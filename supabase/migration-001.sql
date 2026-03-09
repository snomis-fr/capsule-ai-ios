-- =============================================================================
-- CAPSULE AI — Migration initiale
-- Schéma complet : tables, index, triggers, fonctions, RLS, storage
-- Exécutable en une fois dans le SQL Editor Supabase
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TABLES (ordre respectant les FK)
-- -----------------------------------------------------------------------------

-- 1.1 Workspaces (instance Capsule)
CREATE TABLE workspaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  manager_id UUID NOT NULL REFERENCES auth.users(id),
  max_collaborators INTEGER DEFAULT 7,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 1.2 Profiles (utilisateurs)
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

-- 1.3 Spaces (espaces — niveau 1)
CREATE TABLE spaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT DEFAULT '📂',
  color TEXT DEFAULT '#3B82F6',
  sort_order INTEGER DEFAULT 0,
  is_default BOOLEAN DEFAULT false,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  is_private BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 1.4 Sub-spaces (sous-espaces — niveau 2)
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

-- 1.5 Tags
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT NOT NULL DEFAULT '#3B82F6',
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(workspace_id, name)
);

-- 1.6 Notes
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  sub_space_id UUID NOT NULL REFERENCES sub_spaces(id),
  title TEXT NOT NULL,
  content JSONB,
  content_plain TEXT,
  ai_summary TEXT,
  note_type TEXT DEFAULT 'none',
  is_private BOOLEAN DEFAULT false,
  is_pinned BOOLEAN DEFAULT false,
  word_count INTEGER DEFAULT 0,
  location_city TEXT,
  location_country TEXT,
  location_country_code TEXT,
  unsplash_image_url TEXT,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  last_modified_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 1.7 Note actions (plan d'action / checkboxes)
CREATE TABLE note_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  is_checked BOOLEAN DEFAULT false,
  action_group TEXT DEFAULT 'specific',
  sort_order INTEGER DEFAULT 0,
  checked_by UUID REFERENCES auth.users(id),
  checked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.8 Note tags (relation notes ↔ tags)
CREATE TABLE note_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  UNIQUE(note_id, tag_id)
);

-- 1.9 Attachments (pièces jointes)
CREATE TABLE attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  storage_path TEXT NOT NULL,
  mime_type TEXT,
  uploaded_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.10 Note types (types de notes personnalisables)
CREATE TABLE note_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT DEFAULT '📋',
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.11 Note type actions
CREATE TABLE note_type_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_type_id UUID NOT NULL REFERENCES note_types(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  is_universal BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0
);

