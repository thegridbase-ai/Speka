import SwiftUI
import SwiftData
import VocabularyKit
import SpekaUI

/// The main screen after onboarding: per-level progress ring, today's due/new
/// counts, and the "Start studying" CTA.
struct HomeView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.modelContext) private var modelContext

    @State private var stats = WordStore.LevelStats(total: 0, known: 0, dueToday: 0, newToday: 0)
    @State private var summary = StatsStore.Summary(streak: 0, cardsToday: 0, goal: StatsStore.defaultDailyGoal)
    @State private var isStudying = false
    @State private var showSettings = false
    @State private var showProgress = false
    @State private var selectedMode: StudyMode = .flashcard

    private var level: CEFRLevel { profileStore.level ?? .a1 }
    private var language: SourceLanguage { profileStore.nativeLanguage ?? .tr }

    private var hasWork: Bool { stats.dueToday + stats.newToday > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                header

                streakRow

                progressRingCard

                todayCard

                modePicker

                startButton

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topLeading) { progressButton }
        .overlay(alignment: .topTrailing) { settingsButton }
        .onAppear {
            refresh()
            #if DEBUG
            // Test affordance: the `-speka-autostudy` launch arg jumps straight
            // into a study session so each mode can be smoke-tested headlessly.
            // An optional `-speka-mode <flashcard|type|listen|multipleChoice>`
            // pair selects which mode to launch. `-speka-settings` opens Settings.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-speka-autostudy") {
                if let i = args.firstIndex(of: "-speka-mode"),
                   i + 1 < args.count,
                   let mode = StudyMode(launchToken: args[i + 1]) {
                    selectedMode = mode
                }
                isStudying = true
            }
            if args.contains("-speka-settings") {
                showSettings = true
            }
            if args.contains("-speka-progress") {
                showProgress = true
            }
            #endif
        }
        .fullScreenCover(isPresented: $isStudying, onDismiss: refresh) {
            StudySessionView(level: level, language: language, mode: selectedMode)
                .environmentObject(profileStore)
        }
        .fullScreenCover(isPresented: $showSettings, onDismiss: refresh) {
            SettingsView()
                .environmentObject(profileStore)
        }
        .fullScreenCover(isPresented: $showProgress, onDismiss: refresh) {
            ProgressStatsView()
                .environmentObject(profileStore)
        }
    }

    private func refresh() {
        withAnimation(.easeInOut(duration: 0.3)) {
            stats = WordStore.stats(at: level, now: Date(), in: modelContext)
            summary = StatsStore.summary(now: Date(), in: modelContext)
        }
    }

    private var settingsButton: some View {
        circleButton(systemImage: "gearshape.fill") { showSettings = true }
            .padding(.trailing, 20)
            .padding(.top, 56)
    }

    private var progressButton: some View {
        circleButton(systemImage: "chart.bar.fill") { showProgress = true }
            .padding(.leading, 20)
            .padding(.top, 56)
    }

    private func circleButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SpekaColor.textSecondary)
                .frame(width: 44, height: 44)
                .background {
                    Circle().fill(SpekaColor.surface)
                }
                .overlay(Circle().strokeBorder(SpekaColor.border, lineWidth: 1))
                .shadow(color: SpekaColor.textPrimary.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("SPEKA")
                .font(SpekaFont.display(size: 32))
                .foregroundStyle(SpekaColor.primary.base)

            Text("\(Catalog.flag(for: language)) \(language.displayName) · English \(level.displayName)")
                .spekaFont(.subhead)
                .foregroundStyle(SpekaColor.textSecondary)
        }
    }

    private var streakRow: some View {
        HStack(spacing: 14) {
            StreakBadge(days: summary.streak)

            Spacer(minLength: 0)

            // Daily goal pill.
            HStack(spacing: 8) {
                Image(systemName: summary.goalReached ? "checkmark.seal.fill" : "target")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SpekaColor.onColor)
                HStack(spacing: 2) {
                    Text("\(summary.cardsToday)")
                        .contentTransition(.numericText())
                    Text("/ \(summary.goal)")
                }
                .font(SpekaFont.font(.callout))
                .fontWeight(.bold)
                .foregroundStyle(SpekaColor.onColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill((summary.goalReached ? SpekaAccent.mint : SpekaAccent.sky).base)
            }
        }
    }

    private var progressRingCard: some View {
        SpekaCard(cornerRadius: 24, padding: 24) {
            VStack(spacing: 18) {
                SpekaRing(progress: stats.progress, gradientStops: SpekaColor.brandStops) {
                    VStack(spacing: 4) {
                        Text(level.displayName)
                            .font(SpekaFont.display(size: 34))
                            .foregroundStyle(SpekaColor.primary.partner)
                        Text("\(Int(stats.progress * 100))%")
                            .spekaFont(.subhead)
                            .foregroundStyle(SpekaColor.textSecondary)
                            .contentTransition(.numericText())
                    }
                }
                .frame(width: 190, height: 190)

                Text("\(stats.known) of \(stats.total) words mastered")
                    .spekaFont(.subhead)
                    .foregroundStyle(SpekaColor.textSecondary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var todayCard: some View {
        HStack(spacing: 14) {
            statTile(
                value: stats.dueToday,
                label: "due",
                accent: .tangerine,
                systemImage: "clock.arrow.circlepath"
            )
            statTile(
                value: stats.newToday,
                label: "new today",
                accent: .lavender,
                systemImage: "sparkles"
            )
        }
    }

    private func statTile(
        value: Int,
        label: String,
        accent: SpekaAccent,
        systemImage: String
    ) -> some View {
        SpekaCard(cornerRadius: 18, padding: 18, accent: accent, systemImage: systemImage, softFill: true) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(value)")
                    .font(SpekaFont.font(.numberMD))
                    .foregroundStyle(SpekaColor.textPrimary)
                    .contentTransition(.numericText())
                Text(label)
                    .spekaFont(.caption)
                    .foregroundStyle(SpekaColor.textSecondary)
            }
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Practice mode")
                .font(SpekaFont.font(.label))
                .textCase(.uppercase)
                .foregroundStyle(SpekaColor.textTertiary)
                .padding(.leading, 4)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(StudyMode.allCases) { mode in
                    modeTile(mode)
                }
            }
        }
    }

    private func modeTile(_ mode: StudyMode) -> some View {
        let isSelected = selectedMode == mode
        let accent = mode.spekaAccent
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selectedMode = mode }
            UISelection.tap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SpekaColor.onColor)
                    .frame(width: 44, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accent.gradient)
                    }
                    .shadow(color: accent.base.opacity(0.35), radius: 8, x: 0, y: 4)
                Text(mode.title)
                    .spekaFont(.headline)
                    .foregroundStyle(SpekaColor.textPrimary)
                Text(mode.subtitle)
                    .spekaFont(.caption)
                    .foregroundStyle(SpekaColor.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? accent.soft : SpekaColor.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? accent.base : SpekaColor.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(color: SpekaColor.textPrimary.opacity(0.05), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        VStack(spacing: 14) {
            if !hasWork {
                SpekaMascot(state: .hero)
                    .frame(width: 110, height: 110)
                    .popIn()
            }

            SpekaButton(
                hasWork ? "Start studying" : "All caught up",
                systemImage: hasWork ? "play.fill" : "checkmark.circle.fill",
                variant: hasWork ? .brand : .disabled,
                fullWidth: true
            ) {
                guard hasWork else { return }
                isStudying = true
            }

            if !hasWork {
                Text("Come back tomorrow for more reviews.")
                    .spekaFont(.caption)
                    .foregroundStyle(SpekaColor.textTertiary)
            }
        }
        .padding(.top, 4)
    }
}
