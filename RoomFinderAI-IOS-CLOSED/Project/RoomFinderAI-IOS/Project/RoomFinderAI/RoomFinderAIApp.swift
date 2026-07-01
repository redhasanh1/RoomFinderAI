import SwiftUI
import Supabase

@main
struct RoomFinderAIApp: App {
    let supabaseClient: SupabaseClient = {
        let url = URL(string: Secrets.supabaseURL)!
        return SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
    }()
    
    init() {
        // Runtime startup log to confirm correct OpenAI key is loaded
        print("🔐 OpenAI key loaded: \(Secrets.openAIKey.hasPrefix("sk-proj-") ? "project key" : "classic key") (\(Secrets.openAIModel))")
        Secrets.assertValid()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.supabase, supabaseClient)
        }
    }
}

struct ContentView: View {
    @State private var showingDebug = false
    @State private var searchText = ""
    
    var body: some View {
        TabView {
            // Test Tab 1
            Text("HOME TAB - You should see 5 tabs at bottom!")
                .font(.title)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            // Test Tab 2
            Text("AI CHATS TAB")
                .font(.title)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Chats")
                }
            
            // Test Tab 3
            Text("ADD TAB")
                .font(.title)
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
            
            // Test Tab 4
            Text("DASHBOARD TAB")
                .font(.title)
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Dashboard")
                }
            
            // Test Tab 5
            Text("SETTINGS TAB")
                .font(.title)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .sheet(isPresented: $showingDebug) {
            DebugInfoView()
        }
    }
}

struct RoomListView: View {
    @Environment(\.supabase) private var supabase
    @State private var rooms: [Room] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingAddRoom = false
    @Binding var searchText: String
    
