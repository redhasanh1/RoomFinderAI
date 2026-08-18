import ImageIO
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
    /// Where the first photo was taken, if it says so. Used to fill the address
    /// and to price the room against its actual area.
    @State private var photoLocation: ListingDraftService.PhotoLocation?

    @State private var isDrafting = false
    @State private var draftNote: String?
    /// Live narration while the draft is being written.
    @State private var draftSteps: [String] = []
    /// What the model reported understanding, shown after it finishes.
    @State private var draftFindings: [String] = []
    /// Posting is two screens: pick photos, then check what the AI wrote.
    ///
    /// One long form asked for a title, a price and an address before the photo
    /// that can supply most of it, which is backwards. The upload gets a screen
    /// to itself, the analysis runs the moment a photo lands, and the details
    /// screen opens already filled in.
    private enum Step { case photos, details }
    @State private var step: Step = .photos
    private let drafts = ListingDraftService()
    private let locations = LocationProvider()

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didPost = false

    private let houseTypes = ["Apartment", "House", "Condo", "Studio", "Room", "Townhouse"]

    var body: some View {
        NavigationStack {
            Group {
                if didPost {
                    confirmation
                } else {
                    switch step {
                    case .photos:  photoStep
                    case .details: form
                    }
                }
            }
            // On the sheet, not on one of the screens. This lived inside the
            // details form, which is not in the hierarchy while the photo step
            // is showing — so picking a photo on the first screen changed
            // pickerItems with nothing listening, and nothing happened at all.
            .onChange(of: pickerItems) { _, items in
                Task { await loadPhotos(items) }
            }
            .navigationTitle(didPost ? "Posted" : (step == .photos ? "Add Photos" : "Check the Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(didPost ? "Done" : "Cancel") { dismiss() }
                }
                if !didPost, step == .details {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Post", action: submit)
                            .fontWeight(.semibold)
                            .disabled(isSubmitting)
                    }
                }
            }
        }
        // Only Cancel closes this.
        //
        // On iPad a tap outside the sheet dismissed it, and a swipe down did
        // the same on both — throwing away the photos, the analysis and
        // everything typed, with no warning and no way back. Losing a
        // half-written listing to a stray tap is the worst thing this screen
        // could do, so leaving is a deliberate act now.
        .interactiveDismissDisabled()
    }


    // MARK: - Step one: the photo

    /// One big target and nothing else.
    ///
    /// The whole promise of this screen is that a photo does the work, so it is
    /// the only thing on it. The manual route stays reachable underneath, at a
    /// size that can actually be tapped, because someone posting from their
    /// desk with no photo to hand must not hit a dead end.
    private var photoStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                VStack(spacing: 14) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(Theme.gradient)

                    Text("Add photos of the room")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Up to six. The first one is what buyers see.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                // Square, so it reads as a drop target rather than a row.
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            Theme.brand.opacity(0.35),
                            style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                        )
                )
            }
            .disabled(isDrafting)

            // States what happens next, so the automatic analysis is expected
            // rather than a surprise.
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(Theme.brand)
                Text("The AI reads your photo and fills in the listing for you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let draftNote, !isDrafting {
                Text(draftNote)
                    .font(.footnote)
                    .foregroundStyle(draftNote.hasPrefix("Filled") ? Color.secondary : Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Button {
                Haptics.impact(.light)
                withAnimation { step = .details }
            } label: {
                Text("Fill it in myself")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.brand)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.brand.opacity(0.10))
            )
            .disabled(isDrafting)

            if !user.isSignedIn {
                Label("Sign in from the Profile tab first, or this won't be linked to your account.",
                      systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .overlay {
            if isDrafting { processingOverlay }
        }
    }

    /// The analysis, shown as it happens.
    ///
    /// A vision call over an uploaded photo takes several seconds. Covering
    /// that with a bare spinner invites a second tap; naming each step as it
    /// starts makes the wait legible.
    private var processingOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)

                Text("Reading your photo")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(draftSteps, id: \.self) { line in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.brand)
                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .padding(28)
        }
    }

    private var form: some View {
        Form {
            // Say plainly whether the photo produced anything. This was a small
            // grey caption inside a section, which is invisible when the fields
            // you expected to be filled are empty and you are looking at those
            // instead.
            if let draftNote {
                Section {
                    Label {
                        Text(draftNote)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: draftFindings.isEmpty
                              ? "exclamationmark.triangle.fill"
                              : "checkmark.seal.fill")
                    }
                    .foregroundStyle(draftFindings.isEmpty ? Color.orange : Color.green)
                }
            }
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
                Text("Start with photos")
            } footer: {
                Text(photos.isEmpty
                     ? "Add a photo of the room and it writes the listing for you. Up to six."
                     : "Rooms with photos get far more interest. Up to six.")
            }


            if !photos.isEmpty {
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

    /// Coordinates out of a photo's own metadata, or nil.
    ///
    /// Read from the file data with ImageIO, because `UIImage` keeps only the
    /// pixels — by the time a photo is a UIImage its GPS tags are gone. Most
    /// camera photos carry this; screenshots and downloads do not, which is why
    /// every caller treats it as optional.
    private static func coordinates(in data: Data) -> ListingDraftService.PhotoLocation? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              var latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              var longitude = gps[kCGImagePropertyGPSLongitude] as? Double
        else { return nil }

        // EXIF stores magnitude and hemisphere separately.
        if let ref = gps[kCGImagePropertyGPSLatitudeRef] as? String, ref == "S" { latitude = -latitude }
        if let ref = gps[kCGImagePropertyGPSLongitudeRef] as? String, ref == "W" { longitude = -longitude }

        guard latitude != 0 || longitude != 0 else { return nil }
        return .init(latitude: latitude, longitude: longitude)
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        var foundLocation: ListingDraftService.PhotoLocation?  // photo GPS, else the device
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(image)
                // Read the coordinates from the file itself, before UIImage
                // drops them. First photo that has them wins.
                if foundLocation == nil { foundLocation = Self.coordinates(in: data) }
            }
        }
        photos = loaded

        // PhotosPicker hands back images with their location stripped, so the
        // EXIF read above usually finds nothing. Ask the device where it is
        // instead — someone posting a room is standing in it. Only when the
        // photo genuinely carried coordinates do we prefer those.
        if foundLocation == nil,
           let coordinate = await locations.currentCoordinate() {
            foundLocation = .init(latitude: coordinate.latitude,
                                  longitude: coordinate.longitude)
        }
        photoLocation = foundLocation

        // Run the analysis without being asked. The previous screen offered a
        // button for it, which meant the common path was: add a photo, then
        // hunt for the thing that uses it. If it fails the details screen still
        // opens, just empty, so a bad photo never blocks posting.
        if !loaded.isEmpty {
            await runAutofill(using: loaded.first)
            withAnimation { step = .details }
        }
    }

    /// Mirrors the server's own validation so problems are caught before the
    /// round trip rather than coming back as a list of errors afterwards.
    /// Fills the form in. Prefers the photo, because a model that can see the
    /// room writes something truer than one working from four form fields.
    private func autofill() {
        Task { await runAutofill(using: photos.first) }
    }

    /// Reads the first photo and fills in whatever it can.
    ///
    /// Awaitable on purpose: the caller advances to the details screen when this
    /// returns, so wrapping the work in a detached Task would move on before
    /// any of it had happened.
    /// - Parameter image: passed in rather than read back off `photos`.
    ///   loadPhotos calls this immediately after assigning that state, and
    ///   relying on the write having propagated meant it could see an empty
    ///   array, take the no-photo branch and fail with "add a photo first"
    ///   having just been given one.
    private func runAutofill(using image: UIImage?) async {
        isDrafting = true
        draftNote = nil
        draftFindings = []
        draftSteps = []
        Haptics.impact(.light)
        defer { isDrafting = false }

        // Appended as each stage actually begins, not on a timer, so what is on
        // screen is genuinely what is happening.
        func progress(_ text: String) {
            withAnimation(.easeOut(duration: 0.2)) { draftSteps.append(text) }
        }

        do {
            let draft: ListingDraftService.Draft
            if let photo = image {
                progress("Preparing your photo")
                progress("Sending it to be looked at")
                draft = try await drafts.draft(from: photo, at: photoLocation)
                progress("Reading the room")
            } else {
                progress("Writing from the details you entered")
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
            // Every field the analysis can speak to, filled to the best of its
            // ability. The rent estimate and the address were already coming
            // back from the server and being discarded, which left the host
            // guessing the two things that matter most.
            if price.trimmingCharacters(in: .whitespaces).isEmpty,
               let suggested = draft.price, suggested > 0 {
                price = String(suggested)
            }
            if street.trimmingCharacters(in: .whitespaces).isEmpty,
               let value = draft.street?.nilIfEmpty {
                street = value
            }
            if city.trimmingCharacters(in: .whitespaces).isEmpty,
               let value = draft.city?.nilIfEmpty {
                city = value
            }
            if postalCode.trimmingCharacters(in: .whitespaces).isEmpty,
               let value = draft.postalCode?.nilIfEmpty {
                postalCode = value
            }

            // What it understood, in its own terms. An empty list is itself
            // informative: the photo told it nothing useful, which is worth
            // knowing before posting.
            var findings: [String] = []
            if let type = draft.houseType { findings.append("Property type: \(type)") }
            if let count = draft.bedrooms, count > 0 { findings.append("Bedrooms: \(count)") }
            if let value = draft.title { findings.append("Title: \(value)") }
            if let suggested = draft.price, suggested > 0 {
                findings.append("Suggested rent: $\(suggested)/month")
            }
            let place = [draft.street, draft.city, draft.postalCode]
                .compactMap { $0?.nilIfEmpty }
                .joined(separator: ", ")
            if !place.isEmpty {
                findings.append(draft.locationIsApproximate
                    ? "Rough area (check this): \(place)"
                    : "Location from the photo: \(place)")
            }
            if !draft.features.isEmpty {
                findings.append("Spotted: \(draft.features.prefix(4).joined(separator: ", "))")
            }
            if draft.description != nil { findings.append("Wrote a description") }
            draftFindings = findings

            draftNote = findings.isEmpty
                ? "It couldn't tell much from that photo. Fill in what's missing below."
                : "Filled in from your photo. Change anything that's wrong."
            Haptics.notify(findings.isEmpty ? .warning : .success)
        } catch {
            draftSteps = []
            // The server's own words. When it turns a photo down it says why,
            // and that reason is the only thing that tells the host what to do.
            draftNote = error.localizedDescription
            Haptics.notify(.error)
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
