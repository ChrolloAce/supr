import SwiftUI

// MARK: - Sheen

/// A blade coming out of its sheath: a hard band of light that travels across a
/// face, then waits before doing it again. The pause is the whole trick. A
/// highlight that never stops reads as a loading shimmer and the eye tunes it
/// out, while one that glints every couple of seconds keeps asking to be
/// pressed. Only worn by the one button on screen that wants the tap.
struct Sheen: View {
    var tint: Color = .white
    /// Seconds from the start of one sweep to the start of the next.
    var period: Double = 2.4
    /// How long the band takes to cross. Short enough to read as a glint.
    var duration: Double = 0.62
    /// Off vertical, so it rakes across the face like a drawn edge.
    var angle: Double = 18

    @State private var travel: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let band = max(w * 0.26, 40)

            LinearGradient(
                // Peak stays well under 1: plus lighter over a filled face
                // blows straight out to white, and a blown out band reads as a
                // glitch rather than a polished edge.
                colors: [
                    tint.opacity(0),
                    tint.opacity(0.16),
                    tint.opacity(0.5),
                    tint.opacity(0.16),
                    tint.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            // Tall enough that tilting it still covers the corners.
            .frame(width: band, height: h * 3)
            .rotationEffect(.degrees(angle))
            .offset(x: -band + travel * (w + band * 2), y: -h)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .onAppear(perform: sweep)
        .onReceive(Timer.publish(every: period, on: .main, in: .common).autoconnect()) { _ in
            sweep()
        }
    }

    private func sweep() {
        // Snapping back to the start must not animate, or the band visibly
        // rewinds across the button between glints.
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { travel = 0 }
        withAnimation(.easeInOut(duration: duration)) { travel = 1 }
    }
}

// MARK: - Buttons

/// Filled block button with a hard outline and an offset slab underneath, which
/// it presses down into. Same move the onboarding call to action makes, so every
/// button in the app speaks one language instead of the flat fill it used to.
struct BlockButtonStyle: ButtonStyle {
    var fill: Color = Ink.accent
    var textColor: Color = .white
    var height: CGFloat = 54
    var drop: CGFloat = 4
    /// The slab under the face. Rarity dressed buttons pass their own.
    var slab: Color = Ink.raised
    var border: Color = Ink.line
    var textFont: Font = UI.font(14, .semibold)
    /// Opt in, never on by default. Two glinting buttons on one screen cancel
    /// each other out.
    var shine: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: R.chip, style: .continuous)
        return configuration.label
            .font(textFont)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(shape.fill(fill))
            // Above the fill so it lights the face, under the border so the
            // outline stays hard.
            .overlay { if shine { Sheen().clipShape(shape) } }
            .overlay(shape.strokeBorder(border, lineWidth: Line.bold))
            // Drawn as a background so the slab can never claim more room than
            // the face sitting on top of it.
            .background(shape.fill(slab).offset(x: down ? 1 : drop, y: down ? 1 : drop))
            .offset(x: down ? drop - 1 : 0, y: down ? drop - 1 : 0)
            .padding(.trailing, drop)
            .padding(.bottom, drop)
            .animation(.easeOut(duration: 0.08), value: down)
    }
}

/// The onboarding call to action. Same family as the flat block button but with
/// a hard offset slab under it, condensed display type at the size the garage
/// headings use, and an arrow so it always reads as forward motion.
struct SlabButtonStyle: ButtonStyle {
    var fill: Color = Ink.accent
    var textColor: Color = .white
    var height: CGFloat = 62
    var drop: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        return HStack(spacing: 12) {
            configuration.label
                .font(Disp.font(24, .black))
                .tracking(0.5)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Image(systemName: "arrow.right")
                .font(.system(size: 17, weight: .black))
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(fill))
        .overlay(
            RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                .strokeBorder(Ink.line, lineWidth: 1.5)
        )
        // The slab underneath is drawn as a background, so it can never take
        // more room than the face it sits behind.
        .background(
            RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                .fill(Ink.raised)
                .offset(x: down ? 1 : drop, y: down ? 1 : drop)
        )
        .offset(x: down ? drop - 1 : 0, y: down ? drop - 1 : 0)
        .padding(.trailing, drop)
        .padding(.bottom, drop)
        .animation(.easeOut(duration: 0.08), value: down)
    }
}

