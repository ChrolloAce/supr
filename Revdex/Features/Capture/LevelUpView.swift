import SwiftUI

/// The moment a catch pushes you over a level. Takes the whole screen, lights
/// the border, runs the bar up, and gets out of the way.
///
/// It can be turned off for good from inside itself, because the third time you
/// see an animation you did not ask for it stops being a reward.
struct LevelUpView: View {
    struct Payload: Identifiable, Equatable {
        let id = UUID()
        let fromLevel: Int
        let toLevel: Int
        let xpBefore: Int
        let xpAfter: Int
        let xpGained: Int

        var rankBefore: Rank { Ranks.rank(for: fromLevel) }
        var rankAfter: Rank { Ranks.rank(for: toLevel) }
        var rankedUp: Bool { rankBefore.level != rankAfter.level }

        static func == (a: Payload, b: Payload) -> Bool { a.id == b.id }
    }

    let payload: Payload
    let onDone: () -> Void

    /// Read by the capture pipeline, which skips presenting this entirely.
    @AppStorage(Self.skipKey) private var skipNextTime = false
    static let skipKey = "revdex.skipLevelAnimation"

    @State private var border: CGFloat = 0
    @State private var glow = false
    @State private var shownLevel = 0
    @State private var fill: Double = 0
    @State private var titleIn = false
    @State private var badgeIn = false
    @State private var xpIn = false
    @State private var controlsIn = false

    private var progressAfter: Double { Levels.progress(xp: payload.xpAfter).fraction }
    private var rank: Rank { Ranks.rank(for: shownLevel) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Border lighting up, then breathing.
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .trim(from: 0, to: border)
                .stroke(
                    LinearGradient(
                        colors: [Ink.accent, Ink.accentSoft, Ink.accent],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .shadow(color: Ink.accent.opacity(glow ? 0.85 : 0.3), radius: glow ? 26 : 8)
                .padding(6)
                .ignoresSafeArea()

            // Faint bloom so the middle of the screen is not dead black.
            RadialGradient(
                colors: [Ink.accent.opacity(glow ? 0.20 : 0.06), .clear],
                center: .center, startRadius: 10, endRadius: 420
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            content
        }
        .task { run() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            Text(payload.rankedUp ? "RANK UP" : "LEVEL UP")
                .label(12, .semibold, tracking: 5)
                .foregroundStyle(Ink.accentSoft)
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 10)

            Text("\(shownLevel)")
                .font(Disp.font(112, .black))
                .foregroundStyle(Ink.text)
                .contentTransition(.numericText())
                .shadow(color: Ink.accent.opacity(0.55), radius: 24)
                .padding(.top, 2)
                .opacity(titleIn ? 1 : 0)

            Text(rank.name.uppercased())
                .label(11, .semibold, tracking: 3)
                .foregroundStyle(rank.tier.color)
                .opacity(titleIn ? 1 : 0)

            Spacer(minLength: 24)

            RankBadge(rank: rank, size: 132, showsStep: false)
                .scaleEffect(badgeIn ? 1 : 0.55)
                .opacity(badgeIn ? 1 : 0)
                .shadow(color: rank.tier.color.opacity(0.4), radius: 26)

            Spacer(minLength: 24)

            VStack(spacing: 10) {
                XPBar(progress: fill, height: 14)

                HStack {
                    Text("\(payload.xpAfter.formatted()) XP")
                        .font(UI.font(12.5, .semibold))
                        .foregroundStyle(Ink.dim)
                    Spacer()
                    Text("+\(payload.xpGained) THIS CATCH")
                        .label(9.5, .semibold, tracking: 1)
                        .foregroundStyle(Ink.accent)
                        .opacity(xpIn ? 1 : 0)
                }
            }
            .padding(.horizontal, 34)

            Spacer(minLength: 30)

            VStack(spacing: 14) {
                Button("Nice", action: finish)
                    .buttonStyle(.primary)

                Button {
                    Buzz.soft()
                    skipNextTime.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: skipNextTime ? "checkmark.square.fill" : "square")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Skip this animation next time")
                            .font(UI.font(13))
                    }
                    .foregroundStyle(skipNextTime ? Ink.accent : Ink.faint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 26)
            .opacity(controlsIn ? 1 : 0)
        }
    }

    // MARK: Sequence

    private func run() {
        shownLevel = payload.fromLevel
        fill = Levels.progress(xp: payload.xpBefore).fraction

        Task {
            Buzz.heavy()
            withAnimation(.easeOut(duration: 0.85)) { border = 1 }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }

            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { titleIn = true }

            // Run the bar up one level at a time so a multi level jump reads.
            for level in (payload.fromLevel + 1)...max(payload.fromLevel + 1, payload.toLevel) {
                try? await Task.sleep(for: .milliseconds(260))
                withAnimation(.easeInOut(duration: 0.45)) { fill = 1 }
                try? await Task.sleep(for: .milliseconds(460))

                Buzz.win()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                    shownLevel = min(level, payload.toLevel)
                    fill = 0
                }
                if level >= payload.toLevel { break }
            }

            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) { badgeIn = true }
            withAnimation(.easeInOut(duration: 0.7)) { fill = progressAfter }

            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeOut(duration: 0.3)) { xpIn = true }

            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.easeOut(duration: 0.3)) { controlsIn = true }
        }
    }

    private func finish() {
        Buzz.tap()
        onDone()
    }
}
