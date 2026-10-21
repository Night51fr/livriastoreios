import SwiftUI
@preconcurrency import AVFoundation
import UIKit

// MARK: - Convertisseur d'URL Livria Store (/covers/* -> https://livria.store/covers/*)

public enum LivriaURLResolver: Sendable {
    public static let baseWebURL = "https://livria.store"
    public static let socialWebURL = "https://livriasocial.viplenetwork.com"
    public static let identityWebURL = "https://identity-v2.viple.digital"
    public static let deliveryPickupURL = "https://delivery.viplenetwork.com/tools/listpickup?returnurl=https%3A%2F%2Flivria.store%2F"
    public static let deliveryTrackingBaseURL = "https://delivery.viplenetwork.com/?track="
    public static let assistanceWebURL = "https://assistance.viplenetwork.com"

    /// Convertit systématiquement tout lien commençant par `/` (ex: `/covers/978...jpg`) en `https://livria.store/...`
    public static func resolve(_ rawPath: String?) -> URL? {
        guard let raw = rawPath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
            return URL(string: raw)
        }
        if raw.hasPrefix("//") {
            return URL(string: "https:" + raw)
        }
        if raw.hasPrefix("/") {
            return URL(string: baseWebURL + raw)
        }
        return URL(string: baseWebURL + "/" + raw)
    }

    public static func resolveString(_ rawPath: String?) -> String {
        resolve(rawPath)?.absoluteString ?? ""
    }
}

// MARK: - Thème & Palette Livria Store

public enum LivriaPalette: Sendable {
    public static let background = Color(red: 0.984, green: 0.969, blue: 1.000)       // #FBF7FF
    public static let backgroundAlt = Color(red: 0.953, green: 0.925, blue: 1.000)    // #F3ECFF
    public static let cardPaper = Color(red: 1.000, green: 0.992, blue: 0.976)        // #FFFDF9
    public static let primary = Color(red: 0.486, green: 0.302, blue: 1.000)          // #7C4DFF
    public static let primaryDeep = Color(red: 0.369, green: 0.208, blue: 0.694)      // #5E35B1
    public static let primarySoft = Color(red: 0.929, green: 0.898, blue: 1.000)      // #EDE5FF
    public static let coral = Color(red: 1.000, green: 0.373, blue: 0.635)            // #FF5FA2
    public static let gold = Color(red: 0.961, green: 0.620, blue: 0.043)             // #F59E0B
    public static let goldSoft = Color(red: 0.996, green: 0.953, blue: 0.780)         // #FEF3C7
    public static let mint = Color(red: 0.063, green: 0.725, blue: 0.506)             // #10B981
    public static let usedAmber = Color(red: 0.851, green: 0.467, blue: 0.024)        // #D97706 (Occasion)
    public static let usedAmberSoft = Color(red: 0.996, green: 0.953, blue: 0.780)    // #FEF3C7
    public static let ink = Color(red: 0.114, green: 0.082, blue: 0.200)              // #1D1533
    public static let inkMuted = Color(red: 0.373, green: 0.333, blue: 0.478)         // #5F557A
    public static let border = Color(red: 0.486, green: 0.302, blue: 1.000).opacity(0.14)

    public static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.180, green: 0.063, blue: 0.396),
                Color(red: 0.486, green: 0.302, blue: 1.000),
                Color(red: 0.859, green: 0.153, blue: 0.467)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var loobyPlusGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.118, green: 0.106, blue: 0.294),
                Color(red: 0.369, green: 0.208, blue: 0.694),
                Color(red: 0.706, green: 0.325, blue: 0.035)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Fond Dynamique MeshGradient

public struct LivriaMeshHeroBackground: View {
    public init() {}

    public var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.55, 0.45), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.16, green: 0.05, blue: 0.38),
                Color(red: 0.39, green: 0.18, blue: 0.82),
                Color(red: 0.58, green: 0.20, blue: 0.68),
                Color(red: 0.28, green: 0.12, blue: 0.64),
                Color(red: 0.49, green: 0.30, blue: 1.00),
                Color(red: 0.86, green: 0.18, blue: 0.48),
                Color(red: 0.19, green: 0.08, blue: 0.44),
                Color(red: 0.42, green: 0.22, blue: 0.78),
                Color(red: 0.72, green: 0.24, blue: 0.52)
            ]
        )
    }
}