extension ButtonStyle where Self == SlabButtonStyle {
    /// Purple slab, the forward action in onboarding.
    static var slab: SlabButtonStyle { SlabButtonStyle() }
    /// Same shape in card grey, for a secondary step.
    static var slabQuiet: SlabButtonStyle {
        SlabButtonStyle(fill: Ink.cardAlt, textColor: Ink.text)
    }
}

extension ButtonStyle where Self == BlockButtonStyle {
    /// Purple call to action.
    static var primary: BlockButtonStyle {
        BlockButtonStyle(fill: Ink.accent, textColor: .white, slab: Ink.accentDeep)
    }
    /// The same call to action, glinting. For the one button on a screen that
    /// the whole screen exists to get pressed.
    static var primaryShine: BlockButtonStyle {
        BlockButtonStyle(fill: Ink.accent, textColor: .white, slab: Ink.accentDeep, shine: true)
    }
    /// Secondary action in card grey.
    static var accent: BlockButtonStyle {
        BlockButtonStyle(fill: Ink.cardAlt, textColor: Ink.text, slab: Ink.raised)
    }
    /// Tertiary action, quietest of the three.
    static var ghost: BlockButtonStyle {
        BlockButtonStyle(fill: Ink.card, textColor: Ink.text, slab: Ink.cardAlt)
    }
    /// Inverted action.
    static var dark: BlockButtonStyle {
        BlockButtonStyle(fill: Ink.line, textColor: Ink.onAccent, slab: Ink.card)
    }

    /// The button wearing a catch's tier. A legendary gets a gold face on a
    /// darker gold slab, so the action at the bottom of a card matches the
    /// frame around the photo at the top.
    static func rarity(_ rarity: Rarity, shine: Bool = false) -> BlockButtonStyle {
        BlockButtonStyle(
            fill: rarity.color,
            textColor: rarity.onColor,
            slab: rarity.slab,
            border: rarity.trim,
            shine: shine
        )
    }

    /// Same tier, worn quietly: the ordinary card face with the tier only on
    /// the outline. For the second action in a pair, next to a filled one.
    static func rarityQuiet(_ rarity: Rarity) -> BlockButtonStyle {
        BlockButtonStyle(
            fill: Ink.cardAlt,
            textColor: Ink.text,
            slab: Ink.raised,
            border: rarity.frame.opacity(0.5)
        )
    }
}

/// Square icon button with the same hard outline and slab as the block buttons.
struct IconButton: View {
    let icon: String
    var size: CGFloat = 40
    var fill: Color = Ink.card
    var tint: Color = Ink.text
    var slab: Color = Ink.cardAlt
    var border: Color = Ink.line
    var filled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Buzz.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(SlabTileStyle(fill: fill, slab: slab, border: border))
    }
}

/// The block button treatment on a fixed size tile: hard outline, hard slab,
/// presses into it. Icon buttons and chips share it so nothing in the app is
/// a flat rectangle any more.
struct SlabTileStyle: ButtonStyle {
    var fill: Color = Ink.card
    var slab: Color = Ink.cardAlt
    var border: Color = Ink.line
    var radius: CGFloat = R.chip
    var drop: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: Line.bold))
            .background(shape.fill(slab).offset(x: down ? 1 : drop, y: down ? 1 : drop))
            .offset(x: down ? drop - 1 : 0, y: down ? drop - 1 : 0)
            .padding(.trailing, drop)
            .padding(.bottom, drop)
            .animation(.easeOut(duration: 0.08), value: down)
    }
}

// MARK: - Header

struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .display(26)
                .foregroundStyle(Ink.text)
            Spacer()
            HStack(spacing: 9) { trailing }
        }
        .frame(height: 52)
    }
}

