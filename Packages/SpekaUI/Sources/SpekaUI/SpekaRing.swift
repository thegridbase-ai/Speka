import SwiftUI

// MARK: - SpekaRing

/// "Palette C" circular progress ring.
///
/// Re-skins GridBaseUIKit's `ProgressRing` geometry — a 270° sweep starting at
/// 135° (open bottom gap) with rounded caps — over a `surfaceSunken` track. The
/// arc renders either as a solid accent fill (default) or, when `gradientStops`
/// is supplied (e.g. ``SpekaColor/brandStops``), as a gradient sweeping along
/// the arc via an `AngularGradient`. The arc animates from empty to its target
/// on appear with a friendly spring.
///
/// ```swift
/// // Solid accent arc:
/// SpekaRing(progress: 0.42, accent: .mint) { … }
///
/// // Brand-gradient hero arc:
/// SpekaRing(progress: 0.65, gradientStops: SpekaColor.brandStops) { … }
/// ```
public struct SpekaRing<Center: View>: View {
    /// Completion fraction, clamped to `0...1`.
    public var progress: Double
    public var lineWidth: CGFloat
    public var accent: SpekaAccent
    /// Optional gradient stops; when non-nil the arc sweeps this gradient
    /// instead of the solid `accent.base`.
    public var gradientStops: [Color]?
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
        gradientStops: [Color]? = nil,
        sweepDegrees: Double = 270,
        startAngle: Double = 135,
        @ViewBuilder center: () -> Center
    ) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.accent = accent
        self.gradientStops = gradientStops
        self.sweepDegrees = sweepDegrees
        self.startAngle = startAngle
        self.center = center()
    }

    public var body: some View {
        let trimStart = startAngle / 360.0
        let trimSpan = sweepDegrees / 360.0
        let trimEnd = trimStart + trimSpan * animatedProgress

        ZStack {
            // Track over the full sweep.
            Circle()
                .trim(from: trimStart, to: trimStart + trimSpan)
                .stroke(
                    SpekaColor.surfaceSunken,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Accent arc — solid fill, or a gradient swept along the arc.
            Circle()
                .trim(from: trimStart, to: trimEnd)
                .stroke(
                    arcStyle,
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

    /// The arc fill: a solid accent, or an `AngularGradient` swept along the
    /// arc when `gradientStops` is supplied. The angular gradient is rotated so
    /// its first stop aligns with the arc's start angle and it spans only the
    /// sweep, leaving the (hidden) gap unpainted.
    private var arcStyle: AnyShapeStyle {
        guard let stops = gradientStops, stops.count >= 2 else {
            return AnyShapeStyle(accent.base)
        }
        return AnyShapeStyle(
            AngularGradient(
                gradient: Gradient(colors: stops),
                center: .center,
                startAngle: .degrees(startAngle),
                endAngle: .degrees(startAngle + sweepDegrees)
            )
        )
    }
}

public extension SpekaRing where Center == EmptyView {
    /// Convenience initializer with no center content.
    init(
        progress: Double,
        lineWidth: CGFloat = 16,
        accent: SpekaAccent = .coral,
        gradientStops: [Color]? = nil,
        sweepDegrees: Double = 270,
        startAngle: Double = 135
    ) {
        self.init(
            progress: progress,
            lineWidth: lineWidth,
            accent: accent,
            gradientStops: gradientStops,
            sweepDegrees: sweepDegrees,
            startAngle: startAngle
        ) { EmptyView() }
    }
}

#Preview("SpekaRing") {
    ZStack {
        SpekaBackground()
        HStack(spacing: 28) {
            SpekaRing(progress: 0.65, gradientStops: SpekaColor.brandStops) {
                VStack(spacing: 2) {
                    Text("A2")
                        .spekaFont(.displayTitle)
                        .foregroundStyle(SpekaColor.primary.partner)
                    Text("65%")
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
