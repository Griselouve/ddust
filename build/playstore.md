<!-- généré : 20260808 -->
# playstore — donjons & savons

Dossier de publication Play Store : tout ce qu'il y a à renseigner, section par section, dans l'ordre où la console le demande. Complète `legal/dpa.md` (registre RGPD) et `readme.md` §14 (aspects légaux). Les champs `[à renseigner]` sont les seuls qui attendent une décision.

> **Ce document dit QUOI saisir. `publication.md` dit dans quel ORDRE agir, et pourquoi.**
> Les deux se lisent ensemble : la marche à suivre phase par phase (démarches, dépendances,
> calendrier, recette) vit dans `publication.md` ; les valeurs à recopier dans les formulaires
> vivent ici.

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
| Console Firebase → projet `dvddust` → ⚙️ *Paramètres du projet* → onglet *Confidentialité des données* | Contact « responsable de la protection des données » (DPO — facultatif pour un indé, mais renseigner un contact) | **[à renseigner : nom civil de l'éditeur]**, donjons@grisloup.com |
| Même onglet | Représentant UE (art. 27) | **Néant** — éditeur établi dans l'UE, ne rien renseigner |
| Console GCP → *IAM et administration* → *Contacts essentiels* | Contact catégorie « Juridique » (notifications sous-traitants, incidents) | donjons@grisloup.com |
| Console GCP → *Facturation* | Vérifier que l'identité du compte de facturation = l'éditeur déclaré dans les CGU et le compte Play Console | **[à vérifier]** — au lancement : personne physique sous le nom commercial « grisloup.com » (cf. `legal/dpa.md` §3) |
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
| Proposez-vous un moyen de demander la suppression des données ? | **Oui** — URL : `https://donjons.grisloup.com/delete-account/` |
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
| Image de présentation (feature graphic) | **1024×500**, PNG/JPEG | **prête** : `hosting/web/assets/img/playstore.png` (1024×500, 775 Ko) — dérivée de `resources_cloud/donjon/images/big/logo.png` (3104×1372) |
| Captures d'écran téléphone | 2 à 8, PNG/JPEG, ≤ 8 Mo, ratio entre 16:9 et 9:16 | **prêtes** : `hosting/web/assets/img/*.png` (720×1236, conformes — au-dessus du minimum Play de 320 px de côté court). Prendre les 8 `.png`, pas les `.webp` : `04-welcome`, `21-birth-of-clan`, `40-time-to-clean`, `32-choose-avatar`, `33-me`, `54-pocket-money`, `59-loot-chest`, `67-clan` |
| Tablette 7"/10" (facultatif mais recommandé) | 2 à 8 par format | à capturer si distribution tablette |

**Réglages de la fiche :**

| Champ | Valeur |
|---|---|
| Type / catégorie | Application → **Parentalité** (alternative défendable : Jeux → Jeux de rôle ; Parentalité colle mieux à l'usage réel et à l'audience mixte) |
| Tags | famille, corvées, tâches, enfants, motivation, RPG |
| E-mail de contact (public) | donjons@grisloup.com |
| Site web | `https://donjons.grisloup.com` |
| Langues de la fiche | fr-FR (défaut), en-US, es-ES |
| Pays — test fermé | France (+ Belgique, Suisse, Canada si des testeurs s'y trouvent) |
| Pays — production | zone EU au lancement (le backend `us-*` existe, ouvrir les US ensuite) |

---

## autres déclarations « contenu de l'app »

Toutes obligatoires avant la première release, y compris en test fermé :

| Déclaration | Réponse |
|---|---|
| URL de politique de confidentialité | `https://donjons.grisloup.com/fr/legal/` (pointe vers les versions adulte/mineur en 3 langues) |
| Publicités | **Non**, aucune |
| **Achats dans l'application** | **Oui** — abonnements 1.99–7.99 €/mois (19.99–64.99 €/an) et achats à l'unité 1.99–5.99 €. Play calcule et affiche lui-même la fourchette de prix sur la fiche |
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

**À préparer avant la saisie** — le formulaire ne se remplit pas de mémoire :

| Champ | Valeur pour ce projet |
|---|---|
| Type de profil | **Particulier** (personne physique) |
| Nom légal | Le **nom civil**, tel qu'il figure sur la pièce d'identité. Pas « grisloup.com », qui n'est qu'un nom commercial |
| Adresse légale | Adresse **physique réelle** — **les boîtes postales sont refusées** |
| Contact | Nom du représentant, e-mail, téléphone |
| E-mail d'assistance public | donjons@grisloup.com |
| Site web | `https://donjons.grisloup.com` |
| Compte bancaire | IBAN **domicilié dans le pays du profil de paiement**, titulaire identique au nom légal |

**Deux vérifications ensuite**, indépendantes, parallèles, et qui se comptent en jours :

- **Identité** — pièce d'identité en cours de validité, parfois complétée d'un justificatif de domicile. À lancer immédiatement, sans attendre la relance.
- **Compte bancaire** — Google verse un **petit dépôt de contrôle** dont il faut reporter le montant dans la console : compter **jusqu'à 3 jours ouvrés** pour que la banque le passe. Si le dépôt ne peut pas être émis, la vérification bascule sur l'**envoi de documents bancaires officiels**, avec un délai d'environ **5 jours**. ⚠️ Surveiller le relevé : le montant est de quelques centimes et passe inaperçu.

⚠️ **Un compte bancaire non vérifié n'est pas un détail administratif** : Google retire la présence développeur **et les applications** de Google Play tant qu'il ne l'est pas.

⚠️ **Vendeur au sens UE.** Vendre des abonnements dans l'Union fait afficher **nom, adresse et téléphone publiquement** sur la fiche Play. Inévitable pour un particulier ; c'est l'argument le plus concret en faveur d'une structure quand les revenus le justifieront.

**Migration vers une société, plus tard.** Le sens de conversion est le bon : un compte **particulier peut devenir organisation** (numéro **D-U-N-S**, site web d'organisation vérifié, profil de paiement organisationnel, puis **72 h d'attente** avant toute soumission). L'inverse est **impossible** et impose de créer un nouveau compte développeur, donc de tout republier. Démarrer en particulier est le choix réversible.

### produits

Cinq abonnements distincts (les *base plans* servent les périodicités, les *abonnements distincts* servent les niveaux de bénéfice) :

| Abonnement | Base plans | Bénéfice |
|---|---|---|
| `ddust_essentiel` | `essentiel-monthly` 1.99 € · `essentiel-yearly` 19.99 € | max 2 joueurs |
| `ddust_clan` | `clan-monthly` 2.99 € · `clan-yearly` 24.99 € | max 4 joueurs |
| `ddust_tribu` | `tribu-monthly` 4.99 € · `tribu-yearly` 39.99 € | max 7 joueurs |
| `ddust_guilde` | `guilde-monthly` 5.99 € · `guilde-yearly` 49.99 € | max 12 joueurs |
| `ddust_royaume` | `royaume-monthly` 7.99 € · `royaume-yearly` 64.99 € | joueurs illimités |

Le décompte porte sur les **membres actifs du clan, admins compris**, sans distinction d'enfant ni d'adulte : un joueur est un joueur. Aucun bénéfice de jeu n'est réservé à un palier — seule la taille du clan les distingue, ce qui est cohérent avec la promesse « on ne paie jamais pour avancer » de la fiche.

⚠️ **Le suffixe des base plans est contractuel** : `dvstore.basePlanFor` choisit la périodicité par `endsWith("-monthly")` / `endsWith("-yearly")`. Un base plan nommé autrement rend l'annuel inachetable **en silence** — l'app repart sur le mensuel sans un mot.

Offres attachées à chaque base plan :

- `essai-14j` — essai gratuit 14 jours, éligibilité *acquisition de nouveaux clients*
- `fondateur` — **éligibilité déterminée par le développeur** : essai allongé + première année remisée. L'app ne transmet l'`offerToken` fondateur que pour les clans éligibles, le cutoff étant lu côté serveur

Produits à l'unité (non consommables) : validations auto 1.99 €, packs contenu 3.99 €, pack thèmes 5.99 €. Livrés avec le socle extensions ; les contenus suivent avec `ddust/eco` et `ddust/themes`.

⚠️ Un abonnement est souscrit **par clan**, jamais par utilisateur — c'est ce qu'annoncent déjà les CGU (« un seul abonnement et un seul payeur par clan »). Le rattachement passe par l'identifiant de compte obfusqué transmis à l'achat.

### notifications temps réel (RTDN)

| Étape | Détail |
|---|---|
| Lier Play Console au projet GCP | *Configuration → Accès à l'API* → projet `dvddust`, puis activer `androidpublisher.googleapis.com` |
| Compte de service | `deva-store@dvddust` (créé par `pustore`), à inviter dans *Utilisateurs et autorisations* avec « Afficher les données financières » + « Gérer les commandes et abonnements » |
| Topic Pub/Sub | `eu-play-rtdn`, créé par `pustore` avec `google-play-developer-notifications@system.gserviceaccount.com` déjà en publieur. À renseigner dans *Monétisation → Configuration de la monétisation* sous la forme `projects/dvddust/topics/eu-play-rtdn` |

⚠ Play n'accepte **qu'un seul topic par application** alors que l'infra en crée un par région
(`eu-play-rtdn`, `us-play-rtdn`). C'est voulu : ne renseigner que celui d'Europe — la fonction
européenne traite les deux régions de données (`STORE_REGIONS: "eu,us"`), l'autre reste muet.

**Identifiants à respecter au caractère près** — ils sont câblés dans le catalogue
(`resources_cloud/general/layers/store-base-global.yml`) et dans la conf backend :

| élément | identifiant |
|---|---|
| abonnements | `ddust_essentiel`, `ddust_clan`, `ddust_tribu`, `ddust_guilde`, `ddust_royaume` |
| base plans | `essentiel-monthly`/`-yearly`, `clan-monthly`/`-yearly`, `tribu-monthly`/`-yearly`, `guilde-monthly`/`-yearly`, `royaume-monthly`/`-yearly` |
| offres | `essai-14j`, `fondateur` |

L'offre d'essai doit s'appeler exactement `essai-14j` : c'est ce que lit `TRIAL_OFFER_ID`
pour distinguer l'état « essai » de l'état « actif ». De même, `fondateur` est lu par
`FOUNDER_OFFER_ID` : c'est ce qui marque durablement `clans_store.founder` quand Play a
réellement appliqué l'offre de lancement.

⚠️ Les **dix base plans doivent être actifs en console**, pas seulement déclarés. L'app ne
peut proposer que ce que Play lui renvoie : un base plan inactif rend sa périodicité
inachetable, et le journal le dit à l'ouverture (`[dvstore] ddust_clan: N entrée(s) Play
[…]`). C'est le premier endroit à regarder si l'annuel n'apparaît pas.

### deux gestes hors console

Ni Play ni Pulumi ne peuvent les poser :

| Geste | Détail |
|---|---|
| Document `store_config/founders` | Base Firestore `eu-store`, collection `store_config`, document `founders` : `{ cutoff: <Timestamp>, offer_id: "fondateur", default_credit_months: 0 }`. Sans lui, `store_eligibility` rend `""` et **personne n'est fondateur** — l'offre existe en console mais n'est jamais demandée. Le cutoff vit là et pas en variable d'environnement précisément pour se décaler sans redéploiement |
| `GRANT_ADMINS` | UID Firebase du compte d'exploitation, dans l'environnement de `store_grant` (`backend/config.yml`). **Vide = fonction fermée à tout le monde**, ce qui est le bon défaut pour une fonction qui distribue des mois gratuits. À renseigner avant de compenser la première famille du test fermé |

### banc de test

Les scénarios à dérouler et leur ordre sont dans `publication.md` § phase 5. Ci-dessous, l'outillage
et les valeurs de référence.

**Prérequis.** Tester un achat exige une version **déjà publiée sur une piste** (interne suffit),
signée par Play et au bon `versionCode` — pas un build local. Compter quelques heures avant qu'elle
ne devienne installable pour un testeur qui vient de rejoindre.

**Testeurs sous licence** (*Configuration → Test de licence*) : leurs achats sont **gratuits**. Ils
doivent **aussi** avoir rejoint la piste via son lien d'opt-in — les deux listes sont distinctes.
Conséquence directe sur le lancement : les familles du test fermé ne paieront jamais et ne peuvent
pas être récompensées par une offre Play ; leur compensation passe par les crédits de mois côté
serveur (`store_grant`, voir `strategie.md`).

**Play Billing Lab** — application à installer depuis le Play Store sur le téléphone de test,
connectée avec le **même compte** que le testeur de licence. C'est elle qui force les transitions
d'état (*Subscription settings → Manage → Subscription state* → Grace period / Account hold /
Next renewal), permet de rejouer une offre d'essai autant de fois que voulu, et de simuler un autre
pays. ⚠️ Ses configurations **expirent au bout de 2 heures** : les reposer si la session s'éternise.

**Moyens de paiement de test**, dans la feuille de paiement Play :

| Instrument | Ce qu'il permet d'exercer |
|---|---|
| Approuve toujours | parcours nominal |
| **Refuse toujours** | **seul moyen de déclencher un vrai défaut de paiement** |
| Approuve lentement | achat différé (`PurchaseStatus.pending`) |
| Refuse lentement | échec différé |
| **Approuve puis rétrofacture** | **seul moyen d'exercer proprement le chemin de remboursement** |

**Durées accélérées** — c'est ce qui rend le cycle complet exerçable en une après-midi :

| Ce qu'on teste | Durée réelle | En test |
|---|---|---|
| Renouvellement hebdomadaire | 1 semaine | 5 min |
| **Renouvellement mensuel** | 1 mois | **5 min** |
| Renouvellement trimestriel / semestriel | 3 / 6 mois | 10 / 15 min |
| **Renouvellement annuel** | 1 an | **30 min** |
| **Essai gratuit** | 14 jours | **3 min** |
| **Période de grâce** | paramétrée en console | **5 min** |
| **Suspension (account hold)** | jusqu'à 30 j | **10 min** |
| Fenêtre d'acquittement | 3 jours | **5 min** |
| Mise en pause | 1 / 2 / 3 mois | 5 / 10 / 15 min |

Le cycle grâce → hold → locked j50 est donc exerçable en une session au lieu de 50 jours. **À faire
avant la mise en production : c'est la partie la moins rattrapable après coup.**

**Trois pièges du banc de test :**

- ⚠️ **Un achat de test non acquitté est remboursé automatiquement au bout de 3 minutes.** Si la
  chaîne d'acquittement n'est pas complète, les achats disparaissent tout seuls — symptôme qu'on
  prend facilement pour un bug d'affichage.
- ⚠️ **Maximum 6 renouvellements** par abonnement de test : au-delà il expire de lui-même. Prévoir un
  compte de test neuf pour les longues séries.
- ⚠️ **Les achats de test ne calculent pas la TVA.** Ne rien conclure des montants affichés.

### légal lié

Les CGU **v5** (EU) et **v3** (US) portent l'essai à **14 jours**, le cycle de défaut de paiement, le droit de rétractation, le renouvellement 24 h et la description de l'offre fondateurs. Elles sont **générées et référencées par le site** (les liens des pages `/legal/` ont été repointés, et les mentions résiduelles « 15 jours » corrigées le 2026-08-18).

⚠️ Reste à les **servir** : elles ne seront en ligne qu'après le prochain upload `pudocuments`. À faire avant la première release payante — `publication.md` § phase 1.

---

## signature play et second client oauth

⚠️ **Le piège de la première publication, et il ne se voit qu'en production.**

Play **re-signe** l'AAB avec sa propre clé. L'app installée depuis le Store ne porte donc pas
l'empreinte de la clé d'*upload* (celle que le builder gère et persiste en Firestore), mais celle de
la clé de *signature* de Google. Or le client OAuth Android créé au déploiement ne connaît que la
première : **la connexion Google échoue pour toute installation venant du Store**, alors qu'elle
fonctionne parfaitement sur un build local ou sideloadé. Le symptôme est déroutant — tout marche
chez soi, rien ne marche chez les testeurs.

C'est une dépendance circulaire : l'empreinte n'existe qu'**après** le premier upload. D'où cet
ordre, obligatoire :

| # | Geste |
|---|---|
| 1 | Uploader le premier AAB sur une piste (interne suffit) |
| 2 | *Play Console → Test et publication → Signature de l'application* → copier le **SHA-1 de la clé de signature de l'application** — surtout pas celle d'importation |
| 3 | Coller dans `backend/config.yml` → `conf.oauth.android.play_sha1s.client` (aujourd'hui `""`) |
| 4 | Redéployer le backend → un **second client OAuth Android** est créé avec cette empreinte |
| 5 | Réinstaller depuis la piste et refaire l'onboarding complet : c'est le seul test qui prouve le correctif |

Note connexe sur les versions : `versionCode` est à 1 et n'a jamais été uploadé. Dès le premier
envoi, tout build suivant doit porter un numéro **strictement supérieur** (`version=patch`). Un
`versionCode` déjà consommé est refusé, même si l'upload correspondant a été supprimé.

---

## testeurs, oauth et family link

- **Écran de consentement OAuth en production** : dans la console GCP (*API et services → Écran de consentement OAuth*), le projet doit être en statut **En production**, pas « Test » — sinon seuls les comptes listés comme test users peuvent se connecter, et aucun testeur du Play Store n'entrera. Vérifier aussi que nom d'app, logo et domaines autorisés sont propres (une vérification de marque par Google peut s'ensuivre).
  - ⚠️ **Le statut « Test » n'est PAS le bon réglage pour la phase de test fermé Play.** Ce sont deux listes de testeurs sans aucun rapport : celle de la Play Console ouvre l'accès au *téléchargement*, celle de l'écran de consentement OAuth ouvre l'accès à la *connexion Google*. Un testeur Play absent de la seconde se voit refuser le login — et en statut « Test », les jetons de rafraîchissement expirent au bout de 7 jours, ce qui déconnecterait les familles en plein milieu des 14 jours.
  - Publier est sans risque ici : le seul scope demandé est `email`, qui est **non sensible**. Le passage « En production » est immédiat et **ne déclenche aucun audit de vérification** Google (celui-ci ne concerne que les scopes sensibles ou restreints). À basculer donc **avant** d'ouvrir la piste fermée.
- **Comptes enfants (Family Link)** : un enfant de moins de 13/15 ans avec un compte supervisé **peut** utiliser « Se connecter avec Google » — la demande part au parent, qui l'approuve depuis Family Link (ou active en amont *Paramètres → Contrôles → Applis tierces*). Prévoir dans le guide des familles testeuses : 1) le parent installe et approuve l'app côté enfant, 2) l'enfant se connecte, le parent reçoit la demande d'autorisation, 3) le parent approuve. Vérifier dans l'app que le refus de connexion affiche un message compréhensible plutôt qu'un échec silencieux.
- **Recrutement** : viser **18-20 familles** pour absorber les défections. Un **groupe Google** comme liste de testeurs évite de re-soumettre à chaque ajout.
- **La règle, exactement** — elle vise les comptes **personnels créés après le 13 novembre 2023** (les comptes antérieurs et les comptes organisation en sont exemptés) : au moins **12 testeurs opt-in de façon continue pendant les 14 jours précédant la demande** d'accès à la production.
  - Les 14 jours sont **consécutifs par testeur** : quelqu'un qui se désinscrit puis se réinscrit **remet son propre compteur à zéro**.
  - Le compteur ne doit **jamais** passer sous 12 pendant la fenêtre.
  - Les testeurs doivent **réellement utiliser** l'app : la demande d'accès pose des questions ouvertes sur les retours obtenus, et une réponse creuse la fait rejeter.
  - Pousser des mises à jour sur la piste **ne réinitialise pas** le chrono — c'est ce qui permet de corriger pendant les 14 jours.
  - ⚠️ Vérification définitive de l'applicabilité : le tableau de bord de la Play Console affiche ou non l'exigence une fois l'app créée. C'est la seule source qui fasse foi.
