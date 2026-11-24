import SwiftUI

// MARK: - Gestionnaire Centralisé des Appareils Connectés Viple Live ID (LivriaConnectedDevicesView • Swift 6)

public struct LivriaConnectedDevicesView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pendingRevokeTarget: PendingRevokeAction? = nil
    @State private var revokingDeviceId: String? = nil

    private struct PendingRevokeAction: Identifiable, Equatable {
        let device: LivriaConnectedDevice
        let appBadge: LivriaConnectedAppBadge?

        var id: String {
            "\(device.deviceId)-\(appBadge?.appId ?? "*")"
        }
    }

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                securityHeroCard

                if !store.isAuthenticated || store.currentUser?.isGuestAccount == true {
                    signedOutStateCard
                } else if store.isLoadingConnectedDevices && store.connectedDevices.isEmpty {
                    loadingStateCard
                } else if store.connectedDevices.isEmpty {
                    emptyDevicesStateCard
                } else {
                    devicesSummaryHeader
                    ForEach(store.connectedDevices) { device in
                        deviceSessionCard(device)
                    }
                }

                securityGuaranteeFooterCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 80)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Appareils connectés")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.isAuthenticated {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await store.loadConnectedDevices()
                        }
                    } label: {
                        if store.isLoadingConnectedDevices {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .disabled(store.isLoadingConnectedDevices || revokingDeviceId != nil)
                }
            }
        }
        .refreshable {
            await store.loadConnectedDevices()
        }
        .task {
            await store.loadConnectedDevices()
        }
        .alert(
            revokeAlertTitle,
            isPresented: Binding(
                get: { pendingRevokeTarget != nil },
                set: { if !$0 { pendingRevokeTarget = nil } }
            ),
            presenting: pendingRevokeTarget
        ) { target in
            Button("Annuler", role: .cancel) {
                pendingRevokeTarget = nil
            }
            Button(revokeConfirmButtonLabel(for: target), role: .destructive) {
                let captured = target
                pendingRevokeTarget = nil
                Task {
                    await executeRevocation(captured)
                }
            }
        } message: { target in
            Text(revokeAlertMessage(for: target))
        }
    }

    // MARK: - 1. En-tête Sécurité & Écosystème Viple Live ID

    private var securityHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 54, height: 54)
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LivriaPalette.gold)
                        Text("SÉCURITÉ ÉCOSYSTÈME VIPLE LIVE ID")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.goldSoft)
                    }

                    Text("Vos appareils & applications connectées")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Visualisez en temps réel tous les appareils connectés à votre compte sur Viple Mail, Livria Store, Livria Social et Cenelis Academy — même lorsque les applications sont fermées.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                heroMetricPill(
                    icon: "iphone.gen3",
                    title: LivriaAPIClient.shared.resolvedHardwareModelName,
                    subtitle: LivriaAPIClient.shared.resolvedOsVersion
                )
                heroMetricPill(
                    icon: "bell.badge.fill",
                    title: "\(store.connectedDevices.count) appareil\(store.connectedDevices.count > 1 ? "s" : "")",
                    subtitle: "Push exclusif actif"
                )
            }
        }
        .padding(18)
        .background(
            LivriaMeshHeroBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .shadow(color: LivriaPalette.primary.opacity(0.24), radius: 14, x: 0, y: 6)
    }

    private func heroMetricPill(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LivriaPalette.goldSoft)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.15))
        )
    }

    // MARK: - 2. Liste des Appareils Connectés

    private var devicesSummaryHeader: some View {
        HStack {
            Text("Sessions actives (\(store.connectedDevices.count))")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
            Spacer()
            if store.isLoadingConnectedDevices {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Actualisation…")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
            }
        }
    }

    private func deviceSessionCard(_ device: LivriaConnectedDevice) -> some View {
        let isRevokingThis = revokingDeviceId == device.deviceId
        return VStack(alignment: .leading, spacing: 14) {
            // Ligne supérieure : Icône + Modèle exact + Badge « Cet appareil » + Version iOS + Dernière activité
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            device.isCurrentDevice
                                ? LinearGradient(
                                    colors: [LivriaPalette.primary, LivriaPalette.coral],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [LivriaPalette.primarySoft, LivriaPalette.backgroundAlt],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: device.systemSymbolName)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(device.isCurrentDevice ? .white : LivriaPalette.primary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(device.displayModelName)
                            .font(.system(size: 16.5, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                            .lineLimit(1)

                        if device.isCurrentDevice {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 6, height: 6)
                                Text("Cet appareil")
                                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(LivriaPalette.mint))
                            .foregroundStyle(.white)
                        }
                    }

                    HStack(spacing: 8) {
                        Label(device.displayOsLabel, systemImage: "cpu")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(LivriaPalette.primaryDeep)

                        if !device.modelCode.isEmpty &&
                           device.modelCode.lowercased() != device.displayModelName.lowercased() {
                            Text("• \(device.modelCode)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                    }

                    HStack(spacing: 8) {
                        Label(device.lastActivityLabelFr, systemImage: "clock.fill")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(LivriaPalette.inkMuted)

                        if device.pushActive {
                            Label("Push actif", systemImage: "bell.badge.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(LivriaPalette.mint)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            Divider()

            // Badges des applications connectées sur cet appareil (même fermées)
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Applications connectées (\(device.connectedApps.count))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.inkMuted)
                    Spacer()
                    Text("Même appli fermée")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(LivriaPalette.primary)
                }

                if device.connectedApps.isEmpty {
                    Text("Session Viple Live ID enregistrée")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LivriaPalette.inkMuted)
                } else {
                    VStack(spacing: 8) {
                        ForEach(device.connectedApps) { app in
                            connectedAppRow(device: device, app: app, isDisabled: isRevokingThis)
                        }
                    }
                }
            }

            // Bouton global de déconnexion de l'appareil
            Button(role: .destructive) {
                pendingRevokeTarget = PendingRevokeAction(device: device, appBadge: nil)
            } label: {
                HStack(spacing: 8) {
                    if isRevokingThis {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(
                        device.isCurrentDevice
                            ? "Déconnecter cet appareil de tout l'écosystème"
                            : "Déconnecter \(device.displayModelName) à distance"
                    )
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.red.opacity(0.11))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.red.opacity(0.28), lineWidth: 1)
                )
                .foregroundStyle(.red)
            }
            .disabled(isRevokingThis || revokingDeviceId != nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LivriaPalette.cardPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    device.isCurrentDevice ? LivriaPalette.mint.opacity(0.55) : LivriaPalette.border,
                    lineWidth: device.isCurrentDevice ? 1.8 : 1
                )
        )
        .shadow(color: LivriaPalette.primary.opacity(0.07), radius: 12, x: 0, y: 5)
    }

    private func connectedAppRow(
        device: LivriaConnectedDevice,
        app: LivriaConnectedAppBadge,
        isDisabled: Bool
    ) -> some View {
        let brandColor = Self.colorFromHex(app.colorHex)
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(brandColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: app.icon.isEmpty ? LivriaConnectedAppBadge.defaultSystemIcon(for: app.appId) : app.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(brandColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.appName)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)

                    if !app.appVersion.isEmpty {
                        Text("v\(app.appVersion)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(brandColor.opacity(0.12)))
                            .foregroundStyle(brandColor)
                    }

                    if app.notificationsEnabled {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LivriaPalette.mint)
                    }
                }

                if !app.accountEmail.isEmpty {
                    Text(app.accountEmail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Button {
                pendingRevokeTarget = PendingRevokeAction(device: device, appBadge: app)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Déconnecter")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.red.opacity(0.10)))
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || revokingDeviceId != nil)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LivriaPalette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(brandColor.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - 3. États Vides / Chargement / Invité & Pied de Page

    private var loadingStateCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(LivriaPalette.primary)
            Text("Synchronisation de vos appareils connectés…")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .livriaCard()
    }

    private var emptyDevicesStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(LivriaPalette.primary)
            Text("Aucun appareil détecté pour le moment")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
            Text("Tirez vers le bas ou appuyez sur Actualiser pour synchroniser cet appareil avec le registre central Viple Live ID.")
                .font(.system(size: 13))
                .foregroundStyle(LivriaPalette.inkMuted)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    if let user = store.currentUser, !user.isGuestAccount {
                        await LivriaNotificationManager.shared.syncDeviceRegistration(user: user, isExplicitLogin: false)
                    }
                    await store.loadConnectedDevices()
                }
            } label: {
                Label("Synchroniser maintenant", systemImage: "arrow.clockwise")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(LivriaPalette.primary))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .livriaCard()
    }

    private var signedOutStateCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.badge.shield.checkmark.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(LivriaPalette.primary)
            Text("Vous êtes déconnecté sur cet appareil")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
            Text("Connectez-vous à votre compte Viple Live ID pour afficher et contrôler l'ensemble de vos appareils connectés.")
                .font(.system(size: 13))
                .foregroundStyle(LivriaPalette.inkMuted)
                .multilineTextAlignment(.center)
            Button {
                store.isShowingAuthSheet = true
            } label: {
                Label("Se connecter à Viple Live ID", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
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
        .padding(20)
        .livriaCard()
    }

    private var securityGuaranteeFooterCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(LivriaPalette.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Protection stricte des notifications en arrière-plan")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Text("Seul le compte actuellement connecté sur un iPhone reçoit ses notifications (même application fermée). Toute déconnexion ou révocation coupe instantanément les alertes push APNs de l'appareil concerné.")
                    .font(.system(size: 12))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .livriaCard(padding: 14)
    }

    // MARK: - 4. Actions de Révocation & Utilitaires

    private var revokeAlertTitle: String {
        guard let target = pendingRevokeTarget else { return "Déconnecter l'appareil" }
        if let app = target.appBadge {
            return "Déconnecter de \(app.appName) ?"
        }
        return "Déconnecter \(target.device.displayModelName) ?"
    }

    private func revokeConfirmButtonLabel(for target: PendingRevokeAction) -> String {
        if let app = target.appBadge {
            return "Déconnecter de \(app.appName)"
        }
        return "Déconnecter partout"
    }

    private func revokeAlertMessage(for target: PendingRevokeAction) -> String {
        if let app = target.appBadge {
            if target.device.isCurrentDevice && app.appId.lowercased() == "livria-store" {
                return "Vous allez être immédiatement déconnecté de Livria Store sur cet appareil et ne recevrez plus aucune notification."
            }
            return "\(target.device.displayModelName) sera immédiatement déconnecté de \(app.appName) et ses notifications push pour cette application seront coupées."
        }
        if target.device.isCurrentDevice {
            return "Cet appareil sera immédiatement déconnecté de Viple Mail, Livria Store, Livria Social et Cenelis Academy."
        }
        return "\(target.device.displayModelName) sera déconnecté à distance de toutes les applications Viple et ne recevra plus aucune notification."
    }

    private func executeRevocation(_ target: PendingRevokeAction) async {
        let appId = target.appBadge?.appId ?? "*"
        let willSignOutLocally = target.device.isCurrentDevice &&
            (appId == "*" || appId.lowercased() == "livria-store")

        revokingDeviceId = target.device.deviceId
        defer { revokingDeviceId = nil }

        _ = await store.revokeConnectedDevice(device: target.device, targetAppId: appId)
        if willSignOutLocally || !store.isAuthenticated {
            dismiss()
        }
    }

    private static func colorFromHex(_ rawHex: String) -> Color {
        let hex = rawHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, let intVal = UInt64(hex, radix: 16) else {
            return LivriaPalette.primary
        }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
