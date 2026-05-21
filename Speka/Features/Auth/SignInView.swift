import SwiftUI
import SpekaUI
#if canImport(UIKit)
import UIKit
#endif

/// Optional sign-in screen (Palette C). Presented from Settings (and an optional
/// one-time post-onboarding prompt). Sign-in is **never** a hard gate — the
/// "Continue without an account" action dismisses straight back into the
/// fully-functional local-first app.
struct SignInView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    private enum Mode {
        case signIn, createAccount

        var title: String { self == .signIn ? "Sign in" : "Create account" }
        var togglePrompt: String {
            self == .signIn ? "Need an account? Create one" : "Already have an account? Sign in"
        }
    }

    var body: some View {
        ZStack {
            SpekaBackground()

            ScrollView {
                VStack(spacing: 24) {
                    SpekaMascot(state: .wave)
                        .frame(width: 120, height: 120)
                        .popIn()
                        .padding(.top, 48)

                    VStack(spacing: 8) {
                        Text("Sign in to back up &\nsync your progress")
                            .font(SpekaFont.font(.displayTitle))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(SpekaColor.textPrimary)
                        Text("Optional — SPEKA works fully offline. Sign in only to keep your streak safe across devices.")
                            .spekaFont(.subhead)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(SpekaColor.textSecondary)
                            .frame(maxWidth: 300)
                    }

                    googleButton

                    dividerRow

                    emailCard

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    primaryCTA

                    Button(mode.togglePrompt) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            mode = mode == .signIn ? .createAccount : .signIn
                            errorMessage = nil
                        }
                    }
                    .font(SpekaFont.font(.callout))
                    .foregroundStyle(SpekaColor.primary.base)

                    Spacer(minLength: 8)

                    Button("Continue without an account") {
                        dismiss()
                    }
                    .font(SpekaFont.font(.callout))
                    .foregroundStyle(SpekaColor.textTertiary)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Pieces

    private var googleButton: some View {
        Button {
            Task { await run { try await authStore.signInWithGoogle(presenting: Self.topViewController()) } }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                Text("Continue with Google")
                    .font(SpekaFont.font(.callout))
                    .fontWeight(.bold)
            }
            .foregroundStyle(SpekaColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SpekaColor.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(SpekaColor.borderStrong, lineWidth: 1.5)
            }
            .shadow(color: SpekaColor.textPrimary.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            line
            Text("or")
                .spekaFont(.caption)
                .foregroundStyle(SpekaColor.textTertiary)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(SpekaColor.border)
            .frame(height: 1)
    }

    private var emailCard: some View {
        SpekaCard(cornerRadius: 18, padding: 16) {
            VStack(spacing: 12) {
                field(
                    icon: "envelope.fill",
                    placeholder: "Email",
                    text: $email,
                    isSecure: false,
                    keyboard: .emailAddress
                )
                Rectangle().fill(SpekaColor.border).frame(height: 1)
                field(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: $password,
                    isSecure: true,
                    keyboard: .default
                )
            }
        }
    }

    @ViewBuilder
    private func field(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SpekaColor.textTertiary)
                .frame(width: 22)
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(SpekaFont.font(.body))
            .foregroundStyle(SpekaColor.textPrimary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SpekaAccent.coral.base)
            Text(message)
                .spekaFont(.caption)
                .foregroundStyle(SpekaColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SpekaAccent.coral.soft)
        }
    }

    private var primaryCTA: some View {
        SpekaButton(
            isWorking ? "Please wait…" : mode.title,
            systemImage: isWorking ? "hourglass" : "arrow.right",
            variant: isWorking ? .disabled : .brand,
            fullWidth: true
        ) {
            Task {
                await run {
                    switch mode {
                    case .signIn:
                        try await authStore.signInWithEmail(email, password: password)
                    case .createAccount:
                        try await authStore.createAccount(email, password: password)
                    }
                }
            }
        }
    }

    // MARK: - Action runner

    /// Runs an async auth action, surfacing errors in the banner and dismissing
    /// on success.
    private func run(_ action: @escaping () async throws -> Void) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await action()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Presenter lookup

    /// The top-most view controller, used as the Google sign-in presenter.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

#Preview("SignIn") {
    SignInView()
        .environmentObject(AuthStore())
}
