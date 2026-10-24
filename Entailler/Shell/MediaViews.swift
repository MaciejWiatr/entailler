import AppKit
import NotchCore
import SwiftUI

/// The Media Widget on Home: the current track with transport controls and a seekable progress bar.
struct MediaWidgetView: View {
    /// As tall as its artwork.
    nonisolated static let height = MediaArtwork.size

    let media: MediaWidget
    let send: (MediaCommand) -> Void

    var body: some View {
        switch media {
        case .empty:
            HStack(spacing: 14) {
                MediaArtwork(artwork: nil, isPlaying: false)
                Text("Nothing playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.gray)
                Spacer(minLength: 0)
            }
        case .track(let track):
            HStack(spacing: 14) {
                MediaArtwork(artwork: track.artwork, isPlaying: track.isPlaying)
                    // So the brush passes over the track's details.
                    .zIndex(1)
                // As tall as the artwork: the title at its top edge, the controls at its bottom.
                VStack(alignment: .leading, spacing: 1) {
                    // Clicking the title brings the app playing it to the front.
                    Button {
                        openApp(track.app)
                    } label: {
                        Text(track.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .accessibilityHint("Opens the app playing it")
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                    Spacer(minLength: 0)
                    if track.duration != nil {
                        MediaProgressBar(track: track, seek: { send(.seek(to: $0)) })
                    }
                    TransportControls(isPlaying: track.isPlaying, send: send)
                        .frame(maxWidth: .infinity)
                }
                .lineLimit(1)
                .frame(height: Self.height)
            }
        }
    }
}

/// Opens the app with bundle identifier `app`, or brings it to the front if it's running.
private func openApp(_ app: String) {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) else { return }
    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
}

/// Artwork shows as a record on a turntable or as a plain cover. Clicking the artwork in the
/// Media Widget switches between them, and the choice sticks.
private let showsTurntableKey = "showsArtworkAsTurntable"

/// The Media Widget's artwork, switched by clicking it between a record on a minimal turntable
/// and a plain cover. Switching morphs one into the other: the record's label grows into the
/// cover as the record fades beneath it and the tonearm swings away, and back again.
///
/// On the turntable, the record can be scratched by dragging it round, and a brush tucked under it
/// can be pulled out by its handle to sweep the dust off it.
private struct MediaArtwork: View {
    let artwork: Data?
    let isPlaying: Bool

    @AppStorage(showsTurntableKey) private var showsTurntable = true
    /// Where the brush's pad is while it's held, in the turntable's coordinates.
    @State private var brushAt: CGPoint?

    nonisolated static let size: CGFloat = 84
    /// Where the tonearm pivots, just off the record's top-right edge.
    private static let pivot = CGPoint(x: 94, y: 8)
    private static let baseDiameter: CGFloat = 16
    /// The record plus the tonearm's base beside it.
    private static let width = pivot.x + baseDiameter / 2
    /// Where the brush's handle peeks out from under the record's lower edge, pointing away from
    /// its centre.
    private static let brushRest = CGPoint(x: 64, y: 79)
    private static let brushRestAngle = Angle.degrees(58)
    /// How far the brush can be taken: over the record and the track's details beside it.
    private static let brushBounds = CGRect(x: -6, y: 2, width: 300, height: 90)
    private static let space = "turntable"

    var body: some View {
        ZStack(alignment: .topLeading) {
            RecordOrCover(
                artwork: artwork,
                isPlaying: isPlaying,
                showsRecord: showsTurntable,
                size: Self.size,
                coverCornerRadius: 10,
                isHandleable: true,
                brush: brushAt
            )
            // The tonearm's base, a faint ring around its pivot.
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .frame(width: Self.baseDiameter, height: Self.baseDiameter)
                .offset(x: Self.pivot.x - Self.baseDiameter / 2, y: Self.pivot.y - Self.baseDiameter / 2)
                .opacity(showsTurntable ? 1 : 0)
            Tonearm(position: showsTurntable ? (isPlaying ? .onRecord : .resting) : .away)
                .offset(x: Self.pivot.x - Tonearm.pivotRadius, y: Self.pivot.y - Tonearm.pivotRadius)
                .opacity(showsTurntable ? 1 : 0)
            RecordBrush(isOut: brushAt != nil, restingAngle: Self.brushRestAngle)
                .gesture(brushing, including: showsTurntable ? .all : .subviews)
                .position(brushAt ?? Self.brushRest)
                .opacity(showsTurntable ? 1 : 0)
                // Tucked under the record until it's pulled out, then held over everything.
                .zIndex(brushAt == nil ? -1 : 1)
        }
        // Always wide enough for the tonearm, so switching to the cover doesn't shift the text.
        .frame(width: Self.width, height: Self.size, alignment: .topLeading)
        .coordinateSpace(.named(Self.space))
        .contentShape(Rectangle())
        // A tap rather than a button, so dragging the record or the brush doesn't also switch.
        .onTapGesture { showsTurntable.toggle() }
        .animation(RecordOrCover.morph(toRecord: showsTurntable), value: showsTurntable)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(showsTurntable ? "Show plain artwork" : "Show artwork on a turntable")
        .accessibilityAction { showsTurntable.toggle() }
    }

    /// Pulls the brush out from under the record as the handle is grabbed, sweeps it wherever the
    /// pointer goes, and tucks it back in when it's let go.
    private var brushing: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { drag in
                let bounds = Self.brushBounds
                let point = CGPoint(
                    x: min(max(drag.location.x, bounds.minX), bounds.maxX),
                    y: min(max(drag.location.y, bounds.minY), bounds.maxY)
                )
                let isPullingOut = brushAt == nil
                withAnimation(isPullingOut ? .spring(duration: 0.35, bounce: 0.3) : .spring(duration: 0.12, bounce: 0)) {
                    brushAt = point
                }
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    brushAt = nil
                }
            }
    }
}

