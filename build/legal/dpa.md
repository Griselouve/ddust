<!-- généré : 20260808 -->
# dpa — donjons & savons

Dossier de conformité sous-traitance (art. 28 RGPD) et registre des traitements (art. 30 RGPD) pour la mise en production Play Store. Répond au point « DPA Google à signer dans la console Firebase » du `readme.md` §14.

---

## 1. ce qu'est le dpa — et ce qu'il n'y a pas à rédiger

Le DPA (*Data Processing Agreement*, avenant de traitement des données) est le contrat art. 28 RGPD entre le **responsable de traitement** (l'éditeur de Donjons & Savons) et son **sous-traitant** (Google). Il n'est **pas à rédiger** : Google fournit un contrat d'adhésion non négociable, en deux textes qui couvrent l'intégralité du backend `dvddust` :

| Texte | Périmètre | URL |
|---|---|---|
| **Cloud Data Processing Addendum** (CDPA) | GCP : Firestore, Cloud Functions, Cloud Run, Cloud Storage, Secret Manager, **Vertex AI** | cloud.google.com/terms/data-processing-addendum |
| **Firebase Data Processing and Security Terms** (DPST) | Firebase : Authentication, FCM, Hosting | firebase.google.com/terms/data-processing-terms |

Ces textes sont **incorporés automatiquement** aux conditions d'utilisation GCP/Firebase : il n'y a plus de « signature » à proprement parler. Ce qui reste à faire est une **revue, un archivage et le renseignement des contacts** (section 2). Google y est qualifié de *processor*, l'éditeur de *controller* ; les Clauses Contractuelles Types (SCC) de la Commission européenne y sont intégrées pour les transferts de secours hors UE.

Point notable pour Vertex AI : selon les conditions Google Cloud, les données soumises (prompts « Inspire-moi », journal du clan pour le conte du butin) sont traitées comme *Customer Data* — **non utilisées pour entraîner les modèles**.

---

## 2. actions à effectuer (checklist)

- [ ] **Console Firebase** → projet `dvddust` → ⚙️ *Paramètres du projet* → onglet *Confidentialité des données* (« Data privacy ») : vérifier la référence aux DPST et renseigner les coordonnées de contact protection des données (DPO facultatif pour un indé ; l'éditeur étant établi dans l'UE, aucun représentant UE art. 27 à désigner). L'emplacement exact peut varier selon les versions de la console.
- [ ] **Archiver** dans `legal/` un PDF daté du CDPA et des DPST en vigueur (obligation de traçabilité, art. 5.2 — *accountability*). Renouveler l'archive quand Google publie une nouvelle version.
- [ ] **Vérifier l'identité juridique** rattachée au compte de facturation GCP : c'est cette entité (personne physique ou société) qui est partie au CDPA — elle doit coïncider avec l'éditeur déclaré dans les CGU, les pages légales du site et le compte Play Console.
- [ ] **Compléter les champs [à renseigner]** de la section 3 et tenir à jour le registre (section 4) à chaque évolution du produit (économie de jeu, abonnements, multitenancy).
- [ ] Avant production (pas bloquant pour le test fermé) : mener l'**AIPD** (section 7).

---

## 3. qualification des parties

| Rôle | Entité |
|---|---|
| Responsable de traitement | **[à renseigner : nom/raison sociale, adresse, contact]** — éditeur de Donjons & Savons (« grisloup »), contact données : donjons@grisloup.com |
| Sous-traitant principal | **Google Ireland Limited**, Gordon House, Barrow Street, Dublin 4, Irlande (contractant UE pour GCP/Firebase) |
| Sous-sous-traitants | Liste Google publiée (cloud.google.com/terms/subprocessors) — la notification des changements se fait par abonnement à cette page |

Aucun autre sous-traitant : pas d'analytics, pas de régie publicitaire, pas de SDK tiers collecteur. Les alertes budget Telegram ne portent aucune donnée personnelle d'utilisateur.

---

## 4. registre des activités de traitement (art. 30 rgpd)

Personnes concernées, pour tous les traitements : membres des clans — **adultes et mineurs** (mineurs uniquement sous consentement parental, cf. `readme.md` §14). Localisation nominale de tous les traitements : **europe-west9 (Paris)**.

| Traitement | Données | Base légale | Durée de conservation |
|---|---|---|---|
| Compte et authentification (Firebase Auth) | UID Google opaque ; email et nom du compte Google conservés par Firebase Authentication | Exécution du contrat (CGU) ; art. 8 : consentement du titulaire de la responsabilité parentale pour les mineurs, porté par la CGU admin | Jusqu'à suppression du compte (page delete-account ou cascade dissolution du clan d'origine) |
| État légal | Région (EU), distinction mineur/majeur **calculée** — la date de naissance n'est jamais persistée | Obligation légale (protection des mineurs) | Vie du compte |
| Acceptation CGU | Timestamp + device ID (`steps.cgu`) | Obligation légale (preuve du consentement) | Vie du compte |
| Boucle de jeu (Firestore `clans*`) | Pseudos choisis librement, XP, PV, gage, journal d'événements, argent de poche distribué | Exécution du contrat | Vie du clan ; cascade de suppression `backend/config.yml` |
| Notifications (FCM) | Tokens push, contenu des notifications de jeu | Exécution du contrat | Rotation des tokens ; suppression avec le compte |
| IA générative (Vertex AI / Gemini) | Inspiration de nom : nom de joueur, nom et description de clan. Conte du butin : + journal du clan (prénoms choisis, tâches, XP, argent de poche). **Jamais** d'identifiant, âge, région ou email | Exécution du contrat (fonctionnalité déclenchée à la demande explicite) | Pas de stockage applicatif des prompts ; données non utilisées pour l'entraînement (CDPA) |
| Journaux techniques (Cloud Functions/Run) | UID, horodatages d'appel | Intérêt légitime (sécurité, débogage) | Rétention Cloud Logging par défaut (30 j) |

