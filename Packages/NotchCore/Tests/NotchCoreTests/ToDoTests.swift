import Foundation
import NotchCore
import Testing

@MainActor
struct ToDoTests {
    @Test func toDosWithADueDateComeFirstSoonestFirstThenTheRestOldestFirst() {
        let harness = Harness()
        let milk = ToDo(id: "milk", title: "Buy milk", created: .day(-3, at: 9))
        let report = ToDo(id: "report", title: "Send report", due: .tomorrow, created: .day(-1, at: 9))
        let call = ToDo(id: "call", title: "Call the bank", due: .today(at: 14), isDueAtTime: true)
        let plants = ToDo(id: "plants", title: "Water plants", created: .day(-5, at: 9))

        harness.toDos.set([milk, report, call, plants])

        #expect(harness.state.toDos == [call, report, plants, milk])
    }

    @Test func remindersChangingElsewhereShowsAtOnce() {
        let harness = Harness()
        harness.toDos.set([.milk])

        harness.toDos.set([.milk, .plants])

        #expect(harness.state.toDos == [.plants, .milk])
    }

    @Test func tickingAToDoOffMarksItDoneInReminders() {
        let harness = Harness()
        harness.toDos.set([.milk, .plants])

        harness.core.setToDo("milk", done: true)

        #expect(harness.toDos.changes.map(\.id) == ["milk"])
        #expect(harness.toDos.changes.map(\.isDone) == [true])
        #expect(harness.state.toDos?.map(\.isDone) == [false, true])
    }

    @Test func aTickedToDoStaysTickedUntilTheNookCloses() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))
        harness.toDos.set([.milk, .plants])
        harness.core.setToDo("milk", done: true)

        // Reminders no longer reports it, as it's done.
        harness.toDos.set([.plants])
        #expect(harness.state.toDos?.map(\.id) == ["plants", "milk"])
        #expect(harness.state.toDos?.last?.isDone == true)

        harness.core.pointerExited()
        #expect(harness.state.toDos == [.plants])
    }

    @Test func untickingAToDoMarksItNotDoneAgain() {
        let harness = Harness()
        harness.toDos.set([.milk, .plants])
        harness.core.setToDo("milk", done: true)
        harness.toDos.set([.plants])

        harness.core.setToDo("milk", done: false)

        #expect(harness.toDos.changes.map(\.isDone) == [true, false])
        #expect(harness.state.toDos == [.plants, .milk])
    }

    @Test func tickingAToDoTheWayItAlreadyIsDoesNothing() {
        let harness = Harness()
        harness.toDos.set([.milk])

        harness.core.setToDo("milk", done: false)
        harness.core.setToDo("unknown", done: true)

        #expect(harness.toDos.changes.isEmpty)
    }

    @Test func addingAToDoAddsItToRemindersWithoutSurroundingSpaces() {
        let harness = Harness()

        harness.core.addToDo("  Book dentist \n")

        #expect(harness.toDos.added == [QuickAdd(title: "Book dentist")])
    }

    @Test func aDayWrittenInANewToDoMakesItDueThatDay() {
        let harness = Harness()
        harness.dates.teach("tomorrow", .tomorrow(at: 12), hasTime: false)

        harness.core.addToDo("Buy milk tomorrow")

        #expect(harness.toDos.added == [QuickAdd(title: "Buy milk", due: .tomorrow, isDueAtTime: false)])
    }

    @Test func aTimeWrittenInANewToDoMakesItDueThen() {
        let harness = Harness()
        harness.dates.teach("tomorrow 5pm", .tomorrow(at: 17), hasTime: true)

        harness.core.addToDo("Buy milk tomorrow 5pm")

        #expect(harness.toDos.added == [QuickAdd(title: "Buy milk", due: .tomorrow(at: 17), isDueAtTime: true)])
    }

    @Test func theWordLeadingIntoADateGoesWithIt() {
        let harness = Harness()
        harness.dates.teach("friday", .day(4, at: 12), hasTime: false)

        harness.core.addToDo("Pay rent on friday")

        #expect(harness.toDos.added.map(\.title) == ["Pay rent"])
    }

    @Test func aDateInTheMiddleOfANewToDoLeavesTheWordsAroundIt() {
        let harness = Harness()
        harness.dates.teach("at 9", .today(at: 21), hasTime: true)

        harness.core.addToDo("Call  Ann at 9 about the flat")

        #expect(harness.toDos.added.map(\.title) == ["Call Ann about the flat"])
    }

    @Test func aNewToDoThatIsOnlyADateKeepsItAsItsTitle() {
        let harness = Harness()
        harness.dates.teach("tomorrow", .tomorrow(at: 12), hasTime: false)

        harness.core.addToDo("tomorrow")

        #expect(harness.toDos.added == [QuickAdd(title: "tomorrow")])
    }

    @Test func quickAddPreviewsTheToDoWithoutAddingIt() {
        let harness = Harness()
        harness.dates.teach("tomorrow 5pm", .tomorrow(at: 17), hasTime: true)

        let preview = harness.core.quickAdd("Buy milk tomorrow 5pm")

        #expect(preview == QuickAdd(title: "Buy milk", due: .tomorrow(at: 17), isDueAtTime: true))
        #expect(harness.core.quickAdd("  ") == nil)
        #expect(harness.toDos.added.isEmpty)
    }

    @Test func aBlankToDoIsNotAdded() {
        let harness = Harness()

        harness.core.addToDo("   ")

        #expect(harness.toDos.added.isEmpty)
    }

    @Test func withoutRemindersAccessThereAreNoToDosAndNoneCanBeAdded() {
        let harness = Harness()
        harness.toDos.set([.milk])

        harness.toDos.set(access: false)
        harness.core.addToDo("Book dentist")

        #expect(harness.state.toDos == nil)
        #expect(harness.toDos.added.isEmpty)
    }
}

extension ToDo {
    static let milk = ToDo(id: "milk", title: "Buy milk", created: .day(-1, at: 9))
    static let plants = ToDo(id: "plants", title: "Water plants", created: .day(-5, at: 9))
}
