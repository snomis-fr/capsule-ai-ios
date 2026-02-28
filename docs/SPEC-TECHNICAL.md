# CAPSULE AI — Architecture technique
## Application native iOS (SwiftUI) + Backend Supabase
### Version 1.0 — Février 2026

---

## 1. STACK TECHNIQUE

### 1.1 Frontend (iOS natif)
| Composant | Technologie | Version min |
|-----------|-------------|-------------|
| Langage | Swift 5.9+ | iOS 17+ |
| Framework UI | SwiftUI | natif |
| Éditeur riche | WKWebView + Tiptap JS | bridge Swift ↔ JS |
| Navigation | NavigationStack | natif |
| State management | @Observable / @State / @Environment | natif |
| Réseau | URLSession + async/await | natif |
| Auth | Google Sign-In SDK for iOS | dernière stable |
| Images | SDWebImageSwiftUI (cache async) | 3.x |
| Stockage local | SwiftData ou CoreData (mode offline futur) | natif |
| Géolocalisation | CoreLocation | natif |
| Notifications push | APNs + Supabase Realtime | natif |

### 1.2 Backend
| Composant | Technologie | Usage |
|-----------|-------------|-------|
| BDD | Supabase (PostgreSQL) | données, auth, storage, realtime |
| Auth | Supabase Auth + Google OAuth | connexion Google |
| Storage | Supabase Storage | photos profil, PJ notes (photos, PDF, fichiers) |
| Realtime | Supabase Realtime | sync live entre collaborateurs |
| Edge Functions | Supabase Edge Functions (Deno) | logique métier côté serveur |
| API IA | Anthropic Claude API | résumé, structuration, Coach IA |
| Images auto | Unsplash API ou Pexels API | images pour notes #Important |

### 1.3 Outils de développement
| Outil | Usage |
|-------|-------|
| Cursor | IDE principal (génération code Swift) |
| Xcode | Build, signing, simulateur, TestFlight |
| GitHub | Versioning |
| TestFlight | Distribution beta |

---

## 2. SUPABASE — AUTHENTIFICATION

### 2.1 Flow d'authentification
```
1. L'utilisateur tap "Se connecter avec Google"
2. Google Sign-In SDK → récupère le id_token Google
3. L'app envoie le id_token à Supabase Auth :
   supabase.auth.signInWithIdToken(provider: .google, idToken: googleIdToken)
4. Supabase crée/retrouve l'utilisateur dans auth.users
5. Un trigger PostgreSQL crée automatiquement le profil dans public.profiles
6. L'app reçoit le session token Supabase → stocké dans Keychain
7. Toutes les requêtes suivantes utilisent ce token (RLS activé)
```

### 2.2 Configuration Supabase Auth
- Provider : Google
- Redirect URL : scheme custom de l'app iOS (ex: `com.capsule.app://callback`)
- Auto-refresh des tokens activé
- Session persistence via Keychain iOS

---

## 3. SUPABASE — SCHÉMA BASE DE DONNÉES

### 3.1 Table `profiles` (utilisateurs)
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  first_name TEXT,
  last_name TEXT,
  city TEXT,
  title TEXT,
  company TEXT,
  activity TEXT,
  avatar_url TEXT,
  status TEXT DEFAULT 'none' CHECK (status IN ('none', 'available', 'vacation', 'sick')),
  role TEXT DEFAULT 'collaborator' CHECK (role IN ('manager', 'collaborator')),
  workspace_id UUID REFERENCES workspaces(id),
  job_icon TEXT DEFAULT '💼',
  geolocation_enabled BOOLEAN DEFAULT true,
  notifications_enabled BOOLEAN DEFAULT true,
  offline_sync_enabled BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### 3.2 Table `workspaces` (instance Capsule)
