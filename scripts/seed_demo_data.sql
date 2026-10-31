-- ============================================================================
-- Mon Électricité — Jeu de données de DÉMONSTRATION complet
-- ----------------------------------------------------------------------------
-- Crée 10 fausses clientes + ~20 abonnements + ~45 factures variées
-- (payées, dues, en retard) pour que l'app ait l'air déjà utilisée.
--
-- ⚠️  DONNÉES SYNTHÉTIQUES — ne jamais facturer ces montants.
-- ⚠️  Les comptes fictifs ne peuvent PAS se connecter (pas de mot de passe) :
--     ils servent juste à peupler la liste admin.
--
-- ============================================================================
-- MODE D'EMPLOI (3 minutes)
--   1) Ouvre l'app : https://dazbot13-boopt.github.io/mon-electricite/
--   2) Crée un compte avec TON email (celui que tu contrôles).
--      → Si l'app ne te connecte pas tout de suite, va dans Supabase Studio :
--        Authentication → Sign In / Providers → Email → décoche "Confirm email".
--   3) Dans Supabase Studio → SQL Editor → colle TOUT ce fichier.
--   4) Remplace EMAIL_CI_DESSOUS (ligne ~25) par ton email, puis Run.
--   5) Déconnecte-reconnecte dans l'app : tu es admin, tu vois toutes les
--      clientes dans Profil → Ouvrir l'administration.
-- ============================================================================

do $$
declare
  v_email_admin text := 'EMAIL_CI_DESSOUS';
  v_admin_id uuid;
  v_sub_id uuid;
  v_client record;

  -- 10 fausses clientes béninoises
  v_clients jsonb := '[
    {"email":"adjoavi.houngbedji@demo.sbee.bj", "name":"Adjoavi Houngbédji",   "phone":"+22997112233", "addr":"Haie Vive, Cotonou",      "meter":"CPT-100045"},
    {"email":"mariam.soglo@demo.sbee.bj",       "name":"Mariam Soglo",         "phone":"+22995223344", "addr":"Fidjrossè, Cotonou",     "meter":"CPT-100112"},
    {"email":"benedicte.zinsou@demo.sbee.bj",   "name":"Bénédicte Zinsou",     "phone":"+22996334455", "addr":"Agla, Cotonou",          "meter":"CPT-100223"},
    {"email":"clarisse.kpade@demo.sbee.bj",     "name":"Clarisse Kpadé",       "phone":"+22997445566", "addr":"Akpakpa, Cotonou",       "meter":"CPT-100334"},
    {"email":"fatimata.djibril@demo.sbee.bj",   "name":"Fatimata Djibril",     "phone":"+22995556677", "addr":"Zogbo, Cotonou",         "meter":"CPT-100445"},
    {"email":"nadege.agossou@demo.sbee.bj",     "name":"Nadège Agossou",       "phone":"+22996667788", "addr":"Jéricho, Cotonou",       "meter":"CPT-100556"},
    {"email":"awa.tossou@demo.sbee.bj",         "name":"Awa Tossou",           "phone":"+22997778899", "addr":"Cadjèhoun, Cotonou",     "meter":"CPT-100667"},
    {"email":"rachelle.adjibade@demo.sbee.bj",  "name":"Rachelle Adjibadé",    "phone":"+22995889900", "addr":"Vedoko, Cotonou",        "meter":"CPT-100778"},
    {"email":"esther.bokossa@demo.sbee.bj",     "name":"Esther Bokossa",       "phone":"+22996990011", "addr":"Saint-Michel, Cotonou",  "meter":"CPT-100889"},
    {"email":"leontine.dossou@demo.sbee.bj",    "name":"Léontine Dossou",      "phone":"+22997101122", "addr":"Gbégamey, Cotonou",      "meter":"CPT-100990"}
  ]'::jsonb;
