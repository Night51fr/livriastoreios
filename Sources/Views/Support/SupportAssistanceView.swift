import SwiftUI

// MARK: - Service Client & Assistance Livria Store (SupportAssistanceView)

public struct SupportAssistanceView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    @State private var showingCreateTicketSheet: Bool = false
    @State private var activeTicket: LivriaSupportTicket? = nil

    @State private var newSubject: String = ""
    @State private var newCategory: String = "Commande & Livraison"
    @State private var newBody: String = ""

    private let categories = [
        "Commande & Livraison",
        "Abonnement Looby+",
        "Mon Compte",
        "Boutique & Catalogue",
        "Troc & Points Relais",
        "Autre demande"
    ]

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                vipleAssistanceSyncHeader

                HStack {
                    Text("Mes Demandes d'Assistance (\(store.supportTickets.count))")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Spacer()
                    Button {
                        showingCreateTicketSheet = true
                    } label: {
                        Label("Nous contacter", systemImage: "plus.bubble.fill")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(LivriaPalette.primary))
                            .foregroundStyle(.white)
                    }
                }

                if store.supportTickets.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "lifepreserver.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(LivriaPalette.primary)
                        Text("Aucune demande en cours")
                            .font(.system(size: 16, weight: .bold))
                        Text("Besoin d'aide concernant une commande, la livraison d'un colis ou votre abonnement Looby+ ? Envoyez-nous un message et notre équipe vous répondra rapidement.")
                            .font(.system(size: 13))
                            .foregroundStyle(LivriaPalette.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .livriaCard(padding: 24)
                } else {
                    ForEach(store.supportTickets) { ticket in
                        Button {
                            activeTicket = ticket
                        } label: {
                            ticketRowCard(ticket: ticket)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Service Client")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refreshBootstrap()
        }
        .sheet(isPresented: $showingCreateTicketSheet) {
            createTicketSheet
        }
        .sheet(item: $activeTicket) { ticket in
            SupportTicketDetailSheet(initialTicket: ticket)
        }
    }

    private var vipleAssistanceSyncHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                    .font(.title2)
                    .foregroundStyle(LivriaPalette.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Service Client à votre écoute")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Une question sur un livre, un colis ou votre abonnement ? Nous sommes là pour vous aider.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LivriaPalette.heroGradient))
    }

    private func ticketRowCard(ticket: LivriaSupportTicket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ticket.reference)
                    .font(.system(size: 12.5, weight: .black, design: .monospaced))
                    .foregroundStyle(LivriaPalette.primary)
                Text("• \(ticket.category)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivriaPalette.inkMuted)
                Spacer()
                Text(ticket.status)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
                    .foregroundStyle(LivriaPalette.primaryDeep)
            }

            Text(ticket.title)
                .font(.system(size: 15.5, weight: .bold))
                .foregroundStyle(LivriaPalette.ink)

            if let last = ticket.lastMessage, !last.isEmpty {
                Text(last)
                    .font(.system(size: 13))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .lineLimit(2)
            }

            HStack {
                Label("\(ticket.messageCount) message(s)", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(size: 11.5))
                    .foregroundStyle(LivriaPalette.inkMuted)
                Spacer()
                Text("Mis à jour le \(ticket.updatedAt)")
                    .font(.system(size: 11))
                    .foregroundStyle(LivriaPalette.inkMuted)
            }
        }
        .livriaCard()
    }

    private var createTicketSheet: some View {
        NavigationStack {
            Form {
                Section("Nouveau Ticket Viple Assistance") {
                    TextField("Objet de votre demande", text: $newSubject)
                    Picker("Catégorie", selection: $newCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    TextField("Décrivez votre besoin en détail...", text: $newBody, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .scrollContentBackground(.hidden)
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Ouvrir un Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { showingCreateTicketSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Envoyer") {
                        let s = newSubject
                        let c = newCategory
                        let b = newBody
                        Task {
                            let ok = await store.createSupportTicket(subject: s, category: c, body: b)
                            if ok {
                                newSubject = ""
                                newBody = ""
                                showingCreateTicketSheet = false
                            }
                        }
                    }
                    .disabled(newSubject.trimmingCharacters(in: .whitespaces).isEmpty || newBody.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

public struct SupportTicketDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel
    public let initialTicket: LivriaSupportTicket

    @State private var ticket: LivriaSupportTicket? = nil
    @State private var replyText: String = ""

    public var body: some View {
        let current = ticket ?? initialTicket
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(current.reference)
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundStyle(LivriaPalette.primary)
                                Spacer()
                                Text(current.status)
                                    .font(.system(size: 11.5, weight: .bold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(LivriaPalette.primarySoft))
                            }
                            Text(current.title)
                                .font(.system(size: 17, weight: .bold))
                            Text("Catégorie : \(current.category) • Synchronisé sur assistance.viplenetwork.com")
                                .font(.system(size: 12))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                        .livriaCard()

                        ForEach(current.messages ?? []) { msg in
                            HStack {
                                if !msg.isStaff { Spacer() }
                                VStack(alignment: msg.isStaff ? .leading : .trailing, spacing: 4) {
                                    HStack(spacing: 6) {
                                        if msg.isStaff {
                                            Image(systemName: "checkmark.shield.fill")
                                                .foregroundStyle(LivriaPalette.gold)
                                        }
                                        Text(msg.isStaff ? "\(msg.authorName) (Support Viple)" : msg.authorName)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(LivriaPalette.inkMuted)
                                    }
                                    Text(msg.body)
                                        .font(.system(size: 14))
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(msg.isStaff ? LivriaPalette.cardPaper : LivriaPalette.primary)
                                        )
                                        .foregroundStyle(msg.isStaff ? LivriaPalette.ink : .white)
                                    Text(msg.sentAt)
                                        .font(.system(size: 10))
                                        .foregroundStyle(LivriaPalette.inkMuted)
                                }
                                if msg.isStaff { Spacer() }
                            }
                        }
                    }
                    .padding(16)
                }

                HStack(spacing: 10) {
                    TextField("Répondre au support Viple...", text: $replyText)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
                    Button {
                        let txt = replyText
                        replyText = ""
                        Task {
                            let ok = await store.replyToSupportTicket(ticketId: current.id, body: txt)
                            if ok {
                                ticket = await store.fetchSupportTicketDetail(ticketId: current.id)
                            }
                        }
                    } label: {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(LivriaPalette.primary)
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12)
                .background(LivriaPalette.cardPaper)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle(current.reference)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task {
                if let detail = await store.fetchSupportTicketDetail(ticketId: initialTicket.id) {
                    self.ticket = detail
                }
            }
        }
    }
}
