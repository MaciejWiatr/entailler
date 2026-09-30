import Foundation

/// What the system's now-playing source is playing.
public struct NowPlaying: Equatable, Sendable {
    /// Identifies the app playing it, such as its bundle identifier.
    public var app: String
    public var title: String
    public var artist: String
    public var artwork: Data?
    /// `nil` when the source doesn't know, such as a live stream.
    public var duration: TimeInterval?
    /// How far into the track playback was at `elapsedAt`.
    public var elapsed: TimeInterval
    public var elapsedAt: Date
    public var isPlaying: Bool

    public init(
        app: String,
        title: String,
        artist: String,
        artwork: Data? = nil,
        duration: TimeInterval?,
        elapsed: TimeInterval,
        elapsedAt: Date,
        isPlaying: Bool
    ) {
        self.app = app
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.duration = duration
        self.elapsed = elapsed
        self.elapsedAt = elapsedAt
        self.isPlaying = isPlaying
    }

    /// How far into the track playback is at `date`, for the Media Widget's progress bar.
    public func position(at date: Date) -> TimeInterval {
        clamped(isPlaying ? elapsed + date.timeIntervalSince(elapsedAt) : elapsed)
    }

    /// `position` moved within the track, if it falls before its start or past its end.
    func clamped(_ position: TimeInterval) -> TimeInterval {
        min(max(position, 0), duration ?? .infinity)
    }
}

/// A command for whichever app is the system's now-playing source.
public enum MediaCommand: Equatable, Sendable {
    case previousTrack
    case togglePlayPause
    case nextTrack
    case seek(to: TimeInterval)
}

/// What the Media Widget on Home shows.
public enum MediaWidget: Equatable, Sendable {
    /// Nothing has played, or the now-playing source is unavailable.
    case empty
    case track(NowPlaying)

    /// The track shown, if any.
    public var nowPlaying: NowPlaying? {
        guard case .track(let nowPlaying) = self else { return nil }
        return nowPlaying
    }
}
