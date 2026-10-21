import SwiftUI
import AVFoundation

// MARK: - Convertisseur d'URL Livria Store (/covers/* -> https://livria.store/covers/*)

public enum LivriaURLResolver: Sendable {
    public static let baseWebURL = "https://livria.store"
    public static let socialWebURL = "https://livriasocial.viplenetwork.com"
    public static let identityWebURL = "https://identity-v2.viple.digital"
    public static let deliveryPickupURL = "https://delivery.viplenetwork.com/tools/listpickup?returnurl=https%3A%2F%2Flivria.store%2F"
    public static let deliveryTrackingBaseURL = "https://delivery.viplenetwork.com/?track="
    public static let assistanceWebURL = "https://assistance.viplenetwork.com"

    /// Convertit systématiquement tout lien commençant par `/` (ex: `/covers/978...jpg`) en `https://livria.store/...`
    public static func resolve(_ rawPath: String?) -> URL? {
        guard let raw = rawPath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
            return URL(string: raw)
        }
        if raw.hasPrefix("//") {
            return URL(string: "https:" + raw)
        }
        if raw.hasPrefix("/") {
            return URL(string: baseWebURL + raw)
        }
        return URL(string: baseWebURL + "/" + raw)
    }

    public static func resolveString(_ rawPath: String?) -> String {
        resolve(rawPath)?.absoluteString ?? ""
    }
}

// MARK: - Thème & Palette Livria Store (iOS 18+ MeshGradient & iOS 26 Liquid Glass)

public enum LivriaPalette: Sendable {
    public static let background = Color(red: 0.984, green: 0.969, blue: 1.000)       // #FBF7FF
    public static let backgroundAlt = Color(red: 0.953, green: 0.925, blue: 1.000)    // #F3ECFF
    public static let cardPaper = Color(red: 1.000, green: 0.992, blue: 0.976)        // #FFFDF9
    public static let primary = Color(red: 0.486, green: 0.302, blue: 1.000)          // #7C4DFF
    public static let primaryDeep = Color(red: 0.369, green: 0.208, blue: 0.694)      // #5E35B1
    public static let primarySoft = Color(red: 0.929, green: 0.898, blue: 1.000)      // #EDE5FF
    public static let coral = Color(red: 1.000, green: 0.373, blue: 0.635)            // #FF5FA2
    public static let gold = Color(red: 0.961, green: 0.620, blue: 0.043)             // #F59E0B
    public static let goldSoft = Color(red: 0.996, green: 0.953, blue: 0.780)         // #FEF3C7
    public static let mint = Color(red: 0.063, green: 0.725, blue: 0.506)             // #10B981
    public static let usedAmber = Color(red: 0.851, green: 0.467, blue: 0.024)        // #D97706 (Occasion)
    public static let usedAmberSoft = Color(red: 0.996, green: 0.953, blue: 0.780)    // #FEF3C7
    public static let ink = Color(red: 0.114, green: 0.082, blue: 0.200)              // #1D1533
    public static let inkMuted = Color(red: 0.373, green: 0.333, blue: 0.478)         // #5F557A
    public static let border = Color(red: 0.486, green: 0.302, blue: 1.000).opacity(0.14)

    public static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.180, green: 0.063, blue: 0.396),
                Color(red: 0.486, green: 0.302, blue: 1.000),
                Color(red: 0.859, green: 0.153, blue: 0.467)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var loobyPlusGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.118, green: 0.106, blue: 0.294),
                Color(red: 0.369, green: 0.208, blue: 0.694),
                Color(red: 0.706, green: 0.325, blue: 0.035)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Fond Dynamique iOS 18 MeshGradient & iOS 26 Liquid Glass

public struct LivriaMeshHeroBackground: View {
    public init() {}

    public var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.55, 0.45), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.16, green: 0.05, blue: 0.38),
                Color(red: 0.39, green: 0.18, blue: 0.82),
                Color(red: 0.58, green: 0.20, blue: 0.68),
                Color(red: 0.28, green: 0.12, blue: 0.64),
                Color(red: 0.49, green: 0.30, blue: 1.00),
                Color(red: 0.86, green: 0.18, blue: 0.48),
                Color(red: 0.19, green: 0.08, blue: 0.44),
                Color(red: 0.42, green: 0.22, blue: 0.78),
                Color(red: 0.72, green: 0.24, blue: 0.52)
            ]
        )
    }
}

