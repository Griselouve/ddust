<!-- revu: 20260808 -->
# donjons & savons
*transformez les corvées en une aventure épique familiale*

---

## table des matières

1. [vision](#1-vision)
2. [utilisateurs cibles](#2-utilisateurs-cibles)
3. [architecture](#3-architecture)
4. [flux principaux](#4-flux-principaux)
5. [mécanique sécurité des clans](#5-mécanique-sécurité-des-clans)
6. [mécanique ia inspire](#6-mécanique-ia-inspire)
7. [mécanique combat et tâches](#7-mécanique-combat-et-tâches)
8. [mécanique progression (xp, niveaux, titres, butin)](#8-mécanique-progression-xp-niveaux-titres-butin)
9. [mécanique pv, mort et guérison](#9-mécanique-pv-mort-et-guérison)
10. [mécanique journal de clan](#10-mécanique-journal-de-clan)
11. [modèle de données](#11-modèle-de-données)
12. [assets cloud](#12-assets-cloud)
13. [déploiement](#13-déploiement)
14. [aspects légaux](#14-aspects-légaux)
15. [hors scope](#15-hors-scope)
16. [philosophie deva](#16-philosophie-deva)
17. [chantiers actifs](#17-chantiers-actifs)

---

## 1. vision

### problème

Les tâches ménagères sont une source permanente de friction dans les familles. Demander à un enfant de ranger sa chambre déclenche systématiquement rappels, négociations, tensions. Les parents gèrent des comportements, pas une maison.

### solution

Donjons & Savons transforme les corvées en monstres à abattre dans un RPG familial. Chaque tâche accomplie rapporte de l'expérience au joueur et à son clan. Quand le clan monte de niveau, la famille ouvre un butin — une vraie récompense, décidée à l'avance par les parents. Le jeu ne simule pas la récompense : il structure le contrat familial.

La famille est le clan. Les corvées sont les monstres. Le butin est la promesse tenue.

### positionnement

Application mobile B2C familiale, Android en cible principale. Prototype actif en développement, pas encore en store. **Monétisation tranchée** : abonnement par clan, cinq paliers indexés sur le nombre de joueurs (1,99 € à 7,99 €/mois), essai gratuit de 14 jours — l'app se lance payante. Développée en indépendant.

---

## 2. utilisateurs cibles

### adultes (parents / admins)

Nécessairement majeurs — vérification au premier lancement par parental gate mathématique. Le rôle admin (liste `clans.admins`) est effectif. Un admin peut :

- créer un clan (bloqué pour les mineurs) et accepter les demandes d'adhésion, y compris de mineurs (le consentement parental est couvert par la CGU unique acceptée au signup, plus de document `consent_clan` dédié) ;
- juger les tâches en validation : trois verdicts (accepté / partiel / refusé), depuis l'app ou directement depuis les boutons de la notification, app fermée comprise ;
- **promouvoir un membre chef** (`promote_chief` : ajout à `clans.admins` + miroir `is_admin` sur `clans_players`) ou le **rétrograder** (`nomore_chief`) — jamais le fondateur (`clans.founder`, admin à vie) ;
- **déclarer un mineur majeur** (`promote_adult`, réservé à un admin du clan **d'origine** du joueur : `legal_state` passe de `k` à `t`, voir plus bas) ;
- **recommander une tâche « boss »** (`adm_recommend`) : notification au clan et XP boostée pour le prochain qui la valide, ou **retirer la recommandation** (`adm_unrecommend`) — section 7 ;
- **libérer une tâche tenue par un joueur** (`adm_release`, « Laisser tomber ») : elle redevient disponible pour tout le clan, comme si personne ne l'avait prise (section 7) ;
- **révoquer un membre** (tombstone `clans_players.enabled=false`) — jamais le fondateur ;
- gérer l'affichage des tiroirs de tâches (`adm_enable`/`adm_disable`/`adm_hide`/`adm_show`) ;
- guérir un joueur mort (rend 3 PV, cooldown 3 jours) et donner un coup de pouce (+50 XP) au joueur le moins avancé (cooldown 3 jours) — via le menu contextuel du roster ;
- consulter le journal narratif de n'importe quel membre, et le journal complet du clan (bouton kebab, section 10) ;
- se ressusciter lui-même s'il est le seul admin du clan (personne d'autre ne peut le soigner).

La validation est croisée : dès que le clan compte deux admins, un admin ne peut plus valider sa propre tâche — elle passe par le flux normal (preuve, notification, verdict d'un autre admin). L'auto-validation immédiate n'existe que pour l'admin solo.

### enfants (joueurs principaux)

Légalement mineurs ou majeurs — "enfant" désigne le rôle dans le clan, pas le statut légal. L'app est conçue pour être jouable sans smartphone propre (gestion du profil par un parent — flux prévu, pas encore implémenté). Un non-admin ne peut ni ouvrir une tâche en validation, ni guérir, ni booster : le menu contextuel du roster ne s'ouvre pas pour lui.

### rôle vs statut légal

`legal_state` vaut `k` (mineur), `t` (transition) ou `a` (adulte) ; il est calculé depuis la date de naissance à l'onboarding et stocké en session, la date de naissance n'étant jamais persistée. Ce statut conditionne :
- la version des CGU affichée et acceptée
- la capacité à créer un clan (`k` et `t` ne peuvent pas)
- la qualification aux clones de tâches `multiple` (`k`, `a` ou `all`, section 7)

L'état `t` (transition) matérialise le **passage à l'âge adulte**. Un admin du clan **d'origine** du joueur (`clanId == original_clan`) le déclare majeur (`promote_adult`), ce qui pose `legal_state = "t"` sur son doc `clans_players`. Tant que le joueur n'a pas accepté les CGU adultes, `t` est **traité comme `k`** en jeu (`worker.dart:3344`). La vigilance temps réel sur son doc (`_playerVigilance`) détecte `t` et impose une **CGU adulte bloquante** : le routing la re-dérive à chaque login (elle survit à un kill de l'app), et l'acceptation écrit `a` dans `users` **et** `clans_players` (`persist_session_legalstate`).

---

## 3. architecture

```
client Flutter (Android, Windows)
  ├─ worker.dart (orchestrateur applicatif, seul code Dart de la suite)
  └─ modules Deva
       dvcore · dvlang · dvsettings · dvorb · dvmarkdown · dvapp · dvtable
       dvcloud · dvcloudassets · dvlayers · dvtheme · dvprompts · dvmessaging
       dventries · dvtaskbar · dvdocuments · dvparentalgate
       dvvideo · dvdecisiontree · dvvertexai · dvlock · dvcamera
       dvvirtuallobby · dvqrcode · dvqrcodereader · dvdeeplink · dvsocialshare
       dvvibrations · dvsound · dvpops · dvsteps · dvsession · dvflame · dvinterlude

backend Pulumi (GCP — europe-west9)
  ├─ Firebase Auth (Google OAuth, PKCE)
  ├─ Firestore (databases : workers, sessions, messaging, secrets, virtuallobby)
  ├─ Cloud Storage (bucket assets : vidéos, configs, prompts, layers, images, musiques)
  ├─ Cloud Functions (TypeScript, callable)
  ├─ Vertex AI (Gemini 2.5 Flash Lite)
  └─ verrous distribués (dvlock / pulock — course de prise de tâche)
```

Le client est assemblé par DvBuilder depuis `client/build.yml`. L'UI est entièrement déclarative : écrans, widgets et interactions sont définis dans `client/config.yml` via le DSL dvorb. Le seul code Dart applicatif est `worker.dart` — l'orchestrateur qui câble les actions des modules entre eux. Les barèmes de jeu (XP, niveaux, PV, decay, butin) sont eux aussi déclaratifs : un bloc `worker:` dans `config.yml` surcharge les valeurs par défaut, lues une fois au démarrage (`_loadTuning`).

Le backend est provisionné par Pulumi via les modules `pu*`. Il n'y a pas de serveur applicatif propriétaire : les Cloud Functions couvrent uniquement les opérations nécessitant une autorisation côté serveur (comptage de sessions, relais FCM de dvmessaging).

Le flux inter-composants suit le même patron partout : un événement UI déclenche une action nommée (`worker.on_xxx`), le worker lit l'état depuis la couche Deva ou Firestore (via dvcloud), met à jour Firestore, puis navigue vers l'écran suivant. La navigation d'onboarding passe par `dvsteps` ; les sauts directs utilisent `DvOrb.navigate_reset`. Deux exceptions temps réel ciblées : une vigilance `dvcloud.watch` sur la tâche en attente de verdict et une sur le doc joueur (détection de montée de niveau) — push Firestore natif sur Android, polling Fibonacci en secondes sur desktop.

---

## 4. flux principaux

### premier démarrage (onboarding complet)

1. L'écran `home` affiche le bouton de connexion Google. `dvcloud.do_login` déclenche l'auth PKCE.
2. À l'authentification, `worker.on_login` cherche un document utilisateur dans `workers/users` pour chaque région configurée (`_findBestSession`). Si aucun n'existe, l'app navigue vers `region_screen`.
3. L'utilisateur choisit sa région (EU) et confirme. `worker.on_region_screen_done` enregistre le step `region_intro` et navigue vers `player_name_screen`.
4. L'utilisateur saisit un nom d'aventurier. À la confirmation, `on_confirm_player_name` écrit `internal.name` et `external.name` (tous deux égaux à la saisie), enregistre le step `name`, puis navigue vers `age_screen`.
5. L'utilisateur entre sa date de naissance. `dvdocuments` calcule le `legal_state` (`k`/`a`). La date de naissance n'est jamais persistée.
6. Si adulte : `dvparentalgate` affiche un calcul mathématique avec compte à rebours de 3 secondes. Une réponse correcte confirme le statut.
7. `dvdocuments` signale sa disponibilité → `worker.on_documents_ready` enregistre les steps `region` et `legal_state` dans Firestore, active le moteur Vertex AI, et navigue vers `ddvideo`.
8. La vidéo d'introduction est lue en plein écran (FR/EN/ES selon la langue active, téléchargée depuis GCS). L'utilisateur peut la passer. À la sortie de la vidéo, la musique d'ambiance démarre en boucle (`dvsound.loop.ambiant`) et l'affichage des CGU est déclenché.
9. `dvdocuments` affiche les CGU correspondant à `(region, legal_state, lang)` — un fichier HTML chargé depuis Cloud Storage. L'utilisateur coche la case et confirme.
10. `on_acceptance_complete` enregistre le step `cgu`, réactive Vertex AI, et navigue vers `new_or_pick_clan`.
11. L'utilisateur crée un clan ou demande à en rejoindre un existant.
12. Après la sélection de clan, `dvdecisiontree` pose une série de questions sur le foyer (équipements, pièces, véhicules, animaux). Les réponses construisent une whitelist/blacklist de tags qui filtrent la liste de tâches par défaut. Les questions sont configurables depuis GCS (`decisiontree.yml`) sans recompilation. Le contenu actuel est un brouillon de test — les questions et tags définitifs sont à retravailler avant production.
13. L'app arrive sur le `dashboard`. À la première arrivée après création ou adhésion, la page est gelée le temps de garantir que le doc clan et les tâches sont chargés (`_ensureClanReady`, boucle bornée à 5 tentatives), puis l'animation de bienvenue est jouée : le nom du clan en surbrillance dans le DvSplash commun et la scène dvflame « burn » (section 8).

### connexions suivantes

`_findBestSession` retrouve le document utilisateur le plus récent parmi toutes les régions configurées (présence du step `region` requise). Si les CGU ont évolué depuis la dernière session, `dvdocuments` les affiche avant de continuer. Sinon, si `steps.clan` est présent, l'app charge les tâches du clan (`_loadClanTasks`) et navigue directement vers `dashboard`. Sinon elle reprend à la sélection de clan.

`_findPartialSession` couvre le cas où l'utilisateur a confirmé sa région (step `region_intro` présent) mais n'a pas complété l'écran d'âge (step `region` absent) : l'app reprend à `age_screen` plutôt que de repartir de zéro.

Si une preuve était en attente de verdict au moment où l'app a été tuée, `on_login` relit `active_proof` et relance la vigilance de validation — verdict rendu entre-temps compris (première lecture immédiate avant l'installation du watch).

### création d'un clan

Réservée aux adultes (`legal_state == "a"`). Le bouton "créer" est désactivé et grisé pour les mineurs.

1. L'utilisateur saisit un nom (obligatoire) et une description (facultative). Le bouton "Confirmer" s'active dès que le nom est non vide.
2. "Inspire moi" envoie le nom et la description saisis à Vertex AI via le prompt `inspire_clan` (section 6). "Rejouer" restaure les saisies originales avant de relancer.
3. À la confirmation, le worker génère deux UUIDs (`clanId`, `clanSecret`) et appelle la Cloud Function `count_sessions` pour obtenir un index.
4. Le nom externe est construit : `"${aiName}-${region}-${sessionCount}"`. Ce nom est le seul visible **hors du clan sans action du joueur** — l'app ne l'expose jamais, par exemple, à un autre clan qui chercherait à identifier le vôtre. Cette règle protège la confidentialité inter-clans ; elle ne s'applique pas à un **partage volontaire** : le conte du butin (section 10) affiche et transmet à l'IA le nom interne, celui que la famille a choisi — c'est délibérément celui-là qu'un parent reconnaît et veut voir dans ce qu'il partage.
5. Deux documents sont écrits dans Firestore : `users/{uid}` (ajout du `clanId` et du `clanSecret` dans `clans`) et `clans/{clanId}` (avec `ownerId = clanSecret`, voir section 5). Un log `ClanCreated` est écrit dans le journal du clan.
6. Navigation vers `decisiontree`. Les réponses sont persistées dans `clans_tasks` ; les tâches `multiple` activées sont mémorisées dans `clans.enabled_multiple` et le créateur écrit ses propres clones (section 7).

### rejoindre un clan — flux QR (candidat)

1. L'utilisateur appuie sur "Rejoindre un clan" → écran `join_clan` avec deux options.
2. **Via scan QR** : `qrcodereader.scan` ouvre la caméra. Le QR code encode `ddust://invite?group_id=…&lobby_id=…`. Le worker appelle `on_invite_clan_link` avec les paramètres.
3. **Via lien partagé** : l'admin partage le lien via `dvsocialshare` ; le candidat le reçoit en deep link (`ddust://invite`). `dvdeeplink` intercepte et dispatch vers `worker.on_invite_clan_link`. Si l'app était fermée (cold start), `on_login` détecte `worker.pending_group_id` après l'auth et navigue vers `accept_invitation_clan`.
4. L'écran `accept_invitation_clan` affiche un bouton de confirmation → `worker.on_accept_invitation_clan` → `virtuallobby.accept_invitation(groupId, lobbyId)`.
5. `dvvirtuallobby` finalise (`_handleClanJoin`) : consomme le secret via `consumeSecret(lobbyId)`, écrit `clans` + `userindexes` dans Firestore, ajoute le candidat dans `clans.players`. L'arrivant écrit son doc membre (`clans_players`) et ses clones de tâches `multiple`, un log `MemberJoined` est tracé, et tous les autres membres reçoivent une notification « nouveau membre » dans leur langue.
6. Pour un candidat MINEUR, tout ceci précède la liaison de son compte Google : son doc membre naît donc **sans `name`** (il ne le saisit qu'après). Deux conséquences, toutes deux gérées : le roster des autres membres affiche le libellé neutre `member_unnamed` et non son identifiant technique (`_memberLabel`, à n'utiliser que pour l'affichage — le journal, append-only, garde l'id brut) ; et `_handleClanJoin` **persiste les layers** (`Deva.instance.store()`) avant d'envoyer sur l'écran de liaison, sans quoi `worker.session.clan_done` et `worker.pending_clan_welcome` seraient perdus — `_setupUserOwner` → `loadOwnerConfig` relit `runtime-<ownerId>.yml` **depuis le disque** et vide le store, et le mineur repartait alors sur `new_or_pick_clan` après avoir saisi son nom, sans cérémonie de bienvenue. Par sécurité, `on_confirm_player_name` route désormais sur l'enrôlement PERSISTÉ (`steps.clan.clanId`), le drapeau RAM ne servant plus que de repli.

### rejoindre un clan — flux demande (requester)

1. L'utilisateur appuie sur "Envoyer une demande" → `dvvirtuallobby.createSubmission()` crée une submission `pending`. Le lobby_id est stocké et partagé via `dvsocialshare` sous forme de lien `ddust://request?lobby_id=…`.
2. `dvvirtuallobby.watchSubmission` démarre (polling 3s).
3. L'admin reçoit le lien, `dvdeeplink` dispatch vers `worker.on_request_link` → l'admin voit `accept_request_clan`.
4. L'admin confirme → `worker.on_accept_request_clan` : lit son `clanId` en session, appelle `dvvirtuallobby.createManagement(groupId)` puis `.accept(groupId, lobbyId)`.
5. Si `on_consent_required` est déclenché (candidat mineur) : `worker.on_consent_required_clan` reprend **directement** `virtuallobby.continue_workflow` — plus de document `consent_clan` intermédiaire, le consentement parental étant couvert par la CGU unique acceptée au signup.
6. Le candidat reçoit `on_status_changed` (status `accepted`) → `worker.on_submission_status_changed` → `_handleClanJoin`.

### invitation — flux admin (créateur QR)

1. L'admin appuie sur "Inviter un membre" → `worker.on_invite_clan`. **Le lobby n'est pas créé tout de suite** : recruter, c'est potentiellement faire entrer un enfant dans son clan, donc l'overlay de consentement (`clan_page/invite_*`, mise en page `commons/parental_consent` + lien vers les CGU adulte) est révélé d'abord — le RGPD art. 8 veut un consentement éclairé **au moment de l'acte**, pas seulement à l'installation. `worker.on_confirm_invite_consent` enchaîne alors sur `virtuallobby.create_management(groupId)` ; `on_cancel_invite_consent` referme sans rien écrire. Même garde pour l'invitation à distance (`on_invite_clan_remote`), qui ne fait que mémoriser le mode `pin`.
   Le libellé est `invite_consent_notice`, et **pas** la mention inconditionnelle `parental_consent_notice` : à l'instant de l'invitation on ignore qui viendra. Les trois cas sont donc énoncés — un adulte ; un enfant dont le chef est le responsable légal ; un enfant **déjà membre d'un clan**, invité avec l'accord de son responsable. Ce dernier cas n'est pas théorique : `original_clan` est gelé sur le premier clan du joueur, seuls les admins de ce clan-là peuvent le déclarer majeur, et la cascade backend le supprime quand ce clan est dissous. `parental_consent_notice` ne sert donc plus qu'à `create_player_screen`, où le chef crée l'enfant de toutes pièces et en est forcément le responsable.
2. `on_management_created` reçoit `{group_id, lobby_id}` : navigue vers `invite_clan`, affiche le QR via `DvQrCode` et met à jour `invite_clan/qrcode.shape.content` avec le deep link. Démarre `virtuallobby.watch_management`.
3. L'admin peut aussi partager le lien via `dvsocialshare`.
4. Quand le candidat a finalisé, `on_virtuallobby_accepted` publie le `clanSecret` via `publishSecret(lobbyId, groupId, {clanId, clanSecret})`.

### inviter/rejoindre à distance — lien chiffré par PIN (sans QR)

Même workflow que le QR : on ne remplace QUE le véhicule du couple `{group_id, lobby_id}`. Au lieu d'une image QR (lue par proximité), un lien partagé sur les réseaux sociaux dont ce couple est chiffré par un PIN à 6 chiffres dicté de vive voix. Le PIN remplace la présence physique. `publishSecret`/`consumeSecret` du `clanSecret` sont inchangés.

La crypto est générique et vit dans le module `dvvirtuallobby` (`generatePin`/`sealInvite`/`openInvite` — fonctions pures, token auto-porteur, chiffrement par flux authentifié HMAC-SHA256, `exp` embarqué). Réutilisable par d'autres jeux.

1. **Admin** : kebab Clan → « Inviter à distance » → `worker.on_invite_clan_remote` pose `invite_mode=pin` puis `create_management`. `on_management_created` (branche pin) génère PIN + token (`sealInvite`), affiche le PIN sur `invite_clan_pin` et partage `ddust://invitepin?token=…` via `share.clan_invite_pin`.
2. **Candidat** : ouvre le lien (deeplink `ddust://invitepin` → `worker.on_invite_pin_link`) OU touche « Je n'ai pas le QR code » (`worker.on_no_qr`) pour une saisie manuelle. Écran `enter_invite_pin` : coller le lien (pré-rempli si deeplink) + taper le PIN → `worker.on_confirm_pin` → `openInvite` déchiffre → `accept_invitation` (suite identique au QR).
3. Modèle de menace assumé (app enfants) : un lien intercepté sans le PIN est inexploitable ; le secret étant supprimé à la première lecture, le vrai candidat le consomme avant tout curieux.

> L'ancien « flux demande » (candidat émet `ddust://request`) est **remplacé** par ce flux PIN sur le bouton « Je n'ai pas le QR code ». Le handler d'émission `on_send_request` (mort) a été supprimé ; le reste (route `ddust://request` → `on_request_link`, écran `accept_request_clan`, callback `on_submission_status_changed`) subsiste car encore câblé en conf — à purger si le flux demande est définitivement abandonné.

### boucle de combat (sélection et exécution d'une tâche)

C'est la boucle de jeu fondamentale, accessible depuis le `dashboard`. La taskbar comporte cinq onglets : boutique, clan, **combat**, personnage, inventaire. Combat est le gameplay central ; personnage et clan affichent jauges et roster (sections 8 et 9) ; l'inventaire (« Items ») est ouvert à **tous** les joueurs — chacun y voit ses objets et sa bourse, le coffre du clan restant filtré aux admins (`_pushClanItems`) ; la boutique ne porte plus que les produits à l'unité — son étal est vide au lancement, les **packs de domaines** en seront le premier contenu vendu, la liste des domaines n'étant pas extensible par le chef de clan (sections 7 et 15). Le choix du **palier d'abonnement** n'y vit pas : il a son propre écran (`tiers_page`), qui ne s'ouvre qu'au moment où le clan bute sur la capacité de sa cotisation, ou sur relance d'impayé.

1. L'onglet **combat** affiche un tiroir (`DvTiroir`) listant les domaines de la maison dont `domains.{id}.enabled` est vrai — l'état issu du decisiontree. À l'`on_combat_appear`, le worker rafraîchit les statuts des tâches (`_refreshTaskStatuses`) : les overlays sont relus à chaque affichage, pas synchronisés en continu. Le tiroir trie ses entrées actives d'abord, grisées ensuite (comportement `DvTiroir`, re-tri à chaque rafraîchissement).
2. **Sélection d'un domaine** : chaque domaine ouvre son sous-tiroir `{domaine}_tasks` listant ses feuilles, chacune une vraie tâche prenable. Les 19 domaines de `_taskDomains` (`worker.dart`) sont câblés sur la bibliothèque `tasks-base-global.yml` via deux handlers génériques par préfixe — `seldomain.{domaine}` et `seltask.{taskId}` — donc aucun code spécifique par domaine. Chaque tiroir passe par un `selector` (worker.domain_selector / task_selector) qui ne renvoie pour l'instant que l'option seule (`menu_enabled: false` → le tap exécute directement) : point d'extension prêt pour des menus contextuels sur les tâches. Un joueur mort (0 PV) ne peut ni ouvrir un sous-tiroir ni prendre une tâche (section 9).
3. **Prise de tâche** (`_selectTask`) : le worker lit d'abord le statut autoritaire du doc de tâche. Si la tâche est en `validating`, on bifurque vers le mode revue (admin, voir plus bas) — sans verrou. Sinon il acquiert un verrou `dvlock` sur `"{clanId}_{taskId}"`. Verrou refusé → un autre membre est en train de la prendre, abandon silencieux. Verrou acquis, il revérifie le statut : le verrou (TTL 30 s) ne protège que la course simultanée ; une tâche `assigned`/`validating` reste imprenable via son statut Firestore. Exception : une mortelle `dead` dont la fenêtre est passée (`now ≥ revive`) « ressuscite » et redevient prenable.
4. **Affichage combat** : la tâche prise passe en `assigned`, l'écran affiche son illustration de monstre, ses critères d'acceptance, son badge de difficulté (libellé d'effort + XP réels du moment) et deux boutons — "J'ai vaincu le monstre !" (`on_combat_ok`) et "Retraite !" (`on_combat_cancel`). La persistance Firestore (`_assignTask`) se fait en arrière-plan ; le verrou n'est libéré qu'après confirmation de l'écriture du statut. Si l'écriture échoue, le verrou est conservé jusqu'à expiration du TTL. Le marqueur `_freshlySelected` évite que l'appear immédiat de combat réconcilie avec Firestore avant que l'assignation y soit propagée (sinon la tâche paraîtrait « alive » et serait vidée à tort).
5. **Preuve** : "J'ai vaincu" déclenche la capture photo via `dvcamera` (caméra OS, stockage **local** sous un uuid — jamais de cloud). Trois issues : photo prise → `validating` avec `proof = uuid` ; capture annulée → rien ne change ; caméra indisponible (desktop, permission refusée, module absent) → la tâche part quand même en validation, `proof` vide côté Firestore et sentinelle locale `noproof` (le bouton "Voir ma preuve" reste masqué). Un log `TaskDone` est tracé, et **tous les admins du clan** (sauf le demandeur) reçoivent la notification de demande de validation.
6. **Abandon** : "Retraite !" repasse la tâche en `alive` (`assignee` vidé, `proof` retiré, fenêtre `dead`/`revive` préservée) et revient au tiroir.

**Attente de verdict** : dès la soumission, une vigilance `dvcloud.watch` surveille le doc de tâche (push Firestore natif sur Android ; polling Fibonacci à base 2 s sur desktop). Une première lecture immédiate couvre le verdict déjà rendu (cold start). Dès que le statut quitte `validating`, `_resolveValidation` applique l'issue : refus (`assigned`, toujours à moi) → la preuve locale est abandonnée mais la tâche me reste attribuée, je peux recommencer ; accepté (`dead`/`alive`), repris par un autre ou disparu → `active_task`/`active_proof` sont vidés et l'app revient au dashboard. La notification de verdict (tap sur le corps, `wakeup:true`) déclenche la même résolution sans attendre le watch. Le retour sur l'écran combat réconcilie aussi manuellement (aucune dépendance exclusive au temps réel).

### validation parentale (côté admin)

Une tâche `validating` apparaît dans le tiroir avec un overlay **main** (`hand_image`) pour un admin — cliquable, contrairement aux autres joueurs qui la voient verrouillée avec la flamme. **Validation croisée** : si l'assignee est l'admin lui-même, le tap est un no-op — sa tâche doit être tranchée par un autre admin. Sinon, l'admin entre en **mode revue** (`session.review_task`) : l'écran combat affiche l'illustration, les critères d'acceptance et la difficulté — jamais la preuve photo (elle reste sur l'appareil du joueur) — avec **trois verdicts** (logique commune `_applyVerdict`) :

- **accept** ("Le monstre est vaincu !") — crédite l'XP plein au joueur et au clan, puis fait transiter la tâche : `dead = now`, `revive = now + respawn_h` heures, `status` → `dead` (mortelle) ou `alive` (immortelle).
- **partiel** ("À moitié vaincu…") — crédite la **moitié de l'XP** (répercutée aussi sur le clan et le butin) et pose une tâche à moitié régénérée : `dead = now − respawn_h/2`, `revive = now + respawn_h/2`, `status` toujours `alive` — même une mortelle reste sélectionnable, barre de respawn à ~50 %.
- **reject** ("Raté… essaie encore.") — la tâche repasse en `assigned` (au même joueur), la preuve est purgée, aucun XP. La fenêtre `dead`/`revive` préexistante est préservée.

L'XP est calculée **avant** l'écriture du verdict (la proportionnalité utilise la fenêtre du cycle précédent, que la validation réécrit). Chaque verdict trace un log `TaskValidatedOk/Partial/Ko` (avec l'XP créditée) et notifie l'assignee dans sa langue.

**Verdict depuis la notification** : la notification admin porte trois boutons (Valider / À moitié / Refuser) mappés sur `on_notif_validate_*`, en mode `noorb` : app fermée, le tap relance l'app **sans UI** (mode restreint, seuls les idles `orb` et `lang` sont chargés), attend que le contexte clan de l'admin soit résolu (borné ~10 s), exécute le verdict et s'arrête (`wakeup:false`). **Garde d'idempotence** : le verdict n'est appliqué que si la tâche est encore `validating` — deux admins notifiés peuvent taper, le second sort sans re-créditer d'XP.

**Auto-validation (admin solo uniquement)** : quand l'admin **unique** du clan exécute lui-même une tâche, "J'ai vaincu" saute la capture de preuve et applique immédiatement le verdict accepté (XP plein, logs `TaskDone` + `TaskValidatedOk`, aucune notification). Dès qu'un deuxième admin existe (`_adminCount > 1`), ce raccourci disparaît et l'admin repasse par le flux photo → validating → verdict croisé.

---

## 5. mécanique sécurité des clans

La collection `clans` interdit toute énumération (`allow list: if false`). Pour lire ou modifier un document clan, la règle Firestore vérifie :

```
get(userindexes/{auth.uid}).data.clans[clanId].clanSecret == resource.data.ownerId
```

La règle lit depuis la collection `userindexes` (pas `users`) — un document léger `{clans: {[clanId]: {clanSecret}}}` dédié aux contrôles d'accès, distinct du document utilisateur complet.

Le champ `ownerId` du document clan ne contient pas l'UID Firebase du créateur : il contient le `clanSecret`, un UUID généré aléatoirement à la création. Ce secret est stocké dans `userindexes/{uid}`, accessible uniquement par son propriétaire authentifié. La règle croise les deux documents pour valider l'accès sans jamais exposer d'identité réelle dans le document clan. Même en cas d'accès non anticipé au document d'un clan, l'attaquant ne peut en déduire aucune information sur son créateur.

Le même schéma (`ownerId = clanSecret`) protège les sous-collections `clans_tasks`, `clans_players` et `clans_logs`. Le journal `clans_logs` est en outre **append-only par construction** : la règle n'autorise que `list` (membres du clan) et `create` (porteur du secret) — `update` et `delete` sont refusés à tous. Un log écrit ne peut être ni modifié ni effacé depuis un client.

---

## 6. mécanique ia inspire

L'IA intervient via un bouton "Inspire moi" à la création de clan (`inspire_clan`) et à la saisie du nom de joueur. Usage ponctuel, jamais en streaming, jamais en arrière-plan.

**Prompt cloud** : `prompts_General_V1.yml` est stocké dans GCS et téléchargé au lancement (asset critique, bloquant pour Vertex AI). `dvprompts` expose `get_prompt("inspire_clan")`. Le prompt est la concaténation d'un contexte fixe et d'une tâche avec injection de l'input via `@@@worker.inspire_input@@@` et de la langue via `@@@worker.inspire_lang@@@`.

**Entrée** : `"nom: {nom_saisi}, description: {description_saisie}"`. Seules des chaînes saisies librement par l'utilisateur transitent vers Gemini. Aucun identifiant, âge, région ou email.

**Timeout et repli** : l'appel est borné à 3 secondes. Passé ce délai, un nom/description statique est tiré parmi trois jeux traduits (`inspire_fallback_0..2`) — l'utilisateur n'attend jamais l'IA. Si la réponse IA arrive après coup, elle est mise en cache et servie au prochain "Rejouer" (puis le cache est consommé).

**Rejouer sans dériver** : la saisie originale (nom et description) est capturée au premier appui sur "Inspire moi". "Rejouer" restaure ces valeurs originales avant de relancer, ce qui évite que chaque appui dérive du précédent.

**Parsing de la réponse** : le modèle retourne `NOM: ... / DESCRIPTION: ...`. Le worker parse ligne par ligne et injecte les valeurs dans les champs via `DvOrb.get_shape_by_id`.

**Modèle** : Gemini 2.5 Flash Lite via Vertex AI (europe-west9). Choix dicté par le coût très faible sur un usage très occasionnel et la latence acceptable pour une interaction one-shot.

---

## 7. mécanique combat et tâches

### bibliothèque de tâches

Les tâches ne sont pas hardcodées : elles vivent dans `resources_cloud/layers/tasks-base-global.yml`, un layer chargé en base de la conf (`layers.files`). Le fichier déclare **20 domaines** et **151 tâches**. Chaque tâche porte :

```yaml
salon_01:
  title:      "@@@T:dt_t_salon_01@@@"   # nom du monstre (clé de traduction)
  acceptance: "@@@T:dt_a_salon_01@@@"   # critère de réussite (ce que le parent vérifie)
  dead:       "@@@T:dt_d_salon_01@@@"   # texte de victoire quand le monstre est vaincu
  cancel:     "@@@T:dt_c_salon_01@@@"   # texte affiché en cas de retraite
  domain:     salon
  effort:     3                          # difficulté ; XP de base = effort × 10
  type:       immortelle                 # immortelle = respawn ; mortelle = définitive
  respawn_h:  72                         # délai de réapparition/régénération, en heures
  supervision: false                     # la validation exige-t-elle une preuve photo ?
  multiple:   k                          # optionnel : clone par joueur (k|a|all, section ci-dessous)
  skip_if_blacklisted: []                # tags qui retirent la tâche du foyer
  keep_if_whitelisted: []                # tags qui la conservent malgré un blacklist
  enabled:    true
```

Le contenu textuel est porté par un **layer de contenu séparé**, `decisiontree-donjon-global.yml`, chargé sous le thème `theme-donjon`. Les clés `dt_t_`, `dt_a_`, `dt_d_`, `dt_c_` y sont traduites par langue. La structure et le contenu sont versionnables indépendamment.

### filtrage par le foyer

À l'issue du decisiontree, chaque réponse produit des tags (`tag_possede_jardin`, `tag_sans_machine_laver`…). Une tâche est retenue ou écartée selon `skip_if_blacklisted` / `keep_if_whitelisted`. Le résultat est persisté dans les sous-collections `clans_tasks` du clan : seules les tâches pertinentes pour ce foyer y figurent avec `enabled: true`. Les tâches `multiple` activées sont en plus listées dans `clans.enabled_multiple`.

### cycle de vie d'une tâche

Une tâche transite par quatre états, persistés dans `clans_tasks/{clanId}/tasks/{taskId}.status` et reflétés dans un miroir local (`tasks.{taskId}.status`) :

- **`alive`** — disponible. État initial, état de retour après une retraite, état d'une immortelle validée (et d'une mortelle jugée « partiel »).
- **`assigned`** — un membre l'a prise (`assignee = userId`). Imprenable. Aussi l'état de retour après un verdict de rejet.
- **`validating`** — preuve soumise. Résolue par un admin : accept → `dead`/`alive`, partiel → `alive` à moitié régénérée, reject → `assigned`.
- **`dead`** — tâche mortelle vaincue, indisponible pendant sa fenêtre `dead → revive`. Passé `revive`, elle redevient prenable (résurrection constatée à la sélection).

**Rendu dans le tiroir** — le statut de rendu est dérivé du statut réel et de la fenêtre de régénération, et poussé aux tiroirs à chaque rafraîchissement :

| overlay | condition | comportement |
|---|---|---|
| flamme | `assigned`, ou `validating` pour un non-admin | grisée, verrouillée |
| main | `validating` vu par un admin | cliquable → mode revue |
| crâne + barre | mortelle `dead`, tant que `now < revive` | verrouillée, barre de respawn |
| pansement + barre | immortelle `alive` en régénération (`now < revive`) | prenable, XP réduite |
| flamme « busy » | icône d'un domaine dont une feuille est active | domaine reste cliquable |

Le verrou `dvlock` (TTL 30 s) ne couvre que la course simultanée ; au-delà, le statut Firestore garantit l'unicité (section 4).

### tâches multiple (une instance par joueur)

Certaines corvées sont **personnelles** : faire son lit, ranger *sa* chambre. En faire une tâche partagée aurait un effet pervers — la corvée de chacun deviendrait une course au premier arrivé. Une tâche `multiple` est **clonée en une instance par joueur qualifié**, chacun avec son propre état et son propre XP.

Le comportement est **piloté par la conf** : `tasks.<id>.multiple` ou, plus large, `domains.<d>.multiple` (un domaine multiple clone toutes ses tâches). La valeur `k`/`a`/`all` est comparée au `legal_state` du joueur (`_qualifiesForMultiple`). Exemple actuel : `chambre_enfant` en `k`, `vehicules` en `a`. Les clones sont créés à l'enrôlement : chaque membre écrit **ses propres clones** (il connaît son nom et son statut légal) pour les bases listées dans `clans.enabled_multiple`.

L'identifiant de clone est `"{baseId}__{userId}"` ; les baseId ne contiennent jamais de double underscore, donc `_originalOf` retrouve l'original de façon synchrone. Le doc de clone porte des champs d'identité persistés (`original`, `owner`, `owner_name`, `label`, `domain`) ; le réglage (`effort`, `type`, `respawn_h`) est résolu depuis la couche tasks-base de l'original, si bien que le calcul d'XP et les verdicts fonctionnent tels quels avec un id de clone. Dans le tiroir, un domaine multiple se déplie en une entrée par membre (`seldomain.{domaine}__{owner}`) ; une tâche multiple isolée liste tous les clones avec le prénom du propriétaire.

### édition d'une tâche (admin)

Un admin peut retoucher une tâche via l'écran « Modifier la tâche » (`rename_task`, ouvert par `adm_edit`). Quatre champs éditables : le nom, la description, l'**effort** (picklist 1-8, libellé « Normal - 20 XP » = effort × `xp_per_effort`) et le **respawn_h** (picklist de paliers, « Revive in 72h »). L'écriture est **partielle** : seuls les champs réellement modifiés sont écrits sur le doc de tâche puis miroités dans la conf (`worker.dart:2256-2322`) ; si rien n'a changé, l'action ne fait rien. La propagation aux clones `multiple` est gratuite (surcharge générique de `_loadClanTasks`).

La **création** d'une tâche neuve dans un domaine existant se fait par la tuile « + » du mode admin (`adm_add_task` → `rename_task` en mode création → `_createNewTask`) : nouveau doc `clans_tasks/{clanId}/tasks/{domaine}_{micros}` marqué `user_created` (donc exempté du réconciliateur), image `nounours` par défaut ensuite éditable, et tuile injectée dans le tiroir du domaine via le canal `dvtiroir.update_additions`.

En revanche, un admin **ne crée pas de domaine**. La liste des domaines est du contenu de jeu, et les domaines additionnels seront vendus en **packs** (boutique, section 17) : la grille des domaines refuse donc la tuile « + » en conf (`combat/tiroir` → `extras_enabled: false`, clé `DvTiroir` qui écarte les icônes injectées globales), et `adm_add_task` conserve un garde-fou côté code. L'exemption `user_created` du réconciliateur existe aussi pour la sous-collection `domains` : rien ne l'utilise aujourd'hui, elle attend les packs.

### recommandation de tâche (boss)

Un admin peut ériger une tâche en « boss » (`adm_recommend`, proposé sur une feuille dont le champ `recommended` est vide). L'action pose `recommended = now` (ISO) sur le doc de tâche et pousse une notification `boss_notif` à tout le clan (dans la langue de chacun). Le tiroir affiche alors un **badge XP** sur la tâche (canal `dvtiroir.update_recommended`). Le prochain joueur qui la valide reçoit une **XP boostée** : le multiplicateur décroît avec les heures écoulées depuis la recommandation (`max((3..7) / (1 + h), 1)`). Le bonus profite aussi au **clan**, dont la part se calcule sur l'XP boostée (section 8).

Les bornes de ce multiplicateur étant connues à l'avance, `_bossXpRange` les expose : l'écran de combat annonce la **fourchette** réellement en jeu (« effort — 24-56 XP ») au lieu de l'XP de base, et `_bossPlayerXp` tire dans cette même fourchette au verdict — ce qui est promis est exactement ce qui peut tomber. Plus le joueur tarde, plus la fourchette se resserre vers l'XP de base.

**Le verdict consomme la recommandation.** `_writeVerdict` efface `recommended` dans la même écriture que l'acceptation (partielle comprise), sur l'appareil de l'admin qui tranche — c'est le seul moment où l'on est sûr que ça arrive. Passer par l'appareil du joueur récompensé était fragile : il fallait qu'il ouvre l'app, et qu'il ait touché de l'XP (une tâche à 0 XP ne pose pas `last_task_boss`), faute de quoi le badge XP restait collé pour tout le clan. `last_task_boss` ne sert donc plus qu'à **choisir l'animation** côté joueur — « coup de pouce » (interlude `giftxp`) plutôt que `victory` — et `_consumeBossReward` se borne à retirer ce drapeau. Un verdict de refus ne crédite rien : `recommended` est préservé, la tâche reste boostée pour la prochaine tentative.

Retour en arrière possible avant le verdict : **« Ne plus recommander »** (`adm_unrecommend`, même icône XP, proposée à la place de « Recommander » dès que `recommended` est posé) efface le champ — le badge disparaît et le bonus ne s'appliquera plus, sans rien laisser d'orphelin puisque `last_task_boss` n'est posé qu'au moment du crédit. Aucune notification n'est envoyée pour un retrait.

Le journal enregistre l'XP **réellement créditée au joueur**, bonus compris (`data.xp`), plus l'XP de base (`data.xp_base`) et un drapeau `data.boss` pour l'audit. Le log est écrit **après** le crédit, jamais avant : écrit avant et sur l'XP de base, il annonçait 20 XP là où le joueur en avait reçu 100. La ligne narrative **dit le bonus** (`log_task_boss` : « … (100 XP, dont +80 de boss !) ») : un total nu ne permettait pas de savoir si la recommandation avait payé, ni de combien.

### libérer une tâche (`adm_release`)

Une tâche prise reste verrouillée sur son porteur jusqu'au verdict ou à sa « Retraite ! ». Si le porteur disparaît (app désinstallée, joueur parti du clan), la tâche resterait orpheline jusqu'au respawn. L'option **« Laisser tomber »** (icône `flee_nobg`, proposée sur une feuille en `assigned` ou `validating`) appelle `_releaseTask` — la même écriture que la retraite du joueur : `assignee` vidé, `status = "alive"`, preuve retirée, **fenêtre de régénération (`dead`/`revive`) préservée** (libérer n'est pas remettre à neuf, contrairement à `adm_revive`). Le porteur se réaligne seul : sa vigilance et son `on_combat_appear` voient `status=alive` / `assignee` vide, vident `active_task` et le ramènent au tiroir. Aucune célébration ne part, toutes étant conditionnées à une hausse d'XP.

### contrôles admin du tiroir

Un admin pilote la visibilité et l'activation de chaque domaine et tâche via quatre options (`adm_enable`, `adm_disable`, `adm_hide`, `adm_show`) portées par deux booléens `visible` / `enabled` sur `domains.<d>` et `tasks.<id>`. Chaque changement est persisté sur **trois surfaces** — conf runtime, layer runtime par-owner, et Firestore — pour survivre au rebuild comme au changement d'appareil ; les clones `{base}__{uid}` héritent de la base. Les bornes de grille sont réglées à `min_columns: 3 / max_columns: 6 / min_rows: 3` sur les 20 tiroirs (`max_columns > 0` active le scroll, barre ambre).

---

## 8. mécanique progression (xp, niveaux, titres, butin)

La validation d'une tâche est le seul générateur d'XP du jeu — plus le coup de pouce admin (section 9).

### xp d'une tâche

Le gain de base est `(xp_per_effort + respawn_h / xp_respawn_div) × effort`, soit **`(10 + respawn_h / 12) × effort`** avec les valeurs de conf par défaut (`worker._taskBaseXp`, seul point de vérité — utilisé par `getTaskXPs` comme par les libellés de la picklist d'édition). La part variable donne du poids aux corvées rares et lourdes : à effort égal, nettoyer le four (720 h) vaut 350 XP quand mettre la table (6 h) en vaut 10. Une tâche sans `respawn_h` retombe sur l'ancien `effort × 10`.

Sur ce socle s'applique la **fenêtre de régénération** `dead → revive` (`revive = dead + respawn_h` heures) :

- avant `dead` : 0 XP ;
- après `revive` : XP de base pleine ;
- entre les deux : XP proportionnelle au temps écoulé, `base × (now − dead) / (revive − dead)`.

Une **immortelle** rapporte d'autant plus qu'on la laisse « repousser » ; une **mortelle** est indisponible jusqu'à `revive` puis rapporte plein. Le verdict « partiel » divise l'XP par deux — répercuté sur le joueur, le clan et le butin.

**Conséquence d'équilibrage.** Jouée en boucle, une tâche plafonne à `112 × base / respawn_h` XP par semaine (112 h = 16 h éveillées × 7 jours) — un plafond indépendant de la cadence de jeu et identique pour une mortelle et une immortelle. Développé, c'est `1120 × effort / respawn_h + 9,3 × effort` : passé 120 h de recharge (`xp_per_effort × xp_respawn_div`) le second terme domine et le rendement ne dépend plus que de l'effort. C'est pourquoi `respawn_h` doit se lire comme **le poids donné à la tâche**, pas comme la fréquence réelle du besoin du foyer. L'outil `build/tools/gen_tasks_balance.py` régénère `tasks_balance.db` pour auditer tout le catalogue sous cet angle.

### niveaux joueur et clan

Le niveau n'est **jamais stocké** : il se dérive de l'XP cumulée via `getNiveauProgres(xp)`. L'XP requise pour atteindre le niveau N suit `XP_N = 50 · (N(N+1)/2 − 1)` (`worker.xp_per_level` = 50) : 100 au niveau 2, 250 au 3, 450 au 4, 700 au 5. Le coût d'un palier croît linéairement — compromis entre le linéaire (les niveaux ne signifient plus rien) et l'exponentiel (mur infranchissable).

Même courbe pour le clan avec un pas ×10 (`worker.clan_xp_factor`) : niveau 2 à 1000 XP, niveau 3 à 2500. Le crédit d'XP au clan est **divisé par le nombre de membres** (`share = ceil(xp / count)`) : le palier de clan récompense l'effort collectif, pas la taille du foyer. L'XP partagée est celle **réellement gagnée par le joueur, bonus « boss » d'une tâche recommandée compris** — le clan touche toujours une fraction de ce que le joueur a touché, jamais une base amputée. Le diviseur ne compte que les membres **actifs** : les révoqués (`enabled = false`) et les sans-téléphone (`has_device = false`) en sont exclus.

**Plafond d'XP par tâche, indexé sur le niveau.** L'XP gagnée sur UNE tâche est écrêtée à `clans_players.max_xp` (défaut `worker.player_max_xp`, amorçage seul — le champ du doc joueur fait foi ensuite, et peut varier d'un joueur à l'autre) **+ `worker.player_max_xp_per_level` × niveau du joueur** (niveau AVANT le gain). Sans ce bonus, un plafond fixe traite pareil le débutant et le vétéran : trop bas il écrase le bonus « boss » d'une grosse corvée recommandée au niveau 10, trop haut il laisse un niveau 1 rafler d'un coup ce que le barème destine à plusieurs semaines. Indexer le plafond sur le niveau fait du niveau lui-même une récompense (100 + 20/niveau : 120 au niveau 1, 300 au niveau 10). Le badge de combat (`worker._readPlayerMaxXp`, mémorisé par joueur le temps de la session) applique la même formule pour ne jamais promettre plus que ce que le verdict versera.

### titres

Un titre n'est plus une propriété dérivée du niveau : c'est un **item** (première famille du système d'items, section 12). Au niveau 5, puis tous les 5 niveaux (`worker._titleIdxFor`, borné à 19 — 20 titres `player_title_0..19`, idem `clan_title_*` pour le clan), le joueur gagne l'**objet** `titre_perso` de ce rang dans son inventaire (onglet Titres) ; le clan gagne de même un `titre_clan` quand son propre niveau franchit un palier (détecté dans `worker._creditClanXp`, seul endroit qui voit l'xp du clan avant et après un crédit). Porter un titre est un **choix** : l'option « Porter ce titre » du menu de l'item écrit `title_idx` sur `clans_players` (ou `clans`) — et c'est ce champ, jamais le niveau, que les écrans Personnage et Clan lisent pour l'afficher sous le nom. « À la poubelle » **supprime** l'item (pas de rattrapage rétroactif : aucun titre n'est recréé si l'écriture initiale échoue ou si l'objet est jeté). Les titres de clan sont **visibles de tous les membres** (`shared: true` au catalogue) mais **seuls les chefs** peuvent les porter ou les jeter. Un titre ne s'échange pas (`draggable: false`, pas d'option `item_give`) et ne va jamais au coffre du butin.

### montée de niveau : détection, célébration, récompenses

L'XP d'un joueur est créditée **à distance** (sur l'appareil de l'admin qui valide). Une vigilance `dvcloud.watch` sur le doc membre du joueur courant détecte donc la montée **à tout moment, sur n'importe quel écran** (armée au dashboard et à la reprise à froid ; push Firestore natif Android, poll Fibonacci base 3 s desktop). `_checkPlayerLevelUp` compare l'XP fraîche à la dernière XP mémorisée (`worker.player_last_xp`) : amorçage silencieux à la première exécution (pas de fausse célébration au déploiement), mémorisation avant célébration (anti double-fire), lectures transitoires ignorées (l'XP ne décroît jamais).

Au franchissement d'un palier :

0. **Item titre** (si le palier franchit aussi un rang de titre) : l'objet `titre_perso` du rang gagné est écrit dans l'inventaire du joueur (`worker._grantTitleItem`) **avant** l'animation et la notification — si l'un des deux échoue, le titre gagné doit exister tout de même, et il n'y a pas de rattrapage qui le recréerait plus tard.
1. **Animation sur place** : le texte (niveau en surbrillance, titre éventuel) est posé dans le DvSplash commun (`commons/levelup_label`, police MedievalSharp, fondu autonome) injecté par le template `page` sur tout écran à taskbar, puis la scène dvflame **« burn »** est rejouée : l'écran se consume en trois actes (combustion — rideau noir montant + front de flammes ; carbonisation — braises ; effritement — pluie de cendres, l'écran réapparaît par le bas). Aucune navigation : l'écran courant reste affiché. La même mécanique sert à la bienvenue clan.
2. **Notification au clan** : tous les autres membres sont notifiés dans leur langue (le joueur qui monte a l'animation, pas la notif).
3. **Récompenses** : soin complet (`last_task = now`, `damage = 0` → PV pleins, section 9) et don au butin du clan de **100 × nouveau niveau** (plafonné).
4. **Journal** : log `PlayerLeveledUp` (niveau, titre éventuel).

Côté **clan**, `worker._creditClanXp` (crédit d'XP après un verdict accepté) est le seul endroit qui voit l'xp du clan avant et après un gain : un franchissement de palier y est détecté et donne de la même façon l'item `titre_clan` du rang, avec un log `ClanLeveledUp` (niveau, titre) — mais sans animation, ce code tournant sur l'appareil de **l'admin qui valide**, pas celui d'un joueur.

### célébrations : les six interludes

Six scènes `dvinterlude` ponctuent le jeu, toutes déclenchées par **détection** (comparaison à une valeur mémorisée sur le doc joueur), jamais par navigation. Chacune confisque l'écran le temps du spectacle, démarre son et vibration une demi-seconde avant le visuel, puis rend la main (section 12) :

| interlude | déclencheur | rendu |
|---|---|---|
| **burn** | montée de niveau (`_checkPlayerLevelUp`) **et** promotion chef (`_checkChiefPromotion`) | l'écran se consume (flammes → braises → cendres) ; `anim_burn.mp3` |
| **victory** | XP d'une tâche validée (verdict accepté normal) | image `victory_nobg` en fondu + `tatadaa.mp3` |
| **giftxp** | XP créditée à `last_task` inchangé (cadeau de guilde) **et** coup de pouce boss (section 7) | pluie d'XP dorée |
| **giftgold** | hausse du champ `gold` du joueur (`_checkPlayerGoldGift`) | pluie de pièces dorées |
| **heal** | transition mort → vivant (`_evaluateDeath`, résurrection) | croix vertes + voile blanc |
| **gameover** | passage à 0 PV (`_evaluateDeath`) | rideau noir + splash « GAME OVER » |

`giftgold` est déjà câblé mais dormant : **aucune mécanique ne crédite `gold` aujourd'hui** — l'or arrive avec le pack économie (livrable `ddust/eco`). La détection est prête et se déclenchera dès qu'une source d'or existera.

### jauge de butin (`butin_xp`)

Le butin — la grosse récompense familiale — se remplit via une jauge dédiée, distincte du niveau de clan. À chaque crédit d'XP au clan, le même montant (`share`, modulé par `clans.butin_xp_factor`, amorcé par `worker.butin_xp_factor`, défaut 1) est ajouté à `clans.butin_xp`. Deux plafonds distincts s'y appliquent : celui du **cycle** (`worker.butin_max_xp`, 1000 — au-delà, plus aucun gain jusqu'à l'ouverture du coffre) et, en amont, celui d'**un seul crédit** (`clans.max_xp_butin`, amorcé par `worker.butin_gain_max_xp` = 50, **+ `worker.butin_gain_max_xp_per_level` × niveau du clan** — niveau AVANT ce gain) : miroir exact du plafond joueur, il évite qu'une seule corvée recommandée, divisée par peu de membres, ne remplisse la jauge d'un coup dans un jeune clan (70 au niveau 1, 250 au niveau 10). S'y ajoutent les dons fixes des montées de niveau (10 × niveau), soumis au même plafond de crédit — sans quoi ce don isolé rouvrirait le déséquilibre dès le niveau 7. Le butin est prêt à s'ouvrir au plafond du cycle.

Deux compteurs cohabitent sur le doc clan : `xp` (non borné) pilote le niveau et les titres ; `butin_xp` (0 → 1000, destiné à être remis à zéro à l'ouverture) est la jauge d'ouverture. L'écran clan affiche la jauge avec un coffre qui avance sur la barre (coffre « ouvert » au plafond), et le roster affiche la **contribution de chaque joueur au cycle courant** (`xp − last_butin_xp`, normalisée : le meilleur contributeur affiche la progression totale de la jauge, les autres au prorata). `last_butin_xp` est recalé à l'ouverture du butin (voir « cérémonie d'ouverture » ci-dessous), sur le doc clan comme sur chaque doc membre : la jauge repart alors de zéro et le coffre doré s'éteint jusqu'au prochain plafond.

**Notification de dépôt au coffre.** Y déposer un objet — ou y ajouter de l'argent de poche depuis l'écran du coffre — prévient **tout le clan, admins compris** (sauf celui qui dépose : le message est à la 3ᵉ personne), chacun dans sa langue. Le ton s'ajuste : `worker._announceChestDeposit` compare la valeur déposée à la moyenne des 20 derniers butins ouverts (`clans_chest_history`, section 11) — sous `worker.chest_low_pct` (20 %) le dépôt est dérisoire, au-dessus de `worker.chest_high_pct` (180 %) c'est un trésor, entre les deux le message part sans commentaire. Tant qu'aucun butin n'a été ouvert la table est vide : il n'y a rien à comparer, et l'annonce part nue — c'est l'état normal, pas un cas dégradé. La valeur d'un objet est le champ `cost` de son document `clans_items`. Un chef qui **remet** son propre argent de poche au coffre (option `item_to_chest` sur sa bourse) déclenche la même annonce.

**Cérémonie d'ouverture du butin.** Au plafond de la jauge, un coffre doré (`chestok.png`) paraît sur l'écran Clan **des seuls chefs**, entouré d'une aura permanente (scène dvflame `chestaura`, immortelle, halo qui respire + rayons émis dans tous les azimuts) qui ne s'éteint qu'au tap. Le premier chef qui le touche prend un verrou **dvlock** (`butin_open_<clanId>`, TTL 30 min) : il est le **meneur**, les autres n'obtiennent rien. Lui seul voit l'écran de rituel (`butin_open_page`), qui lui demande de réunir le clan, de faire raconter à chacun son aventure, et de sortir la tirelire. Son bouton « Prêt ! Ouvrons le coffre ! » pose `pending_opening` (une date) sur le doc membre de **chaque joueur en ligne** (`enabled != false` **et** `has_device != false`) — sauf lui-même, prêt par construction. La vigilance temps réel de chaque joueur voit le drapeau et ouvre le même écran chez lui, avec le récit de la bataille ; son bouton vide son `pending_opening` et disparaît. Le meneur, lui, suit l'appel sur une `DvList` d'attente — une ligne par joueur, coche verte (`adm_enable.png`) dès qu'il a répondu — alimentée par **une vigilance `dvcloud.watch` par joueur attendu** (le framework écoute des documents, pas des collections). Un tap sur la ligne d'un absent le force prêt, pour qu'un seul retardataire ne gèle pas l'ouverture. Quand plus personne ne manque, l'appareil du meneur relâche le verrou et déclenche la distribution (`_distributeButin`) : le partage, le recalage de `last_butin_xp` (clan **et** membres) et le drapeau `pending_butin` partent dans le même `batchWrite`. La suite est inchangée : chacun réclame sa part sur son propre appareil, puis l'animation.

**Saisie d'une somme (`money_page`).** Écran autonome partagé par les deux sens de circulation de l'argent : la promesse versée au coffre (depuis la ligne de la bourse dans `butin_page`, elle rejoint le brouillon de cet écran) et le retour d'argent de poche vers le coffre (option `item_to_chest`, écriture immédiate en un `batchWrite` des deux portefeuilles). Un `DvNumpad` remplace l'ancienne liste déroulante : **aucun plafond de montant** — on ne connaît pas la monnaie du joueur, et là où une baguette vaut 100 000 un maximum n'aurait aucun sens ; seuls subsistent une borne de 12 chiffres (garde-fou technique) et, pour un retour, le solde réel de la bourse. Le montant vit sur la shape d'affichage, pas dans le worker : `show_ok: false` fait émettre un `submit` à chaque frappe, ce qui permet de normaliser la saisie en direct plutôt que de la raboter en silence au moment de valider.

### indicateurs

Les écrans `personnage` et `clan_page` affichent la même jauge de niveau : barre, remplissage proportionnel, flamme sur la pointe, écusson du niveau, libellé `XP courante / seuil suivant`. `personnage` y ajoute la jauge de PV (cœur qui devient crâne à 0), `clan_page` la jauge de butin (coffre). Tout est recalculé à l'affichage depuis les seules valeurs stockées (`xp`, `pv`, `butin_xp`) ; les dimensions de cadrage sont lues depuis les shapes de `config.yml`, jamais codées en dur. Les écrans personnage et clan naissent « remplis » (géométrie persistée dans le registry de conf) pour éviter le flash au rebuild.

### avatar et nom (écran personnage)

L'écran personnage a un **mode édition** (icône `icon_edit.png`) qui expose deux gestes : renommer le personnage et choisir son avatar. Le choix d'avatar ouvre une grille `DvExplorer` (`avatar_explorer`, filtrée sur les fichiers `icon_XX_P_XX.png`) ; la sélection persiste immédiatement l'icône via le layer runtime **et** écrit `clans_players.avatar` (deep-merge). À l'`on_personnage_appear`, le worker **relit** `clans_players.avatar` depuis Firestore et l'applique (delta only) — l'avatar suit le joueur d'un appareil à l'autre. L'avatar de clan a son miroir (`clan_avatar_explorer` → `clans.avatar`, filtré `icon_XX_C_XX.png`, réservé aux admins). Des avatars par défaut sont posés à la création du joueur et du clan.

---

## 9. mécanique pv, mort et guérison

### pv affichés : tout se dérive, rien ne se planifie

Il n'y a **pas de batch serveur** qui décrémente les PV : la dégradation est calculée à l'affichage, côté client (`_computeDisplayedPv`) — choix d'implémentation (zéro coût serveur), révisable si le besoin d'un constat côté serveur émerge. La formule :

```
pvShown = clamp( pv − floor(jours_depuis(last_task) / decay) − |damage| , 0, pv )
```

- `pv` : PV maximum stockés (init `worker.player_pv` = 10) ;
- `last_task` : date de la dernière tâche terminée par le joueur (posée à chaque envoi en validation ou auto-validation) ;
- `decay` : nombre de jours (fractionnaires — 0.5 = 12 h) d'inactivité par PV perdu, posé sur le doc joueur à sa création (`worker.player_decay`, actuellement 1 jour/PV ; la vision évoquait 3 jours — réglage de conf assumé). `decay ≤ 0` = mort instantanée (garde-fou) ;
- `damage` : dégâts additionnels (retranché en valeur absolue — le champ ne peut jamais soigner). Réservé aux mécaniques futures (attaques de boss…) ; aujourd'hui seul le soin le remet à 0.

Conséquence assumée : la mort n'est « constatée » que lorsqu'un écran calcule les PV — dashboard ou personnage pour soi, roster pour les autres. La lecture du champ `decay` est défensive (`_readDecay`) : elle accepte les nombres natifs, les chaînes, et l'ancienne structure `{doubleValue:…}` laissée par un bug de sérialisation du backend REST dvcloud — auto-réparation sans manipulation console.

### mort : crâne et gage

À 0 PV (`_evaluateDeath`, déclenché au dashboard et sur l'écran personnage) :

1. le statut `dead` et un **gage tiré au hasard** (`gage_01` à `gage_11` — humoristique, non punitif) sont persistés sur le doc joueur (à la transition seulement) ;
2. un **overlay global** s'affiche sur tous les écrans à taskbar : scrim qui avale les taps, crâne, texte du gage suivi de la phrase de soin (`gage_heal` : c'est un admin qui pourra guérir). L'overlay est appliqué par mutation du template de conf (les pages futures naissent avec) + layer runtime persisté (réappliqué dès la première frame au redémarrage) + show/hide des pages déjà en pile ;
3. un joueur mort **ne peut plus ni ouvrir un sous-tiroir ni prendre une tâche** (garde dans `seldomain.*` et `_selectTask`, en plus du scrim).

Le gage relève du contrat familial, comme le butin : rien ne vérifie techniquement son accomplissement — c'est l'admin qui guérit, donc c'est lui qui constate que le gage est fait.

### guérison, coup de pouce, résurrection (menu du roster)

L'écran Clan affiche le **roster** : une tuile par membre (avatar, niveau, PV affichés, nom, **couronne** pour les admins, badge d'activité — main si une tâche est en validation, flamme si une tâche est en cours — et barre de contribution au butin), triées admins d'abord puis ordre alphabétique. Pour un **admin**, un tap sur une tuile ouvre un menu contextuel (`DvMenu`, alimenté par `worker.clan_selector`) ; pour un non-admin ou sur les options non applicables, le menu ne propose rien :

- **Consulter le journal** (`open_player_log`) — toujours proposé à un admin, sur tout joueur y compris lui-même (section 10).
- **Promouvoir chef / Rétrograder** (`promote_chief` / `nomore_chief`) — bascule le membre dans/hors de `clans.admins` (miroir `is_admin` sur son doc `clans_players`, qui réveille sa vigilance). Le **fondateur** (`clans.founder`) ne peut jamais être rétrogradé — il est admin à vie. La promotion joue l'anim « burn » (message `promote_chief_self`) sur l'appareil du promu et notifie le reste du clan ; la rétrogradation est silencieuse.
- **Déclarer majeur** (`promote_adult`) — proposé seulement par un admin du clan **d'origine** du joueur, sur un mineur : pose `legal_state = "t"` (section 2).
- **Révoquer** (`revoke_player`) — pose le tombstone `clans_players.enabled = false` ; jamais sur le fondateur. Un membre révoqué est **ignoré partout** (roster, notifications, diviseur d'XP de clan) et éjecté vers le decisiontree à sa prochaine frame (détecté par sa propre vigilance). Le même tombstone modélise un **départ volontaire**.
- **Guérir** (`revive_player`) — uniquement sur un joueur **mort**, jamais sur soi-même. Rend `worker.heal_pv` = **3 PV** (pas les PV pleins : les futures classes, potions et objets doivent garder de la valeur) en recalant `last_task` pour que la formule de dégradation retombe exactement sur la cible — le champ `damage` n'est pas touché : si `damage` seul maintient le joueur à 0, il reste mort. Si le joueur revit, `status` repasse `alive` et un log `PlayerResurrected` trace le gage accompli. **Cooldown 3 jours par admin** (champ `last_cure` sur son doc `clans_players`) : l'option apparaît grisée pendant le cooldown. Le cooldown est porté par l'acteur, pas par la cible — deux parents peuvent chacun guérir dans la même fenêtre, c'est voulu.
- **Coup de pouce** (`support_player`) — uniquement sur le(s) joueur(s) **au plus petit XP du clan**, jamais sur soi-même : le « coup de main de la guilde » de la vision, pour remotiver le retardataire. **+50 XP au joueur seul** — ni le clan ni le butin ne sont crédités (ce serait détourner le coup de pouce en levier de progression collective). **Cooldown 3 jours par admin** (`last_boost` sur `clans_players`).
- **Payer son tribut** (`pay_tribute`) — l'argent gagné en jeu remis **pour de vrai** au joueur. Proposé sur toutes les tuiles, celle de l'admin comprise (un chef gagne de l'argent comme les autres), grisé sur une bourse vide. Réutilise l'écran de saisie `money_page` (troisième mode, `_moneyPay`), plafonné au solde et **partiel autorisé** — on peut ne verser qu'une partie. L'avertissement nomme le joueur : le jeu ne peut pas constater un versement de la main à la main, c'est le chef qui le déclare. L'écriture retire la somme de `clans_items/wallet_{userId}.quantity` **et** de son miroir `clans_players.wallet` dans un `batchWrite` unique (avec le même recalage de `last_quantity` que le retour au coffre, sinon le prochain butin afficherait un gain négatif), trace un log `TributePaid` et notifie le joueur payé dans sa langue.
- **Résurrection** (bouton sous le gage de l'écran de mort, pas dans le roster) — réservée à l'**admin solo mort** : personne d'autre ne peut le soigner, il se débloque lui-même (soin complet, gage effacé, **sans cooldown** — c'est un déblocage de secours, pas une mécanique de jeu). Un admin non-solo mort n'a pas le bouton : il doit être guéri par un autre admin.

À la montée de niveau, le joueur est soigné complètement (section 8) — c'est la récupération « gratuite » prévue par la vision.

---

## 10. mécanique journal de clan

### clans_logs : l'audit append-only

Chaque événement de jeu significatif écrit un document dans `clans_logs/{clanId}/logs` : `ClanCreated`, `MemberJoined`, `TaskDone` (soumission), `TaskValidatedOk/Partial/Ko` (verdicts, avec l'XP créditée), `PlayerResurrected` (avec le gage accompli), `PlayerLeveledUp` (niveau, titre éventuel), `ClanLeveledUp` (niveau et titre du clan, sans acteur joueur — `adminId` seul). Le docId est construit `<rev>_<event>_<slug>` où `<rev>` est un nombre à 13 chiffres **décroissant** (`9999999999999 − epochSeconds`) : un tri lexicographique croissant remonte les logs les plus récents en tête, sans index. Deux logs dans la même seconde peuvent partager le même `<rev>` (toléré). Le champ `data` porte l'audit structuré (ids et noms lisibles), le champ `slug` un fragment ASCII tronqué. Les règles Firestore rendent le journal inaltérable côté client (section 5).

### écran log : le récit d'un joueur

L'écran `log_page` (`on_log_appear`) reconstitue un récit chronologique depuis `clans_logs`, avec trois points d'entrée : l'option roster « Consulter le journal » (un joueur précis, `open_player_log`), le bouton kebab `DvMenuButton` de l'en-tête **Personnage** (« mon journal », `open_my_log`), et le kebab de l'en-tête **Clan** (« journal du clan complet », `open_clan_log` → drapeau `_logClanWide` : tous les joueurs, pas de filtre `userId`). Hors mode clan-large, les logs sont filtrés par `userId`. Ils sont triés du plus récent au plus ancien, groupés par jour avec un en-tête de date localisé (« Lundi 21 Juin » / « Monday June 21 » / « Lunes 21 de junio »). Chaque événement à rendu narratif produit une ligne :

- tâche validée → la description « accomplie » de la tâche (`dt_d_<base>`) suivie des XP réellement gagnés (bonus « boss » compris) ;
- résurrection → la description de rédemption du gage (`gage_d_<n>`) ;
- montée de niveau → « a atteint le niveau N » (+ titre si franchi).

Les soumissions avant verdict (`TaskDone`) n'apparaissent pas. Les traductions sont résolues **manuellement** (langue courante, repli `fr`) car le token `@@@session.user.name@@@` des descriptions doit être substitué par le nom du joueur **consulté**, pas celui du lecteur. Journal vide → texte `log_empty`.

### partage

Un bouton de partage (`dvsocialshare`, bloc `share.log` de la conf : logo + texte d'intro) publie les **15 événements les plus récents** en texte brut — le récit à l'écran reste intégral. C'est le premier des deux partages de la vision : le journal d'un joueur (implémenté, sans IA) ; le journal narratif du **clan** généré par IA à la montée de niveau reste à faire (section 17).

---

## 11. modèle de données

### database `workers` (Firestore, isolation strict)

**`users/{uid}`** — un document par utilisateur, keyed sur l'UID Firebase.

```yaml
ownerId: "firebase-uid"
userId:  "firebase-uid"
last_clan: "uuid-clan"          # dernier clan actif du joueur
date: "2026-05-21T..."
internal:
  name: "Grog"                  # prénom saisi par le joueur (interne)
external:
  name: "Grog"                  # nom visible des autres (= la saisie)
active_task:  "{clanId}_{taskId}"   # tâche en cours (restaurée par dvsession au redémarrage)
active_proof: "uuid-photo"          # preuve en attente de verdict ("noproof" si sans photo)
first_clan: "uuid-clan"         # premier clan rejoint, gelé (miroir de clans_players.original_clan)
clans:
  "{clanId}":
    date: "..."
    clanSecret: "uuid-secret"   # secret partagé avec le document clan
steps:
  region:      { status: done, date: ..., result: "eu",       device: "..." }
  name:        { status: done, date: ..., result: "Grog" }
  legal_state: { status: done, date: ..., result: "a|k",      device: "..." }
  cgu:         { status: done, date: ..., result: "accepted",  device: "..." }
  clan:        { clanId: "uuid", clanSecret: "uuid-secret", status: done, result: "created|joined", ... }
```

Les `steps` sont le journal d'onboarding ; leur présence conditionne la navigation au login. `active_task`/`active_proof` permettent de reprendre un combat ou une attente de verdict après un kill de l'app.

**`clans/{clanId}`** — un document par clan.

```yaml
clanId:  "uuid"
ownerId: "uuid-secret"           # c'est le clanSecret, PAS le UID du créateur
date:    "..."
players: []
admins:  ["firebase-uid"]        # UID réels stockés ici uniquement, pas dans ownerId
founder: "firebase-uid"          # créateur du clan : admin à vie, jamais rétrogradable
avatar:  "icon_12_C_03.png"      # avatar de clan (édité via clan_avatar_explorer, admins)
xp:       0                      # XP cumulée du clan ; niveau dérivé (section 8)
butin_xp: 0                      # jauge d'ouverture du butin (0→1000, section 8)
title_idx: -1                    # titre de clan PORTÉ (rang de l'item titre_clan appliqué) ; -1 = aucun
enabled_multiple: ["chambre_enfant_01", ...]   # bases de tâches multiple actives (clonage au join)
internal:
  name: "Les Chevaliers du Frigo"
external:
  name: "Éclaireurs-du-Vide-eu-142"    # généré, non-PII, public-safe
description: "..."
```

**`userindexes/{uid}`** — document léger pour les règles Firestore des clans (`{clans: {[clanId]: {clanSecret}}}`). Vit dans la base régionale, comme tout le reste.

**`clans_tasks/{clanId}/tasks/{taskId}`** — l'état d'une tâche pour un clan donné.

```yaml
ownerId:  "uuid-secret"          # clanSecret (règles Firestore)
clanId:   "uuid"
enabled:  true                   # tâche retenue pour ce foyer ?
assignee: "userId"               # membre ayant pris la tâche (vide si alive)
status:   "alive|assigned|validating|dead"
last:     "2026-06-24T..."       # horodatage de la dernière transition
proof:    "uuid-photo"           # présent en validating (vidé à "" ensuite, "" si sans photo)
dead:     "2026-06-24T..."       # instant de validation (début de régénération)
revive:   "2026-06-27T..."       # dead + respawn_h ; XP pleine au-delà (section 8)
domain:   "salon"                # champ d'identité, réinjecté à chaque écriture
# champs d'identité présents uniquement sur un clone de tâche multiple (section 7) :
original:   "salon_01"
owner:      "userId"
owner_name: "Grog"
label:      "@@@T:dt_t_salon_01@@@ - Grog"
```

Les règles Firestore autorisent le `get` unitaire (croisement `clanSecret`) et le `list` aux membres ; le worker maintient un miroir local rempli par `_loadClanTasks`/`_refreshTaskStatuses`. L'écriture `dvcloud` est un **deep-merge** (via `updateMask`) : les champs omis sont préservés, effacer un champ demande de le poser explicitement à `""` — c'est ainsi que `proof` est vidé à la résolution d'un verdict. Les mutations reconstruisent les champs métier et réinjectent les champs d'identité (`_applyIdentityFields`) ; la fenêtre `dead`/`revive` est systématiquement préservée par les écritures qui ne la redéfinissent pas (assignation, retraite, refus) — sinon l'XP d'une immortelle serait remise à plein par une simple prise.

**`clans_tasks/{clanId}/domains/{domainId}`** — l'état d'activation d'un domaine pour le clan (`enabled`, `ownerId = clanSecret`).

**`clans_players/{clanId}/players/{userId}`** — la fiche de jeu d'un joueur dans un clan, créée à l'enrôlement (`_writeClanPlayer`) et mutée par le jeu.

```yaml
name:    "Grog"                  # nom lisible (roster, journal, notifs)
avatar:  "icon_07_P_02.png"      # avatar du joueur (édité via avatar_explorer, cross-device)
xp:      0                       # XP cumulée ; niveau dérivé (jamais stocké)
pv:      10                      # PV maximum (init worker.player_pv)
damage:  0                       # dégâts additionnels (soin → 0 ; réservé aux mécaniques futures)
decay:   1.0                     # jours d'inactivité par PV perdu (copié de worker.player_decay)
last_task: "2026-07-06T..."      # dernière tâche terminée → base de la dégradation temporelle
status:  "alive|dead"            # mort persistée à la transition 0 PV
gage:    "gage_07"               # gage porté (vidé à la résurrection)
last_butin_xp: 0                 # XP au dernier reset de butin → contribution du cycle courant
title_idx: -1                    # titre de personnage PORTÉ (rang de l'item titre_perso appliqué) ; -1 = aucun
wallet:  0                       # MIROIR de clans_items/wallet_{userId}.quantity (cf. ci-dessous)
lang:    "fr"                    # langue du joueur, pour traduire ses notifications
devices: ["fcm-token", ...]      # cibles FCM
legal_state: "k|t|a"             # k mineur · t transition (traité comme k) · a adulte
is_admin: false                  # miroir de clans.admins (réveille la vigilance du membre)
enabled:  true                   # false = tombstone (révoqué / parti) : ignoré partout
original_clan: "uuid-clan"       # clan d'origine (miroir de users.first_clan)
last_boost: "1970-01-01T..."     # cooldown 3 j « coup de pouce », porté par l'ADMIN acteur
last_cure:  "1970-01-01T..."     # cooldown 3 j « guérir », porté par l'ADMIN acteur
last_connected: "2026-07-18T..." # dernière connexion (par connexion)
last_version:   "1.0.0+1"        # version d'app à la dernière connexion
pending_opening: "2026-07-27T..." # date de l'appel du meneur à la cérémonie ; "" = ce joueur a répondu
pending_butin:  false            # une part de butin attend d'être réclamée sur cet appareil
```

L'XP joueur est volontairement séparée du document `users` : c'est une donnée de jeu, propre à un clan, lue et écrite à chaque validation — et le doc membre est la cible de la vigilance temps réel de level-up. Les cooldowns d'admin (`last_boost`/`last_cure`) et le tracking de connexion (`last_connected`/`last_version`) vivent ici aussi, sur le doc membre — pas sur `users` — car ils sont propres à un clan (correctif multi-appareil).

`wallet` est une **dénormalisation assumée** : la source de vérité du solde reste `clans_items/{clanId}/items/wallet_{userId}.quantity`, mais le roster affiche l'argent de chaque membre et `clans_players` est déjà listé pour le construire — sans le miroir, chaque ouverture de l'écran Clan lirait une seconde collection entière. La contrepartie est une règle stricte : **toute écriture qui bouge une bourse pose les deux valeurs dans le même `batchWrite`** (ouverture du butin, retour d'argent au coffre, paiement du tribut). Le champ s'amorce tout seul sur les clans existants : à la première connexion d'un joueur, `_writeClanPlayer` l'initialise depuis le vrai solde (et s'abstient si la lecture échoue, plutôt que d'écrire un 0 sur une bourse pleine).

**`clans_logs/{clanId}/logs/{rev}_{event}_{slug}`** — journal d'audit append-only (section 10) : `event`, `userId`, `adminId`, `task`, `data` (map structurée), `date`, `ownerId = clanSecret`.

**`clans_items/{clanId}/items/{itemId}`** — les objets du clan. Un document ne porte que le **fait** ; tout ce qui relève de l'apparence et du comportement (image, libellé, taille de tuile, options de menu, dépôts acceptés, famille, valeur nominale) est déclaré dans le catalogue de types du layer `items-base` (section 12).

```yaml
ownerId:  "uuid-secret"          # clanSecret (règles Firestore)
type:     "titre_perso"          # clef du catalogue de types
owner:    "userId"               # userId (inventaire d'un joueur) | clanId (au clan, visible des admins/partagé)
                                 # | "butin" (SENTINELLE : l'objet est DANS le coffre, plus personne ne le voit)
quantity: 1                      # CONTENU d'un contenant (doses d'une fiole, argent d'une bourse), jamais un nombre d'exemplaires
title_idx: 0                     # rang du titre porté par CET item (0..19) — absent sur tout autre type
name:     "Écu de Grog"          # nom propre optionnel : l'emporte sur le libellé du type
cost:     7                      # valeur de butin de CET objet (worker._itemCostOf) — absent = 0
last_used: "2026-07-24T..."      # réservé aux mécaniques d'usage
```

`cost` n'a **pas** de nominal par type au catalogue : la valeur d'un objet est un fait de son document, et un second endroit à tenir d'accord ne servirait qu'à diverger.

Deux documents ont un id FIXE, un seul de chaque par clan, créés à la naissance du clan et rattrapés à chaque ouverture de l'écran Items (`_ensureButinDocs`) : **`butin`** (le coffre, `owner = clanId`, épinglé, accepte le dépôt de n'importe quel type) et **`wallet`** (le portefeuille, type `argent_poche`, né `owner = "butin"` avec `quantity = 0` ; par le chemin de la promesse sa quantité ne fait que monter — une promesse faite à un enfant ne se reprend pas ; seul un chef peut y **remettre** le sien, cf. `item_to_chest`).

Un troisième porte un id DÉRIVÉ : **`wallet_<userId>`**, la bourse d'un joueur (type `argent_poche`, `owner` = son userId). Créée en même temps que lui — `_ensurePlayerWallet`, appelée depuis `_writeClanPlayer`, donc par tous les chemins de naissance et rejouée à chaque login — par une écriture partielle qui ne porte JAMAIS `quantity` : elle est ainsi idempotente et ne peut pas écraser un solde. Épinglée en haut à gauche de la grille (`pin: top_left`), elle y montre toujours sa somme, même à 0. La distribution du butin (`_distributeButin`) continue de la créer au besoin, pour les clans d'avant. Champ `last_quantity` : repère du « déjà vu » (le gain montré est `quantity − last_quantity`) — tout retrait doit le recaler, cf. `_depositMoneyToChest` et `_payTribute`. Le solde est **dupliqué** sur le doc membre (`clans_players.wallet`, section 11) pour l'affichage du roster.

Les **titres** (`titre_perso`/`titre_clan`, section 8) suivent le même principe d'id DÉRIVÉ que la bourse — `title_p_<idx>_<userId>` pour un titre de personnage, `title_c_<idx>` pour un titre de clan — écrits par `worker._grantTitleItem` au franchissement d'un palier. Un rang rejoué (deux appareils, une relance) réécrit le même document au lieu d'en créer un second. Ils diffèrent des autres items sur trois points : `draggable: false` et pas d'option `item_give` (un titre ne s'échange pas et ne va jamais au coffre du butin — sinon un joueur pourrait porter un titre qu'il n'a pas gagné) ; **aucun rattrapage rétroactif** (contrairement au coffre/portefeuille, un titre manqué — écriture qui échoue, compte déjà à niveau au déploiement de la fonctionnalité — n'est jamais recréé, seul le palier suivant en redonnera un) ; et « à la poubelle » (`worker.item_trash`) **supprime** le document plutôt que de lui poser une sentinelle, précisément parce qu'aucun rattrapage ne pourrait le ressusciter.

**`clans_chest_history/{clanId}/history/{docId}`** — une ligne par butin **ouvert** : la mémoire chiffrée des récompenses passées du clan.

```yaml
ownerId: "uuid-secret"                # clanSecret (règles Firestore)
clanId:  "uuid"
date:    "2026-07-25T18:04:11.412Z"   # horloge de l'appareil, comme clans_logs
amount:  57                           # valeur du portefeuille à l'ouverture
gold:    0                            # pièces d'or (section 17 : rien ne crédite `gold` aujourd'hui)
cost:    34                           # somme des valeurs des objets contenus dans le coffre
players: 4                            # nombre de joueurs
highest: 46                           # part du meilleur contributeur, en % d'XP (approximatif)
```

**Personne ne l'écrit encore** : c'est la cérémonie d'ouverture du butin (section 17, avec le recalage de `last_butin_xp`) qui l'alimentera. Ce qui existe aujourd'hui n'en est que le **lecteur** : à chaque dépôt dans le coffre, `worker._chestHistoryAvg` moyenne les 20 derniers enregistrements — `amount` si le dépôt est de l'argent, `cost` si c'est un objet — pour situer ce qui vient d'être ajouté et choisir le ton de la notification envoyée au clan (section 8). Table vide = aucun verdict, l'annonce part nue.

La table est **append-only** (`create` seul, ni `update` ni `delete`) et rien ne la purge : elle ne porte donc que des agrégats chiffrés, jamais un nom d'objet ni un identifiant de joueur. Quand la cérémonie sera écrite, elle prendra le docId à l'idiome de `clans_logs` (`rev` décroissant) et calculera `players`/`highest` avec le filtre standard des agrégats du clan (`enabled != false` **et** `has_device != false`) ; `_refreshRoster` produit déjà la contribution maximale du cycle, il n'y manque que la somme. À noter : `clans_logs` reste volontairement **vierge de tout ce qui touche au coffre** — il est lisible par tout le clan, et le contenu du coffre doit rester une surprise. L'historique est une table à part, précisément parce qu'elle ne dit que des nombres.

### autres databases

`sessions` : base interne de `dvcloud` pour la persistence de session de navigation. `messaging` : base de `dvmessaging` (tokens FCM, registrations). `secrets` : secrets post-acceptation de `dvvirtuallobby` (usage unique, supprimés à la lecture). `virtuallobby` : submissions, management records et verrous de création.

---

## 12. assets cloud

Le bucket GCS (`assets`, lecture publique désactivée) est organisé en **racines de thème**, chacune publiant son propre `assets.yml` : `general/` (ce qui ne dépend d'aucun thème — `configs/`, `prompts/`, les layers de structure) et `donjon/` (la saveur — `images/`, `sounds/`, `music/`, `videos/`, les layers de thème et de traductions). Le client déclare la liste des racines à charger (`assets.cloud.manifests`) et les fusionne en cascade : la conf demande des chemins **nus** (`images/big/flamme_nobg.png`), c'est la liste qui décide du thème qui les fournit. Un thème non déclaré n'est jamais téléchargé. Le client télécharge via `dvcloudassets` avec cache local de 30 jours. Deux niveaux de priorité :

| Priorité | Assets | Raison |
|---|---|---|
| `vital` (bloquant) | illustrations d'intro (`intro_little_*`), `video_{lang}.mp4` | requis pour les premiers écrans |
| `critical` (prioritaire) | `prompts.yml`, `ambiant1.mp3`, `anim_burn.mp3`, fonds de splash | IA, musique et décor du tronc commun |

Les autres variantes de vidéo sont blacklistées (`video_{any}.mp4`) pour ne pas télécharger les langues inutiles. La résolution nom → fichier réel passe par une table de pointeurs (`assets.pointers` du backend) : `prompts.yml` → `prompts_General_V1.yml`, `video_fr.mp4` → `Donjons&Savons-FR_General_V1.mp4`, `ambiant1.mp3` → `Ambiant1_General_V1.mp3`… Ce mécanisme permet de versionner les assets GCS sans recompiler le client.

**Musique** : quatre pistes d'ambiance (`ambiant1..4`) jouées en boucle à partir de la fin de la vidéo d'intro (`dvsound.loop.ambiant`). Tant que le personnage est mort, l'ambiance bascule sur une playlist dédiée (`ambiant_dead`) ; le soin ramène la playlist habituelle. Les deux sont déclarées dans le thème (`sound.playlists` de `theme-donjon-global.yml`), comme les sons de célébration.

**Célébrations** : chacune est un **interlude** (module `dvinterlude`) — son effet sonore (`sounds/`) et sa vibration démarrent **une demi-seconde avant le visuel**, l'écran est confisqué le temps du spectacle, et la musique se coupe puis repart de sa première piste. Le worker ne fait que déclencher (`dvinterlude.play.<id>`), composer les textes traduits, et choisir l'ambiance.

La frontière est nette : **`config.yml` déclare que les six interludes existent** (leur identifiant, le DvSplash où poser leur texte, les actions du worker à tirer à la fin — voir le tableau des déclencheurs section 8) ; **le thème déclare ce qu'ils SONT** — la scène dvflame (`flame.scenes`), les partitions de vibration (`vibrations`), les fichiers sons et les playlists (`sound`), et le mariage des trois (`interludes.<id>.{scene, sound, vibration}`). Un autre univers réécrit toutes les animations à son goût sans toucher une ligne de `config.yml` ni de Dart. Les identifiants de scène (`burn`, `heal`…) sont le seul contrat : les vues du registry s'y accrochent, un thème en change le contenu, pas le nom.

**Images** : les illustrations vivent dans des sous-répertoires par gabarit (`big/`, `medium/`, `small/`, `splashs/`) — le builder redimensionne automatiquement selon la règle du sous-répertoire. Chaque feuille de tâche a son monstre `medium/dt_t_{id}.png` ; les overlays du tiroir (`flamme`, `skull`, `cure`, `hand`), les jauges (cœur, coffre `chestip`/`chestok`, écusson) et les personnages d'intro sont en `big/`. Le fond plein écran de la cérémonie d'ouverture (`CoffreRitual.png`) et les miniatures des items (`titre_perso.png`, `titre_clan.png`, `poubelle.png`) sont en vague `major` : une icône d'option de menu non préchargée affiche une ligne nue à la première ouverture (résolution asynchrone).

**Police** : MedievalSharp (OFL) bundlée dans le client — utilisée par les splashs de célébration.

**Catalogue d'items** (`items-base-global.yml`) : familles (onglets) et types déclarés en conf, images posées par le layer de thème (section 8/11). Une clef `shared` sur un type permet à un item du CLAN (`owner = clanId`) de se montrer à **tous** ses membres au lieu des seuls admins (défaut) — sans donner aucun droit : c'est `worker.items_selector` qui décide de ce qu'un non-admin peut en faire. Utilisée aujourd'hui par `titre_clan` seul.

### layers de configuration et de contenu

Le répertoire `layers/` contient les layers fusionnés au démarrage (DSL de surcharge Deva) :

- `tasks-base-global.yml` — structure des 20 domaines et 151 tâches (effort, type, respawn, multiple, tags) ; chargé en base de conf.
- `decisiontree-donjon-global.yml` — layer de **contenu** chargé sous le thème `theme-donjon` : traductions des titres de monstres, critères, textes de victoire/retraite/gages/titres.
- `theme-donjon-global.yml` — le thème par défaut (visuels, splashs, overlays du tiroir, registre d'écrans).
- `theme-pirate.yml` — thème alternatif minimal (`strategy: force`, `above: theme-donjon`) : surcharge le seul `splash_background`. Preuve de concept du système de thèmes par layers, socle des futurs thèmes saisonniers.

> Note sur le decisiontree : `configs/decisiontree.yml` est l'**arbre de questions** consommé par le widget `DvDecisionTree` ; `layers/decisiontree-donjon-global.yml` est le **layer de contenu** (traductions). Ce ne sont pas des doublons : l'un porte le flux, l'autre les textes. Les questions actuelles restent un brouillon à finaliser avant production.

---

## 13. déploiement

Backend provisionné par Pulumi (`backend/build.yml`). L'ordre de build est `backend` puis `client` — le provisioning GCP doit précéder la compilation Flutter qui en consomme les credentials OAuth.

| Module Pulumi | Responsabilité |
|---|---|
| `puproject` | création du projet GCP `dvddust`, liaison facturation |
| `puapis` | activation des APIs (Firestore, Cloud Functions, Run, Artifact Registry...) |
| `pufirebase` | initialisation Firebase, package Android `com.grisloup.ddust_client` |
| `pufirestore` | databases Firestore + règles de sécurité (dont les règles custom `clans`, `clans_logs`) |
| `pustorage` | bucket `assets` (lecture publique désactivée) |
| `puassets` | upload des fichiers de `resources_cloud/` dans le bucket, table de pointeurs |
| `puoauth` + `puoauthcreds` | OAuth clients (desktop, Android) |
| `pusvcaccount` | service account `ddust-backend` (roles Firestore user + logging) |
| `pucloudfunction` | déploiement des Cloud Functions TypeScript |
| `pumessaging` | infrastructure FCM (broadcast activé) |
| `pudocuments` | upload des CGU HTML (`legal/documents/`) dans GCS |
| `pusecrets` | provisionnement des secrets applicatifs (Cloud Secret Manager) |
| `puvertexai` | activation Vertex AI, accès aux modèles Gemini configurés |
| `pubudget` | surveillance des coûts GCP (Vertex AI 5 €/mois, Cloud Run 8 €/mois, auto-disable), token bucket anti-spike, alertes Telegram |
| `puvirtuallobby` | databases Firestore `virtuallobby` + `secrets` avec TTL policy sur le champ `expiration` |

Région unique : `europe-west9` (Paris). Toutes les ressources y sont localisées pour conformité RGPD.

La Cloud Function `countSessions` s'exécute avec le service account `ddust-backend` (Firestore minimal), callable uniquement depuis un client authentifié Firebase.

---

## 14. aspects légaux

### documents CGU

`legal/documents/` contient un fichier HTML par tuple `{eu|us}-{a|k}-{fr|en|es}-{cgu|privacy}-vN.html`, toutes versions confondues. **En vigueur** : CGU **EU v5 / US v3**, privacy **EU v3 / US v2** — `pudocuments` les uploade dans GCS et ne sert que le `max` de chaque tuple. Le module `dvdocuments` sélectionne le bon fichier selon `(region, legal_state, lang)`. La version mineure (`k`) est rédigée dans un langage accessible ; la version adulte inclut les mentions de responsabilité parentale.

L'acceptance est cochée par l'utilisateur et tracée dans `steps.cgu` avec timestamp et device ID.

Seules les **CGU** passent par le flux d'acceptation (`documents.acceptance` dans `screens_meta.yml`). La **politique de confidentialité** n'est pas un document acceptable : elle informe, elle n'engage pas. Elle est consultable dans l'app par l'option « Mes données » du kebab de l'écran Personnage (`worker.open_privacy` → `documents.open_doc` sans suffixe, donc dans l'état légal de la session).

### consentement parental d'adhésion

Il n'existe **plus de document `consent_clan` dédié**. Le consentement parental à l'adhésion d'un mineur est désormais couvert par la **CGU unique** (acceptée par l'admin adulte au signup) : à l'acceptation d'une demande, `on_consent_required` → `worker.on_consent_required_clan` reprend directement le workflow (transmission du `clanSecret`), sans écran intermédiaire.

La CGU (art. 6) porte donc l'engagement, et il est **rappelé au moment de l'acte** sur trois écrans : invitation d'un membre, création d'un profil de joueur, acceptation d'une adhésion. Cet engagement est **conditionnel** : le chef déclare être le responsable légal du mineur qu'il fait entrer, *ou* agir avec l'accord de ce responsable lorsque le mineur appartient déjà à un autre clan. La responsabilité reste attachée au **clan d'origine** (`original_clan`, gelé sur le premier clan) — rejoindre un second clan ne la transfère pas, et la dissolution du clan d'origine entraîne la suppression du profil du mineur (cascade `backend/config.yml`). L'art. 11 des CGU et l'article « consentement parental » des politiques de confidentialité disent la même chose, dans les mêmes termes.

> Les documents restent des **brouillons de test** à valider juridiquement avant mise en production. Toute reprise de leur fond impose de publier de **nouvelles versions** (`pudocuments` retient le `max` par région/état légal/langue/document), ce qui repose les CGU à tous les joueurs au lancement suivant — vérifier alors le routeur `worker.legalstate`, qui doit ramener un joueur déjà enrôlé au dashboard. Ne pas oublier les renvois croisés versionnés (CGU↔privacy, `k`→`a`) et les liens en dur du site (`hosting/web/{fr,en,es}/legal/`).

### âge de consentement numérique (RGPD / COPPA)

Le **consentement numérique** est l'âge sous lequel un service en ligne doit obtenir un consentement parental pour traiter les données d'un enfant — **13 ans aux États-Unis (COPPA)** et **plancher de l'article 8 du RGPD** (les États membres fixent entre 13 et 16 ; la France retient 15). Ce seuil gouverne le **consentement au traitement des données**, pas l'accès au contenu.

Ddust est de toute façon **plus strict que ce plancher** : il n'exploite jamais le consentement propre de l'enfant. Tout mineur — jusqu'à 18 ans, `legal_state = k` — passe obligatoirement par le consentement d'un adulte : les CGU (version mineure) puis, à l'adhésion à un clan, le **consentement parental** donné par un admin qui a lui-même accepté les CGU. Ce modèle « tuteur pour tout mineur » englobe le cas des moins de 13 ans sans dépendre du curseur 13/15/16 propre à chaque pays.

Conséquence côté conf : `documents.age_thresholds` ne déclare **qu'un seul seuil opérant, 18 ans**, dans les deux régions. Le seuil bas est posé à `k: 0`. Un `k: 13` y a longtemps figuré, mais il était **inerte** : `_computeLegalState` (`dvdocuments`) initialise l'état à la clé du plus petit seuil, donc tout âge inférieur à 18 retombe sur `k` de toute façon. Le faire figurer laissait entendre un palier « moins de 13 » vs « 13-17 » qui n'a jamais existé, et poussait les textes légaux UE à annoncer un seuil de 13 ans que rien n'appliquait (corrigé : cgu-v3 §3 et privacy-v2 §4 côté `eu-*`, pages `legal/` du site). COPPA reste porté par la rédaction des documents `us-*`, où le seuil de 13 ans déclenche un vrai régime d'obligations.

⚠ **Ne jamais supprimer la clé `k` de `age_thresholds`.** Avec `{a: 18}` seul, `sorted.first.key` vaut `"a"` et le défaut bascule sur adulte : un enfant de cinq ans serait classé majeur. `k: 0` est le seul retrait sûr.

### parental gate

Un calcul arithmétique avec compte à rebours de 3 secondes. À chaque expiration du timer, un nouveau calcul est affiché. Une réponse correcte avant zéro valide le statut adulte. Ce mécanisme répond aux exigences Google Play Family Policy pour la vérification d'âge parentale sans collecter de données biométriques.

### données collectées

- UID Google (identifiant Firebase opaque)
- Région (EU)
- Distinction mineur / majeur (calculée, jamais la date de naissance brute)
- Données de jeu : XP, PV, gage porté, journal d'événements de jeu (noms de joueur choisis librement)

Par décision de design, les photos de validation de tâches resteront sur le téléphone — pas de Cloud Storage pour les contenus utilisateurs. La preuve photo n'est **jamais** visible par l'admin qui juge : seul le joueur peut revoir sa propre photo.

### ia et confidentialité

Seuls trois textes saisis librement par l'utilisateur — le nom de joueur, le nom de clan et la description de clan (non-PII par construction) — transitent vers Vertex AI lors de l'inspiration de nom (section 6). Aucun identifiant, âge, région ou email.

Le conte du butin (section 10) élargit ce périmètre : à la demande explicite d'un joueur (tout membre, pas seulement un chef), il transmet aussi le **journal du clan** — prénoms des membres, descriptions de tâches accomplies, XP totale, argent de poche distribué. Ce sont les mêmes catégories de données (prénoms choisis par l'utilisateur, faits de jeu), jamais d'identifiant, d'âge, de région ni d'email — mais le volume est sans commune mesure avec un simple nom de clan, d'où cette mention séparée.

### conformité Google Play

Analytics désactivé pour conformité Family Policy. Pas de collecte d'ID publicitaires. Suppression de compte autonome (exigée par le Play Store) : page web `hosting/web/delete-account/` (https://donjons.grisloup.com/delete-account/) **et** option in-app (menu kebab de l'écran Personnage).

Le dossier de sous-traitance RGPD — adhésion au « DPA Google » (CDPA + Firebase DPST), registre art. 30, annexe Data safety — est dans `legal/dpa.md`. Les déclarations Play Console (DPA, Data safety, fiche du store, public cible, IARC, accès de revue, OAuth/Family Link) sont préparées dans `playstore.md`.

> ⚠️ restant avant production (non bloquant pour le test fermé) : validation juridique des CGU/privacy (brouillons de test), AIPD (mineurs + IA générative = deux critères CNIL), mentions plateformes d'affiliation si activées.

---

## 15. hors scope

- **Temps réel généralisé** : pas de listeners Firestore sur les écrans. Les états sont lus à la connexion et aux transitions de navigation ; les statuts de tâches sont relus à chaque affichage du tiroir — deux joueurs peuvent voir un état brièvement divergent. Seules deux vigilances `dvcloud.watch` ciblées existent : la tâche en attente de verdict et le doc joueur (level-up).
- **Stockage cloud de photos** : les photos de validation restent sur le device.
- **Backend propriétaire** : tout passe par Firebase et des Cloud Functions ponctuelles ; pas de batch serveur non plus — même la dégradation des PV est dérivée côté client.
- **Multi-provider auth** : Google uniquement (OAuth PKCE). Pas d'email/password ni d'Apple Sign-In.
- **Génération IA des tâches et des gages** : tâches, gages et butins sont du contenu configuré. Seuls les noms de joueur/clan (et le futur journal narratif de clan) sont générés par IA.
- **Création de domaine par le chef de clan** : la liste des domaines est du contenu de jeu, pas une structure que le clan se façonne. Un chef crée et retouche des **tâches** dans les domaines existants ; les domaines **additionnels** s'achètent en packs dans la boutique (section 17). Concrètement, `combat/tiroir` pose `extras_enabled: false` (aucune tuile « + » sur la grille des domaines) et `adm_add_task` refuse toute page qui n'est pas un sous-tiroir `<domaine>_tasks`.

---

## 16. philosophie deva

Donjons & Savons est une suite `projects/` avec vision produit propre. Son assemblage Deva révèle plusieurs choix d'intégration non-évidents.

**Un seul fichier Dart applicatif** : tout le code métier tient dans `worker.dart`. Chaque écran et widget est défini dans `config.yml` via le DSL dvorb. Le worker ne sait pas comment les écrans sont faits — il répond à des actions nommées et navigue vers des `dvid`. Les barèmes de jeu eux-mêmes (XP, niveaux, PV, decay, butin) sont des clés de conf (`worker.*`), pas des constantes.

**dvdocuments comme gate légal** : le module encapsule l'intégralité du flow légal (région, calcul d'âge, parental gate, CGU, acceptance). Le worker ne connaît que deux callbacks : `on_documents_ready` et `on_acceptance_complete`.

**dvdecisiontree comme configurateur de contenu** : le decisiontree produit une whitelist/blacklist de tags issue des réponses du foyer. Les questions sont dans GCS, modifiables sans recompilation.

**dvcloud comme unique couche d'accès** : deep-merge par `updateMask` (les écritures partielles préservent le reste du doc), vigilances `watch` (push natif Firestore sur Android, polling adaptatif sur desktop — même API), routage régional transparent. Les trois sont exploités intensivement par la boucle de validation et le level-up temps réel.

**dvmessaging porte la logique métier** : demandes de validation à 3 boutons exécutables app fermée (mode restreint `noorb` : l'app relancée par la notif ne charge que `orb` et `lang`, applique le verdict, s'arrête), verdicts traduits dans la langue du destinataire (résolution manuelle des traductions — pas de `@@@T:@@@` qui résoudrait dans la langue de l'émetteur), notifications de level-up et de nouveau membre par joueur.

**dvflame et les scènes déclaratives** : l'animation de célébration (« burn », trois actes minutés, particules de flammes/braises/cendres) est entièrement décrite dans `config.yml` (objets + timeline d'effets) et rejouée par une seule action. Le même interlude sert au level-up et à la bienvenue clan — ajouter une célébration ne demande ni code ni navigation. Les effets de bord qui doivent tomber PENDANT une scène (retirer le crâne quand le voile blanc du soin est plein, poser le « GAME OVER » quand l'écran est devenu noir) sont accrochés au hook `on_end` de l'acte concerné, et non à un délai en dur : si l'animation est retouchée, ils suivent.

**DvTiroir / DvRoster / DvExplorer / DvMenu(Button) et le pattern selector** : les listes (tâches, membres, avatars) sont des widgets génériques du framework, tous descendants d'une classe mère `DvCollection` ; le métier est injecté par des callbacks nommés — `selector` (quelles options de menu, lesquelles grisées), `sort` (tri métier : admins d'abord), clones et statuts poussés par actions (`dvtiroir.update_clones`, `dvroster.set_members`, `dvtiroir.update_recommended`). Le tiroir résout lui-même l'option seule quand `menu_enabled: false` : le même mécanisme sert le tap direct aujourd'hui et le menu contextuel demain. `DvMenuButton` (kebab doré autonome) ouvre les journaux depuis les en-têtes ; `DvExplorer` sert la grille d'avatars.

**dvtheme et la surcharge par layers** : un thème n'est pas une duplication de conf mais un différentiel (`theme-pirate` = un layer mince en `strategy: force`). Socle technique des thèmes saisonniers et payants envisagés.

**dvcloudassets et la priorité de téléchargement** : assets classés `vital` (bloquants) / `critical` (prioritaires) / blacklistés, déclaratifs dans `config.yml`. Les prompts IA bloquent l'activation de Vertex AI jusqu'à disponibilité ; les vidéos des autres langues ne sont jamais téléchargées.

---

## 17. chantiers actifs

La boucle complète « tâche → preuve → verdict croisé → XP → niveau → titre → célébration » tourne de bout en bout, avec sa méta : PV, mort, gage, guérison, coup de pouce, recommandation de tâche (boss), journal narratif, promotion/rétrogradation de chef, révocation, passage à l'âge adulte, création et édition de tâche, avatars, notifications. Les chantiers ouverts, par ordre de valeur (`roadmap.md`) :

- **Butin** — le gros débouché du clan : journal narratif IA du clan, et l'écriture de la table d'historique `clans_chest_history` — **elle reste sans écrivain** : la table existe et est déjà lue (comparaison à la moyenne des 20 derniers butins), la cérémonie ne l'alimente pas encore. Faits : l'accumulation, les jauges, le coffre et son contenu, la notification de dépôt au clan, la cérémonie d'ouverture synchronisée multi-joueurs (verrou dvlock, appel du clan, attente des réponses, recalage de `last_butin_xp`) et l'écran de récompense.
- **Notifications métier restantes** — rappel butin vide, adhésion acceptée validable en un tap.
- **Statuts de joueur** — hors-ligne et sans-téléphone (exclusion du diviseur d'XP clan, du decay et de l'ouverture du butin), switch d'utilisateur (jouer à la place d'un autre joueur), mode adulte sans XP.
- **Préférences et IA** — écran de préférences utilisateur (choix de la langue après l'onboarding), toggle IA global (propositions toutes faites en remplacement quand l'IA est coupée).
- **Économie de jeu** — le plus gros volume : or, boutique à reset hebdomadaire, loot, quêtes, potions, objets, classes, faveurs, succès, saisons. C'est aussi là qu'arrivent les **packs de domaines** : les domaines supplémentaires sont du contenu vendu, jamais créé par le chef de clan (sections 7 et 15).
- **Multitenancy** — changement de clan / rejoindre un autre clan, clans multiples, suppressions en cascade.
- **Monétisation et légal** — restent l'offre fondateurs et les crédits de mois, le parrainage, les CGU/CGV définitives (validation juridique) et l'AIPD avant production, plus le choix fin de l'offre et du base plan à l'achat (API `in_app_purchase_android`). Faits : **socle de monétisation complet** (modules `dvstore` et `pustore` — vérification serveur, RTDN, balayage du cycle de défaut de paiement, cinq écrans, achats personnels et bénéfice collectif par clan), suppression de compte (page web `delete-account` **et** option in-app), politiques de confidentialité mineurs (`legal/documents/*-k-*-privacy`), dossier DPA (`legal/dpa.md`), dossier store (`playstore.md`).
- **Finitions onboarding** — validation d'âge < 13 ans, écran `kid_wants_clan` à remplacer, nom du clan dans la bannière d'invitation. *(Le flux « je n'ai pas le QR code » est câblé : invitation à distance par lien chiffré par PIN — voir « inviter/rejoindre à distance ».)*
- **Assets/UI** — reclasser les icônes de menu (+, show, hide…) dans le gabarit `small` de l'imgshaking.

État d'avancement détaillé : `progress.md`.
