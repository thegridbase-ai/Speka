import SwiftUI
import SwiftData
import VocabularyKit
import SpekaUI

/// Step 2 of onboarding: choose the CEFR level to study.
///
/// Levels with shipped data (Pass 1: A1) show a live word count and are
/// selectable; the rest render disabled with a "coming soon" hint.
struct LevelPickerView: View {
    let language: SourceLanguage
    let onBack: () -> Void
    let onConfirm: (CEFRLevel) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var selected: CEFRLevel? = .a1
    @State private var counts: [CEFRLevel: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(CEFRLevel.allCases, id: \.self) { level in
                        levelRow(level)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            footer
        }
        .padding(.top, 12)
        .onAppear(perform: loadCounts)
    }

    private func loadCounts() {
        var result: [CEFRLevel: Int] = [:]
        for level in CEFRLevel.allCases where Catalog.isAvailable(level) {
            result[level] = WordStore.words(at: level, in: modelContext).count
        }
        counts = result
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SpekaColor.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Text("Choose your level")
                .font(SpekaFont.font(.title))
                .foregroundStyle(SpekaColor.textPrimary)
                .padding(.top, 8)

            Text("\(Catalog.flag(for: language)) \(language.displayName) speaker · learning English")
                .spekaFont(.subhead)
                .foregroundStyle(SpekaColor.textSecondary)
        }
        .padding(.bottom, 20)
    }

    private func levelRow(_ level: CEFRLevel) -> some View {
        let available = Catalog.isAvailable(level)
        let isSelected = selected == level
        let count = counts[level] ?? 0
        let accent = level.accent

        return Button {
            guard available else { return }
            selected = level
            UISelection.tap()
        } label: {
            SpekaCard(
                cornerRadius: 18,
                padding: 14,
                accent: isSelected ? accent : nil
            ) {
                HStack(spacing: 14) {
                    LevelBadge(
                        letter: String(level.displayName.prefix(1)),
                        accent: accent,
                        isLocked: !available,
                        size: 46
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(level.displayName + " · " + levelTitle(level))
                            .spekaFont(.headline)
                            .foregroundStyle(
                                available ? SpekaColor.textPrimary : SpekaColor.textTertiary
                            )
                        Text(available ? "\(count) words" : "Coming soon")
                            .spekaFont(.caption)
                            .foregroundStyle(SpekaColor.textTertiary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(accent.base)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(available ? 1 : 0.6)
        .disabled(!available)
    }

    private func levelTitle(_ level: CEFRLevel) -> String {
        switch level {
        case .a1: return "Beginner"
        case .a2: return "Elementary"
        case .b1: return "Intermediate"
        case .b2: return "Upper-Intermediate"
        case .c1: return "Advanced"
        case .c2: return "Proficient"
        }
    }

    private var footer: some View {
        VStack {
            SpekaButton(
                "Start learning",
                systemImage: "checkmark",
                variant: selected == nil ? .disabled : .filled((selected ?? .a1).accent),
                fullWidth: true
            ) {
                if let selected { onConfirm(selected) }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 20)
    }
}
