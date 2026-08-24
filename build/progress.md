<!-- généré : 20260823 -->
# progress — donjons & savons

## avancement

**95 % du livrable `ddust/beta`** (le lancement commercial), mesuré en story points de
`deva/roadmap.md` : 1 473 sp au total, dont 1 152 comptabilisés à la génération du KPI
(20260723) et ~275 livrés depuis — monétisation et facturation (233), socle extensions (8),
grille à cinq paliers (5), offre fondateurs et crédits de mois (13), trigger Pub/Sub du
module de fonctions (8), versioning du builder (8).

Le KPI de `roadmap.md` est donc **périmé** : il annonce encore 321 sp restants et décrit la
monétisation comme « entièrement absente ». Il reste en réalité ~46 sp, dont l'essentiel
n'est pas du développement mais de l'exploitation (flyers, seeding, gate S+12) et une seule
fonctionnalité produit, le parrainage.

Maturité : la boucle de jeu, sa méta et son socle commercial sont **stables** et éprouvés au
banc d'essai. Trois zones restent des **brouillons assumés** : les questions du decisiontree,
les documents légaux (non validés juridiquement), et le balayage de relance, livré mais
maintenu en mode simulation.

Sur le périmètre complet du projet (beta + mvp + eco + themes, 2 119 sp), l'avancement est
d'environ **70 %** — l'essentiel du reste étant le pack économie, du contenu à produire plus
qu'une architecture à concevoir.

## ce qui est fait

**La boucle de jeu, de bout en bout.** Bibliothèque de 151 tâches sur 20 domaines, filtrée
par le foyer via le decisiontree ; prise de tâche arbitrée par verrou distribué puis par
statut ; preuve photo locale ; validation croisée à trois verdicts, rendue depuis l'app ou
directement depuis les boutons d'une notification, app fermée. XP à part fixe et part
indexée sur la recharge, plafonnée par tâche selon le niveau du joueur, écrêtée de même côté
clan. Niveaux dérivés (jamais stockés), titres livrés comme **objets** portables ou jetables,
six célébrations déclaratives déclenchées par détection.

**La méta.** PV entièrement dérivés de la date de dernière tâche (aucun batch serveur), mort
avec gage et overlay global, guérison et coup de pouce sous cooldown porté par l'admin
acteur, résurrection de secours pour l'admin solo. Jauge de butin à deux plafonds, coffre
avec objets, argent de poche et **notes de chefs**, notification de dépôt au ton modulé par
l'historique du clan, et **cérémonie d'ouverture synchronisée** multi-joueurs — verrou de 30
minutes, appel du clan, attente des réponses avec forçage possible d'un absent, distribution
en un seul lot, réclamation par joueur, révélation des notes, puis conte IA de l'aventure.

**L'administration.** Chefs promus et rétrogradés, fondateur admin à vie, révocation et
départ volontaire par tombstone, passage à l'âge adulte avec CGU bloquante, joueurs déclarés
hors-ligne, **création d'un joueur sans compte** et **prise de place** pour jouer à sa place.
Mode admin du tiroir (activer, masquer, éditer, créer, ressusciter, libérer, recommander),
persisté sur trois surfaces.

**L'identité et le légal.** Onboarding **entièrement anonyme** — Firebase Auth ne détient ni
email ni nom avant l'acceptation des CGU — puis liaison du compte Google avec flush ordonné,
gestion du conflit de compte (adoption pour un adulte, blocage pour un mineur déjà enrôlé),
« Retrouver mon héros » qui vérifie avant d'écrire et nettoie derrière lui. Consentement
parental rappelé au moment de l'acte sur trois écrans, seuil unique à 18 ans, suppression de
compte en cascade récursive (in-app et page web), preuve de consentement close et datée
plutôt qu'effacée.

**Le commercial, complet.** Cinq paliers créés chez Google depuis la conf, essai de 14 jours,
offre fondateurs à éligibilité serveur, vérification d'achat, RTDN, balayage quotidien du
cycle de défaut de paiement, projection de droits en lecture seule, bandeau d'impayé réservé
aux chefs, écran de clan gelé, page des paliers avec fléchage du palier utile, plafond de
membres opposable, mur de première cotisation, codes cadeaux (réclamation, fabrication,
révocation) et porte parentale sur chaque achat.

**L'engagement.** Notifications d'événement traduites dans la langue du destinataire et
regroupées par langue ; balayage serveur de relance à deux pistes cloisonnées, avec boss
réellement convoqué avant d'être annoncé ; réglage « ne plus me faire signe » à un tap.
Tutoriel spotlight de neuf leçons avec overrides par rôle et panneaux d'options, et rappels
de recrutement à cadence pour le fondateur resté seul.