/// A record-cleaning brush seen from above: a velvet pad with a handle along its back. Put away,
/// all that shows is the tip of its handle, poking out from under the record.
private struct RecordBrush: View {
    let isOut: Bool
    let restingAngle: Angle

    static let padSize = CGSize(width: 30, height: 9)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color(white: 0.16))
                .overlay { fibres }
                .overlay {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                }
                .frame(width: Self.padSize.width, height: Self.padSize.height)
                .scaleEffect(isOut ? 1 : 0.3)
                .opacity(isOut ? 1 : 0)
            Capsule()
                .fill(Color(white: 0.75))
                .frame(width: isOut ? 22 : 12, height: 3)
        }
        .rotationEffect(isOut ? .zero : restingAngle)
        // Easier to grab than the sliver of handle showing.
        .frame(width: 34, height: 18)
        .contentShape(Rectangle())
        .pointerStyle(isOut ? .grabActive : .grabIdle)
        .accessibilityHidden(true)
    }

    /// The velvet's fibres, running across the pad.
    private var fibres: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 1.5, to: size.width, by: 1.5) {
                path.move(to: CGPoint(x: x, y: 1))
                path.addLine(to: CGPoint(x: x, y: size.height - 1))
            }
            context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
        }
    }
}

private struct TransportControls: View {
    let isPlaying: Bool
    let send: (MediaCommand) -> Void

    var body: some View {
        HStack(spacing: 22) {
            button("backward.fill", label: "Previous", size: 13, command: .previousTrack)
            button(isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "Pause" : "Play", size: 18, command: .togglePlayPause)
                .contentTransition(.symbolEffect(.replace))
            button("forward.fill", label: "Next", size: 13, command: .nextTrack)
        }
        .foregroundStyle(.white)
    }

    private func button(_ symbol: String, label: String, size: CGFloat, command: MediaCommand) -> some View {
        Button {
            send(command)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 28, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(label)
    }
}

/// Shrinks a little while pressed and springs back on release.
private struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Shows how far into the track playback is, moving on while it plays. Clicking or dragging seeks,
/// and hovering marks where a click would seek to.
private struct MediaProgressBar: View {
    let track: NowPlaying
    let seek: (TimeInterval) -> Void

    /// Where the pointer is while dragging.
    @State private var dragPosition: TimeInterval?
    /// Where the pointer is while hovering over the bar.
    @State private var hoverPosition: TimeInterval?
    /// Where a finished drag seeked to, shown until the source reports the new position.
    @State private var pendingSeek: TimeInterval?

    /// How long to hold a seeked position if the source never reports back.
    private static let pendingSeekHold: Duration = .seconds(2)

