# Naming Conventions

## Files
| Type | Pattern | Example |
|------|---------|---------|
| View | `{Feature}View.swift` | `HomeView.swift` |
| ViewModel | `{Feature}ViewModel.swift` | `HomeViewModel.swift` |
| Model | `{Entity}.swift` | `Note.swift` |
| Component | `{Component}View.swift` | `AvatarView.swift` |
| Extension | `{Type}+{Purpose}.swift` | `Color+Hex.swift` |
| Manager/Service | `{Service}Manager.swift` | `AuthManager.swift` |
| Constants | `{Domain}Constants.swift` | `AppConstants.swift` |
| Sheet/Modal | `{Action}{Entity}Sheet.swift` | `CreateSubSpaceSheet.swift` |

## Variables & Properties
```swift
// Models — Use camelCase matching Supabase column names via CodingKeys
struct Note: Codable, Identifiable {
    let id: UUID
    let title: String
    let aiSummary: String?          // maps to "ai_summary"
    let isPrivate: Bool             // maps to "is_private"
    let createdBy: UUID             // maps to "created_by"
    let updatedAt: Date             // maps to "updated_at"
    let subSpaceId: UUID            // maps to "sub_space_id"

    enum CodingKeys: String, CodingKey {
        case id, title
        case aiSummary = "ai_summary"
        case isPrivate = "is_private"
        case createdBy = "created_by"
        case updatedAt = "updated_at"
        case subSpaceId = "sub_space_id"
    }
}

// Booleans — Always prefix with is/has/can/should
var isLoading: Bool
var hasUnsavedChanges: Bool
var canEdit: Bool
var shouldShowBanner: Bool

// Collections — Always plural nouns
var notes: [Note]
var tags: [Tag]
var selectedTagIds: Set<UUID>

// Optionals — Never force unwrap (!)
var errorMessage: String?           // ✅
let imageUrl: URL? = URL(string: s) // ✅
let url: URL = URL(string: s)!      // ❌ NEVER
```

## Functions
```swift
// Actions — verb + object
func loadNotes() async
func saveNote() async
func deleteNote(id: UUID) async
func togglePin(noteId: UUID)
func fetchUnsplashImage(for title: String) async

// Computed values — noun or adjective
var isValid: Bool { !title.isEmpty && subSpaceId != nil }
var formattedDate: String { ... }
var filteredNotes: [Note] { ... }

// Event handlers — handle + event
func handleSaveTapped()
func handleTagSelected(_ tag: Tag)
func handleSwipeToDelete(_ note: Note)
```

## SwiftUI Views
```swift
// Main view body sections — private var, descriptive name
private var headerSection: some View { ... }
private var noteGrid: some View { ... }
private var tagSection: some View { ... }
private var emptyState: some View { ... }

// Reusable subviews — separate struct
struct NoteCardView: View { ... }     // Not noteCard or NoteCard
struct TagBadgeView: View { ... }
struct StatusBadgeView: View { ... }
```

## Supabase Table & Column References
Always use string constants, never inline strings:

```swift
// In SupabaseConstants.swift
enum Tables {
    static let profiles = "profiles"
    static let notes = "notes"
    static let spaces = "spaces"
    static let subSpaces = "sub_spaces"
    static let tags = "tags"
    static let noteTags = "note_tags"
    static let noteActions = "note_actions"
    static let attachments = "attachments"
    static let noteTypes = "note_types"
    static let collaboratorAccess = "collaborator_access"
    static let coachConversations = "coach_conversations"
}

enum Buckets {
    static let avatars = "avatars"
    static let attachments = "attachments"
    static let noteImages = "note-images"
}
```

## Localization Keys
```swift
// Pattern: feature.element.state
"home.title" = "Notes";
"home.search.placeholder" = "Rechercher dans toutes les notes...";
"spaces.title" = "Mes espaces";
"spaces.create.title" = "Créer une sous-catégorie";
"editor.save" = "Enregistrer la note";
"editor.tag.limit" = "Maximum 3 tags par note";
"profile.collaborators.limit" = "Maximum 7 collaborateurs";
"coach.greeting" = "Bonjour %@ 👋";
"error.network" = "Connexion internet indisponible";
"error.generic" = "Une erreur est survenue";
```

## Git Commits
```
feat: add note creation screen with Tiptap editor
fix: resolve crash when deleting last sub-space
refactor: extract NoteCardView from HomeView
style: align tag badges with design specs
chore: update Supabase SDK to 2.1.0
docs: add testing strategy for dual-device setup
```

## Git Branches
```
main                    → production-ready
develop                 → integration branch
feature/home-screen     → new feature
feature/coach-ia        → new feature
fix/note-delete-crash   → bug fix
refactor/auth-flow      → code improvement
```
