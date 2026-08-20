// -----------------------------------------------------------------------------
// --- This file is part of the DEVA framework
// --- Copyright (C) 2026 Griselouve - deva@grisloup.com
//
// This file is part of DEVA.
//
// DEVA is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// DEVA is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Dependencies
// -----------------------------------------------------------------------------
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import '../dvcore/dvbeing.dart';
import '../dvcore/deva.dart';
import '../dvcore/dvidle.dart';
import '../dvcore/registry.dart';
import '../dvorb/dvshape.dart';
import '../dvorb/dvlabel.dart';
import '../dvorb/dvinput.dart';
import '../dvorb/dvorb.dart';
import '../dvorb/dvpage.dart';
import '../dvcloud/dvcloud.dart';
import '../dventries/dvmenu.dart';
import '../dvlang/dvlang_button.dart';
import '../dvlock/dvlock.dart';
import '../dvcamera/dvcamera.dart';
import '../dvmessaging/dvmessaging.dart';
import '../dvtheme/dvtheme.dart';
import '../dvstore/dvstore.dart';
part 'worker_session.dart';
part 'worker_clan.dart';
part 'worker_members.dart';
part 'worker_tasks.dart';
part 'worker_tuning.dart';
part 'worker_forms.dart';
part 'worker_avatars.dart';
part 'worker_screen_personnage.dart';
part 'worker_screen_clan.dart';
part 'worker_screen_tiroir.dart';
part 'worker_admin.dart';
part 'worker_combat.dart';
part 'worker_watch.dart';
part 'worker_verdict.dart';
part 'worker_celebrations.dart';
part 'worker_items.dart';
part 'worker_butin.dart';
part 'worker_chest.dart';
part 'worker_notify.dart';
part 'worker_log.dart';
part 'worker_store.dart';
part 'worker_fairy.dart';


// -----------------------------------------------------------------------------
// --- Globals shortcuts and miscellaneous
// -----------------------------------------------------------------------------

String _generateUuid() {
    final rng   = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
}

// -----------------------------------------------------------------------------
// --- worker class
// -----------------------------------------------------------------------------
class worker extends DvBeing {

    String  _aiName       = "";
    String? _originalDesc;
    String? _originalName;
    String? _cachedAiName;
    String? _cachedAiDesc;
    // Snapshots ORIGINAUX (non mutés pendant l'édition) de l'écran rename_task, pour n'écrire
    // en Firestore QUE les champs réellement modifiés. _originalName/_originalDesc, eux, suivent la
    // valeur COURANTE (mutés à chaque frappe) → inutilisables pour la détection de changement.
    String  _rtOrigName    = "";
    String  _rtOrigDesc    = "";
    int     _origEffort    = 0;    // effort au chargement (0 = absent)
    int     _origRespawnH  = 0;    // respawn_h au chargement, en heures (0 = absent)
    int     _selEffort     = 0;    // effort sélectionné dans la picklist (init = original)
    int     _selRespawnH   = 0;    // respawn_h sélectionné dans la picklist (init = original)
    String  _origType      = "immortelle";   // type au chargement ("mortelle"/"immortelle")
    String  _selType       = "immortelle";   // type sélectionné dans la picklist (init = original)
    // Tables libellé affiché → valeur, construites à l'appear (dépendent de la langue et du barème
    // d'XP) et relues à la validation pour reconvertir la sélection de la picklist. _effortByLabel
    // est en plus reconstruite à chaque changement de respawn, l'XP dépendant de la recharge.
    final Map<String, int>    _effortByLabel  = {};
    final Map<String, int>    _respawnByLabel = {};
    final Map<String, String> _typeByLabel    = {};   // libellé → "mortelle"/"immortelle"
    // Paliers de respawn proposés dans la picklist (en heures) : 1h…72h, 5j, 1 sem, 2 sem, 1 mois.
    final List<int> _respawnHours = [1, 2, 4, 8, 12, 24, 48, 72, 120, 168, 336, 720];
    String  _userId       = "";
    // Id de JEU de l'utilisateur AUTHENTIFIÉ (propriétaire du doc perso `users/`, verrouillé serveur
    // sur request.auth.uid). Normalement égal à _userId. Diverge pendant l'impersonation : _userId
    // devient l'id de la CIBLE (utilisé dans les collections de clan, autorisées par le clanSecret),
    // tandis que _authUserId reste l'admin — c'est lui que _sessionDocId() cible pour `users/`.
    String  _authUserId   = "";
    // Mode « prendre la place d'un joueur » (option roster admin) : le worker assume l'id de jeu d'un
    // autre membre du clan SANS se déconnecter. Mémoire seule (jamais persisté) → un kill de l'app
    // repart en tant que joueur d'origine. _realUserName garde le nom de l'admin pour le retour.
    bool    _impersonating = false;
    String  _realUserName  = "";
    // Admin du clan courant (cache par clanId) : un admin peut sélectionner une tâche "validating"
    // dans le tiroir (sinon le tiroir la verrouille comme pour tout le monde).
    bool    _isAdmin       = false;
    String  _isAdminClanId = "";
    // Indexe aussi le cache admin sur l'utilisateur : une bascule de compte sur le même appareil et
    // le même clan (worker = singleton) doit forcer la relecture, sinon _isAdmin reste hérité du
    // précédent utilisateur (ex. admin → joueur lambda ⇒ auto-validation indue).
    String  _isAdminUserId = "";
    // Nombre d'admins du clan courant (peuplé avec _isAdmin dans _ensureIsAdmin, cache par clanId).
    // Distingue l'admin SOLO (<=1) : auto-validation conservée + bouton « Résurrection » sur l'écran
    // de mort ; à plusieurs admins, l'admin passe par la validation croisée comme un joueur lambda.
    int     _adminCount    = 0;
    // Menu roster (écran Clan) : cooldowns de l'utilisateur courant (lus sur son doc `users` à
    // l'appear clan) + plus petit XP du clan (calculé au montage du roster). Servent au
    // clan_selector pour griser « coup de pouce »/« guérir » et restreindre le boost.
    String  _myLastBoost   = "";
    String  _myLastCure    = "";
    int     _clanMinXp     = 0;
    // Joueur dont on consulte le journal (posé par open_player_log, lu par on_log_appear une
    // fois l'écran log_page monté). name : substitué au token @@@session.user.name@@@ des dt_d_*.
    String  _logPlayerId   = "";
    String  _logPlayerName = "";
    // Journal clan-large (bouton settings de l'écran Clan) : quand true, on_log_appear n'ignore plus
    // le filtre par joueur et rend TOUS les logs, chaque ligne portant le nom de son propre acteur.
    bool    _logClanWide   = false;
    // Mode CONTE (icône de partage de butin_tale_page) : log_page n'affiche plus la liste des
    // événements mais le récit qu'un modèle en a tiré. Se cumule avec _logClanWide (on ne raconte
    // que le clan entier). CONSOMMÉ par on_log_appear : sans ça, revenir au journal par le kebab
    // rejouerait une inférence, et le mode survivrait à la sortie de l'écran.
    bool    _logNarrative  = false;
    // resourceId d'une tâche que CE device vient de sélectionner : l'appear combat qui suit
    // immédiatement doit afficher la tâche sans réconcilier (l'assignation Firestore est encore
    // en cours d'écriture → un read renverrait "alive" et ferait croire à tort que la tâche est
    // libre). Consommé (remis à "") au premier on_combat_appear.
    String  _freshlySelected = "";

