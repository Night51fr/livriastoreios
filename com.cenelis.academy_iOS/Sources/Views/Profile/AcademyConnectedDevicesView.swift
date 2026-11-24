import SwiftUI

// MARK: - Gestionnaire Unifié des Appareils Connectés & Sessions Écosystème (Viple Mail · Livria Store · Livria Social · Cenelis Academy)

private struct PendingRevokeTarget: Identifiable, Sendable {
    var id: String { "\(device.deviceId)|\(specificApp?.appId ?? "*")" }
    let device: AcademyConnectedDeviceItem
    let specificApp: AcademyConnectedAppSession?
}

public struct AcademyConnectedDevicesView: View {
    @ObservedObject var vm: AcademyStoreViewModel

    @State private var devices: [AcademyConnectedDeviceItem] = []
    @State private var isLoading: Bool = true
    @State private var revokingDeviceId: String? = nil
    @State private var errorMessage: String? = nil
    @State private var toastMessage: String? = nil
    @State private var confirmDeviceMenu: AcademyConnectedDeviceItem? = nil
    @State private var confirmSingleAppTarget: PendingRevokeTarget? = nil

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    private var sortedDevices: [AcademyConnectedDeviceItem] {
        devices.sorted { lhs, rhs in
            if lhs.isCurrentDevice != rhs.isCurrentDevice {
                return lhs.isCurrentDevice && !rhs.isCurrentDevice
            }
            return lhs.lastSeenAtUtc > rhs.lastSeenAtUtc
        }
    }

