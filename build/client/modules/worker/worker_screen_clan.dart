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
// --- worker extension — Écran Clan
// -----------------------------------------------------------------------------
extension Worker_screen_clan on worker {

    void _register_screen_clan() {

                                ActionRegistry.register("worker.on_clan_appear",            on_clan_appear);

                                // Menu contextuel joueur (écran Clan) : sélecteur d'options + actions métier.
                                // L'ouverture/bascule du menu est gérée par DvRoster lui-même (rien à câbler ici).
                                ActionRegistry.register("worker.clan_selector",             clan_selector);

                                ActionRegistry.register("worker.clan_roster_sort",          clan_roster_sort);

    }

    // Affichage de l'écran « Clan » : copie de on_personnage_appear, mais lit l'xp du CLAN
    // (workers/clans/{clanId}.xp) et dérive niveau/progression avec le barème clan
    // (getClanNiveauProgres / _xpForNiveauClan, ×10). Barre/flamme/badge/XP identiques à
    // l'écran personnage ; dimensions de cadrage LUES depuis les shapes clan_page/lvl_*.
    Future<void> on_clan_appear(dynamic caller, dynamic event) async {

                                _stopCombatSiege();   // anti-fuite : coupe le son de combat si on quitte via la taskbar
                                // Filet de la cérémonie du butin : le joueur qu'on a appelé de vive voix vient
                                // souvent voir le clan de lui-même. Ce passage le ramène au coffre même si ni la
                                // notification ni la vigilance n'ont su le prévenir.
                                await _ensurePlayerVigilance();
                                // Shapes de la page ouverte. Header né rempli au rebuild (valeurs persistées en
                                // config registry par _syncClanHeader) ; roster né rempli via le static
                                // _membersData de DvRoster. On lit Firestore et on ne met à jour que sur delta.
                                final track = await DvOrb.wait_for_shape("clan_page/lvl_track");
                                final fill  = await DvOrb.wait_for_shape("clan_page/lvl_fill");
                                final flame = await DvOrb.wait_for_shape("clan_page/lvl_flame");
                                final lvl   = await DvOrb.wait_for_shape("clan_page/lvl_label");
                                final xpLbl = await DvOrb.wait_for_shape("clan_page/xp_label");
                                final title = await DvOrb.wait_for_shape("clan_page/title_label");

                                // Barre de BUTIN (miroir à droite). Coffre = 2 images empilées (chestip/chestok)
                                // dont on bascule la visibilité ; on ne swappe jamais shape.image à chaud.
                                final bTrack   = await DvOrb.wait_for_shape("clan_page/butin_track");
                                final bFill    = await DvOrb.wait_for_shape("clan_page/butin_fill");
                                final bChestIp = await DvOrb.wait_for_shape("clan_page/butin_chest_ip");
                                final bChestOk = await DvOrb.wait_for_shape("clan_page/butin_chest_ok");
                                final bLabel   = await DvOrb.wait_for_shape("clan_page/butin_label");

                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";

                                    var xp    = 0;
                                    var butin = 0;
                                    // Titre PORTÉ par le clan (pas dérivé du niveau) : -1 tant qu'aucun
                                    // chef n'a appliqué l'item titre correspondant.
                                    var titleIdx = -1;
                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        final doc = await _cloud?.read(
                                            "workers", "clans", clanId,
                                            ownerId: clanSecret, region: region) ?? Dvidle({});
                                        xp    = int.tryParse(doc.get("xp")?.toString() ?? "0") ?? 0;
                                        butin = _butinCourant(doc);   // cycle courant, PAS le compteur cumulé
                                        titleIdx = int.tryParse(doc.get("title_idx")?.toString() ?? "-1") ?? -1;

                                        // Nom du clan : peut avoir été renommé depuis un autre appareil.
                                        // On resynchronise la session + le label si la valeur a changé.
                                        final clanName = doc.get("internal.name")?.toString() ?? "";
                                        if (clanName.isNotEmpty) {
                                            final cur = (await Deva.instance.get("session.clan.name"))?.toString() ?? "";
                                            if (cur != clanName) {
                                                await Deva.instance.set("session.clan.name", clanName);
                                                final nlbl = DvOrb.get_shape_by_id("clan_page/label");
                                                if (nlbl is DvLabel) { await nlbl.computeDisplay(); nlbl.refreshUI(); }
                                            }
                                        }

                                        // Avatar du clan : le layer runtime (rechargé au login) fournit déjà la
                                        // bonne image dès la première frame. On ne relit/écrase Firestore QUE si la
                                        // valeur diffère (changement fait depuis un autre appareil) — sinon le
                                        // set+appear() redondant re-décodait l'image et provoquait un flash.
                                        final clanAvatar = doc.get("avatar")?.toString() ?? "";
                                        final cIcon  = DvOrb.get_shape_by_id("clan_page/icon");
                                        final wanted = clanAvatar.isNotEmpty ? clanAvatar : _nopeAvatar;
                                        final cur    = cIcon?.get("shape.image")?.toString() ?? "";
                                        if (wanted != cur) {
                                            cIcon?.set("shape.image", wanted);
                                            try { await cIcon?.appear(); } catch (e) { deva_log("warning", "[clan] icon appear: $e"); }
                                            cIcon?.refreshUI();
                                            // Resynchronise le runtime pour connaître l'image dès le prochain boot.
                                            if (clanAvatar.isNotEmpty) {
                                                await deva_set("registry.clan_page/icon.shape.image", clanAvatar);
                                                await Deva.instance.store();
                                            }
                                        }
                                    }

