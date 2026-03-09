//
//  SupabaseConstants.swift
//  CapsuleAI
//

import Foundation

enum SupabaseConstants {
    static let url = "https://wuezwpyfxeqhbzwcmhsj.supabase.co"
    /// Clé publique (anon) — Dashboard Supabase > Settings > API
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1ZXp3cHlmeGVxaGJ6d2NtaHNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDU4MDYsImV4cCI6MjA4Nzg4MTgwNn0.WGuMYPTHX0Z-HuXLfUOpuuEo3Dehwspwv22XpdHlzwo"
    /// URL de redirection pour OAuth (flux navigateur) — à ajouter dans Supabase Auth > URL Configuration
    static let authRedirectURL = "capsuleai://auth/callback"
}

enum GoogleConstants {
    /// Client ID iOS — pour le flux natif (URL scheme, redirect dans l'app)
    static let clientID = "150715129732-efnstjdrvl30buhvrndfrv5f4921ukfp.apps.googleusercontent.com"
    /// Client ID Web — audience de l'idToken pour vérification Supabase
    static let serverClientID = "150715129732-na7sn7pb3l964f88ojq1k6ektbngk6ea.apps.googleusercontent.com"
    /// Reversed Client ID pour l'URL scheme (doit correspondre au client iOS)
    static let reversedClientID = "com.googleusercontent.apps.150715129732-efnstjdrvl30buhvrndfrv5f4921ukfp"
}

enum Tables {
    static let profiles = "profiles"
    static let workspaces = "workspaces"
    static let spaces = "spaces"
    static let subSpaces = "sub_spaces"
    static let notes = "notes"
    static let tags = "tags"
    static let noteTags = "note_tags"
    static let noteActions = "note_actions"
    static let attachments = "attachments"
    static let noteTypes = "note_types"
    static let noteTypeActions = "note_type_actions"
    static let collaboratorAccess = "collaborator_access"
    static let coachConversations = "coach_conversations"
    static let deviceTokens = "device_tokens"
}

enum Buckets {
    static let avatars = "avatars"
    static let attachments = "attachments"
    static let noteImages = "note-images"
}
