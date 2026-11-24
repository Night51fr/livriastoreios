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
    public let cguVersion: String?
    public let cguHash: String?
}

public struct AcademyAuthResponse: Codable, Sendable {
    public let ok: Bool
    public let pinBypassed: Bool?
    public let token: String?
    public let error: String?
    public let errorCode: String?
    public let learner: AcademyLearnerProfile?
    public let cgu: AcademyCGUDocument?
    public let cguAcceptance: AcademyCGUAcceptanceStatus?
    public let progress: AcademyUserProgress?
}

public struct AcademyProgressEnvelope: Codable, Sendable {
    public let ok: Bool
    public let authenticated: Bool?
    public let email: String?
    public let data: AcademyUserProgress?
}

public struct AcademyMeResponse: Codable, Sendable {
    public let ok: Bool
    public let authenticated: Bool
    public let email: String
    public let displayName: String
    public let cid: String
    public let groups: [String]
    public let hasCenelisAccess: Bool
    public let permissionScope: String
    public let rbacStatus: String
    public let cgu: AcademyCGUDocument?
    public let cguAcceptance: AcademyCGUAcceptanceStatus?

    public var learnerProfile: AcademyLearnerProfile {
        AcademyLearnerProfile(
            authenticated: authenticated,
            email: email,
            displayName: displayName,
            cid: cid,
            groups: groups,
            hasCenelisAccess: hasCenelisAccess,
            permissionScope: permissionScope,
            rbacStatus: rbacStatus
        )
    }
}

public struct AcademyCGUResponse: Codable, Sendable {
    public let ok: Bool
    public let cgu: AcademyCGUDocument
    public let acceptance: AcademyCGUAcceptanceStatus?
}

public struct AcademyCGUAcceptResponse: Codable, Sendable {
    public let ok: Bool
    public let acceptedVersion: String?
    public let acceptedHash: String?
    public let acceptedAtUtc: String?
    public let error: String?
    public let errorCode: String?
}

public struct AcademyPinStatusResponse: Codable, Sendable {
    public let ok: Bool
    public let verified: Bool
    public let expired: Bool?
    public let nonce: String?
    public let proof: String?
    public let verifiedAtUtc: String?
}

public struct AcademyDailyNudgeResponse: Codable, Sendable {
    public let ok: Bool
    public let nudgeId: String
    public let dateParis: String
    public let variant: String
    public let title: String
    public let subtitle: String
    public let body: String
    public let courseId: String
    public let courseTitle: String?
    public let courseProgressPct: Int?
    public let streakDays: Int
    public let studiedToday: Bool
    public let deepLink: String
    public let category: String?
    public let threadId: String?
    public let alreadyPushedToday: Bool?
    public let notificationsEnabled: Bool?
}

private struct AcademyForbiddenEnvelope: Codable, Sendable {
    let ok: Bool?
    let errorCode: String?
    let message: String?
    let learner: AcademyLearnerProfile?
}

public enum AcademyAPIError: LocalizedError, Sendable {
    case invalidResponse
    case unauthorized
    case forbiddenCenelisPermission(AcademyLearnerProfile?)
    case serverMessage(String)
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Réponse serveur Cenelis Academy inattendue."
        case .unauthorized:
            return "Session expirée. Veuillez vous reconnecter avec votre compte Cenelis / Viple Live ID."
        case .forbiddenCenelisPermission:
            return "Votre compte ne dispose d'aucune habilitation interne ou externe Cenelis active."
        case .serverMessage(let msg):
            return msg
        case .networkUnavailable:
            return "Connexion réseau indisponible. Vérifiez votre accès Internet."
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

