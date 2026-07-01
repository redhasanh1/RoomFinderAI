  import SwiftUI
  import Supabase

  struct ContentView: View {
      @EnvironmentObject var authViewModel: AuthViewModel
      @EnvironmentObject var listingsViewModel: ListingsViewModel
      @EnvironmentObject var chatViewModel: ChatViewModel
      @State private var selectedTab = 0
      
      private let supabase = SupabaseClient(
          supabaseURL: URL(string: Secrets.supabaseURL)!,
          supabaseKey: Secrets.supabaseAnonKey
      )
      
      var body: some View {
          TabView(selection: $selectedTab) {
              HomeView()
                  .tabItem {
                      Image(systemName: "house.fill")
                      Text("Home")
                  }
                  .tag(0)
              
              ListingsView()
                  .tabItem {
                      Image(systemName: "list.bullet")
                      Text("Listings")
                  }
                  .tag(1)
              
              AINegotiatorHub()
                  .tabItem {
                      Image(systemName: "brain.head.profile")
                      Text("AI Negotiator")
                  }
                  .tag(2)
          }
          .environment(\.supabase, supabase)
      }
  }
  
  struct HomeView: View {
      var body: some View {
          NavigationView {
              VStack {
                  Text("Welcome to RoomFinderAI")
                      .font(.largeTitle)
                      .padding()
                  
                  Text("Find your perfect room with AI assistance")
                      .font(.subheadline)
                      .foregroundColor(.secondary)
                  
                  Spacer()
              }
              .navigationTitle("Home")
          }
      }
  }
  
  struct AINegotiatorHub: View {
      @State private var messages: [AIMessage] = []
      @State private var inputText = ""
      
      var body: some View {
          NavigationView {
              VStack {
                  ScrollView {
                      LazyVStack {
                          ForEach(messages, id: \.id) { message in
                              MessageRow(message: message)
                          }
                      }
                      .padding()
                  }
                  
                  HStack {
                      TextField("Ask AI about room negotiations...", text: $inputText)
                          .textFieldStyle(RoundedBorderTextFieldStyle())
                      
                      Button("Send") {
                          sendMessage()
                      }
                      .disabled(inputText.isEmpty)
                  }
                  .padding()
              }
              .navigationTitle("AI Negotiator")
          }
      }
      
      private func sendMessage() {
          let userMessage = AIMessage(text: inputText, isFromUser: true)
          messages.append(userMessage)
          inputText = ""
          
          // Simulate AI response
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              let aiResponse = AIMessage(text: "I can help you negotiate better room deals! What specific aspect would you like assistance with?", isFromUser: false)
              messages.append(aiResponse)
          }
      }
  }
  
  struct MessageRow: View {
      let message: AIMessage
      
      var body: some View {
          HStack {
              if message.isFromUser {
                  Spacer()
                  Text(message.text)
                      .padding()
                      .background(Color.blue)
                      .foregroundColor(.white)
                      .cornerRadius(10)
              } else {
                  Text(message.text)
                      .padding()
                      .background(Color.gray.opacity(0.2))
                      .cornerRadius(10)
                  Spacer()
              }
          }
      }
  }
  
  struct AIMessage {
      let id = UUID()
      let text: String
      let isFromUser: Bool
  }
SWIFT,

# Core/Models
"RoomFinderAI-IOS/Project/RoomFinderAI/Core/Models/User.swift" => <<~SWIFT
  import Foundation

  struct User: Codable, Identifiable {
      let id: UUID
      let email: String
      let createdAt: Date
      
      enum CodingKeys: String, CodingKey {
          case id
          case email
          case createdAt = "created_at"
      }
  }
SWIFT,

"RoomFinderAI-IOS/Project/RoomFinderAI/Core/Models/Listing.swift" => <<~SWIFT
  import Foundation

  struct Listing: Codable, Identifiable {
      let id: UUID
      let title: String
      let price: Double
      let location: String
      let description: String
      let imageURL: String?
      let createdAt: Date
      
      enum CodingKeys: String, CodingKey {
          case id
          case title
          case price
          case location
          case description
          case imageURL = "image_url"
          case createdAt = "created_at"
      }
  }
SWIFT,

"RoomFinderAI-IOS/Project/RoomFinderAI/Services/Supabase/AuthViewModel.swift" => <<~SWIFT
  import Foundation
  import Supabase

  @MainActor
  class AuthViewModel: ObservableObject {
      @Published var user: User?
      @Published var isAuthenticated = false
      
      private let supabase = SupabaseClient(
          supabaseURL: URL(string: Secrets.supabaseURL)!,
          supabaseKey: Secrets.supabaseAnonKey
      )
      
      func checkAuthStatus() {
          // Check authentication status
      }
      
      func signOut() async {
          do {
              try await supabase.auth.signOut()
              self.user = nil
              self.isAuthenticated = false
          } catch {
              print("Error signing out: \(error)")
          }
      }
  }
SWIFT,

"RoomFinderAI-IOS/Project/RoomFinderAI/Features/Listings/ListingsView.swift" => <<~SWIFT
  import SwiftUI

  struct ListingsView: View {
      @EnvironmentObject var listingsViewModel: ListingsViewModel
      @State private var searchText = ""
      
      var body: some View {
          NavigationView {
              List {
                  ForEach(listingsViewModel.listings) { listing in
                      ListingRow(listing: listing)
                  }
              }
              .searchable(text: $searchText)
              .navigationTitle("Listings")
              .onAppear {
                  listingsViewModel.fetchListings()
              }
          }
      }
  }
  
  struct ListingRow: View {
      let listing: Listing
      
      var body: some View {
          VStack(alignment: .leading) {
              Text(listing.title)
                  .font(.headline)
              Text("$\(listing.price, specifier: "%.0f")/month")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              Text(listing.location)
                  .font(.caption)
                  .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)
      }
  }
SWIFT,

"RoomFinderAI-IOS/Project/RoomFinderAI/Features/Listings/ListingsViewModel.swift" => <<~SWIFT
  import Foundation
  import Supabase

  @MainActor
  class ListingsViewModel: ObservableObject {
      @Published var listings: [Listing] = []
      @Published var isLoading = false
      
      private let supabase = SupabaseClient(
          supabaseURL: URL(string: Secrets.supabaseURL)!,
          supabaseKey: Secrets.supabaseAnonKey
      )
      
      func fetchListings() {
          isLoading = true
          // Fetch listings from Supabase
          
          // Mock data for now
          listings = [
              Listing(id: UUID(), title: "Cozy Studio", price: 1200, location: "Downtown", description: "Nice studio apartment", imageURL: nil, createdAt: Date()),
              Listing(id: UUID(), title: "Spacious 1BR", price: 1800, location: "Midtown", description: "Large one bedroom", imageURL: nil, createdAt: Date())
          ]
          isLoading = false
      }
  }
SWIFT,

"RoomFinderAI-IOS/Project/RoomFinderAI/Features/Chat/ChatViewModel.swift" => <<~SWIFT
  import Foundation

  @MainActor
  class ChatViewModel: ObservableObject {
      @Published var messages: [ChatMessage] = []
      @Published var isLoading = false
      
      func sendMessage(_ text: String) {
          let message = ChatMessage(text: text, isFromUser: true, timestamp: Date())
          messages.append(message)
          
          // Simulate response
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              let response = ChatMessage(text: "Thanks for your message!", isFromUser: false, timestamp: Date())
              self.messages.append(response)
          }
      }
  }
  
  struct ChatMessage: Identifiable {
      let id = UUID()
      let text: String
      let isFromUser: Bool
      let timestamp: Date
  }
