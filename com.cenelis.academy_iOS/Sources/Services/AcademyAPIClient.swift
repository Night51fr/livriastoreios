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
    public let isSignedIn: Bool?
    public let notificationsEnabled: Bool?
    public let sessionRevoked: Bool?

    enum CodingKeys: String, CodingKey {
        case ok, nudgeId, dateParis, variant, title, subtitle, body, courseId, courseTitle, courseProgressPct
        case streakDays, studiedToday, deepLink, category, threadId, alreadyPushedToday, isSignedIn, notificationsEnabled, sessionRevoked
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = (try? c.decode(Bool.self, forKey: .ok)) ?? false
        self.nudgeId = (try? c.decode(String.self, forKey: .nudgeId)) ?? ""
        self.dateParis = (try? c.decode(String.self, forKey: .dateParis)) ?? ""
        self.variant = (try? c.decode(String.self, forKey: .variant)) ?? "discover"
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        self.body = (try? c.decode(String.self, forKey: .body)) ?? ""
        self.courseId = (try? c.decode(String.self, forKey: .courseId)) ?? ""
        self.courseTitle = try? c.decode(String.self, forKey: .courseTitle)
        self.courseProgressPct = try? c.decode(Int.self, forKey: .courseProgressPct)
        self.streakDays = (try? c.decode(Int.self, forKey: .streakDays)) ?? 0
        self.studiedToday = (try? c.decode(Bool.self, forKey: .studiedToday)) ?? false
        self.deepLink = (try? c.decode(String.self, forKey: .deepLink)) ?? "cenelisacademy://home"
        self.category = try? c.decode(String.self, forKey: .category)
        self.threadId = try? c.decode(String.self, forKey: .threadId)
        self.alreadyPushedToday = try? c.decode(Bool.self, forKey: .alreadyPushedToday)
        self.isSignedIn = try? c.decode(Bool.self, forKey: .isSignedIn)
        self.notificationsEnabled = try? c.decode(Bool.self, forKey: .notificationsEnabled)
        self.sessionRevoked = try? c.decode(Bool.self, forKey: .sessionRevoked)
    }
}

// MARK: - Modèles du Hub Central d'Appareils Connectés (Viple Mail · Livria Store · Livria Social · Cenelis Academy)

public struct AcademyConnectedAppSession: Codable, Identifiable, Sendable, Equatable {
    public var id: String { "\(appId)-\(accountEmail)" }
    public let appId: String
    public let appName: String
    public let bundleId: String
    public let icon: String
    public let colorHex: String
    public let accountEmail: String
    public let appVersion: String
    public let notificationsEnabled: Bool
    public let lastSeenAtUtc: String

    enum CodingKeys: String, CodingKey {
        case appId, appName, bundleId, icon, colorHex, accountEmail, appVersion, notificationsEnabled, lastSeenAtUtc
    }

    public init(
        appId: String,
        appName: String,
        bundleId: String = "",
        icon: String = "app.badge.checkmark.fill",
        colorHex: String = "#145346",
        accountEmail: String = "",
        appVersion: String = "",
        notificationsEnabled: Bool = false,
        lastSeenAtUtc: String = ""
    ) {
        self.appId = appId
        self.appName = appName
        self.bundleId = bundleId
        self.icon = icon
        self.colorHex = colorHex
        self.accountEmail = accountEmail
        self.appVersion = appVersion
        self.notificationsEnabled = notificationsEnabled
        self.lastSeenAtUtc = lastSeenAtUtc
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawId = (try? c.decode(String.self, forKey: .appId)) ?? "ecosystem-app"
        self.appId = rawId
        self.appName = (try? c.decode(String.self, forKey: .appName)) ?? Self.defaultDisplayName(for: rawId)
        self.bundleId = (try? c.decode(String.self, forKey: .bundleId)) ?? ""
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? ""
        self.colorHex = (try? c.decode(String.self, forKey: .colorHex)) ?? "#145346"
        self.accountEmail = (try? c.decode(String.self, forKey: .accountEmail)) ?? ""
        self.appVersion = (try? c.decode(String.self, forKey: .appVersion)) ?? ""
        self.notificationsEnabled = (try? c.decode(Bool.self, forKey: .notificationsEnabled)) ?? false
        self.lastSeenAtUtc = (try? c.decode(String.self, forKey: .lastSeenAtUtc)) ?? ""
    }

