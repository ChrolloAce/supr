import MapKit
import SwiftUI

/// Where cars have been caught. A catch only reaches the map once it has been
/// developed, so every pin is a showroom render rather than a raw snapshot.
struct Spot: Identifiable, Equatable {
    let id: String
    let carID: Int
    let coordinate: CLLocationCoordinate2D
    let deviceID: String
    let handle: String
    let city: String
    let date: Date
    let stickerURL: String
    let photoURL: String?
    let mine: Bool

    var car: CarModel { Catalog.car(carID) }

    static func == (a: Spot, b: Spot) -> Bool { a.id == b.id }
}

@MainActor
final class SpotFeed: ObservableObject {
    @Published private(set) var spots: [Spot] = []
    @Published private(set) var loading = false

    func load() async {
        loading = true
        defer { loading = false }

        async let captureRows = Backend.select(
            "revdex_captures",
            query: "select=id,device_id,car_id,city,photo_url,sticker_url,caught_at,lat,lng"
                 + "&lat=not.is.null&sticker_url=not.is.null&order=caught_at.desc&limit=300"
        )
        async let profileRows = Backend.select(
            "revdex_profiles",
            query: "select=device_id,handle&limit=500"
        )
        let (rows, profiles) = await (captureRows, profileRows)

        var handles: [String: String] = [:]
        for row in profiles {
            if let id = row["device_id"] as? String, let handle = row["handle"] as? String {
                handles[id] = handle
            }
        }

        spots = rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let device = row["device_id"] as? String,
                  let carID = row["car_id"] as? Int,
                  Catalog.byID[carID] != nil,
                  let lat = row["lat"] as? Double,
                  let lng = row["lng"] as? Double,
                  let sticker = row["sticker_url"] as? String else { return nil }
            return Spot(
                id: id,
                carID: carID,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                deviceID: device,
                handle: handles[device] ?? "spotter",
                city: (row["city"] as? String ?? "").uppercased(),
                date: Backend.date(row["caught_at"] as? String),
                stickerURL: sticker,
                photoURL: row["photo_url"] as? String,
                mine: device == Backend.deviceID
            )
        }
    }
}

