import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - SpekaMascot

/// Pip — the SPEKA mascot. Renders one of the staged poses from bundled
/// **transparent PNG** cutouts, with a gentle idle bounce and a pop on state
/// change (both gated behind Reduce Motion). Sits cleanly on any background.
///
/// ```swift
/// SpekaMascot(state: .cheer)
///     .frame(width: 160, height: 160)
/// ```
public struct SpekaMascot: View {

    /// Which staged Pip render to show.
    public enum PipState: String, CaseIterable, Sendable {
        /// Round, neutral hero pose.
        case hero
        /// Celebratory cheer (correct answer).
        case cheer
        /// Warm, encouraging pose (for misses / gentle nudges).
        case kind
        /// Trophy / mastery pose (session summary, level-up).
        case trophy
        /// Waving hello (onboarding greeter).
        case wave
        /// Thumbs-up (level picked / approval).
        case thumbsUp
        /// Napping (empty / caught-up state).
        case nap
        /// Holding a flame (streak milestone).
        case flame

        /// Bundled resource file stem.
        var resourceName: String {
            switch self {
            case .hero: return "pip-hero"
            case .cheer: return "pip-cheer"
            case .kind: return "pip-kind"
            case .trophy: return "pip-trophy"
            case .wave: return "pip-wave"
            case .thumbsUp: return "pip-thumbsup"
            case .nap: return "pip-nap"
            case .flame: return "pip-flame"
            }
        }
    }

    public var state: PipState
    /// Corner radius of the clip (cream blends best with a soft round clip).
    public var cornerRadius: CGFloat
    /// Whether to add the gentle idle bounce.
    public var idle: Bool

    public init(
        state: PipState = .hero,
        cornerRadius: CGFloat = 28,
        idle: Bool = true
    ) {
        self.state = state
        self.cornerRadius = cornerRadius
        self.idle = idle
    }

    public var body: some View {
        image
            .resizable()
            .scaledToFit()
            // Pop on state change.
            .id(state)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .modifier(IdleIf(enabled: idle))
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state)
    }

    /// The pose image, loaded from the package bundle with a graceful fallback
    /// to a friendly SF Symbol if the resource is missing.
    ///
    /// The Pip renders are bundled as loose transparent `.png` files (processed
    /// resources), so they are addressed by URL — `UIImage(named:in:)` only
    /// finds asset-catalog / named images, not loose files. We resolve the file
    /// URL via `Bundle.module` and load the bytes directly.
    private var image: Image {
        guard let url = Bundle.module.url(forResource: state.resourceName, withExtension: "png") else {
            return Image(systemName: "face.smiling.inverse")
        }
        #if canImport(UIKit)
        if let ui = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: ui)
        }
        #elseif canImport(AppKit)
        if let ns = NSImage(contentsOf: url) {
            return Image(nsImage: ns)
        }
        #endif
        return Image(systemName: "face.smiling.inverse")
    }
}

// MARK: - Idle bounce wrapper

/// Applies ``View/idleBounce(amount:)`` only when enabled, keeping the body a
/// single concrete view type.
private struct IdleIf: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.idleBounce(amount: 0.03)
        } else {
            content
        }
    }
}

#Preview("SpekaMascot") {
    ZStack {
        SpekaBackground()
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                SpekaMascot(state: .hero).frame(width: 120, height: 120)
                SpekaMascot(state: .cheer).frame(width: 120, height: 120)
            }
            HStack(spacing: 16) {
                SpekaMascot(state: .kind).frame(width: 120, height: 120)
                SpekaMascot(state: .trophy).frame(width: 120, height: 120)
            }
        }
    }
}
