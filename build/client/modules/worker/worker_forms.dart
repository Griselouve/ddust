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
// --- worker extension — Formulaires (inspire IA, édition)
// -----------------------------------------------------------------------------
extension Worker_forms on worker {

    void _register_forms() {

                                // Édition d'une tâche/domaine (écran rename_task, masks commons/inspireform_*).
                                ActionRegistry.register("worker.on_rename_task_appear",       on_rename_task_appear);

                                ActionRegistry.register("worker.on_rename_task_name_changed", on_rename_task_name_changed);

                                ActionRegistry.register("worker.on_rename_task_desc_changed", on_rename_task_desc_changed);

                                ActionRegistry.register("worker.on_rename_effort_changed",    on_rename_effort_changed);

                                ActionRegistry.register("worker.on_rename_respawn_changed",   on_rename_respawn_changed);

                                ActionRegistry.register("worker.on_rename_type_changed",      on_rename_type_changed);

                                ActionRegistry.register("worker.on_inspire_task",            on_inspire_task);

                                ActionRegistry.register("worker.on_replay_task",             on_replay_task);

                                ActionRegistry.register("worker.on_confirm_rename_task",      on_confirm_rename_task);

                                ActionRegistry.register("worker.on_player_name_appear",   on_player_name_appear);

                                ActionRegistry.register("worker.on_player_name_changed",  on_player_name_changed);

                                ActionRegistry.register("worker.on_confirm_player_name",  on_confirm_player_name);

                                ActionRegistry.register("worker.on_rename_appear",        on_rename_appear);

                                ActionRegistry.register("worker.on_rename_changed",       on_rename_changed);

                                ActionRegistry.register("worker.on_rename_confirm",       on_rename_confirm);

                                ActionRegistry.register("worker.create_player",             create_player);

                                ActionRegistry.register("worker.on_create_player_appear",   on_create_player_appear);

                                ActionRegistry.register("worker.on_create_player_changed",  on_create_player_changed);

                                ActionRegistry.register("worker.on_create_player_confirm",  on_create_player_confirm);

    }

    // Applique un résultat IA aux champs <prefix>/name et <prefix>/desc, active le bouton confirm
    // et révèle le lien « Autre chose ! ». Partagé create_clan / rename_task (prefix paramétré).
    void _applyAiResultTo(String prefix, String result, DvShape? nameEntry, DvShape? descEntry) {

                                final name = _parseAiName(result);
                                final desc = _parseAiDescription(result);
                                if (name.isNotEmpty) {
                                    _aiName = name;
                                    nameEntry?.set("shape.value", name); nameEntry?.refreshUI();
                                    final confirm = DvOrb.get_shape_by_id("$prefix/confirm");
                                    confirm?.set("shape.opacity", 0.6);
                                    confirm?.set("shape.events.tap", true);
                                    confirm?.refreshUI();
                                }
                                if (desc.isNotEmpty) { descEntry?.set("shape.value", desc); descEntry?.refreshUI(); }
                                final replay = DvOrb.get_shape_by_id("$prefix/replay");
                                replay?.set("shape.visible", true); replay?.refreshUI();
    }

    // Repli statique (timeout IA) : tire une des 3 variantes <fallbackPrefix>{0..2}_name/_desc.
    Future<void> _showStaticFallbackTo(String prefix, String fallbackPrefix,
        DvShape? nameEntry, DvShape? descEntry) async {

                            final idx  = Random().nextInt(3);
                            final name = TranslationRegistry.translate("$fallbackPrefix${idx}_name");
                            final desc = TranslationRegistry.translate("$fallbackPrefix${idx}_desc");
                            if (name.isNotEmpty) {
                                _aiName = name;
                                nameEntry?.set("shape.value", name); nameEntry?.refreshUI();
                                final confirm = DvOrb.get_shape_by_id("$prefix/confirm");
                                confirm?.set("shape.opacity", 0.6);
                                confirm?.set("shape.events.tap", true);
                                confirm?.refreshUI();
                            }
                            if (desc.isNotEmpty) { descEntry?.set("shape.value", desc); descEntry?.refreshUI(); }
                            final replay = DvOrb.get_shape_by_id("$prefix/replay");
                            replay?.set("shape.visible", true); replay?.refreshUI();
    }

