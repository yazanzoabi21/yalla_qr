# Database Schema Update for Icon and Color Support

## Problem
The app is trying to save icon and color values to the `sub_category` table, but the database schema is missing the required columns:
- `icon_value` - stores the icon codePoint as TEXT
- `color_value` - stores the color value as TEXT

## Solution: Add Missing Columns

### SQL Commands to Run in Supabase Dashboard

```sql
-- Add icon_value column to store icon codePoints
ALTER TABLE sub_category 
ADD COLUMN IF NOT EXISTS icon_value TEXT;

-- Add color_value column to store color values  
ALTER TABLE sub_category 
ADD COLUMN IF NOT EXISTS color_value TEXT;

-- Verify the columns were added
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'sub_category'
ORDER BY ordinal_position;
```

### How to Run These Commands:

1. **Go to your Supabase Dashboard**
2. **Navigate to SQL Editor**
3. **Run the ALTER TABLE commands above**
4. **Verify the columns exist with the SELECT query**

### Alternative: If you want to set default values

```sql
-- Add columns with default values
ALTER TABLE sub_category 
ADD COLUMN IF NOT EXISTS icon_value TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS color_value TEXT DEFAULT NULL;

-- Update existing rows with default icons based on name
UPDATE sub_category 
SET icon_value = '58832' -- Icons.restaurant codePoint
WHERE icon_value IS NULL;

UPDATE sub_category 
SET color_value = '4294924066' -- Colors.blue value  
WHERE color_value IS NULL;
```

### Icon CodePoint Reference:
```dart
Icons.restaurant: 58832
Icons.breakfast_dining: 58831
Icons.lunch_dining: 58889
Icons.dinner_dining: 58835
Icons.set_meal: 59064
Icons.fastfood: 58842
Icons.cake: 57819
Icons.coffee: 58827
```

### Color Value Reference:
```dart
Colors.deepOrange: 4294924066
Colors.blue: 4280391411
Colors.green: 4283215696
Colors.red: 4294198070
Colors.purple: 4287679225
Colors.teal: 4284513675
```

## After Running SQL Commands

1. **Test the app** - Icon selection should now work
2. **Check debug logs** - Should see successful icon parsing
3. **Icons should persist** - No more fallback icons after restart

## If Issues Persist

1. Check Supabase RLS (Row Level Security) policies
2. Verify column permissions
3. Check database user permissions
