import AuthenticationServices
import SwiftUI

/// Sign in with Apple, plus the agreements a person has to accept before they
/// can take part in anything social.
///
/// Catching cars works signed out: the garage, the dex and the camera are all
/// local. Anything that other people can see needs an account, so there is a
/// real identity behind a post, a comment or a crew.
@MainActor
final class Account: NSObject, ObservableObject {

    /// Bump when the terms change and everyone is asked to accept again.
    static let termsVersion = 1

    /// How this person got in. Worth storing, because only an Apple session can
    /// be revalidated against Apple, and asking Apple about a Supabase user id
    /// comes back "not found" and signs them straight back out.
    enum Provider: String {
        case apple, email
    }

    @Published private(set) var provider: Provider = .apple
    @Published private(set) var appleUserID: String?
    @Published private(set) var name: String = ""
    @Published private(set) var email: String = ""
    @Published private(set) var agreedVersion: Int = 0
    @Published private(set) var working = false
    @Published var error: String?

    var isSignedIn: Bool { appleUserID?.isEmpty == false }
    var hasAgreed: Bool { agreedVersion >= Self.termsVersion }
    /// The one gate every social surface checks.
    var canUseCommunity: Bool { isSignedIn && hasAgreed }

    private let defaults = UserDefaults.standard
    private enum Key {
        static let user = "revdex.apple.user"
        static let name = "revdex.apple.name"
        static let email = "revdex.apple.email"
        static let agreed = "revdex.terms.version"
        static let provider = "revdex.auth.provider"
    }

    override init() {
        super.init()
        provider = Provider(rawValue: defaults.string(forKey: Key.provider) ?? "") ?? .apple
        appleUserID = defaults.string(forKey: Key.user)
        name = defaults.string(forKey: Key.name) ?? ""
        email = defaults.string(forKey: Key.email) ?? ""
        agreedVersion = defaults.integer(forKey: Key.agreed)
        Task { await revalidate() }
    }

    // MARK: Sign in

    func handle(_ result: Result<ASAuthorization, Error>) {
        working = false
        switch result {
        case .failure(let error):
            // Cancelling is not a failure worth shouting about.
            let code = (error as? ASAuthorizationError)?.code
            guard code != .canceled else { return }
            self.error = Self.explain(code, error)
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                self.error = "Unexpected credential"
                return
            }
            appleUserID = credential.user
            provider = .apple
            defaults.set(credential.user, forKey: Key.user)
            defaults.set(Provider.apple.rawValue, forKey: Key.provider)

            // Apple only hands over name and email on the very first sign in.
            if let full = credential.fullName {
                let parts = [full.givenName, full.familyName].compactMap { $0 }
                let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !joined.isEmpty {
                    name = joined
                    defaults.set(joined, forKey: Key.name)
                }
            }
            if let mail = credential.email, !mail.isEmpty {
                email = mail
                defaults.set(mail, forKey: Key.email)
            }
            error = nil
        }
    }

    /// Apple's errors are opaque, and the usual cause is setup rather than the
    /// person doing something wrong, so say which.
    private static func explain(_ code: ASAuthorizationError.Code?, _ error: Error) -> String {
        switch code {
        case .unknown:
            return "Sign in could not start. Check that an Apple Account is signed in on this device, and that Sign in with Apple is enabled for this app in Xcode under Signing and Capabilities."
        case .invalidResponse:
            return "Apple returned an unexpected response. Try again."
        case .notHandled:
            return "Sign in was not handled. Try again."
        case .failed:
            return "Apple could not complete the sign in. Try again in a moment."
        case .notInteractive:
            return "Sign in needs the app to be in the foreground."
        default:
            return error.localizedDescription
        }
    }

    // MARK: Email

    /// Sign in and sign up are the same request to Supabase with a different
    /// path, and both come back with the same shape, so they share a body.
    func signIn(email address: String, password: String) async {
        await authenticate("token?grant_type=password", address, password)
    }

    func signUp(email address: String, password: String) async {
        await authenticate("signup", address, password)
    }

    private func authenticate(_ path: String, _ address: String, _ password: String) async {
        let mail = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard mail.contains("@"), mail.count > 3 else {
            error = "Enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            error = "Passwords need to be at least 6 characters."
            return
        }
        guard let url = URL(string: "\(Backend.url)/auth/v1/\(path)") else { return }

        working = true
        error = nil
        defer { working = false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(Backend.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": mail, "password": password
        ])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            error = "Could not reach the server. Check your connection and try again."
            return
        }

        guard (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0) else {
            // Supabase spreads the reason across three different keys.
            error = json["error_description"] as? String
                ?? json["msg"] as? String
                ?? json["message"] as? String
                ?? "That did not work. Check the email and password and try again."
            return
        }

        // Signing in nests the account under `user`; signing up returns it flat.
        let account = json["user"] as? [String: Any] ?? json
        guard let id = account["id"] as? String, !id.isEmpty else {
            error = "The server did not return an account. Try again."
            return
        }

        appleUserID = id
        provider = .email
        email = account["email"] as? String ?? mail
        defaults.set(id, forKey: Key.user)
        defaults.set(Provider.email.rawValue, forKey: Key.provider)
        defaults.set(email, forKey: Key.email)
        error = nil
    }

    func agreeToTerms() {
        agreedVersion = Self.termsVersion
        defaults.set(agreedVersion, forKey: Key.agreed)
    }

    func signOut() {
        appleUserID = nil
        provider = .apple
        name = ""
        email = ""
        agreedVersion = 0
        defaults.removeObject(forKey: Key.provider)
        defaults.removeObject(forKey: Key.user)
        defaults.removeObject(forKey: Key.name)
        defaults.removeObject(forKey: Key.email)
        defaults.removeObject(forKey: Key.agreed)
    }

    /// If the Apple credential was revoked in Settings, drop the session. Only
    /// Apple sessions: Apple has never heard of an email account's id and would
    /// report it missing, signing the person out on every launch.
    private func revalidate() async {
        guard provider == .apple, let id = appleUserID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let state = try? await provider.credentialState(forUserID: id)
        if state == .revoked || state == .notFound {
            signOut()
        }
    }
}
