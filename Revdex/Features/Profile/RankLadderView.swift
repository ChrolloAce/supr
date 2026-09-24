import SwiftUI

/// The full thirty rank ladder, grouped by tier.
struct RankLadderView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var level: Int { store.profile.level }
    private var myRank: Rank { store.profile.rank }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Ranks", trailingLabel: "\(Ranks.all.count) TOTAL") { dismiss() }

                ScrollView {
                    VStack(spacing: 16) {
                        currentCard
                        ForEach(Rank.Tier.allCases, id: \.self) { tier in
                            tierBlock(tier)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: Current

    private var currentCard: some View {
        let next = Ranks.next(after: level)
        return HStack(spacing: 14) {
            RankBadge(rank: store.profile.rank, size: 62)

            VStack(alignment: .leading, spacing: 3) {
                Text("You are")
                    .label(9.5, .bold, tracking: 0.8)
                    .foregroundStyle(Ink.faint)
                Text(store.profile.rankName)
                    .display(24)
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let next {
                    Text("\(next.name) at LV \(next.level)")
                        .label(9, .bold, tracking: 0.4)
                        .foregroundStyle(store.profile.rank.tier.color)
                } else {
                    Text("Top of the ladder")
                        .label(9, .bold, tracking: 0.4)
                        .foregroundStyle(Ink.accentSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .card()
    }

    // MARK: Tier

    private func tierBlock(_ tier: Rank.Tier) -> some View {
        let ranks = Ranks.all.filter { $0.tier == tier }
        let unlocked = ranks.contains { $0.level <= level }

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(tier.color)
                    .frame(width: 5, height: 20)
                    .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.2))
                Text(tier.title)
                    .display(17)
                    .foregroundStyle(unlocked ? Ink.text : Ink.faint)
                Spacer()
                Text("LV \(ranks.first?.level ?? 1)+")
                    .label(9.5, .bold, tracking: 0.6)
                    .foregroundStyle(Ink.faint)
            }

            VStack(spacing: 0) {
                ForEach(Array(ranks.enumerated()), id: \.element.id) { i, rank in
                    let have = rank.level <= level
                    let isCurrent = rank.id == store.profile.rank.id

                    HStack(spacing: 12) {
                        RankBadge(rank: rank, size: 38, showsStep: false)
                            .opacity(have ? 1 : 0.28)
                            .saturation(have ? 1 : 0)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rank.name)
                                .font(UI.font(13.5, .heavy))
                                .foregroundStyle(have ? Ink.text : Ink.faint)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(tier.title) \(rank.romanStep)  ·  LV \(rank.level)")
                                .label(8.5, .bold, tracking: 0.4)
                                .foregroundStyle(Ink.ghost)
                        }

                        Spacer(minLength: 4)

                        if isCurrent {
                            Text("YOU")
                                .label(8.5, .heavy, tracking: 0.4)
                                .foregroundStyle(Ink.onAccent)
                                .padding(.horizontal, 7)
                                .frame(height: 20)
                                .background(Ink.accentSoft)
                                .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.4))
                        } else if !have {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Ink.ghost)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Ink.done)
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 60)

                    if i < ranks.count - 1 {
                        Rectangle().fill(Ink.line).frame(height: Line.hair)
                    }
                }
            }
            .card()
        }
    }
}
