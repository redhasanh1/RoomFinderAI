import PhotosUI
import SwiftUI

/// Becoming a verified lister, natively.
///
/// The web version collected the selfie first and the ID second, which is the
/// order it still shows on screen — but the document has to reach the server
/// first or the selfie is refused. That mismatch is what made verification fail
/// for people who did nothing wrong. Here the two are collected in either
/// order, held until both exist, and then sent document-first by
/// `VerificationService`.
struct VerificationScreen: View {

    @ObservedObject var service: VerificationService
    @Environment(\.dismiss) private var dismiss

    @State private var documentItem: PhotosPickerItem?
    @State private var selfieItem: PhotosPickerItem?
    @State private var document: UIImage?
    @State private var selfie: UIImage?

    private var canSubmit: Bool { document != nil && selfie != nil && !service.isUploading }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Send a government ID and a photo of your face. A person checks both, usually within a day.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                picker(
                    title: "Government ID",
                    detail: "Passport or driving licence, all four corners visible",
                    symbol: "person.text.rectangle.fill",
                    item: $documentItem,
                    image: $document
                )

                picker(
                    title: "Selfie",
                    detail: "Just you, looking at the camera, in good light",
                    symbol: "person.crop.square.badge.camera.fill",
                    item: $selfieItem,
                    image: $selfie
                )

                if let error = service.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            guard let document, let selfie else { return }
                            await service.submit(document: document, selfie: selfie)
                            if service.errorMessage == nil { dismiss() }
                        }
                    } label: {
                        if service.isUploading {
                            HStack {
                                ProgressView()
                                Text(service.progress ?? "Sending…")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Send for review").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit)
                } footer: {
                    Text("Your ID is used only to confirm who you are, and is never shown on your listings.")
                }
            }
            .navigationTitle("Get verified")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(service.isUploading)
                }
            }
        }
        .interactiveDismissDisabled(service.isUploading)
    }

    private func picker(title: String, detail: String, symbol: String,
                        item: Binding<PhotosPickerItem?>, image: Binding<UIImage?>) -> some View {
        Section {
            PhotosPicker(selection: item, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 12) {
                    if let chosen = image.wrappedValue {
                        Image(uiImage: chosen)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: symbol)
                            .font(.title2)
                            .foregroundStyle(Theme.brand)
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.brand.opacity(0.12)))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.headline)
                        Text(image.wrappedValue == nil ? detail : "Chosen. Tap to change.")
                            .font(.caption)
                            .foregroundStyle(image.wrappedValue == nil ? Color.secondary : Color.green)
                    }

                    Spacer()

                    if image.wrappedValue != nil {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            .disabled(service.isUploading)
            .onChange(of: item.wrappedValue) { _, picked in
                Task {
                    guard let data = try? await picked?.loadTransferable(type: Data.self),
                          let loaded = UIImage(data: data) else { return }
                    image.wrappedValue = loaded
                    service.errorMessage = nil
                }
            }
        }
    }
}

/// Changing your name.
struct EditNameScreen: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthService.shared

    @State private var firstName = AuthService.shared.profile?.firstName ?? ""
    @State private var lastName = AuthService.shared.profile?.lastName ?? ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                } footer: {
                    Text("This is the name landlords see when you message them.")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Your name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(isSaving || firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await auth.updateName(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces)
                )
                Haptics.notify(.success)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

/// Deleting the account, which Apple requires to be possible in the app.
struct DeleteAccountScreen: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthService.shared

    @State private var password = ""
    @State private var confirmed = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("This cannot be undone", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Deleting removes your account, your listings, your saved rooms and your messages.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section {
                    SecureField("Your password", text: $password)
                        .textContentType(.password)
                    Toggle("I understand this is permanent", isOn: $confirmed)
                } footer: {
                    Text("We ask for your password again because a signed-in phone is not proof it is you.")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }

                Section {
                    Button(role: .destructive) {
                        delete()
                    } label: {
                        if isDeleting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Delete my account").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!confirmed || password.isEmpty || isDeleting)
                }
            }
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isDeleting)
                }
            }
        }
        .interactiveDismissDisabled(isDeleting)
    }

    private func delete() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await auth.deleteAccount(password: password)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isDeleting = false
        }
    }
}
