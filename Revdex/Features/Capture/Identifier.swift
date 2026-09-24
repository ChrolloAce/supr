import UIKit
import Vision

/// Turns a photo into a car.
///
/// Stage 1 is real: Vision's built in scene classifier tells us whether there is a
/// vehicle in frame and roughly what shape it is.
/// Stage 2 picks the specific make and model from the catalog, weighted by street
/// rarity and by the body type Vision saw. Swapping in a trained Core ML model or a
/// server side recogniser later only means replacing `pickModel`.
enum Identifier {

    struct Result {
        let car: CarModel
        let confidence: Double
        let sawVehicle: Bool
        let detectedBody: BodyType?
        /// What made this particular vehicle unusual, when anything did.
        var variant: String? = nil
        var spec: String? = nil
        var note: String? = nil
        var rarityBump: Int = 0
    }

    // MARK: Vision pass

    private static let bodyKeywords: [(String, BodyType)] = [
        ("sports_car", .sports), ("race_car", .sports), ("supercar", .sports),
        ("convertible", .convertible), ("cabriolet", .convertible),
        ("coupe", .coupe),
        ("sport_utility_vehicle", .suv), ("suv", .suv), ("jeep", .suv), ("crossover", .suv),
        ("pickup", .truck), ("truck", .truck),
        ("hatchback", .hatch), ("station_wagon", .hatch), ("minivan", .hatch),
        ("sedan", .sedan), ("limousine", .sedan), ("taxi", .sedan)
    ]

    private static let vehicleKeywords = [
        "car", "vehicle", "automobile", "sedan", "coupe", "suv", "truck",
        "convertible", "hatchback", "jeep", "wheel", "bumper", "windshield", "tire"
    ]

    static func classify(_ image: UIImage) async -> (isVehicle: Bool, body: BodyType?, score: Double) {
        guard let cg = image.cgImage else { return (false, nil, 0) }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cg, orientation: cgOrientation(image.imageOrientation), options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: (false, nil, 0))
                    return
                }

                let observations = (request.results ?? [])
                    .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.6) }
                    .sorted { $0.confidence > $1.confidence }
                    .prefix(24)

                var best: BodyType? = nil
                var bestScore: Float = 0
                var vehicleScore: Float = 0

                for obs in observations {
                    let id = obs.identifier.lowercased()
                    if vehicleKeywords.contains(where: { id.contains($0) }) {
                        vehicleScore = max(vehicleScore, obs.confidence)
                    }
                    for (key, body) in bodyKeywords where id.contains(key) {
                        if obs.confidence > bestScore {
                            bestScore = obs.confidence
                            best = body
                        }
                    }
                }

                continuation.resume(returning: (vehicleScore > 0.12 || best != nil, best, Double(vehicleScore)))
            }
        }
    }

    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // MARK: Model pick

    /// Weighted draw over the catalog. Uncaught models and the makes the player
    /// follows get a nudge so the dex actually fills up.
    static func pickModel(
        body: BodyType?,
        caught: Set<Int>,
        favouriteMakes: [String],
        luckBoost: Double = 0
    ) -> CarModel {
        let pool: [CarModel] = {
            guard let body else { return Catalog.cars }
            let matched = Catalog.cars(body: body)
            return matched.count >= 6 ? matched : Catalog.cars
        }()

        var weights: [Double] = []
        for car in pool {
            var w = car.rarity.streetWeight
            if !caught.contains(car.id) { w *= 1.55 }              // favour fresh dex entries
            if favouriteMakes.contains(car.make) { w *= 1.9 }      // favour what the player follows
            if car.rarity >= .exotic { w *= (1 + luckBoost) }      // pro luck
            weights.append(w)
        }

        let total = weights.reduce(0, +)
        guard total > 0 else { return pool.randomElement() ?? Catalog.cars[0] }
        var roll = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            roll -= w
            if roll <= 0 { return pool[i] }
        }
        return pool.last ?? Catalog.cars[0]
    }

    // MARK: Remote recognition

    /// Asks the vision model what the car is, then maps the answer onto the
    /// catalog. Returns nil when there is no key, the call fails, or the car is
    /// not one we track, and the caller falls back to the on device path.
    static func remoteIdentify(_ image: UIImage) async -> Result? {
        guard let answer = await CarVision.identify(image) else { return nil }
        guard answer.isCar else {
            return Result(car: Catalog.cars[0], confidence: 0, sawVehicle: false, detectedBody: nil)
        }
        guard let car = match(make: answer.make, model: answer.model) else { return nil }

        return Result(
            car: car,
            confidence: max(0.6, answer.confidence),
            sawVehicle: true,
            detectedBody: answer.body,
            variant: answer.variant,
            spec: answer.spec,
            note: answer.note,
            rarityBump: answer.standout.bump
        )
    }

    /// Loose match so "Porsche 911 Carrera" still lands on the 911 entry.
    static func match(make: String?, model: String?) -> CarModel? {
        guard let make, !make.isEmpty else { return nil }
        let makeKey = normalise(make)
        let modelKey = normalise(model ?? "")

        let sameMake = Catalog.cars.filter {
            let m = normalise($0.make)
            return m.contains(makeKey) || makeKey.contains(m)
        }
        guard !sameMake.isEmpty else { return nil }
        guard !modelKey.isEmpty else { return sameMake.first }

        // Prefer the entry sharing the most words with the reported model, and
        // require at least one shared word so a Camry never becomes a Supra.
        let words = Set(modelKey.split(separator: " ").map(String.init))
        let ranked = sameMake
            .map { (car: $0, score: score(normalise($0.model), words)) }
            .sorted { $0.score > $1.score }

        guard let best = ranked.first, best.score > 0 else { return sameMake.first }
        return best.car
    }

    private static func normalise(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func score(_ candidate: String, _ words: Set<String>) -> Int {
        Set(candidate.split(separator: " ").map(String.init)).intersection(words).count
    }

    // MARK: Full run

    static func identify(
        image: UIImage?,
        caught: Set<Int>,
        favouriteMakes: [String],
        luckBoost: Double
    ) async -> Result {
        var sawVehicle = true
        var body: BodyType? = nil
        var score = 0.55

        if let image {
            let vision = await classify(image)
            sawVehicle = vision.isVehicle
            body = vision.body
            score = max(0.42, min(0.99, vision.score + 0.35))

            // The vision model wins whenever it is configured and answers.
            if let remote = await remoteIdentify(image) { return remote }
        }

        let car = pickModel(body: body, caught: caught, favouriteMakes: favouriteMakes, luckBoost: luckBoost)
        return Result(car: car, confidence: score, sawVehicle: sawVehicle, detectedBody: body)
    }
}
