import GoogleMobileAds
import SwiftUI
import UIKit

/// Rewarded video, the only ad format in the app.
///
/// Nothing is shown unprompted: an ad plays because somebody chose to trade a
/// minute for more captures. Skipping early pays nothing, which is Google's own
/// rule for the format and also the honest deal.
@MainActor
final class Ads: NSObject, ObservableObject {
    static let shared = Ads()

    /// The live rewarded unit. Debug builds keep Google's test unit, because
    /// their policy requires test ads in development and tapping a live ad
    /// yourself is grounds for a permanent ban on the whole account.
    private static var rewardedUnit: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/1712485313"
        #else
        return "ca-app-pub-2491905367957709/4606911068"
        #endif
    }

    enum State: Equatable {
        case idle, loading, ready, playing, unavailable
    }

    @Published private(set) var state: State = .idle
    @Published var error: String?

    private var ad: RewardedAd?
    private var onReward: (() -> Void)?

    private override init() {
        super.init()
    }

    /// Called once at launch, after consent has been dealt with.
    ///
    /// Nothing is requested from Google until the consent form says it may be,
    /// because an ad request made before consent in the EEA is a policy breach.
    func start() {
        Task {
            await Consent.gather()
            guard Consent.canRequestAds else {
                state = .unavailable
                return
            }
            MobileAds.shared.start { _ in
                Task { @MainActor in self.preload() }
            }
        }
    }

    var isReady: Bool { state == .ready }

    // MARK: Load

    func preload() {
        guard state != .loading, state != .playing, ad == nil else { return }
        state = .loading

        Task {
            do {
                ad = try await RewardedAd.load(with: Self.rewardedUnit, request: Request())
                ad?.fullScreenContentDelegate = self
                state = .ready
            } catch {
                ad = nil
                // No fill is normal, especially on a fresh account. It is not
                // worth putting in front of anyone.
                state = .unavailable
            }
        }
    }

    // MARK: Show

    /// Presents the ad. `onReward` fires only if it is watched to the end.
    func show(onReward: @escaping () -> Void) {
        guard let ad, let root = Self.topViewController() else {
            error = "No ad is ready. Try again in a moment."
            preload()
            return
        }

        self.onReward = onReward
        state = .playing

        ad.present(from: root) { [weak self] in
            guard let self else { return }
            // Google calls this once the reward is genuinely earned.
            self.onReward?()
            self.onReward = nil
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension Ads: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.ad = nil
            self.state = .idle
            self.onReward = nil
            // Line the next one up so the second watch is instant.
            self.preload()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.ad = nil
            self.state = .idle
            self.onReward = nil
            self.error = "That ad could not play. Try again."
            self.preload()
        }
    }
}