    var filteredRooms: [Room] {
        if searchText.isEmpty {
            return rooms
        } else {
            return rooms.filter { room in
                room.title.lowercased().contains(searchText.lowercased()) ||
                room.location.lowercased().contains(searchText.lowercased()) ||
                room.description.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading rooms...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredRooms.isEmpty && !searchText.isEmpty {
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No rooms found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Try adjusting your search terms")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredRooms.isEmpty {
                VStack {
                    Image(systemName: "house.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No rooms available")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Be the first to add a room")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredRooms) { room in
                        NavigationLink(destination: RoomDetailView(room: room)) {
                            RoomRowView(room: room)
                        }
                    }
                }
            }
            
            if let error = error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddRoom = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoom) {
                AddRoomView()
            }
            .task {
                await loadRooms()
            }
            .refreshable {
                await loadRooms()
            }
        }
    }
    
    private func loadRooms() async {
        isLoading = true
        error = nil
        
        do {
            let response: [Room] = try await supabase
                .from("rooms")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.rooms = response
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct RoomRowView: View {
    let room: Room
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(room.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("$\(room.price, specifier: "%.0f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            HStack {
                Image(systemName: "location")
                    .foregroundColor(.secondary)
                Text(room.location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(room.bedrooms) bed • \(room.bathrooms) bath")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(room.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if room.availableFrom > Date() {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.orange)
                    Text("Available from \(room.availableFrom, style: .date)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Available now")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RoomDetailView: View {
    let room: Room
    @State private var showingNegotiator = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: URL(string: room.imageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                        }
                }
                .frame(height: 250)
                .clipped()
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(room.title)
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(room.price, specifier: "%.0f")/month")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                        Text(room.location)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack {
                        VStack {
                            Text("\(room.bedrooms)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Bedrooms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack {
                            Text("\(room.bathrooms)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Bathrooms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack {
                            Text("\(Int(room.squareFeet))")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Sq Ft")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(room.description)
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amenities")
                            .font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(room.amenities, id: \.self) { amenity in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(amenity)
                                        .font(.body)
                                    Spacer()
                                }
                            }
                        }
                    }
                    
                    if room.availableFrom > Date() {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.orange)
                            Text("Available from \(room.availableFrom, style: .date)")
                                .font(.body)
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Negotiate") {
                    showingNegotiator = true
                }
                .foregroundColor(.blue)
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingNegotiator) {
            AINegotiatorView(room: room)
        }
    }
}

struct AddRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.supabase) private var supabase
    
    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var price: Double = 1000
    @State private var bedrooms: Int = 1
    @State private var bathrooms: Int = 1
    @State private var squareFeet: Double = 500
    @State private var imageURL = ""
    @State private var availableFrom = Date()
    @State private var selectedAmenities: Set<String> = []
    
    @State private var isSubmitting = false
    @State private var error: String?
    
    let availableAmenities = [
        "Wi-Fi", "Air Conditioning", "Heating", "Parking", "Laundry",
        "Pet Friendly", "Furnished", "Gym", "Pool", "Balcony",
        "Dishwasher", "Microwave", "Refrigerator", "Storage"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Room Title", text: $title)
                    TextField("Location", text: $location)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Details") {
                    HStack {
                        Text("Price per month")
                        Spacer()
                        TextField("Price", value: $price, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Stepper("Bedrooms: \(bedrooms)", value: $bedrooms, in: 1...10)
                    Stepper("Bathrooms: \(bathrooms)", value: $bathrooms, in: 1...10)
                    
                    HStack {
                        Text("Square Feet")
                        Spacer()
                        TextField("Sq Ft", value: $squareFeet, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("Available From", selection: $availableFrom, displayedComponents: .date)
                }
                
                Section("Image") {
                    TextField("Image URL (optional)", text: $imageURL)
                }
                
                Section("Amenities") {
                    ForEach(availableAmenities, id: \.self) { amenity in
                        HStack {
                            Button(action: {
                                if selectedAmenities.contains(amenity) {
                                    selectedAmenities.remove(amenity)
                                } else {
                                    selectedAmenities.insert(amenity)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedAmenities.contains(amenity) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedAmenities.contains(amenity) ? .blue : .gray)
                                    Text(amenity)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                
                if let error = error {
                    Section {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await submitRoom()
                        }
                    }
                    .disabled(title.isEmpty || location.isEmpty || description.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func submitRoom() async {
        isSubmitting = true
        error = nil
        
        let newRoom = Room(
            id: UUID(),
            title: title,
            description: description,
            price: price,
            location: location,
            bedrooms: bedrooms,
            bathrooms: bathrooms,
            squareFeet: squareFeet,
            imageURL: imageURL.isEmpty ? nil : imageURL,
            amenities: Array(selectedAmenities),
            availableFrom: availableFrom,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            try await supabase
                .from("rooms")
                .insert(newRoom)
                .execute()
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isSubmitting = false
            }
        }
    }
}

struct Room: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let price: Double
    let location: String
    let bedrooms: Int
    let bathrooms: Int
    let squareFeet: Double
    let imageURL: String?
    let amenities: [String]
    let availableFrom: Date
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, location, bedrooms, bathrooms, amenities
        case squareFeet = "square_feet"
        case imageURL = "image_url"
        case availableFrom = "available_from"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - AI Negotiator Components

struct AINegotiatorHub: View {
    @State private var sessions: [NegotiationSession] = []
    @State private var showingNewNegotiation = false
    @Environment(\.supabase) private var supabase
    
    var body: some View {
        NavigationView {
            VStack {
                if sessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("AI Negotiator")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Start negotiating room prices with our AI assistant")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Start New Negotiation") {
                            showingNewNegotiation = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink(destination: AINegotiatorView(session: session)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.roomTitle)
                                        .font(.headline)
                                    Text("Last offer: $\(session.currentOffer, specifier: "%.0f")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("AI Negotiator")
            .toolbar {
                if !sessions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("New") {
                            showingNewNegotiation = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewNegotiation) {
                RoomSelectionView { room in
                    let newSession = NegotiationSession(
                        id: UUID(),
                        room: room,
                        messages: [],
                        currentOffer: room.price,
                        status: .active,
                        createdAt: Date()
                    )
                    sessions.append(newSession)
                    showingNewNegotiation = false
                }
            }
        }
    }
}

struct RoomSelectionView: View {
    @Environment(\.supabase) private var supabase
    @Environment(\.dismiss) private var dismiss
    @State private var rooms: [Room] = []
    @State private var isLoading = false
    let onRoomSelected: (Room) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading rooms...")
                } else if rooms.isEmpty {
                    Text("No rooms available")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(rooms) { room in
                            Button(action: {
                                onRoomSelected(room)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(room.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(room.location)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("$\(room.price, specifier: "%.0f")")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadRooms()
            }
        }
    }
    
    private func loadRooms() async {
        isLoading = true
        
        do {
            let response: [Room] = try await supabase
                .from("rooms")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.rooms = response
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct AINegotiatorView: View {
    let room: Room?
    @State private var session: NegotiationSession
    @State private var messageText = ""
    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss
    
    init(room: Room) {
        self.room = room
        self._session = State(initialValue: NegotiationSession(
            id: UUID(),
            room: room,
            messages: [],
            currentOffer: room.price,
            status: .active,
            createdAt: Date()
        ))
    }
    
    init(session: NegotiationSession) {
        self.room = nil
        self._session = State(initialValue: session)
    }
    
    var body: some View {
        VStack {
            // Room header
            HStack {
                VStack(alignment: .leading) {
                    Text(session.roomTitle)
                        .font(.headline)
                    Text("Current offer: $\(session.currentOffer, specifier: "%.0f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if session.messages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                Text("Start negotiating!")
                                    .font(.headline)
                                Text("I'm here to help you negotiate the best price for this room.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(session.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if isProcessing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("AI is thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading)
                        }
                    }
                    .padding()
                }
                .onChange(of: session.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(session.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            // Input
            HStack {
                TextField("Type your message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                
                Button("Send") {
                    Task {
                        await sendMessage()
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
            .padding()
        }
        .navigationTitle("Negotiation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            if session.messages.isEmpty {
                await sendInitialMessage()
            }
        }
    }
    
    private func sendInitialMessage() async {
        isProcessing = true
        
        let aiMessage = NegotiationMessage(
            id: UUID(),
            content: "Hello! I'm here to help you negotiate the price for \(session.roomTitle). The asking price is $\(session.room.price, specifier: "%.0f"). What would you like to offer?",
            isFromUser: false,
            timestamp: Date(),
            offer: nil
        )
        
        session.messages.append(aiMessage)
        isProcessing = false
    }
    
    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMessage = NegotiationMessage(
            id: UUID(),
            content: text,
            isFromUser: true,
            timestamp: Date(),
            offer: nil
        )
        
        session.messages.append(userMessage)
        messageText = ""
        isProcessing = true
        
        do {
            let response = try await OpenAIClient.shared.textChat(
                system: """
                You are a helpful AI negotiation assistant helping users negotiate room rental prices. 
                Current room: \(session.roomTitle)
                Asking price: $\(session.room.price)
                Current offer in negotiation: $\(session.currentOffer)
                
                Rules:
                1. Be helpful and professional
                2. Help the user make reasonable offers
                3. Explain negotiation strategies
                4. If user mentions a specific price, acknowledge it as their offer
                5. Keep responses concise and conversational
                6. Don't make offers on behalf of the landlord
                """,
                user: text
            )
            
            let aiMessage = NegotiationMessage(
                id: UUID(),
                content: response,
                isFromUser: false,
                timestamp: Date(),
                offer: nil
            )
            
            await MainActor.run {
                session.messages.append(aiMessage)
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                let errorMessage = NegotiationMessage(
                    id: UUID(),
                    content: "Sorry, I encountered an error: \(error.localizedDescription)",
                    isFromUser: false,
                    timestamp: Date(),
                    offer: nil
                )
                session.messages.append(errorMessage)
                isProcessing = false
            }
        }
    }
}

struct MessageBubble: View {
    let message: NegotiationMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isFromUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(12)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
}

struct NegotiationSession: Identifiable {
    let id: UUID
    let room: Room
    var messages: [NegotiationMessage]
    var currentOffer: Double
    var status: NegotiationStatus
    let createdAt: Date
    
    var roomTitle: String { room.title }
}

struct NegotiationMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let offer: Double?
}

enum NegotiationStatus {
    case active, completed, cancelled
}

// MARK: - OpenAI Client

final class OpenAIClient {
    static let shared = OpenAIClient()
    private init() {}
    
    private var isProjectKey: Bool { Secrets.openAIKey.hasPrefix("sk-proj-") }
    
    private func request(_ body: [String:Any]) async throws -> Data {
        Secrets.assertValid()
        
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
        req.addValue("keys/v1", forHTTPHeaderField: "OpenAI-Beta") // required for project keys routing
        
        // ✅ Only attach org for classic keys (NOT for sk-proj)
        if !isProjectKey, let org = Secrets.openAIOrgID, !org.isEmpty {
            req.addValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let txt = String(data: data, encoding: .utf8) ?? ""
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let hint = (code == 401)
                ? "401 Unauthorized: with sk-proj keys the org header must be omitted and the key must be valid/fresh."
                : "OpenAI HTTP \(code)"
            throw NSError(domain: "OpenAI", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "\(hint)\n\(txt)"])
        }
        return data
    }
    
    func textChat(model: String = Secrets.openAIModel, system: String, user: String) async throws -> String {
        let body: [String:Any] = [
            "model": model,
            "messages": [
                ["role":"system","content":system],
                ["role":"user","content":user]
            ],
            "temperature": 0.3
        ]
        struct R: Decodable { struct C: Decodable { struct M: Decodable { let content: String }; let message: M }; let choices: [C] }
        let data = try await request(body)
        return try JSONDecoder().decode(R.self, from: data).choices.first?.message.content ?? ""
    }
    
    func jsonChat<T:Decodable>(model: String = Secrets.openAIModel, system: String, user: String, schema: T.Type) async throws -> T {
        let body: [String:Any] = [
            "model": model,
            "response_format": ["type":"json_object"],
            "messages": [
                ["role":"system","content":system],
                ["role":"user","content":user]
            ],
            "temperature": 0.2
        ]
        struct R: Decodable { struct C: Decodable { struct M: Decodable { let content: String }; let message: M }; let choices: [C] }
        let data = try await request(body)
        let wrap = try JSONDecoder().decode(R.self, from: data)
        let json = wrap.choices.first?.message.content ?? "{}"
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
    
    // In-app self-test for the ⓘ screen
    func health() async -> String {
        do { _ = try await textChat(system: "Reply 'pong'.", user: "ping"); return "OpenAI: OK (\(Secrets.openAIModel))" }
        catch { return "OpenAI: \(error.localizedDescription)" }
    }
}

// MARK: - Debug Info View

struct DebugInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var status = "Checking..."
    
    var body: some View {
        NavigationView {
            List {
                Section("OpenAI Configuration") {
                    Text("Key type: \(Secrets.openAIKey.hasPrefix("sk-proj-") ? "project" : "classic")")
                    Text("Model: \(Secrets.openAIModel)")
                    Text("Org ID: \(Secrets.openAIOrgID ?? "nil")")
                }
                
                Section("Health Check") {
                    Text(status)
                        .foregroundColor(status.contains("OK") ? .green : .red)
                }
            }
            .navigationTitle("Debug Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                status = await OpenAIClient.shared.health()
            }
        }
    }
}

// MARK: - New Tab Views

struct AIChatsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("AI Chats")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Chat history and AI conversations will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Start New Chat") {
                // Will implement later
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("AI Chats")
    }
}

struct PostView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "plus.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Post a Room")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Create a new room listing")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create Listing") {
                // Will implement later - should show AddRoomView
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Post")
    }
}

struct DashboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Dashboard")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your activity, stats, and recent listings will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("Dashboard")
    }
}

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Settings")
                .font(.title)
                .fontWeight(.bold)
            
            Text("App preferences and account settings will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("Settings")
    }
}