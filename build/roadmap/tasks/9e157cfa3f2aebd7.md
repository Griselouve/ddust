---
# Généré par la console deva depuis Firestore : ne pas éditer, réécrit à chaque envoi.
id: "9e157cfa3f2aebd7"
isp: 5
module: "ddust"
---

# Réserver le partage vers l'extérieur aux adultes sur le butin et le journal

### Pourquoi

La revue d'intérêt supérieur de l'enfant (`child_interest.md:295`) et la politique Google Play Familles posent une règle stricte : **« Le partage vers l'extérieur est réservé aux adultes : un enfant ne peut rien publier »**.

Cette règle est aujourd'hui contredite en plusieurs endroits du code et de la configuration :
1. Dans `client/config/registry_butin.yml` (lignes 456-458 et 509-512) : le partage du butin / conte est explicité comme « visible pour TOUT joueur — pas de garde admin ».
2. Dans `client/config/registry_clan_page.yml` (lignes 834-853) : le bouton de partage des 15 derniers événements du journal (`log_page/share`) ne comporte aucune condition de visibilité ni garde de rôle.

Un mineur peut ainsi déclencher la feuille de partage native de l'OS (`dvsocialshare`) avec le texte de son journal ou de son butin.

---

### Périmètre et fichiers concernés

- **`client/config/registry_butin.yml`** : conditionner la visibilité des boutons/actions de partage vers l'extérieur aux seuls adultes / administrateurs.
- **`client/config/registry_clan_page.yml`** : masquer l'action de partage du journal (`log_page/share`) aux non-administrateurs / mineurs via le prédicat de visibilité adéquat (ex. `requires: worker.player_last_is_admin`).
- **`modules/worker/`** (parties gérant le butin, le journal et les actions de partage) : ajouter un garde-fou applicatif vérifiant que l'utilisateur agissant est bien administrateur / adulte avant d'invoquer `dvsocialshare`, empêchant ainsi tout déclenchement direct d'action sans passer par l'UI.

---

### Ce qu'il faut faire

1. **Écran de butin (`registry_butin.yml`)** :
   - Restreindre l'affichage des boutons de partage social aux chefs de clan (`is_admin` / adulte).
   - Conserver la possibilité pour les enfants de lire le conte ou le résumé à l'écran, sans pouvoir l'expédier vers l'extérieur.

2. **Écran du journal (`registry_clan_page.yml`)** :
   - Conditionner la tuile / icône de partage `log_page/share` pour qu'elle ne soit visible et activable que par un chef de clan.

3. **Garde-fou worker (`modules/worker/`)** :
   - Vérifier côté code dans le handler de partage que le joueur n'est pas mineur (`legal_state == 'k'`) et dispose du rôle chef.
   - En cas d'impersonation (prise de place d'un enfant par un chef), le chef incarnant un profil enfant doit revenir à son rôle d'adulte pour partager, afin d'éviter toute ambiguïté sur l'identité agissante.

---

### Contraintes et pièges

- Ne pas confondre la lecture du conte IA du butin (autorisée à tous les membres ayant participé) et l'action d'exportation / partage externe vers les réseaux sociaux ou le presse-papiers (`dvsocialshare`).
- Veiller à utiliser la variable de session ou de conf standard du framework pour la visibilité conditionnelle (ex. `worker.player_last_is_admin`).
