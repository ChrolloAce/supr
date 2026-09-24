import AppTrackingTransparency
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Asks permission before anything is requested from an ad network.
///
/// The order is fixed and it matters. Google's consent form has to be resolved
/// first, because in the EEA and UK an ad request made before consent is a
/// policy breach. Apple's tracking prompt comes second, and only once the
/// consent form is off screen, otherwise the two alerts fight over the window.
/// Ads initialise last, when both have settled.
///
/// Saying no to either is a perfectly good answer: ads still serve, they are
/// just not personalised, and the rewarded video still pays out captures.
@MainActor
enum Consent {

    /// Runs the whole chain, then hands back so ads can start.
    static func gather() async {
        await requestConsentForm()
        await requestTracking()
    }

    // MARK: Google UMP

    private static func requestConsentForm() async {
        let parameters = UMPRequestParameters()
        #if DEBUG
        // Without this the simulator looks like it is nowhere in particular and
        // the EEA form never appears, so it cannot be tested.
        let debugSettings = UMPDebugSettings()
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        #endif

        // No network, or Google having a bad day, must not brick the app: the
        // error is swallowed and the caller carries on without a form.
        await withCheckedContinuation { continuation in
            UMPConsentInformation.sharedInstance
                .requestConsentInfoUpdate(with: parameters) { _ in
                    continuation.resume()
                }
        }

        guard UMPConsentInformation.sharedInstance.formStatus == .available,
              let root = topViewController() else { return }

        await withCheckedContinuation { continuation in
            UMPConsentForm.loadAndPresentIfRequired(from: root) { _ in
                continuation.resume()
            }
        }
    }

    /// True when Google says we may ask for ads at all.
    static var canRequestAds: Bool {
        UMPConsentInformation.sharedInstance.canRequestAds
    }

    /// Shown from settings so somebody can change their mind later, which the
    /// GDPR requires. Nil when the form is not applicable to this person.
    static var privacyOptionsRequired: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    static func showPrivacyOptions() async {
        guard let root = topViewController() else { return }
        await withCheckedContinuation { continuation in
            UMPConsentForm.presentPrivacyOptionsForm(from: root) { _ in
                continuation.resume()
            }
        }
    }

    // MARK: Apple ATT

    private static func requestTracking() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // A beat after the consent sheet dismisses. Asking while another alert
        // is still on screen gets the request silently dropped.
        try? await Task.sleep(for: .milliseconds(600))
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    // MARK: Helpers

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
