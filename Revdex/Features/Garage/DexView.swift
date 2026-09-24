import SwiftUI

struct DexView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var filter = CollectionFilter(sort: .name)
    @State private var showFilter = false
    @State private var onlyCaught = false
    @State private var selectedCar: CarModel?
    @State private var openSpecial: Capture?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var list: [CarModel] {
        let filtered = Catalog.cars.filter { car in
            guard filter.matches(car) else { return false }
            if onlyCaught && !store.caughtIDs.contains(car.id) { return false }
            guard !query.isEmpty else { return true }
            return car.fullName.localizedCaseInsensitiveContains(query)
                || car.dexNumber.contains(query)
        }
        return filter.sorted(filtered)
    }

    private var rarityOptions: [(rarity: Rarity, count: Int)] {
        Rarity.allCases.reversed().map { ($0, Catalog.cars(of: $0).count) }
    }

    private var bodyOptions: [(type: BodyType, count: Int)] {
        BodyType.allCases.map { ($0, Catalog.cars(body: $0).count) }
    }

    private var makeOptions: [(name: String, count: Int)] {
        Dictionary(grouping: Catalog.cars, by: \.make)
            .map { ($0.key, $0.value.count) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "The Dex") { dismiss() }

                VStack(spacing: 12) {
                    progress
                    HStack(spacing: 9) {
                        SearchField(placeholder: "Search make or model", text: $query)
                        FilterButton(filter: filter, size: 44) { showFilter = true }
                    }
                    controls
                }
                .padding(.horizontal, 18)

                ScrollView {
                    if !store.specials.isEmpty { specialsRow }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(list) { car in
                            let caught = store.caughtIDs.contains(car.id)
                            Button {
                                guard caught else { Buzz.nope(); return }
                                Buzz.tap()
                                selectedCar = car
                            } label: {
                                if caught {
                                    DexTile(car: car, capture: store.captures(of: car.id).first)
                                } else {
                                    LockedTile(number: car.id)
                                }
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    Spacer(minLength: 40)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(isPresented: $showFilter) {
            FilterSheet(
                filter: $filter,
                makes: makeOptions,
                bodies: bodyOptions,
                rarities: rarityOptions,
                allowsDateSort: false
            )
        }
        .sheet(item: $openSpecial) { CarDetailView(capture: $0) }
        .sheet(item: $selectedCar) { car in
            if let capture = store.captures(of: car.id).first {
                CarDetailView(capture: capture)
            }
        }
    }

    private var progress: some View {
        VStack(spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(store.dexCount)")
                    .font(UI.font(26, .bold))
                    .foregroundStyle(Ink.text)
                Text("/ \(store.dexTotal) SPOTTED")
                    .label(10, .semibold, tracking: 1.4)
                    .foregroundStyle(Ink.faint)
                Spacer()
                Text("\(Int(Double(store.dexCount) / Double(store.dexTotal) * 100))%")
                    .label(11, .bold, tracking: 1.2)
                    .foregroundStyle(Ink.accent)
            }
            XPBar(progress: Double(store.dexCount) / Double(store.dexTotal))
        }
        .padding(16)
        .card()
    }

    /// Odd vehicles are not catalogue entries, so they get their own shelf.
    /// A Red Bull show car and a police interceptor are the fun of the thing.
    private var specialsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SPECIALS")
                    .label(10, .semibold, tracking: 1.4)
                    .foregroundStyle(Ink.faint)
                Spacer()
                Text("\(store.specials.count)")
                    .label(10, .bold, tracking: 1)
                    .foregroundStyle(Ink.dim)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(store.specials) { capture in
                        Button {
                            Buzz.tap()
                            openSpecial = capture
                        } label: {
                            VStack(spacing: 0) {
                                ZStack {
                                    capture.rarity.plateFill
                                    if let image = store.displayImage(for: capture) {
                                        Image(uiImage: image).resizable().scaledToFit()
                                    } else {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Ink.raised)
                                    }
                                }
                                .frame(width: 132, height: 76)
                                .clipped()

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(capture.variant ?? "")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Text(capture.car.fullName)
                                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(capture.rarity.bandFill)
                            }
                            .frame(width: 132)
                            .clipShape(RoundedRectangle(cornerRadius: R.tile, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: R.tile, style: .continuous)
                                    .strokeBorder(capture.rarity.color.opacity(0.6), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(CardPressStyle())
                    }
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    /// One line under the search field: what is being shown, and a switch for
    /// hiding everything still locked.
    private var controls: some View {
        HStack(spacing: 8) {
            Text(summary)
                .font(UI.font(12.5, .semibold))
                .foregroundStyle(Ink.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)

            Button {
                Buzz.tap()
                withAnimation(.easeOut(duration: 0.16)) { onlyCaught.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: onlyCaught ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Caught only")
                        .font(UI.font(12, .semibold))
                }
                .foregroundStyle(onlyCaught ? Ink.accent : Ink.faint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private var summary: String {
        var parts = ["\(list.count) of \(Catalog.total)"]
        if let r = filter.rarity { parts.append(r.title) }
        if let b = filter.body { parts.append(b.title.capitalized) }
        if let m = filter.make { parts.append(m) }
        return parts.joined(separator: "  ·  ")
    }
}

struct DexTile: View {
    @EnvironmentObject private var store: GameStore
    let car: CarModel
    let capture: Capture?

    var body: some View {
        VStack(spacing: 0) {
            if let capture, let image = store.displayImage(for: capture) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 62)
                    .frame(maxWidth: .infinity)
                    .clipped()
                Rectangle().fill(Ink.line).frame(height: 1.6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(car.dexNumber)
                    .label(8, .heavy, tracking: 0.4)
                    .foregroundStyle(Ink.faint)
                Text(car.model)
                    .display(13)
                    .foregroundStyle(Ink.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 7)
            .padding(.top, 7)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)

            Rectangle().fill(car.rarity.color).frame(height: 6)
        }
        .card(Ink.card, radius: R.chip, drop: 3)
    }
}

struct LockedTile: View {
    let number: Int

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%03d", number))
                    .label(8, .heavy, tracking: 0.4)
                    .foregroundStyle(Ink.ghost)
                Spacer(minLength: 0)
                Image(systemName: "questionmark")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Ink.ghost.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)

            Rectangle().fill(Ink.raised).frame(height: 6)
        }
        .card(Ink.bg, radius: R.chip, drop: 0, shadow: .clear)
        .opacity(0.55)
    }
}
