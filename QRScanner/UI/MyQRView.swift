import SwiftUI

/// The user's own contact card as a QR code (vCard). Stored only on the device.
struct MyQRView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings

    @State private var editing = false
    @State private var name = ""
    @State private var org = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var website = ""
    @State private var nameError = false

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(L.t("menu_my_qr"), onMenu: {
                withAnimation(.easeOut(duration: 0.22)) { model.drawerOpen = true }
            }, trailing: {
                if !editing {
                    BarIconButton(symbol: "pencil", label: L.t("my_qr_edit")) { startEditing() }
                }
            })
            if editing {
                form
            } else {
                let payload = ContentBuilder.vcard(
                    name: settings.myName, org: settings.myOrg, phone: settings.myPhone,
                    email: settings.myEmail, address: settings.myAddress, website: settings.myWebsite
                )
                GeneratedCodeView(text: payload, format: .QR_CODE, header: {
                    Text(settings.myName)
                        .font(Typo.font(24, .bold))
                        .foregroundColor(Palette.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                })
                .id(payload)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .onAppear {
            if settings.myName.trimmingCharacters(in: .whitespaces).isEmpty { startEditing() }
        }
    }

    private func startEditing() {
        name = settings.myName
        org = settings.myOrg
        phone = settings.myPhone
        email = settings.myEmail
        address = settings.myAddress
        website = settings.myWebsite
        nameError = false
        editing = true
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(L.t("my_qr_empty"))
                    .font(Typo.bodyLarge)
                    .foregroundColor(Palette.onVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                FormField(label: L.t("field_name"), text: $name, error: nameError ? L.t("error_required") : nil)
                FormField(label: L.t("field_org"), text: $org)
                FormField(label: L.t("field_phone"), text: $phone, keyboard: .phonePad)
                FormField(label: L.t("field_email"), text: $email, keyboard: .emailAddress, lowercase: true)
                FormField(label: L.t("field_address"), text: $address)
                FormField(label: L.t("field_website"), text: $website, keyboard: .URL, lowercase: true)
                AccentButton(title: L.t("my_qr_save")) { save() }
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func save() {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            nameError = true
            return
        }
        settings.myName = name.trimmingCharacters(in: .whitespaces)
        settings.myOrg = org.trimmingCharacters(in: .whitespaces)
        settings.myPhone = phone.trimmingCharacters(in: .whitespaces)
        settings.myEmail = email.trimmingCharacters(in: .whitespaces)
        settings.myAddress = address.trimmingCharacters(in: .whitespaces)
        settings.myWebsite = website.trimmingCharacters(in: .whitespaces)
        editing = false
    }
}
