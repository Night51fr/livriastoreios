import SwiftUI

// MARK: - Boutique 1-Tap Order & Family Assignment Sheet

public struct BoutiqueOrderSheet: View {
    @Bindable var store: VemStoreViewModel
    public let product: VemBoutiqueProduct

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMemberId: Int = 0
    @State private var customNickname: String = ""

    public init(store: VemStoreViewModel, product: VemBoutiqueProduct) {
        self.store = store
        self.product = product
    }

    private var palette: VemAccentPalette {
        VemAccentPalette.resolve(product.accentTheme)
    }

    private var familyMembers: [VemFamilyMember] {
        store.workspace?.familyMembers ?? []
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Product Hero Summary
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.20))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: VemFormat.sfSymbol(for: product.iconName, category: product.category))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.badgeText.isEmpty ? "OFFRE OFFICIELLE VIPLE" : product.badgeText.uppercased())
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.84))
                                Text(product.title)
                                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }

                        Text(product.description)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .lineSpacing(2)

                        HStack {
                            Text("\(VemFormat.euros(product.priceMonthlyTtc)) TTC / mois")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(product.commitmentLabel)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.white.opacity(0.18)))
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(palette.gradient)
                    )

                    // Beneficiary Family Member Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pour quel membre de votre foyer ?")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text("Si vous choisissez un proche possédant un compte Viple Live lié (ex: Hugo), il verra immédiatement ce service dans son propre espace Viple & Moi.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)

                        ForEach(familyMembers) { member in
                            let isChosen = selectedMemberId == member.id
                            Button {
                                VemHaptics.selection()
                                selectedMemberId = member.id
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(vemHex: member.avatarColor))
                                        .frame(width: 38, height: 38)
                                        .overlay(
                                            Text(String(member.firstName.prefix(1)).uppercased())
                                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                                .foregroundStyle(.white)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(member.firstName) · \(member.relationship)")
                                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        if let email = member.linkedVipleEmail, !email.isEmpty {
                                            Text("Accès partagé : \(email)")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        } else if member.isPrimaryOwner {
                                            Text("Titulaire principal du foyer")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 21))
                                        .foregroundStyle(isChosen ? VemTheme.vipleEmerald : .secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(isChosen ? VemTheme.vipleMint.opacity(0.12) : VemTheme.elevatedSurface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .strokeBorder(isChosen ? VemTheme.vipleEmerald : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(VemPressableButtonStyle())
                        }
                    }
                    .vemCard()

                    // Optional Custom Nickname
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Surnom personnalisé (facultatif)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                        TextField("Ex: VPS Gaming de Hugo, Box Maison…", text: $customNickname)
                            .padding(13)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VemTheme.elevatedSurface))
                    }
                    .vemCard()

                    // Order Recap & Confirm CTA
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Mensualité TTC")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(VemFormat.euros(product.priceMonthlyTtc)) / mois")
                                .font(.system(size: 15, weight: .bold))
                        }
                        HStack {
                            Text("Frais de mise en service")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(product.setupFeeTtc > 0 ? VemFormat.euros(product.setupFeeTtc) : "0,00 € (Offert)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(product.setupFeeTtc > 0 ? Color.primary : VemTheme.vipleEmerald)
                        }
                        Divider()
                        Button {
                            VemHaptics.impact(.heavy)
                            let targetMember = selectedMemberId > 0 ? selectedMemberId : nil
                            Task {
                                let ok = await store.orderService(
                                    productCode: product.productCode,
                                    assignedMemberId: targetMember,
                                    customNickname: customNickname
                                )
                                if ok { dismiss() }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if store.isMutating {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "checkmark.seal.fill")
                                }
                                Text(store.isMutating ? "Provisionnement en cours…" : "Confirmer & Activer immédiatement")
                            }
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(VemTheme.vibrantActionGradient)
                            )
                        }
                        .buttonStyle(VemPressableButtonStyle())
                        .disabled(store.isMutating)
                    }
                    .vemCard()
                }
                .padding(16)
            }
            .background(VemTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Souscrire une offre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onAppear {
                if selectedMemberId == 0, let primary = familyMembers.first(where: { $0.isPrimaryOwner }) ?? familyMembers.first {
                    selectedMemberId = primary.id
                }
            }
        }
    }
}
