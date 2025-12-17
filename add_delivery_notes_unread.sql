-- Add delivery note unread flag to order_delivery_assignments
ALTER TABLE order_delivery_assignments
ADD COLUMN IF NOT EXISTS delivery_notes_unread boolean DEFAULT false;

COMMENT ON COLUMN order_delivery_assignments.delivery_notes_unread IS 'Set to true when delivery leaves/updates a note; cleared when ORG views the note or when delivery completes the order.';