**Non collecté, par design** : photos de preuve (stockées uniquement sur l'appareil, jamais transmises), date de naissance brute, ID publicitaire, analytics, géolocalisation, contacts.

**Mesures de sécurité** : règles Firestore custom (`clans`, `clans_logs`), secret de clan croisé via `userindexes`, lecture publique du bucket désactivée, Secret Manager, service account `ddust-backend` à moindre privilège, Cloud Function callable authentifiée, TTL sur `virtuallobby`/`secrets`, chiffrement en transit et au repos (Google par défaut).

**Transferts hors UE** : aucun en fonctionnement nominal (europe-west9). En cas de transfert de secours par Google : SCC intégrées au CDPA.

---

## 5. droits des personnes

- **Suppression** : autonome via https://dvddust.web.app/delete-account/ (connexion Google puis suppression en cascade). La suppression **depuis l'app** reste au chantier « monétisation et légal » (`readme.md` §17) — exigée par Play à terme, la page web suffit au lancement.
- **Accès / rectification / portabilité** : sur demande à donjons@grisloup.com (pseudos et données de jeu rectifiables in-app).
- **Mineurs** : les droits s'exercent via le titulaire de la responsabilité parentale (admin du clan d'origine, cf. CGU art. 6/11).

---

## 6. déclaration data safety play console (annexe pratique)

Traduction du registre en réponses au formulaire *Sécurité des données* :

| Question | Réponse |
|---|---|
| Collecte de données ? | Oui |
| Infos personnelles → **Identifiants utilisateur** (UID) | Collecté, obligatoire, finalité « fonctionnement de l'app / gestion du compte », non partagé |
| Infos personnelles → **Nom** (pseudos, souvent de vrais prénoms) | Collecté, obligatoire, « fonctionnement de l'app », non partagé |
| Infos personnelles → **Adresse e-mail** (Firebase Auth) | Collecté, obligatoire, « gestion du compte », non partagé |
| Activité dans l'app → **Autre contenu généré par l'utilisateur** (journal, descriptions de tâches) | Collecté, « fonctionnement de l'app », non partagé |
| **Appareil ou autres ID** (device ID d'acceptation CGU, tokens FCM) | Collecté, « fonctionnement de l'app », non partagé |
| Photos | **Non collecté** (traitement local uniquement — hors périmètre « collecte » au sens Play) |
| Localisation, contacts, ID publicitaire, analytics | Non collecté |
| Données chiffrées en transit ? | Oui |
| Mécanisme de suppression ? | Oui — URL : https://dvddust.web.app/delete-account/ |
| Partage avec des tiers ? | Non (Vertex AI = sous-traitant agissant pour le compte de l'éditeur, pas un « partage » au sens Play) |

---

## 7. aipd (analyse d'impact, art. 35)

Deux critères CNIL/CEPD sont réunis : **personnes vulnérables** (mineurs) et **usage innovant** (IA générative sur des données les concernant) — deux critères suffisent à rendre l'AIPD **requise avant la mise en production**. Non bloquante pour un test fermé avec des testeurs recrutés en connaissance de cause, mais à mener avant l'ouverture publique. Le présent registre en constitue la matière première ; le modèle CNIL (outil PIA) suffit à un projet de cette taille.

---

## 8. renvois

- `readme.md` §14 — aspects légaux (consentement parental, âge, parental gate, données collectées)
- `legal/documents/` — CGU et politiques de confidentialité (brouillons à valider juridiquement avant production)
- https://dvddust.web.app/fr/legal/ — espace légal public (URL à déclarer dans Play Console)
