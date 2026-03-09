-- Invitations collaborateurs : le manager invite par email
-- La personne reçoit un email, clique sur le lien, s'inscrit avec Google
-- Ce trigger ajoute le nouveau user comme collaborateur

CREATE TABLE IF NOT EXISTS pending_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  sub_space_id UUID NOT NULL REFERENCES sub_spaces(id) ON DELETE CASCADE,
  invited_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE pending_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pending_invites_insert_manager" ON pending_invites FOR INSERT
  WITH CHECK (
    workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
  );

CREATE POLICY "pending_invites_select_manager" ON pending_invites FOR SELECT
  USING (
    workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
  );

-- Quand un user s'inscrit (via invite), l'ajouter comme collaborateur
CREATE OR REPLACE FUNCTION handle_invited_user_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  invite_record RECORD;
BEGIN
  SELECT * INTO invite_record
  FROM pending_invites
  WHERE LOWER(email) = LOWER(NEW.email)
  LIMIT 1;

  IF FOUND THEN
    INSERT INTO collaborator_access (workspace_id, user_id, sub_space_id, can_read, can_write)
    VALUES (invite_record.workspace_id, NEW.id, invite_record.sub_space_id, true, true);

    UPDATE profiles
    SET workspace_id = invite_record.workspace_id, role = 'collaborator'
    WHERE id = NEW.id;

    DELETE FROM pending_invites WHERE id = invite_record.id;
  END IF;

  RETURN NEW;
END;
$$;

-- S'exécute après handle_new_user (ordre de création des triggers)
CREATE TRIGGER on_auth_user_invited
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_invited_user_signup();
