//
//  OnboardingViewModel.swift
//  CapsuleAI
//

import Foundation
import Observation
import Supabase

@Observable
final class OnboardingViewModel {
    var companyName = ""
    var isLoading = false
    var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    func createWorkspaceAndCompleteOnboarding() async throws -> Profile {
        guard let userId = (try? await supabase.auth.session)?.user.id else {
            throw OnboardingError.notAuthenticated
        }

        let name = companyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            throw OnboardingError.emptyCompanyName
        }

        let companyFirstWord = name.components(separatedBy: .whitespaces).first ?? name
        let workspaceName = "Capsule \(name)"

        // 1. Insert workspace (display_name = premier mot du nom entreprise)
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

        struct WorkspaceIdResponse: Decodable {
            let id: UUID
        }

        let workspaceId: UUID
        do {
            let workspaceResponse: [WorkspaceIdResponse] = try await supabase
                .from(Tables.workspaces)
                .insert(WorkspaceInsert(name: workspaceName, displayName: companyFirstWord, managerId: userId))
                .select("id")
                .execute()
                .value
            guard let ws = workspaceResponse.first else {
                throw OnboardingError.createFailed("Workspace non créé")
            }
            workspaceId = ws.id
        } catch {
            throw OnboardingError.createFailed("Workspace: \(error.localizedDescription)")
        }

        // 2. Insert default space "Non classées" (is_default=true)
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

        struct SpaceIdResponse: Decodable {
            let id: UUID
        }

        let spaceId: UUID
        do {
            let spaceResponse: [SpaceIdResponse] = try await supabase
                .from(Tables.spaces)
                .insert(SpaceInsert(
                    workspaceId: workspaceId,
                    name: "Non classées",
                    emoji: "📁",
                    color: "#6B7280",
                    sortOrder: 0,
                    isDefault: true,
                    createdBy: userId,
                    isPrivate: false
                ))
                .select("id")
                .execute()
                .value
            guard let sp = spaceResponse.first else {
                throw OnboardingError.createFailed("Espace non créé")
            }
            spaceId = sp.id
        } catch {
            throw OnboardingError.createFailed("Espace: \(error.localizedDescription)")
        }

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
                SubSpaceInsert(spaceId: spaceId, name: "Général", emoji: "📄", sortOrder: 0, createdBy: userId, isTrash: false),
                SubSpaceInsert(spaceId: spaceId, name: "Poubelle", emoji: "🗑️", sortOrder: 1, createdBy: userId, isTrash: true)
            ])
            .execute()

        // 4. Insert 4 types de notes par défaut (Réunion, Projet, Problème, Stratégie)
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

        let defaultNoteTypes: [(String, String)] = [
            ("Réunion", "📅"),
            ("Projet", "📁"),
            ("Problème", "⚠️"),
            ("Stratégie", "🎯")
        ]
        for (index, (noteTypeName, emoji)) in defaultNoteTypes.enumerated() {
            try await supabase
                .from(Tables.noteTypes)
                .insert(NoteTypeInsert(
                    workspaceId: workspaceId,
                    name: noteTypeName,
                    emoji: emoji,
                    sortOrder: index
                ))
                .execute()
        }

        // 5. Update profile with workspace_id, role=manager, company
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
            .update(ProfileUpdate(workspaceId: workspaceId, role: "manager", company: name))
            .eq("id", value: userId)
            .execute()

        // 6. Return updated profile (select minimal pour éviter decode complexe)
        struct ProfileMinimal: Decodable {
            let id: UUID
            let email: String
            let workspaceId: UUID?

            enum CodingKeys: String, CodingKey {
                case id, email
                case workspaceId = "workspace_id"
            }
        }
        let profileMinimal: ProfileMinimal
        do {
            let profileResponse: [ProfileMinimal] = try await supabase
                .from(Tables.profiles)
                .select("id, workspace_id, email")
                .eq("id", value: userId)
                .execute()
                .value
            guard let pr = profileResponse.first else {
                throw OnboardingError.createFailed("Profil non trouvé")
            }
            profileMinimal = pr
        } catch {
            throw OnboardingError.createFailed("Profil: \(error.localizedDescription)")
        }

        return Profile(
            id: profileMinimal.id,
            email: profileMinimal.email,
            status: "manager",
            role: "manager",
            workspaceId: profileMinimal.workspaceId ?? workspaceId,
            company: name
        )
    }
}

enum OnboardingError: LocalizedError {
    case notAuthenticated
    case emptyCompanyName
    case createFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Session expirée. Reconnectez-vous."
        case .emptyCompanyName: return "Entrez le nom de votre entreprise."
        case .createFailed(let msg): return msg
        }
    }
}
