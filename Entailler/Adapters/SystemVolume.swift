import AudioToolbox
import CoreAudio

/// The default output device's volume and mute state, through CoreAudio.
enum SystemVolume {
    struct Reading {
        var level: Double
        var isMuted: Bool
        /// Whether the output has a mute switch Entailler can flip.
        var canMute: Bool
    }

    /// The current volume, or `nil` when the output's volume can't be set,
    /// as with many HDMI and DisplayPort outputs.
    static var current: Reading? {
        let device = defaultOutputDevice
        guard device != kAudioObjectUnknown, isSettable(volumeAddress, on: device) else { return nil }
        var level: Float32 = 0
        var muted: UInt32 = 0
        read(volumeAddress, of: device, into: &level)
        read(muteAddress, of: device, into: &muted)
        return Reading(level: Double(level), isMuted: muted != 0, canMute: isSettable(muteAddress, on: device))
    }

    static func setLevel(_ level: Double) {
        var value = Float32(min(max(level, 0), 1))
        write(volumeAddress, of: defaultOutputDevice, from: &value)
    }

    static func setMuted(_ isMuted: Bool) {
        var value: UInt32 = isMuted ? 1 : 0
        write(muteAddress, of: defaultOutputDevice, from: &value)
    }

    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static var defaultOutputDevice: AudioDeviceID {
        var device = AudioDeviceID(kAudioObjectUnknown)
        let address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        read(address, of: AudioObjectID(kAudioObjectSystemObject), into: &device)
        return device
    }

    private static func isSettable(_ address: AudioObjectPropertyAddress, on object: AudioObjectID) -> Bool {
        var address = address
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(object, &address),
              AudioObjectIsPropertySettable(object, &address, &settable) == noErr
        else { return false }
        return settable.boolValue
    }

    private static func read<Value>(_ address: AudioObjectPropertyAddress, of object: AudioObjectID, into value: inout Value) {
        var address = address
        var size = UInt32(MemoryLayout<Value>.size)
        guard AudioObjectHasProperty(object, &address) else { return }
        AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
    }

    private static func write<Value>(_ address: AudioObjectPropertyAddress, of object: AudioObjectID, from value: inout Value) {
        var address = address
        guard AudioObjectHasProperty(object, &address) else { return }
        AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<Value>.size), &value)
    }
}
