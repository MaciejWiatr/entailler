import NotchCore
import Testing

@MainActor
struct FlashActivityTests {
    @Test func changingTheVolumeShowsAVolumeFlashActivityWithTheLevel() {
        let harness = Harness()

        harness.levels.send(.volume(level: 0.625, isMuted: false))

        #expect(harness.state.activity == .flash(.volume(level: 0.625, isMuted: false)))
    }

    @Test func mutingShowsTheVolumeFlashActivityMuted() {
        let harness = Harness()
        harness.levels.send(.volume(level: 0.625, isMuted: false))

        harness.levels.send(.volume(level: 0.625, isMuted: true))

        #expect(harness.state.activity == .flash(.volume(level: 0.625, isMuted: true)))
    }

    @Test func changingTheBrightnessShowsABrightnessFlashActivityWithTheLevel() {
        let harness = Harness()

        harness.levels.send(.brightness(level: 0.25))

        #expect(harness.state.activity == .flash(.brightness(level: 0.25)))
    }

    @Test func aBrightnessChangeRightAfterAVolumeChangeShowsTheBrightness() {
        let harness = Harness()
        harness.levels.send(.volume(level: 0.5, isMuted: false))

        harness.levels.send(.brightness(level: 0.75))

        #expect(harness.state.activity == .flash(.brightness(level: 0.75)))
    }

    @Test func theFlashActivityHidesOneAndAHalfSecondsAfterTheChange() {
        let harness = Harness()
        harness.changeVolume()

        harness.clock.advance(by: .milliseconds(1499))
        #expect(harness.state.activity?.source == .flash)

        harness.clock.advance(by: .milliseconds(1))
        #expect(harness.state.activity == nil)
    }

    @Test func repeatedChangesKeepTheFlashActivityUpUntilOneAndAHalfSecondsAfterTheLast() {
        let harness = Harness()
        harness.changeVolume()
        harness.clock.advance(by: .milliseconds(1000))
        harness.changeVolume()

        harness.clock.advance(by: .milliseconds(1499))
        #expect(harness.state.activity?.source == .flash)

        harness.clock.advance(by: .milliseconds(1))
        #expect(harness.state.activity == nil)
    }

    @Test func aVolumeFlashActivityReplacesNowPlayingThenNowPlayingReturns() {
        let harness = Harness()
        harness.core.activityStarted(.nowPlaying)

        harness.changeVolume()
        #expect(harness.state.activity?.source == .flash)

        harness.clock.advance(by: .milliseconds(1500))
        #expect(harness.state.activity == .nowPlaying)
    }
}
