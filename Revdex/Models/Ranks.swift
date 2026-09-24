import SwiftUI
import UIKit

/// Thirty named ranks, grouped into six tiers of five. Tier drives the badge art
/// and colour, the numeral inside the tier drives the pip count.
struct Rank: Identifiable, Hashable {
    let level: Int          // the level this rank unlocks at
    let name: String
    let tier: Tier
    let step: Int           // 1...5 within the tier

    var id: Int { level }
    var badgeAsset: String { tier.asset }
    var romanStep: String { ["I", "II", "III", "IV", "V"][max(0, min(4, step - 1))] }

    enum Tier: Int, CaseIterable {
        case rookie, spotter, hunter, curator, archivist, legend

        var title: String {
            switch self {
            case .rookie: return "Rookie"
            case .spotter: return "Spotter"
            case .hunter: return "Hunter"
            case .curator: return "Curator"
            case .archivist: return "Archivist"
            case .legend: return "Legend"
            }
        }

        var color: Color {
            switch self {
            case .rookie: return Color(hex: 0x8A8F98)     // gunmetal
            case .spotter: return Color(hex: 0xC0784A)    // bronze
            case .hunter: return Color(hex: 0xC6CBD4)     // silver
            case .curator: return Color(hex: 0xE0B04A)    // gold
            case .archivist: return Color(hex: 0xE8E4DA)  // platinum
            case .legend: return Color(hex: 0xBFE6F0)     // diamond
            }
        }

        /// Image set name in the asset catalog.
        var asset: String { "rank_tier_\(rawValue + 1)" }

        var symbol: String {
            switch self {
            case .rookie: return "cone.fill"
            case .spotter: return "binoculars.fill"
            case .hunter: return "scope"
            case .curator: return "key.fill"
            case .archivist: return "shield.fill"
            case .legend: return "crown.fill"
            }
        }
    }
}

enum Ranks {
    /// Five names per tier, thirty in total.
    static let all: [Rank] = {
        let names: [Rank.Tier: [String]] = [
            .rookie: ["Curb Crawler", "Plate Reader", "Lot Walker", "Corner Watcher", "Rookie Prime"],
            .spotter: ["Street Spotter", "Night Spotter", "Valet Eye", "Garage Regular", "Spotter Prime"],
            .hunter: ["Trim Hunter", "Badge Hunter", "Exhaust Hunter", "Rare Plate Hunter", "Hunter Prime"],
            .curator: ["Keyholder", "Collection Curator", "Concours Scout", "Marque Curator", "Curator Prime"],
            .archivist: ["Registry Keeper", "Chassis Archivist", "Grail Tracker", "Vault Archivist", "Archivist Prime"],
            .legend: ["City Legend", "Coast Legend", "National Legend", "Global Legend", "Apex"]
        ]

        var out: [Rank] = []
        var level = 1
        for tier in Rank.Tier.allCases {
            for step in 1...5 {
                out.append(Rank(level: level, name: names[tier]![step - 1], tier: tier, step: step))
                level += tier == .legend ? 3 : 2
            }
        }
        return out
    }()

    static func rank(for level: Int) -> Rank {
        var best = all[0]
        for r in all where r.level <= level { best = r }
        return best
    }

    static func next(after level: Int) -> Rank? {
        all.first { $0.level > level }
    }
}

// MARK: - Badge

/// Rank badge. Uses generated tier art when it is in the bundle and falls back
/// to a drawn emblem so the app never ships a blank square.
struct RankBadge: View {
    let rank: Rank
    var size: CGFloat = 44
    var showsStep: Bool = true

    private var hasArt: Bool { UIImage(named: rank.badgeAsset) != nil }

    var body: some View {
        ZStack {
            Group {
                if hasArt {
                    Image(rank.badgeAsset)
                        .resizable()
                        .scaledToFit()
                } else {
                    ZStack {
                        rank.tier.color.opacity(0.22)
                        Image(systemName: rank.tier.symbol)
                            .font(.system(size: size * 0.42, weight: .black))
                            .foregroundStyle(rank.tier.color)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(hasArt ? AnyShape(Rectangle()) : AnyShape(Circle()))
            .overlay(hasArt ? nil : Circle().strokeBorder(Ink.line, lineWidth: 1))
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if showsStep {
                Text(rank.romanStep)
                    .font(UI.font(size * 0.24, .bold))
                    .foregroundStyle(Ink.bg)
                    .frame(minWidth: size * 0.36, minHeight: size * 0.28)
                    .background(Capsule().fill(rank.tier.color))
                    .offset(x: size * 0.06, y: size * 0.02)
            }
        }
    }
}