                                    // Sync header ← Firestore : persiste en config registry (born-filled) et ne
                                    // touche l'instance vive que sur delta.
                                    await _syncClanHeader(caller: caller, track: track, fill: fill, flame: flame,
                                        lvl: lvl, xpLbl: xpLbl, title: title, bTrack: bTrack, bFill: bFill,
                                        bChestIp: bChestIp, bChestOk: bChestOk, bLabel: bLabel,
                                        xp: xp, butin: butin, titleIdx: titleIdx);

                                    final npLog = getClanNiveauProgres(xp);
                                    deva_log("info", "[clan] niveau=${npLog.niveau} progres=${(npLog.progres * 100).round()}% xp=$xp "
                                        "butin=$butin/${_butinMaxXp}${butin >= _butinMaxXp ? " (MAX)" : ""}");

                                    // Cooldowns de l'utilisateur courant (coup de pouce / guérir) : lus une
                                    // fois à l'affichage de l'écran Clan depuis son doc membre clans_players
                                    // (ownerId = clanSecret). Servent au clan_selector.
                                    final meDoc = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    _myLastBoost = meDoc.get("last_boost")?.toString() ?? "";
                                    _myLastCure  = meDoc.get("last_cure")?.toString()  ?? "";

                                    // Coffre doré d'ouverture du butin : révélé aux seuls chefs, et seulement
                                    // quand la jauge est au plafond — c'est le déclencheur de la cérémonie.
                                    // _ensureIsAdmin est caché → coût nul en régime établi.
                                    final canOpen = butin >= _butinMaxXp && clanId.isNotEmpty && clanSecret.isNotEmpty
                                        && await _ensureIsAdmin(clanId, clanSecret, region);
                                    await _syncVisible(await DvOrb.wait_for_shape("clan_page/butin_open"),
                                        "clan_page/butin_open", canOpen);
                                    await _syncVisible(await DvOrb.wait_for_shape("clan_page/butin_aura"),
                                        "clan_page/butin_aura", canOpen);
                                    // L'aura tourne tant que le coffre est là : scène immortelle, démarrée
                                    // et arrêtée à la main (idiome flamewall du combat).
                                    ActionRegistry.get(canOpen ? "dvflame.start.chestaura"
                                                              : "dvflame.stop.chestaura")?.call(null, null);

