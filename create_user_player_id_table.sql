-- ========================================
-- CREATE USER_PLAYER_IDS TABLE
-- Stores OneSignal player IDs for each user
-- ========================================

CREATE TABLE IF NOT EXISTS public.user_player_ids (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  player_id TEXT NOT NULL,
  device_type VARCHAR(50) NULL DEFAULT 'unknown',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  CONSTRAINT user_player_ids_pkey PRIMARY KEY (id),
  CONSTRAINT user_player_ids_user_id_fkey FOREIGN KEY (user_id) 
    REFERENCES auth.users (id) ON DELETE CASCADE,
  CONSTRAINT user_player_ids_unique_player UNIQUE (player_id)
) TABLESPACE pg_default;

COMMENT ON TABLE public.user_player_ids IS 'Stores OneSignal player IDs for push notifications per user login';
COMMENT ON COLUMN public.user_player_ids.user_id IS 'Reference to the authenticated user';
COMMENT ON COLUMN public.user_player_ids.player_id IS 'OneSignal Player ID received during login';
COMMENT ON COLUMN public.user_player_ids.device_type IS 'Device type (android, ios, web)';
COMMENT ON COLUMN public.user_player_ids.is_active IS 'Whether this device is currently active';

-- ========================================
-- CREATE INDEXES
-- ========================================

CREATE INDEX IF NOT EXISTS idx_user_player_ids_user_id 
ON public.user_player_ids USING btree (user_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_player_ids_player_id 
ON public.user_player_ids USING btree (player_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_player_ids_active 
ON public.user_player_ids USING btree (is_active) TABLESPACE pg_default;

-- ========================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ========================================

ALTER TABLE public.user_player_ids ENABLE ROW LEVEL SECURITY;

-- Users can only see their own player IDs
CREATE POLICY "Users can view their own player IDs"
  ON public.user_player_ids
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own player IDs
CREATE POLICY "Users can insert their own player IDs"
  ON public.user_player_ids
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own player IDs
CREATE POLICY "Users can update their own player IDs"
  ON public.user_player_ids
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Service role can do all operations (for backend use)
CREATE POLICY "Service role full access"
  ON public.user_player_ids
  FOR ALL
  USING (true)
  WITH CHECK (true);
