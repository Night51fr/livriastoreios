import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Contrôleur Réactif du Moteur Web Encapsulé (WKWebView)

@MainActor
public final class PanelWebController: ObservableObject {
    @Published public var currentURL: URL? = nil
    @Published public var pageTitle: String = ""
    @Published public var isLoading: Bool = false
    @Published public var estimatedProgress: Double = 0.0
    @Published public var canGoBack: Bool = false
    @Published public var canGoForward: Bool = false
    @Published public var lastLoadError: String? = nil

    public fileprivate(set) weak var webView: WKWebView?
    public var pendingPostLoadJavaScript: String? = nil

    public init() {}

    public func load(url: URL, postLoadJS: String? = nil) {
        lastLoadError = nil
        pendingPostLoadJavaScript = postLoadJS

        guard let wv = webView else {
            currentURL = url
            return
        }

        // Si seule l'ancre (#hash) change sur un SPA type Viple SysGRC, naviguer de manière fluide
        if wv.url?.host == url.host && wv.url?.path == url.path && url.fragment != nil {
            wv.load(URLRequest(url: url))
            if let js = postLoadJS, !js.isEmpty {
                wv.evaluateJavaScript(js, completionHandler: nil)
                pendingPostLoadJavaScript = nil
            }
            return
        }

        var req = URLRequest(url: url)
        req.cachePolicy = .useProtocolCachePolicy
        wv.load(req)
    }

    public func reload() {
        WorkspaceHaptics.light()
        lastLoadError = nil
        webView?.reload()
    }

    public func goBack() {
        guard webView?.canGoBack == true else { return }
        WorkspaceHaptics.light()
        webView?.goBack()
    }

    public func goForward() {
        guard webView?.canGoForward == true else { return }
        WorkspaceHaptics.light()
        webView?.goForward()
    }

    public func resetStateOnLogout() {
        pendingPostLoadJavaScript = nil
        currentURL = nil
        pageTitle = ""
        isLoading = false
        estimatedProgress = 0
        canGoBack = false
        canGoForward = false
        lastLoadError = nil
        webView?.stopLoading()
        webView?.loadHTMLString("<html><body style='background:#0E1513;'></body></html>", baseURL: nil)
    }

