import Foundation
import SwiftData

/// A translation of an English `Word` into the learner's native language.
///
/// In SPEKA the target being learned is always English; this row carries the
/// meaning in one of the supported native languages (tr/de/fr/es/it).
@Model
public final class Translation {
    @Attribute(.unique) public var id: String

    /// The learner's native language code this translation is written in
    /// (a `SourceLanguage` raw value: "tr"/"de"/"fr"/"es"/"it").
    public var nativeLanguageCode: String

    /// The translated text in the native language.
    public var text: String

    /// Optional example sentence translated into the native language.
    public var exampleTranslated: String?

    /// Optional usage note or gloss.
    public var note: String?

    /// Inverse relationship to the owning word.
    @Relationship(inverse: \Word.translations)
    public var word: Word?

    public init(
        id: String = UUID().uuidString,
        nativeLanguageCode: String,
        text: String,
        exampleTranslated: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.nativeLanguageCode = nativeLanguageCode
        self.text = text
        self.exampleTranslated = exampleTranslated
        self.note = note
    }
}
