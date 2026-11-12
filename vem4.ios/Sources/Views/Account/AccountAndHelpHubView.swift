import PhotosUI
import SwiftUI
import UIKit

// MARK: - Tab 5: Mon Compte Viple Live, Avatar Cropper, Colis & Aide A–Z

public struct AccountAndHelpHubView: View {
    @Bindable var store: VemStoreViewModel
    @Environment(\.openURL) private var openURL

    // Profile Form State
    @State private var displayName: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var personalMessage: String = ""
    @State private var phoneNumber: String = ""
    @State private var city: String = ""
    @State private var bio: String = ""
    @State private var colorSchemeHex: String = "#145346"
    @State private var securityAlerts: Bool = true
    @State private var newsletter: Bool = false
    @State private var didHydrateProfile: Bool = false

    // Avatar Picker & Cropper
    @State private var pickedPhotoItem: PhotosPickerItem?
    @State private var imagePendingCrop: UIImage?
    @State private var avatarRefreshSeed: Int = 0

    // Mail Alias Quick Add
    @State private var quickAliasInput: String = ""

    // Password Form
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    private let profileSwatches = ["#145346", "#4F46E5", "#0D9488", "#0284C7", "#7C3AED", "#F43F5E", "#D97706"]

    public init(store: VemStoreViewModel) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Identity & Quick Ecosystem Launchers
                VemAuroraBackgroundCard(cornerRadius: 26) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            AvatarCirclePreview(
                                token: store.token,
                                refreshSeed: avatarRefreshSeed,
                                fallbackInitial: String((store.workspace?.viewer.firstName ?? "V").prefix(1)),
                                ringHex: colorSchemeHex
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.account?.displayName.isEmpty == false ? store.account!.displayName : (store.workspace?.viewer.displayName ?? "Mon Compte Viple"))
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(store.workspace?.viewer.email ?? "")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                if let vm = store.workspace?.vipleMail.primaryAddress, !vm.isEmpty {
                                    Text(vm)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.68, green: 0.98, blue: 0.86))
                                }
                            }
                            Spacer()
                        }

                        PhotosPicker(selection: $pickedPhotoItem, matching: .images) {
                            Label("Choisir & recadrer ma photo Viple Live", systemImage: "camera.aperture")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(VemTheme.vipleEmerald)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10.5)
                                .background(Capsule().fill(Color.white))
                        }
                        .onChange(of: pickedPhotoItem) { _, newItem in
                            guard let newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImg = UIImage(data: data) {
                                    await MainActor.run {
                                        self.imagePendingCrop = uiImg
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }

                // 2. Three Essential Hub Cards: Client Guide A-Z, Orders & Support
                VStack(spacing: 12) {
                    HubActionBannerCard(
                        icon: "graduationcap.fill",
                        tint: VemTheme.electricIndigo,
                        badge: store.bestGuideQuizScorePct > 0 ? "Quiz : \(store.bestGuideQuizScorePct)%" : "Interactif A–Z",
                        title: "Apprendre à maîtriser Viple & Moi de A à Z",
                        subtitle: "Cours client intégré pas-à-pas, bulles explicatives sans jargon et quiz interactif."
                    ) {
                        VemHaptics.selection()
                        store.showGuideSheet = true
                    }

                    HubActionBannerCard(
                        icon: "shippingbox.fill",
                        tint: VemTheme.warmCoral,
                        badge: "\(store.ordersPayload?.orders.count ?? 0) colis",
                        title: "Mes Commandes Livria & Colis Viple Delivery",
                        subtitle: "Suivez vos livres, vos codes-barres d'expédition et vos relais Viple Taker."
                    ) {
                        VemHaptics.selection()
                        store.showOrdersSheet = true
                    }

                    HubActionBannerCard(
                        icon: "lifepreserver.fill",
                        tint: VemTheme.lagoonTeal,
                        badge: store.workspace?.rights.vipPriority == true ? "Coupe-file VIP" : "Support 7j/7",
                        title: "Assistance & Support Technique Viple",
                        subtitle: "Ouvrir un ticket ou échanger avec un conseiller Cenelis."
                    ) {
                        if let u = URL(string: "https://support.viplenetwork.com") {
                            openURL(u)
                        }
                    }
                }

                // 3. Official Preset Avatars Strip
                if let presets = store.account?.presetAvatars, !presets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Galeries d'avatars officiels Viple Live")
                            .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(presets) { preset in
                                    Button {
                                        VemHaptics.selection()
                                        Task {
                                            let ok = await store.uploadAvatar(croppedBase64Png: nil, presetFile: preset.file)
                                            if ok { avatarRefreshSeed += 1 }
                                        }
                                    } label: {
                                        AsyncImage(url: resolvePresetURL(preset.url)) { phase in
                                            switch phase {
                                            case .success(let img):
                                                img.resizable().scaledToFill()
                                            default:
                                                Color.secondary.opacity(0.15)
                                            }
                                        }
                                        .frame(width: 54, height: 54)
                                        .clipShape(Circle())
                                        .overlay(Circle().strokeBorder(VemTheme.subtleBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(VemPressableButtonStyle())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .vemCard()
                }

                // 4. Unified Viple Live Profile Form
                VStack(alignment: .leading, spacing: 14) {
                    Text("Identité & Préférences Viple Live")
                        .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                    Text("Toute modification ici est synchronisée sur Viple Mail, Livria, Looby et l'ensemble des applications Cenelis.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)

                    AccountTextField(label: "Nom affiché", placeholder: "Jean Dupont", text: $displayName)
                    HStack(spacing: 10) {
                        AccountTextField(label: "Prénom", placeholder: "Jean", text: $firstName)
                        AccountTextField(label: "Nom", placeholder: "Dupont", text: $lastName)
                    }
                    AccountTextField(label: "Humeur / Message personnel", placeholder: "Disponible sur Viple…", text: $personalMessage)
                    HStack(spacing: 10) {
                        AccountTextField(label: "Téléphone mobile", placeholder: "06 12 34 56 78", text: $phoneNumber)
                        AccountTextField(label: "Ville", placeholder: "Lyon", text: $city)
                    }
                    AccountTextField(label: "Biographie courte", placeholder: "Passionné de lecture et tech…", text: $bio)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Couleur d'accentuation Viple Live")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ForEach(profileSwatches, id: \.self) { hex in
                                Button {
                                    VemHaptics.selection()
                                    colorSchemeHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(vemHex: hex))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.white, lineWidth: colorSchemeHex.uppercased() == hex ? 3 : 0)
                                        )
                                }
                            }
                        }
                    }

                    Toggle("Alertes de sécurité de connexion", isOn: $securityAlerts)
                        .font(.system(size: 13.5, weight: .semibold))
                        .tint(VemTheme.vipleEmerald)

                    Toggle("Actualités & nouveautés Viple / Livria", isOn: $newsletter)
                        .font(.system(size: 13.5, weight: .semibold))
                        .tint(VemTheme.vipleEmerald)

                    Button {
                        VemHaptics.impact(.medium)
                        Task {
                            _ = await store.saveProfile(
                                displayName: displayName,
                                firstName: firstName,
                                lastName: lastName,
                                personalMessage: personalMessage,
                                colorScheme: colorSchemeHex,
                                phoneNumber: phoneNumber,
                                bio: bio,
                                city: city,
                                securityAlerts: securityAlerts,
                                newsletter: newsletter
                            )
                        }
                    } label: {
                        Text("Enregistrer mon profil Viple Live")
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13.5)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VemTheme.vibrantActionGradient))
                    }
                    .buttonStyle(VemPressableButtonStyle())
                    .disabled(store.isMutating)
                }
                .vemCard()

                // 5. Quick Viple Mail Aliases Card
                vipleMailQuickAliasesCard

                // 6. Unified Password Change Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mot de passe unifié Viple Live & Viple Mail")
                        .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                    Text("Met à jour simultanément votre accès SSO Viple Live et votre boîte IMAP/SMTP @viplemail.fr.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)

                    SecureField("Mot de passe actuel", text: $currentPassword)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))

                    SecureField("Nouveau mot de passe (6 caractères min.)", text: $newPassword)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))

                    SecureField("Confirmer le nouveau mot de passe", text: $confirmPassword)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))

                    Button {
                        VemHaptics.impact(.medium)
                        Task {
                            let ok = await store.changePassword(
                                current: currentPassword,
                                next: newPassword,
                                confirm: confirmPassword
                            )
                            if ok {
                                currentPassword = ""
                                newPassword = ""
                                confirmPassword = ""
                            }
                        }
                    } label: {
                        Label("Mettre à jour mon mot de passe", systemImage: "key.horizontal.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(VemTheme.electricIndigo)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12.5)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(VemTheme.electricIndigo.opacity(0.12))
                            )
                    }
                    .buttonStyle(VemPressableButtonStyle())
                    .disabled(store.isMutating)
                }
                .vemCard()

                // 7. Sign Out Button
                Button {
                    VemHaptics.warning()
                    store.signOut()
                } label: {
                    Label("Se déconnecter de Viple & Moi", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VemTheme.warmCoral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(VemTheme.warmCoral.opacity(0.12))
                        )
                }
                .buttonStyle(VemPressableButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(VemTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Compte & Aide")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hydrateProfileIfNeeded()
        }
        .onChange(of: store.account?.email) { _, _ in
            hydrateProfileIfNeeded(force: true)
        }
        .sheet(
            isPresented: Binding(
                get: { imagePendingCrop != nil },
                set: { if !$0 { imagePendingCrop = nil } }
            )
        ) {
            if let img = imagePendingCrop {
                AvatarSquareCropperSheet(sourceImage: img) { base64DataUrl in
                    imagePendingCrop = nil
                    Task {
                        let ok = await store.uploadAvatar(croppedBase64Png: base64DataUrl, presetFile: nil)
                        if ok { avatarRefreshSeed += 1 }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var vipleMailQuickAliasesCard: some View {
        let mail = store.workspace?.vipleMail ?? VemMailStatus()
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Alias @viplemail.fr (\(mail.aliases.count)/5)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Spacer()
                Button {
                    if let u = URL(string: mail.webmailUrl) { openURL(u) }
                } label: {
                    Text("Webmail →")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VemTheme.vipleEmerald)
                }
            }

            if !mail.aliases.isEmpty {
                ForEach(mail.aliases, id: \.self) { al in
                    HStack {
                        Text(al)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        Spacer()
                        Button {
                            Task { _ = await store.manageMailAlias(action: "remove", alias: al) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(VemTheme.warmCoral)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(VemTheme.elevatedSurface))
                }
            }

            if mail.aliases.count < 5 && (store.workspace?.rights.canChangeMailAlias ?? true) {
                HStack(spacing: 8) {
                    TextField("nouvel.alias", text: $quickAliasInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 13, design: .monospaced))
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))
                    Button("Créer") {
                        let trimmed = quickAliasInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            let ok = await store.manageMailAlias(action: "add", alias: trimmed)
                            if ok { quickAliasInput = "" }
                        }
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.vipleEmerald))
                }
            }
        }
        .vemCard()
    }

    private func hydrateProfileIfNeeded(force: Bool = false) {
        guard !didHydrateProfile || force else { return }
        guard let acc = store.account else { return }
        didHydrateProfile = true
        displayName = acc.displayName
        firstName = acc.firstName
        lastName = acc.lastName
        personalMessage = acc.personalMessage
        phoneNumber = acc.phoneNumber
        city = acc.city
        bio = acc.bio
        colorSchemeHex = acc.colorScheme.isEmpty ? "#145346" : acc.colorScheme
        securityAlerts = acc.securityAlerts
        newsletter = acc.newsletter
    }

    private func resolvePresetURL(_ raw: String) -> URL? {
        if raw.hasPrefix("http") { return URL(string: raw) }
        return URL(string: "https://espace-client-v4.viplenetwork.com\(raw.hasPrefix("/") ? "" : "/")\(raw)")
    }
}

