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
// --- worker extension — La fée
// -----------------------------------------------------------------------------
//
// Tout le reste du jeu récompense l'EFFORT : on vainc une monstre-tâche, on gagne de l'XP. La fée
// ne récompense que d'être passé par là. Au plus une fois par mois, sans que personne ne soit
// prévenu, elle prend la place d'une monstre-tâche dans un tiroir de domaine, pendant dix minutes.
// Qui la trouve et la touche choisit entre les deux cadeaux qu'elle tend ; elle disparaît alors
// pour tout le clan.
//
// >>> LE SILENCE EST LA FONCTIONNALITÉ. Aucune notification, aucune ligne de journal, aucun badge
// tant qu'elle est là : la trouver EST la récompense. Ce qui s'annonce (§_notifyClanFairy,
// FairyGift) ne part QU'APRÈS que quelqu'un l'a touchée.
//
// Quatre pièces, dans l'ordre du temps :
//   1. le TIRAGE       — _rollFairy, au dashboard (le seul écran par lequel tout le monde passe) ;
//   2. l'AFFICHAGE     — _fairyAdditionFor / _fairyHiddenTask, greffés sur les canaux du tiroir ;
//   3. la PRISE        — on_fairy_tap, arbitrée par un verrou dvlock (premier arrivé gagne) ;
//   4. la CÉRÉMONIE    — fairy_page, puis le cadeau choisi.
//
// L'état vit dans UN document Firestore partagé par le clan (clans_items/{clan}/items/fairy) : il
// porte à la fois l'horloge des trente jours, la fenêtre de dix minutes, l'endroit où elle se tient
// et les deux cadeaux tirés. Deux appareils qui l'ouvrent voient donc rigoureusement la même fée,
// aux mêmes mains.
extension Worker_fairy on worker {

    // -----------------------------------------------------------------------
    // --- Enregistrement
    // -----------------------------------------------------------------------

    void _register_fairy() {

                                ActionRegistry.register("worker.on_fairy_tap",          on_fairy_tap);
                                ActionRegistry.register("worker.on_fairy_appear",       on_fairy_appear);
                                ActionRegistry.register("worker.on_fairy_ready",        on_fairy_ready);
                                ActionRegistry.register("worker.on_fairy_choose_left",  on_fairy_choose_left);
                                ActionRegistry.register("worker.on_fairy_choose_right", on_fairy_choose_right);
                                // Tirée par la CONF : `on_end` du fondu de sortie du voile noir.
                                ActionRegistry.register("worker.on_fairy_done",         on_fairy_done);

                                // Banc d'essai (kebab de la boutique, mode test seulement).
                                ActionRegistry.register("worker.force_fairy",           force_fairy);

                                // Les cadeaux. Ce sont des clefs d'action ORDINAIRES, et c'est tout
                                // l'intérêt : le catalogue (fairy-base-global.yml) ne fait que les
                                // nommer. Un thème ou un pack qui veut « la même chose, en plus
                                // généreux » ajoute une entrée pointant sur l'une d'elles avec ses
                                // propres bornes — aucun code. Seul un cadeau d'un GENRE nouveau
                                // demande d'en enregistrer une de plus ici.
                                ActionRegistry.register("worker.fairy_xp_self",         fairy_xp_self);
                                ActionRegistry.register("worker.fairy_xp_other",        fairy_xp_other);
                                ActionRegistry.register("worker.fairy_xp_clan",         fairy_xp_clan);
                                ActionRegistry.register("worker.fairy_heal_self",       fairy_heal_self);
                                ActionRegistry.register("worker.fairy_heal_other",      fairy_heal_other);
                                ActionRegistry.register("worker.fairy_heal_clan",       fairy_heal_clan);
                                ActionRegistry.register("worker.fairy_boss",            fairy_boss);
    }

    // -----------------------------------------------------------------------
    // --- Lecture de la conf
    // -----------------------------------------------------------------------

    Future<double> _fairyNum(String key, double fallback) async {

                                final v = await deva_get("fairy.$key");
                                if (v == null) return fallback;
                                return double.tryParse(v.toString()) ?? fallback;
    }

    // Le catalogue des cadeaux, tel que le voient les layers empilés (base + thème + packs
    // achetés). Dvidle, jamais une List : c'est ce qui permet de surcharger une entrée.
    Future<Dvidle?> _fairyGifts() async {

                                final g = await deva_get("fairy.gifts");
                                return (g is Dvidle) ? g : null;
    }

    // Traduction dans la langue courante, repli "fr" — même schéma que partout ailleurs dans le
    // worker (_showLevelUpAnimation, _notifyClanChest…). Repli sur la clef elle-même : un log de
    // mise au point qui affiche « dt_domain_salon » reste exploitable, un log vide ne l'est pas.
    Future<String> _fairyTr(String key) async {

                                if (key.isEmpty) return "";
                                final lang = TranslationRegistry.currentLang;
                                var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                                if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                                return v.isEmpty ? key : v;
    }

    // Libellé traduit d'un cadeau. Les libellés portent un saut de ligne (ils tiennent dans une
    // main, sur deux lignes) : `flat` le remplace par une espace pour les usages en ligne
    // (journal, journal de debug), où une coupure n'aurait aucun sens.
    Future<String> _fairyGiftLabel(String giftId, {bool flat = false}) async {

                                final gifts = await _fairyGifts();
                                final token = gifts?.get("$giftId.label")?.toString() ?? "";
                                if (token.isEmpty) return giftId;
                                final key = token.replaceAll("@@@T:", "").replaceAll("@@@", "");
                                final v   = await _fairyTr(key);
                                if (v == key) return giftId;      // clef non traduite : l'id est plus parlant
                                return flat ? v.replaceAll("\n", " ") : v;
    }

