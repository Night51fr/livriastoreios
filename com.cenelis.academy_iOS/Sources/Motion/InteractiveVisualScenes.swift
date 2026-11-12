import SwiftUI

// MARK: - Moteur Natif des 17 Scènes Motion Design & Simulateurs Interactifs Cenelis Academy

public struct NativeVisualSceneView: View {
    public let sceneId: String

    public init(sceneId: String) {
        self.sceneId = sceneId
    }

    public var body: some View {
        switch sceneId {
        case "cenelis_galaxy":
            CenelisGalaxySceneView()
        case "encryption_simulator":
            EncryptionSimulatorSceneView()
        case "cenelis_connect_flow":
            AnimatedTimelineSceneView(
                badge: "Parcours sécurité animé",
                title: "Comment fonctionne la tranquillité d'1 heure avec Cenelis Connect ?",
                steps: [
                    ("1", "key.fill", "Connexion habituelle", "L'agent se connecte une seule fois avec son compte Viple Live ID habituel."),
                    ("2", "circle.grid.3x3.fill", "Code 4 ou 6 chiffres", "Choisi par vous : validation automatique dès le dernier chiffre, sans bouton « Valider »."),
                    ("3", "bolt.shield.fill", "60 minutes fluides", "Accès direct à toutes vos consoles autorisées pendant 1 heure sans être interrompu."),
                    ("4", "lock.rotation", "Reverrouillage auto", "Après 1 h (ou clic sur « Verrouiller maintenant »), le sas redemande simplement votre code.")
                ]
            )
        case "agents_comparator":
            AgentsComparatorSceneView()
        case "zero_fibre_wave":
            ZeroFibreWaveSceneView()
        case "minecraft_to_pme_cloud":
            MinecraftToPMECloudSceneView()
        case "livria_taker_journey":
            AnimatedTimelineSceneView(
                badge: "Parcours illustré animé",
                title: "Le voyage d'un livre : de l'étagère jusqu'au sourire du voisin relais",
                steps: [
                    ("1", "book.fill", "Commande ou Troc", "Un lecteur choisit un livre neuf, d'occasion vérifiée ou en troc circulaire sur Livria."),
                    ("2", "qrcode.viewfinder", "Assistant Wingman", "L'agent scanne l'ISBN, contrôle l'état pas à pas et édite l'étiquette sans erreur."),
                    ("3", "shippingbox.fill", "Viple Delivery", "Le colis part en tournée locale suivie en temps réel sans détour inutile."),
                    ("4", "hands.sparkles.fill", "Relais Viple Taker", "Un commerçant ou voisin agréé remet le livre contre code de retrait sécurisé.")
                ]
            )
        case "client_consent_handshake":
            ClientConsentHandshakeSceneView()
        case "governance_circles":
            GovernanceCirclesSceneView()
        case "four_pillars_house":
            FourPillarsHouseSceneView()
        case "server_vs_laptop":
            ServerVsLaptopSceneView()
        case "subscription_flywheel":
            SubscriptionFlywheelSceneView()
        case "safety_guardrails":
            SafetyGuardrailsSceneView()
        case "workspace_efficiency_hub":
            WorkspaceEfficiencyHubSceneView()
        case "moderation_triage_simulator":
            ModerationTriageSimulatorView()
        case "marketing_ethical_simulator":
            MarketingEthicalSimulatorView()
        case "prospection_call_simulator":
            ProspectionCallSimulatorView()
        default:
            GenericAnimatedSceneFallback(sceneId: sceneId)
        }
    }
}

// MARK: - Enveloppe Visuelle Commune des Scènes Animées

private struct SceneContainerCard<Content: View>: View {
    let badge: String
    let isCopper: Bool
    let title: String
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(
        badge: String,
        isCopper: Bool = false,
        title: String,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.badge = badge
        self.isCopper = isCopper
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                AcademyBadge(
                    badge,
                    icon: isCopper ? "hand.tap.fill" : "sparkles",
                    style: isCopper ? .copper : .pine
                )
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AcademyPalette.inkSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(isCopper ? AcademyPalette.copperBorder : AcademyPalette.pineBorder, lineWidth: 1.3)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
    }
}

// MARK: - 1. Galaxie Cenelis (Canvas Orbital + Sélection Tactile des 4 Univers)

private struct CenelisGalaxySceneView: View {
    @State private var selectedIndex: Int = 0

    private let universes: [(title: String, sub: String, detail: String, icon: String, color: Color)] = [
        ("VIPLE", "Tech, Télécoms & Colis", "Serveurs Cloud & Dédiés, Zéro Fibre 4G+/5G, StreamBox TV, Viple Mail, Viple Visio et Viple Delivery.", "server.rack", AcademyPalette.pineSolid),
        ("LIVRIA", "Livre & Culture Vivante", "Boutique neuf (Loi Lang) & occasion qualifiée, Troc entre lecteurs et réseau bienveillant LivriaSocial.", "book.fill", AcademyPalette.copperSolid),
        ("LOOBY & TAKER", "Commerce Local & Quartier", "Vitrine numérique des commerçants indépendants et réseau de points relais humains Viple Taker.", "storefront.fill", Color(red: 0.02, green: 0.44, blue: 0.65)),
        ("SOCLE COMMUN", "Institution & Sécurité", "Cenelis Connect (PIN horaire), Cenelis Academy, Cenelis Planner et Newswire : 1 seul compte partout.", "checkmark.shield.fill", Color(red: 0.09, green: 0.52, blue: 0.28))
    ]

