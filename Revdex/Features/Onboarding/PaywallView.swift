import StoreKit
import SwiftUI

/// The native paywall's own purchasing, used whenever Superwall declines to
/// present or is not configured. `purchase` and `restore` are the only two
/// seams that touch StoreKit.
@MainActor
enum PurchaseService {
    struct Plan: Identifiable, Equatable {
        let id: String
        let title: String
        let price: String
        let sub: String
        let strikethrough: String?
        let badge: String?
        let trialDays: Int
    }

    // These have to match the products in App Store Connect exactly, both the
    // identifiers and the money. Anything shown here that the store disagrees
    // with is a rejection under 3.1.2, and a broken purchase besides.
    static let monthly = Plan(
        id: "supr.monthly",
        title: "Monthly",
        price: "$9.99",
        sub: "per month",
        strikethrough: nil,
        badge: nil,
        trialDays: 0
    )

    static let yearly = Plan(
        id: "supr.yearly",
        title: "Yearly",
        price: "$1.67",
        sub: "$19.99 billed yearly",
        strikethrough: "$9.99",
        badge: "3 days free",
        trialDays: 3
    )

    static var plans: [Plan] { [monthly, yearly] }

    /// Superwall buys through its own paywalls. This path only runs when the
    /// native paywall stands in for one, so it has to complete a real purchase
    /// on its own rather than hand out Pro or refuse everybody.
    static func purchase(_ plan: Plan) async -> Bool {
        do {
            guard let product = try await Product.products(for: [plan.id]).first else {
                return false
            }
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                return true
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// True when this Apple ID already owns a subscription that is still
    /// running. `AppStore.sync` is deliberately not called: StoreKit 2 keeps
    /// entitlements current by itself, and forcing a sync prompts for a
    /// password that a person restoring does not expect.
    static func restore() async -> Bool {
        let ids = Set(plans.map(\.id))
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ids.contains(transaction.productID) else { continue }
            if let revoked = transaction.revocationDate, revoked <= .now { continue }
            if let expiry = transaction.expirationDate, expiry <= .now { continue }
            return true
        }
        return false
    }
}

struct PaywallView: View {
    enum Context {
        case onboarding, outOfCaptures, outOfDevelops, leaderboard, settings

        var eyebrow: String {
            switch self {
            case .onboarding: return "SUPR Pro"
            case .outOfCaptures: return "Daily cap reached"
            case .outOfDevelops: return "Darkroom empty"
            case .leaderboard: return "Full board"
            case .settings: return "SUPR Pro"
            }
        }

        var headline: String {
            switch self {
            case .onboarding: return "Hunt without\na limit."
            case .outOfCaptures: return "You are out\nof captures."
            case .outOfDevelops: return "Nothing left\nto develop with."
            case .leaderboard: return "See every\nrival."
            case .settings: return "Go pro."
            }
        }

        var support: String {
            switch self {
            case .onboarding: return "Free spotters get \(GameStore.Quota.freeDaily) captures a day. Pro gets \(GameStore.Quota.proWeekly) a week."
            case .outOfCaptures: return "Free resets at midnight, or watch an ad for \(GameStore.Quota.adReward) more. Pro gets \(GameStore.Quota.proWeekly) a week."
            case .outOfDevelops: return "Developing spends the same pot as catching. Watch an ad for \(GameStore.Quota.adReward) more, or go Pro for \(GameStore.Quota.proWeekly) a week."
            case .leaderboard: return "Rank against your whole city and the global board, live."
            case .settings: return "Everything unlocked, forever hunting."
            }
        }
    }

    let context: Context
    var onFinish: ((Bool) -> Void)? = nil

    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var selected = PurchaseService.yearly
    @State private var working = false
    @State private var note: String?
    @State private var canClose = false

    private let perks: [(String, String)] = [
        ("infinity", "\(GameStore.Quota.proWeekly) captures a week, no ads"),
        ("square.grid.3x3.fill", "The full \(Catalog.total) entry dex"),
        ("sparkles", "Rare luck boost on every scan"),
        ("trophy.fill", "Full city and global boards"),
        ("flame.fill", "Streak freeze so a bad day costs nothing")
    ]

