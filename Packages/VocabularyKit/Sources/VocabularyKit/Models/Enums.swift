import Foundation

/// CEFR proficiency level for a vocabulary item.
/// Ordered A1 (easiest) → C2 (hardest) so `Comparable` reflects difficulty.
public enum CEFRLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case a1, a2, b1, b2, c1, c2

    /// Monotonically increasing rank used for ordering / filtering.
    public var rank: Int {
        switch self {
        case .a1: return 0
        case .a2: return 1
        case .b1: return 2
        case .b2: return 3
        case .c1: return 4
        case .c2: return 5
        }
    }

    public var displayName: String { rawValue.uppercased() }

    public static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// The learner's native language, used to render translations of the English
/// vocabulary being studied. (SPEKA always teaches English; this is the side
/// shown in the learner's own tongue.)
public enum SourceLanguage: String, Codable, CaseIterable, Sendable {
    case tr, de, fr, es, it

    public var displayName: String {
        switch self {
        case .tr: return "Turkish"
        case .de: return "German"
        case .fr: return "French"
        case .es: return "Spanish"
        case .it: return "Italian"
        }
    }
}

/// Lifecycle state of a word for the learner.
public enum WordState: String, Codable, CaseIterable, Sendable {
    /// Never studied.
    case new
    /// Actively being learned (early reps or after a lapse).
    case learning
    /// Graduated into spaced-repetition review cycles.
    case review
    /// Considered mastered (interval crossed the graduation threshold).
    case known
}
