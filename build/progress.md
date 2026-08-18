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
se lance payante, la beta gratuite préalable est supprimée) : abonnements (2 paliers ×
mensuel/annuel, upgrade proraté / downgrade différé), **offre fondateurs et crédits de mois**,
défauts de paiement (grâce 10 j, hold, locked à J50, suppression à J90), CGU v5, dashboard des
achats, parrainage, socle extensions. Stack : `in_app_purchase` natif + backend maison —
module framework `dvbilling`, entitlement écrit **uniquement** par Cloud Function dans une
collection `clans_billing` que le client ne peut pas modifier, RTDN Pub/Sub pour l'état
canonique, sweeper quotidien pour les timers. Entitlement modélisé par clan dès maintenant,
UI mono-clan tant que la multitenancy n'est pas livrée.

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
