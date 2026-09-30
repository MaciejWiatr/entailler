import NotchCore
import SwiftUI

enum NookLayout {
    static let width: CGFloat = 640
    /// Room between the view switcher and the Widgets, and below the Widgets.
    static let contentTopPadding: CGFloat = 8
    static let contentBottomPadding: CGFloat = 22

    /// The open Nook: the view switcher, as tall as the Notch, over a row of Widgets.
    static func size(around placement: NotchPlacement) -> CGSize {
        CGSize(width: width, height: placement.height + contentTopPadding + MediaWidgetView.height + contentBottomPadding)
    }
    /// How close the pointer has to come to the collapsed Notch to count as resting on it:
    /// this far out on each side, and this far below it.
    static let hoverProximity = CGSize(width: 24, height: 16)
    /// Spare room around the Nook, per side, for the opening spring to overshoot into.
    static let springOvershoot = CGSize(width: 40, height: 40)
    /// Radius of the inverted arches flaring the open Nook's top corners into the screen edge.
    static let openFlareRadius: CGFloat = 14
    static let openCornerRadius: CGFloat = 24
    static let closedCornerRadius: CGFloat = 10

    /// The collapsed Notch. An Activity widens it with a wing on each side of the camera.
    static func closedSize(around placement: NotchPlacement, activity: Activity?) -> CGSize {
        CGSize(width: placement.width + wingWidth(for: activity, around: placement) * 2, height: placement.height)
    }

    /// A Flash Activity's wings are wider, to fit a level bar beside the camera.
    static func wingWidth(for activity: Activity?, around placement: NotchPlacement) -> CGFloat {
        switch activity?.kind {
        case nil: 0
        case .flash: placement.height * 2
        case .ongoing: placement.height
        }
    }
}

/// Draws the display state: the collapsed Notch with its Activity, or the open Nook.
struct NotchView: View {
    let core: NotchCore

    var body: some View {
        if case .present(let placement) = core.state.visibility {
            NotchSurface(
                state: core.state,
                placement: placement,
                switchNook: { core.switchNook(to: $0) },
                sendMediaCommand: { core.sendMediaCommand($0) }
            )
        }
    }
}

private struct NotchSurface: View {
    let state: NotchDisplayState
    let placement: NotchPlacement
    let switchNook: (NookView) -> Void
    let sendMediaCommand: (MediaCommand) -> Void

    private var notchHeight: CGFloat { placement.height }

    var body: some View {
        let shape = isOpen
            ? NotchShape(topCornerRadius: NookLayout.openFlareRadius, bottomCornerRadius: NookLayout.openCornerRadius)
            : NotchShape(topCornerRadius: 0, bottomCornerRadius: NookLayout.closedCornerRadius)
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
    }

    /// Opening springs out of the camera cutout; closing tucks back in without overshoot.
    private var nookAnimation: Animation {
        isOpen ? .spring(duration: 0.38, bounce: 0.3) : .spring(duration: 0.25, bounce: 0)
    }

    @ViewBuilder private var content: some View {
        switch state.nook {
        case .closed:
            if let activity = state.activity {
                ActivityWings(activity: activity, media: state.media, placement: placement)
            }
        case .open(let view):
            VStack(spacing: 0) {
                ViewSwitcher(selected: view, switchNook: switchNook)
                    .frame(height: notchHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, NookLayout.openFlareRadius + 20)
                switch view {
                case .home:
                    HStack {
                        MediaWidgetView(media: state.media, send: sendMediaCommand)
                            .frame(width: 320)
                        Spacer()
                    }
                    .padding(.horizontal, NookLayout.openFlareRadius + 20)
                    .padding(.top, NookLayout.contentTopPadding)
                    .padding(.bottom, NookLayout.contentBottomPadding)
                case .files:
                    Spacer()
                }
            }
            .transition(.opacity)
        }
    }

    private var size: CGSize {
        switch state.nook {
        case .open:
            NookLayout.size(around: placement)
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

    private var notchHeight: CGFloat { placement.height }
    private var wingWidth: CGFloat { NookLayout.wingWidth(for: activity, around: placement) }

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(width: wingWidth, height: notchHeight)
            Spacer(minLength: placement.width)
            trailing.frame(width: wingWidth, height: notchHeight)
        }
        .transition(.opacity)
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
        // A stand-in until the upcoming-event feature ticket gives it real content.
        case .upcomingEvent:
            placeholder("calendar")
        }
    }

    @ViewBuilder private var trailing: some View {
        switch activity {
        case .flash(let change):
            LevelBar(change: change)
                .padding(.horizontal, notchHeight / 3)
        case .nowPlaying:
            Waveform(isPlaying: isPlaying, height: notchHeight * 0.4)
        case .upcomingEvent:
            EmptyView()
        }
    }

    private var track: NowPlaying? { media.nowPlaying }
    private var isPlaying: Bool { track?.isPlaying ?? false }

    private func placeholder(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
    }
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
