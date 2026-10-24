import AppKit
import NotchCore
import SwiftUI

enum NookLayout {
    static let width: CGFloat = 640
    /// Room between the view switcher and the Widgets, and below the Widgets.
    static let contentTopPadding: CGFloat = 8
    static let contentBottomPadding: CGFloat = 22

    /// The open Nook: the view switcher, as tall as the Notch, over the view's content.
    static func size(around placement: NotchPlacement, view: NookView) -> CGSize {
        CGSize(width: width, height: placement.height + contentTopPadding + contentHeight(of: view) + contentBottomPadding)
    }

    /// The Nook at its tallest, which the window leaves room for whatever the view.
    static func largestSize(around placement: NotchPlacement) -> CGSize {
        [NookView.home, .calendar, .toDos, .files].map { size(around: placement, view: $0) }.max { $0.height < $1.height }!
    }

    /// The Calendar view's month grid, and the To-Dos view's list, are taller than a row of Widgets.
    private static func contentHeight(of view: NookView) -> CGFloat {
        switch view {
        case .home: MediaWidgetView.height
        case .files: FilesView.height
        case .calendar: CalendarMonthView.height
        case .toDos: ToDoListView.height
        }
    }
    /// How close the pointer has to come to the collapsed Notch to count as resting on it:
    /// this far out on each side, and this far below it.
    static let hoverProximity = CGSize(width: 24, height: 16)
    /// Spare room around the Nook, per side, for the opening spring to overshoot into.
    static let springOvershoot = CGSize(width: 40, height: 40)
    /// Radius of the inverted arches flaring the open Nook's top corners into the screen edge.
    static let openFlareRadius: CGFloat = 14
    /// The same arches on the collapsed Notch while an Activity spreads its wings.
    static let activityFlareRadius: CGFloat = 8
    static let openCornerRadius: CGFloat = 24
    static let closedCornerRadius: CGFloat = 10

    /// The collapsed Notch. An Activity widens it with a wing on each side of the camera, and a
    /// flare beyond each wing.
    static func closedSize(around placement: NotchPlacement, activity: Activity?) -> CGSize {
        let side = wingWidth(for: activity, around: placement) + closedFlareRadius(for: activity)
        return CGSize(width: placement.width + side * 2, height: placement.height)
    }

    /// The bare Notch blends into the camera cutout; only its wings flare into the screen edge.
    static func closedFlareRadius(for activity: Activity?) -> CGFloat {
        activity == nil ? 0 : activityFlareRadius
    }

    /// A Flash Activity's wings are wider, to fit a level bar beside the camera, and so are an
    /// upcoming call's, to fit its countdown and Join button, and a waiting Claude Code session's,
    /// to fit its project's name.
    static func wingWidth(for activity: Activity?, around placement: NotchPlacement) -> CGFloat {
        if case .claudeCode = activity { return placement.height * 2.6 }
        if joinLink(of: activity) != nil { return placement.height * 1.6 }
        return switch activity?.kind {
        case nil: 0
        case .flash: placement.height * 2
        case .ongoing: placement.height
        }
    }

    /// The link to join the call the Activity counts down to, if it is an upcoming call.
    static func joinLink(of activity: Activity?) -> URL? {
        guard case .upcomingEvent(let event) = activity else { return nil }
        return event.joinLink
    }

    /// The collapsed Notch's button, for joining an upcoming call or opening a waiting Claude Code
    /// session: its whole trailing wing, in the window's coordinates from the Notch's top edge.
    /// `nil` when the Activity has no button.
    static func buttonArea(around placement: NotchPlacement, activity: Activity?) -> CGRect? {
        guard joinLink(of: activity) != nil || activity?.source == .claudeCode else { return nil }
        let wing = wingWidth(for: activity, around: placement)
        return CGRect(x: placement.width / 2, y: 0, width: wing, height: placement.height)
    }
}

/// Draws the display state: the collapsed Notch with its Activity, or the open Nook.
struct NotchView: View {
    let core: NotchCore
    let drops: FileDrops

