import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Client Réseau REST Natif « Livria Store » (App Store ID : 6825159743 • iOS 18+ / iOS 26+)

@MainActor
public final class LivriaAPIClient {
    public static let shared = LivriaAPIClient()

    public let baseAPI = "https://livria.store/api/mobile/v1"
    public let socialBaseAPI = "https://livriasocial.viplenetwork.com/api/mobile/v1"
    private let session: URLSession
    private let decoder: JSONDecoder

    public static let serverLunchBreakMessage = "Notre serveur est a sa pause dejeuner, Merci de revenir une fois le serveur rétabli."

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 20
        self.session = URLSession(configuration: cfg)
        self.decoder = JSONDecoder()
    }

    private func applyVipleDeviceHeaders(to req: inout URLRequest) {
        req.setValue("Livria Store", forHTTPHeaderField: "X-Viple-App-Name")
        #if canImport(UIKit)
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString, !vendorId.isEmpty {
            req.setValue(vendorId, forHTTPHeaderField: "X-Viple-Vendor-Id")
        }
        let dev = UIDevice.current
        let bounds = UIScreen.main.bounds
        let deviceSignature = "\(dev.model)|\(dev.systemName)-\(dev.systemVersion)|\(Int(bounds.width))x\(Int(bounds.height))"
        req.setValue(deviceSignature, forHTTPHeaderField: "X-Viple-Device-Info")
        #endif
    }

    private func performRequest(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "LivriaServerOutage",
                    code: 503,
                    userInfo: [NSLocalizedDescriptionKey: Self.serverLunchBreakMessage]
                )
            }
            if http.statusCode >= 500 {
                throw NSError(
                    domain: "LivriaServerOutage",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: Self.serverLunchBreakMessage]
                )
            }
            return (data, http)
        } catch let nsErr as NSError where nsErr.domain == "LivriaServerOutage" {
            throw nsErr
        } catch {
            throw NSError(
                domain: "LivriaServerOutage",
                code: 503,
                userInfo: [NSLocalizedDescriptionKey: Self.serverLunchBreakMessage]
            )
        }
    }

    public func getJSON<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(string: path.hasPrefix("http") ? path : "\(baseAPI)\(path)")!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("LivriaStore-iOS/26.0 (AppID/\(LivriaAppConfig.appleAppId); iPhone; iOS 18.0+)", forHTTPHeaderField: "User-Agent")
        applyVipleDeviceHeaders(to: &req)

        let (data, http) = try await performRequest(req)
        if !(200...299).contains(http.statusCode) {
            if let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = errDict["error"] as? String {
                throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: Self.serverLunchBreakMessage])
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NSError(domain: "LivriaServerOutage", code: 503, userInfo: [NSLocalizedDescriptionKey: Self.serverLunchBreakMessage])
        }
    }

    public func postJSON<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: path.hasPrefix("http") ? path : "\(baseAPI)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("LivriaStore-iOS/26.0 (AppID/\(LivriaAppConfig.appleAppId); iPhone; iOS 18.0+)", forHTTPHeaderField: "User-Agent")
        applyVipleDeviceHeaders(to: &req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, http) = try await performRequest(req)
        if !(200...299).contains(http.statusCode) {
            if let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = errDict["error"] as? String {
                throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: Self.serverLunchBreakMessage])
        }
        return try decoder.decode(T.self, from: data)
    }

    public func postRaw(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: path.hasPrefix("http") ? path : "\(baseAPI)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("LivriaStore-iOS/26.0 (AppID/\(LivriaAppConfig.appleAppId); iPhone; iOS 18.0+)", forHTTPHeaderField: "User-Agent")
        applyVipleDeviceHeaders(to: &req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, http) = try await performRequest(req)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if !(200...299).contains(http.statusCode) {
            let msg = (dict["error"] as? String) ?? Self.serverLunchBreakMessage
            throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return dict
    }

    // MARK: - Viple Live ID Cross-App SSO (Livria Store <-> Livria Social)

    public func discoverCrossAppAccount() async -> LivriaCrossAppAccount? {
        let items = [URLQueryItem(name: "currentApp", value: "Livria Store")]
        if let res: LivriaCrossAppDiscoverResponse = try? await getJSON("/sso/discover", queryItems: items),
           res.hasDetectedAccount, let account = res.account {
            return account
        }
        if let resSocial: LivriaCrossAppDiscoverResponse = try? await getJSON("\(socialBaseAPI)/sso/discover", queryItems: items),
           resSocial.hasDetectedAccount, let account = resSocial.account {
            return account
        }
        return nil
    }

    public func announceCrossAppSession(userId: Int, email: String) async {
        let payload: [String: Any] = [
            "sourceApp": "Livria Store",
            "appName": "Livria Store",
            "userId": userId,
            "email": email
        ]
        _ = try? await postRaw("/sso/announce", body: payload)
        _ = try? await postRaw("\(socialBaseAPI)/sso/announce", body: payload)
    }

    public func clearCrossAppSession() async {
        let payload: [String: Any] = [
            "sourceApp": "Livria Store",
            "appName": "Livria Store"
        ]
        _ = try? await postRaw("/sso/clear", body: payload)
        _ = try? await postRaw("\(socialBaseAPI)/sso/clear", body: payload)
    }

    public func acceptCrossAppAccount(
        userId: Int,
        email: String,
        guestUserId: Int? = nil,
        guestEmail: String? = nil
    ) async throws -> LivriaAuthResponse {
        var payload: [String: Any] = [
            "userId": userId,
            "email": email
        ]
        if let guestUserId, guestUserId > 0 { payload["guestUserId"] = guestUserId }
        if let guestEmail, !guestEmail.isEmpty { payload["guestEmail"] = guestEmail }
        return try await postJSON("/sso/accept", body: payload)
    }

    // MARK: - Authentification Native Viple Live ID

    public func loginVipleLiveID(
        email: String,
        password: String,
        guestUserId: Int? = nil,
        guestEmail: String? = nil
    ) async throws -> LivriaAuthResponse {
        var payload: [String: Any] = [
            "email": email,
            "password": password
        ]
        if let guestUserId, guestUserId > 0 { payload["guestUserId"] = guestUserId }
        if let guestEmail, !guestEmail.isEmpty { payload["guestEmail"] = guestEmail }
        return try await postJSON("/auth/login", body: payload)
    }

    /// Inscription Viple Live ID : `emailMode` = `"viplemail"` (`@viplemail.fr`) ou `"custom"` (email externe)
    public func registerVipleLiveID(
        emailMode: String,
        emailUser: String,
        customEmail: String,
        password: String,
        firstName: String,
        lastName: String,
        displayName: String,
        guestUserId: Int? = nil,
        guestEmail: String? = nil
    ) async throws -> LivriaAuthResponse {
        var payload: [String: Any] = [
            "emailMode": emailMode,
            "emailUser": emailUser,
            "emailDomain": "viplemail.fr",
            "customEmail": customEmail,
            "email": emailMode == "viplemail" ? "\(emailUser)@viplemail.fr" : customEmail,
            "password": password,
            "firstName": firstName,
            "lastName": lastName,
            "displayName": displayName
        ]
        if let guestUserId, guestUserId > 0 { payload["guestUserId"] = guestUserId }
        if let guestEmail, !guestEmail.isEmpty { payload["guestEmail"] = guestEmail }
        return try await postJSON("/auth/register", body: payload)
    }

    /// Sign in with Apple — Étape 1 (Connexion directe ou demande d'onboarding @viplemail.fr)
    public func signInWithApple(
        appleUserId: String,
        identityToken: String?,
        email: String?,
        firstName: String?,
        lastName: String?,
        guestUserId: Int? = nil,
        guestEmail: String? = nil
    ) async throws -> LivriaAuthResponse {
        var payload: [String: Any] = ["appleUserId": appleUserId]
        if let identityToken { payload["identityToken"] = identityToken }
        if let email { payload["email"] = email }
        if let firstName { payload["firstName"] = firstName }
        if let lastName { payload["lastName"] = lastName }
        if let guestUserId, guestUserId > 0 { payload["guestUserId"] = guestUserId }
        if let guestEmail, !guestEmail.isEmpty { payload["guestEmail"] = guestEmail }
        return try await postJSON("/auth/apple", body: payload)
    }

    /// Sign in with Apple — Étape 2 (Inscription uniquement : Nom, Prénom, Pseudo & @viplemail.fr obligatoire)
    public func completeAppleSignup(
        appleUserId: String,
        appleEmail: String?,
        firstName: String,
        lastName: String,
        displayName: String,
        vipleMailUser: String,
        guestUserId: Int? = nil,
        guestEmail: String? = nil
    ) async throws -> LivriaAuthResponse {
        var payload: [String: Any] = [
            "appleUserId": appleUserId,
            "appleEmail": appleEmail ?? "",
            "firstName": firstName,
            "lastName": lastName,
            "displayName": displayName,
            "vipleMailUser": vipleMailUser
        ]
        if let guestUserId, guestUserId > 0 { payload["guestUserId"] = guestUserId }
        if let guestEmail, !guestEmail.isEmpty { payload["guestEmail"] = guestEmail }
        return try await postJSON("/auth/apple-complete", body: payload)
    }

    /// Sign in with Apple — Étape 2 bis (« J'ai déjà un compte Viple Live ID ») : Associer un compte Viple existant au compte Apple
    public func linkAppleToExistingAccount(
        appleUserId: String,
        appleEmail: String?,
        email: String,
        password: String,
        guestUserId: Int? = nil,
        guestEmail: String? = nil
    ) async throws -> LivriaAuthResponse {
        var payload: [String: Any] = [
            "appleUserId": appleUserId,
            "appleEmail": appleEmail ?? "",
            "email": email,
            "password": password
        ]
        if let guestUserId, guestUserId > 0 { payload["guestUserId"] = guestUserId }
        if let guestEmail, !guestEmail.isEmpty { payload["guestEmail"] = guestEmail }
        return try await postJSON("/auth/apple-link-existing", body: payload)
    }

    /// Suppression définitive du compte Viple Live ID
    public func deleteVipleAccount(userId: Int?, email: String?, cid: String?) async throws -> [String: Any] {
        var payload: [String: Any] = [:]
        if let userId { payload["userId"] = userId }
        if let email { payload["email"] = email }
        if let cid { payload["cid"] = cid }
        return try await postRaw("/auth/delete-account", body: payload)
    }

    /// Activation de l'abonnement Looby+ suite à un achat In-App StoreKit 2
    public func activateLoobyPlusIap(userId: Int?, email: String?, cid: String?, productId: String, transactionId: String) async throws -> [String: Any] {
        var payload: [String: Any] = [
            "productId": productId,
            "transactionId": transactionId
        ]
        if let userId { payload["userId"] = userId }
        if let email { payload["email"] = email }
        if let cid { payload["cid"] = cid }
        return try await postRaw("/loobyplus/activate-iap", body: payload)
    }

    // MARK: - Bootstrap, Boutique, Recherche ISBN & Membres

    public func fetchBootstrap(email: String?, userId: Int?) async throws -> LivriaBootstrapResponse {
        var items: [URLQueryItem] = []
        if let email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        if let userId, userId > 0 {
            items.append(URLQueryItem(name: "userId", value: String(userId)))
        }
        return try await getJSON("/bootstrap", queryItems: items)
    }

    public func fetchBookDetails(bookId: Int) async throws -> LivriaBookDetailResponse {
        try await getJSON("/books/\(bookId)")
    }

    /// Recherche par ISBN dans le catalogue Livria
    public func lookupISBN(_ isbn: String) async throws -> LivriaIsbnLookupResponse {
        let clean = isbn.filter { $0.isNumber || $0 == "X" || $0 == "x" }
        return try await getJSON("/isbn/\(clean)")
    }

    /// Recherche de points relais UPS par code postal, ville ou géolocalisation GPS
    public func searchUpsRelays(
        query: String? = nil,
        cp: String? = nil,
        ville: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil
    ) async throws -> LivriaUpsSearchResponse {
        var items: [URLQueryItem] = []
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "query", value: query)) }
        if let cp, !cp.isEmpty { items.append(URLQueryItem(name: "cp", value: cp)) }
        if let ville, !ville.isEmpty { items.append(URLQueryItem(name: "ville", value: ville)) }
        if let lat { items.append(URLQueryItem(name: "lat", value: String(lat))) }
        if let lon { items.append(URLQueryItem(name: "lon", value: String(lon))) }
        return try await getJSON("/relays/ups", queryItems: items)
    }

    /// Recherche de membres publics (redirigeant vers Livria Social / LoobySocial)
    public func searchMembersResponse(query: String) async throws -> LivriaMemberSearchResponse {
        try await getJSON(
            "/members/search",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
    }

    public func searchMembers(query: String) async throws -> [LivriaMemberSearchResult] {
        let res = try await searchMembersResponse(query: query)
        return res.members
    }

    public func fetchPaymentSettings() async throws -> LivriaPaymentSettings {
        try await getJSON("/payment-settings")
    }

    // MARK: - Paiement Express PayPal / Apple Pay / Google Pay & Activation Compte Post-Commande

    public func createPayPalExpressOrder(amount: Double, walletSource: String?) async throws -> LivriaPayPalCreateResponse {
        var payload: [String: Any] = ["amount": amount]
        if let walletSource, !walletSource.isEmpty {
            payload["walletSource"] = walletSource
        }
        return try await postJSON("/checkout/paypal-create", body: payload)
    }

    public func finalizePostOrderGuestAccount(
        guestUserId: Int?,
        orderId: Int?,
        email: String,
        displayName: String,
        password: String,
        mode: String
    ) async throws -> LivriaFinalizeAccountResponse {
        var payload: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "password": password,
            "mode": mode
        ]
        if let guestUserId {
            payload["guestUserId"] = guestUserId
        }
        if let orderId {
            payload["orderId"] = orderId
        }
        return try await postJSON("/checkout/finalize-account", body: payload)
    }
}