-- 1.12 Collaborator access (droits d'accès)
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

-- 1.13 Coach conversations (historique Coach IA)
CREATE TABLE coach_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  messages JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 2. INDEX
-- -----------------------------------------------------------------------------

CREATE INDEX notes_search_idx ON notes
  USING gin(to_tsvector('french', coalesce(title, '') || ' ' || coalesce(content_plain, '')));

CREATE INDEX notes_updated_idx ON notes(workspace_id, updated_at DESC);

-- -----------------------------------------------------------------------------
-- 3. FONCTIONS ET TRIGGERS
-- -----------------------------------------------------------------------------

-- 3.1 Auto-création du profil après inscription
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, first_name, last_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    NEW.raw_user_meta_data->>'given_name',
    NEW.raw_user_meta_data->>'family_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 3.2 Mise à jour automatique du timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON notes FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON spaces FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON workspaces FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON coach_conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 3.3 Max 3 tags par note
CREATE OR REPLACE FUNCTION check_max_tags()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF (SELECT COUNT(*) FROM note_tags WHERE note_id = NEW.note_id) >= 3 THEN
    RAISE EXCEPTION 'Maximum 3 tags par note';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_max_tags
  BEFORE INSERT ON note_tags
  FOR EACH ROW EXECUTE FUNCTION check_max_tags();

-- 3.4 Contrainte taille des pièces jointes (4 Mo photos, 20 Mo fichiers)
CREATE OR REPLACE FUNCTION check_attachment_size()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.file_type = 'photo' AND NEW.file_size > 4194304 THEN
    RAISE EXCEPTION 'Photo max 4 Mo';
  END IF;
  IF NEW.file_type IN ('pdf', 'file') AND NEW.file_size > 20971520 THEN
    RAISE EXCEPTION 'Fichier max 20 Mo';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_attachment_size
  BEFORE INSERT ON attachments
  FOR EACH ROW EXECUTE FUNCTION check_attachment_size();

-- 3.5 Migration des notes vers "Non classées" à la suppression d'un sous-espace
CREATE OR REPLACE FUNCTION migrate_notes_on_subspace_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  default_subspace_id UUID;
BEGIN
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

  IF default_subspace_id IS NULL THEN
    RAISE EXCEPTION 'Impossible de supprimer : aucun sous-espace "Non classées" trouvé';
  END IF;

  UPDATE notes SET sub_space_id = default_subspace_id WHERE sub_space_id = OLD.id;
  RETURN OLD;
END;
$$;

CREATE TRIGGER before_subspace_delete
  BEFORE DELETE ON sub_spaces
  FOR EACH ROW EXECUTE FUNCTION migrate_notes_on_subspace_delete();

-- -----------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE sub_spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_type_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE collaborator_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_conversations ENABLE ROW LEVEL SECURITY;

-- PROFILES
CREATE POLICY "profiles_select" ON profiles FOR SELECT
  USING (
    workspace_id IS NULL
    OR workspace_id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "profiles_insert" ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE
  USING (id = auth.uid());

-- WORKSPACES
CREATE POLICY "workspaces_select" ON workspaces FOR SELECT
  USING (
    manager_id = auth.uid()
    OR id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "workspaces_insert" ON workspaces FOR INSERT
  WITH CHECK (manager_id = auth.uid());

CREATE POLICY "workspaces_update" ON workspaces FOR UPDATE
  USING (manager_id = auth.uid());

CREATE POLICY "workspaces_delete" ON workspaces FOR DELETE
  USING (manager_id = auth.uid());

-- SPACES
CREATE POLICY "spaces_select" ON spaces FOR SELECT
  USING (
    (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
     AND (is_private = false OR created_by = auth.uid()))
    OR (is_private = false AND workspace_id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid()))
    OR created_by = auth.uid()
  );

CREATE POLICY "spaces_insert" ON spaces FOR INSERT
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "spaces_update" ON spaces FOR UPDATE
  USING (created_by = auth.uid());

CREATE POLICY "spaces_delete" ON spaces FOR DELETE
  USING (
    created_by = auth.uid()
    AND NOT EXISTS (SELECT 1 FROM sub_spaces WHERE space_id = spaces.id)
    AND is_default = false
  );

-- SUB_SPACES
CREATE POLICY "sub_spaces_select" ON sub_spaces FOR SELECT
  USING (
    space_id IN (
      SELECT id FROM spaces WHERE
        created_by = auth.uid()
        OR (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()) AND (is_private = false OR created_by = auth.uid()))
        OR (is_private = false AND workspace_id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid()))
    )
  );

CREATE POLICY "sub_spaces_insert" ON sub_spaces FOR INSERT
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "sub_spaces_update" ON sub_spaces FOR UPDATE
  USING (created_by = auth.uid());

CREATE POLICY "sub_spaces_delete" ON sub_spaces FOR DELETE
  USING (created_by = auth.uid());

