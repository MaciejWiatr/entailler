import AppKit
import NotchCore
import SwiftUI

/// Owns the floating window over the notch, keeps it placed from the display state,
/// and turns pointer movement into the core's pointer inputs.
@MainActor
final class NotchWindowController {
    private let core: NotchCore
    private let window = NotchWindow()
    private var monitors: [Any] = []
    private var observation: Task<Void, Never>?
    private var pointerInside = false
    /// Follows the pointer while the Nook is open: while the window has the keyboard, pointer
    /// movement outside it reaches neither event monitor, and while a file is dragged out of the
    /// Tray, the drag takes the pointer's events.
    private var pointerPoll: Timer?
    /// Whether the button held down is dragging files from another app, such as Finder.
    private var isDraggingFiles = false
    /// The drag pasteboard as it was when the button went down, to tell when a drag puts files on it.
    private var dragPasteboardCount = NSPasteboard(name: .drag).changeCount

    init(core: NotchCore) {
        self.core = core
        let drops = FileDrops()
        drops.drop = { zone, files in
            switch zone {
            case .tray: core.dropIntoTray(files)
            case .airDrop: core.dropOnAirDrop(files)
            }
        }
        // The window's frame comes from the Notch placement, never from the SwiftUI content.
        // As the window's content view, a hosting view resizes the window to fit its content,
        // so it sits inside a container instead, which takes file drags for the Files view's Drop
        // Zones.
        let hostingView = FirstMouseHostingView(rootView: NotchView(core: core, drops: drops))
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        let container = FileDropView(drops: drops)
        container.addSubview(hostingView)
        window.contentView = container
        observation = Task { [weak self, core] in
            for await state in Observations({ core.state }) {
                self?.apply(state)
            }
        }
        trackPointer()
        handleKeys()
    }

    private func apply(_ state: NotchDisplayState) {
        guard case .present(let placement) = state.visibility else {
            window.orderOut(nil)
            pointerInside = false
            return
        }
        window.setFrame(Self.windowFrame(around: placement), display: true)
        if !window.isVisible {
            window.orderFrontRegardless()
        }
        takesKeyboard(state.nookHasKeyboard)
        followsPointer(state.nook != .closed)
        pointerMoved()
    }

    private func followsPointer(_ follows: Bool) {
        guard follows else {
            pointerPoll?.invalidate()
            pointerPoll = nil
            return
        }
        guard pointerPoll == nil else { return }
        let poll = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        // Common modes keep it running while a drag tracks the pointer.
        RunLoop.main.add(poll, forMode: .common)
        pointerPoll = poll
    }

    /// The open Nook takes the keyboard when the core says, such as for To-Dos, so the user can
    /// type a new to-do straight away. Once it closes, the window gives the keyboard back to the
    /// app the user was typing in.
    private func takesKeyboard(_ takes: Bool) {
        window.acceptsKeyboard = takes
        if takes {
            if !window.isKeyWindow { window.makeKey() }
            return
        }
        guard window.isKeyWindow else { return }
        // Ordering the window out hands the keyboard back; it comes straight back in front.
        window.orderOut(nil)
        window.orderFrontRegardless()
    }

