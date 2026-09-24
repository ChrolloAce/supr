import AuthenticationServices
import SwiftUI

/// Stands in front of anything social. Signing in with Apple and accepting the
/// terms are both required; the garage and the camera work without either.
///
/// Deliberately sparse: one line of explanation, one action, nothing else.
struct CommunityGate: View {
    @EnvironmentObject private var account: Account
    @EnvironmentObject private var sync: Sync

    @State private var agreed = false
    @State private var showTerms = false
    @State private var showGuidelines = false
    @State private var mail = ""
    @State private var password = ""
    @State private var makingAccount = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Image(systemName: account.isSignedIn ? "checkmark.circle" : "person.2")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Ink.accent)
                    .padding(.bottom, 26)

                Text(account.isSignedIn ? "Almost there" : "Join the community")
                    .display(26)
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)

                Text(account.isSignedIn
                     ? "Accept the terms to post, comment and join crews."
                     : "Your garage works without an account. Posting needs one.")
                    .font(UI.font(14))
                    .foregroundStyle(Ink.faint)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                if account.isSignedIn {
                    agreeRow.padding(.top, 34)

                    Button("Continue") {
                        Buzz.tap()
                        account.agreeToTerms()
                        Task { await sync.pushProfile() }
                    }
                    .buttonStyle(.primary)
                    .disabled(!agreed)
                    .opacity(agreed ? 1 : 0.35)
                    .padding(.top, 18)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        account.handle(result)
                        Task { await sync.pushProfile() }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: R.chip, style: .continuous))
                    .padding(.top, 34)

                    emailForm.padding(.top, 20)

                    legalLinks.padding(.top, 18)
                }

                if let error = account.error {
                    Text(error)
                        .font(UI.font(12))
                        .foregroundStyle(Ink.accent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, 30)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showTerms) { LegalView(kind: .terms) }
        .sheet(isPresented: $showGuidelines) { LegalView(kind: .guidelines) }
    }

    /// One checkbox, both documents. Two separate ticks was busywork.
    private var agreeRow: some View {
        Button {
            Buzz.soft()
            agreed.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: agreed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(agreed ? Ink.accent : Ink.ghost)

                Text("I agree to the Terms of Service and the Community Guidelines")
                    .font(UI.font(13.5))
                    .foregroundStyle(Ink.dim)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomLeading) {
            legalLinks.offset(y: 30)
        }
        .padding(.bottom, 30)
    }

    /// Email is the second way in, so somebody without an Apple Account, or a
    /// reviewer working from a set of credentials, can still reach the
    /// community. Same identity slot as Apple once it succeeds.
    private var emailForm: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Rectangle().fill(Ink.line).frame(height: 1)
                Text("OR")
                    .font(UI.font(11, .bold))
                    .foregroundStyle(Ink.ghost)
                Rectangle().fill(Ink.line).frame(height: 1)
            }
            .padding(.bottom, 4)

            TextField("", text: $mail, prompt: Text("Email").foregroundColor(Ink.ghost))
                .font(UI.font(15, .medium))
                .foregroundStyle(Ink.text)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 52)
                .card()

            SecureField("", text: $password, prompt: Text("Password").foregroundColor(Ink.ghost))
                .font(UI.font(15, .medium))
                .foregroundStyle(Ink.text)
                .textContentType(makingAccount ? .newPassword : .password)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .card()

            Button(makingAccount ? "Create account" : "Sign in") {
                Buzz.tap()
                Task {
                    if makingAccount {
                        await account.signUp(email: mail, password: password)
                    } else {
                        await account.signIn(email: mail, password: password)
                    }
                    if account.isSignedIn { await sync.pushProfile() }
                }
            }
            .buttonStyle(.primary)
            .disabled(account.working || mail.isEmpty || password.isEmpty)
            .opacity(account.working || mail.isEmpty || password.isEmpty ? 0.35 : 1)

            Button(makingAccount
                   ? "Already have an account? Sign in"
                   : "New here? Create an account") {
                Buzz.soft()
                withAnimation(.easeOut(duration: 0.16)) { makingAccount.toggle() }
            }
            .font(UI.font(12.5, .semibold))
            .foregroundStyle(Ink.accent)
            .padding(.top, 2)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 18) {
            Button("Terms") { showTerms = true }
            Button("Guidelines") { showGuidelines = true }
        }
        .font(UI.font(12.5, .semibold))
        .foregroundStyle(Ink.accent)
    }
}

