-- Add quantity field to products table
-- This will track available stock quantity for each product

ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS quantity integer DEFAULT 0;

-- Add comment to explain the column
COMMENT ON COLUMN public.products.quantity IS 'Available stock quantity. 0 means out of stock.';

-- Update existing products: if in_stock is true, set quantity to 10, else 0
UPDATE public.products 
SET quantity = CASE 
    WHEN in_stock = true THEN 10 
    ELSE 0 
END
WHERE quantity IS NULL OR quantity = 0;

-- Create index for faster queries on quantity
CREATE INDEX IF NOT EXISTS idx_products_quantity ON public.products(quantity);
