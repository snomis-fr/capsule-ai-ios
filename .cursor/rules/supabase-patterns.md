# Supabase Patterns

## Client Singleton
```swift
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConstants.url)!,
            supabaseKey: SupabaseConstants.anonKey
        )
    }
}

// Usage everywhere:
let supabase = SupabaseManager.shared.client
```

## Authentication Flow
```swift
// 1. Google Sign-In → get idToken
// 2. Send to Supabase
func signInWithGoogle(idToken: String) async throws {
    try await supabase.auth.signInWithIdToken(
        credentials: .init(provider: .google, idToken: idToken)
    )
}

// 3. Check session on app launch
func checkSession() async -> Bool {
    do {
        let session = try await supabase.auth.session
        return session != nil
    } catch {
        return false
    }
}

// 4. Sign out
func signOut() async throws {
    try await supabase.auth.signOut()
}

// 5. Get current user ID (used in all queries)
var currentUserId: UUID? {
    try? supabase.auth.session?.user.id
}
```

## Query Patterns

### SELECT with relations
```swift
// Load notes with tags and actions
let notes: [Note] = try await supabase
    .from(Tables.notes)
    .select("""
        *,
        note_tags(tag_id, tags(id, name, color)),
        note_actions(id, label, is_checked, sort_order),
        profiles!notes_created_by_fkey(first_name, avatar_url),
        profiles!notes_last_modified_by_fkey(first_name, avatar_url)
    """)
    .eq("workspace_id", value: workspaceId)
    .eq("is_private", value: false)
    .order("updated_at", ascending: false)
    .limit(30)
    .execute()
    .value
```

### INSERT
```swift
// Create a note
let newNote = NoteInsert(
    workspaceId: workspaceId,
    subSpaceId: selectedSubSpace.id,
    title: title,
    content: tiptapContent,
    contentPlain: plainText,
    noteType: selectedType?.rawValue ?? "none",
    isPrivate: isPrivate,
    isPinned: isPinned,
    wordCount: wordCount,
    locationCity: location?.city,
    locationCountry: location?.country,
    locationCountryCode: location?.countryCode,
    createdBy: currentUserId,
    lastModifiedBy: currentUserId
)

let inserted: Note = try await supabase
    .from(Tables.notes)
    .insert(newNote)
    .select()
    .single()
    .execute()
    .value
```

### UPDATE
```swift
// Update a note
try await supabase
    .from(Tables.notes)
    .update([
        "title": title,
        "content": content,
        "content_plain": plainText,
        "last_modified_by": currentUserId,
        "word_count": wordCount
    ])
    .eq("id", value: noteId)
    .execute()
```

### DELETE
```swift
// Delete a note
try await supabase
    .from(Tables.notes)
    .delete()
    .eq("id", value: noteId)
    .execute()
```

### FULL-TEXT SEARCH
```swift
// Search notes
let results: [Note] = try await supabase
    .from(Tables.notes)
    .select()
    .textSearch("content_plain", query: searchQuery, config: "french")
    .eq("workspace_id", value: workspaceId)
    .order("updated_at", ascending: false)
    .execute()
    .value
```

### FILTERED QUERIES (Search screen)
```swift
// Filter by country + space
var query = supabase.from(Tables.notes).select()
    .eq("workspace_id", value: workspaceId)

if let country = selectedCountry {
    query = query.eq("location_country_code", value: country)
}
if let spaceId = selectedSpaceId {
    query = query.in("sub_space_id",
        values: subSpaceIds(for: spaceId)
    )
}

let results: [Note] = try await query
    .order("updated_at", ascending: false)
    .execute()
    .value
```

## Realtime Subscriptions
```swift
// In RealtimeManager.swift
func subscribeToNotes(workspaceId: UUID, onChange: @escaping () -> Void) {
    let channel = supabase.channel("notes-\(workspaceId)")

    channel.on("postgres_changes", filter: .init(
        event: .all,
        schema: "public",
        table: Tables.notes,
        filter: "workspace_id=eq.\(workspaceId)"
    )) { _ in
        onChange()
    }

    channel.subscribe()
}

// In ViewModel — reload on remote change
func startListening() {
    RealtimeManager.shared.subscribeToNotes(workspaceId: workspaceId) { [weak self] in
        Task { await self?.loadNotes() }
    }
}
```

## Storage (File Upload/Download)
```swift
// Upload avatar
func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
    let path = "\(userId)/avatar.jpg"
    try await supabase.storage
        .from(Buckets.avatars)
        .upload(path: path, file: imageData, options: .init(
            contentType: "image/jpeg",
            upsert: true
        ))
    return supabase.storage.from(Buckets.avatars).getPublicURL(path: path).absoluteString
}

// Upload attachment
func uploadAttachment(workspaceId: UUID, noteId: UUID, fileName: String, data: Data, mimeType: String) async throws -> String {
    let path = "\(workspaceId)/\(noteId)/\(fileName)"
    try await supabase.storage
        .from(Buckets.attachments)
        .upload(path: path, file: data, options: .init(contentType: mimeType))
    return path
}

// Download attachment
func downloadAttachment(path: String) async throws -> Data {
    try await supabase.storage
        .from(Buckets.attachments)
        .download(path: path)
}
```

## Edge Function Calls
```swift
// In EdgeFunctionClient.swift
func callEdgeFunction<T: Decodable>(name: String, body: Encodable) async throws -> T {
    let response = try await supabase.functions.invoke(
        name,
        options: .init(body: body)
    )
    return try JSONDecoder().decode(T.self, from: response.data)
}

// Usage: Generate AI summary
struct SummaryRequest: Encodable {
    let noteId: UUID
    let title: String
    let content: String
}
struct SummaryResponse: Decodable {
    let summary: String
}

let response: SummaryResponse = try await EdgeFunctionClient.shared
    .callEdgeFunction(name: "generate-summary", body: SummaryRequest(
        noteId: note.id,
        title: note.title,
        content: note.contentPlain ?? ""
    ))
```

## Error Handling for Supabase
```swift
// Always wrap Supabase calls in do/catch
func loadNotes() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
        notes = try await supabase.from(Tables.notes)
            .select()
            .eq("workspace_id", value: workspaceId)
            .execute()
            .value
    } catch let error as PostgrestError {
        errorMessage = "Erreur base de données: \(error.message)"
    } catch let error as URLError where error.code == .notConnectedToInternet {
        errorMessage = "Pas de connexion internet"
    } catch {
        errorMessage = "Une erreur est survenue"
    }
}
```

## RLS Awareness
Remember: Supabase RLS filters data automatically based on the authenticated user.
- A collaborator will only see notes in sub-spaces they have access to
- Private notes are only visible to their creator
- The manager sees everything except collaborator private spaces
- **Never rely on client-side filtering for security** — RLS handles it
