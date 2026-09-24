import SwiftUI

struct CarDetailView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let capture: Capture

    @State private var confirmDelete = false
    @State private var showOriginal = false
    @State private var renderError: String?
    @State private var viewing = false
    @State private var shareItem: ShareItem?
    @State private var building = false
    @State private var showPaywall = false

    private var car: CarModel { capture.car }
    private var allCatches: [Capture] { store.captures(of: car.id) }

    /// The catch's tier, used only where the page is meant to shout: the frame
    /// and brackets around the photo, and the two buttons. Everything else
    /// stays the ordinary greys.
    private var tier: Rarity { capture.rarity }

    private var render: UIImage? { store.developedImage(for: capture) }
    private var photo: UIImage? { store.image(for: capture) }
    private var canSwitch: Bool { render != nil && photo != nil }
    /// Whatever the hero is showing right now, which is also what gets shared.
    private var shownImage: UIImage? { showOriginal ? photo : (render ?? photo) }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Entry \(car.dexNumber)") { dismiss() }

                ScrollView {
                    VStack(spacing: 12) {
                        hero
                        developRow
                        statsRow
                        specSection
                        logSection
                        // Room for the pinned bar so nothing hides behind it.
                        Spacer(minLength: 96)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)
            }

            // Share and delete stay reachable without scrolling to the end.
            VStack {
                Spacer()
                actionBar
            }
        }
        .fullScreenCover(isPresented: $viewing) {
            CaptureViewer(capture: capture, showOriginal: $showOriginal)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.caption, item.image])
        }
        .suprPaywall(.outOfDevelops, isPresented: $showPaywall, context: .outOfDevelops)
    }

    private var hero: some View {
        VStack(spacing: 0) {
            Button {
                Buzz.tap()
                viewing = true
            } label: {
                ZStack {
                    LinearGradient(colors: [Ink.cardAlt, Ink.card], startPoint: .top, endPoint: .bottom)

                    // Crossfade, never interpolate: morphing between two
                    // different photographs warps the car.
                    if !showOriginal, let render {
                        // The render is a wide 3:2 frame. Filling a tall hero
                        // with it cut the nose and tail off, so it is fitted
                        // whole and the card breathes around it instead.
                        Image(uiImage: render)
                            .resizable()
                            .scaledToFit()
                    } else if let photo {
                        // The original is whatever shape it was shot in, so it
                        // is fitted too rather than cropped to taste.
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                    } else {
                        CarPlate(car: car, glyphWidth: 220)
                    }

                    // The brackets and the frame around them are the tier at
                    // full strength: on a legendary they read gold.
                    CornerBrackets(color: tier.frame, length: 24, thickness: 2, inset: 11)

                    // Says the hero is tappable without covering the car.
                    if shownImage != nil {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(.black.opacity(0.45)))
                            }
                            Spacer()
                        }
                        .padding(11)
                    }
                }
                .frame(height: 250)
                .frame(maxWidth: .infinity)
                .clipped()
                .animation(.easeInOut(duration: 0.18), value: showOriginal)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if canSwitch { modeSwitch }

            RarityStrip(rarity: capture.rarity)

            VStack(alignment: .leading, spacing: 4) {
                Text(car.make)
                    .label(9, .semibold, tracking: 1.6)
                    .foregroundStyle(Ink.faint)
                Text(car.model)
                    .font(UI.font(21, .bold))
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Chassis code and production run, so a 992.2 is not just
                // "a 911".
                if !car.lineage.isEmpty {
                    Text(car.lineage)
                        .label(9.5, .bold, tracking: 1)
                        .foregroundStyle(Ink.dim)
                }

                if let spec = capture.spec {
                    Text(spec)
                        .font(UI.font(12))
                        .foregroundStyle(Ink.dim)
                        .lineLimit(1)
                }

                if let variant = capture.variant {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text(variant)
                            .font(UI.font(12, .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(capture.rarity.onColor)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill(capture.rarity.color))
                    .padding(.top, 4)
                }

                if let note = capture.note {
                    Text(note)
                        .font(UI.font(12.5))
                        .foregroundStyle(Ink.faint)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: R.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.card, style: .continuous)
                .strokeBorder(tier.frame, lineWidth: 1.5)
        )
    }

    /// Sticker or original, sitting under the image where both are one tap away.
    private var modeSwitch: some View {
        HStack(spacing: 0) {
            modeTab("Render", on: !showOriginal) { showOriginal = false }
            modeTab("Original", on: showOriginal) { showOriginal = true }
        }
        .frame(height: 42)
        .background(Ink.cardAlt)
    }

    private func modeTab(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Buzz.soft()
            action()
        } label: {
            Text(title)
                .font(UI.font(13, .semibold))
                .foregroundStyle(on ? Ink.text : Ink.faint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(on ? tier.frame : .clear)
                        .frame(height: 3)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Pinned actions

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                Buzz.tap()
                building = true
                Task {
                    // Rendering the card is quick but not free, so it happens
                    // on demand rather than for every card in the garage.
                    let card = ShareCard.render(capture: capture, image: shownImage)
                    building = false
                    if let card {
                        shareItem = ShareItem(image: card, caption: ShareItem.caption(for: capture))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if building {
                        ProgressView().tint(tier.onColor).scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text("Share")
                }
            }
            // The one place the tier is worth shouting: the button under a
            // legendary is gold.
            .buttonStyle(.rarity(tier))
            .disabled(building)

            Button {
                Buzz.nope()
                if confirmDelete {
                    store.deleteCapture(capture)
                    dismiss()
                } else {
                    withAnimation(.easeOut(duration: 0.15)) { confirmDelete = true }
                }
            } label: {
                Image(systemName: confirmDelete ? "trash.fill" : "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(confirmDelete ? .white : Ink.faint)
                    .frame(width: 54, height: 54)
            }
            // Neutral, like every other secondary control, until it is armed.
            .buttonStyle(SlabTileStyle(
                fill: confirmDelete ? Color(hex: 0xC0392B) : Ink.card,
                slab: confirmDelete ? Color(hex: 0x8E2A1F) : Ink.raised,
                border: confirmDelete ? Color(hex: 0xC0392B) : Ink.line,
                drop: 4
            ))
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [Ink.bg.opacity(0), Ink.bg.opacity(0.92), Ink.bg],
                           startPoint: .top, endPoint: .bottom)
                .padding(.top, -26)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .top) {
            if confirmDelete {
                Text("Tap the bin again to delete this catch")
                    .font(UI.font(11.5, .semibold))
                    .foregroundStyle(Ink.faint)
                    .offset(y: -8)
            }
        }
    }

    /// Develop turns the raw shot into a graded plate with the number plate masked.
    @ViewBuilder
    private var developRow: some View {
        if store.image(for: capture) != nil {
            if capture.isDeveloped {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(capture.wasCompleted ? "Showroom render" : "Render pending")
                            .font(UI.font(14, .semibold))
                            .foregroundStyle(Ink.text)
                        Text(capture.wasCompleted
                             ? "Same car, shot in the showroom"
                             : "The render did not run. Plate is covered.")
                            .font(UI.font(11.5))
                            .foregroundStyle(Ink.faint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    // Switching views is the job of the tabs under the hero,
                    // so this row only reports what happened.
                }
                .padding(.horizontal, 14)
                .frame(height: 62)
                .card()
            } else {
                let busy = store.developing.contains(capture.id)

                VStack(spacing: 8) {
                    Button {
                        Buzz.tap()
                        // Being out is not a dead end. The button keeps working
                        // and sends you where the develops come from, rather
                        // than greying out and leaving you to find the shop.
                        guard store.canDevelop else {
                            showPaywall = true
                            return
                        }
                        // Kick it off and get out of the way; the garage card
                        // shows the progress from here.
                        Task { await store.develop(capture) }
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: store.canDevelop ? "wand.and.sparkles" : "bolt.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text(store.canDevelop ? "Develop this catch" : "Get more develops")
                        }
                    }
                    // Same tier as Share, so the pair of actions on this page
                    // belong to the car rather than to the app chrome. The
                    // glint only runs when the tap does something.
                    .buttonStyle(.rarity(tier, shine: !busy))
                    .disabled(busy)
                    .opacity(busy ? 0.5 : 1)

                    // The cost is stated before it is spent, not after.
                    Text(store.canDevelop
                         ? "Costs 1 · \(store.developsLeft) left · takes a minute or two"
                         : "You are out. Watch an ad or go Pro for more.")
                        .font(UI.font(11.5))
                        .foregroundStyle(store.canDevelop ? Ink.faint : Ink.accentSoft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Second, optional pass. Regenerates pixels, so it sits behind its own
    /// button rather than replacing the honest developed frame.
    @ViewBuilder
    private var renderRow: some View {
        if Secrets.hasFlux, capture.isDeveloped, capture.renderedFile == nil {
            VStack(spacing: 8) {
                Button {
                    Buzz.tap()
                    renderError = nil
                    Task {
                        do { try await store.render(capture) }
                        catch { renderError = error.localizedDescription }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Cinematic render")
                    }
                }
                .buttonStyle(.rarityQuiet(tier))
                .disabled(store.developing.contains(capture.id))

                if let renderError {
                    Text(renderError)
                        .font(UI.font(11.5))
                        .foregroundStyle(Ink.accent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// The four numbers people actually argue about on the kerb. Anything the
    /// catalogue does not know about a car falls back to something it does,
    /// so the row is never half empty.
    private var statsRow: some View {
        HStack(spacing: 10) {
            stat("Power", car.powerLine ?? car.year)
            stat("0-60", car.sprintLine ?? car.body.title)
            stat("Top", car.topSpeedLine ?? "\(capture.rarity.xp) XP")
            stat("Caught", "\(allCatches.count)x")
        }
    }

    /// The full sheet. Long, on purpose: this is the page you open to settle
    /// an argument about what the thing you just photographed actually is.
    private var specSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Spec sheet")
                    .label(10, .semibold, tracking: 1.8)
                    .foregroundStyle(Ink.faint)
                Spacer()
                Image(systemName: car.fuel.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Ink.faint)
                Text(car.drive.title)
                    .label(10, .bold, tracking: 1)
                    .foregroundStyle(Ink.dim)
            }
            .padding(.horizontal, 15)
            .frame(height: 44)

            Rectangle().fill(Ink.line).frame(height: 1)

            let rows = car.specSheet
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.0)
                        .label(9.5, .semibold, tracking: 1.1)
                        .foregroundStyle(Ink.faint)
                    Spacer(minLength: 10)
                    Text(row.1)
                        .font(UI.font(12.5, .semibold))
                        .foregroundStyle(Ink.text)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 40)

                if i < rows.count - 1 {
                    Rectangle().fill(Ink.line.opacity(0.5)).frame(height: 1)
                }
            }
        }
        .card()
    }

    private func stat(_ caption: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(UI.font(14, .bold))
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .label(8, .semibold, tracking: 1.2)
                .foregroundStyle(Ink.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .card(Ink.card, radius: R.chip)
    }

    private var logSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Catch log")
                    .label(10, .semibold, tracking: 1.8)
                    .foregroundStyle(Ink.faint)
                Spacer()
                Text("\(allCatches.count)")
                    .label(10, .bold, tracking: 1)
                    .foregroundStyle(Ink.dim)
            }
            .padding(.horizontal, 15)
            .frame(height: 44)

            Rectangle().fill(Ink.line).frame(height: 1)

            ForEach(Array(allCatches.enumerated()), id: \.element.id) { i, c in
                HStack(spacing: 12) {
                    Circle().fill(car.rarity.color).frame(width: 6, height: 6)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(UI.font(11.5, .semibold))
                            .foregroundStyle(Ink.text)
                        Text(c.city)
                            .label(8, .medium, tracking: 1.2)
                            .foregroundStyle(Ink.ghost)
                    }
                    Spacer()
                    if c.isFirstCatch {
                        Text("FIRST")
                            .label(8, .bold, tracking: 1)
                            .foregroundStyle(Ink.done)
                    }
                    Text("+\(c.xpAwarded)")
                        .font(UI.font(11.5, .semibold))
                        .foregroundStyle(Ink.accent)
                }
                .padding(.horizontal, 15)
                .frame(height: 54)

                if i < allCatches.count - 1 {
                    Rectangle().fill(Ink.line).frame(height: 1).padding(.leading, 33)
                }
            }
        }
        .card()
    }

}
