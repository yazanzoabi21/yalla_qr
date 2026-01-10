-- ==========================================
-- DELIVERY TRACKING SYSTEM - SQL SETUP
-- ==========================================
-- Execute these SQL statements in Supabase SQL Editor
-- Run them in order: 1, 2, 3

-- ==========================================
-- TABLE 1: DELIVERY_LIVE_LOCATIONS
-- Purpose: Store current real-time location of active deliveries
-- ==========================================
-- ✅ RUN THIS FIRST

create table public.delivery_live_locations (
  id uuid not null default gen_random_uuid (),
  assignment_id uuid not null,
  lat numeric not null,
  lng numeric not null,
  speed numeric null,
  heading numeric null,
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint delivery_live_locations_pkey primary key (id),
  constraint delivery_live_locations_assignment_id_key unique (assignment_id),
  constraint fk_live_location_assignment foreign key (assignment_id) references order_delivery_assignments (id) on delete cascade
) tablespace pg_default;

-- Create indexes for performance
create index if not exists idx_delivery_live_locations_assignment_id on public.delivery_live_locations using btree (assignment_id) tablespace pg_default;
create index if not exists idx_delivery_live_locations_updated_at on public.delivery_live_locations using btree (updated_at) tablespace pg_default;

-- Enable Row Level Security
alter table public.delivery_live_locations enable row level security;

-- RLS Policy: Users can view live locations for their own delivery assignments
create policy "Users can view own delivery live locations" on public.delivery_live_locations
  for select using (
    (select order_delivery_assignments.user_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = auth.uid()
    or
    (select order_delivery_assignments.account_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = (
      select account_id from accounts where id = auth.uid()
    )
  );

-- RLS Policy: Delivery drivers can update their own live locations
create policy "Drivers can update own live locations" on public.delivery_live_locations
  for update using (
    (select order_delivery_assignments.user_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = auth.uid()
  );

-- RLS Policy: Delivery drivers can insert their own live locations
create policy "Drivers can insert own live locations" on public.delivery_live_locations
  for insert with check (
    (select order_delivery_assignments.user_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = auth.uid()
  );


-- ==========================================
-- TABLE 2: DELIVERY_LOCATION_HISTORY
-- Purpose: Store historical location data for route tracking
-- ==========================================
-- ✅ RUN THIS SECOND

create table public.delivery_location_history (
  id uuid not null default gen_random_uuid (),
  assignment_id uuid not null,
  lat numeric not null,
  lng numeric not null,
  speed numeric null,
  recorded_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint delivery_location_history_pkey primary key (id),
  constraint fk_location_history_assignment foreign key (assignment_id) references order_delivery_assignments (id) on delete cascade
) tablespace pg_default;

-- Create indexes for performance
create index if not exists idx_delivery_location_history_assignment on public.delivery_location_history using btree (assignment_id) tablespace pg_default;
create index if not exists idx_delivery_location_history_recorded_at on public.delivery_location_history using btree (recorded_at) tablespace pg_default;

-- Enable Row Level Security
alter table public.delivery_location_history enable row level security;

-- RLS Policy: Users can view location history for their own delivery assignments
create policy "Users can view own delivery location history" on public.delivery_location_history
  for select using (
    (select order_delivery_assignments.user_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = auth.uid()
    or
    (select order_delivery_assignments.account_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = (
      select account_id from accounts where id = auth.uid()
    )
  );

-- RLS Policy: Delivery drivers can insert location history
create policy "Drivers can insert location history" on public.delivery_location_history
  for insert with check (
    (select order_delivery_assignments.user_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = auth.uid()
  );


-- ==========================================
-- TABLE 3: DELIVERY_STATUS
-- Purpose: Track delivery status (pending, en-route, arriving, completed, etc)
-- ==========================================
-- ✅ RUN THIS THIRD

create table public.delivery_status (
  id uuid not null default gen_random_uuid (),
  assignment_id uuid not null,
  status text not null,
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint delivery_status_pkey primary key (id),
  constraint delivery_status_assignment_id_key unique (assignment_id),
  constraint fk_delivery_status_assignment foreign key (assignment_id) references order_delivery_assignments (id) on delete cascade
) tablespace pg_default;

-- Create indexes for performance
create index if not exists idx_delivery_status_assignment_id on public.delivery_status using btree (assignment_id) tablespace pg_default;
create index if not exists idx_delivery_status_status on public.delivery_status using btree (status) tablespace pg_default;

-- Enable Row Level Security
alter table public.delivery_status enable row level security;

-- RLS Policy: Users can view status for their own delivery assignments
create policy "Users can view own delivery status" on public.delivery_status
  for select using (
    (select order_delivery_assignments.user_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = auth.uid()
    or
    (select order_delivery_assignments.account_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = (
      select account_id from accounts where id = auth.uid()
    )
  );

-- RLS Policy: Delivery drivers can update their own status
create policy "Drivers can update own delivery status" on public.delivery_status
  for update using (
    (select order_delivery_assignments.user_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = auth.uid()
  );

-- RLS Policy: Delivery drivers can insert status
create policy "Drivers can insert delivery status" on public.delivery_status
  for insert with check (
    (select order_delivery_assignments.user_id from order_delivery_assignments where order_delivery_assignments.id = assignment_id) = auth.uid()
  );


-- ==========================================
-- VERIFICATION QUERIES
-- Run these after setup to verify everything is correct
-- ==========================================

-- Verify tables exist
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' 
AND table_name IN ('delivery_live_locations', 'delivery_location_history', 'delivery_status');

-- Verify indexes
SELECT indexname FROM pg_indexes WHERE tablename IN 
('delivery_live_locations', 'delivery_location_history', 'delivery_status');

-- Verify RLS is enabled
SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' 
AND tablename IN ('delivery_live_locations', 'delivery_location_history', 'delivery_status');

-- Verify policies exist
SELECT schemaname, tablename, policyname FROM pg_policies 
WHERE tablename IN ('delivery_live_locations', 'delivery_location_history', 'delivery_status');


-- ==========================================
-- CLEANUP (if needed)
-- Uncomment to remove all delivery tracking tables
-- ==========================================

-- DROP TABLE IF EXISTS public.delivery_status CASCADE;
-- DROP TABLE IF EXISTS public.delivery_location_history CASCADE;
-- DROP TABLE IF EXISTS public.delivery_live_locations CASCADE;


-- ==========================================
-- REFERENCE: Deployment Status Types
-- ==========================================
-- Valid status values:
-- - pending: Delivery assigned, waiting for acceptance
-- - accepted: Driver accepted the delivery
-- - enRoute: Driver is heading to customer
-- - arriving: Driver is close to destination
-- - arrived: Driver has arrived at location
-- - completed: Delivery completed successfully
-- - cancelled: Delivery was cancelled

