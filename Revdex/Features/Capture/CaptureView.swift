import AVFoundation
import StoreKit
import SwiftUI
import PhotosUI

/// Lets the dock shutter button drive the capture screen.
@MainActor
final class CaptureCoordinator: ObservableObject {
    @Published var shutterTicks = 0
    @Published var busy = false
    func fire() { shutterTicks += 1 }
}

struct CaptureView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var coordinator: CaptureCoordinator
    @EnvironmentObject private var queue: ScanQueue
    @StateObject private var camera = CameraController()

    @State private var showPaywall = false
    @State private var showEarn = false
    @Environment(\.requestReview) private var requestReview
    @State private var showQuest = false
    /// A whole roll can come in at once, so this is a list.
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var flash = false
    @State private var detail: Capture?

    // Pinch zoom
    @State private var zoom: CGFloat = 1
    @State private var pinchStart: CGFloat = 1
    @State private var zoomHUD = false

    var body: some View {
        ZStack {
            viewfinder.ignoresSafeArea()
            overlay
            if flash { Color.white.ignoresSafeArea().transition(.opacity) }
        }
        .background(Color.black)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: coordinator.shutterTicks) { _ in shoot() }
        .onChange(of: pickedItems) { items in loadPicked(items) }
        .onChange(of: queue.isBusy) { busy in coordinator.busy = busy }
        .suprPaywall(.outOfCaptures, isPresented: $showPaywall, context: .outOfCaptures)
        .sheet(isPresented: $showEarn) { EarnCapturesView() }
        .onChange(of: queue.refusal) { refusal in
            // The queue turned a shot away for want of captures, which can
            // happen part way through a library import.
            guard refusal == .noCaptures else { return }
            queue.refusal = nil
            showEarn = true
        }
        .onChange(of: queue.outcome) { outcome in
            guard let outcome, !outcome.rejected else { return }
            askForReviewIfFirstCatch()
        }
        .sheet(isPresented: $showQuest) { QuestView() }
        .sheet(item: $detail) { CarDetailView(capture: $0) }
    }

    // MARK: Viewfinder

    @ViewBuilder
    private var viewfinder: some View {
        switch camera.state {
        case .ready:
            CameraPreview(session: camera.session)
                .gesture(pinch)
                .overlay { framing }
        case .denied:
            fallback(
                title: "Camera is off",
                message: "SUPR needs the camera to capture cars. Turn it on in Settings, or pull a shot from your library.",
                settings: true
            )
        case .unavailable:
            fallback(
                title: "No camera here",
                message: "This device has no camera. Pull a photo from your library to run a capture.",
                settings: false
            )
        case .idle:
            Ink.bg
        }
    }

    /// Four corner marks around the middle of the frame. Not a crop, just a
    /// sight line: put the car inside these and the scan has something to work
    /// with.
    private var framing: some View {
        GeometryReader { geo in
            let side = min(geo.size.width - 44, geo.size.height * 0.46)
            CornerBrackets(color: .white.opacity(0.75), length: 26, thickness: 3)
                .frame(width: side, height: side * 0.72)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .allowsHitTesting(false)
    }

    private var pinch: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = max(1, min(pinchStart * value, camera.maxZoom))
                camera.setZoom(zoom)
                if !zoomHUD { withAnimation(.easeOut(duration: 0.15)) { zoomHUD = true } }
            }
            .onEnded { _ in
                pinchStart = zoom
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    withAnimation(.easeIn(duration: 0.25)) { zoomHUD = false }
                }
            }
    }

    private func fallback(title: String, message: String, settings: Bool) -> some View {
        ZStack {
            Ink.bg
            VStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Ink.faint)
                Text(title)
                    .display(24)
                    .foregroundStyle(Ink.text)
                Text(message)
                    .font(UI.font(13))
                    .foregroundStyle(Ink.faint)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)

                PhotosPicker(selection: $pickedItems, maxSelectionCount: 10, matching: .images) {
                    Text("Pick from library")
                        .label(12, .heavy, tracking: 1.2)
                        .foregroundStyle(.white)
                        .frame(width: 220, height: 50)
                        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.accent))
                }
                .padding(.top, 6)

                if settings {
                    Button("Open settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .label(10.5, .bold, tracking: 0.8)
                    .foregroundStyle(Ink.dim)
                }
            }
        }
    }

    // MARK: Overlay

    private var overlay: some View {
        VStack(spacing: 0) {
            topRow
            questStrip.padding(.top, 10)

            Spacer(minLength: 0)

            if zoomHUD {
                Text(String(format: "%.1fx", zoom))
                    .display(19)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 32)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            if let refusal = queue.refusal, refusal != .noCaptures { refusalStrip(refusal) }
            else if let outcome = queue.outcome { resultToast(outcome) }

            HStack(alignment: .bottom) {
                queueStrip
                Spacer(minLength: 0)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, Dock.clearance)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: queue.pending.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: queue.outcome)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: queue.refusal)
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            Text("Capture")
                .display(24)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 6)

            Spacer()

            Button {
                Buzz.tap()
                showEarn = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(store.capturesLeftToday)")
                        .font(UI.font(13, .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(store.isOutOfCaptures ? Ink.bg : .white)
                .padding(.horizontal, 11)
                .frame(height: 40)
                .background(
                    Capsule().fill(store.isOutOfCaptures ? Ink.accentSoft : .black.opacity(0.4))
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $pickedItems, maxSelectionCount: 10, matching: .images) {
                glassChip(icon: importing ? "arrow.down.circle" : "photo.fill")
            }

            if camera.canFlip {
                Button {
                    Buzz.tap()
                    camera.flip()
                } label: {
                    glassChip(icon: "arrow.triangle.2.circlepath.camera")
                }
                .buttonStyle(.plain)
            }

            Button {
                Buzz.tap()
                camera.toggleTorch()
            } label: {
                glassChip(icon: camera.torchOn ? "bolt.fill" : "bolt.slash.fill", on: camera.torchOn)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 52)
    }

    private func glassChip(icon: String, on: Bool = false) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(on ? Ink.onAccent : .white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(on ? Ink.accentSoft : .black.opacity(0.4)))
            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }

    /// The quest lives here now, not on the garage screen.
    private var questStrip: some View {
        Button {
            Buzz.tap()
            showQuest = true
        } label: {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(store.hunt.completed ? Ink.done : Ink.accent)
                    .frame(width: 4, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Today's quest")
                        .label(8.5, .bold, tracking: 0.8)
                        .foregroundStyle(.white.opacity(0.55))
                    Text(store.hunt.headline)
                        .display(17)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 4)

                Text(store.hunt.completed ? "DONE" : "+\(store.hunt.bonusXP)")
                    .label(9.5, .heavy, tracking: 0.4)
                    .foregroundStyle(Ink.onAccent)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill(store.hunt.completed ? Ink.done : Ink.accentSoft))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(.black.opacity(0.45)))
            .overlay(
                RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Shots waiting to be identified, stacked off to the side.
    @ViewBuilder
    private var queueStrip: some View {
        if !queue.pending.isEmpty {
            HStack(spacing: -14) {
                ForEach(queue.pending.prefix(4)) { item in
                    ZStack {
                        if let thumb = queue.thumbnail(for: item) {
                            Image(uiImage: thumb).resizable().scaledToFill()
                        } else {
                            Ink.cardAlt
                        }
                        Color.black.opacity(0.35)
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.65)
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: R.chip, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1.5)
                    )
                }

                if queue.pending.count > 4 {
                    Text("+\(queue.pending.count - 4)")
                        .label(10, .heavy, tracking: 0.4)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 52)
                        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(.black.opacity(0.6)))
                        .padding(.leading, 14)
                }
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }

    /// A refused shot says why, and clears itself.
    private func refusalStrip(_ refusal: ScanQueue.Refusal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Ink.bg)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Ink.accentSoft))

            Text(refusal.message)
                .font(UI.font(13.5, .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(.black.opacity(0.7)))
        .overlay(
            RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                .strokeBorder(Ink.accentSoft.opacity(0.5), lineWidth: 1)
        )
        .padding(.bottom, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: refusal) {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation { queue.refusal = nil }
        }
    }

    /// Result lands as a tappable strip, the camera stays live behind it.
    private func resultToast(_ outcome: ScanQueue.Outcome) -> some View {
        Button {
            Buzz.tap()
            if let capture = outcome.capture { detail = capture }
            queue.outcome = nil
        } label: {
            HStack(spacing: 12) {
                if outcome.rejected {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Ink.dim)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.raised))
                } else if let capture = outcome.capture {
                    // The shot you just took, not a coloured square. This is
                    // the moment to show what was caught.
                    ZStack {
                        RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                            .fill(capture.car.rarity.plateFill)
                        if let image = store.displayImage(for: capture) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Text(capture.car.dexNumber)
                                .label(10, .heavy, tracking: 0.4)
                                .foregroundStyle(capture.car.rarity.onColor)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: R.chip, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                            .strokeBorder(capture.car.rarity.color.opacity(0.7), lineWidth: 1.5)
                    )
                }

                VStack(alignment: .leading, spacing: 2) {
                    if outcome.rejected {
                        Text("No car in frame")
                            .display(17)
                            .foregroundStyle(Ink.text)
                        Text("Nothing was added")
                            .label(9, .bold, tracking: 0.4)
                            .foregroundStyle(Ink.faint)
                    } else if let capture = outcome.capture {
                        Text(capture.car.model)
                            .display(19)
                            .foregroundStyle(Ink.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(badgeLine(outcome, capture))
                            .label(9, .bold, tracking: 0.4)
                            .foregroundStyle(Ink.accentSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Ink.faint)
            }
            .padding(.horizontal, 13)
            .frame(height: 62)
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: outcome.id) {
            try? await Task.sleep(for: .seconds(4))
            if queue.outcome?.id == outcome.id {
                withAnimation { queue.outcome = nil }
            }
        }
    }

    private func badgeLine(_ outcome: ScanQueue.Outcome, _ capture: Capture) -> String {
        var bits = ["+\(capture.xpAwarded) XP"]
        if outcome.isNew { bits.append("NEW") }
        if outcome.questCompleted { bits.append("QUEST DONE") }
        if outcome.leveledUp { bits.append("LV \(outcome.newLevel)") }
        return bits.joined(separator: "  ·  ")
    }

    // MARK: Actions

    /// The first car in the garage is the moment the app has just proved
    /// itself, so it is the one time worth asking. Apple rate limits this
    /// anyway, and the flag means we never ask twice even if it was ignored.
    private func askForReviewIfFirstCatch() {
        let key = "revdex.review.asked"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        guard store.captures.count == 1 else { return }

        UserDefaults.standard.set(true, forKey: key)
        Task {
            // Let the result strip land first; a prompt on top of an animation
            // reads as an interruption rather than a celebration.
            try? await Task.sleep(for: .seconds(1.6))
            requestReview()
        }
    }

    private func shoot() {
        if store.isOutOfCaptures {
            Buzz.nope()
            showEarn = true
            return
        }
        Buzz.heavy()
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.easeIn(duration: 0.18)) { flash = false }
        }

        let here = LocationService.lastCoordinate.map { (lat: $0.latitude, lng: $0.longitude) }
        if camera.state == .ready {
            camera.capture { queue.enqueue($0, at: here) }
        } else {
            queue.enqueue(nil, at: here)
        }
    }

    /// Library picks go through the same queue and the same rate limit as the
    /// shutter, so bulk importing is not a way around either.
    private func loadPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        pickedItems = []

        if store.isOutOfCaptures {
            Buzz.nope()
            showEarn = true
            return
        }

        importing = true
        Task {
            var picked: [(image: UIImage, coordinate: (lat: Double, lng: Double)?)] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // Where the photo was actually taken, read from its own
                    // metadata. No GPS in the file means no pin on the map.
                    picked.append((image, Exif.coordinate(in: data)))
                }
            }
            importing = false
            guard !picked.isEmpty else { return }

            let accepted = queue.enqueue(picked)
            if accepted > 0 { Buzz.soft() }
        }
    }
}