// MARK: - Thèmes d'arrière-plan personnalisés Livria Store (voile 60-80%)

public struct LivriaSiteThemeOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let colors: [Color]
    public let icon: String

    public static let all: [LivriaSiteThemeOption] = [
        .init(id: "default", name: "Lavande Classique", subtitle: "Ambiance originale Livria", colors: [LivriaPalette.background, LivriaPalette.backgroundAlt], icon: "sparkles"),
        .init(id: "parchment", name: "Parchemin d'Alexandrie", subtitle: "Ambiance librairie ancienne", colors: [Color(red: 0.96, green: 0.90, blue: 0.78), Color(red: 0.89, green: 0.78, blue: 0.62)], icon: "book.closed.fill"),
        .init(id: "sakura", name: "Brume de Sakura", subtitle: "Douceur florale japonaise", colors: [Color(red: 0.99, green: 0.86, blue: 0.92), Color(red: 0.93, green: 0.79, blue: 0.96)], icon: "leaf.fill"),
        .init(id: "aurora", name: "Aurore Boréale", subtitle: "Reflets célestes émeraude & violet", colors: [Color(red: 0.78, green: 0.95, blue: 0.91), Color(red: 0.82, green: 0.80, blue: 0.98)], icon: "moon.stars.fill"),
        .init(id: "emerald", name: "Cabinet d'Émeraude", subtitle: "Salon de lecture feutré", colors: [Color(red: 0.80, green: 0.93, blue: 0.86), Color(red: 0.69, green: 0.87, blue: 0.80)], icon: "lamp.desk.fill"),
        .init(id: "sunset", name: "Crépuscule Doré", subtitle: "Lumière chaude de fin d'après-midi", colors: [Color(red: 0.99, green: 0.88, blue: 0.76), Color(red: 0.98, green: 0.78, blue: 0.84)], icon: "sun.and.horizon.fill"),
        .init(id: "ocean", name: "Odyssée Égée", subtitle: "Horizon marin apaisant", colors: [Color(red: 0.79, green: 0.91, blue: 0.99), Color(red: 0.72, green: 0.84, blue: 0.98)], icon: "water.waves"),
        .init(id: "cosmos", name: "Nébuleuse Nocturne", subtitle: "Voûte étoilée pastel", colors: [Color(red: 0.84, green: 0.80, blue: 0.99), Color(red: 0.76, green: 0.85, blue: 0.99)], icon: "sparkle.magnifyingglass")
    ]

    public static func option(for id: String) -> LivriaSiteThemeOption {
        let key = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let match = all.first(where: { $0.id == key }) {
            return match
        }
        switch key {
        case "oxford-library": return all.first(where: { $0.id == "parchment" }) ?? all[0]
        case "kyoto-sakura": return all.first(where: { $0.id == "sakura" }) ?? all[0]
        case "cosmic-nebula", "gothic-manor": return all.first(where: { $0.id == "cosmos" }) ?? all[0]
        case "enchanted-forest": return all.first(where: { $0.id == "emerald" }) ?? all[0]
        case "mediterranean-sunset": return all.first(where: { $0.id == "sunset" }) ?? all[0]
        case "paris-rain": return all.first(where: { $0.id == "ocean" }) ?? all[0]
        default: return all[0]
        }
    }
}

public struct LivriaThemedBackground: ViewModifier {
    let themeId: String

    public func body(content: Content) -> some View {
        let opt = LivriaSiteThemeOption.option(for: themeId)
        ZStack {
            LinearGradient(colors: opt.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            LivriaPalette.background.opacity(opt.id == "default" ? 0.88 : 0.20)
                .ignoresSafeArea()
            content
        }
    }
}

extension View {
    public func livriaThemedBackground(_ themeId: String) -> some View {
        modifier(LivriaThemedBackground(themeId: themeId))
    }

    @ViewBuilder
    public func livriaCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LivriaPalette.cardPaper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(LivriaPalette.border, lineWidth: 1)
            )
            .shadow(color: LivriaPalette.primary.opacity(0.06), radius: 12, x: 0, y: 5)
    }
}

// MARK: - Composant Couverture de Livre avec Résolution Automatique `/covers/*` -> `https://livria.store/covers/*`

public struct LivriaBookCoverView: View {
    public let coverUrl: String?
    public let title: String
    public var width: CGFloat = 96
    public var height: CGFloat = 142
    public var cornerRadius: CGFloat = 12

