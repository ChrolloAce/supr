import SwiftUI
import UIKit

// MARK: - Palette

/// Warm greys with a single purple accent. No stark black, no blinding white.
enum Ink {
    static let bg = Color(hex: 0x141417)
    static let card = Color(hex: 0x1D1D22)
    static let cardAlt = Color(hex: 0x26262C)
    static let raised = Color(hex: 0x32323A)
    static let cream = Color(hex: 0x241E33)

    /// Borders are a soft grey now, not a hard bone outline.
    static let line = Color(hex: 0x3A3A44)
    static let lineHi = Color(hex: 0x53535F)

    static let shadow = Color(hex: 0x000000)

    static let text = Color(hex: 0xE9E9EE)
    static let dim = Color(hex: 0x9E9EAA)
    static let faint = Color(hex: 0x74747F)
    static let ghost = Color(hex: 0x55555F)

    /// Purple. The only hue in the app.
    static let accent = Color(hex: 0x8B5CF6)
    static let accentSoft = Color(hex: 0xA78BFA)
    static let accentDeep = Color(hex: 0x4C1D95)

    /// Completed states read as a light grey, not a second hue.
    static let done = Color(hex: 0xC9C9D4)

    /// Text drawn on top of a filled accent block.
    static let onAccent = Color(hex: 0x141417)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Geometry

enum R {
    static let card: CGFloat = 14
    static let tile: CGFloat = 12
    static let chip: CGFloat = 10
    static let badge: CGFloat = 7
    static let pill: CGFloat = 999
}

enum Line {
    static let hair: CGFloat = 1
    static let bold: CGFloat = 1.5
    /// Only buttons and the dock keep an offset block behind them.
    static let drop: CGFloat = 3
}

// MARK: - Type

/// Condensed heavy grotesk. Headlines, numbers, anything that should shout.
enum Disp {
    static func font(_ size: CGFloat, _ weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

/// Everyday interface type.
enum UI {
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension View {
    /// Uppercase, tracked label.
    func label(_ size: CGFloat = 11, _ weight: Font.Weight = .bold, tracking: CGFloat = 0.8) -> some View {
        self.font(UI.font(size, weight))
            .tracking(tracking)
            .textCase(.uppercase)
    }

    func display(_ size: CGFloat = 28, _ weight: Font.Weight = .black) -> some View {
        self.font(Disp.font(size, weight))
            .textCase(.uppercase)
    }
}

// MARK: - Surfaces

/// The signature block: flat fill, hard black outline, hard offset shadow.
struct BrutalBlock: ViewModifier {
    var fill: Color
    var radius: CGFloat
    var border: Color
    var width: CGFloat
    var drop: CGFloat
    var shadowColor: Color

    func body(content: Content) -> some View {
        content
            // Fill first, then clip so edge to edge content keeps the rounded corners.
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(shadowColor)
                    .offset(x: drop, y: drop)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border, lineWidth: width)
            )
            // Reserve room so the shadow never lands on the next element.
            .padding(.trailing, drop)
            .padding(.bottom, drop)
    }
}

extension View {
    /// Standard card: white, black outline, black hard shadow.
    func card(
        _ fill: Color = Ink.card,
        radius: CGFloat = R.card,
        border: Color = Ink.line,
        width: CGFloat = Line.bold,
        drop: CGFloat = 0,
        shadow: Color = Ink.shadow
    ) -> some View {
        modifier(BrutalBlock(fill: fill, radius: radius, border: border, width: width, drop: drop, shadowColor: shadow))
    }

    /// Outlined only, no drop shadow. For nested rows and chips.
    func outlined(_ fill: Color = Ink.card, radius: CGFloat = R.chip, width: CGFloat = Line.bold, border: Color = Ink.line) -> some View {
        self.background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(border, lineWidth: width))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Background

struct Backdrop: View {
    var body: some View {
        Ink.bg.ignoresSafeArea()
    }
}

// MARK: - Haptics

/// A barely there wash of the rarity colour, so a wall of cards has variety
/// without turning into a colour chart.
extension Rarity {
    /// A wash of the tier colour on the card, kept far enough down that a grid
    /// of them still reads as one collection rather than a colour chart.
    var cardFill: Color {
        self == .common ? Ink.card : Catalog.blend(hexTint, toward: 0x1D1D22, amount: 0.88)
    }

    /// The plate behind the car, light so the render sits on something clean.
    var plateFill: Color {
        self == .common ? Ink.cardAlt : Catalog.blend(0xFFFFFF, toward: 0x26262C, amount: 0.93)
    }

    /// The tinted strip under the car, and the ink that sits on it.
    var bandFill: Color {
        switch self {
        case .common: return Catalog.blend(0xFFFFFF, toward: 0x1D1D22, amount: 0.94)
        case .uncommon: return Catalog.blend(hexTint, toward: 0x1D1D22, amount: 0.55)
        case .rare: return Catalog.blend(hexTint, toward: 0x1D1D22, amount: 0.45)
        case .exotic: return Catalog.blend(hexTint, toward: 0x1D1D22, amount: 0.32)
        case .legendary: return Catalog.blend(hexTint, toward: 0x14141A, amount: 0.26)
        }
    }

    var bandInk: Color { self == .common ? Ink.dim : .white }

    var edge: Color {
        switch self {
        case .common: return Ink.line
        case .uncommon: return color.opacity(0.35)
        default: return color.opacity(0.55)
        }
    }

    // MARK: Rarity dressed furniture
    //
    // The tier colours the things that are meant to catch the eye and nothing
    // else: the frame and brackets around the photo, and the buttons. Cards,
    // tiles and rules stay the ordinary greys, so a legendary reads as gold
    // highlights on the usual page rather than a gold page.

    /// Full strength outline for the hero frame and its brackets. Common stays
    /// grey, because a grey car should not be dressed up as an event.
    var frame: Color { self == .common ? Ink.lineHi : color }

    /// Outline for a rarity dressed button. Close to the face it sits on, so
    /// the edge reads as a lip rather than a second colour.
    var trim: Color {
        self == .common ? Ink.line : Catalog.blend(hexTint, toward: 0x1D1D22, amount: 0.3)
    }

    /// The slab under a rarity dressed button. The same hue a few steps down,
    /// never far enough to read as a black block behind the button.
    var slab: Color {
        self == .common ? Ink.raised : Catalog.blend(hexTint, toward: 0x1D1D22, amount: 0.45)
    }

    /// The packed value behind `color`, for blending.
    private var hexTint: UInt32 {
        switch self {
        case .common: return 0x6B6B76
        case .uncommon: return 0x3FA37A
        case .rare: return 0x8B5CF6
        case .exotic: return 0xE5484D
        case .legendary: return 0xE8A317
        }
    }
}

enum Buzz {
    static func tap() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7) }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func win() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func nope() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
