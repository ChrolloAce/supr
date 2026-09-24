import SwiftUI
import UIKit

@main
struct RevdexApp: App {
    @StateObject private var store: GameStore
    @StateObject private var queue: ScanQueue
    @StateObject private var community: Community
    @StateObject private var sync: Sync
    @StateObject private var location = LocationService()
    @StateObject private var account = Account()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = GameStore()
        _store = StateObject(wrappedValue: store)
        _queue = StateObject(wrappedValue: ScanQueue(store: store))
        _community = StateObject(wrappedValue: Community(store: store))
        _sync = StateObject(wrappedValue: Sync(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(queue)
                .environmentObject(community)
                .environmentObject(sync)
                .environmentObject(location)
                .environmentObject(account)
                .preferredColorScheme(.dark)
                .tint(Ink.accent)
                .background(DarkWindow())
                .task {
                    location.onResolve = { city in
                        if store.profile.city.isEmpty { store.updateCity(city) }
                    }
                    location.request()

                    // Rewarded video only, and only when somebody asks for it.
                    // Pro never sees an ad, so there is nothing to warm up.
                    if !store.isPro { Ads.shared.start() }

                    // Superwall decides which paywall to show, if any. Without
                    // a key it stays dormant and the native paywall is used.
                    Paywalls.shared.configure(store: store)

                    // Anything caught on another install comes back first, then
                    // whatever this device is holding goes up.
                    queue.sync = sync
                    store.onCaptureDeleted = { id in
                        Task { await sync.deleteCapture(id) }
                    }
                    store.onCaptureChanged = { id in
                        sync.markDirty(id)
                        Task { await sync.pushCaptures() }
                    }
                    await sync.restore()
                    await sync.pushCaptures()
                }
                .onChange(of: scenePhase) { phase in
                    // Leaving the app is the moment worth persisting on.
                    if phase == .background || phase == .inactive {
                        Task { await sync.pushCaptures() }
                    }
                }
        }
    }
}

/// UIKit-backed views, the map above all, read the window's trait collection
/// rather than SwiftUI's colour scheme. Without this the map comes back white
/// in the middle of an otherwise dark app whenever the phone is in light mode.
private struct DarkWindow: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async { view.window?.overrideUserInterfaceStyle = .dark }
    }
}
