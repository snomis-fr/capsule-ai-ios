//
//  AIAssistService.swift
//  CapsuleAI
//

import Foundation
import Observation
import Supabase

enum AIAction: String, Encodable {
    case summarize
    case structure
    case generate
}

@Observable
final class AIAssistService {
    enum State: Equatable {
        case idle
        case loading
        case success(String)
        case error(String)
    }

    var state: State = .idle

    private let supabase = SupabaseManager.shared.client

    func assist(action: AIAction, content: String, context: String? = nil) async throws -> String {
        state = .loading
        defer { state = .idle }

        struct Request: Encodable {
            let action: String
            let content: String
            let context: String?
        }
        struct SuccessPayload: Decodable { let result: String }

        let body = Request(action: action.rawValue, content: content, context: context)

        do {
            let response: SuccessPayload = try await supabase.functions.invoke(
                "ai-assist",
                options: FunctionInvokeOptions(body: body)
            )
            state = .success(response.result)
            return response.result
        } catch {
            let msg = error.localizedDescription
            state = .error(msg)
            throw AIAssistError.apiError(msg)
        }
    }

    func reset() {
        state = .idle
    }
}

enum AIAssistError: LocalizedError {
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Réponse invalide"
        case .apiError(let msg): return msg
        }
    }
}