    var body: some View {
        SceneContainerCard(
            badge: "Galaxie Motion Design interactive",
            title: "La Galaxie Cenelis : 1 maison commune, 4 grands univers complémentaires",
            footer: "Touchez l'un des 4 satellites autour de Cenelis SA pour explorer comment nos univers se renforcent mutuellement."
        ) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AcademyPalette.surfaceSubtle)
                        .frame(height: 215)

                    TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        Canvas { context, size in
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            let rx = size.width * 0.36
                            let ry: CGFloat = 72

                            var orbit = Path()
                            orbit.addEllipse(in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
                            context.stroke(orbit, with: .color(AcademyPalette.pineSolid.opacity(0.25)), style: StrokeStyle(lineWidth: 1.4, dash: [6, 5]))

                            let corners: [CGPoint] = [
                                CGPoint(x: size.width * 0.22, y: 46),
                                CGPoint(x: size.width * 0.78, y: 46),
                                CGPoint(x: size.width * 0.22, y: size.height - 46),
                                CGPoint(x: size.width * 0.78, y: size.height - 46)
                            ]

                            for (idx, pt) in corners.enumerated() {
                                var line = Path()
                                line.move(to: center)
                                line.addLine(to: pt)
                                let col = universes[idx].color
                                context.stroke(line, with: .color(col.opacity(0.32)), lineWidth: 2)

                                let phase = CGFloat((t * 0.45 + Double(idx) * 0.25).truncatingRemainder(dividingBy: 1.0))
                                let bx = center.x + (pt.x - center.x) * phase
                                let by = center.y + (pt.y - center.y) * phase
                                context.fill(Path(ellipseIn: CGRect(x: bx - 4.5, y: by - 4.5, width: 9, height: 9)), with: .color(col))
                            }
                        }
                    }
                    .frame(height: 215)

                    // Cœur Cenelis SA
                    VStack(spacing: 2) {
                        Text("CENELIS SA")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Maison-mère")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(AcademyPalette.gold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Circle().fill(AcademyPalette.pineSolid).frame(width: 92, height: 92))
                    .shadow(color: AcademyPalette.pineSolid.opacity(0.35), radius: 10)

                    // 4 Satellites cliquables
                    VStack {
                        HStack {
                            galaxyNodeButton(0)
                            Spacer()
                            galaxyNodeButton(1)
                        }
                        Spacer()
                        HStack {
                            galaxyNodeButton(2)
                            Spacer()
                            galaxyNodeButton(3)
                        }
                    }
                    .padding(12)
                    .frame(height: 215)
                }

                // Détail du satellite sélectionné
                let active = universes[selectedIndex]
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: active.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(active.color)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(active.color.opacity(0.14)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(active.title) — \(active.sub)")
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                        Text(active.detail)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AcademyPalette.pineSoft.opacity(0.65))
                )
            }
        }
    }

    private func galaxyNodeButton(_ index: Int) -> some View {
        let u = universes[index]
        let isSelected = (selectedIndex == index)
        return Button {
            AcademyHaptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selectedIndex = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: u.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(u.title)
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : AcademyPalette.ink)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? u.color : AcademyPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(u.color, lineWidth: isSelected ? 0 : 1.5)
                    )
            )
        }
        .buttonStyle(SpringPressableButtonStyle())
    }
}

// MARK: - 2. Simulateur Interactif de Cryptage à Sens Unique

private struct EncryptionSimulatorSceneView: View {
    @State private var plainInput: String = "258046"
    @State private var spinDegrees: Double = 0

    private let presets = ["258046", "MonMotSecret", "BonjourCenelis"]

    var body: some View {
        SceneContainerCard(
            badge: "Simulateur interactif en direct",
            isCopper: true,
            title: "Testez vous-même la « Sécurité par cryptage » (le coffre-fort à sens unique)",
            footer: "Même un administrateur principal ne peut jamais retrouver votre code d'origine à partir de l'empreinte brouillée."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { sample in
                            Button {
                                AcademyHaptics.selection()
                                plainInput = sample
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                                    spinDegrees += 180
                                }
                            } label: {
                                Text("Tester « \(sample) »")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(plainInput == sample ? AcademyPalette.copper : AcademyPalette.surfaceSubtle))
                                    .foregroundStyle(plainInput == sample ? .white : AcademyPalette.ink)
                            }
                            .buttonStyle(SpringPressableButtonStyle())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("1. CE QUE VOUS TAPEZ SUR VOTRE ÉCRAN")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.inkSecondary)

