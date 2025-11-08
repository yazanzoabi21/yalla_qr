# Fix: Users Seeing Each Other's Data in Same Category

## 🐛 The Problem

**Symptom**: When two users create accounts in the same category (e.g., both yazan and omar in Meals), they see each other's data.

**Example**:
- User `yazan@gmail.com` creates account in **Meals** → Adds restaurant data
- User `omar@gmail.com` creates account in **Meals** → Sees yazan's restaurant data ❌
- Both see the same products, same settings, same everything ❌

---

## 🔍 Root Cause

**The issue is NOT in Flutter code** - the app correctly filters by `owner_id`:

```dart
// This is CORRECT in Flutter
final query = Supabase.instance.client
    .from('accounts')
    .select('*, categories(*)')
    .eq('owner_id', user.id);  // ✅ Correctly filters by owner
```

**The issue IS in Supabase RLS (Row Level Security) policies**:
- Either RLS is **disabled** on the accounts table
- Or RLS policies are **too permissive** (allowing users to see all accounts in a category)
- The database is allowing the query to return ALL accounts, ignoring the owner_id filter

---

## 🏗️ Database Structure

```
accounts table:
┌─────────────┬──────────────┬─────────────┬──────────────┬───────────────┐
│     id      │   owner_id   │ category_id │     name     │     email     │
├─────────────┼──────────────┼─────────────┼──────────────┼───────────────┤
│ account-1   │  yazan-uid   │  meals-id   │ Yazan's Rest │ yazan@...     │
│ account-2   │  omar-uid    │  meals-id   │ Omar's Cafe  │ omar@...      │
└─────────────┴──────────────┴─────────────┴──────────────┴───────────────┘

❌ WITHOUT proper RLS: Both users can see both accounts
✅ WITH proper RLS: Each user sees only their own account
```

---

## ✅ The Solution

### Fix RLS Policies on Multiple Tables:

1. **accounts table** - Main user account data
2. **products table** - Products linked to accounts
3. **qr_codes table** - QR codes linked to accounts
4. **scan_logs table** - Scan logs linked to QR codes

---

## 🛠️ Step-by-Step Fix

### Step 1: Fix Accounts Table RLS

**Run this SQL in Supabase:**

```sql
-- Enable RLS
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Users can view their own accounts" ON public.accounts;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.accounts;

-- Create new correct policies
CREATE POLICY "Users can view only their own accounts"
ON public.accounts
FOR SELECT
USING (auth.uid() = owner_id);

CREATE POLICY "Users can insert only their own accounts"
ON public.accounts
FOR INSERT
WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update only their own accounts"
ON public.accounts
FOR UPDATE
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can delete only their own accounts"
ON public.accounts
FOR DELETE
USING (auth.uid() = owner_id);
```

**What this does**:
- `USING (auth.uid() = owner_id)` means users can ONLY see/edit/delete rows where they are the owner
- Even if yazan and omar are in the same category, they'll never see each other's data

---

### Step 2: Fix Products Table RLS

Products don't have `owner_id` directly, but they have `account_id`. We need to check through the accounts table:

```sql
-- Enable RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Create policies that check ownership through accounts
CREATE POLICY "Users can view only their own products"
ON public.products
FOR SELECT
USING (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);

-- Similar for INSERT, UPDATE, DELETE
-- (See fix_products_rls.sql for complete code)
```

---

### Step 3: Fix QR Codes Table RLS

Already handled in `qr_system_setup.sql`, but verify:

```sql
CREATE POLICY "Users can view their own qr_codes"
ON public.qr_codes
FOR SELECT
USING (
  account_id IN (
    SELECT id FROM public.accounts WHERE owner_id = auth.uid()
  )
);
```

---

## 🚀 How to Apply the Fix

### Option 1: Use the SQL Files (Recommended)

1. **Open Supabase Dashboard** → SQL Editor
2. **Run `fix_accounts_rls.sql`** first
3. **Run `fix_products_rls.sql`** second
4. **Verify** with the test queries in each file

### Option 2: Manual Verification

Check if RLS is enabled:
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('accounts', 'products', 'qr_codes', 'scan_logs')
  AND schemaname = 'public';
```

Should show `rowsecurity = true` for all tables.

Check current policies:
```sql
SELECT tablename, policyname, cmd, qual
FROM pg_policies 
WHERE tablename IN ('accounts', 'products', 'qr_codes', 'scan_logs')
ORDER BY tablename, policyname;
```

Should show policies with `auth.uid() = owner_id` checks.

---

## 🧪 Test the Fix

### Before Fix:
```sql
-- As user yazan
SELECT * FROM accounts;
-- Returns: yazan's account AND omar's account ❌

