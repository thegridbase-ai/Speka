import Foundation
import SwiftData
import Testing
@testable import VocabularyKit

@Suite("SeedImporter")
struct SeedImporterTests {

    /// Build a fresh, isolated on-disk store holding the full vocab schema.
    @MainActor
    func makeStore() throws -> TestStore {
        try TestStore()
    }

    /// Locate and load the real seed file shipped as a test resource.
    func seedData() throws -> Data {
        guard let url = Bundle.module.url(
            forResource: "words_a1", withExtension: "json"
        ) else {
            Issue.record("words_a1.json missing from test bundle")
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }

    // MARK: - Decoding

    @Test("Decodes all 279 A1 entries from the real seed file")
    func decodesAllEntries() throws {
        let entries = try SeedImporter.decodeEntries(from: try seedData())
        #expect(entries.count == 279)

        let water = try #require(entries.first { $0.id == "en:water" })
        #expect(water.headword == "water")
        #expect(water.pos == "noun")
        #expect(water.phonetic == "/ˈwɔtər/")
        #expect(water.exampleEN == "I drink a lot of water.")
        #expect(water.level == "a1")
        #expect(water.translations["tr"] == "su")
    }

    @Test("Decoder captures only supported native-language keys")
    func decodesFlexibleNativeKeys() throws {
        // A future entry with extra native-language keys + an unknown key.
        let json = """
        [{
          "id": "en:dog", "headword": "dog", "pos": "noun",
          "phonetic": "/dɔɡ/", "exampleEN": "The dog runs fast.",
          "level": "a1", "tr": "köpek", "de": "Hund", "fr": "chien",
          "audio": "dog.mp3"
        }]
        """.data(using: .utf8)!
        let entries = try SeedImporter.decodeEntries(from: json)
        let dog = try #require(entries.first)
        #expect(dog.translations["tr"] == "köpek")
        #expect(dog.translations["de"] == "Hund")
        #expect(dog.translations["fr"] == "chien")
        // Unknown / non-language keys are not treated as translations.
        #expect(dog.translations["audio"] == nil)
        #expect(dog.translations.count == 3)
    }

    // MARK: - Import

    @Test("Imports 279 words into a store with correct data")
    @MainActor
    func importsRealSeed() throws {
        let store = try makeStore()
        defer { store.cleanup() }
        let context = store.context
        let result = try SeedImporter.import(from: try seedData(), into: context)

        #expect(result.inserted == 279)
        #expect(result.updated == 0)

        let words = try context.fetch(FetchDescriptor<Word>())
        #expect(words.count == 279)

        // Known entry round-trips through the store.
        let water = try #require(words.first { $0.id == "en:water" })
        #expect(water.headword == "water")
        #expect(water.cefr == .a1)
        #expect(water.phonetic == "/ˈwɔtər/")
        #expect(water.translation(for: .tr)?.text == "su")

        // Every word came in as .new (no review state yet).
        #expect(words.allSatisfy { $0.wordState == .new })
    }

    @Test("Re-importing the same seed does not duplicate rows (idempotent)")
    @MainActor
    func importIsIdempotent() throws {
        let store = try makeStore()
        defer { store.cleanup() }
        let context = store.context
        let data = try seedData()

        let first = try SeedImporter.import(from: data, into: context)
        #expect(first.inserted == 279)
        #expect(first.updated == 0)

        let second = try SeedImporter.import(from: data, into: context)
        #expect(second.inserted == 0)
        #expect(second.updated == 279)

        // Counts unchanged after the second pass.
        let words = try context.fetch(FetchDescriptor<Word>())
        #expect(words.count == 279)
        let translations = try context.fetch(FetchDescriptor<Translation>())
        #expect(translations.count == 279) // one tr translation per A1 word

        // The known entry still has exactly one Turkish translation.
        let water = try #require(words.first { $0.id == "en:water" })
        #expect(water.translations.count == 1)
        #expect(water.translation(for: .tr)?.text == "su")
    }

    @Test("Re-import preserves existing review state on a word")
    @MainActor
    func reimportPreservesReviewState() throws {
        let store = try makeStore()
        defer { store.cleanup() }
        let context = store.context
        let data = try seedData()
        _ = try SeedImporter.import(from: data, into: context)

        // Attach + advance a review state on one word.
        let allWords = try context.fetch(FetchDescriptor<Word>())
        let water = try #require(allWords.first { $0.id == "en:water" })
        let review = ReviewState()
        water.reviewState = review
        review.review(grade: .good)
        try context.save()
        #expect(water.wordState == .review)

        // Re-import: scalar fields refresh, but the review state survives.
        _ = try SeedImporter.import(from: data, into: context)
        let refetched = try #require(
            try context.fetch(FetchDescriptor<Word>()).first { $0.id == "en:water" }
        )
        #expect(refetched.reviewState?.repetitions == 1)
        #expect(refetched.wordState == .review)
    }
}
