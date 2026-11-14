import Foundation

// MARK: - Enveloppes Réseau Cenelis Connect, VipleAPI & Cenelis Academy

public struct WorkspacePinStateDTO: Codable, Sendable {
    public let isAdmin: Bool?
    public let status: String?
    public let isSuperAdmin: Bool?
    public let groups: [String]?
    public let hasPin: Bool?
    public let pinLength: Int?
    public let lockedUntilUtc: String?
}

public struct WorkspaceSessionEnvelope: Codable, Sendable {
    public let ok: Bool
    public let authenticated: Bool?
    public let error: String?
    public let workspaceToken: String?
    public let email: String?
    public let displayName: String?
    public let cid: String?
    public let ssoBridgeUrl: String?
    public let pinState: WorkspacePinStateDTO?
}

public struct WorkspacePinVerifyEnvelope: Codable, Sendable {
    public let ok: Bool
    public let expired: Bool?
    public let needsSetup: Bool?
    public let locked: Bool?
    public let mismatch: Bool?
    public let error: String?
    public let pinLength: Int?
    public let expiresAtUtc: String?
    public let pinProofToken: String?
    public let ssoBridgeUrl: String?
}

public struct WorkspacePinKeepaliveEnvelope: Codable, Sendable {
    public let ok: Bool
    public let expired: Bool?
    public let pinLocked: Bool?
    public let expiresAtUtc: String?
}

public struct AdminDirectoryServiceDTO: Codable, Sendable {
    public let id: String
    public let name: String?
    public let shortName: String?
    public let domainLabel: String?
    public let shortHost: String?
    public let adminUrl: String?
    public let url: String?
    public let publicUrl: String?
    public let category: String?
    public let description: String?
    public let accentColor: String?
    public let iconKey: String?
}

public struct AdminDirectoryEnvelope: Codable, Sendable {
    public let version: String?
    public let total: Int?
    public let services: [AdminDirectoryServiceDTO]
}

public struct EffectiveRbacEnvelope: Codable, Sendable {
    public let ok: Bool?
    public let registered: Bool?
    public let status: String?
    public let isSuperAdmin: Bool?
    public let groups: [String]?
    public let permissions: [String]?
    public let deniedPermissions: [String]?
    public let pinHasConfigured: Bool?
    public let pinLength: Int?
}

public struct AcademyPinBypassEnvelope: Codable, Sendable {
    public let ok: Bool
    public let pinBypassToken: String?
    public let expiresAtUtc: String?
    public let error: String?
}

public enum WorkspaceAPIError: LocalizedError, Sendable {
    case invalidCredentials(String)
    case unauthorized
    case serverError(String)
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials(let msg): return msg
        case .unauthorized: return "Votre session a expiré. Veuillez vous reconnecter."
        case .serverError(let msg): return msg
        case .networkUnavailable: return "Connexion réseau indisponible. Vérifiez votre accès Internet."
        }
    }
}

// MARK: - Client Réseau Centralisé Cenelis Workspace

@MainActor
public final class WorkspaceAPIClient {
    public static let shared = WorkspaceAPIClient()

