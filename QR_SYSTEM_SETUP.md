# QR Code System - Complete Database Setup

## Overview
This document contains all SQL commands needed to set up the QR code system for the Yalla QR application. This includes the `qr_codes` and `scan_logs` tables with proper relationships, indexes, and security policies.

## System Architecture

```
┌─────────────┐
│ auth.users  │
└──────┬──────┘
       │
       ▼
┌─────────────┐         ┌──────────────┐
│ categories  │◄────────┤  accounts    │
└─────────────┘         │──────────────│
                        │ id (PK)      │───┐
                        │ owner_id (FK)│   │
                        │ category_id  │   │
                        │ name         │   │
                        │ email        │   │
                        │ ...          │   │
                        └──────────────┘   │
                                           │ ON DELETE CASCADE
                                           │
                                           ▼
                        ┌──────────────────────┐
                        │    qr_codes          │
                        │──────────────────────│
                        │ id (PK)              │───┐
                        │ account_id (FK)      │   │
                        │ code (UNIQUE)        │   │
                        │ scan_count           │   │
                        │ created_at           │   │
                        └──────────────────────┘   │
                                                   │ ON DELETE CASCADE
                                                   │
                                                   ▼
                        ┌──────────────────────────┐
                        │     scan_logs            │
                        │──────────────────────────│
                        │ id (PK)                  │
                        │ qr_code_id (FK)          │
                        │ scanned_at               │
                        │ location_lat             │
                        │ location_lng             │
                        │ device_info (JSONB)      │
                        └──────────────────────────┘
```

---

## Prerequisites

Before running these commands, ensure:
- ✅ The `accounts` table exists
- ✅ The `categories` table exists
- ✅ You have access to Supabase SQL Editor
- ✅ You are logged in as a superuser or have appropriate permissions

---

## Step 1: Create QR Codes Table

```sql
-- Create qr_codes table
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

-- Add table comment
COMMENT ON TABLE public.qr_codes IS 'Stores QR codes associated with accounts for customer scanning and app downloads';

-- Add column comments
COMMENT ON COLUMN public.qr_codes.id IS 'Unique identifier for the QR code';
COMMENT ON COLUMN public.qr_codes.account_id IS 'Foreign key to accounts table';
COMMENT ON COLUMN public.qr_codes.code IS 'Unique QR code string that customers will scan';
COMMENT ON COLUMN public.qr_codes.scan_count IS 'Total number of times this QR code has been scanned';
COMMENT ON COLUMN public.qr_codes.created_at IS 'Timestamp when the QR code was generated';
```

---

## Step 2: Create Scan Logs Table

```sql
-- Create scan_logs table
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

-- Add table comment
COMMENT ON TABLE public.scan_logs IS 'Tracks individual QR code scans with location and device information';

-- Add column comments
COMMENT ON COLUMN public.scan_logs.id IS 'Unique identifier for the scan log entry';
COMMENT ON COLUMN public.scan_logs.qr_code_id IS 'Foreign key to qr_codes table';
COMMENT ON COLUMN public.scan_logs.scanned_at IS 'Timestamp when the QR code was scanned';
COMMENT ON COLUMN public.scan_logs.location_lat IS 'Latitude coordinate of scan location';
COMMENT ON COLUMN public.scan_logs.location_lng IS 'Longitude coordinate of scan location';
COMMENT ON COLUMN public.scan_logs.device_info IS 'JSON object containing device information (platform, model, OS version, etc.)';
```

---

## Step 3: Create Performance Indexes

```sql
-- Indexes for qr_codes table
CREATE INDEX IF NOT EXISTS idx_qrcodes_account_id 
ON public.qr_codes USING btree (account_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_qrcodes_code 
ON public.qr_codes USING btree (code) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_qrcodes_created_at 
ON public.qr_codes USING btree (created_at DESC) 
TABLESPACE pg_default;

-- Indexes for scan_logs table
CREATE INDEX IF NOT EXISTS idx_scanlogs_qrcode_id 
ON public.scan_logs USING btree (qr_code_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_scanlogs_scanned_at 
ON public.scan_logs USING btree (scanned_at DESC) 
TABLESPACE pg_default;

-- Composite index for date-range queries
CREATE INDEX IF NOT EXISTS idx_scanlogs_qrcode_scanned 
ON public.scan_logs USING btree (qr_code_id, scanned_at DESC) 
TABLESPACE pg_default;
```

---

## Step 4: Enable Row Level Security (RLS)

```sql
-- Enable RLS on qr_codes table
ALTER TABLE public.qr_codes ENABLE ROW LEVEL SECURITY;

-- Enable RLS on scan_logs table
ALTER TABLE public.scan_logs ENABLE ROW LEVEL SECURITY;
```

---

## Step 5: Create RLS Policies for QR Codes

