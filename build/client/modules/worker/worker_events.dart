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

// LE MOTEUR D'ÉVÉNEMENTS. Le catalogue vit en conf (layers/events-base-global.yml) ; ce fichier
// n'en connaît que les PIÈCES : les moments (quand), les mises en scène (comment), les effets
// (quoi). Un événement qui combine des pièces existantes ne demande aucune ligne ici.
//
// TROIS RÈGLES TENUES ICI ET NULLE PART AILLEURS, pour qu'aucune entrée de YAML ne puisse les
// oublier :
//   1. dérisoire      : chaque montant est ramené aux plafonds `events.limits` ;
//   2. jamais sous 1 PV : un dégât ne sort que si `damage` vaut 0 ET que le joueur garde au moins
//                       1 PV après lui ; il est effacé par la prochaine tâche validée
//                       (_creditXp, _clearEventDamage) ;
//   3. sans captation : les moments « écran » ne tirent qu'une fois par jour et par joueur, et
//                       `per_day` borne le total.
//
// Tout ce qui s'affiche reste LOCAL à l'appareil : un gobelin n'apparaît que chez celui qui l'a
// tiré. Seuls les EFFETS touchent les autres (l'XP du membre imité par un changelin), par les
// chemins existants, qui lui jouent sa propre célébration.

// Moments « écran » : un tirage par jour et par joueur, quel que soit le nombre de visites.
const Set<String> _kEvtScreenMoments = <String>{"clan_screen", "inventory"};

// Mises en scène qui vivent dans la liste du clan (et non dans un message).
const Set<String> _kEvtRosterScenes = <String>{"fake_member", "double_member"};

// Préfixe des membres fictifs injectés dans le roster : jamais un id Firestore.
const String _kEvtFakePrefix = "__evt_";

// L'overlay de message (commons/evt_*, injecté par page_taskbar). Une seule liste pour ouvrir et
// refermer : un widget oublié resterait affiché par-dessus le jeu.
const List<String> _kEvtMessageShapes = <String>[
    "commons/evt_scrim",
    "commons/evt_panel",
    "commons/evt_image",
    "commons/evt_text",
    "commons/evt_ok",
];

// -----------------------------------------------------------------------------
// --- worker extension : événements aléatoires
// -----------------------------------------------------------------------------
extension Worker_events on worker {

    void _register_events() {

                                // Bouton de l'overlay de message : c'est LE clic qui compte (effets,
                                // journal, notification) pour la mise en scène `message`.
                                ActionRegistry.register("worker.on_event_ok",               on_event_ok);

                                // Option « Chasser » du roster (gobelin, changelin).
                                ActionRegistry.register("worker.on_event_chase",            on_event_chase);

                                // Option « Utiliser » d'un objet consommable (potion) : applique le
                                // `use` de son TYPE par les mêmes effets typés, puis le supprime.
                                ActionRegistry.register("worker.item_use",                  item_use);
    }

    // -----------------------------------------------------------------------
    // --- Lecture de la conf
    // -----------------------------------------------------------------------

    Future<Dvidle?> _evtCatalog() async {

                                final c = await deva_get("events.catalog");
                                return (c is Dvidle) ? c : null;
    }

    Future<int> _evtLimit(String key, int fallback) async {

                                final v = await deva_get("events.limits.$key");
                                return int.tryParse(v?.toString() ?? "") ?? fallback;
    }

    // Plafond d'un effet selon son type : c'est ce qui garantit « dérisoire » quel que soit le YAML.
    Future<int> _evtClamp(String type, int value) async {

                                final max = switch (type) {
                                    "xp"     => await _evtLimit("xp_max",     15),
                                    "damage" => await _evtLimit("damage_max",  1),
                                    "heal"   => await _evtLimit("heal_max",    1),
                                    _        => value,
                                };
                                if (value < 0) return 0;
                                return value > max ? max : value;
    }

    String _evtToday() {

                                final d = DateTime.now();
                                return "${d.year.toString().padLeft(4, "0")}-"
                                       "${d.month.toString().padLeft(2, "0")}-"
                                       "${d.day.toString().padLeft(2, "0")}";
    }

    // -----------------------------------------------------------------------
    // --- Le tirage
    // -----------------------------------------------------------------------

