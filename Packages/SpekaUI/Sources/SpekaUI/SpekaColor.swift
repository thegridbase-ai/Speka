import SwiftUI

// MARK: - SpekaColor

/// "Sunny Studio" semantic color tokens for SPEKA.
///
/// A warm, light, pastel palette — cream canvases, white surfaces and seven
/// candy-bright accents. This is the inverse of GridBaseUIKit's dark cyberpunk
/// language; the two coexist (GridBaseUIKit stays dark for sibling apps).
///
/// Modeled on the caseless-`enum` namespace convention used by
/// `GridBaseColors`.
public enum SpekaColor {

    // MARK: Canvas & surfaces

    /// Primary app canvas — warm cream `#FFF8F0` (top of the gradient).
    public static let canvas = Color(hex: "FFF8F0")
    /// Bottom of the canvas gradient — slightly warmer cream `#FFF1E6`.
    public static let canvasBottom = Color(hex: "FFF1E6")
    /// Card / panel surface — pure white `#FFFFFF`.
    public static let surface = Color(hex: "FFFFFF")
    /// Recessed / track surface — sand `#F4EDE3`.
    public static let surfaceSunken = Color(hex: "F4EDE3")
    /// Faint warm tint surface — `#FDF2E9`.
    public static let surfaceTint = Color(hex: "FDF2E9")
    /// Default hairline border — `#EDE3D6`.
    public static let border = Color(hex: "EDE3D6")
    /// Stronger border for focused / active elements — `#E2D4C2`.
    public static let borderStrong = Color(hex: "E2D4C2")

    // MARK: Text

    /// Primary text — espresso `#2B2118`.
    public static let textPrimary = Color(hex: "2B2118")
    /// Secondary text — warm taupe `#6B5D4F`.
    public static let textSecondary = Color(hex: "6B5D4F")
    /// Tertiary / muted text — soft tan `#A1907E`.
    public static let textTertiary = Color(hex: "A1907E")
    /// Text drawn on top of an accent fill — white `#FFFFFF`.
    public static let onColor = Color(hex: "FFFFFF")

    // MARK: Semantic accent helpers

    /// Positive / correct answer — mint.
    public static let correct = SpekaAccent.mint
    /// Negative / wrong answer — coral.
    public static let wrong = SpekaAccent.coral
    /// "Almost" / near-miss — sunflower.
    public static let almost = SpekaAccent.sunflower
    /// Streak emphasis — tangerine.
    public static let streak = SpekaAccent.tangerine
    /// XP emphasis — sunflower.
    public static let xp = SpekaAccent.sunflower
    /// Primary brand accent — coral.
    public static let primary = SpekaAccent.coral
}

// MARK: - SpekaAccent

/// A three-tone accent ramp used across SpekaUI components.
///
/// Each accent bundles three sRGB colors:
/// - ``base`` — the saturated fill (buttons, chips, badges, ring arcs).
/// - ``soft`` — the pastel wash (tinted backgrounds, soft chips).
/// - ``edge`` — the darker shadow lip used for the Duolingo-style 3D button.
///
/// SpekaUI is intentionally **decoupled** from VocabularyKit: it does not
/// import `CEFRLevel` / `StudyMode`. The app target maps its own enums to
/// these named accents (or uses ``byLevelIndex(_:)``).
public struct SpekaAccent: Equatable, Sendable {

    /// Saturated fill color.
    public let base: Color
    /// Pastel / soft wash.
    public let soft: Color
    /// Darker shadow-lip color for the 3D button depth.
    public let edge: Color

    public init(base: Color, soft: Color, edge: Color) {
        self.base = base
        self.soft = soft
        self.edge = edge
    }

    /// Convenience initializer from three hex strings (base, soft, edge).
    public init(baseHex: String, softHex: String, edgeHex: String) {
        self.init(
            base: Color(hex: baseHex),
            soft: Color(hex: softHex),
            edge: Color(hex: edgeHex)
        )
    }

    // MARK: Named accents

    /// Coral — the primary brand accent.
    public static let coral = SpekaAccent(
        baseHex: "FF6B5E", softHex: "FFE5E1", edgeHex: "E04E42"
    )
    /// Tangerine — warm orange (streaks).
    public static let tangerine = SpekaAccent(
        baseHex: "FF9F45", softHex: "FFEAD2", edgeHex: "E8842B"
    )
    /// Sunflower — golden yellow (XP, "almost").
    public static let sunflower = SpekaAccent(
        baseHex: "FFC93C", softHex: "FFF3CF", edgeHex: "E8AE18"
    )
    /// Mint — fresh green (correct).
    public static let mint = SpekaAccent(
        baseHex: "3DD9A0", softHex: "D6F7EC", edgeHex: "23BD86"
    )
    /// Sky — friendly blue.
    public static let sky = SpekaAccent(
        baseHex: "4FB8F5", softHex: "DCF0FD", edgeHex: "2F9BE0"
    )
    /// Lavender — soft purple.
    public static let lavender = SpekaAccent(
        baseHex: "A98CF0", softHex: "ECE4FD", edgeHex: "8E6FE0"
    )
    /// Bubblegum — playful pink.
    public static let bubblegum = SpekaAccent(
        baseHex: "FF7EB6", softHex: "FFE3F0", edgeHex: "EB5C9C"
    )

    /// All seven named accents, in palette order.
    public static let all: [SpekaAccent] = [
        coral, tangerine, sunflower, mint, sky, lavender, bubblegum
    ]

    /// Maps a level index to an accent for per-level theming.
    ///
    /// The app target maps its own enum (e.g. CEFR levels A1…C2) to an index
    /// and calls this — SpekaUI never sees the enum itself.
    ///
    /// `0 → mint, 1 → tangerine, 2 → sunflower, 3 → sky, 4 → lavender,
    /// 5 → bubblegum`. Out-of-range indices wrap modulo the ramp.
    public static func byLevelIndex(_ i: Int) -> SpekaAccent {
        let ramp: [SpekaAccent] = [mint, tangerine, sunflower, sky, lavender, bubblegum]
        let idx = ((i % ramp.count) + ramp.count) % ramp.count
        return ramp[idx]
    }
}
