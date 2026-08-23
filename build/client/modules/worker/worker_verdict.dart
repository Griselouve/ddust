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
// --- worker extension — Verdicts de validation
// -----------------------------------------------------------------------------
extension Worker_verdict on worker {

    void _register_verdict() {

                                ActionRegistry.register("worker.on_validate_ok",            on_validate_ok);

                                ActionRegistry.register("worker.on_validate_partial",       on_validate_partial);

                                ActionRegistry.register("worker.on_validate_ko",            on_validate_ko);

                                ActionRegistry.register("worker.on_validation_resolved",    on_validation_resolved);

                                // Verdicts déclenchés depuis la notification admin (boutons de la notif).
                                ActionRegistry.register("worker.on_notif_validate_ok",      on_notif_validate_ok);

                                ActionRegistry.register("worker.on_notif_validate_partial", on_notif_validate_partial);

                                ActionRegistry.register("worker.on_notif_validate_ko",      on_notif_validate_ko);

                                // Tap sur le CORPS de la notification de validation, version sans
                                // boutons — celle qu'un clan sans cotisation reçoit. Ouvre l'app sur
                                // la tâche à valider au lieu de rendre un verdict en sous-main.
                                ActionRegistry.register("worker.on_notif_open_task",        on_notif_open_task);

    }

    // Tâche → "validating" : preuve déposée (read-modify-write, ownerId du doc = clanSecret).
    // Comme _assignTask, write() est un PATCH sans updateMask → on reconstruit tout le doc.
    Future<void> _validateTask(String clanId, String clanSecret, String taskId, String proof, String region) async {

                                final coll       = "clans_tasks/$clanId/tasks";
                                final last       = DateTime.now().toUtc().toIso8601String();
                                final enabledRaw = await deva_get("tasks.$taskId.enabled");
                                final enabled    = enabledRaw == null ? true : (enabledRaw == true || enabledRaw.toString() == "true");
                                // PATCH = remplacement complet → préserver dead/revive : un verdict de refus
                                // repasse la tâche en "assigned" et ne les réécrit pas (bug XP remis à plein).
                                final dead       = (await deva_get("tasks.$taskId.dead"))?.toString()   ?? "";
                                final revive     = (await deva_get("tasks.$taskId.revive"))?.toString() ?? "";

                                final doc = Dvidle({});
                                doc.set("ownerId",  clanSecret);
                                doc.set("clanId",   clanId);
                                doc.set("enabled",  enabled);
                                doc.set("assignee", _userId);
                                doc.set("last",     last);
                                doc.set("status",   "validating");
                                doc.set("proof",    proof);
                                if (dead.isNotEmpty)   doc.set("dead",   dead);
                                if (revive.isNotEmpty) doc.set("revive", revive);
                                await _applyIdentityFields(doc, taskId);   // préserve domain + champs de clone
                                await _cloud?.write("workers", coll, taskId, doc, region: region, ownerId: clanSecret);

                                // Le joueur vient de finir sa tâche et de l'envoyer en validation → last_task.
                                await _touchLastTask(clanId, clanSecret, region, _userId, last);

                                // Miroir local (cohérent avec _loadClanTasks).
                                await deva_set("tasks.$taskId.assignee", _userId);
                                await deva_set("tasks.$taskId.status",   "validating");
                                await deva_set("tasks.$taskId.last",     last);
                                await deva_set("tasks.$taskId.proof",    proof);
                                deva_log("info", "[combat] tâche en validation: $taskId (proof=$proof)");
    }

    // Tâche → "alive" : libération (assignee vide, proof retiré). Le PATCH sans updateMask
    // remplace le doc complet → ne pas réécrire "proof" suffit à le supprimer.
    Future<void> _releaseTask(String clanId, String clanSecret, String taskId, String region) async {

                                final coll       = "clans_tasks/$clanId/tasks";
                                final last       = DateTime.now().toUtc().toIso8601String();
                                final enabledRaw = await deva_get("tasks.$taskId.enabled");
                                final enabled    = enabledRaw == null ? true : (enabledRaw == true || enabledRaw.toString() == "true");
                                // PATCH = remplacement complet → préserver dead/revive : une retraite ne doit
                                // PAS réinitialiser la régénération (bug XP immortelle remis à plein).
                                final dead       = (await deva_get("tasks.$taskId.dead"))?.toString()   ?? "";
                                final revive     = (await deva_get("tasks.$taskId.revive"))?.toString() ?? "";

                                final doc = Dvidle({});
                                doc.set("ownerId",  clanSecret);
                                doc.set("clanId",   clanId);
                                doc.set("enabled",  enabled);
                                doc.set("assignee", "");
                                doc.set("last",     last);
                                doc.set("status",   "alive");
                                doc.set("proof",    "");                   // merge : vider explicitement (plus supprimé par le PATCH)
                                if (dead.isNotEmpty)   doc.set("dead",   dead);
                                if (revive.isNotEmpty) doc.set("revive", revive);
                                await _applyIdentityFields(doc, taskId);   // préserve domain + champs de clone
                                await _cloud?.write("workers", coll, taskId, doc, region: region, ownerId: clanSecret);

                                // Miroir local. dead/revive laissés intacts.
                                await deva_set("tasks.$taskId.assignee", "");
                                await deva_set("tasks.$taskId.status",   "alive");
                                await deva_set("tasks.$taskId.last",     last);
                                await deva_set("tasks.$taskId.proof",    "");
                                deva_log("info", "[combat] tâche libérée: $taskId");
    }

