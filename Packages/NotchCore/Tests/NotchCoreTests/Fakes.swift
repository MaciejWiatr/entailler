import Foundation
import NotchCore

/// A clock that only moves when a test calls `advance(by:)`. It starts at 9:00 on `Date.today`.
@MainActor
final class FakeClock: NotchClock {
    private let start = Date.today(at: 9)
    var now: Date { start + TimeInterval(elapsed.components.seconds) + TimeInterval(elapsed.components.attoseconds) / 1e18 }

    private struct Pending {
        let id: Int
        let deadline: Duration
        let action: @MainActor () -> Void
    }

    private final class Handle: TimerHandle {
        let cancelAction: @MainActor () -> Void
        init(_ cancelAction: @escaping @MainActor () -> Void) { self.cancelAction = cancelAction }
        func cancel() { cancelAction() }
    }

    private var elapsed: Duration = .zero
    private var pending: [Pending] = []
    private var nextID = 0

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any TimerHandle {
        let id = nextID
        nextID += 1
        pending.append(Pending(id: id, deadline: elapsed + delay, action: action))
        return Handle { [weak self] in self?.pending.removeAll { $0.id == id } }
    }

    func advance(by duration: Duration) {
        let target = elapsed + duration
        while let next = pending.filter({ $0.deadline <= target }).min(by: { $0.deadline < $1.deadline }) {
            pending.removeAll { $0.id == next.id }
            elapsed = next.deadline
            next.action()
        }
        elapsed = target
    }
}

@MainActor
final class FakeDisplayLocator: DisplayLocator {
    private var update: (@MainActor (NotchPlacement?) -> Void)?
    private var placement: NotchPlacement?

    init(placement: NotchPlacement? = .macBookPro) {
        self.placement = placement
    }

    func start(_ update: @escaping @MainActor (NotchPlacement?) -> Void) {
        self.update = update
        update(placement)
    }

    func set(_ placement: NotchPlacement?) {
        self.placement = placement
        update?(placement)
    }
}

@MainActor
final class FakeFullscreenDetector: FullscreenDetector {
    private var update: (@MainActor (Bool) -> Void)?
    private var isFullscreen = false

    func start(_ update: @escaping @MainActor (Bool) -> Void) {
        self.update = update
        update(isFullscreen)
    }

    func set(_ isFullscreen: Bool) {
        self.isFullscreen = isFullscreen
        update?(isFullscreen)
    }
}

@MainActor
final class FakeLevelChangeSource: LevelChangeSource {
    private var update: (@MainActor (LevelChange) -> Void)?

    func start(_ update: @escaping @MainActor (LevelChange) -> Void) {
        self.update = update
    }

    func send(_ change: LevelChange) {
        update?(change)
    }
}

@MainActor
final class FakeNowPlayingSource: NowPlayingSource {
    private var update: (@MainActor (NowPlaying?) -> Void)?
    private var nowPlaying: NowPlaying?

    func start(_ update: @escaping @MainActor (NowPlaying?) -> Void) {
        self.update = update
        update(nowPlaying)
    }

    func set(_ nowPlaying: NowPlaying?) {
        self.nowPlaying = nowPlaying
        update?(nowPlaying)
    }
}

@MainActor
final class FakeMediaController: MediaController {
    private(set) var sent: [MediaCommand] = []

    func send(_ command: MediaCommand) {
        sent.append(command)
    }
}

@MainActor
final class FakeCalendarSource: CalendarSource {
    private var update: (@MainActor (CalendarAccess) -> Void)?
    private var access = CalendarAccess.granted
    private var events: [CalendarEvent] = []

    func start(_ update: @escaping @MainActor (CalendarAccess) -> Void) {
        self.update = update
        update(access)
    }

    func events(in interval: DateInterval) -> [CalendarEvent] {
        guard access == .granted else { return [] }
        return events.filter { $0.start < interval.end && $0.end > interval.start }
    }

    func set(_ events: [CalendarEvent]) {
        self.events = events
        update?(access)
    }

    func set(_ access: CalendarAccess) {
        self.access = access
        update?(access)
    }
}

extension NotchPlacement {
    static let macBookPro = NotchPlacement(x: 1545, y: 1085, width: 185, height: 32)
}

/// A Notch core wired to fakes, so a test can drive every input.
@MainActor
struct Harness {
    let clock = FakeClock()
    let display: FakeDisplayLocator
    let fullscreen = FakeFullscreenDetector()
    let levels = FakeLevelChangeSource()
    let nowPlaying = FakeNowPlayingSource()
    let mediaController = FakeMediaController()
    let calendar = FakeCalendarSource()
    let core: NotchCore

    init(placement: NotchPlacement? = .macBookPro) {
        display = FakeDisplayLocator(placement: placement)
        core = NotchCore(
            clock: clock,
            displayLocator: display,
            fullscreenDetector: fullscreen,
            levelChangeSource: levels,
            nowPlayingSource: nowPlaying,
            mediaController: mediaController,
            calendarSource: calendar
        )
    }

    var state: NotchDisplayState { core.state }

    func hover(for duration: Duration) {
        core.pointerEntered()
        clock.advance(by: duration)
    }
}

extension Harness {
    /// Turns the volume to an arbitrary unmuted level.
    func changeVolume() {
        levels.send(.volume(level: 0.5, isMuted: false))
    }
}

extension NowPlaying {
    static let song = NowPlaying(
        app: "com.example.player",
        title: "Windowlicker",
        artist: "Aphex Twin",
        artwork: Data([0xFF, 0xD8]),
        duration: 367,
        elapsed: 42,
        elapsedAt: Date(timeIntervalSince1970: 1_000_000),
        isPlaying: true
    )

    var paused: NowPlaying {
        var copy = self
        copy.isPlaying = false
        return copy
    }

    /// The same track as its app sometimes publishes it: no artwork, and some other title.
    var sparse: NowPlaying {
        var copy = self
        copy.artwork = nil
        copy.title = "Player – Search"
        copy.artist = ""
        return copy
    }
}

extension Date {
    /// The day the tests take place on, a Monday with no daylight saving change.
    static let today = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5))!
    static let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

    static func today(at hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    static func tomorrow(at hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow)!
    }
}

extension CalendarEvent {
    /// A 30-minute event with no meeting link.
    static func meeting(_ title: String, at start: Date, minutes: Int = 30) -> CalendarEvent {
        CalendarEvent(id: title, title: title, start: start, end: start + TimeInterval(minutes * 60))
    }

    static let standup = meeting("Standup", at: .today(at: 10))

    /// An all-day event on `day`.
    static func allDay(_ title: String, on day: Date) -> CalendarEvent {
        CalendarEvent(
            id: title,
            title: title,
            start: day,
            end: Calendar.current.date(byAdding: .day, value: 1, to: day)!,
            isAllDay: true
        )
    }
}