    // Surcharges texte d'une tâche éditée par le chef de clan (stockées sur clans_tasks, relues à
    // chaque _loadClanTasks). Indexées par id de BASE (les clones héritent via _originalOf). Servent
    // à la résolution SYNCHRONE de _taskLabel/_taskAcceptance (deva_get est async) et au push des
    // libellés du tiroir. Reconstruites intégralement à chaque chargement des tâches du clan.
    final Map<String, String> _titleOverride      = {};
    final Map<String, String> _acceptanceOverride = {};
    // Tâche (id de base) ciblée par l'écran d'édition rename_task : posée par adm_edit avant la
    // navigation, lue par on_rename_task_appear/on_confirm_rename_task. _editReturnPage = écran d'où
    // l'édition a été ouverte (sous-tiroir de domaine ou combat), pour y revenir à la validation.
    String  _editTaskId    = "";
    String  _editReturnPage = "combat";
    // Mode CRÉATION de l'écran rename_task (tuile « + » du tiroir) : _creatingNew=true + _editTaskId
    // vide → l'appear ouvre l'écran vierge et le confirm crée un nouveau doc au lieu d'éditer.
    // _createDomain = domaine parent de la future tâche (déduit de la page sous-tiroir).
    bool    _creatingNew   = false;
    String  _createDomain  = "";
    // Image par défaut d'une tâche créée par le chef de clan. Stockée sur le doc Firestore
    // (champ `image`) → éditable ensuite ; affichée en fond de l'écran de création et sur la tuile.
    final String _defaultTaskImage = "images/medium/nounours.png";

    // Champs de plomberie Firestore d'un doc de tâche à NE PAS refléter dans la conf (tasks.<id>.*)
    // lors de la surcharge générique de _loadClanTasks : identité de doc / autorisation d'écriture.
    final Set<String> _taskDocBlocklist = {"ownerId", "clanId", "docId", "region"};

    // --- Delta-sync des tâches du clan -------------------------------------------------
    // Cache mémoire des docs clans_tasks/{clan}/tasks, indexé par docId. Peuplé
    // intégralement par _loadClanTasks (full list du login), puis tenu à jour par les
    // refreshs DELTA : _refreshTaskStatuses ne relit que les docs dont touched >
    // _tasksSyncCursor (au lieu des ~160 docs à chaque entrée d'écran). Mémoire seule :
    // un redémarrage repasse par le full list du login — pas de curseur persisté à gérer.
    final Map<String, Dvidle> _taskDocsCache = {};
    // Curseur de delta-sync : max(touched) observé. Vide → full list au prochain refresh.
    String    _tasksSyncCursor = "";
    // Clan propriétaire du cache : un changement de clan invalide cache + curseur.
    String    _tasksSyncClanId = "";
    // Garde anti-rafale du FETCH delta (~10 s). Les push d'overlays, eux, tournent à
    // CHAQUE appel (vocabulaire admin/jeu, tiroirs) — seule la lecture cloud est espacée.
    DateTime? _lastTasksFetchAt;
    // Dernier full list : filet de sécurité du delta (les SUPPRESSIONS de docs lui sont
    // invisibles) — au-delà de 24 h, on repasse par un full list.
    DateTime? _lastTasksFullListAt;

    // Cache mémoire du doc `users` de la session (TTL court, cf. _readSession) : ce doc
    // est relu en tête de la plupart des handlers — sans cache, chaque entrée d'écran
    // coûte plusieurs lectures Firestore du même document. Invalidé à CHAQUE écriture
    // locale du doc (cf. _invalidateSessionCache) ; le TTL borne la fraîcheur vis-à-vis
    // d'un autre appareil connecté sur le même compte.
    Dvidle?   _sessionCache;
    String    _sessionCacheKey = "";
    DateTime? _sessionCacheAt;

    // Mode édition de l'écran Personnage : révèle les 2 grosses icônes « edit » (avatar +
    // nom). État éphémère (aucune persistance), remis à false après une édition réussie.
    bool    _personnageEditMode = false;

    // Idem pour l'écran Clan (avatar + nom du clan).
    bool    _clanEditMode = false;

    // Avatars par défaut posés en Firestore à la création (clans_players.avatar /
    // clans.avatar) + image de repli si un avatar référencé est introuvable.
    final String _defaultPlayerAvatar = "images/medium/icon_01_P_01.png";
    final String _defaultClanAvatar   = "images/medium/icon_01_C_01.png";
    final String _nopeAvatar          = "images/medium/nope.png";

    // Vigilance temps réel d'une tâche en attente de validation (watch dvcloud : push
    // Firestore sur mobile, poll desktop). Handle unique (worker singleton).
    // _validationTaskId garde l'unicité et coupe une course start/stop pendant l'await.
    DvVigilance? _validationVigilance;
    String       _validationTaskId = "";

    // Vigilance temps réel du doc membre du joueur COURANT (clans_players/{clanId}/players/{_userId}) :
    // détecte une montée de niveau à tout instant, quel que soit l'écran affiché — l'xp est créditée
    // à distance (appareil de l'admin validateur), donc sans watch le joueur ne verrait l'animation
    // qu'en (re)passant sur dashboard/personnage. Push natif Firestore sur Android, poll desktop.
    // Handle unique (worker singleton) ; _playerVigilanceUserId garde l'unicité / anti double-start.
    DvVigilance? _playerVigilance;
    String       _playerVigilanceUserId = "";

    // Garde de ré-entrance : le watch et les appear (dashboard/personnage) peuvent invoquer
    // _checkPlayerLevelUp en parallèle → on sérialise pour éviter une double célébration (course
    // entre deux lectures de la même xp mémorisée avant qu'une n'ait persisté la nouvelle valeur).
    bool _levelUpChecking = false;

    // Garde de ré-entrance pour la célébration de soin (_celebrateHeal) : watch et appear peuvent
    // détecter la transition mort → vivant quasi simultanément → une seule animation jouée.
    bool _healChecking = false;

