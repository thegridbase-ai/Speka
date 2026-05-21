import SwiftUI

// MARK: - Glass Card

/// Glassmorphism container matching the GridBase design language:
/// a translucent `white/[0.06]` fill over an ultra-thin material, a
/// `white/[0.06]` hairline border, rounded corners and a soft drop shadow.
///
/// ```swift
/// GlassCard {
///     Text("Hello").foregroundStyle(GridBaseColors.textPrimary)
/// }
/// ```
public struct GlassCard<Content: View>: View {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    /// Optional accent tint for the border / glow (defaults to the standard
    /// hairline border, no accent).
    public var accent: Color?
    private let content: Content

    public init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 16,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.accent = accent
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(GridBaseColors.glass)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
            .shadow(color: (accent ?? .clear).opacity(0.18), radius: 16, x: 0, y: 0)
    }

    private var borderColor: Color {
        accent.map { $0.opacity(0.30) } ?? GridBaseColors.border
    }
}

#Preview("GlassCard") {
    ZStack {
        CyberpunkBackground()
        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Glass Card")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(GridBaseColors.textPrimary)
                    Text("white/[0.06] over ultra-thin material")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(GridBaseColors.textSecondary)
                }
            }
            GlassCard(accent: GridBaseColors.cyan) {
                Text("Accent variant")
                    .foregroundStyle(GridBaseColors.cyan)
            }
        }
        .padding(24)
    }
}
