import SwiftUI

// MARK: - Tab 3: Ma Famille, Délégation Viple Live & Contrôle des Options

public struct FamilyHouseholdView: View {
    @Bindable var store: VemStoreViewModel

    @State private var editingMember: VemFamilyMember?
    @State private var showCreateMemberSheet: Bool = false
    @State private var memberPendingDeletion: VemFamilyMember?

    public init(store: VemStoreViewModel) {
        self.store = store
    }

    private var members: [VemFamilyMember] {
        store.workspace?.familyMembers ?? []
    }

    private var canManageFamily: Bool {
        store.workspace?.rights.canManageFamily ?? true
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Hero Card
                VemAuroraBackgroundCard(cornerRadius: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.3.sequence.fill")
                                .foregroundStyle(VemTheme.vipleMint)
                            Text("GESTION FAMILIALE & CONTRÔLE PARENTAL")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(0.9)
                                .foregroundStyle(Color.white.opacity(0.84))
                        }

                        Text("Partagez vos services avec vos proches en toute sérénité")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Renseignez l'adresse e-mail Viple Live de votre enfant ou conjoint (ex. Hugo) : il pilote son VPS ou forfait depuis son propre téléphone, tandis que vous gardez la main sur l'achat d'options et la résiliation.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .lineSpacing(2)

                        if canManageFamily {
                            Button {
                                VemHaptics.impact(.medium)
                                showCreateMemberSheet = true
                            } label: {
                                Label("Ajouter un membre au foyer", systemImage: "person.badge.plus")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(VemTheme.vipleEmerald)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .background(Capsule().fill(Color.white))
                            }
                            .buttonStyle(VemPressableButtonStyle())
                            .padding(.top, 2)
                        }
                    }
                    .padding(20)
                }

                // Pending Option Approval Requests (e.g., Hugo asking for an option)
                if let reqs = store.workspace?.optionRequests, !reqs.isEmpty {
                    VemOptionRequestsBannerView(store: store, requests: reqs)
                }

                // Household Members List
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Membres du foyer (\(members.count))")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Spacer()
                    }

                    ForEach(members) { member in
                        FamilyMemberCard(
                            store: store,
                            member: member,
                            canManage: canManageFamily,
                            onEdit: {
                                editingMember = member
                            },
                            onDelete: {
                                memberPendingDeletion = member
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(VemTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Ma Famille")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canManageFamily {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateMemberSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(VemTheme.vipleEmerald)
                    }
                }
            }
        }
        .refreshable {
            await store.refreshAll(silent: false)
        }
        .sheet(isPresented: $showCreateMemberSheet) {
            FamilyMemberEditorSheet(
                store: store,
                initialMember: VemFamilyMember(
                    id: 0,
                    firstName: "",
                    relationship: "Fils",
                    linkedVipleEmail: "",
                    avatarColor: "#4F46E5",
                    canAccessServices: true,
                    canPurchaseOptions: false,
                    canCancelServices: false,
                    isPrimaryOwner: false
                )
            )
        }
        .sheet(item: $editingMember) { member in
            FamilyMemberEditorSheet(store: store, initialMember: member)
        }
        .alert(
            "Retirer ce profil du foyer ?",
            isPresented: Binding(
                get: { memberPendingDeletion != nil },
                set: { if !$0 { memberPendingDeletion = nil } }
            )
        ) {
            Button("Annuler", role: .cancel) { memberPendingDeletion = nil }
            Button("Retirer du foyer", role: .destructive) {
                if let target = memberPendingDeletion {
                    memberPendingDeletion = nil
                    Task { await store.removeFamilyMember(target.id) }
                }
            }
        } message: {
            if let target = memberPendingDeletion {
                Text("Les services attribués à \(target.firstName) ne seront pas résiliés : ils seront automatiquement rattachés à votre profil principal.")
            }
        }
    }
}

private struct FamilyMemberCard: View {
    @Bindable var store: VemStoreViewModel
    let member: VemFamilyMember
    let canManage: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var assignedSubscriptions: [VemSubscription] {
        (store.workspace?.subscriptions ?? []).filter { $0.assignedMemberId == member.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color(vemHex: member.avatarColor))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(member.firstName.prefix(1)).uppercased())
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(member.firstName)
                            .font(.system(size: 17.5, weight: .heavy, design: .rounded))
                        VemStatusPill(
                            member.isPrimaryOwner ? "Titulaire" : member.relationship,
                            tone: member.isPrimaryOwner ? .emerald : .indigo
                        )
                    }

                    if let email = member.linkedVipleEmail, !email.isEmpty {
                        Label("Viple Live lié : \(email)", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(VemTheme.vipleEmerald)
                    } else if !member.isPrimaryOwner {
                        Label("Aucun compte Viple Live lié (gestion par vous seul)", systemImage: "person.crop.circle.badge.minus")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Administrateur principal de la facturation du foyer")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Assigned Services Chips
            VStack(alignment: .leading, spacing: 8) {
                Text("SERVICES RATTACHÉS (\(assignedSubscriptions.count))")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)

                if assignedSubscriptions.isEmpty {
                    Text("Aucun service rattaché actuellement.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(assignedSubscriptions) { sub in
                                Button {
                                    VemHaptics.impact(.light)
                                    store.activeServiceDetailID = sub.id
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: VemFormat.sfSymbol(for: sub.iconName, category: sub.category))
                                            .font(.system(size: 11.5, weight: .bold))
                                        Text(sub.displayTitle)
                                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(VemTheme.electricIndigo)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(VemTheme.electricIndigo.opacity(0.12))
                                    )
                                }
                                .buttonStyle(VemPressableButtonStyle())
                            }
                        }
                    }
                }
            }

            // Permissions & Quick Option Purchase Toggle (for non-owner members)
            if !member.isPrimaryOwner {
                Divider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achat autonome d'options")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        Text(
                            member.canPurchaseOptions
                                ? "\(member.firstName) peut activer seul(e) une option sur ses services."
                                : "Bloqué : \(member.firstName) doit vous envoyer une demande d'approbation."
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { member.canPurchaseOptions },
                            set: { newVal in
                                VemHaptics.selection()
                                Task { await store.quickToggleMemberOptionPermission(member, allowed: newVal) }
                            }
                        )
                    )
                    .labelsHidden()
                    .tint(VemTheme.vipleEmerald)
                    .disabled(!canManage || store.isMutating)
                }

                HStack(spacing: 8) {
                    VemStatusPill(
                        member.canAccessServices ? "Accès console autorisé" : "Accès console suspendu",
                        tone: member.canAccessServices ? .emerald : .amber,
                        icon: member.canAccessServices ? "lock.open.fill" : "lock.fill"
                    )
                    VemStatusPill(
                        member.canCancelServices ? "Peut résilier" : "Résiliation protégée",
                        tone: member.canCancelServices ? .coral : .sky,
                        icon: "shield.lefthalf.filled"
                    )
                }

                if canManage {
                    HStack(spacing: 10) {
                        Button(action: onEdit) {
                            Label("Modifier les droits", systemImage: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(VemTheme.electricIndigo)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(VemTheme.electricIndigo.opacity(0.11))
                                )
                        }
                        .buttonStyle(VemPressableButtonStyle())

                        Button(action: onDelete) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 13.5, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundStyle(VemTheme.warmCoral)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(VemTheme.warmCoral.opacity(0.12))
                                )
                        }
                        .buttonStyle(VemPressableButtonStyle())
                    }
                }
            }
        }
        .vemCard(cornerRadius: 22, padding: 17)
    }
}

