import SwiftUI
import UIKit

// MARK: - Complete Per-Service Cockpit Sheet (Strict Server vs Non-Server Controls!)

public struct ServiceDetailSheet: View {
    @Bindable var store: VemStoreViewModel
    public let subscriptionId: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var nicknameInput: String = ""
    @State private var selectedMemberId: Int = 0
    @State private var newAliasInput: String = ""
    @State private var editingAliasOriginal: String?
    @State private var editingAliasReplacement: String = ""
    @State private var requestingOption: VemBoutiqueOption?
    @State private var optionRequestNote: String = "Bonjour, est-ce que je peux activer cette option sur mon service ? Merci !"
    @State private var confirmCancelService: Bool = false
    @State private var optionPendingCancel: VemActiveOption?

    public init(store: VemStoreViewModel, subscriptionId: Int) {
        self.store = store
        self.subscriptionId = subscriptionId
    }

    private var svc: VemSubscription? {
        store.subscription(withID: subscriptionId)
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let svc {
                    detailScrollContent(svc)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(VemTheme.vipleEmerald)
                        Text("Ce service n'est plus actif.")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Button("Fermer") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                }
            }
            .background(VemTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(svc?.displayTitle ?? "Détail du service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .onAppear {
                if let svc {
                    nicknameInput = svc.customNickname ?? ""
                    selectedMemberId = svc.assignedMemberId ?? 0
                }
            }
            .alert(
                "Résilier définitivement ce service ?",
                isPresented: $confirmCancelService
            ) {
                Button("Annuler", role: .cancel) {}
                Button("Confirmer la résiliation", role: .destructive) {
                    guard let svc else { return }
                    Task {
                        let ok = await store.performServiceAction(subscription: svc, action: "cancel")
                        if ok { dismiss() }
                    }
                }
            } message: {
                if let svc {
                    Text(
                        svc.isCommercialized
                            ? "Voulez-vous résilier « \(svc.displayTitle) » (\(svc.serviceRef)) ? La facturation s'arrêtera immédiatement."
                            : "ATTENTION : « \(svc.title) » est une offre historique qui n'est plus commercialisée. Si vous la résiliez, vous ne pourrez plus la re-commander à ce tarif."
                    )
                }
            }
            .alert(
                "Résilier cette option ?",
                isPresented: Binding(
                    get: { optionPendingCancel != nil },
                    set: { if !$0 { optionPendingCancel = nil } }
                )
            ) {
                Button("Conserver", role: .cancel) { optionPendingCancel = nil }
                Button("Résilier l'option", role: .destructive) {
                    if let opt = optionPendingCancel {
                        optionPendingCancel = nil
                        Task { await store.cancelOption(optionRowId: opt.id) }
                    }
                }
            } message: {
                if let opt = optionPendingCancel {
                    Text("L'option « \(opt.title) » (+\(VemFormat.euros(opt.priceMonthlyTtc))/mois) sera immédiatement désactivée.")
                }
            }
            .sheet(item: $requestingOption) { opt in
                if let svc {
                    OptionApprovalRequestSheet(
                        store: store,
                        subscription: svc,
                        option: opt,
                        initialMessage: optionRequestNote
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func detailScrollContent(_ svc: VemSubscription) -> some View {
        let palette = VemAccentPalette.resolve(svc.accentTheme)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Header Identity Summary Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.softFill)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: VemFormat.sfSymbol(for: svc.iconName, category: svc.category))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(palette.primary)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(svc.displayTitle)
                                .font(.system(size: 19, weight: .heavy, design: .rounded))
                            Text("\(svc.title) · Réf. \(svc.serviceRef)")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        VemStatusPill(
                            svc.runtimeStatusLabel,
                            tone: svc.isServerStopped ? .amber : .emerald,
                            icon: svc.isServerService
                                ? (svc.isServerStopped ? "pause.circle.fill" : "power.circle.fill")
                                : "checkmark.circle.fill"
                        )
                        VemStatusPill(svc.assignedMemberName, tone: .sky, icon: "person.fill")
                        VemStatusPill(
                            svc.totalMonthlyTtc == 0 ? "0,00 € · Inclus" : "\(VemFormat.euros(svc.totalMonthlyTtc))/mois",
                            tone: .indigo
                        )
                    }

                    // Copyable Technical Identifier
                    Button {
                        UIPasteboard.general.string = svc.technicalIdentifier
                        store.showToast("Identifiant copié : \(svc.technicalIdentifier)")
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(svc.technicalIdentifier)
                                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Text("Copier")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .foregroundStyle(palette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.softFill.opacity(0.8))
                        )
                    }
                    .buttonStyle(VemPressableButtonStyle())
                }
                .vemCard()

