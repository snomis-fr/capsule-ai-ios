-- Fix: path avatar doit correspondre à auth.uid()::text (lowercase)
-- Le client envoie désormais UUID en minuscules. S'assurer que la policy accepte.
-- Certains déploiements peuvent avoir des policies qui échouent sur upsert.

DROP POLICY IF EXISTS "avatars_upload" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update" ON storage.objects;

CREATE POLICY "avatars_upload" ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
  );

CREATE POLICY "avatars_update" ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
  );
