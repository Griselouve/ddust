<!-- généré : 20260719 -->
# progress — donjons & savons

## avancement

**~50 % implémenté**

Estimation par décomposition de `vision.md` en blocs fonctionnels pondérés par leur ampleur.
La boucle de jeu complète et sa méta tournent de bout en bout — tâches, validation croisée, XP,
niveaux, titres, PV, mort, guérison, journal, célébrations — et toute la couche d'administration
et de profils est désormais en place (promotion/rétrogradation de chef, passage à l'âge adulte,
révocation, édition de tâche, recommandation « boss », avatars). Le cœur du MVP est mûr et
stable ; les onglets boutique et inventaire restent des coquilles. Ce qui reste est surtout du
produit à fort volume : l'ouverture du butin, toute l'économie (or, boutique, loot, quêtes,
potions, objets, classes, faveurs, succès, saisons), la multitenancy, la monétisation et le
légal définitif.

> **Révisé 2026-08-11.** La monétisation passe de « après la beta » à **prérequis de la
> première publication** : l'app se lance payante, avec une offre fondateurs en contrepartie
> (voir `strategie.md`). L'onglet boutique n'est donc plus une coquille acceptable au
> lancement — c'est l'écran d'abonnement.

## ce qui est fait

**Authentification et onboarding** : flux complet — Google OAuth PKCE, choix de région (EU),
nom d'aventurier avec « Inspire moi » (Vertex AI, timeout 3 s + repli statique + cache de la
réponse tardive), calcul du `legal_state` sans persister la date de naissance, parental gate,
vidéo d'intro passable, CGU par `(region, legal_state, lang)` depuis GCS, reprise de session
partielle ou complète à la reconnexion, musique d'ambiance en boucle.

**Clans** : création réservée aux adultes (nom externe non-PII généré), sécurité par
`clanSecret` croisé via `userindexes`, adhésion par trois chemins (scan QR, lien partagé
warm/cold start, demande) avec consentement parental pour les mineurs, notification « nouveau
membre », animation de bienvenue (scène dvflame « burn » + DvSplash).

