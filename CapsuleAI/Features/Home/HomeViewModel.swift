//
//  HomeViewModel.swift
//  CapsuleAI
//

import Foundation
import Observation
import Supabase

@Observable
final class HomeViewModel {
    var profile: Profile?
    var workspace: Workspace?
    var notes: [Note] = []
    var tags: [Tag] = []
    /// note_id -> Profile du dernier modificateur (lastModifiedBy ?? createdBy)
    private(set) var modifierProfileByNoteId: [UUID: Profile] = [:]
    /// sub_space_id -> (spaceName, spaceColor) pour afficher la pastille sur les notes
    private(set) var subSpaceToSpaceInfo: [UUID: (name: String, color: String)] = [:]
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""

    private let supabase = SupabaseManager.shared.client

    /// "Capsule [premier mot du nom entreprise]" — spec 1.2
    var displayName: String {
        // Priorité : profile.company (nom entreprise complet)
        if let company = profile?.company, !company.isEmpty {
            let first = company.components(separatedBy: .whitespaces).first ?? company
            return "Capsule \(first)"
        }
        guard let ws = workspace else { return "Capsule" }
        // Fallback : workspace.display_name (doit contenir le premier mot uniquement)
        let parts = ws.displayName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let companyFirst = (parts.first == "Capsule" && parts.count > 1) ? parts[1] : (parts.first ?? ws.displayName)
        return "Capsule \(companyFirst)"
    }

