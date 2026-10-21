import Foundation

// MARK: - Client Réseau REST Natif « Livria Store » (App Store ID : 6825159743 • iOS 18+ / iOS 26+)

public actor LivriaAPIClient {
    public static let shared = LivriaAPIClient()

    public let baseAPI = "https://livria.store/api/mobile/v1"
    private let session: URLSession
    private let decoder: JSONDecoder

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.timeoutIntervalForResource = 45
        self.session = URLSession(configuration: cfg)
        self.decoder = JSONDecoder()
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
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("LivriaStore-iOS/26.0 (AppID/\(LivriaAppConfig.appleAppId); iPhone; iOS 18.0+)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = errDict["error"] as? String {
                throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur HTTP \(http.statusCode)"])
        }
        return try decoder.decode(T.self, from: data)
    }

    public func postJSON<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: path.hasPrefix("http") ? path : "\(baseAPI)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("LivriaStore-iOS/26.0 (AppID/\(LivriaAppConfig.appleAppId); iPhone; iOS 18.0+)", forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if let errDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = errDict["error"] as? String {
                throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur HTTP \(http.statusCode)"])
        }
        return try decoder.decode(T.self, from: data)
    }

    public func postRaw(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: path.hasPrefix("http") ? path : "\(baseAPI)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("LivriaStore-iOS/26.0 (AppID/\(LivriaAppConfig.appleAppId); iPhone; iOS 18.0+)", forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = (dict["error"] as? String) ?? "Erreur serveur (\(http.statusCode))"
            throw NSError(domain: "LivriaStoreAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return dict
    }

    // MARK: - Authentification Native Viple Live ID

    public func loginVipleLiveID(email: String, password: String) async throws -> LivriaAuthResponse {
        try await postJSON("/auth/login", body: [
            "email": email,
            "password": password
        ])
    }

    /// Inscription Viple Live ID : `emailMode` = `"viplemail"` (`@viplemail.fr`) ou `"custom"` (email externe)
    public func registerVipleLiveID(
        emailMode: String,
        emailUser: String,
        customEmail: String,
        password: String,
        firstName: String,
        lastName: String,
        displayName: String
    ) async throws -> LivriaAuthResponse {
        try await postJSON("/auth/register", body: [
            "emailMode": emailMode,
            "emailUser": emailUser,
            "emailDomain": "viplemail.fr",
            "customEmail": customEmail,
            "email": emailMode == "viplemail" ? "\(emailUser)@viplemail.fr" : customEmail,
            "password": password,
            "firstName": firstName,
            "lastName": lastName,
            "displayName": displayName
        ])
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

    /// Recherche par ISBN (Google Books Priorité 1 avec vérification stricte + OpenLibrary Fallback)
    public func lookupISBN(_ isbn: String) async throws -> LivriaIsbnLookupResponse {
        let clean = isbn.filter { $0.isNumber || $0 == "X" || $0 == "x" }
        return try await getJSON("/isbn/\(clean)")
    }

    /// Recherche de membres publics (redirigeant vers Livria Social)
    public func searchMembers(query: String) async throws -> [LivriaMemberSearchResult] {
        let res: LivriaMemberSearchResponse = try await getJSON(
            "/members/search",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        return res.members
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
