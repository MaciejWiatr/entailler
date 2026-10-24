import AVFoundation
import Synchronization

/// The sounds of handling the Media Widget's record. Scratching plays a short "ahh" forwards or
/// backwards as fast as the record turns under the pointer, silent while it's held still, over
/// whatever media plays, like a DJ cutting over a beat. Brushing plays a soft hiss of velvet on
/// vinyl, louder the faster the pad and the record slide past each other.
@MainActor
final class TurntableSound {
    static let shared = TurntableSound()

    private let scratchVoice = ScratchVoice()
    private let brushVoice = BrushVoice()
    private var engine: AVAudioEngine?
    /// How many hands are on the record: one scratching, one brushing.
    private var hands = 0
    private var stopping: Task<Void, Never>?

    /// How long the engine keeps running after the record is let go, in case it's handled again.
    private static let linger: Duration = .seconds(2)

    /// A hand goes to the record, to scratch it or brush it.
    func begin() {
        hands += 1
        stopping?.cancel()
        if engine == nil {
            engine = Self.makeEngine(scratchVoice: scratchVoice, brushVoice: brushVoice)
        }
        guard let engine, !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            NSLog("Entailler: could not start the turntable's sounds: \(error)")
        }
    }

    /// How fast the record turns under the pointer, as a multiple of its playing speed; negative
    /// when it turns backwards.
    func scratch(atSpeed speed: Double) {
        scratchVoice.setSpeed(speed)
    }

    /// How fast the brush's pad and the record slide past each other, from 0 for still to 1 for brisk.
    func brush(atSpeed speed: Double) {
        brushVoice.setSpeed(speed)
    }

    /// A hand comes off the record: its sound dies away, and once both are off, the engine stops
    /// a little later.
    func end() {
        hands = max(hands - 1, 0)
        guard hands == 0 else { return }
        scratchVoice.setSpeed(0)
        brushVoice.setSpeed(0)
        stopping?.cancel()
        stopping = Task {
            try? await Task.sleep(for: Self.linger)
            guard !Task.isCancelled else { return }
            engine?.stop()
        }
    }

    /// Built outside the main actor, so the render blocks don't inherit it and trap when Core Audio
    /// calls them on its own thread.
    private nonisolated static func makeEngine(scratchVoice: ScratchVoice, brushVoice: BrushVoice) -> AVAudioEngine {
        let engine = AVAudioEngine()
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate > 0 ? sampleRate : 48_000, channels: 1)!
        scratchVoice.prepare(sampleRate: format.sampleRate)
        brushVoice.prepare(sampleRate: format.sampleRate)
        let scratch = AVAudioSourceNode(format: format) { _, _, frameCount, buffers in
            scratchVoice.render(frameCount: Int(frameCount), into: UnsafeMutableAudioBufferListPointer(buffers))
            return noErr
        }
        let brush = AVAudioSourceNode(format: format) { _, _, frameCount, buffers in
            brushVoice.render(frameCount: Int(frameCount), into: UnsafeMutableAudioBufferListPointer(buffers))
            return noErr
        }
        for source in [scratch, brush] {
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
        }
        return engine
    }
}

/// A speed set from the main actor and read on the render thread, which falls to nothing if it
/// isn't set again for a moment, as when the pointer stops while still holding on.
private final class SpeedSetting: Sendable {
    /// The speed last set, as a `Double`'s bit pattern, and when, in nanoseconds of uptime.
    private let speed = Atomic<UInt64>(0)
    private let setAt = Atomic<UInt64>(0)

    /// How long a speed holds without being set again.
    private static let hold: UInt64 = 60_000_000

    func set(_ speed: Double) {
        self.speed.store(speed.bitPattern, ordering: .relaxed)
        setAt.store(DispatchTime.now().uptimeNanoseconds, ordering: .relaxed)
    }

    var current: Double {
        let isFresh = DispatchTime.now().uptimeNanoseconds &- setAt.load(ordering: .relaxed) < Self.hold
        return isFresh ? Double(bitPattern: speed.load(ordering: .relaxed)) : 0
    }
}

/// A soft hiss of velvet fibres on vinyl: noise with its rumble and sizzle filtered off, swelling
/// with the speed set and easing back to silence.
private final class BrushVoice: @unchecked Sendable {
    private let setting = SpeedSetting()

