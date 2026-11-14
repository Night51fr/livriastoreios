import Foundation
import Security
import WebKit

// MARK: - Pool de Session Web Partagé (WKProcessPool + WKWebsiteDataStore) & Trousseau Keychain

@MainActor
public final class WorkspaceWebSessionPool {
    public static let shared = WorkspaceWebSessionPool()

    /// User-Agent normalisé pour que VipleAPI calcule systématiquement `BrowserKey = "mob:ios:safari"`
    public static let unifiedUserAgentSuffix = "Version/18.0 Mobile/15E148 Safari/604.1 CenelisWorkspace/2026.11"
    public static let fullURLSessionUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 CenelisWorkspace/2026.11"

    /// Unique `WKProcessPool` et `WKWebsiteDataStore` partagés entre toutes les vues Web de l'application
    public let sharedProcessPool = WKProcessPool()
    public let sharedDataStore: WKWebsiteDataStore = .default()

    /// WebView invisible dédiée à l'établissement silencieux du pont SSO Viple Live ID (`ssoBridgeUrl`)
    private var silentBridgeWebView: WKWebView?

    private let keychainService = "com.cenelis.workspace.sso"
    private let sharedAppGroup = UserDefaults(suiteName: "group.com.viplenetwork.shared")

    private init() {}

    // MARK: - Configuration WKWebView Standardisée avec Nettoyage CSS / JS

    public func makePanelWebViewConfiguration(includeNativeAdminCleanup: Bool = true) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.processPool = sharedProcessPool
        config.websiteDataStore = sharedDataStore
        config.applicationNameForUserAgent = Self.unifiedUserAgentSuffix
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences.preferredContentMode = .mobile

        let contentController = WKUserContentController()
        if includeNativeAdminCleanup {
            let startScript = WKUserScript(
                source: Self.nativeWorkspaceDocumentStartScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            let endScript = WKUserScript(
                source: Self.nativeWorkspaceDocumentEndScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
            contentController.addUserScript(startScript)
            contentController.addUserScript(endScript)
        }
        config.userContentController = contentController
        return config
    }

    // MARK: - Pont SSO Silencieux Viple Live ID <-> Cenelis Connect

    public func warmUpSSOBridgeIfNeeded(ssoBridgeURLString: String?) {
        guard let raw = ssoBridgeURLString,
              let url = URL(string: raw) else {
            return
        }

        if silentBridgeWebView == nil {
            let cfg = makePanelWebViewConfiguration(includeNativeAdminCleanup: false)
            let wv = WKWebView(frame: .zero, configuration: cfg)
            silentBridgeWebView = wv
        }
        silentBridgeWebView?.load(URLRequest(url: url))

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await self.backupMasterCookiesToKeychain()
        }
    }

    // MARK: - Sauvegarde & Restauration des Cookies Maîtres Viple Live ID / Cenelis Connect

    private struct CodableCookieRecord: Codable {
        let name: String
        let value: String
        let domain: String
        let path: String
        let isSecure: Bool
        let isHTTPOnly: Bool
        let expiresTimestamp: TimeInterval?
    }

    public func backupMasterCookiesToKeychain() async {
        let cookies = await sharedDataStore.httpCookieStore.allCookies()
        let critical = cookies.filter { c in
            let dom = c.domain.lowercased()
            return dom.contains("viple.digital")
                || dom.contains("cenelis.com")
                || dom.contains("cenelis.fr")
                || dom.contains("viplenetwork.com")
                || dom.contains("livria.store")
        }
        guard !critical.isEmpty else { return }

        let records: [CodableCookieRecord] = critical.map { c in
            CodableCookieRecord(
                name: c.name,
                value: c.value,
                domain: c.domain,
                path: c.path,
                isSecure: c.isSecure,
                isHTTPOnly: c.isHTTPOnly,
                expiresTimestamp: c.expiresDate?.timeIntervalSince1970
            )
        }
        if let encoded = try? JSONEncoder().encode(records) {
            saveKeychainData(encoded, account: "master_sso_cookies_v1")
        }
    }

