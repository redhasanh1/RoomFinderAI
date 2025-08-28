import Foundation

final class OpenAIClient {
  static let shared = OpenAIClient()
  private init() {}

  private var isProjectKey: Bool {
    Secrets.openAIKey.hasPrefix("sk-proj-")
  }

  func health() async -> String {
    do {
      let response = try await textChat(system: "Health check", user: "Respond with 'OK'")
      return "OpenAI: \(response.prefix(10))"
    } catch {
      return "OpenAI Error: \(error.localizedDescription)"
    }
  }

  func textChat(system: String, user: String) async throws -> String {
    let messages = [
      ["role": "system", "content": system],
      ["role": "user", "content": user]
    ]
    
    let body: [String: Any] = [
      "model": Secrets.openAIModel,
      "messages": messages,
      "max_tokens": 300,
      "temperature": 0.7
    ]
    
    let data = try await request(body)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    
    guard let choices = json?["choices"] as? [[String: Any]],
          let firstChoice = choices.first,
          let message = firstChoice["message"] as? [String: Any],
          let content = message["content"] as? String else {
      throw OpenAIError.invalidResponse
    }
    
    return content.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func request(_ body: [String: Any]) async throws -> Data {
    guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
      throw OpenAIError.invalidURL
    }
    
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    req.addValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
    
    // Project keys need special OpenAI-Beta header  
    if isProjectKey {
      req.addValue("keys/v1", forHTTPHeaderField: "OpenAI-Beta")
    }
    
    // Only add org header if NOT using project key and org is set
    if !isProjectKey, let org = Secrets.openAIOrgID, !org.isEmpty {
      req.addValue(org, forHTTPHeaderField: "OpenAI-Organization")
    }
    
    req.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, response) = try await URLSession.shared.data(for: req)
    
    guard let httpResponse = response as? HTTPURLResponse else {
      throw OpenAIError.networkError
    }
    
    if httpResponse.statusCode != 200 {
      let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
      print("❌ OpenAI API Error (\(httpResponse.statusCode)): \(errorString)")
      throw OpenAIError.apiError(httpResponse.statusCode, errorString)
    }
    
    return data
  }
}

enum OpenAIError: Error {
  case invalidURL
  case invalidResponse
  case networkError
  case apiError(Int, String)
  
  var localizedDescription: String {
    switch self {
    case .invalidURL:
      return "Invalid URL"
    case .invalidResponse:
      return "Invalid response format"
    case .networkError:
      return "Network error"
    case .apiError(let code, let message):
      return "API Error \(code): \(message)"
    }
  }
}