import Foundation

/// An event from one of the user's calendars.
public struct CalendarEvent: Hashable, Sendable {
    /// Identifies the event in its calendar, so the shell can open it in Calendar.
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var url: URL?
    public var location: String?
    public var notes: String?

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        url: URL? = nil,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.url = url
        self.location = location
        self.notes = notes
    }
}

/// Whether Entailler may read the user's calendars.
public enum CalendarAccess: Equatable, Sendable {
    case granted
    case denied
}

/// What the Calendar Widget on Home shows.
public enum CalendarWidget: Equatable, Sendable {
    /// Calendar access was denied, so there are no events to show.
    case accessDenied
    /// Days from today on, one after another.
    case days([CalendarDay])
}

/// One day in the Calendar Widget.
public struct CalendarDay: Hashable, Sendable {
    /// The start of the day.
    public var date: Date
    /// The day's all-day events, shown together on one line at the top.
    public var allDay: [CalendarEvent]
    /// The day's other events, earliest first. Today's leave out those that have ended.
    public var events: [CalendarEvent]

    public init(date: Date, allDay: [CalendarEvent] = [], events: [CalendarEvent] = []) {
        self.date = date
        self.allDay = allDay
        self.events = events
    }
}

/// A month of days, shown as a grid in the Nook's Calendar view.
public struct CalendarMonth: Equatable, Sendable {
    /// The first day of the month.
    public var month: Date
    /// Every day of the month, first to last, each with all its events.
    public var days: [CalendarDay]
    /// The start of the day whose events show beside the grid.
    public var selected: Date
    /// The start of today, which the grid marks.
    public var today: Date

    public var selectedDay: CalendarDay? { days.first { $0.date == selected } }
}

/// The days the Calendar Widget covers, from today on, as seen at one moment.
struct CalendarDays {
    /// How long before an event starts the upcoming-event Activity shows.
    static let upcomingEventLead: TimeInterval = 5 * 60

    let now: Date
    let today: Date
    let tomorrow: Date
    /// The start of each day covered, from today on.
    let dates: [Date]
    private let end: Date

    init(at now: Date, count: Int, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let day = { (offset: Int) in calendar.date(byAdding: .day, value: offset, to: today)! }
        self.now = now
        self.today = today
        tomorrow = day(1)
        dates = (0..<count).map(day)
        end = day(count)
    }

    /// The span the Calendar Widget reads events from.
    var interval: DateInterval { DateInterval(start: today, end: end) }

    /// Each day's events. Today leaves out those that have ended, and also lists those that began
    /// before it and are still going. An all-day event is on every day it covers.
    func days(of events: [CalendarEvent]) -> [CalendarDay] {
        let events = events.sorted { $0.start < $1.start }
        return zip(dates, dates.dropFirst() + [end]).map { start, next in
            var day = calendarDay(from: start, to: next, of: events)
            if start == today {
                day.events = events.filter { !$0.isAllDay && $0.start < next && $0.end > now }
            }
            return day
        }
    }

    /// The soonest event starting within the next 5 minutes. All-day events never count.
    func upcomingEvent(in events: [CalendarEvent]) -> CalendarEvent? {
        events
            .filter { !$0.isAllDay && $0.start > now && $0.start.timeIntervalSince(now) <= Self.upcomingEventLead }
            .min { $0.start < $1.start }
    }

    /// The next moment after `now` when the Calendar Widget or the upcoming-event Activity changes
    /// on its own: an event comes within 5 minutes, starts or ends, or the day rolls over.
    func nextChange(in events: [CalendarEvent]) -> Date {
        let moments = events.filter { !$0.isAllDay }.flatMap { [$0.start - Self.upcomingEventLead, $0.start, $0.end] }
        return (moments + [tomorrow]).filter { $0 > now }.min()!
    }
}

extension CalendarMonth {
    /// The month this many months after the one `now` falls in.
    static func span(offset: Int, from now: Date, calendar: Calendar = .current) -> DateInterval {
        let thisMonth = calendar.dateInterval(of: .month, for: now)!.start
        return calendar.dateInterval(of: .month, for: calendar.date(byAdding: .month, value: offset, to: thisMonth)!)!
    }

