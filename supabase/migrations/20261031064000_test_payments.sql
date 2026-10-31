-- Presentation-only payment records. These rows are explicitly test data and
-- never change invoices.status, public.payments, or public.receipts.
begin;

create table if not exists public.test_payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  amount_xof bigint not null check (amount_xof >= 0),
  status text not null default 'paid_test' check (status = 'paid_test'),
  created_at timestamptz not null default now(),
  unique (invoice_id, user_id)
);

create index if not exists test_payments_user_created_idx
  on public.test_payments (user_id, created_at desc);

alter table public.test_payments enable row level security;
revoke all privileges on table public.test_payments from public, anon, authenticated;
grant select on table public.test_payments to authenticated;
grant insert (invoice_id, user_id, amount_xof) on table public.test_payments to authenticated;

drop policy if exists test_payments_read_owner_or_admin on public.test_payments;
create policy test_payments_read_owner_or_admin
  on public.test_payments for select to authenticated
  using (user_id = (select auth.uid()) or (select app_private.is_admin()));

drop policy if exists test_payments_insert_own_invoice on public.test_payments;
create policy test_payments_insert_own_invoice
  on public.test_payments for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'paid_test'
    and exists (
      select 1
      from public.invoices i
      join public.subscriptions s on s.id = i.subscription_id
      where i.id = test_payments.invoice_id
        and s.owner_id = (select auth.uid())
        and i.status <> 'paid'
        and i.amount_xof = test_payments.amount_xof
    )
  );

-- No UPDATE or DELETE privilege/policy is granted. A test record can only mean
-- “paid in the presentation simulation”; real payments remain provider-only.
commit;
