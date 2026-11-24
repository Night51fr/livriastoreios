import Foundation
import Security
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
    private let backgroundPollSession: URLSession
    private let decoder: JSONDecoder

    public static let serverLunchBreakMessage = "Notre serveur est a sa pause dejeuner, Merci de revenir une fois le serveur rétabli."

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 20
        self.session = URLSession(configuration: cfg)

        let bgCfg = URLSessionConfiguration.default
        bgCfg.timeoutIntervalForRequest = 7.0
        bgCfg.timeoutIntervalForResource = 10.0
        bgCfg.waitsForConnectivity = false
        self.backgroundPollSession = URLSession(configuration: bgCfg)

        self.decoder = JSONDecoder()
    }

    public var resolvedDeviceIdentifier: String {
        let sharedSuite = UserDefaults(suiteName: "group.com.viplenetwork.shared")
        #if canImport(UIKit)
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString, !vendorId.isEmpty {
            sharedSuite?.set(vendorId, forKey: "viple.shared.deviceId")
            return vendorId
        }
        #endif
        if let sharedId = sharedSuite?.string(forKey: "viple.shared.deviceId"), !sharedId.isEmpty {
            return sharedId
        }
        if let localId = UserDefaults.standard.string(forKey: "viple.local.deviceId"), !localId.isEmpty {
            sharedSuite?.set(localId, forKey: "viple.shared.deviceId")
            return localId
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: "viple.local.deviceId")
        sharedSuite?.set(generated, forKey: "viple.shared.deviceId")
        return generated
    }

    private func applyVipleDeviceHeaders(to req: inout URLRequest) {
        req.setValue("Livria Store", forHTTPHeaderField: "X-Viple-App-Name")
        req.setValue("26.10", forHTTPHeaderField: "X-Viple-Client-Version")
        req.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Viple-Request-Id")
        if req.httpMethod == "POST" {
            req.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Idempotency-Key")
        }
        let devId = resolvedDeviceIdentifier
        if !devId.isEmpty {
            req.setValue(devId, forHTTPHeaderField: "X-Viple-Vendor-Id")
            req.setValue(devId, forHTTPHeaderField: "X-Viple-Device-Id")
        }
        #if canImport(UIKit)
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
                reportVipleDiagnosticError(urlOrRoute: req.url?.absoluteString ?? "ios://livria", statusCode: http.statusCode, message: "HTTP \(http.statusCode) Livria Store iOS")
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
            reportVipleDiagnosticError(urlOrRoute: req.url?.absoluteString ?? "ios://livria", statusCode: nil, message: error.localizedDescription)
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
        let devId = resolvedDeviceIdentifier
        guard devId.count >= 8 else { return nil }
        let items = [
            URLQueryItem(name: "currentApp", value: "Livria Store"),
            URLQueryItem(name: "vendorId", value: devId),
            URLQueryItem(name: "deviceId", value: devId)
        ]
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
        let devId = resolvedDeviceIdentifier
        guard devId.count >= 8 else { return }
        let payload: [String: Any] = [
            "sourceApp": "Livria Store",
            "appName": "Livria Store",
            "userId": userId,
            "email": email,
            "vendorId": devId,
            "deviceId": devId
        ]
        _ = try? await postRaw("/sso/announce", body: payload)
        _ = try? await postRaw("\(socialBaseAPI)/sso/announce", body: payload)
    }

    public func clearCrossAppSession() async {
        let devId = resolvedDeviceIdentifier
        guard devId.count >= 8 else { return }
        let payload: [String: Any] = [
            "sourceApp": "Livria Store",
            "appName": "Livria Store",
            "vendorId": devId,
            "deviceId": devId
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
        let devId = resolvedDeviceIdentifier
        var payload: [String: Any] = [
            "userId": userId,
            "email": email,
            "vendorId": devId,
            "deviceId": devId
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

    // MARK: - Suivi Natif Viple Delivery Intégré (Sans ouvrir Safari)

    public func trackVipleDelivery(
        trackingNumber: String? = nil,
        orderId: Int? = nil,
        reference: String? = nil
    ) async throws -> LivriaVipleDeliveryTrackResponse {
        var items: [URLQueryItem] = []
        if let trackingNumber, !trackingNumber.isEmpty {
            items.append(URLQueryItem(name: "trackingNumber", value: trackingNumber))
        }
        if let orderId, orderId > 0 {
            items.append(URLQueryItem(name: "orderId", value: String(orderId)))
        }
        if let reference, !reference.isEmpty {
            items.append(URLQueryItem(name: "reference", value: reference))
        }
        return try await getJSON("/delivery/track", queryItems: items)
    }

    public func fetchUserShipments(userId: Int?, email: String?) async throws -> LivriaUserShipmentsResponse {
        var items: [URLQueryItem] = []
        if let userId, userId > 0 {
            items.append(URLQueryItem(name: "userId", value: String(userId)))
        }
        if let email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        return try await getJSON("/delivery/user-shipments", queryItems: items)
    }

    // MARK: - Préférences Mobile Synchronisées, Export RGPD & Diagnostics

    public func fetchUserPreferences(userId: Int?, email: String?) async throws -> LivriaUserPreferencesResponse {
        var items: [URLQueryItem] = []
        if let userId, userId > 0 {
            items.append(URLQueryItem(name: "userId", value: String(userId)))
        }
        if let email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        return try await getJSON("/account/preferences", queryItems: items)
    }

    public func saveUserPreferences(
        userId: Int?,
        email: String?,
        preferences: LivriaUserPreferences
    ) async throws -> LivriaUserPreferencesResponse {
        var payload: [String: Any] = [
            "notifyOrders": preferences.notifyOrders,
            "notifyMessages": preferences.notifyMessages,
            "notifyPriceDrops": preferences.notifyPriceDrops,
            "notifyStockAlerts": preferences.notifyStockAlerts,
            "notifyBookClubs": preferences.notifyBookClubs,
            "dataSaverMode": preferences.dataSaverMode,
            "hapticFeedback": preferences.hapticFeedback,
            "autoPlayAmbientAudio": preferences.autoPlayAmbientAudio,
            "hideSpoilersDefault": preferences.hideSpoilersDefault,
            "biometricLockEnabled": preferences.biometricLockEnabled,
            "defaultShippingMode": preferences.defaultShippingMode,
            "preferredConditionFilter": preferences.preferredConditionFilter,
            "readingFontScale": preferences.readingFontScale,
            "highContrastCards": preferences.highContrastCards
        ]
        if let userId, userId > 0 { payload["userId"] = userId }
        if let email, !email.isEmpty { payload["email"] = email }
        return try await postJSON("/account/preferences", body: payload)
    }

    public func exportPrivacyData(userId: Int?, email: String?) async throws -> String {
        var items: [URLQueryItem] = []
        if let userId, userId > 0 {
            items.append(URLQueryItem(name: "userId", value: String(userId)))
        }
        if let email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        var components = URLComponents(string: "\(baseAPI)/account/privacy-export")!
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        applyVipleDeviceHeaders(to: &req)
        let (data, _) = try await performRequest(req)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public func pingDiagnostics() async throws -> LivriaDiagnosticsPingResponse {
        try await getJSON("/diagnostics/ping")
    }

    // MARK: - Ma Bibliothèque, Progression de Lecture & Contenu Liseuse / Audio

    public func updateShelfEntry(
        email: String?,
        cid: String?,
        bookId: Int,
        status: String?,
        rating: Int?,
        progress: Double?,
        format: String?
    ) async throws -> LivriaSimpleResponse {
        var payload: [String: Any] = ["bookId": bookId]
        if let email, !email.isEmpty { payload["email"] = email }
        if let cid, !cid.isEmpty { payload["cid"] = cid }
        if let status, !status.isEmpty { payload["status"] = status }
        if let rating { payload["rating"] = rating }
        if let progress { payload["progress"] = progress }
        if let format, !format.isEmpty { payload["format"] = format }
        return try await postJSON("/shelf/update", body: payload)
    }

    public func removeShelfEntry(
        email: String?,
        cid: String?,
        bookId: Int
    ) async throws -> LivriaSimpleResponse {
        var payload: [String: Any] = ["bookId": bookId]
        if let email, !email.isEmpty { payload["email"] = email }
        if let cid, !cid.isEmpty { payload["cid"] = cid }
        return try await postJSON("/shelf/remove", body: payload)
    }

    public func fetchLibraryBookContent(
        bookId: Int,
        userId: Int?,
        email: String?,
        cid: String?
    ) async throws -> LivriaLibraryBookContentResponse {
        var items: [URLQueryItem] = []
        if let userId, userId > 0 {
            items.append(URLQueryItem(name: "userId", value: String(userId)))
        }
        if let email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        if let cid, !cid.isEmpty {
            items.append(URLQueryItem(name: "cid", value: cid))
        }
        return try await getJSON("/library/book/\(bookId)/content", queryItems: items)
    }

    // MARK: - Les Nouvelles Sorties du Jour & Notifications Push APNs

    public nonisolated static func detectAppleTeamIdFromKeychain() -> String {
        let account = "viple.livriastore.apns.teamid.probe"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.viplenetwork.livria.apns.probe",
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery.removeValue(forKey: kSecMatchLimit as String)
            addQuery[kSecValueData as String] = Data("1".utf8)
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(addQuery as CFDictionary, &result)
        }
        if status == errSecSuccess,
           let attrs = result as? [String: Any],
           let group = attrs[kSecAttrAccessGroup as String] as? String {
            let prefix = group.split(separator: ".").first.map(String.init) ?? ""
            if prefix.count == 10 && prefix.allSatisfy({ $0.isLetter || $0.isNumber }) {
                return prefix
            }
        }
        return ""
    }

    public func fetchDailyNewReleases(
        days: Int = 7,
        userId: Int?,
        email: String?,
        cid: String?
    ) async throws -> LivriaDailyReleasesResponse {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "days", value: String(days))
        ]
        if let userId, userId > 0 {
            items.append(URLQueryItem(name: "userId", value: String(userId)))
        }
        if let email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        if let cid, !cid.isEmpty {
            items.append(URLQueryItem(name: "cid", value: cid))
        }
        return try await getJSON("/new-releases", queryItems: items)
    }

    public func registerPushDevice(
        userId: Int?,
        email: String?,
        cid: String?,
        apnsToken: String?,
        notificationsEnabled: Bool = true,
        newReleasesEnabled: Bool = true,
        dailyRecommendationsEnabled: Bool = true
    ) async {
        let devId = resolvedDeviceIdentifier
        guard !devId.isEmpty else { return }
        #if DEBUG
        let apnsEnv = "sandbox"
        #else
        let apnsEnv = "production"
        #endif
        var payload: [String: Any] = [
            "deviceId": devId,
            "vendorId": devId,
            "apnsToken": apnsToken ?? "",
            "apnsEnvironment": apnsEnv,
            "appleTeamId": Self.detectAppleTeamIdFromKeychain(),
            "platform": "iOS",
            "appVersion": "2611.22",
            "notificationsEnabled": notificationsEnabled,
            "newReleasesEnabled": newReleasesEnabled,
            "dailyRecommendationsEnabled": dailyRecommendationsEnabled
        ]
        if let userId, userId > 0 { payload["userId"] = userId }
        if let email, !email.isEmpty { payload["email"] = email }
        if let cid, !cid.isEmpty { payload["cid"] = cid }
        _ = try? await postRaw("/devices/register", body: payload)
    }

    public func unregisterPushDevice(userId: Int?, email: String?) async {
        let devId = resolvedDeviceIdentifier
        guard !devId.isEmpty else { return }
        var payload: [String: Any] = [
            "deviceId": devId,
            "vendorId": devId
        ]
        if let userId, userId > 0 { payload["userId"] = userId }
        if let email, !email.isEmpty { payload["email"] = email }
        _ = try? await postRaw("/devices/unregister", body: payload)
    }

    public func pollNotifications(
        userId: Int?,
        email: String?,
        cid: String?,
        limit: Int = 25,
        fastBackground: Bool = false
    ) async throws -> LivriaNotificationPollResponse {
        let devId = resolvedDeviceIdentifier
        var items: [URLQueryItem] = [
            URLQueryItem(name: "deviceId", value: devId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let userId, userId > 0 {
            items.append(URLQueryItem(name: "userId", value: String(userId)))
        }
        if let email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        if let cid, !cid.isEmpty {
            items.append(URLQueryItem(name: "cid", value: cid))
        }

        if fastBackground {
            var comps = URLComponents(string: "\(baseAPI)/notifications/poll")!
            comps.queryItems = items
            guard let url = comps.url else {
                throw URLError(.badURL)
            }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.timeoutInterval = 7.0
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("LivriaStore-iOS/2611.22 (AppID/\(LivriaAppConfig.appleAppId); BackgroundFetch)", forHTTPHeaderField: "User-Agent")
            applyVipleDeviceHeaders(to: &req)
            let (data, response) = try await backgroundPollSession.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return try decoder.decode(LivriaNotificationPollResponse.self, from: data)
        }

        return try await getJSON("/notifications/poll", queryItems: items)
    }

    public func ackNotifications(
        notificationIds: [String],
        userId: Int?,
        email: String?
    ) async {
        let cleanIds = notificationIds.filter { !$0.isEmpty }
        guard !cleanIds.isEmpty else { return }
        let devId = resolvedDeviceIdentifier
        var payload: [String: Any] = [
            "deviceId": devId,
            "vendorId": devId,
            "notificationIds": cleanIds
        ]
        if let userId, userId > 0 { payload["userId"] = userId }
        if let email, !email.isEmpty { payload["email"] = email }
        _ = try? await postRaw("/notifications/ack", body: payload)
    }

    // MARK: - Viple Live ID CRM Affinity Telemetry & Ecosystem Error Diagnostics

    nonisolated public func sendVipleTelemetry(
        userEmail: String?,
        userCid: String?,
        livriaUserId: Int? = nil,
        eventType: String,
        category: String? = nil,
        subCategory: String? = nil,
        actionLabel: String? = nil,
        detail: String? = nil,
        imageUrl: String? = nil,
        priceEur: Double? = nil,
        isbn: String? = nil,
        genre: String? = nil,
        author: String? = nil,
        itemId: String? = nil,
        itemTitle: String? = nil,
        screen: String? = nil
    ) {
        let rawEmail = (userEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let em = rawEmail.lowercased().hasSuffix("@guest.livria.store") ? "" : rawEmail
        let cid = (userCid ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if em.isEmpty && cid.isEmpty { return }
        guard let url = URL(string: "https://api.viple.digital/api/public/telemetry/event") else { return }

        var meta: [String: Any] = [:]
        if let category, !category.isEmpty { meta["category"] = category }
        if let subCategory, !subCategory.isEmpty { meta["subCategory"] = subCategory }
        if let actionLabel, !actionLabel.isEmpty { meta["actionLabel"] = actionLabel }
        if let detail, !detail.isEmpty { meta["detail"] = detail }
        if let imageUrl, !imageUrl.isEmpty {
            let resolvedImg = LivriaURLResolver.resolve(imageUrl)?.absoluteString ?? imageUrl
            meta["imageUrl"] = resolvedImg
            meta["coverUrl"] = resolvedImg
        }
        if let priceEur { meta["priceEur"] = priceEur }
        if let isbn, !isbn.isEmpty { meta["isbn"] = isbn }

        var payload: [String: Any] = [
            "platform": "livria-ios",
            "eventType": eventType,
            "pathOrScreen": screen ?? "ios://livria/\(eventType)"
        ]
        if !em.isEmpty { payload["userEmail"] = em }
        if !cid.isEmpty { payload["userCid"] = cid }
        if let livriaUserId, livriaUserId > 0 { payload["livriaUserId"] = livriaUserId }
        if let genre, !genre.isEmpty { payload["genre"] = genre }
        if let author, !author.isEmpty { payload["author"] = author }
        if let itemId, !itemId.isEmpty { payload["itemId"] = itemId }
        if let itemTitle, !itemTitle.isEmpty { payload["itemTitle"] = itemTitle }
        if let category, !category.isEmpty { payload["category"] = category }
        if let subCategory, !subCategory.isEmpty { payload["subCategory"] = subCategory }
        if let actionLabel, !actionLabel.isEmpty { payload["actionLabel"] = actionLabel }
        if let detail, !detail.isEmpty { payload["detail"] = detail }
        if let imageUrl, !imageUrl.isEmpty {
            payload["imageUrl"] = LivriaURLResolver.resolve(imageUrl)?.absoluteString ?? imageUrl
        }
        if let priceEur { payload["priceEur"] = priceEur }
        if let isbn, !isbn.isEmpty { payload["isbn"] = isbn }
        if !meta.isEmpty,
           let metaData = try? JSONSerialization.data(withJSONObject: meta),
           let metaStr = String(data: metaData, encoding: .utf8) {
            payload["metadataJson"] = metaStr
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task.detached(priority: .utility) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 10
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Livria Store iOS", forHTTPHeaderField: "X-Viple-App-Name")
            req.httpBody = body
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    nonisolated public func reportVipleDiagnosticError(urlOrRoute: String, statusCode: Int?, message: String, userEmail: String? = nil) {
        if urlOrRoute.contains("api.viple.digital/api/public/") { return }
        guard let url = URL(string: "https://api.viple.digital/api/public/diagnostics/error") else { return }
        var payload: [String: Any] = [
            "service": "livria-store",
            "platform": "ios",
            "severity": (statusCode ?? 503) >= 500 ? "critical" : "error",
            "errorType": "mobile_http_error",
            "message": String(message.prefix(500)),
            "urlOrRoute": urlOrRoute
        ]
        if let statusCode { payload["statusCode"] = statusCode }
        if let userEmail, !userEmail.isEmpty { payload["userEmail"] = userEmail }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task.detached(priority: .utility) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 10
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
            _ = try? await URLSession.shared.data(for: req)
        }
    }
}
