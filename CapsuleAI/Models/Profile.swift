//
//  Profile.swift
//  CapsuleAI
//

import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let email: String
    var firstName: String?
    var lastName: String?
    var city: String?
    var title: String?
    var company: String?
    var activity: String?
    var avatarUrl: String?
    var status: String
    var role: String
    var workspaceId: UUID?
    var jobIcon: String?
    var geolocationEnabled: Bool?
    var notificationsEnabled: Bool?
    var offlineSyncEnabled: Bool?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, status, role
        case firstName = "first_name"
        case lastName = "last_name"
        case city, title, company, activity
        case avatarUrl = "avatar_url"
        case workspaceId = "workspace_id"
        case jobIcon = "job_icon"
        case geolocationEnabled = "geolocation_enabled"
        case notificationsEnabled = "notifications_enabled"
        case offlineSyncEnabled = "offline_sync_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var geolocationEnabledOrDefault: Bool { geolocationEnabled ?? true }
    var notificationsEnabledOrDefault: Bool { notificationsEnabled ?? true }
    var offlineSyncEnabledOrDefault: Bool { offlineSyncEnabled ?? false }

    init(id: UUID, email: String, status: String = "none", role: String = "collaborator", workspaceId: UUID? = nil, company: String? = nil) {
        self.id = id
        self.email = email
        self.firstName = nil
        self.lastName = nil
        self.city = nil
        self.title = nil
        self.company = company
        self.activity = nil
        self.avatarUrl = nil
        self.status = status
        self.role = role
        self.workspaceId = workspaceId
        self.jobIcon = nil
        self.geolocationEnabled = true
        self.notificationsEnabled = true
        self.offlineSyncEnabled = false
        self.createdAt = nil
        self.updatedAt = nil
    }

    init(id: UUID, email: String, firstName: String?, lastName: String?, city: String?, title: String?, company: String?, activity: String?, avatarUrl: String?, status: String, role: String, workspaceId: UUID?, jobIcon: String?, geolocationEnabled: Bool?, notificationsEnabled: Bool?, offlineSyncEnabled: Bool?) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.city = city
        self.title = title
        self.company = company
        self.activity = activity
        self.avatarUrl = avatarUrl
        self.status = status
        self.role = role
        self.workspaceId = workspaceId
        self.jobIcon = jobIcon
        self.geolocationEnabled = geolocationEnabled
        self.notificationsEnabled = notificationsEnabled
        self.offlineSyncEnabled = offlineSyncEnabled
        self.createdAt = nil
        self.updatedAt = nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        company = try c.decodeIfPresent(String.self, forKey: .company)
        activity = try c.decodeIfPresent(String.self, forKey: .activity)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "none"
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? "collaborator"
        workspaceId = try c.decodeIfPresent(UUID.self, forKey: .workspaceId)
        jobIcon = try c.decodeIfPresent(String.self, forKey: .jobIcon)
        geolocationEnabled = try c.decodeIfPresent(Bool.self, forKey: .geolocationEnabled)
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled)
        offlineSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .offlineSyncEnabled)
        createdAt = ISO8601Parser.parse((try? c.decodeIfPresent(String.self, forKey: .createdAt)) ?? nil)
        updatedAt = ISO8601Parser.parse((try? c.decodeIfPresent(String.self, forKey: .updatedAt)) ?? nil)
    }
}
