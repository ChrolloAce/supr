import SwiftUI

struct RevealView: View {
    let payload: GameStore.RevealPayload

    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var stage = 0

    private var car: CarModel { payload.capture.car }

    var body: some View {
        ZStack {
            Ink.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                card.padding(.horizontal, 26)
                Spacer(minLength: 12)
                stats
                actions
            }
            .padding(.vertical, 20)
        }
        .task { run() }
        .interactiveDismissDisabled(stage < 1)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(payload.isNew ? "New entry" : "Logged again")
                .label(10, .bold, tracking: 1.4)
                .foregroundStyle(Ink.faint)
            Text("SUPR \(car.dexNumber)")
                .display(30)
                .foregroundStyle(payload.isNew ? Ink.accent : Ink.text)
        }
        .opacity(stage >= 1 ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: stage)
    }

    private var card: some View {
        VStack(spacing: 0) {
            ZStack {
                if let image = payload.image ?? store.image(for: payload.capture) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    CarPlate(car: car, glyphWidth: 190)
                }
                CornerBrackets(color: Ink.line, length: 24, thickness: 3, inset: 12)
            }
            .frame(height: 236)
            .frame(maxWidth: .infinity)
            .clipped()

            Rectangle().fill(Ink.line).frame(height: Line.bold)
            RarityStrip(rarity: car.rarity)
            Rectangle().fill(Ink.line).frame(height: Line.bold)

            VStack(alignment: .leading, spacing: 2) {
                Text(car.make)
                    .label(10, .heavy, tracking: 0.8)
                    .foregroundStyle(Ink.accent)
                HStack(alignment: .firstTextBaseline) {
                    Text(car.model)
                        .display(30)
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 8)
                    Text(car.year)
                        .display(22)
                        .foregroundStyle(Ink.faint)
                }
                HStack {
                    Text(car.body.title)
                        .label(9, .bold, tracking: 0.6)
                        .foregroundStyle(Ink.ghost)
                    Spacer()
                    Text(payload.capture.city)
                        .label(9, .bold, tracking: 0.6)
                        .foregroundStyle(Ink.ghost)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.card)
        }
        .card()
        .scaleEffect(stage >= 1 ? 1 : 0.9)
        .opacity(stage >= 1 ? 1 : 0)
    }

    private var stats: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                BlockTag(text: "+\(payload.capture.xpAwarded) XP", fill: Ink.accent)
                if payload.isNew { BlockTag(text: "First catch", fill: Ink.accentSoft, textColor: Ink.line) }
                if payload.huntCompleted { BlockTag(text: "Quest done", fill: Ink.done) }
            }

            if payload.leveledUp {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .black))
                    Text("Level up · LV \(payload.newLevel)")
                        .label(12, .heavy, tracking: 0.8)
                }
                .foregroundStyle(Ink.line)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .outlined(Ink.accentSoft, radius: R.badge)
            }

            let p = Levels.progress(xp: store.profile.xp)
            VStack(spacing: 7) {
                HStack {
                    Text("LV \(p.level)")
                        .label(10.5, .heavy, tracking: 0.6)
                        .foregroundStyle(Ink.text)
                    Spacer()
                    Text("\(p.need - p.into) XP TO LV \(p.level + 1)")
                        .label(9.5, .bold, tracking: 0.4)
                        .foregroundStyle(Ink.faint)
                }
                XPBar(progress: p.fraction, height: 12)
            }
            .padding(.horizontal, 26)
            .padding(.top, 6)
        }
        .opacity(stage >= 2 ? 1 : 0)
        .animation(.easeOut(duration: 0.35), value: stage)
        .padding(.bottom, 20)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button("Add to garage") {
                Buzz.tap()
                dismiss()
            }
            .buttonStyle(.primary)

            Button {
                Buzz.nope()
                store.deleteCapture(payload.capture)
                dismiss()
            } label: {
                Text("Wrong car? Discard")
                    .label(10.5, .bold, tracking: 0.8)
                    .foregroundStyle(Ink.faint)
            }
        }
        .padding(.horizontal, 26)
        .opacity(stage >= 2 ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: stage)
    }

    private func run() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { stage = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(340))
            withAnimation { stage = 2 }
            if payload.leveledUp { Buzz.win() }
        }
    }
}
