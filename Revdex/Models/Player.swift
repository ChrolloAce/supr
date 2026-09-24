import Foundation

// MARK: - Capture record

struct Capture: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var carID: Int
    var date: Date
    var city: String
    var imageFile: String?     // filename inside the captures directory
    var developedFile: String? // the graded, plate masked version
    var renderedFile: String?  // optional stylised FLUX pass
    /// True when developedFile is a real showroom render rather than the
    /// censored photo standing in after a failed render. The key keeps its
    /// old name so existing saves and database rows still decode.
    var wasCompleted: Bool = false

    /// What made this one different: a livery, a police conversion, a taxi.
    var variant: String? = nil
    /// Trim or package, when the badging said so.
    var spec: String? = nil
    /// A line worth reading about this particular vehicle.
    var note: String? = nil
    /// Rarity earned by being unusual, above whatever the base model is worth.
    var rarityBump: Int = 0
    var lat: Double?           // where it was spotted
    var lng: Double?
    var xpAwarded: Int
    var isFirstCatch: Bool

    var isDeveloped: Bool { developedFile != nil }

    var car: CarModel { Catalog.car(carID) }

    /// A police interceptor is the same catalogue entry as a base Explorer but
    /// a much better thing to run into, so rarity is the model's floor plus
    /// whatever this particular vehicle earned.
    var rarity: Rarity {
        let all = Rarity.allCases
        let raised = min(all.count - 1, car.rarity.order + max(0, rarityBump))
        return all[raised]
    }

    /// True when this is something other than an ordinary road car.
    var isSpecial: Bool { variant != nil }

    /// What to call it: the model, plus what made it worth a second look.
    var displayName: String {
        guard let variant else { return car.fullName }
        return "\(car.fullName) · \(variant)"
    }

    /// The line under the name on a card.
    var subtitle: String? { spec ?? variant }

    init(
        id: UUID = UUID(),
        carID: Int,
        date: Date,
        city: String,
        imageFile: String? = nil,
        developedFile: String? = nil,
        renderedFile: String? = nil,
        wasCompleted: Bool = false,
        variant: String? = nil,
        spec: String? = nil,
        note: String? = nil,
        rarityBump: Int = 0,
        lat: Double? = nil,
        lng: Double? = nil,
        xpAwarded: Int,
        isFirstCatch: Bool
    ) {
        self.id = id
        self.carID = carID
        self.date = date
        self.city = city
        self.imageFile = imageFile
        self.developedFile = developedFile
        self.renderedFile = renderedFile
        self.wasCompleted = wasCompleted
        self.variant = variant
        self.spec = spec
        self.note = note
        self.rarityBump = rarityBump
        self.lat = lat
        self.lng = lng
        self.xpAwarded = xpAwarded
        self.isFirstCatch = isFirstCatch
    }

    /// Decoded field by field so a save written by an older build still loads
    /// once new fields are added. Synthesised decoding throws on a missing key
    /// even when the property has a default, which would wipe a real garage.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        carID = try c.decode(Int.self, forKey: .carID)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        city = try c.decodeIfPresent(String.self, forKey: .city) ?? ""
        imageFile = try c.decodeIfPresent(String.self, forKey: .imageFile)
        developedFile = try c.decodeIfPresent(String.self, forKey: .developedFile)
        renderedFile = try c.decodeIfPresent(String.self, forKey: .renderedFile)
        wasCompleted = try c.decodeIfPresent(Bool.self, forKey: .wasCompleted) ?? false
        variant = try c.decodeIfPresent(String.self, forKey: .variant)
        spec = try c.decodeIfPresent(String.self, forKey: .spec)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        rarityBump = try c.decodeIfPresent(Int.self, forKey: .rarityBump) ?? 0
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try c.decodeIfPresent(Double.self, forKey: .lng)
        xpAwarded = try c.decodeIfPresent(Int.self, forKey: .xpAwarded) ?? 0
        isFirstCatch = try c.decodeIfPresent(Bool.self, forKey: .isFirstCatch) ?? false
    }
}

// MARK: - Levelling

enum Levels {
    /// Total XP needed to have reached a given level.
    static func threshold(for level: Int) -> Int {
        guard level > 1 else { return 0 }
        // Smooth ramp: 250, 600, 1050, 1600, ...
        let n = Double(level - 1)
        return Int((125 * n * n + 125 * n).rounded())
    }

    static func level(forXP xp: Int) -> Int {
        var lv = 1
        while threshold(for: lv + 1) <= xp { lv += 1 }
        return lv
    }

    static func progress(xp: Int) -> (level: Int, into: Int, need: Int, fraction: Double) {
        let lv = level(forXP: xp)
        let base = threshold(for: lv)
        let next = threshold(for: lv + 1)
        let into = xp - base
        let need = max(1, next - base)
        return (lv, into, need, Double(into) / Double(need))
    }

    static func title(for level: Int) -> String { Ranks.rank(for: level).name }
}

// MARK: - Daily hunt

struct DailyHunt: Codable, Equatable {
    var day: Int              // day-of-era so we can detect rollover
    var kind: Kind
    var payload: String
    var completed: Bool
    var bonusXP: Int

    enum Kind: String, Codable {
        case newModel, rarityAtLeast, specificMake, bodyType
    }