    public func buildPinLaunchURL(token: String, nonce: String) -> URL? {
        guard !token.isEmpty, !nonce.isEmpty else { return nil }
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/mobile/v1/auth/pin-start"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "nonce", value: nonce)
        ]
        return comps?.url
    }

    // MARK: - Persistance Locale d'Acceptation des CGU (Premier Lancement + Détection de Modification)

    private func localCGUKey(forEmail email: String) -> String {
        let norm = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digest = SHA256.hash(data: Data(norm.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined().prefix(24)
        return "ca.cgu.accepted.\(hex)"
    }

    public func loadLocalCGUAcceptance(forEmail email: String) -> (version: String, hash: String, acceptedAt: String)? {
        let norm = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !norm.isEmpty,
              let dict = UserDefaults.standard.dictionary(forKey: localCGUKey(forEmail: norm)) as? [String: String],
              let ver = dict["version"], !ver.isEmpty,
              let h = dict["hash"], !h.isEmpty else {
            return nil
        }
        return (ver, h, dict["acceptedAt"] ?? "")
    }

    public func saveLocalCGUAcceptance(forEmail email: String, version: String, hash: String, acceptedAt: String) {
        let norm = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !norm.isEmpty else { return }
        let dict: [String: String] = [
            "version": version,
            "hash": hash,
            "acceptedAt": acceptedAt
        ]
        UserDefaults.standard.set(dict, forKey: localCGUKey(forEmail: norm))
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

        guard let http = resp as? HTTPURLResponse else {
            throw AcademyAPIError.invalidResponse
        }
        if http.statusCode == 401 {
            throw AcademyAPIError.unauthorized
        }
        if http.statusCode == 403 {
            let env = try? JSONDecoder().decode(AcademyForbiddenEnvelope.self, from: data)
            throw AcademyAPIError.forbiddenCenelisPermission(env?.learner)
        }
        guard (200..<300).contains(http.statusCode) else {
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

    public func fetchMe(token: String) async throws -> AcademyMeResponse {
        guard !token.isEmpty else { throw AcademyAPIError.unauthorized }
        let url = baseURL.appendingPathComponent("api/mobile/v1/me")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AcademyAPIError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse else {
            throw AcademyAPIError.invalidResponse
        }
        if http.statusCode == 401 {
            throw AcademyAPIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AcademyAPIError.invalidResponse
        }
        return try JSONDecoder().decode(AcademyMeResponse.self, from: data)
    }

    public func fetchCGU(token: String?) async throws -> AcademyCGUResponse {
        let url = baseURL.appendingPathComponent("api/mobile/v1/cgu")
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
        return try JSONDecoder().decode(AcademyCGUResponse.self, from: data)
    }

    public func acceptCGU(version: String, contentHash: String, token: String) async throws -> AcademyCGUAcceptResponse {
        guard !token.isEmpty else { throw AcademyAPIError.unauthorized }
        let url = baseURL.appendingPathComponent("api/mobile/v1/cgu/accept")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: String] = [
            "version": version,
            "contentHash": contentHash
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AcademyAPIError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse else {
            throw AcademyAPIError.invalidResponse
        }
        if http.statusCode == 401 {
            throw AcademyAPIError.unauthorized
        }
        if http.statusCode == 403 {
            throw AcademyAPIError.forbiddenCenelisPermission(nil)
        }
        let decoded = try JSONDecoder().decode(AcademyCGUAcceptResponse.self, from: data)
        if !decoded.ok {
            throw AcademyAPIError.serverMessage(decoded.error ?? "Impossible d'enregistrer l'acceptation des CGU.")
        }
        return decoded
    }

    public func checkPinLaunchStatus(nonce: String, token: String) async -> AcademyPinStatusResponse? {
        guard !nonce.isEmpty, !token.isEmpty else { return nil }
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/mobile/v1/auth/pin-status"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "nonce", value: nonce)]
        guard let url = comps?.url else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AcademyPinStatusResponse.self, from: data) else {
            return nil
        }
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

    public func redeemPinBypassToken(_ pinBypassToken: String) async throws -> AcademyAuthResponse {
        let trimmed = pinBypassToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AcademyAPIError.unauthorized }

        let url = baseURL.appendingPathComponent("api/mobile/v1/auth/redeem-pin-bypass")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["pinBypassToken": trimmed])

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AcademyAPIError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse else {
            throw AcademyAPIError.invalidResponse
        }
        if http.statusCode == 401 {
            throw AcademyAPIError.unauthorized
        }
        if http.statusCode == 403 {
            let env = try? JSONDecoder().decode(AcademyForbiddenEnvelope.self, from: data)
            throw AcademyAPIError.forbiddenCenelisPermission(env?.learner)
        }
        let decoded = try JSONDecoder().decode(AcademyAuthResponse.self, from: data)
        if !decoded.ok {
            throw AcademyAPIError.serverMessage(decoded.error ?? "Jeton de transfert Cenelis Workspace invalide ou expiré.")
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

    // MARK: - Notifications Quotidiennes APNs (.p8) & Nudge Arrière-Plan 1×/jour

    public func registerPushDevice(
        deviceId: String,
        apnsToken: String,
        apnsEnvironment: String,
        appleTeamId: String?,
        notificationsEnabled: Bool,
        preferredHourParis: Int,
        preferredMinuteParis: Int,
        token: String
    ) async -> Bool {
        guard !token.isEmpty else { return false }
        let url = baseURL.appendingPathComponent("api/mobile/v1/devices/register")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var payload: [String: Any] = [
            "deviceId": deviceId,
            "apnsToken": apnsToken,
            "apnsEnvironment": apnsEnvironment,
            "notificationsEnabled": notificationsEnabled,
            "preferredHourParis": preferredHourParis,
            "preferredMinuteParis": preferredMinuteParis
        ]
        if let appleTeamId, !appleTeamId.isEmpty {
            payload["appleTeamId"] = appleTeamId
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        req.httpBody = body

        guard let (_, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse else {
            return false
        }
        return (200..<300).contains(http.statusCode)
    }

    public func unregisterPushDevice(
        deviceId: String,
        apnsToken: String,
        token: String
    ) async -> Bool {
        guard !token.isEmpty else { return false }
        let url = baseURL.appendingPathComponent("api/mobile/v1/devices/unregister")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let payload: [String: String] = [
            "deviceId": deviceId,
            "apnsToken": apnsToken
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        req.httpBody = body

        guard let (_, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse else {
            return false
        }
        return (200..<300).contains(http.statusCode)
    }

    public func fetchDailyNudge(token: String) async -> AcademyDailyNudgeResponse? {
        guard !token.isEmpty else { return nil }
        let url = baseURL.appendingPathComponent("api/mobile/v1/notifications/daily-nudge")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AcademyDailyNudgeResponse.self, from: data) else {
            return nil
        }
        return decoded
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