```sql
-- Policy: Users can view their own QR codes
CREATE POLICY "Users can view their own qr_codes"
ON public.qr_codes
FOR SELECT
USING (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Policy: Users can insert QR codes for their accounts
CREATE POLICY "Users can insert their own qr_codes"
ON public.qr_codes
FOR INSERT
WITH CHECK (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Policy: Users can update their own QR codes
CREATE POLICY "Users can update their own qr_codes"
ON public.qr_codes
FOR UPDATE
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

-- Policy: Users can delete their own QR codes
CREATE POLICY "Users can delete their own qr_codes"
ON public.qr_codes
FOR DELETE
USING (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Policy: Allow public to read QR codes (for scanning)
CREATE POLICY "Public can read qr_codes by code"
ON public.qr_codes
FOR SELECT
USING (true);
```

---

## Step 6: Create RLS Policies for Scan Logs

```sql
-- Policy: Users can view scan logs for their QR codes
CREATE POLICY "Users can view their qr_code scan_logs"
ON public.scan_logs
FOR SELECT
USING (
  qr_code_id IN (
    SELECT qr.id FROM public.qr_codes qr
    INNER JOIN public.accounts acc ON qr.account_id = acc.id
    WHERE acc.owner_id = auth.uid()
  )
);

-- Policy: Anyone can insert scan logs (for public scanning)
CREATE POLICY "Public can insert scan_logs"
ON public.scan_logs
FOR INSERT
WITH CHECK (true);

-- Policy: Users can delete scan logs for their QR codes
CREATE POLICY "Users can delete their scan_logs"
ON public.scan_logs
FOR DELETE
USING (
  qr_code_id IN (
    SELECT qr.id FROM public.qr_codes qr
    INNER JOIN public.accounts acc ON qr.account_id = acc.id
    WHERE acc.owner_id = auth.uid()
  )
);
```

---

## Step 7: Create Helper Functions

### Function to Increment Scan Count

```sql
-- Create function to safely increment scan count
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

-- Add comment to function
COMMENT ON FUNCTION public.increment_scan_count(UUID) IS 
  'Safely increments the scan count for a QR code. Uses SECURITY DEFINER to bypass RLS.';
```

### Function to Get Account Info from QR Code

```sql
-- Create function to get account information from QR code
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

-- Add comment to function
COMMENT ON FUNCTION public.get_account_from_qr_code(TEXT) IS 
  'Retrieves account information associated with a QR code. Public access for customer scanning.';
```

---

## Step 8: Verification Queries

Run these queries to verify the setup:

### Check Tables

```sql
-- Verify qr_codes table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'qr_codes'
ORDER BY ordinal_position;

-- Verify scan_logs table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'scan_logs'
ORDER BY ordinal_position;
```

### Check Indexes

```sql
-- Check qr_codes indexes
SELECT 
  indexname, 
  indexdef
FROM pg_indexes 
WHERE tablename = 'qr_codes';

-- Check scan_logs indexes
SELECT 
  indexname, 
  indexdef
FROM pg_indexes 
WHERE tablename = 'scan_logs';
```

### Check Foreign Keys

```sql
-- Check foreign key constraints
SELECT
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints AS rc
  ON tc.constraint_name = rc.constraint_name
WHERE tc.table_name IN ('qr_codes', 'scan_logs')
  AND tc.constraint_type = 'FOREIGN KEY';
```

### Check RLS Policies

```sql
-- Check RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename IN ('qr_codes', 'scan_logs')
ORDER BY tablename, policyname;
```

### Check Functions

```sql
-- Check functions
SELECT 
  routine_name,
  routine_type,
  data_type,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('increment_scan_count', 'get_account_from_qr_code');
```

---

## Step 9: Test the Setup

### Test QR Code Creation

```sql
-- Insert test account (if needed)
INSERT INTO public.accounts (owner_id, name, email, category_id)
VALUES (auth.uid(), 'Test Business', 'test@example.com', NULL)
RETURNING id;

-- Create test QR code
INSERT INTO public.qr_codes (account_id, code)
VALUES ('your-account-id-here', 'TEST-QR-CODE-001')
RETURNING *;

-- Verify QR code was created
SELECT * FROM public.qr_codes WHERE code = 'TEST-QR-CODE-001';
```

### Test Scan Logging

```sql
-- Log a test scan
INSERT INTO public.scan_logs (
  qr_code_id, 
  location_lat, 
  location_lng,
  device_info
)
VALUES (
  (SELECT id FROM public.qr_codes WHERE code = 'TEST-QR-CODE-001'),
  40.7128,
  -74.0060,
  '{"platform": "iOS", "version": "16.0", "model": "iPhone 14"}'::jsonb
)
RETURNING *;

-- Increment scan count
SELECT increment_scan_count(
  (SELECT id FROM public.qr_codes WHERE code = 'TEST-QR-CODE-001')
);

-- Verify scan count increased
SELECT code, scan_count FROM public.qr_codes WHERE code = 'TEST-QR-CODE-001';

-- Get account from QR code
SELECT * FROM get_account_from_qr_code('TEST-QR-CODE-001');
```

