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

@MainActor
final class FakeFrontAppSource: FrontAppSource {
    private var update: (@MainActor (Int32?) -> Void)?
    private var app: Int32?

    func start(_ update: @escaping @MainActor (Int32?) -> Void) {
        self.update = update
        update(app)
    }

    func set(_ app: Int32?) {
        self.app = app
        update?(app)
    }
}

@MainActor
final class FakeClaudeCodeSource: ClaudeCodeSource {
    private var update: (@MainActor (ClaudeCodeReport) -> Void)?
    private(set) var broughtToFront: [ClaudeSession] = []

    func start(_ update: @escaping @MainActor (ClaudeCodeReport) -> Void) {
        self.update = update
    }

    func bringToFront(_ session: ClaudeSession) {
        broughtToFront.append(session)
    }

    func send(_ report: ClaudeCodeReport) {
        update?(report)
    }
}

/// Reminders as a list in memory: ticking a to-do off takes it out of what's reported, as
/// Reminders reports only to-dos not yet done.
@MainActor
final class FakeToDoSource: ToDoSource {
    private var update: (@MainActor ([ToDo]?) -> Void)?
    private var toDos: [ToDo] = []
    private var hasAccess = true
    private(set) var added: [QuickAdd] = []
    private(set) var changes: [(id: String, isDone: Bool)] = []

    func start(_ update: @escaping @MainActor ([ToDo]?) -> Void) {
        self.update = update
        report()
    }

    func add(_ title: String, due: Date?, isDueAtTime: Bool) {
        added.append(QuickAdd(title: title, due: due, isDueAtTime: isDueAtTime))
    }

    func setDone(_ id: String, _ isDone: Bool) {
        changes.append((id, isDone))
    }

    func set(_ toDos: [ToDo]) {
        self.toDos = toDos
        report()
    }

    func set(access: Bool) {
        hasAccess = access
        report()
    }

    private func report() {
        update?(hasAccess ? toDos.filter { !$0.isDone } : nil)
    }
}

/// Finds only the phrases it's been told about, at their last place in the text.
@MainActor
final class FakeDateDetector: DateDetector {
    private var phrases: [String: (date: Date, hasTime: Bool)] = [:]

    func teach(_ phrase: String, _ date: Date, hasTime: Bool) {
        phrases[phrase] = (date, hasTime)
    }

    func lastDate(in text: String) -> WrittenDate? {
        phrases.compactMap { phrase, meaning in
            text.range(of: phrase, options: .backwards).map { WrittenDate(range: $0, date: meaning.date, hasTime: meaning.hasTime) }
        }
        .max { $0.range.lowerBound < $1.range.lowerBound }
    }
}

/// Remembers what was saved, as if across a restart, and knows which files were deleted or moved.
@MainActor
final class FakeTrayStore: TrayStore {
    private(set) var saved: [URL]
    private var gone: Set<URL> = []
    private var moves: [URL: URL] = [:]

    init(saved: [URL] = []) {
        self.saved = saved
    }

    func load() -> [URL] { saved }

    func save(_ files: [URL]) {
        saved = files
    }

    func locate(_ file: URL) -> URL? {
        let now = moves[file] ?? file
        return gone.contains(now) ? nil : now
    }

    func delete(_ file: URL) {
        gone.insert(file)
    }

    func move(_ file: URL, to destination: URL) {
        moves[file] = destination
    }
}

@MainActor
final class FakeAirDropSharer: AirDropSharer {
    private(set) var shared: [[URL]] = []

    func share(_ files: [URL]) {
        shared.append(files)
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
    let frontApp = FakeFrontAppSource()
    let claudeCode = FakeClaudeCodeSource()
    let toDos = FakeToDoSource()
    let dates = FakeDateDetector()
    let trayStore: FakeTrayStore
    let airDrop = FakeAirDropSharer()
    let core: NotchCore

    init(placement: NotchPlacement? = .macBookPro, trayStore: FakeTrayStore = FakeTrayStore()) {
        display = FakeDisplayLocator(placement: placement)
        self.trayStore = trayStore
        core = NotchCore(
            clock: clock,
            displayLocator: display,
            fullscreenDetector: fullscreen,
            levelChangeSource: levels,
            nowPlayingSource: nowPlaying,
            mediaController: mediaController,
            calendarSource: calendar,
            frontAppSource: frontApp,
            claudeCodeSource: claudeCode,
            toDoSource: toDos,
            dateDetector: dates,
            trayStore: trayStore,
            airDropSharer: airDrop
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
        day(1, at: hour, minute)
    }

    /// A time on the day this many days from today.
    static func day(_ offset: Int, at hour: Int, _ minute: Int = 0) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: offset, to: today)!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
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

extension ClaudeHost {
    /// A terminal app, and the browser the user switches to while Claude works.
    static let terminal = ClaudeHost(app: 501, terminal: "/dev/ttys003")
    static let browserApp: Int32 = 777
}

extension ClaudeSession {
    /// A session in the terminal app that finished responding.
    static func finished(_ id: String, project: String = "entailler", host: ClaudeHost? = .terminal) -> ClaudeSession {
        ClaudeSession(id: id, project: project, reason: .finished, host: host)
    }
}

extension URL {
    /// A file in the user's Downloads folder.
    static func file(_ name: String) -> URL {
        URL(filePath: "/Users/me/Downloads/\(name)")
    }
}