    // Moteur « Inspire moi » partagé (create_clan / rename_task). `prefix` = id d'écran (shapes
    // <prefix>/name, <prefix>/desc, <prefix>/confirm, <prefix>/replay). `promptName` = agent dvprompts.
    // `fallbackPrefix` != null → repli statique <fallbackPrefix>{0..2}_name/_desc sur timeout ; null →
    // pas de repli (les champs restent, réponse tardive mise en cache pour un futur « Autre chose ! »).
    Future<void> _runInspire(String prefix, String promptName, String? fallbackPrefix) async {

                                final nameEntry = DvOrb.get_shape_by_id("$prefix/name");
                                final descEntry = DvOrb.get_shape_by_id("$prefix/desc");
                                final rawDesc   = descEntry?.get("shape.value")?.toString().trim() ?? "";
                                final rawName   = nameEntry?.get("shape.value")?.toString().trim() ?? "";
                                _originalDesc ??= rawDesc;
                                _originalName ??= rawName;

                                // Nom de la langue de sortie injecté dans le prompt (consigne « reply in X »,
                                // désormais en anglais). Sert surtout de garde pour les langues non traduites
                                // (le prompt retombe sur le fragment fr mais la sortie reste dans la bonne langue).
                                // Point d'extension pour de futures langues : élargir ce mapping.
                                const langNames = {"fr": "French", "en": "English", "es": "Spanish"};
                                await deva_set("worker.inspire_lang", langNames[TranslationRegistry.currentLang] ?? "English");

                                final inputDesc = _originalDesc!.isEmpty ? "(vide)" : _originalDesc!;
                                final inputName = _originalName!.isEmpty ? "(vide)" : _originalName!;
                                await deva_set("worker.inspire_input", "nom: $inputName, description: $inputDesc");

                                final ai = Deva.instance.module("dvvertexai");
                                if (ai == null) return;
                                try { await (ai as dynamic).startVertexMotor(); } catch (_) {}

                                final prompts = Deva.instance.module("dvprompts");
                                final prompt  = prompts != null
                                    ? await (prompts as dynamic).get_prompt(promptName) as String
                                    : "";
                                deva_log("debug", "[worker] inspire prompt: $prompt");

                                final aiFuture = ((ai as dynamic).sendMessage(prompt)) as Future<String?>;
                                try {
                                    final result = await aiFuture.timeout(const Duration(seconds: 3));
                                    if (result != null) _applyAiResultTo(prefix, result, nameEntry, descEntry);
                                } on TimeoutException {
                                    if (fallbackPrefix != null) {
                                        await _showStaticFallbackTo(prefix, fallbackPrefix, nameEntry, descEntry);
                                    }
                                    // Mettre en cache la réponse IA si elle arrive après le timeout
                                    aiFuture.then((r) {
                                        if (r != null) {
                                            _cachedAiName = _parseAiName(r);
                                            _cachedAiDesc = _parseAiDescription(r);
                                        }
                                    }).catchError((_) {});
                                } catch (e) {
                                    // Échec réel (capacité IA saturée, modèle injoignable) : même repli
                                    // que le timeout, sinon le bouton ne produirait rien du tout. Avant,
                                    // sendMessage renvoyait l'erreur comme une réponse valide et le texte
                                    // « Erreur: Resource exhausted… » atterrissait dans les champs.
                                    deva_log("error", "[$prefix] _runInspire FAILED: $e");
                                    if (fallbackPrefix != null) {
                                        await _showStaticFallbackTo(prefix, fallbackPrefix, nameEntry, descEntry);
                                    }
                                }
    }

    // « Autre chose ! » partagé : rejoue la réponse IA en cache (arrivée après timeout) si présente,
    // sinon restaure les saisies originales et relance l'IA.
    Future<void> _runReplay(String prefix, String promptName, String? fallbackPrefix) async {

                                final nameEntry = DvOrb.get_shape_by_id("$prefix/name");
                                final descEntry = DvOrb.get_shape_by_id("$prefix/desc");
                                if (_cachedAiName != null) {
                                    final name = _cachedAiName!;
                                    final desc = _cachedAiDesc ?? "";
                                    _cachedAiName = null;
                                    _cachedAiDesc = null;
                                    if (name.isNotEmpty) {
                                        _aiName = name;
                                        nameEntry?.set("shape.value", name); nameEntry?.refreshUI();
                                        final confirm = DvOrb.get_shape_by_id("$prefix/confirm");
                                        confirm?.set("shape.opacity", 0.6); confirm?.refreshUI();
                                    }
                                    if (desc.isNotEmpty) { descEntry?.set("shape.value", desc); descEntry?.refreshUI(); }
                                    final replay = DvOrb.get_shape_by_id("$prefix/replay");
                                    replay?.set("shape.visible", true); replay?.refreshUI();
                                    return;
                                }
                                nameEntry?.set("shape.value", _originalName ?? ""); nameEntry?.refreshUI();
                                descEntry?.set("shape.value", _originalDesc ?? ""); descEntry?.refreshUI();
                                await _runInspire(prefix, promptName, fallbackPrefix);
    }

    //-----------------------------------------------------------------------
    //-- Édition d'une tâche/domaine (écran rename_task, réutilise les masks --
    //-- commons/inspireform_* de create_clan) : nom + description + Inspire moi.
    //-----------------------------------------------------------------------

