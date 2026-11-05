import Foundation

/// The symbologies the app can scan and create. Raw values are the labels shown in the UI and stored in the history.
enum CodeFormat: String, CaseIterable, Codable {
    case QR_CODE
    case EAN_8
    case EAN_13
    case UPC_E
    case UPC_A
    case CODE_39
    case CODE_93
    case CODE_128
    case ITF
    case PDF_417
    case CODABAR
    case DATA_MATRIX
    case AZTEC

    var label: String { rawValue }

    var is1D: Bool {
        switch self {
        case .QR_CODE, .PDF_417, .DATA_MATRIX, .AZTEC:
            return false
        default:
            return true
        }
    }

    /// Retail codes are shown as "Product" after scanning.
    var isProduct: Bool {
        return self == .EAN_8 || self == .EAN_13 || self == .UPC_A || self == .UPC_E
    }

    /// Formats listed under "Other types" in the create screen, in display order.
    static let otherTypes: [CodeFormat] = [
        .EAN_8, .EAN_13, .UPC_E, .UPC_A, .CODE_39, .CODE_93, .CODE_128, .ITF, .PDF_417, .CODABAR, .DATA_MATRIX, .AZTEC,
    ]

    static func fromLabel(_ label: String?) -> CodeFormat? {
        guard let label = label else { return nil }
        return CodeFormat(rawValue: label)
    }

    /// Name of the bundled preview image in the asset catalog.
    var previewImageName: String {
        return "code_" + rawValue.lowercased()
    }
}

enum ContentType {
    case text, url, wifi, contact, email, sms, geo, phone, event, product
}
