import Foundation
import SwiftData

/// Persistent SM-2 scheduling state for a single `Word`.
///
/// Conforms to `SM2Schedulable` so `SM2Scheduler` can read/write it, but the
/// algorithm itself operates on value snapshots (`SM2State`) so the core stays
/// testable without a `ModelContainer`.
@Model
public final class ReviewState: SM2Schedulable {
    /// SuperMemo ease factor. Starts at 2.5, never drops below 1.3.
    public var easeFactor: Double

    /// Current inter-repetition interval in days.
    public var interval: Int

    /// Number of consecutive successful repetitions.
    public var repetitions: Int

    /// When this card next becomes due.
    public var dueDate: Date

    /// Timestamp of the most recent review, if any.
    public var lastReviewed: Date?

    /// Last local mutation timestamp (drives sync ordering).
    public var updatedAt: Date

    /// Whether local changes are pending upload to the backend.
    public var dirty: Bool

    /// Backing storage for `wordState` (SwiftData persists the raw value).
    public var wordStateRaw: String

    /// Lifecycle state, bridged to/from the raw stored string.
    public var wordState: WordState {
        get { WordState(rawValue: wordStateRaw) ?? .new }
        set { wordStateRaw = newValue.rawValue }
    }

    /// Inverse of `Word.reviewState`.
    @Relationship(inverse: \Word.reviewState)
    public var word: Word?

    public init(
        easeFactor: Double = SM2Scheduler.defaultEaseFactor,
        interval: Int = 0,
        repetitions: Int = 0,
        dueDate: Date = .distantPast,
        lastReviewed: Date? = nil,
        updatedAt: Date = Date(),
        dirty: Bool = false,
        wordState: WordState = .new
    ) {
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.dueDate = dueDate
        self.lastReviewed = lastReviewed
        self.updatedAt = updatedAt
        self.dirty = dirty
        self.wordStateRaw = wordState.rawValue
    }
}

public extension ReviewState {
    /// Extract a value snapshot for the scheduler.
    var snapshot: SM2State {
        SM2State(
            easeFactor: easeFactor,
            interval: interval,
            repetitions: repetitions,
            dueDate: dueDate,
            lastReviewed: lastReviewed,
            wordState: wordState
        )
    }

    /// Apply a scheduler result back onto the persistent model, marking it dirty.
    func apply(_ snapshot: SM2State, at now: Date = Date()) {
        easeFactor = snapshot.easeFactor
        interval = snapshot.interval
        repetitions = snapshot.repetitions
        dueDate = snapshot.dueDate
        lastReviewed = snapshot.lastReviewed
        wordState = snapshot.wordState
        updatedAt = now
        dirty = true
    }

    /// Convenience: grade this card and persist the result in one call.
    func review(grade: ReviewGrade, now: Date = Date()) {
        let next = SM2Scheduler.schedule(state: snapshot, grade: grade, now: now)
        apply(next, at: now)
    }
}