```sql
CREATE TABLE workspaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_name TEXT NOT NULL, -- premier mot du nom de société
  manager_id UUID NOT NULL REFERENCES auth.users(id),
  max_collaborators INTEGER DEFAULT 7,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### 3.3 Table `spaces` (espaces — niveau 1)
```sql
CREATE TABLE spaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT DEFAULT '📂',
  color TEXT DEFAULT '#3B82F6', -- couleur hex du dégradé
  sort_order INTEGER DEFAULT 0,
  is_default BOOLEAN DEFAULT false, -- true pour "Non classées"
  created_by UUID NOT NULL REFERENCES auth.users(id),
  is_private BOOLEAN DEFAULT false, -- true si espace privé d'un collaborateur
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### 3.4 Table `sub_spaces` (sous-espaces — niveau 2)
```sql
CREATE TABLE sub_spaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT DEFAULT '📄',
  sort_order INTEGER DEFAULT 0,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### 3.5 Table `notes`
```sql
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  sub_space_id UUID NOT NULL REFERENCES sub_spaces(id),
  title TEXT NOT NULL,
  content JSONB, -- contenu Tiptap en JSON
  content_plain TEXT, -- texte brut pour recherche full-text
  ai_summary TEXT, -- résumé généré par IA
  note_type TEXT DEFAULT 'none', -- reunion, projet, probleme, strategie, none
  is_private BOOLEAN DEFAULT false,
  is_pinned BOOLEAN DEFAULT false,
  word_count INTEGER DEFAULT 0,
  location_city TEXT,
  location_country TEXT,
  location_country_code TEXT, -- FR, MA, US, etc.
  unsplash_image_url TEXT, -- image auto pour notes #Important
  created_by UUID NOT NULL REFERENCES auth.users(id),
  last_modified_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index full-text pour la recherche
CREATE INDEX notes_search_idx ON notes USING gin(to_tsvector('french', coalesce(title, '') || ' ' || coalesce(content_plain, '')));

-- Index pour le tri par date de modification
CREATE INDEX notes_updated_idx ON notes(workspace_id, updated_at DESC);
```

### 3.6 Table `note_actions` (plan d'action / checkboxes)
```sql
CREATE TABLE note_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  is_checked BOOLEAN DEFAULT false,
  action_group TEXT DEFAULT 'specific', -- 'specific' ou 'universal'
  sort_order INTEGER DEFAULT 0,
  checked_by UUID REFERENCES auth.users(id),
  checked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### 3.7 Table `note_tags` (relation notes ↔ tags)
```sql
CREATE TABLE note_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  UNIQUE(note_id, tag_id)
);

-- Contrainte : max 3 tags par note (via trigger)
CREATE OR REPLACE FUNCTION check_max_tags()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM note_tags WHERE note_id = NEW.note_id) >= 3 THEN
    RAISE EXCEPTION 'Maximum 3 tags par note';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_max_tags
  BEFORE INSERT ON note_tags
  FOR EACH ROW EXECUTE FUNCTION check_max_tags();
```

### 3.8 Table `tags`
```sql
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT NOT NULL DEFAULT '#3B82F6', -- couleur hex
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(workspace_id, name)
);
```

### 3.9 Table `attachments` (pièces jointes)
```sql
CREATE TABLE attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL, -- 'photo', 'pdf', 'file'
  file_size INTEGER NOT NULL, -- en octets
  storage_path TEXT NOT NULL, -- chemin dans Supabase Storage
  mime_type TEXT,
  uploaded_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Contrainte taille (via trigger)
CREATE OR REPLACE FUNCTION check_attachment_size()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.file_type = 'photo' AND NEW.file_size > 4194304 THEN -- 4 Mo
    RAISE EXCEPTION 'Photo max 4 Mo';
  END IF;
  IF NEW.file_type IN ('pdf', 'file') AND NEW.file_size > 20971520 THEN -- 20 Mo
    RAISE EXCEPTION 'Fichier max 20 Mo';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_attachment_size
  BEFORE INSERT ON attachments
  FOR EACH ROW EXECUTE FUNCTION check_attachment_size();
```

### 3.10 Table `note_types` (types de notes personnalisables)
```sql
CREATE TABLE note_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT DEFAULT '📋',
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE note_type_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_type_id UUID NOT NULL REFERENCES note_types(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  is_universal BOOLEAN DEFAULT false, -- true = action universelle commune
  sort_order INTEGER DEFAULT 0
);
```

