import SwiftUI
import AuthenticationServices

// MARK: - Écran d'Authentification Native Viple Live ID (Connexion, Inscription @viplemail.fr / Email Externe, Sign in with Apple & Mode Invité)

public struct VipleLiveAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel

    public enum AuthTab: String, CaseIterable {
        case login = "Se connecter"
        case register = "Créer un compte"
    }

    public enum EmailSignupMode: String, CaseIterable {
        case viplemail = "viplemail"
        case custom = "custom"
    }

    @State private var selectedTab: AuthTab = .login
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""

    // Inscription Viple Live ID (mêmes modalités qu'identity-v2.viple.digital)
    @State private var signupEmailMode: EmailSignupMode = .viplemail
    @State private var viplemailLocalUser: String = ""
    @State private var customExternalEmail: String = ""
    @State private var signupPassword: String = ""
    @State private var signupConfirmPassword: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var displayName: String = ""
    @State private var localValidationError: String? = nil

    // Finalisation d'inscription Sign in with Apple (Nom, Prénom, Pseudo, Adresse @viplemail.fr obligatoire)
    @State private var appleFirstName: String = ""
    @State private var appleLastName: String = ""
    @State private var appleDisplayName: String = ""
    @State private var appleViplemailUser: String = ""

    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.06, blue: 0.28),
                    Color(red: 0.32, green: 0.16, blue: 0.62),
                    LivriaPalette.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    headerBranding
                    if store.pendingAppleOnboardingUserId != nil {
                        applePostSignupOnboardingCard
                    } else {
                        modePickerCard
                        appleSignInCard
                        if selectedTab == .login {
                            loginFormCard
                        } else {
                            registerFormCard
                        }
                        guestContinueCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .onChange(of: store.pendingAppleOnboardingUserId) { _, newValue in
            if newValue != nil {
                appleFirstName = store.pendingAppleSuggestedFirstName
                appleLastName = store.pendingAppleSuggestedLastName
                let suggestedDisplay = "\(store.pendingAppleSuggestedFirstName) \(store.pendingAppleSuggestedLastName)".trimmingCharacters(in: .whitespaces)
                appleDisplayName = suggestedDisplay
                if appleViplemailUser.isEmpty, !suggestedDisplay.isEmpty {
                    let clean = suggestedDisplay
                        .folding(options: .diacriticInsensitive, locale: .current)
                        .lowercased()
                        .replacingOccurrences(of: " ", with: ".")
                        .filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
                    appleViplemailUser = clean
                }
            }
        }
    }

    // MARK: - En-tête Livria Store × Viple Live ID

    private var headerBranding: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button {
                    store.isShowingAuthSheet = false
                    dismiss()
                } label: {
                    Label("Mode Invité", systemImage: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                        .foregroundStyle(.white)
                }
            }

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [LivriaPalette.primary, LivriaPalette.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 82)
                    .shadow(color: LivriaPalette.primary.opacity(0.45), radius: 18, x: 0, y: 8)

                Image(systemName: "bag.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Livria Store")
                .font(.system(size: 34, weight: .black, design: .serif))
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(LivriaPalette.gold)
                Text("Authentification unifiée Viple Live ID")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.16)))
            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))

            Text("Connectez-vous avec votre compte Viple Live ID pour synchroniser vos commandes Neuf & Occasion, vos offres de Troc, Looby+, Viple Delivery et l'Assistance Viple.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var modePickerCard: some View {
        HStack(spacing: 8) {
            ForEach(AuthTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                        localValidationError = nil
                        store.authErrorMessage = nil
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedTab == tab ? LivriaPalette.primary : Color.clear)
                        )
                        .foregroundStyle(selectedTab == tab ? Color.white : LivriaPalette.ink)
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LivriaPalette.cardPaper))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    // MARK: - Sign in with Apple & Finalisation @viplemail.fr

    private var appleSignInCard: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignInResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Connectez-vous ou inscrivez-vous en 1 toucher avec votre compte Apple associé à Viple Live ID.")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(LivriaPalette.inkMuted)
                .multilineTextAlignment(.center)
        }
        .livriaCard(cornerRadius: 20, padding: 16)
    }

    private var applePostSignupOnboardingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.title2)
                    .foregroundStyle(LivriaPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Finalisez votre compte Viple Live ID")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Inscription via Sign in with Apple • Choix de votre adresse @viplemail.fr")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LivriaPalette.primary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "laptopcomputer.and.iphone")
                        .foregroundStyle(LivriaPalette.primary)
                        .font(.system(size: 15, weight: .bold))
                    Text("Pourquoi choisir une adresse @viplemail.fr ? Cet identifiant Viple Live ID vous permet de vous connecter depuis n'importe quel autre appareil non Apple (PC, web, Android), tandis que sur vos appareils Apple votre compte Viple Live ID reste associé à votre compte Apple.")
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.ink)
                }

                Divider()

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "icloud.and.arrow.down.fill")
                        .foregroundStyle(LivriaPalette.coral)
                        .font(.system(size: 15, weight: .bold))
                    Text("Pour rendre votre expérience plus simple et plus rapide, aucun mot de passe ne vous est demandé maintenant. Le jour où vous souhaiterez vous connecter avec votre identifiant @viplemail.fr depuis un autre appareil sans avoir encore créé de mot de passe, entrez simplement votre adresse @viplemail.fr sans mot de passe : un e-mail sera automatiquement envoyé sur votre boîte mail iCloud avec un lien pour créer votre mot de passe.")
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
            }
            .padding(13)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.primarySoft.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LivriaPalette.primary.opacity(0.3), lineWidth: 1))

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Prénom")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LivriaPalette.ink)
                    TextField("Votre prénom", text: $appleFirstName)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nom")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LivriaPalette.ink)
                    TextField("Votre nom", text: $appleLastName)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Pseudo / Nom d'affichage")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivriaPalette.ink)
                TextField("Votre pseudo sur Livria", text: $appleDisplayName)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Choisissez votre identifiant @viplemail.fr (obligatoire)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LivriaPalette.ink)
                HStack(spacing: 6) {
                    TextField("prenom.nom", text: $appleViplemailUser)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                    Text("@viplemail.fr")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.primary))
                }
            }

            errorBanner

            Button {
                submitAppleOnboarding()
            } label: {
                HStack(spacing: 10) {
                    if store.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                    }
                    Text("Valider mon identifiant @viplemail.fr")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
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
            .disabled(store.isLoading)
        }
        .livriaCard(cornerRadius: 22, padding: 20)
    }

    // MARK: - Formulaire de Connexion Viple Live ID

    private var loginFormCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.key.fill")
                    .font(.title2)
                    .foregroundStyle(LivriaPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connexion Viple Live ID")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Utilisez votre adresse @viplemail.fr ou votre e-mail externe lié à Viple Live ID")
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Adresse e-mail Viple Live ID")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LivriaPalette.ink)
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(LivriaPalette.primary)
                    TextField("ex: prenom.nom@viplemail.fr ou email externe", text: $loginEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mot de passe (laissez vide si inscrit avec Apple sans mot de passe)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(LivriaPalette.ink)
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(LivriaPalette.primary)
                    SecureField("Votre mot de passe Viple Live ID", text: $loginPassword)
                }
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))
            }

            if let notice = store.applePasswordSetupNotice, !notice.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "icloud.fill")
                        .font(.title3)
                        .foregroundStyle(LivriaPalette.primary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Vérifiez votre boîte mail iCloud")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(LivriaPalette.ink)
                        Text(notice)
                            .font(.system(size: 12))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primarySoft))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.primary.opacity(0.4), lineWidth: 1))
            }

            errorBanner

            Button {
                Task {
                    await store.signIn(email: loginEmail, password: loginPassword)
                    if store.isAuthenticated {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if store.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    Text("Se connecter avec Viple Live ID")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [LivriaPalette.primary, LivriaPalette.coral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: LivriaPalette.primary.opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .disabled(store.isLoading || loginEmail.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .livriaCard(cornerRadius: 22, padding: 20)
    }

    // MARK: - Formulaire d'Inscription Viple Live ID (@viplemail.fr ou Email Externe)

    private var registerFormCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(LivriaPalette.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inscription Viple Live ID")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Un seul compte pour Livria Store, Livria Social, Viple & Moi et Delivery")
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Choisissez le type d'adresse pour votre compte Viple Live ID :")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LivriaPalette.ink)

                VStack(spacing: 8) {
                    emailModeOptionButton(
                        mode: .viplemail,
                        title: "Créer une adresse @viplemail.fr (Recommandé)",
                        subtitle: "Inclut une boîte Viple Live Mail officielle gratuite",
                        icon: "at.badge.plus"
                    )
                    emailModeOptionButton(
                        mode: .custom,
                        title: "Utiliser mon adresse e-mail externe",
                        subtitle: "Associer votre adresse actuelle (iCloud, Gmail, Outlook...) à Viple Live ID",
                        icon: "envelope.badge.shield.half.filled"
                    )
                }
            }

            if signupEmailMode == .viplemail {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nouvelle adresse @viplemail.fr")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivriaPalette.ink)
                    HStack(spacing: 6) {
                        TextField("prenom.nom", text: $viplemailLocalUser)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                        Text("@viplemail.fr")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.primary))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Votre adresse e-mail externe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivriaPalette.ink)
                    TextField("ex: lecteur@domaine.fr", text: $customExternalEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LivriaPalette.border, lineWidth: 1))
                }
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Prénom")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LivriaPalette.ink)
                    TextField("Prénom", text: $firstName)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nom")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LivriaPalette.ink)
                    TextField("Nom", text: $lastName)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Pseudo / Nom d'affichage sur Livria")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivriaPalette.ink)
                TextField("Ex: Camille Lecture", text: $displayName)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Mot de passe Viple Live ID (6 caractères min.)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivriaPalette.ink)
                SecureField("Mot de passe", text: $signupPassword)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Confirmer le mot de passe")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivriaPalette.ink)
                SecureField("Confirmation", text: $signupConfirmPassword)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            errorBanner

            Button {
                submitSignup()
            } label: {
                HStack(spacing: 10) {
                    if store.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                    }
                    Text("Créer mon compte Viple Live ID")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
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
            .disabled(store.isLoading)
        }
        .livriaCard(cornerRadius: 22, padding: 20)
    }

    private var guestContinueCard: some View {
        Button {
            store.isShowingAuthSheet = false
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cart.badge.clock")
                    .foregroundStyle(LivriaPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continuer sans compte (Checkout Invité)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Achetez vos livres Neuf & Occasion et créez votre compte en 1 clic après paiement")
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

    private func emailModeOptionButton(mode: EmailSignupMode, title: String, subtitle: String, icon: String) -> some View {
        let isSelected = signupEmailMode == mode
        return Button {
            withAnimation {
                signupEmailMode = mode
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : LivriaPalette.primary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(isSelected ? LivriaPalette.primary : LivriaPalette.primarySoft)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.ink)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? LivriaPalette.primary : LivriaPalette.inkMuted)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? LivriaPalette.primarySoft.opacity(0.65) : LivriaPalette.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? LivriaPalette.primary : LivriaPalette.border, lineWidth: isSelected ? 1.8 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let err = localValidationError ?? store.authErrorMessage, !err.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(err)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.10)))
        }
    }

    private func submitSignup() {
        localValidationError = nil
        if signupPassword.count < 6 {
            localValidationError = "Le mot de passe doit comporter au moins 6 caractères."
            return
        }
        if signupPassword != signupConfirmPassword {
            localValidationError = "Les deux mots de passe ne correspondent pas."
            return
        }
        if signupEmailMode == .viplemail && viplemailLocalUser.trimmingCharacters(in: .whitespaces).isEmpty {
            localValidationError = "Veuillez choisir votre identifiant @viplemail.fr."
            return
        }
        if signupEmailMode == .custom && !customExternalEmail.contains("@") {
            localValidationError = "Veuillez saisir une adresse e-mail externe valide."
            return
        }
        let finalDisplay = displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            : displayName

        Task {
            await store.registerAccount(
                emailMode: signupEmailMode.rawValue,
                emailUser: viplemailLocalUser.trimmingCharacters(in: .whitespaces),
                customEmail: customExternalEmail.trimmingCharacters(in: .whitespaces),
                password: signupPassword,
                firstName: firstName,
                lastName: lastName,
                displayName: finalDisplay.isEmpty ? "Membre Viple Live ID" : finalDisplay
            )
            if store.isAuthenticated {
                dismiss()
            }
        }
    }

    private func handleAppleSignInResult(_ result: Result<ASAuthorization, any Error>) {
        localValidationError = nil
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else {
                localValidationError = "Impossible de lire les informations Apple."
                return
            }
            let appleUserId = cred.user
            let email = cred.email
            let givenName = cred.fullName?.givenName
            let familyName = cred.fullName?.familyName
            var tokenString: String? = nil
            if let tokenData = cred.identityToken {
                tokenString = String(data: tokenData, encoding: .utf8)
            }
            Task {
                await store.handleSignInWithApple(
                    appleUserId: appleUserId,
                    identityToken: tokenString,
                    email: email,
                    firstName: givenName,
                    lastName: familyName
                )
                if store.isAuthenticated && store.pendingAppleOnboardingUserId == nil {
                    dismiss()
                }
            }
        case .failure(let error):
            localValidationError = "Connexion Apple annulée ou indisponible (\(error.localizedDescription))."
        }
    }

    private func submitAppleOnboarding() {
        localValidationError = nil
        let cleanFirst = appleFirstName.trimmingCharacters(in: .whitespaces)
        let cleanLast = appleLastName.trimmingCharacters(in: .whitespaces)
        let cleanDisplay = appleDisplayName.trimmingCharacters(in: .whitespaces)
        let cleanUser = appleViplemailUser.trimmingCharacters(in: .whitespaces)
        if cleanFirst.isEmpty || cleanLast.isEmpty {
            localValidationError = "Veuillez renseigner votre nom et votre prénom."
            return
        }
        if cleanDisplay.isEmpty {
            localValidationError = "Veuillez choisir votre pseudo."
            return
        }
        if cleanUser.isEmpty {
            localValidationError = "Veuillez choisir votre identifiant @viplemail.fr."
            return
        }
        Task {
            await store.completeAppleOnboarding(
                firstName: cleanFirst,
                lastName: cleanLast,
                displayName: cleanDisplay,
                vipleMailUser: cleanUser
            )
            if store.isAuthenticated && store.pendingAppleOnboardingUserId == nil {
                dismiss()
            }
        }
    }
}
