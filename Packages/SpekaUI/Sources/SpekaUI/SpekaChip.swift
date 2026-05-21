import SwiftUI

// MARK: - SpekaChip

/// A small pill/tag chip in the Sunny Studio language.
///
/// - Unselected: accent `soft` fill with `base`-colored text.
/// - Selected: `base` fill with white text.
///
/// ```swift
/// SpekaChip("Nouns", accent: .sky, isSelected: filter == .nouns) {
///     filter = .nouns
/// }
/// ```
public struct SpekaChip: View {
    private let title: String
    private let systemImage: String?
    private let accent: SpekaAccent
    private let isSelected: Bool
    private let action: (() -> Void)?

    public init(
        _ title: String,
        systemImage: String? = nil,
        accent: SpekaAccent = .coral,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
            }
            Text(title)
                .spekaFont(.callout)
        }
        .foregroundStyle(isSelected ? SpekaColor.onColor : accent.base)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? accent.base : accent.soft)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview("SpekaChip") {
    ZStack {
        SpekaBackground()
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                SpekaChip("Nouns", accent: .sky, isSelected: true)
                SpekaChip("Verbs", accent: .sky)
                SpekaChip("New", systemImage: "sparkles", accent: .bubblegum)
            }
            HStack(spacing: 10) {
                SpekaChip("A1", accent: .mint, isSelected: true)
                SpekaChip("A2", accent: .tangerine)
                SpekaChip("B1", accent: .lavender)
            }
        }
        .padding(24)
    }
}
