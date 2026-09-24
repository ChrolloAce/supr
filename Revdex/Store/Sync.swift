import SwiftUI
import UIKit

/// Pushes the garage to the server so a catch survives the app, the phone and a
/// reinstall, and pulls the shared feed and chat back down.
///
/// The device stays the source of truth for gameplay: every write happens
/// locally first and then syncs, so the app works with no signal and catches up
/// when it has one.
@MainActor
final class Sync: ObservableObject {

    @Published private(set) var lastPush: Date?
    @Published private(set) var pushing = false
    @Published private(set) var pushedIDs: Set<UUID> = []

    private let store: GameStore
    private var pushedKey = "revdex.pushed.captures"

    init(store: GameStore) {
        self.store = store
        if let saved = UserDefaults.standard.array(forKey: pushedKey) as? [String] {
            pushedIDs = Set(saved.compactMap(UUID.init(uuidString:)))
        }
    }

    // MARK: Profile

    func pushProfile() async {
        let p = store.profile
        var row: [String: Any] = [
            "device_id": Backend.deviceID,
            "handle": p.handle.isEmpty ? "spotter" : p.handle.lowercased(),
            "city": p.city,
            "xp": p.xp,
            "streak": p.streak,
            "level": p.level,
            "rank_name": p.rankName,
            "display_name": p.displayName,
            "terms_version": UserDefaults.standard.integer(forKey: "revdex.terms.version"),
            "is_pro": store.isPro,
            "updated_at": Backend.iso(Date())
        ]
        if let fav = p.favouriteCarID { row["favourite_car"] = fav }
        if let apple = UserDefaults.standard.string(forKey: "revdex.apple.user"), !apple.isEmpty {
            row["apple_user_id"] = apple
            row["agreed_terms_at"] = Backend.iso(Date())
        }
        let mail = UserDefaults.standard.string(forKey: "revdex.apple.email") ?? ""
        if !mail.isEmpty { row["email"] = mail }

        // The avatar only uploads once, then the URL is reused.
        if let file = p.avatarFile,
           UserDefaults.standard.string(forKey: "revdex.avatar.url.\(file)") == nil,
           let image = store.avatarImage,
           let url = await Backend.upload(image, folder: "avatars", maxSide: 512) {
            UserDefaults.standard.set(url, forKey: "revdex.avatar.url.\(file)")
        }
        if let file = p.avatarFile,
           let url = UserDefaults.standard.string(forKey: "revdex.avatar.url.\(file)") {
            row["avatar_url"] = url
        }

        await Backend.upsert("revdex_profiles", row)
    }

    // MARK: Captures

    /// Sends anything the server has not seen yet, images included.
    func pushCaptures() async {
        guard !pushing else { return }
        pushing = true
        defer { pushing = false }

        // The profile row has to exist first: captures reference it.
        await pushProfile()

        let outstanding = store.captures.filter { !pushedIDs.contains($0.id) }
        guard !outstanding.isEmpty else {
            lastPush = Date()
            return
        }

        for capture in outstanding {
            var row: [String: Any] = [
                "id": capture.id.uuidString.lowercased(),
                "device_id": Backend.deviceID,
                "car_id": capture.carID,
                "city": capture.city,
                "was_completed": capture.wasCompleted,
                "variant": capture.variant as Any,
                "spec": capture.spec as Any,
                "note": capture.note as Any,
                "rarity_bump": capture.rarityBump,
                "xp_awarded": capture.xpAwarded,
                "is_first_catch": capture.isFirstCatch,
                "caught_at": Backend.iso(capture.date)
            ]
            if let lat = capture.lat { row["lat"] = lat }
            if let lng = capture.lng { row["lng"] = lng }

            if let photo = store.image(for: capture),
               let url = await Backend.upload(photo, folder: "photos", maxSide: 1200) {
                row["photo_url"] = url
            }
            if let sticker = store.developedImage(for: capture),
               let url = await Backend.upload(sticker, folder: "stickers", png: true, maxSide: 900) {
                row["sticker_url"] = url
            }

            if await Backend.upsert("revdex_captures", row) {
                pushedIDs.insert(capture.id)
            }
        }

        UserDefaults.standard.set(pushedIDs.map(\.uuidString), forKey: pushedKey)
        lastPush = Date()
    }