### 3.11 Table `collaborator_access` (droits d'accès)
```sql
CREATE TABLE collaborator_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  sub_space_id UUID NOT NULL REFERENCES sub_spaces(id) ON DELETE CASCADE,
  can_read BOOLEAN DEFAULT true,
  can_write BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, sub_space_id)
);
```

### 3.12 Table `coach_conversations` (historique Coach IA)
```sql
CREATE TABLE coach_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  messages JSONB DEFAULT '[]', -- array de {role, content, timestamp}
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

---

## 4. SUPABASE — ROW LEVEL SECURITY (RLS)

### 4.1 Principe
Toutes les tables ont RLS activé. Chaque requête est filtrée automatiquement selon l'utilisateur connecté.

### 4.2 Policies principales

```sql
-- Activer RLS sur toutes les tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE sub_spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE collaborator_access ENABLE ROW LEVEL SECURITY;

-- PROFILES : chacun voit les membres de son workspace
CREATE POLICY "profiles_select" ON profiles FOR SELECT
  USING (workspace_id IN (
    SELECT workspace_id FROM profiles WHERE id = auth.uid()
  ));

CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE
  USING (id = auth.uid());

-- NOTES : visibles selon les droits d'accès aux sous-espaces
CREATE POLICY "notes_select" ON notes FOR SELECT
  USING (
    -- Créateur de la note
    created_by = auth.uid()
    OR
    -- Manager du workspace (sauf notes privées d'un autre)
    (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
     AND (is_private = false OR created_by = auth.uid()))
    OR
    -- Collaborateur avec accès au sous-espace (sauf notes privées)
    (is_private = false AND sub_space_id IN (
      SELECT sub_space_id FROM collaborator_access WHERE user_id = auth.uid()
    ))
  );

CREATE POLICY "notes_insert" ON notes FOR INSERT
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "notes_update" ON notes FOR UPDATE
  USING (
    created_by = auth.uid()
    OR sub_space_id IN (
      SELECT sub_space_id FROM collaborator_access
      WHERE user_id = auth.uid() AND can_write = true
    )
  );

CREATE POLICY "notes_delete" ON notes FOR DELETE
  USING (created_by = auth.uid());

-- SPACES : manager voit tout, collaborateur voit les espaces non privés + les siens
CREATE POLICY "spaces_select" ON spaces FOR SELECT
  USING (
    -- Manager du workspace
    workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
    AND (is_private = false OR created_by = auth.uid())
    OR
    -- Collaborateur : espaces non privés + ses propres espaces privés
    (is_private = false AND workspace_id IN (
      SELECT workspace_id FROM profiles WHERE id = auth.uid()
    ))
    OR created_by = auth.uid()
  );

-- SPACES : seul le manager crée les espaces partagés
CREATE POLICY "spaces_insert" ON spaces FOR INSERT
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "spaces_delete" ON spaces FOR DELETE
  USING (
    created_by = auth.uid()
    AND NOT EXISTS (SELECT 1 FROM sub_spaces WHERE space_id = spaces.id)
    AND is_default = false
  );
```

---

## 5. SUPABASE — STORAGE

### 5.1 Buckets

```sql
-- Bucket pour les avatars (profils)
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);

-- Bucket pour les pièces jointes des notes
INSERT INTO storage.buckets (id, name, public) VALUES ('attachments', 'attachments', false);

-- Bucket pour les images Unsplash mises en cache
INSERT INTO storage.buckets (id, name, public) VALUES ('note-images', 'note-images', true);
```

### 5.2 Policies Storage

```sql
-- Avatars : lecture publique, upload par l'utilisateur
CREATE POLICY "avatars_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

CREATE POLICY "avatars_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Attachments : accès selon les droits sur la note
CREATE POLICY "attachments_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'attachments' AND auth.uid() IS NOT NULL);

