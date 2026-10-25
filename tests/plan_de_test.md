# Plan de test ddust

Plan de test fonctionnel des parcours joueur, joué sur émulateurs Android par la ligne « Test » du builder (`run-tests`). Il sert de source aux fichiers `tests/<categorie>/<test>.yml`.

Inventaire établi sur le client v1.0.86 (build 2080), le 2026-10-17.

## 1. Règles communes

- **Cible** : toujours la cible d'essai (`eut-workers`, case `documents/test_servers` cochée), jamais la production.
- **Région** : tous les téléphones d'un même test choisissent le même pays, sinon l'accueil est refusé (`invite_wrong_region`).
- **Adhésion** (depuis le 2026-10-18) : c'est toujours le candidat qui montre son QR code (`join_show_screen`) et le chef qui le lit, depuis « Accueillir un joueur » (`welcome_child_screen`), ou qui saisit son code de cinq caractères.
- **État initial** : chaque test commence par la suppression des données de ses comptes (helper `reset_comptes`), puis par une app fraîchement installée.
- **Items et prérequis** (depuis le 2026-10-19) : chaque test déclare `items`, ce qu'il exerce (écrans `ecran:`, surcouches `overlay:`, interludes, leçons `tuto:`, événements, partages, notifications : catalogue extrait de la conf), et `prerequisites`, les tests joués obligatoirement avant (le producteur de sa photo). Le rapport liste les items déclarés, vus, et déclarés non vus. On lance par seuil de criticité et par catégorie (`selection=`), ou par items (`items=`) : c'est le panneau Tests de la console.
- **Photos et assets préchargés** (depuis le 2026-10-18) : seuls les tests de bout en bout (§ 6, `bout_en_bout`) et ceux de l'onboarding partent de zéro. Les autres réimportent une **photo** Firestore (`photo: papa_clan` ou `photo: famille`), prise à la fin d'un test de bout en bout réussi (`photo_exporte`), dates décalées de son âge, puis chaque téléphone retrouve son joueur par « Retrouver mon héros » (macro `reprise_photo`). Leurs assets cloud sont **préchargés** depuis le workspace du backend (`backend_t/assets`, ceux que `push-assets` envoie au bucket) ; `assets: reseau` garde le vrai téléchargement (tests de bout en bout). Une photo plus vieille que l'APK de test est refaite : le moteur joue son test producteur d'abord. Si le producteur échoue, les tests qui en dépendent sont comptés en erreur (« photo non prise »).
- **Plafond gratuit de 2 joueurs** : un test à 3 joueurs ou plus commence par un code cadeau de test appliqué directement dans Firestore d'essai (helper `code_cadeau`), qui ouvre le palier voulu sans passer par Play.
- **Mur de cotisation** (chefs, après 3 validations à deux ou 10 seul, 3 reports) : même remède, `code_cadeau` en tête du test.
- **Intro** : elle ne se joue qu'une fois par appareil. Le moteur la marque vue avant de lancer l'app (sauf ONB-08, qui la teste).
- **`enabled: true|false`** : chaque test le porte. Le moteur ne joue pas un test `false` et le compte « désactivé » dans le rapport, sans échec. `categorie=` et `critique` ne le rallument pas ; seul `test=<id>` le force.
- **Rappels surgissants** (`recruit_*`, `safety_*`) : toute étape « attend » ferme d'abord un rappel s'il est affiché (comportement par défaut du moteur).
- **Horloge** : les délais (mort à J10, butin 5 jours, boîte d'adhésion 15 minutes, demande d'un autre clan 7 jours, consentement 3 jours...) ne s'attendent pas, ils se simulent par le helper `horloge` qui recule les dates dans Firestore d'essai.

## 2. Réserve de comptes

| Compte | Nature dans ddust | Usage | Existe |
|---|---|---|---|
| A1 | adulte (Gmail de test) | chef fondateur | oui |
| E1 | Gmail de test, **déclaré mineur** à l'onboarding (date de naissance) | enfant avec téléphone | oui |
| A2 | adulte (Gmail de test) | adulte invité, second chef | non |
| A3 | adulte (Gmail de test) | tests à 3 joueurs, multiclan | non |

