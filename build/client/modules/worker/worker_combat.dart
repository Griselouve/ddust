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
// --- worker extension — Écran Combat
// -----------------------------------------------------------------------------
extension Worker_combat on worker {

    void _register_combat() {

                                ActionRegistry.register("worker.on_combat_appear",          on_combat_appear);

                                ActionRegistry.register("worker.on_combat_ok",              on_combat_ok);

                                ActionRegistry.register("worker.on_combat_cancel",          on_combat_cancel);

                                ActionRegistry.register("worker.on_leave_combat_tab",       on_leave_combat_tab);

                                ActionRegistry.register("worker.on_combat_proof",           on_combat_proof);

    }

    Future<void> on_combat_appear(dynamic caller, dynamic event) async {

                                final activeTask  = (await Deva.instance.get("session.active_task"))?.toString()  ?? "";
                                final activeProof = (await Deva.instance.get("session.active_proof"))?.toString() ?? "";
                                // wait_for_shape sur le tiroir (créé APRÈS l'icône dans le registry) : sinon
                                // get_shape_by_id renverrait null au moment de l'appear et le tiroir resterait visible.
                                final icon      = await DvOrb.wait_for_shape("combat/icon");
                                final icon_bg   = await DvOrb.wait_for_shape("combat/icon_bg");
                                final label     = await DvOrb.wait_for_shape("combat/icon_label");
                                final encourage = await DvOrb.wait_for_shape("combat/encourage");
                                final difficulty = await DvOrb.wait_for_shape("combat/difficulty");
                                final okBtn     = await DvOrb.wait_for_shape("combat/ok");
                                final cancelBtn = await DvOrb.wait_for_shape("combat/cancel");
                                final proofBtn  = await DvOrb.wait_for_shape("combat/proof");
                                final valOkBtn  = await DvOrb.wait_for_shape("combat/validate_ok");
                                final valPartBtn = await DvOrb.wait_for_shape("combat/validate_partial");
                                final valKoBtn  = await DvOrb.wait_for_shape("combat/validate_ko");
                                final tiroir    = await DvOrb.wait_for_shape("combat/tiroir");

                                void setVisible(dynamic shape, bool v) { shape?.set("shape.visible", v); shape?.refreshUI(); }

                                deva_log("info", "[combat] appear active='$activeTask' proof='$activeProof' "
                                    "icon=${icon != null} label=${label != null} encourage=${encourage != null} "
                                    "ok=${okBtn != null} cancel=${cancelBtn != null} proof=${proofBtn != null} tiroir=${tiroir != null}");

                                // MODE REVUE (admin) : une tâche en validation a été sélectionnée. Prioritaire sur
                                // active_task. Affiche icône/label/acceptance/difficulté + les 2 boutons verdict.
                                // La preuve photo n'est JAMAIS affichée (elle reste locale sur l'appareil du joueur).
                                final reviewTask = (await Deva.instance.get("session.review_task"))?.toString() ?? "";

                                // Le switch « Jeu | Admin » suit la visibilité du tiroir : posé ici, AVANT le
                                // branchement, il couvre les 3 états (revue / tâche active / tiroir seul) —
                                // les branches revue et tâche active font un return sans repasser par
                                // _refreshTaskStatuses → _syncChiefUi. La condition lit active_task/review_task.
                                await _syncChiefUi();

                                if (reviewTask.isNotEmpty) {
                                    final rClanId = (await Deva.instance.get("session.clan.id"))?.toString() ?? "";
                                    final rTaskId = _taskIdFromActive(reviewTask, rClanId);
                                    final rTask   = await deva_get("tasks.$rTaskId");
                                    final rEffRaw = rTask is Dvidle ? rTask.get("effort") : null;
                                    final rEffort = rEffRaw == null ? 0 : (int.tryParse(rEffRaw.toString()) ?? 0);
                                    deva_log("info", "[combat] mode revue taskId='$rTaskId'");

                                    setVisible(tiroir, false);
                                    setVisible(icon_bg, true);
                                    setVisible(icon, true);
                                    setVisible(label, true);
                                    setVisible(encourage, true);
                                    setVisible(difficulty, true);
                                    setVisible(okBtn, false);
                                    setVisible(cancelBtn, false);
                                    setVisible(proofBtn, false);
                                    setVisible(valOkBtn, true);
                                    setVisible(valPartBtn, true);
                                    setVisible(valKoBtn, true);

                                    icon?.set("shape.image", await _taskIconPath(rTaskId));
                                    try { await icon?.appear(); } catch (e) { deva_log("warning", "[combat] icon appear: $e"); }
                                    icon?.refreshUI();
                                    if (label is DvLabel)      label.write(_taskLabel(rTaskId));
                                    if (encourage is DvLabel)  encourage.write(_taskAcceptance(rTaskId));
                                    // Tâche recommandée : la fourchette (et non l'XP de base) — l'admin qui
                                    // juge voit ce que le joueur avait devant lui en se lançant. Écrêtée au
                                    // plafond de l'ASSIGNEE (pas celui de l'admin) pour la même raison.
                                    final rRec = (await deva_get("tasks.$rTaskId.recommended"))?.toString() ?? "";
                                    final rWho = rTask is Dvidle ? (rTask.get("assignee")?.toString() ?? "") : "";
                                    final rCap = await _readPlayerMaxXp(rWho);
                                    if (difficulty is DvLabel) {
                                        difficulty.write(_taskDifficultyRange(rEffort, getTaskXPs(rTask), rRec, cap: rCap));
                                    }
                                    _stopCombatSiege();   // mode revue admin : pas de mur de flammes ni de son
                                    caller?.refreshUI();
                                    // Tuto déclenché ICI et pas dans la liste `appear` de la conf : l'état est
                                    // tranché, les `requires` des leçons (session.active_task vide / non vide)
                                    // sont donc évalués sur l'écran réellement affiché. Une des 4 branches de
                                    // ce handler, et une seule, appelle dvtuto.enter (patron on_tiroir_appear).
                                    await deva_do("dvtuto.enter");
                                    return;
                                }

                                // État 1 : aucune tâche active → tiroir seul. On rafraîchit les statuts (overlays
                                // flamme/crâne) car il n'y a pas de sync temps réel entre joueurs.
                                if (activeTask.isEmpty) {
                                    setVisible(tiroir, true);
                                    setVisible(icon, false);
                                    setVisible(icon_bg, false);
                                    setVisible(label, false);
                                    setVisible(encourage, false);
                                    setVisible(difficulty, false);
                                    setVisible(okBtn, false);
                                    setVisible(cancelBtn, false);
                                    setVisible(proofBtn, false);
                                    setVisible(valOkBtn, false);
                                    setVisible(valPartBtn, false);
                                    setVisible(valKoBtn, false);
                                    _stopCombatSiege();   // tiroir seul (aucune tâche active) : pas de combat
                                    await _refreshTaskStatuses();
                                    await deva_do("dvtuto.enter");   // état tranché = tiroir → leçon « domaines »
                                    return;
                                }

                                final clanId = (await Deva.instance.get("session.clan.id"))?.toString() ?? "";
                                final taskId = _taskIdFromActive(activeTask, clanId);
                                // Une preuve déjà prise (uuid restauré par dvsession) ⇒ tâche en "validating".
                                var validating = activeProof.isNotEmpty;

                                // Sélection locale immédiate : on saute la réconciliation (l'assignation Firestore
                                // n'est pas encore propagée → un read renverrait "alive" et viderait la tâche à tort).
                                // Le marqueur est consommé : les appears suivants (retour sur combat, reprise) réconcilient.
                                final freshlySelected = _freshlySelected == activeTask;
                                _freshlySelected = "";

                                // Réconciliation côté joueur (pas de sync temps réel) : on lit le statut autoritaire
                                // de la tâche pour réagir à un verdict admin pris sur un autre appareil.
                                // try/catch OBLIGATOIRE depuis que la page naît vide : hors ligne, le read levait et
                                // l'exception sortait du handler (le dispatcher d'actions de DvShape n'awaite pas la
                                // séquence, son try/catch ne rattrape donc pas une erreur asynchrone) → plus aucune
                                // visibilité n'était posée, écran combat vide sans porte de sortie. En cas d'échec on
                                // ne réconcilie pas : on retombe sur l'état connu de la session (tâche en cours), que
                                // le prochain appear réconciliera.
                                if (!freshlySelected) {
                                    try {
                                        final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                        final userDoc    = await _readSession(region) ?? Dvidle({});
                                        var   clanIdR    = userDoc.get("steps.clan.clanId")?.toString()     ?? "";
                                        final clanSecret = userDoc.get("steps.clan.clanSecret")?.toString() ?? "";
                                        if (clanIdR.isEmpty) clanIdR = clanId;
                                        if (clanSecret.isNotEmpty && clanIdR.isNotEmpty) {
                                            final doc = await _cloud?.read("workers", "clans_tasks/$clanIdR/tasks", taskId,
                                                region: region, ownerId: clanSecret);
                                            final st  = doc?.get("status")?.toString()   ?? "";
                                            final who = doc?.get("assignee")?.toString() ?? "";
    
                                            // (a) REFUSÉ : repassée "assigned", toujours à moi, j'ai une preuve locale →
                                            //     on abandonne la preuve pour permettre de recommencer (état assigned).
                                            if (st == "assigned" && who == _userId && activeProof.isNotEmpty) {
                                                deva_log("info", "[combat] verdict admin = refus → preuve abandonnée: $taskId");
                                                _stopValidationPolling();     // combat ouvert → réconcilié ici (cond. d'arrêt #3)
                                                await _forgetProof(activeProof);   // abandonnée = plus jamais atteignable → le fichier part
                                                userDoc.rem("docId");
                                                userDoc.set("active_proof", "");
                                                await _cloud?.write("workers", "users", _sessionDocId(), userDoc, region: region);
                                                _invalidateSessionCache();
                                                await Deva.instance.set("session.active_proof", "");
                                                validating = false;
                                            }
    
                                            // (b) ACCEPTÉ (dead/alive) ou tâche reprise (assignee != moi) ou disparue →
                                            //     on vide active_task/active_proof et on retourne au tiroir.
                                            final accepted  = st == "dead" || st == "alive";
                                            final takenAway = who != _userId && st.isNotEmpty;
                                            if (accepted || takenAway || st.isEmpty) {
                                                deva_log("info", "[combat] tâche n'est plus active (status=$st assignee=$who) → tiroir: $taskId");
                                                _stopValidationPolling();     // combat ouvert → réconcilié ici (cond. d'arrêt #3)
                                                await _forgetProof(activeProof);   // tâche résolue : la preuve a fini sa vie utile
                                                userDoc.rem("docId");
                                                userDoc.set("active_task",  "");
                                                userDoc.set("active_proof", "");
                                                await _cloud?.write("workers", "users", _sessionDocId(), userDoc, region: region);
                                                _invalidateSessionCache();
                                                await Deva.instance.set("session.active_task",  "");
                                                await Deva.instance.set("session.active_proof", "");
                                                setVisible(tiroir, true);
                                                setVisible(icon, false);
                                                setVisible(icon_bg, false);
                                                setVisible(label, false);
                                                setVisible(encourage, false);
                                                setVisible(difficulty, false);
                                                setVisible(okBtn, false);
                                                setVisible(cancelBtn, false);
                                                setVisible(proofBtn, false);
                                                setVisible(valOkBtn, false);
                                                setVisible(valPartBtn, false);
                                                setVisible(valKoBtn, false);
                                                _stopCombatSiege();   // verdict admin distant → retour tiroir : plus de combat
                                                await _refreshTaskStatuses(force: true);
                                                // Tuto AVANT la célébration : l'affichage (tiroir) est déjà tranché,
                                                // alors que _celebrateAfterAccept peut attendre l'XP jusqu'à ~10 s.
                                                await deva_do("dvtuto.enter");
                                                // Verdict ACCEPTÉ réconcilié ici (app rouverte / réveil : ni watch ni
                                                // notif n'ont célébré) → célébration + consommation boss. PAS pour une
                                                // tâche reprise par un autre (takenAway) ni disparue.
                                                if (accepted) {
                                                    await _celebrateAfterAccept(clanIdR, clanSecret, region);
                                                }
                                                return;
                                            }
                                        }
                                    } catch (e) {
                                        deva_log("warning", "[combat] réconciliation impossible ($e) → affichage de l'état de session");
                                    }
                                }
                                // Tâche complète (couche tasks-base) → effort + XP. Effort absent → pas de badge.
                                final task      = await deva_get("tasks.$taskId");
                                final effortRaw = task is Dvidle ? task.get("effort") : null;
                                final effort    = effortRaw == null ? 0 : (int.tryParse(effortRaw.toString()) ?? 0);
                                final iconPath = await _taskIconPath(taskId);
                                deva_log("info", "[combat] taskId='$taskId' validating=$validating "
                                    "icon='$iconPath' label='${_taskLabel(taskId)}'");

                                // 1) On règle TOUTES les visibilités d'abord, pour que rien ne dépende du succès
                                //    de icon.appear() (résolution d'asset) qui peut lever et interrompre la suite.
                                setVisible(tiroir, false);
                                setVisible(icon_bg, true);
                                setVisible(icon, true);
                                setVisible(label, true);
                                setVisible(encourage, true);
                                setVisible(difficulty, true);
                                // État 2 (assigned) : ok + cancel. État 3 (validating) : proof seul,
                                // sauf preuve zappée (sentinelle _kNoProof) où il n'y a rien à montrer.
                                setVisible(okBtn, !validating);
                                setVisible(cancelBtn, !validating);
                                setVisible(proofBtn, validating && activeProof != _kNoProof);
                                setVisible(valOkBtn, false);
                                setVisible(valPartBtn, false);
                                setVisible(valKoBtn, false);

                                // Combat en cours (état assigned = boutons vaincu/retraite) → mur de flammes sur la
                                // frontière taskbar + son en boucle. État validating (« Voir ma preuve ») → rien.
                                if (!validating) { _startCombatSiege(); } else { _stopCombatSiege(); }

                                // 2) Contenu dynamique (image + légende), isolé des erreurs d'asset.
                                icon?.set("shape.image", iconPath);
                                try { await icon?.appear(); } catch (e) { deva_log("warning", "[combat] icon appear: $e"); }
                                icon?.refreshUI();
                                if (label is DvLabel) label.write(_taskLabel(taskId));
                                // Sous l'icône : critères d'acceptance de la tâche (au lieu du message
                                // d'encouragement statique). Pertinent dans les deux états (assigned + validating).
                                if (encourage is DvLabel) encourage.write(_taskAcceptance(taskId));
                                // Badge difficulté (coin sup. droit du cadre, en rouge) : effort traduit + XP.
                                // Sur une tâche recommandée, la FOURCHETTE de gain possible : elle dit à la
                                // fois que la tâche rapporte gros et qu'elle rapporte moins si l'on traîne.
                                // Écrêté au plafond du joueur : le badge ne promet jamais plus que ce que
                                // _creditXp versera (cf. _taskDifficultyRange).
                                final rec      = (await deva_get("tasks.$taskId.recommended"))?.toString() ?? "";
                                final myCap    = await _readPlayerMaxXp(_userId);
                                final diffText = _taskDifficultyRange(effort, getTaskXPs(task), rec, cap: myCap);
                                if (difficulty is DvLabel) difficulty.write(diffText);
                                // Rafraîchit la PAGE (pas seulement les shapes) pour qu'elle re-balaye ses
                                // calques et peigne les shapes rendues visibles à l'appear.
                                caller?.refreshUI();
                                await deva_do("dvtuto.enter");   // état tranché = tâche en cours → leçon « combat_active »
    }