    /// Renvoie le code-barres / ISBN lu par le scanner matériel iOS à Wingman via `window.onNativeBarcodeScanned(code, meta)`
    public func deliverScannedBarcode(
        code: String,
        symbology: String,
        mode: NativeBarcodeScanMode,
        totalCount: Int,
        fieldContext: String
    ) {
        guard let wv = webView else { return }
        let payloadDict: [String: Any] = [
            "code": code,
            "symbology": symbology,
            "mode": mode.rawValue,
            "count": totalCount,
            "field": fieldContext,
            "isIsbn": (code.count == 13 && (code.hasPrefix("978") || code.hasPrefix("979"))) || code.count == 10
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = """
        (function(meta) {
            var code = meta.code || "";
            if (typeof window.onNativeBarcodeScanned === "function") {
                window.onNativeBarcodeScanned(code, meta);
            }
            window.dispatchEvent(new CustomEvent("cenelis:native-barcode", { detail: meta }));
        })(\(jsonString));
        """
        wv.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Notifie Wingman de la fermeture de la modale native (avec le récapitulatif éventuel du mode Rafale)
    public func notifyBarcodeScannerClosed(mode: NativeBarcodeScanMode, entries: [ScannedBarcodeEntry]) {
        guard let wv = webView else { return }
        let itemsArray: [[String: Any]] = entries.map { entry in
            [
                "code": entry.code,
                "symbology": entry.symbology,
                "quantity": entry.quantity
            ]
        }
        let summaryDict: [String: Any] = [
            "mode": mode.rawValue,
            "totalScanned": entries.reduce(0) { $0 + $1.quantity },
            "uniqueCount": entries.count,
            "items": itemsArray
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: summaryDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = """
        (function(summary) {
            if (typeof window.onNativeBarcodeScannerClosed === "function") {
                window.onNativeBarcodeScannerClosed(summary);
            }
            window.dispatchEvent(new CustomEvent("cenelis:native-barcode-closed", { detail: summary }));
        })(\(jsonString));
        """
        wv.evaluateJavaScript(js, completionHandler: nil)
    }
}

// MARK: - Délégué Faible `WKScriptMessageHandler` (Évite tout cycle de rétention avec WKUserContentController)

@MainActor
private final class WeakBarcodeScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - Vue SwiftUI Encapsulant WKWebView (Pull-to-Refresh, Swipe-Back, Safe Areas, Interceptions & Pont `barcodeScanner`)

public struct CenelisPanelWebView: UIViewRepresentable {
    public static let barcodeHandlerName = "barcodeScanner"

    @ObservedObject public var controller: PanelWebController
    public let initialURL: URL?
    public let onInterceptCenelisAcademyURL: (URL) -> Void
    public let onInterceptUnexpectedWebPinGate: (URL?) -> Void
    public let onInterceptWebLogoutRequest: () -> Void
    public let onBarcodeScannerMessage: (String, NativeBarcodeScanRequest?) -> Void

    public init(
        controller: PanelWebController,
        initialURL: URL?,
        onInterceptCenelisAcademyURL: @escaping (URL) -> Void,
        onInterceptUnexpectedWebPinGate: @escaping (URL?) -> Void,
        onInterceptWebLogoutRequest: @escaping () -> Void,
        onBarcodeScannerMessage: @escaping (String, NativeBarcodeScanRequest?) -> Void = { _, _ in }
    ) {
        self.controller = controller
        self.initialURL = initialURL
        self.onInterceptCenelisAcademyURL = onInterceptCenelisAcademyURL
        self.onInterceptUnexpectedWebPinGate = onInterceptUnexpectedWebPinGate
        self.onInterceptWebLogoutRequest = onInterceptWebLogoutRequest
        self.onBarcodeScannerMessage = onBarcodeScannerMessage
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WorkspaceWebSessionPool.shared.makePanelWebViewConfiguration(includeNativeAdminCleanup: true)
        // Exposition du pont matériel natif `window.webkit.messageHandlers.barcodeScanner` pour Viple Wingman
        config.userContentController.add(
            WeakBarcodeScriptMessageHandler(delegate: context.coordinator),
            name: Self.barcodeHandlerName
        )
        let webView = WKWebView(frame: .zero, configuration: config)

        // Ergonomie mobile 100 % native : Swipe-Back, Safe Areas, zéro barre Safari
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.keyboardDismissMode = .interactive

        // UIRefreshControl natif pour le Pull-to-Refresh
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor(red: 0.722, green: 0.365, blue: 0.231, alpha: 1.0)
        refreshControl.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handlePullToRefresh(_:)),
            for: .valueChanged
        )
        webView.scrollView.refreshControl = refreshControl

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        context.coordinator.attachObservers(to: webView)
        controller.webView = webView

        if let target = controller.currentURL ?? initialURL {
            webView.load(URLRequest(url: target))
        }

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if controller.webView !== uiView {
            controller.webView = uiView
        }
    }

    public static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: Self.barcodeHandlerName)
    }

    // MARK: - Coordinator WKNavigationDelegate, WKUIDelegate & WKScriptMessageHandler (`barcodeScanner`)

    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: CenelisPanelWebView
        private var observations: [NSKeyValueObservation] = []

        init(parent: CenelisPanelWebView) {
            self.parent = parent
        }

        public func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == CenelisPanelWebView.barcodeHandlerName else { return }
            let parsed = NativeBarcodeScanRequest.fromJSMessageBody(message.body)
            parent.onBarcodeScannerMessage(parsed.action, parsed.request)
        }

        func attachObservers(to webView: WKWebView) {
            observations.removeAll()

            observations.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.parent.controller.estimatedProgress = wv.estimatedProgress
                }
            })

            observations.append(webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.parent.controller.isLoading = wv.isLoading
                    if !wv.isLoading {
                        wv.scrollView.refreshControl?.endRefreshing()
                    }
                }
            })

            observations.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.parent.controller.canGoBack = wv.canGoBack
                }
            })

            observations.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.parent.controller.canGoForward = wv.canGoForward
                }
            })

            observations.append(webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.parent.controller.pageTitle = wv.title ?? ""
                }
            })

            observations.append(webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.parent.controller.currentURL = wv.url
                }
            })
        }

        @objc func handlePullToRefresh(_ sender: UIRefreshControl) {
            WorkspaceHaptics.light()
            parent.controller.webView?.reload()
        }

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = (url.scheme ?? "").lowercased()
            let host = (url.host ?? "").lowercased()
            let path = url.path.lowercased()

            // 1. Schémas externes système (cenelisacademy://, mailto:, tel:)
            if scheme == "cenelisacademy" {
                decisionHandler(.cancel)
                parent.onInterceptCenelisAcademyURL(url)
                return
            }
            if scheme == "mailto" || scheme == "tel" {
                decisionHandler(.cancel)
                #if canImport(UIKit)
                UIApplication.shared.open(url)
                #endif
                return
            }

            // 2. Routage externe strict de tout lien vers Cenelis Academy (ne JAMAIS charger le site web dans la WebView)
            if host == "academy.prod.cenelis.com" || host == "academy.cenelis.com" {
                decisionHandler(.cancel)
                parent.onInterceptCenelisAcademyURL(url)
                return
            }

            // 3. Interception d'une éventuelle tentative de déconnexion web -> déconnexion globale native
            if path == "/logout" || path == "/logout.srf" || path == "/deconnexion" {
                decisionHandler(.cancel)
                parent.onInterceptWebLogoutRequest()
                return
            }

            // 4. Neutralisation de la redemande automatique du Cenelis Connect PIN toutes les 1h côté web
            if host == "sso.prod.cenelis.com" && path.hasPrefix("/pin") {
                let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let retRaw = comps?.queryItems?.first(where: { $0.name == "returnUrl" })?.value
                let retURL = retRaw.flatMap { URL(string: $0) } ?? webView.url
                decisionHandler(.cancel)
                parent.onInterceptUnexpectedWebPinGate(retURL)
                return
            }

            // 5. Gestion fluide des liens target="_blank" (ouvrir dans la même WebView si domaine de confiance)
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
            parent.controller.lastLoadError = nil

            // Ré-appliquer par sécurité le masquage CSS du dock web flottant
            webView.evaluateJavaScript(WorkspaceWebSessionPool.nativeWorkspaceDocumentEndScript, completionHandler: nil)

            // Exécuter l'action profonde éventuelle issue de la recherche « Fonctions »
            if let pendingJS = parent.controller.pendingPostLoadJavaScript, !pendingJS.isEmpty {
                parent.controller.pendingPostLoadJavaScript = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    webView.evaluateJavaScript(pendingJS, completionHandler: nil)
                }
            }

            // Sauvegarder les cookies SSO maîtres dans le Trousseau iOS
            Task { @MainActor in
                await WorkspaceWebSessionPool.shared.backupMasterCookiesToKeychain()
            }
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
            let nsErr = error as NSError
            if nsErr.code == NSURLErrorCancelled { return }
            parent.controller.lastLoadError = error.localizedDescription
        }

        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                let host = (url.host ?? "").lowercased()
                if host == "academy.prod.cenelis.com" || url.scheme?.lowercased() == "cenelisacademy" {
                    parent.onInterceptCenelisAcademyURL(url)
                    return nil
                }
                webView.load(navigationAction.request)
            }
            return nil
        }

        public func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor () -> Void
        ) {
            #if canImport(UIKit)
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                completionHandler()
                return
            }
            let alert = UIAlertController(title: "Cenelis Workspace", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            topPresenter(from: rootVC).present(alert, animated: true)
            #else
            completionHandler()
            #endif
        }

        public func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor (Bool) -> Void
        ) {
            #if canImport(UIKit)
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                completionHandler(false)
                return
            }
            let alert = UIAlertController(title: "Confirmation", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "Confirmer", style: .default) { _ in completionHandler(true) })
            topPresenter(from: rootVC).present(alert, animated: true)
            #else
            completionHandler(false)
            #endif
        }

        #if canImport(UIKit)
        private func topPresenter(from root: UIViewController) -> UIViewController {
            var current = root
            while let presented = current.presentedViewController {
                current = presented
            }
            return current
        }
        #endif
    }
}

// MARK: - WebView d'Authentification SSO Viple Live ID Partageant le WKWebsiteDataStore

public struct SharedSSOAuthWebView: UIViewRepresentable {
    public let startURL: URL
    public let onSessionDetected: (String) -> Void

    public init(startURL: URL, onSessionDetected: @escaping (String) -> Void) {
        self.startURL = startURL
        self.onSessionDetected = onSessionDetected
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WorkspaceWebSessionPool.shared.makePanelWebViewConfiguration(includeNativeAdminCleanup: false)
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.load(URLRequest(url: startURL))
        return wv
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SharedSSOAuthWebView
        private var hasTriggeredDetection = false

        init(parent: SharedSSOAuthWebView) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                let cookies = await WorkspaceWebSessionPool.shared.sharedDataStore.httpCookieStore.allCookies()
                guard let connectCookie = cookies.first(where: { $0.name == ".Cenelis.Connect.Auth" }) else {
                    return
                }
                guard !self.hasTriggeredDetection else { return }
                self.hasTriggeredDetection = true
                let header = "\(connectCookie.name)=\(connectCookie.value)"
                await WorkspaceWebSessionPool.shared.backupMasterCookiesToKeychain()
                self.parent.onSessionDetected(header)
            }
        }
    }
}
