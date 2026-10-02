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

// Plafond de clans actifs par joueur (D4).
const int _kMaxClans = 8;
// Fenêtre d'ENTRÉE d'une autorisation donnée par un représentant (D5). Une fois entré,
// l'enfant reste dans le clan jusqu'à un retrait.
const int _kGuestAuthDays = 7;
// Durée de vie d'une attente de secret de représentation côté parent (en attente que
// l'enfant apparaisse dans le clan) et d'une boîte de dépôt de co-représentant.
const int _kGuardianPendingDays = 7;

// -----------------------------------------------------------------------------
// --- worker extension : le multiclan
// -----------------------------------------------------------------------------
//
// Un joueur appartient à plusieurs clans (8 au plus), avec un personnage par clan, et choisit
// celui dans lequel il joue. Dossier de conception : tmp/design_multiclan.md.
//
// TROIS PIÈCES :
//   1. LE CLAN COURANT. `users.steps.clan` n'est plus « le » clan du joueur, c'est le POINTEUR du
//      clan courant ; `users.clans.{id}` est la liste (region, date, last_visit, enabled). Changer
//      de clan, c'est déplacer le pointeur, vider l'état mémoire du clan quitté
//      (_resetClanState) et rejouer l'entrée (_enterClan).
//   2. LE PROFIL PARTAGÉ (`users.profile` : nom, avatar, titres). Recopié sur la fiche de chaque
//      clan à l'entrée. L'XP et le niveau restent par clan.
//   3. LA REPRÉSENTATION D'UN ENFANT (`guardianship/{childId}`), protégée comme un clan par un
//      secret que détiennent l'enfant, son représentant et ses co-représentants
//      (`userindexes.guardianships.{childId}.secret`). UN REPRÉSENTANT N'ÉCRIT QUE LÀ ; c'est
//      l'app de l'enfant, seule à détenir les secrets de tous ses clans, qui applique ses gestes
//      sur ses fiches (_applyGuardianship). Aucune fonction serveur nouvelle : seul
//      delete_user_data (filet du retrait du consentement) lit la table.
//
// ⚠ LIMITE ASSUMÉE : un clan d'une AUTRE région que la maison du joueur est refusé à l'adhésion.
//   Tout le client lit les données de clan dans UNE région (documents.session.cloud_region) ; la
//   région est néanmoins écrite partout (users.clans.{id}.region, guardianship.clans.{id}.region,
//   userindexes.home_region) pour le jour où l'on ouvrira le multi-région.
extension Worker_multiclan on worker {

    // -----------------------------------------------------------------------
    // --- Enregistrement
    // -----------------------------------------------------------------------

    void _register_multiclan() {

                                // Écran « Mes clans » (option du menu Clan) : changer de clan, en rejoindre un autre.
                                ActionRegistry.register("worker.open_my_clans",            open_my_clans);
                                ActionRegistry.register("worker.on_my_clans_appear",       on_my_clans_appear);
                                ActionRegistry.register("worker.on_my_clans_pick",         on_my_clans_pick);
                                ActionRegistry.register("worker.on_switch_covered",        on_switch_covered);

                                // Écran « Mes enfants » (option du menu Clan, adultes) : les gestes d'un représentant.
                                ActionRegistry.register("worker.open_guardian_hub",        open_guardian_hub);
                                ActionRegistry.register("worker.on_guardian_hub_appear",   on_guardian_hub_appear);
                                ActionRegistry.register("worker.on_guardian_hub_pick",     on_guardian_hub_pick);

                                // Écran QR des échanges entre adultes : le chef de B qui accueille un enfant
                                // d'un autre clan, l'adulte qui demande à devenir co-représentant.
                                ActionRegistry.register("worker.on_welcome_guest_child",   on_welcome_guest_child);
                                ActionRegistry.register("worker.on_guardian_qr_appear",    on_guardian_qr_appear);
                                ActionRegistry.register("worker.on_guardian_qr_remote",    on_guardian_qr_remote);
                                ActionRegistry.register("worker.on_guardian_qr_share",     on_guardian_qr_share);
                                ActionRegistry.register("worker.on_guardian_qr_confirm",   on_guardian_qr_confirm);
                                ActionRegistry.register("worker.on_guardian_qr_leave",     on_guardian_qr_leave);

                                // Choix de l'enfant par le représentant (autoriser un clan, ajouter un
                                // co-représentant, voir ses clans et l'en retirer).
                                ActionRegistry.register("worker.on_ward_pick_appear",      on_ward_pick_appear);
                                ActionRegistry.register("worker.on_ward_pick",             on_ward_pick);

                                // Enfant déjà membre d'un clan qui en demande un autre : retour à son clan
                                // depuis l'écran de partage de sa demande.
                                ActionRegistry.register("worker.on_kid_assent_leave",      on_kid_assent_leave);

                                // Crochets de dvmessaging (D11, § 6.4) : filtrer un message à la réception,
                                // basculer vers le clan qu'il nomme avant d'exécuter son action.
                                ActionRegistry.register("dvmessaging.filter",              _onMessageFilter);
                                ActionRegistry.register("dvmessaging.before_action",       _onMessageBeforeAction);

                                // Kebab Personnage : notifications de ce téléphone, pour ce clan ou pour tous.
                                ActionRegistry.register("worker.notif_clan_off", (c, e) async { await _setNotif(false, clan: true);  });
                                ActionRegistry.register("worker.notif_clan_on",  (c, e) async { await _setNotif(true,  clan: true);  });
                                ActionRegistry.register("worker.notif_all_off",  (c, e) async { await _setNotif(false, clan: false); });
                                ActionRegistry.register("worker.notif_all_on",   (c, e) async { await _setNotif(true,  clan: false); });
    }

    // -----------------------------------------------------------------------
    // --- Les clans du joueur
    // -----------------------------------------------------------------------

    // ⚠ UN CHAMP IMBRIQUÉ D'UN Dvidle EST UN Dvidle, PAS UNE Map (Dvidle.set convertit les Maps).
    //   Toute lecture d'une carte (users.clans, guardianships, guest_auth, history…) passe par ici.
    Map<String, dynamic> _mcMap(dynamic v) {

                                if (v is Dvidle) {
                                    final j = v.toJson();
                                    return j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
                                }
                                if (v is Map) return Map<String, dynamic>.from(v);
                                return <String, dynamic>{};
    }

