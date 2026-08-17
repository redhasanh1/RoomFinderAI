import UIKit

/// Fills in a listing for the host instead of making them write one.
///
/// Two routes, matching what the site already does:
///   • a photo goes to `/api/analyze-property-photo`, which runs Cloudflare's
///     Llama 3.2 Vision model and reads the room itself
///   • no photo falls back to `/api/listings/draft`, which writes from the
///     facts already typed in
///
/// Writing the description is where people abandon posting a room, so this is
/// the difference between a listing existing and not.
@MainActor
final class ListingDraftService {

    struct Draft {
        var title: String?
        var description: String?
        var houseType: String?
        var bedrooms: Int?
    }

    enum DraftError: LocalizedError {
        case noInput
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .noInput: return "Add a photo, or fill in the city and property type first."
            case .failed(let message): return message
            }
        }
    }

    /// Reads the room from a photo.
    func draft(from image: UIImage) async throws -> Draft {
        // Downscaled before sending: the endpoint takes the image as a JSON
        // array of bytes, which is roughly four times the size of the raw
        // file, so a full-resolution phone photo would be a multi-megabyte
        // request for no extra accuracy.
        guard let data = Self.downscaledJPEG(image, maxDimension: 900) else {
            throw DraftError.failed("That photo could not be read.")
        }

        var request = URLRequest(url: AppConfig.url("api/analyze-property-photo"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Vision models are slow; this is the one place a long wait is expected.
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: ["image": Array(data)])

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DraftError.failed("The photo analysis service could not be reached.")
        }

        struct AnalysisResponse: Decodable {
            struct Analysis: Decodable {
                let title: String?
                let description: String?
                let house_type: String?
                let bedrooms: Int?
            }
            let success: Bool
            let analysis: Analysis?
            let error: String?
        }

        let decoded = try JSONDecoder().decode(AnalysisResponse.self, from: responseData)
        guard decoded.success, let analysis = decoded.analysis else {
            throw DraftError.failed(decoded.error ?? "The photo could not be analysed.")
        }

        return Draft(
            title: analysis.title,
            description: analysis.description,
            houseType: analysis.house_type,
            bedrooms: analysis.bedrooms
        )
    }

    /// Writes from the details already entered, when there is no photo yet.
    func draft(city: String, street: String, houseType: String,
               bedrooms: Int, price: String, utilitiesIncluded: Bool,
               notes: String) async throws -> Draft {
        guard !city.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw DraftError.noInput
        }

        var body: [String: Any] = [
            "city": city,
            "houseType": houseType,
            "bedrooms": bedrooms,
            "utilities": utilitiesIncluded ? "included" : "not included"
        ]
        if !street.isEmpty { body["street"] = street }
        if let value = Int(price.filter(\.isNumber)), value > 0 { body["price"] = value }
        if !notes.isEmpty { body["notes"] = notes }

        var request = URLRequest(url: AppConfig.url("api/listings/draft"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DraftError.failed("No response from the server.")
        }

        struct DraftResponse: Decodable {
            let success: Bool?
            let title: String?
            let description: String?
            let message: String?
        }
        let decoded = try? JSONDecoder().decode(DraftResponse.self, from: data)

        guard (200..<300).contains(http.statusCode), decoded?.success == true else {
            throw DraftError.failed(decoded?.message ?? "Could not write a draft right now.")
        }

        return Draft(title: decoded?.title, description: decoded?.description)
    }

    /// Longest edge capped, re-encoded as JPEG.
    private static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }

        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }
}
