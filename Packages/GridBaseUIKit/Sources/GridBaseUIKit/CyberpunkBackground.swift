import SwiftUI

// MARK: - Cyberpunk Background

/// Layered GridBase background: deep-black gradient, a faint circuit grid,
/// drifting scan lines, a vignette, and an optional accent pulse overlay.
///
/// Ported from Haptic's `CyberpunkBackground`, recolored to the GridBase
/// palette. Drop it at the back of a `ZStack`; it ignores safe area.
public struct CyberpunkBackground: View {
    public var showScanLines: Bool
    public var showCircuitPattern: Bool
    /// 0...1 accent bloom intensity (e.g. driven by a beat / event).
    public var pulseIntensity: Double
    /// Accent tint for the pulse overlay. Defaults to the cyan accent.
    public var accent: Color

    public init(
        showScanLines: Bool = true,
        showCircuitPattern: Bool = true,
        pulseIntensity: Double = 0,
        accent: Color = GridBaseColors.cyan
    ) {
        self.showScanLines = showScanLines
        self.showCircuitPattern = showCircuitPattern
        self.pulseIntensity = pulseIntensity
        self.accent = accent
    }

    public var body: some View {
        ZStack {
            // Base gradient — deep space black with a subtle blue.
            LinearGradient(
                colors: [
                    GridBaseColors.background,
                    GridBaseColors.backgroundElevated,
                    GridBaseColors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Circuit pattern layer.
            if showCircuitPattern {
                CircuitPatternView()
                    .opacity(0.015 + pulseIntensity * 0.01)
            }

            // Scan lines overlay.
            if showScanLines {
                ScanLinesView()
                    .opacity(0.02)
            }

            // Vignette.
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.4)
                ],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )

            // Accent pulse overlay.
            if pulseIntensity > 0 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(pulseIntensity * 0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .scaleEffect(1.0 + pulseIntensity * 0.2)
                    .animation(.easeOut(duration: 0.15), value: pulseIntensity)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Scan Lines

/// Thin horizontal scan lines that slowly drift downward.
public struct ScanLinesView: View {
    public init() {}

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let lineHeight: CGFloat = 2
                let gap: CGFloat = 3
                let totalStep = lineHeight + gap
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let drift = CGFloat(elapsed.truncatingRemainder(dividingBy: 12.0)) / 12.0 * totalStep
                var y: CGFloat = -totalStep + drift

                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: lineHeight)
                    context.fill(Path(rect), with: .color(.white))
                    y += totalStep
                }
            }
        }
    }
}

// MARK: - Circuit Pattern

/// Faint circuit grid with intersection nodes and a few right-angle traces.
public struct CircuitPatternView: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            let lineWidth: CGFloat = 1

            // Horizontal lines.
            for y in stride(from: 0, to: size.height, by: gridSize) {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.white), lineWidth: lineWidth)
            }

            // Vertical lines.
            for x in stride(from: 0, to: size.width, by: gridSize) {
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(.white), lineWidth: lineWidth)
            }

            // Circuit nodes at intersections (organic, sparse).
            for x in stride(from: 0, to: size.width, by: gridSize) {
                for y in stride(from: 0, to: size.height, by: gridSize) {
                    if Int.random(in: 0...3) == 0 {
                        let rect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                        context.fill(Path(ellipseIn: rect), with: .color(.white))
                    }
                }
            }

            // Random right-angle traces.
            for _ in 0..<15 {
                let startX = CGFloat.random(in: 0...max(size.width, 1))
                let startY = CGFloat.random(in: 0...max(size.height, 1))
                let endX = startX + CGFloat.random(in: -80...80)
                let endY = startY + CGFloat.random(in: -80...80)

                let path = Path { p in
                    p.move(to: CGPoint(x: startX, y: startY))
                    if Bool.random() {
                        p.addLine(to: CGPoint(x: endX, y: startY))
                        p.addLine(to: CGPoint(x: endX, y: endY))
                    } else {
                        p.addLine(to: CGPoint(x: startX, y: endY))
                        p.addLine(to: CGPoint(x: endX, y: endY))
                    }
                }
                context.stroke(path, with: .color(.white), lineWidth: lineWidth)
            }
        }
    }
}

#Preview("CyberpunkBackground") {
    ZStack {
        CyberpunkBackground(pulseIntensity: 0.5)
        Text("GRIDBASE")
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundStyle(GridBaseColors.cyan)
            .neonGlow(radius: 12)
    }
}
