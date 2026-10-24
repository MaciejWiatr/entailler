import Accelerate
import CoreAudio
import Foundation
import Observation

/// How loud the audio playing through the Mac is, in a few frequency bands from bass to treble, for
/// the now-playing waveform. Captures the system's output mix through a Core Audio process tap,
/// which needs the System Audio Recording permission and shows the recording indicator while it
/// runs, so it only runs while something shows the levels.
@MainActor
@Observable
final class SystemAudioLevels {
    static let shared = SystemAudioLevels()

    /// Each band's level from 0 to 1, bass first. `nil` while not capturing, or if capture failed.
    private(set) var levels: [Float]?

    @ObservationIgnored private var users = 0
    @ObservationIgnored private var capture: AudioTapCapture?

    /// Starts capturing for one more viewer; capture stops once every viewer has called `stop`.
    func start() {
        users += 1
        guard users == 1 else { return }
        do {
            capture = try AudioTapCapture { [weak self] levels in
                self?.levels = levels
            }
        } catch {
            NSLog("Entailler: could not capture system audio for the waveform: \(error)")
        }
    }

    func stop() {
        users = max(users - 1, 0)
        guard users == 0 else { return }
        capture?.stop()
        capture = nil
        levels = nil
    }
}

private struct CoreAudioError: Error, CustomStringConvertible {
    let operation: String
    let status: OSStatus
    var description: String { "\(operation) failed (\(status))" }
}

private func check(_ operation: String, _ status: OSStatus) throws {
    guard status == noErr else { throw CoreAudioError(operation: operation, status: status) }
}

/// A global tap on every process's output, wrapped in a private aggregate device whose input it is,
/// with an IO block that hands each buffer to a `BandAnalyzer`.
@MainActor
private final class AudioTapCapture {
    private let queue = DispatchQueue(label: "com.maciejwiatr.entailler.audio-levels", qos: .userInteractive)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?

    init(onLevels: @escaping @MainActor ([Float]) -> Void) throws {
        do {
            try setUp(onLevels: onLevels)
        } catch {
            stop()
            throw error
        }
    }

    private func setUp(onLevels: @escaping @MainActor ([Float]) -> Void) throws {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check("AudioHardwareCreateProcessTap", AudioHardwareCreateProcessTap(description, &tapID))

        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        try check("Reading the tap's format", AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format))

        // The tap is the aggregate's only member, so the aggregate runs at the tap's rate whatever
        // the output device does, such as AirPods switching rates for a call.
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Entailler Audio Levels",
            kAudioAggregateDeviceUIDKey: "com.maciejwiatr.entailler.audio-levels.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        try check("AudioHardwareCreateAggregateDevice", AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID))

        let analyzer = BandAnalyzer(format: format) { levels in
            DispatchQueue.main.async { MainActor.assumeIsolated { onLevels(levels) } }
        }
        // `@Sendable` keeps the block off the main actor, which it would otherwise inherit from this
        // method and then assert on, trapping, when Core Audio calls it on `queue`.
        try check("AudioDeviceCreateIOProcIDWithBlock", AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) {
            @Sendable _, input, _, _, _ in
            analyzer.analyze(input)
        })
        try check("AudioDeviceStart", AudioDeviceStart(aggregateID, procID))
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }
}

/// Splits audio into bands with band-pass filters and reports how loud each band is. Each band is
/// read against its own recent peak, so quiet tracks and the naturally quieter treble still fill
/// the bars, and smoothed so the bars jump up with a beat and fall back gently. Runs on the capture
/// queue only.
private final class BandAnalyzer: @unchecked Sendable {
    /// The bands' centre frequencies in hertz, bass to treble.
    private static let centres: [Double] = [90, 350, 1400, 5000]
    /// A band's peak jumps up with it and sinks this many decibels a second, but never below
    /// `quietestPeak`, so near-silence isn't boosted into full bars.
    private static let peakFall: Float = 8
    private static let quietestPeak: Float = -45
    /// Levels span this many decibels below the band's peak.
    private static let range: Float = 24
    /// How quickly the bars rise and fall, as time constants in seconds.
    private static let attack: Float = 0.03
    private static let release: Float = 0.18
    /// How often levels are reported, at most.
    private static let reportInterval: TimeInterval = 1.0 / 45

