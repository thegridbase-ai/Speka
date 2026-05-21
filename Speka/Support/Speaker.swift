import Foundation
import AVFoundation

/// Speaks English headwords aloud with `AVSpeechSynthesizer` (en-US).
///
/// A single shared synthesizer is reused so taps interrupt the previous
/// utterance rather than queueing. `@MainActor` because it's driven from the
/// flashcard view's tap handlers.
@MainActor
final class Speaker {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()
    private let defaults: UserDefaults
    private let rateKey = "speka.settings.speechRate"

    /// Multiplier applied to `AVSpeechUtteranceDefaultSpeechRate`, clamped to a
    /// sensible spoken-word range. Persisted so the Settings slider survives
    /// relaunches.
    private(set) var rateMultiplier: Double

    /// Allowed multiplier bounds for the Settings slider.
    static let minRate: Double = 0.5
    static let maxRate: Double = 1.3
    static let defaultRate: Double = 0.92

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: rateKey)
        // `double(forKey:)` returns 0 when unset — fall back to the default.
        self.rateMultiplier = stored == 0
            ? Speaker.defaultRate
            : min(max(stored, Speaker.minRate), Speaker.maxRate)

        #if canImport(UIKit)
        // Allow playback even when the ringer is silenced; mix politely.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.mixWithOthers, .duckOthers]
        )
        #endif
    }

    /// Update the speech-rate multiplier and persist it.
    func setRate(_ multiplier: Double) {
        let clamped = min(max(multiplier, Speaker.minRate), Speaker.maxRate)
        rateMultiplier = clamped
        defaults.set(clamped, forKey: rateKey)
    }

    /// Speak an English string in American English, interrupting any current
    /// utterance.
    func speak(_ text: String, languageCode: String = "en-US") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(rateMultiplier)
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }
}