private struct AvatarCirclePreview: View {
    let token: String?
    let refreshSeed: Int
    let fallbackInitial: String
    let ringHex: String

    @State private var resolvedURL: URL?

    var body: some View {
        ZStack {
            if let resolvedURL {
                AsyncImage(url: resolvedURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        fallbackBadge
                    }
                }
            } else {
                fallbackBadge
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color(vemHex: ringHex), lineWidth: 3))
        .shadow(radius: 6)
        .task(id: refreshSeed) {
            let base = await VemAPIClient.shared.currentAvatarURL(token: token)
            var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
            var items = comps?.queryItems ?? []
            items.append(URLQueryItem(name: "seed", value: "\(refreshSeed)"))
            comps?.queryItems = items
            resolvedURL = comps?.url ?? base
        }
    }

    private var fallbackBadge: some View {
        ZStack {
            Color.white.opacity(0.22)
            Text(fallbackInitial.uppercased())
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

private struct HubActionBannerCard: View {
    let icon: String
    let tint: Color
    let badge: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(tint)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(badge)
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(tint.opacity(0.13)))
                        Spacer()
                    }
                    Text(title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .vemCard(cornerRadius: 20, padding: 15)
        }
        .buttonStyle(VemPressableButtonStyle())
    }
}

private struct AccountTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .padding(11.5)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))
        }
    }
}

