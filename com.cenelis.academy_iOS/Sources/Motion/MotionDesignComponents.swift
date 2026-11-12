import SwiftUI

// MARK: - 1. Écran d'Ouverture Motion Design « Sceau Orbital Cenelis Academy »

public struct AcademyLaunchSplashView: View {
    @State private var appeared = false

    public init() {}

    public var body: some View {
        ZStack {
            AcademyPalette.heroGradient
                .ignoresSafeArea()

            // Constellation orbitale animée à 60 fps sur Canvas
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height * 0.43)
                    let radii: [CGFloat] = [88, 136, 188]

                    for (idx, r) in radii.enumerated() {
                        let rect = CGRect(x: center.x - r, y: center.y - r * 0.76, width: r * 2, height: r * 1.52)
                        var orbitPath = Path()
                        orbitPath.addEllipse(in: rect)
                        context.stroke(
                            orbitPath,
                            with: .color(Color.white.opacity(0.11 - Double(idx) * 0.025)),
                            style: StrokeStyle(lineWidth: 1.2, dash: [6, 6])
                        )

                        let speed = (idx % 2 == 0 ? 0.65 : -0.48) * (1.0 - Double(idx) * 0.15)
                        let angle = t * speed + Double(idx) * 1.7
                        let px = center.x + CGFloat(cos(angle)) * r
                        let py = center.y + CGFloat(sin(angle)) * (r * 0.76)

                        let dotColor: Color = (idx == 1) ? AcademyPalette.gold : Color(red: 0.94, green: 0.56, blue: 0.22)
                        let haloRect = CGRect(x: px - 10, y: py - 10, width: 20, height: 20)
                        context.fill(Path(ellipseIn: haloRect), with: .color(dotColor.opacity(0.28)))
                        let dotRect = CGRect(x: px - 4.5, y: py - 4.5, width: 9, height: 9)
                        context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AcademyPalette.copperSolid.opacity(0.24))
                        .frame(width: 122, height: 122)
                        .scaleEffect(appeared ? 1.08 : 0.88)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: appeared)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.11, green: 0.44, blue: 0.37),
                                    Color(red: 0.05, green: 0.22, blue: 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(AcademyPalette.gold.opacity(0.65), lineWidth: 1.8)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, AcademyPalette.gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(appeared ? 1.0 : 0.82)
                .opacity(appeared ? 1.0 : 0.0)

                VStack(spacing: 8) {
                    Text("CENELIS ACADEMY")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(.white)

                    Text("« À tous, pour tous, par tous. »")
                        .font(.system(size: 14.5, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(AcademyPalette.gold)
                }
                .opacity(appeared ? 1.0 : 0.0)
                .offset(y: appeared ? 0 : 12)

                Spacer()

                HStack(spacing: 10) {
                    ProgressView()
                        .tint(AcademyPalette.gold)
                    Text("Synchronisation des parcours officiels…")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.10)))
                .padding(.bottom, 38)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.76)) {
                appeared = true
            }
        }
    }
}

// MARK: - 2. Bandeau Hero Motion Design « Galaxie Orbitale & Tableau de Bord XP »

