import SwiftUI
import AVFoundation
import AudioToolbox
#if canImport(UIKit)
import UIKit
#endif
#if canImport(VisionKit) && canImport(Vision)
import VisionKit
import Vision
#endif

// MARK: - Modèles de Requête & d'Historique du Lecteur Matériel de Codes-Barres / ISBN

public enum NativeBarcodeScanMode: String, CaseIterable, Identifiable, Sendable {
    case single = "single"
    case burst = "burst"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .single: return "Scan Unique"
        case .burst: return "Mode Rafale"
        }
    }

    public var subtitle: String {
        switch self {
        case .single:
            return "Fermeture automatique dès la lecture du code-barres ou ISBN"
        case .burst:
            return "Enchaînement continu avec compteur en direct (inventaire / réception)"
        }
    }
}

public struct NativeBarcodeScanRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var initialMode: NativeBarcodeScanMode
    public var fieldContext: String
    public var customTitle: String?

    public init(
        id: UUID = UUID(),
        initialMode: NativeBarcodeScanMode = .single,
        fieldContext: String = "isbn",
        customTitle: String? = nil
    ) {
        self.id = id
        self.initialMode = initialMode
        self.fieldContext = fieldContext
        self.customTitle = customTitle
    }

    /// Analyse le payload envoyé depuis JavaScript via `window.webkit.messageHandlers.barcodeScanner.postMessage(...)`
    /// Retourne `nil` lorsqu'il s'agit d'une commande de fermeture (`action: "stop"` / `"close"`).
    public static func fromJSMessageBody(_ body: Any) -> (action: String, request: NativeBarcodeScanRequest?) {
        if let rawStr = body as? String {
            let trimmed = rawStr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed == "stop" || trimmed == "close" || trimmed == "cancel" {
                return ("stop", nil)
            }
            let mode: NativeBarcodeScanMode = (trimmed == "burst" || trimmed == "rafale") ? .burst : .single
            return ("start", NativeBarcodeScanRequest(initialMode: mode, fieldContext: trimmed.isEmpty ? "isbn" : trimmed))
        }

        if let dict = body as? [String: Any] {
            let action = ((dict["action"] as? String) ?? "start")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if action == "stop" || action == "close" || action == "cancel" {
                return ("stop", nil)
            }

            let rawMode = ((dict["mode"] as? String) ?? "single").lowercased()
            let mode: NativeBarcodeScanMode = (rawMode == "burst" || rawMode == "rafale" || rawMode == "continuous")
                ? .burst
                : .single
            let field = (dict["field"] as? String)
                ?? (dict["context"] as? String)
                ?? "isbn"
            let title = (dict["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            return ("start", NativeBarcodeScanRequest(
                initialMode: mode,
                fieldContext: field,
                customTitle: (title?.isEmpty == false) ? title : nil
            ))
        }

        return ("start", NativeBarcodeScanRequest())
    }
}

public struct ScannedBarcodeEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let code: String
    public let symbology: String
    public var quantity: Int
    public var lastScannedAt: Date

    public init(code: String, symbology: String, quantity: Int = 1, lastScannedAt: Date = Date()) {
        self.id = UUID()
        self.code = code
        self.symbology = symbology
        self.quantity = quantity
        self.lastScannedAt = lastScannedAt
    }

    public var isIsbnBookland: Bool {
        (code.count == 13 && (code.hasPrefix("978") || code.hasPrefix("979")))
            || (code.count == 10 && code.dropLast().allSatisfy(\.isNumber))
    }
}

// MARK: - Moteur Sensoriel Double Latence Zéro (Bip Douchette Laser + Vibration Haptique)

@MainActor
public final class ScannerSensoryFeedbackEngine {
    public static let shared = ScannerSensoryFeedbackEngine()

    private var beepPlayer: AVAudioPlayer?
    #if canImport(UIKit)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notifGenerator = UINotificationFeedbackGenerator()
    #endif