    // Écrit le verdict dans clans_tasks (PATCH doc complet → reconstruire tous les champs).
    // accept=true, partial=false → tâche libérée : assignee="", last=now, dead=now,
    //                revive=now+respawn_h h, status = "dead" (mortelle) | "alive" (immortelle).
    // accept=true, partial=true  → acceptation PARTIELLE : tâche à moitié régénérée
    //                (dead=now−respawn/2, revive=now+respawn/2) et TOUJOURS "alive" (même mortelle).
    // accept=false → status="assigned", assignee inchangé (le joueur), last=now (preuve retirée).
    // Une acceptation (partielle comprise) efface AUSSI `recommended` : le bonus « boss » a été
    // tiré et crédité, la tâche cesse d'en être un. Un REFUS le conserve — le joueur retente en
    // gardant le bonus.
    Future<void> _writeVerdict(String clanId, String clanSecret, String taskId,
                               String region, bool accept, bool partial, String assignee) async {

                final coll       = "clans_tasks/$clanId/tasks";
                final now        = DateTime.now().toUtc().toIso8601String();
                final enabledRaw = await deva_get("tasks.$taskId.enabled");
                final enabled    = enabledRaw == null ? true : (enabledRaw == true || enabledRaw.toString() == "true");

                final doc = Dvidle({});
                doc.set("ownerId",  clanSecret);
                doc.set("clanId",   clanId);
                doc.set("enabled",  enabled);
                doc.set("last",     now);

                if (accept) {
                    // type/respawn_h proviennent de la couche tasks-base (fusionnée dans tasks.<id>).
                    final type     = (await deva_get("tasks.$taskId.type"))?.toString() ?? "immortelle";
                    final respawnH = int.tryParse((await deva_get("tasks.$taskId.respawn_h"))?.toString() ?? "0") ?? 0;

                    final String st, deadV, reviveV;
                    if (partial) {
                        // Acceptation partielle : tâche à moitié régénérée, JAMAIS "dead" (même
                        // mortelle) → elle reste sélectionnable, barre de respawn à ~50 %.
                        final halfMin = respawnH * 30;   // moitié de respawn_h en minutes (gère les heures impaires)
                        deadV   = DateTime.now().toUtc().subtract(Duration(minutes: halfMin)).toIso8601String();
                        reviveV = DateTime.now().toUtc().add(Duration(minutes: halfMin)).toIso8601String();
                        st      = "alive";
                    } else {
                        deadV   = now;
                        reviveV = DateTime.now().toUtc().add(Duration(hours: respawnH)).toIso8601String();
                        st      = type == "mortelle" ? "dead" : "alive";
                    }

                    doc.set("assignee", "");
                    doc.set("status",   st);
                    doc.set("dead",     deadV);
                    doc.set("revive",   reviveV);
                    doc.set("proof",    "");                   // merge : vider explicitement (plus supprimé par le PATCH)
                    // Verdict accepté (partiel compris) = la recommandation « boss » est CONSOMMÉE :
                    // le bonus a été tiré et crédité juste avant, la tâche n'est plus un boss. On
                    // l'efface ICI, dans la même écriture que le verdict et sur l'appareil qui
                    // tranche — c'est le seul moment où l'on est sûr que ça arrive. (Auparavant
                    // l'effacement n'était fait que par l'appareil du joueur récompensé, après son
                    // animation : joueur hors ligne, ou tâche à 0 XP — donc sans last_task_boss —
                    // et le badge XP restait collé pour tout le clan.)
                    await _applyIdentityFields(doc, taskId, clearRecommended: true);
                    await _cloud?.write("workers", coll, taskId, doc, region: region, ownerId: clanSecret);

                    await deva_set("tasks.$taskId.assignee",    "");
                    await deva_set("tasks.$taskId.status",      st);
                    await deva_set("tasks.$taskId.last",        now);
                    await deva_set("tasks.$taskId.dead",        deadV);
                    await deva_set("tasks.$taskId.revive",      reviveV);
                    await deva_set("tasks.$taskId.proof",       "");
                    await deva_set("tasks.$taskId.recommended", "");
                    deva_log("info", "[combat] verdict ${partial ? 'PARTIEL' : 'ACCEPTÉ'}: $taskId type=$type status=$st dead=$deadV revive=$reviveV");
                } else {
                    // Refus : la tâche repasse "assigned". PATCH = remplacement complet → préserver
                    // la fenêtre de régénération (dead/revive) si elle existe (bug XP remis à plein).
                    final dRaw = (await deva_get("tasks.$taskId.dead"))?.toString()   ?? "";
                    final rRaw = (await deva_get("tasks.$taskId.revive"))?.toString() ?? "";
                    doc.set("assignee", assignee);
                    doc.set("status",   "assigned");
                    doc.set("proof",    "");                   // merge : vider explicitement (plus supprimé par le PATCH)
                    if (dRaw.isNotEmpty) doc.set("dead",   dRaw);
                    if (rRaw.isNotEmpty) doc.set("revive", rRaw);
                    await _applyIdentityFields(doc, taskId);   // préserve domain + champs de clone
                    await _cloud?.write("workers", coll, taskId, doc, region: region, ownerId: clanSecret);

                    await deva_set("tasks.$taskId.assignee", assignee);
                    await deva_set("tasks.$taskId.status",   "assigned");
                    await deva_set("tasks.$taskId.last",     now);
                    await deva_set("tasks.$taskId.proof",    "");
                    deva_log("info", "[combat] verdict REFUSÉ: $taskId → assigned ($assignee)");
                }
    }

