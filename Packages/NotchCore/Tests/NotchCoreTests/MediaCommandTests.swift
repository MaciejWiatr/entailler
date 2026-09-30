import NotchCore
import Testing

@MainActor
struct MediaCommandTests {
    @Test(arguments: [MediaCommand.previousTrack, .togglePlayPause, .nextTrack, .seek(to: 100)])
    func aMediaCommandReachesTheSystem(command: MediaCommand) {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.core.sendMediaCommand(command)

        #expect(harness.mediaController.sent == [command])
    }

    @Test func mediaCommandsDoNothingWhileTheMediaWidgetIsEmpty() {
        let harness = Harness()

        harness.core.sendMediaCommand(.togglePlayPause)
        harness.core.sendMediaCommand(.seek(to: 10))

        #expect(harness.mediaController.sent.isEmpty)
    }

    @Test func seekingPastEitherEndOfTheTrackLandsOnThatEnd() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.core.sendMediaCommand(.seek(to: -5))
        harness.core.sendMediaCommand(.seek(to: 1000))

        #expect(harness.mediaController.sent == [.seek(to: 0), .seek(to: 367)])
    }
}