    // Garde de ré-entrance pour la détection du cadeau d'or (_checkPlayerGoldGift) : même raison
    // que _levelUpChecking (course entre deux lectures du même gold avant persistance).
    bool _goldChecking = false;

    // Garde de ré-entrance pour l'ouverture du butin (_checkPendingButin) : le watch du doc joueur
    // et la vérification unique du démarrage de la vigilance peuvent voir le MÊME pending_butin →
    // une seule réclamation, donc une seule animation. Relâchée par on_celebration_end.
    bool _butinChecking = false;

    // Le tutoriel du dashboard est ouvert par la FIN de l'animation de bienvenue clan (interlude
    // "levelup"), et non par l'`appear` de l'écran : son voile vit sur l'Overlay du Navigator, donc
    // AU-DESSUS de la vue de scène, et il avalerait le burn. L'attendre depuis on_dashboard_appear
    // rendait la leçon otage de tout ce que ce handler fait entre-temps (lectures cloud, autres
    // célébrations, préemption de la bienvenue), et `dvtuto.enter` renonce EN SILENCE s'il tombe
    // pendant un interlude — sans seconde chance, le retour par la taskbar émettant `show` et non
    // `appear`. Ce drapeau, armé par _playPendingClanWelcome, dit à on_celebration_end que le
    // « levelup » qui s'achève est une bienvenue et que le tutoriel l'attend derrière. Il est tiré
    // dans TOUS les cas (fin normale, garde-fou, préemption) : le relais ne peut pas rester en l'air.
    bool _welcomeTuto = false;

    // --- Cérémonie d'ouverture du butin ---------------------------------------------------
    // Rôle de CET appareil dans la cérémonie en cours : "" (aucune), "master" (le chef qui tient le
    // verrou dvlock et mène l'ouverture) ou "player" (un membre appelé par lui). Sert aussi de garde
    // anti-ré-empilage : tant qu'il est posé, l'écran de cérémonie est déjà là.
    String _openingRole = "";

    // Les joueurs que le maître attend, dans l'ordre d'affichage de la liste. Chaque entrée porte
    // id / name / avatar / ready. C'est la vérité de l'écran d'attente ; les vigilances la mettent
    // à jour et la re-poussent entière à la DvList (qui diffe seule).
    final List<Map<String, dynamic>> _openingRows = [];

    // Une vigilance PAR joueur attendu : dvcloud.watch écoute un document, pas une collection, et
    // le maître doit voir chaque `pending_opening` retomber. Coupées ensemble par _stopOpeningWatch.
    final List<DvVigilance> _openingWatch = [];

    // Garde de ré-entrance de la distribution finale : les N vigilances peuvent constater le
    // "tout le monde est prêt" quasi simultanément → une seule ouverture.
    bool _openingDistributing = false;

    // Garde de ré-entrance de l'appel du clan : le bouton du meneur n'est PAS gelant (il enchaîne
    // sur une animation qui pose son propre gel), un double appui doit donc être écarté ici — et
    // _openingRows, qui fait foi ensuite, n'est rempli qu'après la lecture de la collection.
    bool _openingCalling = false;

    // Côté JOUEUR : qui mène la cérémonie en cours (lu dans `opening_master` sur son propre doc,
    // posé par le meneur en même temps que l'appel). C'est l'adresse à laquelle envoyer sa réponse,
    // sans quoi il faudrait relire le clan pour la trouver.
    String _openingMaster = "";

    // État du "siège" de combat (mur de flammes + son en boucle). Sert de garde anti-course :
    // le son est (re)chargé de façon asynchrone à l'entrée en combat ; si le joueur quitte avant
    // que le chargement aboutisse, ce flag (repassé à false par _stopCombatSiege) empêche le
    // callback de démarrer la boucle sur un écran déjà quitté.
    bool _combatSiegeOn = false;

    // Garde de ré-entrance pour la détection de promotion/rétrogradation chef (_checkChiefPromotion) :
    // même raison que _levelUpChecking (course watch ↔ appear sur la même valeur is_admin).
    bool _chiefChecking = false;

    // Garde de ré-entrance pour la célébration de mort (_celebrateDeath) : watch et appear peuvent
    // détecter la transition vivant → mort quasi simultanément → une seule animation jouée.
    bool _deathChecking = false;

    // Amorçage : true après le 1er _evaluateDeath d'une session. Empêche de jouer l'animation de mort
    // au démarrage quand le joueur ouvre l'app DÉJÀ mort (prevDead=false à l'amorçage → transition
    // vivant→mort fictive). Miroir de l'amorçage silencieux du level-up (worker.player_last_xp).
    bool _deathSeeded = false;

    // Fenêtre de fraîcheur (secondes) pour rattacher un log PlayerResurrected au soin qu'on vient de
    // détecter : au-delà, on considère qu'il s'agit d'un vieux cycle de mort et on passe au texte
    // générique. Large (5 min) pour absorber la latence de propagation Firestore + poll desktop.
    final int _healerLookbackS = 300;

    // Contexte de la mort en cours, figé par _celebrateDeath et consommé par show_gameover — qui est
    // tiré par la conf (fin de l'acte 1 de la scène) et ne reçoit donc aucun argument.
    String _deathGage        = "";
    bool   _deathShowRevive  = false;

    // Sentinelle stockée dans active_proof quand la tâche est envoyée en validation
    // SANS photo (caméra indisponible : desktop, pas de caméra, permission refusée).
    // Non-vide → l'état "validating" se dérive correctement (active_proof.isNotEmpty)
    // partout, mais aucune photo n'est associée (bouton "Voir ma preuve" masqué).
    final String _kNoProof = "noproof";

    // Dernière carte enabled/disabled poussée en mode JEU (arbre de décision). Le mode admin la
    // remplace par un « tout activé » (le seul greyer y est l'état d'administration) : c'est CETTE
    // copie qui est repoussée à la sortie. On ne relit pas le store — une relecture qui échoue
    // laisserait le tiroir en « tout activé » et ferait disparaître le grisage du jeu pour de bon.
    Map<String, bool> _gameDomains = {};

    // --- Suppression de compte (option kebab Personnage) -------------------------------------------
    // Idiome overlay (comme « Créer un clan ») mais en MACHINE À ÉTAPES : on avertit le joueur à
    // plusieurs reprises qu'il va TOUT perdre avant l'appel à la fonction cloud delete_user_data.
    int _deleteStep = 0;

    // Étape courante = clé de traduction du panneau d'avertissement (la dernière = définitive).
    final List<String> _deleteWarnKeys = [
        "delete_account_warn1",
        "delete_account_warn2",
        "delete_account_warn3",
    ];

