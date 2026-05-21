#if DEBUG
import Foundation
import SwiftUI
import VocabularyKit

/// A tiny set of closures the ``DemoDriver`` calls to drive `StudySessionView`
/// through the real animation code paths — no synthetic taps, just the same
/// functions a real tap would invoke.
struct DemoHost {
    /// Toggle the flashcard flip (the real 3D rotation + spring).
    let flip: () -> Void
    /// Grade the current card (fires confetti / shake / Pip + advances).
    let grade: (ReviewGrade) -> Void
    /// Whether the session has reached the summary screen.
    let isFinished: () -> Bool
}

/// DEBUG-only scripted "auto-demo" used to capture a screen recording of the
/// study-session animations without any user taps.
///
/// Gated entirely behind `#if DEBUG` and only ever constructed when the
/// `-speka-demo` launch argument is present, so release builds never compile or
/// run any of this. It walks a fixed script on a timer:
///
/// 1. let the flashcard settle on screen,
/// 2. flip it (3D perspective flip),
/// 3. grade **Good** → correct feedback (mint + confetti + Pip cheer),
/// 4. on the next card, flip then grade **Again** → wrong feedback (shake + Pip kind),
/// 5. flip + grade the remaining cards alternately until the session ends and
///    `SessionSummaryView` (confetti + Pip trophy + count-up stats) appears.
@MainActor
final class DemoDriver: ObservableObject {
    private var task: Task<Void, Never>?
    private var started = false

    /// Begin the scripted run against the given host. Idempotent.
    func start(host: DemoHost) {
        guard !started else { return }
        started = true
        task = Task { [weak self] in
            await self?.run(host: host)
        }
    }

    /// Cancel the script (e.g. on disappear).
    func stop() {
        task?.cancel()
        task = nil
    }

    private func run(host: DemoHost) async {
        // (a) Let the session card finish presenting / settling.
        await pause(1.6)
        guard !Task.isCancelled else { return }

        // Card 1 — the showcase correct flow.
        // (c) Flip to reveal the answer (3D flip + perspective).
        host.flip()
        await pause(1.8)
        guard !Task.isCancelled else { return }

        // (d) Grade "Good": mint feedback + confetti + Pip cheer, then advance.
        host.grade(.good)
        await pause(2.0)
        guard !Task.isCancelled else { return }

        // Card 2 — the wrong-answer flow.
        host.flip()
        await pause(1.6)
        guard !Task.isCancelled else { return }

        // (e) Grade "Again": shake + Pip kind, then advance.
        host.grade(.again)
        await pause(2.0)
        guard !Task.isCancelled else { return }

        // (f) Advance through the rest of the queue (alternating correct/wrong)
        //     until the session completes and the summary appears.
        var safety = 0
        while !host.isFinished() && !Task.isCancelled && safety < 40 {
            host.flip()
            await pause(1.1)
            guard !Task.isCancelled else { return }
            host.grade(safety.isMultiple(of: 2) ? .good : .again)
            await pause(1.3)
            safety += 1
        }
        // Linger on the summary so the trophy + count-up + confetti are captured.
    }

    /// Cancellation-aware sleep in seconds.
    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
#endif
