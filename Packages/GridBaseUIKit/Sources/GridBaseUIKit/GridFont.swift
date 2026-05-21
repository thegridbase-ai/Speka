import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - GridFont

/// GridBase typography helper.
///
/// The web design language pairs **JetBrains Mono** (code / numerics) with
/// **General Sans** (UI). When the matching `.ttf`/`.otf` files are bundled
/// with the package resources they are registered with CoreText on first
/// use; when they are absent the helper falls back gracefully to the system
/// monospaced and default fonts (no crash, no hard-fail).
///
/// Inspect ``isMonoRegistered`` / ``isUIRegistered`` to know which path was
/// taken, or read ``registrationNote`` for a human-readable summary.
///
/// Marked `@MainActor`: registration touches UIKit/AppKit font managers and
/// keeps a one-time registration flag, so it must run on the main actor.
@MainActor
public enum GridFont {

    /// PostScript family name we look for once the mono font is registered.
    public static let monoFamilyName = "JetBrains Mono"
    /// PostScript family name we look for once the UI font is registered.
    public static let uiFamilyName = "General Sans"

    /// Candidate resource file stems searched inside the package bundle.
    private static let monoCandidates = [
        "JetBrainsMono-Regular", "JetBrainsMono", "JetBrainsMono-Variable"
    ]
    private static let uiCandidates = [
        "GeneralSans-Regular", "GeneralSans", "GeneralSans-Variable"
    ]
    private static let fontExtensions = ["ttf", "otf"]

    /// Whether JetBrains Mono was successfully registered from bundled files.
    public private(set) static var isMonoRegistered = false
    /// Whether General Sans was successfully registered from bundled files.
    public private(set) static var isUIRegistered = false

    private static var didRegister = false

    /// Registers any bundled GridBase fonts. Idempotent and safe to call
    /// repeatedly (e.g. from an `.onAppear` or app init).
    @discardableResult
    public static func registerFonts() -> (mono: Bool, ui: Bool) {
        guard !didRegister else { return (isMonoRegistered, isUIRegistered) }
        didRegister = true
        isMonoRegistered = register(candidates: monoCandidates)
        isUIRegistered = register(candidates: uiCandidates)
        return (isMonoRegistered, isUIRegistered)
    }

    /// Human-readable summary of what was registered vs. fell back.
    public static var registrationNote: String {
        if !didRegister {
            return "GridFont: registerFonts() not yet called — using fallbacks."
        }
        let mono = isMonoRegistered ? "JetBrains Mono" : "system monospaced (fallback)"
        let ui = isUIRegistered ? "General Sans" : "system default (fallback)"
        return "GridFont: mono → \(mono); ui → \(ui)."
    }

    // MARK: Font factories

    /// Monospaced font — JetBrains Mono if registered, else system monospaced.
    public static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        registerFonts()
        if isMonoRegistered, fontFamilyExists(monoFamilyName) {
            return .custom(monoFamilyName, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    /// UI font — General Sans if registered, else the system default.
    public static func ui(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        registerFonts()
        if isUIRegistered, fontFamilyExists(uiFamilyName) {
            return .custom(uiFamilyName, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    // MARK: - Internals

    private static func register(candidates: [String]) -> Bool {
        for stem in candidates {
            for ext in fontExtensions {
                guard let url = Bundle.module.url(forResource: stem, withExtension: ext) else {
                    continue
                }
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    return true
                }
                // Already-registered counts as success.
                if let err = error?.takeUnretainedValue() {
                    let domain = CFErrorGetDomain(err)
                    let code = CFErrorGetCode(err)
                    if domain == kCTFontManagerErrorDomain as CFString,
                       code == CTFontManagerError.alreadyRegistered.rawValue {
                        return true
                    }
                }
            }
        }
        return false
    }

    private static func fontFamilyExists(_ family: String) -> Bool {
        #if canImport(UIKit)
        return !UIFont.fontNames(forFamilyName: family).isEmpty
        #elseif canImport(AppKit)
        return NSFontManager.shared.availableFontFamilies.contains(family)
        #else
        return false
        #endif
    }
}
