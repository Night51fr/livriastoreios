import SwiftUI

// MARK: - Catalogue Complet des Cours En Ligne & Guides Clients Cenelis Academy

public struct CoursesCatalogView: View {
    @ObservedObject var vm: AcademyStoreViewModel

    public enum CourseFilter: String, CaseIterable, Identifiable {
        case all = "Tous les cours"
        case flagship = "Grands Parcours"
        case thematic = "Modules Thématiques"
        case clientGuides = "Guides Espace Client"

        public var id: String { rawValue }
    }

    @State private var filter: CourseFilter = .all
    @State private var searchText: String = ""

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    private var filteredCourses: [AcademyCourse] {
        let base: [AcademyCourse]
        switch filter {
        case .all:
            base = vm.catalog.courses
        case .flagship:
            base = vm.visibleHomeCourses.filter { $0.parts.count >= 16 || $0.isFlagshipOnboarding }
        case .thematic:
            base = vm.visibleHomeCourses.filter { $0.parts.count < 16 && !$0.isFlagshipOnboarding }
        case .clientGuides:
            base = vm.customerGuideCourses
        }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return base.filter { c in
            c.title.localizedCaseInsensitiveContains(trimmed)
                || c.subtitle.localizedCaseInsensitiveContains(trimmed)
                || c.number.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Filtre rapide par famille
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CourseFilter.allCases) { f in
                                Button {
                                    AcademyHaptics.selection()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        filter = f
                                    }
                                } label: {
                                    Text(f.rawValue)
                                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(filter == f ? .white : AcademyPalette.ink)
                                        .background(Capsule().fill(filter == f ? AcademyPalette.pineSolid : AcademyPalette.surface))
                                }
                                .buttonStyle(SpringPressableButtonStyle())
                            }
                        }
                    }

                    // Préférences rapides de lecture
                    HStack(spacing: 10) {
                        Label("Mode : \(vm.readerStyle.rawValue)", systemImage: vm.readerStyle.sfSymbol)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AcademyPalette.pine)
                        Spacer()
                        Button {
                            AcademyHaptics.selection()
                            vm.readerStyle = (vm.readerStyle == .fluid) ? .focusDeck : .fluid
                        } label: {
                            Text("Basculer")
                                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(AcademyPalette.pineSoft))
                                .foregroundStyle(AcademyPalette.pine)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.surface))

                    ForEach(filteredCourses) { course in
                        CourseSummaryRowCard(course: course, vm: vm)
                    }

                    // Section Approfondissements 5 paliers
                    if filter == .all && searchText.isEmpty && !vm.catalog.deepDives.isEmpty {
                        Divider().padding(.vertical, 4)
                        Text("\(vm.catalog.deepDives.count) Dossiers d'Approfondissement (5 Paliers)")
                            .font(.system(size: 18, weight: .black, design: .rounded))

                        ForEach(vm.catalog.deepDives) { dive in
                            let done = vm.progress.deepDives[dive.id]?.completed.count ?? 0
                            Button {
                                vm.openDeepDive(id: dive.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: AcademyIcons.sfSymbol(for: dive.icon))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(AcademyPalette.pine)
                                        .frame(width: 42, height: 42)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.pineSoft))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(AcademyRichTextParser.plainText(dive.title))
                                            .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                                            .foregroundStyle(AcademyPalette.ink)
                                            .multilineTextAlignment(.leading)
                                        Text("\(done)/\(dive.levels.count) paliers validés · \(dive.badge)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AcademyPalette.copper)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(AcademyPalette.inkMuted)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(AcademyPalette.surface)
                                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.border, lineWidth: 1))
                                )
                            }
                            .buttonStyle(SpringPressableButtonStyle())
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .searchable(text: $searchText, prompt: "Filtrer un cours ou parcours…")
            .refreshable {
                await vm.refreshCatalogAndSync(silent: false)
            }
            .background(AcademyPalette.background)
            .navigationTitle("Tous les Cours")
        }
    }
}