    // Une FEUILLE de domaine a un suffixe numérique (ex. salon_01, cuisine_03) → dt_t_*.
    // Un DOMAINE de premier niveau (ex. cuisine, chambre_enfant) → task_*. Générique : tout
    // nouveau domaine câblé via tools/addnewdomain fonctionne sans toucher ces helpers.
    final RegExp _leafTaskRe = RegExp(r'_\d+$');

    // FORME d'un id de CATALOGUE : "<domaine>_NN" (1 à 2 chiffres, variante "_alt" tolérée —
    // ex. salon_01, linge_02_alt). Les tâches créées par un utilisateur portent un suffixe
    // d'horodatage à 16 chiffres (cf. _createNewTask) et ne matchent donc JAMAIS. Sert au
    // réconciliateur : seul un id de cette forme peut être supprimé comme orphelin — un doc
    // de forme inconnue appartient à quelqu'un d'autre (ou à un binaire plus récent) et ne
    // doit pas être détruit par un client qui ne sait pas le lire. Cf. _reconcileClanSchema.
    final RegExp _catalogTaskIdRe = RegExp(r'^[a-z_]+_\d{1,2}(_alt)?$');

    // Domaines câblés = sous-tiroirs de combat ("<domaine>_tasks/tiroir"). Source unique,
    // réutilisée par _buildTaskResults et par la résolution d'icônes ci-dessous.
    final List<String> _taskDomains = [
        'salon','chambre_parentale','chambre_enfant','cuisine','repas','vaisselle','salle_de_bain',
        'toilettes','entree','bureau','terrasse','jardin',
        'linge','dechets','animaux','garage','vehicules','courses','extras',
    ];

    // --- Tâches « multiple » : clonage par utilisateur -------------------------
    // Une tâche `multiple` n'est PAS persistée comme doc partagé : on crée un doc
    // clone par utilisateur qui qualifie, portant son propre cycle de vie (dead/
    // revive/status). La propriété est **pilotée par la CONF** (champ `multiple:`
    // dans resources_cloud/layers/tasks-base-global.yml, fusionné dans le store
    // `tasks.<id>.multiple`) — AUCUNE liste hardcodée ici : ajouter/retirer
    // `multiple:` dans le YAML suffit. Valeurs : 'k' = un clone par enfant
    // (legal_state "k"), 'a' = un clone par adulte, 'all' = un clone par membre.
    // Ex. actuel : tout `chambre_enfant` en 'k', tout `vehicules` en 'a'.
    // L'affichage/tuning du clone est résolu depuis l'original (cf. _originalOf) :
    // image, effort, type, respawn_h, messages.

    // Miroir cloneId → baseId, rempli à chaque chargement des tâches (le doc clone
    // porte un champ `original`). Permet à _originalOf d'être synchrone et fiable.
    final Map<String, String> _cloneOriginal = {};

    // Part FIXE de l'XP d'une tâche. Réglable via conf `worker.xp_per_effort`.
    int _xpPerEffort = 10;

    // Diviseur de la part VARIABLE (`respawn_h / _xpRespawnDiv`). Réglable via conf
    // `worker.xp_respawn_div`. Les deux parts s'égalisent à `_xpPerEffort × _xpRespawnDiv`
    // heures de recharge (120 h avec les valeurs par défaut).
    int _xpRespawnDiv = 12;

    // PV initiaux posés sur le doc d'un joueur à sa création. Réglable via conf `worker.player_pv`.
    int _playerPv = 10;

    // Valeur `decay` initiale posée sur le doc joueur (diviseur de la dégradation temporelle,
    // en JOURS — fractionnaires — d'inactivité par PV perdu). Réglable via conf `worker.player_decay`.
    double _playerDecay = 1.0;

    // PV rendus par une cure admin (revive_player). Réglable via conf `worker.heal_pv`.
    int _healPv = 3;

    // Plafond de BASE d'XP d'UNE tâche (le GAIN, jamais le cumul). Réglable via conf
    // `worker.player_max_xp`, mais ce n'est qu'une valeur d'AMORÇAGE : elle est recopiée dans
    // `clans_players.max_xp` à la création du joueur (cf. _writeClanPlayer) et c'est ce champ-là
    // qui s'applique ensuite — le plafond est une propriété du JOUEUR, appelée à varier d'un joueur
    // à l'autre. Ce champ ne sert donc qu'à deux choses : initialiser les nouveaux docs, et servir
    // de repli aux docs antérieurs à l'introduction du champ.
    // Sans plafond, une corvée à fort effort ET fort respawn (350 XP de base) RECOMMANDÉE cumulait
    // le coefficient boss (jusqu'à ×8) : 2800 XP d'un coup, soit le niveau 10 en une tâche.
    int _playerMaxXp = 100;

    // Ce que le plafond ci-dessus gagne PAR NIVEAU du joueur (cf. _capForLevel) : le plafond
    // réellement appliqué vaut `max_xp + _playerMaxXpPerLevel × niveau`, soit 120 au niveau 1 et
    // 300 au niveau 10. Un plafond FIXE traitait de la même façon le débutant et le vétéran : assez
    // haut pour laisser respirer les hauts niveaux, il laissait un niveau 1 rafler en une corvée
    // recommandée ce que le barème destine à plusieurs semaines. L'indexer sur le niveau fait du
    // niveau lui-même une récompense. Réglable via conf `worker.player_max_xp_per_level`.
    int _playerMaxXpPerLevel = 20;

    // Ancienne valeur d'amorçage du plafond, réalignée UNE FOIS sur le nouveau barème (cf.
    // _writeClanPlayer). `clans_players.max_xp` étant posé init-si-null, baisser `_playerMaxXp` ne
    // toucherait que les joueurs créés ensuite : les personnages existants garderaient l'ancien
    // plafond. Seule la valeur EXACTEMENT égale à celle-ci est réécrite → un plafond personnalisé
    // (pouvoir, classe) n'est jamais écrasé. 0 = réalignement désactivé, une fois tous les clans
    // passés. Réglable via conf `worker.player_max_xp_legacy`.
    int _playerMaxXpLegacy = 500;

    // Barème de niveaux — courbe quadratique. Le coût d'un niveau croît LINÉAIREMENT :
    // passer de n à n+1 coûte `_xpPerLevel · (n + 1)` XP (1→2 = 100, 2→3 = 150, 3→4 = 200…).
    // L'XP cumulé pour ATTEINDRE le niveau N vaut donc `_xpPerLevel · (N·(N+1)/2 − 1)` :
    // Nv.2 = 100, Nv.3 = 250, Nv.4 = 450, Nv.5 = 700. Compromis entre le linéaire (les niveaux
    // défilent à l'infini et ne signifient plus rien) et le fibonacci (le prochain niveau
    // devient vite inatteignable) : les niveaux ralentissent sans jamais créer de mur.
    // `_xpPerLevel` est le pas de progression ; le 1er niveau coûte `2 · _xpPerLevel` (= 100 XP).
    // Surchargé depuis la conf `worker.xp_per_level` au démarrage (cf. _loadTuning).
    int _xpPerLevel = 50;

