# CAPSULE AI — Cursor Rules (Master)

You are building **Capsule AI**, a native iOS app in SwiftUI targeting iOS 17+.
Collaborative note-taking app with AI features for executives and their teams (max 7 collaborators).

## Read These Files BEFORE Writing Any Code
1. `.cursor/rules/architecture.md` — App architecture, patterns, folder structure
2. `.cursor/rules/swiftui-guidelines.md` — SwiftUI coding standards
3. `.cursor/rules/naming-conventions.md` — Naming rules for files, variables, functions
4. `.cursor/rules/supabase-patterns.md` — Backend patterns, queries, auth, realtime
5. `.cursor/rules/code-quality.md` — Quality checklist before every commit
6. `docs/SPEC-FUNCTIONAL.md` — WHAT to build (screens, features, business rules)
7. `docs/SPEC-TECHNICAL.md` — HOW to build it (stack, DB schema, APIs, Edge Functions)

## Golden Rules
- **SwiftUI only** — no UIKit unless strictly necessary (WKWebView for Tiptap is the only exception)
- **iOS 17+ minimum** — use @Observable, NavigationStack, .searchable, .sensoryFeedback
- **French UI** — all user-facing text in French via Localizable.strings. Code and comments in English
- **Never hardcode** — colors, strings, URLs, limits → Constants.swift or Localizable
- **Small files** — max 200 lines per file. If longer → split into subviews or extensions
- **One file = one responsibility** — never mix View + ViewModel + Model in the same file
- **Test on 2 physical devices** — iPhone Manager + iPhone Collaborator

## When Asked to Create a New Feature
1. Read the relevant section in SPEC-FUNCTIONAL.md
2. Read SPEC-TECHNICAL.md for the database tables involved
3. Create Model → ViewModel → View (in that order)
4. Follow naming conventions from naming-conventions.md
5. Run the code review agent checklist from code-quality.md before delivering

## When Asked to Fix a Bug
1. Reproduce the issue mentally by reading the code
2. Identify the root cause (not just the symptom)
3. Fix with minimal changes
4. Verify no other feature is affected
5. Add a comment explaining the fix if non-obvious
