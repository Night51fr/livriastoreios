import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Direction Artistique Groupe Cenelis · Cenelis Workspace / Admin Hub

public enum WorkspaceTheme {
    // Couleurs institutionnelles Cenelis (adaptatives Clair / Sombre)
    public static let forest = Color(red: 0.106, green: 0.212, blue: 0.176)          // #1B362D
    public static let forestDeep = Color(red: 0.071, green: 0.145, blue: 0.118)      // #12251E
    public static let forestAccent = Color(red: 0.165, green: 0.455, blue: 0.365)    // #2A745D
    public static let terracotta = Color(red: 0.722, green: 0.365, blue: 0.231)      // #B85D3B
    public static let slate = Color(red: 0.118, green: 0.196, blue: 0.290)           // #1E324A
    public static let statusGreen = Color(red: 0.133, green: 0.773, blue: 0.369)     // #22C55E
    public static let statusAmber = Color(red: 0.961, green: 0.620, blue: 0.043)     // #F59E0B
    public static let statusRed = Color(red: 0.863, green: 0.149, blue: 0.149)       // #DC2626

    public static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.055, green: 0.082, blue: 0.075) // #0E1513
            : Color(red: 0.969, green: 0.965, blue: 0.949) // #F7F6F2
    }

    public static func secondaryBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.082, green: 0.118, blue: 0.108) // #151E1B
            : Color(red: 0.937, green: 0.925, blue: 0.902) // #EFECE6
    }

    public static func cardSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.098, green: 0.141, blue: 0.129) // #192421
            : Color(red: 0.992, green: 0.988, blue: 0.980) // #FDFCFA
    }

    public static func borderRule(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.11)
            : Color.black.opacity(0.11)
    }

    public static func primaryInk(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.957, green: 0.953, blue: 0.937)
            : Color(red: 0.067, green: 0.086, blue: 0.082)
    }

    public static func secondaryInk(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.710, green: 0.753, blue: 0.737)
            : Color(red: 0.255, green: 0.298, blue: 0.286)
    }

    public static func color(fromHex hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var intVal: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&intVal)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = ((intVal >> 16) & 0xFF, (intVal >> 8) & 0xFF, intVal & 0xFF)
        default:
            return forest
        }
        return Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}

// MARK: - Retours Haptiques Natifs iOS

@MainActor
public enum WorkspaceHaptics {
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

// MARK: - Correspondance SF Symbols Officielle des 24 Consoles & Outils Cenelis

public enum WorkspaceIcons {
    public static func sfSymbol(for iconKey: String, panelId: String = "") -> String {
        switch panelId {
        case "cenelis-connect": return "lock.shield.fill"
        case "cenelis-admingest": return "key.radiowaves.forward.fill"
        case "cenelis-academy": return "graduationcap.fill"
        case "viple-user-console": return "person.text.rectangle.fill"
        case "cenelis-2ddoc": return "qrcode.viewfinder"
        case "viple-contracts": return "signature"
        case "cenelis-recrute": return "briefcase.fill"
        case "cenelis-planner": return "calendar.badge.clock"
        case "cenelis-groupe": return "building.columns.fill"
        case "viple-sysgrc-master": return "server.rack"
        case "viple-sysgrc": return "chart.bar.doc.horizontal.fill"
        case "cenelis-marketing": return "megaphone.fill"
        case "cenelis-prospect": return "phone.arrow.up.right.fill"
        case "livria": return "books.vertical.fill"
        case "cenelis-newswire": return "newspaper.fill"
        case "viple-wingman": return "barcode.viewfinder"
        case "viple-gest-proct": return "slider.horizontal.3"
        case "viple-support": return "lifepreserver.fill"
        case "viple-delivery": return "shippingbox.and.arrow.backward.fill"
        case "viple-shortener": return "link.badge.plus"
        case "viple-visio": return "video.badge.checkmark"
        case "viple-mail": return "envelope.badge.shield.half.filled.fill"
        case "viple-live": return "person.badge.key.fill"
        case "viple-status": return "waveform.path.ecg"
        default: break
        }

        switch iconKey.lowercased() {
        case "shield": return "checkmark.shield.fill"
        case "key": return "key.fill"
        case "book", "graduation": return "book.closed.fill"
        case "users": return "person.2.fill"
        case "file-signature", "file-check": return "signature"
        case "briefcase": return "briefcase.fill"
        case "calendar": return "calendar"
        case "landmark": return "building.columns.fill"
        case "sliders": return "slider.horizontal.3"
        case "megaphone": return "megaphone.fill"
        case "phone": return "phone.fill"
        case "newspaper": return "newspaper.fill"
        case "box": return "shippingbox.fill"
        case "life-buoy", "lifebuoy": return "lifepreserver.fill"
        case "truck": return "truck.box.fill"
        case "link": return "link"
        case "video": return "video.fill"
        case "mail": return "envelope.fill"
        case "activity": return "waveform.path.ecg"
        case "layers": return "square.3.layers.3d.down.right"
        case "bubble": return "text.bubble.fill"
        case "terminal": return "terminal.fill"
        default: return "square.grid.2x2.fill"
        }
    }
}
