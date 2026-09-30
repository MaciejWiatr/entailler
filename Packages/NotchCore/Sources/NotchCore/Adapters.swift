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
