import SwiftUI

// MARK: - SpekaBackground

/// "Sunny Studio" canvas background. A soft cream vertical gradient
/// (`canvas → canvasBottom`) with an optional, very faint dot-grid.
///
/// This replaces GridBaseUIKit's `CyberpunkBackground` — **no** scan lines,
/// **no** vignette, **no** circuit traces. Drop it at the back of a `ZStack`;
/// it ignores the safe area.
///
/// ```swift
/// ZStack {
///     SpekaBackground()
///     content
/// }
/// ```
public struct SpekaBackground: View {
    /// Whether to draw the faint dot-grid texture (default `true`).
    public var showDotGrid: Bool
    /// Spacing between dots in points.
    public var dotSpacing: CGFloat
    /// Dot radius in points.
    public var dotRadius: CGFloat

    public init(
        showDotGrid: Bool = true,
        dotSpacing: CGFloat = 26,
        dotRadius: CGFloat = 1.1
    ) {
        self.showDotGrid = showDotGrid
        self.dotSpacing = dotSpacing
        self.dotRadius = dotRadius
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [SpekaColor.canvas, SpekaColor.canvasBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            if showDotGrid {
                DotGridView(spacing: dotSpacing, radius: dotRadius)
                    // ~3% in the border color — barely-there texture.
                    .foregroundStyle(SpekaColor.border)
                    .opacity(0.03)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Dot grid

/// A faint, evenly spaced dot grid drawn with a single `Canvas`.
public struct DotGridView: View {
    public var spacing: CGFloat
    public var radius: CGFloat

    public init(spacing: CGFloat = 26, radius: CGFloat = 1.1) {
        self.spacing = spacing
        self.radius = radius
    }

    public var body: some View {
        Canvas { context, size in
            guard spacing > 0 else { return }
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    let rect = CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .foreground)
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

#Preview("SpekaBackground") {
    ZStack {
        SpekaBackground()
        Text("SPEKA")
            .font(SpekaFont.display(size: 40))
            .foregroundStyle(SpekaColor.textPrimary)
    }
}
