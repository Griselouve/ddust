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

// Durée de vie d'une boîte d'adhésion : le code affiché sous le QR code, le temps de le dicter
// au téléphone et de lire les conditions. La règle Firestore la borne à 30 minutes (marge pour
// une horloge de téléphone en avance).
const int _kJoinBoxMinutes = 15;

// Liste blanche des textes qu'un accord d'enfant peut désigner. Le chef AFFICHE le texte nommé par
// la boîte : sans cette liste, une boîte fabriquée ferait lire au chef n'importe quelle phrase de
// l'application, au moment précis où il s'engage.
const List<String> _kAssentTextKeys = ["kid_assent_question"];

// -----------------------------------------------------------------------------
// --- worker extension : l'adhésion à un clan (« montrer patte blanche »)
// -----------------------------------------------------------------------------
//
// LE CANDIDAT MONTRE, LE CHEF SCANNE (refonte du 2026-10-18). Une seule façon d'entrer dans un
// clan, pour un adulte comme pour un enfant :
//   1. le candidat touche « Rejoindre un clan » (un enfant répond d'abord à SA question,
//      kid_assent_screen : il parle le premier, son parent décide ensuite) ;
//   2. son écran (join_show_screen) affiche un QR code à usage unique et, dessous, un code de
//      cinq caractères (« 48E-D8 ») à dicter quand le chef est loin ;
//   3. le chef scanne le QR code, ou saisit le code (« Accueillir un joueur ») ; il voit si c'est
//      un adulte ou un enfant, lit les conditions qui s'appliquent et valide ;
//   4. le secret du clan part dans la boîte, CHIFFRÉ POUR LE SEUL TÉLÉPHONE DU CANDIDAT
//      (dvsealbox : X25519 + ChaCha20-Poly1305), qui la surveille, la lit et entre.
//
// LA BOÎTE, workers/clans_joins/{code} (règles : backend/config.yml). Créée par le candidat, elle
// ne porte AUCUNE donnée personnelle : sa clé publique, son état légal, les métadonnées de
// l'accord d'un enfant, sa région. Le premier chef qui la réclame (`seen`) est le seul à pouvoir
// y déposer (`done`) ou renoncer (`cancelled`) : l'usage unique est tenu par les règles.
//
// ⚠ RIEN SUR LE DISQUE AVANT LE LOGIN. La clé privée, le code, le dépôt reçu vivent en mémoire :
//   un enfant qui ferme l'application perd sa boîte et en ouvrira une neuve. C'est pour cela que
//   la distance passe par un code DICTÉ, pendant un appel : l'échange est synchrone.
//
// ⚠ LE CODE DÉSIGNE LA BOÎTE, IL NE PROTÈGE PAS LE SECRET. Un code se devine ; un dépôt ne
//   s'ouvre qu'avec la clé privée du candidat. Ce qu'un code deviné permet (accueillir un
//   inconnu), la confirmation « c'est bien ta famille ? » le rattrape : elle s'affiche dès que le
//   dépôt ne prouve pas être passé par le QR code (l'aléa `t`, présent dans le QR et jamais dans
//   la boîte, recopié par le chef dans son dépôt).
extension Worker_join on worker {

    void _register_join() {

                                // --- Candidat : l'écran qui montre patte blanche ---
                                ActionRegistry.register("worker.on_join_show_appear",   on_join_show_appear);
                                ActionRegistry.register("worker.on_join_show_quit",     on_join_show_quit);
                                ActionRegistry.register("worker.on_join_family_yes",    on_join_family_yes);
                                ActionRegistry.register("worker.on_join_family_no",     on_join_family_no);
                                ActionRegistry.register("worker.on_join_show_leave",    on_join_show_leave);

                                // --- Chef : « Accueillir un joueur » ---
                                ActionRegistry.register("worker.on_welcome_player",     on_welcome_player);
                                ActionRegistry.register("worker.on_welcome_scan",       on_welcome_scan);
                                ActionRegistry.register("worker.on_welcome_remote",     on_welcome_remote);
                                ActionRegistry.register("worker.on_welcome_code_go",    on_welcome_code_go);
                                ActionRegistry.register("worker.on_welcome_cancel",     (c, e) async => DvOrb.navigate_back());
                                // Le QR code ouvert par l'appareil photo du téléphone (lien ddust://join).
                                ActionRegistry.register("worker.on_join_link",          (c, e) async { if (e is Map) await on_join_link(c, e); });

                                // --- Chef (et représentant) : l'écran de déclaration, en phases ---
                                ActionRegistry.register("worker.on_invite_consent_appear", on_invite_consent_appear);
                                ActionRegistry.register("worker.on_invite_consent_quit",   on_invite_consent_quit);
                                ActionRegistry.register("worker.on_invite_reads",          (c, e) async { await _invitePickReading("child_reads"); });
                                ActionRegistry.register("worker.on_invite_aloud",          (c, e) async { await _invitePickReading("child_read_aloud"); });
                                ActionRegistry.register("worker.on_invite_chief_toggle",   on_invite_chief_toggle);
                                ActionRegistry.register("worker.on_confirm_invite_consent", on_confirm_invite_consent);
                                ActionRegistry.register("worker.on_cancel_invite_consent",  on_cancel_invite_consent);
                                ActionRegistry.register("worker.on_claim_pick_quit",        on_claim_pick_quit);
    }

    // -----------------------------------------------------------------------
    // --- Côté CANDIDAT
    // -----------------------------------------------------------------------

    // L'accord de l'enfant : ce qu'il a lu, et quand il a dit oui. Posé par kid_assent_route au
    // moment exact du oui, il voyage dans la boîte jusqu'au parent, qui le voit avant de décider,
    // puis dans la déclaration scellée du parent jusqu'au dossier de l'enfant.
    // ⚠ AUCUNE DONNÉE PERSONNELLE : la date, la langue et le royaume dans lesquels il a lu, le
    //   texte qu'on lui a montré et la version des conditions qu'il vient d'accepter.
    Future<Map<String, dynamic>> _buildJoinAssent() async => <String, dynamic>{

                                    "v":           1,
                                    "date":        DateTime.now().toUtc().toIso8601String(),
                                    "lang":        TranslationRegistry.currentLang,
                                    "region":      (await Deva.instance.get("documents.session.region"))?.toString() ?? "",
                                    "text_key":    "kid_assent_question",
                                    "cgu_version": (await deva_get("documents.acceptance.cgu.version"))?.toString() ?? "",
                                };