    public func restoreMasterCookiesFromKeychainIfNeeded() async {
        guard let data = readKeychainData(account: "master_sso_cookies_v1"),
              let records = try? JSONDecoder().decode([CodableCookieRecord].self, from: data) else {
            return
        }

        let existing = await sharedDataStore.httpCookieStore.allCookies()
        let hasIdentityCookie = existing.contains(where: { $0.name == "viple.id.v2" || $0.name == ".Cenelis.Connect.Auth" })
        if hasIdentityCookie {
            return
        }

        for rec in records {
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: rec.name,
                .value: rec.value,
                .domain: rec.domain,
                .path: rec.path
            ]
            if rec.isSecure {
                props[.secure] = "TRUE"
            }
            if let exp = rec.expiresTimestamp {
                props[.expires] = Date(timeIntervalSince1970: exp)
            } else {
                props[.expires] = Date().addingTimeInterval(30 * 24 * 3600)
            }
            if let cookie = HTTPCookie(properties: props) {
                await sharedDataStore.httpCookieStore.setCookie(cookie)
            }
        }
    }

    // MARK: - Stockage Sécurisé Jeton & Profil Opérateur dans Keychain

    public func saveWorkspaceCredentials(token: String, profile: WorkspaceOperatorProfile) {
        saveKeychainData(Data(token.utf8), account: "workspace_mobile_token")
        if let profileData = try? JSONEncoder().encode(profile) {
            saveKeychainData(profileData, account: "workspace_operator_profile")
        }
        sharedAppGroup?.set(profile.email, forKey: "viple.shared.email")
    }

    public func loadSavedWorkspaceCredentials() -> (token: String, profile: WorkspaceOperatorProfile)? {
        guard let tokenData = readKeychainData(account: "workspace_mobile_token"),
              let token = String(data: tokenData, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }

        var profile = WorkspaceOperatorProfile(authenticated: true)
        if let profData = readKeychainData(account: "workspace_operator_profile"),
           let decoded = try? JSONDecoder().decode(WorkspaceOperatorProfile.self, from: profData) {
            profile = decoded
        }
        return (token, profile)
    }

    // MARK: - Purge Intégrale Session & Déconnexion Complète (Changement de Compte)

    public func purgeAllSessionsAndWebsiteData() async {
        silentBridgeWebView?.stopLoading()
        silentBridgeWebView = nil

        deleteKeychainItem(account: "workspace_mobile_token")
        deleteKeychainItem(account: "workspace_operator_profile")
        deleteKeychainItem(account: "master_sso_cookies_v1")

        sharedAppGroup?.removeObject(forKey: "viple.shared.email")
        sharedAppGroup?.removeObject(forKey: "ca.mobileToken")

        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        await sharedDataStore.removeData(ofTypes: allTypes, modifiedSince: .distantPast)

        let remainingCookies = await sharedDataStore.httpCookieStore.allCookies()
        for c in remainingCookies {
            await sharedDataStore.httpCookieStore.deleteCookie(c)
        }

        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        URLCache.shared.removeAllCachedResponses()
    }

    // MARK: - Primitives Keychain iOS

    private func saveKeychainData(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var insertQuery = query
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(insertQuery as CFDictionary, nil)
    }

    private func readKeychainData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteKeychainItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Scripts WKUserScript d'Encapsulation Native & Masquage Strict de la Pilule Web `/admin`

    public static let nativeWorkspaceCSSRules: String = """
    /* 1. Masquage total et permanent du sélecteur flottant web /admin (remplacé à 100 % par SwiftUI) */
    .vua-dock,
    #vua-dock-burger,
    .vua-dock__meta,
    .vua-panel,
    #vua-panel-list,
    .vua-backdrop,
    [aria-label="Barre d'administration unifiée"] {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
        width: 0 !important;
        height: 0 !important;
        max-height: 0 !important;
        overflow: hidden !important;
        transform: scale(0) !important;
    }

    /* 2. Récupération de l'espace inférieur réservé à l'ancienne pilule web */
    .vua-content {
        padding-bottom: 24px !important;
    }

    /* 3. Nettoyage des contrôles web redondants sur mobile tout en préservant les barres fonctionnelles des panels */
    .vua-topbar .vua-user-pill,
    .vua-topbar a[href*="/logout"],
    .vua-topbar a[href*="/deconnexion"],
    .vua-topbar form[action*="/deconnexion"],
    .vua-topbar .vua-top-btn--subtle,
    #btnAppLauncher,
    #appLauncherFlyout,
    #userMenuDropdown a[href="/logout"],
    .top-shell-right a[href="/logout"],
    .c2d-topbar__right a[href="/logout"],
    .gp-topbar-actions a[href="/logout"] {
        display: none !important;
        visibility: hidden !important;
    }

    /* 4. Fluidité tactile native iOS */
    html, body {
        -webkit-tap-highlight-color: transparent;
    }
    """

    public static var nativeWorkspaceDocumentStartScript: String {
        let escapedCSS = nativeWorkspaceCSSRules
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        return """
        (function() {
            window.__CENELIS_WORKSPACE_NATIVE_IOS__ = true;
            function injectNativeWorkspaceStyle() {
                if (document.getElementById('cenelis-workspace-native-style')) return;
                var style = document.createElement('style');
                style.id = 'cenelis-workspace-native-style';
                style.textContent = `\(escapedCSS)`;
                (document.head || document.documentElement).appendChild(style);
            }
            injectNativeWorkspaceStyle();
            document.addEventListener('DOMContentLoaded', injectNativeWorkspaceStyle, { once: true });

            var observer = new MutationObserver(function() {
                injectNativeWorkspaceStyle();
                var docks = document.querySelectorAll('.vua-dock, .vua-panel, .vua-backdrop, #vua-dock-burger');
                for (var i = 0; i < docks.length; i++) {
                    docks[i].style.setProperty('display', 'none', 'important');
                    docks[i].style.setProperty('visibility', 'hidden', 'important');
                    docks[i].setAttribute('aria-hidden', 'true');
                }
            });
            observer.observe(document.documentElement, { childList: true, subtree: true });
        })();
        """
    }

    public static var nativeWorkspaceDocumentEndScript: String {
        let escapedCSS = nativeWorkspaceCSSRules
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        return """
        (function() {
            var existing = document.getElementById('cenelis-workspace-native-style');
            if (!existing) {
                var style = document.createElement('style');
                style.id = 'cenelis-workspace-native-style';
                style.textContent = `\(escapedCSS)`;
                (document.head || document.documentElement).appendChild(style);
            }
            var docks = document.querySelectorAll('.vua-dock, .vua-panel, .vua-backdrop, #vua-dock-burger');
            for (var i = 0; i < docks.length; i++) {
                docks[i].style.setProperty('display', 'none', 'important');
                docks[i].style.setProperty('visibility', 'hidden', 'important');
            }
        })();
        """
    }
}
