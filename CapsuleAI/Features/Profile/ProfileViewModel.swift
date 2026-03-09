//
//  ProfileViewModel.swift
//  CapsuleAI
//

import Foundation
import Observation
import Supabase

@Observable
final class ProfileViewModel {
    // MARK: - State
    var profile: Profile?
    var spaces: [Space] = []
    var subSpacesBySpace: [UUID: [SubSpace]] = [:]
    var tags: [Tag] = []
    var collaborators: [Profile] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var didSignOut = false

    // Stats
    var notesTotal = 0
    var spacesActive = 0
    var notesCreatedByUser = 0
    var tagsImportant = 0

    // Editables (avant sauvegarde)
    var firstName: String = ""
    var lastName: String = ""
    var city: String = ""
    var title: String = ""
    var company: String = ""
    var geolocationEnabled: Bool = true
    var notificationsEnabled: Bool = true
    var offlineSyncEnabled: Bool = false

    var isManager: Bool { profile?.role == "manager" }
    var collaboratorCount: Int { collaborators.count }

    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared.client
    private var autoSaveTask: Task<Void, Never>?

    // MARK: - Actions

    func scheduleAutoSave() {
        guard profile != nil else { return }
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            _ = try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    func load(fallbackWorkspaceId: UUID? = nil) async {
        guard let userId = (try? await supabase.auth.session)?.user.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Pré-remplir depuis le cache (en arrière-plan pour ne pas bloquer l’UI)
        do {
            try await loadProfile(userId: userId)
            // Priorité à appState (source fiable après onboarding) puis au profil DB
            let wsId = fallbackWorkspaceId ?? profile?.workspaceId
            guard let wsId else { return }

            async let statsTask: () = loadStats(workspaceId: wsId, userId: userId)
            async let spacesTask: () = loadSpaces(workspaceId: wsId)
            async let tagsTask: () = loadTags(workspaceId: wsId)
            async let collabTask: () = loadCollaborators(workspaceId: wsId)

            _ = try await (statsTask, spacesTask, tagsTask, collabTask)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadProfile(userId: UUID) async throws {
        struct ProfileRow: Decodable {
            let id: UUID
            let email: String
            let firstName: String?
            let lastName: String?
            let city: String?
            let title: String?
            let company: String?
            let activity: String?
            let avatarUrl: String?
            let status: String
            let role: String
            let workspaceId: UUID?
            let geolocationEnabled: Bool?
            let notificationsEnabled: Bool?
            let offlineSyncEnabled: Bool?

            enum CodingKeys: String, CodingKey {
                case id, email, status, role
                case firstName = "first_name"
                case lastName = "last_name"
                case city, title, company, activity
                case avatarUrl = "avatar_url"
                case workspaceId = "workspace_id"
                case geolocationEnabled = "geolocation_enabled"
                case notificationsEnabled = "notifications_enabled"
                case offlineSyncEnabled = "offline_sync_enabled"
            }
        }

        let rows: [ProfileRow] = try await supabase
            .from(Tables.profiles)
            .select()
            .eq("id", value: userId)
            .execute()
            .value

        guard let row = rows.first else { return }

        profile = Profile(
            id: row.id,
            email: row.email,
            firstName: row.firstName,
            lastName: row.lastName,
            city: row.city,
            title: row.title,
            company: row.company,
            activity: row.activity,
            avatarUrl: row.avatarUrl,
            status: row.status,
            role: row.role,
            workspaceId: row.workspaceId,
            jobIcon: nil,
            geolocationEnabled: row.geolocationEnabled,
            notificationsEnabled: row.notificationsEnabled,
            offlineSyncEnabled: row.offlineSyncEnabled
        )

        firstName = row.firstName ?? ""
        lastName = row.lastName ?? ""
        city = row.city ?? ""
        title = row.title ?? ""
        company = row.company ?? ""
        geolocationEnabled = row.geolocationEnabled ?? true
        notificationsEnabled = row.notificationsEnabled ?? true
        offlineSyncEnabled = row.offlineSyncEnabled ?? false
    }

    private func applyProfileEditableFields() {
        guard let p = profile else { return }
        firstName = p.firstName ?? ""
        lastName = p.lastName ?? ""
        city = p.city ?? ""
        title = p.title ?? ""
        company = p.company ?? ""
        geolocationEnabled = p.geolocationEnabled ?? true
        notificationsEnabled = p.notificationsEnabled ?? true
        offlineSyncEnabled = p.offlineSyncEnabled ?? false
    }

    private func loadStats(workspaceId: UUID, userId: UUID) async throws {
        struct IdRow: Decodable { let id: UUID }
        struct NoteIdRow: Decodable { let id: UUID }

        let notesAll: [NoteIdRow] = try await supabase
            .from(Tables.notes)
            .select("id")
            .eq("workspace_id", value: workspaceId)
            .limit(10000)
            .execute()
            .value
        notesTotal = notesAll.count

        let spacesAll: [IdRow] = try await supabase
            .from(Tables.spaces)
            .select("id")
            .eq("workspace_id", value: workspaceId)
            .execute()
            .value
        spacesActive = spacesAll.count

        let notesMine: [NoteIdRow] = try await supabase
            .from(Tables.notes)
            .select("id")
            .eq("workspace_id", value: workspaceId)
            .eq("created_by", value: userId)
            .limit(10000)
            .execute()
            .value
        notesCreatedByUser = notesMine.count

        tagsImportant = try await countNotesWithImportantTag(workspaceId: workspaceId, userId: userId)
    }

    private func countNotesWithImportantTag(workspaceId: UUID, userId: UUID) async throws -> Int {
        // Aligné avec Home/SubSpaceNotes : une note "importante" = tag Important (via note_tags)
        // On compte les notes visibles qui ont le tag, pour correspondre à ce que l'utilisateur voit
        struct NoteTagRow: Decodable { let note_id: UUID }
        struct IdRow: Decodable { let id: UUID }

        let allTags: [Tag] = try await supabase
            .from(Tables.tags)
            .select()
            .eq("workspace_id", value: workspaceId)
            .execute()
            .value
        let importantTags = allTags.filter { $0.name.lowercased().trimmingCharacters(in: CharacterSet.whitespaces) == "important" }

        guard !importantTags.isEmpty else { return 0 }

        var allNoteIds = Set<UUID>()
        for tag in importantTags {
            let rows: [NoteTagRow] = try await supabase
                .from(Tables.noteTags)
                .select("note_id")
                .eq("tag_id", value: tag.id)
                .execute()
                .value
            for r in rows { allNoteIds.insert(r.note_id) }
        }

        if allNoteIds.isEmpty { return 0 }

        // Croiser avec les notes visibles (RLS) pour éviter décalage avec l'affichage
        struct NoteId: Decodable { let id: UUID }
        let visible: [NoteId] = try await supabase
            .from(Tables.notes)
            .select("id")
            .eq("workspace_id", value: workspaceId)
            .in("id", values: Array(allNoteIds))
            .execute()
            .value
        return visible.count
    }

    private func loadSpaces(workspaceId: UUID) async throws {
        let fetched: [Space] = try await supabase
            .from(Tables.spaces)
            .select()
            .eq("workspace_id", value: workspaceId)
            .order("sort_order")
            .execute()
            .value
        spaces = fetched
        sortSpaces()
        for space in spaces {
            let subs: [SubSpace] = try await supabase
                .from(Tables.subSpaces)
                .select()
                .eq("space_id", value: space.id)
                .order("sort_order")
                .execute()
                .value
            subSpacesBySpace[space.id] = subs
        }
    }

    /// Tags par défaut (alignés avec le seed Supabase pour corrélation)
    private static let defaultTags: [(name: String, color: String, sortOrder: Int)] = [
        ("priorité", "#EF4444", 0),
        ("urgent", "#F59E0B", 1),
        ("stratégie", "#8B5CF6", 2),
        ("client", "#22C55E", 3),
        ("suivi", "#06B6D4", 4),
        ("archivé", "#64748B", 5),
        ("relecture", "#EC4899", 6),
        ("validé", "#14B8A6", 7),
    ]

    /// Charge tous les tags du workspace. Si aucun tag n'existe, crée les tags par défaut (corrélation avec la base).
    private func loadTags(workspaceId: UUID) async throws {
        var fetched: [Tag] = try await supabase
            .from(Tables.tags)
            .select()
            .eq("workspace_id", value: workspaceId)
            .order("sort_order")
            .execute()
            .value

        if isManager {
            try? await ensureDefaultTags(workspaceId: workspaceId, existingNames: Set(fetched.map { $0.name.lowercased() }))
            fetched = (try? await supabase
                .from(Tables.tags)
                .select()
                .eq("workspace_id", value: workspaceId)
                .order("sort_order")
                .execute()
                .value) ?? fetched
        }

        struct NoteIdRow: Decodable { let id: UUID }
        struct NoteTagRow: Decodable { let tag_id: UUID }
        let noteIdRows: [NoteIdRow] = (try? await supabase
            .from(Tables.notes)
            .select("id")
            .eq("workspace_id", value: workspaceId)
            .execute()
            .value) ?? []
        let noteIds = noteIdRows.map(\.id)
        if noteIds.isEmpty {
            tags = fetched.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            return
        }
        let ntRows: [NoteTagRow] = (try? await supabase
            .from(Tables.noteTags)
            .select("tag_id")
            .in("note_id", values: noteIds)
            .execute()
            .value) ?? []
        let tagIdsFromNotes = Set(ntRows.map(\.tag_id))
        let fetchedIds = Set(fetched.map(\.id))
        let missingIds = tagIdsFromNotes.subtracting(fetchedIds)
        if !missingIds.isEmpty {
            let extra: [Tag] = (try? await supabase
                .from(Tables.tags)
                .select()
                .in("id", values: Array(missingIds))
                .execute()
                .value) ?? []
            fetched = fetched + extra
        }
        tags = fetched.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    private func ensureDefaultTags(workspaceId: UUID, existingNames: Set<String> = []) async throws {
        struct TagInsert: Encodable {
            let workspaceId: UUID
            let name: String
            let color: String
            let sortOrder: Int
            enum CodingKeys: String, CodingKey {
                case name, color
                case workspaceId = "workspace_id"
                case sortOrder = "sort_order"
            }
        }
        for item in Self.defaultTags {
            guard !existingNames.contains(item.name.lowercased()) else { continue }
            do {
                _ = try await supabase
                    .from(Tables.tags)
                    .insert(TagInsert(workspaceId: workspaceId, name: item.name, color: item.color, sortOrder: item.sortOrder))
                    .execute()
            } catch {
                // Ignorer les doublons (tag déjà existant)
            }
        }
    }

    private func loadCollaborators(workspaceId: UUID) async throws {
        struct CARow: Decodable { let user_id: UUID }
        let rows: [CARow] = try await supabase
            .from(Tables.collaboratorAccess)
            .select("user_id")
            .eq("workspace_id", value: workspaceId)
            .execute()
            .value

        let userIds = Array(Set(rows.map(\.user_id)))
        var collabs: [Profile] = []
        for uid in userIds {
            let p: [Profile] = try await supabase
                .from(Tables.profiles)
                .select()
                .eq("id", value: uid)
                .execute()
                .value
            if let pr = p.first { collabs.append(pr) }
        }
        collaborators = collabs
    }

    func save() async {
        guard let userId = profile?.id else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            struct ProfileUpdate: Encodable {
                let firstName: String?
                let lastName: String?
                let city: String?
                let title: String?
                let company: String?
                let geolocationEnabled: Bool
                let notificationsEnabled: Bool
                let offlineSyncEnabled: Bool

                enum CodingKeys: String, CodingKey {
                    case firstName = "first_name"
                    case lastName = "last_name"
                    case city, title, company
                    case geolocationEnabled = "geolocation_enabled"
                    case notificationsEnabled = "notifications_enabled"
                    case offlineSyncEnabled = "offline_sync_enabled"
                }
            }

            try await supabase
                .from(Tables.profiles)
                .update(ProfileUpdate(
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName,
                    city: city.isEmpty ? nil : city,
                    title: title.isEmpty ? nil : title,
                    company: isManager ? (company.isEmpty ? nil : company) : nil,
                    geolocationEnabled: geolocationEnabled,
                    notificationsEnabled: notificationsEnabled,
                    offlineSyncEnabled: offlineSyncEnabled
                ))
                .eq("id", value: userId)
                .execute()

            if var p = profile {
                p.firstName = firstName.isEmpty ? nil : firstName
                p.lastName = lastName.isEmpty ? nil : lastName
                p.city = city.isEmpty ? nil : city
                p.title = title.isEmpty ? nil : title
                if isManager { p.company = company.isEmpty ? nil : company }
                p.geolocationEnabled = geolocationEnabled
                p.notificationsEnabled = notificationsEnabled
                p.offlineSyncEnabled = offlineSyncEnabled
                profile = p
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            await save()
            try await supabase.auth.signOut()
            didSignOut = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sauvegarde le snapshot actuel vers le cache local pour restauration au prochain login.
    func persistToLocalCache() {
        guard let userId = profile?.id else { return }
        LocalDataCache.shared.save(
            userId: userId,
            profile: profile!,
            workspaceId: profile?.workspaceId,
            spaces: spaces,
            subSpacesBySpace: subSpacesBySpace,
            collaborators: collaborators,
            tags: tags
        )
    }

    func uploadAvatar(imageData: Data) async {
        guard let userId = profile?.id else { return }
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        do {
            try await supabase.storage
                .from(Buckets.avatars)
                .upload(path, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))
            let bucket = supabase.storage.from(Buckets.avatars)
            let url = try bucket.getPublicURL(path: path).absoluteString
            struct AvatarUpdate: Encodable { let avatar_url: String }
            try await supabase.from(Tables.profiles).update(AvatarUpdate(avatar_url: url)).eq("id", value: userId).execute()
            if var p = profile { p.avatarUrl = url; profile = p }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSpace(name: String, color: String = "#3B82F6", fallbackWorkspaceId: UUID? = nil) async throws {
        guard let userId = (try? await supabase.auth.session)?.user.id else {
            throw NSError(domain: "ProfileViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "Non authentifié"])
        }
        guard let wsId = profile?.workspaceId ?? fallbackWorkspaceId else {
            throw NSError(domain: "ProfileViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Aucun espace de travail"])
        }

        struct SpaceInsert: Encodable {
            let workspaceId: UUID
            let name: String
            let emoji: String
            let color: String
            let sortOrder: Int
            let isDefault: Bool
            let createdBy: UUID
            let isPrivate: Bool
            enum CodingKeys: String, CodingKey {
                case name, emoji, color
                case workspaceId = "workspace_id"
                case sortOrder = "sort_order"
                case isDefault = "is_default"
                case createdBy = "created_by"
                case isPrivate = "is_private"
            }
        }

        let nextOrder = spaces.filter { !$0.isDefault }.map(\.sortOrder).max().map { $0 + 1 } ?? 0

        try await supabase
            .from(Tables.spaces)
            .insert(SpaceInsert(
                workspaceId: wsId,
                name: name,
                emoji: "📂",
                color: color,
                sortOrder: nextOrder,
                isDefault: false,
                createdBy: userId,
                isPrivate: false
            ))
            .execute()

        await load(fallbackWorkspaceId: wsId)
    }

    func deleteSpace(_ space: Space) async throws {
        guard !space.isDefault else { return }
        let subs = subSpacesBySpace[space.id] ?? []
        guard subs.isEmpty else { return }

        try await supabase.from(Tables.spaces).delete().eq("id", value: space.id).execute()
        spaces.removeAll { $0.id == space.id }
        subSpacesBySpace.removeValue(forKey: space.id)
    }

    func moveSpaces(from source: IndexSet, to destination: Int) {
        var nonDefault = spaces.filter { !$0.isDefault }
        nonDefault.move(fromOffsets: source, toOffset: destination)
        let defaultSpace = spaces.first { $0.isDefault }
        spaces = nonDefault + (defaultSpace.map { [$0] } ?? [])
        Task { await updateSpaceOrder() }
    }

    private func sortSpaces() {
        spaces = spaces.sortedWithDefaultLast()
    }

    private func updateSpaceOrder() async {
        struct SortUpdate: Encodable { let sort_order: Int }
        for (i, s) in spaces.enumerated() {
            _ = try? await supabase.from(Tables.spaces).update(SortUpdate(sort_order: i)).eq("id", value: s.id).execute()
        }
    }

    func updateSpaceColor(_ space: Space, color: String) async throws {
        struct ColorUpdate: Encodable { let color: String }
        try await supabase.from(Tables.spaces).update(ColorUpdate(color: color)).eq("id", value: space.id).execute()
        if let idx = spaces.firstIndex(where: { $0.id == space.id }) {
            spaces[idx].color = color
        }
    }

    func updateSpaceName(_ space: Space, name: String) async throws {
        struct NameUpdate: Encodable { let name: String }
        try await supabase.from(Tables.spaces).update(NameUpdate(name: name)).eq("id", value: space.id).execute()
        if let idx = spaces.firstIndex(where: { $0.id == space.id }) {
            spaces[idx].name = name
        }
    }

    func updateSpaceEmoji(_ space: Space, emoji: String) async throws {
        struct EmojiUpdate: Encodable { let emoji: String }
        try await supabase.from(Tables.spaces).update(EmojiUpdate(emoji: emoji)).eq("id", value: space.id).execute()
        if let idx = spaces.firstIndex(where: { $0.id == space.id }) {
            spaces[idx].emoji = emoji
        }
    }

    func addTag(name: String, color: String) async throws {
        guard let wsId = profile?.workspaceId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let lowerName = trimmed.lowercased()
        if tags.contains(where: { $0.name.lowercased() == lowerName }) {
            throw NSError(domain: "ProfileViewModel", code: 409, userInfo: [NSLocalizedDescriptionKey: "Un tag avec ce nom existe déjà (insensible à la casse)"])
        }
        struct TagInsert: Encodable {
            let workspaceId: UUID
            let name: String
            let color: String
            let sortOrder: Int
            enum CodingKeys: String, CodingKey {
                case name, color
                case workspaceId = "workspace_id"
                case sortOrder = "sort_order"
            }
        }
        let nextOrder = tags.map(\.sortOrder).max().map { $0 + 1 } ?? 0
        let newTags: [Tag] = try await supabase
            .from(Tables.tags)
            .insert(TagInsert(workspaceId: wsId, name: trimmed, color: color, sortOrder: nextOrder))
            .select()
            .execute()
            .value
        if let t = newTags.first { tags.append(t) }
    }

    func syncDefaultTags() async {
        guard let wsId = profile?.workspaceId, isManager else { return }
        errorMessage = nil
        do {
            try await ensureDefaultTags(workspaceId: wsId, existingNames: Set(tags.map { $0.name.lowercased() }))
            let fetched: [Tag] = try await supabase
                .from(Tables.tags)
                .select()
                .eq("workspace_id", value: wsId)
                .order("sort_order")
                .execute()
                .value
            tags = fetched.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTag(_ tag: Tag, name: String?, color: String?) async throws {
        if let n = name {
            let trimmed = n.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            let lowerName = trimmed.lowercased()
            if tags.contains(where: { $0.id != tag.id && $0.name.lowercased() == lowerName }) {
                throw NSError(domain: "ProfileViewModel", code: 409, userInfo: [NSLocalizedDescriptionKey: "Un tag avec ce nom existe déjà (insensible à la casse)"])
            }
            struct NameUpdate: Encodable { let name: String }
            try await supabase.from(Tables.tags).update(NameUpdate(name: trimmed)).eq("id", value: tag.id).execute()
            if let idx = tags.firstIndex(where: { $0.id == tag.id }) { tags[idx].name = trimmed }
        }
        if let c = color {
            struct ColorUpdate: Encodable { let color: String }
            try await supabase.from(Tables.tags).update(ColorUpdate(color: c)).eq("id", value: tag.id).execute()
            if let idx = tags.firstIndex(where: { $0.id == tag.id }) { tags[idx].color = c }
        }
    }

    func deleteTag(_ tag: Tag) async throws {
        try await supabase.from(Tables.tags).delete().eq("id", value: tag.id).execute()
        tags.removeAll { $0.id == tag.id }
    }

    func updateCollaborator(_ collaborator: Profile, firstName: String, lastName: String, title: String, city: String, status: String) async throws {
        _ = try await supabase.auth.refreshSession()
        let session = try await supabase.auth.session
        let body: [String: String] = [
            "user_id": collaborator.id.uuidString,
            "first_name": firstName,
            "last_name": lastName,
            "title": title,
            "city": city,
            "status": status,
        ]
        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: URL(string: "\(SupabaseConstants.url)/functions/v1/update-collaborator")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConstants.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            struct UpdateResponse: Decodable { let error: String? }
            let decoded = try? JSONDecoder().decode(UpdateResponse.self, from: data)
            throw NSError(domain: "ProfileViewModel", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: decoded?.error ?? "Erreur mise à jour collaborateur"])
        }

        if let idx = collaborators.firstIndex(where: { $0.id == collaborator.id }) {
            var updated = collaborators[idx]
            updated.firstName = firstName.isEmpty ? nil : firstName
            updated.lastName = lastName.isEmpty ? nil : lastName
            updated.title = title.isEmpty ? nil : title
            updated.city = city.isEmpty ? nil : city
            updated.status = status
            collaborators[idx] = updated
        }
    }
}
