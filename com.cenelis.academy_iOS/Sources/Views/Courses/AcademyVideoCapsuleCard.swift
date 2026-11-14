import SwiftUI
import AVKit
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Capsule Vidéo Explicative Native (Motion Design, Sous-Titres Synchronisés, Vitesse, PiP & +30 XP)

public struct AcademyVideoCapsuleCard: View {
    public let video: AcademyVideoCapsule
    @ObservedObject var vm: AcademyStoreViewModel

    @State private var isActivated: Bool = false
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var playbackRate: Float = 1.0
    @State private var showSubtitles: Bool = true
    @State private var showTranscript: Bool = false
    @State private var isPresentingFullscreen: Bool = false
    @State private var pulseScale: CGFloat = 1.0

    @State private var player: AVPlayer? = nil
    @State private var timeObserverToken: Any? = nil
    @State private var endObserver: NSObjectProtocol? = nil

    public init(video: AcademyVideoCapsule, vm: AcademyStoreViewModel) {
        self.video = video
        self.vm = vm
    }

    private var isWatched: Bool {
        vm.isVideoWatched(video.id)
    }

    private var activeCueText: String? {
        guard showSubtitles, !video.cues.isEmpty else { return nil }
        return video.cues.first(where: { currentTime >= $0.start && currentTime <= $0.end + 0.15 })?.text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête éditorial de la capsule vidéo
            HStack(alignment: .top, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(AcademyRichTextParser.plainText(video.badge.isEmpty ? "Capsule vidéo explicative" : video.badge))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(AcademyPalette.pineSolid))
                .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 6) {
                    Label(video.durationLabel, systemImage: "clock.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AcademyPalette.inkSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: isWatched ? "checkmark.seal.fill" : "sparkles")
                            .font(.system(size: 10.5, weight: .bold))
                        Text(isWatched ? "Visionnée ✓" : "+30 XP")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(isWatched ? AcademyPalette.successSoft : AcademyPalette.copperSoft))
                    .foregroundStyle(isWatched ? AcademyPalette.success : AcademyPalette.copper)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AcademyRichTextParser.plainText(video.title))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)

                if !video.subtitle.isEmpty {
                    Text(AcademyRichTextParser.plainText(video.subtitle))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                        .lineSpacing(2)
                }
            }

            // Zone vidéo 16:9 (Poster Motion Design ou Lecteur AVKit actif)
            if isActivated, let activePlayer = player {
                VStack(spacing: 8) {
                    ZStack(alignment: .bottom) {
                        VideoPlayer(player: activePlayer)
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(AcademyPalette.pineBorder, lineWidth: 1.2)
                            )

                        if let cue = activeCueText, !cue.isEmpty {
                            Text(AcademyRichTextParser.plainText(cue))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.black.opacity(0.78))
                                )
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                        }
                    }

                    // Barre de contrôle enrichie Cenelis Academy
                    videoControlStrip
                }
            } else {
                posterLaunchStage
            }

            // Points clés à retenir de la vidéo
            if !video.keyTakeaways.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("POINTS CLÉS EXPLIQUÉS EN VIDÉO")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.pine)

                    ForEach(Array(video.keyTakeaways.enumerated()), id: \.offset) { _, pt in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(AcademyPalette.copper)
                                .padding(.top, 2)
                            Text(AcademyRichTextParser.plainText(pt))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AcademyPalette.ink)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AcademyPalette.surfaceSubtle))
            }

            // Tiroir optionnel de transcription intégrale
            if !video.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        AcademyHaptics.selection()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            showTranscript.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "captions.bubble.fill")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(AcademyPalette.pine)
                            Text(showTranscript ? "Masquer la transcription écrite" : "Lire la transcription complète de la vidéo")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.pine)
                            Spacer()
                            Image(systemName: showTranscript ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AcademyPalette.inkMuted)
                        }
                    }
                    .buttonStyle(.plain)

                    if showTranscript {
                        Text(AcademyRichTextParser.plainText(video.transcript))
                            .font(.system(size: 13))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                            .lineSpacing(3)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isWatched ? AcademyPalette.pineBorder : AcademyPalette.copperBorder, lineWidth: 1.3)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $isPresentingFullscreen) {
            if let activePlayer = player {
                AcademyFullscreenVideoSheet(player: activePlayer)
                    .ignoresSafeArea()
            }
        }
        #endif
        .onChange(of: video.id) { _, _ in
            teardownPlayer()
            isActivated = false
            showTranscript = false
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
    }

    // MARK: - Scène Poster Motion Design avant Lecture

    private var posterLaunchStage: some View {
        Button {
            activateAndPlay()
        } label: {
            ZStack {
                if let poster = video.posterUrl, !poster.isEmpty {
                    CachedAcademyImage(path: poster, contentMode: .fill, cornerRadius: 16, minPlaceholderHeight: 195)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AcademyPalette.heroGradient)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                }

                // Voile de contraste cinématique
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.58)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Bouton Play central pulsant Motion Design
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .strokeBorder(AcademyPalette.gold.opacity(0.55), lineWidth: 2)
                            .frame(width: 74, height: 74)
                            .scaleEffect(pulseScale)

                        Circle()
                            .fill(AcademyPalette.copperGradient)
                            .frame(width: 60, height: 60)
                            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2))
                            .shadow(color: .black.opacity(0.38), radius: 10, y: 4)

                        Image(systemName: "play.fill")
                            .font(.system(size: 23, weight: .black))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    }

                    Text("Lancer l'explication vidéo (\(video.durationLabel))")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.black.opacity(0.62)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AcademyPalette.copperBorder, lineWidth: 1.2)
            )
        }
        .buttonStyle(SpringPressableButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.12
            }
        }
    }

    // MARK: - Barre de Contrôle Tactile Rapide

    private var videoControlStrip: some View {
        let total = max(duration, Double(max(1, video.durationSeconds)))
        let frac = min(1.0, max(0.0, currentTime / total))

        return VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AcademyPalette.surfaceSubtle)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AcademyPalette.pineSolid, AcademyPalette.copperSolid],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * frac))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { val in
                            let ratio = min(1.0, max(0.0, val.location.x / max(1, geo.size.width)))
                            seek(to: ratio * total)
                        }
                )
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                Button {
                    AcademyHaptics.selection()
                    togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AcademyPalette.pineSolid))
                        .foregroundStyle(.white)
                }

                Button {
                    AcademyHaptics.light()
                    seek(to: max(0, currentTime - 10))
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AcademyPalette.ink)
                }

                Button {
                    AcademyHaptics.light()
                    seek(to: min(total, currentTime + 10))
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AcademyPalette.ink)
                }

                Text("\(formatTime(currentTime)) / \(formatTime(total))")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(AcademyPalette.inkSecondary)

                Spacer()

                if !video.cues.isEmpty {
                    Button {
                        AcademyHaptics.selection()
                        showSubtitles.toggle()
                    } label: {
                        Text("CC")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(showSubtitles ? AcademyPalette.pineSolid : AcademyPalette.surfaceSubtle)
                            )
                            .foregroundStyle(showSubtitles ? .white : AcademyPalette.inkSecondary)
                    }
                }

                Menu {
                    ForEach([Float(0.75), Float(1.0), Float(1.25), Float(1.5), Float(2.0)], id: \.self) { rate in
                        Button {
                            setRate(rate)
                        } label: {
                            HStack {
                                Text(String(format: "%.2gx", rate))
                                if abs(playbackRate - rate) < 0.01 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(String(format: "%.2gx", playbackRate))
                        .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AcademyPalette.copperSoft))
                        .foregroundStyle(AcademyPalette.copper)
                }

                #if canImport(UIKit)
                Button {
                    AcademyHaptics.light()
                    isPresentingFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AcademyPalette.pine)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(AcademyPalette.pineSoft))
                }
                #endif
            }
        }
    }

    // MARK: - Gestion AVPlayer & AudioSession Parlée

    private func activateAndPlay() {
        AcademyHaptics.medium()
        guard let resolvedURL = AcademyAPIClient.shared.resolveAssetURL(video.url) else { return }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        if player == nil {
            let item = AVPlayerItem(url: resolvedURL)
            let avPlayer = AVPlayer(playerItem: item)
            avPlayer.automaticallyWaitsToMinimizeStalling = true
            self.player = avPlayer
            self.duration = Double(max(1, video.durationSeconds))

            let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
            let vidId = video.id
            let fallbackDur = Double(max(1, video.durationSeconds))
            self.timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                MainActor.assumeIsolated {
                    let secs = CMTimeGetSeconds(time)
                    if secs.isFinite && secs >= 0 {
                        self.currentTime = secs
                    }
                    if let itemDur = avPlayer.currentItem?.duration {
                        let d = CMTimeGetSeconds(itemDur)
                        if d.isFinite && d > 1 {
                            self.duration = d
                        }
                    }
                    let effectiveDuration = max(self.duration, fallbackDur)
                    if effectiveDuration > 0 && (self.currentTime / effectiveDuration) >= 0.85 {
                        self.vm.markVideoWatched(vidId)
                    }
                }
            }

            self.endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    self.isPlaying = false
                    self.vm.markVideoWatched(vidId)
                }
            }
        }

        isActivated = true
        player?.playImmediately(atRate: playbackRate)
        isPlaying = true
    }

    private func togglePlayPause() {
        guard let player else {
            activateAndPlay()
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            let total = max(duration, Double(max(1, video.durationSeconds)))
            if currentTime >= total - 0.5 {
                seek(to: 0)
            }
            player.playImmediately(atRate: playbackRate)
            isPlaying = true
        }
    }

    private func seek(to seconds: Double) {
        guard let player else { return }
        let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = max(0, seconds)
    }

    private func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    private func teardownPlayer() {
        if let token = timeObserverToken, let player {
            player.removeTimeObserver(token)
        }
        timeObserverToken = nil
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        endObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#if canImport(UIKit)
private struct AcademyFullscreenVideoSheet: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.entersFullScreenWhenPlaybackBegins = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
#endif
