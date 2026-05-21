import SwiftUI

// MARK: - SpekaColor

/// "Palette C — Canlı Gradyan / Oyunsu" semantic color tokens for SPEKA.
///
/// A neutral, near-white base with a vibrant three-stop brand gradient hero and
/// vivid per-mode accents. This replaces the earlier warm-cream "Sunny Studio"
/// palette: surfaces are white/cool, text is slightly cool (not warm espresso),
/// and the energy comes from gradients rather than flat candy fills.
///
/// Modeled on the caseless-`enum` namespace convention used by
/// `GridBaseColors`.
public enum SpekaColor {

    // MARK: Canvas & surfaces

    /// Primary app canvas — near-pure white `#FFFFFF` (top of the gradient).
    public static let canvas = Color(hex: "FFFFFF")
    /// Bottom of the canvas gradient — a whisper of cool depth `#FBFAFC`.
    public static let canvasBottom = Color(hex: "FBFAFC")
    /// Card / panel surface — pure white `#FFFFFF`.
    public static let surface = Color(hex: "FFFFFF")
    /// Recessed / track surface — cool light `#F0EDF4`.
    public static let surfaceSunken = Color(hex: "F0EDF4")
    /// Faint cool tint surface — `#F7F4FB`.
    public static let surfaceTint = Color(hex: "F7F4FB")
    /// Default hairline border — `#ECE9F1`.
    public static let border = Color(hex: "ECE9F1")
    /// Stronger border for focused / active elements — `#DED8E8`.
    public static let borderStrong = Color(hex: "DED8E8")

    // MARK: Text

    /// Primary text — cool near-black `#1C1830`.
    public static let textPrimary = Color(hex: "1C1830")
    /// Secondary text — cool grey `#6B6580`.
    public static let textSecondary = Color(hex: "6B6580")
    /// Tertiary / muted text — soft cool grey `#9E98AE`.
    public static let textTertiary = Color(hex: "9E98AE")
    /// Text drawn on top of an accent fill — white `#FFFFFF`.
    public static let onColor = Color(hex: "FFFFFF")

    // MARK: Brand gradient (the hero)

    /// The three-stop brand gradient stops, warm → magenta → violet:
    /// `#FFA63D` (0%) → `#F4495D` (55%) → `#8B2FE0` (100%).
    ///
    /// Used by the Home progress-ring arc, the primary CTA face, the weekly
    /// bars and the on-level CEFR chip.
    public static let brandStops: [Color] = [
        Color(hex: "FFA63D"),
        Color(hex: "F4495D"),
        Color(hex: "8B2FE0")
    ]

    /// Convenience `LinearGradient` for the brand stops, top-leading →
    /// bottom-trailing (the canonical fill direction for cards, buttons, bars).
    public static let brandGradient = LinearGradient(
        colors: brandStops,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The darker "edge" color for a brand-gradient 3D button lip — a
    /// darkened blend of the gradient's end stops.
    public static let brandEdge = Color(hex: "6E1FB0")

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
    /// Primary brand accent — the solid magenta `#F4495D` (focus, hero text).
    public static let primary = SpekaAccent.coral
}

// MARK: - SpekaAccent

/// A named accent ramp used across SpekaUI components.
///
/// Each accent bundles four sRGB colors:
/// - ``base`` — the saturated fill (buttons, chips, badges, ring arcs).
/// - ``soft`` — the pastel wash (tinted backgrounds, soft chips).
/// - ``edge`` — the darker shadow lip used for the Duolingo-style 3D button.
/// - ``partner`` — the second stop of the accent's 2-stop gradient (filled
///   mode-icon chips, in-session chrome). ``gradient`` runs `base → partner`.
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
    /// Partner stop for the accent's 2-stop gradient (`base → partner`).
    public let partner: Color

    public init(base: Color, soft: Color, edge: Color, partner: Color) {
        self.base = base
        self.soft = soft
        self.edge = edge
        self.partner = partner
    }

    /// Convenience initializer from four hex strings (base, soft, edge, partner).
    public init(baseHex: String, softHex: String, edgeHex: String, partnerHex: String) {
        self.init(
            base: Color(hex: baseHex),
            soft: Color(hex: softHex),
            edge: Color(hex: edgeHex),
            partner: Color(hex: partnerHex)
        )
    }

    /// The accent's 2-stop gradient (`base → partner`), top-leading →
    /// bottom-trailing. Used for filled mode-icon chips and in-session chrome.
    public var gradient: LinearGradient {
        LinearGradient(
            colors: [base, partner],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The accent's gradient stops, as raw colors (for callers that need a
    /// custom gradient shape, e.g. an `AngularGradient`).
    public var gradientStops: [Color] { [base, partner] }

    // MARK: Named accents

    /// Coral / red — the flashcard ("Kart") mode accent. `#FF6B6B → #F4495D`.
    public static let coral = SpekaAccent(
        baseHex: "FF6B6B", softHex: "FFEAEA", edgeHex: "D6354A", partnerHex: "F4495D"
    )
    /// Tangerine — warm orange (streaks, "due" stat). `#FF8A2B → #FF6B2B`.
    public static let tangerine = SpekaAccent(
        baseHex: "FF8A2B", softHex: "FFF0E6", edgeHex: "E8731A", partnerHex: "FF6B2B"
    )
    /// Sunflower — golden yellow (XP, "almost"). `#FFC93C → #FFA63D`.
    public static let sunflower = SpekaAccent(
        baseHex: "FFC93C", softHex: "FFF6DA", edgeHex: "E8AE18", partnerHex: "FFA63D"
    )
    /// Mint / green — the multiple-choice ("Seçenek") mode + correct answer.
    /// `#2BD47A → #10B36A`.
    public static let mint = SpekaAccent(
        baseHex: "2BD47A", softHex: "E9FBF1", edgeHex: "0E9B5C", partnerHex: "10B36A"
    )
    /// Sky / blue — the type ("Yazma") mode accent. `#4F8BFF → #3A5CF6`.
    public static let sky = SpekaAccent(
        baseHex: "4F8BFF", softHex: "E6EEFF", edgeHex: "2F4FD6", partnerHex: "3A5CF6"
    )
    /// Lavender / purple — the listen ("Dinle") mode accent. `#A24BFF → #7C2FE0`.
    public static let lavender = SpekaAccent(
        baseHex: "A24BFF", softHex: "F3E9FF", edgeHex: "6E1FB0", partnerHex: "7C2FE0"
    )
    /// Bubblegum — playful pink (the "new" stat). `#FF7EB6 → #EB5C9C`.
    public static let bubblegum = SpekaAccent(
        baseHex: "FF7EB6", softHex: "FFE3F0", edgeHex: "D6427F", partnerHex: "EB5C9C"
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
