import SwiftUI

/// Things worth doing that are not just XP. Every one is derived from what is
/// already saved, so they can be re-evaluated from scratch at any point and a
/// player who has been catching cars for weeks unlocks their backlog at once.
struct Achievement: Identifiable, Hashable {

    enum Goal: Hashable {
        case captures(Int)              // total catches
        case models(Int)                // distinct models in the dex
        case rarity(Rarity, Int)        // n catches at this rarity or better
        case developed(Int)             // stickers made
        case streak(Int)                // consecutive days
        case makes(Int)                 // distinct manufacturers
        case level(Int)
        case dexPercent(Int)
        case allBodies                  // one of every body type
        case cities(Int)                // distinct places
        case hours(Int, Int)            // a catch inside this hour window
        case mapped(Int)                // developed catches carrying a location
    }

    let id: String
    let title: String
    let blurb: String
    let symbol: String
    let tint: UInt32
    let goal: Goal

    /// Generated art if it is in the bundle, drawn emblem if it is not.
    var asset: String { "ach_\(id)" }
    var color: Color { Color(hex: tint) }

    // MARK: Progress

    /// Where the player is against this goal, as a fraction and as a count.
    func progress(_ s: Achievement.Stats) -> (done: Int, target: Int) {
        switch goal {
        case .captures(let n): return (s.captures, n)
        case .models(let n): return (s.models, n)
        case .rarity(let r, let n): return (s.byRarity[r] ?? 0, n)
        case .developed(let n): return (s.developed, n)
        case .streak(let n): return (s.streak, n)
        case .makes(let n): return (s.makes, n)
        case .level(let n): return (s.level, n)
        case .dexPercent(let n): return (s.dexPercent, n)
        case .allBodies: return (s.bodies, BodyType.allCases.count)
        case .cities(let n): return (s.cities, n)
        case .hours: return (s.nightCatch ? 1 : 0, 1)
        case .mapped(let n): return (s.mapped, n)
        }
    }

    func isMet(_ s: Achievement.Stats) -> Bool {
        if case .hours(let from, let to) = goal {
            return s.caughtInWindow(from, to)
        }
        let p = progress(s)
        return p.done >= p.target
    }

    // MARK: Stats snapshot

    /// Everything the goals are measured against, computed once per evaluation
    /// rather than per achievement.
    struct Stats {
        var captures = 0
        var models = 0
        var byRarity: [Rarity: Int] = [:]
        var developed = 0
        var streak = 0
        var makes = 0
        var level = 1
        var dexPercent = 0
        var bodies = 0
        var cities = 0
        var mapped = 0
        var nightCatch = false
        /// Hour of day for every catch, for the window goals.
        var hours: [Int] = []

        func caughtInWindow(_ from: Int, _ to: Int) -> Bool {
            hours.contains { hour in
                from <= to ? (hour >= from && hour < to) : (hour >= from || hour < to)
            }
        }

        init(captures list: [Capture], level: Int, streak: Int, dexTotal: Int) {
            self.level = level
            self.streak = streak
            captures = list.count
            models = Set(list.map(\.carID)).count
            makes = Set(list.map { $0.car.make }).count
            bodies = Set(list.map { $0.car.body }).count
            cities = Set(list.map { $0.city.uppercased() }.filter { !$0.isEmpty && $0 != "UNKNOWN" }).count
            developed = list.filter(\.isDeveloped).count
            mapped = list.filter { $0.isDeveloped && $0.lat != nil }.count
            dexPercent = dexTotal > 0 ? Int(Double(models) / Double(dexTotal) * 100) : 0

            let calendar = Calendar.current
            hours = list.map { calendar.component(.hour, from: $0.date) }
            nightCatch = caughtInWindow(22, 5)

            // Rarity counts are cumulative: an exotic also counts toward rare.
            for capture in list {
                for rarity in Rarity.allCases where capture.car.rarity >= rarity {
                    byRarity[rarity, default: 0] += 1
                }
            }
        }
    }
}

// MARK: - The list

enum Achievements {