    private init() {
        let wavData = Self.synthesizeLaserScannerBeepWAV()
        beepPlayer = try? AVAudioPlayer(data: wavData, fileTypeHint: AVFileType.wav.rawValue)
        beepPlayer?.volume = 0.92
        beepPlayer?.prepareToPlay()
    }

    public func warmUp(audibleInSilentMode: Bool, soundMuted: Bool) {
        configureAudioSession(audibleInSilentMode: audibleInSilentMode, soundMuted: soundMuted)
        beepPlayer?.prepareToPlay()
        #if canImport(UIKit)
        rigidImpact.prepare()
        heavyImpact.prepare()
        notifGenerator.prepare()
        #endif
    }

    public func configureAudioSession(audibleInSilentMode: Bool, soundMuted: Bool) {
        guard !soundMuted else { return }
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if audibleInSilentMode {
                // Reste audible façon douchette d'entrepôt même si le commutateur silencieux latéral est activé, sans couper l'audio tiers
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            } else {
                try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            }
            try audioSession.setActive(true, options: [])
        } catch {
            // Ignorer silencieusement si l'appareil restreint la session audio
        }
    }

    /// Déclenche simultanément le bip sonore court façon douchette et la vibration haptique
    public func fireScanSuccessFeedback(audibleInSilentMode: Bool, soundMuted: Bool) {
        #if canImport(UIKit)
        rigidImpact.impactOccurred(intensity: 1.0)
        notifGenerator.notificationOccurred(.success)
        rigidImpact.prepare()
        #endif

        guard !soundMuted else { return }
        configureAudioSession(audibleInSilentMode: audibleInSilentMode, soundMuted: false)

        if let player = beepPlayer {
            if player.isPlaying {
                player.currentTime = 0
            } else {
                player.currentTime = 0
                player.play()
            }
        } else {
            AudioServicesPlaySystemSound(1057)
        }
    }

    /// Génère en mémoire un signal PCM 16-bit 44,1 kHz ultra-net de 76 ms (double impulsion 2 620 Hz -> 3 140 Hz façon douchette laser)
    private static func synthesizeLaserScannerBeepWAV() -> Data {
        let sampleRate: Int = 44_100
        let durationSeconds: Double = 0.076
        let totalSamples = Int(Double(sampleRate) * durationSeconds)
        let splitSample = Int(Double(totalSamples) * 0.42)
        let fadeSamples = Int(Double(sampleRate) * 0.004) // 4 ms anti-clic

        var pcmSamples = [Int16](repeating: 0, count: totalSamples)
        var phase: Double = 0.0

        for i in 0..<totalSamples {
            let freq: Double = (i < splitSample) ? 2620.0 : 3140.0
            phase += (2.0 * Double.pi * freq) / Double(sampleRate)
            if phase > 2.0 * Double.pi { phase -= 2.0 * Double.pi }

            // Fondamentale + légère harmonique paire pour la clarté d'une vraie douchette matérielle
            let rawWave = 0.84 * sin(phase) + 0.16 * sin(phase * 2.0)

            var envelope: Double = 1.0
            if i < fadeSamples {
                envelope = 0.5 * (1.0 - cos(Double.pi * Double(i) / Double(fadeSamples)))
            } else if i > totalSamples - fadeSamples {
                let rem = totalSamples - i
                envelope = 0.5 * (1.0 - cos(Double.pi * Double(rem) / Double(fadeSamples)))
            }

            let clamped = max(-1.0, min(1.0, rawWave * envelope * 0.82))
            pcmSamples[i] = Int16(clamped * Double(Int16.max))
        }

        let dataSize = UInt32(totalSamples * 2)
        let riffChunkSize = UInt32(36) + dataSize
        let byteRate = UInt32(sampleRate * 2)
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let audioFormatPCM: UInt16 = 1
        let numChannels: UInt16 = 1
        let fmtChunkSize: UInt32 = 16
        let sampleRateU32 = UInt32(sampleRate)

        var wav = Data(capacity: Int(44 + dataSize))
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(littleEndianBytes(riffChunkSize))
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8)
        wav.append(littleEndianBytes(fmtChunkSize))
        wav.append(littleEndianBytes(audioFormatPCM))
        wav.append(littleEndianBytes(numChannels))
        wav.append(littleEndianBytes(sampleRateU32))
        wav.append(littleEndianBytes(byteRate))
        wav.append(littleEndianBytes(blockAlign))
        wav.append(littleEndianBytes(bitsPerSample))
        wav.append(contentsOf: "data".utf8)
        wav.append(littleEndianBytes(dataSize))

        pcmSamples.withUnsafeBufferPointer { ptr in
            wav.append(UnsafeBufferPointer(
                start: UnsafeRawPointer(ptr.baseAddress)?.assumingMemoryBound(to: UInt8.self),
                count: Int(dataSize)
            ))
        }
        return wav
    }

    private static func littleEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        var le = value.littleEndian
        return withUnsafeBytes(of: &le) { Array($0) }
    }
}