                    TextField("Tapez un code ou un mot secret…", text: $plainInput)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AcademyPalette.surfaceSubtle)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(AcademyPalette.border, lineWidth: 1)
                                )
                        )
                        .onChange(of: plainInput) { _, _ in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                spinDegrees += 90
                            }
                        }
                }

                HStack(spacing: 8) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AcademyPalette.copper)
                        .rotationEffect(.degrees(spinDegrees))
                    Text("Transformation irréversible à sens unique")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AcademyPalette.copper)
                    Spacer()
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(AcademyPalette.pine)
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("2. EMPREINTE RANGÉE DANS LE COFFRE CENELIS")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.gold)

                    Text(deterministicScramble(plainInput))
                        .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AcademyPalette.pineDeep)
                        )
                }
            }
        }
    }

    private func deterministicScramble(_ raw: String) -> String {
        let s = raw.isEmpty ? "vide" : raw
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789#@!$%&*?")
        var seed = 17
        for (i, ch) in s.unicodeScalars.enumerated() {
            seed = (seed * 31 + Int(ch.value) * (i + 7)) % 9973
        }
        var out = ""
        for j in 0..<26 {
            seed = (seed * 73 + j * 19 + s.count * 11) % 9973
            out.append(alphabet[seed % alphabet.count])
        }
        return out
    }
}

// MARK: - 3. Frise Chronologique Animée Générique (Cenelis Connect & Voyage Livre Taker)

private struct AnimatedTimelineSceneView: View {
    let badge: String
    let title: String
    let steps: [(num: String, icon: String, title: String, text: String)]
    @State private var highlightedStep: Int = 0

    var body: some View {
        SceneContainerCard(badge: badge, title: title) {
            VStack(spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    let isLit = (highlightedStep == idx)
                    Button {
                        AcademyHaptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            highlightedStep = idx
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isLit ? AcademyPalette.pineSolid : AcademyPalette.pineSoft)
                                    .frame(width: 34, height: 34)
                                Image(systemName: step.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(isLit ? .white : AcademyPalette.pine)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Étape \(step.num) · \(step.title)")
                                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AcademyPalette.ink)
                                Text(step.text)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(AcademyPalette.inkSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isLit ? AcademyPalette.pineSoft : AcademyPalette.surfaceSubtle)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(isLit ? AcademyPalette.pine : .clear, lineWidth: 1.4)
                                )
                        )
                    }
                    .buttonStyle(SpringPressableButtonStyle())
                }
            }
        }
    }
}

// MARK: - 4. Comparateur Interactif Agent Interne vs Agent Externe

private struct AgentsComparatorSceneView: View {
    @State private var mode: Int = 0 // 0 = Les deux, 1 = Interne, 2 = Externe

    var body: some View {
        SceneContainerCard(
            badge: "Comparateur visuel interactif",
            isCopper: true,
            title: "Agent Interne vs Agent Externe : comparez chaque facette"
        ) {
            VStack(spacing: 12) {
                Picker("Vue", selection: $mode) {
                    Text("Côte à côte").tag(0)
                    Text("Agent Interne").tag(1)
                    Text("Agent Externe").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in AcademyHaptics.selection() }

                if mode == 0 || mode == 1 {
                    roleColumn(
                        badge: "Agent Interne Cenelis / Viple",
                        icon: "building.2.fill",
                        tint: AcademyPalette.pine,
                        softBg: AcademyPalette.pineSoft,
                        subtitle: "Le pilier permanent au cœur du réacteur",
                        bullets: [
                            "Collaborateur intégré directement à l'équipe Cenelis SA (salarié, alternant, référent).",
                            "Horaires coordonnés, réunions sur Viple Visio et suivi Cenelis Planner.",
                            "Accès transverses plus larges pour superviser plusieurs plateformes et accompagner les partenaires."
                        ]
                    )
                }

                if mode == 0 || mode == 2 {
                    roleColumn(
                        badge: "Agent Externe (Gestionnaire Partenaire)",
                        icon: "person.badge.shield.checkmark.fill",
                        tint: AcademyPalette.copper,
                        softBg: AcademyPalette.copperSoft,
                        subtitle: "Le partenaire libre sur une mission claire",
                        bullets: [
                            "Indépendant ayant signé sa convention électronique sur Viple Contractuel (e.GL1, e.GL2, relais Taker…).",
                            "Liberté d'organisation à son rythme, depuis chez soi ou son commerce.",
                            "Périmètre d'accès ciblé exactement sur sa mission pour le protéger à 100 % de toute fausse manipulation."
                        ]
                    )
                }
            }
        }
    }

    private func roleColumn(badge: String, icon: String, tint: Color, softBg: Color, subtitle: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(badge)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
            }
            Text(subtitle)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AcademyPalette.ink)

            ForEach(bullets, id: \.self) { item in
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(tint)
                        .padding(.top, 2)
                    Text(item)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(softBg)
        )
    }
}

// MARK: - 5. Ondes Radio Zéro Fibre 4G+/5G Animées

private struct ZeroFibreWaveSceneView: View {
    var body: some View {
        SceneContainerCard(
            badge: "Schéma animé Télécoms Viple",
            title: "Pourquoi le « Zéro Fibre » dépanne en 2 minutes là où le câble met des mois"
        ) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AcademyPalette.surfaceSubtle)
                        .frame(height: 148)

