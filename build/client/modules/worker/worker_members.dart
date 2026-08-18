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
// --- worker extension — Roster admin (autres joueurs)
// -----------------------------------------------------------------------------
extension Worker_members on worker {

    void _register_members() {

                                ActionRegistry.register("worker.revive_player",             revive_player);

                                ActionRegistry.register("worker.support_player",            support_player);

                                // Options roster (boutons/menu). promote_chief est implémenté ; declare_offline /
                                // promote_adult / revoke_player restent des stubs journalisés.
                                ActionRegistry.register("worker.declare_offline",           declare_offline);

                                ActionRegistry.register("worker.take_place",                take_place);

                                ActionRegistry.register("worker.restore_self",              restore_self);

                                ActionRegistry.register("worker.promote_chief",             promote_chief);

                                // « Plus chef » (rétrogradation) : opposé de promote_chief.
                                ActionRegistry.register("worker.nomore_chief",              nomore_chief);

                                ActionRegistry.register("worker.promote_adult",             promote_adult);

                                ActionRegistry.register("worker.revoke_player",             revoke_player);

    }

    // Action « Guérir le joueur » (admin, joueur mort). `event` = data du joueur cliqué.
    // Recale last_task pour que la dégradation temporelle ramène les PV à la MOITIÉ des PV
    // max (hors damage) : on impose loss = maxPv − maxPv÷2 en posant last_task à
    // now − (loss + 0.5)·decay jours (le +0.5 tombe au milieu du palier → floor stable).
    // Le champ `damage` reste hors scope : si damage ≥ moitié des PV, pvShown ≤ 0 et le
    // joueur reste mort. S'il est réellement ressuscité (pvShown > 0), on repasse status="alive".
    Future<void> revive_player(dynamic caller, dynamic event) async {

                                final m  = (event is Map) ? event : const {};
                                final id = m["id"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // PV max stocké + damage + decay du joueur (pas dans `data` : on lit le doc).
                                    final doc = await _cloud?.read("workers", "clans_players/$clanId/players", id,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    final maxPv  = int.tryParse(doc.get("pv")?.toString() ?? "$_playerPv") ?? _playerPv;
                                    final damage = int.tryParse(doc.get("damage")?.toString() ?? "0") ?? 0;
                                    final decay  = _readDecay(doc.get("decay"));
                                    final gage   = doc.get("gage")?.toString() ?? "";   // gage porté (pour le journal)

                                    final healTarget = (maxPv < _healPv) ? maxPv : _healPv;   // rendre _healPv PV (borné à maxPv)
                                    final lossTarget = maxPv - healTarget;                     // → pv − loss = healTarget
                                    final elapsedSeconds = (lossTarget + 0.5) * decay * 86400.0;
                                    final newLast = DateTime.now().toUtc()
                                        .subtract(Duration(microseconds: (elapsedSeconds * 1000000).round()));
                                    final newLastIso = newLast.toIso8601String();

                                    final pvShown = _computeDisplayedPv(maxPv, damage, newLastIso, decay);

                                    // Écriture (deep-merge → préserve pv/xp/damage/…) : last_task + status si vivant.
                                    final out = Dvidle({});
                                    out.set("id", id);
                                    out.set("last_task", newLastIso);
                                    if (pvShown > 0) out.set("status", "alive");
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, out,
                                        region: region, ownerId: clanSecret);

                                    deva_log("info", "[roster] revive_player ${m["name"]} ($id): visé=$healTarget PV "
                                        "→ pvShown=$pvShown (damage=$damage)${pvShown > 0 ? " alive" : " reste mort"}");

                                    // Journal : ne logger que si le joueur est réellement revenu à la vie.
                                    if (pvShown > 0) {
                                        final adminName  = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                        final playerName = m["name"]?.toString() ?? id;
                                        await _writeClanLog(clanId, clanSecret, region, "PlayerResurrected",
                                            userId: id, adminId: _userId, slug: gage,
                                            data: Dvidle({"playerId": id, "playerName": playerName,
                                                          "gage": gage, "adminId": _userId, "adminName": adminName}));
                                    }

                                    // Cooldown de cure de l'acteur : pose last_cure=now sur son doc
                                    // membre clans_players (deep-merge, ownerId = clanSecret) + cache.
                                    final now = DateTime.now().toUtc().toIso8601String();
                                    final u = Dvidle({});
                                    u.set("last_cure", now);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", _userId, u,
                                        region: region, ownerId: clanSecret);
                                    _myLastCure = now;

                                    // Rafraîchit les tuiles (re-lit clans_players et re-pousse au DvRoster).
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] revive_player FAILED: $e");
                                }
    }

    // Action « Coup de pouce » (admin, joueur le moins gradé). `event` = data du joueur.
    // +50 XP au joueur SEUL (via _creditXp) : ni clan (clans/{clanId}.xp) ni butin (butin_xp)
    // ne sont crédités (on n'appelle PAS _creditClanXp). Pose le cooldown boost de l'acteur.
    Future<void> support_player(dynamic caller, dynamic event) async {

                                final m  = (event is Map) ? event : const {};
                                final id = m["id"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // +50 XP joueur seul (deep-merge sur clans_players ; niveau dérivé de xp).
                                    await _creditXp(clanId, clanSecret, region, id, 50);

                                    // Cooldown de boost de l'acteur : last_boost=now sur son doc membre
                                    // clans_players (deep-merge, ownerId = clanSecret) + cache.
                                    final now = DateTime.now().toUtc().toIso8601String();
                                    final u = Dvidle({});
                                    u.set("last_boost", now);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", _userId, u,
                                        region: region, ownerId: clanSecret);
                                    _myLastBoost = now;

                                    deva_log("info", "[roster] support_player: +50 XP → ${m["name"]} ($id)");

                                    // Rafraîchit les tuiles (le niveau peut avoir monté).
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] support_player FAILED: $e");
                                }
    }

    // --- Actions roster encore en stub (journalisées) ------------------------
    // Chacune reçoit la charge utile du joueur ciblé (comme le menu). On journalise pour l'instant ;
    // les vraies implémentations viendront plus tard. (promote_chief / nomore_chief, plus bas, sont
    // implémentés.)
    // Action « Déclarer hors ligne » (admin) : pose has_device=false sur le doc clans_players du
    // joueur ciblé (deep-merge → préserve xp/pv/…). Dès lors le jeu l'ignore (exclu du partage
    // d'XP/butin, grisé sans crâne, ne peut pas mourir) et l'option disparaît de son menu ; il
    // repassera has_device=true tout seul à sa prochaine reconnexion (_writeClanPlayer). Sur son
    // propre appareil, sa vigilance verra le changement (pas de mort/burn, cf. _evaluateDeath).
    Future<void> declare_offline(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("has_device", false);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    deva_log("info", "[roster] declare_offline : $name ($id) déclaré hors ligne");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] declare_offline FAILED: $e");
                                }
    }

    // Action « Prendre la place d'un joueur » (admin) : le worker assume l'identité de JEU du membre
    // ciblé SANS se déconnecter (aucun impact sur le module cloud / l'auth). _userId bascule sur la
    // cible → toutes les lectures/écritures des collections de clan (roster, xp, pv, avatar, tâches,
    // tiroir, journal, vigilance) se routent sur elle, autorisées par le clanSecret partagé. Le doc
    // perso `users/` reste celui de l'admin (via _authUserId / _sessionDocId), jamais touché : on
    // reconstruit le contexte de clan depuis SA session (même clan, donc clanId/clanSecret connus).
    // Mémoire seule : un kill de l'app repart en admin. `event` = data du joueur cliqué.
    Future<void> take_place(dynamic caller, dynamic event) async {

                                final m        = (event is Map) ? event : const {};
                                final targetId = m["id"]?.toString()   ?? "";
                                final name     = m["name"]?.toString() ?? "";
                                // Gardes : cible valide, jamais soi-même, pas d'imbrication d'impersonation.
                                if (targetId.isEmpty || targetId == _userId || _impersonating) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);   // doc de l'admin → contexte clan (même clan que la cible)
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;
                                    // Réservé aux admins (double garde : le clan_selector le filtre déjà).
                                    if (!await _ensureIsAdmin(clanId, clanSecret, region)) return;

                                    // Coupe les watchers de l'identité courante AVANT la bascule.
                                    _stopValidationPolling();
                                    _stopPlayerVigilance();
                                    _resetOpening();

                                    // Bascule d'identité de JEU (pas d'auth) : _authUserId (doc perso) reste
                                    // l'admin ; _userId devient la cible.
                                    _realUserName  = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    _impersonating = true;
                                    _userId = targetId;
                                    await Deva.instance.set("session.user.id",   targetId);
                                    await Deva.instance.set("session.user.name", name);   // @@@session.user.name@@@ → cible (journaux)
                                    await deva_set("worker.impersonating", "true");          // gate de la leçon dvtuto
                                    await deva_set("dvtuto.seen.impersonation_back", false); // rejoue la leçon à chaque prise de place

                                    // Purge des caches liés à l'identité (même repli que on_logout).
                                    _isAdmin = false; _adminCount = 0; _isAdminClanId = ""; _isAdminUserId = "";
                                    _adminMode = false;
                                    _gameDomains.clear();
                                    // État de jeu local (propre à la session/device) : repart neuf.
                                    await Deva.instance.set("session.active_task",  "");
                                    await Deva.instance.set("session.active_proof", "");
                                    await deva_set("worker.player_dead", false);

                                    // Amorce les lignes de base sur la CIBLE → pas de fausse animation au 1er tick.
                                    await _seedPlayerBaselines(clanId, clanSecret, region);

                                    // Recalcule le statut chef DE LA CIBLE + vocabulaire tiroir.
                                    await _ensureIsAdmin(clanId, clanSecret, region);
                                    _declareTiroirVocabulary();
                                    await _syncChiefUi();

                                    // Recharge les données de jeu du point de vue de la cible.
                                    await _setAmbiance(false);   // l'état de vie réel sera réévalué par la vigilance / on_dashboard_appear
                                    if (session != null) await _loadClanTasks(session, region);
                                    _startPlayerVigilance(clanId, clanSecret, region);   // garde keyée sur _userId → nouveau watch cible

                                    // Bandeau overlay « vous incarnez X » + bouton retour. On NE réenregistre
                                    // PAS le device (_writeClanPlayer) : cela volerait le token FCM / le nom /
                                    // l'avatar de la cible au profit de ce téléphone.
                                    await _applyImpersonation(true, name);

                                    deva_log("info", "[roster] take_place → incarne $name ($targetId)");
                                    DvOrb.navigate_reset("dashboard");
                                } catch (e) {
                                    deva_log("error", "[roster] take_place FAILED: $e");
                                }
    }

    // Retour au compte d'origine depuis l'impersonation (bouton du bandeau overlay). Inverse de
    // take_place : _userId revient à _authUserId, on recharge l'UI du point de vue de l'admin.
    Future<void> restore_self(dynamic caller, dynamic event) async {

                                if (!_impersonating) return;
                                try {
                                    _stopValidationPolling();
                                    _stopPlayerVigilance();
                                    _resetOpening();

                                    _userId        = _authUserId;
                                    _impersonating = false;
                                    await Deva.instance.set("session.user.id",   _authUserId);
                                    await Deva.instance.set("session.user.name", _realUserName);
                                    await deva_set("worker.impersonating", "false");

                                    // Masque le bandeau AVANT de renaviguer → le dashboard neuf naît sans bandeau.
                                    await _applyImpersonation(false, "");

                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);   // à nouveau le doc de l'admin
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";

                                    _isAdmin = false; _adminCount = 0; _isAdminClanId = ""; _isAdminUserId = "";
                                    _adminMode = false;
                                    _gameDomains.clear();
                                    await Deva.instance.set("session.active_task",  "");
                                    await Deva.instance.set("session.active_proof", "");
                                    await deva_set("worker.player_dead", false);

                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        // Ré-amorce les lignes de base sur l'admin (elles portaient les valeurs
                                        // de la cible pendant l'impersonation) → pas de fausse animation au retour.
                                        await _seedPlayerBaselines(clanId, clanSecret, region);
                                        await _ensureIsAdmin(clanId, clanSecret, region);
                                        _declareTiroirVocabulary();
                                        await _syncChiefUi();
                                        await _setAmbiance(false);
                                        if (session != null) await _loadClanTasks(session, region);
                                        _startPlayerVigilance(clanId, clanSecret, region);
                                    }

                                    deva_log("info", "[roster] restore_self → retour au compte $_realUserName ($_authUserId)");
                                    DvOrb.navigate_reset("dashboard");
                                } catch (e) {
                                    deva_log("error", "[roster] restore_self FAILED: $e");
                                }
    }

    // Bandeau overlay d'impersonation (idiome maison commons/death_* : widgets layer:overlay révélés à
    // la volée, jamais une popup modale). MÉMOIRE SEULE — on ne persiste PAS (aucun store()) : un kill
    // de l'app repart en joueur d'origine. Mute les templates de conf (→ les pages FUTURES, dont le
    // dashboard re-navigué, naissent avec/sans le bandeau) ET applique aux pages déjà en pile.
    Future<void> _applyImpersonation(bool on, String name) async {

                                try {
                                    // Widget UNIQUE : « Vous incarnez X — touchez pour revenir » (2 tokens traduits
                                    // + le nom injecté au milieu, comme death_gage compose plusieurs @@@T:@@@).
                                    final label = on
                                        ? "@@@T:impersonating_as@@@ $name — @@@T:impersonation_tap_return@@@"
                                        : "";
                                    await deva_set("registry.commons/impersonation_back.shape.visible", on);
                                    if (on) {
                                        await deva_set("registry.commons/impersonation_back.shape.label", label);
                                    }
                                    for (final p in DvPage.actives) {
                                        final backS = p.get_shape_by_id("commons/impersonation_back");
                                        if (on) {
                                            if (backS is DvLabel) backS.write(label);
                                            backS?.show();
                                        } else {
                                            backS?.hide();
                                        }
                                    }
                                } catch (e) {
                                    deva_log("error", "[impersonation] _applyImpersonation FAILED: $e");
                                }
    }

    // Pré-remplit les lignes de base de détection (xp/task/gold/is_admin) avec les valeurs ACTUELLES
    // du doc joueur courant (_userId), pour que le 1er _onPlayerDocChanged après une bascule d'identité
    // (impersonation ↔ retour) ne diffe pas contre l'identité précédente → aucune fausse animation
    // (level-up / cadeau XP / cadeau d'or / promotion chef). L'ownerId (firebaseUid) ne changeant PAS
    // en impersonation, ces clés per-owner resteraient sinon celles de l'admin. Amorçage explicite =
    // miroir de l'« amorçage silencieux » des checks (storedRaw==null).
    Future<void> _seedPlayerBaselines(String clanId, String clanSecret, String region) async {

                                try {
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return;
                                    final doc = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    final xp       = int.tryParse(doc.get("xp")?.toString()   ?? "0") ?? 0;
                                    final gold     = int.tryParse(doc.get("gold")?.toString() ?? "0") ?? 0;
                                    final lastTask = doc.get("last_task")?.toString() ?? "";
                                    final rawAdmin = doc.get("is_admin");
                                    final isAdmin  = rawAdmin == true || rawAdmin?.toString() == "true";
                                    await deva_set("worker.player_last_xp",       xp);
                                    await deva_set("worker.player_last_task",     lastTask);
                                    await deva_set("worker.player_last_gold",     gold);
                                    await deva_set("worker.player_last_is_admin", isAdmin ? "true" : "false");
                                    await Deva.instance.store();
                                } catch (e) {
                                    deva_log("error", "[impersonation] _seedPlayerBaselines FAILED: $e");
                                }
    }

    // Action « Promouvoir chef » (admin) : ajoute le joueur ciblé à la liste `admins` du doc clan
    // (deep-merge → on réécrit la liste augmentée) ET pose is_admin=true sur SON doc clans_players —
    // c'est cette dernière écriture qui réveille SA vigilance (animation "burn" + resync UI côté
    // promu, cf. _checkChiefPromotion). Journalise, invalide le cache admin du promoteur (le nombre
    // d'admins change → l'auto-validation solo bascule en validation croisée), informe le clan puis
    // rafraîchit le roster (le flag `admin` recalculé remplace l'option par « plus chef »). `event`
    // = data du joueur cliqué. Idempotent : re-promouvoir un chef ne fait rien.
    Future<void> promote_chief(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // Lecture de la liste des chefs actuels (source d'autorisation).
                                    final clanDoc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? [])
                                        .map((a) => a.toString()).where((a) => a.isNotEmpty).toList();
                                    if (admins.contains(id)) {
                                        deva_log("info", "[roster] promote_chief : $name ($id) est déjà chef");
                                        return;
                                    }

                                    // Écriture de la liste augmentée (deep-merge remplace la clé liste).
                                    final out = Dvidle({});
                                    out.set("admins", [...admins, id]);
                                    await _cloud?.write("workers", "clans", clanId, out,
                                        region: region, ownerId: clanSecret);

                                    // Miroir is_admin=true sur le doc du promu → réveille SA vigilance (animation
                                    // burn + resync). deep-merge : préserve xp/pv/… du joueur.
                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("is_admin", true);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    // Journal (schéma adminId déjà prévu) : userId = promu, adminId = promoteur.
                                    final adminName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "ChiefPromoted",
                                        userId: id, adminId: _userId,
                                        data: Dvidle({"playerId": id, "playerName": name,
                                                      "adminId": _userId, "adminName": adminName}));

                                    // Le nombre d'admins a changé → invalider le cache pour que _adminCount soit
                                    // relu (bascule solo→multi de l'auto-validation).
                                    _isAdminClanId = "";
                                    await _ensureIsAdmin(clanId, clanSecret, region);

                                    deva_log("info", "[roster] promote_chief : $name ($id) promu chef");

                                    // Informe les AUTRES membres du clan (le promu, lui, a l'animation burn).
                                    await _notifyChiefPromotion(clanId, clanSecret, region, id, name);

                                    // Rafraîchit les tuiles (recalcule le flag `admin` → « plus chef » sur ce joueur).
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] promote_chief FAILED: $e");
                                }
    }

    // Action « Plus chef » (admin) : retire le joueur ciblé de `admins` (source d'autorisation) ET
    // pose is_admin=false sur son doc clans_players (réveille SA vigilance → resync UI, pas d'anim).
    // Garde-fous : on ne peut PAS se rétrograder soi-même (déjà exclu côté menu, redoublé ici) ni
    // rétrograder le FONDATEUR (admin à vie). Journalise, invalide le cache admin, rafraîchit le
    // roster. Idempotent : rétrograder un non-chef ne fait rien.
    Future<void> nomore_chief(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty || id == _userId) return;       // jamais soi-même
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    final clanDoc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? [])
                                        .map((a) => a.toString()).where((a) => a.isNotEmpty).toList();
                                    // Fondateur = admin à vie (champ `founder`, repli legacy = admins[0]).
                                    final founder = clanDoc?.get("founder")?.toString().isNotEmpty == true
                                        ? clanDoc!.get("founder").toString()
                                        : (admins.isNotEmpty ? admins.first : "");
                                    if (id == founder) {
                                        deva_log("info", "[roster] nomore_chief refusé : $name ($id) est le fondateur");
                                        return;
                                    }
                                    if (!admins.contains(id)) {
                                        deva_log("info", "[roster] nomore_chief : $name ($id) n'est pas chef");
                                        return;
                                    }

                                    // Liste amputée + miroir is_admin=false sur le doc du rétrogradé.
                                    final out = Dvidle({});
                                    out.set("admins", admins.where((a) => a != id).toList());
                                    await _cloud?.write("workers", "clans", clanId, out,
                                        region: region, ownerId: clanSecret);

                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("is_admin", false);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    final adminName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "ChiefDemoted",
                                        userId: id, adminId: _userId,
                                        data: Dvidle({"playerId": id, "playerName": name,
                                                      "adminId": _userId, "adminName": adminName}));

                                    _isAdminClanId = "";
                                    await _ensureIsAdmin(clanId, clanSecret, region);

                                    deva_log("info", "[roster] nomore_chief : $name ($id) n'est plus chef");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] nomore_chief FAILED: $e");
                                }
    }

    // Action « Déclarer majeur » (admin tuteur). Réservée aux admins du CLAN D'ORIGINE du joueur
    // (clan_selector ne la propose que si clanId == original_clan de la cible). Pose legal_state="t"
    // (transition : ni enfant ni adulte) sur son doc clans_players. Le joueur ciblé, qui surveille son
    // propre doc (_playerVigilance), détecte le "t" et se voit imposer la CGU adulte ; à l'acceptation,
    // SON app bascule à "a" (users + clans_players). Tant qu'il est "t", il est traité comme "k".
    Future<void> promote_adult(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // Bascule en transition : deep-merge → préserve xp/pv/… du joueur.
                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("legal_state", "t");
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    deva_log("info", "[roster] promote_adult : $name ($id) passe en transition (legal_state=t)");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] promote_adult FAILED: $e");
                                }
    }

    // Action « A quitté le clan » (admin) : révocation d'un membre OU départ volontaire (cible = soi).
    // Pose enabled=false sur son doc clans_players (tombstone → ignoré partout : roster, XP/butin, coup
    // de pouce, notifs), le retire de `admins` s'il était chef (garde _adminCount juste), journalise.
    // Le FONDATEUR n'est jamais révocable (redoublé ici, admin à vie). Sur soi-même → éjection vers
    // l'écran de choix de clan ; sur autrui → refresh du roster (son appareil s'éjectera via sa vigilance).
    Future<void> revoke_player(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // Chefs + fondateur (source d'autorisation). Le fondateur est admin à vie :
                                    // ni révocable ni « partant volontaire » (le menu le cache déjà).
                                    final clanDoc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? [])
                                        .map((a) => a.toString()).where((a) => a.isNotEmpty).toList();
                                    final founder = clanDoc?.get("founder")?.toString().isNotEmpty == true
                                        ? clanDoc!.get("founder").toString()
                                        : (admins.isNotEmpty ? admins.first : "");
                                    if (id == founder) {
                                        deva_log("info", "[roster] revoke_player refusé : $name ($id) est le fondateur");
                                        return;
                                    }

                                    // Tombstone : enabled=false en deep-merge → préserve xp/pv/… du joueur.
                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("enabled", false);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    // Chef révoqué : le retirer de `admins` pour que _adminCount (validation croisée)
                                    // reste juste, puis invalider le cache admin.
                                    if (admins.contains(id)) {
                                        final out = Dvidle({});
                                        out.set("admins", admins.where((a) => a != id).toList());
                                        await _cloud?.write("workers", "clans", clanId, out,
                                            region: region, ownerId: clanSecret);
                                        _isAdminClanId = "";
                                        await _ensureIsAdmin(clanId, clanSecret, region);
                                    }

                                    // Journal : userId = parti, adminId = acteur (= cible si départ volontaire).
                                    final adminName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "MemberRevoked",
                                        userId: id, adminId: _userId,
                                        data: Dvidle({"playerId": id, "playerName": name,
                                                      "adminId": _userId, "adminName": adminName}));

                                    deva_log("info", "[roster] revoke_player : $name ($id) a quitté le clan");

                                    if (id == _userId) {
                                        // Départ volontaire : retour immédiat à l'écran de choix de clan.
                                        await _leaveClanLocal(region);
                                    } else {
                                        // Révocation d'autrui : la tuile disparaît tout de suite (le membre
                                        // sera éjecté sur SON appareil par sa propre vigilance → _checkRevoked).
                                        await _refreshRoster(clanId, clanSecret, region);
                                    }
                                } catch (e) {
                                    deva_log("error", "[roster] revoke_player FAILED: $e");
                                }
    }

    // Détecte la révocation du joueur COURANT : lit son doc membre et, si enabled=false, l'éjecte
    // (voir _leaveClanLocal). Retourne true si éjecté → l'appelant s'arrête là. Couvre la révocation
    // déclenchée depuis un AUTRE appareil (admin), remontée ici par la vigilance temps réel.
    Future<bool> _checkRevoked() async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return false;
                                    final me = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region);
                                    if (me?.get("enabled") == false) {
                                        deva_log("info", "[roster] joueur révoqué détecté → éjection vers decisiontree");
                                        await _leaveClanLocal(region);
                                        return true;
                                    }
                                } catch (e) {
                                    deva_log("warning", "[roster] _checkRevoked failed: $e");
                                }
                                return false;
    }

    // Détecte une bascule légale déclenchée par le tuteur : lit le doc membre du joueur COURANT ;
    // si legal_state == "t" (transition), impose la CGU ADULTE (bloquante) et retourne true → l'appelant
    // s'arrête là (ni dashboard ni autre animation). Le drapeau worker.pending_adult_transition permet à
    // on_acceptance_complete de committer "a" (users + clans_players) une fois la CGU acceptée. Idempotent
    // (navigate_reset) : sûr à rejouer à chaque tick de vigilance ou à chaque login tant qu'on est en "t".
    Future<bool> _checkAdultTransition() async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return false;
                                    final me = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region);
                                    if ((me?.get("legal_state")?.toString() ?? "") != "t") return false;

                                    deva_log("info", "[legal] transition adulte détectée → CGU adulte imposée");
                                    await Deva.instance.set("worker.pending_adult_transition", "true");
                                    await Deva.instance.store();
                                    // Force la résolution + l'enregistrement de la CGU ADULTE (champ motor en mémoire),
                                    // SANS persister documents_sessions : un kill pendant la lecture repart proprement
                                    // (on re-détecte "t" au login et on ré-impose la CGU).
                                    await ActionRegistry.get("documents.set_session_legalstate")?.call(null, "a");
                                    await ActionRegistry.get("documents.show_acceptance")?.call(null, "cgu");
                                    return true;
                                } catch (e) {
                                    deva_log("warning", "[legal] _checkAdultTransition failed: $e");
                                }
                                return false;
    }

    // Retire localement le joueur COURANT de son clan : vide les pointeurs de clan sur son doc `users`
    // (deep-merge → champ vidé par "" ; le prédicat de login se base sur steps.clan.clanId non-vide),
    // coupe la vigilance et renvoie vers l'écran de choix de clan. Exécuté sur l'appareil du joueur
    // concerné : révocation à distance (_checkRevoked) OU départ volontaire (revoke_player sur soi).
    Future<void> _leaveClanLocal(String region) async {

                                try {
                                    final docId = _sessionDocId();
                                    if (region.isNotEmpty && docId.isNotEmpty) {
                                        final doc = Dvidle({});
                                        doc.set("steps.clan.clanId",     "");
                                        doc.set("steps.clan.clanSecret", "");
                                        doc.set("steps.clan.status",     "");
                                        doc.set("last_clan",             "");
                                        await _cloud?.write("workers", "users", docId, doc, region: region);
                                        _invalidateSessionCache();
                                    }
                                } catch (e) {
                                    deva_log("error", "[roster] _leaveClanLocal: users reset FAILED: $e");
                                }
                                _stopPlayerVigilance();
                                _resetOpening();
                                await Deva.instance.set("worker.session.clan_done", "");
                                DvOrb.navigate_reset("decisiontree");
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