    // Région « maison » : celle du doc `users` (et de `guardianship`, de `userindexes` maison).
    Future<String> _homeRegion() async =>
        (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";

    // Les clans ACTIFS du joueur, lus dans `users.clans` : secret présent, `enabled` différent de
    // false. Triés par dernière visite (la plus récente d'abord), repli sur la date d'adhésion.
    List<Map<String, String>> _activeClans(Dvidle? session) {

                                final out = <Map<String, String>>[];
                                final raw = _mcMap(session?.get("clans"));
                                raw.forEach((k, v) {
                                    if (v is! Map) return;
                                    if (v["enabled"] == false) return;
                                    final secret = v["clanSecret"]?.toString() ?? "";
                                    if (secret.isEmpty) return;
                                    out.add({
                                        "id":         k.toString(),
                                        "secret":     secret,
                                        "region":     v["region"]?.toString() ?? "",
                                        "date":       v["date"]?.toString() ?? "",
                                        "last_visit": v["last_visit"]?.toString() ?? "",
                                    });
                                });
                                String key(Map<String, String> m) =>
                                    (m["last_visit"] ?? "").isNotEmpty ? m["last_visit"]! : (m["date"] ?? "");
                                out.sort((a, b) => key(b).compareTo(key(a)));
                                return out;
    }

    // Le joueur est-il déjà membre ACTIF de ce clan ?
    bool _isActiveMemberOf(Dvidle? session, String clanId) =>
        clanId.isNotEmpty && _activeClans(session).any((c) => c["id"] == clanId);

    // Refus d'une adhésion AVANT de l'accepter (lien, QR, code) : déjà membre, plafond atteint.
    // Rend "" si l'adhésion peut se faire, sinon la clef du message.
    Future<String> _joinRefusal(String groupId) async {

                                final region = await _homeRegion();
                                if (region.isEmpty) return "";
                                Dvidle? session;
                                try { session = await _readSession(region); } catch (_) {}
                                if (_isActiveMemberOf(session, groupId)) return "join_already_member";
                                if (_activeClans(session).length >= _kMaxClans) return "join_clans_cap";
                                return "";
    }

    // -----------------------------------------------------------------------
    // --- Changer de clan (D3)
    // -----------------------------------------------------------------------

    // Vide tout l'état MÉMOIRE lié au clan courant. Partagé par on_logout (qui vide en plus
    // l'identité du compte) et la bascule d'un clan à l'autre. Tout champ Dart ou clé
    // `worker.*` qui porte un clanId, un clanSecret ou un dérivé du clan doit être remis ici.
    Future<void> _resetClanState() async {

                                _stopValidationPolling();
                                _stopPlayerVigilance();
                                _resetOpening();
                                _invitesQuietAt = null;
                                // Rôles : chef et adulte sont PAR CLAN (D12).
                                _isAdmin = false; _adminCount = 0; _isAdminClanId = ""; _isAdminUserId = "";
                                _isAdult = false; _isAdultClanId = ""; _isAdultUserId = "";
                                await _unpublishRoles();
                                _adminMode = false;
                                _gameDomains.clear();
                                _declareTiroirVocabulary();
                                await _syncChiefUi();
                                // Tâches du clan : le cache est keyé sur le clan, on le vide quand même
                                // pour ne rien montrer du clan quitté le temps de la relecture.
                                _tasksSyncCursor = "";
                                _tasksSyncClanId = "";
                                _lastTasksFetchAt = null;
                                _lastTasksFullListAt = null;
                                _maxXpCache.clear();
                                _consentSwept.clear();
                                _consentTargetId = ""; _consentTargetName = ""; _consentMode = "";
                                // Événements de roster et cérémonies : propres au clan quitté.
                                _evtActive = null;
                                _evtOnOk = null;
                                _deathSeeded = false;
                                await Deva.instance.set("worker.session.clan_done", "");
                                await Deva.instance.set("session.clan.name", "");
                                await Deva.instance.set("session.clan.id", "");
                                await Deva.instance.set("session.active_task", "");
                                await Deva.instance.set("session.active_proof", "");
                                // Invitations en cours côté chef : elles visaient le clan quitté.
                                _pendingAssent    = null;
                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _claimRows        = [];
                                _inviteAsChief    = false;
                                _inviteAssent     = null;
                                _assentRejected   = false;
                                _inviteLinkParams = "";
                                _outgoingGroupId  = "";
                                _outgoingLobbyId  = "";
                                _outgoingRegion   = "";
                                _outgoingPinToken = "";
                                // La porte close (retrait du consentement) est un état du clan courant :
                                // l'entrée dans l'autre clan la réévalue.
                                await _applyConsentClosed(false);
    }

    // Bascule vers `clanId` (déjà membre actif). Écrit le pointeur et la dernière visite, vide
    // l'état du clan quitté, puis rejoue l'entrée exactement comme au démarrage.
    // [then] : écran à ouvrir une fois entré (tap sur une notification d'un autre clan).
    Future<bool> _switchToClan(String clanId, {String then = ""}) async {

                                if (_switchingClan || clanId.isEmpty) return false;
                                _switchingClan = true;
                                try {
                                    final region  = await _homeRegion();
                                    if (region.isEmpty) return false;
                                    final session = await _readSession(region);
                                    final entry   = _activeClans(session).where((c) => c["id"] == clanId).toList();
                                    if (entry.isEmpty) {
                                        deva_log("warning", "[multiclan] bascule refusée : $clanId n'est pas un clan actif");
                                        return false;
                                    }
                                    // L'emprunt de compte (take_place) est limité au clan courant (D13).
                                    if (_impersonating) {
                                        deva_log("info", "[multiclan] bascule refusée pendant un emprunt de compte");
                                        return false;
                                    }
                                    final now = DateTime.now().toUtc().toIso8601String();
                                    final doc = Dvidle({});
                                    doc.set("steps.clan.clanId",          clanId);
                                    doc.set("steps.clan.clanSecret",      entry.first["secret"]);
                                    doc.set("steps.clan.status",          "done");
                                    doc.set("last_clan",                  clanId);
                                    doc.set("clans.$clanId.last_visit",   now);
                                    await _cloud?.write("workers", "users", _sessionDocId(), doc, region: region);
                                    _invalidateSessionCache();
                                    deva_log("info", "[multiclan] bascule vers $clanId");

                                    await _resetClanState();
                                    await _impClear();
                                    final fresh = await _readSession(region);
                                    if (fresh == null) return false;
                                    await _enterClan(null, null, fresh, region, fromSwitch: true);
                                    if (then.isNotEmpty) DvOrb.navigate_new(then);
                                    return true;
                                } catch (e) {
                                    deva_log("error", "[multiclan] _switchToClan FAILED: $e");
                                    return false;
                                } finally {
                                    _switchingClan = false;
                                }
    }

    // Le clan courant vient d'être quitté (départ, révocation, retrait d'un clan par un
    // représentant) : on bascule vers un autre clan actif, le clan d'origine en priorité. Rend
    // false s'il n'en reste aucun (l'appelant renvoie alors au choix d'un clan).
    Future<bool> _switchAfterLeave(String leftClanId) async {

                                final region  = await _homeRegion();
                                if (region.isEmpty) return false;
                                _invalidateSessionCache();
                                final session = await _readSession(region);
                                final others  = _activeClans(session).where((c) => c["id"] != leftClanId).toList();
                                if (others.isEmpty) return false;
                                final origin  = session?.get("first_clan")?.toString() ?? "";
                                final target  = others.any((c) => c["id"] == origin) ? origin : others.first["id"]!;
                                return await _switchToClan(target);
    }

    // Marque un clan comme quitté dans `users` et efface son secret de l'index (le joueur n'y a
    // plus accès). À appeler APRÈS les écritures sur la fiche de ce clan : sans le secret, les
    // règles les refuseraient.
    Future<void> _markClanLeft(String clanId) async {

                                final region = await _homeRegion();
                                if (region.isEmpty || clanId.isEmpty) return;
                                try {
                                    final doc = Dvidle({});
                                    doc.set("clans.$clanId.enabled", false);
                                    doc.set("clans.$clanId.left_at", DateTime.now().toUtc().toIso8601String());
                                    await _cloud?.write("workers", "users", _sessionDocId(), doc, region: region);
                                    _invalidateSessionCache();
                                } catch (e) {
                                    deva_log("error", "[multiclan] _markClanLeft users FAILED: $e");
                                }
                                final uid = _cloud?.currentUser()?.providerUid ?? "";
                                if (uid.isNotEmpty) {
                                    try {
                                        final ix = Dvidle({});
                                        ix.set("clans.$clanId", "");
                                        await _cloud?.write("workers", "userindexes", uid, ix, region: region);
                                    } catch (e) {
                                        deva_log("error", "[multiclan] _markClanLeft userindexes FAILED: $e");
                                    }
                                }
    }

    // -----------------------------------------------------------------------
    // --- Notifications (D11, § 6.4)
    // -----------------------------------------------------------------------

    // Tout envoi de notification d'un clan passe par ici : le message NOMME le clan (« [Les
    // Martin] … ») et porte son identifiant (data.clanId), pour que le tap bascule vers lui.
    // Le clan est celui de l'expéditeur, qui agit toujours dans son clan courant.
    Future<Dvidle?> _sendClanMsg(dvmsg m) async {

                                try {
                                    final region  = await _homeRegion();
                                    final session = region.isNotEmpty ? await _readSession(region) : null;
                                    final clanId  = session?.get("steps.clan.clanId")?.toString() ?? "";
                                    final name    = (await Deva.instance.get("session.clan.name"))?.toString() ?? "";
                                    if (clanId.isNotEmpty && (m.get("data.clanId")?.toString() ?? "").isEmpty) {
                                        m.set("data.clanId", clanId);
                                    }
                                    // Le SCOPE du message, pour le silence à la source (pumessaging écarte
                                    // les appareils qui ont coupé ce clan).
                                    if (clanId.isNotEmpty && (m.get("scope")?.toString() ?? "").isEmpty) {
                                        m.set("scope", clanId);
                                    }
                                    final label = m.get("label")?.toString();
                                    if (label != null && label.isNotEmpty && name.isNotEmpty && !label.startsWith("[$name]")) {
                                        m.set("label", "[$name] $label");
                                    }
                                } catch (e) {
                                    deva_log("warning", "[multiclan] _sendClanMsg: $e");
                                }
                                return _messaging?.send(m);
    }

    // Les options « notifications » du kebab Personnage : une de chaque paire. Illisible (pas de
    // messagerie, pas de réseau) : aucune, plutôt qu'un réglage qui afficherait l'inverse.
    Future<List<String>> _notifMenuOptions() async {

                                final msg = _messaging;
                                if (msg == null) return const [];
                                try {
                                    final st      = await msg.muteState();
                                    final region  = await _homeRegion();
                                    final session = region.isNotEmpty ? await _readSession(region) : null;
                                    final clanId  = session?.get("steps.clan.clanId")?.toString() ?? "";
                                    final scopes  = List<dynamic>.from(st.get("muted_scopes") as List? ?? const []);
                                    return [
                                        if (clanId.isNotEmpty) scopes.contains(clanId) ? "notif_clan_on" : "notif_clan_off",
                                        st.get("muted") == true ? "notif_all_on" : "notif_all_off",
                                    ];
                                } catch (e) {
                                    deva_log("warning", "[notif] options illisibles: $e");
                                    return const [];
                                }
    }

    // Coupe ([on] faux) ou rétablit les notifications de CE téléphone, pour le clan courant
    // ([clan] vrai) ou pour tous.
    Future<void> _setNotif(bool on, {required bool clan}) async {

                                final msg = _messaging;
                                if (msg == null) return;
                                var scope = "";
                                if (clan) {
                                    final region  = await _homeRegion();
                                    final session = region.isNotEmpty ? await _readSession(region) : null;
                                    scope = session?.get("steps.clan.clanId")?.toString() ?? "";
                                    if (scope.isEmpty) return;
                                }
                                await msg.setMute(!on, scope: scope);
    }

    // L'identifiant du clan qu'un message nomme (data.clanId), "" s'il n'en nomme pas.
    String _msgClanId(dynamic msg) {

                                if (msg is! Dvidle) return "";
                                try {
                                    return _msgData(msg)["clanId"]?.toString() ?? "";
                                } catch (_) {
                                    return "";
                                }
    }

    // Filtre de réception : un message d'un clan que le joueur a quitté, ou dont un représentant
    // l'a retiré, ou reçu pendant un retrait du consentement, n'est pas montré. L'app en profite
    // pour appliquer le geste (§ 6.4).
    Future<bool> _onMessageFilter(dynamic caller, dynamic msg) async {

                                final clanId = _msgClanId(msg);
                                if (clanId.isEmpty) return true;
                                if (!await _gshipAllowsMessage(clanId)) {
                                    _applyGuardianship();
                                    return false;
                                }
                                final region = await _homeRegion();
                                if (region.isEmpty || _userId.isEmpty) return true;
                                Dvidle? session;
                                try { session = await _readSession(region); } catch (_) { return true; }
                                if (session == null) return true;
                                if (!_isActiveMemberOf(session, clanId)) return false;
                                // Un message SILENCIEUX (sans bandeau, action exécutée d'office) d'un autre
                                // clan que le courant est écarté : seul un tap du joueur fait changer de
                                // clan, jamais un message qui arrive (ex. l'appel à la cérémonie du butin
                                // d'un clan où il ne joue pas en ce moment).
                                final current = session.get("steps.clan.clanId")?.toString() ?? "";
                                final silent  = msg is Dvidle && ((msg.get("label")?.toString() ?? "").isEmpty
                                    || msg.get("foreground")?.toString() == "silent");
                                if (silent && clanId != current) return false;
                                return true;
    }

    // Avant l'action d'un message (tap, bouton) : bascule vers le clan qu'il nomme s'il n'est
    // pas le clan courant. Un clan quitté annule l'action.
    Future<bool> _onMessageBeforeAction(dynamic caller, dynamic msg) async {

                                final clanId = _msgClanId(msg);
                                if (clanId.isEmpty) return true;
                                final region = await _homeRegion();
                                if (region.isEmpty) return true;
                                final session = await _readSession(region);
                                if ((session?.get("steps.clan.clanId")?.toString() ?? "") == clanId) return true;
                                if (!_isActiveMemberOf(session, clanId)) return false;
                                // Une tâche en cours ici : on ne l'abandonne pas sans le dire. « Mes clans »
                                // s'ouvre, l'avertissement déjà armé sur le clan du message.
                                if (_activeTaskHere(session).isNotEmpty) {
                                    _switchArmed = clanId;
                                    DvOrb.navigate_new("my_clans_page");
                                    return false;
                                }
                                return await _switchToClan(clanId);
    }

    // -----------------------------------------------------------------------
    // --- Écran « Mes clans »
    // -----------------------------------------------------------------------

    Future<void> open_my_clans(dynamic caller, dynamic event) async {

                                _switchArmed = "";
                                DvOrb.navigate_new("my_clans_page");
    }

    // La tâche active du joueur dans le clan COURANT ("" s'il n'en a pas). Une seule tâche active
    // par compte (`users.active_task`, « <clanId>_<tâche> »), même en cours de validation.
    String _activeTaskHere(Dvidle? session) {

                                final active  = session?.get("active_task")?.toString() ?? "";
                                final current = session?.get("steps.clan.clanId")?.toString() ?? "";
                                if (active.isEmpty || current.isEmpty || !active.startsWith("${current}_")) return "";
                                return active;
    }

    // Abandon de la tâche active avant de changer de clan (confirmé par le joueur) : même effet
    // que « Retraite ! » (on_combat_cancel), preuve comprise, même en cours de validation.
    Future<void> _abandonActiveTask(Dvidle session, String region) async {

                                final active     = _activeTaskHere(session);
                                if (active.isEmpty) return;
                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                _stopValidationPolling();
                                try {
                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        await _releaseTask(clanId, clanSecret, _taskIdFromActive(active, clanId), region);
                                    }
                                    await _forgetProof(session.get("active_proof")?.toString() ?? "");
                                    final u = Dvidle({});
                                    u.set("active_task",  "");
                                    u.set("active_proof", "");
                                    await _cloud?.write("workers", "users", _sessionDocId(), u, region: region);
                                    _invalidateSessionCache();
                                    await Deva.instance.set("session.active_task",  "");
                                    await Deva.instance.set("session.active_proof", "");
                                    deva_log("info", "[multiclan] tâche $active abandonnée avant de changer de clan");
                                } catch (e) {
                                    deva_log("error", "[multiclan] _abandonActiveTask FAILED: $e");
                                }
    }

