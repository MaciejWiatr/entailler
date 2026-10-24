import Foundation
import NotchCore
import Testing

@MainActor
struct NookKeyboardTests {
    @Test func theShortcutOpensTheNookOnHomeWithTheKeyboard() {
        let harness = Harness()

        harness.core.toggleNook()

        #expect(harness.state.nook == .open(.home))
        #expect(harness.state.nookHasKeyboard)
    }

    @Test func hoveringOpensTheNookWithoutTheKeyboard() {
        let harness = Harness()

        harness.hover(for: .milliseconds(150))

        #expect(!harness.state.nookHasKeyboard)
    }

    @Test func theShortcutOnANookOpenedByHoveringTakesTheKeyboard() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))

        harness.core.toggleNook()

        #expect(harness.state.nook == .open(.home))
        #expect(harness.state.nookHasKeyboard)
    }

    @Test func theShortcutClosesANookThatHasTheKeyboard() {
        let harness = Harness()
        harness.core.toggleNook()

        harness.core.toggleNook()

        #expect(harness.state.nook == .closed)
        #expect(!harness.state.nookHasKeyboard)
    }

    @Test func theShortcutDoesNothingWithoutTheNotchedDisplay() {
        let harness = Harness(placement: nil)

        harness.core.toggleNook()

        #expect(harness.state.nook == .closed)
    }

    @Test func toDosTakesTheKeyboardAndTheNookKeepsItUntilItCloses() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))

        harness.core.switchNook(to: .toDos)
        #expect(harness.state.nookHasKeyboard)

        harness.core.switchNook(to: .calendar)
        #expect(harness.state.nookHasKeyboard)

        harness.core.pointerExited()
        #expect(!harness.state.nookHasKeyboard)
    }

    @Test func escapeClosesTheNook() {
        let harness = Harness()
        harness.core.toggleNook()

        harness.core.dismissNook()

        #expect(harness.state.nook == .closed)
    }

    @Test func switchingByOffsetWrapsAroundTheViews() {
        let harness = Harness()
        harness.core.toggleNook()

        harness.core.switchNook(by: 1)
        #expect(harness.state.nook == .open(.calendar))

        harness.core.switchNook(by: -2)
        #expect(harness.state.nook == .open(.files))
    }

    @Test func movingTheSelectedDayStaysInTheMonth() {
        let harness = Harness()

        harness.core.moveCalendarDay(by: 7)

        #expect(harness.state.calendarMonth?.selected == .day(7, at: 0))
        #expect(harness.state.calendarMonth?.month == .day(-4, at: 0))
    }

    @Test func movingTheSelectedDayPastTheMonthMovesToTheNextMonth() {
        let harness = Harness()
        let november = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 2))!

        harness.core.moveCalendarDay(by: 28)

        #expect(harness.state.calendarMonth?.month == .day(27, at: 0))
        #expect(harness.state.calendarMonth?.selected == november)
    }

    @Test func movingTheSelectedDayBeforeTheMonthMovesToThePreviousMonth() {
        let harness = Harness()
        let september = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 30))!

        harness.core.moveCalendarDay(by: -5)

        #expect(harness.state.calendarMonth?.selected == september)
    }

    @Test func todayGoesBackToThisMonthWithTodaySelected() {
        let harness = Harness()
        harness.core.moveCalendarMonth(by: 3)

        harness.core.showCalendarToday()

        #expect(harness.state.calendarMonth?.month == .day(-4, at: 0))
        #expect(harness.state.calendarMonth?.selected == .today)
    }
}
