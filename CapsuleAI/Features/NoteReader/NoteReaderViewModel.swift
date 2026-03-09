//
//  NoteReaderViewModel.swift
//  CapsuleAI
//

import Foundation
import Observation
import Supabase

@Observable
final class NoteReaderViewModel {
    var note: Note?
    var space: Space?
    var subSpace: SubSpace?
    var tags: [Tag] = []
    var actions: [NoteAction] = []
    var attachments: [Attachment] = []
    var modifierProfile: Profile?
    var isLoading = false
    var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    func load(noteId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let row: NoteReaderRow = try await supabase.from(Tables.notes)
                .select("id,workspace_id,sub_space_id,title,content,content_plain,ai_summary,note_type,is_private,is_pinned,word_count,created_by,last_modified_by,created_at,updated_at")
                .eq("id", value: noteId)
                .single()
                .execute()
                .value
            note = row.toNote()
            let subs: [SubSpace] = try await supabase.from(Tables.subSpaces).select().eq("id", value: row.subSpaceId).execute().value
            subSpace = subs.first
            if let ss = subSpace {
                let sps: [Space] = try await supabase.from(Tables.spaces).select().eq("id", value: ss.spaceId).execute().value
                space = sps.first
            }
            let tagRows: [NoteTagRow] = try await supabase.from(Tables.noteTags).select("tag_id").eq("note_id", value: noteId).execute().value
            if !tagRows.isEmpty {
                let ids = tagRows.map(\.tagId)
                let allTags: [Tag] = try await supabase.from(Tables.tags).select().in("id", values: ids).execute().value
                tags = ids.compactMap { id in allTags.first { $0.id == id } }
            }
            actions = try await supabase.from(Tables.noteActions).select().eq("note_id", value: noteId).order("sort_order").execute().value
            attachments = try await supabase.from(Tables.attachments).select().eq("note_id", value: noteId).execute().value
            if let modId = row.lastModifiedBy {
                modifierProfile = try? await supabase.from(Tables.profiles).select().eq("id", value: modId).single().execute().value
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Met à jour le résumé IA de la note (visible sur la carte accueil et en vue lecture).
    func updateAiSummary(noteId: UUID, summary: String) async throws {
        struct AiSummaryUpdate: Encodable {
            let aiSummary: String
            enum CodingKeys: String, CodingKey { case aiSummary = "ai_summary" }
        }
        try await supabase.from(Tables.notes)
            .update(AiSummaryUpdate(aiSummary: summary.isEmpty ? "" : summary))
            .eq("id", value: noteId)
            .execute()
    }

    func deleteNote(noteId: UUID, workspaceId: UUID) async throws {
        guard let trashSubSpaceId = try await fetchTrashSubSpaceId(workspaceId: workspaceId) else {
            throw NSError(domain: "NoteReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Poubelle introuvable"])
        }
        struct MoveToTrash: Encodable {
            let subSpaceId: UUID
            let movedToTrashAt: Date
            enum CodingKeys: String, CodingKey {
                case subSpaceId = "sub_space_id"
                case movedToTrashAt = "moved_to_trash_at"
            }
        }
        try await supabase
            .from(Tables.notes)
            .update(MoveToTrash(subSpaceId: trashSubSpaceId, movedToTrashAt: Date()))
            .eq("id", value: noteId)
            .execute()
    }

    private func fetchTrashSubSpaceId(workspaceId: UUID) async throws -> UUID? {
        struct SpaceIdRow: Decodable { let id: UUID }
        let spaces: [SpaceIdRow] = try await supabase
            .from(Tables.spaces)
            .select("id")
            .eq("workspace_id", value: workspaceId)
            .eq("is_default", value: true)
            .execute()
            .value
        guard let defaultSpaceId = spaces.first?.id else { return nil }
        struct SubSpaceIdRow: Decodable { let id: UUID }
        let subs: [SubSpaceIdRow] = try await supabase
            .from(Tables.subSpaces)
            .select("id")
            .eq("space_id", value: defaultSpaceId)
            .eq("is_trash", value: true)
            .execute()
            .value
        return subs.first?.id
    }

    func restoreNote(noteId: UUID, targetSubSpaceId: UUID) async throws {
        struct RestoreUpdate: Encodable {
            let subSpaceId: UUID
            let movedToTrashAt: Date?
            enum CodingKeys: String, CodingKey {
                case subSpaceId = "sub_space_id"
                case movedToTrashAt = "moved_to_trash_at"
            }
        }
        try await supabase
            .from(Tables.notes)
            .update(RestoreUpdate(subSpaceId: targetSubSpaceId, movedToTrashAt: nil))
            .eq("id", value: noteId)
            .execute()
    }

    func deleteNotePermanently(noteId: UUID) async throws {
        try await supabase
            .from(Tables.notes)
            .delete()
            .eq("id", value: noteId)
            .execute()
    }

    func loadRestoreDestinations(workspaceId: UUID) async throws -> [(Space, SubSpace)] {
        let fetched: [Space] = try await supabase
            .from(Tables.spaces)
            .select()
            .eq("workspace_id", value: workspaceId)
            .order("sort_order")
            .execute()
            .value
        let spaces = fetched.sortedWithDefaultLast()
        var result: [(Space, SubSpace)] = []
        for space in spaces {
            let subs: [SubSpace] = try await supabase
                .from(Tables.subSpaces)
                .select()
                .eq("space_id", value: space.id)
                .order("sort_order")
                .execute()
                .value
            for sub in subs where !sub.isTrash {
                result.append((space, sub))
            }
        }
        return result
    }

    func toggleAction(id: UUID, isChecked: Bool, userId: UUID) async {
        struct Update: Encodable {
            let isChecked: Bool
            let checkedBy: UUID?
            let checkedAt: Date?

            enum CodingKeys: String, CodingKey {
                case isChecked = "is_checked"
                case checkedBy = "checked_by"
                case checkedAt = "checked_at"
            }
        }
        do {
            try await supabase.from(Tables.noteActions)
                .update(Update(isChecked: isChecked, checkedBy: userId, checkedAt: isChecked ? Date() : nil))
                .eq("id", value: id)
                .execute()
            await load(noteId: note!.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct NoteTagRow: Decodable {
    let tagId: UUID
    enum CodingKeys: String, CodingKey { case tagId = "tag_id" }
}

/// Struct pour charger une note en lecture : gère champs optionnels et JSONB content
private struct NoteReaderRow: Decodable {
    let id: UUID
    let workspaceId: UUID
    let subSpaceId: UUID
    let title: String
    let contentData: Data?
    let contentPlain: String?
    let aiSummary: String?
    let noteType: String?
    let isPrivate: Bool
    let isPinned: Bool
    let wordCount: Int?
    let createdBy: UUID
    let lastModifiedBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title
        case workspaceId = "workspace_id"
        case subSpaceId = "sub_space_id"
        case content
        case contentPlain = "content_plain"
        case aiSummary = "ai_summary"
        case noteType = "note_type"
        case isPrivate = "is_private"
        case isPinned = "is_pinned"
        case wordCount = "word_count"
        case createdBy = "created_by"
        case lastModifiedBy = "last_modified_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workspaceId = try c.decode(UUID.self, forKey: .workspaceId)
        subSpaceId = try c.decode(UUID.self, forKey: .subSpaceId)
        title = try c.decode(String.self, forKey: .title)
        contentPlain = try c.decodeIfPresent(String.self, forKey: .contentPlain)
        aiSummary = try c.decodeIfPresent(String.self, forKey: .aiSummary)
        noteType = try c.decodeIfPresent(String.self, forKey: .noteType)
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount)
        createdBy = try c.decode(UUID.self, forKey: .createdBy)
        lastModifiedBy = try c.decodeIfPresent(UUID.self, forKey: .lastModifiedBy)
        createdAt = ISO8601Parser.parse((try? c.decodeIfPresent(String.self, forKey: .createdAt)) ?? nil)
        updatedAt = ISO8601Parser.parse((try? c.decodeIfPresent(String.self, forKey: .updatedAt)) ?? nil)
        contentData = Self.decodeContent(from: c)
    }

    /// Décodage robuste du JSONB content : JSONValue, puis String (JSON brut), puis Data.
    private static func decodeContent(from c: KeyedDecodingContainer<CodingKeys>) -> Data? {
        if let jsonVal = try? c.decodeIfPresent(JSONValue.self, forKey: .content), let str = jsonVal.jsonString {
            return str.data(using: .utf8)
        }
        if let str = try? c.decodeIfPresent(String.self, forKey: .content), str.count > 10, str.hasPrefix("{") {
            return str.data(using: .utf8)
        }
        if let data = try? c.decodeIfPresent(Data.self, forKey: .content), data.count > 10 {
            return data
        }
        return nil
    }

    func toNote() -> Note {
        return Note(
            id: id,
            workspaceId: workspaceId,
            subSpaceId: subSpaceId,
            title: title,
            content: contentData,
            contentPlain: contentPlain,
            aiSummary: aiSummary,
            noteType: noteType ?? "none",
            isPrivate: isPrivate,
            isPinned: isPinned,
            wordCount: wordCount ?? 0,
            locationCity: nil,
            locationCountry: nil,
            locationCountryCode: nil,
            unsplashImageUrl: nil,
            createdBy: createdBy,
            lastModifiedBy: lastModifiedBy,
            movedToTrashAt: nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
