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
// --- worker extension — Célébrations
// -----------------------------------------------------------------------------
extension Worker_celebrations on worker {

    void _register_celebrations() {

                                // Overlay de mort, posé/retiré AU BON ACTE d'un interlude (cf. flame.scenes) et non
                                // après un délai en dur : le crâne disparaît quand le voile blanc du soin est plein,
                                // et le « GAME OVER » paraît quand l'écran est devenu noir.
                                ActionRegistry.register("worker.hide_skull",                 hide_skull);

                                ActionRegistry.register("worker.show_gameover",              show_gameover);

                                ActionRegistry.register("worker.on_celebration_end",         on_celebration_end);

                                ActionRegistry.register("worker.noop",                      (c, e) async {});

                                // Bouton « Résurrection » (admin solo mort) : auto-soin sans cooldown.
                                ActionRegistry.register("worker.resurrect_self",            resurrect_self);

    }

    // Joue la bienvenue clan si le drapeau one-shot `worker.pending_clan_welcome` est armé (posé par
    // les handlers d'enrôlement : création de clan, jointure QR/PIN, lobby). Renvoie true si elle a
    // été lancée — l'appelant sait alors que le tutoriel du dashboard ne lui appartient plus : il
    // sera ouvert par la FIN de cette animation (on_celebration_end → _enterTutoAfterWelcome).
    // On gèle la page (progressring habituel de DvPage) le temps de garantir les infos clan, puis on
    // joue la bienvenue via la mécanique levelup (scène "burn" + commons/levelup_label). Appelée
    // AVANT _evaluateDeath/_checkPlayerLevelUp, qui lisent aussi le clan.
    Future<bool> _playPendingClanWelcome() async {

                                final pending = (await deva_get("worker.pending_clan_welcome"))?.toString() ?? "";
                                if (pending.isEmpty) return false;

                                await deva_set("worker.pending_clan_welcome", "");   // one-shot
                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final page = DvOrb.get_current_page();
                                if (page is DvPage) page.freeze();
                                try {
                                    await _ensureClanReady(region);
                                } finally {
                                    if (page is DvPage) page.unfreeze();
                                }
                                // Armé AVANT de jouer : on_celebration_end peut arriver très vite (interlude
                                // inconnu, préemption) et ne doit pas trouver le relais encore inexistant.
                                _welcomeTuto = true;   // c'est la FIN de cette animation qui ouvrira le tutoriel
                                // Sans animation (dvinterlude hors build), personne ne notifiera de fin : on
                                // désarme le relais et on ouvre le tutoriel tout de suite, sinon il serait perdu.
                                if (!await _showClanWelcomeAnimation(pending == "created")) {
                                    _welcomeTuto = false;
                                    _enterTutoAfterWelcome();
                                }
                                return true;
    }

    // Attend qu'AUCUN interlude ne joue plus. `dvtuto.enter` renonce EN SILENCE quand un interlude
    // joue : avant de lui rendre la main, on s'assure que l'écran est vraiment libre — une
    // célébration a pu en préempter une autre, et dvinterlude notifie la fin du préempté AVANT de
    // reposer `interludes.playing` pour son remplaçant.
    // Le plafond est posé AU-DELÀ du garde-fou de dvinterlude (20 s), qui termine de lui-même une
    // scène dont la fin n'est jamais notifiée : dans la vie normale c'est lui qui débloque, jamais
    // ce délai-ci.
    Future<void> _waitInterludesIdle() async {

                                const step  = Duration(milliseconds: 200);
                                const limit = 25000 ~/ 200;
                                for (var i = 0; i < limit; i++) {
                                    if (await deva_get("interludes.playing", false) != true) return;
                                    await Future.delayed(step);
                                }
                                deva_log("warning", "[welcome] un interlude joue encore après 25 s : on enchaîne");
    }

    // Détecte la mort (pvShown <= 0), la persiste (status="dead" + gage tiré au hasard,
    // deep-merge → préserve pv/xp/…), pose les flags de session et bascule l'overlay.
    // Appelé uniquement depuis on_dashboard_appear (lancement) et on_personnage_appear.
    // celebrateHeal : si true (défaut), une transition mort → vivant déclenche l'animation de soin
    // ICI MÊME, juste après _applyDeath (qui retire le crâne) → l'animation démarre au moment exact
    // du switch crâne → page normale, elle EST la transition. Passé false quand une montée de niveau
    // vient d'être célébrée (priorité level-up : jamais deux animations à la fois).
    Future<void> _evaluateDeath({bool celebrateHeal = true, bool celebrateDeath = true}) async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return;

