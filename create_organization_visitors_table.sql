-- Create organization_visitors table to track QR code scan visitors
create table public.organization_visitors (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  org_id uuid not null,
  qr_code_id uuid not null,
  first_scanned_at timestamp with time zone not null default timezone ('utc'::text, now()),
  last_scanned_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint organization_visitors_pkey primary key (id),
  constraint unique_user_org unique (user_id, org_id),
  constraint fk_org_visitors_account foreign key (org_id) references accounts (id) on delete cascade,
  constraint fk_org_visitors_qr foreign key (qr_code_id) references qr_codes (id) on delete cascade,
  constraint fk_org_visitors_user foreign key (user_id) references accounts (id) on delete cascade
) tablespace pg_default;

-- Create indexes for faster queries
create index if not exists idx_org_visitors_user_id on public.organization_visitors using btree (user_id) tablespace pg_default;

create index if not exists idx_org_visitors_org_id on public.organization_visitors using btree (org_id) tablespace pg_default;

-- Enable Row Level Security
alter table public.organization_visitors enable row level security;

-- Policy: Users can view visitors for organizations they own
create policy "Users can view their organization visitors"
  on public.organization_visitors
  for select
  using (
    org_id in (
      select id from accounts where user_id = auth.uid()
    )
  );

-- Policy: Allow inserting visitor records when scanning QR codes
create policy "Anyone can insert visitor records"
  on public.organization_visitors
  for insert
  with check (true);

-- Policy: Users can update their own visitor records
create policy "Users can update their visitor records"
  on public.organization_visitors
  for update
  using (user_id = auth.uid());
