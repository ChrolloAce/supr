import SwiftUI
import UIKit

/// Shots are queued and identified off the shutter, so the camera never blocks.
///
/// The queue is written to disk the moment a photo lands, which means a scan
/// that was still running when the app was killed picks up again on next launch
/// instead of losing the shot. Identification itself runs on device; when a real
/// recognition service exists, `process` is the single call to redirect.
@MainActor
final class ScanQueue: ObservableObject {

    struct Item: Identifiable, Codable, Hashable {
        var id: UUID = UUID()
        var imageFile: String?
        var queuedAt: Date = Date()
        /// Where the shot was taken. Nil means we do not know, and a catch
        /// without a known place never reaches the map.
        var lat: Double?
        var lng: Double?
    }

    /// A finished scan waiting to be acknowledged in the UI.
    struct Outcome: Identifiable, Equatable {
        let id = UUID()
        let capture: Capture?
        let isNew: Bool
        let leveledUp: Bool
        let newLevel: Int
        let questCompleted: Bool
        let rejected: Bool
        var levelUp: LevelUpView.Payload? = nil

        static func == (a: Outcome, b: Outcome) -> Bool { a.id == b.id }
    }

    @Published private(set) var pending: [Item] = []
    @Published var outcome: Outcome?

    private var working = false
    private let store: GameStore
    /// Set once the app builds it, so a finished scan can go straight up.
    var sync: Sync?

    init(store: GameStore) {
        self.store = store
        load()
        // Anything left over from a previous launch resumes right away.
        drain()
    }

    var isBusy: Bool { working || !pending.isEmpty }

    // MARK: Rate limiting

    /// Why a shot was turned away. Identification costs a network call and a
    /// row in the database, so a burst has to be stopped at the door rather
    /// than after the fact.
    enum Refusal: Equatable {
        case tooFast(seconds: Int)
        case backlog
        case noCaptures

        var message: String {
            switch self {
            case .tooFast(let seconds):
                return seconds >= 60
                    ? "Slow down. Try again in \(seconds / 60) min"
                    : "Slow down. Try again in \(seconds)s"
            case .backlog:
                return "Too many scans running. Wait for these to finish"
            case .noCaptures:
                return "Out of captures"
            }
        }
    }

    private enum Limit {
        /// A real spotter fires a few times at one car, not thirty. Set above
        /// a full ten photo library import so bulk adding never trips it on
        /// its own.
        static let perMinute = 20
        static let perHour = 120
        /// Waiting on more than this is a sign something is wrong anyway.
        static let queued = 14
    }

    /// Timestamps of accepted shots, kept across launches so quitting the app
    /// is not a way around the limit.
    private var stamps: [Date] = []
    private static let stampsKey = "revdex.scan.stamps"

    /// Set when a shot is turned away, cleared by the UI once shown.
    @Published var refusal: Refusal?

    private func trim(_ now: Date) {
        stamps.removeAll { now.timeIntervalSince($0) > 3600 }
    }

    /// Nil when the shot is allowed.
    private func refusalFor(_ now: Date) -> Refusal? {
        // A queued shot has not spent its capture yet: that happens when the
        // scan lands. So the allowance has to account for what is already in
        // flight, otherwise adding ten photos with two captures left lets all
        // ten through and the limit means nothing.
        guard store.capturesLeftToday - pending.count > 0 else { return .noCaptures }

        guard pending.count < Limit.queued else { return .backlog }

        let lastMinute = stamps.filter { now.timeIntervalSince($0) <= 60 }
        if lastMinute.count >= Limit.perMinute, let oldest = lastMinute.min() {
            return .tooFast(seconds: max(1, Int(60 - now.timeIntervalSince(oldest)) + 1))
        }
        if stamps.count >= Limit.perHour, let oldest = stamps.min() {
            return .tooFast(seconds: max(1, Int(3600 - now.timeIntervalSince(oldest)) + 1))
        }
        return nil
    }

    // MARK: Enqueue

