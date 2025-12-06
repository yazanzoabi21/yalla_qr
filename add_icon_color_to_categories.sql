-- Add icon_code and color_value columns to categories table
-- icon_code will store the IconData codePoint as an integer
-- color_value will store the Color value as a hex string (e.g., '0xFFFF5722')

ALTER TABLE public.categories 
ADD COLUMN IF NOT EXISTS icon_code integer,
ADD COLUMN IF NOT EXISTS color_value text;

-- Add comments to explain the columns
COMMENT ON COLUMN public.categories.icon_code IS 'IconData codePoint for Flutter icons (e.g., 0xe532 for Icons.restaurant)';
COMMENT ON COLUMN public.categories.color_value IS 'Hex color value as string (e.g., 0xFFFF5722 for deep orange)';

-- Update existing categories with default values
UPDATE public.categories 
SET 
    icon_code = 0xe532,  -- Icons.restaurant codePoint
    color_value = '0xFFFF5722'  -- Deep Orange
WHERE LOWER(name) = 'meals' AND icon_code IS NULL;

UPDATE public.categories 
SET 
    icon_code = 0xe566,  -- Icons.fitness_center codePoint
    color_value = '0xFF009688'  -- Teal
WHERE LOWER(name) = 'gym' AND icon_code IS NULL;

-- Set default values for other categories
UPDATE public.categories 
SET 
    icon_code = 0xe14f,  -- Icons.category codePoint
    color_value = '0xFF3F51B5'  -- Indigo
WHERE icon_code IS NULL;
