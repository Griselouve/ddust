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
// --- worker extension — Vigilances dvcloud (validation, joueur)
// -----------------------------------------------------------------------------
extension Worker_watch on worker {

    // -----------------------------------------------------------------------
    // --- Vigilance de validation côté joueur (watch dvcloud, temps réel)
    // -----------------------------------------------------------------------

    // Démarre (ou redémarre) la vigilance d'une tâche en attente de validation.
    void _startValidationPolling(String clanId, String clanSecret, String region, String taskId) {

                                _stopValidationPolling();                 // unicité : une seule vigilance à la fois
                                if (clanId.isEmpty || clanSecret.isEmpty || taskId.isEmpty) return;
                                _validationTaskId = taskId;
                                deva_log("info", "[combat] vigilance validation démarrée: $taskId");
                                // watch ne notifie jamais la baseline : un verdict déjà rendu (ex. cold start
                                // après un kill) ne déclencherait pas `changed`. On vérifie donc une fois tout
                                // de suite, puis on installe la vigilance temps réel pour les changements suivants.
                                _pollValidationOnce(clanId, clanSecret, region, taskId).then((resolved) {
                                    if (resolved || _validationTaskId != taskId) return;  // déjà résolu, ou remplacé/arrêté
                                    _validationVigilance = _cloud?.watch("workers", "clans_tasks/$clanId/tasks", taskId,
                                        (doc, reason) {
                                            if (reason != DvWatchReason.changed) return;  // deleted/timeout : rien à résoudre
                                            final st  = doc?.get("status")?.toString()   ?? "";
                                            final who = doc?.get("assignee")?.toString() ?? "";
                                            if (st == "validating") return;               // toujours en attente
                                            deva_log("info", "[combat] watch: verdict détecté (status=$st) → résolution: $taskId");
                                            _resolveValidation(region, taskId, st, who, navigate: true);
                                        },
                                        region: region, ownerId: clanSecret,
                                        // desktop only ; ignoré sur Android. Plafond : un verdict qui
                                        // tarde ne doit pas faire dériver le poll vers l'heure.
                                        strategy: DvWatchStrategy.fibonacci(baseMs: 2000, maxMs: 15000));
                                });
    }

    // Arrête la vigilance : coupe le watch et invalide la course start/stop en cours.
    void _stopValidationPolling() {

                                _validationVigilance?.stop();
                                _validationVigilance = null;
                                _validationTaskId    = "";
    }

    // -----------------------------------------------------------------------
    // --- Vigilance de la fée (elle disparaît pour tout le monde d'un coup)
    // -----------------------------------------------------------------------
    //
    // La fée est UNE, partagée par le clan : dès que l'un la touche, elle doit s'effacer de
    // l'écran des autres. C'est le seul endroit du jeu où le retard se voit tout de suite — un
    // joueur qui tape une tuile déjà prise se heurte à un fantôme et ne comprend pas.
    //
    // Deux filets, parce qu'une fenêtre de dix minutes ne pardonne pas :
    //   - le WATCH sur le doc partagé, qui voit `taken_by` se remplir ;
    //   - une MINUTERIE locale sur `expires_at`, parce qu'aucun cron ne viendra clore la fenêtre
    //     (rien ne s'écrit à l'expiration : le doc reste avec `taken_by` vide, et c'est chaque
    //     appareil qui recompare l'heure).
    //
    // Armée seulement tant qu'une fenêtre est ouverte, et désarmée dès qu'elle se referme : une
    // vigilance qui tourne pour rien coûte des lectures (poll sur desktop) onze mois sur douze.
    void _startFairyVigilance(String clanId, String clanSecret, String region) {

                                _stopFairyVigilance();
                                if (clanId.isEmpty || clanSecret.isEmpty || !_fairyShowing) return;

                                deva_log("info", "[fairy] vigilance démarrée (jusqu'à $_fairyExpires)");
                                _fairyVigilance = _cloud?.watch("workers", "clans_items/$clanId/items",
                                    _fairyDocId,
                                    (doc, reason) {
                                        if (reason != DvWatchReason.changed || doc == null) return;
                                        final taken   = doc.get("taken_by")?.toString()   ?? "";
                                        final expires = doc.get("expires_at")?.toString() ?? "";
                                        // Prise par quelqu'un d'autre, ou fenêtre refermée : dans les deux cas
                                        // la tuile n'a plus lieu d'être. Prise par SOI : on est déjà sur
                                        // l'écran de la fée, la tuile a été retirée à la prise.
                                        if (taken.isNotEmpty || !_fairyWindowOpen(expires)) {
                                            deva_log("info", "[fairy] elle s'en va (prise par ${taken.isEmpty ? "personne" : taken})");
                                            _dropFairy();   // fire-and-forget : retire la tuile, rend la monstre-tâche
                                        }
                                    },
                                    region: region, ownerId: clanSecret,
                                    // desktop only ; ignoré sur Android (push natif). Plafond serré : dix
                                    // minutes de fenêtre ne laissent pas la place à un back-off d'une minute.
                                    strategy: DvWatchStrategy.fibonacci(baseMs: 2000, maxMs: 10000));

                                // Minuterie de fin de fenêtre. `isNegative` : une date déjà passée
                                // déclencherait un Timer de durée négative (immédiat) — on retire tout de suite.
                                final left = DateTime.tryParse(_fairyExpires)?.toUtc()
                                    .difference(DateTime.now().toUtc());
                                if (left == null || left.isNegative) { _dropFairy(); return; }
                                _fairyExpiryTimer = Timer(left + const Duration(seconds: 1), () {
                                    deva_log("info", "[fairy] les dix minutes sont écoulées");
                                    _dropFairy();
                                });
    }

