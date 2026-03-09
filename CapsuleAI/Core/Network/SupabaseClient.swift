//
//  SupabaseClient.swift
//  CapsuleAI
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: Supabase.SupabaseClient

    private init() {
        guard let url = URL(string: SupabaseConstants.url) else {
            fatalError("Invalid Supabase URL in SupabaseConstants")
        }
        client = Supabase.SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConstants.anonKey,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
        )
    }
}
