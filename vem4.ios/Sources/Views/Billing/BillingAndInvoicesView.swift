import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// MARK: - Tab 4: Facturation SEPA (5 / 10 / 15), PayPal & Factures Certifiées 2D-DOC

public struct BillingAndInvoicesView: View {
    @Bindable var store: VemStoreViewModel

    @State private var holderInput: String = ""
    @State private var ibanInput: String = ""
    @State private var bicInput: String = ""
    @State private var selectedDebitDay: Int = 10
    @State private var addressInput: String = ""
    @State private var postalCodeInput: String = ""
    @State private var cityInput: String = ""
    @State private var didHydrateForm: Bool = false

    private let allowedDebitDays: [Int] = [5, 10, 15]

    public init(store: VemStoreViewModel) {
        self.store = store
    }

    private var profile: VemBillingProfile? {
        store.workspace?.billing.profile
    }

    private var invoices: [VemInvoice] {
        store.workspace?.billing.invoices ?? []
    }

    private var canEditBilling: Bool {
        store.workspace?.rights.canEditBilling ?? true
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Interactive 3D Household Billing Card
                VemInteractive3DCard {
                    VemAuroraBackgroundCard(cornerRadius: 26) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("PORTEFEUILLE & MANDAT DU FOYER")
                                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                                    .tracking(1.0)
                                    .foregroundStyle(Color.white.opacity(0.78))
                                Spacer()
                                Image(systemName: "wave.3.right.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.white.opacity(0.85))
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(VemFormat.euros(store.workspace?.summary.monthlyTotalTtc ?? 0))
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("TTC / mois")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.84))
                            }