// MARK: - Segmented control

struct Segmented: View {
    let items: [String]
    @Binding var index: Int
    var activeFill: Color = Ink.accent
    var activeText: Color = .white

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                Button {
                    Buzz.tap()
                    withAnimation(.easeOut(duration: 0.15)) { index = i }
                } label: {
                    Text(item)
                        .font(UI.font(13, .semibold))
                        .foregroundStyle(index == i ? activeText : Ink.faint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                }
                // The selected tab sits proud on a slab, the rest keep the same
                // footprint with nothing drawn behind them.
                .buttonStyle(SlabTileStyle(
                    fill: index == i ? activeFill : Ink.card,
                    slab: index == i ? Ink.raised : .clear,
                    border: Ink.line
                ))
            }
        }
    }
}

/// Standalone chip used in filter rows.
struct FilterChip: View {
    let text: String
    let count: Int?
    var active: Bool
    var dot: Color? = nil

    var body: some View {
        HStack(spacing: 7) {
            if let dot {
                Circle()
                    .fill(dot)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(Ink.line, lineWidth: 1.2))
            }
            Text(text)
                .label(11, .heavy, tracking: 0.5)
                .foregroundStyle(active ? Ink.onAccent : Ink.text)
            if let count {
                Text("\(count)")
                    .label(11, .bold, tracking: 0)
                    .foregroundStyle(active ? Ink.onAccent.opacity(0.6) : Ink.faint)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .card(active ? Ink.accentSoft : Ink.card,
              radius: R.chip,
              border: Ink.line,
              drop: 3,
              shadow: active ? Ink.accentDeep : Ink.cardAlt)
    }
}

struct DropdownPill: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button {
            Buzz.tap()
            action()
        } label: {
            HStack(spacing: 7) {
                Text(text)
                    .font(UI.font(13, .semibold))
                    .foregroundStyle(Ink.dim)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Ink.faint)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
        }
        .buttonStyle(SlabTileStyle())
    }
}

// MARK: - Section furniture

/// Yellow rule plus heavy label, the reference section head.
struct Caption: View {
    let text: String
    var trailing: String? = nil
    var arrow: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Text(text)
                .font(UI.font(13, .semibold))
                .foregroundStyle(Ink.dim)
            Spacer()
            if let trailing {
                Text(trailing)
                    .label(10, .bold, tracking: 0.6)
                    .foregroundStyle(Ink.faint)
            }
            if arrow {
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Ink.line)
            }
        }
    }
}

/// Two stats side by side split by a hard rule.
struct SplitStat<L: View, T: View>: View {
    @ViewBuilder var leading: L
    @ViewBuilder var trailing: T

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(Ink.line).frame(width: Line.hair, height: 52)
                .padding(.horizontal, 14)
            trailing.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct StatBlock: View {
    let caption: String
    let value: String
    var sub: String? = nil
    var valueColor: Color = Ink.text
    var arrow: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(caption)
                    .label(9.5, .bold, tracking: 0.8)
                    .foregroundStyle(Ink.faint)
                Spacer(minLength: 0)
                if arrow {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Ink.line)
                }
            }
            Text(value)
                .display(27)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            if let sub {
                Text(sub)
                    .label(9.5, .bold, tracking: 0.6)
                    .foregroundStyle(Ink.faint)
            }
        }
    }
}

// MARK: - Progress

struct XPBar: View {
    var progress: Double
    var height: CGFloat = 14
    var tint: Color = Ink.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Ink.cardAlt)
                Rectangle()
                    .fill(tint)
                    .frame(width: max(0, min(1, max(0, progress)) * (geo.size.width - Line.bold * 2)))
                    .padding(Line.bold)
                Rectangle().strokeBorder(Ink.line, lineWidth: Line.bold)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}

// MARK: - Rarity

struct RarityMeter: View {
    let rarity: Rarity
    var width: CGFloat = 13
    var height: CGFloat = 7

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Rectangle()
                    .fill(i < rarity.pips ? rarity.color : Ink.raised)
                    .frame(width: width, height: height)
                    .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1))
            }
        }
    }
}

