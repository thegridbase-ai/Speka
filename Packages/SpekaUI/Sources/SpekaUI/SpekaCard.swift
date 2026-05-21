import SwiftUI

// MARK: - SpekaCard

/// "Sunny Studio" container card. A solid white `surface` fill with a generous
/// continuous corner radius and a soft, low warm shadow.
///
/// The accent variant adds a tinted icon chip plus, by default, a 2px accent
/// border on a white surface. Set `softFill` to instead tint the **whole** card
/// with the accent's soft wash and drop the border (the Home stat-tile look) —
/// body text still reads on the pale tint.
///
/// ```swift
/// SpekaCard {
///     Text("Plain card").foregroundStyle(SpekaColor.textPrimary)
/// }
///
/// // Outlined accent card (white surface, accent border):
/// SpekaCard(accent: .mint, systemImage: "checkmark.seal.fill") {
///     Text("Correct!").foregroundStyle(SpekaColor.textPrimary)
/// }
///
/// // Soft-filled tile (tinted bg, no border):
/// SpekaCard(accent: .tangerine, systemImage: "clock", softFill: true) {
///     Text("8 due").foregroundStyle(SpekaColor.textPrimary)
/// }
/// ```
public struct SpekaCard<Content: View>: View {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    /// Optional accent — adds a tinted leading icon chip.
    public var accent: SpekaAccent?
    /// SF Symbol shown in the tinted icon chip (accent variant only).
    public var systemImage: String?
    /// When `true`, fills the whole card with the accent's `soft` wash and
    /// omits the outline (default `false` → white surface + accent border).
    public var softFill: Bool
    private let content: Content

    public init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 18,
        accent: SpekaAccent? = nil,
        systemImage: String? = nil,
        softFill: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.accent = accent
        self.systemImage = systemImage
        self.softFill = softFill
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
                .fill(cardFill)
        }
        .overlay {
            // Outline only for the default (non-softFill) accent variant.
            if let accent, !softFill {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(accent.base, lineWidth: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Soft, slightly magenta-tinted shadow: ~12%, blur 30, y14. A
        // soft-filled tile reads lighter, so it carries a gentler shadow.
        .shadow(
            color: SpekaColor.textPrimary.opacity(softFill ? 0.06 : 0.12),
            radius: softFill ? 16 : 30,
            x: 0,
            y: softFill ? 8 : 14
        )
    }

    /// The card surface fill: the accent's soft wash when `softFill`, else white.
    private var cardFill: Color {
        if softFill, let accent { return accent.soft }
        return SpekaColor.surface
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
            HStack(spacing: 14) {
                SpekaCard(accent: .tangerine, systemImage: "clock.arrow.circlepath", softFill: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("8").font(SpekaFont.font(.numberMD))
                            .foregroundStyle(SpekaColor.textPrimary)
                        Text("due").spekaFont(.caption)
                            .foregroundStyle(SpekaColor.textSecondary)
                    }
                }
                SpekaCard(accent: .lavender, systemImage: "sparkles", softFill: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("20").font(SpekaFont.font(.numberMD))
                            .foregroundStyle(SpekaColor.textPrimary)
                        Text("new today").spekaFont(.caption)
                            .foregroundStyle(SpekaColor.textSecondary)
                    }
                }
            }
        }
        .padding(24)
    }
}
