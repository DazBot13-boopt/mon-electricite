# Mon Électricité — Flutter + Supabase

Application Flutter connectée au projet Supabase dédié `sbee-mon-electricite` (`ncgtfhsfnwhokewfcslh`, région Europe-Paris). Les anciennes données de démonstration ont été retirées; aucune facture ou identité fictive n’est préchargée.

Pour une démonstration rapide (compte, données, paiement test, admin, hébergement) : [Guide exposé](docs/GUIDE_EXPO.md).

## Connexion

L’application utilise e-mail + mot de passe. Pour que l’inscription connecte immédiatement, le propriétaire doit désactiver **Confirm email** dans Supabase Studio → **Authentication → Sign In / Providers → Email**. Ce réglage n’a pas été modifié automatiquement. Sans confirmation, une adresse erronée n’est pas détectée : vérifier séparément la titulaire avant d’associer un contrat ou une facture.

## Espace admin

L’admin est intégré à l’application Flutter, dans **Profil → Ouvrir l’administration**. Il liste les clientes et permet aux comptes admin de gérer abonnements et factures impayées; un journal de modifications est enregistré. Les règles RLS Supabase vérifient le rôle côté base. Une facture ne peut pas être marquée « payée » depuis le client ou l’admin.

Aucun compte admin n’est précréé. Crée d’abord un compte, puis attribue `profiles.role = 'admin'` à son UUID dans le SQL Editor Supabase (voir [Configuration Supabase](docs/SUPABASE_SETUP.md)). L’écran admin ne s’affichera qu’après cette attribution.

## Paiements et envoi de factures

Le bouton **Simuler le paiement (test)** est activé par défaut pour l’exposé. Après confirmation, une ligne `status = paid_test` est enregistrée dans la table séparée `test_payments`; le client et l’admin voient **Payée · TEST**, y compris après actualisation. Le statut officiel `invoices.status` reste dû et aucune ligne n’est ajoutée à `payments` ou `receipts`; aucun argent n’est encaissé. Désactiver avant usage réel avec `--dart-define=PAYMENT_TEST_MODE=false`. Un vrai règlement exigera un prestataire et un webhook serveur signé.

L’admin affiche une action d’envoi e-mail désactivée tant qu’aucun fournisseur transactionnel n’est configuré. Aucune facture n’est envoyée par e-mail dans cette version. Le cahier des charges et l’hébergement sont dans [Admin et hébergement](docs/ADMIN_ET_HEBERGEMENT.md).

## Démarrage local

Avec Flutter stable, Java et l’Android SDK installés :

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

L’URL Supabase et la clé publishable client sont dans `app/lib/supabase_config.dart`; elles peuvent être remplacées avec `--dart-define=SUPABASE_URL=...` et `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`. Ne jamais mettre une clé `service_role` dans Flutter, un navigateur, un APK ou GitHub.

## Hébergement

Le backend Supabase est hébergé, mais l’application cliente/admin n’est pas encore déployée et aucune URL publique de connexion n’existe. Voir [le guide d’hébergement](docs/HEBERGEMENT.md). Cette mise à jour n’a pas compilé d’APK.
