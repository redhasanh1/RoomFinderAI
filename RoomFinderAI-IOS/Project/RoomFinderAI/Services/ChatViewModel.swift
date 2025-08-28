import Foundation
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let openAIClient = OpenAIClient()
    
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
                let response = try await openAIClient.sendChatMessage(query)
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


class OpenAIClient {
    func sendChatMessage(_ message: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // TODO: Re-enable when Secrets module is properly imported
        let apiKey = "sk-proj-zFRDbomQxBfV4CCY6Zinr5pf0EW4q-hMlWaihWMhOqtSEdHhHhJ_QmWZXDTYBFGXew-K2J3yAsWT3BlbkFJiB-CxD6QNVoq90ds6e-n826FS8-PUSAZ3OQqy110UdLXDsfhB-DXp6i84lKMxr7OB2FaEei1AA"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Add required header for project keys
        if apiKey.hasPrefix("sk-proj-") {
            request.addValue("keys/v1", forHTTPHeaderField: "OpenAI-Beta")
        }
        
        let payload: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful AI assistant specialized in helping people find rooms and housing. Provide practical advice about room hunting, budgeting, and living situations."
                ],
                [
                    "role": "user", 
                    "content": message
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("OpenAI API Error (\(httpResponse.statusCode)): \(errorBody)")
            throw OpenAIError.apiError(httpResponse.statusCode, errorBody)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum OpenAIError: Error, LocalizedError {
    case invalidResponse
    case apiError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let code, let message):
            return "API Error \(code): \(message)"
        }
    }
}