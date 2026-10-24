import AppKit
import NotchCore

/// Hears from Claude Code through the hooks `ClaudeCodeHookSettings` adds to its settings. Each
/// hook sends a line with the bundle identifier of the app it was started from, if it knows it,
/// then its JSON input, into a Unix socket with `nc`. `nc` waits for Entailler to close the socket,
/// and until then its parent processes lead up to the session and the app it runs in.
@MainActor
final class ClaudeCodeHooks: ClaudeCodeSource {
    nonisolated static let socketURL = URL.applicationSupportDirectory.appending(path: "Entailler/claude.sock")
    /// How long a hook gets to send its input before the socket is closed on it.
    private static let readTimeout: Duration = .seconds(5)
    /// The shells a hook command runs through on its way from Claude Code to `nc`.
    private static let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish"]
    /// The notifications in which Claude asks for permission or for an answer.
    nonisolated static let needsInputNotifications: Set<String> = ["permission_prompt", "elicitation_dialog", "elicitation_url_dialog"]

    private var update: (@MainActor (ClaudeCodeReport) -> Void)?
    private var listener: (any DispatchSourceRead)?
    /// Watches each session's Claude Code process, to report the session ended if it goes away
    /// without saying so, such as when its terminal tab is closed.
    private var exitWatches: [String: any DispatchSourceProcess] = [:]

    func start(_ update: @escaping @MainActor (ClaudeCodeReport) -> Void) {
        self.update = update
        do {
            try listen()
        } catch {
            NSLog("Entailler: can't listen for Claude Code hooks: \(error)")
        }
    }

    func bringToFront(_ session: ClaudeSession) {
        guard let host = session.host, let app = NSRunningApplication(processIdentifier: host.app) else { return }
        if let terminal = host.terminal, let script = Self.tabScript(for: app.bundleIdentifier) {
            // Asks for Automation permission the first time.
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/osascript")
            process.arguments = script.flatMap { ["-e", $0] } + [terminal]
            try? process.run()
        } else {
            Self.raiseWindow(titled: session.project, of: app)
        }
        // A background app can't hand activation to another app, but Launch Services can.
        if let url = app.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
    }

    // MARK: Listening

