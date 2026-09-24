import Foundation

/// Another spotter, as stored in `revdex_profiles`. Everyone on the board is a
/// real install; there is no synthetic filler.
struct Rival: Identifiable, Hashable {
    var id: String            // device id
    var handle: String
    var city: String
    var xp: Int
    var level: Int
    var rankName: String
    var avatarURL: String?
    var isPro: Bool

    var isMe: Bool { id == Backend.deviceID }

    init(row: [String: Any]) {
        id = row["device_id"] as? String ?? UUID().uuidString
        handle = row["handle"] as? String ?? "spotter"
        city = (row["city"] as? String ?? "").uppercased()
        xp = row["xp"] as? Int ?? 0
        level = row["level"] as? Int ?? Levels.level(forXP: xp)
        rankName = row["rank_name"] as? String ?? Ranks.rank(for: level).name
        avatarURL = row["avatar_url"] as? String
        isPro = row["is_pro"] as? Bool ?? false
    }
}