    var body: some View {
        if case .present(let placement) = core.state.visibility {
            NotchSurface(
                state: core.state,
                placement: placement,
                switchNook: { core.switchNook(to: $0) },
                sendMediaCommand: { core.sendMediaCommand($0) },
                calendarDayShown: { core.calendarDayShown($0) },
                moveCalendarMonth: { core.moveCalendarMonth(by: $0) },
                selectCalendarDay: { core.selectCalendarDay($0) },
                moveCalendarDay: { core.moveCalendarDay(by: $0) },
                showCalendarToday: { core.showCalendarToday() },
                setToDoDone: { core.setToDo($0, done: $1) },
                addToDo: { core.addToDo($0) },
                quickAdd: { core.quickAdd($0) },
                openClaudeSession: { core.openClaudeSession() },
                trayActions: TrayActions(
                    select: { core.selectTrayFile($0, $1) },
                    clearSelection: { core.clearTraySelection() },
                    remove: { core.removeFromTray($0) },
                    removeSelected: { core.removeSelectedTrayFiles() },
                    filesToDrag: { core.trayFilesToDrag(from: $0) },
                    dragOutEnded: { core.dragOutEnded($0, accepted: $1) }
                ),
                drops: drops
            )
        }
    }
}

private struct NotchSurface: View {
    let state: NotchDisplayState
    let placement: NotchPlacement
    let switchNook: (NookView) -> Void
    let sendMediaCommand: (MediaCommand) -> Void
    let calendarDayShown: (Int) -> Void
    let moveCalendarMonth: (Int) -> Void
    let selectCalendarDay: (Date) -> Void
    let moveCalendarDay: (Int) -> Void
    let showCalendarToday: () -> Void
    let setToDoDone: (String, Bool) -> Void
    let addToDo: (String) -> Void
    let quickAdd: (String) -> QuickAdd?
    let openClaudeSession: () -> Void
    let trayActions: TrayActions
    let drops: FileDrops

    private var notchHeight: CGFloat { placement.height }

    var body: some View {
        let shape = isOpen
            ? NotchShape(topCornerRadius: NookLayout.openFlareRadius, bottomCornerRadius: NookLayout.openCornerRadius)
            : NotchShape(
                topCornerRadius: NookLayout.closedFlareRadius(for: state.activity),
                bottomCornerRadius: NookLayout.closedCornerRadius
            )
        ZStack(alignment: .top) {
            shape.fill(.black)
            content
        }
        // Growing from the top centre keeps the shape attached to the camera cutout.
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(nookAnimation, value: state.nook)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: state.activity)
        // The Notch is always black, so text fields draw their caret and placeholder for dark.
        .environment(\.colorScheme, .dark)
    }

    /// Opening springs out of the camera cutout; closing tucks back in without overshoot.
    private var nookAnimation: Animation {
        isOpen ? .spring(duration: 0.38, bounce: 0.3) : .spring(duration: 0.25, bounce: 0)
    }

    @ViewBuilder private var content: some View {
        switch state.nook {
        case .closed:
            if let activity = state.activity {
                // A new identity per source, so switching Activities blurs one out and the next in.
                ActivityWings(activity: activity, media: state.media, placement: placement, openClaudeSession: openClaudeSession)
                    .padding(.horizontal, NookLayout.activityFlareRadius)
                    .id(activity.source)
            }
        case .open(let view):
            VStack(spacing: 0) {
                ViewSwitcher(selected: view, switchNook: switchNook)
                    .frame(height: notchHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, NookLayout.openFlareRadius + 20)
                switch view {
                case .home:
                    HStack(alignment: .top, spacing: 20) {
                        MediaWidgetView(media: state.media, send: sendMediaCommand)
                            .frame(width: 320)
                        // A hairline between the Widgets, as tall as they are.
                        Rectangle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 1, height: MediaWidgetView.height)
                        CalendarWidgetView(calendar: state.calendar, dayShown: calendarDayShown)
                            .frame(height: MediaWidgetView.height)
                    }
                    .padding(.horizontal, NookLayout.openFlareRadius + 20)
                    .padding(.top, NookLayout.contentTopPadding)
                    .padding(.bottom, NookLayout.contentBottomPadding)
                    // Space plays or pauses, and the arrows skip tracks.
                    .onKeyDown { event in
                        guard event.heldModifiers.isEmpty else { return false }
                        switch event.keyCode {
                        case 49: sendMediaCommand(.togglePlayPause)
                        case 123: sendMediaCommand(.previousTrack)
                        case 124: sendMediaCommand(.nextTrack)
                        default: return false
                        }
                        return true
                    }
                case .calendar:
                    CalendarMonthView(
                        month: state.calendarMonth,
                        move: moveCalendarMonth,
                        select: selectCalendarDay,
                        moveDay: moveCalendarDay,
                        showToday: showCalendarToday
                    )
                        .frame(height: CalendarMonthView.height)
                        .padding(.horizontal, NookLayout.openFlareRadius + 20)
                        .padding(.top, NookLayout.contentTopPadding)
                        .padding(.bottom, NookLayout.contentBottomPadding)
                case .toDos:
                    ToDoListView(toDos: state.toDos, setDone: setToDoDone, add: addToDo, quickAdd: quickAdd)
                        .frame(height: ToDoListView.height)
                        .padding(.horizontal, NookLayout.openFlareRadius + 20)
                        .padding(.top, NookLayout.contentTopPadding)
                        .padding(.bottom, NookLayout.contentBottomPadding)
                case .files:
                    FilesView(tray: state.tray, actions: trayActions, drops: drops)
                        .frame(height: FilesView.height)
                        .padding(.horizontal, NookLayout.openFlareRadius + 20)
                        .padding(.top, NookLayout.contentTopPadding)
                        .padding(.bottom, NookLayout.contentBottomPadding)
                }
            }
            .transition(.opacity)
        }
    }

    private var size: CGSize {
        switch state.nook {
        case .open(let view):
            NookLayout.size(around: placement, view: view)
        case .closed:
            NookLayout.closedSize(around: placement, activity: state.activity)
        }
    }

    private var isOpen: Bool {
        state.nook != .closed
    }
}

