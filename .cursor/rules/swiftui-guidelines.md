# SwiftUI Guidelines

## View Structure (MANDATORY ORDER)
Every SwiftUI view follows this structure:

```swift
struct FeatureView: View {
    // 1. Environment
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // 2. State (owned by this view)
    @State private var viewModel = FeatureViewModel()
    @State private var showSheet = false

    // 3. Bindings (from parent)
    @Binding var selectedNote: Note?

    // 4. Constants / let properties
    let workspaceId: UUID

    // 5. Body
    var body: some View {
        // ...
    }

    // 6. Computed views (extracted subviews)
    private var headerSection: some View {
        // ...
    }

    // 7. Private methods
    private func handleTap() {
        // ...
    }
}
```

## View Size Rules
- **Max 200 lines per View file**
- If `body` exceeds 80 lines → extract subviews
- Extract into `private var sectionName: some View` first
- If still too large → create separate `SectionNameView.swift` file

## State Management
```swift
// ✅ CORRECT — iOS 17+ patterns
@Observable class MyViewModel { }          // ViewModel
@State private var vm = MyViewModel()      // View owns it
@Environment(AppState.self) var appState   // Shared state
@Binding var value: String                 // Parent owns it

// ❌ WRONG — Old patterns (do NOT use)
@ObservedObject var vm: MyViewModel        // Use @State instead
@StateObject var vm = MyViewModel()        // Use @State instead
@EnvironmentObject var appState            // Use @Environment
@Published var items: [Item]               // Use @Observable
```

## Async Operations
```swift
// ✅ CORRECT — Task in .task modifier
var body: some View {
    List(viewModel.notes) { note in
        NoteCardView(note: note)
    }
    .task {
        await viewModel.loadNotes(workspaceId: workspaceId)
    }
    .refreshable {
        await viewModel.loadNotes(workspaceId: workspaceId)
    }
}

// ❌ WRONG — Task in onAppear or init
.onAppear {
    Task { await viewModel.loadNotes() }  // Use .task instead
}
```

## Loading & Error States
Every screen that loads data MUST handle 3 states:

```swift
var body: some View {
    Group {
        if viewModel.isLoading && viewModel.notes.isEmpty {
            LoadingView()
        } else if let error = viewModel.errorMessage {
            ErrorBannerView(message: error, retryAction: {
                Task { await viewModel.loadNotes() }
            })
        } else if viewModel.notes.isEmpty {
            EmptyStateView(
                icon: "note.text",
                title: "Aucune note",
                subtitle: "Créez votre première note"
            )
        } else {
            notesList
        }
    }
}
```

## Lists & Performance
```swift
// ✅ CORRECT — LazyVStack for long lists
ScrollView {
    LazyVStack(spacing: 12) {
        ForEach(viewModel.notes) { note in
            NoteCardView(note: note)
        }
    }
}

// ✅ CORRECT — LazyVGrid for 2-column grid (Home)
ScrollView {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ], spacing: 12) {
        ForEach(viewModel.notes) { note in
            NoteCardView(note: note)
        }
    }
    .padding(.horizontal)
}

// ❌ WRONG — VStack for large datasets
VStack {
    ForEach(items) { ... }  // Loads ALL items at once
}
```

## Sheets & Navigation
```swift
// ✅ CORRECT — Sheet with .sheet modifier
.sheet(isPresented: $showCreateSubSpace) {
    CreateSubSpaceSheet(spaceId: space.id)
}

// ✅ CORRECT — Confirmation dialog for destructive actions
.confirmationDialog("Supprimer cette note ?", isPresented: $showDeleteConfirm) {
    Button("Supprimer", role: .destructive) { deleteNote() }
    Button("Annuler", role: .cancel) { }
}

// ❌ WRONG — Alert for complex choices (use confirmationDialog)
```

## Accessibility
```swift
// Always add accessibility labels to icons and images
Image(systemName: "plus")
    .accessibilityLabel("Créer une note")

// Group related elements
VStack {
    Text(note.title)
    Text(note.summary)
}
.accessibilityElement(children: .combine)
```

## Animations
```swift
// ✅ CORRECT — Subtle, purposeful animations
withAnimation(.easeInOut(duration: 0.2)) {
    viewModel.togglePin(noteId: note.id)
}

// ❌ WRONG — Flashy or slow animations
withAnimation(.spring(duration: 1.5)) { ... }
```

## Image Loading
```swift
// Use SDWebImageSwiftUI for remote images (avatars, Unsplash)
import SDWebImageSwiftUI

WebImage(url: URL(string: note.unsplashImageUrl ?? ""))
    .resizable()
    .placeholder { Color.gray.opacity(0.2) }
    .indicator(.activity)
    .transition(.fade(duration: 0.3))
    .scaledToFill()
    .frame(height: 120)
    .clipped()
```

## Colors
```swift
// ✅ CORRECT — Named colors from Assets.xcassets
Color("PrimaryBlue")
Color("AccentYellow")

// Or from ColorTokens.swift
extension Color {
    static let capsulePrimary = Color(hex: "#3B82F6")
    static let capsuleAccent = Color(hex: "#F59E0B")
    static let capsuleDark = Color(hex: "#1E293B")
    static let capsuleError = Color(hex: "#EF4444")
    static let capsuleSuccess = Color(hex: "#22C55E")
}

// ❌ WRONG — Inline hex or hardcoded colors
Color(red: 0.23, green: 0.51, blue: 0.97)
```

## Keyboard & Input
```swift
// Dismiss keyboard on tap outside
.onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }

// Submit on return key
TextField("Titre de la note...", text: $title)
    .submitLabel(.done)
    .onSubmit { focusNextField() }
```

## Safe Area & Layout
```swift
// ✅ CORRECT — Respect safe areas
.safeAreaInset(edge: .bottom) {
    saveButton
}

// ✅ CORRECT — Scroll behind tab bar
.scrollContentBackground(.hidden)
.ignoresSafeArea(.keyboard)
```
