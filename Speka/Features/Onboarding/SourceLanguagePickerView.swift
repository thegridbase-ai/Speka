import SwiftUI
import VocabularyKit
import SpekaUI

/// Step 1 of onboarding: choose the learner's native language.
///
/// Only languages with shipped data (Pass 1: Turkish) are selectable; the rest
/// render as disabled "coming soon" rows.
struct SourceLanguagePickerView: View {
    @Binding var selected: SourceLanguage?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(SourceLanguage.allCases, id: \.self) { language in
                        languageRow(language)
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
    }

    private var header: some View {
        VStack(spacing: 10) {
            SpekaMascot(state: .wave)
                .frame(width: 132, height: 132)
                .popIn()
                .padding(.top, 28)

            Text("SPEKA")
                .font(SpekaFont.display(size: 34))
                .foregroundStyle(SpekaColor.primary.base)

            Text("Learn English vocabulary")
                .spekaFont(.callout)
                .foregroundStyle(SpekaColor.textSecondary)

            Text("First, what's your native language?")
                .spekaFont(.headline)
                .foregroundStyle(SpekaColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 22)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 18)
    }

    private func languageRow(_ language: SourceLanguage) -> some View {
        let available = Catalog.isAvailable(language)
        let isSelected = selected == language

        return Button {
            guard available else { return }
            selected = language
            UISelection.tap()
        } label: {
            SpekaCard(
                cornerRadius: 18,
                padding: 16,
                accent: isSelected ? SpekaColor.primary : nil
            ) {
                HStack(spacing: 14) {
                    Text(Catalog.flag(for: language))
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(language.displayName)
                            .spekaFont(.headline)
                            .foregroundStyle(
                                available ? SpekaColor.textPrimary : SpekaColor.textTertiary
                            )
                        if !available {
                            Text("Coming soon")
                                .spekaFont(.caption)
                                .foregroundStyle(SpekaColor.textTertiary)
                        }
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(SpekaColor.primary.base)
                    } else if !available {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(SpekaColor.textTertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(available ? 1 : 0.6)
        .disabled(!available)
    }

    private var footer: some View {
        VStack {
            SpekaButton(
                "Continue",
                systemImage: "arrow.right",
                variant: selected == nil ? .disabled : .filled(.coral),
                fullWidth: true
            ) {
                guard selected != nil else { return }
                onContinue()
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 20)
    }
}
