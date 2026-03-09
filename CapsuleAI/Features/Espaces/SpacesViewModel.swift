//
//  SpacesViewModel.swift
//  CapsuleAI
//

import Foundation
import Observation
import Supabase

@Observable
final class SpacesViewModel {
    var spaces: [Space] = []
    var subSpacesBySpace: [UUID: [SubSpace]] = [:]
    var noteCountBySpace: [UUID: Int] = [:]
    var noteCountBySubSpace: [UUID: Int] = [:]
    /// Sous-espaces partagés avec au moins un collaborateur (ceux absents = privés)
    private(set) var sharedSubSpaceIds: Set<UUID> = []
    var isLoading = false
    var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    var totalSpacesCount: Int { spaces.count }
    var totalNotesCount: Int { noteCountBySpace.values.reduce(0, +) }

    /// Non classé toujours en dernier (règle immuable)
    var orderedSpaces: [Space] {
        spaces.sortedWithDefaultLast()
    }

    func load(workspaceId: UUID?, userId: UUID?) async {
        guard let wsId = workspaceId, let _ = userId else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched: [Space] = try await supabase
                .from(Tables.spaces)
                .select()
                .eq("workspace_id", value: wsId)
                .order("sort_order")
                .execute()
                .value

            spaces = fetched
            subSpacesBySpace = [:]
            noteCountBySpace = [:]
            noteCountBySubSpace = [:]
            sharedSubSpaceIds = []

            struct SubSpaceIdRow: Decodable { let sub_space_id: UUID }
            let accessRows: [SubSpaceIdRow] = (try? await supabase
                .from(Tables.collaboratorAccess)
                .select("sub_space_id")
                .eq("workspace_id", value: wsId)
                .execute()
                .value) ?? []
            sharedSubSpaceIds = Set(accessRows.map(\.sub_space_id))

            for space in spaces {
                let subs: [SubSpace] = try await supabase
                    .from(Tables.subSpaces)
                    .select()
                    .eq("space_id", value: space.id)
                    .order("sort_order")
                    .execute()
                    .value
                subSpacesBySpace[space.id] = subs

                var spaceNoteCount = 0
                for sub in subs {
                    struct IdRow: Decodable { let id: UUID }
                    let rows: [IdRow] = try await supabase
                        .from(Tables.notes)
                        .select("id")
                        .eq("sub_space_id", value: sub.id)
                        .execute()
                        .value
                    let count = rows.count
                    noteCountBySubSpace[sub.id] = count
                    spaceNoteCount += count
                }
                noteCountBySpace[space.id] = spaceNoteCount
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createSubSpace(spaceId: UUID, name: String, emoji: String, createdBy: UUID) async throws {
        struct Insert: Encodable {
            let spaceId: UUID
            let name: String
            let emoji: String
            let sortOrder: Int
            let createdBy: UUID

            enum CodingKeys: String, CodingKey {
                case name, emoji
                case spaceId = "space_id"
                case sortOrder = "sort_order"
                case createdBy = "created_by"
            }
        }
        let subs = subSpacesBySpace[spaceId] ?? []
        let nextOrder = (subs.map(\.sortOrder).max() ?? -1) + 1

        try await supabase
            .from(Tables.subSpaces)
            .insert(Insert(spaceId: spaceId, name: name, emoji: emoji, sortOrder: nextOrder, createdBy: createdBy))
            .execute()
    }

    func updateSubSpace(id: UUID, name: String, emoji: String) async throws {
        struct Update: Encodable {
            let name: String
            let emoji: String
        }
        try await supabase
            .from(Tables.subSpaces)
            .update(Update(name: name, emoji: emoji))
            .eq("id", value: id)
            .execute()
    }

    func deleteSubSpace(id: UUID) async throws {
        try await supabase
            .from(Tables.subSpaces)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func updateSpaceName(_ space: Space, name: String) async throws {
        struct NameUpdate: Encodable { let name: String }
        try await supabase.from(Tables.spaces).update(NameUpdate(name: name)).eq("id", value: space.id).execute()
        if let idx = spaces.firstIndex(where: { $0.id == space.id }) {
            spaces[idx].name = name
        }
    }

    func updateSpaceColor(_ space: Space, color: String) async throws {
        struct ColorUpdate: Encodable { let color: String }
        try await supabase.from(Tables.spaces).update(ColorUpdate(color: color)).eq("id", value: space.id).execute()
        if let idx = spaces.firstIndex(where: { $0.id == space.id }) {
            spaces[idx].color = color
        }
    }

    func canDeleteSpace(_ space: Space) -> Bool {
        !space.isDefault && (subSpacesBySpace[space.id] ?? []).isEmpty
    }

    func canDeleteSubSpace(_ subSpace: SubSpace, space: Space) -> Bool {
        !space.isDefault
    }
}
