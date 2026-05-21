import Foundation
import SwiftUI
import SpekaUI

/// The four practice modes that share the same session queue + SM-2 grading
/// pipeline. Each value names a render strategy for a single card; the host
/// (`StudySessionView`) owns the queue, advance, persistence and summary.
enum StudyMode: String, CaseIterable, Identifiable {
    case flashcard
    case type
    case listen
    case multipleChoice

    var id: String { rawValue }

    /// Short label for the Home-screen mode picker.
    var title: String {
        switch self {
        case .flashcard: return "Flashcard"
        case .type: return "Type"
        case .listen: return "Listen"
        case .multipleChoice: return "Choice"
        }
    }

    /// One-line description shown under the picker.
    var subtitle: String {
        switch self {
        case .flashcard: return "Flip the card, grade your recall"
        case .type: return "Type the Turkish translation"
        case .listen: return "Hear it, spell the English word"
        case .multipleChoice: return "Pick the right translation"
        }
    }

    var systemImage: String {
        switch self {
        case .flashcard: return "rectangle.on.rectangle.angled"
        case .type: return "keyboard"
        case .listen: return "ear.fill"
        case .multipleChoice: return "checklist"
        }
    }

    /// Convenience: the mode's accent base color (see `spekaAccent` for the
    /// full base/soft/edge ramp used by SpekaUI components).
    var accent: Color { spekaAccent.base }

    /// Launch-arg token used by the `-speka-autostudy` DEBUG affordance to
    /// deterministically reach a given mode headlessly.
    var launchToken: String { rawValue }

    init?(launchToken: String) {
        self.init(rawValue: launchToken)
    }
}

/// Diacritic- and case-insensitive answer comparison, with Turkish-aware
/// folding so "İ"/"ı"/"i" and accented characters compare equal.
enum AnswerMatch {
    /// Folded comparison key: lowercased (Turkish locale), diacritics stripped,
    /// punctuation/whitespace collapsed.
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Turkish-locale lowercasing keeps İ→i / I→ı sane before folding.
        let lowered = trimmed.lowercased(with: Locale(identifier: "tr_TR"))
        // Strip diacritics so " İ" → "i", "ö" → "o" etc. compare loosely.
        let folded = lowered.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "tr_TR")
        )
        // Collapse internal whitespace; drop surrounding punctuation noise.
        let collapsed = folded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
    }

    /// Whether two strings match after normalization. A translation may carry
    /// multiple comma/slash-separated senses ("happy, glad"); any one matching
    /// the input counts as correct.
    static func isCorrect(_ input: String, expected: String) -> Bool {
        let normalizedInput = normalize(input)
        guard !normalizedInput.isEmpty else { return false }
        for candidate in senses(of: expected) where normalize(candidate) == normalizedInput {
            return true
        }
        return false
    }

    /// Whether the input is "close" — a single edit away from any sense.
    /// Used to award `.hard` instead of `.again` on a minor typo.
    static func isMinorTypo(_ input: String, expected: String) -> Bool {
        let normalizedInput = normalize(input)
        guard normalizedInput.count >= 3 else { return false }
        for candidate in senses(of: expected) {
            let target = normalize(candidate)
            guard !target.isEmpty else { continue }
            if levenshtein(normalizedInput, target) <= 1 { return true }
        }
        return false
    }

    /// Split a translation string into individual senses on commas / slashes /
    /// semicolons.
    static func senses(of text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",/;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Classic iterative Levenshtein edit distance.
    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a), t = Array(b)
        if s.isEmpty { return t.count }
        if t.isEmpty { return s.count }
        var prev = Array(0...t.count)
        var curr = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            curr[0] = i
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,        // deletion
                    curr[j - 1] + 1,    // insertion
                    prev[j - 1] + cost  // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[t.count]
    }
}
