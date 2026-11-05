import AVFoundation
import UIKit
import CoreImage
import SwiftUI

/// Owns the capture session. Codes are detected twice over: AVCaptureMetadataOutput (hardware accelerated, very
/// fast) and a throttled Vision pass over the video frames (covers Codabar and anything the metadata output misses).
/// The first hit is delivered right away, without any button press.
final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var hasTorch = false
    @Published private(set) var failed = false

    /// Called on the main thread with the decoded text, the format and the pictures of the scan.
    var onCode: ((String, CodeFormat, ScanCapture?) -> Void)?

    private let queue = DispatchQueue(label: "com.allcodes.scan.camera")
    private let metadataOutput = AVCaptureMetadataOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()

    // Everything below is only touched on `queue`.
    private var configured = false
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back
    private var autofocus = true
    private var scanning = true
    private var continuous = false
    private var latestFrame: CVPixelBuffer?
    private var lastVision: CFTimeInterval = 0
    private var lastText = ""
    private var lastTime: CFTimeInterval = 0

    // MARK: control

    func start(autofocus: Bool, continuous: Bool) {
        queue.async {
            self.autofocus = autofocus
            self.continuous = continuous
            self.configureIfNeeded()
            if let d = self.device { self.applyFocus(d) }
            self.scanning = true
            if self.configured && !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async {
            self.scanning = false
            if let d = self.device, d.hasTorch, d.torchMode != .off {
                if (try? d.lockForConfiguration()) != nil {
                    d.torchMode = .off
                    d.unlockForConfiguration()
                }
            }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func setContinuous(_ on: Bool) {
        queue.async { self.continuous = on }
    }

    func setAutofocus(_ on: Bool) {
        queue.async {
            self.autofocus = on
            if let d = self.device { self.applyFocus(d) }
        }
    }

    func flip() {
        queue.async {
            guard self.configured else { return }
            let target: AVCaptureDevice.Position = self.position == .back ? .front : .back
            self.session.beginConfiguration()
            _ = self.installInput(target)
            self.session.commitConfiguration()
            self.applyOrientation()
            self.publishTorch()
        }
    }

    func setTorch(_ on: Bool) {
        queue.async {
            guard let d = self.device, d.hasTorch else { return }
            let mode: AVCaptureDevice.TorchMode = on ? .on : .off
            guard d.isTorchModeSupported(mode) else { return }
            do {
                try d.lockForConfiguration()
                d.torchMode = mode
                d.unlockForConfiguration()
            } catch {
            }
        }
    }

    /// `level` is 0...1.
    func setZoom(_ level: Double) {
        queue.async {
            guard let d = self.device else { return }
            let maxFactor = min(d.activeFormat.videoMaxZoomFactor, 10)
            let factor = 1 + CGFloat(max(0, min(1, level))) * (maxFactor - 1)
            do {
                try d.lockForConfiguration()
                d.videoZoomFactor = max(d.minAvailableVideoZoomFactor, factor)
                d.unlockForConfiguration()
            } catch {
            }
        }
    }

    /// `point` is in capture device coordinates (0...1).
    func focus(at point: CGPoint) {
        queue.async {
            guard let d = self.device else { return }
            do {
                try d.lockForConfiguration()
                if d.isFocusPointOfInterestSupported && d.isFocusModeSupported(.continuousAutoFocus) {
                    d.focusPointOfInterest = point
                    d.focusMode = .continuousAutoFocus
                } else if d.isFocusPointOfInterestSupported && d.isFocusModeSupported(.autoFocus) {
                    d.focusPointOfInterest = point
                    d.focusMode = .autoFocus
                }
                if d.isExposurePointOfInterestSupported && d.isExposureModeSupported(.continuousAutoExposure) {
                    d.exposurePointOfInterest = point
                    d.exposureMode = .continuousAutoExposure
                }
                d.unlockForConfiguration()
            } catch {
            }
        }
    }

    // MARK: configuration (on queue)

    private func setFailed(_ value: Bool) {
        DispatchQueue.main.async { self.failed = value }
    }

    private func publishTorch() {
        let value = device?.hasTorch ?? false
        DispatchQueue.main.async { self.hasTorch = value }
    }

    private func configureIfNeeded() {
        if configured { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        if !installInput(.back) && !installInput(.front) {
            session.commitConfiguration()
            setFailed(true)
            return
        }
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
            let wanted: [AVMetadataObject.ObjectType] = [
                .qr, .ean8, .ean13, .upce, .code39, .code39Mod43, .code93, .code128,
                .interleaved2of5, .itf14, .pdf417, .dataMatrix, .aztec,
            ]
            let available = metadataOutput.availableMetadataObjectTypes
            metadataOutput.metadataObjectTypes = wanted.filter { available.contains($0) }
        }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
        applyOrientation()
        configured = true
        setFailed(false)
        publishTorch()
    }

    private func installInput(_ pos: AVCaptureDevice.Position) -> Bool {
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: pos),
              let new = try? AVCaptureDeviceInput(device: dev) else { return false }
        let old = input
        if let old = old { session.removeInput(old) }
        if session.canAddInput(new) {
            session.addInput(new)
            input = new
            device = dev
            position = pos
            applyFocus(dev)
            return true
        }
        if let old = old, session.canAddInput(old) { session.addInput(old) }
        return false
    }

    /// Frames are delivered upright so Vision and the saved pictures need no rotation.
    private func applyOrientation() {
        if let c = videoOutput.connection(with: .video), c.isVideoOrientationSupported {
            c.videoOrientation = .portrait
        }
    }

    private func applyFocus(_ d: AVCaptureDevice) {
        do {
            try d.lockForConfiguration()
            if autofocus && d.isFocusModeSupported(.continuousAutoFocus) {
                d.focusMode = .continuousAutoFocus
            } else if d.isFocusModeSupported(.autoFocus) {
                d.focusMode = .autoFocus
            }
            if d.isAutoFocusRangeRestrictionSupported {
                d.autoFocusRangeRestriction = .near
            }
            if d.isSmoothAutoFocusSupported {
                d.isSmoothAutoFocusEnabled = false
            }
            d.unlockForConfiguration()
        } catch {
        }
    }

    // MARK: detection (on queue)

    private func uiImage(from buffer: CVPixelBuffer) -> UIImage? {
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return nil }
        return CaptureBuilder.normalized(UIImage(cgImage: cg), maxSide: 1600)
    }

    /// Hands a decoded code to the app. `capture` is only evaluated when the code is really delivered.
    private func deliver(text: String, format: CodeFormat, capture: () -> ScanCapture?) {
        let now = CACurrentMediaTime()
        let duplicate = continuous && text == lastText && now - lastTime < 2.5
        lastText = text
        lastTime = now
        if duplicate { return }
        if !continuous { scanning = false }
        let pictures = capture()
        DispatchQueue.main.async { self.onCode?(text, format, pictures) }
    }

    private func makeCapture(for text: String) -> ScanCapture? {
        guard let buffer = latestFrame, let image = uiImage(from: buffer) else { return nil }
        if let hit = ImageScanner.visionScan(image, onlyPayload: text), let c = hit.capture { return c }
        return CaptureBuilder.plain(image)
    }

    fileprivate static func map(_ type: AVMetadataObject.ObjectType, _ text: String) -> (CodeFormat, String)? {
        switch type {
        case .qr: return (.QR_CODE, text)
        case .ean8: return (.EAN_8, text)
        case .ean13:
            if text.count == 13 && text.hasPrefix("0") { return (.UPC_A, String(text.dropFirst())) }
            return (.EAN_13, text)
        case .upce: return (.UPC_E, text)
        case .code39, .code39Mod43: return (.CODE_39, text)
        case .code93: return (.CODE_93, text)
        case .code128: return (.CODE_128, text)
        case .interleaved2of5, .itf14: return (.ITF, text)
        case .pdf417: return (.PDF_417, text)
        case .dataMatrix: return (.DATA_MATRIX, text)
        case .aztec: return (.AZTEC, text)
        default: return nil
        }
    }
}

