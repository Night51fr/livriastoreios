import SwiftUI

// MARK: - Viple & Moi (vem4.ios) Onboarding & Viple Live ID Login View

public struct VemAuthLandingView: View {
    @Bindable var store: VemStoreViewModel

    @State private var emailInput: String = ""
    @State private var passwordInput: String = ""
    @State private var showPassword: Bool = false
    @State private var floatingLogo: Bool = false

    public init(store: VemStoreViewModel) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Animated Aurora Hero Banner
                VemAuroraBackgroundCard(cornerRadius: 32) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundStyle(.white)
                                    .offset(y: floatingLogo ? -2.5 : 2.5)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("VIPLE & MOI")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .tracking(1.4)
                                    .foregroundStyle(Color.white.opacity(0.82))
                                Text("Espace Client v4 · Groupe Cenelis")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.92))
                            }
                            Spacer()
                        }

                        Text("Tout votre univers Viple, votre famille et vos colis réunis.")
                            .font(.system(size: 27, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Pilotez vos serveurs Cloud & Gaming, votre Box 5G, votre boîte Viple Mail incluse à vie, les abonnements de vos proches, vos colis Livria & Viple Delivery et vos prélèvements 5 / 10 / 15.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .lineSpacing(3)
                    }
                    .padding(24)
                }

                // Cross-App Shared Account Quick Fill
                if let hint = store.crossAppHint {
                    Button {
                        VemHaptics.selection()
                        emailInput = hint.email
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(VemTheme.vipleEmerald.gradient)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(hint.name.prefix(1)).uppercased())
                                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Compte détecté sur votre iPhone")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundStyle(VemTheme.vipleEmerald)
                                Text("\(hint.name) · \(hint.email)")
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.left.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(VemTheme.vipleEmerald)
                        }
                        .vemCard(cornerRadius: 18, padding: 14)
                    }
                    .buttonStyle(VemPressableButtonStyle())
                }

                // Native Viple Live ID Login Card
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connexion Viple Live")
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                        Text("Utilisez votre adresse @viplemail.fr ou l'adresse e-mail de votre compte Viple Live.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Adresse e-mail ou identifiant @viplemail.fr")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(VemTheme.vipleEmerald)
                            TextField("prenom.nom@viplemail.fr", text: $emailInput)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(VemTheme.elevatedSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(VemTheme.subtleBorder, lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mot de passe unifié")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(VemTheme.vipleEmerald)
                            Group {
                                if showPassword {
                                    TextField("Votre mot de passe", text: $passwordInput)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Votre mot de passe", text: $passwordInput)
                                }
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(VemTheme.elevatedSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(VemTheme.subtleBorder, lineWidth: 1)
                        )
                    }

                    Button {
                        VemHaptics.impact(.medium)
                        Task {
                            await store.signInWithCredentials(email: emailInput, password: passwordInput)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if store.isInitialLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "bolt.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            Text(store.isInitialLoading ? "Connexion sécurisée…" : "Accéder à Viple & Moi")
                                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(VemTheme.vibrantActionGradient)
                        )
                    }
                    .buttonStyle(VemPressableButtonStyle())
                    .disabled(store.isInitialLoading)

                    HStack {
                        Rectangle().fill(VemTheme.subtleBorder).frame(height: 1)
                        Text("OU")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Rectangle().fill(VemTheme.subtleBorder).frame(height: 1)
                    }

                    Button {
                        VemHaptics.impact(.light)
                        Task {
                            await store.signInWithWebSSO()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Connexion SSO Viple Live dans le navigateur")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13.5)
                        .foregroundStyle(VemTheme.electricIndigo)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(VemTheme.electricIndigo.opacity(0.11))
                        )
                    }
                    .buttonStyle(VemPressableButtonStyle())
                    .disabled(store.isInitialLoading)
                }
                .vemCard(cornerRadius: 24, padding: 20)

                // Feature Highlights Strip
                VStack(spacing: 12) {
                    LandingFeatureRow(
                        icon: "envelope.badge.shield.half.filled",
                        tint: VemTheme.vipleMint,
                        title: "Viple Mail @viplemail.fr inclus à vie",
                        subtitle: "5 Go souverains, Webmail direct et jusqu'à 5 alias personnalisés gratuits."
                    )
                    LandingFeatureRow(
                        icon: "person.3.sequence.fill",
                        tint: VemTheme.electricIndigo,
                        title: "Gestion Foyer & Contrôle des Options",
                        subtitle: "Partagez un VPS ou forfait avec vos enfants et autorisez ou bloquez les achats."
                    )
                    LandingFeatureRow(
                        icon: "checkmark.seal.fill",
                        tint: VemTheme.warmCoral,
                        title: "SEPA (5, 10 ou 15), PayPal & Factures 2D-DOC",
                        subtitle: "Choisissez votre jour de prélèvement et vérifiez vos factures signées VP01."
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(VemTheme.pageBackground.ignoresSafeArea())
        .onAppear {
            if emailInput.isEmpty, let hint = store.crossAppHint {
                emailInput = hint.email
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                floatingLogo = true
            }
        }
    }
}

private struct LandingFeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .vemCard(cornerRadius: 18, padding: 14)
    }
}
