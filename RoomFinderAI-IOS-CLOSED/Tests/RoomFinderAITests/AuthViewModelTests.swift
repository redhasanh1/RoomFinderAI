import XCTest
@testable import RoomFinderAI

class AuthViewModelTests: XCTestCase {
    var authViewModel: AuthViewModel!
    
    override func setUp() {
        super.setUp()
        authViewModel = AuthViewModel()
    }
    
    override func tearDown() {
        authViewModel = nil
        super.tearDown()
    }
    
    // MARK: - Email Validation Tests
    
    func testValidEmail() {
        XCTAssertTrue(authViewModel.validateEmail("test@example.com"))
        XCTAssertTrue(authViewModel.validateEmail("user.name@domain.co.uk"))
        XCTAssertTrue(authViewModel.validateEmail("user+tag@example.org"))
    }
    
    func testInvalidEmail() {
        XCTAssertFalse(authViewModel.validateEmail(""))
        XCTAssertFalse(authViewModel.validateEmail("invalid-email"))
        XCTAssertFalse(authViewModel.validateEmail("test@"))
        XCTAssertFalse(authViewModel.validateEmail("@example.com"))
        XCTAssertFalse(authViewModel.validateEmail("test.example.com"))
    }
    
    // MARK: - Password Validation Tests
    
    func testValidPassword() {
        XCTAssertTrue(authViewModel.validatePassword("password123"))
        XCTAssertTrue(authViewModel.validatePassword("StrongPassword1"))
        XCTAssertTrue(authViewModel.validatePassword("12345678"))
    }
    
    func testInvalidPassword() {
        XCTAssertFalse(authViewModel.validatePassword(""))
        XCTAssertFalse(authViewModel.validatePassword("short"))
        XCTAssertFalse(authViewModel.validatePassword("1234567"))
    }
    
    // MARK: - Password Confirmation Tests
    
    func testPasswordConfirmation() {
        let password = "testPassword123"
        let matchingConfirmation = "testPassword123"
        let nonMatchingConfirmation = "differentPassword"
        
        XCTAssertTrue(authViewModel.validatePasswordConfirmation(password, matchingConfirmation))
        XCTAssertFalse(authViewModel.validatePasswordConfirmation(password, nonMatchingConfirmation))
        XCTAssertFalse(authViewModel.validatePasswordConfirmation("short", "short"))
    }
    
    // MARK: - Authentication State Tests
    
    func testInitialAuthState() {
        XCTAssertFalse(authViewModel.isAuthenticated)
        XCTAssertNil(authViewModel.currentUser)
        XCTAssertFalse(authViewModel.isLoading)
        XCTAssertNil(authViewModel.errorMessage)
    }
    
    func testErrorHandling() {
        XCTAssertFalse(authViewModel.hasError)
        
        authViewModel.errorMessage = "Test error"
        XCTAssertTrue(authViewModel.hasError)
        
        authViewModel.clearError()
        XCTAssertFalse(authViewModel.hasError)
        XCTAssertNil(authViewModel.errorMessage)
    }
    
    // MARK: - Performance Tests
    
    func testEmailValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = authViewModel.validateEmail("test@example.com")
            }
        }
    }
    
    func testPasswordValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = authViewModel.validatePassword("password123")
            }
        }
    }
}

// MARK: - Mock Data Extensions

extension AuthViewModelTests {
    func createMockUser() -> User {
        return User(
            id: "test-user-id",
            email: "test@example.com",
            name: "Test User",
            avatar: nil,
            phone: nil,
            location: nil,
            preferences: nil,
            createdAt: Date(),
            updatedAt: Date(),
            verificationStatus: .verified,
            subscriptionStatus: .free
        )
    }
}

// MARK: - Async Testing Extensions

extension AuthViewModelTests {
    func testSignUpValidation() async {
        let expectation = XCTestExpectation(description: "Sign up validation")
        
        Task {
            // Test with valid data
            let validEmail = "test@example.com"
            let validPassword = "password123"
            let validName = "Test User"
            
            XCTAssertTrue(authViewModel.validateEmail(validEmail))
            XCTAssertTrue(authViewModel.validatePassword(validPassword))
            XCTAssertFalse(validName.isEmpty)
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testSignInValidation() async {
        let expectation = XCTestExpectation(description: "Sign in validation")
        
        Task {
            // Test with valid credentials
            let validEmail = "test@example.com"
            let validPassword = "password123"
            
            XCTAssertTrue(authViewModel.validateEmail(validEmail))
            XCTAssertTrue(authViewModel.validatePassword(validPassword))
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}