CREATE POLICY "attachments_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'attachments' AND auth.uid() IS NOT NULL);
```

### 5.3 Structure des fichiers

```
avatars/
  {user_id}/avatar.jpg

attachments/
  {workspace_id}/{note_id}/{filename}

note-images/
  {note_id}/unsplash.jpg
```

---

## 6. SUPABASE — REALTIME

### 6.1 Channels à écouter

```swift
// Écouter les modifications de notes en temps réel
let notesChannel = supabase.channel("notes-changes")
  .on("postgres_changes", filter: .init(
    event: .all,
    schema: "public",
    table: "notes",
    filter: "workspace_id=eq.\(workspaceId)"
  )) { payload in
    // Mettre à jour la UI en temps réel
  }

// Écouter les modifications d'actions (checkboxes)
let actionsChannel = supabase.channel("actions-changes")
  .on("postgres_changes", filter: .init(
    event: .update,
    schema: "public",
    table: "note_actions"
  )) { payload in
    // Mettre à jour les checkboxes en temps réel
  }
```

### 6.2 Cas d'usage Realtime
- Un collaborateur modifie une note → la Home se met à jour pour tous
- Un collaborateur coche une action → le plan d'action se met à jour en lecture
- Un nouveau collaborateur est ajouté → ses espaces apparaissent
- Un statut collaborateur change (Dispo → Congés) → visible immédiatement

---

## 7. SUPABASE — EDGE FUNCTIONS

### 7.1 `generate-summary` — Résumé IA automatique

```typescript
// supabase/functions/generate-summary/index.ts
import { serve } from "https://deno.land/std/http/server.ts";
import Anthropic from "npm:@anthropic-ai/sdk";

