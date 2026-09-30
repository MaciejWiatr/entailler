import NotchCore
import Testing

@MainActor
struct DisplayPresenceTests {
    @Test func theNotchIsPresentWhereTheBuiltInDisplayPutsIt() {
        let harness = Harness(placement: .macBookPro)

        #expect(harness.state.visibility == .present(.macBookPro))
    }

    @Test func theNotchIsAbsentWithoutTheBuiltInNotchedDisplay() {
        let harness = Harness(placement: nil)

        #expect(harness.state.visibility == .absent)
    }

    @Test func hoveringDoesNotOpenTheNookWhileTheNotchIsAbsent() {
        let harness = Harness(placement: nil)

        harness.hover(for: .milliseconds(150))

        #expect(harness.state.nook == .closed)
    }

    @Test func losingTheDisplayMakesTheNotchAbsentAndClosesTheNook() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))

        harness.display.set(nil)

        #expect(harness.state.visibility == .absent)
        #expect(harness.state.nook == .closed)
    }

    @Test func losingTheDisplayMidHoverStopsTheNookFromOpening() {
        let harness = Harness()
        harness.hover(for: .milliseconds(100))

        harness.display.set(nil)
        harness.clock.advance(by: .milliseconds(100))

        #expect(harness.state.nook == .closed)
    }

    @Test func theNotchReappearsWhenTheDisplayReturns() {
        let harness = Harness()
        harness.display.set(nil)
        let returned = NotchPlacement(x: 0, y: 950, width: 200, height: 38)

        harness.display.set(returned)

        #expect(harness.state.visibility == .present(returned))
    }
}
