-- Create delivery_location_history table for tracking location history
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

-- Create index for faster queries
create index if not exists idx_delivery_location_history_assignment on public.delivery_location_history using btree (assignment_id) tablespace pg_default;
create index if not exists idx_delivery_location_history_recorded_at on public.delivery_location_history using btree (recorded_at) tablespace pg_default;

-- Enable RLS
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
