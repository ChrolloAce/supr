import SwiftUI

/// Onboarding by demonstration. No forms, no questionnaire: you take a shot,
/// watch it develop into a sticker, watch it file itself, and then see what the
/// rest of the app does with it.
struct OnboardingFlow: View {
    @EnvironmentObject private var store: GameStore

    @State private var step = 0

    private let last = 5   // welcome, capture, level, community, map, paywall

    var body: some View {
        ZStack {
            Ink.bg.ignoresSafeArea()

            Group {
                switch step {
                case 0: WelcomeStep(onStart: advance)
                case 1: CaptureDemo(onFinish: advance)
                case 2: LevelStep(onNext: advance)
                case 3: CommunityStep(onNext: advance)
                case 4: MapStep(onNext: advance)
                default: OnboardingPaywall { finish() }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            if step > 0 && step < last {
                VStack {
                    HStack(spacing: 7) {
                        ForEach(1..<last, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? Ink.accent : Ink.raised)
                                .frame(width: i == step ? 22 : 7, height: 5)
                        }
                        Spacer()
                        Button {
                            Buzz.tap()
                            withAnimation { step = last }
                        } label: {
                            // Padded out to a real target: the bare text was
                            // about the size of a fingernail.
                            Text("Skip")
                                .font(UI.font(13, .semibold))
                                .foregroundStyle(Ink.faint)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
                    .padding(.horizontal, 26)
                    .padding(.top, 16)

                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    private func advance() {
        Buzz.tap()
        withAnimation { step += 1 }
    }

    private func finish() {
        // Nothing is asked for up front. City resolves from location, and the
        // tag is editable in the profile, so it just needs to be unique enough
        // to tell two people apart in the feed.
        store.completeOnboarding(
            handle: "spotter\(Int.random(in: 1000...9999))",
            city: "",
            makes: []
        )
    }
}

// MARK: - Shared scaffold

/// One demo on top, one line of copy, one button. Every step after the capture
/// uses this so the rhythm never changes.
private struct DemoStep<Content: View>: View {
    let title: String
    let line: String
    var cta: String = "Next"
    let onNext: () -> Void
    @ViewBuilder var content: Content

    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxHeight: .infinity)
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.94)

            VStack(spacing: 9) {
                Text(title)
                    .display(30)
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)

                Text(line)
                    .font(UI.font(14))
                    .foregroundStyle(Ink.faint)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 34)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)

            Button(cta, action: onNext)
                .buttonStyle(.slab)
                .padding(.horizontal, 26)
                .padding(.top, 26)
                .padding(.bottom, 14)
                .opacity(shown ? 1 : 0)
        }
        .padding(.top, 58)
        .task {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { shown = true }
        }
    }
}

// MARK: - 0 · Welcome

struct WelcomeStep: View {
    let onStart: () -> Void

    @State private var shown = false
    @State private var float = false
    @State private var glow = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            ZStack {
                // Soft purple bloom behind the car.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Ink.accent.opacity(0.4), .clear],
                            center: .center, startRadius: 4, endRadius: 190
                        )
                    )
                    .frame(width: 380, height: 380)
                    .scaleEffect(glow ? 1.06 : 0.9)
                    .blur(radius: 12)

                Image("onboard_sticker")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 26)
                    .shadow(color: .black.opacity(0.6), radius: 22, y: 14)
                    .rotationEffect(.degrees(shown ? 0 : -8))
                    .offset(y: float ? -8 : 8)
                    .scaleEffect(shown ? 1 : 0.7)
            }
            .frame(height: 300)

            Spacer(minLength: 10)

            VStack(spacing: 14) {
                HStack(spacing: 11) {
                    RevMark(size: 17)
                    Text("SUPR")
                        .display(19)
                        .tracking(4)
                        .foregroundStyle(Ink.text)
                }

                Text("Catch cars in the wild")
                    .display(34)
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)

                Text("Photograph what you see. SUPR works out what it is and turns it into a sticker for your garage.")
                    .font(UI.font(14.5))
                    .foregroundStyle(Ink.faint)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 34)
            }
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)

            Spacer(minLength: 20)

            Button("Try it", action: onStart)
                .buttonStyle(.slab)
                .padding(.horizontal, 26)
                .padding(.bottom, 22)
                .opacity(shown ? 1 : 0)
        }
        .task {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.7)) { shown = true }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { float = true }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

// MARK: - 2 · Level

