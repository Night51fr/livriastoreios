import SwiftUI
import UIKit

// MARK: - Viple & Moi (Espace Client v4) Design System & Palette

public enum VemTheme {
    // Core Brand Colors
    public static let vipleEmerald = Color(red: 0.078, green: 0.325, blue: 0.275)       // #145346
    public static let vipleMint = Color(red: 0.063, green: 0.725, blue: 0.506)          // #10B981
    public static let electricIndigo = Color(red: 0.310, green: 0.275, blue: 0.898)     // #4F46E5
    public static let vibrantViolet = Color(red: 0.486, green: 0.227, blue: 0.929)      // #7C3AED
    public static let warmCoral = Color(red: 0.957, green: 0.247, blue: 0.369)          // #F43F5E
    public static let solarAmber = Color(red: 0.961, green: 0.620, blue: 0.043)         // #F59E0B
    public static let oceanSky = Color(red: 0.008, green: 0.518, blue: 0.780)           // #0284C7
    public static let lagoonTeal = Color(red: 0.051, green: 0.580, blue: 0.533)         // #0D9488
    public static let payPalBlue = Color(red: 0.000, green: 0.439, blue: 0.729)         // #0070BA

    // Adaptive Surfaces
    public static let pageBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.047, green: 0.063, blue: 0.106, alpha: 1.0)
            : UIColor(red: 0.953, green: 0.965, blue: 0.988, alpha: 1.0)
    })

    public static let cardSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.094, green: 0.118, blue: 0.184, alpha: 1.0)
            : UIColor.white
    })

    public static let elevatedSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.129, green: 0.161, blue: 0.243, alpha: 1.0)
            : UIColor(red: 0.973, green: 0.980, blue: 0.996, alpha: 1.0)
    })

    public static let subtleBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.10)
            : UIColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 0.08)
    })

    // Gradients
    public static let auroraHeroGradient = LinearGradient(
        colors: [
            Color(red: 0.055, green: 0.255, blue: 0.216),
            Color(red: 0.086, green: 0.310, blue: 0.388),
            Color(red: 0.216, green: 0.188, blue: 0.639)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let vibrantActionGradient = LinearGradient(
        colors: [vipleEmerald, lagoonTeal, electricIndigo],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Springs
    public static let snappySpring = Animation.spring(response: 0.34, dampingFraction: 0.78)
    public static let bouncySpring = Animation.spring(response: 0.46, dampingFraction: 0.70)
    public static let smoothSpring = Animation.spring(response: 0.55, dampingFraction: 0.84)
}

// MARK: - Dynamic Service Accent Theme Palette

public struct VemAccentPalette: Sendable {
    public let primary: Color
    public let secondary: Color
    public let softFill: Color

    public var gradient: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public static func resolve(_ theme: String?) -> VemAccentPalette {
        switch (theme ?? "indigo").lowercased() {
        case "emerald":
            return VemAccentPalette(
                primary: VemTheme.vipleEmerald,
                secondary: VemTheme.vipleMint,
                softFill: VemTheme.vipleMint.opacity(0.14)
            )
        case "coral":
            return VemAccentPalette(
                primary: VemTheme.warmCoral,
                secondary: VemTheme.solarAmber,
                softFill: VemTheme.warmCoral.opacity(0.14)
            )
        case "teal":
            return VemAccentPalette(
                primary: VemTheme.lagoonTeal,
                secondary: VemTheme.oceanSky,
                softFill: VemTheme.lagoonTeal.opacity(0.14)
            )
        case "amber":
            return VemAccentPalette(
                primary: Color(red: 0.851, green: 0.467, blue: 0.024),
                secondary: VemTheme.solarAmber,
                softFill: VemTheme.solarAmber.opacity(0.15)
            )
        case "sky":
            return VemAccentPalette(
                primary: VemTheme.oceanSky,
                secondary: VemTheme.electricIndigo,
                softFill: VemTheme.oceanSky.opacity(0.14)
            )
        case "violet":
            return VemAccentPalette(
                primary: VemTheme.vibrantViolet,
                secondary: VemTheme.warmCoral,
                softFill: VemTheme.vibrantViolet.opacity(0.14)
            )
        default:
            return VemAccentPalette(
                primary: VemTheme.electricIndigo,
                secondary: VemTheme.vibrantViolet,
                softFill: VemTheme.electricIndigo.opacity(0.14)
            )
        }
    }
}

// MARK: - Color Hex Initializer

public extension Color {
    init(vemHex hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var intVal: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&intVal)
        let r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (r, g, b) = ((intVal >> 8) * 17, (intVal >> 4 & 0xF) * 17, (intVal & 0xF) * 17)
        case 6, 8:
            (r, g, b) = (intVal >> 16 & 0xFF, intVal >> 8 & 0xFF, intVal & 0xFF)
        default:
            (r, g, b) = (79, 70, 229)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Formatting & SF Symbols Mapping

public enum VemFormat {
    public static func euros(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let num = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        return "\(num) €"
    }

    public static func decimal(_ val: Double, maxFraction: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFraction
        return formatter.string(from: NSNumber(value: val)) ?? "\(val)"
    }

    public static func frenchDate(_ rawIso: String?) -> String {
        guard let rawIso, !rawIso.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackIso = ISO8601DateFormatter()
        if let date = iso.date(from: rawIso) ?? fallbackIso.date(from: rawIso) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "fr_FR")
            out.dateStyle = .medium
            out.timeStyle = .none
            return out.string(from: date)
        }
        return String(rawIso.prefix(10))
    }

    public static func sfSymbol(for iconName: String?, category: String? = nil) -> String {
        switch (iconName ?? "").lowercased() {
        case "mail", "inbox":
            return "envelope.badge.shield.half.filled"
        case "gamepad":
            return "gamecontroller.fill"
        case "server":
            return "server.rack"
        case "cpu":
            return "cpu.fill"
        case "wifi":
            return "wifi.router.fill"
        case "radio":
            return "antenna.radiowaves.left.and.right"
        case "tv", "film":
            return "tv.and.mediabox.fill"
        case "smartphone":
            return "iphone.gen3"
        case "globe":
            return "globe.europe.africa.fill"
        case "phone":
            return "phone.connection.fill"
        case "book", "bookopen":
            return "books.vertical.fill"
        case "shield":
            return "checkmark.shield.fill"
        case "hard-drive":
            return "internaldrive.fill"
        case "zap":
            return "bolt.shield.fill"
        case "lock":
            return "lock.shield.fill"
        case "plane":
            return "airplane.departure"
        case "rocket":
            return "sparkles"
        default:
            switch (category ?? "").lowercased() {
            case "cloud-vps", "vps", "serveur-dedie":
                return "server.rack"
            case "box-5g":
                return "wifi.router.fill"
            case "decodeur-tv":
                return "tv.and.mediabox.fill"
            case "forfait-mobile":
                return "iphone.gen3"
            case "telephonie-sip":
                return "phone.connection.fill"
            case "hebergement-web":
                return "globe"
            case "messagerie-incluse":
                return "envelope.badge.shield.half.filled"
            case "ecosysteme-looby":
                return "books.vertical.fill"
            default:
                return "sparkles.rectangle.stack.fill"
            }
        }
    }

    public static func categoryDisplayTitle(_ category: String) -> String {
        switch category.lowercased() {
        case "all": return "Toutes les offres"
        case "cloud-vps": return "Cloud & Gaming VPS"
        case "box-5g": return "Box 5G Zéro Fibre"
        case "decodeur-tv": return "StreamBox TV 4K"
        case "forfait-mobile": return "Forfaits Mobiles 5G"
        case "hebergement-web": return "Web & Domaines"
        case "telephonie-sip": return "Téléphonie Fixe"
        case "ecosysteme-looby": return "Livria & Looby+"
        case "messagerie-incluse": return "Viple Mail Inclus"
        default: return category.capitalized
        }
    }
}

// MARK: - Haptic Feedback Helper

@MainActor
public enum VemHaptics {
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }

    public static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    public static func warning() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
    }

    public static func error() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.error)
    }

    public static func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.selectionChanged()
    }
}