    // Bouton "J'ai vaincu le monstre !".
    //  - Joueur ADMIN de son clan : auto-validation immédiate (pas de photo ni de validation par
    //    un tiers) → verdict "accepté" écrit directement, XP crédité, retour au tiroir.
    //  - Joueur non-admin : prise de photo (preuve) → tâche en validation (flux historique).
    Future<void> on_combat_ok(DvShape? caller, dynamic event) async {

                                _stopCombatSiege();   // "J'ai vaincu le monstre" → mur de flammes + son coupés
                                final activeTask = (await Deva.instance.get("session.active_task"))?.toString() ?? "";
                                if (activeTask.isEmpty) return;

                                // 1) Contexte clan/region pour la persistance Firestore (résolu AVANT toute photo :
                                //    il détermine aussi si l'utilisateur est admin et peut auto-valider).
                                final ownerId = _cloud?.currentUser()?.providerUid ?? "";
                                if (_userId.isEmpty || ownerId.isEmpty) {
                                    deva_log("error", "[combat] on_combat_ok: contexte incomplet (user=$_userId owner=$ownerId)");
                                    return;
                                }
                                final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                final userDoc    = await _readSession(region) ?? Dvidle({});
                                var   clanId     = userDoc.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = userDoc.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty) clanId = (await Deva.instance.get("session.clan.id"))?.toString() ?? "";
                                final taskId = _taskIdFromActive(activeTask, clanId);

