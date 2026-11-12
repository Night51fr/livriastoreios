import Foundation
import Observation
import SwiftUI

// MARK: - Navigation Tabs & Toast Banner

public enum VemTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case services
    case family
    case billing
    case more

    public var id: String { rawValue }
}

public struct VemToastBanner: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let message: String
    public let isError: Bool
}

// MARK: - Central State Orchestrator for Viple & Moi (vem4.ios)

@MainActor
@Observable
public final class VemStoreViewModel {
    // Session & Data
    public var token: String?
    public var isAuthenticated: Bool = false
    public var isInitialLoading: Bool = false
    public var isMutating: Bool = false
    public var workspace: VemWorkspace?
    public var account: VemAccountProfile?
    public var ordersPayload: VemOrdersDeliveryPayload?
    public var isLoadingOrders: Bool = false

    // Embedded Academy Guide (guide-espace-client-v4)
    public var customerGuide: VemGuideCourse?
    public var guideBubbles: [String: VemGuideBubble] = [:]
    public var isLoadingGuide: Bool = false
    public var completedGuidePartIDs: Set<String> = []
    public var bestGuideQuizScorePct: Int = 0

    // Navigation & Filters
    public var selectedTab: VemTab = .home
    public var memberFilter: String = "all" // "all" | "delegated" | "\(member.id)"
    public var servicesSegment: Int = 0    // 0 = Mes Services, 1 = Boutique Officielle
    public var boutiqueCategory: String = "all"

    // Sheets & Modals
    public var activeServiceDetailID: Int?
    public var orderingProduct: VemBoutiqueProduct?
    public var selectedInvoiceForDetail: VemInvoice?
    public var showOrdersSheet: Bool = false
    public var showGuideSheet: Bool = false

    // Feedback & Confetti
    public var toast: VemToastBanner?
    public var confettiCounter: Int = 0
    public var crossAppHint: (email: String, name: String)?

    public init() {
        self.crossAppHint = VemKeychainStore.discoverCrossAppEmailHint()
        if let savedPages = UserDefaults.standard.stringArray(forKey: "vem4.guide.completed_parts") {
            self.completedGuidePartIDs = Set(savedPages)
        }
        self.bestGuideQuizScorePct = UserDefaults.standard.integer(forKey: "vem4.guide.best_quiz")

        if let savedToken = VemKeychainStore.loadToken(), !savedToken.isEmpty {
            self.token = savedToken
            self.isAuthenticated = true
            Task {
                if let cached = await VemAPIClient.shared.loadCachedBootstrap() {
                    self.workspace = cached.workspace
                    self.account = cached.account
                }
                await refreshAll(silent: true)
            }
        }
    }

    // MARK: Computed Helpers

    public var filteredSubscriptions: [VemSubscription] {
        guard let list = workspace?.subscriptions else { return [] }
        switch memberFilter {
        case "all":
            return list
        case "delegated":
            return list.filter { $0.isDelegatedToMe }
        default:
            return list.filter { "\($0.assignedMemberId ?? -1)" == memberFilter }
        }
    }

    public var filteredBoutiqueProducts: [VemBoutiqueProduct] {
        guard let list = workspace?.boutique.products else { return [] }
        if boutiqueCategory == "all" { return list }
        return list.filter { $0.category.lowercased() == boutiqueCategory.lowercased() }
    }

    public var pendingRequestsCount: Int {
        workspace?.optionRequests.count ?? 0
    }

    public func subscription(withID id: Int) -> VemSubscription? {
        workspace?.subscriptions.first(where: { $0.id == id })
    }

    public func compatibleCommercializedOptions(for sub: VemSubscription) -> [VemBoutiqueOption] {
        let activeCodes = Set(sub.options.map { $0.optionCode.lowercased() })
        return (workspace?.boutique.options ?? []).filter { opt in
            !activeCodes.contains(opt.optionCode.lowercased()) && opt.isCompatible(with: sub.category)
        }
    }

    // MARK: Toast & Celebration