    private var totalConnectedAppsCount: Int {
        devices.reduce(0) { $0 + max(1, $1.connectedApps.count) }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ecosystemSummaryHeroCard

                if let toastMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(AcademyPalette.success)
                        Text(toastMessage)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                        Spacer()
                    }
                    .padding(13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AcademyPalette.successSoft)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(AcademyPalette.success.opacity(0.35), lineWidth: 1)
                            )
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AcademyPalette.danger)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AcademyPalette.danger)
                            Button("Réessayer") {
                                AcademyHaptics.selection()
                                Task { await loadDevices(showSpinner: true) }
                            }
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.pine)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AcademyPalette.dangerSoft)
                    )
                }

                if isLoading && devices.isEmpty {
                    loadingStateCard
                } else if sortedDevices.isEmpty {
                    emptyDevicesStateCard
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Appareils actifs (\(sortedDevices.count))")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(AcademyPalette.ink)
                            Spacer()
                            AcademyBadge(
                                "\(totalConnectedAppsCount) session\(totalConnectedAppsCount > 1 ? "s" : "")",
                                icon: "square.stack.3d.up.fill",
                                style: .pine
                            )
                        }

                        ForEach(sortedDevices) { device in
                            deviceCard(for: device)
                        }
                    }
                }

                securityGovernanceNoteCard
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(AcademyPalette.background)
        .navigationTitle("Appareils connectés")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    AcademyHaptics.selection()
                    Task { await loadDevices(showSpinner: false) }
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AcademyPalette.pine)
                    }
                }
                .disabled(isLoading || revokingDeviceId != nil)
            }
        }
        .refreshable {
            await loadDevices(showSpinner: false)
        }
        .task {
            await loadDevices(showSpinner: true)
        }
        .confirmationDialog(
            confirmDialogTitle(for: confirmDeviceMenu),
            isPresented: Binding(
                get: { confirmDeviceMenu != nil },
                set: { if !$0 { confirmDeviceMenu = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = confirmDeviceMenu {
                Button(
                    target.isCurrentDevice
                        ? "Déconnecter cet appareil (tout l'écosystème)"
                        : "Déconnecter de tout l'écosystème",
                    role: .destructive
                ) {
                    Task { await performRevoke(device: target, targetAppId: nil) }
                }

                ForEach(target.connectedApps) { app in
                    Button("Déconnecter uniquement de \(app.appName)", role: .destructive) {
                        Task { await performRevoke(device: target, targetAppId: app.appId) }
                    }
                }

                Button("Annuler", role: .cancel) {
                    confirmDeviceMenu = nil
                }
            }
        } message: {
            if let target = confirmDeviceMenu {
                Text(
                    target.isCurrentDevice
                        ? "Attention : il s'agit de l'appareil que vous utilisez actuellement. La déconnexion coupera immédiatement les notifications et fermera votre session."
                        : "La révocation coupe immédiatement les notifications push et ferme les sessions ouvertes sur \(target.resolvedDisplayModelName)."
                )
            }
        }
        .alert(
            "Déconnecter cette application ?",
            isPresented: Binding(
                get: { confirmSingleAppTarget != nil },
                set: { if !$0 { confirmSingleAppTarget = nil } }
            ),
            presenting: confirmSingleAppTarget
        ) { pending in
            Button("Déconnecter \(pending.specificApp?.appName ?? "")", role: .destructive) {
                Task {
                    await performRevoke(
                        device: pending.device,
                        targetAppId: pending.specificApp?.appId
                    )
                }
            }
            Button("Annuler", role: .cancel) {
                confirmSingleAppTarget = nil
            }
        } message: { pending in
            let appLabel = pending.specificApp?.appName ?? "l'écosystème"
            Text(
                pending.device.isCurrentDevice && (pending.specificApp?.appId.lowercased() == "cenelis-academy")
                    ? "Vous serez immédiatement déconnecté de Cenelis Academy sur cet appareil et ne recevrez plus aucune notification."
                    : "L'application \(appLabel) sera déconnectée à distance sur \(pending.device.resolvedDisplayModelName)."
            )
        }
    }

    // MARK: - En-tête Institutionnel Écosystème

    private var ecosystemSummaryHeroCard: some View {
        let localHW = AcademyDeviceHardwareInfo.current()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("HUB SÉCURITÉ ÉCOSYSTÈME")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                }
                .foregroundStyle(AcademyPalette.gold)

                Spacer()

                Text("\(localHW.modelName) · iOS \(localHW.osVersion)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text("Appareils & Applications Connectées")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Visualisez tous les appareils associés à **\(vm.learner.email)** sur *Viple Mail*, *Livria Store*, *Livria Social* et *Cenelis Academy* (même lorsque les applications sont fermées) et révoquez instantanément tout accès à distance.")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.88))
                .lineSpacing(2.5)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AcademyPalette.heroGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                )
        )
    }

    // MARK: - Carte d'un Appareil Physique

    private func deviceCard(for device: AcademyConnectedDeviceItem) -> some View {
        let isRevokingThis = (revokingDeviceId == device.deviceId)

        return VStack(alignment: .leading, spacing: 14) {
            // 1. En-tête matériel : Modèle exact + iOS + badge « Cet appareil »
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(device.isCurrentDevice ? AcademyPalette.pineSolid : AcademyPalette.pineSoft)
                        .frame(width: 48, height: 48)
                    Image(systemName: hardwareSFSymbol(for: device))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(device.isCurrentDevice ? .white : AcademyPalette.pine)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(device.resolvedDisplayModelName)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)

                        if device.isCurrentDevice {
                            AcademyBadge("Cet appareil", icon: "checkmark.circle.fill", style: .success)
                        }
                    }

                    Text(hardwareSubtitle(for: device))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AcademyPalette.inkSecondary)

                    HStack(spacing: 8) {
                        Label(
                            formattedRelativeActivity(device.lastSeenAtUtc),
                            systemImage: "clock.arrow.circlepath"
                        )
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(AcademyPalette.inkMuted)

                        if device.pushActive {
                            Label("Push actif", systemImage: "bell.badge.fill")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.pine)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            Divider()

            // 2. Applications connectées sur cet appareil (y compris fermées en arrière-plan)
            VStack(alignment: .leading, spacing: 8) {
                Text("APPLICATIONS CONNECTÉES SUR CET APPAREIL")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(AcademyPalette.inkMuted)

                if device.connectedApps.isEmpty {
                    HStack(spacing: 6) {
                        AcademyBadge("Session Écosystème active", icon: "checkmark.shield.fill", style: .pine)
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(device.connectedApps) { app in
                            connectedAppRow(app: app, on: device, isBusy: isRevokingThis)
                        }
                    }
                }
            }

            // 3. Bouton « Déconnecter cet appareil »
            Button {
                AcademyHaptics.medium()
                confirmDeviceMenu = device
            } label: {
                HStack(spacing: 8) {
                    if isRevokingThis {
                        ProgressView()
                            .tint(AcademyPalette.danger)
                    } else {
                        Image(systemName: "power.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("Déconnecter cet appareil")
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    }
                }
                .foregroundStyle(AcademyPalette.danger)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(AcademyPalette.dangerSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(AcademyPalette.danger.opacity(0.26), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(SpringPressableButtonStyle())
            .disabled(revokingDeviceId != nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            device.isCurrentDevice ? AcademyPalette.pine : AcademyPalette.border,
                            lineWidth: device.isCurrentDevice ? 1.5 : 1
                        )
                )
                .shadow(color: .black.opacity(0.03), radius: 8, y: 3)
        )
    }

    private func connectedAppRow(
        app: AcademyConnectedAppSession,
        on device: AcademyConnectedDeviceItem,
        isBusy: Bool
    ) -> some View {
        let brandColor = resolvedAppBrandColor(for: app)

        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(brandColor.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: resolvedAppIcon(for: app))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(brandColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.appName)
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.ink)

                    if !app.appVersion.isEmpty {
                        Text("v\(app.appVersion)")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AcademyPalette.surfaceSubtle))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                    }

                    if app.notificationsEnabled {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(brandColor)
                    }
                }

                Text(
                    app.lastSeenAtUtc.isEmpty
                        ? (app.accountEmail.isEmpty ? "Session active" : app.accountEmail)
                        : "\(formattedRelativeActivity(app.lastSeenAtUtc))"
                )
                .font(.system(size: 11.5))
                .foregroundStyle(AcademyPalette.inkSecondary)
            }

            Spacer()

            Button {
                AcademyHaptics.selection()
                confirmSingleAppTarget = PendingRevokeTarget(device: device, specificApp: app)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AcademyPalette.inkMuted)
            }
            .buttonStyle(.plain)
            .disabled(isBusy || revokingDeviceId != nil)
            .accessibilityLabel("Déconnecter \(app.appName) sur \(device.resolvedDisplayModelName)")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(AcademyPalette.surfaceSubtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(brandColor.opacity(0.22), lineWidth: 1)
                )
        )
    }

    // MARK: - États Chargement / Vide / Gouvernance

    private var loadingStateCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AcademyPalette.pine)
            Text("Interrogation du Hub d'Appareils Cenelis / Viple…")
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(AcademyPalette.inkSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    private var emptyDevicesStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AcademyPalette.copper)
            Text("Aucun appareil recensé")
                .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                .foregroundStyle(AcademyPalette.ink)
            Text("Tirez vers le bas pour actualiser l'état de vos sessions actives.")
                .font(.system(size: 12.5))
                .foregroundStyle(AcademyPalette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    private var securityGovernanceNoteCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AcademyPalette.pine)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Exclusivité stricte des notifications & Révocation instantanée")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
                Text("Seul le compte actuellement connecté reçoit les rappels et notifications push sur un appareil donné. Toute déconnexion coupe immédiatement les notifications (même application fermée).")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AcademyPalette.inkSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AcademyPalette.pineSoft)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AcademyPalette.pineBorder, lineWidth: 1))
        )
    }

    // MARK: - Actions Réseau (Chargement & Révocation)

    private func loadDevices(showSpinner: Bool) async {
        guard !vm.mobileToken.isEmpty else { return }
        if showSpinner { isLoading = true }
        errorMessage = nil
        defer { isLoading = false }

        do {
            let res = try await AcademyAPIClient.shared.fetchConnectedDevices(token: vm.mobileToken)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                self.devices = res.devices
            }
        } catch let apiError as AcademyAPIError where apiError.isSessionTerminated {
            vm.logout(remoteRevocationMessage: apiError.errorDescription)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performRevoke(device: AcademyConnectedDeviceItem, targetAppId: String?) async {
        guard !vm.mobileToken.isEmpty else { return }
        revokingDeviceId = device.deviceId
        errorMessage = nil
        toastMessage = nil
        defer { revokingDeviceId = nil }

        let normalizedApp = targetAppId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "*"
        let isGlobal = normalizedApp.isEmpty || normalizedApp == "*" || normalizedApp.lowercased() == "all"
        let affectsCurrentAcademySession = device.isCurrentDevice
            && (isGlobal || normalizedApp.lowercased() == "cenelis-academy")

        do {
            _ = try await AcademyAPIClient.shared.revokeConnectedDevice(
                token: vm.mobileToken,
                targetDeviceId: device.deviceId,
                targetAppId: isGlobal ? "*" : normalizedApp,
                rawDeviceIds: device.rawDeviceIds
            )
            AcademyHaptics.success()

            if affectsCurrentAcademySession {
                vm.logout(remoteRevocationMessage: "Session fermée depuis le gestionnaire d'appareils.")
                return
            }

            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                toastMessage = isGlobal
                    ? "\(device.resolvedDisplayModelName) a été déconnecté de tout l'écosystème."
                    : "Application déconnectée sur \(device.resolvedDisplayModelName)."
            }
            await loadDevices(showSpinner: false)
        } catch let apiError as AcademyAPIError where apiError.isSessionTerminated {
            vm.logout(remoteRevocationMessage: apiError.errorDescription)
        } catch {
            AcademyHaptics.error()
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers de Présentation Visuelle

    private func confirmDialogTitle(for device: AcademyConnectedDeviceItem?) -> String {
        guard let device else { return "Déconnecter cet appareil" }
        return "Déconnecter \(device.resolvedDisplayModelName)"
    }

    private func hardwareSFSymbol(for device: AcademyConnectedDeviceItem) -> String {
        let lowerName = device.resolvedDisplayModelName.lowercased()
        let lowerPlat = device.platform.lowercased()
        if lowerName.contains("ipad") || lowerPlat.contains("ipad") {
            return "ipad.gen2"
        }
        if lowerPlat.contains("mac") || lowerPlat.contains("web") || lowerPlat.contains("windows") {
            return "desktopcomputer"
        }
        return "iphone.gen3"
    }

    private func hardwareSubtitle(for device: AcademyConnectedDeviceItem) -> String {
        var parts: [String] = []
        let plat = device.platform.isEmpty ? "iOS" : device.platform
        if !device.osVersion.isEmpty {
            parts.append("\(plat) \(device.osVersion)")
        } else {
            parts.append(plat)
        }
        if !device.modelCode.isEmpty && !device.modelCode.lowercased().contains("arm64") {
            parts.append(device.modelCode)
        }
        return parts.joined(separator: " · ")
    }

    private func resolvedAppIcon(for app: AcademyConnectedAppSession) -> String {
        let id = app.appId.lowercased()
        if id.contains("mail") { return "envelope.fill" }
        if id.contains("store") { return "book.closed.fill" }
        if id.contains("social") { return "bubble.left.and.bubble.right.fill" }
        if id.contains("academy") { return "graduationcap.fill" }
        if id.contains("workspace") || id.contains("connect") { return "lock.shield.fill" }
        if !app.icon.isEmpty { return app.icon }
        return "app.badge.checkmark.fill"
    }

    private func resolvedAppBrandColor(for app: AcademyConnectedAppSession) -> Color {
        if let parsed = Self.colorFromHex(app.colorHex) {
            return parsed
        }
        let id = app.appId.lowercased()
        if id.contains("mail") { return AcademyPalette.sky }
        if id.contains("store") { return AcademyPalette.copper }
        if id.contains("social") { return Color(red: 0.48, green: 0.23, blue: 0.93) }
        return AcademyPalette.pine
    }

    private static func colorFromHex(_ rawHex: String) -> Color? {
        var cleaned = rawHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let rgb = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    private func formattedRelativeActivity(_ isoString: String) -> String {
        let trimmed = isoString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Activité récente" }

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]

        guard let date = isoFrac.date(from: trimmed) ?? isoPlain.date(from: trimmed) else {
            return "Activité récente"
        }

        let delta = Date().timeIntervalSince(date)
        if delta < 90 {
            return "En ligne à l'instant"
        }
        if delta < 3600 {
            let mins = max(1, Int(delta / 60))
            return "Actif il y a \(mins) min"
        }
        if delta < 86_400 {
            let hours = max(1, Int(delta / 3600))
            return "Actif il y a \(hours) h"
        }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        fmt.dateFormat = "d MMM yyyy 'à' HH'h'mm"
        return "Vu le \(fmt.string(from: date))"
    }
}
