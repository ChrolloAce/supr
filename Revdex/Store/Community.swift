import SwiftUI
import UIKit

// MARK: - Feed

/// One entry in the shared feed: either something a spotter wrote, or a catch
/// that landed. Both come from the database; nothing here is generated.
struct Post: Identifiable, Hashable {
    var id: String
    var deviceID: String
    var handle: String
    var city: String
    var text: String
    var imageURL: String?
    var date: Date
    var likes: Int
    var likedByMe: Bool
    var carID: Int?
    var avatarURL: String?
    /// A capture announcement rather than a written post.
    var isCatch: Bool

    var car: CarModel? { carID.flatMap { Catalog.byID[$0] } }
    var mine: Bool { deviceID == Backend.deviceID }
}

// MARK: - Crews

struct Crew: Identifiable, Hashable {
    var id: String
    var name: String
    var tag: String
    var city: String
    var members: Int
    var totalXP: Int
    var ownerID: String?
    var imageURL: String?
    var mine: Bool = false

    init(row: [String: Any], myCrewID: String?) {
        id = row["id"] as? String ?? UUID().uuidString
        name = row["name"] as? String ?? "Crew"
        tag = (row["tag"] as? String ?? "CRW").uppercased()
        city = (row["city"] as? String ?? "").uppercased()
        members = row["members"] as? Int ?? 1
        totalXP = row["total_xp"] as? Int ?? 0
        ownerID = row["owner_id"] as? String
        imageURL = row["image_url"] as? String
        mine = (myCrewID != nil && myCrewID == id)
    }
}

// MARK: - Store

/// Everything social, read straight from the database.
@MainActor
final class Community: ObservableObject {

    @Published private(set) var posts: [Post] = []
    @Published private(set) var crews: [Crew] = []
    @Published private(set) var board: [Rival] = []
    @Published private(set) var loadingFeed = false
    @Published private(set) var loadingCrews = false
    @Published private(set) var loadingBoard = false

    private let store: GameStore
    private let myCrewKey = "revdex.crew.id"

