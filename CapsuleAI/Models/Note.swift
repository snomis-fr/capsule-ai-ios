//
//  Note.swift
//  CapsuleAI
//

import Foundation

struct Note: Codable, Identifiable {
    let id: UUID
    let workspaceId: UUID
    let subSpaceId: UUID
    let title: String
    var content: Data? // JSONB — omitted in list queries, used in editor
    var contentPlain: String?
    var aiSummary: String?
    var noteType: String
    var isPrivate: Bool
    var isPinned: Bool
    var wordCount: Int
    var locationCity: String?
    var locationCountry: String?
    var locationCountryCode: String?
    var unsplashImageUrl: String?
    let createdBy: UUID
    var lastModifiedBy: UUID?
    var movedToTrashAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case workspaceId = "workspace_id"
        case subSpaceId = "sub_space_id"
        case contentPlain = "content_plain"
        case aiSummary = "ai_summary"
        case noteType = "note_type"
        case isPrivate = "is_private"
        case isPinned = "is_pinned"
        case wordCount = "word_count"
        case locationCity = "location_city"
        case locationCountry = "location_country"
        case locationCountryCode = "location_country_code"
        case unsplashImageUrl = "unsplash_image_url"
        case createdBy = "created_by"
        case lastModifiedBy = "last_modified_by"
        case movedToTrashAt = "moved_to_trash_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
