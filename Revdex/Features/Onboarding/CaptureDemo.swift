import SwiftUI

/// The onboarding centrepiece: you actually take the shot.
///
/// A real photo runs through the real sequence, shutter, scan, plate cover,
/// sticker, filed into the garage. Nothing is described in words that the
/// person cannot just do.
struct CaptureDemo: View {
    let onFinish: () -> Void

    enum Phase: Int, Comparable {
        case ready, flash, scanning, identified, filed

        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    @State private var phase: Phase = .ready
    @State private var scanY: CGFloat = -1
    @State private var bracketPulse = false
    @State private var stickerInGarage = false
    @State private var xpShown = false

    private let car = Catalog.car(16)   // Porsche 911 GT3 RS, the demo subject

    var body: some View {
        VStack(spacing: 0) {
            caption
                .padding(.horizontal, 26)
                .padding(.bottom, 22)

            stage
                .padding(.horizontal, 26)

            Spacer(minLength: 16)

            action
                .padding(.horizontal, 26)
                .padding(.bottom, 18)
        }
        .padding(.top, 64)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                bracketPulse = true
            }
        }
    }

    // MARK: Words

    private var caption: some View {
        VStack(spacing: 8) {
            Text(title)
                .display(30)
                .foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            Text(subtitle)
                .font(UI.font(14))
                .foregroundStyle(Ink.faint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(height: 44, alignment: .top)
                .contentTransition(.opacity)
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    private var title: String {
        switch phase {
        case .ready: return "See a car?"
        case .flash, .scanning: return "Reading it"
        case .identified: return "Developed"
        case .filed: return "In your garage"
        }
    }

    private var subtitle: String {
        switch phase {
        case .ready: return "Point, shoot, and SUPR works out what it is."
        case .flash, .scanning: return "Identifying the model and covering the plate."
        case .identified: return "Cut out as a sticker, plate hidden. The car is untouched."
        case .filed: return "Every catch lands here, ranked by how rare it is."
        }
    }

    // MARK: Stage

    private var stage: some View {
        ZStack {
            viewfinder
                .opacity(phase >= .filed ? 0 : 1)
                .scaleEffect(phase >= .filed ? 0.86 : 1)

            if phase >= .filed { garage.transition(.opacity) }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 330)
        .animation(.spring(response: 0.55, dampingFraction: 0.8), value: phase)
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Ink.cardAlt)

            // The shot, then the sticker it becomes.
            Group {
                if phase >= .identified {
                    ZStack {
                        LinearGradient(colors: [Ink.cardAlt, Ink.card], startPoint: .top, endPoint: .bottom)
                        Image("onboard_sticker")
                            .resizable()
                            .scaledToFit()
                            .padding(18)
                            .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                } else {
                    // Color.clear takes the layout, the photo just fills it.
                    // scaledToFill on its own would widen the whole screen.
                    Color.clear.overlay {
                        Image("onboard_photo")
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Scan sweep.
            if phase == .scanning {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Ink.accent.opacity(0.75), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 90)
                    .offset(y: scanY * geo.size.height)
                    .blendMode(.plusLighter)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .allowsHitTesting(false)
            }

            if phase < .identified {
                CornerBrackets(
                    color: .white.opacity(phase == .scanning ? 0.95 : (bracketPulse ? 0.85 : 0.4)),
                    length: 30,
                    thickness: 3,
                    inset: 18
                )
            }

            if phase == .flash {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
                    .transition(.opacity)
            }

            // Result badge.
            if phase >= .identified {
                VStack {
                    Spacer()
                    HStack(spacing: 9) {
                        Circle().fill(car.rarity.color).frame(width: 8, height: 8)
                        Text(car.fullName)
                            .font(UI.font(14, .semibold))
                            .foregroundStyle(Ink.text)
                        Text(car.rarity.title)
                            .label(9.5, .semibold, tracking: 0.6)
                            .foregroundStyle(car.rarity.color)
                        Spacer(minLength: 0)
                        Text("+\(car.rarity.xp) XP")
                            .font(UI.font(13, .semibold))
                            .foregroundStyle(Ink.accent)
                            .opacity(xpShown ? 1 : 0)
                            .scaleEffect(xpShown ? 1 : 0.6)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: R.chip, style: .continuous))
                    .padding(10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Ink.line, lineWidth: 1)
        )
    }

    /// The catch dropping into a grid.
    private var garage: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                filledSlot
                emptySlot
            }
            HStack(spacing: 12) {
                emptySlot
                emptySlot
            }
        }
    }

    private var filledSlot: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [Ink.cardAlt, Ink.card], startPoint: .top, endPoint: .bottom)
                Image("onboard_sticker")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            }
            .frame(height: 96)

            VStack(alignment: .leading, spacing: 1) {
                Text(car.make)
                    .font(UI.font(9, .semibold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Ink.faint)
                Text(car.model)
                    .display(15)
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
        }
        .card(Ink.card, radius: R.tile)
        .overlay(
            RoundedRectangle(cornerRadius: R.tile, style: .continuous)
                .strokeBorder(car.rarity.color.opacity(stickerInGarage ? 0.9 : 0), lineWidth: 2)
        )
        .scaleEffect(stickerInGarage ? 1 : 0.7)
        .opacity(stickerInGarage ? 1 : 0)
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: R.tile, style: .continuous)
            .strokeBorder(Ink.line, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            .frame(height: 145)
    }

    // MARK: Action

    @ViewBuilder
    private var action: some View {
        switch phase {
        case .ready:
            Button {
                run()
            } label: {
                Text("Capture it")
            }
            .buttonStyle(.slab)

        case .flash, .scanning:
            HStack(spacing: 10) {
                ProgressView().tint(Ink.accent)
                Text("Developing")
                    .font(UI.font(14, .semibold))
                    .foregroundStyle(Ink.faint)
            }
            .frame(height: 54)

        case .identified, .filed:
            Button("Next", action: onFinish)
                .buttonStyle(.slab)
                .transition(.opacity)
        }
    }

    // MARK: Sequence

    private func run() {
        Buzz.heavy()
        withAnimation(.easeOut(duration: 0.08)) { phase = .flash }

        Task {
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeIn(duration: 0.2)) { phase = .scanning }

            scanY = -0.3
            withAnimation(.easeInOut(duration: 1.15).repeatCount(2, autoreverses: false)) {
                scanY = 1.1
            }

            try? await Task.sleep(for: .milliseconds(1700))
            Buzz.win()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = .identified }

            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { xpShown = true }

            try? await Task.sleep(for: .milliseconds(950))
            Buzz.soft()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { phase = .filed }

            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { stickerInGarage = true }
        }
    }
}