    // Barème CLAN — copié du barème joueur mais ×`_clanXpFactor` (facteur sur le pas) :
    // avec le défaut (×10) : Nv.2 = 1000, Nv.3 = 2500, Nv.4 = 4500, Nv.5 = 7000. Même courbe,
    // montée plus lente. Le pas clan se dérive du pas joueur → un seul barème à régler.
    // Surchargé depuis la conf `worker.clan_xp_factor` au démarrage (cf. _loadTuning).
    int _clanXpFactor = 10;

    // Plafond du butin d'un clan : au-delà, le butin ne gagne plus d'XP. Le plafond borne le butin
    // du CYCLE COURANT (cf. _butinCourant), pas le compteur cumulé. À ne pas confondre avec
    // _butinGainMaxXp, qui borne UN SEUL crédit : celui-ci dit quand le coffre est plein, l'autre à
    // quelle vitesse il peut se remplir.
    // Surchargé depuis la conf `worker.butin_max_xp` au démarrage (cf. _loadTuning).
    int _butinMaxXp = 1000;

    // Facteur de conversion XP-clan → butin, valeur d'AMORÇAGE. Le facteur réellement appliqué
    // est celui du doc clan (`clans.butin_xp_factor`), lu à chaque crédit par _creditClanButin :
    // il est modifiable en cours de partie, ce que la conf (lue une seule fois au démarrage, et
    // commune à toutes les familles) ne permet pas. Ce champ ne sert donc qu'à deux choses :
    // amorcer le champ du clan à sa création, et servir de repli aux clans créés avant son
    // introduction. Défaut 1 (même quantité). Surchargé depuis la conf `worker.butin_xp_factor`.
    int _butinXpFactor = 1;

    // Plafond de BASE d'UN SEUL crédit au butin (et non du cycle, cf. _butinMaxXp), valeur
    // d'AMORÇAGE. Le plafond réellement appliqué est celui du doc clan (`clans.max_xp_butin`), lu à
    // chaque crédit par _creditClanButin, +20×niveau du clan (cf. _capForLevel) — même statut que
    // _butinXpFactor : n'amorce le champ du clan qu'à sa création, et sert de repli aux clans créés
    // avant son introduction. Surchargé depuis la conf `worker.butin_gain_max_xp`.
    int _butinGainMaxXp = 50;

    // Ce que le plafond ci-dessus gagne PAR NIVEAU du CLAN — miroir exact de _playerMaxXpPerLevel
    // côté joueur : 70 au niveau 1, 250 au niveau 10. Surchargé depuis la conf
    // `worker.butin_gain_max_xp_per_level`.
    int _butinGainMaxXpPerLevel = 20;

    // Seuils du verdict porté par la notification de dépôt au coffre, en POURCENTAGE de la
    // moyenne des 20 derniers butins ouverts (cf. _announceChestDeposit) : en dessous du premier
    // le dépôt est dérisoire, au-dessus du second c'est un trésor. Entre les deux, le message
    // part sans commentaire. Surchargés depuis la conf `worker.chest_low_pct`/`chest_high_pct`.
    int _chestLowPct  = 20;

    int _chestHighPct = 180;

    // Mémoire de session des plafonds d'XP lus, par joueur. L'écran de combat rebâtit son badge à
    // chaque appear : sans ce cache, chaque ouverture coûterait une lecture Firestore de plus.
    final Map<String, int> _maxXpCache = {};

    // -------------------------------------------------------------------------
    // --- Mode CHEF : administration des tiroirs (lot UI — rien n'est câblé)
    // -------------------------------------------------------------------------
    // Le chef de clan est AUSSI un joueur : on ne taxe donc pas sa boucle de jeu d'un menu à chaque
    // tap. Un switch « Jeu | Admin » (commons/mode_game + commons/mode_admin, en bas du tiroir)
    // bascule entre :
    //   - mode JEU   : le tiroir est celui d'aujourd'hui (les selectors ne renvoient que l'option
    //                  seule → DvTiroir lance la tâche directement, sans ouvrir de menu) ;
    //   - mode ADMIN : le tap ouvre commons/tiroir_menu, les tâches cachées réapparaissent (grisées,
    //                  croix rouge), une tuile « + » s'ajoute en fin de grille (icône injectée, pas
    //                  un bouton flottant : elle vit DANS le tiroir), la bordure vire au rouge.
    // Le tiroir CHANGE DE LANGUE selon le mode : en mode admin on ne pousse plus les statuts de jeu
    // (assigned/validating/dead/cure/review) mais des statuts d'administration — d'où la
    // disparition automatique des flammes, crânes, mains et barres de respawn, sans code de rendu.
    // L'apparence des icônes, elle, ne change PAS de grammaire : actives en couleur (en tête),
    // désactivées en grisé, cachées en grisé + croix rouge (en queue) — même tri qu'en jeu.
    bool _adminMode = false;

    // L'état d'administration (activé/désactivé/caché) n'est plus un mock mémoire : il vit dans la
    // conf — domains.<d>.{visible,enabled} et tasks.<id>.{visible,enabled} — miroir de Firestore,
    // et il est persisté sur 3 surfaces (conf + layer runtime + Firestore) par _admApply.
    // Cf. _iconVisible / _iconEnabled / _buildEnabledMap / _buildHiddenStatusMap.

    // Bordure d'origine de chaque tiroir, capturée avant de la repeindre en mode chef.
    final Map<String, dynamic> _tiroirBorder = {};

    final String _admBorderColor = "0xFFB03030";   // rouge : « tu es en train d'administrer »

    final String _defBorderColor = "0xFFB07328";   // or donjon : bordure des 20 tiroirs

    // Segments du switch « Jeu | Admin » : sélectionné = or plein / texte noir, sinon sombre / or.
    final String _segOnBg  = "#C8A84B";

    final String _segOnFg  = "black";

    final String _segOffBg = "0xF01A1A1A";

    final String _segOffFg = "#C8A84B";

    // Tuile « + » (ajouter une TÂCHE) : une icône INJECTÉE dans la grille en mode admin, et non un
    // bouton flottant par-dessus — elle vit dans le tiroir, avec les autres, et ferme la marche.
    // Liste vide en mode jeu → la grille revient exactement à sa config.
    // Le canal update_extras est GLOBAL (les 20 tiroirs) : c'est la grille des domaines qui la
    // refuse de son côté (combat/tiroir → extras_enabled: false), un chef ne créant pas de domaine.
    final String _admAddIcon = "adm_add";