    void _stopFairyVigilance() {

                                _fairyVigilance?.stop();
                                _fairyVigilance = null;
                                _fairyExpiryTimer?.cancel();
                                _fairyExpiryTimer = null;
    }

    // -----------------------------------------------------------------------
    // --- Vigilance du doc joueur (montée de niveau en temps réel)
    // -----------------------------------------------------------------------

    // Arme (ou ré-arme) la vigilance temps réel sur le doc membre du joueur courant. Idempotent :
    // si déjà active pour ce _userId, ne fait rien (évite les doublons quand plusieurs points
    // d'ancrage l'appellent). Chaque changement du doc (l'xp est créditée à distance) relance
    // _checkPlayerLevelUp, qui gère seul la détection et l'anti-double-fire (worker.player_last_xp).
    void _startPlayerVigilance(String clanId, String clanSecret, String region) {

                                if (_playerVigilance != null && _playerVigilanceUserId == _userId) return;
                                _stopPlayerVigilance();
                                if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return;
                                _playerVigilanceUserId = _userId;
                                deva_log("info", "[levelup] vigilance joueur démarrée: $_userId");
                                _playerVigilance = _cloud?.watch("workers", "clans_players/$clanId/players", _userId,
                                    (doc, reason) {
                                        if (reason != DvWatchReason.changed || doc == null) return;
                                        _onPlayerDocChanged();   // fire-and-forget : level-up + mort + soin (séquencés)
                                    },
                                    region: region, ownerId: clanSecret,
                                    // desktop only ; ignoré sur Android. Le plafond compte ici plus
                                    // qu'ailleurs : cette vigilance vit toute la session, et sans lui
                                    // la suite de Fibonacci l'endort jusqu'à ne plus relire qu'une
                                    // fois par heure — le joueur ne voyait plus rien arriver.
                                    strategy: DvWatchStrategy.fibonacci(baseMs: 3000, maxMs: 60000));
    }

    // Une part de butin ou un appel à la cérémonie DÉJÀ en attente au moment où l'on s'abonne
    // n'émet aucun changement : le watch ne les verrait jamais (la baseline est toujours avalée).
    // Cette relecture est le rattrapage — et le filet quand le push n'est pas passé et que la
    // vigilance dort. Elle est volontairement HORS de _startPlayerVigilance, dont la garde
    // d'idempotence sortait avant elle : elle ne se jouait donc qu'au tout premier armement.
    Future<void> _checkPendingCeremony() async {

                                if (await _checkPendingOpening()) return;   // le rituel passe devant
                                await _checkPendingButin();
    }

