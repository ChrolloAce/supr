import UIKit

/// Names the car in a photo using an OpenAI vision model.
///
/// This is the accurate path. When there is no key, the call fails, or the
/// answer is not a car in the catalog, `Identifier` quietly falls back to the
/// on device Vision classifier so a capture never fails outright.
enum CarVision {

    struct Answer {
        let isCar: Bool
        let make: String
        let model: String
        let year: String
        let body: BodyType?
        let confidence: Double
        /// What makes this one different from every other car of the model:
        /// a racing livery, a police conversion, a taxi, a wide body kit.
        let variant: String?
        /// The trim or package, where the badging says so.
        let spec: String?
        /// One line worth reading on the card.
        let note: String?
        /// How special the model tells us this particular vehicle is.
        let standout: Standout
    }

    /// How far above the base model a specific vehicle sits. A base Mini and a
    /// Red Bull show car are the same catalogue entry but nowhere near the same
    /// thing to run into on the street.
    enum Standout: String {
        case none, notable, rare, wild

        var bump: Int {
            switch self {
            case .none: return 0
            case .notable: return 1
            case .rare: return 2
            case .wild: return 3
            }
        }
    }

    private static let prompt = """
    Identify the vehicle in this photo. Reply with JSON only, no prose:
    {"is_car":bool,"make":string,"model":string,"year":string,\
    "body":"sports"|"sedan"|"suv"|"truck"|"coupe"|"hatch"|"convertible",\
    "confidence":number between 0 and 1,"variant":string,"spec":string,\
    "note":string,"standout":"none"|"notable"|"rare"|"wild"}

    make and model: the base vehicle. Use the specific model name, for example \
    "911 GT3 RS" rather than just "911", when you can read the badging.

    spec: the trim, package or engine if the badging shows it, otherwise "".

    variant: what makes THIS vehicle different from an ordinary one of the same \
    model. Racing or sponsor liveries, police, fire, ambulance, taxi, military, \
    tow truck, ice cream van, driving school, rally car, camouflaged prototype, \
    widebody or heavily modified builds, film cars, wraps. Name it plainly, for \
    example "Red Bull Racing livery", "Police interceptor", "New York taxi", \
    "Camouflaged test mule", "Widebody". Empty string if it is just a normal \
    road car.

    standout: how unusual this specific vehicle is to see on the street. \
    "none" for an ordinary road car. "notable" for a taxi, a driving school \
    car, a light wrap. "rare" for police, fire, ambulance, a proper widebody, \
    a rally car. "wild" for a race team livery, a camouflaged prototype, a film \
    car, a one off.

    note: one short sentence, under 90 characters, about what this vehicle is. \
    Empty string if there is nothing interesting to say.

    If there is no vehicle clearly visible, set is_car to false and leave the \
    other fields as empty strings.
    """

    static func identify(_ image: UIImage) async -> Answer? {
        guard let key = Secrets.openAIKey,
              let payload = jpegBase64(image),
              let url = URL(string: "https://api.openai.com/v1/chat/completions")
        else { return nil }

        let body: [String: Any] = [
            "model": Secrets.visionModel,
            "max_tokens": 320,
            "response_format": ["type": "json_object"],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(payload)"]]
                ]
            ]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let content = envelope.choices.first?.message.content,
              let inner = content.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(Payload.self, from: inner)
        else { return nil }

        func trimmed(_ value: String?) -> String? {
            let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }

        return Answer(
            isCar: parsed.is_car,
            make: parsed.make ?? "",
            model: parsed.model ?? "",
            year: parsed.year ?? "",
            body: parsed.body.flatMap { BodyType(rawValue: $0.lowercased()) },
            confidence: parsed.confidence ?? 0.8,
            variant: trimmed(parsed.variant),
            spec: trimmed(parsed.spec),
            note: trimmed(parsed.note),
            standout: Standout(rawValue: (parsed.standout ?? "none").lowercased()) ?? .none
        )
    }

    /// Shrink before upload. Vision models do not need a 12 megapixel frame and
    /// the smaller body keeps the call fast and cheap.
    private static func jpegBase64(_ image: UIImage) -> String? {
        let target: CGFloat = 768
        let scale = min(1, target / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let shrunk = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return shrunk.jpegData(compressionQuality: 0.82)?.base64EncodedString()
    }

    // MARK: Wire types

    private struct Envelope: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }

    private struct Payload: Decodable {
        let is_car: Bool
        let make: String?
        let model: String?
        let year: String?
        let body: String?
        let confidence: Double?
        let variant: String?
        let spec: String?
        let note: String?
        let standout: String?
    }
}
