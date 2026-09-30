import NotchCore
import Testing

@MainActor
struct FullscreenTests {
    @Test(arguments: [ActivitySource.nowPlaying, .upcomingEvent])
    func inFullscreenAnOngoingActivityIsNotShown(source: ActivitySource) {
        let harness = Harness()
        harness.fullscreen.set(true)

        harness.core.activityStarted(Activity(source: source))

        #expect(harness.state.activity == nil)
    }

    @Test func inFullscreenAPlayingTrackShowsNoActivityButAVolumeChangeDoes() {
        let harness = Harness()
        harness.fullscreen.set(true)
        harness.core.activityStarted(Activity(source: .nowPlaying))

        harness.core.activityStarted(Activity(source: .flash))

        #expect(harness.state.activity?.source == .flash)
    }

    @Test func goingFullscreenHidesTheOngoingActivityAndLeavingBringsItBack() {
        let harness = Harness()
        harness.core.activityStarted(Activity(source: .nowPlaying))

        harness.fullscreen.set(true)
        #expect(harness.state.activity == nil)

        harness.fullscreen.set(false)
        #expect(harness.state.activity?.source == .nowPlaying)
    }

    @Test func inFullscreenAFlashActivityEndingLeavesNothingShown() {
        let harness = Harness()
        harness.fullscreen.set(true)
        harness.core.activityStarted(Activity(source: .nowPlaying))
        harness.core.activityStarted(Activity(source: .flash))

        harness.core.activityEnded(.flash)

        #expect(harness.state.activity == nil)
    }

    @Test func inFullscreenHoveringStillOpensTheNook() {
        let harness = Harness()
        harness.fullscreen.set(true)

        harness.hover(for: .milliseconds(150))

        #expect(harness.state.nook == .open(.home))
    }
}
