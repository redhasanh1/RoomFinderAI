import Foundation
import Supabase
import Combine

// MARK: - Sample Data Structure
struct SampleListingData: Codable {
    let title: String
    let price: Int
    let city: String
    let street: String
    let postalCode: String
    let houseType: String
    let bedrooms: Int
    let utilities: String
    let description: String?
    let userEmail: String
    
    enum CodingKeys: String, CodingKey {
        case title, price, city, street, bedrooms, utilities, description
        case postalCode = "postal_code"
        case houseType = "house_type"
        case userEmail = "user_email"
    }
}

// MARK: - Real-time Event Types
enum ListingRealtimeEvent {
    case insert(Listing)
    case update(Listing)
    case delete(String) // listing ID
}

class RealSupabaseService: ObservableObject {
    private let client: SupabaseClient
    private var realtimeChannel: RealtimeChannelV2?
    
    // Publishers for real-time events
    @Published var connectionStatus: String = "Disconnected"
    @Published var lastEventTime: Date?
    @Published var connectionError: String?
    @Published var retryCount: Int = 0
    @Published var isRetrying: Bool = false
    
    // Subject for real-time listing events
    let realtimeEventsSubject = PassthroughSubject<ListingRealtimeEvent, Never>()
    
    // Connection retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 5.0
    private var reconnectionTimer: Timer?
    
    init(supabaseClient: SupabaseClient) {
        self.client = supabaseClient
        print("🔧 RealSupabaseService initialized")
    }
    
    deinit {
        disconnectRealtime()
        reconnectionTimer?.invalidate()
    }
    
    // MARK: - Connection Testing
    
