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
// --- worker extension — Tâches du clan
// -----------------------------------------------------------------------------
extension Worker_tasks on worker {

    void _register_tasks() {

                                ActionRegistry.register("worker.storetasks",                 storetasks);

                                ActionRegistry.register("worker.on_fast_test_skip",         on_fast_test_skip);

                                // Sélection générique : un seul handler préfixé remplace ~150 registrations
                                // de tâches feuilles. Action "seltask.<taskId>" (ex: seltask.voiture_01).
                                ActionRegistry.register_prefix("seltask", (String taskId, dynamic caller, dynamic event) async {
                                    await _selectTask(taskId);
                                });

                                // Ouverture du sous-tiroir d'un domaine : "seldomain.<domaine>" (ex: seldomain.cuisine).
                                // Remplace les ~19 task_<domaine>_select. Vérifie domains.<domaine>.enabled avant nav.
                                // Domaine « multiple » : le suffixe peut être "<domaine>__<owner>" (une entrée par
                                // membre au tiroir parent). On extrait l'owner → session.selected_owner (filtre le
                                // sous-tiroir sur ses tâches), et on résout le domaine de base via _originalOf.
                                ActionRegistry.register_prefix("seldomain", (String suffix, dynamic caller, dynamic event) async {
                                    // Joueur mort (0 PV) : ni ouverture de sous-tiroir ni sélection.
                                    if ((await deva_get("session.player_dead")) == true) return;
                                    // Tâche déjà en cours : on n'entre même pas dans le sous-tiroir (symétrique de
                                    // la garde de _selectTask, qui reste le filet de sécurité). Un tap rapide qui
                                    // passe avant le masquage du tiroir ramène ainsi le joueur à SON combat, au lieu
                                    // de le promener dans un écran de tâches où plus rien n'est prenable.
                                    if (((await Deva.instance.get("session.active_task"))?.toString() ?? "").isNotEmpty) {
                                        DvOrb.navigate_reset("combat");
                                        return;
                                    }
                                    final domain = _originalOf(suffix);
                                    final owner  = suffix == domain ? "" : suffix.substring(domain.length + 2);
                                    await Deva.instance.set("session.selected_owner", owner);
                                    final raw     = await deva_get("domains.$domain.enabled");
                                    final enabled = raw == null ? true : (raw == true || raw.toString() == "true");
                                    if (!enabled) return;
                                    await _refreshTaskStatuses();
                                    DvOrb.navigate_new("${domain}_tasks");
                                });

    }

    Future<void> on_fast_test_skip(DvShape? caller, dynamic event) async {

                                if (_userId.isEmpty) _userId = await _resolveUserId();
                                if (_userId.isEmpty) { deva_log("error", "[worker] on_fast_test_skip: userId introuvable"); return; }

                                const region       = "eu";
                                const legalState   = "a";
                                const internalName = "TestClan";
                                const playerName   = "TestPlayer";

                                await ActionRegistry.get("documents.on_region_selected")?.call(null, region);
                                _cloud?.configure("region", region);
                                final _ai = Deva.instance.module("dvvertexai");
                                if (_ai != null) try { await (_ai as dynamic).startVertexMotor(); } catch (_) {}

                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                final device      = await _cloud?.deviceId() ?? "";
                                final now         = DateTime.now().toUtc().toIso8601String();
                                final clanId      = _generateUuid();
                                final clanSecret  = _generateUuid();

                                // user session — toutes les étapes complètes
                                final userDoc = await _readSession(region) ?? Dvidle({});
                                userDoc.rem("docId");
                                userDoc.set("ownerId",                    firebaseUid);
                                userDoc.set("userId",                     _userId);
                                userDoc.set("last_clan",                  clanId);
                                userDoc.set("clans.$clanId.date",         now);
                                userDoc.set("clans.$clanId.clanSecret",   clanSecret);
                                userDoc.set("steps.region_intro.status",  "done");
                                userDoc.set("steps.region_intro.date",    now);
                                userDoc.set("steps.region_intro.result",  region);
                                userDoc.set("steps.region_intro.device",  device);
                                userDoc.set("steps.region.status",        "done");
                                userDoc.set("steps.region.date",          now);
                                userDoc.set("steps.region.result",        region);
                                userDoc.set("steps.region.device",        device);
                                userDoc.set("steps.legal_state.status",   "done");
                                userDoc.set("steps.legal_state.date",     now);
                                userDoc.set("steps.legal_state.result",   legalState);
                                userDoc.set("steps.legal_state.device",   device);
                                userDoc.set("steps.cgu.status",           "done");
                                userDoc.set("steps.cgu.date",             now);
                                userDoc.set("steps.cgu.result",           "accepted");
                                userDoc.set("steps.cgu.device",           device);
                                userDoc.set("steps.clan.clanId",          clanId);
                                userDoc.set("steps.clan.clanSecret",      clanSecret);
                                userDoc.set("steps.clan.status",          "done");
                                userDoc.set("steps.clan.date",            now);
                                userDoc.set("steps.clan.result",          "created");
                                userDoc.set("steps.clan.device",          device);
                                userDoc.set("steps.decisiontree.status",  "done");
                                userDoc.set("steps.decisiontree.date",    now);
                                userDoc.set("steps.decisiontree.result",  "done");
                                userDoc.set("steps.decisiontree.device",  device);
                                userDoc.set("internal.name",              playerName);
                                userDoc.set("external.name",              playerName);
                                userDoc.set("steps.name.status",          "done");
                                userDoc.set("steps.name.date",            now);
                                userDoc.set("steps.name.result",          playerName);
                                userDoc.set("steps.name.device",          device);
                                userDoc.set("date",                       now);
                                try {
                                    await _cloud?.write("workers", "users", _sessionDocId(), userDoc, region: region);
                                    _invalidateSessionCache();
                                    deva_log("info", "[worker] on_fast_test_skip: users OK");
                                } catch (e) {
                                    deva_log("error", "[worker] on_fast_test_skip: users FAILED: $e");
                                }

                                // userindexes
                                if (firebaseUid.isNotEmpty) {
                                    try {
                                        final idx = Dvidle({});
                                        idx.set("ownerId",                   firebaseUid);
                                        idx.set("userId",                    _userId);
                                        idx.set("clans.$clanId.clanSecret",  clanSecret);
                                        await _cloud?.write("workers", "userindexes", firebaseUid, idx, region: region);
                                        deva_log("info", "[worker] on_fast_test_skip: userindexes OK");
                                    } catch (e) {
                                        deva_log("error", "[worker] on_fast_test_skip: userindexes FAILED: $e");
                                    }
                                }

                                // clan
                                final clanDoc = Dvidle({});
                                clanDoc.set("clanId",         clanId);
                                clanDoc.set("ownerId",        clanSecret);
                                clanDoc.set("date",           now);
                                clanDoc.set("admins",         [_userId]);
                                clanDoc.set("founder",        _userId);
                                clanDoc.set("internal.name",  internalName);
                                clanDoc.set("external.name",  "$internalName-$region-0");
                                clanDoc.set("description",    "Fast test clan");
                                clanDoc.set("avatar",         _defaultClanAvatar);
                                try {
                                    await _cloud?.write("workers", "clans", clanId, clanDoc, region: region, ownerId: clanSecret);
                                    deva_log("info", "[worker] on_fast_test_skip: clan OK");
                                    // Le créateur est le premier membre ET chef d'emblée (asAdmin).
                                    await _writeClanPlayer(clanId, clanSecret, _userId, device, region, asAdmin: true);
                                    // Coffre du butin + portefeuille (clan neuf : rien ne peut exister).
                                    await _ensureButinDocs(clanId, clanSecret, region, const <Dvidle>[]);
                                } catch (e) {
                                    deva_log("error", "[worker] on_fast_test_skip: clan FAILED: $e");
                                }

                                // clans_tasks — simuler les réponses au decisiontree
                                final computed = _computeFastTestTasks();
                                try {
                                    await _persistTaskResults(computed, clanId, clanSecret, region);
                                    deva_log("info", "[worker] on_fast_test_skip: clans_tasks OK");
                                } catch (e) {
                                    deva_log("error", "[worker] on_fast_test_skip: clans_tasks FAILED: $e");
                                }

                                // Reproduit le flux on_login (best session) + on_documents_ready + on_acceptance_complete.

                                // 1. Synchronise le module documents en mémoire :
                                //    → documents.session.region, documents.session.legalstate,
                                //      documents.region_ready (débloque le wait messaging)
                                await ActionRegistry.get("documents._sync_session")?.call(null, null);

                                // 2. Enregistrement FCM (normalement déclenché via on_documents_ready).
                                await _messaging?.msgregister('global');

                                // 3. Charge tasks/domains en RAM depuis clans_tasks Firestore.
                                await _loadClanTasks(userDoc, region);

                                // 4. État adulte — désactive la restriction "mineur" sur create_clan.
                                await Deva.instance.set("worker.session.create_clan_disabled", "");

                                // 5. Session clan et user marqués complets.
                                await Deva.instance.set("session.clan.name", internalName);
                                await Deva.instance.set("session.user.name", playerName);
                                await Deva.instance.set("worker.session.clan_done", "true");

                                // 6. Persiste les layers sur disque (dont les couches cloud déjà chargées) :
                                //    le skip court-circuite l'onboarding, on s'assure que tout est sauvegardé
                                //    pour que le prochain démarrage recharge les traductions au bootstrap.
                                await Deva.instance.store();

                                DvOrb.navigate_reset("dashboard");
    }

    // Skip de test : toutes les tâches et tous les domaines activés (on ne désactive rien).
    Dvidle _computeFastTestTasks() => _buildTaskResults(
            whitelist: {},
            blacklist: {},
            enableAll: true,
    );

