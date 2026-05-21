import Foundation
import SwiftData
import VocabularyKit

/// Computes streak + daily-goal stats from `StudySession` records and records
/// new completed sessions.
///
/// Streak = number of consecutive calendar days (ending today, or yesterday if
/// nothing studied yet today) on which at least one session was completed.
/// "Today's progress" = total cards reviewed across completed sessions whose
/// `endedAt` falls on the current calendar day, measured against the user's
/// daily goal. The daily goal lives in `UserDefaults` (no auth in Pass 1).
enum StatsStore {

    private static let dailyGoalKey = "speka.settings.dailyGoal"

    /// Default cards-per-day target.
    static let defaultDailyGoal = 20

    /// Allowed daily-goal bounds for the Settings stepper.
    static let minDailyGoal = 5
    static let maxDailyGoal = 100

    // MARK: - Daily goal

    static func dailyGoal(defaults: UserDefaults = .standard) -> Int {
        let stored = defaults.integer(forKey: dailyGoalKey)
        guard stored > 0 else { return defaultDailyGoal }
        return min(max(stored, minDailyGoal), maxDailyGoal)
    }

    static func setDailyGoal(_ value: Int, defaults: UserDefaults = .standard) {
        let clamped = min(max(value, minDailyGoal), maxDailyGoal)
        defaults.set(clamped, forKey: dailyGoalKey)
    }

    // MARK: - Stats model

    struct Summary {
        /// Consecutive-day study streak (🔥 N days).
        var streak: Int
        /// Cards reviewed across completed sessions today.
        var cardsToday: Int
        /// Daily goal target.
        var goal: Int

        var goalProgress: Double {
            guard goal > 0 else { return 0 }
            return min(max(Double(cardsToday) / Double(goal), 0), 1)
        }

        var goalReached: Bool { cardsToday >= goal }
    }

    // MARK: - Queries

    /// All completed sessions (those with an `endedAt`), most-recent first.
    private static func completedSessions(in context: ModelContext) -> [StudySession] {
        let descriptor = FetchDescriptor<StudySession>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Compute the streak + today's progress.
    static func summary(
        now: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard,
        in context: ModelContext
    ) -> Summary {
        let sessions = completedSessions(in: context)
        let goal = dailyGoal(defaults: defaults)

        let today = calendar.startOfDay(for: now)

        // Cards completed today.
        let cardsToday = sessions.reduce(into: 0) { acc, session in
            guard let ended = session.endedAt else { return }
            if calendar.isDate(ended, inSameDayAs: now) {
                acc += session.cardsReviewed
            }
        }

        // Distinct calendar days with at least one completed session.
        var studyDays = Set<Date>()
        for session in sessions {
            guard let ended = session.endedAt else { continue }
            studyDays.insert(calendar.startOfDay(for: ended))
        }

        let streak = computeStreak(studyDays: studyDays, today: today, calendar: calendar)

        return Summary(streak: streak, cardsToday: cardsToday, goal: goal)
    }

    /// Count consecutive days ending at `today`. If today has no session yet,
    /// the streak still counts as long as yesterday did (today is "pending").
    static func computeStreak(
        studyDays: Set<Date>,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard !studyDays.isEmpty else { return 0 }

        // Anchor the walk on today if studied today, else yesterday. If neither
        // day has a session, the streak is broken (0).
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var cursor: Date
        if studyDays.contains(today) {
            cursor = today
        } else if studyDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var count = 0
        while studyDays.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    // MARK: - Recording

    /// Persist a completed study session. Called when a session ends so streak +
    /// daily progress reflect the work just done.
    @discardableResult
    static func recordSession(
        language: SourceLanguage,
        startedAt: Date,
        endedAt: Date = Date(),
        cardsReviewed: Int,
        correctCount: Int,
        newWordsIntroduced: Int = 0,
        in context: ModelContext
    ) -> StudySession {
        let session = StudySession(
            language: language,
            startedAt: startedAt,
            endedAt: endedAt,
            cardsReviewed: cardsReviewed,
            correctCount: correctCount,
            newWordsIntroduced: newWordsIntroduced,
            updatedAt: endedAt,
            dirty: true
        )
        context.insert(session)
        try? context.save()
        return session
    }
}
