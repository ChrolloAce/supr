import SwiftUI

/// What the garage and the dex are currently showing, and in what order.
///
/// Replaces the row of rarity chips that used to scroll off the side of the
/// screen. A collection of five hundred entries needs a make and a body filter
/// too, and none of that fits in a strip.
struct CollectionFilter: Equatable {

    enum Sort: String, CaseIterable, Identifiable {
        case newest, oldest, rarest, commonest, name, make

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newest: return "Date added, newest"
            case .oldest: return "Date added, oldest"
            case .rarest: return "Rarity, highest"
            case .commonest: return "Rarity, lowest"
            case .name: return "Model, A to Z"
            case .make: return "Make, A to Z"
            }
        }

        var short: String {
            switch self {
            case .newest: return "Newest"
            case .oldest: return "Oldest"
            case .rarest: return "Rarest"
            case .commonest: return "Commonest"
            case .name: return "A-Z"
            case .make: return "Make"
            }
        }

        /// The dex has no capture dates, so date order means nothing there.
        var needsDates: Bool { self == .newest || self == .oldest }
    }

    var sort: Sort = .newest
    var rarity: Rarity?
    var body: BodyType?
    var make: String?

    var isActive: Bool { rarity != nil || body != nil || make != nil }
    var count: Int { [rarity != nil, body != nil, make != nil].filter { $0 }.count }

    mutating func clear() {
        rarity = nil
        body = nil
        make = nil
    }

    func matches(_ car: CarModel) -> Bool {
        if let rarity, car.rarity != rarity { return false }
        if let body, car.body != body { return false }
        if let make, car.make != make { return false }
        return true
    }

    /// Ordering for things that have a catch date behind them.
    func sorted(_ captures: [Capture]) -> [Capture] {
        switch sort {
        case .newest: return captures.sorted { $0.date > $1.date }
        case .oldest: return captures.sorted { $0.date < $1.date }
        case .rarest: return captures.sorted { ($0.car.rarity, $0.date) > ($1.car.rarity, $1.date) }
        case .commonest: return captures.sorted { ($0.car.rarity, $0.date) < ($1.car.rarity, $1.date) }
        case .name: return captures.sorted { $0.car.model.localizedCompare($1.car.model) == .orderedAscending }
        case .make: return captures.sorted { $0.car.fullName.localizedCompare($1.car.fullName) == .orderedAscending }
        }
    }

    /// Ordering for the dex, where dex number stands in for date.
    func sorted(_ cars: [CarModel]) -> [CarModel] {
        switch sort {
        case .newest, .oldest: return cars.sorted { $0.id < $1.id }
        case .rarest: return cars.sorted { ($0.rarity, $1.id) > ($1.rarity, $0.id) }
        case .commonest: return cars.sorted { ($0.rarity, $1.id) < ($1.rarity, $0.id) }
        case .name: return cars.sorted { $0.model.localizedCompare($1.model) == .orderedAscending }
        case .make: return cars.sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
        }
    }
}

// MARK: - Button

