<!-- revu: 20260823 -->
# donjons & savons
*transformez les corvées en une aventure épique familiale*

---

## table des matières

1. [vision](#1-vision)
2. [utilisateurs cibles](#2-utilisateurs-cibles)
3. [architecture](#3-architecture)
4. [flux principaux](#4-flux-principaux)
5. [mécanique sécurité des clans](#5-mécanique-sécurité-des-clans)
6. [mécanique ia](#6-mécanique-ia)
7. [mécanique combat et tâches](#7-mécanique-combat-et-tâches)
8. [mécanique progression (xp, niveaux, titres, butin)](#8-mécanique-progression-xp-niveaux-titres-butin)
9. [mécanique pv, mort et guérison](#9-mécanique-pv-mort-et-guérison)
10. [mécanique la fée](#10-mécanique-la-fée)
11. [mécanique journal de clan](#11-mécanique-journal-de-clan)
12. [mécanique monétisation](#12-mécanique-monétisation)
13. [notifications et relances d'engagement](#13-notifications-et-relances-dengagement)
14. [tutoriel et rappels de recrutement](#14-tutoriel-et-rappels-de-recrutement)
15. [banc d'essai](#15-banc-dessai)
16. [modèle de données](#16-modèle-de-données)
17. [assets cloud](#17-assets-cloud)
18. [déploiement](#18-déploiement)
19. [aspects légaux](#19-aspects-légaux)
20. [hors scope](#20-hors-scope)
21. [philosophie deva](#21-philosophie-deva)
22. [chantiers actifs](#22-chantiers-actifs)

---

## 1. vision

### problème

Les tâches ménagères sont une source permanente de friction dans les familles. Demander à un enfant de ranger sa chambre déclenche systématiquement rappels, négociations, tensions. Les parents gèrent des comportements, pas une maison.

### solution

Donjons & Savons transforme les corvées en monstres à abattre dans un RPG familial. Chaque tâche accomplie rapporte de l'expérience au joueur et à son clan. Quand le coffre du clan est plein, la famille ouvre un butin — une vraie récompense, décidée à l'avance par les parents. Le jeu ne simule pas la récompense : il structure le contrat familial.

La famille est le clan. Les corvées sont les monstres. Le butin est la promesse tenue.

### positionnement

Application mobile B2C familiale, Android en cible principale (le client compile aussi pour Windows, qui sert de banc de développement). Version courante `1.0.6+7`, en préparation de test fermé Play (France, Belgique), zone UE au lancement, les US ensuite.

**Monétisation tranchée et livrée** : abonnement par clan, cinq paliers indexés sur le seul nombre de joueurs (1,99 € à 7,99 €/mois), essai gratuit de 14 jours, offre fondateurs pour les premiers clans. L'app se lance payante — la beta gratuite préalable a été supprimée (`strategie.md`, décision du 2026-08-11) : une beta gratuite produit de la rétention, jamais de la conversion, et faire commencer à payer des familles déjà installées coûte plus de churn qu'un prix affiché dès le premier écran.

Développée en indépendant, éditeur personne physique (`build.yml` → `publisher`), sans publicité, sans traceur, sans achat surprise, et sans qu'aucune photo ne quitte l'appareil.

---

## 2. utilisateurs cibles

### adultes (chefs / admins)

Nécessairement majeurs — vérification au premier lancement par parental gate mathématique. Le rôle admin (liste `clans.admins`) est effectif. Un admin peut :

- créer un clan (bloqué pour les mineurs), inviter (QR, lien chiffré par PIN) et accepter les demandes d'adhésion ;
- **créer de toutes pièces un joueur sans compte** (`create_player`, section 4) et **prendre sa place** pour jouer à sa place (`take_place`, ci-dessous) ;
- juger les tâches en validation : trois verdicts (accepté / partiel / refusé), depuis l'app ou directement depuis les boutons de la notification, app fermée comprise — *à condition que le clan cotise*, cf. section 13 ;
- **promouvoir un membre chef** (`promote_chief` : ajout à `clans.admins` + miroir `is_admin` sur `clans_players`) ou le **rétrograder** (`nomore_chief`) — jamais le fondateur (`clans.founder`, admin à vie) ;
- **déclarer un mineur majeur** (`promote_adult`, réservé à un admin du clan **d'origine** du joueur) ;
- **recommander une tâche « boss »** (`adm_recommend`/`adm_unrecommend`, section 7), **libérer une tâche** tenue par quelqu'un (`adm_release`), **ressusciter** une tâche (`adm_revive`), en **créer** et en **éditer** ;
- **révoquer un membre** (tombstone `clans_players.enabled = false`) — jamais le fondateur ;
- **déclarer un joueur hors-ligne** (`declare_offline` : `has_device = false`) ;
- guérir un joueur mort (3 PV, cooldown 3 jours), donner un coup de pouce (+50 XP au moins avancé, cooldown 3 jours), **payer son tribut** (remettre pour de vrai l'argent gagné en jeu) ;
- **acheter** : abonnement, paliers, codes cadeaux — toujours derrière la porte parentale (section 12) ;
- consulter le journal narratif de n'importe quel membre, et le journal complet du clan ;
- se ressusciter lui-même s'il est le seul admin du clan.

La validation est croisée : dès que le clan compte deux admins, un admin ne peut plus valider sa propre tâche. L'auto-validation immédiate n'existe que pour l'admin solo.

### enfants (joueurs principaux)

Légalement mineurs ou majeurs — « enfant » désigne le rôle dans le clan, pas le statut légal. Un non-admin ne peut ni juger une tâche, ni guérir, ni booster, ni acheter quoi que ce soit : le menu contextuel du roster ne lui propose rien, et **aucun écran de paiement ne lui est jamais montré** — ni la page des paliers, ni le mur de première cotisation, ni le bouton « Se réabonner » de l'écran de clan gelé.

### joueur sans compte

Un chef peut **créer un joueur** (option `create_player` du kebab Clan) : un enfant trop jeune pour avoir un téléphone, ou privé du sien. Le document `clans_players` est écrit directement, autorisé par le `clanSecret` du parent, **sans doc `users` ni `userindexes`** — ce personnage n'a pas de compte Google, pas de jeton FCM, `legal_state = "k"` et un marqueur `no_account`. Il consomme une place au sens du plafond d'abonnement, comme n'importe quel membre. C'est un chef qui joue pour lui, via la prise de place.

### prise de place (impersonation)

Un admin peut **prendre la place** d'un membre du clan (`take_place`) : le worker assume l'identité de **jeu** de la cible sans se déconnecter. `_userId` bascule sur la cible — toutes les lectures et écritures des collections de clan (roster, XP, PV, avatar, tâches, tiroir, journal, vigilance) la visent, autorisées par le `clanSecret` partagé — tandis que `_authUserId` reste l'admin : le document personnel `users/` n'est jamais touché.

C'est de la **mémoire seule** : un kill de l'app repart en tant que joueur d'origine. Un bandeau overlay permanent (« Vous incarnez X — touchez pour revenir ») porte le retour (`restore_self`), et une leçon de tutoriel le pointe **à chaque prise de place**, jamais une seule fois. Pendant l'impersonation, l'option « supprimer mon compte » disparaît du kebab Personnage — elle supprimerait le compte de l'admin depuis la fiche d'un autre —, le device FCM n'est **pas** ré-enregistré (cela volerait le jeton, le nom et l'avatar de la cible), et les lignes de base de détection (xp, gold, last_task, is_admin) sont ré-amorcées dans les deux sens pour qu'aucune fausse célébration ne parte au moment de la bascule.

### rôle vs statut légal

`legal_state` vaut `k` (mineur), `t` (transition) ou `a` (adulte) ; il est calculé depuis la date de naissance à l'onboarding, la date elle-même n'étant jamais persistée. Ce statut conditionne la version des CGU affichée, la capacité à créer un clan (`k` et `t` ne peuvent pas), et la qualification aux clones de tâches `multiple` (section 7).

L'état `t` matérialise le **passage à l'âge adulte**. Un admin du clan **d'origine** du joueur (`clanId == original_clan`) le déclare majeur, ce qui pose `legal_state = "t"` sur son doc `clans_players`. Tant que le joueur n'a pas accepté les CGU adultes, `t` est **traité comme `k`** en jeu. Sa vigilance temps réel détecte le `t` et impose une **CGU adulte bloquante** : le routage la re-dérive à chaque login (elle survit à un kill de l'app), et l'acceptation écrit `a` dans `users` **et** `clans_players`.

---

## 3. architecture

```
client Flutter (Android, Windows)
  ├─ modules/worker — le seul code Dart applicatif : 23 fichiers `part of`,
  │    ~19 500 lignes (session, clan, members, tasks, forms, avatars, tiroir,
  │    combat, verdict, watch, celebrations, items, butin, chest, notify, log,
  │    store, fairy, admin, tuning, screens…)
  └─ 39 modules Deva
       dvcore · dvlang · dvsettings · dvorb · dvmarkdown · dvapp · dvtable
       dvcloud · dvcloudassets · dvlayers · dvtheme · dvprompts · dvmessaging
       dventries · dvtaskbar · dvdocuments · dvparentalgate · dvvideo
       dvdecisiontree · dvvertexai · dvsocialshare · dvvirtuallobby · dvlock
       dvqrcode · dvqrcodereader · dvcamera · dvdeeplink · dvvibrations
       dvsound · dvpops · dvsteps · dvsession · dvflame · dvinterlude
       dvtuto · dvstore

backend Pulumi (GCP — 2 régions : europe-west9, us-central1)
  ├─ Firebase Auth (anonyme puis Google OAuth PKCE, lien soft)
  ├─ Firestore : 7 bases PAR RÉGION, préfixées
  │    {eu,us}-workers · -sessions · -messaging · -documents
  │    {eu,us}-secrets · -virtuallobby · -store
  ├─ Cloud Storage (bucket assets par région : images, sons, vidéos, layers, prompts)
  ├─ Cloud Functions TypeScript (5 propres + 8 de modules)
  ├─ Cloud Scheduler (balayage des impayés 5 h, purge 6 h, relances 17 h UTC)
  ├─ Firebase Hosting (site vitrine + page de suppression de compte)
  ├─ Vertex AI (Gemini 2.5 Flash Lite, localisation par région)
  └─ verrous distribués (dvlock / pulock)
```

Le client est assemblé par DvBuilder depuis `client/build.yml`. L'UI est entièrement déclarative : écrans, widgets et interactions sont définis dans `client/config.yml` et ses **19 fragments** de `client/config/` (`registry_*.yml`, `steps.yml`, `dvtuto.yml`, `lang.yml`, `pops.yml`, `screens_meta.yml`) via le DSL dvorb. Les barèmes de jeu (XP, niveaux, PV, decay, butin, seuils de coffre) sont eux aussi déclaratifs : un bloc `worker:` dans `config.yml`, lu une fois au démarrage (`_loadTuning`).

Le worker n'est plus un fichier mais un **module découpé en parties** : une extension par domaine fonctionnel, toutes membres de la même classe `worker`, enregistrées par un `_register_xxx()` appelé depuis `register()`. Le découpage n'est pas cosmétique — chaque partie porte son propre bloc de commentaires de conception, et c'est là que vit le *pourquoi* de chaque mécanique.

**Ce qui est en conf, ce qui est au bucket, ce qui est chez Google.** Trois frontières que le projet tient strictement :

- **le `build.yml` de la suite** porte ce qui doit exister à un seul endroit parce que trois consommateurs le lisent : l'identité de l'éditeur (`publisher`), le dossier de sous-traitance RGPD (`dpa`), la fiche du store (`listing`) et surtout **le catalogue de la boutique** (`store`) — redistribué par le builder à la conf du client, au `config.yaml` du backend et au layer cloud `store-catalog-global.yml`. Un identifiant Play ne se corrige jamais : il ne pouvait pas rester écrit à trois endroits ;
- **les layers du bucket** portent ce qui doit pouvoir changer **sans release** : catalogue de tâches, catalogue d'items, thèmes, cadence et cadeaux de la fée, scénarios du banc d'essai, seuil de relance de conversion. Une copie est embarquée dans l'APK (`onboard`) pour que le premier lancement ne montre jamais un écran vide ;
- **la Play Console** ne porte que ce que Google exige, et `pucatalog` l'y écrit depuis la même source.

Le flux inter-composants suit le même patron partout : un événement UI déclenche une action nommée (`worker.on_xxx`), le worker lit l'état via dvcloud, met à jour Firestore, puis navigue. La navigation d'onboarding passe par `dvsteps` ; les sauts directs utilisent `DvOrb.navigate_reset`. Le temps réel reste ciblé : trois vigilances `dvcloud.watch` seulement — la tâche en attente de verdict, le doc du joueur courant, et le doc de la fée quand une fenêtre est ouverte (plus une vigilance par joueur attendu pendant la cérémonie du butin). Push Firestore natif sur Android, polling Fibonacci plafonné sur desktop.

---

## 4. flux principaux

### premier démarrage — onboarding anonyme

Le joueur traverse **tout** l'onboarding en session Firebase **anonyme**, sans qu'une seule ligne ne soit écrite en base. Firebase Auth ne détient donc ni email, ni nom, ni photo avant que les conditions soient acceptées et l'état légal connu. Le compte Google est lié en fin de parcours ; `linkWithCredential` conserve le même uid, il n'y a rien à migrer.

1. L'écran `home` propose **deux portes** : « Je pars à l'aventure » (nouveau joueur) et « Retrouver mon héros » (compte existant). Aucune session anonyme n'est ouverte automatiquement — un `auto_start` créerait un compte anonyme à chaque lancement.
2. **Je pars à l'aventure** ouvre la session anonyme et entre dans l'onboarding : royaume (région), date de naissance (jamais persistée, seul `legal_state` en est tiré), parental gate si adulte, vidéo d'introduction (FR/EN/ES, téléchargée depuis GCS, passable), puis les **CGU** correspondant à `(region, legal_state, lang)`.
3. À l'acceptation, le routage diverge selon trois cas (`worker.legalstate`) :
   - **adulte encore anonyme** → écran de **liaison de compte** (`link_account_screen`), bloquant, sans « plus tard » ;
   - **mineur** → directement l'écran de demande d'entrée dans un clan (`kid_wants_clan`). Il liera son compte **après** l'admission : avant, il n'a rien à protéger et l'écran de liaison le bloquerait pour rien ;
   - **adulte déjà authentifié** (compte supprimé qui refait son onboarding) → rien à lier, on enchaîne sur le nom.
4. **Le flush.** La liaison réussie déclenche la première écriture réelle, d'un seul tenant et dans cet ordre : `userindexes` **en premier** (le document que toutes les règles Firestore déréférencent, et celui qui rend le compte retrouvable), puis `users` avec les quatre steps en une seule écriture fusionnée, puis la **preuve de consentement** rejouée par dvdocuments avec l'horodatage réel, puis l'enregistrement du device FCM (non critique). Si une étape échoue, le flush rend `false` et le parcours ne continue pas : atteindre l'écran de clan sans `userindexes` ferait échouer la création de clan au niveau des règles, panne bien plus tardive et bien plus obscure qu'un message ré-essayable.
5. **Le nom d'aventurier** est demandé après la liaison, pour tout le monde — quand le joueur a une identité durable.
6. L'utilisateur crée un clan ou demande à en rejoindre un.
7. Après la sélection de clan, `dvdecisiontree` pose une série de questions sur le foyer (équipements, pièces, véhicules, animaux) dont les réponses filtrent la bibliothèque de tâches (section 7). Les questions vivent dans GCS et se modifient sans recompilation ; le contenu actuel reste un brouillon à retravailler avant production.
8. Arrivée sur le `dashboard`, gelé le temps de garantir que le doc clan et les tâches sont chargés (`_ensureClanReady`, borné à 5 tentatives), puis animation de bienvenue (nom du clan en surbrillance + scène dvflame « burn »), puis le **tutoriel** (section 14).

**Cas limites de l'onboarding anonyme, tous assumés :**

- une session anonyme interrompue **ne laisse rien** — ni entrée Auth exploitable (autodelete natif à 30 jours), ni document Firestore. Il n'y a donc **aucune reprise avant le flush** : on recommence l'onboarding depuis le début. Le tampon d'acceptation ne survit pas à un kill, par choix — une preuve de consentement à demi-écrite n'en est pas une ;
- **« Retrouver mon héros »** vérifie le compte **avant toute écriture** : `verify_account` cherche `userindexes/{firebaseUid}` dans chaque région. `ok` → on adopte le compte ; `not_found` → l'entrée Firebase Auth qui vient d'être créée est **supprimée** (se tromper de bouton ne doit laisser aucune trace) et un overlay l'explique ; `error` (une région injoignable) → **rien n'est supprimé**, on peut réessayer. Un compte historique interrompu avant la création de son index sera refusé et repartira par la première porte ;
- **conflit de compte** (le compte Google visé porte déjà un héros) : pour un **adulte**, rien n'a encore été écrit sous l'uid anonyme, on propose donc d'adopter le compte existant — le tampon local est jeté d'abord, sans quoi le flusher sur le compte adopté écraserait ses steps et empilerait une seconde acceptation de CGU. Pour un **mineur** déjà admis dans un clan, on **bloque** : des documents existent sous son uid anonyme, et surtout, s'il était seul chef d'un clan, une suppression cascaderait sur des données de tiers ;
- **échec de connexion** : un seul tri, sur la porte empruntée et non sur la cause. « Je pars à l'aventure » n'implique aucun compte Google — lui parler d'autorisation parentale serait absurde. Au-delà, sur un compte supervisé Family Link, le refus du parent et l'enfant qui referme la feuille remontent le même `canceled` : un texte unique couvre les deux, plutôt qu'un message faux une fois sur deux ;
- **compte supprimé qui revient** : `enabled = false` est traité comme inexistant (onboarding complet), et les champs de routage du doc `users` sont remis à plat avant de recommencer — sinon l'ancien `steps.clan` le renverrait vers un clan mort dès la première écriture.

### connexions suivantes

`_findBestSession` retrouve le document utilisateur le plus récent parmi toutes les régions configurées. Si les CGU ont évolué, `dvdocuments` les repose **à tout le monde** — et le routeur ramène alors un joueur déjà enrôlé à son dashboard plutôt que dans le tunnel d'onboarding. Sinon, si un `steps.clan.clanId` non vide existe, l'app charge les tâches du clan, ré-enregistre le device, arme la vigilance du joueur, vérifie une cérémonie de butin en attente, restaure une tâche en cours et sa vigilance de verdict, consomme un éventuel lien d'invitation reçu à froid, puis navigue vers le dashboard.

`_findPartialSession` couvre le cas d'un compte **authentifié** qui a confirmé sa région sans compléter l'écran d'âge : il reprend à `age_screen`.

### création d'un clan

Réservée aux adultes. Le bouton est grisé pour `k` et `t`.

1. Saisie d'un nom (obligatoire) et d'une description. « Inspire moi » envoie les deux à Vertex AI (section 6) ; « Rejouer » restaure les saisies originales avant de relancer.
2. À la confirmation, deux UUID sont générés (`clanId`, `clanSecret`) et la Cloud Function `count_sessions` fournit un index.
3. Le **nom externe** est construit `"{aiName}-{region}-{sessionCount}"`. C'est le seul nom visible hors du clan **sans action du joueur**. Cette règle protège la confidentialité inter-clans ; elle ne s'applique pas à un **partage volontaire** : le conte du butin (section 11) affiche et transmet le nom interne, celui que la famille a choisi.
4. Deux documents sont écrits — `users/{uid}` (ajout du clan et de son secret) et `clans/{clanId}` (avec `ownerId = clanSecret`, section 5) — et un log `ClanCreated` est tracé.
5. Navigation vers le decisiontree ; les réponses sont persistées dans `clans_tasks`, les tâches `multiple` activées mémorisées dans `clans.enabled_multiple`, et le créateur écrit ses propres clones.

### rejoindre un clan — QR code

1. **Côté admin** : « Inviter un membre » ne crée **pas** le lobby tout de suite. Recruter, c'est potentiellement faire entrer un enfant dans son clan : l'overlay de consentement est révélé d'abord (mise en page `commons/parental_consent` + lien vers les CGU adulte) — le RGPD art. 8 veut un consentement éclairé **au moment de l'acte**, pas seulement à l'installation. La confirmation enchaîne sur `virtuallobby.create_management`, l'annulation ne referme rien d'écrit. Le libellé énonce les **trois cas** possibles (un adulte ; un enfant dont le chef est responsable légal ; un enfant déjà membre d'un autre clan, invité avec l'accord de son responsable) : à l'instant de l'invitation, on ignore qui viendra.
2. Le QR encode `ddust://invite?group_id=…&lobby_id=…`. L'admin peut aussi partager le lien (`dvsocialshare`).
3. **Côté candidat** : scan (`dvqrcodereader`) ou deep link. Si l'app était fermée, `on_login` détecte l'invitation en attente après l'auth et navigue vers l'écran d'acceptation.
4. `dvvirtuallobby` finalise : consommation du secret (usage unique), écriture de `clans` + `userindexes`, ajout dans `clans.players`, écriture du doc membre et de ses clones `multiple`, log `MemberJoined`, notification « nouveau membre » à tout le clan dans la langue de chacun.
5. **Cas limite du candidat MINEUR** : tout ceci précède la liaison de son compte Google. Son doc membre naît donc **sans `name`** — le roster des autres affiche le libellé neutre `member_unnamed` et non son identifiant technique (le journal, append-only, garde l'id brut). Et le handler **persiste les layers** avant d'envoyer sur l'écran de liaison, sans quoi les drapeaux de session seraient perdus par le rechargement du layer par-owner et le mineur repartirait sur le choix de clan après avoir saisi son nom, sans cérémonie de bienvenue.

### rejoindre un clan — lien chiffré par PIN

Même workflow que le QR : on ne remplace que le **véhicule** du couple `{group_id, lobby_id}`. Au lieu d'une image lue par proximité, un lien partagé sur les réseaux sociaux dont ce couple est chiffré par un **PIN à 6 chiffres** dicté de vive voix. Le PIN remplace la présence physique.

La crypto est générique et vit dans `dvvirtuallobby` (`generatePin`/`sealInvite`/`openInvite` — fonctions pures, token auto-porteur, chiffrement par flux authentifié HMAC-SHA256, expiration embarquée). Côté candidat, deux entrées : le deep link `ddust://invitepin?token=…`, ou le bouton « Je n'ai pas le QR code » qui ouvre la saisie manuelle. Modèle de menace assumé pour une app d'enfants : un lien intercepté sans le PIN est inexploitable, et le secret étant supprimé à la première lecture, le vrai candidat le consomme avant tout curieux.

> L'ancien « flux demande » (le candidat émet `ddust://request`) est remplacé par ce flux PIN. Le handler d'émission a été supprimé ; la route entrante et l'écran d'acceptation subsistent, encore câblés en conf.

### créer un joueur sans compte

Option `create_player` du kebab Clan (chefs seulement). Comme l'opération n'est pas anodine — personnage fictif, puis relais par la prise de place — une **leçon de tutoriel manuelle** est jouée d'abord, sur l'écran Clan, et l'écran de saisie ne s'ouvre qu'à la fin de la leçon. La confirmation contrôle le statut d'admin, puis **le plafond de joueurs du palier souscrit** (un enfant créé consomme une place comme un autre : le refus ouvre la page des paliers en fléchant celui qui en libère une, section 12), puis écrit le doc membre et un log `MemberCreated`.

### boucle de combat

La taskbar comporte cinq onglets : boutique, clan, **combat**, personnage, inventaire. L'inventaire est ouvert à tous — chacun y voit ses objets et sa bourse, le coffre du clan restant filtré aux admins ; la boutique ne porte que les produits à l'unité, et son étal est vide au lancement. Le choix du **palier d'abonnement** n'y vit pas : il a son propre écran (section 12).

1. L'onglet **combat** affiche un tiroir (`DvTiroir`) listant les domaines de la maison activés par le decisiontree. À chaque affichage, les statuts des tâches sont rafraîchis — les overlays sont relus à l'entrée d'écran, pas synchronisés en continu. Le rafraîchissement est un **delta** : seuls les documents dont `touched` a bougé depuis le curseur sont relus (au lieu des ~160 documents à chaque entrée), avec un garde anti-rafale de ~10 s sur la lecture cloud et un retour au listing complet toutes les 24 h — les suppressions de documents étant invisibles d'un delta.
2. **Sélection d'un domaine** : chaque domaine ouvre son sous-tiroir listant ses feuilles. Les 19 domaines câblés sont servis par deux handlers génériques par préfixe (`seldomain.{domaine}`, `seltask.{taskId}`) : aucun code spécifique par domaine. Un joueur mort ne peut ni ouvrir un sous-tiroir ni prendre une tâche.
3. **Prise de tâche** : le worker lit d'abord le statut autoritaire du document. En `validating`, on bifurque vers le mode revue (admin) sans verrou. Sinon il acquiert un verrou `dvlock` sur `"{clanId}_{taskId}"` (TTL 30 s) qui ne protège que la course simultanée ; le statut Firestore garantit l'unicité au-delà. Exception : une mortelle `dead` dont la fenêtre est passée « ressuscite » et redevient prenable.
4. **Affichage combat** : illustration du monstre, critères d'acceptance, badge de difficulté (libellé d'effort + XP réels du moment, fourchette si la tâche est un boss), et deux boutons — « J'ai vaincu le monstre ! » et « Retraite ! ». Un mur de flammes et une boucle sonore tiennent le siège tant qu'on y est ; ils sont coupés dès qu'on quitte l'onglet, y compris par la taskbar.
5. **Preuve** : la capture passe par `dvcamera` (caméra OS, stockage **local** sous un uuid — jamais de cloud). Trois issues : photo prise → `validating` ; capture annulée → rien ne change ; caméra indisponible → la tâche part quand même en validation, avec une sentinelle locale `noproof` (le bouton « Voir ma preuve » reste masqué). Un log `TaskDone` est tracé et **tous les admins** (sauf le demandeur) sont notifiés.
6. **Abandon** : « Retraite ! » repasse la tâche en `alive`, vide l'assignation et la preuve, et **préserve la fenêtre de régénération**.

**Attente de verdict** : une vigilance `dvcloud.watch` surveille le document, précédée d'une lecture immédiate qui couvre le verdict déjà rendu (cold start). Dès que le statut quitte `validating` : refus → la tâche me reste attribuée, je peux recommencer ; accepté, repris par un autre ou disparu → l'état local est vidé et l'app revient au dashboard. La notification de verdict déclenche la même résolution sans attendre le watch, et le retour sur l'écran combat réconcilie manuellement — aucune dépendance exclusive au temps réel.

### validation parentale

Une tâche `validating` apparaît dans le tiroir avec un overlay **main** pour un admin — cliquable, contrairement aux autres joueurs qui la voient verrouillée par la flamme. **Validation croisée** : si l'assignee est l'admin lui-même, le tap est un no-op. Sinon l'admin entre en mode revue — illustration, critères, difficulté, **jamais la preuve photo** (elle reste sur l'appareil du joueur) — avec trois verdicts :

- **accept** — XP plein au joueur et au clan, puis transition : `dead = now`, `revive = now + respawn_h`, statut `dead` (mortelle) ou `alive` (immortelle) ;
- **partiel** — **moitié de l'XP** (répercutée sur le clan et le butin) et tâche à moitié régénérée : `dead = now − respawn_h/2`, `revive = now + respawn_h/2`, statut `alive` — même une mortelle reste sélectionnable, barre de respawn à ~50 % ;
- **reject** — retour en `assigned` au même joueur, preuve purgée, aucun XP, fenêtre préexistante préservée.

L'XP est calculée **avant** l'écriture du verdict (la proportionnalité utilise la fenêtre du cycle précédent, que la validation réécrit). Chaque verdict trace un log et notifie l'assignee dans sa langue. Chaque verdict accepté incrémente aussi `clans.validations`, le compteur qui déclenche la demande de première cotisation (section 12) — un compteur commercial qui ne doit jamais faire échouer une validation : en cas d'erreur, la famille est créditée et fêtée quand même, et la relance part une tâche plus tard.

**Verdict depuis la notification** (clans abonnés) : trois boutons mappés sur des actions en mode `noorb` — app fermée, le tap relance l'app **sans UI** (seuls les idles `orb` et `lang` sont chargés), attend la résolution du contexte clan (borné ~10 s), exécute le verdict et s'arrête. **Garde d'idempotence** : le verdict n'est appliqué que si la tâche est encore `validating`, deux admins peuvent taper sans double crédit.

**Auto-validation (admin solo uniquement)** : quand l'admin **unique** exécute lui-même une tâche, « J'ai vaincu » saute la preuve et applique immédiatement le verdict accepté. Dès qu'un deuxième admin existe, ce raccourci disparaît.

---

## 5. mécanique sécurité des clans

La collection `clans` interdit toute énumération (`allow list: if false`). Pour lire ou modifier un document clan, la règle Firestore vérifie :

```
get(userindexes/{auth.uid}).data.clans[clanId].clanSecret == resource.data.ownerId
```

La règle lit depuis `userindexes` (pas `users`) — un document léger `{clans: {[clanId]: {clanSecret}}}` dédié aux contrôles d'accès. `userindexes` porte sa propre règle explicite plutôt qu'une isolation générique : chacun ne lit et n'écrit **que son propre index** (`docId == uid`). Avec l'isolation standard, n'importe quel utilisateur authentifié aurait pu lire les `clanSecret` d'autrui à partir d'un UID — or tout le modèle repose sur le secret de ce champ.

Le champ `ownerId` du document clan ne contient pas l'UID Firebase du créateur : il contient le `clanSecret`, un UUID aléatoire. La règle croise les deux documents sans jamais exposer d'identité réelle dans le document clan.

Le même schéma protège `clans_tasks`, `clans_players`, `clans_items`, `clans_logs` et `clans_chest_history`. Trois collections sont **append-only par construction** (`create` seul, ni `update` ni `delete` depuis un client) : `clans_logs`, `clans_chest_history` et `clans_store/{clanId}/events` — cette dernière allant plus loin encore, le `create` lui-même y est fermé au client, seul le SDK Admin y écrit.

Deux collections sont en **lecture seule pour tout le monde** : `clans_store` (les droits achetés) et `clans_pulse` (l'état de relance). Elles ne pouvaient pas vivre dans `clans/{clanId}`, modifiable par tout détenteur du `clanSecret` : un champ `tier` y serait falsifiable depuis un client modifié, et un client capable de réécrire son état de relance pourrait s'en exempter — ou se le réarmer en boucle.

**Limite assumée** : le filtre de visibilité des items (`clans_items`) est **client**. Depuis l'ouverture de l'écran à tous les joueurs, le contenu du coffre n'est caché que par l'app — un client modifié le lirait. Le durcir demande une règle Firestore sur `owner`, qui devra s'appuyer sur l'identité du lecteur puisque le `clanSecret` est partagé.

---

## 6. mécanique ia

Deux usages seulement, tous deux ponctuels, jamais en streaming, jamais en arrière-plan. Le modèle est Gemini 2.5 Flash Lite via Vertex AI, avec une **localisation par région** (`aimodel.location`) : une liste par région, car le texte envoyé est saisi par l'utilisateur et doit être traité chez lui. L'Europe est volontairement découplée de `europe-west9` (petite région à faible capacité Gemini, d'où des 429 « Resource exhausted » dès deux joueurs simultanés) au profit de la multi-région `eu`, avec `europe-west4` en repli.

### « inspire moi »

À la création de clan et à la saisie du nom de joueur. Le prompt (`prompts_General_V1.yml`) est stocké dans GCS et téléchargé au lancement (asset critique, bloquant pour Vertex AI) ; `dvprompts` l'expose, avec injection de l'entrée et de la langue.

**Entrée** : `"nom: {saisie}, description: {saisie}"`. Seules des chaînes librement saisies transitent. **Timeout et repli** : l'appel est borné à 3 secondes, après quoi un jeu statique traduit est tiré — l'utilisateur n'attend jamais l'IA. Si la réponse arrive après coup, elle est mise en cache et servie au prochain « Rejouer ». **Rejouer sans dériver** : la saisie originale est capturée au premier appui et restaurée avant chaque relance.

### le conte du butin

Après une ouverture de coffre, **tout joueur ayant participé** (pas seulement les chefs) peut demander à l'IA de raconter l'aventure du clan. L'écran de journal bascule alors en **mode conte** : au lieu de la liste d'événements, il affiche le récit qu'un modèle en a tiré, suivi d'une phrase fixe. Le mode est **consommé** à l'affichage — revenir au journal par le kebab ne rejoue pas d'inférence, et le mode ne survit pas à la sortie de l'écran.

La matière est le **journal du clan en texte brut**, borné, plus de quoi citer un seul chiffre (l'XP totale). Trois contraintes portées par le prompt lui-même : le conte **ne parle jamais d'argent** (la phrase qui en parle est fixe, hors IA), il ne raconte pas la fondation du clan (les premières lignes du journal l'ouvraient systématiquement dessus), et il travaille sur les **prénoms choisis par les joueurs** — jamais un identifiant, un âge, une région ou un email. Journal vide → rien à raconter, on retombe sur le message habituel sans déranger l'IA.

---

## 7. mécanique combat et tâches

### bibliothèque de tâches

Les tâches vivent dans `resources_cloud/general/layers/tasks-base-global.yml`, chargé en base de la conf. Le fichier déclare **20 domaines** (19 câblés à un tiroir) et **151 tâches** :

```yaml
salon_01:
  title:      "@@@T:dt_t_salon_01@@@"   # nom du monstre (clé de traduction)
  acceptance: "@@@T:dt_a_salon_01@@@"   # critère de réussite (ce que le parent vérifie)
  dead:       "@@@T:dt_d_salon_01@@@"   # texte de victoire
  cancel:     "@@@T:dt_c_salon_01@@@"   # texte de retraite
  domain:     salon
  effort:     3                          # difficulté
  type:       immortelle                 # immortelle = régénère ; mortelle = respawn sec
  respawn_h:  72                         # délai de réapparition/régénération, en heures
  supervision: false
  multiple:   k                          # optionnel : clone par joueur (k|a|all)
  skip_if_blacklisted: []
  keep_if_whitelisted: []
  enabled:    true
```

Le contenu textuel est porté par un **layer de contenu séparé** chargé sous le thème, ce qui rend structure et traductions versionnables indépendamment.

### filtrage par le foyer

Chaque réponse du decisiontree produit des tags (`tag_possede_jardin`, `tag_sans_machine_laver`…) ; une tâche est retenue ou écartée selon `skip_if_blacklisted` / `keep_if_whitelisted`. Le résultat est persisté dans `clans_tasks`.

### cycle de vie d'une tâche

Quatre états : **`alive`** (disponible), **`assigned`** (prise, imprenable — aussi l'état de retour après un rejet), **`validating`** (preuve soumise), **`dead`** (mortelle vaincue, indisponible jusqu'à `revive`).

| overlay | condition | comportement |
|---|---|---|
| flamme | `assigned`, ou `validating` pour un non-admin | grisée, verrouillée |
| main | `validating` vu par un admin | cliquable → mode revue |
| crâne + barre | mortelle `dead`, tant que `now < revive` | verrouillée, barre de respawn |
| pansement + barre | immortelle `alive` en régénération | prenable, XP réduite |
| badge XP | tâche recommandée (boss) | prenable, XP boostée |
| flamme « busy » | icône d'un domaine dont une feuille est active | domaine reste cliquable |

### tâches multiple

Certaines corvées sont **personnelles** : faire son lit, ranger *sa* chambre. En faire une tâche partagée aurait un effet pervers — la corvée de chacun deviendrait une course au premier arrivé. Une tâche `multiple` est **clonée en une instance par joueur qualifié**, chacune avec son état et son XP.

Le comportement est piloté par la conf (`tasks.<id>.multiple` ou `domains.<d>.multiple`), la valeur `k`/`a`/`all` étant comparée au `legal_state`. Les clones sont créés à l'enrôlement, chaque membre écrivant les siens. L'identifiant est `"{baseId}__{userId}"` ; les baseId ne contiennent jamais de double underscore, ce qui rend la remontée à l'original synchrone. Le réglage (`effort`, `type`, `respawn_h`) est résolu depuis l'original.

### édition, création, résurrection

Un admin retouche une tâche via « Modifier la tâche » : nom, description, **effort** (picklist 1-8), **respawn_h** (paliers de 1 h à 1 mois) et **type**. L'écriture est **partielle** — seuls les champs réellement modifiés partent ; si rien n'a changé, l'action ne fait rien.

La **création** passe par la tuile « + » du mode admin : nouveau document `{domaine}_{micros}` marqué `user_created` (donc exempté du réconciliateur de schéma), image `nounours` par défaut ensuite éditable, tuile injectée dans le tiroir. Le réconciliateur ne supprime jamais qu'un identifiant de la **forme du catalogue** (`<domaine>_NN`) : un document de forme inconnue appartient à quelqu'un d'autre — ou à un binaire plus récent — et ne doit pas être détruit par un client qui ne sait pas le lire.

**« Ressusciter »** (`adm_revive`) remet une tâche à neuf immédiatement — fenêtre `dead`/`revive` **effacée**, ni crâne ni barre. À ne pas confondre avec **« Laisser tomber »** (`adm_release`), qui libère une tâche tenue par un joueur disparu : même écriture qu'une retraite, mais la fenêtre de régénération est **préservée**. Le porteur se réaligne seul, sans notification, et aucune célébration ne part — elles sont toutes conditionnées à une hausse d'XP.

### recommandation de tâche (boss)

Un admin érige une tâche en « boss » : `recommended = now` et notification à tout le clan dans la langue de chacun. Le tiroir affiche un **badge XP**. Le prochain joueur qui la valide reçoit une **XP boostée**, le multiplicateur décroissant avec les heures écoulées (`max((3..7) / (1 + h), 1)`). Le bonus profite aussi au clan, dont la part se calcule sur l'XP boostée.

Les bornes étant connues à l'avance, l'écran de combat annonce la **fourchette réellement en jeu** (« effort — 24-56 XP ») et le verdict tire dans cette même fourchette : ce qui est promis est exactement ce qui peut tomber. Plus le joueur tarde, plus la fourchette se resserre.

**Le verdict consomme la recommandation** : l'effacement se fait dans la même écriture que l'acceptation, sur l'appareil de l'admin qui tranche — le seul moment où l'on est sûr que ça arrive. Le drapeau posé côté joueur ne sert plus qu'à **choisir l'animation** (« coup de pouce » plutôt que « victoire »). Un refus ne consomme rien : la tâche reste boostée pour la prochaine tentative. Le retrait manuel (« Ne plus recommander ») efface le champ sans notifier — on ne dérange pas le clan pour un retrait.

Le journal enregistre l'XP **réellement créditée**, bonus compris, plus l'XP de base et un drapeau d'audit, et la ligne narrative **dit le bonus** (« … 100 XP, dont +80 de boss ! ») : un total nu ne permettait pas de savoir si la recommandation avait payé.

Deux autres sources posent un boss sans qu'un chef intervienne : le **cadeau de la fée** (section 10) et le **balayage serveur** quand un clan est silencieux depuis une semaine (section 13).

### contrôles admin du tiroir

Le chef de clan est **aussi un joueur** : on ne taxe donc pas sa boucle de jeu d'un menu à chaque tap. Un switch « Jeu | Admin » en bas du tiroir bascule entre les deux :

- **mode jeu** — le tap lance la tâche directement (les selectors ne renvoient que l'option seule) ;
- **mode admin** — le tap ouvre le menu, les tâches cachées réapparaissent (grisées, croix rouge), une tuile « + » ferme la marche, la bordure vire au rouge.

Le tiroir **change de vocabulaire** selon le mode : en mode admin on ne pousse plus les statuts de jeu mais des statuts d'administration, d'où la disparition automatique des flammes, crânes, mains et barres — sans une ligne de code de rendu. Quatre options (`adm_enable`, `adm_disable`, `adm_hide`, `adm_show`) portent deux booléens `visible`/`enabled` persistés sur **trois surfaces** (conf runtime, layer runtime par-owner, Firestore) ; les clones héritent de la base. Les bornes de grille sont réglées à `min_columns: 3 / max_columns: 6 / min_rows: 3` sur les 20 tiroirs.

Un admin **ne crée jamais de domaine** : la liste des domaines est du contenu de jeu, et les domaines additionnels seront vendus en packs. La grille des domaines refuse donc la tuile « + » en conf (`extras_enabled: false`), avec un garde-fou redoublé côté code.

---

## 8. mécanique progression (xp, niveaux, titres, butin)

La validation d'une tâche est le principal générateur d'XP, avec le coup de pouce admin (section 9) et les cadeaux de la fée (section 10).

### xp d'une tâche

Le gain de base est `(xp_per_effort + respawn_h / xp_respawn_div) × effort`, soit **`(10 + respawn_h / 12) × effort`** par défaut. La part variable donne du poids aux corvées rares et lourdes : à effort égal, nettoyer le four (720 h) vaut 350 XP quand mettre la table (6 h) en vaut 10.

Sur ce socle s'applique la **fenêtre de régénération** `dead → revive` : 0 XP avant `dead`, XP pleine après `revive`, proportionnelle entre les deux. Une **immortelle** rapporte d'autant plus qu'on la laisse repousser ; une **mortelle** est indisponible jusqu'à `revive` puis rapporte plein. Le verdict « partiel » divise par deux, joueur, clan et butin compris.

**Conséquence d'équilibrage.** Jouée en boucle, une tâche plafonne à `112 × base / respawn_h` XP par semaine (112 h = 16 h éveillées × 7 jours) — plafond indépendant de la cadence de jeu et identique pour une mortelle et une immortelle. Développé, `1120 × effort / respawn_h + 9,3 × effort` : passé 120 h de recharge, le second terme domine et le rendement ne dépend plus que de l'effort. C'est pourquoi `respawn_h` doit se lire comme **le poids donné à la tâche**, pas comme la fréquence réelle du besoin du foyer.

### niveaux joueur et clan

Le niveau n'est **jamais stocké** : il se dérive de l'XP cumulée. L'XP requise pour atteindre le niveau N suit `XP_N = 50 · (N(N+1)/2 − 1)` : 100 au niveau 2, 250 au 3, 450 au 4, 700 au 5. Le coût d'un palier croît linéairement — compromis entre le linéaire (les niveaux ne signifient plus rien) et l'exponentiel (mur infranchissable).

Même courbe pour le clan avec un pas ×10 : niveau 2 à 1000 XP, niveau 3 à 2500. Le crédit d'XP au clan est **divisé par le nombre de membres** (`ceil(xp / count)`) : le palier de clan récompense l'effort collectif, pas la taille du foyer. L'XP partagée est celle **réellement gagnée par le joueur, bonus boss compris**. Le diviseur ne compte que les membres **actifs** : révoqués (`enabled = false`) et sans-téléphone (`has_device = false`) en sont exclus.

**Plafond d'XP par tâche, indexé sur le niveau.** L'XP gagnée sur UNE tâche est écrêtée à `clans_players.max_xp` (amorcé à 100, le champ du doc faisant foi ensuite et pouvant varier d'un joueur à l'autre) **+ 20 × niveau du joueur** (niveau avant le gain) : 120 au niveau 1, 300 au niveau 10. Sans ce bonus, un plafond fixe traite pareil le débutant et le vétéran — trop bas il écrase le bonus boss d'une grosse corvée au niveau 10, trop haut il laisse un niveau 1 rafler d'un coup ce que le barème destine à plusieurs semaines. Indexer le plafond sur le niveau fait du niveau lui-même une récompense. Le badge de combat applique la même formule pour ne jamais promettre plus que ce que le verdict versera. Un réalignement à usage unique (`player_max_xp_legacy`) réécrit l'ancienne valeur d'amorçage sur les personnages existants, sans jamais écraser un plafond personnalisé.

### titres

Un titre n'est pas une propriété dérivée du niveau : c'est un **item**. Au niveau 5, puis tous les 5 niveaux (borné à 20 rangs), le joueur gagne l'objet `titre_perso` de ce rang dans son inventaire ; le clan gagne de même un `titre_clan` quand son propre niveau franchit un palier. **Porter** un titre est un choix : l'option écrit `title_idx` sur le doc joueur (ou clan), et c'est ce champ, jamais le niveau, que les écrans affichent sous le nom. « À la poubelle » **supprime** l'item — il n'y a **aucun rattrapage rétroactif**, précisément parce qu'aucun rattrapage ne pourrait le ressusciter. Les titres de clan sont visibles de tous les membres (`shared: true`) mais seuls les chefs peuvent les porter ou les jeter. Un titre ne s'échange pas et ne va jamais au coffre.

### montée de niveau : détection, célébration, récompenses

L'XP d'un joueur est créditée **à distance** (sur l'appareil de l'admin qui valide). Une vigilance sur le doc membre détecte donc la montée **à tout moment, sur n'importe quel écran**. La comparaison se fait contre une XP mémorisée : amorçage silencieux à la première exécution (pas de fausse célébration au déploiement), mémorisation avant célébration (anti double-fire), lectures transitoires ignorées.

Au franchissement d'un palier : **(0)** l'item titre est écrit **avant** l'animation et la notification — si l'un des deux échoue, le titre gagné doit exister tout de même ; **(1)** animation sur place (texte dans le DvSplash commun + scène dvflame « burn » : combustion, carbonisation, effritement), sans aucune navigation ; **(2)** notification au reste du clan dans la langue de chacun ; **(3)** récompenses : soin complet et don au butin de 100 × nouveau niveau, plafonné ; **(4)** log `PlayerLeveledUp`.

Côté clan, le franchissement est détecté au crédit d'XP — seul endroit qui voit l'XP du clan avant et après — et donne l'item `titre_clan` avec un log, mais sans animation : ce code tourne sur l'appareil de l'admin qui valide, pas sur celui d'un joueur.

### célébrations : les six interludes

Six scènes `dvinterlude` ponctuent le jeu, toutes déclenchées par **détection** (comparaison à une valeur mémorisée), jamais par navigation. Chacune confisque l'écran, démarre son et vibration une demi-seconde avant le visuel, puis rend la main :

| interlude | déclencheur | rendu |
|---|---|---|
| **burn** | montée de niveau, promotion chef, bienvenue clan | l'écran se consume (flammes → braises → cendres) |
| **victory** | XP d'une tâche validée (verdict accepté normal) | image de victoire en fondu + `tatadaa.mp3` |
| **giftxp** | XP créditée sans tâche (cadeau de guilde, coup de pouce boss, cadeau de fée) | pluie d'XP dorée |
| **giftgold** | hausse du champ `gold` du joueur | pluie de pièces dorées |
| **heal** | transition mort → vivant | croix vertes + voile blanc |
| **gameover** | passage à 0 PV | rideau noir + splash « GAME OVER » |

`giftgold` est câblé mais **dormant** : aucune mécanique ne crédite `gold` aujourd'hui, l'or arrivant avec le pack économie. La détection se déclenchera dès qu'une source existera.

### jauge de butin

Le butin se remplit via une jauge dédiée, distincte du niveau de clan. À chaque crédit d'XP au clan, le même montant (modulé par `clans.butin_xp_factor`) est ajouté à `clans.butin_xp`. **Deux plafonds distincts** : celui du **cycle** (1000 — au-delà, plus aucun gain jusqu'à l'ouverture) et, en amont, celui d'**un seul crédit** (`clans.max_xp_butin`, amorcé à 50, **+ 20 × niveau du clan**) : miroir exact du plafond joueur, il évite qu'une seule corvée recommandée, divisée par peu de membres, ne remplisse la jauge d'un coup dans un jeune clan. Les dons fixes des montées de niveau (10 × niveau) sont soumis au même plafond de crédit.

Deux compteurs cohabitent sur le doc clan : `xp` (non borné) pilote le niveau et les titres ; `butin_xp` (0 → 1000) est la jauge d'ouverture. L'écran clan affiche la jauge avec un coffre qui avance sur la barre, et le roster la **contribution de chaque joueur au cycle courant** (`xp − last_butin_xp`, normalisée sur le meilleur contributeur). `last_butin_xp` est recalé à l'ouverture, sur le doc clan comme sur chaque doc membre.

### le coffre et son contenu

Y déposer un objet — ou y ajouter de l'argent de poche — prévient **tout le clan, admins compris** (sauf le déposant : le message est à la 3ᵉ personne), chacun dans sa langue, avec un regroupement par langue (une famille de cinq coûte deux envois, pas quatre). Le ton s'ajuste : la valeur déposée est comparée à la moyenne des **20 derniers butins ouverts** (`clans_chest_history`) — sous 20 % le dépôt est dérisoire, au-dessus de 180 % c'est un trésor, entre les deux le message part sans commentaire. Tant qu'aucun butin n'a été ouvert, la table est vide : l'annonce part nue, c'est l'état normal et pas un cas dégradé.

**Les notes du coffre.** Un chef peut déposer **plusieurs notes** — des annonces destinées au moment de l'ouverture. Chaque note a son identifiant et sa ligne dans le contenu du coffre ; son tap la **supprime** directement, sans écran d'édition : une note ne se corrige pas, elle se retire. Le dépôt d'une note emprunte le même canal d'annonce que les autres dépôts, sans verdict de valeur. Rien de tout cela n'est journalisé dans `clans_logs` — le journal est lisible par tout le clan et le contenu du coffre doit rester une surprise.

**Saisie d'une somme (`money_page`).** Un écran, trois modes : la **promesse** versée au coffre (elle rejoint le brouillon de l'écran de butin, rien n'est écrit avant « Valider »), le **retour** d'argent de poche d'un chef vers le coffre (écriture immédiate), et le **paiement du tribut** (un chef remet pour de vrai à un joueur l'argent gagné en jeu). Un `DvNumpad` remplace toute liste déroulante et **il n'y a aucun plafond de montant** : on ne connaît pas la monnaie du joueur, et là où une baguette vaut 100 000 un maximum n'aurait aucun sens. Ne subsistent qu'une borne de 12 chiffres (garde-fou technique) et, pour un retour ou un tribut, le solde réel de la bourse. Le montant vit sur la shape d'affichage : chaque frappe émet un `submit`, ce qui permet de normaliser la saisie en direct plutôt que de la raboter en silence au moment de valider.

### cérémonie d'ouverture du butin

Au plafond de la jauge, un coffre doré paraît sur l'écran Clan **des seuls chefs**, entouré d'une aura permanente (scène dvflame immortelle) qui ne s'éteint qu'au tap.

1. Le premier chef qui le touche prend un verrou **dvlock** (TTL **30 minutes**, généreux à dessein : il doit couvrir un rituel entier, discussions comprises). Il est le **meneur** ; les autres n'obtiennent rien. Si le meneur abandonne (app fermée, batterie morte), le verrou meurt seul et un autre chef reprend — c'est la seule porte de sortie.
2. Lui seul voit l'écran de rituel, qui lui demande de réunir le clan, de faire raconter à chacun son aventure, et de sortir la tirelire.
3. Son bouton « Prêt ! Ouvrons le coffre ! » pose `pending_opening` sur le doc membre de **chaque joueur en ligne** (`enabled != false` **et** `has_device != false`), sauf lui-même — prêt par construction.
4. La vigilance de chaque joueur voit le drapeau et ouvre le même écran chez lui, avec le récit de la bataille ; son bouton vide son `pending_opening`.
5. Le meneur suit l'appel sur une `DvList` d'attente — une ligne par joueur, coche verte dès qu'il a répondu — alimentée par **une vigilance par joueur attendu** (le framework écoute des documents, pas des collections). Un tap sur la ligne d'un absent le **force prêt**, pour qu'un seul retardataire ne gèle pas l'ouverture.
6. Quand plus personne ne manque, l'appareil du meneur relâche le verrou et déclenche la distribution : le partage, le recalage de `last_butin_xp` (clan **et** membres) et le drapeau `pending_butin` partent dans le même `batchWrite`. Les objets distribués passent par une sentinelle de transit (`owner = "opening"`) : ils ont quitté le coffre mais leur destinataire ne les a pas encore réclamés — sans quoi le coffre paraîtrait encore plein entre la distribution et la dernière réclamation.
7. Chacun réclame sa part sur son propre appareil, puis l'animation de récompenses. **L'attaque de bisous** — le petit mot qui nomme celui qui a le moins rapporté d'XP — est figée au même moment, et **vide sur l'appareil du principal intéressé** : on ne dit pas à un enfant qu'il est dernier, on le dit aux autres pour qu'ils viennent l'embrasser.
8. Les **notes des chefs** sont révélées ensuite, avec un minuteur de lecture forcée de 10 s avant que le bouton de sortie n'apparaisse ; sans note, l'écran est sauté.
9. Vient enfin la proposition de **raconter l'aventure** (le conte IA, section 6) : c'est là — et pas trois écrans plus loin — qu'on la fait.

Un log `ButinOpened` est écrit **après** le batch : on ne raconte que ce qui est acquis. C'est ce log, et non `clans_chest_history`, que le balayage serveur interroge pour savoir quand le coffre a été ouvert pour la dernière fois.

### indicateurs, avatar et nom

Les écrans `personnage` et `clan_page` affichent la même jauge de niveau (barre, flamme, écusson, `XP courante / seuil suivant`) ; `personnage` y ajoute la jauge de PV (cœur qui devient crâne à 0), `clan_page` celle du butin. Tout est recalculé à l'affichage depuis les seules valeurs stockées. Les deux écrans naissent « remplis » (géométrie persistée dans le registry) pour éviter le flash au rebuild.

L'écran personnage a un **mode édition** exposant deux gestes : renommer, et choisir son avatar dans une grille `DvExplorer`. La sélection persiste l'icône via le layer runtime **et** écrit `clans_players.avatar` ; à chaque apparition, le worker **relit** ce champ et l'applique — l'avatar suit le joueur d'un appareil à l'autre. L'avatar de clan a son miroir, réservé aux admins.

---

## 9. mécanique pv, mort et guérison

### pv affichés : tout se dérive, rien ne se planifie

Il n'y a **pas de batch serveur** qui décrémente les PV : la dégradation est calculée à l'affichage, côté client — choix d'implémentation (zéro coût serveur), révisable si le besoin d'un constat côté serveur émerge.

```
pvShown = clamp( pv − floor(jours_depuis(last_task) / decay) − |damage| , 0, pv )
```

`pv` : maximum stocké (init 10). `last_task` : date de la dernière tâche terminée. `decay` : jours d'inactivité (fractionnaires) par PV perdu, posé à la création du joueur (1 jour/PV actuellement ; la vision évoquait 3 jours — réglage de conf assumé). `damage` : dégâts additionnels, retranchés en valeur absolue — le champ ne peut jamais soigner ; réservé aux mécaniques futures.

Conséquence assumée : la mort n'est « constatée » que lorsqu'un écran calcule les PV. La lecture du champ `decay` est défensive : elle accepte les nombres natifs, les chaînes, et l'ancienne structure `{doubleValue:…}` laissée par un bug de sérialisation du backend REST — auto-réparation sans manipulation console.

### mort : crâne et gage

À 0 PV : le statut `dead` et un **gage tiré au hasard** (11 gages, humoristiques et non punitifs) sont persistés à la transition seulement ; un **overlay global** s'affiche sur tous les écrans à taskbar (scrim qui avale les taps, crâne, texte du gage suivi de la phrase de soin) ; un joueur mort **ne peut plus ni ouvrir un sous-tiroir ni prendre une tâche**. L'overlay est appliqué par mutation du template de conf (les pages futures naissent avec), plus un layer runtime persisté (réappliqué dès la première frame au redémarrage), plus un show/hide des pages déjà en pile. La musique bascule sur une playlist dédiée tant que le personnage est mort.

Le gage relève du contrat familial, comme le butin : rien ne vérifie techniquement son accomplissement — c'est l'admin qui guérit, donc c'est lui qui constate.

### menu du roster

L'écran Clan affiche le **roster** : une tuile par membre (avatar, niveau, PV, nom, couronne pour les admins, badge d'activité, barre de contribution au butin, argent), triée admins d'abord puis alphabétiquement. Pour un **admin**, un tap ouvre un menu contextuel ; pour un non-admin, rien ne s'ouvre.

- **Consulter le journal** — toujours proposé à un admin, sur tout joueur y compris lui-même.
- **Promouvoir chef / Rétrograder** — bascule dans/hors de `clans.admins`, avec miroir `is_admin` qui réveille la vigilance du membre. Le fondateur n'est jamais rétrogradable. La promotion joue l'anim « burn » chez le promu et notifie le reste du clan ; la rétrogradation est silencieuse.
- **Déclarer majeur** — admin du clan d'origine seulement, sur un mineur. Aucun contrôle de plafond : déclarer majeur ne **déplace** plus de place depuis que la grille n'a qu'un seul compteur (section 12).
- **Prendre sa place** — l'impersonation (section 2).
- **Déclarer hors ligne** — pose `has_device = false`. Le jeu l'ignore alors : exclu du partage d'XP et du butin, du décompte de la cérémonie, des notifications ; il ne peut plus mourir. Il repassera en ligne tout seul à sa prochaine connexion.
- **A quitté le clan** — tombstone `enabled = false`, jamais sur le fondateur. Le membre est **ignoré partout** et éjecté vers le decisiontree à sa prochaine frame (détecté par sa propre vigilance) ; s'il était chef, il est retiré de `clans.admins` pour que le décompte d'admins reste juste. Le même tombstone modélise un **départ volontaire** (la cible étant soi-même), qui éjecte immédiatement.
- **Guérir** — sur un joueur **mort** seulement, jamais soi-même. Rend 3 PV (pas les PV pleins : les futures classes, potions et objets doivent garder de la valeur) en **reculant `last_task`** pour que la formule retombe exactement sur la cible — le champ `damage` n'est pas touché, donc si `damage` seul maintient le joueur à 0, il reste mort. **Cooldown 3 jours par admin**, porté par l'acteur et non par la cible : deux parents peuvent chacun guérir dans la même fenêtre, c'est voulu.
- **Coup de pouce** — sur le(s) joueur(s) au plus petit XP du clan, jamais soi-même. **+50 XP au joueur seul** : ni le clan ni le butin ne sont crédités, ce serait détourner le coup de pouce en levier de progression collective. Cooldown 3 jours par admin.
- **Payer son tribut** — proposé sur toutes les tuiles, celle de l'admin comprise, grisé sur une bourse vide. Réutilise l'écran de saisie, plafonné au solde, **partiel autorisé**. L'avertissement nomme le joueur : le jeu ne peut pas constater un versement de la main à la main, c'est le chef qui le déclare. L'écriture retire la somme de la bourse **et** de son miroir sur le doc membre dans un `batchWrite` unique, avec recalage du repère de « déjà vu » (sinon le prochain butin afficherait un gain négatif), trace un log et notifie le joueur payé.
- **Rappels** (`nudges_on`/`nudges_off`) — un chef peut couper les relances d'engagement pour un enfant (section 13).
- **Résurrection** — bouton sous le gage de l'écran de mort, pas dans le roster : réservé à l'**admin solo mort**, que personne d'autre ne peut soigner. Soin complet, gage effacé, **sans cooldown** — c'est un déblocage de secours, pas une mécanique de jeu.

À la montée de niveau, le joueur est soigné complètement.

---

## 10. mécanique la fée

Tout le reste du jeu récompense l'**effort** : on vainc une monstre-tâche, on gagne de l'XP. La fée ne récompense que d'être passé par là. Au plus une fois par mois, sans que personne ne soit prévenu, elle prend la place d'une monstre-tâche dans un tiroir de domaine, pendant dix minutes. Qui la trouve et la touche choisit entre les deux cadeaux qu'elle tend ; elle disparaît alors pour tout le clan.

> **Le silence est la fonctionnalité.** Aucune notification, aucune ligne de journal, aucun badge tant qu'elle est là : la trouver **est** la récompense. Ce qui s'annonce ne part qu'**après** que quelqu'un l'a touchée.

L'état vit dans **un document Firestore partagé** (`clans_items/{clan}/items/fairy`) qui porte à la fois l'horloge du cycle, la fenêtre de dix minutes, l'endroit où elle se tient et les deux cadeaux tirés : deux appareils voient rigoureusement la même fée, aux mêmes mains.

### le tirage

Le dé est jeté au **dashboard**, et nulle part ailleurs — le seul écran par lequel passe tout joueur enrôlé. La courbe : `p = (écoulé / cycle_days) ^ curve_exponent`, bornée à [0, 1] — nulle juste après une apparition, certaine au terme du cycle (30 jours par défaut).

`roll_every_hours` (24 h) n'est pas un confort : sans lui, le dé serait jeté à **chaque ouverture de l'app**, et un clan qui l'ouvre dix fois par jour verrait la fée dix fois plus souvent qu'un clan qui l'ouvre une fois — la cadence ne voudrait plus rien dire. Le throttle est porté par le **document de clan**, pas par l'appareil : cinq téléphones dans la famille, un seul tirage par jour.

> À noter, et documenté dans le layer : avec un tirage quotidien et `curve_exponent: 1.0`, la garantie des 30 jours tient mais l'attente **moyenne** tourne autour d'une semaine. `curve_exponent` est le bouton qui corrige cela sans toucher au code (à 4, la moyenne remonte vers trois semaines).

Cas particuliers : un clan tout neuf **amorce** l'horloge sans faire apparaître quoi que ce soit (la magie n'en serait plus) ; un tirage raté ne repousse que le throttle, jamais l'origine de la courbe (sinon elle repartirait de zéro à chaque échec et la fée ne viendrait jamais) ; et deux appareils qui ouvrent l'app dans la même seconde sont arbitrés par un verrou, pour qu'il n'apparaisse pas **deux** fées, avec deux domaines et deux jeux de cadeaux.

La monstre-tâche remplacée est tirée parmi les tâches **vivantes, activées, visibles et que personne ne tient** — mêmes filtres que le boss serveur, plus l'exclusion des clones (un clone appartient à un joueur précis, le masquer ne priverait qu'une personne).

### la prise

Premier arrivé gagne. Un verrou `dvlock` arbitre la course simultanée — sa clef porte l'horodatage de naissance de la fée, une fée n'étant pas l'autre. Le verrou ne dit rien de l'état durable : on relit ensuite le document pour vérifier qu'elle n'a pas été prise plus tôt et que la fenêtre est ouverte. L'écriture de `taken_by` est ce qui la fait disparaître chez les autres, leur vigilance voyant le champ se remplir.

**Un joueur mort a le droit de la toucher** : c'est même tout l'intérêt des cadeaux de soin. Aucune garde de mort ici, contrairement à la prise de tâche.

### la cérémonie et les cadeaux

L'écran de la fée joue une scène dvflame (givre, lumière, neige) et une musique **en boucle** — contrairement à toutes les autres célébrations, elle reste tant qu'on n'a pas choisi. Les deux libellés sont posés à l'ouverture mais restent invisibles : c'est la fin du dernier acte qui les révèle. À la sortie, les deux musiques se **croisent** : l'ambiance repart pendant que le morceau de la fée descend, sur la même durée que le fondu visuel (2 s) — couper puis relancer laisserait un trou de silence.

Le catalogue vit dans un layer du bucket. Sept cadeaux, tirés **au poids et sans remise** (le joueur doit arbitrer entre deux choses distinctes) :

| cadeau | poids | montant |
|---|---|---|
| XP pour soi | 20 | 80–250 |
| XP pour un autre (au hasard) | 20 | 80–250 |
| XP pour tout le clan | 15 | 25–70 par tête |
| soin pour soi | 20 | 2–4 PV |
| soin pour un autre | 15 | 2–4 PV |
| soin pour tout le clan | 10 | 1–2 PV |
| faire surgir un boss | 10 | — (bonus calculé au verdict) |

Les variantes « pour tout le clan » portent des bornes plus basses : le total distribué grandit avec la taille de la famille, pas le montant par tête. Les cadeaux d'XP passent par le même chemin que le coup de pouce d'un chef — ni le clan ni le butin ne sont crédités : **la fée donne aux gens, pas à la trésorerie**. Les cadeaux de soin n'écrivent aucun PV (ils n'existent pas en base) : ils reculent `last_task`, en tenant compte du `damage` pour que le gain annoncé soit le gain reçu.

**Cas limite du clan d'une seule personne** : « pour un autre » ne peut désigner personne. La fée ne reprend pas son cadeau pour autant — il revient au joueur.

Le catalogue est un **dictionnaire, jamais une liste** : le merge de layers fusionne les listes en union sans ordre, impossible d'y surcharger un élément, alors qu'une clé nommée se surcharge champ par champ. C'est ce qui permet à un thème de retoucher un montant, et à un pack acheté d'ajouter ses propres cadeaux, sans une ligne de Dart. Un cadeau d'un **genre** nouveau demande en revanche d'enregistrer une action de plus.

Après le choix : une ligne de journal `FairyGift` (qui nomme le cadeau) puis une notification au clan qui, elle, **ne le nomme pas** — « X a rencontré une fée ! ». Elle ne dit pas qu'une fée est apparue, elle dit qu'elle est repartie, et avec qui. Un push qui annoncerait « +250 XP pour Léa » transformerait une jolie surprise en bulletin de score. Ni l'un ni l'autre n'est fatal : le cadeau est déjà crédité, et un push raté ne doit pas se lire comme un cadeau raté.

Dernier détail, invisible mais nécessaire : le crédit d'XP **rebase** le repère anti-double-fire de la célébration « cadeau d'XP », sans quoi la vigilance du joueur lancerait l'animation dorée **par-dessus** la fée, au moment même où elle s'efface. Une vraie montée de niveau garde le droit de partir après le fondu : c'est un bon final, et elle passe par un autre chemin.

---

## 11. mécanique journal de clan

### clans_logs : l'audit append-only

Chaque événement significatif écrit un document dans `clans_logs/{clanId}/logs` : `ClanCreated`, `MemberJoined`, `MemberCreated`, `MemberRevoked`, `TaskDone`, `TaskValidatedOk/Partial/Ko`, `PlayerResurrected`, `PlayerLeveledUp`, `ClanLeveledUp`, `ChiefPromoted`, `ChiefDemoted`, `TributePaid`, `FairyGift`, `BossSummoned`, `ButinOpened`, et les événements commerciaux (`StorePurchase`, `StoreSubscription`, `StoreRenewed`, `StoreTierChanged`, `StoreEnded`, `StorePaymentDefault`, `StorePaymentRecovered`, `StoreLocked`).

Le docId est construit `<rev>_<event>_<slug>` où `<rev>` est un nombre à 13 chiffres **décroissant** (`9999999999999 − epochSeconds`) : un tri lexicographique croissant remonte les logs les plus récents en tête, **sans index**. Deux logs dans la même seconde peuvent partager le même `<rev>` (toléré). Le champ `data` porte l'audit structuré, le champ `slug` un fragment ASCII tronqué.

Rien de ce qui touche au **contenu du coffre** n'y figure : le journal est lisible par tout le clan, et le butin doit rester une surprise. Ses chiffres vivent dans une table à part (section 16), précisément parce qu'elle ne dit que des nombres.

### écran log

Trois points d'entrée : l'option roster « Consulter le journal » (un joueur précis), le kebab **Personnage** (« mon journal »), et le kebab **Clan** (« journal du clan complet » — tous les joueurs, sans filtre). Les événements sont triés du plus récent au plus ancien, groupés par jour avec un en-tête de date localisé, et rendus en prose : tâche validée → la description « accomplie » suivie des XP réellement gagnés ; résurrection → la description de rédemption du gage ; montée de niveau → « a atteint le niveau N » ; rencontre de la fée → le cadeau, **sans son montant** (le récit raconte une rencontre, pas un score) ; achats et incidents de facturation — c'est là qu'ils se racontent depuis la suppression de l'écran « Mes achats ».

Les soumissions avant verdict n'apparaissent pas. Les traductions sont résolues **manuellement** (langue courante, repli `fr`) car le token de nom des descriptions doit être substitué par le nom du joueur **consulté**, pas celui du lecteur.

### partage

Un bouton de partage publie les **15 événements les plus récents** en texte brut — le récit à l'écran reste intégral. Le **conte IA** (section 6) est le second mode de sortie ; c'est le même écran qui les sert, avec un regroupement commun mais trois bornes distinctes (l'écran borne des jours, le partage et le conte bornent des lignes).

---

## 12. mécanique monétisation

### le modèle

**Un abonnement par clan, cinq paliers qui ne se distinguent QUE par le nombre de joueurs.** Essai gratuit de 14 jours, quelle que soit la taille du clan — un mois complet laissait passer le pic d'enthousiasme avant le premier paiement.

| Palier | Joueurs | Part des clans | Mensuel | Annuel |
|---|---|---|---|---|
| Essentiel | 1-2 | ~40 % | 1,99 € | 19,99 € |
| Clan | 3-4 | ~30 % | 2,99 € | 24,99 € |
| Tribu | 5-7 | ~25 % | 4,99 € | 39,99 € |
| Guilde | 8-12 | ~4 % | 5,99 € | 49,99 € |
| Royaume | 13+ | ~1 % | 7,99 € | 64,99 € |

Les bornes suivent la **démographie réelle des foyers**, pas une progression régulière : d'où Clan qui s'arrête à 4 et Tribu à 7. C'est le paramètre le plus sensible de toute la grille — un cran de décalage vaut ±10 % de plateau, cinq fois l'effet du barème lui-même. Les remises annuelles vont de −16 % à −33 %.

**Un joueur est un joueur.** Le décompte porte sur les membres actifs, admins compris, sans distinction d'enfant ni d'adulte ; un membre révoqué ou parti libère sa place ; déclarer un mineur majeur ne change rien. La grille précédente portait **deux plafonds distincts** (`max_kids` / `max_adults`), ce qui obligeait à savoir de quelle nature était chaque membre pour dire s'il restait de la place : une famille ne pouvait pas prévoir son propre palier, et le code ne pouvait pas contrôler proprement un candidat dont l'âge n'était pas encore connu. **Convention** : `-1` = illimité, jamais 0 — un plafond à zéro se lirait « aucun joueur autorisé », l'exact contraire, et un test `count >= max` écrit sans précaution bloquerait tout le monde sur le palier le plus cher.

Deux offres sont attachées à chaque base plan : `essai-14j` (éligibilité « nouveaux clients », arbitrée par Play lui-même) et `fondateur` (un mois offert puis la première année à −30 %, **éligibilité déléguée au développeur** : c'est la fonction `store_eligibility` qui tranche, en comparant la date de création du clan à un cutoff vivant dans un document de configuration serveur — décalable sans redéploiement). Un clan dont la date de création est illisible est considéré comme fondateur : les clans les plus anciens sont précisément ceux d'avant que le champ n'existe, et l'offre leur est due.

### qui paie, qui bénéficie

C'est **le clan** qui paie, jamais l'utilisateur. dvstore n'en garde qu'une empreinte sha256 — ni l'identifiant du clan ni son secret ne partent chez Play. Mais la séparation va plus loin, et elle porte tout le modèle :

- **acheter est personnel.** Un admin engage SON compte Google et SA carte ; un autre admin peut payer un pack avec le sien. Chaque achat reste attaché à son payeur, et remboursement, litige et résiliation le suivent. Le registre des achats vit dans une base dédiée (`{region}-store`), rangé par compte payeur ;
- **bénéficier est collectif.** Tout membre du clan lit la **projection** `workers/clans_store/{clanId}` : le pack de thème acheté par un adulte habille l'écran de tous les enfants, sans que personne d'autre n'ait rien à acheter ni même à savoir qui a payé. Un enfant n'achète jamais rien mais gagne tout.

L'achat est gardé **deux fois** : administrateur du clan, puis **porte parentale** (`dvparentalgate`) — être adulte administrateur ne dispense pas de le prouver devant l'écran. La porte ne rend rien : elle empile son écran et rappelle une action, l'achat est donc mis de côté le temps du détour, et un abandon l'oublie simplement. **Une seule exception**, décision produit assumée : le bouton « Se réabonner » de l'écran de clan gelé, qui n'est pas un étal qu'on parcourt mais une porte fermée avec un seul geste possible, déjà réservé aux administrateurs.

### où se choisit le palier

**Pas dans la boutique.** La boutique est un étal : on y vendra des packs de contenu et des thèmes, à l'unité, et on la parcourt quand on veut. Une grille tarifaire n'est pas un étal, et surtout elle ne se lit qu'au moment où elle répond à une question — « pourquoi je ne peux pas ajouter ce joueur ? ».

Le choix vit donc sur un écran dédié (`tiers_page`) qu'on n'atteint **jamais par navigation libre**. Cinq raisons l'ouvrent : le plafond atteint (créer un joueur, inviter par QR ou par lien, accepter une demande), le bandeau d'impayé, la notification de relance, « Se réabonner » depuis l'écran de gel, et le **mur de première cotisation**. La **raison** de la venue est publiée dans le dictionnaire et peinte en tête d'écran, puis remise à zéro — sans quoi une venue ordinaire hériterait du bandeau de la précédente.

L'écran présente les cinq paliers ensemble et n'en surligne que **deux** : le palier **courant** (coché, avec l'effectif réel du clan rappelé dessous) et le palier **conseillé** (fléché). On a résisté à en ajouter (« le plus populaire », « le meilleur rapport ») : ils dilueraient les deux qui répondent réellement à la question posée. Le conseillé n'est pas « le suivant dans l'ordre » mais **le moins cher qui couvre l'effectif visé et qui est strictement au-dessus du courant** — proposer une montée qui ne suffit toujours pas est le pire conseil qu'on puisse donner à quelqu'un qui vient de se voir refuser un membre. Un drapeau explicite distingue les deux façons d'arriver : un **refus de plafond** vise l'effectif **+ 1** (la famille veut une place de plus), une souscription ordinaire vise l'effectif **tel quel** (viser +1 vendrait le palier du dessus à un clan de cinq qui tient très bien dans celui de cinq).

Les prix viennent **toujours de Play** (localisés, taxes incluses — exigence de la politique du store), avec un repli du catalogue **par périodicité** : sans un repli annuel distinct, l'onglet « Par an » afficherait le tarif mensuel, et une grille tarifaire qui ment est pire qu'une grille vide — elle mentirait précisément pendant toute la recette, où aucun canal Play n'est ouvert. Le nom affiché est celui du **catalogue** et non celui de Play : sur un comparatif, le titre Play répéterait la marque à chacune des cinq lignes et noierait le seul mot qui les distingue.

Toutes les lignes sont tapables sauf le palier courant, **y compris les moins chères** : une descente de palier est un droit, et la refuser pousserait à résilier tout court, ce qui coûte bien plus qu'un downgrade. Un plafond dépassé après une descente **n'évince personne** — il ne bloque que les entrées suivantes.

### deux portes fermées, et deux seulement

Le jeu ne se ferme pour **aucun** état commercial. Ni la fin d'essai, ni l'impayé en cours ne barrent quoi que ce soit : la page des paliers porte l'offre, le bandeau prévient. Deux exceptions, toutes deux gardées au **dashboard** — le passage obligé de tout joueur enrôlé, ce qui suffit à garder les 25 écrans de jeu sans en instrumenter aucun :

**1. Le clan gelé** (`locked`, au 50ᵉ jour d'un impayé jamais régularisé). Le donjon se ferme, une seule fois, et l'écran de gel devient la racine de la pile. Ce qui justifie de fermer au bout du compte n'est pas la sanction mais le **coût** : Firestore, Storage et Vertex AI sont facturés à l'éditeur, et un clan qui ne paie plus depuis deux mois continuait de les consommer. Le gel survenu **en cours de séance** (le balayage passe à 5 h, la vigilance temps réel le rapporte aussitôt) est traité aussi : sans cela, une famille déjà dans le jeu au moment du gel y resterait jusqu'à la prochaine ouverture — soit précisément la session la plus longue. Un enfant qui tombe sur cet écran ne se voit **rien** proposer : il lit la ligne qui dit que rien n'est perdu.

**2. Le mur de première cotisation.** Le plafond de joueurs attrape les foyers qui **grandissent** ; il ne dit jamais rien à un foyer d'un parent et un enfant, qui tient dans le palier d'entrée — soit environ quatre clans sur dix. Pour ceux-là, la seule porte est le nombre de tâches menées à leur terme : `clans.validations`, incrémenté à chaque verdict accepté. Le seuil est de **2**, et le raisonnement est entier : une famille joue sa première tâche dans les dix minutes qui suivent l'installation ; la deuxième dit qu'elle est **revenue**. Aucune condition de délai — deux validations dans le même quart d'heure sont le signe le plus favorable qui soit, pas un artefact à filtrer.

Le mur est un état **dérivé**, recalculé à chaque arrivée au dashboard depuis des faits persistants, et surtout pas un drapeau one-shot : il survit au changement d'appareil comme à une réinstallation, et vaut pour les deux chefs d'un clan sans rien à synchroniser. **Trois conditions**, et la deuxième protège les enfants :

- le clan ne cotise pas ;
- l'utilisateur **peut payer** (administrateur) — un enfant ne peut pas, lui fermer le jeu ne servirait qu'à l'inquiéter. Cette condition couvre au passage la prise de place, qui change l'identité agissante ;
- le clan **n'est plus seul**. Un fondateur teste volontiers deux tâches en attendant que sa famille installe le jeu — et l'admin solo auto-valide sans preuve, si bien que le compteur atteint le seuil en quelques minutes. Le mur tomberait alors avant que le clan existe vraiment : un écran de paiement sans issue en face d'un roster d'une tuile, et l'essai de 14 jours qui démarre pendant la phase de constitution, celle qui a le plus de chances d'échouer.

Le mur ne se ferme **que pour les chefs**. Les enfants continuent de jouer : leurs tâches s'empilent en attente d'une validation que personne ne rend, et c'est très exactement la pression qu'on veut — elle s'exerce sur l'adulte qui peut payer, sans qu'aucun enfant ne voie d'écran de paiement.

Le compteur `validations` est **falsifiable** (la règle de `clans` autorise tout détenteur du secret à écrire) : sans gravité, le fausser ne peut qu'**avancer** la demande de cotisation, jamais la retarder ni accorder un droit.

### plafond de membres

Le plafond opposable est lu sur les `grants` du catalogue (`max_players`), et le repli d'un clan sans droit acquis est le plafond du **palier d'entrée** — pas « illimité ». C'est le point qui a été corrigé : sans abonnement, l'ancienne version rendait `-1` au motif qu'un clan sans abonnement relevait de la paywall et non d'un plafond. Le raisonnement tenait tant qu'une paywall existait ; elle a été supprimée, rien n'a pris le relais, et un clan qui ne souscrivait pas n'était jamais plafonné, donc jamais amené à la page des paliers, donc jamais sollicité. **Une paywall n'existe que si quelque chose y mène.**

Deux arbitrages d'erreur, tous deux dans le même sens :

- **catalogue absent** (le layer du bucket n'est pas descendu) → aucun plafond. Plafonner sur une ignorance refuserait des membres pour une raison qui n'existe pas ;
- **effectif illisible** → on laisse passer. Des deux erreurs possibles, refuser un membre sur une lecture ratée est de très loin la pire : elle est visible, injuste et sans recours, là où laisser passer un membre de trop coûte une place, une fois, et se rattrape au contrôle suivant.

Le bandeau de refus lui-même a **deux formes**, choisies sur l'histoire commerciale du clan et jamais sur le plafond. À un clan qui n'a **jamais** souscrit, on annonce ce qui l'attend — cotisation, 14 jours offerts, arrêt quand il veut ; « le clan est au complet » se lirait comme un refus alors que c'est une proposition. À tous les autres — abonné qui déborde, résilié, expiré, gelé — on ne promet **pas** les 14 jours : Play ne re-sert pas l'offre d'essai à un compte qui l'a déjà eue, et une promesse que la feuille de paiement dément est pire que pas de promesse du tout.

### défaut de paiement

C'est un jeu familial destiné à aider les parents : on montre de la compréhension. Le calendrier est **entièrement déclaratif** côté serveur (`STORE_LIFECYCLE`), et les textes sont au serveur et non dans le thème — ils doivent partir même quand l'app n'est jamais ouverte, donc sans le dictionnaire de traductions du client.

| jour | phase | ce qui se passe |
|---|---|---|
| 0-10 | grâce | rien, aucune relance |
| 10-20 | `soft` | relances douces aux **adultes** seulement |
| 20-40 | `firm` | relances plus fermes |
| 40-50 | `last` | messages d'adieu |
| 50 | **gel** | le donjon se ferme, l'écran de clan gelé prend la racine de la pile |
| 700-730 | `farewell` | on prévient un mois avant l'effacement |
| **730** | purge | dissolution fonctionnelle du clan (`clan_purge`) |

**Deux ans entre le gel et la suppression, et non 40 jours.** Le calendrier ne change pas avant : grâce 10 jours, relances jusqu'à J50, gel à J50 — c'est **après** que l'on desserre. Une famille qui arrête n'a pas toujours renoncé : elle déménage, l'enfant grandit, la rentrée passe. Ce qui coûte à reconstituer n'est pas le clan mais son **histoire** — les tâches réglées, les niveaux, le butin, le journal de chacun. La conserver ne coûte, elle, presque rien : un clan gelé ne fait plus aucune requête, les preuves photo n'ont jamais quitté les appareils, et il ne reste que quelques mégaoctets par clan. Supprimer coûterait même des écritures. La phase `farewell` existe parce que deux ans de silence s'achevant sur une suppression que personne n'a vue venir rendrait vaine l'opportunité qu'on veut leur laisser.

**Le bandeau d'impayé.** Aucun écran bloquant : un bandeau overlay rouge doux, réservé aux **chefs de clan** (« on n'inquiète surtout pas les enfants », et ce sont de toute façon les seuls capables de payer). Il est piloté par la **phase publiée par le serveur** et non recalculée : le client ne connaît ni la date d'entrée en défaut ni les seuils, et deux calendriers qui divergent valent moins qu'un seul. Le déclencheur est la phase et non le hook de transition — un hook ne se déclenche que sur un changement, et une session qui s'ouvre sur un clan en défaut depuis trois semaines n'en verrait jamais passer un seul. **Mémoire seule, aucune persistance** : un bandeau rouge persisté sur disque survivrait à la régularisation et accuserait une famille à jour.

### codes cadeaux

`store_grant` accorde des mois offerts — parrainage, et **compensation des familles du test fermé**, dont les achats sous licence sont gratuits et qu'aucune offre Play ne peut donc récompenser. Mais `store_grant` exige qu'on **désigne** le clan, or quand on veut remercier une famille on ne dispose que de son e-mail, et rien ne mène d'une adresse à un clan. **Un code inverse l'identification** : ce n'est plus nous qui désignons le clan, c'est le clan qui se désigne en réclamant.

L'écran ne fait que présenter un code ; tout le droit s'acquiert serveur (`store_claim`) : appartenance au clan, droit de l'engager (administrateur, via la traduction des identifiants métier), plafond d'essais (**5 codes faux par compte et par jour** — un code juste ne consomme rien, une famille qui reçoit deux cadeaux n'est jamais bloquée), puis consommation du code dans une transaction avant crédit. Le **registre des codes vit dans une seule base** (`eu-store`) et non une par région : sinon un même code serait réclamable une fois en EU et une fois en US.

Les mois obtenus rejoignent la **même réserve** que les mois offerts à la main, consommée par le balayage quotidien : réclamer pendant une cotisation payante ne perd rien, la réserve attend que l'abonnement retombe. Le message de succès dit **ce qui a été reçu, pas quand cela s'ouvre** — promettre une date que l'app ne décide pas serait un mensonge poli. Un statut inconnu (fonction plus récente que l'app) retombe sur le message générique plutôt que d'afficher un jeton brut, et une erreur réseau ne prétend rien : on ne sait pas si le code est bon, et réessayer plus tard ne coûte rien.

`store_mint` fabrique des lots (nombre, mois, usages, validité, libellé) et `store_revoke` coupe un code ou un lot entier — le pendant indispensable de la fabrication : un code publié sur un flyer et recopié sur un forum doit pouvoir s'arrêter sans passer par la console Firestore, c'est-à-dire au pire moment et sous pression. La révocation **ne supprime rien** : ce qui a déjà été donné reste donné. Les deux fonctions partagent la **même allowlist** que `store_grant` — offrir des mois et fabriquer de quoi en offrir sont le même pouvoir. Vide, elle ferme la fonction à tout le monde : c'est le bon défaut pour une fonction qui distribue de la valeur. Les codes fabriqués **ne repassent jamais** (seule leur empreinte est conservée) : ils sont posés dans le dictionnaire le temps de les faire sortir de l'app par le partage.

### ce que les droits changent dans le jeu

**Aujourd'hui, une seule chose : le plafond de membres.** Le reste (packs de contenu) passera par les tags de layers, que dvstore active lui-même. Le routeur de gating (`store.gate.<feature>`, qui rend `allowed | paywall | locked`) n'est câblé **nulle part**, et c'est délibéré. Le jour où une fonctionnalité sera vendue à l'unité, une entrée `dvsteps` et une clé dans les `grants` suffiront — sans une ligne de Dart.

Les produits à l'unité sont volontairement **absents du catalogue** au lancement : le socle technique (achat, activation par clan, gating, restauration) est livré et se teste avec les abonnements, mais déclarer un pack dont le contenu n'existe pas afficherait une boutique qui vend du vide. `pucatalog` ne gère d'ailleurs aujourd'hui que les abonnements.

---

## 13. notifications et relances d'engagement

Deux familles, et la distinction porte tout le reste : les notifications d'**événement** (il s'est passé quelque chose, on le dit) partent du **client** ; les **relances** (il ne se passe plus rien) partent du **serveur**. Une famille qui décroche est une famille que plus personne n'ouvre : aucun client ne peut détecter son propre silence.

### notifications d'événement (client)

| notification | destinataires | forme |
|---|---|---|
| demande de validation | tous les admins sauf le demandeur | 3 boutons *si le clan cotise*, sinon tap-corps |
| verdict rendu | l'assignee | tap-corps (ouvre l'app) |
| nouveau membre | tout le clan sauf l'arrivant | texte simple |
| montée de niveau | tout le clan sauf l'intéressé | texte simple |
| boss recommandé | tout le clan sauf le chef qui recommande | texte simple |
| dépôt au coffre / note de chef | tout le clan sauf le déposant | texte simple, ton modulé (section 8) |
| don d'objet | le destinataire | texte simple |
| tribut payé | le joueur payé | texte simple |
| rencontre de la fée | tout le clan sauf l'intéressé | texte simple |
| cérémonie du butin | les joueurs appelés, puis le meneur | canal principal |
| promotion chef | tout le clan sauf le promu (qui a l'animation) | texte simple |

Toutes sont traduites dans la langue **du destinataire**, lue sur son doc membre : la résolution est manuelle depuis le store fusionné, jamais par un token `@@@T:@@@` qui résoudrait dans la langue de l'émetteur. Les envois sont **regroupés par langue** quand la liste est longue (coffre, fée) : une famille de cinq coûte deux appels au lieu de quatre. Convention maison : une action **unique et sans libellé** ne produit aucun bouton, et le tap sur le corps du bandeau déclenche l'action.

**Les trois boutons de validation sont un bénéfice d'abonnement.** Pour un clan qui ne cotise pas, la notification porte une action unique sans libellé, et le tap ouvre l'app sur la tâche à valider. C'est délibéré et c'est le seul levier du genre dans le jeu : les trois boutons résolvent la validation **sans jamais ouvrir l'app**, donc sans jamais amener le chef devant quoi que ce soit — ni la page des paliers, ni le mur. Ils reviennent dès qu'une cotisation est active.

### relances d'engagement (serveur, `pulse_sweeper`)

Une passe par jour et par région, à **17 h UTC**. L'heure est le garde-fou : contrairement aux relances d'impayé qui s'adressent à un adulte et partent à 5 h, celle-ci peut atteindre un enfant — on vise le début de soirée locale, après l'école, avant le coucher.

**Deux principes portent tout le reste :**

1. **l'unité de relance est le CLAN, pas l'événement.** Trois enfants avec trois validations en souffrance donnent UNE notification au parent, pas trois ;
2. **la condition d'entrée est le SILENCE, pas l'événement.** Un parent qui ouvre l'app tous les jours et laisse traîner une validation fait un choix ; le relancer serait du harcèlement. Une seule connexion de n'importe quel membre remet les compteurs à zéro : une famille vivante ne reçoit jamais rien, par construction.

**L'énumération des candidats** repose sur deux requêtes **bornées des deux côtés**. La borne haute écarte les vivants (48 h de silence minimum), la borne basse écarte les partis (**30 jours** : au-delà, on cesse de relire le joueur). C'est l'arrêt définitif, obtenu par la requête plutôt que par un compteur d'état — sans lui, la population des dormants ne ferait que grossir. La seconde requête rattrape les clans **jeunes** (moins de 14 jours), qui ne sont pas forcément silencieux : un fondateur qui ouvre l'app tous les jours sans avoir rien configuré est invisible de la première, et c'est pourtant le décrochage le plus coûteux du parcours.

**Deux pistes cloisonnées, une notification maximum par personne et par passe.**

**Piste adulte** (les chefs), un motif par passe, aux jours **2, 5 et 12** de silence, puis plus rien — trois messages ignorés SONT une réponse. Deux pressions distinctes, et les confondre était une erreur : l'**onboarding** ne se mesure pas au silence mais à l'**âge du clan** (un fondateur bloqué n'est pas silencieux) ; les autres motifs supposent au contraire une famille qui ne vient plus. Un seul motif part, l'onboarding l'emportant quand il vaut — on ne parle pas du coffre à qui n'a pas encore de quête :

- `onboarding_empty` — aucune quête configurée ;
- `onboarding_idle` — les quêtes sont prêtes mais aucune n'a jamais été jouée ;
- `onboarding_alone` — le donjon tourne, mais le chef est seul dedans **et n'a jamais ouvert d'invitation**. Ce dernier discriminant compte : jouer à deux est ~40 % des clans et un usage parfaitement légitime, le reprocher insulterait la plus grosse part de la base. Le critère est `clans.first_invite_at` — celui qui a essayé et n'y est pas arrivé n'est pas celui qui a choisi. Sans cette trace, on se tait ;
- `validation` — une quête attend un verdict depuis deux jours. Le motif le plus actionnable du lot, et le seul à porter des boutons (mêmes trois actions que le client, même charge : aucun code supplémentaire, et la **même règle de cotisation**) ;
- `chest_full` — le coffre déborde et n'a pas été ouvert depuis trois semaines. La date de dernière ouverture est lue dans le **journal** (`ButinOpened`) et non dans la table d'historique : celle-ci n'est écrite par personne, un coffre ouvert hier y paraîtrait éternellement oublié ;
- `chest_empty` — le coffre est vide alors que le clan joue. Jamais dit à un clan qui n'a rien validé : un coffre vide y est normal, pas un symptôme.

Le palier **n'avance que si quelque chose est parti**. Sinon un parent dont l'appareil n'est pas encore enregistré brûlerait ses trois relances sans jamais rien recevoir. Et le compteur **retombe sur la disparition du motif**, pas sur une simple connexion : un parent qui ouvre l'app sans trancher le verdict qui traîne n'a rien résolu, son clan ne doit pas repartir pour trois relances au premier jour de silence suivant.

**Piste enfant** (les non-admins), jamais d'administration de clan, jamais rien de monétaire — c'est la règle de routage, et elle ne souffre pas d'exception :

- **le boss** : après **7 jours** de silence, le donjon convoque lui-même un monstre. Il **existe** — le serveur pose un vrai `recommended` sur une vraie tâche dormante **avant** d'annoncer quoi que ce soit, et journalise un `BossSummoned`. Annoncer un monstre qu'on ne crée pas, c'est mentir à un enfant qui va vérifier. Un par clan et par **quinzaine** au maximum : le bonus d'XP est réel, un boss automatique trop fréquent déréglerait la progression et viderait de son sens la recommandation d'un chef. Le tri s'appuie sur l'index déjà déclaré pour la validation (`last` vide trie en tête, ce sont les tâches jamais prises) et l'écriture est **ciblée** — un PATCH complet réinitialiserait la régénération de la tâche ;
- **le retour du clan** : les autres ont repris, pas lui. Cadence 7 puis 21 jours, par membre. Le texte ne nomme ni ne compte **jamais** les autres membres, et parle de la place gardée plutôt que de l'absence remarquée — désigner un enfant comme le retardataire de la fratrie transformerait le jeu en instrument de comparaison entre frères et sœurs.

**Les garde-fous** : silence total sur un clan en défaut de paiement (il reçoit déjà les relances de cotisation, et une famille en difficulté n'est pas une famille qui se désintéresse), sur un clan gelé ou purgé, sur un clan « muté », sur un joueur déclaré hors-ligne, et sur quiconque a coupé les rappels. **Plafonds durs** sur chaque requête (3000 joueurs, 500 clans, 500 notifications) : ce n'est pas une optimisation — le budget coupe Cloud Run à 8 €/mois avec `auto_disable`, et une requête emballée qui retente n'aurait pas seulement coûté cher, elle aurait **éteint le backend**.

**« Ne plus me faire signe »** est à un tap dans le kebab Personnage, et un chef peut aussi le poser pour un enfant depuis le roster : un refus qu'il faut chercher n'est pas un refus. Le réglage est écrit en **deep-merge ciblé** sur le doc membre — un PATCH complet emporterait xp, pv et `last_task` — et le kebab le **relit** à chaque ouverture plutôt que de le mettre en cache : un réglage qui affiche l'inverse de ce qu'il vaut est pire que tout. Illisible, on n'affiche **ni** l'une **ni** l'autre option plutôt que de deviner.

**Où l'état vit.** Les compteurs sont dans `clans_pulse`, en lecture seule pour les clients. Les marqueurs **par membre** y vivent aussi, alors que leur place naturelle serait le doc `clans_players` correspondant : plusieurs écritures du client sur ce document sont des PATCH **complets**, un champ serveur posé là serait effacé au prochain login du joueur, et la relance repartirait de zéro indéfiniment.

Le helper d'envoi est un **portage** de celui du module de facturation (pas une bibliothèque partagée : chaque Cloud Function est déployée avec son propre `index.ts`), et il en corrige un défaut : une notification **à boutons doit être data-only**. Android n'affiche pas de boutons personnalisés pour un message portant un bloc `notification` quand l'app est fermée — le système le rend lui-même et court-circuite le handler de fond, ce qui est exactement le cas des trois boutons de validation, dont tout l'intérêt est de trancher sans ouvrir l'app.

**`PULSE_DRY_RUN` est à `true`** : la fonction calcule tout, journalise tout, n'envoie rien et n'écrit aucun état. À laisser ainsi jusqu'à ce que le rapport de plusieurs passes soit jugé crédible — une relance partie ne se rattrape pas.

---

## 14. tutoriel et rappels de recrutement

Le module `dvtuto` joue des **leçons interactives** : gel de l'écran, voile à ~70 %, spotlight sur un widget à la fois, délai inerte de 0,8 s avant de pouvoir avancer (anti-tap accidentel). Une leçon cible des widgets par leur identifiant, est jouée à la première arrivée sur son écran, puis marquée « vue » par utilisateur et par appareil. Tout est déclaratif dans `client/config/dvtuto.yml` ; les textes sont des tokens de traduction.

Neuf leçons couvrent le parcours : `dashboard_intro` (les cinq onglets), `personnage_intro`, `clan_intro` (identité, jauges, roster décomposé — la liste puis l'avatar, le nom, le kebab de la première tuile), `combat_domains`, `combat_tasks`, `combat_active`, `items_intro`, `create_player_intro` et `impersonation_back`.

Quatre mécanismes méritent d'être connus :

- **les overrides par condition** : une même étape porte un texte joueur et un texte chef, choisi sur l'état réel (`worker.player_last_is_admin`) ; une étape entière peut être conditionnée (`requires`), comme le switch Jeu|Admin ou les panneaux d'options d'administration ;
- **les panneaux** : au lieu d'un spotlight, une étape peut afficher un tableau — la liste des options d'un menu réel (lu depuis le menu lui-même : le tutoriel ne redit pas ce que la conf déclare), ou une légende d'icônes (flamme, main, badge XP, crâne, pansement) ;
- **les leçons manuelles** : `create_player_intro` n'est jamais jouée à l'arrivée sur un écran, elle est déclenchée à la main par l'action qui en a besoin, et rend la main à la fin ;
- **le déclenchement du tutoriel du dashboard** n'est **pas** l'`appear` de l'écran mais la **fin de l'animation de bienvenue**. Son voile vit sur l'Overlay du Navigator, donc au-dessus de la vue de scène, et il avalerait le « burn » ; et `dvtuto.enter` renonce **en silence** s'il tombe pendant un interlude, sans seconde chance — le retour par la taskbar émettant `show` et non `appear`. Partout ailleurs, le tutoriel est appelé **en dernier**, après un drainage explicite des interludes en cours, et jamais depuis la liste `appear` de la conf (qui n'est pas awaitée : il partirait en parallèle du handler et poserait son voile par-dessus ce qui joue).

### les rappels de recrutement

Deux écrans **ne sont pas des tutoriels** et le disent : en-tête « RECRUTE » en ambre au lieu du « TUTORIEL » bleu, absents de l'écran de rejeu (il n'y a rien à « revoir » : ce n'est pas de la pédagogie), et surtout une **cadence** au lieu d'un drapeau « vu » — première ouverture, puis une sur trois, arrêt définitif après cinq affichages, le compteur n'avançant que sur une ouverture où les conditions sont satisfaites.

Ils comblent un trou précis : le fondateur sort de la création de clan en croyant avoir fini de configurer (il vient d'enchaîner le decisiontree), et rien ne lui dit qu'il lui reste le principal — faire installer l'app à sa famille, puis lui montrer le QR code. Le tutoriel du dashboard lui fait visiter cinq onglets sans jamais prononcer le mot « inviter ». Les deux rappels forment une **chaîne** : le premier envoie vers l'onglet Clan, le second vers le kebab. Ils ne se déclenchent que pour un chef dont le clan est encore **seul**, drapeau posé à la création du clan, à chaque lecture du roster et à l'admission d'un candidat — jamais par une lecture Firestore dédiée.

Le même souci a réordonné une paire d'étapes de `clan_intro` : « QR code du clan » **avant** « Créer un joueur », la règle d'abord et l'exception ensuite. Le tutoriel détaillait la création d'un joueur sans téléphone — le cas rare — et taisait le QR code, qui est le cas nominal de la cible ; sans la première étape, la seconde se fait passer pour la voie normale.

---

## 15. banc d'essai

Éprouver un impayé, une paywall ou l'apparition d'une fée ne doit demander ni rebuild, ni console, ni attendre trente jours. Trois outils, tous gardés par `store.debug.test_mode` — un drapeau du **layer cloud**, pas du binaire : le bucket de production le pose à `false`, l'entrée de menu disparaît, et il n'y a rien à retirer plus tard. Une condition d'administrateur s'y ajoute côté worker : un enfant ne voit jamais ces entrées.

> Le réglage vivait autrefois dans `config.yml`, donc dans le binaire : éprouver un impayé demandait d'éditer **puis de reconstruire l'app**. Pire, un état simulé oublié dans une release vendrait un abonnement que personne ne peut acheter — c'est arrivé.

**Les scénarios commerciaux** (kebab de la boutique → « Changer de scénario ») sont des **paquets cohérents** déclarés dans le layer du bucket : ce qu'on veut éprouver est « un clan en impayé dur », pas « hold avec firm ». Le worker les traduit en réglages de simulation que dvstore relit à chaque rafraîchissement ; la bascule est immédiate, et « réel » ressort du banc sans rien écraser. Trois paliers seulement y figurent, pas cinq : ce qu'on éprouve n'est pas la grille tarifaire mais le **plafond** — un palier étroit (2 places), un palier courant, un palier illimité. Une phase de relance déclenche en plus l'**envoi réel** de la notification correspondante aux chefs, par le même canal et avec le même texte que celle du serveur.

**Ce que le banc ne reproduit pas**, et qu'il faut savoir en lisant ses résultats : la projection `clans_store` n'est **pas** écrite (elle est fermée au client), donc l'état ne se propage pas aux autres appareils du clan et ne survit pas au redémarrage ; et le balayage quotidien du serveur ne voit rien — il tourne à 5 h du matin, on ne l'observait de toute façon pas en session. Une première version passait par une fonction serveur qui écrivait la vraie projection : c'était payer très cher trois avantages minces, dont une **allowlist de comptes à maintenir pour une fonction qui accorde un droit payant en production** — « être administrateur du clan » ne la protège pas, n'importe qui crée un clan et en devient l'administrateur. Ce qui manquait réellement — recevoir la notification — ne demandait aucun serveur.

**La fabrique de codes** (`store_mint` / `store_revoke`) s'appelle depuis l'app, sous le compte éditeur : une fonction callable exige un jeton d'**utilisateur** authentifié, elle ne se joint donc ni en curl avec un compte de service, ni depuis un script. La vraie garde reste serveur (`GRANT_ADMINS`) ; l'écran ne fait qu'éviter de montrer une porte qui ne s'ouvrirait pas.

**« Faire venir la fée »** la fait apparaître tout de suite, et **écrit en clair dans le journal de mise au point** où elle se trouve (domaine, tâche remplacée, les deux cadeaux). Elle est placée au hasard parmi dix-neuf domaines : sans cette ligne, la retrouver veut dire ouvrir les tiroirs un par un. Elle est journalisée en `warning` et non en `info` — la seule ligne qu'on vient vraiment y chercher ne doit pas se noyer dans le flot des lectures de tâches qui la suivent.

**Le balayage de relance** a son propre banc, côté serveur : la fonction étant en `trigger: http`, elle est **privée** (seules les identités portant `run.invoker` peuvent l'appeler). Un paramètre force un motif sur un clan donné, immédiatement, **par le chemin réel** — même code, même charge utile, mêmes mots. C'est mieux qu'un banc côté client, qui passerait par un autre chemin d'envoi et exigerait de recopier les textes dans le dictionnaire du client, où ils divergeraient. Ni cadence ni silence ne s'appliquent, et **aucun état n'est écrit** : le banc ne consomme pas un palier de relance et ne fausse donc pas la passe du soir. Seule exception assumée : le boss pose un vrai `recommended`, puisque c'est précisément ce qu'il s'agit de vérifier.

Deux autres interrupteurs, hors mode test : `PULSE_ENABLED` (une fonction qui va chercher des familles inactives doit pouvoir être coupée sans redéploiement) et `catalog.dry_run` du backend, qui affiche le plan complet de publication en Play Console — créations, modifications, désactivations — sans rien écrire. C'est le seul moment où une faute de frappe se rattrape encore : un identifiant Play créé ne se supprime **jamais**.

Enfin, un verrou de production (`build.production_on`) neutralise le mot-clef `reset` du builder : le jour où l'app sert de vrais clans, il reste tapable mais ne supprime plus rien — ni Firestore, ni GCS, ni Auth, ni les caches locaux.

---

## 16. modèle de données

Sept bases Firestore par région (`{eu,us}-…`), toutes en isolation stricte : **`workers`** (le jeu), `sessions` (traces de connexion, TTL), `messaging` (jetons FCM), `documents` (consentements), `secrets` (secrets post-acceptation de dvvirtuallobby, usage unique), `virtuallobby` (submissions, managements, verrous) et `store` (registre **personnel** des achats, jetons Play, codes cadeaux).

### base `workers`

**`users/{userId}`** — un document par utilisateur.

```yaml
ownerId: "firebase-uid"
userId:  "uuid-métier"          # PAS l'uid Firebase : cf. userindexes
enabled: true                   # false = suppression logique
last_clan: "uuid-clan"
first_clan: "uuid-clan"         # premier clan rejoint, gelé
internal: { name: "Grog" }      # prénom saisi
external: { name: "Grog" }
active_task:  "{clanId}_{taskId}"   # reprise après un kill
active_proof: "uuid-photo"          # "noproof" si sans photo
clans:
  "{clanId}": { date: "...", clanSecret: "uuid-secret", enabled: true }
steps:
  region_intro / region / legal_state / name / cgu / clan
```

Les `steps` sont le journal d'onboarding ; leur présence conditionne la navigation au login. **L'enrôlement se lit sur `steps.clan.clanId` non vide**, pas sur la présence de `steps.clan` : au départ d'un clan, les pointeurs sont vidés et le joueur repart au choix de clan.

**`userindexes/{firebaseUid}`** — document léger `{ownerId, userId, enabled, clans: {[clanId]: {clanSecret}}}`. Il porte **deux rôles** : la table UID d'authentification → userId **métier**, et le coffre des `clanSecret` que les règles déréférencent. La distinction des deux espaces d'identifiants est structurante : `clans.admins` et `clans_players` portent des userId métier, `msgregistry` et les fonctions callable voient des UID Firebase, et **toute comparaison entre les deux doit passer par cette traduction** — sans elle, elle ne rend jamais vrai, et plus personne ne peut payer, être notifié ou être relancé.

**`clans/{clanId}`**

```yaml
ownerId: "uuid-secret"           # le clanSecret, PAS l'UID du créateur
date:    "..."                   # création — sert aussi à l'éligibilité fondateurs
admins:  ["userId", ...]
founder: "userId"                # admin à vie, jamais rétrogradable ni révocable
avatar:  "icon_12_C_03.png"
xp: 0                            # niveau dérivé
butin_xp: 0                      # jauge d'ouverture (0 → 1000)
title_idx: -1                    # titre PORTÉ ; -1 = aucun
butin_xp_factor: 1               # amorcé par la conf, modifiable en partie
max_xp_butin: 50                 # plafond d'UN crédit (+20 × niveau du clan)
enabled_multiple: ["chambre_enfant_01", ...]
validations: 0                   # tâches validées — déclenche le mur de 1re cotisation
first_invite_at: "..."           # une invitation a-t-elle déjà été ouverte ?
internal: { name: "Les Chevaliers du Frigo" }
external: { name: "Éclaireurs-du-Vide-eu-142" }
enabled: true                    # false + dissolved_at = clan dissous
```

**`clans_tasks/{clanId}/tasks/{taskId}`** — `status`, `assignee`, `dead`/`revive` (fenêtre de régénération), `proof`, `recommended` (boss), `enabled`/`visible` (administration), `last`, `touched` (curseur de delta-sync), `domain` et, sur un clone, `original`/`owner`/`owner_name`/`label`. Un index composite `(status, last)` sert le balayage serveur. Sous-collection sœur `domains/{domainId}` pour l'activation des domaines.

L'écriture dvcloud est un **deep-merge** (via `updateMask`) : les champs omis sont préservés, et effacer un champ demande de le poser explicitement à `""`. Les mutations réinjectent les champs d'identité, et la fenêtre `dead`/`revive` est systématiquement préservée par les écritures qui ne la redéfinissent pas — sinon l'XP d'une immortelle serait remise à plein par une simple prise.

**`clans_players/{clanId}/players/{userId}`** — la fiche de jeu d'un joueur **dans un clan**.

```yaml
name / avatar / lang / devices        # identité et cibles FCM
xp: 0                                 # niveau dérivé, jamais stocké
pv: 10 / damage: 0 / decay: 1.0       # PV : tout se calcule depuis last_task
last_task: "..." / status: alive|dead / gage: "gage_07"
max_xp: 100                           # plafond d'XP par tâche, propre au joueur
last_butin_xp: 0                      # contribution du cycle courant
title_idx: -1
wallet: 0                             # MIROIR de clans_items/wallet_{userId}.quantity
legal_state: "k|t|a"
is_admin: false                       # miroir de clans.admins (réveille la vigilance)
enabled: true                         # false = tombstone (révoqué / parti / supprimé)
has_device: true                      # false = hors-ligne ou joueur sans compte
no_account: true                      # joueur créé par un chef
nudges: true                          # false = « ne plus me faire signe »
original_clan: "uuid-clan"
last_boost / last_cure                # cooldowns 3 j, portés par l'ADMIN acteur
last_connected / last_version / tz_offset
pending_opening: "..."                # appel de la cérémonie ; "" = ce joueur a répondu
opening_master: "userId"              # à qui répondre
pending_butin: false                  # une part attend d'être réclamée
```

L'XP est volontairement séparée de `users` : c'est une donnée de jeu propre à un clan, et ce document est la cible de la vigilance temps réel. `wallet` est une **dénormalisation assumée** — la source de vérité reste le document d'objet, mais le roster affiche l'argent de chaque membre et cette collection est déjà listée pour le construire. La contrepartie est une règle stricte : **toute écriture qui bouge une bourse pose les deux valeurs dans le même `batchWrite`**.

**`clans_items/{clanId}/items/{itemId}`** — un document ne porte que le **fait** ; l'apparence et le comportement (image, libellé, taille de tuile, options de menu, dépôts acceptés, famille) sont déclarés dans le catalogue de types du layer `items-base`. Champs : `type`, `owner` (userId | clanId | sentinelle), `quantity` (le **contenu** d'un contenant, jamais un nombre d'exemplaires), `cost` (valeur de butin de **cet** objet — pas de nominal par type, un second endroit à tenir d'accord ne servirait qu'à diverger), `name`, `title_idx`.

Trois sentinelles d'`owner` : `"butin"` (l'objet est **dans** le coffre, plus personne ne le voit), `"opening"` (distribué mais pas encore réclamé) — aucune ne correspond à un userId ni à un clanId, le filtre d'affichage les écarte donc tout seul.

Quatre documents à identifiant **fixe ou dérivé**, tous idempotents : **`butin`** (le coffre), **`wallet`** (le portefeuille du clan, dont la quantité ne fait que monter par le chemin de la promesse — une promesse faite à un enfant ne se reprend pas), **`wallet_<userId>`** (la bourse d'un joueur, créée en même temps que lui par une écriture qui ne porte **jamais** `quantity`, donc incapable d'écraser un solde) et **`fairy`** (l'état partagé de la fée : horloge, fenêtre, position, cadeaux, preneur). Les **titres** suivent le même principe (`title_p_<idx>_<userId>`, `title_c_<idx>`) : un rang rejoué réécrit le même document au lieu d'en créer un second.

**`clans_logs/{clanId}/logs/{rev}_{event}_{slug}`** — journal d'audit append-only (section 11).

**`clans_chest_history/{clanId}/history/{docId}`** — une ligne par butin **ouvert** : `amount` (portefeuille), `gold`, `cost` (somme des objets), `players`, `highest` (part du meilleur contributeur, en %). Append-only, jamais purgée, et **elle ne porte que des agrégats chiffrés** — jamais un nom d'objet ni un identifiant de joueur : le contenu du coffre reste une surprise, et c'est pour cela qu'elle est une table à part.

> ⚠️ **Personne ne l'écrit encore.** Ce qui existe n'en est que le **lecteur** : la moyenne des 20 dernières lignes situe un dépôt et choisit le ton de la notification. Table vide = aucun verdict, l'annonce part nue. La cérémonie d'ouverture, qui devait l'alimenter, est livrée et ne le fait pas — c'est le principal reliquat du chantier butin (section 22).

**`clans_store/{clanId}`** — la **projection** métier des achats, en lecture seule pour tous : `tier` (l'identifiant produit tel quel, recopié sans traduction — ouvrir un palier au catalogue ne demande aucun redéploiement backend), `state` (`trial|active|canceled|grace|hold|locked|expired`), `products`, `expiry`, `auto_renewing`, `founder`, `credit_months`, `credit_active`/`credit_until` (le mois offert **en cours**, sans lequel un clan crédité mais jamais abonné resterait invisible du balayage), `dunning_phase`, `default_since`, `locked_at`, `purge_due`, `purged_at`, `test`, `last_rtdn_at`. **Pas de jeton d'achat ici** : c'est une donnée personnelle du payeur, elle reste dans la base `store`. Sous-collection `events` : le journal de facturation, append-only et fermé même en création au client — c'est la piste d'audit qui justifie l'état du clan en cas de litige, elle ne vaut rien si un client peut y écrire.

**`clans_pulse/{clanId}`** — l'état de relance : `last_seen` (max des connexions, **calculé au balayage** — aucune écriture client, aucune migration), `adult_stage`/`adult_at`, `boss_at`/`boss_task`, `members.<userId>.{comeback_stage, comeback_at}`, `muted`.

**`beta_signups/{sha256(email)}`** — la liste d'attente saisie sur le site vitrine. Fermée au client en lecture **comme** en écriture (une liste d'e-mails est une donnée personnelle) ; seule la fonction `beta_signup`, qui passe par l'admin SDK, y écrit. Le docId est l'empreinte de l'adresse normalisée : une seule ligne par inscrit, sans écrire l'e-mail dans un chemin de document. Volontairement **absente de la liste de reset** : un reset de développement effacerait des prospects, qui ne sont pas des données de jeu.

### persistance locale

Le dictionnaire Deva (layers `conf-global` et `runtime-<ownerId>`) porte le miroir local des tâches, l'état d'administration des tiroirs, l'avatar, les repères anti-double-fire des célébrations, les drapeaux « vu » du tutoriel et les compteurs de rappels. Le **layer runtime par-owner** est relu au login : les avatars et l'overlay de mort sont donc corrects dès la première frame. Les photos de preuve vivent hors dictionnaire, dans le stockage local de l'appareil, sous un uuid.

---

## 17. assets cloud

Le bucket GCS (lecture publique désactivée) est organisé en **racines de thème**, chacune publiant son propre manifeste : `general/` (ce qui ne dépend d'aucun thème — configs, prompts, layers de structure, catalogue de la boutique, catalogue de la fée) et `donjon/` (la saveur — images, sons, musiques, vidéos, layers de thème et de traductions). Le client déclare la liste des racines et les fusionne en cascade : la conf demande des chemins **nus**, c'est la liste qui décide du thème qui les fournit, et un thème non déclaré n'est jamais téléchargé.

Le téléchargement passe par `dvcloudassets` (cache local 30 jours, 6 fichiers en parallèle sur la passe paresseuse), avec des **vagues de priorité** déclarées dans un layer (donc modifiables sans release) : `vital` (bloquant — illustrations d'intro, vidéo de la langue active), `critical` (prompts, musique d'ambiance, son de l'animation « burn », fonds de splash), puis les vagues suivantes jusqu'à `lazy`. Les vidéos des autres langues sont blacklistées. La résolution nom → fichier réel passe par une **table de pointeurs** côté backend, ce qui permet de versionner un asset sans recompiler le client.

**Musique** : quatre pistes d'ambiance en boucle à partir de la fin de la vidéo d'intro, une playlist dédiée tant que le personnage est mort, un morceau propre à la fée. **Célébrations** : chacune est un **interlude** dont le son et la vibration démarrent une demi-seconde avant le visuel.

La frontière est nette : **`config.yml` déclare que les six interludes existent** (identifiant, DvSplash où poser leur texte, actions de fin) ; **le thème déclare ce qu'ils SONT** — la scène dvflame, les partitions de vibration, les fichiers sons, les playlists, et le mariage des trois. Un autre univers réécrit toutes les animations à son goût sans toucher une ligne de conf ni de Dart. Les identifiants de scène sont le seul contrat.

**Images** : sous-répertoires par gabarit (`big/`, `medium/`, `small/`, `splashs/`), le builder redimensionnant selon la règle du répertoire. Chaque feuille de tâche a son monstre `medium/dt_t_{id}.png`. **Police** : MedievalSharp (OFL), bundlée.

### layers

| layer | racine | rôle |
|---|---|---|
| `assets-global` | general | vagues de priorité + catalogue des thèmes |
| `tasks-base-global` | general | 20 domaines, 151 tâches (structure) |
| `items-base-global` | general | familles et types d'objets |
| `store-base-global` | general | seuil de relance de conversion + scénarios du banc |
| `store-catalog-global` | general | **généré** par le builder depuis `store.catalog` |
| `fairy-base-global` | general | cadence et catalogue des cadeaux de la fée |
| `decisiontree-donjon-global` | donjon | traductions des tâches, gages, titres |
| `theme-donjon-global` | donjon | thème par défaut (visuels, scènes, sons, libellés) |
| `theme-pirate` | donjon | thème alternatif minimal (preuve de concept) |

Tous les layers `general/` sont **embarqués dans l'APK** (`onboard`) en plus d'être publiés : le premier lancement dispose déjà de leurs valeurs, et la boutique naît remplie plutôt que d'attendre le bucket sur une grille vide.

> Le `decisiontree.yml` des configs est l'**arbre de questions** ; le layer `decisiontree-donjon-global` est le **contenu** (traductions). Ce ne sont pas des doublons : l'un porte le flux, l'autre les textes. Les questions actuelles restent un brouillon à finaliser avant production.

---

## 18. déploiement

Backend provisionné par Pulumi. L'ordre de build est `backend` puis `client` — le provisioning GCP doit précéder la compilation Flutter qui en consomme les credentials OAuth.

| Module Pulumi | Responsabilité |
|---|---|
| `puproject` | projet GCP `dvddust`, facturation, **contacts essentiels** (canal art. 28 RGPD) |
| `puapis` | activation des APIs (Firestore, Functions, Run, Android Publisher, Pub/Sub, Scheduler…) |
| `pufirebase` | initialisation Firebase, package `com.grisloup.ddust_client` |
| `pufirestore` | bases Firestore, règles de sécurité, index composites, TTL |
| `pustorage` / `puassets` | bucket d'assets et upload de `resources_cloud/`, table de pointeurs |
| `puoauth` + `puoauthcreds` | clients OAuth (desktop, Android ×2, web) |
| `pusvcaccount` | comptes de service `ddust-backend` et `ddust-pulse` |
| `pucloudfunction` | déploiement des Cloud Functions TypeScript |
| `puscheduler` | tâches planifiées (par région) |
| `pumessaging` | infrastructure FCM |
| `pudocuments` | upload des CGU/privacy HTML |
| `puhosting` | site vitrine + page de suppression de compte + rewrites `/api/*` |
| `pusecrets` | secrets applicatifs |
| `puvertexai` | activation Vertex AI et accès aux modèles |
| `pubudget` | surveillance des coûts (Vertex AI 5 €/mois, Cloud Run 8 €/mois, auto-disable), token bucket anti-spike, alertes Telegram |
| `puvirtuallobby` / `pulock` | bases du lobby et des verrous, TTL |
| `pustore` | miroir d'achats, vérification serveur, RTDN, balayage de facturation |
| `pucatalog` | **crée et met à jour le catalogue chez Google** depuis `store.catalog` |

**Deux régions** : `europe-west9` (Paris) et `us-central1`. Chaque région déclarée produit sa **pile complète** — 7 bases préfixées, un bucket d'assets, un bucket de documents et un jeu de Cloud Functions. Le choix du joueur est définitif (CGU) et aucune donnée ne circule d'une région à l'autre. Deux exceptions documentées : le **registre des codes cadeaux** vit dans `eu-store` seulement (un même code doit être réclamable une seule fois), et **Play n'accepte qu'un topic RTDN**, la fonction européenne traite donc aussi les données américaines.

**Cloud Functions propres à la suite** : `count_sessions` (index de nommage des clans, authentifié), `beta_signup` (**volontairement publique** — le visiteur du site n'est pas connecté ; d'où la validation stricte, le champ piège anti-robot et une réponse identique qu'il s'agisse d'une première inscription ou d'une relance, un formulaire public ne devant pas révéler qui est inscrit), `delete_user_data` (suppression logique en cascade, self-delete uniquement), `clan_purge` (dissolution au terme du calendrier de facturation) et `pulse_sweeper` (relances). S'y ajoutent les huit fonctions de modules : `messaging`, `store_verify`, `store_eligibility`, `store_grant`, `store_claim`, `store_mint`, `store_revoke`, `store_rtdn`, `store_sweeper`.

**Planification** : balayage de facturation à 5 h (module), purge des clans à 6 h — une heure **après**, pour que le drapeau posé à 5 h soit honoré le matin même plutôt que le lendemain —, relances d'engagement à 17 h UTC. Le bloc de planification est en **deep-merge** avec ce que déclarent les modules : on n'écrase ni la tâche du module, ni son compte de service.

**Deux comptes de service, délibérément séparés.** `ddust-backend` (Firestore + logs) porte les fonctions qui **suppriment des données** ; `ddust-pulse` porte le seul balayage de relance et a besoin, lui, de FCM et de `run.invoker`. Accorder les deux à `backend` élargirait les droits de toutes les autres fonctions : un compte de plus coûte zéro, un compte trop puissant coûte le jour où il sert à autre chose que ce pour quoi on l'a élargi.

**Deux clients OAuth Android** coexistent, même package, empreintes différentes : Play re-signe l'AAB avec **sa** clé, le certificat de l'app installée depuis le Store n'est donc pas celui du keystore local. Google résout le bon client côté serveur d'après le certificat réel de l'APK — l'app n'envoie jamais de `client_id` Android. L'empreinte de production a été **relevée sur l'APK réellement distribué** et non lue en console, qui donnait une autre valeur ne correspondant à aucune installation.

**Reset de développement** : `build.yml` énumère explicitement chaque base et chaque collection à purger, par région, avec les raisons. Trois pièges y sont documentés — un `clans_pulse` oublié ferait travailler le balayeur sur des clans morts ; un `clans_store` oublié ressusciterait un état payant sur des données de jeu vides ; et l'annuaire Firebase Auth non purgé ferait tomber le prochain onboarding sur un conflit de compte alors que Firestore est vide. Les buckets d'assets sont **neutralisés** de ce reset : ils ne portent aucune donnée de joueur, et les vider sans enchaîner un build laisserait l'app installée incapable de charger ses assets.

---

## 19. aspects légaux

### documents

`legal/documents/` contient un fichier HTML par tuple `{eu|us}-{a|k}-{fr|en|es}-{cgu|privacy}-vN.html`. `pudocuments` les uploade et ne sert que le `max` de chaque tuple ; `dvdocuments` sélectionne selon `(region, legal_state, lang)`. La version mineure (`k`) est rédigée dans un langage accessible ; la version adulte inclut les mentions de responsabilité parentale.

Seules les **CGU** passent par le flux d'acceptation. La **politique de confidentialité** n'est pas un document acceptable : elle informe, elle n'engage pas — elle est consultable par l'option « Mes données » du kebab Personnage, dans l'état légal de la session (un mineur voit donc la version enfant).

L'acceptation est tracée dans `steps.cgu` (timestamp + device) **et** dans la base `documents` (preuve de consentement horodatée, écrite au flush avec l'horodatage réel de l'acceptation).

> Les documents restent des **brouillons de test** à valider juridiquement avant production. Toute reprise de leur fond impose de publier de **nouvelles versions**, ce qui repose les CGU à tous les joueurs au lancement suivant — vérifier alors que le routeur ramène bien un joueur déjà enrôlé au dashboard. Ne pas oublier les renvois croisés versionnés (CGU↔privacy, `k`→`a`) et les liens en dur du site.

### consentement parental

Il n'existe **plus de document de consentement dédié** : l'engagement est porté par la **CGU unique** acceptée par l'admin adulte, et il est **rappelé au moment de l'acte** sur trois écrans — invitation d'un membre, création d'un profil de joueur, acceptation d'une adhésion.

Cet engagement est **conditionnel** : le chef déclare être le responsable légal du mineur qu'il fait entrer, *ou* agir avec l'accord de ce responsable lorsque le mineur appartient déjà à un autre clan. La responsabilité reste attachée au **clan d'origine** (`original_clan`, gelé sur le premier clan) — rejoindre un second clan ne la transfère pas, seuls les admins du clan d'origine peuvent déclarer le joueur majeur, et la dissolution de ce clan entraîne la suppression du profil du mineur (cascade backend).

### âge de consentement numérique

Le consentement numérique est l'âge sous lequel un service doit obtenir un consentement parental — **13 ans aux États-Unis (COPPA)** et **plancher de l'article 8 du RGPD** (13 à 16 selon l'État membre ; la France retient 15).

Ddust est **plus strict que ce plancher** : il n'exploite jamais le consentement propre de l'enfant. Tout mineur — jusqu'à 18 ans — passe par le consentement d'un adulte. Ce modèle « tuteur pour tout mineur » englobe le cas des moins de 13 ans sans dépendre du curseur national. Conséquence côté conf : `age_thresholds` ne déclare **qu'un seul seuil opérant, 18 ans**, dans les deux régions. COPPA reste porté par la rédaction des documents `us-*`.

⚠ **Ne jamais supprimer la clé `k` de `age_thresholds`.** Avec `{a: 18}` seul, le défaut bascule sur adulte : un enfant de cinq ans serait classé majeur. `k: 0` est le seul retrait sûr.

### parental gate

Un calcul arithmétique avec compte à rebours de 3 secondes, renouvelé à chaque expiration. Il sert **deux fois** : à confirmer le statut adulte à l'onboarding, et à garder **chaque achat** (section 12). Il répond aux exigences de la politique « Familles » sans collecter la moindre donnée biométrique.

### données collectées

- UID Google (identifiant Firebase opaque) et userId métier ;
- région (EU / US) ;
- distinction mineur / majeur — **calculée, la date de naissance n'est jamais persistée** ;
- données de jeu : XP, PV, gage, avatar, journal d'événements, prénoms **choisis librement** ;
- traces techniques : jeton FCM, version d'app, date de dernière connexion, décalage horaire ;
- adresse e-mail pour la liste d'attente beta, si l'utilisateur la saisit sur le site.

Par décision de design, **les photos de validation ne quittent jamais le téléphone** — pas de Cloud Storage pour les contenus utilisateurs, et la preuve n'est **jamais** visible par l'admin qui juge : seul le joueur peut revoir sa propre photo.

Firebase Auth ne détient ni email, ni nom, ni photo avant l'acceptation des CGU (session anonyme, section 4), et le scope OAuth demandé est **`email` seul** — `profile` (nom et photo Google) n'est demandé à personne, les joueurs étant souvent mineurs. Seule conséquence visible : l'écran de profil affiche l'icône de l'app à la place de la photo Google.

### ia et confidentialité

Trois textes librement saisis — nom de joueur, nom de clan, description de clan — transitent vers Vertex AI pour l'inspiration de nom. Le **conte du butin** élargit ce périmètre à la demande explicite d'un joueur : il transmet aussi le journal du clan (prénoms, descriptions de tâches accomplies, XP totale). Ce sont les mêmes catégories de données, jamais d'identifiant, d'âge, de région ni d'e-mail — mais le volume est sans commune mesure, d'où cette mention séparée. Le traitement a lieu **dans la région du joueur**.

### suppression et conservation

Deux chemins, une même sémantique : **suppression fonctionnelle** (tombstones, `enabled: false`, secrets conservés pour une éventuelle restauration), l'effacement matériel étant une étape distincte et commune aux deux, non encore livrée.

- **à la demande** (`delete_user_data`, option in-app + page web) : self-delete uniquement, en cascade. Le compte est désactivé, ses adhésions tombstonées ; s'il était **chef unique** d'un clan, le clan est dissous, tous ses membres tombstonés, et ceux qui n'ont plus de responsable légal (mineur dont le clan d'origine disparaît) ou plus aucun autre clan actif sont eux-mêmes supprimés — **récursivement**. Le consentement n'est pas effacé mais **clos et daté** : la preuve de ce qui a été accepté doit survivre au compte, c'est toute sa raison d'être, et la politique de confidentialité la conserve 5 ans à ce titre. Une acceptation déjà close par une version plus récente garde **sa** date de fin. Un garde-fou multi-région évite de créer des documents fantômes : la page web interroge chaque région, dont la plupart n'hébergent pas le compte, et sans sortie anticipée les écritures en merge y **créeraient** les documents absents ;
- **au terme du calendrier de facturation** (`clan_purge`, J730) : même cascade, appliquée aux clans dont le balayage a posé le drapeau. Le document de facturation n'est **jamais** supprimé — c'est la piste d'audit qui justifie ce qui vient d'être fait. L'idempotence passe par un horodatage de purge et non par l'effacement du drapeau, dont l'absence relancerait une purge par jour, indéfiniment.

> ⚠️ La cascade est **dupliquée** entre les deux fonctions. Ce n'est pas un choix : chaque Cloud Function est déployée avec son propre `index.ts`, sans bibliothèque partagée. Toute correction de l'une doit être portée dans l'autre — il s'agit d'une suppression irréversible, deux implémentations qui divergeraient seraient un vrai danger.

### conformité Google Play

Analytics désactivé et pas de collecte d'ID publicitaires (politique « Familles »). Suppression de compte autonome (exigée) : page web `hosting/web/delete-account/` **et** option in-app. Les deux permissions à impact console (caméra, notifications) sont déclarées **explicitement** dans le build plutôt que laissées apparaître au gré des plugins.

Le dossier de sous-traitance RGPD — adhésion au DPA Google (CDPA + Firebase DPST), registre art. 30, annexe Data safety — est dans `stores/google/dpa.md`, et les **archives datées** des deux contrats sont produites **par le build** : les contrats d'adhésion de Google ne se signent plus, aucune case « j'accepte » n'existe dans les consoles récentes, et la preuve d'adhésion au titre de l'accountability est l'archive du texte en vigueur. À refaire à chaque version publiée par Google — donc exactement ce qu'une mémoire humaine ne tient pas.

Les déclarations Play Console sont préparées dans `stores/google/playstore.md`, `compte.md` et `publication.md`, et les **feuilles de saisie** (`saisie_compte.md`, `saisie_dpa.md`, `saisie_playstore.md`) sont **rendues au build** depuis le `build.yml` de la suite : c'est ce qu'on ouvre devant le formulaire, plus rien à recouper de tête. Une référence non résolue **fait échouer le build** — un champ vide dans une procédure de saisie, c'est une case remplie de mémoire.

**Le statut de vendeur (DSA)** : se déclarer professionnel fait afficher nom, adresse complète et téléphone sur la fiche Play dans l'EEE — mais seulement à partir du moment où une fiche est publique. Tant que la diffusion reste en piste fermée, rien n'est exposé. C'est pourquoi le bloc `publisher` du `build.yml` **ne déclare aucun layer** : sans `layer.publish`, la section ne descend ni dans l'APK ni dans le bucket que l'app lit sans authentification. En ajouter un exposerait une donnée personnelle dans un APK décompressable.

> ⚠️ restant avant production (non bloquant pour le test fermé) : validation juridique des CGU/privacy, AIPD (mineurs + IA générative = deux critères CNIL), mentions des plateformes d'affiliation si elles sont activées.

---

## 20. hors scope

- **Temps réel généralisé** : pas de listeners d'écran. Les statuts de tâches sont relus à chaque affichage du tiroir, en delta ; deux joueurs peuvent voir un état brièvement divergent. Seules trois vigilances ciblées existent (verdict, doc joueur, fée), plus une par joueur attendu pendant la cérémonie du butin.
- **Stockage cloud de photos** : les preuves restent sur l'appareil.
- **Backend propriétaire** : Firebase et Cloud Functions ponctuelles. Les seuls traitements périodiques sont les trois balayages planifiés — même la dégradation des PV est dérivée côté client.
- **Multi-provider auth** : Google uniquement (OAuth PKCE), après une session anonyme. Pas d'email/password ni d'Apple Sign-In.
- **Génération IA des tâches, gages et butins** : c'est du contenu configuré. L'IA n'écrit que des noms de clan et le conte du butin.
- **Création de domaine par le chef de clan** : la liste des domaines est du contenu de jeu. Un chef crée et retouche des **tâches** dans les domaines existants ; les domaines additionnels s'achètent en packs.
- **Recherche de clan par son nom** : écartée. Elle casse la confidentialité inter-clans, le nom interne n'est pas unique, et un annuaire interrogeable serait un vecteur d'abus pour une app d'enfants. À distance, on rejoint par lien chiffré par PIN.
- **Écran « Mes achats »** : supprimé. Il redisait l'état que la boutique porte déjà ; l'historique se lit au journal du clan, avec le reste de l'histoire de la famille.
- **Gating par fonctionnalité** : le routeur existe mais n'est câblé nulle part — le jeu ne se ferme pour aucun état commercial, sauf les deux portes de la section 12.

---

## 21. philosophie deva

Donjons & Savons est une suite `projects/` avec vision produit propre. Son assemblage révèle plusieurs choix d'intégration non-évidents.

**Un seul module Dart applicatif, découpé en parties.** Tout le métier tient dans `modules/worker`, une classe et 22 extensions `part of`. Chaque écran et widget est défini en conf via le DSL dvorb : le worker ne sait pas comment les écrans sont faits, il répond à des actions nommées et navigue vers des identifiants. Les barèmes de jeu eux-mêmes sont des clés de conf.

**Trois niveaux de configurabilité, et le choix du niveau est une décision.** Ce qui ne change jamais est en Dart ; ce qui se règle est en conf embarquée ; ce qui doit changer **sans release** est dans un layer du bucket — catalogue de tâches, catalogue de la boutique, cadence de la fée, seuil de conversion, scénarios de test. Le critère est simple : *devra-t-on l'ajuster en observant les premières semaines ?* Si oui, une version sur les stores pour déplacer un entier serait absurde.

**dvdocuments comme gate légal** : le module encapsule tout le flow (région, calcul d'âge, parental gate, CGU, acceptation, preuve différée pour l'onboarding anonyme). Le worker ne connaît que deux callbacks.

**dvcloud comme unique couche d'accès** : deep-merge par `updateMask`, vigilances `watch` (push natif Android, polling adaptatif plafonné sur desktop — même API), routage régional transparent, appels de fonctions callable. Les trois sont exploités intensivement.

**dvstore porte le commercial, le worker porte le métier.** Le module constate ce que dit Play ; le worker décide de ce que cela veut dire dans le donjon — journal de clan, bandeau, plafond de membres, écrans. Le contrat tient en deux points d'entrée déclarés en conf : ce qui **paie** (le clan) et qui décide de l'**éligibilité** (le serveur).

**dvmessaging porte de la logique métier** : verdicts à 3 boutons exécutables app fermée (mode restreint `noorb`), messages traduits dans la langue du destinataire (résolution manuelle — pas de token qui résoudrait dans la langue de l'émetteur), regroupement par langue, convention du tap-corps pour une action sans libellé. Le balayage serveur reprend le **même contrat de payload**, jusqu'aux noms d'actions : aucun code client à écrire pour le traiter.

**dvflame, dvinterlude et les scènes déclaratives** : les animations sont entièrement décrites en conf (objets + timeline d'effets) et rejouées par une seule action. Les effets de bord qui doivent tomber **pendant** une scène (retirer le crâne quand le voile blanc est plein, poser le « GAME OVER » quand l'écran est noir, révéler les cadeaux quand la fée est apparue) sont accrochés au hook de fin de l'**acte concerné**, jamais à un délai en dur : si l'animation est retouchée, ils suivent.

**dvtuto et la pédagogie déclarative** : leçons, panneaux, conditions et overrides sont en conf. Le worker n'y touche que pour jouer une leçon manuelle. Le mécanisme de **reminder** (cadence au lieu de « vu ») a permis d'y loger un dispositif qui n'est pas pédagogique du tout — le rappel de recrutement — sans forcer le module.

**Les widgets de collection et le pattern selector** : `DvTiroir`, `DvRoster`, `DvExplorer`, `DvList`, `DvMenu(Button)` descendent d'une classe mère commune ; le métier est injecté par des callbacks nommés — `selector` (quelles options, lesquelles grisées), `sort` (tri métier) — et les données sont poussées par actions. Le tiroir résout lui-même l'option seule quand le menu est désactivé : le même mécanisme sert le tap direct d'aujourd'hui et le menu contextuel de demain.

**Jamais de popup modale.** Tout ce qui ressemblerait à une boîte de dialogue — consentement d'invitation, avertissements de suppression de compte, succès d'un code cadeau, conflit de compte, bandeau d'impayé, bandeau d'impersonation — est un **overlay de widgets déclarés invisibles puis révélés**, appliqué à deux niveaux : mutation du template de conf (pour les pages qui naîtront) et show/hide des pages déjà en pile. Deux règles en découlent : un état **éphémère** (impersonation, impayé, erreur) n'est **jamais** persisté sur disque — un bandeau rouge persisté survivrait à la régularisation et accuserait une famille à jour ; un état **durable** (crâne de mort, avatar) l'est au contraire, pour naître avec la première frame.

**dvtheme et la surcharge par layers** : un thème n'est pas une duplication de conf mais un différentiel. Socle technique des thèmes saisonniers et payants envisagés.

---

## 22. chantiers actifs

La boucle complète « tâche → preuve → verdict croisé → XP → niveau → titre → célébration » tourne de bout en bout, avec sa méta (PV, mort, gage, guérison, coup de pouce, boss, journal, titres-objets, coffre et cérémonie d'ouverture, fée), son administration (chefs, révocation, passage à l'âge adulte, joueur sans compte, prise de place, édition et création de tâches), son onboarding anonyme, son tutoriel, son socle commercial complet et son dispositif de relance. Les chantiers ouverts, par ordre de valeur (`deva/roadmap.md`, livrables `ddust/beta`, `ddust/mvp`, `ddust/defis`, `ddust/loots`, `ddust/minijeux`, `ddust/classes`, `ddust/themes`, `ddust/packs`) :

- **Butin** — l'**écriture de `clans_chest_history`** reste à faire : la table existe, elle est déjà lue (comparaison à la moyenne des 20 derniers butins), et la cérémonie ne l'alimente pas. Elle prendra le docId à l'idiome de `clans_logs` et calculera son effectif avec le filtre standard des agrégats.
- **Relances** — sortir `pulse_sweeper` du mode simulation après plusieurs passes jugées crédibles ; le découpage de la passe par heure locale réelle (le décalage horaire est déjà collecté, il n'y aura pas de reprise de données).
- **Statuts de joueur** — le mode adulte sans XP (jouer sans peser sur le jeu des enfants) reste à faire ; hors-ligne, sans-téléphone et prise de place sont livrés.
- **Préférences et IA** — toggle IA global, avec propositions toutes faites en remplacement quand l'IA est coupée.
- **Économie de jeu** (`ddust/loots`) — le plus gros volume : or, boutique à reset hebdomadaire, loot, quêtes, potions, objets, classes, faveurs, succès, saisons, et les **packs de domaines**. C'est aussi ce qui réveillera la célébration `giftgold`, déjà câblée et dormante.
- **Thèmes** (`ddust/themes`) — packs cosmétiques à 5,99 €, contenu YAML + assets, sur le socle de layers déjà éprouvé par `theme-pirate`.
- **Multitenancy** — changement de clan, clans multiples, facturation multi-clan.
- **Monétisation** — parrainage, produits à l'unité au catalogue (`pucatalog` devra être étendu aux in-app products), choix fin de l'offre et du base plan à l'achat.
- **Finitions onboarding** — écran de demande d'entrée à remplacer, nom du clan dans la bannière d'invitation, finalisation des questions du decisiontree.
- **Légal et production** — validation juridique des CGU/privacy, AIPD, ouverture effective de la région US.

État d'avancement détaillé : `progress.md`. Stratégie et modèle de revenus : `strategie.md`, `revenus.md`.