                                    final doc = await _cloud?.read(
                                        "workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    final pv       = int.tryParse(doc.get("pv")?.toString() ?? "$_playerPv") ?? _playerPv;
                                    final damage   = int.tryParse(doc.get("damage")?.toString() ?? "0") ?? 0;
                                    final decay    = _readDecay(doc.get("decay"));
                                    final lastTask = doc.get("last_task")?.toString() ?? "";
                                    final status   = doc.get("status")?.toString() ?? "alive";
                                    final storedGage = doc.get("gage")?.toString() ?? "";

                                    final pvShown = _computeDisplayedPv(pv, damage, lastTask, decay);
                                    // Mort déterminée UNIQUEMENT par les PV affichés (même calcul que la barre de
                                    // vie), INDÉPENDAMMENT du champ `status` : la détection suit l'affichage, pas un
                                    // drapeau stocké (un status "dead"/"alive" incohérent ne fausse plus le déclencheur).
                                    // EXCEPTION : un joueur hors-device (has_device=false) ne peut pas mourir — si un
                                    // admin le déclare hors ligne alors qu'il est encore connecté, sa vigilance ne doit
                                    // NI jouer le burn NI basculer en mode mort (et à sa reconnexion, _writeClanPlayer
                                    // recale déjà last_task=now → PV pleins).
                                    final dead    = pvShown <= 0 && doc.get("has_device") != false;

                                    var gage = storedGage;
                                    if (dead && gage.isEmpty) {
                                        gage = "gage_${(Random().nextInt(11) + 1).toString().padLeft(2, '0')}";
                                    }

                                    // Admin SOLO mort → bouton « Résurrection » (personne d'autre ne peut le soigner).
                                    // _ensureIsAdmin peuple _isAdmin/_adminCount (cache par clan) ; échec de lecture →
                                    // _adminCount=0 → loneAdmin faux → pas de bouton (repli sûr).
                                    await _ensureIsAdmin(clanId, clanSecret, region);
                                    final loneAdmin = _isAdmin && _adminCount <= 1;

                                    // On fige l'état précédent + la décision (healing/dying) ET on démarre l'animation
                                    // AVANT toute écriture cloud (plus bas) : l'écriture status="dead" re-déclenche le
                                    // watch (→ un 2e _evaluateDeath). En posant ici session.player_dead=true et en
                                    // lançant _celebrateDeath (qui met _deathChecking=true de façon SYNCHRONE) avant le
                                    // write, le 2e passage voit prevDead=true (dying=false) ET _deathChecking=true → il
                                    // n'affiche PAS le crâne prématurément (c'est _celebrateDeath qui le pose à ~4 s).
                                    final prevDead = (await deva_get("session.player_dead")) == true;
                                    final prevGage = (await deva_get("session.player_gage"))?.toString() ?? "";
                                    await deva_set("session.player_dead", dead);
                                    await deva_set("session.player_gage", gage);
                                    // État de vie MÉMORISÉ (persisté) : au prochain lancement, la musique d'ambiance
                                    // démarre déjà sur la bonne playlist, comme le crâne s'affiche déjà dès la 1re frame.
                                    // Comparé au flag PERSISTÉ, pas à prevDead : resurrect_self remet déjà
                                    // session.player_dead à false avant nous (dead == prevDead == false) — on raterait
                                    // la remise à jour et le mort ressuscité redémarrerait sur la musique de mort.
                                    if (dead != ((await deva_get("worker.player_dead")) == true)) {
                                        await deva_set("worker.player_dead", dead);
                                        await Deva.instance.store();
                                    }
                                    // Transition mort → vivant = le joueur vient d'être soigné (résurrection par un
                                    // admin via revive_player). prevDead lu depuis session.player_dead (déjà réécrit à
                                    // `dead` ci-dessus → pas de re-fire au prochain passage ; pas de célébration à
                                    // l'amorçage où prevDead=false).
                                    final healing = celebrateHeal && prevDead && !dead;
                                    // Transition vivant → mort = MIROIR du soin (le joueur vient d'atteindre 0 PV).
                                    // _deathSeeded exige qu'on ait déjà observé un état AVANT : au tout 1er passage
                                    // d'une session (ouverture app déjà mort), prevDead=false donnerait une fausse
                                    // transition → on amorce sans animer. Symétrique de `healing`.
                                    final dying = celebrateDeath && _deathSeeded && !prevDead && dead;
                                    _deathSeeded = true;

                                    if (healing) {
                                        // Fire-and-forget : _celebrateHeal lance l'interlude de façon SYNCHRONE (avant
                                        // tout await) puis résout le texte en tâche de fond → on ne bloque pas
                                        // l'appelant (appear/watch) pendant les ~8 s du spectacle.
                                        _celebrateHeal(clanId, clanSecret, region);
                                    } else if (dying) {
                                        // Fire-and-forget symétrique : _celebrateDeath pose _deathChecking=true tout de
                                        // suite et lance l'interlude. Le crâne sera posé SOUS le noir (worker.show_gameover,
                                        // tiré par la fin de l'acte qui noircit) : on ne l'AFFICHE PAS brutalement.
                                        _celebrateDeath(gage, dead && loneAdmin);
                                    } else if (!(dead && _deathChecking)) {
                                        // Vivant, ou déjà mort SANS transition (ré-entrée d'écran) : on applique l'état
                                        // de l'overlay immédiatement. MAIS pas si une animation de mort est en cours
                                        // (_deathChecking, ex. 2e passage déclenché par l'écriture status="dead") : le
                                        // crâne serait affiché AVANT que le voile noir ne le couvre (flash).
                                        await _applyDeath(dead, gage,
                                            persist: dead != prevDead || gage != prevGage,
                                            showRevive: dead && loneAdmin);
                                    }

                                    // Ambiance : le mort a la sienne. On la déclare DÈS QU'ON SAIT — y compris pendant
                                    // que l'interlude vient de couper la musique : dvsound la mémorise et la jouera à la
                                    // reprise. Pas de cas particulier à écrire ici, c'est tout l'intérêt du découpage.
                                    await _setAmbiance(dead);

                                    deva_log("info", "[death] pvShown=$pvShown status=$status dead=$dead gage=$gage loneAdmin=$loneAdmin healing=$healing dying=$dying deathChecking=$_deathChecking");

                                    // Persistance cloud APRÈS avoir figé l'état + démarré l'animation (cf. commentaire
                                    // ci-dessus) : "dead" à la transition ; sinon complète juste le gage manquant.
                                    if (pvShown <= 0 && status != "dead") {
                                        await _cloud?.write("workers", "clans_players/$clanId/players", _userId,
                                            Dvidle({"status": "dead", "gage": gage}), region: region, ownerId: clanSecret);
                                    } else if (dead && storedGage.isEmpty && gage.isNotEmpty) {
                                        await _cloud?.write("workers", "clans_players/$clanId/players", _userId,
                                            Dvidle({"gage": gage}), region: region, ownerId: clanSecret);
                                    }
                                } catch (e) {
                                    deva_log("error", "[death] _evaluateDeath FAILED: $e");
                                }
    }

    // Bascule GLOBALE de l'overlay de mort. Mute les templates de conf (→ les pages futures
    // naissent visibles) + persiste le layer runtime (réappliqué au redémarrage) + show/hide
    // sur toutes les pages déjà en pile (retours arrière). Symétrique : rétablit à false quand vivant.
    // showRevive : n'affiche le bouton « Résurrection » (sous le gage) que pour l'admin SOLO mort ;
    // pour un joueur lambda / un admin non-solo, le bouton reste masqué (il faut un autre admin).
    Future<void> _applyDeath(bool dead, String gage, {bool persist = true, bool showRevive = false}) async {

                                try {
                                    // Texte du gage + 2 sauts de ligne + phrase de soin (les 2 tokens traduits au rendu).
                                    final gageLabel  = "@@@T:$gage@@@\n\n@@@T:gage_heal@@@";
                                    final showBtn    = dead && showRevive;
                                    await deva_set("registry.commons/death_scrim.shape.visible",  dead);
                                    await deva_set("registry.commons/death_skull.shape.visible",  dead);
                                    await deva_set("registry.commons/death_gage.shape.visible",   dead);
                                    await deva_set("registry.commons/death_revive.shape.visible", showBtn);
                                    if (dead && gage.isNotEmpty) {
                                        await deva_set("registry.commons/death_gage.shape.label", gageLabel);
                                    }
                                    // Flush le layer runtime sur disque → l'overlay est réappliqué au prochain
                                    // démarrage (bootstrap → merge) dès la 1re frame (cf. store() ligne ~481).
                                    // Uniquement sur changement d'état (évite une écriture disque à chaque visite).
                                    if (persist) await Deva.instance.store();

                                    // Les 4 shapes sont déclarées UNE fois (commons/death_*) et injectées dans les
                                    // écrans à taskbar par le registry du template "page_taskbar" → chaque page en
                                    // possède SA propre instance, sous le MÊME dvid. D'où le get_shape_by_id
                                    // d'INSTANCE (p.…) et non le statique (DvOrb.…, qui ne rendrait que celle de la
                                    // page du dessus) : les pages du dessous (retours arrière) doivent suivre aussi.
                                    // Les écrans sans overlay (login…) renvoient null → les ?. les ignorent.
                                    for (final p in DvPage.actives) {
                                        final scrim  = p.get_shape_by_id("commons/death_scrim");
                                        final skull  = p.get_shape_by_id("commons/death_skull");
                                        final gageS  = p.get_shape_by_id("commons/death_gage");
                                        final revive = p.get_shape_by_id("commons/death_revive");
                                        if (dead) {
                                            if (gageS is DvLabel && gage.isNotEmpty) gageS.write(gageLabel);
                                            scrim?.show(); skull?.show(); gageS?.show();
                                            if (showBtn) { revive?.show(); } else { revive?.hide(); }
                                        } else {
                                            scrim?.hide(); skull?.hide(); gageS?.hide(); revive?.hide();
                                        }
                                    }
                                } catch (e) {
                                    deva_log("error", "[death] _applyDeath FAILED: $e");
                                }
    }

    // Bouton « Résurrection » de l'écran de mort, réservé à l'admin SOLO (le seul admin de son clan,
    // que personne d'autre ne peut soigner). Auto-ciblé : remet damage=0, last_task=now, status=alive
    // (deep-merge → préserve pv/xp/…), efface le gage, et masque l'overlay. Contrairement à
    // revive_player, NE touche PAS last_cure (pas de cooldown : c'est un déblocage de secours).
    Future<void> resurrect_self(dynamic caller, dynamic event) async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return;

                                    // Gage porté (capturé AVANT effacement) pour le journal d'audit.
                                    final gage = (await deva_get("session.player_gage"))?.toString() ?? "";

                                    final now = DateTime.now().toUtc().toIso8601String();
                                    final out = Dvidle({});                 // deep-merge : ne réécrit que ces champs
                                    out.set("id",        _userId);
                                    out.set("damage",    0);
                                    out.set("last_task", now);
                                    out.set("status",    "alive");
                                    out.set("gage",      "");               // repart d'un état vivant propre
                                    await _cloud?.write("workers", "clans_players/$clanId/players", _userId, out,
                                        region: region, ownerId: clanSecret);
                                    // NB : on NE touche PAS last_cure (contrairement à revive_player).

                                    // Journal : l'admin solo s'est ressuscité (on trace le gage qu'il portait).
                                    final selfName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "PlayerResurrected",
                                        userId: _userId, adminId: _userId, slug: gage,
                                        data: Dvidle({"playerId": _userId, "playerName": selfName,
                                                      "gage": gage, "adminId": _userId, "adminName": selfName}));

                                    await deva_set("session.player_dead", false);
                                    await deva_set("session.player_gage", "");
                                    // On NE retire PAS le crâne ici : l'interlude de soin lance le voile (qui le masque)
                                    // et le crâne est retiré SOUS le blanc, à la fin de l'acte qui étale le voile
                                    // (worker.hide_skull) → le voile fait la transition crâne → page. Fire-and-forget.
                                    // Auto-résurrection → _findRecentHealer verra adminId == moi et renverra ""
                                    // → texte générique healed_anim (pas de « sauvé par soi-même »).
                                    _celebrateHeal(clanId, clanSecret, region);
                                    deva_log("info", "[death] résurrection admin solo: $_userId");
                                } catch (e) {
                                    deva_log("error", "[death] resurrect_self FAILED: $e");
                                }
    }

    // Après un verdict ACCEPTÉ : garantit la célébration côté joueur SANS dépendre du watch temps réel
    // (_playerVigilance, peu fiable / desktop-only). Le crédit XP de l'admin (_creditXp) est un write
    // SÉPARÉ et POSTÉRIEUR au changement de statut qui déclenche la résolution (et à la notif
    // on_validation_resolved) → on attend (borné ~10 s) que l'XP dépasse la baseline mémorisée, PUIS on
    // délègue à _checkPlayerLevelUp, qui décide seul (victoire / coup de pouce / level-up), consomme la
    // récompense boss (recommended) et gère l'anti-double-fire (player_last_xp + _levelUpChecking).
    // Idempotent avec le watch : celui des deux qui gagne la course célèbre, l'autre est un no-op.
    Future<void> _celebrateAfterAccept(String clanId, String clanSecret, String region) async {

                    try {
                        if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return;
                        final storedRaw = await deva_get("worker.player_last_xp");
                        // Baseline absente = amorçage pas encore fait → on NE poll PAS (aucune célébration à
                        // forcer) : _checkPlayerLevelUp amorcera silencieusement la baseline.
                        final baseline  = storedRaw == null ? null : int.tryParse(storedRaw.toString());
                        if (baseline != null) {
                            for (var i = 0; i < 100; i++) {                     // ~10 s (100 × 100 ms)
                                Dvidle? doc;
                                try {
                                    doc = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region);
                                } catch (_) { doc = null; }
                                final xpRaw = doc?.get("xp");
                                final xp    = xpRaw == null ? null : int.tryParse(xpRaw.toString());
                                if (xp != null && xp > baseline) break;        // XP arrivée → on peut célébrer
                                // Le watch a pu résoudre pendant l'attente : player_last_xp aurait avancé → on sort.
                                final nowRaw = await deva_get("worker.player_last_xp");
                                final now    = nowRaw == null ? baseline : (int.tryParse(nowRaw.toString()) ?? baseline);
                                if (now != baseline) break;
                                await Future.delayed(const Duration(milliseconds: 100));
                            }
                        }
                        // Que l'XP ait été vue ou non : _checkPlayerLevelUp relit, décide, et n'affiche rien si
                        // l'XP n'a pas bougé (garde xp <= storedXp, sans régression de baseline).
                        await _checkPlayerLevelUp();
                    } catch (e) {
                        deva_log("error", "[levelup] _celebrateAfterAccept FAILED: $e");
                    }
    }

    //-----------------------------------------------------------------------
    //-- Montée de niveau : célébration locale + notification au clan -------
    //-----------------------------------------------------------------------

    // Détecte une montée de niveau du joueur COURANT en comparant l'xp fraîchement lue
    // (clans_players/{clanId}/players/{_userId}) à l'xp mémorisée dans le dico deva
    // (worker.player_last_xp). Le niveau n'est pas stocké : il se dérive via getNiveauProgres().
    // Appelé depuis les handlers d'apparition qui atterrissent après une validation (dashboard)
    // ou consultent le niveau (personnage). Modèle : _evaluateDeath (même lecture de doc).
    //
    // Amorçage : à la 1re exécution (valeur absente) on mémorise SANS célébrer → aucune fausse
    // montée pour les joueurs existants au déploiement de la feature. La nouvelle xp est toujours
    // persistée AVANT de déclencher l'animation → un seul déclenchement (au retour dashboard,
    // xp == storedXp donc pas de re-fire).
    // Retourne true SSI une célébration plein écran a été jouée — montée de niveau OU cadeau d'XP de
    // la guilde (xp+ à tâche inchangée, cf. branche ci-dessous). L'appelant s'en sert pour NE PAS
    // déclencher en plus l'animation de soin (jamais deux célébrations à la fois).
    Future<bool> _checkPlayerLevelUp() async {

                                if (_levelUpChecking) return false;            // sérialise watch ↔ appear concurrents
                                _levelUpChecking = true;
                                bool celebrated = false;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return false;

                                    final doc = await _cloud?.read(
                                        "workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    // Un read échoué/transitoire donne un doc vide (xp absente). On sort SANS
                                    // toucher à la mémoire (sinon on écraserait player_last_task par "" et on
                                    // fausserait la détection de cadeau au prochain read valide). Le doc joueur
                                    // réel a toujours "xp" (initialisée à 0 à la création, worker.dart:2104).
                                    if (doc.get("xp") == null) return false;
                                    final xp       = int.tryParse(doc.get("xp")?.toString() ?? "0") ?? 0;
                                    final lastTask = doc.get("last_task")?.toString() ?? "";
                                    // Drapeau « boss » posé atomiquement avec xp+last_task par _creditXp (id de la
                                    // tâche recommandée validée, "" sinon). Snapshot cohérent → pas de course.
                                    final boss     = doc.get("last_task_boss")?.toString() ?? "";

                                    final storedRaw = await deva_get("worker.player_last_xp");
                                    if (storedRaw == null) {                       // amorçage silencieux
                                        await deva_set("worker.player_last_xp", xp);
                                        await deva_set("worker.player_last_task", lastTask);
                                        await Deva.instance.store();
                                        return false;
                                    }
                                    final storedXp       = int.tryParse(storedRaw.toString()) ?? xp;
                                    final storedLastTask = (await deva_get("worker.player_last_task"))?.toString() ?? "";
                                    // L'xp ne décroît jamais : une valeur < mémorisée = lecture transitoire/vide
                                    // (read échoué → doc {} → xp=0). Ne PAS rétrograder la mémoire, sinon la
                                    // prochaine lecture correcte rejouerait une fausse montée. On sort simplement.
                                    // On rafraîchit tout de même last_task (lecture valide ici) : la récompense de
                                    // niveau réécrit last_task=now SANS changer l'xp, et ce watch ressort par ici —
                                    // sans ce refresh, un cadeau ultérieur (xp+ à tâche inchangée) serait vu à tort
                                    // comme « tâche accomplie ».
                                    if (xp <= storedXp) {
                                        if (lastTask != storedLastTask) {
                                            await deva_set("worker.player_last_task", lastTask);
                                            await Deva.instance.store();
                                        }
                                        return false;
                                    }

                                    final oldNiv = getNiveauProgres(storedXp).niveau;
                                    final newNiv = getNiveauProgres(xp).niveau;

                                    // Toujours mémoriser la nouvelle xp (et le last_task courant) AVANT toute
                                    // célébration (anti double-fire).
                                    await deva_set("worker.player_last_xp", xp);
                                    await deva_set("worker.player_last_task", lastTask);
                                    await Deva.instance.store();

                                    if (newNiv <= oldNiv) {
                                        // Hausse d'xp sans franchir de palier. Deux cas, distingués par last_task :
                                        //  - inchangé  → CADEAU de la guilde (crédit via _creditXp sans lastTaskWhen,
                                        //                ex. coup de pouce +50 XP support_player) → anim giftxp.
                                        //  - changé    → XP de TÂCHE ACCOMPLIE ET VALIDÉE (le crédit a réécrit
                                        //                last_task en même temps, cf. _applyVerdict / on_combat_ok)
                                        //                → anim de VICTOIRE (et non plus « rien »).
                                        celebrated = true;                         // supprime aussi le soin (jamais 2 anims)
                                        if (lastTask == storedLastTask) {
                                            deva_log("info", "[gift] cadeau d'XP détecté (xp $storedXp → $xp, tâche inchangée)");
                                            await _showGiftAnimation();
                                        } else if (boss.isNotEmpty) {
                                            // Tâche RECOMMANDÉE validée → XP exceptionnels : anim « coup de pouce »
                                            // (giftxp) au lieu de la victoire, puis retrait du drapeau (la tâche,
                                            // elle, n'est déjà plus recommandée : effacée au verdict).
                                            deva_log("info", "[boss] tâche recommandée validée (xp $storedXp → $xp) → coup de pouce");
                                            await _showGiftAnimation();
                                            await _consumeBossReward(clanId, clanSecret, region, boss);
                                        } else {
                                            deva_log("info", "[victory] tâche validée (xp $storedXp → $xp, last_task changé)");
                                            await _showVictoryAnimation();
                                        }
                                        return celebrated;
                                    }
                                    celebrated = true;                             // à partir d'ici : célébration jouée

                                    // Titre : 1 nouveau tous les 5 niveaux. Nouveau titre ssi le rang a
                                    // augmenté — le joueur ne le PORTE plus automatiquement, il en gagne
                                    // l'OBJET, qui l'attend dans son inventaire (onglet Titres). C'est
                                    // exactement ce que les textes de célébration disaient déjà :
                                    // « tu peux PRÉTENDRE au titre de … ».
                                    final oldIdx   = _titleIdxFor(oldNiv);
                                    final newIdx   = _titleIdxFor(newNiv);
                                    final gotTitle = newIdx >= 0 && newIdx > oldIdx;
                                    final titleIdx = newIdx;

                                    final name = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    deva_log("info", "[levelup] $name : niveau $oldNiv → $newNiv (xp $storedXp → $xp)"
                                        "${gotTitle ? " nouveau titre #$titleIdx" : ""}");

                                    // L'item AVANT le spectacle : l'animation confisque l'écran, la notif part
                                    // sur le réseau — si l'un des deux échoue, le titre gagné doit tout de
                                    // même exister. Il n'y a pas de rattrapage : un échec ici est un titre
                                    // perdu (tracé en erreur par _grantTitleItem), rejoué seulement au palier
                                    // suivant.
                                    if (gotTitle) {
                                        await _grantTitleItem(clanId, clanSecret, region, titleIdx, clan: false);
                                    }

                                    await _showLevelUpAnimation(newNiv, gotTitle, titleIdx);
                                    await _notifyClanLevelUp(clanId, clanSecret, region, name, gotTitle, titleIdx);

                                    // Récompenses de la montée de niveau : soin complet du joueur (last_task=now +
                                    // damage=0 → _computeDisplayedPv repart de pv plein) et don au butin du clan
                                    // (10 × niveau — c'était 100, soit 30 tâches d'un coup : le butin sautait de
                                    // 44 à 354 sur un seul passage de niveau, écrasant l'échelle des gains par
                                    // tâche). Chaque écriture est isolée (helper avec try/catch propre) → un échec
                                    // ne casse pas l'animation ni la notif déjà jouées.
                                    await _rewardPlayerOnLevelUp(clanId, clanSecret, region, _userId);
                                    await _creditClanButinFixed(clanId, clanSecret, region, 10 * newNiv);

                                    // Le plafond d'XP par tâche affiché au badge de combat dépend du niveau
                                    // (cf. _readPlayerMaxXp) : sans cette invalidation, le badge continuerait
                                    // d'annoncer l'ancien plafond jusqu'à la prochaine écriture de doc joueur.
                                    _maxXpCache.remove(_userId);

                                    // La montée de niveau prime sur l'anim « coup de pouce », mais le drapeau
                                    // boss doit tout de même être retiré, sinon l'animation se rejouerait à la
                                    // prochaine hausse d'XP.
                                    if (boss.isNotEmpty) await _consumeBossReward(clanId, clanSecret, region, boss);

                                    // Priorité level-up gérée par l'appelant : il passe celebrateHeal=false à
                                    // _evaluateDeath quand cette méthode retourne true → pas d'animation de soin en
                                    // plus. (Le soin de niveau ne lève de toute façon pas status="dead" : un joueur
                                    // mort qui monte de niveau reste mort côté _evaluateDeath, donc pas de transition.)

                                    // Trace au journal d'audit du clan (visible dans l'écran log joueur).
                                    final logData = Dvidle({});
                                    logData.set("niveau", newNiv);
                                    if (gotTitle) logData.set("title_idx", titleIdx);
                                    await _writeClanLog(clanId, clanSecret, region, "PlayerLeveledUp",
                                        userId: _userId, slug: name, data: logData);
                                } catch (e) {
                                    deva_log("error", "[levelup] _checkPlayerLevelUp FAILED: $e");
                                } finally {
                                    _levelUpChecking = false;
                                }
                                return celebrated;
    }

    // Détecte un CADEAU D'OR : le champ gold du doc joueur augmente (crédité côté serveur/guilde).
    // Même schéma que la détection d'XP (clé mémoire worker.player_last_gold) : amorçage silencieux
    // au 1er passage, jamais de rétrogradation (une lecture < mémorisée = read transitoire/vide). Sur
    // une hausse réelle, mémorise la nouvelle valeur AVANT toute anim (anti double-fire), puis — si
    // `celebrate` — joue l'animation avec le GAIN (delta) et retourne true (l'appelant supprime alors
    // le soin, jamais deux célébrations à la fois). Quand `celebrate` est faux (une autre anim a déjà
    // été jouée ce tick), on met tout de même la mémoire à jour pour ne pas rejouer l'or au prochain
    // changement.
    Future<bool> _checkPlayerGoldGift({bool celebrate = true}) async {

                                if (_goldChecking) return false;               // sérialise watch ↔ appear concurrents
                                _goldChecking = true;
                                bool celebrated = false;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return false;

                                    final doc = await _cloud?.read(
                                        "workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    // Read échoué/transitoire → doc vide (gold absent) : on sort SANS toucher à la
                                    // mémoire (le doc joueur réel a toujours "gold", initialisé à 0 à la création).
                                    if (doc.get("gold") == null) return false;
                                    final gold = int.tryParse(doc.get("gold")?.toString() ?? "0") ?? 0;

                                    final storedRaw = await deva_get("worker.player_last_gold");
                                    if (storedRaw == null) {                       // amorçage silencieux
                                        await deva_set("worker.player_last_gold", gold);
                                        await Deva.instance.store();
                                        return false;
                                    }
                                    final storedGold = int.tryParse(storedRaw.toString()) ?? gold;
                                    // L'or ne décroît pas côté cadeau : une valeur < mémorisée = lecture transitoire
                                    // (read échoué → doc {} → gold=0). Ne PAS rétrograder la mémoire (sinon fausse
                                    // hausse rejouée au prochain read valide). On sort simplement.
                                    if (gold <= storedGold) return false;

                                    // Toujours mémoriser la nouvelle valeur AVANT toute célébration (anti double-fire).
                                    await deva_set("worker.player_last_gold", gold);
                                    await Deva.instance.store();

                                    final gain = gold - storedGold;
                                    if (celebrate) {
                                        celebrated = true;
                                        deva_log("info", "[giftgold] cadeau d'or détecté (gold $storedGold → $gold, +$gain)");
                                        await _showGiftGoldAnimation(gain);
                                    }
                                } catch (e) {
                                    deva_log("error", "[giftgold] _checkPlayerGoldGift FAILED: $e");
                                } finally {
                                    _goldChecking = false;
                                }
                                return celebrated;
    }

    // Retrouve le NOM du soigneur du joueur COURANT : parcourt clans_logs à la recherche du log
    // PlayerResurrected le plus récent où userId == moi (écrit par revive_player / resurrect_self,
    // data.adminName = soigneur). Borné en fraîcheur (< _healerLookbackS) pour ne pas ramasser un
    // vieux cycle de mort. Retourne "" si aucun soigneur identifié (log absent/trop vieux) OU si le
    // soigneur est moi-même (auto-résurrection admin solo) → l'appelant bascule sur le texte générique.
    //
    // revive_player écrit le doc joueur (→ déclenche mon watch) PUIS le log, sur deux documents qui
    // propagent indépendamment : le log peut n'être pas encore visible à la 1re lecture. On réessaie
    // donc quelques fois avec un court délai avant de renoncer (repli générique).
    Future<String> _findRecentHealer(String clanId, String clanSecret, String region) async {

                                for (var attempt = 0; attempt < 3; attempt++) {
                                    try {
                                        // 50 logs les plus récents suffisent largement : la fenêtre utile est
                                        // _healerLookbackS — un full list relirait tout l'historique du clan.
                                        final logs = await _cloud?.searchWhere("workers", "clans_logs/$clanId/logs", const [],
                                            region: region, skipIsolationFilter: true,
                                            orderBy: "date", descending: true, limit: 50) ?? [];
                                        Dvidle? best;
                                        for (final l in logs) {
                                            if (l is! Dvidle) continue;
                                            if ((l.get("event")?.toString()  ?? "") != "PlayerResurrected") continue;
                                            if ((l.get("userId")?.toString() ?? "") != _userId) continue;
                                            final t = DateTime.tryParse(l.get("date")?.toString() ?? "")?.toUtc();
                                            if (t == null) continue;
                                            if (DateTime.now().toUtc().difference(t).inSeconds > _healerLookbackS) continue;
                                            if (best == null || (l.get("date")?.toString() ?? "")
                                                    .compareTo(best.get("date")?.toString() ?? "") > 0) {
                                                best = l;
                                            }
                                        }
                                        if (best != null) {
                                            final adminId = best.get("adminId")?.toString().isNotEmpty == true
                                                ? best.get("adminId")!.toString()
                                                : (best.get("data.adminId")?.toString() ?? "");
                                            if (adminId.isEmpty || adminId == _userId) return "";   // auto-soin → générique
                                            return best.get("data.adminName")?.toString() ?? "";
                                        }
                                    } catch (e) {
                                        deva_log("error", "[heal] _findRecentHealer FAILED: $e");
                                        return "";
                                    }
                                    // Log pas encore propagé : petite attente puis nouvel essai.
                                    await Future.delayed(const Duration(milliseconds: 600));
                                }
                                return "";                                          // renoncement → repli générique
    }

    // Célébration SUR PLACE (pas de navigation) : tout le spectacle — le son qui l'annonce une demi-
    // seconde avant, l'écran confisqué, la scène "burn", la musique coupée puis rendue — est décrit par
    // l'interlude "levelup" (thème). Ne reste ici que le texte, qui est du métier : pré-résolu dans la
    // langue COURANTE (levelup_anim / levelup_anim_title, substitution {level}/{title}) et passé au
    // déclenchement. dvinterlude le pose dans le DvSplash de la page courante au démarrage du visuel ;
    // le DvSplash gère seul son fondu et se masque sans hook. L'écran reste le même avant/après.
    Future<void> _showLevelUpAnimation(int niveau, bool gotTitle, int titleIdx) async {

                                final lang = TranslationRegistry.currentLang;
                                Future<String> tr(String key) async {
                                    var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                                    if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                                    return v;
                                }

                                var text = gotTitle ? await tr("levelup_anim_title") : await tr("levelup_anim");
                                // [[ … ]] : marqueur de surbrillance du DvLabel → le niveau ressort en rouge/gras
                                // (highlight_color de commons/levelup_label). Le reste du texte reste en ambre.
                                text = text.replaceAll("{level}", "[[$niveau]]");
                                if (gotTitle) text = text.replaceAll("{title}", await tr("player_title_$titleIdx"));

                                ActionRegistry.get("dvinterlude.play.levelup")?.call(null, {"text": text});
    }

    // Célébration « cadeau d'XP de la guilde » (interlude "giftxp"). Déclenchée depuis
    // _checkPlayerLevelUp quand l'xp monte à last_task inchangé (bonus offert, pas de tâche finie).
    // Même mécanique que le level-up : on passe un texte pré-résolu dans la langue COURANTE (message
    // giftxp_anim en noir) entouré d'une pluie décorative de "XP" (marqueur [[ ]] → rouge via
    // highlight_color de commons/giftxp_label).
    Future<void> _showGiftAnimation() async {

                                final lang = TranslationRegistry.currentLang;
                                Future<String> tr(String key) async {
                                    var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                                    if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                                    return v;
                                }

                                final msg = await tr("giftxp_anim");
                                // Pluie décorative de "XP" rouges ([[ ]]) ; text_align CENTER centre chaque ligne.
                                const rain = "[[XP]]      [[xp]]        [[XP]]\n"
                                             "   [[xp]]        [[XP]]      [[xp]]\n"
                                             "[[XP]]        [[xp]]     [[XP]]";
                                final text = "$rain\n\n$msg\n\n$rain";

                                ActionRegistry.get("dvinterlude.play.giftxp")?.call(null, {"text": text});
    }

    // Célébration « tâche accomplie et validée » (interlude "victory"). Déclenchée depuis
    // _checkPlayerLevelUp quand l'xp monte à last_task CHANGÉ (le crédit de validation a réécrit
    // last_task, cf. _applyVerdict / on_combat_ok) : c'est une récompense de tâche, pas un cadeau.
    // Image victory_nobg.png en fondu (apparition/maintien/disparition, 3 s) + son tatadaa.mp3, jouée
    // par-dessus l'écran courant. Aucun texte → pas de splash à poser.
    Future<void> _showVictoryAnimation() async {

                                ActionRegistry.get("dvinterlude.play.victory")?.call(null, null);
    }

    //-----------------------------------------------------------------------
    //-- Promotion / rétrogradation chef détectée en temps réel -------------
    //-----------------------------------------------------------------------

    // Détecte un changement du statut chef du joueur COURANT en comparant le champ is_admin
    // fraîchement lu (clans_players/{clanId}/players/{_userId}) au dernier connu en mémoire
    // (worker.player_last_is_admin). Déclenché par la vigilance du doc joueur (_onPlayerDocChanged) :
    // la promotion/rétrogradation écrit is_admin sur CE doc, ce qui réveille le watch (là où une
    // modif de clans.admins seule ne le réveillait pas). Dans les deux sens, on resynchronise le
    // rôle (cache _isAdmin + UI chef + roster). Sur promotion (false→true) et si `celebrate`, on
    // joue l'animation "burn" du level-up avec le message promo (promote_chief_self). Retourne true
    // SSI une animation a été jouée (l'appelant supprime alors les autres célébrations).
    //
    // Amorçage silencieux (miroir du level-up) : à la 1re lecture (mémoire absente) on mémorise sans
    // rien jouer → aucun faux déclenchement pour les membres existants. Champ absent (record d'avant
    // la feature, ou read transitoire) → on sort sans toucher la mémoire.
    Future<bool> _checkChiefPromotion({bool celebrate = true}) async {

                                if (_chiefChecking) return false;              // sérialise watch ↔ appear concurrents
                                _chiefChecking = true;
                                bool celebrated = false;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return false;

                                    final doc = await _cloud?.read(
                                        "workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    final rawField = doc.get("is_admin");
                                    if (rawField == null) return false;        // champ absent → ne rien mémoriser
                                    final bool isAdmin = rawField == true || rawField.toString() == "true";

                                    // Mémoire stockée en chaîne ("true"/"false") : absente = jamais amorcée
                                    // (≠ "false"), sans ambiguïté de sérialisation booléenne.
                                    final storedRaw = await deva_get("worker.player_last_is_admin");
                                    if (storedRaw == null) {                   // amorçage silencieux
                                        await deva_set("worker.player_last_is_admin", isAdmin ? "true" : "false");
                                        await Deva.instance.store();
                                        return false;
                                    }
                                    final bool storedIsAdmin = storedRaw.toString() == "true";
                                    if (isAdmin == storedIsAdmin) return false;  // pas de changement

                                    // Mémoriser AVANT toute célébration (anti double-fire).
                                    await deva_set("worker.player_last_is_admin", isAdmin ? "true" : "false");
                                    await Deva.instance.store();

                                    // Resynchronise le rôle dans les deux sens : cache admin, UI chef (switch),
                                    // et tuiles du roster (couronne sur soi). _ensureIsAdmin relit clans.admins,
                                    // source d'autorisation (le miroir is_admin y est tenu synchrone).
                                    _isAdminClanId = "";
                                    await _ensureIsAdmin(clanId, clanSecret, region);
                                    await _syncChiefUi();
                                    await _refreshRoster(clanId, clanSecret, region);

                                    if (isAdmin && celebrate) {                 // promotion : célébration "burn"
                                        celebrated = true;
                                        deva_log("info", "[chief] promotion détectée → animation burn");
                                        await _showChiefPromotionAnimation();
                                    } else {
                                        deva_log("info", "[chief] statut chef resynchronisé (is_admin=$isAdmin)");
                                    }
                                } catch (e) {
                                    deva_log("error", "[chief] _checkChiefPromotion FAILED: $e");
                                } finally {
                                    _chiefChecking = false;
                                }
                                return celebrated;
    }

    // Célébration de promotion : réutilise l'interlude "levelup" (scène "burn" + son) avec le
    // message promo pré-résolu dans la langue COURANTE (promote_chief_self, repli fr).
    Future<void> _showChiefPromotionAnimation() async {

                                final lang = TranslationRegistry.currentLang;
                                var text = (await deva_get("lang.translations.promote_chief_self.$lang"))?.toString() ?? "";
                                if (text.isEmpty) text = (await deva_get("lang.translations.promote_chief_self.fr"))?.toString() ?? "";
                                if (text.isEmpty) return;
                                ActionRegistry.get("dvinterlude.play.levelup")?.call(null, {"text": text});
    }

    // Célébration « cadeau d'or de la guilde » (interlude "giftgold" : pluie de pièces + nappe d'or
    // montante). Déclenchée depuis _checkPlayerGoldGift quand le champ gold du joueur augmente. Texte
    // pré-résolu dans la langue COURANTE (giftgold_anim, {gold} = nombre de pièces reçues →
    // surbrillance rouge via highlight_color).
    Future<void> _showGiftGoldAnimation(int gain) async {

                                final lang = TranslationRegistry.currentLang;
                                Future<String> tr(String key) async {
                                    var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                                    if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                                    return v;
                                }

                                var text = await tr("giftgold_anim");
                                // {gold} → [[gain]] : le nombre de pièces ressort en rouge (highlight_color de
                                // commons/giftgold_label), le reste du message en noir sur l'or.
                                text = text.replaceAll("{gold}", "[[$gain]]");

                                ActionRegistry.get("dvinterlude.play.giftgold")?.call(null, {"text": text});
    }

    Future<void> _celebrateHeal(String clanId, String clanSecret, String region) async {

                                if (_healChecking) return;                     // une seule animation à la fois
                                _healChecking = true;                          // relâchée par on_celebration_end
                                try {
                                    ActionRegistry.get("dvinterlude.play.heal")?.call(null, null);

                                    // Le soigneur n'est connu qu'après une lecture réseau (1–2 s) : l'interlude ne
                                    // déclare donc pas de splash, on pose le texte nous-mêmes quand on l'a. Son fondu
                                    // (2 s) le fait arriver à temps sur le voile blanc.
                                    final name   = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    final healer = await _findRecentHealer(clanId, clanSecret, region);
                                    deva_log("info", "[heal] $name soigné (mort → vivant)"
                                        "${healer.isNotEmpty ? " par $healer" : ""} → célébration");

                                    final lang = TranslationRegistry.currentLang;
                                    Future<String> tr(String key) async {
                                        var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                                        if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                                        return v;
                                    }

                                    var text = await tr(healer.isNotEmpty ? "healed_by_anim" : "healed_anim");
                                    text = text.replaceAll("{name}", "[[$name]]");
                                    if (healer.isNotEmpty) text = text.replaceAll("{healer}", "[[$healer]]");
                                    ActionRegistry.get("dvorb.splash.commons/heal_label")?.call(null, text);
                                } catch (e) {
                                    deva_log("error", "[heal] _celebrateHeal FAILED: $e");
                                    _healChecking = false;                     // personne ne viendra la relâcher
                                }
    }

    // Célébration de MORT (0 PV) — miroir du soin. L'interlude "gameover" masque la transition écran de
    // jeu → écran de mort : le son (le glas) part d'abord, l'écran est confisqué, puis le voile noir le
    // recouvre progressivement (~3 s). À la FIN DE L'ACTE qui noircit, worker.show_gameover pose le
    // splash « GAME OVER » et applique le crâne SOUS le noir — il y reste masqué jusqu'au burst de
    // cendres qui le révèle.
    // _deathChecking est posé AVANT tout await : le 2e passage de _evaluateDeath (déclenché par
    // l'écriture status="dead") le voit déjà true → il n'affiche pas le crâne trop tôt. Il est relâché
    // par on_celebration_end, à la fin de l'interlude.
    // gage / showRevive sont figés ici : show_gameover est tiré par la conf et ne reçoit aucun argument.
    Future<void> _celebrateDeath(String gage, bool showRevive) async {

                                if (_deathChecking) return;                    // une seule animation à la fois
                                _deathChecking   = true;
                                _deathGage       = gage;
                                _deathShowRevive = showRevive;
                                ActionRegistry.get("dvinterlude.play.gameover")?.call(null, null);
    }

    // --- Overlay de mort, posé/retiré AU BON ACTE d'un interlude (tirés par la conf des scènes) ------
    // Les deux sont gardées par le drapeau de leur célébration : sur le banc de test (burn_page), où
    // l'on rejoue les interludes sans être mort ni soigné, elles ne doivent RIEN toucher.

    // Le voile blanc du soin recouvre tout l'écran : on retire le crâne dessous.
    Future<void> hide_skull(dynamic caller, dynamic event) async {

                                if (!_healChecking) return;
                                await _applyDeath(false, "", persist: true, showRevive: false);
    }

    // L'écran est devenu noir : on pose le splash « GAME OVER » et le crâne, sous le noir.
    Future<void> show_gameover(dynamic caller, dynamic event) async {

                                if (!_deathChecking) return;
                                ActionRegistry.get("dvorb.splash.commons/gameover_label")?.call(null, "GAME OVER");
                                await _applyDeath(true, _deathGage, persist: true, showRevive: _deathShowRevive);
    }

    // Fin de l'interlude de mort ou de soin : on relâche SON garde. Tirée par le `on_finished` de
    // l'INTERLUDE (déclaré dans le thème) et non par celui de la scène : dvinterlude le tire dans TOUS
    // les cas — fin normale, garde-fou (scène jamais terminée), ou préemption par un autre interlude.
    // Sans ça, une célébration fantôme laisserait le worker bloqué pour toujours.
    // On relâche le garde de l'interlude NOMMÉ (dvinterlude passe son identifiant en event), jamais les
    // deux : quand la mort préempte un soin resté en l'air, la fin du soin ne doit pas relâcher le garde
    // que la mort vient tout juste de poser — le crâne ne s'afficherait alors jamais.
    // `levelup` ne porte aucun garde : il ne fait qu'ouvrir le tutoriel derrière la bienvenue clan,
    // quand il y en a une (une vraie montée de niveau tire le même hook et ne trouve rien à relayer).
    Future<void> on_celebration_end(dynamic caller, dynamic event) async {

                                final id = event?.toString() ?? "";
                                if (id == "heal")     _healChecking  = false;
                                if (id == "gameover") _deathChecking = false;
                                if (id == "butin")    _butinChecking = false;
                                // La bienvenue clan vient de s'éteindre : c'est L'INSTANT du tutoriel du
                                // dashboard. On ne l'attend plus depuis on_dashboard_appear — le voici tiré par
                                // la fin de l'animation elle-même. Volontairement PAS attendu : ce hook est
                                // awaité par dvinterlude.finished(), et une leçon dure le temps que
                                // l'utilisateur veut.
                                if (id == "levelup" && _welcomeTuto) {
                                    _welcomeTuto = false;
                                    _enterTutoAfterWelcome();
                                }
    }

    // Ouvre le tutoriel derrière la bienvenue clan. Tiré par la fin de l'interlude — donc dans TOUS
    // les cas : fin normale, garde-fou (scène jamais terminée) ou préemption par une autre
    // célébration. Ce dernier cas est justement celui qui faisait tout rater : dvinterlude notifie la
    // fin du préempté AVANT de reposer `interludes.playing` pour le nouveau, et `dvtuto.enter`
    // renonce sans un mot quand un interlude joue. D'où la respiration puis le drainage : on ne rend
    // la main à la leçon qu'une fois l'écran vraiment libre.
    Future<void> _enterTutoAfterWelcome() async {

                                await Future.delayed(const Duration(milliseconds: 300));
                                await _waitInterludesIdle();
                                deva_log("info", "[tuto] fin de bienvenue → dvtuto.enter (seen.dashboard_intro="
                                    "${await deva_get("dvtuto.seen.dashboard_intro", false)})");
                                await deva_do("dvtuto.enter");
    }

    // Déclare la musique de fond correspondant à l'état de vie : le mort a la sienne.
    // dvsound la joue tout de suite si la musique tourne — et la MÉMORISE si elle est suspendue (un
    // interlude en cours) pour la lancer à la reprise. C'est ce qui permet de basculer l'ambiance au
    // moment exact où l'on détecte la mort, sans que dvinterlude ait à savoir ce qu'est un mort.
    Future<void> _setAmbiance(bool dead) async {

                                final playlist = dead ? "ambiant_dead" : "ambiant";
                                ActionRegistry.get("dvsound.ambiance.$playlist")?.call(null, null);
    }

    // Bienvenue clan (1re arrivée sur dashboard après création/rejoint) : même interlude que la montée de
    // niveau (scène "burn", même son, même DvSplash) — elle en hérite donc de tout : le son qui l'annonce,
    // l'écran confisqué, la musique coupée puis rendue.
    // Texte résolu dans la langue COURANTE depuis les clés created_clan_splash / joined_clan_splash (repli
    // fr), avec substitution du token @@@session.clan.name@@@ par le nom du clan mis en surbrillance ([[ ]]
    // → rouge/gras via highlight_color de commons/levelup_label).
    // Renvoie false si dvinterlude n'est pas dans ce build : rien ne jouera, donc rien ne viendra
    // notifier la fin — et le tutoriel, qui attend derrière, doit alors être ouvert sur-le-champ.
    Future<bool> _showClanWelcomeAnimation(bool created) async {

                                final play = ActionRegistry.get("dvinterlude.play.levelup");
                                if (play == null) {
                                    deva_log("warning", "[welcome] dvinterlude absent : pas d'animation de bienvenue");
                                    return false;
                                }

                                final lang = TranslationRegistry.currentLang;
                                Future<String> tr(String key) async {
                                    var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                                    if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                                    return v;
                                }

                                final key  = created ? "created_clan_splash" : "joined_clan_splash";
                                final name = (await Deva.instance.get("session.clan.name"))?.toString() ?? "";
                                var text   = await tr(key);
                                text = text.replaceAll("@@@session.clan.name@@@", "[[$name]]");

                                play(null, {"text": text});
                                return true;
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