    // Nom lisible du tiroir et de la monstre-tâche où la fée se tient. Sert au journal de mise au
    // point du banc d'essai : sans lui, il faut ouvrir les dix-neuf domaines pour la trouver.
    // Le titre de la tâche suit la même règle d'affichage que le tiroir : un titre réécrit par un
    // chef (_titleOverride) l'emporte sur le libellé de catalogue.
    Future<String> _fairyWhere() async {

                                if (_fairyDomain.isEmpty) return "";
                                final domain = await _fairyTr("dt_domain_$_fairyDomain");
                                final task   = (_titleOverride[_fairyTaskId]?.isNotEmpty ?? false)
                                    ? _titleOverride[_fairyTaskId]!
                                    : await _fairyTr("dt_t_${_originalOf(_fairyTaskId)}");
                                return "onglet Combat → « $domain » ($_fairyDomain), "
                                       "à la place de « $task » ($_fairyTaskId)";
    }

    // -----------------------------------------------------------------------
    // --- L'état partagé (clans_items/{clan}/items/fairy)
    // -----------------------------------------------------------------------

    Future<Dvidle?> _readFairyDoc(String clanId, String clanSecret, String region) async {

                                try {
                                    return await _cloud?.read("workers", "clans_items/$clanId/items",
                                        _fairyDocId, ownerId: clanSecret, region: region);
                                } catch (e) {
                                    // Document absent (clan qui n'a encore jamais vu de fée) : les règles
                                    // Firestore refusent un `get` sur un doc inexistant, l'erreur est donc
                                    // NORMALE et ne doit rien journaliser en `error`.
                                    deva_log("info", "[fairy] pas encore de doc fée: $e");
                                    return null;
                                }
    }

