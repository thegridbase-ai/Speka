import SwiftUI
import SpekaUI

/// End-of-session celebration: Pip trophy, count-up stats, confetti and a
/// full-width "Done" CTA. The payoff moment of every session.
struct SessionSummaryView: View {
    let reviewed: Int
    let correct: Int
    /// Level / mode accent used for the card glow + headline tint.
    var accent: SpekaAccent = .mint
    let onDone: () -> Void

    @State private var appeared = false
    @State private var fireConfetti = false
    @State private var animatedReviewed = 0
    @State private var animatedAccuracy = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accuracy: Int {
        guard reviewed > 0 else { return 0 }
        return Int((Double(correct) / Double(reviewed)) * 100)
    }

    var body: some View {
        ZStack {
            SpekaBackground()

            VStack(spacing: 26) {
                Spacer()

                SpekaMascot(state: .trophy)
                    .frame(width: 168, height: 168)
                    .popIn()

                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(SpekaAccent.sunflower.base)
                        .symbolEffect(.pulse, options: .repeating)
                    Text("Session complete")
                        .font(SpekaFont.font(.displayTitle))
                        .foregroundStyle(SpekaColor.textPrimary)
                }

                statsCard
                    .padding(.horizontal, 32)
                    // Badge-style pop-in via spring scale on appear.
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
                    .opacity(appeared || reduceMotion ? 1 : 0)

                Spacer()

                SpekaButton("Done", systemImage: "checkmark", variant: .filled(.mint), fullWidth: true) {
                    onDone()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }

            SpekaConfetti(isActive: fireConfetti)
                .allowsHitTesting(false)
        }
        .onAppear(perform: runAppear)
    }

    private func runAppear() {
        fireConfetti = true
        if reduceMotion {
            appeared = true
            animatedReviewed = reviewed
            animatedAccuracy = accuracy
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
            appeared = true
        }
        // Count-up the stats so `.numericText()` rolls from 0 to the totals.
        withAnimation(.easeOut(duration: 0.8).delay(0.35)) {
            animatedReviewed = reviewed
            animatedAccuracy = accuracy
        }
    }

    private var statsCard: some View {
        SpekaCard(cornerRadius: 22, padding: 24, accent: accent) {
            HStack(spacing: 0) {
                summaryStat(value: animatedReviewed, label: "reviewed", suffix: "")
                divider
                summaryStat(value: animatedAccuracy, label: "accuracy", suffix: "%")
            }
        }
    }

    private func summaryStat(value: Int, label: String, suffix: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Text("\(value)")
                    .contentTransition(.numericText())
                Text(suffix)
            }
            .font(SpekaFont.font(.numberXL))
            .foregroundStyle(accent.base)

            Text(label)
                .spekaFont(.subhead)
                .foregroundStyle(SpekaColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(SpekaColor.border)
            .frame(width: 1, height: 44)
    }
}