    // Apparition de l'écran : pré-remplit nom/description avec les valeurs COURANTES résolues dans la
    // langue du terminal (l'admin édite à partir de ce qui est affiché), pose l'image de la tâche en
    // fond, cache « Autre chose ! » et arme le bouton valider (le nom est déjà présent).
    // NB: caller est `dynamic` (pas DvShape?) — l'appear d'un ÉCRAN reçoit le DvView (un DvBeing,
    // PAS un DvShape) comme caller ; typer DvShape? ferait échouer l'appel (TypeError avalée par
    // DvView._resolveActions → le handler ne tournerait jamais). Idem on_dashboard/combat/tiroir_appear.
    Future<void> on_rename_task_appear(dynamic caller, dynamic event) async {

                                _aiName       = "";
                                _originalDesc = null;
                                _originalName = null;
                                _cachedAiName = null;
                                _cachedAiDesc = null;
                                final base     = _editTaskId;
                                // Mode création (tuile « + ») : écran vierge, item traité comme une feuille de
                                // tâche (picklists visibles). Sinon, feuille détectée par le suffixe _<n>.
                                final creating = _creatingNew;
                                final isLeaf   = creating ? true : _leafTaskRe.hasMatch(base);
                                final nameEntry = await DvOrb.wait_for_shape("rename_task/name");
                                final descEntry = DvOrb.get_shape_by_id("rename_task/desc");
                                final replay    = DvOrb.get_shape_by_id("rename_task/replay");
                                final confirm   = DvOrb.get_shape_by_id("rename_task/confirm");
                                final bg        = DvOrb.get_shape_by_id("rename_task/background");

                                final curName = creating ? "" : TranslationRegistry.processLabel(_taskLabel(base));
                                final curDesc = creating ? "" : (isLeaf ? TranslationRegistry.processLabel(_taskAcceptance(base)) : "");
                                nameEntry?.set("shape.value", curName); nameEntry?.refreshUI();
                                descEntry?.set("shape.value", curDesc); descEntry?.refreshUI();
                                _originalName = curName.trim();
                                _originalDesc = curDesc.trim();
                                // Snapshots originaux figés (≠ _originalName/_originalDesc, qui suivent la frappe).
                                _rtOrigName = curName.trim();
                                _rtOrigDesc = curDesc.trim();

                                // Effort/respawn : picklists (feuilles uniquement). Valeurs courantes lues sur la
                                // couche tasks-base fusionnée (surchargée par clans_tasks au chargement du clan).
                                // Création : valeurs par défaut (mêmes que la couche tasks-base). Édition : valeurs
                                // courantes lues sur la couche fusionnée (surchargée par clans_tasks au chargement).
                                final curEffort   = creating ? 3  : (int.tryParse((await deva_get("tasks.$base.effort"))?.toString()    ?? "") ?? 0);
                                final curRespawnH = creating ? 72 : (int.tryParse((await deva_get("tasks.$base.respawn_h"))?.toString() ?? "") ?? 0);
                                final curType     = creating ? "immortelle" : ((await deva_get("tasks.$base.type"))?.toString() ?? "immortelle");
                                _origEffort = curEffort;   _selEffort   = curEffort;
                                _origRespawnH = curRespawnH; _selRespawnH = curRespawnH;
                                _origType = curType;       _selType     = curType;
                                final effortPick  = DvOrb.get_shape_by_id("rename_task/effort");
                                final respawnPick = DvOrb.get_shape_by_id("rename_task/respawn");
                                final typePick    = DvOrb.get_shape_by_id("rename_task/type");
                                if (isLeaf) {
                                    _populateEditPicklists(curEffort, curRespawnH, curType);
                                    effortPick?.set("shape.visible", true);  effortPick?.refreshUI();
                                    respawnPick?.set("shape.visible", true); respawnPick?.refreshUI();
                                    typePick?.set("shape.visible", true);    typePick?.refreshUI();
                                } else {
                                    effortPick?.set("shape.visible", false);  effortPick?.refreshUI();
                                    respawnPick?.set("shape.visible", false); respawnPick?.refreshUI();
                                    typePick?.set("shape.visible", false);    typePick?.refreshUI();
                                }

                                // Fond = image de la tâche (résolue depuis la config du tiroir qui la déclare).
                                // set + appear() + refreshUI : le appear() re-résout le ImageProvider (mis en
                                // cache sinon → l'écu resterait affiché). Même patron que on_avatar_selected / combat.
                                final img = creating ? _defaultTaskImage : await _taskIconPath(base);
                                if (img.isNotEmpty) {
                                    bg?.set("shape.image", img);
                                    try { await bg?.appear(); } catch (e) { deva_log("warning", "[rename_task] bg appear: $e"); }
                                    bg?.refreshUI();
                                }

                                replay?.set("shape.visible", false); replay?.refreshUI();
                                final enabled = curName.trim().isNotEmpty;
                                confirm?.set("shape.opacity", enabled ? 0.6 : 0.3);
                                confirm?.set("shape.events.tap", enabled);
                                confirm?.refreshUI();
    }

    Future<void> on_rename_task_name_changed(DvShape caller, dynamic event) async {

                                final value   = caller.get("shape.value")?.toString() ?? "";
                                _originalName = value.trim();
                                final confirm = DvOrb.get_shape_by_id("rename_task/confirm");
                                final enabled = value.trim().isNotEmpty;
                                confirm?.set("shape.opacity", enabled ? 0.6 : 0.3);
                                confirm?.set("shape.events.tap", enabled);
                                confirm?.refreshUI();
    }

    Future<void> on_rename_task_desc_changed(DvShape caller, dynamic event) async {

                                _originalDesc = caller.get("shape.value")?.toString().trim() ?? "";
    }

    // Libellé d'une option d'effort : « Facile - 12 XP » … « Cauchemar - 96 XP » pour une recharge
    // de 24 h (« Facile - 70 XP » … pour 720 h — les valeurs bougent avec le palier de respawn).
    // L'XP dépend AUSSI de la recharge (_taskBaseXp), donc ces libellés se recalculent quand le
    // chef change le palier de respawn — cf. on_rename_respawn_changed. Mêmes valeurs que le badge
    // de difficulté _taskDifficulty.
    String _effortOptionLabel(int effort, int respawnH) =>
        "${TranslationRegistry.processLabel("@@@T:dt_effort_$effort@@@")} - ${_taskBaseXp(effort, respawnH)} XP";

    // Libellé d'une option de respawn : « Renaît dans 72h » / « Revive in 5 days » …
    // Les paliers horaires s'écrivent « {n}h » (universel) ; les 4 durées longues sont traduites.
    String _respawnOptionLabel(int hours) {

                                final prefix = TranslationRegistry.processLabel("@@@T:revive_in@@@");
                                String dur;
                                switch (hours) {
                                    case 120: dur = TranslationRegistry.processLabel("@@@T:respawn_dur_5d@@@"); break;
                                    case 168: dur = TranslationRegistry.processLabel("@@@T:respawn_dur_1w@@@"); break;
                                    case 336: dur = TranslationRegistry.processLabel("@@@T:respawn_dur_2w@@@"); break;
                                    case 720: dur = TranslationRegistry.processLabel("@@@T:respawn_dur_1m@@@"); break;
                                    default:  dur = "${hours}h";
                                }
                                return "$prefix $dur";
    }

