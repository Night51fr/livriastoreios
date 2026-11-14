import SwiftUI

// MARK: - 1. Écran d'Amorçage Sécurisé

public struct WorkspaceBootSplashView: View {
    @Environment(\.colorScheme) private var scheme

    public init() {}

    public var body: some View {
        ZStack {
            WorkspaceTheme.background(for: scheme)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                CenelisMonogramBadge(size: 72)

                VStack(spacing: 6) {
                    Text("CENELIS WORKSPACE")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .tracking(2.4)
                        .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))

                    Text("Super-App d'Administration · Groupe Cenelis")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                }

                ProgressView()
                    .tint(WorkspaceTheme.terracotta)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Monogramme Institutionnel Cenelis

public struct CenelisMonogramBadge: View {
    public let size: CGFloat

    public init(size: CGFloat = 44) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(WorkspaceTheme.forest)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
                        .padding(size * 0.09)
                )

            Text("C")
                .font(.system(size: size * 0.54, weight: .regular, design: .serif))
                .foregroundStyle(Color(red: 0.969, green: 0.965, blue: 0.949))

            Rectangle()
                .fill(WorkspaceTheme.terracotta)
                .frame(width: size * 0.44, height: max(2, size * 0.055))
        }
    }
}

// MARK: - 2. Écran de Connexion Persistante Viple Live ID / Cenelis Connect

public struct VipleLiveLoginView: View {
    @ObservedObject public var vm: WorkspaceStoreViewModel
    @Environment(\.colorScheme) private var scheme

    @State private var identifier: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isShowingSSOWebSheet: Bool = false

    public init(vm: WorkspaceStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack {
            WorkspaceTheme.background(for: scheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer(minLength: 28)

                    VStack(spacing: 14) {
                        CenelisMonogramBadge(size: 64)

                        Text("CENELIS WORKSPACE")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(2.0)
                            .foregroundStyle(WorkspaceTheme.terracotta)

                        Text("Connexion Opérateur Viple Live ID")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))

                        Text("Authentifiez votre compte principal. Votre session Viple Live ID restera active sur l'ensemble des consoles *.cenelis.com et sera protégée par votre code PIN Cenelis Connect.")
                            .font(.system(size: 13.5))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                            .padding(.horizontal, 8)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("IDENTIFIANT VIPLE LIVE ID / @VIPLEMAIL.FR")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))

