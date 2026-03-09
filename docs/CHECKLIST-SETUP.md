# CHECKLIST DE SETUP — Tout ce qu'il faut avant de coder

## ✅ CE QUE TU AS DÉJÀ
- [x] Mac avec Xcode
- [x] 2 iPhones pour test (Manager + Collaborateur)
- [x] Compte Vercel
- [x] Cahier des charges fonctionnel (SPEC-FUNCTIONAL.md)
- [x] Architecture technique (SPEC-TECHNICAL.md)

---

## 🔧 COMPTES À CRÉER / CONFIGURER

### 1. Apple Developer Program (OBLIGATOIRE pour TestFlight)
- [ ] **Compte Apple Developer** (99$/an) → https://developer.apple.com/programs/
- [ ] Créer un **App ID** : `com.ippon.capsule` (ou `com.capsuleai.app`)
- [ ] Créer un **Provisioning Profile** (Development + Distribution)
- [ ] Activer les capabilities : **Push Notifications**, **Sign in with Apple** (optionnel)
- ⏱ Délai : 24-48h pour validation du compte

### 2. Supabase
- [ ] Créer un projet sur https://supabase.com (plan Free pour démarrer)
- [ ] Noter le **Project URL** : `https://xxxxx.supabase.co`
- [ ] Noter la **anon key** (publique, utilisée côté client)
- [ ] Noter la **service_role key** (privée, utilisée uniquement dans les Edge Functions)
- [ ] Activer **Google Auth** dans Authentication > Providers > Google

### 3. Google Cloud Console (pour Google Sign-In)
- [ ] Créer un projet sur https://console.cloud.google.com
- [ ] Activer l'API **Google Identity Services**
- [ ] Créer un **OAuth 2.0 Client ID** type "iOS"
  - Bundle ID : `com.ippon.capsule`
  - Télécharger le `GoogleService-Info.plist`
- [ ] Créer un **OAuth 2.0 Client ID** type "Web" (requis par Supabase)
  - Copier le Client ID et Client Secret dans Supabase > Auth > Google
- [ ] Configurer l'écran de consentement OAuth (nom app, logo, email support)

### 4. Anthropic (Claude API)
- [ ] Compte API sur https://console.anthropic.com
- [ ] Créer une **API Key** (`sk-ant-...`)
- [ ] Ajouter du crédit (pay-as-you-go, commencer avec 20$)
- [ ] Stocker la clé dans **Supabase > Edge Functions > Secrets** : `ANTHROPIC_API_KEY`

### 5. Unsplash API
- [ ] Compte développeur sur https://unsplash.com/developers
- [ ] Créer une **Application** → obtenir **Access Key**
- [ ] Plan gratuit : 50 requêtes/heure (suffisant pour démarrer)
- [ ] Stocker la clé dans **Supabase > Secrets** : `UNSPLASH_ACCESS_KEY`

### 6. Pexels API (fallback)
- [ ] Compte sur https://www.pexels.com/api/
- [ ] Obtenir **API Key**
- [ ] Stocker dans **Supabase > Secrets** : `PEXELS_API_KEY`

### 7. GitHub
- [ ] Créer un **repo privé** : `capsule-ai-ios`
- [ ] Inviter les développeurs (si applicable)
- [ ] Configurer les branches : `main` + `develop`
- [ ] Activer la protection de branche sur `main` (require PR review)

---

## 🛠 OUTILS À INSTALLER SUR LE MAC

