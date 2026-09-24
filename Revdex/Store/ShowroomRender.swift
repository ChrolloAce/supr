import UIKit

/// Turns a street photo into a showroom shot of the same car.
///
/// Every render comes out the same way: the car side on, nose to the left, on a
/// pale seamless backdrop over polished concrete. That consistency is the point.
/// A garage full of cars all shot at the same angle in the same room reads as a
/// collection; a garage of phone snaps taken from wherever you happened to be
/// standing reads as a camera roll.
///
/// The car itself is not invented. The source photo goes in as the reference, so
/// the model, paint, wheels and trim come back as they were; only the viewpoint
/// and the room are normalised.
enum ShowroomRender {

    enum Failure: LocalizedError {
        case noKey
        case refused(String)
        case network(String)

        var errorDescription: String? {
            switch self {
            case .noKey:
                return "No OpenAI key set, so renders are off."
            case .refused(let why):
                return why
            case .network(let why):
                return why
            }
        }
    }

    /// Written as a shot brief rather than a wish list, because the model
    /// follows a described photograph more reliably than a pile of adjectives.
    private static let prompt = """
    Studio photograph of this exact car in a bright white industrial showroom.

    ORIENTATION, THE MOST IMPORTANT RULE: the car must face LEFT. Its nose, \
    headlights and grille point to the LEFT edge of the frame. Its rear, boot \
    and tail lights are on the RIGHT. You are looking at the front three \
    quarter of the driver's side. If the source photograph shows the car facing \
    right, mirror it so that it faces left. Never output a car facing right.

    Camera: front three quarter, at headlight height, level, lens around 50mm, \
    the whole vehicle inside the frame with air around it.

    The room: a large empty white gallery warehouse. Clean white walls, white \
    structural columns, and an exposed industrial ceiling of long linear \
    fluorescent strip lights running front to back between white ceiling panels \
    and visible pipework. Polished pale grey concrete floor, wide and open, with \
    soft mirror reflections of the car and the ceiling lights on it. Bright, \
    cool, even daylight. High key, almost white overall, deep perspective into \
    the room behind the car.

    Keep the car exactly as it is: the same model, body shape, paint colour and \
    finish, the same wheels, the same trim and badges, the same ride height. Do \
    not restyle it, do not change the colour, do not add parts it does not have. \
    If the photograph cuts the car off, complete the missing bodywork in the \
    same style.

    Nothing else in the room. No people, no other cars, no signage, no watermark, \
    no text of any kind. The number plate must be blank or absent, never \
    readable.

    Check before you finish: is the nose pointing LEFT? If not, mirror it.
    """

    /// A wide frame, because cars are wider than they are tall and a square
    /// crop wastes half the picture on empty wall.
    private static let size = "1536x1024"

    static func render(_ photo: UIImage) async throws -> UIImage {
        guard let key = Secrets.openAIKey else { throw Failure.noKey }
        guard let url = URL(string: "https://api.openai.com/v1/images/edits") else {
            throw Failure.network("Bad endpoint")
        }
        guard let source = png(photo, maxSide: 1024) else {
            throw Failure.network("Could not encode the photo")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Image generation is slow. Well under the background task budget, but
        // far longer than a normal API call.
        request.timeoutInterval = 180
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let boundary = "supr-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        field("model", "gpt-image-1")
        field("prompt", prompt)
        field("size", size)
        field("quality", "high")
        field("output_format", "png")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"car.png\"\r\n")
        body.append("Content-Type: image/png\r\n\r\n")
        body.append(source)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw Failure.network(error.localizedDescription)
        }

        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            throw Failure.refused(message(from: data, code: code))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]],
              let b64 = items.first?["b64_json"] as? String,
              let raw = Data(base64Encoded: b64),
              let image = UIImage(data: raw)
        else {
            throw Failure.network("The render came back unreadable.")
        }

        return image
    }

    /// OpenAI's errors are useful; surfacing them beats a generic failure.
    private static func message(from data: Data, code: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let text = error["message"] as? String {
            return text
        }
        return "The render failed (\(code))."
    }

    private static func png(_ image: UIImage, maxSide: CGFloat) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }

        let scale = min(1, maxSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let flat = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return flat.pngData()
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
