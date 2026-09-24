import SwiftUI

struct GarageView: View {
    @EnvironmentObject private var store: GameStore

    @State private var showProfile = false
    @State private var showActivity = false
    @State private var showDex = false
    @State private var showRanks = false
    @State private var showPaywall = false
    @State private var selected: Capture?
    @State private var filter = CollectionFilter()
    @State private var showFilter = false
    @State private var searching = false
    @State private var query = ""

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var cards: [Capture] {
        var list = store.garage.filter { filter.matches($0.car) }
        if !query.isEmpty {
            list = list.filter { $0.car.fullName.localizedCaseInsensitiveContains(query) }
        }
        return filter.sorted(list)
    }

    /// Only what is actually in the garage is offered as a filter, so no option
    /// can ever lead to an empty grid.
    private var rarityOptions: [(rarity: Rarity, count: Int)] {
        Rarity.allCases.reversed().compactMap { r in
            let n = store.garage.filter { $0.car.rarity == r }.count
            return n > 0 ? (r, n) : nil
        }
    }

    private var bodyOptions: [(type: BodyType, count: Int)] {
        BodyType.allCases.compactMap { b in
            let n = store.garage.filter { $0.car.body == b }.count
            return n > 0 ? (b, n) : nil
        }
    }

    private var makeOptions: [(name: String, count: Int)] {
        Dictionary(grouping: store.garage, by: { $0.car.make })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
    }

    var body: some View {
        ZStack {
            Backdrop()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    levelCard
                    collection
                    Spacer(minLength: Dock.clearance)
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showProfile) { ProfileView() }
        .sheet(isPresented: $showActivity) { ActivityView() }
        .sheet(isPresented: $showDex) { DexView() }
        .task {
            #if DEBUG
            // `dex` on the scheme opens the index straight away, so store
            // screenshots don't depend on a tap landing in the right place.
            if ProcessInfo.processInfo.arguments.contains("dex") { showDex = true }
            #endif
        }
        .sheet(isPresented: $showRanks) { RankLadderView() }
        .suprPaywall(.settings, isPresented: $showPaywall, context: .settings)
        .sheet(isPresented: $showFilter) {
            FilterSheet(
                filter: $filter,
                makes: makeOptions,
                bodies: bodyOptions,
                rarities: rarityOptions
            )
        }
        .sheet(item: $selected) { CarDetailView(capture: $0) }
    }

    // MARK: Header

    private var header: some View {
        ScreenHeader(title: "Garage") {
            IconButton(icon: "bell") { showActivity = true }
        }
    }

    // MARK: Level

    private var levelCard: some View {
        let p = Levels.progress(xp: store.profile.xp)
        let next = Ranks.next(after: p.level)

        return VStack(spacing: 0) {
            // Tap anywhere here to browse every rank, locked ones included.
            Button {
                Buzz.tap()
                showRanks = true
            } label: {
                HStack(spacing: 14) {
                    RankBadge(rank: store.profile.rank, size: 52)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("LV \(p.level)")
                            .display(30)
                            .foregroundStyle(Ink.text)
                        Text(store.profile.rankName)
                            .label(10.5, .heavy, tracking: 0.6)
                            .foregroundStyle(store.profile.rank.tier.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Ink.faint)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 9) {
                XPBar(progress: p.fraction)
                HStack {
                    Text("\(store.profile.xp.formatted()) XP")
                        .label(10, .bold, tracking: 0.4)
                        .foregroundStyle(Ink.dim)
                    Spacer()
                    Text(next.map { "\(p.need - p.into) XP TO \($0.name.uppercased())" } ?? "MAX RANK")
                        .label(10, .bold, tracking: 0.4)
                        .foregroundStyle(Ink.faint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            Rectangle().fill(Ink.line).frame(height: Line.bold)

            statRow
        }
        .card()
    }

    /// Three even blocks. No cramped fractions.
    private var statRow: some View {
        HStack(spacing: 0) {
            Button {
                Buzz.tap()
                showDex = true
            } label: {
                statCell("\(store.dexCount)", "of \(store.dexTotal) spotted", arrow: true)
            }
            .buttonStyle(.plain)

            Rectangle().fill(Ink.line).frame(width: Line.hair, height: 48)

            statCell(
                store.profile.streak > 0 ? "\(store.profile.streak)" : "0",
                "day streak",
                tint: store.profile.streak > 0 ? Ink.text : Ink.ghost,
                flame: store.profile.streak > 0
            )

            Rectangle().fill(Ink.line).frame(width: Line.hair, height: 48)

            statCell(
                "\(store.developedCount)",
                store.developedCount == store.captures.count && !store.captures.isEmpty
                    ? "all developed"
                    : "of \(store.captures.count) developed",
                tint: store.developedCount > 0 ? Ink.text : Ink.ghost
            )
        }
        .padding(.vertical, 15)
    }

    private func statCell(
        _ value: String,
        _ caption: String,
        tint: Color = Ink.text,
        arrow: Bool = false,
        flame: Bool = false
    ) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(value)
                    .display(26)
                    .foregroundStyle(tint)
                if flame {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF7A1A))
                }
                if arrow {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Ink.faint)
                }
            }
            Text(caption)
                .label(9, .bold, tracking: 0.5)
                .foregroundStyle(Ink.faint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: Collection

    private var collection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                Caption(text: "Collected", trailing: "\(store.garage.count)")
                Spacer(minLength: 4)
                IconButton(icon: "magnifyingglass", size: 40) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        searching.toggle()
                        if !searching { query = "" }
                    }
                }
                if store.garage.count > 3 {
                    FilterButton(filter: filter) { showFilter = true }
                }
                IconButton(icon: "square.grid.2x2.fill", size: 40) { showDex = true }
            }

            if !store.developing.isEmpty { developingBanner }

            if searching { SearchField(placeholder: "Search your garage", text: $query) }

            if filter.isActive || filter.sort != .newest { activeFilterLine }

            if store.garage.isEmpty {
                EmptyBlock(
                    icon: "car.side.fill",
                    title: "Empty garage",
                    message: "Point the camera at any car and hit the shutter. Rarer plates are worth more XP."
                )
            } else if cards.isEmpty {
                EmptyBlock(
                    icon: "line.3.horizontal.decrease",
                    title: "Nothing matches",
                    message: "No catch in your garage fits that filter."
                )
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(cards) { capture in
                        Button {
                            Buzz.tap()
                            selected = capture
                        } label: {
                            CollectionCard(capture: capture)
                        }
                        .buttonStyle(CardPressStyle())
                    }
                }
            }
        }
    }

    /// Its own row rather than a fragment wedged beside the Collected count.
    /// A render takes a minute or two, so it says so instead of leaving a
    /// spinner spinning with no explanation.
    private var developingBanner: some View {
        HStack(spacing: 11) {
            ProgressView().tint(Ink.accent).scaleEffect(0.8)

            VStack(alignment: .leading, spacing: 1) {
                Text(store.developing.count == 1
                     ? "Developing 1 catch"
                     : "Developing \(store.developing.count) catches")
                    .font(UI.font(13.5, .semibold))
                    .foregroundStyle(Ink.text)
                Text("Renders take a minute or two. You can keep using the app.")
                    .font(UI.font(11))
                    .foregroundStyle(Ink.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.card))
        .overlay(
            RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                .strokeBorder(Ink.accent.opacity(0.35), lineWidth: 1)
        )
        .transition(.opacity)
    }

    /// What the filter button is doing, in one line, with a way out of it.
    private var activeFilterLine: some View {
        HStack(spacing: 8) {
            Text(summary)
                .font(UI.font(12.5, .semibold))
                .foregroundStyle(Ink.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            Text("\(cards.count)")
                .font(UI.font(12.5, .semibold))
                .foregroundStyle(Ink.faint)

            if filter.isActive {
                Button {
                    Buzz.tap()
                    withAnimation(.easeOut(duration: 0.16)) { filter.clear() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Ink.faint)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Ink.cardAlt))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 7)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.card))
        .overlay(
            RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                .strokeBorder(Ink.line, lineWidth: 1)
        )
    }

    private var summary: String {
        var parts = [filter.sort.short]
        if let r = filter.rarity { parts.append(r.title) }
        if let b = filter.body { parts.append(b.title.capitalized) }
        if let m = filter.make { parts.append(m) }
        return parts.joined(separator: "  ·  ")
    }
}