    // Point d'entrée des moments. Tire (au plus un événement), puis le met en scène. Renvoie true si
    // un événement de ROSTER vient d'être posé : l'écran du clan doit alors se rafraîchir.
    // `waitIdle` : attendre la fin d'une célébration en cours avant de rien montrer (jamais deux
    // spectacles à la fois). Faux pour l'écran du clan, dont l'événement se glisse dans la liste.
    Future<bool> _evtAt(String moment, {bool waitIdle = true}) async {

                                if (_evtRolling) return false;
                                _evtRolling = true;
                                try {
                                    if (waitIdle) {
                                        // Laisse à la page le temps de naître, et à une célébration qui
                                        // démarre le temps de poser `interludes.playing`.
                                        await Future.delayed(const Duration(milliseconds: 800));
                                        await _waitInterludesIdle();
                                        // Pas d'overlay de message sur cette page (écran sans taskbar) :
                                        // on ne tire pas, plutôt que de compter un événement invisible.
                                        if (DvOrb.get_shape_by_id("commons/evt_ok") == null) return false;
                                    }
                                    final ev = await _evtRoll(moment);
                                    if (ev == null) return false;
                                    final scene = ev["scene"]?.toString() ?? "message";
                                    deva_log("info", "[events] $moment → ${ev["id"]} ($scene)");

                                    if (_kEvtRosterScenes.contains(scene)) {
                                        _evtActive = ev;
                                        return true;
                                    }
                                    if (scene == "item") {
                                        // L'objet est DÉJÀ là quand le message le dit : on l'applique, puis
                                        // on l'annonce. Recharger la grille le fait paraître.
                                        await _evtResolve(ev);
                                        final ctx = await _butinCtx();
                                        if (ctx != null) {
                                            await _loadClanItems(ctx.get("clanId").toString(),
                                                ctx.get("clanSecret").toString(), ctx.get("region").toString());
                                        }
                                        await _evtShowMessage(ev, ev["text"]?.toString() ?? "");
                                        return false;
                                    }
                                    // `message` : les effets attendent le clic sur OK.
                                    _evtOnOk = ev;
                                    await _evtShowMessage(ev, ev["text"]?.toString() ?? "");
                                    return false;
                                } catch (e) {
                                    deva_log("error", "[events] _evtAt($moment) FAILED: $e");
                                    return false;
                                } finally {
                                    _evtRolling = false;
                                }
    }

    // Tire un événement pour ce moment, ou null. Écrit les compteurs du joueur AVANT de rendre la
    // main : un événement tiré compte dans le plafond du jour, qu'il soit cliqué ou non.
    Future<Map<String, dynamic>?> _evtRoll(String moment) async {

                                // --- Garde-fous globaux --------------------------------------------
                                // Un événement abandonné ne bloque pas les suivants : un message dont
                                // l'overlay n'est plus à l'écran (le joueur a navigué sans cliquer), un
                                // intrus resté dans la mémoire alors qu'on a quitté l'écran du clan.
                                if (_evtOnOk != null
                                    && DvOrb.get_shape_by_id("commons/evt_ok")?.get("shape.visible") != true) {
                                    _evtOnOk = null;
                                }
                                if (_evtActive != null && DvOrb.get_current_page()?.dvid != "clan_page") {
                                    _evtActive = null;
                                }
                                if (_evtActive != null || _evtOnOk != null) return null;   // un seul à la fois
                                if (_impersonating) return null;       // la récompense irait à la mauvaise personne
                                if ((await deva_get("deva.active_mode"))?.toString() == "showcase") return null;

                                final ctx = await _butinCtx();
                                if (ctx == null || _userId.isEmpty) return null;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();

                                final catalog = await _evtCatalog();
                                if (catalog == null) return null;

                                final me = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                    ownerId: clanSecret, region: region);
                                if (me == null || me.get("xp") == null) return null;   // lecture ratée : on s'abstient
                                if (me.get("has_device") == false)      return null;
                                if (me.get("hors_concours") == true)    return null;
                                if (me.get("status")?.toString() == "dead") return null;