                                // 2) ADMIN SOLO : auto-validation (pas de caméra, pas de polling). On rejoue le verdict
                                //    "accepté" sur sa propre tâche (assignee = _userId) — sans notification, puisque
                                //    le joueur EST l'admin et voit le résultat immédiatement. Réservé à l'admin UNIQUE
                                //    du clan : dès qu'il y a un 2e admin (_adminCount > 1), on retombe dans le flux
                                //    lambda (photo → validating → notif aux autres admins → polling) pour imposer une
                                //    validation croisée.
                                if (clanId.isNotEmpty && clanSecret.isNotEmpty
                                    && await _ensureIsAdmin(clanId, clanSecret, region)
                                    && _adminCount <= 1) {

                                    // XP calculé AVANT _writeVerdict (proportionnalité = dead/revive du cycle
                                    // précédent, que la validation va réécrire). Identique à _handleVerdict.
                                    final task = await deva_get("tasks.$taskId");
                                    final xp   = getTaskXPs(task is Dvidle ? task : null);
                                    // Tâche « boss » : l'admin solo peut aussi finir sa propre tâche recommandée.
                                    // On lit recommended FRAIS et on réamorce le miroir (préservation _writeVerdict),
                                    // puis on booste l'XP — bonus compris dans la part du clan. bossTaskId → last_task_boss.
                                    final rec = await _readTaskRecommended(clanId, clanSecret, region, taskId);
                                    await deva_set("tasks.$taskId.recommended", rec);
                                    final boostedXp  = _bossPlayerXp(xp, rec, taskId: taskId);
                                    final bossTaskId = rec.isNotEmpty ? taskId : "";
                                    await _writeVerdict(clanId, clanSecret, taskId, region, true, false, _userId);
                                    // L'admin finit sa propre tâche (auto-validation) = son moment de finish → last_task.
                                    // xp + last_task en UNE écriture (via _creditXp) → le watch joueur voit une
                                    // tâche accomplie (VICTOIRE) sans course. Tâche à 0 XP : _creditXp ne fait rien,
                                    // on pose quand même last_task pour recaler la dégradation.
                                    final nowIso = DateTime.now().toUtc().toIso8601String();
                                    // XP RÉELLEMENT créditée = celle que _creditXp renvoie, écrêtée au plafond du
                                    // joueur (clans_players.max_xp). C'est elle — et non l'XP boostée brute — qui
                                    // alimente la part du clan et le journal.
                                    var playerXp = 0;
                                    if (xp > 0) {
                                        playerXp = await _creditXp(clanId, clanSecret, region, _userId, boostedXp,
                                                        lastTaskWhen: nowIso, bossTaskId: bossTaskId);
                                        await _creditClanXp(clanId, clanSecret, region, playerXp);   // CLAN = part de l'XP RÉELLE (bonus boss compris, plafond appliqué)
                                    } else {
                                        await _touchLastTask(clanId, clanSecret, region, _userId, nowIso);
                                    }

                                    // Journal : l'admin a fait ET validé sa propre tâche en un coup.
                                    final selfName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "TaskDone",
                                        userId: _userId, task: taskId, slug: taskId,
                                        data: Dvidle({"taskId": taskId,
                                                      "playerId": _userId, "playerName": selfName}));
                                    // `xp` = ce qui a été RÉELLEMENT crédité (boosté si tâche recommandée,
                                    // écrêté au plafond du joueur), comme dans _applyVerdict ;
                                    // `xp_base` = le gain sans bonus ni plafond (audit).
                                    await _writeClanLog(clanId, clanSecret, region, "TaskValidatedOk",
                                        userId: _userId, adminId: _userId, task: taskId, slug: taskId,
                                        data: Dvidle({"taskId": taskId, "assigneeId": _userId,
                                                      "assigneeName": selfName, "adminId": _userId,
                                                      "adminName": selfName, "verdict": "ok",
                                                      "xp": playerXp, "xp_base": xp,
                                                      "boss": bossTaskId.isNotEmpty}));

