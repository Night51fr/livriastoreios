import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Mon Profil Livria & Studio de Personnalisation Viple Live ID (ProfileView)

public struct ProfileView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var motto: String = ""
    @State private var favoriteGenres: String = ""
    @State private var yearlyGoal: Int = 12
    @State private var selectedThemeId: String = "default"
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var postalCode: String = ""
    @State private var city: String = ""
    @State private var showingDeleteAccountConfirmation: Bool = false

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageForCrop: UIImage? = nil
    @State private var isShowingAvatarCropper: Bool = false
    @State private var isUploadingAvatar: Bool = false
    @State private var isShowingAdvancedSettingsSheet: Bool = false
    @State private var quickTrackingCode: String = ""
    @State private var activeDigitalReaderEntry: LivriaShelfEntry? = nil
    @State private var activeAudioPlayerEntry: LivriaShelfEntry? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    quickAccessEcosystemCard
                    myLibraryProfileSectionCard
                    vipleDeliveryDirectTrackingCard
                    favoritesAndReadingStatsCard

                    if !store.isAuthenticated {
                        guestRestrictedProfileCard
                        advancedSettingsEntryCard
                    } else {
                        profileIdentityHeaderCard
                        themePersonalizationStudioCard
                        editProfileAndAddressCard
                        advancedSettingsEntryCard
                        legalTermsReviewCard
                        signOutCard
                        deleteAccountCard
                    }
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Mon Profil Livria")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                populateFieldsFromStore()
            }
            .sheet(isPresented: $isShowingAdvancedSettingsSheet) {
                LivriaAdvancedSettingsSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $store.isShowingVipleDeliverySheet) {
                if let tracking = store.activeTrackingResult {
                    LivriaVipleDeliveryTrackingSheet(tracking: tracking)
                        .environmentObject(store)
                }
            }
            .sheet(item: $activeDigitalReaderEntry) { entry in
                LivriaDigitalReaderSheet(entry: entry)
                    .environmentObject(store)
            }
            .sheet(item: $activeAudioPlayerEntry) { entry in
                LivriaAudioPlayerSheet(entry: entry)
                    .environmentObject(store)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            selectedImageForCrop = uiImage
                            isShowingAvatarCropper = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingAvatarCropper) {
                if let img = selectedImageForCrop {
                    LivriaAvatarCropperSheet(sourceImage: img) { croppedData in
                        isShowingAvatarCropper = false
                        isUploadingAvatar = true
                        Task {
                            _ = await store.uploadCroppedAvatar(imageData: croppedData)
                            await MainActor.run {
                                isUploadingAvatar = false
                            }
                        }
                    }
                }
            }
            .alert("Êtes-vous sûr de vouloir supprimer votre compte Viple Live ID ?", isPresented: $showingDeleteAccountConfirmation) {
                Button("Annuler", role: .cancel) {}
                Button("Oui, supprimer définitivement", role: .destructive) {
                    Task {
                        _ = await store.deleteVipleAccount()
                    }
                }
            } message: {
                Text("Êtes-vous sûr de vouloir supprimer définitivement votre compte Viple Live ID ? Cette action est irréversible et entraînera la suppression de votre profil et de vos données associées.")
            }
        }
    }

    // MARK: - Accès Rapide Écosystème Livria (Marketplace, Livria Social, Viple Taker)

    private var quickAccessEcosystemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LivriaPalette.primary)
                Text("Accès rapide")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                Text("Écosystème Livria")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LivriaPalette.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
            }

            HStack(spacing: 10) {
                Button {
                    store.openLivriaMarketplaceApp()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(LivriaPalette.primary))
                            Spacer()
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(LivriaPalette.primary)
                        }
                        Text("Marketplace")
                            .font(.system(size: 13.5, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                        Text("Livres, CD/DVD, Goodies & Vêtements")
                            .font(.system(size: 10.5))
                            .foregroundStyle(LivriaPalette.inkMuted)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.primarySoft.opacity(0.55)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LivriaPalette.primary.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    store.openLivriaSocialApp()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(LivriaPalette.coral))
                            Spacer()
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(LivriaPalette.coral)
                        }
                        Text("Livria Social")
                            .font(.system(size: 13.5, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                        Text("Communauté, Clubs & Messagerie")
                            .font(.system(size: 10.5))
                            .foregroundStyle(LivriaPalette.inkMuted)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.background))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LivriaPalette.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                VipleTakerApplicationView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LivriaPalette.primary)
                            .frame(width: 38, height: 38)
                        Image(systemName: "shippingbox.and.arrow.backward.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Devenir Viple Taker (Point Relais Particulier)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(LivriaPalette.ink)
                            Text("1,00 € / colis")
                                .font(.system(size: 10, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.15)))
                                .foregroundStyle(.green)
                        }
                        Text("Réceptionnez les colis Livria chez vous et gagnez 1,00 € par colis remis")
                            .font(.system(size: 11))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(LivriaPalette.primary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.background))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LivriaPalette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .livriaCard()
    }

    private var guestRestrictedProfileCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LivriaPalette.primarySoft)
                    .frame(width: 68, height: 68)
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(LivriaPalette.primary)
            }

            Text("Connexion requise pour Mon Profil")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
                .multilineTextAlignment(.center)

            Text("En mode invité (hors connexion), seuls Mes Commandes, les Points Relais et le Scan ISBN sont accessibles. Connectez-vous à votre compte Viple Live ID pour accéder à votre profil.")
                .font(.system(size: 13.5))
                .foregroundStyle(LivriaPalette.inkMuted)
                .multilineTextAlignment(.center)

            Button {
                store.isShowingAuthSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Se connecter / Créer un compte Viple Live ID")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [LivriaPalette.primary, LivriaPalette.coral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .livriaCard()
    }

    // MARK: - En-tête Profil avec LevelRing Circulaire & Badge Viple Live ID

    private var profileIdentityHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                LevelRingView(
                    avatarUrl: store.currentUser?.avatarUrl,
                    displayName: store.currentUser?.displayName ?? "Membre",
                    level: store.currentUser?.level ?? 1,
                    xp: store.currentUser?.xp ?? 0,
                    size: 86
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.currentUser?.displayName ?? "Membre Livria")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(LivriaPalette.gold)
                        Text(store.currentUser?.isLivriaPlus == true ? "Abonné Club Looby+" : "Membre Livria")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.16)))

                    if let email = store.currentUser?.email, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LivriaPalette.goldSoft)
                    }
                }
                Spacer()
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack {
                    Image(systemName: "camera.crop.circle.fill")
                    Text("Uploader & Recadrer ma photo de profil")
                        .font(.system(size: 13.5, weight: .bold))
                    Spacer()
                    Image(systemName: "crop")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.18)))
                .foregroundStyle(.white)
            }
            .disabled(isUploadingAvatar)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LivriaPalette.heroGradient))
    }

    // MARK: - Studio de Personnalisation de Livria (Thèmes d'arrière-plan 60-80% transparents)

    private var themePersonalizationStudioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                    .font(.title3)
                    .foregroundStyle(LivriaPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Studio de Personnalisation de Livria")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Thèmes d'arrière-plan (voile transparent 60–80%) synchronisés avec livria.store")
                        .font(.system(size: 11.5))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(LivriaSiteThemeOption.all) { opt in
                    let isSelected = store.currentThemeId == opt.id
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedThemeId = opt.id
                            store.setTheme(opt.id)
                        }
                        if store.isAuthenticated {
                            saveChanges()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: opt.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: opt.icon)
                                        .font(.caption)
                                        .foregroundStyle(LivriaPalette.ink)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(opt.name)
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                                    .lineLimit(1)
                                Text(opt.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundStyle(LivriaPalette.inkMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(LivriaPalette.primary)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? LivriaPalette.primarySoft.opacity(0.6) : LivriaPalette.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? LivriaPalette.primary : LivriaPalette.border, lineWidth: isSelected ? 1.8 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .livriaCard()
    }

    // MARK: - Formulaire d'Édition du Profil & Adresse de Livraison

    private var editProfileAndAddressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Informations publiques & Livraison")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            VStack(alignment: .leading, spacing: 5) {
                Text("Nom d'affichage")
                    .font(.system(size: 12, weight: .semibold))
                TextField("Nom d'affichage", text: $displayName)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Devise / Statut Viple Live ID")
                    .font(.system(size: 12, weight: .semibold))
                TextField("Ex: Membre Viple Live ID", text: $motto)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Biographie littéraire")
                    .font(.system(size: 12, weight: .semibold))
                TextField("Parlez de vos auteurs et univers préférés...", text: $bio, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Genres favoris")
                    .font(.system(size: 12, weight: .semibold))
                TextField("Roman, Science-Fiction, Thriller...", text: $favoriteGenres)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            Stepper("Objectif annuel de lecture : \(yearlyGoal) livres", value: $yearlyGoal, in: 1...200)
                .font(.system(size: 13.5, weight: .semibold))

            Divider()

            Text("Adresse d'expédition UPS par défaut")
                .font(.system(size: 14, weight: .bold))

            HStack(spacing: 10) {
                TextField("Prénom", text: $firstName)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                TextField("Nom", text: $lastName)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            TextField("Téléphone", text: $phone)
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

            TextField("Adresse postale", text: $address)
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

            HStack(spacing: 10) {
                TextField("Code postal", text: $postalCode)
                    .frame(width: 110)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                TextField("Ville", text: $city)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            Button {
                saveChanges()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Enregistrer mon profil Livria")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .livriaCard()
    }

    private var legalTermsReviewCard: some View {
        Button {
            store.isShowingTermsReviewSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LivriaPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Revoir les Conditions Générales (CGU / CGV)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Conditions Générales d'Utilisation & de Vente Livria et Viple Live ID")
                        .font(.system(size: 11.5))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(LivriaPalette.inkMuted)
            }
            .livriaCard(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var signOutCard: some View {
        Button(role: .destructive) {
            store.signOut()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Se déconnecter du compte Viple Live ID")
                    .font(.system(size: 14.5, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.12)))
            .foregroundStyle(.red)
        }
    }

    private var deleteAccountCard: some View {
        Button(role: .destructive) {
            showingDeleteAccountConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("Supprimer mon compte Viple Live ID")
                    .font(.system(size: 14.5, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.20)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.45), lineWidth: 1))
            .foregroundStyle(.red)
        }
    }

    private func populateFieldsFromStore() {
        selectedThemeId = store.currentThemeId
        guard let u = store.currentUser else { return }
        displayName = u.displayName
        bio = u.bio
        motto = u.motto
        favoriteGenres = u.favoriteGenres
        yearlyGoal = max(1, u.yearlyGoal)
        firstName = u.firstName
        lastName = u.lastName
        phone = u.phone
        address = u.address
        postalCode = u.postalCode
        city = u.city
    }

    private func saveChanges() {
        store.setTheme(selectedThemeId)
        guard store.isAuthenticated else { return }
        Task {
            await store.updateProfile(
                displayName: displayName,
                bio: bio,
                motto: motto,
                favoriteGenres: favoriteGenres,
                yearlyGoal: yearlyGoal,
                themeId: selectedThemeId,
                firstName: firstName,
                lastName: lastName,
                phone: phone,
                address: address,
                postalCode: postalCode,
                city: city
            )
        }
    }

    // MARK: - Section « Ma bibliothèque » dans Mon Profil (avec Lecteur Numérique & Audio uniquement pour les livres détenus en Numérique/Audio)

    private var myLibraryProfileSectionCard: some View {
        let totalCount = store.shelf.count
        let digitalOrAudioCount = store.shelf.filter { $0.ownsDigital || $0.ownsAudio }.count
        let readingCount = store.shelf.filter { $0.status == "Reading" }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ma bibliothèque")
                        .font(.system(size: 16.5, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("\(totalCount) livre\(totalCount > 1 ? "s" : "") • \(digitalOrAudioCount) détenu\(digitalOrAudioCount > 1 ? "s" : "") en Numérique/Audio")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
                NavigationLink {
                    LivriaMyLibraryView()
                } label: {
                    HStack(spacing: 4) {
                        Text("Tout voir")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
                    .foregroundStyle(LivriaPalette.primary)
                }
            }

            HStack(spacing: 8) {
                libraryMiniStatPill(icon: "book.closed.fill", label: "Étagères", value: "\(totalCount)", tint: LivriaPalette.primary)
                libraryMiniStatPill(icon: "ipad.and.iphone", label: "Numérique/Audio", value: "\(digitalOrAudioCount)", tint: LivriaPalette.coral)
                libraryMiniStatPill(icon: "bookmark.fill", label: "En cours", value: "\(readingCount)", tint: LivriaPalette.mint)
            }

            if store.shelf.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "text.book.closed")
                        .font(.title3)
                        .foregroundStyle(LivriaPalette.primary)
                    Text(store.isAuthenticated
                         ? "Votre bibliothèque est prête. Vos achats Livria Store (Broché, Numérique et Audio) ainsi que vos lectures y apparaissent automatiquement."
                         : "Connectez-vous à votre compte Viple Live ID pour retrouver votre bibliothèque personnelle et vos livres numériques & audio.")
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.shelf.prefix(8)) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    LivriaBookCoverView(
                                        coverUrl: entry.coverUrl,
                                        title: entry.title,
                                        width: 108,
                                        height: 152,
                                        cornerRadius: 12
                                    )
                                    if entry.ownsDigital || entry.ownsAudio {
                                        HStack(spacing: 3) {
                                            if entry.ownsDigital {
                                                Image(systemName: "ipad")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                            if entry.ownsAudio {
                                                Image(systemName: "headphones")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(LivriaPalette.primary))
                                        .foregroundStyle(.white)
                                        .padding(6)
                                    }
                                }

                                Text(entry.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                                    .lineLimit(1)
                                    .frame(width: 108, alignment: .leading)

                                Text(entry.author)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(LivriaPalette.inkMuted)
                                    .lineLimit(1)
                                    .frame(width: 108, alignment: .leading)

                                if entry.canOpenDigitalReader || entry.canOpenAudioPlayer {
                                    HStack(spacing: 4) {
                                        if entry.canOpenDigitalReader {
                                            Button {
                                                activeDigitalReaderEntry = entry
                                            } label: {
                                                Label("Lire", systemImage: "book.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 5)
                                                    .background(Capsule().fill(LivriaPalette.primary))
                                                    .foregroundStyle(.white)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        if entry.canOpenAudioPlayer {
                                            Button {
                                                activeAudioPlayerEntry = entry
                                            } label: {
                                                Label("Audio", systemImage: "headphones")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 5)
                                                    .background(Capsule().fill(LivriaPalette.coral))
                                                    .foregroundStyle(.white)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else {
                                    Text("📕 Broché détenu")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(LivriaPalette.inkMuted)
                                        .padding(.vertical, 3)
                                }
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.background))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LivriaPalette.border, lineWidth: 1))
                        }
                    }
                }
            }

            NavigationLink {
                LivriaMyLibraryView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical.circle.fill")
                    Text("Ouvrir Ma bibliothèque & Lecteur Numérique / Audio")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [LivriaPalette.primary, LivriaPalette.coral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .livriaCard(padding: 15)
    }

    private func libraryMiniStatPill(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13.5, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
    }

    // MARK: - Suivi Natif Viple Delivery Intégré depuis le Profil (Sans ouvrir Safari)

    private var vipleDeliveryDirectTrackingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "truck.box.badge.clock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LivriaPalette.primary)
                Text("Suivi Viple Delivery (En direct)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                NavigationLink {
                    OrdersView()
                } label: {
                    Text("Mes commandes (\(store.orders.count)) →")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                }
            }

            HStack(spacing: 8) {
                TextField("N° commande (#LIV-...) ou suivi (1Z..., VD-...)", text: $quickTrackingCode)
                    .font(.system(size: 12, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                Button {
                    Task {
                        await store.trackParcelByCodeInApp(quickTrackingCode)
                    }
                } label: {
                    Label("Suivre", systemImage: "location.fill")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.primary))
                        .foregroundStyle(.white)
                }
                .disabled(quickTrackingCode.trimmingCharacters(in: .whitespaces).isEmpty || store.isTrackingLoading)
            }
        }
        .livriaCard(padding: 14)
    }

    // MARK: - Carte Coups de Cœur ❤️ & Journal de Lecture Personnel

    private var favoritesAndReadingStatsCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(LivriaPalette.coral)
                    Text("\(store.favoriteBookIds.count)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }
                Text("Coups de cœur")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LivriaPalette.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.background))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(LivriaPalette.primary)
                    Text("\(store.recentlyViewedBookIds.count)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }
                Text("Consultés")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LivriaPalette.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.background))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "book.pages.fill")
                        .foregroundStyle(LivriaPalette.gold)
                    Text("\(store.totalReadingMinutes)m")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }
                Text("Temps de lecture")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LivriaPalette.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.background))
        }
        .livriaCard(padding: 12)
    }

    private var advancedSettingsEntryCard: some View {
        Button {
            isShowingAdvancedSettingsSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LivriaPalette.primarySoft)
                        .frame(width: 38, height: 38)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Réglages avancés, Confidentialité RGPD & Cache")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Notifications Viple Delivery, haptique, économiseur de données, export RGPD & diagnostic")
                        .font(.system(size: 11.5))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(LivriaPalette.primary)
            }
            .livriaCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Centre de Réglages Avancés, Confidentialité RGPD, Cache & Diagnostics (LivriaAdvancedSettingsSheet)

