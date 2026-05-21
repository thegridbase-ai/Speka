import SwiftUI

// MARK: - SpekaButton variant

/// The visual variant of a ``SpekaButton`` / ``SpekaButtonStyle``.
public enum SpekaButtonVariant: Equatable, Sendable {
    /// Accent-gradient face (`base → partner`) on a darker `edge` lip — the
    /// default 3D button. Per-mode CTAs use their mode accent here.
    case filled(SpekaAccent)
    /// The hero CTA: the three-stop **brand gradient** face on a darkened lip.
    case brand
    /// White face with an accent (or border) outline and `textPrimary` label.
    case ghost(SpekaAccent)
    /// Inert sunken look: `surfaceSunken` face, `textTertiary` label, no lip.
    case disabled
}

// MARK: - SpekaButtonStyle

/// The Duolingo-style **3D push button** for SPEKA.
///
/// A `ZStack(alignment: .bottom)` places a darker `edge`-colored rounded rect
/// (offset down by ``depth``) behind the colored face. While pressed, the face
/// slides down by `depth` so it "compresses" flush onto the lip, with a snappy
/// spring. Exposed as a `ButtonStyle` so any `Button` label can adopt the look.
public struct SpekaButtonStyle: ButtonStyle {
    public var variant: SpekaButtonVariant
    public var depth: CGFloat
    public var cornerRadius: CGFloat
    /// When `true`, uses a `Capsule` shape instead of a rounded rectangle.
    public var capsule: Bool
    public var fullWidth: Bool

    public init(
        variant: SpekaButtonVariant = .filled(.coral),
        depth: CGFloat = 5,
        cornerRadius: CGFloat = 16,
        capsule: Bool = false,
        fullWidth: Bool = false
    ) {
        self.variant = variant
        self.depth = depth
        self.cornerRadius = cornerRadius
        self.capsule = capsule
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isInteractive
        let label = configuration.label
            .font(SpekaFont.font(.callout))
            .fontWeight(.bold)
            .foregroundStyle(faceTextColor)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil)

        // Single concrete shape (AnyShape) so the lip, clip and border all
        // share the same geometry.
        let face = capsule
            ? AnyShape(Capsule(style: .continuous))
            : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        return ZStack(alignment: .bottom) {
            // Shadow lip — only for the raised (filled / ghost) variants.
            if hasLip {
                face
                    .fill(lipColor)
                    .padding(.top, depth)
            }

            // Colored face. Slides down onto the lip while pressed.
            label
                .background(faceBackground)
                .clipShape(face)
                .overlay {
                    if case .ghost = variant {
                        face.stroke(ghostBorderColor, lineWidth: 2)
                    }
                }
                .offset(y: pressed ? depth : 0)
        }
        // The lip is a flexible `Shape.fill()`; without this the button would
        // stretch to any excess height it's offered (e.g. a fullWidth button in
        // a footer alongside a ScrollView), ballooning into a giant block. Pin
        // the height to the label's intrinsic size; keep horizontal flexible.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, hasLip ? depth : 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }

    // MARK: Derived appearance

    private var isInteractive: Bool {
        if case .disabled = variant { return false }
        return true
    }

    private var hasLip: Bool {
        switch variant {
        case .filled, .brand, .ghost: return true
        case .disabled: return false
        }
    }

    @ViewBuilder
    private var faceBackground: some View {
        switch variant {
        case .filled(let accent):
            accent.gradient
        case .brand:
            SpekaColor.brandGradient
        case .ghost:
            SpekaColor.surface
        case .disabled:
            SpekaColor.surfaceSunken
        }
    }

    private var lipColor: Color {
        switch variant {
        case .filled(let accent): return accent.edge
        case .brand: return SpekaColor.brandEdge
        case .ghost: return SpekaColor.borderStrong
        case .disabled: return .clear
        }
    }

    private var ghostBorderColor: Color {
        if case .ghost(let accent) = variant {
            return accent.base.opacity(0.45)
        }
        return SpekaColor.border
    }

    private var faceTextColor: Color {
        switch variant {
        case .filled, .brand: return SpekaColor.onColor
        case .ghost: return SpekaColor.textPrimary
        case .disabled: return SpekaColor.textTertiary
        }
    }
}

// MARK: - SpekaButton

/// A ready-made SPEKA 3D button. Wraps a `Button` in ``SpekaButtonStyle`` and
/// adds a light press `.sensoryFeedback`.
///
/// ```swift
/// SpekaButton("Check", variant: .filled(.mint)) { check() }
/// SpekaButton("Skip", variant: .ghost(.sky)) { skip() }
/// SpekaButton("Locked", variant: .disabled) {}
/// ```
public struct SpekaButton: View {
    private let title: String
    private let systemImage: String?
    private let variant: SpekaButtonVariant
    private let capsule: Bool
    private let fullWidth: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        variant: SpekaButtonVariant = .filled(.coral),
        capsule: Bool = false,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.capsule = capsule
        self.fullWidth = fullWidth
        self.action = action
    }

    public var body: some View {
        Button {
            feedbackToggle.toggle()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .fontWeight(.bold)
                }
                Text(title)
            }
        }
        .buttonStyle(
            SpekaButtonStyle(
                variant: variant,
                capsule: capsule,
                fullWidth: fullWidth
            )
        )
        .disabled(isDisabled)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackToggle)
    }

    private var isDisabled: Bool {
        if case .disabled = variant { return true }
        return false
    }

    // Flipped on each tap so the press `.sensoryFeedback` fires.
    @State private var feedbackToggle = false
}

#Preview("SpekaButton") {
    ZStack {
        SpekaBackground()
        VStack(spacing: 22) {
            SpekaButton("Continue", systemImage: "play.fill", variant: .brand, fullWidth: true) {}
                .padding(.horizontal, 32)
            SpekaButton("Check", systemImage: "checkmark", variant: .filled(.mint)) {}
            SpekaButton("Kontrol et", variant: .filled(.sky), fullWidth: true) {}
                .padding(.horizontal, 32)
            SpekaButton("Skip", variant: .ghost(.sky)) {}
            SpekaButton("Locked", systemImage: "lock.fill", variant: .disabled) {}
            SpekaButton("Capsule", variant: .filled(.lavender), capsule: true) {}
        }
    }
}