    // Écriture ciblée (deep-merge) : ne touche QUE les champs passés. `last_roll` doit pouvoir se
    // réécrire seul, sans effacer une fenêtre en cours.
    Future<void> _writeFairyDoc(String clanId, String clanSecret, String region, Dvidle patch) async {

                                patch.set("ownerId", clanSecret);
                                patch.set("clanId",  clanId);
                                try {
                                    await _cloud?.write("workers", "clans_items/$clanId/items", _fairyDocId,
                                        patch, region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("error", "[fairy] écriture du doc fée FAILED: $e");
                                }
    }

    // Mémorise en RAM ce que le tiroir doit afficher. Le tiroir se reconstruit à chaque entrée
    // d'écran (_refreshTaskStatuses) et ne peut pas se permettre une lecture cloud à chaque fois :
    // ces trois champs sont sa seule source. Ils sont rafraîchis au tirage, à la vigilance, et à
    // l'expiration.
    void _cacheFairy(Dvidle? doc) {

                                final taken   = doc?.get("taken_by")?.toString()   ?? "";
                                final expires = doc?.get("expires_at")?.toString() ?? "";
                                final open    = doc != null && taken.isEmpty && _fairyWindowOpen(expires);
                                _fairyDomain  = open ? (doc.get("domain")?.toString()  ?? "") : "";
                                _fairyTaskId  = open ? (doc.get("task_id")?.toString() ?? "") : "";
                                _fairyExpires = open ? expires : "";
    }

    bool _fairyWindowOpen(String expiresIso) {

                                if (expiresIso.isEmpty) return false;
                                final t = DateTime.tryParse(expiresIso)?.toUtc();
                                return t != null && t.isAfter(DateTime.now().toUtc());
    }

    // La fée est-elle visible en ce moment, et dans quel tiroir ?
    bool get _fairyShowing => _fairyDomain.isNotEmpty && _fairyWindowOpen(_fairyExpires);

    // Ce que le tiroir doit ajouter (§_buildAdditionsMap) et ce qu'il doit cacher
    // (§_buildHiddenStatusMap). Deux getters, pour que la greffe côté worker_tasks tienne en une
    // ligne chacune et reste lisible.
    String get _fairyTiroirDvid => _fairyShowing ? "${_fairyDomain}_tasks/tiroir" : "";
    String get _fairyHiddenTask => _fairyShowing ? _fairyTaskId : "";

    Map<String, String> get _fairyAddition => {

        "id":     _fairyIconId,
        "image":  "images/medium/fairy_tile.png",
        "label":  "@@@T:fairy_tile@@@",
        "action": "worker.on_fairy_tap",
    };

    // -----------------------------------------------------------------------
    // --- 1) Le tirage
    // -----------------------------------------------------------------------
    //
    // Appelé depuis on_dashboard_appear : le dashboard est le passage obligé de tout joueur
    // enrôlé, et le tirage n'affiche RIEN — il ne concurrence donc aucune célébration.
    //
    // La courbe : p = (écoulé / cycle_days) ^ curve_exponent, bornée à [0, 1]. Nulle juste après
    // une apparition, certaine au terme du cycle.
    //
    // >>> `roll_every_hours` n'est pas un confort. Sans lui, le dé serait jeté à CHAQUE ouverture
    // de l'app, et un clan qui l'ouvre dix fois par jour verrait la fée dix fois plus souvent
    // qu'un clan qui l'ouvre une fois — la « cadence » ne voudrait plus rien dire. Le throttle la
    // rend indépendante de l'assiduité. Il est porté par le DOC DE CLAN (last_roll), pas par
    // l'appareil : cinq téléphones dans la famille, un seul tirage par jour.
    Future<void> _rollFairy() async {

                                try {
                                    final ctx = await _butinCtx();
                                    if (ctx == null) return;
                                    final region     = ctx.get("region").toString();
                                    final clanId     = ctx.get("clanId").toString();
                                    final clanSecret = ctx.get("clanSecret").toString();

                                    final now = DateTime.now().toUtc();
                                    final doc = await _readFairyDoc(clanId, clanSecret, region);

                                    // Premier contact : on AMORCE l'horloge sans faire apparaître quoi que ce
                                    // soit (expires_at déjà passé). Un clan tout neuf ne rencontre donc pas une
                                    // fée le jour de sa création — la magie n'en serait plus.
                                    if (doc == null) {
                                        final seed = Dvidle({});
                                        seed.set("started_at", now.toIso8601String());
                                        seed.set("expires_at", now.toIso8601String());
                                        seed.set("last_roll",  now.toIso8601String());
                                        seed.set("taken_by",   "");
                                        await _writeFairyDoc(clanId, clanSecret, region, seed);
                                        _cacheFairy(null);
                                        deva_log("info", "[fairy] horloge amorcée pour le clan $clanId");
                                        return;
                                    }

                                    // Fenêtre encore ouverte : elle est DÉJÀ là. Rien à tirer, mais il faut
                                    // armer la vigilance — c'est peut-être ce lancement-ci qui la découvre.
                                    final expires = doc.get("expires_at")?.toString() ?? "";
                                    final taken   = doc.get("taken_by")?.toString()   ?? "";
                                    if (taken.isEmpty && _fairyWindowOpen(expires)) {
                                        _cacheFairy(doc);
                                        _startFairyVigilance(clanId, clanSecret, region);
                                        deva_log("info", "[fairy] déjà présente (domaine=$_fairyDomain, jusqu'à $expires)");
                                        return;
                                    }
                                    _cacheFairy(doc);

                                    final everyH   = await _fairyNum("roll_every_hours", 24);
                                    final lastRoll = DateTime.tryParse(doc.get("last_roll")?.toString() ?? "")?.toUtc();
                                    if (lastRoll != null &&
                                        now.difference(lastRoll).inMinutes < (everyH * 60).round()) {
                                        return;   // déjà tiré aujourd'hui, par cet appareil ou par un autre
                                    }

                                    final cycleD  = await _fairyNum("cycle_days", 30);
                                    final expo    = await _fairyNum("curve_exponent", 1.0);
                                    final started = DateTime.tryParse(doc.get("started_at")?.toString() ?? "")?.toUtc()
                                                    ?? now;
                                    final days    = now.difference(started).inSeconds / 86400.0;
                                    var   p       = cycleD <= 0 ? 1.0 : pow(days / cycleD, expo).toDouble();
                                    if (p.isNaN || p < 0) p = 0.0;
                                    if (p > 1) p = 1.0;

                                    final roll = Random().nextDouble();
                                    deva_log("info", "[fairy] tirage: écoulé=${days.toStringAsFixed(2)}j "
                                                     "p=${p.toStringAsFixed(3)} dé=${roll.toStringAsFixed(3)}");
                                    if (roll >= p) {
                                        // Raté : on ne repousse QUE le throttle. started_at reste intact, sans
                                        // quoi la courbe repartirait de zéro à chaque échec et la fée ne
                                        // viendrait jamais.
                                        final u = Dvidle({});
                                        u.set("last_roll", now.toIso8601String());
                                        await _writeFairyDoc(clanId, clanSecret, region, u);
                                        return;
                                    }

                                    // Gagné. Le verrou empêche deux appareils qui ouvrent l'app dans la même
                                    // seconde de faire apparaître DEUX fées (deux domaines, deux jeux de
                                    // cadeaux). Le perdant sort en silence : il verra celle du gagnant.
                                    final lock = Deva.instance.module("dvlock") as dvlock?;
                                    final got  = await lock?.lock("fairy_roll_$clanId", _userId) ?? false;
                                    if (!got) {
                                        deva_log("info", "[fairy] apparition menée par un autre appareil");
                                        return;
                                    }

                                    await _spawnFairy(clanId, clanSecret, region, reason: "tirage");
                                } catch (e) {
                                    // JAMAIS fatal : le dashboard est l'écran d'accueil du jeu, il ne doit pas
                                    // dépendre du bon vouloir d'une fée.
                                    deva_log("error", "[fairy] _rollFairy FAILED: $e");
                                }
    }

    // Fait apparaître la fée : choisit sa place et ses deux cadeaux, puis écrit le doc partagé.
    // Facteur commun au tirage et au banc d'essai (force_fairy).
    Future<bool> _spawnFairy(String clanId, String clanSecret, String region,
                             {String reason = ""}) async {

                                final target = await _pickFairyTask(clanId, clanSecret, region);
                                if (target == null) {
                                    deva_log("warning", "[fairy] aucune monstre-tâche éligible — apparition annulée");
                                    return false;
                                }
                                final gifts = await _pickTwoGifts();
                                if (gifts.length < 2) {
                                    deva_log("warning", "[fairy] moins de deux cadeaux au catalogue — apparition annulée");
                                    return false;
                                }

                                final windowM = (await _fairyNum("window_minutes", 10)).round();
                                final now     = DateTime.now().toUtc();
                                final doc     = Dvidle({});
                                doc.set("started_at", now.toIso8601String());
                                doc.set("expires_at", now.add(Duration(minutes: windowM)).toIso8601String());
                                doc.set("last_roll",  now.toIso8601String());
                                doc.set("domain",     target["domain"]);
                                doc.set("task_id",    target["id"]);
                                doc.set("gift_left",  gifts[0]);
                                doc.set("gift_right", gifts[1]);
                                // Explicitement vide : le deep-merge dvcloud n'efface un champ que si on lui
                                // pose une chaîne vide. Sans ça, le `taken_by` de la fée PRÉCÉDENTE survivrait
                                // et la nouvelle naîtrait déjà prise.
                                doc.set("taken_by",   "");
                                doc.set("taken_at",   "");
                                await _writeFairyDoc(clanId, clanSecret, region, doc);

                                _fairyDomain  = target["domain"] ?? "";
                                _fairyTaskId  = target["id"]     ?? "";
                                _fairyExpires = doc.get("expires_at").toString();
                                // Miroir local des deux cadeaux. Ils seront de toute façon RELUS depuis le
                                // doc à la prise (c'est lui qui fait foi, et c'est peut-être un autre joueur
                                // qui touchera la fée) : on ne les pose ici que pour le journal de mise au
                                // point du banc d'essai, qui tourne avant que quiconque l'ait touchée.
                                _fairyGiftLeft  = gifts[0];
                                _fairyGiftRight = gifts[1];
                                _startFairyVigilance(clanId, clanSecret, region);
                                await _refreshTaskStatuses(force: true);

                                deva_log("info", "[fairy] APPARITION ($reason) : domaine=$_fairyDomain "
                                                 "à la place de $_fairyTaskId, cadeaux=${gifts[0]}/${gifts[1]}, "
                                                 "jusqu'à $_fairyExpires");
                                return true;
    }

    // La monstre-tâche que la fée remplace. Mêmes filtres que le `summonBoss` du serveur
    // (backend/config.yml) : une tâche VIVANTE, activée, visible, que personne ne tient. On ajoute
    // la contrainte des clones (`__`) : un clone appartient à un joueur précis, le masquer ne
    // priverait qu'une personne — et son tiroir n'est pas celui des autres.
    Future<Map<String, String>?> _pickFairyTask(String clanId, String clanSecret, String region) async {

                                var docs = _taskDocsCache.values.toList();
                                if (docs.isEmpty) {
                                    // Cache froid (app tout juste lancée, aucun tiroir encore ouvert) : on lit.
                                    try {
                                        final fetched = await _cloud?.list("workers", "clans_tasks/$clanId/tasks",
                                            region: region) ?? [];
                                        docs = List<Dvidle>.from(fetched);
                                    } catch (e) {
                                        deva_log("error", "[fairy] lecture des tâches FAILED: $e");
                                        return null;
                                    }
                                }

                                final eligible = <Map<String, String>>[];
                                for (final d in docs) {
                                    final id     = d.get("docId")?.toString()  ?? "";
                                    final domain = d.get("domain")?.toString() ?? "";
                                    if (id.isEmpty || domain.isEmpty) continue;
                                    if (id.contains("__")) continue;                                  // clone
                                    if (!_taskDomains.contains(domain)) continue;                     // domaine inconnu
                                    if (d.get("enabled") == false || d.get("visible") == false) continue;
                                    if ((d.get("status")?.toString()   ?? "") != "alive") continue;
                                    if ((d.get("assignee")?.toString() ?? "").isNotEmpty) continue;   // déjà tenue
                                    eligible.add({"id": id, "domain": domain});
                                }
                                if (eligible.isEmpty) return null;
                                return eligible[Random().nextInt(eligible.length)];
    }

    // Deux cadeaux DIFFÉRENTS, tirés au poids et SANS REMISE : le joueur doit arbitrer entre deux
    // choses distinctes, sinon le choix n'aurait aucun enjeu.
    Future<List<String>> _pickTwoGifts() async {

                                final gifts = await _fairyGifts();
                                if (gifts == null) return const [];
                                final ids     = <String>[];
                                final weights = <double>[];
                                for (final id in gifts.keys) {
                                    // Un cadeau sans action est une entrée mal formée (ou un genre apporté par
                                    // un pack dont le code n'est pas là) : on ne peut pas l'offrir.
                                    if ((gifts.get("$id.action")?.toString() ?? "").isEmpty) continue;
                                    final w = double.tryParse(gifts.get("$id.weight")?.toString() ?? "") ?? 1.0;
                                    if (w <= 0) continue;
                                    ids.add(id);
                                    weights.add(w);
                                }
                                if (ids.length < 2) return const [];

                                final rng  = Random();
                                final out  = <String>[];
                                for (var draw = 0; draw < 2; draw++) {
                                    var total = 0.0;
                                    for (final w in weights) total += w;
                                    if (total <= 0) break;
                                    var t = rng.nextDouble() * total;
                                    var k = weights.length - 1;
                                    for (var i = 0; i < weights.length; i++) {
                                        t -= weights[i];
                                        if (t <= 0) { k = i; break; }
                                    }
                                    out.add(ids[k]);
                                    ids.removeAt(k);          // sans remise
                                    weights.removeAt(k);
                                }
                                return out;
    }

    // -----------------------------------------------------------------------
    // --- Banc d'essai : la faire venir tout de suite
    // -----------------------------------------------------------------------
    //
    // Kebab de la boutique, gardé par store.debug.test_mode (layer CLOUD) : le bucket de
    // production ne pose pas ce drapeau, l'option n'existe donc pas chez les joueurs. Rien à
    // retirer plus tard.
    Future<void> force_fairy(dynamic caller, dynamic event) async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final ok = await _spawnFairy(ctx.get("clanId").toString(),
                                                             ctx.get("clanSecret").toString(),
                                                             ctx.get("region").toString(),
                                                             reason: "banc d'essai");
                                if (!ok) return;

                                // OÙ elle est, en toutes lettres et en évidence. Le banc d'essai la place
                                // dans un domaine AU HASARD parmi dix-neuf : sans cette ligne, la retrouver
                                // veut dire ouvrir les tiroirs un par un. En `warning` et non en `info` : la
                                // seule ligne du journal qu'on vient VRAIMENT y chercher ne doit pas se
                                // noyer dans le flot des lectures de tâches qui la suivent immédiatement.
                                final mins = (await _fairyNum("window_minutes", 10)).round();
                                deva_log("warning", "[fairy] ══════════════════════════════════════════");
                                deva_log("warning", "[fairy] BANC D'ESSAI — elle t'attend $mins min ici :");
                                deva_log("warning", "[fairy]   ${await _fairyWhere()}");
                                deva_log("warning", "[fairy]   cadeaux : "
                                    "${await _fairyGiftLabel(_fairyGiftLeft, flat: true)}"
                                    "  |  ${await _fairyGiftLabel(_fairyGiftRight, flat: true)}");
                                deva_log("warning", "[fairy] ══════════════════════════════════════════");
    }

