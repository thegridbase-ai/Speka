import SwiftUI
import Testing
@testable import GridBaseUIKit

/// Compile + behaviour smoke tests. Building these forces every public
/// component's `body` / API to type-check, and asserts a few invariants.
@Suite("GridBaseUIKit smoke")
@MainActor
struct SmokeTests {

    // MARK: - Color + Hex

    @Test("Color(hex:) parses the canonical palette")
    func hexParses() {
        // These must not trap; exact channel values are validated below.
        _ = Color(hex: "00f0ff")
        _ = Color(hex: "#a855f7")
        _ = Color(hex: "0a0a0f")
        _ = Color(hex: "fff")        // 3-digit
        _ = Color(hex: "CC0a0a0f")   // 8-digit ARGB
        _ = Color(hex: "")           // empty → falls back, no crash
    }

    @Test("6-digit hex resolves to expected RGB channels")
    func hexChannels() throws {
        #if canImport(UIKit)
        let cyan = UIColor(Color(hex: "00f0ff"))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        cyan.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 0.0) < 0.01)
        #expect(abs(g - 240.0 / 255.0) < 0.01)
        #expect(abs(b - 1.0) < 0.01)
        #expect(abs(a - 1.0) < 0.01)
        #else
        let cyan = NSColor(Color(hex: "00f0ff")).usingColorSpace(.sRGB)
        let resolved = try #require(cyan)
        #expect(abs(resolved.redComponent - 0.0) < 0.01)
        #expect(abs(resolved.greenComponent - 240.0 / 255.0) < 0.01)
        #expect(abs(resolved.blueComponent - 1.0) < 0.01)
        #endif
    }

    // MARK: - Colors namespace

    @Test("Palette tokens are accessible")
    func paletteTokens() {
        _ = GridBaseColors.background
        _ = GridBaseColors.cyan
        _ = GridBaseColors.purple
        _ = GridBaseColors.glass
        _ = GridBaseColors.glassHover
        _ = GridBaseColors.border
        _ = GridBaseColors.borderStrong
        _ = GridBaseColors.accentBorder
        _ = GridBaseColors.textPrimary
        _ = GridBaseColors.success
        #expect(GridBaseColors.accent == GridBaseColors.cyan)
        #expect(GridBaseColors.secondary == GridBaseColors.purple)
    }

    // MARK: - Fonts (graceful fallback)

    @Test("GridFont registers/falls back without crashing")
    func fonts() {
        let result = GridFont.registerFonts()
        // No fonts are bundled by default, so both should fall back — but the
        // contract is only that it does not crash and reports a note.
        _ = result.mono
        _ = result.ui
        _ = GridFont.mono(size: 17, weight: .bold)
        _ = GridFont.ui(size: 15)
        #expect(!GridFont.registrationNote.isEmpty)
    }

    // MARK: - View construction (forces body type-check)

    @Test("Components build")
    func components() {
        _ = AnyView(CyberpunkBackground(pulseIntensity: 0.5))
        _ = AnyView(ScanLinesView())
        _ = AnyView(CircuitPatternView())
        _ = AnyView(Text("glow").neonGlow())
        _ = AnyView(GlassCard { Text("card") })
        _ = AnyView(GlassCard(accent: GridBaseColors.cyan) { Text("card") })
        _ = AnyView(GlassButton("tap", systemImage: "play.fill") {})
        _ = AnyView(GlassButton("del", role: .destructive) {})
        _ = AnyView(Text("x").buttonStyle(GlassButtonStyle()).opacity(1))
        _ = AnyView(ProgressRing(progress: 0.42))
        _ = AnyView(ProgressRing(progress: 1.5, accent: .purple) { Text("A2") })
    }

    @Test("ProgressRing clamps progress to 0...1")
    func progressClamps() {
        let over = ProgressRing(progress: 2.0)
        let under = ProgressRing(progress: -1.0)
        #expect(over.progress == 1.0)
        #expect(under.progress == 0.0)
    }
}
