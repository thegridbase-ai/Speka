import SwiftUI
import SwiftData
import VocabularyKit
import SpekaUI

/// The main screen after onboarding: per-level progress ring, today's due/new
/// counts, and the "Start studying" CTA.
struct HomeView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var syncService: SyncService
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
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 18) {
                    levelSelector

                    streakRow

                    Spacer(minLength: 12)

                    progressRingCard

                    todayCard

                    Spacer(minLength: 12)

                    startButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                // Fill the viewport so the spacers distribute the content (ring
                // centered, CTA at the bottom) instead of bunching at the top.
                .frame(minHeight: geo.size.height - 72, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
        }
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
                .environmentObject(authStore)
                .environmentObject(syncService)
        }
        .fullScreenCover(isPresented: $showSettings, onDismiss: refresh) {
            SettingsView()
                .environmentObject(profileStore)
                .environmentObject(authStore)
                .environmentObject(syncService)
        }
        .fullScreenCover(isPresented: $showProgress, onDismiss: refresh) {
            ProgressStatsView()
                .environmentObject(profileStore)
                .environmentObject(authStore)
                .environmentObject(syncService)
        }
    }

    private func refresh() {
        withAnimation(.easeInOut(duration: 0.3)) {
            stats = WordStore.stats(at: level, now: Date(), in: modelContext)
            summary = StatsStore.summary(now: Date(), in: modelContext)
        }
    }

    /// Pinned top bar: progress + settings buttons flanking the SPEKA wordmark.
    /// Lives in `safeAreaInset` so it stays put while the content scrolls under it.
    private var topBar: some View {
        ZStack {
            header
            HStack {
                progressButton
                Spacer(minLength: 0)
                settingsButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background {
            SpekaColor.canvas
                .ignoresSafeArea(edges: .top)
                .shadow(color: SpekaColor.textPrimary.opacity(0.06), radius: 10, y: 5)
        }
    }

    private var settingsButton: some View {
        circleButton(systemImage: "gearshape.fill") { showSettings = true }
    }

    private var progressButton: some View {
        circleButton(systemImage: "chart.bar.fill") { showProgress = true }
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

    /// Compact CEFR level selector. Seeded levels (A1, A2) are selectable; the
    /// rest show locked / "coming soon". Choosing a level persists + syncs it via
    /// `profileStore.setLevel` and the whole screen re-reads against it.
    private var levelSelector: some View {
        HStack(spacing: 8) {
            ForEach(CEFRLevel.allCases, id: \.self) { lvl in
                levelPill(lvl)
            }
        }
    }

    private func levelPill(_ lvl: CEFRLevel) -> some View {
        let available = Catalog.isAvailable(lvl)
        let isSelected = level == lvl
        return Button {
            guard available, !isSelected else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                profileStore.setLevel(lvl)
            }
            syncService.schedulePush()
            refresh()
            UISelection.tap()
        } label: {
            VStack(spacing: 2) {
                Text(lvl.displayName)
                    .font(SpekaFont.font(.callout))
                    .fontWeight(.bold)
                if !available {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundStyle(
                isSelected ? SpekaColor.onColor
                    : (available ? SpekaColor.textSecondary : SpekaColor.textTertiary)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(SpekaColor.brandGradient)
                                     : AnyShapeStyle(SpekaColor.surface))
            }
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SpekaColor.border, lineWidth: 1)
                }
            }
            .shadow(
                color: isSelected ? SpekaColor.primary.base.opacity(0.3) : .clear,
                radius: isSelected ? 10 : 0, y: isSelected ? 5 : 0
            )
        }
        .buttonStyle(.plain)
        .opacity(available ? 1 : 0.55)
        .disabled(!available || isSelected)
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
