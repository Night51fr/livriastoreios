import SwiftUI

// MARK: - Évaluation Finale en 4 Volets : Grand Quiz (80 % Apte), Rattrapage Lacunes -> 100 %, Points Flous & Approfondissements

public struct CourseEvaluationView: View {
    public let course: AcademyCourse
    @ObservedObject var vm: AcademyStoreViewModel

    public enum EvalTab: String, CaseIterable, Identifiable {
        case quiz = "1. Quiz Final"
        case gaps = "2. Lacunes → 100%"
        case unclear = "3. Points flous"
        case deepDives = "4. Approfondir"

        public var id: String { rawValue }
    }

    @State private var selectedTab: EvalTab = .quiz
    @State private var answers: [Int: Int] = [:]
    @State private var hasSubmittedInSession: Bool = false
    @State private var remediationChoices: [Int: Int] = [:]
    @State private var remediationErrorIdx: Int? = nil

    public init(course: AcademyCourse, vm: AcademyStoreViewModel) {
        self.course = course
        self.vm = vm
    }

    private var savedRecord: AcademyCourseScoreRecord? {
        vm.progress.courseScores[course.id]
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Sélecteur des 4 volets pédagogiques
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EvalTab.allCases) { tab in
                        let active = (selectedTab == tab)
                        Button {
                            AcademyHaptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = tab
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8.5)
                                .foregroundStyle(active ? .white : AcademyPalette.ink)
                                .background(Capsule().fill(active ? AcademyPalette.pineSolid : AcademyPalette.surfaceSubtle))
                        }
                        .buttonStyle(SpringPressableButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(AcademyPalette.surface)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let rec = savedRecord {
                        consolidatedScoreBanner(record: rec)
                    }

                    switch selectedTab {
                    case .quiz:
                        quizTabContent
                    case .gaps:
                        gapsRemediationTabContent
                    case .unclear:
                        unclearPointsTabContent
                    case .deepDives:
                        deepDivesTabContent
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            if let existing = savedRecord, answers.isEmpty {
                for (k, v) in existing.lastAnswers {
                    if let idx = Int(k) { answers[idx] = v }
                }
            }
        }
    }

    // MARK: - Bandeau d'Aptitude Officielle (Seuil 80 % -> Consolidation 100 %)

    private func consolidatedScoreBanner(record: AcademyCourseScoreRecord) -> some View {
        let isApte = record.consolidatedPct >= course.passThresholdPct
        let missingCount = max(0, record.total - record.consolidatedScore)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                AnimatedMasteryRing(
                    progress: Double(record.consolidatedPct) / 100.0,
                    size: 68,
                    lineWidth: 7,
                    tint: isApte ? AcademyPalette.gold : AcademyPalette.copper,
                    trackColor: .white.opacity(0.18),
                    centerText: "\(record.consolidatedPct)%",
                    textColor: .white
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(isApte
                         ? (record.consolidatedPct == 100 ? "MAÎTRISE INTÉGRALE 100 % VALIDÉE" : "APTE À REJOINDRE CENELIS (≥ \(course.passThresholdPct) %)")
                         : "EN ROUTE VERS L'APTITUDE (\(course.passThresholdPct) % REQUIS)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(AcademyPalette.gold)

                    Text("\(record.consolidatedScore) / \(record.total) acquis consolidés")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(missingCount == 0
                         ? "Zéro lacune restante : vous maîtrisez 100 % des points du parcours !"
                         : "Il vous reste \(missingCount) point(s) à rattraper dans l'onglet « Lacunes → 100% ».")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            if missingCount > 0 && selectedTab != .gaps {
                Button {
                    AcademyHaptics.medium()
                    withAnimation(.spring()) { selectedTab = .gaps }
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Combler mes \(missingCount) lacune(s) une par une vers 100 %")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.16)))
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AcademyPalette.heroGradient)
        )
    }

    // MARK: - Volet 1 : Grand Quiz Final

    private var quizTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Grand Quiz Final · \(course.number)")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                    Text("Répondez aux \(course.quiz.count) questions (\(answers.count)/\(course.quiz.count) sélectionnées) · Seuil d'aptitude : \(course.passThresholdPct) %.")
                        .font(.system(size: 13))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
                Spacer()
                Button {
                    AcademyHaptics.selection()
                    vm.setStepIndex(max(0, course.parts.count - 1), for: course)
                } label: {
                    Label("Cours", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AcademyPalette.surfaceSubtle))
                        .foregroundStyle(AcademyPalette.ink)
                }
            }

            ForEach(Array(course.quiz.enumerated()), id: \.offset) { qIdx, question in
                quizQuestionCard(index: qIdx, question: question)
            }

