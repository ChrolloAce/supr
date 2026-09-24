import SwiftUI

/// Pick the one car from your garage that represents you.
struct FavouriteCarPicker: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    /// Captures rather than bare models, so each row can show the picture that
    /// was actually caught instead of a number in a coloured box.
    private var owned: [Capture] {
        store.uniqueGarage.sorted { $0.car.rarity > $1.car.rarity }
    }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Signature car") { dismiss() }

                if owned.isEmpty {
                    VStack {
                        EmptyBlock(
                            icon: "car.side.fill",
                            title: "Nothing to pick yet",
                            message: "Capture a car first, then come back and choose the one that represents you."
                        )
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(owned.enumerated()), id: \.element.id) { i, capture in
                                let car = capture.car
                                let picked = store.profile.favouriteCarID == car.id
                                Button {
                                    Buzz.tap()
                                    store.setFavouriteCar(picked ? nil : car.id)
                                    if !picked { dismiss() }
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                                                .fill(car.rarity.plateFill)
                                            if let image = store.displayImage(for: capture) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .padding(3)
                                            } else {
                                                Image(systemName: "car.side.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(Ink.raised)
                                            }
                                        }
                                        .frame(width: 74, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: R.chip, style: .continuous))

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(car.make)
                                                .label(8.5, .heavy, tracking: 0.6)
                                                .foregroundStyle(Ink.accent)
                                            Text(car.model)
                                                .display(18)
                                                .foregroundStyle(Ink.text)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.6)
                                        }

                                        Spacer(minLength: 4)

                                        Text(car.rarity.title)
                                            .label(8.5, .bold, tracking: 0.4)
                                            .foregroundStyle(Ink.faint)

                                        Image(systemName: picked ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 15, weight: .black))
                                            .foregroundStyle(picked ? Ink.accentSoft : Ink.ghost)
                                    }
                                    .padding(.horizontal, 13)
                                    .frame(height: 62)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if i < owned.count - 1 {
                                    Rectangle().fill(Ink.line).frame(height: Line.hair)
                                }
                            }
                        }
                        .card()
                        .padding(.horizontal, 18)
                        Spacer(minLength: 40)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }
}