    public static func defaultDisplayName(for appId: String) -> String {
        switch appId.lowercased() {
        case "viple-mail", "viplemail": return "Viple Mail"
        case "livria-store", "livriastore": return "Livria Store"
        case "livria-social", "livriasocial": return "Livria Social"
        case "cenelis-academy", "cenelisacademy": return "Cenelis Academy"
        case "cenelis-workspace", "cenelisworkspace": return "Cenelis Workspace"
        default: return appId
        }
    }
}

public struct AcademyConnectedDeviceItem: Codable, Identifiable, Sendable, Equatable {
    public var id: String { deviceId }
    public let deviceId: String
    public let rawDeviceIds: [String]
    public let modelName: String
    public let modelCode: String
    public let platform: String
    public let osVersion: String
    public let isCurrentDevice: Bool
    public let pushActive: Bool
    public let connectedAtUtc: String
    public let lastSeenAtUtc: String
    public let connectedApps: [AcademyConnectedAppSession]

    enum CodingKeys: String, CodingKey {
        case deviceId, rawDeviceIds, modelName, modelCode, platform, osVersion
        case isCurrentDevice, pushActive, connectedAtUtc, lastSeenAtUtc, connectedApps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.deviceId = (try? c.decode(String.self, forKey: .deviceId)) ?? UUID().uuidString
        self.rawDeviceIds = (try? c.decode([String].self, forKey: .rawDeviceIds)) ?? []
        self.modelName = (try? c.decode(String.self, forKey: .modelName)) ?? ""
        self.modelCode = (try? c.decode(String.self, forKey: .modelCode)) ?? ""
        self.platform = (try? c.decode(String.self, forKey: .platform)) ?? "iOS"
        self.osVersion = (try? c.decode(String.self, forKey: .osVersion)) ?? ""
        self.isCurrentDevice = (try? c.decode(Bool.self, forKey: .isCurrentDevice)) ?? false
        self.pushActive = (try? c.decode(Bool.self, forKey: .pushActive)) ?? false
        self.connectedAtUtc = (try? c.decode(String.self, forKey: .connectedAtUtc)) ?? ""
        self.lastSeenAtUtc = (try? c.decode(String.self, forKey: .lastSeenAtUtc)) ?? ""
        self.connectedApps = (try? c.decode([AcademyConnectedAppSession].self, forKey: .connectedApps)) ?? []
    }

    public var resolvedDisplayModelName: String {
        let trimmedName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let genericNames: Set<String> = ["", "iphone", "ipad", "ios", "apple", "appareil ios"]
        if !genericNames.contains(trimmedName.lowercased()) {
            return trimmedName
        }
        let trimmedCode = modelCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCode.isEmpty {
            return AcademyDeviceHardwareInfo.readableAppleModelName(for: trimmedCode)
        }
        return trimmedName.isEmpty ? "iPhone" : trimmedName
    }
}

public struct AcademyConnectedDevicesResponse: Codable, Sendable {
    public let ok: Bool
    public let devices: [AcademyConnectedDeviceItem]

    enum CodingKeys: String, CodingKey { case ok, devices }

    public init(ok: Bool = true, devices: [AcademyConnectedDeviceItem] = []) {
        self.ok = ok
        self.devices = devices
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = (try? c.decode(Bool.self, forKey: .ok)) ?? true
        self.devices = (try? c.decode([AcademyConnectedDeviceItem].self, forKey: .devices)) ?? []
    }
}

public struct AcademyDeviceRevokeResponse: Codable, Sendable {
    public let ok: Bool
    public let targetDeviceId: String?
    public let targetAppId: String?
    public let localRevokedCount: Int?
    public let error: String?
}

