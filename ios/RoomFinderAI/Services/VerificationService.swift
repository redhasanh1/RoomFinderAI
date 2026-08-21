import Foundation
import UIKit

/// Getting verified, natively.
///
/// The order of the two uploads is not cosmetic. `/api/verify/face-match`
/// refuses a selfie until a document exists for that address, answering with
/// "Please submit your ID document first before uploading a selfie" — so the
/// document is always sent first here, whichever one was chosen first on
/// screen. The web page had the same fix; this keeps it rather than inheriting
/// the bug again.
@MainActor
final class VerificationService: ObservableObject {

    struct Status: Decodable {
        struct Verification: Decodable {
            let id_verification_status: String?
            let face_verification_status: String?
        }
        let verification: Verification?
        let isVerified: Bool?
        let verifiedAt: String?
    }

    enum Stage: Equatable {
        case unknown
        case notStarted
        case pending
        case verified
        case rejected(String)
    }

    @Published private(set) var stage: Stage = .unknown
    @Published private(set) var isUploading = false
    @Published private(set) var progress: String?
    @Published var errorMessage: String?

    func loadStatus() async {
        guard let email = AuthService.shared.profile?.email else {
            stage = .notStarted
            return
        }

        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? email
        var request = URLRequest(url: AppConfig.url("api/verify/status/\(encoded)"))
        request.cachePolicy = .reloadIgnoringLocalCacheData

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let status = try? JSONDecoder().decode(Status.self, from: data) else {
            stage = .unknown
            return
        }

        if status.isVerified == true {
            stage = .verified
            return
        }

        let id = status.verification?.id_verification_status ?? "not_submitted"
        let face = status.verification?.face_verification_status ?? "not_submitted"

        if id == "rejected" || face == "rejected" {
            stage = .rejected("One of your documents was not accepted. Send it again.")
        } else if id == "not_submitted" && face == "not_submitted" {
            stage = .notStarted
        } else {
            stage = .pending
        }
    }

    /// Sends both images, document first.
    func submit(document: UIImage, selfie: UIImage) async {
        guard let email = AuthService.shared.profile?.email else {
            errorMessage = "You're not signed in."
            return
        }

        isUploading = true
        errorMessage = nil

        defer {
            isUploading = false
            progress = nil
        }

        // Shrunk before sending. A modern camera roll photo is several
        // megabytes, which on a phone connection is the difference between a
        // pause and a timeout, and the checks read it at a fraction of that.
        guard let documentData = Self.shrink(document) else {
            errorMessage = "That photo of your ID couldn't be prepared. Try another."
            return
        }
        guard let selfieData = Self.shrink(selfie) else {
            errorMessage = "That selfie couldn't be prepared. Try another."
            return
        }

        do {
            progress = "Uploading ID document…"
            try await upload(
                path: "api/verify/upload-id",
                field: "idDocument",
                filename: "id.jpg",
                data: documentData,
                email: email
            )

            progress = "Uploading selfie…"
            try await upload(
                path: "api/verify/face-match",
                field: "facePhoto",
                filename: "selfie.jpg",
                data: selfieData,
                email: email
            )

            stage = .pending
            Haptics.notify(.success)
        } catch let failure as AuthService.Failure {
            errorMessage = failure.message
            Haptics.notify(.error)
        } catch {
            errorMessage = "Couldn't send those. Check your connection and try again."
            Haptics.notify(.error)
        }
    }

    private func upload(path: String, field: String, filename: String,
                        data: Data, email: String) async throws {
        let boundary = "rf-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) {
            body.append(string.data(using: .utf8)!)
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"userEmail\"\r\n\r\n")
        append("\(email)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: AppConfig.url(path))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // Generous, because this is two photos over whatever connection the
        // phone happens to have.
        request.timeoutInterval = 120
        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthService.Failure(message: "No answer from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            // These messages are the whole point of the screen: the server
            // knows whether it could not find a face, found several, or could
            // not see an ID at all, and only it can say which.
            struct Refusal: Decodable { let error: String?; let message: String? }
            let stated = try? JSONDecoder().decode(Refusal.self, from: responseData)
            throw AuthService.Failure(
                message: stated?.error ?? stated?.message
                    ?? "That upload didn't go through (error \(http.statusCode))."
            )
        }
    }

    /// Longest edge to 1600pt, JPEG at 0.8.
    private static func shrink(_ image: UIImage) -> Data? {
        let limit: CGFloat = 1600
        let longest = max(image.size.width, image.size.height)

        guard longest > limit else { return image.jpegData(compressionQuality: 0.8) }

        let scale = limit / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.jpegData(compressionQuality: 0.8)
    }
}