    static let all: [Achievement] = [
        // Volume
        Achievement(id: "first_catch", title: "Ignition", blurb: "Catch your first car",
                    symbol: "camera.fill", tint: 0x8B5CF6, goal: .captures(1)),
        Achievement(id: "ten_catches", title: "Ten Deep", blurb: "Catch 10 cars",
                    symbol: "car.fill", tint: 0x8B5CF6, goal: .captures(10)),
        Achievement(id: "fifty_catches", title: "Curb Rat", blurb: "Catch 50 cars",
                    symbol: "car.2.fill", tint: 0xA78BFA, goal: .captures(50)),
        Achievement(id: "two_hundred", title: "Menace", blurb: "Catch 200 cars",
                    symbol: "flame.fill", tint: 0xE8B93B, goal: .captures(200)),

        // Rarity
        Achievement(id: "first_uncommon", title: "Second Look", blurb: "Catch an uncommon car",
                    symbol: "sparkle", tint: 0x6D5AA8, goal: .rarity(.uncommon, 1)),
        Achievement(id: "first_rare", title: "Head Turner", blurb: "Catch a rare car",
                    symbol: "diamond.fill", tint: 0x8B5CF6, goal: .rarity(.rare, 1)),
        Achievement(id: "first_exotic", title: "Exotic Plates", blurb: "Catch an exotic car",
                    symbol: "bolt.fill", tint: 0xA78BFA, goal: .rarity(.exotic, 1)),
        Achievement(id: "first_legendary", title: "Ghost", blurb: "Catch a legendary car",
                    symbol: "crown.fill", tint: 0xD5CCF0, goal: .rarity(.legendary, 1)),
        Achievement(id: "ten_exotic", title: "Bad Habit", blurb: "Catch 10 exotics or better",
                    symbol: "star.circle.fill", tint: 0xE0B04A, goal: .rarity(.exotic, 10)),
        Achievement(id: "five_legendary", title: "Myth Hunter", blurb: "Catch 5 legendary cars",
                    symbol: "trophy.fill", tint: 0xE0B04A, goal: .rarity(.legendary, 5)),

        // Developing
        Achievement(id: "first_develop", title: "Darkroom", blurb: "Develop your first sticker",
                    symbol: "wand.and.sparkles", tint: 0x8B5CF6, goal: .developed(1)),
        Achievement(id: "twenty_develop", title: "Peel and Stick", blurb: "Develop 20 stickers",
                    symbol: "square.stack.3d.up.fill", tint: 0xA78BFA, goal: .developed(20)),
        Achievement(id: "first_pin", title: "Dropped a Pin", blurb: "Put a developed catch on the map",
                    symbol: "mappin.circle.fill", tint: 0x1FA88F, goal: .mapped(1)),
        Achievement(id: "ten_pins", title: "Territory", blurb: "Drop 10 pins on the map",
                    symbol: "map.fill", tint: 0x1FA88F, goal: .mapped(10)),

        // Breadth
        Achievement(id: "five_makes", title: "Mixed Bag", blurb: "Catch 5 different makes",
                    symbol: "square.grid.2x2.fill", tint: 0x8B5CF6, goal: .makes(5)),
        Achievement(id: "twenty_makes", title: "Badge Snob", blurb: "Catch 20 different makes",
                    symbol: "seal.fill", tint: 0xA78BFA, goal: .makes(20)),
        Achievement(id: "all_bodies", title: "Full Set", blurb: "Catch one of every body type",
                    symbol: "rectangle.3.group.fill", tint: 0xE8B93B, goal: .allBodies),
        Achievement(id: "three_cities", title: "Out of State", blurb: "Catch cars in 3 cities",
                    symbol: "signpost.right.fill", tint: 0x3B7FB5, goal: .cities(3)),

        // Dex
        Achievement(id: "dex_5", title: "Warm Tyres", blurb: "Fill 5% of the dex",
                    symbol: "book.fill", tint: 0x8B5CF6, goal: .dexPercent(5)),
        Achievement(id: "dex_25", title: "Deep Cut", blurb: "Fill 25% of the dex",
                    symbol: "books.vertical.fill", tint: 0xA78BFA, goal: .dexPercent(25)),
        Achievement(id: "dex_50", title: "Half the Road", blurb: "Fill half the dex",
                    symbol: "checkmark.seal.fill", tint: 0xE0B04A, goal: .dexPercent(50)),

        // Habit
        Achievement(id: "streak_3", title: "Three Deep", blurb: "Catch on 3 days running",
                    symbol: "flame", tint: 0xFF6A00, goal: .streak(3)),
        Achievement(id: "streak_7", title: "No Days Off", blurb: "Catch on 7 days running",
                    symbol: "flame.fill", tint: 0xFF6A00, goal: .streak(7)),
        Achievement(id: "streak_30", title: "Unhinged", blurb: "Catch on 30 days running",
                    symbol: "bolt.heart.fill", tint: 0xD8232A, goal: .streak(30)),
        Achievement(id: "night_owl", title: "Graveyard Shift", blurb: "Catch a car after 10pm",
                    symbol: "moon.stars.fill", tint: 0x1D3557, goal: .hours(22, 5)),
        Achievement(id: "early_bird", title: "Cold Start", blurb: "Catch a car before 7am",
                    symbol: "sunrise.fill", tint: 0xE8B93B, goal: .hours(5, 7)),

        // Rank
        Achievement(id: "level_10", title: "Regular", blurb: "Reach level 10",
                    symbol: "chevron.up.circle.fill", tint: 0x8B5CF6, goal: .level(10)),
        Achievement(id: "level_25", title: "Old Head", blurb: "Reach level 25",
                    symbol: "shield.fill", tint: 0xA78BFA, goal: .level(25)),
        Achievement(id: "level_50", title: "Apex", blurb: "Reach level 50",
                    symbol: "crown.fill", tint: 0xE0B04A, goal: .level(50))
    ]

    static let byID: [String: Achievement] = Dictionary(
        all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    static func achievement(_ id: String) -> Achievement? { byID[id] }
}

// MARK: - Badge

/// Uses generated art when it is in the bundle and falls back to a drawn
/// emblem, so a missing image never leaves a blank square.
struct AchievementBadge: View {
    let achievement: Achievement
    var size: CGFloat = 64
    var locked: Bool = false

    private var hasArt: Bool { UIImage(named: achievement.asset) != nil }

    var body: some View {
        ZStack {
            if hasArt {
                Image(achievement.asset)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [achievement.color.opacity(0.28), achievement.color.opacity(0.08)],
                            center: .topLeading, startRadius: 2, endRadius: size
                        )
                    )
                    .overlay(Circle().strokeBorder(achievement.color.opacity(0.55), lineWidth: 1.5))
                    .overlay(
                        Image(systemName: achievement.symbol)
                            .font(.system(size: size * 0.38, weight: .semibold))
                            .foregroundStyle(achievement.color)
                    )
            }
        }
        .frame(width: size, height: size)
        .saturation(locked ? 0 : 1)
        .opacity(locked ? 0.32 : 1)
    }
}
