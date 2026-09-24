import SwiftUI
import PhotosUI

/// One profile page, used for you and for everyone else. Passing nil means you,
/// which unlocks editing; any other device id is read only plus a follow button.
struct ProfilePage: View {
    var deviceID: String? = nil
    var asSheet: Bool = false

    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var sync: Sync
    @EnvironmentObject private var account: Account
    @Environment(\.dismiss) private var dismiss
    @StateObject private var people = People()

    /// 0 garage, 1 posts. Your own profile is posts only, so it starts there.
    @State private var tab = 0
    @State private var showRanks = false
    @State private var showFavourite = false
    @State private var showSettings = false
    @State private var showBadges = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var editingName = false
    @State private var nameDraft = ""
    @State private var openPost: Post?
    @State private var openProfile: String?

    private var isMe: Bool { deviceID == nil || deviceID == Backend.deviceID }
    private var targetID: String { deviceID ?? Backend.deviceID }

    var body: some View {
        ZStack {
            Backdrop()

            ScrollView {
                LazyVStack(spacing: 16) {
                    if asSheet {
                        SheetHeader(title: isMe ? "Profile" : "Spotter") { dismiss() }
                            .padding(.horizontal, -18)
                    } else {
                        header
                    }

                    identityCard
                    if isMe || account.canUseCommunity {
                        statsRow
                        if isMe {
                            favouriteRow
                            badgeRow
                        } else {
                            followButton
                        }
                        tabs
                        content
                    } else {
                        CommunityGate().frame(minHeight: 380)
                    }
                    Spacer(minLength: asSheet ? 30 : Dock.clearance)
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
            .refreshable { await people.load(deviceID: targetID) }
        }
        .task(id: targetID) {
            if isMe { tab = 1 }
            #if DEBUG
            // `badges` on the scheme opens the grid straight away, so store
            // screenshots don't depend on a tap landing in the right place.
            if isMe, ProcessInfo.processInfo.arguments.contains("badges") { showBadges = true }
            #endif
            await people.load(deviceID: targetID)
        }
        .sheet(isPresented: $showRanks) { RankLadderView() }
        .sheet(isPresented: $showFavourite) { FavouriteCarPicker() }
        .sheet(isPresented: $showSettings) { ProfileView() }
        .sheet(isPresented: $showBadges) { AchievementsView() }
        .sheet(item: $openPost) { PostDetailView(post: $0) }
        .sheet(item: Binding(
            get: { openProfile.map(IdentifiedID.init) },
            set: { openProfile = $0?.id }
        )) { wrapped in
            ProfilePage(deviceID: wrapped.id, asSheet: true)
        }
        .onChange(of: avatarItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    store.setAvatar(image)
                    await sync.pushProfile()
                    await people.load(deviceID: targetID)
                }
                avatarItem = nil
            }
        }
    }

    private struct IdentifiedID: Identifiable { let id: String }

    // MARK: Header

    private var header: some View {
        ScreenHeader(title: "Profile") {
            if isMe {
                IconButton(icon: "gearshape") { showSettings = true }
            }
        }
    }

    // MARK: Identity

    private var identityCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                avatar

