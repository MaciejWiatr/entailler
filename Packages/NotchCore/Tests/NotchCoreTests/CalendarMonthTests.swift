import Foundation
import NotchCore
import Testing

@MainActor
struct CalendarMonthTests {
    @Test func theCalendarShowsEveryDayOfThisMonthWithTodaySelected() {
        let harness = Harness()

        #expect(harness.month?.month == .day(-4, at: 0))
        #expect(harness.month?.days.count == 31)
        #expect(harness.month?.days.first?.date == .day(-4, at: 0))
        #expect(harness.month?.selected == .today)
    }

    @Test func eachDayOfTheMonthListsAllItsEventsIncludingThoseThatHaveEnded() {
        let harness = Harness()
        let breakfast = CalendarEvent.meeting("Breakfast", at: .today(at: 7))
        let standup = CalendarEvent.meeting("Standup", at: .today(at: 10))
        let lastWeek = CalendarEvent.meeting("Retro", at: .day(-3, at: 10))
        let holiday = CalendarEvent.allDay("Holiday", on: .day(-2, at: 0))

        harness.calendar.set([standup, breakfast, lastWeek, holiday])

        #expect(harness.monthDay(.today)?.events == [breakfast, standup])
        #expect(harness.monthDay(.day(-3, at: 0))?.events == [lastWeek])
        #expect(harness.monthDay(.day(-2, at: 0))?.allDay == [holiday])
    }

    @Test func selectingADayShowsItsEvents() {
        let harness = Harness()
        let retro = CalendarEvent.meeting("Retro", at: .day(3, at: 10))
        harness.calendar.set([retro])

        harness.core.selectCalendarDay(.day(3, at: 0))

        #expect(harness.month?.selected == .day(3, at: 0))
        #expect(harness.month?.selectedDay?.events == [retro])
    }

    @Test func movingToTheNextMonthShowsItWithItsFirstDaySelected() {
        let harness = Harness()
        let november = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let offsite = CalendarEvent.meeting("Offsite", at: november + 10 * 3600)
        harness.calendar.set([offsite])

        harness.core.moveCalendarMonth(by: 1)

        #expect(harness.month?.month == november)
        #expect(harness.month?.days.count == 30)
        #expect(harness.month?.selected == november)
        #expect(harness.month?.selectedDay?.events == [offsite])
    }

    @Test func movingBackToThisMonthSelectsTodayAgain() {
        let harness = Harness()
        harness.core.moveCalendarMonth(by: -1)

        harness.core.moveCalendarMonth(by: 1)

        #expect(harness.month?.month == .day(-4, at: 0))
        #expect(harness.month?.selected == .today)
    }

    @Test func closingTheNookGoesBackToThisMonthAndToday() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))
        harness.core.moveCalendarMonth(by: 2)
        harness.core.selectCalendarDay(.day(60, at: 0))

        harness.core.pointerExited()

        #expect(harness.month?.month == .day(-4, at: 0))
        #expect(harness.month?.selected == .today)
    }

    @Test func withoutCalendarAccessThereIsNoMonth() {
        let harness = Harness()

        harness.calendar.set(.denied)

        #expect(harness.month == nil)
    }
}

extension Harness {
    var month: CalendarMonth? { state.calendarMonth }

    func monthDay(_ date: Date) -> CalendarDay? {
        month?.days.first { $0.date == date }
    }
}
