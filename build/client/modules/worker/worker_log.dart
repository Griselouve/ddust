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
// --- worker extension — Journal narratif
// -----------------------------------------------------------------------------
extension Worker_log on worker {

    void _register_log() {

                                // Journal d'un joueur (écran Clan → option « Consulter le journal ») :
                                // ouverture de l'écran + reconstitution chronologique du récit.
                                ActionRegistry.register("worker.open_player_log",           open_player_log);

                                ActionRegistry.register("worker.on_log_appear",             on_log_appear);

                                // Journaux ouverts par le bouton settings (kebab d'en-tête) : clan-large
                                // (écran Clan) et personnel (écran Personnage).
                                ActionRegistry.register("worker.open_clan_log",             open_clan_log);

                                ActionRegistry.register("worker.open_my_log",               open_my_log);

    }

    // Ouvre l'écran « journal » pour le joueur cliqué. `event` = map du joueur (comme
    // revive_player/support_player). On mémorise id + name (le nom sert à substituer le token
    // @@@session.user.name@@@ des descriptions) puis on empile l'écran log_page.
    Future<void> open_player_log(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                _logPlayerId   = m["id"]?.toString()   ?? "";
                                _logPlayerName = m["name"]?.toString() ?? "";
                                _logClanWide   = false;   // journal d'un joueur précis : filtre par joueur
                                deva_log("info", "[log] open_player_log → $_logPlayerName ($_logPlayerId)");
                                DvOrb.navigate_new("log_page");
    }

    // Ouvre le journal DU CLAN (bouton settings de l'écran Clan) : tous les joueurs confondus,
    // non filtré. `event` est ignoré (le bouton n'est lié à aucun joueur).
    Future<void> open_clan_log(dynamic caller, dynamic event) async {

                                _logPlayerId   = "";
                                _logPlayerName = "";
                                _logClanWide   = true;
                                deva_log("info", "[log] open_clan_log → journal clan-large");
                                DvOrb.navigate_new("log_page");
    }

    // Ouvre MON journal (bouton settings de l'écran Personnage) : même effet que l'option journal
    // du roster appliquée à l'utilisateur courant.
    Future<void> open_my_log(dynamic caller, dynamic event) async {

                                if (_userId.isEmpty) _userId = await _resolveUserId();
                                _logPlayerId   = _userId;
                                _logPlayerName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                _logClanWide   = false;
                                deva_log("info", "[log] open_my_log → $_logPlayerName ($_logPlayerId)");
                                DvOrb.navigate_new("log_page");
    }

    // Apparition de l'écran log_page : reconstitue le récit chronologique du joueur _logPlayerId
    // (ou du clan entier si _logClanWide) à partir de clans_logs et l'écrit dans log_page/story,
    // via _buildLogStory. Événements retenus (cf. _logLine) :
    //  - TaskValidatedOk/Partial/Ko  → description « tâche accomplie » (dt_d_<task>) + XP gagnés
    //  - PlayerResurrected           → description d'accomplissement du gage (gage_d_<n>)
    //  - ClanCreated, PlayerLeveledUp, ClanLeveledUp, ItemGiven, ButinOpened, TributePaid…
    // Les TaskDone (soumissions, avant verdict) sont ignorées.
    // Troisième mode, _logNarrative (armé par butin_tale_page/share) : au lieu d'afficher la liste,
    // demande à l'IA (_narrateClanStory) un récit tiré du même journal clan-large. Le mode est
    // consommé dès l'entrée pour ne jamais relancer d'inférence par accident.
    Future<void> on_log_appear(dynamic caller, dynamic event) async {

                                // Mode CONSOMMÉ dès l'entrée : quel que soit le sort de l'inférence, revenir
                                // ici par le kebab affichera de nouveau le journal ordinaire — et ne relancera
                                // pas une seconde inférence.
                                final narrative = _logNarrative;
                                _logNarrative   = false;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";

                                    // Mode conte : l'écran ne peut pas rester muet pendant l'aller-retour au
                                    // modèle (plusieurs secondes). On pose l'attente AVANT de lire le journal.
                                    if (narrative) {
                                        final wait = await DvOrb.wait_for_shape("log_page/story");
                                        if (wait is DvLabel) {
                                            wait.write(await _resolveDesc("log_narrating"));
                                            wait.refreshUI();
                                        }
                                    }

                                    String text = "";
                                    var    plain = "";
                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty && (_logPlayerId.isNotEmpty || _logClanWide)) {
                                        final story = await _buildLogStory(clanId, clanSecret, region);
                                        text  = story.rich;
                                        plain = story.plain;
                                        // dvsocialshare lit share.log.text → @@@log.share_text@@@ (cf. bloc `share:`).
                                        // L'accroche est résolue ICI (pas laissée en `@@@T:...@@@`) : dvsocialshare
                                        // ne fait qu'une seule passe de substitution, un marqueur T: imbriqué dans
                                        // une valeur deva_get ne serait donc jamais déplié.
                                        await deva_set("log.share_text",  story.share);
                                        await deva_set("log.share_intro", await _resolveDesc("share_log_intro"));
                                    }