    // -----------------------------------------------------------------------
    // --- 3) La prise — premier arrivé gagne
    // -----------------------------------------------------------------------
    //
    // Un joueur MORT a le droit de la toucher : c'est même tout l'intérêt des cadeaux de soin.
    // Aucune garde de mort ici, contrairement à _selectTask.
    Future<void> on_fairy_tap(dynamic caller, dynamic event) async {

                                if (_fairyTaking) return;              // double-tap sur la tuile
                                _fairyTaking = true;
                                try {
                                    final ctx = await _butinCtx();
                                    if (ctx == null) return;
                                    final region     = ctx.get("region").toString();
                                    final clanId     = ctx.get("clanId").toString();
                                    final clanSecret = ctx.get("clanSecret").toString();

                                    final doc = await _readFairyDoc(clanId, clanSecret, region);
                                    if (doc == null) { await _dropFairy(); return; }
                                    final started = doc.get("started_at")?.toString() ?? "";

                                    // Le verrou arbitre la course SIMULTANÉE (deux enfants qui tapent en même
                                    // temps, chacun sur son téléphone). Sa clef porte `started_at` : une fée
                                    // n'est pas l'autre, et le verrou de la précédente ne doit pas bloquer la
                                    // suivante — même si son TTL n'a pas encore expiré.
                                    final lock = Deva.instance.module("dvlock") as dvlock?;
                                    final got  = await lock?.lock("fairy_${clanId}_$started", _userId) ?? false;
                                    if (!got) {
                                        deva_log("info", "[fairy] quelqu'un d'autre l'a touchée en même temps");
                                        await _dropFairy();
                                        return;
                                    }

                                    // Le verrou ne dit RIEN de l'état durable (cf. worker_tasks : une tâche
                                    // prise plus tôt, verrou déjà expiré, doit rester imprenable). On relit.
                                    final fresh   = await _readFairyDoc(clanId, clanSecret, region) ?? doc;
                                    final taken   = fresh.get("taken_by")?.toString()   ?? "";
                                    final expires = fresh.get("expires_at")?.toString() ?? "";
                                    if (taken.isNotEmpty || !_fairyWindowOpen(expires)) {
                                        deva_log("info", "[fairy] trop tard (prise=$taken, fin=$expires)");
                                        await _dropFairy();
                                        return;
                                    }

                                    // Elle est à nous. L'écriture est ce qui la fait disparaître chez les
                                    // autres : leur vigilance voit `taken_by` se remplir.
                                    final now = DateTime.now().toUtc().toIso8601String();
                                    final u   = Dvidle({});
                                    u.set("taken_by", _userId);
                                    u.set("taken_at", now);
                                    await _writeFairyDoc(clanId, clanSecret, region, u);

                                    _fairyGiftLeft  = fresh.get("gift_left")?.toString()  ?? "";
                                    _fairyGiftRight = fresh.get("gift_right")?.toString() ?? "";
                                    _fairyResolving = false;
                                    _stopFairyVigilance();
                                    _cacheFairy(null);                  // la tuile n'a plus lieu d'être

                                    _startFairyMusic();
                                    DvOrb.navigate_new("fairy_page");
                                } catch (e) {
                                    deva_log("error", "[fairy] on_fairy_tap FAILED: $e");
                                } finally {
                                    _fairyTaking = false;
                                }
    }

