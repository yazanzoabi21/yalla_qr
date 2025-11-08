-- ========================================
-- QR CODE SYSTEM - COMPLETE SQL SETUP
-- Copy and paste this entire file into Supabase SQL Editor
-- ========================================

-- ========================================
-- STEP 1: CREATE QR_CODES TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS public.qr_codes (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  account_id UUID NULL,
  code TEXT NOT NULL,
  scan_count INTEGER NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT qr_codes_pkey PRIMARY KEY (id),
  CONSTRAINT qr_codes_code_key UNIQUE (code),
  CONSTRAINT qr_codes_account_id_fkey FOREIGN KEY (account_id) 
    REFERENCES accounts (id) ON DELETE CASCADE
) TABLESPACE pg_default;

COMMENT ON TABLE public.qr_codes IS 'Stores QR codes associated with accounts';

-- ========================================
-- STEP 2: CREATE SCAN_LOGS TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS public.scan_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  qr_code_id UUID NULL,
  scanned_at TIMESTAMP WITH TIME ZONE NULL DEFAULT timezone('utc'::text, now()),
  location_lat NUMERIC NULL,
  location_lng NUMERIC NULL,
  device_info JSONB NULL,
  CONSTRAINT scan_logs_pkey PRIMARY KEY (id),
  CONSTRAINT scan_logs_qr_code_id_fkey FOREIGN KEY (qr_code_id) 
    REFERENCES qr_codes (id) ON DELETE CASCADE
) TABLESPACE pg_default;

COMMENT ON TABLE public.scan_logs IS 'Tracks QR code scans with location and device info';

-- ========================================
-- STEP 3: CREATE INDEXES
-- ========================================

-- QR Codes indexes
CREATE INDEX IF NOT EXISTS idx_qrcodes_account_id 
ON public.qr_codes USING btree (account_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_qrcodes_code 
ON public.qr_codes USING btree (code) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_qrcodes_created_at 
ON public.qr_codes USING btree (created_at DESC) TABLESPACE pg_default;

-- Scan Logs indexes
CREATE INDEX IF NOT EXISTS idx_scanlogs_qrcode_id 
ON public.scan_logs USING btree (qr_code_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_scanlogs_scanned_at 
ON public.scan_logs USING btree (scanned_at DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_scanlogs_qrcode_scanned 
ON public.scan_logs USING btree (qr_code_id, scanned_at DESC) TABLESPACE pg_default;

-- ========================================
-- STEP 4: ENABLE ROW LEVEL SECURITY
-- ========================================

ALTER TABLE public.qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scan_logs ENABLE ROW LEVEL SECURITY;

-- ========================================
-- STEP 5: CREATE RLS POLICIES - QR CODES
-- ========================================

-- Users can view their own QR codes
CREATE POLICY "Users can view their own qr_codes"
ON public.qr_codes FOR SELECT
USING (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Users can insert their own QR codes
CREATE POLICY "Users can insert their own qr_codes"
ON public.qr_codes FOR INSERT
WITH CHECK (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Users can update their own QR codes
CREATE POLICY "Users can update their own qr_codes"
ON public.qr_codes FOR UPDATE
USING (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
)
WITH CHECK (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Users can delete their own QR codes
CREATE POLICY "Users can delete their own qr_codes"
ON public.qr_codes FOR DELETE
USING (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Public can read QR codes for scanning
CREATE POLICY "Public can read qr_codes by code"
ON public.qr_codes FOR SELECT
USING (true);

-- ========================================
-- STEP 6: CREATE RLS POLICIES - SCAN LOGS
-- ========================================

-- Users can view scan logs for their QR codes
CREATE POLICY "Users can view their qr_code scan_logs"
ON public.scan_logs FOR SELECT
USING (
  qr_code_id IN (
    SELECT qr.id FROM public.qr_codes qr
    INNER JOIN public.accounts acc ON qr.account_id = acc.id
    WHERE acc.owner_id = auth.uid()
  )
);

-- Public can insert scan logs
CREATE POLICY "Public can insert scan_logs"
ON public.scan_logs FOR INSERT
WITH CHECK (true);

-- Users can delete their scan logs
CREATE POLICY "Users can delete their scan_logs"
ON public.scan_logs FOR DELETE
USING (
  qr_code_id IN (
    SELECT qr.id FROM public.qr_codes qr
    INNER JOIN public.accounts acc ON qr.account_id = acc.id
    WHERE acc.owner_id = auth.uid()
  )
);

-- ========================================
-- STEP 7: CREATE HELPER FUNCTIONS
-- ========================================

-- Function to increment scan count
CREATE OR REPLACE FUNCTION public.increment_scan_count(qr_code_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_count INTEGER;
BEGIN
  UPDATE public.qr_codes
  SET scan_count = scan_count + 1
  WHERE id = qr_code_id
  RETURNING scan_count INTO new_count;
  
  RETURN new_count;
END;
$$;

COMMENT ON FUNCTION public.increment_scan_count(UUID) IS 
  'Safely increments the scan count for a QR code';

-- Function to get account from QR code
CREATE OR REPLACE FUNCTION public.get_account_from_qr_code(qr_code TEXT)
RETURNS TABLE (
  account_id UUID,
  account_name TEXT,
  category_id UUID,
  description TEXT,
  location_address TEXT,
  logo_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    acc.id,
    acc.name,
    acc.category_id,
    acc.description,
    acc.location_address,
    acc.logo_url
  FROM public.qr_codes qr
  INNER JOIN public.accounts acc ON qr.account_id = acc.id
  WHERE qr.code = qr_code;
END;
$$;

COMMENT ON FUNCTION public.get_account_from_qr_code(TEXT) IS 
  'Retrieves account information from QR code for public scanning';

-- ========================================
-- SETUP COMPLETE!
-- ========================================

-- Run verification queries below to confirm setup:

-- Check qr_codes table
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'qr_codes'
ORDER BY ordinal_position;

-- Check scan_logs table
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'scan_logs'
ORDER BY ordinal_position;

-- Check indexes
SELECT indexname, indexdef FROM pg_indexes 
WHERE tablename IN ('qr_codes', 'scan_logs');

-- Check RLS policies
SELECT tablename, policyname, cmd FROM pg_policies 
WHERE tablename IN ('qr_codes', 'scan_logs')
ORDER BY tablename, policyname;

-- ========================================
-- READY TO USE!
-- Your QR code system is now set up.
-- Next: Test in your Flutter app
-- ========================================