// MARK: - Thèmes d'arrière-plan personnalisés Livria Store (voile 60-80%)

public struct LivriaSiteThemeOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let colors: [Color]
    public let icon: String

    public static let all: [LivriaSiteThemeOption] = [
        .init(id: "default", name: "Lavande Classique", subtitle: "Thème original Livria Store", colors: [LivriaPalette.background, LivriaPalette.backgroundAlt], icon: "sparkles"),
        .init(id: "parchment", name: "Parchemin d'Alexandrie", subtitle: "Ambiance librairie ancienne", colors: [Color(red: 0.96, green: 0.90, blue: 0.78), Color(red: 0.89, green: 0.78, blue: 0.62)], icon: "book.closed.fill"),
        .init(id: "sakura", name: "Brume de Sakura", subtitle: "Douceur florale japonaise", colors: [Color(red: 0.99, green: 0.86, blue: 0.92), Color(red: 0.93, green: 0.79, blue: 0.96)], icon: "leaf.fill"),
        .init(id: "aurora", name: "Aurore Boréale", subtitle: "Reflets célestes émeraude & violet", colors: [Color(red: 0.78, green: 0.95, blue: 0.91), Color(red: 0.82, green: 0.80, blue: 0.98)], icon: "moon.stars.fill"),
        .init(id: "emerald", name: "Cabinet d'Émeraude", subtitle: "Salon de lecture feutré", colors: [Color(red: 0.80, green: 0.93, blue: 0.86), Color(red: 0.69, green: 0.87, blue: 0.80)], icon: "lamp.desk.fill"),
        .init(id: "sunset", name: "Crépuscule Doré", subtitle: "Lumière chaude de fin d'après-midi", colors: [Color(red: 0.99, green: 0.88, blue: 0.76), Color(red: 0.98, green: 0.78, blue: 0.84)], icon: "sun.and.horizon.fill"),
        .init(id: "ocean", name: "Odyssée Égée", subtitle: "Horizon marin apaisant", colors: [Color(red: 0.79, green: 0.91, blue: 0.99), Color(red: 0.72, green: 0.84, blue: 0.98)], icon: "water.waves"),
        .init(id: "cosmos", name: "Nébuleuse Nocturne", subtitle: "Voûte étoilée pastel", colors: [Color(red: 0.84, green: 0.80, blue: 0.99), Color(red: 0.76, green: 0.85, blue: 0.99)], icon: "sparkle.magnifyingglass")
    ]

    public static func option(for id: String) -> LivriaSiteThemeOption {
        all.first(where: { $0.id == id.lowercased() }) ?? all[0]
    }
}

public struct LivriaThemedBackground: ViewModifier {
    let themeId: String

    public func body(content: Content) -> some View {
        let opt = LivriaSiteThemeOption.option(for: themeId)
        ZStack {
            LinearGradient(colors: opt.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            // Voile semi-transparent 72% (60-80%) pour garantir une lisibilité parfaite
            LivriaPalette.background.opacity(opt.id == "default" ? 0.92 : 0.72)
                .ignoresSafeArea()
            content
        }
    }
}

extension View {
    public func livriaThemedBackground(_ themeId: String) -> some View {
        modifier(LivriaThemedBackground(themeId: themeId))
    }

    /// Applique un style de carte Livria Store natif avec prise en charge d'iOS 26 Liquid Glass lorsque disponible
    @ViewBuilder
    public func livriaCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LivriaPalette.cardPaper.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(LivriaPalette.border, lineWidth: 1)
                )
                .shadow(color: LivriaPalette.primary.opacity(0.07), radius: 14, x: 0, y: 6)
        } else {
            self
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LivriaPalette.cardPaper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(LivriaPalette.border, lineWidth: 1)
                )
                .shadow(color: LivriaPalette.primary.opacity(0.06), radius: 12, x: 0, y: 5)
        }
    }
}

// MARK: - Composant Couverture de Livre avec Résolution Automatique `/covers/*` -> `https://livria.store/covers/*`

public struct LivriaBookCoverView: View {
    public let coverUrl: String?
    public let title: String
    public var width: CGFloat = 96
    public var height: CGFloat = 142
    public var cornerRadius: CGFloat = 12

