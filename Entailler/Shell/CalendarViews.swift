import AppKit
import NotchCore
import SwiftUI

/// The Calendar Widget on Home: a row of days from today on, swiped through sideways for as far
/// as the user likes. Each day has its all-day events on one line above its other events.
/// Clicking an event opens it in Calendar; a meeting gets a Join button.
struct CalendarWidgetView: View {
    let calendar: CalendarWidget
    let dayShown: (Int) -> Void

    /// How much of the next day shows at the trailing edge, hinting that the days scroll.
    private static let nextDayPeek: CGFloat = 28
    private static let daySpacing: CGFloat = 16
    /// How wide the fade is where the days run off the trailing edge.
    private static let edgeFade: CGFloat = 24

    var body: some View {
        switch calendar {
        case .accessDenied:
            AccessDeniedView()
        case .days(let days):
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Self.daySpacing) {
                    ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                        DayColumn(day: day, index: index)
                            .onAppear { dayShown(index) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.never)
            .mask { edgeFadeMask }
        }
    }

    /// Fades the days out where they run off the trailing edge.
    private var edgeFadeMask: some View {
        HStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: Self.edgeFade)
        }
    }

    /// One day: its name, then its events, scrolling down if they don't fit.
    private struct DayColumn: View {
        let day: CalendarDay
        /// How many days from today.
        let index: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                DayEvents(day: day, emptyText: index == 0 ? "Nothing else today" : "No events")
            }
            .containerRelativeFrame(.horizontal) { width, _ in
                width - CalendarWidgetView.nextDayPeek - CalendarWidgetView.daySpacing
            }
        }

        private var title: Text {
            switch index {
            case 0: Text("Today")
            case 1: Text("Tomorrow")
            default: Text(day.date, format: .dateTime.weekday(.wide).day().month(.abbreviated))
            }
        }
    }
}

/// A day's all-day line and its other events, scrolling down if they don't fit.
private struct DayEvents: View {
    let day: CalendarDay
    let emptyText: String

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 4) {
                if !day.allDay.isEmpty {
                    AllDayLine(events: day.allDay)
                }
                if day.events.isEmpty {
                    Text(emptyText)
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                        .frame(height: EventRow.height)
                }
                ForEach(day.events, id: \.self) { event in
                    EventRow(event: event)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }
}

private struct AllDayLine: View {
    let events: [CalendarEvent]

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10))
            Text(events.map(\.title).joined(separator: " · "))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.gray)
    }
}

/// An event's start time and title, and a Join button if it has a meeting link.
private struct EventRow: View {
    static let height: CGFloat = 20

    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 8) {
            Button {
                openInCalendar(event)
            } label: {
                HStack(spacing: 8) {
                    Text(event.start, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.gray)
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the event in Calendar")
            if let link = event.joinURL {
                Button("Join") {
                    NSWorkspace.shared.open(link)
                }
                .buttonStyle(JoinButtonStyle())
            }
        }
        .frame(height: Self.height)
    }
}

private struct JoinButtonStyle: ButtonStyle {
    var height: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: height < 18 ? 10 : 11, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, height < 18 ? 8 : 10)
            .frame(height: height)
            .background(.green, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct AccessDeniedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("No calendar access", systemImage: "calendar.badge.exclamationmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text("Entailler can't show your events until you allow it in System Settings.")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Privacy Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Opens `event` in Calendar.
private func openInCalendar(_ event: CalendarEvent) {
    let id = event.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.id
    guard let url = URL(string: "ical://ekevent/\(id)?method=show&options=more") else { return }
    NSWorkspace.shared.open(url)
}

/// The Nook's Calendar view: a month grid, and beside it a timeline of the month's days and their
/// events, which the grid's selected day follows. Swiping sideways on the trackpad, the chevrons,
/// or [ and ] move between months; the arrow keys move the selected day, and T goes to today.
struct CalendarMonthView: View {
    nonisolated static let height: CGFloat = MonthGrid.height

    /// `nil` without calendar access.
    let month: CalendarMonth?
    let move: (Int) -> Void
    let select: (Date) -> Void
    let moveDay: (Int) -> Void
    let showToday: () -> Void

    @State private var swipe = SwipeMonitor()
    /// Which way the last move went, so the next month slides in from that side.
    @State private var direction = 1

    var body: some View {
        if let month {
            content(month)
        } else {
            AccessDeniedView()
        }
    }

    private func content(_ month: CalendarMonth) -> some View {
        HStack(alignment: .top, spacing: 20) {
            MonthGrid(month: month, direction: direction, move: step, select: select)
                .frame(width: MonthGrid.width, alignment: .topLeading)
            // A hairline between the grid and the day, as tall as they are.
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: Self.height)
            MonthTimeline(month: month, select: select)
                .id(month.month)
                .transition(.opacity)
        }
        .onAppear { swipe.start(step) }
        .onDisappear { swipe.stop() }
        .onKeyDown { event in handleKey(event, in: month) }
    }

    private func handleKey(_ event: NSEvent, in month: CalendarMonth) -> Bool {
        guard event.heldModifiers.isEmpty else { return false }
        switch event.keyCode {
        case 123: stepDay(-1, in: month)
        case 124: stepDay(1, in: month)
        case 126: stepDay(-7, in: month)
        case 125: stepDay(7, in: month)
        default:
            switch event.charactersIgnoringModifiers {
            case "[": step(-1)
            case "]": step(1)
            case "t":
                let isThisMonth = month.days.contains { $0.date == month.today }
                guard !isThisMonth else {
                    showToday()
                    return true
                }
                direction = month.month > month.today ? -1 : 1
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) { showToday() }
            default: return false
            }
        }
        return true
    }

    private func step(_ offset: Int) {
        direction = offset
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) { move(offset) }
    }

    /// Moves the selected day, sliding in the month it lands in if that's another one.
    private func stepDay(_ days: Int, in month: CalendarMonth) {
        let day = Calendar.current.date(byAdding: .day, value: days, to: month.selected)!
        guard !month.days.contains(where: { $0.date == day }) else {
            moveDay(days)
            return
        }
        direction = days
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) { moveDay(days) }
    }
}