                                final maxPv  = int.tryParse(me.get("pv")?.toString() ?? "$_playerPv") ?? _playerPv;
                                final damage = int.tryParse(me.get("damage")?.toString() ?? "0") ?? 0;
                                final pvNow  = _computeDisplayedPv(maxPv, damage,
                                    me.get("last_task")?.toString() ?? "", _readDecay(me.get("decay")));
                                if (pvNow <= 0) return null;

                                final today   = _evtToday();
                                final sameDay = me.get("events.day")?.toString() == today;
                                final count   = sameDay ? (int.tryParse(me.get("events.count")?.toString() ?? "0") ?? 0) : 0;
                                final perDay  = await _evtLimit("per_day", 2);
                                final screen  = _kEvtScreenMoments.contains(moment);

                                // Moment « écran » déjà tiré aujourd'hui : ouvrir l'écran une fois de plus
                                // ne change rien. C'est la règle anti-captation.
                                if (screen && me.get("events.rolled.$moment")?.toString() == today) return null;

                                final counters = Dvidle({});
                                counters.set("id", _userId);
                                if (screen) counters.set("events.rolled.$moment", today);

                                Map<String, dynamic>? picked;
                                if (count < perDay) {
                                    // --- Candidats -------------------------------------------------
                                    final now    = DateTime.now().toUtc();
                                    final level  = getNiveauProgres(int.tryParse(me.get("xp")?.toString() ?? "0") ?? 0).niveau;
                                    final legal  = me.get("legal_state")?.toString() ?? "";
                                    int? members;                                  // lu à la demande seulement
                                    final ids    = <String>[];
                                    final chance = <double>[];
                                    for (final id in catalog.keys) {
                                        final key = id.toString();
                                        if (catalog.get("$key.moment")?.toString() != moment) continue;
                                        final c = double.tryParse(catalog.get("$key.chance")?.toString() ?? "") ?? 0.0;
                                        if (c <= 0) continue;

                                        // Délai propre à cet événement.
                                        final cd   = double.tryParse(catalog.get("$key.cooldown_hours")?.toString() ?? "") ?? 0.0;
                                        final last = DateTime.tryParse(me.get("events.last.$key")?.toString() ?? "")?.toUtc();
                                        if (cd > 0 && last != null && now.difference(last).inMinutes < cd * 60) continue;

                                        // Conditions déclarées.
                                        final lvlMin = int.tryParse(catalog.get("$key.conditions.level_min")?.toString() ?? "");
                                        if (lvlMin != null && level < lvlMin) continue;
                                        final pvMin = int.tryParse(catalog.get("$key.conditions.pv_min")?.toString() ?? "");
                                        if (pvMin != null && pvNow < pvMin) continue;
                                        final ls = catalog.get("$key.conditions.legal_state")?.toString() ?? "";
                                        if (ls.isNotEmpty && ls != legal) continue;
                                        final memMin = int.tryParse(catalog.get("$key.conditions.members_min")?.toString() ?? "");
                                        if (memMin != null) {
                                            members ??= (await _fairyActiveMembers(clanId, clanSecret, region)).length;
                                            if (members < memMin) continue;
                                        }

                                        // JAMAIS SOUS 1 PV, et un seul dégât à la fois.
                                        if (!await _evtDamageAllowed(catalog, key, damage, pvNow)) continue;

                                        ids.add(key);
                                        chance.add(c);
                                    }

                                    // --- Tirage : au plus un, par chances cumulées -----------------
                                    if (ids.isNotEmpty) {
                                        final r = Random().nextDouble();
                                        var cum = 0.0;
                                        for (var i = 0; i < ids.length; i++) {
                                            cum += chance[i];
                                            if (r < cum) {
                                                picked = _evtBuild(catalog, ids[i]);
                                                break;
                                            }
                                        }
                                    }
                                }

