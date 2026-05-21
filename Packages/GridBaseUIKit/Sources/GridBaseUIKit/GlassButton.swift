import SwiftUI

// MARK: - Glass Button

/// Glass button matching the GridBase design language. A glassmorphism pill
/// with an accent-tinted border that brightens to `glass-hover` while pressed
/// and gains a subtle neon glow.
///
/// ```swift
/// GlassButton("Start", systemImage: "play.fill") { start() }
/// GlassButton("Delete", accent: GridBaseColors.error, role: .destructive) { ... }
/// ```
public struct GlassButton: View {
    private let title: String
    private let systemImage: String?
    private let accent: Color
    private let fullWidth: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        accent: Color = GridBaseColors.cyan,
        fullWidth: Bool = false,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        // Destructive role implies the error accent unless overridden.
        if role == .destructive, accent == GridBaseColors.cyan {
            self.accent = GridBaseColors.error
        } else {
            self.accent = accent
        }
        self.fullWidth = fullWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(GlassButtonStyle(accent: accent))
    }
}

// MARK: - Glass Button Style

/// The press-reactive styling behind ``GlassButton``. Exposed so callers can
/// apply the GridBase glass look to any custom `Button` label.
public struct GlassButtonStyle: ButtonStyle {
    public var accent: Color

    public init(accent: Color = GridBaseColors.cyan) {
        self.accent = accent
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(accent)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(pressed ? GridBaseColors.glassHover : GridBaseColors.glass)
                    }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(accent.opacity(pressed ? 0.55 : 0.30), lineWidth: 1)
            }
            .clipShape(Capsule(style: .continuous))
            .shadow(color: accent.opacity(pressed ? 0.45 : 0.22), radius: pressed ? 12 : 8)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: pressed)
    }
}

#Preview("GlassButton") {
    ZStack {
        CyberpunkBackground()
        VStack(spacing: 18) {
            GlassButton("Start Session", systemImage: "play.fill") {}
            GlassButton("Review", accent: GridBaseColors.purple) {}
            GlassButton("Delete", role: .destructive) {}
            GlassButton("Full Width", systemImage: "checkmark", fullWidth: true) {}
                .padding(.horizontal, 24)
        }
    }
}
