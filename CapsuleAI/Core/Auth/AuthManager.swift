//
//  AuthManager.swift
//  CapsuleAI
//

import Foundation
import Supabase

@Observable
final class AuthManager {
    private let supabase = SupabaseManager.shared.client

    private(set) var currentUserId: UUID?

    func checkSession() async -> Bool {
        do {
            let session = try await supabase.auth.session
            currentUserId = session.user.id
            return true
        } catch {
            currentUserId = nil
            return false
        }
    }

    /// Connexion Google via OAuth Supabase (flux navigateur) — évite le problème nonce
    func signInWithGoogle() async throws {
        guard let redirectURL = URL(string: SupabaseConstants.authRedirectURL) else {
            throw AuthError.invalidRedirectURL
        }

        _ = try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: redirectURL
        ) { session in
            session.prefersEphemeralWebBrowserSession = false
        }

        currentUserId = (try? await supabase.auth.session)?.user.id
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUserId = nil
    }
}

enum AuthError: LocalizedError {
    case missingGoogleIdToken
    case invalidRedirectURL
    case unknown
    case supabaseError(String)

    var errorDescription: String? {
        switch self {
        case .missingGoogleIdToken:
            return "Impossible de récupérer le token Google"
        case .invalidRedirectURL:
            return "URL de redirection invalide"
        case .unknown:
            return "Erreur d'authentification"
        case .supabaseError(let msg):
            return msg
        }
    }
}