    private var duration: TimeInterval { track.duration ?? 0 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let position = dragPosition ?? pendingSeek ?? track.position(at: context.date)
            VStack(spacing: 1) {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.white)
                                .frame(width: width * fraction(of: position))
                        }
                        .frame(height: dragPosition == nil ? 4 : 6)
                        .frame(maxHeight: .infinity)
                        .overlay(alignment: .leading) {
                            if let target = dragPosition ?? hoverPosition {
                                seekMarker(at: target, width: width)
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(dragToSeek(width: width))
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location): hoverPosition = seekTarget(atX: location.x, width: width)
                            case .ended: hoverPosition = nil
                            }
                        }
                        .animation(.spring(duration: 0.2, bounce: 0.3), value: dragPosition == nil)
                        .animation(.spring(duration: 0.2, bounce: 0), value: hoverPosition == nil)
                }
                .frame(height: 10)
                HStack {
                    Text(Self.format(position))
                    Spacer()
                    Text(Self.format(duration))
                }
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.gray)
            }
        }
        .onChange(of: track) { pendingSeek = nil }
        // If the source never reports back, stop holding the seeked position.
        .task(id: pendingSeek) {
            guard pendingSeek != nil else { return }
            try? await Task.sleep(for: Self.pendingSeekHold)
            pendingSeek = nil
        }
    }

    /// A tick on the bar with the time above it, showing where a click would seek to.
    private func seekMarker(at target: TimeInterval, width: CGFloat) -> some View {
        let x = width * fraction(of: target)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(.white)
                .frame(width: 2, height: 12)
                .offset(x: x - 1)
            Text(Self.format(target))
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(white: 0.22), in: Capsule())
                .fixedSize()
                // Kept over the bar even when the pointer nears either end.
                .position(x: min(max(x, 22), width - 22), y: -9)
        }
        .frame(width: width, height: 10, alignment: .leading)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func seekTarget(atX x: CGFloat, width: CGFloat) -> TimeInterval {
        min(max(x / width, 0), 1) * duration
    }

    private func dragToSeek(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                dragPosition = seekTarget(atX: drag.location.x, width: width)
            }
            .onEnded { _ in
                guard let dragPosition else { return }
                seek(dragPosition)
                pendingSeek = dragPosition
                self.dragPosition = nil
            }
    }

    private func fraction(of position: TimeInterval) -> CGFloat {
        duration > 0 ? position / duration : 0
    }

    private static func format(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded(.down)).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}

/// A thin arm hanging from its pivot: swung in so the stylus sits in the grooves, resting beside
/// the record, or swung away while the artwork shows as a plain cover.
private struct Tonearm: View {
    enum Position {
        case away, resting, onRecord
    }

    let position: Position

    static let pivotRadius: CGFloat = 5
    private static let length: CGFloat = 62

    var body: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(Color(white: 0.75))
                .frame(width: 2, height: Self.length)
                .offset(y: Self.pivotRadius)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(white: 0.85))
                .frame(width: 5, height: 9)
                .rotationEffect(.degrees(20))
                .offset(x: -1, y: Self.pivotRadius + Self.length - 4)
            Circle()
                .fill(Color(white: 0.2))
                .stroke(Color(white: 0.5), lineWidth: 1)
                .frame(width: Self.pivotRadius * 2, height: Self.pivotRadius * 2)
        }
        .frame(width: Self.pivotRadius * 2, height: Self.pivotRadius + Self.length + 6, alignment: .top)
        .rotationEffect(
            .degrees(angle),
            anchor: UnitPoint(x: 0.5, y: Self.pivotRadius / (Self.pivotRadius + Self.length + 6))
        )
        .animation(.spring(duration: 0.6, bounce: 0.15), value: position)
    }

    private var angle: Double {
        switch position {
        case .away: -30
        case .resting: 0
        case .onRecord: 25
        }
    }
}

/// The artwork as the label of a vinyl record, or as a plain cover. The record turns at 33⅓ rpm
/// while media plays and stops where it is when playback pauses. Switching to the cover grows
/// the label out to the full size, squares off its corners and turns it upright, while the
/// record shrinks away beneath it.
///
/// A handleable record can be scratched by dragging it round, and gathers dust while it plays for
/// the brush to sweep off. Sweeping off the last speck makes it gleam.
private struct RecordOrCover: View {
    let artwork: Data?
    let isPlaying: Bool
    let showsRecord: Bool
    let size: CGFloat
    let coverCornerRadius: CGFloat
    var isHandleable = false
    /// Where the brush's pad is while it's held, in the record's coordinates.
    var brush: CGPoint?

    @State private var spin = Spin()
    /// Where the pointer was round the record, in degrees, and when, while it's scratching.
    @State private var scratch: (degrees: Double, time: Date)?
    /// `brush`, kept where the sweeping task can read it as it changes.
    @State private var brushAt: CGPoint?
    @State private var gleam = 0.0