// MARK: - Modale Plein Écran du Scanner Matériel Wingman / Cenelis Workspace

public struct NativeBarcodeScannerModalView: View {
    public let request: NativeBarcodeScanRequest
    public let onCodeScanned: (_ code: String, _ symbology: String, _ mode: NativeBarcodeScanMode, _ totalCount: Int) -> Void
    public let onCloseScanner: (_ mode: NativeBarcodeScanMode, _ entries: [ScannedBarcodeEntry]) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("cenelis.scanner.audibleSilent") private var audibleInSilentMode: Bool = true
    @AppStorage("cenelis.scanner.soundMuted") private var soundMuted: Bool = false

    @State private var scanMode: NativeBarcodeScanMode
    @State private var isTorchOn: Bool = false
    @State private var isMacroZoomEnabled: Bool = false
    @State private var cameraAuthStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    // État temps réel des lectures (Mode Unique & Mode Rafale)
    @State private var scannedEntries: [ScannedBarcodeEntry] = []
    @State private var totalScanCount: Int = 0
    @State private var lastScannedCode: String = ""
    @State private var lastScannedSymbology: String = ""
    @State private var lastScannedTimestamp: Date = .distantPast
    @State private var showDetectionFlash: Bool = false
    @State private var isClosingAfterSingleScan: Bool = false

    public init(
        request: NativeBarcodeScanRequest,
        onCodeScanned: @escaping (_ code: String, _ symbology: String, _ mode: NativeBarcodeScanMode, _ totalCount: Int) -> Void,
        onCloseScanner: @escaping (_ mode: NativeBarcodeScanMode, _ entries: [ScannedBarcodeEntry]) -> Void
    ) {
        self.request = request
        self._scanMode = State(initialValue: request.initialMode)
        self.onCodeScanned = onCodeScanned
        self.onCloseScanner = onCloseScanner
    }