    // Tout l'état d'une adhésion côté candidat, oublié d'un coup : déconnexion, admission,
    // parcours remis à zéro. La boîte en cours, s'il y en a une, est effacée.
    Future<void> _joinForget() async {

                                await _joinStop(deleteBox: true);
                                _joinAssent  = null;
                                _joinDeposit = null;
                                _joinRepAck  = "";
                                _joinFamily  = null;
    }

    // Coupe la surveillance de la boîte et sa minuterie ; l'efface si demandé (et si aucun dépôt
    // n'y attend encore d'être lu : un dépôt lu est déjà effacé).
    Future<void> _joinStop({bool deleteBox = false}) async {

                                _joinBoxVigil?.stop();
                                _joinBoxVigil = null;
                                _joinExpiryTimer?.cancel();
                                _joinExpiryTimer = null;
                                final code = _joinCode;
                                _joinCode  = "";
                                _joinNonce = "";
                                _joinKey   = null;
                                if (deleteBox && code.isNotEmpty) await _joinBoxDelete(code);
    }

    Future<void> _joinBoxDelete(String code) async {

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                if (region.isEmpty || code.isEmpty) return;
                                try {
                                    await _cloud?.delete("workers", "clans_joins", code, region: region, ownerId: "join");
                                } catch (e) {
                                    // Sans gravité : le TTL la fera disparaître.
                                    deva_log("warning", "[join] boîte $code non effacée ($e)");
                                }
    }

    // « 48ED8 » → « 48E-D8 » : deux groupes, pour la lire et la dicter sans se perdre.
    String _joinShowCode(String code) =>
        code.length == 5 ? "${code.substring(0, 3)}-${code.substring(3)}" : code;

    // Ce qu'un chef a tapé : majuscules, sans tirets ni espaces, et seulement l'alphabet des codes.
    String _joinNormCode(String raw) {

                                final s = raw.toUpperCase().replaceAll(RegExp(r'[\s\-_.]'), "");
                                for (final ch in s.split("")) {
                                    if (!DvSealBox.codeAlphabet.contains(ch)) return "";
                                }
                                return s.length == 5 ? s : "";
    }

    // ⚠ `dynamic caller` : l'appear d'une PAGE passe un DvPage, qui n'est pas une shape.
    Future<void> on_join_show_appear(dynamic caller, dynamic event) async {

                                final legalRaw = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                final minor    = _gameplayLegal(legalRaw) != "a";
                                // Un enfant n'arrive ici qu'après SA question. S'il n'y a pas d'accord en
                                // mémoire (application rouverte, mineur connecté et sans clan), il y retourne.
                                if (minor && _joinAssent == null) {
                                    DvOrb.navigate_reset("kid_assent_screen");
                                    return;
                                }
                                await DvOrb.wait_for_shape("join_show_screen/intro");
                                await _revealLabel("join_show_screen/intro", minor ? "join_show_intro_kid" : "join_show_intro_adult");
                                _hideShapes(["join_show_screen/family_yes", "join_show_screen/family_no"]);

                                // Déjà membre d'un clan (multiclan) : une sortie vers son clan. Sinon, encore
                                // anonyme : ce qui l'attend ensuite (la connexion Google).
                                final region = await _homeRegion();
                                Dvidle? session;
                                try { session = region.isNotEmpty && !_anon ? await _readSession(region) : null; } catch (_) {}
                                final hasClan = _activeClans(session).isNotEmpty;
                                DvOrb.get_shape_by_id("join_show_screen/leave")?..set("shape.visible", hasClan)..refreshUI();
                                DvOrb.get_shape_by_id("join_show_screen/notice")?..set("shape.visible", _anon)..refreshUI();

                                // Un message en attente (refus, nouveau code) : affiché une fois.
                                if (_joinNotice.isNotEmpty) {
                                    await _revealLabel("join_show_screen/status", _joinNotice);
                                    _joinNotice = "";
                                } else {
                                    _hideShapes(["join_show_screen/status"]);
                                }

                                // Écran réaffiché avec une boîte encore ouverte : on la remontre, sans en
                                // tirer une autre (son code a peut-être déjà été dicté).
                                if (_joinCode.isNotEmpty && _joinKey != null) {
                                    await _joinPaint();
                                    return;
                                }
                                await _joinOpenBox(hasClan: hasClan);
    }

