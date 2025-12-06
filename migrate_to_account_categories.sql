-- Migration: Populate account_categories for existing accounts
-- This creates the many-to-many relationship between accounts and categories

-- Step 1: For each user, link their ORG account to all parent categories
-- This ensures the ORG account can create products in any category
INSERT INTO account_categories (account_id, category_id, is_hidden)
SELECT 
    a.id as account_id,
    c.id as category_id,
    false as is_hidden
FROM accounts a
CROSS JOIN categories c
WHERE 
    a.role = 'ORG'
    AND c.parent_id IS NULL  -- Only parent categories
ON CONFLICT (account_id, category_id) DO NOTHING;

-- Step 2: If you want to also link ORG to child categories (optional)
-- Uncomment the following if you want ORG account to access all categories
/*
INSERT INTO account_categories (account_id, category_id, is_hidden)
SELECT 
    a.id as account_id,
    c.id as category_id,
    false as is_hidden
FROM accounts a
CROSS JOIN categories c
WHERE a.role = 'ORG'
ON CONFLICT (account_id, category_id) DO NOTHING;
*/

-- Verify the migration
SELECT 
    a.name as account_name,
    COUNT(ac.category_id) as linked_categories
FROM accounts a
LEFT JOIN account_categories ac ON a.id = ac.account_id
GROUP BY a.id, a.name
ORDER BY a.name;
