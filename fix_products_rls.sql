-- ========================================
-- FIX: PRODUCTS TABLE RLS POLICIES
-- Ensure users only see products from their own accounts
-- ========================================

-- Step 1: Drop existing policies (if any)
DROP POLICY IF EXISTS "Users can view their own products" ON public.products;
DROP POLICY IF EXISTS "Users can insert their own products" ON public.products;
DROP POLICY IF EXISTS "Users can update their own products" ON public.products;
DROP POLICY IF EXISTS "Users can delete their own products" ON public.products;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.products;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.products;
DROP POLICY IF EXISTS "Enable update for users based on account" ON public.products;
DROP POLICY IF EXISTS "Enable delete for users based on account" ON public.products;

-- Step 2: Enable RLS on products table
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Step 3: Create CORRECT RLS policies for products

-- Policy: Users can only view products from their own accounts
CREATE POLICY "Users can view only their own products"
ON public.products
FOR SELECT
USING (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Policy: Users can only insert products to their own accounts
CREATE POLICY "Users can insert only their own products"
ON public.products
FOR INSERT
WITH CHECK (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Policy: Users can only update their own products
CREATE POLICY "Users can update only their own products"
ON public.products
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

-- Policy: Users can only delete their own products
CREATE POLICY "Users can delete only their own products"
ON public.products
FOR DELETE
USING (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- ========================================
-- VERIFICATION
-- ========================================

-- Check RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'products' AND schemaname = 'public';

-- Check policies
SELECT policyname, cmd, qual
FROM pg_policies 
WHERE tablename = 'products'
ORDER BY policyname;

-- Test query (should only return your products)
SELECT p.id, p.name, p.account_id, a.owner_id
FROM public.products p
JOIN public.accounts a ON p.account_id = a.id;
-- Should only show products where a.owner_id = your auth.uid()

-- ========================================
-- EXPLANATION
-- ========================================

/*
The key difference from accounts table:
- Accounts: Direct check (owner_id = auth.uid())
- Products: Indirect check through accounts table

Products don't have owner_id directly, but they have account_id.
So we check if the account_id belongs to an account owned by the user.

Subquery: 
  account_id IN (SELECT id FROM accounts WHERE owner_id = auth.uid())

This ensures:
- User yazan can only see/edit products linked to yazan's accounts
- User omar can only see/edit products linked to omar's accounts
- Even if both are in the same category (Meals)
*/
