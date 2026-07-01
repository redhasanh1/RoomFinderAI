import Foundation
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let openAIClient = OpenAIClient.shared
    
    init() {
        addWelcomeMessage()
    }
    
    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(content: currentInput, isUser: true)
        messages.append(userMessage)
        
        let query = currentInput
        currentInput = ""
        isLoading = true
        errorMessage = nil
        
        // Call OpenAI API
        Task {
            do {
                let response = try await openAIClient.textChat(system: "You are a helpful AI Room Finder assistant. Help users find rooms based on their preferences.", user: query)
                await MainActor.run {
                    let aiMessage = ChatMessage(content: response, isUser: false)
                    self.messages.append(aiMessage)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to get AI response: \(error.localizedDescription)"
                    self.isLoading = false
                    print("OpenAI error: \(error)")
                }
            }
        }
    }
    
    func clearChat() {
        messages.removeAll()
        addWelcomeMessage()
        errorMessage = nil
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: "Hello! I'm your AI Room Finder assistant. I can help you find the perfect room based on your preferences, budget, and location needs. What are you looking for?",
            isUser: false
        )
        messages.append(welcomeMessage)
    }
}

