import SwiftUI

// MARK: - SpekaProgressBar

/// A rounded, candy-style horizontal progress bar.
///
/// A fully-rounded `surfaceSunken` track holds the fill; the fill carries a
/// lighter top-highlight stripe for a soft 3D "gel" read. The fill is a solid
/// accent by default, or a gradient when `gradientStops` is supplied (e.g.
/// ``SpekaColor/brandStops`` for the in-session header bars). Animates smoothly
/// as `progress` changes (honors Reduce Motion).
///
/// ```swift
/// SpekaProgressBar(progress: 0.6, accent: .sunflower)
/// SpekaProgressBar(progress: 0.6, gradientStops: SpekaColor.brandStops)
/// ```
public struct SpekaProgressBar: View {
    /// Completion fraction, clamped to `0...1`.
    public var progress: Double
    public var accent: SpekaAccent
    /// Optional gradient stops; when non-nil the fill is this gradient.
    public var gradientStops: [Color]?
    public var height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        progress: Double,
        accent: SpekaAccent = .coral,
        gradientStops: [Color]? = nil,
        height: CGFloat = 14
    ) {
        self.progress = min(max(progress, 0), 1)
        self.accent = accent
        self.gradientStops = gradientStops
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            let fillWidth = max(geo.size.width * progress, progress > 0 ? height : 0)
            ZStack(alignment: .leading) {
                // Track.
                Capsule(style: .continuous)
                    .fill(SpekaColor.surfaceSunken)

                // Accent (or gradient) fill + lighter top highlight stripe.
                Capsule(style: .continuous)
                    .fill(fillStyle)
                    .overlay(alignment: .top) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.28))
                            .frame(height: height * 0.34)
                            .padding(.horizontal, height * 0.28)
                            .padding(.top, height * 0.16)
                    }
                    .frame(width: fillWidth)
                    .animation(
                        reduceMotion ? nil
                            : .spring(response: 0.5, dampingFraction: 0.8),
                        value: progress
                    )
            }
        }
        .frame(height: height)
    }

    /// The fill: a horizontal gradient when `gradientStops` is supplied,
    /// otherwise the solid `accent.base`.
    private var fillStyle: AnyShapeStyle {
        guard let stops = gradientStops, stops.count >= 2 else {
            return AnyShapeStyle(accent.base)
        }
        return AnyShapeStyle(
            LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing)
        )
    }
}

#Preview("SpekaProgressBar") {
    ZStack {
        SpekaBackground()
        VStack(spacing: 18) {
            SpekaProgressBar(progress: 0.4, gradientStops: SpekaColor.brandStops)
            SpekaProgressBar(progress: 0.6, accent: .sky)
            SpekaProgressBar(progress: 0.9, accent: .mint, height: 18)
        }
        .padding(.horizontal, 32)
    }
}
