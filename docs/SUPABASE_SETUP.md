# Configuration Supabase — Mon Électricité

## Projet et clé cliente

Projet `sbee-mon-electricite` (`ncgtfhsfnwhokewfcslh`), séparé de `restaurantOsias`. Les migrations sont versionnées dans `supabase/migrations/`. Flutter utilise l’URL du projet et la clé publishable. Une clé publishable n’accorde pas de droits admin; aucune clé `service_role` ne doit être exposée dans Flutter, le navigateur, un APK ou GitHub.

## Authentification e-mail

Dans Supabase Studio, ouvrir **Authentication → Sign In / Providers → Email** et désactiver **Confirm email** pour que l’inscription crée immédiatement une session sans validation. Ce réglage doit encore être fait manuellement dans le Dashboard; il n’est pas modifié par une migration SQL. Si Supabase ne renvoie pas de session, l’application affiche le réglage à corriger.

Sans confirmation e-mail, une adresse incorrecte ou usurpée n’est pas détectée. Ne pas utiliser l’e-mail seul comme preuve de titularité d’un compteur; vérifier le contrat par un canal SBEE fiable avant de publier une facture. Prévoir des limites/CAPTCHA ou des inscriptions sur invitation avant ouverture publique.

## Tables, rôles et RLS

Les tables métier `profiles`, `subscriptions`, `invoices`, `payments` et `receipts` sont protégées par RLS. `profiles.email` reflète l’e-mail Auth pour la liste admin; un trigger le synchronise à l’inscription et lors d’une modification d’e-mail. Le rôle par défaut est `customer`.

La migration `20261031060000_admin_management.sql` ajoute `admin_audit_log`, les politiques et les privilèges d’écriture limités. Un admin authentifié peut créer/modifier des abonnements et créer/modifier des factures dont le statut n’est pas payé. Aucune suppression n’est accordée. Les clients ne peuvent pas écrire ces lignes. `payments` et `receipts` restent sans droits d’insertion/mise à jour pour les rôles client/admin; une future intégration de paiement devra utiliser un backend vérifiant les notifications du prestataire.

L’audit Supabase après migration a renvoyé zéro alerte sécurité. Les avertissements performance portent sur des index non utilisés, attendu tant que les tables sont vides.

## Premier compte administrateur

Aucun utilisateur ou compte admin n’est précréé. Créer le compte depuis l’application après désactivation de la confirmation e-mail. Dans `Authentication → Users`, relever et vérifier l’UUID exact, puis dans le SQL Editor du projet SBEE exécuter :

```sql
update public.profiles
set role = 'admin'
where id = 'UUID_AUTH_USER_VERIFIE';
```

Contrôler ensuite le résultat avant de transmettre l’accès. L’utilisateur ne peut pas modifier son propre rôle depuis l’application; ne pas créer de politique RLS qui lui permettrait de le faire.

## Paiement et factures

Le mode exposé (`PAYMENT_TEST_MODE=true`) inscrit une ligne `status = 'paid_test'` dans `public.test_payments`, isolée des paiements réels. Les politiques RLS autorisent le client à ajouter un test uniquement pour sa propre facture et l’admin à lire ces lignes. L’interface client/admin affiche alors « Payée · TEST » même après actualisation. Le champ officiel `invoices.status` reste `due` et les tables `payments`/`receipts` ne changent pas. Désactiver avec `--dart-define=PAYMENT_TEST_MODE=false` avant usage réel. Un vrai paiement nécessitera une fonction serveur et un webhook signé/idempotent; le retour navigateur seul ne suffit pas.

Aucune source SBEE ni fournisseur e-mail transactionnel n’est branché. L’écran admin gère les dossiers et factures, mais son action d’envoi est désactivée tant que le service d’envoi et le domaine expéditeur ne sont pas configurés. Vérifier l’adresse de destination par un canal fiable, car les e-mails Auth ne sont pas confirmés.

## Références

- [Initialiser Supabase Flutter](https://supabase.com/docs/reference/dart/initializing)
- [Connexion par e-mail et mot de passe](https://supabase.com/docs/guides/auth/passwords)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [URLs de redirection Auth](https://supabase.com/docs/guides/auth/redirect-urls)
