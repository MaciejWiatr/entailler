/// A Claude Code session running in a terminal or another app.
public struct ClaudeSession: Hashable, Sendable {
    /// Claude Code's own identifier for the session.
    public var id: String
    /// The name of the folder the session works in, shown in its Activity.
    public var project: String
    /// Why the session is waiting for the user.
    public var reason: ClaudeWaitReason
    /// Where the session runs, so the shell can bring it to the front. `nil` when it couldn't be found.
    public var host: ClaudeHost?

    public init(id: String, project: String, reason: ClaudeWaitReason, host: ClaudeHost? = nil) {
        self.id = id
        self.project = project
        self.reason = reason
        self.host = host
    }
}

public enum ClaudeWaitReason: Hashable, Sendable {
    /// Claude finished responding.
    case finished
    /// Claude is asking for permission or for an answer before it can go on.
    case needsInput
}

/// The app a Claude Code session runs in.
public struct ClaudeHost: Hashable, Sendable {
    /// The app's process identifier.
    public var app: Int32
    /// The terminal device the session runs on, such as `/dev/ttys003`, for finding its tab.
    public var terminal: String?

    public init(app: Int32, terminal: String? = nil) {
        self.app = app
        self.terminal = terminal
    }
}

/// What a Claude Code session reports as it goes.
public enum ClaudeCodeReport: Equatable, Sendable {
    /// The session is waiting for the user, for the reason it gives.
    case waiting(ClaudeSession)
    /// The user sent the session a prompt, so it no longer waits.
    case working(sessionID: String)
    /// The session ended, or the process running it is gone.
    case ended(sessionID: String)
}
