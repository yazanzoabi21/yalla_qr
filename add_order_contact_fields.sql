-- Migration: Add contact and delivery fields to orders table
-- Adds optional columns used by the checkout form

ALTER TABLE IF EXISTS orders
ADD COLUMN IF NOT EXISTS contact_name text;

ALTER TABLE IF EXISTS orders
ADD COLUMN IF NOT EXISTS delivery_address text;

ALTER TABLE IF EXISTS orders
ADD COLUMN IF NOT EXISTS delivery_phone text;

ALTER TABLE IF EXISTS orders
ADD COLUMN IF NOT EXISTS notes text;

-- Optionally you may want to set indexes if you frequently query by phone/address
-- CREATE INDEX IF NOT EXISTS idx_orders_delivery_phone ON orders (delivery_phone);
