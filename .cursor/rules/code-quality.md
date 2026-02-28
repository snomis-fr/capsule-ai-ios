# Code Quality & Review Agent

## CODE REVIEW AGENT

When asked to review code, or before delivering any feature, act as a **senior iOS code reviewer**.
Run EVERY item in this checklist. Report issues as ❌ FAIL with the fix. Report passes as ✅.

### Checklist (run on every file)

**ARCHITECTURE**
- [ ] File is under 200 lines
- [ ] One responsibility per file (no View + ViewModel in same file)
- [ ] Follows MVVM: View has ZERO business logic
- [ ] ViewModel is @Observable class, not ObservableObject
- [ ] No force unwraps (!) anywhere
- [ ] No hardcoded strings, colors, or URLs

**SWIFTUI**
- [ ] Uses @State (not @StateObject) for ViewModels
- [ ] Uses @Environment (not @EnvironmentObject)
- [ ] Uses .task (not .onAppear + Task {})
- [ ] Loading / Error / Empty states are handled
- [ ] LazyVStack or LazyVGrid for lists (not VStack)
- [ ] No inline styles — colors from ColorTokens
- [ ] Accessibility labels on icons and images

**SUPABASE**
- [ ] All queries use Tables.xxx constants (no inline table names)
- [ ] All queries are in ViewModel (never in View)
- [ ] Error handling with do/catch (no try?)
- [ ] Realtime subscription cleaned up on disappear
- [ ] No sensitive data logged (tokens, keys)

**PERFORMANCE**
- [ ] Images use SDWebImageSwiftUI with placeholder
- [ ] No unnecessary re-renders (check @State usage)
- [ ] Heavy operations are async (never blocking main thread)
- [ ] Lists use .id() for stable identity

**SECURITY**
- [ ] API keys are in environment variables (not in code)
- [ ] No user data in print/debugPrint statements
- [ ] Auth token stored in Keychain (not UserDefaults)
- [ ] RLS relied upon for access control (no client-side filtering for security)

**NAMING**
- [ ] File name matches struct/class name
- [ ] Bool variables prefixed with is/has/can/should
- [ ] Functions named verb + object
- [ ] CodingKeys map camelCase → snake_case correctly

**BUSINESS RULES**
- [ ] Max 3 tags per note enforced
- [ ] Max 7 collaborators enforced
- [ ] File size limits enforced (4 Mo photos, 20 Mo docs)
- [ ] Note requires space + sub-space + title to save
- [ ] Private notes visible only to creator
- [ ] "Non classées" space cannot be deleted
- [ ] Space deletion blocked if sub-spaces exist
- [ ] Sub-space deletion migrates notes to "Non classées"

### Review Output Format
```
## Code Review: {FileName}

### Summary
{1-2 sentence overview}

### Issues Found
❌ Line 42: Force unwrap on optional URL
   → Fix: Use guard let url = URL(string: s) else { return }

❌ Line 78: Business logic in View (filtering notes)
   → Fix: Move to ViewModel as computed property

### Passed Checks
✅ Architecture: MVVM respected
✅ Naming: Consistent conventions
✅ Error handling: All states covered

### Suggestions (non-blocking)
💡 Consider extracting headerSection into a separate component
💡 Add .sensoryFeedback(.impact, trigger: isToggled) on pin button
```

---

## QUALITY RULES (Always Apply)

### Never Do
```swift
// ❌ Force unwrap
let url = URL(string: urlString)!

// ❌ try? silencing errors
let notes = try? await loadNotes()

// ❌ Print in production
print("Debug: \(note)")

// ❌ Massive switch in View body
var body: some View {
    switch state {
        case .a: /* 50 lines */
        case .b: /* 50 lines */
        case .c: /* 50 lines */
    }
}

// ❌ Nested closures > 2 levels deep
.onReceive(publisher) { value in
    Task {
        await something { result in
            // Too deep
        }
    }
}

// ❌ Magic numbers
.padding(17.5)
.frame(height: 347)
```

### Always Do
```swift
// ✅ Safe unwrap
guard let url = URL(string: urlString) else { return }

// ✅ Explicit error handling
do {
    notes = try await loadNotes()
} catch {
    errorMessage = error.localizedDescription
}

// ✅ Logger for debug (removed in production)
import os
private let logger = Logger(subsystem: "com.capsule.ai", category: "HomeVM")
logger.debug("Loaded \(notes.count) notes")

// ✅ Extract view sections
var body: some View {
    ScrollView {
        headerSection
        noteGrid
        tagSection
    }
}

// ✅ Named constants
.padding(.horizontal, Spacing.medium)   // 16
.frame(height: CardHeight.standard)     // 120
```

### Constants Pattern
```swift
// In AppConstants.swift
enum AppLimits {
    static let maxNotesHome = 30
    static let maxTagsPerNote = 3
    static let maxCollaborators = 7
    static let maxPhotoSizeMB = 4
    static let maxFileSizeMB = 20
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let pill: CGFloat = 100
}
```

---

## PRE-COMMIT CHECKLIST (Before Every Git Push)

1. ☐ Build succeeds (⌘B) — zero warnings
2. ☐ No compiler warnings
3. ☐ No force unwraps
4. ☐ No hardcoded strings
5. ☐ All new strings added to Localizable.strings
6. ☐ Test on iPhone Manager (your device)
7. ☐ Test on iPhone Collaborator (second device) if feature involves permissions
8. ☐ UI looks correct in Light mode
9. ☐ UI looks correct in Dark mode (if supported)
10. ☐ Keyboard doesn't cover input fields
11. ☐ Pull-to-refresh works on lists
12. ☐ Loading state shows during network calls
13. ☐ Error state shows meaningful French message
14. ☐ Empty state shows when no data
