import Foundation
import CoreData

@objc(CDMessage)
public class CDMessage: NSManagedObject {
    
}

extension CDMessage {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDMessage> {
        return NSFetchRequest<CDMessage>(entityName: "CDMessage")
    }
    
    @NSManaged public var id: String?
    @NSManaged public var chatID: String?
    @NSManaged public var senderID: String?
    @NSManaged public var content: String?
    @NSManaged public var messageType: String?
    @NSManaged public var isRead: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncStatus: String?
}

extension CDMessage: Identifiable {
    
}