    public init(coverUrl: String?, title: String, width: CGFloat = 96, height: CGFloat = 142, cornerRadius: CGFloat = 12) {
        self.coverUrl = coverUrl
        self.title = title
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let resolvedURL = LivriaURLResolver.resolve(coverUrl)
        ZStack {
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackCover
                    case .empty:
                        ZStack {
                            fallbackCover.opacity(0.55)
                            ProgressView()
                                .tint(.white)
                        }
                    @unknown default:
                        fallbackCover
                    }
                }
            } else {
                fallbackCover
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 4)
    }

    private var fallbackCover: some View {
        ZStack {
            LinearGradient(
                colors: [LivriaPalette.primaryDeep, LivriaPalette.primary, LivriaPalette.coral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: min(width * 0.28, 26), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(title)
                    .font(.system(size: max(min(width * 0.11, 12), 9), weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 6)
            }
        }
    }
}

// MARK: - Anneau de Niveau & Avatar Strictement Circulaire (LevelRingView)

public struct LevelRingView: View {
    public let avatarUrl: String?
    public let displayName: String
    public let level: Int
    public let xp: Int
    public var size: CGFloat = 76

    public init(avatarUrl: String?, displayName: String, level: Int, xp: Int, size: CGFloat = 76) {
        self.avatarUrl = avatarUrl
        self.displayName = displayName
        self.level = level
        self.xp = xp
        self.size = size
    }

    private var progressInLevel: Double {
        let remainder = xp % 200
        return Double(remainder) / 200.0
    }

    public var body: some View {
        let innerSize = size - 12
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .stroke(LivriaPalette.primary.opacity(0.18), lineWidth: 4.5)
                    .frame(width: size, height: size)

                Circle()
                    .trim(from: 0, to: max(0.08, progressInLevel))
                    .stroke(
                        AngularGradient(
                            colors: [LivriaPalette.primary, LivriaPalette.coral, LivriaPalette.gold, LivriaPalette.primary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)

                avatarContent(innerSize: innerSize)
                    .frame(width: innerSize, height: innerSize)
                    .clipShape(Circle())
                    .contentShape(Circle())
            }

            Text("Niv. \(level)")
                .font(.system(size: max(10, size * 0.14), weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .leading, endPoint: .trailing))
                )
                .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
                .offset(x: 4, y: 4)
        }
    }

    @ViewBuilder
    private func avatarContent(innerSize: CGFloat) -> some View {
        if let url = LivriaURLResolver.resolve(avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .scaledToFill()
                        .frame(width: innerSize, height: innerSize)
                        .clipped()
                default:
                    initialsBubble(innerSize: innerSize)
                }
            }
        } else {
            initialsBubble(innerSize: innerSize)
        }
    }

    private func initialsBubble(innerSize: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(displayName.prefix(1)).uppercased())
                .font(.system(size: innerSize * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: innerSize, height: innerSize)
    }
}

// MARK: - Générateur d'Ambiance Sonore Littéraire (Pluie, Cheminée, Café) pour la Fiche Livre

@MainActor
public final class LivriaAmbientSoundPlayer: ObservableObject {
    @Published public private(set) var activePreset: String? = nil
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var filterState: Float = 0.0

    public init() {}

    public func toggle(preset: String) {
        if activePreset == preset {
            stop()
        } else {
            start(preset: preset)
        }
    }

    public func start(preset: String) {
        stop()
        let audioEngine = AVAudioEngine()
        let mainMixer = audioEngine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100)

        let mode = preset.lowercased()
        let node = Self.buildSourceNode(mode: mode, sampleRate: sampleRate)

        audioEngine.attach(node)
        audioEngine.connect(node, to: mainMixer, format: outputFormat)
        do {
            try audioEngine.start()
            self.engine = audioEngine
            self.sourceNode = node
            self.activePreset = preset
        } catch {
            self.activePreset = nil
        }
    }

    nonisolated private static func buildSourceNode(mode: String, sampleRate: Float) -> AVAudioSourceNode {
        var lpf: Float = 0.0
        var phase: Float = 0.0
        return AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let white = Float.random(in: -1.0...1.0)
                let alpha: Float = mode.contains("pluie") ? 0.14 : (mode.contains("chemin") ? 0.06 : 0.10)
                lpf = lpf + alpha * (white - lpf)
                phase += 1.0 / sampleRate
                let crackle: Float = (mode.contains("chemin") && Float.random(in: 0...1) > 0.996) ? Float.random(in: -0.35...0.35) : 0.0
                let sample = max(-0.25, min(0.25, (lpf * 0.18) + crackle))
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    if frame < buf.count {
                        buf[frame] = sample
                    }
                }
            }
            return noErr
        }
    }

    public func stop() {
        engine?.stop()
        engine = nil
        sourceNode = nil
        activePreset = nil
    }
}

