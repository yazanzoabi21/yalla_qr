-- Add delivery_notes column to order_delivery_assignments table
-- This allows delivery drivers to add notes about delivery issues

ALTER TABLE order_delivery_assignments
ADD COLUMN IF NOT EXISTS delivery_notes TEXT;

-- Add comment to explain the column
COMMENT ON COLUMN order_delivery_assignments.delivery_notes IS 'Notes from delivery driver to organization (e.g., cannot deliver, customer not available, address issues)';
