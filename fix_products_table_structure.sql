-- Fix products table structure
-- Add missing category_id column and ensure all required columns exist

-- Add category_id column if it doesn't exist
ALTER TABLE products ADD COLUMN IF NOT EXISTS category_id uuid;

-- Add foreign key constraint if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_category_id_fkey'
    ) THEN
        ALTER TABLE products 
        ADD CONSTRAINT products_category_id_fkey 
        FOREIGN KEY (category_id) 
        REFERENCES categories(id) 
        ON DELETE CASCADE;
    END IF;
END $$;

-- Create index on category_id for better query performance
CREATE INDEX IF NOT EXISTS idx_products_category_id 
ON products(category_id);

-- Verify the table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'products'
ORDER BY ordinal_position;
