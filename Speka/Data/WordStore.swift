import Foundation
import SwiftData
import VocabularyKit

/// Read/query helpers over the SwiftData store for a given level + language.
///
/// Centralises the fetch + `DailyQueueBuilder` logic so `HomeView` and
/// `StudySessionView` agree on counts and ordering. All methods are synchronous
/// and run on the context's actor (the views call them from the main context).
enum WordStore {

    /// Stats shown on the Home screen for one level.
    struct LevelStats {
        var total: Int
        var known: Int
        var dueToday: Int
        var newToday: Int

        /// Mastery fraction (known / total), clamped to `0...1`.
        var progress: Double {
            guard total > 0 else { return 0 }
            return min(max(Double(known) / Double(total), 0), 1)
        }
    }

    /// All words at a CEFR level, sorted by id for stable ordering.
    static func words(
        at level: CEFRLevel,
        in context: ModelContext
    ) -> [Word] {
        let levelRaw = level.rawValue
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.cefrRaw == levelRaw },
            sortBy: [SortDescriptor(\.id)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Compute per-level stats for the Home screen using the daily queue.
    static func stats(
        at level: CEFRLevel,
        config: QueueConfig = .default,
        now: Date = Date(),
        in context: ModelContext
    ) -> LevelStats {
        let all = words(at: level, in: context)
        let known = all.filter { $0.wordState == .known }.count

        // The daily queue is what the learner will actually study today.
        let queue = DailyQueueBuilder.build(candidates: all, config: config, now: now)
        let newToday = queue.filter { $0.wordState == .new }.count
        let dueToday = queue.count - newToday

        return LevelStats(
            total: all.count,
            known: known,
            dueToday: dueToday,
            newToday: newToday
        )
    }

    /// Build today's ordered study queue for a level.
    static func dailyQueue(
        at level: CEFRLevel,
        config: QueueConfig = .default,
        now: Date = Date(),
        in context: ModelContext
    ) -> [Word] {
        let all = words(at: level, in: context)
        return DailyQueueBuilder.build(candidates: all, config: config, now: now)
    }
}