    // Titre PORTÉ par le joueur (clans_players.title_idx) et, si chef, par le clan
    // (clans.title_idx) — -1 = aucun. Lu UNE FOIS par apparition de l'écran (et non dans
    // _loadClanItems, rejoué après chaque mutation, qui paierait sinon un read de plus à
    // chaque geste). Sert à griser l'option « Porter ce titre » du titre déjà porté
    // (items_selector) et à savoir quoi remettre à -1 quand on le jette (item_trash).
    int _playerTitleIdx = -1;

    int _clanTitleIdx   = -1;

    // Énumère clans_items/{clanId}/items et pousse les items VISIBLES au DvExplorer.
    // Règle de visibilité : un joueur ne voit que les items dont il est `owner` ; un admin voit
    // en plus ceux qui appartiennent au clan (owner == clanId). Le filtre est fait ici faute de
    // filtre serveur dans dvcloud.list.
    // LIMITE ASSUMÉE : ce filtre est CLIENT. Depuis l'ouverture de l'écran à tous les joueurs, le
    // contenu du coffre n'est caché que par l'app — un client modifié le lirait. Le durcir demande
    // une règle Firestore sur `owner` dans clans_items (le clanSecret étant partagé, elle devra
    // s'appuyer sur l'identité du lecteur) : c'est une étape à part.
    // Les items DANS le coffre (owner == "butin") ne correspondent à aucun des deux cas : ils
    // disparaissent donc de la grille sans traitement particulier — c'est tout l'intérêt de la
    // sentinelle (cf. _butinOwner).
    // Miroir local des documents lus, et clan auquel il appartient. C'est la seule source de ce
    // que la grille montre : le garder permet de refléter un déplacement à l'instant où il est
    // écrit, sans relire la collection. Indispensable, car revenir d'un écran empilé (le coffre)
    // n'émet PAS `appear` mais `show` — sans miroir, personne ne relirait la base et l'objet
    // déplacé resterait invisible alors qu'il est bien enregistré.
    List<Dvidle> _clanItemDocs = [];

    String       _clanItemsOf  = "";

    // Types dont un item appartenant au CLAN se montre à TOUS ses membres (clef `shared` du
    // catalogue — aujourd'hui, le titre de clan). Calculé ici parce que _pushClanItems est
    // SYNCHRONE (c'est ce qui lui permet de refléter une mutation à l'instant où elle est écrite,
    // sans aller-retour réseau) alors que lire le catalogue de types est asynchrone. Le catalogue
    // reste la source de vérité, on n'en garde qu'une empreinte pour les types réellement présents.
    final Set<String> _sharedItemTypes = {};

    //-----------------------------------------------------------------------
    //-- Fiche d'un objet (option « Voir », commune à tout le catalogue) -----
    //-----------------------------------------------------------------------
    // item_view n'ouvre que la fiche (aucune lecture ni écriture) ; on_item_view_appear la
    // remplit depuis la charge déjà en main (aucun aller-retour réseau) ; on_item_view_apply
    // rejoue la première option MÉTIER que worker.items_selector accorde à cet item — porter un
    // titre, remettre dans le coffre, ouvrir le coffre… — sans connaître elle-même ce que ça
    // fait : la conf propose, items_selector arbitre, la fiche ne fait que relire cet arbitrage.

    // Objet actuellement affiché (charge brute reçue du menu : id/type/name/quantity/badge/cost/
    // owner/title_idx/options — la même que celle que reçoit items_selector). Vide = rien à voir.
    Map<String, dynamic> _viewedItem = const {};

    // Option retenue pour le bouton « Appliquer » de la fiche courante, posée par
    // on_item_view_appear et consommée par on_item_view_apply. Vide = bouton caché.
    String _viewedApplyKey = "";

    //-----------------------------------------------------------------------
    //-- Donner un objet d'inventaire à un joueur du clan --------------------
    //-----------------------------------------------------------------------
    // Deux temps, et rien n'est écrit avant le second : l'option « Donner » mémorise l'objet et
    // empile l'écran de choix (give_page) ; le tap sur une ligne joueur commet le don. La flèche
    // retour abandonne. L'objet ne quitte pas la base, il change juste de mains (champ `owner`) :
    // il disparaît de la grille du donneur et paraît dans celle du destinataire.
    // Le mobilier (coffre, bourse) ne se donne pas — il ne déclare pas l'option dans le catalogue.

    // Objet en cours de don, mémorisé par item_give et consommé par give_to_player : l'écran de
    // choix ne porte rien lui-même. Vide = aucun don en cours (le tap y devient inerte).
    String _giveItemId   = "";

    String _giveItemType = "";

    String _giveItemName = "";

    //-----------------------------------------------------------------------
    //-- Coffre du butin ----------------------------------------------------
    //-----------------------------------------------------------------------
    // Le coffre est un item comme un autre (type `butin`), à trois différences près, toutes
    // déclarées en conf : il est épinglé en haut au centre, il n'est pas saisissable, et il
    // accepte le dépôt de n'importe quel type (joker `drops: {"*": …}`).
    // Y déposer un item lui pose `owner = "butin"` : il quitte l'inventaire de tout le monde
    // sans quitter la base — on sait qu'il est dans le butin, personne ne le voit.
    // Le portefeuille (type `argent_poche`) naît DANS le coffre : il n'a donc jamais de tuile,
    // seulement une ligne dans la liste de contenu. Seule sa quantité bouge.
    // Rien de tout cela n'est journalisé : clans_logs est lisible par tout le clan, et le
    // contenu du coffre est censé rester une surprise.

    // Identifiants FIXES des deux documents : un seul coffre et un seul portefeuille par clan.
    // C'est ce qui rend leur création idempotente (rejouable à chaque ouverture de l'écran).
    final String _butinDocId  = "butin";

    final String _walletDocId = "wallet";

    //-----------------------------------------------------------------------
    //-- La fée (worker_fairy.dart) ----------------------------------------
    //-----------------------------------------------------------------------
    //
    // Elle vit dans un TROISIÈME document fixe de clans_items, à côté du coffre et du
    // portefeuille : un seul état de fée par clan, donc un identifiant en dur, donc une écriture
    // idempotente. Il porte à la fois l'horloge des trente jours, la fenêtre de dix minutes,
    // l'endroit où elle se tient et les deux cadeaux tirés — deux appareils voient rigoureusement
    // la même fée, aux mêmes mains.
    // Ce n'est PAS un item du coffre : le filtre de _loadClanItems l'écarte comme les autres
    // documents à identifiant fixe (aucun champ `type`, aucun `owner`).
    final String _fairyDocId  = "fairy";

