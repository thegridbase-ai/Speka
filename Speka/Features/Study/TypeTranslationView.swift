import SwiftUI
import VocabularyKit
import SpekaUI

/// Type-the-translation mode.
///
/// Shows the English headword (with an optional speak button) and asks the
/// learner to type the **Turkish** (native-language) translation. Matching is
/// diacritic- and case-insensitive with Turkish-aware folding (`AnswerMatch`).
///
/// Grading:
/// - Correct on the first attempt → `.good`
/// - Correct after a typo / a peeked hint → `.hard`
/// - Wrong (gives up / submits an incorrect answer) → `.again`
///
/// The view reports its grade through `onGrade`; the host owns advancing.
struct TypeTranslationView: View {
    let word: Word
    let language: SourceLanguage
    let onGrade: (ReviewGrade) -> Void

    @State private var input = ""
    @State private var attempts = 0
    @State private var usedHint = false
    @State private var revealed = false
    @State private var wasCorrect = false
    @FocusState private var fieldFocused: Bool

    private let accent: SpekaAccent = .lavender

    private var expected: String { word.translation(for: language)?.text ?? "—" }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            promptCard

            inputField
                .padding(.top, 22)

            // Reserved-height slot: the reveal content fills it instead of
            // growing the layout, so the centered block stays put (no "jump"),
            // while centering keeps whitespace balanced (not dumped at the
            // bottom behind the buttons).
            revealSlot
                .padding(.top, 14)

            Spacer(minLength: 16)

            actionBar
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .onAppear {
            fieldFocused = true
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-speka-type-autoanswer") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    input = expected
                    submit()
                }
            }
            #endif
        }
    }

    // MARK: - Prompt

    private var promptCard: some View {
        SpekaCard(cornerRadius: 26, padding: 26, accent: accent) {
            VStack(spacing: 16) {
                HStack {
                    Text("Translate")
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

                if let phonetic = word.phonetic {
                    Text(phonetic)
                        .spekaFont(.callout)
                        .foregroundStyle(SpekaColor.textSecondary)
                }

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
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accent.base)
                .frame(width: 44, height: 44)
                .background(Circle().fill(accent.soft))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input

    private var inputField: some View {
        TextField("Type the Turkish translation", text: $input)
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
            .shake(trigger: attempts)
    }

    /// Fixed-height slot the reveal result (or retry hint) fills — reserving it
    /// keeps the surrounding layout stable across the prompt → reveal change.
    private var revealSlot: some View {
        VStack(spacing: 12) {
            if revealed {
                resultRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if attempts > 0 {
                Text("Not quite — try again, or peek the answer.")
                    .spekaFont(.subhead)
                    .foregroundStyle(SpekaAccent.sunflower.edge)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .top)
        .animation(.easeInOut(duration: 0.2), value: revealed)
        .animation(.easeInOut(duration: 0.2), value: attempts)
    }

    private var fieldBorderColor: Color {
        if revealed { return wasCorrect ? SpekaAccent.mint.base : SpekaAccent.coral.base }
        if attempts > 0 { return SpekaAccent.sunflower.base }
        return accent.base.opacity(0.4)
    }

    private var resultRow: some View {
        VStack(spacing: 10) {
            SpekaMascot(state: wasCorrect ? .cheer : .kind)
                .frame(width: 90, height: 90)
                .popIn()

            HStack(spacing: 8) {
                Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(wasCorrect ? SpekaAccent.mint.base : SpekaAccent.coral.base)
                Text(wasCorrect ? "Correct" : "Answer")
                    .spekaFont(.subhead)
                    .foregroundStyle(SpekaColor.textSecondary)
            }
            Text(expected)
                .font(SpekaFont.font(.title))
                .foregroundStyle(wasCorrect ? SpekaAccent.mint.edge : SpekaColor.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private var actionBar: some View {
        Group {
            if revealed {
                SpekaButton(
                    "Continue",
                    systemImage: "arrow.right",
                    variant: .filled(wasCorrect ? .mint : accent),
                    fullWidth: true,
                    action: advance
                )
            } else {
                HStack(spacing: 12) {
                    SpekaButton("Reveal", systemImage: "eye", variant: .ghost(accent)) {
                        usedHint = true
                        wasCorrect = false
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
            reveal()
        } else {
            attempts += 1
            UISelection.tap()
            // After two misses, reveal the answer and grade as wrong.
            if attempts >= 2 {
                wasCorrect = false
                reveal()
            }
        }
    }

    private func reveal() {
        fieldFocused = false
        withAnimation { revealed = true }
    }

    private func advance() {
        let grade: ReviewGrade
        if wasCorrect {
            grade = (attempts == 0 && !usedHint) ? .good : .hard
        } else {
            grade = .again
        }
        onGrade(grade)
    }
}