// MARK: - Legal text

struct LegalView: View {
    enum Kind {
        case terms, guidelines

        var title: String {
            switch self {
            case .terms: return "Terms of Service"
            case .guidelines: return "Community Guidelines"
            }
        }
    }

    let kind: Kind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: kind.title) { dismiss() }

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.0)
                                    .font(UI.font(15, .semibold))
                                    .foregroundStyle(Ink.text)
                                Text(section.1)
                                    .font(UI.font(14))
                                    .foregroundStyle(Ink.dim)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Text("Last updated 12 August 2026.")
                            .font(UI.font(12))
                            .foregroundStyle(Ink.ghost)
                            .padding(.top, 8)

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 22)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var sections: [(String, String)] {
        switch kind {
        case .terms: return Self.terms
        case .guidelines: return Self.guidelines
        }
    }

    private static let terms: [(String, String)] = [
        ("Who can use SUPR",
         "You need to be at least 13 years old, and old enough to agree to a contract where you live. You sign in with Apple, and that Apple account is your identity here."),
        ("Your account",
         "Keep your account to yourself. Anything posted from it is treated as posted by you. Tell us if you think somebody else is using it."),
        ("What you capture",
         "Photographs you take stay yours. By posting one to the feed, the map or a crew you give SUPR permission to show it inside the app to other people. You can delete a post at any time and it stops being shown."),
        ("Photographing cars",
         "Photograph cars in public places, and follow the law where you are. Do not trespass, do not obstruct traffic, and never take a photograph while driving. SUPR pixelates number plates it detects, but that is a convenience and not a guarantee, so check before you post."),
        ("Identifying cars",
         "Car identification is automated and often wrong. Rarity, XP and levels are game mechanics, not valuations or facts about a vehicle."),
        ("Subscriptions",
         "Pro is a recurring subscription billed through your Apple ID. It renews unless you cancel at least 24 hours before the period ends, in Settings, Subscriptions."),
        ("Ending it",
         "You can stop using SUPR whenever you like and sign out from your profile. We can suspend an account that breaks these terms or the community guidelines."),
        ("No warranty",
         "SUPR is provided as it is. We do not promise it will always be available, accurate or free of problems.")
    ]

    private static let guidelines: [(String, String)] = [
        ("Post cars, not people",
         "This is about cars. Do not post photographs that centre on a person, and do not post anyone's face as the subject of a post."),
        ("Cover the plate",
         "Develop a capture before posting it and check the plate is actually covered. Never post a readable number plate."),
        ("Do not post an address",
         "A car outside a house says where somebody lives. Do not post house numbers, street signs that pin an exact address, or say where a specific car is parked overnight."),
        ("No harassment",
         "No abuse, no slurs, no threats, no pile ons. Disagreeing about a car is fine. Going after a person is not."),
        ("Be honest about your catches",
         "Post cars you actually saw. Do not post photos taken from the internet, screenshots or other people's pictures as your own."),
        ("Keep it legal",
         "Nothing illegal, nothing depicting dangerous driving you took part in, nothing sexual, nothing violent."),
        ("Reporting",
         "If you see something that breaks these rules, report it. We remove posts and suspend accounts that keep breaking them."),
        ("The short version",
         "Photograph cars, cover the plate, leave people alone.")
    ]
}

// MARK: - Hosted documents

/// The public copies of the documents, the same ones the App Store listing
/// links to. The in app `LegalView` is the readable version; these are what a
/// reviewer, or anyone outside the app, can open.
enum Legal {
    static let terms = URL(string: "https://supr-site.vercel.app/terms")!
    static let privacy = URL(string: "https://supr-site.vercel.app/privacy")!
}