**Boucle de combat et validation croisée** : tiroir des domaines (19 câblés, 151 tâches,
tri actives-puis-grisées, bornes de grille + scroll), verrou `dvlock` + statut Firestore,
preuve photo locale **optionnelle** (sentinelle `noproof` si caméra indisponible), trois
verdicts (accept / partiel / reject) avec fenêtre de régénération préservée, **validation
croisée** (un admin ne juge pas sa propre tâche ; auto-validation réservée à l'admin solo),
notification admin à **3 boutons** exécutable app fermée (mode restreint `noorb`, garde
d'idempotence), vigilance `dvcloud.watch` côté joueur (push natif Android), overlays main /
flamme / crâne / pansement avec barres de respawn, tâches `multiple` clonées par joueur qualifié.

**Progression et célébrations** : XP `effort × 10` modulée par la fenêtre `dead → revive`,
niveaux joueur et clan dérivés (jamais stockés), titres tous les 5 niveaux (20 par échelle) —
**depuis peu des items** (`titre_perso`/`titre_clan`) gagnés au palier et **portés par choix**
(option « Porter ce titre »), plus une dérivation automatique ; montée de niveau de CLAN
désormais **détectée** (`_creditClanXp`, elle ne l'était pas) avec son propre item et son log
`ClanLeveledUp`, XP clan divisée par le nombre de membres, jauge de butin plafonnée à 10000 avec
contribution par joueur, montée de niveau joueur détectée en temps réel sur tout écran, barèmes
réglables par conf `worker.*`. **Six interludes** dvinterlude câblés : burn (level-up + promotion
chef), victory (tâche validée), giftxp (cadeau de guilde + coup de pouce boss), heal
(résurrection), gameover (0 PV) ; giftgold (hausse d'or) est câblé mais dormant tant qu'aucune
source d'or n'existe.

**PV, mort et guérison** : dégradation temporelle des PV dérivée côté client
(`jours d'inactivité / decay`), écran de mort global (scrim + crâne + gage aléatoire parmi 11)
persistant au redémarrage, blocage des tâches quand mort, menu contextuel du roster pour les
admins — guérir (3 PV, cooldown 3 j), coup de pouce (+50 XP au moins avancé, cooldown 3 j),
résurrection auto-servie de l'admin solo.

**Administration et profils** : promotion/rétrogradation de chef (couronne roster, fondateur
protégé, `clans.admins` + miroir `is_admin`, anim burn au promu + notif clan), **passage à
l'âge adulte** (un admin du clan d'origine pose `legal_state = "t"`, CGU adulte bloquante
survivant au kill, écriture de `"a"` dans `users` + `clans_players`), **révocation / départ**
par tombstone `clans_players.enabled = false` (fondateur protégé, éjection vers decisiontree),
**édition de tâche** (effort + respawn en picklists, écriture partielle des seuls champs
modifiés), **création de tâche** (tuile « + » d'un sous-tiroir → doc `user_created` exempté du
réconciliateur ; la création de *domaine* est hors scope : contenu vendu en packs),
**recommandation « boss »** (`adm_recommend` → badge XP, notif clan, XP boostée
décroissante, anim coup de pouce), **avatars** joueur et clan (grille `DvExplorer`, persistés
et relus depuis Firestore, cross-device), **contrôles admin du tiroir** (visible/enabled
persistés conf + runtime + Firestore).

**Journal de clan** : audit append-only `clans_logs` (règles Firestore inaltérables), écran de
récit narratif ouvert par `DvMenuButton` (mon journal, journal d'un joueur, journal du clan
complet), groupé par jour, localisé, tokens substitués, partage social des 15 derniers
événements.

**Socle** : thèmes par layers (`theme-pirate` en preuve de concept), animations dvflame
déclaratives, images redimensionnées par gabarit au build, écrans « born-filled » (géométrie
persistée en registry), backend Pulumi complet (Firebase Auth, Firestore multi-bases avec
règles custom, GCS + pointeurs versionnés, Cloud Functions, FCM broadcast, Vertex AI, budget
avec auto-disable et alertes Telegram, verrous, TTL lobby).

## ce qui reste à faire

**Butin (débouché du clan)** : l'accumulation, les jauges, le coffre et son contenu existent, ainsi
que la notification de dépôt au clan (ton modulé par comparaison à la moyenne des 20 derniers
butins) et la table d'historique `clans_chest_history` — déjà lue, mais **encore sans écrivain**.
Reste : gestion du contenu par les parents, sélection des participants, ouverture synchronisée
multi-joueurs (avec recalage de `last_butin_xp`, et c'est elle qui remplira l'historique), écran de
récompense, journal narratif IA du clan, idées de butin et affiliations.

**Économie de jeu** : le plus gros volume restant — or gagné aux tâches, boutique à reset
hebdomadaire, loot aléatoire, quêtes individuelles et de clan, potions, objets et équipement,
classes de personnage, faveurs parentales, succès, saisons. L'onglet inventaire porte sa
première vraie famille d'items (les titres, cf. ci-dessus) ; le reste des familles (potions,
magie, skills) et l'onglet boutique restent des coquilles. La boutique portera aussi les
**packs de domaines** : les domaines supplémentaires sont du contenu vendu, jamais créé par le
chef de clan.

**Profils et statuts** : switch d'utilisateur (jouer à la place d'un autre joueur : déconnecté,
sans device), choix du titre affiché parmi les débloqués, statuts hors-ligne et sans-téléphone
(exclusion du diviseur d'XP, du decay et du butin), mode adulte sans XP.

**Préférences et IA** : écran de préférences utilisateur avec choix de la langue après
l'onboarding (le sélecteur `dvlang` n'est plus accessible ensuite), toggle IA global
(propositions toutes faites en remplacement quand l'IA est coupée pour maîtriser les coûts).

**Multitenancy** : changement de clan / rejoindre un autre clan, clans multiples par joueur,
suppression de clan et cascades.

**Monétisation et légal** (**bloquant la première publication depuis le 2026-08-11** — l'app
se lance payante, la beta gratuite préalable est supprimée) : reste le **parrainage** (l'app
n'a pas d'écran ni de code de parrainage, alors que son moteur de crédits est livré) et
l'**effacement matériel à 30 jours** annoncé par la politique de confidentialité (§ 8), qui
manque aux *deux* chemins de suppression — celui du compte comme celui du clan, tous deux
n'étant aujourd'hui que des suppressions fonctionnelles.

*Livré le 2026-08-18* : le socle complet de monétisation. Module framework **`dvstore`**
(catalogue en layer cloud, droits publiés dans `store.*`, routeur de gate, onze callbacks
métier, banc d'essai `simulate_state`), backend **`pustore`** (vérification serveur via
l'API Google Play, RTDN, balayage quotidien : réconciliation + cycle de défaut de paiement
grâce 10 j / relances / gel J50 / drapeau de purge J90), cinq écrans (boutique, abonnement,
fiche produit, mes achats, clan gelé) et `worker_store.dart`.

*Complété le 2026-08-18 (revue du socle)* — le socle était structurellement juste et
fonctionnellement creux ; six trous comblés :

- **Achat du bon base plan et de la bonne offre.** Play renvoie une entrée `ProductDetails`
  par couple (base plan × offre) ; le moteur n'en gardait qu'une, ce qui rendait **l'annuel
  inachetable** et **l'essai 14 j inatteignable**. Toutes les entrées sont désormais
  conservées et l'achat choisit la bonne, avec cascade de replis (une offre à laquelle le
  compte n'est pas éligible n'est pas une erreur : Play ne la renvoie simplement pas). Les
  prix sont publiés **par périodicité** — sans quoi la bascule mensuel/annuel n'affichait
  rien. Aucune dépendance ajoutée : le jeton d'offre voyage avec l'entrée choisie.
- **Paywall.** Il n'existait aucune différence entre un clan abonné et un clan qui ne l'était
  pas, jusqu'au gel du 50ᵉ jour. `worker._checkStoreAccess` interroge maintenant le routeur
  `store.gate` à l'entrée du dashboard — seul point de passage obligé, et le même que le gel :
  `locked` → écran de repos, `paywall` → écran d'abonnement sans flèche de retour. C'est la
  lettre des CGU v5. `grace` et `hold` continuent de ne rien fermer.
- **Plafonds de membres.** `max_kids` / `max_adults` n'étaient que journalisés. Ils sont tenus
  aux quatre points d'entrée d'un clan (créer un joueur, inviter par QR ou par lien, accepter
  une demande, déclarer majeur), du côté du chef — le seul qui connaisse l'effectif et puisse
  payer pour l'augmenter. Un refus ouvre le palier illimité au lieu d'être un cul-de-sac, et
  une descente de palier n'évince jamais personne.
  *(Refondu le 2026-08-20 — voir ci-dessous : un seul compteur `max_players`, et « déclarer
  majeur » ne contrôle plus rien.)*
- **Offre fondateurs et crédits de mois.** L'éligibilité était circulaire (l'app demandait
  l'offre fondateurs si elle était *déjà* fondateur) : elle passe à une cloud function
  souveraine `store_eligibility`, dont le cutoff vit dans un document `store_config/founders`
  ajustable sans redéploiement. `store_verify` écrit `founder` sur constat de ce que Play a
  appliqué. Nouvelle fonction `store_grant` (allowlist d'exploitation) et consommation des
  crédits par le balayage : **c'est le seul levier capable de récompenser les familles du test
  fermé**, dont les achats sous licence sont gratuits.
- **« Mes achats ».** L'écran était inatteignable (aucun point d'entrée) et sa liste câblée
  vide, alors que le serveur écrivait déjà `clans_store/{clanId}/events`. Option de menu
  réservée aux chefs, et lecture réelle du journal de facturation.
- **Purge J90.** Le drapeau `purge_due` n'avait aucun lecteur — et n'était en fait **jamais
  posé** : le balayage ne regardait pas l'état `locked`, si bien qu'un clan gelé à J50 sortait
  de la requête et que le calendrier des CGU s'arrêtait là. Requête élargie, et nouvelle
  fonction `clan_purge` (planifiée à 6 h, une heure après le balayage) qui dissout le clan en
  réutilisant la cascade de `delete_user_data`.

Deux correctifs de bord au passage : l'entitlement est désormais lu **même quand la
facturation est indisponible** sur l'appareil (sans quoi la tablette d'un enfant refusait de
jouer alors que le parent avait payé depuis son téléphone), et `debug.simulate_state` est
repassé à `""` — non vide, il n'ouvre aucun canal Play et rien de tout ce qui précède ne
fonctionne.

