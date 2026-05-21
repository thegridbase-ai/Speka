import Foundation
import Combine
import VocabularyKit

/// The learner's onboarding choices: native language + target CEFR level.
///
/// Pass 1 keeps this in `UserDefaults` (no auth, no sync). Pass 2 will mirror it
/// into a synced profile once Firebase is wired. Exposed as an `ObservableObject`
/// so `AppRouter` re-renders the moment onboarding completes.
@MainActor
final class ProfileStore: ObservableObject {

    private let defaults: UserDefaults
    private let languageKey = "speka.profile.nativeLanguage"
    private let levelKey = "speka.profile.level"

    /// The learner's native language (the side translations are shown in).
    @Published private(set) var nativeLanguage: SourceLanguage?

    /// The CEFR level the learner is studying.
    @Published private(set) var level: CEFRLevel?

    /// Onboarding is complete once both choices exist.
    var isOnboarded: Bool { nativeLanguage != nil && level != nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: languageKey) {
            self.nativeLanguage = SourceLanguage(rawValue: raw)
        }
        if let raw = defaults.string(forKey: levelKey) {
            self.level = CEFRLevel(rawValue: raw)
        }
    }

    /// Persist the completed onboarding selection.
    func complete(language: SourceLanguage, level: CEFRLevel) {
        defaults.set(language.rawValue, forKey: languageKey)
        defaults.set(level.rawValue, forKey: levelKey)
        self.nativeLanguage = language
        self.level = level
    }

    /// Switch the active CEFR level (e.g. from Settings) without re-onboarding.
    func setLevel(_ level: CEFRLevel) {
        defaults.set(level.rawValue, forKey: levelKey)
        self.level = level
    }

    /// Switch the native language (e.g. from Settings) without re-onboarding.
    func setLanguage(_ language: SourceLanguage) {
        defaults.set(language.rawValue, forKey: languageKey)
        self.nativeLanguage = language
    }

    /// Clears the profile (used for testing / a future "reset" affordance).
    func reset() {
        defaults.removeObject(forKey: languageKey)
        defaults.removeObject(forKey: levelKey)
        nativeLanguage = nil
        level = nil
    }
}