begin

  -- ========================================================================
  -- 1) RETROUVE L'ADMIN
  -- ========================================================================
  select id into v_admin_id
  from auth.users
  where lower(email) = lower(v_email_admin)
  limit 1;

  if v_admin_id is null then
    raise exception 'Compte introuvable pour %. Crée-le d''abord dans l''app, puis relance.', v_email_admin;
  end if;

  update public.profiles
  set display_name = coalesce(nullif(display_name, ''), 'Administrateur SBEE'),
      role = 'admin'
  where id = v_admin_id;

  raise notice '✓ Admin configuré : % (uuid %)', v_email_admin, v_admin_id;

  -- ========================================================================
  -- 2) CRÉE LES 10 FAUSSES CLIENTES dans auth.users
  -- ========================================================================
  -- Le trigger on_auth_user_created_profile crée automatiquement leur profile.
  -- encrypted_password reste NULL → impossibles à logger (c'est voulu).
  for v_client in select * from jsonb_to_recordset(v_clients) as x(email text, name text, phone text, addr text, meter text)
  loop
    -- auth.users n'a pas forcément de contrainte UNIQUE sur email seul (varie
    -- selon les versions Supabase), donc on vérifie manuellement avant insert.
    if not exists (select 1 from auth.users where lower(email) = lower(v_client.email)) then
      insert into auth.users (
        id, instance_id, aud, role, email,
        encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at
      ) values (
        gen_random_uuid(),
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        v_client.email,
        null,
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('display_name', v_client.name),
        now() - (random() * interval '180 days'),
        now()
      );
    end if;

    -- Met à jour le profile (créé par le trigger on_auth_user_created_profile).
    update public.profiles p
    set display_name = v_client.name,
        phone = v_client.phone
    from auth.users u
    where lower(u.email) = lower(v_client.email) and p.id = u.id;
  end loop;

  raise notice '✓ 10 clientes fictives créées / mises à jour';

  -- ========================================================================
  -- 3) ABONNEMENTS pour chaque cliente
  -- ========================================================================
  insert into public.subscriptions (owner_id, reference, label, service_address, meter_number, status)
  select
    u.id,
    'SBEE-COT-' || lpad((row_number() over (order by u.email))::text, 5, '0'),
    'Abonnement résidentiel',
    (c->>'addr'),
    (c->>'meter'),
    case when random() < 0.9 then 'active' else 'suspended' end
  from jsonb_array_elements(v_clients) c
  join auth.users u on u.email = (c->>'email')
  on conflict (reference) do update
    set owner_id = excluded.owner_id,
        service_address = excluded.service_address,
        meter_number = excluded.meter_number;

  -- Un deuxième abonnement pour 5 clientes (compteur secondaire : boutique, atelier…)
  insert into public.subscriptions (owner_id, reference, label, service_address, meter_number, status)
  select
    u.id,
    'SBEE-COT-SEC-' || lpad((row_number() over (order by u.email))::text, 5, '0'),
    'Compteur boutique',
    (c->>'addr') || ' — boutique',
    'CPT-SEC-' || lpad((100000 + (row_number() over (order by u.email)) * 7)::text, 6, '0'),
    'active'
  from jsonb_array_elements(v_clients) c
  join auth.users u on u.email = (c->>'email')
  where (c->>'email') in (
    'adjoavi.houngbedji@demo.sbee.bj',
    'benedicte.zinsou@demo.sbee.bj',
    'fatimata.djibril@demo.sbee.bj',
    'awa.tossou@demo.sbee.bj',
    'esther.bokossa@demo.sbee.bj'
  )
  on conflict (reference) do nothing;

  -- 2 abonnements pour l'admin aussi (pour que son espace client ne soit pas vide)
  insert into public.subscriptions (owner_id, reference, label, service_address, meter_number, status)
  values
    (v_admin_id, 'SBEE-ADMIN-001', 'Domicile principal', 'Cocotomey, Abomey-Calavi', 'CPT-200001', 'active'),
    (v_admin_id, 'SBEE-ADMIN-002', 'Bureau', 'Les Cocotiers, Cotonou',                'CPT-200002', 'active')
  on conflict (reference) do nothing;

  raise notice '✓ Abonnements créés';

  -- ========================================================================
  -- 4) FACTURES — 3 mois d'historique pour chaque abonnement
  -- ========================================================================
  -- Pour chaque subscription, on crée 3 factures : aout, septembre, octobre.
  -- Statuts : la plus ancienne 'paid', la moyenne 'paid' ou 'overdue', la récente 'due'.

  insert into public.invoices (
    subscription_id, external_reference, period_label, period_start, period_end,
    amount_xof, due_date, status, consumption_kwh, previous_index, current_index, energy_xof, fees_xof
  )
  select
    s.id,
    s.reference || '-2026-08',
    'Août 2026',
    date '2026-08-01', date '2026-08-31',
    (8000 + (hashtext(s.reference) % 25000))::bigint,
    date '2026-09-15',
    'paid',
    (60 + (hashtext(s.reference) % 180))::numeric,
    (1000 + abs(hashtext(s.reference)) % 3000)::numeric,
    (1000 + abs(hashtext(s.reference)) % 3000 + 60 + abs(hashtext(s.reference)) % 180)::numeric,
    (7000 + abs(hashtext(s.reference)) % 22000)::bigint,
    (800 + abs(hashtext(s.reference)) % 3000)::bigint
  from public.subscriptions s
  on conflict (external_reference) do nothing;

  insert into public.invoices (
    subscription_id, external_reference, period_label, period_start, period_end,
    amount_xof, due_date, status, consumption_kwh, previous_index, current_index, energy_xof, fees_xof
  )
  select
    s.id,
    s.reference || '-2026-09',
    'Septembre 2026',
    date '2026-09-01', date '2026-09-30',
    (9500 + (hashtext(s.reference || 'sept') % 28000))::bigint,
    date '2026-10-15',
    case when (abs(hashtext(s.reference)) % 10) < 7 then 'paid' else 'overdue' end,
    (70 + (hashtext(s.reference || 'sept') % 190))::numeric,
    (1500 + abs(hashtext(s.reference)) % 3200)::numeric,
    (1500 + abs(hashtext(s.reference)) % 3200 + 70 + abs(hashtext(s.reference || 'sept')) % 190)::numeric,
    (8300 + abs(hashtext(s.reference || 'sept')) % 24000)::bigint,
    (900 + abs(hashtext(s.reference || 'sept')) % 3500)::bigint
  from public.subscriptions s
  on conflict (external_reference) do nothing;

  insert into public.invoices (
    subscription_id, external_reference, period_label, period_start, period_end,
    amount_xof, due_date, status, consumption_kwh, previous_index, current_index, energy_xof, fees_xof
  )
  select
    s.id,
    s.reference || '-2026-10',
    'Octobre 2026',
    date '2026-10-01', date '2026-10-31',
    (11000 + (hashtext(s.reference || 'oct') % 32000))::bigint,
    date '2026-11-15',
    'due',
    (85 + (hashtext(s.reference || 'oct') % 210))::numeric,
    (2000 + abs(hashtext(s.reference)) % 3500)::numeric,
    (2000 + abs(hashtext(s.reference)) % 3500 + 85 + abs(hashtext(s.reference || 'oct')) % 210)::numeric,
    (9500 + abs(hashtext(s.reference || 'oct')) % 27000)::bigint,
    (1100 + abs(hashtext(s.reference || 'oct')) % 4200)::bigint
  from public.subscriptions s
  on conflict (external_reference) do nothing;

  raise notice '✓ Factures créées (3 mois par abonnement)';

  -- ========================================================================
  -- 5) UN TEST_PAYMENT pour l'admin pour voir "Payée · TEST"
  -- ========================================================================
  insert into public.test_payments (invoice_id, user_id, amount_xof, status)
  select i.id, v_admin_id, i.amount_xof, 'paid_test'
  from public.invoices i
  join public.subscriptions s on s.id = i.subscription_id
  where s.owner_id = v_admin_id
    and i.period_label = 'Octobre 2026'
    and s.reference = 'SBEE-ADMIN-002'
  on conflict (invoice_id, user_id) do nothing;

  raise notice '✓ Paiement test ajouté pour l''admin';
  raise notice '';
  raise notice '🎉 Jeu de données prêt. Reconnecte-toi dans l''app.';

end;
$$;

-- Vérif rapide (optionnel) : combien de factures par statut ?
select status, count(*) as nb from public.invoices group by status order by nb desc;