/// The XP earned in the previous step is shown landing: bar fills, level ticks
/// over, the badge upgrades.
private struct LevelStep: View {
    let onNext: () -> Void

    @State private var progress: Double = 0.1
    @State private var level = 1
    @State private var tier = 0
    @State private var pop = false

    /// One rank per tier, so the six badges all get shown climbing.
    private var rank: Rank { Ranks.all[min(tier * 5, Ranks.all.count - 1)] }

    var body: some View {
        DemoStep(
            title: "Level up your garage",
            line: "Rarer catches pay more XP. Every level moves you up the ranks, from Rookie to Apex.",
            onNext: onNext
        ) {
            VStack(spacing: 26) {
                RankBadge(rank: rank, size: 128, showsStep: false)
                    .scaleEffect(pop ? 1.1 : 1)
                    .shadow(color: rank.tier.color.opacity(0.35), radius: pop ? 26 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: pop)
                    .animation(.easeInOut(duration: 0.35), value: tier)

                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("LEVEL")
                            .label(10, .semibold, tracking: 1)
                            .foregroundStyle(Ink.faint)
                        Text("\(level)")
                            .display(30)
                            .foregroundStyle(Ink.text)
                            .contentTransition(.numericText())
                        Spacer()
                        Text(rank.name)
                            .font(UI.font(13.5, .semibold))
                            .foregroundStyle(rank.tier.color)
                            .contentTransition(.opacity)
                    }

                    XPBar(progress: progress, height: 12)
                }
                .padding(.horizontal, 30)
            }
            .task { climb() }
        }
    }

    private func climb() {
        Task {
            try? await Task.sleep(for: .milliseconds(420))

            for next in 1...5 {
                withAnimation(.easeInOut(duration: 0.5)) { progress = 1 }
                try? await Task.sleep(for: .milliseconds(520))

                Buzz.win()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) {
                    tier = next
                    level = Ranks.all[next * 5].level
                    progress = 0
                }
                pop = true
                try? await Task.sleep(for: .milliseconds(200))
                pop = false
                try? await Task.sleep(for: .milliseconds(200))
            }

            withAnimation(.easeInOut(duration: 0.7)) { progress = 0.58 }
        }
    }
}

// MARK: - 3 · Community

/// Posts stack in one by one and the top one gets liked, so the mechanic is
/// shown rather than described.
private struct CommunityStep: View {
    let onNext: () -> Void

    @State private var visible = 0
    @State private var liked = false
    @State private var likes = 23
    @State private var burst = false

    private let posts: [(String, String, String)] = [
        ("mika", "MIAMI", "Caught this outside the marina at 6am. Worth the alarm."),
        ("dre", "LOS ANGELES", "Third one this week. The valet knows me now."),
        ("kenji", "TOKYO", "Daikoku on a Saturday is unfair.")
    ]

    var body: some View {
        DemoStep(
            title: "Talk to other spotters",
            line: "Every catch you post lands in the feed. Like it, comment on it, join a crew in your city.",
            onNext: onNext
        ) {
            VStack(spacing: 11) {
                ForEach(Array(posts.enumerated()), id: \.offset) { i, post in
                    card(i, post)
                        .opacity(visible > i ? 1 : 0)
                        .offset(y: visible > i ? 0 : 26)
                        .scaleEffect(visible > i ? 1 : 0.96)
                }
            }
            .padding(.horizontal, 26)
            .task { play() }
        }
    }

    private func card(_ index: Int, _ post: (String, String, String)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Avatar(handle: post.0, image: nil, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("@\(post.0)")
                        .font(UI.font(13.5, .semibold))
                        .foregroundStyle(Ink.text)
                    Text(post.1)
                        .label(9, .semibold, tracking: 0.6)
                        .foregroundStyle(Ink.ghost)
                }
                Spacer(minLength: 0)
                if index == 0 {
                    Image("onboard_sticker")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 74, height: 34)
                }
            }

            Text(post.2)
                .font(UI.font(13.5))
                .foregroundStyle(Ink.dim)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    ZStack {
                        Image(systemName: index == 0 && liked ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(index == 0 && liked ? Ink.accent : Ink.faint)
                            .scaleEffect(index == 0 && burst ? 1.5 : 1)

                        if index == 0 && burst {
                            Circle()
                                .strokeBorder(Ink.accent.opacity(0.5), lineWidth: 2)
                                .frame(width: 34, height: 34)
                                .scaleEffect(burst ? 1.4 : 0.3)
                                .opacity(burst ? 0 : 1)
                        }
                    }
                    Text("\(index == 0 ? likes : 9 + index * 4)")
                        .font(UI.font(12.5, .semibold))
                        .foregroundStyle(Ink.faint)
                        .contentTransition(.numericText())
                }
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(2 + index)")
                        .font(UI.font(12.5, .semibold))
                }
                .foregroundStyle(Ink.faint)
                Spacer(minLength: 0)
            }
        }
        .padding(13)
        .card()
    }

    private func play() {
        Task {
            for i in 1...posts.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { visible = i }
                Buzz.soft()
                try? await Task.sleep(for: .milliseconds(230))
            }

            try? await Task.sleep(for: .milliseconds(620))
            Buzz.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                liked = true
                likes += 1
                burst = true
            }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.25)) { burst = false }
        }
    }
}