public struct OrbitalConstellationHeroView: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @State private var pulseWave: Bool = false

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let rank = vm.currentRank

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AcademyPalette.heroGradient)

            // Scène Motion Design Canvas en arrière-plan
            TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let hub = CGPoint(x: size.width * 0.82, y: size.height * 0.30)

                    for ring in 0..<3 {
                        let rx = CGFloat(55 + ring * 42)
                        let ry = CGFloat(34 + ring * 25)
                        let rect = CGRect(x: hub.x - rx, y: hub.y - ry, width: rx * 2, height: ry * 2)
                        var p = Path()
                        p.addEllipse(in: rect)
                        context.stroke(
                            p,
                            with: .color(.white.opacity(0.10 - Double(ring) * 0.02)),
                            style: StrokeStyle(lineWidth: 1.1, dash: [5, 5])
                        )

                        let angle = t * (ring % 2 == 0 ? 0.75 : -0.55) + Double(ring) * 2.1
                        let nx = hub.x + CGFloat(cos(angle)) * rx
                        let ny = hub.y + CGFloat(sin(angle)) * ry
                        let col: Color = ring == 1 ? AcademyPalette.gold : Color(red: 0.95, green: 0.58, blue: 0.24)
                        context.fill(Path(ellipseIn: CGRect(x: nx - 8, y: ny - 8, width: 16, height: 16)), with: .color(col.opacity(0.25)))
                        context.fill(Path(ellipseIn: CGRect(x: nx - 3.5, y: ny - 3.5, width: 7, height: 7)), with: .color(col))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                // En-tête : Identité & Série Quotidienne
                HStack(alignment: .center, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: rank.sfSymbol)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AcademyPalette.gold)
                        Text("RANG \(rank.level) · \(rank.title.uppercased())")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.14)))

                    Spacer()

                    // Flamme de série quotidienne
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.18))
                            .scaleEffect(pulseWave ? 1.12 : 0.96)
                        Text("\(max(1, vm.progress.streakDays)) j")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.24)))
                }

                // Salutation & Accroche
                VStack(alignment: .leading, spacing: 5) {
                    Text(greetingTitle)
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Tout l'univers Cenelis, Viple, Livria & Looby expliqué simplement, animé et synchronisé en direct.")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Barre XP + Objectif du jour
                HStack(spacing: 14) {
                    AnimatedMasteryRing(
                        progress: vm.dailyGoalFraction,
                        size: 56,
                        lineWidth: 6,
                        tint: AcademyPalette.gold,
                        trackColor: .white.opacity(0.16),
                        centerText: "\(Int((vm.dailyGoalFraction * 100).rounded()))%",
                        textColor: .white
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(vm.progress.xp) XP cumulés")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            if let nextXP = rank.nextMinXP {
                                Text("Prochain rang : \(nextXP) XP")
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AcademyPalette.gold)
                            } else {
                                Text("Rang maximal atteint")
                                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(AcademyPalette.gold)
                            }
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.16))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AcademyPalette.gold, Color(red: 0.95, green: 0.53, blue: 0.19)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(10, geo.size.width * rank.progressFraction(forXP: vm.progress.xp)))
                            }
                        }
                        .frame(height: 8)

                        Text("Objectif du jour : \(vm.todayEarnedXP) / \(vm.progress.dailyGoalXP) XP · \(vm.progress.completedParts.count) pages assimilées")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                        )
                )
            }
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(AcademyPalette.pineBorder.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: AcademyPalette.pineDeep.opacity(0.22), radius: 16, y: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                pulseWave = true
            }
        }
    }

    private var greetingTitle: String {
        if vm.learner.authenticated && !vm.learner.displayName.isEmpty {
            let first = vm.learner.displayName.split(separator: " ").first.map(String.init) ?? vm.learner.displayName
            return "Bonjour, \(first)"
        }
        return "Bienvenue à Cenelis Academy"
    }
}

// MARK: - 3. Anneau de Progression Animé au Ressort

public struct AnimatedMasteryRing: View {
    public let progress: Double
    public var size: CGFloat = 52
    public var lineWidth: CGFloat = 5.5
    public var tint: Color = AcademyPalette.pine
    public var trackColor: Color = AcademyPalette.pineSoft
    public var centerText: String? = nil
    public var textColor: Color = AcademyPalette.ink

    public init(
        progress: Double,
        size: CGFloat = 52,
        lineWidth: CGFloat = 5.5,
        tint: Color = AcademyPalette.pine,
        trackColor: Color = AcademyPalette.pineSoft,
        centerText: String? = nil,
        textColor: Color = AcademyPalette.ink
    ) {
        self.progress = min(1.0, max(0.0, progress))
        self.size = size
        self.lineWidth = lineWidth
        self.tint = tint
        self.trackColor = trackColor
        self.centerText = centerText
        self.textColor = textColor
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.55, dampingFraction: 0.8), value: progress)

            if let centerText {
                Text(centerText)
                    .font(.system(size: size * 0.24, weight: .heavy, design: .rounded))
                    .foregroundStyle(textColor)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 4. Passeport Holographique 3D Tactile (Inclinaison Gyroscopique au Doigt)

public struct HolographicPassportCard: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @State private var dragOffset: CGSize = .zero

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let rank = vm.currentRank
        let certifiedCount = vm.visibleHomeCourses.filter { vm.isCourseCertified($0) }.count

        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.34, blue: 0.28),
                            Color(red: 0.04, green: 0.17, blue: 0.14),
                            Color(red: 0.18, green: 0.12, blue: 0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Reflet holographique mobile piloté par le doigt
            GeometryReader { geo in
                let sheenX = geo.size.width * 0.5 + dragOffset.width * 1.4
                let sheenY = geo.size.height * 0.5 + dragOffset.height * 1.4
                RadialGradient(
                    colors: [
                        AcademyPalette.gold.opacity(0.32),
                        AcademyPalette.copperSolid.opacity(0.16),
                        .clear
                    ],
                    center: UnitPoint(
                        x: min(1.1, max(-0.1, sheenX / max(1, geo.size.width))),
                        y: min(1.1, max(-0.1, sheenY / max(1, geo.size.height)))
                    ),
                    startRadius: 12,
                    endRadius: 210
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PASSEPORT D'EXCELLENCE CENELIS SA")
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .tracking(1.1)
                            .foregroundStyle(AcademyPalette.gold)
                        Text(vm.learner.authenticated ? vm.learner.displayName : "Apprenant Mobile Cenelis")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(vm.learner.authenticated ? vm.learner.email : "Connectez Viple Live ID pour synchroniser vos attestations")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.14))
                            .frame(width: 52, height: 52)
                        Image(systemName: rank.sfSymbol)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AcademyPalette.gold)
                    }
                }

                Divider()
                    .overlay(.white.opacity(0.18))

                HStack(spacing: 0) {
                    passportStat(value: "\(vm.progress.xp)", label: "Points XP")
                    Spacer()
                    passportStat(value: "Nv. \(rank.level)", label: rank.title)
                    Spacer()
                    passportStat(value: "\(certifiedCount)/\(max(1, vm.visibleHomeCourses.count))", label: "Certifiés")
                    Spacer()
                    passportStat(value: "\(vm.progress.unlockedBadges.count)/\(AcademyTrophy.catalog.count)", label: "Trophées")
                }

                HStack {
                    Label("Glissez le doigt pour incliner le sceau 3D", systemImage: "hand.draw.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                    Spacer()
                    Text("CHARLEVILLE-MÉZIÈRES")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AcademyPalette.gold.opacity(0.88))
                }
            }
            .padding(22)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [AcademyPalette.gold.opacity(0.75), .white.opacity(0.2), AcademyPalette.copperSolid.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.26), radius: 18, y: 10)
        .rotation3DEffect(
            .degrees(Double(-dragOffset.height / 10)),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.7
        )
        .rotation3DEffect(
            .degrees(Double(dragOffset.width / 10)),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.7
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    let clampedW = min(95, max(-95, val.translation.width))
                    let clampedH = min(75, max(-75, val.translation.height))
                    dragOffset = CGSize(width: clampedW, height: clampedH)
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                        dragOffset = .zero
                    }
                }
        )
    }

    private func passportStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16.5, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
        }
    }
}