struct SpotMapView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var location: LocationService
    @StateObject private var feed = SpotFeed()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.79, longitude: -80.13),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    @State private var onlyMine = false
    @State private var selected: Spot?

    private var visible: [Spot] {
        onlyMine ? feed.spots.filter(\.mine) : feed.spots
    }

    /// Everything parked within a few metres of this one. Cars pile up outside
    /// the same restaurant, and one pin on top of another hides the rest.
    private func stack(around spot: Spot) -> [Spot] {
        let tolerance = 0.0004   // roughly 40 metres
        return visible.filter {
            abs($0.coordinate.latitude - spot.coordinate.latitude) < tolerance
                && abs($0.coordinate.longitude - spot.coordinate.longitude) < tolerance
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Plain Apple Maps, nothing restyled.
            Map(
                coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: visible
            ) { spot in
                MapAnnotation(coordinate: spot.coordinate) {
                    Button {
                        Buzz.tap()
                        selected = spot
                    } label: {
                        StickerPin(spot: spot, active: selected?.id == spot.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            .ignoresSafeArea()

            controls

            VStack {
                Spacer()
                if let selected {
                    SpotCard(
                        spot: selected,
                        siblings: stack(around: selected),
                        onSwap: { self.selected = $0 },
                        onClose: { self.selected = nil }
                    )
                    .padding(.horizontal, 18)
                    .transition(.opacity)
                } else {
                    statusPill
                }
            }
            .padding(.bottom, Dock.clearance)
        }
        // A plain fade: springing the card made the map lurch behind it.
        .animation(.easeOut(duration: 0.18), value: selected)
        .task {
            await feed.load()
            if let here = location.coordinate {
                region = MKCoordinateRegion(
                    center: here,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            } else if let first = feed.spots.first {
                region = MKCoordinateRegion(
                    center: first.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                )
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Text("Map")
                    .display(24)
                    .foregroundStyle(Ink.text)
                    .shadow(color: Ink.bg.opacity(0.8), radius: 6)

                Spacer()

                Button {
                    Buzz.tap()
                    withAnimation { onlyMine.toggle() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: onlyMine ? "person.fill" : "person.2.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(onlyMine ? "Only mine" : "Everyone")
                            .font(UI.font(12.5, .semibold))
                    }
                    .foregroundStyle(onlyMine ? .white : Ink.text)
                    .padding(.horizontal, 13)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                            .fill(onlyMine ? Ink.accent : Ink.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                            .strokeBorder(onlyMine ? .clear : Ink.line, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                }
                .buttonStyle(.plain)

                IconButton(icon: "location.fill") {
                    guard let here = location.coordinate else { return }
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: here,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                }
            }

        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    /// Centred above the dock so it reads as a status line, not a stray label.
    private var statusPill: some View {
        HStack(spacing: 8) {
            if feed.loading { ProgressView().tint(Ink.faint).scaleEffect(0.65) }
            Text(caption)
                .font(UI.font(12.5, .semibold))
                .foregroundStyle(Ink.dim)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(Capsule().fill(Ink.card.opacity(0.95)))
        .overlay(Capsule().strokeBorder(Ink.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        .transition(.opacity)
    }

    private var caption: String {
        if feed.loading && feed.spots.isEmpty { return "Loading spots" }
        if visible.isEmpty { return "Develop a catch to put it on the map" }
        return "\(visible.count) spot\(visible.count == 1 ? "" : "s")"
    }
}

// MARK: - Pin

/// The render itself is the pin.
struct StickerPin: View {
    let spot: Spot
    var active: Bool

    private var size: CGFloat { active ? 54 : 42 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Ink.card)
                .overlay(
                    Circle().strokeBorder(
                        spot.mine ? Ink.accent : .white.opacity(0.85),
                        lineWidth: active ? 2 : 1.5
                    )
                )

            // The photograph reads better at pin size than the render does:
            // a showroom shot shrunk to 42pt is mostly empty wall.
            RemoteImage(url: spot.photoURL ?? spot.stickerURL, contentMode: .fill) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(spot.car.rarity.color)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
    }
}

// MARK: - Detail card

struct SpotCard: View {
    let spot: Spot
    /// Every catch at this spot, this one included.
    var siblings: [Spot] = []
    var onSwap: ((Spot) -> Void)? = nil
    let onClose: () -> Void

    private var index: Int { siblings.firstIndex(of: spot) ?? 0 }
    private var hasStack: Bool { siblings.count > 1 }

    private func step(_ delta: Int) {
        guard hasStack else { return }
        let next = (index + delta + siblings.count) % siblings.count
        Buzz.tap()
        onSwap?(siblings[next])
    }

    @State private var showOriginal = false
    @State private var openProfile = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                LinearGradient(colors: [Ink.cardAlt, Ink.card], startPoint: .top, endPoint: .bottom)

                if showOriginal, let photo = spot.photoURL {
                    RemoteImage(url: photo, contentMode: .fill) {
                        ProgressView().tint(Ink.faint)
                    }
                } else {
                    RemoteImage(url: spot.stickerURL, contentMode: .fill) {
                        ProgressView().tint(Ink.faint)
                    }
                }
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: R.chip, style: .continuous))
            .overlay(alignment: .bottom) {
                if hasStack {
                    HStack(spacing: 0) {
                        Button { step(-1) } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 34)
                        }
                        Text("\(index + 1) / \(siblings.count)")
                            .font(UI.font(12, .semibold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 46)
                        Button { step(1) } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 34)
                        }
                    }
                    .buttonStyle(.plain)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .padding(.bottom, 9)
                }
            }
            .overlay(alignment: .topTrailing) {
                if spot.photoURL != nil {
                    Button {
                        Buzz.tap()
                        withAnimation(.easeInOut(duration: 0.2)) { showOriginal.toggle() }
                    } label: {
                        Text(showOriginal ? "Render" : "Original")
                            .font(UI.font(11.5, .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(Capsule().fill(.black.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                    .padding(9)
                }
            }

            HStack(spacing: 10) {
                Circle().fill(spot.car.rarity.color).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(spot.car.fullName)
                        .font(UI.font(15, .semibold))
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(spot.car.rarity.title)  ·  \(spot.city)")
                        .font(UI.font(11))
                        .foregroundStyle(Ink.faint)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    Buzz.tap()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Ink.faint)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Ink.line)

            Button {
                Buzz.tap()
                openProfile = true
            } label: {
                HStack(spacing: 11) {
                    Avatar(handle: spot.handle, image: nil, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("@\(spot.handle)")
                            .font(UI.font(13.5, .semibold))
                            .foregroundStyle(Ink.text)
                        Text(spot.date.formatted(.relative(presentation: .numeric)))
                            .font(UI.font(11))
                            .foregroundStyle(Ink.faint)
                    }
                    Spacer(minLength: 0)
                    if spot.mine {
                        Text("YOU")
                            .label(9, .semibold, tracking: 0.5)
                            .foregroundStyle(Ink.accent)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Ink.ghost)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .card()
        .sheet(isPresented: $openProfile) {
            ProfilePage(deviceID: spot.deviceID, asSheet: true)
        }
    }
}
