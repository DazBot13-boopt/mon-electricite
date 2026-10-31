-- Initial production-oriented schema for Mon Électricité / SBEE.
-- No demo users, subscriptions, invoices, payments, or receipts are seeded.

begin;

create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 120),
  phone text,
  role text not null default 'customer' check (role in ('customer', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists profiles_phone_unique
  on public.profiles (phone) where phone is not null;

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete restrict,
  reference text not null unique check (char_length(reference) between 1 and 80),
  label text not null check (char_length(label) between 1 and 120),
  service_address text not null default '',
  meter_number text,
  status text not null default 'pending_verification'
    check (status in ('pending_verification', 'active', 'suspended', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists subscriptions_owner_id_idx
  on public.subscriptions (owner_id);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions (id) on delete restrict,
  external_reference text unique,
  period_label text not null check (char_length(period_label) between 1 and 80),
  period_start date,
  period_end date,
  amount_xof bigint not null check (amount_xof >= 0),
  due_date date,
  status text not null default 'due'
    check (status in ('due', 'paid', 'overdue', 'cancelled')),
  consumption_kwh numeric(12, 3) check (consumption_kwh is null or consumption_kwh >= 0),
  previous_index numeric(14, 3) check (previous_index is null or previous_index >= 0),
  current_index numeric(14, 3) check (current_index is null or current_index >= 0),
  energy_xof bigint check (energy_xof is null or energy_xof >= 0),
  fees_xof bigint check (fees_xof is null or fees_xof >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (period_start is null or period_end is null or period_start <= period_end),
  check (previous_index is null or current_index is null or current_index >= previous_index)
);

create index if not exists invoices_subscription_due_idx
  on public.invoices (subscription_id, due_date desc);
create index if not exists invoices_status_idx
  on public.invoices (status);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices (id) on delete restrict,
  user_id uuid not null references public.profiles (id) on delete restrict,
  amount_xof bigint not null check (amount_xof >= 0),
  currency text not null default 'XOF' check (currency = 'XOF'),
  status text not null default 'initiated'
    check (status in ('initiated', 'pending', 'succeeded', 'failed', 'cancelled', 'refunded')),
  provider text,
  provider_reference text,
  idempotency_key text not null unique check (char_length(idempotency_key) between 1 and 160),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists payments_user_created_idx
  on public.payments (user_id, created_at desc);
create index if not exists payments_invoice_created_idx
  on public.payments (invoice_id, created_at desc);

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null unique references public.payments (id) on delete restrict,
  user_id uuid not null references public.profiles (id) on delete restrict,
  receipt_number text not null unique,
  issued_at timestamptz not null default now(),
  document_path text,
  created_at timestamptz not null default now()
);

create index if not exists receipts_user_issued_idx
  on public.receipts (user_id, issued_at desc);

create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

revoke all on function app_private.is_admin() from public, anon;
grant usage on schema app_private to authenticated;
grant execute on function app_private.is_admin() to authenticated;

create or replace function app_private.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function app_private.set_updated_at() from public, anon, authenticated;

create or replace function app_private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, phone)
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), ''),
    nullif(new.phone, '')
  )
  on conflict (id) do update
    set phone = excluded.phone,
        updated_at = now();
  return new;
end;
$$;

revoke all on function app_private.handle_new_auth_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function app_private.handle_new_auth_user();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function app_private.set_updated_at();

drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at
before update on public.subscriptions
for each row execute function app_private.set_updated_at();

drop trigger if exists invoices_set_updated_at on public.invoices;
create trigger invoices_set_updated_at
before update on public.invoices
for each row execute function app_private.set_updated_at();

drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at
before update on public.payments
for each row execute function app_private.set_updated_at();

alter table public.profiles enable row level security;
alter table public.subscriptions enable row level security;
alter table public.invoices enable row level security;
alter table public.payments enable row level security;
alter table public.receipts enable row level security;

-- Revoke default broad grants, then grant only the operations needed by the mobile app.
revoke all privileges on table public.profiles from public, anon, authenticated;
revoke all privileges on table public.subscriptions from public, anon, authenticated;
revoke all privileges on table public.invoices from public, anon, authenticated;
revoke all privileges on table public.payments from public, anon, authenticated;
revoke all privileges on table public.receipts from public, anon, authenticated;

grant select on table public.profiles to authenticated;
grant update (display_name) on table public.profiles to authenticated;
grant select on table public.subscriptions to authenticated;
grant select on table public.invoices to authenticated;
grant select on table public.payments to authenticated;
grant select on table public.receipts to authenticated;

create policy profiles_read_self_or_admin
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select app_private.is_admin()));

create policy profiles_update_own_display_name
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy subscriptions_read_owner_or_admin
  on public.subscriptions for select to authenticated
  using (owner_id = (select auth.uid()) or (select app_private.is_admin()));

create policy invoices_read_owner_or_admin
  on public.invoices for select to authenticated
  using (
    (select app_private.is_admin())
    or exists (
      select 1 from public.subscriptions s
      where s.id = invoices.subscription_id
        and s.owner_id = (select auth.uid())
    )
  );

create policy payments_read_owner_or_admin
  on public.payments for select to authenticated
  using (user_id = (select auth.uid()) or (select app_private.is_admin()));

create policy receipts_read_owner_or_admin
  on public.receipts for select to authenticated
  using (user_id = (select auth.uid()) or (select app_private.is_admin()));

commit;