                            if let p = profile, p.sepaActive {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("IBAN : \(p.sepaIbanMasked) · Jour de prélèvement : le \(p.sepaDebitDay) du mois")
                                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.68, green: 0.98, blue: 0.86))
                                    Text("RUM : \(p.sepaMandateRum)")
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.75))
                                }
                            } else if let p = profile, p.payPalActive {
                                Label("PayPal actif : \(p.payPalEmail ?? "Compte vérifié")", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(red: 0.68, green: 0.98, blue: 0.86))
                            } else {
                                Text("Configurez votre RIB SEPA (prélèvement le 5, 10 ou 15) ou associez PayPal ci-dessous.")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Color.white.opacity(0.86))
                            }
                        }
                        .padding(22)
                    }
                }

                // 2. SEPA Direct Debit Form (Choice of Debit Day: 5, 10, or 15)
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prélèvement Automatique SEPA")
                                .font(.system(size: 17.5, weight: .heavy, design: .rounded))
                            Text("Enregistrez votre RIB et choisissez librement votre date d'échéance.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if profile?.sepaActive == true {
                            VemStatusPill("Mandat actif", tone: .emerald, icon: "checkmark.seal.fill")
                        }
                    }

                    // Tactile 5 / 10 / 15 Day Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JOUR DE PRÉLÈVEMENT SOUHAITÉ")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            ForEach(allowedDebitDays, id: \.self) { day in
                                let isChosen = selectedDebitDay == day
                                Button {
                                    VemHaptics.selection()
                                    withAnimation(VemTheme.snappySpring) {
                                        selectedDebitDay = day
                                    }
                                } label: {
                                    VStack(spacing: 3) {
                                        Text("Le \(day)")
                                            .font(.system(size: 18, weight: .black, design: .rounded))
                                        Text("du mois")
                                            .font(.system(size: 11.5, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(isChosen ? .white : .primary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .fill(isChosen ? AnyShapeStyle(VemTheme.vibrantActionGradient) : AnyShapeStyle(VemTheme.elevatedSurface))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .strokeBorder(isChosen ? Color.clear : VemTheme.subtleBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(VemPressableButtonStyle())
                                .disabled(!canEditBilling)
                            }
                        }
                    }

                    VemLabeledField(label: "Titulaire du compte bancaire", placeholder: "Prénom Nom", text: $holderInput)
                    VemLabeledField(
                        label: "IBAN (saisir l'IBAN complet FR76…)",
                        placeholder: profile?.sepaIbanMasked.isEmpty == false ? "Actuel : \(profile!.sepaIbanMasked)" : "FR76 3000 4000 …",
                        text: $ibanInput,
                        monospaced: true,
                        autocap: .characters
                    )
                    VemLabeledField(label: "Code BIC / SWIFT", placeholder: "BNPAFRPPXXX", text: $bicInput, monospaced: true, autocap: .characters)
                    VemLabeledField(label: "Adresse postale de facturation", placeholder: "12 rue de la République", text: $addressInput)

                    HStack(spacing: 10) {
                        VemLabeledField(label: "Code postal", placeholder: "75001", text: $postalCodeInput)
                            .frame(width: 120)
                        VemLabeledField(label: "Ville", placeholder: "Paris", text: $cityInput)
                    }

                    if canEditBilling {
                        Button {
                            VemHaptics.impact(.medium)
                            Task {
                                let ok = await store.saveSepa(
                                    holder: holderInput,
                                    iban: ibanInput,
                                    bic: bicInput,
                                    debitDay: selectedDebitDay,
                                    address: addressInput,
                                    postalCode: postalCodeInput,
                                    city: cityInput
                                )
                                if ok { ibanInput = "" }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "signature")
                                Text("Signer & Enregistrer le mandat SEPA (le \(selectedDebitDay))")
                            }
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(VemTheme.vibrantActionGradient))
                        }
                        .buttonStyle(VemPressableButtonStyle())
                        .disabled(store.isMutating)
                    }
                }
                .vemCard()

                // 3. PayPal Express Integration (Same API as Livria Store)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paiement & Liaison PayPal")
                                .font(.system(size: 17.5, weight: .heavy, design: .rounded))
                            Text("Réglez votre échéance en cours ou associez votre portefeuille PayPal officiel.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if profile?.payPalActive == true {
                            VemStatusPill("Associé", tone: .sky, icon: "checkmark.circle.fill")
                        }
                    }

                    if let email = profile?.payPalEmail, !email.isEmpty {
                        Text("Compte PayPal lié : \(email)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VemTheme.payPalBlue)
                    }

                    if canEditBilling {
                        Button {
                            VemHaptics.impact(.medium)
                            Task { await store.startPayPalCheckoutFlow() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "creditcard.circle.fill")
                                    .font(.system(size: 18))
                                Text(profile?.payPalActive == true ? "Régler une échéance avec PayPal" : "Associer & Payer avec PayPal")
                            }
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(VemTheme.payPalBlue)
                            )
                        }
                        .buttonStyle(VemPressableButtonStyle())
                        .disabled(store.isMutating)
                    }
                }
                .vemCard()

                // 4. Certified 2D-DOC Invoices List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Factures Certifiées 2D-DOC (\(invoices.count))")
                                .font(.system(size: 17.5, weight: .heavy, design: .rounded))
                            Text("Chaque facture Viple comporte un sceau cryptographique souverain VP01 vérifiable.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    if invoices.isEmpty {
                        Text("Aucune facture émise pour le moment.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(invoices) { inv in
                            Button {
                                VemHaptics.selection()
                                store.selectedInvoiceForDetail = inv
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(VemTheme.vipleMint.opacity(0.14))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: "qrcode.viewfinder")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundStyle(VemTheme.vipleEmerald)
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(inv.invoiceNumber)
                                                .font(.system(size: 13.5, weight: .heavy, design: .monospaced))
                                                .foregroundStyle(.primary)
                                            VemStatusPill(inv.status, tone: .emerald)
                                        }
                                        Text(inv.label)
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Text("\(inv.periodLabel) · \(inv.paymentMethod)")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(VemFormat.euros(inv.amountTtc))
                                            .font(.system(size: 15, weight: .black, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text("2D-DOC →")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(VemTheme.electricIndigo)
                                    }
                                }
                                .padding(13)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VemTheme.elevatedSurface))
                            }
                            .buttonStyle(VemPressableButtonStyle())
                        }
                    }
                }
                .vemCard()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(VemTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Facturation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hydrateFromWorkspaceIfNeeded()
        }
        .onChange(of: store.workspace?.billing.profile?.sepaMandateRum) { _, _ in
            hydrateFromWorkspaceIfNeeded(force: true)
        }
        .refreshable {
            await store.refreshAll(silent: false)
        }
    }

    private func hydrateFromWorkspaceIfNeeded(force: Bool = false) {
        guard !didHydrateForm || force else { return }
        guard let p = profile else { return }
        didHydrateForm = true
        holderInput = p.sepaAccountHolder.isEmpty ? (store.workspace?.viewer.displayName ?? "") : p.sepaAccountHolder
        bicInput = p.sepaBic
        selectedDebitDay = [5, 10, 15].contains(p.sepaDebitDay) ? p.sepaDebitDay : 10
        addressInput = p.billingAddress
        postalCodeInput = p.billingPostalCode
        cityInput = p.billingCity
    }
}

private struct VemLabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var monospaced: Bool = false
    var autocap: TextInputAutocapitalization = .words

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
                .font(monospaced ? .system(size: 13.5, design: .monospaced) : .system(size: 14))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(VemTheme.subtleBorder, lineWidth: 1))
        }
    }
}