    // Une ligne par clan actif (nom + emblème, dernière visite), le clan courant marqué, puis
    // « Rejoindre un autre clan » (grisé au plafond).
    Future<void> on_my_clans_appear(dynamic caller, dynamic event) async {

                                final region  = await _homeRegion();
                                final session = region.isNotEmpty ? await _readSession(region) : null;
                                final current = session?.get("steps.clan.clanId")?.toString() ?? "";
                                final clans   = _activeClans(session);
                                final rows    = <Map<String, dynamic>>[];
                                for (final c in clans) {
                                    final id = c["id"]!;
                                    var name   = "";
                                    var avatar = "";
                                    try {
                                        final clan = await _cloud?.read("workers", "clans", id,
                                            ownerId: c["secret"], region: region);
                                        name   = clan?.get("internal.name")?.toString() ?? "";
                                        avatar = clan?.get("avatar")?.toString() ?? "";
                                    } catch (_) {}
                                    final visit = DateTime.tryParse(c["last_visit"] ?? "")?.toLocal();
                                    final armed = _switchArmed == id;
                                    rows.add({
                                        "id":    id,
                                        "label": name.isNotEmpty ? name : TranslationRegistry.translate("my_clans_unnamed"),
                                        if (armed) "color": "0xFFCC4444",
                                        // Bascule armée (tâche en cours) : l'avertissement remplace la date.
                                        "desc":  armed ? TranslationRegistry.translate("my_clans_task_warn")
                                               : visit == null ? "" : TranslationRegistry.translate("my_clans_last_visit")
                                                    .replaceAll("{date}", "${visit.day.toString().padLeft(2, '0')}/"
                                                        "${visit.month.toString().padLeft(2, '0')}/${visit.year}"),
                                        "image": avatar.isNotEmpty ? avatar : _defaultClanAvatar,
                                        if (id == current) "aside": TranslationRegistry.translate("my_clans_current"),
                                    });
                                }
                                final full = clans.length >= _kMaxClans;
                                rows.add({
                                    "id":      "__join",
                                    "label":   TranslationRegistry.translate("my_clans_join"),
                                    "desc":    TranslationRegistry.translate(full ? "join_clans_cap" : "my_clans_join_desc"),
                                    "icon":    "group_add",
                                    "enabled": !full,
                                });
                                ActionRegistry.get("dvlist.set_rows")?.call(null, {"page": "my_clans_page", "rows": rows});
    }

