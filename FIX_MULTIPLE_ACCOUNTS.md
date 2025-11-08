# Fix: Multiple Accounts Per User (One Per Category)

## 🐛 Problem Identified

**Issue**: When a user creates a new account in a different category, it was updating the existing account instead of creating a new one.

**Example**:
1. User creates account in **Meals** category → Works fine
2. Same user creates account in **Gym** category → **OVERWRITES** Meals account ❌
3. When logging into Gym, shows Meals data ❌

**Root Cause**: The code was checking only `owner_id` without considering `category_id`, treating each user as having only ONE account total.

---

## ✅ Solution Implemented

**Fixed Logic**: Now checks BOTH `owner_id` AND `category_id` together, allowing users to have **multiple accounts** (one per category).

### What Changed:

**Before** (Incorrect):
```dart
// Only checked owner_id - BAD!
final existingAccount = await _client
    .from('accounts')
    .select('id')
    .eq('owner_id', userId)  // ❌ Missing category check
    .maybeSingle();
```

**After** (Correct):
```dart
// Checks BOTH owner_id AND category_id - GOOD!
final accountQuery = _client
    .from('accounts')
    .select('id')
    .eq('owner_id', userId);

if (categoryId != null) {
  accountQuery.eq('category_id', categoryId);  // ✅ Check category too!
} else {
  accountQuery.is_('category_id', null);
}

final existingAccount = await accountQuery.maybeSingle();
```

---

## 🎯 How It Works Now

### Scenario 1: User Creates Account in Meals
```
User: john@example.com
Category: Meals
Result: Creates NEW account with category_id = meals_uuid
```

### Scenario 2: Same User Creates Account in Gym
```
User: john@example.com
Category: Gym
Result: Creates ANOTHER NEW account with category_id = gym_uuid
```

### Scenario 3: User Logs Into Meals
```
Query: owner_id = john_id AND category_id = meals_uuid
Result: Shows MEALS account data ✅
```

### Scenario 4: User Logs Into Gym
```
Query: owner_id = john_id AND category_id = gym_uuid
Result: Shows GYM account data ✅
```

---

## 📊 Database Structure

```
accounts table:
┌────────┬──────────┬─────────────┬────────────┬──────────┐
│   id   │ owner_id │ category_id │    name    │  email   │
├────────┼──────────┼─────────────┼────────────┼──────────┤
│ uuid-1 │  john    │  meals-id   │ John's Cafe│ john@... │
│ uuid-2 │  john    │  gym-id     │ John's Gym │ john@... │
│ uuid-3 │  yazan   │  meals-id   │ Yazan Food │ yazan@.. │
└────────┴──────────┴─────────────┴────────────┴──────────┘

Same user (john) → Multiple accounts (different categories) ✅
```

---

## 🔑 Key Points

### Unique Constraint Logic:
- **Unique Key**: `(owner_id + category_id)` combination
- Same user can have multiple accounts
- But only ONE account per category

### Update vs Insert:
- **If exists** (owner_id + category_id match): UPDATE the account
- **If not exists**: INSERT new account

### Null Category Handling:
- If `category_id` is NULL, checks for accounts with NULL category
- Allows for "general" accounts without category

---

## 🧪 Testing

### Test Case 1: Create Multiple Accounts
```dart
// Create account in Meals
await authService.signUpUser(
  email: 'test@example.com',
  password: 'password',
  name: 'My Restaurant',
  categoryName: 'Meals',
);
// Result: Account created with meals category_id

// Create account in Gym (same email, different category)
await authService.signUpUser(
  email: 'test@example.com',
  password: 'password',
  name: 'My Gym',
  categoryName: 'Gym',
);
// Result: NEW account created with gym category_id ✅
```

### Test Case 2: Login to Different Categories
```dart
// Login to Meals
await authService.signInUserForCategory(
  email: 'test@example.com',
  password: 'password',
  categoryName: 'Meals',
);
// Shows: My Restaurant data ✅

// Login to Gym
await authService.signInUserForCategory(
  email: 'test@example.com',
  password: 'password',
  categoryName: 'Gym',
);
// Shows: My Gym data ✅
```

---

## 🚀 What to Do Now

### 1. Test the Fix:
- Create a new account in Meals category
- Create another account in Gym category (same user)
- Login to each category separately
- Verify each shows correct data

### 2. Check Database:
```sql
-- See all accounts for a user
SELECT id, name, category_id, email
FROM accounts
WHERE owner_id = 'your-user-id'
ORDER BY category_id;

-- Should show multiple rows (one per category)
```

### 3. Clean Up Old Data (Optional):
If you have test accounts with wrong category assignments:
```sql
-- Delete test accounts
DELETE FROM accounts WHERE email = 'test@example.com';

-- Or update category_id if needed
UPDATE accounts 
SET category_id = 'correct-category-id'
WHERE id = 'account-id';
```

---

## 📋 Summary

### Fixed Issues:
✅ Users can now create multiple accounts (one per category)  
✅ Each category login shows correct account data  
✅ No more data overwriting between categories  
✅ QR codes are generated for each account separately  

### How It's Fixed:
- Modified `signUpUser()` in `auth_service.dart`
- Now checks BOTH `owner_id` AND `category_id`
- Creates separate accounts per category
- Updates only the specific category account

---

## 🔍 Related Files Modified

- ✅ `lib/services/auth_service.dart` - Fixed signup logic

---

**Status**: ✅ Fixed and Ready to Test!