    // Crédite l'XP gagné à l'assignee : lecture/écriture ciblée sur SON doc membre
    // (clans_players/{clanId}/players/{assignee}) → pas de contention sur le doc clan.
    // Incrémente `xp`. Le niveau n'est pas stocké : il se dérive de l'xp via getNiveauProgres().
    // `lastTaskWhen` (optionnel) : quand fourni, réécrit AUSSI last_task dans la MÊME écriture que
    // l'xp. Indispensable pour l'XP de tâche accomplie/validée : sans ça, l'xp arrive au joueur à
    // last_task inchangé et _checkPlayerLevelUp la prendrait pour un CADEAU. En une seule écriture, le
    // watch joueur voit xp+ ET last_task changé de façon atomique (pas de course sur le temps réel).
    // Le vrai cadeau (support_player) N'en passe PAS → last_task intact → toujours vu comme cadeau.
    //
    // RETOURNE l'XP RÉELLEMENT créditée, une fois écrêtée au plafond du joueur (`max_xp` +
    // 20×niveau — cf. _capForLevel). C'est ce goulot — et lui seul — qui applique le plafond : il a
    // déjà le doc du joueur en main, donc son plafond ET son xp cumulé (→ son niveau), sans lecture
    // supplémentaire. Les appelants DOIVENT se servir de la valeur renvoyée pour la part du clan et
    // pour le journal, sinon le clan toucherait sa fraction d'un gain que le joueur n'a pas eu et le
    // journal annoncerait une XP jamais versée.
    // Le plafond porte sur le GAIN d'une tâche, jamais sur le cumul : `xp` continue de croître, donc
    // la garde `xp <= storedXp` de _checkPlayerLevelUp n'est pas concernée.
    Future<int> _creditXp(String clanId, String clanSecret, String region,
                          String assignee, int xp, {String? lastTaskWhen, String bossTaskId = ""}) async {

                if (clanId.isEmpty || clanSecret.isEmpty || assignee.isEmpty || xp <= 0) return 0;
                try {
                    final doc = await _cloud?.read(
                        "workers", "clans_players/$clanId/players", assignee,
                        ownerId: clanSecret, region: region) ?? Dvidle({});
                    final current = int.tryParse(doc.get("xp")?.toString() ?? "0") ?? 0;
                    // Plafond PORTÉ PAR LE JOUEUR, relu à chaque crédit → une modification en cours
                    // de partie prend effet sans relancer l'app. Champ absent (doc antérieur au
                    // champ) → repli sur la conf ; plafond nul ou négatif → ignoré (garde-fou : un
                    // réglage aberrant ne doit pas annuler tous les gains du jeu). +20×niveau — niveau
                    // dérivé de `current`, donc AVANT le gain de cette tâche.
                    final baseCap = int.tryParse(doc.get("max_xp")?.toString() ?? "") ?? _playerMaxXp;
                    final niveau  = getNiveauProgres(current).niveau;
                    final cap     = _capForLevel(baseCap, niveau, _playerMaxXpPerLevel);
                    final granted = (cap > 0 && xp > cap) ? cap : xp;
                    doc.set("id", assignee);                     // garantir l'id si doc fraîchement créé
                    doc.set("xp", current + granted);
                    if (lastTaskWhen != null && lastTaskWhen.isNotEmpty) {
                        doc.set("last_task", lastTaskWhen);
                        // Drapeau « boss » posé ATOMIQUEMENT avec xp+last_task (même écriture) → le watch
                        // joueur (_checkPlayerLevelUp) lit un snapshot cohérent, sans course : id de tâche
                        // recommandée → anim « coup de pouce » + nettoyage ; "" → validation normale (victoire).
                        doc.set("last_task_boss", bossTaskId);
                    }
                    await _cloud?.write(
                        "workers", "clans_players/$clanId/players", assignee, doc,
                        region: region, ownerId: clanSecret);
                    if (granted < xp) {
                        deva_log("info", "[combat] XP écrêtée : $xp → $granted (plafond $cap = $baseCap+$_playerMaxXpPerLevel×Nv.$niveau) pour $assignee");
                    }
                    deva_log("info", "[combat] +$granted XP → $assignee (total ${current + granted})");
                    return granted;
                } catch (e) {
                    deva_log("error", "[combat] _creditXp FAILED: $e");
                    // Le doc du joueur n'a pas pu être lu : on ne connaît ni SON plafond ni SON
                    // niveau (dérivé de son xp cumulé). On rend quand même une valeur (la part du
                    // clan et le journal partaient déjà quand ce crédit échouait — ce comportement
                    // ne change pas), mais écrêtée au plafond NU de la conf (sans bonus de niveau,
                    // impossible à connaître ici) : la meilleure information disponible, et jamais
                    // un gain nu.
                    return (_playerMaxXp > 0 && xp > _playerMaxXp) ? _playerMaxXp : xp;
                }
    }

    // Fourchette d'XP JOUEUR d'une tâche « boss » : le coefficient est
    // max((3 + rand(0..4)) / (1 + heures), 1), où `heures` = temps écoulé depuis la recommandation.
    // Le tirage porte sur 3..7, donc les bornes sont connues À L'AVANCE — c'est ce qui permet de les
    // AFFICHER avant le combat (_taskDifficultyRange) tout en gardant le tirage au verdict.
    // Plus on tarde, plus la fourchette se resserre vers l'XP de base ; borné à 1 → jamais moins.
    // Non recommandée / date invalide → (base, base). Le tirage sert aussi au CLAN : sa part est
    // calculée sur l'XP boostée, pas sur l'XP de base (cf. _creditClanXp).
    (int, int) _bossXpRange(int baseXp, String recommended) {

                    if (baseXp <= 0 || recommended.isEmpty) return (baseXp, baseXp);
                    final recAt = DateTime.tryParse(recommended)?.toUtc();
                    if (recAt == null) return (baseXp, baseXp);
                    // Plancher à 0 : une date de recommandation dans le FUTUR (horloge décalée entre
                    // deux appareils) donnerait un écoulement négatif, donc un diviseur nul ou négatif
                    // — et `1 / 0` vaut Infinity, que .round() refuse de convertir. Une recommandation
                    // du futur est simplement traitée comme toute fraîche.
                    final raw   = DateTime.now().toUtc().difference(recAt).inMilliseconds / 3600000.0;
                    final hours = raw < 0 ? 0.0 : raw;
                    final lo = (baseXp * max(3 / (1 + hours), 1.0)).round();
                    final hi = (baseXp * max(7 / (1 + hours), 1.0)).round();
                    return (lo, hi);
    }

    // Tirage effectif du bonus, au moment du verdict : un entier de la fourchette ci-dessus. Passer
    // par _bossXpRange (et non par un second calcul du coefficient) garantit que ce qui est crédité
    // tombe bien dans ce que le badge de combat avait promis.
    int _bossPlayerXp(int baseXp, String recommended, {String taskId = ""}) {

                    final (lo, hi) = _bossXpRange(baseXp, recommended);
                    if (hi <= lo) return baseXp;
                    final pXp = lo + Random().nextInt(hi - lo + 1);
                    deva_log("info", "[boss] $taskId : xp $baseXp → $pXp (fourchette $lo-$hi)");
                    return pXp;
    }

