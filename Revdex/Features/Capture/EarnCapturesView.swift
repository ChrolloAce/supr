import SwiftUI

/// What you see when the captures run out.
///
/// Two honest options: watch something and get three more, or stop being
/// metered. Nothing is taken away for saying no, and the free allowance comes
/// back on its own.
struct EarnCapturesView: View {
    @EnvironmentObject private var store: GameStore
    @ObservedObject private var ads = Ads.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var justEarned = false

    enum Choice { case ad, pro }
    @State private var choice: Choice = .ad

    private var left: Int { store.capturesLeftToday }

    var body: some View {
        ZStack {
            // Lifted off pure black and given a purple bloom, because a wall of
            // near black is the last thing that makes anyone want to upgrade.
            Ink.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Ink.accent.opacity(0.30), .clear],
                center: .top, startRadius: 20, endRadius: 620
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        Buzz.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Ink.dim)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Ink.card))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 22) {
                        headline
                        options
                        Text("Free captures reset every day. Earned ones never expire.")
                            .font(UI.font(12))
                            .foregroundStyle(Ink.ghost)
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)

                Button(choice == .pro ? "Go Pro" : "Watch an ad") {
                    Buzz.tap()
                    if choice == .pro {
                        showPaywall = true
                    } else {
                        ads.show {
                            store.grantAdReward()
                            Buzz.win()
                            justEarned = true
                            Task {
                                try? await Task.sleep(for: .milliseconds(400))
                                justEarned = false
                            }
                        }
                    }
                }
                .buttonStyle(.slab)
                .disabled(choice == .ad && !ads.isReady)
                .opacity(choice == .ad && !ads.isReady ? 0.5 : 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .suprPaywall(.outOfCaptures, isPresented: $showPaywall, context: .outOfCaptures)
        .task { if !store.isPro { ads.preload() } }
    }

    private var headline: some View {
        VStack(spacing: 10) {
            Text("\(left)")
                .font(Disp.font(96, .black))
                .foregroundStyle(left > 0 ? Ink.text : Ink.accentSoft)
                .contentTransition(.numericText())
                .scaleEffect(justEarned ? 1.12 : 1)
                .shadow(color: Ink.accent.opacity(0.4), radius: 26)

            Text(left == 0 ? "You are out of captures" : "\(left) captures left")
                .display(26)
                .foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)

            Text("Every capture and every render costs one. Pick how you want more.")
                .font(UI.font(14))
                .foregroundStyle(Ink.faint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 14)

            if store.earnedCredits > 0 {
                Text("\(store.earnedCredits) earned so far")
                    .font(UI.font(12.5, .semibold))
                    .foregroundStyle(Ink.accent)
            }
        }
        .padding(.top, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: justEarned)
    }

    /// Two big cards you choose between, rather than two rows you read past.
    private var options: some View {
        VStack(spacing: 12) {
            if !store.isPro {
                optionCard(
                    kind: .ad,
                    icon: "play.fill",
                    tint: Ink.accent,
                    title: "Watch an ad",
                    headline: "+\(GameStore.Quota.adReward)",
                    detail: ads.isReady
                        ? "About 30 seconds. Do it as often as you like."
                        : watchLabel
                )
            }

            optionCard(
                kind: .pro,
                icon: "bolt.fill",
                tint: Ink.accentSoft,
                title: store.isPro ? "You are Pro" : "Go Pro",
                headline: "\(GameStore.Quota.proWeekly)",
                detail: store.isPro
                    ? "\(GameStore.Quota.proWeekly) a week, no ads."
                    : "A week, every week. No ads, no waiting."
            )
        }
    }

    private func optionCard(
        kind: Choice,
        icon: String,
        tint: Color,
        title: String,
        headline: String,
        detail: String
    ) -> some View {
        let on = choice == kind

        return Button {
            Buzz.soft()
            withAnimation(.easeOut(duration: 0.15)) { choice = kind }
        } label: {
            HStack(alignment: .top, spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous).fill(tint)
                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(kind == .pro ? Ink.bg : .white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(UI.font(18, .semibold))
                            .foregroundStyle(Ink.text)
                        Spacer(minLength: 0)
                        Text(headline)
                            .font(Disp.font(26, .black))
                            .foregroundStyle(tint)
                    }
                    Text(detail)
                        .font(UI.font(13))
                        .foregroundStyle(Ink.faint)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(17)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(on ? Ink.cardAlt : Ink.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(on ? tint : Ink.line, lineWidth: on ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var watchLabel: String {
        switch ads.state {
        case .loading: return "Finding an ad"
        case .ready: return "Watch an ad"
        case .playing: return "Playing"
        case .unavailable: return "No ad available right now"
        case .idle: return "Watch an ad"
        }
    }

}