    var filteredNotes: [Note] {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return notes }
        let q = searchQuery.lowercased()
        return notes.filter {
            $0.title.lowercased().contains(q) ||
            ($0.aiSummary?.lowercased().contains(q) ?? false)
        }
    }

    func load() async {
        guard let userId = (try? await supabase.auth.session)?.user.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await loadProfile(userId: userId)
            if let wsId = profile?.workspaceId ?? workspace?.id {
                try await loadNotes(workspaceId: wsId)
                try await loadSpaceLookup(workspaceId: wsId)
                try await loadTags(workspaceId: wsId)
            }
        } catch is DecodingError {
            errorMessage = "Erreur de chargement des données"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadProfile(userId: UUID) async throws {
        let fetched: Profile = try await supabase
            .from(Tables.profiles)
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        profile = fetched
        if let wsId = fetched.workspaceId {
            let ws: Workspace = try await supabase
                .from(Tables.workspaces)
                .select()
                .eq("id", value: wsId)
                .single()
                .execute()
                .value
            workspace = ws
        }
    }

    private func loadNotes(workspaceId: UUID) async throws {
        let fetched: [Note] = try await supabase
            .from(Tables.notes)
            .select("id,workspace_id,sub_space_id,title,content_plain,ai_summary,note_type,is_private,is_pinned,word_count,location_city,location_country,location_country_code,unsplash_image_url,created_by,last_modified_by,moved_to_trash_at,created_at,updated_at")
            .eq("workspace_id", value: workspaceId)
            .is("moved_to_trash_at", value: nil as Bool?)
            .order("updated_at", ascending: false)
            .limit(AppLimits.maxNotesHome)
            .execute()
            .value
        notes = fetched
        modifierProfileByNoteId = await loadModifierProfiles(for: fetched)
    }

    private func loadModifierProfiles(for notes: [Note]) async -> [UUID: Profile] {
        guard !notes.isEmpty else { return [:] }
        let modifierIds = Set(notes.map { $0.lastModifiedBy ?? $0.createdBy })
        var profiles: [UUID: Profile] = [:]
        for uid in modifierIds {
            if let p: Profile = try? await supabase.from(Tables.profiles).select().eq("id", value: uid).single().execute().value {
                profiles[uid] = p
            }
        }
        var result: [UUID: Profile] = [:]
        for note in notes {
            let uid = note.lastModifiedBy ?? note.createdBy
            if let p = profiles[uid] {
                result[note.id] = p
            }
        }
        return result
    }

    private func loadSpaceLookup(workspaceId: UUID) async throws {
        let spaces: [Space] = try await supabase
            .from(Tables.spaces)
            .select()
            .eq("workspace_id", value: workspaceId)
            .execute()
            .value
        var lookup: [UUID: (name: String, color: String)] = [:]
        for space in spaces {
            let subs: [SubSpace] = try await supabase
                .from(Tables.subSpaces)
                .select()
                .eq("space_id", value: space.id)
                .execute()
                .value
            for sub in subs {
                lookup[sub.id] = (space.name, space.color)
            }
        }
        subSpaceToSpaceInfo = lookup
    }

    func spaceInfo(for subSpaceId: UUID) -> (name: String, color: String)? {
        subSpaceToSpaceInfo[subSpaceId]
    }

    private func loadTags(workspaceId: UUID) async throws {
        let fetched: [Tag] = try await supabase
            .from(Tables.tags)
            .select()
            .eq("workspace_id", value: workspaceId)
            .order("sort_order")
            .execute()
            .value
        tags = fetched
    }

    func createWorkspace(companyName: String) async throws {
        guard let userId = (try? await supabase.auth.session)?.user.id else {
            throw WorkspaceError.notAuthenticated
        }

        let name = companyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            throw WorkspaceError.emptyCompanyName
        }

        let displayName = name.components(separatedBy: .whitespaces).first ?? name
        let workspaceName = "Capsule \(name)"

        // 1. Insert workspace
        struct WorkspaceInsert: Encodable {
            let name: String
            let displayName: String
            let managerId: UUID

            enum CodingKeys: String, CodingKey {
                case name
                case displayName = "display_name"
                case managerId = "manager_id"
            }
        }

        let workspace: Workspace = try await supabase
            .from(Tables.workspaces)
            .insert(WorkspaceInsert(name: workspaceName, displayName: displayName, managerId: userId))
            .select()
            .single()
            .execute()
            .value

        // 2. Insert default space "Non classées"
        struct SpaceInsert: Encodable {
            let workspaceId: UUID
            let name: String
            let emoji: String
            let color: String
            let sortOrder: Int
            let isDefault: Bool
            let createdBy: UUID
            let isPrivate: Bool

            enum CodingKeys: String, CodingKey {
                case name, emoji, color
                case workspaceId = "workspace_id"
                case sortOrder = "sort_order"
                case isDefault = "is_default"
                case createdBy = "created_by"
                case isPrivate = "is_private"
            }
        }

        let space: Space = try await supabase
            .from(Tables.spaces)
            .insert(SpaceInsert(
                workspaceId: workspace.id,
                name: "Non classées",
                emoji: "📁",
                color: "#6B7280",
                sortOrder: 0,
                isDefault: true,
                createdBy: userId,
                isPrivate: false
            ))
            .select()
            .single()
            .execute()
            .value

        // 3. Insert default sub_spaces (Général + Poubelle)
        struct SubSpaceInsert: Encodable {
            let spaceId: UUID
            let name: String
            let emoji: String
            let sortOrder: Int
            let createdBy: UUID
            let isTrash: Bool?

            enum CodingKeys: String, CodingKey {
                case name, emoji
                case spaceId = "space_id"
                case sortOrder = "sort_order"
                case createdBy = "created_by"
                case isTrash = "is_trash"
            }
        }

        _ = try await supabase
            .from(Tables.subSpaces)
            .insert([
                SubSpaceInsert(spaceId: space.id, name: "Général", emoji: "📄", sortOrder: 0, createdBy: userId, isTrash: false),
                SubSpaceInsert(spaceId: space.id, name: "Poubelle", emoji: "🗑️", sortOrder: 1, createdBy: userId, isTrash: true)
            ])
            .execute()

        // 4. Insert default note types (Réunion, Projet, Problème, Stratégie)
        struct NoteTypeInsert: Encodable {
            let workspaceId: UUID
            let name: String
            let emoji: String
            let sortOrder: Int
            enum CodingKeys: String, CodingKey {
                case name, emoji
                case workspaceId = "workspace_id"
                case sortOrder = "sort_order"
            }
        }
        let defaultNoteTypes: [(String, String)] = [("Réunion", "📅"), ("Projet", "📁"), ("Problème", "⚠️"), ("Stratégie", "🎯")]
        for (idx, (noteTypeName, emoji)) in defaultNoteTypes.enumerated() {
            try await supabase.from(Tables.noteTypes).insert(NoteTypeInsert(workspaceId: workspace.id, name: noteTypeName, emoji: emoji, sortOrder: idx)).execute()
        }

        // 6. Update profile with workspace_id, role, company
        struct ProfileUpdate: Encodable {
            let workspaceId: UUID
            let role: String
            let company: String

            enum CodingKeys: String, CodingKey {
                case role, company
                case workspaceId = "workspace_id"
            }
        }
        try await supabase
            .from(Tables.profiles)
            .update(ProfileUpdate(workspaceId: workspace.id, role: "manager", company: name))
            .eq("id", value: userId)
            .execute()

        self.workspace = workspace
        try await loadProfile(userId: userId)
    }
}

enum WorkspaceError: LocalizedError {
    case notAuthenticated
    case emptyCompanyName

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Session expirée. Reconnectez-vous."
        case .emptyCompanyName: return "Entrez le nom de votre entreprise."
        }
    }
}
