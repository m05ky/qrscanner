import UIKit
import ZXingCpp

/// Renders any supported symbology to an image using ZXing-cpp.
enum CodeGenerator {

    struct EncodeFailure: Error {
        let format: CodeFormat
    }

    /// Strips whitespace for numeric-only symbologies so "4006 3810" style input works.
    static func normalize(_ format: CodeFormat, _ text: String) -> String {
        switch format {
        case .EAN_8, .EAN_13, .UPC_A, .UPC_E, .ITF:
            return String(text.filter { !$0.isWhitespace })
        case .CODE_39, .CODE_93:
            return text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        default:
            return text
        }
    }

    private static func zxingFormat(_ f: CodeFormat) -> ZXIFormat {
        switch f {
        case .QR_CODE: return .QR_CODE
        case .EAN_8: return .EAN_8
        case .EAN_13: return .EAN_13
        case .UPC_E: return .UPC_E
        case .UPC_A: return .UPC_A
        case .CODE_39: return .CODE_39
        case .CODE_93: return .CODE_93
        case .CODE_128: return .CODE_128
        case .ITF: return .ITF
        case .PDF_417: return .PDF_417
        case .CODABAR: return .CODABAR
        case .DATA_MATRIX: return .DATA_MATRIX
        case .AZTEC: return .AZTEC
        }
    }

    /// Throws EncodeFailure when the text is invalid for the chosen format.
    static func image(_ text: String, format: CodeFormat, size: Int = 900) throws -> UIImage {
        var width = size
        var height = size
        if format.is1D || format == .PDF_417 { height = size / 3 }
        var margin: Int32 = -1
        var ecLevel: Int32 = -1
        switch format {
        case .QR_CODE:
            margin = 3
            ecLevel = QR_ERROR_CORRECTION_MEDIUM
        case .AZTEC, .DATA_MATRIX, .PDF_417:
            margin = 2
        default:
            break
        }
        if text.isEmpty { throw EncodeFailure(format: format) }
        let options = ZXIWriterOptions(format: zxingFormat(format), width: Int32(width), height: Int32(height), ecLevel: ecLevel, margin: margin)
        guard let ref = try? ZXIBarcodeWriter(options: options).write(text) else {
            throw EncodeFailure(format: format)
        }
        let cg = ref.takeRetainedValue()
        width = cg.width
        height = cg.height
        return redrawOpaque(cg, width: width, height: height)
    }

    static func imageOrNil(_ text: String, format: CodeFormat, size: Int = 900) -> UIImage? {
        return try? image(text, format: format, size: size)
    }

    /// The writer returns an 8 bit gray image; convert it to a regular opaque RGB image so saving / sharing behaves.
    private static func redrawOpaque(_ cg: CGImage, width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: CGPoint.zero, size: size))
            ctx.cgContext.interpolationQuality = .none
            UIImage(cgImage: cg).draw(in: CGRect(origin: CGPoint.zero, size: size))
        }
    }
}
