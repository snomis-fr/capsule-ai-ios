//
//  Workspace.swift
//  CapsuleAI
//

import Foundation

struct Workspace: Codable, Identifiable {
    let id: UUID
    let name: String
    let displayName: String
    let managerId: UUID
    var maxCollaborators: Int
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case displayName = "display_name"
        case managerId = "manager_id"
        case maxCollaborators = "max_collaborators"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        displayName = try c.decode(String.self, forKey: .displayName)
        managerId = try c.decode(UUID.self, forKey: .managerId)
        maxCollaborators = try c.decodeIfPresent(Int.self, forKey: .maxCollaborators) ?? 7
        createdAt = ISO8601Parser.parse((try? c.decodeIfPresent(String.self, forKey: .createdAt)) ?? nil)
            ?? ISO8601Parser.parseFromTimestamp(try? c.decodeIfPresent(Double.self, forKey: .createdAt))
        updatedAt = ISO8601Parser.parse((try? c.decodeIfPresent(String.self, forKey: .updatedAt)) ?? nil)
            ?? ISO8601Parser.parseFromTimestamp(try? c.decodeIfPresent(Double.self, forKey: .updatedAt))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(managerId, forKey: .managerId)
        try c.encode(maxCollaborators, forKey: .maxCollaborators)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}