    private var dust: RecordDust { .shared }

    /// How often dust settles on a playing record, and the brush sweeps.
    private static let dustSettles: Duration = .seconds(20)
    private static let sweepInterval: Duration = .milliseconds(30)
    /// How fast, in points a second, the pad and the record slide past each other at the brush's
    /// loudest. The record turning beneath a still brush hisses at under half that.
    private static let briskBrushing = 250.0

    /// Setting the record up takes its time, so the tonearm can be seen swinging into place;
    /// putting it away is quicker.
    static func morph(toRecord: Bool) -> Animation {
        toRecord ? .spring(duration: 0.5, bounce: 0.2) : .spring(duration: 0.45, bounce: 0.2)
    }

    private var labelSize: CGFloat { showsRecord ? size * 0.5 : size }
    private var canBeHandled: Bool { isHandleable && showsRecord }

    var body: some View {
        TimelineView(.animation(paused: !spin.isTurning || !showsRecord)) { context in
            let angle = showsRecord ? spin.angle(at: context.date) : .zero
            ZStack {
                RecordDisc(diameter: size)
                    .scaleEffect(showsRecord ? 1 : 0.5)
                    .opacity(showsRecord ? 1 : 0)
                if isHandleable {
                    DustView(specks: dust.specks, diameter: size)
                        .rotationEffect(angle)
                        .opacity(showsRecord ? 1 : 0)
                    RecordGleam(diameter: size)
                        .opacity(gleam)
                }
                ArtworkImage(data: artwork)
                    .frame(width: labelSize, height: labelSize)
                    .clipShape(RoundedRectangle(
                        cornerRadius: showsRecord ? labelSize / 2 : coverCornerRadius,
                        style: .continuous
                    ))
                    .rotationEffect(angle)
                Circle()
                    .fill(.black)
                    .frame(width: max(size * 0.05, 2), height: max(size * 0.05, 2))
                    .opacity(showsRecord ? 1 : 0)
            }
            // Animations from outside don't reach into a timeline's content, so the morph
            // springs from in here.
            .animation(Self.morph(toRecord: showsRecord), value: showsRecord)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(scratching, including: canBeHandled ? .all : .subviews)
        .onChange(of: isPlaying, initial: true) { _, isPlaying in
            spin.setPlaying(isPlaying, at: .now)
        }
        .onChange(of: brush, initial: true) { _, brush in
            brushAt = brush
            sweep()
        }
        // The brush keeps sweeping while it's held still, as the record turns beneath it.
        .task(id: brush != nil && canBeHandled) {
            guard brush != nil && canBeHandled else { return }
            TurntableSound.shared.begin()
            var last = (point: brushAt, time: Date.now)
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.sweepInterval)
                sweep()
                let now = Date.now
                if let point = brushAt {
                    hiss(at: point, from: last.point, over: now.timeIntervalSince(last.time))
                }
                last = (brushAt, now)
            }
            TurntableSound.shared.end()
        }
        .task(id: isPlaying && canBeHandled) {
            guard isPlaying && canBeHandled else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.dustSettles)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) { dust.settle() }
            }
        }
        .onDisappear {
            if scratch != nil { TurntableSound.shared.end() }
        }
    }

    /// Turns the record with the pointer as it's dragged round, holding it still in between, and
    /// lets it play on from wherever it's left.
    private var scratching: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { drag in
                let degrees = degreesRound(to: drag.location)
                guard let last = scratch else {
                    spin.hold(at: .now)
                    TurntableSound.shared.begin()
                    scratch = (degreesRound(to: drag.startLocation), drag.time)
                    return
                }
                scratch = (degrees, drag.time)
                // Close to the spindle, the angle swings wildly with the slightest move.
                let centre = CGPoint(x: size / 2, y: size / 2)
                guard hypot(drag.location.x - centre.x, drag.location.y - centre.y) > size * 0.1 else { return }
                let turned = remainder(degrees - last.degrees, 360)
                spin.turn(by: turned)
                let elapsed = drag.time.timeIntervalSince(last.time)
                if elapsed > 0 {
                    TurntableSound.shared.scratch(atSpeed: turned / elapsed / Spin.degreesPerSecond)
                }
            }
            .onEnded { _ in
                spin.letGo(at: .now)
                TurntableSound.shared.end()
                scratch = nil
            }
    }

    private func degreesRound(to point: CGPoint) -> Double {
        atan2(point.y - size / 2, point.x - size / 2) * 180 / .pi
    }

    /// The pad's hiss on the record, louder the faster they slide past each other: as the brush is
    /// swept about, and as the record turns beneath it. Silent off the record.
    private func hiss(at point: CGPoint, from previous: CGPoint?, over elapsed: TimeInterval) {
        let distance = hypot(point.x - size / 2, point.y - size / 2)
        guard distance - size / 2 < RecordBrush.padSize.height / 2, elapsed > 0 else {
            TurntableSound.shared.brush(atSpeed: 0)
            return
        }
        let swept = previous.map { hypot(point.x - $0.x, point.y - $0.y) / elapsed } ?? 0
        let turning = spin.isTurning ? Spin.degreesPerSecond * .pi / 180 * min(distance, size / 2) : 0
        TurntableSound.shared.brush(atSpeed: (swept + turning) / Self.briskBrushing)
    }

    /// Brushes off the specks under the brush's pad, wherever the record has turned them to.
    private func sweep() {
        guard let brushAt, canBeHandled else { return }
        let pad = CGRect(
            x: brushAt.x - RecordBrush.padSize.width / 2,
            y: brushAt.y - RecordBrush.padSize.height / 2,
            width: RecordBrush.padSize.width,
            height: RecordBrush.padSize.height
        ).insetBy(dx: -1, dy: -1)
        let turned = spin.angle(at: .now)
        var wasLeftClean = false
        withAnimation(.spring(duration: 0.3, bounce: 0)) {
            wasLeftClean = dust.sweep { pad.contains($0.position(turnedBy: turned, diameter: size)) }
        }
        guard wasLeftClean else { return }
        withAnimation(.spring(duration: 0.25, bounce: 0)) { gleam = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(duration: 0.9, bounce: 0)) { gleam = 0 }
        }
    }

    /// How far the record has turned: the angle it stopped at, plus however long it has played
    /// since. Held, it only turns as far as it's turned by hand.
    private struct Spin {
        /// 33⅓ revolutions per minute.
        static let degreesPerSecond = 200.0

        var restingDegrees = 0.0
        var playingSince: Date?
        var isPlaying = false
        var isHeld = false

        var isTurning: Bool { playingSince != nil }

        /// Kept within half a turn either way, so turning the label upright for the cover
        /// never spins it round more than half a turn.
        func angle(at date: Date) -> Angle {
            .degrees(remainder(degrees(at: date), 360))
        }

        mutating func setPlaying(_ isPlaying: Bool, at date: Date) {
            self.isPlaying = isPlaying
            update(at: date)
        }

        mutating func hold(at date: Date) {
            isHeld = true
            update(at: date)
        }

        mutating func letGo(at date: Date) {
            isHeld = false
            update(at: date)
        }

        mutating func turn(by degrees: Double) {
            restingDegrees += degrees
        }

        private mutating func update(at date: Date) {
            if isPlaying && !isHeld {
                playingSince = playingSince ?? date
            } else {
                restingDegrees = degrees(at: date)
                playingSince = nil
            }
        }

        private func degrees(at date: Date) -> Double {
            restingDegrees + (playingSince.map { date.timeIntervalSince($0) * Self.degreesPerSecond } ?? 0)
        }
    }
}

