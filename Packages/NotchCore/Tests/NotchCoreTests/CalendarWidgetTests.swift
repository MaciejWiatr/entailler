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

        #expect(harness.agenda?.today == [standup, review])
    }

    @Test func anEventUnderwayIsStillListedUntilItEnds() {
        let harness = Harness()
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 8, 45))

        harness.calendar.set([standup])
        #expect(harness.agenda?.today == [standup])

        harness.clock.advance(by: .seconds(15 * 60))
        #expect(harness.agenda?.today == [])
    }

    @Test func todaysAllDayEventsAreOnTheAllDayLineAndNotAmongTheTimedOnes() {
        let harness = Harness()
        let holiday = CalendarEvent.allDay("Holiday", on: .today)
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 10))

        harness.calendar.set([standup, holiday])

        #expect(harness.agenda?.allDay == [holiday])
        #expect(harness.agenda?.today == [standup])
    }

    @Test func tomorrowsFirstEventIsShownAfterTodays() {
        let harness = Harness()
        let lunch = CalendarEvent.meeting("Lunch", at: .tomorrow(at: 12))
        let planning = CalendarEvent.meeting("Planning", at: .tomorrow(at: 9))
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 10))

        harness.calendar.set([lunch, planning, standup])

        #expect(harness.agenda?.today == [standup])
        #expect(harness.agenda?.tomorrow == planning)
    }

    @Test func tomorrowsAllDayEventsAreNotShown() {
        let harness = Harness()
        let holiday = CalendarEvent.allDay("Holiday", on: .tomorrow)
        let planning = CalendarEvent.meeting("Planning", at: .tomorrow(at: 9))

        harness.calendar.set([holiday, planning])

        #expect(harness.agenda?.allDay == [])
        #expect(harness.agenda?.tomorrow == planning)
    }

    @Test func theCalendarWidgetUpdatesWhenEventsChange() {
        let harness = Harness()
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 10))
        harness.calendar.set([standup])
        var moved = standup
        moved.start = .today(at: 11)
        moved.end = .today(at: 11, 30)

        harness.calendar.set([moved])

        #expect(harness.agenda?.today == [moved])
    }

    @Test func atMidnightTomorrowsEventsBecomeTodaysAndTheAllDayLineMovesOn() {
        let harness = Harness()
        let review = CalendarEvent.meeting("Review", at: .today(at: 15))
        let today = CalendarEvent.allDay("Holiday", on: .today)
        let tomorrow = CalendarEvent.allDay("Out of office", on: .tomorrow)
        let planning = CalendarEvent.meeting("Planning", at: .tomorrow(at: 9))
        let lunch = CalendarEvent.meeting("Lunch", at: .tomorrow(at: 12))
        let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: .tomorrow)!
        let retro = CalendarEvent.meeting("Retro", at: dayAfter + 10 * 3600)
        harness.calendar.set([review, today, tomorrow, planning, lunch, retro])

        harness.clock.advance(by: .seconds(15 * 3600))

        #expect(harness.agenda == CalendarAgenda(allDay: [tomorrow], today: [planning, lunch], tomorrow: retro))
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

        #expect(harness.agenda?.today == [standup])
    }
}

extension Harness {
    /// What the Calendar Widget lists, or `nil` if it says calendar access was denied.
    var agenda: CalendarAgenda? {
        guard case .agenda(let agenda) = state.calendar else { return nil }
        return agenda
    }
}
