# Recette Android — client et admin

Checklist à exécuter par le propriétaire sur un appareil réel après la configuration de Supabase. Cette mise à jour n’a pas produit d’APK.

## Connexion e-mail

- [ ] Désactiver `Confirm email` dans Supabase Email pour obtenir une session après inscription.
- [ ] Créer un client de test avec nom, adresse e-mail et mot de passe; vérifier `Authentication → Users` et le profil `customer`.
- [ ] Confirmer qu’aucun code SMS/OTP ou courriel de vérification n’est requis.
- [ ] Se connecter, fermer/réouvrir l’application, puis se déconnecter.
- [ ] Vérifier les messages pour e-mail invalide, mot de passe invalide et confirmation encore activée.

## Premier administrateur et isolation

- [ ] Utiliser un compte de confiance; relever son UUID Auth et le promouvoir en SQL à `role='admin'`.
- [ ] Confirmer que le lien d’administration apparaît uniquement pour l’admin.
- [ ] Créer deux comptes clients A/B; vérifier qu’ils ne lisent pas les données l’un de l’autre.
- [ ] Depuis l’admin, consulter la liste des clients, créer/modifier un abonnement et une facture non payée; vérifier les lignes et le journal d’audit dans Supabase.
- [ ] Vérifier qu’un compte client ne peut pas créer/modifier abonnement ou facture, changer son rôle, lire l’audit, ou modifier les paiements/reçus.
- [ ] Vérifier qu’aucun chemin UI/API client/admin ne peut marquer une facture comme payée ou créer un reçu.

## Envoi et paiement

- [ ] Le bouton d’envoi e-mail est désactivé tant que fournisseur et domaine expéditeur ne sont pas configurés.
- [ ] Ouvrir une facture due, cliquer « Simuler le paiement (test) » et confirmer; client et admin affichent « Payée · TEST » même après actualisation.
- [ ] Vérifier dans Supabase qu’une ligne apparaît dans `test_payments`, tandis que `invoices.status` reste `due` et que `payments`/`receipts` ne changent pas.
- [ ] Désactiver le mode avant toute distribution réelle avec `--dart-define=PAYMENT_TEST_MODE=false`.
- [ ] Après sélection d’un fournisseur réel, tester le flux serveur et les webhooks signés/idempotents avant d’activer les paiements.

## Contrôles d’usage

- [ ] `flutter analyze` sans erreur; exécuter `flutter test` et build uniquement lorsque le propriétaire souhaite compiler.
- [ ] Vérifier formulaires, clavier, petits écrans, erreurs réseau et absence de débordement.
- [ ] Ne jamais publier une clé `service_role`; ne communiquer l’URL qu’après hébergement HTTPS et vérification RLS.
