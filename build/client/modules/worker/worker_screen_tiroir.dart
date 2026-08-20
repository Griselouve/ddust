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

part of 'worker.dart';

// -----------------------------------------------------------------------------
// --- Globals shortcuts and miscellaneous
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- worker extension — Écran Tiroir (dashboard, admin)
// -----------------------------------------------------------------------------
extension Worker_screen_tiroir on worker {

    void _register_screen_tiroir() {

                                // Écran de mort (0 PV) : détection au lancement (dashboard) et tap avalé par le scrim.
                                ActionRegistry.register("worker.on_dashboard_appear",       on_dashboard_appear);

                                // Sélecteurs des tiroirs : option seule (= tap courant) en mode JEU, options
                                // d'administration en mode CHEF (cf. _tiroirSelector).
                                ActionRegistry.register("worker.domain_selector",           domain_selector);

                                ActionRegistry.register("worker.task_selector",             task_selector);

                                // Administration du tiroir par le chef de clan (bascule + options du menu).
                                // Lot UI : les actions ne font que journaliser et muter un état EN MÉMOIRE.
                                ActionRegistry.register("worker.set_mode_game",             set_mode_game);

                                ActionRegistry.register("worker.set_mode_admin",            set_mode_admin);

                                ActionRegistry.register("worker.on_tiroir_appear",          on_tiroir_appear);

    }

    //-----------------------------------------------------------------------
    //-- Mort du joueur (0 PV) : overlay crâne + gage sur tous les écrans ----
    //-----------------------------------------------------------------------

    // Affichage du dashboard (au lancement) : point de détection de la mort demandé.
    // Point d'atterrissage après un verdict REFUSÉ (_resolveValidation → navigate_reset("dashboard")) :
    // moment naturel pour (re)détecter une montée de niveau fraîchement créditée. NB : un verdict
    // ACCEPTÉ va sur "combat" (le tiroir) et célèbre via _celebrateAfterAccept, pas ici.
    Future<void> on_dashboard_appear(dynamic caller, dynamic event) async {

                                _stopCombatSiege();   // anti-fuite : coupe le son de combat si on quitte via la taskbar

                                // CLAN GELÉ (J50 du calendrier de défaut de paiement) : le donjon se
                                // ferme, ici et une seule fois. Le dashboard est le passage obligé de
                                // tout joueur enrôlé — le garder suffit à garder les 25 écrans de jeu,
                                // sans en instrumenter aucun.
                                //
                                // C'est la SEULE porte fermée du jeu, et elle ne l'est qu'au terme de
                                // 50 jours de relances adressées aux adultes. Avant cela, on entre
                                // toujours : ni l'essai fini, ni l'impayé en cours ne barrent quoi que
                                // ce soit — c'est la page des paliers qui porte l'offre, et le bandeau qui
                                // prévient. Ce qui justifie de fermer au bout du compte n'est pas la
                                // sanction, c'est le coût : Firestore, Storage et VertexAI sont
                                // facturés à l'éditeur, et un clan qui ne paie plus depuis deux mois
                                // continuait de les consommer.
                                if (await _storeLocked()) {
                                    deva_log("info", "[store] clan gelé — donjon fermé");
                                    DvOrb.navigate_reset("locked_page");
                                    return;
                                }

                                // Rappel d'impayé : doux, réservé aux chefs de clan, et seulement une
                                // fois le cycle de relance entamé côté serveur. Évalué ICI pour la même
                                // raison — un seul appel peuple les écrans déjà montés comme ceux qui
                                // naîtront ensuite.
                                await _evaluateDunning();

                                // Arme la vigilance temps réel du doc joueur : à partir d'ici (tout joueur enrôlé
                                // passe par le dashboard) la montée de niveau est détectée sur n'importe quel écran,
                                // pas seulement à l'affichage de dashboard/personnage. Idempotent.
                                await _ensurePlayerVigilance();

                                // LA FÉE. Le dé est jeté ici, et nulle part ailleurs : le dashboard est le
                                // seul écran par lequel passe TOUT joueur enrôlé, et c'est le plus fréquenté.
                                // Placé AVANT le `return` de la bienvenue clan (plus bas) pour que ce chemin-là
                                // arme la vigilance lui aussi.
                                // Aucun risque de collision avec les célébrations qui suivent : le tirage
                                // n'affiche rien, il écrit un document. Ce qui se voit, la tuile, n'apparaît
                                // que dans un tiroir de domaine — deux écrans plus loin.
                                // _rollFairy avale toutes ses exceptions : l'écran d'accueil du jeu ne doit
                                // pas dépendre du bon vouloir d'une fée.
                                await _rollFairy();

                                // 1re arrivée après création/rejoint : la bienvenue clan, s'il y en a une.
                                final welcomed = await _playPendingClanWelcome();

                                // Atterrissage après validation / lancement : level-up, mort (overlay) et soin,
                                // dans l'ordre géré par _onPlayerDocChanged (le level-up qui ressuscite supprime
                                // lui-même l'animation de soin).
                                await _onPlayerDocChanged();

                                // Bienvenue clan en cours : ce handler NE déclenche PAS le tutoriel. C'est la fin
                                // de l'animation qui l'ouvre (worker.on_celebration_end → _enterTutoAfterWelcome).
                                // L'attendre depuis ici rendait la leçon otage de tout ce qui précède — lectures
                                // cloud, autres célébrations, préemption de la bienvenue — et `dvtuto.enter`
                                // renonce EN SILENCE s'il tombe pendant un interlude, sans seconde chance (le
                                // retour par la taskbar émet `show`, pas `appear`).
                                if (welcomed) return;

                                // Arrivée ordinaire sur le dashboard : le tutoriel EN DERNIER, et jamais depuis la
                                // liste `appear` de la conf : une liste d'actions n'est pas awaitée (DvView exécute
                                // la séquence sans await), si bien que dvtuto.enter partait en parallèle de ce
                                // handler et posait son voile par-dessus ce qui jouait. Même patron que
                                // on_combat_appear. Le drainage couvre les célébrations que _onPlayerDocChanged
                                // vient éventuellement de lancer (level-up, or, soin, mort).
                                await _waitInterludesIdle();
                                deva_log("info", "[tuto] entrée dashboard : seen.dashboard_intro="
                                    "${await deva_get("dvtuto.seen.dashboard_intro", false)}");
                                await deva_do("dvtuto.enter");
    }

