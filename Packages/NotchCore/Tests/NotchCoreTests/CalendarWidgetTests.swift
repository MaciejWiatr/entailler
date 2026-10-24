import Foundation
import NotchCore
import Testing

@MainActor
struct CalendarWidgetTests {
    @Test func theCalendarWidgetListsTodaysRemainingEventsEarliestFirst() {
        let harness = Harness()
        let review = CalendarEvent.meeting("Review", at: .today(at: 15))
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 10))
        let breakfast = CalendarEvent.meeting("Breakfast", at: .today(at: 7))

        harness.calendar.set([review, standup, breakfast])

        #expect(harness.day(0)?.events == [standup, review])
    }

    @Test func anEventUnderwayIsStillListedUntilItEnds() {
        let harness = Harness()
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 8, 45))

        harness.calendar.set([standup])
        #expect(harness.day(0)?.events == [standup])

        harness.clock.advance(by: .seconds(15 * 60))
        #expect(harness.day(0)?.events == [])
    }

    @Test func todaysAllDayEventsAreOnTheAllDayLineAndNotAmongTheTimedOnes() {
        let harness = Harness()
        let holiday = CalendarEvent.allDay("Holiday", on: .today)
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 10))

        harness.calendar.set([standup, holiday])

        #expect(harness.day(0)?.allDay == [holiday])
        #expect(harness.day(0)?.events == [standup])
    }

    @Test func theDaysStartWithTodayAndFollowOneAnother() {
        let harness = Harness()

        #expect(harness.day(0)?.date == .today)
        #expect(harness.day(1)?.date == .tomorrow)
    }

    @Test func eachDayAfterTodayListsAllItsEventsAndItsAllDayLine() {
        let harness = Harness()
        let lunch = CalendarEvent.meeting("Lunch", at: .tomorrow(at: 12))
        let planning = CalendarEvent.meeting("Planning", at: .tomorrow(at: 9))
        let holiday = CalendarEvent.allDay("Holiday", on: .tomorrow)
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 10))

        harness.calendar.set([lunch, planning, holiday, standup])

        #expect(harness.day(0)?.events == [standup])
        #expect(harness.day(0)?.allDay == [])
        #expect(harness.day(1)?.events == [planning, lunch])
        #expect(harness.day(1)?.allDay == [holiday])
    }

    @Test func aWeekOfDaysIsShownAtFirst() {
        let harness = Harness()
        let nextWeek = CalendarEvent.meeting("Retro", at: .day(6, at: 10))
        let later = CalendarEvent.meeting("Offsite", at: .day(7, at: 10))

        harness.calendar.set([nextWeek, later])

        #expect(harness.days.count == 7)
        #expect(harness.day(6)?.events == [nextWeek])
    }

    @Test func showingTheLastDaysBringsInTheWeekAfter() {
        let harness = Harness()
        let later = CalendarEvent.meeting("Offsite", at: .day(10, at: 10))
        harness.calendar.set([later])
        harness.hover(for: .milliseconds(150))

        harness.core.calendarDayShown(6)

        #expect(harness.days.count == 13)
        #expect(harness.day(10)?.events == [later])
    }

    @Test func closingTheNookGoesBackToAWeekOfDays() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))
        harness.core.calendarDayShown(6)

        harness.core.pointerExited()

        #expect(harness.days.count == 7)
    }

    @Test func aMultiDayAllDayEventIsOnTheAllDayLineOfEachDayItCovers() {
        let harness = Harness()
        var trip = CalendarEvent.allDay("Trip", on: .today)
        trip.end = Date.day(3, at: 0)

        harness.calendar.set([trip])

        #expect(harness.days.prefix(4).map(\.allDay) == [[trip], [trip], [trip], []])
    }

    @Test func theCalendarWidgetUpdatesWhenEventsChange() {
        let harness = Harness()
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 10))
        harness.calendar.set([standup])
        var moved = standup
        moved.start = .today(at: 11)
        moved.end = .today(at: 11, 30)

        harness.calendar.set([moved])

        #expect(harness.day(0)?.events == [moved])
    }

    @Test func atMidnightTomorrowBecomesToday() {
        let harness = Harness()
        let review = CalendarEvent.meeting("Review", at: .today(at: 15))
        let today = CalendarEvent.allDay("Holiday", on: .today)
        let tomorrow = CalendarEvent.allDay("Out of office", on: .tomorrow)
        let planning = CalendarEvent.meeting("Planning", at: .tomorrow(at: 9))
        let retro = CalendarEvent.meeting("Retro", at: .day(2, at: 10))
        harness.calendar.set([review, today, tomorrow, planning, retro])

        harness.clock.advance(by: .seconds(15 * 3600))

        #expect(harness.day(0) == CalendarDay(date: .tomorrow, allDay: [tomorrow], events: [planning]))
        #expect(harness.day(1)?.events == [retro])
    }

    @Test func whenCalendarAccessIsDeniedTheCalendarWidgetSaysSo() {
        let harness = Harness()
        harness.calendar.set([.meeting("Standup", at: .today(at: 10))])

        harness.calendar.set(.denied)

        #expect(harness.state.calendar == .accessDenied)
    }

    @Test func grantingCalendarAccessLaterFillsTheCalendarWidget() {
        let harness = Harness()
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 10))
        harness.calendar.set(.denied)
        harness.calendar.set([standup])

        harness.calendar.set(.granted)

        #expect(harness.day(0)?.events == [standup])
    }
}

extension Harness {
    /// The days the Calendar Widget shows, or none if it says calendar access was denied.
    var days: [CalendarDay] {
        guard case .days(let days) = state.calendar else { return [] }
        return days
    }

    /// The Calendar Widget's day this many days from today.
    func day(_ index: Int) -> CalendarDay? {
        days.indices.contains(index) ? days[index] : nil
    }
}
