import AppKit
import SwiftUI

/// The Files view's Drop Zones, as the window sees them. SwiftUI's own drop handling misses drags
/// over the far side of the Nook, which it hit-tests through the Notch's clip as it was before it
/// grew, so the window takes file drags in AppKit instead and hands each one to the zone under
/// the pointer.
@MainActor @Observable
final class FileDrops {
    enum Zone {
        case tray, airDrop
    }

    /// The zone a drag is over, which lights up.
    var targeted: Zone?
    /// Where each zone on screen is, in the window's content, from the top left.
    @ObservationIgnored var frames: [Zone: CGRect] = [:]
    /// Takes the files dropped on a zone, and says whether it took them.
    @ObservationIgnored var drop: (Zone, [URL]) -> Bool = { _, _ in false }
}

extension View {
    /// Makes this view the zone that takes file drags over it, while it is on screen.
    func fileDropZone(_ zone: FileDrops.Zone, in drops: FileDrops) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { drops.frames[zone] = $0 }
            .onDisappear {
                drops.frames[zone] = nil
                if drops.targeted == zone { drops.targeted = nil }
            }
    }
}

/// The Notch window's content view, under the SwiftUI content: takes file drags and drops them
/// on the Drop Zone under the pointer.
final class FileDropView: NSView {
    private let drops: FileDrops

    init(drops: FileDrops) {
        self.drops = drops
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// From the top left, as SwiftUI lays out the content filling it.
    override var isFlipped: Bool { true }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        target(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        target(sender)
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        setTargeted(nil)
    }

    override func draggingEnded(_ sender: any NSDraggingInfo) {
        setTargeted(nil)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        defer { setTargeted(nil) }
        guard let zone = zone(for: sender) else { return false }
        let files = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        return drops.drop(zone, files.map(\.filePath))
    }

    private func target(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let zone = zone(for: sender)
        setTargeted(zone)
        return zone == nil ? [] : .copy
    }

    private func setTargeted(_ zone: FileDrops.Zone?) {
        if drops.targeted != zone { drops.targeted = zone }
    }

    /// The zone that takes the files, if any. The Tray turns down files dragged out of it, since
    /// it has them already, and a drop it turns down leaves them in it.
    private func zone(for sender: any NSDraggingInfo) -> FileDrops.Zone? {
        let point = convert(sender.draggingLocation, from: nil)
        guard let zone = drops.frames.first(where: { $0.value.contains(point) })?.key,
              !(zone == .tray && sender.draggingSource is TrayDragOut),
              sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        else { return nil }
        return zone
    }
}

private extension URL {
    /// A file reference URL, as some apps put on the pasteboard, as the path it refers to now.
    var filePath: URL {
        ((self as NSURL).filePathURL ?? self).standardizedFileURL
    }
}
