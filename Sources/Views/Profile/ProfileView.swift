import SwiftUI

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

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    profileIdentityHeaderCard
                    themePersonalizationStudioCard
                    editProfileAndAddressCard
                    signOutCard
                }
                .padding(16)
            }
            .livriaThemedBackground(selectedThemeId)
            .navigationTitle("Mon Profil Livria")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                populateFieldsFromStore()
            }
        }
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
                        Text(store.currentUser?.authBadgeLabel ?? "Membre Viple Live ID")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.16)))

                    Text("ID Livria : \(store.currentUser?.livriaAccountId ?? "LID-VIPLE")")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(LivriaPalette.goldSoft)
                }
                Spacer()
            }

            if let url = URL(string: "\(LivriaURLResolver.identityWebURL)/compte") {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.Camera.fill")
                        Text("Modifier mon profil & mon avatar Live")
                            .font(.system(size: 13.5, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.up.right.square.fill")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.18)))
                    .foregroundStyle(.white)
                }
            }
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
                    let isSelected = selectedThemeId == opt.id
                    Button {
                        selectedThemeId = opt.id
                        store.currentUser?.themeId = opt.id
                        saveChanges()
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

    private func populateFieldsFromStore() {
        guard let u = store.currentUser else { return }
        displayName = u.displayName
        bio = u.bio
        motto = u.motto
        favoriteGenres = u.favoriteGenres
        yearlyGoal = max(1, u.yearlyGoal)
        selectedThemeId = u.themeId
        firstName = u.firstName
        lastName = u.lastName
        phone = u.phone
        address = u.address
        postalCode = u.postalCode
        city = u.city
    }

    private func saveChanges() {
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
}