    /// Escape closes the Nook; ⌘1 to ⌘4 switch to a view, and ⌘[ and ⌘] to the one before or
    /// after. Each view handles its own keys besides.
    private func handleKeys() {
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handleKey(event) ?? false } ? nil : event
        }
        if let monitor { monitors.append(monitor) }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard window.isKeyWindow, case .open = core.state.nook else { return false }
        let modifiers = event.heldModifiers
        if event.keyCode == 53, modifiers.isEmpty {
            core.dismissNook()
            return true
        }
        guard modifiers == .command, let key = event.charactersIgnoringModifiers else { return false }
        let views = NookView.allCases
        if let number = Int(key), views.indices.contains(number - 1) {
            core.switchNook(to: views[number - 1])
        } else if key == "[" {
            core.switchNook(by: -1)
        } else if key == "]" {
            core.switchNook(by: 1)
        } else {
            return false
        }
        return true
    }

    private func trackPointer() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
                MainActor.assumeIsolated { self?.pointerMoved() }
            },
            NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
                MainActor.assumeIsolated { self?.pointerMoved() }
                return event
            },
        ].compactMap { $0 }
        trackFileDrags()
    }

    /// Files dragged from another app open the Nook on Files when they come to the Notch. A drag
    /// puts what it carries on the drag pasteboard, so a pasteboard that changed since the button
    /// went down means the button is dragging something.
    private func trackFileDrags() {
        let monitors: [Any?] = [
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isDraggingFiles = false
                    self?.dragPasteboardCount = NSPasteboard(name: .drag).changeCount
                }
            },
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
                MainActor.assumeIsolated { self?.dragMoved() }
            },
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
                MainActor.assumeIsolated { self?.isDraggingFiles = false }
            },
        ]
        self.monitors += monitors.compactMap { $0 }
    }

    private func dragMoved() {
        let pasteboard = NSPasteboard(name: .drag)
        if !isDraggingFiles, pasteboard.changeCount != dragPasteboardCount {
            isDraggingFiles = pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        }
        // A drag already on the Notch when it picked up its files opens the Nook now.
        if isDraggingFiles, pointerInside, core.state.nook == .closed {
            core.dragEntered()
        }
    }

    private func pointerMoved() {
        let location = NSEvent.mouseLocation
        let isOnButton = buttonArea?.contains(location) ?? false
        // Only the open Nook, or the Activity's button, such as an upcoming call's Join button,
        // takes clicks. The rest of the collapsed Notch lets them through to the menu bar.
        window.ignoresMouseEvents = core.state.nook == .closed && !isOnButton
        // Resting on the button doesn't open the Nook, which would cover it.
        let isInside = !isOnButton && hotArea?.contains(location) ?? false
        guard isInside != pointerInside else { return }
        pointerInside = isInside
        if isInside, isDraggingFiles {
            core.dragEntered()
        } else if isInside {
            core.pointerEntered()
        } else {
            core.pointerExited()
        }
    }

    /// The collapsed Notch's button, in screen coordinates.
    private var buttonArea: NSRect? {
        guard case .present(let placement) = core.state.visibility, core.state.nook == .closed,
              let area = NookLayout.buttonArea(around: placement, activity: core.state.activity)
        else { return nil }
        let top = placement.y + placement.height
        let centre = placement.x + placement.width / 2
        // Up to the very top pixel row, which `contains` treats as outside.
        return NSRect(x: centre + area.minX, y: top - area.maxY, width: area.width, height: area.height + 1)
    }

    /// The area the pointer has to be in: close to the Notch (with any Activity) while collapsed,
    /// the whole Nook while open.
    private var hotArea: NSRect? {
        guard case .present(let placement) = core.state.visibility else { return nil }
        let size: CGSize
        switch core.state.nook {
        case .open(let view):
            size = NookLayout.size(around: placement, view: view)
        case .closed:
            let proximity = NookLayout.hoverProximity
            let notch = NookLayout.closedSize(around: placement, activity: core.state.activity)
            size = CGSize(width: notch.width + proximity.width * 2, height: notch.height + proximity.height)
        }
        let area = Self.frame(of: size, around: placement)
        // The pointer can rest on the very top pixel row, which `contains` treats as outside.
        return NSRect(x: area.minX, y: area.minY, width: area.width, height: area.height + 1)
    }

    /// The window: the Nook plus room for the opening spring to overshoot without being cut off.
    private static func windowFrame(around placement: NotchPlacement) -> NSRect {
        let overshoot = NookLayout.springOvershoot
        let nook = NookLayout.largestSize(around: placement)
        let size = CGSize(width: nook.width + overshoot.width * 2, height: nook.height + overshoot.height)
        return frame(of: size, around: placement)
    }

    /// A rectangle hanging from the top of the screen, centred on the Notch.
    private static func frame(of size: CGSize, around placement: NotchPlacement) -> NSRect {
        NSRect(
            x: placement.x + placement.width / 2 - size.width / 2,
            y: placement.y + placement.height - size.height,
            width: size.width,
            height: size.height
        )
    }
}

/// A borderless window that floats above the menu bar and fullscreen apps. It takes the keyboard
/// only while `acceptsKeyboard`, and even then never activates Entailler, so the app in front
/// stays in front.
private final class NotchWindow: NSPanel {
    var acceptsKeyboard = false

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .mainMenu + 3
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        // Handing the keyboard back orders the window out and straight back in, which mustn't fade.
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }
}

/// Lets the first click on the Nook act without the window having to become key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

