-- Table pour stocker les tokens de notification push (APNs)
-- Un utilisateur peut avoir plusieurs appareils
CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, token)
);

CREATE INDEX IF NOT EXISTS device_tokens_user_id_idx ON device_tokens(user_id);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- RLS : l'utilisateur ne peut que lire/écrire ses propres tokens
CREATE POLICY "device_tokens_select" ON device_tokens FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "device_tokens_insert" ON device_tokens FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "device_tokens_update" ON device_tokens FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "device_tokens_delete" ON device_tokens FOR DELETE
  USING (user_id = auth.uid());

CREATE TRIGGER set_updated_at BEFORE UPDATE ON device_tokens FOR EACH ROW EXECUTE FUNCTION update_updated_at();
