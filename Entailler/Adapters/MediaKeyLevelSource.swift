import AppKit
import NotchCore

/// Takes over the volume and brightness keys: applies each change itself and reports it, so macOS
/// never shows its own pop-ups. Swallowing the keys takes an event tap, which needs Accessibility
/// permission. Until that is granted, or when a key can't be handled, the key passes through to
/// macOS and its pop-up shows as usual. The tap ends with the app, so quitting brings the pop-ups back.
@MainActor
final class MediaKeyLevelSource: LevelChangeSource {
    /// How often to try the event tap again while Accessibility permission is missing.
    private static let retryInterval: Duration = .seconds(2)

    private var update: (@MainActor (LevelChange) -> Void)?
    private var tap: CFMachPort?
    private var retry: Task<Void, Never>?

    func start(_ update: @escaping @MainActor (LevelChange) -> Void) {
        self.update = update
        guard !installTap() else { return }
        NSLog("Entailler: the volume and brightness keys are waiting for Accessibility permission")
        // `kAXTrustedCheckOptionPrompt`, spelled out because the imported global isn't concurrency-safe.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        retry = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.retryInterval)
                guard let self, !self.installTap() else { return }
            }
        }
    }

    private func installTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << systemDefinedEventType)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    /// macOS turns off a tap that is slow to respond, or while secure input is on. Turn it straight back on.
    fileprivate func reenableTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    /// Handles a volume or brightness key from the tap. Returns `true` to swallow it.
    fileprivate func handle(_ press: MediaKeyPress) -> Bool {
        // Option alone opens Sound or Displays settings, so leave that to macOS.
        if press.flags.contains(.maskAlternate), !press.flags.contains(.maskShift) { return false }
        // Shift-Option moves in quarter steps, as in macOS.
        let steps: Double = press.flags.contains([.maskAlternate, .maskShift]) ? 64 : 16

        switch press.key {
        case .volumeUp, .volumeDown:
            guard let volume = SystemVolume.current else { return false }
            if press.isDown {
                let up = press.key == .volumeUp
                let level = step(volume.level, up: up, steps: steps)
                // Turning the volume up unmutes, as in macOS.
                let isMuted = volume.isMuted && !up
                SystemVolume.setLevel(level)
                SystemVolume.setMuted(isMuted)
                update?(.volume(level: level, isMuted: isMuted))
            }
        case .mute:
            guard let volume = SystemVolume.current, volume.canMute else { return false }
            if press.isDown {
                SystemVolume.setMuted(!volume.isMuted)
                update?(.volume(level: volume.level, isMuted: !volume.isMuted))
            }
        case .brightnessUp, .brightnessDown:
            guard let brightness = DisplayBrightness.level else { return false }
            if press.isDown {
                let level = step(brightness, up: press.key == .brightnessUp, steps: steps)
                DisplayBrightness.setLevel(level)
                update?(.brightness(level: level))
            }
        }
        // Swallow the key's release too, so macOS never sees half a key press.
        return true
    }

    /// Moves a level to the next mark up or down on a scale of `steps`. A level between marks
    /// moves to the nearest mark in that direction, so a press never skips a mark.
    private func step(_ level: Double, up: Bool, steps: Double) -> Double {
        let position = level * steps
        // A tenth of a step of tolerance, so a level read back slightly off a mark still counts
        // as on it and the press doesn't set the same mark again.
        let tolerance = 0.1
        let mark = up ? (position + tolerance).rounded(.down) + 1 : (position - tolerance).rounded(.up) - 1
        return min(max(mark / steps, 0), 1)
    }
}

/// `NX_SYSDEFINED`, the event type that carries the media keys. `CGEventType` has no case for it.
private let systemDefinedEventType: UInt32 = 14

/// Runs on the main run loop, where the tap's source is installed.
private func mediaKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)
    guard let userInfo else { return pass }
    let source = Unmanaged<MediaKeyLevelSource>.fromOpaque(userInfo).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { source.reenableTap() }
        return pass
    }
    guard let press = MediaKeyPress(type: type, event: event) else { return pass }
    let swallow = MainActor.assumeIsolated { source.handle(press) }
    return swallow ? nil : pass
}

private enum MediaKey: Sendable {
    case volumeUp, volumeDown, mute, brightnessUp, brightnessDown
}

/// A press or release of a volume or brightness key.
private struct MediaKeyPress: Sendable {
    let key: MediaKey
    let isDown: Bool
    let flags: CGEventFlags

    init?(type: CGEventType, event: CGEvent) {
        flags = event.flags
        if type == .keyDown || type == .keyUp {
            // Some MacBook keyboards send brightness as plain key codes instead of media keys.
            switch event.getIntegerValueField(.keyboardEventKeycode) {
            case 144: key = .brightnessUp
            case 145: key = .brightnessDown
            default: return nil
            }
            isDown = type == .keyDown
            return
        }

        // Media keys are system-defined events of subtype 8 (`NX_SUBTYPE_AUX_CONTROL_BUTTONS`),
        // with the key type in the high half of `data1` and the key state in the low half.
        guard
            type.rawValue == systemDefinedEventType,
            let event = NSEvent(cgEvent: event),
            event.subtype.rawValue == 8
        else { return nil }
        switch (event.data1 & 0xFFFF_0000) >> 16 {
        case 0: key = .volumeUp        // NX_KEYTYPE_SOUND_UP
        case 1: key = .volumeDown      // NX_KEYTYPE_SOUND_DOWN
        case 2: key = .brightnessUp    // NX_KEYTYPE_BRIGHTNESS_UP
        case 3: key = .brightnessDown  // NX_KEYTYPE_BRIGHTNESS_DOWN
        case 7: key = .mute            // NX_KEYTYPE_MUTE
        default: return nil
        }
        isDown = (event.data1 & 0xFF00) >> 8 == 0xA
    }
}