    /// The month spanning `span`. The selected day is `selected` if it falls in the month, or else
    /// today if the month is this one, or else the month's first day.
    init(span: DateInterval, events: [CalendarEvent], selected: Date?, now: Date, calendar: Calendar = .current) {
        let isInMonth = { (date: Date) in date >= span.start && date < span.end }
        let dates = Array(sequence(first: span.start) { calendar.date(byAdding: .day, value: 1, to: $0)! }.prefix { isInMonth($0) })
        let events = events.sorted { $0.start < $1.start }
        let today = calendar.startOfDay(for: now)
        self.init(
            month: span.start,
            days: zip(dates, dates.dropFirst() + [span.end]).map { calendarDay(from: $0, to: $1, of: events) },
            selected: selected.flatMap { isInMonth($0) ? calendar.startOfDay(for: $0) : nil }
                ?? (isInMonth(today) ? today : span.start),
            today: today
        )
    }
}

/// The day from `start` until `next`: the all-day events covering it, and the other events that
/// start in it, in the order given.
private func calendarDay(from start: Date, to next: Date, of events: [CalendarEvent]) -> CalendarDay {
    CalendarDay(
        date: start,
        allDay: events.filter { $0.isAllDay && $0.start < next && $0.end > start },
        events: events.filter { !$0.isAllDay && $0.start >= start && $0.start < next }
    )
}

extension CalendarEvent {
    /// The Zoom, Google Meet, Microsoft Teams or FaceTime link to join the event with, if it has one.
    /// It's looked for in the event's URL, then its location, then its notes, and the first one wins.
    public var joinLink: URL? {
        [url?.absoluteString, location, notes].lazy.compactMap { $0.flatMap(meetingLink(in:)) }.first
    }

    /// What the Join button opens: the meeting link, except that a Google Meet link goes through
    /// Google's account chooser first, so the user picks which Google account joins.
    public var joinURL: URL? {
        guard let link = joinLink else { return nil }
        guard link.host() == "meet.google.com" else { return link }
        // The link's own query stays with it rather than being read as the chooser's.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        let meeting = link.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed)!
        return URL(string: "https://accounts.google.com/AccountChooser?continue=\(meeting)")
    }
}

private let linkDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

/// The first meeting link in `text`. A link written without its scheme comes back as https.
func meetingLink(in text: String) -> URL? {
    linkDetector.matches(in: text, range: NSRange(text.startIndex..., in: text)).lazy
        .compactMap(\.url)
        .compactMap { link -> URL? in
            guard var components = URLComponents(url: link, resolvingAgainstBaseURL: false),
                  let host = components.host?.lowercased(),
                  isMeetingLink(host: host, path: components.path)
            else { return nil }
            if components.scheme == "http" { components.scheme = "https" }
            return components.url
        }
        .first
}

/// Whether a link goes to a meeting on Zoom, Google Meet, Microsoft Teams or FaceTime, rather than
/// to another page on their sites, such as a download or settings page an invitation also links to.
private func isMeetingLink(host: String, path: String) -> Bool {
    let isHost = { (domain: String) in host == domain || host.hasSuffix("." + domain) }
    if isHost("zoom.us") || isHost("zoomgov.com") {
        return ["/j/", "/my/", "/s/", "/w/", "/wc/join/"].contains { path.hasPrefix($0) }
    }
    if host == "meet.google.com" {
        // A meeting code, such as abc-defg-hij, or a named meeting looked up by its organization.
        return path.wholeMatch(of: /\/[a-z]{3}-[a-z]{4}-[a-z]{3}/) != nil || path.hasPrefix("/lookup/")
    }
    if isHost("teams.microsoft.com") || isHost("teams.live.com") || isHost("teams.microsoft.us") {
        return path.hasPrefix("/l/meetup-join/") || path.hasPrefix("/meet/")
    }
    if host == "facetime.apple.com" {
        return path.hasPrefix("/join")
    }
    return false
}