    // Identifiant de sa TUILE dans le tiroir. Injectée au runtime par dvtiroir.update_additions,
    // elle n'existe dans aucune config. Sans `__` (réservé aux clones {base}__{uid}), et ne
    // correspond ni à un domaine ni à un id du catalogue de tâches : aucune collision possible.
    final String _fairyIconId = "fairy";

    // Ce que le TIROIR doit afficher, en RAM. Il se reconstruit à chaque entrée d'écran et ne peut
    // pas se payer une lecture cloud à chaque fois : ces trois champs sont sa seule source. Vides
    // = aucune fée. Rafraîchis au tirage, par la vigilance, et à l'expiration.
    String _fairyDomain  = "";
    String _fairyTaskId  = "";   // la monstre-tâche dont elle prend la place
    String _fairyExpires = "";

    // Les deux cadeaux de la fée EN COURS, figés à la prise et consommés par fairy_page (qui est
    // tirée par la conf et ne reçoit donc aucun argument). Même procédé que _deathGage.
    String _fairyGiftLeft  = "";
    String _fairyGiftRight = "";

    // Gardes de ré-entrance. _fairyTaking : deux taps sur la tuile pendant l'aller-retour réseau
    // de la prise. _fairyResolving : les deux mains tapées coup sur coup — un seul cadeau.
    bool _fairyTaking    = false;
    bool _fairyResolving = false;

    // La musique de la fée tourne EN BOUCLE (elle reste tant qu'on n'a pas choisi), contrairement
    // à toutes les autres célébrations. Le drapeau évite de re-suspendre l'ambiance, et coupe un
    // chargement encore en vol pour qu'il n'amorce pas la boucle après coup (cf. _combatSiegeOn).
    bool _fairyMusicOn = false;

    // Vigilance temps réel sur le doc de la fée : c'est elle qui la fait disparaître chez les
    // autres dès que l'un du clan l'a touchée. Armée seulement tant qu'une fenêtre est ouverte.
    DvVigilance? _fairyVigilance;

    // Minuterie des dix minutes. Il n'y a AUCUN cron : la fenêtre est tenue côté client (et toute
    // lecture recompare `expires_at` à l'heure courante, donc un appareil endormi n'est jamais dupe).
    Timer? _fairyExpiryTimer;

    // Propriétaire sentinelle des items DANS le coffre : ne vaut ni un userId ni un clanId, donc
    // le filtre de _loadClanItems les écarte tout seul.
    final String _butinOwner  = "butin";

    // Propriétaire sentinelle d'un item EN TRANSIT : le butin a été distribué, cet objet a un
    // destinataire (champ `to_owner`) mais celui-ci ne l'a pas encore réclamé. Même vertu que
    // _butinOwner — invisible de tous — mais il a QUITTÉ le coffre : sans ça le coffre paraîtrait
    // encore plein entre la distribution et la dernière réclamation.
    final String _openingOwner = "opening";

    final String _crossImage  = "images/small/adm_cross.png";

    // Icône « + » du contenu du coffre (bourse, ligne « Ajouter une note ») : même image que la
    // tuile « + » du tiroir admin (worker_tasks.dart, adm_add_task) — l'app n'a qu'un seul signe
    // pour « ajouter ».
    final String _addImage    = "images/small/adm_add.png";

    // Titres (première famille d'items) : docId DÉTERMINISTE, un par rang — même vertu que
    // `butin`/`wallet_<userId>`, un palier rejoué (deux appareils, une relance) réécrit le même
    // document au lieu d'en créer un second. Pas de sentinelle d'owner dédiée : il n'y a pas de
    // rattrapage, donc rien à protéger d'une résurrection — « à la poubelle » supprime le document.
    final String _playerTitleType = "titre_perso";

    final String _clanTitleType   = "titre_clan";

    // BROUILLON de l'écran butin_page, vidé à chaque ouverture. Rien n'est écrit en base tant que
    // « Valider » n'est pas touché : taper une ligne ne fait que marquer une intention, ce qui rend
    // le tap accidentel sans conséquence (et l'annulation gratuite : on retape, ou on s'en va).
    List<Map<String, dynamic>> _butinRows = [];   // lignes chargées, telles que lues en base

    final Set<String> _butinTaken = {};           // objets marqués comme sortis du coffre

    int _butinMoneyAdd = 0;                       // argent promis, pas encore écrit

    // Part reçue à l'ouverture du butin, figée entre la réclamation (_claimButin, qui écrit) et
    // l'écran de récompenses (qui ne fait qu'afficher). L'écran est empilé PENDANT l'animation :
    // il ne peut pas relire la base, où tout a déjà changé de mains.
    List<Map<String, dynamic>> _butinClaimRows = [];

    // L'attaque de bisous : le petit mot qui nomme celui qui a le moins rapporté d'XP, figé au même
    // moment que la part et pour la même raison. VIDE sur l'appareil du principal intéressé — on ne
    // dit pas à un enfant qu'il est dernier, on le dit aux autres pour qu'ils viennent l'embrasser.
    String _butinKissText = "";

    // --- Notes du coffre (annonces des chefs) -----------------------------------------------
    // Un chef peut déposer PLUSIEURS notes : chacune a son propre id (_generateUuid), et sa
    // ligne dans le contenu du coffre (butin_page/list) s'écrit "<préfixe><id>" — jamais un docId
    // réel de clans_items, ne peut donc pas entrer en collision. Son tap la SUPPRIME directement
    // (worker.on_butin_row_tap → worker._deleteButinNote), pas d'écran d'édition : une note ne se
    // corrige pas, elle se retire (au besoin on en redépose une autre).
    final String _noteRowPrefix = "note_";

    // Ligne « Ajouter une note », toujours présente dans le contenu du coffre (contrairement aux
    // lignes de notes, qui n'apparaissent que si j'en ai déjà déposé). Id fixe, distinct du
    // préfixe ci-dessus pour ne jamais être pris pour une note existante.
    final String _addNoteRowId = "add_note";

    // Notes révélées par la dernière ouverture, figées à la réclamation (worker._claimButin) pour
    // la même raison que _butinClaimRows : butin_notes_page ne lit rien, la base a déjà tout vidé.
    // Déjà mis en forme (Markdown, un bloc par note) — VIDE si personne n'en a écrit, ce qui fait
    // sauter l'écran (worker.on_butin_rewards_ok).
    String _butinNotesText = "";

    // Jeton du minuteur de lecture forcée (10 s) de butin_notes_page : incrémenté à chaque
    // apparition de l'écran, il écarte un minuteur d'un affichage précédent qui révélerait le
    // bouton « ok » d'un écran qu'on a déjà quitté.
    int _butinNotesTick = 0;