private struct AcademyForbiddenEnvelope: Codable, Sendable {
    let ok: Bool?
    let errorCode: String?
    let message: String?
    let learner: AcademyLearnerProfile?
}

private struct AcademySessionRevokedEnvelope: Codable, Sendable {
    let ok: Bool?
    let sessionRevoked: Bool?
    let error: String?
}

// MARK: - Identité Matérielle Partagée Écosystème Viple / Livria / Cenelis (App Group + uname)

public struct AcademyDeviceHardwareInfo: Sendable, Equatable {
    public static let sharedSuiteName = "group.com.viplenetwork.shared"
    public static let sharedPhysicalIdKey = "cenelis.shared.physicalDeviceId.v1"
    public static let localDeviceIdKey = "ca.notif.deviceId"

    public let deviceId: String
    public let physicalDeviceId: String
    public let modelCode: String
    public let modelName: String
    public let deviceCustomName: String
    public let osVersion: String
    public let appVersion: String

    @MainActor
    public static func current() -> AcademyDeviceHardwareInfo {
        let devId = resolveOrCreateLocalDeviceId()
        let physId = resolveOrPersistSharedPhysicalDeviceId(fallbackDeviceId: devId)
        let code = rawHardwareModelCode()
        let readable = readableAppleModelName(for: code)

        #if canImport(UIKit)
        let osVer = UIDevice.current.systemVersion
        let customName = UIDevice.current.name
        #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let osVer = "\(v.majorVersion).\(v.minorVersion)"
        let customName = readable
        #endif

        let appVer = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "2026.11.3"

        return AcademyDeviceHardwareInfo(
            deviceId: devId,
            physicalDeviceId: physId,
            modelCode: code,
            modelName: readable,
            deviceCustomName: customName,
            osVersion: osVer,
            appVersion: appVer
        )
    }

