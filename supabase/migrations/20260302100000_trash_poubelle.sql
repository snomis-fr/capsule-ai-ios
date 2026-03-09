-- Poubelle : sous-catégorie dans Non classées pour les notes supprimées
-- - Les notes "supprimées" sont déplacées vers Poubelle (pas de DELETE)
-- - Suppression définitive après 30 jours
-- - Restauration possible vers un autre espace avant 30 jours

-- 1. Colonnes pour la poubelle
ALTER TABLE sub_spaces ADD COLUMN IF NOT EXISTS is_trash BOOLEAN DEFAULT false;
ALTER TABLE notes ADD COLUMN IF NOT EXISTS moved_to_trash_at TIMESTAMPTZ;

-- 2. Créer le sous-espace Poubelle dans Non classées pour chaque workspace existant
INSERT INTO sub_spaces (space_id, name, emoji, sort_order, created_by, is_trash)
SELECT s.id, 'Poubelle', '🗑️', 1, s.created_by, true
FROM spaces s
WHERE s.is_default = true
  AND NOT EXISTS (
    SELECT 1 FROM sub_spaces ss
    WHERE ss.space_id = s.id AND ss.is_trash = true
  );

-- 3. Fonction pour purger les notes en poubelle depuis plus de 30 jours
CREATE OR REPLACE FUNCTION purge_old_trash_notes()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  WITH deleted AS (
    DELETE FROM notes
    WHERE moved_to_trash_at IS NOT NULL
      AND moved_to_trash_at < now() - interval '30 days'
    RETURNING id
  )
  SELECT count(*)::integer INTO deleted_count FROM deleted;
  RETURN deleted_count;
END;
$$;

-- 4. (Optionnel) Programmer avec pg_cron si disponible :
-- SELECT cron.schedule('purge-trash-daily', '0 3 * * *', 'SELECT purge_old_trash_notes()');
