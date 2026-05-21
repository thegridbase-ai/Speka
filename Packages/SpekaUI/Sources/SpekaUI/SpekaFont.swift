import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - SpekaFont

/// "Sunny Studio" typography helper for SPEKA.
///
/// UI text uses the system rounded face (`.system(design: .rounded)`) — warm,
/// legible, and free. Display text (big hero / title moments) uses **Fredoka**
/// (SIL OFL), a chunky rounded display family bundled as a package resource.
/// Registration mirrors `GridFont`'s safe-fallback pattern: the bundled
/// `.ttf` is registered with CoreText on first use, and if it is missing the
/// helper falls back gracefully to a heavy `.system(design: .rounded)` weight
/// (no crash, no hard-fail).
///
/// Inspect ``isDisplayRegistered`` to know which path was taken, or read
/// ``registrationNote`` for a human-readable summary.
///
/// There is **no monospace** anywhere in SpekaUI — that is GridBaseUIKit's
/// language, not the Sunny Studio one.
///
/// Marked `@MainActor`: registration touches UIKit/AppKit font managers and
/// keeps a one-time registration flag, so it must run on the main actor.
@MainActor
public enum SpekaFont {

    /// PostScript family name we look for once the display font is registered.
    public static let displayFamilyName = "Fredoka"

    /// Candidate resource file stems searched inside the package bundle.
    private static let displayCandidates = [
        "Fredoka-VariableFont", "Fredoka", "Fredoka-Regular"
    ]
    private static let fontExtensions = ["ttf", "otf"]

    /// Whether Fredoka was successfully registered from bundled files.
    public private(set) static var isDisplayRegistered = false

    private static var didRegister = false

    /// Registers the bundled Fredoka display font. Idempotent and safe to call
    /// repeatedly (e.g. from an `.onAppear` or app init).
    @discardableResult
    public static func registerFonts() -> Bool {
        guard !didRegister else { return isDisplayRegistered }
        didRegister = true
        isDisplayRegistered = register(candidates: displayCandidates)
        return isDisplayRegistered
    }

    /// Human-readable summary of what was registered vs. fell back.
    public static var registrationNote: String {
        if !didRegister {
            return "SpekaFont: registerFonts() not yet called — using fallbacks."
        }
        let display = isDisplayRegistered
            ? "Fredoka"
            : "system rounded heavy (fallback)"
        return "SpekaFont: display → \(display); ui → system rounded."
    }

    // MARK: - Type scale

    /// The canonical SPEKA type scale. UI styles use the system rounded face;
    /// display styles route through ``display(size:weight:)`` so they pick up
    /// Fredoka when registered.
    public enum Style {
        case displayHero   // 40 bold   (display)
        case displayTitle  // 28 bold   (display)
        case title         // 22 bold
        case headline      // 18 semibold
        case body          // 16 medium
        case callout       // 15 semibold
        case subhead       // 14 regular
        case caption       // 13 regular
        case label         // 11 bold uppercase, +0.5 tracking
        case numberXL      // 34 bold   (display, tabular)
        case numberMD      // 22 bold   (display, tabular)

        var size: CGFloat {
            switch self {
            case .displayHero: return 40
            case .displayTitle: return 28
            case .title: return 22
            case .headline: return 18
            case .body: return 16
            case .callout: return 15
            case .subhead: return 14
            case .caption: return 13
            case .label: return 11
            case .numberXL: return 34
            case .numberMD: return 22
            }
        }

        var weight: Font.Weight {
            switch self {
            case .displayHero, .displayTitle, .title, .label,
                 .numberXL, .numberMD: return .bold
            case .headline, .callout: return .semibold
            case .body: return .medium
            case .subhead, .caption: return .regular
            }
        }

        /// Whether this style should route through the Fredoka display face.
        var isDisplay: Bool {
            switch self {
            case .displayHero, .displayTitle, .numberXL, .numberMD: return true
            default: return false
            }
        }
    }

    /// Returns the `Font` for a scale ``Style``.
    public static func font(_ style: Style) -> Font {
        if style.isDisplay {
            return display(size: style.size, weight: style.weight)
        }
        return .system(size: style.size, weight: style.weight, design: .rounded)
    }

    /// Tracking (letter spacing) recommended for a style; non-zero only for
    /// the all-caps ``Style/label``.
    public static func tracking(_ style: Style) -> CGFloat {
        style == .label ? 0.5 : 0
    }

    /// Whether a style's text should be uppercased by the caller.
    public static func isUppercased(_ style: Style) -> Bool {
        style == .label
    }

    // MARK: - Font factories

    /// Display font — Fredoka if registered, else a heavy system rounded face.
    public static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        registerFonts()
        if isDisplayRegistered, fontFamilyExists(displayFamilyName) {
            return .custom(displayFamilyName, size: size).weight(weight)
        }
        // Fallback: the chunkiest rounded system weight reads closest to
        // Fredoka's display character.
        let fallbackWeight: Font.Weight = weight == .bold ? .heavy : weight
        return .system(size: size, weight: fallbackWeight, design: .rounded)
    }

    /// UI font — always the system rounded face (warm, legible, free).
    public static func ui(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
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

// MARK: - View sugar

public extension View {
    /// Applies a SPEKA type-scale ``SpekaFont/Style`` — sets the font and the
    /// recommended tracking in one call. (Uppercasing for `.label` is left to
    /// the caller via `Text(...).textCase(.uppercase)` when desired.)
    @MainActor
    func spekaFont(_ style: SpekaFont.Style) -> some View {
        self
            .font(SpekaFont.font(style))
            .tracking(SpekaFont.tracking(style))
    }
}