    var body: some View {
        ZStack {
            Ink.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topRow
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headline
                        perkList
                        planRow
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)
                }
                .scrollIndicators(.hidden)
                cta
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(context == .onboarding ? 1.6 : 0.3))
            withAnimation { canClose = true }
        }
    }

    private var topRow: some View {
        HStack {
            Button {
                Buzz.tap()
                Task {
                    working = true
                    let ok = await PurchaseService.restore()
                    working = false
                    if ok {
                        store.setPro(true)
                        finish(true)
                    } else {
                        withAnimation { note = "Nothing to restore on this Apple ID." }
                    }
                }
            } label: {
                Text("Restore")
                    .label(11, .bold, tracking: 0.8)
                    .foregroundStyle(Ink.dim)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            IconButton(icon: "xmark", size: 40) { finish(false) }
                .opacity(canClose ? 1 : 0)
                .disabled(!canClose)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Ink.accentSoft)
                    .frame(width: 6, height: 16)
                    .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.2))
                Text(context.eyebrow)
                    .label(10, .heavy, tracking: 1)
                    .foregroundStyle(Ink.dim)
            }
            Text(context.headline)
                .display(40)
                .foregroundStyle(Ink.text)
                .lineSpacing(-4)
                .fixedSize(horizontal: false, vertical: true)
            Text(note ?? context.support)
                .font(UI.font(13.5))
                .foregroundStyle(note == nil ? Ink.dim : Ink.accent)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var perkList: some View {
        VStack(spacing: 0) {
            ForEach(Array(perks.enumerated()), id: \.offset) { i, perk in
                HStack(spacing: 12) {
                    Image(systemName: perk.0)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Ink.line)
                        .frame(width: 32, height: 32)
                        .background(Ink.accentSoft)
                        .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.6))
                    Text(perk.1)
                        .font(UI.font(13, .semibold))
                        .foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if i < perks.count - 1 {
                    Rectangle().fill(Ink.line).frame(height: Line.hair)
                }
            }
        }
        .card()
    }

    private var planRow: some View {
        HStack(spacing: 11) {
            ForEach(PurchaseService.plans) { plan in
                planCard(plan)
            }
        }
        .padding(.top, 4)
    }

    private func planCard(_ plan: PurchaseService.Plan) -> some View {
        let on = selected == plan
        return Button {
            Buzz.tap()
            withAnimation(.easeOut(duration: 0.16)) { selected = plan }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(plan.title)
                        .label(11, .heavy, tracking: 0.8)
                        .foregroundStyle(Ink.line)
                    Spacer()
                    ZStack {
                        Rectangle()
                            .fill(on ? Ink.line : Ink.card)
                            .frame(width: 18, height: 18)
                        Rectangle()
                            .strokeBorder(Ink.line, lineWidth: 1.8)
                            .frame(width: 18, height: 18)
                        if on {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                }

                Spacer(minLength: 10)

                if let strike = plan.strikethrough {
                    Text(strike)
                        .font(UI.font(11, .semibold))
                        .strikethrough()
                        .foregroundStyle(Ink.faint)
                        .padding(.bottom, 1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(plan.price)
                        .display(30)
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("/mo")
                        .label(9.5, .bold, tracking: 0.4)
                        .foregroundStyle(Ink.faint)
                }

                Text(plan.sub)
                    .font(UI.font(9.5, .semibold))
                    .foregroundStyle(Ink.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .card(on ? Ink.accentSoft : Ink.card, radius: R.chip, drop: on ? 5 : 3)
            .overlay(alignment: .top) {
                if let badge = plan.badge {
                    Text(badge)
                        .label(9, .heavy, tracking: 0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 22)
                        .background(Ink.accent)
                        .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.6))
                        .offset(y: -11)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var cta: some View {
        VStack(spacing: 11) {
            Button {
                Buzz.heavy()
                Task {
                    working = true
                    let ok = await PurchaseService.purchase(selected)
                    working = false
                    if ok {
                        store.setPro(true)
                        Buzz.win()
                        finish(true)
                    } else {
                        Buzz.nope()
                        withAnimation { note = "That did not go through. Nothing has been charged." }
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    if working { ProgressView().tint(.white).scaleEffect(0.7) }
                    Text(selected.trialDays > 0 ? "Start free trial" : "Unlock pro")
                }
            }
            // The one thing this whole screen is for, so it is the one thing
            // that glints. Stops while a purchase is in flight.
            .buttonStyle(working ? .primary : .primaryShine)
            .disabled(working)

            Text(finePrint)
                .font(UI.font(9.5))
                .foregroundStyle(Ink.faint)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            // Apple requires both of these to be reachable from the paywall
            // itself, not just from the profile, so they are real links out to
            // the same documents that back the App Store listing.
            HStack(spacing: 16) {
                Link("Terms of use", destination: Legal.terms)
                Link("Privacy policy", destination: Legal.privacy)
            }
            .label(9, .bold, tracking: 0.6)
            .foregroundStyle(Ink.ghost)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    /// Guideline 3.1.2(c) wants four things visible on the paywall itself: the
    /// name of the subscription, how long a period lasts, what it costs (with a
    /// per unit price where one is shown), and links to both documents. The
    /// links live just below this; the rest has to be in the sentence.
    private var finePrint: String {
        selected.trialDays > 0
            ? "SUPR Pro Yearly. 3 days free, then $19.99 per year ($1.67 per month), charged to your Apple ID. Renews automatically unless cancelled at least 24 hours before the period ends. Manage in Settings, Apple ID, Subscriptions."
            : "SUPR Pro Monthly. $9.99 per month, charged to your Apple ID. Renews automatically unless cancelled at least 24 hours before the period ends. Manage in Settings, Apple ID, Subscriptions."
    }

    private func finish(_ purchased: Bool) {
        if let onFinish {
            onFinish(purchased)
        } else {
            dismiss()
        }
    }
}
