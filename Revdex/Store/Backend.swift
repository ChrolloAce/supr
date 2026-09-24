import UIKit

/// Thin Supabase client: PostgREST for rows, Storage for images.
///
/// There is no account system yet, so identity is a UUID minted once on the
/// device and kept in the keychain-less defaults. That is enough to own your
/// own rows and to show up in the feed, the board and chat.
enum Backend {

    static let url = "https://hfpnuszmzahddxntlcjt.supabase.co"
    static let anonKey = "sb_publishable_X8rcak3DHU94AeeyM9YmUg_32xB08IA"
    static let bucket = "revdex"

    /// Who this install posts as. The Apple account when signed in, so a
    /// profile follows the person across devices, otherwise a per install UUID
    /// so the garage still syncs for someone playing solo.
    static var deviceID: String {
        if let apple = UserDefaults.standard.string(forKey: "revdex.apple.user"), !apple.isEmpty {
            return apple
        }
        let key = "revdex.device.id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = UUID().uuidString.lowercased()
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    // MARK: Rows

    enum Prefer: String {
        case none = ""
        case upsert = "resolution=merge-duplicates"
        case returnNone = "return=minimal"
    }

    @discardableResult
    static func insert(_ table: String, _ rows: [[String: Any]], prefer: Prefer = .returnNone) async -> Bool {
        guard let url = URL(string: "\(url)/rest/v1/\(table)") else { return false }
        var request = base(url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var preferences = ["return=representation"]
        if prefer == .upsert { preferences.append("resolution=merge-duplicates") }
        if prefer == .returnNone { preferences = ["return=minimal"] }
        request.setValue(preferences.joined(separator: ","), forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: rows)

        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// Insert or update by primary key.
    @discardableResult
    static func upsert(_ table: String, _ row: [String: Any]) async -> Bool {
        await insert(table, [row], prefer: .upsert)
    }

    static func select(_ table: String, query: String) async -> [[String: Any]] {
        guard let url = URL(string: "\(url)/rest/v1/\(table)?\(query)") else { return [] }
        guard let (data, response) = try? await URLSession.shared.data(for: base(url)),
              (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return rows
    }

    @discardableResult
    static func delete(_ table: String, query: String) async -> Bool {
        guard let url = URL(string: "\(url)/rest/v1/\(table)?\(query)") else { return false }
        var request = base(url)
        request.httpMethod = "DELETE"
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    // MARK: Images

    /// Removes every file this device uploaded. Storage has no delete by prefix,
    /// so the folder is listed first and the keys removed by name.
    static func deleteUploads() async -> Bool {
        var ok = true
        for folder in ["photos", "stickers", "avatars", "posts", "crews"] {
            let prefix = "\(deviceID)/\(folder)"
            guard let list = URL(string: "\(url)/storage/v1/object/list/\(bucket)") else { continue }

            var request = base(list)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "prefix": prefix, "limit": 1000
            ])

            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { continue }

            let names = rows.compactMap { $0["name"] as? String }.map { "\(prefix)/\($0)" }
            guard !names.isEmpty else { continue }

            guard let remove = URL(string: "\(url)/storage/v1/object/\(bucket)") else { continue }
            var del = base(remove)
            del.httpMethod = "DELETE"
            del.setValue("application/json", forHTTPHeaderField: "Content-Type")
            del.httpBody = try? JSONSerialization.data(withJSONObject: ["prefixes": names])

            guard let (_, response) = try? await URLSession.shared.data(for: del),
                  (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0)
            else { ok = false; continue }
        }
        return ok
    }

    /// Shrinks to fit a long edge, leaving anything already smaller alone.
    private static func downscale(_ image: UIImage, to maxSide: CGFloat, keepAlpha: Bool) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide, longest > 0 else { return image }

        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = !keepAlpha
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Uploads and returns the public URL. Path is namespaced per device.
    ///
    /// `maxSide` caps the long edge before upload. The feed never shows a
    /// picture larger than the screen, and a wall of full resolution photos is
    /// the difference between a feed that loads and one that crawls.
    static func upload(_ image: UIImage, folder: String, png: Bool = false, maxSide: CGFloat = 1400) async -> String? {
        let name = "\(deviceID)/\(folder)/\(UUID().uuidString).\(png ? "png" : "jpg")"
        let sized = downscale(image, to: maxSide, keepAlpha: png)
        guard let data = png ? sized.pngData() : sized.jpegData(compressionQuality: 0.8),
              let url = URL(string: "\(url)/storage/v1/object/\(bucket)/\(name)") else { return nil }

        var request = base(url)
        request.httpMethod = "POST"
        request.setValue(png ? "image/png" : "image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0)
        else { return nil }

        return "\(Backend.url)/storage/v1/object/public/\(bucket)/\(name)"
    }

    static func download(_ urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: Plumbing

    private static func base(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    static func date(_ string: String?) -> Date {
        guard let string else { return Date() }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string) ?? Date()
    }
}