                                if (picked != null) {
                                    counters.set("events.day",   today);
                                    counters.set("events.count", count + 1);
                                    counters.set("events.last.${picked["id"]}", DateTime.now().toUtc().toIso8601String());
                                }
                                if (picked != null || screen) {
                                    try {
                                        await _cloud?.write("workers", "clans_players/$clanId/players", _userId, counters,
                                            region: region, ownerId: clanSecret);
                                    } catch (e) {
                                        // Compteurs non écrits : on renonce plutôt que de risquer de
                                        // dépasser le plafond du jour au prochain passage.
                                        deva_log("error", "[events] compteurs non écrits ($e) : événement abandonné");
                                        return null;
                                    }
                                }
                                return picked;
    }

    // Un événement porteur de dégât n'est candidat que si le joueur n'en porte aucun et qu'il lui
    // restera au moins 1 PV. Le montant est celui qui sera APPLIQUÉ, donc plafonné.
    Future<bool> _evtDamageAllowed(Dvidle catalog, String key, int damage, int pvNow) async {

                                final effects = catalog.get("$key.effects");
                                if (effects is! Dvidle) return true;
                                for (final ek in effects.keys) {
                                    if (effects.get("$ek.type")?.toString() != "damage") continue;
                                    if (damage.abs() > 0) return false;
                                    final v = await _evtClamp("damage",
                                        int.tryParse(effects.get("$ek.value")?.toString() ?? "1") ?? 1);
                                    if (pvNow - v < 1) return false;
                                }
                                return true;
    }

    // Copie « plate » d'une entrée du catalogue, figée au moment du tirage : un upload de conf
    // pendant que l'événement est à l'écran ne change pas ce qu'il promet.
    Map<String, dynamic> _evtBuild(Dvidle catalog, String id) {

                                String s(String k) => catalog.get("$id.$k")?.toString() ?? "";
                                final effects = <String, Map<String, dynamic>>{};
                                final raw = catalog.get("$id.effects");
                                if (raw is Dvidle) {
                                    for (final ek in raw.keys) {
                                        final t   = raw.get("$ek.target");
                                        final tgt = (t is List) ? t.map((e) => e.toString()).toList()
                                                  : <String>[(t ?? "self").toString()];
                                        effects[ek.toString()] = {
                                            "type":   raw.get("$ek.type")?.toString() ?? "",
                                            "target": tgt,
                                            "value":  int.tryParse(raw.get("$ek.value")?.toString() ?? "0") ?? 0,
                                            "item":   raw.get("$ek.item")?.toString() ?? "",
                                        };
                                    }
                                }
                                return {
                                    "id":        id,
                                    "instance":  "${id}_${DateTime.now().toUtc().millisecondsSinceEpoch}",
                                    "scene":     s("scene").isEmpty ? "message" : s("scene"),
                                    "image":     s("image"),
                                    "text":      s("text"),
                                    "text_miss": s("text_miss"),
                                    "name":      s("name"),
                                    "notify":    s("notify"),
                                    "effects":   effects,
                                };
    }

    // -----------------------------------------------------------------------
    // --- Application des effets (inscrire AVANT d'appliquer)
    // -----------------------------------------------------------------------

    // Applique les effets d'un événement. `clicked` : le joueur l'a découvert ET a cliqué dessus →
    // journal et notification. Le plan est d'abord inscrit dans `events.pending` du joueur, chaque
    // effet appliqué y est coché, et le tout est effacé à la fin : un plantage entre deux laisse
    // de quoi reprendre au lancement suivant (_evtReplayPending), sans rien appliquer deux fois.
    Future<void> _evtResolve(Map<String, dynamic> ev, {bool clicked = false}) async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();

                                // Plan concret : cibles résolues en identifiants, montants plafonnés.
                                final plan = <String, dynamic>{};
                                final effects = (ev["effects"] as Map?) ?? const {};
                                for (final entry in effects.entries) {
                                    final e    = Map<String, dynamic>.from(entry.value as Map);
                                    final type = e["type"]?.toString() ?? "";
                                    final value = await _evtClamp(type, int.tryParse(e["value"]?.toString() ?? "0") ?? 0);
                                    final targets = <String>[];
                                    for (final t in List<String>.from(e["target"] as List? ?? const ["self"])) {
                                        if (t == "self") {
                                            targets.add(_userId);
                                        } else if (t == "imitated") {
                                            final other = ev["imitated"]?.toString() ?? "";
                                            if (other.isNotEmpty && other != _userId) targets.add(other);
                                        } else if (t == "clan") {
                                            for (final p in await _fairyActiveMembers(clanId, clanSecret, region)) {
                                                final pid = p.get("id")?.toString() ?? "";
                                                if (pid.isNotEmpty) targets.add(pid);
                                            }
                                        }
                                    }
                                    for (var i = 0; i < targets.length; i++) {
                                        plan["${entry.key}_$i"] = {
                                            "type": type, "target": targets[i], "value": value,
                                            "item": e["item"]?.toString() ?? "",
                                        };
                                    }
                                }

                                final pending = Dvidle({});
                                pending.set("id", _userId);
                                pending.set("events.pending", {
                                    "id": ev["id"], "instance": ev["instance"], "plan": plan,
                                });
                                try {
                                    await _cloud?.write("workers", "clans_players/$clanId/players", _userId, pending,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("error", "[events] plan non inscrit ($e) : rien n'est appliqué");
                                    return;
                                }

                                await _evtApplyPlan(clanId, clanSecret, region,
                                    ev["instance"]?.toString() ?? "", plan, const {});

                                if (!clicked) return;
                                final name = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                await _writeClanLog(clanId, clanSecret, region, "EventFound",
                                    userId: _userId, slug: ev["id"]?.toString() ?? "",
                                    data: Dvidle({
                                        "playerId":   _userId,
                                        "playerName": name,
                                        "event":      ev["id"],
                                    }));
                                final notify = ev["notify"]?.toString() ?? "";
                                if (notify.isNotEmpty) await _notifyClanKey(clanId, region, notify, name);
    }

    // Applique un plan, effet par effet, en cochant chacun dans `events.pending.done` ; efface le
    // plan à la fin (deep-merge dvcloud : "" efface).
    Future<void> _evtApplyPlan(String clanId, String clanSecret, String region,
                               String instance, Map<String, dynamic> plan, Map done) async {

                                for (final entry in plan.entries) {
                                    if (done[entry.key] == true) continue;
                                    final e = Map<String, dynamic>.from(entry.value as Map);
                                    await _evtApplyEffect(clanId, clanSecret, region, instance, entry.key, e);
                                    final tick = Dvidle({});
                                    tick.set("id", _userId);
                                    tick.set("events.pending.done.${entry.key}", true);
                                    try {
                                        await _cloud?.write("workers", "clans_players/$clanId/players", _userId, tick,
                                            region: region, ownerId: clanSecret);
                                    } catch (e) {
                                        deva_log("warning", "[events] effet ${entry.key} non coché : $e");
                                    }
                                }
                                final clear = Dvidle({});
                                clear.set("id", _userId);
                                clear.set("events.pending", "");
                                try {
                                    await _cloud?.write("workers", "clans_players/$clanId/players", _userId, clear,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("warning", "[events] plan non effacé : $e");
                                }
    }

    // Les effets typés. Un nouveau TYPE est du code, ici ; un nouvel événement n'en est pas.
    Future<void> _evtApplyEffect(String clanId, String clanSecret, String region,
                                 String instance, String key, Map<String, dynamic> e) async {

                                final type   = e["type"]?.toString() ?? "";
                                final target = e["target"]?.toString() ?? "";
                                final value  = int.tryParse(e["value"]?.toString() ?? "0") ?? 0;
                                if (target.isEmpty) return;
                                final coll = "clans_players/$clanId/players";
                                try {
                                    switch (type) {
                                        case "xp":
                                            // SANS lastTaskWhen : un cadeau, pas une victoire. Chez soi, la
                                            // célébration « cadeau d'XP » est tue (le message l'a déjà dit) ;
                                            // chez l'autre, elle joue par la vigilance de son propre doc.
                                            await _creditXp(clanId, clanSecret, region, target, value);
                                            if (target == _userId) await _quietGiftCelebration();
                                            break;
                                        case "damage":
                                            // Revérifié à l'application : entre le tirage et le clic, le joueur a
                                            // pu perdre un PV de plus avec le temps.
                                            final doc = await _cloud?.read("workers", coll, target,
                                                ownerId: clanSecret, region: region) ?? Dvidle({});
                                            final maxPv  = int.tryParse(doc.get("pv")?.toString() ?? "$_playerPv") ?? _playerPv;
                                            final damage = int.tryParse(doc.get("damage")?.toString() ?? "0") ?? 0;
                                            final pvNow  = _computeDisplayedPv(maxPv, damage,
                                                doc.get("last_task")?.toString() ?? "", _readDecay(doc.get("decay")));
                                            if (damage.abs() > 0 || pvNow - value < 1) {
                                                deva_log("info", "[events] dégât écarté ($target : $pvNow PV, damage=$damage)");
                                                break;
                                            }
                                            final out = Dvidle({});
                                            out.set("id", target);
                                            out.set("damage", value);
                                            await _cloud?.write("workers", coll, target, out, region: region, ownerId: clanSecret);
                                            break;
                                        case "heal":
                                            // Le piège d'abord : soigner efface la blessure avant de remonter le
                                            // temps (_healPlayer, qui ne touche jamais `damage`).
                                            final doc = await _cloud?.read("workers", coll, target,
                                                ownerId: clanSecret, region: region) ?? Dvidle({});
                                            final damage = (int.tryParse(doc.get("damage")?.toString() ?? "0") ?? 0).abs();
                                            final cured  = damage < value ? damage : value;
                                            if (cured > 0) {
                                                final out = Dvidle({});
                                                out.set("id", target);
                                                out.set("damage", damage - cured);
                                                await _cloud?.write("workers", coll, target, out, region: region, ownerId: clanSecret);
                                            }
                                            if (value - cured > 0) {
                                                await _healPlayer(clanId, clanSecret, region, target, value - cured);
                                            }
                                            break;
                                        case "item":
                                            // Identifiant déterministe : un rejeu réécrit le même objet au
                                            // lieu d'en créer un second.
                                            final itemType = e["item"]?.toString() ?? "";
                                            if (itemType.isEmpty) break;
                                            await _writeButinDoc(clanId, clanSecret, region,
                                                "evt_${instance}_$key", itemType, target, 1);
                                            break;
                                        default:
                                            deva_log("warning", "[events] type d'effet inconnu '$type'");
                                    }
                                } catch (err) {
                                    deva_log("error", "[events] effet $type → $target FAILED: $err");
                                }
    }

    // Au lancement : un plan inscrit mais pas effacé est repris là où il s'était arrêté. Ni journal
    // ni notification : ils ont pu partir, et un doublon vaut moins qu'un silence.
    Future<void> _evtReplayPending(String clanId, String clanSecret, String region) async {

                                if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return;
                                try {
                                    final me = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region);
                                    final pending = me?.get("events.pending");
                                    if (pending is! Dvidle) return;
                                    final planRaw = pending.get("plan");
                                    final doneRaw = pending.get("done");
                                    final plan = <String, dynamic>{};
                                    if (planRaw is Dvidle) {
                                        for (final k in planRaw.keys) {
                                            final p = planRaw.get(k.toString());
                                            if (p is! Dvidle) continue;
                                            plan[k.toString()] = {
                                                "type":   p.get("type")?.toString()   ?? "",
                                                "target": p.get("target")?.toString() ?? "",
                                                "value":  p.get("value"),
                                                "item":   p.get("item")?.toString()   ?? "",
                                            };
                                        }
                                    }
                                    final done = <String, dynamic>{};
                                    if (doneRaw is Dvidle) {
                                        for (final k in doneRaw.keys) { done[k.toString()] = doneRaw.get(k.toString()); }
                                    }
                                    deva_log("info", "[events] reprise du plan ${pending.get("instance")} (${plan.length} effet(s))");
                                    await _evtApplyPlan(clanId, clanSecret, region,
                                        pending.get("instance")?.toString() ?? "", plan, done);
                                } catch (e) {
                                    deva_log("warning", "[events] reprise impossible : $e");
                                }
    }

    // La tâche validée efface le piège (règle 2). Pour les chemins sans XP : ceux qui en créditent
    // passent par _creditXp, qui le fait dans la même écriture que l'XP.
    Future<void> _clearEventDamage(String clanId, String clanSecret, String region, String player) async {

                                if (clanId.isEmpty || clanSecret.isEmpty || player.isEmpty) return;
                                try {
                                    final out = Dvidle({});
                                    out.set("id", player);
                                    out.set("damage", 0);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", player, out,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("warning", "[events] damage non effacé pour $player : $e");
                                }
    }

    // -----------------------------------------------------------------------
    // --- Mise en scène « message »
    // -----------------------------------------------------------------------

    Future<void> _evtShowMessage(Map<String, dynamic> ev, String textKey) async {

                                if (await DvOrb.wait_for_shape("commons/evt_ok") == null) return;
                                final img = DvOrb.get_shape_by_id("commons/evt_image");
                                final image = ev["image"]?.toString() ?? "";
                                if (img != null && image.isNotEmpty) {
                                    img.set("shape.image", image);
                                    try { await img.appear(); } catch (e) { deva_log("warning", "[events] image : $e"); }
                                }
                                final t = DvOrb.get_shape_by_id("commons/evt_text");
                                if (t is DvLabel) {
                                    final text = (await _fairyTr(textKey))
                                        .replaceAll("{name}", ev["imitated_name"]?.toString() ?? "");
                                    t.set("shape.label", text);
                                    await t.computeDisplay();
                                }
                                for (final id in _kEvtMessageShapes) {
                                    DvOrb.get_shape_by_id(id)?.show();
                                }
    }

    // OK : referme, puis applique ce qui attendait le clic (mise en scène `message`).
    Future<void> on_event_ok(dynamic caller, dynamic event) async {

                                for (final id in _kEvtMessageShapes) {
                                    DvOrb.get_shape_by_id(id)?.hide();
                                }
                                final ev = _evtOnOk;
                                _evtOnOk = null;
                                if (ev != null) await _evtResolve(ev, clicked: true);
    }

    // -----------------------------------------------------------------------
    // --- Mises en scène du roster (gobelin, changelin)
    // -----------------------------------------------------------------------

    // Appelé par _refreshRoster juste avant de pousser la liste : ajoute l'intrus (ou le double).
    // Le double est FIGÉ à la première injection (même détail faux à chaque rafraîchissement).
    void _evtInjectRoster(List<Map<String, dynamic>> members) {

                                final ev = _evtActive;
                                if (ev == null) return;
                                final scene = ev["scene"]?.toString() ?? "";
                                final fakeId = "$_kEvtFakePrefix${ev["instance"]}";

                                if (scene == "fake_member") {
                                    members.add({
                                        "id":     fakeId,
                                        "name":   ev["name_text"]?.toString() ?? "",
                                        "avatar": ev["image"]?.toString() ?? "",
                                        "level":  1,
                                        "pv":     0,
                                        "dead":   false,
                                        "dimmed": false,
                                        "hide":   "level,pv,progress,wallet",
                                        "admin":  false,
                                        "progress": 0.0,
                                    });
                                    return;
                                }

                                if (scene == "double_member") {
                                    var fake = ev["fake"] as Map<String, dynamic>?;
                                    if (fake == null) {
                                        // Un membre au hasard, jamais soi-même ni un intrus, et dont au moins
                                        // un chiffre est lisible (un hors-concours n'en montre aucun).
                                        final pool = members.where((m) {
                                            final id = m["id"]?.toString() ?? "";
                                            return id.isNotEmpty && id != _userId && !id.startsWith(_kEvtFakePrefix)
                                                && m["hors_concours"] != true && m["consent_pending"] != true;
                                        }).toList();
                                        if (pool.isEmpty) { _evtActive = null; return; }
                                        final real = pool[Random().nextInt(pool.length)];
                                        fake = Map<String, dynamic>.from(real);
                                        fake["id"] = fakeId;
                                        // LE DÉTAIL QUI TRAHIT : le niveau ou les PV, décalés d'un cran.
                                        final lvl = int.tryParse(real["level"]?.toString() ?? "1") ?? 1;
                                        final pv  = int.tryParse(real["pv"]?.toString() ?? "0") ?? 0;
                                        if (Random().nextBool() || pv <= 0) {
                                            fake["level"] = lvl <= 1 ? lvl + 1 : lvl + (Random().nextBool() ? 1 : -1);
                                        } else {
                                            fake["pv"] = pv >= _playerPv ? pv - 1 : pv + 1;
                                        }
                                        ev["fake"]          = fake;
                                        ev["imitated"]      = real["id"]?.toString() ?? "";
                                        ev["imitated_name"] = real["name"]?.toString() ?? "";
                                    }
                                    // Le vrai a pu quitter la liste entre deux rafraîchissements.
                                    if (!members.any((m) => m["id"] == ev["imitated"])) { _evtActive = null; return; }
                                    members.add(Map<String, dynamic>.from(fake));
                                }
    }

    // clan_selector : pendant un événement de roster, l'intrus (et, pour un changelin, le vrai
    // membre) ne proposent QUE « Chasser », à tout le monde. Null = pas concerné.
    Map<String, dynamic>? _evtRosterSelector(dynamic data) {

                                final ev = _evtActive;
                                if (ev == null) return null;
                                final m  = (data is Map) ? data : const {};
                                final id = m["id"]?.toString() ?? "";
                                final fakeId = "$_kEvtFakePrefix${ev["instance"]}";
                                final chase = <String, dynamic>{"selectable": ["evt_chase"], "disabled": [], "single": ""};
                                if (id == fakeId) return chase;
                                if (ev["scene"] == "double_member" && id.isNotEmpty && id == ev["imitated"]) return chase;
                                return null;
    }

    // « Chasser » : sur l'intrus, les effets ; sur le vrai membre (changelin), il s'enfuit, rien
    // d'autre. Aucune issue n'est une sanction.
    Future<void> on_event_chase(dynamic caller, dynamic event) async {

                                final ev = _evtActive;
                                if (ev == null) return;
                                final m  = (event is Map) ? event : const {};
                                final id = m["id"]?.toString() ?? "";
                                final caught = id == "$_kEvtFakePrefix${ev["instance"]}";
                                _evtActive = null;

                                final ctx = await _butinCtx();
                                if (ctx != null) {
                                    await _refreshRoster(ctx.get("clanId").toString(),
                                        ctx.get("clanSecret").toString(), ctx.get("region").toString());
                                }
                                if (caught) {
                                    await _evtShowMessage(ev, ev["text"]?.toString() ?? "");
                                    await _evtResolve(ev, clicked: true);
                                } else {
                                    final miss = ev["text_miss"]?.toString() ?? "";
                                    await _evtShowMessage(ev, miss.isNotEmpty ? miss : (ev["text"]?.toString() ?? ""));
                                }
    }

    // Avant chaque passage sur l'écran du clan : l'intrus de la visite précédente est parti.
    // Puis, s'il en sort un nouveau (un tirage par jour), on redessine la liste.
    Future<void> _evtClanScreen(String clanId, String clanSecret, String region) async {

                                if (await _evtAt("clan_screen", waitIdle: false)) {
                                    final ev = _evtActive;
                                    if (ev != null && ev["scene"] == "fake_member") {
                                        ev["name_text"] = await _fairyTr(ev["name"]?.toString() ?? "");
                                    }
                                    await _refreshRoster(clanId, clanSecret, region);
                                }
    }

    // -----------------------------------------------------------------------
    // --- Objets consommables
    // -----------------------------------------------------------------------

    // « Utiliser » : applique le `use` du TYPE de l'objet (items-base-global.yml), puis le supprime.
    // Seul son propriétaire peut l'utiliser.
    Future<void> item_use(dynamic caller, dynamic event) async {

                                final data   = (event is Map) ? event : const {};
                                final itemId = data["id"]?.toString()    ?? "";
                                final owner  = data["owner"]?.toString() ?? "";
                                final type   = data["type"]?.toString()  ?? "";
                                if (itemId.isEmpty || type.isEmpty || owner != _userId) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();

                                final useType = (await deva_get("items.$type.use.type"))?.toString() ?? "";
                                final useVal  = int.tryParse((await deva_get("items.$type.use.value"))?.toString() ?? "0") ?? 0;
                                if (useType.isEmpty) return;
                                try {
                                    // L'objet d'abord : un double tap ne boit pas deux fois la même fiole.
                                    await _cloud?.delete("workers", "clans_items/$clanId/items", itemId,
                                        region: region, ownerId: clanSecret);
                                    if (_removeLocalItem(itemId)) {
                                        _pushClanItems();
                                    } else {
                                        await _loadClanItems(clanId, clanSecret, region);
                                    }
                                    await _evtApplyEffect(clanId, clanSecret, region, itemId, "use", {
                                        "type": useType, "target": _userId,
                                        "value": await _evtClamp(useType, useVal),
                                    });
                                    deva_log("info", "[items] '$itemId' utilisé ($useType $useVal)");
                                } catch (e) {
                                    deva_log("error", "[items] item_use FAILED: $e");
                                }
    }
}

// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
