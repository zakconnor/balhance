-- ============================================================
-- Subscriptions table
-- Tracks each user's billing plan and subscription status.
-- Managed by admins (service role); users can only read their
-- own row via RLS.
-- ============================================================

create table if not exists public.subscriptions (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references auth.users(id) on delete cascade,
  status                text not null default 'inactive'
                          check (status in ('active', 'inactive', 'cancelled', 'past_due')),
  plan_name             text,
  billing_period        text check (billing_period in ('monthly', 'quarterly', 'annual')),
  current_period_start  timestamptz,
  current_period_end    timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- One subscription row per user
create unique index if not exists subscriptions_user_id_idx
  on public.subscriptions(user_id);

-- Row-level security: users can only see their own record
alter table public.subscriptions enable row level security;

create policy "Users can view their own subscription"
  on public.subscriptions
  for select
  using (auth.uid() = user_id);

-- Keep updated_at current
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();
