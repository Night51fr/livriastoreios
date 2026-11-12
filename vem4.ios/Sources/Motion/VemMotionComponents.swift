import SwiftUI

// MARK: - Motion Design & Interactive Visual Components for Viple & Moi

public struct VemAuroraBackgroundCard<Content: View>: View {
    private let cornerRadius: CGFloat
    @ViewBuilder private let content: () -> Content
    @State private var animateOrbs = false

    public init(cornerRadius: CGFloat = 28, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(VemTheme.auroraHeroGradient)

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(VemTheme.vipleMint.opacity(0.32))
                        .frame(width: 210, height: 210)
                        .blur(radius: 42)
                        .offset(
                            x: animateOrbs ? -35 : 25,
                            y: animateOrbs ? -40 : 10
                        )

                    Circle()
                        .fill(VemTheme.electricIndigo.opacity(0.38))
                        .frame(width: 240, height: 240)
                        .blur(radius: 48)
                        .offset(
                            x: geo.size.width * 0.45 + (animateOrbs ? 24 : -24),
                            y: geo.size.height * 0.25 + (animateOrbs ? -20 : 20)
                        )

                    Circle()
                        .fill(VemTheme.warmCoral.opacity(0.22))
                        .frame(width: 160, height: 160)
                        .blur(radius: 40)
                        .offset(
                            x: geo.size.width * 0.25,
                            y: geo.size.height * 0.55 + (animateOrbs ? 16 : -12)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            content()
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: VemTheme.vipleEmerald.opacity(0.26), radius: 20, x: 0, y: 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true)) {
                animateOrbs = true
            }
        }
    }
}

// MARK: - Breathing Live Status Dot

public struct VemPulseDot: View {
    public var color: Color = VemTheme.vipleMint
    @State private var pulse = false

    public init(color: Color = VemTheme.vipleMint) {
        self.color = color
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: 16, height: 16)
                .scaleEffect(pulse ? 1.45 : 0.85)
                .opacity(pulse ? 0.0 : 0.75)

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Animated Circular Gauge Ring

public struct VemAnimatedRingGauge: View {
    public let used: Double
    public let maximum: Double
    public let palette: VemAccentPalette
    public var size: CGFloat = 54
    public var lineWidth: CGFloat = 6

    @State private var animatedProgress: CGFloat = 0

    public init(used: Double, maximum: Double, palette: VemAccentPalette, size: CGFloat = 54, lineWidth: CGFloat = 6) {
        self.used = used
        self.maximum = maximum
        self.palette = palette
        self.size = size
        self.lineWidth = lineWidth
    }

    private var targetProgress: CGFloat {
        guard maximum > 0 else { return 0.15 }
        let raw = CGFloat(used / maximum)
        return min(1.0, max(0.05, raw))
    }

    private var percentageLabel: String {
        guard maximum > 0 else { return "Actif" }
        let pct = Int((used / maximum * 100.0).rounded())
        return "\(min(100, max(1, pct)))%"
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(palette.primary.opacity(0.14), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [palette.primary, palette.secondary, palette.primary],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(percentageLabel)
                .font(.system(size: size * 0.22, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.78)) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: used) { _, _ in
            withAnimation(VemTheme.smoothSpring) {
                animatedProgress = targetProgress
            }
        }
    }
}

// MARK: - Interactive 3D Tilt Card (SEPA Mandate / Household Pass)

public struct VemInteractive3DCard<Content: View>: View {
    @ViewBuilder private let content: () -> Content
    @State private var dragOffset: CGSize = .zero

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .rotation3DEffect(
                .degrees(Double(dragOffset.width / 16)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.65
            )
            .rotation3DEffect(
                .degrees(Double(-dragOffset.height / 18)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.65
            )
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { val in
                        dragOffset = CGSize(
                            width: max(-90, min(90, val.translation.width)),
                            height: max(-60, min(60, val.translation.height))
                        )
                    }
                    .onEnded { _ in
                        withAnimation(VemTheme.bouncySpring) {
                            dragOffset = .zero
                        }
                    }
            )
    }
}

// MARK: - Joyful Celebration Confetti Burst

fileprivate struct VemConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let startX: CGFloat
    let driftX: CGFloat
    let size: CGFloat
    let rotation: Double
    let duration: Double
}

public struct VemConfettiOverlay: View {
    public let trigger: Int
    @State private var particles: [VemConfettiParticle] = []

    public init(trigger: Int) {
        self.trigger = trigger
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    SingleConfettiPiece(particle: p, height: geo.size.height)
                }
            }
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0 else { return }
                spawn(in: geo.size.width)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func spawn(in width: CGFloat) {
        let palette: [Color] = [
            VemTheme.vipleMint,
            VemTheme.electricIndigo,
            VemTheme.warmCoral,
            VemTheme.solarAmber,
            VemTheme.oceanSky,
            VemTheme.vibrantViolet
        ]
        var next: [VemConfettiParticle] = []
        for idx in 0..<28 {
            next.append(
                VemConfettiParticle(
                    color: palette[idx % palette.count],
                    startX: CGFloat.random(in: 24...max(48, width - 24)),
                    driftX: CGFloat.random(in: -90...90),
                    size: CGFloat.random(in: 7...13),
                    rotation: Double.random(in: 140...520),
                    duration: Double.random(in: 1.4...2.4)
                )
            )
        }
        particles = next
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            particles = []
        }
    }
}

private struct SingleConfettiPiece: View {
    let particle: VemConfettiParticle
    let height: CGFloat
    @State private var fallen = false

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 1.45)
            .rotationEffect(.degrees(fallen ? particle.rotation : 0))
            .position(
                x: particle.startX + (fallen ? particle.driftX : 0),
                y: fallen ? height + 40 : -20
            )
            .opacity(fallen ? 0.0 : 1.0)
            .onAppear {
                withAnimation(.easeIn(duration: particle.duration)) {
                    fallen = true
                }
            }
    }
}