serve(async (req) => {
  const { noteId, title, content } = await req.json();

  const anthropic = new Anthropic({
    apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
  });

  const message = await anthropic.messages.create({
    model: "claude-sonnet-4-5-20250929",
    max_tokens: 200,
    system: "Tu es un assistant qui résume des notes professionnelles. Génère un résumé de 2-3 lignes maximum, concis et factuel. Réponds uniquement avec le résumé, sans préambule.",
    messages: [
      {
        role: "user",
        content: `Titre: ${title}\n\nContenu:\n${content}`
      }
    ]
  });

  const summary = message.content[0].text;

  // Sauvegarder le résumé dans la note
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  );

  await supabase.from("notes").update({ ai_summary: summary }).eq("id", noteId);

  return new Response(JSON.stringify({ summary }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

### 7.2 `ai-assist` — Assistance IA dans l'éditeur

```typescript
// supabase/functions/ai-assist/index.ts
serve(async (req) => {
  const { action, title, content } = await req.json();
  // action: "summarize" | "restructure" | "suggestions" | "translate" | "action_plan"

  const prompts = {
    summarize: "Résume cette note en 3 points clés maximum.",
    restructure: "Restructure et mets en forme cette note de manière professionnelle avec des titres, sous-titres et listes. Conserve tout le contenu.",
    suggestions: "Propose 3 à 5 suggestions concrètes pour améliorer ou compléter cette note.",
    translate: "Traduis intégralement cette note en anglais, en conservant la mise en forme.",
    action_plan: "À partir du contenu de cette note, génère un plan d'action concret avec des étapes numérotées, des responsables potentiels et des deadlines suggérées."
  };

  const anthropic = new Anthropic({
    apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
  });

  const message = await anthropic.messages.create({
    model: "claude-sonnet-4-5-20250929",
    max_tokens: 2000,
    system: "Tu es un assistant professionnel intégré dans une application de prise de notes pour dirigeants. Réponds de manière concise, structurée et actionnable.",
    messages: [
      {
        role: "user",
        content: `${prompts[action]}\n\nTitre: ${title}\n\nContenu:\n${content}`
      }
    ]
  });

  return new Response(JSON.stringify({
    result: message.content[0].text
  }));
});
```

### 7.3 `coach-ia` — Coach IA conversationnel

```typescript
// supabase/functions/coach-ia/index.ts
serve(async (req) => {
  const { userId, workspaceId, userMessage, conversationHistory } = await req.json();

  // Récupérer le contexte des notes de l'utilisateur
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  );

  // Charger les notes récentes + notes #Important + actions non cochées
  const { data: recentNotes } = await supabase
    .from("notes")
    .select("title, ai_summary, updated_at, note_actions(*), note_tags(tags(name))")
    .eq("workspace_id", workspaceId)
    .order("updated_at", { ascending: false })
    .limit(50);

  // Construire le contexte
  const notesContext = recentNotes.map(n => {
    const unchecked = n.note_actions?.filter(a => !a.is_checked).map(a => a.label) || [];
    const tags = n.note_tags?.map(nt => nt.tags?.name) || [];
    return `- "${n.title}" (modifiée ${n.updated_at}) | Tags: ${tags.join(", ")} | Actions en attente: ${unchecked.join(", ") || "aucune"}`;
  }).join("\n");

  const systemPrompt = `Tu es le Coach IA de l'application Capsule. Tu as accès à toutes les notes de l'utilisateur dans son workspace.

TON RÔLE :
- Analyser les notes de l'utilisateur UNIQUEMENT (tu n'es PAS un assistant généraliste)
- Détecter les actions en retard ou non cochées
- Faire des résumés croisés par espace, tag ou période
- Alerter sur les notes non mises à jour
- Rechercher dans les notes

CONTEXTE ACTUEL DES NOTES :
${notesContext}

Réponds de manière concise, structurée et actionnable. Utilise des émojis avec parcimonie.`;

  const messages = [
    ...conversationHistory.map(m => ({ role: m.role, content: m.content })),
    { role: "user", content: userMessage }
  ];

  const anthropic = new Anthropic({
    apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
  });

  const message = await anthropic.messages.create({
    model: "claude-sonnet-4-5-20250929",
    max_tokens: 1500,
    system: systemPrompt,
    messages: messages
  });

  return new Response(JSON.stringify({
    reply: message.content[0].text
  }));
});
```

### 7.4 `fetch-unsplash-image` — Image auto pour notes #Important

```typescript
// supabase/functions/fetch-unsplash-image/index.ts
serve(async (req) => {
  const { noteId, title } = await req.json();

  // Extraire les mots-clés du titre pour la recherche
  const query = title
    .replace(/[—–\-]/g, " ")
    .split(" ")
    .filter(w => w.length > 3)
    .slice(0, 3)
    .join(" ");

  const response = await fetch(
    `https://api.unsplash.com/search/photos?query=${encodeURIComponent(query)}&per_page=1&orientation=landscape`,
    {
      headers: {
        Authorization: `Client-ID ${Deno.env.get("UNSPLASH_ACCESS_KEY")}`,
      },
    }
  );

  const data = await response.json();
  const imageUrl = data.results?.[0]?.urls?.regular || null;

  if (imageUrl) {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL"),
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    );

    await supabase.from("notes").update({ unsplash_image_url: imageUrl }).eq("id", noteId);
  }

  return new Response(JSON.stringify({ imageUrl }));
});
```

---

## 8. TRIGGERS PostgreSQL

### 8.1 Auto-création du profil après inscription

```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, first_name, last_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'given_name',
    NEW.raw_user_meta_data->>'family_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

### 8.2 Mise à jour automatique du timestamp

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer à toutes les tables pertinentes
CREATE TRIGGER set_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON notes FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON spaces FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON workspaces FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

### 8.3 Migration des notes quand un sous-espace est supprimé

```sql
CREATE OR REPLACE FUNCTION migrate_notes_on_subspace_delete()
RETURNS TRIGGER AS $$
DECLARE
  default_subspace_id UUID;
BEGIN
  -- Trouver le sous-espace "Non classées" du workspace
  SELECT ss.id INTO default_subspace_id
  FROM sub_spaces ss
  JOIN spaces s ON ss.space_id = s.id
  WHERE s.workspace_id = (
    SELECT s2.workspace_id FROM spaces s2
    JOIN sub_spaces ss2 ON ss2.space_id = s2.id
    WHERE ss2.id = OLD.id
  )
  AND s.is_default = true
  LIMIT 1;

  -- Migrer toutes les notes du sous-espace supprimé
  UPDATE notes SET sub_space_id = default_subspace_id WHERE sub_space_id = OLD.id;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_subspace_delete
  BEFORE DELETE ON sub_spaces
  FOR EACH ROW EXECUTE FUNCTION migrate_notes_on_subspace_delete();
```

