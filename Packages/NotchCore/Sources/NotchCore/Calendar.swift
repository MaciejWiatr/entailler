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
    case agenda(CalendarAgenda)
}

/// The events the Calendar Widget lists, in the order it lists them.
public struct CalendarAgenda: Equatable, Sendable {
    /// Today's all-day events, shown together on one line at the top.
    public var allDay: [CalendarEvent]
    /// Today's events that haven't ended yet, earliest first.
    public var today: [CalendarEvent]
    /// Tomorrow's first event that isn't all-day.
    public var tomorrow: CalendarEvent?

    public init(allDay: [CalendarEvent] = [], today: [CalendarEvent] = [], tomorrow: CalendarEvent? = nil) {
        self.allDay = allDay
        self.today = today
        self.tomorrow = tomorrow
    }

    public static let empty = CalendarAgenda()
}

/// The days the Calendar Widget covers, as seen at one moment.
struct CalendarDays {
    /// How long before an event starts the upcoming-event Activity shows.
    static let upcomingEventLead: TimeInterval = 5 * 60

    let now: Date
    let today: Date
    let tomorrow: Date
    let dayAfterTomorrow: Date

    init(at now: Date, calendar: Calendar = .current) {
        self.now = now
        today = calendar.startOfDay(for: now)
        tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)!
    }

    /// Today and tomorrow, the span the Calendar Widget reads events from.
    var interval: DateInterval { DateInterval(start: today, end: dayAfterTomorrow) }

    func agenda(of events: [CalendarEvent]) -> CalendarAgenda {
        let timed = events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
        return CalendarAgenda(
            allDay: events.filter { $0.isAllDay && $0.start < tomorrow && $0.end > today },
            today: timed.filter { $0.start < tomorrow && $0.end > now },
            tomorrow: timed.first { $0.start >= tomorrow }
        )
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

extension CalendarEvent {
    /// The Zoom, Google Meet, Microsoft Teams or FaceTime link to join the event with, if it has one.
    /// It's looked for in the event's URL, then its location, then its notes, and the first one wins.
    public var joinLink: URL? {
        [url?.absoluteString, location, notes].lazy.compactMap { $0.flatMap(meetingLink(in:)) }.first
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
