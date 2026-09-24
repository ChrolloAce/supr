import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var account: Account
    @EnvironmentObject private var syncService: Sync
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var handle = ""
    @State private var city = ""
    @State private var showPaywall = false
    @State private var confirmReset = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var deleteConfirmText = ""
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var showTerms = false
    @State private var showGuidelines = false
    @State private var showRanks = false
    @State private var showFavouritePicker = false
    @State private var avatarItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Backdrop()

            VStack(spacing: 0) {
                SheetHeader(title: "Profile") {
                    commit()
                    dismiss()
                }

                ScrollView {
                    VStack(spacing: 12) {
                        identityCard
                        favouriteCard
                        proCard
                        statsRow
                        rarityCard
                        fields
                        accountPanel
                                footer
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18)
                }
                .scrollIndicators(.hidden)
            }
        }
        .suprPaywall(.settings, isPresented: $showPaywall, context: .settings)
        .sheet(isPresented: $showTerms) { LegalView(kind: .terms) }
        .sheet(isPresented: $showGuidelines) { LegalView(kind: .guidelines) }
        .sheet(isPresented: $showRanks) { RankLadderView() }
        .sheet(isPresented: $showFavouritePicker) { FavouriteCarPicker() }
        .onChange(of: avatarItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    store.setAvatar(image)
                }
                avatarItem = nil
            }
        }
        .onAppear {
            handle = store.profile.handle
            city = store.profile.city
        }
    }

    private var identityCard: some View {
        let p = Levels.progress(xp: store.profile.xp)
        return VStack(spacing: 14) {
            HStack(spacing: 14) {
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    ZStack {
                        Rectangle().fill(Ink.shadow).offset(x: 3, y: 3)
                        if let avatar = store.avatarImage {
                            Image(uiImage: avatar).resizable().scaledToFill()
                        } else {
                            ZStack {
                                Ink.cardAlt
                                Text(String((store.profile.handle.isEmpty ? "S" : store.profile.handle).prefix(1)))
                                    .display(26)
                                    .foregroundStyle(Ink.faint)
                            }
                        }
                        Rectangle().strokeBorder(Ink.line, lineWidth: Line.bold)
                    }
                    .frame(width: 62, height: 62)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Ink.onAccent)
                            .frame(width: 20, height: 20)
                            .background(Ink.accentSoft)
                            .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.5))
                            .offset(x: 6, y: 6)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("@\(store.profile.handle.isEmpty ? "spotter" : store.profile.handle.lowercased())")
                        .display(22)
                        .foregroundStyle(Ink.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(store.profile.city.isEmpty ? "NO CITY SET" : store.profile.city)
                        .label(9, .bold, tracking: 0.8)
                        .foregroundStyle(Ink.ghost)
                }

                Spacer(minLength: 0)

                Button {
                    Buzz.tap()
                    showRanks = true
                } label: {
                    RankBadge(rank: store.profile.rank, size: 46)
                }
                .buttonStyle(.plain)
            }

            XPBar(progress: p.fraction)

            HStack {
                Text("LV \(p.level)  ·  \(store.profile.rankName)")
                    .label(10, .heavy, tracking: 0.5)
                    .foregroundStyle(store.profile.rank.tier.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text("\(p.need - p.into) TO LV \(p.level + 1)")
                    .label(9.5, .bold, tracking: 0.4)
                    .foregroundStyle(Ink.faint)
            }
        }
        .padding(16)
        .card()
    }

    /// The one car you want on your profile.
    private var favouriteCard: some View {
        Button {
            Buzz.tap()
            showFavouritePicker = true
        } label: {
            HStack(spacing: 13) {
                if let car = store.favouriteCar {
                    Text(car.dexNumber)
                        .label(10, .heavy, tracking: 0.4)
                        .foregroundStyle(car.rarity.onColor)
                        .frame(width: 40, height: 30)
                        .background(car.rarity.color)
                        .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.6))
                } else {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Ink.onAccent)
                        .frame(width: 40, height: 30)
                        .background(Ink.accentSoft)
                        .overlay(Rectangle().strokeBorder(Ink.line, lineWidth: 1.6))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Signature car")
                        .label(9.5, .bold, tracking: 0.8)
                        .foregroundStyle(Ink.faint)
                    Text(store.favouriteCar?.fullName ?? "Pick one from your garage")
                        .display(18)
                        .foregroundStyle(store.favouriteCar == nil ? Ink.faint : Ink.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Ink.faint)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
    }

    @ViewBuilder
    private var proCard: some View {
        if store.isPro {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Ink.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("SUPR Pro")
                        .label(11, .bold, tracking: 1.4)
                        .foregroundStyle(Ink.text)
                    Text("Unlimited captures · full board · luck boost")
                        .font(UI.font(9.5))
                        .foregroundStyle(Ink.faint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(15)
            .card(Ink.cream)
        } else {
            Button("Go pro") {
                Buzz.tap()
                showPaywall = true
            }
            .buttonStyle(.accent)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat("\(store.dexCount)", "Spotted")
            stat("\(store.captures.count)", "Captures")
            stat("\(store.profile.streak)", "Streak")
        }
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(UI.font(19, .bold))
                .foregroundStyle(Ink.text)
            Text(caption)
                .label(8.5, .semibold, tracking: 1.4)
                .foregroundStyle(Ink.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .card(Ink.card, radius: R.chip)
    }

    private var rarityCard: some View {
        VStack(spacing: 11) {
            Caption(text: "Collection")
            ForEach(Rarity.allCases.reversed(), id: \.self) { r in
                let have = store.rarityCount(r)
                let total = Catalog.cars(of: r).count
                HStack(spacing: 11) {
                    Text(r.title)
                        .label(9, .bold, tracking: 1.2)
                        .foregroundStyle(r.color)
                        .frame(width: 74, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule()
                                .fill(r.color.opacity(0.85))
                                .frame(width: max(0, geo.size.width * (total == 0 ? 0 : Double(have) / Double(total))))
                        }
                    }
                    .frame(height: 5)
                    Text("\(have)/\(total)")
                        .label(8.5, .semibold, tracking: 0.8)
                        .foregroundStyle(Ink.ghost)
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .card()
    }

    private var fields: some View {
        VStack(spacing: 10) {
            Caption(text: "Settings")
            field("Handle", text: $handle, placeholder: "YOUR TAG")
            field("City", text: $city, placeholder: "WHERE YOU HUNT")
            proSwitch
        }
    }

    /// Stands in for a real receipt until StoreKit is wired up. It exists so
    /// Pro can be tried on and taken off again; nothing here is a purchase.
    private var proSwitch: some View {
        HStack(spacing: 12) {
            Text("PRO")
                .label(9, .semibold, tracking: 1.4)
                .foregroundStyle(Ink.faint)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(store.isPro
                     ? "\(GameStore.Quota.proWeekly) captures a week"
                     : "\(GameStore.Quota.freeDaily) captures a day")
                    .font(UI.font(12.5, .semibold))
                    .foregroundStyle(Ink.text)
                Text("Not a purchase, just a switch for now")
                    .font(UI.font(10))
                    .foregroundStyle(Ink.ghost)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { store.isPro },
                set: { on in
                    Buzz.soft()
                    store.setPro(on)
                }
            ))
            .labelsHidden()
            .tint(Ink.accent)
        }
        .padding(.horizontal, 15)
        .frame(height: 58)
        .card(Ink.card, radius: R.chip)
    }

    private func field(_ caption: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(caption)
                .label(9, .semibold, tracking: 1.4)
                .foregroundStyle(Ink.faint)
                .frame(width: 56, alignment: .leading)
            TextField("", text: text, prompt: Text(placeholder).font(UI.font(11)).foregroundColor(Ink.ghost))
                .font(UI.font(12.5, .semibold))
                .foregroundStyle(Ink.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .onSubmit { commit() }
        }
        .padding(.horizontal, 15)
        .frame(height: 52)
        .card(Ink.card, radius: R.chip)
    }

    /// Signed in state, the legal documents, and the way out.
    private var accountPanel: some View {
        VStack(spacing: 10) {
            Caption(text: "Account")

            HStack(spacing: 12) {
                Image(systemName: account.isSignedIn ? "checkmark.seal.fill" : "person.crop.circle.badge.questionmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(account.isSignedIn ? Ink.accent : Ink.faint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.isSignedIn
                         ? (account.provider == .apple ? "Signed in with Apple" : "Signed in with email")
                         : "Not signed in")
                        .font(UI.font(14, .semibold))
                        .foregroundStyle(Ink.text)
                    Text(accountDetail)
                        .font(UI.font(11.5))
                        .foregroundStyle(Ink.faint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .card()

            // Both documents have to stay reachable outside the paywall too, so
            // that somebody who already subscribed can still find them. Privacy
            // has no in app copy, so it opens the hosted one.
            HStack(spacing: 10) {
                legalButton("Terms of Use") { showTerms = true }
                legalButton("Privacy") { openURL(Legal.privacy) }
                legalButton("Guidelines") { showGuidelines = true }
            }

            // The GDPR requires consent to be as easy to withdraw as to give,
            // so the form has to be reachable after the first launch too. Only
            // shown to people the form actually applies to.
            if Consent.privacyOptionsRequired {
                Button {
                    Buzz.tap()
                    Task { await Consent.showPrivacyOptions() }
                } label: {
                    Text("Ad privacy settings")
                        .font(UI.font(13.5, .semibold))
                        .foregroundStyle(Ink.dim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                                .strokeBorder(Ink.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if account.isSignedIn {
                Button {
                    Buzz.nope()
                    if confirmSignOut {
                        account.signOut()
                        confirmSignOut = false
                        dismiss()
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) { confirmSignOut = true }
                    }
                } label: {
                    Text(confirmSignOut ? "Tap again to sign out" : "Sign out")
                        .font(UI.font(13.5, .semibold))
                        .foregroundStyle(confirmSignOut ? Ink.accent : Ink.dim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                                .strokeBorder(confirmSignOut ? Ink.accent.opacity(0.5) : Ink.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Text("Signing out keeps your garage on this device. Your posts stay up.")
                    .font(UI.font(11))
                    .foregroundStyle(Ink.ghost)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            deleteAccountRow
        }
    }

    private var accountDetail: String {
        if !account.isSignedIn { return "Sign in from the Community tab to post and comment." }
        if !account.email.isEmpty { return account.email }
        if !account.name.isEmpty { return account.name }
        return "Apple account connected"
    }

    /// Deleting is permanent, so it asks for the word rather than a second tap.
    /// A stray double tap must never be able to wipe somebody's collection.
    private var deleteAccountRow: some View {
        VStack(spacing: 10) {
            if deleting {
                HStack(spacing: 10) {
                    ProgressView().tint(Ink.accent)
                    Text("Deleting your account")
                        .font(UI.font(13.5, .semibold))
                        .foregroundStyle(Ink.faint)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            } else if confirmDelete {
                TextField(
                    "",
                    text: $deleteConfirmText,
                    prompt: Text("Type DELETE to confirm").foregroundColor(Ink.ghost)
                )
                .font(UI.font(14, .semibold))
                .foregroundStyle(Ink.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.card))
                .overlay(
                    RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                        .strokeBorder(Color(hex: 0xC0392B).opacity(0.6), lineWidth: 1)
                )

                HStack(spacing: 10) {
                    Button("Cancel") {
                        Buzz.tap()
                        withAnimation { confirmDelete = false; deleteConfirmText = "" }
                    }
                    .font(UI.font(13.5, .semibold))
                    .foregroundStyle(Ink.dim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)

                    Button("Delete for good") {
                        Buzz.nope()
                        runDelete()
                    }
                    .font(UI.font(13.5, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                            .fill(Color(hex: 0xC0392B))
                    )
                    .opacity(deleteConfirmText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE" ? 1 : 0.35)
                    .disabled(deleteConfirmText.trimmingCharacters(in: .whitespaces).uppercased() != "DELETE")
                }
            } else {
                Button {
                    Buzz.tap()
                    withAnimation { confirmDelete = true }
                } label: {
                    Text("Delete account")
                        .font(UI.font(13.5, .semibold))
                        .foregroundStyle(Color(hex: 0xC0392B))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text(deleteError ?? "This erases your garage, your posts and your profile, on this device and on our servers. It cannot be undone.")
                .font(UI.font(11))
                .foregroundStyle(deleteError == nil ? Ink.ghost : Color(hex: 0xC0392B))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 6)
    }

    private func runDelete() {
        deleting = true
        deleteError = nil
        Task {
            let cleared = await syncService.deleteEverythingRemote()
            if cleared {
                store.resetEverything()
                account.signOut()
                deleting = false
                dismiss()
            } else {
                // Nothing local is touched, so a failed wipe leaves the person
                // with their account intact rather than half deleted.
                deleting = false
                deleteError = "Could not reach the server, so nothing was deleted. Check your connection and try again."
            }
        }
    }

    private func legalButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(UI.font(12.5, .semibold))
                .foregroundStyle(Ink.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: R.chip, style: .continuous).fill(Ink.card))
                .overlay(
                    RoundedRectangle(cornerRadius: R.chip, style: .continuous)
                        .strokeBorder(Ink.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }


    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Buzz.nope()
                if confirmReset {
                    store.resetEverything()
                    dismiss()
                } else {
                    withAnimation(.easeOut(duration: 0.15)) { confirmReset = true }
                }
            } label: {
                Text(confirmReset ? "Tap again to wipe everything" : "Reset progress")
                    .label(10.5, .semibold, tracking: 1.4)
                    .foregroundStyle(confirmReset ? Ink.accent : Ink.faint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: R.pill, style: .continuous).fill(Ink.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: R.pill, style: .continuous)
                            .strokeBorder(confirmReset ? Ink.accent.opacity(0.5) : Ink.line, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Text("SUPR v1.0")
                .label(8.5, .medium, tracking: 2)
                .foregroundStyle(Ink.ghost)
        }
        .padding(.top, 4)
    }

    private func commit() {
        store.updateHandle(handle)
        store.updateCity(city)
        // Push it, otherwise the rename only exists on this phone.
        Task { await syncService.pushProfile() }
    }
}