    public init(coverUrl: String?, title: String, width: CGFloat = 96, height: CGFloat = 142, cornerRadius: CGFloat = 12) {
        self.coverUrl = coverUrl
        self.title = title
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let resolvedURL = LivriaURLResolver.resolve(coverUrl)
        ZStack {
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackCover
                    case .empty:
                        ZStack {
                            fallbackCover.opacity(0.55)
                            ProgressView()
                                .tint(.white)
                        }
                    @unknown default:
                        fallbackCover
                    }
                }
            } else {
                fallbackCover
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 4)
    }

    private var fallbackCover: some View {
        ZStack {
            LinearGradient(
                colors: [LivriaPalette.primaryDeep, LivriaPalette.primary, LivriaPalette.coral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: min(width * 0.28, 26), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(title)
                    .font(.system(size: max(min(width * 0.11, 12), 9), weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 6)
            }
        }
    }
}

// MARK: - Anneau de Niveau & Avatar Strictement Circulaire (LevelRingView)

public struct LevelRingView: View {
    public let avatarUrl: String?
    public let displayName: String
    public let level: Int
    public let xp: Int
    public var size: CGFloat = 76

    public init(avatarUrl: String?, displayName: String, level: Int, xp: Int, size: CGFloat = 76) {
        self.avatarUrl = avatarUrl
        self.displayName = displayName
        self.level = level
        self.xp = xp
        self.size = size
    }

    private var progressInLevel: Double {
        let remainder = xp % 200
        return Double(remainder) / 200.0
    }

    public var body: some View {
        let innerSize = size - 12
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .stroke(LivriaPalette.primary.opacity(0.18), lineWidth: 4.5)
                    .frame(width: size, height: size)

                Circle()
                    .trim(from: 0, to: max(0.08, progressInLevel))
                    .stroke(
                        AngularGradient(
                            colors: [LivriaPalette.primary, LivriaPalette.coral, LivriaPalette.gold, LivriaPalette.primary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)

                avatarContent(innerSize: innerSize)
                    .frame(width: innerSize, height: innerSize)
                    .clipShape(Circle())
                    .contentShape(Circle())
            }

            Text("Niv. \(level)")
                .font(.system(size: max(10, size * 0.14), weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .leading, endPoint: .trailing))
                )
                .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
                .offset(x: 4, y: 4)
        }
    }

    @ViewBuilder
    private func avatarContent(innerSize: CGFloat) -> some View {
        if let url = LivriaURLResolver.resolve(avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .scaledToFill()
                        .frame(width: innerSize, height: innerSize)
                        .clipped()
                default:
                    initialsBubble(innerSize: innerSize)
                }
            }
        } else {
            initialsBubble(innerSize: innerSize)
        }
    }

    private func initialsBubble(innerSize: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(displayName.prefix(1)).uppercased())
                .font(.system(size: innerSize * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: innerSize, height: innerSize)
    }
}

// MARK: - Générateur d'Ambiance Sonore Littéraire (Pluie, Cheminée, Café) pour la Fiche Livre

@MainActor
public final class LivriaAmbientSoundPlayer: ObservableObject {
    @Published public private(set) var activePreset: String? = nil
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    public init() {}

    public func toggle(preset: String) {
        if activePreset == preset {
            stop()
        } else {
            start(preset: preset)
        }
    }

    public func start(preset: String) {
        stop()
        let audioEngine = AVAudioEngine()
        let mainMixer = audioEngine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100)

        let mode = preset.lowercased()
        let node = Self.buildSourceNode(mode: mode, sampleRate: sampleRate)

        audioEngine.attach(node)
        audioEngine.connect(node, to: mainMixer, format: outputFormat)
        do {
            try audioEngine.start()
            self.engine = audioEngine
            self.sourceNode = node
            self.activePreset = preset
        } catch {
            self.activePreset = nil
        }
    }

    nonisolated private static func buildSourceNode(mode: String, sampleRate: Float) -> AVAudioSourceNode {
        var lpf: Float = 0.0
        var phase: Float = 0.0
        return AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let white = Float.random(in: -1.0...1.0)
                let alpha: Float = mode.contains("pluie") ? 0.14 : (mode.contains("chemin") ? 0.06 : 0.10)
                lpf = lpf + alpha * (white - lpf)
                phase += 1.0 / sampleRate
                let crackle: Float = (mode.contains("chemin") && Float.random(in: 0...1) > 0.996) ? Float.random(in: -0.35...0.35) : 0.0
                let sample = max(-0.25, min(0.25, (lpf * 0.18) + crackle))
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    if frame < buf.count {
                        buf[frame] = sample
                    }
                }
            }
            return noErr
        }
    }

    public func stop() {
        engine?.stop()
        engine = nil
        sourceNode = nil
        activePreset = nil
    }
}

