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
// --- worker extension — Création / jointure de clan
// -----------------------------------------------------------------------------
extension Worker_clan on worker {

    void _register_clan() {

                                ActionRegistry.register("worker.on_join_clan",               on_join_clan);

                                ActionRegistry.register("worker.on_create_clan_complete",    on_create_clan_complete);

                                ActionRegistry.register("worker.on_decisiontree_complete",    on_decisiontree_complete);

                                ActionRegistry.register("worker.on_create_clan_appear",      on_create_clan_appear);

                                ActionRegistry.register("worker.on_create_clan_name_changed",on_create_clan_name_changed);

                                ActionRegistry.register("worker.on_create_clan_desc_changed",on_create_clan_desc_changed);

                                ActionRegistry.register("worker.on_inspire_clan",            on_inspire_clan);

                                ActionRegistry.register("worker.on_replay_clan",             on_replay_clan);

                                ActionRegistry.register("worker.on_confirm_create_clan",     on_confirm_create_clan);

                                // Overlay de confirmation « Créer un clan » (écran new_or_pick_clan, adulte).
                                ActionRegistry.register("worker.on_ask_create_clan",          on_ask_create_clan);

                                ActionRegistry.register("worker.on_confirm_create_clan_choice", on_confirm_create_clan_choice);

                                ActionRegistry.register("worker.on_cancel_create_clan",       on_cancel_create_clan);

                                // Sortie « un autre parent a déjà créé le clan » → scan du QR (anti-doublon).
                                ActionRegistry.register("worker.on_create_clan_goto_join",    on_create_clan_goto_join);

                                // Bouton « marche arrière » adulte sur l'écran de rejointe (kid_wants_clan).
                                ActionRegistry.register("worker.on_kid_wants_clan_appear",    on_kid_wants_clan_appear);

                                ActionRegistry.register("worker.on_back_to_choice",           on_back_to_choice);

                                ActionRegistry.register("worker.on_scan_qr",                   on_scan_qr);

                                ActionRegistry.register("worker.on_request_link",              (c, e) async { if (e is Map) await on_request_link(c, e); });

                                ActionRegistry.register("worker.on_accept_request_clan",       on_accept_request_clan);

                                ActionRegistry.register("worker.on_virtuallobby_accepted",     (c, e) async { if (e is Map) await on_virtuallobby_accepted(c, e); });

                                ActionRegistry.register("worker.on_submission_status_changed", (c, e) async { if (e is Map) await on_submission_status_changed(c, e); });

                                ActionRegistry.register("worker.on_invite_clan",               (c, e) async { await on_invite_clan(c, e); });

                                ActionRegistry.register("worker.on_management_created",      (c, e) async { if (e is Map) await on_management_created(c, e); });

                                ActionRegistry.register("worker.on_invite_clan_link",        (c, e) async { if (e is Map) await on_invite_clan_link(c, e); });

                                ActionRegistry.register("worker.on_accept_invitation_clan",  (c, e) async { await on_accept_invitation_clan(c, e); });

                                // Invitation à distance (lien chiffré par PIN, partage réseaux sociaux) — remplace le QR à distance.
                                ActionRegistry.register("worker.on_invite_clan_remote",      on_invite_clan_remote);

                                // Overlay de consentement du chef, révélé avant TOUT recrutement (QR comme PIN).
                                ActionRegistry.register("worker.on_confirm_invite_consent",  on_confirm_invite_consent);

                                ActionRegistry.register("worker.on_cancel_invite_consent",   on_cancel_invite_consent);

                                ActionRegistry.register("worker.on_no_qr",                   on_no_qr);

                                ActionRegistry.register("worker.on_invite_pin_link",         (c, e) async { if (e is Map) await on_invite_pin_link(c, e); });

                                ActionRegistry.register("worker.on_confirm_pin",             on_confirm_pin);

                                // Créer un joueur enfant (option clan « Créer un joueur », chef) : selector du
                                // menu d'en-tête + écran de saisie du nom + création directe dans clans_players.
                                ActionRegistry.register("worker.clan_settings_selector",    clan_settings_selector);

    }

    Future<void> on_join_clan(DvShape? caller, dynamic event) async {

                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (region.isNotEmpty) await _writeStep(region, "clan", "joined");
                                await Deva.instance.set("worker.session.clan_done", "true");
                                // Bienvenue clan jouée à la 1re arrivée sur dashboard (cf. on_dashboard_appear).
                                await deva_set("worker.pending_clan_welcome", "joined");
                                DvOrb.navigate_reset("dashboard");
    }

    Future<String> on_create_clan_complete(DvShape? caller, dynamic event) async {

                                final region       = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final data         = event is Map ? event as Map : <String, dynamic>{};
                                final internalName = data["internal_name"]?.toString() ?? "";
                                final aiName       = data["ai_name"]?.toString()       ?? "";
                                final description  = data["description"]?.toString()   ?? "";

                                int count = 0;
                                try {
                                    final r = await _cloud?.call("count_sessions", Dvidle({}));
                                    count = int.tryParse(r?.get("count")?.toString() ?? "0") ?? 0;
                                } catch (_) {}

                                final regionCode   = region.isNotEmpty ? region : "eu";
                                final nameForExt   = aiName.isNotEmpty ? aiName : internalName;
                                final externalName = "$nameForExt-$regionCode-$count";

                                final userId      = _sessionDocId();
                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                final clanId      = _generateUuid();
                                final clanSecret  = _generateUuid();
                                final now         = DateTime.now().toUtc().toIso8601String();

                                if (region.isNotEmpty && userId.isNotEmpty) {
                                    try {
                                        final device  = await _cloud?.deviceId() ?? "";
                                        final userDoc = await _readSession(region) ?? Dvidle({});
                                        userDoc.rem("docId");
                                        // first_clan (users) = tout premier clan du joueur, figé s'il est vide.
                                        final firstClan = (userDoc.get("first_clan")?.toString() ?? "").isNotEmpty
                                            ? userDoc.get("first_clan").toString()
                                            : clanId;
                                        if ((userDoc.get("first_clan")?.toString() ?? "").isEmpty)
                                            userDoc.set("first_clan", firstClan);
                                        userDoc.set("ownerId",                  firebaseUid);
                                        userDoc.set("userId",                   userId);
                                        userDoc.set("last_clan",                clanId);
                                        userDoc.set("clans.$clanId.date",       now);
                                        userDoc.set("clans.$clanId.clanSecret", clanSecret);
                                        userDoc.set("steps.clan.clanId",        clanId);
                                        userDoc.set("steps.clan.clanSecret",    clanSecret);
                                        userDoc.set("steps.clan.status",        "done");
                                        userDoc.set("steps.clan.date",          now);
                                        userDoc.set("steps.clan.result",        "created");
                                        userDoc.set("steps.clan.device",        device);
                                        userDoc.set("date",                     now);
                                        await _cloud?.write("workers", "users", userId, userDoc, region: region);
                                        _invalidateSessionCache();

                                        if (firebaseUid.isNotEmpty) {
                                            final indexDoc = Dvidle({});
                                            indexDoc.set("ownerId",                    firebaseUid);
                                            indexDoc.set("userId",                     userId);
                                            indexDoc.set("clans.$clanId.clanSecret",   clanSecret);
                                            await _cloud?.write("workers", "userindexes", firebaseUid, indexDoc, region: region);
                                        }

                                        final clanDoc = Dvidle({});
                                        clanDoc.set("clanId",          clanId);
                                        clanDoc.set("ownerId",         clanSecret);
                                        clanDoc.set("date",            now);
                                        clanDoc.set("admins",          [userId]);
                                        // Fondateur = admin à vie (jamais rétrogradable). Repli legacy = admins[0].
                                        clanDoc.set("founder",         userId);
                                        clanDoc.set("internal.name",   internalName);
                                        clanDoc.set("external.name",   externalName);
                                        clanDoc.set("description",     description);
                                        clanDoc.set("avatar",          _defaultClanAvatar);
                                        clanDoc.set("butin_xp",        0);
                                        // Snapshot d'ouverture du coffre : le butin en jeu est butin_xp −
                                        // last_butin_xp (cf. _butinCourant). Posé explicitement à la création
                                        // pour que le champ existe dès le premier cycle.
                                        clanDoc.set("last_butin_xp",   0);
                                        // Facteur de conversion XP→butin PROPRE au clan : amorcé depuis la conf,
                                        // puis modifiable en cours de partie (réglage de difficulté par famille).
                                        clanDoc.set("butin_xp_factor", _butinXpFactor);
                                        // Plafond d'UN SEUL crédit de butin PROPRE au clan (+20×niveau du clan à
                                        // l'usage, cf. _creditClanButin) : même statut d'amorçage que le facteur
                                        // ci-dessus, modifiable ensuite en cours de partie.
                                        clanDoc.set("max_xp_butin",    _butinGainMaxXp);
                                        await _cloud?.write("workers", "clans", clanId, clanDoc, region: region, ownerId: clanSecret);
                                        deva_log("info", "[worker] clan créé → firestore OK (ext: $externalName)");
                                        // Le créateur est le premier membre ET chef d'emblée (asAdmin).
                                        await _writeClanPlayer(clanId, clanSecret, userId, device, region,
                                            asAdmin: true, firstClan: firstClan);
                                        // Un clan qui naît est seul, par construction. Posé ICI parce que le
                                        // fondateur file au dashboard sans passer par l'écran Clan : sans cet
                                        // amorçage, le reminder de recrutement n'aurait pas sa condition au moment
                                        // précis où il est le plus utile — juste après la cérémonie de bienvenue.
                                        await _setClanAlone(true);
                                        // Coffre du butin + portefeuille, dès la naissance du clan (la
                                        // collection est vide : rien à vérifier, on crée les deux).
                                        await _ensureButinDocs(clanId, clanSecret, region, const <Dvidle>[]);
                                        // Journal : le clan a été créé (créateur = premier admin). La DESCRIPTION
                                        // est recopiée ici et pas seulement dans clans/{clanId} : le journal est
                                        // append-only, c'est donc lui qui garde la profession de foi d'origine
                                        // même si le clan la réécrit plus tard. C'est aussi ce qui ouvre le récit
                                        // (_logLine) et la matière que le conteur IA reçoit pour savoir QUI est
                                        // ce clan avant de raconter ses exploits.
                                        final creatorName = await _playerName(clanId, clanSecret, region, userId);
                                        // `clanName` (externe) reste pour compat — mais c'est `clanNameInternal`
                                        // (le nom choisi par la famille) que le récit et le journal affichent
                                        // désormais : le nom externe est un identifiant de confidentialité
                                        // inter-clans, pas celui que la famille reconnaît (cf. readme.md §2).
                                        await _writeClanLog(clanId, clanSecret, region, "ClanCreated",
                                            userId: userId, adminId: userId, slug: externalName,
                                            data: Dvidle({"clanName": externalName, "clanNameInternal": internalName,
                                                          "creatorId": userId,
                                                          "creatorName": creatorName,
                                                          "description": description}));
                                    } catch (e) {
                                        deva_log("error", "[worker] clan write FAILED: $e");
                                    }
                                }

                                await Deva.instance.set("session.clan.name", internalName);
                                await Deva.instance.set("worker.session.clan_done", "true");

                                // Le SCOPE de dvstore, c'est le clan — et il n'existait pas encore au
                                // démarrage du module. `store_scope` a donc rendu vide, `_resolveScope`
                                // n'a rien résolu, et sans cette relecture le PREMIER achat de chaque
                                // nouveau client échouerait en `no_scope` : le fondateur d'un clan tout
                                // juste créé est exactement la personne à qui l'on va présenter les
                                // paliers. Ici et pas ailleurs, parce que c'est le seul endroit du jeu
                                // où un scope naît (rejoindre un clan passe par une session déjà
                                // ouverte, donc par le démarrage normal du module).
                                //
                                // Sans await : la boutique n'est pas la prochaine seconde du parcours,
                                // et un aller-retour Play ne doit pas retarder l'entrée dans le donjon.
                                ActionRegistry.get("store.refresh")?.call(null, null);

                                // Bienvenue clan jouée à la 1re arrivée sur dashboard (cf. on_dashboard_appear).
                                await deva_set("worker.pending_clan_welcome", "created");
                                return "ok";
    }

