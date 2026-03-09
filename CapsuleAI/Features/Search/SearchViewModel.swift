//
//  SearchViewModel.swift
//  CapsuleAI
//

import Foundation
import Observation
import Supabase

struct SearchFilters {
    var spaceId: UUID?
    var tagId: UUID?
    var noteType: String?
    var dateFilter: DateFilter = .none
    var customDate: Date?
    var isPrivate: Bool?
}

enum DateFilter: String, CaseIterable {
    case none = "Toutes"
    case today = "Aujourd'hui"
    case week = "Cette semaine"
    case month = "Ce mois"
    case custom = "Date..."
}

struct SearchResultItem: Identifiable {
    var id: UUID { note.id }
    let note: Note
    let spaceName: String
    let spaceColor: String
    let spaceEmoji: String
    let subSpaceName: String
    let tags: [Tag]
    let creatorProfile: Profile?
}

@Observable
final class SearchViewModel {
    var searchQuery = "" { didSet { scheduleSearch() } }
    var filters = SearchFilters()
    var results: [SearchResultItem] = []
    var spaces: [Space] = []
    var tags: [Tag] = []
    var noteTypes: [NoteType] = []
    var isLoading = false
    var errorMessage: String?
    var hasSearched = false
    var isInitialState: Bool { !hasSearched && results.isEmpty }

    private let supabase = SupabaseManager.shared.client
    private var searchTask: Task<Void, Never>?
    private var workspaceId: UUID?
    private var subSpaceToSpace: [UUID: (Space, SubSpace)] = [:]
    private let debounceNs: UInt64 = 300_000_000

    /// Non classé toujours en dernier (règle immuable)
    var orderedSpaces: [Space] {
        spaces.sortedWithDefaultLast()
    }