extension CameraController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if !scanning { return }
        for object in metadataObjects {
            guard let code = object as? AVMetadataMachineReadableCodeObject,
                  let text = code.stringValue, !text.isEmpty,
                  let mapped = CameraController.map(code.type, text) else { continue }
            deliver(text: mapped.1, format: mapped.0, capture: { self.makeCapture(for: mapped.1) })
            return
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        latestFrame = buffer
        if !scanning { return }
        let now = CACurrentMediaTime()
        if now - lastVision < 0.35 { return }
        lastVision = now
        guard let image = uiImage(from: buffer), let hit = ImageScanner.visionScan(image) else { return }
        deliver(text: hit.text, format: hit.format, capture: { hit.capture })
    }
}

// MARK: SwiftUI preview

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { return AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    var onTap: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tapped(_ g: UITapGestureRecognizer) {
        let p = g.location(in: self)
        onTap?(previewLayer.captureDevicePointConverted(fromLayerPoint: p))
    }
}

struct CameraPreview: UIViewRepresentable {
    let controller: CameraController
    let tapFocus: Bool

    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.previewLayer.session = controller.session
        return v
    }

    func updateUIView(_ view: PreviewUIView, context: Context) {
        if tapFocus {
            view.onTap = { [weak controller] p in controller?.focus(at: p) }
        } else {
            view.onTap = nil
        }
    }
}
