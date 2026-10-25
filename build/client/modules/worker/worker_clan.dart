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

                                ActionRegistry.register("worker.on_create_clan_complete",    on_create_clan_complete);

                                ActionRegistry.register("worker.on_decisiontree_complete",    on_decisiontree_complete);

                                // Pas `decisiontree` : le fondateur passe par le choix du thème du clan.
                                ActionRegistry.register("worker.decisiontree_route",          decisiontree_route);

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

                                // Sortie « un autre parent a déjà créé le clan » → rejoindre (anti-doublon).
                                ActionRegistry.register("worker.on_create_clan_goto_join",    on_create_clan_goto_join);

                                // L'enfant parle d'abord : SA question (kid_assent_screen), puis l'écran qui
                                // montre patte blanche (join_show_screen, worker_join.dart).
                                ActionRegistry.register("worker.on_kid_assent_appear",         on_kid_assent_appear);
                                ActionRegistry.register("worker.kid_assent_route",             kid_assent_route);

                                // L'enfant jouait déjà sur le téléphone du parent : quel joueur reprend-il ?
                                ActionRegistry.register("worker.on_claim_pick_appear",         on_claim_pick_appear);
                                ActionRegistry.register("worker.on_claim_pick",                on_claim_pick);

                                // Message d'une adhésion qui n'a pas abouti, côté adulte.
                                ActionRegistry.register("worker.on_new_or_pick_clan_appear", on_new_or_pick_clan_appear);

                                // Menus du clan : les gestes de base, et les options avancées.
                                ActionRegistry.register("worker.clan_settings_selector",    clan_settings_selector);
                                ActionRegistry.register("worker.clan_advanced_selector",    clan_advanced_selector);
                                ActionRegistry.register("worker.open_clan_advanced",        open_clan_advanced);

                                ActionRegistry.register("worker.clan_ai_off",               clan_ai_off);

                                ActionRegistry.register("worker.clan_ai_on",                clan_ai_on);

    }

    Future<String> on_create_clan_complete(DvShape? caller, dynamic event) async {

                                final region       = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                final data         = event is Map ? event as Map : <String, dynamic>{};
                                final internalName = data["internal_name"]?.toString() ?? "";
                                final description  = data["description"]?.toString()   ?? "";
                                // Identité externe déjà résolue par l'appelant (on_confirm_create_clan).
                                // Repli de sécurité si ce flux est appelé de plus loin : la banque, JAMAIS
                                // le nom interne — c'était précisément le défaut d'origine.
                                _AiDraft ext = _AiDraft()
                                    ..extName = data["ext_name"]?.toString()   ?? ""
                                    ..extDesc = data["ext_desc"]?.toString()   ?? ""
                                    ..source  = data["ext_source"]?.toString() ?? "";
                                if (ext.extName.isEmpty) ext = _bankSubstitute("clan");

                                int count = 0;
                                try {
                                    final r = await _cloud?.call("count_sessions", Dvidle({}));
                                    count = int.tryParse(r?.get("count")?.toString() ?? "0") ?? 0;
                                } catch (_) {}

                                final regionCode   = region.isNotEmpty ? region : "eu";
                                // Le nom externe reste suffixé « -region-compteur » : c'est lui qui porte
                                // l'unicité inter-clans. Seule sa BASE change — un nom de substitution, et
                                // plus jamais le nom que la famille s'est donné.
                                final externalName = "${ext.extName}-$regionCode-$count";

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
                                        clanDoc.set("internal.name",        internalName);
                                        clanDoc.set("internal.description", description);
                                        clanDoc.set("external.name",        externalName);
                                        clanDoc.set("external.description", ext.extDesc);
                                        clanDoc.set("external.source",      ext.source);
                                        clanDoc.set("external.date",        now);
                                        // MIROIR HISTORIQUE de internal.description. Les binaires déjà
                                        // installés lisent ce champ plat (conteur du butin) : on l'écrit en
                                        // double le temps d'une release, puis il pourra disparaître.
                                        clanDoc.set("description",          description);
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
                                        // Version des données (dvautover) : un clan qui naît est au format de
                                        // l'application qui le crée. Les règles Firestore ne laissent poser ce
                                        // champ qu'ici (création) ou s'il est absent ; ensuite, seule la fonction
                                        // de mise à jour du clan l'écrit.
                                        clanDoc.set("data_version",    await _appBuild());
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

    // Routeur du pas `decisiontree` (steps.yml), tiré par l'interlude passage_quete une fois les
    // tâches enregistrées. Le FONDATEUR d'un clan tout juste créé va choisir l'ambiance de son
    // clan (route `theme` → theme_pick_page) ; tous les autres (joueur renvoyé à la quête après
    // un départ ou une éjection) vont droit au dashboard, comme avant (`default`).
    // Le signe du fondateur : la bienvenue « created » encore armée, posée par
    // on_create_clan_complete et consommée seulement à l'arrivée sur le dashboard.
    Future<String> decisiontree_route(dynamic caller, dynamic event) async {

                                final pending = (await deva_get("worker.pending_clan_welcome"))?.toString() ?? "";
                                return pending == "created" ? "theme" : "default";
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


    // ⚠ `dynamic caller` ET NON `DvShape?` : l'`appear` d'une PAGE passe la page
    //   elle-même, et une page est un DvView, pas un DvShape. Typer le paramètre
    //   `DvShape?` faisait lever un `type 'DvPage' is not a subtype of 'DvShape?'` que
    //   DvView attrape et journalise — l'écran naissait donc inerte, en silence.
    Future<void> on_create_clan_appear(dynamic caller, dynamic event) async {

                                _resetAiDraft();
                                final nameEntry = await DvOrb.wait_for_shape("create_clan/name");
                                final descEntry = DvOrb.get_shape_by_id("create_clan/desc");
                                final replay    = DvOrb.get_shape_by_id("create_clan/replay");
                                final confirm   = DvOrb.get_shape_by_id("create_clan/confirm");
                                nameEntry?.set("shape.value", ""); nameEntry?.refreshUI();
                                descEntry?.set("shape.value", ""); descEntry?.refreshUI();
                                replay?.set("shape.visible", false); replay?.refreshUI();
                                confirm?.set("shape.opacity", _confirmOpacity(confirm, false));
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

    // « Quelqu'un l'a déjà créé : je le rejoins. » LE garde-fou du clan en double, et il
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
                                // → join_show_screen), pour ne pas dupliquer la navigation d'onboarding.
                                final r = ActionRegistry.get("steps.navigate.join")?.call(caller, event);
                                if (r is Future) await r;
    }

    Future<void> on_confirm_create_clan_choice(DvShape? caller, dynamic event) async {

                                _setCreateConfirmVisible(false);
                                // Rejoue la navigation d'origine du bouton créer (step new_or_pick_clan, route create → create_clan).
                                final r = ActionRegistry.get("steps.navigate.create")?.call(caller, event);
                                if (r is Future) await r;
    }

    Future<void> on_create_clan_name_changed(DvShape caller, dynamic event) async {

                                final value   = caller.get("shape.value")?.toString() ?? "";
                                _originalName = value.trim();
                                final confirm = DvOrb.get_shape_by_id("create_clan/confirm");
                                final enabled = value.trim().isNotEmpty;
                                confirm?.set("shape.opacity", _confirmOpacity(confirm, enabled));
                                confirm?.set("shape.events.tap", enabled);
                                confirm?.refreshUI();
    }

    Future<void> on_create_clan_desc_changed(DvShape caller, dynamic event) async {

                                _originalDesc = caller.get("shape.value")?.toString().trim() ?? "";
    }

    Future<void> on_inspire_clan(DvShape? caller, dynamic event) async =>
        _runInspire("create_clan", "inspire_clan", "inspire_fallback_", kind: "clan");

    Future<void> on_replay_clan(DvShape? caller, dynamic event) async =>
        _runReplay("create_clan", "inspire_clan", "inspire_fallback_", kind: "clan");

    Future<String> on_confirm_create_clan(DvShape? caller, dynamic event) async {

                                final nameEntry = DvOrb.get_shape_by_id("create_clan/name");
                                final descEntry = DvOrb.get_shape_by_id("create_clan/desc");
                                final name      = nameEntry?.get("shape.value")?.toString().trim() ?? "";
                                if (name.isEmpty) return "cancel";
                                final desc = descEntry?.get("shape.value")?.toString().trim() ?? "";
                                // Identité externe résolue ICI, avant la moindre écriture : soit le
                                // brouillon d'« Inspire moi » la portait déjà (aucun appel de plus), soit
                                // un appel de substitution la produit, soit la banque locale la fournit.
                                // Elle ne peut, dans aucun de ces cas, valoir le nom interne.
                                final ext = await _resolveExternal("clan", name, desc);
                                return await on_create_clan_complete(null, {
                                    "internal_name": name,
                                    "description":   desc,
                                    "ext_name":      ext.extName,
                                    "ext_desc":      ext.extDesc,
                                    "ext_source":    ext.source,
                                });
    }

    // Rôles de l'utilisateur dans le clan courant, relus à chaque ouverture d'un des deux menus
    // du clan (de base, « Options avancées »). Lecture KO → tout à false : repli sûr, les options
    // de chef et d'adulte restent cachées.
    Future<({bool admin, bool adult, bool canDeclare})> _clanMenuRoles() async {

                                var isAdmin = false;
                                var isAdult = false;
                                var canDeclare = false;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    isAdmin = await _ensureIsAdmin(clanId, clanSecret, region);
                                    isAdult = await _ensureIsAdult(clanId, clanSecret, region);
                                    if (isAdmin && isAdult) canDeclare = await _referralCanDeclare(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[clan] rôles du menu clan illisibles : $e");
                                }
                                return (admin: isAdmin, adult: isAdult, canDeclare: canDeclare);
    }

    // Selector du menu d'en-tête du clan : LES GESTES DE BASE. Ordre :
    //   1. « Accueillir un joueur », chef : le candidat, adulte ou enfant, montre son QR code
    //      (ou dicte son code) et le chef le scanne. Une seule porte depuis le 2026-10-18 ;
    //   2. « Créer un joueur sans téléphone », chef ;
    //   3. le journal et les tutoriels, pour tous ;
    //   4. « Options avancées… », seulement si ce second menu a quelque chose à montrer.
    //
    // « Mes achats » n'est plus ici : tout ce qui touche à l'argent vit sur la page
    // d'entrée de la boutique (tuiles dvshop : code cadeau, abonnement).
    // (« Mes clans » non plus : c'est le bouton aux deux flèches de l'écran, clan_page/switch.)
    Future<List<String>> clan_settings_selector(dynamic caller, dynamic data) async {

                                final r = await _clanMenuRoles();
                                final options = <String>[];
                                if (r.admin) options.addAll(["welcome", "create_player"]);
                                options.addAll(["clan_log", "tutorials"]);
                                if ((await _clanAdvancedOptions(r)).isNotEmpty) options.add("advanced");
                                return options;
    }

    Future<List<String>> clan_advanced_selector(dynamic caller, dynamic data) async =>
                                _clanAdvancedOptions(await _clanMenuRoles());

    // Les options avancées, mêmes gardes qu'avant la refonte.
    Future<List<String>> _clanAdvancedOptions(({bool admin, bool adult, bool canDeclare}) r) async {

                                final options = <String>[];
                                // MULTICLAN : pour tout adulte, les clans des enfants qu'il représente
                                // (demandes d'autres clans, co-représentants, retraits).
                                if (r.adult) options.add("guardian_hub");
                                // L'IA du clan : UNE des deux options, selon l'état relu à frais.
                                if (r.admin) options.add(await _iaDuClan() ? "clan_ai_off" : "clan_ai_on");
                                // PARRAINAGE : chef ADULTE seulement. « J'ai un parrain » disparaît une fois
                                // un parrain déclaré ou le clan abonné.
                                if (r.admin && r.adult) {
                                    options.add("referral");
                                    if (r.canDeclare) options.add("referral_declare");
                                }
                                // « Noter et partager » TOUT EN BAS, pour tout adulte (chef ou non).
                                if (r.adult) options.add("rate_share");
                                return options;
    }

    // Ouvre un second menu du clan AU MÊME ENDROIT que le menu de base, que DvMenu vient de
    // refermer (même motif que le choix de la langue, worker.open_lang_menu).
    Future<void> _openClanSubMenu(String menuId) async {

                                final base = DvOrb.get_shape_by_id("clan_page/settings_menu");
                                final anchor = (base is DvMenu && base.lastShowPosition != null)
                                    ? base.lastShowPosition!
                                    : const Offset(100, 100);
                                // Par le kebab (DvMenuButton.openSubMenu) : il passe les icônes du
                                // sous-menu, sans quoi celui-ci sortait sans icônes, texte centré.
                                final btn = DvOrb.get_shape_by_id("clan_page/settings");
                                if (btn is DvMenuButton) {
                                    btn.openSubMenu(menuId, anchor);
                                } else {
                                    DvOrb.get_shape_by_id(menuId)?.act("show", {"x": anchor.dx, "y": anchor.dy});
                                }
    }

    Future<void> open_clan_advanced(dynamic caller, dynamic event) async =>
                                _openClanSubMenu("clan_page/advanced_menu");

    // Couper / rallumer l'IA pour TOUT le clan (champ `ai_enabled` du doc `clans`).
    //
    // POURQUOI. Quand les coûts d'inférence débordent, le chef coupe l'IA : « Inspire moi »
    // sert alors des propositions toutes faites (masqué sur une tâche), et le conte du butin
    // laisse place au journal brut. Chaque joueur relit le champ à chaque usage (_iaDuClan) :
    // le réglage vaut pour tous dès l'écriture, sans relancer l'app.
    //
    // Réservé au chef (clan_settings_selector filtre, _ensureIsAdmin est la ceinture).
    // ⚠ CE N'EST QU'UNE GARDE DE L'APPLICATION : les règles de `clans` laissent tout membre
    //   écrire le document, comme pour le titre et l'avatar du clan.
    // Réversible d'un tap, donc aucune confirmation (même doctrine que hors_concours_*).
    // Read-modify-write du document complet, comme title_apply_clan.
    Future<void> _setClanAi(bool enabled) async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;
                                    if (!await _ensureIsAdmin(clanId, clanSecret, region)) {
                                        deva_log("warning", "[clan] ai_enabled=$enabled REFUSÉ : non-chef");
                                        return;
                                    }
                                    final clan = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    clan.rem("docId");
                                    clan.set("ai_enabled", enabled);
                                    await _cloud?.write("workers", "clans", clanId, clan,
                                        region: region, ownerId: clanSecret);
                                    _iaClanCoupee = !enabled;
                                    await _publishRole("worker.clan_ai_enabled", enabled);
                                    deva_log("info", "[clan] IA ${enabled ? "rallumée" : "coupée"} pour le clan");
                                } catch (e) {
                                    deva_log("error", "[clan] _setClanAi($enabled) FAILED: $e");
                                }
    }

    Future<void> clan_ai_off(dynamic caller, dynamic event) async { await _setClanAi(false); }
    Future<void> clan_ai_on (dynamic caller, dynamic event) async { await _setClanAi(true);  }

    //-----------------------------------------------------------------------
    //-- Join clan (candidat) ---------------------------------------------
    //-----------------------------------------------------------------------

    // Un clan vit dans UNE SEULE base : ses données sont dans celle de son datacenter et
    // rien ne traverse. Une invitation émise ailleurs ne mènerait donc qu'à un « clan
    // introuvable » silencieux — autant le dire franchement.
    //
    // ⚠ LA COMPARAISON PORTE SUR LE DATACENTER (cloud_region), PAS SUR LE ROYAUME.
    //   La question posée n'est pas « avons-nous le même droit ? » mais « nos données
    //   sont-elles dans la même base ? ». Un joueur du royaume de France et un joueur
    //   des royaumes d'Europe lisent des conditions générales différentes et vivent
    //   pourtant tous deux dans `eu` : ils doivent pouvoir jouer ensemble. Comparer
    //   les royaumes les séparerait sans aucune raison technique.
    //
    // Une invitation sans région (lien émis avant l'ouverture de la seconde région) passe :
    // il n'y avait alors qu'une région, la comparaison n'a pas de sens.
    // Retourne true si l'invitation doit être refusée (le message est déjà affiché).
    Future<bool> _inviteRegionMismatch(String inviteRegion, String errorShapeId) async {

                                if (inviteRegion.isEmpty) return false;

                                final mine = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
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

    //-----------------------------------------------------------------------
    //-- L'enfant parle d'abord (kid_assent_screen → join_show_screen) -------
    //-----------------------------------------------------------------------
    //
    // ⚠ L'ORDRE EST LA RÈGLE, et il vient du droit. Le décret colombien 1377 de 2013 (art. 12)
    //   veut que l'enfant exprime sa volonté AVANT la décision de son représentant ; le RGPD
    //   (art. 8) qu'aucune de ses données ne soit enregistrée avant l'autorisation de ce
    //   représentant. D'où ce parcours : l'enfant répond, puis MONTRE son QR code (ou dicte son
    //   code) ; le parent le scanne, voit ce que l'enfant a dit et décide ; c'est seulement alors
    //   que l'enfant se connecte et que quoi que ce soit s'écrit à son nom (worker_join.dart).
    //
    // ⚠ RIEN N'EST ÉCRIT DE CE CÔTÉ SUR LE DISQUE. Avant le login, le dictionnaire deva vit dans
    //   la couche `prelogin`, en mémoire, comme l'accord (_joinAssent) : un enfant qui ferme
    //   l'application ne laisse aucune trace, et repart du tout premier écran.

    // L'écran d'avis pose UNE question, toujours la même : « as-tu envie de jouer ? ».
    // Déjà connecté (enfant qui demande un autre clan, ou mineur sans clan après un refus) : la
    // flèche mènerait aux conditions, acceptées depuis longtemps. Un enfant déjà membre d'un clan
    // y gagne le retour à son clan (route `my_clan`) ; sinon elle disparaît.
    // ⚠ `dynamic caller` : l'appear d'une PAGE passe un DvPage, qui n'est pas une shape.
    Future<void> on_kid_assent_appear(dynamic caller, dynamic event) async {

                                await DvOrb.wait_for_shape("kid_assent/question");
                                if (_anon) return;
                                final region = await _homeRegion();
                                Dvidle? session;
                                try { session = region.isNotEmpty ? await _readSession(region) : null; } catch (_) {}
                                if (_activeClans(session).isEmpty) {
                                    _hideShapes(["kid_assent/back"]);
                                    return;
                                }
                                final back = DvOrb.get_shape_by_id("kid_assent/back");
                                back?.set("shape.label", TranslationRegistry.translate("back_to_my_clan"));
                                if (back is DvLabel) await back.computeDisplay();
                                back?..set("shape.visible", true)..refreshUI();
    }

    // Routeur du pas kid_assent_screen (steps.yml). Reçoit la route demandée par le bouton
    // (`go` par l'interlude passage_assent, `back` par la flèche) :
    //   * `back`    : retour aux conditions, ou à son clan pour un enfant déjà connecté ;
    //   * `go`      : l'écran qui montre patte blanche (join_show_screen).
    // L'accord naît ICI, au moment exact du oui : c'est ce moment-là que sa date doit dire, pas
    // celui où l'écran suivant se réaffiche. Un nouveau oui, c'est un nouvel accord.
    Future<String> kid_assent_route(DvShape? caller, dynamic event) async {

                                if (event?.toString() == "back") return _anon ? "back" : "my_clan";
                                _joinAssent = await _buildJoinAssent();
                                return "go";
    }

    // L'ENFANT JOUAIT DÉJÀ SUR LE TÉLÉPHONE D'UN PARENT (joueur sans compte, no_account, créé par
    // « Créer un joueur »). Il reçoit son propre téléphone : il doit retrouver CE joueur (XP,
    // butin, journal, avatar), pas en créer un second. La question est posée au PARENT, jamais à
    // l'enfant : c'est lui qui sait, et c'est lui seul qui désigne le joueur. Un enfant ne peut
    // pas dire « je suis Léo » ; le choix voyage avec la déclaration du chef, dans le dépôt scellé
    // de la boîte d'adhésion (claim), jusqu'à _handleClanJoin.
    //
    // Posée seulement s'il y a de quoi choisir : un clan sans joueur sans téléphone va droit à
    // la déclaration. Le chemin adulte n'est pas concerné : un joueur sans compte est un enfant.
    Future<void> _openClaimOrConsent() async {

                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _claimRows        = _pendingAssent == null ? [] : await _claimCandidates();
                                if (_claimRows.isEmpty) {
                                    await _openInviteConsent();
                                    return;
                                }
                                DvOrb.navigate_new("claim_pick_page");
    }

    // Les joueurs sans téléphone du clan, encore actifs : sans compte, pas révoqués, pas en cours
    // de retrait du consentement (leur document est gelé, cf. _writeClanPlayer).
    Future<List<Map<String, dynamic>>> _claimCandidates() async {

                                final rows = <Map<String, dynamic>>[];
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = region.isNotEmpty ? await _readSession(region) : null;
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return rows;
                                    final players = await _cloud?.list("workers", "clans_players/$clanId/players",
                                        region: region) ?? [];
                                    for (final p in players) {
                                        final pid = p.get("id")?.toString() ?? "";
                                        if (pid.isEmpty || p.get("no_account") != true) continue;
                                        if (p.get("enabled") == false) continue;
                                        if ((p.get("consent_due")?.toString() ?? "").isNotEmpty) continue;
                                        final avatar = p.get("avatar")?.toString() ?? "";
                                        rows.add({
                                            "id":    pid,
                                            "label": _memberLabel(p.get("name")?.toString() ?? ""),
                                            "image": avatar.isNotEmpty ? avatar : "images/medium/nope.png",
                                        });
                                    }
                                    rows.sort((a, b) => a["label"].toString()
                                        .toLowerCase().compareTo(b["label"].toString().toLowerCase()));
                                } catch (e) {
                                    deva_log("error", "[worker] _claimCandidates FAILED: $e");
                                }
                                return rows;
    }

    // Une ligne par joueur sans téléphone, puis « C'est un nouveau joueur » en dernier : le cas
    // courant reste à un tap, et le parent ne peut pas passer la question sans y répondre.
    Future<void> on_claim_pick_appear(dynamic caller, dynamic event) async {

                                // L'écran est là : le quitter par la flèche rend la boîte au candidat
                                // (on_claim_pick_quit), un choix fait mène à la déclaration.
                                _welcomeAdvancing = false;
                                final rows = <Map<String, dynamic>>[
                                    ..._claimRows,
                                    {
                                        "id":    _claimNewRow,
                                        "label": TranslationRegistry.processLabel("@@@T:claim_pick_new@@@"),
                                        "image": _defaultPlayerAvatar,
                                    },
                                ];
                                ActionRegistry.get("dvlist.set_rows")?.call(null, rows);
    }

    static const String _claimNewRow = "__new__";

    // Tap sur une ligne : `id` _claimNewRow = nouveau joueur. Puis la déclaration, comme sans ce détour.
    // L'écran de choix est retiré de la pile avant : le retour depuis la déclaration ramène au
    // clan, pas à une question déjà répondue.
    Future<void> on_claim_pick(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                final id          = m["id"]?.toString() ?? "";
                                _pendingClaimId   = id == _claimNewRow ? "" : id;
                                _pendingClaimName = _pendingClaimId.isEmpty ? "" : (m["label"]?.toString() ?? "");
                                _claimRows        = [];
                                deva_log("info", "[worker] on_claim_pick: ${_pendingClaimId.isEmpty ? 'nouveau joueur' : 'reprise de $_pendingClaimId'}");
                                _welcomeAdvancing = true;
                                DvOrb.navigate_back();
                                await _openInviteConsent();
    }

    // Le scellé de la déclaration est lisible par qui le transporte (base64url d'un JSON, cf.
    // dvdocuments) : on n'y lit que deux choses, « le chef s'est-il déclaré responsable légal ? »
    // et « pour quelle demande ? » (le code de l'accord qu'il a scellé avec sa déclaration).
    bool _ackIsGuardian(String sealed) {

                                if (sealed.isEmpty) return false;
                                try {
                                    final raw = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(sealed))));
                                    return raw is Map && raw["guardian"] == true;
                                } catch (_) {
                                    return false;
                                }
    }

    String _ackAssentCode(String sealed) {

                                if (sealed.isEmpty) return "";
                                try {
                                    final raw = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(sealed))));
                                    final assent = raw is Map ? raw["assent"] : null;
                                    return assent is Map ? (assent["n"]?.toString() ?? "") : "";
                                } catch (_) {
                                    return "";
                                }
    }

    // Admission du candidat, une fois le dépôt du chef lu (worker_join.dart). Appelée par l'écran
    // qui montre patte blanche (candidat connecté), par on_login une fois le compte d'un enfant lié
    // (_consumeJoinDeposit), et par l'app d'un enfant multiclan quand un représentant a autorisé
    // le clan qui l'accueille.
    //
    // [deposit] : le dépôt déchiffré {code, joinId, clanId, clanSecret, clanName, adminId,
    // adminName, region, ack, as_chief?, claim?, guardianSecret?, guest?, chief_devices?,
    // chief_lang?, vector}. [repAck] : la déclaration du représentant qui a autorisé ce clan
    // (multiclan), collée à la preuve à côté de celle de l'adulte qui accueille.
    //
    // Rend true quand c'est fini : admis, refusé (un message attend le candidat), ou mis en
    // attente de la décision d'un représentant.
    //
    // ⚠ L'ORDRE DES ÉCRITURES EST LA RÈGLE : users d'abord, puis userindexes (le secret du clan,
    //   que les règles de clans_players lisent), puis clans_players.
    Future<bool> _handleClanJoin(Map deposit, {String repAck = ""}) async {

                                if (_joinAdmitting) return false;
                                _joinAdmitting = true;
                                try {
                                    return await _admitInClan(deposit, repAck);
                                } finally {
                                    _joinAdmitting = false;
                                }
    }

    Future<bool> _admitInClan(Map deposit, String repAck) async {

                                // `var` : l'enfant qui reprend un joueur sans téléphone change d'identité
                                // de jeu en route (cf. _claimNoAccountPlayer).
                                var docId        = _sessionDocId();
                                final region     = deposit["region"]?.toString()     ?? "";
                                final clanId     = deposit["clanId"]?.toString()     ?? "";
                                final clanSecret = deposit["clanSecret"]?.toString() ?? "";
                                final adminId    = deposit["adminId"]?.toString()    ?? "";
                                final joinId     = deposit["joinId"]?.toString()     ?? "";
                                final code       = deposit["code"]?.toString()       ?? "";
                                final guest      = deposit["guest"] == true;
                                if (docId.isEmpty || region.isEmpty || clanId.isEmpty || clanSecret.isEmpty || _cloud == null) {
                                    deva_log("error", "[join] admission impossible : dépôt ou session incomplets");
                                    return false;
                                }

                                // Déclaration de l'adulte qui accueille, faite au moment de valider. On la
                                // colle à la preuve d'acceptation des CGU de CE joueur : la CGU a été acceptée
                                // pendant l'inscription, donc bien avant d'arriver ici, et dvdocuments
                                // complète la preuve existante (cf. documents.attach_ack).
                                final ack = deposit["ack"]?.toString() ?? "";

                                // MULTICLAN : déjà membre de ce clan (autre appareil) ; plafond de 8 clans ;
                                // clan d'une autre région que la maison (pas encore possible : tout le client
                                // lit UNE région).
                                final before = await _readSession(region);
                                if (_isActiveMemberOf(before, clanId)) {
                                    await _joinRefused("join_already_member");
                                    return true;
                                }
                                final homeRegion = await _homeRegion();
                                final refusalMc = _activeClans(before).length >= _kMaxClans ? "join_clans_cap"
                                    : (homeRegion.isNotEmpty && region != homeRegion) ? "clan_other_region" : "";
                                if (refusalMc.isNotEmpty) {
                                    await _joinRefused(refusalMc);
                                    return true;
                                }
                                final hadClans = _activeClans(before).isNotEmpty;

                                // UN ENFANT N'ENTRE QU'AVEC LA DÉCLARATION D'UN RESPONSABLE, faite pour LUI.
                                // C'est ici, et seulement ici, que les deux bouts se rencontrent (l'état légal
                                // de l'entrant et la déclaration de l'adulte), donc ici qu'on refuse, AVANT la
                                // moindre écriture au nom de l'enfant dans le clan.
                                // DÉFENSE EN PROFONDEUR : la déclaration porte le code de SA boîte (l'accord
                                // scellé par le parent), le même que celui du dépôt.
                                final legalRaw = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                final minor    = _gameplayLegal(legalRaw) != "a";
                                _gateUsedAuth.clear();
                                if (minor) {
                                    String refusal = "";
                                    if (guest) {
                                        // L'adulte d'un AUTRE clan l'accueille, sans rien décider pour lui : seule
                                        // l'autorisation d'un représentant (guest_auth) le fait entrer.
                                        refusal = hadClans ? await _guardianGate(docId, clanId, adminId, _gateUsedAuth)
                                                           : "invite_needs_child_ack";
                                    } else if (!_ackIsGuardian(ack)) {
                                        refusal = "invite_needs_child_ack";
                                    } else if (_ackAssentCode(ack) != code) {
                                        refusal = "kid_invite_not_mine";
                                    } else if (hadClans) {
                                        // MULTICLAN (§ 5.2) : déjà membre d'un clan, il n'entre que si l'adulte
                                        // qui l'accueille est l'un de ses représentants, ou si l'un d'eux a
                                        // autorisé ce clan.
                                        refusal = await _guardianGate(docId, clanId, adminId, _gateUsedAuth);
                                    }
                                    // Pas encore autorisé, mais ses représentants peuvent le faire : la demande
                                    // part chez eux, le dépôt attend sur ce téléphone (connecté : il peut le
                                    // garder).
                                    if (refusal == "kid_needs_guardian_auth" && hadClans && repAck.isEmpty) {
                                        await _guestJoinPark(Map<String, dynamic>.from(deposit));
                                        return true;
                                    }
                                    if (refusal.isNotEmpty) {
                                        await _joinRefused(refusal);
                                        return true;
                                    }
                                }

                                for (final a in [ack, repAck]) {
                                    if (a.isEmpty) continue;
                                    final r = await ActionRegistry.get("documents.attach_ack")?.call(null, a);
                                    deva_log("info", "[join] attach_ack → ${r ?? 'action absente'}");
                                }

                                // L'ENFANT REPREND UN JOUEUR SANS TÉLÉPHONE, désigné par le parent (claim,
                                // cf. _openClaimOrConsent). Un mineur seulement. À partir d'ici, l'identité de
                                // jeu est celle du joueur repris, et tout ce qui suit s'écrit sous elle.
                                final claimId = minor ? (deposit["claim"]?.toString() ?? "") : "";
                                if (claimId.isNotEmpty) {
                                    var r = "retry";
                                    for (var attempt = 0; attempt < 3 && r == "retry"; attempt++) {
                                        if (attempt > 0) await Future.delayed(Duration(seconds: 2 * attempt));
                                        r = await _claimNoAccountPlayer(clanId, clanSecret, claimId, joinId, region);
                                    }
                                    if (r != "ok") {
                                        await _joinRefused(r == "refused" ? "kid_claim_gone" : "join_show_error");
                                        return true;
                                    }
                                    docId = claimId;
                                }
                                // L'ADULTE ACCUEILLI COMME CHEF (décision du chef, portée par le dépôt qu'il
                                // est seul à pouvoir sceller). Adulte seulement : c'est la garde d'âge de
                                // promote_chief, un mineur n'est jamais chef.
                                final asChief = !minor && deposit["as_chief"] == true;

                                // 1. users, AVANT tout le reste. Trois essais : au-delà, le candidat
                                //    recommence (une boîte neuve, que le chef scannera de nouveau).
                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                // Clan d'origine à propager au doc membre (clans_players.original_clan) ; repli = ce clan.
                                String firstClan = clanId;
                                var written = false;
                                for (var attempt = 0; attempt < 3 && !written; attempt++) {
                                    if (attempt > 0) await Future.delayed(Duration(seconds: 2 * attempt));
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
                                        // MULTICLAN : la liste des clans (users.clans) ; steps.clan ci-dessous
                                        // n'est plus que le POINTEUR du clan courant, déplacé vers le nouveau.
                                        existing.set("clans.$clanId.region",        region);
                                        existing.set("clans.$clanId.last_visit",    now);
                                        existing.set("clans.$clanId.enabled",       true);
                                        existing.set("clans.$clanId.left_at",       "");
                                        existing.set("steps.clan.clanId",           clanId);
                                        existing.set("steps.clan.clanSecret",       clanSecret);
                                        existing.set("steps.clan.status",           "done");
                                        existing.set("steps.clan.date",             now);
                                        existing.set("steps.clan.result",           "joined");
                                        existing.set("steps.clan.device",           device);
                                        existing.set("date",                        now);
                                        await _cloud?.write("workers", "users", docId, existing, region: region);
                                        written = true;
                                    } catch (e) {
                                        deva_log("error", "[join] users write FAILED (essai ${attempt + 1}): $e");
                                    }
                                    _invalidateSessionCache();
                                }
                                if (!written) {
                                    await _joinRefused("join_show_error");
                                    return true;
                                }
                                // Admis : l'accord et le dépôt ont servi. Un nouveau clan passerait par un
                                // nouvel écran, une nouvelle boîte.
                                _joinAssent = null;
                                _joinFamily = null;

                                // userindexes doit avoir le clanSecret avant le read/update du clan
                                if (firebaseUid.isNotEmpty) {
                                    try {
                                        final indexDoc = Dvidle({});
                                        indexDoc.set("ownerId",                  firebaseUid);
                                        indexDoc.set("userId",                   docId);
                                        indexDoc.set("clans.$clanId.clanSecret", clanSecret);
                                        indexDoc.set("home_region",              homeRegion.isNotEmpty ? homeRegion : region);
                                        await _cloud?.write("workers", "userindexes", firebaseUid, indexDoc, region: region);
                                    } catch (e) {
                                        deva_log("error", "[join] userindexes update FAILED: $e");
                                    }
                                }

                                // 2. Le candidat devient membre : doc dédié dans clans_players.
                                //    Le doc clan n'est lu que pour son nom d'affichage (internal.name).
                                String clanName = deposit["clanName"]?.toString() ?? "";
                                Set<String> enabledMultiple = {};
                                try {
                                    final clan = await _cloud?.read(
                                        "workers", "clans", clanId,
                                        ownerId: clanSecret, region: region,
                                    );
                                    if (clan != null) {
                                        clanName = clan.get("internal.name")?.toString() ?? clanName;
                                        final em = clan.get("enabled_multiple");
                                        if (em is List) enabledMultiple = em.map((e) => e.toString()).toSet();
                                    }
                                    final device = await _cloud?.deviceId() ?? "";
                                    await _writeClanPlayer(clanId, clanSecret, docId, device, region, firstClan: firstClan);
                                    if (asChief) await _joinAsChief(clanId, clanSecret, region, docId);
                                    // AUDIT : l'entrée dans un clan (qui l'a fait entrer, par quelle voie).
                                    await _audit("clan_joined", {
                                        "playerId": docId, "clanId": clanId, "clan_name": clanName,
                                        "via": adminId, "legal": _gameplayLegal(legalRaw),
                                        "vector": deposit["vector"]?.toString() ?? "",
                                        if (joinId.isNotEmpty) "join": joinId,
                                        if (claimId.isNotEmpty) "claim": claimId,
                                        if (_gateUsedAuth.isNotEmpty) "guest_auth": true,
                                    });
                                    // Un clan quitté puis rejoint : ses notifications reviennent (le silence
                                    // posé au départ, ou par un représentant, ne vaut plus).
                                    await _messaging?.setMute(false, scope: clanId);
                                    // MULTICLAN : un joueur qui a déjà un profil (nom, avatar, titre) le
                                    // retrouve sur sa fiche de ce clan, sans qu'on le lui redemande.
                                    await _profileSyncOnEntry(clanId, clanSecret, region);
                                    // MULTICLAN, REPRÉSENTATION D'UN MINEUR. Première représentation (adhésion
                                    // d'origine, ou reprise d'un joueur sans téléphone) : l'enfant la crée avec
                                    // le secret tiré par le parent, qui en devient le représentant. Sinon : la
                                    // ligne de clan, quel que soit le chemin, visible de tous ses représentants.
                                    if (minor) {
                                        final gSecret   = deposit["guardianSecret"]?.toString() ?? "";
                                        final chiefName = deposit["adminName"]?.toString() ?? "";
                                        final hasGship  = ((await _gshipSecrets())[docId] ?? "").isNotEmpty;
                                        if (!hasGship && gSecret.isNotEmpty) {
                                            await _gshipCreateOrigin(childId: docId, secret: gSecret, adminId: adminId,
                                                adminName: chiefName, clanId: clanId, clanName: clanName,
                                                region: region, joinId: joinId);
                                        } else if (hasGship) {
                                            await _gshipNoteEntry(docId, clanId, clanName, chiefName, region, adminId,
                                                _gateUsedAuth.isNotEmpty);
                                        }
                                    }
                                } catch (e) {
                                    deva_log("error", "[join] clans_players update FAILED: $e");
                                }

                                // Annoncer l'arrivée aux membres déjà présents (notif push thème donjon).
                                // Le nom n'est demandé qu'APRÈS la liaison du compte : à cet instant il est
                                // encore vide pour un nouveau venu. On DIFFÈRE alors l'annonce et la ligne de
                                // journal jusqu'à sa saisie (_persistPlayerName les consomme). clans_logs est
                                // append-only : une entrée écrite sans nom resterait anonyme pour toujours.
                                final myName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                if (claimId.isNotEmpty) {
                                    // Pas d'annonce d'arrivée : le clan le connaît déjà. Une ligne de récit
                                    // à la place, « <nom> a maintenant son propre téléphone ».
                                    await _writeClanLog(clanId, clanSecret, region, "MemberClaimed",
                                        userId: docId, adminId: adminId, slug: myName,
                                        data: Dvidle({"userId": docId, "userName": myName, "adminId": adminId}));
                                } else if (myName.isEmpty) {
                                    await deva_set("worker.pending_member_joined.clanId",     clanId);
                                    await deva_set("worker.pending_member_joined.clanSecret", clanSecret);
                                    await deva_set("worker.pending_member_joined.region",     region);
                                    await deva_set("worker.pending_member_joined.adminId",    adminId);
                                    if (asChief) await deva_set("worker.pending_member_joined.as_chief", "true");
                                    await Deva.instance.store();
                                } else {
                                    try {
                                        await _notifyClanNewMember(clanId, clanSecret, region, docId, myName);
                                    } catch (e) {
                                        deva_log("error", "[join] notif nouveau membre FAILED: $e");
                                    }
                                    // Journal : un utilisateur a rejoint le clan (adminId = celui qui l'a accueilli).
                                    await _writeClanLog(clanId, clanSecret, region, "MemberJoined",
                                        userId: docId, adminId: adminId, slug: myName,
                                        data: Dvidle({"userId": docId, "userName": myName, "adminId": adminId}));
                                    if (asChief) await _announceJoinedChief(clanId, clanSecret, region, docId, myName, adminId);
                                }

                                // Créer les clones de l'arrivant pour les tâches multiple activées qu'il
                                // qualifie (legal_state) — les docs de base n'existent pas pour ces tâches.
                                // _writeClanPlayer ci-dessus a (ré)écrit legal_state ; on peut cloner ensuite.
                                try {
                                    await _createMyClones(clanId, clanSecret, region, enabledMultiple);
                                } catch (e) {
                                    deva_log("error", "[join] _createMyClones FAILED: $e");
                                }

                                // Charger l'état domaines/tâches du clan (miroir local + notif tiroirs),
                                // comme on_login() le fait pour le propriétaire via _loadClanTasks().
                                final joined = await _readSession(region);
                                if (joined != null) await _loadClanTasks(joined, region);

                                await Deva.instance.set("session.clan.name", clanName);
                                await Deva.instance.set("worker.session.clan_done", "true");
                                // Bienvenue clan jouée à la 1re arrivée sur dashboard (cf. on_dashboard_appear).
                                // Accueilli comme chef : la bienvenue le lui dit (une seule animation, pas une
                                // bienvenue suivie d'une promotion).
                                await deva_set("worker.pending_clan_welcome", asChief ? "joined_chief" : "joined");
                                // Nom pas encore saisi (tout nouveau venu) : le nom passe avant tout le reste.
                                // La cérémonie de bienvenue n'est PAS jouée ici : son drapeau reste armé et
                                // on_dashboard_appear la jouera à l'arrivée, après le nom, avec le tutoriel
                                // derrière. La déclencher maintenant la ferait couper net par la navigation.
                                if (joined?.get("steps.name") == null) {
                                    DvOrb.navigate_reset("player_name_screen");
                                    return true;
                                }
                                if (DvOrb.get_current_page()?.dvid == "dashboard") {
                                    await _playPendingClanWelcome();
                                } else {
                                    DvOrb.navigate_reset("dashboard");
                                }
                                return true;
    }

    // Reprise d'un joueur sans téléphone (no_account) par l'enfant, sur son propre téléphone.
    //
    // Le joueur garde son identifiant de jeu (le docId de clans_players) : tout ce qui compte
    // (journal, butin, bourse, tâches, avatar) y est rangé. On ne déplace donc rien, on raccroche
    // le compte de l'enfant à cet identifiant : userindexes/{uid}.userId → claimId, et un doc
    // users/{claimId} qui reprend celui de son inscription (CGU, âge, région) plus le nom du
    // joueur. Le doc d'inscription, devenu sans objet, est effacé.
    //
    // Rend "ok" (identité basculée), "refused" (plus rien à reprendre : joueur déjà repris,
    // révoqué, ou en cours de retrait du consentement) ou "retry" (échec d'écriture).
    //
    // ⚠ L'ORDRE PERMET LA REPRISE APRÈS PLANTAGE. Le joueur est marqué repris (claim_join) en
    //   premier : rejouée avec la même adhésion, la reprise se reconnaît et continue, alors
    //   qu'une autre adhésion est refusée. users/{claimId} est écrit avant que l'index n'y
    //   pointe, et l'ancien doc reçoit first_clan avant l'index : s'il survivait à un plantage,
    //   le balayage des comptes jamais admis (pulse_sweeper, piste orphans) ne le prendrait pas
    //   pour un orphelin, ce qui effacerait l'index et le compte de l'enfant avec lui.
    Future<String> _claimNoAccountPlayer(String clanId, String clanSecret, String claimId,
                                         String joinId, String region) async {

                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                final oldId       = _sessionDocId();
                                if (firebaseUid.isEmpty || oldId.isEmpty) return "retry";

                                // 1. Le secret du clan dans l'index : sans lui, les règles refusent la
                                //    lecture du joueur. L'identité de jeu, elle, ne bouge pas encore.
                                try {
                                    final idx = Dvidle({});
                                    idx.set("ownerId",                  firebaseUid);
                                    idx.set("clans.$clanId.clanSecret", clanSecret);
                                    await _cloud?.write("workers", "userindexes", firebaseUid, idx, region: region);
                                } catch (e) {
                                    deva_log("error", "[worker] _claimNoAccountPlayer: userindexes (secret) FAILED: $e");
                                    return "retry";
                                }

                                // 2. Le joueur : encore sans téléphone, ou déjà repris par CETTE adhésion.
                                Dvidle? player;
                                try {
                                    player = await _cloud?.read("workers", "clans_players/$clanId/players", claimId,
                                        ownerId: clanSecret, region: region);
                                } catch (e) {
                                    deva_log("error", "[worker] _claimNoAccountPlayer: lecture du joueur FAILED: $e");
                                    return "retry";
                                }
                                if (player == null
                                    || player.get("enabled") == false
                                    || (player.get("consent_due")?.toString() ?? "").isNotEmpty
                                    || (player.get("no_account") != true
                                        && player.get("claim_join")?.toString() != joinId)) {
                                    deva_log("warning", "[worker] _claimNoAccountPlayer: joueur $claimId plus disponible → refus");
                                    // Le secret ne sert plus à rien : il quitte l'index.
                                    try {
                                        final idx = Dvidle({});
                                        idx.set("clans.$clanId", "");
                                        await _cloud?.write("workers", "userindexes", firebaseUid, idx, region: region);
                                    } catch (_) {}
                                    return "refused";
                                }

                                // 3. Marqué repris : il a désormais un compte. `no_account` à false le fait
                                //    rentrer dans le droit commun (révocation d'un mineur, cascade serveur).
                                final now = DateTime.now().toUtc().toIso8601String();
                                try {
                                    final mark = Dvidle({});
                                    mark.set("id",          claimId);
                                    mark.set("no_account",  false);
                                    mark.set("claim_join",  joinId);
                                    mark.set("claimed_at",  now);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", claimId, mark,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("error", "[worker] _claimNoAccountPlayer: marque de reprise FAILED: $e");
                                    return "retry";
                                }

                                // 4. users/{claimId} : l'inscription de l'enfant (CGU, âge, région…), plus
                                //    l'identité du joueur. Le nom est déjà choisi : l'écran du nom est sauté.
                                final name = player.get("name")?.toString() ?? "";
                                try {
                                    final device   = await _cloud?.deviceId() ?? "";
                                    final original = player.get("original_clan")?.toString() ?? "";
                                    final doc      = await _readSession(region) ?? Dvidle({});
                                    doc.rem("docId");
                                    doc.set("ownerId",    firebaseUid);
                                    doc.set("userId",     claimId);
                                    doc.set("first_clan", original.isNotEmpty ? original : clanId);
                                    if (name.isNotEmpty) {
                                        doc.set("internal.name",     name);
                                        doc.set("steps.name.status", "done");
                                        doc.set("steps.name.date",   now);
                                        doc.set("steps.name.result", name);
                                        doc.set("steps.name.device", device);
                                    }
                                    final desc = player.get("internal.description")?.toString() ?? "";
                                    if (desc.isNotEmpty) doc.set("internal.description", desc);
                                    // L'identité de substitution du joueur, telle quelle (gel) : sans elle,
                                    // le rattrapage du démarrage en inventerait une autre et l'écraserait.
                                    final ext = _extFromDoc(player);
                                    if (ext != null) {
                                        doc.set("external.name",        ext.extName);
                                        doc.set("external.description", ext.extDesc);
                                        doc.set("external.source",      ext.source);
                                        final extDate = player.get("external.date")?.toString() ?? "";
                                        if (extDate.isNotEmpty) doc.set("external.date", extDate);
                                    }
                                    doc.set("claimed_at", now);
                                    await _cloud?.write("workers", "users", claimId, doc, region: region);
                                    _invalidateSessionCache();
                                } catch (e) {
                                    deva_log("error", "[worker] _claimNoAccountPlayer: users/$claimId FAILED: $e");
                                    _invalidateSessionCache();
                                    return "retry";
                                }

                                // 5. L'ancien doc d'inscription porte un clan avant que l'index ne le quitte
                                //    (cf. l'ordre ci-dessus), puis l'index bascule.
                                if (oldId != claimId) {
                                    try {
                                        await _cloud?.write("workers", "users", oldId,
                                            Dvidle({"ownerId": firebaseUid, "userId": oldId, "first_clan": clanId}), region: region);
                                    } catch (e) {
                                        deva_log("warning", "[worker] _claimNoAccountPlayer: garde de l'ancien doc non posée ($e)");
                                    }
                                }
                                try {
                                    await _cloud?.write("workers", "userindexes", firebaseUid,
                                        Dvidle({"ownerId": firebaseUid, "userId": claimId}), region: region);
                                } catch (e) {
                                    deva_log("error", "[worker] _claimNoAccountPlayer: userindexes (userId) FAILED: $e");
                                    return "retry";
                                }

                                // 6. L'identité en mémoire : désormais celle du joueur repris.
                                _userId     = claimId;
                                _authUserId = claimId;
                                await Deva.instance.set("session.user.id", claimId);
                                if (name.isNotEmpty) await Deva.instance.set("session.user.name", name);
                                _invalidateSessionCache();

                                // 7. L'ancien doc d'inscription n'a plus d'objet. Un échec n'est pas grave :
                                //    il porte first_clan, rien ne le prendra pour un compte orphelin.
                                if (oldId != claimId) {
                                    try {
                                        await _cloud?.delete("workers", "users", oldId, region: region);
                                    } catch (e) {
                                        deva_log("warning", "[worker] _claimNoAccountPlayer: ancien doc $oldId non effacé ($e)");
                                    }
                                }
                                deva_log("info", "[worker] _claimNoAccountPlayer: joueur $claimId repris ($oldId → $claimId)");
                                return "ok";
    }

    // Message d'une adhésion qui n'a pas abouti, côté adulte, quand il revient au choix du
    // clan. Consommé à l'affichage : il ne se montre qu'une fois.
    // ⚠ `dynamic caller` : l'appear d'une PAGE passe un DvPage, qui n'est pas une shape.
    Future<void> on_new_or_pick_clan_appear(dynamic caller, dynamic event) async {

                                await DvOrb.wait_for_shape("new_or_pick_clan/notice");
                                if (_joinNotice.isEmpty) {
                                    _hideShapes(["new_or_pick_clan/notice"]);
                                    return;
                                }
                                final notice = _joinNotice;
                                _joinNotice = "";
                                await _revealLabel("new_or_pick_clan/notice", notice);
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
                                final asChief    = (await deva_get("worker.pending_member_joined.as_chief"))?.toString()   == "true";
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
                                if (asChief) await _announceJoinedChief(clanId, clanSecret, region, docId, name, adminId);
    }

    // L'adulte accueilli comme chef s'inscrit lui-même dans clans.admins, dès son admission : la
    // décision est celle du chef qui l'a accueilli, portée par le dépôt que lui seul peut sceller
    // (cf. _welcomeDeposit). Mêmes écritures que promote_chief : la liste des chefs (source
    // d'autorisation) et le miroir is_admin sur son doc. La mémoire de la célébration est posée
    // à "true" : la bienvenue dit déjà qu'il est chef, la vigilance ne rejouera pas de promotion.
    // Journal et notification attendent son nom (_announceJoinedChief).
    Future<void> _joinAsChief(String clanId, String clanSecret, String region, String docId) async {

                                try {
                                    final clanDoc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? [])
                                        .map((a) => a.toString()).where((a) => a.isNotEmpty).toList();
                                    if (!admins.contains(docId)) {
                                        final out = Dvidle({});
                                        out.set("admins", [...admins, docId]);
                                        await _cloud?.write("workers", "clans", clanId, out,
                                            region: region, ownerId: clanSecret);
                                    }
                                    final pflag = Dvidle({});
                                    pflag.set("id",       docId);
                                    pflag.set("is_admin", true);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", docId, pflag,
                                        region: region, ownerId: clanSecret);
                                    await deva_set("worker.player_last_is_admin", "true");
                                    _isAdminClanId = "";
                                    await _ensureIsAdmin(clanId, clanSecret, region);
                                    await _syncChiefUi();
                                    deva_log("info", "[worker] _joinAsChief: $docId entre comme chef de $clanId");
                                } catch (e) {
                                    deva_log("error", "[worker] _joinAsChief FAILED: $e");
                                }
    }

    // Journal ChiefPromoted (promoteur = le chef qui a invité) et notification au reste du clan,
    // comme promote_chief. Une fois le nom connu : clans_logs est append-only.
    Future<void> _announceJoinedChief(String clanId, String clanSecret, String region,
                                      String docId, String name, String adminId) async {

                                await _writeClanLog(clanId, clanSecret, region, "ChiefPromoted",
                                    userId: docId, adminId: adminId,
                                    data: Dvidle({"playerId": docId, "playerName": name,
                                                  "adminId": adminId, "adminName": ""}));
                                try {
                                    await _notifyChiefPromotion(clanId, clanSecret, region, docId, name);
                                } catch (e) {
                                    deva_log("error", "[worker] _announceJoinedChief: notif FAILED: $e");
                                }
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
    // internalDesc / ext : description de personnage et identité de substitution, transmises par
    // les écrans qui les font naître (nom du joueur, création d'un enfant sans compte). Absentes,
    // elles sont reprises du doc `users` du joueur — la source de vérité pour qui en a un.
    Future<void> _writeClanPlayer(
        String clanId, String clanSecret, String userId, String device, String region,
        {bool asAdmin = false, String firstClan = "",
         String nameOverride = "", String internalDesc = "", _AiDraft? ext,
         String legalStateOverride = "", bool noAccount = false}) async {

            if (clanId.isEmpty || clanSecret.isEmpty || userId.isEmpty) return;
            // Le clan ouvert devient le scope du style des notifications : ses notifications
            // reçues app fermée prendront la couleur de SON thème (dvmessaging.setStyleScope).
            if (userId == _userId) unawaited(_messaging?.setStyleScope(clanId));
            try {
                final existing = await _cloud?.read(
                    "workers", "clans_players/$clanId/players", userId,
                    ownerId: clanSecret, region: region,
                );
                final doc = existing ?? Dvidle({});
                // RETRAIT DU CONSENTEMENT EN COURS : on ne touche plus à ce document. Rien de ce
                // que cette fonction écrit n'a de sens pour un joueur qu'on a cessé de traiter —
                // et `has_device` est reforcé à true à CHAQUE appel, donc à chaque login : une
                // connexion de l'enfant le remettrait dans les agrégats du clan (butin, coup de
                // pouce) alors qu'il n'y joue plus. Le document est en lecture seule jusqu'à ce
                // qu'un chef rétablisse l'enfant ou que l'échéance tombe.
                if ((doc.get("consent_due")?.toString() ?? "").isNotEmpty) {
                    deva_log("info", "[consent] _writeClanPlayer ignoré : retrait en cours sur $userId");
                    return;
                }
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
                // Premier passage du mois pour ce joueur ? Lu AVANT d'écraser la date : c'est le
                // changement de mois de last_connected qui pose la marque d'actif (plus bas).
                final avant      = doc.get("last_connected")?.toString() ?? "";
                final maintenant = DateTime.now().toUtc();
                final moisNeuf   = avant.length < 7
                    || avant.substring(0, 7) != maintenant.toIso8601String().substring(0, 7);
                doc.set("last_connected", maintenant.toIso8601String());
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
                // Paire internal/external du MEMBRE. Le champ plat `name` ci-dessus en reste le
                // MIROIR : une dizaine de lecteurs s'appuient dessus (roster, journal, butin,
                // objets) et le désynchroniser de internal.name casserait l'affichage partout.
                //
                // internal.* suit l'autorité du renommage, comme `name`. external.* est
                // INIT-SI-NULL : l'identité de substitution est figée à la naissance du joueur,
                // et aucun renommage ultérieur ne la régénère.
                //
                // Source par défaut : le doc `users` du joueur — mais SEULEMENT s'il est bien le
                // sien. Pendant une prise de place, _sessionDocId() désigne l'ADMIN : recopier son
                // identité ici collerait le nom de l'adulte sur l'enfant qu'il incarne. Un enfant
                // sans compte (no_account) n'a pas de doc `users` du tout : sa paire ne vit QUE
                // sur ce document, d'où l'argument `ext` que lui passe on_create_player_confirm.
                final identity = (!_impersonating && userId == _sessionDocId())
                    ? await _readSession(region)
                    : null;
                // internal.name recopie ce que `name` vaut AU SORTIR du bloc ci-dessus, et hérite
                // ainsi exactement de sa règle : autorité au renommage, init-si-null sinon. Le
                // dériver de `users` à la place ferait diverger les deux au premier renommage posé
                // par un admin en prise de place — la reconnexion du joueur l'effacerait.
                final intName = doc.get("name")?.toString() ?? "";
                if (intName.isNotEmpty) doc.set("internal.name", intName);
                // Description : autorité au paramètre explicite (l'écran qui vient de la saisir),
                // sinon init-si-null depuis le doc `users` du joueur. Même raison : ne pas défaire
                // à chaque login ce qu'un autre écran a écrit.
                if (internalDesc.isNotEmpty) {
                    doc.set("internal.description", internalDesc);
                } else if ((doc.get("internal.description")?.toString() ?? "").isEmpty) {
                    final d = identity?.get("internal.description")?.toString() ?? "";
                    if (d.isNotEmpty) doc.set("internal.description", d);
                }
                if ((doc.get("external.name")?.toString() ?? "").isEmpty) {
                    final e = ext ?? _extFromDoc(identity);
                    if (e != null && e.extName.isNotEmpty) _setExternal(doc, e);
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
                if (moisNeuf) unawaited(_marqueActif(userId, region, maintenant));
                // Le doc vient d'être réécrit : la valeur mémorisée pour le badge de combat peut
                // dater d'avant (repli sur la conf pris avant l'initialisation du champ). On la
                // jette plutôt que de la deviner — la prochaine ouverture de combat relira.
                _maxXpCache.remove(userId);
            } catch (e) {
                deva_log("error", "[worker] _writeClanPlayer: FAILED: $e");
            }
    }

    // La MARQUE D'ACTIF du mois : stats_active/{AAAAMM}_{userId}, posée au premier
    // last_connected du mois. C'est elle que compte `active_users` (pubudget, budget
    // automatique et rapport Telegram) : un count() sur les marques du mois, au lieu de
    // relire toutes les heures tous les joueurs connectés depuis le 1er.
    //
    // ⚠ UNE MARQUE, PAS UN COMPTEUR. dvcloud ne sait pas incrémenter, et un compteur
    //   compterait deux fois le joueur de deux clans. La marque est idempotente : la
    //   réécrire (deux appareils, une reconnexion) ne change rien, et la règle l'accepte
    //   pour qu'un refus ne déclenche pas « Clan en maintenance » (cf. dvautover).
    // ⚠ JAMAIS BLOQUANTE. Une marque perdue ne coûte qu'un joueur de moins au compteur
    //   du budget, jamais la connexion.
    // ⚠ `expiration` EST UN DateTime : dvcloud le sérialise en timestamp, seul type que
    //   le TTL de Firestore efface. 62 jours : le mois compté, plus le suivant.
    Future<void> _marqueActif(String userId, String region, DateTime quand) async {

            try {
                final mois = "${quand.year}${quand.month.toString().padLeft(2, "0")}";
                await _cloud?.write("workers", "stats_active", "${mois}_$userId", Dvidle({
                    "month":      mois,
                    "expiration": quand.add(const Duration(days: 62)),
                }), region: region);
            } catch (e) {
                deva_log("warning", "[worker] marque d'actif non posée : $e");
            }
    }

    // BACKFILL de l'identité de substitution. Les documents créés AVANT ce correctif portent un
    // `external` FAUX, pas absent : pour un joueur il valait mot pour mot le nom interne, pour un
    // clan il en était préfixé (« Les Dupont-eu-142 »). Un init-si-null ne les rattraperait donc
    // jamais — le champ est bien là, il ne protège simplement rien.
    //
    // Appelé en fire-and-forget depuis on_login : rien ne l'attend, et un échec ne coûte qu'une
    // tentative de plus au démarrage suivant. La condition est auto-effaçante : dès qu'un
    // substitut est écrit (IA ou banque), elle devient fausse et ne se rejoue plus jamais — ce
    // qui est exactement la règle de gel appliquée aux documents anciens.
    Future<void> _backfillExternalIdentity(Dvidle session, String region) async {

                                if (region.isEmpty || _impersonating || _anon) return;
                                try {
                                    await _backfillPlayerExternal(session, region);
                                } catch (e) {
                                    deva_log("error", "[worker] backfill joueur FAILED: $e");
                                }
                                try {
                                    await _backfillClanExternal(session, region);
                                } catch (e) {
                                    deva_log("error", "[worker] backfill clan FAILED: $e");
                                }
    }

    Future<void> _backfillPlayerExternal(Dvidle session, String region) async {

                                final intName = session.get("internal.name")?.toString()  ?? "";
                                final extName = session.get("external.name")?.toString()  ?? "";
                                if (intName.isEmpty) return;                       // nom pas encore saisi
                                if (extName.isNotEmpty && extName != intName) return;   // déjà protégé
                                final docId = _sessionDocId();
                                if (docId.isEmpty) return;

                                final intDesc = session.get("internal.description")?.toString() ?? "";
                                // Banque locale, pas d'IA : ce rattrapage tourne au démarrage, sans que
                                // personne ne l'ait demandé. Y appeler le modèle transmettrait le nom
                                // interne d'un enfant en tâche de fond — exactement ce que ce champ
                                // existe pour éviter.
                                final ext     = _bankSubstitute("player");
                                if (ext.extName.isEmpty) return;

                                final patch = Dvidle({});
                                patch.set("ownerId", _cloud?.currentUser()?.providerUid ?? "");
                                patch.set("userId",  docId);
                                _setExternal(patch, ext);
                                await _cloud?.write("workers", "users", docId, patch, region: region);
                                _invalidateSessionCache();
                                deva_log("info", "[worker] backfill joueur → ${ext.extName} (${ext.source})");

                                // Miroir sur le doc membre, qui porte la copie dénormalisée lue par tout
                                // ce qui affiche un joueur. Écriture ciblée (deep-merge) : le doc membre
                                // n'est pas relu, on n'écrase que ces champs-là.
                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return;
                                final mirror = Dvidle({});
                                mirror.set("id",            _userId);
                                mirror.set("internal.name", intName);
                                if (intDesc.isNotEmpty) mirror.set("internal.description", intDesc);
                                _setExternal(mirror, ext);
                                await _cloud?.write("workers", "clans_players/$clanId/players", _userId,
                                    mirror, region: region, ownerId: clanSecret);
    }

    // Volet clan, RÉSERVÉ AUX CHEFS : quatre membres d'une même famille qui ouvrent l'app le même
    // matin généreraient sinon quatre substituts concurrents pour un seul clan.
    Future<void> _backfillClanExternal(Dvidle session, String region) async {

                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) return;
                                if (!await _ensureIsAdmin(clanId, clanSecret, region)) return;

                                final clan = await _cloud?.read("workers", "clans", clanId,
                                    ownerId: clanSecret, region: region);
                                if (clan == null) return;
                                final intName  = clan.get("internal.name")?.toString()        ?? "";
                                final extName  = clan.get("external.name")?.toString()        ?? "";
                                final descFlat = clan.get("description")?.toString()          ?? "";
                                final intDesc  = clan.get("internal.description")?.toString() ?? "";
                                final extDesc  = clan.get("external.description")?.toString() ?? "";
                                if (intName.isEmpty) return;

                                // Fuite du nom interne dans le nom externe : soit il est absent, soit il
                                // vaut le nom interne, soit il en est préfixé (l'ancien « {interne}-eu-142 »).
                                // ⚠ Limite connue : un clan renommé DEPUIS sa création n'est plus détecté —
                                // le nom interne qui a fuité n'existe plus nulle part pour être comparé.
                                final leaking  = extName.isEmpty || extName == intName ||
                                                 extName.startsWith("$intName-");
                                final needDesc = intDesc.isEmpty && descFlat.isNotEmpty;
                                if (!leaking && extDesc.isNotEmpty && !needDesc) return;

                                final patch = Dvidle({});
                                patch.set("ownerId", clanSecret);
                                // Migration du champ plat historique vers internal.description.
                                if (needDesc) patch.set("internal.description", descFlat);

                                if (leaking || extDesc.isEmpty) {
                                    // Banque locale (cf. _backfillPlayerExternal) : aucun appel au
                                    // modèle dans un rattrapage de démarrage.
                                    final ext = _bankSubstitute("clan");
                                    if (ext.extName.isNotEmpty && leaking) {
                                        // On conserve le discriminant existant (« -eu-142 ») quand il y en a
                                        // un : il identifie ce clan depuis sa naissance, seule la base — le
                                        // nom qui fuitait — a besoin d'être remplacée.
                                        String suffix = extName.startsWith("$intName-")
                                            ? extName.substring(intName.length)
                                            : "";
                                        if (suffix.isEmpty) {
                                            int count = 0;
                                            try {
                                                final r = await _cloud?.call("count_sessions", Dvidle({}));
                                                count = int.tryParse(r?.get("count")?.toString() ?? "0") ?? 0;
                                            } catch (_) {}
                                            suffix = "-$region-$count";
                                        }
                                        patch.set("external.name",   "${ext.extName}$suffix");
                                        patch.set("external.source", ext.source);
                                        patch.set("external.date",   DateTime.now().toUtc().toIso8601String());
                                    }
                                    if (extDesc.isEmpty && ext.extDesc.isNotEmpty) {
                                        patch.set("external.description", ext.extDesc);
                                    }
                                }
                                await _cloud?.write("workers", "clans", clanId, patch,
                                    region: region, ownerId: clanSecret);
                                deva_log("info", "[worker] backfill clan $clanId OK");
    }

    // Relit une identité de substitution déjà persistée (doc `users` ou `clans_players`). Rend
    // null si le document n'en porte pas — un appelant ne doit alors RIEN écrire plutôt que
    // d'inventer une valeur : le gel n'a de sens que si l'on n'écrase jamais l'existant.
    _AiDraft? _extFromDoc(Dvidle? d) {

                                final n = d?.get("external.name")?.toString() ?? "";
                                if (n.isEmpty) return null;
                                return _AiDraft()
                                    ..extName = n
                                    ..extDesc = d?.get("external.description")?.toString() ?? ""
                                    ..source  = d?.get("external.source")?.toString() ?? "";
    }

    // Pose les quatre champs `external.*` d'un document. Un seul endroit pour que la date de gel
    // et la provenance ne soient jamais oubliées quelque part.
    void _setExternal(Dvidle doc, _AiDraft e) {

                                doc.set("external.name",        e.extName);
                                doc.set("external.description", e.extDesc);
                                doc.set("external.source",      e.source);
                                doc.set("external.date",        DateTime.now().toUtc().toIso8601String());
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

    // Contrôles de tout accueil d'un joueur : le clan doit être connu de la session, l'appelant
    // doit en être chef, et il doit rester de la place. Rend le clanId, ou "" si refusé.
    Future<String> _clanIdIfChief(String who) async {

                                final region  = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
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

    // Horodate la PREMIÈRE invitation ouverte par le clan (`clans.first_invite_at`, écrit une seule
    // fois). Sert au balayage serveur (pulse_sweeper) à distinguer deux clans d'un seul membre qui
    // n'ont rien à voir : celui dont le chef a essayé d'inviter et n'y est pas arrivé, et celui qui
    // joue seul délibérément — un clan de 1 à 2 joueurs, c'est ~40 % des clans, le palier le plus
    // souscrit. « Un seul membre » ne discrimine donc rien ; « n'a jamais ouvert d'invitation », si.
    //
    // Posé ici, au consentement confirmé, et non à l'admission : ce qu'on mesure est la TENTATIVE.
    // Best-effort — un compteur d'analyse ne fait jamais échouer un recrutement.
    Future<void> _stampFirstInvite(String clanId) async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
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
