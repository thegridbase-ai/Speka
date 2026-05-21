import SwiftUI
import SpekaUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

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
        // Forward the Google OAuth callback URL to the GoogleSignIn SDK. No-op
        // until the URL scheme below is configured (see TODO in Info.plist /
        // project.yml). Harmless when auth isn't configured — it simply returns
        // `false` for URLs it doesn't recognise.
        .onOpenURL { url in
            #if canImport(GoogleSignIn)
            _ = GIDSignIn.sharedInstance.handle(url)
            #endif
        }
    }
}
