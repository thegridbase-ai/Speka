import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - SpekaConfetti

/// A lightweight, GPU-driven confetti celebration overlay.
///
/// Uses a `CAEmitterLayer` (no third-party dependency). Drop it over content
/// and flip `isActive` to fire a burst; the emitter stops after `duration` and
/// removes its layer to keep things cheap. Honors **Reduce Motion** — when the
/// user prefers reduced motion, nothing emits.
///
/// ```swift
/// ZStack {
///     content
///     SpekaConfetti(isActive: didFinishLesson)
///         .allowsHitTesting(false)
/// }
/// ```
public struct SpekaConfetti: View {
    /// When this flips to `true`, a burst fires.
    public var isActive: Bool
    /// How long the emitter stays on before stopping.
    public var duration: Double
    /// Confetti colors (defaults to the seven Sunny Studio accents).
    public var colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        isActive: Bool,
        duration: Double = 1.4,
        colors: [Color] = SpekaAccent.all.map(\.base)
    ) {
        self.isActive = isActive
        self.duration = duration
        self.colors = colors
    }

    public var body: some View {
        #if canImport(UIKit)
        ConfettiEmitterView(
            isActive: isActive && !reduceMotion,
            duration: duration,
            colors: colors.map { UIColor($0) }
        )
        .allowsHitTesting(false)
        #else
        // Non-UIKit platforms (macOS preview targets): no-op overlay.
        Color.clear
        #endif
    }
}

#if canImport(UIKit)

// MARK: - CAEmitterLayer representable

private struct ConfettiEmitterView: UIViewRepresentable {
    let isActive: Bool
    let duration: Double
    let colors: [UIColor]

    func makeUIView(context: Context) -> EmitterHostView {
        EmitterHostView()
    }

    func updateUIView(_ uiView: EmitterHostView, context: Context) {
        if isActive {
            uiView.fire(duration: duration, colors: colors)
        }
    }
}

/// Hosts a transient `CAEmitterLayer`; emits a burst then tears the layer down.
final class EmitterHostView: UIView {
    private var didFire = false

    func fire(duration: Double, colors: [UIColor]) {
        // Fire once per activation to avoid stacking emitters on re-renders.
        guard !didFire else { return }
        didFire = true

        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -12)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = colors.map { cell(color: $0) }
        layer.addSublayer(emitter)

        // Stop emitting new cells after `duration`, then remove the layer once
        // the in-flight confetti has fallen offscreen.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak emitter] in
            emitter?.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 3.0) { [weak self, weak emitter] in
            emitter?.removeFromSuperlayer()
            self?.didFire = false
        }
    }

    private func cell(color: UIColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = 6
        cell.lifetime = 5
        cell.velocity = 220
        cell.velocityRange = 80
        cell.emissionLongitude = .pi          // downward
        cell.emissionRange = .pi / 5
        cell.spin = 3.5
        cell.spinRange = 4
        cell.scale = 0.6
        cell.scaleRange = 0.3
        cell.color = color.cgColor
        cell.contents = Self.confettiImage.cgImage
        return cell
    }

    /// Small rounded-rect confetti chip, rasterized once and tinted per cell.
    private static let confettiImage: UIImage = {
        let size = CGSize(width: 9, height: 14)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            let path = UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: 2.5
            )
            path.fill()
        }
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep any live emitter spanning the current width.
        for sublayer in layer.sublayers ?? [] {
            guard let emitter = sublayer as? CAEmitterLayer else { continue }
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: -12)
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        }
    }
}

#endif

#Preview("SpekaConfetti") {
    ZStack {
        SpekaBackground()
        Text("Lesson Complete!")
            .spekaFont(.displayTitle)
            .foregroundStyle(SpekaColor.textPrimary)
        SpekaConfetti(isActive: true)
    }
}