    // Consomme le DRAPEAU « boss » côté JOUEUR, une fois l'XP reçue et l'animation « coup de pouce »
    // jouée : remet last_task_boss="" sur son propre doc (sans quoi l'animation rejouerait à la
    // prochaine hausse d'XP), puis rafraîchit ses tiroirs pour que le badge XP tombe chez lui aussi.
    // `recommended` N'EST PLUS effacé ici : c'est le verdict qui le fait (_writeVerdict), dans la
    // même écriture, sur l'appareil de l'admin. Passer par le joueur était fragile — il fallait
    // qu'il ouvre l'app, et qu'il ait touché de l'XP (une tâche à 0 XP ne pose pas last_task_boss),
    // sinon la tâche restait « recommandée » pour tout le clan.
    Future<void> _consumeBossReward(String clanId, String clanSecret, String region, String boss) async {

                    if (clanId.isEmpty || clanSecret.isEmpty || boss.isEmpty) return;
                    try {
                        final pd = Dvidle({});
                        pd.set("id",             _userId);
                        pd.set("last_task_boss", "");
                        await _cloud?.write("workers", "clans_players/$clanId/players", _userId, pd,
                            region: region, ownerId: clanSecret);
                    } catch (e) {
                        deva_log("error", "[boss] effacement last_task_boss FAILED: $e");
                    }
                    // Le badge XP disparaît au prochain rebuild des tiroirs (recommended vide en base).
                    try { await _refreshTaskStatuses(force: true); } catch (_) {}
                    deva_log("info", "[boss] récompense consommée : drapeau joueur effacé ($boss)");
    }

    // Rafraîchit `last_task` (date où le joueur a « joué ») sur SON doc membre
    // clans_players/{clanId}/players/{player}. Écriture ciblée en deep-merge dvcloud →
    // xp/pv/devices/last_task-de-création préservés. Deux moments comptent comme avoir joué :
    // le « finish » du joueur (tâche envoyée en validation) ET le verdict rendu par un admin sur
    // la tâche d'un tiers (arbitrer est une contribution, cf. _applyVerdict).
    Future<void> _touchLastTask(String clanId, String clanSecret, String region,
                                String player, String when) async {
                if (clanId.isEmpty || clanSecret.isEmpty || player.isEmpty) return;
                try {
                    final doc = Dvidle({});
                    doc.set("id", player);              // garantir l'id si le merge crée le doc
                    doc.set("last_task", when);
                    await _cloud?.write(
                        "workers", "clans_players/$clanId/players", player, doc,
                        region: region, ownerId: clanSecret);
                } catch (e) {
                    deva_log("error", "[combat] _touchLastTask FAILED: $e");
                }
    }

    // Récompense de montée de niveau sur le doc joueur : rafraîchit `last_task` à maintenant ET
    // remet `damage` à 0 → _computeDisplayedPv repart de `pv` plein (soin complet). Écriture ciblée
    // deep-merge dvcloud (xp/pv/decay/devices préservés). Miroir de _touchLastTask, +damage.
    Future<void> _rewardPlayerOnLevelUp(String clanId, String clanSecret, String region,
                                        String player) async {
                if (clanId.isEmpty || clanSecret.isEmpty || player.isEmpty) return;
                try {
                    final doc = Dvidle({});
                    doc.set("id", player);              // garantir l'id si le merge crée le doc
                    doc.set("last_task", DateTime.now().toUtc().toIso8601String());
                    doc.set("damage", 0);
                    await _cloud?.write(
                        "workers", "clans_players/$clanId/players", player, doc,
                        region: region, ownerId: clanSecret);
                    deva_log("info", "[levelup] soin niveau → $player (last_task=now, damage=0)");
                } catch (e) {
                    deva_log("error", "[levelup] _rewardPlayerOnLevelUp FAILED: $e");
                }
    }