    // --- Écran money_page (saisie d'une somme) ---------------------------------------------
    // Trois modes, un seul écran : "promise" = promesse d'argent RÉEL versée au coffre (elle
    // rejoint le brouillon ci-dessus), "deposit" = un chef remet SON argent de poche dans le
    // coffre (écriture immédiate), "pay" = un chef VERSE le tribut d'un joueur, c'est-à-dire lui
    // remet pour de vrai l'argent gagné en jeu, qui quitte alors la bourse de ce joueur.
    // Posés par l'appelant AVANT navigate_new.
    final String _moneyPromise = "promise";

    final String _moneyDeposit = "deposit";

    final String _moneyPay     = "pay";

    // Littéral dupliqué (et non `= _moneyPromise`) : un initialiseur de champ d'instance ne peut
    // pas lire un autre champ d'instance via `this` (contrainte du compilateur, pas un choix).
    String _moneyMode = "promise";

    // Mode "pay" seulement : à qui l'on verse (id du membre) et son nom, pour l'avertissement.
    String _moneyPayTarget = "";

    String _moneyPayName   = "";

    // Plafond de la saisie, 0 = AUCUN. Il n'y en a pas pour une promesse : on ne connaît pas la
    // monnaie du joueur, et là où une baguette vaut 100 000 un maximum n'a aucun sens. Pour un
    // retour au coffre, c'est le solde de la bourse — on ne rend pas ce qu'on n'a pas.
    int _moneyCap = 0;

    // Garde anti double-tap : en mode dépôt, « Valider » écrit vraiment.
    bool _moneyBusy = false;

    // Seul garde-fou de saisie, TECHNIQUE et non monétaire : au-delà, on sortirait de l'entier sûr
    // et le nombre déborderait de son cadre. Une frappe supplémentaire est simplement ignorée.
    final int _moneyDigitsMax = 12;

    // Durée de vie du verrou (30 min). Généreuse à dessein : elle doit couvrir un rituel entier,
    // discussions comprises. Si le meneur abandonne (app fermée, batterie morte), le verrou meurt
    // tout seul et un autre chef peut reprendre la cérémonie — c'est la seule porte de sortie.
    final int _openingLockMs = 1800000;

    // --- Historique des butins + annonce d'un dépôt ----------------------------------------
    // `clans_chest_history/{clanId}/history` garde une ligne par butin OUVERT : montant du
    // portefeuille, or, valeur des objets contenus, nombre de joueurs, part du meilleur
    // contributeur. Rien ici ne l'écrit : la cérémonie d'ouverture du butin (celle qui recalera
    // `clans.last_butin_xp` et videra le coffre) n'existe pas encore, et c'est elle qui
    // l'alimentera. Ce qu'on lit, c'est la MOYENNE des 20 derniers, pour situer ce qu'on vient
    // de déposer : tant que la table est vide, aucun verdict n'est porté et l'annonce part nue.
    //
    // La table est append-only (create seul, cf. les règles), et rien ne la purge : elle ne
    // porte donc que des agrégats chiffrés — jamais un nom d'objet ni un identifiant de joueur.

    final String _chestHistColl = "clans_chest_history";

    // Profondeur de la moyenne : on ne regarde que les derniers butins, pas toute l'histoire du
    // clan (un foyer change d'habitudes, la référence doit suivre).
    final int    _chestHistDepth = 20;

    // --- Boutique (dvstore) --------------------------------------------------
    // Produit sélectionné dans la liste de la boutique, le temps d'ouvrir sa fiche
    // (même mécanique que _giveItemId pour give_page).
    String _storeProductId = "";

    // Périodicité choisie sur l'écran d'abonnement : "monthly" ou "yearly". Ce
    // n'est qu'une préférence d'affichage/achat, jamais un état commercial —
    // celui-là appartient au serveur.
    String _storePeriod = "monthly";

    // Achat mis de côté le temps du contrôle parental : dvparentalgate empile son
    // écran et rappelle worker.store_gate_passed, l'achat ne peut donc pas rester
    // sur la pile d'appel. Vidé au rappel comme à l'abandon (le suivant l'écrase).
    String _storePendingBuy = "";

    // Offre associée à l'achat mis de côté, portée avec lui à travers la porte
    // parentale. null = celle que le serveur juge éligible ; "" = tarif courant
    // sans aucune offre (reprise après gel : on ne redonne pas l'essai gratuit à
    // chaque défaut de paiement). Voir dvstore.buy — la distinction est une règle
    // commerciale, pas une commodité.
    String? _storePendingOffer;

    // La RAISON d'une venue commerciale (plafond de joueurs atteint, relance
    // d'impayé) n'est pas une variable de worker : _storeGotoTiers la publie dans
    // `worker.store.notice`, que `tiers_page` peint en tête d'écran. Une chaîne en
    // mémoire ici n'appartiendrait qu'à un écran, et l'information vaut mieux que ça.

    // Dernier ratage du banc d'essai (pas de clan sous la main pour envoyer la
    // relance). Affiché tel quel sur le bandeau de l'écran de scénarios : un banc qui
    // échouerait en silence est pire que pas de banc du tout — on croirait éprouver
    // ce qu'on n'éprouve pas. Mémoire seule, remis à zéro à chaque tentative.
    String _storeBenchError = "";

    dvcloud?     get _cloud     => Deva.instance.module("dvcloud")     as dvcloud?;
    dvmessaging? get _messaging => Deva.instance.module("dvmessaging") as dvmessaging?;
    dvcamera?    get _camera    => Deva.instance.module("dvcamera")    as dvcamera?;
    dvstore?     get _store     => Deva.instance.module("dvstore")     as dvstore?;

    worker([super.kwargs]);

    @override
    String get name => "worker";

    //-----------------------------------------------------------------------
    //-- Lifecycle ----------------------------------------------------------
    //-----------------------------------------------------------------------

    @override
    void define() { deva_set("worker.session.defined", "true"); }

    @override
    Future<void> register() async {

                                ModuleRegistry.register('modules.worker.worker', () => worker());
                                _register_session();
                                _register_clan();
                                _register_members();
                                _register_tasks();
                                _register_forms();
                                _register_avatars();
                                _register_screen_personnage();
                                _register_screen_clan();
                                _register_screen_tiroir();
                                _register_admin();
                                _register_combat();
                                _register_verdict();
                                _register_celebrations();
                                _register_items();
                                _register_butin();
                                _register_chest();
                                _register_notify();
                                _register_log();
                                _register_store();
                                _register_fairy();
    }

    @override
    Future<void> invoke() async {

                                await _loadTuning();
                                await on_login(null, null);
                                deva_set("worker.session.invoked", "true");
                                deva_log("info", "Module worker invoked");
    }

}


// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