                    TimelineView(.animation(minimumInterval: 1.0 / 35.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        Canvas { context, size in
                            let src = CGPoint(x: 54, y: size.height / 2)
                            let dstTop = CGPoint(x: size.width - 78, y: 40)
                            let dstBot = CGPoint(x: size.width - 78, y: size.height - 40)

                            // Anneaux radio concentriques
                            for w in 0..<3 {
                                let prog = CGFloat((t * 0.65 + Double(w) * 0.33).truncatingRemainder(dividingBy: 1.0))
                                let radius = 12 + prog * 44
                                let rect = CGRect(x: src.x - radius, y: src.y - radius, width: radius * 2, height: radius * 2)
                                context.stroke(
                                    Path(ellipseIn: rect),
                                    with: .color(AcademyPalette.copperSolid.opacity(Double(1.0 - prog) * 0.7)),
                                    lineWidth: 2
                                )
                            }

                            var p1 = Path()
                            p1.move(to: src)
                            p1.addQuadCurve(to: dstTop, control: CGPoint(x: size.width * 0.48, y: 14))
                            context.stroke(p1, with: .color(AcademyPalette.pineSolid.opacity(0.45)), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))

                            var p2 = Path()
                            p2.move(to: src)
                            p2.addQuadCurve(to: dstBot, control: CGPoint(x: size.width * 0.48, y: size.height - 14))
                            context.stroke(p2, with: .color(AcademyPalette.copperSolid.opacity(0.45)), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        }
                    }
                    .frame(height: 148)

                    HStack {
                        VStack(spacing: 5) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(AcademyPalette.pine)
                            Text("Antenne\n4G+ / 5G")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                        }
                        .padding(10)

                        Spacer()

                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "wifi.router.fill")
                                    .foregroundStyle(AcademyPalette.pine)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("AirBox Foyer & Pro")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    Text("1 prise = Wi-Fi immédiat")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(AcademyPalette.inkSecondary)
                                }
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AcademyPalette.surface))

                            HStack(spacing: 6) {
                                Image(systemName: "tv.and.mediabox.fill")
                                    .foregroundStyle(AcademyPalette.copper)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("StreamBox TV")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    Text("Télé autonome sans box")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(AcademyPalette.inkSecondary)
                                }
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AcademyPalette.surface))
                        }
                        .padding(.trailing, 10)
                    }
                }
            }
        }
    }
}

// MARK: - 6. Explorateur Profils Cloud Viple (Léo 15 ans Minecraft -> PME)

private struct MinecraftToPMECloudSceneView: View {
    @State private var selectedIdx: Int = 0

    private let personas: [(chip: String, icon: String, title: String, body: String)] = [
        ("Léo, 15 ans (Minecraft)", "gamecontroller.fill", "Léo, 15 ans : jouer avec ses 8 amis même PC éteint !", "Si Léo héberge sa partie Minecraft sur le PC du salon, tout coupe dès que ses parents ferment l'ordinateur. Avec un petit serveur Viple, leur monde reste ouvert 24h/24 avec protection Anti-DDoS."),
        ("Association locale", "person.3.fill", "Club sportif ou culturel : exister proprement sur le web", "Réservation de son nom de domaine, hébergement web Viple sans publicité et envoi des albums photos du tournoi aux familles via VipleZip."),
        ("Commerce de quartier", "storefront.fill", "Boulangerie & Fleuriste : zéro perte d'encaissement", "Connexion Zéro Fibre en secours du terminal Carte Bancaire, site vitrine Agence Web Viple et point relais Viple Taker qui attire de nouveaux voisins."),
        ("PME 40 salariés", "building.2.fill", "PME industrielle : souveraineté, mails pro & serveurs dédiés", "Serveurs dédiés en France pour son logiciel métier, boîtes Viple Mail, réunions Viple Visio et support humain réactif en français.")
    ]

    var body: some View {
        SceneContainerCard(
            badge: "Explorateur interactif des profils clients",
            isCopper: true,
            title: "Pas besoin d'être une grande société pour louer un service Viple !"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(personas.enumerated()), id: \.offset) { idx, item in
                            Button {
                                AcademyHaptics.selection()
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    selectedIdx = idx
                                }
                            } label: {
                                Label(item.chip, systemImage: item.icon)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(selectedIdx == idx ? AcademyPalette.pineSolid : AcademyPalette.surfaceSubtle))
                                    .foregroundStyle(selectedIdx == idx ? .white : AcademyPalette.ink)
                            }
                            .buttonStyle(SpringPressableButtonStyle())
                        }
                    }
                }

                let p = personas[selectedIdx]
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.title)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.pine)
                    Text(p.body)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AcademyPalette.pineSoft))
            }
        }
    }
}

// MARK: - 7. Simulation Interactive d'Accord Client par Code Unique (Support 30 min)

private struct ClientConsentHandshakeSceneView: View {
    @State private var stepState: Int = 0 // 0 = verrouillé, 1 = code envoyé, 2 = déverrouillé 30 min

