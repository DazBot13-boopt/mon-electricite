# Direction graphique et écrans Android

L’application garde le thème clair existant : bleu nuit `#142C46`, bleu d’action `#1456A0`, jaune `#FFD15C`, fond `#F4F7FB`, cartes blanches et contenus adaptés au clavier.

## Espace client

Connexion et inscription par e-mail/mot de passe, sans téléphone/OTP; la connexion immédiate exige que `Confirm email` soit désactivé dans Supabase. Le client voit accueil, factures, détail, abonnements et profil selon RLS. Le bouton peut lancer une simulation « Payée · TEST »; elle est locale à l’écran, ne modifie pas Supabase et ne produit aucun reçu réel. Le bandeau indique clairement le mode test.

## Espace admin intégré

Le profil d’un compte dont `profiles.role = 'admin'` présente **Ouvrir l’administration**. L’écran admin s’adapte au téléphone et au grand écran et comporte les vues Clients, Abonnements, Factures et Journal. Il permet de créer/modifier abonnements et factures et de consulter les actions historisées. La suppression est absente; une facture payée est en lecture seule et aucun statut « payé » ne peut être saisi.

L’action d’envoi e-mail est visible mais désactivée en attente d’un fournisseur. Il n’y a pas d’admin public précréé; le propriétaire promeut le premier compte par UUID dans Supabase. La liste globale de clientes et l’audit restent réservés au rôle admin par RLS.

## Hébergement et limites

L’écran admin fait partie de la même application Flutter, pas d’un site web séparé. L’app Web n’est pas publiée et aucun lien de connexion n’existe. Les factures ne sont pas encore synchronisées à SBEE; l’envoi e-mail et le paiement réel nécessitent des fournisseurs non configurés.
