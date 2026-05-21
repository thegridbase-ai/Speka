import SwiftUI

// MARK: - StreakBadge

/// A streak counter tile: a tangerine rounded tile with a pulsing flame and a
/// big bold day count. The flame uses `.symbolEffect(.pulse, options:
/// .repeating)`; the count uses the display number scale.
///
/// ```swift
/// StreakBadge(days: 12)
/// ```
public struct StreakBadge: View {
    public var days: Int

    public init(days: Int) {
        self.days = days
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(SpekaColor.onColor)
                .symbolEffect(.pulse, options: .repeating)

            Text("\(days)")
                .font(SpekaFont.font(.numberXL))
                .foregroundStyle(SpekaColor.onColor)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpekaAccent.tangerine.base)
        }
        .shadow(color: SpekaAccent.tangerine.edge.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

// MARK: - XPBadge

/// An XP pill: a sunflower capsule with a star and an animating count.
/// The count animates via `.contentTransition(.numericText())`.
///
/// ```swift
/// XPBadge(xp: 1280)
/// ```
public struct XPBadge: View {
    public var xp: Int

    public init(xp: Int) {
        self.xp = xp
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .bold))
            Text("\(xp)")
                .font(SpekaFont.font(.callout))
                .fontWeight(.bold)
                .contentTransition(.numericText())
        }
        .foregroundStyle(SpekaColor.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(SpekaAccent.sunflower.base)
        }
    }
}

// MARK: - LevelBadge

/// A level chip: a rounded-square (or hexagon) tile in an accent, holding a big
/// bold letter. The locked state renders a `surfaceSunken` tile with a lock.
///
/// ```swift
/// LevelBadge(letter: "A", accent: .mint)
/// LevelBadge(letter: "C", accent: .bubblegum, isLocked: true)
/// LevelBadge(letter: "B", accent: .sky, shape: .hexagon)
/// ```
public struct LevelBadge: View {

    /// The outline shape of the badge tile.
    public enum BadgeShape: Sendable {
        case roundedSquare
        case hexagon
    }

    public var letter: String
    public var accent: SpekaAccent
    public var isLocked: Bool
    public var shape: BadgeShape
    public var size: CGFloat
    /// Optional gradient stops; when non-nil the tile fills with this gradient
    /// (e.g. ``SpekaColor/brandStops`` for the on-level CEFR chip).
    public var gradientStops: [Color]?

    public init(
        letter: String,
        accent: SpekaAccent = .coral,
        isLocked: Bool = false,
        shape: BadgeShape = .roundedSquare,
        size: CGFloat = 56,
        gradientStops: [Color]? = nil
    ) {
        self.letter = letter
        self.accent = accent
        self.isLocked = isLocked
        self.shape = shape
        self.size = size
        self.gradientStops = gradientStops
    }

    public var body: some View {
        ZStack {
            tile

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(SpekaColor.textTertiary)
            } else {
                Text(letter)
                    .font(SpekaFont.display(size: size * 0.5))
                    .foregroundStyle(SpekaColor.onColor)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var tile: some View {
        switch shape {
        case .roundedSquare:
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(tileFill)
        case .hexagon:
            HexagonShape()
                .fill(tileFill)
        }
    }

    /// The tile fill: sunken when locked, a gradient when `gradientStops` is
    /// supplied, otherwise the solid `accent.base`.
    private var tileFill: AnyShapeStyle {
        if isLocked {
            return AnyShapeStyle(SpekaColor.surfaceSunken)
        }
        if let stops = gradientStops, stops.count >= 2 {
            return AnyShapeStyle(
                LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        return AnyShapeStyle(accent.base)
    }
}

// MARK: - Hexagon

/// A flat-top regular hexagon used by ``LevelBadge``.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let qx = w * 0.25
        return Path { p in
            p.move(to: CGPoint(x: qx, y: 0))
            p.addLine(to: CGPoint(x: w - qx, y: 0))
            p.addLine(to: CGPoint(x: w, y: h / 2))
            p.addLine(to: CGPoint(x: w - qx, y: h))
            p.addLine(to: CGPoint(x: qx, y: h))
            p.addLine(to: CGPoint(x: 0, y: h / 2))
            p.closeSubpath()
        }
    }
}

#Preview("Badges") {
    ZStack {
        SpekaBackground()
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                StreakBadge(days: 12)
                XPBadge(xp: 1280)
            }
            HStack(spacing: 12) {
                LevelBadge(letter: "A", accent: .mint)
                LevelBadge(letter: "B", accent: .sky, shape: .hexagon)
                LevelBadge(letter: "C", accent: .bubblegum, isLocked: true)
            }
        }
        .padding(24)
    }
}
