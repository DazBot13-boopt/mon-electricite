# État de l’application

## Implémenté et appliqué

Le projet dédié `sbee-mon-electricite` contient les tables `profiles`, `subscriptions`, `invoices`, `payments`, `receipts` et `admin_audit_log`, toutes protégées par RLS. La migration admin ajoute `profiles.email`, les contrôles de rôle, l’audit des mutations et des écritures réservées aux admins sur abonnements/factures impayées. L’audit sécurité après migration n’a pas signalé d’alerte; les tables sont vides.

Le client Flutter utilise e-mail + mot de passe et une session immédiate si le propriétaire désactive `Confirm email`. L’espace admin intégré permet de lister les clientes, gérer leurs abonnements/factures non payées et lire le journal. Les factures payées sont en lecture seule. Aucun rôle admin n’est attribué automatiquement : le propriétaire doit promouvoir l’UUID vérifié d’un compte.

Le client peut enregistrer un test de paiement sans argent dans `test_payments`; la facture est affichée « Payée · TEST » au client et à l’admin. Le statut officiel `invoices.status` reste dû et aucune ligne de paiement réel ou reçu n’est créée. Aucun admin ne peut marquer une vraie facture payée.

## À faire avant usage réel

- Désactiver la confirmation e-mail manuellement et créer un premier administrateur, puis valider séparément l’identité/contrat client.
- Désactiver le mode test avec `--dart-define=PAYMENT_TEST_MODE=false` avant une distribution réelle. Aucun argent ne bouge; le paiement réel nécessitera ensuite un prestataire avec initiation serveur et webhooks signés/idempotents.
- Choisir un fournisseur d’e-mail transactionnel, configurer domaine/secrets côté serveur et activer ensuite l’envoi des factures; le bouton est actuellement désactivé.
- Relier une source SBEE ou un contrôle opérateur pour que les montants saisis ne soient pas confondus avec des factures officielles.
- Déployer la version Flutter Web sur un hébergeur HTTPS. Aucun lien public de connexion n’existe pour le moment.
- Tester sur appareils/comptes réels; aucun APK ou build Web n’a été produit dans cette mise à jour.

Voir [Administration et hébergement](ADMIN_ET_HEBERGEMENT.md), [configuration Supabase](SUPABASE_SETUP.md) et [la recette](RECETTE_TELEPHONE.md).
- Désactiver le mode de simulation avec `--dart-define=PAYMENT_TEST_MODE=false` avant toute distribution réelle, puis choisir un prestataire et intégrer l’initiation serveur et les webhooks signés/idempotents. À présent, aucun argent ne bouge.
