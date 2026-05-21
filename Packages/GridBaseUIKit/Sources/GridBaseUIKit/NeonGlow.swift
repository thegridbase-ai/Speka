import SwiftUI

// MARK: - Neon Glow Modifier

/// Layered neon glow effect — three stacked shadows of decreasing opacity
/// and increasing radius to fake a soft bloom.
///
/// Ported from Haptic's `NeonGlow` modifier, defaulting to the GridBase
/// cyan accent.
public struct NeonGlow: ViewModifier {
    public var color: Color
    public var radius: CGFloat

    public init(color: Color = GridBaseColors.cyan, radius: CGFloat = 8) {
        self.color = color
        self.radius = radius
    }

    public func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius / 2)
            .shadow(color: color.opacity(0.5), radius: radius)
            .shadow(color: color.opacity(0.3), radius: radius * 1.5)
    }
}

public extension View {
    /// Applies the GridBase neon bloom around a view.
    ///
    /// - Parameters:
    ///   - color: Glow tint. Defaults to the cyan accent.
    ///   - radius: Base glow radius in points. Defaults to `8`.
    func neonGlow(color: Color = GridBaseColors.cyan, radius: CGFloat = 8) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }
}

#Preview("NeonGlow") {
    ZStack {
        GridBaseColors.background.ignoresSafeArea()
        VStack(spacing: 32) {
            Text("00f0ff")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(GridBaseColors.cyan)
                .neonGlow()
            Text("a855f7")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(GridBaseColors.purple)
                .neonGlow(color: GridBaseColors.purple, radius: 14)
        }
    }
}