// MARK: - Certified Invoice & Sovereign 2D-DOC (ANTS DC04 · VP01) Inspector Sheet

public struct CertifiedInvoiceSheet: View {
    @Bindable var store: VemStoreViewModel
    public let invoice: VemInvoice

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var detail: VemInvoiceDetailResponse?
    @State private var isLoading: Bool = true
    @State private var errorText: String?
    @State private var showRawPayload: Bool = false

    public init(store: VemStoreViewModel, invoice: VemInvoice) {
        self.store = store
        self.invoice = invoice
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Génération et vérification du sceau 2D-DOC VP01…")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .vemCard()
                    } else if let errorText {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(VemTheme.warmCoral)
                            Text(errorText)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .vemCard()
                    } else if let detail {
                        invoiceSummaryCard(detail.invoice)
                        sovereign2DDocCard(detail.seal)

                        Button {
                            Task {
                                let url = await VemAPIClient.shared.printableInvoiceURL(invoiceId: invoice.id, token: store.token)
                                openURL(url)
                            }
                        } label: {
                            Label("Ouvrir la facture officielle imprimable (PDF / A4)", systemImage: "printer.fill")
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(VemTheme.vibrantActionGradient))
                        }
                        .buttonStyle(VemPressableButtonStyle())
                    }
                }
                .padding(16)
            }
            .background(VemTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(invoice.invoiceNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .task {
                await loadDetail()
            }
        }
    }

    @ViewBuilder
    private func invoiceSummaryCard(_ inv: VemPrintableInvoiceDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("FACTURE ACQUITTÉE VIPLE / CENELIS")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(VemTheme.vipleEmerald)
                    Text(inv.invoiceNumber)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                }
                Spacer()
                VemStatusPill(inv.status, tone: .emerald, icon: "checkmark.seal.fill")
            }

            Text(inv.label)
                .font(.system(size: 14, weight: .semibold))
            Text("Période : \(inv.periodLabel) · Règlement : \(inv.paymentMethod)")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            if !inv.holder.isEmpty {
                Text("Titulaire : \(inv.holder)\(inv.city.isEmpty ? "" : " — \(inv.postalCode) \(inv.city)")")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("Montant HT")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(VemFormat.euros(inv.amountHt))
                    .font(.system(size: 13.5, weight: .semibold))
            }
            HStack {
                Text("TVA (20,0 %)")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(VemFormat.euros(inv.tva))
                    .font(.system(size: 13.5, weight: .semibold))
            }
            HStack {
                Text("Total TTC")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Spacer()
                Text(VemFormat.euros(inv.amountTtc))
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(VemTheme.vipleEmerald)
            }
        }
        .vemCard()
    }

    @ViewBuilder
    private func sovereign2DDocCard(_ seal: Vem2DDocSeal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(VemTheme.vipleEmerald)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cachet Électronique Visible 2D-DOC")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text("\(seal.authority) · \(seal.algorithm)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if seal.hasSeal, !seal.payloadRaw.isEmpty {
                HStack {
                    Spacer()
                    if let qrImg = generateMatrixImage(from: seal.payloadRaw) {
                        Image(uiImage: qrImg)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 190, height: 190)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(VemTheme.vipleEmerald.opacity(0.25), lineWidth: 1.5)
                            )
                    }
                    Spacer()
                }

                DisclosureGroup("Inspecter la trame signée DC04 (\(seal.docReference))", isExpanded: $showRawPayload) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(seal.payloadRaw)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Button {
                            UIPasteboard.general.string = seal.payloadRaw
                            store.showToast("Trame 2D-DOC copiée dans le presse-papiers.")
                        } label: {
                            Label("Copier la trame brute", systemImage: "doc.on.doc")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))

                if let verifyURL = URL(string: seal.verifyUrl) {
                    Button {
                        openURL(verifyURL)
                    } label: {
                        Label("Vérifier ce 2D-DOC sur 2d-doc.cenelis.com", systemImage: "checkmark.seal.text.page.fill")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VemTheme.electricIndigo)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11.5)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(VemTheme.electricIndigo.opacity(0.12))
                            )
                    }
                    .buttonStyle(VemPressableButtonStyle())
                }
            } else {
                Text("Ce justificatif est archivé dans votre coffre-fort Viple.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
        }
        .vemCard()
    }

    private func loadDetail() async {
        guard let tok = store.token else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            self.detail = try await VemAPIClient.shared.fetchInvoiceDetail(token: tok, invoiceId: invoice.id)
        } catch {
            self.errorText = error.localizedDescription
        }
    }

    private func generateMatrixImage(from payload: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
