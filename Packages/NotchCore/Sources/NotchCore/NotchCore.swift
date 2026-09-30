import Observation

/// All of Entailler's behavior. Takes inputs from adapters and the shell,
/// and publishes a single display state.
@MainActor
@Observable
public final class NotchCore {
    public private(set) var state = NotchDisplayState()

    static let hoverDelay: Duration = .milliseconds(150)
    static let flashDuration: Duration = .milliseconds(1500)

    private let clock: any NotchClock
    private let displayLocator: any DisplayLocator
    private let fullscreenDetector: any FullscreenDetector
    private let levelChangeSource: any LevelChangeSource
    @ObservationIgnored private var hoverTimer: (any TimerHandle)?
    @ObservationIgnored private var flashTimer: (any TimerHandle)?
    @ObservationIgnored private var activities: [ActivitySource: Activity] = [:]
    @ObservationIgnored private var isFullscreen = false

    public init(
        clock: any NotchClock,
        displayLocator: any DisplayLocator,
        fullscreenDetector: any FullscreenDetector,
        levelChangeSource: any LevelChangeSource
    ) {
        self.clock = clock
        self.displayLocator = displayLocator
        self.fullscreenDetector = fullscreenDetector
        self.levelChangeSource = levelChangeSource
        displayLocator.start { [weak self] placement in self?.displayChanged(placement) }
        fullscreenDetector.start { [weak self] isFullscreen in self?.fullscreenChanged(isFullscreen) }
        levelChangeSource.start { [weak self] change in self?.levelChanged(change) }
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
