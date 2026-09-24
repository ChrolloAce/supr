import SwiftUI
import UIKit

/// A rendered card on its way to the share sheet, with the line that goes
/// alongside it.
struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
    var caption: String = ""

    static func caption(for capture: Capture) -> String {
        let place = capture.city.trimmingCharacters(in: .whitespaces)
        let where_ = place.isEmpty || place.uppercased() == "UNKNOWN"
            ? ""
            : " at \(place.capitalized)"
        return "look what i caught, \(capture.car.fullName)\(where_), in SUPR"
    }
}

/// The system share sheet. ShareLink cannot carry a UIImage rendered on the
/// spot, so this wraps the activity controller directly.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Full screen look at a catch. Opens from the detail hero, switches between
/// the render and the shot it came from, and zooms.
struct CaptureViewer: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    let capture: Capture
    /// Which one it opens on, kept in step with the detail sheet behind it.
    @Binding var showOriginal: Bool

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private var car: CarModel { capture.car }
    private var render: UIImage? { store.developedImage(for: capture) }
    private var photo: UIImage? { store.image(for: capture) }
    private var canSwitch: Bool { render != nil && photo != nil }

    private var current: UIImage? { showOriginal ? photo : (render ?? photo) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = current {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .id(showOriginal)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.18), value: showOriginal)
                    .scaleEffect(zoom)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { zoom = min(6, max(1, lastZoom * $0)) }
                                .onEnded { _ in
                                    lastZoom = zoom
                                    if zoom <= 1 { reset() }
                                },
                            DragGesture()
                                .onChanged { value in
                                    guard zoom > 1 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                    )
                    .onTapGesture(count: 2) {
                        Buzz.soft()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if zoom > 1 { reset() } else { zoom = 2.5; lastZoom = 2.5 }
                        }
                    }
            } else {
                CarPlate(car: car, glyphWidth: 240)
            }

            VStack {
                topBar
                Spacer()
                if canSwitch { modeSwitch.padding(.bottom, 22) }
            }
        }
        .statusBarHidden()
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(car.fullName)
                    .font(UI.font(15, .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(capture.city)  ·  \(capture.date.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(UI.font(11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let image = current {
                ShareLink(item: Image(uiImage: image), preview: SharePreview(car.fullName, image: Image(uiImage: image))) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.white.opacity(0.14)))
                }
            }

            Button {
                Buzz.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            mode("Render", on: !showOriginal) { showOriginal = false }
            mode("Original", on: showOriginal) { showOriginal = true }
        }
        .padding(4)
        .background(Capsule().fill(.white.opacity(0.12)))
    }

    private func mode(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Buzz.soft()
            // No animation around the swap itself: animating it makes SwiftUI
            // morph one photograph into the other, which warps the car. The
            // crossfade lives on the image view instead.
            reset()
            action()
        } label: {
            Text(title)
                .font(UI.font(13, .semibold))
                .foregroundStyle(on ? Ink.bg : .white)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(Capsule().fill(on ? Color.white : .clear))
        }
        .buttonStyle(.plain)
    }

    private func reset() {
        zoom = 1
        lastZoom = 1
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Share card

/// What gets shared: the catch on a REVDEX plate rather than a bare photo, so
/// it carries the model, the rarity and where it was found.
struct ShareCard: View {
    let capture: Capture
    let image: UIImage?

    private var car: CarModel { capture.car }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [Ink.cardAlt, Ink.bg], startPoint: .top, endPoint: .bottom)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 900, height: 700)
                        .clipped()
                } else {
                    CarPlate(car: car, glyphWidth: 300)
                }
            }
            .frame(width: 900, height: 700)

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(car.make.uppercased())
                        .font(UI.font(22, .semibold))
                        .tracking(3)
                        .foregroundStyle(Ink.faint)
                    Text(car.model)
                        .font(Disp.font(58, .black))
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    HStack(spacing: 10) {
                        RarityBar(rarity: car.rarity, segment: CGSize(width: 22, height: 9), onDark: false)
                        Text(car.rarity.title.uppercased())
                            .font(UI.font(20, .semibold))
                            .tracking(2)
                            .foregroundStyle(car.rarity.color)
                        Text("·")
                            .foregroundStyle(Ink.ghost)
                        Text(capture.city.isEmpty ? "SPOTTED" : capture.city.uppercased())
                            .font(UI.font(20, .semibold))
                            .tracking(2)
                            .foregroundStyle(Ink.faint)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    RevMark(size: 34)
                    Text("SUPR")
                        .font(Disp.font(20, .black))
                        .tracking(4)
                        .foregroundStyle(Ink.dim)
                }
            }
            .padding(.horizontal, 44)
            .frame(width: 900, height: 260)
            .background(Ink.card)
        }
        .frame(width: 900, height: 960)
        .background(Ink.bg)
    }
}

extension ShareCard {
    /// Flattened at 2x so it lands in Messages and Instagram at a usable size.
    @MainActor
    static func render(capture: Capture, image: UIImage?) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCard(capture: capture, image: image))
        renderer.scale = 2
        return renderer.uiImage
    }
}