### 8.4 Appel IA auto à la sauvegarde d'une note

```sql
-- Via Database Webhook (Supabase Dashboard)
-- Quand une note est INSERT ou UPDATE → appeler la Edge Function generate-summary
-- Configuration dans Supabase Dashboard > Database > Webhooks
-- Table: notes
-- Events: INSERT, UPDATE
-- URL: https://<project>.supabase.co/functions/v1/generate-summary
```

### 8.5 Fetch image Unsplash quand tag #Important est ajouté

```sql
-- Via Database Webhook
-- Quand un note_tag est INSERT avec tag "Important" → appeler fetch-unsplash-image
-- Logique : vérifier côté Edge Function si le tag est "Important"
```

---

## 9. APIS EXTERNES

### 9.1 Anthropic Claude API

| Paramètre | Valeur |
|-----------|--------|
| Endpoint | https://api.anthropic.com/v1/messages |
| Modèle recommandé | claude-sonnet-4-5-20250929 (rapport qualité/coût/vitesse) |
| Modèle premium (Coach IA) | claude-sonnet-4-5-20250929 ou claude-opus-4-6 si budget le permet |
| Clé API | stockée en variable d'environnement Supabase (ANTHROPIC_API_KEY) |
| Appels côté | serveur uniquement (Edge Functions) — jamais côté client |

**Usages :**
| Fonction | Tokens estimés (entrée + sortie) | Fréquence |
|----------|----------------------------------|-----------|
| Résumé auto | ~500 + 100 | À chaque sauvegarde de note |
| Assist éditeur (résumer, restructurer, suggestions) | ~1000 + 500 | À la demande |
| Traduire | ~1000 + 1000 | À la demande |
| Coach IA | ~3000 + 500 par message | À la demande |

### 9.2 Unsplash API