    public func showToast(_ message: String, isError: Bool = false) {
        if isError {
            VemHaptics.error()
        } else {
            VemHaptics.success()
        }
        let banner = VemToastBanner(message: message, isError: isError)
        withAnimation(VemTheme.snappySpring) {
            self.toast = banner
        }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if self.toast?.id == banner.id {
                withAnimation(VemTheme.snappySpring) {
                    self.toast = nil
                }
            }
        }
    }

    public func celebrate() {
        confettiCounter += 1
        VemHaptics.success()
    }

    // MARK: Authentication & Deep Links

    public func signInWithCredentials(email: String, password: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else {
            showToast("Veuillez renseigner votre adresse e-mail Viple Live et votre mot de passe.", isError: true)
            return
        }
        isInitialLoading = true
        defer { isInitialLoading = false }

        do {
            let res = try await VemAPIClient.shared.login(email: trimmed, password: password)
            guard let tok = res.token, !tok.isEmpty else {
                showToast("Jeton d'authentification manquant.", isError: true)
                return
            }
            let resolvedEmail = res.viewer?.email ?? trimmed
            let resolvedName = res.viewer?.displayName ?? resolvedEmail
            VemKeychainStore.saveToken(tok, email: resolvedEmail, displayName: resolvedName)
            self.token = tok
            self.workspace = res.workspace
            self.account = res.account
            withAnimation(VemTheme.smoothSpring) {
                self.isAuthenticated = true
            }
            showToast("Bienvenue \(resolvedName.split(separator: " ").first.map(String.init) ?? "") !")
            await loadOrders(silent: true)
        } catch {
            showToast(error.localizedDescription, isError: true)
        }
    }

    public func signInWithWebSSO() async {
        isInitialLoading = true
        defer { isInitialLoading = false }

        do {
            let startURL = await VemAPIClient.shared.ssoStartURL()
            let callbackURL = try await VemWebAuthCoordinator.shared.runWebFlow(startURL: startURL)
            await handleIncomingURL(callbackURL)
        } catch is CancellationError {
            // User closed web sheet voluntarily
        } catch {
            showToast(error.localizedDescription, isError: true)
        }
    }

    public func handleIncomingURL(_ url: URL) async {
        guard url.scheme?.lowercased() == "vipleetmoi" else { return }
        let host = (url.host ?? "").lowercased()
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let q = Dictionary(uniqueKeysWithValues: (comps?.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        switch host {
        case "auth":
            if q["ok"] == "1", let tok = q["token"], !tok.isEmpty {
                let em = q["email"] ?? ""
                let nm = q["name"] ?? em
                VemKeychainStore.saveToken(tok, email: em, displayName: nm)
                self.token = tok
                withAnimation(VemTheme.smoothSpring) {
                    self.isAuthenticated = true
                }
                await refreshAll(silent: false)
                showToast("Connexion Viple Live confirmée !")
            } else {
                showToast("La connexion SSO n'a pas abouti.", isError: true)
            }

        case "paypal":
            let st = q["status"] ?? ""
            if st == "success" {
                await refreshAll(silent: true)
                selectedTab = .billing
                celebrate()
                showToast("Paiement PayPal confirmé ! Votre compte PayPal est associé et votre facture est disponible.")
            } else if st == "cancelled" {
                showToast("Session PayPal annulée — aucun débit effectué.")
            } else {
                showToast(q["msg"] ?? "La validation PayPal n'a pas abouti.", isError: true)
            }

        case "service":
            if let idStr = q["id"], let sid = Int(idStr) {
                selectedTab = .services
                activeServiceDetailID = sid
            }

        default:
            break
        }
    }

    public func signOut() {
        VemKeychainStore.clearToken()
        withAnimation(VemTheme.smoothSpring) {
            self.token = nil
            self.isAuthenticated = false
            self.workspace = nil
            self.account = nil
            self.ordersPayload = nil
            self.activeServiceDetailID = nil
            self.selectedTab = .home
        }
        self.crossAppHint = VemKeychainStore.discoverCrossAppEmailHint()
    }

    // MARK: Workspace & Orders Refresh

    public func refreshAll(silent: Bool = false) async {
        guard let tok = token, !tok.isEmpty else { return }
        if !silent && workspace == nil {
            isInitialLoading = true
        }
        defer { isInitialLoading = false }

        do {
            let boot = try await VemAPIClient.shared.fetchBootstrap(token: tok)
            withAnimation(VemTheme.snappySpring) {
                self.workspace = boot.workspace
                self.account = boot.account
            }
            if ordersPayload == nil {
                await loadOrders(silent: true)
            }
        } catch VemAPIError.unauthorized {
            signOut()
            showToast("Votre session a expiré, veuillez vous reconnecter.", isError: true)
        } catch {
            if !silent {
                showToast(error.localizedDescription, isError: true)
            }
        }
    }

    public func loadOrders(silent: Bool = false) async {
        guard let tok = token, !tok.isEmpty else { return }
        isLoadingOrders = true
        defer { isLoadingOrders = false }
        do {
            let res = try await VemAPIClient.shared.fetchOrdersAndDelivery(token: tok)
            withAnimation(VemTheme.snappySpring) {
                self.ordersPayload = res
            }
        } catch {
            if !silent {
                showToast(error.localizedDescription, isError: true)
            }
        }
    }

    // MARK: Service & Option Mutations

    public func performServiceAction(
        subscription: VemSubscription,
        action: String,
        customNickname: String? = nil,
        assignedMemberId: Int? = nil
    ) async -> Bool {
        guard let tok = token else { return false }

        // Strict Client-Side Guard: Never send server start/stop on non-server subscriptions
        if (action == "start" || action == "stop") && !subscription.isServerService {
            showToast("Ce service fonctionne en continu et ne comporte ni démarrage ni arrêt serveur.", isError: true)
            return false
        }
        if action == "reboot" && !subscription.canReboot {
            showToast("Ce service ne nécessite aucun redémarrage matériel.", isError: true)
            return false
        }

        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.executeServiceAction(
                token: tok,
                subscriptionId: subscription.id,
                action: action,
                customNickname: customNickname,
                assignedMemberId: assignedMemberId
            )
            if action == "cancel" {
                activeServiceDetailID = nil
            }
            await refreshAll(silent: true)
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    public func orderService(productCode: String, assignedMemberId: Int?, customNickname: String?) async -> Bool {
        guard let tok = token else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.orderNewService(
                token: tok,
                productCode: productCode,
                assignedMemberId: assignedMemberId,
                customNickname: customNickname
            )
            orderingProduct = nil
            servicesSegment = 0
            await refreshAll(silent: true)
            celebrate()
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    public func activateOption(subscriptionId: Int, optionCode: String) async -> Bool {
        guard let tok = token else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.purchaseOption(token: tok, subscriptionId: subscriptionId, optionCode: optionCode)
            await refreshAll(silent: true)
            celebrate()
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    public func cancelOption(optionRowId: Int) async {
        guard let tok = token else { return }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.cancelOption(token: tok, optionRowId: optionRowId)
            await refreshAll(silent: true)
            showToast(msg)
        } catch {
            showToast(error.localizedDescription, isError: true)
        }
    }

    public func sendOptionRequestToOwner(subscriptionId: Int, optionCode: String, message: String) async -> Bool {
        guard let tok = token else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.requestOptionFromOwner(
                token: tok,
                subscriptionId: subscriptionId,
                optionCode: optionCode,
                message: message
            )
            await refreshAll(silent: true)
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    public func resolveOptionRequest(requestId: Int, approve: Bool) async {
        guard let tok = token else { return }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.resolveOptionRequest(token: tok, requestId: requestId, approve: approve)
            await refreshAll(silent: true)
            if approve { celebrate() }
            showToast(msg)
        } catch {
            showToast(error.localizedDescription, isError: true)
        }
    }

    // MARK: Family Management

    public func saveFamilyMember(_ member: VemFamilyMember) async -> Bool {
        guard let tok = token else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.upsertFamilyMember(token: tok, member: member)
            await refreshAll(silent: true)
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    public func quickToggleMemberOptionPermission(_ member: VemFamilyMember, allowed: Bool) async {
        var copy = member
        copy.canPurchaseOptions = allowed
        _ = await saveFamilyMember(copy)
    }

    public func removeFamilyMember(_ memberId: Int) async {
        guard let tok = token else { return }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.deleteFamilyMember(token: tok, memberId: memberId)
            if memberFilter == "\(memberId)" { memberFilter = "all" }
            await refreshAll(silent: true)
            showToast(msg)
        } catch {
            showToast(error.localizedDescription, isError: true)
        }
    }

    // MARK: Viple Mail Aliases

    public func manageMailAlias(action: String, alias: String, previousAlias: String? = nil) async -> Bool {
        guard let tok = token else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            let (msg, updatedMail) = try await VemAPIClient.shared.updateMailAlias(
                token: tok,
                action: action,
                alias: alias,
                previousAlias: previousAlias
            )
            if let updatedMail {
                self.workspace?.vipleMail = updatedMail
            }
            await refreshAll(silent: true)
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    // MARK: Billing SEPA & PayPal

    public func saveSepa(
        holder: String,
        iban: String,
        bic: String,
        debitDay: Int,
        address: String,
        postalCode: String,
        city: String
    ) async -> Bool {
        guard let tok = token else { return false }
        if iban.contains("•") {
            showToast("Veuillez saisir votre IBAN complet (FR76...) pour modifier le mandat SEPA.", isError: true)
            return false
        }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.saveSepaMandate(
                token: tok,
                accountHolder: holder,
                iban: iban,
                bic: bic,
                debitDay: debitDay,
                address: address,
                postalCode: postalCode,
                city: city
            )
            await refreshAll(silent: true)
            celebrate()
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    public func startPayPalCheckoutFlow() async {
        guard let tok = token else { return }
        isMutating = true
        do {
            let (_, approveURL, _) = try await VemAPIClient.shared.createPayPalMobileOrder(token: tok)
            isMutating = false
            let callback = try await VemWebAuthCoordinator.shared.runWebFlow(startURL: approveURL)
            await handleIncomingURL(callback)
        } catch is CancellationError {
            isMutating = false
            showToast("Session PayPal fermée — aucun débit effectué.")
        } catch {
            isMutating = false
            showToast(error.localizedDescription, isError: true)
        }
    }

    // MARK: Account Profile, Avatar & Password

    public func saveProfile(
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
    ) async -> Bool {
        guard let tok = token else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.updateAccountProfile(
                token: tok,
                displayName: displayName,
                firstName: firstName,
                lastName: lastName,
                personalMessage: personalMessage,
                colorScheme: colorScheme,
                phoneNumber: phoneNumber,
                bio: bio,
                city: city,
                securityAlerts: securityAlerts,
                newsletter: newsletter
            )
            await refreshAll(silent: true)
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    public func uploadAvatar(croppedBase64Png: String?, presetFile: String?) async -> Bool {
        guard let tok = token else { return false }
        isMutating = true
        defer { isMutating = false }

        do {
            let (msg, _) = try await VemAPIClient.shared.updateAvatar(
                token: tok,
                croppedBase64Png: croppedBase64Png,
                presetFile: presetFile
            )
            await refreshAll(silent: true)
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    public func changePassword(current: String, next: String, confirm: String) async -> Bool {
        guard let tok = token else { return false }
        guard next.count >= 6 else {
            showToast("Le nouveau mot de passe doit contenir au moins 6 caractères.", isError: true)
            return false
        }
        guard next == confirm else {
            showToast("La confirmation du nouveau mot de passe ne correspond pas.", isError: true)
            return false
        }
        isMutating = true
        defer { isMutating = false }

        do {
            let msg = try await VemAPIClient.shared.updatePassword(
                token: tok,
                currentPassword: current,
                newPassword: next,
                confirmPassword: confirm
            )
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription, isError: true)
            return false
        }
    }

    // MARK: Embedded Customer Course (guide-espace-client-v4)

    public func ensureCustomerGuideLoaded() async {
        if customerGuide != nil { return }
        isLoadingGuide = true
        defer { isLoadingGuide = false }
        do {
            let (course, bubbles) = try await VemAPIClient.shared.fetchEmbeddedCustomerGuide()
            self.customerGuide = course
            self.guideBubbles = bubbles
        } catch {
            showToast(error.localizedDescription, isError: true)
        }
    }

    public func markGuidePartRead(_ partID: String) {
        completedGuidePartIDs.insert(partID)
        UserDefaults.standard.set(Array(completedGuidePartIDs), forKey: "vem4.guide.completed_parts")
    }

    public func recordGuideQuizScore(_ pct: Int) {
        if pct > bestGuideQuizScorePct {
            bestGuideQuizScorePct = pct
            UserDefaults.standard.set(pct, forKey: "vem4.guide.best_quiz")
        }
        if pct >= (customerGuide?.passThresholdPct ?? 75) {
            celebrate()
        }
    }
}
