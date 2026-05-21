import Foundation
import VocabularyKit

/// Static facts about which content is shipped in Pass 1.
///
/// Pass 1 ships only Turkish (`.tr`) translations and the A1 + A2 levels. Other
/// languages / levels are surfaced in the UI as "coming soon" and disabled.
enum Catalog {

    /// Native languages that have translation data available right now.
    static let availableLanguages: Set<SourceLanguage> = [.tr]

    /// CEFR levels that have word data available right now.
    static let availableLevels: Set<CEFRLevel> = [.a1, .a2]

    static func isAvailable(_ language: SourceLanguage) -> Bool {
        availableLanguages.contains(language)
    }

    static func isAvailable(_ level: CEFRLevel) -> Bool {
        availableLevels.contains(level)
    }

    /// Native-language flag emoji for the picker chips.
    static func flag(for language: SourceLanguage) -> String {
        switch language {
        case .tr: return "🇹🇷"
        case .de: return "🇩🇪"
        case .fr: return "🇫🇷"
        case .es: return "🇪🇸"
        case .it: return "🇮🇹"
        }
    }
}
