-- Link parent categories (like "Meals", "Gym", etc.) to all ORG accounts
-- This ensures each organization can see the parent categories

-- Insert parent categories for all ORG accounts
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

-- Verify the links
SELECT 
    a.name as account_name,
    a.owner_id,
    COUNT(ac.category_id) as linked_parent_categories,
    STRING_AGG(c.name, ', ') as category_names
FROM accounts a
LEFT JOIN account_categories ac ON a.id = ac.account_id
LEFT JOIN categories c ON ac.category_id = c.id AND c.parent_id IS NULL
WHERE a.role = 'ORG'
GROUP BY a.id, a.name, a.owner_id
ORDER BY a.name;