    public let ssoBaseURL = URL(string: "https://sso.prod.cenelis.com")!
    public let vipleAPIBaseURL = URL(string: "https://api.viple.digital")!
    public let academyBaseURL = URL(string: "https://academy.prod.cenelis.com")!
    public let identityBaseURL = URL(string: "https://identity-v2.viple.digital")!

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 16
        config.timeoutIntervalForResource = 35
        config.httpAdditionalHeaders = [
            "User-Agent": WorkspaceWebSessionPool.fullURLSessionUserAgent,
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - 1. Authentification Viple Live ID / Cenelis Connect

    public func login(identifier: String, password: String) async throws -> WorkspaceSessionEnvelope {
        let url = ssoBaseURL.appendingPathComponent("api/workspace/auth/login")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "identifier": identifier.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password,
            "remember": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await perform(req)
        let env = try JSONDecoder().decode(WorkspaceSessionEnvelope.self, from: data)
        if !env.ok || env.authenticated == false {
            throw WorkspaceAPIError.invalidCredentials(env.error ?? "Identifiants Viple Live ID incorrects.")
        }
        return env
    }

    public func fetchSession(token: String?, extraCookieHeader: String? = nil) async throws -> WorkspaceSessionEnvelope {
        let url = ssoBaseURL.appendingPathComponent("api/workspace/session")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let extraCookieHeader, !extraCookieHeader.isEmpty {
            req.setValue(extraCookieHeader, forHTTPHeaderField: "Cookie")
        }

        let (data, resp) = try await perform(req)
        if resp.statusCode == 401 {
            throw WorkspaceAPIError.unauthorized
        }
        return try JSONDecoder().decode(WorkspaceSessionEnvelope.self, from: data)
    }

    // MARK: - 2. Vérification, Création, Keepalive & Révocation du Code PIN Cenelis Connect

    public func verifyPin(pin: String, token: String) async throws -> WorkspacePinVerifyEnvelope {
        let url = ssoBaseURL.appendingPathComponent("api/workspace/pin/verify")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["pin": pin])

        let (data, resp) = try await perform(req)
        if resp.statusCode == 401 {
            throw WorkspaceAPIError.unauthorized
        }
        return try JSONDecoder().decode(WorkspacePinVerifyEnvelope.self, from: data)
    }