### Obligatoires
- [ ] **Xcode 15+** (App Store) — vérifie que c'est la dernière version
- [ ] **Cursor** (https://cursor.sh) — IDE principal pour le développement
- [ ] **Git** (préinstallé sur Mac, vérifie avec `git --version`)
- [ ] **Supabase CLI** : `brew install supabase/tap/supabase`
- [ ] **Node.js 18+** (pour les Edge Functions Supabase) : `brew install node`
- [ ] **CocoaPods** (au cas où) : `sudo gem install cocoapods`

### Recommandés
- [ ] **SF Symbols** (app Apple gratuite) — pour parcourir les icônes système
- [ ] **Proxyman** ou **Charles** — pour debug des requêtes réseau
- [ ] **GitHub Desktop** (si pas à l'aise avec Git en CLI)

---

## 📱 CONFIGURATION DES 2 iPHONES

### iPhone Manager (ton iPhone)
- [ ] iOS 17+ installé (vérifie dans Réglages > Général > Mise à jour)
- [ ] Connecté au même compte iCloud que le Mac (ou confiance USB)
- [ ] **Mode développeur activé** : Réglages > Confidentialité > Mode développeur
- [ ] Compte Google `snomis@ippon.fr` connecté

### iPhone Collaborateur (second iPhone)
- [ ] iOS 17+ installé
- [ ] Mode développeur activé
- [ ] **Compte Google test** créé (ex: `capsule.test.collab@gmail.com`)
- [ ] Connecté en USB au Mac OU inscrit dans TestFlight

### Pour tester sur les 2 devices
- [ ] Les 2 iPhones connectés au même réseau WiFi que le Mac
- [ ] OU utiliser TestFlight (plus pratique pour le 2ème device)

---

## 🗄 SETUP SUPABASE (à faire une fois le projet créé)

### Base de données
- [ ] Exécuter le script SQL de création des tables (depuis SPEC-TECHNICAL.md)
- [ ] Activer **RLS** sur toutes les tables
- [ ] Créer les policies RLS
- [ ] Créer les triggers (auto-profil, updated_at, migration notes)

### Storage
- [ ] Créer le bucket `avatars` (public)
- [ ] Créer le bucket `attachments` (privé)
- [ ] Créer le bucket `note-images` (public)
- [ ] Configurer les policies de storage

### Edge Functions
- [ ] Déployer `generate-summary`
- [ ] Déployer `ai-assist`
- [ ] Déployer `coach-ia`
- [ ] Déployer `fetch-unsplash-image`
- [ ] Configurer les secrets (API keys) :
  ```bash
  # Depuis la racine du projet, avec ta clé Anthropic (console.anthropic.com) :
  supabase secrets set ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxx
  ```

### Database Webhooks
- [ ] Webhook sur INSERT/UPDATE notes → `generate-summary`
- [ ] Webhook sur INSERT note_tags (tag #Important) → `fetch-unsplash-image`

---

## 📋 SETUP XCODE (à faire au premier lancement)

### Création du projet
- [ ] File > New > Project > iOS > App
- [ ] Product Name : `CapsuleAI`
- [ ] Team : ton compte Apple Developer
- [ ] Organization Identifier : `com.ippon` (ou `com.capsuleai`)
- [ ] Bundle Identifier final : `com.ippon.capsule`
- [ ] Interface : **SwiftUI**
- [ ] Language : **Swift**
- [ ] Storage : **None** (on utilise Supabase)

### Swift Package Manager (SPM)
- [ ] File > Add Package Dependencies :
  - `https://github.com/supabase/supabase-swift` (2.0+)
  - `https://github.com/google/GoogleSignIn-iOS` (7.0+)
  - `https://github.com/SDWebImage/SDWebImageSwiftUI` (3.0+)

### Configuration
- [ ] Copier `GoogleService-Info.plist` dans le projet
- [ ] Ajouter URL Scheme dans Info.plist (pour Google redirect)
- [ ] Signing & Capabilities : sélectionner ton Team + Provisioning Profile
- [ ] Ajouter le dossier `.cursor/rules/` à la racine du repo

---

## 🔑 RÉCAP DES CLÉS ET SECRETS

| Clé | Où la trouver | Où la stocker |
|-----|---------------|---------------|
| Supabase URL | Dashboard Supabase > Settings > API | `SupabaseConstants.swift` |
| Supabase Anon Key | Dashboard Supabase > Settings > API | `SupabaseConstants.swift` |
| Supabase Service Role Key | Dashboard Supabase > Settings > API | **Supabase Secrets** (jamais dans le code) |
| Google iOS Client ID | Google Cloud Console | `GoogleService-Info.plist` |
| Google Web Client ID | Google Cloud Console | Supabase Auth > Google |
| Google Web Client Secret | Google Cloud Console | Supabase Auth > Google |
| Anthropic API Key | console.anthropic.com | **Supabase Secrets** : `ANTHROPIC_API_KEY` |
| Unsplash Access Key | unsplash.com/developers | **Supabase Secrets** : `UNSPLASH_ACCESS_KEY` |
| Pexels API Key | pexels.com/api | **Supabase Secrets** : `PEXELS_API_KEY` |

⚠️ **RÈGLE ABSOLUE** : les clés privées (service_role, Anthropic, Unsplash, Pexels) ne sont **JAMAIS** dans le code Swift. Elles sont uniquement dans les Supabase Secrets (Edge Functions côté serveur).

---

## 💰 BUDGET ESTIMÉ POUR DÉMARRER

| Service | Coût | Notes |
|---------|------|-------|
| Apple Developer | 99$/an | Obligatoire pour TestFlight et App Store |
| Supabase | 0$ (Free tier) | 500 Mo BDD, 1 Go Storage, 500K Edge Functions |
| Claude API | ~20$/mois | Estimé pour usage modéré (résumés + coach) |
| Unsplash | 0$ (Free) | 50 req/h, suffisant |
| Pexels | 0$ (Free) | Fallback |
| Google Cloud | 0$ (Free) | OAuth gratuit |
| GitHub | 0$ (Free private repos) | Ou plan payant si besoin |
| **Total démarrage** | **~120$/an + ~20$/mois** | |

---

## 🚀 ORDRE DE MISE EN PLACE

1. Créer le compte Apple Developer (faire en premier car 24-48h de validation)
2. Créer le projet Supabase
3. Configurer Google Cloud Console (OAuth)
4. Créer le repo GitHub + cloner
5. Copier les fichiers `.cursor/rules/` et `docs/` dans le repo
6. Ouvrir dans Cursor + créer le projet Xcode
7. Installer les dépendances SPM
8. Configurer Supabase (BDD, auth, storage)
9. Premier test : Login Google → profil créé → Home vide
10. Développer feature par feature