    // Ids des 20 tiroirs (celui des domaines + les 19 de tâches).
    List<String> get _tiroirIds =>
        ["combat/tiroir", for (final d in _taskDomains) "${d}_tasks/tiroir"];

    // Bordure d'un tiroir selon le mode. Repli sur l'or donjon si l'originale n'a pas pu être
    // capturée : sans ça, un tiroir sans border_color en conf resterait rouge après la sortie.
    String _borderOf(String tid) => _adminMode
        ? _admBorderColor
        : (_tiroirBorder[tid]?.toString() ?? _defBorderColor);

    // Segments du switch « Jeu | Admin » (bas du tiroir). Réservés aux chefs vivants : mort,
    // l'écran est mangé par l'overlay de mort (et le switch, en layer overlay, se dessinerait
    // par-dessus le scrim). Taper le segment déjà actif ne fait rien.
    Future<void> set_mode_game(dynamic caller, dynamic event)  async => _setAdminMode(false);

    Future<void> set_mode_admin(dynamic caller, dynamic event) async => _setAdminMode(true);

    Future<void> _setAdminMode(bool admin) async {

                                if (!_isAdmin || _adminMode == admin) return;
                                if ((await deva_get("session.player_dead")) == true) return;
                                _adminMode = admin;
                                deva_log("info", "[admin] mode ${_adminMode ? "ADMIN" : "JEU"}");
                                await _applyAdminMode();
    }

    // Déclare au framework le vocabulaire visuel du tiroir pour le mode courant. SEUL endroit qui
    // décide de ce qui grise et de ce qui masque — les deux listes sont remplacées en bloc, donc
    // un appel suffit à basculer d'un mode à l'autre.
    //   - mode JEU  : grisent assigned/validating/dead + ce que le chef a désactivé ; masque ce
    //                 qu'il a caché (l'icône disparaît de la grille) ;
    //   - mode ADMIN : grise ce qui est désactivé ET ce qui est caché, masque ce qui est caché —
    //                 mais la RÉVÉLATION est active, donc les cachées ne disparaissent pas : elles
    //                 se rendent grisées, en queue de grille, avec la croix rouge de leur statut
    //                 (icons_shape.status_images). Les grisées redeviennent aussi cliquables, sans
    //                 quoi on ne pourrait pas les réactiver (le tiroir ne pose pas de geste dessus).
    void _declareTiroirVocabulary() {

                                // Le grisage « désactivé » ne passe plus par un statut : il vient du drapeau
                                // enabled (carte _buildEnabledMap). Ne restent en statut que les cachées
                                // (adm_hidden) et, en jeu, les overlays de cycle de vie.
                                ActionRegistry.get("dvtiroir.set_dimmed_statuses")?.call(null, _adminMode
                                    ? const ["adm_hidden"]
                                    : const ["assigned", "validating", "dead"]);
                                // `fairy_hidden` : la monstre-tâche dont la fée a pris la place. Masquée
                                // exactement comme une tâche cachée par un chef, mais sous un statut à
                                // elle — en mode révélation, un chef doit pouvoir distinguer « cachée par
                                // moi » (croix rouge) de « momentanément remplacée par une fée ».
                                ActionRegistry.get("dvtiroir.set_hidden_statuses")?.call(null,
                                    const ["adm_hidden", "fairy_hidden"]);
                                ActionRegistry.get("dvtiroir.set_reveal_mode")?.call(null, _adminMode);
                                _notifyTiroirExtras();      // tuile « + » présente en admin, absente en jeu
    }

