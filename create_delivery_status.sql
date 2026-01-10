-- Create delivery_status table for tracking delivery status
create table public.delivery_status (
  id uuid not null default gen_random_uuid (),
  assignment_id uuid not null,
  status text not null,
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint delivery_status_pkey primary key (id),
  constraint delivery_status_assignment_id_key unique (assignment_id),
  constraint fk_delivery_status_assignment foreign key (assignment_id) references order_delivery_assignments (id) on delete cascade
) tablespace pg_default;

-- Create index for faster queries
create index if not exists idx_delivery_status_assignment_id on public.delivery_status using btree (assignment_id) tablespace pg_default;
create index if not exists idx_delivery_status_status on public.delivery_status using btree (status) tablespace pg_default;

-- Enable RLS
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
