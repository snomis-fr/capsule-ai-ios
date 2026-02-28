# Architecture — MVVM + Clean Layers

## Pattern: MVVM (Model-View-ViewModel)
Every feature follows this strict separation:

```
Model       → Data structure (Codable, Identifiable, Hashable)
ViewModel   → Business logic, state, Supabase calls (@Observable class)
View        → SwiftUI layout only. ZERO business logic.
```

## Folder Structure (MANDATORY)
```
CapsuleAI/
│
├── App/
│   ├── CapsuleAIApp.swift              → @main entry point
│   ├── AppState.swift                  → Global state: auth, workspace, current user
│   ├── ContentView.swift               → Root router: auth check → Login or TabView
│   └── TabRouter.swift                 → TabView with 5 tabs
│
├── Core/
│   ├── Auth/
│   │   ├── AuthManager.swift           → Google Sign-In + Supabase session
│   │   └── KeychainHelper.swift        → Token storage
│   ├── Network/
│   │   ├── SupabaseClient.swift        → Singleton Supabase client
│   │   ├── EdgeFunctionClient.swift    → Calls to Edge Functions (AI, images)
│   │   └── RealtimeManager.swift       → Supabase Realtime subscriptions
│   ├── Location/
│   │   └── LocationManager.swift       → CoreLocation wrapper
│   └── Storage/
│       └── StorageManager.swift        → Supabase Storage (upload/download)
│
├── Models/
│   ├── Profile.swift
│   ├── Workspace.swift
│   ├── Space.swift
│   ├── SubSpace.swift
│   ├── Note.swift
│   ├── NoteAction.swift
│   ├── Tag.swift
│   ├── NoteTag.swift
│   ├── Attachment.swift
│   ├── NoteType.swift
│   ├── NoteTypeAction.swift
│   ├── CollaboratorAccess.swift
│   └── CoachMessage.swift
│
├── Features/
│   ├── Login/
│   │   └── LoginView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   ├── NoteCardView.swift
│   │   ├── ImportantNoteCardView.swift
│   │   └── TagSectionView.swift
│   ├── Spaces/
│   │   ├── SpacesView.swift
│   │   ├── SpacesViewModel.swift
│   │   ├── SubSpaceListView.swift
│   │   ├── SubSpaceNotesView.swift
│   │   └── CreateSubSpaceSheet.swift
│   ├── NoteEditor/
│   │   ├── NoteEditorView.swift
│   │   ├── NoteEditorViewModel.swift
│   │   ├── TiptapWebView.swift         → WKWebView bridge
│   │   ├── SpacePickerView.swift
│   │   ├── TagPickerView.swift
│   │   ├── AttachmentPickerView.swift
│   │   ├── NoteTypePickerView.swift
│   │   └── AIAssistSheet.swift
│   ├── NoteReader/
│   │   ├── NoteReaderView.swift
│   │   ├── NoteReaderViewModel.swift
│   │   └── ActionPlanView.swift
│   ├── Search/
│   │   ├── SearchView.swift
│   │   ├── SearchViewModel.swift
│   │   └── FilterBarView.swift
│   ├── CoachIA/
│   │   ├── CoachIAView.swift
│   │   ├── CoachIAViewModel.swift
│   │   ├── ChatBubbleView.swift
│   │   └── SuggestionChipView.swift
│   └── Profile/
│       ├── ProfileView.swift
│       ├── ProfileViewModel.swift
│       ├── EditProfileSheet.swift
│       ├── SpaceManagerView.swift
│       ├── CollaboratorListView.swift
│       ├── CollaboratorDetailView.swift
│       ├── TagManagerView.swift
│       ├── NoteTypeManagerView.swift
│       ├── NotificationsSettingView.swift
│       └── SyncSettingView.swift
│
├── Components/                         → Reusable UI components
│   ├── AvatarView.swift
│   ├── BadgeView.swift
│   ├── SpaceBadgeView.swift
│   ├── TagBadgeView.swift
│   ├── StatusBadgeView.swift
│   ├── SearchBarView.swift
│   ├── LoadingView.swift
│   ├── EmptyStateView.swift
│   └── ErrorBannerView.swift
│
├── Extensions/
│   ├── Color+Hex.swift
│   ├── Date+Relative.swift
│   ├── String+Extensions.swift
│   └── View+Modifiers.swift
│
├── Resources/
│   ├── Assets.xcassets                 → Colors, icons, app icon
│   ├── tiptap-editor.html              → Tiptap HTML for WKWebView
│   ├── tiptap-editor.js                → Tiptap JS config
│   └── Localizable.strings             → All French strings
│
├── Constants/
│   ├── AppConstants.swift              → Limits (30 notes, 3 tags, 7 collabs, file sizes)
│   ├── SupabaseConstants.swift         → URL, anon key, bucket names, table names
│   └── ColorTokens.swift              → Named colors matching design
│
└── Config/
    ├── Info.plist
    ├── GoogleService-Info.plist        → Google OAuth config
    └── Entitlements.plist
```

## Dependency Injection
Use SwiftUI's `@Environment` for shared services:

```swift
// In CapsuleAIApp.swift
@main
struct CapsuleAIApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

// In any view
struct HomeView: View {
    @Environment(AppState.self) private var appState
}
```

## ViewModel Pattern (iOS 17+)
```swift
@Observable
final class HomeViewModel {
    // MARK: - State
    var notes: [Note] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies
    private let supabase = SupabaseClient.shared

    // MARK: - Actions
    func loadNotes(workspaceId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            notes = try await supabase.from("notes")
                .select()
                .eq("workspace_id", value: workspaceId)
                .order("updated_at", ascending: false)
                .limit(30)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## Navigation Pattern
Use NavigationStack with typed paths:

```swift
// Define routes
enum AppRoute: Hashable {
    case noteReader(noteId: UUID)
    case noteEditor(noteId: UUID?)
    case subSpaceNotes(subSpaceId: UUID)
    case collaboratorDetail(userId: UUID)
    case profile
}

// In ContentView or TabRouter
NavigationStack(path: $path) {
    HomeView()
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .noteReader(let id): NoteReaderView(noteId: id)
            case .noteEditor(let id): NoteEditorView(noteId: id)
            // ...
            }
        }
}
```

## Error Handling Pattern
Never crash. Always show user-friendly errors:

```swift
enum CapsuleError: LocalizedError {
    case networkUnavailable
    case unauthorized
    case notFound
    case maxTagsReached
    case maxCollaboratorsReached
    case fileTooLarge(maxMB: Int)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .maxTagsReached: return "Maximum 3 tags par note"
        case .maxCollaboratorsReached: return "Maximum 7 collaborateurs"
        case .fileTooLarge(let max): return "Fichier trop volumineux (max \(max) Mo)"
        // ...
        }
    }
}
```
