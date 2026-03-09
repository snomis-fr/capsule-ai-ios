//
//  NoteType.swift
//  CapsuleAI
//

import Foundation

struct NoteType: Codable, Identifiable {
    let id: UUID
    let workspaceId: UUID
    var name: String
    var emoji: String
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, emoji
        case workspaceId = "workspace_id"
        case sortOrder = "sort_order"
    }
}

struct NoteTypeAction: Codable, Identifiable {
    let id: UUID
    let noteTypeId: UUID
    var label: String
    var isUniversal: Bool
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, label
        case noteTypeId = "note_type_id"
        case isUniversal = "is_universal"
        case sortOrder = "sort_order"
    }
}