    // Libellé d'une option de type : « Mortelle (crâne) » / « Immortal (revives) » …
    // La valeur stockée reste "mortelle"/"immortelle" (relue à la validation par _writeVerdict).
    String _typeOptionLabel(String type) => TranslationRegistry.processLabel(
        type == "mortelle" ? "@@@T:task_type_mortal@@@" : "@@@T:task_type_immortal@@@");

    // Peuple la SEULE picklist d'effort. Isolée du reste parce que ses libellés portent l'XP, qui
    // dépend de la recharge : elle doit être reconstruite à chaque changement de palier de respawn,
    // sans toucher aux deux autres picklists (reconstruire celle du respawn depuis son propre
    // onChange serait ré-entrant).
    void _populateEffortPicklist(int curEffort, int respawnH) {

                                final effortPick = DvOrb.get_shape_by_id("rename_task/effort");
                                _effortByLabel.clear();
                                final effortOptions = <String>[];
                                for (var e = 1; e <= 8; e++) {
                                    final lbl = _effortOptionLabel(e, respawnH);
                                    effortOptions.add(lbl);
                                    _effortByLabel[lbl] = e;
                                }
                                effortPick?.set("shape.options", effortOptions);
                                effortPick?.set("shape.value",
                                    (curEffort >= 1 && curEffort <= 8) ? _effortOptionLabel(curEffort, respawnH) : null);
                                effortPick?.refreshUI();
    }

    // Peuple les 3 picklists (options + valeur courante) et (re)construit les tables libellé → valeur
    // qui serviront à reconvertir la sélection à la validation. La valeur courante de respawn est
    // construite depuis la VRAIE valeur (même hors paliers, ex. données historiques 36h → « Revive in
    // 36h ») et ajoutée à la table pour rester réversible ; l'utilisateur doit choisir un palier pour
    // la changer.
    void _populateEditPicklists(int curEffort, int curRespawnH, String curType) {

                                final respawnPick = DvOrb.get_shape_by_id("rename_task/respawn");
                                final typePick    = DvOrb.get_shape_by_id("rename_task/type");

                                _populateEffortPicklist(curEffort, curRespawnH);

                                _respawnByLabel.clear();
                                final respawnOptions = <String>[];
                                for (final h in _respawnHours) {
                                    final lbl = _respawnOptionLabel(h);
                                    respawnOptions.add(lbl);
                                    _respawnByLabel[lbl] = h;
                                }
                                respawnPick?.set("shape.options", respawnOptions);
                                if (curRespawnH > 0) {
                                    final lbl = _respawnOptionLabel(curRespawnH);
                                    _respawnByLabel.putIfAbsent(lbl, () => curRespawnH);
                                    respawnPick?.set("shape.value", lbl);
                                } else {
                                    respawnPick?.set("shape.value", null);
                                }
                                respawnPick?.refreshUI();

                                // Type : 2 options fixes (immortelle par défaut en tête).
                                _typeByLabel.clear();
                                final typeOptions = <String>[];
                                for (final t in const ["immortelle", "mortelle"]) {
                                    final lbl = _typeOptionLabel(t);
                                    typeOptions.add(lbl);
                                    _typeByLabel[lbl] = t;
                                }
                                typePick?.set("shape.options", typeOptions);
                                final normType = curType == "mortelle" ? "mortelle" : "immortelle";
                                typePick?.set("shape.value", _typeOptionLabel(normType));
                                typePick?.refreshUI();
    }

    // Sélection d'un effort dans la picklist → entier reconverti via _effortByLabel.
    Future<void> on_rename_effort_changed(DvShape caller, dynamic event) async {

                                final label = caller.get("shape.value")?.toString() ?? "";
                                _selEffort  = _effortByLabel[label] ?? _origEffort;
    }

    // Sélection d'un respawn dans la picklist → heures reconverties via _respawnByLabel.
    // L'XP dépendant de la recharge, les libellés de la picklist d'effort deviennent faux : on les
    // reconstruit sur la nouvelle valeur, en conservant l'effort déjà sélectionné.
    Future<void> on_rename_respawn_changed(DvShape caller, dynamic event) async {

                                final label  = caller.get("shape.value")?.toString() ?? "";
                                _selRespawnH = _respawnByLabel[label] ?? _origRespawnH;
                                _populateEffortPicklist(_selEffort, _selRespawnH);
    }

    // Sélection d'un type dans la picklist → "mortelle"/"immortelle" reconverti via _typeByLabel.
    Future<void> on_rename_type_changed(DvShape caller, dynamic event) async {

                                final label = caller.get("shape.value")?.toString() ?? "";
                                _selType    = _typeByLabel[label] ?? _origType;
    }

    Future<void> on_inspire_task(DvShape? caller, dynamic event) async =>
        _runInspire("rename_task", "inspire_task", null);

    Future<void> on_replay_task(DvShape? caller, dynamic event) async =>
        _runReplay("rename_task", "inspire_task", null);

