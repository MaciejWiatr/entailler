import AppKit

extension NSScreen {
    /// The built-in display, when it is connected, awake, and has a camera notch.
    static var builtInNotched: NSScreen? {
        screens.first { $0.isBuiltIn && $0.safeAreaInsets.top > 0 }
    }

    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    private var isBuiltIn: Bool {
        displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
    }
}
