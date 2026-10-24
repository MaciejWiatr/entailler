import NotchCore
import Testing

@MainActor
struct ClaudeCodeActivityTests {
    /// A harness where the user has switched from the terminal to the browser.
    private func awayFromTerminal() -> Harness {
        let harness = Harness()
        harness.frontApp.set(ClaudeHost.browserApp)
        return harness
    }

    @Test func aSessionThatFinishesRespondingShowsAnOngoingActivity() {
        let harness = awayFromTerminal()
        let session = ClaudeSession.finished("a")

        harness.claudeCode.send(.waiting(session))

        #expect(harness.state.activity == .claudeCode(session, waiting: 1))
        #expect(harness.state.activity?.kind == .ongoing)
    }

    @Test func aSessionAskingForPermissionShowsTheActivityToo() {
        let harness = awayFromTerminal()
        let session = ClaudeSession(id: "a", project: "entailler", reason: .needsInput, host: .terminal)

        harness.claudeCode.send(.waiting(session))

        #expect(harness.state.activity == .claudeCode(session, waiting: 1))
    }

    @Test func aSessionThatFinishesWhileItsAppIsInFrontShowsNoActivity() {
        let harness = Harness()
        harness.frontApp.set(ClaudeHost.terminal.app)

        harness.claudeCode.send(.waiting(.finished("a")))

        #expect(harness.state.activity == nil)
    }

    @Test func aSessionWhoseAppIsUnknownShowsTheActivityWhateverIsInFront() {
        let harness = Harness()
        harness.frontApp.set(ClaudeHost.terminal.app)
        let session = ClaudeSession.finished("a", host: nil)

        harness.claudeCode.send(.waiting(session))

        #expect(harness.state.activity == .claudeCode(session, waiting: 1))
    }

    @Test func openingTheSessionBringsItToTheFrontAndEndsTheActivity() {
        let harness = awayFromTerminal()
        let session = ClaudeSession.finished("a")
        harness.claudeCode.send(.waiting(session))

        harness.core.openClaudeSession()

        #expect(harness.claudeCode.broughtToFront == [session])
        #expect(harness.state.activity == nil)
    }

    @Test func switchingToTheSessionsAppEndsTheActivity() {
        let harness = awayFromTerminal()
        harness.claudeCode.send(.waiting(.finished("a")))

        harness.frontApp.set(ClaudeHost.terminal.app)

        #expect(harness.state.activity == nil)
        #expect(harness.claudeCode.broughtToFront.isEmpty)
    }

    @Test func switchingToAnotherAppKeepsTheActivity() {
        let harness = awayFromTerminal()
        let session = ClaudeSession.finished("a")
        harness.claudeCode.send(.waiting(session))

        harness.frontApp.set(42)

        #expect(harness.state.activity == .claudeCode(session, waiting: 1))
    }

    @Test(arguments: [ClaudeCodeReport.working(sessionID: "a"), .ended(sessionID: "a")])
    func aPromptOrTheSessionEndingEndsTheActivity(report: ClaudeCodeReport) {
        let harness = awayFromTerminal()
        harness.claudeCode.send(.waiting(.finished("a")))

        harness.claudeCode.send(report)

        #expect(harness.state.activity == nil)
    }

    @Test func theLatestWaitingSessionIsShownWithHowManyAreWaiting() {
        let harness = awayFromTerminal()
        let first = ClaudeSession.finished("a", project: "entailler")
        let second = ClaudeSession.finished("b", project: "website")

        harness.claudeCode.send(.waiting(first))
        harness.claudeCode.send(.waiting(second))

        #expect(harness.state.activity == .claudeCode(second, waiting: 2))
    }

    @Test func openingTheLatestSessionShowsTheOneWaitingBeforeIt() {
        let harness = awayFromTerminal()
        let first = ClaudeSession.finished("a", project: "entailler")
        harness.claudeCode.send(.waiting(first))
        harness.claudeCode.send(.waiting(.finished("b", project: "website")))

        harness.core.openClaudeSession()

        #expect(harness.state.activity == .claudeCode(first, waiting: 1))
    }

    @Test func aSessionWaitingAgainMovesToTheFrontWithoutCountingTwice() {
        let harness = awayFromTerminal()
        harness.claudeCode.send(.waiting(.finished("a", project: "entailler")))
        harness.claudeCode.send(.waiting(.finished("b", project: "website")))
        let again = ClaudeSession(id: "a", project: "entailler", reason: .needsInput, host: .terminal)

        harness.claudeCode.send(.waiting(again))

        #expect(harness.state.activity == .claudeCode(again, waiting: 2))
    }

    @Test func switchingToAnAppEndsEverySessionWaitingInIt() {
        let harness = awayFromTerminal()
        let elsewhere = ClaudeSession.finished("c", host: ClaudeHost(app: 600))
        harness.claudeCode.send(.waiting(elsewhere))
        harness.claudeCode.send(.waiting(.finished("a")))
        harness.claudeCode.send(.waiting(.finished("b")))

        harness.frontApp.set(ClaudeHost.terminal.app)

        #expect(harness.state.activity == .claudeCode(elsewhere, waiting: 1))
    }

    @Test func aWaitingSessionRanksBelowAnUpcomingEventAndAboveNowPlaying() {
        let harness = awayFromTerminal()
        harness.core.activityStarted(.nowPlaying)
        harness.claudeCode.send(.waiting(.finished("a")))
        #expect(harness.state.activity?.source == .claudeCode)

        harness.core.activityStarted(.upcomingEvent(.standup))
        #expect(harness.state.activity?.source == .upcomingEvent)

        harness.core.activityEnded(.upcomingEvent)
        harness.core.openClaudeSession()
        #expect(harness.state.activity?.source == .nowPlaying)
    }

    @Test func aWaitingSessionIsHiddenInFullscreen() {
        let harness = awayFromTerminal()
        harness.fullscreen.set(true)

        harness.claudeCode.send(.waiting(.finished("a")))

        #expect(harness.state.activity == nil)
    }
}
