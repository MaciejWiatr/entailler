import NotchCore
import Testing

@MainActor
struct ActivitySlotTests {
    @Test func noActivityIsShownUntilOneStarts() {
        let harness = Harness()

        #expect(harness.state.activity == nil)
    }

    @Test func aFlashActivityIsShownAsAFlashActivity() {
        let harness = Harness()

        harness.core.activityStarted(Activity(source: .flash))

        #expect(harness.state.activity?.source == .flash)
        #expect(harness.state.activity?.kind == .flash)
    }

    @Test func nowPlayingIsShownAsAnOngoingActivity() {
        let harness = Harness()

        harness.core.activityStarted(Activity(source: .nowPlaying))

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
            harness.core.activityStarted(Activity(source: source))
        }

        #expect(harness.state.activity?.source == .flash)
    }

    @Test func anUpcomingEventWinsOverNowPlaying() {
        let harness = Harness()

        harness.core.activityStarted(Activity(source: .upcomingEvent))
        harness.core.activityStarted(Activity(source: .nowPlaying))

        #expect(harness.state.activity?.source == .upcomingEvent)
    }

    @Test func nowPlayingReturnsWhenAFlashActivityEnds() {
        let harness = Harness()
        harness.core.activityStarted(Activity(source: .nowPlaying))
        harness.core.activityStarted(Activity(source: .flash))

        harness.core.activityEnded(.flash)

        #expect(harness.state.activity?.source == .nowPlaying)
    }

    @Test func eachLowerActivityReturnsInTurnAsHigherOnesEnd() {
        let harness = Harness()
        harness.core.activityStarted(Activity(source: .nowPlaying))
        harness.core.activityStarted(Activity(source: .upcomingEvent))
        harness.core.activityStarted(Activity(source: .flash))

        harness.core.activityEnded(.flash)
        #expect(harness.state.activity?.source == .upcomingEvent)

        harness.core.activityEnded(.upcomingEvent)
        #expect(harness.state.activity?.source == .nowPlaying)

        harness.core.activityEnded(.nowPlaying)
        #expect(harness.state.activity == nil)
    }

    @Test func endingALowerActivityLeavesTheHigherOneShown() {
        let harness = Harness()
        harness.core.activityStarted(Activity(source: .nowPlaying))
        harness.core.activityStarted(Activity(source: .flash))

        harness.core.activityEnded(.nowPlaying)
        harness.core.activityEnded(.flash)

        #expect(harness.state.activity == nil)
    }
}
