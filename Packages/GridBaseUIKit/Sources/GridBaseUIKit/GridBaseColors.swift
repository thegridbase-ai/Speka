import SwiftUI

// MARK: - GridBase Colors

/// Canonical GridBase design-language palette.
///
/// Mirrors the web design tokens (see globals.css):
/// `bg: #0a0a0f`, `accent: #00f0ff (cyan)`, `secondary: #a855f7 (purple)`,
/// glassmorphism surfaces and `white/[0.06]` borders.
///
/// Modeled on Haptic's `HapticColors` enum convention (static `Color`
/// constants on a caseless `enum` namespace).
public enum GridBaseColors {

    // MARK: Backgrounds

    /// Primary app background — `#0a0a0f` (deep space black, blue undertone).
    public static let background = Color(hex: "0a0a0f")
    /// Slightly lighter base used for gradient mid-stops — `#0d0d14`.
    public static let backgroundElevated = Color(hex: "0d0d14")
    /// Card / panel surface beneath the glass layer — `#14141a`.
    public static let surface = Color(hex: "14141a")
    /// Elevated surface (modals, popovers) — `#1e1e26`.
    public static let surfaceElevated = Color(hex: "1e1e26")

    // MARK: Accents

    /// Primary accent — cyan `#00f0ff`.
    public static let cyan = Color(hex: "00f0ff")
    /// Secondary accent — purple `#a855f7`.
    public static let purple = Color(hex: "a855f7")

    /// Convenience alias for the primary accent.
    public static let accent = cyan
    /// Convenience alias for the secondary accent.
    public static let secondary = purple

    // MARK: Glassmorphism tokens

    /// Glass fill — translucent white at 6% (`white/[0.06]`).
    public static let glass = Color.white.opacity(0.06)
    /// Glass fill on hover / press — `white/[0.10]`.
    public static let glassHover = Color.white.opacity(0.10)
    /// Default hairline border — `white/[0.06]`.
    public static let border = Color.white.opacity(0.06)
    /// Stronger border for focused / active elements — `white/[0.12]`.
    public static let borderStrong = Color.white.opacity(0.12)
    /// Accent-tinted hover border — `cyan/20`.
    public static let accentBorder = cyan.opacity(0.20)

    // MARK: Text

    /// Primary text — pure white.
    public static let textPrimary = Color.white
    /// Secondary text — `white/[0.60]`.
    public static let textSecondary = Color.white.opacity(0.60)
    /// Tertiary / muted text — `white/[0.35]`.
    public static let textTertiary = Color.white.opacity(0.35)

    // MARK: Status

    /// Success / positive — green.
    public static let success = Color(hex: "34d399")
    /// Warning — amber.
    public static let warning = Color(hex: "fbbf24")
    /// Error / destructive — soft red.
    public static let error = Color(hex: "ff6b6b")
}
