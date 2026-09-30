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
public enum Activity: Equatable, Sendable {
    /// A Flash Activity showing the level the user just changed.
    case flash(LevelChange)
    /// An Ongoing Activity counting down to an event that starts within 5 minutes.
    case upcomingEvent(CalendarEvent)
    case nowPlaying

    public var source: ActivitySource {
        switch self {
        case .flash: .flash
        case .upcomingEvent: .upcomingEvent
        case .nowPlaying: .nowPlaying
        }
    }

    public var kind: ActivityKind { source == .flash ? .flash : .ongoing }
}

/// A change the user made to the volume or display brightness. Levels run from 0 to 1.
public enum LevelChange: Equatable, Sendable {
    case volume(level: Double, isMuted: Bool)
    case brightness(level: Double)
}
