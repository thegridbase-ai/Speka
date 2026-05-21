import Foundation

/// Learner self-assessment after seeing a card's answer.
/// Maps to the SM-2 quality score `q` used by the scheduler.
public enum ReviewGrade: String, Codable, CaseIterable, Sendable {
    /// Complete blackout / wrong answer → lapse.
    case again
    /// Recalled with serious difficulty.
    case hard
    /// Recalled correctly with some effort.
    case good
    /// Recalled effortlessly.
    case easy

    /// SM-2 quality score (`q`). Values < 3 trigger a lapse.
    public var quality: Int {
        switch self {
        case .again: return 1
        case .hard: return 3
        case .good: return 4
        case .easy: return 5
        }
    }
}