/// Rarity as a five segment gauge instead of a word. Reads at a glance on a
/// card corner, and two cards can be compared without reading anything.
struct RarityBar: View {
    let rarity: Rarity
    var segment: CGSize = CGSize(width: 9, height: 4)
    var onDark: Bool = true

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i < rarity.pips ? rarity.color : (onDark ? Color.white.opacity(0.15) : Ink.raised))
                    .frame(width: segment.width, height: segment.height)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(Capsule().fill(.black.opacity(onDark ? 0.5 : 0)))
    }
}

/// Tinted band under a car photo on a collection card.
struct RarityStrip: View {
    let rarity: Rarity

    var body: some View {
        HStack {
            Text(rarity.title)
                .label(10, .heavy, tracking: 0.8)
                .foregroundStyle(rarity.onColor)
            Spacer(minLength: 6)
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Rectangle()
                        .fill(i < rarity.pips ? rarity.onColor : rarity.onColor.opacity(0.28))
                        .frame(width: 7, height: 5)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(rarity.color)
    }
}

/// Small corner tag, the reference "FEATURED" block.
struct BlockTag: View {
    let text: String
    var fill: Color = Ink.accent
    var textColor: Color = .white

    var body: some View {
        Text(text)
            .label(9.5, .heavy, tracking: 0.8)
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(fill)
            .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.5))
    }
}

// MARK: - Search

struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Ink.line)
            TextField("", text: $text, prompt: Text(placeholder).font(UI.font(13, .medium)).foregroundColor(Ink.ghost))
                .font(UI.font(14, .semibold))
                .foregroundStyle(Ink.text)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Ink.faint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .outlined()
    }
}

// MARK: - Terminal flourishes (capture scan)

struct TypeOnText: View {
    let full: String
    var speed: Double = 0.014
    var font: Font = UI.font(13, .semibold)
    var color: Color = Ink.text
    var tracking: CGFloat = 0.4

    @State private var shown = ""

    var body: some View {
        Text(shown.isEmpty ? " " : shown)
            .font(font)
            .tracking(tracking)
            .foregroundStyle(color)
            .task(id: full) {
                shown = ""
                for ch in full {
                    if Task.isCancelled { return }
                    shown.append(ch)
                    try? await Task.sleep(for: .seconds(speed))
                }
            }
    }
}

struct Caret: View {
    @State private var on = true
    var body: some View {
        Rectangle()
            .fill(Ink.accent)
            .frame(width: 8, height: 15)
            .opacity(on ? 1 : 0)
            .onAppear {
                withAnimation(.linear(duration: 0.55).repeatForever(autoreverses: false)) { on = false }
            }
    }
}

struct CornerBrackets: View {
    var color: Color = Ink.line
    var length: CGFloat = 26
    var thickness: CGFloat = 3
    var inset: CGFloat = 0

    var body: some View {
        VStack {
            HStack {
                bracket(0)
                Spacer(minLength: 0)
                bracket(90)
            }
            Spacer(minLength: 0)
            HStack {
                bracket(270)
                Spacer(minLength: 0)
                bracket(180)
            }
        }
        .padding(inset)
        .allowsHitTesting(false)
    }

    private func bracket(_ rotation: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(color).frame(width: length, height: thickness)
            Rectangle().fill(color).frame(width: thickness, height: length)
        }
        .frame(width: length, height: length, alignment: .topLeading)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Car art

/// Vector car used wherever there is no capture photo yet.
struct CarGlyph: View {
    var tint: Color = Ink.line
    var outline: Color = Ink.line
    var showsDetail: Bool = true

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 100, geo.size.height / 42)
            let ox = (geo.size.width - 100 * s) / 2
            let oy = (geo.size.height - 42 * s) / 2
            let pt = { (x: CGFloat, y: CGFloat) in CGPoint(x: ox + x * s, y: oy + y * s) }

