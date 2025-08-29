import Foundation

final class OpenAIClient {
  static let shared = OpenAIClient(); private init() {}

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