import Foundation

struct ListingsFilter: Codable, Equatable {
    var city: String?
    var maxPrice: Int?
    var minPrice: Int?
    var houseType: String?
    var bedrooms: Int?
    var search: String?
    
    init(
        city: String? = nil,
        maxPrice: Int? = nil,
        minPrice: Int? = nil,
        houseType: String? = nil,
        bedrooms: Int? = nil,
        search: String? = nil
    ) {
        self.city = city
        self.maxPrice = maxPrice
        self.minPrice = minPrice
        self.houseType = houseType
        self.bedrooms = bedrooms
        self.search = search
    }
    
    static let empty = ListingsFilter()
    
    var isEmpty: Bool {
        return city == nil && 
               maxPrice == nil && 
               minPrice == nil && 
               houseType == nil && 
               bedrooms == nil && 
               search?.isEmpty != false
    }
    
    enum CodingKeys: String, CodingKey {
        case city, maxPrice, minPrice, bedrooms, search
        case houseType = "house_type"
    }
}