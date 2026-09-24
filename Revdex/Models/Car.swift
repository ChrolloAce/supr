import SwiftUI

// MARK: - Rarity

enum Rarity: String, Codable, CaseIterable, Comparable {
    case common
    case uncommon
    case rare
    case exotic
    case legendary

    var title: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .exotic: return "Exotic"
        case .legendary: return "Legendary"
        }
    }

    /// A proper ladder rather than five purples. Purple stays the brand's
    /// middle rung, and the top two escalate away from it so a legendary is
    /// obvious across a grid.
    var color: Color {
        switch self {
        case .common: return Color(hex: 0x6B6B76)      // grey
        case .uncommon: return Color(hex: 0x3FA37A)    // green
        case .rare: return Color(hex: 0x8B5CF6)        // purple
        case .exotic: return Color(hex: 0xE5484D)      // red
        case .legendary: return Color(hex: 0xE8A317)   // gold
        }
    }

    /// Text and pips drawn on top of `color`.
    var onColor: Color {
        switch self {
        case .legendary: return Ink.onAccent
        default: return .white
        }
    }

    var pips: Int {
        switch self {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 3
        case .exotic: return 4
        case .legendary: return 5
        }
    }

    var xp: Int {
        switch self {
        case .common: return 25
        case .uncommon: return 60
        case .rare: return 140
        case .exotic: return 320
        case .legendary: return 750
        }
    }

    /// Rough odds of running into one on the street, used to weight the identifier.
    var streetWeight: Double {
        switch self {
        case .common: return 46
        case .uncommon: return 27
        case .rare: return 16
        case .exotic: return 8
        case .legendary: return 3
        }
    }

    var order: Int { Rarity.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.order < rhs.order }
}

// MARK: - Body type

enum BodyType: String, Codable, CaseIterable {
    case sports
    case sedan
    case suv
    case truck
    case coupe
    case hatch
    case convertible

    var title: String { rawValue.uppercased() }
}

// MARK: - Drivetrain

enum Drive: String, Codable, CaseIterable {
    case fwd, rwd, awd, four

    var title: String {
        switch self {
        case .fwd: return "FWD"
        case .rwd: return "RWD"
        case .awd: return "AWD"
        case .four: return "4WD"
        }
    }

    var long: String {
        switch self {
        case .fwd: return "Front wheel drive"
        case .rwd: return "Rear wheel drive"
        case .awd: return "All wheel drive"
        case .four: return "Four wheel drive"
        }
    }
}

// MARK: - What it burns

enum Fuel: String, Codable, CaseIterable {
    case gas, hybrid, plugin, electric, diesel

    var title: String {
        switch self {
        case .gas: return "Petrol"
        case .hybrid: return "Hybrid"
        case .plugin: return "Plug-in hybrid"
        case .electric: return "Electric"
        case .diesel: return "Diesel"
        }
    }

    var icon: String {
        switch self {
        case .gas: return "fuelpump.fill"
        case .hybrid, .plugin: return "leaf.fill"
        case .electric: return "bolt.fill"
        case .diesel: return "fuelpump"
        }
    }
}

// MARK: - Car

struct CarModel: Identifiable, Codable, Hashable {
    let id: Int          // dex number
    let make: String
    let model: String
    /// The model year of the car this entry depicts. Not a guess: it is the
    /// year of the exact generation and trim named above.
    let year: String
    let rarity: Rarity
    let body: BodyType
    let tint: UInt32     // signature colour for the glyph

    // MARK: Spec sheet
    //
    // Everything below is what a spotter argues about on the kerb. Zero means
    // the figure is not known for this car rather than the car being slow, and
    // the spec sheet leaves that row out rather than printing a zero.

    /// Generation, chassis or platform code: "992.2", "F80", "W223", "Mk8".
    /// Empty when a car genuinely has no code worth naming.
    let series: String
    /// Production run of this exact generation, "2016-2022" or "2020-present".
    let production: String
    /// Layout and displacement as it would be badged, "3.0L twin-turbo I6".
    let engine: String
    let power: Int          // hp
    let torque: Int         // lb-ft
    let drive: Drive
    /// Transmission as sold: "8-sp DCT", "6-sp manual", "1-sp reduction".
    let gearbox: String
    let sprint: Double      // 0-60 mph, seconds
    let topSpeed: Int       // mph
    let weight: Int         // curb weight, lb
    let seats: Int
    /// Base price when new, in US dollars.
    let msrp: Int
    let fuel: Fuel

    /// Defaults keep every field optional at the call site, so a car can be
    /// added with nothing but a name while the rest is filled in later.
    init(
        id: Int,
        make: String,
        model: String,
        year: String,
        rarity: Rarity,
        body: BodyType,
        tint: UInt32,
        series: String = "",
        production: String = "",
        engine: String = "",
        power: Int = 0,
        torque: Int = 0,
        drive: Drive = .rwd,
        gearbox: String = "",
        sprint: Double = 0,
        topSpeed: Int = 0,
        weight: Int = 0,
        seats: Int = 0,
        msrp: Int = 0,
        fuel: Fuel = .gas
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.rarity = rarity
        self.body = body
        self.tint = tint
        self.series = series
        self.production = production
        self.engine = engine
        self.power = power
        self.torque = torque
        self.drive = drive
        self.gearbox = gearbox
        self.sprint = sprint
        self.topSpeed = topSpeed
        self.weight = weight
        self.seats = seats
        self.msrp = msrp
        self.fuel = fuel
    }

