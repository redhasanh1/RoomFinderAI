import Foundation
import CoreData

@objc(CDListing)
public class CDListing: NSManagedObject {
    
}

extension CDListing {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDListing> {
        return NSFetchRequest<CDListing>(entityName: "CDListing")
    }
    
    @NSManaged public var id: String?
    @NSManaged public var title: String?
    @NSManaged public var price: Double
    @NSManaged public var bedrooms: Int32
    @NSManaged public var bathrooms: Int32
    @NSManaged public var propertyType: String?
    @NSManaged public var address: String?
    @NSManaged public var city: String?
    @NSManaged public var state: String?
    @NSManaged public var zipCode: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var details: String?
    @NSManaged public var imageURLs: [String]?
    @NSManaged public var isActive: Bool
    @NSManaged public var isFavorite: Bool
    @NSManaged public var availableDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncStatus: String?
}

extension CDListing: Identifiable {
    
}