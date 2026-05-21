import SwiftUI
import VocabularyKit
import SpekaUI

/// Listen-and-spell mode.
///
/// Auto-speaks the English headword on appear (the word itself is hidden) and
/// asks the learner to type the **English** spelling. A replay button re-speaks
/// the word. On submit the correct spelling is revealed.
///
/// Grading:
/// - Exact spelling → `.good`
/// - A single-character typo (`AnswerMatch.isMinorTypo`) → `.hard`
/// - Anything else / gives up → `.again`
struct ListenAndSpellView: View {
    let word: Word
    let onGrade: (ReviewGrade) -> Void

    @State private var input = ""
    @State private var revealed = false
    @State private var wasCorrect = false
    @State private var minorTypo = false
    @State private var wrongShake = 0
    @FocusState private var fieldFocused: Bool

    private let accent: SpekaAccent = .sky

    private var expected: String { word.headword }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            speakerCard

            inputField
                .padding(.top, 24)

            // Reserved-height slot so the reveal fills it instead of growing the
            // layout (no "jump"); centering keeps whitespace balanced.
            revealSlot
                .padding(.top, 14)

            Spacer(minLength: 16)

            actionBar
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .onAppear {
            // Auto-play the prompt and focus the field shortly after, so the
            // audio session is ready before the keyboard animation steals focus.
            Speaker.shared.speak(word.headword)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                fieldFocused = true
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-speka-listen-autoanswer") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    input = expected
                    submit()
                }
            }
            #endif
        }
    }

    // MARK: - Speaker prompt

    private var speakerCard: some View {
        SpekaCard(cornerRadius: 26, padding: 30, accent: accent) {
            VStack(spacing: 18) {
                Text("Listen & spell")
                    .font(SpekaFont.font(.label))
                    .textCase(.uppercase)
                    .foregroundStyle(accent.base)

                Button {
                    Speaker.shared.speak(word.headword)
                    UISelection.tap()
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(SpekaColor.onColor)
                        .frame(width: 110, height: 110)
                        .background(Circle().fill(accent.base))
                        .shadow(color: accent.edge.opacity(0.5), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(revealed)

                Text(revealed ? "" : "Tap to replay")
                    .spekaFont(.subhead)
                    .foregroundStyle(SpekaColor.textTertiary)
                    .frame(height: 18)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Input

    private var inputField: some View {
        TextField("Spell what you hear", text: $input)
            .font(SpekaFont.font(.title))
            .foregroundStyle(SpekaColor.textPrimary)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($fieldFocused)
            .disabled(revealed)
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SpekaColor.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(fieldBorderColor, lineWidth: 2)
            }
            .onSubmit(submit)
            .shake(trigger: wrongShake)
    }

    /// Fixed-height slot the reveal result fills — reserving it keeps the layout
    /// stable across the prompt → reveal change (no upward "jump").
    private var revealSlot: some View {
        VStack(spacing: 12) {
            if revealed {
                resultRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .top)
        .animation(.easeInOut(duration: 0.2), value: revealed)
    }

    private var fieldBorderColor: Color {
        guard revealed else { return accent.base.opacity(0.4) }
        if wasCorrect { return SpekaAccent.mint.base }
        if minorTypo { return SpekaAccent.sunflower.base }
        return SpekaAccent.coral.base
    }

    private var resultRow: some View {
        VStack(spacing: 10) {
            SpekaMascot(state: wasCorrect ? .cheer : .kind)
                .frame(width: 90, height: 90)
                .popIn()

            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor.base)
                Text(statusLabel)
                    .spekaFont(.subhead)
                    .foregroundStyle(SpekaColor.textSecondary)
            }
            Text(expected)
                .font(SpekaFont.font(.displayTitle))
                .foregroundStyle(statusColor.edge)
            if let phonetic = word.phonetic {
                Text(phonetic)
                    .spekaFont(.callout)
                    .foregroundStyle(SpekaColor.textSecondary)
            }
        }
    }

    private var statusIcon: String {
        if wasCorrect { return "checkmark.circle.fill" }
        if minorTypo { return "exclamationmark.circle.fill" }
        return "xmark.circle.fill"
    }

    private var statusColor: SpekaAccent {
        if wasCorrect { return .mint }
        if minorTypo { return .sunflower }
        return .coral
    }

    private var statusLabel: String {
        if wasCorrect { return "Correct" }
        if minorTypo { return "Almost — close spelling" }
        return "Answer"
    }

    // MARK: - Actions

    private var actionBar: some View {
        Group {
            if revealed {
                SpekaButton(
                    "Continue",
                    systemImage: "arrow.right",
                    variant: .filled(statusColor),
                    fullWidth: true,
                    action: advance
                )
            } else {
                HStack(spacing: 12) {
                    SpekaButton("Reveal", systemImage: "eye", variant: .ghost(accent)) {
                        wasCorrect = false
                        minorTypo = false
                        reveal()
                    }
                    SpekaButton("Check", systemImage: "checkmark", variant: .filled(accent), fullWidth: true, action: submit)
                }
            }
        }
    }

    private func submit() {
        guard !revealed else { return }
        if AnswerMatch.isCorrect(input, expected: expected) {
            wasCorrect = true
        } else if AnswerMatch.isMinorTypo(input, expected: expected) {
            minorTypo = true
        } else {
            wrongShake += 1
        }
        reveal()
    }

    private func reveal() {
        fieldFocused = false
        withAnimation { revealed = true }
    }

    private func advance() {
        let grade: ReviewGrade
        if wasCorrect { grade = .good }
        else if minorTypo { grade = .hard }
        else { grade = .again }
        onGrade(grade)
    }
}