// MARK: - Interactive 260×260 Square Avatar Zoom & Drag Cropper Sheet

private struct AvatarSquareCropperSheet: View {
    let sourceImage: UIImage
    let onCropped: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    private let viewportSize: CGFloat = 260

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Text("Déplacez et zoomez votre photo dans le cadre carré")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ZStack {
                    Color.black
                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: viewportSize, height: viewportSize)
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                }
                .frame(width: viewportSize, height: viewportSize)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(VemTheme.vipleMint, lineWidth: 3)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            panOffset = CGSize(
                                width: lastPanOffset.width + value.translation.width,
                                height: lastPanOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastPanOffset = panOffset
                        }
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                        Slider(value: $zoomScale, in: 1.0...3.0)
                            .tint(VemTheme.vipleEmerald)
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)

                Button {
                    VemHaptics.impact(.medium)
                    if let dataUrl = renderCroppedDataURL() {
                        onCropped(dataUrl)
                    }
                } label: {
                    Label("Valider & Enregistrer mon avatar", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VemTheme.vibrantActionGradient))
                }
                .buttonStyle(VemPressableButtonStyle())
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 20)
            .background(VemTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Recadrer ma photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private func renderCroppedDataURL() -> String? {
        let target = CGSize(width: 260, height: 260)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)

        let rendered = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: target))

            let imgSize = sourceImage.size
            guard imgSize.width > 0, imgSize.height > 0 else { return }
            let fillScale = max(target.width / imgSize.width, target.height / imgSize.height) * zoomScale
            let drawWidth = imgSize.width * fillScale
            let drawHeight = imgSize.height * fillScale
            let originX = (target.width - drawWidth) / 2.0 + panOffset.width
            let originY = (target.height - drawHeight) / 2.0 + panOffset.height
            sourceImage.draw(in: CGRect(x: originX, y: originY, width: drawWidth, height: drawHeight))
        }

        guard let png = rendered.pngData() else { return nil }
        return "data:image/png;base64,\(png.base64EncodedString())"
    }
}
