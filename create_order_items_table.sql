-- Order Items Table
-- This table stores individual items within an order

CREATE TABLE public.order_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL,
  product_id uuid NOT NULL,
  product_name text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  unit_price numeric NOT NULL,
  currency_code text NOT NULL,
  product_image_url text NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT order_items_pkey PRIMARY KEY (id),
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
) TABLESPACE pg_default;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items USING btree (order_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_order_items_product ON public.order_items USING btree (product_id) TABLESPACE pg_default;

-- RLS Policies (optional - adjust based on your security requirements)
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own order items
CREATE POLICY "Users can view their order items" ON public.order_items
  FOR SELECT
  USING (
    order_id IN (
      SELECT id FROM orders WHERE customer_id = auth.uid()
    )
  );

-- Allow organizations to view order items for their orders
CREATE POLICY "Organizations can view their order items" ON public.order_items
  FOR SELECT
  USING (
    order_id IN (
      SELECT o.id FROM orders o
      JOIN accounts a ON o.account_id = a.id
      WHERE a.owner_id = auth.uid()
    )
  );

-- Allow authenticated users to insert order items
CREATE POLICY "Users can insert order items" ON public.order_items
  FOR INSERT
  WITH CHECK (
    order_id IN (
      SELECT id FROM orders WHERE customer_id = auth.uid()
    )
  );