public struct LivriaAdvancedSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel
    @State private var prefs: LivriaUserPreferences = LivriaUserPreferences()
    @State private var exportedPrivacyJson: String? = nil
    @State private var isExportingPrivacy: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Notifications & Alertes Viple Delivery") {
                    Toggle("Suivi d'expédition Viple Delivery & UPS", isOn: $prefs.notifyOrders)
                    Toggle("Alertes baisses de prix (Coups de cœur)", isOn: $prefs.notifyPriceDrops)
                    Toggle("Alertes retour en stock (Occasion & Neuf)", isOn: $prefs.notifyStockAlerts)
                    Toggle("Activité Clubs de lecture & Troc", isOn: $prefs.notifyBookClubs)
                }

                Section("Confort, Accessibilité & Économie de Données") {
                    Toggle("Retour haptique (vibrations douces)", isOn: $prefs.hapticFeedback)
                    Toggle("Mode économiseur de données", isOn: $prefs.dataSaverMode)
                    Toggle("Masquer les spoilers par défaut", isOn: $prefs.hideSpoilersDefault)
                    Toggle("Contraste renforcé des cartes", isOn: $prefs.highContrastCards)
                    Toggle("Protection Face ID / Touch ID au lancement", isOn: $prefs.biometricLockEnabled)
                }

                Section("Historique Local & Cache Réseau") {
                    Button {
                        store.clearRecentlyViewedBooks()
                    } label: {
                        Label("Effacer les livres récemment consultés (\(store.recentlyViewedBookIds.count))", systemImage: "clock.badge.xmark")
                    }

                    Button {
                        store.clearRecentSearches()
                        store.showToast("Recherches récentes effacées.")
                    } label: {
                        Label("Effacer l'historique de recherche (\(store.recentSearchQueries.count))", systemImage: "magnifyingglass.circle")
                    }

                    Button(role: .destructive) {
                        store.clearLocalCache()
                    } label: {
                        Label("Purger le cache réseau et les images temporaires", systemImage: "trash.slash.fill")
                    }
                }

                Section("Confidentialité RGPD & Portabilité") {
                    Button {
                        Task {
                            isExportingPrivacy = true
                            let json = try? await LivriaAPIClient.shared.exportPrivacyData(
                                userId: store.currentUser?.id,
                                email: store.currentUser?.email
                            )
                            exportedPrivacyJson = json
                            isExportingPrivacy = false
                        }
                    } label: {
                        HStack {
                            Label("Générer mon archive RGPD (JSON)", systemImage: "lock.doc.fill")
                            Spacer()
                            if isExportingPrivacy {
                                ProgressView()
                            }
                        }
                    }

                    if let exported = exportedPrivacyJson {
                        ShareLink(item: exported, preview: SharePreview("Export RGPD Viple Live ID")) {
                            Label("Télécharger / Partager mon archive RGPD", systemImage: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(LivriaPalette.primary)
                        }
                    }
                }

                Section("Diagnostic Serveur & Passerelle Viple Delivery") {
                    Button {
                        Task {
                            await store.runDiagnosticsCheck()
                        }
                    } label: {
                        Label("Tester la connexion au serveur Livria & Viple Delivery", systemImage: "waveform.path.ecg")
                    }

                    if let diag = store.lastDiagnosticsPing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Service : \(diag.service) (API \(diag.apiVersion))")
                                .font(.system(size: 12.5, weight: .bold))
                            Text("Latence base de données : \(diag.dbLatencyMs ?? 1) ms")
                                .font(.system(size: 12))
                            Text("Passerelle Viple Delivery : \(diag.vipleDeliveryGatewayReachable == true ? "Opérationnelle ✓" : "Mode secours local")")
                                .font(.system(size: 12))
                                .foregroundStyle(diag.vipleDeliveryGatewayReachable == true ? .green : .orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Réglages & RGPD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        Task {
                            await store.saveAndSyncPreferences(prefs)
                            store.showToast("Réglages enregistrés et synchronisés.")
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                prefs = store.userPreferences
            }
        }
    }
}

