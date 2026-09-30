import NotchCore
import Testing

@MainActor
struct ActivitySlotTests {
    @Test func noActivityIsShownUntilOneStarts() {
        let harness = Harness()

        #expect(harness.state.activity == nil)
    }

    @Test func aVolumeChangeIsShownAsAFlashActivity() {
        let harness = Harness()

        harness.changeVolume()

        #expect(harness.state.activity?.source == .flash)
        #expect(harness.state.activity?.kind == .flash)
    }

    @Test func nowPlayingIsShownAsAnOngoingActivity() {
        let harness = Harness()

        harness.core.activityStarted(.nowPlaying)

        #expect(harness.state.activity?.source == .nowPlaying)
        #expect(harness.state.activity?.kind == .ongoing)
    }

    @Test(arguments: [
        [ActivitySource.nowPlaying, .upcomingEvent, .flash],
        [.flash, .upcomingEvent, .nowPlaying],
        [.upcomingEvent, .flash, .nowPlaying],
    ])
    func aFlashActivityWinsOverBothOngoingActivitiesWhateverTheOrder(order: [ActivitySource]) {
        let harness = Harness()

        for source in order {
            switch source {
            case .flash: harness.changeVolume()
            case .upcomingEvent: harness.core.activityStarted(.upcomingEvent(.standup))
            case .nowPlaying: harness.core.activityStarted(.nowPlaying)
            }
        }

        #expect(harness.state.activity?.source == .flash)
    }

    @Test func anUpcomingEventWinsOverNowPlaying() {
        let harness = Harness()

        harness.core.activityStarted(.upcomingEvent(.standup))
        harness.core.activityStarted(.nowPlaying)

        #expect(harness.state.activity?.source == .upcomingEvent)
    }

    @Test func eachLowerActivityReturnsInTurnAsHigherOnesEnd() {
        let harness = Harness()
        harness.core.activityStarted(.nowPlaying)
        harness.core.activityStarted(.upcomingEvent(.standup))
        harness.changeVolume()

        harness.clock.advance(by: .milliseconds(1500))
        #expect(harness.state.activity?.source == .upcomingEvent)

        harness.core.activityEnded(.upcomingEvent)
        #expect(harness.state.activity?.source == .nowPlaying)

        harness.core.activityEnded(.nowPlaying)
        #expect(harness.state.activity == nil)
    }

    @Test func endingALowerActivityLeavesTheHigherOneShown() {
        let harness = Harness()
        harness.core.activityStarted(.nowPlaying)
        harness.changeVolume()

        harness.core.activityEnded(.nowPlaying)

        #expect(harness.state.activity?.source == .flash)
    }
}
