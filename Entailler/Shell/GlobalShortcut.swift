import AppKit
import Carbon.HIToolbox

/// A key combination that works whichever app is in front, through Carbon's hot keys, which need
/// no Accessibility permission.
@MainActor
final class GlobalShortcut {
    /// ⌥⌘N, for the Nook.
    static let nook = (keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(optionKey | cmdKey), label: "⌥⌘N")

    private let action: @MainActor () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, shortcut in
            guard let shortcut else { return OSStatus(eventNotHandledErr) }
            let target = Unmanaged<GlobalShortcut>.fromOpaque(shortcut).takeUnretainedValue()
            MainActor.assumeIsolated { target.action() }
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let id = EventHotKeyID(signature: OSType(0x454E_544C), id: 1) // "ENTL"
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKey)
    }

    isolated deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
