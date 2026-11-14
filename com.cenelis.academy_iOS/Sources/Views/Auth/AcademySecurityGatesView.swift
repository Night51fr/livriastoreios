import SwiftUI
import AuthenticationServices
#if canImport(SafariServices)
import SafariServices
#endif

// MARK: - Orchestrateur de Sécurité Institutionnel Cenelis Academy
// 1. Connexion obligatoire (SSO Cenelis Connect / Viple Live ID ou identifiants)
// 2. Contrôle strict d'habilitation Interne ou Externe Cenelis (RBAC AdminGest)
// 3. Acceptation obligatoire des CGU (premier lancement OU modification des CGU)
// 4. Vérification systématique du code PIN Cenelis Connect à CHAQUE lancement via Safari In-App (vraie page web sso.prod.cenelis.com/pin, zéro vue PIN native)

public struct AcademySecurityRootContainerView: View {
    @ObservedObject var vm: AcademyStoreViewModel

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack {
            switch vm.activeSecurityGate {
            case .booting:
                AcademyLaunchSplashView()
                    .transition(.opacity)

            case .loginRequired:
                AcademyMandatoryLoginGateView(vm: vm)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .permissionDenied:
                AcademyPermissionDeniedGateView(vm: vm)
                    .transition(.opacity)

            case .cguAcceptanceRequired:
                AcademyCGUAcceptanceGateView(vm: vm)
                    .transition(.opacity)

            case .pinVerificationRequired:
                AcademyPinLaunchGateView(vm: vm)
                    .transition(.opacity)

            case .unlocked:
                MainAcademyTabView(vm: vm)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: vm.activeSecurityGate)
        .onChange(of: vm.activeSecurityGate) { _, newGate in
            if newGate == .pinVerificationRequired {
                vm.triggerAutoPinIfNeeded()
            }
        }
        #if canImport(SafariServices)
        .fullScreenCover(item: $vm.activePinSafariItem, onDismiss: {
            vm.handlePinSafariDismissedByUser()
        }) { item in
            let viewModel = vm
            CenelisConnectInAppSafariView(url: item.url) {
                viewModel.handlePinSafariDismissedByUser()
            }
            .ignoresSafeArea()
        }
        #endif
    }
}

// MARK: - 1. Écran de Connexion Obligatoire (Zéro Accès Invité)

