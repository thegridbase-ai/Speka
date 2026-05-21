import Foundation
import SwiftData

/// An English vocabulary item the learner is studying, at a CEFR level, with its
/// translations into the learner's native language(s) and per-learner review state.
///
/// SPEKA teaches English: the `headword` is always English (the word being
/// learned). Translations carry the meaning in the learner's native language
/// (see `Translation.nativeLanguageCode`).
@Model
public final class Word: QueueCandidate {
    /// Stable unique identifier (e.g. "en:water"). Also used for queue tie-breaking.
    @Attribute(.unique) public var id: String

    /// The English headword being learned (American English).
    public var headword: String

    /// Optional part of speech (e.g. "noun", "verb").
    public var partOfSpeech: String?

    /// Optional IPA phonetic transcription of the English headword.
    public var phonetic: String?

    /// Optional example sentence in English using the headword.
    public var exampleEN: String?

    /// Raw stored CEFR level.
    public var cefrRaw: String

    /// Translations of this word into the learner's native language(s).
    @Relationship(deleteRule: .cascade)
    public var translations: [Translation]

    /// Per-learner SM-2 scheduling state. `nil` until first scheduled.
    @Relationship(deleteRule: .cascade)
    public var reviewState: ReviewState?

    public init(
        id: String = UUID().uuidString,
        headword: String,
        partOfSpeech: String? = nil,
        phonetic: String? = nil,
        exampleEN: String? = nil,
        cefr: CEFRLevel,
        translations: [Translation] = [],
        reviewState: ReviewState? = nil
    ) {
        self.id = id
        self.headword = headword
        self.partOfSpeech = partOfSpeech
        self.phonetic = phonetic
        self.exampleEN = exampleEN
        self.cefrRaw = cefr.rawValue
        self.translations = translations
        self.reviewState = reviewState
    }
}

public extension Word {
    /// CEFR level bridged from the raw stored value.
    var cefr: CEFRLevel {
        get { CEFRLevel(rawValue: cefrRaw) ?? .a1 }
        set { cefrRaw = newValue.rawValue }
    }

    /// The translation into the learner's native language, if one exists.
    func translation(for language: SourceLanguage) -> Translation? {
        translations.first { $0.nativeLanguageCode == language.rawValue }
    }

    // MARK: QueueCandidate conformance

    /// Due date derived from the review state; `.distantPast` (always due) when
    /// the word has never been scheduled.
    var dueDate: Date {
        reviewState?.dueDate ?? .distantPast
    }

    /// Lifecycle state derived from the review state; `.new` when unscheduled.
    var wordState: WordState {
        reviewState?.wordState ?? .new
    }
}