    // Retire la tuile ici et maintenant (elle est prise, ou expirée). `force` court-circuite le
    // garde anti-rafale de 3 s de _refreshTaskStatuses : une fée qui disparaît doit disparaître
    // TOUT DE SUITE, sans quoi on tape sur un fantôme.
    Future<void> _dropFairy() async {

                                _cacheFairy(null);
                                _stopFairyVigilance();
                                await _refreshTaskStatuses(force: true);
    }

    // -----------------------------------------------------------------------
    // --- La musique
    // -----------------------------------------------------------------------
    //
    // Même idiome que le siège de combat (worker_combat._startCombatSiege), à une différence
    // près qui compte : la BOUCLE. Toutes les autres célébrations jouent un son qui finit ; la
    // fée reste à l'écran aussi longtemps que le joueur met à choisir, et le morceau doit tenir.
    //
    // (Re)chargement explicite : `sound.preload` a pu échouer si l'asset n'était pas encore
    // descendu. Si le Future se complète plus tard, la boucle démarre à ce moment — et le drapeau
    // l'empêche de démarrer après coup si le joueur a déjà choisi.
    void _startFairyMusic() {

                                if (_fairyMusicOn) return;
                                _fairyMusicOn = true;
                                ActionRegistry.get("dvsound.ambiance.pause")?.call(null, null);
                                final snd = ModuleRegistry.create("dvsound");
                                if (snd == null) return;
                                try {
                                    final f = (snd as dynamic).load("anim_fairy", "music/fairy.mp3");
                                    if (f is Future) {
                                        f.then((_) { if (_fairyMusicOn) (snd as dynamic).loop("anim_fairy"); });
                                    } else {
                                        (snd as dynamic).loop("anim_fairy");
                                    }
                                } catch (e) {
                                    deva_log("warning", "[fairy] musique: $e");
                                }
    }