// MARK: - Tactile Pressable Card & Button Styles

public struct VemPressableButtonStyle: ButtonStyle {
    public var scaleAmount: CGFloat = 0.965

    public init(scaleAmount: CGFloat = 0.965) {
        self.scaleAmount = scaleAmount
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(VemTheme.snappySpring, value: configuration.isPressed)
    }
}

public struct VemCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 22
    public var padding: CGFloat = 18

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(VemTheme.cardSurface)
                    .shadow(color: Color.black.opacity(0.055), radius: 14, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(VemTheme.subtleBorder, lineWidth: 1)
            )
    }
}

public extension View {
    func vemCard(cornerRadius: CGFloat = 22, padding: CGFloat = 18) -> some View {
        modifier(VemCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Status Pill Badge

public struct VemStatusPill: View {
    public enum Tone: Sendable {
        case emerald, indigo, sky, amber, coral, violet
    }

    public let text: String
    public let tone: Tone
    public var icon: String? = nil

    public init(_ text: String, tone: Tone = .emerald, icon: String? = nil) {
        self.text = text
        self.tone = tone
        self.icon = icon
    }

    private var colors: (fg: Color, bg: Color) {
        switch tone {
        case .emerald:
            return (Color(red: 0.04, green: 0.52, blue: 0.36), VemTheme.vipleMint.opacity(0.16))
        case .indigo:
            return (VemTheme.electricIndigo, VemTheme.electricIndigo.opacity(0.14))
        case .sky:
            return (VemTheme.oceanSky, VemTheme.oceanSky.opacity(0.14))
        case .amber:
            return (Color(red: 0.78, green: 0.42, blue: 0.02), VemTheme.solarAmber.opacity(0.18))
        case .coral:
            return (VemTheme.warmCoral, VemTheme.warmCoral.opacity(0.15))
        case .violet:
            return (VemTheme.vibrantViolet, VemTheme.vibrantViolet.opacity(0.15))
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(colors.fg)
        .padding(.horizontal, 9)
        .padding(.vertical, 4.5)
        .background(Capsule().fill(colors.bg))
    }
}
