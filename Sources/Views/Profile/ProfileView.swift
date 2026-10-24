import SwiftUI
import PhotosUI

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

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    quickAccessEcosystemCard
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
