-- Create delivery_live_locations table for real-time tracking
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

-- Create index for faster queries
create index if not exists idx_delivery_live_locations_assignment_id on public.delivery_live_locations using btree (assignment_id) tablespace pg_default;
create index if not exists idx_delivery_live_locations_updated_at on public.delivery_live_locations using btree (updated_at) tablespace pg_default;

-- Enable RLS
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
