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

> **Valeurs exactes et marche à suivre : `saisie_dpa.md`** (généré au build depuis `build.yml`
> → `publisher:` et `dpa:`). Des trois premières cases ci-dessous, **une seule reste manuelle** :
> les contacts essentiels GCP sont posés par `puproject` au déploiement, et l'archivage est fait
> par le build.

- [ ] **Console Firebase** → onglet *Confidentialité des données* : renseigner le contact protection des données, laisser le représentant UE (art. 27) vide — l'éditeur est établi dans l'Union. **Seule saisie manuelle du lot**, aucune API ne l'expose. → `saisie_dpa.md` §1
- [ ] **Contacts essentiels GCP**, catégorie *Juridique* : posés par `puproject` (`backend/config.yml` → `conf.project.essential_contacts`). Rien à faire, seulement à vérifier. → `saisie_dpa.md` §2
- [ ] **Archivage daté du CDPA et des DPST** dans `legal/` (traçabilité, art. 5.2 — *accountability*) : téléchargé, vérifié et daté **par le build**, qui détecte aussi les nouvelles versions publiées par Google. Un avertissement jaune signale un échec. → `saisie_dpa.md` §3
- [ ] **Vérifier l'identité juridique** rattachée au compte de facturation GCP : c'est cette entité (personne physique ou société) qui est partie au CDPA — elle doit coïncider avec l'éditeur déclaré dans les CGU, les pages légales du site et le compte Play Console.
- [ ] **Tenir à jour le registre** (section 4) à chaque évolution du produit (économie de jeu, abonnements, multitenancy). L'identité de la section 3, elle, n'est plus à compléter : elle vient de `build.yml` → `publisher:`.
- [ ] Avant production (pas bloquant pour le test fermé) : mener l'**AIPD** (section 7).

---

## 3. qualification des parties

| Rôle | Entité |
|---|---|
| Responsable de traitement | **Entrepreneur individuel immatriculé, exerçant sous le nom commercial « Grisloup »** — éditeur de Donjons & Savons. SIREN `109354092`, immatriculé au RNE le **2026-09-02**, code APE `58.29C`. Dénomination, adresse de domiciliation et contact données : `build.yml` → `publisher:`, restitués dans `saisie_dpa.md`. Ils ne sont pas recopiés ici : une identité qui vit à deux endroits finit par y différer |
| Sous-traitant principal | **Google Ireland Limited**, Gordon House, Barrow Street, Dublin 4, Irlande (contractant UE pour GCP/Firebase) |
| Sous-sous-traitants | Liste Google publiée (cloud.google.com/terms/subprocessors) — la notification des changements se fait par abonnement à cette page |

Aucun autre sous-traitant : pas d'analytics, pas de régie publicitaire, pas de SDK tiers collecteur. Les alertes budget Telegram ne portent aucune donnée personnelle d'utilisateur.

⚠️ **Le responsable de traitement reste une personne physique**, et l'immatriculation ne change pas cela : une entreprise individuelle n'est pas une personne morale distincte de son entrepreneur. Ce sont sa **qualification**, son **adresse** et son **numéro** qui ont changé le 2026-09-02, pas son identité.

C'est ce qui a permis de trancher, le 2026-09-03, en faveur d'une mise à jour des **mentions légales et de la politique de confidentialité SANS re-acceptation des CGU** : la partie au traitement est la même, aucun droit ni aucune obligation n'est modifié, et bumper les CGU aurait forcé à re-notifier tous les inscrits de la beta pour l'ajout d'un numéro. Les documents restent en `v1`, complétés sur place — cf. `build/tools/set_publisher_siren.py`, qui porte l'arbitrage et le geste. **Un changement de FOND, lui, se bumperait** ; c'est la ligne de partage à tenir.

La même identité doit se retrouver, à l'identique, sur le compte marchand Play, le compte de facturation GCP, l'éditeur déclaré dans les CGU et la mention « éditeur » des pages légales du site. Le jour où une société existerait, la partie au CDPA changerait vraiment : il faudrait alors reprendre ces cinq endroits, publier une nouvelle version des CGU et mettre à jour ce registre. Ce n'est pas le cas ici — et la SASU est sortie du plan.

Rappel Play : un vendeur d'abonnements dans l'UE voit son nom et son adresse **affichés publiquement** sur sa fiche store. Depuis le 2026-09-02, cette adresse est une **domiciliation** : l'exposition est devenue sans conséquence, ce qui était le motif central de toute la démarche.

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

- **Suppression** : deux chemins, tous deux livrés. Web : https://donjons.grisloup.com/delete-account/ (connexion Google puis suppression en cascade). In-app : écran Personnage → menu kebab → « Supprimer mon compte », overlay d'avertissements répétés puis appel de la même Cloud Function `delete_user_data`.
- **Information** : la politique de confidentialité de la région, de la langue et de l'état légal de la session s'ouvre depuis l'app — écran Personnage → menu kebab → « Mes données ». Les CGU sont accessibles par les liens inline des écrans de consentement parental.
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
| Mécanisme de suppression ? | Oui — URL : https://donjons.grisloup.com/delete-account/ |
| Partage avec des tiers ? | Non (Vertex AI = sous-traitant agissant pour le compte de l'éditeur, pas un « partage » au sens Play) |

---

## 7. aipd (analyse d'impact, art. 35)

Deux critères CNIL/CEPD sont réunis : **personnes vulnérables** (mineurs) et **usage innovant** (IA générative sur des données les concernant) — deux critères suffisent à rendre l'AIPD **requise avant la mise en production**. Non bloquante pour un test fermé avec des testeurs recrutés en connaissance de cause, mais à mener avant l'ouverture publique. Le présent registre en constitue la matière première ; le modèle CNIL (outil PIA) suffit à un projet de cette taille.

---

## 8. renvois

- `saisie_dpa.md` — **généré au build** : la feuille à ouvrir devant les consoles (valeurs exactes)
- `saisie_dpa.tpl.md` — le gabarit dont elle est rendue ; c'est lui qu'on édite, jamais la sortie
- `readme.md` §14 — aspects légaux (consentement parental, âge, parental gate, données collectées)
- `legal/documents/` — CGU et politiques de confidentialité (brouillons à valider juridiquement avant production)
- https://donjons.grisloup.com/fr/legal/ — espace légal public (URL à déclarer dans Play Console)