                                    // Roster des membres : une tuile par joueur. set_members ignore un re-push
                                    // identique (diff dans DvRoster) → pas de vidage/re-remplissage sans delta.
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[clan] on_clan_appear FAILED: $e");
                                }
    }

    // Écran Clan : calcule niveau/prog (barème clan) + barre butin, puis synchronise vers les shapes
    // (config registry + instance vive) via _sync*. Nom/avatar du clan gérés à part (flux frais).
    Future<void> _syncClanHeader({

                required dynamic caller,
                required dynamic track, required dynamic fill, required dynamic flame,
                required dynamic lvl,   required dynamic xpLbl, required dynamic title,
                required dynamic bTrack, required dynamic bFill, required dynamic bChestIp,
                required dynamic bChestOk, required dynamic bLabel,
                required int xp, required int butin, required int titleIdx,
    }) async {

                                final trackX  = _pctOf(track,    "shape.x", 5.0);
                                final trackW  = _pctOf(track,    "shape.w", 28.0);
                                final flameW  = _pctOf(flame,    "shape.w", 10.0);
                                final bTrackX = _pctOf(bTrack,   "shape.x", 66.0);
                                final bTrackW = _pctOf(bTrack,   "shape.w", 29.0);
                                final bChestW = _pctOf(bChestIp, "shape.w", 10.0);

                                final np   = getClanNiveauProgres(xp);
                                final niv  = np.niveau;
                                final prog = np.progres;

                                var ch = false;
                                // Barre XP clan : remplissage + flamme sur la pointe.
                                final fillW  = (prog * trackW).clamp(0.5, trackW);
                                final flameX = (trackX + prog * trackW - flameW / 2).clamp(0.0, 100.0 - flameW);
                                ch = await _syncGeom(fill,  "clan_page/lvl_fill",  "shape.w", "${fillW.toStringAsFixed(2)}%")  || ch;
                                ch = await _syncGeom(flame, "clan_page/lvl_flame", "shape.x", "${flameX.toStringAsFixed(2)}%") || ch;
                                ch = await _syncLabel(lvl,   "clan_page/lvl_label",   "$niv")                                  || ch;
                                ch = await _syncLabel(xpLbl, "clan_page/xp_label",    "$xp / ${_xpForNiveauClan(niv + 1)} XP") || ch;
                                // Titre PORTÉ par le clan, plus dérivé du niveau : cf. clans.title_idx,
                                // posé par l'option « Porter ce titre » de l'item titre de clan (chefs).
                                ch = await _syncLabel(title, "clan_page/title_label", _titleKeyOf("clan_title", titleIdx)) || ch;

                                // Barre BUTIN : 0 → _butinMaxXp, linéaire ; coffre sur la pointe.
                                final bprog  = (_butinMaxXp <= 0 ? 0.0 : butin / _butinMaxXp).clamp(0.0, 1.0);
                                final atMax  = butin >= _butinMaxXp;
                                final bFillW = (bprog * bTrackW).clamp(0.5, bTrackW);
                                final chestX = (bTrackX + bprog * bTrackW - bChestW / 2).clamp(0.0, 100.0 - bChestW);
                                ch = await _syncGeom(bFill,    "clan_page/butin_fill",     "shape.x", "${bTrackX.toStringAsFixed(2)}%") || ch;
                                ch = await _syncGeom(bFill,    "clan_page/butin_fill",     "shape.w", "${bFillW.toStringAsFixed(2)}%")  || ch;
                                ch = await _syncGeom(bChestIp, "clan_page/butin_chest_ip", "shape.x", "${chestX.toStringAsFixed(2)}%")  || ch;
                                ch = await _syncGeom(bChestOk, "clan_page/butin_chest_ok", "shape.x", "${chestX.toStringAsFixed(2)}%")  || ch;
                                ch = await _syncLabel(bLabel, "clan_page/butin_label", "$butin / $_butinMaxXp")                         || ch;
                                // Bascule coffre : chestok au max, chestip sinon (visibilité persistée → naissance correcte).
                                ch = await _syncVisible(bChestIp, "clan_page/butin_chest_ip", !atMax) || ch;
                                ch = await _syncVisible(bChestOk, "clan_page/butin_chest_ok", atMax)  || ch;

                                if (ch) caller?.refreshUI();
    }

    // Énumère clans_players/{clanId}/players (docs porteurs de name/xp/pv/damage/decay/
    // last_task), dérive niveau (getNiveauProgres) + PV affichés (_computeDisplayedPv) par
    // membre, et pousse la liste au DvRoster (action dvroster.set_members). Appelé au 1er
    // affichage (on_clan_appear) ET après une mutation (ex. revive_player) pour rafraîchir l'UI.
    Future<void> _refreshRoster(String clanId, String clanSecret, String region) async {

                                if (clanId.isEmpty) return;
                                final players = await _cloud?.list(
                                    "workers", "clans_players/$clanId/players", region: region) ?? [];
                                // Liste des admins du clan (workers/clans/{clanId}.admins) : sert au tri métier du
                                // roster (worker.clan_roster_sort, admins d'abord). Lecture protégée : repli liste vide.
                                List<dynamic> admins = const [];
                                String founderId = "";
                                // Butin du CYCLE COURANT (cf. _butinCourant) : c'est LUI qui dimensionne les barres
                                // de progrès des tuiles (cf. normalisation plus bas). Lu au passage de la lecture
                                // du doc clan déjà faite pour les admins → aucun round-trip supplémentaire.
                                int butin = 0;
                                if (clanSecret.isNotEmpty) {
                                    final clanDoc = await _cloud?.read(
                                        "workers", "clans", clanId, ownerId: clanSecret, region: region);
                                    admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? []);
                                    if (clanDoc != null) butin = _butinCourant(clanDoc);
                                    // Fondateur = admin à vie (champ `founder`, repli legacy = admins[0]) : sert à
                                    // masquer « plus chef » sur sa tuile (clan_selector).
                                    founderId = clanDoc?.get("founder")?.toString().isNotEmpty == true
                                        ? clanDoc!.get("founder").toString()
                                        : (admins.isNotEmpty ? admins.first.toString() : "");
                                }
                                // Statut d'activité par joueur (pour le badge bas-droit de sa tuile) : on
                                // parcourt les tâches du clan et on retient, par assignee, "validating" (main,
                                // demande de validation) en priorité sur "assigned" (flamme, tâche en cours).
                                // Source = le CACHE delta (cf. _refreshTaskStatuses) : le refresh (1 requête
                                // delta, throttlé) remplace le full list (~160 lectures) que faisait cet écran.
                                final taskStatusByPlayer = <String, String>{};
                                try { await _refreshTaskStatuses(); } catch (_) {}
                                final clanTasks = _taskDocsCache.values.toList();
                                for (final t in clanTasks) {
                                    final assignee = t.get("assignee")?.toString() ?? "";
                                    if (assignee.isEmpty) continue;
                                    final tst = t.get("status")?.toString() ?? "";
                                    if (tst != "assigned" && tst != "validating") continue;
                                    final cur = taskStatusByPlayer[assignee] ?? "";
                                    // validating l'emporte sur assigned ; sinon on garde le premier trouvé.
                                    if (tst == "validating" || cur.isEmpty) taskStatusByPlayer[assignee] = tst;
                                }

                                final members = <Map<String, dynamic>>[];
                                int? minXp;
                                // Contribution de chaque joueur au butin courant (XP - last_butin_xp) : sert à
                                // RÉPARTIR la barre de progrès entre les tuiles (cf. normalisation plus bas).
                                // Seule la contribution MAXIMALE est nécessaire : la hauteur de la barre vient du
                                // butin réel du clan, pas d'une reconstruction à partir des XP joueurs (les deux
                                // ne sont pas dans la même unité — cf. _creditClanXp, qui divise par le nombre de
                                // membres avant de créditer le butin).
                                int maxCur = 0;
                                for (final p in players) {
                                    final pid = p.get("id")?.toString() ?? "";
                                    if (pid.isEmpty) continue;
                                    // Membre révoqué (tombstone) : invisible ET hors calculs. Le sauter ici
                                    // exclut d'un coup la tuile, le _clanMinXp (« coup de pouce ») et la barre
                                    // butin (tous dérivés de cette boucle). Champ absent/true = actif (rétrocompat).
                                    if (p.get("enabled") == false) continue;
                                    final pname    = _memberLabel(p.get("name")?.toString() ?? "");
                                    final pavatar  = p.get("avatar")?.toString() ?? "";
                                    final pxp      = int.tryParse(p.get("xp")?.toString() ?? "0") ?? 0;
                                    final plastB   = int.tryParse(p.get("last_butin_xp")?.toString() ?? "0") ?? 0;
                                    final ppv      = int.tryParse(p.get("pv")?.toString() ?? "$_playerPv") ?? _playerPv;
                                    final pdamage  = int.tryParse(p.get("damage")?.toString() ?? "0") ?? 0;
                                    final pdecay   = _readDecay(p.get("decay"));
                                    final plast    = p.get("last_task")?.toString() ?? "";
                                    final plegal   = p.get("legal_state")?.toString() ?? "";   // k=mineur / a=adulte
                                    // has_device : false = joueur déclaré hors ligne (sans appareil dans ce clan).
                                    // Le jeu l'ignore : tuile grisée MAIS pas morte (pas de crâne / résurrection),
                                    // barre butin vide, et exclu des agrégats (partage XP, coup de pouce). Absent/true
                                    // = actif (rétrocompat, comme enabled). La tuile reste VISIBLE (pas de continue).
                                    final phasDevice = p.get("has_device") != false;
                                    final pisAdmin = admins.contains(pid);
                                    final pniv     = getNiveauProgres(pxp).niveau;
                                    final pvShownM = _computeDisplayedPv(ppv, pdamage, plast, pdecay);
                                    final pcur     = phasDevice && (pxp - plastB) > 0 ? (pxp - plastB) : 0;
                                    // Hors-device : n'entre dans aucun agrégat (butin maxCur, _clanMinXp du
                                    // « coup de pouce ») pour ne pas fausser l'équilibrage du clan.
                                    if (phasDevice) {
                                        if (pcur > maxCur) maxCur = pcur;
                                        // Le « coup de pouce » ne vise QUE les joueurs non admin : les chefs
                                        // sont donc hors du minimum d'XP du clan — sinon un chef au plus petit
                                        // XP confisquerait le minimum et plus personne ne serait éligible.
                                        if (!pisAdmin) {
                                            minXp = (minXp == null) ? pxp : (pxp < minXp ? pxp : minXp);
                                        }
                                    }
                                    members.add({
                                        "id":    pid,
                                        "name":  pname,
                                        "level": pniv,
                                        "pv":    pvShownM,
                                        // Mort UNIQUEMENT si le joueur a un appareil : un hors-device ne meurt pas.
                                        "dead":  phasDevice && pvShownM <= 0,
                                        // Assombrissement de la tuile (décision métier) : mort (PV affichés <= 0)
                                        // OU hors-device (grisé même vivant, pour signaler qu'il est ignoré).
                                        "dimmed": phasDevice ? pvShownM <= 0 : true,
                                        "has_device": phasDevice,   // pour clan_selector (masque « déclarer hors ligne »)
                                        "xp":    pxp,   // pour clan_selector (restriction « moins d'XP »)
                                        "admin": pisAdmin,               // tri roster (admins d'abord), « déjà chef », « coup de pouce » interdit
                                        "founder": pid == founderId,     // fondateur = admin à vie (pas de « plus chef »)
                                        "legal_state": plegal,           // pour clan_selector (« déjà adulte » / mineur)
                                        "original_clan": p.get("original_clan")?.toString() ?? "",  // clan_selector : protection mineur / clan d'origine
                                        "no_account": p.get("no_account") == true,   // enfant sans compte : dérogation à la protection mineur (révocable)
                                        // Badge d'activité de la tuile : "assigned"/"validating"/"" (cf. DvRoster).
                                        "task_status": taskStatusByPlayer[pid] ?? "",
                                        // Avatar du membre (clans_players.avatar) → tuile du roster (repli nope).
                                        "avatar": pavatar,
                                        // Solde de la bourse : badge de la tuile (visible de TOUS) et plafond
                                        // du versement de tribut (clan_selector). Lu sur le MIROIR du doc
                                        // joueur, justement pour ne pas lister une 2e collection ici.
                                        "wallet": int.tryParse(p.get("wallet")?.toString() ?? "0") ?? 0,
                                        // Rappels de relance actifs pour ce membre (clan_selector : « couper »
                                        // ou « rétablir »). Absent = actif, comme enabled/has_device : le champ
                                        // n'existe pas sur les docs antérieurs, et le défaut doit être « oui ».
                                        "nudges": p.get("nudges") != false,
                                        "_cur":  pcur,  // temporaire : sert au calcul de progress ci-dessous
                                    });
                                }
                                _clanMinXp = minXp ?? 0;
                                // Barre de progrès « butin » par joueur (spéc) : le MEILLEUR contributeur affiche
                                // exactement la barre de butin du clan (butin du cycle / plafond, la même que l'entête de
                                // l'écran Clan) ; les autres au prorata de leur contribution / max.
                                // Le butin est lu tel quel sur le doc clan : le reconstruire depuis la somme des XP
                                // joueurs donnerait une valeur sans rapport (l'XP-clan est l'XP de la tâche divisée
                                // par le nombre de membres, et les bonus de niveau créditent le butin en direct).
                                final totalProg = (_butinMaxXp <= 0 ? 0.0 : butin / _butinMaxXp).clamp(0.0, 1.0);
                                for (final m in members) {
                                    final cur = m["_cur"] as int;
                                    m["progress"] = maxCur > 0 ? totalProg * (cur / maxCur) : 0.0;
                                    m.remove("_cur");
                                }
                                // Push au DvRoster : l'action ignore un re-push identique (diff) et remplace
                                // intégralement sinon (un membre supprimé disparaît de la liste fraîche).
                                ActionRegistry.get("dvroster.set_members")?.call(null, members);
                                deva_log("info", "[clan] roster: ${members.length} membre(s) poussé(s), minXp=$_clanMinXp");
    }

    //-----------------------------------------------------------------------
    //-- Menu contextuel joueur (écran Clan) --------------------------------
    //-----------------------------------------------------------------------

    // Sélecteur du DvMenu clan_page/roster_menu : reçoit `data` = infos du joueur cliqué
    // (poussées au roster) et retourne {"selectable": [...], "disabled": [...]} (les grisées
    // sont affichées mais non cliquables).
    //  - non-admin, ou soi-même                    → rien (menu non ouvert)
    //  - « guérir » : uniquement si le joueur est mort ; grisée si cooldown cure < 3 j
    //  - « coup de pouce » : uniquement pour le(s) joueur(s) NON ADMIN le(s) moins gradé(s) en
    //    XP du clan ; grisée si cooldown boost < 3 j
    // Cooldowns lus au montage de l'écran (_myLastBoost/_myLastCure), min XP = _clanMinXp.
    Future<Map<String, dynamic>> clan_selector(dynamic caller, dynamic data) async {

                                final empty = <String, dynamic>{"selectable": [], "disabled": [], "single": ""};
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";

                                    final isAdmin = await _ensureIsAdmin(clanId, clanSecret, region);
                                    if (!isAdmin) return empty;

                                    final m = (data is Map) ? data : <String, dynamic>{};
                                    final isSelf = (m["id"]?.toString() ?? "") == _userId;

                                    final selectable = <String>[];
                                    final disabled   = <String>[];

                                    // Journal : toujours proposé aux admins, sur n'importe quel joueur (y compris soi-même).
                                    selectable.add("player_log");

                                    // Guérir / Coup de pouce : jamais sur soi-même.
                                    if (!isSelf) {
                                        // Guérir : seulement si mort. Grisé si l'admin est en cooldown de cure.
                                        final dead = m["dead"] == true;
                                        if (dead) {
                                            (_withinDays(_myLastCure, 3) ? disabled : selectable).add("revive_player");
                                        }

                                        // Coup de pouce : seulement pour le(s) JOUEUR(S) NON ADMIN au plus petit
                                        // XP du clan (un chef ne se fait pas booster ; _clanMinXp est calculé
                                        // hors admins, cf. _refreshRoster). Grisé si l'admin est en cooldown.
                                        final targetXp = int.tryParse(m["xp"]?.toString() ?? "") ?? 0;
                                        if (m["admin"] != true && targetXp <= _clanMinXp) {
                                            (_withinDays(_myLastBoost, 3) ? disabled : selectable).add("support_player");
                                        }

                                        // Déclarer hors ligne : caché si le joueur est déjà hors-device
                                        // (has_device==false) — plus rien à déclarer. Prendre la place : toujours (stub).
                                        if (m["has_device"] != false) selectable.add("declare_offline");
                                        selectable.add("take_place");

                                        // Chef : promouvoir si simple joueur, sinon « plus chef » (rétrograder) —
                                        // sauf le fondateur, admin à vie. (Soi-même est déjà exclu : pas d'auto-
                                        // rétrogradation possible.)
                                        if (m["admin"] != true) {
                                            selectable.add("promote_chief");
                                        } else if (m["founder"] != true) {
                                            selectable.add("nomore_chief");
                                        }

                                        // Déclarer majeur : réservé aux TUTEURS = admins du clan d'origine du joueur
                                        // (clanId == original_clan). Caché si déjà adulte ("a") ou déjà en transition ("t").
                                        final plegal        = m["legal_state"]?.toString()   ?? "";
                                        final poriginalClan = m["original_clan"]?.toString() ?? "";
                                        if (poriginalClan == clanId && plegal != "a" && plegal != "t") {
                                            selectable.add("promote_adult");
                                        }
                                    }

                                    // Rappels de relance : deux options EXCLUSIVES, comme « chef »/« plus chef »
                                    // juste au-dessus. Hors du bloc !isSelf : un chef coupe les rappels d'un
                                    // enfant, et peut couper les siens sans quitter l'écran Clan (le kebab
                                    // Personnage propose la même bascule, sur soi seulement).
                                    // C'est la porte de sortie du dispositif de relance, et elle doit rester
                                    // à un tap : un refus qu'il faut chercher n'est pas un refus.
                                    (m["nudges"] != false)
                                        ? selectable.add("nudges_off")
                                        : selectable.add("nudges_on");

                                    // Payer son tribut : HORS du bloc !isSelf — un chef gagne de l'argent en
                                    // jeu comme les autres et se verse le sien. Grisée sur une bourse vide :
                                    // dire que l'option existe a du sens (contrairement à la cacher), c'est
                                    // ainsi que le chef apprend qu'il y a quelque chose à payer un jour.
                                    (int.tryParse(m["wallet"]?.toString() ?? "0") ?? 0) > 0
                                        ? selectable.add("pay_tribute")
                                        : disabled.add("pay_tribute");

                                    // A quitté le clan : révocation (sur autrui) OU départ volontaire (sur soi-même) —
                                    // d'où le placement HORS du bloc !isSelf. Jamais sur le fondateur (admin à vie).
                                    // Grisé si le joueur est un mineur encore dans son clan d'origine (protection) ;
                                    // actif sinon (adulte, ou mineur dont original_clan ≠ clan courant).
                                    if (m["founder"] != true) {
                                        // "t" (transition) est traité comme mineur : protection maintenue jusqu'à "a".
                                        final isMinor      = (m["legal_state"]?.toString() ?? "") != "a";
                                        final originalClan =  m["original_clan"]?.toString() ?? "";
                                        // Dérogation : un enfant sans compte (no_account) reste révocable même
                                        // mineur dans son clan d'origine — c'est le seul moyen de le retirer
                                        // (il ne peut ni partir de lui-même ni exister ailleurs).
                                        final noAccount    =  m["no_account"] == true;
                                        if (isMinor && originalClan == clanId && !noAccount) {
                                            disabled.add("revoke_player");
                                        } else {
                                            selectable.add("revoke_player");
                                        }
                                    }

                                    // single vide : rien à exécuter quand aucune option n'est proposée (iso-fonctionnel roster).
                                    return {"selectable": selectable, "disabled": disabled, "single": ""};
                                } catch (e) {
                                    deva_log("warning", "[roster] clan_selector failed: $e");
                                    return empty;
                                }
    }

    // Tri métier du roster clan (exposé au DvRoster générique via sa conf `sort`) : le joueur
    // courant TOUJOURS en dernier (sa tuile reste tout en bas de la liste, quel que soit son
    // statut), puis les admins d'abord (ordre alphabétique) et enfin les non-admins (ordre
    // alphabétique). `event` = liste des maps membres (portant `id`, `admin` et `name`). Retourne
    // une NOUVELLE liste ordonnée (ne mute pas l'entrée). Tri insensible à la casse via toLowerCase.
    List<dynamic> clan_roster_sort(dynamic caller, dynamic event) {

                                if (event is! List) return const [];
                                final list = event
                                    .whereType<Map>()
                                    .map((e) => Map<String, dynamic>.from(e))
                                    .toList();
                                list.sort((a, b) {
                                    // Le joueur courant est épinglé tout en bas, avant toute autre règle.
                                    final aSelf = (a["id"]?.toString() ?? "") == _userId;
                                    final bSelf = (b["id"]?.toString() ?? "") == _userId;
                                    if (aSelf != bSelf) return aSelf ? 1 : -1;      // soi-même après les autres
                                    final aAdmin = a["admin"] == true;
                                    final bAdmin = b["admin"] == true;
                                    if (aAdmin != bAdmin) return aAdmin ? -1 : 1;   // admins avant non-admins
                                    final an = (a["name"]?.toString() ?? "").toLowerCase();
                                    final bn = (b["name"]?.toString() ?? "").toLowerCase();
                                    return an.compareTo(bn);                        // puis alphabétique
                                });
                                return list;
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
