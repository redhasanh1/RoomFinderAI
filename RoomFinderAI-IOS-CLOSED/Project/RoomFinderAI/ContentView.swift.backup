import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var listingsViewModel: ListingsViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        TabView {
            // Home/Search Tab
            NavigationView {
                VStack {
                    if authViewModel.isAuthenticated {
                        RoomListingsView()
                            .environmentObject(listingsViewModel)
                    } else {
                        AuthView()
                            .environmentObject(authViewModel)
                    }
                }
                .navigationTitle("Room Finder")
            }
            .tabItem {
                Image(systemName: "house")
                Text("Home")
            }
            
            // AI Chat Tab
            NavigationView {
                if authViewModel.isAuthenticated {
                    ChatView()
                        .environmentObject(chatViewModel)
                } else {
                    Text("Please sign in to use AI features")
                        .foregroundColor(.secondary)
                }
            }
            .tabItem {
                Image(systemName: "brain")
                Text("AI Assistant")
            }
            
            // Profile Tab
            NavigationView {
                ProfileView()
                    .environmentObject(authViewModel)
            }
            .tabItem {
                Image(systemName: "person")
                Text("Profile")
            }
        }
    }
}

struct RoomListingsView: View {
    @EnvironmentObject var listingsViewModel: ListingsViewModel
    
    var body: some View {
        VStack {
            Text("Room Listings")
                .font(.title2)
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
        .onAppear {
            listingsViewModel.loadListings()
        }
    }
}

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Room Finder AI")
                .font(.title)
                .multilineTextAlignment(.center)
            
            Button("Sign In") {
                authViewModel.signIn()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(ListingsViewModel())
        .environmentObject(ChatViewModel())
}