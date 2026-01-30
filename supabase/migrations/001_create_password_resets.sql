-- Create table to store password reset tokens issued by Edge Functions
create table if not exists public.password_resets (
  id uuid not null default gen_random_uuid() primary key,
  owner_id uuid not null,
  token_hash text not null,
  created_at timestamptz default timezone('utc', now()),
  expires_at timestamptz not null,
  used boolean default false,
  used_at timestamptz null
);

create index if not exists idx_password_resets_owner_id on public.password_resets (owner_id);
create index if not exists idx_password_resets_token_hash on public.password_resets (token_hash);
