import Foundation
import CoreData

@objc(CDChat)
public class CDChat: NSManagedObject {
    
}

extension CDChat {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDChat> {
        return NSFetchRequest<CDChat>(entityName: "CDChat")
    }
    
    @NSManaged public var id: String?
    @NSManaged public var propertyID: String?
    @NSManaged public var participantsData: Data?
    @NSManaged public var type: String?
    @NSManaged public var lastMessage: String?
    @NSManaged public var lastMessageDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncStatus: String?
}

extension CDChat: Identifiable {
    
}