    Future<void> on_my_clans_pick(dynamic caller, dynamic event) async {

                                final m  = event is Map ? event : const {};
                                final id = m["id"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                if (id == "__join") { await _openJoinOther(); return; }
                                final region  = await _homeRegion();
                                final session = await _readSession(region);
                                if ((session?.get("steps.clan.clanId")?.toString() ?? "") == id) {
                                    _switchArmed = "";
                                    DvOrb.navigate_back();
                                    return;
                                }
                                // TÂCHE EN COURS dans le clan courant : premier tap = avertissement, second
                                // tap = abandon (même en validation) puis bascule. Le joueur peut aussi
                                // revenir en arrière et attendre son verdict.
                                if (session != null && _activeTaskHere(session).isNotEmpty) {
                                    if (_switchArmed != id) {
                                        _switchArmed = id;
                                        await on_my_clans_appear(null, null);
                                        return;
                                    }
                                    await _abandonActiveTask(session, region);
                                }
                                _switchArmed = "";
                                await _playSwitchCurtain(id, m["label"]?.toString() ?? "");
    }

    // Le rideau du changement de clan : le noir tombe, « Bon retour parmi {clan} » s'affiche, et
    // la bascule a lieu dessous (on_switch_covered). Sans dvinterlude : bascule directe.
    Future<void> _playSwitchCurtain(String clanId, String clanName) async {

                                final play = ActionRegistry.get("dvinterlude.play.passage_switch");
                                if (play == null) { await _switchToClan(clanId); return; }
                                _pendingSwitchClan = clanId;
                                final text = TranslationRegistry.translate("switch_welcome").replaceAll("{clan}", "[[$clanName]]");
                                play(null, {"text": text});
    }

    // Rideau tombé (ou préempté) : la bascule, une seule fois.
    Future<void> on_switch_covered(dynamic caller, dynamic event) async {

                                final id = _pendingSwitchClan;
                                if (id.isEmpty) return;
                                _pendingSwitchClan = "";
                                await _switchToClan(id);
    }

    // « Rejoindre un autre clan ». Un adulte suit le parcours d'adhésion habituel (QR du chef,
    // ou lien + code). Un enfant fait une DEMANDE, comme à son inscription : le « je veux jouer »
    // et son code, que le chef de l'autre clan scanne. Son appareil vérifiera ensuite que l'un de
    // ses représentants a bien autorisé ce clan (§ 5.2).
    Future<void> _openJoinOther() async {

                                final region  = await _homeRegion();
                                final session = region.isNotEmpty ? await _readSession(region) : null;
                                if (_activeClans(session).length >= _kMaxClans) return;
                                final legal = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                if (_gameplayLegal(legal) == "a") {
                                    DvOrb.navigate_new("kid_wants_clan");
                                    return;
                                }
                                _kidAssentCode = _newAssentCode();
                                _kidAssentLink = await _buildKidAssentLink();
                                DvOrb.navigate_new("kid_assent_share");
    }

    // Enfant déjà membre d'un clan, sur l'écran de sa demande : retour à son clan.
    Future<void> on_kid_assent_leave(dynamic caller, dynamic event) async {

                                _kidAssentCode = "";
                                _kidAssentLink = "";
                                DvOrb.navigate_reset("dashboard");
    }

    // L'écran de partage de la demande sert aussi à l'enfant DÉJÀ membre d'un clan : il y gagne
    // une sortie (il n'a plus de parcours d'inscription derrière lui).
    Future<void> _syncKidAssentLeave() async {

                                final region  = await _homeRegion();
                                Dvidle? session;
                                try { session = region.isNotEmpty ? await _readSession(region) : null; } catch (_) {}
                                final hasClan = _activeClans(session).isNotEmpty;
                                final leave  = await DvOrb.wait_for_shape("kid_assent_share/leave");
                                leave?..set("shape.visible", hasClan)..refreshUI();
                                if (hasClan) _hideShapes(["kid_assent_share/notice"]);
    }

    // -----------------------------------------------------------------------
    // --- Profil partagé (D2)
    // -----------------------------------------------------------------------

    // Le profil du joueur (nom, avatar, titres) : `users.profile`, source de vérité. Rempli à la
    // première adhésion depuis la fiche du clan, puis recopié sur la fiche de chaque clan où il
    // entre, et tenu à jour à chaque changement (cf. _profileTouch).
    Future<void> _profileSyncOnEntry(String clanId, String clanSecret, String region) async {

                                if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty || _impersonating) return;
                                try {
                                    final session = await _readSession(region);
                                    final profile = _mcMap(session?.get("profile"));
                                    final fiche   = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region);
                                    if (fiche == null) return;
                                    if (profile.isEmpty) {
                                        // Premier passage : le profil naît de la fiche courante.
                                        final p = Dvidle({});
                                        p.set("profile.name",   fiche.get("name")?.toString() ?? "");
                                        p.set("profile.avatar", fiche.get("avatar")?.toString() ?? "");
                                        final titles = fiche.get("titles");
                                        if (titles is List) p.set("profile.titles", titles);
                                        final idx = fiche.get("title_idx");
                                        if (idx != null) p.set("profile.title_idx", idx);
                                        await _cloud?.write("workers", "users", _sessionDocId(), p, region: region);
                                        _invalidateSessionCache();
                                        return;
                                    }
                                    // Recopie du profil sur la fiche, champ par champ, seulement ce qui diffère.
                                    final patch = Dvidle({});
                                    var dirty = false;
                                    void copy(String from, String to) {
                                        final v = profile[from];
                                        if (v == null) return;
                                        if (v is String && v.isEmpty) return;
                                        if (fiche.get(to)?.toString() == v.toString()) return;
                                        patch.set(to, v);
                                        dirty = true;
                                    }
                                    copy("name", "name");
                                    copy("avatar", "avatar");
                                    copy("title_idx", "title_idx");
                                    final ptitles = profile["titles"];
                                    if (ptitles is List && ptitles.isNotEmpty) {
                                        final ftitles = fiche.get("titles");
                                        final merged  = <dynamic>{...(ftitles is List ? ftitles : const []), ...ptitles}.toList();
                                        if (ftitles is! List || merged.length != ftitles.length) {
                                            patch.set("titles", merged);
                                            dirty = true;
                                        }
                                        // Un titre gagné ICI remonte au profil (il se porte partout).
                                        if (ftitles is List && merged.length != ptitles.length) {
                                            final up = Dvidle({});
                                            up.set("profile.titles", merged);
                                            await _cloud?.write("workers", "users", _sessionDocId(), up, region: region);
                                            _invalidateSessionCache();
                                        }
                                    }
                                    if (!dirty) return;
                                    patch.set("id", _userId);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", _userId, patch,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("warning", "[multiclan] _profileSyncOnEntry: $e");
                                }
    }

    // Un élément du profil vient de changer sur la fiche courante (nom, avatar, titre porté ou
    // gagné) : il remonte au profil, d'où il se recopiera sur les autres fiches à leur entrée.
    Future<void> _profileTouch({String? name, String? avatar, int? titleIdx, List<dynamic>? titles}) async {

                                if (_impersonating) return;
                                try {
                                    final region = await _homeRegion();
                                    if (region.isEmpty) return;
                                    final p = Dvidle({});
                                    if (name     != null && name.isNotEmpty)   p.set("profile.name", name);
                                    if (avatar   != null && avatar.isNotEmpty) p.set("profile.avatar", avatar);
                                    if (titleIdx != null)                      p.set("profile.title_idx", titleIdx);
                                    if (titles   != null)                      p.set("profile.titles", titles);
                                    await _cloud?.write("workers", "users", _sessionDocId(), p, region: region);
                                    _invalidateSessionCache();
                                } catch (e) {
                                    deva_log("warning", "[multiclan] _profileTouch: $e");
                                }
    }

    // -----------------------------------------------------------------------
    // --- guardianship : accès
    // -----------------------------------------------------------------------

    // TRACE D'AUDIT (dvdocuments, documents.record_audit) : un acte qui engage est tracé au MÊME
    // endroit que les preuves d'acceptation des CGU, sous le compte de celui qui agit, et en suit
    // la conservation (5 ans) et la clôture. Best-effort : l'acte est déjà fait.
    Future<void> _audit(String event, Map<String, dynamic> details) async {

                                try {
                                    final fn = ActionRegistry.get("documents.record_audit");
                                    if (fn == null) {
                                        deva_log("warning", "[audit] documents.record_audit absente : $event non tracé");
                                        return;
                                    }
                                    dynamic r = fn(null, {"event": event, "details": details});
                                    if (r is Future) r = await r;
                                    if (r?.toString() != "ok") deva_log("warning", "[audit] $event non tracé ($r)");
                                } catch (e) {
                                    deva_log("warning", "[audit] $event: $e");
                                }
    }

    // Clef d'une ligne d'historique : unique par geste (instant + auteur). Une CARTE et non une
    // liste : la fusion de dvcloud remplace les listes, deux ajouts simultanés en perdraient un.
    String _histKey() => "${DateTime.now().toUtc().millisecondsSinceEpoch}_${_authUserId.isNotEmpty ? _authUserId : _userId}";

    // Mon index (région maison).
    Future<Dvidle?> _myIndex() async {

                                final uid    = _cloud?.currentUser()?.providerUid ?? "";
                                final region = await _homeRegion();
                                if (uid.isEmpty || region.isEmpty) return null;
                                try {
                                    return await _cloud?.read("workers", "userindexes", uid, region: region);
                                } catch (e) {
                                    deva_log("warning", "[guardian] lecture de l'index FAILED: $e");
                                    return null;
                                }
    }

    // Les secrets de représentation de mon index : {childId: secret}. Le mien (si je suis moi-même
    // un enfant représenté) y figure aussi, sous mon propre identifiant.
    Future<Map<String, String>> _gshipSecrets() async {

                                final out = <String, String>{};
                                final ix  = await _myIndex();
                                _mcMap(ix?.get("guardianships")).forEach((k, v) {
                                    final s = v is Map ? (v["secret"]?.toString() ?? "") : "";
                                    if (s.isNotEmpty) out[k] = s;
                                });
                                return out;
    }

    Future<Dvidle?> _gshipRead(String childId, String secret) async {

                                final region = await _homeRegion();
                                if (childId.isEmpty || secret.isEmpty || region.isEmpty) return null;
                                try {
                                    return await _cloud?.read("workers", "guardianship", childId, ownerId: secret, region: region);
                                } catch (e) {
                                    deva_log("warning", "[guardian] lecture de guardianship/$childId FAILED: $e");
                                    return null;
                                }
    }

    Future<bool> _gshipWrite(String childId, String secret, Dvidle patch) async {

                                final region = await _homeRegion();
                                if (childId.isEmpty || secret.isEmpty || region.isEmpty) return false;
                                try {
                                    await _cloud?.write("workers", "guardianship", childId, patch, ownerId: secret, region: region);
                                    return true;
                                } catch (e) {
                                    deva_log("error", "[guardian] écriture de guardianship/$childId FAILED: $e");
                                    return false;
                                }
    }

    // Représentants d'un enfant : son représentant d'origine puis ses co-représentants.
    List<String> _gshipReps(Dvidle? g) {

                                if (g == null) return const [];
                                final out = <String>[];
                                final origin = g.get("guardian_id")?.toString() ?? "";
                                if (origin.isNotEmpty) out.add(origin);
                                final cos = g.get("guardians");
                                if (cos is List) {
                                    for (final c in cos) {
                                        final s = c?.toString() ?? "";
                                        if (s.isNotEmpty && !out.contains(s)) out.add(s);
                                    }
                                }
                                return out;
    }

    bool _gshipClosed(Dvidle? g) => (g?.get("closed_at")?.toString() ?? "").isNotEmpty;

    // Le consentement est-il retiré (retrait posé, non suivi d'un rétablissement) ?
    bool _gshipConsentWithdrawn(Dvidle? g) {

                                final w = DateTime.tryParse(g?.get("consent.withdrawn_at")?.toString() ?? "");
                                if (w == null) return false;
                                final r = DateTime.tryParse(g?.get("consent.restored_at")?.toString() ?? "");
                                return r == null || r.isBefore(w);
    }

    // Suis-je représentant de cet enfant ? Rend sa guardianship si oui (et son secret), sinon null.
    Future<(Dvidle, String)?> _asGuardianOf(String childId) async {

                                if (childId.isEmpty || childId == _authUserId) return null;
                                final secret = (await _gshipSecrets())[childId] ?? "";
                                if (secret.isEmpty) return null;
                                final g = await _gshipRead(childId, secret);
                                if (g == null || _gshipClosed(g)) return null;
                                final me = _authUserId.isNotEmpty ? _authUserId : _userId;
                                if (!_gshipReps(g).contains(me)) return null;
                                return (g, secret);
    }

    // Les enfants que je représente : [{id, name, secret, g}], guardianship ouverte seulement.
    Future<List<Map<String, dynamic>>> _myWards() async {

                                final out = <Map<String, dynamic>>[];
                                final me  = _authUserId.isNotEmpty ? _authUserId : _userId;
                                final secrets = await _gshipSecrets();
                                for (final e in secrets.entries) {
                                    if (e.key == me) continue;
                                    final g = await _gshipRead(e.key, e.value);
                                    if (g == null || _gshipClosed(g) || !_gshipReps(g).contains(me)) continue;
                                    out.add({"id": e.key, "name": g.get("name")?.toString() ?? "", "secret": e.value, "g": g});
                                }
                                return out;
    }

    // UN GESTE DE REPRÉSENTANT : le changement ET sa ligne d'historique, en une écriture.
    Future<bool> _gshipGesture(String childId, String secret, String gesture,
                               {String clanId = "", Map<String, dynamic>? extra, Dvidle? patch}) async {

                                final me   = _authUserId.isNotEmpty ? _authUserId : _userId;
                                final doc  = patch ?? Dvidle({});
                                final key  = _histKey();
                                doc.set("history.$key.at",      DateTime.now().toUtc().toIso8601String());
                                doc.set("history.$key.by",      me);
                                doc.set("history.$key.gesture", gesture);
                                if (clanId.isNotEmpty) doc.set("history.$key.clanId", clanId);
                                extra?.forEach((k, v) => doc.set("history.$key.$k", v));
                                final ok = await _gshipWrite(childId, secret, doc);
                                if (ok) {
                                    await _audit(gesture, {
                                        "childId": childId,
                                        "by":      me,
                                        if (clanId.isNotEmpty) "clanId": clanId,
                                        ...?extra,
                                    });
                                }
                                return ok;
    }

    // -----------------------------------------------------------------------
    // --- guardianship : naissance (adhésion d'origine d'un enfant)
    // -----------------------------------------------------------------------

    // CÔTÉ PARENT, à l'invitation d'un enfant : tire le secret de représentation et le range dans
    // SON index en ATTENTE, sous l'identifiant du lobby. Le parent ne connaît pas encore
    // l'identifiant de l'enfant (l'accord n'en porte aucun, à dessein) : il le rattachera quand
    // l'enfant apparaîtra dans le clan avec la marque `guardian_lobby` (_reconcileGuardianPending).
    Future<String> _newGuardianPending(String lobbyId, String clanId) async {

                                final uid    = _cloud?.currentUser()?.providerUid ?? "";
                                final region = await _homeRegion();
                                if (uid.isEmpty || region.isEmpty || lobbyId.isEmpty) return "";
                                final secret = _generateUuid();
                                try {
                                    final ix = Dvidle({});
                                    ix.set("guardianships_pending.$lobbyId.secret", secret);
                                    ix.set("guardianships_pending.$lobbyId.clanId", clanId);
                                    ix.set("guardianships_pending.$lobbyId.at",     DateTime.now().toUtc().toIso8601String());
                                    await _cloud?.write("workers", "userindexes", uid, ix, region: region);
                                    return secret;
                                } catch (e) {
                                    deva_log("error", "[guardian] secret de représentation non rangé ($e)");
                                    return "";
                                }
    }

    // CÔTÉ PARENT : les secrets en attente dont l'enfant est apparu dans le clan (sa fiche porte
    // `guardian_lobby`) passent sous `guardianships.{childId}`. Les attentes échues sont oubliées.
    // Appelée au rafraîchissement du roster, qui a déjà toutes les fiches en main.
    Future<void> _reconcileGuardianPending(String clanId, List<Dvidle> players) async {

                                final uid    = _cloud?.currentUser()?.providerUid ?? "";
                                final region = await _homeRegion();
                                if (uid.isEmpty || region.isEmpty) return;
                                final ix  = await _myIndex();
                                final pen = _mcMap(ix?.get("guardianships_pending"));
                                if (pen.isEmpty) return;
                                final patch = Dvidle({});
                                var dirty = false;
                                final limit = DateTime.now().toUtc().subtract(const Duration(days: _kGuardianPendingDays));
                                pen.forEach((lobby, v) {
                                    if (v is! Map) return;
                                    final secret = v["secret"]?.toString() ?? "";
                                    final at     = DateTime.tryParse(v["at"]?.toString() ?? "");
                                    if (secret.isEmpty) return;
                                    if (v["clanId"]?.toString() == clanId) {
                                        for (final p in players) {
                                            if (p.get("guardian_lobby")?.toString() != lobby.toString()) continue;
                                            final childId = p.get("id")?.toString() ?? "";
                                            if (childId.isEmpty) continue;
                                            patch.set("guardianships.$childId.secret", secret);
                                            patch.set("guardianships_pending.$lobby", "");
                                            dirty = true;
                                            deva_log("info", "[guardian] représentation de $childId rattachée (lobby $lobby)");
                                            return;
                                        }
                                    }
                                    if (at != null && at.isBefore(limit)) {
                                        patch.set("guardianships_pending.$lobby", "");
                                        dirty = true;
                                    }
                                });
                                if (!dirty) return;
                                try {
                                    await _cloud?.write("workers", "userindexes", uid, patch, region: region);
                                } catch (e) {
                                    deva_log("error", "[guardian] _reconcileGuardianPending FAILED: $e");
                                }
    }

    // CÔTÉ ENFANT, à son adhésion d'origine (ou à la reprise d'un joueur sans téléphone) : range
    // le secret reçu dans son index, PUIS crée le document (la règle lit l'index).
    Future<void> _gshipCreateOrigin({required String childId, required String secret, required String adminId,
                                     required String adminName, required String clanId, required String clanName,
                                     required String region, required String lobbyId}) async {

                                final uid = _cloud?.currentUser()?.providerUid ?? "";
                                if (uid.isEmpty || childId.isEmpty || secret.isEmpty) return;
                                try {
                                    final ix = Dvidle({});
                                    ix.set("guardianships.$childId.secret", secret);
                                    await _cloud?.write("workers", "userindexes", uid, ix, region: region);
                                    final now = DateTime.now().toUtc().toIso8601String();
                                    final g = Dvidle({});
                                    g.set("guardian_id", adminId);
                                    g.set("guardians",   <String>[]);
                                    g.set("name",        (await Deva.instance.get("session.user.name"))?.toString() ?? "");
                                    g.set("created_at",  now);
                                    g.set("clans.$clanId.clan_name",  clanName);
                                    g.set("clans.$clanId.chief_name", adminName);
                                    g.set("clans.$clanId.region",     region);
                                    g.set("clans.$clanId.via",        adminId);
                                    g.set("clans.$clanId.at",         now);
                                    g.set("clans.$clanId.origin",     true);
                                    await _gshipWrite(childId, secret, g);
                                    // La marque qui permet au parent de rattacher le secret à cet enfant.
                                    final m = Dvidle({});
                                    m.set("id", childId);
                                    m.set("guardian_lobby", lobbyId);
                                    final clanSecret = (await _readSession(region))?.get("clans.$clanId.clanSecret")?.toString() ?? "";
                                    if (clanSecret.isNotEmpty) {
                                        await _cloud?.write("workers", "clans_players/$clanId/players", childId, m,
                                            region: region, ownerId: clanSecret);
                                    }
                                    deva_log("info", "[guardian] représentation créée pour $childId (représentant $adminId)");
                                    await _audit("guardian_origin", {"childId": childId, "guardian": adminId,
                                        "guardian_name": adminName, "clanId": clanId, "clan_name": clanName});
                                } catch (e) {
                                    deva_log("error", "[guardian] _gshipCreateOrigin FAILED: $e");
                                }
    }

    // CÔTÉ ENFANT, à l'entrée dans un clan ALORS QU'IL EN A DÉJÀ UN (§ 5.2). Rend "" si l'entrée
    // est autorisée, sinon la clef du message. Trois conditions, une suffit : une autorisation
    // valide pour ce clan, un chef qui publie et qui est le représentant d'origine, ou un
    // co-représentant. [usedAuth] reçoit true quand c'est l'autorisation qui a servi.
    Future<String> _guardianGate(String childId, String clanId, String adminId, List<bool> usedAuth) async {

                                final secret = (await _gshipSecrets())[childId] ?? "";
                                if (secret.isEmpty) return "kid_needs_guardian_auth";
                                final g = await _gshipRead(childId, secret);
                                if (g == null) return "kid_needs_guardian_auth";
                                if (_gshipConsentWithdrawn(g)) return "kid_needs_guardian_auth";
                                if (adminId.isNotEmpty && _gshipReps(g).contains(adminId)) return "";
                                final revoked = g.get("guest_auth.$clanId.revoked_at")?.toString() ?? "";
                                final expires = DateTime.tryParse(g.get("guest_auth.$clanId.expires_at")?.toString() ?? "");
                                if (revoked.isEmpty && expires != null && DateTime.now().toUtc().isBefore(expires.toUtc())) {
                                    usedAuth.add(true);
                                    return "";
                                }
                                return "kid_needs_guardian_auth";
    }

    // CÔTÉ ENFANT : la ligne de clan (et l'autorisation consommée), à CHAQUE entrée.
    Future<void> _gshipNoteEntry(String childId, String clanId, String clanName, String chiefName,
                                 String region, String via, bool usedAuth) async {

                                final secret = (await _gshipSecrets())[childId] ?? "";
                                if (secret.isEmpty) return;
                                final now = DateTime.now().toUtc().toIso8601String();
                                final g = Dvidle({});
                                g.set("clans.$clanId.clan_name",  clanName);
                                g.set("clans.$clanId.chief_name", chiefName);
                                g.set("clans.$clanId.region",     region);
                                g.set("clans.$clanId.via",        via);
                                g.set("clans.$clanId.at",         now);
                                g.set("clans.$clanId.left_at",    "");
                                if (usedAuth) g.set("guest_auth.$clanId.used_at", now);
                                await _gshipWrite(childId, secret, g);
    }

    // -----------------------------------------------------------------------
    // --- guardianship : l'app de l'enfant applique (§ 6)
    // -----------------------------------------------------------------------

    // Relit la représentation de l'enfant COURANT et répercute les gestes des représentants sur
    // TOUTES ses fiches, clan d'origine compris. Idempotente : compare l'état voulu à l'état de
    // chaque fiche et n'écrit que la différence. Appelée au login, à chaque bascule, par la
    // vigilance sur guardianship et à la réception d'une notification.
    // Rend true si le clan courant a été quitté (retrait) : l'appelant s'arrête alors.
    Future<bool> _applyGuardianship() async {

                                if (_gshipApplying || _impersonating) return false;
                                final me = _authUserId.isNotEmpty ? _authUserId : _userId;
                                if (me.isEmpty) return false;
                                _gshipApplying = true;
                                try {
                                    final secret = (await _gshipSecrets())[me] ?? "";
                                    if (secret.isEmpty) return false;
                                    final g = await _gshipRead(me, secret);
                                    if (g == null) return false;
                                    await _gshipKeepLocal(g);
                                    if (_gshipClosed(g)) return false;
                                    final region  = await _homeRegion();
                                    final session = await _readSession(region);
                                    if (session == null) return false;
                                    final current = session.get("steps.clan.clanId")?.toString() ?? "";
                                    var leftCurrent = false;

                                    // 1. RETRAITS D'UN CLAN (guest_auth.{c}.revoked_at).
                                    final ga = _mcMap(g.get("guest_auth"));
                                    {
                                        for (final e in ga.entries) {
                                            final c = e.key.toString();
                                            final v = e.value;
                                            if (v is! Map) continue;
                                            final revoked = DateTime.tryParse(v["revoked_at"]?.toString() ?? "");
                                            if (revoked == null) continue;
                                            final entered = DateTime.tryParse(g.get("clans.$c.at")?.toString() ?? "");
                                            // Une entrée POSTÉRIEURE au retrait (nouvelle autorisation) l'emporte.
                                            if (entered != null && entered.isAfter(revoked)) continue;
                                            if (!_isActiveMemberOf(session, c)) continue;
                                            await _leaveClanByGuardian(c, session, secret);
                                            if (c == current) leftCurrent = true;
                                        }
                                    }

                                    // 2. CONSENTEMENT ET MAJORITÉ, sur chaque fiche active.
                                    final withdrawn = _gshipConsentWithdrawn(g);
                                    final wAt       = DateTime.tryParse(g.get("consent.withdrawn_at")?.toString() ?? "");
                                    final due       = wAt?.add(const Duration(days: _kConsentGraceDays)).toIso8601String() ?? "";
                                    final declared  = (g.get("majority.declared_at")?.toString() ?? "").isNotEmpty;
                                    final fresh     = await _readSession(region);
                                    for (final c in _activeClans(fresh)) {
                                        final cid = c["id"]!;
                                        final cs  = c["secret"]!;
                                        Dvidle? fiche;
                                        try {
                                            fiche = await _cloud?.read("workers", "clans_players/$cid/players", me,
                                                ownerId: cs, region: region);
                                        } catch (_) {}
                                        if (fiche == null) continue;
                                        final patch = Dvidle({});
                                        var dirty = false;
                                        final curDue = fiche.get("consent_due")?.toString() ?? "";
                                        if (withdrawn && curDue.isEmpty && due.isNotEmpty) {
                                            patch.set("consent_at",  wAt!.toIso8601String());
                                            patch.set("consent_due", due);
                                            patch.set("consent_by",  g.get("consent.by")?.toString() ?? "");
                                            dirty = true;
                                        } else if (!withdrawn && curDue.isNotEmpty) {
                                            patch.set("consent_at",  "");
                                            patch.set("consent_due", "");
                                            patch.set("consent_by",  "");
                                            dirty = true;
                                        }
                                        final legal = fiche.get("legal_state")?.toString() ?? "";
                                        if (declared && legal != "t" && legal != "a") {
                                            patch.set("legal_state", "t");
                                            dirty = true;
                                        }
                                        if (!dirty) continue;
                                        patch.set("id", me);
                                        try {
                                            await _cloud?.write("workers", "clans_players/$cid/players", me, patch,
                                                region: region, ownerId: cs);
                                        } catch (e) {
                                            deva_log("error", "[guardian] application sur $cid FAILED: $e");
                                        }
                                    }

                                    // 3. JOURNAL : chaque geste une fois dans le clan d'origine.
                                    await _gshipLogHistory(g, me, secret, fresh);

                                    // 4. CLAN D'ORIGINE DISPARU (dissous au départ de son représentant) : le
                                    //    clan d'un co-représentant, où l'enfant est membre, devient l'origine.
                                    await _gshipRehome(g, fresh);

                                    if (leftCurrent) {
                                        if (!await _switchAfterLeave(current)) {
                                            await Deva.instance.set("worker.session.clan_done", "");
                                            DvOrb.navigate_reset("decisiontree");
                                        }
                                        return true;
                                    }
                                    return false;
                                } catch (e) {
                                    deva_log("error", "[guardian] _applyGuardianship FAILED: $e");
                                    return false;
                                } finally {
                                    _gshipApplying = false;
                                }
    }

    // Retrait d'un clan décidé par un représentant (§ 6.1), exécuté par l'app de l'enfant :
    // plus aucune notification de ce clan (devices vidés), fiche désactivée, journal, puis le
    // clan quitté dans users, l'index et guardianship.
    Future<void> _leaveClanByGuardian(String clanId, Dvidle session, String gSecret) async {

                                final region = await _homeRegion();
                                final me     = _authUserId.isNotEmpty ? _authUserId : _userId;
                                final cs     = session.get("clans.$clanId.clanSecret")?.toString() ?? "";
                                if (cs.isNotEmpty) {
                                    try {
                                        final f = Dvidle({});
                                        f.set("id", me);
                                        f.set("devices", <String>[]);
                                        f.set("enabled", false);
                                        f.set("has_device", false);
                                        await _cloud?.write("workers", "clans_players/$clanId/players", me, f,
                                            region: region, ownerId: cs);
                                        await _writeClanLog(clanId, cs, region, "MemberRevoked", userId: me,
                                            data: Dvidle({"playerId": me, "by": "guardian"}));
                                    } catch (e) {
                                        deva_log("error", "[guardian] retrait de $clanId (fiche) FAILED: $e");
                                    }
                                }
                                await _markClanLeft(clanId);
                                // Plus rien de ce clan, même application fermée : silence à la source.
                                await _messaging?.setMute(true, scope: clanId);
                                final g = Dvidle({});
                                g.set("clans.$clanId.left_at", DateTime.now().toUtc().toIso8601String());
                                await _gshipWrite(me, gSecret, g);
                                deva_log("info", "[guardian] $me retiré de $clanId par un représentant");
                                await _audit("clan_left", {"playerId": me, "clanId": clanId, "by": "guardian"});
    }

    // Chaque ligne d'historique est journalisée UNE fois dans le clan d'origine (seul clan dont
    // la représentation soit l'affaire). `history_logged` est à part : `history` ne se modifie jamais.
    Future<void> _gshipLogHistory(Dvidle g, String me, String secret, Dvidle? session) async {

                                final hist = _mcMap(g.get("history"));
                                if (hist.isEmpty) return;
                                final origin = session?.get("first_clan")?.toString() ?? "";
                                final cs     = session?.get("clans.$origin.clanSecret")?.toString() ?? "";
                                if (origin.isEmpty || cs.isEmpty || !_isActiveMemberOf(session, origin)) return;
                                final region = await _homeRegion();
                                final logged = _mcMap(g.get("history_logged"));
                                final mark   = Dvidle({});
                                var dirty = false;
                                const events = {
                                    "consent_withdrawn": "ConsentWithdrawn",
                                    "consent_restored":  "ConsentRestored",
                                    "majority_declared": "MajorityDeclared",
                                    "guest_authorized":  "GuestAuthorized",
                                    "guest_revoked":     "GuestRevoked",
                                    "guardian_added":    "GuardianAdded",
                                };
                                for (final e in hist.entries) {
                                    final key = e.key.toString();
                                    final v   = e.value;
                                    if (v is! Map) continue;
                                    final done = logged[key] is Map && (logged[key] as Map)[origin] == true;
                                    if (done) continue;
                                    final ev = events[v["gesture"]?.toString() ?? ""];
                                    if (ev == null) { mark.set("history_logged.$key.$origin", true); dirty = true; continue; }
                                    try {
                                        await _writeClanLog(origin, cs, region, ev, userId: me,
                                            adminId: v["by"]?.toString() ?? "",
                                            data: Dvidle({"playerId": me, "by": v["by"]?.toString() ?? "",
                                                          "clanId": v["clanId"]?.toString() ?? "",
                                                          "at": v["at"]?.toString() ?? ""}));
                                        mark.set("history_logged.$key.$origin", true);
                                        dirty = true;
                                    } catch (_) {}
                                }
                                if (dirty) await _gshipWrite(me, secret, mark);
    }

    // Clan d'origine devenu inactif (dissous) alors que l'enfant a d'autres clans : le clan d'un
    // co-représentant où il est membre devient son clan d'origine (users.first_clan + la fiche
    // `original_clan` de chaque clan actif). Sans co-représentant, rien ne change ici : le
    // serveur a déjà traité la cascade.
    Future<void> _gshipRehome(Dvidle g, Dvidle? session) async {

                                final origin = session?.get("first_clan")?.toString() ?? "";
                                if (origin.isEmpty || _isActiveMemberOf(session, origin)) return;
                                final active = _activeClans(session);
                                if (active.isEmpty) return;
                                final cos = _gshipReps(g).skip(1).toSet();
                                String target = "";
                                for (final c in active) {
                                    final via = g.get("clans.${c["id"]}.via")?.toString() ?? "";
                                    if (cos.contains(via)) { target = c["id"]!; break; }
                                }
                                if (target.isEmpty) return;
                                final region = await _homeRegion();
                                final me     = _authUserId.isNotEmpty ? _authUserId : _userId;
                                try {
                                    final u = Dvidle({});
                                    u.set("first_clan", target);
                                    await _cloud?.write("workers", "users", _sessionDocId(), u, region: region);
                                    _invalidateSessionCache();
                                    for (final c in active) {
                                        final f = Dvidle({});
                                        f.set("id", me);
                                        f.set("original_clan", target);
                                        await _cloud?.write("workers", "clans_players/${c["id"]}/players", me, f,
                                            region: region, ownerId: c["secret"]);
                                    }
                                    deva_log("info", "[guardian] clan d'origine $origin disparu → $target");
                                } catch (e) {
                                    deva_log("error", "[guardian] _gshipRehome FAILED: $e");
                                }
    }

    // Copie LOCALE de ce qui sert à filtrer les notifications à la réception (§ 6.4) : les clans
    // retirés et le retrait du consentement. Au disque (store) : c'est tout son intérêt, l'app
    // doit pouvoir refuser un message sans relire la base.
    Future<void> _gshipKeepLocal(Dvidle g) async {

                                final blocked = <String>[];
                                _mcMap(g.get("guest_auth")).forEach((k, v) {
                                    if (v is Map && (v["revoked_at"]?.toString() ?? "").isNotEmpty) blocked.add(k);
                                });
                                final withdrawn = _gshipConsentWithdrawn(g) ? "true" : "false";
                                final prevB = (await deva_get("worker.gship_blocked"))?.toString() ?? "";
                                final prevW = (await deva_get("worker.gship_withdrawn"))?.toString() ?? "";
                                final nextB = blocked.join(",");
                                if (prevB == nextB && prevW == withdrawn) return;
                                await deva_set("worker.gship_blocked", nextB);
                                await deva_set("worker.gship_withdrawn", withdrawn);
                                await Deva.instance.store();
    }

    // Un message d'un clan doit-il être montré ? Non si ce clan a été retiré à l'enfant, ou si
    // son consentement est retiré. Appelée par le filtre de dvmessaging, AVANT tout affichage.
    Future<bool> _gshipAllowsMessage(String clanId) async {

                                if ((await deva_get("worker.gship_withdrawn"))?.toString() == "true") return false;
                                if (clanId.isEmpty) return true;
                                final blocked = ((await deva_get("worker.gship_blocked"))?.toString() ?? "").split(",");
                                return !blocked.contains(clanId);
    }

    // Vigilance sur MA représentation (enfant) : un geste d'un représentant s'applique sans
    // attendre la prochaine ouverture.
    void _startGshipVigilance(String secret) {

                                final me = _authUserId.isNotEmpty ? _authUserId : _userId;
                                if (secret.isEmpty || me.isEmpty) return;
                                if (_gshipVigilance != null && _gshipVigilanceId == me) return;
                                _stopGshipVigilance();
                                _homeRegion().then((region) {
                                    if (region.isEmpty) return;
                                    _gshipVigilanceId = me;
                                    _gshipVigilance = _cloud?.watch("workers", "guardianship", me, (doc, reason) {
                                        if (reason != DvWatchReason.changed || doc == null) return;
                                        _applyGuardianship();
                                    }, region: region, ownerId: secret,
                                       strategy: DvWatchStrategy.fibonacci(baseMs: 5000, maxMs: 120000));
                                });
    }

    void _stopGshipVigilance() {

                                _gshipVigilance?.stop();
                                _gshipVigilance   = null;
                                _gshipVigilanceId = "";
    }

    // À l'entrée dans un clan (login, bascule) : l'enfant représenté applique, puis surveille.
    // Rend true si le clan courant vient d'être quitté.
    Future<bool> _gshipOnEnter() async {

                                final me = _authUserId.isNotEmpty ? _authUserId : _userId;
                                final secret = (await _gshipSecrets())[me] ?? "";
                                if (secret.isEmpty) return false;
                                final left = await _applyGuardianship();
                                if (!left) _startGshipVigilance(secret);
                                return left;
    }

    // CÔTÉ REPRÉSENTANT : échéance d'un retrait du consentement atteinte → exécution réclamée à
    // delete_user_data (qui revérifie tout), que l'app de l'enfant ait appliqué ou non.
    Future<void> _sweepGuardianConsents() async {

                                try {
                                    for (final w in await _myWards()) {
                                        final g = w["g"] as Dvidle;
                                        if (!_gshipConsentWithdrawn(g)) continue;
                                        final at = DateTime.tryParse(g.get("consent.withdrawn_at")?.toString() ?? "");
                                        if (at == null) continue;
                                        if (at.add(const Duration(days: _kConsentGraceDays)).isAfter(DateTime.now().toUtc())) continue;
                                        final id = w["id"] as String;
                                        if (_consentSwept.contains(id)) continue;
                                        _consentSwept.add(id);
                                        try {
                                            final res = await _cloud?.call("delete_user_data", Dvidle({"consentTarget": id}));
                                            deva_log("info", "[consent] échéance atteinte sur $id → suppression réclamée (ok=${res?.get('ok')})");
                                        } catch (e) {
                                            deva_log("error", "[consent] suppression réclamée sur $id FAILED: $e");
                                        }
                                    }
                                } catch (e) {
                                    deva_log("warning", "[consent] _sweepGuardianConsents: $e");
                                }
    }

    // -----------------------------------------------------------------------
    // --- Écran « Mes enfants » (représentant)
    // -----------------------------------------------------------------------

    Future<void> open_guardian_hub(dynamic caller, dynamic event) async {

                                DvOrb.navigate_new("guardian_hub_page");
    }

    Future<void> on_guardian_hub_appear(dynamic caller, dynamic event) async {

                                final wards = await _myWards();
                                final has   = wards.isNotEmpty;
                                String desc(String key) => TranslationRegistry.translate(has ? key : "guardian_hub_no_ward");
                                final rows = <Map<String, dynamic>>[
                                    {"id": "guest_auth", "label": TranslationRegistry.translate("guardian_hub_guest_auth"),
                                     "desc": desc("guardian_hub_guest_auth_desc"), "icon": "face", "enabled": has},
                                    {"id": "ward_clans", "label": TranslationRegistry.translate("guardian_hub_ward_clans"),
                                     "desc": desc("guardian_hub_ward_clans_desc"), "icon": "face", "enabled": has},
                                    {"id": "cog_add",    "label": TranslationRegistry.translate("guardian_hub_cog_add"),
                                     "desc": desc("guardian_hub_cog_add_desc"), "icon": "group_add", "enabled": has},
                                    {"id": "cog_become", "label": TranslationRegistry.translate("guardian_hub_cog_become"),
                                     "desc": TranslationRegistry.translate("guardian_hub_cog_become_desc"), "icon": "share"},
                                ];
                                ActionRegistry.get("dvlist.set_rows")?.call(null, {"page": "guardian_hub_page", "rows": rows});
    }

    Future<void> on_guardian_hub_pick(dynamic caller, dynamic event) async {

                                final id = (event is Map ? event["id"]?.toString() : null) ?? "";
                                switch (id) {
                                    case "guest_auth":
                                    case "cog_add":
                                        await _scanGuardianRequest(id == "guest_auth" ? "guest" : "cog");
                                        break;
                                    case "ward_clans":
                                        _guardReq  = null;
                                        _wardMode  = "clans";
                                        _wardChild = "";
                                        _wardArmed = "";
                                        DvOrb.navigate_new("ward_pick_page");
                                        break;
                                    case "cog_become":
                                        await _openGuardianQr("cog");
                                        break;
                                }
    }

    // Le représentant scanne le QR code montré par l'autre adulte (chef de B, ou candidat
    // co-représentant). Un code qui n'est pas du type attendu est ignoré, avec un message.
    Future<void> _scanGuardianRequest(String expected) async {

                                await deva_set("commons.qrcodereader.result", "");
                                final fut = ActionRegistry.get("qrcodereader.scan")?.call(null, null);
                                if (fut is Future) await fut;
                                final content = (await deva_get("commons.qrcodereader.result"))?.toString() ?? "";
                                if (content.isEmpty) return;
                                final req = _parseGuardianUri(content);
                                if (req == null || req["t"] != expected) {
                                    await _revealLabel("guardian_hub_page/error", "guardian_scan_wrong");
                                    return;
                                }
                                _hideShapes(["guardian_hub_page/error"]);
                                await _openGuardianRequest(req);
    }

    // Décode ddust://guestreq?d=… ou ddust://cogreq?d=… (base64url d'un JSON). Rend null si ce
    // n'en est pas un, s'il est incomplet ou échu.
    Map<String, dynamic>? _parseGuardianUri(String content) {

                                final uri = Uri.tryParse(content.trim());
                                if (uri == null || uri.scheme != "ddust") return null;
                                if (uri.host != "guestreq" && uri.host != "cogreq") return null;
                                try {
                                    final d   = uri.queryParameters["d"] ?? "";
                                    final raw = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(d))));
                                    if (raw is! Map) return null;
                                    return _checkGuardianPayload(Map<String, dynamic>.from(raw));
                                } catch (_) {
                                    return null;
                                }
    }

    Map<String, dynamic>? _checkGuardianPayload(Map<String, dynamic> p) {

                                final t = p["t"]?.toString() ?? "";
                                final exp = DateTime.tryParse(p["exp"]?.toString() ?? "");
                                if (exp != null && DateTime.now().toUtc().isAfter(exp.toUtc())) return null;
                                if (t == "guest") {
                                    if ((p["c"]?.toString() ?? "").isEmpty) return null;
                                    return p;
                                }
                                if (t == "cog") {
                                    if ((p["u"]?.toString() ?? "").isEmpty || (p["d"]?.toString() ?? "").isEmpty
                                        || (p["k"]?.toString() ?? "").isEmpty) return null;
                                    return p;
                                }
                                return null;
    }

    // Une demande d'adulte reçue (QR scanné, ou lien + code) : choix de l'enfant.
    Future<void> _openGuardianRequest(Map<String, dynamic> req) async {

                                final region = await _homeRegion();
                                final r = req["r"]?.toString() ?? "";
                                if (r.isNotEmpty && region.isNotEmpty && r != region) {
                                    await _revealLabel("guardian_hub_page/error", "clan_other_region");
                                    return;
                                }
                                _guardReq  = req;
                                _wardMode  = req["t"]?.toString() ?? "";
                                _wardChild = "";
                                _wardArmed = "";
                                DvOrb.navigate_new("ward_pick_page");
    }

    // -----------------------------------------------------------------------
    // --- Écran de choix de l'enfant (représentant)
    // -----------------------------------------------------------------------

    Future<void> on_ward_pick_appear(dynamic caller, dynamic event) async {

                                final req = _guardReq;
                                String hint;
                                if (_wardMode == "guest" && req != null) {
                                    hint = TranslationRegistry.translate("ward_pick_guest_hint")
                                        .replaceAll("{clan}",  req["n"]?.toString() ?? "")
                                        .replaceAll("{chief}", req["h"]?.toString() ?? "");
                                } else if (_wardMode == "cog" && req != null) {
                                    hint = TranslationRegistry.translate("ward_pick_cog_hint")
                                        .replaceAll("{name}", req["n"]?.toString() ?? "");
                                } else if (_wardChild.isNotEmpty) {
                                    hint = TranslationRegistry.translate("ward_clans_hint");
                                } else {
                                    hint = TranslationRegistry.translate("ward_pick_clans_hint");
                                }
                                final h = await DvOrb.wait_for_shape("ward_pick_page/hint");
                                if (h != null) {
                                    h.set("shape.label", hint);
                                    if (h is DvLabel) await h.computeDisplay();
                                    h.refreshUI();
                                }
                                await _pushWardRows();
    }

    Future<void> _pushWardRows() async {

                                final rows = <Map<String, dynamic>>[];
                                if (_wardMode == "clans" && _wardChild.isNotEmpty) {
                                    // Les clans de l'enfant choisi : tap = armer le retrait, second tap = retirer.
                                    final w = await _asGuardianOf(_wardChild);
                                    final g = w?.$1;
                                    final clans = _mcMap(g?.get("clans"));
                                    {
                                        clans.forEach((k, v) {
                                            if (v is! Map) return;
                                            if ((v["left_at"]?.toString() ?? "").isNotEmpty) return;
                                            final id = k.toString();
                                            final origin = v["origin"] == true;
                                            final armed  = _wardArmed == id;
                                            rows.add({
                                                "id":      id,
                                                "label":   v["clan_name"]?.toString() ?? "",
                                                "desc":    origin
                                                    ? TranslationRegistry.translate("ward_clans_origin")
                                                    : TranslationRegistry.translate(armed ? "ward_clans_confirm" : "ward_clans_chief")
                                                        .replaceAll("{chief}", v["chief_name"]?.toString() ?? ""),
                                                "icon":    origin ? "face" : "block",
                                                "enabled": !origin,
                                                if (armed) "color": "0xFFCC4444",
                                            });
                                        });
                                    }
                                } else {
                                    for (final w in await _myWards()) {
                                        rows.add({"id": w["id"], "label": (w["name"] as String).isNotEmpty ? w["name"] : "?", "icon": "face"});
                                    }
                                }
                                ActionRegistry.get("dvlist.set_rows")?.call(null, {"page": "ward_pick_page", "rows": rows});
    }

    Future<void> on_ward_pick(dynamic caller, dynamic event) async {

                                final id = (event is Map ? event["id"]?.toString() : null) ?? "";
                                if (id.isEmpty) return;
                                switch (_wardMode) {
                                    case "guest": await _authorizeGuestClan(id); break;
                                    case "cog":   await _addCoGuardian(id);      break;
                                    case "clans":
                                        if (_wardChild.isEmpty) {
                                            _wardChild = id;
                                            _wardArmed = "";
                                            await on_ward_pick_appear(null, null);
                                            return;
                                        }
                                        if (_wardArmed != id) {
                                            _wardArmed = id;
                                            await _pushWardRows();
                                            return;
                                        }
                                        await _revokeGuestClan(_wardChild, id);
                                        _wardArmed = "";
                                        await _pushWardRows();
                                        break;
                                }
    }

    // AUTORISER UN CLAN (§ 5.1) : guest_auth.{clanB}, 7 jours pour entrer. Rien ne repart vers B.
    Future<void> _authorizeGuestClan(String childId) async {

                                final req = _guardReq;
                                if (req == null) return;
                                final w = await _asGuardianOf(childId);
                                if (w == null) return;
                                final clanB = req["c"]?.toString() ?? "";
                                final now   = DateTime.now().toUtc();
                                final me    = _authUserId.isNotEmpty ? _authUserId : _userId;
                                final patch = Dvidle({});
                                patch.set("guest_auth.$clanB.clan_name",  req["n"]?.toString() ?? "");
                                patch.set("guest_auth.$clanB.chief_name", req["h"]?.toString() ?? "");
                                patch.set("guest_auth.$clanB.region",     req["r"]?.toString() ?? "");
                                patch.set("guest_auth.$clanB.by",         me);
                                patch.set("guest_auth.$clanB.at",         now.toIso8601String());
                                patch.set("guest_auth.$clanB.expires_at", now.add(const Duration(days: _kGuestAuthDays)).toIso8601String());
                                patch.set("guest_auth.$clanB.used_at",    "");
                                patch.set("guest_auth.$clanB.revoked_at", "");
                                final ok = await _gshipGesture(childId, w.$2, "guest_authorized", clanId: clanB, patch: patch);
                                _guardReq = null;
                                DvOrb.navigate_back();
                                await _revealLabel("guardian_hub_page/error", ok ? "ward_guest_done" : "ward_error");
    }

    // RETIRER L'ENFANT D'UN CLAN (§ 6.1) : revoked_at ; l'app de l'enfant fait le reste.
    Future<void> _revokeGuestClan(String childId, String clanId) async {

                                final w = await _asGuardianOf(childId);
                                if (w == null) return;
                                final me    = _authUserId.isNotEmpty ? _authUserId : _userId;
                                final now   = DateTime.now().toUtc().toIso8601String();
                                final patch = Dvidle({});
                                patch.set("guest_auth.$clanId.revoked_at", now);
                                if ((w.$1.get("guest_auth.$clanId.by")?.toString() ?? "").isEmpty) {
                                    patch.set("guest_auth.$clanId.by", me);
                                    patch.set("guest_auth.$clanId.at", now);
                                }
                                await _gshipGesture(childId, w.$2, "guest_revoked", clanId: clanId, patch: patch);
    }

    // AJOUTER UN CO-REPRÉSENTANT (§ 5.3) : guardians += candidat, puis dépôt du secret dans SA
    // boîte (guardian_drops/{d}), chiffré par la clef qu'il a lui-même tirée (QR ou lien + code).
    Future<void> _addCoGuardian(String childId) async {

                                final req = _guardReq;
                                if (req == null) return;
                                final w = await _asGuardianOf(childId);
                                if (w == null) return;
                                final cand = req["u"]?.toString() ?? "";
                                if (cand.isEmpty) return;
                                final g = w.$1;
                                final cos = <String>[..._gshipReps(g).skip(1), if (!_gshipReps(g).contains(cand)) cand];
                                final patch = Dvidle({});
                                patch.set("guardians", cos);
                                final ok = await _gshipGesture(childId, w.$2, "guardian_added",
                                    extra: {"guardian": cand, "guardian_name": req["n"]?.toString() ?? ""}, patch: patch);
                                if (ok) {
                                    final lobby = ModuleRegistry.create("dvvirtuallobby");
                                    final region = await _homeRegion();
                                    if (lobby != null) {
                                        final token = (lobby as dynamic).sealInvite(<String, dynamic>{
                                            "s": w.$2, "c": childId, "cn": g.get("name")?.toString() ?? "", "r": region,
                                        }, req["k"].toString()) as String;
                                        try {
                                            await _cloud?.write("workers", "guardian_drops", req["d"].toString(), Dvidle({
                                                "token":      token,
                                                "expiration": DateTime.now().toUtc().add(const Duration(days: _kGuardianPendingDays)),
                                            }), region: region, ownerId: "drop");
                                        } catch (e) {
                                            deva_log("error", "[guardian] dépôt du secret FAILED: $e");
                                        }
                                    }
                                }
                                _guardReq = null;
                                DvOrb.navigate_back();
                                await _revealLabel("guardian_hub_page/error", ok ? "ward_cog_done" : "ward_error");
    }

    // -----------------------------------------------------------------------
    // --- Écran QR des échanges entre adultes
    // -----------------------------------------------------------------------

    // Chef de B : « Accueillir un enfant d'un autre clan ».
    Future<void> on_welcome_guest_child(dynamic caller, dynamic event) async {

                                if ((await _clanIdIfChief("on_welcome_guest_child")).isEmpty) return;
                                await _openGuardianQr("guest");
    }

    Future<void> _openGuardianQr(String mode) async {

                                _gqrMode  = mode;
                                _gqrToken = "";
                                _gqrDrop  = null;
                                if (mode == "cog") {
                                    _gqrDropId  = _generateUuid();
                                    _gqrDropKey = _generateUuid().replaceAll("-", "");
                                }
                                DvOrb.navigate_new("guardian_qr_page");
    }

    // Construit la charge du QR code selon le mode. Aucune donnée d'enfant : le chef de B ne
    // sait pas qui viendra, le candidat ne connaît pas encore l'enfant.
    Future<Map<String, dynamic>> _gqrPayload() async {

                                final region = await _homeRegion();
                                final name   = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                final exp    = DateTime.now().toUtc().add(const Duration(hours: 72)).toIso8601String();
                                if (_gqrMode == "guest") {
                                    final session = await _readSession(region);
                                    final clanId  = session?.get("steps.clan.clanId")?.toString() ?? "";
                                    final clanN   = (await Deva.instance.get("session.clan.name"))?.toString() ?? "";
                                    return {"v": 1, "t": "guest", "c": clanId, "n": clanN, "h": name, "r": region, "exp": exp};
                                }
                                final me = _authUserId.isNotEmpty ? _authUserId : _userId;
                                return {"v": 1, "t": "cog", "u": me, "n": name, "d": _gqrDropId, "k": _gqrDropKey, "r": region, "exp": exp};
    }

    Future<void> on_guardian_qr_appear(dynamic caller, dynamic event) async {

                                final p    = await _gqrPayload();
                                final host = _gqrMode == "guest" ? "guestreq" : "cogreq";
                                final d    = base64Url.encode(utf8.encode(jsonEncode(p))).replaceAll("=", "");
                                final qr   = await DvOrb.wait_for_shape("guardian_qr_page/qrcode");
                                qr?..set("shape.content", "ddust://$host?d=$d")..refreshUI();
                                final intro = DvOrb.get_shape_by_id("guardian_qr_page/intro");
                                if (intro != null) {
                                    intro.set("shape.label", TranslationRegistry.translate(
                                        _gqrMode == "guest" ? "guardian_qr_guest_intro" : "guardian_qr_cog_intro"));
                                    if (intro is DvLabel) await intro.computeDisplay();
                                    intro.refreshUI();
                                }
                                _hideShapes(["guardian_qr_page/code", "guardian_qr_page/share", "guardian_qr_page/confirm"]);
                                if (_gqrMode == "cog") _startDropWatch();
    }

    // À distance : un code à 6 chiffres affiché, à dicter, et un lien à partager
    // (ddust://invitepin?token=…, le même que l'invitation d'un clan). Le code n'est jamais dans le lien.
    Future<void> on_guardian_qr_remote(dynamic caller, dynamic event) async {

                                final lobby = ModuleRegistry.create("dvvirtuallobby");
                                if (lobby == null) return;
                                final pin = (lobby as dynamic).generatePin() as String;
                                _gqrToken = (lobby as dynamic).sealInvite(await _gqrPayload(), pin) as String;
                                final code = DvOrb.get_shape_by_id("guardian_qr_page/code");
                                if (code != null) {
                                    code.set("shape.label", TranslationRegistry.translate("guardian_qr_code").replaceAll("{code}", pin));
                                    code.set("shape.visible", true);
                                    if (code is DvLabel) await code.computeDisplay();
                                    code.refreshUI();
                                }
                                DvOrb.get_shape_by_id("guardian_qr_page/share")?..set("shape.visible", true)..refreshUI();
    }

    Future<void> on_guardian_qr_share(dynamic caller, dynamic event) async {

                                if (_gqrToken.isEmpty) return;
                                await deva_set("worker.guardian_out_token", _gqrToken);
                                try {
                                    final fut = ActionRegistry.get("share.guardian_link")?.call(caller, event);
                                    if (fut is Future) await fut;
                                } finally {
                                    await deva_set("worker.guardian_out_token", "");
                                }
    }

    // CANDIDAT CO-REPRÉSENTANT : attend le dépôt du secret dans sa boîte.
    void _startDropWatch() {

                                _stopDropWatch();
                                final id = _gqrDropId;
                                if (id.isEmpty) return;
                                _homeRegion().then((region) {
                                    if (region.isEmpty) return;
                                    _dropVigilance = _cloud?.watch("workers", "guardian_drops", id, (doc, reason) {
                                        if (doc == null) return;
                                        _onDropArrived(doc);
                                    }, region: region, ownerId: "drop",
                                       strategy: DvWatchStrategy.fibonacci(baseMs: 3000, maxMs: 20000));
                                });
    }

    void _stopDropWatch() {

                                _dropVigilance?.stop();
                                _dropVigilance = null;
    }

    Future<void> _onDropArrived(Dvidle doc) async {

                                if (_gqrDrop != null) return;
                                final token = doc.get("token")?.toString() ?? "";
                                final lobby = ModuleRegistry.create("dvvirtuallobby");
                                if (token.isEmpty || lobby == null) return;
                                final p = (lobby as dynamic).openInvite(token, _gqrDropKey) as Map?;
                                if (p == null) return;
                                _gqrDrop = Map<String, dynamic>.from(p);
                                _stopDropWatch();
                                // La DÉCLARATION du candidat : il confirme être représentant légal de l'enfant.
                                final intro = DvOrb.get_shape_by_id("guardian_qr_page/intro");
                                if (intro != null) {
                                    intro.set("shape.label", TranslationRegistry.translate("guardian_cog_declare")
                                        .replaceAll("{name}", p["cn"]?.toString() ?? ""));
                                    if (intro is DvLabel) await intro.computeDisplay();
                                    intro.refreshUI();
                                }
                                _hideShapes(["guardian_qr_page/qrcode", "guardian_qr_page/code",
                                             "guardian_qr_page/share", "guardian_qr_page/remote"]);
                                DvOrb.get_shape_by_id("guardian_qr_page/confirm")?..set("shape.visible", true)..refreshUI();
    }

    // Le candidat confirme : le secret rejoint SON index, sa déclaration entre dans l'historique
    // (sous son identifiant), la boîte est vidée.
    Future<void> on_guardian_qr_confirm(dynamic caller, dynamic event) async {

                                final p = _gqrDrop;
                                if (p == null) return;
                                final uid     = _cloud?.currentUser()?.providerUid ?? "";
                                final region  = await _homeRegion();
                                final childId = p["c"]?.toString() ?? "";
                                final secret  = p["s"]?.toString() ?? "";
                                if (uid.isEmpty || childId.isEmpty || secret.isEmpty) return;
                                try {
                                    final ix = Dvidle({});
                                    ix.set("guardianships.$childId.secret", secret);
                                    await _cloud?.write("workers", "userindexes", uid, ix, region: region);
                                    await _gshipGesture(childId, secret, "guardian_declared");
                                    await _cloud?.delete("workers", "guardian_drops", _gqrDropId, region: region, ownerId: "drop");
                                } catch (e) {
                                    deva_log("error", "[guardian] confirmation du co-représentant FAILED: $e");
                                }
                                _gqrDrop = null;
                                DvOrb.navigate_back();
    }

    Future<void> on_guardian_qr_leave(dynamic caller, dynamic event) async {

                                _stopDropWatch();
                                _gqrToken = "";
                                _gqrDrop  = null;
    }

    // -----------------------------------------------------------------------
    // --- Gestes des représentants sur la tuile d'un enfant (D16)
    // -----------------------------------------------------------------------

    // Options de la tuile d'un enfant REPRÉSENTÉ, pour son représentant (chef ou non). Rend null
    // si ce n'est pas un enfant que je représente.
    Future<Map<String, dynamic>?> _wardRosterOptions(Map m) async {

                                final id = m["id"]?.toString() ?? "";
                                if (id.isEmpty || m["no_account"] == true) return null;
                                final w = await _asGuardianOf(id);
                                if (w == null) return null;
                                final g = w.$1;
                                final sel = <String>[];
                                if (_gshipConsentWithdrawn(g)) {
                                    sel.add("restore_consent");
                                } else {
                                    final legal = m["legal_state"]?.toString() ?? "";
                                    if ((g.get("majority.declared_at")?.toString() ?? "").isEmpty && legal != "a" && legal != "t") {
                                        sel.add("promote_adult");
                                    }
                                    sel.add("withdraw_consent");
                                }
                                return {"selectable": sel};
    }

    // Retrait / rétablissement du consentement, déclaration de majorité : dans guardianship.
    Future<bool> _wardConsent(String childId, bool withdraw) async {

                                final w = await _asGuardianOf(childId);
                                if (w == null) return false;
                                if (withdraw == _gshipConsentWithdrawn(w.$1)) return true;
                                final me    = _authUserId.isNotEmpty ? _authUserId : _userId;
                                final now   = DateTime.now().toUtc().toIso8601String();
                                final patch = Dvidle({});
                                if (withdraw) {
                                    patch.set("consent.withdrawn_at", now);
                                } else {
                                    patch.set("consent.restored_at", now);
                                    _consentSwept.remove(childId);
                                }
                                patch.set("consent.by", me);
                                return _gshipGesture(childId, w.$2, withdraw ? "consent_withdrawn" : "consent_restored", patch: patch);
    }

    Future<bool> _wardDeclareMajor(String childId) async {

                                final w = await _asGuardianOf(childId);
                                if (w == null) return false;
                                final me    = _authUserId.isNotEmpty ? _authUserId : _userId;
                                final patch = Dvidle({});
                                patch.set("majority.declared_at", DateTime.now().toUtc().toIso8601String());
                                patch.set("majority.by", me);
                                return _gshipGesture(childId, w.$2, "majority_declared", patch: patch);
    }

    // CÔTÉ ENFANT, à l'acceptation de la CGU adulte : `a` sur toutes ses fiches, puis la
    // représentation se ferme (§ 6.3). Rien si aucun représentant n'a déclaré la majorité.
    Future<void> _gshipMajorityDone(String region) async {

                                final me = _authUserId.isNotEmpty ? _authUserId : _userId;
                                final secret = (await _gshipSecrets())[me] ?? "";
                                if (secret.isEmpty) return;
                                final g = await _gshipRead(me, secret);
                                if (g == null || _gshipClosed(g)) return;
                                if ((g.get("majority.declared_at")?.toString() ?? "").isEmpty) return;
                                final session = await _readSession(region);
                                for (final c in _activeClans(session)) {
                                    try {
                                        final f = Dvidle({});
                                        f.set("id", me);
                                        f.set("legal_state", "a");
                                        await _cloud?.write("workers", "clans_players/${c["id"]}/players", me, f,
                                            region: region, ownerId: c["secret"]);
                                    } catch (e) {
                                        deva_log("error", "[guardian] majorité sur ${c["id"]} FAILED: $e");
                                    }
                                }
                                final close = Dvidle({});
                                close.set("closed_at", DateTime.now().toUtc().toIso8601String());
                                await _gshipWrite(me, secret, close);
                                _stopGshipVigilance();
                                await deva_set("worker.gship_blocked", "");
                                await deva_set("worker.gship_withdrawn", "false");
    }

    // Suppression du compte refusée parce que le joueur est le SEUL représentant d'un enfant
    // (delete_user_data, « Sole guardian »). Rend les prénoms concernés, pour le message.
    Future<String> _soleGuardianNames(dynamic error) async {

                                final msg = error.toString();
                                if (!msg.contains("Sole guardian")) return "";
                                final names = <String>[];
                                for (final w in await _myWards()) {
                                    final g = w["g"] as Dvidle;
                                    if (_gshipReps(g).length <= 1) names.add((w["name"] as String).isNotEmpty ? w["name"] as String : "?");
                                }
                                return names.isEmpty ? "?" : names.join(", ");
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
