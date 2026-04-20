// AIProviderManager.swift
// MemoAgent — AI Provider abstraction
//
// Supports: Apple Intelligence, Claude API, Google AI Studio, OpenAI
// Unified callAI / streamAI interface routes to the active provider.

import Foundation
import Security

// MARK: - AIProvider

enum AIProvider: String, CaseIterable {
    case appleIntelligence = "Apple Intelligence"
    case claudeAPI         = "Claude API"
    case googleAI          = "Google AI Studio"
    case openAI            = "OpenAI"

    var requiresAPIKey: Bool { self != .appleIntelligence }

    var keychainAccount: String {
        switch self {
        case .appleIntelligence: return ""
        case .claudeAPI:         return "claude-api-key"
        case .googleAI:          return "google-ai-key"
        case .openAI:            return "openai-api-key"
        }
    }

    var modelName: String {
        switch self {
        case .appleIntelligence: return "On-device"
        case .claudeAPI:         return "claude-sonnet-4-6"
        case .googleAI:          return "gemini-2.0-flash"
        case .openAI:            return "gpt-4o-mini"
        }
    }

    var systemImage: String {
        switch self {
        case .appleIntelligence: return "apple.logo"
        case .claudeAPI:         return "cloud"
        case .googleAI:          return "sparkles"
        case .openAI:            return "brain.head.profile"
        }
    }

    var description: String {
        switch self {
        case .appleIntelligence: return "온디바이스 · 인터넷 불필요 · Apple Silicon + macOS 15.1 이상"
        case .claudeAPI:         return "Anthropic Claude · 뛰어난 추론 · API 키 필요"
        case .googleAI:          return "Google Gemini · 빠른 응답 · API 키 필요"
        case .openAI:            return "OpenAI GPT · 범용 · API 키 필요"
        }
    }
}

// MARK: - AIProviderError

enum AIProviderError: LocalizedError {
    case missingAPIKey(AIProvider)
    case httpError(Int, String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p):
            return "\(p.rawValue) API 키가 설정되지 않았습니다. 설정(⌘,)에서 입력해주세요."
        case .httpError(let code, let msg):
            return "API 오류 (HTTP \(code)): \(msg)"
        case .parseError:
            return "응답을 파싱할 수 없습니다."
        }
    }
}

// MARK: - Private Codable helpers

// Claude
private struct ClaudeMsg: Encodable { let role: String; let content: String }
private struct ClaudeResponse: Decodable {
    struct Block: Decodable { let text: String }
    let content: [Block]
}
private struct ClaudeSSE: Decodable {
    let type: String
    let delta: ClaudeSSEDelta?
}
private struct ClaudeSSEDelta: Decodable { let type: String?; let text: String? }

// Google AI
private struct GeminiRequest: Encodable {
    struct SystemInstruction: Encodable { let parts: [Part] }
    struct Content: Encodable { let parts: [Part] }
    struct Part: Encodable { let text: String }
    let system_instruction: SystemInstruction?
    let contents: [Content]
}
private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String }
            let parts: [Part]
        }
        let content: Content?
    }
    let candidates: [Candidate]
}

// OpenAI
private struct OpenAIRequest: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    let model: String
    let max_tokens: Int
    let messages: [Message]
    var stream: Bool = false
}
private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message?
    }
    let choices: [Choice]
}
private struct OpenAIStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}

// MARK: - AIProviderManager

final class AIProviderManager {
    static let shared = AIProviderManager()
    private init() {}

    private let defaultsKey     = "memoagent.ai.provider.v1"
    private let keychainService = "com.memoagent.app"

    // MARK: V2 — Persona context

    /// When set, this string is prepended to every system prompt.
    var activePersonaContext: String? = nil

    private func augmentedSystem(_ system: String) -> String {
        guard let ctx = activePersonaContext, !ctx.isEmpty else { return system }
        return "\(ctx)\n\n\(system)"
    }

    // MARK: Provider selection

    var selectedProvider: AIProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? ""
            return AIProvider(rawValue: raw) ?? .claudeAPI
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    // MARK: Keychain (per provider)

