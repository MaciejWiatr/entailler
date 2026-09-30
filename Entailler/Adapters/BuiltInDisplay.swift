import AppKit
import NotchCore

/// Finds the built-in notched display and where its Notch sits.
@MainActor
final class BuiltInDisplayLocator: DisplayLocator {
    private var observer: (any NSObjectProtocol)?

    func start(_ update: @escaping @MainActor (NotchPlacement?) -> Void) {
        update(Self.notchPlacement())
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { update(Self.notchPlacement()) }
        }
    }

    private static func notchPlacement() -> NotchPlacement? {
        guard
            let screen = NSScreen.builtInNotched,
            let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea
        else { return nil }

        let frame = screen.frame
        let height = screen.safeAreaInsets.top
        return NotchPlacement(
            x: frame.minX + left.width,
            y: frame.maxY - height,
            width: frame.width - left.width - right.width,
            height: height
        )
    }
}
