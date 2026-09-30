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

    init(core: NotchCore) {
        self.core = core
        // The window's frame comes from the Notch placement, never from the SwiftUI content.
        // As the window's content view, a hosting view resizes the window to fit its content,
        // so it sits inside a plain container instead.
        let hostingView = FirstMouseHostingView(rootView: NotchView(core: core))
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        let container = NSView()
        container.addSubview(hostingView)
        window.contentView = container
        observation = Task { [weak self, core] in
            for await state in Observations({ core.state }) {
                self?.apply(state)
            }
        }
        trackPointer()
    }

    private func apply(_ state: NotchDisplayState) {
        guard case .present(let placement) = state.visibility else {
            window.orderOut(nil)
            pointerInside = false
            return
        }
        window.setFrame(Self.windowFrame(around: placement), display: true)
        // Only the open Nook takes clicks; the collapsed Notch lets them through to the menu bar.
        window.ignoresMouseEvents = state.nook == .closed
        if !window.isVisible {
            window.orderFrontRegardless()
        }
        pointerMoved()
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
    }

    private func pointerMoved() {
        let isInside = hotArea?.contains(NSEvent.mouseLocation) ?? false
        guard isInside != pointerInside else { return }
        pointerInside = isInside
        if isInside {
            core.pointerEntered()
        } else {
            core.pointerExited()
        }
    }

    /// The area the pointer has to be in: close to the Notch (with any Activity) while collapsed,
    /// the whole Nook while open.
    private var hotArea: NSRect? {
        guard case .present(let placement) = core.state.visibility else { return nil }
        var size = NookLayout.size
        if core.state.nook == .closed {
            let proximity = NookLayout.hoverProximity
            let notch = NookLayout.closedSize(around: placement, showingActivity: core.state.activity != nil)
            size = CGSize(width: notch.width + proximity.width * 2, height: notch.height + proximity.height)
        }
        let area = Self.frame(of: size, around: placement)
        // The pointer can rest on the very top pixel row, which `contains` treats as outside.
        return NSRect(x: area.minX, y: area.minY, width: area.width, height: area.height + 1)
    }

    /// The window: the Nook plus room for the opening spring to overshoot without being cut off.
    private static func windowFrame(around placement: NotchPlacement) -> NSRect {
        let overshoot = NookLayout.springOvershoot
        let size = CGSize(
            width: NookLayout.size.width + overshoot.width * 2,
            height: NookLayout.size.height + overshoot.height
        )
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

/// A borderless window that floats above the menu bar and fullscreen apps and never takes focus.
private final class NotchWindow: NSPanel {
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
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the first click on the Nook act without the window having to become key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