Les comptes sont rangés dans Firestore (master `asura-888`, base `deva`, `apps_tests/ddust`), saisis par `deva/python/modules/dvtest/comptes.py ddust`. Depuis le 2026-10-17 ce ne sont plus de vrais comptes Google : chaque compte devient une identité de test Firebase (`dvtest-ddust-a1`...), sans création ni vérification chez Google (`deva/python/modules/dvtest/readme.md`, « la connexion »). Ajouter un compte à la réserve suffit. Les tests qui demandent un compte absent sont en `enabled: false` (§ 6) ; une fois le compte créé, repasser leur `enabled` à `true`.

Pas de Family Link. Un enfant sans compte n'occupe aucun compte Google (créé par le chef).

## 3. Macros (répétées dans les tests)

| Macro | Ce qu'elle fait | Fin constatée |
|---|---|---|
| `onboarding_adulte` | `awake/tap` → `lang_choice/fr` → intro → `home/connect` → `region_screen` (pays, test_servers) → `age_screen` (≥ 18 ans) → `parentalgate` (calcul résolu) → CGU → `link_account/google_button` → `player_name_screen` | `new_or_pick_clan` ; log `_flushOnboarding: onboarding inscrit en base` |
| `onboarding_mineur` | idem jusqu'à `age_screen` (< 18 ans) → CGU → `kid_assent/go` | `join_show_screen` (QR code et code) |
| `creer_clan` | `new_or_pick_clan/create` → confirmation → `create_clan/confirm` → questionnaire → `theme_pick_page` | `dashboard` ; log `clan créé → firestore OK` |
| `inviter_adulte` | invité : `new_or_pick_clan/join` → `join_show_screen`, QR lu par `qr_lire` ; chef : `worker.on_welcome_player` → le lien `ddust://join` → `invite_consent_screen/yes` | invité sur `dashboard` ; log `[join] dépôt reçu` |
| `accueillir_enfant` | enfant : `join_show_screen`, QR lu par `qr_lire` ; chef : `worker.on_welcome_player` → le lien `ddust://join` → `invite_consent_screen/reads` (ou `aloud`) → `yes` ; enfant : Google → nom | enfant sur `dashboard` ; `clans_players.legal_state = k` |

Durée d'un onboarding : environ 1 min 30 (passages non sautables, l'intro étant marquée vue).

## 4. Helpers

