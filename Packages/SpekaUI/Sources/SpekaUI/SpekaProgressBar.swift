import SwiftUI

// MARK: - SpekaProgressBar

/// A rounded, candy-style horizontal progress bar.
///
/// A fully-rounded `surfaceSunken` track holds a solid accent fill; the fill
/// carries a lighter top-highlight stripe for a soft 3D "gel" read. Animates
/// smoothly as `progress` changes (honors Reduce Motion).
///
/// ```swift
/// SpekaProgressBar(progress: 0.6, accent: .sunflower)
/// ```
public struct SpekaProgressBar: View {
    /// Completion fraction, clamped to `0...1`.
    public var progress: Double
    public var accent: SpekaAccent
    public var height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        progress: Double,
        accent: SpekaAccent = .coral,
        height: CGFloat = 14
    ) {
        self.progress = min(max(progress, 0), 1)
        self.accent = accent
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            let fillWidth = max(geo.size.width * progress, progress > 0 ? height : 0)
            ZStack(alignment: .leading) {
                // Track.
                Capsule(style: .continuous)
                    .fill(SpekaColor.surfaceSunken)

                // Accent fill + lighter top highlight stripe.
                Capsule(style: .continuous)
                    .fill(accent.base)
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
}

#Preview("SpekaProgressBar") {
    ZStack {
        SpekaBackground()
        VStack(spacing: 18) {
            SpekaProgressBar(progress: 0.3, accent: .coral)
            SpekaProgressBar(progress: 0.6, accent: .sunflower)
            SpekaProgressBar(progress: 0.9, accent: .mint, height: 18)
        }
        .padding(.horizontal, 32)
    }
}