// MARK: - Caméra Directe Code-Barres EAN-13 / ISBN (AVCaptureSession temps réel)

public struct LivriaBarcodeCameraView: UIViewControllerRepresentable {
    public var isScanning: Bool
    public var torchEnabled: Bool
    public var onCodeScanned: (String) -> Void
    public var onCameraUnavailable: () -> Void

    public init(
        isScanning: Bool,
        torchEnabled: Bool,
        onCodeScanned: @escaping (String) -> Void,
        onCameraUnavailable: @escaping () -> Void
    ) {
        self.isScanning = isScanning
        self.torchEnabled = torchEnabled
        self.onCodeScanned = onCodeScanned
        self.onCameraUnavailable = onCameraUnavailable
    }

    public func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onCodeScanned = onCodeScanned
        vc.onCameraUnavailable = onCameraUnavailable
        return vc
    }

    public func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.setScanning(isScanning)
        uiViewController.setTorch(torchEnabled)
    }

    public final class ScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
        var onCodeScanned: ((String) -> Void)?
        var onCameraUnavailable: (() -> Void)?

        private let captureSession = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var isConfigured = false
        private var allowDetection = true
        private var lastDetectedCode: String = ""
        private var lastDetectionDate: Date = .distantPast

        public override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureCameraSession()
        }

        public override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        public override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            stopSession()
        }

        private func configureCameraSession() {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                setupSessionOnQueue()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.setupSessionOnQueue()
                        } else {
                            self?.onCameraUnavailable?()
                        }
                    }
                }
            default:
                DispatchQueue.main.async { [weak self] in
                    self?.onCameraUnavailable?()
                }
            }
        }

        private func setupSessionOnQueue() {
            guard !isConfigured else {
                startSession()
                return
            }
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
                  captureSession.canAddInput(videoInput) else {
                onCameraUnavailable?()
                return
            }

            captureSession.beginConfiguration()
            captureSession.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                let wantedTypes: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128]
                let supported = metadataOutput.availableMetadataObjectTypes
                metadataOutput.metadataObjectTypes = wantedTypes.filter { supported.contains($0) }
            } else {
                captureSession.commitConfiguration()
                onCameraUnavailable?()
                return
            }
            captureSession.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.frame = view.layer.bounds
            layer.videoGravity = .resizeAspectFill
            view.layer.insertSublayer(layer, at: 0)
            self.previewLayer = layer
            self.isConfigured = true
            startSession()
        }

        func setScanning(_ active: Bool) {
            allowDetection = active
            if active {
                lastDetectedCode = ""
                startSession()
            }
        }

        func setTorch(_ on: Bool) {
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {}
        }

        private func startSession() {
            guard isConfigured, !captureSession.isRunning else { return }
            nonisolated(unsafe) let session = captureSession
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        private func stopSession() {
            guard captureSession.isRunning else { return }
            nonisolated(unsafe) let session = captureSession
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }

        public func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard allowDetection else { return }
            guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let rawString = metadataObject.stringValue else { return }

            let cleaned = rawString.filter { $0.isNumber || $0 == "X" || $0 == "x" }
            guard cleaned.count >= 10 else { return }

            let now = Date()
            if cleaned == lastDetectedCode && now.timeIntervalSince(lastDetectionDate) < 2.2 {
                return
            }
            lastDetectedCode = cleaned
            lastDetectionDate = now
            allowDetection = false

            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
            onCodeScanned?(cleaned)
        }
    }
}

// MARK: - Scanner ISBN Direct avec Caméra Temps Réel + Animation "Livre trouvé !" -> Fiche du Livre

