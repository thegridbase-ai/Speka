import SwiftUI
import VocabularyKit
import SpekaUI

/// Multiple-choice mode.
///
/// Shows the English headword and four **Turkish** options (one correct
/// translation plus three distractors, sampled and ordered by the host). Tapping
/// the correct option grades `.good`; a wrong tap grades `.again`. After a tap
/// the correct/incorrect choices are highlighted, then the host advances.
struct MultipleChoiceView: View {
    let word: Word
    let language: SourceLanguage
    /// Pre-shuffled options (correct + distractors) supplied by the host.
    let options: [String]
    let onGrade: (ReviewGrade) -> Void

    @State private var selected: String?
    @State private var locked = false
    @State private var wrongShake = 0

    private let accent: SpekaAccent = .mint

    private var correct: String { word.translation(for: language)?.text ?? "—" }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            promptCard

            optionsList
                .padding(.top, 22)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 24)
        #if DEBUG
        .onAppear {
            // Deterministic QA: auto-pick an option so the locked/highlighted
            // state can be screenshotted (verifies options don't reflow).
            guard ProcessInfo.processInfo.arguments.contains("-speka-mc-autoanswer"),
                  !locked else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if let opt = options.dropFirst().first { choose(opt) }
            }
        }
        #endif
    }

    // MARK: - Prompt

    private var promptCard: some View {
        SpekaCard(cornerRadius: 26, padding: 26, accent: accent) {
            VStack(spacing: 14) {
                HStack {
                    Text("Choose the meaning")
                        .font(SpekaFont.font(.label))
                        .textCase(.uppercase)
                        .foregroundStyle(accent.base)
                    Spacer()
                    if let pos = word.partOfSpeech {
                        Text(pos.uppercased())
                            .font(SpekaFont.font(.label))
                            .foregroundStyle(SpekaColor.textTertiary)
                    }
                }

                Text(word.headword)
                    .font(SpekaFont.font(.displayHero))
                    .foregroundStyle(SpekaColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)

                speakButton
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var speakButton: some View {
        Button {
            Speaker.shared.speak(word.headword)
            UISelection.tap()
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent.base)
                .frame(width: 42, height: 42)
                .background(Circle().fill(accent.soft))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Options

    private var optionsList: some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.self) { option in
                optionButton(option)
            }
        }
        .shake(trigger: wrongShake)
    }

    private func optionButton(_ option: String) -> some View {
        Button {
            choose(option)
        } label: {
            HStack {
                Text(option)
                    .spekaFont(.headline)
                    .foregroundStyle(textColor(for: option))
                    .multilineTextAlignment(.leading)
                Spacer()
                if let icon = trailingIcon(for: option) {
                    Image(systemName: icon.name)
                        .foregroundStyle(icon.color)
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fillColor(for: option))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(borderColor(for: option), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    // MARK: - Per-option styling (post-tap feedback)

    private func isCorrect(_ option: String) -> Bool {
        AnswerMatch.normalize(option) == AnswerMatch.normalize(correct)
    }

    private func textColor(for option: String) -> Color {
        guard locked else { return SpekaColor.textPrimary }
        if isCorrect(option) { return SpekaAccent.mint.edge }
        if option == selected { return SpekaAccent.coral.edge }
        return SpekaColor.textTertiary
    }

    private func fillColor(for option: String) -> Color {
        guard locked else { return SpekaColor.surface }
        if isCorrect(option) { return SpekaAccent.mint.soft }
        if option == selected { return SpekaAccent.coral.soft }
        return SpekaColor.surface
    }

    private func borderColor(for option: String) -> Color {
        guard locked else { return SpekaColor.border }
        if isCorrect(option) { return SpekaAccent.mint.base }
        if option == selected { return SpekaAccent.coral.base }
        return SpekaColor.border
    }

    private func trailingIcon(for option: String) -> (name: String, color: Color)? {
        guard locked else { return nil }
        if isCorrect(option) { return ("checkmark.circle.fill", SpekaAccent.mint.base) }
        if option == selected { return ("xmark.circle.fill", SpekaAccent.coral.base) }
        return nil
    }

    // MARK: - Selection

    private func choose(_ option: String) {
        guard !locked else { return }
        selected = option
        locked = true
        let right = isCorrect(option)
        UISelection.tap()
        if !right { wrongShake += 1 }

        // Brief pause so the learner sees the highlight before advancing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            onGrade(right ? .good : .again)
        }
    }
}
