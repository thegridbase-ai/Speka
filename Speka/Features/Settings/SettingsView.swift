import SwiftUI
import SwiftData
import VocabularyKit
import SpekaUI

/// App settings: switch CEFR level / native language, tune the TTS speech rate,
/// set the daily goal, and reset learning progress.
///
/// Reachable from Home via the gear button. Styled with SpekaUI so it reads as
/// a native part of the "Sunny Studio" app rather than a stock form.
struct SettingsView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var speechRate: Double = Speaker.shared.rateMultiplier
    @State private var dailyGoal: Int = StatsStore.dailyGoal()
    @State private var showResetConfirm = false
    @State private var showSignIn = false

    private var level: CEFRLevel { profileStore.level ?? .a1 }
    private var language: SourceLanguage { profileStore.nativeLanguage ?? .tr }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "v\(v) (\(b))"
    }

    var body: some View {
        ZStack {
            SpekaBackground()

            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 22) {
                            accountSection
                            levelSection
                            languageSection
                            speechSection.id("speech")
                            dailyGoalSection
                            resetSection
                            versionFooter
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        #if DEBUG
                        // Test affordance: scroll to the lower controls so a single
                        // headless screenshot can verify speech / goal / reset.
                        if ProcessInfo.processInfo.arguments.contains("-speka-settings-bottom") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation { proxy.scrollTo("speech", anchor: .top) }
                            }
                        }
                        // Test affordance: open the sign-in sheet for screenshots.
                        if ProcessInfo.processInfo.arguments.contains("-speka-signin") {
                            showSignIn = true
                        }
                        #endif
                    }
                }
            }
        }
        .alert("Reset progress?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetProgress() }
        } message: {
            Text("This permanently clears all review history, streaks and study sessions. Your level and language are kept. This cannot be undone.")
        }
        .fullScreenCover(isPresented: $showSignIn) {
            SignInView()
                .environmentObject(authStore)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Account")
            SpekaCard(cornerRadius: 18, padding: 16) {
                switch authStore.state {
                case .signedIn(_, let email, let displayName):
                    signedInRow(email: email, displayName: displayName)
                case .signedOut:
                    signedOutRow
                }
            }
        }
    }

    private var signedOutRow: some View {
        Button {
            showSignIn = true
            UISelection.tap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SpekaColor.primary.base)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in")
                        .spekaFont(.headline)
                        .foregroundStyle(SpekaColor.textPrimary)
                    Text("Back up & sync your progress")
                        .spekaFont(.caption)
                        .foregroundStyle(SpekaColor.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SpekaColor.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func signedInRow(email: String?, displayName: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(SpekaAccent.mint.base)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName ?? email ?? "Signed in")
                    .spekaFont(.headline)
                    .foregroundStyle(SpekaColor.textPrimary)
                if displayName != nil, let email {
                    Text(email)
                        .spekaFont(.caption)
                        .foregroundStyle(SpekaColor.textTertiary)
                }
            }
            Spacer()
            Button("Sign out") {
                authStore.signOut()
                UISelection.tap()
            }
            .font(SpekaFont.font(.callout))
            .foregroundStyle(SpekaAccent.coral.base)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(SpekaColor.textSecondary)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            Text("Settings")
                .font(SpekaFont.font(.title))
                .foregroundStyle(SpekaColor.primary.base)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Section chrome

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(SpekaFont.font(.label))
            .textCase(.uppercase)
            .foregroundStyle(SpekaColor.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    // MARK: - Level

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("CEFR level")
            SpekaCard(cornerRadius: 18, padding: 12) {
                VStack(spacing: 8) {
                    ForEach(CEFRLevel.allCases, id: \.self) { lvl in
                        levelRow(lvl)
                    }
                }
            }
        }
    }

    private func levelRow(_ lvl: CEFRLevel) -> some View {
        let available = Catalog.isAvailable(lvl)
        let isSelected = level == lvl
        let accent = lvl.accent
        return Button {
            guard available, !isSelected else { return }
            profileStore.setLevel(lvl)
            syncService.schedulePush()
            UISelection.tap()
        } label: {
            HStack(spacing: 12) {
                LevelBadge(
                    letter: String(lvl.displayName.prefix(1)),
                    accent: accent,
                    isLocked: !available,
                    size: 38
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(lvl.displayName)
                        .spekaFont(.headline)
                        .foregroundStyle(available ? SpekaColor.textPrimary : SpekaColor.textTertiary)
                    Text(available ? "Available" : "Coming soon")
                        .spekaFont(.caption)
                        .foregroundStyle(SpekaColor.textTertiary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(SpekaAccent.mint.base)
                } else if !available {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SpekaColor.textTertiary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accent.soft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .opacity(available ? 1 : 0.6)
        .disabled(!available)
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Native language")
            SpekaCard(cornerRadius: 18, padding: 12) {
                VStack(spacing: 8) {
                    ForEach(SourceLanguage.allCases, id: \.self) { lang in
                        languageRow(lang)
                    }
                }
            }
        }
    }

    private func languageRow(_ lang: SourceLanguage) -> some View {
        let available = Catalog.isAvailable(lang)
        let isSelected = language == lang
        return Button {
            guard available, !isSelected else { return }
            profileStore.setLanguage(lang)
            syncService.schedulePush()
            UISelection.tap()
        } label: {
            HStack(spacing: 12) {
                Text(Catalog.flag(for: lang))
                    .font(.system(size: 22))
                    .frame(width: 32, alignment: .leading)
                Text(lang.displayName)
                    .spekaFont(.headline)
                    .foregroundStyle(available ? SpekaColor.textPrimary : SpekaColor.textTertiary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(SpekaAccent.mint.base)
                } else if !available {
                    Text("Coming soon")
                        .spekaFont(.caption)
                        .foregroundStyle(SpekaColor.textTertiary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? SpekaAccent.sky.soft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .opacity(available ? 1 : 0.6)
        .disabled(!available)
    }

    // MARK: - Speech rate

    private var speechSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Speech rate")
            SpekaCard(cornerRadius: 18, padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(SpekaColor.primary.base)
                        Text("\(Int(speechRate * 100))%")
                            .font(SpekaFont.font(.callout))
                            .foregroundStyle(SpekaColor.textPrimary)
                        Spacer()
                        Button {
                            Speaker.shared.speak("This is the speech rate")
                            UISelection.tap()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill")
                                Text("Preview")
                            }
                            .font(SpekaFont.font(.callout))
                            .foregroundStyle(SpekaColor.primary.base)
                        }
                        .buttonStyle(.plain)
                    }

                    Slider(
                        value: $speechRate,
                        in: Speaker.minRate...Speaker.maxRate
                    ) {
                        Text("Speech rate")
                    }
                    .tint(SpekaColor.primary.base)
                    .onChange(of: speechRate) { _, newValue in
                        Speaker.shared.setRate(newValue)
                    }
                }
            }
        }
    }

    // MARK: - Daily goal

    private var dailyGoalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Daily goal")
            SpekaCard(cornerRadius: 18, padding: 18, accent: .tangerine, systemImage: "target") {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(dailyGoal) cards / day")
                            .spekaFont(.headline)
                            .foregroundStyle(SpekaColor.textPrimary)
                        Text("Target reviews per day")
                            .spekaFont(.caption)
                            .foregroundStyle(SpekaColor.textTertiary)
                    }
                    Spacer()
                    Stepper(
                        "",
                        value: $dailyGoal,
                        in: StatsStore.minDailyGoal...StatsStore.maxDailyGoal,
                        step: 5
                    )
                    .labelsHidden()
                    .tint(SpekaColor.primary.base)
                    .onChange(of: dailyGoal) { _, newValue in
                        StatsStore.setDailyGoal(newValue)
                        syncService.schedulePush()
                    }
                }
            }
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Danger zone")
            SpekaButton(
                "Reset progress",
                systemImage: "trash.fill",
                variant: .ghost(.coral),
                fullWidth: true
            ) {
                showResetConfirm = true
            }
        }
    }

    private func resetProgress() {
        // Clear all per-learner state: review scheduling, aggregate progress and
        // recorded sessions. The seeded Word/Translation catalog is preserved so
        // every word returns to its `.new` state automatically.
        do {
            try modelContext.delete(model: ReviewState.self)
            try modelContext.delete(model: UserProgress.self)
            try modelContext.delete(model: StudySession.self)
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[Settings] reset failed: \(error)")
            #endif
        }
        GradeHaptics.play(.success)
        dismiss()
    }

    // MARK: - Version

    private var versionFooter: some View {
        Text("SPEKA · \(appVersion)")
            .spekaFont(.caption)
            .foregroundStyle(SpekaColor.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}
