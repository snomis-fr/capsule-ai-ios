//
//  SubSpace.swift
//  CapsuleAI
//

import Foundation

struct SubSpace: Codable, Identifiable, Hashable {
    let id: UUID
    let spaceId: UUID
    let name: String
    var emoji: String
    var sortOrder: Int
    let createdBy: UUID
    var isTrash: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, emoji
        case spaceId = "space_id"
        case sortOrder = "sort_order"
        case createdBy = "created_by"
        case isTrash = "is_trash"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: UUID, spaceId: UUID, name: String, emoji: String, sortOrder: Int, createdBy: UUID, isTrash: Bool = false, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
        self.createdBy = createdBy
        self.isTrash = isTrash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        spaceId = try c.decode(UUID.self, forKey: .spaceId)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "📄"
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdBy = try c.decode(UUID.self, forKey: .createdBy)
        isTrash = try c.decodeIfPresent(Bool.self, forKey: .isTrash) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}
