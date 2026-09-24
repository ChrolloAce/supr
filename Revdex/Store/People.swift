import SwiftUI
import UIKit

/// Everything about a spotter that the app can show: their profile, what they
/// have caught, what they have posted, and who follows whom.
@MainActor
final class People: ObservableObject {

    struct Person: Identifiable, Equatable {
        var id: String            // device id
        var handle: String
        var displayName: String
        var city: String
        var xp: Int
        var level: Int
        var rankName: String
        var avatarURL: String?
        var favouriteCarID: Int?
        var isPro: Bool

        var isMe: Bool { id == Backend.deviceID }
        var rank: Rank { Ranks.rank(for: level) }
        var name: String { displayName.isEmpty ? "@\(handle)" : displayName }

        init(row: [String: Any]) {
            id = row["device_id"] as? String ?? ""
            handle = row["handle"] as? String ?? "spotter"
            displayName = row["display_name"] as? String ?? ""
            city = (row["city"] as? String ?? "").uppercased()
            xp = row["xp"] as? Int ?? 0
            level = row["level"] as? Int ?? Levels.level(forXP: xp)
            rankName = row["rank_name"] as? String ?? Ranks.rank(for: level).name
            avatarURL = row["avatar_url"] as? String
            favouriteCarID = row["favourite_car"] as? Int
            isPro = row["is_pro"] as? Bool ?? false
        }
    }

    /// A capture belonging to someone, as shown on their garage grid.
    struct Catch: Identifiable, Equatable {
        let id: String
        let carID: Int
        let stickerURL: String?
        let photoURL: String?
        let date: Date
        var car: CarModel { Catalog.car(carID) }
    }

    @Published private(set) var person: Person?
    @Published private(set) var catches: [Catch] = []
    @Published private(set) var posts: [Post] = []
    @Published private(set) var followers = 0
    @Published private(set) var following = 0
    @Published private(set) var iFollow = false
    @Published private(set) var loading = false

    /// Loads a whole profile page in one pass.
    func load(deviceID: String) async {
        loading = true
        defer { loading = false }

        async let profileRows = Backend.select("revdex_profiles", query: "device_id=eq.\(deviceID)&limit=1")
        async let catchRows = Backend.select(
            "revdex_captures",
            query: "device_id=eq.\(deviceID)&select=id,car_id,photo_url,sticker_url,caught_at&order=caught_at.desc&limit=200"
        )
        async let postRows = Backend.select(
            "revdex_posts",
            query: "device_id=eq.\(deviceID)&order=created_at.desc&limit=50"
        )
        async let followerRows = Backend.select("revdex_follows", query: "following_id=eq.\(deviceID)&select=follower_id")
        async let followingRows = Backend.select("revdex_follows", query: "follower_id=eq.\(deviceID)&select=following_id")

        let (profiles, caught, written, followerList, followingList) =
            await (profileRows, catchRows, postRows, followerRows, followingRows)

        person = profiles.first.map(Person.init(row:))

        catches = caught.compactMap { row in
            guard let id = row["id"] as? String,
                  let carID = row["car_id"] as? Int,
                  Catalog.byID[carID] != nil else { return nil }
            return Catch(
                id: id,
                carID: carID,
                stickerURL: row["sticker_url"] as? String,
                photoURL: row["photo_url"] as? String,
                date: Backend.date(row["caught_at"] as? String)
            )
        }

        let handle = person?.handle ?? "spotter"
        posts = written.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return Post(
                id: id,
                deviceID: deviceID,
                handle: handle,
                city: (row["city"] as? String ?? "").uppercased(),
                text: row["body"] as? String ?? "",
                imageURL: row["image_url"] as? String,
                date: Backend.date(row["created_at"] as? String),
                likes: 0,
                likedByMe: false,
                carID: row["car_id"] as? Int,
                avatarURL: person?.avatarURL,
                isCatch: row["is_catch"] as? Bool ?? false
            )
        }

        followers = followerList.count
        following = followingList.count
        iFollow = followerList.contains { ($0["follower_id"] as? String) == Backend.deviceID }
    }

    func toggleFollow(_ deviceID: String) async {
        guard deviceID != Backend.deviceID else { return }
        if iFollow {
            iFollow = false
            followers = max(0, followers - 1)
            await Backend.delete(
                "revdex_follows",
                query: "follower_id=eq.\(Backend.deviceID)&following_id=eq.\(deviceID)"
            )
        } else {
            iFollow = true
            followers += 1
            await Backend.insert("revdex_follows", [[
                "follower_id": Backend.deviceID,
                "following_id": deviceID
            ]])
        }
    }
}

/// Small in memory cache so map pins and grids do not refetch the same sticker.
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    /// Memory first, then a file on disk, then the network. The disk layer is
    /// what stops the feed re-downloading everything on every cold launch.
    private let memory = NSCache<NSString, UIImage>()
    /// One task per URL. Two cells asking for the same picture share a single
    /// download and both get the result; the previous version handed the second
    /// caller nil and it never retried, which is why the feed looked stuck.
    private var tasks: [String: Task<UIImage?, Never>] = [:]

    private let dir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("supr-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private init() {
        memory.countLimit = 300
        memory.totalCostLimit = 120 * 1024 * 1024
    }

    private func file(for url: String) -> URL {
        // A stable, filesystem safe name for an arbitrary URL.
        var hash: UInt64 = 5381
        for byte in url.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        return dir.appendingPathComponent(String(hash, radix: 36))
    }

    func cached(_ url: String) -> UIImage? {
        memory.object(forKey: url as NSString)
    }

    func load(_ url: String) async -> UIImage? {
        if let hit = cached(url) { return hit }

        if let existing = tasks[url] { return await existing.value }

        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }

            // Disk before network.
            let path = self.file(for: url)
            if let data = try? Data(contentsOf: path), let image = UIImage(data: data) {
                self.keep(image, for: url)
                return image
            }

            guard let image = await Backend.download(url) else { return nil }
            if let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() {
                try? data.write(to: path, options: .atomic)
            }
            self.keep(image, for: url)
            return image
        }

        tasks[url] = task
        let result = await task.value
        tasks[url] = nil
        return result
    }

    private func keep(_ image: UIImage, for url: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        memory.setObject(image, forKey: url as NSString, cost: cost)
    }

    /// Wipes the on-disk copies. Memory survives, so nothing visible flickers.
    func purgeDisk() {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}

/// Loads a remote image once and keeps it.
struct RemoteImage<Placeholder: View>: View {
    let url: String?
    var contentMode: ContentMode = .fit
    @ViewBuilder var placeholder: Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            if let hit = ImageCache.shared.cached(url) { image = hit; return }
            let loaded = await ImageCache.shared.load(url)
            // The cell may have been recycled onto another post by now.
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) { image = loaded }
        }
    }
}
