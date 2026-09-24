import Foundation

/// API keys, read at runtime from `Secrets.plist` in the bundle. That file is
/// listed in .gitignore so live keys never reach the repo.
///
/// Every feature that depends on a key falls back to an on device path when the
/// key is missing, so the app stays fully usable without any of this filled in.
enum Secrets {

    /// Vision model that names the make and model of a photographed car.
    static var openAIKey: String? { value("OPENAI_API_KEY") }
    static var visionModel: String { value("OPENAI_VISION_MODEL") ?? "gpt-4o-mini" }

    /// fal.ai, used for the optional FLUX render pass.
    static var falKey: String? { value("FAL_API_KEY") }

    /// Superwall's public key, the one that starts pk_. Safe to ship in the
    /// binary; it identifies the app, it does not authorise anything.
    static var superwallKey: String? { value("SUPERWALL_API_KEY") }

    static var hasVision: Bool { openAIKey?.isEmpty == false }
    static var hasFlux: Bool { falKey?.isEmpty == false }
    static var hasSuperwall: Bool { superwallKey?.isEmpty == false }

    private static func value(_ key: String) -> String? {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: Any],
           let v = dict[key] as? String, !v.isEmpty, !v.hasPrefix("$(") {
            return v
        }
        if let v = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !v.isEmpty, !v.hasPrefix("$(") {
            return v
        }
        let env = ProcessInfo.processInfo.environment[key]
        return (env?.isEmpty == false) ? env : nil
    }
}