// MARK: - 5. Bulle Flottante de Gain d'XP (+XP) & Pluie de Confettis Physique

public struct FloatingXPToastView: View {
    public let item: XPToastItem

    public init(item: XPToastItem) {
        self.item = item
    }

    public var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.isMajor ? AcademyPalette.gold : AcademyPalette.pineSolid)
                    .frame(width: 30, height: 30)
                Image(systemName: item.isMajor ? "crown.fill" : "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(item.isMajor ? Color.black : Color.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("+\(item.amount) XP")
                    .font(.system(size: 13.5, weight: .black, design: .rounded))
                    .foregroundStyle(AcademyPalette.pine)
                Text(item.label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(item.isMajor ? AcademyPalette.gold : AcademyPalette.pineBorder, lineWidth: 1.4)
                )
                .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        )
    }
}

public struct ConfettiBurstOverlayView: View {
    public let trigger: Int
    @State private var burstStart: Date? = nil

    private struct ParticleSeed: Sendable {
        let angle: Double
        let speed: Double
        let spin: Double
        let size: CGFloat
        let colorIndex: Int
    }

    private let seeds: [ParticleSeed] = (0..<46).map { i in
        let frac = Double(i) / 46.0
        return ParticleSeed(
            angle: -Double.pi * (0.12 + 0.76 * frac),
            speed: 260 + Double((i * 53) % 240),
            spin: Double((i % 2 == 0 ? 1 : -1) * (3 + (i % 5))),
            size: CGFloat(6 + (i % 6)),
            colorIndex: i % 4
        )
    }

    public init(trigger: Int) {
        self.trigger = trigger
    }

    public var body: some View {
        Group {
            if let start = burstStart {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    if elapsed < 2.6 {
                        Canvas { context, size in
                            let origin = CGPoint(x: size.width / 2, y: size.height * 0.22)
                            let palette: [Color] = [
                                AcademyPalette.pineSolid,
                                AcademyPalette.copperSolid,
                                AcademyPalette.gold,
                                Color(red: 0.16, green: 0.68, blue: 0.52)
                            ]
                            let gravity = 460.0

                            for seed in seeds {
                                let vx = cos(seed.angle) * seed.speed
                                let vy = sin(seed.angle) * seed.speed
                                let x = origin.x + CGFloat(vx * elapsed)
                                let y = origin.y + CGFloat(vy * elapsed + 0.5 * gravity * elapsed * elapsed)
                                let alpha = max(0, 1.0 - elapsed / 2.5)

                                var ctxCopy = context
                                ctxCopy.translateBy(x: x, y: y)
                                ctxCopy.rotate(by: .radians(seed.spin * elapsed))
                                let rect = CGRect(x: -seed.size / 2, y: -seed.size * 0.35, width: seed.size, height: seed.size * 0.7)
                                ctxCopy.fill(
                                    Path(roundedRect: rect, cornerRadius: 2),
                                    with: .color(palette[seed.colorIndex].opacity(alpha))
                                )
                            }
                        }
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .onChange(of: trigger) { _, _ in
            burstStart = Date()
        }
    }
}
