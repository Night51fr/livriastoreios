import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Système de Design Institutionnel « Cenelis Academy » (Pin Minéral #145346 & Cuivre Ambré #B85D19)

public enum AcademyThemeMode: String, CaseIterable, Identifiable, Sendable {
    case system = "Automatique"
    case light = "Clair Ivoire"
    case dark = "Sombre Minéral"

    public var id: String { rawValue }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public var sfSymbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
}

public enum AcademyPalette {
    // Couleurs de marque primaires (adaptatives Clair / Sombre)
    public static let pine = Color(dynamicLight: (0.078, 0.325, 0.275), dark: (0.196, 0.765, 0.612))          // #145346 / #32C39C
    public static let pineSolid = Color(red: 0.078, green: 0.325, blue: 0.275)                                 // #145346 fixe (fonds hero/boutons)
    public static let pineDeep = Color(red: 0.047, green: 0.204, blue: 0.173)                                  // #0C342C
    public static let pineSoft = Color(dynamicLight: (0.914, 0.961, 0.945), dark: (0.090, 0.215, 0.184))
    public static let pineBorder = Color(dynamicLight: (0.745, 0.882, 0.843), dark: (0.165, 0.380, 0.325))

    public static let copper = Color(dynamicLight: (0.722, 0.365, 0.098), dark: (0.945, 0.576, 0.235))        // #B85D19 / #F1933C
    public static let copperSolid = Color(red: 0.722, green: 0.365, blue: 0.098)
    public static let copperSoft = Color(dynamicLight: (0.992, 0.949, 0.902), dark: (0.245, 0.145, 0.075))
    public static let copperBorder = Color(dynamicLight: (0.953, 0.816, 0.678), dark: (0.485, 0.285, 0.145))

    public static let gold = Color(red: 0.945, green: 0.733, blue: 0.212)                                      // #F1BB36
    public static let sky = Color(dynamicLight: (0.012, 0.412, 0.631), dark: (0.220, 0.741, 0.973))

    // Surfaces & Encres
    public static let background = Color(dynamicLight: (0.980, 0.973, 0.957), dark: (0.039, 0.082, 0.071))    // #FAF8F4 / #0A1512
    public static let surface = Color(dynamicLight: (1.000, 1.000, 1.000), dark: (0.071, 0.137, 0.118))       // #FFFFFF / #12231E
    public static let surfaceSubtle = Color(dynamicLight: (0.953, 0.945, 0.922), dark: (0.098, 0.180, 0.157))
    public static let border = Color(dynamicLight: (0.878, 0.867, 0.835), dark: (0.165, 0.267, 0.235))

    public static let ink = Color(dynamicLight: (0.075, 0.125, 0.110), dark: (0.949, 0.973, 0.965))
    public static let inkSecondary = Color(dynamicLight: (0.325, 0.392, 0.369), dark: (0.675, 0.765, 0.733))
    public static let inkMuted = Color(dynamicLight: (0.510, 0.569, 0.549), dark: (0.475, 0.569, 0.537))

    public static let success = Color(dynamicLight: (0.082, 0.502, 0.239), dark: (0.204, 0.827, 0.600))
    public static let successSoft = Color(dynamicLight: (0.925, 0.992, 0.961), dark: (0.075, 0.235, 0.175))
    public static let danger = Color(dynamicLight: (0.725, 0.110, 0.110), dark: (0.973, 0.443, 0.443))
    public static let dangerSoft = Color(dynamicLight: (0.996, 0.949, 0.949), dark: (0.255, 0.095, 0.095))

    public static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.090, green: 0.365, blue: 0.306),
                Color(red: 0.051, green: 0.220, blue: 0.184),
                Color(red: 0.035, green: 0.145, blue: 0.122)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var copperGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.847, green: 0.447, blue: 0.157),
                Color(red: 0.659, green: 0.314, blue: 0.071)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(dynamicLight light: (Double, Double, Double), dark: (Double, Double, Double)) {
        #if canImport(UIKit)
        self.init(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: dark.0, green: dark.1, blue: dark.2, alpha: 1.0)
            } else {
                return UIColor(red: light.0, green: light.1, blue: light.2, alpha: 1.0)
            }
        })
        #else
        self.init(red: light.0, green: light.1, blue: light.2)
        #endif
    }
}

// MARK: - Correspondance Native SF Symbols (55+ icônes du référentiel web Cenelis Academy)

