import SwiftUI
import PhotosUI

struct ProfileRef: Identifiable { let id: String }

struct RivalsView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var community: Community
    @EnvironmentObject private var account: Account

    @State private var section = 0            // 0 feed, 1 crews, 2 board
    @State private var global = true
    @State private var showProfile = false
    @State private var showActivity = false
    @State private var showPaywall = false
    @State private var showCompose = false
    @State private var showCreateCrew = false
    @State private var showChat = false
    @State private var openPost: Post?
    @State private var openProfileID: String?

    var body: some View {
        ZStack {
            Backdrop()

            if account.canUseCommunity {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        header
                        controlRow
                        switch section {
                        case 1: crewsSection
                        case 2: boardSection
                        default: feedSection
                        }
                        Spacer(minLength: Dock.clearance)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)
                .refreshable { await reload() }

                if section == 0 { floatingPostButton }
            } else {
                VStack(spacing: 0) {
                    header.padding(.horizontal, 18)
                    CommunityGate()
                }
                .padding(.bottom, Dock.clearance)
            }
        }
        .task(id: "\(section)-\(global)-\(account.canUseCommunity)") {
            guard account.canUseCommunity else { return }
            await reload()
        }
        .sheet(isPresented: $showProfile) { ProfileView() }
        .sheet(isPresented: $showActivity) { ActivityView() }
        .suprPaywall(.leaderboard, isPresented: $showPaywall, context: .leaderboard)
        .sheet(isPresented: $showCompose) { ComposeView() }
        .sheet(isPresented: $showCreateCrew) { CreateCrewView() }
        .sheet(isPresented: $showChat) { ChatView() }
        .sheet(item: $openPost) { PostDetailView(post: $0) }
        .sheet(item: Binding(
            get: { openProfileID.map(ProfileRef.init) },
            set: { openProfileID = $0?.id }
        )) { ProfilePage(deviceID: $0.id, asSheet: true) }
    }

    private func reload() async {
        switch section {
        case 1: await community.loadCrews(global: global)
        case 2: await community.loadBoard(global: global)
        default: await community.loadFeed(global: global)
        }
    }

    // MARK: Chrome

    private var header: some View {
        ScreenHeader(title: "Community") {
            if account.canUseCommunity {
                IconButton(icon: "bubble.left.and.bubble.right") { showChat = true }
            }
            IconButton(icon: "bell") { showActivity = true }
        }
    }

    private var controlRow: some View {
        HStack(spacing: 9) {
            Segmented(items: ["Feed", "Crews", "Board"], index: $section)
            DropdownPill(text: global ? "Global" : "City") {
                withAnimation(.easeOut(duration: 0.16)) { global.toggle() }
            }
        }
    }

    private func spinner() -> some View {
        HStack {
            Spacer()
            ProgressView().tint(Ink.accent)
            Spacer()
        }
        .padding(.vertical, 40)
    }

    // MARK: Feed

    private var feedSection: some View {
        VStack(spacing: 14) {
            composeBar

            if community.loadingFeed && community.posts.isEmpty {
                spinner()
            } else if community.posts.isEmpty {
                EmptyBlock(
                    icon: "bubble.left",
                    title: global ? "Nothing here yet" : "Nothing in your city",
                    message: global
                        ? "No catches or posts yet. Capture a car or say something to start it off."
                        : "Nobody near you has posted yet. Switch to Global to see everyone."
                )
            } else {
                ForEach(community.posts) { post in
                    PostCard(
                        post: post,
                        onOpen: {
                            Buzz.tap()
                            openPost = post
                        },
                        onOpenProfile: { openProfileID = $0 }
                    )
                }
            }
        }
    }

    /// Sits above the dock so posting is one tap from anywhere in the feed,
    /// however far down it has been scrolled.
    private var floatingPostButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    Buzz.tap()
                    showCompose = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                        Text("Post")
                            .font(UI.font(15, .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 50)
                    .background(Capsule().fill(Ink.accent))
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 18)
            .padding(.bottom, Dock.clearance - 8)
        }
        .allowsHitTesting(true)
    }

    private var composeBar: some View {
        Button {
            Buzz.tap()
            showCompose = true
        } label: {
            HStack(spacing: 12) {
                Avatar(handle: store.profile.handle, image: store.avatarImage, size: 34)
                Text("Say something about a car")
                    .font(UI.font(13.5))
                    .foregroundStyle(Ink.faint)
                Spacer(minLength: 0)
                Image(systemName: "photo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Ink.accent)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Crews

    private var crewsSection: some View {
        VStack(spacing: 14) {
            if let mine = community.myCrew {
                myCrewCard(mine)
            } else {
                Button {
                    Buzz.tap()
                    showCreateCrew = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.accent))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start a crew")
                                .font(UI.font(14, .semibold))
                                .foregroundStyle(Ink.text)
                            Text("Pool your catches with your city")
                                .font(UI.font(11.5))
                                .foregroundStyle(Ink.faint)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 66)
                    .card()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if community.loadingCrews && community.crews.isEmpty {
                spinner()
            } else if community.crews.isEmpty {
                EmptyBlock(
                    icon: "person.3",
                    title: global ? "No crews yet" : "No crews in your city",
                    message: "Nobody has started one. Be the first."
                )
            } else {
                Caption(text: global ? "All crews" : (store.profile.city.isEmpty ? "Your city" : store.profile.city))
                VStack(spacing: 0) {
                    ForEach(Array(community.crews.enumerated()), id: \.element.id) { i, crew in
                        CrewRow(crew: crew) {
                            Buzz.tap()
                            Task {
                                crew.mine ? await community.leaveCrew() : await community.join(crew)
                            }
                        }
                        if i < community.crews.count - 1 {
                            Divider().overlay(Ink.line).padding(.leading, 60)
                        }
                    }
                }
                .card()
            }
        }
    }

    private func myCrewCard(_ crew: Crew) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                CrewMark(tag: crew.tag, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(crew.name)
                        .font(UI.font(16, .semibold))
                        .foregroundStyle(Ink.text)
                    Text("\(crew.city)  ·  \(crew.members) member\(crew.members == 1 ? "" : "s")")
                        .font(UI.font(11.5))
                        .foregroundStyle(Ink.faint)
                }
                Spacer(minLength: 0)
                Text("YOUR CREW")
                    .label(9, .semibold, tracking: 0.6)
                    .foregroundStyle(Ink.accent)
            }

            Divider().overlay(Ink.line)

            HStack {
                Text("\(crew.totalXP.formatted()) XP")
                    .font(UI.font(13, .semibold))
                    .foregroundStyle(Ink.dim)
                Spacer()
                Button("Leave") {
                    Buzz.nope()
                    Task { await community.leaveCrew() }
                }
                .font(UI.font(12.5, .semibold))
                .foregroundStyle(Ink.faint)
            }
        }
        .padding(16)
        .card()
    }

    // MARK: Board

    private var boardSection: some View {
        VStack(spacing: 14) {
            rankCard

            if community.loadingBoard && community.board.isEmpty {
                spinner()
            } else if community.board.isEmpty {
                EmptyBlock(
                    icon: "trophy",
                    title: global ? "Board is empty" : "Nobody in your city",
                    message: "Ranks fill in as spotters start catching cars."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(community.board.enumerated()), id: \.element.id) { index, rival in
                        Button {
                            Buzz.tap()
                            openProfileID = rival.id
                        } label: {
                            RivalRow(rank: index + 1, rival: rival)
                        }
                        .buttonStyle(.plain)
                        if index < community.board.count - 1 {
                            Divider().overlay(Ink.line).padding(.leading, 56)
                        }
                    }
                }
                .card()
            }
        }
    }

    private var rankCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your rank")
                    .font(UI.font(11.5))
                    .foregroundStyle(Ink.faint)
                Text(community.myRank().map { "#\($0)" } ?? "-")
                    .display(28)
                    .foregroundStyle(Ink.text)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(store.profile.xp.formatted()) XP")
                    .font(UI.font(13, .semibold))
                    .foregroundStyle(Ink.dim)
                Text(global ? "GLOBAL" : (store.profile.city.isEmpty ? "NO CITY" : store.profile.city))
                    .label(9, .semibold, tracking: 0.6)
                    .foregroundStyle(Ink.faint)
            }
        }
        .padding(16)
        .card()
    }
}