    private func listen() throws {
        let path = Self.socketURL.path
        try FileManager.default.createDirectory(at: Self.socketURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // A socket left behind by an earlier run would stop this one binding.
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError.current }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let fits = withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            // Leaves room for the terminating zero the address already ends with.
            guard path.utf8.count < buffer.count else { return false }
            buffer.copyBytes(from: path.utf8)
            return true
        }
        guard fits else {
            close(fd)
            throw POSIXError(.ENAMETOOLONG)
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, Darwin.listen(fd, 16) == 0 else {
            let error = POSIXError.current
            close(fd)
            throw error
        }
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.acceptConnections(on: fd) }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        listener = source
    }

    private func acceptConnections(on listener: Int32) {
        while case let fd = accept(listener, nil, nil), fd >= 0 {
            _ = fcntl(fd, F_SETFL, O_NONBLOCK)
            let connection = HookConnection(fd: fd)
            connection.source.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    guard connection.read() else { return }
                    // Read before closing: the sender's processes are still there until then.
                    self?.received(connection.input, from: connection.sender)
                    connection.close()
                }
            }
            connection.source.resume()
            Task {
                try? await Task.sleep(for: Self.readTimeout)
                connection.close()
            }
        }
    }

    private func received(_ data: Data, from sender: pid_t?) {
        guard let newline = data.firstIndex(of: UInt8(ascii: "\n")) else { return }
        let startedFrom = String(decoding: data[..<newline], as: UTF8.self)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let input = try? decoder.decode(HookInput.self, from: data[data.index(after: newline)...]) else { return }
        let id = input.sessionId
        let reason: ClaudeWaitReason
        switch input.hookEventName {
        case "Stop":
            reason = .finished
        case "Notification" where input.notificationType.map(Self.needsInputNotifications.contains) == true:
            reason = .needsInput
        case "UserPromptSubmit":
            watchExit(of: sender, session: id)
            update?(.working(sessionID: id))
            return
        case "SessionEnd":
            sessionEnded(id)
            return
        default:
            return
        }
        watchExit(of: sender, session: id)
        let project = input.cwd.map { URL(filePath: $0).lastPathComponent } ?? "Claude Code"
        let host = sender.flatMap { Self.host(of: $0, startedFrom: startedFrom) }
        update?(.waiting(ClaudeSession(id: id, project: project, reason: reason, host: host)))
    }

    private func watchExit(of sender: pid_t?, session id: String) {
        guard exitWatches[id] == nil, let sender, let claude = Self.claudeProcess(above: sender) else { return }
        let source = DispatchSource.makeProcessSource(identifier: claude, eventMask: .exit, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.sessionEnded(id) }
        }
        source.resume()
        exitWatches[id] = source
    }

    private func sessionEnded(_ id: String) {
        exitWatches.removeValue(forKey: id)?.cancel()
        update?(.ended(sessionID: id))
    }

    // MARK: Finding the session

    /// The app the session runs in: the nearest of the sender's parents that is a regular app.
    /// A session in tmux, or in a terminal whose shells outlive it, has no app among its parents,
    /// so it falls back on the app the hook was started from, by its bundle identifier.
    private static func host(of sender: pid_t, startedFrom bundleIdentifier: String) -> ClaudeHost? {
        let ancestry = ancestry(of: sender)
        let app = ancestry.lazy
            .compactMap { NSRunningApplication(processIdentifier: $0.pid) }
            .first { $0.activationPolicy == .regular }
            ?? NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        guard let app else { return nil }
        let terminal = ancestry.lazy.compactMap(\.terminal).first
        return ClaudeHost(app: app.processIdentifier, terminal: terminal)
    }

    /// The Claude Code process that ran the hook: the first of the sender's parents that isn't
    /// the shell the hook command runs in.
    private static func claudeProcess(above sender: pid_t) -> pid_t? {
        ancestry(of: sender).dropFirst().first { !shells.contains($0.name) }?.pid
    }

    private struct ProcessEntry {
        let pid: pid_t
        let name: String
        /// The controlling terminal's device path, such as `/dev/ttys003`.
        let terminal: String?
    }

    /// `pid` and its parents, nearest first, up to but not including launchd.
    private static func ancestry(of pid: pid_t) -> [ProcessEntry] {
        var entries: [ProcessEntry] = []
        var pid = pid
        while pid > 1, entries.count < 64 {
            var info = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.stride
            var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
            guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { break }
            let name = withUnsafeBytes(of: info.kp_proc.p_comm) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            let device = info.kp_eproc.e_tdev
            let terminal = device == -1 ? nil : devname(device, S_IFCHR).map { "/dev/" + String(cString: $0) }
            entries.append(ProcessEntry(pid: pid, name: name, terminal: terminal))
            pid = info.kp_eproc.e_ppid
        }
        return entries
    }

    // MARK: Bringing the session to the front

    /// Terminal and iTerm2 can select the tab running on a terminal device, passed as the
    /// script's argument.
    private static func tabScript(for bundleIdentifier: String?) -> [String]? {
        switch bundleIdentifier {
        case "com.apple.Terminal":
            [
                "on run argv",
                "tell application id \"com.apple.Terminal\"",
                "repeat with w in windows",
                "repeat with t in tabs of w",
                "if tty of t is item 1 of argv then",
                "set selected of t to true",
                "set index of w to 1",
                "activate",
                "return",
                "end if",
                "end repeat",
                "end repeat",
                "end tell",
                "end run",
            ]
        case "com.googlecode.iterm2":
            [
                "on run argv",
                "tell application id \"com.googlecode.iterm2\"",
                "repeat with w in windows",
                "repeat with t in tabs of w",
                "repeat with s in sessions of t",
                "if tty of s is item 1 of argv then",
                "select w",
                "select t",
                "select s",
                "activate",
                "return",
                "end if",
                "end repeat",
                "end repeat",
                "end repeat",
                "end tell",
                "end run",
            ]
        default:
            nil
        }
    }

    /// Other apps, such as editors, usually name their windows after the folder they have open,
    /// so the window to raise is the first whose title has the project's name. Needs the
    /// Accessibility permission the volume and brightness keys already ask for.
    private static func raiseWindow(titled project: String, of app: NSRunningApplication) {
        guard AXIsProcessTrusted() else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var windows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXWindows" as CFString, &windows) == .success,
              let windows = windows as? [AXUIElement]
        else { return }
        let window = windows.first { window in
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(window, "AXTitle" as CFString, &title)
            return (title as? String)?.localizedCaseInsensitiveContains(project) == true
        }
        guard let window else { return }
        AXUIElementSetAttributeValue(window, "AXMain" as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, "AXRaise" as CFString)
    }
}

/// The parts of a hook's JSON input Entailler uses.
private struct HookInput: Decodable {
    let sessionId: String
    let hookEventName: String
    let cwd: String?
    let notificationType: String?
}

/// One hook's connection to the socket.
@MainActor
private final class HookConnection {
    let source: any DispatchSourceRead
    /// The process that connected: `nc`, run by the hook.
    let sender: pid_t?
    private(set) var input = Data()
    private let fd: Int32
    private var isClosed = false

    init(fd: Int32) {
        self.fd = fd
        var pid: pid_t = 0
        var length = socklen_t(MemoryLayout<pid_t>.size)
        sender = getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &pid, &length) == 0 ? pid : nil
        source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setCancelHandler { Darwin.close(fd) }
    }

    /// Reads what has arrived. Returns `true` once the sender has sent all of it.
    func read() -> Bool {
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count > 0 {
                input.append(contentsOf: buffer.prefix(count))
            } else {
                return count == 0 || errno != EAGAIN
            }
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        source.cancel()
    }
}

private extension POSIXError {
    static var current: POSIXError { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}