| Helper | Rôle |
|---|---|
| `qr_lire` | capture d'écran d'un téléphone → décodage du QR → le lien `ddust://...` (join, cogreq) |
| `lien` | ouvre un lien `ddust://...` sur un téléphone (deeplink, voir § 7) |
| `mul_code` | lit un code dans une phrase affichée, par la sonde : le code d'une boîte d'adhésion (`join_show_screen/code`, `motif: join`, rendu sans tiret) ou le code du co-représentant (`guardian_qr_page/code`) |
| `reset_comptes` | supprime les données des comptes du test sur la cible d'essai |
| `horloge` | recule une date dans Firestore d'essai (dernier passage, jauge du butin, échéance) |
| `code_cadeau` | crédite le clan de mois offerts sur un palier, en écrivant directement dans `clans_store` (Firestore d'essai) |
| `firestore_lire` | lit un document de la cible d'essai pour les vérifications |

## 5. Criticité

- **critique** : sans lui, aucun joueur ne peut jouer ou un enfant peut être exposé (onboarding, clan, accueil d'un enfant, tâche validée, suppression de compte). Joué à chaque version.
- **majeur** : une fonction importante cassée, le jeu reste jouable.
- **mineur** : confort, présentation.

## 6. Les tests

Colonnes : **Tél.** = téléphones et comptes ; **Constat** = ce qui valide (écran / log / Firestore).

### bout_en_bout

Joués en premier. Apps neuves, comptes neufs, **assets téléchargés du bucket** : ils valident l'app de zéro et prennent les photos des autres tests.

| Test | Titre | Crit. | enabled | Comptes | Vérifications |
|---|---|---|---|---|---|
| E2E-01 | De zéro : onboarding du chef, son clan, son thème (photo `papa_clan`) (ex CLN-01) | critique | true | A1 | `dashboard` ; log `clan créé → firestore OK`, thème donjon ; questionnaire chargé (`question(s) chargées depuis`), aucun `asset introuvable … configs/` ; `clans/{clan}.founder` |
| E2E-02 | De zéro : la famille, chef et enfant accueilli par son QR code (photo `famille`) (ex ENF-01) | critique | true | A1, E1 | les deux sur `dashboard` ; `réclamée, mode child_pick`, `, par QR code)` ; `guardianship/{E1}` ; `clans_players.legal_state = k` |
| E2E-03 | Reprise d'une photo : chef et enfant retrouvent leur clan sur une app neuve | critique | true | A1, E1 | `verify_account: compte reconnu en région` sur les deux ; aucune inscription ni CGU rejouée ; `worker.is_chief` ; représentation intacte |

### onboarding

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| ONB-01 | Onboarding adulte complet jusqu'au choix du clan | critique | true | A1 | `new_or_pick_clan` ; `users`, `userindexes` écrits ; preuve CGU |
| ONB-02 | Onboarding mineur jusqu'à l'écran qui montre patte blanche | critique | true | E1 | `join_show_screen` avec QR et code ; boîte `clans_joins/{code}` ouverte, sans donnée personnelle |
| ONB-03 | Retrouver son héros (compte existant, app réinstallée) | critique | true | A1 | `dashboard` ; log `verify_account: compte reconnu` |
| ONB-04 | Mauvaise porte : compte inconnu par « Retrouver mon héros » | majeur | true | A1 vierge | overlay `home/rejected_*` |
| ONB-05 | Conflit de liaison : compte Google qui porte déjà un héros | majeur | true | A1 | overlay `link_account/conflict_*`, annulation sans perte |
| ONB-06 | Porte parentale : mauvaise réponse puis bonne | mineur | true | A1 | refus puis passage aux CGU |
| ONB-07 | App tuée avant la connexion Google : retour à `awake` | mineur | true | A1 | `awake`, aucune donnée écrite |
| ONB-08 | Intro jouée à la première ouverture, plus à la seconde | majeur | true | A1 | 2e lancement : `home` sans l'intro |

### clan

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| ~~CLN-01~~ | Devenu **E2E-01** (bout_en_bout) : Créer un clan et choisir son thème | critique | true | A1 | `dashboard` ; `clans`, `clans_players`, coffre ; log `ClanCreated` ; `clans_shop` |
| CLN-02 | Accueillir un adulte par son QR code | critique | false | A1, A2 | A2 sur `dashboard` ; `MemberJoined` ; boîte effacée |
| CLN-03 | Accueillir un adulte à distance (code dicté, « c'est bien ton clan ? ») | majeur | false | A1, A2 | log `dépôt reçu (…, par code)` |
| CLN-04 | Code faux | mineur | true | A1 | `welcome_child_screen/error` « Ce code ne mène à personne » |
| CLN-05 | Accueil refusé : régions différentes (QR forgé) | majeur | true | A1, E1 | message `invite_wrong_region` chez le chef |
| CLN-06 | Plafond gratuit : un 3e joueur (enfant sans compte, après E1) est refusé, `tiers_page` | majeur | true | A1, E1 | `tiers_page` ouverte au lieu de la création |
| CLN-07 | Code échu (15 min, `horloge`) | mineur | true | A1, E1 | refus chez le chef, boîte non réclamée |
| CLN-08 | « Pas maintenant » : boîte rendue, code neuf | mineur | true | A1, E1 | log `le chef a renoncé` ; ancienne boîte effacée |
| CLN-09 | Par code, l'enfant ne reconnaît pas le clan | critique | true | A1, E1 | personne n'entre ; code neuf ; aucun flush |
| CLN-10 | Usage unique : un second chef ne reprend pas une boîte réclamée | critique | false | A1, A2, E1 | refus `welcome_code_taken` ; `status = seen` |

### enfants

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| ~~ENF-01~~ | Devenu **E2E-02** (bout_en_bout) : Accueillir un enfant avec téléphone : son QR code, « il sait lire » | critique | true | A1, E1 | E1 sur `dashboard` ; `guardianship/{E1}` ; `clans_players.legal_state = k` |
| ENF-02 | Enfant sans compte créé par le chef | critique | true | A1 | tuile au roster ; `no_account: true` ; `MemberCreated` |
| ENF-03 | Réclamer un joueur sans téléphone | majeur | true | A1, E1 | `MemberClaimed` ; ancien doc `users` supprimé ; écran du nom sauté |
| ENF-04 | Jouer à la place de l'enfant puis revenir (PIN) | majeur | true | A1 | logs `take_place` puis `restore_self` |
| ENF-05 | Un autre adulte saisit le code de l'enfant : l'enfant refuse, puis son parent l'accueille | critique | false | A1, A2, E1 | E1 chez A1, pas chez A2 |
| ENF-06 | L'enfant ferme l'app avant de lier son compte : rien à son nom | critique | true | A1, E1 | `awake` ; boîte effacée ; aucun joueur `k` dans le clan |
| ENF-07 | Déclarer l'enfant majeur | majeur | true | A1, E1 | E1 : CGU adulte imposées ; `legal_state` `t` puis `a` |
| ENF-08 | Retrait du consentement puis annulation | majeur | true | A1, E1 | `consent_due` posé puis effacé |
| ENF-09 | Retrait du consentement à échéance (`horloge`) | critique | true | A1, E1 | données de E1 supprimées (`delete_user_data`) |
| ENF-10 | Accueillir un enfant à distance : son code dicté, « il ne sait pas encore lire » | critique | true | A1, E1 | log `dépôt reçu (…, par code)` ; option `child_read_aloud` |

### roster

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| ROS-01 | Promouvoir un adulte chef, puis le rétrograder | majeur | false | A1, A2 | `ChiefPromoted` / `ChiefDemoted` ; animation côté A2 |
| ROS-02 | Promotion chef refusée pour un enfant | critique | true | A1, E1 | option absente ou refusée |
| ROS-03 | Un chef retire un membre | majeur | false | A1, A2 | `MemberRevoked` ; A2 revient au choix du clan |
| ROS-04 | Fondateur seul dissout son clan | majeur | true | A1 | `clans.enabled = false` |
| ROS-05 | Supprimer son compte (adulte membre) | critique | false | A1, A2 | A2 à `awake` ; `status = deleted` côté clan |
| ROS-06 | Suppression refusée : seul représentant d'un enfant | critique | true | A1, E1 | refus `delete_account_sole_guardian` |
| ROS-07 | Suppression du chef unique : clan dissous, cascade enfants | critique | true | A1, ENF sans compte | clan dissous ; mineurs traités |
| ROS-08 | Un adulte non chef quitte le clan de lui-même | majeur | false | A1, A2 | A2 au choix du clan ; `MemberRevoked` (acteur = A2) |
| ROS-09 | Un enfant non chef ne voit pas « A quitté le clan » sur sa tuile | critique | true | A1, E1 | menu de E1 vide |

### taches

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| TAC-01 | Un membre prend une tâche, le chef l'accepte | critique | false | A1, A2 | status `assigned` → `validating` → `dead` ; XP créditée ; `TaskValidatedOk` |
| TAC-02 | Verdict partiel puis refusé | majeur | true | A1, E1 | `TaskValidatedPartial` / `Ko` ; XP conforme |
| TAC-03 | Auto-validation du chef seul | critique | true | A1 | log `auto-validation admin` |
| TAC-04 | Validation croisée : un chef ne valide pas sa tâche | majeur | false | A1, A2 (chef) | refus ; l'autre chef valide |
| TAC-05 | Enfant fait une tâche, parent valide | critique | true | A1, E1 | idem TAC-01 côté enfant |
| TAC-06 | Créer et modifier une tâche (mode Admin) | majeur | true | A1 | `clans_tasks` créée puis modifiée |
| TAC-07 | Tâches multiples : clones par joueur | mineur | true | A1, E1 | docs `{base}__{userId}` |
| TAC-08 | Abandonner une tâche | mineur | true | A1, E1 | tâche rendue disponible |

### progression

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| PRO-01 | Montée de niveau (XP par tâches) | majeur | true | A1, E1 | log `[levelup] niveau a → b` ; `personnage/lvl_*` |
| PRO-02 | Boss recommandé puis validé | majeur | true | A1, E1 | logs `tâche recommandée (boss)` puis `coup de pouce` |
| PRO-03 | Mort à J10 (`horloge`) et gage | majeur | true | A1, E1 | overlay `commons/death_*` ; `status = dead` |
| PRO-04 | Résurrection par le chef | majeur | true | A1, E1 | `PlayerResurrected` |
| PRO-05 | Résurrection du chef seul | mineur | true | A1 | log `résurrection admin solo` |

### butin

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| BUT-01 | Préparer le butin (objets, note, argent promis) | majeur | true | A1 | `clans_items` owner `butin` |
| BUT-02 | Cérémonie d'ouverture à deux (jauge pleine par `horloge`) | majeur | true | A1, E1 | `clans_chest_history` ; parts reçues |
| BUT-03 | Forcer un absent pendant la cérémonie | mineur | true | A1, E1 | distribution malgré l'absent |
| BUT-04 | Donner un item | mineur | true | A1, E1 | log `donné à` ; owner changé |

### boutique

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| BOU-01 | S'abonner par le faux store (porte parentale incluse, seul test qui passe par l'écran d'achat) | critique | true | A1 | `clans_store.tier` / `state` |
| BOU-02 | Code cadeau accepté puis refusé | majeur | true | A1 | `credit_months` ; log `code refusé` |
| BOU-03 | Mur de première cotisation, report | majeur | true | A1, E1 | mur après 3 validations ; report compté |
| BOU-04 | Bandeau d'impayé (phases simulées) | majeur | true | A1 | `commons/store_dunning` ; jamais bloquant |
| BOU-05 | Changer de thème : tous les appareils basculent | mineur | true | A1, E1 | log `bascule de l'appareil` sur E1 |

### confort

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| CNF-01 | Ouvrir les guides parent et enfant | mineur | true | A1 | `dvtuto.seen.*` |
| CNF-02 | Journal personnel, de clan, d'un joueur | mineur | true | A1, E1 | `log_page` non vide |
| CNF-03 | Couper puis rallumer l'IA du clan | mineur | true | A1 | `clans.ai_enabled` |
| CNF-04 | Réglages de notifications | mineur | true | A1 | interrupteurs persistés |
| CNF-05 | Notification de nouveau membre reçue | majeur | true | A1, E1 | log `notif nouveau membre` ; notification visible sur A1 |

### multiclan

| Id | Test | Crit. | enabled | Tél. | Constat |
|---|---|---|---|---|---|
| MUL-01 | Adulte dans deux clans, bascule | majeur | false | A1, A2, A3 | log `[multiclan] bascule vers` |
| MUL-02 | Enfant accueilli dans un autre clan : son représentant accepte | majeur | false | A1, A3, E1 | `join_requests` ; `guest_auth.{B}.used_at` ; fiche dans B |
| MUL-03 | Enfant accueilli dans un autre clan : son représentant refuse | majeur | false | A1, A3, E1 | aucune fiche dans B ; notification au chef de B |
| MUL-04 | Enfant accueilli dans un autre clan : pas de réponse en 7 jours (`horloge`) | mineur | false | A1, A3, E1 | demande `expired` ; notification au chef de B |
| MUL-05 | Co-représentant à distance (lien `ddust://cogpin` + code) | mineur | false | A1, A2, E1 | `guardianship.guardians` contient A2 |

**Total** : 69 tests, dont 22 critiques. Actifs avec les comptes A1 et E1 : 54, dont 17 critiques.

## 7. Points relevés pendant l'inventaire

Décisions du 2026-10-17 :

1. **Liens `ddust://`** : corrigé. Le builder pose l'intent-filter Android et le `CFBundleURLTypes` iOS depuis `appsettings.deeplink_schemes` (build.yml du client). Les tests ouvrent les liens par `adb am start`.
2. **Départ volontaire d'un adulte non chef** : corrigé. « A quitté le clan » sur sa propre tuile (`clan_selector`), garde redoublée dans `revoke_player`. Test ROS-08.
3. **Écran `accept_invitation_clan`** : supprimé (écran, thèmes, langues, route, action).
4. **Intro** : vue une fois par appareil, puis plus jamais (voir § 1). Les tests la marquent vue avant de lancer l'app.
5. **Abonnements et délais** : codes cadeaux de test appliqués dans Firestore d'essai (`code_cadeau`), dates reculées dans Firestore d'essai (`horloge`).

Restent tels quels :

- **`app_share.store_url` vide** : « Noter » affiche `rate_thanks_soon` tant que la fiche Play n'est pas publique (pas de test d'avis pour l'instant).
- **La caméra** n'est jamais utilisée par les tests : chaque QR est lu sur l'écran du candidat par `qr_lire`, puis ouvert chez le chef comme lien profond (`ddust://join`). La preuve photo d'une tâche part donc sans photo (`noproof`), comme quand la caméra manque.