/// The dust on the Media Widget's record, kept while the Nook is closed. A little settles while
/// the record plays, up to a limit.
@MainActor
@Observable
private final class RecordDust {
    static let shared = RecordDust()

    struct Speck: Identifiable {
        let id = UUID()
        /// How far out it lies, as a fraction of the record's diameter, clear of the label.
        let distance: CGFloat
        let degrees: Double
        let diameter: CGFloat
        let opacity: Double

        static func random() -> Speck {
            Speck(
                distance: .random(in: 0.28...0.47),
                degrees: .random(in: 0..<360),
                diameter: .random(in: 0.8...1.6),
                opacity: .random(in: 0.3...0.6)
            )
        }

        /// Where it is on a record of `diameter` turned by `angle`, from the record's top-left corner.
        func position(turnedBy angle: Angle, diameter recordDiameter: CGFloat) -> CGPoint {
            let radians = (degrees + angle.degrees) * .pi / 180
            let radius = distance * recordDiameter
            return CGPoint(x: recordDiameter / 2 + radius * cos(radians), y: recordDiameter / 2 + radius * sin(radians))
        }
    }

    private static let most = 14

    private(set) var specks = (0..<6).map { _ in Speck.random() }

    func settle() {
        guard specks.count < Self.most else { return }
        specks.append(.random())
    }