                                    // Le conte remplace la liste par le récit qu'un modèle en tire. Journal vide
                                    // → rien à raconter : on retombe sur le message habituel sans déranger l'IA.
                                    if (narrative && plain.isNotEmpty) {
                                        final tale = await _narrateClanStory(plain, clanId, clanSecret, region);
                                        if (tale.isNotEmpty) {
                                            // Le conte IA ne parle jamais d'argent (interdit par le prompt) : cette
                                            // phrase de clôture FIXE, elle, en parle — et sert d'appel à l'action
                                            // doux, ce qu'un récit ne doit justement jamais faire.
                                            final outro = await _resolveDesc("share_tale_outro");
                                            final full  = outro.isNotEmpty ? "$tale\n\n$outro" : tale;
                                            text = full;
                                            // Le partage porte alors le RÉCIT, avec sa propre accroche (celle du
                                            // journal parle des exploits « de mon aventurier » : hors sujet ici).
                                            await deva_set("log.share_text",  full);
                                            await deva_set("log.share_intro", await _resolveDesc("share_tale_intro"));
                                        } else {
                                            // Modèle injoignable, coupé (budget) ou muet : on ne laisse pas l'écran
                                            // vide — le journal brut reste un récit, et son partage est déjà armé.
                                            final failed = await _resolveDesc("log_narrate_failed");
                                            if (failed.isNotEmpty) text = "$failed\n\n$text";
                                        }
                                    }

                                    if (text.isEmpty) {
                                        text = await _resolveDesc("log_empty");
                                        // Aucun log : ne pas laisser un partage périmé d'un joueur précédent.
                                        await deva_set("log.share_text",  text);
                                        await deva_set("log.share_intro", await _resolveDesc("share_log_intro"));
                                    }