public struct AcademyMandatoryLoginGateView: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @Environment(\.webAuthenticationSession) private var webAuthSession

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSubmitting: Bool = false

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack {
            AcademyPalette.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // En-tête institutionnel Cenelis Academy
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AcademyPalette.pineSoft)
                                .frame(width: 84, height: 84)
                                .overlay(
                                    Circle()
                                        .strokeBorder(AcademyPalette.pineBorder, lineWidth: 1.5)
                                )
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(AcademyPalette.pine)
                        }

                        AcademyBadge("ACCÈS HABILITÉ OBLIGATOIRE", icon: "lock.shield.fill", style: .copper)

                        Text("Cenelis Academy")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)

                        Text("Connectez-vous avec votre compte professionnel pour accéder aux parcours métiers, procédures opérationnelles et certifications du Groupe Cenelis.")
                            .font(.system(size: 14))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 8)
                    }
                    .padding(.top, 24)

                    // Bandeau d'éligibilité Interne / Externe Cenelis
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AcademyPalette.pine)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Réservé aux permissions internes & externes Cenelis")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.ink)
                            Text("Accès ouvert aux collaborateurs internes Cenelis ainsi qu'aux gestionnaires externes titulaires d'un mandat actif (e.GL1, e.GL2, e.GVN_u) validé dans AdminGest.")
                                .font(.system(size: 12))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                                .lineSpacing(2)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AcademyPalette.pineSoft)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AcademyPalette.pineBorder, lineWidth: 1))
                    )

                    // Bouton principal SSO Cenelis Connect / Viple Live ID (Safari In-App)
                    Button {
                        AcademyHaptics.medium()
                        Task { await startWebSSO() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "safari.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Se connecter avec Cenelis Connect / SSO")
                                .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AcademyPalette.pineSolid)
                                .shadow(color: AcademyPalette.pineSolid.opacity(0.24), radius: 10, y: 5)
                        )
                    }
                    .buttonStyle(SpringPressableButtonStyle())
                    .disabled(isSubmitting)

                    HStack {
                        Rectangle().fill(AcademyPalette.border).frame(height: 1)
                        Text("OU IDENTIFIANTS DIRECTS")
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.inkMuted)
                        Rectangle().fill(AcademyPalette.border).frame(height: 1)
                    }

                    // Formulaire d'identifiants directs
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Identifiant professionnel (@viplemail.fr / @cenelis.com)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                            TextField("prenom.nom@viplemail.fr", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(13)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AcademyPalette.surfaceSubtle)
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mot de passe")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                            SecureField("Votre mot de passe personnel", text: $password)
                                .padding(13)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AcademyPalette.surfaceSubtle)
                                )
                        }

                        if let errorMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AcademyPalette.danger)
                                Text(errorMessage)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(AcademyPalette.danger)
                            }
                            .padding(11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 11).fill(AcademyPalette.dangerSoft))
                        }

                        Button {
                            Task { await submitDirectLogin() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 17, weight: .bold))
                                    Text("Continuer vers la vérification PIN")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AcademyPalette.copperGradient)
                            )
                        }
                        .buttonStyle(SpringPressableButtonStyle())
                        .disabled(isSubmitting || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(AcademyPalette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(AcademyPalette.border, lineWidth: 1))
                    )

                    Text("Groupe Cenelis · Cenelis SA — Authentification sécurisée suivie du contrôle PIN Cenelis Connect à chaque ouverture.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(AcademyPalette.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func submitDirectLogin() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await vm.loginWithPassword(email: email, password: password)
        } catch {
            AcademyHaptics.error()
            errorMessage = error.localizedDescription
        }
    }

    private func startWebSSO() async {
        errorMessage = nil
        do {
            let callbackURL = try await webAuthSession.authenticate(
                using: AcademyAPIClient.shared.ssoStartURL(),
                callback: .customScheme("cenelisacademy"),
                preferredBrowserSession: vm.shouldForceFreshSSOLogin ? .ephemeral : .shared,
                additionalHeaderFields: [:]
            )
            await vm.handleIncomingURL(callbackURL)
        } catch {
            // Annulation volontaire de la feuille SSO par l'utilisateur
        }
    }
}

// MARK: - 2. Écran de Blocage RBAC (Compte Sans Permission Interne ni Externe Cenelis)

public struct AcademyPermissionDeniedGateView: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @State private var isRefreshingRights: Bool = false

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    private var statusDetailText: String {
        switch vm.learner.rbacStatus.lowercased() {
        case "blocked":
            return "Ce compte fait actuellement l'objet d'un blocage ou d'une révocation d'habilitation dans Cenelis AdminGest."
        case "pending":
            return "Votre demande d'habilitation est en attente d'approbation par la Direction dans Cenelis AdminGest."
        case "unavailable":
            return "Le serveur de gouvernance Cenelis est momentanément injoignable. Vérifiez votre connexion Internet puis réessayez."
        default:
            return "Aucune permission interne (Collaborateur / Pôle métier) ni permission externe (mandat e.GL1, e.GL2, e.GVN_u) n'est rattachée à ce compte."
        }
    }

    public var body: some View {
        ZStack {
            AcademyPalette.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AcademyPalette.dangerSoft)
                        .frame(width: 88, height: 88)
                    Image(systemName: "hand.raised.slash.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AcademyPalette.danger)
                }

                AcademyBadge("ACCÈS RESTREINT · HABILITATION REQUISE", icon: "shield.slash.fill", style: .copper)

                Text("Permission Cenelis requise")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
                    .multilineTextAlignment(.center)

                Text("L'application Cenelis Academy est exclusivement accessible aux personnes disposant d'une **permission interne** ou d'une **permission externe** active au sein du Groupe Cenelis.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(AcademyPalette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .foregroundStyle(AcademyPalette.copper)
                        Text(vm.learner.email.isEmpty ? "Compte authentifié" : vm.learner.email)
                            .font(.system(size: 13.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(AcademyPalette.ink)
                    }
                    Divider()
                    Text(statusDetailText)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                        .lineSpacing(2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AcademyPalette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.border, lineWidth: 1))
                )

                VStack(spacing: 12) {
                    Button {
                        AcademyHaptics.selection()
                        Task {
                            isRefreshingRights = true
                            await vm.refreshSessionAndCGU()
                            isRefreshingRights = false
                            vm.triggerAutoPinIfNeeded()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRefreshingRights {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                Text("Vérifier à nouveau mes permissions")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 15).fill(AcademyPalette.pineSolid))
                    }
                    .buttonStyle(SpringPressableButtonStyle())
                    .disabled(isRefreshingRights)

                    Button {
                        vm.logout()
                    } label: {
                        Label("Se déconnecter / Changer de compte", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AcademyPalette.danger)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.dangerSoft))
                    }
                    .buttonStyle(SpringPressableButtonStyle())
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - 3. Écran d'Acceptation Obligatoire des CGU (Premier Lancement ou Modification des CGU)