    // Sortie de la fée : les deux musiques se CROISENT. Le thème repart tout de suite, et le
    // morceau de la fée se retire en descendant — il ne s'arrête jamais net.
    //
    // L'ordre compte, et il est contre-intuitif : on rend l'ambiance D'ABORD, pendant que l'autre
    // sonne encore. C'est ce chevauchement qui EST le fondu ; couper puis relancer laisserait un
    // trou de silence, et c'est précisément ce qu'on cherche à éviter.
    //
    // `fadeOut` et non `fade` : `fade` passe d'un son à un autre SON, alors que la musique de fond
    // est une playlist tenue par l'état d'ambiance de dvsound — les deux mondes ne se parlent pas.
    // Ils se composent en revanche très bien, l'un montant pendant que l'autre descend.
    //
    // Durée calée sur le fondu VISUEL (2 s, cf. _chooseFairyGift) : l'image et le son s'effacent
    // ensemble. Repli sur un arrêt net si le module est absent du build — muet vaut mieux que bloqué.
    void _stopFairyMusic() {

                                if (!_fairyMusicOn) return;
                                _fairyMusicOn = false;
                                ActionRegistry.get("dvsound.ambiance.resume")?.call(null, null);
                                final fade = ActionRegistry.get("dvsound.fadeout.anim_fairy.2000");
                                if (fade != null) {
                                    fade(null, null);
                                } else {
                                    ActionRegistry.get("dvsound.stop.anim_fairy")?.call(null, null);
                                }
    }

    // -----------------------------------------------------------------------
    // --- 4) La cérémonie
    // -----------------------------------------------------------------------

    // Arrivée sur fairy_page. Les deux libellés sont posés MAINTENANT (ils viennent du doc
    // partagé, la conf ne peut pas les connaître) mais restent invisibles : c'est la fin du
    // dernier acte de la scène qui les révèle.
    Future<void> on_fairy_appear(dynamic caller, dynamic event) async {

                                await _setFairyGiftsVisible(false);
                                await _setFairyLabel("left",  await _fairyGiftLabel(_fairyGiftLeft));
                                await _setFairyLabel("right", await _fairyGiftLabel(_fairyGiftRight));
                                // Scène MORTELLE et rejouable : `start` remet la pose à zéro. Sans ce
                                // rejeu explicite, une deuxième venue rouvrirait l'écran sur la pose finale
                                // de la première — la fée déjà là, sans cérémonie.
                                ActionRegistry.get("dvflame.start.fairy")?.call(null, null);
    }

    // Fin de l'acte 4 (la fée est entièrement révélée) : on montre les deux cadeaux. Tiré par la
    // CONF, depuis le `on_end` de l'effet — jamais par un délai en dur ici.
    Future<void> on_fairy_ready(dynamic caller, dynamic event) async {

                                if (_fairyResolving) return;   // le choix est déjà fait (rejeu tardif d'un hook)
                                await _setFairyGiftsVisible(true);
    }

    Future<void> on_fairy_choose_left(dynamic caller, dynamic event)  async => _chooseFairyGift(_fairyGiftLeft);
    Future<void> on_fairy_choose_right(dynamic caller, dynamic event) async => _chooseFairyGift(_fairyGiftRight);

    Future<void> _chooseFairyGift(String giftId) async {

                                if (_fairyResolving) return;             // les deux mains tapées coup sur coup
                                _fairyResolving = true;
                                await _setFairyGiftsVisible(false);      // plus rien à choisir

                                try {
                                    final gifts  = await _fairyGifts();
                                    final action = gifts?.get("$giftId.action")?.toString() ?? "";
                                    final lo     = int.tryParse(gifts?.get("$giftId.min")?.toString() ?? "") ?? 0;
                                    final hi     = int.tryParse(gifts?.get("$giftId.max")?.toString() ?? "") ?? 0;
                                    final amount = (hi > lo) ? lo + Random().nextInt(hi - lo + 1) : lo;

                                    if (action.isNotEmpty) {
                                        final fn = ActionRegistry.get(action);
                                        if (fn == null) {
                                            deva_log("error", "[fairy] cadeau '$giftId' : action '$action' inconnue");
                                        } else {
                                            await fn(null, {"gift": giftId, "amount": amount});
                                        }
                                    }
                                    await _announceFairyGift(giftId, amount);
                                } catch (e) {
                                    deva_log("error", "[fairy] application du cadeau '$giftId' FAILED: $e");
                                }

                                // L'IMAGE ET LE SON s'effacent ENSEMBLE : le fondu sonore part ici, en même
                                // temps que le fondu visuel ci-dessous, et sur la même durée. L'attendre
                                // jusqu'à on_fairy_done le ferait commencer quand le visuel est déjà fini —
                                // on entendrait la fée deux secondes de plus, sur l'écran du tiroir.
                                _stopFairyMusic();

                                // Le fondu de sortie n'est PAS dans la timeline de la scène (elle est finie
                                // depuis que la fée est apparue) : ce sont des effets ponctuels, tirés à la
                                // demande. `dvflame.trigger` les exécute sur une scène finie sans difficulté —
                                // le game tourne toujours, seule la timeline s'est tue.
                                void fade(String target, num to, {bool last = false}) {
                                    final e = <String, dynamic>{
                                        "scene": "fairy", "target": target, "to": to, "duration": 2.0,
                                    };
                                    // Le retour est accroché à la fin du fondu du VOILE NOIR : quand il est
                                    // transparent, il n'y a plus rien à voir. Ancré sur l'effet, pas sur un
                                    // Future.delayed — changer la durée ci-dessus suffit.
                                    if (last) {
                                        e["on_end"] = {"back": {"order": 1, "action": "worker.on_fairy_done"}};
                                    }
                                    ActionRegistry.get("dvflame.trigger")?.call(null, e);
                                }
                                fade("fee.opacity", 0);
                                fade("lumiere.opacity", 0);
                                fade("givre.opacity", 0);
                                fade("neige.emission.rate", 0);
                                fade("givre_haut.emission.rate", 0);
                                fade("givre_bas.emission.rate", 0);
                                fade("givre_gauche.emission.rate", 0);
                                fade("givre_droite.emission.rate", 0);
                                fade("noir.opacity", 0, last: true);
    }