    func saveAPIKey(_ key: String, for provider: AIProvider) {
        guard provider.requiresAPIKey else { return }
        let account = provider.keychainAccount
        let deleteQ: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                         kSecAttrService: keychainService,
                                         kSecAttrAccount: account]
        SecItemDelete(deleteQ as CFDictionary)
        guard !key.isEmpty else { return }
        let addQ: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                      kSecAttrService: keychainService,
                                      kSecAttrAccount: account,
                                      kSecValueData: Data(key.utf8)]
        SecItemAdd(addQ as CFDictionary, nil)
    }

    func loadAPIKey(for provider: AIProvider) -> String? {
        guard provider.requiresAPIKey else { return nil }
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                       kSecAttrService: keychainService,
                                       kSecAttrAccount: provider.keychainAccount,
                                       kSecReturnData: kCFBooleanTrue!,
                                       kSecMatchLimit: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key  = String(data: data, encoding: .utf8) else { return nil }
        return key
    }

    // MARK: Unified API — non-streaming

    func callAI(system: String, userMessage: String, maxTokens: Int = 1500) async throws -> String {
        let sys = augmentedSystem(system)
        switch selectedProvider {
        case .appleIntelligence:
            fatalError("callAI must not be called for Apple Intelligence")
        case .claudeAPI:
            return try await callClaude(system: sys, userMessage: userMessage, maxTokens: maxTokens)
        case .googleAI:
            return try await callGemini(system: sys, userMessage: userMessage, maxTokens: maxTokens)
        case .openAI:
            return try await callOpenAI(system: sys, userMessage: userMessage, maxTokens: maxTokens)
        }
    }

    /// Call a specific provider regardless of selectedProvider.
    /// Used by DebateOrchestrator to route specialist agents to named providers.
    /// Apple Intelligence is not supported here — use LanguageModelSession directly.
    func callAI(provider: AIProvider, system: String, userMessage: String, maxTokens: Int = 1500) async throws -> String {
        let sys = augmentedSystem(system)
        switch provider {
        case .appleIntelligence:
            throw AIProviderError.missingAPIKey(.appleIntelligence)
        case .claudeAPI:
            return try await callClaude(system: sys, userMessage: userMessage, maxTokens: maxTokens)
        case .googleAI:
            return try await callGemini(system: sys, userMessage: userMessage, maxTokens: maxTokens)
        case .openAI:
            return try await callOpenAI(system: sys, userMessage: userMessage, maxTokens: maxTokens)
        }
    }

    // MARK: Unified API — streaming (yields accumulated text)

    func streamAI(system: String, userMessage: String, maxTokens: Int = 1024) -> AsyncThrowingStream<String, Error> {
        switch selectedProvider {
        case .appleIntelligence:
            fatalError("streamAI must not be called for Apple Intelligence")
        case .claudeAPI:
            return streamClaude(system: system, userMessage: userMessage, maxTokens: maxTokens)
        case .googleAI:
            return streamGemini(system: system, userMessage: userMessage, maxTokens: maxTokens)
        case .openAI:
            return streamOpenAI(system: system, userMessage: userMessage, maxTokens: maxTokens)
        }
    }

    // MARK: - Claude

    private func callClaude(system: String, userMessage: String, maxTokens: Int) async throws -> String {
        let apiKey = try requireKey(for: .claudeAPI)
        struct Body: Encodable {
            let model, system: String; let max_tokens: Int; let messages: [ClaudeMsg]
        }
        var req = try buildRequest(url: "https://api.anthropic.com/v1/messages",
                                   body: Body(model: AIProvider.claudeAPI.modelName,
                                              system: system, max_tokens: maxTokens,
                                              messages: [ClaudeMsg(role: "user", content: userMessage)]))
        req.setValue(apiKey,       forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: req)
        try checkHTTP(response, data)
        return try JSONDecoder().decode(ClaudeResponse.self, from: data).content.first?.text ?? ""
    }

    private func streamClaude(system: String, userMessage: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in Task {
            do {
                let apiKey = try self.requireKey(for: .claudeAPI)
                struct Body: Encodable {
                    let model, system: String; let max_tokens: Int
                    let messages: [ClaudeMsg]; let stream: Bool
                }
                var req = try self.buildRequest(
                    url: "https://api.anthropic.com/v1/messages",
                    body: Body(model: AIProvider.claudeAPI.modelName, system: system,
                               max_tokens: maxTokens, messages: [ClaudeMsg(role: "user", content: userMessage)],
                               stream: true))
                req.setValue(apiKey,       forHTTPHeaderField: "x-api-key")
                req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                var acc = ""
                for try await line in (try await URLSession.shared.bytes(for: req)).0.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let json = String(line.dropFirst(6))
                    guard json != "[DONE]",
                          let d = json.data(using: .utf8),
                          let e = try? JSONDecoder().decode(ClaudeSSE.self, from: d),
                          e.type == "content_block_delta",
                          e.delta?.type == "text_delta",
                          let t = e.delta?.text else { continue }
                    acc += t; c.yield(acc)
                }
                c.finish()
            } catch { c.finish(throwing: error) }
        }}
    }

    // MARK: - Google AI Studio (Gemini)

    private func callGemini(system: String, userMessage: String, maxTokens: Int) async throws -> String {
        let apiKey = try requireKey(for: .googleAI)
        let model  = AIProvider.googleAI.modelName
        let url    = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"

        let body = GeminiRequest(
            system_instruction: .init(parts: [.init(text: system)]),
            contents: [.init(parts: [.init(text: userMessage)])]
        )
        let req = try buildRequest(url: url, body: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try checkHTTP(response, data)
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return decoded.candidates.first?.content?.parts.first?.text ?? ""
    }

    private func streamGemini(system: String, userMessage: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in Task {
            do {
                let apiKey = try self.requireKey(for: .googleAI)
                let model  = AIProvider.googleAI.modelName
                let url    = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"
                let body   = GeminiRequest(
                    system_instruction: .init(parts: [.init(text: system)]),
                    contents: [.init(parts: [.init(text: userMessage)])]
                )
                let req = try self.buildRequest(url: url, body: body)

                var acc = ""
                for try await line in (try await URLSession.shared.bytes(for: req)).0.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let json = String(line.dropFirst(6))
                    guard json != "[DONE]",
                          let d       = json.data(using: .utf8),
                          let decoded = try? JSONDecoder().decode(GeminiResponse.self, from: d),
                          let text    = decoded.candidates.first?.content?.parts.first?.text else { continue }
                    acc += text; c.yield(acc)
                }
                c.finish()
            } catch { c.finish(throwing: error) }
        }}
    }

    // MARK: - OpenAI

    private func callOpenAI(system: String, userMessage: String, maxTokens: Int) async throws -> String {
        let apiKey = try requireKey(for: .openAI)
        var req = try buildRequest(
            url: "https://api.openai.com/v1/chat/completions",
            body: OpenAIRequest(
                model: AIProvider.openAI.modelName,
                max_tokens: maxTokens,
                messages: [.init(role: "system", content: system),
                           .init(role: "user",   content: userMessage)]
            )
        )
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        try checkHTTP(response, data)
        return try JSONDecoder().decode(OpenAIResponse.self, from: data).choices.first?.message?.content ?? ""
    }

    private func streamOpenAI(system: String, userMessage: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in Task {
            do {
                let apiKey = try self.requireKey(for: .openAI)
                var req = try self.buildRequest(
                    url: "https://api.openai.com/v1/chat/completions",
                    body: OpenAIRequest(
                        model: AIProvider.openAI.modelName,
                        max_tokens: maxTokens,
                        messages: [.init(role: "system", content: system),
                                   .init(role: "user",   content: userMessage)],
                        stream: true
                    )
                )
                req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                var acc = ""
                for try await line in (try await URLSession.shared.bytes(for: req)).0.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let json = String(line.dropFirst(6))
                    guard json != "[DONE]",
                          let d    = json.data(using: .utf8),
                          let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: d),
                          let text  = chunk.choices.first?.delta.content else { continue }
                    acc += text; c.yield(acc)
                }
                c.finish()
            } catch { c.finish(throwing: error) }
        }}
    }

    // MARK: - Helpers

    private func requireKey(for provider: AIProvider) throws -> String {
        guard let key = loadAPIKey(for: provider), !key.isEmpty else {
            throw AIProviderError.missingAPIKey(provider)
        }
        return key
    }

    private func buildRequest<T: Encodable>(url: String, body: T) throws -> URLRequest {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return req
    }

    private func checkHTTP(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode != 200 else { return }
        let msg = String(data: data, encoding: .utf8) ?? ""
        throw AIProviderError.httpError(http.statusCode, msg)
    }

    // MARK: - Connection test (used by SettingsView)

    func testConnection(for provider: AIProvider) async throws -> String {
        let prevProvider = selectedProvider
        selectedProvider = provider
        defer { selectedProvider = prevProvider }
        return try await callAI(system: "You are a helpful assistant.",
                                userMessage: "Reply with exactly the word: OK",
                                maxTokens: 10)
    }
}
