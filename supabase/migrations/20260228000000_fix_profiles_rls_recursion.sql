-- =============================================================================
-- Fix: infinite recursion in profiles RLS policies
-- Les policies qui font SELECT sur profiles dans leur USING déclenchent une
-- récursion. Solution : fonction SECURITY DEFINER qui bypass RLS.
-- Exécuter dans Supabase SQL Editor ou via: supabase db push
-- =============================================================================

-- 1. Fonction helper qui retourne le workspace_id de l'utilisateur connecté (bypass RLS)
CREATE OR REPLACE FUNCTION public.get_my_workspace_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT workspace_id FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- 2. Remplacer profiles_select (évite la récursion)
DROP POLICY IF EXISTS "profiles_select" ON profiles;
CREATE POLICY "profiles_select" ON profiles FOR SELECT
  USING (
    id = auth.uid()
    OR workspace_id IS NULL
    OR workspace_id = public.get_my_workspace_id()
  );

-- 3. Remplacer workspaces_select
DROP POLICY IF EXISTS "workspaces_select" ON workspaces;
CREATE POLICY "workspaces_select" ON workspaces FOR SELECT
  USING (
    manager_id = auth.uid()
    OR id = public.get_my_workspace_id()
  );

-- 4. Remplacer spaces_select
DROP POLICY IF EXISTS "spaces_select" ON spaces;
CREATE POLICY "spaces_select" ON spaces FOR SELECT
  USING (
    (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid())
     AND (is_private = false OR created_by = auth.uid()))
    OR (is_private = false AND workspace_id = public.get_my_workspace_id())
    OR created_by = auth.uid()
  );

-- 5. Remplacer sub_spaces_select
DROP POLICY IF EXISTS "sub_spaces_select" ON sub_spaces;
CREATE POLICY "sub_spaces_select" ON sub_spaces FOR SELECT
  USING (
    space_id IN (
      SELECT id FROM spaces WHERE
        created_by = auth.uid()
        OR (workspace_id IN (SELECT id FROM workspaces WHERE manager_id = auth.uid()) AND (is_private = false OR created_by = auth.uid()))
        OR (is_private = false AND workspace_id = public.get_my_workspace_id())
    )
  );
