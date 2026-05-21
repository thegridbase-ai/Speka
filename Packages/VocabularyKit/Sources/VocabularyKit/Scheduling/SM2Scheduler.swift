import Foundation

/// Pure implementation of the SuperMemo SM-2 spaced-repetition algorithm.
///
/// All state transitions are computed from an input snapshot and returned as a
/// new snapshot — no shared mutable state, no I/O, fully deterministic given a
/// `now` clock. Callers (e.g. `ReviewState` SwiftData models) map the result
/// back onto persistent storage.
public enum SM2Scheduler {

    // MARK: - Tunables

    /// Starting ease factor for a brand-new card.
    public static let defaultEaseFactor: Double = 2.5

    /// Hard floor for the ease factor; SM-2 never lets EF drop below this.
    public static let minimumEaseFactor: Double = 1.3

    /// Interval (in days) at/above which a card is considered mastered.
    public static let graduationIntervalDays: Int = 21

    // MARK: - Scheduling

    /// Apply a review grade to an SM-2 state and return the updated snapshot.
    ///
    /// - Parameters:
    ///   - state: current SM-2 state.
    ///   - grade: learner's self-assessment for this review.
    ///   - now: the review timestamp (injectable for deterministic tests).
    /// - Returns: a new state with updated EF, interval, repetitions, due date,
    ///   `lastReviewed`, and `wordState`.
    public static func schedule(
        state: SM2State,
        grade: ReviewGrade,
        now: Date = Date()
    ) -> SM2State {
        var result = state
        let q = grade.quality

        // 1. Update the ease factor (applies on every review, even lapses).
        //    EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        result.easeFactor = updatedEaseFactor(state.easeFactor, quality: q)

        // 2. Branch on recall success. q < 3 is a lapse.
        if q < 3 {
            // Lapse: reset the learning progress.
            result.repetitions = 0
            result.interval = 1
            result.wordState = .learning
        } else {
            // Successful recall: advance the repetition count and interval.
            result.repetitions = state.repetitions + 1

            switch result.repetitions {
            case 1:
                result.interval = 1
            case 2:
                result.interval = 6
            default:
                // interval = round(previousInterval * EF) using the new EF.
                result.interval = Int(
                    (Double(state.interval) * result.easeFactor).rounded()
                )
            }

            // 3. Determine the lifecycle state from the new interval.
            result.wordState =
                result.interval >= graduationIntervalDays ? .known : .review
        }

        // 4. Schedule the next due date and stamp the review time.
        result.dueDate = addingDays(result.interval, to: now)
        result.lastReviewed = now

        return result
    }

    // MARK: - Helpers

    /// SM-2 ease-factor update, clamped at the `minimumEaseFactor` floor.
    static func updatedEaseFactor(_ ef: Double, quality q: Int) -> Double {
        let delta = 0.1 - (5.0 - Double(q)) * (0.08 + (5.0 - Double(q)) * 0.02)
        return max(minimumEaseFactor, ef + delta)
    }

    /// Add a whole number of days to a date using the current calendar.
    /// Falls back to a fixed-seconds offset if calendar math is unavailable.
    static func addingDays(_ days: Int, to date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        if let next = calendar.date(byAdding: .day, value: days, to: date) {
            return next
        }
        return date.addingTimeInterval(TimeInterval(days) * 86_400)
    }
}
