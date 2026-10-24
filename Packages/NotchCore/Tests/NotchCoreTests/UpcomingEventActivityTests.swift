import Foundation
import NotchCore
import Testing

@MainActor
struct UpcomingEventActivityTests {
    @Test func noActivityShowsMoreThanFiveMinutesBeforeAnEvent() {
        let harness = Harness()
        harness.calendar.set([.meeting("Standup", at: .today(at: 9, 10))])

        harness.clock.advance(by: .seconds(4 * 60 + 59))

        #expect(harness.state.activity == nil)
    }

    @Test func theUpcomingEventActivityShowsFiveMinutesBeforeAnEventStarts() {
        let harness = Harness()
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 9, 10))
        harness.calendar.set([standup])

        harness.clock.advance(by: .seconds(5 * 60))

        #expect(harness.state.activity == .upcomingEvent(standup))
        #expect(harness.state.activity?.kind == .ongoing)
    }

    @Test func anEventStartingWithinFiveMinutesShowsTheActivityAsSoonAsItIsAdded() {
        let harness = Harness()
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 9, 3))

        harness.calendar.set([standup])

        #expect(harness.state.activity == .upcomingEvent(standup))
    }

    @Test func theUpcomingEventActivityEndsWhenTheEventStarts() {
        let harness = Harness()
        harness.calendar.set([.meeting("Standup", at: .today(at: 9, 3))])

        harness.clock.advance(by: .seconds(3 * 60))

        #expect(harness.state.activity == nil)
    }

    @Test func anAllDayEventNeverCreatesAnActivity() {
        let harness = Harness()
        let holiday = CalendarEvent.allDay("Holiday", on: .tomorrow)
        harness.calendar.set([holiday])

        harness.clock.advance(by: .seconds(15 * 3600 - 60))
        #expect(harness.state.activity == nil)

        harness.clock.advance(by: .seconds(60))
        #expect(harness.state.activity == nil)
        #expect(harness.day(0)?.allDay == [holiday])
    }

    @Test func ofTwoEventsAboutToStartTheSoonerOneIsShown() {
        let harness = Harness()
        let review = CalendarEvent.meeting("Review", at: .today(at: 9, 4))
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 9, 2))

        harness.calendar.set([review, standup])
        #expect(harness.state.activity == .upcomingEvent(standup))

        harness.clock.advance(by: .seconds(2 * 60))
        #expect(harness.state.activity == .upcomingEvent(review))
    }

    @Test func tomorrowsFirstEventShowsTheActivityAcrossMidnight() {
        let harness = Harness()
        let lateCall = CalendarEvent.meeting("Late call", at: .tomorrow(at: 0, 2))
        harness.calendar.set([lateCall])

        harness.clock.advance(by: .seconds(15 * 3600 - 3 * 60))

        #expect(harness.state.activity == .upcomingEvent(lateCall))
    }

    @Test func removingTheEventEndsTheActivity() {
        let harness = Harness()
        harness.calendar.set([.meeting("Standup", at: .today(at: 9, 3))])

        harness.calendar.set([])

        #expect(harness.state.activity == nil)
    }

    @Test func losingCalendarAccessEndsTheActivity() {
        let harness = Harness()
        harness.calendar.set([.meeting("Standup", at: .today(at: 9, 3))])

        harness.calendar.set(.denied)

        #expect(harness.state.activity == nil)
    }

    @Test func theUpcomingEventActivityRanksBelowAFlashActivityAndAboveNowPlaying() {
        let harness = Harness()
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 9, 3))
        harness.nowPlaying.set(.song)
        harness.calendar.set([standup])
        #expect(harness.state.activity == .upcomingEvent(standup))

        harness.changeVolume()
        #expect(harness.state.activity?.source == .flash)

        harness.clock.advance(by: .milliseconds(1500))
        #expect(harness.state.activity == .upcomingEvent(standup))

        harness.clock.advance(by: .seconds(3 * 60))
        #expect(harness.state.activity == .nowPlaying)
    }

    @Test func theUpcomingEventActivityIsHiddenInFullscreenAndReturnsAfterwards() {
        let harness = Harness()
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 9, 3))
        harness.calendar.set([standup])

        harness.fullscreen.set(true)
        #expect(harness.state.activity == nil)

        harness.fullscreen.set(false)
        #expect(harness.state.activity == .upcomingEvent(standup))
    }
}
