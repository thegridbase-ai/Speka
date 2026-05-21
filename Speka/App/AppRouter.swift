import SwiftUI
import SpekaUI

/// Top-level router: onboarding until a profile exists, then the main app.
struct AppRouter: View {
    @EnvironmentObject private var profileStore: ProfileStore

    var body: some View {
        ZStack {
            SpekaBackground()

            if profileStore.isOnboarded {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: profileStore.isOnboarded)
    }
}