                                    // RELANCE DE CONVERSION, SECOND SITE — et il est indispensable.
                                    // L'admin solo n'appelle JAMAIS _applyVerdict : il inline son propre
                                    // verdict, juste au-dessus. Un compteur posé là-bas seulement ne
                                    // verrait donc jamais un clan à un seul chef, c'est-à-dire exactement
                                    // la population que cette relance vise — un foyer d'un parent et un
                                    // enfant ne rencontre jamais le plafond de joueurs, la deuxième tâche
                                    // validée est la seule porte qui lui reste.
                                    await _storeCountValidation(clanId, clanSecret, region);

                                    // Libération de l'état actif (même nettoyage que _resolveValidation accepté).
                                    // L'admin solo ne capture pas de photo (la capture est l'étape 3, non-admins
                                    // seulement) : l'effacement est défensif, comme le vidage d'active_proof
                                    // juste en dessous — il rattrape une preuve héritée d'un flux antérieur.
                                    await _forgetProof((await Deva.instance.get("session.active_proof"))?.toString() ?? "");
                                    userDoc.rem("docId");
                                    userDoc.set("active_task",  "");
                                    userDoc.set("active_proof", "");
                                    await _cloud?.write("workers", "users", _sessionDocId(), userDoc, region: region);
                                    _invalidateSessionCache();
                                    await Deva.instance.set("session.active_task",  "");
                                    await Deva.instance.set("session.active_proof", "");

