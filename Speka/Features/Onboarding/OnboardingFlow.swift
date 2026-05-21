import SwiftUI
import SwiftData
import VocabularyKit
import SpekaUI

/// Two-step onboarding: pick native language, then pick CEFR level.
struct OnboardingFlow: View {
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var selectedLanguage: SourceLanguage?
    @State private var step: Step = .language

    private enum Step { case language, level }

    var body: some View {
        VStack {
            switch step {
            case .language:
                SourceLanguagePickerView(selected: $selectedLanguage) {
                    withAnimation(.easeInOut(duration: 0.3)) { step = .level }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))

            case .level:
                LevelPickerView(
                    language: selectedLanguage ?? .tr,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) { step = .language }
                    },
                    onConfirm: { level in
                        guard let language = selectedLanguage else { return }
                        profileStore.complete(language: language, level: level)
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}