    Future<void> on_decisiontree_complete(DvShape? caller, dynamic event) async {

                                DvOrb.navigate_reset("dashboard");
    }

    // Nom lisible d'un membre du clan. Joueur courant → session (aucune lecture).
    // Sinon lecture clans_players (champ `name` posé par _writeClanPlayer), avec le
    // pattern admin de _notifyAssignee (ownerId: clanSecret). Repli : le userId brut.
    Future<String> _playerName(String clanId, String clanSecret, String region, String userId) async {

                                if (userId.isEmpty) return "";
                                if (userId == _userId) {
                                    return (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                }
                                try {
                                    final p = await _cloud?.read("workers", "clans_players/$clanId/players",
                                        userId, ownerId: clanSecret, region: region);
                                    final n = p?.get("name")?.toString() ?? "";
                                    return n.isNotEmpty ? n : userId;
                                } catch (_) { return userId; }
    }

    // Libellé AFFICHABLE d'un membre. Un doc `clans_players` naît sans `name` : le nom n'est
    // demandé qu'après la liaison du compte, si bien qu'entre son entrée dans le clan et sa
    // saisie, un arrivant n'a pas de nom du tout. Le repli historique (`?? pid`) affichait
    // alors son userId — un uuid brut au milieu du roster. On affiche un libellé neutre à la
    // place ; le vrai nom arrive dès la prochaine lecture de l'écran.
    // À n'utiliser que pour de l'AFFICHAGE : le journal (clans_logs) est append-only, un id
    // brut y reste préférable à un libellé générique figé pour toujours (cf. _playerName).
    String _memberLabel(String name) =>
        name.isNotEmpty ? name : TranslationRegistry.processLabel("@@@T:member_unnamed@@@");

    // clans_logs : journal d'audit append-only du clan. ownerId = clanSecret (exigé
    // par la règle Firestore). Sous-collection clans_logs/<clanId>/logs (le clanId du
    // chemin sert à la règle). docId construit <rev>_<event>_<slug> où <rev> est un
    // nombre à 13 chiffres décroissant (9999999999999 - epochSeconds) : trié par ordre
    // croissant, les logs les plus récents remontent en tête. Pas de compteur unique —
    // deux logs dans la même seconde peuvent partager le même <rev> (toléré).
    // `data` = map JSON structurée (audit complet).
    Future<void> _writeClanLog(String clanId, String clanSecret, String region, String event,
        {String userId = "", String adminId = "", String task = "",
         String slug = "", Dvidle? data}) async {
                    if (clanId.isEmpty || clanSecret.isEmpty) return;
                    final now = DateTime.now().toUtc();
                    final rev = 9999999999999 - (now.millisecondsSinceEpoch ~/ 1000);
                    final docId = "${rev}_${event}_${_slug(slug)}";
                    final doc = Dvidle({});
                    doc.set("ownerId", clanSecret);
                    doc.set("clanId",  clanId);
                    doc.set("event",   event);
                    doc.set("userId",  userId);
                    doc.set("adminId", adminId);
                    doc.set("task",    task);
                    doc.set("data",    data ?? Dvidle({}));
                    doc.set("date",    now.toIso8601String());
                    try {
                        await _cloud?.write("workers", "clans_logs/$clanId/logs", docId, doc,
                            region: region, ownerId: clanSecret);
                    } catch (e) {
                        deva_log("error", "[worker] _writeClanLog FAILED: $e");
                    }
    }

    //-----------------------------------------------------------------------
    //-- Clan pages actions ------------------------------------------------
    //-----------------------------------------------------------------------


    Future<void> on_create_clan_appear(DvShape? caller, dynamic event) async {

                                _aiName       = "";
                                _originalDesc = null;
                                _originalName = null;
                                _cachedAiName = null;
                                _cachedAiDesc = null;
                                final nameEntry = await DvOrb.wait_for_shape("create_clan/name");
                                final descEntry = DvOrb.get_shape_by_id("create_clan/desc");
                                final replay    = DvOrb.get_shape_by_id("create_clan/replay");
                                final confirm   = DvOrb.get_shape_by_id("create_clan/confirm");
                                nameEntry?.set("shape.value", ""); nameEntry?.refreshUI();
                                descEntry?.set("shape.value", ""); descEntry?.refreshUI();
                                replay?.set("shape.visible", false); replay?.refreshUI();
                                confirm?.set("shape.opacity", 0.3);
                                confirm?.set("shape.events.tap", false);
                                confirm?.refreshUI();
    }

    // --- Overlay de confirmation « Créer un clan » (écran new_or_pick_clan, adulte) -----------------
    // Widgets posés en layer:overlay, invisibles par défaut (visible:false). On les révèle/masque à
    // la volée plutôt que via une popup modale (idiome maison, cf. overlay de mort commons/death_*).
    void _setCreateConfirmVisible(bool v) {

                                for (final id in const [
                                    "new_or_pick_clan/confirm_scrim",
                                    "new_or_pick_clan/confirm_panel",
                                    "new_or_pick_clan/confirm_scan",
                                    "new_or_pick_clan/confirm_yes",
                                    "new_or_pick_clan/confirm_no",
                                ]) {
                                    final s = DvOrb.get_shape_by_id(id);
                                    s?.set("shape.visible", v);
                                    s?.refreshUI();
                                }
    }

    Future<void> on_ask_create_clan(DvShape? caller, dynamic event) async {

                                _setCreateConfirmVisible(true);
    }

    Future<void> on_cancel_create_clan(DvShape? caller, dynamic event) async {

                                _setCreateConfirmVisible(false);
    }

    // « Quelqu'un l'a déjà créé : je scanne son QR code. » LE garde-fou du clan en double, et il
    // fallait qu'il soit une ACTION, pas une question.
    //
    // Le foyer où deux parents installent l'app chacun de son côté est le cas d'erreur le plus
    // probable de tout l'onboarding, et il est aujourd'hui IRRÉPARABLE : il n'existe aucune action
    // « quitter le clan » (revoke_player et nomore_chief refusent tous deux le fondateur), le
    // fondateur est admin à vie, et le multi-clan est post-lancement. Le second parent resterait
    // enfermé dans un clan vide, avec sa propre cotisation, sans autre issue que de supprimer son
    // compte. On ne peut donc que PRÉVENIR — et prévenir en donnant une sortie, là où l'écran ne
    // posait qu'une question à laquelle le parent, par définition, ne sait pas répondre.
    Future<void> on_create_clan_goto_join(DvShape? caller, dynamic event) async {

                                _setCreateConfirmVisible(false);
                                // Même route que le bouton « rejoindre » de l'écran (steps.navigate.join
                                // → kid_wants_clan), pour ne pas dupliquer la navigation d'onboarding.
                                final r = ActionRegistry.get("steps.navigate.join")?.call(caller, event);
                                if (r is Future) await r;
    }

    Future<void> on_confirm_create_clan_choice(DvShape? caller, dynamic event) async {

                                _setCreateConfirmVisible(false);
                                // Rejoue la navigation d'origine du bouton créer (step new_or_pick_clan, route create → create_clan).
                                final r = ActionRegistry.get("steps.navigate.create")?.call(caller, event);
                                if (r is Future) await r;
    }

    // --- Bouton « marche arrière » adulte sur l'écran de rejointe (kid_wants_clan) -----------------
    // Invisible par défaut ; révélé uniquement pour l'adulte (venu de new_or_pick_clan via « Rejoindre »).
    // Les mineurs (k/t) arrivent ici en racine et ne doivent jamais atteindre l'option « créer ».
    Future<void> on_kid_wants_clan_appear(DvShape? caller, dynamic event) async {

                                // Premier instant où une écriture devient indispensable au mineur : le lobby
                                // ne peut lui transmettre le clanSecret que sous un uid connu. On inscrit donc
                                // tout l'onboarding MAINTENANT, avant la moindre soumission. Le faire après
                                // l'admission laisserait un doc `users` porteur de steps.clan mais privé de
                                // steps.region — _findBestSession l'ignore, et un mineur pourtant admis
                                // repartirait en onboarding au lancement suivant.
                                // (Un adulte n'entre jamais ici en anonyme : son link précède new_or_pick_clan.)
                                if (_anon && !await _flushOnboarding()) {
                                    final err = await DvOrb.wait_for_shape("kid_wants_clan/region_error");
                                    err?.set("shape.label", TranslationRegistry.processLabel("@@@T:link_flush_failed@@@"));
                                    if (err is DvLabel) await err.computeDisplay();
                                    err?..set("shape.visible", true)..refreshUI();
                                    // Tant que rien n'est en base, aucune demande d'entrée ne peut aboutir.
                                    for (final id in ["kid_wants_clan/scan_qr", "kid_wants_clan/send_request"]) {
                                        DvOrb.get_shape_by_id(id)?..set("shape.events.tap", false)..refreshUI();
                                    }
                                    return;
                                }

                                final raw   = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                // Mineur : on l'avertit que la connexion Google viendra APRÈS l'admission, et
                                // qu'un compte supervisé demandera l'accord d'un parent. C'est le seul moment où
                                // le chef de clan est probablement encore à côté de lui, son QR code à la main.
                                // (Même bande que le bouton « marche arrière » de l'adulte : jamais les deux.)
                                //
                                // Conditionné à _anon, et pas au seul état légal : un mineur DÉJÀ lié qui vient
                                // rejoindre un second clan n'a plus aucune liaison devant lui, lui annoncer une
                                // connexion Google serait faux.
                                if (_gameplayLegal(raw) != "a") {
                                    if (_anon) {
                                        final notice = await DvOrb.wait_for_shape("kid_wants_clan/notice");
                                        notice?..set("shape.visible", true)..refreshUI();
                                    }
                                    return;
                                }
                                final back = await DvOrb.wait_for_shape("kid_wants_clan/back");
                                back?.set("shape.visible", true);
                                back?.set("shape.events.tap", true);
                                back?.refreshUI();
    }

    Future<void> on_back_to_choice(DvShape? caller, dynamic event) async {

                                DvOrb.navigate_back("new_or_pick_clan");
    }

    Future<void> on_create_clan_name_changed(DvShape caller, dynamic event) async {

                                final value   = caller.get("shape.value")?.toString() ?? "";
                                _originalName = value.trim();
                                final confirm = DvOrb.get_shape_by_id("create_clan/confirm");
                                final enabled = value.trim().isNotEmpty;
                                confirm?.set("shape.opacity", enabled ? 0.6 : 0.3);
                                confirm?.set("shape.events.tap", enabled);
                                confirm?.refreshUI();
    }

    Future<void> on_create_clan_desc_changed(DvShape caller, dynamic event) async {

                                _originalDesc = caller.get("shape.value")?.toString().trim() ?? "";
    }

    Future<void> on_inspire_clan(DvShape? caller, dynamic event) async =>
        _runInspire("create_clan", "inspire_clan", "inspire_fallback_");

    Future<void> on_replay_clan(DvShape? caller, dynamic event) async =>
        _runReplay("create_clan", "inspire_clan", "inspire_fallback_");

    Future<String> on_confirm_create_clan(DvShape? caller, dynamic event) async {

                                final nameEntry = DvOrb.get_shape_by_id("create_clan/name");
                                final descEntry = DvOrb.get_shape_by_id("create_clan/desc");
                                final name      = nameEntry?.get("shape.value")?.toString().trim() ?? "";
                                if (name.isEmpty) return "cancel";
                                final desc = descEntry?.get("shape.value")?.toString().trim() ?? "";
                                return await on_create_clan_complete(null, {
                                    "internal_name": name,
                                    "description":   desc,
                                    "ai_name":       _aiName,
                                });
    }

    // Selector du menu d'en-tête du clan (DvMenuButton, charge vide). Seuls le journal et les
    // tutoriels sont ouverts à tous ; recruter (QR, invitation à distance) et « Créer un joueur »
    // sont des prérogatives de chef (admin). Le menu s'affiche dans l'ordre de la liste renvoyée :
    // on calcule donc `isAdmin` d'abord, et on monte la liste dans l'ordre historique.
    //
    // « Mes achats » n'est plus ici : il a rejoint le kebab de la boutique
    // (worker.shop_settings_selector), avec le reste de ce qui touche à l'argent.
    Future<List<String>> clan_settings_selector(dynamic caller, dynamic data) async {

                                var isAdmin = false;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    isAdmin = await _ensureIsAdmin(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[clan] clan_settings_selector FAILED: $e");
                                }
                                // Lecture KO → isAdmin false : repli sûr (les options chef restent cachées).
                                final options = <String>["clan_log"];
                                if (isAdmin) options.addAll(["clan_qr", "clan_invite_remote"]);
                                options.add("tutorials");
                                if (isAdmin) options.add("create_player");
                                return options;
    }

    //-----------------------------------------------------------------------
    //-- Join clan (candidat) ---------------------------------------------
    //-----------------------------------------------------------------------

    // Un clan vit dans UNE SEULE région : ses données sont dans la base de cette région et
    // rien ne traverse. Une invitation émise ailleurs ne mènerait donc qu'à un « clan
    // introuvable » silencieux — autant le dire franchement.
    // Une invitation sans région (lien émis avant l'ouverture de la seconde région) passe :
    // il n'y avait alors qu'une région, la comparaison n'a pas de sens.
    // Retourne true si l'invitation doit être refusée (le message est déjà affiché).
    Future<bool> _inviteRegionMismatch(String inviteRegion, String errorShapeId) async {

                                if (inviteRegion.isEmpty) return false;

                                final mine = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (mine.isEmpty || mine.toLowerCase() == inviteRegion.toLowerCase()) return false;

                                deva_log("info", "[worker] invitation région=$inviteRegion, session région=$mine — refusée");

                                // computeDisplay() obligatoire : DvLabel ne peint que shape.display,
                                // écrire shape.label seul laisserait la shape visible mais vide.
                                final err = DvOrb.get_shape_by_id(errorShapeId);
                                err?.set("shape.label", TranslationRegistry.processLabel("@@@T:invite_wrong_region@@@"));
                                if (err is DvLabel) await err.computeDisplay();
                                err?.set("shape.visible", true);
                                err?.refreshUI();
                                return true;
    }

    Future<void> on_scan_qr(DvShape? caller, dynamic event) async {

                                final fut = ActionRegistry.get("qrcodereader.scan")?.call(caller, event);
                                if (fut is Future) await fut;

                                final content = (await deva_get("commons.qrcodereader.result"))?.toString() ?? "";
                                if (content.isEmpty) return;

                                final uri = Uri.tryParse(content);
                                if (uri == null || uri.scheme != "ddust" || uri.host != "invite") return;

                                final groupId = uri.queryParameters["group_id"] ?? "";
                                final lobbyId = uri.queryParameters["lobby_id"] ?? "";
                                final region  = uri.queryParameters["region"]   ?? "";
                                if (groupId.isEmpty || lobbyId.isEmpty) return;

                                // Le contrôle de région est fait par on_invite_clan_link, commun au QR et au deeplink.
                                await on_invite_clan_link(caller, {"group_id": groupId, "lobby_id": lobbyId, "region": region});
    }

    Future<void> on_request_link(DvShape? caller, Map event) async {

                                await deva_set("worker.pending_lobby_id", event["lobby_id"]?.toString() ?? "");
                                if (_cloud?.isReady() ?? false) DvOrb.navigate_new("accept_request_clan");
    }

    Future<void> on_accept_request_clan(DvShape? caller, dynamic event) async {

                                final region  = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session = region.isNotEmpty ? await _readSession(region) : null;
                                final groupId = session?.get("steps.clan.clanId")?.toString() ?? "";
                                final lobbyId = (await deva_get("worker.pending_lobby_id"))?.toString() ?? "";
                                if (groupId.isEmpty || lobbyId.isEmpty) return;

                                // Plafond de membres : accepter une demande fait entrer quelqu'un, tout
                                // comme émettre une invitation. Le refus ici évite d'accepter un
                                // candidat que le clan ne pourra pas accueillir — la déception serait
                                // pour lui, pas pour le chef.
                                if (await _storeRefuseMember()) {
                                    deva_log("info", "[worker] on_accept_request_clan: refusé (clan au complet)");
                                    return;
                                }

                                final lobby = ModuleRegistry.create("dvvirtuallobby");
                                if (lobby == null) return;
                                await (lobby as dynamic).createManagement(groupId, lobbyId: lobbyId);
                                await (lobby as dynamic).accept(groupId, lobbyId);
    }

    Future<void> on_virtuallobby_accepted(DvShape? caller, Map event) async {

                                final groupId = event["group_id"]?.toString() ?? "";
                                final lobbyId = event["lobby_id"]?.toString() ?? "";
                                final region  = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session = region.isNotEmpty ? await _readSession(region) : null;
                                final hasClan = session?.get("steps.clan") != null;

                                deva_log("info", "[worker] on_virtuallobby_accepted: groupId=$groupId lobbyId=$lobbyId hasClan=$hasClan");

                                if (!hasClan && groupId.isNotEmpty) {
                                    await _handleClanJoin(groupId, lobbyId, region);
                                } else {
                                    // Plafond de membres, vérifié à CHAQUE admission et pas seulement à
                                    // l'ouverture du recrutement : un QR affiché une fois peut servir à
                                    // plusieurs candidats, et _clanIdIfChief n'a compté les places
                                    // qu'au premier. C'est ici, sur l'appareil du chef, que le clan
                                    // s'agrandit réellement — le seul endroit qui connaisse l'effectif
                                    // et qui ait l'autorité de payer pour l'augmenter.
                                    //
                                    // Sans publication du secret, l'appareil du candidat ne peut pas
                                    // écrire son doc clans_players : il repart vers decisiontree
                                    // (branche « virtuallobbysecret introuvable » de _handleClanJoin).
                                    // Refuser ici plutôt que là-bas est ce qui évite un demi-enrôlement
                                    // — un membre à moitié écrit serait pire que le refus.
                                    if (lobbyId.isNotEmpty && await _storeRefuseMember()) {
                                        deva_log("info", "[worker] on_virtuallobby_accepted: admission refusée (clan au complet)");
                                        return;
                                    }
                                    if (lobbyId.isNotEmpty) {
                                        final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                        final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                        if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                            deva_log("info", "[worker] publishSecret: lobbyId=$lobbyId groupId=$groupId");
                                            final lobby = ModuleRegistry.create("dvvirtuallobby");
                                            await (lobby as dynamic).publishSecret(lobbyId, groupId, {"clanId": clanId, "clanSecret": clanSecret, "adminId": _userId});
                                            // Le clan s'agrandit réellement ici, sur l'appareil du chef : le
                                            // reminder de recrutement doit s'éteindre TOUT DE SUITE, sans attendre
                                            // la prochaine lecture du roster (le chef repart au dashboard).
                                            await _setClanAlone(false);
                                        } else {
                                            deva_log("error", "[worker] on_virtuallobby_accepted: clanId ou clanSecret absent de la session");
                                        }
                                    }
                                    DvOrb.navigate_reset("dashboard");
                                }
    }