    /// Erases everything this device has put on the server.
    ///
    /// Apple requires account deletion to actually delete, not just sign out,
    /// so this clears every table keyed on the device id and the uploaded files
    /// with it. Returns false if any step failed, so the UI can say so rather
    /// than claim a deletion that did not happen.
    @discardableResult
    func deleteEverythingRemote() async -> Bool {
        let me = Backend.deviceID
        var ok = true

        // Likes and comments this person left on other people's posts go too,
        // otherwise their handle survives on somebody else's thread.
        let tables = [
            "revdex_post_likes",
            "revdex_comments",
            "revdex_follows",
            "revdex_crew_members",
            "revdex_messages",
            "revdex_posts",
            "revdex_captures",
            "revdex_profiles"
        ]
        for table in tables {
            let column = table == "revdex_follows" ? "follower_id" : "device_id"
            if await Backend.delete(table, query: "\(column)=eq.\(me)") == false { ok = false }
        }
        // Following rows pointing back at this person.
        _ = await Backend.delete("revdex_follows", query: "target_id=eq.\(me)")

        if await Backend.deleteUploads() == false { ok = false }

        // Nothing is pushed again on the way out.
        pushedIDs = []
        UserDefaults.standard.removeObject(forKey: pushedKey)
        return ok
    }

    /// Removes one catch from the server, so it cannot come back on restore.
    func deleteCapture(_ id: UUID) async {
        let key = id.uuidString.lowercased()
        _ = await Backend.delete("revdex_captures", query: "id=eq.\(key)")
        _ = await Backend.delete("revdex_posts", query: "capture_id=eq.\(key)")
        pushedIDs.remove(id)
        UserDefaults.standard.set(pushedIDs.map(\.uuidString), forKey: pushedKey)
    }

    /// Marks a capture dirty so its next push carries the new sticker.
    func markDirty(_ id: UUID) {
        pushedIDs.remove(id)
        UserDefaults.standard.set(pushedIDs.map(\.uuidString), forKey: pushedKey)
    }

    // MARK: Restore

    /// Pulls this device's captures back down, for a reinstall or a new phone.
    @discardableResult
    func restore() async -> Int {
        let rows = await Backend.select(
            "revdex_captures",
            query: "device_id=eq.\(Backend.deviceID)&order=caught_at.desc&limit=500"
        )
        guard !rows.isEmpty else { return 0 }

        var recovered = 0
        for row in rows {
            guard let idString = row["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let carID = row["car_id"] as? Int,
                  !store.captures.contains(where: { $0.id == id }) else { continue }

            var photoFile: String?
            if let url = row["photo_url"] as? String, let image = await Backend.download(url) {
                photoFile = store.persistImage(image)
            }
            var stickerFile: String?
            if let url = row["sticker_url"] as? String, let image = await Backend.download(url) {
                stickerFile = store.persistPNG(image)
            }

            store.adopt(
                Capture(
                    id: id,
                    carID: carID,
                    date: Backend.date(row["caught_at"] as? String),
                    city: row["city"] as? String ?? "",
                    imageFile: photoFile,
                    developedFile: stickerFile,
                    wasCompleted: row["was_completed"] as? Bool ?? false,
                    variant: row["variant"] as? String,
                    spec: row["spec"] as? String,
                    note: row["note"] as? String,
                    rarityBump: row["rarity_bump"] as? Int ?? 0,
                    lat: row["lat"] as? Double,
                    lng: row["lng"] as? Double,
                    xpAwarded: row["xp_awarded"] as? Int ?? 0,
                    isFirstCatch: row["is_first_catch"] as? Bool ?? false
                )
            )
            pushedIDs.insert(id)
            recovered += 1
        }

        UserDefaults.standard.set(pushedIDs.map(\.uuidString), forKey: pushedKey)
        return recovered
    }
}
