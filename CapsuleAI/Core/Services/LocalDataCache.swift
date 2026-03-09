//
//  LocalDataCache.swift
//  CapsuleAI
//
//  Persiste les données workspace localement pour conservation après déconnexion
//  et restauration rapide au retour.
//

import Foundation

/// Cache local des données workspace (profil, collaborateurs, espaces, tags).
/// Les données sont conservées après déconnexion et restaurées au login.
final class LocalDataCache {

    static let shared = LocalDataCache()
    private let defaults = UserDefaults.standard
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    private func key(for userId: UUID) -> String {
        "workspace_cache_\(userId.uuidString)"
    }

    /// Sauvegarde le snapshot actuel des données pour l'utilisateur.
    func save(
        userId: UUID,
        profile: Profile,
        workspaceId: UUID?,
        spaces: [Space],
        subSpacesBySpace: [UUID: [SubSpace]],
        collaborators: [Profile],
        tags: [Tag]
    ) {
        let snapshot = CachedWorkspaceSnapshot(
            profile: profile,
            workspaceId: workspaceId,
            spaces: spaces,
            subSpacesBySpace: subSpacesBySpace,
            collaborators: collaborators,
            tags: tags,
            savedAt: Date()
        )
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key(for: userId))
    }

    /// Charge le cache pour l'utilisateur, ou nil si absent ou corrompu.
    func load(userId: UUID) -> CachedWorkspaceSnapshot? {
        let k = key(for: userId)
        guard let data = defaults.data(forKey: k) else { return nil }
        do {
            return try decoder.decode(CachedWorkspaceSnapshot.self, from: data)
        } catch {
            defaults.removeObject(forKey: k) // supprimer un cache corrompu
            return nil
        }
    }
}

/// Snapshot des données workspace pour persistance.
struct CachedWorkspaceSnapshot: Codable {
    let profile: Profile
    let workspaceId: UUID?
    let spaces: [Space]
    /// Clés = spaceId.uuidString (JSON n'accepte pas UUID comme clé)
    let subSpacesBySpaceKeys: [String]
    let subSpacesBySpaceValues: [[SubSpace]]
    let collaborators: [Profile]
    let tags: [Tag]
    let savedAt: Date

    init(profile: Profile, workspaceId: UUID?, spaces: [Space], subSpacesBySpace: [UUID: [SubSpace]], collaborators: [Profile], tags: [Tag], savedAt: Date) {
        self.profile = profile
        self.workspaceId = workspaceId
        self.spaces = spaces
        let sorted = subSpacesBySpace.sorted { $0.key.uuidString < $1.key.uuidString }
        self.subSpacesBySpaceKeys = sorted.map { $0.key.uuidString }
        self.subSpacesBySpaceValues = sorted.map { $0.value }
        self.collaborators = collaborators
        self.tags = tags
        self.savedAt = savedAt
    }

    var subSpacesBySpace: [UUID: [SubSpace]] {
        var result: [UUID: [SubSpace]] = [:]
        for (i, key) in subSpacesBySpaceKeys.enumerated() {
            guard let uuid = UUID(uuidString: key), i < subSpacesBySpaceValues.count else { continue }
            result[uuid] = subSpacesBySpaceValues[i]
        }
        return result
    }

    enum CodingKeys: String, CodingKey {
        case profile
        case workspaceId = "workspace_id"
        case spaces
        case subSpacesBySpaceKeys = "sub_spaces_keys"
        case subSpacesBySpaceValues = "sub_spaces_values"
        case collaborators
        case tags
        case savedAt = "saved_at"
    }
}
