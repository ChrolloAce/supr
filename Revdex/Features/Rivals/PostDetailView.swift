import SwiftUI

/// A post opened up: the picture full width, then likes and the comment thread.
struct PostDetailView: View {
    let post: Post

    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var community: Community
    @Environment(\.dismiss) private var dismiss
    @StateObject private var thread = Thread()

    @State private var image: UIImage?
    @State private var draft = ""
    @State private var replyingTo: Thread.Comment?
    @State private var reporting = false
    @State private var reported = false
    @FocusState private var focused: Bool

    private var handle: String {
        store.profile.handle.isEmpty ? "spotter" : store.profile.handle.lowercased()
    }

    /// Live from the feed list, so liking here updates the card behind this sheet.
    private var likeCount: Int { community.likeState(for: post.id)?.likes ?? post.likes }
    private var liked: Bool { community.likeState(for: post.id)?.liked ?? post.likedByMe }

    private static let reasons = [
        "Not a car",
        "Readable number plate",
        "Somebody's home or address",
        "Harassment or abuse",
        "Not their photo",
        "Something else"
    ]

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: post.isCatch ? "Catch" : "Post") { dismiss() }
                    .overlay(alignment: .trailing) {
                        if !post.mine {
                            Button {
                                Buzz.tap()
                                reporting = true
                            } label: {
                                Image(systemName: "flag")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Ink.faint)
                                    .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                            .offset(x: -46)
                        }
                    }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if post.imageURL != nil { picture }
                        actionRow
                        author
                        if !post.text.isEmpty {
                            Text(post.text)
                                .font(UI.font(15))
                                .foregroundStyle(Ink.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        commentsSection
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)

                composer
            }
        }
        .task {
            await thread.load(postID: post.id)
            // Goes through the shared cache, so a picture already seen in the
            // feed appears instantly instead of downloading twice.
            if let url = post.imageURL { image = await ImageCache.shared.load(url) }
        }
        .confirmationDialog("Report this post", isPresented: $reporting, titleVisibility: .visible) {
            ForEach(Self.reasons, id: \.self) { reason in
                Button(reason, role: reason == "Something else" ? nil : .destructive) {
                    Task {
                        await community.report(post, reason: reason)
                        reported = true
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("We will look at it. The post is hidden for you straight away.")
        }
    }

    // MARK: Picture

    private var picture: some View {
        ZStack {
            Ink.cardAlt
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(post.isCatch ? 14 : 0)
            } else {
                ProgressView().tint(Ink.faint)
            }
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: R.card, style: .continuous))
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                Buzz.soft()
                Task { await community.toggleLike(post) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(likeCount)")
                        .font(UI.font(14, .semibold))
                }
                .foregroundStyle(liked ? Ink.accent : Ink.dim)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.card))
                .overlay(
                    RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                        .strokeBorder(liked ? Ink.accent.opacity(0.5) : Ink.line, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if let car = post.car {
                HStack(spacing: 7) {
                    Circle().fill(car.rarity.color).frame(width: 7, height: 7)
                    Text(car.fullName)
                        .font(UI.font(12.5, .semibold))
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.card))
                .overlay(
                    RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                        .strokeBorder(Ink.line, lineWidth: 1)
                )
            }
        }
    }

    private var author: some View {
        HStack(spacing: 12) {
            Avatar(handle: post.handle, image: nil, size: 40, url: post.avatarURL)
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(post.handle)")
                    .font(UI.font(15, .semibold))
                    .foregroundStyle(Ink.text)
                Text(post.city.isEmpty
                     ? post.date.formatted(.relative(presentation: .numeric))
                     : "\(post.city)  ·  \(post.date.formatted(.relative(presentation: .numeric)))")
                    .font(UI.font(11.5))
                    .foregroundStyle(Ink.faint)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .card()
    }

    // MARK: Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comments")
                    .font(UI.font(13, .semibold))
                    .foregroundStyle(Ink.dim)
                Text("(\(thread.comments.count))")
                    .font(UI.font(13))
                    .foregroundStyle(Ink.faint)
                Spacer()
            }

            if thread.loading && thread.comments.isEmpty {
                HStack { Spacer(); ProgressView().tint(Ink.accent); Spacer() }
                    .padding(.vertical, 20)
            } else if thread.comments.isEmpty {
                Text("No comments yet. Say something.")
                    .font(UI.font(13))
                    .foregroundStyle(Ink.faint)
                    .padding(.vertical, 12)
            } else {
                ForEach(thread.rootComments) { comment in
                    CommentRow(comment: comment, thread: thread) { replyingTo = comment; focused = true }

                    ForEach(thread.replies(to: comment.id)) { reply in
                        CommentRow(comment: reply, thread: thread) { replyingTo = comment; focused = true }
                            .padding(.leading, 34)
                    }
                }
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        VStack(spacing: 8) {
            if let replyingTo {
                HStack(spacing: 8) {
                    Text("Replying to @\(replyingTo.handle)")
                        .font(UI.font(11.5))
                        .foregroundStyle(Ink.faint)
                    Spacer()
                    Button("Cancel") { self.replyingTo = nil }
                        .font(UI.font(11.5, .semibold))
                        .foregroundStyle(Ink.accent)
                }
                .padding(.horizontal, 18)
            }

            HStack(spacing: 10) {
                TextField("", text: $draft, prompt: Text("Add a comment").foregroundColor(Ink.faint), axis: .vertical)
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
                    let parent = replyingTo?.id
                    draft = ""
                    replyingTo = nil
                    Task {
                        await thread.comment(
                            postID: post.id,
                            body: text,
                            handle: handle,
                            parentID: parent
                        )
                    }
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
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Comment row

struct CommentRow: View {
    let comment: Thread.Comment
    @ObservedObject var thread: Thread
    let onReply: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(handle: comment.handle, image: nil, size: 30)

            VStack(alignment: .leading, spacing: 5) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(comment.handle)
                        .font(UI.font(12.5, .semibold))
                        .foregroundStyle(Ink.text)
                    Text(comment.body)
                        .font(UI.font(13.5))
                        .foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.card))

                HStack(spacing: 14) {
                    Text(comment.date.formatted(.relative(presentation: .numeric)))
                        .font(UI.font(11))
                        .foregroundStyle(Ink.ghost)

                    Button {
                        Buzz.soft()
                        Task { await thread.likeComment(comment) }
                    } label: {
                        Text("Like it!")
                            .font(UI.font(11.5, .semibold))
                            .foregroundStyle(Ink.dim)
                    }
                    .buttonStyle(.plain)

                    Button(action: onReply) {
                        Text("Reply")
                            .font(UI.font(11.5, .semibold))
                            .foregroundStyle(Ink.dim)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    if comment.likes > 0 {
                        HStack(spacing: 4) {
                            Text("\(comment.likes)")
                                .font(UI.font(11, .semibold))
                                .foregroundStyle(Ink.faint)
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Ink.accent)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Thread store

@MainActor
final class Thread: ObservableObject {

    struct Comment: Identifiable, Equatable {
        let id: String
        let parentID: String?
        let handle: String
        let body: String
        let date: Date
        var likes: Int
    }

    @Published private(set) var comments: [Comment] = []
    @Published private(set) var loading = false

    var rootComments: [Comment] { comments.filter { $0.parentID == nil } }
    func replies(to id: String) -> [Comment] { comments.filter { $0.parentID == id } }

    func load(postID: String) async {
        loading = true
        defer { loading = false }

        let fetched = await Backend.select(
            "revdex_comments",
            query: "post_id=eq.\(postID)&order=created_at.asc&limit=200"
        )

        comments = fetched.compactMap { row in
            guard let id = row["id"] as? String, let body = row["body"] as? String else { return nil }
            return Comment(
                id: id,
                parentID: row["parent_id"] as? String,
                handle: row["handle"] as? String ?? "spotter",
                body: body,
                date: Backend.date(row["created_at"] as? String),
                likes: row["likes"] as? Int ?? 0
            )
        }
    }

    func comment(postID: String, body: String, handle: String, parentID: String?) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var row: [String: Any] = [
            "post_id": postID,
            "device_id": Backend.deviceID,
            "handle": handle,
            "body": trimmed
        ]
        if let parentID { row["parent_id"] = parentID }

        await Backend.insert("revdex_comments", [row])
        await load(postID: postID)
    }

    func likeComment(_ comment: Comment) async {
        guard let i = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        comments[i].likes += 1
        await Backend.upsert("revdex_comments", ["id": comment.id, "likes": comments[i].likes])
    }
}