Le modèle est à **deux niveaux**, et c'est ce qui permet qu'un enfant profite de tout sans
rien pouvoir acheter : les achats sont **personnels** (base dédiée `store`, un document par
achat, rangé par compte payeur — plusieurs adultes peuvent donc payer chacun avec sa carte),
et le bénéfice est **collectif** (projection `workers/clans_store/{clanId}`, écrite
uniquement par Cloud Function, lisible par tout membre du clan).

*Refondu le 2026-08-20 — **grille à cinq paliers au nombre de joueurs**.* La grille à deux
paliers portait **deux plafonds distincts** (5 enfants, 4 adultes). Une famille ne pouvait pas
prévoir son propre palier sans répondre à des questions que le produit ne pose jamais — l'admin
joue-t-il ? l'ado de 17 ans compte-t-il comme enfant ? — et le code héritait de la même
ambiguïté : le refus dépendait de la nature du candidat, dont le `legal_state` n'est pas encore
écrit au moment où l'on recrute.

Un seul compteur désormais, `max_players` : **les membres actifs du clan, admins compris**.
Essentiel 1-2 (1,99 €), Clan 3-4 (2,99 €), Tribu 5-7 (4,99 €), Guilde 8-12 (5,99 €), Royaume
13+ (7,99 €), plans annuels de 19,99 € à 64,99 € — bornes calées sur la démographie des
foyers, effet revenu quasi nul (+3%). Trois conséquences de code :

