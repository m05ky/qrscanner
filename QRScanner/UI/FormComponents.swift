import SwiftUI

/// Labeled text field with an optional hint / error line underneath.
struct FormField: View {
    @EnvironmentObject var settings: AppSettings
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var multiline = false
    var error: String?
    var hint: String?
    var lowercase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typo.font(13, .medium))
                .foregroundColor(error != nil ? Color.red : Palette.onVariant)
            field
                .font(Typo.bodyLarge)
                .foregroundColor(Palette.onSurface)
                .keyboardType(keyboard)
                .textInputAutocapitalization(lowercase ? .never : nil)
                .autocorrectionDisabled(lowercase)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(error != nil ? Color.red : Palette.outline, lineWidth: 1)
                )
            if let error = error {
                Text(error)
                    .font(Typo.bodySmall)
                    .foregroundColor(Color.red)
            } else if let hint = hint {
                Text(hint)
                    .font(Typo.bodySmall)
                    .foregroundColor(Palette.onVariant)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        if multiline {
            TextField("", text: $text, axis: .vertical)
                .lineLimit(3...8)
        } else {
            TextField("", text: $text)
        }
    }
}

/// Shows a generated code with save / share / copy actions. Also used by My QR.
struct GeneratedCodeView<Header: View>: View {
    @EnvironmentObject var settings: AppSettings
    let text: String
    let format: CodeFormat
    let header: Header

    @State private var image: UIImage?

    init(text: String, format: CodeFormat, @ViewBuilder header: () -> Header) {
        self.text = text
        self.format = format
        self.header = header()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(maxWidth: 360)
                        .padding(16)
                    HStack(spacing: 0) {
                        bigAction("square.and.arrow.down", L.t("save_image")) { Actions.saveImage(img) }
                        bigAction("square.and.arrow.up", L.t("share_image")) { Actions.shareImage(img) }
                        bigAction("doc.on.doc", L.t("copy_text")) { Actions.copy(text) }
                    }
                    .padding(.horizontal, 4)
                }
                Text(text)
                    .font(Typo.bodyLarge)
                    .foregroundColor(Palette.onVariant)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
        .onAppear {
            if image == nil { image = CodeGenerator.imageOrNil(text, format: format, size: 1000) }
        }
    }

    private func bigAction(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 30))
                    .foregroundColor(settings.accent)
                    .frame(height: 40)
                Text(label)
                    .font(Typo.font(14))
                    .foregroundColor(Palette.onVariant)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension GeneratedCodeView where Header == EmptyView {
    init(text: String, format: CodeFormat) {
        self.init(text: text, format: format, header: { EmptyView() })
    }
}
