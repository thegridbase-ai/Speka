import SwiftUI
import VocabularyKit
import SpekaUI

// MARK: - App-side accent mappings

/// Maps domain enums (which live in VocabularyKit / the app) to SpekaUI's
/// design-system accents. SpekaUI stays decoupled from VocabularyKit; this
/// bridge lives in the app target where both are already imported.

extension CEFRLevel {
    /// Per-level accent: a1=mint, a2=tangerine, b1=sunflower, b2=sky,
    /// c1=lavender, c2=bubblegum (driven by SpekaUI's `byLevelIndex`, indexed
    /// by the level's difficulty rank).
    var accent: SpekaAccent {
        SpekaAccent.byLevelIndex(rank)
    }
}

extension StudyMode {
    /// Per-mode accent driving the in-session chrome and Home mode-card chips.
    /// Aligned to Palette C: flashcard=coral/red, type=sky/blue,
    /// listen=lavender/purple, multipleChoice=mint/green.
    var spekaAccent: SpekaAccent {
        switch self {
        case .flashcard: return .coral
        case .type: return .sky
        case .listen: return .lavender
        case .multipleChoice: return .mint
        }
    }
}