                // 2. Retired Offer Warning (if legacy grandfathered plan)
                if !svc.isCommercialized {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(VemTheme.solarAmber)
                            Text("Offre historique protégée (plus commercialisée)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        Text(svc.retiredReason ?? "Cette offre n'est plus commercialisée au catalogue mais votre tarif historique reste garanti.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                        if svc.replacementProductCode != nil {
                            Button {
                                dismiss()
                                store.servicesSegment = 1
                                store.selectedTab = .services
                            } label: {
                                Label("Découvrir la nouvelle gamme équivalente", systemImage: "arrow.up.right.circle.fill")
                                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(VemTheme.electricIndigo)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(VemTheme.solarAmber.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(VemTheme.solarAmber.opacity(0.32), lineWidth: 1)
                            )
                    )
                }

                // 3. STRICT DOMAIN-SPECIFIC TECHNICAL COCKPIT
                if svc.isMandatoryMail {
                    vipleMailCockpitSection(svc, palette: palette)
                } else if svc.isServerService {
                    cloudServerConsoleSection(svc, palette: palette)
                } else if svc.serviceKind == "equipment" {
                    homeEquipmentCockpitSection(svc, palette: palette)
                } else {
                    continuousSubscriptionStatusSection(svc, palette: palette)
                }

                // 4. Nickname & Family Member Assignment
                if !svc.isMandatoryMail || svc.isOwner {
                    personalizationAndFamilySection(svc)
                }

                // 5. Active Options & Compatible Catalog Options
                if !svc.isMandatoryMail {
                    optionsManagementSection(svc, palette: palette)
                }

                // 6. Service Cancellation (Never shown for mandatory free Viple Mail)
                if !svc.isMandatoryMail && svc.permissions.canCancelService {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Zone de résiliation")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(VemTheme.warmCoral)
                        Text("Sans frais cachés : l'arrêt de « \(svc.displayTitle) » prend effet immédiatement et met à jour votre mensualité foyer.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                        Button {
                            VemHaptics.warning()
                            confirmCancelService = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Résilier ce service")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(VemTheme.warmCoral)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(VemTheme.warmCoral.opacity(0.12))
                            )
                        }
                        .buttonStyle(VemPressableButtonStyle())
                    }
                    .vemCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Case A: True Server Console (`isServerService == true` ONLY)

