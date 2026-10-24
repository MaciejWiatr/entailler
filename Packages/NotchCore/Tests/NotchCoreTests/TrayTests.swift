import Foundation
import NotchCore
import Testing

@MainActor
struct TrayTests {
    let a = URL.file("a.png")
    let b = URL.file("b.png")
    let c = URL.file("c.pdf")
    let d = URL.file("d.zip")

    /// A harness with the Nook open on Files, holding these files.
    private func files(_ files: [URL]) -> Harness {
        let harness = Harness()
        harness.core.dragEntered()
        harness.core.dropIntoTray(files)
        return harness
    }

    @Test func aDragEnteringTheNotchOpensTheNookOnFiles() {
        let harness = Harness()

        harness.core.dragEntered()

        #expect(harness.state.nook == .open(.files))
    }

    @Test func aDragEnteringTheOpenNookSwitchesItToFiles() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))
        harness.core.switchNook(to: .calendar)

        harness.core.dragEntered()

        #expect(harness.state.nook == .open(.files))
    }

    @Test func aDragDoesNothingWithoutTheBuiltInDisplay() {
        let harness = Harness(placement: nil)

        harness.core.dragEntered()

        #expect(harness.state.nook == .closed)
    }

    @Test func droppingFilesAddsThemToTheTrayInOrder() {
        let harness = files([a, b])

        #expect(harness.state.tray.files == [a, b])
    }

    @Test func droppingAFileAlreadyInTheTrayDoesNotAddItAgain() {
        let harness = files([a, b])

        let added = harness.core.dropIntoTray([b, a])

        #expect(!added)
        #expect(harness.state.tray.files == [a, b])
    }

    @Test func droppingTheSameFileTwiceInOneDropAddsItOnce() {
        let harness = files([a, a, c])

        #expect(harness.state.tray.files == [a, c])
    }

    @Test func onlyFilesGoIntoTheTray() {
        let harness = files([URL(string: "https://example.com")!])

        #expect(harness.state.tray.files.isEmpty)
    }

    @Test func theTraySurvivesARestart() {
        let store = FakeTrayStore()
        let before = Harness(trayStore: store)
        before.core.dropIntoTray([a, b])

        let after = Harness(trayStore: store)

        #expect(after.state.tray.files == [a, b])
    }

    @Test func itemsWhoseFileIsGoneArePrunedAtLaunch() {
        let store = FakeTrayStore(saved: [a, b])
        store.delete(a)

        let harness = Harness(trayStore: store)

        #expect(harness.state.tray.files == [b])
        #expect(store.saved == [b])
    }

    @Test func itemsWhoseFileIsGoneArePrunedWhenFilesOpens() {
        let harness = files([a, b])
        harness.core.pointerExited()
        harness.trayStore.delete(b)

        harness.hover(for: .milliseconds(150))
        harness.core.switchNook(to: .files)

        #expect(harness.state.tray.files == [a])
    }

    @Test func anItemFollowsItsFileWhenItIsMoved() {
        let harness = files([a, b])
        harness.core.pointerExited()
        let moved = URL.file("Archive/a.png")
        harness.trayStore.move(a, to: moved)

        harness.core.dragEntered()

        #expect(harness.state.tray.files == [moved, b])
    }

    @Test func aPlainClickSelectsOnlyThatItem() {
        let harness = files([a, b, c])
        harness.core.selectTrayFile(a, .only)

        harness.core.selectTrayFile(b, .only)

        #expect(harness.state.tray.selection == [b])
    }

    @Test func commandClickAddsAndRemovesItemsFromTheSelection() {
        let harness = files([a, b, c])
        harness.core.selectTrayFile(a, .only)

        harness.core.selectTrayFile(c, .toggle)
        #expect(harness.state.tray.selection == [a, c])

        harness.core.selectTrayFile(a, .toggle)
        #expect(harness.state.tray.selection == [c])
    }

    @Test func shiftClickSelectsEveryItemFromTheLastClickedOne() {
        let harness = files([a, b, c, d])
        harness.core.selectTrayFile(d, .only)

        harness.core.selectTrayFile(b, .range)

        #expect(harness.state.tray.selection == [b, c, d])
    }

    @Test func selectingAnItemTakesTheKeyboardForTheDeleteKey() {
        let harness = files([a])

        harness.core.selectTrayFile(a, .only)

        #expect(harness.state.nookHasKeyboard)
    }

    @Test func theDeleteKeyRemovesEverySelectedItem() {
        let harness = files([a, b, c])
        harness.core.selectTrayFile(a, .only)
        harness.core.selectTrayFile(c, .toggle)

        harness.core.removeSelectedTrayFiles()

        #expect(harness.state.tray.files == [b])
        #expect(harness.state.tray.selection.isEmpty)
        #expect(harness.trayStore.saved == [b])
    }

    @Test func theRemoveButtonOnASelectedItemRemovesTheSelection() {
        let harness = files([a, b, c])
        harness.core.selectTrayFile(a, .only)
        harness.core.selectTrayFile(b, .toggle)

        harness.core.removeFromTray(b)

        #expect(harness.state.tray.files == [c])
    }

    @Test func theRemoveButtonOnAnUnselectedItemRemovesOnlyThatItem() {
        let harness = files([a, b, c])
        harness.core.selectTrayFile(a, .only)

        harness.core.removeFromTray(c)

        #expect(harness.state.tray.files == [a, b])
        #expect(harness.state.tray.selection == [a])
    }

    @Test func closingTheNookClearsTheSelection() {
        let harness = files([a])
        harness.core.selectTrayFile(a, .only)

        harness.core.pointerExited()

        #expect(harness.state.tray.selection.isEmpty)
    }

    @Test func draggingASelectedItemCarriesTheWholeSelectionInTrayOrder() {
        let harness = files([a, b, c])
        harness.core.selectTrayFile(c, .only)
        harness.core.selectTrayFile(a, .toggle)

        #expect(harness.core.trayFilesToDrag(from: c) == [a, c])
    }

    @Test func draggingAnUnselectedItemCarriesOnlyThatItem() {
        let harness = files([a, b, c])
        harness.core.selectTrayFile(a, .only)

        #expect(harness.core.trayFilesToDrag(from: b) == [b])
    }

    @Test func anAcceptedDragOutRemovesEveryDraggedItem() {
        let harness = files([a, b, c])

        harness.core.dragOutEnded([a, c], accepted: true)

        #expect(harness.state.tray.files == [b])
        #expect(harness.trayStore.saved == [b])
    }

    @Test func aCancelledDragOutKeepsTheItems() {
        let harness = files([a, b, c])

        harness.core.dragOutEnded([a, c], accepted: false)

        #expect(harness.state.tray.files == [a, b, c])
    }

    @Test func droppingFilesOnAirDropHandsThemToAirDrop() {
        let harness = Harness()
        harness.core.dragEntered()

        let taken = harness.core.dropOnAirDrop([a, b])

        #expect(taken)
        #expect(harness.airDrop.shared == [[a, b]])
        #expect(harness.state.tray.files.isEmpty)
    }

    @Test func airDropTurnsDownDropsWithNoFiles() {
        let harness = Harness()

        let taken = harness.core.dropOnAirDrop([URL(string: "https://example.com")!])

        #expect(!taken)
        #expect(harness.airDrop.shared.isEmpty)
    }
}