// MARK: - Feuille de Recherche & Scan ISBN (Google Books + OpenLibrary + Catalogue Livria Store)

public struct LivriaISBNScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel

    public var onSelectCatalogBook: ((LivriaBook) -> Void)?
    public var onSelectISBNResult: ((LivriaISBNLookupResponse) -> Void)?

    @State private var isbnInput: String = ""
    @State private var isSearching: Bool = false
    @State private var lookupResult: LivriaISBNLookupResponse? = nil
    @State private var errorMessage: String? = nil

    public init(
        onSelectCatalogBook: ((LivriaBook) -> Void)? = nil,
        onSelectISBNResult: ((LivriaISBNLookupResponse) -> Void)? = nil
    ) {
        self.onSelectCatalogBook = onSelectCatalogBook
        self.onSelectISBNResult = onSelectISBNResult
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // Visuel Scanner Code-barres EAN-13
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LivriaPalette.heroGradient)
                                .frame(height: 156)

                            VStack(spacing: 8) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 52, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Scanner ou saisir un code ISBN-13")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Recherche instantanée dans Livria Store, Google Books & OpenLibrary")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        }

                        HStack(spacing: 10) {
                            HStack {
                                Image(systemName: "barcode")
                                    .foregroundStyle(LivriaPalette.primary)
                                TextField("Ex: 9782070368228 ou 9782253004226", text: $isbnInput)
                                    .keyboardType(.numbersAndPunctuation)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))

                            Button {
                                performSearch()
                            } label: {
                                if isSearching {
                                    ProgressView().tint(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                } else {
                                    Text("Rechercher")
                                        .font(.system(size: 14, weight: .bold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                            .foregroundStyle(.white)
                            .disabled(isbnInput.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                        }
                    }
                    .livriaCard()

                    if let err = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(err)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LivriaPalette.ink)
                        }
                        .livriaCard()
                    }

                    if let res = lookupResult, res.ok {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 14) {
                                LivriaBookCoverView(
                                    coverUrl: res.coverUrl ?? res.catalogBook?.coverUrl,
                                    title: res.title ?? res.catalogBook?.title ?? "Livre",
                                    width: 90,
                                    height: 132,
                                    cornerRadius: 12
                                )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(res.inCatalog ? "Disponible dans Livria Store" : "Identifié via Google Books / OpenLibrary")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(res.inCatalog ? LivriaPalette.mint.opacity(0.18) : LivriaPalette.primarySoft))
                                        .foregroundStyle(res.inCatalog ? LivriaPalette.mint : LivriaPalette.primary)

                                    Text(res.title ?? res.catalogBook?.title ?? "")
                                        .font(.system(size: 17, weight: .bold, design: .serif))
                                        .foregroundStyle(LivriaPalette.ink)

                                    Text(res.author ?? res.catalogBook?.author ?? "")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundStyle(LivriaPalette.inkMuted)

                                    if let isbn = res.isbn {
                                        Text("ISBN : \(isbn)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(LivriaPalette.inkMuted)
                                    }
                                }
                            }

                            if let catBook = res.catalogBook, let onSelectCatalogBook {
                                Button {
                                    dismiss()
                                    onSelectCatalogBook(catBook)
                                } label: {
                                    Label("Ouvrir la fiche dans la Boutique (\(String(format: "%.2f €", catBook.price)))", systemImage: "bag.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                                        .foregroundStyle(.white)
                                }
                            }

                            if let onSelectISBNResult {
                                Button {
                                    onSelectISBNResult(res)
                                    dismiss()
                                } label: {
                                    Label("Utiliser cet ouvrage pour mon annonce de Troc", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.coral))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .livriaCard()
                    }
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Scanner / ISBN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func performSearch() {
        errorMessage = nil
        lookupResult = nil
        isSearching = true
        Task {
            if let res = await store.lookupBookByISBN(isbn: isbnInput), res.ok {
                lookupResult = res
            } else {
                errorMessage = "Aucun livre trouvé pour cet ISBN. Vérifiez les 10 ou 13 chiffres."
            }
            isSearching = false
        }
    }
}