    var body: some View {
        SceneContainerCard(
            badge: "Simulation interactive Support",
            isCopper: true,
            title: "Essayez le geste « Accord du client par code unique » avant toute action sensible"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: stepState == 2 ? "lock.open.rotation" : (stepState == 1 ? "message.badge.filled.fill" : "lock.shield.fill"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(stepState == 2 ? AcademyPalette.success : (stepState == 1 ? AcademyPalette.copper : AcademyPalette.pine))

                    Text(statusMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AcademyPalette.ink)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(stepState == 2 ? AcademyPalette.successSoft : AcademyPalette.surfaceSubtle)
                )

                VStack(spacing: 8) {
                    Button {
                        AcademyHaptics.medium()
                        withAnimation(.spring()) { stepState = 1 }
                    } label: {
                        Label("1. Envoyer un code d'accord au client", systemImage: "paperplane.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 11).fill(stepState == 0 ? AcademyPalette.copper : AcademyPalette.surfaceSubtle))
                            .foregroundStyle(stepState == 0 ? .white : AcademyPalette.inkMuted)
                    }
                    .disabled(stepState != 0)

                    Button {
                        AcademyHaptics.success()
                        withAnimation(.spring()) { stepState = 2 }
                    } label: {
                        Label("2. Valider le code dicté par le client (842 910)", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 11).fill(stepState == 1 ? AcademyPalette.pineSolid : AcademyPalette.surfaceSubtle))
                            .foregroundStyle(stepState == 1 ? .white : AcademyPalette.inkMuted)
                    }
                    .disabled(stepState != 1)

                    if stepState > 0 {
                        Button("Réinitialiser la démonstration") {
                            AcademyHaptics.selection()
                            withAnimation(.spring()) { stepState = 0 }
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                    }
                }
            }
        }
    }

    private var statusMessage: String {
        switch stepState {
        case 0:
            return "Dossier en lecture protégée. Le client au téléphone demande une action sensible : appuyez sur l'étape 1."
        case 1:
            return "Code 842 910 reçu par le client sur son téléphone et dicté à voix haute ! Appuyez sur l'étape 2."
        default:
            return "Accord client vérifié ! Fenêtre légale de 30 minutes ouverte et journalisée automatiquement dans la Fiche 360°."
        }
    }
}

// MARK: - 8. Équilibre Gouvernance (AG + Cenelis SA + Assemblée Commune)

private struct GovernanceCirclesSceneView: View {
    var body: some View {
        SceneContainerCard(
            badge: "Architecture institutionnelle",
            title: "L'équilibre entre Assemblée Générale, Direction Cenelis SA et Assemblée Commune"
        ) {
            VStack(spacing: 10) {
                govPillar(
                    tag: "PILIER LÉGAL & FINANCIER",
                    title: "Assemblée Générale (AG)",
                    desc: "Réunit les actionnaires de Cenelis SA, contrôle les comptes annuels et garantit la solidité juridique durable.",
                    tint: AcademyPalette.pine
                )
                govPillar(
                    tag: "CŒUR EXÉCUTIF · « À TOUS, POUR TOUS, PAR TOUS. »",
                    title: "Cenelis SA (Maison-mère)",
                    desc: "Exécute la feuille de route quotidienne, protège les équipes et relie rigueur légale et écoute humaine.",
                    tint: AcademyPalette.gold,
                    darkCard: true
                )
                govPillar(
                    tag: "PILIER HUMAIN & TERRAIN",
                    title: "Assemblée Commune",
                    desc: "Donne réellement la parole aux forces vives, agents et contributeurs qui bâtissent Cenelis au quotidien.",
                    tint: AcademyPalette.copper
                )
            }
        }
    }

    private func govPillar(tag: String, title: String, desc: String, tint: Color, darkCard: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tag)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(darkCard ? AcademyPalette.gold : tint)
            Text(title)
                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                .foregroundStyle(darkCard ? .white : AcademyPalette.ink)
            Text(desc)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(darkCard ? .white.opacity(0.84) : AcademyPalette.inkSecondary)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(darkCard ? AcademyPalette.pineSolid : AcademyPalette.surfaceSubtle)
        )
    }
}

// MARK: - 9. Maison aux 4 Piliers, 10. Serveur vs PC, 11. Roue Abonnements, 12. Glissières, 13. Bureau 4 Onglets

private struct FourPillarsHouseSceneView: View {
    var body: some View {
        SceneContainerCard(
            badge: "Architecture du Groupe",
            title: "Un seul toit protecteur (Cenelis SA) soutenu par nos 4 grands piliers métiers"
        ) {
            VStack(spacing: 8) {
                Text("TOIT COMMUN : CENELIS SA · ANCRAGE CHARLEVILLE-MÉZIÈRES")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AcademyPalette.pineSolid))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    pillarTile("1. CENELIS", "Connect · Academy · Planner · Newswire", AcademyPalette.pine)
                    pillarTile("2. VIPLE", "Serveurs · Zéro Fibre · Mail · Delivery", AcademyPalette.sky)
                    pillarTile("3. LIVRIA", "Neuf · Occasion · LivriaSocial · Troc", AcademyPalette.copper)
                    pillarTile("4. LOOBY", "Boutiques locales & Relais Taker", AcademyPalette.success)
                }

