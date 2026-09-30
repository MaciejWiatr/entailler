/// Where an Activity comes from. Each source fills at most one place in the Activity slot.
/// Cases are declared in priority order, highest first.
public enum ActivitySource: Sendable, CaseIterable {
    case flash
    case upcomingEvent
    case nowPlaying
}

public enum ActivityKind: Sendable {
    case flash
    case ongoing
}

/// Glanceable status shown beside the collapsed Notch.
public struct Activity: Equatable, Sendable {
    public var source: ActivitySource

    public init(source: ActivitySource) {
        self.source = source
    }

    public var kind: ActivityKind { source == .flash ? .flash : .ongoing }
}
