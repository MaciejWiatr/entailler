import NotchCore
import SwiftUI

enum NookLayout {
    static let size = CGSize(width: 640, height: 180)
    /// Spare room around the Nook, per side, for the opening spring to overshoot into.
    static let springOvershoot = CGSize(width: 40, height: 40)
    static let openCornerRadius: CGFloat = 24
    static let closedCornerRadius: CGFloat = 10

    /// The collapsed Notch. An Activity widens it with a wing on each side of the camera.
    static func closedSize(around placement: NotchPlacement, showingActivity: Bool) -> CGSize {
        let wings = showingActivity ? placement.height * 2 : 0
        return CGSize(width: placement.width + wings, height: placement.height)
    }
}

/// Draws the display state: the collapsed Notch with its Activity, or the open Nook.
struct NotchView: View {
    let core: NotchCore

    var body: some View {
        if case .present(let placement) = core.state.visibility {
            NotchSurface(state: core.state, placement: placement, switchNook: { core.switchNook(to: $0) })
        }
    }
}

private struct NotchSurface: View {
    let state: NotchDisplayState
    let placement: NotchPlacement
    let switchNook: (NookView) -> Void

    private var notchHeight: CGFloat { placement.height }

    var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius)
        ZStack(alignment: .top) {
            shape.fill(.black)
            content
        }
        // Growing from the top centre keeps the shape attached to the camera cutout.
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(nookAnimation, value: state.nook)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state.activity)
    }

    /// Opening springs out of the camera cutout; closing tucks back in without overshoot.
    private var nookAnimation: Animation {
        state.nook == .closed ? .spring(duration: 0.3, bounce: 0) : .spring(duration: 0.45, bounce: 0.3)
    }

    @ViewBuilder private var content: some View {
        switch state.nook {
        case .closed:
            if let activity = state.activity {
                ActivityWings(activity: activity, placement: placement)
            }
        case .open(let view):
            VStack(spacing: 0) {
                ViewSwitcher(selected: view, switchNook: switchNook)
                    .frame(height: notchHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                Spacer()
            }
            .transition(.opacity)
        }
    }

    private var size: CGSize {
        switch state.nook {
        case .open:
            NookLayout.size
        case .closed:
            NookLayout.closedSize(around: placement, showingActivity: state.activity != nil)
        }
    }

    private var cornerRadius: CGFloat {
        state.nook == .closed ? NookLayout.closedCornerRadius : NookLayout.openCornerRadius
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

/// Stand-in Activity drawing until each Activity's feature ticket gives it real content.
private struct ActivityWings: View {
    let activity: Activity
    let placement: NotchPlacement

    private var notchHeight: CGFloat { placement.height }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: notchHeight, height: notchHeight)
            Spacer(minLength: placement.width)
            Color.clear.frame(width: notchHeight, height: notchHeight)
        }
        .transition(.opacity)
    }

    private var symbol: String {
        switch activity.source {
        case .flash: "speaker.wave.2.fill"
        case .upcomingEvent: "calendar"
        case .nowPlaying: "music.note"
        }
    }
}