                Text("SOCLE UNIQUE : 1 seul compte Viple Live ID · 1 sécurité Cenelis Connect")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AcademyPalette.pine)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AcademyPalette.pineSoft))
            }
        }
    }

    private func pillarTile(_ title: String, _ sub: String, _ col: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12.5, weight: .black, design: .rounded))
                .foregroundStyle(col)
            Text(sub)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(AcademyPalette.inkSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AcademyPalette.surfaceSubtle)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(col.opacity(0.45), lineWidth: 1.2))
        )
    }
}

private struct ServerVsLaptopSceneView: View {
    var body: some View {
        SceneContainerCard(
            badge: "Comparaison visuelle",
            isCopper: true,
            title: "Ordinateur du salon vs Serveur Cloud Viple : pourquoi tout change ?"
        ) {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "laptopcomputer.slash")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AcademyPalette.danger)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ordinateur personnel à la maison")
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        Text("S'éteint dès qu'on ferme le capot le soir, chauffe et coupe au moindre orage : amis ou visiteurs bloqués.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 13).fill(AcademyPalette.dangerSoft))

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AcademyPalette.success)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Serveur Cloud Viple (24h/24 · 7j/7)")
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        Text("Électricité et réseau secourus, Anti-DDoS actif, très haut débit fluide jour et nuit sans bruit à la maison.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 13).fill(AcademyPalette.successSoft))
            }
        }
    }
}

private struct SubscriptionFlywheelSceneView: View {
    var body: some View {
        SceneContainerCard(
            badge: "Roue de l'équilibre Viple",
            title: "Comment chaque famille de clients renforce la solidité durable de Viple"
        ) {
            VStack(spacing: 9) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    flywheelItem("Jeunes & Particuliers", "Enthousiasme & bouche-à-oreille", "sparkles")
                    flywheelItem("Associations", "Fidélité sur plusieurs années", "heart.circle.fill")
                    flywheelItem("Commerçants", "Secours TPE & Relais Taker", "bag.fill")
                    flywheelItem("PME & Sur-mesure", "Forte valeur ajoutée mensuelle", "building.columns.fill")
                }
                HStack(spacing: 8) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AcademyPalette.gold)
                    Text("Solidité mensuelle récurrente · Zéro tarif piège · Réinvestissement continu")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(11)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.pineSolid))
            }
        }
    }

    private func flywheelItem(_ title: String, _ sub: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(AcademyPalette.pine)
            Text(title)
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(AcademyPalette.inkSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))
    }
}

private struct SafetyGuardrailsSceneView: View {
    var body: some View {
        SceneContainerCard(
            badge: "Protection bienveillante RBAC",
            title: "Le périmètre d'accès : comme les glissières d'une route qui vous protègent à 100 %"
        ) {
            VStack(spacing: 8) {
                Text("GLISSIÈRE HAUTE : Serveurs critiques fermés = Zéro risque de fausse manip")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(AcademyPalette.copper)
                    .padding(9)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AcademyPalette.copperSoft))

                VStack(spacing: 4) {
                    Text("VOTRE VOIE DE MISSION OUVERTE & FLUIDE")
                        .font(.system(size: 13.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Tous vos outils métier sont là, guidés pas à pas par Wingman en toute confiance.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(13)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 13).fill(AcademyPalette.pineSolid))

                Text("GLISSIÈRE BASSE : Protection juridique — aucun incident hors mission ne peut vous être imputé")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(AcademyPalette.copper)
                    .padding(9)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AcademyPalette.copperSoft))
            }
        }
    }
}

private struct WorkspaceEfficiencyHubSceneView: View {
    @State private var activeBrowserTab: Int = 0
    private let browserTabs: [(label: String, desc: String)] = [
        ("📌 /portail", "Toujours épinglé tout à gauche : affiche votre compteur PIN 60 min en direct et ouvre toutes vos consoles en 1 clic."),
        ("2. Viple Mail", "Votre messagerie souveraine @viplemail.fr pour les réponses officielles et invitations agenda .ics."),
        ("3. Planner", "Vos créneaux d'équipe, rappels de rappels prospects et réunions Viple Visio de la journée."),
        ("4. Console + Alt+A", "Votre outil métier actif, avec le raccourci clavier Alt + A (ou bouton ☰ sur mobile) pour basculer sans ressaisie.")
    ]

    var body: some View {
        SceneContainerCard(
            badge: "Astuce Pro Cenelis · Bureau idéal",
            isCopper: true,
            title: "L'organisation en 4 onglets fixes des agents Cenelis les plus rapides"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(browserTabs.enumerated()), id: \.offset) { idx, t in
                            Button {
                                AcademyHaptics.selection()
                                activeBrowserTab = idx
                            } label: {
                                Text(t.label)
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(activeBrowserTab == idx ? (idx == 0 ? AcademyPalette.copperSolid : AcademyPalette.pineSolid) : AcademyPalette.surfaceSubtle))
                                    .foregroundStyle(activeBrowserTab == idx ? .white : AcademyPalette.ink)
                            }
                            .buttonStyle(SpringPressableButtonStyle())
                        }
                    }
                }

                Text(browserTabs[activeBrowserTab].desc)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AcademyPalette.inkSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))
            }
        }
    }
}

