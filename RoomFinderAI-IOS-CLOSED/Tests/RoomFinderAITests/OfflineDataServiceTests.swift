import XCTest
import CoreData
import Combine
@testable import RoomFinderAI

class OfflineDataServiceTests: XCTestCase {
    var offlineDataService: OfflineDataService!
    var coreDataService: CoreDataService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Setup in-memory Core Data stack for testing
        coreDataService = CoreDataService.shared
        offlineDataService = OfflineDataService.shared
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing data
        try? coreDataService.clearAllData()
    }
    
    override func tearDown() {
        // Clean up
        try? coreDataService.clearAllData()
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Listings Tests
    
    func testSaveAndRetrieveListings() {
        // Given
        let mockListings = createMockListings(count: 5)
        
        // When
        offlineDataService.saveListings(mockListings, isInitialLoad: true)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save listings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        let retrievedListings = offlineDataService.getOfflineListings()
        
        // Then
        XCTAssertEqual(retrievedListings.count, 5)
        XCTAssertEqual(retrievedListings[0].title, "Test Listing 0")
        XCTAssertEqual(retrievedListings[0].price, 1000)
    }
    
    func testGetOfflineListingsWithPagination() {
        // Given
        let mockListings = createMockListings(count: 25)
        offlineDataService.saveListings(mockListings, isInitialLoad: true)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save listings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // When
        let firstPage = offlineDataService.getOfflineListings(limit: 10, offset: 0)
        let secondPage = offlineDataService.getOfflineListings(limit: 10, offset: 10)
        
        // Then
        XCTAssertEqual(firstPage.count, 10)
        XCTAssertEqual(secondPage.count, 10)
        XCTAssertNotEqual(firstPage[0].id, secondPage[0].id)
    }
    
    func testToggleFavorite() {
        // Given
        let mockListings = createMockListings(count: 3)
        offlineDataService.saveListings(mockListings, isInitialLoad: true)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save listings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        let listingId = mockListings[0].id
        
        // When
        offlineDataService.toggleFavorite(listingId: listingId)
        
        // Give it time to update
        let expectation2 = XCTestExpectation(description: "Toggle favorite")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: 1.0)
        
        let favoriteListings = offlineDataService.getFavoriteListings()
        
        // Then
        XCTAssertEqual(favoriteListings.count, 1)
        XCTAssertEqual(favoriteListings[0].id, listingId)
    }
    
    func testGetFavoriteListings() {
        // Given
        let mockListings = createMockListings(count: 5)
        offlineDataService.saveListings(mockListings, isInitialLoad: true)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save listings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Mark first two as favorites
        offlineDataService.toggleFavorite(listingId: mockListings[0].id)
        offlineDataService.toggleFavorite(listingId: mockListings[1].id)
        
        // Give it time to update
        let expectation2 = XCTestExpectation(description: "Toggle favorites")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: 1.0)
        
        // When
        let favoriteListings = offlineDataService.getFavoriteListings()
        
        // Then
        XCTAssertEqual(favoriteListings.count, 2)
        XCTAssertTrue(favoriteListings.contains { $0.id == mockListings[0].id })
        XCTAssertTrue(favoriteListings.contains { $0.id == mockListings[1].id })
    }
    
    // MARK: - User Tests
    
    func testSaveAndRetrieveUser() {
        // Given
        let mockUser = createMockUser(id: "user123", email: "test@example.com")
        
        // When
        offlineDataService.saveUser(mockUser)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save user")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        let retrievedUser = offlineDataService.getOfflineUser(id: "user123")
        
        // Then
        XCTAssertNotNil(retrievedUser)
        XCTAssertEqual(retrievedUser?.email, "test@example.com")
        XCTAssertEqual(retrievedUser?.firstName, "Test")
    }
    
    func testGetOfflineUserNonExistent() {
        // Given
        let nonExistentUserId = "nonexistent_user"
        
        // When
        let retrievedUser = offlineDataService.getOfflineUser(id: nonExistentUserId)
        
        // Then
        XCTAssertNil(retrievedUser)
    }
    
    // MARK: - Chat Tests
    
    func testSaveAndRetrieveChat() {
        // Given
        let mockChat = createMockChat(id: "chat123", participants: ["user1", "user2"])
        
        // When
        offlineDataService.saveChat(mockChat)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save chat")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        let retrievedChats = offlineDataService.getOfflineChats()
        
        // Then
        XCTAssertEqual(retrievedChats.count, 1)
        XCTAssertEqual(retrievedChats[0].id, "chat123")
        XCTAssertEqual(retrievedChats[0].participants.count, 2)
    }
    
    func testSaveAndRetrieveMessage() {
        // Given
        let mockMessage = createMockMessage(id: "message123", chatId: "chat123", content: "Hello World")
        
        // When
        offlineDataService.saveMessage(mockMessage)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save message")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        let retrievedMessages = offlineDataService.getOfflineMessages(chatId: "chat123")
        
        // Then
        XCTAssertEqual(retrievedMessages.count, 1)
        XCTAssertEqual(retrievedMessages[0].content, "Hello World")
        XCTAssertEqual(retrievedMessages[0].chatID, "chat123")
    }
    
    func testGetOfflineMessagesForDifferentChats() {
        // Given
        let message1 = createMockMessage(id: "msg1", chatId: "chat1", content: "Message 1")
        let message2 = createMockMessage(id: "msg2", chatId: "chat2", content: "Message 2")
        let message3 = createMockMessage(id: "msg3", chatId: "chat1", content: "Message 3")
        
        // When
        offlineDataService.saveMessage(message1)
        offlineDataService.saveMessage(message2)
        offlineDataService.saveMessage(message3)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save messages")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        let chat1Messages = offlineDataService.getOfflineMessages(chatId: "chat1")
        let chat2Messages = offlineDataService.getOfflineMessages(chatId: "chat2")
        
        // Then
        XCTAssertEqual(chat1Messages.count, 2)
        XCTAssertEqual(chat2Messages.count, 1)
        XCTAssertEqual(chat2Messages[0].content, "Message 2")
    }
    
    // MARK: - Search Tests
    
    func testSearchOfflineListings() {
        // Given
        let listings = [
            createMockListing(id: "1", title: "Beautiful Apartment", city: "New York"),
            createMockListing(id: "2", title: "Cozy House", city: "Los Angeles"),
            createMockListing(id: "3", title: "Modern Studio", city: "New York")
        ]
        
        offlineDataService.saveListings(listings, isInitialLoad: true)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save listings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // When
        let apartmentResults = offlineDataService.searchOfflineListings(query: "Apartment")
        let newYorkResults = offlineDataService.searchOfflineListings(query: "New York")
        let modernResults = offlineDataService.searchOfflineListings(query: "Modern")
        
        // Then
        XCTAssertEqual(apartmentResults.count, 1)
        XCTAssertEqual(apartmentResults[0].title, "Beautiful Apartment")
        
        XCTAssertEqual(newYorkResults.count, 2)
        XCTAssertEqual(modernResults.count, 1)
        XCTAssertEqual(modernResults[0].title, "Modern Studio")
    }
    
    func testFilterListings() {
        // Given
        let listings = [
            createMockListing(id: "1", title: "Cheap Apartment", price: 800, bedrooms: 1, bathrooms: 1, type: .apartment),
            createMockListing(id: "2", title: "Expensive House", price: 3000, bedrooms: 3, bathrooms: 2, type: .house),
            createMockListing(id: "3", title: "Mid-range Condo", price: 1500, bedrooms: 2, bathrooms: 1, type: .condo)
        ]
        
        offlineDataService.saveListings(listings, isInitialLoad: true)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save listings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // When
        let priceFiltered = offlineDataService.filterListings(
            priceRange: 1000...2000,
            bedrooms: nil,
            bathrooms: nil,
            propertyType: nil
        )
        
        let bedroomFiltered = offlineDataService.filterListings(
            priceRange: nil,
            bedrooms: 2,
            bathrooms: nil,
            propertyType: nil
        )
        
        let typeFiltered = offlineDataService.filterListings(
            priceRange: nil,
            bedrooms: nil,
            bathrooms: nil,
            propertyType: .apartment
        )
        
        // Then
        XCTAssertEqual(priceFiltered.count, 1)
        XCTAssertEqual(priceFiltered[0].title, "Mid-range Condo")
        
        XCTAssertEqual(bedroomFiltered.count, 2) // 2 or more bedrooms
        XCTAssertEqual(typeFiltered.count, 1)
        XCTAssertEqual(typeFiltered[0].title, "Cheap Apartment")
    }
    
    // MARK: - Cleanup Tests
    
    func testClearAllOfflineData() {
        // Given
        let mockListings = createMockListings(count: 3)
        let mockUser = createMockUser(id: "user123", email: "test@example.com")
        let mockChat = createMockChat(id: "chat123", participants: ["user1", "user2"])
        
        offlineDataService.saveListings(mockListings, isInitialLoad: true)
        offlineDataService.saveUser(mockUser)
        offlineDataService.saveChat(mockChat)
        
        // Give it time to save
        let expectation = XCTestExpectation(description: "Save data")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify data exists
        XCTAssertEqual(offlineDataService.getOfflineListings().count, 3)
        XCTAssertNotNil(offlineDataService.getOfflineUser(id: "user123"))
        XCTAssertEqual(offlineDataService.getOfflineChats().count, 1)
        
        // When
        offlineDataService.clearAllOfflineData()
        
        // Give it time to clear
        let expectation2 = XCTestExpectation(description: "Clear data")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: 1.0)
        
        // Then
        XCTAssertEqual(offlineDataService.getOfflineListings().count, 0)
        XCTAssertNil(offlineDataService.getOfflineUser(id: "user123"))
        XCTAssertEqual(offlineDataService.getOfflineChats().count, 0)
    }
    
    // MARK: - Network Status Tests
    
    func testNetworkStatusReactive() {
        // Given
        let expectation = XCTestExpectation(description: "Network status change")
        var receivedStatus: Bool?
        
        offlineDataService.$isOnline
            .sink { isOnline in
                receivedStatus = isOnline
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        // Note: This test depends on the actual network monitor implementation
        // In a real test, you might want to inject a mock network monitor
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedStatus)
    }
    
    // MARK: - Helper Methods
    
    private func createMockListings(count: Int) -> [Listing] {
        return Array(0..<count).map { index in
            createMockListing(id: "\(index)", title: "Test Listing \(index)", price: 1000 + Double(index * 100))
        }
    }
    
    private func createMockListing(
        id: String,
        title: String,
        price: Double = 1000,
        bedrooms: Int = 2,
        bathrooms: Int = 1,
        type: PropertyType = .apartment,
        city: String = "Test City"
    ) -> Listing {
        return Listing(
            id: id,
            title: title,
            price: price,
            bedrooms: bedrooms,
            bathrooms: bathrooms,
            propertyType: type,
            location: [
                "city": city,
                "state": "Test State",
                "address": "123 Test St",
                "zipCode": "12345"
            ],
            description: "Test description for \(title)",
            isActive: true,
            availableDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func createMockUser(id: String, email: String) -> User {
        return User(
            id: id,
            email: email,
            firstName: "Test",
            lastName: "User",
            phoneNumber: "123-456-7890",
            profileImageURL: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func createMockChat(id: String, participants: [String]) -> Chat {
        return Chat(
            id: id,
            propertyID: nil,
            participants: participants,
            type: .direct,
            lastMessage: "Test message",
            lastMessageDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func createMockMessage(id: String, chatId: String, content: String) -> Message {
        return Message(
            id: id,
            chatID: chatId,
            senderID: "user123",
            content: content,
            messageType: .text,
            isRead: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}