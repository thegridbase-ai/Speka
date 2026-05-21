import Foundation
import SwiftData
import Testing
@testable import VocabularyKit

@Suite("Models & enums")
struct ModelTests {

    let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Enums

    @Test("CEFRLevel is Comparable A1 < A2 < ... < C2")
    func cefrComparable() {
        #expect(CEFRLevel.a1 < .a2)
        #expect(CEFRLevel.a2 < .b1)
        #expect(CEFRLevel.b2 < .c1)
        #expect(CEFRLevel.c1 < .c2)
        #expect(CEFRLevel.allCases.sorted() == [.a1, .a2, .b1, .b2, .c1, .c2])
    }

    @Test("ReviewGrade maps to SM-2 quality 1/3/4/5")
    func gradeQuality() {
        #expect(ReviewGrade.again.quality == 1)
        #expect(ReviewGrade.hard.quality == 3)
        #expect(ReviewGrade.good.quality == 4)
        #expect(ReviewGrade.easy.quality == 5)
    }

    @Test("SourceLanguage covers tr/de/fr/es/it")
    func sourceLanguages() {
        #expect(Set(SourceLanguage.allCases) == [.tr, .de, .fr, .es, .it])
    }

    // MARK: - SwiftData @Model round-trip (confirms models build & persist on macOS CLI)

    @Test("Word + ReviewState persist and review() updates state via SM-2")
    @MainActor
    func swiftDataRoundTrip() throws {
        let store = try TestStore()
        defer { store.cleanup() }
        let context = store.context

        let review = ReviewState()
        let word = Word(
            id: "en:water",
            headword: "water",
            partOfSpeech: "noun",
            phonetic: "/ˈwɔtər/",
            exampleEN: "I drink a lot of water.",
            cefr: .a1,
            translations: [Translation(nativeLanguageCode: "tr", text: "su")],
            reviewState: review
        )
        context.insert(word)
        try context.save()

        // Brand-new word reports as .new and always-due.
        #expect(word.wordState == .new)
        #expect(word.dueDate == .distantPast)

        // translation(for:) helper resolves by native language.
        #expect(word.translation(for: .tr)?.text == "su")
        #expect(word.translation(for: .de) == nil)

        // Drive one successful review through the convenience API.
        review.review(grade: .good, now: now)
        #expect(review.repetitions == 1)
        #expect(review.interval == 1)
        #expect(review.wordState == .review)
        #expect(review.dirty == true)
        #expect(word.wordState == .review)

        // Fetch back to confirm persistence.
        let fetched = try context.fetch(FetchDescriptor<Word>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.headword == "water")
        #expect(fetched.first?.phonetic == "/ˈwɔtər/")
        #expect(fetched.first?.cefr == .a1)
        #expect(fetched.first?.reviewState?.repetitions == 1)
    }

    @Test("StudySession accuracy computes correctly")
    func sessionAccuracy() {
        let s = StudySession(language: .de, cardsReviewed: 10, correctCount: 7)
        #expect(s.accuracy == 0.7)
        let empty = StudySession(language: .fr)
        #expect(empty.accuracy == nil)
    }
}
