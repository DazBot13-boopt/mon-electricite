# Validation effectuée

État mis à jour le 31 octobre 2026.

## Backend Supabase

Projet `sbee-mon-electricite` (`ncgtfhsfnwhokewfcslh`), schéma initial et migration admin `20261031060000_admin_management.sql` appliqués. Cette migration ajoute l’e-mail aux profils, `admin_audit_log`, des mutations RLS réservées aux admins sur abonnements et factures non payées, et les triggers d’audit. Les droits d’écriture paiements/reçus restent fermés au client et à l’admin. Les requêtes de vérification ont confirmé les politiques et grants; l’audit sécurité Supabase a renvoyé zéro alerte. Les tables métier restent vides.

## Code Flutter

L’authentification par e-mail, l’écran admin (clients, abonnements, factures et journal), les méthodes API typées, la navigation depuis le profil et les restrictions de statut sont intégrés. L’action d’e-mail est désactivée sans fournisseur. Le mode paiement TEST affiche la facture payée uniquement sur l’écran courant et n’écrit jamais dans Supabase; aucun débit ou reçu réel n’est créé.

Après l’ajout du mode paiement TEST local, `dart format lib test` a été exécuté et `flutter analyze` a terminé avec **No issues found**. Les tests Flutter ne sont pas exécutés. Aucun APK ou build Web n’est lancé, conformément à la demande de ne pas compiler.

## À faire avant production

Le propriétaire doit désactiver `Confirm email`, créer et promouvoir manuellement un premier compte admin vérifié, et valider la titularité SBEE. Il n’y a pas encore de source officielle SBEE, d’envoi e-mail, de prestataire de paiement, de déploiement Web, d’URL publique ni de tests de bout en bout sur téléphone. Les factures admin saisies en base ne doivent pas être présentées comme des factures officielles SBEE avant validation opérateur.
Projet `sbee-mon-electricite` (`ncgtfhsfnwhokewfcslh`), schéma initial, migration admin `20261031060000_admin_management.sql` et migration `20261031064000_test_payments.sql` appliqués. La table `public.test_payments` (RLS activé) enregistre les paiements de démonstration `paid_test`; elle est isolée de `payments`, `receipts` et de `invoices.status`. Les droits d’écriture réels restent fermés au client et à l’admin. Les tables métier sont vides jusqu’à l’exécution de `scripts/seed_expo_data.sql`.
