import UIKit

/// The two pictures kept for every scan: `frame` is the camera frame (or the picked image) with the scanned code
/// outlined, `code` is the cropped code. Helpful when several codes are in view: the outline shows which one was read.
struct ScanCapture {
    let frame: UIImage
    let code: UIImage
}

enum CaptureBuilder {
    private static let frameMaxSide: CGFloat = 1280
    private static let codeMaxSide: CGFloat = 640

    /// Redraws `image` upright at scale 1 (so `cgImage` pixels match what is displayed), optionally limiting the size.
    static func normalized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let w = image.size.width
        let h = image.size.height
        if w < 1 || h < 1 { return image }
        let f = min(1, maxSide / max(w, h))
        let size = CGSize(width: max(1, (w * f).rounded()), height: max(1, (h * f).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: CGPoint.zero, size: size))
        }
    }

    private static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let w = image.size.width
        let h = image.size.height
        if max(w, h) <= maxSide { return image }
        return normalized(image, maxSide: maxSide)
    }

    /// Used when the code's position is unknown: the whole picture is kept for both pictures.
    static func plain(_ source: UIImage) -> ScanCapture {
        return ScanCapture(frame: source, code: source)
    }

    /// `source` must be upright with scale 1. `points` are the code's corners in pixel coordinates of `source`
    /// (origin top-left). With `exactPolygon` the outline follows the points; otherwise a padded box around them is used.
    static func build(source: UIImage, points: [CGPoint], exactPolygon: Bool) -> ScanCapture? {
        guard let cg = source.cgImage, !points.isEmpty else { return nil }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        if w < 2 || h < 2 { return nil }

        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        let side = max(maxX - minX, maxY - minY)
        let pad = max(side * 0.12, 12)

        // Code crop with a little margin around the code.
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        var rect = CGRect(x: minX - pad, y: minY - pad, width: (maxX - minX) + 2 * pad, height: (maxY - minY) + 2 * pad)
        rect = rect.intersection(full)
        if rect.isNull || rect.width < 8 || rect.height < 8 { rect = full }
        guard let cropped = cg.cropping(to: rect.integral) else { return nil }
        let code = downscale(UIImage(cgImage: cropped), maxSide: codeMaxSide)

        // Frame with the outline of the scanned code.
        let f = min(1, frameMaxSide / max(w, h))
        let size = CGSize(width: max(1, (w * f).rounded()), height: max(1, (h * f).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let frame = renderer.image { _ in
            UIImage(cgImage: cg).draw(in: CGRect(origin: CGPoint.zero, size: size))

            let path = UIBezierPath()
            if exactPolygon && points.count >= 3 {
                path.move(to: CGPoint(x: points[0].x * f, y: points[0].y * f))
                for i in 1..<points.count {
                    path.addLine(to: CGPoint(x: points[i].x * f, y: points[i].y * f))
                }
                path.close()
            } else {
                let grow = max(side * 0.08, 8)
                let box = CGRect(x: (minX - grow) * f, y: (minY - grow) * f, width: ((maxX - minX) + 2 * grow) * f, height: ((maxY - minY) + 2 * grow) * f)
                path.append(UIBezierPath(roundedRect: box, cornerRadius: 8))
            }
            path.lineJoinStyle = .round
            let stroke = max(3, max(size.width, size.height) / 220)
            UIColor(white: 0, alpha: 0.6).setStroke()
            path.lineWidth = stroke * 2
            path.stroke()
            UIColor(red: 46.0 / 255.0, green: 230.0 / 255.0, blue: 126.0 / 255.0, alpha: 1).setStroke()
            path.lineWidth = stroke
            path.stroke()
        }
        return ScanCapture(frame: frame, code: code)
    }
}
