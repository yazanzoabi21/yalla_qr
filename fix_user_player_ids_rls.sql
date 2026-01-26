-- ========================================
-- UPDATE USER_PLAYER_IDS RLS POLICIES
-- Allow users to manage their player IDs properly
-- ========================================

-- Drop old policies first
DROP POLICY IF EXISTS "Users can view their own player IDs" ON public.user_player_ids;
DROP POLICY IF EXISTS "Users can insert their own player IDs" ON public.user_player_ids;
DROP POLICY IF EXISTS "Users can update their own player IDs" ON public.user_player_ids;
DROP POLICY IF EXISTS "Users can update player IDs" ON public.user_player_ids;
DROP POLICY IF EXISTS "Users can delete their own player IDs" ON public.user_player_ids;
DROP POLICY IF EXISTS "Service role full access" ON public.user_player_ids;

-- Enable RLS if not already enabled
ALTER TABLE public.user_player_ids ENABLE ROW LEVEL SECURITY;

-- Allow users to view all player IDs (needed for upsert conflict checking)
CREATE POLICY "Users can view their own player IDs"
  ON public.user_player_ids
  FOR SELECT
  USING (true);

-- Allow users to insert their own player IDs
CREATE POLICY "Users can insert their own player IDs"
  ON public.user_player_ids
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update records where they are the owner
-- OR allow updating ANY record as long as the new user_id is set to current user
-- This allows device switching between accounts
CREATE POLICY "Users can update their own player IDs"
  ON public.user_player_ids
  FOR UPDATE
  USING (true)  -- Allow checking any record
  WITH CHECK (auth.uid() = user_id);  -- But only if setting user_id to current user

-- Allow users to delete their own player IDs
CREATE POLICY "Users can delete their own player IDs"
  ON public.user_player_ids
  FOR DELETE
  USING (auth.uid() = user_id);

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_player_ids TO authenticated;
