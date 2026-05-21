import Foundation

/// The mutable spaced-repetition fields the SM-2 algorithm reads and writes.
/// `ReviewState` (a SwiftData `@Model`) conforms to this so the scheduler can
/// stay a pure function over lightweight value types and remain unit-testable
/// without a `ModelContainer`.
public protocol SM2Schedulable {
    var easeFactor: Double { get set }
    var interval: Int { get set }
    var repetitions: Int { get set }
    var dueDate: Date { get set }
    var lastReviewed: Date? { get set }
    var wordState: WordState { get set }
}

/// An immutable value snapshot of SM-2 state. Used by the pure scheduler and in
/// tests; can be lifted out of / written back into a `ReviewState` model.
public struct SM2State: SM2Schedulable, Equatable, Codable, Sendable {
    public var easeFactor: Double
    public var interval: Int
    public var repetitions: Int
    public var dueDate: Date
    public var lastReviewed: Date?
    public var wordState: WordState

    public init(
        easeFactor: Double = SM2Scheduler.defaultEaseFactor,
        interval: Int = 0,
        repetitions: Int = 0,
        dueDate: Date = .distantPast,
        lastReviewed: Date? = nil,
        wordState: WordState = .new
    ) {
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.dueDate = dueDate
        self.lastReviewed = lastReviewed
        self.wordState = wordState
    }
}