    // Réaction à un changement du doc joueur (watch temps réel OU visite dashboard/personnage) :
    // détecte d'abord la montée de niveau (prioritaire), puis ré-évalue la mort. _evaluateDeath bascule
    // l'overlay crâne/gage ET, sur une transition mort → vivant, déclenche l'animation de soin AU MÊME
    // instant que le retrait du crâne (elle EST la transition). Level-up PRIORITAIRE : si une montée a
    // été célébrée, on passe celebrateHeal=false → pas d'animation de soin (jamais deux à la fois).
    Future<void> _onPlayerDocChanged() async {

                                // Révocation prioritaire : si le joueur courant a été mis enabled=false (par un
                                // admin, possiblement depuis un autre appareil), on l'éjecte et on n'évalue rien d'autre.
                                if (await _checkRevoked()) return;
                                // Bascule légale (mineur → adulte) déclenchée par le tuteur : le doc porte
                                // legal_state="t" → on impose la CGU adulte bloquante et on n'évalue rien d'autre.
                                if (await _checkAdultTransition()) return;
                                // Appel du meneur à la cérémonie d'ouverture : il précède tout le reste,
                                // y compris la part de butin — c'est le rituel qui la produit, et personne
                                // ne doit voir ses pièces avant que le clan ne soit réuni.
                                if (await _checkPendingOpening()) return;
                                // Ouverture du butin : la plus grosse des célébrations passe devant, et
                                // seule. Sa part est réclamée (donc écrite) avant d'être montrée ; une
                                // montée de niveau survenue au même instant garde sa baseline intacte et
                                // sera célébrée au changement suivant, pas perdue.
                                if (await _checkPendingButin()) return;
                                // Cérémonie EN COURS (garde tenue de la réclamation jusqu'à la fin de
                                // l'interlude) : rien ne doit passer devant. Un interlude qui en préempte un
                                // autre COUPE son son (_silence) — une montée de niveau ou un soin détecté
                                // pendant les dix secondes de l'ouverture décapitait la musique du butin en
                                // plein spectacle. La célébration écartée n'est pas perdue : sa baseline reste
                                // intacte et elle sera jouée au changement suivant.
                                if (_butinChecking) return;
                                final leveled = await _checkPlayerLevelUp();
                                // Cadeau d'or : hausse du champ gold (célébré seulement si aucune autre anim déjà
                                // jouée ; la mémoire player_last_gold reste synchronisée même quand supprimé).
                                final golded = await _checkPlayerGoldGift(celebrate: !leveled);
                                // Promotion/rétrogradation chef : le miroir is_admin du doc joueur a changé.
                                // Resynchronise le rôle (cache + UI chef) dans les deux sens ; sur promotion,
                                // joue l'animation "burn" (comme un level-up) si aucune autre anim déjà jouée.
                                final promoted = await _checkChiefPromotion(celebrate: !(leveled || golded));
                                // Mort/soin : jamais deux animations à la fois → suppression du soin ET du game over
                                // si une célébration (level-up/or/chef) vient d'être jouée.
                                await _evaluateDeath(
                                    celebrateHeal: !(leveled || golded || promoted),
                                    celebrateDeath: !(leveled || golded || promoted));
    }

    // Coupe la vigilance joueur (logout / changement de contexte).
    void _stopPlayerVigilance() {

                                _playerVigilance?.stop();
                                _playerVigilance = null;
                                _playerVigilanceUserId = "";
    }