    // Ouvre une boîte neuve : clé, code, document `open`, QR code, surveillance, minuterie.
    Future<void> _joinOpenBox({bool? hasClan}) async {

                                if (_joinOpening) return;
                                _joinOpening = true;
                                try {
                                    await _joinStop(deleteBox: true);
                                    _joinFamily = null;
                                    final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    if (region.isEmpty || _cloud == null) {
                                        deva_log("error", "[join] pas de région : boîte impossible");
                                        await _revealLabel("join_show_screen/status", "join_show_error");
                                        return;
                                    }
                                    final legalRaw = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                    final legal    = _gameplayLegal(legalRaw) == "a" ? "a" : "k";
                                    var withClan   = hasClan;
                                    if (withClan == null) {
                                        Dvidle? session;
                                        try { session = !_anon ? await _readSession(region) : null; } catch (_) {}
                                        withClan = _activeClans(session).isNotEmpty;
                                    }
                                    final key   = await DvSealBox.newKey();
                                    final nonce = DvSealBox.nonce();
                                    final now   = DateTime.now().toUtc();
                                    final exp   = now.add(const Duration(minutes: _kJoinBoxMinutes));
                                    // Enfant déjà membre d'un clan : de quoi laisser le chef reconnaître l'un
                                    // de SES enfants, sans publier l'identifiant de celui-ci.
                                    final me   = _authUserId.isNotEmpty ? _authUserId : _userId;
                                    final ward = (legal == "k" && withClan && me.isNotEmpty)
                                        ? await DvSealBox.shortHash("ddust-ward:$me") : "";
                                    String code = "";
                                    for (var i = 0; i < 5 && code.isEmpty; i++) {
                                        final c = DvSealBox.code();
                                        try {
                                            final existing = await _cloud?.read("workers", "clans_joins", c,
                                                region: region, ownerId: "join");
                                            if (existing != null) continue;
                                            await _cloud?.write("workers", "clans_joins", c, Dvidle({
                                                "v":            1,
                                                "pk":           key.publicKey,
                                                "legal":        legal,
                                                if (legal == "k" && _joinAssent != null) "assent": _joinAssent,
                                                "cloud_region": region,
                                                "has_clan":     withClan,
                                                if (ward.isNotEmpty) "ward": ward,
                                                "status":       "open",
                                                "created_at":   now.toIso8601String(),
                                                "expires_at":   exp.toIso8601String(),
                                                "expiration":   exp,
                                            }), region: region, ownerId: "join");
                                            code = c;
                                        } catch (e) {
                                            // Code pris entre la lecture et l'écriture, ou refus : on en tire un autre.
                                            deva_log("warning", "[join] boîte $c refusée ($e)");
                                        }
                                    }
                                    if (code.isEmpty) {
                                        await _revealLabel("join_show_screen/status", "join_show_error");
                                        return;
                                    }
                                    _joinKey     = key;
                                    _joinCode    = code;
                                    _joinNonce   = nonce;
                                    _joinHandled = false;
                                    await _joinPaint();
                                    _joinArmExpiry(exp);
                                    _joinBoxVigil = _cloud?.watch("workers", "clans_joins", code, (doc, reason) {
                                        _onJoinBox(code, doc, reason);
                                    }, region: region, ownerId: "join",
                                       strategy: DvWatchStrategy.fibonacci(baseMs: 2000, maxMs: 15000));
                                    // Une vigilance ne rapporte jamais ce qui était là avant elle : un chef très
                                    // rapide aurait pu réclamer la boîte entre l'écriture et l'abonnement.
                                    try {
                                        final now2 = await _cloud?.read("workers", "clans_joins", code, region: region, ownerId: "join");
                                        if (now2 != null) _onJoinBox(code, now2, DvWatchReason.changed);
                                    } catch (_) {}
                                    deva_log("info", "[join] boîte ouverte ($code, ${legal == "a" ? "adulte" : "enfant"})");
                                } finally {
                                    _joinOpening = false;
                                }
    }

    // Le QR code et le code, tels que le chef les verra.
    Future<void> _joinPaint() async {

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                final fp     = await DvSealBox.fingerprint(_joinKey!.publicKey);
                                final link   = "ddust://join?c=$_joinCode&f=$fp&t=$_joinNonce&r=$region";
                                final qr = await DvOrb.wait_for_shape("join_show_screen/qrcode");
                                qr?..set("shape.content", link)..set("shape.visible", true)..refreshUI();
                                final code = DvOrb.get_shape_by_id("join_show_screen/code");
                                if (code != null) {
                                    code.set("shape.label", TranslationRegistry.processLabel("@@@T:join_show_code@@@")
                                        .replaceAll("{code}", _joinShowCode(_joinCode)));
                                    code.set("shape.visible", true);
                                    if (code is DvLabel) await code.computeDisplay();
                                    code.refreshUI();
                                }
    }

    // L'échéance de la boîte : à son terme, tant qu'aucun chef ne l'a réclamée, un code neuf
    // remplace l'ancien sans un mot. Un chef qui lit les conditions repousse l'échéance (seen).
    void _joinArmExpiry(DateTime exp) {

                                _joinExpiryTimer?.cancel();
                                final code = _joinCode;
                                final left = exp.difference(DateTime.now().toUtc());
                                _joinExpiryTimer = Timer(left.isNegative ? Duration.zero : left + const Duration(seconds: 2), () {
                                    if (_joinCode != code || _joinHandled) return;
                                    deva_log("info", "[join] boîte $code échue : nouveau code");
                                    _joinOpenBox();
                                });
    }

    // Chaque changement de la boîte. Idempotent : la lecture qui suit l'abonnement et la
    // vigilance peuvent rapporter le même état.
    Future<void> _onJoinBox(String code, Dvidle? doc, DvWatchReason reason) async {

                                if (code != _joinCode || _joinHandled) return;
                                if (reason == DvWatchReason.deleted || doc == null) {
                                    // Effacée sous nos yeux (TTL, ou par qui connaissait le code) : on en
                                    // ouvre une autre.
                                    if (reason == DvWatchReason.deleted) {
                                        _joinNotice = "join_show_new_code";
                                        await _joinOpenBox();
                                        if (_joinNotice.isNotEmpty) {
                                            await _revealLabel("join_show_screen/status", _joinNotice);
                                            _joinNotice = "";
                                        }
                                    }
                                    return;
                                }
                                final status = doc.get("status")?.toString() ?? "";
                                if (status == "seen") {
                                    // « Les anciens évaluent ta bravoure… » : le chef lit les conditions.
                                    await _revealLabel("join_show_screen/status", "join_show_wait");
                                    final exp = doc.get("expiration");
                                    final at  = exp is DateTime ? exp.toUtc() : DateTime.tryParse(doc.get("expires_at")?.toString() ?? "");
                                    _joinArmExpiry((at ?? DateTime.now().toUtc()).add(const Duration(minutes: _kJoinBoxMinutes)));
                                    return;
                                }
                                if (status == "cancelled") {
                                    _joinHandled = true;
                                    deva_log("info", "[join] le chef a renoncé ($code)");
                                    await _joinOpenBox();
                                    await _revealLabel("join_show_screen/status", "join_show_new_code");
                                    return;
                                }
                                if (status != "done") return;
                                _joinHandled = true;
                                final key   = _joinKey;
                                final nonce = _joinNonce;
                                final sealed = doc.get("sealed")?.toString() ?? "";
                                final deposit = key == null ? null : await DvSealBox.open(key, sealed, context: code);
                                // Le dépôt est lu (ou illisible) : la boîte a servi, elle disparaît.
                                await _joinStop(deleteBox: true);
                                if (deposit == null || deposit["code"]?.toString() != code
                                        || (deposit["clanId"]?.toString() ?? "").isEmpty
                                        || (deposit["clanSecret"]?.toString() ?? "").isEmpty) {
                                    deva_log("warning", "[join] dépôt illisible ($code)");
                                    _joinNotice = "join_show_error";
                                    await _joinOpenBox();
                                    if (_joinNotice.isNotEmpty) {
                                        await _revealLabel("join_show_screen/status", _joinNotice);
                                        _joinNotice = "";
                                    }
                                    return;
                                }
                                final byQr = nonce.isNotEmpty && deposit["t"]?.toString() == nonce;
                                deposit["vector"] = byQr ? "qr" : "code";
                                deva_log("info", "[join] dépôt reçu ($code, par ${byQr ? "QR code" : "code"})");
                                if (byQr) {
                                    await _joinProceed(deposit);
                                    return;
                                }
                                // PAR CODE : le candidat confirme que c'est bien sa famille (son clan). Un
                                // code deviné ne fait entrer personne chez un inconnu sans qu'il le voie.
                                _joinFamily = deposit;
                                await _joinShowFamily(deposit);
    }

