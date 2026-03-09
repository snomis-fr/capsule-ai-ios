//
//  NoteEditorViewModel.swift
//  CapsuleAI
//

import Foundation
import Observation
import Supabase
import PhotosUI
import CoreLocation
import SwiftUI
import UniformTypeIdentifiers

private struct ImageFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: UTType.image) { data in
            ImageFile(data: data)
        }
    }
}

/// Élément de plan d'action affiché (checkbox)
struct ActionCheckboxItem: Identifiable {
    let id: UUID
    let label: String
    var isChecked: Bool
    let actionGroup: String
}

/// Pièce jointe en attente d'upload
struct PendingAttachment: Identifiable {
    let id: UUID
    let fileName: String
    let isPhoto: Bool
    let fileData: Data
    let mimeType: String
    let fileType: String // "photo" | "pdf" | "file"
}

/// Actions par défaut (universelles + par type)
enum NoteTypeDefaultActions {
    static let universal: [String] = [
        "Définir les objectifs",
        "Identifier les responsabilités",
        "Fixer une date limite",
        "Faire un suivi"
    ]
    static func forType(_ name: String) -> [String] {
        switch name {
        case "Réunion": return ["Préparer l'ordre du jour", "Envoyer l'invitation", "Rédiger le compte-rendu"]
        case "Projet": return ["Définir le périmètre", "Planifier les étapes", "Assigner les ressources"]
        case "Problème": return ["Identifier la cause racine", "Proposer des solutions", "Choisir et implémenter"]
        case "Stratégie": return ["Analyser le contexte", "Définir les priorités", "Élaborer le plan"]
        default: return []
        }
    }
}

