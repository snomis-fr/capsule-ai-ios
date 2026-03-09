//
//  SubSpaceNotesViewModel.swift
//  CapsuleAI
//

import Foundation
import Observation
import Supabase

struct SubSpaceNoteItem: Identifiable {
    var id: UUID { note.id }
    let note: Note
    let spaceName: String
    let spaceColor: String
    let spaceEmoji: String
    let tags: [Tag]
    let creatorProfile: Profile?
}

@Observable
final class SubSpaceNotesViewModel {
    var items: [SubSpaceNoteItem] = []
    var isLoading = false
    var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    var pinnedItems: [SubSpaceNoteItem] { items.filter(\.note.isPinned) }
    var unpinnedItems: [SubSpaceNoteItem] { items.filter { !$0.note.isPinned } }

    func load(subSpaceId: UUID, spaceName: String, spaceColor: String, spaceEmoji: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched: [Note] = try await supabase
                .from(Tables.notes)
                .select("id,workspace_id,sub_space_id,title,content_plain,ai_summary,note_type,is_private,is_pinned,word_count,location_city,location_country,location_country_code,unsplash_image_url,created_by,last_modified_by,created_at,updated_at")
                .eq("sub_space_id", value: subSpaceId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            items = await enrichNotes(fetched, spaceName: spaceName, spaceColor: spaceColor, spaceEmoji: spaceEmoji)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func enrichNotes(_ notes: [Note], spaceName: String, spaceColor: String, spaceEmoji: String) async -> [SubSpaceNoteItem] {
        guard !notes.isEmpty else { return [] }
        var profiles: [UUID: Profile] = [:]
        for uid in Set(notes.map(\.createdBy)) {
            if let p: Profile = try? await supabase.from(Tables.profiles).select().eq("id", value: uid).single().execute().value {
                profiles[uid] = p
            }
        }
        var noteTags: [UUID: [Tag]] = [:]
        struct NT: Decodable { let note_id: UUID; let tag_id: UUID }
        let ntRows: [NT] = (try? await supabase.from(Tables.noteTags).select("note_id,tag_id").in("note_id", values: notes.map(\.id)).execute().value) ?? []
        let tagIds = Set(ntRows.map(\.tag_id))
        var tagsById: [UUID: Tag] = [:]
        if !tagIds.isEmpty {
            let allTags: [Tag] = (try? await supabase.from(Tables.tags).select().in("id", values: Array(tagIds)).execute().value) ?? []
            for t in allTags { tagsById[t.id] = t }
        }
        for r in ntRows { if let tag = tagsById[r.tag_id] { noteTags[r.note_id, default: []].append(tag) } }
        return notes.map { note in
            SubSpaceNoteItem(
                note: note,
                spaceName: spaceName,
                spaceColor: spaceColor,
                spaceEmoji: spaceEmoji,
                tags: noteTags[note.id] ?? [],
                creatorProfile: profiles[note.createdBy]
            )
        }
    }

    func deleteNote(id: UUID) async throws {
        try await supabase
            .from(Tables.notes)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
