import SwiftUI

/// Everything there is to earn, in one grid, with the ones still out of reach
/// greyed rather than hidden. Knowing what is left is most of the point.
struct AchievementsView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Achievement?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var stats: Achievement.Stats { store.achievementStats }
    private var earned: Int { store.unlocked.count }

    /// Unlocked first, then whatever is closest to being unlocked.
    private var ordered: [Achievement] {
        Achievements.all.sorted { a, b in
            let ua = store.isUnlocked(a), ub = store.isUnlocked(b)
            if ua != ub { return ua }
            return fraction(a) > fraction(b)
        }
    }

    private func fraction(_ a: Achievement) -> Double {
        let p = a.progress(stats)
        return p.target > 0 ? min(1, Double(p.done) / Double(p.target)) : 0
    }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Badges") { dismiss() }

                summary
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(ordered) { achievement in
                            Button {
                                Buzz.tap()
                                selected = achievement
                            } label: {
                                tile(achievement)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                    Spacer(minLength: 40)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(item: $selected) { detail($0) }
    }

    private var summary: some View {
        VStack(spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(earned)")
                    .font(UI.font(26, .bold))
                    .foregroundStyle(Ink.text)
                Text("/ \(Achievements.all.count) EARNED")
                    .label(10, .semibold, tracking: 1.4)
                    .foregroundStyle(Ink.faint)
                Spacer()
                Text("\(Int(Double(earned) / Double(Achievements.all.count) * 100))%")
                    .label(11, .bold, tracking: 1.2)
                    .foregroundStyle(Ink.accent)
            }
            XPBar(progress: Double(earned) / Double(Achievements.all.count))
        }
        .padding(16)
        .card()
    }

    private func tile(_ a: Achievement) -> some View {
        let unlocked = store.isUnlocked(a)
        let p = a.progress(stats)

        return VStack(spacing: 8) {
            AchievementBadge(achievement: a, size: 58, locked: !unlocked)
                .padding(.top, 12)

            Text(a.title)
                .font(UI.font(11.5, .semibold))
                .foregroundStyle(unlocked ? Ink.text : Ink.faint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(height: 30, alignment: .top)
                .padding(.horizontal, 6)

            if unlocked {
                Text("EARNED")
                    .label(7.5, .semibold, tracking: 0.8)
                    .foregroundStyle(a.color)
                    .padding(.bottom, 10)
            } else {
                Text("\(min(p.done, p.target))/\(p.target)")
                    .font(UI.font(10, .semibold))
                    .foregroundStyle(Ink.ghost)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .card(Ink.card, radius: R.tile)
        .overlay(
            RoundedRectangle(cornerRadius: R.tile, style: .continuous)
                .strokeBorder(unlocked ? a.color.opacity(0.4) : Ink.line, lineWidth: 1)
        )
    }

    private func detail(_ a: Achievement) -> some View {
        let unlocked = store.isUnlocked(a)
        let p = a.progress(stats)

        return ZStack {
            Backdrop()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                AchievementBadge(achievement: a, size: 132, locked: !unlocked)
                    .shadow(color: a.color.opacity(unlocked ? 0.4 : 0), radius: 26)

                Text(a.title)
                    .display(30)
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)

                Text(a.blurb)
                    .font(UI.font(14.5))
                    .foregroundStyle(Ink.faint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 40)

                if unlocked {
                    if let date = store.unlockedAt(a) {
                        Text("Earned \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .label(9.5, .semibold, tracking: 1)
                            .foregroundStyle(a.color)
                            .padding(.top, 18)
                    }
                } else {
                    VStack(spacing: 8) {
                        XPBar(progress: fraction(a), height: 10)
                        Text("\(min(p.done, p.target)) of \(p.target)")
                            .font(UI.font(12.5, .semibold))
                            .foregroundStyle(Ink.faint)
                    }
                    .padding(.top, 26)
                    .padding(.horizontal, 50)
                }

                Spacer(minLength: 0)
            }
        }
        // Sized to its content rather than a guessed height, so there is no
        // strip of the grid showing under the sheet.
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