    Future<void> _joinShowFamily(Map<String, dynamic> deposit) async {

                                final legalRaw = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                final key = _gameplayLegal(legalRaw) == "a" ? "join_show_family_adult" : "join_show_family";
                                _hideShapes(["join_show_screen/qrcode", "join_show_screen/code"]);
                                final s = DvOrb.get_shape_by_id("join_show_screen/status");
                                if (s != null) {
                                    s.set("shape.label", TranslationRegistry.processLabel("@@@T:$key@@@")
                                        .replaceAll("{clan}",  deposit["clanName"]?.toString() ?? "")
                                        .replaceAll("{chief}", deposit["adminName"]?.toString() ?? ""));
                                    if (s is DvLabel) await s.computeDisplay();
                                    s..set("shape.visible", true)..refreshUI();
                                }
                                await _revealLabel("join_show_screen/family_yes", "join_show_family_yes");
                                await _revealLabel("join_show_screen/family_no",  "join_show_family_no");
    }

    Future<void> on_join_family_yes(dynamic caller, dynamic event) async {

                                final d = _joinFamily;
                                if (d == null) return;
                                _joinFamily = null;
                                _hideShapes(["join_show_screen/family_yes", "join_show_screen/family_no"]);
                                await _joinProceed(d);
    }

    Future<void> on_join_family_no(dynamic caller, dynamic event) async {

                                deva_log("info", "[join] le candidat ne reconnaît pas le clan : dépôt jeté");
                                _joinFamily = null;
                                _hideShapes(["join_show_screen/family_yes", "join_show_screen/family_no"]);
                                await _joinOpenBox();
                                await _revealLabel("join_show_screen/status", "join_show_new_code");
    }

    // Le dépôt est accepté. Un candidat connecté entre tout de suite. Un enfant encore anonyme
    // lie d'abord son compte Google : le dépôt l'attend EN MÉMOIRE, et on_login le consomme une
    // fois le compte définitif chargé (_consumeJoinDeposit). L'accord de son parent est donné à
    // cet instant : c'est seulement maintenant que quoi que ce soit s'écrit à son nom.
    Future<void> _joinProceed(Map<String, dynamic> deposit) async {

                                if (_anon) {
                                    _joinDeposit = deposit;
                                    await ActionRegistry.get("steps.navigate.link")?.call(null, null);
                                    return;
                                }
                                await _handleClanJoin(deposit);
    }

    // Le dépôt mis de côté pendant la liaison du compte (ou autorisé en différé par un
    // représentant, multiclan). Rend true s'il y en avait un : l'appelant ne route pas à son tour.
    Future<bool> _consumeJoinDeposit() async {

                                final d = _joinDeposit;
                                if (d == null || _joinAdmitting) return false;
                                final repAck  = _joinRepAck;
                                final guestId = _joinGuestId;
                                _joinDeposit = null;
                                _joinRepAck  = "";
                                _joinGuestId = "";
                                // La demande d'un autre clan (multiclan) est close AVANT l'entrée : les
                                // écritures de l'entrée réveillent la vigilance de la représentation, qui
                                // rejouerait sinon le même dépôt. Le dépôt, lui, est en main.
                                if (guestId.isNotEmpty) await _guestJoinDone(guestId);
                                await _handleClanJoin(d, repAck: repAck);
                                return true;
    }

    // L'écran est quitté : liaison du compte (la boîte a servi et n'existe plus), sortie vers son
    // clan, retour système. Une boîte encore ouverte disparaît avec lui.
    // ⚠ LE DÉPÔT ET L'ACCORD NE SONT PAS OUBLIÉS ICI : quitter l'écran pour se connecter est
    //   justement le chemin de l'enfant.
    Future<void> on_join_show_quit(dynamic caller, dynamic event) async {

                                if (_joinCode.isEmpty) return;
                                await _joinStop(deleteBox: !_joinHandled);
    }

    Future<void> on_join_show_leave(dynamic caller, dynamic event) async {

                                await _joinForget();
                                DvOrb.navigate_reset("dashboard");
    }

    // Une adhésion qui n'a pas abouti : le message, et une boîte neuve. Le candidat déjà membre
    // d'un clan (multiclan) retrouve le sien, le message sur « Mes clans ».
    Future<void> _joinRefused(String notice) async {

                                deva_log("info", "[join] adhésion refusée ($notice)");
                                _joinDeposit = null;
                                _joinRepAck  = "";
                                _joinNotice  = notice;
                                final region = await _homeRegion();
                                Dvidle? mine;
                                try { mine = region.isNotEmpty ? await _readSession(region) : null; } catch (_) {}
                                if (_activeClans(mine).isNotEmpty) {
                                    _joinAssent = null;
                                    DvOrb.navigate_reset("dashboard");
                                    return;
                                }
                                if (DvOrb.get_current_page()?.dvid == "join_show_screen") {
                                    await _joinOpenBox();
                                    if (_joinNotice.isNotEmpty) {
                                        await _revealLabel("join_show_screen/status", _joinNotice);
                                        _joinNotice = "";
                                    }
                                    return;
                                }
                                DvOrb.navigate_reset("join_show_screen");
    }