    // Fin du fondu visuel : on rend l'écran. La musique, elle, a commencé à se retirer deux
    // secondes plus tôt (au choix du cadeau) et achève son fondu pendant ce retour — c'est voulu :
    // le thème est déjà en train de reprendre quand le tiroir reparaît.
    // Garde : _stopFairyMusic est idempotent (drapeau _fairyMusicOn), un second appel ne ferait
    // rien — mais il n'y en a pas, la sortie de la musique appartient à _chooseFairyGift.
    Future<void> on_fairy_done(dynamic caller, dynamic event) async {

                                // >>> PAS de `dvflame.stop.fairy` ici. `stop` reconstruit la POSE INITIALE
                                // (cf. dvscene_motor : _clearEffects + rebuild + une frame à dt=0) — et la
                                // pose initiale de cette scène-ci, c'est le voile noir OPAQUE. L'appeler
                                // ferait clignoter l'écran en noir juste après le fondu qu'on vient de
                                // jouer, soit exactement ce que le fondu servait à éviter.
                                // Rien à libérer de toute façon : la scène est détruite d'elle-même quand sa
                                // dernière vue se détache, c'est-à-dire au pop ci-dessous.
                                //
                                // Pop SIMPLE (sans argument) : on revient au tiroir d'où l'on vient. Passer
                                // "fairy_page" ferait un popUntil VERS la page courante, c'est-à-dire rien.
                                DvOrb.navigate_back();
                                await _refreshTaskStatuses(force: true);
    }

    // Les deux libellés naissent invisibles en conf. Comme pour l'overlay de mort, il faut agir à
    // DEUX niveaux : le template de conf (pour une page qui naîtrait ensuite) et les instances
    // déjà montées (celle qu'on regarde). Pas de `store()` ici, en revanche : cet état est
    // éphémère, le persister sur disque figerait des cadeaux visibles au prochain démarrage.
    Future<void> _setFairyGiftsVisible(bool v) async {

                                for (final side in const ["left", "right"]) {
                                    await deva_set("registry.fairy_page/gift_$side.shape.visible", v);
                                    await deva_set("registry.fairy_page/glow_$side.shape.visible", v);
                                }
                                for (final p in DvPage.actives) {
                                    for (final side in const ["left", "right"]) {
                                        final lbl  = p.get_shape_by_id("fairy_page/gift_$side");
                                        final glow = p.get_shape_by_id("fairy_page/glow_$side");
                                        if (v) { lbl?.show(); glow?.show(); } else { lbl?.hide(); glow?.hide(); }
                                    }
                                }
    }

    Future<void> _setFairyLabel(String side, String text) async {

                                await deva_set("registry.fairy_page/gift_$side.shape.label", text);
                                for (final p in DvPage.actives) {
                                    final lbl = p.get_shape_by_id("fairy_page/gift_$side");
                                    if (lbl is DvLabel) lbl.write(text);   // pose le label ET recalcule l'affichage
                                }
    }

    // Journal du clan puis notification. Dans cet ordre : le récit est la trace durable, le push
    // n'est qu'un messager. Aucun des deux n'est fatal — le cadeau est déjà crédité quand on
    // arrive ici, et un push raté ne doit pas se lire comme un cadeau raté.
    Future<void> _announceFairyGift(String giftId, int amount) async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final region     = ctx.get("region").toString();
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final name = (await Deva.instance.get("session.user.name"))?.toString() ?? "";

                                await _writeClanLog(clanId, clanSecret, region, "FairyGift",
                                    userId: _userId, slug: giftId,
                                    data: Dvidle({
                                        "playerId":   _userId,
                                        "playerName": name,
                                        "gift":       giftId,
                                        "amount":     amount,
                                    }));