                            TextField("prenom.nom@viplemail.fr", text: $identifier)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .textContentType(.username)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(WorkspaceTheme.secondaryBackground(for: scheme))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("MOT DE PASSE")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))

                            SecureField("Votre mot de passe Viple Live ID", text: $password)
                                .textContentType(.password)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(WorkspaceTheme.secondaryBackground(for: scheme))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                                )
                        }

                        if let errorMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(WorkspaceTheme.statusRed)
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(WorkspaceTheme.statusRed)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(WorkspaceTheme.statusRed.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Button {
                            submitCredentials()
                        } label: {
                            HStack(spacing: 10) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "lock.open.shield.fill")
                                    Text("Se connecter avec Viple Live ID")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(WorkspaceTheme.forest)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .disabled(isSubmitting || identifier.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                        .opacity((isSubmitting || identifier.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty) ? 0.6 : 1.0)

                        Button {
                            isShowingSSOWebSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "globe.badge.chevron.backward")
                                Text("Passer par le portail SSO Web Cenelis Connect")
                                    .font(.system(size: 13.5, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                            .background(WorkspaceTheme.secondaryBackground(for: scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                            )
                        }
                    }
                    .padding(22)
                    .background(WorkspaceTheme.cardSurface(for: scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    Text("GROUPE CENELIS · SESSION SSO UNIFIÉE WKWEBSITEDATASTORE")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $isShowingSSOWebSheet) {
            NavigationStack {
                SharedSSOAuthWebView(
                    startURL: URL(string: "https://sso.prod.cenelis.com/login?returnUrl=%2Fportail")!
                ) { cookieHeader in
                    isShowingSSOWebSheet = false
                    Task {
                        await vm.completeSSOWebLogin(cookieHeader: cookieHeader)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("SSO Cenelis Connect")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") {
                            isShowingSSOWebSheet = false
                        }
                    }
                }
            }
        }
    }

    private func submitCredentials() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                try await vm.signInWithCredentials(identifier: identifier, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - 3. Écran Habilitation Absente (Compte sans droits /admin)

public struct WorkspaceAccessDeniedView: View {
    @ObservedObject public var vm: WorkspaceStoreViewModel
    @Environment(\.colorScheme) private var scheme

    public init(vm: WorkspaceStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack {
            WorkspaceTheme.background(for: scheme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "shield.slash.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(WorkspaceTheme.terracotta)

                Text("Aucune habilitation /admin active")
                    .font(.system(size: 23, weight: .bold, design: .serif))
                    .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))

                Text("Le compte \(vm.operatorProfile.email) est authentifié mais ne dispose d'aucun rôle d'administration approuvé dans Cenelis AdminGest.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                    .padding(.horizontal, 28)

                HStack(spacing: 12) {
                    Button {
                        Task { await vm.refreshOperatorAndRbacSession() }
                    } label: {
                        Label("Revérifier", systemImage: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(WorkspaceTheme.forest)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        Task { await vm.performFullLogout() }
                    } label: {
                        Label("Changer de compte", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(WorkspaceTheme.secondaryBackground(for: scheme))
                            .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - 4. Écran de Verrouillage Natif « Cenelis Connect PIN » (Chaque Lancement & Retour Premier Plan)

public struct NativeCenelisConnectPinLockView: View {
    @ObservedObject public var vm: WorkspaceStoreViewModel
    @Environment(\.colorScheme) private var scheme

    @State private var enteredDigits: String = ""
    @State private var setupFirstEntry: String = ""
    @State private var isConfirmingSetup: Bool = false
    @State private var selectedSetupLength: Int = 6
    @State private var shakeOffset: CGFloat = 0
    @State private var showLogoutConfirm: Bool = false

    public init(vm: WorkspaceStoreViewModel) {
        self.vm = vm
    }

    private var targetLength: Int {
        vm.operatorProfile.hasPinConfigured ? vm.operatorProfile.pinLength : selectedSetupLength
    }

    public var body: some View {
        ZStack {
            // Fond opaque institutionnel masquant intégralement tout panel ouvert en arrière-plan
            WorkspaceTheme.background(for: scheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Barre supérieure : Identité du compte actif + Changement de compte
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(WorkspaceTheme.forest)
                                .frame(width: 34, height: 34)
                            Text(vm.operatorProfile.initials)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(vm.operatorProfile.displayName)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                                .lineLimit(1)
                            Text(vm.operatorProfile.email)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        showLogoutConfirm = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Déconnexion")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WorkspaceTheme.terracotta)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(WorkspaceTheme.terracotta.opacity(0.11))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer(minLength: 16)

                // En-tête Cenelis Connect PIN
                VStack(spacing: 12) {
                    CenelisMonogramBadge(size: 54)

                    Text("CENELIS CONNECT · SÉCURITÉ PIN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(WorkspaceTheme.terracotta)

                    Text(headerTitle)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))

                    Text(headerSubtitle)
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                        .padding(.horizontal, 28)

                    if !vm.operatorProfile.hasPinConfigured && !isConfirmingSetup {
                        Picker("Format du PIN", selection: $selectedSetupLength) {
                            Text("4 chiffres").tag(4)
                            Text("6 chiffres").tag(6)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                        .padding(.top, 4)
                        .onChange(of: selectedSetupLength) { _, _ in
                            enteredDigits = ""
                        }
                    }
                }

                // Pastilles d'état de saisie du PIN
                HStack(spacing: 16) {
                    ForEach(0..<targetLength, id: \.self) { idx in
                        let isFilled = idx < enteredDigits.count
                        Circle()
                            .fill(isFilled ? WorkspaceTheme.forestAccent : Color.clear)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isFilled ? WorkspaceTheme.forestAccent : WorkspaceTheme.secondaryInk(for: scheme).opacity(0.45),
                                        lineWidth: 1.8
                                    )
                            )
                            .scaleEffect(isFilled ? 1.12 : 1.0)
                            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: enteredDigits.count)
                    }
                }
                .offset(x: shakeOffset)
                .padding(.vertical, 26)

                if vm.isVerifyingPin {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(WorkspaceTheme.terracotta)
                        Text("Vérification Cenelis Connect…")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                    }
                    .frame(height: 26)
                } else if let err = vm.pinErrorMessage {
                    Text(err)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(WorkspaceTheme.statusRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 26)
                } else {
                    Color.clear.frame(height: 26)
                }

                Spacer(minLength: 10)

                // Pavé numérique tactile natif
                VStack(spacing: 14) {
                    ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                        HStack(spacing: 22) {
                            ForEach(row, id: \.self) { digit in
                                PinKeypadDigitButton(label: "\(digit)", scheme: scheme) {
                                    appendDigit("\(digit)")
                                }
                            }
                        }
                    }

                    HStack(spacing: 22) {
                        if !vm.operatorProfile.hasPinConfigured && isConfirmingSetup {
                            Button {
                                WorkspaceHaptics.light()
                                isConfirmingSetup = false
                                setupFirstEntry = ""
                                enteredDigits = ""
                                vm.pinErrorMessage = nil
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 74, height: 74)
                                    .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                            }
                        } else {
                            Color.clear.frame(width: 74, height: 74)
                        }

                        PinKeypadDigitButton(label: "0", scheme: scheme) {
                            appendDigit("0")
                        }

                        Button {
                            deleteLastDigit()
                        } label: {
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 21, weight: .medium))
                                .frame(width: 74, height: 74)
                                .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                        }
                        .disabled(enteredDigits.isEmpty || vm.isVerifyingPin)
                        .opacity(enteredDigits.isEmpty ? 0.35 : 1.0)
                    }
                }
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 430)
        }
        .confirmationDialog(
            "Se déconnecter du compte Viple Live ID ?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("Se déconnecter et purger la session", role: .destructive) {
                Task { await vm.performFullLogout() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tous les cookies WebView et jetons de session seront effacés afin de permettre la connexion d'un autre compte.")
        }
    }

    private var headerTitle: String {
        if !vm.operatorProfile.hasPinConfigured {
            return isConfirmingSetup ? "Confirmez votre code PIN" : "Créez votre code PIN"
        }
        return "Entrez votre code PIN"
    }

    private var headerSubtitle: String {
        if !vm.operatorProfile.hasPinConfigured {
            return isConfirmingSetup
                ? "Saisissez une seconde fois votre code personnel Cenelis Connect."
                : "Définissez votre code PIN Cenelis Connect personnel pour sécuriser vos consoles /admin."
        }
        return "Déverrouillage obligatoire à chaque ouverture de Cenelis Workspace."
    }

    private func appendDigit(_ d: String) {
        guard !vm.isVerifyingPin, enteredDigits.count < targetLength else { return }
        WorkspaceHaptics.light()
        vm.pinErrorMessage = nil
        enteredDigits.append(d)

        if enteredDigits.count == targetLength {
            handleCompletedEntry(enteredDigits)
        }
    }

    private func deleteLastDigit() {
        guard !vm.isVerifyingPin, !enteredDigits.isEmpty else { return }
        WorkspaceHaptics.light()
        enteredDigits.removeLast()
    }

    private func handleCompletedEntry(_ code: String) {
        if !vm.operatorProfile.hasPinConfigured {
            if !isConfirmingSetup {
                setupFirstEntry = code
                enteredDigits = ""
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConfirmingSetup = true
                }
                return
            } else {
                Task {
                    let ok = await vm.submitInitialPinSetup(pin: setupFirstEntry, confirmPin: code)
                    if !ok {
                        triggerErrorShake()
                        isConfirmingSetup = false
                        setupFirstEntry = ""
                        enteredDigits = ""
                    }
                }
                return
            }
        }

        Task {
            let ok = await vm.submitPinVerification(code)
            if !ok {
                triggerErrorShake()
                enteredDigits = ""
            }
        }
    }

    private func triggerErrorShake() {
        withAnimation(.default) { shakeOffset = 14 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.default) { shakeOffset = -12 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.default) { shakeOffset = 8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { shakeOffset = 0 }
        }
    }
}

private struct PinKeypadDigitButton: View {
    let label: String
    let scheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                .frame(width: 74, height: 74)
                .background(WorkspaceTheme.cardSurface(for: scheme))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
