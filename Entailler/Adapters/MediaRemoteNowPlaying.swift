import Foundation
import NotchCore

/// Now playing and media control for whichever app is the system's now-playing source, through
/// MediaRemote. Since macOS 15.4 only Apple-entitled processes may use MediaRemote, so this runs
/// the helper library (see `Helpers/MediaRemote`) inside /usr/bin/perl, which still is, and talks
/// to it over pipes. If the helper can't run, it reports no media and commands go nowhere.
@MainActor
final class MediaRemoteNowPlaying: NowPlayingSource, MediaController {
    private static let perl = URL(filePath: "/usr/bin/perl")
    private static let loader = """
        use DynaLoader;
        my $library = DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error();
        my $main = DynaLoader::dl_find_symbol($library, "entailler_media_remote_main") or die DynaLoader::dl_error();
        DynaLoader::dl_install_xsub("main::run", $main);
        main::run();
        """
    private static let library = Bundle.main.privateFrameworksURL?.appending(path: "EntaillerMediaRemote.dylib")
    private static let relaunchDelay: Duration = .seconds(5)
    /// A helper that exits sooner than this after launching counts as failing to start.
    private static let quickExit: TimeInterval = 10
    private static let maxQuickExits = 3

    private var update: (@MainActor (NowPlaying?) -> Void)?
    private var commands: FileHandle?
    private var quickExits = 0

    func start(_ update: @escaping @MainActor (NowPlaying?) -> Void) {
        self.update = update
        // Writing a command to a helper that has just died must fail, not kill Entailler.
        signal(SIGPIPE, SIG_IGN)
        launch()
    }

    func send(_ command: MediaCommand) {
        let line = switch command {
        case .previousTrack: "previous"
        case .togglePlayPause: "toggle"
        case .nextTrack: "next"
        case .seek(let position): "seek \(position)"
        }
        try? commands?.write(contentsOf: Data((line + "\n").utf8))
    }

    private func launch() {
        guard let library = Self.library, FileManager.default.fileExists(atPath: library.path) else {
            NSLog("Entailler: the MediaRemote helper library is missing")
            return
        }
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = Self.perl
        process.arguments = ["-e", Self.loader, library.path]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let launchedAt = Date()
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.helperExited(launchedAt: launchedAt) }
        }
        do {
            try process.run()
        } catch {
            NSLog("Entailler: could not start the MediaRemote helper: \(error)")
            return
        }
        commands = input.fileHandleForWriting
        Task.detached { [weak self] in
            for try await line in output.fileHandleForReading.bytes.lines {
                let nowPlaying = Self.decode(line)
                await self?.update?(nowPlaying)
            }
        }
    }

    private func helperExited(launchedAt: Date) {
        commands = nil
        update?(nil)
        quickExits = Date().timeIntervalSince(launchedAt) < Self.quickExit ? quickExits + 1 : 0
        guard quickExits < Self.maxQuickExits else {
            NSLog("Entailler: the MediaRemote helper keeps exiting, so now playing is off")
            return
        }
        Task { [weak self] in
            try? await Task.sleep(for: Self.relaunchDelay)
            self?.launch()
        }
    }

    /// One line from the helper: a JSON object describing the media, or `null` for none.
    private nonisolated static func decode(_ line: String) -> NowPlaying? {
        guard let report = try? JSONDecoder().decode(HelperReport?.self, from: Data(line.utf8)) else { return nil }
        var title = report.title
        // Podcasts leave the artist empty and name the show as the album, or, from Spotify at times,
        // leave both empty and append the show to the title.
        var artist = report.artist.isEmpty ? report.album : report.artist
        if artist.isEmpty, let separator = title.range(of: " • ") {
            artist = String(title[separator.upperBound...])
            title = String(title[..<separator.lowerBound])
        }
        return NowPlaying(
            app: report.app,
            title: title,
            artist: artist,
            artwork: report.artwork.flatMap { Data(base64Encoded: $0) },
            duration: report.duration.flatMap { $0 > 0 ? $0 : nil },
            elapsed: report.elapsed,
            elapsedAt: Date(timeIntervalSince1970: report.timestamp),
            isPlaying: report.playing
        )
    }
}

private struct HelperReport: Decodable {
    var app: String
    var title: String
    var artist: String
    var album: String
    var artwork: String?
    var duration: TimeInterval?
    var elapsed: TimeInterval
    var timestamp: TimeInterval
    var playing: Bool
}