                                await _notifyClanFairy(clanId, region, name);
    }

    // -----------------------------------------------------------------------
    // --- Les sept cadeaux
    // -----------------------------------------------------------------------

    int _fairyAmount(dynamic event) =>
        int.tryParse((event is Map ? event["amount"]?.toString() : "") ?? "") ?? 0;

    // Les membres qui comptent : ni révoqués (tombstone `enabled:false`), ni déclarés hors ligne.
    // Mêmes filtres que le partage d'XP et du butin — un cadeau « pour tout le clan » ne doit pas
    // se diluer sur des joueurs qui n'y sont plus.
    Future<List<Dvidle>> _fairyActiveMembers(String clanId, String clanSecret, String region) async {

                                try {
                                    final players = await _cloud?.list("workers", "clans_players/$clanId/players",
                                        region: region) ?? [];
                                    return List<Dvidle>.from(players).where((p) {
                                        final id = p.get("id")?.toString() ?? "";
                                        return id.isNotEmpty
                                            && p.get("enabled")    != false
                                            && p.get("has_device") != false;
                                    }).toList();
                                } catch (e) {
                                    deva_log("error", "[fairy] lecture du roster FAILED: $e");
                                    return const [];
                                }
    }

    Future<String> _fairyRandomOther(String clanId, String clanSecret, String region) async {

                                final others = (await _fairyActiveMembers(clanId, clanSecret, region))
                                    .map((p) => p.get("id")?.toString() ?? "")
                                    .where((id) => id.isNotEmpty && id != _userId)
                                    .toList();
                                if (others.isEmpty) return "";
                                return others[Random().nextInt(others.length)];
    }

    // --- XP ---------------------------------------------------------------
    //
    // _creditXp SANS `lastTaskWhen` : le joueur le perçoit comme un CADEAU et non comme une
    // victoire (c'est exactement ce que fait le « coup de pouce » d'un chef). Ni le clan ni le
    // butin ne sont crédités : la fée donne aux gens, pas à la trésorerie.
    Future<void> fairy_xp_self(dynamic caller, dynamic event) async {

                                final n = _fairyAmount(event);
                                if (n <= 0) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                await _creditXp(ctx.get("clanId").toString(), ctx.get("clanSecret").toString(),
                                    ctx.get("region").toString(), _userId, n);
                                await _quietGiftCelebration();
                                deva_log("info", "[fairy] +$n XP pour soi");
    }

    Future<void> fairy_xp_other(dynamic caller, dynamic event) async {

                                final n = _fairyAmount(event);
                                if (n <= 0) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                final who = await _fairyRandomOther(clanId, clanSecret, region);
                                // Clan d'une seule personne : la fée ne peut pas offrir « à un autre ». Elle
                                // ne reprend pas son cadeau pour autant — il revient au joueur.
                                if (who.isEmpty) {
                                    await _creditXp(clanId, clanSecret, region, _userId, n);
                                    await _quietGiftCelebration();
                                    deva_log("info", "[fairy] +$n XP : personne d'autre dans le clan → pour soi");
                                    return;
                                }
                                await _creditXp(clanId, clanSecret, region, who, n);
                                deva_log("info", "[fairy] +$n XP pour $who");
    }

    Future<void> fairy_xp_clan(dynamic caller, dynamic event) async {

                                final n = _fairyAmount(event);
                                if (n <= 0) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                for (final p in await _fairyActiveMembers(clanId, clanSecret, region)) {
                                    final id = p.get("id")?.toString() ?? "";
                                    if (id.isEmpty) continue;
                                    await _creditXp(clanId, clanSecret, region, id, n);
                                }
                                await _quietGiftCelebration();
                                deva_log("info", "[fairy] +$n XP pour tout le clan");
    }

    // --- Soin -------------------------------------------------------------
    //
    // Aucun de ces cadeaux n'écrit de PV : les PV ne sont pas stockés, ils se CALCULENT depuis
    // `last_task`. Soigner, c'est reculer cette date (cf. _healPlayer, factorisé depuis
    // revive_player).
    Future<void> fairy_heal_self(dynamic caller, dynamic event) async {

                                final n = _fairyAmount(event);
                                if (n <= 0) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                await _healPlayer(ctx.get("clanId").toString(), ctx.get("clanSecret").toString(),
                                    ctx.get("region").toString(), _userId, n);
                                deva_log("info", "[fairy] +$n PV pour soi");
    }

    Future<void> fairy_heal_other(dynamic caller, dynamic event) async {

                                final n = _fairyAmount(event);
                                if (n <= 0) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                final who = await _fairyRandomOther(clanId, clanSecret, region);
                                final target = who.isEmpty ? _userId : who;   // cf. fairy_xp_other
                                await _healPlayer(clanId, clanSecret, region, target, n);
                                deva_log("info", "[fairy] +$n PV pour $target");
    }

    Future<void> fairy_heal_clan(dynamic caller, dynamic event) async {

                                final n = _fairyAmount(event);
                                if (n <= 0) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                for (final p in await _fairyActiveMembers(clanId, clanSecret, region)) {
                                    final id = p.get("id")?.toString() ?? "";
                                    if (id.isEmpty) continue;
                                    await _healPlayer(clanId, clanSecret, region, id, n);
                                }
                                deva_log("info", "[fairy] +$n PV pour tout le clan");
    }

    // --- Boss -------------------------------------------------------------
    //
    // Même chemin que « Recommander » (worker_admin.on_recommend_task), mais SANS
    // _notifyClanBoss : la notification de la fée porte déjà la nouvelle, et le badge XP est
    // visible dans le tiroir. Deux pushes coup sur coup pour un seul événement seraient du bruit.
    Future<void> fairy_boss(dynamic caller, dynamic event) async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();

                                // Éligibilité : une tâche vivante et libre, qui n'est pas DÉJÀ un boss —
                                // recommander un boss ne ferait rien de visible.
                                final target = await _pickFairyTask(clanId, clanSecret, region);
                                if (target == null) {
                                    deva_log("warning", "[fairy] aucune tâche éligible pour un boss");
                                    return;
                                }
                                final id = target["id"] ?? "";
                                if ((await deva_get("tasks.$id.recommended"))?.toString().isNotEmpty == true) {
                                    deva_log("info", "[fairy] $id est déjà un boss — rien à faire");
                                    return;
                                }

                                final now = DateTime.now().toUtc().toIso8601String();
                                try {
                                    final doc = Dvidle({});
                                    doc.set("ownerId",     clanSecret);
                                    doc.set("clanId",      clanId);
                                    doc.set("recommended", now);
                                    _stampTouched(doc);
                                    await _cloud?.write("workers", "clans_tasks/$clanId/tasks", id, doc,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("error", "[fairy] réveil du boss $id FAILED: $e");
                                    return;
                                }
                                await deva_set("tasks.$id.recommended", now);
                                await _refreshTaskStatuses(force: true);
                                deva_log("info", "[fairy] boss réveillé : $id");
    }

    // Rebase le drapeau anti-double-fire de la célébration « cadeau d'XP ». Sans ça, la vigilance
    // du doc joueur verrait l'XP monter à `last_task` inchangé et lancerait l'animation giftxp
    // PAR-DESSUS la fée, au moment même où elle s'efface. Une vraie montée de NIVEAU, elle, garde
    // le droit de partir après le fondu : c'est un bon final, et elle passe par un autre chemin.
    Future<void> _quietGiftCelebration() async {

                                try {
                                    final ctx = await _butinCtx();
                                    if (ctx == null) return;
                                    final doc = await _cloud?.read("workers",
                                        "clans_players/${ctx.get("clanId")}/players", _userId,
                                        ownerId: ctx.get("clanSecret").toString(),
                                        region: ctx.get("region").toString());
                                    final xp = int.tryParse(doc?.get("xp")?.toString() ?? "") ?? 0;
                                    await deva_set("session.player_last_xp", xp);
                                } catch (e) {
                                    deva_log("warning", "[fairy] rebase player_last_xp: $e");
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
