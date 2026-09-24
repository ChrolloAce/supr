import SwiftUI

struct ActivityItem: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let detail: String
}

struct ActivityView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Activity") { dismiss() }

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.activity()) { item in
                            HStack(spacing: 13) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                                        .fill(item.tint.opacity(0.13))
                                    Image(systemName: item.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(item.tint)
                                }
                                .frame(width: 38, height: 38)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(UI.font(12, .semibold))
                                        .foregroundStyle(Ink.text)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(item.detail)
                                        .font(UI.font(10))
                                        .foregroundStyle(Ink.faint)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(13)
                            .card()
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

/// Shared header for sheets: title left, close button right.
struct SheetHeader: View {
    let title: String
    var trailingLabel: String? = nil
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .label(14, .bold, tracking: 3.4)
                .foregroundStyle(Ink.text)
            Spacer()
            if let trailingLabel {
                Text(trailingLabel)
                    .label(10, .semibold, tracking: 1.4)
                    .foregroundStyle(Ink.faint)
                    .padding(.trailing, 4)
            }
            IconButton(icon: "xmark", size: 38, tint: Ink.dim, filled: true, action: onClose)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
}