public struct AcademyCGUAcceptanceGateView: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @State private var hasCheckedConsent: Bool = false
    @State private var isAccepting: Bool = false
    @State private var errorMessage: String? = nil

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let doc = vm.cguDocument
        let isUpdated = vm.isCGUModifiedAfterPriorAcceptance

        ZStack {
            AcademyPalette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // En-tête fixe
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        AcademyBadge(
                            isUpdated
                                ? "MISE À JOUR DES CGU · v\(doc.version)"
                                : "PREMIER LANCEMENT · CGU v\(doc.version)",
                            icon: isUpdated ? "arrow.trianglehead.2.clockwise.rotate.90" : "doc.badge.checkmark",
                            style: isUpdated ? .copper : .pine
                        )
                        Spacer()
                        AcademyBadge(vm.learner.permissionBadgeTitle, icon: "checkmark.shield.fill", style: .pine)
                    }

                    Text(doc.title)
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(AcademyPalette.ink)

                    Text(isUpdated
                         ? "Les Conditions Générales d'Utilisation de Cenelis Academy ont été modifiées (\(doc.effectiveDate)). Veuillez en prendre connaissance et les accepter pour continuer."
                         : doc.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .background(AcademyPalette.surface)
                .overlay(alignment: .bottom) {
                    Divider()
                }

                // Corps intégral des articles CGU
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(doc.sections) { sec in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(sec.number.uppercased())
                                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AcademyPalette.copper)
                                Text(sec.title)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(AcademyPalette.ink)
                                Text(sec.body)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(AcademyPalette.inkSecondary)
                                    .lineSpacing(3.5)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AcademyPalette.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AcademyPalette.border, lineWidth: 1))
                            )
                        }

                        HStack {
                            Image(systemName: "number.square.fill")
                                .foregroundStyle(AcademyPalette.inkMuted)
                            Text("Version \(doc.version) · En vigueur le \(doc.effectiveDate) · Empreinte \(doc.contentHash.prefix(12))")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AcademyPalette.inkMuted)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    }
                    .padding(18)
                }

                // Pied de validation obligatoire
                VStack(spacing: 12) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AcademyPalette.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        AcademyHaptics.selection()
                        hasCheckedConsent.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: hasCheckedConsent ? "checkmark.square.fill" : "square")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(hasCheckedConsent ? AcademyPalette.pine : AcademyPalette.inkMuted)
                            Text("J'ai lu et j'accepte sans réserve les Conditions Générales d'Utilisation de Cenelis Academy (version \(doc.version)) ainsi que mes engagements de confidentialité.")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(AcademyPalette.ink)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 10) {
                        Button {
                            vm.logout()
                        } label: {
                            Text("Refuser")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.danger)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 48)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.dangerSoft))
                        }

                        Button {
                            Task { await confirmAcceptance() }
                        } label: {
                            HStack(spacing: 8) {
                                if isAccepting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text("Accepter et continuer")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(hasCheckedConsent ? AcademyPalette.pineSolid : AcademyPalette.inkMuted.opacity(0.45))
                            )
                        }
                        .disabled(!hasCheckedConsent || isAccepting)
                    }
                }
                .padding(18)
                .background(AcademyPalette.surface)
                .overlay(alignment: .top) {
                    Divider()
                }
            }
        }
    }

    private func confirmAcceptance() async {
        errorMessage = nil
        isAccepting = true
        defer { isAccepting = false }
        do {
            try await vm.acceptCurrentCGU()
        } catch {
            AcademyHaptics.error()
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Feuille de Consultation des CGU Acceptées (depuis Mon Passeport)

public struct AcademyCGUReadOnlySheet: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @Environment(\.dismiss) private var dismiss

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let doc = vm.cguDocument
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        AcademyBadge("CGU ACCEPTÉES · v\(doc.version)", icon: "checkmark.seal.fill", style: .success)
                        Spacer()
                    }
                    Text(doc.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AcademyPalette.inkSecondary)

                    ForEach(doc.sections) { sec in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sec.number.uppercased())
                                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.copper)
                            Text(sec.title)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(AcademyPalette.ink)
                            Text(sec.body)
                                .font(.system(size: 13.5))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                                .lineSpacing(3)
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AcademyPalette.surface)
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AcademyPalette.border, lineWidth: 1))
                        )
                    }
                }
                .padding(18)
            }
            .background(AcademyPalette.background)
            .navigationTitle("Conditions Générales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(AcademyPalette.pine)
                }
            }
        }
    }
}

