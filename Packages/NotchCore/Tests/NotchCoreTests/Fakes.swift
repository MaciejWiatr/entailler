import Foundation
import NotchCore

/// A clock that only moves when a test calls `advance(by:)`.
@MainActor
final class FakeClock: NotchClock {
    private struct Pending {
        let id: Int
        let deadline: Duration
        let action: @MainActor () -> Void
    }

    private final class Handle: TimerHandle {
        let cancelAction: @MainActor () -> Void
        init(_ cancelAction: @escaping @MainActor () -> Void) { self.cancelAction = cancelAction }
        func cancel() { cancelAction() }
    }

    private var elapsed: Duration = .zero
    private var pending: [Pending] = []
    private var nextID = 0

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any TimerHandle {
        let id = nextID
        nextID += 1
        pending.append(Pending(id: id, deadline: elapsed + delay, action: action))
        return Handle { [weak self] in self?.pending.removeAll { $0.id == id } }
    }

    func advance(by duration: Duration) {
        let target = elapsed + duration
        while let next = pending.filter({ $0.deadline <= target }).min(by: { $0.deadline < $1.deadline }) {
            pending.removeAll { $0.id == next.id }
            elapsed = next.deadline
            next.action()
        }
        elapsed = target
    }
}

@MainActor
final class FakeDisplayLocator: DisplayLocator {
    private var update: (@MainActor (NotchPlacement?) -> Void)?
    private var placement: NotchPlacement?

    init(placement: NotchPlacement? = .macBookPro) {
        self.placement = placement
    }

    func start(_ update: @escaping @MainActor (NotchPlacement?) -> Void) {
        self.update = update
        update(placement)
    }

    func set(_ placement: NotchPlacement?) {
        self.placement = placement
        update?(placement)
    }
}

@MainActor
final class FakeFullscreenDetector: FullscreenDetector {
    private var update: (@MainActor (Bool) -> Void)?
    private var isFullscreen = false

    func start(_ update: @escaping @MainActor (Bool) -> Void) {
        self.update = update
        update(isFullscreen)
    }

    func set(_ isFullscreen: Bool) {
        self.isFullscreen = isFullscreen
        update?(isFullscreen)
    }
}

@MainActor
final class FakeLevelChangeSource: LevelChangeSource {
    private var update: (@MainActor (LevelChange) -> Void)?

    func start(_ update: @escaping @MainActor (LevelChange) -> Void) {
        self.update = update
    }

    func send(_ change: LevelChange) {
        update?(change)
    }
}

@MainActor
final class FakeNowPlayingSource: NowPlayingSource {
    private var update: (@MainActor (NowPlaying?) -> Void)?
    private var nowPlaying: NowPlaying?

    func start(_ update: @escaping @MainActor (NowPlaying?) -> Void) {
        self.update = update
        update(nowPlaying)
    }

    func set(_ nowPlaying: NowPlaying?) {
        self.nowPlaying = nowPlaying
        update?(nowPlaying)
    }
}

@MainActor
final class FakeMediaController: MediaController {
    private(set) var sent: [MediaCommand] = []

    func send(_ command: MediaCommand) {
        sent.append(command)
    }
}

extension NotchPlacement {
    static let macBookPro = NotchPlacement(x: 1545, y: 1085, width: 185, height: 32)
}

/// A Notch core wired to fakes, so a test can drive every input.
@MainActor
struct Harness {
    let clock = FakeClock()
    let display: FakeDisplayLocator
    let fullscreen = FakeFullscreenDetector()
    let levels = FakeLevelChangeSource()
    let nowPlaying = FakeNowPlayingSource()
    let mediaController = FakeMediaController()
    let core: NotchCore

    init(placement: NotchPlacement? = .macBookPro) {
        display = FakeDisplayLocator(placement: placement)
        core = NotchCore(
            clock: clock,
            displayLocator: display,
            fullscreenDetector: fullscreen,
            levelChangeSource: levels,
            nowPlayingSource: nowPlaying,
            mediaController: mediaController
        )
    }

    var state: NotchDisplayState { core.state }

    func hover(for duration: Duration) {
        core.pointerEntered()
        clock.advance(by: duration)
    }
}

extension Harness {
    /// Turns the volume to an arbitrary unmuted level.
    func changeVolume() {
        levels.send(.volume(level: 0.5, isMuted: false))
    }
}

extension NowPlaying {
    static let song = NowPlaying(
        app: "com.example.player",
        title: "Windowlicker",
        artist: "Aphex Twin",
        artwork: Data([0xFF, 0xD8]),
        duration: 367,
        elapsed: 42,
        elapsedAt: Date(timeIntervalSince1970: 1_000_000),
        isPlaying: true
    )

    var paused: NowPlaying {
        var copy = self
        copy.isPlaying = false
        return copy
    }

    /// The same track as its app sometimes publishes it: no artwork, and some other title.
    var sparse: NowPlaying {
        var copy = self
        copy.artwork = nil
        copy.title = "Player – Search"
        copy.artist = ""
        return copy
    }
}