    // Repeint les tiroirs selon le mode courant. Les canaux du framework (statuts, masquage,
    // grisage, respawn) sont des maps/listes REMPLACÉES EN BLOC : une bascule = un re-push complet.
    Future<void> _applyAdminMode() async {

                                try {
                                    // Le vocabulaire est posé EN PREMIER et sans condition : si la suite échoue
                                    // (réseau…), le tiroir reste au moins cohérent avec le mode courant.
                                    _declareTiroirVocabulary();
                                    if (_adminMode) {
                                        // Mode chef : grisage (enabled) et croix (visible) dérivés de la conf
                                        // (miroir de Firestore) — le chef voit l'état réel et peut le contredire
                                        // (réactiver un domaine fermé par l'arbre, réafficher une tâche cachée).
                                        _notifyTiroirDomains(await _buildEnabledMap());
                                        _notifyTiroirProgress(const {});        // pas de barres de respawn en mode admin
                                        _notifyTiroirStatuses(await _buildHiddenStatusMap());
                                    } else {
                                        // Restaure le grisage du jeu AVANT tout le reste : c'est la seule chose
                                        // qui, si elle manquait, laisserait le tiroir « tout activé » (régression
                                        // silencieuse : des domaines désactivés redeviendraient cliquables).
                                        if (_gameDomains.isNotEmpty) _notifyTiroirDomains(_gameDomains);
                                        await _refreshTaskStatuses();           // repousse les maps de jeu
                                    }
                                    await _syncChiefUi();
                                } catch (e) {
                                    deva_log("error", "[admin] _applyAdminMode FAILED: $e");
                                }
    }

    // ── État d'administration dérivé de la CONF ──────────────────────────────────────────────
    // Plus aucun état mémoire : la source est la conf (miroir de Firestore), donc partagée au
    // clan et durable. domains.<d>.{visible,enabled} / tasks.<id>.{visible,enabled}.

    // Lecture défensive d'un booléen de conf : absent/null ⇒ true (défaut historique).
    bool _flagTrue(dynamic raw) => raw == null ? true : (raw == true || raw.toString() == "true");

    // Espace de noms conf d'une icône : "domains" si l'id résolu (base, via _originalOf) est un
    // domaine câblé, sinon "tasks".
    String _iconNs(String iconId) =>
        _taskDomains.contains(_originalOf(iconId)) ? "domains" : "tasks";

    // visible / enabled d'une icône, lus sur la BASE (les clones {base}__{uid} en héritent).
    Future<bool> _iconVisible(String iconId) async =>
        _flagTrue(await deva_get("${_iconNs(iconId)}.${_originalOf(iconId)}.visible"));

    Future<bool> _iconEnabled(String iconId) async =>
        _flagTrue(await deva_get("${_iconNs(iconId)}.${_originalOf(iconId)}.enabled"));

    // Carte enabled (grisage) de TOUTES les icônes — domaines + tâches — lue dans la conf. Poussée
    // dans les deux modes : enabled:false grise en jeu (inerte) comme en admin.
    Future<Map<String, bool>> _buildEnabledMap() async {

                                final out     = <String, bool>{};
                                final domains = await deva_get("domains");
                                final tasks   = await deva_get("tasks");
                                for (final d in _taskDomains) {
                                    out[d] = _flagTrue(domains is Dvidle ? domains.get("$d.enabled") : null);
                                }
                                if (tasks is Dvidle) {
                                    for (final id in tasks.keys) {
                                        // enabled par-icône si présent (clones chargés sous leur id), sinon base.
                                        final raw = tasks.get("$id.enabled");
                                        out[id] = raw == null
                                            ? _flagTrue(tasks.get("${_originalOf(id)}.enabled"))
                                            : _flagTrue(raw);
                                    }
                                }
                                return out;
    }

