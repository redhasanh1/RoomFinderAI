import PhotosUI
import SwiftUI

/// Post a room, natively.
///
/// Reached from the button in the middle of the tab bar, which is where people
/// expect "add" to live. Everything the server validates is asked for here and
/// checked before sending, so a listing is never rejected after the effort of
/// filling it in.
struct PostListingSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var user = CurrentUser.shared

    @State private var title = ""
    @State private var price = ""
    @State private var city = ""
    @State private var street = ""
    @State private var postalCode = ""
    @State private var houseType = "Apartment"
    @State private var bedrooms = 1
    @State private var utilitiesIncluded = true
    @State private var description = ""

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photos: [UIImage] = []

    @State private var isDrafting = false
    @State private var draftNote: String?
    /// Live narration while the draft is being written.
    @State private var draftSteps: [String] = []
    /// What the model reported understanding, shown after it finishes.
    @State private var draftFindings: [String] = []
    private let drafts = ListingDraftService()

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didPost = false

    private let houseTypes = ["Apartment", "House", "Condo", "Studio", "Room", "Townhouse"]

    var body: some View {
        NavigationStack {
            Group {
                if didPost { confirmation } else { form }
            }
            .navigationTitle(didPost ? "Posted" : "Post a Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(didPost ? "Done" : "Cancel") { dismiss() }
                }
                if !didPost {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Post", action: submit)
                            .fontWeight(.semibold)
                            .disabled(isSubmitting)
                    }
                }
            }
        }
    }

    private var form: some View {
        Form {
            if !user.isSignedIn {
                Section {
                    Label("Sign in first from the Profile tab, or your room won't be linked to your account.",
                          systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }


            Section {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                    Label(photos.isEmpty ? "Add photos" : "\(photos.count) photo\(photos.count == 1 ? "" : "s") selected",
                          systemImage: "photo.on.rectangle.angled")
                }
                if !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(photos.enumerated()), id: \.offset) { _, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 74, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Photos")
            } footer: {
                Text("Rooms with photos get far more interest. Up to six.")
            }

            Section {
                Button(action: autofill) {
                    HStack(spacing: 10) {
                        if isDrafting {
                            ProgressView()
                        } else {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(Theme.brand)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(photos.isEmpty ? "Write it for me" : "Read my photo and fill this in")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(photos.isEmpty
                                 ? "Add a photo above and it can describe the room itself"
                                 : "Looks at your first photo and writes the listing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .disabled(isDrafting)

                // Say what it is doing, step by step.
                //
                // This used to be a bare spinner, so a photo upload and a
                // vision call that together take several seconds looked like
                // the button had hung. The website narrates the same work, and
                // people were reasonably asking why the app did not.
                if isDrafting {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(draftSteps, id: \.self) { step in
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .foregroundStyle(Theme.brand)
                                Text(step)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // What it actually understood, so the host can see whether it
                // read the room correctly rather than diffing the fields by eye.
                if !isDrafting, !draftFindings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What it saw")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(draftFindings, id: \.self) { finding in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(finding)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                if let draftNote {
                    Text(draftNote)
                        .font(.caption)
                        .foregroundStyle(draftNote.hasPrefix("Couldn't") ? .red : .secondary)
                }
            } footer: {
                Text("Everything it writes stays editable. Check it before posting.")
            }

            Section("The room") {
                TextField("Title, e.g. Bright 1-bed near campus", text: $title)
                LabeledContent("Rent per month") {
                    TextField("1500", text: $price)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Type", selection: $houseType) {
                    ForEach(houseTypes, id: \.self) { Text($0) }
                }
                Stepper("Bedrooms: \(bedrooms)", value: $bedrooms, in: 0...10)
                Toggle("Utilities included", isOn: $utilitiesIncluded)
            }

            Section("Where") {
                TextField("Street address", text: $street)
                TextField("City", text: $city)
                TextField("Postal code", text: $postalCode)
                    .textInputAutocapitalization(.characters)
            }


            Section("Description") {
                TextField("What's good about this place?", text: $description, axis: .vertical)
                    .lineLimit(3...8)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            Task { await loadPhotos(items) }
        }
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView("Posting…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(.green)
            Text("Your room is live")
                .font(.title3.weight(.semibold))
            Text("It's now on RoomFinderAI. You'll get a message here when someone's interested.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(image)
            }
        }
        photos = loaded
    }

    /// Mirrors the server's own validation so problems are caught before the
    /// round trip rather than coming back as a list of errors afterwards.
    /// Fills the form in. Prefers the photo, because a model that can see the
    /// room writes something truer than one working from four form fields.
    private func autofill() {
        isDrafting = true
        draftNote = nil
        draftFindings = []
        draftSteps = []
        Haptics.impact(.light)

        // Each step is appended as the work actually starts, not on a timer, so
        // whatever is on screen is genuinely what is happening.
        func step(_ text: String) {
            withAnimation(.easeOut(duration: 0.2)) { draftSteps.append(text) }
        }

        Task {
            defer { isDrafting = false }
            do {
                let draft: ListingDraftService.Draft
                if let photo = photos.first {
                    step("Preparing your photo…")
                    step("Sending it to be looked at…")
                    draft = try await drafts.draft(from: photo)
                    step("Reading the room…")
                } else {
                    step("Writing from the details you entered…")
                    draft = try await drafts.draft(
                        city: city, street: street, houseType: houseType,
                        bedrooms: bedrooms, price: price,
                        utilitiesIncluded: utilitiesIncluded, notes: description
                    )
                }

                // Never overwrite what the host already wrote themselves.
                if title.trimmingCharacters(in: .whitespaces).isEmpty, let value = draft.title {
                    title = value
                }
                if description.trimmingCharacters(in: .whitespaces).isEmpty, let value = draft.description {
                    description = value
                }
                if let type = draft.houseType, houseTypes.contains(type) {
                    houseType = type
                }
                if let count = draft.bedrooms, count > 0, count <= 10 {
                    bedrooms = count
                }

                // Report what it understood, in its own terms. An empty list
                // is itself informative: it means the photo told it nothing
                // useful, which is worth knowing before posting.
                var findings: [String] = []
                if let type = draft.houseType { findings.append("Property type: \(type)") }
                if let count = draft.bedrooms, count > 0 {
                    findings.append("Bedrooms: \(count)")
                }
                if let value = draft.title { findings.append("Suggested title: \(value)") }
                if draft.description != nil { findings.append("Wrote a description") }
                draftFindings = findings

                draftNote = findings.isEmpty
                    ? "It couldn't tell much from that photo. Try a wider shot, or fill it in yourself."
                    : "Filled in. Edit anything that is not right."
                Haptics.notify(findings.isEmpty ? .warning : .success)
            } catch {
                draftSteps = []
                // The server's own words. When it turns a photo down it says
                // why, and that reason is the only thing that tells the host
                // what to do about it.
                draftNote = error.localizedDescription
                Haptics.notify(.error)
            }
        }
    }

    private func validate() -> String? {
        if title.trimmingCharacters(in: .whitespaces).isEmpty { return "Give your room a title." }
        guard let value = Int(price.filter(\.isNumber)), value > 0 else { return "Enter the monthly rent." }
        _ = value
        if street.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter the street address." }
        if city.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter the city." }
        if postalCode.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter the postal code." }
        return nil
    }

    private func submit() {
        if let problem = validate() {
            errorMessage = problem
            Haptics.notify(.error)
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            defer { isSubmitting = false }
            do {
                // Photos first: the listing row stores their URLs, so they have
                // to exist before it is created.
                let urls = photos.isEmpty ? [] : try await uploadPhotos()
                try await createListing(media: urls)
                Haptics.notify(.success)
                didPost = true
            } catch let error as PostError {
                Haptics.notify(.error)
                errorMessage = error.message
            } catch {
                Haptics.notify(.error)
                errorMessage = "Couldn't post your room. Check your connection and try again."
            }
        }
    }

    private struct PostError: Error { let message: String }

    private func uploadPhotos() async throws -> [String] {
        let boundary = "rf-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) { body.append(Data(string.utf8)) }

        if let email = CurrentUser.shared.email {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"userEmail\"\r\n\r\n\(email)\r\n")
        }

        for (index, image) in photos.enumerated() {
            // Re-encoded as JPEG at 0.8: a modern phone photo is several
            // megabytes, and six of them would make posting a room feel broken
            // on anything but wifi.
            guard let data = image.jpegData(compressionQuality: 0.8) else { continue }
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"photos\"; filename=\"room-\(index).jpg\"\r\n")
            append("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")

        var request = URLRequest(url: AppConfig.url("api/listings/photos"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PostError(message: "Your photos couldn't be uploaded. Try again, or post without them.")
        }

        struct UploadResponse: Decodable { let urls: [String]? }
        return (try? JSONDecoder().decode(UploadResponse.self, from: data))?.urls ?? []
    }

    private func createListing(media: [String]) async throws {
        var payload: [String: Any] = [
            "title": title.trimmingCharacters(in: .whitespaces),
            "price": Int(price.filter(\.isNumber)) ?? 0,
            "city": city.trimmingCharacters(in: .whitespaces),
            "street": street.trimmingCharacters(in: .whitespaces),
            "postalCode": postalCode.trimmingCharacters(in: .whitespaces),
            "houseType": houseType,
            "bedrooms": bedrooms,
            // The server accepts these two spellings and nothing else.
            "utilities": utilitiesIncluded ? "included" : "not included",
            "description": description,
            "media": media
        ]
        if let email = CurrentUser.shared.email { payload["userEmail"] = email }

        var request = URLRequest(url: AppConfig.url("api/listings"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PostError(message: "No response from the server.") }

        guard (200..<300).contains(http.statusCode) else {
            // The server returns { errors: [...] }; showing its own words beats
            // a generic failure that leaves people guessing which field is wrong.
            struct ErrorResponse: Decodable { let errors: [String]?; let error: String? }
            let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            let message = decoded?.errors?.first ?? decoded?.error
                ?? "Couldn't post your room (error \(http.statusCode))."
            throw PostError(message: message)
        }
    }
}
