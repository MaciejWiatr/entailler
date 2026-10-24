import AppKit
import NotchCore

/// Reports the front app, as the workspace announces each app coming to the front.
@MainActor
final class WorkspaceFrontApp: FrontAppSource {
    private var observer: (any NSObjectProtocol)?

    func start(_ update: @escaping @MainActor (Int32?) -> Void) {
        update(NSWorkspace.shared.frontmostApplication?.processIdentifier)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let pid = app?.processIdentifier
            MainActor.assumeIsolated { update(pid) }
        }
    }
}
