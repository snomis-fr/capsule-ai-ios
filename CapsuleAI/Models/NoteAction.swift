//
//  NoteAction.swift
//  CapsuleAI
//

import Foundation

struct NoteAction: Codable, Identifiable {
    let id: UUID
    let noteId: UUID
    var label: String
    var isChecked: Bool
    var actionGroup: String
    var sortOrder: Int
    var checkedBy: UUID?
    var checkedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, label
        case noteId = "note_id"
        case isChecked = "is_checked"
        case actionGroup = "action_group"
        case sortOrder = "sort_order"
        case checkedBy = "checked_by"
        case checkedAt = "checked_at"
    }
}