// MARK: - 14. Simulateur Métier Modération Graduée (3 Cas Réels)

private struct ModerationTriageSimulatorView: View {
    @State private var caseIndex: Int = 0
    @State private var chosenAction: Int? = nil

    private struct ModCase {
        let label: String
        let quote: String
        let bestAction: Int
        let explanations: [String]
    }

    private let cases: [ModCase] = [
        ModCase(
            label: "Cas 1 · Avis critique",
            quote: "« J'ai trouvé le rythme du tome 2 beaucoup trop lent malgré une belle écriture, je suis déçue par rapport au premier volet. »",
            bestAction: 0,
            explanations: [
                "Bravo ! Un avis critique mais courtois fait pleinement partie de la liberté culturelle sur LivriaSocial : on classe sans suite.",
                "Attention : ne jamais avertir un lecteur parce qu'il n'a pas aimé un roman tant qu'il reste poli !",
                "Erreur à éviter : retirer un avis courtois serait de la censure injustifiée."
            ]
        ),
        ModCase(
            label: "Cas 2 · Spoiler sauvage",
            quote: "« Liste rémunérée : Voici les 6 polars où le détective est lui-même le coupable à la dernière page ! »",
            bestAction: 1,
            explanations: [
                "Pas tout à fait : dévoiler la fin de 6 romans dès le titre public gâche la découverte des autres lecteurs.",
                "Exactement ! C'est une maladresse sans malveillance : un Avertissement pédagogique invitant à masquer le spoiler suffit.",
                "Trop sévère en première intention : l'Avertissement pédagogique permet au membre de corriger sa liste."
            ]
        ),
        ModCase(
            label: "Cas 3 · Lien Phishing",
            quote: "« Gagnez un bon cadeau immédiatement en cliquant sur ce lien externe raccourci bit-promo-livres[.]xyz !! »",
            bestAction: 2,
            explanations: [
                "Danger ! Laisser un lien frauduleux exposerait nos membres au vol de leurs identifiants.",
                "Insuffisant face à un spam frauduleux : le lien piégé resterait actif.",
                "Réflexe parfait ! Retrait immédiat + ouverture en 1 clic de la Fiche 360° GVN_u pour suspendre le compte spammeur."
            ]
        )
    ]

    var body: some View {
        let current = cases[caseIndex]
        SceneContainerCard(
            badge: "Simulateur Métier · Poste Modérateur",
            title: "Entraînez votre discernement : quelle décision prendre sur ces 3 signalements ?"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(cases.enumerated()), id: \.offset) { idx, c in
                            Button {
                                AcademyHaptics.selection()
                                caseIndex = idx
                                chosenAction = nil
                            } label: {
                                Text(c.label)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6.5)
                                    .background(Capsule().fill(caseIndex == idx ? AcademyPalette.pineSolid : AcademyPalette.surfaceSubtle))
                                    .foregroundStyle(caseIndex == idx ? .white : AcademyPalette.ink)
                            }
                        }
                    }
                }

                Text(current.quote)
                    .font(.system(size: 13.5, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(AcademyPalette.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))

                VStack(spacing: 7) {
                    modButton(0, "1. Classer sans suite", "checkmark.circle")
                    modButton(1, "2. Avertissement pédagogique", "exclamationmark.bubble.fill")
                    modButton(2, "3. Retirer + Ouvrir Fiche 360° GVN_u", "shield.lefthalf.filled.slash")
                }

                if let act = chosenAction {
                    let isGood = (act == current.bestAction)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: isGood ? "checkmark.seal.fill" : "info.circle.fill")
                            .foregroundStyle(isGood ? AcademyPalette.success : AcademyPalette.copper)
                        Text(current.explanations[act])
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AcademyPalette.ink)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(isGood ? AcademyPalette.successSoft : AcademyPalette.copperSoft))
                }
            }
        }
    }

    private func modButton(_ index: Int, _ label: String, _ icon: String) -> some View {
        let isSelected = (chosenAction == index)
        return Button {
            let ok = (index == cases[caseIndex].bestAction)
            if ok { AcademyHaptics.success() } else { AcademyHaptics.warning() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                chosenAction = index
            }
        } label: {
            HStack {
                Image(systemName: icon)
                Text(label)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : AcademyPalette.ink)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? AcademyPalette.pineSolid : AcademyPalette.surfaceSubtle))
        }
        .buttonStyle(SpringPressableButtonStyle())
    }
}

// MARK: - 15. Laboratoire Interactif Score Éthique & Légal Marketing (/100)

private struct MarketingEthicalSimulatorView: View {
    @State private var optIn = true
    @State private var loiLang = true
    @State private var sincerePricing = true
    @State private var mobileTested = true

    private var score: Int {
        (optIn ? 25 : 0) + (loiLang ? 25 : 0) + (sincerePricing ? 25 : 0) + (mobileTested ? 25 : 0)
    }