// MARK: - Feed card

struct PostCard: View {
    let post: Post
    /// Tapping anywhere that is not the like button opens the post.
    var onOpen: (() -> Void)? = nil
    /// Tapping the person opens their profile instead of the post.
    var onOpenProfile: ((String) -> Void)? = nil

    @EnvironmentObject private var community: Community
    @State private var image: UIImage?
    @State private var reporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Button {
                    Buzz.tap()
                    onOpenProfile?(post.deviceID)
                } label: {
                    HStack(spacing: 11) {
                        Avatar(handle: post.handle, image: nil, size: 34, url: post.avatarURL)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text("@\(post.handle)")
                                    .font(UI.font(13.5, .semibold))
                                    .foregroundStyle(Ink.text)
                                    .lineLimit(1)
                                if post.mine {
                                    Text("YOU")
                                        .label(8, .semibold, tracking: 0.4)
                                        .foregroundStyle(Ink.accent)
                                }
                            }
                            Text(subtitle)
                                .font(UI.font(11))
                                .foregroundStyle(Ink.faint)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if !post.mine {
                    Button {
                        Buzz.tap()
                        reporting = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Ink.ghost)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if !post.text.isEmpty {
                Text(post.text)
                    .font(UI.font(14))
                    .foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }

            if post.imageURL != nil {
                ZStack {
                    Ink.cardAlt
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(post.isCatch ? 12 : 0)
                    } else {
                        ProgressView().tint(Ink.faint)
                    }
                }
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipped()
            }

            if let car = post.car {
                HStack(spacing: 10) {
                    Circle().fill(car.rarity.color).frame(width: 8, height: 8)
                    Text(car.fullName)
                        .font(UI.font(13, .semibold))
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                    Text(car.rarity.title)
                        .label(9, .semibold, tracking: 0.6)
                        .foregroundStyle(car.rarity.color)
                    Spacer(minLength: 0)
                    Text(car.dexNumber)
                        .font(UI.font(12, .semibold))
                        .foregroundStyle(Ink.faint)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Ink.cardAlt)
            }

            HStack(spacing: 6) {
                Button {
                    Buzz.soft()
                    Task { await community.toggleLike(post) }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: post.likedByMe ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .semibold))
                            .scaleEffect(post.likedByMe ? 1.15 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: post.likedByMe)
                        Text("\(post.likes)")
                            .font(UI.font(13, .semibold))
                    }
                    .foregroundStyle(post.likedByMe ? Ink.accent : Ink.faint)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    onOpen?()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Comment")
                            .font(UI.font(13, .semibold))
                    }
                    .foregroundStyle(Ink.faint)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if post.mine && !post.isCatch {
                    Button {
                        Buzz.nope()
                        Task { await community.deletePost(post) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Ink.ghost)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 46)
        }
        .card()
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .confirmationDialog("Report this post", isPresented: $reporting, titleVisibility: .visible) {
            ForEach(Self.reasons, id: \.self) { reason in
                Button(reason, role: reason == "Something else" ? nil : .destructive) {
                    Task { await community.report(post, reason: reason) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("We will look at it. The post is hidden for you straight away.")
        }
        .task(id: post.imageURL) {
            guard let url = post.imageURL, image == nil else { return }
            image = await Backend.download(url)
        }
    }

    private static let reasons = [
        "Not a car",
        "Readable number plate",
        "Somebody's home or address",
        "Harassment or abuse",
        "Not their photo",
        "Something else"
    ]

    private var subtitle: String {
        let when = post.date.formatted(.relative(presentation: .numeric))
        return post.city.isEmpty ? when : "\(post.city)  ·  \(when)"
    }
}

// MARK: - Crew rows

struct CrewRow: View {
    let crew: Crew
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CrewMark(tag: crew.tag, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(crew.name)
                    .font(UI.font(14, .semibold))
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                Text("\(crew.city)  ·  \(crew.members)")
                    .font(UI.font(11))
                    .foregroundStyle(Ink.faint)
            }

            Spacer(minLength: 4)

            Text(compact(crew.totalXP))
                .font(UI.font(12.5, .semibold))
                .foregroundStyle(Ink.dim)

            Button(action: onToggle) {
                Text(crew.mine ? "Leave" : "Join")
                    .label(10, .semibold, tracking: 0.4)
                    .foregroundStyle(crew.mine ? Ink.faint : .white)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                            .fill(crew.mine ? Ink.cardAlt : Ink.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
    }

    private func compact(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return "\(n / 1000)K" }
        return "\(n)"
    }
}

struct CrewMark: View {
    let tag: String
    var size: CGFloat = 36

    var body: some View {
        Text(String(tag.prefix(3)))
            .font(Disp.font(size * 0.38, .black))
            .foregroundStyle(Ink.text)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.cardAlt))
            .overlay(
                RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                    .strokeBorder(Ink.line, lineWidth: 1)
            )
    }
}