    // -----------------------------------------------------------------------
    // --- Côté CHEF : « Accueillir un joueur »
    // -----------------------------------------------------------------------

    // L'option du menu du clan : d'abord l'écran qui dit quoi faire sur le téléphone du candidat
    // (welcome_child_screen), la caméra ne s'ouvre qu'au toucher du bouton.
    Future<void> on_welcome_player(dynamic caller, dynamic event) async {

                                if ((await _clanIdIfChief("on_welcome_player")).isEmpty) return;
                                _welcomeBox = null;
                                DvOrb.navigate_new("welcome_child_screen");
    }

    // Le chef scanne le QR code du candidat.
    Future<void> on_welcome_scan(dynamic caller, dynamic event) async {

                                // Le lecteur ne vide jamais son résultat : sans cette remise à blanc, un scan
                                // abandonné rejouerait le code scanné la fois précédente.
                                await deva_set("commons.qrcodereader.result", "");
                                final fut = ActionRegistry.get("qrcodereader.scan")?.call(caller, event);
                                if (fut is Future) await fut;
                                final content = (await deva_get("commons.qrcodereader.result"))?.toString() ?? "";
                                if (content.isEmpty) return;   // scan abandonné : on reste sur l'explication
                                final uri = Uri.tryParse(content.trim());
                                if (uri == null || uri.scheme != "ddust" || uri.host != "join") {
                                    await _revealLabel("welcome_child_screen/error", "welcome_not_join_qr");
                                    return;
                                }
                                await _welcomeOpenBox(uri.queryParameters["c"] ?? "", uri.queryParameters["f"] ?? "",
                                    uri.queryParameters["t"] ?? "", uri.queryParameters["r"] ?? "");
    }

    // « Il est loin ? Saisir son code » : la saisie apparaît sous les boutons.
    Future<void> on_welcome_remote(dynamic caller, dynamic event) async {

                                _hideShapes(["welcome_child_screen/error"]);
                                for (final id in ["welcome_child_screen/code", "welcome_child_screen/code_go"]) {
                                    DvOrb.get_shape_by_id(id)?..set("shape.visible", true)..refreshUI();
                                }
    }

    Future<void> on_welcome_code_go(dynamic caller, dynamic event) async {

                                final raw  = DvOrb.get_shape_by_id("welcome_child_screen/code")?.get("shape.value")?.toString() ?? "";
                                final code = _joinNormCode(raw);
                                if (code.isEmpty) {
                                    await _revealLabel("welcome_child_screen/error", "welcome_code_unknown");
                                    return;
                                }
                                await _welcomeOpenBox(code, "", "", "");
    }

    // Le QR code du candidat ouvert par l'appareil photo du téléphone du chef (ddust://join).
    // Même traitement qu'un scan, depuis l'écran « Accueillir un joueur » ; ailleurs, ou avant le
    // login, rien ne se passe : il n'y a pas de recrutement sans le geste du chef.
    Future<void> on_join_link(DvShape? caller, Map event) async {

                                if (!(_cloud?.isReady() ?? false) || _anon || _userId.isEmpty) return;
                                if ((await _clanIdIfChief("on_join_link")).isEmpty) return;
                                if (DvOrb.get_current_page()?.dvid != "welcome_child_screen") {
                                    DvOrb.navigate_new("welcome_child_screen");
                                    await DvOrb.wait_for_shape("welcome_child_screen/error");
                                }
                                await _welcomeOpenBox(event["c"]?.toString() ?? "", event["f"]?.toString() ?? "",
                                    event["t"]?.toString() ?? "", event["r"]?.toString() ?? "");
    }

    // Le chef ouvre la boîte du candidat et la RÉCLAME : plus aucun autre chef ne pourra y
    // déposer. Rien n'est réclamé tant que les vérifications ne sont pas passées.
    Future<void> _welcomeOpenBox(String code, String f, String t, String r) async {

                                const errId = "welcome_child_screen/error";
                                _hideShapes([errId]);
                                code = _joinNormCode(code);
                                if (code.isEmpty) {
                                    await _revealLabel(errId, "welcome_code_unknown");
                                    return;
                                }
                                // Une autre contrée : le clan n'existe pas dans la base du candidat.
                                if (await _inviteRegionMismatch(r, errId)) return;
                                // Chef, et de la place (un clan plein ouvre la page des paliers).
                                if ((await _clanIdIfChief("_welcomeOpenBox")).isEmpty) return;
                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                Dvidle? box;
                                try {
                                    box = await _cloud?.read("workers", "clans_joins", code, region: region, ownerId: "join");
                                } catch (e) {
                                    deva_log("error", "[join] lecture de la boîte $code FAILED: $e");
                                }
                                final status  = box?.get("status")?.toString() ?? "";
                                final expires = DateTime.tryParse(box?.get("expires_at")?.toString() ?? "");
                                if (box == null || expires == null || DateTime.now().toUtc().isAfter(expires.toUtc())) {
                                    await _revealLabel(errId, "welcome_code_unknown");
                                    return;
                                }
                                if (status != "open") {
                                    await _revealLabel(errId, "welcome_code_taken");
                                    return;
                                }
                                final pk = box.get("pk")?.toString() ?? "";
                                if (pk.isEmpty || (f.isNotEmpty && await DvSealBox.fingerprint(pk) != f)) {
                                    await _revealLabel(errId, "welcome_not_join_qr");
                                    return;
                                }
                                if (await _inviteRegionMismatch(box.get("cloud_region")?.toString() ?? "", errId)) return;

                                // La réclamation : le premier qui écrit `seen` est le seul à pouvoir déposer.
                                final uid = _cloud?.currentUser()?.providerUid ?? "";
                                final now = DateTime.now().toUtc();
                                final exp = now.add(const Duration(minutes: _kJoinBoxMinutes));
                                try {
                                    await _cloud?.write("workers", "clans_joins", code, Dvidle({
                                        "status":     "seen",
                                        "by":         uid,
                                        "seen_at":    now.toIso8601String(),
                                        "expiration": exp,
                                    }), region: region, ownerId: "join");
                                } catch (e) {
                                    deva_log("warning", "[join] boîte $code déjà réclamée ($e)");
                                    await _revealLabel(errId, "welcome_code_taken");
                                    return;
                                }

                                final legal  = box.get("legal")?.toString() == "a" ? "a" : "k";
                                final assent = _mcMap(box.get("assent"));
                                _welcomeBox = {
                                    "code":     code,
                                    "pk":       pk,
                                    "t":        t,
                                    "legal":    legal,
                                    "has_clan": box.get("has_clan") == true,
                                };
                                _welcomeDone      = false;
                                _welcomeAdvancing = false;
                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _inviteAsChief    = false;
                                _inviteReading    = "";
                                // L'accord de l'enfant, avec le code de SA boîte : c'est ce code que l'appareil
                                // de l'enfant retrouvera dans la déclaration scellée (défense en profondeur).
                                _pendingAssent = legal == "a" ? null : <String, dynamic>{...assent, "n": code};
                                if (legal == "a") {
                                    _inviteMode = "adult";
                                } else if (box.get("has_clan") == true
                                        && !await _isMyWard(box.get("ward")?.toString() ?? "")) {
                                    // Un enfant d'un AUTRE foyer : ses parents décideront.
                                    _inviteMode = "guest";
                                } else {
                                    _inviteMode = "child_pick";
                                }
                                deva_log("info", "[join] boîte $code réclamée, mode $_inviteMode");
                                // L'écran d'explication est remplacé par la suite : un retour depuis la
                                // déclaration ramène au clan, pas à la caméra.
                                _welcomeAdvancing = true;
                                DvOrb.navigate_back();
                                if (_inviteMode == "child_pick") {
                                    await _openClaimOrConsent();
                                } else {
                                    await _openInviteConsent();
                                }
    }