/// The month's days that have events, one under another, scrolling up and down. The day at the
/// top is the selected one: scrolling selects the day that reaches the top, and selecting a day
/// in the grid scrolls it, or the next day with events, there.
private struct MonthTimeline: View {
    let month: CalendarMonth
    let select: (Date) -> Void

    /// The day at the top of the timeline.
    @State private var topDay: Date?
    /// Only the user's own scrolling selects days, not scrolling to a day selected in the grid.
    @State private var isUserScrolling = false
    @State private var details = EventDetailsPresenter()

    private var days: [CalendarDay] {
        month.days.filter { !$0.events.isEmpty || !$0.allDay.isEmpty }
    }

    var body: some View {
        if days.isEmpty {
            Text("No events this month")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            timeline
        }
    }

    private var timeline: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                // Not lazy: a month's days are few, and laying them all out puts the selected one
                // exactly at the top, where a lazy stack's guessed heights put it off by a row or two.
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(days, id: \.date) { day in
                        TimelineDay(day: day, isToday: day.date == month.today)
                            .id(day.date)
                    }
                }
                .scrollTargetLayout()
            }
            // Room after the last day, so even it can scroll up to the top.
            .contentMargins(.bottom, max(0, proxy.size.height - 36), for: .scrollContent)
        }
        .scrollIndicators(.never)
        // Fades the days out where they run off the bottom edge.
        .mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 16)
            }
        }
        .overlayPreferenceValue(HoveredEventKey.self) { hovered in
            GeometryReader { proxy in
                if let hovered {
                    EventDetails(event: hovered.event, below: proxy[hovered.bounds], in: proxy.size) { inside in
                        details.cardHovered(inside)
                    }
                }
            }
        }
        .environment(details)
        .onDisappear { details.dismiss() }
        .scrollPosition(id: $topDay, anchor: .top)
        .onScrollPhaseChange { _, phase in
            isUserScrolling = phase == .tracking || phase == .interacting || phase == .decelerating
        }
        .onAppear { topDay = shownDay(for: month.selected) }
        .onChange(of: topDay) { _, day in
            guard isUserScrolling, let day, day != month.selected else { return }
            select(day)
        }
        .onChange(of: month.selected) { _, selected in
            let day = shownDay(for: selected)
            guard day != topDay else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0)) { topDay = day }
        }
    }

    /// The day the timeline shows for `date`: that day, or the next one with events, or the last.
    private func shownDay(for date: Date) -> Date? {
        days.first { $0.date >= date }?.date ?? days.last?.date
    }
}

/// One day in the timeline: its number and weekday on the line of its first event, red for
/// today, and beside them its all-day line and other events.
private struct TimelineDay: View {
    static let dateWidth: CGFloat = 46

    let day: CalendarDay
    let isToday: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(day.date, format: .dateTime.day())
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isToday ? .red : .white)
                Text(day.date, format: .dateTime.weekday(.abbreviated))
                    .textCase(.uppercase)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isToday ? .red : .gray)
            }
            .frame(width: Self.dateWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                if !day.allDay.isEmpty {
                    AllDayLine(events: day.allDay)
                        .frame(height: TimelineEventRow.height)
                }
                ForEach(day.events, id: \.self) { event in
                    TimelineEventRow(event: event)
                }
            }
        }
    }
}