    Future<void> on_submission_status_changed(DvShape? caller, Map event) async {

                                final status  = event["status"]?.toString()   ?? "";
                                final groupId = event["group_id"]?.toString() ?? "";
                                final lobbyId = event["lobby_id"]?.toString() ?? "";

                                if (status == "accepted" && groupId.isNotEmpty) {
                                    ActionRegistry.get("virtuallobby.stop_watching")?.call(null, null);
                                    final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    await _handleClanJoin(groupId, lobbyId, region);
                                }
    }

    Future<void> _handleClanJoin(String groupId, String lobbyId, String region) async {

                                final docId = _sessionDocId();
                                if (docId.isEmpty) { DvOrb.navigate_reset("decisiontree"); return; }

                                // 1. Lire le clanSecret depuis virtuallobbysecret (via moteur, avec retry + delete)
                                deva_log("info", "[worker] _handleClanJoin: consumeSecret lobbyId=$lobbyId");
                                final lobby    = ModuleRegistry.create("dvvirtuallobby");
                                final secret   = await (lobby as dynamic).consumeSecret(lobbyId);
                                final clanId     = secret?.get("clanId")?.toString()     ?? "";
                                final clanSecret = secret?.get("clanSecret")?.toString() ?? "";
                                final adminId    = secret?.get("adminId")?.toString()    ?? "";
                                deva_log("info", "[worker] _handleClanJoin: secret=${secret != null ? 'ok' : 'null'} clanId=${clanId.isNotEmpty ? 'ok' : 'vide'}");

                                if (clanId.isEmpty || clanSecret.isEmpty) {
                                    deva_log("error", "[worker] _handleClanJoin: virtuallobbysecret introuvable pour lobbyId=$lobbyId");
                                    if (region.isNotEmpty) await _writeStep(region, "clan", "joined");
                                    await Deva.instance.set("worker.session.clan_done", "true");
                                    DvOrb.navigate_reset("decisiontree");
                                    return;
                                }

                                // 2. Mettre à jour workers.users et userindexes
                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                // Clan d'origine à propager au doc membre (clans_players.original_clan) ; repli = ce clan.
                                String firstClan = clanId;
                                if (region.isNotEmpty) {
                                    try {
                                        final device      = await _cloud?.deviceId() ?? "";
                                        final now         = DateTime.now().toUtc().toIso8601String();
                                        final existing    = await _readSession(region) ?? Dvidle({});
                                        existing.rem("docId");
                                        // first_clan (users) = tout premier clan du joueur, figé s'il est vide.
                                        if ((existing.get("first_clan")?.toString() ?? "").isEmpty)
                                            existing.set("first_clan", clanId);
                                        firstClan = existing.get("first_clan")?.toString() ?? clanId;
                                        existing.set("ownerId",                     firebaseUid);
                                        existing.set("userId",                      docId);
                                        existing.set("last_clan",                   clanId);
                                        existing.set("clans.$clanId.date",          now);
                                        existing.set("clans.$clanId.clanSecret",    clanSecret);
                                        existing.set("steps.clan.clanId",           clanId);
                                        existing.set("steps.clan.clanSecret",       clanSecret);
                                        existing.set("steps.clan.status",           "done");
                                        existing.set("steps.clan.date",             now);
                                        existing.set("steps.clan.result",           "joined");
                                        existing.set("steps.clan.device",           device);
                                        existing.set("date",                        now);
                                        await _cloud?.write("workers", "users", docId, existing, region: region);
                                        _invalidateSessionCache();
                                    } catch (e) {
                                        deva_log("error", "[worker] _handleClanJoin: users write FAILED: $e");
                                    }
                                }

                                // userindexes doit avoir le clanSecret avant le read/update du clan
                                if (firebaseUid.isNotEmpty) {
                                    try {
                                        final indexDoc = Dvidle({});
                                        indexDoc.set("ownerId",                  firebaseUid);
                                        indexDoc.set("userId",                   docId);
                                        indexDoc.set("clans.$clanId.clanSecret", clanSecret);
                                        await _cloud?.write("workers", "userindexes", firebaseUid, indexDoc, region: region);
                                    } catch (e) {
                                        deva_log("error", "[worker] _handleClanJoin: userindexes update FAILED: $e");
                                    }
                                }

                                // 3. Ajouter le candidat comme membre : doc dédié dans clans_players.
                                //    Le doc clan n'est lu que pour son nom d'affichage (internal.name).
                                String clanName = "";
                                Set<String> enabledMultiple = {};
                                try {
                                    final clan = await _cloud?.read(
                                        "workers", "clans", clanId,
                                        ownerId: clanSecret, region: region,
                                    );
                                    if (clan != null) {
                                        clanName = clan.get("internal.name")?.toString() ?? "";
                                        final em = clan.get("enabled_multiple");
                                        if (em is List) enabledMultiple = em.map((e) => e.toString()).toSet();
                                    }
                                    final device = await _cloud?.deviceId() ?? "";
                                    await _writeClanPlayer(clanId, clanSecret, docId, device, region, firstClan: firstClan);
                                } catch (e) {
                                    deva_log("error", "[worker] _handleClanJoin: clans_players update FAILED: $e");
                                }

                                // Annoncer l'arrivée aux membres déjà présents (notif push thème donjon).
                                // Le nom n'est demandé qu'APRÈS la liaison du compte : à cet instant il est
                                // encore vide pour un nouveau venu. On DIFFÈRE alors l'annonce et la ligne de
                                // journal jusqu'à sa saisie (_persistPlayerName les consomme). clans_logs est
                                // append-only : une entrée écrite sans nom resterait anonyme pour toujours.
                                final myName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                if (myName.isEmpty) {
                                    await deva_set("worker.pending_member_joined.clanId",     clanId);
                                    await deva_set("worker.pending_member_joined.clanSecret", clanSecret);
                                    await deva_set("worker.pending_member_joined.region",     region);
                                    await deva_set("worker.pending_member_joined.adminId",    adminId);
                                    await Deva.instance.store();
                                } else {
                                    try {
                                        await _notifyClanNewMember(clanId, clanSecret, region, docId, myName);
                                    } catch (e) {
                                        deva_log("error", "[worker] _handleClanJoin: notif nouveau membre FAILED: $e");
                                    }
                                    // Journal : un utilisateur a rejoint le clan (adminId = accepteur, via lobby).
                                    await _writeClanLog(clanId, clanSecret, region, "MemberJoined",
                                        userId: docId, adminId: adminId, slug: myName,
                                        data: Dvidle({"userId": docId, "userName": myName, "adminId": adminId}));
                                }

                                // Créer les clones de l'arrivant pour les tâches multiple activées qu'il
                                // qualifie (legal_state) — les docs de base n'existent pas pour ces tâches.
                                // _writeClanPlayer ci-dessus a (ré)écrit legal_state ; on peut cloner ensuite.
                                try {
                                    await _createMyClones(clanId, clanSecret, region, enabledMultiple);
                                } catch (e) {
                                    deva_log("error", "[worker] _handleClanJoin: _createMyClones FAILED: $e");
                                }

                                // Charger l'état domaines/tâches du clan (miroir local + notif tiroirs),
                                // comme on_login() le fait pour le propriétaire via _loadClanTasks().
                                // `existing` est hors portée ici (déclaré dans le bloc region ci-dessus),
                                // on relit donc la session persistée qui porte steps.clan.clanId/clanSecret.
                                if (region.isNotEmpty) {
                                    final joined = await _readSession(region);
                                    if (joined != null) await _loadClanTasks(joined, region);
                                }

                                await Deva.instance.set("session.clan.name", clanName);
                                await Deva.instance.set("worker.session.clan_done", "true");
                                // Bienvenue clan jouée à la 1re arrivée sur dashboard (cf. on_dashboard_appear).
                                await deva_set("worker.pending_clan_welcome", "joined");
                                // En flux QR/PIN d'onboarding, l'app a déjà atterri sur le dashboard AVANT que le
                                // chef n'accepte (on navigue dès la soumission) : il n'y aura donc aucun nouvel
                                // `appear` pour consommer le drapeau, et la bienvenue ne serait jamais jouée — ou
                                // jouée bien plus tard, hors contexte. On la joue donc ici même ; le tutoriel, lui,
                                // s'ouvrira derrière la fin de l'animation (on_celebration_end), comme partout.
                                // Compte pas encore lié (parcours mineur) : la liaison passe avant tout le
                                // reste. La cérémonie de bienvenue n'est PAS jouée ici — son drapeau reste
                                // armé et on_dashboard_appear la jouera à l'arrivée, dans son contexte et
                                // avec le tutoriel derrière. La déclencher maintenant la ferait couper net
                                // par la navigation, et le tutoriel s'ouvrirait sur l'écran de liaison.
                                //
                                // store() OBLIGATOIRE avant de partir sur l'écran de liaison, et pas
                                // seulement par prudence : la liaison du compte passe par
                                // dvcloud_motor._setupUserOwner → deva.loadOwnerConfig, qui RELIT
                                // runtime-<ownerId>.yml DEPUIS LE DISQUE (le layer en mémoire est remplacé,
                                // cf. DvLayers._loadFile) puis vide le store (_applyMerge → _store.clear()).
                                // Tout ce qui n'a pas été persisté à cet instant est perdu — c'est ce qui
                                // effaçait clan_done juste au-dessus, si bien qu'un mineur fraîchement admis
                                // repartait sur new_or_pick_clan après avoir saisi son nom, et que sa
                                // cérémonie de bienvenue (pending_clan_welcome) ne se jouait jamais. Le
                                // store() de la branche « nom vide » plus haut ne suffit pas : il précède
                                // les deux drapeaux.
                                if (_anon) {
                                    await Deva.instance.store();
                                    await _requireAccountLink();
                                    return;
                                }
                                if (DvOrb.get_current_page()?.dvid == "dashboard") {
                                    await _playPendingClanWelcome();
                                } else {
                                    await ActionRegistry.get("steps.navigate")?.call(null, null);
                                }
    }

