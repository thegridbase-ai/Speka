import SwiftUI

// MARK: - SpekaRing

/// "Sunny Studio" circular progress ring.
///
/// Re-skins GridBaseUIKit's `ProgressRing` geometry — a 270° sweep starting at
/// 135° (open bottom gap) with rounded caps — but renders **flat**: a solid
/// accent arc over a `surfaceSunken` track, no glow and no gradient. The arc
/// animates from empty to its target on appear with a friendly spring.
///
/// ```swift
/// SpekaRing(progress: 0.42, accent: .mint) {
///     VStack(spacing: 2) {
///         Text("A2").spekaFont(.displayTitle)
///         Text("42%").spekaFont(.caption)
///     }
/// }
/// ```
public struct SpekaRing<Center: View>: View {
    /// Completion fraction, clamped to `0...1`.
    public var progress: Double
    public var lineWidth: CGFloat
    public var accent: SpekaAccent
    /// Sweep of the arc in degrees (default 270).
    public var sweepDegrees: Double
    /// Start angle in degrees (default 135).
    public var startAngle: Double
    private let center: Center

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        progress: Double,
        lineWidth: CGFloat = 16,
        accent: SpekaAccent = .coral,
        sweepDegrees: Double = 270,
        startAngle: Double = 135,
        @ViewBuilder center: () -> Center
    ) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.accent = accent
        self.sweepDegrees = sweepDegrees
        self.startAngle = startAngle
        self.center = center()
    }

    public var body: some View {
        let trimStart = startAngle / 360.0
        let trimSpan = sweepDegrees / 360.0
        let trimEnd = trimStart + trimSpan * animatedProgress

        ZStack {
            // Flat track over the full sweep.
            Circle()
                .trim(from: trimStart, to: trimStart + trimSpan)
                .stroke(
                    SpekaColor.surfaceSunken,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Flat solid accent arc — no glow, no gradient.
            Circle()
                .trim(from: trimStart, to: trimEnd)
                .stroke(
                    accent.base,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            center
        }
        .padding(lineWidth / 2)
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                animatedProgress = newValue
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    animatedProgress = newValue
                }
            }
        }
    }
}

public extension SpekaRing where Center == EmptyView {
    /// Convenience initializer with no center content.
    init(
        progress: Double,
        lineWidth: CGFloat = 16,
        accent: SpekaAccent = .coral,
        sweepDegrees: Double = 270,
        startAngle: Double = 135
    ) {
        self.init(
            progress: progress,
            lineWidth: lineWidth,
            accent: accent,
            sweepDegrees: sweepDegrees,
            startAngle: startAngle
        ) { EmptyView() }
    }
}

#Preview("SpekaRing") {
    ZStack {
        SpekaBackground()
        HStack(spacing: 28) {
            SpekaRing(progress: 0.42, accent: .mint) {
                VStack(spacing: 2) {
                    Text("A2")
                        .spekaFont(.displayTitle)
                        .foregroundStyle(SpekaColor.textPrimary)
                    Text("42%")
                        .spekaFont(.caption)
                        .foregroundStyle(SpekaColor.textSecondary)
                }
            }
            .frame(width: 150, height: 150)

            SpekaRing(progress: 0.78, accent: .lavender)
                .frame(width: 110, height: 110)
        }
        .padding(24)
    }
}