**Le décor et l'exploitation.** Deux régions provisionnées, assets par racines de thème avec
vagues de priorité réglables sans release, catalogue de la boutique en source unique
redistribuée à trois consommateurs, feuilles de saisie des consoles rendues au build,
archivage automatique des contrats de sous-traitance, site vitrine trilingue avec liste
d'attente beta, et un banc d'essai complet (scénarios commerciaux, fabrique de codes,
invocation de la fée, forçage d'une relance).

## ce qui reste à faire

**Butin** — l'écriture de `clans_chest_history` : la table existe, elle est déjà lue pour
situer un dépôt, et la cérémonie ne l'alimente toujours pas. C'est le dernier reliquat d'un
chantier par ailleurs terminé.

**Monétisation** — le programme de parrainage (13 sp) est la seule fonctionnalité produit
encore absente du lancement : le moteur de crédits qu'il partage avec l'offre fondateurs est
livré, il manque le suivi du filleul, l'écran et les notifications. Restent aussi la
correction de la classification IARC, l'ouverture effective de la piste (12 testeurs pendant
14 jours), et l'extension du module de catalogue aux produits à l'unité — inutile tant
qu'aucun contenu n'est à vendre.

**Relances** — sortir le balayage du mode simulation, une fois plusieurs passes jugées
crédibles ; puis, si le volume le justifie, découper la passe par heure locale réelle (le
décalage horaire est déjà collecté).

**Contenus** — le pack économie (or, boutique hebdomadaire, loot, quêtes, potions, objets,
classes, faveurs, succès, saisons, packs de tâches, affiliation) et les packs de thèmes.
C'est le plus gros volume restant du projet, et il attend la preuve que la base paye.

**Multitenancy** — changement de clan, clans multiples et facturation multi-clan. Le modèle
de données est déjà par clan, il n'y aura pas de migration ; c'est l'UI qui reste mono-clan.

**Finitions** — mode adulte sans XP, toggle IA global avec propositions de remplacement,
écran de demande d'entrée à refaire, nom du clan dans la bannière d'invitation, choix
photo/vidéo pour la preuve, ordre de priorité des avatars, icônes de menu en gabarit `small`.

**Avant production** — validation juridique des CGU et politiques de confidentialité (elles
restent des brouillons de test), AIPD (mineurs et IA générative, deux critères CNIL),
finalisation des questions du decisiontree, et ouverture effective de la région US.

## écarts roadmap ↔ implémentation

- **Le module de facturation n'a pas le nom prévu.** La roadmap annonce un module `dvbilling`
  et une collection `clans_billing` ; c'est livré sous `dvstore` (client), `pustore` (backend)
  et `pucatalog` (publication du catalogue), avec la projection `workers/clans_store`. Le
  principe est respecté à la lettre — écriture réservée au SDK Admin, `write: if false` côté
  client — seuls les noms diffèrent.
- **Le dashboard des achats n'existe pas, et c'est délibéré.** La roadmap le liste dans le lot
  monétisation ; il a été écrit puis **supprimé** : il redisait l'état que la boutique porte
  déjà. L'historique de facturation se lit désormais au journal du clan.
- **La suppression des données passe de J90 à J730.** Le calendrier d'impayé est inchangé
  jusqu'au gel (grâce 10 j, relances jusqu'à J50, gel à J50), mais la purge intervient deux
  ans plus tard et non quarante jours, avec une phase d'adieu un mois avant. Les CGU disent
  encore J90 : **c'est le principal écart à corriger au prochain bump documentaire.**
- **Quatre items estampillés `ddust/mvp` sont déjà livrés** : l'invitation à distance (par
  lien chiffré par PIN, et non par la « demande » décrite), le profil sans téléphone (création
  d'un joueur par un chef + prise de place), le choix de la langue en préférence utilisateur,
  et la majeure partie des notifications métier (le rappel de coffre vide est livré côté
  serveur ; l'adhésion acceptée validable en un tap ne l'est pas).
- **La paywall par fonctionnalité n'est câblée nulle part.** Le routeur de gating existe dans
  le module et le design le prévoyait ; le jeu ne se ferme finalement pour aucun état
  commercial, sauf deux portes explicites (clan gelé, mur de première cotisation). C'est un
  choix produit, pas un manque.
- **Trois écarts avec `vision.md`**, qui n'a pas été repris : la dégradation des PV est réglée
  à 1 jour par point et non 3 ; le butin ne s'ouvre pas « tous les 10 000 XP » mais sur une
  jauge à 1 000 alimentée par une part d'XP plafonnée ; et la recherche d'un clan par son nom
  a été **écartée** au profit du lien chiffré par PIN (la vision le note déjà). Le fichier
  reste par ailleurs la référence du ton et des intentions produit.
