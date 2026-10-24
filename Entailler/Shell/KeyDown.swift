import AppKit
import SwiftUI

extension View {
    /// Handles key presses in the Notch window, which gets them only while it has the keyboard,
    /// for as long as this view is shown. `handle` returns whether it used the key, and a used key
    /// goes no further, such as into a text field.
    func onKeyDown(_ handle: @escaping @MainActor (NSEvent) -> Bool) -> some View {
        modifier(KeyDownModifier(handle: handle))
    }
}

extension NSEvent {
    /// The ⌘, ⌥, ⌃ and ⇧ keys held, without the flags arrow and function keys carry.
    var heldModifiers: NSEvent.ModifierFlags {
        modifierFlags.intersection([.command, .option, .control, .shift])
    }
}

private struct KeyDownModifier: ViewModifier {
    let handle: @MainActor (NSEvent) -> Bool

    @State private var monitor = KeyMonitor()

    func body(content: Content) -> some View {
        // The latest handler, so it sees the view as it is now.
        monitor.handle = handle
        return content
            .onAppear { monitor.start() }
            .onDisappear { monitor.stop() }
    }
}

@MainActor
private final class KeyMonitor {
    var handle: (@MainActor (NSEvent) -> Bool)?
    private var monitor: Any?

    nonisolated init() {}

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handle?(event) ?? false } ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
