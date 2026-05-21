import SwiftUI

// MARK: - Progress Ring

/// Circular per-level progress arc in the GridBase style.
///
/// Uses the same sweep geometry as Haptic's `ArcSlider` (a 270° arc starting
/// at 135°, i.e. an open bottom gap), drawing a dim track beneath a glowing
/// accent arc. Optimized for "X / Y words at this CEFR level" style displays:
/// pass `progress` (0...1) and an optional center label.
public struct ProgressRing<Center: View>: View {
    /// Completion fraction, clamped to `0...1`.
    public var progress: Double
    public var lineWidth: CGFloat
    public var accent: Color
    /// Sweep of the arc in degrees (default 270, matching ArcSlider).
    public var sweepDegrees: Double
    /// Start angle in degrees (default 135, matching ArcSlider).
    public var startAngle: Double
    private let center: Center

    public init(
        progress: Double,
        lineWidth: CGFloat = 12,
        accent: Color = GridBaseColors.cyan,
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
        // Convert the absolute 135°/270° sweep into SwiftUI trim fractions.
        // SwiftUI's `trim` runs clockwise from 3 o'clock (0°); ArcSlider's
        // 135° start maps to fraction 135/360.
        let trimStart = startAngle / 360.0
        let trimSpan = sweepDegrees / 360.0
        let trimEnd = trimStart + trimSpan * progress

        return ZStack {
            // Dim track over the full sweep.
            Circle()
                .trim(from: trimStart, to: trimStart + trimSpan)
                .stroke(
                    GridBaseColors.border,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Glowing accent arc.
            Circle()
                .trim(from: trimStart, to: trimEnd)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [accent.opacity(0.6), accent]),
                        center: .center,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(startAngle + sweepDegrees)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .neonGlow(color: accent, radius: lineWidth)
                .animation(.easeInOut(duration: 0.35), value: progress)

            center
        }
        .padding(lineWidth / 2)
        .aspectRatio(1, contentMode: .fit)
    }
}

public extension ProgressRing where Center == EmptyView {
    /// Convenience initializer with no center content.
    init(
        progress: Double,
        lineWidth: CGFloat = 12,
        accent: Color = GridBaseColors.cyan,
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

#Preview("ProgressRing") {
    ZStack {
        CyberpunkBackground()
        HStack(spacing: 28) {
            ProgressRing(progress: 0.42, accent: GridBaseColors.cyan) {
                VStack(spacing: 2) {
                    Text("A2")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(GridBaseColors.cyan)
                    Text("42%")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(GridBaseColors.textSecondary)
                }
            }
            .frame(width: 140, height: 140)

            ProgressRing(progress: 0.78, accent: GridBaseColors.purple)
                .frame(width: 100, height: 100)
        }
        .padding(24)
    }
}