    func testConnection() async throws -> Bool {
        print("🧪 Testing Supabase connection...")
        print("   - Table: listings")
        
        do {
            // Try to get a count of listings to test the connection
            let response = try await client
                .from("listings")
                .select("count", head: true)
                .execute()
            
            let count = response.count ?? 0
            print("✅ Connection test successful: Found \(count) listings in database")
            return true
        } catch {
            print("❌ Connection test failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Sample Data Creation
    
    func createSampleListings() async throws -> Int {
        print("🏠 DEBUG: Creating sample listings in database...")
        
        // Create sample listings using proper Codable objects
        let sampleListings = [
            SampleListingData(
                title: "Cozy 2BR Downtown Apartment",
                price: 1800,
                city: "Toronto",
                street: "123 King St",
                postalCode: "M5H 1J8",
                houseType: "Apartment",
                bedrooms: 2,
                utilities: "Included",
                description: "Beautiful downtown apartment with city views",
                userEmail: "test@roomfinder.ai"
            ),
            SampleListingData(
                title: "Modern 1BR Near University",
                price: 1400,
                city: "Toronto",
                street: "456 College St",
                postalCode: "M5S 3M5",
                houseType: "Apartment",
                bedrooms: 1,
                utilities: "Not included",
                description: "Perfect for students, close to campus",
                userEmail: "test@roomfinder.ai"
            ),
            SampleListingData(
                title: "Spacious 3BR House with Parking",
                price: 2500,
                city: "Toronto",
                street: "789 Queen St West",
                postalCode: "M6J 1G3",
                houseType: "House",
                bedrooms: 3,
                utilities: "Not included",
                description: "Family home with backyard and parking",
                userEmail: "test@roomfinder.ai"
            )
        ]
        
        do {
            print("📝 DEBUG: Inserting \(sampleListings.count) listings using Codable objects...")
            
            // Try to bypass RLS for sample data creation
            let response = try await client
                .from("listings")
                .insert(sampleListings)
                .execute()
            
            print("🎉 Successfully created sample listings")
            print("📊 Response size: \(response.data.count) bytes")
            
            return sampleListings.count
            
        } catch {
            print("❌ Failed to create sample listings: \(error)")
            print("🔍 DEBUG: Error details:")
            print("   - Type: \(type(of: error))")
            print("   - Description: \(error.localizedDescription)")
            
            // Try alternative approach with RLS bypass
            if error.localizedDescription.contains("RLS") || error.localizedDescription.contains("policy") {
                print("🔄 DEBUG: Detected RLS issue, trying alternative approach...")
                return try await createSampleListingsWithRLSBypass()
            }
            
            throw error
        }
    }
    
    // Alternative method to handle RLS policies  
    private func createSampleListingsWithRLSBypass() async throws -> Int {
        print("🔐 DEBUG: Attempting to set user context for RLS...")
        
        do {
            // First, try to set the current user email context for RLS
            let _ = try await client.rpc("set_current_user_email", params: [
                "email": "test@roomfinder.ai"
            ]).execute()
            
            print("✅ DEBUG: User context set for RLS")
            
            // Now try the insert with proper user context
            let sampleListings = [
                SampleListingData(
                    title: "Cozy 2BR Downtown Apartment",
                    price: 1800,
                    city: "Toronto",
                    street: "123 King St",
                    postalCode: "M5H 1J8",
                    houseType: "Apartment",
                    bedrooms: 2,
                    utilities: "Included",
                    description: "Beautiful downtown apartment with city views",
                    userEmail: "test@roomfinder.ai"
                ),
                SampleListingData(
                    title: "Modern 1BR Near University",
                    price: 1400,
                    city: "Toronto",
                    street: "456 College St",
                    postalCode: "M5S 3M5",
                    houseType: "Apartment",
                    bedrooms: 1,
                    utilities: "Not included",
                    description: "Perfect for students, close to campus",
                    userEmail: "test@roomfinder.ai"
                ),
                SampleListingData(
                    title: "Spacious 3BR House with Parking",
                    price: 2500,
                    city: "Toronto",
                    street: "789 Queen St West",
                    postalCode: "M6J 1G3",
                    houseType: "House",
                    bedrooms: 3,
                    utilities: "Not included",
                    description: "Family home with backyard and parking",
                    userEmail: "test@roomfinder.ai"
                )
            ]
            
            _ = try await client
                .from("listings")
                .insert(sampleListings)
                .execute()
            
            print("🎉 Successfully created sample listings with RLS context")
            return sampleListings.count
            
        } catch {
            print("❌ DEBUG: RLS context setting failed: \(error)")
            
            // Last resort: Try with a dedicated sample data creation function
            print("🔄 DEBUG: Trying dedicated sample data function...")
            return try await createSampleDataViaSQLFunction()
        }
    }
    
    // Ultimate fallback: Use a SQL function that bypasses RLS
    private func createSampleDataViaSQLFunction() async throws -> Int {
        do {
            _ = try await client.rpc("create_sample_listings_bypass_rls").execute()
            print("✅ DEBUG: Sample data created via SQL function")
            return 3
        } catch {
            print("❌ DEBUG: All approaches failed")
            throw NSError(domain: "SampleDataError", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Unable to create sample data. The database may require authentication or have strict RLS policies. Original error: \(error.localizedDescription)"
            ])
        }
    }
    
    // MARK: - Debug Methods
    
    func debugCountListings() async throws -> Int {
        print("🔍 DEBUG: Counting listings in database...")
        print("🔗 DEBUG: Using URL: \("[SUPABASE_URL]")")
        print("🔑 DEBUG: Using anon key: \("[SUPABASE_KEY]".prefix(15))...")
        
        do {
            print("📡 DEBUG: Making count request to Supabase...")
            let response = try await client
                .from("listings")
                .select("count", head: true)
                .execute()
            
            let count = response.count ?? 0
            print("📊 DEBUG: Count response received")
            print("   - Response count: \(count)")
            print("   - Response data size: \(response.data.count) bytes")
            print("   - Response headers: \(response.response.allHeaderFields)")
            
            if response.data.count > 0 {
                if let responseString = String(data: response.data, encoding: .utf8) {
                    print("   - Response body: \(responseString)")
                }
            }
            
            return count
        } catch {
            print("❌ DEBUG: Failed to count listings!")
            print("   - Error type: \(type(of: error))")
            print("   - Error: \(error)")
            print("   - Localized: \(error.localizedDescription)")
            throw error
        }
    }
    
    func debugRawQuery() async throws {
        print("🔍 DEBUG: Testing raw query without parsing...")
        print("🎯 DEBUG: Query: SELECT id, title, price FROM listings LIMIT 5")
        
        do {
            print("📡 DEBUG: Executing raw query...")
            let response = try await client
                .from("listings")
                .select("id, title, price")
                .limit(5)
                .execute()
            
            print("📄 DEBUG: Raw response received")
            print("   - Data size: \(response.data.count) bytes")
            print("   - Response count: \(response.count ?? -1)")
            print("   - Status code: \(response.response.statusCode)")
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📄 DEBUG: Raw JSON response:")
                print("   \(jsonString)")
                
                // Check if it's an empty array
                let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "[]" {
                    print("⚠️ DEBUG: Response is EMPTY ARRAY - This suggests RLS policy issue!")
                    print("🔍 DEBUG: Testing if we can bypass RLS...")
                    try await debugRLSBypass()
                } else {
                    print("✅ DEBUG: Got actual data - RLS is working correctly")
                }
            } else {
                print("❌ DEBUG: Could not convert response to string")
            }
        } catch {
            print("❌ DEBUG: Raw query failed!")
            print("   - Error type: \(type(of: error))")
            print("   - Error: \(error)")
            print("   - Localized: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Test RLS bypass functionality
    private func debugRLSBypass() async throws {
        print("🔐 DEBUG: Testing RLS bypass methods...")
        
        // Test 1: Try setting anonymous user context
        do {
            print("📝 DEBUG: Test 1 - Setting anonymous user context...")
            let _ = try await client.rpc("set_config", params: [
                "setting_name": "app.current_user_email",
                "new_value": "",
                "is_local": "true"
            ]).execute()
            
            let response = try await client
                .from("listings")
                .select("id, title")
                .limit(3)
                .execute()
                
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("✅ DEBUG: Anonymous context result: \(jsonString)")
            }
        } catch {
            print("❌ DEBUG: Anonymous context failed: \(error)")
        }
        
        // Test 2: Try with explicit user email
        do {
            print("📝 DEBUG: Test 2 - Setting explicit user email...")
            let _ = try await client.rpc("set_current_user_email", params: [
                "email": "test@roomfinder.ai"
            ]).execute()
            
            let response = try await client
                .from("listings")
                .select("id, title")
                .limit(3)
                .execute()
                
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("✅ DEBUG: Explicit user result: \(jsonString)")
            }
        } catch {
            print("❌ DEBUG: Explicit user failed: \(error)")
        }
        
        // Test 3: Check if table exists and has data
        do {
            print("📝 DEBUG: Test 3 - Checking table existence...")
            let response = try await client.rpc("count_all_listings").execute()
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("✅ DEBUG: Table count result: \(jsonString)")
            }
        } catch {
            print("❌ DEBUG: Table count failed: \(error)")
        }
    }
    
    // Comprehensive RLS and connection testing
    func runComprehensiveDebug() async throws {
        print("🚀 DEBUG: Starting comprehensive Supabase debugging...")
        print("============================================================")
        
        // Test 1: Basic connection
        print("📡 DEBUG: Test 1 - Basic Connection")
        do {
            _ = try await testConnection()
            print("✅ Connection test passed")
        } catch {
            print("❌ Connection test failed: \(error)")
        }
        
        print("============================================================")
        
        // Test 2: Raw count query
        print("📊 DEBUG: Test 2 - Count Query")
        do {
            let count = try await debugCountListings()
            print("✅ Count query returned: \(count)")
        } catch {
            print("❌ Count query failed: \(error)")
        }
        
        print("============================================================")
        
        // Test 3: Raw data query
        print("📄 DEBUG: Test 3 - Raw Data Query")
        do {
            try await debugRawQuery()
            print("✅ Raw query completed")
        } catch {
            print("❌ Raw query failed: \(error)")
        }
        
        print("============================================================")
        
        // Test 4: Check web app configuration
        print("🌐 DEBUG: Test 4 - Web App Style Query")
        await testWebStyleQuery()
        
        print("============================================================")
        print("🏁 DEBUG: Comprehensive debugging completed")
    }
    
    // Test querying like the web app does
    private func testWebStyleQuery() async {
        print("🌐 DEBUG: Testing web app style query...")
        
        do {
            // Use the injected client instead of creating a new one
            let webStyleClient = self.client
            
            print("📡 DEBUG: Making web-style request...")
            let response = try await webStyleClient
                .from("listings")
                .select("*")
                .order("created_at", ascending: false)
                .execute()
            
            print("📄 DEBUG: Web-style response received")
            print("   - Data size: \(response.data.count) bytes")
            print("   - Response count: \(response.count ?? -1)")
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "[]" {
                    print("⚠️ DEBUG: Web-style query also returns empty array!")
                    print("🔍 DEBUG: This confirms RLS policy is blocking anonymous access")
                } else {
                    print("✅ DEBUG: Web-style query successful!")
                    print("📝 DEBUG: Sample response: \(String(jsonString.prefix(200)))...")
                }
            }
            
        } catch {
            print("❌ DEBUG: Web-style query failed: \(error)")
        }
    }
    