private struct ViewSwitcher: View {
    let selected: NookView
    let switchNook: (NookView) -> Void

    var body: some View {
        HStack(spacing: 4) {
            button(.home, symbol: "house.fill", label: "Home")
            button(.calendar, symbol: "calendar", label: "Calendar")
            button(.toDos, symbol: "checklist", label: "To-Dos")
            button(.files, symbol: "tray.fill", label: "Files")
        }
    }

    private func button(_ view: NookView, symbol: String, label: String) -> some View {
        Button {
            switchNook(view)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected == view ? .white : .gray)
                .frame(width: 28, height: 22)
                .background(selected == view ? Color.white.opacity(0.15) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// An Activity's content, split into a wing on each side of the camera. Now playing shows its
/// artwork on the left and a waveform on the right.
private struct ActivityWings: View {
    let activity: Activity
    let media: MediaWidget
    let placement: NotchPlacement
    let openClaudeSession: () -> Void

    private var notchHeight: CGFloat { placement.height }
    private var wingWidth: CGFloat { NookLayout.wingWidth(for: activity, around: placement) }

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(width: wingWidth, height: notchHeight)
            Spacer(minLength: placement.width)
            trailing.frame(width: wingWidth, height: notchHeight)
        }
        .transition(BlurReplace())
    }

    @ViewBuilder private var leading: some View {
        switch activity {
        case .flash(let change):
            // Inset from the Notch's edge by as much as the level bar on the other side.
            FlashSymbol(change: change)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, notchHeight / 3)
        case .nowPlaying:
            NowPlayingArtwork(artwork: track?.artwork, isPlaying: isPlaying, size: notchHeight - 10)
        case .upcomingEvent(let event) where event.joinLink != nil:
            HStack(spacing: 4) {
                Image(systemName: "video.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                EventCountdown(start: event.start)
            }
        case .upcomingEvent:
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        case .claudeCode(let session, let waiting):
            HStack(spacing: 5) {
                DancingClaudeBot(isAsking: session.reason == .needsInput)
                    .frame(width: 24, height: 15)
                if waiting > 1 {
                    Text("\(waiting)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, notchHeight / 3)
        }
    }

    @ViewBuilder private var trailing: some View {
        switch activity {
        case .flash(let change):
            LevelBar(change: change)
                .padding(.horizontal, notchHeight / 3)
        case .nowPlaying:
            Waveform(isPlaying: isPlaying, height: notchHeight * 0.4)
        case .upcomingEvent(let event):
            if let link = event.joinURL {
                // Clickable while the Notch is collapsed; see `NookLayout.buttonArea`.
                Button("Join") {
                    NSWorkspace.shared.open(link)
                }
                .buttonStyle(NotchJoinButtonStyle())
            } else {
                EventCountdown(start: event.start)
            }
        case .claudeCode(let session, _):
            // Clickable while the Notch is collapsed; see `NookLayout.buttonArea`.
            Button(session.project, action: openClaudeSession)
                .buttonStyle(NotchClaudeButtonStyle())
                .padding(.horizontal, 5)
                .accessibilityLabel("Open Claude Code in \(session.project)")
        }
    }

    private var track: NowPlaying? { media.nowPlaying }
    private var isPlaying: Bool { track?.isPlaying ?? false }
}

/// Fades content through a blur, so one Activity dissolves into the next rather than cross-fading.
private struct BlurReplace: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : 6)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

/// The Join button in an upcoming call's trailing wing.
private struct NotchJoinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 9)
            .frame(height: 18)
            .background(.green, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// The button in a waiting Claude Code session's trailing wing, named after its project.
private struct NotchClaudeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .frame(height: 18)
            .background(Color.claude, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// The Claude Code bot dancing a little: it sways from side to side, hopping on each beat and
/// lifting the legs on the side it leans away from, then rests. It dances faster while Claude asks
/// for something.
private struct DancingClaudeBot: View {
    let isAsking: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Step {
        /// Degrees clockwise, about the bot's feet.
        var tilt: Double = 0
        var lift: CGFloat = 0
    }

    private var beat: Double { isAsking ? 0.2 : 0.3 }
    /// How long the bot stands still between rounds of dancing.
    private var rest: Double { isAsking ? 0.4 : 1.2 }

    /// Up and back down within one beat.
    @KeyframeTrackContentBuilder<CGFloat> private var hop: some KeyframeTrackContent<CGFloat> {
        SpringKeyframe(-2, duration: beat / 2, spring: .snappy)
        SpringKeyframe(0, duration: beat / 2, spring: .bouncy)
    }

    var body: some View {
        if reduceMotion {
            ClaudeBot().fill(Color.claude)
        } else {
            KeyframeAnimator(initialValue: Step(), repeating: true) { step in
                ClaudeBot(raisedLegs: step.tilt > 2 ? .left : step.tilt < -2 ? .right : nil)
                    .fill(Color.claude)
                    .rotationEffect(.degrees(step.tilt), anchor: .bottom)
                    .offset(y: step.lift)
            } keyframes: { _ in
                KeyframeTrack(\.tilt) {
                    SpringKeyframe(-9, duration: beat, spring: .snappy)
                    SpringKeyframe(9, duration: beat, spring: .snappy)
                    SpringKeyframe(-9, duration: beat, spring: .snappy)
                    SpringKeyframe(9, duration: beat, spring: .snappy)
                    SpringKeyframe(0, duration: beat, spring: .snappy)
                    SpringKeyframe(0, duration: rest)
                }
                KeyframeTrack(\.lift) {
                    hop
                    hop
                    hop
                    hop
                    SpringKeyframe(0, duration: beat + rest)
                }
            }
        }
    }
}

/// The Claude Code bot from the welcome screen of the `claude` command, drawn in pixels twice as
/// tall as they are wide, as a terminal draws the block characters it's made of.
private struct ClaudeBot: Shape {
    enum Side { case left, right }

    /// The legs on this side are off the ground.
    var raisedLegs: Side?

    private static let pixels = [
        "..############..",
        "..##.######.##..",
        "################",
        "..############..",
        "...#.#....#.#...",
    ]
    private static let legRow = 4

    func path(in rect: CGRect) -> Path {
        let width = rect.width / CGFloat(Self.pixels[0].count)
        let height = rect.height / CGFloat(Self.pixels.count)
        var path = Path()
        for (row, line) in Self.pixels.enumerated() {
            for (column, pixel) in line.enumerated() where pixel == "#" {
                if row == Self.legRow, let raisedLegs, (column < line.count / 2) == (raisedLegs == .left) { continue }
                path.addRect(CGRect(x: rect.minX + CGFloat(column) * width, y: rect.minY + CGFloat(row) * height, width: width, height: height))
            }
        }
        return path
    }
}

private extension Color {
    /// Claude's terracotta.
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)
}

/// The icon of a volume or brightness Flash Activity.
private struct FlashSymbol: View {
    let change: LevelChange

    var body: some View {
        symbol
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
    }

    private var symbol: Image {
        switch change {
        case .volume(_, isMuted: true):
            Image(systemName: "speaker.slash.fill")
        case .volume(let level, isMuted: false):
            // The waves fill in as the volume rises.
            Image(systemName: "speaker.wave.3.fill", variableValue: level)
        case .brightness(let level):
            Image(systemName: level < 0.5 ? "sun.min.fill" : "sun.max.fill")
        }
    }
}

/// The level of a volume or brightness Flash Activity. Muted volume shows an empty bar.
private struct LevelBar: View {
    let change: LevelChange

    private var fraction: CGFloat {
        switch change {
        case .volume(_, isMuted: true): 0
        case .volume(let level, isMuted: false), .brightness(let level): level
        }
    }

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.2))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.white)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 5)
    }
}