    // Point d'ancrage unique : résout region + clan depuis la session (même préambule que
    // _evaluateDeath), puis arme la vigilance. Appelé aux funnels où un joueur enrôlé atterrit
    // (on_dashboard_appear, on_clan_appear) ; sûr à appeler plusieurs fois grâce à l'idempotence
    // de _startPlayerVigilance.
    //
    // Le rattrapage, lui, se rejoue à CHAQUE passage, armement neuf ou pas : c'est la troisième
    // corde de la cérémonie du butin (après le push et la vigilance). Quoi qu'il arrive au
    // téléphone du joueur, une simple navigation le ramène là où le clan l'attend.
    Future<void> _ensurePlayerVigilance() async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return;
                                    _startPlayerVigilance(clanId, clanSecret, region);
                                    await _checkPendingCeremony();
                                } catch (e) {
                                    deva_log("error", "[levelup] _ensurePlayerVigilance FAILED: $e");
                                }
    }

    // Une lecture du statut autoritaire. Retourne true si le polling doit s'arrêter (verdict
    // rendu : la tâche n'est plus "validating"), false sinon (encore en attente, ou lecture
    // transitoire en échec → on reprogramme).
    Future<bool> _pollValidationOnce(String clanId, String clanSecret, String region, String taskId) async {

                                Dvidle? doc;
                                try {
                                    doc = await _cloud?.read("workers", "clans_tasks/$clanId/tasks", taskId,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("warning", "[combat] poll validation: lecture KO ($e) → on réessaiera");
                                    return false;                                       // erreur transitoire : continuer
                                }
                                final st  = doc?.get("status")?.toString()   ?? "";
                                final who = doc?.get("assignee")?.toString() ?? "";
                                if (st == "validating") return false;                   // toujours en attente
                                deva_log("info", "[combat] poll: verdict détecté (status=$st) → résolution: $taskId");
                                await _resolveValidation(region, taskId, st, who, navigate: true);
                                return true;
    }

    // Applique localement l'issue d'une validation (verdict rendu) et nettoie l'état. Factorise
    // la même logique que la réconciliation de on_combat_appear. st = statut autoritaire lu.
    Future<void> _resolveValidation(String region, String taskId, String st, String who,
                                    {required bool navigate}) async {

                _stopValidationPolling();
                final userDoc = await _readSession(region) ?? Dvidle({});
                userDoc.rem("docId");

                final refused = st == "assigned" && who == _userId;
                if (refused) {
                    // Refus : la tâche reste à moi (assigned), seule la preuve est abandonnée →
                    // le joueur pourra la reprendre. On ne vide PAS active_task.
                    userDoc.set("active_proof", "");
                    await _cloud?.write("workers", "users", _sessionDocId(), userDoc, region: region);
                    _invalidateSessionCache();
                    await Deva.instance.set("session.active_proof", "");
                    deva_log("info", "[combat] résolution = refus → preuve abandonnée: $taskId");
                } else {
                    // Accepté (dead/alive), repris par un autre, ou disparu → on libère tout.
                    userDoc.set("active_task",  "");
                    userDoc.set("active_proof", "");
                    await _cloud?.write("workers", "users", _sessionDocId(), userDoc, region: region);
                    _invalidateSessionCache();
                    await Deva.instance.set("session.active_task",  "");
                    await Deva.instance.set("session.active_proof", "");
                    deva_log("info", "[combat] résolution = libération (status=$st): $taskId");
                }

                // Verdict rendu (poll ou tap sur la notif) → on quitte l'écran d'attente.
                //  - accepté (tâche libérée) → retour au TIROIR de sélection (combat, active_task vidé) :
                //    le joueur enchaîne sur une nouvelle tâche ; l'anim de victoire s'y joue par-dessus.
                //  - refus (tâche encore à moi) → dashboard, comme avant.
                if (navigate) DvOrb.navigate_reset(refused ? "dashboard" : "combat");

                // Verdict ACCEPTÉ (dead/alive) : garantir la célébration (victoire / coup de pouce) ET
                // la consommation de la récompense boss (effacement de recommended) SANS dépendre du seul
                // watch temps réel. Le tiroir (on_combat_appear) n'appelle pas _checkPlayerLevelUp → c'est
                // ici le point d'atterrissage fiable. REFUS / repris / disparu → rien à célébrer.
                if (!refused && (st == "dead" || st == "alive")) {
                    final clanId     = userDoc.get("steps.clan.clanId")?.toString()     ?? "";
                    final clanSecret = userDoc.get("steps.clan.clanSecret")?.toString() ?? "";
                    await _celebrateAfterAccept(clanId, clanSecret, region);
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
