import SwiftUI
import UIKit

/// Inter, bundled in Resources/Fonts (SIL OFL).
enum Typo {
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:
            name = "Inter-Bold"
        case .semibold:
            name = "Inter-SemiBold"
        case .medium:
            name = "Inter-Medium"
        default:
            name = "Inter-Regular"
        }
        return Font.custom(name, size: size)
    }

    static let titleLarge = font(20, .semibold)
    static let titleMedium = font(16, .medium)
    static let bodyLarge = font(16)
    static let bodyMedium = font(14)
    static let bodySmall = font(12)
    static let labelMedium = font(12, .semibold)
}

/// Light / dark colors that follow the active color scheme.
enum Palette {
    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        return Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }

    static let background = dynamic(0xF3F3F3, 0x222222)
    static let surface = dynamic(0xFFFFFF, 0x1C1C1C)
    static let onSurface = dynamic(0x111111, 0xFFFFFF)
    static let variant = dynamic(0xE6E6E6, 0x2C2C2C)
    static let onVariant = dynamic(0x6F6F6F, 0xB0B0B0)
    static let outline = dynamic(0xE0E0E0, 0x333333)
    static let star = Color(red: 246.0 / 255.0, green: 191.0 / 255.0, blue: 38.0 / 255.0)
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1
        )
    }
}

extension AppSettings {
    private var accentValue: UInt32 {
        let i = min(max(colorIndex, 0), AppSettings.palette.count - 1)
        return AppSettings.palette[i] & 0xFFFFFF
    }

    var accent: Color { return Color(UIColor(rgb: accentValue)) }

    /// Text / icon color that stays readable on top of the accent color.
    var onAccent: Color {
        let v = accentValue
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        func lin(_ c: CGFloat) -> CGFloat { return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let lum = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        return lum > 0.45 ? Color(UIColor(rgb: 0x1B1B1B)) : Color.white
    }

    var colorScheme: ColorScheme? {
        switch theme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}

extension ContentType {
    var symbol: String {
        switch self {
        case .text: return "textformat"
        case .url: return "link"
        case .wifi: return "wifi"
        case .contact: return "person.fill"
        case .email: return "envelope.fill"
        case .sms: return "message.fill"
        case .geo: return "mappin.and.ellipse"
        case .phone: return "phone.fill"
        case .event: return "calendar"
        case .product: return "shippingbox.fill"
        }
    }

    var title: String {
        switch self {
        case .text: return L.t("type_text")
        case .url: return L.t("type_url")
        case .wifi: return L.t("type_wifi")
        case .contact: return L.t("type_contact")
        case .email: return L.t("type_email")
        case .sms: return L.t("type_sms")
        case .geo: return L.t("type_geo")
        case .phone: return L.t("type_phone")
        case .event: return L.t("type_event")
        case .product: return L.t("type_product")
        }
    }
}
