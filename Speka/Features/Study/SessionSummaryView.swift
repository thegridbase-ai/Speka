import SwiftUI
import SpekaUI

/// End-of-session celebration ("Oturum tamam!"): a brand-gradient check burst,
/// a 3-stat row (correct / accuracy / time), a streak card and a brand-gradient
/// "Continue" CTA. The payoff moment of every session.
struct SessionSummaryView: View {
    let reviewed: Int
    let correct: Int
    /// Elapsed session time in seconds (drives the "time" stat).
    var durationSeconds: TimeInterval = 0
    /// Current consecutive-day streak (drives the streak card).
    var streak: Int = 0
    let onDone: () -> Void

    @State private var appeared = false
    @State private var fireConfetti = false
    @State private var animatedCorrect = 0
    @State private var animatedAccuracy = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accuracy: Int {
        guard reviewed > 0 else { return 0 }
        return Int((Double(correct) / Double(reviewed)) * 100)
    }

    /// Whole-minute duration, floored to 1 min once any time has elapsed.
    private var minutes: Int {
        guard durationSeconds > 0 else { return 0 }
        return max(1, Int((durationSeconds / 60).rounded()))
    }

    var body: some View {
        ZStack {
            SpekaBackground()

            VStack(spacing: 22) {
                Spacer()

                checkBurst
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                    .opacity(appeared || reduceMotion ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Oturum tamam!")
                        .font(SpekaFont.font(.displayTitle))
                        .foregroundStyle(SpekaColor.textPrimary)

                    Text("\(reviewed) kelimeyi gözden geçirdin · harika gidiyorsun")
                        .spekaFont(.subhead)
                        .foregroundStyle(SpekaColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }

                statsRow
                    .padding(.horizontal, 24)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
                    .opacity(appeared || reduceMotion ? 1 : 0)

                streakCard
                    .padding(.horizontal, 24)
                    .opacity(appeared || reduceMotion ? 1 : 0)

                Spacer()

                SpekaButton("Devam et", systemImage: "play.fill", variant: .brand, fullWidth: true) {
                    onDone()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }

            SpekaConfetti(isActive: fireConfetti)
                .allowsHitTesting(false)
        }
        .onAppear(perform: runAppear)
    }

    private func runAppear() {
        fireConfetti = true
        GradeHaptics.play(.success)
        if reduceMotion {
            appeared = true
            animatedCorrect = correct
            animatedAccuracy = accuracy
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
            appeared = true
        }
        // Count-up the stats so `.numericText()` rolls from 0 to the totals.
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            animatedCorrect = correct
            animatedAccuracy = accuracy
        }
    }

    // MARK: - Pieces

    /// The brand-gradient circle with a white check, mascot-free per the mockup.
    private var checkBurst: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(SpekaColor.onColor)
            .frame(width: 132, height: 132)
            .background {
                Circle().fill(SpekaColor.brandGradient)
            }
            .shadow(color: SpekaColor.primary.base.opacity(0.4), radius: 22, x: 0, y: 12)
    }

    private var statsRow: some View {
        HStack(spacing: 14) {
            statTile(value: "\(animatedCorrect)", label: "Doğru")
            statTile(value: "\(animatedAccuracy)%", label: "İsabet")
            statTile(value: "\(minutes)dk", label: "Süre")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        SpekaCard(cornerRadius: 18, padding: 16) {
            VStack(spacing: 6) {
                Text(value)
                    .font(SpekaFont.font(.numberMD))
                    .foregroundStyle(SpekaColor.primary.base)
                    .contentTransition(.numericText())
                Text(label)
                    .spekaFont(.caption)
                    .foregroundStyle(SpekaColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var streakCard: some View {
        SpekaCard(cornerRadius: 18, padding: 16, accent: .tangerine, systemImage: "flame.fill") {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(streak) günlük seri")
                        .font(SpekaFont.font(.headline))
                        .foregroundStyle(SpekaColor.textPrimary)
                    Text("🔥")
                }
                Text("Yarın da gel, seriyi kırma")
                    .spekaFont(.caption)
                    .foregroundStyle(SpekaColor.textSecondary)
            }
        }
    }
}

#Preview("SessionSummary") {
    SessionSummaryView(
        reviewed: 20,
        correct: 18,
        durationSeconds: 240,
        streak: 7,
        onDone: {}
    )
}
