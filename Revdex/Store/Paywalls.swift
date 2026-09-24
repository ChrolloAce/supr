import SuperwallKit
import SwiftUI

/// Superwall in front of the paywall, with the built in one behind it.
///
/// Placements are named events, not screens. The app says "this person ran out
/// of captures" and the campaign in the dashboard decides whether that shows a
/// paywall, which paywall, and to whom. If no key is set, or the campaign has
/// nothing to show, the native `PaywallView` still opens, so monetisation never
/// depends on a remote config being correct.
@MainActor
final class Paywalls: ObservableObject {
    static let shared = Paywalls()

    /// Where the app asked from.
    ///
    /// All four fire the same placement, because the campaign listens for
    /// `campaign_trigger`. The reason travels as a parameter instead, so the
    /// campaign can split on `source` later without another app release.
    enum Placement: String {
        case onboarding
        case outOfCaptures
        case outOfDevelops
        case leaderboard
        case settings

        /// The event name the campaign is listening for.
        var event: String { "campaign_trigger" }
    }

    /// True once configure has run with a real key.
    @Published private(set) var isLive = false
    /// Mirrors Superwall's view of the subscription, so the store can follow it.
    @Published private(set) var isSubscribed = false

    private var store: GameStore?

    private init() {}

    // MARK: Setup

    func configure(store: GameStore) {
        self.store = store

        guard let key = Secrets.superwallKey, !key.isEmpty else {
            // No key yet. Everything falls back to the native paywall.
            isLive = false
            return
        }

        Superwall.configure(apiKey: key)
        Superwall.shared.delegate = self
        isLive = true

        // Whatever Superwall already knows wins over what is on disk, so a
        // subscription bought on another device is honoured at launch.
        syncSubscription()
    }

    private func syncSubscription() {
        let active = Superwall.shared.subscriptionStatus.isActive
        isSubscribed = active
        if active, let store, !store.isPro { store.setPro(true) }
    }

    // MARK: Asking for a paywall

    /// Registers the placement and reports whether the app should open its own
    /// paywall instead. True means Superwall handled it.
    @discardableResult
    func present(_ placement: Placement) async -> Bool {
        guard isLive else { return false }

        return await withCheckedContinuation { continuation in
            var answered = false
            func answer(_ handled: Bool) {
                guard !answered else { return }
                answered = true
                continuation.resume(returning: handled)
            }

            let handler = PaywallPresentationHandler()
            handler.onPresent { _ in answer(true) }
            // A campaign that holds this person back, or has no paywall for
            // this placement, is not a failure: the native one takes over.
            handler.onSkip { _ in answer(false) }
            handler.onError { _ in answer(false) }

            Superwall.shared.register(
                placement: placement.event,
                params: ["source": placement.rawValue],
                handler: handler
            ) {
                // Fires only when the person is entitled afterwards.
                self.syncSubscription()
            }
        }
    }
}

// MARK: - Delegate

extension Paywalls: SuperwallDelegate {
    nonisolated func subscriptionStatusDidChange(
        from oldValue: SuperwallKit.SubscriptionStatus,
        to newValue: SuperwallKit.SubscriptionStatus
    ) {
        Task { @MainActor in
            self.isSubscribed = newValue.isActive
            if newValue.isActive {
                self.store?.setPro(true)
            }
        }
    }
}

private extension SuperwallKit.SubscriptionStatus {
    var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}

// MARK: - Convenience

extension View {
    /// Asks Superwall first, and only falls back to the built in paywall when
    /// it declines or is not configured.
    func suprPaywall(
        _ placement: Paywalls.Placement,
        isPresented: Binding<Bool>,
        context: PaywallView.Context
    ) -> some View {
        modifier(PaywallBridge(placement: placement, isPresented: isPresented, context: context))
    }
}

private struct PaywallBridge: ViewModifier {
    let placement: Paywalls.Placement
    @Binding var isPresented: Bool
    let context: PaywallView.Context

    @State private var showNative = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showNative) { PaywallView(context: context) }
            .onChange(of: isPresented) { wants in
                guard wants else { return }
                isPresented = false
                Task {
                    let handled = await Paywalls.shared.present(placement)
                    if !handled { showNative = true }
                }
            }
    }
}
