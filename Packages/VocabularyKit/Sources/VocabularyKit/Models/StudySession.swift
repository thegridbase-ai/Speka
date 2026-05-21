import Foundation
import SwiftData

/// A record of one study session (used for stats and streak computation).
@Model
public final class StudySession {
    @Attribute(.unique) public var id: String

    /// Raw stored source language studied in this session.
    public var languageRaw: String

    /// When the session began.
    public var startedAt: Date

    /// When the session ended, if it has.
    public var endedAt: Date?

    /// Number of cards reviewed in the session.
    public var cardsReviewed: Int

    /// Number of those reviews that were correct (grade >= good).
    public var correctCount: Int

    /// New words introduced during the session.
    public var newWordsIntroduced: Int

    /// Last local mutation timestamp (drives sync ordering).
    public var updatedAt: Date

    /// Whether local changes are pending upload.
    public var dirty: Bool

    public init(
        id: String = UUID().uuidString,
        language: SourceLanguage,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        cardsReviewed: Int = 0,
        correctCount: Int = 0,
        newWordsIntroduced: Int = 0,
        updatedAt: Date = Date(),
        dirty: Bool = false
    ) {
        self.id = id
        self.languageRaw = language.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.cardsReviewed = cardsReviewed
        self.correctCount = correctCount
        self.newWordsIntroduced = newWordsIntroduced
        self.updatedAt = updatedAt
        self.dirty = dirty
    }
}

public extension StudySession {
    /// Source language bridged from the raw stored value.
    var language: SourceLanguage {
        get { SourceLanguage(rawValue: languageRaw) ?? .de }
        set { languageRaw = newValue.rawValue }
    }

    /// Accuracy in `[0, 1]`, or `nil` when no cards were reviewed.
    var accuracy: Double? {
        guard cardsReviewed > 0 else { return nil }
        return Double(correctCount) / Double(cardsReviewed)
    }
}
