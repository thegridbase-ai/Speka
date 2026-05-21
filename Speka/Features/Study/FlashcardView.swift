import SwiftUI
import VocabularyKit
import SpekaUI

/// A single flippable flashcard in the Sunny Studio look.
///
/// Front: English headword + phonetic + speak button + CEFR badge + "tap to
/// reveal" hint. Back: the native-language translation + the English example.
/// Tapping flips with a 3D `rotation3DEffect` (with perspective) + spring.
/// Backface culling is done manually (each face hidden once rotation passes
/// 90°). The soft card shadow lives on a **non-rotating** container so the GPU
/// never has to re-rasterize a shadow every frame of the flip.
struct FlashcardView: View {
    let word: Word
    let language: SourceLanguage
    @Binding var isFlipped: Bool
    /// Drives the per-mode accent for the front face.
    var accent: SpekaAccent = .coral

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var translation: Translation? { word.translation(for: language) }
    private let cardHeight: CGFloat = 380

    var body: some View {
        // Static shadow container — does NOT rotate, so the soft shadow is
        // rasterized once instead of per-frame during the flip.
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.clear)
                .shadow(color: SpekaColor.textPrimary.opacity(0.10), radius: 22, x: 0, y: 12)

            rotatingFaces
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                isFlipped.toggle()
            }
            UISelection.tap()
        }
        .sensoryFeedback(.selection, trigger: isFlipped)
    }

    private var rotatingFaces: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)

            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
    }

    // MARK: - Front

    private var front: some View {
        cardSurface(accent: accent, tinted: false) {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    cefrBadge
                    Spacer()
                    if let pos = word.partOfSpeech {
                        Text(pos.uppercased())
                            .font(SpekaFont.font(.label))
                            .foregroundStyle(SpekaColor.textTertiary)
                    }
                }

                Spacer()

                VStack(spacing: 14) {
                    Text(word.headword)
                        .font(SpekaFont.font(.displayHero))
                        .foregroundStyle(SpekaColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)

                    if let phonetic = word.phonetic {
                        Text(phonetic)
                            .spekaFont(.body)
                            .foregroundStyle(SpekaColor.textSecondary)
                    }

                    speakButton
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 12))
                    Text("Tap to reveal")
                        .spekaFont(.subhead)
                }
                .foregroundStyle(SpekaColor.textTertiary)
            }
        }
    }

    private var cefrBadge: some View {
        Text(word.cefr.displayName)
            .font(SpekaFont.font(.label))
            .foregroundStyle(accent.base)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(accent.soft))
    }

    private var speakButton: some View {
        Button {
            Speaker.shared.speak(word.headword)
            UISelection.tap()
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent.base)
                .frame(width: 48, height: 48)
                .background(Circle().fill(accent.soft))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Back

    private var back: some View {
        cardSurface(accent: accent, tinted: false) {
            VStack(spacing: 22) {
                Spacer()

                Text(translation?.text ?? "—")
                    .font(SpekaFont.font(.displayTitle))
                    .foregroundStyle(accent.edge)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(3)

                if let example = word.exampleEN {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent.base)
                            .frame(width: 4)
                        Text("\"\(example)\"")
                            .spekaFont(.body)
                            .italic()
                            .foregroundStyle(SpekaColor.textSecondary)
                            .multilineTextAlignment(.leading)
                            .padding(.leading, 14)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accent.soft)
                    )
                }

                Spacer()
            }
        }
    }

    // MARK: - Shared surface

    private func cardSurface<Content: View>(
        accent: SpekaAccent,
        tinted: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(tinted ? SpekaColor.surfaceTint : SpekaColor.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(accent.base, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
