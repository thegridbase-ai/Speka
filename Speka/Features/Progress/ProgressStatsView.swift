import SwiftUI
import SwiftData
import VocabularyKit
import SpekaUI

/// İlerleme / İstatistik — the progress screen.
///
/// Shows the CEFR level path (the active level filled with the brand gradient),
/// a "Bu hafta" weekly bar chart (brand-gradient bars) and a stats row
/// (words learned / day streak / accuracy). Every number is derived from real
/// `StudySession` + `Word` data via `StatsStore` / `WordStore`; a fresh user
/// legitimately sees an empty week and zeros.
struct ProgressStatsView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var report = StatsStore.ProgressReport(
        weeklyCounts: Array(repeating: 0, count: 7), weeklyTotal: 0, accuracy: nil, streak: 0
    )
    @State private var learnedCount = 0

    private var level: CEFRLevel { profileStore.level ?? .a1 }

    var body: some View {
        ZStack {
            SpekaBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 22) {
                        levelPath
                        weeklyCard
                        statsRow
                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        report = StatsStore.progress(now: Date(), in: modelContext)
        learnedCount = WordStore.stats(at: level, now: Date(), in: modelContext).known
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SpekaColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Text("İlerleme")
                .font(SpekaFont.font(.title))
                .foregroundStyle(SpekaColor.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 4)
    }

    // MARK: - CEFR level path

    private var levelPath: some View {
        HStack(spacing: 8) {
            ForEach(CEFRLevel.allCases, id: \.self) { lvl in
                levelChip(lvl)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func levelChip(_ lvl: CEFRLevel) -> some View {
        let isCurrent = lvl == level
        return Text(lvl.displayName)
            .font(SpekaFont.font(.callout))
            .fontWeight(.bold)
            .foregroundStyle(isCurrent ? SpekaColor.onColor : SpekaColor.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(chipFill(isCurrent: isCurrent))
            }
            .overlay {
                if !isCurrent {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(SpekaColor.border, lineWidth: 1)
                }
            }
            .shadow(
                color: isCurrent ? SpekaColor.primary.base.opacity(0.35) : .clear,
                radius: isCurrent ? 12 : 0, x: 0, y: isCurrent ? 6 : 0
            )
    }

    private func chipFill(isCurrent: Bool) -> AnyShapeStyle {
        isCurrent
            ? AnyShapeStyle(SpekaColor.brandGradient)
            : AnyShapeStyle(SpekaColor.surface)
    }

    // MARK: - Weekly chart

    private var weeklyCard: some View {
        SpekaCard(cornerRadius: 22, padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Bu hafta · \(report.weeklyTotal) kelime")
                    .font(SpekaFont.font(.headline))
                    .foregroundStyle(SpekaColor.textPrimary)
                    .contentTransition(.numericText())

                WeeklyBarChart(counts: report.weeklyCounts)
                    .frame(height: 150)
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 14) {
            statTile(value: "\(learnedCount)", label: "öğrenildi", flame: false)
            statTile(value: "\(report.streak)", label: "gün seri", flame: true)
            statTile(value: report.accuracy.map { "\($0)%" } ?? "—", label: "isabet", flame: false)
        }
    }

    private func statTile(value: String, label: String, flame: Bool) -> some View {
        SpekaCard(cornerRadius: 18, padding: 16) {
            VStack(spacing: 6) {
                HStack(spacing: 2) {
                    Text(value)
                        .font(SpekaFont.font(.numberMD))
                        .foregroundStyle(SpekaColor.primary.base)
                        .contentTransition(.numericText())
                    if flame { Text("🔥").font(.system(size: 18)) }
                }
                Text(label)
                    .spekaFont(.caption)
                    .foregroundStyle(SpekaColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - WeeklyBarChart

/// A 7-bar weekly chart with brand-gradient bars and Mon-first weekday labels.
/// Bar heights scale to the week's max; a zero-count day shows a short stub so
/// the axis still reads. Animates the bars up on appear (honors Reduce Motion).
private struct WeeklyBarChart: View {
    let counts: [Int]

    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var maxCount: Int { max(counts.max() ?? 0, 1) }

    var body: some View {
        GeometryReader { geo in
            let labels = StatsStore.ProgressReport.weekdayLabels
            let labelHeight: CGFloat = 20
            let barAreaHeight = max(geo.size.height - labelHeight, 0)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(counts.enumerated()), id: \.offset) { idx, count in
                    VStack(spacing: 8) {
                        Spacer(minLength: 0)

                        Capsule(style: .continuous)
                            .fill(SpekaColor.brandGradient)
                            .frame(height: barHeight(count: count, area: barAreaHeight))

                        Text(labels.indices.contains(idx) ? labels[idx] : "")
                            .spekaFont(.caption)
                            .foregroundStyle(SpekaColor.textTertiary)
                            .frame(height: labelHeight)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            if reduceMotion {
                grown = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { grown = true }
            }
        }
    }

    private func barHeight(count: Int, area: CGFloat) -> CGFloat {
        guard area > 0 else { return 0 }
        let minStub: CGFloat = 8
        let fraction = CGFloat(count) / CGFloat(maxCount)
        let target = minStub + (area - minStub) * fraction
        return grown ? target : minStub
    }
}

#Preview("Progress") {
    ProgressStatsView()
        .environmentObject(ProfileStore())
}
