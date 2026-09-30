import Foundation
import Observation

/// All of Entailler's behavior. Takes inputs from adapters and the shell,
/// and publishes a single display state.
@MainActor
@Observable
public final class NotchCore {
    public private(set) var state = NotchDisplayState()

    static let hoverDelay: Duration = .milliseconds(150)
    static let flashDuration: Duration = .milliseconds(1500)
    static let pausedNowPlayingLinger: Duration = .seconds(5)
    /// Two reports whose durations differ by less than this are taken to be the same track.
    static let sameTrackDurationTolerance: TimeInterval = 1

    private let clock: any NotchClock
    private let displayLocator: any DisplayLocator
    private let fullscreenDetector: any FullscreenDetector
    private let levelChangeSource: any LevelChangeSource
    private let nowPlayingSource: any NowPlayingSource
    private let mediaController: any MediaController
    @ObservationIgnored private var hoverTimer: (any TimerHandle)?
    @ObservationIgnored private var flashTimer: (any TimerHandle)?
    @ObservationIgnored private var pausedTimer: (any TimerHandle)?
    @ObservationIgnored private var activities: [ActivitySource: Activity] = [:]
    @ObservationIgnored private var isFullscreen = false

    public init(
        clock: any NotchClock,
        displayLocator: any DisplayLocator,
        fullscreenDetector: any FullscreenDetector,
        levelChangeSource: any LevelChangeSource,
        nowPlayingSource: any NowPlayingSource,
        mediaController: any MediaController
    ) {
        self.clock = clock
        self.displayLocator = displayLocator
        self.fullscreenDetector = fullscreenDetector
        self.levelChangeSource = levelChangeSource
        self.nowPlayingSource = nowPlayingSource
        self.mediaController = mediaController
        displayLocator.start { [weak self] placement in self?.displayChanged(placement) }
        fullscreenDetector.start { [weak self] isFullscreen in self?.fullscreenChanged(isFullscreen) }
        levelChangeSource.start { [weak self] change in self?.levelChanged(change) }
        nowPlayingSource.start { [weak self] nowPlaying in self?.nowPlayingChanged(nowPlaying) }
    }

    public func pointerEntered() {
        guard state.visibility != .absent, state.nook == .closed, hoverTimer == nil else { return }
        hoverTimer = clock.schedule(after: Self.hoverDelay) { [weak self] in
            self?.hoverTimer = nil
            self?.state.nook = .open(.home)
        }
    }

    public func pointerExited() {
        closeNook()
    }

    public func switchNook(to view: NookView) {
        guard case .open = state.nook else { return }
        state.nook = .open(view)
    }

    /// Passes a command from the Media Widget to the now-playing source. Seeks stay within the track.
    public func sendMediaCommand(_ command: MediaCommand) {
        guard let track = state.media.nowPlaying else { return }
        guard case .seek(let position) = command else {
            mediaController.send(command)
            return
        }
        mediaController.send(.seek(to: track.clamped(position)))
    }

    public func activityStarted(_ activity: Activity) {
        activities[activity.source] = activity
        refreshActivity()
    }

    public func activityEnded(_ source: ActivitySource) {
        activities[source] = nil
        refreshActivity()
    }

    private func displayChanged(_ placement: NotchPlacement?) {
        guard let placement else {
            state.visibility = .absent
            closeNook()
            return
        }
        state.visibility = .present(placement)
    }

    private func levelChanged(_ change: LevelChange) {
        activities[.flash] = .flash(change)
        refreshActivity()
        // Each change restarts the countdown, so repeated key presses keep the Flash Activity up.
        flashTimer?.cancel()
        flashTimer = clock.schedule(after: Self.flashDuration) { [weak self] in
            self?.flashTimer = nil
            self?.activityEnded(.flash)
        }
    }

    /// Playing media shows the now-playing Activity. Pausing leaves it up for a while before it
    /// hides; media that is no longer reported at all takes it away at once.
    private func nowPlayingChanged(_ nowPlaying: NowPlaying?) {
        let nowPlaying = nowPlaying.map { filledIn($0, from: state.media.nowPlaying) }
        state.media = nowPlaying.map(MediaWidget.track) ?? .empty
        switch nowPlaying?.isPlaying {
        case true:
            cancelPausedTimer()
            activityStarted(.nowPlaying)
        case false:
            guard pausedTimer == nil, activities[.nowPlaying] != nil else { return }
            pausedTimer = clock.schedule(after: Self.pausedNowPlayingLinger) { [weak self] in
                self?.pausedTimer = nil
                self?.activityEnded(.nowPlaying)
            }
        case nil:
            cancelPausedTimer()
            activityEnded(.nowPlaying)
        }
    }

    /// Apps don't always publish artwork, and Spotify also publishes the track it's playing with no
    /// artwork and its window title in place of the track's. So media without artwork shows the
    /// artwork its app last published, and if it's the same length as the track before, it's taken
    /// to be that track: it keeps the title and artist and takes only the playback state.
    private func filledIn(_ nowPlaying: NowPlaying, from previous: NowPlaying?) -> NowPlaying {
        guard nowPlaying.artwork == nil, let previous, previous.app == nowPlaying.app else { return nowPlaying }
        var filled = nowPlaying
        filled.artwork = previous.artwork
        if let duration = nowPlaying.duration, let previousDuration = previous.duration,
           abs(duration - previousDuration) < Self.sameTrackDurationTolerance {
            filled.title = previous.title
            filled.artist = previous.artist
        }
        return filled
    }

    private func cancelPausedTimer() {
        pausedTimer?.cancel()
        pausedTimer = nil
    }

    private func fullscreenChanged(_ isFullscreen: Bool) {
        self.isFullscreen = isFullscreen
        refreshActivity()
    }

    /// Shows the highest-priority Activity. In fullscreen only Flash Activities show.
    private func refreshActivity() {
        state.activity = ActivitySource.allCases.lazy
            .compactMap { self.activities[$0] }
            .first { !self.isFullscreen || $0.kind == .flash }
    }

    private func closeNook() {
        hoverTimer?.cancel()
        hoverTimer = nil
        state.nook = .closed
    }
}
