# Administration, envoi de factures et hébergement

## Fonctions admin présentes

L’espace admin est intégré au client Flutter. Une fois un compte promu `admin` par le propriétaire Supabase, il apparaît sous **Profil → Ouvrir l’administration**. L’écran affiche les comptes (nom/e-mail/rôle), les abonnements, les factures et le journal d’audit. Il permet de créer/modifier les abonnements et les factures; il n’autorise pas la suppression et ne permet jamais de marquer une facture payée.

Le schéma Supabase correspondant a été appliqué. `profiles.email` est synchronisé depuis Auth; RLS réserve la liste complète aux admins. Les mutations sont contrôlées par `app_private.is_admin()` et le journal `admin_audit_log` enregistre les créations/modifications. Les droits de paiement et de reçu ne sont pas ouverts.

### Premier admin

Aucun compte admin n’est créé à l’avance. Le propriétaire doit désactiver Confirm email, créer un compte d’essai puis relever l’UUID dans Supabase Studio → Authentication → Users. Dans le SQL Editor du projet SBEE, exécuter une seule fois pour l’UUID vérifié :

```sql
update public.profiles
set role = 'admin'
where id = 'UUID_AUTH_USER_VERIFIE';
```

Ne jamais laisser le client modifier son propre rôle. Le rôle admin donne accès à tous les profils et factures : ne l’accorder qu’à des personnes de confiance.

## Limites qui nécessitent des fournisseurs

### Envoi des factures

Le formulaire admin permet de gérer les données de facture, mais **n’envoie pas encore d’e-mail**. Le bouton d’envoi est désactivé faute de fournisseur transactionnel, de domaine expéditeur et de secrets. Avant d’activer l’envoi, choisir un prestataire, configurer ses secrets uniquement côté serveur, enregistrer les états d’envoi/rebonds et envoyer un lien sécurisé ou un PDF dans un stockage privé. Comme les e-mails Auth ne sont pas vérifiés, contrôler le destinataire par un canal fiable avant d’envoyer une facture nominative. L’intégration SBEE et la génération PDF restent à faire.

### Paiements

Le mode exposé est activé par défaut : la table séparée `test_payments` reçoit une ligne `paid_test`, visible par le client et l’admin via RLS. L’application affiche « Payée · TEST » après confirmation. Le statut officiel de la facture reste dû; les tables `payments` et `receipts` ne changent pas, aucun argent n’est encaissé et aucun reçu réel n’est créé. Pour une distribution réelle, désactiver avec `--dart-define=PAYMENT_TEST_MODE=false`. La table `payments` reste réservée à un backend sécurisé; un paiement réel exigera un prestataire, une fonction serveur d’initiation et un webhook signé/idempotent.

### Données SBEE

Les factures saisies par l’admin sont des enregistrements de la base, pas des factures officielles SBEE tant qu’une source ou une validation opérateur n’est pas connectée. Vérifier la titulaire et les montants avant publication.

## Hébergement et lien web

Le backend Supabase est hébergé, mais le client Flutter (y compris l’écran admin) n’a pas été déployé sur un site public; **aucune URL de connexion n’existe encore**. Une fois le dépôt GitHub prêt, un hébergeur statique HTTPS peut publier le client Flutter Web : installer Flutter dans le pipeline, lancer `flutter build web --release` depuis `app/`, puis publier `app/build/web`. Configurer `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY` au build; ne jamais mettre `service_role` dans le frontend.

Ajouter le domaine final dans Supabase Auth → URL Configuration (Site URL et Redirect URLs si nécessaires), activer HTTPS et tester en navigation privée, en particulier le client non admin et l’accès admin par rôle. Ne copier l’URL dans le README qu’après son déploiement réel et ses essais. Aucun APK ni build Web n’a été produit lors de cette mise à jour, conformément à la demande de ne pas compiler.
