/// Everything the shell needs to draw the Notch.
public struct NotchDisplayState: Equatable, Sendable {
    public var visibility: NotchVisibility = .absent
    public var nook: Nook = .closed
    public var activity: Activity?
    public var media: MediaWidget = .empty
}

public enum NotchVisibility: Equatable, Sendable {
    case absent
    case present(NotchPlacement)
}

public enum Nook: Equatable, Sendable {
    case closed
    case open(NookView)
}

public enum NookView: Equatable, Sendable {
    case home
    case files
}
