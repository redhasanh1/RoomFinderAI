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

    /// How to leave. Supplied when this is a tab's own page, where there is no
    /// presentation to dismiss and closing means going back to the tab you came
    /// from. Nil when it is presented, and then the environment's dismiss is
    /// the right thing.
    var onClose: (() -> Void)?
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
    /// The bytes each photo arrived as, in the same order.
    ///
    /// Uploading re-encoded `photos` instead, which meant the upload depended on
    /// state that a second, overlapping pick could rewrite underneath it — the
    /// way three chosen photos turned into one of them sent twice. Holding the
    /// original data means what is uploaded is exactly what was picked, and it
    /// skips a needless re-compression.
    @State private var photoData: [Data] = []
    /// Cancels a previous load when a new selection arrives, so two runs cannot
    /// interleave and leave a mixed set behind.
    @State private var loadTask: Task<Void, Never>?
    /// Where the first photo was taken, if it says so. Used to fill the address
    /// and to price the room against its actual area.
    @State private var photoLocation: ListingDraftService.PhotoLocation?

    @State private var isDrafting = false
    @State private var draftNote: String?
    @State private var spinAngle: Double = 0
    @State private var sparklePulse = false
    @State private var captionIndex = 0
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
    /// Shown as an alert as well as inline. The inline copy sits at the bottom
    /// of a long form, so tapping Post with something missing looked like the
    /// button did nothing at all.
    @State private var showsProblem = false
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
                // Replace any load still running, rather than racing it.
                loadTask?.cancel()
                loadTask = Task { await loadPhotos(items) }
            }
            .navigationTitle(didPost ? "Posted" : (step == .photos ? "Add Photos" : "Check the Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(didPost ? "Done" : "Cancel") { close() }
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
        .alert("Can't post yet", isPresented: $showsProblem) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Something is missing.")
        }
    }


    // MARK: - Step one: the photo

    /// One big target and nothing else.
    ///
    /// The whole promise of this screen is that a photo does the work, so it is
    /// the only thing on it. The manual route stays reachable underneath, at a
    /// size that can actually be tapped, because someone posting from their
    /// desk with no photo to hand must not hit a dead end.
    private var photoStep: some View {
        // Scrolling, and the target is capped.
        //
        // A square that fills the width is most of an iPad sheet on its own,
        // which pushed everything under it past the sheet's edge. It still drew,
        // so "Fill it in myself" looked present and simply did not respond:
        // taps outside a container's bounds are clipped before they reach it.
        ScrollView {
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
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 340)
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
                    .foregroundStyle(Theme.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.brand.opacity(0.10))
                    )
                    // The whole pill, not just the glyphs. The background used
                    // to be applied outside the label, which draws the shape
                    // but does not make it tappable.
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isDrafting)

            if !user.isSignedIn {
                Label("Sign in from the Profile tab first, or this won't be linked to your account.",
                      systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay {
            if isDrafting { processingOverlay }
        }
    }

    /// The wait, made worth looking at.
    ///
    /// This used to narrate the plumbing — "preparing your photo", "sending it
    /// to be looked at" — which reads like surveillance of your own upload and
    /// tells the host nothing they care about. It now says what is being worked
    /// out for them, over a spinning brand-coloured ring, and cycles so a slow
    /// vision call does not look like a frozen screen.
    private var processingOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.brand.opacity(0.16), Theme.brandDeep.opacity(0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(.regularMaterial)
            .ignoresSafeArea()

            VStack(spacing: 26) {
                ZStack {
                    // Track.
                    Circle()
                        .stroke(Theme.brand.opacity(0.15), lineWidth: 8)

                    // The moving arc.
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(
                            AngularGradient(
                                colors: [Theme.brand, Theme.brandDeep, Theme.brand],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(spinAngle))

                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Theme.gradient)
                        .scaleEffect(sparklePulse ? 1.12 : 0.9)
                        .opacity(sparklePulse ? 1 : 0.75)
                }
                .frame(width: 108, height: 108)

                VStack(spacing: 8) {
                    Text("AI processing")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.gradient)

                    Text(Self.processingCaptions[captionIndex])
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .id(captionIndex)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .frame(maxWidth: 280)
            }
            .padding(32)
        }
        .task {
            // Spin and pulse for as long as this view is on screen.
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                spinAngle = 360
            }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                sparklePulse = true
            }
            // Rotate the copy so a long wait still feels like progress.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_900_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    captionIndex = (captionIndex + 1) % Self.processingCaptions.count
                }
            }
        }
    }

    /// What it is working out, in the host's terms rather than the system's.
    private static let processingCaptions = [
        "Looking around the room",
        "Spotting the good bits",
        "Working out a fair rent",
        "Writing your description",
        "Almost there"
    ]

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
                              : "wand.and.stars")
                    }
                    .foregroundStyle(draftFindings.isEmpty ? Color.orange : Color.secondary)
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
        var loadedData: [Data] = []
        var foundLocation: ListingDraftService.PhotoLocation?  // photo GPS, else the device

        for item in items {
            if Task.isCancelled { return }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }

            // The picker can hand back the same asset twice; uploading it twice
            // then looks like the other photos silently vanished.
            if loadedData.contains(data) { continue }

            loaded.append(image)
            loadedData.append(data)
            // Read the coordinates from the file itself, before UIImage drops
            // them. First photo that has them wins.
            if foundLocation == nil { foundLocation = Self.coordinates(in: data) }
        }

        if Task.isCancelled { return }
        photos = loaded
        photoData = loadedData

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
        Haptics.impact(.light)
        defer { isDrafting = false }


        do {
            let draft: ListingDraftService.Draft
            if let photo = image {
                draft = try await drafts.draft(from: photo, at: photoLocation)
            } else {
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
                : "AI filled this in as best it could. Check anything that matters."
            Haptics.notify(findings.isEmpty ? .warning : .success)
        } catch {
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
            showsProblem = true
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
                showsProblem = true
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

        // Snapshotted before the loop: this runs across await points, and
        // reading the state each time round meant a photo picked mid-upload
        // could change what was being sent.
        let outgoing = photoData
        for (index, data) in outgoing.enumerated() {
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

    private func close() {
        if let onClose { onClose() } else { dismiss() }
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