// MARK: - Card

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

/// The photo is the card. Name sits over it, nothing else competes.
struct CollectionCard: View {
    @EnvironmentObject private var store: GameStore
    let capture: Capture

    private var car: CarModel { capture.car }
    /// Rarity earned by this vehicle, which can be above the model's floor.
    private var rarity: Rarity { capture.rarity }
    /// A developed catch is a showroom render: a full frame picture, so it
    /// fills the tile exactly like the original photo does.
    private var render: UIImage? { store.developedImage(for: capture) }
    private var photo: UIImage? { store.image(for: capture) }

    var body: some View {
        VStack(spacing: 0) {
            // Plate: the car, fitted whole, with its dex number over it.
            ZStack {
                rarity.plateFill

                if let render {
                    Image(uiImage: render).resizable().scaledToFit()
                } else if let photo {
                    Image(uiImage: photo).resizable().scaledToFit()
                } else {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(Ink.raised)
                }
            }
            .frame(height: 112)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .topLeading) {
                Text(car.dexNumber)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Ink.text)
                    .padding(.horizontal, 7)
                    .frame(height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.black.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                    )
                    .padding(8)
            }

            // Rarity reads as a band, named and counted, tinted to the tier.
            HStack(spacing: 8) {
                Text(rarity.title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(rarity.bandInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                HStack(spacing: 2.5) {
                    ForEach(0..<5, id: \.self) { i in
                        Rectangle()
                            .fill(rarity.bandInk.opacity(i < rarity.pips ? 1 : 0.22))
                            .frame(width: 9, height: 3)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .frame(maxWidth: .infinity)
            .background(rarity.bandFill)

            VStack(alignment: .leading, spacing: 2) {
                Text(car.make)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Ink.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(car.model)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let variant = capture.variant {
                    Text(variant)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(rarity.color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 8)

            Spacer(minLength: 0)

            Rectangle().fill(Ink.line).frame(height: 1).padding(.horizontal, 10)

            // Footer: when it was caught, and the mark.
            HStack(spacing: 6) {
                Text(capture.isDeveloped ? "CAUGHT" : "LOGGED")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(Ink.ghost)
                Text(capture.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Ink.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                SuprGlyph(size: 13, tint: Ink.ghost)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 248, alignment: .top)
        .background(Ink.card)
        .clipShape(RoundedRectangle(cornerRadius: R.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.tile, style: .continuous)
                .strokeBorder(rarity.edge, lineWidth: rarity >= .rare ? 1.5 : 1)
        )
        .overlay {
            if store.developing.contains(capture.id) {
                ZStack {
                    Color.black.opacity(0.5)
                    VStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Developing")
                            .font(UI.font(11.5, .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: R.tile, style: .continuous))
                .transition(.opacity)
            }
        }
        .card(Ink.card, radius: R.tile)
        .animation(.easeInOut(duration: 0.2), value: store.developing.contains(capture.id))
    }
}