struct Avatar: View {
    let handle: String
    let image: UIImage?
    var size: CGFloat = 34
    /// A picture on the server, used everywhere the local one is not to hand.
    var url: String? = nil

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url {
                RemoteImage(url: url, contentMode: .fill) {
                    ZStack {
                        Ink.cardAlt
                        Text(String((handle.isEmpty ? "?" : handle).prefix(1)).uppercased())
                            .font(UI.font(size * 0.42, .semibold))
                            .foregroundStyle(Ink.dim)
                    }
                }
            } else {
                Ink.cardAlt
                Text(String((handle.isEmpty ? "?" : handle).prefix(1)).uppercased())
                    .font(UI.font(size * 0.42, .semibold))
                    .foregroundStyle(Ink.dim)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Ink.line, lineWidth: 1))
    }
}

// MARK: - Board row

struct RivalRow: View {
    let rank: Int
    let rival: Rival

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(UI.font(13, .semibold))
                .foregroundStyle(rank <= 3 ? Ink.accent : Ink.faint)
                .frame(width: 26, alignment: .leading)

            Avatar(handle: rival.handle, image: nil, size: 32, url: rival.avatarURL)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("@\(rival.handle)")
                        .font(UI.font(13.5, .semibold))
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                    if rival.isMe {
                        Text("YOU")
                            .label(8, .semibold, tracking: 0.4)
                            .foregroundStyle(Ink.accent)
                    } else if rival.isPro {
                        Text("PRO")
                            .label(8, .semibold, tracking: 0.4)
                            .foregroundStyle(Ink.faint)
                    }
                }
                Text(rival.city.isEmpty ? rival.rankName : rival.city)
                    .font(UI.font(11))
                    .foregroundStyle(Ink.faint)
            }

            Spacer(minLength: 4)

            Text(rival.xp.formatted())
                .font(UI.font(13, .semibold))
                .foregroundStyle(Ink.dim)
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
    }
}