    Dvidle _buildTaskResults({required Set<String> whitelist, required Set<String> blacklist, bool enableAll = false}) {

                                bool taskEnabled(List<String> skipBl, List<String> keepWl) {
                                    if (enableAll) return true;                 // skip region_screen : on ne désactive rien
                                    if (keepWl.isNotEmpty) return keepWl.every((t) => whitelist.contains(t));
                                    if (skipBl.isNotEmpty && skipBl.any((t) => blacklist.contains(t))) return false;
                                    return true;
                                }

                                // (taskId, domain, skip_if_blacklisted, keep_if_whitelisted)
                                const taskDefs = <(String, String, List<String>, List<String>)>[
                                    ('salon_01','salon',[],[]),('salon_02','salon',[],[]),('salon_03','salon',[],[]),
                                    ('salon_04','salon',[],[]),('salon_05','salon',[],[]),('salon_06','salon',[],[]),
                                    ('salon_07','salon',[],[]),('salon_08','salon',[],[]),('salon_09','salon',[],[]),
                                    ('salon_10','salon',[],[]),
                                    ('chambre_parentale_01','chambre_parentale',[],[]),('chambre_parentale_02','chambre_parentale',[],[]),
                                    ('chambre_parentale_03','chambre_parentale',[],[]),('chambre_parentale_04','chambre_parentale',[],[]),
                                    ('chambre_parentale_05','chambre_parentale',[],[]),('chambre_parentale_06','chambre_parentale',[],[]),
                                    ('chambre_parentale_08','chambre_parentale',[],[]),
                                    ('chambre_parentale_09','chambre_parentale',[],[]),
                                    ('chambre_parentale_10','chambre_parentale',[],[]),
                                    ('chambre_enfant_01','chambre_enfant',['tag_possede_chambre_enfant'],[]),
                                    ('chambre_enfant_02','chambre_enfant',['tag_possede_chambre_enfant'],[]),
                                    ('chambre_enfant_03','chambre_enfant',['tag_possede_chambre_enfant'],[]),
                                    ('chambre_enfant_04','chambre_enfant',['tag_possede_chambre_enfant'],[]),
                                    ('chambre_enfant_05','chambre_enfant',['tag_possede_chambre_enfant'],[]),
                                    ('chambre_enfant_06','chambre_enfant',['tag_possede_chambre_enfant'],[]),
                                    ('chambre_enfant_09','chambre_enfant',['tag_possede_chambre_enfant'],[]),
                                    ('chambre_enfant_10','chambre_enfant',['tag_possede_chambre_enfant'],[]),
                                    ('chambre_enfant_11','chambre_enfant',['tag_possede_chambre_enfant'],[]),
                                    ('cuisine_01','cuisine',[],[]),('cuisine_03','cuisine',[],[]),
                                    ('cuisine_04','cuisine',[],[]),('cuisine_05','cuisine',[],[]),('cuisine_06','cuisine',[],[]),
                                    ('cuisine_07','cuisine',[],[]),('cuisine_08','cuisine',[],[]),('cuisine_09','cuisine',[],[]),
                                    ('cuisine_10','cuisine',['tag_possede_hotte'],[]),
                                    ('cuisine_11','cuisine',['tag_possede_four'],[]),
                                    ('cuisine_12','cuisine',['tag_possede_plaque_cuisson'],[]),
                                    ('cuisine_13','cuisine',[],[]),
                                    ('cuisine_15','cuisine',['tag_possede_bouilloire_cafetiere'],[]),
                                    ('cuisine_18','cuisine',[],[]),('cuisine_19','cuisine',[],[]),
                                    ('repas_06','repas',[],[]),('repas_07','repas',[],[]),
                                    ('repas_10','repas',[],[]),('repas_11','repas',[],[]),
                                    ('vaisselle_01','vaisselle',[],[]),
                                    ('vaisselle_02','vaisselle',['tag_possede_lave_vaisselle'],[]),
                                    ('vaisselle_03','vaisselle',['tag_possede_lave_vaisselle'],[]),
                                    ('vaisselle_04','vaisselle',['tag_possede_lave_vaisselle'],[]),
                                    ('vaisselle_05','vaisselle',[],['tag_sans_lave_vaisselle']),
                                    ('vaisselle_06','vaisselle',[],[]),('vaisselle_07','vaisselle',[],[]),
                                    ('vaisselle_08','vaisselle',[],[]),
                                    ('vaisselle_09','vaisselle',['tag_possede_lave_vaisselle'],[]),
                                    ('salle_de_bain_01','salle_de_bain',[],[]),('salle_de_bain_02','salle_de_bain',[],[]),
                                    ('salle_de_bain_03','salle_de_bain',[],[]),('salle_de_bain_04','salle_de_bain',[],[]),
                                    ('salle_de_bain_05','salle_de_bain',[],[]),('salle_de_bain_06','salle_de_bain',[],[]),
                                    ('salle_de_bain_07','salle_de_bain',['tag_possede_douche'],[]),
                                    ('salle_de_bain_08','salle_de_bain',['tag_possede_baignoire'],[]),
                                    ('salle_de_bain_10','salle_de_bain',[],[]),
                                    ('salle_de_bain_11','salle_de_bain',[],[]),('salle_de_bain_12','salle_de_bain',[],[]),
                                    ('toilettes_01','toilettes',[],[]),('toilettes_02','toilettes',[],[]),
                                    ('toilettes_03','toilettes',[],[]),('toilettes_04','toilettes',[],[]),
                                    ('toilettes_06','toilettes',[],[]),
                                    ('couloir_01','entree',[],[]),('couloir_02','entree',[],[]),
                                    ('couloir_03','entree',[],[]),('couloir_04','entree',[],[]),
                                    ('entree_01','entree',[],[]),('entree_02','entree',[],[]),
                                    ('entree_03','entree',[],[]),('entree_04','entree',[],[]),
                                    ('bureau_01','bureau',['tag_possede_bureau'],[]),('bureau_02','bureau',['tag_possede_bureau'],[]),
                                    ('bureau_03','bureau',['tag_possede_bureau'],[]),('bureau_04','bureau',['tag_possede_bureau'],[]),
                                    ('bureau_05','bureau',['tag_possede_bureau'],[]),('bureau_06','bureau',['tag_possede_bureau'],[]),
                                    ('terrasse_01','terrasse',['tag_possede_terrasse'],[]),('terrasse_02','terrasse',['tag_possede_terrasse'],[]),
                                    ('balcon_01','terrasse',['tag_possede_balcon'],[]),('balcon_02','terrasse',['tag_possede_balcon'],[]),
                                    ('terrasse_03','terrasse',[],['tag_possede_balcon_ou_terrasse']),
                                    ('jardin_01','jardin',['tag_possede_jardin'],[]),('jardin_02','jardin',['tag_possede_jardin'],[]),
                                    ('jardin_03','jardin',['tag_possede_jardin'],[]),('jardin_04','jardin',['tag_possede_jardin'],[]),
                                    ('jardin_05','jardin',['tag_possede_jardin'],[]),('jardin_06','jardin',['tag_possede_jardin'],[]),
                                    ('linge_01','linge',[],[]),
                                    ('linge_02','linge',['tag_possede_machine_laver'],[]),
                                    ('linge_02_alt','linge',[],['tag_sans_machine_laver']),
                                    ('linge_03','linge',['tag_possede_etendoir'],[]),
                                    ('linge_04','linge',['tag_possede_etendoir'],[]),
                                    ('linge_05','linge',[],[]),('linge_06','linge',[],[]),
                                    ('linge_08','linge',['tag_possede_fer_a_repasser'],[]),
                                    ('linge_09','linge',['tag_possede_machine_laver'],[]),
                                    ('dechets_01','dechets',[],[]),('dechets_02','dechets',[],[]),('dechets_03','dechets',[],[]),
                                    ('dechets_04','dechets',[],[]),
                                    ('dechets_05','dechets',['tag_possede_composteur'],[]),
                                    ('dechets_06','dechets',[],[]),('dechets_07','dechets',[],[]),
                                    ('animaux_01','animaux',['tag_possede_animal'],[]),('animaux_02','animaux',['tag_possede_animal'],[]),
                                    ('animaux_03','animaux',['tag_possede_animal'],[]),('animaux_05','animaux',['tag_possede_animal'],[]),
                                    ('voiture_01','vehicules',['tag_possede_voiture'],[]),
                                    ('voiture_02','vehicules',['tag_possede_voiture'],[]),
                                    ('moto_01','vehicules',['tag_possede_moto'],[]),
                                    ('garage_01','garage',['tag_possede_garage'],[]),('garage_02','garage',['tag_possede_garage'],[]),
                                    ('garage_03','garage',['tag_possede_garage'],[]),('garage_04','garage',['tag_possede_garage'],[]),
                                    ('garage_05','garage',['tag_possede_garage'],[]),('garage_06','garage',['tag_possede_garage'],[]),
                                    ('courses_01','courses',[],[]),('courses_02','courses',[],[]),('courses_03','courses',[],[]),
                                    ('courses_04','courses',[],[]),('courses_05','courses',[],[]),
                                    ('extras_01','extras',['tag_possede_plantes_interieur'],[]),
                                    ('extras_02','extras',[],[]),
                                    ('extras_03','extras',['tag_possede_aspirateur'],[]),
                                    ('extras_04','extras',[],[]),('extras_05','extras',[],[]),('extras_06','extras',[],[]),
                                    ('extras_07','extras',[],[]),('extras_08','extras',[],[]),
                                ];

                                final tasks            = Dvidle({});
                                final domains          = Dvidle({});
                                final domainHasEnabled = <String, bool>{};

                                for (final (id, domain, skipBl, keepWl) in taskDefs) {
                                    final en = taskEnabled(skipBl, keepWl);
                                    tasks.set('$id.enabled', en);
                                    tasks.set('$id.domain',  domain);            // persisté sur le doc → fin de la regex de regroupement
                                    domainHasEnabled[domain] = (domainHasEnabled[domain] ?? false) || en;
                                }

                                final allDomains = _taskDomains;
                                for (final d in allDomains) {
                                    domains.set('$d.enabled', domainHasEnabled[d] ?? true);
                                }

                                final result = Dvidle({});
                                result.set('tasks',   tasks);
                                result.set('domains', domains);
                                return result;
    }

    Future<void> storetasks(DvShape? caller, dynamic event) async {

                                deva_log("info", "[worker] storetasks: appelé");
                                final rawBl = await deva_get("decisiontree.session.blacklist");
                                final rawWl = await deva_get("decisiontree.session.whitelist");
                                final blacklist = rawBl is List ? rawBl.map((e) => e.toString()).toSet() : <String>{};
                                final whitelist = rawWl is List ? rawWl.map((e) => e.toString()).toSet() : <String>{};
                                if (blacklist.isEmpty && whitelist.isEmpty) {
                                    deva_log("error", "[worker] storetasks: session decisiontree vide");
                                    return;
                                }
                                deva_log("info", "[worker] storetasks: bl=${blacklist.length} wl=${whitelist.length} → calcul");
                                try {
                                    await _applyAndPersistTasks(_buildTaskResults(whitelist: whitelist, blacklist: blacklist));
                                } catch (e) {
                                    deva_log("error", "[worker] storetasks: erreur $e");
                                }
    }

    Future<void> _applyAndPersistTasks(Dvidle result) async {

                                final resultTasks   = result.get("tasks");
                                final resultDomains = result.get("domains");

                                // Appliquer dans le store DEVA
                                int enabledCount = 0, disabledCount = 0;
                                if (resultTasks is Dvidle) {
                                    for (final taskId in resultTasks.keys) {
                                        final raw       = resultTasks.get("$taskId.enabled");
                                        final isEnabled = raw == null ? true : (raw == true || raw.toString() == "true");
                                        await deva_set("tasks.$taskId.enabled", isEnabled);
                                        if (isEnabled) enabledCount++; else disabledCount++;
                                    }
                                }
                                if (resultDomains is Dvidle) {
                                    for (final d in resultDomains.keys) {
                                        final raw = resultDomains.get("$d.enabled");
                                        final en  = raw == null ? true : (raw == true || raw.toString() == "true");
                                        await deva_set("domains.$d.enabled", en);
                                    }
                                    _notifyTiroirDomains(_buildDomainStatusMap(resultDomains));
                                }
                                deva_log("info", "[worker] clans_tasks: $enabledCount enabled, $disabledCount disabled → persist");

                                // Persister en Firestore
                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (region.isEmpty) return;
                                final session    = await _readSession(region);
                                final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) return;

