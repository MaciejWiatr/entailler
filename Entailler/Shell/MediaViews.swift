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
                // As tall as the artwork: the title at its top edge, the controls at its bottom.
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
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

/// Artwork shows as a record on a turntable or as a plain cover. Clicking the artwork in the
/// Media Widget switches between them, and the choice sticks.
private let showsTurntableKey = "showsArtworkAsTurntable"

/// The Media Widget's artwork, switched by clicking it between a record on a minimal turntable
/// and a plain cover. Switching morphs one into the other: the record's label grows into the
/// cover as the record fades beneath it and the tonearm swings away, and back again.
private struct MediaArtwork: View {
    let artwork: Data?
    let isPlaying: Bool

    @AppStorage(showsTurntableKey) private var showsTurntable = true

    nonisolated static let size: CGFloat = 84
    /// Where the tonearm pivots, just off the record's top-right edge.
    private static let pivot = CGPoint(x: 94, y: 8)
    private static let baseDiameter: CGFloat = 16

    var body: some View {
        Button {
            showsTurntable.toggle()
        } label: {
            ZStack(alignment: .topLeading) {
                RecordOrCover(
                    artwork: artwork,
                    isPlaying: isPlaying,
                    showsRecord: showsTurntable,
                    size: Self.size,
                    coverCornerRadius: 10
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
            }
            .frame(
                width: showsTurntable ? Self.pivot.x + Self.baseDiameter / 2 : Self.size,
                height: Self.size,
                alignment: .topLeading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(RecordOrCover.morph, value: showsTurntable)
        .accessibilityLabel(showsTurntable ? "Show plain artwork" : "Show artwork on a turntable")
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
private struct RecordOrCover: View {
    let artwork: Data?
    let isPlaying: Bool
    let showsRecord: Bool
    let size: CGFloat
    let coverCornerRadius: CGFloat

    @State private var spin = Spin()

    static let morph = Animation.spring(duration: 0.45, bounce: 0.2)

    private var labelSize: CGFloat { showsRecord ? size * 0.5 : size }

    var body: some View {
        TimelineView(.animation(paused: !isPlaying || !showsRecord)) { context in
            ZStack {
                RecordDisc(diameter: size)
                    .scaleEffect(showsRecord ? 1 : 0.5)
                    .opacity(showsRecord ? 1 : 0)
                ArtworkImage(data: artwork)
                    .frame(width: labelSize, height: labelSize)
                    .clipShape(RoundedRectangle(
                        cornerRadius: showsRecord ? labelSize / 2 : coverCornerRadius,
                        style: .continuous
                    ))
                    .rotationEffect(showsRecord ? spin.angle(at: context.date) : .zero)
                Circle()
                    .fill(.black)
                    .frame(width: max(size * 0.05, 2), height: max(size * 0.05, 2))
                    .opacity(showsRecord ? 1 : 0)
            }
            // Animations from outside don't reach into a timeline's content, so the morph
            // springs from in here.
            .animation(Self.morph, value: showsRecord)
        }
        .frame(width: size, height: size)
        .onChange(of: isPlaying, initial: true) { _, isPlaying in
            spin.setPlaying(isPlaying, at: .now)
        }
    }

    /// How far the record has turned: the angle it stopped at, plus however long it has played since.
    private struct Spin {
        /// 33⅓ revolutions per minute.
        static let degreesPerSecond = 200.0

        var restingDegrees = 0.0
        var playingSince: Date?

        /// Kept within half a turn either way, so turning the label upright for the cover
        /// never spins it round more than half a turn.
        func angle(at date: Date) -> Angle {
            .degrees(remainder(degrees(at: date), 360))
        }

        mutating func setPlaying(_ isPlaying: Bool, at date: Date) {
            if isPlaying {
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

    /// Each bar's speed and phase, so they move out of step with each other.
    private static let bars: [(speed: Double, phase: Double)] = [(7.1, 0), (9.3, 1.2), (6.2, 2.4), (8.4, 0.7)]

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(Self.bars.indices, id: \.self) { index in
                    let bar = Self.bars[index]
                    let level = isPlaying ? 0.35 + 0.65 * abs(sin(time * bar.speed / 2 + bar.phase)) : 0.2
                    Capsule()
                        .fill(.white)
                        .frame(width: 2.5, height: height * level)
                }
            }
            .frame(height: height)
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isPlaying)
    }
}