                                    deva_log("info", "[combat] auto-validation admin: $taskId (xp=$xp)");
                                    DvOrb.navigate_reset("combat");        // appear voit active_task vide → tiroir
                                    // Crédit XP local (même device) → le poll voit l'XP dès la 1re itération :
                                    // célébration (victoire / coup de pouce) + consommation boss aussi pour l'admin solo.
                                    await _celebrateAfterAccept(clanId, clanSecret, region);
                                    return;
                                }

                                // 3) Non-admin : capture photo via le module dvcamera (caméra OS, stockage local
                                //    sous uuid). Trois issues :
                                //    - cancelled   : l'utilisateur a annulé → on ne change rien.
                                //    - captured    : preuve prise → validation avec photo (flux historique).
                                //    - unavailable : caméra indispo (desktop/pas de caméra/permission refusée)
                                //                    OU module absent (_camera null) → preuve zappée, la tâche
                                //                    part quand même en validation (proof vide, sentinelle locale).
                                final result = await _camera?.capture();
                                final status = result?.status ?? DvCaptureStatus.unavailable;
                                if (status == DvCaptureStatus.cancelled) return;
                                final withProof = status == DvCaptureStatus.captured;
                                final uuid      = withProof ? result!.uuid! : _kNoProof;

                                // 4) Tâche → validating (+ proof, last=now) dans clans_tasks. Preuve zappée →
                                //    proof vide côté Firestore (l'admin n'affiche de toute façon jamais la photo).
                                if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                    await _validateTask(clanId, clanSecret, taskId, withProof ? uuid : "", region);
                                    // Journal : l'utilisateur a terminé la tâche (part en validation admin).
                                    final playerName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "TaskDone",
                                        userId: _userId, task: taskId, slug: taskId,
                                        data: Dvidle({"taskId": taskId, "playerId": _userId,
                                                      "playerName": playerName, "proof": withProof,
                                                      "status": "validating"}));
                                    // Prévenir les admins du clan (notif à 3 boutons) qu'une validation est demandée.
                                    final requesterName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _notifyAdmins(clanId, clanSecret, region, taskId, _userId,
                                        requesterName.isNotEmpty ? requesterName : "Un joueur");
                                    // Le verdict admin n'est pas synchronisé en temps réel → on poll Firestore
                                    // (backoff Fibonacci) jusqu'à ce que la tâche ne soit plus "validating".
                                    _startValidationPolling(clanId, clanSecret, region, taskId);
                                } else {
                                    deva_log("warning", "[combat] on_combat_ok: clanId/clanSecret introuvable, clans_tasks non mis à jour");
                                }

                                // 5) UUID de la preuve sur le doc user → restauré par dvsession au redémarrage.
                                userDoc.rem("docId");
                                userDoc.set("active_proof", uuid);
                                await _cloud?.write("workers", "users", _sessionDocId(), userDoc, region: region);
                                _invalidateSessionCache();
                                await Deva.instance.set("session.active_proof", uuid);

                                // 6) Échange des boutons : ok/cancel masqués. "Voir ma preuve" affiché
                                //    seulement si une photo existe (pas dans le cas preuve zappée).
                                final okBtn     = await DvOrb.wait_for_shape("combat/ok");
                                final cancelBtn = await DvOrb.wait_for_shape("combat/cancel");
                                final proofBtn  = await DvOrb.wait_for_shape("combat/proof");
                                void setVisible(dynamic shape, bool v) { shape?.set("shape.visible", v); shape?.refreshUI(); }
                                setVisible(okBtn, false);
                                setVisible(cancelBtn, false);
                                setVisible(proofBtn, withProof);
    }

    // Bouton "Voir ma preuve" : réaffiche la photo prise (uuid géré par dvsession).
    Future<void> on_combat_proof(DvShape? caller, dynamic event) async {

                                final uuid = (await Deva.instance.get("session.active_proof"))?.toString() ?? "";
                                if (uuid.isEmpty) { deva_log("warning", "[combat] proof: aucun uuid"); return; }
                                // Preuve zappée (caméra indispo) : rien à afficher (bouton déjà masqué).
                                if (uuid == _kNoProof) { deva_log("info", "[combat] proof: preuve zappée, rien à montrer"); return; }
                                await _camera?.show(uuid);
    }

    // --- Cycle de vie du FICHIER de preuve ------------------------------------------------
    // La photo vit sur l'appareil de celui qui l'a prise ; le verdict est écrit par l'appareil
    // qui TRANCHE. Un effacement « au verdict » n'atteint donc pas le fichier quand l'admin
    // décide à distance. Les deux helpers ci-dessous sont un couple, pas un doublon :
    //  - _forgetProof     : immédiat, sur l'appareil du joueur, partout où la preuve est
    //                       abandonnée. Rend la photo inaccessible dans la seconde, quand on
    //                       est là pour le faire.
    //  - _reconcileProofs : au démarrage, autoritaire. Tout fichier qui n'est pas la preuve
    //                       ENCORE référencée par la session est un orphelin, quelle qu'en
    //                       soit la cause. C'est le mécanisme principal — c'est lui qui rend
    //                       l'effacement immédiat tolérant à l'échec, et non l'inverse.

    // Efface le fichier d'une preuve abandonnée. UUID vide ou sentinelle _kNoProof (preuve
    // zappée, caméra indisponible) → rien à faire. Ne lève jamais : un effacement raté n'a pas
    // à faire échouer le geste métier qui l'a déclenché, la réconciliation repassera.
    Future<void> _forgetProof(String uuid) async {

                                if (uuid.isEmpty || uuid == _kNoProof) return;
                                await _camera?.delete(uuid);
    }

    // Démarrage (et sorties définitives) : ne garder que la preuve encore référencée. Rattrape
    // tous les orphelinages hors de portée de l'effacement immédiat — app tuée pendant le
    // verdict, verdict rendu à distance app fermée, joueur révoqué, compte supprimé depuis le
    // web puis app rouverte.
    // ⚠ Le répertoire appartient à l'APPLICATION, pas au joueur : sur un appareil partagé, la
    // preuve en attente d'un AUTRE compte est effacée à la connexion suivante. Conséquence
    // assumée et bénigne — le fichier ne sert qu'à SE re-montrer sa propre photo (l'adulte qui
    // juge ne la voit jamais), et « Voir ma preuve » reste alors sans effet plutôt que de casser.
    Future<void> _reconcileProofs(String keepUuid) async {

                                final keep = <String>{};
                                if (keepUuid.isNotEmpty && keepUuid != _kNoProof) keep.add(keepUuid);
                                await _camera?.purge(keep);
    }

    // Bouton "Retraite !" : abandon de la tâche → retour à l'état initial (tiroir).
    Future<void> on_combat_cancel(DvShape? caller, dynamic event) async {

                                _stopCombatSiege();                       // "Retraite" → mur de flammes + son coupés
                                _stopValidationPolling();                 // tâche abandonnée → plus de poll
                                final activeTask = (await Deva.instance.get("session.active_task"))?.toString() ?? "";
                                if (activeTask.isEmpty) { DvOrb.navigate_reset("combat"); return; }

                                final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                final userDoc    = await _readSession(region) ?? Dvidle({});
                                var   clanId     = userDoc.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = userDoc.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty) clanId = (await Deva.instance.get("session.clan.id"))?.toString() ?? "";
                                final taskId = _taskIdFromActive(activeTask, clanId);

                                // 1) Tâche → alive (assignee vide, last=now, proof retiré).
                                if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                    await _releaseTask(clanId, clanSecret, taskId, region);
                                } else {
                                    deva_log("warning", "[combat] on_combat_cancel: clanId/clanSecret introuvable, clans_tasks non mis à jour");
                                }

                                // 2) Vider active_task / active_proof sur le doc user (PATCH = remplacement complet),
                                //    et effacer le fichier de preuve : la retraite abandonne la tâche, la photo
                                //    ne sera plus jamais montrée à personne.
                                await _forgetProof((await Deva.instance.get("session.active_proof"))?.toString() ?? "");
                                userDoc.rem("docId");
                                userDoc.set("active_task",  "");
                                userDoc.set("active_proof", "");
                                await _cloud?.write("workers", "users", _sessionDocId(), userDoc, region: region);
                                _invalidateSessionCache();

                                // 3) Vider tout l'état local référençant la tâche.
                                await Deva.instance.set("session.active_task",  "");
                                await Deva.instance.set("session.active_proof", "");

                                // 4) Retour au tiroir : combat se recrée, on_combat_appear voit active_task vide.
                                DvOrb.navigate_reset("combat");
    }

    // Célébration de soin, sur la transition mort → vivant (depuis _evaluateDeath ou resurrect_self),
    // en fire-and-forget. L'interlude "heal" fait tout le spectacle : il confisque l'écran, coupe la
    // musique, joue le son + la vibration du soin, et une demi-seconde plus tard lance le voile blanc,
    // qui part du centre AU-DESSUS du crâne encore affiché (layer:popup > overlay) et le masque.
    // Le crâne est retiré SOUS le blanc par worker.hide_skull — tiré par la FIN DE L'ACTE qui étale le
    // voile, pas après un délai en dur : quand le voile se dissipe, c'est la page qui paraît.
    // Ne reste ici que le métier : la garde de ré-entrance, et le texte.
    // Texte : healer connu → healed_by_anim (« Ouf {name}, tu viens d'être sauvé par {healer} ! ») ;
    // sinon healed_anim (repli générique). {name}/{healer} en surbrillance ([[ ]] → vert, repli fr).
    // Mur de flammes + son de combat : joués tant que les boutons "vaincu"/"retraite" sont
    // affichés (état assigned de l'écran combat). La scène `flamewall` (immortal) brûle sur la
    // frontière du dvtaskbar ; batte_swords tourne en boucle.
    //
    // Le son est (RE)CHARGÉ explicitement ici, puis bouclé dans le callback, plutôt que de compter
    // sur le seul préchargement (sound.preload) : au démarrage l'asset de la vague `high` n'est pas
    // encore en cache et le rappel de préchargement peut ne jamais aboutir. À l'entrée en combat
    // (bien après l'onboarding) l'asset est en cache → load() résout et loop() joue tout de suite.
    // Si l'asset arrive plus tard, le Future de load() se complète à ce moment → loop() suit.
    void _startCombatSiege() {

                                if (_combatSiegeOn) return;   // déjà en siège : ne pas re-suspendre l'ambiance ni re-boucler
                                _combatSiegeOn = true;
                                // Comme un interlude (music: cut) : on TAIT la musique de fond pendant le combat
                                // et on la RENDRA à la sortie (_stopCombatSiege). dvsound mémorise une éventuelle
                                // bascule d'ambiance survenue pendant la suspension (ex. mort → ambiant_dead).
                                ActionRegistry.get("dvsound.ambiance.pause")?.call(null, null);
                                ActionRegistry.get("dvflame.start.flamewall")?.call(null, null);
                                final snd = ModuleRegistry.create("dvsound");
                                if (snd == null) return;
                                try {
                                    // load()/loop() vivent sur la façade dvsound, pas sur DvBeing → dispatch dynamique.
                                    final f = (snd as dynamic).load("batte_swords", "sounds/batte_swords.mp3");
                                    if (f is Future) {
                                        f.then((_) { if (_combatSiegeOn) (snd as dynamic).loop("batte_swords"); });
                                    } else if (_combatSiegeOn) {
                                        (snd as dynamic).loop("batte_swords");
                                    }
                                } catch (e) {
                                    deva_log("warning", "[combat] son batte_swords: $e");
                                }
    }

    // Éteint le mur de flammes et coupe la boucle. Sûr à appeler en toute circonstance :
    // dvsound.stop est un no-op si rien ne joue, dvflame.stop sans effet hors de l'écran combat.
    // Le flag coupe aussi un chargement de son encore en vol (n'amorce pas la boucle après coup).
    void _stopCombatSiege() {

                                final wasOn = _combatSiegeOn;   // ne rend l'ambiance QUE si on sortait vraiment du combat
                                _combatSiegeOn = false;
                                ActionRegistry.get("dvsound.stop.batte_swords")?.call(null, null);
                                ActionRegistry.get("dvflame.stop.flamewall")?.call(null, null);
                                // Rend la musique de fond suspendue par _startCombatSiege. Gardé par wasOn : les
                                // appels « anti-fuite » des *_appear d'onglets (hors combat) ne doivent PAS relancer
                                // l'ambiance depuis sa 1re piste à chaque changement d'onglet.
                                if (wasOn) ActionRegistry.get("dvsound.ambiance.resume")?.call(null, null);
    }

    // Onglets placeholder (shop, testme) : quitter le combat vers eux doit couper le son ET rendre
    // l'ambiance, comme les autres onglets. Passe par _stopCombatSiege (gardé) au lieu du
    // dvsound.stop.batte_swords brut qui ne relançait jamais la musique de fond.
    Future<void> on_leave_combat_tab(dynamic caller, dynamic event) async {

                                _stopCombatSiege();
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
