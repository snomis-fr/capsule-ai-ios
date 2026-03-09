//
//  Space.swift
//  CapsuleAI
//

import Foundation

struct Space: Codable, Identifiable, Hashable {
    let id: UUID
    let workspaceId: UUID
    var name: String
    var emoji: String
    var color: String
    var sortOrder: Int
    var isDefault: Bool
    let createdBy: UUID
    var isPrivate: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, color
        case workspaceId = "workspace_id"
        case sortOrder = "sort_order"
        case isDefault = "is_default"
        case createdBy = "created_by"
        case isPrivate = "is_private"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workspaceId = try c.decode(UUID.self, forKey: .workspaceId)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "📂"
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#3B82F6"
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isDefault = try c.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        createdBy = try c.decode(UUID.self, forKey: .createdBy)
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        createdAt = ISO8601Parser.parse((try? c.decodeIfPresent(String.self, forKey: .createdAt)) ?? nil)
        updatedAt = ISO8601Parser.parse((try? c.decodeIfPresent(String.self, forKey: .updatedAt)) ?? nil)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(workspaceId, forKey: .workspaceId)
        try c.encode(name, forKey: .name)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(color, forKey: .color)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(isDefault, forKey: .isDefault)
        try c.encode(createdBy, forKey: .createdBy)
        try c.encode(isPrivate, forKey: .isPrivate)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}
