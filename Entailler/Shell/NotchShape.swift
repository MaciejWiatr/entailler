import SwiftUI

/// The outline of the Notch and Nook: a body hanging from the top of the screen with rounded
/// bottom corners, whose top corners flare outwards in inverted arches that meet the screen edge.
/// The flares sit inside the rectangle, so the body is `topCornerRadius` narrower on each side.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    /// How far the control points reach along each edge. Longer than a circular arc's 0.552,
    /// so the curve eases into the straight edges instead of meeting them abruptly.
    private static let smoothing: CGFloat = 0.64

    func path(in rect: CGRect) -> Path {
        let top = min(topCornerRadius, rect.width / 4, rect.height / 2)
        let bottom = min(bottomCornerRadius, rect.width / 2 - top, rect.height - top)
        let k = Self.smoothing
        let left = rect.minX + top
        let right = rect.maxX - top

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left flare: curves from the screen edge down into the body's left side.
        path.addCurve(
            to: CGPoint(x: left, y: rect.minY + top),
            control1: CGPoint(x: rect.minX + top * k, y: rect.minY),
            control2: CGPoint(x: left, y: rect.minY + top * (1 - k))
        )
        path.addLine(to: CGPoint(x: left, y: rect.maxY - bottom))
        path.addCurve(
            to: CGPoint(x: left + bottom, y: rect.maxY),
            control1: CGPoint(x: left, y: rect.maxY - bottom * (1 - k)),
            control2: CGPoint(x: left + bottom * (1 - k), y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: right - bottom, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: right, y: rect.maxY - bottom),
            control1: CGPoint(x: right - bottom * (1 - k), y: rect.maxY),
            control2: CGPoint(x: right, y: rect.maxY - bottom * (1 - k))
        )
        path.addLine(to: CGPoint(x: right, y: rect.minY + top))

        // Top-right flare, mirroring the left one back out to the screen edge.
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: right, y: rect.minY + top * (1 - k)),
            control2: CGPoint(x: rect.maxX - top * k, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
