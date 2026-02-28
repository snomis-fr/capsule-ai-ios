# Capsule AI 💊

Application iOS native de gestion de notes collaboratives augmentée par l'IA.
Destinée aux dirigeants et à leurs équipes rapprochées (max 7 collaborateurs).

## Stack
- **Frontend** : SwiftUI (iOS 17+)
- **Backend** : Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions)
- **IA** : Claude API (Anthropic) — résumés, structuration, Coach IA
- **Images** : Unsplash API / Pexels API
- **Auth** : Google Sign-In

## Structure du projet
```
.cursor/rules/          ← Règles Cursor (architecture, SwiftUI, naming, Supabase, quality)
docs/                   ← Spécifications (fonctionnel, technique, testing, checklist)
CapsuleAI/              ← Code source iOS (créé via Xcode)
supabase/functions/     ← Edge Functions (generate-summary, ai-assist, coach-ia, fetch-unsplash)
```

## Développement
1. Lire `docs/CHECKLIST-SETUP.md` pour la mise en place
2. Ouvrir le projet dans **Cursor** pour le développement
3. Utiliser **Xcode** pour build, signing et TestFlight
4. Tester sur 2 iPhones : Manager + Collaborateur

## Branches
- `main` — production-ready
- `develop` — intégration
- `feature/*` — nouvelles fonctionnalités
- `fix/*` — corrections de bugs