                                    final story = await DvOrb.wait_for_shape("log_page/story");
                                    if (story is DvLabel) { story.write(text); story.refreshUI(); }
                                } catch (e) {
                                    deva_log("error", "[log] on_log_appear FAILED: $e");
                                }
    }

    // Reconstruit le récit du journal en TROIS rendus du même parcours, parce qu'ils n'ont ni le
    // même lecteur ni la même contrainte :
    //  - `rich`  : l'écran. Intégral, en-têtes de date encadrés <center> pour DvRichLabel.
    //  - `share` : le partage social. Texte brut, borné aux 8 évènements les plus récents (`mine`
    //              étant trié décroissant, ce sont les premiers rendus), suffixe « …et tant
    //              d'autres exploits » si l'on a tronqué.
    //  - `plain` : la matière du conteur IA. Texte brut, borné à `plainMax` — largement de quoi
    //              couvrir des mois de jeu, tout en gardant l'invite d'une taille raisonnable.
    // Les lignes sont DÉJÀ résolues et localisées par _logLine (descriptions de tâches, noms des
    // joueurs substitués) : le modèle reçoit du récit lisible, pas du JSON à déchiffrer.
    Future<({String rich, String share, String plain, int lines})> _buildLogStory(
            String clanId, String clanSecret, String region, {int plainMax = 300}) async {

                                // Borné aux 300 événements les plus récents (= plainMax, la plus large des
                                // trois bornes de rendu) : clans_logs est append-only et jamais purgé — un
                                // full list croîtrait sans limite avec l'âge du clan. Tri serveur date desc
                                // (index mono-champ automatique). skipIsolationFilter : ownerId des logs =
                                // clanSecret, pas l'uid — l'accès est gardé par la règle `list`.
                                final logs = await _cloud?.searchWhere("workers", "clans_logs/$clanId/logs", const [],
                                    region: region, skipIsolationFilter: true,
                                    orderBy: "date", descending: true, limit: plainMax) ?? [];

                                // Journal clan-large : table id→nom du clan pour attribuer chaque ligne à son
                                // vrai acteur (nom substitué au token @@@session.user.name@@@ par _resolveDesc).
                                final Map<String, String> nameById = {};
                                if (_logClanWide) {
                                    final players = await _cloud?.list("workers", "clans_players/$clanId/players", region: region) ?? [];
                                    for (final p in players) {
                                        if (p is! Dvidle) continue;
                                        final pid = p.get("id")?.toString() ?? "";
                                        if (pid.isEmpty) continue;
                                        nameById[pid] = _memberLabel(p.get("name")?.toString() ?? "");
                                    }
                                }

                                // Événements retenus, triés chronologiquement (date décroissante : le plus récent
                                // en premier). Journal joueur → filtré sur _logPlayerId ; clan-large → tous.
                                final mine = <Dvidle>[];
                                for (final l in logs) {
                                    if (l is! Dvidle) continue;
                                    if (!_logClanWide && (l.get("userId")?.toString() ?? "") != _logPlayerId) continue;
                                    mine.add(l);
                                }
                                mine.sort((a, b) => (b.get("date")?.toString() ?? "")
                                    .compareTo(a.get("date")?.toString() ?? ""));

                                const int shareMax = 8;
                                final richSb  = _StoryBuffer(centered: true);
                                final shareSb = _StoryBuffer(max: shareMax);
                                final plainSb = _StoryBuffer(max: plainMax);
                                final lang    = TranslationRegistry.currentLang;
                                int nb = 0;
                                for (final l in mine) {
                                    // Clan-large : chaque ligne porte le nom de SON acteur (résolu par _resolveDesc).
                                    if (_logClanWide) {
                                        _logPlayerName = nameById[l.get("userId")?.toString() ?? ""] ?? "";
                                    }
                                    final line = await _logLine(l);
                                    if (line.isEmpty) continue;
                                    final day    = _dayKey(l);
                                    final header = _dateHeader(l, lang);
                                    richSb.add(line, day, header);
                                    shareSb.add(line, day, header);
                                    // `plain` seulement : le conte IA ne parle pas de la fondation du clan. Le
                                    // lecteur visé est une AUTRE famille — l'acte de naissance administratif ne
                                    // lui raconte rien, et le modèle, fidèle à sa matière, ouvrait dessus. L'écran
                                    // (`rich`) et le partage (`share`) la gardent : là, elle a sa place.
                                    if ((l.get("event")?.toString() ?? "") != "ClanCreated") {
                                        plainSb.add(line, day, header);
                                    }
                                    nb++;
                                }
                                // Log tronqué (plus d'évènements que shareMax) : clore le partage par
                                // un suffixe traduit dans la langue du message (repli fr).
                                if (nb > shareMax) shareSb.append(await _resolveDesc("log_share_more"));

                                deva_log("info", "[log] _buildLogStory: ${mine.length} évt(s) "
                                    "(${_logClanWide ? 'clan' : _logPlayerId}) → $nb ligne(s)");
                                return (rich:  richSb.toString(),
                                        share: shareSb.toString(),
                                        plain: plainSb.toString(),
                                        lines: nb);
    }

    // Demande au modèle un récit épique du clan, à partir du journal DÉJÀ résolu (`plainText`,
    // produit par _buildLogStory) et d'agrégats calculés ICI, en Dart — jamais par le modèle : un
    // LLM qui doit sommer lui-même une liste de nombres se trompe, et personne ne peut vérifier.
    // Suit EXACTEMENT le patron de _runInspire (mêmes clés `worker.inspire_lang`, même séquence
    // dvvertexai → dvprompts → sendMessage), mais avec un timeout LONG (30 s, contre 3 s pour
    // « inspire ») : il n'existe pas de repli statique crédible pour un récit — l'appelant se
    // rabat sur le journal brut si cette fonction rend "".
    //
    // Les agrégats sont volontairement PAUVRES : un total, pas un détail par joueur. Le premier
    // jet fournissait « XP par joueur : A: 725, B: 226… » et le modèle, fidèle à sa matière,
    // rendait un inventaire au lieu d'un récit. On ne lui tend plus que de quoi nommer les
    // enfants (les prénoms, séparément) et de quoi citer UN chiffre (XP totale du clan) —
    // jamais une liste qui appelle l'énumération. L'argent de poche n'est PAS transmis au
    // modèle : le prompt l'interdit désormais, la phrase qui en parle est fixe (share_tale_outro,
    // ajoutée après coup par on_log_appear). Les valeurs nulles sont omises : « 0 objet partagé »
    // ne doit jamais apparaître nulle part.
    Future<String> _narrateClanStory(String plainText, String clanId, String clanSecret, String region) async {

                                try {
                                    // Nom INTERNE (celui choisi par la famille, pas le nom externe généré) et
                                    // description du clan : la matière qui dit QUI est ce clan, pas ce qu'il a
                                    // fait. Lus ici (et pas seulement depuis le journal) pour rester corrects
                                    // même si le clan a été renommé depuis sa création, ou si son log
                                    // `ClanCreated` est antérieur au champ `clanNameInternal`.
                                    final clanDoc  = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final clanName = clanDoc?.get("internal.name")?.toString() ?? "";
                                    final clanDesc = clanDoc?.get("description")?.toString() ?? "";

                                    // Prénoms (pour que le modèle NOMME les enfants) et XP TOTALE du clan (un
                                    // seul nombre, jamais un par joueur) : le fait brut, pas une opinion — mais
                                    // assez pauvre pour ne pas suggérer une énumération.
                                    final players = await _cloud?.list("workers", "clans_players/$clanId/players", region: region) ?? [];
                                    final names = <String>[];
                                    var totalXp = 0;
                                    for (final p in players) {
                                        if (p is! Dvidle || p.get("enabled") == false) continue;
                                        final name = p.get("name")?.toString() ?? "";
                                        if (name.isNotEmpty) names.add(name);
                                        totalXp += int.tryParse(p.get("xp")?.toString() ?? "0") ?? 0;
                                    }

                                    final totals = StringBuffer();
                                    if (names.isNotEmpty)  totals.writeln("Membres du clan : ${names.join(", ")}.");
                                    if (totalXp > 0)       totals.writeln("XP totale accumulée par le clan : $totalXp XP.");

                                    const langNames = {"fr": "French", "en": "English", "es": "Spanish"};
                                    await deva_set("worker.inspire_lang",   langNames[TranslationRegistry.currentLang] ?? "English");
                                    await deva_set("worker.narrate_clan",   "$clanName. $clanDesc".trim());
                                    await deva_set("worker.narrate_input",  plainText);
                                    await deva_set("worker.narrate_totals", totals.toString());

                                    final ai = Deva.instance.module("dvvertexai");
                                    if (ai == null) return "";
                                    try { await (ai as dynamic).startVertexMotor(); } catch (_) {}

                                    final prompts = Deva.instance.module("dvprompts");
                                    final prompt  = prompts != null
                                        ? await (prompts as dynamic).get_prompt("narrate_clan") as String
                                        : "";
                                    if (prompt.isEmpty) return "";

                                    final aiFuture = ((ai as dynamic).sendMessage(prompt)) as Future<String?>;
                                    final result = await aiFuture.timeout(const Duration(seconds: 30));
                                    return result?.trim() ?? "";
                                } on TimeoutException {
                                    deva_log("warning", "[log] _narrateClanStory: timeout (30s)");
                                    return "";
                                } catch (e) {
                                    deva_log("error", "[log] _narrateClanStory FAILED: $e");
                                    return "";
                                }
    }

    // Traduit un log en une ligne de récit ("" si l'événement n'a pas de rendu narratif).
    // Seules les tâches VALIDÉES par un chef de clan (ok/partiel/refusé) et les gages accomplis
    // produisent une ligne ; les TaskDone (soumissions, avant verdict) sont ignorées.
    Future<String> _logLine(Dvidle l) async {

                                final ev = l.get("event")?.toString() ?? "";

                                // Naissance du clan : la toute première ligne du récit (le journal est trié
                                // du plus récent au plus ancien, elle ferme donc l'écran). Sa description est
                                // celle SAISIE À LA CRÉATION, figée dans le log — le clan a pu la réécrire
                                // depuis, le récit garde la profession de foi d'origine. Clan d'avant ce champ
                                // (description absente) → phrase sans profession de foi, jamais de {desc} nu.
                                // Nom INTERNE préféré (`clanNameInternal`, celui choisi par la famille) — le
                                // nom externe (`clanName`, généré) ne sert que la confidentialité inter-clans,
                                // il n'a rien à faire dans un récit qui s'adresse à la famille elle-même.
                                // Repli sur `clanName` pour les logs antérieurs à ce champ.
                                if (ev == "ClanCreated") {
                                    final desc = l.get("data.description")?.toString() ?? "";
                                    final clanNameForLine = (l.get("data.clanNameInternal")?.toString() ?? "").isNotEmpty
                                        ? l.get("data.clanNameInternal").toString()
                                        : l.get("data.clanName")?.toString() ?? "";
                                    var line = await _resolveDesc(desc.isEmpty ? "log_clan_created"
                                                                              : "log_clan_created_desc");
                                    if (line.isEmpty) return "";
                                    line = line.replaceAll("{clan}", clanNameForLine);
                                    return line.replaceAll("{desc}", desc);
                                }

                                // Gage accompli (à la résurrection) : description de rédemption (gage_d_<n>).
                                if (ev == "PlayerResurrected") {
                                    final gage = l.get("data.gage")?.toString() ?? "";
                                    if (gage.isEmpty) return "";
                                    return await _resolveDesc(gage.replaceFirst("gage_", "gage_d_"));
                                }

                                // Départ / révocation du clan : « <nom> a quitté le clan. » Le token
                                // @@@session.user.name@@@ de la trad est substitué par _resolveDesc.
                                if (ev == "MemberRevoked") {
                                    return await _resolveDesc("log_member_left");
                                }

                                // Montée de niveau : « <nom> a atteint le niveau N ! » (+ titre si franchi).
                                if (ev == "PlayerLeveledUp") {
                                    final niveau   = l.get("data.niveau")?.toString()    ?? "";
                                    final idxRaw   = l.get("data.title_idx")?.toString() ?? "";
                                    final hasTitle = idxRaw.isNotEmpty;
                                    var line = await _resolveDesc(hasTitle ? "log_levelup_title" : "log_levelup");
                                    if (line.isEmpty) return "";
                                    line = line.replaceAll("{level}", niveau);
                                    if (hasTitle) line = line.replaceAll("{title}", await _resolveDesc("player_title_$idxRaw"));
                                    return line;
                                }

                                // Palier de CLAN franchi : « Le clan a atteint le niveau N et peut
                                // prétendre au titre de X ! » Le titre n'est pas porté pour autant — un
                                // chef doit appliquer l'item (aucun {title} sans title_idx : pas de ligne).
                                if (ev == "ClanLeveledUp") {
                                    final niveau = l.get("data.niveau")?.toString()    ?? "";
                                    final idxRaw = l.get("data.title_idx")?.toString() ?? "";
                                    if (idxRaw.isEmpty) return "";
                                    var line = await _resolveDesc("log_clan_levelup");
                                    if (line.isEmpty) return "";
                                    line = line.replaceAll("{level}", niveau);
                                    return line.replaceAll("{title}", await _resolveDesc("clan_title_$idxRaw"));
                                }

                                // Don d'un objet à un joueur : « <donneur> a fait un don généreux de X à Y. »
                                // Le libellé de l'objet est résolu dans la langue du LECTEUR (nom propre
                                // s'il en a un, sinon le libellé de son type) ; le nom du donneur vient du
                                // token @@@session.user.name@@@ substitué par _resolveDesc.
                                if (ev == "ItemGiven") {
                                    var line = await _resolveDesc("log_item_given");
                                    if (line.isEmpty) return "";
                                    final type = l.get("data.item_type")?.toString() ?? "";
                                    var item   = l.get("data.item_name")?.toString() ?? "";
                                    if (item.isEmpty && type.isNotEmpty) item = await _resolveDesc("it_t_$type");
                                    return line
                                        .replaceAll("{item}", item)
                                        .replaceAll("{to}", l.get("data.to_name")?.toString() ?? "");
                                }

                                // Tâche validée (ok/partiel/refusé) : description « accomplie » de la tâche +
                                // XP gagnés → « <nom> vient de … (30 XP) ». Tâche `multiple` → id clone
                                // `<base>__<uid>` ; la description est keyée sur la BASE (dt_d_<base>). _originalOf
                                // est neutre pour les tâches non clonées.
                                if (ev == "TaskValidatedOk" || ev == "TaskValidatedPartial" || ev == "TaskValidatedKo") {
                                    final base = _originalOf(l.get("task")?.toString() ?? "");
                                    if (base.isEmpty) return "";
                                    final desc = await _resolveDesc("dt_d_$base");
                                    if (desc.isEmpty) return "";
                                    final xp = l.get("data.xp")?.toString() ?? "0";
                                    // Tâche « boss » : dire le bonus, pas seulement le total. Le journal
                                    // écrit déjà l'XP RÉELLEMENT créditée (data.xp) et l'XP sans bonus
                                    // (data.xp_base) — mais un total nu ne permettait pas de savoir si la
                                    // recommandation avait payé, ni de combien.
                                    final xpN   = int.tryParse(xp) ?? 0;
                                    final baseN = int.tryParse(l.get("data.xp_base")?.toString() ?? "0") ?? 0;
                                    if (l.get("data.boss") == true && xpN > baseN) {
                                        final line = await _resolveDesc("log_task_boss");
                                        if (line.isNotEmpty) {
                                            return "$desc ${line.replaceAll("{xp}", "$xpN")
                                                                .replaceAll("{bonus}", "+${xpN - baseN}")}";
                                        }
                                    }
                                    return "$desc ($xp XP)";
                                }

                                // Ouverture du coffre : événement de CLAN (pas d'acteur joueur), donc rendu
                                // tel quel — aucun @@@session.user.name@@@ à substituer. Un coffre ouvert
                                // sans un sou reste un moment de clan : la variante sans argent existe pour
                                // ne jamais afficher « 0 pièces ».
                                if (ev == "ButinOpened") {
                                    final money = int.tryParse(l.get("data.money")?.toString() ?? "0") ?? 0;
                                    var line = await _resolveDesc(money > 0 ? "log_butin_opened"
                                                                            : "log_butin_opened_empty");
                                    if (line.isEmpty) return "";
                                    return line
                                        .replaceAll("{amount}",  "$money")
                                        .replaceAll("{items}",   l.get("data.items")?.toString()   ?? "0")
                                        .replaceAll("{players}", l.get("data.players")?.toString() ?? "0");
                                }

                                // Tribut versé : le chef a remis au joueur l'argent réel de sa bourse.
                                if (ev == "TributePaid") {
                                    final line = await _resolveDesc("log_tribute_paid");
                                    if (line.isEmpty) return "";
                                    return line.replaceAll("{amount}", l.get("data.amount")?.toString() ?? "0");
                                }

                                return "";
    }

    // Résout une clé de traduction en texte BRUT (pas de rendu DvLabel : on substitue le nom
    // nous-mêmes), dans la langue courante avec repli "fr" — même schéma que _notifyAssignee.
    // Le token @@@session.user.name@@@ des dt_d_* est remplacé par le nom du joueur consulté.
    Future<String> _resolveDesc(String key) async {

                                final lang = TranslationRegistry.currentLang;
                                var t = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                                if (t.isEmpty) t = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                                return t.replaceAll("@@@session.user.name@@@", _logPlayerName);
    }

    // Date locale d'un log (champ `date` = ISO-8601 UTC) → DateTime local, ou null si absent/invalide.
    DateTime? _localDate(Dvidle l) {

                                final dt = DateTime.tryParse(l.get("date")?.toString() ?? "");
                                return dt?.toLocal();
    }

    // Clef de regroupement journalier (année-mois-jour, heure locale) : marque les bornes de groupe.
    String _dayKey(Dvidle l) {

                                final d = _localDate(l);
                                return d == null ? "" : "${d.year}-${d.month}-${d.day}";
    }

    // En-tête de groupe (« Lundi 21 Juin ») dans la langue courante (fr/en/es, repli fr).
    // weekday: 1=lundi … 7=dimanche ; month: 1..12.
    String _dateHeader(Dvidle l, String lang) {

                                final d = _localDate(l);
                                if (d == null) return "";
                                const days = {
                                    "fr": ["Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche"],
                                    "en": ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"],
                                    "es": ["Lunes","Martes","Miércoles","Jueves","Viernes","Sábado","Domingo"],
                                };
                                const months = {
                                    "fr": ["Janvier","Février","Mars","Avril","Mai","Juin","Juillet","Août","Septembre","Octobre","Novembre","Décembre"],
                                    "en": ["January","February","March","April","May","June","July","August","September","October","November","December"],
                                    "es": ["enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre"],
                                };
                                final dd = days[lang]   ?? days["fr"]!;
                                final mm = months[lang] ?? months["fr"]!;
                                final wd = dd[(d.weekday - 1) % 7];
                                final mo = mm[(d.month - 1) % 12];
                                switch (lang) {
                                    case "en": return "$wd $mo ${d.day}";       // Monday June 21
                                    case "es": return "$wd ${d.day} de $mo";    // Lunes 21 de junio
                                    default:   return "$wd ${d.day} $mo";       // Lundi 21 Juin
                                }
    }

}

