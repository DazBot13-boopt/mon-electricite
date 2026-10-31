# Guide exposé — 10 minutes de mise en route

Objectif : montrer une application Flutter connectée à Supabase, avec une facture réelle en base, un paiement **de test** qui s’affiche « Payée · TEST », et un espace admin qui voit la même chose.

Tout ce qui suit est un environnement de démonstration : aucun argent ne circule, aucune facture officielle SBEE n’est émise.

## 1. Créer le compte de démonstration

1. Lancer l’application (téléphone ou version Web).
2. Onglet de connexion → créer un compte avec un e-mail que tu contrôles et un mot de passe.
3. La connexion est immédiate si `Confirm email` est désactivé dans Supabase → **Authentication → Sign In / Providers → Email**.

## 2. Insérer les données de démonstration

1. Ouvrir `scripts/seed_expo_data.sql`.
2. Remplacer `EMAIL_CI_DESSOUS` par l’e-mail du compte créé.
3. Laisser `v_make_admin := true` pour obtenir aussi l’espace admin.
4. Copier tout le script dans Supabase → **SQL Editor** → exécuter.

Résultat attendu : 1 abonnement, 2 factures (une due, une déjà « payée » en test), et le compte promu `admin`.

## 3. Montrer le paiement de test

1. Dans l’app, ouvrir la facture « FACTURE TEST — EXPOSÉ ».
2. Appuyer sur **Simuler le paiement (test)** puis confirmer.
3. L’écran affiche **Payée · TEST** et le montant dû passe à 0.
4. Dans Supabase → **Table Editor → test_payments**, une ligne `paid_test` apparaît.
5. Dans Supabase → **invoices**, le statut reste `due` : c’est la preuve qu’aucun règlement réel n’a été enregistré.

## 4. Montrer l’espace admin

1. Dans l’app : **Profil → Ouvrir l’administration** (visible seulement pour `role = 'admin'`).
2. L’admin voit les clientes, les abonnements, les factures (avec l’étiquette « Payée · TEST ») et le journal des modifications.
3. L’admin peut créer/modifier un abonnement ou une facture **non payée** ; il ne peut jamais déclarer une facture payée.

## 5. Hébergement et lien

- Le dépôt GitHub contient tout le code et les migrations.
- Pour publier l’application Web : `cd app && flutter build web --release`, puis héberger `app/build/web` sur un hébergeur statique HTTPS.
- Le lien obtenu sert **au client et à l’admin** : l’onglet Administration n’apparaît que pour un profil `admin`.
- Après déploiement, ajouter l’URL dans Supabase → **Authentication → URL Configuration**.

## Points à dire pendant l’exposé

- Les données vivent dans PostgreSQL (Supabase), pas dans le téléphone : chaque utilisateur ne voit que ses lignes grâce aux politiques RLS.
- Le paiement affiché est un test tracé dans une table séparée `test_payments`; un vrai encaissement exigera un prestataire et un webhook serveur signé.
- L’admin ne peut pas falsifier un règlement : `invoices.status = 'paid'` n’est accessible à aucun client.