                VStack(alignment: .leading, spacing: 6) {
                    nameBlock

                    Text("@\(people.person?.handle ?? (isMe ? currentHandle : "spotter"))")
                        .font(UI.font(13))
                        .foregroundStyle(Ink.faint)

                    if let city = people.person?.city, !city.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10, weight: .semibold))
                            Text(city)
                                .font(UI.font(11.5))
                        }
                        .foregroundStyle(Ink.ghost)
                    }
                }

                Spacer(minLength: 0)
            }

            // Badge and level, tappable to browse the whole ladder.
            Button {
                Buzz.tap()
                if isMe { showRanks = true }
            } label: {
                HStack(spacing: 13) {
                    RankBadge(rank: displayRank, size: 46)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("LV \(displayLevel)")
                            .display(22)
                            .foregroundStyle(Ink.text)
                        Text(people.person?.rankName ?? store.profile.rankName)
                            .font(UI.font(12, .semibold))
                            .foregroundStyle(displayRank.tier.color)
                    }

                    Spacer(minLength: 0)

                    if isMe {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Ink.faint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isMe {
                XPBar(progress: Levels.progress(xp: store.profile.xp).fraction)
            }
        }
        .padding(16)
        .card()
    }

    private var avatar: some View {
        Group {
            if isMe {
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    avatarImage.overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Ink.accent))
                            .overlay(Circle().strokeBorder(Ink.bg, lineWidth: 2))
                            .offset(x: 3, y: 3)
                    }
                }
            } else {
                avatarImage
            }
        }
    }

    private var avatarImage: some View {
        ZStack {
            if isMe, let local = store.avatarImage {
                Image(uiImage: local).resizable().scaledToFill()
            } else if let url = people.person?.avatarURL {
                RemoteImage(url: url, contentMode: .fill) {
                    ZStack { Ink.cardAlt; initial }
                }
            } else {
                ZStack { Ink.cardAlt; initial }
            }
        }
        .frame(width: 78, height: 78)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Ink.line, lineWidth: 1))
    }

    private var initial: some View {
        Text(String((people.person?.name ?? "S").dropFirst(0).prefix(1)).uppercased())
            .font(UI.font(30, .semibold))
            .foregroundStyle(Ink.dim)
    }

    @ViewBuilder
    private var nameBlock: some View {
        if isMe && editingName {
            HStack(spacing: 8) {
                TextField("", text: $nameDraft, prompt: Text("Display name").foregroundColor(Ink.ghost))
                    .font(UI.font(19, .semibold))
                    .foregroundStyle(Ink.text)
                    .autocorrectionDisabled()
                Button("Save") {
                    Buzz.tap()
                    store.updateDisplayName(nameDraft)
                    editingName = false
                    Task {
                        await sync.pushProfile()
                        await people.load(deviceID: targetID)
                    }
                }
                .font(UI.font(12.5, .semibold))
                .foregroundStyle(Ink.accent)
            }
        } else {
            Button {
                guard isMe else { return }
                Buzz.tap()
                nameDraft = store.profile.displayName
                editingName = true
            } label: {
                HStack(spacing: 7) {
                    Text(displayName)
                        .display(24)
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if isMe {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Ink.faint)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var displayName: String {
        if isMe {
            let name = store.profile.displayName
            return name.isEmpty ? (store.profile.handle.isEmpty ? "Spotter" : store.profile.handle) : name
        }
        return people.person?.name ?? "Spotter"
    }

    private var currentHandle: String {
        store.profile.handle.isEmpty ? "spotter" : store.profile.handle.lowercased()
    }

    private var displayLevel: Int { isMe ? store.profile.level : (people.person?.level ?? 1) }
    private var displayRank: Rank { isMe ? store.profile.rank : (people.person?.rank ?? Ranks.all[0]) }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat("\(people.catches.count)", "Spotted")
            divider
            stat("\(people.followers)", "Followers")
            divider
            stat("\(people.following)", "Following")
        }
        .padding(.vertical, 15)
        .card()
    }

    private var divider: some View {
        Rectangle().fill(Ink.line).frame(width: 1, height: 34)
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .display(22)
                .foregroundStyle(Ink.text)
            Text(caption)
                .font(UI.font(11.5))
                .foregroundStyle(Ink.faint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private var followButton: some View {
        Button {
            Buzz.tap()
            Task { await people.toggleFollow(targetID) }
        } label: {
            Text(people.iFollow ? "Following" : "Follow")
        }
        .buttonStyle(people.iFollow ? .accent : .primary)
    }

    private var favouriteRow: some View {
        Button {
            Buzz.tap()
            showFavourite = true
        } label: {
            HStack(spacing: 13) {
                if let car = store.favouriteCar {
                    ZStack {
                        Ink.cardAlt
                        RemoteImage(url: stickerURL(for: car.id)) {
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(car.rarity.color)
                        }
                        .padding(5)
                    }
                    .frame(width: 54, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: R.chip, style: .continuous))
                } else {
                    Image(systemName: "star")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.accent)
                        .frame(width: 54, height: 44)
                        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.cardAlt))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Signature car")
                        .font(UI.font(11.5))
                        .foregroundStyle(Ink.faint)
                    Text(store.favouriteCar?.fullName ?? "Pick one you have spotted")
                        .font(UI.font(14, .semibold))
                        .foregroundStyle(store.favouriteCar == nil ? Ink.faint : Ink.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Ink.faint)
            }
            .padding(13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
    }

    /// The three most recent badges, and a way into the rest.
    private var badgeRow: some View {
        let recent = store.unlocked
            .sorted { $0.value > $1.value }
            .compactMap { Achievements.achievement($0.key) }

        return Button {
            Buzz.tap()
            showBadges = true
        } label: {
            HStack(spacing: 12) {
                if recent.isEmpty {
                    Image(systemName: "rosette")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.accent)
                        .frame(width: 54, height: 44)
                        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.cardAlt))
                } else {
                    // Sized to what three overlapped badges actually occupy, so
                    // the stack cannot run over the label beside it.
                    HStack(spacing: -9) {
                        ForEach(recent.prefix(3)) { badge in
                            AchievementBadge(achievement: badge, size: 32)
                                .background(Circle().fill(Ink.card))
                        }
                    }
                    .frame(width: 68, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Badges")
                        .font(UI.font(11.5))
                        .foregroundStyle(Ink.faint)
                    Text(recent.isEmpty
                         ? "Nothing earned yet"
                         : "\(store.unlocked.count) of \(Achievements.all.count) earned")
                        .font(UI.font(14, .semibold))
                        .foregroundStyle(recent.isEmpty ? Ink.faint : Ink.text)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Ink.faint)
            }
            .padding(13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
    }

    private func stickerURL(for carID: Int) -> String? {
        people.catches.first { $0.carID == carID }?.stickerURL
    }

    // MARK: Tabs

    /// Your own garage already is the main screen, so your profile only shows
    /// posts. Somebody else's profile still needs both, because their
    /// collection is the reason you opened it.
    @ViewBuilder
    private var tabs: some View {
        if !isMe {
            Segmented(items: ["Garage", "Posts"], index: $tab)
        } else {
            Caption(text: "Posts", trailing: "\(people.posts.count)")
        }
    }

    @ViewBuilder
    private var content: some View {
        if people.loading && people.catches.isEmpty && people.posts.isEmpty {
            ProgressView().tint(Ink.accent).padding(.vertical, 40)
        } else if tab == 0 && !isMe {
            if people.catches.isEmpty {
                EmptyBlock(
                    icon: "car.side",
                    title: isMe ? "Nothing caught yet" : "Nothing here yet",
                    message: isMe ? "Your catches will show up here." : "This spotter has not caught anything."
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(people.catches) { item in
                        CatchTile(item: item)
                    }
                }
            }
        } else {
            if people.posts.isEmpty {
                EmptyBlock(
                    icon: "bubble.left",
                    title: "No posts",
                    message: isMe ? "Anything you post shows up here." : "This spotter has not posted."
                )
            } else {
                ForEach(people.posts) { post in
                    PostCard(post: post) {
                        Buzz.tap()
                        openPost = post
                    }
                }
            }
        }
    }
}

// MARK: - Grid tile

struct CatchTile: View {
    let item: People.Catch

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [Ink.cardAlt, Ink.card], startPoint: .top, endPoint: .bottom)
                RemoteImage(url: item.stickerURL ?? item.photoURL, contentMode: item.stickerURL != nil ? .fit : .fill) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Ink.raised)
                }
                .padding(item.stickerURL != nil ? 10 : 0)
            }
            .frame(height: 130)
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Circle().fill(item.car.rarity.color).frame(width: 6, height: 6)
                    Text(item.car.make)
                        .font(UI.font(9.5, .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Ink.faint)
                        .lineLimit(1)
                }
                Text(item.car.model)
                    .display(17)
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
        }
        .card(Ink.card, radius: R.tile)
    }
}
