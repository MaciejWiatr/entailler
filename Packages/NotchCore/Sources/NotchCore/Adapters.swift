import Foundation

/// Where the Notch sits on the built-in display, in global screen coordinates
/// with the origin at the bottom left, as AppKit uses.
public struct NotchPlacement: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Reports whether the built-in notched display is present, and where its Notch is.
@MainActor
public protocol DisplayLocator: AnyObject {
    /// Reports the current placement right away, then again whenever it changes.
    /// `nil` means the built-in notched display is unavailable.
    func start(_ update: @escaping @MainActor (NotchPlacement?) -> Void)
}

/// Reports whether the front app is fullscreen.
@MainActor
public protocol FullscreenDetector: AnyObject {
    /// Reports the current value right away, then again whenever it changes.
    func start(_ update: @escaping @MainActor (Bool) -> Void)
}

/// Reports each change the user makes to the volume or display brightness. While it runs, the
/// system's own volume and brightness pop-ups stay hidden, since the Flash Activity replaces them.
@MainActor
public protocol LevelChangeSource: AnyObject {
    func start(_ update: @escaping @MainActor (LevelChange) -> Void)
}

/// Reports what the system's now-playing source is playing.
@MainActor
public protocol NowPlayingSource: AnyObject {
    /// Reports the current media as soon as it is known, then again whenever it changes.
    /// `nil` means nothing is playing or the source is unavailable.
    func start(_ update: @escaping @MainActor (NowPlaying?) -> Void)
}

/// Carries media commands to the system's now-playing source.
@MainActor
public protocol MediaController: AnyObject {
    func send(_ command: MediaCommand)
}

/// Reads events from all of the user's calendars.
@MainActor
public protocol CalendarSource: AnyObject {
    /// Asks for calendar access if it hasn't been asked for before, then reports whether it's granted.
    /// Reports again whenever events or access change, or the clock jumps, so the core looks again.
    func start(_ update: @escaping @MainActor (CalendarAccess) -> Void)
    /// Events from all calendars that overlap `interval`. Empty without access.
    func events(in interval: DateInterval) -> [CalendarEvent]
}

/// Reads the user's to-dos from Apple Reminders, and changes them there.
@MainActor
public protocol ToDoSource: AnyObject {
    /// Asks for Reminders access if it hasn't been asked for before, then reports the to-dos not
    /// yet done, from every list. Reports again whenever reminders or access change. `nil` means
    /// access is denied.
    func start(_ update: @escaping @MainActor ([ToDo]?) -> Void)
    /// Adds a to-do to the default Reminders list, due at `due` if it has a due date. A to-do due
    /// at a time of day reminds the user then.
    func add(_ title: String, due: Date?, isDueAtTime: Bool)
    /// Marks the to-do done, or not done again.
    func setDone(_ id: String, _ isDone: Bool)
}

/// Finds dates written in text, such as "tomorrow 5pm" or "next monday".
@MainActor
public protocol DateDetector: AnyObject {
    /// The last date written in `text`, if there is one.
    func lastDate(in text: String) -> WrittenDate?
}

/// Reports what Claude Code sessions are doing, and brings a session's app to the front.
@MainActor
public protocol ClaudeCodeSource: AnyObject {
    func start(_ update: @escaping @MainActor (ClaudeCodeReport) -> Void)
    /// Brings the app the session runs in to the front, with the session's tab or window if it can.
    func bringToFront(_ session: ClaudeSession)
}

/// Reports which app is in front.
@MainActor
public protocol FrontAppSource: AnyObject {
    /// Reports the front app's process identifier right away, then again whenever another app
    /// comes to the front. `nil` when no app is in front.
    func start(_ update: @escaping @MainActor (Int32?) -> Void)
}

/// Keeps the Tray's file references across restarts, and finds the files they point to.
@MainActor
public protocol TrayStore: AnyObject {
    /// The files saved last time, in order.
    func load() -> [URL]
    func save(_ files: [URL])
    /// Where the file is now, following it if it was moved or renamed. `nil` once it has been
    /// deleted, moved to the Trash, or can't be found.
    func locate(_ file: URL) -> URL?
}

/// Sends files with AirDrop.
@MainActor
public protocol AirDropSharer: AnyObject {
    /// Opens the AirDrop share sheet with the files.
    func share(_ files: [URL])
}
