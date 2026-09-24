import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: GameStore
    @StateObject private var coordinator = CaptureCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: Tab = Tab.launchDefault

    enum Tab {
        case garage, map, capture, rivals, profile

        /// Lets `garage` / `rivals` on the scheme open straight into a screen while building.
        static var launchDefault: Tab {
            #if DEBUG
            switch ProcessInfo.processInfo.arguments.last(where: { ["garage", "rivals", "capture", "map", "profile", "dex"].contains($0) }) {
            case "garage", "dex": return .garage
            case "map": return .map
            case "rivals": return .rivals
            case "profile": return .profile
            default: return .capture
            }
            #else
            return .capture
            #endif
        }
    }

    var body: some View {
        Group {
            if store.onboarded {
                main
            } else {
                OnboardingFlow()
            }
        }
        .environmentObject(coordinator)
        .preferredColorScheme(.dark)
        // In-app banners sit above every screen but below the takeover.
        .overlay(alignment: .top) { ToastHost() }
        .fullScreenCover(item: $store.pendingLevelUp) { payload in
            LevelUpView(payload: payload) { store.pendingLevelUp = nil }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.refreshDaily() }
        }
        .task {
            // Anything earned before achievements existed unlocks quietly on
            // first launch rather than firing thirty banners at once.
            store.syncAchievements(announce: false)

            #if DEBUG
            // `seed` on the scheme skips onboarding and fills the garage, so a
            // screen that normally takes a hundred catches to reach is one
            // launch away while building.
            if ProcessInfo.processInfo.arguments.contains("seed") {
                if !store.onboarded {
                    store.completeOnboarding(handle: "spotter0001", city: "TEST", makes: [])
                }
                store.unlockEverything()
            }

            // `levelup` on the scheme shows the takeover without catching a car.
            if ProcessInfo.processInfo.arguments.contains("levelup") {
                let now = store.profile.xp
                store.pendingLevelUp = LevelUpView.Payload(
                    fromLevel: store.profile.level,
                    toLevel: store.profile.level + 2,
                    xpBefore: now,
                    xpAfter: Levels.threshold(for: store.profile.level + 2) + 300,
                    xpGained: 370
                )
            }
            #endif
        }
    }

    private var main: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .garage: GarageView()
                case .map: SpotMapView()
                case .capture: CaptureView()
                case .rivals: RivalsView()
                case .profile: ProfilePage()
                }
            }
            .ignoresSafeArea(.keyboard)

            TabDock(tab: $tab) {
                if tab == .capture {
                    coordinator.fire()
                } else {
                    Buzz.tap()
                    withAnimation(.easeOut(duration: 0.2)) { tab = .capture }
                }
            }
            .padding(.horizontal, 18)
        }
        .background(Ink.bg)
    }
}

// MARK: - Floating dock

struct TabDock: View {
    @Binding var tab: RootView.Tab
    let onShutter: () -> Void

    @EnvironmentObject private var coordinator: CaptureCoordinator
    @State private var spin: Double = 0

    var body: some View {
        HStack(spacing: 0) {
            item(.garage, icon: "square.grid.2x2.fill", label: "Garage")
            item(.map, icon: "map.fill", label: "Map")
            Spacer(minLength: 0)
            shutter
            Spacer(minLength: 0)
            item(.rivals, icon: "person.2.fill", label: "Feed")
            item(.profile, icon: "person.crop.circle.fill", label: "You")
        }
        .padding(.horizontal, 6)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Ink.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Ink.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 18, y: 6)
    }

    /// A plain white shutter, the way every camera on the phone draws one.
    /// The ring turns purple while a scan is still running.
    private var shutter: some View {
        Button(action: onShutter) {
            ZStack {
                Circle()
                    .strokeBorder(coordinator.busy ? Ink.accent : Ink.line, lineWidth: 2.5)
                    .frame(width: 62, height: 62)
                Circle()
                    .fill(.white)
                    .frame(width: 50, height: 50)

                if coordinator.busy {
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Ink.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 62, height: 62)
                        .rotationEffect(.degrees(spin))
                }
            }
            .frame(width: 72, height: 70)
            .contentShape(Circle())
        }
        .buttonStyle(ShutterStyle())
        .offset(y: -6)
        .onChange(of: coordinator.busy) { busy in
            guard busy else { return }
            spin = 0
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { spin = 360 }
        }
    }

    private func item(_ target: RootView.Tab, icon: String, label: String) -> some View {
        let on = tab == target
        return Button {
            Buzz.tap()
            withAnimation(.easeOut(duration: 0.2)) { tab = target }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(on ? Ink.text : Ink.faint)
                Text(label)
                    .font(UI.font(10, .medium))
                    .foregroundStyle(on ? Ink.text : Ink.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 62, height: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ShutterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Height every scroll view should reserve so content clears the dock.
enum Dock {
    static let clearance: CGFloat = 108
}