| Paramètre | Valeur |
|-----------|--------|
| Endpoint | https://api.unsplash.com/search/photos |
| Clé | UNSPLASH_ACCESS_KEY (variable d'environnement) |
| Limite gratuite | 50 requêtes/heure (production : demander accès étendu) |
| Fallback | Pexels API (https://api.pexels.com/v1/search) si quota Unsplash dépassé |
| Attribution | Obligatoire selon TOS Unsplash (lien photographe) |

### 9.3 Google Sign-In

| Paramètre | Valeur |
|-----------|--------|
| SDK | google-signin-ios (SPM) |
| Client ID | Créé dans Google Cloud Console |
| Scopes | email, profile |
| Redirect | scheme custom app |

---

## 10. ARCHITECTURE SWIFT (STRUCTURE DU PROJET)

```
CapsuleAI/
├── App/
│   ├── CapsuleAIApp.swift          -- Point d'entrée
│   ├── AppState.swift              -- État global (@Observable)
│   └── ContentView.swift           -- Router principal + TabView
│
├── Core/
│   ├── Auth/
│   │   ├── AuthManager.swift       -- Google Sign-In + Supabase Auth
│   │   └── AuthView.swift          -- Écran login
│   ├── Network/
│   │   ├── SupabaseManager.swift   -- Client Supabase singleton
│   │   ├── APIClient.swift         -- Appels Edge Functions
│   │   └── RealtimeManager.swift   -- Supabase Realtime
│   └── Location/
│       └── LocationManager.swift   -- CoreLocation
│
├── Models/
│   ├── Profile.swift
│   ├── Workspace.swift
│   ├── Space.swift
│   ├── SubSpace.swift
│   ├── Note.swift
│   ├── Tag.swift
│   ├── Attachment.swift
│   ├── NoteType.swift
│   └── NoteAction.swift
│
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift          -- Écran d'accueil
│   │   ├── HomeViewModel.swift
│   │   ├── NoteCardView.swift      -- Carte note (standard + important)
│   │   └── TagListView.swift       -- Section tags
│   │
│   ├── Spaces/
│   │   ├── SpacesView.swift        -- Liste des espaces
│   │   ├── SpacesViewModel.swift
│   │   ├── SubSpaceListView.swift  -- Notes d'un sous-espace
│   │   └── CreateSubSpaceSheet.swift
│   │
│   ├── NoteEditor/
│   │   ├── NoteEditorView.swift    -- Création/édition
│   │   ├── NoteEditorViewModel.swift
│   │   ├── TiptapWebView.swift     -- WKWebView + bridge Tiptap
│   │   ├── SpacePickerView.swift
│   │   ├── TagPickerView.swift
│   │   ├── AttachmentPickerView.swift
│   │   └── NoteTypePickerView.swift
│   │
│   ├── NoteReader/
│   │   ├── NoteReaderView.swift    -- Vue lecture
│   │   ├── NoteReaderViewModel.swift
│   │   └── ActionPlanView.swift    -- Checkboxes interactives
│   │
│   ├── Search/
│   │   ├── SearchView.swift
│   │   ├── SearchViewModel.swift
│   │   └── FilterBarView.swift
│   │
│   ├── CoachIA/
│   │   ├── CoachIAView.swift       -- Chat Coach IA
│   │   ├── CoachIAViewModel.swift
│   │   └── SuggestionButtonView.swift
│   │
│   └── Profile/
│       ├── ProfileView.swift       -- Profil utilisateur
│       ├── ProfileViewModel.swift
│       ├── SpaceManagerView.swift   -- Gestion espaces (drag & drop)
│       ├── CollaboratorListView.swift
│       ├── CollaboratorDetailView.swift
│       ├── TagManagerView.swift
│       ├── NoteTypeManagerView.swift
│       └── SettingsView.swift
│
├── Components/
│   ├── AvatarView.swift
│   ├── BadgeView.swift
│   ├── SearchBarView.swift
│   └── AIAssistButton.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── tiptap-editor.html          -- HTML Tiptap pour WKWebView
│   └── Localizable.strings         -- i18n
│
└── Utilities/
    ├── DateFormatter+Extensions.swift
    ├── Color+Hex.swift
    └── Constants.swift
```

---

## 11. VARIABLES D'ENVIRONNEMENT (Supabase)

```env
# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbG...
SUPABASE_SERVICE_ROLE_KEY=eyJhbG...  # Uniquement côté serveur

# Anthropic
ANTHROPIC_API_KEY=sk-ant-...

# Unsplash
UNSPLASH_ACCESS_KEY=...

# Pexels (fallback)
PEXELS_API_KEY=...

# Google OAuth
GOOGLE_CLIENT_ID=...
GOOGLE_IOS_CLIENT_ID=...
```

---

## 12. DÉPLOIEMENT TESTFLIGHT

### 12.1 Prérequis
1. Compte Apple Developer (99$/an)
2. Mac avec Xcode 15+
3. Certificat de distribution iOS
4. Provisioning Profile (App Store / Ad Hoc)
5. App ID configuré dans Apple Developer Portal

### 12.2 Étapes
```bash
1. Ouvrir le projet dans Xcode
2. Configurer Signing & Capabilities (Team, Bundle ID)
3. Ajouter capabilities : Sign in with Apple (optionnel), Push Notifications
4. Product → Archive
5. Distribute App → App Store Connect
6. Upload
7. Dans App Store Connect → TestFlight → Ajouter testeurs internes/externes
8. Les testeurs reçoivent une invitation par email
```

### 12.3 Dépendances Swift Package Manager (SPM)
```swift
// Package.swift dependencies
dependencies: [
  .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
  .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0"),
  .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "3.0.0"),
]
```

---

*Document technique généré le 28 février 2026*
*Capsule AI v1.0 — Prêt pour implémentation via Cursor + Xcode*
