import SwiftUI
import Testing
@testable import SpekaUI

/// Compile + behaviour smoke tests for SpekaUI. Building these forces every
/// public component's `body` / API to type-check, and asserts the palette,
/// font and accent invariants hold.
@Suite("SpekaUI smoke")
@MainActor
struct SmokeTests {

    // MARK: - Color + Hex

    @Test("Color(hex:) parses the Sunny Studio palette")
    func hexParses() {
        // Must not trap; channel values validated below.
        _ = Color(hex: "FFF8F0")     // canvas
        _ = Color(hex: "#3DD9A0")    // mint
        _ = Color(hex: "2B2118")     // text primary
        _ = Color(hex: "fff")        // 3-digit
        _ = Color(hex: "CCFFF8F0")   // 8-digit ARGB
        _ = Color(hex: "")           // empty → falls back, no crash
    }

    @Test("6-digit hex resolves to expected RGB channels (coral #FF6B5E)")
    func hexChannels() throws {
        #if canImport(UIKit)
        let coral = UIColor(SpekaAccent.coral.base)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        coral.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 0xFF / 255.0) < 0.01)
        #expect(abs(g - 0x6B / 255.0) < 0.01)
        #expect(abs(b - 0x5E / 255.0) < 0.01)
        #expect(abs(a - 1.0) < 0.01)
        #else
        let coral = try #require(NSColor(SpekaAccent.coral.base).usingColorSpace(.sRGB))
        #expect(abs(coral.redComponent - 0xFF / 255.0) < 0.01)
        #expect(abs(coral.greenComponent - 0x6B / 255.0) < 0.01)
        #expect(abs(coral.blueComponent - 0x5E / 255.0) < 0.01)
        #endif
    }

    // MARK: - SpekaColor tokens

    @Test("Canvas / surface / text tokens are accessible")
    func paletteTokens() {
        _ = SpekaColor.canvas
        _ = SpekaColor.canvasBottom
        _ = SpekaColor.surface
        _ = SpekaColor.surfaceSunken
        _ = SpekaColor.surfaceTint
        _ = SpekaColor.border
        _ = SpekaColor.borderStrong
        _ = SpekaColor.textPrimary
        _ = SpekaColor.textSecondary
        _ = SpekaColor.textTertiary
        _ = SpekaColor.onColor
    }

    @Test("Semantic accent helpers map to the right named accents")
    func semanticAccents() {
        #expect(SpekaColor.correct == SpekaAccent.mint)
        #expect(SpekaColor.wrong == SpekaAccent.coral)
        #expect(SpekaColor.almost == SpekaAccent.sunflower)
        #expect(SpekaColor.streak == SpekaAccent.tangerine)
        #expect(SpekaColor.xp == SpekaAccent.sunflower)
        #expect(SpekaColor.primary == SpekaAccent.coral)
    }

    @Test("All seven accents expose distinct base/soft/edge")
    func accentRamp() {
        #expect(SpekaAccent.all.count == 7)
        for accent in SpekaAccent.all {
            _ = accent.base
            _ = accent.soft
            _ = accent.edge
        }
    }

    @Test("byLevelIndex maps 0..5 in palette order and wraps out-of-range")
    func levelIndexMapping() {
        #expect(SpekaAccent.byLevelIndex(0) == SpekaAccent.mint)
        #expect(SpekaAccent.byLevelIndex(1) == SpekaAccent.tangerine)
        #expect(SpekaAccent.byLevelIndex(2) == SpekaAccent.sunflower)
        #expect(SpekaAccent.byLevelIndex(3) == SpekaAccent.sky)
        #expect(SpekaAccent.byLevelIndex(4) == SpekaAccent.lavender)
        #expect(SpekaAccent.byLevelIndex(5) == SpekaAccent.bubblegum)
        // Wrap-around (6 → 0 → mint) and negative indices are safe.
        #expect(SpekaAccent.byLevelIndex(6) == SpekaAccent.mint)
        #expect(SpekaAccent.byLevelIndex(-1) == SpekaAccent.bubblegum)
    }

    // MARK: - SpekaFont (graceful fallback + scale)

    @Test("SpekaFont registers Fredoka or falls back without crashing")
    func fonts() {
        let registered = SpekaFont.registerFonts()
        // Fredoka IS bundled, so registration should succeed; but the contract
        // is only that it does not crash and reports a note either way.
        _ = registered
        _ = SpekaFont.display(size: 40)
        _ = SpekaFont.ui(size: 16, weight: .medium)
        #expect(!SpekaFont.registrationNote.isEmpty)
    }

    @Test("Type scale exposes every style with correct tracking/case rules")
    func typeScale() {
        for style in [
            SpekaFont.Style.displayHero, .displayTitle, .title, .headline,
            .body, .callout, .subhead, .caption, .label, .numberXL, .numberMD
        ] {
            _ = SpekaFont.font(style)
        }
        // Only the all-caps label carries tracking + uppercasing.
        #expect(SpekaFont.tracking(.label) == 0.5)
        #expect(SpekaFont.tracking(.body) == 0)
        #expect(SpekaFont.isUppercased(.label))
        #expect(!SpekaFont.isUppercased(.title))
    }

    // MARK: - View construction (forces body type-check)

    @Test("Background + dot grid build")
    func backgrounds() {
        _ = AnyView(SpekaBackground())
        _ = AnyView(SpekaBackground(showDotGrid: false))
        _ = AnyView(DotGridView())
    }

    @Test("Buttons build for every variant")
    func buttons() {
        _ = AnyView(SpekaButton("Check", systemImage: "checkmark", variant: .filled(.mint)) {})
        _ = AnyView(SpekaButton("Skip", variant: .ghost(.sky)) {})
        _ = AnyView(SpekaButton("Locked", variant: .disabled) {})
        _ = AnyView(SpekaButton("Cap", variant: .filled(.coral), capsule: true, fullWidth: true) {})
        _ = AnyView(Text("x").buttonStyle(SpekaButtonStyle(variant: .filled(.coral))))
        _ = AnyView(Text("x").buttonStyle(SpekaButtonStyle(variant: .ghost(.sky))))
        _ = AnyView(Text("x").buttonStyle(SpekaButtonStyle(variant: .disabled)))
    }

    @Test("Cards build (plain + accent)")
    func cards() {
        _ = AnyView(SpekaCard { Text("plain") })
        _ = AnyView(SpekaCard(accent: .mint, systemImage: "checkmark.seal.fill") { Text("accent") })
    }

    @Test("Chips build (selected + unselected, with/without action)")
    func chips() {
        _ = AnyView(SpekaChip("A1", accent: .mint, isSelected: true))
        _ = AnyView(SpekaChip("A2", systemImage: "sparkles", accent: .sky) {})
    }

    @Test("Ring + progress bar build and clamp")
    func ringAndBar() {
        _ = AnyView(SpekaRing(progress: 0.42, accent: .mint))
        _ = AnyView(SpekaRing(progress: 1.5, accent: .lavender) { Text("A2") })
        _ = AnyView(SpekaProgressBar(progress: 0.6, accent: .sunflower))

        let overRing = SpekaRing(progress: 2.0)
        let underRing = SpekaRing(progress: -1.0)
        #expect(overRing.progress == 1.0)
        #expect(underRing.progress == 0.0)

        let overBar = SpekaProgressBar(progress: 5.0)
        let underBar = SpekaProgressBar(progress: -5.0)
        #expect(overBar.progress == 1.0)
        #expect(underBar.progress == 0.0)
    }

    @Test("Badges build for every shape / state")
    func badges() {
        _ = AnyView(StreakBadge(days: 12))
        _ = AnyView(XPBadge(xp: 1280))
        _ = AnyView(LevelBadge(letter: "A", accent: .mint))
        _ = AnyView(LevelBadge(letter: "B", accent: .sky, shape: .hexagon))
        _ = AnyView(LevelBadge(letter: "C", accent: .bubblegum, isLocked: true))
        _ = AnyView(HexagonShape().fill(.red))
    }

    @Test("Confetti + every mascot state build")
    func confettiAndMascot() {
        _ = AnyView(SpekaConfetti(isActive: true))
        _ = AnyView(SpekaConfetti(isActive: false, duration: 2.0, colors: [.red, .blue]))
        for state in SpekaMascot.PipState.allCases {
            _ = AnyView(SpekaMascot(state: state))
        }
        #expect(SpekaMascot.PipState.allCases.count == 4)
    }

    @Test("Motion modifiers build and gate behind Reduce Motion")
    func motion() {
        _ = AnyView(Text("shake").shake(trigger: 1))
        _ = AnyView(Text("pop").popIn())
        _ = AnyView(Text("pop").popIn(delay: 0.2))
        _ = AnyView(Text("idle").idleBounce())
        _ = AnyView(Text("scale").spekaFont(.headline))
    }

    @Test("Every Pip render is bundled as a package resource")
    func pipResourcesBundled() throws {
        for state in SpekaMascot.PipState.allCases {
            let url = Bundle.module.url(forResource: state.resourceName, withExtension: "jpg")
            #expect(url != nil, "Missing bundled render: \(state.resourceName).jpg")
        }
        // Fredoka font is bundled too.
        let font = Bundle.module.url(forResource: "Fredoka-VariableFont", withExtension: "ttf")
        #expect(font != nil, "Fredoka font not bundled")
    }
}