    var dexNumber: String { String(format: "%03d", id) }
    var fullName: String { "\(make) \(model)" }
    var color: Color { Color(hex: tint) }

    // MARK: Formatted spec

    /// "992.2 · 2024-present", the line under the model name.
    var lineage: String {
        [series, production].filter { !$0.isEmpty }.joined(separator: "  ·  ")
    }

    var powerLine: String? { power > 0 ? "\(power) hp" : nil }
    var torqueLine: String? { torque > 0 ? "\(torque) lb-ft" : nil }
    var sprintLine: String? { sprint > 0 ? String(format: "%.1fs", sprint) : nil }
    var topSpeedLine: String? { topSpeed > 0 ? "\(topSpeed) mph" : nil }
    var weightLine: String? { weight > 0 ? "\(weight.formatted(.number.grouping(.automatic))) lb" : nil }
    var seatsLine: String? { seats > 0 ? "\(seats)" : nil }

    var priceLine: String? {
        guard msrp > 0 else { return nil }
        if msrp >= 1_000_000 {
            let millions = Double(msrp) / 1_000_000
            return String(format: millions < 10 ? "$%.2fM" : "$%.1fM", millions)
        }
        return "$\(msrp / 1000)k"
    }

    /// Power per ton, the number that actually decides how quick something
    /// feels. Nil when either half of the sum is missing.
    var powerToWeight: String? {
        guard power > 0, weight > 0 else { return nil }
        return "\(Int((Double(power) / (Double(weight) / 2000)).rounded())) hp/ton"
    }

    /// The headline pair on a card: what it makes and how fast it gets going.
    var punchline: String {
        [powerLine, sprintLine.map { "0-60 in \($0)" }]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
    }

    /// The whole sheet, in reading order, with unknown rows dropped.
    var specSheet: [(String, String)] {
        var rows: [(String, String)] = []
        if !series.isEmpty { rows.append(("Series", series)) }
        if !production.isEmpty { rows.append(("Built", production)) }
        rows.append(("Model year", year))
        if !engine.isEmpty { rows.append((fuel == .electric ? "Motors" : "Engine", engine)) }
        rows.append(("Fuel", fuel.title))
        if let powerLine { rows.append(("Power", powerLine)) }
        if let torqueLine { rows.append(("Torque", torqueLine)) }
        if let powerToWeight { rows.append(("Power to weight", powerToWeight)) }
        rows.append(("Drivetrain", drive.long))
        if !gearbox.isEmpty { rows.append(("Gearbox", gearbox)) }
        if let sprintLine { rows.append(("0-60 mph", sprintLine)) }
        if let topSpeedLine { rows.append(("Top speed", topSpeedLine)) }
        if let weightLine { rows.append(("Curb weight", weightLine)) }
        if let seatsLine { rows.append(("Seats", seatsLine)) }
        rows.append(("Body", body.title.capitalized))
        if let priceLine { rows.append(("Price new", priceLine)) }
        return rows
    }

    /// Paint colour knocked back toward neutral so a wall of cards does not
    /// read as a wall of neon.
    var bodyColor: Color { Catalog.blend(tint, toward: 0x8E9298, amount: 0.30) }

    /// A dimmer version of the same, used for small marks on dark chips.
    var shadowColor: Color { Catalog.blend(tint, toward: 0x14161A, amount: 0.45) }
}

// MARK: - Catalog

enum Catalog {
    /// The whole dex, generated by scripts/gen_catalog.py from the tables in
    /// scripts/catalog. Dex numbers are permanent, because a saved catch and
    /// every row in the database store the car by id, so the generator reads
    /// them back out of scripts/dex_ids.json rather than renumbering.
    static let cars: [CarModel] = allCars

    /// First entry wins, so a duplicated dex number can never take a catch
    /// away from the car it was recorded against.
    static let byID: [Int: CarModel] = Dictionary(cars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func car(_ id: Int) -> CarModel { byID[id] ?? cars[0] }

    static var total: Int { cars.count }

    static func cars(of rarity: Rarity) -> [CarModel] { cars.filter { $0.rarity == rarity } }

    static func cars(body: BodyType) -> [CarModel] { cars.filter { $0.body == body } }

    static let makes: [String] = Array(Set(cars.map(\.make))).sorted()

    /// Linear blend between two packed hex colours.
    static func blend(_ from: UInt32, toward: UInt32, amount: Double) -> Color {
        func channel(_ hex: UInt32, _ shift: UInt32) -> Double { Double((hex >> shift) & 0xFF) }
        let t = max(0, min(1, amount))
        let r = channel(from, 16) * (1 - t) + channel(toward, 16) * t
        let g = channel(from, 8) * (1 - t) + channel(toward, 8) * t
        let b = channel(from, 0) * (1 - t) + channel(toward, 0) * t
        return Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: 1)
    }
}
