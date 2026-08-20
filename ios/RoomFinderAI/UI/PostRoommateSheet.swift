import PhotosUI
import SwiftUI

/// Post your own roommate profile, with photos.
///
/// The marketplace was read-only from the app: you could scroll a hundred
/// strangers and never appear in it yourself. Two sides, one form, because a
/// person looking for a room and a person with a room to fill need opposite
/// things asked of them — a budget they can stretch to, or a rent and photos of
/// the place.
struct PostRoommateSheet: View {

    var onPosted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var user = CurrentUser.shared

    @State private var kind: RoommateProfile.Kind = .seeking
    @State private var name = ""
    @State private var bio = ""
    @State private var areas = ""
    @State private var moveInDate = Date()
    @State private var setsMoveIn = true

    @State private var budgetMin = ""
    @State private var budgetMax = ""

    @State private var roomRent = ""
    @State private var roomLocation = ""
    @State private var roomDescription = ""

    @State private var avatarItem: PhotosPickerItem?
    @State private var avatar: UIImage?
    @State private var avatarData: Data?

    @State private var roomItems: [PhotosPickerItem] = []
    @State private var roomPhotos: [UIImage] = []
    @State private var roomPhotoData: [Data] = []

    @State private var isPosting = false
    @State private var progressNote: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("I need a room").tag(RoommateProfile.Kind.seeking)
                        Text("I have a room").tag(RoommateProfile.Kind.hasSpot)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, _ in Haptics.select() }
                } footer: {
                    Text(kind == .seeking
                         ? "You're looking for a place with someone already in it."
                         : "You have a spare room and you're looking for the person to fill it.")
                }

                photoSection

                Section("You") {
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)

                    TextField("A few words about you: schedule, habits, what you're like to live with.",
                              text: $bio, axis: .vertical)
                        .lineLimit(3...8)
                }

                if kind == .seeking {
                    Section {
                        HStack {
                            Text("$").foregroundStyle(.secondary)
                            TextField("Least", text: $budgetMin).keyboardType(.numberPad)
                            Text("to $").foregroundStyle(.secondary)
                            TextField("Most", text: $budgetMax).keyboardType(.numberPad)
                        }
                        TextField("Areas you'd live in, separated by commas", text: $areas)
                            .textInputAutocapitalization(.words)
                    } header: {
                        Text("What you can pay")
                    } footer: {
                        Text("A range gets you more replies than a hard number.")
                    }
                } else {
                    Section("The room") {
                        HStack {
                            Text("$").foregroundStyle(.secondary)
                            TextField("900", text: $roomRent).keyboardType(.numberPad)
                            Text("/month").foregroundStyle(.secondary)
                        }
                        TextField("Where it is", text: $roomLocation)
                            .textInputAutocapitalization(.words)
                        TextField("The place, the other people in it, house rules.",
                                  text: $roomDescription, axis: .vertical)
                            .lineLimit(3...8)
                    }
                }

                Section {
                    Toggle("I know when I'm moving", isOn: $setsMoveIn.animation())
                    if setsMoveIn {
                        DatePicker("Move in", selection: $moveInDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Timing")
                }

                if let progressNote {
                    Section {
                        Label(progressNote, systemImage: "arrow.up.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !user.isSignedIn {
                    Section {
                        Label("Sign in from the Profile tab first. A profile nobody can message is a dead end.",
                              systemImage: "person.crop.circle.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Post your profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isPosting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Button("Post") { Task { await post() } }
                            .fontWeight(.semibold)
                            .disabled(!canPost)
                    }
                }
            }
        }
    }

    // MARK: - Photos

    /// A face first, then the room. People decide whether to read a profile
    /// from the picture, and a card with initials in a circle reads as an
    /// account somebody abandoned.
    private var photoSection: some View {
        Section {
            HStack(spacing: 14) {
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    Group {
                        if let avatar {
                            Image(uiImage: avatar)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Circle().fill(Theme.brand.opacity(0.12))
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.brand)
                            }
                        }
                    }
                    .frame(width: 68, height: 68)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(avatar == nil ? "Add a photo of you" : "Change photo")
                        .font(.subheadline.weight(.semibold))
                    Text("Profiles with a face get answered far more often.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

            if kind == .hasSpot {
                PhotosPicker(selection: $roomItems, maxSelectionCount: 6, matching: .images) {
                    Label(roomPhotos.isEmpty
                          ? "Add photos of the room"
                          : "\(roomPhotos.count) photo\(roomPhotos.count == 1 ? "" : "s") of the room",
                          systemImage: "photo.on.rectangle.angled")
                }

                if !roomPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(roomPhotos.enumerated()), id: \.offset) { _, photo in
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        } header: {
            Text("Photos")
        }
        .onChange(of: avatarItem) { _, item in
            Task { await loadAvatar(item) }
        }
        .onChange(of: roomItems) { _, items in
            Task { await loadRoomPhotos(items) }
        }
    }

    private func loadAvatar(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        // Downscaled before it leaves the phone: a modern camera photo is
        // several megabytes and this is shown at 68 points.
        let shrunk = Self.shrink(data, to: 900)
        avatarData = shrunk
        avatar = UIImage(data: shrunk)
    }

    private func loadRoomPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        var payloads: [Data] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let shrunk = Self.shrink(data, to: 1600)
            if let image = UIImage(data: shrunk) {
                images.append(image)
                payloads.append(shrunk)
            }
        }
        roomPhotos = images
        roomPhotoData = payloads
    }

    private static func shrink(_ data: Data, to maxEdge: CGFloat) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge else { return image.jpegData(compressionQuality: 0.8) ?? data }

        let scale = maxEdge / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }

    // MARK: - Posting

    private var canPost: Bool {
        guard user.isSignedIn, !name.trimmed.isEmpty else { return false }
        return kind == .seeking ? Int(budgetMax.trimmed) ?? 0 > 0
                                : Int(roomRent.trimmed) ?? 0 > 0
    }

    private func post() async {
        guard let email = user.email else { return }
        isPosting = true
        errorMessage = nil

        do {
            var avatarUrl: String?
            var roomUrls: [String] = []

            if avatarData != nil || !roomPhotoData.isEmpty {
                progressNote = "Uploading photos"
                // One request. The avatar goes first so its URL is the one at
                // index zero, whatever order the picker handed things back in.
                let outgoing = [avatarData].compactMap { $0 } + roomPhotoData
                let urls = try await upload(outgoing, email: email)
                var remaining = urls
                if avatarData != nil, !remaining.isEmpty {
                    avatarUrl = remaining.removeFirst()
                }
                roomUrls = remaining
            }

            progressNote = "Saving your profile"
            try await save(email: email, avatarUrl: avatarUrl, roomUrls: roomUrls)

            Haptics.impact(.medium)
            onPosted()
            dismiss()
        } catch let failure as PostRoommateError {
            errorMessage = failure.message
        } catch {
            errorMessage = "Couldn't reach the server. Check your connection."
        }
        progressNote = nil
        isPosting = false
    }

    private func upload(_ payloads: [Data], email: String) async throws -> [String] {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"userEmail\"\r\n\r\n\(email)\r\n")

        for (index, data) in payloads.enumerated() {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"photos\"; filename=\"roommate-\(index).jpg\"\r\n")
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
            throw PostRoommateError(message: "Your photos couldn't be uploaded. Try again, or post without them.")
        }
        struct UploadResponse: Decodable { let urls: [String]? }
        return (try? JSONDecoder().decode(UploadResponse.self, from: data))?.urls ?? []
    }

    private func save(email: String, avatarUrl: String?, roomUrls: [String]) async throws {
        var payload: [String: Any] = [
            "userEmail": email,
            "name": name.trimmed,
            "userType": kind.rawValue,
            "bio": bio.trimmed
        ]
        if let avatarUrl { payload["avatarUrl"] = avatarUrl }
        if setsMoveIn { payload["moveInDate"] = Self.day(moveInDate) }

        if kind == .seeking {
            if let low = Int(budgetMin.trimmed), low > 0 { payload["budgetMin"] = low }
            payload["budgetMax"] = Int(budgetMax.trimmed) ?? 0
            let list = areas.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            payload["preferredAreas"] = list
        } else {
            payload["roomRent"] = Int(roomRent.trimmed) ?? 0
            payload["roomLocation"] = roomLocation.trimmed
            payload["roomDescription"] = roomDescription.trimmed
            payload["roomPhotos"] = roomUrls
        }

        var request = URLRequest(url: AppConfig.url("api/roommate-profiles"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            struct Failure: Decodable { let message: String?; let details: String? }
            let decoded = try? JSONDecoder().decode(Failure.self, from: data)
            throw PostRoommateError(message: decoded?.message ?? "Couldn't save that. Try again in a moment.")
        }
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct PostRoommateError: Error { let message: String }

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
