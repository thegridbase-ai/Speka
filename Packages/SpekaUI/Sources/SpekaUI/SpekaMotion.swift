import SwiftUI

// MARK: - SpekaMotion

/// Reusable iOS 17 motion helpers for SpekaUI, all gated behind Reduce Motion.
///
/// These wrap the modern APIs the alchemist flagged — `KeyframeAnimator`
/// (shake), spring `.scaleEffect` pops, and `PhaseAnimator` idle loops — into
/// drop-in modifiers so the re-skin pass can sprinkle motion without
/// re-deriving the timing each time.

// MARK: Shake (KeyframeAnimator)

/// Horizontal "no" shake driven by a changing `trigger` value (e.g. a wrong
/// answer count). Uses `KeyframeAnimator` for a crisp, self-contained wobble.
private struct ShakeModifier<T: Equatable & Sendable>: ViewModifier {
    let trigger: T
    let amplitude: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .keyframeAnimator(
                    initialValue: CGFloat.zero,
                    trigger: trigger
                ) { view, offset in
                    view.offset(x: offset)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-amplitude, duration: 0.06)
                        CubicKeyframe(amplitude, duration: 0.08)
                        CubicKeyframe(-amplitude * 0.6, duration: 0.08)
                        CubicKeyframe(amplitude * 0.4, duration: 0.08)
                        CubicKeyframe(0, duration: 0.10)
                    }
                }
        }
    }
}

// MARK: Pop-in (spring scale)

/// A spring "pop" the first time the view appears — scales up from a slightly
/// shrunken, faded state. Honors Reduce Motion (renders fully visible, no
/// animation).
private struct PopInModifier: ViewModifier {
    let delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .scaleEffect(shown ? 1 : 0.86)
                .opacity(shown ? 1 : 0)
                .onAppear {
                    withAnimation(
                        .spring(response: 0.45, dampingFraction: 0.62)
                        .delay(delay)
                    ) {
                        shown = true
                    }
                }
        }
    }
}

// MARK: Idle bounce (PhaseAnimator)

/// A gentle, never-ending idle bounce (≤3% scale) for playful elements like
/// the mascot. Honors Reduce Motion (renders static).
private struct IdleBounceModifier: ViewModifier {
    /// Max scale delta (e.g. 0.03 → bounces between 1.0 and 1.03).
    let amount: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.phaseAnimator([false, true]) { view, up in
                view.scaleEffect(up ? 1 + amount : 1 - amount * 0.3)
            } animation: { _ in
                .easeInOut(duration: 1.6)
            }
        }
    }
}

// MARK: - Public modifiers

public extension View {
    /// Shakes horizontally whenever `trigger` changes. Disabled under Reduce
    /// Motion.
    ///
    /// ```swift
    /// AnswerField().shake(trigger: wrongAttempts)
    /// ```
    func shake<T: Equatable & Sendable>(trigger: T, amplitude: CGFloat = 8) -> some View {
        modifier(ShakeModifier(trigger: trigger, amplitude: amplitude))
    }

    /// Pops in with a spring on first appear. Disabled under Reduce Motion.
    func popIn(delay: Double = 0) -> some View {
        modifier(PopInModifier(delay: delay))
    }

    /// Adds a gentle, repeating idle bounce. Disabled under Reduce Motion.
    func idleBounce(amount: CGFloat = 0.03) -> some View {
        modifier(IdleBounceModifier(amount: amount))
    }
}