                                try {
                                    await _persistTaskResults(result, clanId, clanSecret, region);
                                    deva_log("info", "[worker] clans_tasks persisté → firestore OK");
                                } catch (e) {
                                    deva_log("error", "[worker] clans_tasks write FAILED: $e");
                                }
                                await _writeStep(region, "decisiontree", "done");
    }

    // Persiste les tâches/domaines en sous-collections : un document par item
    //   clans_tasks/{clanId}/tasks/{taskId}     → enabled, assignee, last, status
    //   clans_tasks/{clanId}/domains/{domainId} → enabled
    // batchWrite n'injecte pas ownerId → on le pose explicitement dans chaque doc.
    Future<void> _persistTaskResults(Dvidle result, String clanId, String clanSecret, String region) async {

                                final userId     = _userId;
                                final name       = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                final legalState = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "";

                                final writes          = <DvCloudWrite>[];
                                final enabledMultiple = <String>[];   // baseId des tâches multiple activées (→ doc clan)
                                final tasks  = result.get("tasks");
                                if (tasks is Dvidle) {
                                    for (final id in tasks.keys) {
                                        final raw      = tasks.get("$id.enabled");
                                        final en       = raw == null ? true : (raw == true || raw.toString() == "true");
                                        final rawVis   = tasks.get("$id.visible");
                                        final vis      = rawVis == null ? true : (rawVis == true || rawVis.toString() == "true");
                                        final domain   = tasks.get("$id.domain")?.toString() ?? "";
                                        // `multiple` piloté par la CONF (jamais hardcodé) : flag de la tâche
                                        // (tasks.<id>.multiple) OU, à défaut, du domaine (domains.<d>.multiple).
                                        final multiple = await _taskMultipleWho(id, domain);
                                        if (multiple.isNotEmpty) {
                                            // Tâche multiple : PAS de doc de base partagé. On mémorise l'activation
                                            // pour les arrivants, et on crée le clone du créateur s'il qualifie.
                                            if (en) enabledMultiple.add(id);
                                            if (en && _qualifiesForMultiple(multiple, legalState)) {
                                                final cid   = _cloneId(id, userId);
                                                final label = "@@@T:dt_t_$id@@@ - $name";
                                                writes.add(DvCloudWrite.set("clans_tasks/$clanId/tasks", cid,
                                                    _newTaskDoc(clanId, clanSecret, en, domain: domain, original: id,
                                                        owner: userId, ownerName: name, label: label, visible: vis)));
                                            }
                                        } else {
                                            writes.add(DvCloudWrite.set("clans_tasks/$clanId/tasks", id,
                                                _newTaskDoc(clanId, clanSecret, en, domain: domain, visible: vis)));
                                        }
                                    }
                                }
                                final domains = result.get("domains");
                                if (domains is Dvidle) {
                                    for (final d in domains.keys) {
                                        final raw = domains.get("$d.enabled");
                                        final en  = raw == null ? true : (raw == true || raw.toString() == "true");
                                        final rawVis = domains.get("$d.visible");
                                        final vis    = rawVis == null ? true : (rawVis == true || rawVis.toString() == "true");
                                        final dd  = Dvidle({});
                                        dd.set("ownerId", clanSecret);
                                        dd.set("clanId",  clanId);
                                        dd.set("enabled", en);
                                        dd.set("visible", vis);
                                        writes.add(DvCloudWrite.set("clans_tasks/$clanId/domains", d, dd));
                                    }
                                }
                                if (writes.isNotEmpty) await _cloud?.batchWrite("workers", writes, region: region);

                                // Liste des tâches multiple activées → doc clan : un arrivant y lit quoi cloner
                                // pour lui-même (les docs de base n'existent pas pour ces tâches).
                                try {
                                    final clan = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    clan.rem("docId");
                                    clan.set("enabled_multiple", enabledMultiple);
                                    await _cloud?.write("workers", "clans", clanId, clan,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("error", "[worker] _persistTaskResults: enabled_multiple write FAILED: $e");
                                }
    }

    Future<void> _loadClanTasks(Dvidle session, String region) async {

                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) return;
                                try {
                                    var taskDocs   = await _cloud?.list("workers", "clans_tasks/$clanId/tasks",   region: region) ?? [];
                                    var domainDocs = await _cloud?.list("workers", "clans_tasks/$clanId/domains", region: region) ?? [];

                                    // Migration de schéma : converge Firestore vers le CATALOGUE de conf (ajoute
                                    // les tâches/domaines nouveaux, retire ceux disparus). Si un diff a été appliqué,
                                    // on relit pour que l'hydratation ci-dessous reflète l'état final.
                                    if (await _reconcileClanSchema(clanId, clanSecret, region, taskDocs, domainDocs)) {
                                        taskDocs   = await _cloud?.list("workers", "clans_tasks/$clanId/tasks",   region: region) ?? [];
                                        domainDocs = await _cloud?.list("workers", "clans_tasks/$clanId/domains", region: region) ?? [];
                                    }

                                    // Seed du delta-sync : ce full list fait autorité. Cache reconstruit à
                                    // neuf (les docs supprimés par le réconciliateur en sortent ici — les
                                    // refreshs delta ne voient pas les suppressions), curseur posé au
                                    // max(touched) observé ("0" si aucun doc estampillé : tout ISO-8601 lui
                                    // est lexicographiquement supérieur), filet 24 h réarmé.
                                    _taskDocsCache.clear();
                                    _tasksSyncCursor = "0";
                                    _tasksSyncClanId = clanId;
                                    for (final d in taskDocs) {
                                        final id = d.get("docId")?.toString() ?? "";
                                        if (id.isEmpty) continue;
                                        _taskDocsCache[id] = d;
                                        final t = d.get("touched")?.toString() ?? "";
                                        if (t.compareTo(_tasksSyncCursor) > 0) _tasksSyncCursor = t;
                                    }
                                    _lastTasksFullListAt = DateTime.now();
                                    _lastTasksFetchAt    = DateTime.now();

                                    int enabledCount = 0, disabledCount = 0;
                                    _titleOverride.clear();
                                    _acceptanceOverride.clear();
                                    for (final d in taskDocs) {
                                        final taskId = d.get("docId")?.toString() ?? "";
                                        if (taskId.isEmpty) continue;
                                        // SURCHARGE GÉNÉRIQUE : tout champ du doc Firestore écrase tasks.<id>.<champ>
                                        // de la conf (hors plomberie). Rend les futurs champs éditables « gratuits »
                                        // (aucune ligne à ajouter ici). Un champ absent du doc laisse la valeur conf.
                                        for (final k in d.keys) {
                                            if (_taskDocBlocklist.contains(k)) continue;
                                            await deva_set("tasks.$taskId.$k", d.get(k));
                                        }
                                        // enabled/visible : coercion booléenne (défaut true) — le rendu en dépend et
                                        // un doc legacy peut ne pas porter le champ. Réappliqué par-dessus la boucle.
                                        final raw       = d.get("enabled");
                                        final isEnabled = raw == null ? true : (raw == true || raw.toString() == "true");
                                        final rawVis    = d.get("visible");
                                        final isVisible = rawVis == null ? true : (rawVis == true || rawVis.toString() == "true");
                                        await deva_set("tasks.$taskId.enabled",  isEnabled);
                                        await deva_set("tasks.$taskId.visible",  isVisible);
                                        // Overrides texte (édition chef) → résolution synchrone du label/acceptance.
                                        final t = d.get("title")?.toString()      ?? "";
                                        if (t.isNotEmpty) _titleOverride[taskId] = t;
                                        final a = d.get("acceptance")?.toString() ?? "";
                                        if (a.isNotEmpty) _acceptanceOverride[taskId] = a;
                                        await _ingestTaskDoc(d);   // clone → mémorise original + hydrate tuning
                                        if (isEnabled) enabledCount++; else disabledCount++;
                                    }
                                    // Table de clones (baseId → clones) : le tiroir masque les templates
                                    // multiple et affiche une icône par clone.
                                    _notifyTiroirClones(await _buildClonesMap(taskDocs));
                                    // Tuiles NEUVES (tâches user-created, hors catalogue) : injectées dans le
                                    // tiroir de leur domaine (aucun template en config → seul canal possible).
                                    _notifyTiroirAdditions(await _buildAdditionsMap(taskDocs));
                                    final domainStatus = <String, bool>{};
                                    for (final d in domainDocs) {
                                        final id = d.get("docId")?.toString() ?? "";
                                        if (id.isEmpty) continue;
                                        // Surcharge générique (idem tâches) : le nom d'un domaine peut être renommé.
                                        for (final k in d.keys) {
                                            if (_taskDocBlocklist.contains(k)) continue;
                                            await deva_set("domains.$id.$k", d.get(k));
                                        }
                                        final raw = d.get("enabled");
                                        final en  = raw == null ? true : (raw == true || raw.toString() == "true");
                                        final rawVis = d.get("visible");
                                        final vis    = rawVis == null ? true : (rawVis == true || rawVis.toString() == "true");
                                        await deva_set("domains.$id.enabled", en);
                                        await deva_set("domains.$id.visible", vis);
                                        final t = d.get("title")?.toString() ?? "";
                                        if (t.isNotEmpty) _titleOverride[id] = t;
                                        domainStatus[id] = en;
                                    }
                                    if (domainStatus.isNotEmpty) _notifyTiroirDomains(domainStatus);
                                    // Libellés surchargés (tâches/domaines renommés) poussés au tiroir : le
                                    // `label:` de config est statique, ce canal le remplace au runtime.
                                    _notifyTiroirLabels(_titleOverride);
                                    deva_log("info", "[worker] clans_tasks loaded: $enabledCount enabled, $disabledCount disabled");
                                } catch (e) {
                                    deva_log("error", "[worker] _loadClanTasks FAILED: $e");
                                }
    }

    // --- Migration de schéma : converge clans_tasks/{clanId} vers le CATALOGUE de conf.
    // Détection STRUCTURELLE (aucun bookkeeping) : à chaque chargement, on compare l'ensemble
    // désiré (issu de _buildTaskResults — même source que le skip de test) aux docs présents, et
    // on applique le diff en UN seul batch. Idempotent : convergent même si plusieurs membres le
    // lancent en parallèle. Sur un état déjà à jour, aucune écriture n'est émise (retour false).
    //   • AJOUTE les tâches/domaines présents au catalogue mais absents de Firestore (enabled:true).
    //   • RETIRE les docs dont la base (via _originalOf → préserve les clones {base}__{uid}) n'est
    //     plus au catalogue.
    // Volontairement HORS PÉRIMÈTRE (arbitrages produit validés) :
    //   • le filtrage par tags n'est PAS rejoué → les ajouts sont enabled:true ;
    //   • la liste clans.enabled_multiple n'est pas maintenue (aucune tâche `multiple` concernée).
    // N'importe quel membre peut l'exécuter (écritures autorisées via ownerId == clanSecret).
    // Renvoie true si au moins une écriture a été émise (→ l'appelant relit les docs).
    Future<bool> _reconcileClanSchema(String clanId, String clanSecret, String region,
        List<dynamic> taskDocs, List<dynamic> domainDocs) async {

                    // Ensemble désiré = catalogue complet (tous tags actifs), même source que le skip de test.
                    final desired      = _buildTaskResults(whitelist: {}, blacklist: {}, enableAll: true);
                    final desiredTasks = desired.get("tasks");
                    final desiredDoms  = desired.get("domains");
                    if (desiredTasks is! Dvidle || desiredDoms is! Dvidle) return false;

                    final desiredTaskIds = desiredTasks.keys.toSet();   // inclut les bases `multiple`
                    final desiredDomIds  = desiredDoms.keys.toSet();

                    final existingTaskIds = <String>{};
                    for (final d in taskDocs) {
                        final id = d.get("docId")?.toString() ?? "";
                        if (id.isNotEmpty) existingTaskIds.add(id);
                    }
                    final existingDomIds = <String>{};
                    for (final d in domainDocs) {
                        final id = d.get("docId")?.toString() ?? "";
                        if (id.isNotEmpty) existingDomIds.add(id);
                    }
                    // Items créés par l'utilisateur (hors catalogue de conf) : exemptés de suppression —
                    // le réconciliateur ne connaît que le catalogue, il les prendrait pour des orphelins.
                    // Le drapeau `user_created` est la marque nominale, mais on ne s'y fie pas SEUL :
                    // un doc portant du contenu SAISI (title/image) vient forcément d'une création ou
                    // d'une édition et doit survivre, même écrit par un binaire qui ne posait pas encore
                    // le drapeau (sinon ce client-là détruit le travail des autres au démarrage).
                    bool isUserCreated(dynamic d) =>
                        d.get("user_created") == true ||
                        (d.get("title")?.toString() ?? "").isNotEmpty ||
                        (d.get("image")?.toString() ?? "").isNotEmpty;

                    final userCreatedTaskIds = <String>{};
                    for (final d in taskDocs) {
                        if (!isUserCreated(d)) continue;
                        final id = d.get("docId")?.toString() ?? "";
                        if (id.isNotEmpty) userCreatedTaskIds.add(id);
                    }
                    // Symétrique pour les domaines. Aucun chemin client n'écrit de domaine user-created
                    // (le chef ne crée pas de domaine : les domaines additionnels seront livrés par des
                    // packs achetés) — l'exemption est là pour que le jour où un pack posera ses domaines
                    // hors catalogue de conf, le réconciliateur ne les efface pas au prochain passage.
                    final userCreatedDomIds = <String>{};
                    for (final d in domainDocs) {
                        if (!isUserCreated(d)) continue;
                        final id = d.get("docId")?.toString() ?? "";
                        if (id.isNotEmpty) userCreatedDomIds.add(id);
                    }

                    final writes = <DvCloudWrite>[];

                    // Tâches à AJOUTER : id désiré sans doc, hors tâches `multiple` (pas de doc de base
                    // partagé — le clone est créé à la demande, comme dans _persistTaskResults).
                    for (final id in desiredTaskIds) {
                        if (existingTaskIds.contains(id)) continue;
                        final domain   = desiredTasks.get("$id.domain")?.toString() ?? "";
                        final multiple = await _taskMultipleWho(id, domain);
                        if (multiple.isNotEmpty) continue;
                        writes.add(DvCloudWrite.set("clans_tasks/$clanId/tasks", id,
                            _newTaskDoc(clanId, clanSecret, true, domain: domain)));
                    }
                    // Tâches à RETIRER : base (via _originalOf) absente du catalogue → orpheline.
                    // DOUBLE GARDE, parce qu'une suppression est irréversible et qu'elle est décidée
                    // par un client dont le catalogue peut être PLUS ANCIEN que la base :
                    //   1. les tâches user-created sont exemptées (hors catalogue par nature) ;
                    //   2. seule une tâche dont l'id a la FORME d'un id de catalogue (<domaine>_NN) peut
                    //      être supprimée — un id de forme inconnue appartient à un autre binaire (ou à
                    //      un joueur) et ne doit pas être détruit par celui qui ne sait pas le lire.
                    // Chaque suppression est journalisée : sans ça, une donnée qui disparaît au
                    // redémarrage ne laisse aucune trace exploitable.
                    for (final eid in existingTaskIds) {
                        if (userCreatedTaskIds.contains(eid)) continue;
                        if (desiredTaskIds.contains(_originalOf(eid))) continue;
                        if (!_catalogTaskIdRe.hasMatch(_originalOf(eid))) {
                            deva_log("warning", "[worker] reconcile: $eid hors catalogue ET hors forme catalogue → CONSERVÉ");
                            continue;
                        }
                        deva_log("warning", "[worker] reconcile: suppression tasks/$eid (orphelin hors catalogue)");
                        writes.add(DvCloudWrite.delete("clans_tasks/$clanId/tasks", eid));
                    }

                    // Domaines à AJOUTER.
                    for (final d in desiredDomIds) {
                        if (existingDomIds.contains(d)) continue;
                        final dd = Dvidle({});
                        dd.set("ownerId", clanSecret);
                        dd.set("clanId",  clanId);
                        dd.set("enabled", true);
                        dd.set("visible", true);
                        writes.add(DvCloudWrite.set("clans_tasks/$clanId/domains", d, dd));
                    }
                    // Domaines à RETIRER : AUCUN. L'ensemble désiré vaut exactement _taskDomains (cf.
                    // _buildTaskResults) — un doc de domaine qui n'y figure pas est donc inconnu de CE
                    // binaire (pack acheté, version plus récente, domaine créé côté chef) et non un
                    // orphelin. Le supprimer reviendrait à laisser le client le plus ancien du clan
                    // faire autorité. On journalise pour que la divergence reste visible.
                    for (final eid in existingDomIds) {
                        if (userCreatedDomIds.contains(eid)) continue;
                        if (desiredDomIds.contains(eid)) continue;
                        deva_log("warning", "[worker] reconcile: domaine $eid inconnu de ce binaire → CONSERVÉ");
                    }

                    // Backfill du champ `recommended` sur les docs de tâche antérieurs (migration idempotente,
                    // couvre le clan existant et tout futur clan). Écriture PARTIELLE : le batchWrite dvcloud
                    // deep-merge (updateMask) → seul `recommended` est ajouté, les autres champs préservés.
                    // Sautée une fois le champ présent (donc au plus une passe par doc et par installation).
                    for (final d in taskDocs) {
                        final id = d.get("docId")?.toString() ?? "";
                        if (id.isEmpty) continue;
                        if (!desiredTaskIds.contains(_originalOf(id))) continue;   // orphelin déjà en suppression → pas de backfill
                        if (d.get("recommended") != null) continue;               // déjà migré
                        final rd = Dvidle({});
                        rd.set("ownerId",     clanSecret);
                        rd.set("clanId",      clanId);
                        rd.set("recommended", "");
                        writes.add(DvCloudWrite.set("clans_tasks/$clanId/tasks", id, rd));
                    }

                    // Trace des seules tâches HORS catalogue qui doivent leur survie à l'exemption
                    // (les tâches de catalogue simplement renommées n'ont jamais été menacées).
                    final protectedIds = userCreatedTaskIds
                        .where((id) => !desiredTaskIds.contains(_originalOf(id)))
                        .toList();
                    if (protectedIds.isNotEmpty) {
                        deva_log("info", "[worker] reconcile: ${protectedIds.length} tâche(s) hors catalogue "
                            "préservée(s): ${protectedIds.join(', ')}");
                    }
                    if (writes.isEmpty) return false;
                    try {
                        await _cloud?.batchWrite("workers", writes, region: region);
                        deva_log("info", "[worker] _reconcileClanSchema: ${writes.length} écriture(s) appliquée(s)");
                        return true;
                    } catch (e) {
                        deva_log("error", "[worker] _reconcileClanSchema FAILED: $e");
                        return false;
                    }
    }

    Map<String, bool> _buildDomainStatusMap(Dvidle domains) {

                                final Map<String, bool> result = {};
                                for (final d in domains.keys) {
                                    final raw = domains.get("$d.enabled");
                                    result[d] = raw == null ? true : (raw == true || raw.toString() == "true");
                                }
                                return result;
    }

    void _notifyTiroirDomains(Map<String, bool> domainStatus) {

                                if (!_adminMode) _gameDomains = Map<String, bool>.from(domainStatus);
                                final fn = ActionRegistry.get("dvtiroir.update_domains");
                                fn?.call(null, domainStatus);
    }

    // Pousse l'état de cycle de vie des tâches (assigned/validating/dead/busy) aux DvTiroir,
    // par nom d'icône. Complète _notifyTiroirDomains (qui ne gère que enabled/disabled).
    void _notifyTiroirStatuses(Map<String, String> iconStatus) {

                                final fn = ActionRegistry.get("dvtiroir.update_statuses");
                                fn?.call(null, iconStatus);
    }

    // Pousse les fenêtres de respawn (dead/revive) des tâches "dead" aux DvTiroir, par nom
    // d'icône : id → [deadIso, reviveIso]. Le tiroir en déduit la barre de progression.
    void _notifyTiroirProgress(Map<String, List<String>> progressById) {

                                final fn = ActionRegistry.get("dvtiroir.update_progress");
                                fn?.call(null, progressById);
    }

    // Pousse l'ensemble des icônes « recommandées » (boss) aux DvTiroir (badge XP, coin nord-ouest).
    // Canal indépendant des statuts : une tâche peut être recommandée ET assigned/validating.
    void _notifyTiroirRecommended(Set<String> ids) {

                                final fn = ActionRegistry.get("dvtiroir.update_recommended");
                                fn?.call(null, ids.toList());
    }

    // Ensemble des icônes portant le badge « boss » : chaque FEUILLE dont `recommended` est non vide,
    // PLUS son domaine (remontée) et la variante <domaine>__<owner> (icônes dépliées des multiples) —
    // même logique de roll-up que _buildIconStatusMap pour "busy".
    Set<String> _buildRecommendedSet(List<dynamic> taskDocs, Map<String, String> domainById) {

                                final set = <String>{};
                                for (final d in taskDocs) {
                                    final id = d.get("docId")?.toString() ?? "";
                                    if (id.isEmpty) continue;
                                    final rec = d.get("recommended")?.toString() ?? "";
                                    if (rec.isEmpty) continue;
                                    set.add(id);
                                    final domain = domainById[id] ??
                                        (_leafTaskRe.firstMatch(id) != null
                                            ? id.substring(0, _leafTaskRe.firstMatch(id)!.start)
                                            : "");
                                    if (domain.isNotEmpty) {
                                        set.add(domain);
                                        final owner = id.contains('__') ? id.substring(id.indexOf('__') + 2) : "";
                                        if (owner.isNotEmpty) set.add("${domain}__$owner");
                                    }
                                }
                                return set;
    }

    // Rafraîchit les statuts des tâches du clan et pousse les overlays aux tiroirs.
    // DELTA-SYNC : au lieu de relister les ~160 docs à chaque entrée d'écran, on ne relit
    // que les docs modifiés depuis le dernier passage (touched > curseur, cf. _stampTouched)
    // et on fusionne dans _taskDocsCache, peuplé par le full list du login. Les overlays
    // sont ensuite recalculés sur TOUT le cache — il n'y a toujours pas de sync temps réel,
    // seule la taille du transfert change (0-3 docs au lieu de ~160).
    // `force` : fetch immédiat, sans la garde anti-rafale (~3 s). OBLIGATOIRE après une
    // écriture locale d'un doc tâche — sinon le cache resservirait l'état d'avant l'écriture.
    Future<void> _refreshTaskStatuses({bool force = false}) async {

                                final region  = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final userDoc = await _readSession(region) ?? Dvidle({});
                                var   clanId  = userDoc.get("steps.clan.clanId")?.toString() ?? "";
                                if (clanId.isEmpty) clanId = (await Deva.instance.get("session.clan.id"))?.toString() ?? "";
                                if (clanId.isEmpty) return;
                                // Détecte (une fois par clan) si l'utilisateur est admin : conditionne la
                                // cliquabilité des tâches "validating" dans le tiroir (_buildIconStatusMap).
                                final clanSecret = userDoc.get("steps.clan.clanSecret")?.toString() ?? "";
                                await _ensureIsAdmin(clanId, clanSecret, region);
                                try {
                                    // --- 1) FETCH : full list (cache froid / autre clan / filet 24 h — les
                                    // refreshs delta ne voient pas les SUPPRESSIONS de docs) ou DELTA.
                                    final now = DateTime.now();
                                    final needFull = _tasksSyncClanId != clanId || _tasksSyncCursor.isEmpty ||
                                        _lastTasksFullListAt == null ||
                                        now.difference(_lastTasksFullListAt!) > const Duration(hours: 24);
                                    final throttled = !force && _lastTasksFetchAt != null &&
                                        now.difference(_lastTasksFetchAt!) < const Duration(seconds: 3);
                                    var fetched = <dynamic>[];
                                    // Échec de lecture ISOLÉ du rendu : le tiroir EST l'écran de combat,
                                    // le laisser sans données l'affiche BLANC. Les overlays du cache
                                    // restent valides — mieux vaut un état un peu périmé qu'un écran vide.
                                    // Le cache n'est vidé qu'APRÈS un full list réussi, jamais avant.
                                    try {
                                        if (needFull) {
                                            fetched = await _cloud?.list("workers", "clans_tasks/$clanId/tasks", region: region) ?? [];
                                            _taskDocsCache.clear();
                                            _tasksSyncCursor     = "0";
                                            _tasksSyncClanId     = clanId;
                                            _lastTasksFullListAt = now;
                                            _lastTasksFetchAt    = now;
                                        } else if (!throttled) {
                                            // Recouvrement de 5 min : le curseur est un horodatage posé par
                                            // L'ÉCRIVAIN — la marge absorbe le décalage d'horloge entre les
                                            // appareils du clan (ré-ingérer un doc déjà vu est idempotent).
                                            // skipIsolationFilter : ownerId des docs = clanSecret (pas l'uid), et
                                            // la plage sur touched doit rester l'UNIQUE filtre (pas d'index
                                            // composite possible) — l'accès est gardé par la règle `list`.
                                            var since = _tasksSyncCursor;
                                            final parsed = DateTime.tryParse(since);
                                            if (parsed != null) since = parsed.subtract(const Duration(minutes: 5)).toIso8601String();
                                            fetched = await _cloud?.searchWhere("workers", "clans_tasks/$clanId/tasks",
                                                [DvWhere("touched", since, op: 'GREATER_THAN')],
                                                region: region, skipIsolationFilter: true) ?? [];
                                            _lastTasksFetchAt = now;
                                        }
                                    } catch (e) {
                                        deva_log("error", "[combat] lecture des tâches FAILED (rendu depuis le cache): $e");
                                    }
                                    // --- 2) INGESTION des docs frais (0-3 en régime normal) : cache + miroir
                                    // local — mêmes écritures par doc que l'ancien full refresh.
                                    for (final d in fetched) {
                                        final id = d.get("docId")?.toString() ?? "";
                                        if (id.isEmpty) continue;
                                        _taskDocsCache[id] = d;
                                        final touched = d.get("touched")?.toString() ?? "";
                                        if (touched.compareTo(_tasksSyncCursor) > 0) _tasksSyncCursor = touched;
                                        await _ingestTaskDoc(d);   // clone → mémorise original + hydrate tuning
                                        await deva_set("tasks.$id.status",   d.get("status")?.toString()   ?? "");   // statut RÉEL (le rendu est dérivé plus bas)
                                        await deva_set("tasks.$id.assignee", d.get("assignee")?.toString() ?? "");
                                        await deva_set("tasks.$id.last",     d.get("last")?.toString()     ?? "");
                                        await deva_set("tasks.$id.dead",     d.get("dead")?.toString()     ?? "");
                                        await deva_set("tasks.$id.revive",   d.get("revive")?.toString()   ?? "");
                                        // enabled/visible : mirrorés AUSSI au delta — une bascule admin faite
                                        // sur un autre appareil arrive désormais sans attendre le prochain login.
                                        final rawEn  = d.get("enabled");
                                        if (rawEn  != null) await deva_set("tasks.$id.enabled", rawEn == true  || rawEn.toString()  == "true");
                                        final rawVis = d.get("visible");
                                        if (rawVis != null) await deva_set("tasks.$id.visible", rawVis == true || rawVis.toString() == "true");
                                        // Textes édités par un chef : on suit le doc, pour qu'un renommage fait
                                        // par quelqu'un d'autre arrive sans attendre le prochain login. Delta
                                        // (pas de clear) : ces maps portent AUSSI les libellés de domaines,
                                        // remplis par _loadClanTasks à partir des docs `domains` que ce refresh
                                        // ne relit pas.
                                        final t = d.get("title")?.toString() ?? "";
                                        if (t.isNotEmpty) _titleOverride[id] = t;
                                        final a = d.get("acceptance")?.toString() ?? "";
                                        if (a.isNotEmpty) _acceptanceOverride[id] = a;
                                        // Tâche créée par un chef : la conf ne la connaît PAS (aucun template).
                                        // On rejoue ici la surcharge générique de _loadClanTasks pour ce seul cas
                                        // (quelques docs) → image, effort, respawn_h, type sont résolus dès que la
                                        // tuile apparaît, sans quoi un tap tomberait sur une tâche sans tuning.
                                        if (d.get("user_created") == true) {
                                            for (final k in d.keys) {
                                                if (_taskDocBlocklist.contains(k)) continue;
                                                await deva_set("tasks.$id.$k", d.get(k));
                                            }
                                        }
                                    }
                                    // --- 3) OVERLAYS recalculés sur TOUT le cache (aucune lecture cloud) :
                                    // les fenêtres de respawn/régénération dépendent de l'heure courante et
                                    // doivent être re-dérivées même sans aucun doc frais.
                                    final taskDocs   = _taskDocsCache.values.toList();
                                    final statusById = <String, String>{};
                                    // Domaine par id (champ persisté) : remplace la regex de regroupement dans
                                    // _buildIconStatusMap (fiable pour les clones {base}__{uid}).
                                    final domainById = <String, String>{};
                                    // Fenêtres de respawn (status "dead") à pousser aux tiroirs : id → [dead, revive].
                                    final progressById = <String, List<String>>{};
                                    for (final d in taskDocs) {
                                        final id = d.get("docId")?.toString() ?? "";
                                        if (id.isEmpty) continue;
                                        final st     = d.get("status")?.toString() ?? "";
                                        final dead   = d.get("dead")?.toString()   ?? "";
                                        final revive = d.get("revive")?.toString() ?? "";
                                        final dom = d.get("domain")?.toString() ?? "";
                                        if (dom.isNotEmpty) domainById[id] = dom;
                                        // Fenêtre de respawn/régénération : mortelle "dead" = respawn, immortelle
                                        // "alive" = régénération XP (0 % au dead → 100 % au revive). Overlay ET barre
                                        // ne vivent que TANT QUE la fenêtre court (now < revive) : passé le revive, la
                                        // tâche « ressuscite » (ni crâne ni pansement, re-disponible).
                                        final hasWindow    = dead.isNotEmpty && revive.isNotEmpty;
                                        final reviveFuture = hasWindow &&
                                            (DateTime.tryParse(revive)?.toUtc().isAfter(DateTime.now().toUtc()) ?? false);
                                        // Statut de RENDU (crâne / pansement / rien), dérivé de la fenêtre. Ne remplace
                                        // jamais le statut réel du miroir : sert uniquement aux overlays du tiroir.
                                        String renderSt = st;
                                        if (st == "dead") {
                                            renderSt = reviveFuture ? "dead" : "";          // crâne uniquement pendant le respawn
                                        } else if (st == "alive") {
                                            renderSt = (hasWindow && reviveFuture) ? "cure" : "";  // pansement pendant la régénération
                                        }
                                        statusById[id] = renderSt;
                                        if ((st == "dead" || st == "alive") && reviveFuture) {
                                            progressById[id] = [dead, revive];
                                        }
                                    }
                                    // Vocabulaire visuel du mode courant (ce qui grise / ce qui masque), reposé
                                    // avant le push de statuts pour un rendu correct dès la 1re frame. Sans
                                    // condition : un drapeau « déjà déclaré » laisserait le tiroir en vocabulaire
                                    // ADMIN après un logout ou une sortie de mode ratée (tâche morte cliquable).
                                    _declareTiroirVocabulary();
                                    // Libellés surchargés AVANT les clones : _buildClonesMap reconstruit
                                    // « <titre> - <prénom> » à partir de _titleOverride.
                                    _notifyTiroirLabels(_titleOverride);
                                    _notifyTiroirClones(await _buildClonesMap(taskDocs));
                                    // Tuiles NEUVES (tâches user-created) : repoussées à chaque refresh, pas
                                    // seulement au login — un joueur déjà lancé voit la tâche créée par le chef
                                    // dès qu'il entre dans un tiroir. Le canal est global et idempotent.
                                    _notifyTiroirAdditions(await _buildAdditionsMap(taskDocs));
                                    // Grisage (enabled) poussé dans les DEUX modes : source = la conf
                                    // (miroir de Firestore). enabled:false grise en jeu (inerte) comme en admin.
                                    _notifyTiroirDomains(await _buildEnabledMap());
                                    if (_adminMode) {
                                        // Mode chef : vocabulaire d'ADMINISTRATION — uniquement les croix des
                                        // cachées (pas d'overlays de cycle de vie ni de barres de respawn).
                                        _notifyTiroirStatuses(await _buildHiddenStatusMap());
                                        _notifyTiroirProgress(const {});
                                    } else {
                                        // Jeu : statuts de cycle de vie, mais visible:false PRIME (icône masquée,
                                        // donc pas de flamme) → superposition de adm_hidden.
                                        final gameStatus = _buildIconStatusMap(statusById, domainById);
                                        (await _buildHiddenStatusMap()).forEach((id, st) => gameStatus[id] = st);
                                        _notifyTiroirStatuses(gameStatus);
                                        _notifyTiroirProgress(progressById);
                                    }
                                    // Badge « boss » (XP) : poussé dans les DEUX modes (canal indépendant du
                                    // statut). En admin, sert de repère « déjà recommandée » ; en jeu, appâte.
                                    _notifyTiroirRecommended(_buildRecommendedSet(taskDocs, domainById));
                                } catch (e) {
                                    deva_log("error", "[combat] _refreshTaskStatuses FAILED: $e");
                                }
                                // Heaume / bouton « + » / bordure : posés sur les TEMPLATES de conf ici, donc un
                                // sous-tiroir ouvert juste après (seldomain navigue après ce refresh) naît déjà
                                // dans le bon état — les pages <domaine>_tasks n'ont pas d'action `appear`.
                                await _syncChiefUi();
    }

    // Construit la map nom_icône → statut de rendu pour TOUS les tiroirs (fusionnée) :
    //  - feuille (suffixe _NN) : son statut propre (assigned/validating/dead → overlay + grisé) ;
    //  - icône de domaine CONTENEUR (a des feuilles) : "busy" (flamme) si une feuille est assigned ;
    //    sinon, si une feuille est validating (validation en attente, rien en cours), "review"
    //    (main) pour un admin qui peut juger, "busy" (flamme) pour un non-admin ; reste cliquable
    //    dans tous les cas ; dead ignoré → l'icône domaine n'est pas modifiée ;
    //  - tâche directe (icône domaine sans feuille) : son statut propre.
    Map<String, String> _buildIconStatusMap(Map<String, String> statusById,
        [Map<String, String> domainById = const {}]) {

                final result          = <String, String>{};
                final childrenByDomain = <String, List<String>>{};
                // Badge "busy" au niveau ENFANT-DOMAINE (<domaine>__<owner>) : cible les icônes
                // dépliées du combat/tiroir pour un domaine multiple. Émis en plus du <domaine>
                // (domaine normal) — l'icône inexistante est ignorée par le tiroir.
                final childrenByChildDomain = <String, List<String>>{};
                statusById.forEach((id, st) {
                    // Pour un admin, une tâche "validating" doit rester CLIQUABLE (afin de la
                    // juger) : on la pousse en "review" (overlay MAIN, non verrouillée) au lieu de
                    // "validating" (que le tiroir grise/verrouille). Statut réel conservé pour
                    // le calcul "busy" des domaines conteneurs. Pour un non-admin, "validating"
                    // reste tel quel (flamme + verrouillé).
                    final renderSt = (_isAdmin && st == "validating") ? "review" : st;
                    // Domaine : champ persisté (fiable pour les clones {base}__{uid}), repli
                    // sur l'ancienne regex de suffixe pour les docs antérieurs sans `domain`.
                    final domain = domainById[id] ??
                        (_leafTaskRe.firstMatch(id) != null
                            ? id.substring(0, _leafTaskRe.firstMatch(id)!.start)
                            : "");
                    final owner = id.contains('__') ? id.substring(id.indexOf('__') + 2) : "";
                    if (domain.isNotEmpty) {
                        if (renderSt == "assigned" || renderSt == "validating"
                            || renderSt == "dead" || renderSt == "cure" || renderSt == "busy"
                            || renderSt == "review") result[id] = renderSt;
                        (childrenByDomain[domain] ??= <String>[]).add(st);
                        if (owner.isNotEmpty) {
                            (childrenByChildDomain["${domain}__$owner"] ??= <String>[]).add(st);
                        }
                    } else {
                        if (renderSt == "assigned" || renderSt == "validating"
                            || renderSt == "dead" || renderSt == "cure" || renderSt == "busy"
                            || renderSt == "review") result[id] = renderSt;
                    }
                });
                childrenByDomain.forEach((domain, sts) {
                    if (sts.any((s) => s == "assigned")) {
                        result[domain] = "busy";
                    } else if (sts.any((s) => s == "validating")) {
                        // Aucune tâche en cours, seulement de la validation en attente :
                        // main pour l'admin (qui peut juger), flamme pour les autres.
                        result[domain] = _isAdmin ? "review" : "busy";
                    }
                });
                childrenByChildDomain.forEach((childDomain, sts) {
                    if (sts.any((s) => s == "assigned")) {
                        result[childDomain] = "busy";
                    } else if (sts.any((s) => s == "validating")) {
                        result[childDomain] = _isAdmin ? "review" : "busy";
                    }
                });
                return result;
    }

    //-----------------------------------------------------------------------
    //-- Combat task selection ---------------------------------------------
    //-----------------------------------------------------------------------
    // Plus de handler par icône : la sélection est dispatchée par deux handlers
    // génériques préfixés enregistrés dans register() :
    //   - "seltask.<id>"      -> _selectTask("<id>")
    //   - "seldomain.<dom>"   -> ouvre l'écran "<dom>_tasks" si le domaine est enabled

    //-----------------------------------------------------------------------
    //-- Task take (verrou + persistance + affichage combat) ----------------
    //-----------------------------------------------------------------------

    Future<void> _selectTask(String taskId) async {

                                // Joueur mort (0 PV) : sélection de tâche interdite (double garde avec le scrim UI).
                                if ((await deva_get("session.player_dead")) == true) return;

                                // Une tâche est DÉJÀ en cours → aucune sélection possible. Garde autoritaire,
                                // et pas seulement cosmétique : masquer le tiroir ne suffit pas. L'écran combat
                                // le masque bien, mais son appear est asynchrone (fenêtre de tap), et les 19
                                // sous-tiroirs <domaine>_tasks, eux, ne masquent RIEN (on_tiroir_appear ne
                                // regarde pas l'état de combat) — un tap rapide sur un domaine y déposait le
                                // joueur avec toutes les tâches prenables. Sans cette garde, la 1re tâche restait
                                // "assigned" dans Firestore sans plus personne pour la résoudre (orpheline jusqu'au
                                // respawn). Retour au combat : le tap égaré ramène le joueur à SA tâche, et
                                // on_combat_appear réconcilie si l'état local était périmé.
                                final ongoing = (await Deva.instance.get("session.active_task"))?.toString() ?? "";
                                if (ongoing.isNotEmpty) {
                                    deva_log("info", "[combat] sélection ignorée, tâche déjà en cours: $ongoing");
                                    DvOrb.navigate_reset("combat");
                                    return;
                                }

                                _stopValidationPolling();                 // nouvelle sélection → ancien poll obsolète
                                final ownerId = _cloud?.currentUser()?.providerUid ?? "";
                                if (_userId.isEmpty || ownerId.isEmpty) {
                                    deva_log("error", "[combat] _selectTask: contexte incomplet (user=$_userId owner=$ownerId)");
                                    return;
                                }

                                // clanId/clanSecret : doc session (autoritatif), repli sur le store local rempli par dvsession.
                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final userDoc    = await _readSession(region) ?? Dvidle({});
                                var   clanId     = userDoc.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = userDoc.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty) clanId = (await Deva.instance.get("session.clan.id"))?.toString() ?? "";
                                if (clanId.isEmpty) {
                                    deva_log("error", "[combat] _selectTask: clanId introuvable");
                                    return;
                                }

                                final resourceId = "${clanId}_$taskId";
                                final holderId   = "${ownerId}_$_userId";

                                // Lecture autoritaire du statut AVANT tout verrou. Le get unitaire est autorisé
                                // par les règles (clanSecret == ownerId du doc). Permet de brancher sur "validating"
                                // (validation admin) sans poser de verrou ni assigner la tâche.
                                String status   = "alive";
                                String assignee = "";
                                // Fenêtre passée (now >= revive) → mortelle "dead" ressuscitée = re-prenable (respawn).
                                bool   revived  = false;
                                if (clanSecret.isNotEmpty) {
                                    final taskDoc = await _cloud?.read("workers", "clans_tasks/$clanId/tasks", taskId,
                                        region: region, ownerId: clanSecret);
                                    status   = taskDoc?.get("status")?.toString()   ?? "alive";
                                    assignee = taskDoc?.get("assignee")?.toString() ?? "";
                                    final revive = taskDoc?.get("revive")?.toString() ?? "";
                                    revived = revive.isNotEmpty &&
                                        !(DateTime.tryParse(revive)?.toUtc().isAfter(DateTime.now().toUtc()) ?? false);
                                }

                                // BRANCHE A — tâche en attente de validation. Seul un admin du clan peut trancher ;
                                // un non-admin ne déclenche rien (juste un rafraîchissement des overlays).
                                if (status == "validating") {
                                    await deva_set("tasks.$taskId.status",   status);
                                    await deva_set("tasks.$taskId.assignee", assignee);

                                    final clanDoc = clanSecret.isEmpty ? null : await _cloud?.read(
                                        "workers", "clans", clanId, ownerId: clanSecret, region: region);
                                    final admins  = List<dynamic>.from(clanDoc?.get("admins") as List? ?? []);
                                    if (!admins.contains(_userId)) {
                                        deva_log("info", "[combat] tâche en validation, non-admin → no-op: $taskId");
                                        await _refreshTaskStatuses(force: true);
                                        return;
                                    }
                                    // Validation croisée : un admin ne peut pas valider SA PROPRE tâche (il doit la
                                    // faire trancher par un autre admin, comme un joueur lambda). No-op sinon.
                                    if (assignee == _userId) {
                                        deva_log("info", "[combat] admin ne peut pas valider sa propre tâche: $taskId");
                                        await _refreshTaskStatuses(force: true);
                                        return;
                                    }

                                    // Admin → mode revue : on stocke le contexte et on navigue vers combat.
                                    // Aucun verrou, aucun _assignTask, active_task inchangé.
                                    deva_log("info", "[combat] admin ouvre la validation: $taskId (assignee=$assignee)");
                                    await Deva.instance.set("session.clan.id",         clanId);
                                    await Deva.instance.set("session.review_task",     resourceId);
                                    await Deva.instance.set("session.review_assignee", assignee);
                                    DvOrb.navigate_reset("combat");
                                    return;
                                }

                                final lock = Deva.instance.module("dvlock") as dvlock?;
                                final ok   = await lock?.lock(resourceId, holderId) ?? false;
                                if (!ok) {
                                    deva_log("info", "[combat] tâche déjà prise (verrou): $resourceId");
                                    return;
                                }

                                // Le verrou ne protège que la course SIMULTANÉE. Une tâche assignée plus tôt
                                // (verrou déjà expiré côté TTL) doit rester imprenable → on revérifie le statut
                                // (déjà lu ci-dessus) au moment de la sélection. Exception : une mortelle "dead"
                                // dont la fenêtre est passée (revived) « ressuscite » et redevient prenable.
                                if (status.isNotEmpty && status != "alive" && !(status == "dead" && revived)) {
                                    deva_log("info", "[combat] tâche déjà prise (status=$status): $taskId");
                                    // Miroir local + tiroir rafraîchis pour refléter l'état réel (grisé + flamme).
                                    await deva_set("tasks.$taskId.status",   status);
                                    await deva_set("tasks.$taskId.assignee", assignee);
                                    await lock?.release(resourceId);
                                    await _refreshTaskStatuses(force: true);
                                    return;
                                }

                                // Verrou acquis et tâche encore vivante → on pose les valeurs locales (rapides) et on navigue IMMÉDIATEMENT.
                                // navigate_reset vide la pile et recrée une page combat unique (évite les doublons
                                // /combat qui déclenchent le back_target vers dashboard). L'action appear de combat
                                // lance on_combat_appear (icône seule), qui lit session.active_task déjà posé ci-dessous.
                                await Deva.instance.set("session.clan.id",     clanId);
                                await Deva.instance.set("session.active_task", resourceId);
                                // Marque cette sélection locale : l'appear combat immédiat affichera la tâche sans
                                // réconcilier (cf. _freshlySelected) — évite la course avec l'assignation ci-dessous.
                                _freshlySelected = resourceId;
                                DvOrb.navigate_reset("combat");

                                // Persistance Firestore en arrière-plan (n'empêche pas l'affichage immédiat).
                                userDoc.rem("docId");
                                userDoc.set("active_task", resourceId);
                                await _cloud?.write("workers", "users", _sessionDocId(), userDoc, region: region);
                                _invalidateSessionCache();
                                if (clanSecret.isNotEmpty) {
                                    try {
                                        await _assignTask(clanId, clanSecret, taskId, region);
                                        // Req1 : on ne libère le verrou qu'APRÈS le changement de statut confirmé
                                        // dans Firestore — sinon un autre joueur pourrait reprendre la tâche entre
                                        // la libération et l'écriture du statut.
                                        await lock?.release(resourceId);
                                    } catch (e) {
                                        // Écriture du statut échouée → on GARDE le verrou (il expirera via le TTL)
                                        // pour ne pas exposer une tâche à moitié prise.
                                        deva_log("error", "[combat] _assignTask échec, verrou conservé jusqu'au TTL: $e");
                                    }
                                } else {
                                    // Sans clanSecret, le statut ne peut pas être écrit → verrou conservé (TTL).
                                    deva_log("warning", "[combat] clanSecret introuvable, clans_tasks non mis à jour, verrou conservé");
                                }
    }

    // Assigne une tâche dans clans_tasks/{clanId}/tasks/{taskId} (read-modify-write pour
    // ownerId du doc = clanSecret (exigé par les règles Firestore, comme _persistTaskResults).
    // write() fait un PATCH sans updateMask → remplacement complet du doc : on reconstruit donc
    // tous les champs. `enabled` est repris du miroir local rempli par _loadClanTasks (le read
    // unitaire sur clans_tasks est refusé par les règles — seul le list passe).
    Future<void> _assignTask(String clanId, String clanSecret, String taskId, String region) async {

                                final coll       = "clans_tasks/$clanId/tasks";
                                final last       = DateTime.now().toUtc().toIso8601String();
                                final enabledRaw = await deva_get("tasks.$taskId.enabled");
                                final enabled    = enabledRaw == null ? true : (enabledRaw == true || enabledRaw.toString() == "true");

                                // PATCH = remplacement complet → préserver la fenêtre de régénération (dead/revive)
                                // sinon une simple (ré)assignation l'efface dans Firestore (bug XP remis à plein).
                                final dead   = (await deva_get("tasks.$taskId.dead"))?.toString()   ?? "";
                                final revive = (await deva_get("tasks.$taskId.revive"))?.toString() ?? "";

                                final doc = Dvidle({});
                                doc.set("ownerId",  clanSecret);
                                doc.set("clanId",   clanId);
                                doc.set("enabled",  enabled);
                                doc.set("assignee", _userId);
                                doc.set("last",     last);
                                doc.set("status",   "assigned");
                                doc.set("proof",    "");                   // merge : vider explicitement (plus supprimé par le PATCH)
                                if (dead.isNotEmpty)   doc.set("dead",   dead);
                                if (revive.isNotEmpty) doc.set("revive", revive);
                                await _applyIdentityFields(doc, taskId);   // préserve domain + champs de clone
                                await _cloud?.write("workers", coll, taskId, doc, region: region, ownerId: clanSecret);

                                // Miroir local (cohérent avec _loadClanTasks). dead/revive laissés intacts.
                                await deva_set("tasks.$taskId.assignee", _userId);
                                await deva_set("tasks.$taskId.status",   "assigned");
                                await deva_set("tasks.$taskId.last",     last);
                                deva_log("info", "[combat] tâche assignée: $taskId → $_userId");
    }

    // Séparateur d'ID de clone : "{baseId}__{userId}". Les baseId n'ont jamais de
    // double underscore → l'original est récupérable sans lecture ni map.
    String _cloneId(String baseId, String userId) => "${baseId}__$userId";

    // Renvoie le baseId d'un éventuel clone, sinon l'id tel quel (tâche normale).
    String _originalOf(String id) {

                        final i = id.indexOf('__');
                        return i < 0 ? id : id.substring(0, i);
    }

    // Normalise l'état légal pour le GAMEPLAY : "t" (transition adulte en cours, déclarée par le
    // tuteur mais CGU adulte pas encore acceptée) est traité exactement comme "k" (mineur). Seul
    // "a" confère les droits adultes. Défensif : la clé de session ne porte "t" qu'exceptionnellement.
    String _gameplayLegal(String raw) => raw == "t" ? "k" : raw;

    // L'utilisateur (legal_state "k"/"a") qualifie-t-il pour une tâche multiple ?
    bool _qualifiesForMultiple(String multiple, String legalState) =>
        multiple == 'all' || multiple == _gameplayLegal(legalState);

    // « who » (k/a/all) d'une tâche, piloté par la CONF : flag de la TÂCHE
    // (tasks.<id>.multiple) sinon flag du DOMAINE (domains.<d>.multiple), sinon "".
    // Un domaine « multiple » clone donc toutes ses tâches sans les flagger une à une.
    // Exclusion mutuelle par convention (un domaine multiple ne flagge pas ses tâches).
    Future<String> _taskMultipleWho(String taskId, String domain) async {

                        final t = (await deva_get("tasks.$taskId.multiple"))?.toString() ?? "";
                        if (t.isNotEmpty) return t;
                        if (domain.isEmpty) return "";
                        return (await deva_get("domains.$domain.multiple"))?.toString() ?? "";
    }

    // Estampille de delta-sync : posée sur CHAQUE écriture d'un doc tâche (création via
    // _newTaskDoc, réécriture complète via _applyIdentityFields, écritures partielles à la
    // main). _refreshTaskStatuses ne relit que les docs dont touched > curseur local —
    // une écriture non estampillée serait INVISIBLE des autres appareils jusqu'à leur
    // prochain login.
    void _stampTouched(Dvidle doc) => doc.set("touched", DateTime.now().toUtc().toIso8601String());

    // Fabrique un doc de tâche (base ou clone). Les champs de clone (original/owner/
    // owner_name/label) ne sont posés que s'ils sont fournis. ownerId=clanSecret est
    // exigé par les règles Firestore (batchWrite n'injecte pas ownerId).
    Dvidle _newTaskDoc(String clanId, String clanSecret, bool enabled,
        {String domain = '', String original = '', String owner = '',
         String ownerName = '', String label = '', bool visible = true}) {

            final t = Dvidle({});
            _stampTouched(t);
            t.set("ownerId",  clanSecret);
            t.set("clanId",   clanId);
            t.set("enabled",  enabled);
            t.set("visible",  visible);
            t.set("assignee", "");
            t.set("last",     "");
            t.set("status",   "alive");
            t.set("recommended", "");                          // « boss » recommandé par le chef (ISO), vide par défaut
            if (domain.isNotEmpty)    t.set("domain",     domain);
            if (original.isNotEmpty)  t.set("original",   original);
            if (owner.isNotEmpty)     t.set("owner",      owner);
            if (ownerName.isNotEmpty) t.set("owner_name", ownerName);
            if (label.isNotEmpty)     t.set("label",      label);
            return t;
    }

    // Ingère un doc de tâche chargé depuis Firestore : miroir local (enabled/status/
    // assignee/last/dead/revive) ET, pour un clone, mémorise l'original + hydrate le
    // tuning (effort/type/respawn_h) depuis la couche tasks-base fusionnée dans
    // tasks.<base> → getTaskXPs/_writeVerdict fonctionnent tels quels avec l'id clone.
    Future<void> _ingestTaskDoc(dynamic d) async {

                            final id = d.get("docId")?.toString() ?? "";
                            if (id.isEmpty) return;
                            // Miroir des champs d'identité (persistés sur le doc) → réappliqués lors des
                            // réécritures PATCH complètes (_assignTask/_writeVerdict) qui, sinon, les effacent.
                            await deva_set("tasks.$id.domain", d.get("domain")?.toString() ?? "");
                            // État « boss » (recommended) : mirroré localement → lu par _tiroirSelector
                            // (option Recommander), _buildRecommendedSet (badge XP) et _applyVerdict (bonus XP),
                            // et réappliqué par _applyIdentityFields lors des réécritures PATCH complètes.
                            await deva_set("tasks.$id.recommended", d.get("recommended")?.toString() ?? "");
                            final original = d.get("original")?.toString() ?? "";
                            if (original.isNotEmpty) {
                                _cloneOriginal[id] = original;
                                await deva_set("tasks.$id.original",   original);
                                await deva_set("tasks.$id.owner",      d.get("owner")?.toString()      ?? "");
                                await deva_set("tasks.$id.owner_name", d.get("owner_name")?.toString() ?? "");
                                await deva_set("tasks.$id.label",      d.get("label")?.toString()      ?? "");
                                // Tuning résolu depuis la couche tasks-base (fusionnée dans tasks.<base>) →
                                // getTaskXPs/_writeVerdict fonctionnent tels quels avec l'id clone.
                                for (final k in const ['effort', 'type', 'respawn_h']) {
                                    final v = await deva_get("tasks.$original.$k");
                                    if (v != null) await deva_set("tasks.$id.$k", v);
                                }
                            }
    }

    // Réapplique les champs d'identité (persistés) sur un doc reconstruit avant écriture.
    // _assignTask et _writeVerdict font un PATCH = remplacement complet du doc → sans ceci,
    // `domain` (toutes tâches) et `original/owner/owner_name/label` (clones) seraient perdus.
    Future<void> _applyIdentityFields(Dvidle doc, String taskId,
                                      {bool clearRecommended = false}) async {

                            // Toute réécriture complète change l'état → estampille de delta-sync.
                            _stampTouched(doc);
                            final domain = (await deva_get("tasks.$taskId.domain"))?.toString() ?? "";
                            if (domain.isNotEmpty) doc.set("domain", domain);
                            // État « boss ». Deux cas :
                            //  - clearRecommended (verdict ACCEPTÉ) : la recommandation vient d'être
                            //    consommée, on l'efface EXPLICITEMENT — l'omettre ne suffirait pas, le
                            //    write dvcloud est un deep-merge qui préserverait l'ancienne valeur.
                            //  - sinon (assignation, mise en validation, verdict REFUSÉ) : on la
                            //    réapplique telle quelle, sinon le PATCH complet la perdrait.
                            if (clearRecommended) {
                                doc.set("recommended", "");
                            } else {
                                final rec = (await deva_get("tasks.$taskId.recommended"))?.toString() ?? "";
                                if (rec.isNotEmpty) doc.set("recommended", rec);
                            }
                            // Surcharges texte (tâche renommée par le chef) : portées par le doc de BASE. Un
                            // PATCH complet (_assignTask/_writeVerdict) les effacerait → on les réapplique
                            // depuis les maps d'override. Les clones n'en portent pas (héritage via _originalOf).
                            final base = _originalOf(taskId);
                            if (base == taskId) {
                                final t = _titleOverride[base];
                                if (t != null && t.isNotEmpty) doc.set("title", t);
                                final a = _acceptanceOverride[base];
                                if (a != null && a.isNotEmpty) doc.set("acceptance", a);
                            }
                            final original = (await deva_get("tasks.$taskId.original"))?.toString() ?? "";
                            if (original.isEmpty) return;
                            doc.set("original", original);
                            final owner     = (await deva_get("tasks.$taskId.owner"))?.toString()      ?? "";
                            final ownerName = (await deva_get("tasks.$taskId.owner_name"))?.toString() ?? "";
                            final label     = (await deva_get("tasks.$taskId.label"))?.toString()      ?? "";
                            if (owner.isNotEmpty)     doc.set("owner",      owner);
                            if (ownerName.isNotEmpty) doc.set("owner_name", ownerName);
                            if (label.isNotEmpty)     doc.set("label",      label);
    }

    // Construit la table de clones à pousser au tiroir : nomTemplate → [{id, label, action}, …].
    // Deux modes, tous deux pilotés par la CONF :
    //   - DOMAINE multiple (domains.<d>.multiple) : la clé <d> (icône du combat/tiroir) reçoit
    //     une entrée ENFANT-DOMAINE par `owner` distinct (action seldomain.<d>__<owner>) ; les
    //     tâches du domaine (clés <baseTask>) ne reçoivent QUE le clone de l'owner sélectionné
    //     (session.selected_owner), label de base (sans prénom).
    //   - TÂCHE multiple dans un domaine normal (tasks.<id>.multiple) : la clé <baseTask> reçoit
    //     TOUS les clones (label figé avec prénom, action seltask.<clone>).
    // On amorce une entrée VIDE pour chaque template multiple (domaine + tâches concernées) →
    // le tiroir masque le template même sans clone (jamais d'icône de base sélectionnable).
    Future<Map<String, List<Map<String, String>>>> _buildClonesMap(List<dynamic> taskDocs) async {

                            final clones        = <String, List<Map<String, String>>>{};
                            final selectedOwner = (await Deva.instance.get("session.selected_owner"))?.toString() ?? "";

                            // Domaines multiple (piloté conf).
                            final multiDomains = <String>{};
                            final domStore = await deva_get("domains");
                            if (domStore is Dvidle) {
                                for (final d in domStore.keys) {
                                    if (((domStore.get("$d.multiple")?.toString()) ?? "").isNotEmpty) multiDomains.add(d);
                                }
                            }
                            // Amorce des templates à masquer : icône de domaine multiple (combat/tiroir) +
                            // chaque tâche de base multiple, soit par flag de tâche, soit par domaine multiple.
                            for (final d in multiDomains) clones[d] = [];
                            final taskStore = await deva_get("tasks");
                            if (taskStore is Dvidle) {
                                for (final id in taskStore.keys) {
                                    if (id.contains('__')) continue;   // ignore les clones (ids de base seulement)
                                    final m   = taskStore.get("$id.multiple")?.toString() ?? "";
                                    final dom = taskStore.get("$id.domain")?.toString()   ?? "";
                                    if (m.isNotEmpty || multiDomains.contains(dom)) clones[id] = [];
                                }
                            }

                            final seenChildDomain = <String>{};   // dédup enfant-domaine par (domain, owner)
                            for (final d in taskDocs) {
                                final original = d.get("original")?.toString() ?? "";
                                if (original.isEmpty) continue;
                                final id = d.get("docId")?.toString() ?? "";
                                if (id.isEmpty) continue;
                                final domain    = d.get("domain")?.toString()     ?? "";
                                final owner     = d.get("owner")?.toString()      ?? "";
                                final ownerName = d.get("owner_name")?.toString() ?? "";
                                final label     = d.get("label")?.toString()      ?? "";

                                if (multiDomains.contains(domain)) {
                                    // Entrée enfant-domaine (une par owner) sous la clé du domaine.
                                    final childKey = "$domain::$owner";
                                    if (owner.isNotEmpty && seenChildDomain.add(childKey)) {
                                        (clones[domain] ??= []).add({
                                            "id":     "${domain}__$owner",
                                            "label":  ownerName,
                                            "action": "seldomain.${domain}__$owner",
                                        });
                                    }
                                    // Tâches du domaine : seulement le clone de l'owner sélectionné, label de
                                    // base (le template porte déjà `@@@T:dt_t_<base>@@@` → on laisse label vide).
                                    if (owner.isNotEmpty && owner == selectedOwner) {
                                        (clones[original] ??= []).add({"id": id, "label": "", "action": "seltask.$id"});
                                    }
                                } else {
                                    // Tâche-multiple dans un domaine normal : tous les clones, label figé (prénom).
                                    // Si la tâche a été renommée (override), reconstruire « <titre> - <prénom> »
                                    // à partir du titre surchargé plutôt que du label figé au moment du clonage.
                                    final ov  = _titleOverride[original];
                                    final lbl = (ov != null && ov.isNotEmpty && ownerName.isNotEmpty)
                                        ? "$ov - $ownerName"
                                        : label;
                                    (clones[original] ??= []).add({"id": id, "label": lbl, "action": "seltask.$id"});
                                }
                            }
                            return clones;
    }

    void _notifyTiroirClones(Map<String, List<Map<String, String>>> clonesByBase) {

                            final fn = ActionRegistry.get("dvtiroir.update_clones");
                            fn?.call(null, clonesByBase);
    }

    // Construit la table des tuiles NEUVES (tâches user-created) à injecter dans les tiroirs :
    // dvid de tiroir "<domaine>_tasks/tiroir" → [{id, image, label, action}]. Ces tâches n'ont aucun
    // template en config → elles ne peuvent apparaître que par ce canal. `image`/`label` proviennent
    // du doc (nounours + titre par défaut, ou valeurs éditées). Les clones (champ `original`) sont
    // exclus (gérés par _buildClonesMap).
    Future<Map<String, List<Map<String, String>>>> _buildAdditionsMap(List<dynamic> taskDocs) async {

                            final additions = <String, List<Map<String, String>>>{};
                            for (final d in taskDocs) {
                                if (d.get("user_created") != true) continue;
                                if ((d.get("original")?.toString() ?? "").isNotEmpty) continue;   // clone → pas ici
                                final id     = d.get("docId")?.toString() ?? "";
                                final domain = d.get("domain")?.toString() ?? "";
                                if (id.isEmpty || domain.isEmpty) continue;
                                final image  = (d.get("image")?.toString() ?? "").isNotEmpty
                                    ? d.get("image").toString() : _defaultTaskImage;
                                final label  = d.get("title")?.toString() ?? "";
                                (additions["${domain}_tasks/tiroir"] ??= []).add({
                                    "id":     id,
                                    "image":  image,
                                    "label":  label,
                                    "action": "seltask.$id",
                                });
                            }
                            // La FÉE emprunte le même canal, pour la même raison que les tâches
                            // créées par un chef : c'est le SEUL qui porte une image, et elle n'a
                            // aucun template en config (elle n'existe que dix minutes par mois).
                            // Sa monstre-tâche, elle, est masquée par _buildHiddenStatusMap : le
                            // nombre de tuiles ne bouge pas, la fée prend bien LA PLACE d'un monstre.
                            if (_fairyTiroirDvid.isNotEmpty) {
                                (additions[_fairyTiroirDvid] ??= []).add(_fairyAddition);
                            }
                            return additions;
    }

    void _notifyTiroirAdditions(Map<String, List<Map<String, String>>> additionsByTiroir) {

                            final fn = ActionRegistry.get("dvtiroir.update_additions");
                            fn?.call(null, additionsByTiroir);
    }

    // Pousse les libellés surchargés (tâches renommées par le chef) aux DvTiroir, par name d'icône.
    // Le `label:` de config est statique → ce canal le remplace au runtime. Map vide = retour config.
    void _notifyTiroirLabels(Map<String, String> labelsByName) {

                            final fn = ActionRegistry.get("dvtiroir.update_labels");
                            fn?.call(null, labelsByName);
    }

    // Crée en Firestore les clones de l'utilisateur courant pour les tâches multiple
    // ACTIVÉES qu'il qualifie. Appelé à la création du clan (créateur) et au join
    // (arrivant). `enabledBases` = ensemble des baseId multiple activés pour le clan
    // (stocké sur le doc clan, champ `enabled_multiple`). Chaque membre n'écrit que
    // ses propres clones → il connaît son nom (label figé) et son legal_state.
    Future<void> _createMyClones(String clanId, String clanSecret, String region,
        Set<String> enabledBases) async {

            if (enabledBases.isEmpty) return;
            final userId     = _userId;
            final name       = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
            final legalState = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "";
            if (userId.isEmpty) return;

            // `enabledBases` = tâches multiple activées pour le clan (déjà filtrées par la
            // conf à la persistance). who/domain relus depuis la CONF (tâche OU domaine).
            final writes = <DvCloudWrite>[];
            for (final baseId in enabledBases) {
                final domain = (await deva_get("tasks.$baseId.domain"))?.toString() ?? "";
                final who    = await _taskMultipleWho(baseId, domain);
                if (who.isEmpty) continue;
                if (!_qualifiesForMultiple(who, legalState)) continue;
                final cid    = _cloneId(baseId, userId);
                final label  = "@@@T:dt_t_$baseId@@@ - $name";
                writes.add(DvCloudWrite.set("clans_tasks/$clanId/tasks", cid,
                    _newTaskDoc(clanId, clanSecret, true,
                        domain: domain, original: baseId,
                        owner: userId, ownerName: name, label: label)));
            }
            if (writes.isNotEmpty) await _cloud?.batchWrite("workers", writes, region: region);
    }

    // Chemin de l'icône d'une tâche : LU DEPUIS LA CONFIG du DvTiroir qui la déclare
    // (icons.<taskId>.image). Le chemin est librement configurable côté conf → on ne le
    // devine JAMAIS. On parcourt les tiroirs de domaine et on renvoie l'image du premier
    // qui contient la tâche (les taskId sont uniques entre tiroirs). Repli sur l'ancienne
    // convention seulement si la tâche n'est déclarée dans aucun tiroir.
    Future<String> _taskIconPath(String taskId) async {

                            // Clone → on résout l'image de l'original (point A : même icône que l'original).
                            taskId = _originalOf(taskId);
                            // Image stockée sur le doc (tâche user-created ou image éditée) : prioritaire, car
                            // ces tâches n'ont aucune entrée `icons.<id>.image` en config.
                            final stored = (await deva_get("tasks.$taskId.image"))?.toString() ?? "";
                            if (stored.isNotEmpty) return stored;
                            for (final d in _taskDomains) {
                                final cfg = await Deva.instance.resolveRegistryItem("${d}_tasks/tiroir");
                                final img = cfg?.get("icons.$taskId.image")?.toString() ?? "";
                                if (img.isNotEmpty) return img;
                            }
                            deva_log("warning", "[combat] image introuvable en config pour '$taskId' → repli convention");
                            return _leafTaskRe.hasMatch(taskId)
                                ? "images/dt_t_$taskId.png"
                                : "images/task_${taskId}_nobg.png";
    }

    // Légende d'une tâche, identique à celle affichée dans le DvTiroir. Clone → clé de
    // l'original (le nom du propriétaire figure sur le label figé côté tiroir).
    String _taskLabel(String taskId) {

                        final base = _originalOf(taskId);
                        // Surcharge texte (tâche renommée par le chef) : affichée verbatim, sinon token conf.
                        final ov = _titleOverride[base];
                        if (ov != null && ov.isNotEmpty) return ov;
                        return _leafTaskRe.hasMatch(base) ? "@@@T:dt_t_$base@@@" : "@@@T:task_$base@@@";
    }

    // Critères d'acceptance d'une tâche (toujours une feuille en combat) → dt_a_<base>,
    // ou la description surchargée (édition chef) si présente.
    String _taskAcceptance(String taskId) {

                        final base = _originalOf(taskId);
                        final ov = _acceptanceOverride[base];
                        if (ov != null && ov.isNotEmpty) return ov;
                        return "@@@T:dt_a_$base@@@";
    }

    // Extrait le taskId d'un active_task "{clanId}_{taskId}". Repli robuste : au démarrage
    // session.clan.id peut ne pas être encore restauré par dvsession → on retire le préfixe UUID.
    String _taskIdFromActive(String activeTask, String clanId) {

                                if (clanId.isNotEmpty && activeTask.startsWith("${clanId}_")) {
                                    return activeTask.substring(clanId.length + 1);
                                }
                                final m = RegExp(r'^[0-9a-fA-F-]{36}_').firstMatch(activeTask);
                                return m != null ? activeTask.substring(m.end) : activeTask;
    }

    void _notifyTiroirExtras() {

                                ActionRegistry.get("dvtiroir.update_extras")?.call(null, _adminMode
                                    ? [{
                                        "id":     _admAddIcon,
                                        "image":  "images/small/adm_add.png",
                                        "label":  "@@@T:adm_add@@@",
                                        "action": "worker.adm_add_task",
                                      }]
                                    : <Map<String, String>>[]);
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