    @ViewBuilder
    private func cloudServerConsoleSection(_ svc: VemSubscription, palette: VemAccentPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Dark Terminal Header
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(svc.isServerStopped ? VemTheme.solarAmber : VemTheme.vipleMint)
                            .frame(width: 9, height: 9)
                        Text(svc.isServerStopped ? "[VIPLE-CLOUD] SERVEUR ARRÊTÉ" : "[VIPLE-CLOUD] SERVEUR DÉMARRÉ")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(svc.isServerStopped ? VemTheme.solarAmber : Color(red: 0.45, green: 0.96, blue: 0.76))
                    }
                    Spacer()
                    Text("KVM NVMe")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Text("Hôte : \(svc.technicalIdentifier)")
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))

                if !svc.metric2Value.isEmpty {
                    Text("Ressources : \(svc.metric2Value)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.055, green: 0.082, blue: 0.145))
            )

            // Storage / Resource Gauge
            HStack(spacing: 14) {
                VemAnimatedRingGauge(
                    used: svc.metric1Used,
                    maximum: svc.metric1Max,
                    palette: palette,
                    size: 58,
                    lineWidth: 6
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(svc.metric1Label) : \(VemFormat.decimal(svc.metric1Used)) / \(VemFormat.decimal(svc.metric1Max)) \(svc.metric1Unit)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(svc.runtimeStatusDetail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
            }

            // Server Power Controls (Reboot + Start/Stop)
            if svc.permissions.canPilotTechnical {
                HStack(spacing: 10) {
                    Button {
                        VemHaptics.impact(.medium)
                        Task { _ = await store.performServiceAction(subscription: svc, action: "reboot") }
                    } label: {
                        Label("Redémarrer", systemImage: "arrow.clockwise.circle.fill")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(VemTheme.electricIndigo)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(VemTheme.electricIndigo.opacity(0.12))
                            )
                    }
                    .buttonStyle(VemPressableButtonStyle())
                    .disabled(store.isMutating)

                    Button {
                        VemHaptics.impact(.heavy)
                        let nextAction = svc.isServerStopped ? "start" : "stop"
                        Task { _ = await store.performServiceAction(subscription: svc, action: nextAction) }
                    } label: {
                        Label(
                            svc.isServerStopped ? "Démarrer le serveur" : "Arrêter le serveur",
                            systemImage: svc.isServerStopped ? "play.circle.fill" : "stop.circle.fill"
                        )
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(svc.isServerStopped ? VemTheme.vipleEmerald : VemTheme.warmCoral)
                        )
                    }
                    .buttonStyle(VemPressableButtonStyle())
                    .disabled(store.isMutating)
                }
            }
        }
        .vemCard()
    }

    // MARK: - Case B: Home Equipment (`box-5g` / `decodeur-tv` — Remote Box Restart ONLY, NO Server Start/Stop!)

    @ViewBuilder
    private func homeEquipmentCockpitSection(_ svc: VemSubscription, palette: VemAccentPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VemAnimatedRingGauge(
                    used: svc.metric1Used,
                    maximum: svc.metric1Max,
                    palette: palette,
                    size: 56,
                    lineWidth: 6
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        VemPulseDot(color: VemTheme.vipleMint)
                        Text("  \(svc.runtimeStatusLabel)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                    }
                    Text(svc.runtimeStatusDetail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                    Text("\(svc.metric1Label) : \(VemFormat.decimal(svc.metric1Used)) / \(VemFormat.decimal(svc.metric1Max)) \(svc.metric1Unit)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.primary)
                }
            }

            if svc.permissions.canPilotTechnical && svc.canReboot {
                Button {
                    VemHaptics.impact(.medium)
                    Task { _ = await store.performServiceAction(subscription: svc, action: "reboot") }
                } label: {
                    Label("Relancer le boîtier à distance", systemImage: "wifi.exclamationmark")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(palette.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.softFill)
                        )
                }
                .buttonStyle(VemPressableButtonStyle())
                .disabled(store.isMutating)
            }
        }
        .vemCard()
    }

    // MARK: - Case C: Continuous Non-Server Services (`forfait-mobile`, `ecosysteme-looby`, `hebergement-web`, `telephonie-sip`)

    @ViewBuilder
    private func continuousSubscriptionStatusSection(_ svc: VemSubscription, palette: VemAccentPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VemAnimatedRingGauge(
                    used: svc.metric1Used,
                    maximum: svc.metric1Max,
                    palette: palette,
                    size: 58,
                    lineWidth: 6
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(VemTheme.vipleEmerald)
                        Text(svc.runtimeStatusLabel)
                            .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                    }
                    Text(svc.runtimeStatusDetail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(svc.metric1Label.uppercased())
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(VemFormat.decimal(svc.metric1Used)) / \(VemFormat.decimal(svc.metric1Max)) \(svc.metric1Unit)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                Spacer()
                if !svc.metric2Value.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text((svc.metric2Label.isEmpty ? "DÉTAIL" : svc.metric2Label).uppercased())
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(svc.metric2Value)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VemTheme.elevatedSurface)
            )

            if svc.category.lowercased() == "ecosysteme-looby" || svc.productCode.lowercased().contains("looby") {
                Button {
                    if let u = URL(string: "https://livria.store") {
                        openURL(u)
                    }
                } label: {
                    Label("Profiter de mes avantages sur Livria Store", systemImage: "books.vertical.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12.5)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.gradient)
                        )
                }
                .buttonStyle(VemPressableButtonStyle())
            }
        }
        .vemCard()
    }

    // MARK: - Case D: Sovereign Viple Mail Inclus (@viplemail.fr + Stalwart Aliases)

    @ViewBuilder
    private func vipleMailCockpitSection(_ svc: VemSubscription, palette: VemAccentPalette) -> some View {
        let mail = store.workspace?.vipleMail ?? VemMailStatus()
        let canEditAliases = store.workspace?.rights.canChangeMailAlias ?? true

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                VemAnimatedRingGauge(
                    used: mail.usedGb,
                    maximum: mail.quotaGb,
                    palette: palette,
                    size: 58,
                    lineWidth: 6
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Messagerie Souveraine @viplemail.fr")
                        .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                    Text("Stockage utilisé : \(VemFormat.decimal(mail.usedGb, maxFraction: 2)) Go sur \(VemFormat.decimal(mail.quotaGb, maxFraction: 0)) Go inclus à vie (0,00 €).")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("IMAP : \(mail.imapServer)", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                Label("SMTP : \(mail.smtpServer)", systemImage: "paperplane.fill")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))

            Button {
                if let u = URL(string: mail.webmailUrl) { openURL(u) }
            } label: {
                Label("Ouvrir le Webmail Viple Mail", systemImage: "envelope.open.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12.5)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(VemTheme.vibrantActionGradient)
                    )
            }
            .buttonStyle(VemPressableButtonStyle())

            Divider()

            // Alias @viplemail.fr Manager (Up to 5 aliases)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Mes alias @viplemail.fr (\(mail.aliases.count)/5)")
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    Spacer()
                }
                Text("Recevez vos courriels sur des adresses secondaires sans dévoiler votre adresse principale.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if mail.aliases.isEmpty {
                    Text("Aucun alias supplémentaire configuré.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(mail.aliases, id: \.self) { al in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(al)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                Spacer()
                                if canEditAliases {
                                    Button {
                                        editingAliasOriginal = al
                                        editingAliasReplacement = al.replacingOccurrences(of: "@viplemail.fr", with: "")
                                    } label: {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(VemTheme.electricIndigo)
                                    }

                                    Button {
                                        Task { _ = await store.manageMailAlias(action: "remove", alias: al) }
                                    } label: {
                                        Image(systemName: "trash.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(VemTheme.warmCoral)
                                    }
                                }
                            }

                            if editingAliasOriginal == al {
                                HStack(spacing: 8) {
                                    TextField("nouvel.alias", text: $editingAliasReplacement)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .font(.system(size: 13, design: .monospaced))
                                        .padding(9)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(VemTheme.cardSurface))
                                    Button("Remplacer") {
                                        let target = editingAliasReplacement
                                        Task {
                                            let ok = await store.manageMailAlias(
                                                action: "replace",
                                                alias: target,
                                                previousAlias: al
                                            )
                                            if ok { editingAliasOriginal = nil }
                                        }
                                    }
                                    .font(.system(size: 12.5, weight: .bold))
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))
                    }
                }

                if canEditAliases && mail.aliases.count < 5 {
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            TextField("mon.alias", text: $newAliasInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 13.5, design: .monospaced))
                            Text("@viplemail.fr")
                                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(VemTheme.elevatedSurface)
                        )

                        Button {
                            let target = newAliasInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !target.isEmpty else { return }
                            Task {
                                let ok = await store.manageMailAlias(action: "add", alias: target)
                                if ok { newAliasInput = "" }
                            }
                        } label: {
                            Text("Ajouter")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10.5)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.vipleEmerald))
                        }
                        .buttonStyle(VemPressableButtonStyle())
                        .disabled(store.isMutating)
                    }
                }
            }
        }
        .vemCard()
    }

    // MARK: - Nickname & Family Member Assignment

    @ViewBuilder
    private func personalizationAndFamilySection(_ svc: VemSubscription) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Personnalisation & Membre du Foyer")
                .font(.system(size: 15.5, weight: .heavy, design: .rounded))

            VStack(alignment: .leading, spacing: 6) {
                Text("Surnom personnalisé (visible par tout le foyer)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("Ex: VPS Minecraft de Hugo, Mobile Chloé…", text: $nicknameInput)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(VemTheme.elevatedSurface)
                        )
                    Button {
                        Task {
                            _ = await store.performServiceAction(
                                subscription: svc,
                                action: "rename",
                                customNickname: nicknameInput
                            )
                        }
                    } label: {
                        Text("Renommer")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10.5)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.electricIndigo))
                    }
                    .buttonStyle(VemPressableButtonStyle())
                    .disabled(store.isMutating)
                }
            }

            if svc.isOwner && !svc.isMandatoryMail, let members = store.workspace?.familyMembers, !members.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attribuer et déléguer ce service à un proche")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)

                    Picker("Membre bénéficiaire", selection: $selectedMemberId) {
                        ForEach(members) { m in
                            let suffix = (m.linkedVipleEmail?.isEmpty == false) ? " (\(m.linkedVipleEmail!))" : ""
                            Text("\(m.firstName) · \(m.relationship)\(suffix)")
                                .tag(m.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))

                    Button {
                        Task {
                            _ = await store.performServiceAction(
                                subscription: svc,
                                action: "assign-member",
                                assignedMemberId: selectedMemberId
                            )
                        }
                    } label: {
                        Label("Confirmer l'attribution familiale", systemImage: "person.2.badge.key.fill")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(VemTheme.vipleEmerald)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(VemTheme.vipleMint.opacity(0.14))
                            )
                    }
                    .buttonStyle(VemPressableButtonStyle())
                    .disabled(store.isMutating)
                }
            }
        }
        .vemCard()
    }

    // MARK: - Active Options & Compatible Catalog Options (Direct Buy OR Family Approval Request!)

    @ViewBuilder
    private func optionsManagementSection(_ svc: VemSubscription, palette: VemAccentPalette) -> some View {
        let catalogOptions = store.compatibleCommercializedOptions(for: svc)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Options du service (\(svc.options.count))")
                    .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                Spacer()
                if !svc.permissions.canPurchaseOptions {
                    VemStatusPill("Validation parentale requise", tone: .amber, icon: "lock.fill")
                }
            }

            if svc.options.isEmpty {
                Text("Aucune option payante active sur ce service.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(svc.options) { opt in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(opt.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                if !opt.isCommercialized {
                                    VemStatusPill("Historique maintenu", tone: .amber)
                                }
                            }
                            Text("+\(VemFormat.euros(opt.priceMonthlyTtc)) / mois")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(palette.primary)
                        }
                        Spacer()
                        if svc.permissions.canPurchaseOptions || svc.isOwner {
                            Button {
                                optionPendingCancel = opt
                            } label: {
                                Text("Résilier")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(VemTheme.warmCoral)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6.5)
                                    .background(Capsule().fill(VemTheme.warmCoral.opacity(0.12)))
                            }
                            .buttonStyle(VemPressableButtonStyle())
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VemTheme.elevatedSurface))
                }
            }

            if !catalogOptions.isEmpty {
                Divider()
                Text("Options compatibles disponibles")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                ForEach(catalogOptions) { opt in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: VemFormat.sfSymbol(for: opt.iconName))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(palette.primary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(palette.softFill))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(opt.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text(opt.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+\(VemFormat.euros(opt.priceMonthlyTtc))/m")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                        }

                        if svc.permissions.canPurchaseOptions {
                            Button {
                                VemHaptics.impact(.medium)
                                Task { _ = await store.activateOption(subscriptionId: svc.id, optionCode: opt.optionCode) }
                            } label: {
                                Label("Activer immédiatement", systemImage: "bolt.circle.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9.5)
                                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(palette.gradient))
                            }
                            .buttonStyle(VemPressableButtonStyle())
                            .disabled(store.isMutating)
                        } else {
                            Button {
                                VemHaptics.selection()
                                requestingOption = opt
                            } label: {
                                Label("Demander au titulaire du foyer", systemImage: "paperplane.circle.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(VemTheme.electricIndigo)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .fill(VemTheme.electricIndigo.opacity(0.13))
                                    )
                            }
                            .buttonStyle(VemPressableButtonStyle())
                        }
                    }
                    .padding(13)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(VemTheme.elevatedSurface))
                }
            }
        }
        .vemCard()
    }
}