    func loadFilters() async {
        guard let userId = (try? await supabase.auth.session)?.user.id else { return }
        do {
            let p: Profile = try await supabase.from(Tables.profiles).select().eq("id", value: userId).single().execute().value
            guard let wsId = p.workspaceId else { return }
            workspaceId = wsId
            try await loadSpaces(wsId)
            try await loadTags(wsId)
            try await loadNoteTypes(wsId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadInitialOrSearch() async {
        hasSearched = true
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        if q.count < 2 {
            await loadRecentNotes()
        } else {
            await performSearch(query: q)
        }
    }

    func loadRecentNotes() async {
        guard let wsId = workspaceId else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let notes: [Note] = try await buildAndExecute(workspaceId: wsId, searchPattern: nil, limit: AppLimits.maxNotesSearchRecent)
            results = await enrichResults(notes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retry() async {
        errorMessage = nil
        await loadInitialOrSearch()
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: debounceNs)
            guard !Task.isCancelled else { return }
            await loadInitialOrSearch()
        }
    }

    private func loadSpaces(_ wsId: UUID) async throws {
        let sp: [Space] = try await supabase.from(Tables.spaces).select().eq("workspace_id", value: wsId).order("sort_order").execute().value
        spaces = sp
        for s in sp {
            let subs: [SubSpace] = try await supabase.from(Tables.subSpaces).select().eq("space_id", value: s.id).order("sort_order").execute().value
            for sub in subs { subSpaceToSpace[sub.id] = (s, sub) }
        }
    }

    private func loadTags(_ wsId: UUID) async throws {
        tags = try await supabase.from(Tables.tags).select().eq("workspace_id", value: wsId).order("sort_order").execute().value
    }

    private func loadNoteTypes(_ wsId: UUID) async throws {
        noteTypes = try await supabase.from(Tables.noteTypes).select().eq("workspace_id", value: wsId).order("sort_order").execute().value
    }

    private func performSearch(query: String) async {
        guard let wsId = workspaceId else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let pattern = "%\(query)%"
            let notes: [Note] = try await buildAndExecute(workspaceId: wsId, searchPattern: pattern, limit: 100)
            results = await enrichResults(notes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildAndExecute(workspaceId: UUID, searchPattern: String?, limit: Int) async throws -> [Note] {
        var noteIdsForTag: [UUID]?
        if let tid = filters.tagId {
            struct Row: Decodable { let note_id: UUID }
            let rows: [Row] = try await supabase.from(Tables.noteTags).select("note_id").eq("tag_id", value: tid).execute().value
            noteIdsForTag = rows.map(\.note_id)
            if noteIdsForTag?.isEmpty ?? true { return [] }
        }
        var q = supabase.from(Tables.notes).select("id,workspace_id,sub_space_id,title,content_plain,ai_summary,note_type,is_private,is_pinned,word_count,location_city,location_country,location_country_code,unsplash_image_url,created_by,last_modified_by,moved_to_trash_at,created_at,updated_at").eq("workspace_id", value: workspaceId).is("moved_to_trash_at", value: nil as Bool?)
        if let subIds = filters.spaceId.flatMap({ sid in subSpaceToSpace.filter { $0.value.0.id == sid }.map(\.key) }), !subIds.isEmpty {
            q = q.in("sub_space_id", values: subIds)
        }
        if let ids = noteIdsForTag { q = q.in("id", values: ids) }
        if let nt = filters.noteType { q = q.eq("note_type", value: nt) }
        if let ip = filters.isPrivate { q = q.eq("is_private", value: ip) }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        switch filters.dateFilter {
        case .today:
            let start = Calendar.current.startOfDay(for: Date())
            q = q.gte("updated_at", value: fmt.string(from: start))
        case .week:
            let start = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            q = q.gte("updated_at", value: fmt.string(from: start))
        case .month:
            let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
            q = q.gte("updated_at", value: fmt.string(from: start))
        case .custom:
            if let d = filters.customDate {
                let start = Calendar.current.startOfDay(for: d)
                let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
                q = q.gte("updated_at", value: fmt.string(from: start)).lt("updated_at", value: fmt.string(from: end))
            }
        case .none: break
        }
        if let p = searchPattern {
            q = q.or("title.ilike.\(p),content_plain.ilike.\(p)")
        }
        return try await q.order("updated_at", ascending: false).limit(limit).execute().value
    }

    private func enrichResults(_ notes: [Note]) async -> [SearchResultItem] {
        guard !notes.isEmpty else { return [] }
        var profiles: [UUID: Profile] = [:]
        for uid in Set(notes.map(\.createdBy)) {
            if let p: Profile = try? await supabase.from(Tables.profiles).select().eq("id", value: uid).single().execute().value {
                profiles[uid] = p
            }
        }
        var noteTags: [UUID: [Tag]] = [:]
        struct NT: Decodable { let note_id: UUID; let tag_id: UUID }
        let ntRows: [NT] = (try? await supabase.from(Tables.noteTags).select("note_id,tag_id").in("note_id", values: notes.map(\.id)).execute().value) ?? []
        let tagIds = Set(ntRows.map(\.tag_id))
        var tagsById: [UUID: Tag] = [:]
        if !tagIds.isEmpty {
            let allTags: [Tag] = (try? await supabase.from(Tables.tags).select().in("id", values: Array(tagIds)).execute().value) ?? []
            for t in allTags { tagsById[t.id] = t }
        }
        for r in ntRows { if let tag = tagsById[r.tag_id] { noteTags[r.note_id, default: []].append(tag) } }
        return notes.map { note in
            let spaceName: String
            let spaceColor: String
            let spaceEmoji: String
            let subSpaceName: String
            if let (sp, sub) = subSpaceToSpace[note.subSpaceId] {
                spaceName = sp.name; spaceColor = sp.color; spaceEmoji = sp.emoji; subSpaceName = sub.name
            } else {
                spaceName = "?"; spaceColor = "#3B82F6"; spaceEmoji = "📂"; subSpaceName = "?"
            }
            return SearchResultItem(note: note, spaceName: spaceName, spaceColor: spaceColor, spaceEmoji: spaceEmoji, subSpaceName: subSpaceName, tags: noteTags[note.id] ?? [], creatorProfile: profiles[note.createdBy])
        }
    }
}
