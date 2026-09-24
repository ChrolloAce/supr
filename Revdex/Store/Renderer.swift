import UIKit

/// Optional second pass over an already developed frame, run through FLUX on
/// fal.ai. This one does regenerate pixels, so it is offered alongside the clean
/// develop rather than replacing it: the local develop is the honest record of
/// what you shot, this is the stylised poster version.
///
/// Strength is deliberately low so the car keeps its shape, stance and colour.
enum Renderer {

    enum Failure: LocalizedError {
        case noKey
        case outOfCredit
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .noKey: return "No FLUX key set"
            case .outOfCredit: return "fal.ai balance is empty. Top up at fal.ai/dashboard/billing."
            case .failed(let why): return why
            }
        }
    }

    private static let prompt = """
    cinematic automotive photography of this exact car, dramatic rim lighting, \
    glossy deep paint reflections, wet asphalt, moody dark background, shot on a \
    85mm lens, car magazine cover quality, keep the vehicle body shape, wheels and \
    paint colour exactly as they are
    """

    static func render(_ image: UIImage) async throws -> UIImage {
        guard let key = Secrets.falKey else { throw Failure.noKey }
        guard let b64 = jpegBase64(image) else { throw Failure.failed("Could not encode the photo") }

        let submit = try await post(
            "https://queue.fal.run/fal-ai/flux/dev/image-to-image",
            key: key,
            body: [
                "image_url": "data:image/jpeg;base64,\(b64)",
                "prompt": prompt,
                "strength": 0.32,
                "num_inference_steps": 34,
                "guidance_scale": 3.5,
                "num_images": 1,
                "enable_safety_checker": false
            ]
        )

        guard let statusURL = submit["status_url"] as? String,
              let responseURL = submit["response_url"] as? String else {
            if let detail = submit["detail"] as? String {
                throw detail.lowercased().contains("balance") ? Failure.outOfCredit : Failure.failed(detail)
            }
            throw Failure.failed("Unexpected reply from fal.ai")
        }

        // Poll until the job leaves the queue.
        for _ in 0..<60 {
            try await Task.sleep(for: .seconds(2))
            let status = try await get(statusURL, key: key)
            switch status["status"] as? String {
            case "COMPLETED":
                let result = try await get(responseURL, key: key)
                guard let images = result["images"] as? [[String: Any]],
                      let urlString = images.first?["url"] as? String,
                      let url = URL(string: urlString),
                      let (data, _) = try? await URLSession.shared.data(from: url),
                      let out = UIImage(data: data) else {
                    throw Failure.failed("Render finished but produced no image")
                }
                return out
            case "IN_QUEUE", "IN_PROGRESS":
                continue
            default:
                throw Failure.failed("Render did not complete")
            }
        }
        throw Failure.failed("Render timed out")
    }

    // MARK: HTTP

    private static func post(_ urlString: String, key: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else { throw Failure.failed("Bad URL") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Key \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func get(_ urlString: String, key: String) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else { throw Failure.failed("Bad URL") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Key \(key)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func jpegBase64(_ image: UIImage) -> String? {
        let target: CGFloat = 1024
        let scale = min(1, target / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let shrunk = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return shrunk.jpegData(compressionQuality: 0.88)?.base64EncodedString()
    }
}
