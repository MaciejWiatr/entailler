import NotchCore
import Testing

@MainActor
struct NookTests {
    @Test func restingOnTheNotchForTheHoverDelayOpensTheNookOnHome() {
        let harness = Harness()

        harness.hover(for: .milliseconds(150))

        #expect(harness.state.nook == .open(.home))
    }

    @Test func aPassShorterThanTheHoverDelayDoesNotOpenTheNook() {
        let harness = Harness()

        harness.hover(for: .milliseconds(100))
        harness.core.pointerExited()
        harness.clock.advance(by: .seconds(1))

        #expect(harness.state.nook == .closed)
    }

    @Test func thePointerLeavingTheOpenNookClosesIt() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))

        harness.core.pointerExited()

        #expect(harness.state.nook == .closed)
    }

    @Test func theOpenNookSwitchesBetweenHomeAndFiles() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))

        harness.core.switchNook(to: .files)
        #expect(harness.state.nook == .open(.files))

        harness.core.switchNook(to: .home)
        #expect(harness.state.nook == .open(.home))
    }

    @Test func switchingViewsDoesNothingWhileTheNookIsClosed() {
        let harness = Harness()

        harness.core.switchNook(to: .files)

        #expect(harness.state.nook == .closed)
    }

    @Test func thePointerEnteringAgainWhileOpenKeepsTheCurrentView() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))
        harness.core.switchNook(to: .files)

        harness.hover(for: .milliseconds(150))

        #expect(harness.state.nook == .open(.files))
    }

    @Test func reopeningByHoverAlwaysLandsOnHome() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))
        harness.core.switchNook(to: .files)
        harness.core.pointerExited()

        harness.hover(for: .milliseconds(150))

        #expect(harness.state.nook == .open(.home))
    }

    @Test func theNookCanSwitchToCalendarAndBack() {
        let harness = Harness()
        harness.hover(for: .milliseconds(150))

        harness.core.switchNook(to: .calendar)
        #expect(harness.state.nook == .open(.calendar))

        harness.core.switchNook(to: .home)
        #expect(harness.state.nook == .open(.home))
    }
}
