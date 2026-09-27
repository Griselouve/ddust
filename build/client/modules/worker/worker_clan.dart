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

                                // L'enfant parle d'abord : écran d'avis (la question), puis écran de
                                // partage de sa réponse et de son code, d'où il scanne ou saisit
                                // l'invitation du parent.
                                ActionRegistry.register("worker.on_kid_assent_appear",         on_kid_assent_appear);
                                ActionRegistry.register("worker.kid_assent_route",             kid_assent_route);
                                ActionRegistry.register("worker.on_kid_assent_share_appear",   on_kid_assent_share_appear);
                                ActionRegistry.register("worker.on_kid_assent_send",           on_kid_assent_send);
                                ActionRegistry.register("worker.on_kid_scan_invite",           on_kid_scan_invite);
                                ActionRegistry.register("worker.on_enter_invite_pin_appear",   on_enter_invite_pin_appear);

                                // Le parent décide ensuite : option « Accueillir un enfant » (scan de
                                // l'accord) et lien ddust://assent ouvert à distance.
                                ActionRegistry.register("worker.on_welcome_child",             on_welcome_child);
                                ActionRegistry.register("worker.on_assent_link",               (c, e) async { if (e is Map) await on_assent_link(c, e); });
                                ActionRegistry.register("worker.on_invite_kind_toggle",        on_invite_kind_toggle);
                                ActionRegistry.register("worker.on_invite_chief_toggle",       on_invite_chief_toggle);
                                // L'enfant jouait déjà sur le téléphone du parent : quel joueur reprend-il ?
                                ActionRegistry.register("worker.on_claim_pick_appear",         on_claim_pick_appear);
                                ActionRegistry.register("worker.on_claim_pick",                on_claim_pick);

                                ActionRegistry.register("worker.on_invite_ack_changed",        on_invite_ack_changed);
                                ActionRegistry.register("worker.on_invite_consent_appear",     on_invite_consent_appear);

                                ActionRegistry.register("worker.on_virtuallobby_accepted",     (c, e) async { if (e is Map) await on_virtuallobby_accepted(c, e); });

                                ActionRegistry.register("worker.on_submission_status_changed", (c, e) async { if (e is Map) await on_submission_status_changed(c, e); });

                                ActionRegistry.register("worker.on_invite_clan",               (c, e) async { await on_invite_clan(c, e); });

                                ActionRegistry.register("worker.on_management_created",      (c, e) async { if (e is Map) await on_management_created(c, e); });

                                // Partage du lien d'invitation par QR code (écran invite_clan).
                                ActionRegistry.register("worker.on_share_clan_invite",       on_share_clan_invite);

                                ActionRegistry.register("worker.on_share_clan_invite_pin",   on_share_clan_invite_pin);

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

                                // Adhésion en attente (candidat connecté, invitation acceptée) : écran
                                // join_wait, qui survit à la fermeture de l'application.
                                ActionRegistry.register("worker.on_join_wait_appear",        on_join_wait_appear);
                                ActionRegistry.register("worker.on_join_wait_giveup",        on_join_wait_giveup);
                                // Message d'une attente abandonnée ou expirée, côté adulte.
                                ActionRegistry.register("worker.on_new_or_pick_clan_appear", on_new_or_pick_clan_appear);

                                // Créer un joueur enfant (option clan « Créer un joueur », chef) : selector du
                                // menu d'en-tête + écran de saisie du nom + création directe dans clans_players.
                                ActionRegistry.register("worker.clan_settings_selector",    clan_settings_selector);

                                ActionRegistry.register("worker.clan_ai_off",               clan_ai_off);

                                ActionRegistry.register("worker.clan_ai_on",                clan_ai_on);

    }

    Future<void> on_join_clan(DvShape? caller, dynamic event) async {

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                if (region.isNotEmpty) await _writeStep(region, "clan", "joined");
                                await Deva.instance.set("worker.session.clan_done", "true");
                                // Bienvenue clan jouée à la 1re arrivée sur dashboard (cf. on_dashboard_appear).
                                await deva_set("worker.pending_clan_welcome", "joined");
                                DvOrb.navigate_reset("dashboard");
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
    // Un mineur n'arrive plus ici pendant son inscription : il passe par kid_assent_share et se
    // connecte AVANT d'entrer dans un clan. Seul un mineur déjà connecté et sans clan (admission
    // qui n'a pas abouti) peut encore y venir, et il ne doit jamais atteindre l'option « créer ».
    //
    // ⚠ PLUS AUCUNE ÉCRITURE ICI. Cet écran inscrivait autrefois l'onboarding d'un mineur encore
    //   anonyme, pour que le lobby puisse lui répondre sous un uid connu. C'était écrire en base
    //   les données d'un enfant AVANT que son parent n'ait décidé ; le parcours a été retourné
    //   pour que cela ne puisse plus arriver (cf. kid_assent_route).
    // ⚠ `dynamic caller` ET NON `DvShape?` : l'`appear` d'une PAGE passe la page
    //   elle-même, et une page est un DvView, pas un DvShape. Typer le paramètre
    //   `DvShape?` faisait lever un `type 'DvPage' is not a subtype of 'DvShape?'` que
    //   DvView attrape et journalise — l'écran naissait donc inerte, en silence.
    Future<void> on_kid_wants_clan_appear(dynamic caller, dynamic event) async {

                                final raw   = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                // Mineur connecté et sans clan : cet écran ne lui ouvre aucune porte, le
                                // QR code d'un chef sans accord d'enfant ne fait entrer qu'un adulte. On le
                                // ramène à SA question, d'où sa réponse repartira vers son parent.
                                if (_gameplayLegal(raw) != "a") {
                                    DvOrb.navigate_reset("kid_assent_screen");
                                    return;
                                }
                                final back = await DvOrb.wait_for_shape("kid_wants_clan/back");
                                // MULTICLAN : un adulte déjà membre vient de « Mes clans » ; la marche
                                // arrière le ramène à son clan, pas au choix créer/rejoindre.
                                final region  = await _homeRegion();
                                Dvidle? session;
                                try { session = region.isNotEmpty ? await _readSession(region) : null; } catch (_) {}
                                if (_activeClans(session).isNotEmpty) {
                                    back?.set("shape.label", TranslationRegistry.translate("back_to_my_clan"));
                                    if (back is DvLabel) await back.computeDisplay();
                                }
                                back?.set("shape.visible", true);
                                back?.set("shape.events.tap", true);
                                back?.refreshUI();
    }

    Future<void> on_back_to_choice(DvShape? caller, dynamic event) async {

                                final region  = await _homeRegion();
                                Dvidle? session;
                                try { session = region.isNotEmpty ? await _readSession(region) : null; } catch (_) {}
                                if (_activeClans(session).isNotEmpty) {
                                    DvOrb.navigate_reset("dashboard");
                                    return;
                                }
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

    // Selector du menu d'en-tête du clan (DvMenuButton, charge vide). Seuls le journal et les
    // tutoriels sont ouverts à tous ; recruter (accueil d'un enfant, QR, invitation à distance) et « Créer un joueur »
    // sont des prérogatives de chef (admin). Le menu s'affiche dans l'ordre de la liste renvoyée :
    // on calcule donc `isAdmin` d'abord, et on monte la liste dans l'ordre historique.
    //
    // « Mes achats » n'est plus ici : il a rejoint le kebab de la boutique
    // (worker.shop_settings_selector), avec le reste de ce qui touche à l'argent.
    Future<List<String>> clan_settings_selector(dynamic caller, dynamic data) async {

                                var isAdmin = false;
                                var isAdult = false;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    isAdmin = await _ensureIsAdmin(clanId, clanSecret, region);
                                    isAdult = await _ensureIsAdult(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[clan] clan_settings_selector FAILED: $e");
                                }
                                // Lecture KO → isAdmin false : repli sûr (les options chef restent cachées).
                                // Les tutoriels en DEUXIEME position, juste apres le journal :
                                // c'est l'option qu'on cherche quand on ne sait pas quoi faire, et
                                // elle etait enterree sous deux entrees reservees au chef. Un
                                // membre simple ne voyait meme qu'une ligne avant elle.
                                // (« Mes clans » n'est pas ici : c'est le bouton aux deux flèches de
                                // l'écran du clan, clan_page/switch.)
                                final options = <String>["clan_log", "tutorials"];
                                // « Accueillir un enfant » EN TÊTE des options de chef : c'est la seule
                                // porte d'un enfant, et le cas le plus fréquent d'une application de
                                // famille. « QR Code du clan » et « Inviter à distance », sans accord
                                // d'enfant joint, ne font plus entrer que des adultes.
                                if (isAdmin) options.addAll(["welcome_child", "clan_qr", "clan_invite_remote"]);
                                // MULTICLAN : accueillir un enfant qui a déjà un clan (le chef montre un QR
                                // code à son représentant) ; et, pour tout adulte, l'écran des enfants
                                // qu'il représente (autoriser un clan, co-représentants, retraits).
                                if (isAdmin && isAdult) options.add("welcome_guest_child");
                                if (isAdult) options.add("guardian_hub");
                                if (isAdmin) options.add("create_player");
                                // L'IA du clan : UNE des deux options, selon l'état relu à frais.
                                // En dernier : c'est un réglage, pas un geste de jeu.
                                if (isAdmin) options.add(await _iaDuClan() ? "clan_ai_off" : "clan_ai_on");
                                // « Noter et partager » TOUT EN BAS, pour tout adulte (chef ou non) :
                                // partager l'app vers l'extérieur est réservé à la majorité légale.
                                if (isAdult) options.add("rate_share");
                                return options;
    }

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

    Future<void> on_scan_qr(DvShape? caller, dynamic event) async {

                                // Le lecteur ne vide JAMAIS son résultat : sans cette remise à blanc, un
                                // scan abandonné relirait le code du scan précédent.
                                await deva_set("commons.qrcodereader.result", "");
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

                                // Les contrôles de région et de nature (adulte / enfant) sont faits par
                                // on_invite_clan_link, commun au QR et au deeplink.
                                await on_invite_clan_link(caller, {
                                    "group_id": groupId,
                                    "lobby_id": lobbyId,
                                    "region":   region,
                                    "k":        uri.queryParameters["k"] ?? "",
                                    "n":        uri.queryParameters["n"] ?? "",
                                });
    }

    // ⚠ LE PARCOURS « DEMANDE D'ENTRÉE » A ÉTÉ SUPPRIMÉ le 2026-09-22 (ddust://request,
    //   accept_request_clan, share.clan_request). Le candidat y envoyait une demande, le chef
    //   l'acceptait d'un tap : c'était la seule porte qui ne passait PAS par la déclaration du
    //   chef (invite_consent_screen), et le lobby y réutilisait la dernière déclaration
    //   scellée, faite pour quelqu'un d'autre. L'enfant qui veut entrer passe désormais par
    //   son accord (kid_assent_share) et le chef par « Accueillir un enfant ».

    //-----------------------------------------------------------------------
    //-- L'enfant parle d'abord (kid_assent_screen → kid_assent_share) -------
    //-----------------------------------------------------------------------
    //
    // ⚠ L'ORDRE EST LA RÈGLE, et il vient du droit. Le décret colombien 1377 de 2013 (art. 12)
    //   veut que l'enfant exprime sa volonté AVANT la décision de son représentant ; le RGPD
    //   (art. 8) qu'aucune de ses données ne soit enregistrée avant l'autorisation de ce
    //   représentant. D'où ce parcours : l'enfant répond, sa réponse VOYAGE jusqu'au parent
    //   (QR code ou lien, sans une donnée personnelle), le parent déclare et invite, et c'est
    //   seulement alors que l'enfant se connecte et que quoi que ce soit s'écrit à son nom.
    //
    // ⚠ RIEN N'EST ÉCRIT DE CE CÔTÉ, ni en base ni sur le disque. Avant le login, le
    //   dictionnaire deva vit dans la couche `prelogin`, en mémoire : un enfant qui ferme
    //   l'application ne laisse aucune trace, et repart du tout premier écran.

    // Liste blanche des textes qu'un accord peut désigner. Le chef AFFICHE le texte nommé par
    // le QR code : sans cette liste, un QR fabriqué ferait lire au chef n'importe quelle
    // phrase de l'application, au moment précis où il s'engage.
    // ⚠ `kid_assent_question_again` A DISPARU (2026-09-22) avec la reconfirmation qu'il posait :
    //   un accord qui le citerait ne vient plus d'une version en service.
    static const List<String> _assentTextKeys = ["kid_assent_question"];

    // Le code de l'accord : six caractères, sans ceux qu'on confond à l'œil ou à la voix
    // (0/O, 1/I/L). Le parent le compare d'un coup d'œil entre deux écrans, il ne le tape pas.
    static const String _assentCodeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    static final  RegExp _assentCodeFormat  = RegExp(r'^[A-HJKMNP-Z2-9]{6}$');

    String _newAssentCode() {

                                final rng = Random.secure();
                                return List.generate(6,
                                    (_) => _assentCodeAlphabet[rng.nextInt(_assentCodeAlphabet.length)]).join();
    }

    Future<bool> _kidHasPendingInvite() async {

                                final group = (await deva_get("worker.pending_group_id"))?.toString()        ?? "";
                                final token = (await deva_get("worker.pending_invite_token_in"))?.toString() ?? "";
                                return group.isNotEmpty || token.isNotEmpty;
    }

    // Toute la mémoire d'une demande d'enfant, oubliée d'un coup : le code, le lien qui le
    // porte, le message en attente et l'invitation mise de côté. Déconnexion, admission,
    // parcours remis à zéro.
    Future<void> _forgetKidAssent() async {

                                _kidAssentCode   = "";
                                _kidAssentLink   = "";
                                _kidAssentNotice = "";
                                await _clearPendingInvite();
    }

    // L'invitation peut-elle être retenue sur CET appareil ? Rend "" si oui, sinon la clef du
    // message à afficher. `kind` absent (invitation faite par une version antérieure) = adulte.
    //
    //   * adulte (état légal "a") : refuse une invitation « enfant », faite pour un autre ;
    //   * mineur : refuse une invitation « adulte » (le parent n'a rien déclaré pour lui), et
    //     une invitation « enfant » qui ne porte pas SON code. Pas de code en mémoire
    //     (application tuée pendant l'attente) = refus aussi : c'est la règle stricte, l'enfant
    //     envoie une nouvelle demande, on ne lui fait pas reconfirmer une ancienne.
    //
    // État légal encore inconnu (lien ouvert application fermée, avant l'écran d'âge) : on ne
    // peut pas juger, le contrôle est repoussé (kid_assent_route, _consumePendingInvite).
    Future<String> _inviteKindRefusal(String kind, String code) async {

                                final legalRaw = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "";
                                if (legalRaw.isEmpty) return "";
                                final isChild = kind == "child";
                                if (_gameplayLegal(legalRaw) == "a") return isChild ? "invite_for_child" : "";
                                if (!isChild) return "invite_needs_child_ack";
                                if (_kidAssentCode.isEmpty || code != _kidAssentCode) return "kid_invite_not_mine";
                                return "";
    }

    // Un mineur dont l'invitation vient d'être refusée hors de l'écran de partage : le message
    // l'attend sur cet écran. S'il a un code, il y retourne (sa demande tient toujours) ; sinon
    // il repart de sa question, qui en fera une nouvelle.
    void _sendKidBackToAssent(String notice) {

                                _kidAssentNotice = notice;
                                DvOrb.navigate_reset(_kidAssentCode.isEmpty ? "kid_assent_screen" : "kid_assent_share");
    }

    // L'écran d'avis pose UNE question, toujours la même : « as-tu envie de jouer ? ».
    // ⚠ PLUS DE SECONDE QUESTION (2026-09-22). Un enfant arrivé ici avec une invitation déjà en
    //   poche (lien ouvert application fermée) se voyait demander « c'est toujours ce que tu
    //   veux ? », puis allait droit à la saisie du code. Une invitation porte désormais le code
    //   de la demande à laquelle elle répond, et ce code est perdu avec le processus : une
    //   invitation reçue avant ce oui ne peut pas y répondre (cf. kid_assent_route).
    // ⚠ `dynamic caller` : l'appear d'une PAGE passe un DvPage, qui n'est pas une shape.
    Future<void> on_kid_assent_appear(dynamic caller, dynamic event) async {

                                // Déjà connecté (mineur sans clan, ramené ici par kid_wants_clan ou par
                                // un refus d'admission) : la flèche mènerait aux conditions, qu'il a
                                // acceptées depuis longtemps. Elle disparaît.
                                // (Après l'attente de la question : les shapes de la page existent alors.)
                                await DvOrb.wait_for_shape("kid_assent/question");
                                if (!_anon) _hideShapes(["kid_assent/back"]);
    }

    // Routeur du pas kid_assent_screen (steps.yml). Reçoit la route demandée par le bouton
    // (`go` par l'interlude passage_assent, `back` par la flèche) :
    //   * `back`  : retour aux conditions ;
    //   * `go`    : l'écran qui transmet la réponse de l'enfant, et son code, au parent.
    // ⚠ LES ROUTES `pin` ET `link` ONT DISPARU (2026-09-22) : elles menaient droit à la saisie
    //   du code ou à la connexion avec une invitation reçue avant ce oui.
    Future<String> kid_assent_route(DvShape? caller, dynamic event) async {

                                if (event?.toString() == "back") return "back";

                                // Le code et le lien « je veux jouer » naissent ICI, au moment exact du
                                // oui : c'est ce moment-là que la date doit dire, pas celui où l'écran se
                                // réaffiche. Un nouveau oui, c'est une nouvelle demande, donc un nouveau code.
                                _kidAssentCode   = _newAssentCode();
                                _kidAssentLink   = await _buildKidAssentLink();

                                // Une invitation attend déjà (lien ouvert application fermée, ou en plein
                                // parcours) : elle a été faite AVANT ce oui, elle ne peut pas porter ce
                                // code. Refusée, et l'écran de partage dit pourquoi. Une invitation
                                // « adulte » le dit à sa façon ; un lien à code, encore scellé, ne dit pas
                                // ce qu'il est : il est traité comme une invitation pour un autre enfant.
                                if (await _kidHasPendingInvite()) {
                                    final group = (await deva_get("worker.pending_group_id"))?.toString() ?? "";
                                    _kidAssentNotice = group.isNotEmpty && _pendingInviteKind != "child"
                                        ? "invite_needs_child_ack"
                                        : "kid_invite_not_mine";
                                    deva_log("info", "[worker] kid_assent_route: invitation reçue avant ce oui → refusée");
                                    await _clearPendingInvite();
                                }
                                return "go";
    }

    // Le contenu du QR code « je veux jouer » : ddust://assent?d=<base64url d'un JSON>.
    //
    // ⚠ AUCUNE DONNÉE PERSONNELLE, et c'est délibéré : la date du oui, la langue et le royaume
    //   dans lesquels l'enfant a lu, le texte qu'on lui a montré et la version des conditions
    //   qu'il vient d'accepter. Pas de prénom : le parent sait qui est devant lui, et ce lien
    //   peut transiter par une messagerie.
    // `n` : le code de la demande (_kidAssentCode), tiré au hasard, qui ne dit rien de l'enfant.
    // L'application du parent le recopie dans son invitation, et c'est par lui que l'appareil
    // de l'enfant reconnaît l'invitation faite pour SA demande.
    Future<String> _buildKidAssentLink() async {

                                if (_kidAssentCode.isEmpty) _kidAssentCode = _newAssentCode();
                                final payload = <String, dynamic>{
                                    "v":           1,
                                    "n":           _kidAssentCode,
                                    "date":        DateTime.now().toUtc().toIso8601String(),
                                    "lang":        TranslationRegistry.currentLang,
                                    "region":      (await Deva.instance.get("documents.session.region"))?.toString() ?? "",
                                    "text_key":    "kid_assent_question",
                                    "cgu_version": (await deva_get("documents.acceptance.cgu.version"))?.toString() ?? "",
                                };
                                // Sans le remplissage `=` : il n'a rien à faire dans un paramètre d'URL, et
                                // _decodeAssent le rétablit (base64Url.normalize).
                                final d = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll("=", "");
                                return "ddust://assent?d=$d";
    }

    // ⚠ `dynamic caller` : l'appear d'une PAGE passe un DvPage, qui n'est pas une shape.
    Future<void> on_kid_assent_share_appear(dynamic caller, dynamic event) async {

                                // Filet : l'écran n'est atteint que par kid_assent_route, qui pose les
                                // deux. Un lien sans code (ou l'inverse) ne pourrait pas servir.
                                if (_kidAssentCode.isEmpty || _kidAssentLink.isEmpty) {
                                    _kidAssentCode = _newAssentCode();
                                    _kidAssentLink = await _buildKidAssentLink();
                                }
                                final qr = await DvOrb.wait_for_shape("kid_assent_share/qrcode");
                                qr?..set("shape.content", _kidAssentLink)..refreshUI();
                                // Le code, en grand : le parent vérifie d'un coup d'œil que c'est le même
                                // que sur son écran de déclaration (invite_consent_screen/assent).
                                final code = DvOrb.get_shape_by_id("kid_assent_share/code");
                                if (code != null) {
                                    code.set("shape.label", TranslationRegistry.processLabel("@@@T:kid_assent_share_code@@@")
                                        .replaceAll("{code}", _kidAssentCode));
                                    if (code is DvLabel) await code.computeDisplay();
                                    code.refreshUI();
                                }
                                if (_kidAssentNotice.isNotEmpty) {
                                    await _revealLabel("kid_assent_share/error", _kidAssentNotice);
                                    _kidAssentNotice = "";
                                } else {
                                    _hideShapes(["kid_assent_share/error"]);
                                }
                                // MULTICLAN : l'enfant déjà membre d'un clan peut revenir au sien.
                                await _syncKidAssentLeave();
    }

    // « Envoyer ma réponse » : le modèle de partage share.kid_assent (screens_meta.yml) lit le
    // lien dans le dictionnaire. Il n'y est posé que LE TEMPS DU PARTAGE, puis effacé : le
    // lien porte le code de la demande, et le code ne vit qu'en mémoire du worker.
    Future<void> on_kid_assent_send(DvShape? caller, dynamic event) async {

                                if (_kidAssentLink.isEmpty) return;
                                await deva_set("worker.kid_assent_link", _kidAssentLink);
                                try {
                                    final fut = ActionRegistry.get("share.kid_assent")?.call(caller, event);
                                    if (fut is Future) await fut;
                                } finally {
                                    await deva_set("worker.kid_assent_link", "");
                                }
    }

    // « Scanner l'invitation de mon parent ». N'accepte QUE ddust://invite : l'enfant scanne à
    // côté de son parent, et le seul autre QR code du jeu qu'il puisse croiser est le sien.
    Future<void> on_kid_scan_invite(DvShape? caller, dynamic event) async {

                                // Le lecteur ne vide jamais son résultat : sans cette remise à blanc, un
                                // scan abandonné relirait le code du scan précédent.
                                await deva_set("commons.qrcodereader.result", "");
                                final fut = ActionRegistry.get("qrcodereader.scan")?.call(caller, event);
                                if (fut is Future) await fut;

                                final content = (await deva_get("commons.qrcodereader.result"))?.toString() ?? "";
                                if (content.isEmpty) return;   // scan abandonné : rien à dire

                                final uri     = Uri.tryParse(content.trim());
                                final isInv   = uri != null && uri.scheme == "ddust" && uri.host == "invite";
                                final groupId = isInv ? (uri?.queryParameters["group_id"] ?? "") : "";
                                final lobbyId = isInv ? (uri?.queryParameters["lobby_id"] ?? "") : "";
                                if (groupId.isEmpty || lobbyId.isEmpty) {
                                    await _revealLabel("kid_assent_share/error", "kid_assent_share_not_invite");
                                    return;
                                }
                                _hideShapes(["kid_assent_share/error"]);
                                await on_invite_clan_link(caller, {
                                    "group_id": groupId,
                                    "lobby_id": lobbyId,
                                    "region":   uri?.queryParameters["region"] ?? "",
                                    "k":        uri?.queryParameters["k"]      ?? "",
                                    "n":        uri?.queryParameters["n"]      ?? "",
                                });
    }

    // L'invitation mise de côté est jetée : refusée, consommée, ou parcours remis à zéro. Les
    // quatre clefs vont ensemble, avec la nature et le code gardés en mémoire.
    Future<void> _clearPendingInvite() async {

                                await deva_set("worker.pending_group_id",       "");
                                await deva_set("worker.pending_lobby_id",       "");
                                await deva_set("worker.pending_invite_region",  "");
                                await deva_set("worker.pending_invite_token_in", "");
                                _pendingInviteKind = "";
                                _pendingInviteCode = "";
                                _pendingInviteFresh = false;
    }

    // L'écran de saisie du code pré-remplit le lien reçu, d'où qu'on y arrive : lien ouvert
    // application ouverte, ou reprise après login. Le faire à
    // l'appear évite à chaque appelant d'attendre la shape après sa navigation.
    // ⚠ `dynamic caller` : l'appear d'une PAGE passe un DvPage, qui n'est pas une shape.
    Future<void> on_enter_invite_pin_appear(dynamic caller, dynamic event) async {

                                _hideShapes(["enter_invite_pin/error"]);
                                final token = (await deva_get("worker.pending_invite_token_in"))?.toString() ?? "";
                                if (token.isEmpty) return;
                                final field = await DvOrb.wait_for_shape("enter_invite_pin/token");
                                if ((field?.get("shape.value")?.toString() ?? "").isNotEmpty) return;
                                field?..set("shape.value", token)..refreshUI();
    }

    //-----------------------------------------------------------------------
    //-- Le parent décide ensuite (« Accueillir un enfant ») ----------------
    //-----------------------------------------------------------------------

    // Décode la charge d'un accord d'enfant. Rend null si ce n'en est pas un, ou s'il est
    // incomplet : le chef ne doit jamais déclarer sur la foi d'un accord qu'on ne sait pas lire.
    // Ne rend QUE les champs connus : ce qui voyage ensuite avec la déclaration du parent est
    // ce que l'application de l'enfant a écrit, rien de plus.
    Map<String, dynamic>? _decodeAssent(String d) {

                                if (d.isEmpty) return null;
                                try {
                                    final raw = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(d))));
                                    if (raw is! Map) return null;
                                    if (raw["v"]?.toString() != "1") return null;
                                    final date    = raw["date"]?.toString()     ?? "";
                                    final textKey = raw["text_key"]?.toString() ?? "";
                                    // Le code est exigé : sans lui, l'invitation que le chef ferait
                                    // serait refusée par l'appareil de l'enfant, après la déclaration.
                                    // Autant le dire au chef avant qu'il ne déclare.
                                    final code    = raw["n"]?.toString()        ?? "";
                                    if (DateTime.tryParse(date) == null) return null;
                                    if (!_assentTextKeys.contains(textKey)) return null;
                                    if (!_assentCodeFormat.hasMatch(code)) return null;
                                    return <String, dynamic>{
                                        "v":           1,
                                        "n":           code,
                                        "date":        date,
                                        "lang":        raw["lang"]?.toString()        ?? "",
                                        "region":      raw["region"]?.toString()      ?? "",
                                        "text_key":    textKey,
                                        "cgu_version": raw["cgu_version"]?.toString() ?? "",
                                    };
                                } catch (_) {
                                    return null;
                                }
    }

    Map<String, dynamic>? _parseAssentUri(String content) {

                                final uri = Uri.tryParse(content.trim());
                                if (uri == null || uri.scheme != "ddust" || uri.host != "assent") return null;
                                return _decodeAssent(uri.queryParameters["d"] ?? "");
    }

    // Option « Accueillir un enfant » : l'enfant est à côté, il montre son QR code.
    //
    // Un code qui n'est pas un accord n'arrête PAS le chef : l'écran de déclaration s'ouvre quand
    // même, limité au cas adulte, et dit en tête ce qui s'est passé. C'est l'idiome maison (pas
    // de fenêtre modale), et c'est aussi le plus utile : un chef qui a scanné le mauvais code
    // voit tout de suite pourquoi les cas « enfant » ne lui sont pas proposés.
    Future<void> on_welcome_child(DvShape? caller, dynamic event) async {

                                if ((await _clanIdIfChief("on_welcome_child")).isEmpty) return;

                                // Le lecteur ne vide jamais son résultat : sans cette remise à blanc, un
                                // scan abandonné rejouerait l'accord scanné la fois précédente.
                                await deva_set("commons.qrcodereader.result", "");
                                final fut = ActionRegistry.get("qrcodereader.scan")?.call(caller, event);
                                if (fut is Future) await fut;
                                final content = (await deva_get("commons.qrcodereader.result"))?.toString() ?? "";
                                if (content.isEmpty) return;   // scan abandonné

                                _pendingAssent  = _parseAssentUri(content);
                                _assentRejected = _pendingAssent == null;
                                // L'enfant est à côté : le QR code du clan est le chemin naturel. Le
                                // chef peut encore basculer sur l'invitation à distance depuis l'écran.
                                await deva_set("worker.pending_invite_kind", "qr");
                                await _openClaimOrConsent();
    }

    // Le parent ouvre le lien que son enfant lui a envoyé (ddust://assent?d=…). Même traitement
    // que le scan, mais l'enfant est loin : l'invitation à distance est proposée d'abord.
    //
    // Application fermée, le lien arrive AVANT que le compte ne soit chargé : l'accord est gardé
    // en mémoire et on_login le reprend une fois le chef connecté (_openPendingAssent).
    Future<void> on_assent_link(DvShape? caller, Map event) async {

                                final assent = _decodeAssent(event["d"]?.toString() ?? "");
                                if (assent == null) {
                                    deva_log("warning", "[worker] on_assent_link: lien d'accord illisible, ignoré");
                                    return;
                                }
                                _pendingAssent  = assent;
                                _assentRejected = false;
                                if (!(_cloud?.isReady() ?? false) || _anon || _userId.isEmpty) {
                                    deva_log("info", "[worker] on_assent_link: accord gardé en mémoire jusqu'au login");
                                    return;
                                }
                                await _openPendingAssent();
    }

    // Ouvre la déclaration pour l'accord en attente, si l'appelant est bien chef. Un accord reçu
    // par quelqu'un qui ne l'est pas est oublié : il n'a rien à décider.
    Future<void> _openPendingAssent() async {

                                if (_pendingAssent == null) return;
                                if ((await _clanIdIfChief("_openPendingAssent")).isEmpty) {
                                    _pendingAssent = null;
                                    return;
                                }
                                await deva_set("worker.pending_invite_kind", "pin");
                                await _openClaimOrConsent();
    }

    // L'ENFANT JOUAIT DÉJÀ SUR LE TÉLÉPHONE D'UN PARENT (joueur sans compte, no_account, créé par
    // « Créer un joueur »). Il reçoit son propre téléphone : il doit retrouver CE joueur (XP,
    // butin, journal, avatar), pas en créer un second. La question est posée au PARENT, jamais à
    // l'enfant : c'est lui qui sait, et c'est lui seul qui désigne le joueur. Un enfant ne peut
    // pas dire « je suis Léo » ; le choix voyage avec la déclaration du chef, dans l'invitation
    // privée puis le secret du clan (claim), jusqu'à _handleClanJoin.
    //
    // Posée seulement s'il y a de quoi choisir : un clan sans joueur sans téléphone va droit à
    // la déclaration, comme avant. Le chemin adulte (sans accord) n'est pas concerné : un joueur
    // sans compte est un enfant.
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
                                DvOrb.navigate_back();
                                await _openInviteConsent();
    }

    // Bascule QR code ⇄ invitation à distance, en mode « enfant ». Dans les deux autres entrées
    // (QR Code du clan, Inviter à distance), le mode est déjà choisi par l'option du menu.
    Future<void> on_invite_kind_toggle(DvShape? caller, dynamic event) async {

                                final kind = (await deva_get("worker.pending_invite_kind"))?.toString() ?? "qr";
                                final next = kind == "pin" ? "qr" : "pin";
                                await deva_set("worker.pending_invite_kind", next);
                                await _revealLabel("invite_consent_screen/kind",
                                    next == "pin" ? "invite_consent_kind_pin" : "invite_consent_kind_qr");
    }

    // Bascule « simple membre ⇄ aussi chef de clan », en mode ADULTE seulement : un mineur n'est
    // jamais chef (cf. la garde d'âge de promote_chief). Le libellé dit l'état courant et qu'on
    // peut en changer, comme la bascule QR / à distance.
    Future<void> on_invite_chief_toggle(DvShape? caller, dynamic event) async {

                                _inviteAsChief = !_inviteAsChief;
                                await _revealLabel("invite_consent_screen/chief",
                                    _inviteAsChief ? "invite_consent_chief_yes" : "invite_consent_chief_no");
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

    // Acceptation d'un lobby, tirée par dvvirtuallobby : sur l'appareil du CHEF par sa
    // surveillance (watch_management), sur celui du CANDIDAT par acceptInvitation.
    //
    // ⚠ LE CANDIDAT N'EST PLUS ADMIS ICI (2026-09-22). Son attente est portée par l'écran
    //   join_wait (users.pending_join, puis vigilance du secret), posée par _acceptAndWait
    //   APRÈS l'acceptation. Cet évènement-ci n'est tiré que si le record était encore
    //   « pending », il ne survit pas à un redémarrage, et il part avant même que pending_join
    //   soit écrit : il ne peut rien porter de durable. Côté candidat, il n'y a donc rien à faire.
    //
    // « A un clan » se juge sur steps.clan.clanId NON VIDE, comme dans on_login. Un steps.clan
    // présent mais vidé (joueur parti de son clan, cf. _leaveClanLocal) n'est pas un clan.
    Future<void> on_virtuallobby_accepted(DvShape? caller, Map event) async {

                                final groupId = event["group_id"]?.toString() ?? "";
                                final lobbyId = event["lobby_id"]?.toString() ?? "";
                                final region  = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                final session = region.isNotEmpty ? await _readSession(region) : null;
                                final hasClan = (session?.get("steps.clan.clanId")?.toString() ?? "").isNotEmpty;

                                deva_log("info", "[worker] on_virtuallobby_accepted: groupId=$groupId lobbyId=$lobbyId hasClan=$hasClan");

                                if (!hasClan) {
                                    deva_log("info", "[worker] on_virtuallobby_accepted: candidat, l'attente du secret est sur join_wait");
                                    return;
                                }
                                // Chemin VIVANT du chef (application ouverte sur le QR code ou le code) :
                                // même publication que la reprise, avec les mêmes gardes (_publishInvite).
                                // Plafond de membres vérifié à CHAQUE admission et pas seulement à
                                // l'ouverture du recrutement : c'est ici, sur l'appareil du chef, que le
                                // clan s'agrandit réellement, le seul endroit qui connaisse l'effectif et
                                // qui ait l'autorité de payer pour l'augmenter. Sans secret publié, le
                                // candidat reste sur join_wait jusqu'à l'expiration de l'invitation : un
                                // refus ici vaut mieux qu'un membre à moitié écrit.
                                if (lobbyId.isNotEmpty) {
                                    final r = await _publishInvite(groupId, lobbyId, navigate: true);
                                    if (r == "full") {
                                        deva_log("info", "[worker] on_virtuallobby_accepted: admission refusée (clan au complet)");
                                        return;
                                    }
                                }
                                DvOrb.navigate_reset("dashboard");
    }

    // Écrit l'invitation PRIVÉE du chef, workers/clans_invites/{lobbyId}, AVANT le lobby
    // (on_confirm_invite_consent). C'est elle, et non le record de lobby, qui autorise la
    // publication du secret du clan (cf. _publishInvite).
    //
    // La base `workers` est en isolation `strict` : dvcloud estampille `ownerId` avec l'uid
    // FIREBASE du chef connecté, et les règles serveur exigent que ce chef détienne le secret du
    // clan (userindexes/{uid}.clans.{clanId}.clanSecret). `adminUserId` est l'identifiant de JEU
    // du chef (celui de clans.admins) : les deux ne se confondent pas, et c'est lui que la
    // publication confronte à la liste des chefs.
    //
    // `ack` : la déclaration scellée du chef (et l'accord de l'enfant qu'elle embarque). Elle
    // vivait dans `worker.pending_ack`, un emplacement UNIQUE : deux invitations ouvertes
    // l'une après l'autre s'y écrasaient, et la seconde déclaration partait avec la première
    // admission. Chaque invitation porte désormais la sienne.
    //
    // `expires_at` (ISO, lu par l'application) et `expiration` (timestamp) disent le même
    // instant : la politique TTL posée par pufirestore ne regarde QUE un champ nommé
    // `expiration`, de type timestamp. Sans lui, rien ne serait jamais effacé.
    //
    // Rend false si l'écriture a échoué : l'appelant n'ouvre alors pas le lobby, une invitation
    // qui ne pourrait jamais être servie ne doit pas être affichée.
    //
    // `claim` : le joueur sans téléphone que l'enfant reprend (cf. _openClaimOrConsent), absent
    // pour un nouveau joueur. Posé par le chef, relu par lui seul à la publication.
    //
    // `as_chief` : l'adulte invité sera aussi chef de clan, décision du chef à l'invitation.
    // `guardian_secret` : le secret de représentation d'un enfant (multiclan), tiré par le parent
    // quand l'invitation porte un accord d'enfant ; il voyage avec le secret du clan et sert à
    // l'enfant à créer sa guardianship s'il n'en a pas encore (adhésion d'origine).
    Future<bool> _writeClanInvite(String clanId, String lobbyId, String ack, String kind,
                                  {String claim = "", bool asChief = false, String guardianSecret = ""}) async {

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                if (_cloud == null || region.isEmpty || clanId.isEmpty || lobbyId.isEmpty) {
                                    deva_log("error", "[worker] _writeClanInvite: contexte incomplet (region=$region clanId=$clanId)");
                                    return false;
                                }
                                final now     = DateTime.now().toUtc();
                                final expires = now.add(Duration(hours: await _inviteTtlHours()));
                                try {
                                    await _cloud?.write("workers", "clans_invites", lobbyId, Dvidle({
                                        "clanId":       clanId,
                                        "adminUserId":  _sessionDocId(),
                                        "ack":          ack,
                                        "kind":         kind,
                                        if (claim.isNotEmpty) "claim": claim,
                                        if (asChief)          "as_chief": true,
                                        if (guardianSecret.isNotEmpty) "guardian_secret": guardianSecret,
                                        "created_at":   now.toIso8601String(),
                                        "expires_at":   expires.toIso8601String(),
                                        "expiration":   expires,
                                        "published_at": "",
                                    }), region: region);
                                    deva_log("info", "[worker] invitation privée écrite (lobbyId=$lobbyId kind=$kind)");
                                    return true;
                                } catch (e) {
                                    deva_log("error", "[worker] _writeClanInvite FAILED: $e");
                                    return false;
                                }
    }

    // Publie le secret du clan pour UNE invitation acceptée. Seul point de publication, pour les
    // deux chemins : le chemin vivant (on_virtuallobby_accepted, application du chef ouverte) et
    // la reprise (_resumeInvites, au login et sur l'écran du clan).
    //
    // ⚠ UN RECORD DE LOBBY ACCEPTÉ NE SUFFIT PAS. Les règles de la base virtuallobby laissent
    //   n'importe quel compte connecté créer un record dans un clan dont il connaît
    //   l'identifiant (il figure dans chaque QR code), puis l'accepter lui-même. Publier pour
    //   « tout record accepté » donnerait le secret du clan à un inconnu. On exige donc
    //   l'invitation PRIVÉE du chef (_writeClanInvite). dvcloud ne rend un document d'une base
    //   `strict` qu'à son auteur : lue ici, elle est donc de nous. Reste à vérifier qu'elle vise
    //   ce clan, qu'elle n'a pas expiré, et que son auteur (adminUserId) figure toujours dans
    //   clans.admins, tout comme le joueur courant (_ensureIsAdmin).
    //   Conséquence assumée : un co-chef ne publie pas l'invitation d'un autre chef, elle attend
    //   que son auteur rouvre l'application.
    //
    // Rend "published", "already" (déjà publiée), "full" (plus de place : rien n'est publié),
    // "invalid" (aucune invitation valide : jamais servie) ou "error".
    // [navigate] : clan plein → page des paliers (_storeRefuseMember) ; sinon rien d'affiché
    // (_storeCapNotice) : c'est le cas du login, qui ne doit pas détourner le démarrage.
    //
    // Publier deux fois ne pose aucun problème : le secret est réécrit à l'identique.
    Future<String> _publishInvite(String groupId, String lobbyId, {bool navigate = true}) async {

                                final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                final session    = region.isNotEmpty ? await _readSession(region) : null;
                                final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (lobbyId.isEmpty || clanId.isEmpty || clanSecret.isEmpty) {
                                    deva_log("error", "[worker] _publishInvite: clanId ou clanSecret absent de la session");
                                    return "error";
                                }
                                if (groupId.isNotEmpty && groupId != clanId) {
                                    deva_log("warning", "[worker] _publishInvite: record d'un autre clan ($groupId), rien n'est publié");
                                    return "invalid";
                                }

                                // 1. L'invitation privée : existe, vise ce clan, pas expirée, auteur chef.
                                Dvidle? invite;
                                try {
                                    invite = await _cloud?.read("workers", "clans_invites", lobbyId, region: region);
                                } catch (e) {
                                    deva_log("error", "[worker] _publishInvite: lecture de l'invitation FAILED: $e");
                                    return "error";
                                }
                                if (invite == null) {
                                    deva_log("warning", "[worker] _publishInvite: aucune invitation privée de ce chef pour lobbyId=$lobbyId "
                                        "(record créé par un autre compte, ou invitation d'un autre chef) : rien n'est publié");
                                    return "invalid";
                                }
                                if ((invite.get("clanId")?.toString() ?? "") != clanId) {
                                    deva_log("warning", "[worker] _publishInvite: invitation d'un autre clan (lobbyId=$lobbyId), rien n'est publié");
                                    return "invalid";
                                }
                                final expires = DateTime.tryParse(invite.get("expires_at")?.toString() ?? "");
                                if (expires == null || DateTime.now().toUtc().isAfter(expires.toUtc())) {
                                    deva_log("info", "[worker] _publishInvite: invitation expirée (lobbyId=$lobbyId), rien n'est publié");
                                    return "invalid";
                                }
                                if ((invite.get("published_at")?.toString() ?? "").isNotEmpty) return "already";
                                if (!await _ensureIsAdmin(clanId, clanSecret, region)) {
                                    deva_log("warning", "[worker] _publishInvite: joueur courant non chef, rien n'est publié");
                                    return "invalid";
                                }
                                final author = invite.get("adminUserId")?.toString() ?? "";
                                try {
                                    final clanDoc = await _cloud?.read("workers", "clans", clanId, ownerId: clanSecret, region: region);
                                    final admins  = List<dynamic>.from(clanDoc?.get("admins") as List? ?? []);
                                    if (author.isEmpty || !admins.contains(author)) {
                                        deva_log("warning", "[worker] _publishInvite: l'auteur de l'invitation n'est plus chef (lobbyId=$lobbyId), rien n'est publié");
                                        return "invalid";
                                    }
                                } catch (e) {
                                    deva_log("error", "[worker] _publishInvite: lecture des chefs FAILED: $e");
                                    return "error";
                                }

                                // 2. La place. Au login, on ne détourne rien : la page des paliers
                                //    attendra le passage sur l'écran du clan.
                                if (navigate) {
                                    if (await _storeRefuseMember()) return "full";
                                } else if ((await _storeCapNotice()).isNotEmpty) {
                                    deva_log("info", "[worker] _publishInvite: clan au complet, publication différée (lobbyId=$lobbyId)");
                                    return "full";
                                }

                                // 3. La publication. La déclaration du chef voyage avec le secret : c'est
                                //    le seul canal qui serve les deux chemins de recrutement (QR et code),
                                //    et sa charge est libre. L'appareil du nouvel entrant la colle à sa
                                //    propre preuve d'acceptation des CGU, où lui seul peut écrire.
                                final lobby = ModuleRegistry.create("dvvirtuallobby");
                                if (lobby == null) return "error";
                                final ack   = invite.get("ack")?.toString()   ?? "";
                                // Le joueur sans téléphone que l'enfant reprend : même voyage que la
                                // déclaration, qu'il complète (cf. _openClaimOrConsent).
                                final claim = invite.get("claim")?.toString() ?? "";
                                // L'adulte invité sera aussi chef (décision du chef à l'invitation).
                                final asChief = invite.get("as_chief") == true;
                                // MULTICLAN : le nom du chef (ligne de clan de la guardianship de l'enfant)
                                // et, pour l'invitation d'un enfant, le secret de représentation.
                                final adminName      = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                final clanName       = (await Deva.instance.get("session.clan.name"))?.toString() ?? "";
                                final guardianSecret = invite.get("guardian_secret")?.toString() ?? "";
                                final ok  = (await (lobby as dynamic).publishSecret(lobbyId, clanId, {
                                    "clanId":     clanId,
                                    "clanSecret": clanSecret,
                                    "adminId":    _userId,
                                    "adminName":  adminName,
                                    "clanName":   clanName,
                                    if (ack.isNotEmpty)   "ack":   ack,
                                    if (claim.isNotEmpty) "claim": claim,
                                    if (asChief)          "as_chief": true,
                                    if (guardianSecret.isNotEmpty) "guardianSecret": guardianSecret,
                                })) == true;
                                if (!ok) return "error";

                                // 4. Marquée publiée : la reprise ne la sert plus. UNE DÉCLARATION PAR
                                //    INVITATION, une admission par invitation. Un échec d'écriture n'est pas
                                //    grave : la reprise republiera à l'identique.
                                try {
                                    await _cloud?.write("workers", "clans_invites", lobbyId,
                                        Dvidle({"published_at": DateTime.now().toUtc().toIso8601String()}), region: region);
                                } catch (e) {
                                    deva_log("warning", "[worker] _publishInvite: published_at non écrit ($e), la publication reste valable");
                                }
                                deva_log("info", "[worker] _publishInvite: secret publié (lobbyId=$lobbyId)");
                                // Le clan s'agrandit réellement ici, sur l'appareil du chef : le rappel
                                // de recrutement s'éteint TOUT DE SUITE.
                                await _setClanAlone(false);
                                return "published";
    }

    // Reprise des invitations acceptées pendant que l'application du chef était fermée : au login
    // (branche « a un clan », [navigate] faux) et à chaque passage sur l'écran du clan
    // ([navigate] vrai : un clan plein y ouvre la page des paliers, comme au chemin vivant).
    // Chef seulement. Rend true si elle a navigué.
    Future<bool> _resumeInvites({bool navigate = false}) async {

                                if (_invitesResuming) return false;
                                final quiet = _invitesQuietAt;
                                if (quiet != null && DateTime.now().difference(quiet) < const Duration(minutes: 1)) return false;
                                _invitesResuming = true;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = region.isNotEmpty ? await _readSession(region) : null;
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return false;
                                    if (!await _ensureIsAdmin(clanId, clanSecret, region)) return false;
                                    final lobby = ModuleRegistry.create("dvvirtuallobby");
                                    if (lobby == null) return false;
                                    final records = await (lobby as dynamic).listManagement(clanId, status: "accepted");
                                    var pending = 0;
                                    for (final r in (records is List ? records : const [])) {
                                        if (r is! Dvidle) continue;
                                        final lobbyId = (r.get("lobbyId") ?? r.get("docId"))?.toString() ?? "";
                                        if (lobbyId.isEmpty) continue;
                                        final res = await _publishInvite(clanId, lobbyId, navigate: navigate);
                                        deva_log("info", "[worker] _resumeInvites: $lobbyId → $res");
                                        if (res == "full") return navigate;
                                        if (res == "published" || res == "error") pending++;
                                    }
                                    // Rien à servir : répit d'une minute avant la prochaine requête.
                                    _invitesQuietAt = pending == 0 ? DateTime.now() : null;
                                } catch (e) {
                                    deva_log("error", "[worker] _resumeInvites FAILED: $e");
                                } finally {
                                    _invitesResuming = false;
                                }
                                return false;
    }

    Future<void> on_submission_status_changed(DvShape? caller, Map event) async {

                                // La submission du candidat est passée à « accepted » (surveillance
                                // virtuallobby.watch_submission, que ddust n'arme plus). L'admission, elle,
                                // attend le secret du clan : c'est l'affaire de join_wait. On se contente
                                // de relancer un essai si l'attente est en cours.
                                final status  = event["status"]?.toString()   ?? "";
                                final lobbyId = event["lobby_id"]?.toString() ?? "";
                                if (status == "accepted" && lobbyId.isNotEmpty && lobbyId == _joinLobbyId) {
                                    ActionRegistry.get("virtuallobby.stop_watching")?.call(null, null);
                                    final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    await _tryJoin(lobbyId, region);
                                }
    }

    // Admission du candidat, une fois le secret du clan publié par le chef. Appelée par l'attente
    // de join_wait (_tryJoin), jamais directement : c'est [pendingJoin] (users.pending_join) qui
    // porte l'invitation acceptée, et le code de la demande de l'enfant.
    //
    // Rend true quand l'attente est terminée (admis, ou refusé et renvoyé ailleurs), false quand
    // il faut continuer d'attendre (secret pas encore publié, écriture ratée).
    //
    // ⚠ SECRET ABSENT = ON ATTEND. On ne refuse plus, et le repli adulte qui écrivait steps.clan
    //   SANS clanId, puis envoyait à decisiontree, a disparu : il produisait un joueur ni dedans
    //   ni dehors.
    //
    // ⚠ L'ORDRE DES ÉCRITURES EST LA RÈGLE : users d'abord (pending_join vidé DANS LA MÊME
    //   écriture, pour qu'aucun cache périmé ne vienne le réécrire), puis userindexes, puis
    //   clans_players, et SEULEMENT ENSUITE la suppression du secret. Un plantage en route ne
    //   perd plus le secret : au redémarrage, l'attente reprend et le relit.
    Future<bool> _handleClanJoin(String groupId, String lobbyId, String region, Map pendingJoin) async {

                                // `var` : l'enfant qui reprend un joueur sans téléphone change d'identité
                                // de jeu en route (cf. _claimNoAccountPlayer).
                                var docId = _sessionDocId();
                                if (docId.isEmpty || lobbyId.isEmpty || region.isEmpty || _cloud == null) return false;

                                // 1. Le secret du clan, publié par le chef. Lu SANS être supprimé : il ne
                                //    l'est qu'une fois tout écrit (cf. l'ordre ci-dessus).
                                final lobby = ModuleRegistry.create("dvvirtuallobby");
                                if (lobby == null) return false;
                                Dvidle? secret;
                                try {
                                    secret = await (lobby as dynamic).readSecret(lobbyId) as Dvidle?;
                                } catch (e) {
                                    deva_log("error", "[worker] _handleClanJoin: lecture du secret FAILED: $e");
                                    return false;
                                }
                                final clanId     = secret?.get("clanId")?.toString()     ?? "";
                                final clanSecret = secret?.get("clanSecret")?.toString() ?? "";
                                final adminId    = secret?.get("adminId")?.toString()    ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) {
                                    deva_log("info", "[worker] _handleClanJoin: secret pas encore publié (lobbyId=$lobbyId), on attend");
                                    return false;
                                }
                                if (groupId.isNotEmpty && clanId != groupId) {
                                    deva_log("warning", "[worker] _handleClanJoin: secret d'un autre clan que l'invitation, ignoré");
                                    return false;
                                }

                                // Déclaration du chef, faite au moment d'ouvrir l'invitation. On la colle
                                // à la preuve d'acceptation des CGU de CE joueur : la CGU a été acceptée
                                // pendant l'inscription, donc bien avant d'arriver ici : dvdocuments
                                // complète la preuve existante (cf. documents.attach_ack).
                                // Best-effort : une déclaration qu'on n'a pas su coller ne doit pas
                                // empêcher une admission déjà acquise des deux côtés.
                                final ack = secret?.get("ack")?.toString() ?? "";

                                // MULTICLAN : déjà membre de ce clan (reprise après un plantage, autre
                                // appareil) → l'attente est finie ; plafond de 8 clans ; clan d'une autre
                                // région que la maison (pas encore possible : tout le client lit UNE région).
                                final before = await _readSession(region);
                                if (_isActiveMemberOf(before, clanId)) {
                                    deva_log("info", "[worker] _handleClanJoin: déjà membre de $clanId");
                                    await (lobby as dynamic).deleteSecret(lobbyId);
                                    await _leaveJoin(region, notice: "join_already_member");
                                    return true;
                                }
                                final homeRegion = await _homeRegion();
                                final refusalMc = _activeClans(before).length >= _kMaxClans ? "join_clans_cap"
                                    : (homeRegion.isNotEmpty && region != homeRegion) ? "clan_other_region" : "";
                                if (refusalMc.isNotEmpty) {
                                    deva_log("warning", "[worker] _handleClanJoin: $refusalMc");
                                    await (lobby as dynamic).deleteSecret(lobbyId);
                                    await _leaveJoin(region, notice: refusalMc);
                                    return true;
                                }
                                final hadClans = _activeClans(before).isNotEmpty;

                                // UN ENFANT N'ENTRE QU'AVEC UN ACCORD. Sans accord d'enfant joint, l'écran
                                // de déclaration du chef ne propose plus que « il s'agit d'un adulte » :
                                // un mineur qui scanne un tel QR code (celui du menu, affiché pour un
                                // adulte) entrerait sans que personne ait déclaré en être responsable.
                                // C'est ici, et seulement ici, que les deux bouts se rencontrent (l'état
                                // légal de l'entrant et la déclaration du chef), donc ici qu'on refuse,
                                // AVANT la moindre écriture au nom de l'enfant dans le clan. Et seulement
                                // quand le secret est là : avant, il n'y a rien à juger.
                                //
                                // DÉFENSE EN PROFONDEUR : la déclaration doit aussi répondre à SA demande.
                                // L'appareil a déjà comparé le code de l'invitation avant le login
                                // (on_invite_clan_link, on_confirm_pin) ; on compare ici celui que le
                                // chef a SCELLÉ avec sa déclaration, le seul qui ait voyagé avec le secret.
                                // Le code de l'enfant est relu dans pending_join, et non plus en mémoire :
                                // la comparaison tient donc aussi après un redémarrage. Pas de code = refus.
                                final legalRaw = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                _gateUsedAuth.clear();
                                if (_gameplayLegal(legalRaw) != "a") {
                                    final myCode  = pendingJoin["code"]?.toString() ?? "";
                                    String refusal = "";
                                    if (!_ackIsGuardian(ack)) {
                                        refusal = "invite_needs_child_ack";
                                    } else {
                                        final sealedCode = _ackAssentCode(ack);
                                        if (myCode.isEmpty || sealedCode != myCode) refusal = "kid_invite_not_mine";
                                    }
                                    // MULTICLAN (§ 5.2) : un mineur qui a DÉJÀ un clan n'entre que si l'un
                                    // de ses représentants a autorisé ce clan, ou si le chef qui l'accueille
                                    // est lui-même son représentant. Vérifié par l'app de l'enfant, dans sa
                                    // guardianship, AVANT toute écriture.
                                    if (refusal.isEmpty && hadClans) {
                                        refusal = await _guardianGate(docId, clanId, adminId, _gateUsedAuth);
                                    }
                                    if (refusal.isNotEmpty) {
                                        deva_log("warning", "[worker] _handleClanJoin: mineur, déclaration absente ou faite pour une autre demande ($refusal) → non admis");
                                        // Le secret ne lui était pas destiné : il ne reste pas en base.
                                        await (lobby as dynamic).deleteSecret(lobbyId);
                                        // Retour à SA question : c'est de là que repart une réponse que le
                                        // parent pourra accueillir, avec un code neuf. Le message s'affiche
                                        // sur l'écran de partage.
                                        await _leaveJoin(region, notice: refusal);
                                        return true;
                                    }
                                }

                                if (ack.isNotEmpty) {
                                    final r = await ActionRegistry.get("documents.attach_ack")?.call(null, ack);
                                    deva_log("info", "[worker] _handleClanJoin: attach_ack → ${r ?? 'action absente'}");
                                }

                                // L'ENFANT REPREND UN JOUEUR SANS TÉLÉPHONE, désigné par le parent (claim,
                                // cf. _openClaimOrConsent). Un mineur seulement : la reprise n'est proposée
                                // qu'avec un accord d'enfant, et la déclaration vient d'être vérifiée. À
                                // partir d'ici, l'identité de jeu est celle du joueur repris, et tout ce qui
                                // suit (users, userindexes, clans_players) s'écrit sous elle.
                                final claimId = _gameplayLegal(legalRaw) != "a"
                                    ? (secret?.get("claim")?.toString() ?? "")
                                    : "";
                                if (claimId.isNotEmpty) {
                                    final r = await _claimNoAccountPlayer(clanId, clanSecret, claimId, lobbyId, region);
                                    if (r == "retry") {
                                        _scheduleJoinRetry(lobbyId, region);
                                        return false;
                                    }
                                    if (r == "refused") {
                                        await (lobby as dynamic).deleteSecret(lobbyId);
                                        await _leaveJoin(region, notice: "kid_claim_gone");
                                        return true;
                                    }
                                    docId = claimId;
                                }
                                // L'ADULTE INVITÉ COMME CHEF (décision du chef, portée par le secret qu'il
                                // est seul à publier). Adulte seulement : c'est la garde d'âge de
                                // promote_chief, un mineur n'est jamais chef.
                                final asChief = _gameplayLegal(legalRaw) == "a" && secret?.get("as_chief") == true;

                                // 2. users, AVANT tout le reste, avec pending_join vidé dans la même
                                //    écriture. Un échec ici laisse tout en place (secret compris) : on
                                //    réessaie un peu plus tard, et au pire au prochain démarrage.
                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                // Clan d'origine à propager au doc membre (clans_players.original_clan) ; repli = ce clan.
                                String firstClan = clanId;
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
                                    // Effacement deep-merge : poser le champ à "" (convention dvcloud).
                                    existing.set("pending_join",                "");
                                    await _cloud?.write("workers", "users", docId, existing, region: region);
                                    _invalidateSessionCache();
                                } catch (e) {
                                    deva_log("error", "[worker] _handleClanJoin: users write FAILED: $e");
                                    _invalidateSessionCache();
                                    _scheduleJoinRetry(lobbyId, region);
                                    return false;
                                }
                                // Admis (ou adulte) : l'attente est finie, la demande a servi. Code, lien
                                // et invitation en attente sont oubliés ; un nouveau clan passerait par
                                // une nouvelle demande.
                                _stopJoinWatch();
                                _joinPendingMem = null;
                                await _forgetKidAssent();

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
                                    if (asChief) await _joinAsChief(clanId, clanSecret, region, docId);
                                    // AUDIT : l'entrée dans un clan (qui l'a fait entrer, par quelle voie).
                                    await _audit("clan_joined", {
                                        "playerId": docId, "clanId": clanId, "clan_name": clanName,
                                        "via": adminId, "legal": _gameplayLegal(legalRaw),
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
                                    if (_gameplayLegal(legalRaw) != "a") {
                                        final gSecret   = secret?.get("guardianSecret")?.toString() ?? "";
                                        final chiefName = secret?.get("adminName")?.toString() ?? "";
                                        final hasGship  = ((await _gshipSecrets())[docId] ?? "").isNotEmpty;
                                        if (!hasGship && gSecret.isNotEmpty) {
                                            await _gshipCreateOrigin(childId: docId, secret: gSecret, adminId: adminId,
                                                adminName: chiefName, clanId: clanId, clanName: clanName,
                                                region: region, lobbyId: lobbyId);
                                        } else if (hasGship) {
                                            await _gshipNoteEntry(docId, clanId, clanName, chiefName, region, adminId,
                                                _gateUsedAuth.isNotEmpty);
                                        }
                                    }
                                } catch (e) {
                                    deva_log("error", "[worker] _handleClanJoin: clans_players update FAILED: $e");
                                }

                                // 4. Tout est écrit : le secret a servi, il quitte la base. Un échec n'est
                                //    pas grave, le TTL du lobby finira le ménage.
                                await (lobby as dynamic).deleteSecret(lobbyId);

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
                                        deva_log("error", "[worker] _handleClanJoin: notif nouveau membre FAILED: $e");
                                    }
                                    // Journal : un utilisateur a rejoint le clan (adminId = accepteur, via lobby).
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
                                // Invité comme chef : la bienvenue le lui dit (une seule animation, pas une
                                // bienvenue suivie d'une promotion).
                                await deva_set("worker.pending_clan_welcome", asChief ? "joined_chief" : "joined");
                                // Le candidat attend sur join_wait depuis le 2026-09-22 : la navigation vers
                                // le dashboard ci-dessous produit un `appear` qui consomme le drapeau. Le
                                // cas « déjà sur le dashboard » (ancien flux, où l'on y atterrissait dès la
                                // soumission) reste traité : la bienvenue est jouée ici même, et le tutoriel
                                // s'ouvrira derrière la fin de l'animation (on_celebration_end), comme partout.
                                //
                                // Nom pas encore saisi : c'est le cas de TOUT nouveau venu depuis que le
                                // mineur se connecte avant d'entrer (il n'y a plus d'admission anonyme, donc
                                // plus d'écran de liaison après elle). Le nom passe avant tout le reste. La
                                // cérémonie de bienvenue n'est PAS jouée ici : son drapeau reste armé et
                                // on_dashboard_appear la jouera à l'arrivée, après le nom, dans son contexte
                                // et avec le tutoriel derrière. La déclencher maintenant la ferait couper net
                                // par la navigation.
                                if (region.isNotEmpty && (await _readSession(region))?.get("steps.name") == null) {
                                    DvOrb.navigate_reset("player_name_screen");
                                    return true;
                                }
                                if (DvOrb.get_current_page()?.dvid == "dashboard") {
                                    await _playPendingClanWelcome();
                                } else {
                                    // Depuis join_wait : route `default` → dashboard (steps.yml).
                                    await ActionRegistry.get("steps.navigate")?.call(null, null);
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
    // ⚠ L'ORDRE PERMET LA REPRISE APRÈS PLANTAGE. Le joueur est marqué repris (claim_lobby) en
    //   premier : rejouée avec la même invitation, la reprise se reconnaît et continue, alors
    //   qu'une autre invitation est refusée. users/{claimId} est écrit avant que l'index n'y
    //   pointe, et l'ancien doc reçoit first_clan avant l'index : s'il survivait à un plantage,
    //   le balayage des comptes jamais admis (pulse_sweeper, piste orphans) ne le prendrait pas
    //   pour un orphelin, ce qui effacerait l'index et le compte de l'enfant avec lui.
    Future<String> _claimNoAccountPlayer(String clanId, String clanSecret, String claimId,
                                         String lobbyId, String region) async {

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

                                // 2. Le joueur : encore sans téléphone, ou déjà repris par CETTE invitation.
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
                                        && player.get("claim_lobby")?.toString() != lobbyId)) {
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
                                    mark.set("claim_lobby", lobbyId);
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

    //-----------------------------------------------------------------------
    //-- Adhésion en attente (écran join_wait) ------------------------------
    //-----------------------------------------------------------------------
    //
    // Le candidat (enfant ou adulte) s'est connecté et a accepté l'invitation : c'est au chef de
    // publier le secret du clan, et son application peut être fermée. L'attente vit donc EN BASE,
    // dans `users.pending_join` : {group_id, lobby_id, kind, code, region, accepted_at,
    // expires_at}. Le joueur peut fermer le jeu : on_login le ramène sur join_wait, et
    // l'attente reprend où elle en était.
    //
    // ⚠ "" OU AUTRE CHOSE QU'UNE MAP = PAS D'ATTENTE, partout. Vider un champ en deep merge,
    //   c'est le poser à "" (convention dvcloud) : un pending_join vidé reste présent, en chaîne.
    //
    // ⚠ PAS D'ÉCRITURE AVANT LE LOGIN. pending_join n'est posé que sous le compte définitif,
    //   après l'acceptation (_acceptAndWait). Avant, l'invitation attend en mémoire, comme
    //   toujours.

    // Le pending_join d'une session, ou null s'il est absent, vidé ("") ou incomplet.
    Map<String, dynamic>? _pendingJoinOf(Dvidle? session) {

                                final raw = session?.get("pending_join");
                                dynamic m;
                                if (raw is Dvidle) {
                                    m = raw.toJson();
                                } else if (raw is Map) {
                                    m = raw;
                                }
                                if (m is! Map) return null;
                                final out = <String, dynamic>{};
                                m.forEach((k, v) => out[k.toString()] = v);
                                if ((out["group_id"]?.toString() ?? "").isEmpty) return null;
                                if ((out["lobby_id"]?.toString() ?? "").isEmpty) return null;
                                return out;
    }

    // Une attente sans date lisible est tenue pour expirée : on ne garde pas un joueur devant
    // un écran d'attente sans savoir jusqu'à quand.
    bool _pendingJoinExpired(Map pj) {

                                final exp = DateTime.tryParse(pj["expires_at"]?.toString() ?? "");
                                return exp == null || DateTime.now().toUtc().isAfter(exp.toUtc());
    }

    // Durée de vie d'une invitation, la même que celle du lobby (screens_meta.yml,
    // virtuallobby.ttl_hours).
    Future<int> _inviteTtlHours() async {

                                final n = int.tryParse((await deva_get("virtuallobby.ttl_hours"))?.toString() ?? "") ?? 72;
                                return n > 0 ? n : 72;
    }

    // Accepte l'invitation SOUS LE COMPTE DÉFINITIF, inscrit l'attente en base, puis mène à
    // join_wait. Commun à tous les chemins d'un candidat connecté : invitation gardée en mémoire
    // avant le login (_consumePendingInvite), QR code ou lien reçu déjà connecté
    // (on_invite_clan_link), code saisi (on_confirm_pin), écran accept_invitation_clan.
    //
    // ⚠ ON ATTEND LA FIN DE accept_invitation, et l'on se fie à ce qu'elle rend, pas à
    //   on_accepted : une invitation déjà acceptée (second passage, reprise) ne tire rien.
    //
    // [kind] "child" / "adult". [code] : pour un enfant, le code de SA demande, déjà comparé à
    // celui de l'invitation par l'appelant. Il est rangé dans pending_join parce que le code en
    // mémoire (_kidAssentCode) meurt avec le processus : sans lui, un enfant qui ferme le jeu
    // pendant l'attente serait refusé à l'admission.
    //
    // Une invitation qui ne peut pas être acceptée (expirée, annulée, déjà servie) renvoie le
    // joueur vers sa demande (enfant) ou le choix du clan (adulte), avec le message
    // `join_expired` : demander une nouvelle invitation est la seule issue.
    // Rend true si elle a navigué (join_wait, ou sortie avec message).
    Future<bool> _acceptAndWait(String groupId, String lobbyId, String kind, String code) async {

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                final docId  = _sessionDocId();
                                if (groupId.isEmpty || lobbyId.isEmpty || region.isEmpty || docId.isEmpty || _anon || _cloud == null) {
                                    deva_log("error", "[worker] _acceptAndWait: contexte incomplet (region=$region docId=${docId.isNotEmpty} anon=$_anon)");
                                    return false;
                                }
                                var ok = false;
                                final lobby = ModuleRegistry.create("dvvirtuallobby");
                                try {
                                    if (lobby != null) ok = (await (lobby as dynamic).acceptInvitation(lobbyId, groupId)) == true;
                                } catch (e) {
                                    deva_log("error", "[worker] _acceptAndWait: accept_invitation FAILED: $e");
                                }
                                if (!ok) {
                                    deva_log("warning", "[worker] _acceptAndWait: invitation non acceptée (expirée, annulée ou déjà servie)");
                                    await _leaveJoin(region, notice: "join_expired");
                                    return true;
                                }

                                // Échéance : celle du record de lobby, qui disparaît avec son TTL (le chef
                                // ne pourrait plus publier après), bornée par la durée d'une invitation.
                                final now     = DateTime.now().toUtc();
                                var   expires = now.add(Duration(hours: await _inviteTtlHours()));
                                try {
                                    final rec    = await _cloud?.read("virtuallobby", "virtuallobbymanagement/$groupId/records", lobbyId);
                                    final raw    = rec?.get("expiration");
                                    final recExp = raw is DateTime ? raw : DateTime.tryParse(raw?.toString() ?? "");
                                    if (recExp != null && recExp.toUtc().isBefore(expires)) expires = recExp.toUtc();
                                } catch (_) {}

                                final pj = <String, dynamic>{
                                    "group_id":    groupId,
                                    "lobby_id":    lobbyId,
                                    "kind":        kind == "child" ? "child" : "adult",
                                    "code":        code,
                                    "region":      region,
                                    "accepted_at": now.toIso8601String(),
                                    "expires_at":  expires.toIso8601String(),
                                };
                                // Gardée aussi en mémoire : si l'écriture échoue, l'attente tient au
                                // moins jusqu'à la fermeture du jeu.
                                _joinPendingMem = pj;
                                try {
                                    await _cloud?.write("workers", "users", docId, Dvidle({"pending_join": pj}), region: region);
                                } catch (e) {
                                    deva_log("error", "[worker] _acceptAndWait: pending_join non écrit ($e), attente en mémoire seulement");
                                }
                                _invalidateSessionCache();
                                deva_log("info", "[worker] _acceptAndWait: invitation acceptée, attente du chef (lobbyId=$lobbyId kind=$kind)");
                                DvOrb.navigate_reset("join_wait");
                                return true;
    }

    // Fin d'une attente sans admission : « J'abandonne », invitation expirée, refus d'un mineur.
    // pending_join est vidé, la demande de l'enfant oubliée, et chacun repart d'où l'on repart :
    // l'enfant de sa question (kid_assent_screen, le message l'attend sur l'écran de partage),
    // l'adulte du choix du clan (new_or_pick_clan, le message s'y affiche), ou de son nom s'il
    // ne l'a pas encore donné. Rien à faire côté lobby : son TTL fait le ménage.
    Future<void> _leaveJoin(String region, {String notice = ""}) async {

                                _stopJoinWatch();
                                _joinPendingMem = null;
                                final docId = _sessionDocId();
                                if (region.isNotEmpty && docId.isNotEmpty) {
                                    try {
                                        await _cloud?.write("workers", "users", docId, Dvidle({"pending_join": ""}), region: region);
                                    } catch (e) {
                                        deva_log("error", "[worker] _leaveJoin: pending_join non vidé ($e)");
                                    }
                                    _invalidateSessionCache();
                                }
                                await _forgetKidAssent();
                                // MULTICLAN : le joueur a déjà un clan (il en demandait un autre) → retour à
                                // son clan, le message sur l'écran « Mes clans ».
                                Dvidle? mine;
                                try { mine = region.isNotEmpty ? await _readSession(region) : null; } catch (_) {}
                                if (_activeClans(mine).isNotEmpty) {
                                    _joinNotice = notice;
                                    DvOrb.navigate_reset("dashboard");
                                    return;
                                }
                                final legalRaw = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                if (_gameplayLegal(legalRaw) != "a") {
                                    _kidAssentNotice = notice;
                                    DvOrb.navigate_reset("kid_assent_screen");
                                    return;
                                }
                                _joinNotice = notice;
                                Dvidle? session;
                                try { session = region.isNotEmpty ? await _readSession(region) : null; } catch (_) {}
                                DvOrb.navigate_reset(session != null && session.get("steps.name") == null
                                    ? "player_name_screen" : "new_or_pick_clan");
    }

    // Arme l'attente du secret : lecture immédiate (le secret a pu être publié pendant que le
    // jeu était fermé, et une vigilance ne notifie jamais ce qui était là avant elle), puis
    // vigilance du document virtuallobbysecret/{lobbyId}, sur le modèle de
    // _startValidationPolling. Et une minuterie sur l'échéance : aucune écriture ne viendra
    // dire que l'invitation a expiré.
    void _startJoinWatch(Map pj, String region) {

                                final lobbyId = pj["lobby_id"]?.toString() ?? "";
                                if (lobbyId.isEmpty) return;
                                // Déjà armée pour cette invitation (appear rejoué) : rien à refaire.
                                if (_joinLobbyId == lobbyId && _joinExpiryTimer != null) return;
                                _stopJoinWatch();
                                _joinLobbyId = lobbyId;

                                final left = DateTime.tryParse(pj["expires_at"]?.toString() ?? "")?.toUtc()
                                    .difference(DateTime.now().toUtc());
                                if (left == null || left.isNegative) {
                                    _leaveJoin(region, notice: "join_expired");
                                    return;
                                }
                                _joinExpiryTimer = Timer(left + const Duration(seconds: 1), () {
                                    if (_joinLobbyId != lobbyId) return;
                                    deva_log("info", "[worker] join_wait : invitation expirée pendant l'attente");
                                    _leaveJoin(region, notice: "join_expired");
                                });

                                deva_log("info", "[worker] join_wait : attente du secret (lobbyId=$lobbyId)");
                                _tryJoin(lobbyId, region).then((done) {
                                    if (done || _joinLobbyId != lobbyId || _joinVigilance != null) return;
                                    _joinVigilance = _cloud?.watch("virtuallobby", "virtuallobbysecret", lobbyId,
                                        (doc, reason) {
                                            if (reason != DvWatchReason.changed || doc == null) return;
                                            _tryJoin(lobbyId, region);
                                        },
                                        // desktop only ; ignoré sur Android. Plafond : un chef qui rouvre
                                        // son jeu des heures plus tard ne doit pas attendre une minute de plus.
                                        strategy: DvWatchStrategy.fibonacci(baseMs: 2000, maxMs: 15000));
                                });
    }

    void _stopJoinWatch() {

                                _joinVigilance?.stop();
                                _joinVigilance = null;
                                _joinExpiryTimer?.cancel();
                                _joinExpiryTimer = null;
                                _joinRetryTimer?.cancel();
                                _joinRetryTimer = null;
                                _joinLobbyId = "";
    }

    // Nouvel essai après une écriture ratée de l'admission : le secret, lui, ne changera plus,
    // la vigilance ne se redéclenchera donc pas d'elle-même.
    void _scheduleJoinRetry(String lobbyId, String region) {

                                _joinRetryTimer?.cancel();
                                _joinRetryTimer = Timer(const Duration(seconds: 15), () {
                                    if (_joinLobbyId == lobbyId) _tryJoin(lobbyId, region);
                                });
    }

    // Un essai d'admission. Rend true quand l'attente est terminée. Garde de ré-entrance : la
    // lecture initiale, la vigilance et un nouvel essai peuvent tomber ensemble.
    Future<bool> _tryJoin(String lobbyId, String region) async {

                                if (_joinInFlight) return false;
                                _joinInFlight = true;
                                try {
                                    final session = await _readSession(region);
                                    // Déjà admis (reprise après un plantage entre deux écritures, autre appareil).
                                    // MULTICLAN : admis dans CE clan, et non « a un clan ».
                                    final pjNow = _pendingJoinOf(session) ?? _joinPendingMem;
                                    if (pjNow == null && (session?.get("steps.clan.clanId")?.toString() ?? "").isNotEmpty
                                        || _isActiveMemberOf(session, pjNow?["group_id"]?.toString() ?? "")) {
                                        _stopJoinWatch();
                                        _joinPendingMem = null;
                                        if (DvOrb.get_current_page()?.dvid == "join_wait") {
                                            DvOrb.navigate_reset(session?.get("steps.name") == null ? "player_name_screen" : "dashboard");
                                        }
                                        return true;
                                    }
                                    final pj = _pendingJoinOf(session) ?? _joinPendingMem;
                                    if (pj == null || pj["lobby_id"]?.toString() != lobbyId) {
                                        // Attente abandonnée ou remplacée ailleurs : cette vigilance n'a plus d'objet.
                                        deva_log("info", "[worker] _tryJoin: plus d'attente pour lobbyId=$lobbyId");
                                        _stopJoinWatch();
                                        return true;
                                    }
                                    return await _handleClanJoin(pj["group_id"]?.toString() ?? "", lobbyId, region, pj);
                                } catch (e) {
                                    deva_log("error", "[worker] _tryJoin FAILED: $e");
                                    return false;
                                } finally {
                                    _joinInFlight = false;
                                }
    }

    // ⚠ `dynamic caller` : l'appear d'une PAGE passe un DvPage, qui n'est pas une shape.
    Future<void> on_join_wait_appear(dynamic caller, dynamic event) async {

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                Dvidle? session;
                                try {
                                    session = region.isNotEmpty ? await _readSession(region) : null;
                                } catch (e) {
                                    deva_log("error", "[worker] on_join_wait_appear: lecture session FAILED: $e");
                                }
                                if ((session?.get("steps.clan.clanId")?.toString() ?? "").isNotEmpty) {
                                    _stopJoinWatch();
                                    DvOrb.navigate_reset(session?.get("steps.name") == null ? "player_name_screen" : "dashboard");
                                    return;
                                }
                                final pj = _pendingJoinOf(session) ?? _joinPendingMem;
                                if (pj == null) {
                                    // Session illisible (réseau) : on reste, « J'abandonne » est là. Session
                                    // lue sans attente : rien à faire ici.
                                    if (session != null) await _leaveJoin(region);
                                    return;
                                }
                                if (_pendingJoinExpired(pj)) {
                                    await _leaveJoin(region, notice: "join_expired");
                                    return;
                                }
                                _startJoinWatch(pj, region);
    }

    // « J'abandonne » : l'attente est vidée, la demande de l'enfant oubliée.
    Future<void> on_join_wait_giveup(DvShape? caller, dynamic event) async {

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                deva_log("info", "[worker] join_wait : le candidat abandonne l'attente");
                                await _leaveJoin(region);
    }

    // Message d'une attente abandonnée ou expirée, côté adulte (l'enfant a le sien sur
    // kid_assent_share). Consommé à l'affichage : il ne se montre qu'une fois.
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

    // L'adulte invité comme chef s'inscrit lui-même dans clans.admins, dès son admission : la
    // décision est celle du chef qui l'a invité, portée par le secret que lui seul publie
    // (cf. _publishInvite). Mêmes écritures que promote_chief : la liste des chefs (source
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
                // Le doc vient d'être réécrit : la valeur mémorisée pour le badge de combat peut
                // dater d'avant (repli sur la conf pris avant l'initialisation du champ). On la
                // jette plutôt que de la deviner — la prochaine ouverture de combat relira.
                _maxXpCache.remove(userId);
            } catch (e) {
                deva_log("error", "[worker] _writeClanPlayer: FAILED: $e");
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

    // --- Écran de consentement du chef au recrutement (invite_consent_screen) -----------------
    //
    // ⚠ UN ECRAN, ET NON PLUS UN OVERLAY. C'etait un voile noir a 80 % pose sur clan_page, et
    //   l'idiome maison — jamais de fenetre modale — n'imposait pas cela : il proscrit la MODALE,
    //   pas la page. Sous le voile, le roster, le coffre et la banniere de recrutement restaient
    //   visibles : trois plans de lecture superposes pour un acte qui engage la responsabilite
    //   legale du chef. Une declaration se lit sur un fond qui ne bouge pas.
    //
    // La remise a neuf des cases n'a plus sa place ici : elle est passee a l'`appear` de l'ecran
    // (on_invite_consent_appear), le seul moment ou les shapes existent a coup sur.
    Future<void> _openInviteConsent() async {

                                DvOrb.navigate_new("invite_consent_screen");
    }

    // L'ecran vient de s'afficher : on repose la question A NEUF. Les cases sont reconstruites
    // depuis la conf (donc decochees) par show_ack, et le bouton repart eteint avec elles — une
    // declaration faite pour l'invitation precedente ne vaut pas pour celle-ci.
    //
    // ⚠ `dynamic caller` ET NON `DvShape?` : l'appear d'une PAGE passe un DvPage, qui n'est pas
    //   une shape. Un handler type DvShape? leve un NoSuchMethodError silencieux (vecu le
    //   2026-09-14 sur dix handlers d'onboarding).
    //
    // DEUX MODES, choisis par la présence d'un accord d'enfant (_pendingAssent) :
    //   * avec accord : le panneau de tête montre ce que l'enfant a accepté, quand, et le texte
    //     qui lui a été montré ; les cases sont celles de l'acquittement `guardian`, réduit aux
    //     deux cas « enfant » ; le chef choisit ensuite QR code ou invitation à distance ;
    //   * sans accord : l'acquittement `adult`, qui ne porte que « il s'agit d'un adulte », et
    //     le panneau de tête dit comment faire entrer un enfant.
    //
    // ⚠ DEUX ACQUITTEMENTS EN CONF, ET NON UN FILTRE ICI. documents.show_ack pousse toutes les
    //   options d'un acquittement, sans tri possible. Scinder la conf (screens_meta.yml) garde
    //   le module ignorant de ddust et rend la règle lisible là où sont les cases.
    Future<void> on_invite_consent_appear(dynamic caller, dynamic event) async {

                                final assent = _pendingAssent;
                                await ActionRegistry.get("documents.show_ack")?.call(null, assent != null ? "guardian" : "adult");
                                _setInviteYesReady(false);

                                final head = await DvOrb.wait_for_shape("invite_consent_screen/assent");
                                if (head != null) {
                                    String text;
                                    if (assent != null) {
                                        final d    = DateTime.tryParse(assent["date"]?.toString() ?? "")?.toLocal();
                                        final when = d == null ? "" :
                                            "${_storeShortDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
                                        // Le texte est rendu dans la langue du CHEF, qui doit le comprendre ;
                                        // celle dans laquelle l'enfant l'a lu voyage dans l'accord (`lang`).
                                        final shown = TranslationRegistry.processLabel("@@@T:${assent["text_key"]}@@@");
                                        // Le code de la demande en tête : le chef le compare à celui que
                                        // l'enfant affiche en grand. C'est lui que l'invitation portera.
                                        text = TranslationRegistry.processLabel("@@@T:invite_consent_assent_code@@@")
                                                .replaceAll("{code}", assent["n"]?.toString() ?? "")
                                            + "\n\n"
                                            + TranslationRegistry.processLabel("@@@T:invite_consent_assent@@@")
                                                .replaceAll("{date}", when)
                                                .replaceAll("{text}", shown);
                                        // Le joueur qu'il reprendra, choisi juste avant : relu ici, sous les
                                        // yeux du parent, avant qu'il ne signe.
                                        if (_pendingClaimId.isNotEmpty) {
                                            text += "\n\n" + TranslationRegistry.processLabel("@@@T:invite_consent_claim@@@")
                                                .replaceAll("{name}", _pendingClaimName);
                                        }
                                    } else {
                                        text = TranslationRegistry.processLabel(_assentRejected
                                            ? "@@@T:invite_consent_not_assent@@@"
                                            : "@@@T:invite_consent_child_hint@@@");
                                    }
                                    head.set("shape.label", text);
                                    if (head is DvLabel) await head.computeDisplay();
                                    head.refreshUI();
                                }

                                // Le choix QR / à distance n'a de sens qu'en mode enfant : ailleurs, c'est
                                // l'option du menu qui l'a déjà fait.
                                if (assent != null) {
                                    final kind = (await deva_get("worker.pending_invite_kind"))?.toString() ?? "qr";
                                    await _revealLabel("invite_consent_screen/kind",
                                        kind == "pin" ? "invite_consent_kind_pin" : "invite_consent_kind_qr");
                                } else {
                                    _hideShapes(["invite_consent_screen/kind"]);
                                }
                                // Même emplacement, l'autre mode : en mode adulte, le chef peut faire de
                                // l'invité un chef dès son arrivée. Repart à « simple membre » à chaque
                                // ouverture : une décision prise pour l'invitation précédente ne vaut pas.
                                _inviteAsChief = false;
                                if (assent == null) {
                                    await _revealLabel("invite_consent_screen/chief", "invite_consent_chief_no");
                                } else {
                                    _hideShapes(["invite_consent_screen/chief"]);
                                }
    }

    // Opacités du bouton « Invitons ! ». Deux valeurs et pas de mémoire : l'extension ne peut
    // pas porter de champ, et relire l'opacité courante de la shape prendrait le bouton grisé
    // pour la référence du bouton allumé dès la deuxième ouverture de l'overlay.
    static const double _inviteYesOn  = 1.0;
    static const double _inviteYesOff = 0.25;

    // Bouton éteint ET sourd : `shape.events.tap` coupe le tap (idiome ddust d'un bouton hors
    // service, cf. on_kid_wants_clan_appear), l'opacité dit pourquoi. Les deux vont ensemble —
    // grisé sans être sourd, il laisserait passer un tap ; sourd sans être grisé, il
    // n'expliquerait rien.
    // ⚠ On ne le CACHE pas : un bouton éteint qui reste là dit qu'il manque quelque chose, un
    //   bouton disparu laisse croire que l'écran est cassé.
    //
    // Appelee depuis l'`appear` de l'ecran ET a chaque changement de case : la shape peut donc
    // ne pas encore exister au tout premier passage, d'ou le `?..` qui ne leve pas.
    void _setInviteYesReady(bool ready) {

                                DvOrb.get_shape_by_id("invite_consent_screen/yes")
                                    ?..set("shape.opacity", ready ? _inviteYesOn : _inviteYesOff)
                                    ..set("shape.events.tap", ready)
                                    ..refreshUI();
    }

    // Le chef vient de cocher (ou décocher) l'un des trois cas.
    Future<void> on_invite_ack_changed(DvShape? caller, dynamic event) async {

                                final fn = ActionRegistry.get("documents.ack_ready");
                                final ready = fn == null
                                    ? true
                                    : (await fn(null, null))?.toString() == "true";
                                _setInviteYesReady(ready);
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
                                // Entrée « adulte » : aucun accord d'enfant ne doit traîner d'un scan
                                // précédent resté sans suite, il ouvrirait les cas « enfant ».
                                _pendingAssent    = null;
                                _assentRejected   = false;
                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _inviteAsChief    = false;
                                await deva_set("worker.pending_invite_kind", "qr");
                                await _openInviteConsent();
    }

    // Contrôles communs aux deux modes de recrutement (QR et invitation à distance) : le clan doit
    // être connu de la session et l'appelant doit en être chef. Rend le clanId, ou "" si refusé.
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

    // Le chef a lu la mention et confirmé sa responsabilité : on crée enfin le lobby. Le mode
    // mémorisé décide de la suite — invite_mode=pin fait bifurquer on_management_created vers
    // l'écran PIN + partage au lieu du QR.
    Future<void> on_confirm_invite_consent(DvShape? caller, dynamic event) async {

                                // Le chef n'a pas dit DE QUI il s'agit : on ne bouge pas. Le bouton est
                                // déjà sourd, cette garde est celle qui va avec.
                                // ⚠ On interroge `ack_ready` et NON le scellé : une conf sans
                                //   acquittement déclaré rend un scellé vide sans que rien ne manque,
                                //   et bloquer là-dessus casserait le recrutement de toute application
                                //   qui ne se sert pas du mécanisme.
                                final readyFn = ActionRegistry.get("documents.ack_ready");
                                if (readyFn != null && (await readyFn(null, null))?.toString() != "true") {
                                    deva_log("info", "[worker] on_confirm_invite_consent: aucune déclaration cochée");
                                    return;
                                }
                                // Voyage avec l'invitation jusqu'à la preuve d'acceptation de l'entrant
                                // (cf. _writeClanInvite, puis _publishInvite → publishSecret).
                                //
                                // Avec un accord d'enfant, le scellé l'EMPORTE : la déclaration du parent et
                                // la volonté de l'enfant qui l'a précédée ne se séparent plus, ni dans le
                                // dossier de l'enfant (attach_ack), ni dans celui du parent (ci-dessous).
                                final assent = _pendingAssent;
                                final sealed = (await ActionRegistry.get("documents.seal_ack")?.call(null,
                                    assent != null
                                        ? <String, dynamic>{"id": "guardian", "assent": assent}
                                        : "adult"))?.toString() ?? "";
                                // Un accord d'enfant sans scellé ne ferait entrer personne : l'appareil de
                                // l'enfant refuse une invitation sans déclaration de responsable.
                                if (assent != null && sealed.isEmpty) {
                                    deva_log("error", "[worker] on_confirm_invite_consent: scellé vide malgré l'accord d'enfant");
                                    return;
                                }
                                if (assent != null) {
                                    // La décision du parent, enregistrée SOUS SON PROPRE COMPTE : c'est lui
                                    // qui décide, c'est donc à son nom que la preuve doit exister, que
                                    // l'enfant entre un jour dans le clan ou non.
                                    // ⚠ Un échec ARRÊTE l'invitation : sans cette trace, le parent aurait
                                    //   autorisé sans que rien, de son côté, ne le prouve. Le bouton reste
                                    //   là, il suffit de réessayer. (Une action absente, build sans le
                                    //   module à jour, ne bloque pas : elle est journalisée.)
                                    final fn = ActionRegistry.get("documents.record_guardian_decision");
                                    if (fn == null) {
                                        deva_log("warning", "[worker] documents.record_guardian_decision absente : décision non enregistrée côté parent");
                                    } else {
                                        dynamic r = fn(null, sealed);
                                        if (r is Future) r = await r;
                                        if (r == false || r?.toString() == "error" || r?.toString() == "false") {
                                            deva_log("error", "[worker] on_confirm_invite_consent: décision du parent non enregistrée ($r)");
                                            return;
                                        }
                                    }
                                }
                                // ⚠ PLUS DE `worker.pending_ack` (2026-09-22) : la déclaration part dans
                                //   l'invitation privée de CE lobby (_writeClanInvite, plus bas), où la
                                //   publication la relira. Un emplacement unique la laissait écraser par
                                //   l'invitation suivante, et finissait sur le disque au premier store().
                                // Consommé : un accord ne sert qu'à UNE invitation. Il ne reste en mémoire
                                // que pour l'invitation à distance, dont la charge le porte aussi
                                // (on_management_created).
                                // Le joueur sans téléphone repris, s'il y en a un : seulement avec un accord
                                // d'enfant (le choix n'est proposé que là), consommé comme lui.
                                final claim = assent != null ? _pendingClaimId : "";
                                // L'invité sera aussi chef : en mode adulte seulement, consommé de même.
                                final asChief = assent == null && _inviteAsChief;
                                _inviteAsChief = false;
                                _pendingAssent    = null;
                                _assentRejected   = false;
                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _inviteAssent     = assent;

                                // On quitte l'ecran AVANT de creer le lobby : `create_management`
                                // enchaine sur l'ecran QR (ou PIN), et il doit se poser sur
                                // clan_page, pas par-dessus une declaration deja signee. Les deux
                                // operations sont synchrones sur le meme Navigator : le pop est
                                // acquis quand le push part.
                                DvOrb.navigate_back();
                                final kind = (await deva_get("worker.pending_invite_kind"))?.toString() ?? "qr";
                                await deva_set("worker.pending_invite_kind", "");
                                // Le clan est relu ici et pas conservé depuis la garde : entre le tap sur
                                // l'option et la confirmation, rien ne garantit que la session n'a pas bougé.
                                final groupId = await _clanIdIfChief("on_confirm_invite_consent");
                                if (groupId.isEmpty) {
                                    _inviteAssent = null;
                                    return;
                                }
                                // Le lobbyId est tiré ICI, et non par dvvirtuallobby : l'invitation
                                // privée doit exister AVANT le lobby qu'elle autorise. Sans elle, un
                                // candidat accepterait un lobby qu'aucune publication ne servirait
                                // jamais. Un échec d'écriture arrête donc l'invitation.
                                final lobbyId = _generateUuid();
                                // MULTICLAN : invitation d'un enfant → secret de représentation, rangé en
                                // attente dans l'index du parent jusqu'à ce que l'enfant apparaisse.
                                final guardianSecret = assent != null ? await _newGuardianPending(lobbyId, groupId) : "";
                                if (!await _writeClanInvite(groupId, lobbyId, sealed, assent != null ? "child" : "adult",
                                        claim: claim, asChief: asChief, guardianSecret: guardianSecret)) {
                                    _inviteAssent = null;
                                    return;
                                }
                                if (kind == "pin") await deva_set("worker.invite_mode", "pin");
                                await _stampFirstInvite(groupId);
                                await ActionRegistry.get("virtuallobby.create_management")?.call(null, {"group_id": groupId, "lobby_id": lobbyId});
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

    Future<void> on_cancel_invite_consent(DvShape? caller, dynamic event) async {

                                // L'accord de l'enfant n'a pas servi : il est oublié. L'enfant pourra
                                // le montrer de nouveau, il est toujours affiché sur son téléphone.
                                _pendingAssent    = null;
                                _assentRejected   = false;
                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _inviteAsChief    = false;
                                await deva_set("worker.pending_invite_kind", "");
                                DvOrb.navigate_back();
    }

    // Invitation à distance : même chemin que le QR (consentement puis create_management), mais le
    // flag invite_mode=pin — posé par on_confirm_invite_consent — fait bifurquer
    // on_management_created vers l'écran PIN + partage réseaux sociaux au lieu du QR.
    // Réservé au chef, comme le QR (double garde avec clan_settings_selector).
    Future<void> on_invite_clan_remote(DvShape? caller, dynamic event) async {

                                if ((await _clanIdIfChief("on_invite_clan_remote")).isEmpty) return;
                                // Entrée « adulte », comme on_invite_clan.
                                _pendingAssent    = null;
                                _assentRejected   = false;
                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _inviteAsChief    = false;
                                await deva_set("worker.pending_invite_kind", "pin");
                                await _openInviteConsent();
    }

    Future<void> on_management_created(DvShape? caller, Map event) async {

                                final groupId = event["group_id"]?.toString() ?? "";
                                final lobbyId = event["lobby_id"]?.toString() ?? "";
                                if (groupId.isEmpty || lobbyId.isEmpty) return;

                                deva_log("info", "[worker] on_management_created: groupId=$groupId lobbyId=$lobbyId");

                                // ⚠ L'INVITATION SORTANTE RESTE EN MÉMOIRE (cf. _outgoingGroupId). Écrite
                                //   dans `worker.pending_group_id`, elle ressemblait, au lancement suivant,
                                //   à une invitation reçue : _consumePendingInvite la rejouait et le chef
                                //   postulait dans son propre lobby.
                                _outgoingGroupId = groupId;
                                _outgoingLobbyId = lobbyId;

                                // La région voyage avec l'invitation : le clan n'existe que dans la sienne,
                                // et celui qui la reçoit doit pouvoir le savoir avant de tenter d'entrer.
                                // Lue par le QR code ci-dessous et par le partage (on_share_clan_invite).
                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                _outgoingRegion = region;

                                ActionRegistry.get("virtuallobby.watch_management")?.call(null, {"group_id": groupId, "lobby_id": lobbyId});
                                deva_log("info", "[worker] watch_management démarré");

                                // Mode « à distance » : sceau chiffré par PIN, écran PIN + partage (pas de QR).
                                final mode = (await deva_get("worker.invite_mode"))?.toString() ?? "";
                                // L'accord de l'enfant ne sert qu'à CETTE invitation : consommé ici, quel que
                                // soit le mode.
                                final assent = _inviteAssent;
                                _inviteAssent = null;
                                // L'INVITATION EST TYPÉE. « enfant » quand elle répond à un accord, avec
                                // le code de cet accord ; « adulte » sinon. L'appareil de l'enfant refuse
                                // une invitation « adulte », et une invitation « enfant » qui ne porte
                                // pas le code de SA demande ; celui d'un adulte refuse une invitation
                                // « enfant ». Sans `k` (version antérieure), l'invitation vaut « adulte ».
                                final code = assent?["n"]?.toString() ?? "";
                                final kind = assent != null ? "child" : "adult";
                                _inviteLinkParams = kind == "child"
                                    ? "&k=child&n=${Uri.encodeQueryComponent(code)}"
                                    : "&k=adult";
                                if (mode == "pin") {
                                    await deva_set("worker.invite_mode", "");
                                    final lobby = ModuleRegistry.create("dvvirtuallobby");
                                    if (lobby == null) return;
                                    final pin   = (lobby as dynamic).generatePin() as String? ?? "";
                                    // La charge est libre (sealInvite) : elle porte aussi l'accord, pour que
                                    // l'invitation dise d'elle-même à quelle réponse d'enfant elle répond.
                                    // `k` et `n` à plat dans la charge : l'appareil de l'enfant les lit
                                    // une fois le code PIN saisi (on_confirm_pin), avant toute connexion.
                                    final token = (lobby as dynamic).sealInvite(<String, dynamic>{
                                        "group_id": groupId,
                                        "lobby_id": lobbyId,
                                        "region":   region,
                                        "k":        kind,
                                        if (assent != null) "n":      code,
                                        if (assent != null) "assent": assent,
                                    }, pin) as String? ?? "";
                                    _outgoingPinToken = token;

                                    DvOrb.navigate_new("invite_clan_pin");
                                    final pinShape = await DvOrb.wait_for_shape("invite_clan_pin/pin");
                                    pinShape
                                        ?..set("shape.label", pin)
                                        ..refreshUI();
                                    return;
                                }

                                DvOrb.navigate_new("invite_clan");

                                final link       = "ddust://invite?group_id=$groupId&lobby_id=$lobbyId&region=$region$_inviteLinkParams";
                                final qrcodeShape = await DvOrb.wait_for_shape("invite_clan/qrcode");
                                qrcodeShape
                                    ?..set("shape.content", link)
                                    ..refreshUI();
    }

    // « Partager l'invitation » (écran invite_clan) : le modèle share.clan_invite lit le clan,
    // le lobby, la région et la fin du lien (`&k=…&n=…`) dans le dictionnaire. Ils n'y sont
    // posés que le temps du partage : le code d'un enfant n'a pas à finir sur le disque du chef
    // au prochain store(), et l'invitation sortante non plus (cf. _outgoingGroupId).
    // ⚠ Des clefs `worker.invite_out_*`, distinctes de `worker.pending_*` (l'invitation REÇUE) :
    //   même si un store() tombait pendant le partage, rien ne pourrait passer pour une
    //   invitation en attente au lancement suivant.
    Future<void> on_share_clan_invite(DvShape? caller, dynamic event) async {

                                if (_outgoingGroupId.isEmpty || _outgoingLobbyId.isEmpty) return;
                                await deva_set("worker.invite_out_group_id", _outgoingGroupId);
                                await deva_set("worker.invite_out_lobby_id", _outgoingLobbyId);
                                await deva_set("worker.invite_out_region",   _outgoingRegion);
                                await deva_set("worker.pending_invite_type", _inviteLinkParams);
                                try {
                                    final fut = ActionRegistry.get("share.clan_invite")?.call(caller, event);
                                    if (fut is Future) await fut;
                                } finally {
                                    await deva_set("worker.invite_out_group_id", "");
                                    await deva_set("worker.invite_out_lobby_id", "");
                                    await deva_set("worker.invite_out_region",   "");
                                    await deva_set("worker.pending_invite_type", "");
                                }
    }

    // « Partager l'invitation » de l'écran invite_clan_pin : même règle que on_share_clan_invite.
    // Le jeton scellé ne passe par le dictionnaire (lu par le modèle share.clan_invite_pin) que
    // le temps du partage, sous une clef `invite_out_*` qui ne peut passer pour une invitation reçue.
    Future<void> on_share_clan_invite_pin(DvShape? caller, dynamic event) async {

                                if (_outgoingPinToken.isEmpty) return;
                                await deva_set("worker.invite_out_pin_token", _outgoingPinToken);
                                try {
                                    final fut = ActionRegistry.get("share.clan_invite_pin")?.call(caller, event);
                                    if (fut is Future) await fut;
                                } finally {
                                    await deva_set("worker.invite_out_pin_token", "");
                                }
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
                                final region  = event["region"]?.toString() ?? "";
                                final onShare = DvOrb.get_current_page()?.dvid == "kid_assent_share";
                                final errorId = onShare ? "kid_assent_share/error" : "kid_wants_clan/region_error";
                                if (await _inviteRegionMismatch(region, errorId)) return;

                                // Nature de l'invitation, et code de la demande d'enfant qu'elle porte.
                                // Contrôlées ICI, avant la moindre mise de côté : une invitation refusée
                                // ne doit pas remplacer celle, valide, qui attendrait déjà.
                                final kind    = event["k"]?.toString() == "child" ? "child" : "adult";
                                final code    = event["n"]?.toString() ?? "";
                                final refusal = await _inviteKindRefusal(kind, code);
                                if (refusal.isNotEmpty) {
                                    deva_log("info", "[worker] on_invite_clan_link: invitation $kind refusée ($refusal)");
                                    if (onShare || refusal == "invite_for_child") {
                                        // Sur place : l'enfant reste sur son écran de partage (son code
                                        // tient toujours), l'adulte sur l'écran où il a scanné.
                                        await _revealLabel(errorId, refusal);
                                    } else {
                                        // Mineur ailleurs (lien ouvert en plein parcours) : le message
                                        // l'attend sur son écran de partage, sans l'arracher à l'étape
                                        // en cours (des conditions pas encore acceptées, par exemple).
                                        _kidAssentNotice = refusal;
                                    }
                                    return;
                                }

                                // Stocké inconditionnellement : on_login le consomme en cold start. La
                                // région suit : c'est là seulement qu'on pourra la comparer, une fois le
                                // royaume choisi. La nature et le code aussi, en mémoire : l'état légal
                                // n'est pas toujours connu ici (lien ouvert application fermée), ils
                                // seront revérifiés (kid_assent_route, _consumePendingInvite).
                                await deva_set("worker.pending_group_id",      groupId);
                                await deva_set("worker.pending_lobby_id",      lobbyId);
                                await deva_set("worker.pending_invite_region", region);
                                _pendingInviteKind = kind;
                                _pendingInviteCode = code;
                                _pendingInviteFresh = true;

                                if (!(_cloud?.isReady() ?? false)) return;

                                // AVANT LE LOGIN, ON NE REJOINT RIEN. Accepter ici, c'était soumettre une
                                // candidature sous l'identifiant anonyme, donc écrire au nom d'un enfant
                                // avant qu'il ne soit quelqu'un. L'invitation attend en mémoire ; la
                                // connexion Google passe d'abord, et on_login l'accepte ensuite, sous le
                                // compte définitif (_consumePendingInvite).
                                // Hors de l'écran de partage (lien ouvert en plein parcours), rien ne
                                // bouge. Un mineur qui n'a pas encore dit oui la verra refusée par
                                // kid_assent_route : elle a été faite avant sa demande.
                                if (_anon) {
                                    if (onShare) await ActionRegistry.get("steps.navigate.link")?.call(caller, null);
                                    return;
                                }

                                // Warm start : joueur déjà connecté → acceptation sous son compte, puis
                                // attente du chef sur join_wait (_acceptAndWait).
                                // Consommé : sans ce reset, un redémarrage à froid ultérieur rejoue
                                // l'acceptation d'une adhésion déjà finalisée.
                                await _clearPendingInvite();
                                if (await _hasClanNow("on_invite_clan_link", groupId)) return;
                                await _acceptAndWait(groupId, lobbyId, kind, code);
    }

    // L'invitation ne peut-elle PAS être acceptée ? MULTICLAN : un joueur peut avoir plusieurs
    // clans ; on refuse seulement s'il est déjà membre de CE clan, ou s'il a atteint le plafond
    // (l'accepter brûlerait le lobby pour rien).
    Future<bool> _hasClanNow(String who, [String groupId = ""]) async {

                                final refusal = await _joinRefusal(groupId);
                                if (refusal.isNotEmpty) {
                                    deva_log("info", "[worker] $who: invitation ignorée ($refusal)");
                                    _joinNotice = refusal;
                                }
                                return refusal.isNotEmpty;
    }

    // Invitation laissée en attente avant le login (QR scanné ou lien ouvert par un enfant encore
    // anonyme, lien reçu application fermée). Appelée par on_login, une fois le compte définitif
    // chargé : c'est le premier moment où rejoindre un clan n'écrit plus sous un identifiant
    // jetable. Rend true si elle a navigué (l'appelant ne doit alors pas router à son tour).
    //
    // [hasClan] : le joueur a déjà un clan (branche « session complète » d'on_login). Un refus ne
    // le renvoie alors nulle part : il n'a pas de demande en cours à refaire.
    //
    // [ownClanId] : le clan du joueur, quand il en a un.
    // ⚠ FILET POUR LES DISQUES D'AVANT LE CORRECTIF : on_management_created écrivait l'invitation
    //   que le chef venait d'OUVRIR dans `worker.pending_group_id`, et le store() suivant la
    //   gardait. Une invitation « en attente » vers son propre clan n'est donc jamais une
    //   invitation reçue : c'est ce reste-là. Oubliée sans rien accepter.
    Future<bool> _consumePendingInvite(DvShape? caller, dynamic event, {bool hasClan = false, String ownClanId = ""}) async {

                                final pendingGroup = (await deva_get("worker.pending_group_id"))?.toString() ?? "";
                                if (pendingGroup.isNotEmpty && ownClanId.isNotEmpty && pendingGroup == ownClanId) {
                                    deva_log("info", "[worker] _consumePendingInvite: invitation vers son propre clan (reste côté chef), oubliée");
                                    await _clearPendingInvite();
                                    return false;
                                }
                                if (pendingGroup.isNotEmpty) {
                                    // Revérifiée ici, sous le compte définitif : l'état légal pouvait être
                                    // inconnu quand le lien a été ouvert (application fermée, avant
                                    // l'écran d'âge), et le contrôle avait alors été repoussé.
                                    final refusal = await _inviteKindRefusal(
                                        _pendingInviteKind.isEmpty ? "adult" : _pendingInviteKind, _pendingInviteCode);
                                    if (refusal.isNotEmpty) {
                                        deva_log("info", "[worker] _consumePendingInvite: invitation refusée ($refusal)");
                                        await _clearPendingInvite();
                                        // Un adulte, ou un joueur qui a déjà son clan : rien à refaire,
                                        // la suite ordinaire d'on_login reprend (tableau de bord, ou choix
                                        // entre créer et rejoindre un clan).
                                        if (refusal == "invite_for_child" || hasClan) return false;
                                        _sendKidBackToAssent(refusal);
                                        return true;
                                    }
                                    final pendingLobby = (await deva_get("worker.pending_lobby_id"))?.toString() ?? "";
                                    final kind         = _pendingInviteKind.isEmpty ? "adult" : _pendingInviteKind;
                                    final code         = _pendingInviteCode;
                                    // Consommé : sans ce reset, une adhésion déjà acceptée est rejouée à
                                    // chaque démarrage à froid (la submission n'accepte plus l'écriture).
                                    // Le code de la demande part dans pending_join (_acceptAndWait) :
                                    // _handleClanJoin le compare au code scellé par le chef, à l'admission,
                                    // même après un redémarrage.
                                    await _clearPendingInvite();
                                    // MULTICLAN : un joueur qui a déjà un clan peut en rejoindre un autre,
                                    // sauf s'il en est déjà membre ou a atteint le plafond.
                                    if (hasClan && await _hasClanNow("_consumePendingInvite", pendingGroup)) return false;
                                    return await _acceptAndWait(pendingGroup, pendingLobby, kind, code);
                                }
                                // Lien PIN reçu avant l'auth : écran de saisie, le jeton est pré-rempli
                                // par son appear (on_enter_invite_pin_appear).
                                final pendingToken = (await deva_get("worker.pending_invite_token_in"))?.toString() ?? "";
                                if (pendingToken.isNotEmpty) {
                                    DvOrb.navigate_new("enter_invite_pin");
                                    return true;
                                }
                                return false;
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

                                // Stocké inconditionnellement : on_login le consomme en cold start (un
                                // adulte déjà connecté). Pour un enfant, un lien reçu application fermée
                                // ne sert plus : le code de sa demande est mort avec le processus, et
                                // kid_assent_route refuse le lien quand il dit oui de nouveau.
                                await deva_set("worker.pending_invite_token_in", token);
                                _pendingInviteFresh = true;

                                if (!(_cloud?.isReady() ?? false)) return;
                                // Enfant encore anonyme : on ne l'arrache à son parcours que s'il en est à
                                // attendre l'invitation (écran de partage). Ailleurs, il n'a pas encore de
                                // demande à laquelle ce lien puisse répondre : kid_assent_route le refusera.
                                if (_anon && DvOrb.get_current_page()?.dvid != "kid_assent_share") return;
                                // Écran de saisie du PIN, jeton pré-rempli par son appear.
                                DvOrb.navigate_new("enter_invite_pin");
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
                                // MULTICLAN : le même lien + code sert aux échanges entre adultes (un chef
                                // qui accueille un enfant d'un autre clan, un candidat co-représentant).
                                final gt = payload?["t"]?.toString() ?? "";
                                if (gt == "guest" || gt == "cog") {
                                    final req = _checkGuardianPayload(Map<String, dynamic>.from(payload!));
                                    await deva_set("worker.pending_invite_token_in", "");
                                    if (req == null || _anon) {
                                        errShape?..set("shape.label", TranslationRegistry.processLabel("@@@T:pin_wrong@@@"))
                                            ..set("shape.visible", true)..refreshUI();
                                        return;
                                    }
                                    errShape?..set("shape.visible", false)..refreshUI();
                                    DvOrb.navigate_back();
                                    await _openGuardianRequest(req);
                                    return;
                                }
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

                                // Le PIN était bon et la contrée la même : reste la nature de l'invitation
                                // et, pour un enfant, le code de SA demande (cf. _inviteKindRefusal). Un
                                // lien scellé par une version antérieure n'a pas de `k` : il vaut « adulte ».
                                final kind    = payload?["k"]?.toString() == "child" ? "child" : "adult";
                                final code    = payload?["n"]?.toString() ?? "";
                                final refusal = await _inviteKindRefusal(kind, code);
                                if (refusal.isNotEmpty) {
                                    deva_log("info", "[worker] on_confirm_pin: invitation $kind refusée ($refusal)");
                                    await deva_set("worker.pending_invite_token_in", "");
                                    if (refusal == "invite_for_child") {
                                        // Un adulte : le message sur place, il peut coller un autre lien.
                                        await _revealLabel("enter_invite_pin/error", refusal);
                                    } else {
                                        // Un enfant : retour à sa demande (écran de partage, ou sa question
                                        // s'il n'a plus de code), où le message l'attend.
                                        _sendKidBackToAssent(refusal);
                                    }
                                    return;
                                }

                                errShape?..set("shape.visible", false)..refreshUI();
                                await deva_set("worker.pending_invite_token_in", "");

                                // Suite strictement identique au flux QR : acceptation + navigation.
                                await deva_set("worker.pending_group_id", groupId);
                                await deva_set("worker.pending_lobby_id",  lobbyId);
                                _pendingInviteKind = kind;
                                _pendingInviteCode = code;
                                _pendingInviteFresh = true;
                                // Avant le login (l'enfant) : l'invitation déchiffrée attend en mémoire,
                                // la connexion Google passe d'abord (cf. on_invite_clan_link). Le code a
                                // été vérifié ici, une fois pour toutes : on_login n'aura plus qu'à accepter.
                                if (_anon) {
                                    await ActionRegistry.get("steps.navigate.link")?.call(caller, null);
                                    return;
                                }
                                // Consommé : sans ce reset, un redémarrage à froid ultérieur rejoue
                                // l'acceptation d'une adhésion déjà finalisée.
                                await _clearPendingInvite();
                                if (await _hasClanNow("on_confirm_pin", groupId)) return;
                                // Joueur connecté : acceptation sous son compte, puis attente du chef
                                // sur join_wait.
                                await _acceptAndWait(groupId, lobbyId, kind, code);
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
                                final kind = _pendingInviteKind.isEmpty ? "adult" : _pendingInviteKind;
                                final code = _pendingInviteCode;

                                // Consommé : sans ce reset, un redémarrage à froid ultérieur rejoue
                                // l'acceptation d'une adhésion déjà finalisée.
                                await _clearPendingInvite();
                                if (_anon || await _hasClanNow("on_accept_invitation_clan", groupId)) return;
                                await _acceptAndWait(groupId, lobbyId, kind, code);
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
