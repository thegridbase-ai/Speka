import Foundation
import SwiftData

/// Aggregate per-learner progress for a given source language.
@Model
public final class UserProgress {
    @Attribute(.unique) public var id: String

    /// Raw stored source language this progress record tracks.
    public var languageRaw: String

    /// Total words the learner has been introduced to.
    public var wordsIntroduced: Int

    /// Words currently in the `.known` state.
    public var wordsKnown: Int

    /// Current consecutive-day study streak.
    public var streakDays: Int

    /// Longest streak ever achieved.
    public var longestStreakDays: Int

    /// Calendar day (start-of-day) of the most recent study session.
    public var lastStudyDay: Date?

    /// Last local mutation timestamp (drives sync ordering).
    public var updatedAt: Date

    /// Whether local changes are pending upload.
    public var dirty: Bool

    public init(
        id: String = UUID().uuidString,
        language: SourceLanguage,
        wordsIntroduced: Int = 0,
        wordsKnown: Int = 0,
        streakDays: Int = 0,
        longestStreakDays: Int = 0,
        lastStudyDay: Date? = nil,
        updatedAt: Date = Date(),
        dirty: Bool = false
    ) {
        self.id = id
        self.languageRaw = language.rawValue
        self.wordsIntroduced = wordsIntroduced
        self.wordsKnown = wordsKnown
        self.streakDays = streakDays
        self.longestStreakDays = longestStreakDays
        self.lastStudyDay = lastStudyDay
        self.updatedAt = updatedAt
        self.dirty = dirty
    }
}

public extension UserProgress {
    /// Source language bridged from the raw stored value.
    var language: SourceLanguage {
        get { SourceLanguage(rawValue: languageRaw) ?? .de }
        set { languageRaw = newValue.rawValue }
    }
}