/// An event in the timeline: its start time, title, and a video icon if it has a meeting link,
/// which turns into a Join button while the pointer is on the event. Resting the pointer on it
/// shows its details.
private struct TimelineEventRow: View {
    static let height: CGFloat = 18
    /// Room for the Join button, kept whether or not it shows, so titles don't shift under it.
    private static let joinWidth: CGFloat = 40

    let event: CalendarEvent

    @Environment(EventDetailsPresenter.self) private var details
    @State private var isHovered = false

    var body: some View {
        let showsDetails = details.shown == event
        row
            .background(
                isHovered || showsDetails ? Color.white.opacity(0.08) : .clear,
                in: RoundedRectangle(cornerRadius: 5).inset(by: -3)
            )
            .onHover { hovering in
                isHovered = hovering
                details.rowHovered(event, hovering)
            }
            .anchorPreference(key: HoveredEventKey.self, value: .bounds) { bounds in
                showsDetails ? HoveredEvent(event: event, bounds: bounds) : nil
            }
    }

    private var row: some View {
        HStack(spacing: 8) {
            Button {
                openInCalendar(event)
            } label: {
                HStack(spacing: 8) {
                    Text(event.start, format: .dateTime.hour().minute())
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.gray)
                        .frame(minWidth: 30, alignment: .leading)
                    Text(event.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the event in Calendar")
            if let link = event.joinURL {
                ZStack(alignment: .trailing) {
                    if isHovered || details.shown == event {
                        Button("Join") {
                            NSWorkspace.shared.open(link)
                        }
                        .buttonStyle(JoinButtonStyle(height: 16))
                        .transition(.scale(scale: 0.85, anchor: .trailing).combined(with: .opacity))
                    } else {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.gray)
                            .transition(.opacity)
                            .accessibilityLabel("Has a call")
                    }
                }
                .frame(width: Self.joinWidth, alignment: .trailing)
                .animation(.spring(duration: 0.2, bounce: 0.2), value: isHovered || details.shown == event)
            }
        }
        .frame(height: Self.height)
    }
}

/// Which event's details show, as the pointer moves over the timeline's events and their card.
/// Details show once the pointer has rested on an event a moment, so passing over the timeline
/// doesn't flash them, and then follow it to other events at once. They stay while the pointer
/// crosses from the event onto the card, so its links can be clicked.
///
/// Hover reports can come in either order, such as entering an event before leaving the card, so
/// they only record where the pointer is, and what shows is worked out from that.
@MainActor
@Observable
private final class EventDetailsPresenter {
    private static let showDelay: Duration = .milliseconds(250)
    /// Long enough to cross the gap between an event and its card.
    private static let hideDelay: Duration = .milliseconds(200)

    private(set) var shown: CalendarEvent?
    /// The event the pointer is on, if any.
    @ObservationIgnored private var hoveredRow: CalendarEvent?
    @ObservationIgnored private var isCardHovered = false
    /// What the pending change will show, so a repeat report doesn't restart its delay.
    @ObservationIgnored private var pendingTarget: CalendarEvent??
    @ObservationIgnored private var pending: Task<Void, Never>?

    nonisolated init() {}

    func rowHovered(_ event: CalendarEvent, _ inside: Bool) {
        if inside {
            hoveredRow = event
        } else if hoveredRow == event {
            hoveredRow = nil
        }
        update()
    }

    func cardHovered(_ inside: Bool) {
        isCardHovered = inside
        update()
    }

    func dismiss() {
        cancelPending()
        hoveredRow = nil
        isCardHovered = false
        shown = nil
    }

    private func update() {
        if let row = hoveredRow {
            if shown == nil {
                schedule(row, after: Self.showDelay)
            } else {
                cancelPending()
                show(row)
            }
        } else if isCardHovered, shown != nil {
            cancelPending()
        } else if shown != nil {
            schedule(nil, after: Self.hideDelay)
        } else {
            cancelPending()
        }
    }

    private func show(_ event: CalendarEvent?) {
        guard event != shown else { return }
        // The card is replaced, and a removed card never reports the pointer leaving it.
        isCardHovered = false
        withAnimation(event == nil ? .spring(duration: 0.2, bounce: 0) : .spring(duration: 0.3, bounce: 0.2)) {
            shown = event
        }
    }

    private func schedule(_ target: CalendarEvent?, after delay: Duration) {
        guard pendingTarget != .some(target) else { return }
        cancelPending()
        pendingTarget = .some(target)
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.pendingTarget = nil
            self.pending = nil
            self.show(target)
        }
    }

