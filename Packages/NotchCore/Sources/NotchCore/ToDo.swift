import Foundation

/// A to-do from Apple Reminders.
public struct ToDo: Hashable, Sendable {
    /// Identifies the reminder, so it can be ticked off in Reminders.
    public var id: String
    public var title: String
    /// When it's due, if it has a due date.
    public var due: Date?
    /// Whether it's due at a time of day, rather than on a day.
    public var isDueAtTime: Bool
    /// When it was made, which orders the to-dos that have no due date.
    public var created: Date?
    /// The name of the Reminders list it's on.
    public var list: String
    public var isDone: Bool

    public init(
        id: String,
        title: String,
        due: Date? = nil,
        isDueAtTime: Bool = false,
        created: Date? = nil,
        list: String = "Reminders",
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.due = due
        self.isDueAtTime = isDueAtTime
        self.created = created
        self.list = list
        self.isDone = isDone
    }
}

/// A date written in text, as a `DateDetector` finds it.
public struct WrittenDate: Equatable, Sendable {
    /// Where in the text it's written.
    public var range: Range<String.Index>
    public var date: Date
    /// Whether a time of day was written, as in "tomorrow 5pm", rather than only a day.
    public var hasTime: Bool

    public init(range: Range<String.Index>, date: Date, hasTime: Bool) {
        self.range = range
        self.date = date
        self.hasTime = hasTime
    }
}

/// A new to-do as typed into the To-Dos view: its title, and the due date written in it, if any.
public struct QuickAdd: Equatable, Sendable {
    public var title: String
    public var due: Date?
    public var isDueAtTime: Bool

    public init(title: String, due: Date? = nil, isDueAtTime: Bool = false) {
        self.title = title
        self.due = due
        self.isDueAtTime = isDueAtTime
    }
}

extension QuickAdd {
    /// Words that only lead into a due date, as in "Pay rent on friday", and go with it.
    private static let leadIns: Set<String> = ["on", "at", "by", "due"]

    /// The to-do typed as `text`, with the date written in it taken out of its title and made its
    /// due date. Without a time of day it's due on the day. `nil` for blank text. Text that is only
    /// a date, such as "tomorrow", is taken as the title.
    init?(_ text: String, written: WrittenDate?, calendar: Calendar = .current) {
        let whole = Self.tidied(text)
        guard !whole.isEmpty else { return nil }
        guard let written else {
            self.init(title: whole)
            return
        }
        var before = Self.tidied(String(text[..<written.range.lowerBound])).split(separator: " ")
        if let last = before.last, Self.leadIns.contains(last.lowercased()) { before.removeLast() }
        let title = Self.tidied(before.joined(separator: " ") + " " + text[written.range.upperBound...])
        guard !title.isEmpty else {
            self.init(title: whole)
            return
        }
        self.init(
            title: title,
            due: written.hasTime ? written.date : calendar.startOfDay(for: written.date),
            isDueAtTime: written.hasTime
        )
    }

    /// `text` without surrounding spaces, and with the spaces inside it single.
    private static func tidied(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

extension ToDo {
    /// To-dos with a due date come first, soonest first, then the rest, oldest first, so a new
    /// to-do joins the end of the list.
    static func isOrderedBefore(_ a: ToDo, _ b: ToDo) -> Bool {
        switch (a.due, b.due) {
        case (let aDue?, let bDue?) where aDue != bDue: return aDue < bDue
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }
        switch (a.created, b.created) {
        case (let aCreated?, let bCreated?) where aCreated != bCreated: return aCreated < bCreated
        case (_?, nil): return true
        case (nil, _?): return false
        default: return (a.title, a.id) < (b.title, b.id)
        }
    }
}
