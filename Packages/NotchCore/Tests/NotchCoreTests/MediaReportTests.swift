import Foundation
import NotchCore
import Testing

/// Apps don't always publish complete details. Spotify, for one, also publishes the track it's
/// playing without artwork and with its window title in place of the track's.
@MainActor
struct MediaReportTests {
    @Test func mediaWithoutArtworkKeepsTheArtworkItsAppLastPublished() {
        let harness = Harness()
        harness.nowPlaying.set(.song)
        var nextTrack = NowPlaying.song
        nextTrack.title = "Flim"
        nextTrack.duration = 177
        nextTrack.artwork = nil

        harness.nowPlaying.set(nextTrack)

        #expect(harness.state.media.nowPlaying?.title == "Flim")
        #expect(harness.state.media.nowPlaying?.artwork == NowPlaying.song.artwork)
    }

    @Test func artworkIsNotCarriedOverToAnotherAppsMedia() {
        let harness = Harness()
        harness.nowPlaying.set(.song)
        var video = NowPlaying.song.sparse
        video.app = "com.example.browser"

        harness.nowPlaying.set(video)

        #expect(harness.state.media.nowPlaying?.artwork == nil)
    }

    @Test func artworkIsNotCarriedOverOnceNothingIsReported() {
        let harness = Harness()
        harness.nowPlaying.set(.song)
        harness.nowPlaying.set(nil)

        harness.nowPlaying.set(NowPlaying.song.sparse)

        #expect(harness.state.media.nowPlaying?.artwork == nil)
    }

    @Test func aSparseReportOfTheSameTrackKeepsItsTitleAndArtistAndTakesItsPlaybackState() {
        let harness = Harness()
        harness.nowPlaying.set(.song)

        harness.nowPlaying.set(NowPlaying.song.sparse.paused)

        #expect(harness.state.media == .track(NowPlaying.song.paused))
    }
}
