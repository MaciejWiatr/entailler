import NotchCore
import Testing

@MainActor
struct FullscreenTests {
    @Test(arguments: [Activity.nowPlaying, .upcomingEvent(.standup)])
    func inFullscreenAnOngoingActivityIsNotShown(activity: Activity) {
        let harness = Harness()
        harness.fullscreen.set(true)

        harness.core.activityStarted(activity)

        #expect(harness.state.activity == nil)
    }

    @Test func inFullscreenAPlayingTrackShowsNoActivityButAVolumeChangeDoes() {
        let harness = Harness()
        harness.fullscreen.set(true)
        harness.core.activityStarted(.nowPlaying)

        harness.changeVolume()

        #expect(harness.state.activity?.source == .flash)
    }

    @Test func goingFullscreenHidesTheOngoingActivityAndLeavingBringsItBack() {
        let harness = Harness()
        harness.core.activityStarted(.nowPlaying)

        harness.fullscreen.set(true)
        #expect(harness.state.activity == nil)

        harness.fullscreen.set(false)
        #expect(harness.state.activity?.source == .nowPlaying)
    }

    @Test func inFullscreenAFlashActivityEndingLeavesNothingShown() {
        let harness = Harness()
        harness.fullscreen.set(true)
        harness.core.activityStarted(.nowPlaying)
        harness.changeVolume()

        harness.clock.advance(by: .milliseconds(1500))

        #expect(harness.state.activity == nil)
    }

    @Test func inFullscreenHoveringStillOpensTheNook() {
        let harness = Harness()
        harness.fullscreen.set(true)

        harness.hover(for: .milliseconds(150))

        #expect(harness.state.nook == .open(.home))
    }
}