    private static let glide = 0.04
    private static let volume: Float = 0.12

    // Touched only while preparing, before the engine runs, and then on the render thread.
    private var level = 0.0
    private var easing = 0.0
    private var lowPass = Float(0)
    private var lowPassed = Float(0)
    private var highPass = Float(0)
    private var highPassed = Float(0)
    private var generator = SystemRandomNumberGenerator()

    func setSpeed(_ speed: Double) {
        setting.set(speed)
    }

    func prepare(sampleRate: Double) {
        easing = 1 - exp(-1 / (Self.glide * sampleRate))
        lowPass = Float(1 - exp(-2 * .pi * 4_500 / sampleRate))
        highPass = Float(1 - exp(-2 * .pi * 900 / sampleRate))
    }

    func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        let target = min(max(setting.current, 0), 1)
        for frame in 0..<frameCount {
            level += (target - level) * easing
            let noise = Float.random(in: -1...1, using: &generator)
            lowPassed += (noise - lowPassed) * lowPass
            highPassed += (lowPassed - highPassed) * highPass
            let output = (lowPassed - highPassed) * Float(level) * Self.volume
            for buffer in buffers {
                buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = output
            }
        }
    }
}

/// Plays a looped sample at a speed set from the main actor. The speed eases towards each new
/// setting, so the pitch slides like a real record's instead of stepping.
private final class ScratchVoice: @unchecked Sendable {
    private let setting = SpeedSetting()

    /// How quickly the speed eases towards its setting, as a time constant in seconds.
    private static let glide = 0.012
    private static let volume: Float = 0.5

    // Touched only while preparing, before the engine runs, and then on the render thread.
    private var sample: [Float] = []
    private var playhead = 0.0
    private var speed = 0.0
    private var easing = 0.0

    func setSpeed(_ speed: Double) {
        setting.set(speed)
    }

    func prepare(sampleRate: Double) {
        sample = Self.makeSample(sampleRate: sampleRate)
        easing = 1 - exp(-1 / (Self.glide * sampleRate))
    }

    func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        let target = setting.current
        let count = Double(sample.count)
        for frame in 0..<frameCount {
            speed += (target - speed) * easing
            playhead = (playhead + speed).truncatingRemainder(dividingBy: count)
            if playhead < 0 { playhead += count }
            let index = Int(playhead)
            let next = (index + 1) % sample.count
            let fraction = Float(playhead - Double(index))
            let value = sample[index] + (sample[next] - sample[index]) * fraction
            // Louder the faster the record turns, and silent once it stops.
            let level = Float(min(abs(speed), 1.2) / 1.2)
            let output = value * level * Self.volume
            for buffer in buffers {
                buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = output
            }
        }
    }

    /// A sung "ahh" in four swells, over a little hiss, looping without a click.
    private static func makeSample(sampleRate: Double) -> [Float] {
        let count = Int(sampleRate * 1.2)
        let duration = Double(count) / sampleRate
        // A whole number of cycles in the loop, so it joins up smoothly.
        let fundamental = (170 * duration).rounded() / duration
        // The formants of an open "ah".
        let formants: [(frequency: Double, width: Double)] = [(730, 160), (1090, 220), (2440, 400)]
        let harmonics = (1...24).map { harmonic -> (frequency: Double, amplitude: Double) in
            let frequency = fundamental * Double(harmonic)
            let amplitude = formants.reduce(0.05) { sum, formant in
                sum + exp(-pow((frequency - formant.frequency) / formant.width, 2))
            } / Double(harmonic).squareRoot()
            return (frequency, amplitude)
        }
        var generator = SystemRandomNumberGenerator()
        var noise = 0.0
        var sample = (0..<count).map { index -> Float in
            let time = Double(index) / sampleRate
            let voice = harmonics.reduce(0) { $0 + $1.amplitude * sin(2 * .pi * $1.frequency * time) }
            let swell = 0.35 + 0.65 * pow(sin(.pi * time / duration * 4), 2)
            noise += (Double.random(in: -1...1, using: &generator) - noise) * 0.3
            return Float(voice * swell + noise * 0.08)
        }
        let peak = sample.map(abs).max() ?? 1
        for index in sample.indices {
            sample[index] /= peak
        }
        return sample
    }
}
