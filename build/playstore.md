<!-- généré : 20260808 -->
# playstore — donjons & savons

Dossier de publication Play Store : tout ce qu'il y a à renseigner, section par section, dans l'ordre où la console le demande. Complète `legal/dpa.md` (registre RGPD) et `readme.md` §14 (aspects légaux). Les champs `[à renseigner]` sont les seuls qui attendent une décision.

Rappel du parcours : compte développeur → **compte marchand** → créer l'app → déclarations « Contenu de l'app » → fiche du store → **produits d'abonnement + RTDN** → release en **test fermé** (≥ 12 testeurs opt-in pendant 14 jours consécutifs, viser 20) → demande d'accès production → production.

> **Révisé 2026-08-11 — l'app se lance payante.** La beta publique gratuite est supprimée
> (voir `strategie.md`). Cela ajoute au dossier tout le volet monétisation ci-dessous, et
> **corrige une déclaration IARC devenue fausse** (« pas d'achats numériques »). Le compte
> marchand et les 14 jours de test fermé sont sur le chemin critique : à engager avant le
> développement, pas après.

---

## dpa

Le « DPA Google » ne se signe pas : le **Cloud Data Processing Addendum** (GCP, dont Vertex AI) et les **Firebase Data Processing and Security Terms** sont incorporés automatiquement aux conditions d'utilisation. Ce qui reste est du renseignement de contacts et de l'archivage — détail juridique complet dans `legal/dpa.md`.

À renseigner, dans l'ordre :

| Où | Champ | Valeur |
|---|---|---|
| Console Firebase → projet `dvddust` → ⚙️ *Paramètres du projet* → onglet *Confidentialité des données* | Contact « responsable de la protection des données » (DPO — facultatif pour un indé, mais renseigner un contact) | **[à renseigner : nom]**, donjons@grisloup.com |
| Même onglet | Représentant UE (art. 27) | **Néant** — éditeur établi dans l'UE, ne rien renseigner |
| Console GCP → *IAM et administration* → *Contacts essentiels* | Contact catégorie « Juridique » (notifications sous-traitants, incidents) | donjons@grisloup.com |
| Console GCP → *Facturation* | Vérifier que l'identité du compte de facturation = l'éditeur déclaré dans les CGU et le compte Play Console | **[à vérifier]** |
| `legal/` | Archiver un PDF **daté** des deux textes : cloud.google.com/terms/data-processing-addendum et firebase.google.com/terms/data-processing-terms | à refaire à chaque nouvelle version Google |

Aucune case « j'accepte » n'existe plus dans les consoles récentes : l'archive datée + les contacts renseignés constituent la preuve d'adhésion (accountability art. 5.2). L'emplacement des onglets peut varier légèrement selon les versions de la console.

---

## data safety

Formulaire *Play Console → Contenu de l'app → Sécurité des données*. Réponses dans l'ordre du questionnaire — la justification de chaque ligne est dans `legal/dpa.md` §4 et §6.

**Questions générales :**

| Question | Réponse |
|---|---|
| L'app collecte-t-elle ou partage-t-elle des données utilisateur ? | **Oui** |
| Toutes les données sont-elles chiffrées en transit ? | **Oui** |
| Proposez-vous un moyen de demander la suppression des données ? | **Oui** — URL : `https://dvddust.web.app/delete-account/` |
| L'app permet-elle de créer un compte ? | **Oui** (compte via Google) — suppression : la même URL, plus l'option in-app (écran Personnage → menu kebab → suppression de compte) |

**Types de données à déclarer** — pour chacun : *collecté* oui, *partagé* non, *traité de façon éphémère* non, *obligatoire* (pas facultatif) :

| Catégorie → type | Contenu réel | Finalités à cocher |
|---|---|---|
| Infos personnelles → **Nom** | pseudos choisis librement (souvent de vrais prénoms) | Fonctionnement de l'appli |
| Infos personnelles → **Adresse e-mail** | e-mail du compte Google conservé par Firebase Auth | Fonctionnement de l'appli, Gestion du compte |
| Infos personnelles → **ID utilisateur** | UID Firebase opaque | Fonctionnement de l'appli, Gestion du compte |
| Activité dans l'app → **Autres contenus générés par l'utilisateur** | journal du clan, descriptions de tâches, noms/descriptions de clan | Fonctionnement de l'appli |
| **Appareil ou autres ID** | device ID d'acceptation CGU, tokens FCM | Fonctionnement de l'appli |

**À ne PAS déclarer** (non collecté au sens Play) :

- **Photos** : preuves stockées uniquement sur l'appareil, jamais transmises → traitement local, hors périmètre.
- Localisation, contacts, ID publicitaire, analytics, historique web, santé, finances : rien.
- **Partage avec des tiers : Non partout** — Vertex AI est un sous-traitant agissant pour le compte de l'éditeur, pas un « partage » au sens du formulaire.

---

## fiche

*Play Console → Présence sur le Play Store → Fiche principale.*

**Textes** (fr = langue par défaut ; décliner en/es dans les fiches traduites) :

| Champ | Contenu |
|---|---|
| Nom de l'app (30 car. max) | `Donjons & Savons` |
| Description courte FR (80 car. max) | `Transformez les corvées en aventure familiale : tâches-monstres, XP et butins.` |
| Description courte EN | `Turn chores into a family adventure: monster tasks, XP, levels and loot chests.` |
| Description courte ES | `Convierte las tareas en una aventura familiar: monstruos, XP, niveles y botín.` |

Description longue FR (4000 car. max) — proposition, à ajuster puis traduire :

> ⚔️ Les corvées sont des monstres. Abattez-les en famille !
>
> Donjons & Savons transforme la maison en donjon : la famille devient un clan, chaque tâche ménagère devient un monstre à vaincre, et chaque victoire rapporte de l'expérience au joueur comme au clan. Quand le coffre du clan est plein, la famille ouvre un butin — une vraie récompense, décidée à l'avance par les parents. Le jeu ne simule pas la récompense : il structure la promesse familiale.
>
> 🛡️ Comment ça marche
> • Un parent fonde le clan et invite la famille (QR code ou lien sécurisé).
> • Chacun choisit son avatar et son nom d'aventurier.
> • Ranger sa chambre, sortir les poubelles, mettre la table : 19 domaines et plus de 150 tâches, ajustés à votre foyer — et vos propres tâches en plus.
> • Les parents valident les exploits (preuve photo possible — elle reste sur le téléphone).
> • XP, niveaux, titres, points de vie, journal du clan et cérémonies d'ouverture du butin.
>
> 👨‍👩‍👧‍👦 Pensé pour les familles
> • Aucune publicité, aucun traceur, aucun achat surprise.
> • Les mineurs ne rejoignent un clan qu'avec le consentement d'un adulte responsable.
> • Les photos ne quittent jamais l'appareil ; les données restent hébergées en Europe.
> • Suppression de compte autonome, dans l'app ou sur le site.
>
> Le butin est la promesse tenue. À vos épées — et à vos éponges !

**Assets graphiques** (sources existantes, à retoucher au besoin) :

| Asset Play | Contrainte | Source |
|---|---|---|
| Icône | 512×512, PNG 32 bits, ≤ 1 Mo | `hosting/web/icon-512.png` (prête, 512×512) — source HD : `resources/icon/icon.png` (1536×1536) |
| Image de présentation (feature graphic) | **1024×500**, PNG/JPEG | à produire depuis `resources_cloud/donjon/images/big/logo.png` (3104×1372 → recadrer au ratio 2,048:1 puis réduire) |
| Captures d'écran téléphone | 2 à 8, PNG/JPEG, ≤ 8 Mo, ratio entre 16:9 et 9:16 | `hosting/web/assets/img/*.png` (720×1236, conformes ; idéal 1080×1920). Sélection proposée : `04-welcome`, `21-birth-of-clan`, `40-time-to-clean`, `32-choose-avatar`, `33-me`, `54-pocket-money`, `59-loot-chest`, `67-clan` |
| Tablette 7"/10" (facultatif mais recommandé) | 2 à 8 par format | à capturer si distribution tablette |

**Réglages de la fiche :**

| Champ | Valeur |
|---|---|
| Type / catégorie | Application → **Parentalité** (alternative défendable : Jeux → Jeux de rôle ; Parentalité colle mieux à l'usage réel et à l'audience mixte) |
| Tags | famille, corvées, tâches, enfants, motivation, RPG |
| E-mail de contact (public) | donjons@grisloup.com |
| Site web | `https://dvddust.web.app` |
| Langues de la fiche | fr-FR (défaut), en-US, es-ES |
| Pays — test fermé | France (+ Belgique, Suisse, Canada si des testeurs s'y trouvent) |
| Pays — production | zone EU au lancement (le backend `us-*` existe, ouvrir les US ensuite) |

---

## autres déclarations « contenu de l'app »

Toutes obligatoires avant la première release, y compris en test fermé :

| Déclaration | Réponse |
|---|---|
| URL de politique de confidentialité | `https://dvddust.web.app/fr/legal/` (pointe vers les versions adulte/mineur en 3 langues) |
| Publicités | **Non**, aucune |
| **Achats dans l'application** | **Oui** — abonnements 2.99–4.99 €/mois (29.99–49.99 €/an) et achats à l'unité 1.99–5.99 €. Play calcule et affiche lui-même la fourchette de prix sur la fiche |
| **Public cible** | cocher **6-8, 9-12, 13-15, 16-17 et 18+** → app « audience mixte » → questionnaire Family Policy : pas de pub, pas d'ID publicitaire, pas d'analytics, parental gate en place — tout est déjà conforme (`readme.md` §14) |
| Classification du contenu (IARC) | questionnaire en tant qu'app. Déclarer : violence fantastique très légère (monstres caricaturaux, mécanique de « mort » du personnage), interactions entre utilisateurs **au sein d'un cercle privé** (clan familial), pas d'échange avec des inconnus, pas de partage de localisation, et **oui aux achats numériques** (⚠️ corrigé le 2026-08-11 : le dossier déclarait « pas d'achats numériques », valable pour la beta gratuite abandonnée — une déclaration IARC fausse est un motif de retrait). Attendu : PEGI 3/7, éventuellement assorti de la mention « achats intégrés » |
| Contenu généré par IA (si le questionnaire apparaît) | déclarer la génération de noms (« Inspire-moi ») et le conte narratif du butin ; contenu borné, pas de chat libre |
| Applis d'actualités / santé / gouvernement / financières | Non partout |
| **Accès à l'app** (App access) | l'app exige une connexion Google → fournir un **compte Google de test dédié** avec un clan pré-créé + instructions pas à pas pour l'équipe de revue. **[à créer : compte de test]** |

---

## monétisation

Ajouté le 2026-08-11 avec la décision de lancer payant. Stack retenue : `in_app_purchase`
natif + backend maison (pas de RevenueCat) — détail technique dans `readme.md` et `vision.md`.

### compte marchand — à faire en premier

| Étape | Détail |
|---|---|
| Créer le profil de paiement | Play Console → *Configuration → Informations de paiement*. Vérification d'identité et de compte bancaire : **c'est le poste le plus long du dossier**, à engager avant tout développement |
| Cohérence d'identité | Le titulaire du compte marchand doit correspondre à l'éditeur déclaré dans les CGU et sur la fiche — même point de vigilance que la ligne « facturation » de la section dpa |
| Pays de vente | Zone EU au lancement, aligné sur la fiche |

### produits

Deux abonnements distincts (les *base plans* servent les périodicités, les *abonnements distincts* servent les niveaux de bénéfice) :

| Abonnement | Base plans | Bénéfice |
|---|---|---|
| `ddust_standard` | `standard-monthly` 2.99 € · `standard-yearly` 29.99 € | max 5 enfants, 4 adultes |
| `ddust_unlimited` | `unlimited-monthly` 4.99 € · `unlimited-yearly` 49.99 € | illimité |

Offres attachées à chaque base plan :

- `essai-14j` — essai gratuit 14 jours, éligibilité *acquisition de nouveaux clients*
- `fondateur` — **éligibilité déterminée par le développeur** : essai allongé + première année remisée. L'app ne transmet l'`offerToken` fondateur que pour les clans éligibles, le cutoff étant lu côté serveur

Produits à l'unité (non consommables) : validations auto 1.99 €, packs contenu 3.99 €, pack thèmes 5.99 €. Livrés avec le socle extensions ; les contenus suivent avec `ddust/eco` et `ddust/themes`.

⚠️ Un abonnement est souscrit **par clan**, jamais par utilisateur — c'est ce qu'annoncent déjà les CGU (« un seul abonnement et un seul payeur par clan »). Le rattachement passe par l'identifiant de compte obfusqué transmis à l'achat.

### notifications temps réel (RTDN)

| Étape | Détail |
|---|---|
| Lier Play Console au projet GCP | *Configuration → Accès à l'API* → projet `dvddust`, puis activer `androidpublisher.googleapis.com` |
| Compte de service | Créé côté infra, invité dans *Utilisateurs et autorisations* avec « Afficher les données financières » + « Gérer les commandes et abonnements » |
| Topic Pub/Sub | Créé dans `dvddust`, avec `google-play-developer-notifications@system.gserviceaccount.com` en publieur, puis renseigné dans *Monétisation → Configuration de la monétisation* |

### banc de test

- **Testeurs sous licence** (*Configuration → Test de licence*) : leurs achats sont **gratuits**. Conséquence directe sur le lancement — les familles du test fermé ne paieront jamais et ne peuvent pas être récompensées par une offre Play ; leur compensation passe par les crédits de mois côté serveur (voir `strategie.md`).
- **Cartes de test** : « approuve toujours » et surtout **« refuse toujours »**, seul moyen de déclencher un vrai défaut de paiement.
- **Renouvellements accélérés** : en test, un abonnement mensuel se renouvelle en quelques minutes — le cycle grâce → hold → locked j50 est donc exerçable en une session au lieu de 50 jours. À faire avant la mise en production : c'est la partie la moins rattrapable après coup.
- Tester un achat **exige un APK déjà uploadé** sur une piste, signé avec la clé finale et au bon `versionCode`.

### légal lié

Les CGU v5 doivent être en ligne avant la première release payante : essai à **14 jours** (les v3/v4 annoncent encore 15), cycle de défaut de paiement, droit de rétractation, renouvellement 24 h, et description de l'offre fondateurs.

---

## testeurs, oauth et family link

- **Écran de consentement OAuth en production** : dans la console GCP (*API et services → Écran de consentement OAuth*), le projet doit être en statut **En production**, pas « Test » — sinon seuls les comptes listés comme test users peuvent se connecter, et aucun testeur du Play Store n'entrera. Vérifier aussi que nom d'app, logo et domaines autorisés sont propres (une vérification de marque par Google peut s'ensuivre).
- **Comptes enfants (Family Link)** : un enfant de moins de 13/15 ans avec un compte supervisé **peut** utiliser « Se connecter avec Google » — la demande part au parent, qui l'approuve depuis Family Link (ou active en amont *Paramètres → Contrôles → Applis tierces*). Prévoir dans le guide des familles testeuses : 1) le parent installe et approuve l'app côté enfant, 2) l'enfant se connecte, le parent reçoit la demande d'autorisation, 3) le parent approuve. Vérifier dans l'app que le refus de connexion affiche un message compréhensible plutôt qu'un échec silencieux.
- **Recrutement** : viser ~20 familles ; le compteur d'opt-in ne doit jamais passer sous 12 pendant les 14 jours, et les testeurs doivent réellement utiliser l'app. Un **groupe Google** comme liste de testeurs évite de re-soumettre à chaque ajout.