public struct LivriaISBNScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel

    public var onSelectCatalogBook: ((LivriaBook) -> Void)?
    public var onSelectISBNResult: ((LivriaISBNLookupResponse) -> Void)?

    @State private var isScanningCamera: Bool = true
    @State private var torchEnabled: Bool = false
    @State private var cameraUnavailable: Bool = false
    @State private var laserOffset: CGFloat = -95
    @State private var isSearchingCatalog: Bool = false
    @State private var detectedISBNCode: String = ""
    @State private var foundBook: LivriaBook? = nil
    @State private var showBookFoundAnimation: Bool = false
    @State private var notFoundMessage: String? = nil
    @State private var showManualField: Bool = false
    @State private var manualISBN: String = ""

    public init(
        onSelectCatalogBook: ((LivriaBook) -> Void)? = nil,
        onSelectISBNResult: ((LivriaISBNLookupResponse) -> Void)? = nil
    ) {
        self.onSelectCatalogBook = onSelectCatalogBook
        self.onSelectISBNResult = onSelectISBNResult
    }

    public var body: some View {
        ZStack {
            // 1. Vue appareil photo plein écran directe
            if !cameraUnavailable {
                LivriaBarcodeCameraView(
                    isScanning: isScanningCamera && !isSearchingCatalog && foundBook == nil,
                    torchEnabled: torchEnabled,
                    onCodeScanned: { code in
                        handleScannedISBN(code)
                    },
                    onCameraUnavailable: {
                        cameraUnavailable = true
                        showManualField = true
                    }
                )
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.05, blue: 0.20),
                        Color(red: 0.22, green: 0.11, blue: 0.44),
                        Color(red: 0.12, green: 0.06, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            // Assombrissement autour du cadre de visée
            Color.black.opacity(cameraUnavailable ? 0.25 : 0.42)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Barre supérieure (Fermer + Lampe torche)
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("Fermer")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundStyle(LivriaPalette.gold)
                        Text("Scan ISBN Livria")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    if !cameraUnavailable {
                        Button {
                            torchEnabled.toggle()
                        } label: {
                            Image(systemName: torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(torchEnabled ? LivriaPalette.gold : Color.white.opacity(0.20))
                                )
                                .foregroundStyle(torchEnabled ? .black : .white)
                        }
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                Spacer()

                // Cadre de visée laser (style Wingman)
                if foundBook == nil {
                    VStack(spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.32), lineWidth: 1.5)
                                .frame(width: 286, height: 196)
                                .background(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(Color.black.opacity(0.16))
                                )

                            // Coins lumineux du viseur
                            ScannerCornersOverlay()
                                .stroke(
                                    LinearGradient(
                                        colors: [LivriaPalette.gold, LivriaPalette.coral, LivriaPalette.primary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                                )
                                .frame(width: 286, height: 196)

                            // Ligne laser animée
                            if !cameraUnavailable && isScanningCamera {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, LivriaPalette.coral, LivriaPalette.gold, LivriaPalette.coral, .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 254, height: 3)
                                    .shadow(color: LivriaPalette.coral.opacity(0.9), radius: 8)
                                    .offset(y: laserOffset)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 1.65).repeatForever(autoreverses: true)) {
                                            laserOffset = 95
                                        }
                                    }
                            }

                            if isSearchingCatalog {
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .scaleEffect(1.3)
                                        .tint(LivriaPalette.gold)
                                    Text("Recherche de l'ISBN \(detectedISBNCode) dans le catalogue Livria...")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }
                                .padding(18)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                            }
                        }

                        VStack(spacing: 6) {
                            Text("Placez le code-barres au dos du livre dans le cadre")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text("Détection automatique dans le catalogue Livria Store")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .padding(.horizontal, 24)
                    }
                }

                Spacer()

                // Message si livre absent du catalogue
                if let msg = notFoundMessage, foundBook == nil {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "book.closed.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LivriaPalette.gold)
                            Text(msg)
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                        }

                        Button {
                            withAnimation {
                                notFoundMessage = nil
                                isScanningCamera = true
                            }
                        } label: {
                            Label("Scanner un autre code-barres", systemImage: "camera.viewfinder")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(LivriaPalette.gold))
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Option discrète de saisie manuelle si le code-barres est abîmé
                if foundBook == nil {
                    VStack(spacing: 10) {
                        if showManualField {
                            HStack(spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "barcode")
                                        .foregroundStyle(LivriaPalette.gold)
                                    TextField("Saisir l'ISBN (ex: 9782070368228)", text: $manualISBN)
                                        .keyboardType(.numbersAndPunctuation)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.14)))

                                Button {
                                    handleScannedISBN(manualISBN)
                                } label: {
                                    Text("Valider")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.primary))
                                        .foregroundStyle(.white)
                                }
                                .disabled(manualISBN.trimmingCharacters(in: .whitespaces).isEmpty || isSearchingCatalog)
                            }
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showManualField = true
                                }
                            } label: {
                                Label("Code-barres illisible ? Saisir les chiffres manuellement", systemImage: "keyboard")
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.white.opacity(0.14)))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 26)
                }
            }

            // 2. Animation plein écran "Livre trouvé !" puis redirection directe vers la fiche du livre
            if let book = foundBook {
                ZStack {
                    Color.black.opacity(0.76)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [LivriaPalette.mint.opacity(0.55), LivriaPalette.primary.opacity(0.05)],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 132, height: 132)
                                .scaleEffect(showBookFoundAnimation ? 1.12 : 0.6)

                            Circle()
                                .fill(LivriaPalette.mint)
                                .frame(width: 74, height: 74)
                                .shadow(color: LivriaPalette.mint.opacity(0.6), radius: 16, x: 0, y: 6)

                            Image(systemName: "checkmark")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(showBookFoundAnimation ? 1.0 : 0.4)

                        Text("Livre trouvé !")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Ouverture directe de la fiche dans Livria Store...")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(LivriaPalette.goldSoft)

                        HStack(spacing: 16) {
                            LivriaBookCoverView(
                                coverUrl: book.coverUrl,
                                title: book.title,
                                width: 84,
                                height: 124,
                                cornerRadius: 12
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text(book.displayGenre)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3.5)
                                    .background(Capsule().fill(LivriaPalette.primarySoft))
                                    .foregroundStyle(LivriaPalette.primaryDeep)

                                Text(book.title)
                                    .font(.system(size: 17, weight: .bold, design: .serif))
                                    .foregroundStyle(LivriaPalette.ink)
                                    .lineLimit(2)

                                Text(book.author)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(LivriaPalette.inkMuted)

                                Text(String(format: "%.2f €", book.price))
                                    .font(.system(size: 19, weight: .black, design: .rounded))
                                    .foregroundStyle(LivriaPalette.primary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LivriaPalette.cardPaper))
                        .padding(.horizontal, 24)

                        Button {
                            openFoundBookNow(book)
                        } label: {
                            Label("Voir la fiche du livre maintenant", systemImage: "arrow.right.circle.fill")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .padding(.horizontal, 22)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(LivriaPalette.gold))
                                .foregroundStyle(.black)
                        }
                    }
                    .scaleEffect(showBookFoundAnimation ? 1.0 : 0.82)
                    .opacity(showBookFoundAnimation ? 1.0 : 0.0)
                }
                .zIndex(50)
            }
        }
    }

    private func handleScannedISBN(_ rawCode: String) {
        let cleaned = rawCode.filter { $0.isNumber || $0 == "X" || $0 == "x" }
        guard !cleaned.isEmpty else { return }

        notFoundMessage = nil
        detectedISBNCode = cleaned
        isSearchingCatalog = true
        isScanningCamera = false

        Task {
            if let matched = await store.findBookInLivriaCatalog(isbn: cleaned) {
                isSearchingCatalog = false
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)

                foundBook = matched
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                    showBookFoundAnimation = true
                }

                if let onSelectISBNResult {
                    let resp = LivriaISBNLookupResponse(
                        ok: true,
                        inCatalog: true,
                        isbn: matched.isbn,
                        title: matched.title,
                        author: matched.author,
                        description: matched.description,
                        coverUrl: matched.coverUrl,
                        catalogBook: matched
                    )
                    onSelectISBNResult(resp)
                }

                try? await Task.sleep(nanoseconds: 1_150_000_000)
                if foundBook?.id == matched.id {
                    openFoundBookNow(matched)
                }
            } else {
                isSearchingCatalog = false
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.warning)
                withAnimation {
                    notFoundMessage = "Aucun livre avec l'ISBN \(cleaned) n'a été trouvé dans le catalogue Livria Store."
                }
            }
        }
    }

    private func openFoundBookNow(_ book: LivriaBook) {
        let callback = onSelectCatalogBook
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if let callback {
                callback(book)
            } else {
                store.scannedBookForDetail = book
            }
        }
    }
}

private struct ScannerCornersOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let len: CGFloat = 34
        let r: CGFloat = 24

        // Haut-gauche
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))

        // Haut-droite
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))

        // Bas-droite
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))

        // Bas-gauche
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))

        return p
    }
}
