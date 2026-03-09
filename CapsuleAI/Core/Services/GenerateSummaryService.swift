//
//  GenerateSummaryService.swift
//  CapsuleAI
//

import Foundation
import Supabase

/// Génère et enregistre le résumé IA d'une note après sauvegarde.
enum GenerateSummaryService {
    private static let supabase = SupabaseManager.shared.client

    /// Appelle la Edge Function generate-summary pour une note. S'exécute en arrière-plan.
    static func triggerForNote(id: UUID, title: String, contentPlain: String) {
        Task {
            struct Request: Encodable {
                let noteId: String
                let title: String
                let content: String
            }
            let body = Request(
                noteId: id.uuidString,
                title: title,
                content: contentPlain
            )
            _ = try? await supabase.functions.invoke(
                "generate-summary",
                options: FunctionInvokeOptions(body: body)
            )
        }
    }
}
