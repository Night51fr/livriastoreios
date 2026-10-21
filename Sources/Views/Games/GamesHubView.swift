import SwiftUI

// MARK: - Jeux Littéraires & Récompenses XP Livria.iOS (GamesHubView)

public struct GamesHubView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    @State private var wheelAngle: Double = 0
    @State private var isSpinningWheel: Bool = false
    @State private var lastWheelReward: String? = nil

    // Quiz Littéraire
    @State private var quizIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var showQuizExplanation: Bool = false

    // Mot Mystère
    @State private var scrambleIndex: Int = 0
    @State private var scrambleGuess: String = ""
    @State private var scrambleFeedback: String? = nil

    private let questions = LivriaQuizQuestionItem.sampleQuestions
    private let scrambles = LivriaWordScrambleItem.all

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                dailyStreakBanner
                fortuneWheelCard
                literaryQuizCard
                wordScrambleCard
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Jeux & Défis XP")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dailyStreakBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LivriaPalette.gold.opacity(0.24))
                    .frame(width: 52, height: 52)
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(LivriaPalette.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Série quotidienne : \(store.games?.streak ?? store.currentUser?.streak ?? 0) jour(s)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Réclamez votre bonus quotidien pour gagner de l'XP et des points de fidélité !")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.88))
            }
            Spacer()
            Button {
                Task {
                    await store.claimDailyGameBonus()
                }
            } label: {
                Text(store.games?.canClaimDaily == false ? "Réclamé ✓" : "Réclamer")
                    .font(.system(size: 12.5, weight: .black))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(LivriaPalette.gold))
                    .foregroundStyle(.black)
            }
            .disabled(store.games?.canClaimDaily == false)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LivriaPalette.heroGradient))
    }

    private var fortuneWheelCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "sparkles.tv.fill")
                    .foregroundStyle(LivriaPalette.coral)
                Text("Roue de la Fortune Littéraire")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
            }

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [LivriaPalette.primary, LivriaPalette.coral, LivriaPalette.gold, LivriaPalette.mint, LivriaPalette.primary],
                            center: .center
                        )
                    )
                    .frame(width: 140, height: 140)
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .rotationEffect(.degrees(wheelAngle))
                    .shadow(color: LivriaPalette.primary.opacity(0.25), radius: 10, x: 0, y: 5)

                Circle()
                    .fill(LivriaPalette.cardPaper)
                    .frame(width: 48, height: 48)
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundStyle(LivriaPalette.primary)
            }

            if let reward = lastWheelReward {
                Text("🎉 \(reward)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LivriaPalette.mint)
            }

            Button {
                guard !isSpinningWheel else { return }
                isSpinningWheel = true
                withAnimation(.easeOut(duration: 1.8)) {
                    wheelAngle += 1080 + Double(Int.random(in: 45...315))
                }
                Task {
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    let reward = await store.spinFortuneWheel()
                    lastWheelReward = reward
                    isSpinningWheel = false
                }
            } label: {
                Text(isSpinningWheel ? "La roue tourne..." : "Tourner la Roue de la Fortune")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .livriaCard()
    }

    private var literaryQuizCard: some View {
        let q = questions[quizIndex % questions.count]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Quiz Culture Littéraire", systemImage: "questionmark.bubble.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                Text("+\(q.xpReward) XP")
                    .font(.system(size: 12, weight: .heavy))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
                    .foregroundStyle(LivriaPalette.primary)
            }

            Text(q.question)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(LivriaPalette.ink)

            ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                Button {
                    guard selectedOptionIndex == nil else { return }
                    selectedOptionIndex = idx
                    showQuizExplanation = true
                    if idx == q.correctIndex {
                        Task {
                            await store.submitGameScore(game: "Quiz Littéraire", score: 100, xp: q.xpReward)
                        }
                    }
                } label: {
                    HStack {
                        Text(opt)
                            .font(.system(size: 13.5, weight: .semibold))
                        Spacer()
                        if let sel = selectedOptionIndex {
                            if idx == q.correctIndex {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(LivriaPalette.mint)
                            } else if idx == sel {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(11)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(optionBackground(idx: idx, correct: q.correctIndex))
                    )
                    .foregroundStyle(LivriaPalette.ink)
                }
                .buttonStyle(.plain)
            }

            if showQuizExplanation {
                Text(q.explanation)
                    .font(.system(size: 12.5))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

                Button("Question suivante →") {
                    quizIndex = (quizIndex + 1) % questions.count
                    selectedOptionIndex = nil
                    showQuizExplanation = false
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LivriaPalette.primary)
            }
        }
        .livriaCard()
    }

    private func optionBackground(idx: Int, correct: Int) -> Color {
        guard let sel = selectedOptionIndex else { return LivriaPalette.background }
        if idx == correct { return LivriaPalette.mint.opacity(0.22) }
        if idx == sel { return Color.red.opacity(0.18) }
        return LivriaPalette.background
    }

    private var wordScrambleCard: some View {
        let item = scrambles[scrambleIndex % scrambles.count]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Mot Mystère Littéraire", systemImage: "character.textbox")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                Text("+\(item.xpReward) XP")
                    .font(.system(size: 12, weight: .heavy))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(LivriaPalette.goldSoft))
                    .foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.02))
            }

            Text(item.scrambled)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(LivriaPalette.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primarySoft.opacity(0.6)))

            Text("Indice : \(item.hint)")
                .font(.system(size: 12.5))
                .foregroundStyle(LivriaPalette.inkMuted)

            HStack(spacing: 10) {
                TextField("Votre réponse...", text: $scrambleGuess)
                    .textInputAutocapitalization(.characters)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

                Button("Valider") {
                    let clean = scrambleGuess.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if clean == item.answer {
                        scrambleFeedback = "Bravo ! Le mot était bien \(item.answer) (+\(item.xpReward) XP)."
                        scrambleGuess = ""
                        scrambleIndex = (scrambleIndex + 1) % scrambles.count
                        Task {
                            await store.submitGameScore(game: "Mot Mystère", score: 100, xp: item.xpReward)
                        }
                    } else {
                        scrambleFeedback = "Pas tout à fait, réessayez !"
                    }
                }
                .font(.system(size: 13.5, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.primary))
                .foregroundStyle(.white)
            }

            if let fb = scrambleFeedback {
                Text(fb)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(LivriaPalette.primary)
            }
        }
        .livriaCard()
    }
}
