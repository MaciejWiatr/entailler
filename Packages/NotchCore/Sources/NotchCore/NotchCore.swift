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
    /// How many days the Calendar Widget shows each time the Nook opens.
    static let initialCalendarDays = 7
    /// Two reports whose durations differ by less than this are taken to be the same track.
    static let sameTrackDurationTolerance: TimeInterval = 1

    private let clock: any NotchClock
    private let displayLocator: any DisplayLocator
    private let fullscreenDetector: any FullscreenDetector
    private let levelChangeSource: any LevelChangeSource
    private let nowPlayingSource: any NowPlayingSource
    private let mediaController: any MediaController
    private let calendarSource: any CalendarSource
    private let frontAppSource: any FrontAppSource
    private let claudeCodeSource: any ClaudeCodeSource
    private let toDoSource: any ToDoSource
    private let dateDetector: any DateDetector
    private let trayStore: any TrayStore
    private let airDropSharer: any AirDropSharer
    @ObservationIgnored private var hoverTimer: (any TimerHandle)?
    @ObservationIgnored private var flashTimer: (any TimerHandle)?
    @ObservationIgnored private var pausedTimer: (any TimerHandle)?
    @ObservationIgnored private var calendarTimer: (any TimerHandle)?
    @ObservationIgnored private var activities: [ActivitySource: Activity] = [:]
    @ObservationIgnored private var isFullscreen = false
    @ObservationIgnored private var calendarAccess = CalendarAccess.denied
    @ObservationIgnored private var calendarDayCount = initialCalendarDays
    /// How many months from this one the Calendar view shows.
    @ObservationIgnored private var calendarMonthOffset = 0
    @ObservationIgnored private var selectedCalendarDay: Date?
    @ObservationIgnored private var frontApp: Int32?
    /// Claude Code sessions waiting for the user, the one that began waiting most recently last.
    @ObservationIgnored private var waitingClaudeSessions: [ClaudeSession] = []
    /// The to-dos Reminders reports as not done. `nil` without Reminders access.
    @ObservationIgnored private var openToDos: [ToDo]? = []
    /// To-dos ticked off since the Nook opened. They stay in the list, ticked, until it closes,
    /// so a mistaken tick can be undone.
    @ObservationIgnored private var doneToDos: [ToDo] = []
    /// The Tray item last clicked without ⇧, which a ⇧-click selects from.
    @ObservationIgnored private var traySelectionAnchor: URL?

    public init(
        clock: any NotchClock,
        displayLocator: any DisplayLocator,
        fullscreenDetector: any FullscreenDetector,
        levelChangeSource: any LevelChangeSource,
        nowPlayingSource: any NowPlayingSource,
        mediaController: any MediaController,
        calendarSource: any CalendarSource,
        frontAppSource: any FrontAppSource,
        claudeCodeSource: any ClaudeCodeSource,
        toDoSource: any ToDoSource,
        dateDetector: any DateDetector,
        trayStore: any TrayStore,
        airDropSharer: any AirDropSharer
    ) {
        self.clock = clock
        self.displayLocator = displayLocator
        self.fullscreenDetector = fullscreenDetector
        self.levelChangeSource = levelChangeSource
        self.nowPlayingSource = nowPlayingSource
        self.mediaController = mediaController
        self.calendarSource = calendarSource
        self.frontAppSource = frontAppSource
        self.claudeCodeSource = claudeCodeSource
        self.toDoSource = toDoSource
        self.dateDetector = dateDetector
        self.trayStore = trayStore
        self.airDropSharer = airDropSharer
        state.tray.files = trayStore.load()
        refreshTray()
        displayLocator.start { [weak self] placement in self?.displayChanged(placement) }
        fullscreenDetector.start { [weak self] isFullscreen in self?.fullscreenChanged(isFullscreen) }
        levelChangeSource.start { [weak self] change in self?.levelChanged(change) }
        nowPlayingSource.start { [weak self] nowPlaying in self?.nowPlayingChanged(nowPlaying) }
        calendarSource.start { [weak self] access in self?.calendarChanged(access) }
        frontAppSource.start { [weak self] app in self?.frontAppChanged(app) }
        claudeCodeSource.start { [weak self] report in self?.claudeCodeReported(report) }
        toDoSource.start { [weak self] toDos in self?.toDosChanged(toDos) }
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
        // To-Dos is for typing into, so it takes the keyboard.
        if view == .toDos { state.nookHasKeyboard = true }
        if view == .files { refreshTray() }
    }

    /// A drag carrying files came onto the Notch. It opens the Nook on Files, whatever view was
    /// last shown, so the files can be dropped straight away.
    public func dragEntered() {
        guard state.visibility != .absent else { return }
        hoverTimer?.cancel()
        hoverTimer = nil
        state.nook = .open(.files)
        refreshTray()
    }

    /// Switches the open Nook this many views along the view switcher, wrapping around its ends.
    public func switchNook(by offset: Int) {
        guard case .open(let view) = state.nook else { return }
        let views = NookView.allCases
        let index = views.firstIndex(of: view)! + offset
        switchNook(to: views[(index % views.count + views.count) % views.count])
    }

    /// The global shortcut. It opens the Nook on Home with the keyboard; on a Nook opened by
    /// hovering, it takes the keyboard; and on a Nook that has the keyboard, it closes it.
    public func toggleNook() {
        guard state.visibility != .absent else { return }
        switch state.nook {
        case .closed:
            hoverTimer?.cancel()
            hoverTimer = nil
            state.nook = .open(.home)
            state.nookHasKeyboard = true
        case .open where !state.nookHasKeyboard:
            state.nookHasKeyboard = true
        case .open:
            closeNook()
        }
    }

    /// Closes the Nook, as Escape does.
    public func dismissNook() {
        closeNook()
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

    /// The Calendar Widget is showing the day this many days from today. Nearing the last day
    /// brings in the week after it, so the days go on for as long as the user scrolls.
    public func calendarDayShown(_ index: Int) {
        let needed = index + Self.initialCalendarDays
        guard needed > calendarDayCount else { return }
        calendarDayCount = needed
        refreshCalendar()
    }

    /// Moves the Calendar view this many months later, or earlier when negative.
    public func moveCalendarMonth(by offset: Int) {
        calendarMonthOffset += offset
        selectedCalendarDay = nil
        refreshCalendar()
    }

    /// Selects the day starting at `date` in the Calendar view, to show its events.
    public func selectCalendarDay(_ date: Date) {
        selectedCalendarDay = date
        refreshCalendar()
    }

    /// Moves the Calendar view's selected day this many days later, or earlier when negative,
    /// into the month it lands in.
    public func moveCalendarDay(by days: Int) {
        guard let month = state.calendarMonth else { return }
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: days, to: month.selected)!
        let thisMonth = calendar.dateInterval(of: .month, for: clock.now)!.start
        let dayMonth = calendar.dateInterval(of: .month, for: day)!.start
        calendarMonthOffset = calendar.dateComponents([.month], from: thisMonth, to: dayMonth).month!
        selectedCalendarDay = day
        refreshCalendar()
    }

    /// Goes back to this month in the Calendar view, with today selected.
    public func showCalendarToday() {
        calendarMonthOffset = 0
        selectedCalendarDay = nil
        refreshCalendar()
    }

    /// The to-do `text` would add: its title, and the due date written in it, such as
    /// "Buy milk tomorrow 5pm". `nil` for blank text.
    public func quickAdd(_ text: String) -> QuickAdd? {
        QuickAdd(text, written: dateDetector.lastDate(in: text))
    }

    /// Adds the to-do typed as `text` to Reminders, due when the date written in it says.
    /// Blank text adds nothing.
    public func addToDo(_ text: String) {
        guard openToDos != nil, let toDo = quickAdd(text) else { return }
        toDoSource.add(toDo.title, due: toDo.due, isDueAtTime: toDo.isDueAtTime)
    }

    /// Ticks the to-do off in Reminders, or unticks it.
    public func setToDo(_ id: String, done: Bool) {
        guard let toDo = state.toDos?.first(where: { $0.id == id }), toDo.isDone != done else { return }
        var changed = toDo
        changed.isDone = done
        if done {
            doneToDos.append(changed)
        } else {
            doneToDos.removeAll { $0.id == id }
            // Shown as not done even before Reminders reports it again.
            openToDos?.removeAll { $0.id == id }
            openToDos?.append(changed)
        }
        toDoSource.setDone(id, done)
        refreshToDos()
    }

    /// Parks references to the files in the Tray. A file already in it isn't added again.
    /// Returns whether any file was added, so a drop that adds nothing can be turned down.
    @discardableResult
    public func dropIntoTray(_ files: [URL]) -> Bool {
        var added = false
        for file in files where file.isFileURL && !state.tray.files.contains(file) {
            state.tray.files.append(file)
            added = true
        }
        if added { trayStore.save(state.tray.files) }
        return added
    }

    /// A click on a Tray item. Selecting takes the keyboard, so Delete can remove the selection.
    public func selectTrayFile(_ file: URL, _ how: TraySelection) {
        guard let index = state.tray.files.firstIndex(of: file) else { return }
        switch how {
        case .only:
            state.tray.selection = [file]
        case .toggle where state.tray.selection.contains(file):
            state.tray.selection.remove(file)
        case .toggle:
            state.tray.selection.insert(file)
        case .range:
            let anchor = traySelectionAnchor.flatMap { state.tray.files.firstIndex(of: $0) } ?? index
            state.tray.selection.formUnion(state.tray.files[min(anchor, index)...max(anchor, index)])
        }
        if how != .range || traySelectionAnchor == nil { traySelectionAnchor = file }
        if case .open = state.nook { state.nookHasKeyboard = true }
    }

    /// A click on the Tray away from its items.
    public func clearTraySelection() {
        state.tray.selection = []
        traySelectionAnchor = nil
    }

    /// The × button on a Tray item. On a selected item it removes the whole selection.
    public func removeFromTray(_ file: URL) {
        removeTrayFiles(state.tray.selection.contains(file) ? state.tray.selection : [file])
    }

    /// The Delete key removes the selected Tray items.
    public func removeSelectedTrayFiles() {
        removeTrayFiles(state.tray.selection)
    }

    /// The files a drag starting on `file` carries out of the Tray: the selection, in Tray order,
    /// when `file` is in it, or else `file` alone.
    public func trayFilesToDrag(from file: URL) -> [URL] {
        guard state.tray.selection.contains(file) else { return [file] }
        return state.tray.files.filter(state.tray.selection.contains)
    }

    /// A drag out of the Tray finished. Files a destination accepted, even as a copy or an
    /// upload, have been delivered and leave the Tray; a cancelled or rejected drag keeps them.
    public func dragOutEnded(_ files: [URL], accepted: Bool) {
        guard accepted else { return }
        removeTrayFiles(Set(files))
    }

    /// Hands the files dropped onto the AirDrop Drop Zone to AirDrop. It takes files only, and
    /// returns whether it took any.
    @discardableResult
    public func dropOnAirDrop(_ files: [URL]) -> Bool {
        let files = files.filter(\.isFileURL)
        guard !files.isEmpty else { return false }
        airDropSharer.share(files)
        return true
    }

    /// Brings the Claude Code session in the Activity to the front. It no longer waits for the user.
    public func openClaudeSession() {
        guard case .claudeCode(let session, _) = activities[.claudeCode] else { return }
        claudeCodeSource.bringToFront(session)
        stopWaiting { $0.id == session.id }
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

    private func calendarChanged(_ access: CalendarAccess) {
        calendarAccess = access
        refreshCalendar()
    }

    /// Reads the Calendar Widget's days again, and schedules the next read for when what
    /// they show next changes with time.
    private func refreshCalendar() {
        calendarTimer?.cancel()
        calendarTimer = nil
        guard calendarAccess == .granted else {
            state.calendar = .accessDenied
            state.calendarMonth = nil
            activityEnded(.upcomingEvent)
            return
        }
        let now = clock.now
        let days = CalendarDays(at: now, count: calendarDayCount)
        let events = calendarSource.events(in: days.interval)
        state.calendar = .days(days.days(of: events))
        let month = CalendarMonth.span(offset: calendarMonthOffset, from: now)
        state.calendarMonth = CalendarMonth(
            span: month,
            events: calendarSource.events(in: month),
            selected: selectedCalendarDay,
            now: now
        )
        if let upcoming = days.upcomingEvent(in: events) {
            activityStarted(.upcomingEvent(upcoming))
        } else {
            activityEnded(.upcomingEvent)
        }
        let untilNextChange = days.nextChange(in: events).timeIntervalSince(now)
        calendarTimer = clock.schedule(after: .seconds(untilNextChange)) { [weak self] in
            self?.calendarTimer = nil
            self?.refreshCalendar()
        }
    }

    private func removeTrayFiles(_ files: Set<URL>) {
        guard !files.isEmpty else { return }
        state.tray.files.removeAll(where: files.contains)
        state.tray.selection.subtract(files)
        trayStore.save(state.tray.files)
    }

    /// Follows each Tray item to where its file is now, and drops the ones whose file is gone.
    private func refreshTray() {
        var located: [URL] = []
        var selection: Set<URL> = []
        for file in state.tray.files {
            // Two references can lead to the same file once one of them has been moved.
            guard let now = trayStore.locate(file), !located.contains(now) else { continue }
            located.append(now)
            if state.tray.selection.contains(file) { selection.insert(now) }
        }
        guard located != state.tray.files else { return }
        state.tray = Tray(files: located, selection: selection)
        trayStore.save(located)
    }

    private func toDosChanged(_ toDos: [ToDo]?) {
        openToDos = toDos
        if toDos == nil { doneToDos = [] }
        refreshToDos()
    }

    private func refreshToDos() {
        guard let openToDos else {
            state.toDos = nil
            return
        }
        let done = Set(doneToDos.map(\.id))
        state.toDos = (openToDos.filter { !done.contains($0.id) } + doneToDos).sorted(by: ToDo.isOrderedBefore)
    }

    /// A session that begins waiting while its app is in front is in plain sight, so it shows
    /// no Activity. Bringing a session's app to the front counts as going back to it.
    private func claudeCodeReported(_ report: ClaudeCodeReport) {
        switch report {
        case .waiting(let session):
            waitingClaudeSessions.removeAll { $0.id == session.id }
            if session.host == nil || session.host?.app != frontApp {
                waitingClaudeSessions.append(session)
            }
            refreshClaudeCodeActivity()
        case .working(let id), .ended(let id):
            stopWaiting { $0.id == id }
        }
    }

    private func frontAppChanged(_ app: Int32?) {
        frontApp = app
        guard let app else { return }
        stopWaiting { $0.host?.app == app }
    }

    private func stopWaiting(_ isDone: (ClaudeSession) -> Bool) {
        waitingClaudeSessions.removeAll(where: isDone)
        refreshClaudeCodeActivity()
    }

    private func refreshClaudeCodeActivity() {
        guard let latest = waitingClaudeSessions.last else {
            activityEnded(.claudeCode)
            return
        }
        activityStarted(.claudeCode(latest, waiting: waitingClaudeSessions.count))
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
        state.nookHasKeyboard = false
        // The Nook opens on today again, so the days and month moved to are no longer needed.
        if calendarDayCount != Self.initialCalendarDays || calendarMonthOffset != 0 || selectedCalendarDay != nil {
            calendarDayCount = Self.initialCalendarDays
            calendarMonthOffset = 0
            selectedCalendarDay = nil
            refreshCalendar()
        }
        if !doneToDos.isEmpty {
            doneToDos = []
            refreshToDos()
        }
        clearTraySelection()
    }
}