            Button {
                let rec = vm.submitCourseQuiz(course: course, answers: answers)
                hasSubmittedInSession = true
                if rec.consolidatedPct < 100 {
                    withAnimation(.spring()) {
                        selectedTab = .gaps
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text(answers.count < course.quiz.count
                         ? "Répondez à toutes les questions (\(answers.count)/\(course.quiz.count))"
                         : "Valider mon évaluation et calculer mon score")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(answers.count < course.quiz.count ? AnyShapeStyle(AcademyPalette.inkMuted) : AnyShapeStyle(AcademyPalette.pineSolid))
                )
            }
            .buttonStyle(SpringPressableButtonStyle())
            .disabled(answers.count < course.quiz.count)
        }
    }

    private func quizQuestionCard(index: Int, question: AcademyQuizQuestion) -> some View {
        let chosen = answers[index]
        let showCorrection = hasSubmittedInSession || (savedRecord != nil)

        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                AcademyBadge("Question \(index + 1)/\(course.quiz.count)", style: .pine)
                if let topic = question.topic, !topic.isEmpty {
                    Text(topic)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(AcademyPalette.copper)
                }
            }

            Text(AcademyRichTextParser.plainText(question.q))
                .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                .foregroundStyle(AcademyPalette.ink)

            VStack(spacing: 8) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { optIdx, optText in
                    let isSelected = (chosen == optIdx)
                    let isRightOption = (optIdx == question.correct)

                    Button {
                        AcademyHaptics.selection()
                        answers[index] = optIdx
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isSelected ? AcademyPalette.pine : AcademyPalette.inkMuted)
                                .padding(.top, 2)

                            Text(AcademyRichTextParser.plainText(optText))
                                .font(.system(size: 13.5, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(AcademyPalette.ink)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)

                            if showCorrection && isSelected {
                                Image(systemName: isRightOption ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(isRightOption ? AcademyPalette.success : AcademyPalette.danger)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(isSelected ? AcademyPalette.pineSoft : AcademyPalette.surfaceSubtle)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(isSelected ? AcademyPalette.pine : .clear, lineWidth: 1.4)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // MARK: - Volet 2 : Passage Point par Point sur Chaque Lacune jusqu'à 100 %

    private var gapsRemediationTabContent: some View {
        guard let rec = savedRecord else {
            return AnyView(
                VStack(spacing: 12) {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 38))
                        .foregroundStyle(AcademyPalette.pine)
                    Text("Passez d'abord le Grand Quiz Final")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    Text("Dès votre première tentative, cet onglet listera automatiquement chacune de vos lacunes avec une explication sur mesure et une question de rattrapage pour monter jusqu'à 100 %.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20).fill(AcademyPalette.surface))
            )
        }

        let missedIndices = course.quiz.indices.filter { idx in
            let directAns = rec.lastAnswers["\(idx)"]
            return directAns != course.quiz[idx].correct
        }

        if missedIndices.isEmpty {
            return AnyView(
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AcademyPalette.gold)
                    Text("Bravo : 0 lacune détectée (100 % direct) !")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("Vous avez répondu juste à l'intégralité des questions du premier coup.")
                        .font(.system(size: 14))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20).fill(AcademyPalette.surface))
            )
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Rattrapage personnalisé point par point")
                    .font(.system(size: 18, weight: .black, design: .rounded))

                ForEach(missedIndices, id: \.self) { qIdx in
                    let q = course.quiz[qIdx]
                    let isRemediated = (rec.remediatedIndices["\(qIdx)"] == true)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            AcademyBadge(
                                isRemediated ? "Lacune comblée ✓" : "Lacune à consolider",
                                icon: isRemediated ? "checkmark.seal.fill" : "sparkles",
                                style: isRemediated ? .success : .copper
                            )
                            Spacer()
                            if let pIdx = q.partIdx, course.parts.indices.contains(pIdx) {
                                Button {
                                    vm.setStepIndex(pIdx, for: course)
                                } label: {
                                    Label("Relire page \(pIdx + 1)", systemImage: "book.pages")
                                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(AcademyPalette.pine)
                                }
                            }
                        }

                        Text("Q\(qIdx + 1). \(AcademyRichTextParser.plainText(q.q))")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))

                        if let why = q.whyWrong, !why.isEmpty {
                            Text("Piège fréquent : \(AcademyRichTextParser.plainText(why))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AcademyPalette.copper)
                        }

                        Text(AcademyRichTextParser.plainText(q.explain))
                            .font(.system(size: 13.5))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.pineSoft))

                        // Question de rattrapage immédiat vers 100 %
                        if let rem = q.remediation, !isRemediated {
                            Divider()
                            Text("VÉRIFICATION DE RATTRAPAGE (+40 XP) :")
                                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.pine)

                            Text(AcademyRichTextParser.plainText(rem.q))
                                .font(.system(size: 14, weight: .bold, design: .rounded))

                            ForEach(Array(rem.options.enumerated()), id: \.offset) { rOptIdx, rOpt in
                                let picked = (remediationChoices[qIdx] == rOptIdx)
                                Button {
                                    AcademyHaptics.selection()
                                    remediationChoices[qIdx] = rOptIdx
                                    remediationErrorIdx = nil
                                } label: {
                                    HStack {
                                        Image(systemName: picked ? "largecircle.fill.circle" : "circle")
                                            .foregroundStyle(picked ? AcademyPalette.pine : AcademyPalette.inkMuted)
                                        Text(AcademyRichTextParser.plainText(rOpt))
                                            .font(.system(size: 13, weight: picked ? .bold : .medium))
                                            .foregroundStyle(AcademyPalette.ink)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 11).fill(picked ? AcademyPalette.pineSoft : AcademyPalette.surfaceSubtle))
                                }
                                .buttonStyle(.plain)
                            }

                            if remediationErrorIdx == qIdx {
                                Text("Relisez calmement l'encadré vert ci-dessus puis choisissez la bonne proposition.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AcademyPalette.danger)
                            }

                            Button {
                                guard let choice = remediationChoices[qIdx] else { return }
                                let ok = vm.validateRemediationQuestion(course: course, questionIndex: qIdx, chosenOption: choice)
                                if !ok {
                                    remediationErrorIdx = qIdx
                                }
                            } label: {
                                Text("Valider ce rattrapage")
                                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.pineSolid))
                            }
                            .disabled(remediationChoices[qIdx] == nil)
                        } else if isRemediated, let note = q.remediation?.successNote {
                            Text("✓ \(AcademyRichTextParser.plainText(note))")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(AcademyPalette.success)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AcademyPalette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(isRemediated ? AcademyPalette.success.opacity(0.45) : AcademyPalette.copperBorder, lineWidth: 1.2))
                    )
                }
            }
        )
    }

    // MARK: - Volet 3 : Points Non Compris signalés par l'Apprenant

    private var unclearPointsTabContent: some View {
        let unclearParts = course.parts.enumerated().filter { vm.isPartMarkedUnclear($0.element.id) }

        return VStack(alignment: .leading, spacing: 14) {
            Text("Vos points signalés à ré-expliquer")
                .font(.system(size: 18, weight: .black, design: .rounded))
            Text("Tout point que vous avez marqué « Pas 100 % clair » pendant la lecture est ré-expliqué ici avec des mots simples. Vous pouvez aussi ajouter n'importe quelle page du cours ci-dessous.")
                .font(.system(size: 13.5))
                .foregroundStyle(AcademyPalette.inkSecondary)

            if unclearParts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AcademyPalette.pine)
                    Text("Aucun point flou en attente !")
                        .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 18).fill(AcademyPalette.surface))
            } else {
                ForEach(unclearParts, id: \.element.id) { idx, part in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            AcademyBadge("Page \(idx + 1)", style: .copper)
                            Spacer()
                            Button("C'est limpide maintenant ✓") {
                                vm.toggleUnclearPoint(part.id)
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AcademyPalette.success)
                        }

                        Text(part.title)
                            .font(.system(size: 15.5, weight: .heavy, design: .rounded))

                        if let rx = part.reexplain {
                            Text("💡 Analogie : \(AcademyRichTextParser.plainText(rx.analogy))")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(AcademyPalette.copper)
                            Text(AcademyRichTextParser.plainText(rx.simple))
                                .font(.system(size: 13.5))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                        } else {
                            Text(AcademyRichTextParser.plainText(part.summary))
                                .font(.system(size: 13.5))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(AcademyPalette.surface))
                }
            }

            // Sélecteur rapide pour ajouter un point du cours si besoin
            DisclosureGroup("Choisir d'autres pages du cours à ré-expliquer") {
                VStack(spacing: 6) {
                    ForEach(Array(course.parts.enumerated()), id: \.element.id) { idx, part in
                        let marked = vm.isPartMarkedUnclear(part.id)
                        Button {
                            vm.toggleUnclearPoint(part.id)
                        } label: {
                            HStack {
                                Image(systemName: marked ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(marked ? AcademyPalette.copper : AcademyPalette.inkMuted)
                                Text("\(idx + 1). \(part.title)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AcademyPalette.ink)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .font(.system(size: 13.5, weight: .bold, design: .rounded))
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(AcademyPalette.surface))
        }
    }

    // MARK: - Volet 4 : Dossiers d'Approfondissement Progressifs (5 Paliers)

    private var deepDivesTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aller encore plus loin (5 paliers par sujet)")
                .font(.system(size: 18, weight: .black, design: .rounded))
            Text("Explorez les coulisses techniques, juridiques et métiers de Cenelis sans jamais subir de jargon brutal.")
                .font(.system(size: 13.5))
                .foregroundStyle(AcademyPalette.inkSecondary)

            ForEach(vm.catalog.deepDives) { dive in
                let rec = vm.progress.deepDives[dive.id]
                let doneCount = rec?.completed.count ?? 0

                Button {
                    vm.openDeepDive(id: dive.id)
                } label: {
                    HStack(spacing: 12) {
                        AnimatedMasteryRing(
                            progress: Double(doneCount) / Double(max(1, dive.levels.count)),
                            size: 46,
                            lineWidth: 5,
                            tint: AcademyPalette.pine,
                            centerText: "\(doneCount)/\(dive.levels.count)"
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(dive.title)
                                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.ink)
                                .multilineTextAlignment(.leading)
                            Text(dive.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
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
}