    // Validation : écrit sur clans_tasks (partagé au clan, deep-merge par champ comme _admApply)
    // UNIQUEMENT les champs réellement modifiés dans l'UI (title, acceptance, effort, respawn_h) —
    // un champ non touché n'est pas ajouté au doc (donc jamais créé). Met à jour store + maps
    // d'override, rafraîchit le tiroir et revient à l'écran d'origine. Le nom/description sont du
    // texte LIBRE (langue de l'éditeur, affiché verbatim) ; effort/respawn sont des entiers (la
    // picklist n'expose qu'un choix contraint, reconverti via _effortByLabel/_respawnByLabel).
    Future<void> on_confirm_rename_task(DvShape? caller, dynamic event) async {

                                // Mode création (tuile « + ») : bifurcation vers la création d'un nouveau doc.
                                if (_creatingNew) { await _createNewTask(); return; }

                                final base = _editTaskId;
                                if (base.isEmpty) { DvOrb.navigate_back(_editReturnPage); return; }
                                final nameEntry = DvOrb.get_shape_by_id("rename_task/name");
                                final descEntry = DvOrb.get_shape_by_id("rename_task/desc");
                                final name = nameEntry?.get("shape.value")?.toString().trim() ?? "";
                                if (name.isEmpty) { DvOrb.navigate_back(_editReturnPage); return; }
                                final isLeaf = _leafTaskRe.hasMatch(base);
                                final desc   = isLeaf ? (descEntry?.get("shape.value")?.toString().trim() ?? "") : "";
                                final ns     = _taskDomains.contains(base) ? "domains" : "tasks";

                                // Détection des changements : effort/respawn (feuilles) ne comptent que si un palier
                                // valide a été retenu (>0) ET diffère de l'original.
                                final nameChanged    = name != _rtOrigName;
                                final descChanged    = isLeaf && desc != _rtOrigDesc;
                                final effortChanged  = isLeaf && _selEffort   > 0 && _selEffort   != _origEffort;
                                final respawnChanged = isLeaf && _selRespawnH > 0 && _selRespawnH != _origRespawnH;
                                final typeChanged    = isLeaf && _selType.isNotEmpty && _selType != _origType;
                                if (!nameChanged && !descChanged && !effortChanged && !respawnChanged && !typeChanged) {
                                    DvOrb.navigate_back(_editReturnPage); return;   // rien de modifié → aucune écriture
                                }

                                // Contexte clan (comme _admApply).
                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session    = await _readSession(region) ?? Dvidle({});
                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                    try {
                                        final doc = Dvidle({});
                                        doc.set("ownerId", clanSecret);
                                        doc.set("clanId",  clanId);
                                        if (nameChanged)    doc.set("title",     name);
                                        if (descChanged)    doc.set("acceptance", desc);
                                        if (effortChanged)  doc.set("effort",    _selEffort);
                                        if (respawnChanged) doc.set("respawn_h", _selRespawnH);
                                        if (typeChanged)    doc.set("type",      _selType);
                                        // Delta-sync : seules les tâches sont relues incrémentalement (les
                                        // domaines ne sont relus qu'au login).
                                        if (ns == "tasks") _stampTouched(doc);
                                        await _cloud?.write("workers", "clans_tasks/$clanId/$ns", base, doc,
                                            region: region, ownerId: clanSecret);
                                    } catch (e) {
                                        deva_log("error", "[admin] persist edit $ns/$base FAILED: $e");
                                    }
                                } else {
                                    deva_log("warning", "[admin] pas de clan → édition non persistée");
                                }

                                // Miroir local (conf/runtime) + maps d'override (résolution synchrone) + flush disque,
                                // uniquement pour les champs modifiés → l'affichage se met à jour sans round-trip.
                                if (nameChanged) {
                                    await deva_set("$ns.$base.title", name);
                                    _titleOverride[base] = name;
                                }
                                if (descChanged) {
                                    await deva_set("tasks.$base.acceptance", desc);
                                    _acceptanceOverride[base] = desc;
                                }
                                if (effortChanged)  await deva_set("tasks.$base.effort",    _selEffort);
                                if (respawnChanged) await deva_set("tasks.$base.respawn_h", _selRespawnH);
                                if (typeChanged)    await deva_set("tasks.$base.type",      _selType);
                                try { await Deva.instance.store(); }
                                catch (e) { deva_log("error", "[admin] store() edit FAILED: $e"); }

