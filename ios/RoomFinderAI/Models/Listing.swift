import Foundation

/// A room or apartment as returned by `/api/listings`.
struct Listing: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let description: String?
    let price: Double?
    let location: String?
    let address: String?
    let bedrooms: Int?
    let bathrooms: Int?
    let imageUrl: String?
    /// Every photo, when the server offers them. Older responses only carried
    /// `imageUrl`, so this stays optional and falls back to it.
    let imageUrls: [String]?
    let propertyType: String?
    let available: Bool?
    let userVerified: Bool?
    /// Who posted it — needed so a report can offer to block them.
    let userEmail: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, price, location, address
        case bedrooms, bathrooms, imageUrl, imageUrls, propertyType, available
        case userVerified = "user_verified"
        case userEmail = "user_email"
    }

    /// Some rows carry a `[rf-catalog]` marker used by the website's seeding,
    /// which should never be shown to a person.
    var cleanDescription: String? {
        description?
            .replacingOccurrences(of: "[rf-catalog]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    var priceText: String {
        guard let price, price > 0 else { return "Price on request" }
        return "$\(Int(price))/mo"
    }

    /// "2 bed · 1 bath · Apartment", skipping anything the row does not have
    /// rather than printing "0 bed".
    var summaryLine: String {
        var parts: [String] = []
        if let bedrooms, bedrooms > 0 { parts.append("\(bedrooms) bed") }
        if let bathrooms, bathrooms > 0 { parts.append("\(bathrooms) bath") }
        if let propertyType, !propertyType.isEmpty { parts.append(propertyType) }
        return parts.joined(separator: " · ")
    }

    var displayLocation: String {
        location?.nilIfEmpty ?? address?.nilIfEmpty ?? "Location not specified"
    }

    var imageURL: URL? {
        guard let imageUrl, !imageUrl.isEmpty else { return nil }
        return URL(string: imageUrl)
    }

    /// The gallery, in order. Falls back to the single image so a room posted
    /// before the server sent the full set still shows its photo.
    var galleryURLs: [URL] {
        let candidates = (imageUrls?.isEmpty == false) ? imageUrls! : [imageUrl].compactMap { $0 }
        return candidates.compactMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    /// The web page for this listing, used when the native screen hands off for
    /// contacting a landlord or starting a negotiation.
    var detailURL: URL {
        AppConfig.url("listing_details.html?id=\(id)")
    }
}

/// The API wraps every payload as `{ success, data, message }`.
struct ListingsResponse: Decodable {
    let success: Bool
    let data: [Listing]?
    let message: String?
}

extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