// MARK: - Add / Edit Family Member Sheet

private struct FamilyMemberEditorSheet: View {
    @Bindable var store: VemStoreViewModel
    @State var draft: VemFamilyMember
    @Environment(\.dismiss) private var dismiss

    private let relationships = ["Fils", "Fille", "Conjoint(e)", "Parent", "Frère / Sœur", "Proche"]
    private let colorSwatches = ["#4F46E5", "#145346", "#0D9488", "#0284C7", "#7C3AED", "#F43F5E", "#D97706"]

    init(store: VemStoreViewModel, initialMember: VemFamilyMember) {
        self.store = store
        self._draft = State(initialValue: initialMember)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Identity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Identité du proche")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Prénom")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(.secondary)
                            TextField("Ex: Hugo, Chloé, Léa…", text: $draft.firstName)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Lien de parenté")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(relationships, id: \.self) { rel in
                                        let active = draft.relationship == rel
                                        Button {
                                            VemHaptics.selection()
                                            draft.relationship = rel
                                        } label: {
                                            Text(rel)
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .foregroundStyle(active ? .white : .primary)
                                                .background(
                                                    Capsule()
                                                        .fill(active ? VemTheme.electricIndigo : VemTheme.elevatedSurface)
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Couleur du badge")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                ForEach(colorSwatches, id: \.self) { hex in
                                    Button {
                                        VemHaptics.selection()
                                        draft.avatarColor = hex
                                    } label: {
                                        Circle()
                                            .fill(Color(vemHex: hex))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.white, lineWidth: draft.avatarColor.uppercased() == hex ? 3 : 0)
                                            )
                                            .shadow(radius: draft.avatarColor.uppercased() == hex ? 4 : 0)
                                    }
                                }
                            }
                        }
                    }
                    .vemCard()

                    // Viple Live Delegation Link
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Connexion Viple Live du proche (facultatif)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text("Si votre proche possède un compte Viple Live, saisissez son e-mail ci-dessous : les services que vous lui attribuez apparaîtront automatiquement dans son application Viple & Moi.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)

                        TextField(
                            "hugo@viplemail.fr",
                            text: Binding(
                                get: { draft.linkedVipleEmail ?? "" },
                                set: { draft.linkedVipleEmail = $0 }
                            )
                        )
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VemTheme.elevatedSurface))
                    }
                    .vemCard()

                    // Permissions Switches
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Autorisations & Contrôle parental")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))

                        Toggle(isOn: $draft.canAccessServices) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Voir et piloter ses services")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text("Permet de consulter sa consommation ou piloter son propre VPS.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(VemTheme.vipleEmerald)

                        Divider()

                        Toggle(isOn: $draft.canPurchaseOptions) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Acheter des options sans validation")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text("Si désactivé, toute demande d'option vous est soumise pour approbation.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(VemTheme.vipleEmerald)

                        Divider()

                        Toggle(isOn: $draft.canCancelServices) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Autoriser la résiliation d'un service")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text("Recommandé désactivé pour éviter toute suppression accidentelle.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(VemTheme.warmCoral)
                    }
                    .vemCard()

                    Button {
                        let cleanedName = draft.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanedName.isEmpty else {
                            store.showToast("Veuillez indiquer le prénom du membre.", isError: true)
                            return
                        }
                        draft.firstName = cleanedName
                        Task {
                            let ok = await store.saveFamilyMember(draft)
                            if ok { dismiss() }
                        }
                    } label: {
                        Text(draft.id > 0 ? "Enregistrer les modifications" : "Ajouter \(draft.firstName.isEmpty ? "ce proche" : draft.firstName) au foyer")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VemTheme.vibrantActionGradient))
                    }
                    .buttonStyle(VemPressableButtonStyle())
                    .disabled(store.isMutating)
                }
                .padding(16)
            }
            .background(VemTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(draft.id > 0 ? "Modifier \(draft.firstName)" : "Nouveau membre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