    // L'enfant d'une boîte est-il l'un de ceux que je représente ? La boîte ne porte qu'une
    // empreinte de son identifiant (cf. _joinOpenBox).
    Future<bool> _isMyWard(String ward) async {

                                if (ward.isEmpty) return false;
                                for (final w in await _myWards()) {
                                    if (await DvSealBox.shortHash("ddust-ward:${w["id"]}") == ward) return true;
                                }
                                return false;
    }

    // Le chef renonce (« Pas maintenant », retour, écran quitté) : la boîte passe à `cancelled`,
    // le candidat reçoit un code neuf. Rien si le dépôt est fait.
    Future<void> _welcomeCancel() async {

                                final box = _welcomeBox;
                                _welcomeBox = null;
                                if (box == null || _welcomeDone) return;
                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                try {
                                    await _cloud?.write("workers", "clans_joins", box["code"].toString(),
                                        Dvidle({"status": "cancelled", "done_at": DateTime.now().toUtc().toIso8601String()}),
                                        region: region, ownerId: "join");
                                } catch (e) {
                                    deva_log("warning", "[join] renoncement non écrit ($e) : la boîte échoira seule");
                                }
    }

    // Le dépôt : le secret du clan, et ce dont l'entrant aura besoin, scellés pour SA clé.
    // Rend false si la boîte n'accepte plus de dépôt (échue).
    Future<bool> _welcomeDeposit(Map<String, dynamic> extra) async {

                                final box = _welcomeBox;
                                if (box == null) return false;
                                final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                final session    = region.isNotEmpty ? await _readSession(region) : null;
                                final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) return false;
                                final code    = box["code"].toString();
                                final payload = <String, dynamic>{
                                    "v":          1,
                                    "code":       code,
                                    "t":          box["t"]?.toString() ?? "",
                                    "joinId":     extra.remove("joinId") ?? _generateUuid(),
                                    "clanId":     clanId,
                                    "clanSecret": clanSecret,
                                    "clanName":   (await Deva.instance.get("session.clan.name"))?.toString() ?? "",
                                    "adminId":    _userId,
                                    "adminName":  (await Deva.instance.get("session.user.name"))?.toString() ?? "",
                                    "region":     region,
                                    "at":         DateTime.now().toUtc().toIso8601String(),
                                    ...extra,
                                };
                                try {
                                    final sealed = await DvSealBox.seal(box["pk"].toString(), payload, context: code);
                                    await _cloud?.write("workers", "clans_joins", code, Dvidle({
                                        "status":  "done",
                                        "sealed":  sealed,
                                        "done_at": DateTime.now().toUtc().toIso8601String(),
                                    }), region: region, ownerId: "join");
                                } catch (e) {
                                    deva_log("error", "[join] dépôt dans $code FAILED: $e");
                                    return false;
                                }
                                _welcomeDone = true;
                                deva_log("info", "[join] dépôt fait ($code, joinId=${payload["joinId"]})");
                                await _stampFirstInvite(clanId);
                                await _setClanAlone(false);
                                return true;
    }

    // -----------------------------------------------------------------------
    // --- L'écran de déclaration (invite_consent_screen), en phases
    // -----------------------------------------------------------------------
    //
    // Un écran, plusieurs moments (_inviteMode) :
    //   * `adult`      : un adulte se présente. Ses conditions, la case « Il sera aussi chef » ;
    //   * `child_pick` : un enfant se présente. Ce qu'il a dit, puis DEUX BOUTONS : « Mon enfant
    //                    sait lire » / « Mon enfant ne sait pas encore lire » ;
    //   * `child`      : les conditions qui suivent ce choix (« Fais-lui lire… », « Lis-lui… »),
    //                    et « J'ai compris, accueillons-le » ;
    //   * `guest`      : un enfant d'un AUTRE foyer. L'adulte qui accueille ne décide rien pour
    //                    lui : ses parents recevront la demande (multiclan) ;
    //   * `ward_pick` / `ward` : le REPRÉSENTANT qui reçoit cette demande, en différé : les deux
    //                    boutons, puis « J'accepte » / « Je refuse » ;
    //   * `sent`       : c'est fait, le bouton ramène au clan.
    // ⚠ PLUS DE CASES À COCHER. Le choix d'un bouton (ou l'état légal lu dans la boîte) désigne
    //   l'option de l'acquittement, scellée par documents.seal_ack avec `chosen`.

    Future<void> _openInviteConsent() async {

                                DvOrb.navigate_new("invite_consent_screen");
    }

    // ⚠ `dynamic caller` : l'appear d'une PAGE passe un DvPage, qui n'est pas une shape.
    Future<void> on_invite_consent_appear(dynamic caller, dynamic event) async {

                                _welcomeAdvancing = false;
                                await DvOrb.wait_for_shape("invite_consent_screen/assent");
                                await _paintInviteConsent();
    }

    Future<void> _paintInviteConsent() async {

                                final mode = _inviteMode;
                                String head;
                                if (mode == "adult") {
                                    head = TranslationRegistry.processLabel("@@@T:invite_consent_head_adult@@@");
                                } else if (mode == "ward_pick" || mode == "ward") {
                                    head = _wardHead();
                                } else if (mode == "sent") {
                                    head = TranslationRegistry.processLabel("@@@T:$_welcomeSentKey@@@");
                                } else {
                                    head = _assentHead(_pendingAssent,
                                        guest: mode == "guest", claimName: _pendingClaimName);
                                }
                                final h = DvOrb.get_shape_by_id("invite_consent_screen/assent");
                                if (h != null) {
                                    h.set("shape.label", head);
                                    if (h is DvLabel) await h.computeDisplay();
                                    h..set("shape.visible", true)..refreshUI();
                                }

                                final notice = switch (mode) {
                                    "adult"           => "invite_consent_notice_adult",
                                    "child" || "ward" => _inviteReading == "child_read_aloud"
                                                            ? "invite_consent_notice_aloud" : "invite_consent_notice_reads",
                                    "guest"           => "invite_consent_notice_guest",
                                    _                 => "",
                                };
                                if (notice.isEmpty) {
                                    _hideShapes(["invite_consent_screen/notice"]);
                                } else {
                                    await _revealLabel("invite_consent_screen/notice", notice);
                                }

                                final pick = mode == "child_pick" || mode == "ward_pick";
                                for (final id in ["invite_consent_screen/reads", "invite_consent_screen/aloud"]) {
                                    DvOrb.get_shape_by_id(id)?..set("shape.visible", pick)..refreshUI();
                                }
                                // « Il sera aussi chef » : un adulte seulement, décochée à chaque ouverture.
                                final chief = DvOrb.get_shape_by_id("invite_consent_screen/chief");
                                if (mode == "adult") {
                                    chief?..set("shape.checked", _inviteAsChief)..set("shape.visible", true)..refreshUI();
                                } else {
                                    chief?..set("shape.visible", false)..refreshUI();
                                }

                                final yes = switch (mode) {
                                    "adult" || "guest" || "child" => "invite_consent_yes",
                                    "ward"             => "ward_request_accept",
                                    "sent"             => "welcome_sent_back",
                                    _                  => "",
                                };
                                if (yes.isEmpty) {
                                    _hideShapes(["invite_consent_screen/yes"]);
                                } else {
                                    await _revealLabel("invite_consent_screen/yes", yes);
                                }
                                if (mode == "sent") {
                                    _hideShapes(["invite_consent_screen/no"]);
                                } else {
                                    await _revealLabel("invite_consent_screen/no",
                                        mode == "ward" || mode == "ward_pick" ? "ward_request_refuse" : "invite_consent_no");
                                }
    }

    // Le panneau de tête quand un enfant se présente : ce qu'il a dit, quand, et le texte qu'on
    // lui a montré (dans la langue du CHEF, qui doit le comprendre ; celle de l'enfant voyage
    // dans l'accord). Puis, le cas échéant, le joueur qu'il reprendra, ou le fait qu'il a déjà un
    // clan ailleurs.
    String _assentHead(Map<String, dynamic>? assent, {bool guest = false, String claimName = ""}) {

                                final d    = DateTime.tryParse(assent?["date"]?.toString() ?? "")?.toLocal();
                                final when = d == null ? "" :
                                    "${_storeShortDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
                                final key  = assent?["text_key"]?.toString() ?? "";
                                final shown = _kAssentTextKeys.contains(key)
                                    ? TranslationRegistry.processLabel("@@@T:$key@@@") : "";
                                // Sans accord lisible (date ou texte absent) : aucune phrase plutôt que
                                // « le . » et « «  » » (relevé par la vitrine, 2026-10-21).
                                var text = (when.isEmpty || shown.isEmpty) ? "" : TranslationRegistry.processLabel(
                                        guest ? "@@@T:invite_consent_assent_guest@@@" : "@@@T:invite_consent_assent@@@")
                                    .replaceAll("{date}", when)
                                    .replaceAll("{text}", shown);
                                if (claimName.isNotEmpty) {
                                    text += "${text.isEmpty ? "" : "\n\n"}${TranslationRegistry.processLabel("@@@T:invite_consent_claim@@@")
                                        .replaceAll("{name}", claimName)}";
                                }
                                return text;
    }

    Future<void> _invitePickReading(String option) async {

                                if (_inviteMode != "child_pick" && _inviteMode != "ward_pick") return;
                                _inviteReading = option;
                                _inviteMode    = _inviteMode == "ward_pick" ? "ward" : "child";
                                await _paintInviteConsent();
    }

    // Case « Il sera aussi chef du clan », en mode ADULTE seulement : un mineur n'est jamais chef
    // (cf. la garde d'âge de promote_chief). `change` porte le nouvel état de la case.
    Future<void> on_invite_chief_toggle(DvShape? caller, dynamic event) async {

                                _inviteAsChief = event == true || caller?.get("shape.checked") == true;
    }

    // Scelle la déclaration (documents.seal_ack avec `chosen`). Rend "" si rien n'a pu l'être.
    Future<String> _inviteSeal(String ackId, String option, {Map<String, dynamic>? assent}) async {

                                final r = await ActionRegistry.get("documents.seal_ack")?.call(null, <String, dynamic>{
                                    "id":     ackId,
                                    "chosen": option,
                                    if (assent != null) "assent": assent,
                                });
                                return r?.toString() ?? "";
    }

    // La décision d'un parent, enregistrée SOUS SON PROPRE COMPTE : c'est lui qui décide, c'est
    // donc à son nom que la preuve doit exister, que l'enfant entre un jour dans le clan ou non.
    // Rend false si elle n'a pas pu l'être : la décision ne part pas sans sa trace. Une action
    // absente (module pas à jour) ne bloque pas, elle est journalisée.
    Future<bool> _recordDecision(String sealed) async {

                                final fn = ActionRegistry.get("documents.record_guardian_decision");
                                if (fn == null) {
                                    deva_log("warning", "[join] documents.record_guardian_decision absente : décision non enregistrée");
                                    return true;
                                }
                                dynamic r = fn(null, sealed);
                                if (r is Future) r = await r;
                                return !(r == false || r?.toString() == "error" || r?.toString() == "false");
    }

    Future<void> on_confirm_invite_consent(DvShape? caller, dynamic event) async {

                                switch (_inviteMode) {
                                    case "sent":
                                        _inviteMode = "";
                                        DvOrb.navigate_back();
                                        return;
                                    case "ward":
                                        await _wardDecide(true);
                                        return;
                                    case "adult":
                                        final sealed = await _inviteSeal("adult", "adult");
                                        if (!await _welcomeDeposit({
                                            if (sealed.isNotEmpty) "ack": sealed,
                                            if (_inviteAsChief) "as_chief": true,
                                        })) {
                                            await _revealLabel("invite_consent_screen/notice", "welcome_code_expired");
                                            return;
                                        }
                                        break;
                                    case "child":
                                        final sealed = await _inviteSeal("guardian", _inviteReading, assent: _pendingAssent);
                                        if (sealed.isEmpty) {
                                            deva_log("error", "[join] déclaration du parent non scellée");
                                            return;
                                        }
                                        if (!await _recordDecision(sealed)) {
                                            await _revealLabel("invite_consent_screen/notice", "ward_error");
                                            return;
                                        }
                                        final clanId = await _clanIdIfChief("on_confirm_invite_consent");
                                        if (clanId.isEmpty) return;
                                        final joinId = _generateUuid();
                                        // La représentation de l'enfant : un secret tiré par le parent, rangé en
                                        // attente dans SON index jusqu'à ce que l'enfant apparaisse (multiclan).
                                        final gSecret = await _newGuardianPending(joinId, clanId);
                                        if (!await _welcomeDeposit({
                                            "joinId": joinId,
                                            "ack":    sealed,
                                            if (_pendingClaimId.isNotEmpty) "claim": _pendingClaimId,
                                            if (gSecret.isNotEmpty) "guardianSecret": gSecret,
                                        })) {
                                            await _revealLabel("invite_consent_screen/notice", "welcome_code_expired");
                                            return;
                                        }
                                        break;
                                    case "guest":
                                        final sealed = await _inviteSeal("guest", "guest_child", assent: _pendingAssent);
                                        // Le chef de B ne décide rien pour l'enfant, mais il l'a accueilli : sa
                                        // trace, sous son compte. Les parents de l'enfant décideront.
                                        await _audit("guest_welcomed", {"clanId": await _currentClanId()});
                                        // Ses appareils et sa langue : l'app de l'enfant le préviendra de la
                                        // décision des parents (accord, refus, délai passé).
                                        final mine = await _myClanFiche();
                                        if (!await _welcomeDeposit({
                                            if (sealed.isNotEmpty) "ack": sealed,
                                            "guest":        true,
                                            "chief_devices": List<dynamic>.from(mine?.get("devices") as List? ?? const [])
                                                .map((d) => d.toString()).toList(),
                                            "chief_lang":   mine?.get("lang")?.toString() ?? TranslationRegistry.currentLang,
                                        })) {
                                            await _revealLabel("invite_consent_screen/notice", "welcome_code_expired");
                                            return;
                                        }
                                        break;
                                    default:
                                        return;
                                }
                                // Déposé : le même écran le dit, le bouton ramène au clan.
                                _welcomeSentKey   = switch (_inviteMode) {
                                    "adult" => "welcome_sent_adult",
                                    "guest" => "welcome_sent_guest",
                                    _       => "welcome_sent",
                                };
                                _pendingAssent    = null;
                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _inviteAsChief    = false;
                                _inviteMode       = "sent";
                                await _paintInviteConsent();
    }

    Future<void> on_cancel_invite_consent(DvShape? caller, dynamic event) async {

                                if (_inviteMode == "ward" || _inviteMode == "ward_pick") {
                                    await _wardDecide(false);
                                    return;
                                }
                                await _welcomeCancel();
                                _inviteResetMemory();
                                DvOrb.navigate_back();
    }

    // L'écran est quitté sans passer par les boutons (retour système, flèche) : une boîte
    // réclamée et sans dépôt est rendue au candidat.
    Future<void> on_invite_consent_quit(dynamic caller, dynamic event) async {

                                if (_welcomeAdvancing) return;
                                await _welcomeCancel();
                                if (_inviteMode != "ward" && _inviteMode != "ward_pick") _inviteResetMemory();
    }

    // claim_pick_page quittée par la flèche : même règle. Un choix fait mène à la déclaration
    // (_welcomeAdvancing), la boîte reste réclamée.
    Future<void> on_claim_pick_quit(dynamic caller, dynamic event) async {

                                if (_welcomeAdvancing) return;
                                await _welcomeCancel();
                                _inviteResetMemory();
    }

    void _inviteResetMemory() {

                                _pendingAssent    = null;
                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _claimRows        = [];
                                _inviteAsChief    = false;
                                _inviteReading    = "";
                                _inviteMode       = "";
    }

    Future<String> _currentClanId() async {

                                final region = await _homeRegion();
                                final s = region.isNotEmpty ? await _readSession(region) : null;
                                return s?.get("steps.clan.clanId")?.toString() ?? "";
    }

    // Ma fiche dans le clan courant (appareils, langue).
    Future<Dvidle?> _myClanFiche() async {

                                try {
                                    final region     = await _homeRegion();
                                    final s          = region.isNotEmpty ? await _readSession(region) : null;
                                    final clanId     = s?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = s?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return null;
                                    return await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region);
                                } catch (_) {
                                    return null;
                                }
    }
}

// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
