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
    private var nookShortcut: GlobalShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let nowPlaying = MediaRemoteNowPlaying()
        let core = NotchCore(
            clock: SystemClock(),
            displayLocator: BuiltInDisplayLocator(),
            fullscreenDetector: FrontAppFullscreenDetector(),
            levelChangeSource: MediaKeyLevelSource(),
            nowPlayingSource: nowPlaying,
            mediaController: nowPlaying,
            calendarSource: EventKitCalendar(),
            frontAppSource: WorkspaceFrontApp(),
            claudeCodeSource: ClaudeCodeHooks(),
            toDoSource: EventKitReminders(),
            dateDetector: DataDetectorDates(),
            trayStore: BookmarkTrayStore(),
            airDropSharer: SharingServiceAirDrop()
        )
        notchWindow = NotchWindowController(core: core)
        let shortcut = GlobalShortcut.nook
        nookShortcut = GlobalShortcut(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { core.toggleNook() }
    }
}

private struct MenuBarMenu: View {
    @State private var launchesAtLogin = LaunchAtLogin.isEnabled
    @State private var claudeCodeHooked = ClaudeCodeHookSettings.isInstalled

    var body: some View {
        Toggle("Launch at Login", isOn: $launchesAtLogin)
            .onChange(of: launchesAtLogin) { _, enabled in
                LaunchAtLogin.set(enabled)
                launchesAtLogin = LaunchAtLogin.isEnabled
            }
        Toggle("Show Claude Code Sessions", isOn: $claudeCodeHooked)
            .onChange(of: claudeCodeHooked) { _, enabled in
                ClaudeCodeHookSettings.set(enabled)
                claudeCodeHooked = ClaudeCodeHookSettings.isInstalled
            }
        Divider()
        Button("Restart Entailler") {
            restart()
        }
        .keyboardShortcut("r")
        Button("Quit Entailler") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// Quits, and opens Entailler again once this copy has gone, so the two never run together.
    private func restart() {
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = [
            "-c",
            "while kill -0 \"$0\" 2>/dev/null; do sleep 0.1; done; open \"$1\"",
            String(ProcessInfo.processInfo.processIdentifier),
            Bundle.main.bundlePath,
        ]
        do {
            try relaunch.run()
        } catch {
            NSLog("Entailler couldn't restart: \(error)")
            return
        }
        NSApplication.shared.terminate(nil)
    }
}
