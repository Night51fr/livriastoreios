import Foundation
import SwiftUI
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Enveloppes Réseau API Mobile (/api/mobile/v1/*)

public struct AcademyVersionResponse: Codable, Sendable {
    public let ok: Bool
    public let contentVersion: String
}

public struct AcademyAuthResponse: Codable, Sendable {
    public let ok: Bool
    public let token: String?
    public let error: String?
    public let learner: AcademyLearnerProfile?
    public let progress: AcademyUserProgress?
}

public struct AcademyProgressEnvelope: Codable, Sendable {
    public let ok: Bool
    public let authenticated: Bool?
    public let email: String?
    public let data: AcademyUserProgress?
}

public enum AcademyAPIError: LocalizedError, Sendable {
    case invalidResponse
    case serverMessage(String)
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Réponse serveur Cenelis Academy inattendue."
        case .serverMessage(let msg):
            return msg
        case .networkUnavailable:
            return "Connexion réseau indisponible. Mode hors-ligne activé sur le cache local."
        }
    }
}

// MARK: - Client Réseau & Cache Hors-Ligne Instantané

@MainActor
public final class AcademyAPIClient {
    public static let shared = AcademyAPIClient()

    public let baseURL = URL(string: "https://academy.prod.cenelis.com")!
    private let session: URLSession
    private let cacheDirectory: URL
    private let capturesCacheDirectory: URL

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 18
        config.timeoutIntervalForResource = 45
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)

        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let cacheDir = appSupport.appendingPathComponent("CenelisAcademyCache", isDirectory: true)
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        self.cacheDirectory = cacheDir

        let sysCaches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let capDir = sysCaches.appendingPathComponent("CenelisAcademyCaptures", isDirectory: true)
        try? fm.createDirectory(at: capDir, withIntermediateDirectories: true)
        self.capturesCacheDirectory = capDir
    }

    private var bootstrapCacheURL: URL {
        cacheDirectory.appendingPathComponent("bootstrap_v1.json")
    }

    private var progressCacheURL: URL {
        cacheDirectory.appendingPathComponent("local_progress_v1.json")
    }

    public func ssoStartURL() -> URL {
        baseURL.appendingPathComponent("api/mobile/v1/auth/sso-start")
    }

    public func resolveAssetURL(_ rawPath: String?) -> URL? {
        guard let raw = rawPath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        let clean = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
        return baseURL.appendingPathComponent(clean)
    }

    // MARK: - Cache Disque (Démarrage < 50 ms & Apprentissage Hors-Ligne)

    public func loadCachedBootstrap() -> AcademyBootstrapPayload? {
        guard let data = try? Data(contentsOf: bootstrapCacheURL) else { return nil }
        return try? JSONDecoder().decode(AcademyBootstrapPayload.self, from: data)
    }

    public func saveCachedBootstrapData(_ data: Data) {
        try? data.write(to: bootstrapCacheURL, options: .atomic)
    }

    public func loadLocalProgress() -> AcademyUserProgress? {
        guard let data = try? Data(contentsOf: progressCacheURL) else { return nil }
        return try? JSONDecoder().decode(AcademyUserProgress.self, from: data)
    }

    public func saveLocalProgress(_ progress: AcademyUserProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        try? data.write(to: progressCacheURL, options: .atomic)
    }

    public func cachedCapturesSizeMB() -> Double {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: capturesCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var bytes: Int64 = 0
        for file in files {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                bytes += Int64(size)
            }
        }
        return Double(bytes) / (1024.0 * 1024.0)
    }

    public func clearCapturesCache() {
        let fm = FileManager.default
        try? fm.removeItem(at: capturesCacheDirectory)
        try? fm.createDirectory(at: capturesCacheDirectory, withIntermediateDirectories: true)
        AcademyImageLoader.shared.purgeMemory()
    }

    public func captureDiskFileURL(for remoteURL: URL) -> URL {
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined().prefix(32)
        let ext = remoteURL.pathExtension.isEmpty ? "png" : remoteURL.pathExtension
        return capturesCacheDirectory.appendingPathComponent("\(hex).\(ext)")
    }

    // MARK: - Appels Réseau Live Cenelis Academy

    public func fetchVersion() async -> String? {
        let url = baseURL.appendingPathComponent("api/mobile/v1/version")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AcademyVersionResponse.self, from: data) else {
            return nil
        }
        return decoded.contentVersion
    }

    public func fetchBootstrap(token: String?, includeHidden: Bool = true) async throws -> AcademyBootstrapPayload {
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/mobile/v1/bootstrap"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "includeHidden", value: includeHidden ? "1" : "0")]
        guard let url = comps?.url else { throw AcademyAPIError.invalidResponse }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AcademyAPIError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AcademyAPIError.invalidResponse
        }

        var decoded = try JSONDecoder().decode(AcademyBootstrapPayload.self, from: data)
        // Hydrater la clé de chaque bulle pour l'identifiant
        var hydratedBubbles: [String: AcademyBubble] = [:]
        for (k, var v) in decoded.bubbles {
            v.key = k
            hydratedBubbles[k] = v
        }
        decoded.bubbles = hydratedBubbles

        saveCachedBootstrapData(data)
        return decoded
    }

    public func login(email: String, password: String) async throws -> AcademyAuthResponse {
        let url = baseURL.appendingPathComponent("api/mobile/v1/auth/login")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: req)
        let decoded = try JSONDecoder().decode(AcademyAuthResponse.self, from: data)
        if !decoded.ok {
            throw AcademyAPIError.serverMessage(decoded.error ?? "Identifiants Viple Live ID incorrects.")
        }
        return decoded
    }

    public func fetchCloudProgress(token: String) async -> AcademyUserProgress? {
        guard !token.isEmpty else { return nil }
        let url = baseURL.appendingPathComponent("api/mobile/v1/progress")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let env = try? JSONDecoder().decode(AcademyProgressEnvelope.self, from: data) else {
            return nil
        }
        return env.data
    }

    public func pushCloudProgress(_ progress: AcademyUserProgress, token: String) async -> Bool {
        guard !token.isEmpty else { return false }
        let url = baseURL.appendingPathComponent("api/mobile/v1/progress")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let body = try? JSONEncoder().encode(progress) else { return false }
        req.httpBody = body

        guard let (_, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse else {
            return false
        }
        return (200..<300).contains(http.statusCode)
    }
}

// MARK: - Chargeur d'Images @2x avec Double Cache (RAM NSCache + Disque Hors-Ligne)

@MainActor
public final class AcademyImageLoader {
    public static let shared = AcademyImageLoader()

    #if canImport(UIKit)
    private let memoryCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 140
        c.totalCostLimit = 90 * 1024 * 1024
        return c
    }()
    #endif

    private init() {}

    public func purgeMemory() {
        #if canImport(UIKit)
        memoryCache.removeAllObjects()
        #endif
    }

    #if canImport(UIKit)
    public func loadImage(for rawPath: String?) async -> UIImage? {
        guard let remoteURL = AcademyAPIClient.shared.resolveAssetURL(rawPath) else { return nil }
        let key = remoteURL.absoluteString as NSString

        if let mem = memoryCache.object(forKey: key) {
            return mem
        }

        let diskFile = AcademyAPIClient.shared.captureDiskFileURL(for: remoteURL)
        if let diskData = try? Data(contentsOf: diskFile),
           let diskImg = UIImage(data: diskData) {
            memoryCache.setObject(diskImg, forKey: key, cost: diskData.count)
            return diskImg
        }

        var req = URLRequest(url: remoteURL)
        req.timeoutInterval = 20
        guard let (netData, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let netImg = UIImage(data: netData) else {
            return nil
        }

        try? netData.write(to: diskFile, options: .atomic)
        memoryCache.setObject(netImg, forKey: key, cost: netData.count)
        return netImg
    }
    #endif
}

// MARK: - Composant SwiftUI de Rendu de Capture Haute Définition @2x

public struct CachedAcademyImage: View {
    public let path: String?
    public var contentMode: ContentMode = .fit
    public var cornerRadius: CGFloat = 14
    public var minPlaceholderHeight: CGFloat = 185

    #if canImport(UIKit)
    @State private var loadedImage: UIImage?
    #endif
    @State private var isLoading: Bool = true
    @State private var reloadTrigger: Int = 0

    public init(
        path: String?,
        contentMode: ContentMode = .fit,
        cornerRadius: CGFloat = 14,
        minPlaceholderHeight: CGFloat = 185
    ) {
        self.path = path
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.minPlaceholderHeight = minPlaceholderHeight
    }

    public var body: some View {
        Group {
            #if canImport(UIKit)
            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: contentMode)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else if isLoading {
                shimmerPlaceholder
            } else {
                offlineFallbackCard
            }
            #else
            shimmerPlaceholder
            #endif
        }
        .task(id: "\(path ?? "")-\(reloadTrigger)") {
            isLoading = true
            #if canImport(UIKit)
            loadedImage = await AcademyImageLoader.shared.loadImage(for: path)
            #endif
            withAnimation(.easeOut(duration: 0.22)) {
                isLoading = false
            }
        }
    }

    private var shimmerPlaceholder: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = CGFloat((t * 0.65).truncatingRemainder(dividingBy: 1.0))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AcademyPalette.surfaceSubtle)
                .frame(minHeight: minPlaceholderHeight)
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .clear,
                                AcademyPalette.pine.opacity(0.10),
                                AcademyPalette.copper.opacity(0.08),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.75)
                        .offset(x: (phase * 1.8 - 0.5) * geo.size.width)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )
                .overlay(
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(AcademyPalette.pine)
                        Text("Chargement capture @2x…")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AcademyPalette.inkMuted)
                    }
                )
        }
    }

    private var offlineFallbackCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.arrow.down.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AcademyPalette.copper)
            Text("Capture en attente de connexion")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AcademyPalette.ink)
            Button {
                AcademyHaptics.selection()
                reloadTrigger += 1
            } label: {
                Label("Réessayer", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AcademyPalette.pineSoft))
                    .foregroundStyle(AcademyPalette.pine)
            }
            .buttonStyle(SpringPressableButtonStyle())
        }
        .frame(maxWidth: .infinity, minHeight: minPlaceholderHeight)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AcademyPalette.surfaceSubtle)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AcademyPalette.border, lineWidth: 1)
                )
        )
    }
}