/// Sits next to search. Shows a dot when something is actually filtering.
struct FilterButton: View {
    let filter: CollectionFilter
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button {
            Buzz.tap()
            action()
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(filter.isActive ? .white : Ink.text)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                        .fill(filter.isActive ? Ink.accent : Ink.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                        .strokeBorder(filter.isActive ? .clear : Ink.line, lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if filter.count > 1 {
                        Text("\(filter.count)")
                            .font(UI.font(9, .bold))
                            .foregroundStyle(Ink.bg)
                            .frame(width: 15, height: 15)
                            .background(Circle().fill(Ink.accentSoft))
                            .offset(x: 4, y: -4)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet

struct FilterSheet: View {
    @Binding var filter: CollectionFilter
    /// Makes present in whatever is being filtered, with how many of each.
    let makes: [(name: String, count: Int)]
    let bodies: [(type: BodyType, count: Int)]
    let rarities: [(rarity: Rarity, count: Int)]
    /// The dex cannot sort by date, so those two options are hidden there.
    var allowsDateSort: Bool = true

    @Environment(\.dismiss) private var dismiss

    private var sorts: [CollectionFilter.Sort] {
        CollectionFilter.Sort.allCases.filter { allowsDateSort || !$0.needsDates }
    }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Filter and sort") { dismiss() }

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        section("Sort by") {
                            VStack(spacing: 0) {
                                ForEach(Array(sorts.enumerated()), id: \.element.id) { i, sort in
                                    Button {
                                        Buzz.soft()
                                        filter.sort = sort
                                    } label: {
                                        HStack(spacing: 10) {
                                            Text(sort.title)
                                                .font(UI.font(14))
                                                .foregroundStyle(Ink.text)
                                            Spacer(minLength: 0)
                                            if filter.sort == sort {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Ink.accent)
                                            }
                                        }
                                        .padding(.horizontal, 15)
                                        .frame(height: 46)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if i < sorts.count - 1 {
                                        Rectangle().fill(Ink.line).frame(height: Line.hair)
                                    }
                                }
                            }
                            .card()
                        }

                        if !rarities.isEmpty {
                            section("Rarity") {
                                wrap(rarities.map { ($0.rarity.title, $0.count, $0.rarity.color) },
                                     isOn: { i in filter.rarity == rarities[i].rarity },
                                     tap: { i in
                                         let r = rarities[i].rarity
                                         filter.rarity = filter.rarity == r ? nil : r
                                     },
                                     clear: { filter.rarity = nil },
                                     allActive: filter.rarity == nil)
                            }
                        }

                        if !bodies.isEmpty {
                            section("Body") {
                                wrap(bodies.map { ($0.type.title.capitalized, $0.count, nil) },
                                     isOn: { i in filter.body == bodies[i].type },
                                     tap: { i in
                                         let b = bodies[i].type
                                         filter.body = filter.body == b ? nil : b
                                     },
                                     clear: { filter.body = nil },
                                     allActive: filter.body == nil)
                            }
                        }

                        if !makes.isEmpty {
                            section("Make") {
                                wrap(makes.map { ($0.name, $0.count, nil) },
                                     isOn: { i in filter.make == makes[i].name },
                                     tap: { i in
                                         let m = makes[i].name
                                         filter.make = filter.make == m ? nil : m
                                     },
                                     clear: { filter.make = nil },
                                     allActive: filter.make == nil)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)

                HStack(spacing: 10) {
                    Button("Clear") {
                        Buzz.tap()
                        filter.clear()
                    }
                    .buttonStyle(.accent)
                    .opacity(filter.isActive ? 1 : 0.4)
                    .disabled(!filter.isActive)

                    Button("Done") {
                        Buzz.tap()
                        dismiss()
                    }
                    .buttonStyle(.primary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .label(10, .semibold, tracking: 1)
                .foregroundStyle(Ink.faint)
            content()
        }
    }

    /// A wrapping run of chips. Nothing scrolls sideways, so nothing hides.
    private func wrap(
        _ items: [(String, Int, Color?)],
        isOn: @escaping (Int) -> Bool,
        tap: @escaping (Int) -> Void,
        clear: @escaping () -> Void,
        allActive: Bool
    ) -> some View {
        FlowLayout(spacing: 8) {
            chip("All", nil, nil, active: allActive) {
                Buzz.soft()
                clear()
            }
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                chip(item.0, item.1, item.2, active: isOn(i)) {
                    Buzz.soft()
                    tap(i)
                }
            }
        }
    }

    private func chip(_ text: String, _ count: Int?, _ dot: Color?, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 6, height: 6)
                }
                Text(text)
                    .font(UI.font(13, .semibold))
                    .foregroundStyle(active ? .white : Ink.text)
                if let count {
                    Text("\(count)")
                        .font(UI.font(11.5, .semibold))
                        .foregroundStyle(active ? .white.opacity(0.7) : Ink.faint)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule().fill(active ? Ink.accent : Ink.card)
            )
            .overlay(
                Capsule().strokeBorder(active ? .clear : Ink.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow layout

/// Chips that wrap onto the next line instead of running off the edge.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, in: width)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, in: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let next = row.width == 0 ? size.width : row.width + spacing + size.width
            if next > width && !row.indices.isEmpty {
                rows.append(row)
                row = Row()
                row.indices = [index]
                row.width = size.width
                row.height = size.height
            } else {
                row.indices.append(index)
                row.width = next
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
