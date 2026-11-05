import SwiftUI
import AVFoundation

struct ScanView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings
    @StateObject private var controller = CameraController()

    @State private var status = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var torch = false
    @State private var zoom: Double = 0
    @State private var batchActive = false
    @State private var batchCount = 0

    private var authorized: Bool { return status == .authorized }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if authorized {
                CameraPreview(controller: controller, tapFocus: settings.tapFocus && settings.autofocus)
                    .ignoresSafeArea()
            }
            ScanFrame(accent: settings.accent)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            LinearGradient(colors: [Color.black.opacity(0.45), Color.clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
            }

            if authorized && controller.failed {
                Text(L.t("camera_error"))
                    .font(Typo.bodyLarge)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(32)
            }
            if !authorized {
                permissionPrompt
            }
            if authorized {
                VStack(spacing: 0) {
                    Spacer()
                    bottomControls
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            controller.onCode = { text, format, capture in
                let navigate = !batchActive
                model.onScanned(text: text, format: format, navigate: navigate, capture: capture)
                if batchActive { batchCount += 1 }
            }
            begin()
        }
        .onDisappear {
            controller.stop()
            torch = false
        }
        .onChange(of: model.path.isEmpty) { empty in
            if empty { begin() } else { controller.stop(); torch = false }
        }
        .onChange(of: torch) { on in controller.setTorch(on) }
        .onChange(of: zoom) { z in controller.setZoom(z) }
        .onChange(of: settings.autofocus) { on in controller.setAutofocus(on) }
        .onChange(of: settings.batchMode) { on in
            if !on { batchActive = false }
        }
        .onChange(of: batchActive) { on in controller.setContinuous(on) }
    }

    // MARK: lifecycle

    private func begin() {
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    status = AVCaptureDevice.authorizationStatus(for: .video)
                    if status == .authorized && model.path.isEmpty { startCamera() }
                }
            }
        } else if status == .authorized {
            startCamera()
        }
    }

    private func startCamera() {
        controller.start(autofocus: settings.autofocus, continuous: batchActive)
    }

    // MARK: pieces

    private var topBar: some View {
        ZStack {
            HStack {
                iconButton("line.3.horizontal", label: L.t("open_menu")) {
                    withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = true }
                }
                Spacer()
            }
            HStack(spacing: 20) {
                iconButton("photo", label: L.t("cd_gallery")) { model.pickImage() }
                iconButton(torch ? "bolt.fill" : "bolt.slash.fill", label: L.t("cd_flash"), enabled: authorized && controller.hasTorch) {
                    torch.toggle()
                }
                iconButton("arrow.triangle.2.circlepath.camera", label: L.t("cd_flip"), enabled: authorized) {
                    torch = false
                    zoom = 0
                    controller.flip()
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }

    private func iconButton(_ symbol: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .medium))
                .foregroundColor(.white.opacity(enabled ? 1 : 0.4))
                .frame(width: 48, height: 48)
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Text(L.t("camera_permission_title"))
                .font(Typo.titleLarge)
                .foregroundColor(.white)
            Text(L.t("camera_permission_body"))
                .font(Typo.bodyLarge)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button {
                if status == .notDetermined {
                    begin()
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L.t("camera_permission_grant"))
                    .font(Typo.font(16, .semibold))
                    .foregroundColor(settings.onAccent)
                    .padding(.horizontal, 28)
                    .frame(height: 46)
                    .background(settings.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(32)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if settings.batchMode {
                Button {
                    batchActive.toggle()
                    if batchActive { batchCount = 0 }
                } label: {
                    Text(batchActive ? L.f("batch_count", Int32(batchCount)) : L.t("batch_off"))
                        .font(Typo.font(14, .medium))
                        .foregroundColor(batchActive ? settings.onAccent : .white)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(batchActive ? settings.accent : Color.black.opacity(0.55))
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 8) {
                Button {
                    zoom = max(0, zoom - 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L.t("cd_zoom_out"))
                Slider(value: $zoom, in: 0...1)
                    .tint(.white.opacity(0.75))
                Button {
                    zoom = min(1, zoom + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L.t("cd_zoom_in"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

/// The white square with accent corner brackets and the red scan line across it.
struct ScanFrame: View {
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let side = min(size.width * 0.75, size.height * 0.6)
            let left = (size.width - side) / 2
            let top = (size.height - side) / 2
            let right = left + side
            let bottom = top + side
            let thick: CGFloat = 4
            let len: CGFloat = 22

            context.stroke(
                Path(CGRect(x: left, y: top, width: side, height: side)),
                with: .color(Color.white.opacity(0.65)),
                lineWidth: 1
            )

            var corners = Path()
            corners.addPath(corner(x: left, y: top, dx: 1, dy: 1, thick: thick, len: len))
            corners.addPath(corner(x: right, y: top, dx: -1, dy: 1, thick: thick, len: len))
            corners.addPath(corner(x: left, y: bottom, dx: 1, dy: -1, thick: thick, len: len))
            corners.addPath(corner(x: right, y: bottom, dx: -1, dy: -1, thick: thick, len: len))
            context.stroke(corners, with: .color(accent), style: StrokeStyle(lineWidth: thick, lineCap: .butt))

            var line = Path()
            line.move(to: CGPoint(x: left, y: top + side / 2))
            line.addLine(to: CGPoint(x: right, y: top + side / 2))
            context.stroke(line, with: .color(Color(red: 229.0 / 255.0, green: 57.0 / 255.0, blue: 53.0 / 255.0)), lineWidth: 1.5)
        }
    }

    private func corner(x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat, thick: CGFloat, len: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x - dx * thick / 2, y: y))
        p.addLine(to: CGPoint(x: x + dx * len, y: y))
        p.move(to: CGPoint(x: x, y: y - dy * thick / 2))
        p.addLine(to: CGPoint(x: x, y: y + dy * len))
        return p
    }
}