// Accumulateur de récit groupé par jour, partagé par les trois rendus de _buildLogStory (écran,
// partage, entrée du conteur IA). Les trois suivent le MÊME regroupement — un en-tête de date
// précède chaque groupe de lignes du même jour — mais diffèrent sur deux points :
//  - `centered` : l'écran (DvRichLabel/Markdown) veut ses en-têtes encadrés <center>…</center> ;
//    le partage et le conte, en texte brut, les veulent nus.
//  - `max` : le partage et le conte bornent le nombre de LIGNES (pas de jours) rendues ; l'écran
//    ne borne rien (0 = illimité). Une fois le plafond atteint, `add()` devient un no-op silencieux
//    — c'est à l'appelant de savoir qu'il a tronqué (cf. `nb > shareMax` dans _buildLogStory) et
//    d'ajouter lui-même un suffixe.
class _StoryBuffer {

    final bool centered;
    final int  max;             // 0 = illimité
    final StringBuffer _sb = StringBuffer();
    String _curDay = "";
    int    _count  = 0;

    _StoryBuffer({this.centered = false, this.max = 0});

    void add(String line, String day, String header) {

            if (max > 0 && _count >= max) return;
            if (day != _curDay) {
                _curDay = day;
                if (_sb.isNotEmpty) _sb.write("\n\n\n");
                _sb.write(centered ? "<center>$header</center>" : header);
                _sb.write("\n\n");
            } else {
                _sb.write("\n\n");
            }
            _sb.write(line);
            _count++;
    }

    // Ajoute un texte de clôture (suffixe « …et tant d'autres exploits »), hors du regroupement
    // par jour — toujours en fin de buffer, jamais compté dans `max`.
    void append(String text) {

            if (text.isEmpty) return;
            _sb.write("\n\n\n");
            _sb.write(text);
    }

    @override
    String toString() => _sb.toString();
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