    /// Hands a shot to the queue and returns immediately. False means the shot
    /// was refused; `refusal` says why.
    @discardableResult
    func enqueue(_ image: UIImage?, at coordinate: (lat: Double, lng: Double)? = nil) -> Bool {
        let now = Date()
        trim(now)

        if let refused = refusalFor(now) {
            refusal = refused
            Buzz.nope()
            return false
        }

        stamps.append(now)
        UserDefaults.standard.set(
            stamps.map(\.timeIntervalSince1970), forKey: Self.stampsKey
        )

        let file = image.flatMap { store.persistImage($0) }
        pending.append(Item(imageFile: file, lat: coordinate?.lat, lng: coordinate?.lng))
        save()
        drain()
        return true
    }

    /// Adds several shots at once, stopping at the first refusal so the rest of
    /// a big library selection is not silently dropped without explanation.
    @discardableResult
    func enqueue(_ images: [(image: UIImage, coordinate: (lat: Double, lng: Double)?)]) -> Int {
        var accepted = 0
        for item in images {
            guard enqueue(item.image, at: item.coordinate) else { break }
            accepted += 1
        }
        return accepted
    }

    func thumbnail(for item: Item) -> UIImage? {
        guard let f = item.imageFile else { return nil }
        return UIImage(contentsOfFile: GameStore.imagesDir.appendingPathComponent(f).path)
    }

    // MARK: Drain

    private func drain() {
        guard !working, let next = pending.first else { return }
        working = true

        Task {
            let result = await process(next)

            // The item is only dropped once its result is committed, so a crash
            // mid-scan leaves the shot in the queue rather than losing it.
            pending.removeFirst()
            save()
            outcome = result
            working = false

            if result.rejected {
                Buzz.nope()
            } else {
                Buzz.win()
                // The takeover runs once the scan lands, not at the shutter,
                // because that is the moment the XP actually exists.
                if let levelUp = result.levelUp,
                   !UserDefaults.standard.bool(forKey: LevelUpView.skipKey) {
                    store.pendingLevelUp = levelUp
                }
                if let sync { Task { await sync.pushCaptures() } }
            }

            drain()
        }
    }

    private func process(_ item: Item) async -> Outcome {
        let image = item.imageFile.flatMap {
            UIImage(contentsOfFile: GameStore.imagesDir.appendingPathComponent($0).path)
        }

        let result = await Identifier.identify(
            image: image,
            caught: store.caughtIDs,
            favouriteMakes: store.favouriteMakes,
            luckBoost: store.isPro ? 0.35 : 0
        )

        guard result.sawVehicle else {
            if let f = item.imageFile {
                try? FileManager.default.removeItem(at: GameStore.imagesDir.appendingPathComponent(f))
            }
            return Outcome(capture: nil, isNew: false, leveledUp: false, newLevel: 0, questCompleted: false, rejected: true, levelUp: nil)
        }

        let here = item.lat.flatMap { lat in item.lng.map { (lat, $0) } }
        let payload = store.record(
            car: result.car,
            imageFile: item.imageFile,
            at: here,
            variant: result.variant,
            spec: result.spec,
            note: result.note,
            rarityBump: result.rarityBump
        )
        return Outcome(
            capture: payload.capture,
            isNew: payload.isNew,
            leveledUp: payload.leveledUp,
            newLevel: payload.newLevel,
            questCompleted: payload.huntCompleted,
            rejected: false,
            levelUp: payload.levelUp
        )
    }

    // MARK: Persistence

    private static var url: URL { GameStore.supportDir.appendingPathComponent("scanqueue.json") }

    private func load() {
        if let raw = UserDefaults.standard.array(forKey: Self.stampsKey) as? [TimeInterval] {
            stamps = raw.map(Date.init(timeIntervalSince1970:))
            trim(Date())
        }
        guard let data = try? Data(contentsOf: Self.url),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return }
        pending = items
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        try? data.write(to: Self.url, options: .atomic)
    }
}
