import SwiftUI

// MARK: - Passeport Holographique 3D, Rangs Institutionnels, 12 Trophées, Attestations & Réglages Hors-Ligne

public struct PassportProfileView: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @State private var cacheSizeMB: Double = 0

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // 1. Carte Passeport 3D Holographique Interactive
                    HolographicPassportCard(vm: vm)

                    // 2. Compte Viple Live ID & Synchronisation Cloud
                    accountSyncSection

                    // 3. Attestations Officielles par Parcours
                    certificationsSection

                    // 4. Vitrine des 12 Trophées Déblocables
                    trophiesShowcaseSection

                    // 5. Échelle des 6 Rangs Institutionnels
                    rankLadderSection

                    // 6. Préférences d'Affichage & Cache Hors-Ligne
                    preferencesAndCacheSection
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(AcademyPalette.background)
            .navigationTitle("Mon Passeport")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                cacheSizeMB = AcademyAPIClient.shared.cachedCapturesSizeMB()
            }
        }
    }

    // MARK: - Synchronisation Cloud Cenelis / Viple Live ID

    private var accountSyncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(vm.lastSyncStatus, systemImage: vm.isOfflineMode ? "icloud.slash.fill" : "checkmark.icloud.fill")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(vm.isOfflineMode ? AcademyPalette.copper : AcademyPalette.pine)
                Spacer()
                if vm.isSyncing {
                    ProgressView().scaleEffect(0.8)
                }
            }

            if vm.learner.authenticated {
                if !vm.learner.groups.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(vm.learner.groups, id: \.self) { grp in
                                AcademyBadge(grp, icon: "key.fill", style: .pine)
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await vm.refreshCatalogAndSync(silent: false) }
                    } label: {
                        Label("Synchroniser maintenant", systemImage: "arrow.trianglehead.2.clockwise")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.pineSolid))
                            .foregroundStyle(.white)
                    }

                    Button {
                        vm.logout()
                    } label: {
                        Text("Déconnexion")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 42)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.dangerSoft))
                            .foregroundStyle(AcademyPalette.danger)
                    }
                }
            } else {
                Text("Connectez votre compte Viple Live ID / Cenelis Connect pour retrouver la même progression sur le site web academy.prod.cenelis.com et sur votre iPhone.")
                    .font(.system(size: 13))
                    .foregroundStyle(AcademyPalette.inkSecondary)

                Button {
                    AcademyHaptics.medium()
                    vm.isShowingAuthSheet = true
                } label: {
                    Label("Se connecter avec Viple Live ID / SSO", systemImage: "person.badge.key.fill")
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.pineSolid))
                }
                .buttonStyle(SpringPressableButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // MARK: - Attestations Officielles 80 % -> 100 %

    private var certificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attestations d'Aptitude Cenelis")
                .font(.system(size: 18, weight: .black, design: .rounded))

            ForEach(vm.visibleHomeCourses) { course in
                let certified = vm.isCourseCertified(course)
                let pct = vm.courseConsolidatedPct(course)

                Button {
                    vm.openCourse(course.id, stepIndex: course.parts.count)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: certified ? "checkmark.seal.fill" : "seal")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(certified ? AcademyPalette.success : AcademyPalette.inkMuted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(course.number)
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.copper)
                            Text(course.title)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.ink)
                                .lineLimit(1)
                            Text(certified
                                 ? "Apte à rejoindre Cenelis · Score consolidé : \(pct) %"
                                 : "Seuil requis : \(course.passThresholdPct) % · Touchez pour ouvrir l'évaluation")
                                .font(.system(size: 12))
                                .foregroundStyle(certified ? AcademyPalette.success : AcademyPalette.inkSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(certified ? AcademyPalette.successSoft : AcademyPalette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AcademyPalette.border, lineWidth: 1))
                    )
                }
                .buttonStyle(SpringPressableButtonStyle())
            }
        }
    }

    // MARK: - Vitrine des 12 Trophées

    private var trophiesShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trophées & Distinctions")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Spacer()
                AcademyBadge("\(vm.progress.unlockedBadges.count)/\(AcademyTrophy.catalog.count)", icon: "trophy.fill", style: .copper)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AcademyTrophy.catalog) { trophy in
                    let unlocked = vm.progress.unlockedBadges[trophy.id] != nil
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: trophy.sfSymbol)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(unlocked ? (trophy.isCopper ? AcademyPalette.copper : AcademyPalette.pine) : AcademyPalette.inkMuted)
                            Spacer()
                            Text("+\(trophy.xpBonus) XP")
                                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(unlocked ? AcademyPalette.pine : AcademyPalette.inkMuted)
                        }

                        Text(trophy.title)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(unlocked ? AcademyPalette.ink : AcademyPalette.inkMuted)
                            .lineLimit(2)

                        Text(trophy.description)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                            .lineLimit(3)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
                    .opacity(unlocked ? 1.0 : 0.62)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(unlocked ? (trophy.isCopper ? AcademyPalette.copperSoft : AcademyPalette.pineSoft) : AcademyPalette.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(unlocked ? (trophy.isCopper ? AcademyPalette.copperBorder : AcademyPalette.pineBorder) : AcademyPalette.border, lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - Échelle des 6 Rangs Institutionnels

    private var rankLadderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Échelle des Rangs Cenelis Academy")
                .font(.system(size: 18, weight: .black, design: .rounded))

            ForEach(AcademyRank.ladder) { rank in
                let reached = vm.progress.xp >= rank.minXP
                let isCurrent = vm.currentRank.id == rank.id

                HStack(spacing: 12) {
                    Image(systemName: rank.sfSymbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(reached ? AcademyPalette.pine : AcademyPalette.inkMuted)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(reached ? AcademyPalette.pineSoft : AcademyPalette.surfaceSubtle))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Rang \(rank.level) · \(rank.title)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                            if isCurrent {
                                AcademyBadge("Actuel", style: .copper)
                            }
                        }
                        Text(rank.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                    }
                    Spacer()
                    Text("\(rank.minXP) XP")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(reached ? AcademyPalette.pine : AcademyPalette.inkMuted)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isCurrent ? AcademyPalette.pineSoft.opacity(0.6) : AcademyPalette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(isCurrent ? AcademyPalette.pine : AcademyPalette.border, lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Préférences & Gestion du Cache Hors-Ligne

    private var preferencesAndCacheSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Préférences & Hors-Ligne")
                .font(.system(size: 18, weight: .black, design: .rounded))

            VStack(alignment: .leading, spacing: 8) {
                Text("Apparence visuelle")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(AcademyPalette.inkSecondary)
                Picker("Apparence", selection: $vm.themeMode) {
                    ForEach(AcademyThemeMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Mode de lecture préféré")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(AcademyPalette.inkSecondary)
                Picker("Style de lecture", selection: $vm.readerStyle) {
                    ForEach(AcademyReaderStyle.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Captures d'écran par défaut")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(AcademyPalette.inkSecondary)
                Picker("Captures", selection: $vm.shotDeviceMode) {
                    ForEach(AcademyDeviceCaptureMode.allCases) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cache captures @2x hors-ligne")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    Text(String(format: "%.1f Mo stockés localement · Catalogue v%@", cacheSizeMB, String(vm.catalog.contentVersion.prefix(8))))
                        .font(.system(size: 12))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
                Spacer()
                Button("Vider images") {
                    AcademyHaptics.selection()
                    AcademyAPIClient.shared.clearCapturesCache()
                    cacheSizeMB = 0
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AcademyPalette.copper)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }
}