    // Consomme l'annonce d'arrivée mise en attente par _handleClanJoin — le joueur n'avait
    // alors pas encore de nom, le sien est demandé après la liaison du compte. Appelée par
    // _persistPlayerName. One-shot : le drapeau est effacé quoi qu'il advienne ensuite,
    // une arrivée qu'on n'a pas su annoncer ne se rattrape pas des jours plus tard.
    Future<void> _flushPendingMemberJoined(String name) async {

                                final clanId = (await deva_get("worker.pending_member_joined.clanId"))?.toString() ?? "";
                                if (clanId.isEmpty || name.isEmpty) return;
                                final clanSecret = (await deva_get("worker.pending_member_joined.clanSecret"))?.toString() ?? "";
                                final region     = (await deva_get("worker.pending_member_joined.region"))?.toString()     ?? "";
                                final adminId    = (await deva_get("worker.pending_member_joined.adminId"))?.toString()    ?? "";
                                await Deva.instance.set("worker.pending_member_joined", null);
                                await Deva.instance.store();
                                if (clanSecret.isEmpty || region.isEmpty) return;

                                final docId = _sessionDocId();
                                try {
                                    await _notifyClanNewMember(clanId, clanSecret, region, docId, name);
                                } catch (e) {
                                    deva_log("error", "[worker] _flushPendingMemberJoined: notif FAILED: $e");
                                }
                                await _writeClanLog(clanId, clanSecret, region, "MemberJoined",
                                    userId: docId, adminId: adminId, slug: name,
                                    data: Dvidle({"userId": docId, "userName": name, "adminId": adminId}));
    }

