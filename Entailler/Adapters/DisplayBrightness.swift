import AppKit

/// The built-in display's brightness, through Apple's private DisplayServices framework (ADR 0001).
/// It is loaded at runtime, so if a macOS update removes it, only brightness stops working.
@MainActor
enum DisplayBrightness {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let framework = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )
    private static let getBrightness = framework
        .flatMap { dlsym($0, "DisplayServicesGetBrightness") }
        .map { unsafeBitCast($0, to: GetBrightness.self) }
    private static let setBrightness = framework
        .flatMap { dlsym($0, "DisplayServicesSetBrightness") }
        .map { unsafeBitCast($0, to: SetBrightness.self) }

    /// The current brightness, or `nil` when it can't be read or set: the framework is gone,
    /// or the built-in display is off.
    static var level: Double? {
        guard let getBrightness, setBrightness != nil, let display = NSScreen.builtInNotched?.displayID
        else { return nil }
        var level: Float = 0
        guard getBrightness(display, &level) == 0 else { return nil }
        return Double(level)
    }

    static func setLevel(_ level: Double) {
        guard let setBrightness, let display = NSScreen.builtInNotched?.displayID else { return }
        _ = setBrightness(display, Float(min(max(level, 0), 1)))
    }
}
