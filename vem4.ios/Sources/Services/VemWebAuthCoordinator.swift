import AuthenticationServices
import Foundation
import UIKit

// MARK: - ASWebAuthenticationSession Coordinator (Viple Live Web SSO & PayPal Checkout)

@MainActor
public final class VemWebAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = VemWebAuthCoordinator()
    private var activeSession: ASWebAuthenticationSession?

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let active = scenes.first(where: { $0.activationState == .foregroundActive }),
           let keyWindow = active.windows.first(where: { $0.isKeyWindow }) ?? active.windows.first {
            return keyWindow
        }
        return ASPresentationAnchor()
    }

    public func runWebFlow(startURL: URL, callbackScheme: String = "vipleetmoi", prefersEphemeral: Bool = false) async throws -> URL {
        activeSession?.cancel()
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: startURL, callbackURLScheme: callbackScheme) { callbackURL, error in
                Task { @MainActor in
                    self.activeSession = nil
                    if let callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else if let authErr = error as? ASWebAuthenticationSessionError, authErr.code == .canceledLogin {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(throwing: VemAPIError.network(error?.localizedDescription ?? "Session web interrompue."))
                    }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = prefersEphemeral
            self.activeSession = session
            if !session.start() {
                self.activeSession = nil
                continuation.resume(throwing: VemAPIError.network("Impossible d'ouvrir la fenêtre sécurisée."))
            }
        }
    }
}