    //-----------------------------------------------------------------------
    //-- Enregistrement joueur + device dans players (cibles FCM) -----------
    //-----------------------------------------------------------------------

    // Écrit (ou met à jour) le document membre clans_players/{clanId}/players/{userId} :
    // id du joueur + deviceId courant (clé de messaging.msgregistry → token FCM). Lit,
    // fusionne et réécrit le doc membre ; idempotent (pas de doublon de device). Chaque
    // membre n'écrit que son propre document → plus de contention sur le doc clan.
    // Préserve l'xp/pv existants ; initialise xp=0 et pv=10 à la première écriture. Le
    // niveau n'est pas stocké : il se dérive de l'xp via getNiveauProgres().
    // Stocke aussi legal_state ("k"=enfant, "a"=adulte), rafraîchi à chaque écriture.
    // asAdmin : true UNIQUEMENT à la création du clan (le créateur est chef d'emblée). Pour tous
    // les autres records, is_admin est initialisé à false (init-si-null : jamais réécrit ici, il
    // évoluera via promote_chief / nomore_chief). Ce champ vit sur le doc du joueur pour que SA
    // propre vigilance (_startPlayerVigilance) se déclenche quand son statut chef change.
    // nameOverride / legalStateOverride : posés au lieu des valeurs de session (utilisés pour
    // créer un joueur ENFANT sans compte — cf. on_create_player_confirm — dont le nom et le
    // statut légal ("k") ne doivent PAS hériter de ceux du parent authentifié). noAccount marque
    // ce joueur comme dépourvu de doc `users`/`userindexes` (pilote la dérogation de révocation).
    Future<void> _writeClanPlayer(
        String clanId, String clanSecret, String userId, String device, String region,
        {bool asAdmin = false, String firstClan = "",
         String nameOverride = "", String legalStateOverride = "", bool noAccount = false}) async {

            if (clanId.isEmpty || clanSecret.isEmpty || userId.isEmpty) return;
            try {
                final existing = await _cloud?.read(
                    "workers", "clans_players/$clanId/players", userId,
                    ownerId: clanSecret, region: region,
                );
                final doc = existing ?? Dvidle({});
                final devices = List<dynamic>.from(doc.get("devices") as List? ?? []);
                if (device.isNotEmpty && !devices.contains(device)) devices.add(device);
                doc.set("id",      userId);
                doc.set("lang",    TranslationRegistry.currentLang);
                doc.set("devices", devices);
                // Traçabilité de connexion : rafraîchis à chaque appel (donc à chaque login,
                // via on_login → _writeClanPlayer). last_version = semver de l'app courante
                // (conf.application.version, injectée au build), last_connected = date ISO.
                //
                // last_connected est aussi la SEULE trace de vie d'un clan lisible sans ouvrir
                // l'app : c'est sur elle que le balayeur de relance (pulse_sweeper) décide
                // qu'une famille a décroché. Un clan qui décroche est justement un clan que
                // plus personne n'ouvre — aucun client ne peut donc s'en charger.
                doc.set("last_connected", DateTime.now().toUtc().toIso8601String());
                doc.set("last_version",   (await deva_get("application.version"))?.toString() ?? "");
                // Décalage horaire du membre, en minutes. PAS ENCORE EXPLOITÉ : le balayeur de
                // relance part à heure fixe UTC (une par région), ce qui reste un compromis à
                // l'intérieur de chaque fuseau régional. On le collecte dès maintenant pour que
                // le découpage par heure locale RÉELLE ne soit qu'un changement de requête, et
                // non une reprise de données sur des familles qu'on n'ouvre plus.
                doc.set("tz_offset", DateTime.now().timeZoneOffset.inMinutes);
                // Rappels de relance : refus explicite du joueur (réglage « Rappels » du kebab
                // Personnage, ou décision d'un chef pour un enfant depuis le roster). Init-si-null
                // pour que les docs antérieurs basculent au défaut sans migration — et le défaut
                // est `true`, sans quoi la fonctionnalité naîtrait éteinte pour tout le monde.
                if (doc.get("nudges") == null) doc.set("nudges", true);
                // Nom lisible du membre (réutilisé par le journal d'audit clans_logs). nameOverride
                // = renommage explicite (ou création d'un joueur enfant) : il fait autorité. Sinon
                // INIT-SI-NULL depuis la session, comme avatar/is_admin juste en dessous — le nom
                // n'est plus réécrit à chaque login, sinon la reconnexion d'un joueur écraserait le
                // renommage qu'un admin a posé en prenant sa place. Garde non-vide dans les deux
                // cas : ne jamais écraser un nom stocké par une session pas hydratée.
                if (nameOverride.isNotEmpty) {
                    doc.set("name", nameOverride);
                } else if ((doc.get("name")?.toString() ?? "").isEmpty) {
                    final myName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                    if (myName.isNotEmpty) doc.set("name", myName);
                }
                // Avatar du membre : posé au défaut à la création, jamais écrasé ensuite
                // (l'utilisateur peut le changer via l'explorateur → clans_players.avatar).
                if (doc.get("avatar")    == null) doc.set("avatar", _defaultPlayerAvatar);
                if (doc.get("xp")        == null) doc.set("xp", 0);
                // Plafond d'XP d'UNE tâche, porté par le JOUEUR (et non par la conf) : c'est une
                // caractéristique de personnage, appelée à varier d'un joueur à l'autre (pouvoirs,
                // classes…). La conf ne fait que l'amorcer. Init-si-null → les docs antérieurs au
                // champ se migrent seuls à la première connexion, comme `wallet` ci-dessous.
                if (doc.get("max_xp")    == null) doc.set("max_xp", _playerMaxXp);
                // Réalignement UNIQUE de l'ancienne valeur d'amorçage (500) sur le nouveau barème
                // indexé au niveau : sans lui, les joueurs créés avant l'introduction du bonus de
                // niveau garderaient pour toujours l'ancien plafond fixe, hors du nouveau barème.
                // Ne touche QUE la valeur EXACTEMENT égale à l'ancien amorçage — un plafond
                // personnalisé (pouvoir, classe) n'est jamais écrasé. `_playerMaxXpLegacy` = 0
                // désactive ce réalignement (conf `worker.player_max_xp_legacy`), une fois tous les
                // clans passés.
                if (_playerMaxXpLegacy > 0 &&
                    doc.get("max_xp")?.toString() == "$_playerMaxXpLegacy") doc.set("max_xp", _playerMaxXp);
                if (doc.get("gold")      == null) doc.set("gold", 0);
                // MIROIR du solde de la bourse (clans_items/{clan}/items/wallet_{userId}.quantity),
                // qui reste la source de vérité. Il vit ici pour que le roster affiche l'argent de
                // chaque membre sans lire une SECONDE collection à chaque ouverture de l'écran Clan :
                // clans_players est déjà listé, autant que la somme y soit. Contrepartie : toute
                // écriture qui bouge une bourse doit poser les deux valeurs dans le MÊME batch
                // (ouverture du butin, retour au coffre, paiement du tribut).
                // Init-si-null depuis le VRAI solde, et seulement si on a pu le lire : les clans
                // existants se migrent ainsi tout seuls à la première connexion de chaque joueur,
                // sans jamais risquer d'écrire un 0 sur une bourse pleine (lecture ratée → on
                // laisse le champ absent, la prochaine connexion réessaiera).
                final needWallet = doc.get("wallet") == null;
                final walletQty  = await _ensurePlayerWallet(clanId, clanSecret, userId, region,
                                                             needQuantity: needWallet);
                if (needWallet && walletQty != null) doc.set("wallet", walletQty);
                if (doc.get("pv")        == null) doc.set("pv", _playerPv);
                if (doc.get("damage")    == null) doc.set("damage", 0);
                if (doc.get("decay")     == null) doc.set("decay", _playerDecay);
                // status : état de vie du joueur, posé "alive" à la création puis jamais réécrit ici
                // (il évoluera ensuite vers "dead" etc. par d'autres flux).
                if (doc.get("status")    == null) doc.set("status", "alive");
                // Snapshot de l'XP DU JOUEUR au dernier coffre ouvert : sa contribution au cycle
                // courant est xp − last_butin_xp. Même rôle que le champ homonyme du doc clan
                // (cf. _butinCourant), mais sur l'XP joueur et non sur le butin — deux grandeurs
                // différentes, ne pas les comparer.
                if (doc.get("last_butin_xp") == null) doc.set("last_butin_xp", 0);
                // Tombstone d'appartenance : true par défaut (init-si-null, jamais réécrit ici).
                // Passe à false via revoke_player → le membre est ignoré partout (roster/XP/butin/notifs).
                if (doc.get("enabled")   == null) doc.set("enabled", true);
                // Clan d'origine : miroir de users.first_clan, transmis par le funnel create/join.
                // Init-si-null (fige le tout premier clan) : sert au clan_selector (protection mineur).
                if (firstClan.isNotEmpty && doc.get("original_clan") == null) doc.set("original_clan", firstClan);
                // Statut chef (source d'autorisation = clans.admins ; ce champ en est le miroir sur
                // le doc du joueur, pour réveiller sa vigilance quand il change). Créateur → true.
                if (doc.get("is_admin")  == null) doc.set("is_admin", asAdmin);
                // Cooldowns des actions admin (coup de pouce / guérir) : init à une date TRÈS
                // ancienne (et NON `now`) pour qu'un joueur/admin fraîchement créé ne soit pas
                // faussement en cooldown — sinon « Coup de pouce »/« Guérir » restaient grisés
                // 3 jours après l'entrée dans le clan sans qu'aucune action n'ait été faite.
                // Mis à jour ensuite par support_player / revive_player. Vivent ici
                // (clans_players), pas sur le doc `users`.
                const epochIso = "1970-01-01T00:00:00.000Z";
                if (doc.get("last_boost") == null) doc.set("last_boost", epochIso);
                if (doc.get("last_cure")  == null) doc.set("last_cure",  epochIso);
                // last_task : posé une seule fois à la création du joueur (= date d'entrée dans le
                // clan), puis rafraîchi à chaque tâche finie via _touchLastTask. Jamais écrasé ici.
                if (doc.get("last_task") == null) doc.set("last_task", DateTime.now().toUtc().toIso8601String());
                // legal_state ("k"=enfant, "a"=adulte, "t"=transition en cours) : écrit à frais depuis
                // la session, mais jamais écrasé par une valeur vide (session pas encore hydratée). Et
                // SURTOUT : ne jamais rétrograder une bascule légale posée à distance — la session est
                // ré-hydratée à "k" à chaque login, or un "t" (déclaré adulte par le tuteur) ou un "a"
                // (statut adulte acquis) doivent primer. On n'écrit donc que si l'existant n'est ni "t" ni "a".
                final legalState     = legalStateOverride.isNotEmpty
                    ? legalStateOverride
                    : (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "";
                final existingLegal  = doc.get("legal_state")?.toString() ?? "";
                if (legalState.isNotEmpty && existingLegal != "t" && existingLegal != "a") {
                    doc.set("legal_state", legalState);
                }
                // Joueur sans compte (enfant) : marqueur init-si-null. Distingue les membres
                // dépourvus de doc `users`/`userindexes` (pilotés via « prendre la place »).
                if (noAccount && doc.get("no_account") == null) doc.set("no_account", true);
                // has_device : présence d'un appareil du joueur DANS CE CLAN. Toute connexion
                // (re)donne un device → on force true à chaque appel (donc à chaque login), et
                // JAMAIS init-si-null (l'admin peut le remettre à false via declare_offline entre
                // deux logins). Naît true à la création (valeur absente ci-dessus). false explicite
                // = déclaré hors ligne : le jeu l'ignore (roster/XP/butin/mort). Une reconnexion
                // depuis cet état repart propre : on recale last_task=now (PV pleins, pas de mort
                // héritée pendant l'absence). Reste borné à ce clan (write d'un seul doc).
                final wasOffline = doc.get("has_device") == false;
                doc.set("has_device", true);
                if (wasOffline) doc.set("last_task", DateTime.now().toUtc().toIso8601String());
                await _cloud?.write(
                    "workers", "clans_players/$clanId/players", userId, doc,
                    region: region, ownerId: clanSecret,
                );
                // Le doc vient d'être réécrit : la valeur mémorisée pour le badge de combat peut
                // dater d'avant (repli sur la conf pris avant l'initialisation du champ). On la
                // jette plutôt que de la deviner — la prochaine ouverture de combat relira.
                _maxXpCache.remove(userId);
            } catch (e) {
                deva_log("error", "[worker] _writeClanPlayer: FAILED: $e");
            }
    }

    // Portefeuille PERSONNEL du joueur (cf. _playerWalletId), créé EN MÊME TEMPS que lui : chaque
    // membre a sa bourse dès son entrée dans le clan, vide, au lieu de l'obtenir par effet de bord
    // d'une distribution de butin (_distributeButin la crée toujours, pour les clans d'avant).
    // IDEMPOTENT PAR CONSTRUCTION : écriture partielle (deep-merge dvcloud) qui ne porte JAMAIS
    // `quantity`. Rejouée à chaque login, elle ne peut donc pas écraser un solde — et les trois
    // champs qu'elle pose sont invariants dans la vie du document, si bien que la réécriture
    // répare un document abîmé plutôt qu'elle ne l'altère.
    // Pas de `read` PRÉALABLE : les règles de clans_items refusent un `get` sur un document qui
    // n'existe pas encore — c'est déjà pourquoi _ensureButinDocs travaille depuis un `list`.
    // `needQuantity` demande le solde EN RETOUR (null si indisponible) : la relecture se fait alors
    // APRÈS l'écriture, moment où le document existe forcément. Elle ne sert qu'à amorcer le miroir
    // clans_players.wallet, donc on ne la demande qu'une fois par joueur — une fois le champ posé,
    // ce chemin ne coûte plus rien de plus qu'avant.
    Future<int?> _ensurePlayerWallet(String clanId, String clanSecret, String userId,
                                     String region, {bool needQuantity = false}) async {

            if (clanId.isEmpty || clanSecret.isEmpty || userId.isEmpty) return null;
            try {
                final doc = Dvidle({});
                doc.set("ownerId", clanSecret);
                doc.set("type",    "argent_poche");
                doc.set("owner",   userId);
                await _cloud?.write(
                    "workers", "clans_items/$clanId/items", _playerWalletId(userId), doc,
                    region: region, ownerId: clanSecret,
                );
                if (!needQuantity) return null;
                final cur = await _cloud?.read(
                    "workers", "clans_items/$clanId/items", _playerWalletId(userId),
                    ownerId: clanSecret, region: region,
                );
                // Document tout juste créé : `quantity` est absente et vaut 0 (une bourse est un
                // contenant, cf. _pushClanItems). Doc introuvable = anomalie → null, on ne migre pas.
                if (cur == null) return null;
                return int.tryParse(cur.get("quantity")?.toString() ?? "0") ?? 0;
            } catch (e) {
                deva_log("error", "[items] _ensurePlayerWallet FAILED: $e");
                return null;
            }
    }

    //-----------------------------------------------------------------------
    //-- Invitation clan ---------------------------------------------------
    //-----------------------------------------------------------------------

    // --- Overlay de consentement du chef au recrutement (écran clan_page) ---------------------
    // Widgets posés en layer:overlay, invisibles par défaut — même idiome que l'overlay
    // « Créer un clan » (_setCreateConfirmVisible), jamais de fenêtre modale.
    void _setInviteConsentVisible(bool v) {

                                for (final id in const [
                                    "clan_page/invite_scrim",
                                    "clan_page/invite_panel",
                                    "clan_page/invite_yes",
                                    "clan_page/invite_no",
                                ]) {
                                    final s = DvOrb.get_shape_by_id(id);
                                    s?.set("shape.visible", v);
                                    s?.refreshUI();
                                }
    }

    // Recruter est réservé au chef (double garde : clan_settings_selector cache déjà l'option).
    //
    // Le lobby n'est PAS créé ici : recruter, c'est potentiellement faire entrer un enfant dans
    // son clan, et la mention de responsabilité légale doit être sous les yeux du chef AVANT
    // l'acte (RGPD art. 8), pas seulement dans les CGU acceptées à l'installation. On révèle donc
    // l'overlay de consentement ; on_confirm_invite_consent enchaîne sur create_management.
    // Les gardes (clanId en session, statut de chef) restent AVANT l'overlay : on ne demande pas
    // au chef d'assumer une responsabilité pour échouer juste après.
    Future<void> on_invite_clan(DvShape? caller, dynamic event) async {

                                if ((await _clanIdIfChief("on_invite_clan")).isEmpty) return;
                                await deva_set("worker.pending_invite_kind", "qr");
                                _setInviteConsentVisible(true);
    }

    // Contrôles communs aux deux modes de recrutement (QR et invitation à distance) : le clan doit
    // être connu de la session et l'appelant doit en être chef. Rend le clanId, ou "" si refusé.
    Future<String> _clanIdIfChief(String who) async {

                                final region  = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session = region.isNotEmpty ? await _readSession(region) : null;
                                final groupId = session?.get("steps.clan.clanId")?.toString() ?? "";
                                if (groupId.isEmpty) {
                                    deva_log("error", "[worker] $who: clanId introuvable dans la session");
                                    return "";
                                }
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (!await _ensureIsAdmin(groupId, clanSecret, region)) {
                                    deva_log("warning", "[worker] $who: refusé (non admin)");
                                    return "";
                                }
                                // Plafond de joueurs du palier souscrit. On refuse ici, AVANT de
                                // demander au chef d'assumer la responsabilité légale du recrutement
                                // (et avant de créer un lobby) : lui faire lire la mention pour échouer
                                // juste après serait pénible et inutile.
                                //
                                // Le contrôle est désormais EXACT à ce stade, alors qu'il ne pouvait
                                // pas l'être du temps des deux plafonds : il ne dépend plus de la
                                // nature du candidat, dont le `legal_state` n'existe pas encore. Un
                                // clan plein est plein, quel que soit celui qui frappe à la porte.
                                if (await _storeRefuseMember()) {
                                    deva_log("info", "[worker] $who: refusé (clan au complet)");
                                    return "";
                                }
                                return groupId;
    }

    // Le chef a lu la mention et confirmé sa responsabilité : on crée enfin le lobby. Le mode
    // mémorisé décide de la suite — invite_mode=pin fait bifurquer on_management_created vers
    // l'écran PIN + partage au lieu du QR.
    Future<void> on_confirm_invite_consent(DvShape? caller, dynamic event) async {

                                _setInviteConsentVisible(false);
                                final kind = (await deva_get("worker.pending_invite_kind"))?.toString() ?? "qr";
                                await deva_set("worker.pending_invite_kind", "");
                                // Le clan est relu ici et pas conservé depuis la garde : entre le tap sur
                                // l'option et la confirmation, rien ne garantit que la session n'a pas bougé.
                                final groupId = await _clanIdIfChief("on_confirm_invite_consent");
                                if (groupId.isEmpty) return;
                                if (kind == "pin") await deva_set("worker.invite_mode", "pin");
                                await _stampFirstInvite(groupId);
                                ActionRegistry.get("virtuallobby.create_management")?.call(null, {"group_id": groupId});
    }

    \ Horodate la PREMIÈRE invitation ouverte par le clan (`clans.first_invite_at`, écrit une seule
    // fois). Sert au balayage serveur (pulse_sweeper) à distinguer deux clans d'un seul membre qui
    // n'ont rien à voir : celui dont le chef a essayé d'inviter et n'y est pas arrivé, et celui qui
    // joue seul délibérément — un clan de 1 à 2 joueurs, c'est ~40 % des clans, le palier le plus
    // souscrit. « Un seul membre » ne discrimine donc rien ; « n'a jamais ouvert d'invitation », si.
    //
    // Posé ici, au consentement confirmé, et non à l'admission : ce qu'on mesure est la TENTATIVE.
    // Best-effort — un compteur d'analyse ne fait jamais échouer un recrutement.
    Future<void> _stampFirstInvite(String clanId) async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = region.isNotEmpty ? await _readSession(region) : null;
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || region.isEmpty) return;

                                    final doc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    // Écrit UNE SEULE FOIS : c'est la date de la première tentative qui
                                    // renseigne, pas celle de la dernière.
                                    if ((doc?.get("first_invite_at")?.toString() ?? "").isNotEmpty) return;

                                    final out = Dvidle({});
                                    out.set("first_invite_at", DateTime.now().toUtc().toIso8601String());
                                    await _cloud?.write("workers", "clans", clanId, out,
                                        region: region, ownerId: clanSecret);
                                    deva_log("info", "[clan] first_invite_at posé sur $clanId");
                                } catch (e) {
                                    deva_log("error", "[clan] _stampFirstInvite FAILED: $e");
                                }
    }

    Future<void> on_cancel_invite_consent(DvShape? caller, dynamic event) async {

                                await deva_set("worker.pending_invite_kind", "");
                                _setInviteConsentVisible(false);
    }

    // Invitation à distance : même chemin que le QR (consentement puis create_management), mais le
    // flag invite_mode=pin — posé par on_confirm_invite_consent — fait bifurquer
    // on_management_created vers l'écran PIN + partage réseaux sociaux au lieu du QR.
    // Réservé au chef, comme le QR (double garde avec clan_settings_selector).
    Future<void> on_invite_clan_remote(DvShape? caller, dynamic event) async {

                                if ((await _clanIdIfChief("on_invite_clan_remote")).isEmpty) return;
                                await deva_set("worker.pending_invite_kind", "pin");
                                _setInviteConsentVisible(true);
    }

    Future<void> on_management_created(DvShape? caller, Map event) async {

                                final groupId = event["group_id"]?.toString() ?? "";
                                final lobbyId = event["lobby_id"]?.toString() ?? "";
                                if (groupId.isEmpty || lobbyId.isEmpty) return;

                                deva_log("info", "[worker] on_management_created: groupId=$groupId lobbyId=$lobbyId");

                                await deva_set("worker.pending_group_id", groupId);
                                await deva_set("worker.pending_lobby_id",  lobbyId);

                                // La région voyage avec l'invitation : le clan n'existe que dans la sienne,
                                // et celui qui la reçoit doit pouvoir le savoir avant de tenter d'entrer.
                                // Posée dans le store pour le texte de partage (screens_meta : share_clan_invite).
                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                await deva_set("worker.pending_region", region);

                                ActionRegistry.get("virtuallobby.watch_management")?.call(null, {"group_id": groupId, "lobby_id": lobbyId});
                                deva_log("info", "[worker] watch_management démarré");

                                // Mode « à distance » : sceau chiffré par PIN, écran PIN + partage (pas de QR).
                                final mode = (await deva_get("worker.invite_mode"))?.toString() ?? "";
                                if (mode == "pin") {
                                    await deva_set("worker.invite_mode", "");
                                    final lobby = ModuleRegistry.create("dvvirtuallobby");
                                    if (lobby == null) return;
                                    final pin   = (lobby as dynamic).generatePin() as String? ?? "";
                                    final token = (lobby as dynamic).sealInvite(
                                        {"group_id": groupId, "lobby_id": lobbyId, "region": region}, pin) as String? ?? "";
                                    await deva_set("worker.pending_invite_token", token);

                                    DvOrb.navigate_new("invite_clan_pin");
                                    final pinShape = await DvOrb.wait_for_shape("invite_clan_pin/pin");
                                    pinShape
                                        ?..set("shape.label", pin)
                                        ..refreshUI();
                                    return;
                                }

                                DvOrb.navigate_new("invite_clan");

                                final link       = "ddust://invite?group_id=$groupId&lobby_id=$lobbyId&region=$region";
                                final qrcodeShape = await DvOrb.wait_for_shape("invite_clan/qrcode");
                                qrcodeShape
                                    ?..set("shape.content", link)
                                    ..refreshUI();
    }

    Future<void> on_invite_clan_link(DvShape? caller, Map event) async {

                                final groupId = event["group_id"]?.toString() ?? "";
                                final lobbyId = event["lobby_id"]?.toString() ?? "";
                                if (groupId.isEmpty || lobbyId.isEmpty) return;

                                // Point de contrôle unique de la région, pour le QR comme pour le deeplink.
                                // Placé AVANT les deva_set : une invitation d'une autre région ne doit pas
                                // être mise en attente, sinon on_login la rejouerait au prochain démarrage.
                                // En cold start la session n'a pas encore de région et le contrôle laisse
                                // passer ; l'invitation sera rejouée une fois la région connue.
                                if (await _inviteRegionMismatch(
                                        event["region"]?.toString() ?? "", "kid_wants_clan/region_error")) return;

                                // Stocké inconditionnellement — on_login le consomme en cold start.
                                await deva_set("worker.pending_group_id", groupId);
                                await deva_set("worker.pending_lobby_id",  lobbyId);

                                // Warm start : utilisateur déjà connecté → acceptation directe + navigation via dvsteps.
                                if (_cloud?.isReady() ?? false) {
                                    ActionRegistry.get("virtuallobby.accept_invitation")?.call(null, {
                                        "group_id": groupId,
                                        "lobby_id": lobbyId,
                                    });
                                    // Consommé : sans ce reset, un redémarrage à froid ultérieur rejoue
                                    // l'acceptation d'une adhésion déjà finalisée.
                                    await deva_set("worker.pending_group_id", "");
                                    await deva_set("worker.pending_lobby_id", "");
                                    ActionRegistry.get("steps.navigate")?.call(caller, null);
                                }
    }

    // « Je n'ai pas le QR code » : saisie manuelle (coller le lien reçu + taper le PIN).
    Future<void> on_no_qr(DvShape? caller, dynamic event) async {

                                await deva_set("worker.pending_invite_token_in", "");
                                DvOrb.navigate_new("enter_invite_pin");
    }

    // Deeplink ddust://invitepin?token=… : token chiffré reçu sur les réseaux sociaux.
    Future<void> on_invite_pin_link(DvShape? caller, Map event) async {

                                final token = event["token"]?.toString() ?? "";
                                if (token.isEmpty) return;

                                // Stocké inconditionnellement — on_login le consomme en cold start.
                                await deva_set("worker.pending_invite_token_in", token);

                                // Warm start : déjà connecté → écran de saisie du PIN, token pré-rempli.
                                if (_cloud?.isReady() ?? false) {
                                    DvOrb.navigate_new("enter_invite_pin");
                                    final tokenShape = await DvOrb.wait_for_shape("enter_invite_pin/token");
                                    tokenShape
                                        ?..set("shape.value", token)
                                        ..refreshUI();
                                }
    }

    // Validation du PIN : déchiffre le token via dvvirtuallobby.openInvite, puis rejoint le clan
    // par le chemin d'acceptation habituel (identique au flux QR).
    Future<void> on_confirm_pin(DvShape? caller, dynamic event) async {

                                final errShape = DvOrb.get_shape_by_id("enter_invite_pin/error");

                                // Token : champ de saisie prioritaire (collé), sinon deeplink stocké.
                                String tokenRaw = DvOrb.get_shape_by_id("enter_invite_pin/token")?.get("shape.value")?.toString().trim() ?? "";
                                if (tokenRaw.isEmpty) {
                                    tokenRaw = (await deva_get("worker.pending_invite_token_in"))?.toString() ?? "";
                                }
                                // Le champ peut contenir le token brut OU l'URL complète ddust://invitepin?token=…
                                String token = tokenRaw;
                                final uri = Uri.tryParse(tokenRaw);
                                final uriToken = uri?.queryParameters["token"];
                                if (uriToken != null && uriToken.isNotEmpty) token = uriToken;

                                final pin = DvOrb.get_shape_by_id("enter_invite_pin/pin")?.get("shape.value")?.toString().trim() ?? "";

                                if (token.isEmpty || pin.isEmpty) {
                                    errShape?..set("shape.visible", true)..refreshUI();
                                    return;
                                }

                                final lobby = ModuleRegistry.create("dvvirtuallobby");
                                if (lobby == null) return;
                                final payload = (lobby as dynamic).openInvite(token, pin) as Map?;
                                final groupId = payload?["group_id"]?.toString() ?? "";
                                final lobbyId = payload?["lobby_id"]?.toString() ?? "";
                                if (groupId.isEmpty || lobbyId.isEmpty) {
                                    deva_log("info", "[worker] on_confirm_pin: PIN incorrect ou lien expiré");
                                    errShape
                                        ?..set("shape.label", TranslationRegistry.processLabel("@@@T:pin_wrong@@@"))
                                        ..set("shape.visible", true)
                                        ..refreshUI();
                                    return;
                                }

                                // Le PIN était bon : le lien est authentique, mais il peut venir d'une autre
                                // région. Le message remplace alors « PIN incorrect », qui serait trompeur.
                                if (await _inviteRegionMismatch(
                                        payload?["region"]?.toString() ?? "", "enter_invite_pin/error")) return;

                                errShape?..set("shape.visible", false)..refreshUI();
                                await deva_set("worker.pending_invite_token_in", "");

                                // Suite strictement identique au flux QR : acceptation + navigation.
                                await deva_set("worker.pending_group_id", groupId);
                                await deva_set("worker.pending_lobby_id",  lobbyId);
                                ActionRegistry.get("virtuallobby.accept_invitation")?.call(null, {
                                    "group_id": groupId,
                                    "lobby_id": lobbyId,
                                });
                                // Consommé : sans ce reset, un redémarrage à froid ultérieur rejoue
                                // l'acceptation d'une adhésion déjà finalisée.
                                await deva_set("worker.pending_group_id", "");
                                await deva_set("worker.pending_lobby_id", "");
                                ActionRegistry.get("steps.navigate")?.call(caller, null);
    }

    // Garantit que les infos du clan sont connues AVANT de jouer la bienvenue / afficher le dashboard :
    // absorbe la course de propagation (doc clan pas encore écrit en Firestore ou pas encore chargé).
    // Boucle bornée : (ré)hydrate les tâches via _loadClanTasks tant que clan_done n'est pas posé, et
    // relit le doc clan pour renseigner session.clan.name s'il est encore vide. Appelée sous freeze (ring).
    Future<void> _ensureClanReady(String region) async {

                                if (region.isEmpty) return;
                                for (var attempt = 0; attempt < 5; attempt++) {
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";

                                    final done = (await deva_get("worker.session.clan_done"))?.toString() == "true";
                                    if (!done && session != null && clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        await _loadClanTasks(session, region);
                                        await Deva.instance.set("worker.session.clan_done", "true");
                                    }

                                    var name = (await Deva.instance.get("session.clan.name"))?.toString() ?? "";
                                    if (name.isEmpty && clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        try {
                                            final clan = await _cloud?.read(
                                                "workers", "clans", clanId, ownerId: clanSecret, region: region);
                                            name = clan?.get("internal.name")?.toString() ?? "";
                                            if (name.isNotEmpty) await Deva.instance.set("session.clan.name", name);
                                        } catch (_) {}
                                    }

                                    if (name.isNotEmpty && (await deva_get("worker.session.clan_done"))?.toString() == "true") {
                                        return;   // clan prêt : nom connu + tâches hydratées
                                    }
                                    await Future.delayed(const Duration(milliseconds: 300));
                                }
    }

    Future<void> on_accept_invitation_clan(DvShape? caller, dynamic event) async {

                                final groupId = (await deva_get("worker.pending_group_id"))?.toString() ?? "";
                                final lobbyId = (await deva_get("worker.pending_lobby_id"))?.toString()  ?? "";
                                if (groupId.isEmpty || lobbyId.isEmpty) return;

                                // Consommé : sans ce reset, un redémarrage à froid ultérieur rejoue
                                // l'acceptation d'une adhésion déjà finalisée.
                                await deva_set("worker.pending_group_id", "");
                                await deva_set("worker.pending_lobby_id", "");
                                ActionRegistry.get("virtuallobby.accept_invitation")?.call(null, {
                                    "group_id": groupId,
                                    "lobby_id": lobbyId,
                                });
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
