-- Ajoute les espaces Projets, Clients, Réunions pour snomis@ippon.fr si absents

DO $$
DECLARE
  r RECORD;
  uid UUID;
  ws_id UUID;
BEGIN
  SELECT id INTO uid FROM auth.users WHERE email = 'snomis@ippon.fr';
  IF uid IS NULL THEN RETURN; END IF;

  SELECT id INTO ws_id FROM workspaces WHERE manager_id = uid;
  IF ws_id IS NULL THEN RETURN; END IF;

  INSERT INTO spaces (workspace_id, name, emoji, color, sort_order, is_default, created_by, is_private)
  SELECT ws_id, 'Projets', '📁', '#3B82F6', 1, false, uid, false
  WHERE NOT EXISTS (SELECT 1 FROM spaces WHERE workspace_id = ws_id AND name = 'Projets');

  INSERT INTO spaces (workspace_id, name, emoji, color, sort_order, is_default, created_by, is_private)
  SELECT ws_id, 'Clients', '👥', '#22C55E', 2, false, uid, false
  WHERE NOT EXISTS (SELECT 1 FROM spaces WHERE workspace_id = ws_id AND name = 'Clients');

  INSERT INTO spaces (workspace_id, name, emoji, color, sort_order, is_default, created_by, is_private)
  SELECT ws_id, 'Réunions', '📅', '#F59E0B', 3, false, uid, false
  WHERE NOT EXISTS (SELECT 1 FROM spaces WHERE workspace_id = ws_id AND name = 'Réunions');

  FOR r IN SELECT id FROM spaces WHERE workspace_id = ws_id AND is_default = false AND name IN ('Projets','Clients','Réunions')
  LOOP
    IF NOT EXISTS (SELECT 1 FROM sub_spaces WHERE space_id = r.id) THEN
      INSERT INTO sub_spaces (space_id, name, emoji, sort_order, created_by, is_trash)
      VALUES (r.id, 'Général', '📄', 0, uid, false);
    END IF;
  END LOOP;
END $$;
