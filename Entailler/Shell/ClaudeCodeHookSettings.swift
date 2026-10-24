import Foundation

/// Adds the hooks that tell Entailler what Claude Code sessions are doing to Claude Code's user
/// settings, or takes them out again. Every session on the Mac runs them, in any terminal or app.
enum ClaudeCodeHookSettings {
    static let settingsURL = URL.homeDirectory.appending(path: ".claude/settings.json")

    /// Sends the bundle identifier of the app the session was started from, which macOS sets for
    /// every process an app starts, then the hook's input, to Entailler. Quietly does nothing while
    /// Entailler isn't running.
    private static let command = #"{ echo "$__CFBundleIdentifier"; cat; } | nc -U -w 2 '"# + ClaudeCodeHooks.socketURL.path + #"' >/dev/null 2>&1 || true"#

    /// The events to hook, each with the matcher that narrows it down, if any.
    private static let events: [(name: String, matcher: String?)] = [
        ("UserPromptSubmit", nil),
        ("Stop", nil),
        ("Notification", ClaudeCodeHooks.needsInputNotifications.sorted().joined(separator: "|")),
        ("SessionEnd", nil),
    ]

    static var isInstalled: Bool {
        guard let hooks = (try? settings())?["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { event in
            (hooks[event.name] as? [[String: Any]])?.contains(where: isEntaillers) == true
        }
    }

    static func set(_ installed: Bool) {
        do {
            var settings = try settings()
            var hooks = settings["hooks"] as? [String: Any] ?? [:]
            for event in events {
                var groups = (hooks[event.name] as? [[String: Any]] ?? []).filter { !isEntaillers($0) }
                if installed {
                    var group: [String: Any] = ["hooks": [["type": "command", "command": command, "async": true]]]
                    group["matcher"] = event.matcher
                    groups.append(group)
                }
                hooks[event.name] = groups.isEmpty ? nil : groups
            }
            settings["hooks"] = hooks.isEmpty ? nil : hooks
            try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            NSLog("Entailler: can't update Claude Code's settings: \(error)")
        }
    }

    /// The settings as they are, or none if there's no settings file yet.
    private static func settings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let data = try Data(contentsOf: settingsURL)
        guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return settings
    }

    /// Whether a group of hooks is the one Entailler added, recognised by the socket it sends to.
    private static func isEntaillers(_ group: [String: Any]) -> Bool {
        (group["hooks"] as? [[String: Any]] ?? []).contains { hook in
            (hook["command"] as? String)?.contains(ClaudeCodeHooks.socketURL.path) == true
        }
    }
}
