import SwiftUI

/// Tap the quest to see exactly what counts, with real examples from the dex.
struct QuestView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var hunt: DailyHunt { store.hunt }

    /// Catalog entries that would satisfy today's quest.
    private var examples: [CarModel] {
        let caught = store.caughtIDs
        let matches = Catalog.cars.filter { hunt.isSatisfied(by: $0, isNew: !caught.contains($0.id)) }
        // Show the ones still missing from the dex first, they are worth the most.
        return Array(
            matches.sorted { a, b in
                let aNew = !caught.contains(a.id), bNew = !caught.contains(b.id)
                if aNew != bNew { return aNew }
                return a.rarity > b.rarity
            }.prefix(9)
        )
    }

    private var rule: String {
        switch hunt.kind {
        case .newModel:
            return "Capture any model that is not in your dex yet. Duplicates do not count today."
        case .rarityAtLeast:
            return "Capture anything rated \(hunt.payload.capitalized) or higher. Common and uncommon plates will not close it."
        case .specificMake:
            return "Capture any \(hunt.payload.capitalized). Any model, any year, any body style."
        case .bodyType:
            return "Capture any \(hunt.payload.lowercased()). Make and model do not matter."
        }
    }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Today's quest") { dismiss() }

                ScrollView {
                    VStack(spacing: 16) {
                        headline
                        rulePanel
                        if !examples.isEmpty { examplesSection }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(hunt.completed ? "Complete" : "Open")
                    .label(10, .heavy, tracking: 0.8)
                    .foregroundStyle(Ink.onAccent)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(hunt.completed ? Ink.done : Ink.accentSoft)
                    .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.5))
                Spacer()
                Text("+\(hunt.bonusXP) XP")
                    .display(20)
                    .foregroundStyle(Ink.accent)
            }
            .padding(.bottom, 12)

            Text(hunt.headline)
                .display(34)
                .foregroundStyle(Ink.text)
                .lineSpacing(-4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Resets at midnight")
                .label(9.5, .bold, tracking: 0.6)
                .foregroundStyle(Ink.faint)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card()
    }

    private var rulePanel: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "list.bullet.clipboard.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Ink.onAccent)
                .frame(width: 34, height: 34)
                .background(Ink.accentSoft)
                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.6))

            VStack(alignment: .leading, spacing: 5) {
                Text("What counts")
                    .label(10, .heavy, tracking: 0.8)
                    .foregroundStyle(Ink.dim)
                Text(rule)
                    .font(UI.font(13))
                    .foregroundStyle(Ink.text)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .card()
    }

    private var examplesSection: some View {
        VStack(spacing: 12) {
            Caption(text: "Look for", trailing: "\(examples.count) of many")

            VStack(spacing: 0) {
                ForEach(Array(examples.enumerated()), id: \.element.id) { i, car in
                    let caught = store.caughtIDs.contains(car.id)
                    HStack(spacing: 12) {
                        Text(car.dexNumber)
                            .label(9.5, .heavy, tracking: 0.4)
                            .foregroundStyle(car.rarity.onColor)
                            .frame(width: 36, height: 24)
                            .background(car.rarity.color)
                            .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.5))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(car.make)
                                .label(8.5, .heavy, tracking: 0.6)
                                .foregroundStyle(Ink.accent)
                            Text(car.model)
                                .display(17)
                                .foregroundStyle(Ink.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }

                        Spacer(minLength: 6)

                        Text(caught ? "IN DEX" : "MISSING")
                            .label(8.5, .heavy, tracking: 0.4)
                            .foregroundStyle(caught ? Ink.faint : Ink.done)
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 58)

                    if i < examples.count - 1 {
                        Rectangle().fill(Ink.line).frame(height: Line.hair)
                    }
                }
            }
            .card()
        }
    }
}
