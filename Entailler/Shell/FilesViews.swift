import AppKit
import NotchCore
import QuickLookThumbnailing
import SwiftUI

/// What the Files view asks the core to do.
struct TrayActions {
    let select: (URL, TraySelection) -> Void
    let clearSelection: () -> Void
    let remove: (URL) -> Void
    let removeSelected: () -> Void
    let filesToDrag: (URL) -> [URL]
    let dragOutEnded: ([URL], Bool) -> Void
}

/// The Nook's Files view: the Tray, where files are parked and dragged back out later, beside
/// the AirDrop Drop Zone. Delete removes the selected items.
struct FilesView: View {
    nonisolated static let height: CGFloat = MediaWidgetView.height

    let tray: Tray
    let actions: TrayActions
    let drops: FileDrops

    var body: some View {
        HStack(spacing: 12) {
            TrayView(tray: tray, actions: actions, isTargeted: drops.targeted == .tray)
                .fileDropZone(.tray, in: drops)
            AirDropZone(isTargeted: drops.targeted == .airDrop)
                .frame(width: 112)
                .fileDropZone(.airDrop, in: drops)
        }
        .onKeyDown { event in
            // Delete, and Forward Delete.
            guard event.heldModifiers.isEmpty || event.heldModifiers == .command,
                  event.keyCode == 51 || event.keyCode == 117
            else { return false }
            actions.removeSelected()
            return true
        }
    }
}

/// A Drop Zone's outline: a dashed rounded rectangle that lights up while a drag is over it.
private struct DropZoneBackground: View {
    let isTargeted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.white.opacity(isTargeted ? 0.1 : 0.04))
            .strokeBorder(
                .white.opacity(isTargeted ? 0.5 : 0.15),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
            )
            .animation(.spring(duration: 0.25, bounce: 0.2), value: isTargeted)
    }
}

private struct TrayView: View {
    let tray: Tray
    let actions: TrayActions
    let isTargeted: Bool

    var body: some View {
        ZStack {
            DropZoneBackground(isTargeted: isTargeted)
                // A click away from the items lets go of the selection.
                .contentShape(Rectangle())
                .onTapGesture(perform: actions.clearSelection)
            if tray.files.isEmpty {
                Label("Drop files here", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 2) {
                        ForEach(tray.files, id: \.self) { file in
                            TrayItemView(file: file, isSelected: tray.selection.contains(file), actions: actions)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 6)
                    .frame(maxHeight: .infinity)
                }
                .scrollIndicators(.never)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: tray.files)
    }
}

/// A Tray item: the file's thumbnail or icon over its name. Clicks select it, ⌘ and ⇧ adding to
/// the selection, and dragging carries it, with the rest of the selection, out of the Tray.
private struct TrayItemView: View {
    static let iconSize: CGFloat = 44

    let file: URL
    let isSelected: Bool
    let actions: TrayActions

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            FileThumbnail(file: file, size: Self.iconSize)
            Text(file.lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 4)
                .frame(height: 14)
                .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .frame(width: 68)
        .padding(.vertical, 4)
        .background(isSelected ? Color.white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            TrayItemMouse(
                select: { actions.select(file, $0) },
                filesToDrag: { actions.filesToDrag(file) },
                dragEnded: actions.dragOutEnded
            )
        }
        .overlay(alignment: .topLeading) {
            if isHovered {
                Button {
                    actions.remove(file)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .gray)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: 0)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
                .accessibilityLabel("Remove \(file.lastPathComponent) from the Tray")
            }
        }
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2, bounce: 0.2)) { isHovered = hovering }
        }
        .animation(.spring(duration: 0.25, bounce: 0.2), value: isSelected)
    }
}

/// The file's Quick Look thumbnail, such as a picture's contents, or its icon until there is one.
private struct FileThumbnail: View {
    let file: URL
    let size: CGFloat