### Test Statistics Query

```sql
-- Get scan statistics for last 7 days
SELECT 
  DATE(scanned_at) as scan_date,
  COUNT(*) as scan_count
FROM public.scan_logs
WHERE qr_code_id = (SELECT id FROM public.qr_codes WHERE code = 'TEST-QR-CODE-001')
  AND scanned_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(scanned_at)
ORDER BY scan_date DESC;
```

### Cleanup Test Data

```sql
-- Clean up test data
DELETE FROM public.qr_codes WHERE code = 'TEST-QR-CODE-001';
```

---

## How to Run These Commands

1. **Open Supabase Dashboard**: https://app.supabase.com
2. **Select Your Project**
3. **Navigate to SQL Editor** (left sidebar)
4. **Create a New Query**
5. **Copy and Paste** each step's SQL commands
6. **Run Each Step** one at a time (click "Run" or Ctrl+Enter)
7. **Verify Results** using the verification queries
8. **Run Tests** to ensure everything works

---

## Expected Results

After successful setup, you should have:

✅ `qr_codes` table with proper structure and constraints  
✅ `scan_logs` table with proper structure and constraints  
✅ All indexes created for optimal performance  
✅ Row Level Security enabled on both tables  
✅ RLS policies configured for user access control  
✅ Public access for QR code scanning  
✅ Helper functions for scan counting and data retrieval  
✅ Cascade delete behavior (deleting account deletes QR codes and scan logs)  

---

## User Flow

### For Business Owners (Account Holders):

1. **Sign up** → Account created automatically
2. **QR code generated** automatically with account
3. **View QR code** in app dashboard
4. **Share QR code** (print, display, social media)
5. **Track scans** via statistics dashboard
6. **View scan history** with location data

### For Customers (App Users):

1. **See QR code** at business location
2. **Scan QR code** with any QR scanner
3. **Redirected** to app download page or deep link
4. **Scan logged** with location and device info
5. **Business sees analytics** from the scan

---

## Troubleshooting

### Issue: Foreign Key Constraint Fails
**Cause**: The `accounts` table doesn't exist  
**Solution**: Create the `accounts` table first before creating `qr_codes`

### Issue: RLS Policies Block Access
**Cause**: User doesn't own the account  
**Solution**: Ensure `auth.uid()` matches the account's `owner_id`

### Issue: Cannot Insert Scan Log
**Cause**: QR code doesn't exist or wrong ID  
**Solution**: Verify the QR code exists with the correct ID

### Issue: Scan Count Not Incrementing
**Cause**: Function doesn't exist or RLS blocking  
**Solution**: Use the `increment_scan_count()` function with SECURITY DEFINER

### Issue: Public Cannot Scan
**Cause**: RLS policy too restrictive  
**Solution**: Ensure "Public can read qr_codes by code" policy exists

---

## Security Considerations

- ✅ **RLS Enabled**: Prevents unauthorized access to QR codes and scan logs
- ✅ **Cascade Delete**: Ensures data integrity when accounts are deleted
- ✅ **Public Scanning**: Allows anyone to scan QR codes without authentication
- ✅ **Owner Access**: Only account owners can view their scan analytics
- ✅ **SECURITY DEFINER**: Functions bypass RLS for necessary operations
- ⚠️ **Device Info**: Be mindful of privacy when collecting device information

---

## Next Steps

1. ✅ **Update Flutter App**: Integrate QR code service
2. ✅ **Generate QR Codes**: On account creation
3. ✅ **Display QR Codes**: In business dashboard
4. ✅ **Scan Tracking**: Log scans from customer app
5. ✅ **Analytics Dashboard**: Show scan statistics
6. 📱 **QR Code Widget**: Use `qr_flutter` package for display
7. 🔗 **Deep Links**: Configure app deep linking for scans
8. 📊 **Export Data**: Allow businesses to export scan data

---

## Related Files

- **Models**: `lib/models/qr_code.dart`, `lib/models/scan_log.dart`, `lib/models/account.dart`
- **Services**: `lib/services/qr_code_service.dart`, `lib/services/auth_service.dart`
- **Widgets**: `lib/widgets/qr_code_widget.dart`

---

## Support

If you encounter issues:
1. Check Supabase logs for errors
2. Verify RLS policies are correct
3. Ensure foreign keys reference existing records
4. Test queries in SQL Editor before running in app
5. Check Flutter console for error messages

---

**Last Updated**: November 8, 2025  
**Version**: 1.0  
**Status**: Ready for Production