-- As user omar
SELECT * FROM accounts;
-- Returns: omar's account AND yazan's account ❌
```

### After Fix:
```sql
-- As user yazan
SELECT * FROM accounts;
-- Returns: ONLY yazan's account ✅

-- As user omar
SELECT * FROM accounts;
-- Returns: ONLY omar's account ✅
```

---

## 📱 Test in Flutter App

### Test Scenario:

1. **Create Account 1**:
   - Email: yazan@gmail.com
   - Category: Meals
   - Name: Yazan's Restaurant
   - Add some products

2. **Logout**

3. **Create Account 2**:
   - Email: omar@gmail.com
   - Category: Meals
   - Name: Omar's Cafe
   - Add different products

4. **Login as yazan**:
   - Should see: Yazan's Restaurant ✅
   - Should see: Only yazan's products ✅
   - Should NOT see: Omar's data ❌

5. **Login as omar**:
   - Should see: Omar's Cafe ✅
   - Should see: Only omar's products ✅
   - Should NOT see: Yazan's data ❌

---

## 🔐 Security Explanation

### RLS (Row Level Security)

RLS is a PostgreSQL feature that filters database queries based on the user making the request.

**Without RLS**:
```sql
SELECT * FROM accounts WHERE owner_id = 'yazan-uid';
-- Database returns ALL accounts (ignores the filter!) ❌
```

**With RLS**:
```sql
SELECT * FROM accounts WHERE owner_id = 'yazan-uid';
-- Database returns ONLY accounts where:
-- 1. owner_id = 'yazan-uid' (from query)
-- 2. AND auth.uid() = owner_id (from RLS policy) ✅
```

### Key Points:

1. **RLS is enforced at database level** - Even if someone bypasses your Flutter app, they can't see other users' data
2. **`auth.uid()`** - Supabase function that returns the currently authenticated user's ID
3. **USING clause** - Determines which rows can be selected/updated/deleted
4. **WITH CHECK clause** - Determines which values can be inserted/updated

---

## 🎯 Why This Happened

### Common Scenarios:

1. **RLS Not Enabled**: Table was created without RLS
2. **Wrong Policies**: Policies created but too permissive (e.g., allowing all authenticated users)
3. **Missing Policies**: Only some operations have policies (e.g., INSERT but not SELECT)
4. **Policy Conflicts**: Multiple policies that contradict each other

### In Your Case:

Most likely: **RLS was disabled** or **policies were too permissive**.

---

## 📋 Checklist

After applying the fix, verify:

- [ ] RLS is enabled on accounts table
- [ ] RLS is enabled on products table
- [ ] RLS is enabled on qr_codes table
- [ ] RLS is enabled on scan_logs table
- [ ] Policies check `auth.uid() = owner_id` for accounts
- [ ] Policies check through accounts for products/qr_codes/scan_logs
- [ ] Test with multiple users in same category
- [ ] Each user sees only their own data

---

## 🆘 Troubleshooting

### Issue: Still seeing other users' data after fix

**Check**:
1. Did you run the SQL in Supabase SQL Editor?
2. Did you refresh your app after applying fix?
3. Check Supabase logs for RLS policy errors

**Debug Query**:
```sql
-- Check what the current user can see
SELECT 
  a.id,
  a.name,
  a.owner_id,
  auth.uid() as current_user_id,
  (a.owner_id = auth.uid()) as is_owner
FROM accounts a;
```

### Issue: Can't insert new accounts

**Cause**: RLS policy blocking inserts  
**Solution**: Check WITH CHECK clause allows `auth.uid() = owner_id`

### Issue: "permission denied for table accounts"

**Cause**: RLS is working! User trying to access unauthorized data  
**Solution**: This is correct behavior - fix your app to only request owned data

---

## 📁 Files Created

1. **`fix_accounts_rls.sql`** - Fix accounts table RLS policies
2. **`fix_products_rls.sql`** - Fix products table RLS policies
3. **`FIX_DATA_ISOLATION_ISSUE.md`** - This documentation

---

## 🎓 Learn More

- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL RLS Documentation](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)

---

## ✅ Summary

**Problem**: Users in same category see each other's data  
**Cause**: Missing or incorrect RLS policies  
**Solution**: Enable RLS with proper owner_id filtering  
**Result**: Each user sees only their own data, even in same category  

**Run the SQL files in Supabase SQL Editor and test!** 🚀