    var body: some View {
        SceneContainerCard(
            badge: "Laboratoire Interactif · Poste Marketing",
            isCopper: true,
            title: "Testez en direct le Score Éthique & Légal (/100) d'une campagne Cenelis"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    AnimatedMasteryRing(
                        progress: Double(score) / 100.0,
                        size: 58,
                        lineWidth: 6,
                        tint: score == 100 ? AcademyPalette.success : AcademyPalette.copper,
                        centerText: "\(score)"
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(score == 100 ? "Campagne exemplaire (100/100)" : "Points à corriger (\(score)/100)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(score == 100 ? AcademyPalette.success : AcademyPalette.copper)
                        Text(score == 100
                             ? "Tous les feux RGPD, Loi Lang et Mobile 375 px sont au vert pour Stalwart (viplemail.fr)."
                             : "Activez les 4 garde-fous indispensables avant tout envoi de campagne.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                    }
                }

                VStack(spacing: 8) {
                    Toggle("Destinataires Opt-in + Désinscription 1 clic", isOn: $optIn)
                    Toggle("Respect Loi Lang (zéro promo sauvage sur livre neuf)", isOn: $loiLang)
                    Toggle("Zéro prix inventé ni fausse urgence anxiogène", isOn: $sincerePricing)
                    Toggle("Variable {{prenom}} + Aperçu Mobile 375 px vérifié", isOn: $mobileTested)
                }
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .tint(AcademyPalette.pine)
                .onChange(of: score) { _, _ in AcademyHaptics.selection() }
            }
        }
    }
}

// MARK: - 16. Simulateur d'Appel Prospection & RDV (Zéro Prix Improvisé)

private struct ProspectionCallSimulatorView: View {
    @State private var roleIdx: Int = 0

    private let scripts: [(label: String, question: String, value: String, nextStep: String)] = [
        (
            "Commerçant (TPE / Fibre)",
            "« Comment réagit votre terminal Carte Bancaire quand la ligne internet de la rue coupe un vendredi après-midi ? »",
            "Continuité cellulaire Viple Zéro Fibre 4G+/5G immédiate sans travaux de voirie.",
            "Zéro tarif improvisé à l'oral → planifier un RDV Viple Visio de 15 min avec invitation .ics automatique."
        ),
        (
            "Boutique (Relais Taker)",
            "« Avez-vous observé combien de nouveaux voisins entrent dans un commerce indépendant pour retirer un livre ou colis local ? »",
            "Flux piéton régulier, indemnité transparente par colis et scan en 10 s sur smartphone via Viple Wingman.",
            "Proposer une démonstration de 10 min en boutique ou sur Viple Visio et envoyer le récapitulatif par Viple Mail."
        ),
        (
            "Dirigeant PME (Sur-mesure)",
            "« Avez-vous aujourd'hui un interlocuteur technique français direct quand votre site ou vos boîtes mail doivent évoluer ? »",
            "Agence Web « Haute Couture » (.NET / Next.js sans commission sur les ventes) + hébergement souverain français.",
            "Un projet sur mesure ne se chiffre jamais à la volée : qualifier le besoin dans le Cockpit d'Appel puis fixer un RDV d'étude."
        ),
        (
            "Parent / Jeune 15 ans",
            "« Vous cherchez un serveur Minecraft entre amis avec des mods sans subir de coupures ni de mauvaise surprise ? »",
            "Pas besoin d'être une entreprise pour être respecté chez Viple : Anti-DDoS inclus et accompagnement bienveillant.",
            "Orienter vers les offres publiques officielles de l'espace Viple sans jamais inventer de remise orale."
        )
    ]

    var body: some View {
        let cur = scripts[roleIdx]
        SceneContainerCard(
            badge: "Simulateur d'Appel · Prospection & RDV",
            title: "Choisissez un interlocuteur pour afficher l'accroche d'écoute et le bon réflexe"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(scripts.enumerated()), id: \.offset) { idx, item in
                            Button {
                                AcademyHaptics.selection()
                                roleIdx = idx
                            } label: {
                                Text(item.label)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6.5)
                                    .background(Capsule().fill(roleIdx == idx ? AcademyPalette.pineSolid : AcademyPalette.surfaceSubtle))
                                    .foregroundStyle(roleIdx == idx ? .white : AcademyPalette.ink)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    scriptRow(num: "1. Question d'écoute", text: cur.question, color: AcademyPalette.pine)
                    scriptRow(num: "2. Valeur concrète", text: cur.value, color: AcademyPalette.copper)
                    scriptRow(num: "3. Réflexe Prix & Suite", text: cur.nextStep, color: AcademyPalette.ink)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 13).fill(AcademyPalette.surfaceSubtle))
            }
        }
    }

    private func scriptRow(num: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(num)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(AcademyPalette.inkSecondary)
        }
    }
}

private struct GenericAnimatedSceneFallback: View {
    let sceneId: String
    var body: some View {
        SceneContainerCard(badge: "Schéma interactif Cenelis", title: "Illustration interactive (\(sceneId))") {
            Text("Module interactif synchronisé depuis Cenelis Academy.")
                .font(.system(size: 13))
                .foregroundStyle(AcademyPalette.inkSecondary)
        }
    }
}
