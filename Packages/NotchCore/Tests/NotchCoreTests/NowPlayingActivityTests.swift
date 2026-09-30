import NotchCore
import Testing

@MainActor
struct NowPlayingActivityTests {
    @Test func playingMediaShowsTheNowPlayingOngoingActivity() {
        let harness = Harness()

        harness.nowPlaying.set(.song)

        #expect(harness.state.activity?.source == .nowPlaying)
        #expect(harness.state.activity?.kind == .ongoing)
    }

    @Test func theNowPlayingActivityStaysForFiveSecondsAfterPausing() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.nowPlaying.set(NowPlaying.song.paused)
        harness.clock.advance(by: .milliseconds(4999))

        #expect(harness.state.activity?.source == .nowPlaying)
    }

    @Test func theNowPlayingActivityHidesFiveSecondsAfterPausing() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.nowPlaying.set(NowPlaying.song.paused)
        harness.clock.advance(by: .seconds(5))

        #expect(harness.state.activity == nil)
    }

    @Test func resumingWithinFiveSecondsKeepsTheNowPlayingActivity() {
        let harness = Harness()
        harness.nowPlaying.set(.song)
        harness.nowPlaying.set(NowPlaying.song.paused)
        harness.clock.advance(by: .seconds(3))

        harness.nowPlaying.set(.song)
        harness.clock.advance(by: .seconds(3))

        #expect(harness.state.activity?.source == .nowPlaying)
    }

    @Test func aTrackAlreadyPausedWhenReportedShowsNoActivity() {
        let harness = Harness()

        harness.nowPlaying.set(NowPlaying.song.paused)

        #expect(harness.state.activity == nil)
    }

    @Test func theNowPlayingActivityHidesAtOnceWhenMediaStopsBeingReported() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.nowPlaying.set(nil)

        #expect(harness.state.activity == nil)
    }

    @Test func theNowPlayingActivityIsHiddenInFullscreenAndReturnsAfterwards() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.fullscreen.set(true)
        #expect(harness.state.activity == nil)

        harness.fullscreen.set(false)
        #expect(harness.state.activity?.source == .nowPlaying)
    }

    @Test func theNowPlayingActivityGivesWayToAFlashActivityAndReturnsAfterIt() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.changeVolume()
        #expect(harness.state.activity?.source == .flash)

        harness.clock.advance(by: .milliseconds(1500))
        #expect(harness.state.activity?.source == .nowPlaying)
    }

    @Test func theNowPlayingActivityGivesWayToAnUpcomingEventAndReturnsAfterIt() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.core.activityStarted(.upcomingEvent)
        #expect(harness.state.activity?.source == .upcomingEvent)

        harness.core.activityEnded(.upcomingEvent)
        #expect(harness.state.activity?.source == .nowPlaying)
    }

    @Test func pausingWhileAFlashActivityShowsStillHidesNowPlayingFiveSecondsAfterThePause() {
        let harness = Harness()
        harness.nowPlaying.set(.song)
        harness.changeVolume()

        harness.nowPlaying.set(NowPlaying.song.paused)
        harness.clock.advance(by: .milliseconds(1500))
        #expect(harness.state.activity?.source == .nowPlaying)

        harness.clock.advance(by: .milliseconds(3500))
        #expect(harness.state.activity == nil)
    }
}
