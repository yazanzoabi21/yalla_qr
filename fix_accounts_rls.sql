-- ========================================
-- FIX: ACCOUNTS TABLE RLS POLICIES
-- Problem: Users can see other users' accounts in the same category
-- Solution: Update RLS policies to filter by owner_id
-- ========================================

-- Step 1: Drop existing policies (if any)
DROP POLICY IF EXISTS "Users can view their own accounts" ON public.accounts;
DROP POLICY IF EXISTS "Users can insert their own accounts" ON public.accounts;
DROP POLICY IF EXISTS "Users can update their own accounts" ON public.accounts;
DROP POLICY IF EXISTS "Users can delete their own accounts" ON public.accounts;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.accounts;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.accounts;
DROP POLICY IF EXISTS "Enable update for users based on owner_id" ON public.accounts;
DROP POLICY IF EXISTS "Enable delete for users based on owner_id" ON public.accounts;

-- Step 2: Enable RLS on accounts table (if not already enabled)
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

-- Step 3: Create CORRECT RLS policies

-- Policy: Users can only SELECT their own accounts
CREATE POLICY "Users can view only their own accounts"
ON public.accounts
FOR SELECT
USING (auth.uid() = owner_id);

-- Policy: Users can only INSERT accounts they own
CREATE POLICY "Users can insert only their own accounts"
ON public.accounts
FOR INSERT
WITH CHECK (auth.uid() = owner_id);

-- Policy: Users can only UPDATE their own accounts
CREATE POLICY "Users can update only their own accounts"
ON public.accounts
FOR UPDATE
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

-- Policy: Users can only DELETE their own accounts
CREATE POLICY "Users can delete only their own accounts"
ON public.accounts
FOR DELETE
USING (auth.uid() = owner_id);

-- ========================================
-- VERIFICATION
-- ========================================

-- Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'accounts' AND schemaname = 'public';
-- Should show: rowsecurity = true

-- Check current policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'accounts'
ORDER BY policyname;

-- ========================================
-- TEST THE FIX
-- ========================================

-- Test 1: Try to select accounts (should only see your own)
SELECT id, name, email, owner_id, category_id
FROM public.accounts;
-- Should only show accounts where owner_id = your auth.uid()

-- Test 2: Verify you can't see other users' accounts
-- This should return empty (unless you're that user)
SELECT * 
FROM public.accounts 
WHERE owner_id != auth.uid();
-- Should return 0 rows

-- ========================================
-- EXPLANATION
-- ========================================

/*
BEFORE (Wrong):
- No RLS policies OR policies that allow viewing all accounts in a category
- Result: yazan can see omar's data, omar can see yazan's data

AFTER (Correct):
- RLS policies filter by owner_id = auth.uid()
- Result: yazan only sees yazan's data, omar only sees omar's data

Key Point:
The USING clause "auth.uid() = owner_id" ensures that:
- SELECT: Users can only read rows where they are the owner
- INSERT: Users can only create rows where they are the owner
- UPDATE: Users can only modify rows where they are the owner
- DELETE: Users can only delete rows where they are the owner

Even if two users (yazan and omar) are in the same category (Meals),
they will NEVER see each other's data because owner_id is different!
*/

-- ========================================
-- READY!
-- Run these commands in Supabase SQL Editor
-- ========================================