// MARK: - Compose

struct ComposeView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var community: Community
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var carID: Int?
    @State private var pickingFromGarage = false
    @FocusState private var focused: Bool

    /// A post is a picture of a car. Everything else is optional.
    private var canPost: Bool { image != nil && !community.posting }
    private var remaining: Int { Community.captionLimit - text.count }

    private var garage: [Capture] { store.uniqueGarage }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "New post") { dismiss() }

                ScrollView {
                    VStack(spacing: 14) {
                        photoWell
                        sourceButtons
                        caption
                        if !garage.isEmpty { tagRow }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)

                // Always on screen, so the action is never scrolled away.
                Button {
                    Buzz.tap()
                    Task {
                        await community.addPost(
                            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                            image: image,
                            carID: carID
                        )
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if community.posting { ProgressView().tint(.white).scaleEffect(0.7) }
                        Text(community.posting ? "Posting" : "Post")
                    }
                }
                .buttonStyle(.primary)
                .disabled(!canPost)
                .opacity(canPost ? 1 : 0.4)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
        .sheet(isPresented: $pickingFromGarage) {
            GaragePicker { capture in
                image = store.displayImage(for: capture)
                carID = capture.carID
            }
        }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    image = UIImage(data: data)
                }
                pickerItem = nil
            }
        }
    }

    private var photoWell: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        Button {
                            Buzz.tap()
                            self.image = nil
                            carID = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(.black.opacity(0.55)))
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(Ink.raised)
                    Text("Add a photo of a car")
                        .font(UI.font(13.5))
                        .foregroundStyle(Ink.faint)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 260)
            }
        }
        .background(Ink.cardAlt)
        .clipShape(RoundedRectangle(cornerRadius: R.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.card, style: .continuous)
                .strokeBorder(Ink.line, lineWidth: 1)
        )
    }

    private var sourceButtons: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                sourceChip(icon: "photo", title: "Library")
            }

            Button {
                Buzz.tap()
                pickingFromGarage = true
            } label: {
                sourceChip(icon: "square.grid.2x2.fill", title: "From garage")
            }
            .buttonStyle(.plain)
            .disabled(garage.isEmpty)
            .opacity(garage.isEmpty ? 0.4 : 1)
        }
    }

    private func sourceChip(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(UI.font(13.5, .semibold))
        }
        .foregroundStyle(Ink.text)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .card()
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(
                    "",
                    text: $text,
                    prompt: Text("Say something short").foregroundColor(Ink.faint)
                )
                .font(UI.font(15))
                .foregroundStyle(Ink.text)
                .focused($focused)
                .onChange(of: text) { new in
                    if new.count > Community.captionLimit {
                        text = String(new.prefix(Community.captionLimit))
                    }
                }

                Text("\(remaining)")
                    .font(UI.font(12, .semibold))
                    .foregroundStyle(remaining <= 5 ? Ink.accent : Ink.ghost)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .card()
        }
    }

    private var tagRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "Tag a car")
            FlowLayout(spacing: 8) {
                ForEach(garage, id: \.id) { capture in
                    let car = capture.car
                    let on = carID == car.id
                    Button {
                        Buzz.tap()
                        carID = on ? nil : car.id
                    } label: {
                        Text(car.model)
                            .font(UI.font(12.5, .semibold))
                            .foregroundStyle(on ? .white : Ink.dim)
                            .lineLimit(1)
                            .padding(.horizontal, 13)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                                    .fill(on ? Ink.accent : Ink.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                                    .strokeBorder(on ? .clear : Ink.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Pulls a shot straight out of the garage, so posting a catch does not mean
/// hunting for it again in the camera roll.
struct GaragePicker: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let onPick: (Capture) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "From your garage") { dismiss() }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.garage) { capture in
                            Button {
                                Buzz.tap()
                                onPick(capture)
                                dismiss()
                            } label: {
                                VStack(spacing: 0) {
                                    ZStack {
                                        LinearGradient(colors: [Ink.cardAlt, Ink.card],
                                                       startPoint: .top, endPoint: .bottom)
                                        if let image = store.displayImage(for: capture) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .padding(8)
                                        } else {
                                            Image(systemName: "car.side.fill")
                                                .font(.system(size: 26))
                                                .foregroundStyle(Ink.raised)
                                        }
                                    }
                                    .frame(height: 118)

                                    Text(capture.car.fullName)
                                        .font(UI.font(12, .semibold))
                                        .foregroundStyle(Ink.text)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 9)
                                }
                                .card(Ink.card, radius: R.tile)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                    Spacer(minLength: 30)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

// MARK: - Create crew

struct CreateCrewView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var community: Community
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var tag = ""
    @State private var city = ""
    @State private var creating = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && tag.count >= 2
    }

    /// Typed city wins, otherwise wherever the founder is.
    private var place: String {
        city.trimmingCharacters(in: .whitespaces).isEmpty ? store.profile.city : city
    }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Start a crew") { dismiss() }

                ScrollView {
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            // Tap the mark to give the crew a picture.
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                ZStack {
                                    if let image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 54, height: 54)
                                            .clipShape(RoundedRectangle(cornerRadius: R.chip, style: .continuous))
                                    } else {
                                        CrewMark(tag: tag.isEmpty ? "???" : tag, size: 54)
                                    }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Circle().fill(Ink.accent))
                                        .offset(x: 4, y: 4)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name.isEmpty ? "Your crew" : name)
                                    .font(UI.font(16, .semibold))
                                    .foregroundStyle(name.isEmpty ? Ink.faint : Ink.text)
                                    .lineLimit(1)
                                Text(place.isEmpty ? "City" : place.uppercased())
                                    .font(UI.font(11.5))
                                    .foregroundStyle(Ink.faint)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .card()

                        field("Name", text: $name, placeholder: "Night Shift")
                        field("Tag", text: $tag, placeholder: "NGT")
                        field("City", text: $city, placeholder: store.profile.city.isEmpty ? "Your city" : store.profile.city)

                        if city.isEmpty && !store.profile.city.isEmpty {
                            Text("Set to \(store.profile.city.capitalized) from your location. Change it above if the crew belongs somewhere else.")
                                .font(UI.font(11.5))
                                .foregroundStyle(Ink.faint)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Buzz.tap()
                            creating = true
                            Task {
                                await community.createCrew(
                                    name: name.trimmingCharacters(in: .whitespaces),
                                    tag: tag,
                                    city: place,
                                    image: image
                                )
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if creating { ProgressView().tint(.white).scaleEffect(0.7) }
                                Text(creating ? "Creating" : "Create crew")
                            }
                        }
                        .buttonStyle(.primary)
                        .disabled(!valid || creating)
                        .opacity(valid && !creating ? 1 : 0.4)
                        .padding(.top, 4)

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear { city = store.profile.city }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    image = UIImage(data: data)
                }
                pickerItem = nil
            }
        }
    }

    private func field(_ caption: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(caption)
                .font(UI.font(12.5))
                .foregroundStyle(Ink.faint)
                .frame(width: 48, alignment: .leading)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(Ink.ghost))
                .font(UI.font(15, .semibold))
                .foregroundStyle(Ink.text)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .card()
    }
}
