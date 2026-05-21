import Foundation
import Testing
@testable import VocabularyKit

@Suite("SM2Scheduler")
struct SM2SchedulerTests {

    /// Fixed reference instant so day math is deterministic.
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// UTC calendar matching the scheduler's internal day arithmetic.
    var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    func daysBetween(_ start: Date, _ end: Date) -> Int {
        utcCalendar.dateComponents([.day], from: start, to: end).day ?? -1
    }

    // MARK: - Ease factor formula

    @Test("EF update formula matches SM-2 for each quality")
    func easeFactorFormula() {
        // q=5 (easy): delta = +0.1  → 2.5 → 2.6
        #expect(abs(SM2Scheduler.updatedEaseFactor(2.5, quality: 5) - 2.6) < 1e-9)
        // q=4 (good): delta = 0.0   → 2.5 → 2.5
        #expect(abs(SM2Scheduler.updatedEaseFactor(2.5, quality: 4) - 2.5) < 1e-9)
        // q=3 (hard): delta = -0.14 → 2.5 → 2.36
        #expect(abs(SM2Scheduler.updatedEaseFactor(2.5, quality: 3) - 2.36) < 1e-9)
        // q=1 (again): delta = -0.54 → 2.5 → 1.96
        #expect(abs(SM2Scheduler.updatedEaseFactor(2.5, quality: 1) - 1.96) < 1e-9)
    }

    @Test("EF is clamped at the 1.3 floor")
    func easeFactorFloor() {
        // Starting near the floor and grading 'again' (delta -0.54) must clamp.
        #expect(SM2Scheduler.updatedEaseFactor(1.4, quality: 1) == 1.3)
        // Repeated failures never push below the floor.
        var ef = SM2Scheduler.minimumEaseFactor
        for _ in 0..<10 {
            ef = SM2Scheduler.updatedEaseFactor(ef, quality: 1)
        }
        #expect(ef == 1.3)
    }

    @Test("Default starting state uses EF 2.5")
    func defaultEaseFactor() {
        #expect(SM2State().easeFactor == 2.5)
        #expect(SM2Scheduler.defaultEaseFactor == 2.5)
    }

    // MARK: - Interval progression

    @Test("Interval progression: rep1 -> 1, rep2 -> 6, rep3 -> round(interval*EF)")
    func intervalProgression() {
        var state = SM2State()

        // First successful review.
        state = SM2Scheduler.schedule(state: state, grade: .good, now: now)
        #expect(state.repetitions == 1)
        #expect(state.interval == 1)
        #expect(state.wordState == .review)

        // Second successful review.
        state = SM2Scheduler.schedule(state: state, grade: .good, now: now)
        #expect(state.repetitions == 2)
        #expect(state.interval == 6)
        #expect(state.wordState == .review)

        // Third successful review: interval = round(6 * EF).
        // After two 'good' (q=4, delta 0) reviews EF stays 2.5 → round(6*2.5)=15.
        let efBefore = state.easeFactor
        state = SM2Scheduler.schedule(state: state, grade: .good, now: now)
        #expect(state.repetitions == 3)
        #expect(state.interval == Int((6.0 * efBefore).rounded()))
        #expect(state.interval == 15)
    }

    @Test("Due date is the new interval in days after 'now'")
    func dueDateAdvances() {
        var state = SM2State()
        state = SM2Scheduler.schedule(state: state, grade: .good, now: now)
        #expect(daysBetween(now, state.dueDate) == 1)
        #expect(state.lastReviewed == now)

        state = SM2Scheduler.schedule(state: state, grade: .good, now: now)
        #expect(daysBetween(now, state.dueDate) == 6)
    }

    // MARK: - Lapse behavior

    @Test("Lapse on q<3 resets repetitions->0, interval->1, state->learning")
    func lapseResets() {
        // Build up a mature card first.
        var state = SM2State()
        state = SM2Scheduler.schedule(state: state, grade: .good, now: now) // rep1, i1
        state = SM2Scheduler.schedule(state: state, grade: .good, now: now) // rep2, i6
        state = SM2Scheduler.schedule(state: state, grade: .good, now: now) // rep3, i15
        #expect(state.repetitions == 3)
        let efBeforeLapse = state.easeFactor

        // Now lapse with 'again' (q=1, < 3).
        state = SM2Scheduler.schedule(state: state, grade: .again, now: now)
        #expect(state.repetitions == 0)
        #expect(state.interval == 1)
        #expect(state.wordState == .learning)
        // EF still gets updated (decreased) on a lapse.
        #expect(state.easeFactor < efBeforeLapse)
        #expect(daysBetween(now, state.dueDate) == 1)
    }

    @Test("'hard' grade (q=3) is NOT a lapse and still advances repetitions")
    func hardIsNotLapse() {
        var state = SM2State()
        state = SM2Scheduler.schedule(state: state, grade: .hard, now: now)
        #expect(state.repetitions == 1)
        #expect(state.interval == 1)
        #expect(state.wordState == .review)
        // EF decreases for hard (q=3 delta -0.14) but stays above the floor.
        #expect(abs(state.easeFactor - 2.36) < 1e-9)
    }

    // MARK: - Graduation

    @Test("Graduates to .known when interval >= 21")
    func graduationToKnown() {
        // Drive several easy reviews to push interval past 21 days.
        var state = SM2State()
        var graduated = false
        for _ in 0..<6 {
            state = SM2Scheduler.schedule(state: state, grade: .easy, now: now)
            if state.interval >= SM2Scheduler.graduationIntervalDays {
                #expect(state.wordState == .known)
                graduated = true
                break
            } else {
                #expect(state.wordState == .review)
            }
        }
        #expect(graduated, "card should have graduated to .known within 6 easy reviews")
    }

    @Test("Interval below threshold keeps card in .review, not .known")
    func belowThresholdStaysReview() {
        var state = SM2State()
        state = SM2Scheduler.schedule(state: state, grade: .good, now: now) // i=1
        #expect(state.interval < SM2Scheduler.graduationIntervalDays)
        #expect(state.wordState == .review)
        state = SM2Scheduler.schedule(state: state, grade: .good, now: now) // i=6
        #expect(state.interval < SM2Scheduler.graduationIntervalDays)
        #expect(state.wordState == .review)
    }
}
