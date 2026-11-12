import Foundation
import Security

// MARK: - Keychain & Shared App Group Token Storage

public enum VemKeychainStore {
    private static let serviceName = "com.viplenetwork.vem4.auth"
    private static let tokenAccount = "vem4_bearer_token"
    private static let sharedGroups = ["group.com.viplenetwork.shared", "group.store.livria.shared"]

    public static func saveToken(_ token: String, email: String, displayName: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(insert as CFDictionary, nil)

        UserDefaults.standard.set(email, forKey: "vem4.last_email")
        UserDefaults.standard.set(displayName, forKey: "vem4.last_name")

        for grp in sharedGroups {
            if let suite = UserDefaults(suiteName: grp) {
                suite.set(email, forKey: "viple.shared.email")
                suite.set(displayName, forKey: "viple.shared.displayName")
            }
        }
    }

    public static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func clearToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    public static func discoverCrossAppEmailHint() -> (email: String, name: String)? {
        for grp in sharedGroups {
            if let suite = UserDefaults(suiteName: grp) {
                let em = suite.string(forKey: "viple.shared.email")
                    ?? suite.string(forKey: "vipleLiveEmail")
                    ?? suite.string(forKey: "userEmail")
                if let em, !em.isEmpty {
                    let nm = suite.string(forKey: "viple.shared.displayName")
                        ?? suite.string(forKey: "displayName")
                        ?? em
                    return (em, nm)
                }
            }
        }
        if let last = UserDefaults.standard.string(forKey: "vem4.last_email"), !last.isEmpty {
            let nm = UserDefaults.standard.string(forKey: "vem4.last_name") ?? last
            return (last, nm)
        }
        return nil
    }
}

// MARK: - Viple & Moi API Error

public enum VemAPIError: LocalizedError, Sendable {
    case unauthorized
    case lockedByFamilyOwner(String)
    case serverMessage(String)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Votre session Viple Live a expiré. Veuillez vous reconnecter."
        case .lockedByFamilyOwner(let msg):
            return msg
        case .serverMessage(let msg):
            return msg
        case .network(let msg):
            return msg
        }
    }
}

// MARK: - Actor Network Client for Espace Client v4 + Cenelis Academy Guide