    // Statut adm_hidden des icônes invisibles (visible:false), lu dans la conf. En jeu (reveal off)
    // ⇒ absentes de la grille ; en admin (reveal on) ⇒ grisées + croix rouge, donc atteignables
    // pour l'option « Montrer ».
    Future<Map<String, String>> _buildHiddenStatusMap() async {

                                final out     = <String, String>{};
                                final domains = await deva_get("domains");
                                final tasks   = await deva_get("tasks");
                                if (domains is Dvidle) {
                                    for (final d in _taskDomains) {
                                        if (!_flagTrue(domains.get("$d.visible"))) out[d] = "adm_hidden";
                                    }
                                }
                                if (tasks is Dvidle) {
                                    for (final id in tasks.keys) {
                                        if (!_flagTrue(tasks.get("${_originalOf(id)}.visible"))) out[id] = "adm_hidden";
                                    }
                                }
                                // La monstre-tâche que la FÉE remplace, le temps de sa visite. Statut
                                // distinct d'adm_hidden : elle n'est pas cachée par un chef, et le mode
                                // révélation doit pouvoir les distinguer. Posé EN DERNIER — si la tâche
                                // tirée était par ailleurs invisible, la fée n'aurait pas dû la choisir
                                // (_pickFairyTask filtre sur visible), mais l'ordre lève le doute.
                                if (_fairyHiddenTask.isNotEmpty) out[_fairyHiddenTask] = "fairy_hidden";
                                return out;
    }

    // Switch « Jeu | Admin » (chefs vivants) et bordure des tiroirs. N'agit QUE sur les shapes
    // montées : surtout PAS de deva_set ici. Muter le template de conf écrirait dans le layer
    // runtime, que _applyDeath flushe sur disque (store()) — mourir en mode admin persisterait des
    // tiroirs rouges jusqu'au prochain démarrage. Les pages ouvertes ensuite se synchronisent
    // elles-mêmes (action `appear` → on_tiroir_appear).
    Future<void> _syncChiefUi() async {

                                final bool dead       = (await deva_get("session.player_dead")) == true;
                                // Le switch suit le tiroir : masqué quand celui-ci l'est, c'est-à-dire en
                                // combat (session.active_task) ou en revue admin (session.review_task) —
                                // les deux mêmes conditions que on_combat_appear utilise pour cacher le tiroir.
                                final bool combatting =
                                    ((await deva_get("session.active_task"))?.toString() ?? "").isNotEmpty ||
                                    ((await deva_get("session.review_task"))?.toString() ?? "").isNotEmpty;
                                final bool showSwitch = _isAdmin && !dead && !combatting;

                                for (final p in DvPage.actives) {
                                    final game  = p.get_shape_by_id("commons/mode_game");
                                    final admin = p.get_shape_by_id("commons/mode_admin");
                                    if (showSwitch) { game?.show(); admin?.show(); }
                                    else            { game?.hide(); admin?.hide(); }
                                    // Segment sélectionné peint en or (texte noir), l'autre sombre (texte or).
                                    _paintSegment(game,  selected: !_adminMode);
                                    _paintSegment(admin, selected: _adminMode);

                                    for (final tid in _tiroirIds) {
                                        final t = p.get_shape_by_id(tid);
                                        if (t == null) continue;
                                        // Bordure d'origine capturée sur la shape elle-même, avant de la repeindre.
                                        if (!_tiroirBorder.containsKey(tid)) {
                                            _tiroirBorder[tid] = t.get("shape.border_color");
                                        }
                                        t.set("shape.border_color", _borderOf(tid));
                                        t.refreshUI();
                                    }
                                }
    }

    void _paintSegment(dynamic seg, {required bool selected}) {

                                if (seg == null) return;
                                seg.set("shape.background_color", selected ? _segOnBg  : _segOffBg);
                                seg.set("shape.font_color",       selected ? _segOnFg  : _segOffFg);
                                seg.refreshUI();
    }

    // `appear` des 19 écrans <domaine>_tasks : ils n'avaient pas d'action d'entrée (le rafraîchis-
    // sement se fait dans le prefix handler seldomain, AVANT la navigation — donc avant que leurs
    // shapes existent). Le switch doit, lui, être posé une fois la page montée.
    Future<void> on_tiroir_appear(dynamic caller, dynamic event) async {

                                // Ces 19 écrans <domaine>_tasks portent la taskbar (mask page_taskbar), qui
                                // arme un retour vers "dashboard". Or on y arrive depuis combat (le tiroir des
                                // domaines) : le retour doit y ramener, pas au dashboard. On écrase la cible
                                // APRÈS le montage de la taskbar — make() l'invoque (→ _registerBackTarget)
                                // avant que l'appear ne se déclenche (cf. dvpage_motor), donc combat gagne.
                                // combat, lui, garde "dashboard" : il a son propre appear (on_combat_appear),
                                // on_tiroir_appear ne tourne QUE sur les 19 écrans de tâches.
                                DvOrb.get_current_page()?.set("back_target", "combat");
                                await _syncChiefUi();
                                await deva_do("dvtuto.enter");   // déclenche les leçons de tutoriel des écrans de tâches
    }