    public func setupPin(pin: String, confirmPin: String, token: String) async throws -> WorkspacePinVerifyEnvelope {
        let url = ssoBaseURL.appendingPathComponent("api/workspace/pin/setup")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "pin": pin,
            "confirmPin": confirmPin
        ])

        let (data, resp) = try await perform(req)
        if resp.statusCode == 401 {
            throw WorkspaceAPIError.unauthorized
        }
        return try JSONDecoder().decode(WorkspacePinVerifyEnvelope.self, from: data)
    }

    public func keepalivePinSession(token: String, pinProof: String) async -> Bool {
        guard !token.isEmpty, !pinProof.isEmpty else { return false }
        let url = ssoBaseURL.appendingPathComponent("api/workspace/pin/keepalive")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(pinProof, forHTTPHeaderField: "X-Pin-Proof")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["pinProofToken": pinProof])

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let env = try? JSONDecoder().decode(WorkspacePinKeepaliveEnvelope.self, from: data) else {
            return false
        }
        return env.ok
    }

    public func lockPinSession(token: String) async {
        guard !token.isEmpty else { return }
        let url = ssoBaseURL.appendingPathComponent("api/workspace/pin/lock")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: req)
    }

    public func revokeGlobalWebSSOSessions() async {
        let urls = [
            ssoBaseURL.appendingPathComponent("logout.srf"),
            identityBaseURL.appendingPathComponent("logout.srf")
        ]
        for u in urls {
            var req = URLRequest(url: u)
            req.httpMethod = "GET"
            req.cachePolicy = .reloadIgnoringLocalCacheData
            _ = try? await session.data(for: req)
        }
    }

    // MARK: - 3. Annuaire des Panels `/admin`, Droits RBAC Effectifs & Sondes de Statut

    public func fetchAdminDirectory() async -> [AdminPanelItem]? {
        let url = vipleAPIBaseURL.appendingPathComponent("api/public/admin-directory")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AdminDirectoryEnvelope.self, from: data),
              !decoded.services.isEmpty else {
            return nil
        }

        let fallbackMap = Dictionary(uniqueKeysWithValues: EcosystemCatalogRegistry.fallbackPanels.map { ($0.id, $0) })

        return decoded.services.map { dto in
            let fb = fallbackMap[dto.id]
            let rawAdmin = dto.adminUrl ?? dto.url ?? fb?.adminURLString ?? "https://sso.prod.cenelis.com/"
            let normalizedAdmin = AdminPanelItem.normalizeEcosystemURL(rawAdmin)
            let dom = dto.domainLabel ?? dto.shortHost ?? fb?.domainLabel ?? ""
            let normalizedDomain = dom == "master-sysgrc.console.prod.cenelis.com"
                ? "control.ext-sysprod.cenelis.com"
                : dom

            return AdminPanelItem(
                id: dto.id,
                name: dto.shortName ?? fb?.name ?? dto.name ?? dto.id,
                fullTitle: dto.name ?? fb?.fullTitle ?? dto.id,
                domainLabel: normalizedDomain,
                adminURLString: normalizedAdmin,
                category: dto.category ?? fb?.category ?? "Gouvernance, RH & Juridique",
                description: dto.description ?? fb?.description ?? "",
                accentHex: dto.accentColor ?? fb?.accentHex ?? "#1B362D",
                iconKey: dto.iconKey ?? fb?.iconKey ?? "shield",
                healthProbeURLString: fb?.healthProbeURLString ?? normalizedAdmin
            )
        }
    }

    public func fetchEffectiveRbac(email: String) async -> WorkspaceRbacSnapshot? {
        let norm = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !norm.isEmpty else { return nil }

        var comps = URLComponents(url: vipleAPIBaseURL.appendingPathComponent("api/public/rbac/effective"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "email", value: norm)]
        guard let url = comps?.url else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let env = try? JSONDecoder().decode(EffectiveRbacEnvelope.self, from: data) else {
            return nil
        }

        return WorkspaceRbacSnapshot(
            registered: env.registered ?? false,
            status: env.status ?? "unregistered",
            isSuperAdmin: env.isSuperAdmin ?? false,
            groups: env.groups ?? [],
            permissions: Set(env.permissions ?? []),
            deniedPermissions: Set(env.deniedPermissions ?? [])
        )
    }

    public func probePanelHealth(panel: AdminPanelItem) async -> AdminPanelHealthStatus {
        guard let url = panel.healthProbeURL else { return .unknown }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 6.5
        req.cachePolicy = .reloadIgnoringLocalCacheData

        let start = ContinuousClock.now
        do {
            let (_, resp) = try await session.data(for: req)
            let elapsed = ContinuousClock.now - start
            let ms = max(1, Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000))
            if let http = resp as? HTTPURLResponse {
                if (200..<405).contains(http.statusCode) {
                    return .operational(latencyMs: ms)
                }
                return .degraded(code: http.statusCode)
            }
            return .operational(latencyMs: ms)
        } catch {
            return .unreachable
        }
    }

    // MARK: - 4. Recherche Live Cenelis Academy & Jeton Signé à Usage Unique (Bypass PIN)

    public func searchCenelisAcademy(query: String, token: String) async -> [AcademyHelpSearchResult] {
        guard !token.isEmpty else { return [] }
        var comps = URLComponents(url: academyBaseURL.appendingPathComponent("api/mobile/v1/search"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "45")
        ]
        guard let url = comps?.url else { return [] }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AcademyHelpSearchEnvelope.self, from: data) else {
            return []
        }
        return decoded.results
    }

    public func issueAcademyPinBypassToken(token: String, pinProof: String) async -> String? {
        guard !token.isEmpty, !pinProof.isEmpty else { return nil }
        let url = academyBaseURL.appendingPathComponent("api/mobile/v1/auth/issue-pin-bypass")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(pinProof, forHTTPHeaderField: "X-Pin-Proof")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["pinProofToken": pinProof])

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AcademyPinBypassEnvelope.self, from: data),
              decoded.ok,
              let bypass = decoded.pinBypassToken,
              !bypass.isEmpty else {
            return nil
        }
        return bypass
    }

    // MARK: - Helper Réseau

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: request)
        } catch {
            throw WorkspaceAPIError.networkUnavailable
        }
        guard let http = resp as? HTTPURLResponse else {
            throw WorkspaceAPIError.serverError("Réponse serveur invalide.")
        }
        return (data, http)
    }
}
