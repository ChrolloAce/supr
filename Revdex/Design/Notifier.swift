import SwiftUI

/// In-app banners. Nothing here goes through the notification centre; these
/// only ever appear while the app is open, so an unlock can be celebrated
/// without asking anyone for push permission.
@MainActor
final class Notifier: ObservableObject {
    static let shared = Notifier()

    struct Note: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let symbol: String
        /// Set when the banner should show generated badge art instead.
        var asset: String?
        var tint: Color = Ink.accent

        static func == (a: Note, b: Note) -> Bool { a.id == b.id }
    }

    @Published private(set) var current: Note?

    private var queue: [Note] = []
    private var timer: Task<Void, Never>?

    private init() {}

    func post(_ note: Note) {
        queue.append(note)
        if current == nil { advance() }
    }

    func post(unlocked achievement: Achievement) {
        post(Note(
            title: achievement.title,
            message: achievement.blurb,
            symbol: achievement.symbol,
            asset: achievement.asset,
            tint: achievement.color
        ))
    }

    func dismiss() {
        timer?.cancel()
        advance()
    }

    private func advance() {
        timer?.cancel()
        guard !queue.isEmpty else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { current = nil }
            return
        }
        let next = queue.removeFirst()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { current = next }
        Buzz.win()

        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.4))
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }
}

// MARK: - Host

/// Sits on top of everything in the root view.
struct ToastHost: View {
    @ObservedObject private var notifier = Notifier.shared

    var body: some View {
        VStack {
            if let note = notifier.current {
                banner(note)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(note.id)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .allowsHitTesting(notifier.current != nil)
    }

    private func banner(_ note: Note) -> some View {
        HStack(spacing: 12) {
            art(note)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(UI.font(14.5, .semibold))
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                Text(note.message)
                    .font(UI.font(12))
                    .foregroundStyle(Ink.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)

            Text("UNLOCKED")
                .label(8.5, .semibold, tracking: 1)
                .foregroundStyle(note.tint)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Ink.card)
                .shadow(color: .black.opacity(0.55), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(note.tint.opacity(0.45), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { notifier.dismiss() }
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height < -10 { notifier.dismiss() }
                }
        )
    }

    private typealias Note = Notifier.Note

    @ViewBuilder
    private func art(_ note: Note) -> some View {
        if let asset = note.asset, UIImage(named: asset) != nil {
            Image(asset).resizable().scaledToFit()
        } else {
            Circle()
                .fill(note.tint.opacity(0.18))
                .overlay(Circle().strokeBorder(note.tint.opacity(0.5), lineWidth: 1))
                .overlay(
                    Image(systemName: note.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(note.tint)
                )
        }
    }
}