public enum AcademyIcons {
    public static func sfSymbol(for webName: String?) -> String {
        guard let raw = webName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "book.closed.fill"
        }
        switch raw {
        case "graduationCap": return "graduationcap.fill"
        case "landmark": return "building.columns.fill"
        case "building": return "building.2.fill"
        case "cpu": return "cpu.fill"
        case "server": return "server.rack"
        case "database": return "externaldrive.fill.badge.checkmark"
        case "terminal": return "terminal.fill"
        case "bookOpen": return "book.fill"
        case "users": return "person.3.fill"
        case "userCheck": return "person.badge.shield.checkmark.fill"
        case "shieldCheck": return "checkmark.shield.fill"
        case "sliders": return "slider.horizontal.3"
        case "scale": return "scalemass.fill"
        case "heartHandshake": return "hands.sparkles.fill"
        case "award": return "medal.fill"
        case "target": return "target"
        case "globe": return "globe.europe.africa.fill"
        case "compass": return "safari.fill"
        case "layers": return "square.3.layers.3d.down.right"
        case "layersPlus": return "square.stack.3d.up.fill"
        case "sparkles": return "sparkles"
        case "briefcase": return "briefcase.fill"
        case "megaphone": return "megaphone.fill"
        case "phoneCall": return "phone.arrow.up.right.fill"
        case "messageSquare": return "bubble.left.and.bubble.right.fill"
        case "fileText": return "doc.text.fill"
        case "wifi": return "antenna.radiowaves.left.and.right"
        case "trendingUp": return "chart.line.uptrend.xyaxis"
        case "alertTriangle": return "exclamationmark.triangle.fill"
        case "checkCircle", "check": return "checkmark.circle.fill"
        case "clock": return "clock.fill"
        case "monitor": return "desktopcomputer"
        case "smartphone": return "iphone"
        case "zoomIn": return "plus.magnifyingglass"
        case "lightbulb": return "lightbulb.max.fill"
        case "helpCircle": return "questionmark.circle.fill"
        case "lock": return "lock.shield.fill"
        case "key": return "key.fill"
        case "mail": return "envelope.fill"
        case "store": return "storefront.fill"
        case "truck": return "shippingbox.and.arrow.backward.fill"
        case "home": return "house.fill"
        case "mousePointer": return "cursorarrow.click.2"
        case "info": return "info.circle.fill"
        case "refreshCw": return "arrow.clockwise"
        case "arrowRight": return "arrow.right"
        case "arrowLeft": return "arrow.left"
        case "list": return "list.bullet.indent"
        case "video", "film", "playCircle": return "play.rectangle.fill"
        case "play": return "play.fill"
        case "wand", "wandSparkles": return "wand.and.stars"
        case "eye": return "eye.fill"
        case "package": return "shippingbox.fill"
        case "shield": return "shield.lefthalf.filled"
        case "gamepad": return "gamecontroller.fill"
        case "tv": return "tv.fill"
        case "search": return "magnifyingglass"
        case "calendar": return "calendar"
        case "radio": return "dot.radiowaves.left.and.right"
        case "unlock": return "lock.open.fill"
        case "scanBarcode", "qrCode": return "qrcode.viewfinder"
        case "creditCard": return "creditcard.fill"
        case "receipt", "calculator": return "doc.text.magnifyingglass"
        case "kanban", "columns", "layout", "grid": return "square.grid.2x2.fill"
        case "workflow", "gitBranch": return "point.topleft.down.to.point.bottomright.curvepath.fill"
        case "lifeBuoy", "headphones": return "headphones"
        case "wrench", "settings", "cog": return "gearshape.2.fill"
        case "userPlus": return "person.badge.plus"
        case "building2": return "building.2.crop.circle.fill"
        case "clipboardCheck": return "checklist.checked"
        case "barChart", "pieChart", "activity": return "chart.bar.xaxis"
        case "chevronUp": return "chevron.up"
        case "chevronDown": return "chevron.down"
        case "chevronRight": return "chevron.right"
        case "chevronLeft": return "chevron.left"
        case "externalLink": return "arrow.up.right.square"
        default: return "sparkles.rectangle.stack.fill"
        }
    }
}

// MARK: - Moteur Haptique Tactile

@MainActor
public enum AcademyHaptics {
    public static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    public static func light() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    public static func medium() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    public static func heavy() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }

    public static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    public static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    public static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}

// MARK: - Composants de Style Réutilisables (Boutons Ressort & Badges)

public struct SpringPressableButtonStyle: ButtonStyle {
    public var scale: CGFloat = 0.96

    public init(scale: CGFloat = 0.96) {
        self.scale = scale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

public enum AcademyBadgeStyle {
    case pine
    case copper
    case success
    case muted
    case gold
}

public struct AcademyBadge: View {
    public let text: String
    public var icon: String? = nil
    public var style: AcademyBadgeStyle = .pine

    public init(_ text: String, icon: String? = nil, style: AcademyBadgeStyle = .pine) {
        self.text = text
        self.icon = icon
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4.5)
        .foregroundStyle(foreground)
        .background(
            Capsule(style: .continuous)
                .fill(background)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                )
        )
    }

    private var foreground: Color {
        switch style {
        case .pine: return AcademyPalette.pine
        case .copper: return AcademyPalette.copper
        case .success: return AcademyPalette.success
        case .muted: return AcademyPalette.inkSecondary
        case .gold: return Color(red: 0.55, green: 0.36, blue: 0.02)
        }
    }

    private var background: Color {
        switch style {
        case .pine: return AcademyPalette.pineSoft
        case .copper: return AcademyPalette.copperSoft
        case .success: return AcademyPalette.successSoft
        case .muted: return AcademyPalette.surfaceSubtle
        case .gold: return AcademyPalette.gold.opacity(0.22)
        }
    }

    private var border: Color {
        switch style {
        case .pine: return AcademyPalette.pineBorder
        case .copper: return AcademyPalette.copperBorder
        case .success: return AcademyPalette.success.opacity(0.35)
        case .muted: return AcademyPalette.border
        case .gold: return AcademyPalette.gold.opacity(0.55)
        }
    }
}
