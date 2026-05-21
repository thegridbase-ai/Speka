import Foundation
import SwiftData

/// One row of the seed JSON. The fixed keys describe the English headword;
/// any of the supported native-language keys (tr/de/fr/es/it) that are present
/// become `Translation` rows. Extra/unknown keys are ignored.
///
/// Example:
/// ```json
/// { "id": "en:water", "headword": "water", "pos": "noun",
///   "phonetic": "/ˈwɔtər/", "exampleEN": "I drink a lot of water.",
///   "level": "a1", "tr": "su" }
/// ```
public struct SeedEntry: Codable, Sendable, Equatable {
    public let id: String
    public let headword: String
    public let pos: String?
    public let phonetic: String?
    public let exampleEN: String?
    public let level: String

    /// Translations keyed by native-language code (e.g. ["tr": "su"]).
    /// Only `SourceLanguage` keys present in the JSON are captured.
    public let translations: [String: String]

    public init(
        id: String,
        headword: String,
        pos: String? = nil,
        phonetic: String? = nil,
        exampleEN: String? = nil,
        level: String,
        translations: [String: String] = [:]
    ) {
        self.id = id
        self.headword = headword
        self.pos = pos
        self.phonetic = phonetic
        self.exampleEN = exampleEN
        self.level = level
        self.translations = translations
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// Fixed (non-translation) keys, so we know which keys are native-language fields.
    private static let reservedKeys: Set<String> =
        ["id", "headword", "pos", "phonetic", "exampleEN", "level"]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)

        func string(_ key: String) -> String? {
            try? container.decode(String.self, forKey: DynamicKey(stringValue: key))
        }

        guard let id = string("id") else {
            throw DecodingError.keyNotFound(
                DynamicKey(stringValue: "id"),
                .init(codingPath: decoder.codingPath, debugDescription: "missing id")
            )
        }
        guard let headword = string("headword") else {
            throw DecodingError.keyNotFound(
                DynamicKey(stringValue: "headword"),
                .init(codingPath: decoder.codingPath, debugDescription: "missing headword")
            )
        }
        self.id = id
        self.headword = headword
        self.pos = string("pos")
        self.phonetic = string("phonetic")
        self.exampleEN = string("exampleEN")
        self.level = string("level") ?? CEFRLevel.a1.rawValue

        // Capture any present native-language keys as translations.
        let supported = Set(SourceLanguage.allCases.map(\.rawValue))
        var translations: [String: String] = [:]
        for key in container.allKeys
        where !Self.reservedKeys.contains(key.stringValue)
            && supported.contains(key.stringValue) {
            if let value = string(key.stringValue) {
                translations[key.stringValue] = value
            }
        }
        self.translations = translations
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(id, forKey: DynamicKey(stringValue: "id"))
        try container.encode(headword, forKey: DynamicKey(stringValue: "headword"))
        try container.encodeIfPresent(pos, forKey: DynamicKey(stringValue: "pos"))
        try container.encodeIfPresent(phonetic, forKey: DynamicKey(stringValue: "phonetic"))
        try container.encodeIfPresent(exampleEN, forKey: DynamicKey(stringValue: "exampleEN"))
        try container.encode(level, forKey: DynamicKey(stringValue: "level"))
        for (code, text) in translations {
            try container.encode(text, forKey: DynamicKey(stringValue: code))
        }
    }
}

/// Imports seed-JSON vocabulary into a SwiftData store.
///
/// The importer is deliberately free of app-bundle assumptions: it takes raw
/// `Data` (or pre-decoded `[SeedEntry]`), never `Bundle.main`. Imports are
/// idempotent — a `Word` with a matching `id` is updated in place rather than
/// duplicated, and its translation set is reconciled to the entry.
public enum SeedImporter {

    /// Outcome of an import pass.
    public struct Result: Equatable, Sendable {
        public var inserted: Int
        public var updated: Int
        public var translationsWritten: Int

        public var total: Int { inserted + updated }
    }

    enum ImportError: Error {
        case notAnArray
    }

    /// Decode seed entries from raw JSON `Data`.
    public static func decodeEntries(from data: Data) throws -> [SeedEntry] {
        try JSONDecoder().decode([SeedEntry].self, from: data)
    }

    /// Decode and import seed entries from raw JSON `Data`.
    @discardableResult
    public static func `import`(
        from data: Data,
        into context: ModelContext
    ) throws -> Result {
        let entries = try decodeEntries(from: data)
        return try `import`(entries: entries, into: context)
    }

    /// Decode and import seed entries from a file `URL`.
    @discardableResult
    public static func `import`(
        contentsOf url: URL,
        into context: ModelContext
    ) throws -> Result {
        let data = try Data(contentsOf: url)
        return try `import`(from: data, into: context)
    }

    /// Upsert pre-decoded entries into the store. Idempotent, keyed off `Word.id`.
    @discardableResult
    public static func `import`(
        entries: [SeedEntry],
        into context: ModelContext
    ) throws -> Result {
        var result = Result(inserted: 0, updated: 0, translationsWritten: 0)

        // Fetch all existing words once and index by id. Avoids a per-entry
        // `#Predicate` fetch (which is both slow and fragile against an
        // in-memory store) and keeps the upsert a pure in-memory dictionary
        // lookup.
        let existingWords = try context.fetch(FetchDescriptor<Word>())
        var index: [String: Word] = Dictionary(
            existingWords.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for entry in entries {
            let level = CEFRLevel(rawValue: entry.level) ?? .a1
            let existing = index[entry.id]

            let word: Word
            if let existing {
                // Update scalar fields in place.
                existing.headword = entry.headword
                existing.partOfSpeech = entry.pos
                existing.phonetic = entry.phonetic
                existing.exampleEN = entry.exampleEN
                existing.cefr = level
                word = existing
                result.updated += 1
            } else {
                word = Word(
                    id: entry.id,
                    headword: entry.headword,
                    partOfSpeech: entry.pos,
                    phonetic: entry.phonetic,
                    exampleEN: entry.exampleEN,
                    cefr: level
                )
                context.insert(word)
                index[entry.id] = word  // guard against duplicate ids in one batch
                result.inserted += 1
            }

            // Reconcile translations: upsert per native-language code, drop any
            // codes no longer present in the entry.
            reconcileTranslations(entry: entry, on: word, context: context, result: &result)
        }

        try context.save()
        return result
    }

    // MARK: - Helpers

    private static func reconcileTranslations(
        entry: SeedEntry,
        on word: Word,
        context: ModelContext,
        result: inout Result
    ) {
        let desired = entry.translations  // [code: text]

        // Update or remove existing translation rows.
        var keptCodes = Set<String>()
        for translation in word.translations {
            let code = translation.nativeLanguageCode
            if let text = desired[code] {
                translation.text = text
                keptCodes.insert(code)
                result.translationsWritten += 1
            } else {
                // No longer present in the seed: detach and delete.
                context.delete(translation)
            }
        }

        // Add translations for codes not already represented.
        for (code, text) in desired where !keptCodes.contains(code) {
            let translation = Translation(
                id: "\(entry.id)#\(code)",
                nativeLanguageCode: code,
                text: text
            )
            word.translations.append(translation)
            result.translationsWritten += 1
        }
    }
}
