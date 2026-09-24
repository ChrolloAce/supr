import UIKit

/// Rebuilds a car that ran off the edge of the frame.
///
/// Only used when the lifted cutout touches the picture border, which means the
/// missing bodywork is genuinely not in the photo. The car it returns is drawn,
/// not photographed, so it is deliberately reserved for that one case.
enum CarCompletion {

    private static let prompt = """
    Complete this car so the entire vehicle is visible from the same angle. \
    Keep the existing bodywork, paint colour, wheels and proportions exactly as \
    they are and only draw the parts of the car that are missing from the frame. \
    Fully transparent background, no scenery, no ground, no shadow, product \
    cutout style. Do not add any readable text or number plate characters.
    """

    static func complete(_ cutout: UIImage) async -> UIImage? {
        guard let key = Secrets.openAIKey,
              let url = URL(string: "https://api.openai.com/v1/images/edits") else { return nil }

        let side: CGFloat = 1024
        guard let (canvas, mask) = prepare(cutout, side: side),
              let canvasData = canvas.pngData(),
              let maskData = mask.pngData() else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let boundary = "revdex-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        func file(_ name: String, _ filename: String, _ data: Data) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
            body.append("Content-Type: image/png\r\n\r\n")
            body.append(data)
            body.append("\r\n")
        }

        field("model", "gpt-image-1")
        field("prompt", prompt)
        field("size", "1024x1024")
        field("background", "transparent")
        field("output_format", "png")
        file("image", "car.png", canvasData)
        file("mask", "mask.png", maskData)
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]],
              let b64 = items.first?["b64_json"] as? String,
              let raw = Data(base64Encoded: b64),
              let image = UIImage(data: raw)
        else { return nil }

        return image
    }

    /// Centres the cutout on a square transparent canvas and builds the matching
    /// mask: opaque where the car already is, clear everywhere it may be drawn.
    private static func prepare(_ cutout: UIImage, side: CGFloat) -> (UIImage, UIImage)? {
        let scale = min(side * 0.62 / cutout.size.width, side * 0.62 / cutout.size.height)
        let size = CGSize(width: cutout.size.width * scale, height: cutout.size.height * scale)
        let origin = CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2)
        let rect = CGRect(origin: origin, size: size)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        let canvas = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
            .image { _ in cutout.draw(in: rect) }

        let mask = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
            .image { ctx in
                // Draw the car's own silhouette in solid white: that is the area
                // the model must leave alone.
                ctx.cgContext.saveGState()
                cutout.draw(in: rect)
                ctx.cgContext.setBlendMode(.sourceIn)
                UIColor.white.setFill()
                ctx.cgContext.fill(CGRect(x: 0, y: 0, width: side, height: side))
                ctx.cgContext.restoreGState()
            }

        return (canvas, mask)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
