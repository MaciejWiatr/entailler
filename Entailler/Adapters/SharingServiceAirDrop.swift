import AppKit
import NotchCore

/// Sends files with the system's AirDrop sharing service.
@MainActor
final class SharingServiceAirDrop: AirDropSharer {
    func share(_ files: [URL]) {
        // Files arrive mid-drop. The share sheet opens once the drag has finished, since one
        // opened while it is still ending can go with it.
        DispatchQueue.main.async {
            guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: files) else { return }
            // Entailler has no windows of its own to come forward with, so the share sheet would
            // open behind the app in front.
            NSApp.activate()
            service.perform(withItems: files)
        }
    }
}