    @State private var thumbnail: NSImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Image(nsImage: thumbnail ?? NSWorkspace.shared.icon(forFile: file.path))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .task(id: file) {
                let request = QLThumbnailGenerator.Request(
                    fileAt: file,
                    size: CGSize(width: size, height: size),
                    scale: displayScale,
                    representationTypes: .thumbnail
                )
                thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
            }
    }
}

private struct AirDropZone: View {
    let isTargeted: Bool

    var body: some View {
        ZStack {
            // The outline is the zone's content, not its background, so a drag anywhere inside it
            // counts, not only one over the icon or the label.
            DropZoneBackground(isTargeted: isTargeted)
            VStack(spacing: 6) {
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)
                    .scaleEffect(isTargeted ? 1.15 : 1)
                Text("AirDrop")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isTargeted ? .white : .gray)
            }
        }
        .contentShape(Rectangle())
        .animation(.spring(duration: 0.3, bounce: 0.35), value: isTargeted)
        .accessibilityLabel("AirDrop Drop Zone")
    }

    private var icon: Image {
        if let image = NSSharingService(named: .sendViaAirDrop)?.image {
            return Image(nsImage: image)
        }
        return Image(systemName: "dot.radiowaves.left.and.right")
    }
}

/// Takes a Tray item's clicks and drags in AppKit, which, unlike SwiftUI, says whether the
/// destination accepted a drag.
private struct TrayItemMouse: NSViewRepresentable {
    let select: (TraySelection) -> Void
    let filesToDrag: () -> [URL]
    let dragEnded: ([URL], Bool) -> Void

    func makeNSView(context: Context) -> TrayItemMouseView {
        TrayItemMouseView()
    }

    func updateNSView(_ view: TrayItemMouseView, context: Context) {
        view.select = select
        view.filesToDrag = filesToDrag
        view.dragEnded = dragEnded
    }
}

private final class TrayItemMouseView: NSView {
    /// How far the pointer moves with the button down before a click becomes a drag.
    private static let dragThreshold: CGFloat = 3

    var select: (TraySelection) -> Void = { _ in }
    var filesToDrag: () -> [URL] = { [] }
    var dragEnded: ([URL], Bool) -> Void = { _, _ in }
    private var mouseDown: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDown = event
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseDown != nil else { return }
        mouseDown = nil
        let modifiers = event.heldModifiers
        select(modifiers.contains(.command) ? .toggle : modifiers.contains(.shift) ? .range : .only)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDown else { return }
        let start = down.locationInWindow
        let now = event.locationInWindow
        guard hypot(now.x - start.x, now.y - start.y) >= Self.dragThreshold else { return }
        mouseDown = nil
        let files = filesToDrag()
        let origin = convert(start, from: nil)
        let size = TrayItemView.iconSize
        let items = files.enumerated().map { index, file in
            let item = NSDraggingItem(pasteboardWriter: file as NSURL)
            let offset = CGFloat(index) * 4
            item.setDraggingFrame(
                NSRect(x: origin.x - size / 2 + offset, y: origin.y - size / 2 - offset, width: size, height: size),
                contents: NSWorkspace.shared.icon(forFile: file.path)
            )
            return item
        }
        let session = beginDraggingSession(with: items, event: down, source: TrayDragOut(files: files, ended: dragEnded))
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }
}

/// A drag out of the Tray. It outlives the Tray item it started on, since the Nook closes as soon
/// as the pointer leaves it while the drag carries on.
@MainActor
final class TrayDragOut: NSObject, NSDraggingSource {
    private static var running: Set<TrayDragOut> = []

    private let files: [URL]
    private let ended: ([URL], Bool) -> Void

    init(files: [URL], ended: @escaping ([URL], Bool) -> Void) {
        self.files = files
        self.ended = ended
        super.init()
        Self.running.insert(self)
    }

    /// Anywhere outside Entailler takes the files as a normal file drag would, such as Finder
    /// moving them within a disk. Inside, only the AirDrop Drop Zone takes them; the Tray already
    /// has them, so it turns them down.
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link, .generic] : [.copy, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        ended(files, operation != [])
        Self.running.remove(self)
    }
}