    init(day: Int, kind: Kind, payload: String, completed: Bool, bonusXP: Int) {
        self.day = day
        self.kind = kind
        self.payload = payload
        self.completed = completed
        self.bonusXP = bonusXP
    }

    /// Tolerant like the rest: a hunt that fails to read is regenerated rather
    /// than taking the whole save file down with it.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decodeIfPresent(Int.self, forKey: .day) ?? Days.index()
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .newModel
        payload = try c.decodeIfPresent(String.self, forKey: .payload) ?? ""
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        bonusXP = try c.decodeIfPresent(Int.self, forKey: .bonusXP) ?? 150
    }

    var headline: String {
        switch kind {
        case .newModel: return "A model you haven't caught"
        case .rarityAtLeast: return "Anything \(payload) or better"
        case .specificMake: return "Any \(payload)"
        case .bodyType: return "Any \(payload.lowercased())"
        }
    }

    static func make(for day: Int) -> DailyHunt {
        var rng = SeededRandom(seed: UInt64(day) &* 6364136223846793005)
        let roll = rng.next(upTo: 4)
        switch roll {
        case 0:
            return .init(day: day, kind: .newModel, payload: "", completed: false, bonusXP: 150)
        case 1:
            let r: Rarity = [.rare, .exotic][Int(rng.next(upTo: 2))]
            return .init(day: day, kind: .rarityAtLeast, payload: r.title.uppercased(), completed: false, bonusXP: r == .exotic ? 260 : 160)
        case 2:
            let make = Catalog.makes[Int(rng.next(upTo: UInt64(Catalog.makes.count)))]
            return .init(day: day, kind: .specificMake, payload: make.uppercased(), completed: false, bonusXP: 180)
        default:
            let body = BodyType.allCases[Int(rng.next(upTo: UInt64(BodyType.allCases.count)))]
            return .init(day: day, kind: .bodyType, payload: body.title, completed: false, bonusXP: 120)
        }
    }

    func isSatisfied(by car: CarModel, isNew: Bool) -> Bool {
        switch kind {
        case .newModel: return isNew
        case .rarityAtLeast:
            guard let target = Rarity.allCases.first(where: { $0.title.uppercased() == payload }) else { return false }
            return car.rarity >= target
        case .specificMake: return car.make.uppercased() == payload
        case .bodyType: return car.body.title == payload
        }
    }
}

// MARK: - Player profile

struct Profile: Codable {
    var handle: String = ""
    var displayName: String = ""
    var city: String = ""
    var xp: Int = 0
    var streak: Int = 0
    var lastCaptureDay: Int? = nil
    var joined: Date = Date()
    var dailyCaptureDay: Int = 0
    var dailyCaptureCount: Int = 0
    /// Pro is metered by the week rather than the day.
    var weekIndex: Int = 0
    var weeklyCaptureCount: Int = 0
    /// Credits earned by watching an ad. They do not expire, which is the
    /// whole appeal of earning them.
    var earnedCredits: Int = 0
    var avatarFile: String? = nil
    var favouriteCarID: Int? = nil

    var level: Int { Levels.level(forXP: xp) }
    var rank: Rank { Ranks.rank(for: level) }
    var rankName: String { rank.name }

    init() {}

    /// Every field is optional on the way in, so a profile written by an older
    /// build still loads once a new field is added. Synthesised decoding throws
    /// on a missing key even when the property has a default, which would reset
    /// the player to a blank slate.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        handle = try c.decodeIfPresent(String.self, forKey: .handle) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        city = try c.decodeIfPresent(String.self, forKey: .city) ?? ""
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        lastCaptureDay = try c.decodeIfPresent(Int.self, forKey: .lastCaptureDay)
        joined = try c.decodeIfPresent(Date.self, forKey: .joined) ?? Date()
        dailyCaptureDay = try c.decodeIfPresent(Int.self, forKey: .dailyCaptureDay) ?? 0
        dailyCaptureCount = try c.decodeIfPresent(Int.self, forKey: .dailyCaptureCount) ?? 0
        weekIndex = try c.decodeIfPresent(Int.self, forKey: .weekIndex) ?? 0
        weeklyCaptureCount = try c.decodeIfPresent(Int.self, forKey: .weeklyCaptureCount) ?? 0
        earnedCredits = try c.decodeIfPresent(Int.self, forKey: .earnedCredits) ?? 0
        avatarFile = try c.decodeIfPresent(String.self, forKey: .avatarFile)
        favouriteCarID = try c.decodeIfPresent(Int.self, forKey: .favouriteCarID)
    }
}

// MARK: - Deterministic RNG (so daily hunts and rivals stay stable)

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func nextUInt() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func next(upTo bound: UInt64) -> UInt64 {
        guard bound > 0 else { return 0 }
        return nextUInt() % bound
    }

    mutating func nextDouble() -> Double {
        Double(nextUInt() % 1_000_000) / 1_000_000
    }
}

// MARK: - Day helpers

enum Days {
    static func index(_ date: Date = Date()) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86_400)
    }

    /// Rolling seven day buckets, used for the Pro allowance.
    static func week(_ date: Date = Date()) -> Int {
        index(date) / 7
    }
}