    @MainActor
    public static func resolveOrCreateLocalDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: localDeviceIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            return existing
        }
        #if canImport(UIKit)
        let generated = "ios-" + (UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? UUID().uuidString.lowercased())
        #else
        let generated = "ios-" + UUID().uuidString.lowercased()
        #endif
        UserDefaults.standard.set(generated, forKey: localDeviceIdKey)
        return generated
    }

    @MainActor
    public static func resolveOrPersistSharedPhysicalDeviceId(fallbackDeviceId: String) -> String {
        let shared = UserDefaults(suiteName: sharedSuiteName)
        if let fromShared = shared?.string(forKey: sharedPhysicalIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !fromShared.isEmpty {
            UserDefaults.standard.set(fromShared, forKey: sharedPhysicalIdKey)
            return fromShared
        }
        if let fromLocal = UserDefaults.standard.string(forKey: sharedPhysicalIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !fromLocal.isEmpty {
            shared?.set(fromLocal, forKey: sharedPhysicalIdKey)
            return fromLocal
        }
        shared?.set(fallbackDeviceId, forKey: sharedPhysicalIdKey)
        UserDefaults.standard.set(fallbackDeviceId, forKey: sharedPhysicalIdKey)
        return fallbackDeviceId
    }

    public static func rawHardwareModelCode() -> String {
        #if targetEnvironment(simulator)
        if let simCode = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !simCode.isEmpty {
            return simCode
        }
        #endif
        var sysinfo = utsname()
        uname(&sysinfo)
        let mirror = Mirror(reflecting: sysinfo.machine)
        let code = mirror.children.reduce(into: "") { acc, child in
            guard let byte = child.value as? Int8, byte != 0 else { return }
            acc.append(Character(UnicodeScalar(UInt8(byte))))
        }
        return code.isEmpty ? "iPhone" : code
    }

    public static func readableAppleModelName(for rawCode: String) -> String {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        switch code {
        // iPhone X / XS / XR
        case "iPhone10,1", "iPhone10,4": return "iPhone 8"
        case "iPhone10,2", "iPhone10,5": return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6": return "iPhone X"
        case "iPhone11,2": return "iPhone XS"
        case "iPhone11,4", "iPhone11,6": return "iPhone XS Max"
        case "iPhone11,8": return "iPhone XR"
        // iPhone 11 & SE 2
        case "iPhone12,1": return "iPhone 11"
        case "iPhone12,3": return "iPhone 11 Pro"
        case "iPhone12,5": return "iPhone 11 Pro Max"
        case "iPhone12,8": return "iPhone SE (2e gen.)"
        // iPhone 12
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        // iPhone 13 & SE 3
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,6": return "iPhone SE (3e gen.)"
        // iPhone 14
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        // iPhone 15
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        // iPhone 16
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,5": return "iPhone 16e"
        // iPhone 17
        case "iPhone18,3": return "iPhone 17"
        case "iPhone18,4": return "iPhone 17 Air"
        case "iPhone18,1": return "iPhone 17 Pro"
        case "iPhone18,2": return "iPhone 17 Pro Max"
        // iPad courants
        case "iPad13,1", "iPad13,2": return "iPad Air (4e gen.)"
        case "iPad13,16", "iPad13,17": return "iPad Air (M1)"
        case "iPad14,8", "iPad14,9": return "iPad Air 11\" (M2)"
        case "iPad14,10", "iPad14,11": return "iPad Air 13\" (M2)"
        case "iPad14,1", "iPad14,2": return "iPad mini (6e gen.)"
        case "iPad16,1", "iPad16,2": return "iPad mini (A17 Pro)"
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro 11\" (M1)"
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro 12.9\" (M1)"
        case "iPad14,3", "iPad14,4": return "iPad Pro 11\" (M2)"
        case "iPad14,5", "iPad14,6": return "iPad Pro 12.9\" (M2)"
        case "iPad16,3", "iPad16,4": return "iPad Pro 11\" (M4)"
        case "iPad16,5", "iPad16,6": return "iPad Pro 13\" (M4)"
        case "arm64", "x86_64": return "iPhone (Simulateur)"
        default:
            if code.hasPrefix("iPad") { return "iPad (\(code))" }
            if code.hasPrefix("iPhone") { return "iPhone (\(code))" }
            return code.isEmpty ? "iPhone" : code
        }
    }
}

public enum AcademyAPIError: LocalizedError, Sendable {
    case invalidResponse
    case unauthorized
    case sessionRevoked(String)
    case forbiddenCenelisPermission(AcademyLearnerProfile?)
    case serverMessage(String)
    case networkUnavailable

    public var isSessionTerminated: Bool {
        switch self {
        case .unauthorized, .sessionRevoked:
            return true
        default:
            return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Réponse serveur Cenelis Academy inattendue."
        case .unauthorized:
            return "Session expirée. Veuillez vous reconnecter avec votre compte Cenelis / Viple Live ID."
        case .sessionRevoked(let msg):
            return msg.isEmpty ? "Cet appareil a été déconnecté à distance." : msg
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

    // MARK: - En-têtes Matériels Partagés Écosystème & Appels Réseau Live Cenelis Academy

    private func makeRequest(url: URL, method: String = "GET", token: String? = nil) -> URLRequest {
        let hw = AcademyDeviceHardwareInfo.current()
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(hw.deviceId, forHTTPHeaderField: "X-Viple-Device-Id")
        req.setValue(hw.physicalDeviceId, forHTTPHeaderField: "X-Viple-Physical-Device-Id")
        req.setValue(hw.modelCode, forHTTPHeaderField: "X-Viple-Hardware-Model")
        req.setValue(Self.asciiSafeHeaderValue(hw.modelName), forHTTPHeaderField: "X-Viple-Model-Name")
        req.setValue(hw.osVersion, forHTTPHeaderField: "X-Viple-OS-Version")
        req.setValue(hw.appVersion, forHTTPHeaderField: "X-Viple-App-Version")
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private static func asciiSafeHeaderValue(_ raw: String) -> String {
        let ascii = raw.unicodeScalars.map { scalar -> Character in
            if scalar.value >= 32 && scalar.value < 127 {
                return Character(scalar)
            }
            return " "
        }
        return String(ascii).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func throwIfUnauthorizedOrRevoked(http: HTTPURLResponse, data: Data) throws {
        if let rev = try? JSONDecoder().decode(AcademySessionRevokedEnvelope.self, from: data),
           rev.sessionRevoked == true {
            throw AcademyAPIError.sessionRevoked(rev.error ?? "Cet appareil a été déconnecté à distance.")
        }
        if http.statusCode == 401 {
            throw AcademyAPIError.unauthorized
        }
    }

    public func fetchVersion() async -> String? {
        let url = baseURL.appendingPathComponent("api/mobile/v1/version")
        let req = makeRequest(url: url, method: "GET")
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

        let req = makeRequest(url: url, method: "GET", token: token)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AcademyAPIError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse else {
            throw AcademyAPIError.invalidResponse
        }
        try throwIfUnauthorizedOrRevoked(http: http, data: data)
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
        let req = makeRequest(url: url, method: "GET", token: token)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AcademyAPIError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse else {
            throw AcademyAPIError.invalidResponse
        }
        try throwIfUnauthorizedOrRevoked(http: http, data: data)
        guard (200..<300).contains(http.statusCode) else {
            throw AcademyAPIError.invalidResponse
        }
        return try JSONDecoder().decode(AcademyMeResponse.self, from: data)
    }

    public func fetchCGU(token: String?) async throws -> AcademyCGUResponse {
        let url = baseURL.appendingPathComponent("api/mobile/v1/cgu")
        let req = makeRequest(url: url, method: "GET", token: token)

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
        var req = makeRequest(url: url, method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        try throwIfUnauthorizedOrRevoked(http: http, data: data)
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

        let req = makeRequest(url: url, method: "GET", token: token)

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
        var req = makeRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
        var req = makeRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        try throwIfUnauthorizedOrRevoked(http: http, data: data)
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
        let req = makeRequest(url: url, method: "GET", token: token)

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
        var req = makeRequest(url: url, method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? JSONEncoder().encode(progress) else { return false }
        req.httpBody = body

        guard let (_, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse else {
            return false
        }
        return (200..<300).contains(http.statusCode)
    }

    // MARK: - Notifications Quotidiennes APNs (.p8), Nudge 1×/jour & Sessions d'Appareils Connectés

    @discardableResult
    public func registerPushDevice(
        deviceId: String,
        physicalDeviceId: String? = nil,
        apnsToken: String,
        apnsEnvironment: String,
        appleTeamId: String?,
        notificationsEnabled: Bool,
        preferredHourParis: Int,
        preferredMinuteParis: Int,
        isExplicitLogin: Bool = true,
        token: String
    ) async -> (ok: Bool, sessionRevoked: Bool) {
        guard !token.isEmpty else { return (false, false) }
        let hw = AcademyDeviceHardwareInfo.current()
        let url = baseURL.appendingPathComponent("api/mobile/v1/devices/register")
        var req = makeRequest(url: url, method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "deviceId": deviceId,
            "physicalDeviceId": physicalDeviceId ?? hw.physicalDeviceId,
            "apnsToken": apnsToken,
            "apnsEnvironment": apnsEnvironment,
            "notificationsEnabled": notificationsEnabled,
            "preferredHourParis": preferredHourParis,
            "preferredMinuteParis": preferredMinuteParis,
            "deviceModelCode": hw.modelCode,
            "deviceModelName": hw.modelName,
            "deviceCustomName": hw.deviceCustomName,
            "osVersion": hw.osVersion,
            "appVersion": hw.appVersion,
            "isExplicitLogin": isExplicitLogin
        ]
        if let appleTeamId, !appleTeamId.isEmpty {
            payload["appleTeamId"] = appleTeamId
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return (false, false) }
        req.httpBody = body

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse else {
            return (false, false)
        }
        if let rev = try? JSONDecoder().decode(AcademySessionRevokedEnvelope.self, from: data),
           rev.sessionRevoked == true {
            return (false, true)
        }
        if http.statusCode == 401 {
            return (false, true)
        }
        return ((200..<300).contains(http.statusCode), false)
    }

    @discardableResult
    public func unregisterPushDevice(
        deviceId: String,
        physicalDeviceId: String? = nil,
        apnsToken: String,
        token: String,
        email: String? = nil,
        cid: String? = nil
    ) async -> Bool {
        let hw = AcademyDeviceHardwareInfo.current()
        let effDev = deviceId.isEmpty ? hw.deviceId : deviceId
        let effPhys = (physicalDeviceId?.isEmpty == false) ? physicalDeviceId! : hw.physicalDeviceId
        guard !token.isEmpty || !effDev.isEmpty || !(email ?? "").isEmpty else { return false }

        let url = baseURL.appendingPathComponent("api/mobile/v1/devices/unregister")
        var req = makeRequest(url: url, method: "POST", token: token.isEmpty ? nil : token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: String] = [
            "deviceId": effDev,
            "physicalDeviceId": effPhys,
            "apnsToken": apnsToken
        ]
        if let email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["email"] = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        if let cid, !cid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["cid"] = cid.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        req.httpBody = body

        guard let (_, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse else {
            return false
        }
        return (200..<300).contains(http.statusCode)
    }

    public func fetchDailyNudge(token: String) async throws -> AcademyDailyNudgeResponse? {
        guard !token.isEmpty else { return nil }
        let url = baseURL.appendingPathComponent("api/mobile/v1/notifications/daily-nudge")
        let req = makeRequest(url: url, method: "GET", token: token)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AcademyAPIError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse else {
            throw AcademyAPIError.invalidResponse
        }
        try throwIfUnauthorizedOrRevoked(http: http, data: data)

        guard (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AcademyDailyNudgeResponse.self, from: data) else {
            return nil
        }
        if decoded.sessionRevoked == true {
            throw AcademyAPIError.sessionRevoked("Cet appareil a été déconnecté à distance.")
        }
        return decoded
    }

    // MARK: - Hub Central d'Appareils Connectés & Déconnexion à Distance

    public func fetchConnectedDevices(token: String) async throws -> AcademyConnectedDevicesResponse {
        guard !token.isEmpty else { throw AcademyAPIError.unauthorized }
        let hw = AcademyDeviceHardwareInfo.current()
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/mobile/v1/devices/sessions"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "currentDeviceId", value: hw.deviceId),
            URLQueryItem(name: "currentPhysicalDeviceId", value: hw.physicalDeviceId)
        ]
        guard let url = comps?.url else { throw AcademyAPIError.invalidResponse }

        let req = makeRequest(url: url, method: "GET", token: token)
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AcademyAPIError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse else {
            throw AcademyAPIError.invalidResponse
        }
        try throwIfUnauthorizedOrRevoked(http: http, data: data)
        guard (200..<300).contains(http.statusCode) else {
            throw AcademyAPIError.invalidResponse
        }

        return try JSONDecoder().decode(AcademyConnectedDevicesResponse.self, from: data)
    }

    public func revokeConnectedDevice(
        token: String,
        targetDeviceId: String,
        targetAppId: String?,
        rawDeviceIds: [String] = []
    ) async throws -> AcademyDeviceRevokeResponse {
        guard !token.isEmpty else { throw AcademyAPIError.unauthorized }
        let url = baseURL.appendingPathComponent("api/mobile/v1/devices/revoke")
        var req = makeRequest(url: url, method: "POST", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "targetDeviceId": targetDeviceId
        ]
        if let targetAppId, !targetAppId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["targetAppId"] = targetAppId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !rawDeviceIds.isEmpty {
            payload["rawDeviceIds"] = rawDeviceIds
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw AcademyAPIError.networkUnavailable
        }

        guard let http = resp as? HTTPURLResponse else {
            throw AcademyAPIError.invalidResponse
        }
        try throwIfUnauthorizedOrRevoked(http: http, data: data)

        let decoded = try JSONDecoder().decode(AcademyDeviceRevokeResponse.self, from: data)
        if !decoded.ok {
            throw AcademyAPIError.serverMessage(decoded.error ?? "Impossible de déconnecter cet appareil.")
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
