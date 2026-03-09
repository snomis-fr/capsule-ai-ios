-- Tags : unicité insensible à la casse (Urgent = urgent = URGENT → une seule ligne)
-- 1. Fusionner les doublons existants (garder un tag par workspace_id + lower(name))
-- 2. Remplacer UNIQUE(workspace_id, name) par UNIQUE(workspace_id, lower(name))

DO $$
DECLARE
  dup RECORD;
  keeper_id UUID;
BEGIN
  FOR dup IN
    SELECT workspace_id, lower(name) AS name_lower, array_agg(id ORDER BY created_at, id) AS ids
    FROM tags
    GROUP BY workspace_id, lower(name)
    HAVING count(*) > 1
  LOOP
    keeper_id := dup.ids[1];
    UPDATE note_tags SET tag_id = keeper_id WHERE tag_id = ANY(dup.ids[2:array_length(dup.ids, 1)]);
    DELETE FROM tags WHERE id = ANY(dup.ids[2:array_length(dup.ids, 1)]);
  END LOOP;
END $$;

ALTER TABLE tags DROP CONSTRAINT IF EXISTS tags_workspace_id_name_key;

CREATE UNIQUE INDEX tags_workspace_id_name_lower_key ON tags (workspace_id, lower(name));
