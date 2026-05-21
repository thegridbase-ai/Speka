import SwiftUI

// MARK: - SpekaCard

/// "Sunny Studio" container card. A solid white `surface` fill with a generous
/// continuous corner radius and a soft, low warm shadow.
///
/// The accent variant adds a 2px accent border and a tinted icon chip — it
/// **never** tints the whole card, so body text stays crisp on white.
///
/// ```swift
/// SpekaCard {
///     Text("Plain card").foregroundStyle(SpekaColor.textPrimary)
/// }
///
/// SpekaCard(accent: .mint, systemImage: "checkmark.seal.fill") {
///     Text("Correct!").foregroundStyle(SpekaColor.textPrimary)
/// }
/// ```
public struct SpekaCard<Content: View>: View {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    /// Optional accent — adds a 2px border and a tinted leading icon.
    public var accent: SpekaAccent?
    /// SF Symbol shown in the tinted icon chip (accent variant only).
    public var systemImage: String?
    private let content: Content

    public init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 18,
        accent: SpekaAccent? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.accent = accent
        self.systemImage = systemImage
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let accent, let systemImage {
                iconChip(accent: accent, systemImage: systemImage)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(padding)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(SpekaColor.surface)
        }
        .overlay {
            if let accent {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(accent.base, lineWidth: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Soft, slightly magenta-tinted shadow: ~12%, blur 30, y14.
        .shadow(color: SpekaColor.textPrimary.opacity(0.12), radius: 30, x: 0, y: 14)
    }

    private func iconChip(accent: SpekaAccent, systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(SpekaColor.onColor)
            .frame(width: 40, height: 40)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.gradient)
            }
            .shadow(color: accent.base.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

#Preview("SpekaCard") {
    ZStack {
        SpekaBackground()
        VStack(spacing: 18) {
            SpekaCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plain Card")
                        .spekaFont(.headline)
                        .foregroundStyle(SpekaColor.textPrimary)
                    Text("Solid white surface, soft shadow.")
                        .spekaFont(.subhead)
                        .foregroundStyle(SpekaColor.textSecondary)
                }
            }
            SpekaCard(accent: .mint, systemImage: "checkmark.seal.fill") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Correct!")
                        .spekaFont(.headline)
                        .foregroundStyle(SpekaColor.textPrimary)
                    Text("Accent border + tinted icon, crisp body.")
                        .spekaFont(.subhead)
                        .foregroundStyle(SpekaColor.textSecondary)
                }
            }
        }
        .padding(24)
    }
}
