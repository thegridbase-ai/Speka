import Foundation
import Testing
@testable import VocabularyKit

@Suite("DailyQueueBuilder")
struct DailyQueueBuilderTests {

    let now = Date(timeIntervalSince1970: 1_700_000_000)

    func item(_ id: String, _ state: WordState, dueOffsetDays: Double = 0) -> QueueItem {
        QueueItem(
            id: id,
            dueDate: now.addingTimeInterval(dueOffsetDays * 86_400),
            wordState: state
        )
    }

    // MARK: - Sorting

    @Test("Due cards are sorted by dueDate ascending")
    func dueSortedByDate() {
        let cands = [
            item("late", .review, dueOffsetDays: -1),   // due 1 day ago
            item("oldest", .review, dueOffsetDays: -5),  // due 5 days ago
            item("recent", .learning, dueOffsetDays: -2) // due 2 days ago
        ]
        // No new cards so order is purely the sorted due stream.
        let queue = DailyQueueBuilder.build(
            candidates: cands,
            config: QueueConfig(newPerDay: 0, reviewPerNew: 4),
            now: now
        )
        #expect(queue.map(\.id) == ["oldest", "recent", "late"])
    }

    // MARK: - New cap

    @Test("New cards are capped at newPerDay")
    func newCappedAtLimit() {
        let cands = (0..<10).map { item("new\($0)", .new) }
        let queue = DailyQueueBuilder.build(
            candidates: cands,
            config: QueueConfig(newPerDay: 3, reviewPerNew: 4),
            now: now
        )
        #expect(queue.count == 3)
        #expect(queue.allSatisfy { $0.wordState == .new })
    }

    @Test("newPerDay = 0 yields no new cards")
    func zeroNew() {
        let cands = (0..<5).map { item("new\($0)", .new) }
        let queue = DailyQueueBuilder.build(
            candidates: cands,
            config: QueueConfig(newPerDay: 0),
            now: now
        )
        #expect(queue.isEmpty)
    }

    // MARK: - Interleave ratio

    @Test("Interleave respects the reviewPerNew ratio")
    func interleaveRatio() {
        // 8 due (review) cards + 2 new, ratio 4 → expect 4 due, 1 new, 4 due, 1 new.
        let due = (0..<8).map { item(String(format: "d%02d", $0), .review, dueOffsetDays: -Double(10 - $0)) }
        let new = [item("n0", .new), item("n1", .new)]
        let queue = DailyQueueBuilder.build(
            candidates: due + new,
            config: QueueConfig(newPerDay: 20, reviewPerNew: 4),
            now: now
        )

        let states = queue.map(\.wordState)
        // Pattern: review x4, new, review x4, new
        #expect(states == [
            .review, .review, .review, .review, .new,
            .review, .review, .review, .review, .new
        ])
        #expect(queue.count == 10)
        // New cards landed at indices 4 and 9.
        #expect(queue[4].id == "n0")
        #expect(queue[9].id == "n1")
    }

    @Test("Leftover due cards are appended after new cards run out")
    func leftoverDueAppended() {
        // 10 due, 1 new, ratio 4 → 4 due, 1 new, then remaining 6 due appended.
        let due = (0..<10).map { item(String(format: "d%02d", $0), .review, dueOffsetDays: -Double(20 - $0)) }
        let new = [item("n0", .new)]
        let queue = DailyQueueBuilder.build(
            candidates: due + new,
            config: QueueConfig(newPerDay: 20, reviewPerNew: 4),
            now: now
        )
        #expect(queue.count == 11)
        #expect(queue[4].id == "n0")
        // After the single new card, all remaining items are due/review.
        #expect(queue[5...].allSatisfy { $0.wordState == .review })
    }

    @Test("Only new cards (no due) returns just the capped new stream")
    func onlyNew() {
        let cands = (0..<5).map { item("n\($0)", .new) }
        let queue = DailyQueueBuilder.build(
            candidates: cands,
            config: QueueConfig(newPerDay: 4, reviewPerNew: 4),
            now: now
        )
        #expect(queue.count == 4)
        #expect(queue.allSatisfy { $0.wordState == .new })
    }

    // MARK: - Known exclusion

    @Test(".known cards are excluded unless due now")
    func knownExcludedUnlessDue() {
        let cands = [
            item("known_future", .known, dueOffsetDays: 5),   // not due → excluded
            item("known_due", .known, dueOffsetDays: -1),     // due → included
            item("review_due", .review, dueOffsetDays: -2)    // due → included
        ]
        let queue = DailyQueueBuilder.build(
            candidates: cands,
            config: QueueConfig(newPerDay: 0, reviewPerNew: 4),
            now: now
        )
        let ids = Set(queue.map(\.id))
        #expect(ids.contains("known_due"))
        #expect(ids.contains("review_due"))
        #expect(!ids.contains("known_future"))
        #expect(queue.count == 2)
    }

    @Test("learning/review cards are excluded if not yet due")
    func nonDueExcluded() {
        let cands = [
            item("future_review", .review, dueOffsetDays: 3),
            item("future_learning", .learning, dueOffsetDays: 2),
            item("due_now", .review, dueOffsetDays: 0)
        ]
        let queue = DailyQueueBuilder.build(
            candidates: cands,
            config: QueueConfig(newPerDay: 0),
            now: now
        )
        #expect(queue.map(\.id) == ["due_now"])
    }

    @Test("New cards are always included regardless of dueDate")
    func newAlwaysIncluded() {
        // A .new card with a future dueDate still belongs in the new stream.
        let cands = [item("brand_new", .new, dueOffsetDays: 99)]
        let queue = DailyQueueBuilder.build(
            candidates: cands,
            config: QueueConfig(newPerDay: 10),
            now: now
        )
        #expect(queue.map(\.id) == ["brand_new"])
    }
}