    // Sélecteurs des tiroirs domaines/tâches — même règle pour les deux (l'id de l'icône suffit).
    Future<Map<String, dynamic>> domain_selector(dynamic caller, dynamic data) async =>
        _tiroirSelector(data);

    Future<Map<String, dynamic>> task_selector(dynamic caller, dynamic data) async =>
        _tiroirSelector(data);

    // Mode JEU : aucune option → DvTiroir exécute l'option seule (= le tap courant, echo de
    // data["tap"] : seldomain.cuisine / seltask.salon_01). Iso-fonctionnel, aucun menu.
    // Mode CHEF : options selon l'état (visible, enabled) lu dans la conf. Règles :
    //   - visible:false                → « Montrer » (adm_show) uniquement ;
    //   - visible:true, enabled:false  → « Activer » (adm_enable) + « Cacher » (adm_hide) ;
    //   - visible:true, enabled:true   → « Désactiver » (adm_disable).
    Future<Map<String, dynamic>> _tiroirSelector(dynamic data) async {

                                final m   = (data is Map) ? data : const {};
                                final tap = m["tap"]?.toString() ?? "";
                                final id  = m["id"]?.toString() ?? "";
                                // La tuile « + » est un OUTIL, pas un élément administrable : pas de menu
                                // dessus, son action s'exécute directement (option seule).
                                if (!_adminMode || id == _admAddIcon) {
                                    return {"selectable": <String>[], "disabled": <String>[], "single": tap};
                                }

                                final options = <String>[];
                                // Icône de DOMAINE (tap seldomain.<d>) : proposer d'abord « Voir les tâches »
                                // → ouvre le sous-tiroir sans quitter le mode admin. Absent des feuilles (seltask.).
                                if (tap.startsWith("seldomain.")) options.add("adm_tasks");
                                if (!await _iconVisible(id)) {
                                    options.add("adm_show");
                                } else if (!await _iconEnabled(id)) {
                                    options.addAll(["adm_enable", "adm_hide"]);
                                } else {
                                    options.add("adm_disable");
                                }
                                // Statut de la tâche — par-instance → id d'icône RÉEL (un clone
                                // {base}__{uid} porte sa propre assignation). Défaut "alive" (cf. init doc
                                // joueur). Vide sur un domaine : son état de combat n'a pas de sens.
                                final st = tap.startsWith("seltask.")
                                    ? ((await deva_get("tasks.$id.status"))?.toString() ?? "alive")
                                    : "";
                                // « Laisser tomber » : la tâche est TENUE par un joueur — "assigned" (combat
                                // en cours) ou "validating" (preuve déposée, verdict en attente). Le chef la
                                // relâche : elle redevient libre pour tout le clan. Porte de sortie quand le
                                // porteur a disparu (app désinstallée, joueur parti du clan) et laisse la
                                // tâche orpheline jusqu'au respawn.
                                if (st == "assigned" || st == "validating") options.add("adm_release");
                                // « Ressusciter » : remise à neuf immédiate — feuilles de tâche uniquement
                                // (jamais un domaine, dont l'état de combat n'a pas de sens), et seulement
                                // si la tâche n'est PAS déjà vivante (inutile de ressusciter un vivant).
                                if (st.isNotEmpty && st != "alive") {
                                    options.add("adm_revive");
                                }
                                // « Recommander » / « Ne plus recommander » (boss) : feuilles de tâche
                                // uniquement, l'une OU l'autre selon que la tâche porte déjà le statut boss
                                // (recommended non vide). L'état est par-instance → on lit l'id d'icône réel
                                // (pas la base).
                                if (tap.startsWith("seltask.")) {
                                    final rec = (await deva_get("tasks.$id.recommended"))?.toString() ?? "";
                                    options.add(rec.isEmpty ? "adm_recommend" : "adm_unrecommend");
                                }
                                options.add("adm_edit");
                                return {"selectable": options, "disabled": <String>[], "single": ""};
    }

}

// -----------------------------------------------------------------------------
// --- Let's go
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- To be continued...
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