public actor VemAPIClient {
    public static let shared = VemAPIClient()

    public let baseURL = URL(string: "https://espace-client-v4.viplenetwork.com")!
    public let academyBaseURL = URL(string: "https://academy.prod.cenelis.com")!

    private let session: URLSession
    private let cacheFileURL: URL

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 35
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)

        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheFileURL = dir.appendingPathComponent("vem4_workspace_cache_v1.json")
    }

    public func ssoStartURL() -> URL {
        baseURL.appendingPathComponent("api/mobile/v1/auth/sso-start")
    }

    public func currentAvatarURL(token: String?) -> URL {
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/client/account/current-avatar"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "t", value: "\(Int(Date().timeIntervalSince1970))")]
        if let token, !token.isEmpty {
            items.append(URLQueryItem(name: "vem_token", value: token))
        }
        comps.queryItems = items
        return comps.url ?? baseURL
    }

    public func printableInvoiceURL(invoiceId: Int, token: String?) -> URL {
        var comps = URLComponents(url: baseURL.appendingPathComponent("factures/\(invoiceId)"), resolvingAgainstBaseURL: false)!
        if let token, !token.isEmpty {
            comps.queryItems = [URLQueryItem(name: "vem_token", value: token)]
        }
        return comps.url ?? baseURL
    }

    // MARK: Auth & Bootstrap

    public func login(email: String, password: String) async throws -> VemMobileLoginResponse {
        let body: [String: Any] = ["email": email, "password": password]
        let (data, http) = try await sendJSON(path: "/api/mobile/v1/auth/login", method: "POST", body: body, token: nil)
        let decoded = try JSONDecoder().decode(VemMobileLoginResponse.self, from: data)
        if http.statusCode >= 400 || !decoded.ok {
            throw VemAPIError.serverMessage(decoded.error ?? "Identifiants Viple Live incorrects.")
        }
        if let ws = decoded.workspace {
            saveCachedBootstrap(VemBootstrapResponse(workspace: ws, account: decoded.account))
        }
        return decoded
    }

    public func fetchBootstrap(token: String) async throws -> VemBootstrapResponse {
        let (data, http) = try await sendRequest(path: "/api/client/bootstrap", method: "GET", bodyData: nil, token: token)
        if http.statusCode == 401 {
            throw VemAPIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw VemAPIError.serverMessage("Impossible d'actualiser votre Espace Client (HTTP \(http.statusCode)).")
        }
        let decoded = try JSONDecoder().decode(VemBootstrapResponse.self, from: data)
        saveCachedBootstrap(decoded)
        return decoded
    }

    public func loadCachedBootstrap() -> VemBootstrapResponse? {
        guard let data = try? Data(contentsOf: cacheFileURL) else { return nil }
        return try? JSONDecoder().decode(VemBootstrapResponse.self, from: data)
    }

    private func saveCachedBootstrap(_ payload: VemBootstrapResponse) {
        if let encoded = try? JSONEncoder().encode(payload) {
            try? encoded.write(to: cacheFileURL, options: .atomic)
        }
    }

    // MARK: Livria Store & Viple Delivery Orders

    public func fetchOrdersAndDelivery(token: String) async throws -> VemOrdersDeliveryPayload {
        let (data, http) = try await sendRequest(path: "/api/client/orders-delivery", method: "GET", bodyData: nil, token: token)
        if http.statusCode == 401 { throw VemAPIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw VemAPIError.serverMessage("Synchronisation des commandes Livria momentanément indisponible.")
        }
        return try JSONDecoder().decode(VemOrdersDeliveryPayload.self, from: data)
    }

    // MARK: Services & Options Management

    public func orderNewService(token: String, productCode: String, assignedMemberId: Int?, customNickname: String?) async throws -> String {
        var body: [String: Any] = ["productCode": productCode]
        if let assignedMemberId { body["assignedMemberId"] = assignedMemberId }
        if let nick = customNickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty {
            body["customNickname"] = nick
        }
        let resp = try await postGeneric(path: "/api/client/services/order", body: body, token: token)
        return resp.message ?? "Votre nouveau service Viple est activé !"
    }

    public func executeServiceAction(
        token: String,
        subscriptionId: Int,
        action: String,
        customNickname: String? = nil,
        assignedMemberId: Int? = nil
    ) async throws -> String {
        var body: [String: Any] = ["action": action]
        if let customNickname { body["customNickname"] = customNickname }
        if let assignedMemberId { body["assignedMemberId"] = assignedMemberId }
        let resp = try await postGeneric(path: "/api/client/services/\(subscriptionId)/action", body: body, token: token)
        return resp.message ?? "Opération effectuée."
    }

    public func purchaseOption(token: String, subscriptionId: Int, optionCode: String) async throws -> String {
        let body: [String: Any] = ["optionCode": optionCode]
        let resp = try await postGeneric(path: "/api/client/services/\(subscriptionId)/options", body: body, token: token)
        return resp.message ?? "Option activée immédiatement !"
    }

    public func cancelOption(token: String, optionRowId: Int) async throws -> String {
        let resp = try await postGeneric(path: "/api/client/options/\(optionRowId)/cancel", body: [:], token: token)
        return resp.message ?? "Option résiliée."
    }

    public func requestOptionFromOwner(token: String, subscriptionId: Int, optionCode: String, message: String) async throws -> String {
        let body: [String: Any] = ["optionCode": optionCode, "message": message]
        let resp = try await postGeneric(path: "/api/client/services/\(subscriptionId)/request-option", body: body, token: token)
        return resp.message ?? "Demande envoyée au titulaire du foyer !"
    }

    public func resolveOptionRequest(token: String, requestId: Int, approve: Bool) async throws -> String {
        let body: [String: Any] = ["approve": approve]
        let resp = try await postGeneric(path: "/api/client/option-requests/\(requestId)/resolve", body: body, token: token)
        return resp.message ?? (approve ? "Option approuvée et activée !" : "Demande refusée.")
    }

    // MARK: Family Household CRUD

    public func upsertFamilyMember(token: String, member: VemFamilyMember) async throws -> String {
        var body: [String: Any] = [
            "firstName": member.firstName,
            "relationship": member.relationship,
            "avatarColor": member.avatarColor,
            "canAccessServices": member.canAccessServices,
            "canPurchaseOptions": member.canPurchaseOptions,
            "canCancelServices": member.canCancelServices
        ]
        if member.id > 0 { body["id"] = member.id }
        if let email = member.linkedVipleEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            body["linkedVipleEmail"] = email
        }
        let resp = try await postGeneric(path: "/api/client/family/upsert", body: body, token: token)
        return resp.message ?? "Profil familial mis à jour."
    }

    public func deleteFamilyMember(token: String, memberId: Int) async throws -> String {
        let resp = try await postGeneric(path: "/api/client/family/\(memberId)/delete", body: [:], token: token)
        return resp.message ?? "Profil retiré du foyer."
    }

    // MARK: Viple Mail (@viplemail.fr) Aliases

    public func updateMailAlias(token: String, action: String, alias: String, previousAlias: String? = nil) async throws -> (String, VemMailStatus?) {
        var body: [String: Any] = ["action": action, "alias": alias]
        if let previousAlias, !previousAlias.isEmpty {
            body["previousAlias"] = previousAlias
        }
        let resp = try await postGeneric(path: "/api/client/viplemail/alias", body: body, token: token)
        return (resp.message ?? "Alias @viplemail.fr mis à jour !", resp.vipleMail)
    }

    // MARK: Billing SEPA (5/10/15), PayPal & Certified 2D-DOC Invoices

    public func saveSepaMandate(
        token: String,
        accountHolder: String,
        iban: String,
        bic: String,
        debitDay: Int,
        address: String,
        postalCode: String,
        city: String
    ) async throws -> String {
        let body: [String: Any] = [
            "accountHolder": accountHolder,
            "iban": iban,
            "bic": bic,
            "debitDay": debitDay,
            "billingAddress": address,
            "billingPostalCode": postalCode,
            "billingCity": city
        ]
        let resp = try await postGeneric(path: "/api/client/billing/sepa", body: body, token: token)
        return resp.message ?? "Mandat SEPA enregistré."
    }

    public func createPayPalMobileOrder(token: String) async throws -> (orderId: String, approveUrl: URL, amountEur: Double) {
        let resp = try await postGeneric(path: "/api/client/billing/paypal/create-order?mobile=1", body: [:], token: token)
        guard let urlStr = resp.approveUrl, let url = URL(string: urlStr) else {
            throw VemAPIError.serverMessage(resp.error ?? "Impossible d'initialiser la session PayPal.")
        }
        return (resp.orderId ?? "", url, resp.amountEur ?? 1.0)
    }

    public func fetchInvoiceDetail(token: String, invoiceId: Int) async throws -> VemInvoiceDetailResponse {
        let (data, http) = try await sendRequest(path: "/api/client/invoices/\(invoiceId)/detail", method: "GET", bodyData: nil, token: token)
        if http.statusCode == 401 { throw VemAPIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw VemAPIError.serverMessage("Impossible de charger le détail certifié 2D-DOC de cette facture.")
        }
        return try JSONDecoder().decode(VemInvoiceDetailResponse.self, from: data)
    }

    // MARK: Unified Viple Live Account Profile, Avatar & Password

    public func updateAccountProfile(
        token: String,
        displayName: String,
        firstName: String,
        lastName: String,
        personalMessage: String,
        colorScheme: String,
        phoneNumber: String,
        bio: String,
        city: String,
        securityAlerts: Bool,
        newsletter: Bool
    ) async throws -> String {
        let body: [String: Any] = [
            "displayName": displayName,
            "firstName": firstName,
            "lastName": lastName,
            "personalMessage": personalMessage,
            "colorScheme": colorScheme,
            "phoneNumber": phoneNumber,
            "bio": bio,
            "city": city,
            "securityAlerts": securityAlerts,
            "newsletter": newsletter
        ]
        let resp = try await postGeneric(path: "/api/client/account/profile", body: body, token: token)
        return resp.message ?? "Profil Viple Live mis à jour !"
    }

    public func updateAvatar(token: String, croppedBase64Png: String?, presetFile: String?) async throws -> (String, String?) {
        var body: [String: Any] = [:]
        if let croppedBase64Png { body["croppedAvatarBase64"] = croppedBase64Png }
        if let presetFile { body["presetAvatar"] = presetFile }
        let resp = try await postGeneric(path: "/api/client/account/avatar", body: body, token: token)
        return (resp.message ?? "Photo de profil enregistrée !", resp.userTileUrl)
    }

    public func updatePassword(token: String, currentPassword: String, newPassword: String, confirmPassword: String) async throws -> String {
        let body: [String: Any] = [
            "currentPassword": currentPassword,
            "newPassword": newPassword,
            "confirmPassword": confirmPassword
        ]
        let resp = try await postGeneric(path: "/api/client/account/password", body: body, token: token)
        return resp.message ?? "Mot de passe unifié mis à jour."
    }

    // MARK: Embedded Cenelis Academy Course (guide-espace-client-v4)

    public func fetchEmbeddedCustomerGuide() async throws -> (course: VemGuideCourse, bubbles: [String: VemGuideBubble]) {
        var comps = URLComponents(url: academyBaseURL.appendingPathComponent("api/mobile/v1/bootstrap"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "includeHidden", value: "1")]
        guard let url = comps.url else {
            throw VemAPIError.network("URL Cenelis Academy invalide.")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("VipleEtMoi-iOS/2026.11", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw VemAPIError.network("Impossible de récupérer le guide interactif Cenelis Academy.")
        }
        let decoded = try JSONDecoder().decode(VemAcademyBootstrap.self, from: data)
        if let guide = decoded.courses.first(where: { $0.id == "guide-espace-client-v4" || $0.isCustomerGuide })
            ?? decoded.courses.last {
            return (guide, decoded.bubbles)
        }
        throw VemAPIError.serverMessage("Guide Espace Client introuvable.")
    }

    // MARK: Low-Level Helpers

    private func postGeneric(path: String, body: [String: Any], token: String?) async throws -> VemGenericActionResponse {
        let (data, http) = try await sendJSON(path: path, method: "POST", body: body, token: token)
        if http.statusCode == 401 {
            throw VemAPIError.unauthorized
        }
        let decoded = (try? JSONDecoder().decode(VemGenericActionResponse.self, from: data))
            ?? VemGenericActionResponse(ok: (200..<300).contains(http.statusCode))

        if http.statusCode == 403 && decoded.lockedByFamilyOwner == true {
            throw VemAPIError.lockedByFamilyOwner(decoded.error ?? "Achat autonome d'options bloqué par le titulaire du foyer.")
        }
        if !(200..<300).contains(http.statusCode) || decoded.ok == false {
            throw VemAPIError.serverMessage(decoded.error ?? "L'opération n'a pas pu aboutir.")
        }
        return decoded
    }

    private func sendJSON(path: String, method: String, body: [String: Any], token: String?) async throws -> (Data, HTTPURLResponse) {
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        return try await sendRequest(path: path, method: method, bodyData: data, token: token)
    }

    private func sendRequest(path: String, method: String, bodyData: Data?, token: String?) async throws -> (Data, HTTPURLResponse) {
        let fullURL: URL
        if path.hasPrefix("http") {
            fullURL = URL(string: path) ?? baseURL
        } else {
            let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
            fullURL = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL ?? baseURL
        }

        var req = URLRequest(url: fullURL)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("VipleEtMoi-iOS/2026.11", forHTTPHeaderField: "User-Agent")
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let bodyData {
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            req.httpBody = bodyData
        }

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw VemAPIError.network("Réponse réseau invalide.")
            }
            return (data, http)
        } catch let err as VemAPIError {
            throw err
        } catch {
            throw VemAPIError.network("Connexion impossible à l'Espace Client Viple (\(error.localizedDescription)).")
        }
    }
}