    private let isInterleaved: Bool
    private let channels: Int
    private let sampleRate: Float
    private var filters: [vDSP.Biquad<Float>]
    private var peaks: [Float]
    private var smoothed: [Float]
    private var lastReport = Date.distantPast
    private let report: @Sendable ([Float]) -> Void

    init(format: AudioStreamBasicDescription, report: @escaping @Sendable ([Float]) -> Void) {
        isInterleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        channels = max(Int(format.mChannelsPerFrame), 1)
        sampleRate = Float(format.mSampleRate)
        filters = Self.centres.map { Self.bandPass(centre: $0, sampleRate: format.mSampleRate) }
        peaks = Array(repeating: Self.quietestPeak, count: Self.centres.count)
        smoothed = Array(repeating: 0, count: Self.centres.count)
        self.report = report
    }

    func analyze(_ input: UnsafePointer<AudioBufferList>) {
        let mono = mixDown(UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)))
        guard !mono.isEmpty else { return }
        // Smoothing by the time the buffer covers keeps the feel the same whatever its size.
        let elapsed = Float(mono.count) / sampleRate
        let rise = 1 - exp(-elapsed / Self.attack)
        let fall = 1 - exp(-elapsed / Self.release)
        for band in filters.indices {
            let rms = vDSP.rootMeanSquare(filters[band].apply(input: mono))
            let decibels = 20 * log10(max(rms, 1e-7))
            peaks[band] = max(decibels, peaks[band] - Self.peakFall * elapsed, Self.quietestPeak)
            let level = min(max((decibels - peaks[band]) / Self.range + 1, 0), 1)
            smoothed[band] += (level - smoothed[band]) * (level > smoothed[band] ? rise : fall)
        }
        let now = Date()
        guard now.timeIntervalSince(lastReport) >= Self.reportInterval else { return }
        lastReport = now
        report(smoothed)
    }

    /// The buffer's channels averaged into one.
    private func mixDown(_ buffers: UnsafeMutableAudioBufferListPointer) -> [Float] {
        if isInterleaved {
            guard let buffer = buffers.first, let data = buffer.mData else { return [] }
            let samples = UnsafeBufferPointer(
                start: data.assumingMemoryBound(to: Float.self),
                count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            )
            let frames = samples.count / channels
            return (0..<frames).map { frame in
                (0..<channels).reduce(0) { $0 + samples[frame * channels + $1] } / Float(channels)
            }
        }
        let channelSamples = buffers.compactMap { buffer -> UnsafeBufferPointer<Float>? in
            guard let data = buffer.mData else { return nil }
            return UnsafeBufferPointer(
                start: data.assumingMemoryBound(to: Float.self),
                count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            )
        }
        guard let first = channelSamples.first else { return [] }
        var mono = Array(first)
        for other in channelSamples.dropFirst() where other.count == mono.count {
            vDSP.add(mono, other, result: &mono)
        }
        return vDSP.divide(mono, Float(channelSamples.count))
    }

    /// A band-pass filter about one octave wide, from the Audio EQ Cookbook.
    private static func bandPass(centre: Double, sampleRate: Double) -> vDSP.Biquad<Float> {
        let omega = 2 * Double.pi * centre / sampleRate
        let alpha = sin(omega) / (2 * 1.4)
        let a0 = 1 + alpha
        let coefficients = [alpha / a0, 0, -alpha / a0, -2 * cos(omega) / a0, (1 - alpha) / a0]
        return vDSP.Biquad(coefficients: coefficients, channelCount: 1, sectionCount: 1, ofType: Float.self)!
    }
}
