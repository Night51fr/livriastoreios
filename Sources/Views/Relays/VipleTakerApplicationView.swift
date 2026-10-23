import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Page « Devenir Viple Taker » (Point Relais Particulier — 1,00 € / colis remis)

public struct VipleTakerApplicationView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var relayName: String = ""
    @State private var address: String = ""
    @State private var postalCode: String = ""
    @State private var city: String = ""
    @State private var housingType: String = "Maison / Rez-de-chaussée"
    @State private var storageCapacity: String = "15 à 30 colis / semaine"
    @State private var openingHours: String = "Lun-Ven 17h30-20h30 • Sam 09h30-19h00"
    @State private var motivationAndAccessNotes: String = ""
    @State private var supplementaryResponse: String = ""
    @State private var acceptsCharter: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var showingCancelConfirmation: Bool = false
    @State private var isEditingExistingForm: Bool = false

    private let housingOptions = [
        "Maison individuelle avec entrée dédiée",
        "Maison / Rez-de-chaussée",
        "Appartement Rez-de-chaussée",
        "Appartement avec ascenseur",
        "Local / Atelier sécurisé à domicile"
    ]

    private let capacityOptions = [
        "5 à 15 colis / semaine",
        "15 à 30 colis / semaine",
        "30 à 50 colis / semaine",
        "Plus de 50 colis / semaine"
    ]

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroTakerBanner

                howVipleTakerWorksCard

                if let app = store.takerApplication, app.status != "Annulée" {
                    applicationStatusCard(app)
                }

                if store.takerApplication == nil || store.takerApplication?.status == "Annulée" || isEditingExistingForm {
                    applicationFormCard
                }
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Devenir Viple Taker")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            populateFromUserAndExisting()
            await store.fetchTakerApplicationStatus()
            populateFromUserAndExisting()
        }
        .alert("Annuler ma demande Viple Taker ?", isPresented: $showingCancelConfirmation) {
            Button("Conserver ma demande", role: .cancel) {}
            Button("Oui, annuler ma demande", role: .destructive) {
                Task {
                    isSubmitting = true
                    _ = await store.cancelTakerApplication()
                    isSubmitting = false
                }
            }
        } message: {
            Text("Votre demande pour devenir Point Relais Particulier Viple Taker sera annulée. Vous pourrez déposer une nouvelle demande à tout moment.")
        }
    }

    // MARK: - 1. Bannière Hero Viple Taker (1,00 € / colis remis)

    private var heroTakerBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LivriaPalette.gold)
                Text("PROGRAMME VIPLE TAKER PARTICULIER")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.goldSoft)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.16)))

            Text("Devenez Point Relais Particulier Livria & gagnez 1,00 € par colis remis")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Recevez à domicile les colis Livria livrés par Viple Delivery (service interne) ou par UPS, scannez l'étiquette Viple Delivery avec l'application « Looby Taker », puis programmez la remise avec l'acheteur.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))

            HStack(spacing: 10) {
                Label("1,00 € / colis délivré", systemImage: "eurosign.circle.fill")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(LivriaPalette.gold))
                    .foregroundStyle(.black)

                Label("Même gain qu'un relais pro", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .background(
            LivriaMeshHeroBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .shadow(color: LivriaPalette.primary.opacity(0.24), radius: 14, x: 0, y: 6)
    }

    // MARK: - 2. Fonctionnement détaillé (Viple Delivery, UPS, Scan Looby Taker, 1€/colis)

    private var howVipleTakerWorksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundStyle(LivriaPalette.primary)
                Text("Comment fonctionne le rôle de Viple Taker ?")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
            }

            takerStepRow(
                number: "1",
                title: "Réception Viple Delivery & UPS",
                subtitle: "Vous recevez les colis Livria acheminés par notre service interne Viple Delivery ou par UPS. Chaque colis comporte également une étiquette code-barres Viple Delivery dédiée.",
                icon: "truck.box.fill",
                color: LivriaPalette.primary
            )

            takerStepRow(
                number: "2",
                title: "Scan via l'application « Looby Taker »",
                subtitle: "À l'arrivée du colis, vous scannez le code-barres de l'étiquette Viple Delivery depuis l'application Looby Taker pour confirmer instantanément sa réception.",
                icon: "barcode.viewfinder",
                color: LivriaPalette.coral
            )

            takerStepRow(
                number: "3",
                title: "Rendez-vous avec l'acheteur & 1,00 € par colis",
                subtitle: "Vous programmez avec l'acheteur le moment idéal pour lui remettre son colis. Vous gagnez 1,00 € par colis délivré, exactement comme les commerces points relais Viple Taker classiques !",
                icon: "hand.thumbsup.fill",
                color: LivriaPalette.mint
            )
        }
        .livriaCard()
    }

    private func takerStepRow(number: String, title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(number). \(title)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(LivriaPalette.inkMuted)
            }
        }
    }

    // MARK: - 3. Carte « Statut de votre demande » (Envoyée / Vu par Viple / En attente d'éléments / Validé / Refusé + Bouton Annuler)

    private func applicationStatusCard(_ app: LivriaVipleTakerApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STATUT DE VOTRE DEMANDE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.primary)
                    Text(app.relayName)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }
                Spacer()
                Text(app.reference)
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
                    .foregroundStyle(LivriaPalette.primaryDeep)
            }

            // Badge de statut principal
            HStack(spacing: 10) {
                Image(systemName: statusIcon(for: app.status))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(statusColor(for: app.status))

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.status)
                        .font(.system(size: 15.5, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor(for: app.status))
                    Text(statusExplanation(for: app.status))
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(statusColor(for: app.status).opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(statusColor(for: app.status).opacity(0.35), lineWidth: 1.2)
            )

            // Progression visuelle des étapes de traitement Viple
            VStack(alignment: .leading, spacing: 8) {
                statusTimelineStep(label: "Envoyée", currentStatus: app.status)
                statusTimelineStep(label: "Vu par Viple, en cours de traitement", currentStatus: app.status)
                if app.status == "En attente d'éléments supplémentaires" || !(app.requestedAdditionalInfo ?? "").isEmpty {
                    statusTimelineStep(label: "En attente d'éléments supplémentaires", currentStatus: app.status)
                }
                if app.status == "Refusé" {
                    statusTimelineStep(label: "Refusé", currentStatus: app.status)
                } else {
                    statusTimelineStep(label: "Validé", currentStatus: app.status)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.background))

            // Si Viple demande des éléments supplémentaires : encadré + champ de réponse directe
            if app.status == "En attente d'éléments supplémentaires" || !(app.requestedAdditionalInfo ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .foregroundStyle(.orange)
                        Text("Éléments supplémentaires demandés par Viple :")
                            .font(.system(size: 13.5, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                    }

                    Text((app.requestedAdditionalInfo ?? "").isEmpty
                         ? "Merci de préciser vos horaires de présence et les instructions d'accès pour le livreur Viple Delivery / UPS."
                         : (app.requestedAdditionalInfo ?? ""))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.65, green: 0.32, blue: 0.02))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.goldSoft))

                    TextField("Votre réponse / éléments complémentaires pour Viple...", text: $supplementaryResponse, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LivriaPalette.border, lineWidth: 1))

                    Button {
                        Task {
                            isSubmitting = true
                            _ = await store.submitTakerApplication(
                                firstName: firstName.isEmpty ? app.firstName : firstName,
                                lastName: lastName.isEmpty ? app.lastName : lastName,
                                phone: phone.isEmpty ? app.phone : phone,
                                relayName: relayName.isEmpty ? app.relayName : relayName,
                                address: address.isEmpty ? app.address : address,
                                postalCode: postalCode.isEmpty ? app.postalCode : postalCode,
                                city: city.isEmpty ? app.city : city,
                                housingType: housingType,
                                storageCapacity: storageCapacity,
                                openingHours: openingHours.isEmpty ? app.openingHours : openingHours,
                                motivationAndAccessNotes: motivationAndAccessNotes.isEmpty ? app.motivationAndAccessNotes : motivationAndAccessNotes,
                                supplementaryResponse: supplementaryResponse
                            )
                            isSubmitting = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Envoyer ces éléments supplémentaires à Viple")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                        .foregroundStyle(.white)
                    }
                    .disabled(supplementaryResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(LivriaPalette.goldSoft.opacity(0.45)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(LivriaPalette.gold, lineWidth: 1))
            }

            // Boutons Modifier / Annuler ma demande si besoin
            HStack(spacing: 10) {
                Button {
                    withAnimation {
                        isEditingExistingForm.toggle()
                    }
                } label: {
                    Label(isEditingExistingForm ? "Masquer le formulaire" : "Modifier mes infos", systemImage: "pencil")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primarySoft))
                        .foregroundStyle(LivriaPalette.primaryDeep)
                }

                Button(role: .destructive) {
                    showingCancelConfirmation = true
                } label: {
                    Label("Annuler ma demande", systemImage: "xmark.circle.fill")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.12)))
                        .foregroundStyle(.red)
                }
            }
        }
        .livriaCard()
    }

    private func statusTimelineStep(label: String, currentStatus: String) -> some View {
        let isCurrent = currentStatus.localizedCaseInsensitiveCompare(label) == .orderedSame
        let isCompleted = isStepCompleted(step: label, current: currentStatus)
        return HStack(spacing: 10) {
            Image(systemName: isCurrent ? "largecircle.fill.circle" : (isCompleted ? "checkmark.circle.fill" : "circle"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isCurrent ? LivriaPalette.primary : (isCompleted ? LivriaPalette.mint : LivriaPalette.inkMuted.opacity(0.45)))
            Text(label)
                .font(.system(size: 13, weight: isCurrent ? .black : (isCompleted ? .bold : .medium), design: .rounded))
                .foregroundStyle(isCurrent ? LivriaPalette.ink : (isCompleted ? LivriaPalette.ink.opacity(0.85) : LivriaPalette.inkMuted))
            Spacer()
            if isCurrent {
                Text("En cours")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
                    .foregroundStyle(LivriaPalette.primaryDeep)
            }
        }
    }

    private func isStepCompleted(step: String, current: String) -> Bool {
        let order = [
            "Envoyée": 1,
            "Vu par Viple, en cours de traitement": 2,
            "En attente d'éléments supplémentaires": 3,
            "Validé": 4,
            "Refusé": 4
        ]
        guard let stepIdx = order[step], let currIdx = order[current] else { return false }
        return currIdx > stepIdx
    }

    private func statusIcon(for status: String) -> String {
        switch status {
        case "Validé": return "checkmark.seal.fill"
        case "Vu par Viple, en cours de traitement": return "eye.circle.fill"
        case "En attente d'éléments supplémentaires": return "exclamationmark.triangle.fill"
        case "Refusé": return "xmark.octagon.fill"
        default: return "paperplane.circle.fill"
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "Validé": return LivriaPalette.mint
        case "Vu par Viple, en cours de traitement": return LivriaPalette.primary
        case "En attente d'éléments supplémentaires": return .orange
        case "Refusé": return .red
        default: return LivriaPalette.primaryDeep
        }
    }

    private func statusExplanation(for status: String) -> String {
        switch status {
        case "Envoyée":
            return "Votre demande a bien été transmise à l'espace /admin de Livria. Notre équipe va l'examiner rapidement."
        case "Vu par Viple, en cours de traitement":
            return "L'équipe Viple a consulté votre dossier et vérifie actuellement vos informations de point relais particulier."
        case "En attente d'éléments supplémentaires":
            return "Nous avons besoin d'une précision complémentaire ci-dessous pour valider votre Point Relais Viple Taker."
        case "Validé":
            return "Félicitations ! Votre Point Relais Viple Taker est actif et affiché dans Points Relais sur Livria Store et Livria Marketplace (1,00 €/colis)."
        case "Refusé":
            return "Votre candidature n'a pas pu être retenue pour le moment. Vous pouvez mettre à jour votre dossier et postuler à nouveau."
        default:
            return "Suivi en direct de votre candidature Viple Taker."
        }
    }

    // MARK: - 4. Formulaire Complet de Candidature Viple Taker

    private var applicationFormCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.takerApplication == nil ? "Formulaire d'inscription Viple Taker" : "Mettre à jour ma candidature Viple Taker")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            Text("Remplissez ce formulaire pour proposer votre domicile comme Point Relais Particulier. Dès validation dans l'espace /admin de Livria, votre relais apparaîtra sur la carte des Points Relais.")
                .font(.system(size: 12.5))
                .foregroundStyle(LivriaPalette.inkMuted)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prénom")
                        .font(.system(size: 12, weight: .bold))
                    TextField("Prénom", text: $firstName)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nom")
                        .font(.system(size: 12, weight: .bold))
                    TextField("Nom", text: $lastName)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Téléphone mobile (pour les livreurs Viple Delivery / UPS & acheteurs)")
                    .font(.system(size: 12, weight: .bold))
                TextField("06 12 34 56 78", text: $phone)
                    .keyboardType(.phonePad)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Nom affiché de votre Point Relais Viple Taker")
                    .font(.system(size: 12, weight: .bold))
                TextField("Ex: Viple Taker — Chez Thomas (Quartier Centre)", text: $relayName)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Adresse postale complète de réception des colis")
                    .font(.system(size: 12, weight: .bold))
                TextField("Numéro et rue", text: $address)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Code postal")
                        .font(.system(size: 12, weight: .bold))
                    TextField("75001", text: $postalCode)
                        .frame(width: 110)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ville")
                        .font(.system(size: 12, weight: .bold))
                    TextField("Ville", text: $city)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Type de logement / accès")
                    .font(.system(size: 12, weight: .bold))
                Picker("Logement", selection: $housingType) {
                    ForEach(housingOptions, id: \.self) { opt in
                        Text(opt).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Capacité d'accueil hebdomadaire")
                    .font(.system(size: 12, weight: .bold))
                Picker("Capacité", selection: $storageCapacity) {
                    ForEach(capacityOptions, id: \.self) { opt in
                        Text(opt).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Créneaux habituels de remise aux acheteurs")
                    .font(.system(size: 12, weight: .bold))
                TextField("Ex: Lun-Ven 17h30-20h30 • Sam 09h30-19h00", text: $openingHours)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Précisions d'accès (digicode, interphone, lieu de stockage sec)")
                    .font(.system(size: 12, weight: .bold))
                TextField("Indiquez vos disponibilités et les instructions utiles...", text: $motivationAndAccessNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            Toggle(isOn: $acceptsCharter) {
                Text("J'accepte de réceptionner les colis Viple Delivery et UPS, de scanner l'étiquette Viple Delivery via l'appli « Looby Taker » à réception, et de convenir du rendez-vous de remise avec l'acheteur (rémunération de 1,00 € par colis remis).")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(LivriaPalette.ink)
            }
            .tint(LivriaPalette.primary)

            Button {
                Task {
                    isSubmitting = true
                    let ok = await store.submitTakerApplication(
                        firstName: firstName,
                        lastName: lastName,
                        phone: phone,
                        relayName: relayName,
                        address: address,
                        postalCode: postalCode,
                        city: city,
                        housingType: housingType,
                        storageCapacity: storageCapacity,
                        openingHours: openingHours,
                        motivationAndAccessNotes: motivationAndAccessNotes,
                        supplementaryResponse: supplementaryResponse
                    )
                    isSubmitting = false
                    if ok {
                        isEditingExistingForm = false
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text("Envoyer ma demande Viple Taker (1,00 € / colis)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [LivriaPalette.primary, LivriaPalette.coral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!acceptsCharter || address.trimmingCharacters(in: .whitespaces).isEmpty || city.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
        }
        .livriaCard()
    }

    private func populateFromUserAndExisting() {
        if let app = store.takerApplication {
            firstName = app.firstName
            lastName = app.lastName
            phone = app.phone
            relayName = app.relayName
            address = app.address
            postalCode = app.postalCode
            city = app.city
            housingType = app.housingType
            storageCapacity = app.storageCapacity
            openingHours = app.openingHours
            motivationAndAccessNotes = app.motivationAndAccessNotes
            supplementaryResponse = app.applicantSupplementaryResponse ?? ""
            return
        }
        guard let u = store.currentUser else { return }
        if firstName.isEmpty { firstName = u.firstName }
        if lastName.isEmpty { lastName = u.lastName }
        if phone.isEmpty { phone = u.phone }
        if address.isEmpty { address = u.address }
        if postalCode.isEmpty { postalCode = u.postalCode }
        if city.isEmpty { city = u.city }
        if relayName.isEmpty && !u.displayName.isEmpty {
            relayName = "Viple Taker — Chez \(u.displayName)"
        }
    }
}

// MARK: - Studio d'Upload & Recadrage Interactif de Photo de Profil (Zoom, Déplacement & Recadrage Carré/Circulaire)

#if canImport(UIKit)
public struct LivriaAvatarCropperSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let sourceImage: UIImage
    public let onCropped: (Data) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 280

    public init(sourceImage: UIImage, onCropped: @escaping (Data) -> Void) {
        self.sourceImage = sourceImage
        self.onCropped = onCropped
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Text("Déplacez et zoomez votre photo avec deux doigts pour la recadrer parfaitement")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                ZStack {
                    Color.black.opacity(0.88)
                        .frame(width: cropSize + 44, height: cropSize + 44)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSize, height: cropSize)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [LivriaPalette.primary, LivriaPalette.coral, LivriaPalette.gold],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3.5
                                )
                        )
                        .contentShape(Rectangle())
                        .gesture(
                            SimultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    },
                                MagnificationGesture()
                                    .onChanged { value in
                                        let next = lastScale * value
                                        scale = min(max(next, 1.0), 4.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    }
                            )
                        )
                }

                // Contrôle de zoom par curseur en complément du pincement
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundStyle(LivriaPalette.inkMuted)
                        Slider(value: $scale, in: 1.0...4.0) { _ in
                            lastScale = scale
                        }
                        .tint(LivriaPalette.primary)
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundStyle(LivriaPalette.primary)
                    }
                    .padding(.horizontal, 28)

                    Button("Réinitialiser le cadrage") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(LivriaPalette.primary)
                }

                Spacer()

                Button {
                    if let data = renderCroppedJPEG() {
                        onCropped(data)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crop")
                        Text("Valider et enregistrer ma photo recadrée")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [LivriaPalette.primary, LivriaPalette.coral],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(LivriaPalette.background.ignoresSafeArea())
            .navigationTitle("Recadrer ma photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func renderCroppedJPEG() -> Data? {
        let outputDimension: CGFloat = 512
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputDimension, height: outputDimension), format: rendererFormat)

        let ratio = outputDimension / cropSize
        let renderedImage = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: outputDimension, height: outputDimension)
            UIBezierPath(ovalIn: rect).addClip()

            let imgSize = sourceImage.size
            let aspect = max(outputDimension / max(imgSize.width, 1), outputDimension / max(imgSize.height, 1))
            let baseWidth = imgSize.width * aspect * scale
            let baseHeight = imgSize.height * aspect * scale

            let drawX = (outputDimension - baseWidth) / 2.0 + (offset.width * ratio)
            let drawY = (outputDimension - baseHeight) / 2.0 + (offset.height * ratio)
            sourceImage.draw(in: CGRect(x: drawX, y: drawY, width: baseWidth, height: baseHeight))
        }
        return renderedImage.jpegData(compressionQuality: 0.86)
    }
}
#endif
