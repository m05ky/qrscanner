import UIKit
import Vision
import ZXingCpp

struct ScanHit {
    let text: String
    let format: CodeFormat
    let capture: ScanCapture?
}

extension CodeFormat {
    /// Maps Vision's symbology. UPC-A is reported as EAN-13 with a leading zero.
    static func fromVision(_ symbology: VNBarcodeSymbology, text: String) -> (CodeFormat, String) {
        switch symbology {
        case .qr:
            return (.QR_CODE, text)
        case .ean8:
            return (.EAN_8, text)
        case .ean13:
            if text.count == 13 && text.hasPrefix("0") { return (.UPC_A, String(text.dropFirst())) }
            return (.EAN_13, text)
        case .upce:
            return (.UPC_E, text)
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum:
            return (.CODE_39, text)
        case .code93, .code93i:
            return (.CODE_93, text)
        case .code128:
            return (.CODE_128, text)
        case .i2of5, .i2of5Checksum, .itf14:
            return (.ITF, text)
        case .pdf417, .microPDF417:
            return (.PDF_417, text)
        case .codabar:
            return (.CODABAR, text)
        case .dataMatrix:
            return (.DATA_MATRIX, text)
        case .aztec:
            return (.AZTEC, text)
        default:
            return (.QR_CODE, text)
        }
    }

    static func fromZXing(_ f: ZXIFormat) -> CodeFormat? {
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
        default: return nil
        }
    }
}

/// Decodes a picked image: Vision first, ZXing-cpp (try-harder, rotated, inverted) as a fallback.
enum ImageScanner {
    private static let queue = DispatchQueue(label: "com.allcodes.scan.image", qos: .userInitiated)
    private static let maxSide: CGFloat = 2800

    /// `completion` runs on the main thread with nil when nothing was found.
    static func scan(_ image: UIImage, completion: @escaping (ScanHit?) -> Void) {
        queue.async {
            let upright = CaptureBuilder.normalized(image, maxSide: maxSide)
            let hit = visionScan(upright) ?? zxingScan(upright)
            DispatchQueue.main.async { completion(hit) }
        }
    }

    /// Vision on an upright image; also used for camera frames. Returns the observation matching `payload` when given.
    static func visionScan(_ image: UIImage, onlyPayload: String? = nil) -> ScanHit? {
        guard let cg = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let observations: [VNBarcodeObservation] = (request.results ?? []).compactMap { $0 as? VNBarcodeObservation }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        for o in observations {
            guard let payload = o.payloadStringValue, !payload.isEmpty else { continue }
            let mapped = CodeFormat.fromVision(o.symbology, text: payload)
            if let wanted = onlyPayload, wanted != payload, wanted != mapped.1 { continue }
            // Vision's points are normalized with the origin at the bottom left.
            let corners = [o.topLeft, o.topRight, o.bottomRight, o.bottomLeft]
            let pts = corners.map { CGPoint(x: $0.x * w, y: (1 - $0.y) * h) }
            let capture = CaptureBuilder.build(source: image, points: pts, exactPolygon: true)
            return ScanHit(text: mapped.1, format: mapped.0, capture: capture)
        }
        return nil
    }

    private static func zxingScan(_ image: UIImage) -> ScanHit? {
        guard let cg = image.cgImage else { return nil }
        let options = ZXIReaderOptions()
        options.tryHarder = true
        options.tryRotate = true
        options.tryInvert = true
        let reader = ZXIBarcodeReader(options: options)
        guard let results = try? reader.read(cg) else { return nil }
        for r in results {
            guard let f = CodeFormat.fromZXing(r.format), !r.text.isEmpty else { continue }
            let p = r.position
            let corners = [p.topLeft, p.topRight, p.bottomRight, p.bottomLeft]
            let pts = corners.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
            let capture = CaptureBuilder.build(source: image, points: pts, exactPolygon: true)
            return ScanHit(text: r.text, format: f, capture: capture)
        }
        return nil
    }
}