    // Crédite un MONTANT FIXE au butin du clan (champ butin_xp de clans/{clanId}), le cycle courant
    // plafonné à _butinMaxXp (cf. _butinPlafonne). Contrairement à _creditClanButin (proportionnel à
    // l'XP-clan via le facteur du clan `butin_xp_factor`), le montant est passé tel quel et N'EST PAS
    // soumis à ce facteur — ici 10 × niveau à la montée de niveau. Il reste en revanche soumis au
    // MÊME plafond de gain (+20×niveau du clan) que _creditClanButin : sans lui, ce don rouvrirait
    // exactement le déséquilibre corrigé (10×niveau dépasse 70 dès le niveau 7). Read-modify-write
    // dédié — ne mute pas `xp`, donc le niveau se dérive directement du doc lu.
    Future<void> _creditClanButinFixed(String clanId, String clanSecret, String region, int amount) async {

                                if (clanId.isEmpty || clanSecret.isEmpty || amount <= 0) return;
                                try {
                                    final doc = await _cloud?.read(
                                        "workers", "clans", clanId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    if (_butinCourant(doc) >= _butinMaxXp) return;        // coffre du cycle déjà plein
                                    final clanXp  = int.tryParse(doc.get("xp")?.toString() ?? "0") ?? 0;
                                    final niveau  = getClanNiveauProgres(clanXp).niveau;
                                    final baseCap = int.tryParse(doc.get("max_xp_butin")?.toString() ?? "")
                                                    ?? _butinGainMaxXp;
                                    final cap     = _capForLevel(baseCap, niveau, _butinGainMaxXpPerLevel);
                                    final granted = (cap > 0 && amount > cap) ? cap : amount;
                                    doc.set("butin_xp", _butinPlafonne(doc, granted));
                                    await _cloud?.write(
                                        "workers", "clans", clanId, doc,
                                        region: region, ownerId: clanSecret);
                                    deva_log("info", "[levelup] +$granted butin → clan "
                                        "(cycle ${_butinCourant(doc)}/$_butinMaxXp, cumul ${_butinCumul(doc)}, "
                                        "plafond gain $cap Nv.$niveau)");
                                } catch (e) {
                                    deva_log("error", "[levelup] _creditClanButinFixed FAILED: $e");
                                }
    }

    // Crédite l'XP gagné au CLAN — miroir de _creditXp, mais sur le doc clan
    // (workers/clans/{clanId}.xp), cumulatif et global. Le crédit s'exécute toujours côté
    // admin validateur (auto-validation ou verdict accepté) → pas de contention pratique.
    // L'XP passée est celle RÉELLEMENT gagnée par le joueur — bonus « boss » d'une tâche recommandée
    // COMPRIS : le clan reçoit toujours une fraction de ce que le joueur a touché, jamais une base
    // amputée. Elle est divisée par le nombre de membres du clan (arrondi au SUPÉRIEUR) : ainsi un
    // clan plus nombreux progresse moins vite par tâche, le niveau récompense l'effort collectif et
    // non la simple taille. Le niveau n'est pas stocké : dérivé via getClanNiveauProgres().
    Future<void> _creditClanXp(String clanId, String clanSecret, String region, int xp) async {

                                if (clanId.isEmpty || clanSecret.isEmpty || xp <= 0) return;
                                try {
                                    // Nombre de joueurs = docs de clans_players/{clanId}/players (repli à 1 si vide/échec).
                                    // Les membres révoqués (enabled=false) ET les hors-device (has_device=false) ne
                                    // comptent pas dans le partage d'XP (donc ni dans le butin, dérivé du même share).
                                    final players = (await _cloud?.list(
                                        "workers", "clans_players/$clanId/players", region: region) ?? [])
                                        .where((p) => p.get("enabled") != false && p.get("has_device") != false).toList();
                                    final count = players.isEmpty ? 1 : players.length;
                                    final share = (xp / count).ceil();          // XP par tâche / nb joueurs, arrondi supérieur

                                    final doc = await _cloud?.read(
                                        "workers", "clans", clanId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    final current = int.tryParse(doc.get("xp")?.toString() ?? "0") ?? 0;
                                    // Niveau du clan AVANT ce gain — c'est lui qui plafonne le crédit de butin
                                    // ci-dessous. Dérivé sur `current`, PAS relu sur le doc après le set("xp", …)
                                    // suivant, qui donnerait le niveau D'APRÈS.
                                    final clanNiveau = getClanNiveauProgres(current).niveau;
                                    doc.set("xp", current + share);
                                    final butinBefore = _butinCourant(doc);
                                    _creditClanButin(doc, share, clanNiveau);   // crédite le butin (× facteur du clan, écrêté au plafond de gain), même doc/write
                                    final butin = _butinCourant(doc);
                                    await _cloud?.write(
                                        "workers", "clans", clanId, doc,
                                        region: region, ownerId: clanSecret);
                                    deva_log("info", "[combat] +$share XP → clan ($xp/$count joueurs, total ${current + share}, "
                                        "butin +${butin - butinBefore} → $butin/$_butinMaxXp, "
                                        "plafond gain butin Nv.$clanNiveau)");

                                    // Palier de CLAN franchi : ce code est le SEUL endroit du jeu qui voit
                                    // l'xp du clan avant ET après (le niveau de clan n'est sinon dérivé
                                    // qu'à l'affichage de l'écran Clan). Le clan gagne l'ITEM titre —
                                    // personne ne le porte tant qu'un chef ne l'a pas appliqué. Après le
                                    // write : si l'écriture d'xp échoue, le palier n'a pas été franchi.
                                    // NB : ce code tourne sur l'appareil de l'ADMIN QUI VALIDE, pas sur
                                    // celui d'un joueur — d'où l'absence d'animation ici (elle se
                                    // jouerait chez la mauvaise personne), remplacée par le journal.
                                    final oldTitle = _titleIdxFor(getClanNiveauProgres(current).niveau);
                                    final newTitle = _titleIdxFor(getClanNiveauProgres(current + share).niveau);
                                    if (newTitle >= 0 && newTitle > oldTitle) {
                                        await _grantTitleItem(clanId, clanSecret, region, newTitle, clan: true);
                                        final logData = Dvidle({});
                                        logData.set("niveau",    getClanNiveauProgres(current + share).niveau);
                                        logData.set("title_idx", newTitle);
                                        await _writeClanLog(clanId, clanSecret, region, "ClanLeveledUp",
                                            adminId: _userId, slug: clanId, data: logData);
                                    }
                                } catch (e) {
                                    deva_log("error", "[combat] _creditClanXp FAILED: $e");
                                }
    }

    // Cœur commun à tous les verdicts (boutons UI ET notification admin). Applique le verdict
    // sur <taskId> pour <assignee>, avec les identifiants clan de l'admin courant. NE navigue
    // PAS → utilisable headless (mode restreint, app relancée par la notif).
    //
    // Garde d'idempotence : ne traite que si la tâche est encore "validating". Deux admins
    // notifiés peuvent tapper : le second lira un statut différent (dead/alive/assigned) et
    // sortira sans re-créditer d'XP.
    Future<void> _applyVerdict(String verdict, String clanId, String clanSecret,
                               String region, String taskId, String assignee) async {

                    final accept  = verdict != "ko";
                    final partial = verdict == "partial";

                    if (clanId.isEmpty || clanSecret.isEmpty || taskId.isEmpty) {
                        deva_log("warning", "[combat] _applyVerdict: contexte incomplet (clan=$clanId task=$taskId)");
                        return;
                    }

                    // Lecture FRAÎCHE unique du doc : statut (garde d'idempotence) ET recommended
                    // sortent de la même lecture — c'était deux reads du même document. Ce chemin
                    // s'exécute aussi en headless (verdict depuis la notif) où le miroir local peut
                    // être vide → on ne s'y fie pas : sans cette lecture, un boss serait validé sans
                    // bonus, et le journal annoncerait l'XP de base. On réamorce ensuite le miroir
                    // local, dont _writeVerdict se sert pour préserver l'état « boss » sur un REFUS
                    // (sur une acceptation, il l'efface — la recommandation vient d'être consommée).
                    final taskDoc = await _readTaskDoc(clanId, clanSecret, region, taskId);
                    final st = taskDoc?.get("status")?.toString() ?? "";
                    if (st != "validating") {
                        deva_log("info", "[combat] _applyVerdict: $taskId non 'validating' (=$st) → ignoré (déjà tranché ?)");
                        return;
                    }
                    final rec = taskDoc?.get("recommended")?.toString() ?? "";
                    await deva_set("tasks.$taskId.recommended", rec);

                    // XP calculé AVANT _writeVerdict : la proportionnalité doit utiliser le
                    // dead/revive du cycle précédent, que la validation va réécrire.
                    var xp        = 0;   // XP de BASE de la tâche (avant bonus de recommandation)
                    var boostedXp = 0;   // XP après bonus « boss », AVANT écrêtage au plafond du joueur
                    var playerXp  = 0;   // XP RÉELLEMENT créditée → part du clan/butin ET journal
                    var bossTaskId = "";
                    if (accept) {
                        final task = await deva_get("tasks.$taskId");
                        xp = getTaskXPs(task is Dvidle ? task : null);
                        if (partial) xp = xp ~/ 2;   // moitié → se répercute sur joueur/clan/butin
                        // Tâche « boss » : XP boostée. Le bonus COMPTE dans la part du clan (le clan
                        // reçoit toujours la fraction de ce que le joueur a réellement gagné). bossTaskId
                        // non vide → posé dans last_task_boss, qui ne sert plus qu'à CHOISIR L'ANIMATION
                        // côté joueur (coup de pouce plutôt que victoire).
                        boostedXp  = _bossPlayerXp(xp, rec, taskId: taskId);
                        bossTaskId = rec.isNotEmpty ? taskId : "";
                    }
                    await _writeVerdict(clanId, clanSecret, taskId, region, accept, partial, assignee);
                    await _notifyAssignee(clanId, clanSecret, region, assignee,
                        verdict == "ok"      ? "combat_validate_ok"
                        : verdict == "partial" ? "combat_validate_partial"
                        :                        "combat_validate_ko", taskId);
                    if (accept && xp > 0 && assignee.isNotEmpty) {
                        // last_task = now réécrit AVEC l'xp (une seule écriture) → l'assignee voit une
                        // tâche accomplie (VICTOIRE), pas un cadeau (cf. _creditXp / _checkPlayerLevelUp).
                        // bossTaskId (non vide si tâche recommandée) est posé DANS la même écriture
                        // (last_task_boss) → le joueur joue l'anim « coup de pouce » plutôt que la victoire.
                        // _creditXp RENVOIE l'XP réellement versée, écrêtée au plafond de l'assignee
                        // (clans_players.max_xp) — c'est elle qui sert ensuite au clan et au journal,
                        // pas l'XP boostée brute.
                        playerXp = await _creditXp(clanId, clanSecret, region, assignee, boostedXp,
                                        lastTaskWhen: DateTime.now().toUtc().toIso8601String(),
                                        bossTaskId: bossTaskId);
                        await _creditClanXp(clanId, clanSecret, region, playerXp);   // CLAN = part de l'XP RÉELLE (bonus boss compris, plafond appliqué)
                    }
                    // Journal : verdict admin (ok / partiel / refusé). userId = celui qui a fait
                    // la tâche (assignee), adminId = l'admin courant qui tranche.
                    // ÉCRIT APRÈS LE CRÉDIT, et avec `playerXp` : le journal doit dire ce que le joueur
                    // a RÉELLEMENT gagné. Écrit avant, et avec l'XP de base, il annonçait 20 XP sur une
                    // tâche recommandée qui en avait crédité 100 — le bonus « boss » restait invisible.
                    // `xp_base` garde la trace du gain sans bonus ni plafond (audit), `boss` marque la ligne.
                    final adminName    = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                    final assigneeName = await _playerName(clanId, clanSecret, region, assignee);
                    final vEvent = partial ? "TaskValidatedPartial" : accept ? "TaskValidatedOk" : "TaskValidatedKo";
                    await _writeClanLog(clanId, clanSecret, region, vEvent,
                        userId: assignee, adminId: _userId, task: taskId, slug: taskId,
                        data: Dvidle({"taskId": taskId, "assigneeId": assignee,
                                      "assigneeName": assigneeName, "adminId": _userId,
                                      "adminName": adminName, "verdict": verdict,
                                      "xp": playerXp, "xp_base": xp,
                                      "boss": bossTaskId.isNotEmpty}));

                    // RELANCE DE CONVERSION : ce clan vient de mener une tâche à son terme.
                    // Après le journal, donc après que tout ce qui devait être crédité l'a été —
                    // un compteur qui avancerait sur un verdict à moitié appliqué mentirait.
                    // `accept` seulement : une tâche à moitié validée a été faite, créditée et
                    // fêtée, elle prouve que le jeu tourne ; un refus ne prouve rien.
                    // Le double comptage est impossible : la garde d'idempotence `validating`
                    // en tête de cette fonction est déjà franchie, un second admin qui tranche
                    // la même tâche est ressorti bien avant d'arriver ici.
                    if (accept) await _storeCountValidation(clanId, clanSecret, region);

                    // L'ADMIN qui tranche contribue au jeu : trancher COMPTE comme avoir joué. On recale
                    // SON last_task=now → la dégradation temporelle repart de zéro, il ne perd plus de PV
                    // pendant qu'il arbitre les tâches des autres. Vrai pour les trois verdicts (arbitrer
                    // un refus est le même travail qu'arbitrer une réussite). last_task seul, SANS xp :
                    // _checkPlayerLevelUp ne voit pas de hausse d'xp → aucune animation parasite, il ne
                    // fait que rafraîchir sa mémoire (cf. branche `xp <= storedXp`). Pas d'auto-crédit :
                    // si l'admin est l'assignee (auto-validation), _creditXp a déjà posé son last_task.
                    if (_userId.isNotEmpty && _userId != assignee) {
                        await _touchLastTask(clanId, clanSecret, region, _userId,
                                             DateTime.now().toUtc().toIso8601String());
                        deva_log("info", "[combat] last_task recalé pour l'admin $_userId (verdict '$verdict' sur $taskId)");
                    }
    }

    // Lecture ciblée UNIQUE d'un doc de tâche (statut + recommended dans le même read).
    // Repli null en cas d'échec — les extracteurs replient alors sur "" (garde
    // d'idempotence qui abandonne, pas de bonus ni de nettoyage indus).
    Future<Dvidle?> _readTaskDoc(String clanId, String clanSecret, String region, String taskId) async {

                                try {
                                    return await _cloud?.read(
                                        "workers", "clans_tasks/$clanId/tasks", taskId,
                                        ownerId: clanSecret, region: region);
                                } catch (e) {
                                    deva_log("warning", "[combat] _readTaskDoc $taskId: $e");
                                    return null;
                                }
    }

    // Lecture ciblée du champ `recommended` (boss) d'une tâche. Repli "" en cas d'échec (→ pas de
    // bonus ni de nettoyage indus). Fraîche : le miroir local peut être vide en chemin headless.
    Future<String> _readTaskRecommended(String clanId, String clanSecret, String region, String taskId) async =>
                                (await _readTaskDoc(clanId, clanSecret, region, taskId))?.get("recommended")?.toString() ?? "";

    // Payload métier d'un message dvmsg : dv.get("data") est une JSON string (range global,
    // sérialisée par le backend) ou une Map/Dvidle (range local). Normalise en Map.
    Map<String, dynamic> _msgData(Dvidle dv) {

                                final raw = dv.get("data");
                                if (raw is String && raw.isNotEmpty) {
                                    try { final p = jsonDecode(raw); if (p is Map) return Map<String, dynamic>.from(p); } catch (_) {}
                                }
                                if (raw is Dvidle) { final j = raw.toJson(); if (j is Map<String, dynamic>) return j; }
                                if (raw is Map) return Map<String, dynamic>.from(raw);
                                return {};
    }

    // Logique commune aux trois boutons verdict de l'UI (mode revue admin).
    //   verdict = "ok"      → "Le monstre est vaincu !" : XP plein + libération/respawn.
    //   verdict = "partial" → "À moitié vaincu…"        : moitié des XP + tâche à moitié régénérée.
    //   verdict = "ko"      → "Raté... essaie encore."  : retour à "assigned".
    Future<void> _handleVerdict(String verdict) async {

                                final reviewTask = (await Deva.instance.get("session.review_task"))?.toString() ?? "";
                                if (reviewTask.isEmpty) { DvOrb.navigate_reset("combat"); return; }

                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final userDoc    = await _readSession(region) ?? Dvidle({});
                                var   clanId     = userDoc.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = userDoc.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty) clanId = (await Deva.instance.get("session.clan.id"))?.toString() ?? "";
                                final assignee   = (await Deva.instance.get("session.review_assignee"))?.toString() ?? "";
                                final taskId     = _taskIdFromActive(reviewTask, clanId);

                                await _applyVerdict(verdict, clanId, clanSecret, region, taskId, assignee);

                                // Sortie du mode revue → retour au tiroir (appear voit review_task vide).
                                await Deva.instance.set("session.review_task",     "");
                                await Deva.instance.set("session.review_assignee", "");
                                DvOrb.navigate_reset("combat");
    }

    // Verdict déclenché par un bouton de la notification admin. taskId/assignee viennent du
    // message (payload métier) ; les identifiants clan viennent de la session de l'admin.
    // Aucune navigation : app ouverte, l'appear rafraîchira ; app relancée en mode restreint,
    // l'app s'arrête après coup (wakeup=false).
    Future<void> _handleNotifVerdict(String verdict, dynamic event) async {

                                final dv       = event is Dvidle ? event : Dvidle(event is Map ? Map<String, dynamic>.from(event) : {});
                                final data     = _msgData(dv);
                                final taskId   = data["taskId"]?.toString()   ?? "";
                                final assignee = data["assignee"]?.toString() ?? "";
                                if (taskId.isEmpty) { deva_log("warning", "[combat] notif verdict: taskId manquant"); return; }

                                // App potentiellement relancée en mode restreint (noorb) par la notif :
                                // l'init session du worker (appear → _resolveUserId / _findBestSession)
                                // tourne en parallèle. Attendre (borné ~10 s) que le contexte clan de
                                // l'admin (userId + clanSecret) soit résolu avant d'appliquer le verdict.
                                String region = "", clanId = "", clanSecret = "";
                                for (var i = 0; i < 100; i++) {
                                    region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    if (_userId.isEmpty) _userId = await _resolveUserId();
                                    final userDoc = _userId.isEmpty ? null : await _readSession(region);
                                    clanId     = userDoc?.get("steps.clan.clanId")?.toString()     ?? "";
                                    clanSecret = userDoc?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty) clanId = data["clanId"]?.toString() ?? "";
                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty) break;
                                    await Future.delayed(const Duration(milliseconds: 100));
                                }