-- NOTES
CREATE POLICY "notes_select" ON notes FOR SELECT
  USING (
    created_by = auth.uid()
    OR (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
        AND (is_private = false OR created_by = auth.uid()))
    OR (is_private = false AND sub_space_id IN (
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

-- TAGS
CREATE POLICY "tags_select" ON tags FOR SELECT
  USING (
    workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
    OR workspace_id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "tags_insert" ON tags FOR INSERT
  WITH CHECK (
    workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
    OR workspace_id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "tags_update" ON tags FOR UPDATE
  USING (
    workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
    OR workspace_id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "tags_delete" ON tags FOR DELETE
  USING (
    workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
    OR workspace_id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid())
  );

-- NOTE_TAGS (accès via la note)
CREATE POLICY "note_tags_select" ON note_tags FOR SELECT
  USING (
    note_id IN (SELECT id FROM notes WHERE
      created_by = auth.uid()
      OR (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()) AND (is_private = false OR created_by = auth.uid()))
      OR (is_private = false AND sub_space_id IN (SELECT sub_space_id FROM collaborator_access WHERE user_id = auth.uid()))
    )
  );

CREATE POLICY "note_tags_insert" ON note_tags FOR INSERT
  WITH CHECK (
    note_id IN (SELECT id FROM notes WHERE created_by = auth.uid()
      OR sub_space_id IN (SELECT sub_space_id FROM collaborator_access WHERE user_id = auth.uid() AND can_write = true))
  );

CREATE POLICY "note_tags_delete" ON note_tags FOR DELETE
  USING (
    note_id IN (SELECT id FROM notes WHERE created_by = auth.uid()
      OR sub_space_id IN (SELECT sub_space_id FROM collaborator_access WHERE user_id = auth.uid() AND can_write = true))
  );

-- NOTE_ACTIONS
CREATE POLICY "note_actions_select" ON note_actions FOR SELECT
  USING (
    note_id IN (SELECT id FROM notes WHERE
      created_by = auth.uid()
      OR (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()) AND (is_private = false OR created_by = auth.uid()))
      OR (is_private = false AND sub_space_id IN (SELECT sub_space_id FROM collaborator_access WHERE user_id = auth.uid()))
    )
  );

CREATE POLICY "note_actions_insert" ON note_actions FOR INSERT
  WITH CHECK (
    note_id IN (SELECT id FROM notes WHERE created_by = auth.uid()
      OR sub_space_id IN (SELECT sub_space_id FROM collaborator_access WHERE user_id = auth.uid() AND can_write = true))
  );

CREATE POLICY "note_actions_update" ON note_actions FOR UPDATE
  USING (
    note_id IN (SELECT id FROM notes WHERE created_by = auth.uid()
      OR sub_space_id IN (SELECT sub_space_id FROM collaborator_access WHERE user_id = auth.uid() AND can_write = true))
  );

CREATE POLICY "note_actions_delete" ON note_actions FOR DELETE
  USING (
    note_id IN (SELECT id FROM notes WHERE created_by = auth.uid()
      OR sub_space_id IN (SELECT sub_space_id FROM collaborator_access WHERE user_id = auth.uid() AND can_write = true))
  );

-- ATTACHMENTS
CREATE POLICY "attachments_select" ON attachments FOR SELECT
  USING (
    note_id IN (SELECT id FROM notes WHERE
      created_by = auth.uid()
      OR (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()) AND (is_private = false OR created_by = auth.uid()))
      OR (is_private = false AND sub_space_id IN (SELECT sub_space_id FROM collaborator_access WHERE user_id = auth.uid()))
    )
  );

CREATE POLICY "attachments_insert" ON attachments FOR INSERT
  WITH CHECK (uploaded_by = auth.uid());

CREATE POLICY "attachments_delete" ON attachments FOR DELETE
  USING (uploaded_by = auth.uid());

-- NOTE_TYPES
CREATE POLICY "note_types_select" ON note_types FOR SELECT
  USING (
    workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
    OR workspace_id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "note_types_insert" ON note_types FOR INSERT
  WITH CHECK (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()));

CREATE POLICY "note_types_update" ON note_types FOR UPDATE
  USING (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()));

CREATE POLICY "note_types_delete" ON note_types FOR DELETE
  USING (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()));

-- NOTE_TYPE_ACTIONS
CREATE POLICY "note_type_actions_select" ON note_type_actions FOR SELECT
  USING (
    note_type_id IN (
      SELECT id FROM note_types WHERE
        workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
        OR workspace_id IN (SELECT workspace_id FROM profiles WHERE id = auth.uid())
    )
  );

CREATE POLICY "note_type_actions_insert" ON note_type_actions FOR INSERT
  WITH CHECK (
    note_type_id IN (SELECT id FROM note_types WHERE workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()))
  );

CREATE POLICY "note_type_actions_update" ON note_type_actions FOR UPDATE
  USING (
    note_type_id IN (SELECT id FROM note_types WHERE workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()))
  );

CREATE POLICY "note_type_actions_delete" ON note_type_actions FOR DELETE
  USING (
    note_type_id IN (SELECT id FROM note_types WHERE workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()))
  );

-- COLLABORATOR_ACCESS (gestion par le manager uniquement)
CREATE POLICY "collaborator_access_select" ON collaborator_access FOR SELECT
  USING (
    workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
    OR user_id = auth.uid()
  );

CREATE POLICY "collaborator_access_insert" ON collaborator_access FOR INSERT
  WITH CHECK (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()));

CREATE POLICY "collaborator_access_update" ON collaborator_access FOR UPDATE
  USING (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()));

CREATE POLICY "collaborator_access_delete" ON collaborator_access FOR DELETE
  USING (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()));

-- COACH_CONVERSATIONS
CREATE POLICY "coach_conversations_all" ON coach_conversations FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 5. STORAGE (policies uniquement)
-- Les buckets (avatars, attachments, note-images) sont créés via Supabase Dashboard
-- -----------------------------------------------------------------------------

-- Avatars
CREATE POLICY "avatars_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

CREATE POLICY "avatars_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Attachments
CREATE POLICY "attachments_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'attachments' AND auth.uid() IS NOT NULL);

CREATE POLICY "attachments_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'attachments' AND auth.uid() IS NOT NULL);

-- Note images
CREATE POLICY "note_images_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'note-images');

CREATE POLICY "note_images_upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'note-images' AND auth.uid() IS NOT NULL);
