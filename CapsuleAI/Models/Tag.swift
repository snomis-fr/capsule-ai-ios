//
//  Tag.swift
//  CapsuleAI
//

import Foundation

struct Tag: Codable, Identifiable {
    let id: UUID
    let workspaceId: UUID
    var name: String
    var color: String
    var sortOrder: Int
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case workspaceId = "workspace_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}
