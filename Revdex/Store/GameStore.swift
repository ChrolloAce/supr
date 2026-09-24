import SwiftUI
import CoreLocation
import UIKit

/// Everything the app knows, persisted to a JSON file in Application Support.
@MainActor
final class GameStore: ObservableObject {

    // MARK: Persisted state

    struct SaveFile: Codable {
        var profile = Profile()
        var captures: [Capture] = []
        var hunt: DailyHunt? = nil
        var onboarded = false
        var isPro = false
        var favouriteMakes: [String] = []
        var pushOptIn = false
        /// Achievement id to the moment it was unlocked.
        var unlocked: [String: Date] = [:]

        init(
            profile: Profile = Profile(),
            captures: [Capture] = [],
            hunt: DailyHunt? = nil,
            onboarded: Bool = false,
            isPro: Bool = false,
            favouriteMakes: [String] = [],
            pushOptIn: Bool = false,
            unlocked: [String: Date] = [:]
        ) {
            self.profile = profile
            self.captures = captures
            self.hunt = hunt
            self.onboarded = onboarded
            self.isPro = isPro
            self.favouriteMakes = favouriteMakes
            self.pushOptIn = pushOptIn
            self.unlocked = unlocked
        }

        /// Nothing in a save file is mandatory. A field added in a later build
        /// must never invalidate a file written by an earlier one.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            profile = try c.decodeIfPresent(Profile.self, forKey: .profile) ?? Profile()
            captures = try c.decodeIfPresent([Capture].self, forKey: .captures) ?? []
            hunt = try c.decodeIfPresent(DailyHunt.self, forKey: .hunt)
            onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
            isPro = try c.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
            favouriteMakes = try c.decodeIfPresent([String].self, forKey: .favouriteMakes) ?? []
            pushOptIn = try c.decodeIfPresent(Bool.self, forKey: .pushOptIn) ?? false
            unlocked = try c.decodeIfPresent([String: Date].self, forKey: .unlocked) ?? [:]
        }
    }

    @Published private(set) var profile = Profile()
    @Published private(set) var captures: [Capture] = []
    @Published private(set) var hunt: DailyHunt = DailyHunt.make(for: Days.index())
    @Published var onboarded = false
    @Published private(set) var isPro = false
    @Published var favouriteMakes: [String] = []
    @Published var pushOptIn = false
    @Published private(set) var unlocked: [String: Date] = [:]

    /// Set when a capture completes so the reveal sheet can show it.
    @Published var pendingReveal: RevealPayload? = nil
    /// Set when a catch crosses a level. The root view takes the screen over.
    @Published var pendingLevelUp: LevelUpView.Payload?

    struct RevealPayload: Identifiable {
        let id = UUID()
        let capture: Capture
        let isNew: Bool
        let leveledUp: Bool
        let newLevel: Int
        let huntCompleted: Bool
        let image: UIImage?
        var levelUp: LevelUpView.Payload? = nil
    }

    // MARK: Captures as currency

    /// A capture is the thing worth paying for, so it is metered.
    ///
    /// Free is deliberately small: enough to see what the app does, not enough
    /// to live on. Anything above that is either earned by watching an ad or
    /// bought with Pro.
    enum Quota {
        static let freeDaily = 3
        static let proWeekly = 250
        /// What one completed ad is worth.
        static let adReward = 3
    }

    /// Allowance left in the current period, before earned credits.
    private var allowanceLeft: Int {
        if isPro {
            let week = Days.week()
            if profile.weekIndex != week { return Quota.proWeekly }
            return max(0, Quota.proWeekly - profile.weeklyCaptureCount)
        }
        let today = Days.index()
        if profile.dailyCaptureDay != today { return Quota.freeDaily }
        return max(0, Quota.freeDaily - profile.dailyCaptureCount)
    }

    /// Allowance plus anything earned. This is what the camera checks.
    var capturesLeftToday: Int { allowanceLeft + profile.earnedCredits }

    var isOutOfCaptures: Bool { capturesLeftToday <= 0 }

    /// Earned credits shown separately, because they are the reward.
    var earnedCredits: Int { profile.earnedCredits }

    /// Developing spends from the same pot as capturing. A render is the most
    /// expensive thing the app does, so it cannot be free while catching is not.
    var canDevelop: Bool { capturesLeftToday > 0 }
    var developsLeft: Int { capturesLeftToday }

    /// When the allowance comes back.
    var quotaResetsIn: String {
        isPro ? "this week" : "tomorrow"
    }

    var quotaCeiling: Int { isPro ? Quota.proWeekly : Quota.freeDaily }

    /// Called after a completed ad. Credits are banked, not spent immediately,
    /// so someone can stack a few and then go out shooting.
    func grantAdReward() {
        profile.earnedCredits += Quota.adReward
        save()
    }

    /// Takes one capture off whatever is available, allowance first so earned
    /// credits are kept for when the free window is empty.
    func spendCapture() {
        let today = Days.index()
        let week = Days.week()

        if profile.dailyCaptureDay != today {
            profile.dailyCaptureDay = today
            profile.dailyCaptureCount = 0
        }
        if profile.weekIndex != week {
            profile.weekIndex = week
            profile.weeklyCaptureCount = 0
        }

        if allowanceLeft > 0 {
            profile.dailyCaptureCount += 1
            profile.weeklyCaptureCount += 1
        } else if profile.earnedCredits > 0 {
            profile.earnedCredits -= 1
        }
    }

    // MARK: Derived

    var caughtIDs: Set<Int> { Set(captures.map(\.carID)) }
    var dexCount: Int { caughtIDs.count }
    var dexTotal: Int { Catalog.total }

    /// Every catch, newest first. Two photos of the same model are two cards:
    /// they are two separate moments. Counting each model once is the dex's job.
    var garage: [Capture] {
        captures.sorted { $0.date > $1.date }
    }

    /// One entry per model, for anywhere that wants the collection rather than
    /// the history.
    var uniqueGarage: [Capture] {
        var seen = Set<Int>()
        var out: [Capture] = []
        for c in garage where !seen.contains(c.carID) {
            seen.insert(c.carID)
            out.append(c)
        }
        return out
    }

    /// One entry per kind of special caught, newest first. A second police car
    /// does not add a row; a fire engine does.
    var specials: [Capture] {
        var seen = Set<String>()
        var out: [Capture] = []
        for capture in garage {
            guard let variant = capture.variant?.lowercased() else { continue }
            guard !seen.contains(variant) else { continue }
            seen.insert(variant)
            out.append(capture)
        }
        return out
    }

    /// How many catches have been through the darkroom.
    var developedCount: Int { captures.filter(\.isDeveloped).count }

    func captures(of carID: Int) -> [Capture] {
        captures.filter { $0.carID == carID }.sorted { $0.date > $1.date }
    }

    func rarityCount(_ r: Rarity) -> Int {
        caughtIDs.compactMap { Catalog.byID[$0] }.filter { $0.rarity == r }.count
    }

    // MARK: Init

    init() {
        load()
        refreshDaily()
    }

    // MARK: Daily rollover

    func refreshDaily() {
        let today = Days.index()
        if hunt.day != today {
            hunt = DailyHunt.make(for: today)
        }
        // Streak decay: missing a full day resets it.
        if let last = profile.lastCaptureDay, today - last > 1, profile.streak != 0 {
            profile.streak = 0
        }
        save()
    }

    // MARK: Onboarding

    func completeOnboarding(handle: String, city: String, makes: [String]) {
        profile.handle = handle.isEmpty ? "SPOTTER" : handle.uppercased()
        profile.city = city.uppercased()
        favouriteMakes = makes
        onboarded = true
        save()
    }

    func setPro(_ value: Bool) {
        isPro = value
        save()
    }

    // MARK: Capturing

    /// Records a capture, awards XP, advances streak and daily hunt.
    @discardableResult
    func record(car: CarModel, image: UIImage?) -> RevealPayload {
        record(car: car, imageFile: image.flatMap { persistImage($0) })
    }

    /// Same as above but reuses a photo the scan queue already wrote to disk.
    @discardableResult
    func record(
        car: CarModel,
        imageFile file: String?,
        at coordinate: (lat: Double, lng: Double)? = nil,
        variant: String? = nil,
        spec: String? = nil,
        note: String? = nil,
        rarityBump: Int = 0
    ) -> RevealPayload {
        let today = Days.index()
        let isNew = !caughtIDs.contains(car.id)

        // A police interceptor pays like the rarity it actually is, not like
        // the base model it is built on.
        let tiers = Rarity.allCases
        let effective = tiers[min(tiers.count - 1, car.rarity.order + max(0, rarityBump))]

        var xp = effective.xp
        if isNew { xp += 50 }             // first catch bonus
        if rarityBump > 0 { xp += 40 * rarityBump }
        if !isNew { xp = max(8, xp / 4) } // duplicates are worth less

        var huntDone = false
        if !hunt.completed && hunt.isSatisfied(by: car, isNew: isNew) {
            hunt.completed = true
            huntDone = true
            xp += hunt.bonusXP
        }

        let beforeLevel = profile.level
        let beforeXP = profile.xp
        profile.xp += xp

        // Streak
        if profile.lastCaptureDay != today {
            if let last = profile.lastCaptureDay, today - last == 1 {
                profile.streak += 1
            } else {
                profile.streak = 1
            }
            profile.lastCaptureDay = today
        }

        spendCapture()

        // Only a place we actually know. A photo picked from the library has
        // wherever it was taken, or nothing at all: it must never inherit where
        // the phone is standing now, because that would put somebody else's car
        // on the map at your address.
        let capture = Capture(
            carID: car.id,
            date: Date(),
            city: profile.city.isEmpty ? "UNKNOWN" : profile.city,
            imageFile: file,
            variant: variant,
            spec: spec,
            note: note,
            rarityBump: rarityBump,
            lat: coordinate?.lat,
            lng: coordinate?.lng,
            xpAwarded: xp,
            isFirstCatch: isNew
        )
        captures.append(capture)
        save()
        syncAchievements()

        let leveled = profile.level > beforeLevel
        return RevealPayload(
            capture: capture,
            isNew: isNew,
            leveledUp: leveled,
            newLevel: profile.level,
            huntCompleted: huntDone,
            image: nil,
            levelUp: leveled ? LevelUpView.Payload(
                fromLevel: beforeLevel,
                toLevel: profile.level,
                xpBefore: beforeXP,
                xpAfter: profile.xp,
                xpGained: xp
            ) : nil
        )
    }

    // MARK: Achievements

    var unlockedAchievements: [Achievement] {
        unlocked.keys.compactMap { Achievements.achievement($0) }
    }

    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlocked[achievement.id] != nil
    }

    func unlockedAt(_ achievement: Achievement) -> Date? {
        unlocked[achievement.id]
    }

    var achievementStats: Achievement.Stats {
        Achievement.Stats(
            captures: captures,
            level: profile.level,
            streak: profile.streak,
            dexTotal: dexTotal
        )
    }

    /// Re-derives every achievement from the save and announces anything that
    /// just came true. Safe to call as often as you like: unlocks are recorded
    /// with a date and never fire twice.
    @discardableResult
    func syncAchievements(announce: Bool = true) -> [Achievement] {
        let stats = achievementStats
        var fresh: [Achievement] = []

        for achievement in Achievements.all
        where unlocked[achievement.id] == nil && achievement.isMet(stats) {
            unlocked[achievement.id] = Date()
            fresh.append(achievement)
        }

        guard !fresh.isEmpty else { return [] }
        save()
        if announce {
            for achievement in fresh { Notifier.shared.post(unlocked: achievement) }
        }
        return fresh
    }

    /// Adds a capture restored from the server without re-awarding XP.
    func adopt(_ capture: Capture) {
        guard !tombstones.contains(capture.id) else { return }
        guard !captures.contains(where: { $0.id == capture.id }) else { return }
        captures.append(capture)
        save()
    }

    /// Ids this device has deleted. Kept for good, because restore() reads the
    /// server and would otherwise pull a deleted catch back down on the next
    /// launch. Belt and braces alongside the remote delete: if the network is
    /// down when you delete, the catch still must not reappear.
    private(set) var tombstones: Set<UUID> = Set(
        (UserDefaults.standard.stringArray(forKey: "revdex.deleted") ?? []).compactMap(UUID.init)
    )

    /// Set by the app so a deletion also clears the server copy.
    var onCaptureDeleted: ((UUID) -> Void)?

    func deleteCapture(_ capture: Capture) {
        captures.removeAll { $0.id == capture.id }

        for file in [capture.imageFile, capture.developedFile, capture.renderedFile] {
            if let file {
                try? FileManager.default.removeItem(at: Self.imagesDir.appendingPathComponent(file))
            }
        }

        tombstones.insert(capture.id)
        UserDefaults.standard.set(tombstones.map(\.uuidString), forKey: "revdex.deleted")

        save()
        onCaptureDeleted?(capture.id)
    }

    func updateHandle(_ handle: String) {
        profile.handle = handle.uppercased()
        save()
    }

    func updateDisplayName(_ name: String) {
        profile.displayName = name.trimmingCharacters(in: .whitespaces)
        save()
    }

    func updateCity(_ city: String) {
        profile.city = city.uppercased()
        save()
    }

    // MARK: Personalisation

    func setAvatar(_ image: UIImage?) {
        if let old = profile.avatarFile {
            try? FileManager.default.removeItem(at: Self.imagesDir.appendingPathComponent(old))
        }
        profile.avatarFile = image.flatMap { persistImage($0) }
        save()
    }

    var avatarImage: UIImage? {
        guard let f = profile.avatarFile else { return nil }
        return UIImage(contentsOfFile: Self.imagesDir.appendingPathComponent(f).path)
    }

    func setFavouriteCar(_ id: Int?) {
        profile.favouriteCarID = id
        save()
    }

    var favouriteCar: CarModel? {
        guard let id = profile.favouriteCarID, caughtIDs.contains(id) else { return nil }
        return Catalog.byID[id]
    }

    #if DEBUG
    /// Debug builds only. Lets ranks and badges be exercised without grinding.
    func grantXP(_ amount: Int) {
        profile.xp = max(0, profile.xp + amount)
        save()
    }

    func setLevel(_ level: Int) {
        profile.xp = Levels.threshold(for: max(1, level))
        save()
    }

    /// Puts one of every catalog car in the garage.
    func unlockEverything() {
        let missing = Catalog.cars.filter { !caughtIDs.contains($0.id) }
        for car in missing {
            captures.append(Capture(
                carID: car.id,
                date: Date(),
                city: profile.city.isEmpty ? "TEST" : profile.city,
                imageFile: nil,
                xpAwarded: 0,
                isFirstCatch: true
            ))
        }
        save()
    }
    #endif

    func resetEverything() {
        try? FileManager.default.removeItem(at: Self.saveURL)
        try? FileManager.default.removeItem(at: Self.imagesDir)
        profile = Profile()
        captures = []
        onboarded = false
        isPro = false
        favouriteMakes = []
        unlocked = [:]
        hunt = DailyHunt.make(for: Days.index())
        save()
    }

    // MARK: Activity

    /// Things worth telling the player about, drawn only from their own data.
    func activity() -> [ActivityItem] {
        var out: [ActivityItem] = []
        let p = Levels.progress(xp: profile.xp)

        if !hunt.completed {
            out.append(.init(
                icon: "target",
                tint: Ink.accent,
                title: "Today's quest is open",
                detail: "\(hunt.headline) · +\(hunt.bonusXP) XP"
            ))
        }
        if profile.streak > 0 {
            out.append(.init(
                icon: "flame.fill",
                tint: Ink.accentSoft,
                title: "\(profile.streak) day streak",
                detail: "Capture something today to keep it alive."
            ))
        }
        out.append(.init(
            icon: "chart.line.uptrend.xyaxis",
            tint: Ink.done,
            title: "\(p.need - p.into) XP to LV \(p.level + 1)",
            detail: "Next rank: \(Ranks.next(after: p.level)?.name ?? profile.rankName)."
        ))
        for capture in captures.sorted(by: { $0.date > $1.date }).prefix(4) {
            out.append(.init(
                icon: "car.side.fill",
                tint: capture.car.rarity.color,
                title: "Caught a \(capture.car.model)",
                detail: "\(capture.car.rarity.title) · \(capture.city) · +\(capture.xpAwarded) XP"
            ))
        }
        if !isPro {
            out.append(.init(
                icon: "lock.fill",
                tint: Ink.dim,
                title: "\(capturesLeftToday) captures left today",
                detail: "Pro removes the daily cap."
            ))
        }
        return out
    }

    // MARK: Developing

    /// Captures currently being processed, so the UI can show a spinner.
    @Published private(set) var developing: Set<UUID> = []

    /// Set by the app so a changed capture can be re-uploaded.
    var onCaptureChanged: ((UUID) -> Void)?

    @discardableResult
    func develop(_ capture: Capture) async -> Bool {
        guard !developing.contains(capture.id),
              capturesLeftToday > 0,
              let original = image(for: capture) else { return false }

        // Charged up front, so a queue of develops cannot outrun the meter the
        // way a batch of captures used to.
        spendCapture()
        save()

        developing.insert(capture.id)
        defer { developing.remove(capture.id) }

        guard let output = await Developer.develop(original) else { return false }
        // Renders are opaque photographs, so JPEG rather than PNG.
        guard let file = persistImage(output.render) else { return false }

        guard let i = captures.firstIndex(where: { $0.id == capture.id }) else { return false }
        if let old = captures[i].developedFile {
            try? FileManager.default.removeItem(at: Self.imagesDir.appendingPathComponent(old))
        }
        captures[i].developedFile = file
        captures[i].wasCompleted = output.isRendered
        save()
        syncAchievements()
        onCaptureChanged?(capture.id)
        return true
    }

    /// Best available frame: AI render, then developed, then the original.
    func displayImage(for capture: Capture) -> UIImage? {
        renderedImage(for: capture) ?? developedImage(for: capture) ?? image(for: capture)
    }

    func renderedImage(for capture: Capture) -> UIImage? {
        guard let f = capture.renderedFile else { return nil }
        return UIImage(contentsOfFile: Self.imagesDir.appendingPathComponent(f).path)
    }

    /// Optional stylised pass through FLUX. Throws so the UI can show why it failed.
    func render(_ capture: Capture) async throws {
        guard let source = developedImage(for: capture) ?? image(for: capture) else { return }
        developing.insert(capture.id)
        defer { developing.remove(capture.id) }

        let out = try await Renderer.render(source)
        guard let file = persistImage(out),
              let i = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        if let old = captures[i].renderedFile {
            try? FileManager.default.removeItem(at: Self.imagesDir.appendingPathComponent(old))
        }
        captures[i].renderedFile = file
        save()
    }

    func developedImage(for capture: Capture) -> UIImage? {
        guard let f = capture.developedFile else { return nil }
        return UIImage(contentsOfFile: Self.imagesDir.appendingPathComponent(f).path)
    }

    func image(for capture: Capture) -> UIImage? {
        guard let f = capture.imageFile else { return nil }
        return UIImage(contentsOfFile: Self.imagesDir.appendingPathComponent(f).path)
    }

    // MARK: Image storage

    static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var saveURL: URL { supportDir.appendingPathComponent("revdex.json") }

    static var imagesDir: URL {
        let dir = supportDir.appendingPathComponent("captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Alpha preserving variant, used for stickers.
    func persistPNG(_ image: UIImage) -> String? {
        let name = "\(UUID().uuidString).png"
        let target: CGFloat = 1400
        let scale = min(1, target / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let scaled = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = scaled.pngData() else { return nil }
        do {
            try data.write(to: Self.imagesDir.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    func persistImage(_ image: UIImage) -> String? {
        let name = "\(UUID().uuidString).jpg"
        // Downscale so the library stays light.
        let target: CGFloat = 1400
        let scale = min(1, target / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let scaled = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = scaled.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: Self.imagesDir.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: Self.saveURL) else { return }

        guard let file = try? JSONDecoder().decode(SaveFile.self, from: data) else {
            // Keep the unreadable file instead of letting the next save stamp
            // over it, so a bad migration is recoverable rather than fatal.
            let backup = Self.supportDir.appendingPathComponent("revdex-unreadable.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: Self.saveURL, to: backup)
            return
        }
        profile = file.profile
        captures = file.captures
        hunt = file.hunt ?? DailyHunt.make(for: Days.index())
        onboarded = file.onboarded
        isPro = file.isPro
        favouriteMakes = file.favouriteMakes
        pushOptIn = file.pushOptIn
        unlocked = file.unlocked
    }

    func save() {
        let file = SaveFile(
            profile: profile,
            captures: captures,
            hunt: hunt,
            onboarded: onboarded,
            isPro: isPro,
            favouriteMakes: favouriteMakes,
            pushOptIn: pushOptIn,
            unlocked: unlocked
        )
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: Self.saveURL, options: .atomic)
    }
}
