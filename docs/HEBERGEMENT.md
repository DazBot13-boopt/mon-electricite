# Hébergement web — guide court

Le backend Supabase est en ligne. Le client Flutter, qui contient aussi l’espace admin, n’est pas encore publié; il n’y a pas d’URL publique.

Pour publier depuis GitHub, connecter le dépôt privé à un hébergeur statique HTTPS dont le pipeline installe Flutter, lancer `flutter build web --release` depuis `app/` et publier `app/build/web`. Configurer `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY` au build; ces valeurs sont publiques côté client. Ne jamais ajouter `service_role` au frontend. Ajouter le domaine final à Supabase Auth → URL Configuration et tester les rôles client/admin en HTTPS.

L’interface admin est incluse dans la même app et n’apparaît qu’aux profils `admin`; le premier admin doit être attribué en SQL par le propriétaire. L’envoi des factures est désactivé faute de fournisseur e-mail. Le paiement TEST local affiche un succès uniquement dans l’écran courant, sans écriture Supabase; désactive-le avant un usage réel avec `--dart-define=PAYMENT_TEST_MODE=false`.

Aucun build Web ou APK n’a été lancé dans cette mise à jour. Inscrire l’URL dans le README uniquement après un déploiement réel et les essais.