    private func cancelPending() {
        pending?.cancel()
        pending = nil
        pendingTarget = nil
    }
}

/// The timeline event the pointer rests on, and where its row is.
private struct HoveredEvent {
    let event: CalendarEvent
    let bounds: Anchor<CGRect>
}

private struct HoveredEventKey: PreferenceKey {
    static let defaultValue: HoveredEvent? = nil

    static func reduce(value: inout HoveredEvent?, nextValue: () -> HoveredEvent?) {
        value = value ?? nextValue()
    }
}

/// A card with an event's full title, when it is, where, and the start of its notes. It shows
/// under the event's row, or over it when the row is in the lower half of the timeline. Its
/// meeting link, and any links in its notes, open when clicked.
private struct EventDetails: View {
    let event: CalendarEvent
    /// The event's row.
    let row: CGRect
    /// The timeline's size.
    let size: CGSize
    let hovered: (Bool) -> Void

    init(event: CalendarEvent, below row: CGRect, in size: CGSize, hovered: @escaping (Bool) -> Void) {
        self.event = event
        self.row = row
        self.size = size
        self.hovered = hovered
    }

    private static let gap: CGFloat = 6
    private var isBelow: Bool { row.midY < size.height / 2 }

    var body: some View {
        card
            .onHover(perform: hovered)
            .padding(.top, isBelow ? row.maxY + Self.gap : 0)
            .padding(.bottom, isBelow ? 0 : size.height - row.minY + Self.gap)
            .frame(width: size.width, height: size.height, alignment: isBelow ? .top : .bottom)
            .transition(.scale(scale: 0.96, anchor: isBelow ? .top : .bottom).combined(with: .opacity))
            .id(event)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            detail("clock", time)
            if let link = event.joinLink {
                detail("video.fill", Text(meetingService(link)) + Text("  ") + Text(meetingLink(link)))
            }
            if let location = event.location, !location.isEmpty, location != event.joinLink?.absoluteString {
                detail("mappin.and.ellipse", Text(linked(location)))
            }
            if let notes = event.notes.flatMap(description), !notes.isEmpty {
                Text(linked(notes))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.gray)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(Color(red: 0.45, green: 0.7, blue: 1))
        // The Google Meet link goes through Google's account chooser, as the Join button does.
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url == event.joinLink ? event.joinURL ?? url : url)
            return .handled
        })
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
    }

    private func detail(_ symbol: String, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: symbol)
                .frame(width: 12)
            text.lineLimit(1)
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.75))
    }

    /// "09:00 – 09:30 · 30 min", or "All day".
    private var time: Text {
        guard !event.isAllDay else { return Text("All day") }
        let length = Duration.seconds(event.end.timeIntervalSince(event.start))
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        let start = event.start.formatted(.dateTime.hour().minute())
        let end = event.end.formatted(.dateTime.hour().minute())
        return Text("\(start) – \(end) · \(length)")
    }

    /// The app a meeting link is for.
    private func meetingService(_ link: URL) -> String {
        let host = link.host()?.lowercased() ?? ""
        if host.contains("zoom") { return "Zoom" }
        if host == "meet.google.com" { return "Google Meet" }
        if host.contains("teams") { return "Microsoft Teams" }
        return "FaceTime"
    }

    /// The meeting link as a link, written without its scheme or query, such as
    /// "meet.google.com/abc-defg-hij".
    private func meetingLink(_ link: URL) -> AttributedString {
        var text = AttributedString((link.host() ?? "") + link.path())
        text.link = link
        text.underlineStyle = .single
        return text
    }

    /// `text` with the links in it clickable and the link colour. A link written without its
    /// scheme opens over https.
    private func linked(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for match in Self.linkDetector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let url = match.url, let range = Range(match.range, in: text),
                  let linkRange = Range(range, in: attributed)
            else { continue }
            attributed[linkRange].link = url
            attributed[linkRange].underlineStyle = .single
        }
        return attributed
    }

    private static let linkDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// What the organizer wrote about the event, on one line. Google Meet and Teams add their
    /// joining details after a divider line, which is left out with everything after it. Notes
    /// with the meeting link in them are all joining details, as Zoom writes them, so there's none.
    private func description(_ notes: String) -> String? {
        let lines = notes.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let isDivider = { (line: Substring) in
            line.count >= 5 && !line.contains { $0.isLetter || $0.isNumber || $0.isWhitespace }
        }
        let written = lines.prefix { !isDivider($0) }
        if let link = event.joinLink?.host(), written.contains(where: { $0.contains(link) }) { return nil }
        return written
            .filter { line in line.contains { $0.isLetter } }
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .joined(separator: " ")
    }
}