// MARK: - 4 · Map

/// Pins drop onto a street grid, one of them yours.
private struct MapStep: View {
    let onNext: () -> Void

    @State private var dropped = 0

    private let pins: [(CGFloat, CGFloat, Bool)] = [
        (0.24, 0.30, false),
        (0.68, 0.22, false),
        (0.50, 0.52, true),
        (0.30, 0.72, false),
        (0.78, 0.66, false)
    ]

    var body: some View {
        DemoStep(
            title: "See where cars turn up",
            line: "Developed catches drop a pin. Tap one to see the original shot and who found it.",
            cta: "Continue",
            onNext: onNext
        ) {
            ZStack {
                streets
                GeometryReader { geo in
                    ForEach(Array(pins.enumerated()), id: \.offset) { i, pin in
                        pinView(mine: pin.2, on: dropped > i)
                            .position(x: pin.0 * geo.size.width, y: pin.1 * geo.size.height)
                    }
                }
            }
            .frame(height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Ink.line, lineWidth: 1)
            )
            .padding(.horizontal, 26)
            .task { drop() }
        }
    }

    /// Abstract streets, no map tiles pulled just to run an animation.
    private var streets: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0.0, through: size.width, by: 46) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, through: size.height, by: 46) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Ink.line.opacity(0.55)), lineWidth: 1)

            var wide = Path()
            wide.move(to: CGPoint(x: 0, y: size.height * 0.52))
            wide.addLine(to: CGPoint(x: size.width, y: size.height * 0.44))
            wide.move(to: CGPoint(x: size.width * 0.5, y: 0))
            wide.addLine(to: CGPoint(x: size.width * 0.42, y: size.height))
            context.stroke(wide, with: .color(Ink.raised), lineWidth: 7)
        }
        .background(Ink.card)
    }

    private func pinView(mine: Bool, on: Bool) -> some View {
        ZStack {
            if mine && on {
                Circle()
                    .fill(Ink.accent.opacity(0.16))
                    .frame(width: 96, height: 96)
            }
            ZStack {
                Circle()
                    .fill(Ink.cardAlt)
                    .overlay(Circle().strokeBorder(mine ? Ink.accent : Ink.line, lineWidth: 2))
                Image("onboard_sticker")
                    .resizable()
                    .scaledToFit()
                    .padding(9)
            }
            .frame(width: mine ? 62 : 48, height: mine ? 62 : 48)
            .shadow(color: .black.opacity(0.5), radius: 7, y: 4)
        }
        .scaleEffect(on ? 1 : 0.1)
        .opacity(on ? 1 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.55), value: on)
    }

    private func drop() {
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            for i in 1...pins.count {
                dropped = i
                Buzz.soft()
                try? await Task.sleep(for: .milliseconds(190))
            }
        }
    }
}


// MARK: - Last step

/// The end of onboarding asks Superwall first. If the campaign has nothing for
/// this person, the built in paywall stands in, and either way onboarding ends
/// when it closes.
private struct OnboardingPaywall: View {
    let onDone: () -> Void

    @State private var decided = false
    @State private var showNative = false

    var body: some View {
        ZStack {
            Ink.bg.ignoresSafeArea()
            if !decided {
                ProgressView().tint(Ink.accent)
            }
        }
        .task {
            guard !decided else { return }
            let handled = await Paywalls.shared.present(.onboarding)
            decided = true
            if handled {
                onDone()
            } else {
                showNative = true
            }
        }
        .fullScreenCover(isPresented: $showNative) {
            PaywallView(context: .onboarding) { _ in onDone() }
        }
    }
}
