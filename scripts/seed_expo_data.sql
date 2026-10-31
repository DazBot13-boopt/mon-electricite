-- Données synthétiques pour l’exposé uniquement. Ne jamais facturer ces montants.
--
-- Mode d’emploi (2 minutes) :
--   1) Lancer l’application et créer un compte avec un e-mail que tu contrôles
--      (l’app le connecte immédiatement, sans confirmation e-mail).
--   2) Remplacer EMAIL_CI_DESSOUS par cet e-mail dans la variable v_email.
--   3) Exécuter tout ce script dans Supabase → SQL Editor.
--   4) Se déconnecter/reconnecter dans l’app : l’abonnement, la facture et
--      l’accès admin apparaissent. Appuyer sur « Simuler le paiement (test) »
--      pour voir « Payée · TEST » côté client et côté admin.
--
-- Le statut officiel de la facture reste « due » : le test écrit seulement dans
-- public.test_payments et ne touche jamais payments, receipts ou invoices.status.

do $$
declare
  v_email text := 'EMAIL_CI_DESSOUS';
  v_make_admin boolean := true; -- false si tu veux seulement un compte cliente
  v_user_id uuid;
  v_subscription_id uuid;
begin
  select id into v_user_id
  from auth.users
  where lower(email) = lower(v_email)
  limit 1;

  if v_user_id is null then
    raise exception 'Compte introuvable pour %. Crée-le d’abord dans l’application, puis relance ce script.', v_email;
  end if;

  -- Profil : nom lisible + e-mail (l’e-mail est déjà synchronisé par trigger).
  update public.profiles
  set display_name = coalesce(nullif(display_name, ''), 'Cliente Exposé'),
      email = v_email,
      role = case when v_make_admin then 'admin' else role end
  where id = v_user_id;

  -- Abonnement de démonstration (idempotent grâce à la référence unique).
  insert into public.subscriptions (
    owner_id, reference, label, service_address, meter_number, status
  ) values (
    v_user_id,
    'EXPO-SBEE-TEST-001',
    'Abonnement test — Exposé',
    'Adresse fictive — données de démonstration',
    'COMPTEUR-TEST-001',
    'active'
  )
  on conflict (reference) do update set
    owner_id = excluded.owner_id,
    label = excluded.label,
    service_address = excluded.service_address,
    meter_number = excluded.meter_number,
    status = excluded.status
  returning id into v_subscription_id;

  -- Facture impayée à montrer pendant la démonstration.
  insert into public.invoices (
    subscription_id, external_reference, period_label, period_start, period_end,
    amount_xof, due_date, status, consumption_kwh, previous_index,
    current_index, energy_xof, fees_xof
  ) values (
    v_subscription_id,
    'EXPO-TEST-INVOICE-001',
    'FACTURE TEST — EXPOSÉ',
    date '2026-10-01',
    date '2026-10-31',
    12500,
    current_date + 30,
    'due',
    92.5,
    1200,
    1292.5,
    10800,
    1700
  )
  on conflict (external_reference) do update set
    subscription_id = excluded.subscription_id,
    period_label = excluded.period_label,
    period_start = excluded.period_start,
    period_end = excluded.period_end,
    amount_xof = excluded.amount_xof,
    due_date = excluded.due_date,
    status = 'due',
    consumption_kwh = excluded.consumption_kwh,
    previous_index = excluded.previous_index,
    current_index = excluded.current_index,
    energy_xof = excluded.energy_xof,
    fees_xof = excluded.fees_xof;

  -- Deuxième facture déjà « payée » en test pour montrer l’historique Payées.
  insert into public.invoices (
    subscription_id, external_reference, period_label, period_start, period_end,
    amount_xof, due_date, status, consumption_kwh, previous_index,
    current_index, energy_xof, fees_xof
  ) values (
    v_subscription_id,
    'EXPO-TEST-INVOICE-000',
    'FACTURE TEST — EXPOSÉ (septembre)',
    date '2026-09-01',
    date '2026-09-30',
    11400,
    current_date - 5,
    'due',
    84.0,
    1116,
    1200,
    9800,
    1600
  )
  on conflict (external_reference) do update set
    subscription_id = excluded.subscription_id,
    period_label = excluded.period_label,
    amount_xof = excluded.amount_xof,
    due_date = excluded.due_date,
    status = 'due',
    consumption_kwh = excluded.consumption_kwh,
    previous_index = excluded.previous_index,
    current_index = excluded.current_index,
    energy_xof = excluded.energy_xof,
    fees_xof = excluded.fees_xof;

  insert into public.test_payments (invoice_id, user_id, amount_xof, status)
  select i.id, v_user_id, i.amount_xof, 'paid_test'
  from public.invoices i
  where i.external_reference = 'EXPO-TEST-INVOICE-000'
  on conflict (invoice_id, user_id) do nothing;
end;
$$;
