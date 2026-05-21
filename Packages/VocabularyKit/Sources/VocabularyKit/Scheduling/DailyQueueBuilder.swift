import Foundation

/// Configuration for how a daily study queue is assembled.
public struct QueueConfig: Equatable, Codable, Sendable {
    /// Maximum number of brand-new cards introduced per day.
    public var newPerDay: Int

    /// Interleave ratio: for every `reviewPerNew` due/review cards, one new card
    /// is woven in. e.g. `4` → roughly 4 reviews then 1 new, repeating.
    public var reviewPerNew: Int

    public init(newPerDay: Int = 20, reviewPerNew: Int = 4) {
        self.newPerDay = max(0, newPerDay)
        self.reviewPerNew = max(1, reviewPerNew)
    }

    public static let `default` = QueueConfig()
}

/// A card candidate for the daily queue. Decoupled from SwiftData so the builder
/// is pure and unit-testable; `Word` exposes a conforming view of its state.
public protocol QueueCandidate {
    /// Stable identifier (used for deterministic tie-breaking).
    var id: String { get }
    /// When the card next becomes due.
    var dueDate: Date { get }
    /// Lifecycle state used to classify the card.
    var wordState: WordState { get }
}

/// Lightweight value type for queue building and testing.
public struct QueueItem: QueueCandidate, Equatable, Sendable {
    public let id: String
    public let dueDate: Date
    public let wordState: WordState

    public init(id: String, dueDate: Date, wordState: WordState) {
        self.id = id
        self.dueDate = dueDate
        self.wordState = wordState
    }
}

/// Builds the ordered list of cards to study today.
///
/// Rules (per blueprint §4):
/// - **Due cards** (`learning`/`review`, and `known` only if due now) come first
///   in priority and are sorted by `dueDate` ascending.
/// - **New cards** (`.new`) are capped at `config.newPerDay`.
/// - The two streams are **interleaved** by `config.reviewPerNew` so new words
///   are spread through the session rather than front- or back-loaded.
/// - `.known` cards are **excluded** unless they are due now.
public enum DailyQueueBuilder {

    public static func build<C: QueueCandidate>(
        candidates: [C],
        config: QueueConfig = .default,
        now: Date = Date()
    ) -> [C] {
        // Partition candidates.
        var due: [C] = []
        var fresh: [C] = []

        for card in candidates {
            switch card.wordState {
            case .new:
                fresh.append(card)
            case .known:
                // Known cards are excluded unless they have come due.
                if card.dueDate <= now { due.append(card) }
            case .learning, .review:
                // Only include if actually due now.
                if card.dueDate <= now { due.append(card) }
            }
        }

        // Due cards sorted by dueDate ascending; stable tie-break on id.
        due.sort { lhs, rhs in
            if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
            return lhs.id < rhs.id
        }

        // New cards capped at the daily limit; stable order on id.
        fresh.sort { $0.id < $1.id }
        let cappedNew = Array(fresh.prefix(config.newPerDay))

        return interleave(due: due, new: cappedNew, ratio: config.reviewPerNew)
    }

    /// Weave `new` cards into the `due` stream: emit up to `ratio` due cards,
    /// then one new card, repeating. Leftover cards from either stream are
    /// appended once the other is exhausted.
    static func interleave<C: QueueCandidate>(
        due: [C],
        new: [C],
        ratio: Int
    ) -> [C] {
        guard !new.isEmpty else { return due }
        guard !due.isEmpty else { return new }

        let step = max(1, ratio)
        var result: [C] = []
        result.reserveCapacity(due.count + new.count)

        var dueIndex = 0
        var newIndex = 0

        while dueIndex < due.count || newIndex < new.count {
            // Emit up to `step` due cards.
            var emitted = 0
            while emitted < step && dueIndex < due.count {
                result.append(due[dueIndex])
                dueIndex += 1
                emitted += 1
            }
            // Then one new card if available.
            if newIndex < new.count {
                result.append(new[newIndex])
                newIndex += 1
            } else if dueIndex >= due.count {
                // Both exhausted.
                break
            }
        }

        return result
    }
}
