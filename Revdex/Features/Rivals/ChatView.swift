import SwiftUI

/// Shared room where spotters talk. Backed by the same database as everything
/// else, polled while the screen is open.
@MainActor
final class Chat: ObservableObject {

    struct Message: Identifiable, Equatable {
        let id: String
        let deviceID: String
        let handle: String
        let body: String
        let date: Date
        let mine: Bool
        var avatarURL: String?
    }

    @Published private(set) var messages: [Message] = []
    @Published private(set) var loading = false
    @Published var room = "global"

    private var poller: Task<Void, Never>?

    func start(room: String) {
        self.room = room
        poller?.cancel()
        poller = Task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    func stop() {
        poller?.cancel()
        poller = nil
    }

    func load() async {
        if messages.isEmpty { loading = true }
        defer { loading = false }

        async let messageRows = Backend.select(
            "revdex_messages",
            query: "room=eq.\(room)&order=created_at.desc&limit=80"
        )
        async let profileRows = Backend.select(
            "revdex_profiles",
            query: "select=device_id,handle,avatar_url&limit=500"
        )
        let (rows, profiles) = await (messageRows, profileRows)

        var handles: [String: String] = [:]
        var avatars: [String: String] = [:]
        for row in profiles {
            guard let id = row["device_id"] as? String else { continue }
            if let handle = row["handle"] as? String { handles[id] = handle }
            if let avatar = row["avatar_url"] as? String { avatars[id] = avatar }
        }

        let mapped: [Message] = rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let body = row["body"] as? String else { return nil }
            let device = row["device_id"] as? String ?? ""
            return Message(
                id: id,
                deviceID: device,
                // Live handle first, so a rename applies to old messages too.
                handle: handles[device] ?? row["handle"] as? String ?? "spotter",
                body: body,
                date: Backend.date(row["created_at"] as? String),
                mine: device == Backend.deviceID,
                avatarURL: avatars[device]
            )
        }
        .reversed()

        if mapped != messages { messages = mapped }
    }

    func send(_ text: String, handle: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Show it straight away, then reconcile on the next poll.
        messages.append(
            Message(
                id: UUID().uuidString,
                deviceID: Backend.deviceID,
                handle: handle,
                body: trimmed,
                date: Date(),
                mine: true
            )
        )

        await Backend.insert("revdex_messages", [[
            "room": room,
            "device_id": Backend.deviceID,
            "handle": handle,
            "body": trimmed
        ]])
        await load()
    }
}

struct ChatView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var account: Account
    @StateObject private var chat = Chat()
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @State private var scope = 0
    @State private var openProfile: String?
    @FocusState private var focused: Bool

    private struct Spotter: Identifiable { let id: String }

    private var handle: String {
        store.profile.handle.isEmpty ? "spotter" : store.profile.handle.lowercased()
    }
    private var room: String {
        scope == 0 ? "global" : (store.profile.city.isEmpty ? "global" : store.profile.city.lowercased())
    }

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Chat") { dismiss() }

                if account.canUseCommunity {
                    Segmented(items: ["Global", store.profile.city.isEmpty ? "City" : store.profile.city], index: $scope)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                } else {
                    CommunityGate().padding(.horizontal, 18)
                    Spacer()
                }

                if !account.canUseCommunity {
                    EmptyView()
                } else if chat.loading && chat.messages.isEmpty {
                    Spacer()
                    ProgressView().tint(Ink.accent)
                    Spacer()
                } else if chat.messages.isEmpty {
                    Spacer()
                    EmptyBlock(
                        icon: "bubble.left.and.bubble.right",
                        title: "Nobody has said anything",
                        message: "Be the first to post in this room."
                    )
                    .padding(.horizontal, 18)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(chat.messages) { message in
                                    bubble(message).id(message.id)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 6)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: chat.messages.count) { _ in
                            if let last = chat.messages.last {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                if account.canUseCommunity { composer }
            }
        }
        .task(id: "\(room)-\(account.canUseCommunity)") {
            guard account.canUseCommunity else { return }
            chat.start(room: room)
        }
        .onDisappear { chat.stop() }
        .sheet(item: Binding(
            get: { openProfile.map(Spotter.init) },
            set: { openProfile = $0?.id }
        )) { ProfilePage(deviceID: $0.id, asSheet: true) }
    }

    private func bubble(_ message: Chat.Message) -> some View {
        HStack(alignment: .bottom, spacing: 9) {
            if message.mine { Spacer(minLength: 40) }

            if !message.mine {
                Button {
                    Buzz.tap()
                    openProfile = message.deviceID
                } label: {
                    Avatar(handle: message.handle, image: nil, size: 28, url: message.avatarURL)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: message.mine ? .trailing : .leading, spacing: 3) {
                if !message.mine {
                    Button {
                        Buzz.tap()
                        openProfile = message.deviceID
                    } label: {
                        Text("@\(message.handle)")
                            .font(UI.font(11, .semibold))
                            .foregroundStyle(Ink.faint)
                    }
                    .buttonStyle(.plain)
                }
                Text(message.body)
                    .font(UI.font(14))
                    .foregroundStyle(message.mine ? .white : Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(message.mine ? Ink.accent : Ink.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(message.mine ? .clear : Ink.line, lineWidth: 1)
                    )
            }

            if !message.mine { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("", text: $draft, prompt: Text("Message").foregroundColor(Ink.faint), axis: .vertical)
                .font(UI.font(14))
                .foregroundStyle(Ink.text)
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Ink.card))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Ink.line, lineWidth: 1)
                )

            Button {
                Buzz.tap()
                let text = draft
                draft = ""
                Task { await chat.send(text, handle: handle) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Ink.accent))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
