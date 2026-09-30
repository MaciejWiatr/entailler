import AppKit
import NotchCore

/// Reports whether the front app has a window covering the whole built-in display.
@MainActor
final class FrontAppFullscreenDetector: FullscreenDetector {
    /// Entering or leaving fullscreen animates, so check again once the animation has settled.
    private static let settleDelay: Duration = .milliseconds(800)

    private var observers: [any NSObjectProtocol] = []
    private var settleCheck: Task<Void, Never>?

    func start(_ update: @escaping @MainActor (Bool) -> Void) {
        var last = Self.isFrontAppFullscreen()
        update(last)

        let check = { @MainActor [weak self] in
            let report = {
                let current = Self.isFrontAppFullscreen()
                guard current != last else { return }
                last = current
                update(current)
            }
            report()
            self?.settleCheck?.cancel()
            self?.settleCheck = Task {
                try? await Task.sleep(for: Self.settleDelay)
                guard !Task.isCancelled else { return }
                report()
            }
        }

        let center = NSWorkspace.shared.notificationCenter
        observers = [
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didActivateApplicationNotification,
        ].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { check() }
            }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { check() }
        })
    }

    /// Fullscreen means the menu bar is gone from the built-in display and a window of the front app
    /// fills it. On a notched display that window usually starts below the camera housing rather
    /// than at the very top, so it only has to span the full width down to the bottom edge.
    private static func isFrontAppFullscreen() -> Bool {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            let screen = NSScreen.builtInNotched,
            let displayID = screen.displayID,
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[CFString: Any]]
        else { return false }

        // Window bounds use the display's top-left origin, like `CGDisplayBounds`.
        let displayBounds = CGDisplayBounds(displayID)
        let housingHeight = screen.safeAreaInsets.top
        let boundsOf = { (window: [CFString: Any]) in
            (window[kCGWindowBounds] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }
        }

        let menuBarShown = windows.contains { window in
            window[kCGWindowOwnerName] as? String == "Window Server"
                && window[kCGWindowName] as? String == "Menubar"
                && boundsOf(window)?.intersects(displayBounds) == true
        }
        guard !menuBarShown else { return false }

        return windows.contains { window in
            guard
                window[kCGWindowOwnerPID] as? pid_t == app.processIdentifier,
                window[kCGWindowLayer] as? Int == 0,
                let bounds = boundsOf(window)
            else { return false }
            return bounds.minX == displayBounds.minX
                && bounds.width == displayBounds.width
                && bounds.maxY == displayBounds.maxY
                && bounds.minY <= displayBounds.minY + housingHeight
        }
    }
}
