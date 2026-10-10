---
# Généré par la console deva depuis Firestore : ne pas éditer, réécrit à chaque envoi.
id: "cd27ef1e671bbce5"
isp: 2
module: "ddust"
---

# Vérifier la déclaration trader du DSA en console Play

### Pourquoi

Le règlement européen sur les services numériques (*Digital Services Act* — DSA) impose à Google Play d'afficher publiquement l'identité légale et les coordonnées des éditeurs qualifiés de « commerçants » (*traders*) auprès des utilisateurs de l'Espace Économique Européen (EEE).

Dès lors que Donjons & Savons commercialise des abonnements payants par clan (paliers de 1,99 € à 7,99 €/mois), l'éditeur agit à des fins commerciales : il relève obligatoirement du statut *trader*. Se déclarer *non-trader* pour masquer ses coordonnées constituerait une fausse déclaration délibérée, entraînant un risque de blocage des paiements ou de suspension du compte développeur Play.

---

### Ce qu'il faut faire

1. **Vérification du statut en console Play** :
   - Accéder à la Google Play Console, section **Compte de développeur** / **Détails du compte** / **Déclaration relative au statut de commerçant (DSA)**.
   - Vérifier et formaliser la déclaration en tant que **commerçant** (*Trader*).
2. **Contrôle des informations d'identification** :
   - Vérifier que l'adresse postale, l'adresse e-mail professionnelle et le numéro de téléphone validé correspondent rigoureusement à l'identité légale de l'éditeur (Grisloup).
   - Recouper avec les feuilles générées du projet : `stores/google/compte.md`, `stores/google/saisie_compte.md` et le bloc `publisher` de `projects/suites/ddust/build/build.yml`.
3. **Contrôle d'exposition** :
   - Noter que tant que l'application est restreinte à la piste de test fermé (*closed testing*), Google n'affiche pas encore publiquement les coordonnées sur le Play Store ; elles deviendront visibles lors de l'ouverture publique.
   - Confirmer le respect de la règle d'isolation interne : le bloc `publisher` du `build.yml` ne doit comporter aucun `layer.publish` (pour ne jamais injecter ces coordonnées dans l'APK décompressable ni dans les layers cloud publics).

---

### Préalables

- Avoir validé l'identité légale et les coordonnées officielles de l'éditeur Grisloup (tâche associée du lot `ddust / légal`).
- Avoir accès avec les droits appropriés à la console Google Play du compte éditeur.