    private var myCrewID: String? {
        get { UserDefaults.standard.string(forKey: myCrewKey) }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: myCrewKey) }
            else { UserDefaults.standard.removeObject(forKey: myCrewKey) }
        }
    }

    init(store: GameStore) {
        self.store = store
    }

    var myCrew: Crew? { crews.first(where: \.mine) }

    // MARK: Feed

    /// The feed is what people chose to post. Catches land in your garage and
    /// on the map on their own; they only reach the feed if you write one.
    /// Rows left over from when catches auto-published are filtered out here.
    func loadFeed(global: Bool) async {
        loadingFeed = true
        defer { loadingFeed = false }

        async let postRows = Backend.select(
            "revdex_posts",
            query: "or=(is_catch.is.null,is_catch.eq.false)&order=created_at.desc&limit=80"
        )
        async let profileRows = Backend.select(
            "revdex_profiles",
            query: "select=device_id,handle,avatar_url&limit=500"
        )
        let (rows, profiles) = await (postRows, profileRows)

        var handles: [String: String] = [:]
        var avatars: [String: String] = [:]
        for row in profiles {
            guard let id = row["device_id"] as? String else { continue }
            if let handle = row["handle"] as? String { handles[id] = handle }
            if let avatar = row["avatar_url"] as? String { avatars[id] = avatar }
        }

        var built: [Post] = rows.compactMap { row in
            guard let id = row["id"] as? String, let device = row["device_id"] as? String else { return nil }
            return Post(
                id: id,
                deviceID: device,
                // The profile wins over the copy stored on the row, so a
                // rename shows up on everything the person has ever posted.
                handle: handles[device] ?? row["handle"] as? String ?? "spotter",
                city: (row["city"] as? String ?? "").uppercased(),
                text: row["body"] as? String ?? "",
                imageURL: row["image_url"] as? String,
                date: Backend.date(row["created_at"] as? String),
                likes: 0,
                likedByMe: false,
                carID: row["car_id"] as? Int,
                avatarURL: avatars[device],
                isCatch: row["is_catch"] as? Bool ?? false
            )
        }

        // One query for every like on the posts we just loaded.
        if !built.isEmpty {
            let ids = built.map(\.id).joined(separator: ",")
            let likeRows = await Backend.select(
                "revdex_post_likes",
                query: "post_id=in.(\(ids))&select=post_id,device_id&limit=5000"
            )
            var counts: [String: Int] = [:]
            var mine: Set<String> = []
            for row in likeRows {
                guard let post = row["post_id"] as? String else { continue }
                counts[post, default: 0] += 1
                if (row["device_id"] as? String) == Backend.deviceID { mine.insert(post) }
            }
            for i in built.indices {
                built[i].likes = counts[built[i].id] ?? 0
                built[i].likedByMe = mine.contains(built[i].id)
            }
        }

        built.removeAll { hidden.contains($0.id) }

        let city = store.profile.city.uppercased()
        posts = global ? built : built.filter { $0.city == city }
    }

    /// Optimistic, then written through. Works the same from the feed and from
    /// the opened post, because both read this one list.
    func toggleLike(_ post: Post) async {
        guard let i = posts.firstIndex(where: { $0.id == post.id }) else {
            await writeLike(postID: post.id, liked: !post.likedByMe)
            return
        }
        let nowLiked = !posts[i].likedByMe
        posts[i].likedByMe = nowLiked
        posts[i].likes = max(0, posts[i].likes + (nowLiked ? 1 : -1))
        await writeLike(postID: post.id, liked: nowLiked)
    }

    private func writeLike(postID: String, liked: Bool) async {
        if liked {
            await Backend.insert("revdex_post_likes", [[
                "post_id": postID,
                "device_id": Backend.deviceID
            ]])
        } else {
            await Backend.delete(
                "revdex_post_likes",
                query: "post_id=eq.\(postID)&device_id=eq.\(Backend.deviceID)"
            )
        }
    }

    /// Current like state for a post, so an opened post stays in step.
    func likeState(for id: String) -> (likes: Int, liked: Bool)? {
        posts.first { $0.id == id }.map { ($0.likes, $0.likedByMe) }
    }

    /// The longest a caption can be. A post is a picture of a car with a line
    /// under it, not an essay.
    static let captionLimit = 30

    @Published var posting = false

    func addPost(text: String, image: UIImage?, carID: Int?) async {
        posting = true
        defer { posting = false }

        var row: [String: Any] = [
            "device_id": Backend.deviceID,
            "handle": store.profile.handle.isEmpty ? "spotter" : store.profile.handle.lowercased(),
            "city": store.profile.city,
            "body": String(text.prefix(Self.captionLimit)),
            "is_catch": false
        ]
        if let carID { row["car_id"] = carID }
        if let image, let url = await Backend.upload(image, folder: "posts", maxSide: 1100) {
            row["image_url"] = url
        }
        await Backend.insert("revdex_posts", [row])
        await loadFeed(global: true)
    }

    /// Flags a post for review and hides it locally straight away, so the person
    /// who reported it does not have to keep looking at it.
    func report(_ post: Post, reason: String) async {
        await Backend.insert("revdex_reports", [[
            "post_id": post.id,
            "device_id": Backend.deviceID,
            "target_device_id": post.deviceID,
            "reason": reason
        ]])
        hidden.insert(post.id)
        posts.removeAll { $0.id == post.id }
    }

    /// Posts this person has reported or blocked, kept on device.
    @Published private(set) var hidden: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "revdex.hidden.posts") ?? []
    ) {
        didSet { UserDefaults.standard.set(Array(hidden), forKey: "revdex.hidden.posts") }
    }

    func deletePost(_ post: Post) async {
        guard post.mine, !post.isCatch else { return }
        await Backend.delete("revdex_posts", query: "id=eq.\(post.id)")
        posts.removeAll { $0.id == post.id }
    }


    // MARK: Crews

    func loadCrews(global: Bool) async {
        loadingCrews = true
        defer { loadingCrews = false }

        let rows = await Backend.select("revdex_crews", query: "order=total_xp.desc&limit=100")
        let all = rows.map { Crew(row: $0, myCrewID: myCrewID) }
        let city = store.profile.city.uppercased()
        crews = global ? all : all.filter { $0.city == city }
    }

    /// City defaults to wherever the founder is, because a crew without a place
    /// cannot be found by the people it is for.
    func createCrew(name: String, tag: String, city: String, image: UIImage? = nil) async {
        let id = UUID().uuidString.lowercased()
        let place = city.isEmpty ? store.profile.city : city

        var row: [String: Any] = [
            "id": id,
            "name": name,
            "tag": tag.uppercased(),
            "city": place.uppercased(),
            "owner_id": Backend.deviceID,
            "members": 1,
            "total_xp": store.profile.xp
        ]
        if let image, let url = await Backend.upload(image, folder: "crews", maxSide: 600) {
            row["image_url"] = url
        }
        await Backend.insert("revdex_crews", [row])
        await Backend.insert("revdex_crew_members", [[
            "crew_id": id,
            "device_id": Backend.deviceID
        ]])
        myCrewID = id
        await loadCrews(global: true)
    }

    func join(_ crew: Crew) async {
        if let current = myCrewID { await leave(crewID: current) }
        await Backend.insert("revdex_crew_members", [[
            "crew_id": crew.id,
            "device_id": Backend.deviceID
        ]])
        await Backend.upsert("revdex_crews", ["id": crew.id, "members": crew.members + 1])
        myCrewID = crew.id
        await loadCrews(global: true)
    }

    func leaveCrew() async {
        guard let id = myCrewID else { return }
        await leave(crewID: id)
        await loadCrews(global: true)
    }

    private func leave(crewID: String) async {
        await Backend.delete(
            "revdex_crew_members",
            query: "crew_id=eq.\(crewID)&device_id=eq.\(Backend.deviceID)"
        )
        if let crew = crews.first(where: { $0.id == crewID }) {
            await Backend.upsert("revdex_crews", ["id": crewID, "members": max(0, crew.members - 1)])
        }
        myCrewID = nil
    }

    // MARK: Board

    func loadBoard(global: Bool) async {
        loadingBoard = true
        defer { loadingBoard = false }

        // A fresh install writes a profile row before it has played, so the board
        // filters those out server side rather than showing a tail of empty names.
        let rows = await Backend.select("revdex_profiles", query: "xp=gt.0&order=xp.desc&limit=200")
        let all = rows.map(Rival.init(row:))
        let city = store.profile.city.uppercased()
        board = global ? all : all.filter { $0.city == city }
    }

    /// Where the player sits on the board that is currently loaded.
    func myRank() -> Int? {
        guard let index = board.firstIndex(where: \.isMe) else { return nil }
        return index + 1
    }
}