// MARK: - Child / Delegated Member Option Request Composer Sheet

private struct OptionApprovalRequestSheet: View {
    @Bindable var store: VemStoreViewModel
    let subscription: VemSubscription
    let option: VemBoutiqueOption
    @State var message: String
    @Environment(\.dismiss) private var dismiss

    init(store: VemStoreViewModel, subscription: VemSubscription, option: VemBoutiqueOption, initialMessage: String) {
        self.store = store
        self.subscription = subscription
        self.option = option
        self._message = State(initialValue: initialMessage)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    VemStatusPill("Demande au titulaire du foyer", tone: .indigo, icon: "person.2.wave.2.fill")
                    Text(option.title)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                    Text("Sur « \(subscription.displayTitle) » · +\(VemFormat.euros(option.priceMonthlyTtc)) TTC / mois")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Petit mot pour expliquer votre besoin")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $message)
                        .frame(height: 110)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VemTheme.cardSurface))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(VemTheme.subtleBorder))
                }

                Button {
                    Task {
                        let ok = await store.sendOptionRequestToOwner(
                            subscriptionId: subscription.id,
                            optionCode: option.optionCode,
                            message: message
                        )
                        if ok { dismiss() }
                    }
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Envoyer la demande d'approbation")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VemTheme.vibrantActionGradient))
                }
                .buttonStyle(VemPressableButtonStyle())
                .disabled(store.isMutating)

                Spacer()
            }
            .padding(20)
            .background(VemTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Demander une option")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
