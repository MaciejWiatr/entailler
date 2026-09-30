import AppKit
import NotchCore
import SwiftUI

@main
struct EntaillerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Entailler", systemImage: "rectangle.topthird.inset.filled") {
            MenuBarMenu()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let core = NotchCore(
            clock: SystemClock(),
            displayLocator: BuiltInDisplayLocator(),
            fullscreenDetector: FrontAppFullscreenDetector()
        )
        notchWindow = NotchWindowController(core: core)
    }
}

private struct MenuBarMenu: View {
    @State private var launchesAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Toggle("Launch at Login", isOn: $launchesAtLogin)
            .onChange(of: launchesAtLogin) { _, enabled in
                LaunchAtLogin.set(enabled)
                launchesAtLogin = LaunchAtLogin.isEnabled
            }
        Divider()
        Button("Quit Entailler") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