                                deva_log("info", "[combat] notif verdict '$verdict' task=$taskId assignee=$assignee clan=$clanId");
                                await _applyVerdict(verdict, clanId, clanSecret, region, taskId, assignee);
    }

    Future<void> on_notif_validate_ok(DvShape? caller, dynamic event)      async => _handleNotifVerdict("ok", event);

    Future<void> on_notif_validate_partial(DvShape? caller, dynamic event) async => _handleNotifVerdict("partial", event);

    Future<void> on_notif_validate_ko(DvShape? caller, dynamic event)      async => _handleNotifVerdict("ko", event);

    // Tap sur le CORPS de la notification de validation SANS boutons (clan qui n'a pas
    // de cotisation, cf. _notifyAdmins). Contrairement aux trois verdicts ci-dessus, on
    // ne tranche rien ici : on amène le chef DEVANT la tâche, dans l'app.
    //
    // Le drapeau n'est pas une précaution de confort, il est nécessaire. `on_pulse_open`
    // navigue de lui-même sans attendre la session, mais il vise le `dashboard` —
    // c'est-à-dire la destination que l'ouverture de session aurait choisie de toute
    // façon, si bien que la course est sans conséquence. Nous visons `combat` AVEC un
    // contexte de revue : la navigation d'ouverture de session l'écraserait sans bruit.
    // On ne navigue donc tout de suite que si l'app est déjà en jeu ; sinon on arme, et
    // le dashboard consommera au seul instant où la session est réellement prête.
    Future<void> on_notif_open_task(DvShape? caller, dynamic event) async {

                                final dv     = event is Dvidle ? event : Dvidle(event is Map ? Map<String, dynamic>.from(event) : {});
                                final data   = _msgData(dv);
                                final taskId = data["taskId"]?.toString() ?? "";
                                if (taskId.isEmpty) {
                                    deva_log("warning", "[combat] notif ouverture: taskId manquant");
                                    return;
                                }

                                await deva_set("worker.pending_review_task", taskId);
                                await Deva.instance.store();

                                // App déjà en jeu (premier plan ou arrière-plan réveillé) : une page est
                                // montée ET le clan est résolu. Même test qu'à la fin de _handleClanJoin,
                                // pour la même raison — savoir si quelqu'un est encore là pour consommer.
                                final page   = DvOrb.get_current_page();
                                final clanId = (await Deva.instance.get("session.clan.id"))?.toString() ?? "";
                                if (page != null && clanId.isNotEmpty) {
                                    await _consumePendingReviewTask();
                                    return;
                                }
                                deva_log("info", "[combat] notif ouverture tapée app fermée — revue différée au dashboard");
    }

    // Consomme la revue armée par la notification. Rend `true` si l'écran a été pris en
    // main (l'appelant ne doit alors rien enchaîner derrière).
    //
    // ONE-SHOT, sauf une exception assumée : le drapeau est effacé AVANT tout await
    // risqué (patron _playPendingClanWelcome), pour qu'un plantage en aval ne fasse pas
    // ressurgir une revue trois jours plus tard.
    Future<bool> _consumePendingReviewTask() async {

                                final taskId = (await deva_get("worker.pending_review_task"))?.toString() ?? "";
                                if (taskId.isEmpty) return false;

                                // CLAN GELÉ. `seltask` fait un navigate_reset("combat") sans repasser par
                                // on_dashboard_appear, seul endroit qui garde la porte du gel : sans ce
                                // test, un chef de clan gelé atterrirait sur une revue au lieu de l'écran
                                // qui lui explique pourquoi le donjon est fermé.
                                if (await _storeLocked()) {
                                    await deva_set("worker.pending_review_task", "");
                                    await Deva.instance.store();
                                    deva_log("info", "[combat] revue abandonnée — clan gelé");
                                    DvOrb.navigate_reset("locked_page");
                                    return true;
                                }

                                // CHEF MORT : _selectTask sort sans rien afficher, et la notification
                                // aurait donc l'air cassée. SEULE SORTIE QUI NE CONSOMME PAS, et elle est
                                // délibérée : un mort ne peut littéralement rien arbitrer, ce n'est pas un
                                // échec mais un report. Le drapeau attend le prochain dashboard, donc
                                // l'après-résurrection ou l'après-soin. Le logout le purge.
                                if ((await Deva.instance.get("session.player_dead")) == true) {
                                    deva_log("info", "[combat] revue $taskId reportée — le chef est mort");
                                    return false;
                                }

                                await deva_set("worker.pending_review_task", "");
                                await Deva.instance.store();

                                // On DÉLÈGUE à seltask plutôt que de poser review_task/review_assignee
                                // nous-mêmes : _selectTask relit le statut FRAIS sur Firestore, revérifie
                                // que l'utilisateur est bien admin ET qu'il n'est pas l'assignee, puis
                                // navigue. Trois contrôles qu'un second chemin ferait tôt ou tard diverger
                                // — et le premier règle gratuitement le cas de la tâche déjà tranchée par
                                // l'autre chef, qui ne mène alors à aucune revue.
                                //
                                // GARDE ASSUMÉE : si le chef a lui-même une tâche en cours, _selectTask le
                                // ramène à SON combat et pas à la revue. On laisse faire — l'app est
                                // ouverte, ce qui est tout l'objet de cette notification, et la tâche à
                                // valider l'attend dans le tiroir avec sa flamme, à deux taps.
                                final act = ActionRegistry.get("seltask.$taskId");
                                if (act == null) {
                                    deva_log("warning", "[combat] revue $taskId : action seltask introuvable");
                                    return false;
                                }
                                deva_log("info", "[combat] ouverture de la revue $taskId");
                                await act(null, null);
                                return true;
    }

    // Bouton "Le monstre est vaincu !" : la tâche est validée et libérée (XP plein).
    Future<void> on_validate_ok(DvShape? caller, dynamic event) async => _handleVerdict("ok");

    // Bouton "À moitié vaincu…" : acceptation partielle (moitié des XP, tâche à moitié régénérée).
    Future<void> on_validate_partial(DvShape? caller, dynamic event) async => _handleVerdict("partial");

    // Bouton "Raté... essaie encore." : la tâche repasse en "assigned".
    Future<void> on_validate_ko(DvShape? caller, dynamic event) async => _handleVerdict("ko");

    // Réception côté JOUEUR de la notif de verdict (action `foreground:true` portée par le
    // message de _notifyAssignee). Arrête le poll et résout immédiatement en lisant le statut
    // autoritaire (au lieu d'attendre le prochain tick Fibonacci).
    Future<void> on_validation_resolved(DvShape? caller, dynamic event) async {

                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final userDoc    = await _readSession(region) ?? Dvidle({});
                                var   clanId     = userDoc.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = userDoc.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty) clanId = (await Deva.instance.get("session.clan.id"))?.toString() ?? "";
                                final activeTask = (await Deva.instance.get("session.active_task"))?.toString() ?? "";

                                if (activeTask.isEmpty || clanId.isEmpty || clanSecret.isEmpty) {
                                    _stopValidationPolling();
                                    return;
                                }
                                final taskId = _taskIdFromActive(activeTask, clanId);
                                final stop   = await _pollValidationOnce(clanId, clanSecret, region, taskId);
                                if (!stop) {
                                    // Course rare : statut pas encore propagé. Le poll en cours retentera.
                                    deva_log("info", "[combat] on_validation_resolved: statut encore validating, poll continue");
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
