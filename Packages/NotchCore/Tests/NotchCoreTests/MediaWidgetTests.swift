import Foundation
import NotchCore
import Testing

@MainActor
struct MediaWidgetTests {
    @Test func theMediaWidgetIsEmptyWhenNothingHasPlayed() {
        let harness = Harness()

        #expect(harness.state.media == .empty)
    }

    @Test func theMediaWidgetShowsTheTrackThatIsPlaying() {
        let harness = Harness()

        harness.nowPlaying.set(.song)

        #expect(harness.state.media == .track(.song))
    }

    @Test func theMediaWidgetKeepsShowingThePausedTrackAfterTheActivityHides() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.nowPlaying.set(NowPlaying.song.paused)
        harness.clock.advance(by: .seconds(5))

        #expect(harness.state.activity == nil)
        #expect(harness.state.media == .track(NowPlaying.song.paused))
    }

    @Test func theMediaWidgetIsEmptyWhenMediaStopsBeingReported() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.nowPlaying.set(nil)

        #expect(harness.state.media == .empty)
    }

    @Test func theProgressMovesOnWhilePlaying() {
        let harness = Harness()

        harness.nowPlaying.set(.song)

        #expect(harness.progress(after: 10) == 52)
    }

    @Test func theProgressStandsStillWhilePaused() {
        let harness = Harness()

        harness.nowPlaying.set(NowPlaying.song.paused)

        #expect(harness.progress(after: 10) == 42)
    }

    @Test func theProgressStopsAtTheEndOfTheTrack() {
        let harness = Harness()

        harness.nowPlaying.set(.song)

        #expect(harness.progress(after: 1000) == 367)
    }
}

extension Harness {
    /// The Media Widget's progress this many seconds after the track's position was measured.
    func progress(after seconds: TimeInterval) -> TimeInterval? {
        state.media.nowPlaying.map { $0.position(at: $0.elapsedAt.addingTimeInterval(seconds)) }
    }
}