                                // Rafraîchit l'affichage : libellés du tiroir + clones (label figé avec prénom),
                                // seulement si le nom a changé (effort/respawn se recalculent au prochain chargement).
                                if (nameChanged) {
                                    _notifyTiroirLabels(_titleOverride);
                                    if (ns == "tasks" && clanId.isNotEmpty) {
                                        // Clones (« <titre> - <prénom> ») : le doc renommé vient d'être
                                        // estampillé → le refresh forcé le récupère en delta et repousse
                                        // lui-même labels + clones (plus de full list ici).
                                        try { await _refreshTaskStatuses(force: true); } catch (_) {}
                                    }
                                }
                                deva_log("info", "[admin] $ns/$base édité (conf + runtime + firestore)");
                                DvOrb.navigate_back(_editReturnPage);
    }

    // Crée une NOUVELLE tâche (tuile « + » d'un sous-tiroir de domaine) : nouveau doc Firestore
    // (visible par tout le clan), miroir local, et injection de la tuile dans le tiroir du domaine.
    // Id = "<domaine>_<micros>" : feuille (suffixe _<chiffres> → _leafTaskRe), sans "__", unique et
    // hors catalogue (donc exempté du réconciliateur via le flag user_created).
    Future<void> _createNewTask() async {

                                final domain = _createDomain;
                                _creatingNew = false; _createDomain = "";   // consommé, quel que soit l'issue
                                final nameEntry = DvOrb.get_shape_by_id("rename_task/name");
                                final descEntry = DvOrb.get_shape_by_id("rename_task/desc");
                                final name = nameEntry?.get("shape.value")?.toString().trim() ?? "";
                                final desc = descEntry?.get("shape.value")?.toString().trim() ?? "";
                                if (domain.isEmpty || name.isEmpty) { DvOrb.navigate_back(_editReturnPage); return; }

                                final id      = "${domain}_${DateTime.now().toUtc().microsecondsSinceEpoch}";
                                final effort  = _selEffort   > 0 ? _selEffort   : 3;
                                final respawn = _selRespawnH > 0 ? _selRespawnH : 72;
                                final type    = _selType.isNotEmpty ? _selType : "immortelle";

                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session    = await _readSession(region) ?? Dvidle({});
                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) {
                                    deva_log("warning", "[admin] pas de clan (ou pas chef) → création annulée");
                                    DvOrb.navigate_back(_editReturnPage); return;
                                }

                                // Doc Firestore : plomberie via _newTaskDoc + champs éditables + image par défaut
                                // (stockée → éditable ensuite) + flag user_created (exemption réconciliateur).
                                final doc = _newTaskDoc(clanId, clanSecret, true, domain: domain);
                                doc.set("title",        name);
                                doc.set("acceptance",   desc);
                                doc.set("effort",       effort);
                                doc.set("respawn_h",    respawn);
                                doc.set("type",         type);
                                doc.set("image",        _defaultTaskImage);
                                doc.set("user_created", true);
                                deva_log("info", "[admin] création tâche $id (domaine $domain, clan $clanId, région $region)");
                                try {
                                    await _cloud?.write("workers", "clans_tasks/$clanId/tasks", id, doc,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("error", "[admin] création tâche $id FAILED: $e");
                                    DvOrb.navigate_back(_editReturnPage); return;
                                }

                                // RELECTURE serveur avant toute trace locale : Firestore est la SEULE source de
                                // vérité (la tuile ne vient que de _buildAdditionsMap, alimenté par la liste
                                // Firestore). Sans ce contrôle, une écriture partie en silence laisserait l'app
                                // afficher une tâche qui n'existe pour personne, et disparaîtrait au redémarrage
                                // — exactement le symptôme qu'on corrige.
                                Dvidle? saved;
                                try {
                                    saved = await _cloud?.read("workers", "clans_tasks/$clanId/tasks", id,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("error", "[admin] création tâche $id : relecture FAILED: $e");
                                }
                                if (saved == null) {
                                    deva_log("error", "[admin] création tâche $id : doc ABSENT après écriture "
                                        "(rien de persisté, aucune tuile injectée)");
                                    DvOrb.navigate_back(_editReturnPage); return;
                                }

                                // Miroir local (conf/runtime) : la tâche est immédiatement résolue partout sans
                                // round-trip (label/acceptance/image via overrides + _taskIconPath).
                                await deva_set("tasks.$id.domain",       domain);
                                await deva_set("tasks.$id.title",        name);
                                await deva_set("tasks.$id.acceptance",   desc);
                                await deva_set("tasks.$id.effort",       effort);
                                await deva_set("tasks.$id.respawn_h",    respawn);
                                await deva_set("tasks.$id.type",         type);
                                await deva_set("tasks.$id.image",        _defaultTaskImage);
                                await deva_set("tasks.$id.status",       "alive");
                                await deva_set("tasks.$id.enabled",      true);
                                await deva_set("tasks.$id.visible",      true);
                                await deva_set("tasks.$id.user_created", true);
                                _titleOverride[id]      = name;
                                _acceptanceOverride[id] = desc;
                                try { await Deva.instance.store(); }
                                catch (e) { deva_log("error", "[admin] store() création FAILED: $e"); }

                                // Affiche la tuile et rafraîchit les statuts : _refreshTaskStatuses récupère
                                // le doc frais (delta) et pousse lui-même update_additions.
                                await _refreshTaskStatuses(force: true);
                                deva_log("info", "[admin] tâche créée + relue: tasks/$id (domaine $domain)");
                                DvOrb.navigate_back(_editReturnPage);
    }

    //-----------------------------------------------------------------------
    //-- Player name screen actions ----------------------------------------
    //-----------------------------------------------------------------------

    Future<String> on_confirm_player_name(DvShape? caller, dynamic event) async {

                                final nameEntry = DvOrb.get_shape_by_id("player_name_screen/name");
                                final raw       = nameEntry?.get("shape.value")?.toString().trim() ?? "";
                                if (raw.isEmpty) return "cancel";
                                await _persistPlayerName(_capitalizeFirst(raw));
                                // Le nom est saisi APRÈS la liaison du compte : un mineur qui vient d'être
                                // admis part au tableau de bord, un adulte n'a pas encore de clan et va le
                                // créer ou en rejoindre un.
                                //
                                // Le critère est l'ENRÔLEMENT PERSISTÉ (un clanId non vide dans le doc
                                // `users`), le même que celui d'on_login — et surtout pas le seul drapeau
                                // RAM `worker.session.clan_done` : celui-ci ne survit pas forcément à la
                                // liaison du compte, qui recharge le layer runtime depuis le disque et vide
                                // le store (cf. _handleClanJoin). Le drapeau ne sert plus que de repli quand
                                // la lecture Firestore échoue.
                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (region.isNotEmpty) {
                                    try {
                                        final session = await _readSession(region);
                                        if (session != null) {
                                            final clanId = session.get("steps.clan.clanId")?.toString() ?? "";
                                            return clanId.isNotEmpty ? "dashboard" : "clan";
                                        }
                                    } catch (e) {
                                        deva_log("error", "[worker] on_confirm_player_name: lecture session FAILED: $e");
                                    }
                                }
                                final clanDone = (await Deva.instance.get("worker.session.clan_done"))?.toString() ?? "";
                                return clanDone == "true" ? "dashboard" : "clan";
    }

    // Persiste le nom du joueur : écriture Firestore (workers/users) + mise à jour de la
    // session RAM (session.user.name). Le nom est rechargé au prochain démarrage depuis
    // Firestore via la config dvsession (session.username ↔ users.internal.name).
    // GARDE D'IMPERSONATION (miroir de open_delete_account) : le doc `users/` appartient au
    // compte AUTHENTIFIÉ (_sessionDocId() → _authUserId, verrouillé serveur sur auth.uid).
    // Pendant une prise de place, le nom saisi est celui de la CIBLE : l'écrire ici renommerait
    // l'ADMIN — et ce nom lui reviendrait au prochain démarrage, dvsession réhydratant
    // session.user.name depuis users.internal.name. Le nom d'un joueur incarné vit donc
    // uniquement dans clans_players (seule source pour un joueur sans compte, no_account).
    Future<void> _persistPlayerName(String name) async {

                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (region.isNotEmpty && !_impersonating) {
                                    final docId = _sessionDocId();
                                    if (docId.isNotEmpty) {
                                        try {
                                            final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                            final device      = await _cloud?.deviceId() ?? "";
                                            final now         = DateTime.now().toUtc().toIso8601String();
                                            final existing    = await _readSession(region) ?? Dvidle({});
                                            existing.rem("docId");
                                            existing.set("ownerId",           firebaseUid);
                                            existing.set("userId",            docId);
                                            existing.set("internal.name",     name);
                                            existing.set("external.name",     name);
                                            existing.set("steps.name.status", "done");
                                            existing.set("steps.name.date",   now);
                                            existing.set("steps.name.result", name);
                                            existing.set("steps.name.device", device);
                                            existing.set("date",              now);
                                            await _cloud?.write("workers", "users", docId, existing, region: region);
                                            _invalidateSessionCache();
                                            deva_log("info", "[worker] player name saved → firestore OK ($name)");
                                        } catch (e) {
                                            deva_log("error", "[worker] player name FAILED: $e");
                                        }
                                    }
                                }
                                await Deva.instance.set("session.user.name", name);

                                // Répercute le nom dans le doc membre clans_players/{clanId}/players/{userId} :
                                // c'est la copie dénormalisée qui alimente le roster (et le journal). Sans ça,
                                // le nom ne changerait que dans workers/users. _writeClanPlayer fusionne
                                // (préserve xp/pv/status/…). nameOverride explicite : c'est CE renommage qui
                                // fait autorité, y compris quand il vise un joueur incarné (dont le nom ne
                                // peut vivre que là).
                                if (region.isNotEmpty && _userId.isNotEmpty) {
                                    try {
                                        final session    = await _readSession(region);
                                        final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                        final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                        if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                            if (_impersonating) {
                                                // Joueur incarné : write CHIRURGICAL du seul champ `name` (dvcloud
                                                // fusionne en profondeur via updateMask). Surtout PAS _writeClanPlayer,
                                                // qui enregistrerait le device de l'admin dans les `devices` de la cible
                                                // (vol du token FCM) et forcerait has_device=true — c'est exactement ce
                                                // que take_place s'interdit.
                                                final patch = Dvidle({});
                                                patch.set("name", name);
                                                await _cloud?.write("workers", "clans_players/$clanId/players", _userId,
                                                    patch, region: region, ownerId: clanSecret);
                                            } else {
                                                final device = await _cloud?.deviceId() ?? "";
                                                await _writeClanPlayer(clanId, clanSecret, _userId, device, region,
                                                    nameOverride: name);
                                            }
                                        }
                                    } catch (e) {
                                        deva_log("error", "[worker] clans_players name sync FAILED: $e");
                                    }
                                }

                                // Annonce d'arrivée dans le clan mise en attente par _handleClanJoin faute de
                                // nom à afficher : le joueur en a un, elle peut partir. Sans effet dans tous
                                // les autres cas (renommage, impersonation, création de clan).
                                if (!_impersonating) await _flushPendingMemberJoined(name);
    }

    Future<void> on_player_name_appear(DvShape? caller, dynamic event) async {

                                final nameEntry = await DvOrb.wait_for_shape("player_name_screen/name");
                                final confirm   = DvOrb.get_shape_by_id("player_name_screen/confirm");
                                nameEntry?.set("shape.value", ""); nameEntry?.refreshUI();
                                confirm?.set("shape.opacity", 0.3);
                                confirm?.set("shape.events.tap", false);
                                confirm?.refreshUI();
    }

    Future<void> on_player_name_changed(DvShape caller, dynamic event) async {

                                final value   = caller.get("shape.value")?.toString() ?? "";
                                final confirm = DvOrb.get_shape_by_id("player_name_screen/confirm");
                                final enabled = value.trim().isNotEmpty;
                                confirm?.set("shape.opacity", enabled ? 0.6 : 0.3);
                                confirm?.set("shape.events.tap", enabled);
                                confirm?.refreshUI();
    }

    String _capitalizeFirst(String s) {

                                if (s.isEmpty) return s;
                                return s[0].toUpperCase() + s.substring(1);
    }

    //-----------------------------------------------------------------------
    //-- Écran de renommage (player_rename_screen) --------------------------
    //-----------------------------------------------------------------------

    // Apparition : pré-remplit le champ avec le nom courant et active le bouton d'emblée.
    Future<void> on_rename_appear(DvShape? caller, dynamic event) async {

                                final nameEntry = await DvOrb.wait_for_shape("player_rename_screen/name");
                                final confirm   = DvOrb.get_shape_by_id("player_rename_screen/confirm");
                                final current   = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                nameEntry?.set("shape.value", current); nameEntry?.refreshUI();
                                final enabled = current.trim().isNotEmpty;
                                confirm?.set("shape.opacity", enabled ? 0.6 : 0.3);
                                confirm?.set("shape.events.tap", enabled);
                                confirm?.refreshUI();
    }

    // Champ modifié : active/désactive le bouton selon que le champ est vide ou non.
    Future<void> on_rename_changed(DvShape caller, dynamic event) async {

                                final value   = caller.get("shape.value")?.toString() ?? "";
                                final confirm = DvOrb.get_shape_by_id("player_rename_screen/confirm");
                                final enabled = value.trim().isNotEmpty;
                                confirm?.set("shape.opacity", enabled ? 0.6 : 0.3);
                                confirm?.set("shape.events.tap", enabled);
                                confirm?.refreshUI();
    }

    // Confirmation : persiste, revient à l'écran Personnage, rafraîchit le label et sort
    // du mode édition. Miroir de on_avatar_selected.
    Future<void> on_rename_confirm(DvShape? caller, dynamic event) async {

                                final nameEntry = DvOrb.get_shape_by_id("player_rename_screen/name");
                                final raw       = nameEntry?.get("shape.value")?.toString().trim() ?? "";
                                if (raw.isEmpty) return;
                                await _persistPlayerName(_capitalizeFirst(raw));

                                // Recalcule le label (re-résout @@@session.user.name@@@ depuis la session).
                                final lbl = DvOrb.get_shape_by_id("personnage/label");
                                if (lbl is DvLabel) { await lbl.computeDisplay(); lbl.refreshUI(); }

                                DvOrb.navigate_back("personnage");
                                await _exitPersonnageEdit();
    }

    //-----------------------------------------------------------------------
    //-- Créer un joueur enfant (sans compte) -------------------------------
    //-----------------------------------------------------------------------

    // Option clan « Créer un joueur » (chef) : l'opération n'est pas anodine (personnage fictif +
    // relais par « Jouer à sa place »), on explique AVANT de changer d'écran. DvMenu a déjà refermé
    // le menu quand l'action se déclenche → la leçon se joue sur l'écran Clan. dvtuto.play ne rend la
    // main qu'à la fin de la leçon, et immédiatement si elle ne peut pas jouer : la navigation vers
    // l'écran de saisie du nom a lieu dans tous les cas.
    Future<void> create_player(dynamic caller, dynamic event) async {

                                await deva_do("dvtuto.play.create_player_intro");
                                DvOrb.navigate_new("create_player_screen");
    }

    // Apparition : champ vide + bouton confirmer grisé (calqué sur on_player_name_appear).
    Future<void> on_create_player_appear(DvShape? caller, dynamic event) async {

                                final nameEntry = await DvOrb.wait_for_shape("create_player_screen/name");
                                final confirm   = DvOrb.get_shape_by_id("create_player_screen/confirm");
                                nameEntry?.set("shape.value", ""); nameEntry?.refreshUI();
                                confirm?.set("shape.opacity", 0.3);
                                confirm?.set("shape.events.tap", false);
                                confirm?.refreshUI();
    }

    // Champ modifié : active/grise le bouton selon que le champ est vide ou non.
    Future<void> on_create_player_changed(DvShape caller, dynamic event) async {

                                final value   = caller.get("shape.value")?.toString() ?? "";
                                final confirm = DvOrb.get_shape_by_id("create_player_screen/confirm");
                                final enabled = value.trim().isNotEmpty;
                                confirm?.set("shape.opacity", enabled ? 0.6 : 0.3);
                                confirm?.set("shape.events.tap", enabled);
                                confirm?.refreshUI();
    }

    // Confirmation : crée l'enfant DIRECTEMENT dans le clan courant, SANS doc `users` ni
    // `userindexes` (il n'a pas de compte). Le doc clans_players est autorisé par le clanSecret
    // du parent (détenu dans SON userindexes) ; le docId enfant est un uuid libre. device vide →
    // pas de token FCM propre ; legal_state "k" (mineur) ; no_account = marqueur. Retour au clan
    // + refresh du roster pour afficher la nouvelle tuile. L'admin jouera pour lui via take_place.
    Future<void> on_create_player_confirm(DvShape? caller, dynamic event) async {

                                final nameEntry = DvOrb.get_shape_by_id("create_player_screen/name");
                                final raw       = nameEntry?.get("shape.value")?.toString().trim() ?? "";
                                if (raw.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;
                                    if (!await _ensureIsAdmin(clanId, clanSecret, region)) return;

                                    final childId   = _generateUuid();
                                    final childName = _capitalizeFirst(raw);
                                    await _writeClanPlayer(clanId, clanSecret, childId, "", region,
                                        firstClan: clanId, nameOverride: childName,
                                        legalStateOverride: "k", noAccount: true);

                                    await _writeClanLog(clanId, clanSecret, region, "MemberCreated",
                                        userId: childId, adminId: _userId, slug: childName);

                                    deva_log("info", "[clan] create_player : $childName ($childId) créé dans $clanId");
                                    DvOrb.navigate_back("clan_page");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[clan] on_create_player_confirm FAILED: $e");
                                }
    }

    String _parseAiName(String r) {

                                for (final line in r.split('\n')) {
                                    final t  = line.trim();
                                    final tu = t.toUpperCase();
                                    if (tu.startsWith('NOM:'))    return t.substring(4).trim();
                                    if (tu.startsWith('NOMBRE:')) return t.substring(7).trim();
                                }
                                return "";
    }

    String _parseAiDescription(String r) {

                                bool cap = false;
                                final parts = <String>[];
                                for (final line in r.split('\n')) {
                                    final t  = line.trim();
                                    final tu = t.toUpperCase();
                                    int? prefixLen;
                                    if      (tu.startsWith('DESCRIPTION:'))  prefixLen = 12;
                                    else if (tu.startsWith('DESCRIPCION:'))  prefixLen = 12;
                                    else if (tu.startsWith('DESCRIPCIÓN:'))  prefixLen = 12;
                                    if (prefixLen != null) {
                                        cap = true;
                                        final rest = t.substring(prefixLen).trim();
                                        if (rest.isNotEmpty) parts.add(rest);
                                    } else if (cap && t.isNotEmpty) {
                                        parts.add(t);
                                    }
                                }
                                return parts.join('\n').trim();
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