/// A month's days laid out by week, under the month's name and the weekday initials. Today is
/// marked in red, the selected day with a ring, and days with events with a dot. Moving to
/// another month slides only the days, from the side of `direction`; the name and initials stay.
private struct MonthGrid: View {
    nonisolated static let cellSize = CGSize(width: 28, height: 18)
    nonisolated static let width = cellSize.width * 7
    /// Room between the month's name and the weekday initials.
    nonisolated static let headerGap: CGFloat = 8
    /// The month's name, the weekday initials, and six weeks, enough for any month.
    nonisolated static let height: CGFloat = 18 + headerGap + 14 + cellSize.height * 6 + 4

    let month: CalendarMonth
    /// Which way the last move went: later months come in from the trailing side.
    let direction: Int
    let move: (Int) -> Void
    let select: (Date) -> Void

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                Text(month.month, format: .dateTime.month(.wide).year())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                chevron("chevron.left", label: "Previous month", offset: -1)
                chevron("chevron.right", label: "Next month", offset: 1)
            }
            .frame(height: 18)
            .padding(.bottom, Self.headerGap)
            HStack(spacing: 0) {
                ForEach(Array(weekdayInitials.enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .frame(width: Self.cellSize.width)
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.gray)
            .frame(height: 14)
            ZStack(alignment: .top) {
                days
                    .id(month.month)
                    .transition(.asymmetric(
                        insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .frame(width: Self.width, height: Self.cellSize.height * 6, alignment: .top)
            .clipped()
        }
        .frame(height: Self.height, alignment: .top)
    }

    private var days: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.cellSize.width), spacing: 0), count: 7), spacing: 0) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: Self.cellSize.height)
            }
            ForEach(month.days, id: \.date) { day in
                DayCell(day: day, isToday: day.date == month.today, isSelected: day.date == month.selected) {
                    select(day.date)
                }
            }
        }
    }

    /// The weekday initials, starting on the user's first day of the week.
    private var weekdayInitials: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Empty cells before the first of the month, so it falls under its weekday.
    private var leadingBlanks: Int {
        (calendar.component(.weekday, from: month.month) - calendar.firstWeekday + 7) % 7
    }

    private func chevron(_ symbol: String, label: String, offset: Int) -> some View {
        Button {
            move(offset)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.gray)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private struct DayCell: View {
        let day: CalendarDay
        let isToday: Bool
        let isSelected: Bool
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                ZStack {
                    Circle()
                        .fill(isToday ? Color.red : isSelected ? .white.opacity(0.18) : .clear)
                        .frame(width: 17, height: 17)
                    Text(day.date, format: .dateTime.day())
                        .font(.system(size: 10, weight: isToday || isSelected ? .bold : .medium).monospacedDigit())
                        .foregroundStyle(.white)
                    if !day.events.isEmpty || !day.allDay.isEmpty {
                        Circle()
                            .fill(.white.opacity(0.55))
                            .frame(width: 3, height: 3)
                            .offset(y: 7.5)
                    }
                }
                .frame(width: MonthGrid.cellSize.width, height: MonthGrid.cellSize.height)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide)))
        }
    }
}

/// Turns a sideways two-finger swipe on the trackpad into one step: a month later for a swipe to
/// the left, as when turning a page, and a month earlier for one to the right.
@MainActor
private final class SwipeMonitor {
    /// How far the fingers travel sideways before the swipe counts.
    private static let threshold: CGFloat = 40

    private var monitor: Any?
    private var travel: CGFloat = 0
    private var hasStepped = false

    nonisolated init() {}

    func start(_ step: @escaping @MainActor (Int) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event, step) }
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent, _ step: (Int) -> Void) {
        // Momentum after the fingers lift is ignored, so one swipe moves one month.
        guard event.momentumPhase.isEmpty else { return }
        if event.phase.contains(.began) {
            travel = 0
            hasStepped = false
        }
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }
        // The way the fingers moved, whether or not scrolling is natural.
        travel += event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        guard !hasStepped, abs(travel) > Self.threshold else { return }
        hasStepped = true
        step(travel < 0 ? 1 : -1)
    }
}

/// The minutes left until an upcoming event starts, counting down beside the Notch.
struct EventCountdown: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("\(minutesLeft(at: context.date))m")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
        }
    }

    /// Rounded up, so the last minute reads 1m rather than 0m.
    private func minutesLeft(at date: Date) -> Int {
        max(1, Int((start.timeIntervalSince(date) / 60).rounded(.up)))
    }
}