// MARK: - 4. Porte de Déverrouillage Code PIN Cenelis Connect (Ouverture Automatique dans Safari In-App à Chaque Lancement)
// IMPORTANT : Aucune vue clavier PIN native ! Cet écran ouvre automatiquement la vraie page web https://sso.prod.cenelis.com/pin dans Safari In-App.

public struct AcademyPinLaunchGateView: View {
    @ObservedObject var vm: AcademyStoreViewModel

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack {
            AcademyPalette.heroGradient.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 92, height: 92)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("CENELIS CONNECT · SÉCURITÉ MOBILE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(AcademyPalette.gold)

                Text("Code PIN Cenelis Connect requis")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("À chaque lancement de Cenelis Academy, la saisie de votre code PIN personnel s'effectue sur la page officielle **Cenelis Connect** intégrée à l'application.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)

                // Carte d'identité de la session en attente de déverrouillage PIN
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .foregroundStyle(AcademyPalette.gold)
                        Text(vm.learner.displayName.isEmpty ? vm.learner.email : vm.learner.displayName)
                            .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("\(vm.learner.email) · \(vm.learner.permissionBadgeTitle)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.18), lineWidth: 1))
                )

                if let msg = vm.pinGateMessage {
                    Text(msg)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.black.opacity(0.24))
                        )
                }

                VStack(spacing: 12) {
                    Button {
                        AcademyHaptics.medium()
                        vm.openInAppCenelisConnectPin()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "safari.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Ouvrir la page PIN Cenelis Connect")
                                .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(AcademyPalette.pineDeep)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.20), radius: 12, y: 5)
                        )
                    }
                    .buttonStyle(SpringPressableButtonStyle())

                    Button {
                        vm.logout()
                    } label: {
                        Text("Se déconnecter / Changer de compte")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.84))
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            vm.triggerAutoPinIfNeeded()
        }
    }
}

// MARK: - Navigateur Safari In-App Natif (SFSafariViewController) ouvrant https://sso.prod.cenelis.com/pin

#if canImport(SafariServices)
public struct CenelisConnectInAppSafariView: UIViewControllerRepresentable {
    public let url: URL
    public let onUserDismiss: @Sendable @MainActor () -> Void

    public init(url: URL, onUserDismiss: @escaping @Sendable @MainActor () -> Void) {
        self.url = url
        self.onUserDismiss = onUserDismiss
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onUserDismiss: onUserDismiss)
    }

    public func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = false

        let safari = SFSafariViewController(url: url, configuration: config)
        safari.delegate = context.coordinator
        safari.dismissButtonStyle = .close
        safari.preferredBarTintColor = UIColor(red: 0.078, green: 0.325, blue: 0.275, alpha: 1.0)
        safari.preferredControlTintColor = .white
        return safari
    }

    public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    public final class Coordinator: NSObject, SFSafariViewControllerDelegate, @unchecked Sendable {
        private let onUserDismiss: @Sendable @MainActor () -> Void

        init(onUserDismiss: @escaping @Sendable @MainActor () -> Void) {
            self.onUserDismiss = onUserDismiss
        }

        nonisolated public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            let callback = self.onUserDismiss
            Task { @MainActor in
                callback()
            }
        }
    }
}
#endif
