/// Everything the shell needs to draw the Notch.
public struct NotchDisplayState: Equatable, Sendable {
    public var visibility: NotchVisibility = .absent
    public var nook: Nook = .closed
    /// Whether the open Nook has the keyboard, so its keybindings work and To-Dos can be typed
    /// into. It takes the keyboard when opened with the global shortcut or on To-Dos, and keeps it
    /// until it closes.
    public var nookHasKeyboard = false
    public var activity: Activity?
    public var media: MediaWidget = .empty
    public var calendar: CalendarWidget = .days([])
    /// The month in the Nook's Calendar view. `nil` without calendar access.
    public var calendarMonth: CalendarMonth?
    /// The to-dos in the Nook's To-Dos view, in order. `nil` without Reminders access.
    public var toDos: [ToDo]? = []
    /// The files in the Nook's Files view.
    public var tray = Tray()
}

public enum NotchVisibility: Equatable, Sendable {
    case absent
    case present(NotchPlacement)
}

public enum Nook: Equatable, Sendable {
    case closed
    case open(NookView)
}

/// The Nook's views, in the order the view switcher shows them.
public enum NookView: Equatable, Sendable, CaseIterable {
    case home
    /// The days from the Calendar Widget, across the whole Nook.
    case calendar
    /// The user's to-dos from Apple Reminders.
    case toDos
    /// The Tray and the AirDrop Drop Zone.
    case files
}