// MARK: - Vue Complète « Ma bibliothèque » (LivriaMyLibraryView)

public struct LivriaMyLibraryView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @State private var searchText: String = ""
    @State private var selectedFilter: String = "ALL"
    @State private var activeDigitalReaderEntry: LivriaShelfEntry? = nil
    @State private var activeAudioPlayerEntry: LivriaShelfEntry? = nil
    @State private var selectedCatalogBookForDetail: LivriaBook? = nil

    public init() {}

    private var filteredShelf: [LivriaShelfEntry] {
        store.shelf.filter { entry in
            let matchesFilter: Bool
            switch selectedFilter {
            case "DIGITAL_AUDIO":
                matchesFilter = entry.ownsDigital || entry.ownsAudio
            case "READING":
                matchesFilter = entry.status == "Reading"
            case "WANT":
                matchesFilter = entry.status == "WantToRead"
            case "READ":
                matchesFilter = entry.status == "Read"
            case "FAV":
                matchesFilter = entry.isCoupDeCoeur || store.isFavoriteBook(entry.bookId)
            default:
                matchesFilter = true
            }
            guard matchesFilter else { return false }

            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty { return true }
            return entry.title.lowercased().contains(q)
                || entry.author.lowercased().contains(q)
                || entry.genre.lowercased().contains(q)
                || entry.format.lowercased().contains(q)
        }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                headerBannerCard
                searchAndFilterBar

                if !store.isAuthenticated {
                    guestLibraryNoticeCard
                } else if filteredShelf.isEmpty {
                    emptyLibraryStateCard
                } else {
                    ForEach(filteredShelf) { entry in
                        libraryEntryCard(entry)
                    }
                }
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Ma bibliothèque")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCatalogBookForDetail) { b in
            BookDetailView(book: b)
        }
        .sheet(item: $activeDigitalReaderEntry) { entry in
            LivriaDigitalReaderSheet(entry: entry)
                .environmentObject(store)
        }
        .sheet(item: $activeAudioPlayerEntry) { entry in
            LivriaAudioPlayerSheet(entry: entry)
                .environmentObject(store)
        }
        .refreshable {
            await store.refreshBootstrap()
        }
    }

    private var headerBannerCard: some View {
        let total = store.shelf.count
        let digitalCount = store.shelf.filter(\.ownsDigital).count
        let audioCount = store.shelf.filter(\.ownsAudio).count
        let readCount = store.shelf.filter { $0.status == "Read" }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ma bibliothèque personnelle")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Liseuse numérique & Lecteur audio activés uniquement pour vos ouvrages détenus en Numérique ou Audio")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
            }

            HStack(spacing: 8) {
                bannerStatChip(title: "Total", value: "\(total)")
                bannerStatChip(title: "Numérique", value: "\(digitalCount)")
                bannerStatChip(title: "Audio", value: "\(audioCount)")
                bannerStatChip(title: "Lus", value: "\(readCount)")
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LivriaPalette.heroGradient))
    }

    private func bannerStatChip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.16)))
    }

    private var searchAndFilterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(LivriaPalette.inkMuted)
                TextField("Rechercher un titre, auteur ou format dans ma bibliothèque...", text: $searchText)
                    .font(.system(size: 13.5))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                }
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterTabPill(id: "ALL", label: "Tous (\(store.shelf.count))", icon: "books.vertical.fill")
                    filterTabPill(
                        id: "DIGITAL_AUDIO",
                        label: "Numérique & Audio (\(store.shelf.filter { $0.ownsDigital || $0.ownsAudio }.count))",
                        icon: "headphones"
                    )
                    filterTabPill(
                        id: "READING",
                        label: "En cours (\(store.shelf.filter { $0.status == "Reading" }.count))",
                        icon: "book.fill"
                    )
                    filterTabPill(
                        id: "WANT",
                        label: "À lire (\(store.shelf.filter { $0.status == "WantToRead" }.count))",
                        icon: "bookmark.fill"
                    )
                    filterTabPill(
                        id: "READ",
                        label: "Terminés (\(store.shelf.filter { $0.status == "Read" }.count))",
                        icon: "checkmark.seal.fill"
                    )
                    filterTabPill(
                        id: "FAV",
                        label: "Coups de cœur (\(store.shelf.filter { $0.isCoupDeCoeur || store.isFavoriteBook($0.bookId) }.count))",
                        icon: "heart.fill"
                    )
                }
            }
        }
    }

    private func filterTabPill(id: String, label: String, icon: String) -> some View {
        let isSelected = selectedFilter == id
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                selectedFilter = id
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? LivriaPalette.primary : LivriaPalette.surface))
            .foregroundStyle(isSelected ? .white : LivriaPalette.ink)
            .overlay(Capsule().stroke(isSelected ? LivriaPalette.primary : LivriaPalette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var guestLibraryNoticeCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.book.closed.fill")
                .font(.system(size: 34))
                .foregroundStyle(LivriaPalette.primary)
            Text("Connectez-vous pour accéder à Ma bibliothèque")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
            Text("Retrouvez tous vos livres achetés sur Livria Store, vos étagères de lecture ainsi que votre liseuse numérique et votre lecteur audio.")
                .font(.system(size: 13))
                .foregroundStyle(LivriaPalette.inkMuted)
                .multilineTextAlignment(.center)
            Button {
                store.isShowingAuthSheet = true
            } label: {
                Label("Se connecter avec Viple Live ID", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(LivriaPalette.primary))
                    .foregroundStyle(.white)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .livriaCard()
    }

    private var emptyLibraryStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 34))
                .foregroundStyle(LivriaPalette.primary)
            Text("Aucun livre dans ce filtre")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
            Text("Tous les livres que vous achetez sur Livria Store ou ajoutez à vos étagères apparaissent ici. Achetez un ouvrage au format Numérique ou Audio pour débloquer sa liseuse ou son lecteur audio intégré.")
                .font(.system(size: 12.5))
                .foregroundStyle(LivriaPalette.inkMuted)
                .multilineTextAlignment(.center)
            Button {
                store.selectedMainTab = 1
            } label: {
                Label("Explorer la Boutique Livria", systemImage: "bag.fill")
                    .font(.system(size: 13.5, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(LivriaPalette.primary))
                    .foregroundStyle(.white)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .livriaCard()
    }

    private func libraryEntryCard(_ entry: LivriaShelfEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Button {
                    if let catBook = store.books.first(where: { $0.id == entry.bookId }) {
                        selectedCatalogBookForDetail = catBook
                    }
                } label: {
                    LivriaBookCoverView(
                        coverUrl: entry.coverUrl,
                        title: entry.title,
                        width: 86,
                        height: 126,
                        cornerRadius: 12
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(LivriaPalette.ink)
                                .lineLimit(2)
                            Text(entry.author)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                        Spacer()
                        Button {
                            let nextRating = entry.rating >= 5 ? 4 : 5
                            Task {
                                await store.updateShelf(bookId: entry.bookId, rating: nextRating)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: entry.isCoupDeCoeur ? "heart.fill" : "heart")
                                Text(entry.isCoupDeCoeur ? "Coup de cœur" : "Favori")
                            }
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(entry.isCoupDeCoeur ? LivriaPalette.coral.opacity(0.15) : LivriaPalette.background))
                            .foregroundStyle(entry.isCoupDeCoeur ? LivriaPalette.coral : LivriaPalette.inkMuted)
                        }
                        .buttonStyle(.plain)
                    }

                    // Badges des formats détenus par l'utilisateur
                    HStack(spacing: 6) {
                        if entry.ownsDigital {
                            ownedFormatBadge(label: "📖 Numérique détenu", color: LivriaPalette.primary)
                        }
                        if entry.ownsAudio {
                            ownedFormatBadge(label: "🎧 Audio détenu", color: LivriaPalette.coral)
                        }
                        if entry.ownsPhysical || (!entry.ownsDigital && !entry.ownsAudio) {
                            ownedFormatBadge(label: "📕 Broché", color: LivriaPalette.mint)
                        }
                    }

                    // Sélecteur de statut d'étagère (À lire / En cours / Terminé)
                    HStack(spacing: 6) {
                        shelfStatusButton(entry: entry, statusKey: "WantToRead", label: "À lire")
                        shelfStatusButton(entry: entry, statusKey: "Reading", label: "En cours")
                        shelfStatusButton(entry: entry, statusKey: "Read", label: "Terminé")
                    }

                    // Étoiles + Progression
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                Task {
                                    await store.updateShelf(bookId: entry.bookId, rating: star)
                                }
                            } label: {
                                Image(systemName: star <= entry.rating ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundStyle(LivriaPalette.gold)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text("Progression : \(Int(entry.progress)) %")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LivriaPalette.primary)
                    }
                }
            }

            // Barre de progression de lecture
            ProgressView(value: min(max(entry.progress, 0), 100), total: 100)
                .tint(LivriaPalette.primary)

            // LECTEUR NUMÉRIQUE & LECTEUR AUDIO : UNIQUEMENT POUR LES LIVRES DÉTENUS AU FORMAT NUMÉRIQUE / AUDIO
            if entry.canOpenDigitalReader || entry.canOpenAudioPlayer {
                HStack(spacing: 10) {
                    if entry.canOpenDigitalReader {
                        Button {
                            activeDigitalReaderEntry = entry
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "book.pages.fill")
                                Text("Lire (Liseuse numérique)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                LinearGradient(
                                    colors: [LivriaPalette.primary, LivriaPalette.primaryDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if entry.canOpenAudioPlayer {
                        Button {
                            activeAudioPlayerEntry = entry
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "headphones")
                                Text("Écouter (Livre audio)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                LinearGradient(
                                    colors: [LivriaPalette.coral, LivriaPalette.usedAmber],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                    Text("Exemplaire détenu au format Broché uniquement (lecteur numérique/audio réservé aux éditions Numérique & Audio).")
                        .font(.system(size: 11))
                        .foregroundStyle(LivriaPalette.inkMuted)
                    Spacer()
                    if let catBook = store.books.first(where: { $0.id == entry.bookId }) {
                        Button {
                            selectedCatalogBookForDetail = catBook
                        } label: {
                            Text("Voir la fiche")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LivriaPalette.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            if !entry.isPurchased {
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        Task {
                            await store.removeFromShelf(bookId: entry.bookId)
                        }
                    } label: {
                        Label("Retirer de mes étagères", systemImage: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .livriaCard(padding: 14)
    }

    private func ownedFormatBadge(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundStyle(color)
    }

    private func shelfStatusButton(entry: LivriaShelfEntry, statusKey: String, label: String) -> some View {
        let isSelected = entry.status == statusKey
        return Button {
            Task {
                await store.updateShelf(
                    bookId: entry.bookId,
                    status: statusKey,
                    progress: statusKey == "Read" ? 100 : entry.progress
                )
            }
        } label: {
            Text(label)
                .font(.system(size: 10.5, weight: .bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(isSelected ? LivriaPalette.primary : LivriaPalette.background))
                .foregroundStyle(isSelected ? .white : LivriaPalette.ink)
                .overlay(Capsule().stroke(isSelected ? LivriaPalette.primary : LivriaPalette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Liseuse Numérique Native « Livria Digital Reader » (Uniquement pour les livres détenus au format Numérique)

public struct LivriaDigitalReaderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel
    @StateObject private var ambientPlayer = LivriaAmbientSoundPlayer()

    public let entry: LivriaShelfEntry

    @State private var isLoading: Bool = true
    @State private var accessDeniedMessage: String? = nil
    @State private var chapters: [LivriaBookChapter] = []
    @State private var currentChapterIndex: Int = 0
    @State private var readerTheme: String = "light" // light, sepia, dark
    @State private var fontSize: CGFloat = 18
    @State private var useDyslexicFont: Bool = false
    @State private var useBionicReading: Bool = false
    @State private var isAmbientPlaying: Bool = false

    public init(entry: LivriaShelfEntry) {
        self.entry = entry
    }

    private var backgroundColor: Color {
        switch readerTheme {
        case "sepia": return Color(red: 0.98, green: 0.94, blue: 0.86)
        case "dark": return Color(red: 0.09, green: 0.09, blue: 0.13)
        default: return Color.white
        }
    }

    private var textColor: Color {
        switch readerTheme {
        case "sepia": return Color(red: 0.27, green: 0.14, blue: 0.04)
        case "dark": return Color(red: 0.92, green: 0.92, blue: 0.96)
        default: return LivriaPalette.ink
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                readerToolbarHeader

                if !entry.canOpenDigitalReader {
                    lockedFormatStateView(
                        title: "Édition Numérique non détenue",
                        message: "La liseuse numérique est réservée aux livres que vous détenez au format Numérique."
                    )
                } else if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Ouverture de votre édition numérique « \(entry.title) »...")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = accessDeniedMessage {
                    lockedFormatStateView(title: "Accès restreint", message: err)
                } else if chapters.isEmpty {
                    lockedFormatStateView(title: "Chapitres indisponibles", message: "Le contenu numérique de cet ouvrage n'a pas pu être chargé.")
                } else {
                    let activeChapter = chapters[min(max(currentChapterIndex, 0), chapters.count - 1)]

                    ScrollView(showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(activeChapter.title)
                                .font(.system(size: fontSize + 4, weight: .black, design: useDyslexicFont ? .rounded : .serif))
                                .foregroundStyle(textColor)

                            Divider()

                            if useBionicReading {
                                Text(makeBionicAttributedString(from: activeChapter.content))
                                    .font(.system(size: fontSize, design: useDyslexicFont ? .rounded : .serif))
                                    .foregroundStyle(textColor)
                                    .lineSpacing(7)
                            } else {
                                Text(activeChapter.content)
                                    .font(.system(size: fontSize, weight: useDyslexicFont ? .medium : .regular, design: useDyslexicFont ? .rounded : .serif))
                                    .foregroundStyle(textColor)
                                    .lineSpacing(7)
                            }
                        }
                        .padding(22)
                    }
                    .background(backgroundColor)

                    readerBottomNavigationBar
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadReaderChapters()
            }
            .onDisappear {
                ambientPlayer.stop()
            }
        }
    }

    private var readerToolbarHeader: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("📖 \(entry.title)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(entry.author) • Édition Numérique Livria")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Quitter")
                        .font(.system(size: 12.5, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                        .foregroundStyle(.white)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    themePill(id: "light", label: "Clair")
                    themePill(id: "sepia", label: "Sépia")
                    themePill(id: "dark", label: "Sombre")

                    Button {
                        fontSize = max(14, fontSize - 2)
                    } label: {
                        Text("A-")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.16)))
                            .foregroundStyle(.white)
                    }

                    Button {
                        fontSize = min(30, fontSize + 2)
                    } label: {
                        Text("A+")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.16)))
                            .foregroundStyle(.white)
                    }

                    Button {
                        useDyslexicFont.toggle()
                    } label: {
                        Text(useDyslexicFont ? "Dyslexie : ON" : "Police Dyslexie")
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(useDyslexicFont ? LivriaPalette.primary : Color.white.opacity(0.16)))
                            .foregroundStyle(.white)
                    }

                    Button {
                        useBionicReading.toggle()
                    } label: {
                        Text(useBionicReading ? "Bionic : ON" : "Lecture Bionic")
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(useBionicReading ? LivriaPalette.coral : Color.white.opacity(0.16)))
                            .foregroundStyle(.white)
                    }

                    Button {
                        let preset = entry.ambientSoundtrack ?? "rain"
                        ambientPlayer.toggle(preset: preset)
                        isAmbientPlaying = ambientPlayer.activePreset != nil
                    } label: {
                        Text(isAmbientPlaying ? "🌧️ Ambiance ON" : "🌧️ Ambiance")
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(isAmbientPlaying ? LivriaPalette.mint : Color.white.opacity(0.16)))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.11, blue: 0.29))
    }

    private func themePill(id: String, label: String) -> some View {
        let isSelected = readerTheme == id
        return Button {
            readerTheme = id
        } label: {
            Text(label)
                .font(.system(size: 11.5, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.16)))
                .foregroundStyle(isSelected ? Color(red: 0.12, green: 0.11, blue: 0.29) : .white)
        }
    }

    private var readerBottomNavigationBar: some View {
        HStack {
            Button {
                if currentChapterIndex > 0 {
                    currentChapterIndex -= 1
                    syncChapterProgress()
                }
            } label: {
                Label("Précédent", systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
            }
            .disabled(currentChapterIndex <= 0)

            Spacer()

            Text("Chapitre \(currentChapterIndex + 1) / \(max(1, chapters.count))")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            Spacer()

            Button {
                if currentChapterIndex < chapters.count - 1 {
                    currentChapterIndex += 1
                    syncChapterProgress()
                } else {
                    Task {
                        await store.updateShelf(bookId: entry.bookId, status: "Read", progress: 100)
                        store.showToast("Bravo ! Vous avez terminé « \(entry.title) » (+30 XP).")
                    }
                }
            } label: {
                Label(currentChapterIndex < chapters.count - 1 ? "Suivant" : "Terminer", systemImage: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(LivriaPalette.surface)
        .overlay(Divider(), alignment: .top)
    }

    private func lockedFormatStateView(title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 38))
                .foregroundStyle(LivriaPalette.coral)
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(LivriaPalette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadReaderChapters() async {
        guard entry.canOpenDigitalReader else {
            isLoading = false
            return
        }
        isLoading = true
        let response = await store.fetchBookReaderContent(bookId: entry.bookId)
        isLoading = false
        guard let response else {
            accessDeniedMessage = "Impossible de récupérer le contenu numérique."
            return
        }
        if !response.ok || response.ownsDigital == false {
            accessDeniedMessage = response.error ?? "Vous ne détenez pas cet ouvrage au format Numérique."
            return
        }
        self.chapters = response.chapters ?? []
        if !self.chapters.isEmpty && entry.progress > 0 && entry.progress < 100 {
            let estimatedIdx = Int((entry.progress / 100.0) * Double(self.chapters.count - 1))
            self.currentChapterIndex = min(max(0, estimatedIdx), self.chapters.count - 1)
        }
        syncChapterProgress()
    }

    private func syncChapterProgress() {
        guard !chapters.isEmpty else { return }
        let pct = Double(currentChapterIndex + 1) / Double(chapters.count) * 100.0
        Task {
            await store.updateShelf(
                bookId: entry.bookId,
                status: pct >= 100 ? "Read" : "Reading",
                progress: min(100, pct.rounded())
            )
        }
    }

    private func makeBionicAttributedString(from text: String) -> AttributedString {
        var result = AttributedString()
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for (idx, word) in words.enumerated() {
            if word.isEmpty { continue }
            let prefixLen = max(1, word.count / 2)
            let boldPart = String(word.prefix(prefixLen))
            let regularPart = String(word.dropFirst(prefixLen))

            var attrBold = AttributedString(boldPart)
            attrBold.font = .system(size: fontSize, weight: .black, design: useDyslexicFont ? .rounded : .serif)
            let attrReg = AttributedString(regularPart + (idx < words.count - 1 ? " " : ""))
            result.append(attrBold)
            result.append(attrReg)
        }
        return result
    }
}

// MARK: - Lecteur Livre Audio Natif « Livria Audio Player » (Uniquement pour les livres détenus au format Audio)

@MainActor
public final class LivriaBookAudioPlayerEngine: NSObject, ObservableObject {
    @Published public var isPlaying: Bool = false
    @Published public var playbackRate: Float = 1.0
    @Published public var elapsedSeconds: Int = 0
    @Published public var totalDurationSeconds: Int = 210
    @Published public var sleepTimerRemainingMinutes: Int = 0

    private let synthesizer = AVSpeechSynthesizer()
    private var avPlayer: AVPlayer?
    private var tickTimer: Timer?
    private var activeText: String = ""

    public override init() {
        super.init()
    }

    public func loadChapter(text: String, durationSeconds: Int, remoteAudioUrl: String?) {
        stop()
        self.activeText = text
        self.totalDurationSeconds = max(60, durationSeconds)
        self.elapsedSeconds = 0

        if let remoteAudioUrl,
           let url = LivriaURLResolver.resolve(remoteAudioUrl),
           (url.pathExtension.lowercased() == "mp3" || url.pathExtension.lowercased() == "m4a" || url.pathExtension.lowercased() == "wav") {
            self.avPlayer = AVPlayer(url: url)
        } else {
            self.avPlayer = nil
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        if let player = avPlayer {
            player.playImmediately(atRate: playbackRate)
            isPlaying = true
        } else {
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
            } else {
                synthesizer.stopSpeaking(at: .immediate)
                let utterance = AVSpeechUtterance(string: activeText)
                utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
                let mappedRate = AVSpeechUtteranceDefaultSpeechRate * playbackRate
                utterance.rate = min(max(AVSpeechUtteranceMinimumSpeechRate, mappedRate), AVSpeechUtteranceMaximumSpeechRate)
                synthesizer.speak(utterance)
            }
            isPlaying = true
        }
        startTickTimer()
    }

    public func pause() {
        if let player = avPlayer {
            player.pause()
        } else if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
        isPlaying = false
        tickTimer?.invalidate()
    }

    public func skip(seconds delta: Int) {
        elapsedSeconds = min(max(0, elapsedSeconds + delta), totalDurationSeconds)
        if let player = avPlayer {
            let target = CMTime(seconds: Double(elapsedSeconds), preferredTimescale: 600)
            player.seek(to: target)
        }
    }

    public func setSpeed(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            if let player = avPlayer {
                player.rate = rate
            } else {
                synthesizer.stopSpeaking(at: .immediate)
                play()
            }
        }
    }

    public func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        avPlayer?.pause()
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isPlaying = false
    }

    private func startTickTimer() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                if self.elapsedSeconds < self.totalDurationSeconds {
                    self.elapsedSeconds += 1
                } else {
                    self.pause()
                }
            }
        }
    }
}

public struct LivriaAudioPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel
    @StateObject private var audioEngine = LivriaBookAudioPlayerEngine()
    @StateObject private var ambientPlayer = LivriaAmbientSoundPlayer()

    public let entry: LivriaShelfEntry

    @State private var isLoading: Bool = true
    @State private var accessDeniedMessage: String? = nil
    @State private var chapters: [LivriaBookChapter] = []
    @State private var remoteStreamUrl: String? = nil
    @State private var currentChapterIndex: Int = 0
    @State private var selectedSleepMinutes: Int = 0
    @State private var selectedAmbient: String = "none"

    public init(entry: LivriaShelfEntry) {
        self.entry = entry
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if !entry.canOpenAudioPlayer {
                    VStack(spacing: 14) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(LivriaPalette.coral)
                        Text("Édition Audio non détenue")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Le lecteur livre audio est réservé aux ouvrages que vous détenez au format Audio.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(LivriaPalette.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Chargement de votre livre audio « \(entry.title) »...")
                            .font(.system(size: 13.5))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    .padding(40)
                } else if let err = accessDeniedMessage {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)
                        Text(err)
                            .font(.system(size: 14))
                            .foregroundStyle(LivriaPalette.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    VStack(spacing: 18) {
                        LivriaBookCoverView(
                            coverUrl: entry.coverUrl,
                            title: entry.title,
                            width: 176,
                            height: 254,
                            cornerRadius: 18
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)

                        VStack(spacing: 4) {
                            Text(entry.title)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(LivriaPalette.ink)
                                .multilineTextAlignment(.center)
                            Text(entry.author)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LivriaPalette.inkMuted)
                            if !chapters.isEmpty {
                                Text(chapters[min(currentChapterIndex, chapters.count - 1)].title)
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(LivriaPalette.primary)
                                    .padding(.top, 2)
                            }
                        }

                        // Barre de temps audio
                        VStack(spacing: 6) {
                            ProgressView(
                                value: Double(audioEngine.elapsedSeconds),
                                total: Double(max(1, audioEngine.totalDurationSeconds))
                            )
                            .tint(LivriaPalette.coral)

                            HStack {
                                Text(formatTime(audioEngine.elapsedSeconds))
                                Spacer()
                                Text("-\(formatTime(max(0, audioEngine.totalDurationSeconds - audioEngine.elapsedSeconds)))")
                            }
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(LivriaPalette.inkMuted)
                        }
                        .padding(.horizontal, 8)

                        // Commandes de lecture Audio
                        HStack(spacing: 24) {
                            Button {
                                if currentChapterIndex > 0 {
                                    selectChapter(currentChapterIndex - 1, autoPlay: true)
                                }
                            } label: {
                                Image(systemName: "backward.end.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(currentChapterIndex > 0 ? LivriaPalette.ink : LivriaPalette.inkMuted.opacity(0.4))
                            }
                            .disabled(currentChapterIndex <= 0)

                            Button {
                                audioEngine.skip(seconds: -15)
                            } label: {
                                Image(systemName: "gobackward.15")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                            }

                            Button {
                                audioEngine.togglePlayPause()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [LivriaPalette.coral, LivriaPalette.primary], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 68, height: 68)
                                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 26, weight: .black))
                                        .foregroundStyle(.white)
                                }
                            }

                            Button {
                                audioEngine.skip(seconds: 15)
                            } label: {
                                Image(systemName: "goforward.15")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                            }

                            Button {
                                if currentChapterIndex < chapters.count - 1 {
                                    selectChapter(currentChapterIndex + 1, autoPlay: true)
                                }
                            } label: {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(currentChapterIndex < chapters.count - 1 ? LivriaPalette.ink : LivriaPalette.inkMuted.opacity(0.4))
                            }
                            .disabled(currentChapterIndex >= chapters.count - 1)
                        }

                        // Vitesse, Minuterie de sommeil & Ambiance
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("⚡ Vitesse d'écoute :")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                                Spacer()
                                ForEach([Float(0.75), Float(1.0), Float(1.25), Float(1.5), Float(2.0)], id: \.self) { spd in
                                    Button {
                                        audioEngine.setSpeed(spd)
                                    } label: {
                                        Text(String(format: "%gx", spd))
                                            .font(.system(size: 11.5, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(audioEngine.playbackRate == spd ? LivriaPalette.primary : LivriaPalette.background))
                                            .foregroundStyle(audioEngine.playbackRate == spd ? .white : LivriaPalette.ink)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            HStack {
                                Text("⏱️ Minuterie de sommeil :")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                                Spacer()
                                Picker("Minuterie", selection: $selectedSleepMinutes) {
                                    Text("Désactivée").tag(0)
                                    Text("15 min").tag(15)
                                    Text("30 min").tag(30)
                                    Text("45 min").tag(45)
                                    Text("60 min").tag(60)
                                }
                                .pickerStyle(.menu)
                            }

                            HStack {
                                Text("🎧 Fond sonore :")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                                Spacer()
                                Picker("Ambiance", selection: $selectedAmbient) {
                                    Text("Silencieux").tag("none")
                                    Text("🌧️ Pluie douce").tag("rain")
                                    Text("🔥 Cheminée").tag("fire")
                                    Text("☕ Café littéraire").tag("cafe")
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedAmbient) { _, newValue in
                                    if newValue == "none" {
                                        ambientPlayer.stop()
                                    } else {
                                        ambientPlayer.toggle(preset: newValue)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(LivriaPalette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LivriaPalette.border, lineWidth: 1))

                        // Liste des chapitres audio
                        if !chapters.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Chapitres de l'édition audio (\(chapters.count))")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(LivriaPalette.ink)

                                ForEach(Array(chapters.enumerated()), id: \.element.id) { idx, ch in
                                    Button {
                                        selectChapter(idx, autoPlay: true)
                                    } label: {
                                        HStack {
                                            Image(systemName: idx == currentChapterIndex ? "speaker.wave.3.fill" : "play.circle")
                                                .foregroundStyle(idx == currentChapterIndex ? LivriaPalette.coral : LivriaPalette.primary)
                                            Text(ch.title)
                                                .font(.system(size: 13, weight: idx == currentChapterIndex ? .bold : .medium))
                                                .foregroundStyle(LivriaPalette.ink)
                                                .lineLimit(1)
                                            Spacer()
                                            Text(formatTime(ch.durationSeconds))
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(LivriaPalette.inkMuted)
                                        }
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(idx == currentChapterIndex ? LivriaPalette.primarySoft.opacity(0.6) : LivriaPalette.background))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .livriaCard(padding: 14)
                        }
                    }
                    .padding(16)
                }
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Lecteur Audio Livria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .task {
                await loadAudioBookContent()
            }
            .onDisappear {
                audioEngine.stop()
                ambientPlayer.stop()
            }
        }
    }

    private func loadAudioBookContent() async {
        guard entry.canOpenAudioPlayer else {
            isLoading = false
            return
        }
        isLoading = true
        let response = await store.fetchBookReaderContent(bookId: entry.bookId)
        isLoading = false
        guard let response else {
            accessDeniedMessage = "Impossible de charger le livre audio."
            return
        }
        if !response.ok || response.ownsAudio == false {
            accessDeniedMessage = response.error ?? "Vous ne détenez pas cet ouvrage au format Audio."
            return
        }
        self.chapters = response.chapters ?? []
        self.remoteStreamUrl = response.audioStreamUrl
        selectChapter(0, autoPlay: false)
    }

    private func selectChapter(_ index: Int, autoPlay: Bool) {
        guard !chapters.isEmpty else { return }
        let safeIdx = min(max(0, index), chapters.count - 1)
        currentChapterIndex = safeIdx
        let ch = chapters[safeIdx]
        audioEngine.loadChapter(
            text: ch.content,
            durationSeconds: ch.durationSeconds,
            remoteAudioUrl: remoteStreamUrl
        )
        if autoPlay {
            audioEngine.play()
        }
        let pct = Double(safeIdx + 1) / Double(chapters.count) * 100.0
        Task {
            await store.updateShelf(
                bookId: entry.bookId,
                status: pct >= 100 ? "Read" : "Reading",
                progress: min(100, pct.rounded())
            )
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