- **Le contrôle devient exact** aux quatre points d'entrée, y compris quand on ignore encore qui
  frappe à la porte — ce qui **clôt le point 10** de la revue de `publication.md` par conception
  plutôt que par correctif.
- **« Déclarer majeur » ne vérifie plus rien.** La promotion ne déplace plus de place : le joueur
  en occupait une avant, il en occupe une après.
- **Un seul jeton de refus** (`store_cap_full`) au lieu de trois, et il ne nomme plus de palier —
  celui qu'il faut dépend de l'effectif, et l'écran le flèche lui-même.

*Écran des paliers (`tiers_page`), au même moment.* Le choix de palier **sort de la boutique** :
celle-ci est un étal, qu'on parcourt quand on veut, et qui vendra des packs à l'unité. Une grille
tarifaire ne se lit qu'au moment où elle répond à une question. La page ne s'atteint donc jamais
par navigation libre — elle s'ouvre sur plafond atteint, bandeau d'impayé, relance push ou
réabonnement — et surligne exactement deux lignes : le palier courant (coché, effectif du clan
rappelé dessous) et le palier **conseillé**, celui qui ouvre réellement la place manquante et non
le suivant dans l'ordre. Rien de bloquant, conformément au reste : elle s'empile et se quitte.

Elle remplace le `subscription_page` supprimé en août et comble un trou réel — depuis le retrait
de `shop/list`, **aucun écran ne permettait plus de souscrire quoi que ce soit**.

Deux correctifs `dvstore` au passage, tous deux dictés par cet écran : le catalogue publie
désormais son propre libellé (`store.catalog.<id>.label`) à côté du titre Play, que Play décore du
nom de l'application — sur cinq lignes comparées, la parenthèse se répétait et noyait le seul mot
qui distingue les offres ; et le repli de prix devient **conscient de la périodicité**
(`price_hint_yearly`), là où il servait le tarif mensuel sous l'étiquette « par an » dès que le
canal Play était fermé, c'est-à-dire pendant toute la recette.

*Déjà livrés dans ce bloc* : suppression de compte (page web exigée par le Play Store **et**
depuis l'app), politique de confidentialité mineurs, DPA Google.

**Finitions** : questions du decisiontree définitives, validation d'âge < 13 ans, écran
`kid_wants_clan`, flux « je n'ai pas le QR code », nom du clan dans la bannière d'invitation,
notifications restantes (rappel butin vide, adhésion en un tap), reclassement des icônes de
menu dans le gabarit `small`.

## écarts roadmap ↔ implémentation

**Diviseur d'XP clan = nombre total de membres (écart assumé).** L'XP de clan est divisée par
le nombre **total** de docs `clans_players`, alors que la vision veut le nombre de membres
*actifs* (hors profils hors-ligne, sans-téléphone, adulte-sans-XP). L'exclusion viendra avec
les statuts de joueur.

**Dégradation des PV côté client (choix d'implémentation).** La roadmap envisageait une Cloud
Function planifiée (`pv_decay`) ; l'implémentation dérive les PV affichés à la lecture, sans
batch serveur. La mort n'est donc « constatée » que lorsqu'un écran calcule les PV. Par
ailleurs `player_decay` vaut 1 jour/PV là où la vision évoquait une attaque tous les 3 jours —
réglage de conf assumé.