    /// Sweeps off the specks `isUnderPad` picks out. Returns whether that left the record clean.
    func sweep(where isUnderPad: (Speck) -> Bool) -> Bool {
        guard !specks.isEmpty else { return false }
        specks.removeAll(where: isUnderPad)
        return specks.isEmpty
    }
}

/// Specks of dust lying on a record, before it's turned.
private struct DustView: View {
    let specks: [RecordDust.Speck]
    let diameter: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(specks) { speck in
                let position = speck.position(turnedBy: .zero, diameter: diameter)
                Circle()
                    .fill(.white.opacity(speck.opacity))
                    .frame(width: speck.diameter, height: speck.diameter)
                    .position(position)
                    .transition(.scale(scale: 2).combined(with: .opacity))
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }
}

/// A flash of light across a freshly cleaned record.
private struct RecordGleam: View {
    let diameter: CGFloat

    var body: some View {
        AngularGradient(
            colors: [.clear, .white.opacity(0.35), .clear, .clear, .white.opacity(0.35), .clear, .clear],
            center: .center,
            angle: .degrees(60)
        )
        .clipShape(Circle())
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }
}

/// A vinyl record without its label: concentric grooves under a sheen of light that stays put.
private struct RecordDisc: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.09))
            ForEach([0.94, 0.86, 0.78, 0.7, 0.62], id: \.self) { groove in
                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: diameter * groove, height: diameter * groove)
            }
            AngularGradient(
                colors: [.clear, .white.opacity(0.09), .clear, .clear, .white.opacity(0.09), .clear, .clear],
                center: .center,
                angle: .degrees(20)
            )
            .clipShape(Circle())
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Album artwork filling its frame, or a music note on a dark fill when there is none.
private struct ArtworkImage: View {
    let data: Data?

    var body: some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            GeometryReader { geometry in
                Image(systemName: "music.note")
                    .font(.system(size: geometry.size.width * 0.4, weight: .semibold))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.18))
            }
        }
    }
}

/// The now-playing Activity's artwork beside the camera, in the style chosen in the Media Widget.
struct NowPlayingArtwork: View {
    let artwork: Data?
    let isPlaying: Bool
    let size: CGFloat

    @AppStorage(showsTurntableKey) private var showsTurntable = true

    var body: some View {
        RecordOrCover(
            artwork: artwork,
            isPlaying: isPlaying,
            showsRecord: showsTurntable,
            size: size,
            coverCornerRadius: size * 0.2
        )
    }
}

/// Bars bouncing beside the Notch while media plays. They settle low when playback pauses.
struct Waveform: View {
    let isPlaying: Bool
    let height: CGFloat

    /// Each bar's speed and phase, so they move out of step with each other when there are no
    /// real levels to show.
    private static let bars: [(speed: Double, phase: Double)] = [(7.1, 0), (9.3, 1.2), (6.2, 2.4), (8.4, 0.7)]

    private var audio: SystemAudioLevels { .shared }

    var body: some View {
        // The bars follow the audio playing, bass to treble, while its levels can be read, and
        // otherwise move on their own.
        TimelineView(.animation(paused: !isPlaying || audio.levels != nil)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(Self.bars.indices, id: \.self) { index in
                    // Shading from gray at the foot to white at the tip, so the bars sit quietly
                    // beside the camera.
                    Capsule()
                        .fill(LinearGradient(colors: [Color(white: 0.4), Color(white: 0.9)], startPoint: .bottom, endPoint: .top))
                        .frame(width: 2.5, height: height * level(of: index, at: time))
                }
            }
            .frame(height: height)
            // Glides between level reports instead of stepping at their rate.
            .animation(.spring(duration: 0.12, bounce: 0), value: audio.levels)
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isPlaying)
        .onAppear { if isPlaying { audio.start() } }
        .onDisappear { if isPlaying { audio.stop() } }
        .onChange(of: isPlaying) { _, playing in
            if playing { audio.start() } else { audio.stop() }
        }
    }

    /// A bar's height as a fraction of the waveform's.
    private func level(of index: Int, at time: TimeInterval) -> CGFloat {
        guard isPlaying else { return 0.2 }
        if let levels = audio.levels, levels.indices.contains(index) {
            return 0.2 + 0.8 * CGFloat(levels[index])
        }
        let bar = Self.bars[index]
        return 0.35 + 0.65 * abs(sin(time * bar.speed / 2 + bar.phase))
    }
}