            let bodyPath = Path { p in
                p.move(to: pt(4, 31))
                p.addLine(to: pt(9, 21))
                p.addCurve(to: pt(30, 14), control1: pt(15, 16), control2: pt(22, 14))
                p.addLine(to: pt(58, 14))
                p.addCurve(to: pt(78, 20), control1: pt(68, 14), control2: pt(73, 16))
                p.addLine(to: pt(92, 25))
                p.addCurve(to: pt(96, 31), control1: pt(95, 26), control2: pt(96, 28))
                p.addLine(to: pt(96, 33))
                p.addLine(to: pt(4, 33))
                p.closeSubpath()
            }

            ZStack {
                bodyPath.fill(tint)
                bodyPath.stroke(outline, lineWidth: max(1.2, 1.6 * s))

                if showsDetail {
                    let glass = Path { p in
                        p.move(to: pt(26, 22))
                        p.addCurve(to: pt(38, 17), control1: pt(30, 18), control2: pt(33, 17))
                        p.addLine(to: pt(56, 17))
                        p.addCurve(to: pt(70, 22), control1: pt(63, 17), control2: pt(67, 19))
                        p.closeSubpath()
                    }
                    glass.fill(Ink.bg.opacity(0.55))
                    glass.stroke(outline, lineWidth: max(1, 1.3 * s))

                    ForEach([CGFloat(28), CGFloat(76)], id: \.self) { x in
                        Circle()
                            .fill(Ink.shadow)
                            .frame(width: 13 * s, height: 13 * s)
                            .overlay(
                                Circle()
                                    .fill(Ink.raised)
                                    .frame(width: 5.5 * s, height: 5.5 * s)
                            )
                            .position(pt(x, 33))
                    }
                }
            }
        }
    }
}

/// Fills a hero area for a car with no photo. Purely typographic: no fake art,
/// no placeholder texture, just the car set large on a flat field.
struct CarPlate: View {
    let car: CarModel
    /// Drives the type scale.
    var glyphWidth: CGFloat = 120

    var body: some View {
        ZStack {
            Ink.cardAlt

            VStack(spacing: 6) {
                Text(car.make)
                    .label(glyphWidth * 0.075, .heavy, tracking: 1)
                    .foregroundStyle(Ink.accentSoft)

                Text(car.model)
                    .font(Disp.font(glyphWidth * 0.24, .black))
                    .textCase(.uppercase)
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 14)

                Text("\(car.year)  ·  \(car.body.title)")
                    .label(glyphWidth * 0.07, .bold, tracking: 0.8)
                    .foregroundStyle(Ink.faint)

                if !car.punchline.isEmpty {
                    Text(car.punchline)
                        .label(glyphWidth * 0.065, .semibold, tracking: 0.6)
                        .foregroundStyle(Ink.dim)
                        .padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - Logo

/// The SUPR mark: an S+ inside camera brackets, on a rounded tile.
///
/// Drawn from the supplied artwork as a template image, so it takes whatever
/// colour it is given and stays sharp at any size.
struct RevMark: View {
    var size: CGFloat = 34
    var fill: Color = Ink.accent
    var letter: Color = .white

    var body: some View {
        Image("supr_mark")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(letter)
            .padding(size * 0.2)
            .frame(width: size * 1.25, height: size * 1.25)
            .background(
                RoundedRectangle(cornerRadius: R.badge, style: .continuous).fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: R.badge, style: .continuous)
                    .strokeBorder(Ink.line, lineWidth: 1)
            )
    }
}

/// The mark on its own, no tile behind it.
struct SuprGlyph: View {
    var size: CGFloat = 34
    var tint: Color = Ink.text

    var body: some View {
        Image("supr_mark")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(tint)
            .frame(width: size, height: size)
    }
}

// MARK: - Empty state

struct EmptyBlock: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Ink.line)
            Text(title)
                .display(19)
                .foregroundStyle(Ink.text)
            Text(message)
                .font(UI.font(12.5))
                .foregroundStyle(Ink.faint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 26)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .card(Ink.cardAlt)
    }
}