    private var contextHeadline: String {
        if let custom = request.customTitle, !custom.isEmpty {
            return custom
        }
        switch request.fieldContext.lowercased() {
        case "catalog_isbn": return "Recherche Catalogue · ISBN"
        case "w3_isbn", "w3_burst": return "Réception Cartons · ISBN"
        case "w4_isbn": return "Contrôle Qualité · ISBN"
        case "w5_picking": return "Picking Commande · Articles"
        case "w8_rma": return "Retour Logistique · Code RMA"
        case "w11_pair": return "Appairage Poste · QR Viple ID"
        default: return "Lecteur Matériel Wingman · ISBN / EAN"
        }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch cameraAuthStatus {
            case .authorized:
                liveScannerLayer

            case .notDetermined:
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                    Text("Initialisation de l'optique macro…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }

            default:
                cameraPermissionDeniedView
            }

            // Flash vert émeraude bref à chaque lecture réussie
            if showDetectionFlash {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(WorkspaceTheme.statusGreen, lineWidth: 6)
                    .background(WorkspaceTheme.statusGreen.opacity(0.12))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Interface HUD Native (Barre supérieure + Viseur laser + Sélecteur Mode Unique / Rafale + Compteur)
            VStack(spacing: 0) {
                topControlsBar

                Spacer()

                if cameraAuthStatus == .authorized {
                    centerReticleOverlay
                }

                Spacer()

                bottomModeAndBurstPanel
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            ScannerSensoryFeedbackEngine.shared.warmUp(
                audibleInSilentMode: audibleInSilentMode,
                soundMuted: soundMuted
            )
            requestCameraPermissionIfNeeded()
        }
        .onDisappear {
            setHardwareTorch(enabled: false)
        }
    }

    // MARK: - Flux Caméra Matériel (`DataScannerViewController` VisionKit ou `AVCaptureMetadataOutput`)

    @ViewBuilder
    private var liveScannerLayer: some View {
        #if canImport(VisionKit) && canImport(Vision)
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            VisionKitHardwareBarcodeView(
                isTorchOn: $isTorchOn,
                isMacroZoomEnabled: $isMacroZoomEnabled,
                onBarcodeDetected: { rawValue, symbology in
                    handleDetectedBarcode(rawCode: rawValue, symbology: symbology)
                }
            )
            .ignoresSafeArea()
        } else {
            AVFoundationHardwareBarcodeView(
                isTorchOn: $isTorchOn,
                isMacroZoomEnabled: $isMacroZoomEnabled,
                onBarcodeDetected: { rawValue, symbology in
                    handleDetectedBarcode(rawCode: rawValue, symbology: symbology)
                }
            )
            .ignoresSafeArea()
        }
        #else
        AVFoundationHardwareBarcodeView(
            isTorchOn: $isTorchOn,
            isMacroZoomEnabled: $isMacroZoomEnabled,
            onBarcodeDetected: { rawValue, symbology in
                handleDetectedBarcode(rawCode: rawValue, symbology: symbology)
            }
        )
        .ignoresSafeArea()
        #endif
    }

    // MARK: - Barre Supérieure (Fermer, Audio Douchette, Macro, Torche/Flash)

    private var topControlsBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    closeScannerModal()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Fermer")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }

                Spacer()

                // Réglage du Bip Douchette (Audible même en mode silencieux / Muet)
                Button {
                    WorkspaceHaptics.light()
                    if soundMuted {
                        soundMuted = false
                        audibleInSilentMode = true
                    } else if audibleInSilentMode {
                        audibleInSilentMode = false
                    } else {
                        soundMuted = true
                    }
                    ScannerSensoryFeedbackEngine.shared.configureAudioSession(
                        audibleInSilentMode: audibleInSilentMode,
                        soundMuted: soundMuted
                    )
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: soundMuted ? "speaker.slash.fill" : (audibleInSilentMode ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
                            .font(.system(size: 13, weight: .semibold))
                        Text(soundMuted ? "Muet" : (audibleInSilentMode ? "Bip Forcé" : "Bip Auto"))
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(soundMuted ? Color.black.opacity(0.55) : WorkspaceTheme.forest.opacity(0.88))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                }
                .accessibilityLabel("Mode sonore du bip douchette")

                // Bouton Zoom / Autofocus Macro Proche (1.6x)
                Button {
                    WorkspaceHaptics.light()
                    isMacroZoomEnabled.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.macro")
                            .font(.system(size: 13, weight: .semibold))
                        Text(isMacroZoomEnabled ? "1.6×" : "1×")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(isMacroZoomEnabled ? WorkspaceTheme.terracotta : Color.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                }
                .accessibilityLabel("Autofocus macro rapproché")

                // Bouton Torche / Flash Matériel
                Button {
                    WorkspaceHaptics.light()
                    isTorchOn.toggle()
                    setHardwareTorch(enabled: isTorchOn)
                } label: {
                    Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(isTorchOn ? Color.yellow : Color.black.opacity(0.55))
                        .foregroundStyle(isTorchOn ? Color.black : Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                }
                .accessibilityLabel(isTorchOn ? "Éteindre la torche" : "Allumer la torche")
            }

            // Titre contextuel & Compteur Rafale en direct
            HStack(spacing: 8) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WorkspaceTheme.statusGreen)
                Text(contextHeadline)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if scanMode == .burst {
                    Text("• \(totalScanCount) lu\(totalScanCount > 1 ? "s" : "")")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(WorkspaceTheme.statusGreen)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.62))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - Viseur Laser Central ISBN / EAN-13 / Code 128 / QR

    private var centerReticleOverlay: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        showDetectionFlash ? WorkspaceTheme.statusGreen : Color.white.opacity(0.75),
                        lineWidth: showDetectionFlash ? 3.5 : 2.0
                    )
                    .frame(width: 286, height: 174)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.10))
                    )

                // Ligne de visée douchette laser
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                showDetectionFlash ? WorkspaceTheme.statusGreen : WorkspaceTheme.terracotta,
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 254, height: 2)
            }

            Text("EAN-13 / ISBN · EAN-8 · Code 128 · QR Code")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
        }
        .allowsHitTesting(false)
    }

    // MARK: - Panneau Inférieur : Mode Scan Unique vs Mode Rafale + Compteur & Derniers Scans

    private var bottomModeAndBurstPanel: some View {
        VStack(spacing: 12) {
            // Dernier article bippé (retour visuel instantané + bouton +1 rapide en mode Rafale)
            if !lastScannedCode.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(WorkspaceTheme.statusGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(lastScannedCode)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text(lastScannedSymbology)
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(WorkspaceTheme.forest)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        if scanMode == .burst,
                           let match = scannedEntries.first(where: { $0.code == lastScannedCode }) {
                            Text("Quantité bippée pour cette référence : ×\(match.quantity)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }

                    Spacer()

                    if scanMode == .burst {
                        Button {
                            processAcceptedCode(lastScannedCode, symbology: lastScannedSymbology, bypassCooldown: true)
                        } label: {
                            Text("+1 ex.")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(WorkspaceTheme.forestAccent)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(12)
                .background(Color(red: 0.067, green: 0.102, blue: 0.090).opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(WorkspaceTheme.statusGreen.opacity(0.55), lineWidth: 1.2)
                )
            }

            // Ruban horizontal des articles scannés en Mode Rafale
            if scanMode == .burst && !scannedEntries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(scannedEntries) { entry in
                            HStack(spacing: 6) {
                                Text(entry.code)
                                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("×\(entry.quantity)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(WorkspaceTheme.terracotta)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Sélecteur Mode Scan Unique / Mode Rafale + Bouton de validation Rafale
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(NativeBarcodeScanMode.allCases) { mode in
                        let selected = (scanMode == mode)
                        Button {
                            WorkspaceHaptics.light()
                            withAnimation(.snappy(duration: 0.2)) {
                                scanMode = mode
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode == .single ? "1.circle.fill" : "square.stack.3d.up.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(mode.label)
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selected ? WorkspaceTheme.forest : Color.white.opacity(0.10))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(selected ? WorkspaceTheme.statusGreen.opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(scanMode.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)

                if scanMode == .burst && totalScanCount > 0 {
                    Button {
                        WorkspaceHaptics.medium()
                        closeScannerModal()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Terminer la rafale (\(totalScanCount) article\(totalScanCount > 1 ? "s" : "") · \(scannedEntries.count) réf.)")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(WorkspaceTheme.statusGreen)
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(14)
            .background(Color(red: 0.055, green: 0.082, blue: 0.075).opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.macro.slash")
                .font(.system(size: 44))
                .foregroundStyle(WorkspaceTheme.terracotta)
            Text("Accès caméra requis")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text("Autorisez l'accès à l'appareil photo dans Réglages > Cenelis Workspace afin d'utiliser le lecteur matériel de codes-barres ISBN / EAN-13.")
                .font(.system(size: 13.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 28)

            #if canImport(UIKit)
            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text("Ouvrir les Réglages iOS")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(WorkspaceTheme.forest)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            #endif
        }
    }

    // MARK: - Traitement Normalisé, Anti-Rebond, Retour Sensoriel & Callback WebView

    private func requestCameraPermissionIfNeeded() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthStatus = status
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    cameraAuthStatus = granted ? .authorized : .denied
                }
            }
        }
    }

    private func handleDetectedBarcode(rawCode: String, symbology: String) {
        guard !isClosingAfterSingleScan else { return }
        let cleaned = Self.normalizeScannedPayload(rawCode, symbology: symbology)
        guard !cleaned.isEmpty else { return }
        processAcceptedCode(cleaned, symbology: symbology, bypassCooldown: false)
    }

    private func processAcceptedCode(_ cleaned: String, symbology: String, bypassCooldown: Bool) {
        let now = Date()
        if !bypassCooldown {
            // En mode rafale, éviter les lectures multiples accidentelles sur un même livre maintenu devant l'objectif (< 1,35 s),
            // mais accepter instantanément (0 ms) tout code différent !
            if cleaned == lastScannedCode && now.timeIntervalSince(lastScannedTimestamp) < 1.35 {
                return
            }
            // Anti-rebond minimal inter-trames (180 ms)
            if now.timeIntervalSince(lastScannedTimestamp) < 0.18 {
                return
            }
        }

        lastScannedCode = cleaned
        lastScannedSymbology = symbology
        lastScannedTimestamp = now
        totalScanCount += 1

        if let idx = scannedEntries.firstIndex(where: { $0.code == cleaned }) {
            var updated = scannedEntries[idx]
            updated.quantity += 1
            updated.lastScannedAt = now
            scannedEntries.remove(at: idx)
            scannedEntries.insert(updated, at: 0)
        } else {
            scannedEntries.insert(ScannedBarcodeEntry(code: cleaned, symbology: symbology, quantity: 1, lastScannedAt: now), at: 0)
        }

        // 1. Retour sensoriel double immédiat : Bip Douchette + Vibration Haptique
        ScannerSensoryFeedbackEngine.shared.fireScanSuccessFeedback(
            audibleInSilentMode: audibleInSilentMode,
            soundMuted: soundMuted
        )

        // 2. Flash visuel vert sur le cadre
        withAnimation(.easeOut(duration: 0.10)) {
            showDetectionFlash = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.easeIn(duration: 0.18)) {
                showDetectionFlash = false
            }
        }

        // 3. Remontée temps réel vers Wingman via `window.onNativeBarcodeScanned(code, meta)`
        onCodeScanned(cleaned, symbology, scanMode, totalScanCount)

        // 4. Fermeture automatique si Mode Scan Unique
        if scanMode == .single {
            isClosingAfterSingleScan = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 230_000_000)
                closeScannerModal()
            }
        }
    }

    private func closeScannerModal() {
        setHardwareTorch(enabled: false)
        onCloseScanner(scanMode, scannedEntries)
        dismiss()
    }

    private func setHardwareTorch(enabled: Bool) {
        guard let device = HardwareCameraOpticsHelper.preferredRearVideoDevice(),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if enabled {
                try device.setTorchModeOn(level: 0.85)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            // Ignorer si la torche est momentanément indisponible
        }
    }

    private static func normalizeScannedPayload(_ raw: String, symbology: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Conversion automatique UPC-A préfixé '0' par iOS EAN-13 uniquement si pertinent ;
        // les ISBN-13 commencent par 978 / 979 et sont conservés intégralement sur 13 chiffres.
        if symbology.contains("EAN") || symbology.contains("ISBN") || symbology.contains("UPC") {
            let digitsOnly = trimmed.filter { $0.isNumber || $0 == "X" || $0 == "x" }.uppercased()
            return digitsOnly
        }
        return trimmed
    }
}

// MARK: - Optique Matérielle Partagée (Autofocus Macro Rapproché, Sélection Multi-Objectifs & Torche)

enum HardwareCameraOpticsHelper {
    static func preferredRearVideoDevice() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: .back
        )
        return discovery.devices.first ?? AVCaptureDevice.default(for: .video)
    }

    static func applyMacroAndTorchConfiguration(
        to device: AVCaptureDevice,
        torchOn: Bool,
        macroZoom: Bool
    ) {
        do {
            try device.lockForConfiguration()
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            let desiredZoom: CGFloat = macroZoom ? min(1.65, device.activeFormat.videoMaxZoomFactor) : 1.0
            if abs(device.videoZoomFactor - desiredZoom) > 0.05 {
                device.videoZoomFactor = max(1.0, desiredZoom)
            }

            if device.hasTorch {
                if torchOn {
                    try? device.setTorchModeOn(level: 0.85)
                } else {
                    device.torchMode = .off
                }
            }
            device.unlockForConfiguration()
        } catch {
            // Continuer avec les réglages matériels courants
        }
    }
}

// MARK: - Moteur 1 : `DataScannerViewController` (VisionKit Haute Fréquence iOS 16+)

#if canImport(VisionKit) && canImport(Vision)
private struct VisionKitHardwareBarcodeView: UIViewControllerRepresentable {
    @Binding var isTorchOn: Bool
    @Binding var isMacroZoomEnabled: Bool
    let onBarcodeDetected: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let symbologies: [VNBarcodeSymbology] = [
            .ean13,
            .ean8,
            .upce,
            .code128,
            .code39,
            .itf14,
            .qr,
            .dataMatrix
        ]
        let scannerVC = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: symbologies)],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scannerVC.delegate = context.coordinator

        try? scannerVC.startScanning()
        if let device = HardwareCameraOpticsHelper.preferredRearVideoDevice() {
            HardwareCameraOpticsHelper.applyMacroAndTorchConfiguration(
                to: device,
                torchOn: isTorchOn,
                macroZoom: isMacroZoomEnabled
            )
        }
        return scannerVC
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
        if let device = HardwareCameraOpticsHelper.preferredRearVideoDevice() {
            HardwareCameraOpticsHelper.applyMacroAndTorchConfiguration(
                to: device,
                torchOn: isTorchOn,
                macroZoom: isMacroZoomEnabled
            )
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        if uiViewController.isScanning {
            uiViewController.stopScanning()
        }
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: VisionKitHardwareBarcodeView

        init(parent: VisionKitHardwareBarcodeView) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            forwardFirstBarcode(from: addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            forwardFirstBarcode(from: updatedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            forwardFirstBarcode(from: [item])
        }

        private func forwardFirstBarcode(from items: [RecognizedItem]) {
            for item in items {
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue,
                   !payload.isEmpty {
                    let sym = Self.friendlySymbologyName(barcode.observation.symbology, payload: payload)
                    parent.onBarcodeDetected(payload, sym)
                    break
                }
            }
        }

        private static func friendlySymbologyName(_ sym: VNBarcodeSymbology, payload: String) -> String {
            switch sym {
            case .ean13:
                if payload.hasPrefix("978") || payload.hasPrefix("979") {
                    return "ISBN-13"
                }
                return "EAN-13"
            case .ean8: return "EAN-8"
            case .upce: return "UPC-E"
            case .code128: return "CODE-128"
            case .code39: return "CODE-39"
            case .itf14: return "ITF-14"
            case .qr: return "QR"
            case .dataMatrix: return "2D-DATAMATRIX"
            default: return sym.rawValue.uppercased()
            }
        }
    }
}
#endif

// MARK: - Moteur 2 (Fallback Universel) : `AVCaptureSession` + `AVCaptureMetadataOutput`

private struct AVFoundationHardwareBarcodeView: UIViewRepresentable {
    @Binding var isTorchOn: Bool
    @Binding var isMacroZoomEnabled: Bool
    let onBarcodeDetected: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        context.coordinator.configureCaptureSession(in: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateOptics(torchOn: isTorchOn, macroZoom: isMacroZoomEnabled)
    }

    static func dismantleUIView(_ uiView: CameraPreviewContainerView, coordinator: Coordinator) {
        coordinator.stopSession()
    }

    final class CameraPreviewContainerView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    @MainActor
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: AVFoundationHardwareBarcodeView
        private let captureSession = AVCaptureSession()
        private let sessionQueue = DispatchQueue(label: "com.cenelis.workspace.barcodescanner")
        private var activeDevice: AVCaptureDevice?

        init(parent: AVFoundationHardwareBarcodeView) {
            self.parent = parent
        }

        func configureCaptureSession(in view: CameraPreviewContainerView) {
            view.videoPreviewLayer.session = captureSession
            view.videoPreviewLayer.videoGravity = .resizeAspectFill

            let initialTorch = parent.isTorchOn
            let initialMacro = parent.isMacroZoomEnabled
            let session = captureSession
            let delegateRef = self

            sessionQueue.async {
                session.beginConfiguration()
                if session.canSetSessionPreset(.hd1920x1080) {
                    session.sessionPreset = .hd1920x1080
                }

                guard let videoDevice = HardwareCameraOpticsHelper.preferredRearVideoDevice(),
                      let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                      session.canAddInput(videoInput) else {
                    session.commitConfiguration()
                    return
                }
                session.addInput(videoInput)

                let metadataOutput = AVCaptureMetadataOutput()
                if session.canAddOutput(metadataOutput) {
                    session.addOutput(metadataOutput)
                    metadataOutput.setMetadataObjectsDelegate(delegateRef, queue: DispatchQueue.main)
                    let desiredTypes: [AVMetadataObject.ObjectType] = [
                        .ean13, .ean8, .upce, .code128, .code39, .itf14, .qr, .dataMatrix
                    ]
                    let supported = Set(metadataOutput.availableMetadataObjectTypes)
                    metadataOutput.metadataObjectTypes = desiredTypes.filter { supported.contains($0) }
                }

                HardwareCameraOpticsHelper.applyMacroAndTorchConfiguration(
                    to: videoDevice,
                    torchOn: initialTorch,
                    macroZoom: initialMacro
                )
                session.commitConfiguration()
                session.startRunning()

                Task { @MainActor in
                    delegateRef.activeDevice = videoDevice
                }
            }
        }

        func updateOptics(torchOn: Bool, macroZoom: Bool) {
            guard let device = activeDevice else { return }
            sessionQueue.async {
                HardwareCameraOpticsHelper.applyMacroAndTorchConfiguration(
                    to: device,
                    torchOn: torchOn,
                    macroZoom: macroZoom
                )
            }
        }

        func stopSession() {
            let session = captureSession
            sessionQueue.async {
                if session.isRunning {
                    session.stopRunning()
                }
            }
        }

        nonisolated func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let rawValue = readable.stringValue,
                  !rawValue.isEmpty else {
                return
            }
            let objType = readable.type
            Task { @MainActor [weak self] in
                guard let self else { return }
                let sym = Self.friendlyAVSymbology(objType, payload: rawValue)
                self.parent.onBarcodeDetected(rawValue, sym)
            }
        }

        private static func friendlyAVSymbology(_ type: AVMetadataObject.ObjectType, payload: String) -> String {
            switch type {
            case .ean13:
                return (payload.hasPrefix("978") || payload.hasPrefix("979")) ? "ISBN-13" : "EAN-13"
            case .ean8: return "EAN-8"
            case .upce: return "UPC-E"
            case .code128: return "CODE-128"
            case .code39: return "CODE-39"
            case .itf14: return "ITF-14"
            case .qr: return "QR"
            case .dataMatrix: return "2D-DATAMATRIX"
            default: return type.rawValue.uppercased()
            }
        }
    }
}
