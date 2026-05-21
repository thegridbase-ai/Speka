import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper over UIKit feedback generators for subtle, meaningful haptics.
///
/// Pass 1 uses the lightweight UIKit generators (selection / impact / notification)
/// rather than a full CoreHaptics engine — the flashcard loop only needs short,
/// discrete taps on grade and selection. No-ops on platforms without UIKit.
enum UISelection {
    static func tap() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}

/// Impact feedback for grading a card. Intensity maps to the grade weight.
enum GradeHaptics {
    enum Strength {
        case light, medium, heavy, success
    }

    static func play(_ strength: Strength) {
        #if canImport(UIKit)
        switch strength {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }
}