@Observable
final class NoteEditorViewModel {
    var spaces: [Space] = []
    var subSpaces: [SubSpace] = []
    var tags: [Tag] = []
    var noteTypes: [NoteType] = []
    var selectedSpaceId: UUID?
    var selectedSubSpaceId: UUID?
    var title = ""
    var contentJson: Data?
    var contentPlain = ""
    var selectedTagIds: Set<UUID> = []
    var isPrivate = false
    var isPinned = false
    var selectedNoteTypeId: UUID?
    var actionCheckboxes: [ActionCheckboxItem] = []
    var pendingAttachments: [PendingAttachment] = []
    var showDocumentPicker = false
    var initialHtmlOverride: String?
    var locationCity: String?
    var locationCountry: String?
    var locationCountryCode: String?
    var isLoading = false
    var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    var canSave: Bool {
        selectedSpaceId != nil && selectedSubSpaceId != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Réinitialise le formulaire pour une nouvelle note (après sauvegarde, quand on revient sur l’onglet création).
    func resetForNewNote() {
        title = ""
        contentJson = nil
        contentPlain = ""
        selectedTagIds = []
        isPrivate = false
        isPinned = false
        selectedNoteTypeId = nil
        actionCheckboxes = []
        pendingAttachments = []
        initialHtmlOverride = nil
        locationCity = nil
        locationCountry = nil
        locationCountryCode = nil
        selectDefaultSpaceAndSubSpace()
    }

    /// Sélectionne par défaut « Non classées » > premier sous-espace non-poubelle (pour création rapide).
    func selectDefaultSpaceAndSubSpace() {
        let space = spaces.first { $0.isDefault } ?? spaces.first
        guard let sp = space else { return }
        let subs = subSpaces.filter { $0.spaceId == sp.id && !$0.isTrash }
        selectedSpaceId = sp.id
        selectedSubSpaceId = subs.first?.id
    }

    var currentSubSpaces: [SubSpace] {
        guard let sid = selectedSpaceId else { return [] }
        return subSpaces.filter { $0.spaceId == sid }
    }

    var locationDisplay: String? {
        [locationCity, locationCountry].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    func load(workspaceId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // Ordre défini par le manager dans le profil (Non classé toujours en dernier)
            let fetched: [Space] = try await supabase.from(Tables.spaces).select().eq("workspace_id", value: workspaceId).order("sort_order").execute().value
            spaces = fetched.sortedWithDefaultLast()
            // Charger les sous-espaces par espace (ordre identique au profil manager)
            var subs: [SubSpace] = []
            for space in spaces {
                let spaceSubs: [SubSpace] = try await supabase.from(Tables.subSpaces).select().eq("space_id", value: space.id).order("sort_order").execute().value
                subs.append(contentsOf: spaceSubs)
            }
            subSpaces = subs
            tags = try await supabase.from(Tables.tags).select().eq("workspace_id", value: workspaceId).order("sort_order").execute().value
            noteTypes = try await supabase.from(Tables.noteTypes).select().eq("workspace_id", value: workspaceId).order("sort_order").execute().value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadNote(noteId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            struct FullNoteRow: Decodable {
                    let subSpaceId: UUID
                    let title: String
                    let content: String?
                    let contentPlain: String?
                    let isPrivate: Bool
                    let isPinned: Bool
                    let noteType: String?
                    let locationCity: String?
                    let locationCountry: String?
                    let locationCountryCode: String?
                    enum CodingKeys: String, CodingKey {
                        case subSpaceId = "sub_space_id"
                        case title, content
                        case contentPlain = "content_plain"
                        case isPrivate = "is_private"
                        case isPinned = "is_pinned"
                        case noteType = "note_type"
                        case locationCity = "location_city"
                        case locationCountry = "location_country"
                        case locationCountryCode = "location_country_code"
                    }
                    init(from decoder: Decoder) throws {
                        let c = try decoder.container(keyedBy: CodingKeys.self)
                        subSpaceId = try c.decode(UUID.self, forKey: .subSpaceId)
                        title = try c.decode(String.self, forKey: .title)
                        contentPlain = try c.decodeIfPresent(String.self, forKey: .contentPlain)
                        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
                        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
                        noteType = try c.decodeIfPresent(String.self, forKey: .noteType)
                        locationCity = try c.decodeIfPresent(String.self, forKey: .locationCity)
                        locationCountry = try c.decodeIfPresent(String.self, forKey: .locationCountry)
                        locationCountryCode = try c.decodeIfPresent(String.self, forKey: .locationCountryCode)
                        content = try? Self.decodeJSONB(container: c)
                    }
                    private static func decodeJSONB(container c: KeyedDecodingContainer<CodingKeys>) -> String? {
                        guard let v = try? c.decode(JSONValue.self, forKey: .content) else { return nil }
                        return v.jsonString
                    }
                }
                let row: FullNoteRow = try await supabase.from(Tables.notes).select("sub_space_id,title,content,content_plain,is_private,is_pinned,note_type,location_city,location_country,location_country_code").eq("id", value: noteId).single().execute().value
            selectedSubSpaceId = row.subSpaceId
            if let ss = subSpaces.first(where: { $0.id == row.subSpaceId }) {
                selectedSpaceId = ss.spaceId
            }
            title = row.title
            if initialHtmlOverride == nil {
                contentJson = row.content?.data(using: .utf8)
                contentPlain = row.contentPlain ?? ""
            }
            isPrivate = row.isPrivate
            isPinned = row.isPinned
            locationCity = row.locationCity
            locationCountry = row.locationCountry
            locationCountryCode = row.locationCountryCode
            if let ntStr = row.noteType, let ntUuid = UUID(uuidString: ntStr) {
                selectedNoteTypeId = ntUuid
                await loadActionsForSelectedType()
                struct ActionRow: Decodable {
                    let label: String
                    let isChecked: Bool
                    enum CodingKeys: String, CodingKey {
                        case label
                        case isChecked = "is_checked"
                    }
                }
                let actions: [ActionRow] = try await supabase.from(Tables.noteActions).select("label,is_checked").eq("note_id", value: noteId).order("sort_order").execute().value
                for ar in actions {
                    if let idx = actionCheckboxes.firstIndex(where: { $0.label == ar.label }) {
                        actionCheckboxes[idx].isChecked = ar.isChecked
                    }
                }
            }
            // Load tags
            struct NoteTagRow: Decodable { let tag_id: UUID }
            let tagRows: [NoteTagRow] = try await supabase.from(Tables.noteTags).select("tag_id").eq("note_id", value: noteId).execute().value
            selectedTagIds = Set(tagRows.map(\.tag_id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadActionsForSelectedType() async {
        guard let typeId = selectedNoteTypeId,
              let type = noteTypes.first(where: { $0.id == typeId }) else {
            actionCheckboxes = []
            return
        }
        var items: [ActionCheckboxItem] = []
        var sortOrder = 0
        for label in NoteTypeDefaultActions.universal {
            items.append(ActionCheckboxItem(id: UUID(), label: label, isChecked: false, actionGroup: "universal"))
            sortOrder += 1
        }
        for label in NoteTypeDefaultActions.forType(type.name) {
            items.append(ActionCheckboxItem(id: UUID(), label: label, isChecked: false, actionGroup: "specific"))
            sortOrder += 1
        }
        actionCheckboxes = items
    }

    func toggleAction(id: UUID) {
        if let idx = actionCheckboxes.firstIndex(where: { $0.id == id }) {
            actionCheckboxes[idx].isChecked.toggle()
        }
    }

    func processSelectedPhotos(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            pendingAttachments.removeAll { $0.isPhoto }
            return
        }
        let photoLimit = AppLimits.maxPhotoSizeMB * 1024 * 1024
        var newPhotos: [PendingAttachment] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: ImageFile.self)?.data, data.count <= photoLimit {
                let name = "photo_\(UUID().uuidString.prefix(8)).jpg"
                newPhotos.append(PendingAttachment(id: UUID(), fileName: name, isPhoto: true, fileData: data, mimeType: "image/jpeg", fileType: "photo"))
            }
        }
        pendingAttachments.removeAll { $0.isPhoto }
        pendingAttachments.append(contentsOf: newPhotos)
    }

    func addDocument(url: URL) {
        let limit = AppLimits.maxFileSizeMB * 1024 * 1024
        guard let data = try? Data(contentsOf: url),
              data.count <= limit else {
            errorMessage = "Fichier trop volumineux (max \(AppLimits.maxFileSizeMB) Mo)"
            return
        }
        let ext = url.pathExtension.lowercased()
        let fileType: String
        let mime: String
        if ext == "pdf" {
            fileType = "pdf"
            mime = "application/pdf"
        } else {
            fileType = "file"
            mime = "application/octet-stream"
        }
        let name = url.lastPathComponent
        pendingAttachments.append(PendingAttachment(id: UUID(), fileName: name, isPhoto: false, fileData: data, mimeType: mime, fileType: fileType))
    }

    func removePendingAttachment(_ id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func fetchLocation() async {
        let fetcher = LocationFetcher()
        let (city, country, code) = await fetcher.fetch()
        await MainActor.run {
            locationCity = city
            locationCountry = country
            locationCountryCode = code
        }
    }

    func save(workspaceId: UUID, userId: UUID, noteId: UUID?, subSpaceId: UUID) async throws -> UUID {
        let noteTypeStr = selectedNoteTypeId?.uuidString
        var contentJSON: JSONValue? = contentJson.flatMap { JSONValue.from(data: $0) }
        // Fallback : si le JSON Tiptap ne se convertit pas, créer un doc minimal à partir du texte brut
        if contentJSON == nil, !contentPlain.trimmingCharacters(in: .whitespaces).isEmpty {
            let textNode: JSONValue = .object(["type": .string("text"), "text": .string(contentPlain)])
            let paraContent: JSONValue = .array([textNode])
            let para: JSONValue = .object(["type": .string("paragraph"), "content": paraContent])
            contentJSON = .object(["type": .string("doc"), "content": .array([para])])
        }

        struct NoteInsert: Encodable {
            let workspaceId: UUID
            let subSpaceId: UUID
            let title: String
            let content: JSONValue?
            let contentPlain: String?
            let noteType: String?
            let isPrivate: Bool
            let isPinned: Bool
            let locationCity: String?
            let locationCountry: String?
            let locationCountryCode: String?
            let createdBy: UUID

            enum CodingKeys: String, CodingKey {
                case title
                case workspaceId = "workspace_id"
                case subSpaceId = "sub_space_id"
                case content
                case contentPlain = "content_plain"
                case noteType = "note_type"
                case isPrivate = "is_private"
                case isPinned = "is_pinned"
                case locationCity = "location_city"
                case locationCountry = "location_country"
                case locationCountryCode = "location_country_code"
                case createdBy = "created_by"
            }
        }
        struct NoteUpdate: Encodable {
            let subSpaceId: UUID
            let title: String
            let content: JSONValue?
            let contentPlain: String?
            let noteType: String?
            let isPrivate: Bool
            let isPinned: Bool
            let locationCity: String?
            let locationCountry: String?
            let locationCountryCode: String?
            let lastModifiedBy: UUID

            enum CodingKeys: String, CodingKey {
                case title
                case subSpaceId = "sub_space_id"
                case content
                case contentPlain = "content_plain"
                case noteType = "note_type"
                case isPrivate = "is_private"
                case isPinned = "is_pinned"
                case locationCity = "location_city"
                case locationCountry = "location_country"
                case locationCountryCode = "location_country_code"
                case lastModifiedBy = "last_modified_by"
            }
        }

        var finalNoteId: UUID
        if let nid = noteId {
            try await supabase.from(Tables.notes).update(NoteUpdate(
                subSpaceId: subSpaceId,
                title: title.trimmingCharacters(in: .whitespaces),
                content: contentJSON,
                contentPlain: contentPlain.isEmpty ? nil : contentPlain,
                noteType: noteTypeStr,
                isPrivate: isPrivate,
                isPinned: isPinned,
                locationCity: locationCity,
                locationCountry: locationCountry,
                locationCountryCode: locationCountryCode,
                lastModifiedBy: userId
            )).eq("id", value: nid).execute()
            finalNoteId = nid
        } else {
            struct InsertedId: Decodable { let id: UUID }
            let result: InsertedId = try await supabase.from(Tables.notes).insert(NoteInsert(
                workspaceId: workspaceId,
                subSpaceId: subSpaceId,
                title: title.trimmingCharacters(in: .whitespaces),
                content: contentJSON,
                contentPlain: contentPlain.isEmpty ? nil : contentPlain,
                noteType: noteTypeStr,
                isPrivate: isPrivate,
                isPinned: isPinned,
                locationCity: locationCity,
                locationCountry: locationCountry,
                locationCountryCode: locationCountryCode,
                createdBy: userId
            )).select("id").single().execute().value
            finalNoteId = result.id
        }

        // note_tags
        try await supabase.from(Tables.noteTags).delete().eq("note_id", value: finalNoteId).execute()
        for tagId in selectedTagIds {
            struct NoteTagInsert: Encodable {
                let noteId: UUID
                let tagId: UUID
                enum CodingKeys: String, CodingKey {
                    case noteId = "note_id"
                    case tagId = "tag_id"
                }
            }
            try await supabase.from(Tables.noteTags).insert(NoteTagInsert(noteId: finalNoteId, tagId: tagId)).execute()
        }

        // note_actions (remplace tout)
        _ = try? await supabase.from(Tables.noteActions).delete().eq("note_id", value: finalNoteId).execute()
        for (idx, item) in actionCheckboxes.enumerated() {
            struct ActionInsert: Encodable {
                let noteId: UUID
                let label: String
                let isChecked: Bool
                let actionGroup: String
                let sortOrder: Int
                let checkedBy: UUID?
                let checkedAt: String?
                enum CodingKeys: String, CodingKey {
                    case noteId = "note_id"
                    case label
                    case isChecked = "is_checked"
                    case actionGroup = "action_group"
                    case sortOrder = "sort_order"
                    case checkedBy = "checked_by"
                    case checkedAt = "checked_at"
                }
            }
            let checkedBy = item.isChecked ? userId : nil
            let checkedAt = item.isChecked ? ISO8601DateFormatter().string(from: Date()) : nil
            try await supabase.from(Tables.noteActions).insert(ActionInsert(
                noteId: finalNoteId,
                label: item.label,
                isChecked: item.isChecked,
                actionGroup: item.actionGroup,
                sortOrder: idx,
                checkedBy: checkedBy,
                checkedAt: checkedAt
            )).execute()
        }

        // attachments
        for att in pendingAttachments {
            let path = "\(finalNoteId.uuidString)/\(att.fileName)"
            try await supabase.storage
                .from(Buckets.attachments)
                .upload(path, data: att.fileData, options: .init(contentType: att.mimeType, upsert: true))
            struct AttInsert: Encodable {
                let noteId: UUID
                let fileName: String
                let fileType: String
                let fileSize: Int
                let storagePath: String
                let mimeType: String
                let uploadedBy: UUID
                enum CodingKeys: String, CodingKey {
                    case noteId = "note_id"
                    case fileName = "file_name"
                    case fileType = "file_type"
                    case fileSize = "file_size"
                    case storagePath = "storage_path"
                    case mimeType = "mime_type"
                    case uploadedBy = "uploaded_by"
                }
            }
            try await supabase.from(Tables.attachments).insert(AttInsert(
                noteId: finalNoteId,
                fileName: att.fileName,
                fileType: att.fileType,
                fileSize: att.fileData.count,
                storagePath: path,
                mimeType: att.mimeType,
                uploadedBy: userId
            )).execute()
        }
        pendingAttachments.removeAll()

        return finalNoteId
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
}