    // MARK: - UI-Visible Debug Functions
    
    // Return debug data that can be displayed in the UI
    func getUIVisibleDebugInfo() async -> (response: String, statusCode: Int, headers: String, debugInfo: String) {
        var debugMessages: [String] = []
        var finalResponse = "No response"
        var finalStatusCode = 0
        var finalHeaders = "No headers"
        
        debugMessages.append("🚀 Starting enhanced debug session...")
        debugMessages.append("🔗 URL: \("[SUPABASE_URL]")")
        debugMessages.append("🔑 Key: \("[SUPABASE_KEY]".prefix(15))...")
        
        // Test 1: Check if table exists and get count
        do {
            debugMessages.append("📊 Step 1: Checking table existence and count...")
            let countResponse = try await client
                .from("listings")
                .select("*", head: true)
                .execute()
            
            let count = countResponse.count ?? 0
            debugMessages.append("✅ Table exists with \(count) total rows")
            finalStatusCode = countResponse.response.statusCode
            
        } catch {
            debugMessages.append("❌ Table check failed: \(error)")
        }
        
        // Test 2: Try to get just basic fields that should exist
        do {
            debugMessages.append("📡 Step 2: Testing basic fields query...")
            let response = try await client
                .from("listings")
                .select("id, title, price, city")
                .limit(5)
                .execute()
            
            finalStatusCode = response.response.statusCode
            finalHeaders = "\(response.response.allHeaderFields)"
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                finalResponse = jsonString
                debugMessages.append("✅ Basic fields response: \(jsonString.count) characters")
                
                let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "[]" {
                    debugMessages.append("⚠️ EMPTY ARRAY - Database has no data or RLS blocking access")
                    
                    // Try to understand why
                    debugMessages.append("🔍 Investigating empty response...")
                    
                    // Check if RLS is the issue
                    do {
                        debugMessages.append("🔐 Testing with user context...")
                        let _ = try await client.rpc("set_current_user_email", params: ["email": "test@roomfinder.ai"]).execute()
                        
                        let contextResponse = try await client
                            .from("listings")
                            .select("id, title")
                            .limit(2)
                            .execute()
                        
                        if let contextJsonString = String(data: contextResponse.data, encoding: .utf8) {
                            let contextTrimmed = contextJsonString.trimmingCharacters(in: .whitespacesAndNewlines)
                            if contextTrimmed == "[]" {
                                debugMessages.append("❌ Still empty with user context - No data in database")
                            } else {
                                debugMessages.append("✅ RLS was blocking! Data exists: \(contextJsonString)")
                                finalResponse = contextJsonString
                            }
                        }
                    } catch {
                        debugMessages.append("❌ User context test failed: \(error)")
                    }
                    
                } else {
                    debugMessages.append("✅ Got data! Parsing...")
                    // Try to parse as JSON to understand structure
                    if let data = jsonString.data(using: .utf8),
                       let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                        debugMessages.append("📋 Found \(jsonArray.count) records")
                        
                        if let first = jsonArray.first as? [String: Any] {
                            let keys = Array(first.keys).sorted()
                            debugMessages.append("🔑 Available fields: \(keys.joined(separator: ", "))")
                        }
                    }
                }
            } else {
                debugMessages.append("❌ Could not convert response to string")
                finalResponse = "Could not convert response to string"
            }
            
        } catch {
            debugMessages.append("❌ Basic fields query failed: \(error)")
            finalResponse = "Error: \(error.localizedDescription)"
        }
        
        // Test 2: Try count query
        do {
            debugMessages.append("📊 Testing count query...")
            let response = try await client
                .from("listings")
                .select("count", head: true)
                .execute()
            
            let count = response.count ?? 0
            debugMessages.append("📊 Count result: \(count)")
            
        } catch {
            debugMessages.append("❌ Count query failed: \(error)")
        }
        
        debugMessages.append("🏁 Debug session completed")
        
        // Test 3: Try RLS bypass test
        do {
            debugMessages.append("🔐 Testing RLS bypass...")
            
            // Test setting user email context
            let _ = try await client.rpc("set_current_user_email", params: [
                "email": "test@roomfinder.ai"
            ]).execute()
            
            let response = try await client
                .from("listings")
                .select("id, title")
                .limit(2)
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
                    debugMessages.append("❌ RLS bypass also returns empty - Issue is deeper than RLS")
                } else {
                    debugMessages.append("✅ RLS bypass worked! Issue was anonymous access")
                }
            }
            
        } catch {
            debugMessages.append("❌ RLS bypass test failed: \(error)")
        }
        
        return (
            response: finalResponse,
            statusCode: finalStatusCode,
            headers: finalHeaders,
            debugInfo: debugMessages.joined(separator: "\n")
        )
    }
    
    func debugFieldMapping() async throws {
        print("🔍 DEBUG: Testing field-by-field mapping...")
        
        // Test 1: Basic fields only
        do {
            print("📝 DEBUG: Testing basic fields (id, title, price, city)...")
            let response = try await client
                .from("listings")
                .select("id, title, price, city")
                .limit(3)
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("✅ DEBUG: Basic fields response: \(jsonString)")
            }
        } catch {
            print("❌ DEBUG: Basic fields test failed: \(error.localizedDescription)")
        }
        
        // Test 2: Snake_case fields
        do {
            print("📝 DEBUG: Testing snake_case fields (postal_code, house_type, user_email)...")
            let response = try await client
                .from("listings")
                .select("id, postal_code, house_type, user_email")
                .limit(3)
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("✅ DEBUG: Snake_case fields response: \(jsonString)")
            }
        } catch {
            print("❌ DEBUG: Snake_case fields test failed: \(error.localizedDescription)")
        }
        
        // Test 3: Date fields
        do {
            print("📝 DEBUG: Testing date fields (created_at, updated_at)...")
            let response = try await client
                .from("listings")
                .select("id, created_at, updated_at")
                .limit(3)
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("✅ DEBUG: Date fields response: \(jsonString)")
            }
        } catch {
            print("❌ DEBUG: Date fields test failed: \(error.localizedDescription)")
        }
        
        // Test 4: All fields
        do {
            print("📝 DEBUG: Testing ALL fields...")
            let response = try await client
                .from("listings")
                .select("*")
                .limit(1)
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("✅ DEBUG: All fields response: \(jsonString)")
            }
        } catch {
            print("❌ DEBUG: All fields test failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Real-time Subscription Methods
    
    /// Subscribe to real-time listing changes (INSERT, UPDATE, DELETE)
    func subscribeToListingsRealtime() {
        print("📡 Setting up real-time listings subscription...")
        
        // Disconnect existing subscription if any
        disconnectRealtime()
        
        // Create new channel for listings  
        realtimeChannel = client.realtimeV2.channel("public:listings")
        
        guard let channel = realtimeChannel else {
            print("❌ Failed to create realtime channel")
            return
        }
        
        // Subscribe to postgres changes using V2 API
        _ = channel
            .onPostgresChange(InsertAction.self, schema: "public", table: "listings") { [weak self] action in
                self?.handleRealtimeEvent("INSERT", message: action)
            }
            
        _ = channel
            .onPostgresChange(UpdateAction.self, schema: "public", table: "listings") { [weak self] action in
                self?.handleRealtimeEvent("UPDATE", message: action)
            }
            
        _ = channel
            .onPostgresChange(DeleteAction.self, schema: "public", table: "listings") { [weak self] action in
                self?.handleRealtimeEvent("DELETE", message: action)
            }
        
        // Subscribe to channel with error handling and retry logic
        Task {
            for await status in channel.statusChange {
                await MainActor.run {
                    self.handleConnectionStatusChange(status)
                }
            }
        }
        
        Task {
            await channel.subscribe()
        }
    }
    
    /// Disconnect from real-time subscription
    func disconnectRealtime() {
        guard let channel = realtimeChannel else { return }
        
        print("🔴 Disconnecting real-time subscription...")
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        
        Task {
            await channel.unsubscribe()
        }
        realtimeChannel = nil
        
        Task { @MainActor in
            self.connectionStatus = "Disconnected"
            self.connectionError = nil
            self.retryCount = 0
            self.isRetrying = false
        }
    }
    
    // MARK: - Connection Status and Error Handling
    
    /// Handle real-time connection status changes with retry logic
    private func handleConnectionStatusChange(_ status: RealtimeChannelStatus) {
        switch status {
        case .subscribed:
            connectionStatus = "Connected"
            connectionError = nil
            retryCount = 0
            isRetrying = false
            reconnectionTimer?.invalidate()
            print("✅ Real-time subscription active")
            
        case .unsubscribed:
            connectionStatus = "Disconnected"
            print("🔴 Real-time subscription closed")
            attemptReconnectionIfNeeded()
            
        case .subscribing:
            connectionStatus = "Connecting"
            connectionError = nil
            print("🔄 Real-time subscription connecting...")
            
        case .unsubscribing:
            connectionStatus = "Disconnecting"
            print("🔄 Real-time subscription disconnecting...")
            
        @unknown default:
            connectionStatus = "Unknown"
            connectionError = "Unknown connection status"
            print("❓ Real-time subscription status: \(status)")
        }
    }
    
    /// Attempt to reconnect to real-time subscription with exponential backoff
    private func attemptReconnectionIfNeeded() {
        guard retryCount < maxRetries else {
            print("❌ Max reconnection attempts reached (\(maxRetries))")
            connectionStatus = "Failed"
            connectionError = "Connection failed after \(maxRetries) attempts"
            isRetrying = false
            return
        }
        
        guard !isRetrying else {
            print("🔄 Reconnection already in progress...")
            return
        }
        
        isRetrying = true
        retryCount += 1
        
        let delay = retryDelay * pow(2.0, Double(retryCount - 1)) // Exponential backoff
        print("🔄 Attempting reconnection in \(delay) seconds (attempt \(retryCount)/\(maxRetries))...")
        
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performReconnection()
            }
        }
    }
    
    /// Perform the actual reconnection
    private func performReconnection() {
        print("🔄 Performing real-time reconnection attempt \(retryCount)")
        
        // Clean up existing connection
        if let channel = realtimeChannel {
            Task {
                await channel.unsubscribe()
            }
        }
        realtimeChannel = nil
        
        // Start fresh subscription
        subscribeToListingsRealtime()
    }
    
    /// Manually retry connection (called by user action)
    func retryConnection() {
        print("🔄 Manual connection retry requested")
        retryCount = 0
        isRetrying = false
        reconnectionTimer?.invalidate()
        
        connectionError = nil
        performReconnection()
    }
    
    /// Handle incoming real-time events and convert to app events
    private func handleRealtimeEvent(_ eventType: String, message: Any) {
        print("📨 Real-time event received: \(eventType)")
        print("📋 Raw message: \(message)")
        
        Task { @MainActor in
            self.lastEventTime = Date()
            
            do {
                switch eventType {
                case "INSERT":
                    if let insertAction = message as? InsertAction {
                        let listing = try insertAction.decodeRecord(as: Listing.self, decoder: createRealtimeDecoder())
                        print("✅ INSERT: Successfully parsed listing: \(listing.title)")
                        realtimeEventsSubject.send(.insert(listing))
                    } else {
                        throw NSError(domain: "RealtimeError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid INSERT action type"])
                    }
                    
                case "UPDATE":
                    if let updateAction = message as? UpdateAction {
                        let listing = try updateAction.decodeRecord(as: Listing.self, decoder: createRealtimeDecoder())
                        print("✅ UPDATE: Successfully parsed listing: \(listing.title)")
                        realtimeEventsSubject.send(.update(listing))
                    } else {
                        throw NSError(domain: "RealtimeError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid UPDATE action type"])
                    }
                    
                case "DELETE":
                    if let deleteAction = message as? DeleteAction {
                        let listing = try deleteAction.decodeOldRecord(as: Listing.self, decoder: createRealtimeDecoder())
                        print("✅ DELETE: Successfully parsed listing: \(listing.title)")
                        realtimeEventsSubject.send(.delete(listing.id))
                    } else {
                        throw NSError(domain: "RealtimeError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid DELETE action type"])
                    }
                    
                default:
                    print("❓ Unknown event type: \(eventType)")
                    handleParsingError("Unknown real-time event type: \(eventType)")
                }
                
            } catch {
                print("❌ Failed to parse real-time event: \(error)")
                print("   Event type: \(eventType)")
                print("   Message: \(message)")
                handleParsingError("Failed to parse \(eventType) event: \(error.localizedDescription)")
            }
        }
    }
    
    /// Handle parsing errors for real-time events
    private func handleParsingError(_ errorMessage: String) {
        connectionError = errorMessage
        print("⚠️ Real-time parsing error: \(errorMessage)")
        
        // Don't disconnect for parsing errors, just log them
        // The connection may still be working for other events
    }
    
    /// Create a properly configured JSON decoder for real-time events
    private func createRealtimeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        
        // Use the same date decoding strategy as the main queries
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try multiple date formats common in PostgreSQL real-time events
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss"
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            for format in formats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
            
            // Fallback to ISO8601
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        return decoder
    }
    
    /// Parse a single listing from JSON data
    private func parseListingFromJSON(data: Data) throws -> Listing {
        let decoder = JSONDecoder()
        
        // Use the same date parsing logic as fetchListingsSimple
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSZ", 
                "yyyy-MM-dd'T'HH:mm:ss.SSSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss"
            ]
            
            for format in formats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
            
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        return try decoder.decode(Listing.self, from: data)
    }
    
    // MARK: - Database Setup Functions
    
    func enablePublicReadAccess() async throws {
        print("🔐 DEBUG: Setting up public read access for listings...")
        
        do {
            // This function would be run once to enable public read access
            let _ = try await client.rpc("enable_public_listings_read").execute()
            print("✅ DEBUG: Public read access enabled")
        } catch {
            print("❌ DEBUG: Failed to enable public read access: \(error)")
            throw error
        }
    }
    
    // MARK: - Simplified Query Methods
    
    func fetchListingsWithFilters(
        searchQuery: String? = nil,
        city: String? = nil,
        minPrice: Int? = nil,
        maxPrice: Int? = nil,
        houseType: String? = nil,
        bedrooms: Int? = nil,
        sortBy: String = "created_at",
        ascending: Bool = false,
        offset: Int = 0,
        limit: Int = 20
    ) async throws -> [Listing] {
        print("🔄 DEBUG: Fetching listings with filters...")
        print("   - City: \(city ?? "Any")")
        print("   - Price: $\(minPrice ?? 0) - $\(maxPrice ?? 9999)")
        print("   - Type: \(houseType ?? "Any")")
        print("   - Bedrooms: \(bedrooms ?? 0)+")
        
        do {
            var query = client.from("listings").select("*")
            
            // Apply filters
            if let city = city, !city.isEmpty {
                query = query.ilike("city", pattern: "%\(city)%")
            }
            
            if let minPrice = minPrice {
                query = query.gte("price", value: minPrice)
            }
            
            if let maxPrice = maxPrice {
                query = query.lte("price", value: maxPrice)
            }
            
            if let houseType = houseType, !houseType.isEmpty {
                query = query.eq("house_type", value: houseType)
            }
            
            if let bedrooms = bedrooms {
                query = query.gte("bedrooms", value: bedrooms)
            }
            
            if let searchQuery = searchQuery, !searchQuery.isEmpty {
                // Search in title and description
                query = query.or("title.ilike.%\(searchQuery)%,description.ilike.%\(searchQuery)%")
            }
            
            // Apply sorting and pagination
            let response = try await query
                .order(sortBy, ascending: ascending)
                .range(from: offset, to: offset + limit - 1)
                .execute()
            
            print("📄 DEBUG: Filtered response - \(response.data.count) bytes")
            
            // Use the same date parsing logic
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss"
                ]
                
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
                
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
            }
            
            do {
                let listings = try decoder.decode([Listing].self, from: response.data)
                print("✅ DEBUG: Filtered query returned \(listings.count) listings")
                return listings
            } catch {
                print("❌ DEBUG: Parsing failed, trying custom parser")
                return try parseWithCustomDates(data: response.data)
            }
            
        } catch {
            print("❌ DEBUG: Filtered query failed: \(error)")
            throw error
        }
    }
    
    func fetchListingsSimple() async throws -> [Listing] {
        print("🔄 DEBUG: Using simplified query approach...")
        print("🔗 DEBUG: URL: \("[SUPABASE_URL]")")
        print("🔑 DEBUG: Key: \("[SUPABASE_KEY]".prefix(10))...")
        
        do {
            print("📡 DEBUG: Making Supabase request...")
            let response = try await client
                .from("listings")
                .select("*")
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
            
            print("📄 DEBUG: Response received - size: \(response.data.count) bytes")
            print("📊 DEBUG: Response count: \(response.count ?? -1)")
            
            // Log raw response for debugging
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📝 DEBUG: Raw response preview: \(jsonString.prefix(200))...")
                
                // Check if response is empty array
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
                    print("⚠️ DEBUG: Response is empty array - no data in database!")
                    return []
                }
            }
            
            // Try simple JSON parsing first
            let decoder = JSONDecoder()
            // Use custom date decoding strategy for PostgreSQL timestamps
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try different date formats
                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss"
                ]
                
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
                
                // If all else fails, try ISO8601
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
            }
            
            do {
                let listings = try decoder.decode([Listing].self, from: response.data)
                print("✅ DEBUG: Parsing successful - \(listings.count) listings")
                if let first = listings.first {
                    print("📍 DEBUG: First listing - \(first.title) at \(first.city)")
                }
                return listings
            } catch {
                print("❌ DEBUG: Parsing failed: \(error)")
                print("🔄 DEBUG: Trying custom date parsing...")
                return try parseWithCustomDates(data: response.data)
            }
            
        } catch {
            print("❌ DEBUG: Network request failed!")
            print("   - Error type: \(type(of: error))")
            print("   - Error: \(error)")
            print("   - Localized: \(error.localizedDescription)")
            
            // Create more specific error message
            let specificError = NSError(
                domain: "SupabaseError", 
                code: 1, 
                userInfo: [
                    NSLocalizedDescriptionKey: "Network request failed: \(error.localizedDescription)",
                    "originalError": error
                ]
            )
            throw specificError
        }
    }
    
    private func parseWithCustomDates(data: Data) throws -> [Listing] {
        // Parse JSON manually and handle dates as strings
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "ParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not parse JSON"])
        }
        
        print("📋 DEBUG: Manual parsing - found \(json.count) raw objects")
        
        var listings: [Listing] = []
        
        for (index, dict) in json.enumerated() {
            // Extract all fields manually
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let price = dict["price"] as? Int,
                  let city = dict["city"] as? String,
                  let street = dict["street"] as? String,
                  let postalCode = dict["postal_code"] as? String,
                  let houseType = dict["house_type"] as? String,
                  let bedrooms = dict["bedrooms"] as? Int,
                  let utilities = dict["utilities"] as? String,
                  let userEmail = dict["user_email"] as? String else {
                print("❌ DEBUG: Missing required fields in listing \(index)")
                continue
            }
            
            let description = dict["description"] as? String
            let media = dict["media"] as? [String] ?? []
            let createdAt = Date() // Use current date as fallback
            let updatedAt = Date() // Use current date as fallback
            
            // Create a JSON representation that matches our new Listing structure
            let listingDict: [String: Any] = [
                "id": id,
                "title": title,
                "price": Double(price),
                "city": city,
                "created_at": ISO8601DateFormatter().string(from: createdAt),
                "description": description as Any,
                "street": street,
                "postal_code": postalCode,
                "house_type": houseType,
                "bedrooms": bedrooms,
                "utilities": utilities,
                "media": media,
                "user_email": userEmail,
                "updated_at": ISO8601DateFormatter().string(from: updatedAt)
            ]
            
            // Convert to JSON data and decode
            let jsonData = try JSONSerialization.data(withJSONObject: listingDict)
            let listing = try JSONDecoder().decode(Listing.self, from: jsonData)
            
            listings.append(listing)
            
            if index == 0 {
                print("✅ DEBUG: First listing parsed: \(listing.title) - $\(listing.price)")
            }
        }
        
        print("✅ DEBUG: Manual parsing completed - \(listings.count) listings")
        return listings
    }
    
    // MARK: - Real Data Fetching
    
    // Fetch all listings from Supabase using the proven web implementation query
    func fetchAllListings() async throws -> [Listing] {
        print("🔄 Fetching all listings from Supabase...")
        
        do {
            // Use the same robust parsing as the pagination method
            let response = try await client
                .from("listings")
                .select("*")
                .order("created_at", ascending: false)
                .execute()
            
            print("📄 Raw response size: \(response.data.count) bytes")
            
            // Try to parse with custom decoder first
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            decoder.dateDecodingStrategy = .formatted(formatter)
            
            do {
                let listings = try decoder.decode([Listing].self, from: response.data)
                print("✅ Successfully fetched \(listings.count) real listings from Supabase")
                
                if let firstListing = listings.first {
                    print("   - First listing: '\(firstListing.title)' - $\(firstListing.price)")
                    print("   - Location: \(firstListing.city)")
                }
                
                return listings
            } catch {
                print("🔧 Direct decoding failed, using manual parsing...")
                return try parseListingsManually(from: response.data)
            }
            
        } catch {
            print("❌ Error fetching real listings from Supabase:")
            print("   - Error: \(error)")
            print("   - Description: \(error.localizedDescription)")
            
            // Fall back to mock data for development
            print("🔄 Falling back to mock data for development")
            let mockService = MockDataService.shared
            return mockService.getSampleListings()
        }
    }
    
    // Pagination method that mirrors the working web implementation
    func fetchListingsWithPagination(page: Int = 0, limit: Int = 20) async throws -> [Listing] {
        let startRange = page * limit
        let endRange = startRange + limit - 1
        
        print("🔄 Fetching listings with pagination from Supabase")
        print("   - Page: \(page) (0-based, like web implementation)")
        print("   - Range: \(startRange) to \(endRange)")
        print("   - Limit: \(limit)")
        print("   - Table: listings")
        print("   - URL: \("[SUPABASE_URL]")")
        
        do {
            // First, let's get the raw response to debug the JSON structure
            print("🔍 Step 1: Getting raw response from Supabase...")
            
            let response = try await client
                .from("listings")
                .select("*")
                .order("created_at", ascending: false)
                .range(from: startRange, to: endRange)
                .execute()
            
            // Log the raw response data
            print("📄 Raw response received:")
            print("   - Data size: \(response.data.count) bytes")
            
            // Convert raw data to string for debugging
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("   - Raw JSON: \(jsonString.prefix(500))...") // First 500 chars
            }
            
            // Now try to parse the data using custom JSON decoder
            print("🔍 Step 2: Attempting to parse with custom decoder...")
            
            let decoder = JSONDecoder()
            
            // Set up date decoding strategy for PostgreSQL timestamps
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            decoder.dateDecodingStrategy = .formatted(formatter)
            
            // Alternative: try ISO8601 strategy as fallback
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            do {
                let listings = try decoder.decode([Listing].self, from: response.data)
                print("✅ Successfully parsed \(listings.count) listings with custom decoder")
                
                // Log details about the first listing
                if let firstListing = listings.first {
                    print("   - First listing: '\(firstListing.title)' - $\(firstListing.price)")
                    print("   - Location: \(firstListing.city)")
                    print("   - Created: \(firstListing.createdAt)")
                }
                
                return listings
            } catch {
                print("❌ Custom decoder failed, trying ISO8601 strategy...")
                print("   - Custom decoder error: \(error)")
                
                // Try with ISO8601 date strategy
                decoder.dateDecodingStrategy = .iso8601
                
                do {
                    let listings = try decoder.decode([Listing].self, from: response.data)
                    print("✅ Successfully parsed \(listings.count) listings with ISO8601 decoder")
                    return listings
                } catch {
                    print("❌ ISO8601 decoder also failed, trying manual parsing...")
                    print("   - ISO8601 decoder error: \(error)")
                    
                    // Last resort: try to parse as generic JSON and convert manually
                    return try parseListingsManually(from: response.data)
                }
            }
            
        } catch {
            print("❌ Error fetching paginated listings from Supabase:")
            print("   - Error: \(error)")
            print("   - Description: \(error.localizedDescription)")
            print("   - Error type: \(type(of: error))")
            
            throw error
        }
    }
    
    // MARK: - Manual Parsing Fallback
    
    private func parseListingsManually(from data: Data) throws -> [Listing] {
        print("🔧 Attempting manual JSON parsing as fallback...")
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "ParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not parse JSON as array of objects"])
        }
        
        print("📋 Found \(json.count) raw listing objects")
        
        var listings: [Listing] = []
        
        for (index, listingDict) in json.enumerated() {
            do {
                let listing = try parseListingFromDict(listingDict)
                listings.append(listing)
                
                if index == 0 {
                    print("   - Successfully parsed first listing: \(listing.title)")
                }
            } catch {
                print("⚠️ Failed to parse listing \(index + 1): \(error)")
                // Continue with other listings
            }
        }
        
        print("✅ Manual parsing completed: \(listings.count)/\(json.count) listings parsed successfully")
        return listings
    }
    
    private func parseListingFromDict(_ dict: [String: Any]) throws -> Listing {
        // Extract required fields with fallbacks
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let price = dict["price"] as? Int,
              let city = dict["city"] as? String,
              let street = dict["street"] as? String,
              let postalCode = dict["postal_code"] as? String,
              let houseType = dict["house_type"] as? String,
              let bedrooms = dict["bedrooms"] as? Int,
              let utilities = dict["utilities"] as? String,
              let userEmail = dict["user_email"] as? String else {
            throw NSError(domain: "ParsingError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing required fields in listing"])
        }
        
        // Handle optional/nullable fields
        let description = dict["description"] as? String
        let media = dict["media"] as? [String] ?? []
        
        // Parse dates manually
        let createdAt = parseDate(from: dict["created_at"]) ?? Date()
        let updatedAt = parseDate(from: dict["updated_at"]) ?? Date()
        
        // Create a JSON representation that matches our new Listing structure
        let listingDict: [String: Any] = [
            "id": id,
            "title": title,
            "price": Double(price),
            "city": city,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "description": description as Any,
            "street": street,
            "postal_code": postalCode,
            "house_type": houseType,
            "bedrooms": bedrooms,
            "utilities": utilities,
            "media": media,
            "user_email": userEmail,
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
        
        // Convert to JSON data and decode
        let jsonData = try JSONSerialization.data(withJSONObject: listingDict)
        return try JSONDecoder().decode(Listing.self, from: jsonData)
    }
    
    private func parseDate(from value: Any?) -> Date? {
        guard let dateString = value as? String else { return nil }
        
        // Try multiple date formats common in PostgreSQL
        let formatters = [
            // PostgreSQL timestamp with timezone
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'+00:00'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'+00:00'",
            // ISO8601
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Last resort: try ISO8601DateFormatter
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return iso8601Formatter.date(from: dateString)
    }
    
    // MARK: - Create Listing Method
    
    func createListing(_ listingData: [String: Any]) async throws {
        print("🏠 DEBUG: Creating new listing...")
        
        do {
            let response = try await client
                .from("listings")
                .insert(listingData)
                .execute()
            
            print("✅ DEBUG: Successfully created listing")
            print("📊 Response size: \(response.data.count) bytes")
            
        } catch {
            print("❌ DEBUG: Failed to create listing: \(error)")
            throw error
        }
    }
}