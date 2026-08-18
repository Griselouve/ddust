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
// --- worker extension — Administration du tiroir
// -----------------------------------------------------------------------------
extension Worker_admin on worker {

    void _register_admin() {

                                ActionRegistry.register("worker.adm_enable",                adm_enable);

                                ActionRegistry.register("worker.adm_disable",               adm_disable);

                                ActionRegistry.register("worker.adm_hide",                  adm_hide);

                                ActionRegistry.register("worker.adm_show",                  adm_show);

                                ActionRegistry.register("worker.adm_edit",                  adm_edit);

                                ActionRegistry.register("worker.adm_tasks",                 adm_tasks);

                                ActionRegistry.register("worker.adm_revive",                adm_revive);

                                ActionRegistry.register("worker.adm_release",               adm_release);

                                ActionRegistry.register("worker.on_recommend_task",         on_recommend_task);

                                ActionRegistry.register("worker.on_unrecommend_task",       on_unrecommend_task);

                                ActionRegistry.register("worker.adm_add_task",              adm_add_task);

    }

    // Détecte (et met en cache, une fois par clan) si l'utilisateur est admin du clan : lit le
    // doc clan workers/clans/{clanId} et teste _userId ∈ admins. Conditionne la cliquabilité des
    // tâches "validating" dans le tiroir ET l'auto-validation de ses propres tâches (on_combat_ok).
    // clanSecret vide / lecture KO → _isAdmin garde sa valeur (false par défaut) : repli sûr.
    Future<bool> _ensureIsAdmin(String clanId, String clanSecret, String region) async {

                                if ((_isAdminClanId != clanId || _isAdminUserId != _userId)
                                    && clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                    try {
                                        final clanDoc = await _cloud?.read("workers", "clans", clanId,
                                            ownerId: clanSecret, region: region);
                                        final admins  = List<dynamic>.from(clanDoc?.get("admins") as List? ?? []);
                                        _isAdmin       = admins.contains(_userId);
                                        _adminCount    = admins.length;
                                        _isAdminClanId = clanId;
                                        _isAdminUserId = _userId;
                                        deva_log("info", "[combat] isAdmin=$_isAdmin (clan=$clanId)");
                                    } catch (e) {
                                        deva_log("warning", "[combat] détection admin échec: $e");
                                    }
                                }
                                return _isAdmin;
    }

    // Options du menu d'administration. Chacune persiste un drapeau (visible OU enabled) sur 3
    // surfaces via _admApply, puis rafraîchit l'UI. `event` = la charge passée par DvTiroir au
    // menu : {"id": <icône>, "tap": <action de jeu>}.
    Future<void> adm_enable(dynamic caller, dynamic event)  async => _admApply(event, enabled: true);

    Future<void> adm_disable(dynamic caller, dynamic event) async => _admApply(event, enabled: false);

    Future<void> adm_hide(dynamic caller, dynamic event)    async => _admApply(event, visible: false);

    Future<void> adm_show(dynamic caller, dynamic event)    async => _admApply(event, visible: true);

    // Applique une bascule d'administration (visible OU enabled) à un domaine/tâche et la PERSISTE
    // sur les 3 surfaces : conf (store fusionné) + layer runtime (flush disque) + Firestore (doc
    // partagé au clan). Puis rafraîchit l'UI du mode courant (chef). Écrit sur la BASE (via
    // _originalOf) — les clones {base}__{uid} héritent du drapeau. La bascule est faite à l'état
    // VIVANT (le switch Jeu|Admin est masqué si mort), donc le flush disque est volontaire et sûr.
    Future<void> _admApply(dynamic event, {bool? visible, bool? enabled}) async {

                                final rawId = (event is Map ? event["id"]?.toString() : "") ?? "";
                                final id    = _originalOf(rawId);
                                if (id.isEmpty) return;
                                final isDomain = _taskDomains.contains(id);
                                final ns    = isDomain ? "domains" : "tasks";   // espace conf ET sous-collection
                                final field = visible != null ? "visible" : "enabled";
                                final value = visible ?? enabled ?? true;

                                // 1) conf + layer runtime en mémoire (deva_set écrit _store ET runtime-<ownerId>).
                                await deva_set("$ns.$id.$field", value);

                                // 2) Firestore (doc partagé du clan). Écriture par champ : le deep-merge dvcloud
                                //    préserve les autres champs. ownerId == clanSecret requis par les règles.
                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session    = await _readSession(region) ?? Dvidle({});
                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                    try {
                                        final doc = Dvidle({});
                                        doc.set("ownerId", clanSecret);
                                        doc.set("clanId",  clanId);
                                        doc.set(field,     value);
                                        // Delta-sync : seules les tâches sont relues incrémentalement (les
                                        // domaines ne sont relus qu'au login).
                                        if (ns == "tasks") _stampTouched(doc);
                                        await _cloud?.write("workers", "clans_tasks/$clanId/$ns", id, doc,
                                            region: region, ownerId: clanSecret);
                                    } catch (e) {
                                        deva_log("error", "[admin] persist $ns/$id $field=$value FAILED: $e");
                                    }
                                } else {
                                    deva_log("warning", "[admin] pas de clan → $field non persisté en Firestore");
                                }

                                // 3) Flush disque du layer runtime (bascule volontaire, à l'état vivant).
                                try { await Deva.instance.store(); }
                                catch (e) { deva_log("error", "[admin] store() FAILED: $e"); }

                                deva_log("info", "[admin] $ns/$id : $field=$value (conf + runtime + firestore)");

                                // 4) Rafraîchit l'UI du mode chef : grisage (enabled) + croix (visible).
                                _notifyTiroirDomains(await _buildEnabledMap());
                                _notifyTiroirStatuses(await _buildHiddenStatusMap());
    }

    // « Voir les tâches » (menu admin, tiroir des domaines) : ouvre le sous-tiroir <domaine>_tasks
    // SANS quitter le mode admin. Pas de garde enabled (l'admin gère aussi les domaines fermés) ni
    // de push de statuts de jeu — le vocabulaire admin est global/rémanent et le nouveau tiroir en
    // hérite ; son `appear` (on_tiroir_appear → _syncChiefUi) pose le switch et la bordure rouge.
    // Domaine « multiple » : rawId = <domaine>__<owner> → owner filtre le sous-tiroir (cf. seldomain).
    Future<void> adm_tasks(dynamic caller, dynamic event) async {

                                final rawId  = (event is Map ? event["id"]?.toString() : "") ?? "";
                                final domain = _originalOf(rawId);
                                if (domain.isEmpty) return;
                                final owner  = rawId == domain ? "" : rawId.substring(domain.length + 2);
                                await Deva.instance.set("session.selected_owner", owner);
                                DvOrb.navigate_new("${domain}_tasks");
    }

    // « Ressusciter » (menu admin, feuille de tâche) : remet la tâche à NEUF immédiatement (100 %
    // disponible), quel que soit son état courant (assigned / validating / dead / en régénération).
    // Contrairement à un verdict accepté qui DÉMARRE le timer (revive=now+respawn_h), on ZÉROTE la
    // fenêtre (dead/revive vides → hasWindow=false dans _refreshTaskStatuses) : ni crâne ni barre,
    // tâche reprenable tout de suite. Persistance sur les 2 surfaces d'état (Firestore doc du clan +
    // miroir local), puis refresh UI — même schéma clan que _admApply, même écriture que _writeVerdict.
    // Cible la BASE (via _originalOf) ; les clones {base}__{uid} héritent via le miroir habituel.
    Future<void> adm_revive(dynamic caller, dynamic event) async {

                                final rawId = (event is Map ? event["id"]?.toString() : "") ?? "";
                                final id    = _originalOf(rawId);
                                if (id.isEmpty || _taskDomains.contains(id)) return;   // tâches uniquement

                                final now = DateTime.now().toUtc().toIso8601String();

                                // 1) Firestore (doc partagé du clan). PATCH complet : reconstruire l'état frais +
                                //    préserver l'identité (domain + champs de clone). Vider dead/revive/proof
                                //    EXPLICITEMENT ("") → le deep-merge dvcloud efface le champ (fenêtre absente).
                                //    ownerId == clanSecret requis par les règles.
                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session    = await _readSession(region) ?? Dvidle({});
                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                    try {
                                        final doc = Dvidle({});
                                        doc.set("ownerId",  clanSecret);
                                        doc.set("clanId",   clanId);
                                        doc.set("assignee", "");
                                        doc.set("status",   "alive");
                                        doc.set("dead",     "");
                                        doc.set("revive",   "");
                                        doc.set("proof",    "");
                                        doc.set("last",     now);
                                        await _applyIdentityFields(doc, id);   // préserve domain + champs de clone
                                        await _cloud?.write("workers", "clans_tasks/$clanId/tasks", id, doc,
                                            region: region, ownerId: clanSecret);
                                    } catch (e) {
                                        deva_log("error", "[admin] revive tasks/$id FAILED: $e");
                                    }
                                } else {
                                    deva_log("warning", "[admin] pas de clan → revive $id non persisté en Firestore");
                                }

                                // 2) Miroir local (store fusionné + layer runtime). dead/revive = "" → hasWindow=false.
                                await deva_set("tasks.$id.assignee", "");
                                await deva_set("tasks.$id.status",   "alive");
                                await deva_set("tasks.$id.dead",     "");
                                await deva_set("tasks.$id.revive",   "");
                                await deva_set("tasks.$id.proof",    "");
                                await deva_set("tasks.$id.last",     now);

                                deva_log("info", "[admin] revive tasks/$id : status=alive, fenêtre effacée (100 %)");

                                // 3) Rafraîchit l'UI : recalcule crâne/barre → tuile propre et reprenable.
                                await _refreshTaskStatuses(force: true);
    }

    // « Laisser tomber » (menu admin, feuille de tâche) : LIBÈRE une tâche tenue par un joueur —
    // elle redevient exactement ce qu'elle était avant sa sélection (assignee vide, status "alive",
    // preuve retirée). Exactement l'écriture de la « Retraite ! » du joueur (_releaseTask), mais
    // décidée par un chef sur la tâche d'un AUTRE. Contrairement à « Ressusciter », la fenêtre de
    // régénération (dead/revive) est PRÉSERVÉE : libérer n'est pas remettre à neuf — une tâche
    // relâchée pendant sa repousse garde sa barre.
    // Cible l'id d'icône RÉEL (pas _originalOf) : l'assignation vit sur le doc d'instance, et un
    // clone {base}__{uid} est assigné à son propre porteur.
    // Le porteur s'aligne tout seul, sans notification : sa vigilance (watch, s'il attendait un
    // verdict) et son on_combat_appear lisent status=alive / assignee vide → active_task vidé,
    // retour au tiroir. Aucune célébration ne part : elles sont toutes conditionnées à une hausse
    // d'XP, et libérer n'en crédite aucune.
    Future<void> adm_release(dynamic caller, dynamic event) async {

                                final id = (event is Map ? event["id"]?.toString() : "") ?? "";
                                if (id.isEmpty || _taskDomains.contains(id)) return;   // feuilles de tâche uniquement

                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session    = await _readSession(region) ?? Dvidle({});
                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) {
                                    deva_log("warning", "[admin] pas de clan → libération de $id ignorée");
                                    return;
                                }

                                // Firestore + miroir local (assignee, status, last, proof) en une passe.
                                try {
                                    await _releaseTask(clanId, clanSecret, id, region);
                                } catch (e) {
                                    deva_log("error", "[admin] release tasks/$id FAILED: $e");
                                    return;
                                }
                                deva_log("info", "[admin] release tasks/$id : tâche rendue au clan");

                                // Rafraîchit l'UI : la flamme (busy) ou la main (review) disparaît, la tuile
                                // redevient prenable.
                                await _refreshTaskStatuses(force: true);
    }

    // « Recommander » (menu admin du tiroir) : marque une FEUILLE de tâche comme « boss ». Pose
    // recommended = ISO now sur le doc d'instance (id d'icône réel, y compris un clone {base}__{uid}
    // — état par-instance, PAS via _originalOf), puis prévient tout le clan. Écriture ciblée : le
    // deep-merge dvcloud préserve les autres champs. ownerId == clanSecret requis par les règles. Le
    // badge XP (haut-gauche) apparaît au _refreshTaskStatuses. Le bonus d'XP est tiré au verdict
    // (_applyVerdict / on_combat_ok), qui efface du même coup `recommended` : une acceptation
    // consomme la recommandation, un refus la conserve pour la nouvelle tentative.
    Future<void> on_recommend_task(dynamic caller, dynamic event) async {

                                final id = (event is Map ? event["id"]?.toString() : "") ?? "";
                                if (id.isEmpty || _taskDomains.contains(id)) return;   // feuilles de tâche uniquement

                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session    = await _readSession(region) ?? Dvidle({});
                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) {
                                    deva_log("warning", "[admin] pas de clan → recommandation de $id ignorée");
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
                                    deva_log("error", "[admin] recommandation tasks/$id FAILED: $e");
                                    return;
                                }

                                // Miroir local + badge XP (tâche + domaine par remontée).
                                await deva_set("tasks.$id.recommended", now);
                                await _refreshTaskStatuses(force: true);

                                deva_log("info", "[admin] tâche recommandée (boss): $id → $now");

                                // Prévient tout le clan (sauf soi) qu'un boss est apparu.
                                await _notifyClanBoss(clanId, clanSecret, region);
    }

    // « Ne plus recommander » (menu admin du tiroir) : retour en arrière sur « Recommander ». Efface
    // recommended sur le doc d'instance (id d'icône RÉEL, comme la pose) → le badge XP disparaît et
    // le bonus ne s'appliquera plus au verdict (_bossPlayerXp ne boost que sur un `recommended` non
    // vide, lu au moment de la validation). Écriture ciblée : le deep-merge dvcloud exige la chaîne
    // vide EXPLICITE pour effacer le champ (cf. _applyIdentityFields, qui fait la même chose au
    // verdict accepté). Aucune notification : on ne dérange pas le clan pour un retrait.
    Future<void> on_unrecommend_task(dynamic caller, dynamic event) async {

                                final id = (event is Map ? event["id"]?.toString() : "") ?? "";
                                if (id.isEmpty || _taskDomains.contains(id)) return;   // feuilles de tâche uniquement

                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session    = await _readSession(region) ?? Dvidle({});
                                final clanId     = session.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) {
                                    deva_log("warning", "[admin] pas de clan → retrait de recommandation de $id ignoré");
                                    return;
                                }

                                try {
                                    final doc = Dvidle({});
                                    doc.set("ownerId",     clanSecret);
                                    doc.set("clanId",      clanId);
                                    doc.set("recommended", "");
                                    _stampTouched(doc);
                                    await _cloud?.write("workers", "clans_tasks/$clanId/tasks", id, doc,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("error", "[admin] retrait de recommandation tasks/$id FAILED: $e");
                                    return;
                                }

                                // Miroir local + badge XP retiré (tâche + domaine par remontée).
                                await deva_set("tasks.$id.recommended", "");
                                await _refreshTaskStatuses(force: true);

                                deva_log("info", "[admin] tâche n'est plus recommandée (boss retiré): $id");
    }

    // « Modifier » (menu admin du tiroir) : ouvre l'écran d'édition sur la BASE de la tâche/domaine
    // (via _originalOf → les clones ciblent leur original). Mémorise l'écran d'origine pour y revenir.
    Future<void> adm_edit(dynamic caller, dynamic event) async {

                                final rawId = (event is Map ? event["id"]?.toString() : "") ?? "";
                                final base  = _originalOf(rawId);
                                if (base.isEmpty) return;
                                _editTaskId     = base;
                                _editReturnPage = DvOrb.get_current_page()?.dvid ?? "combat";
                                DvOrb.navigate_new("rename_task");
    }

    // Tuile « + » (mode admin) : ouvre rename_task en mode CRÉATION d'une TÂCHE, rattachée au
    // domaine de la page courante (`<domaine>_tasks`). Un chef ne crée JAMAIS de domaine : la liste
    // des domaines est du contenu de jeu, et les domaines additionnels s'achètent en packs (boutique).
    // C'est pourquoi combat/tiroir refuse la tuile en conf (extras_enabled: false) ; le test ci-dessous
    // n'est qu'une ceinture-bretelles si un autre écran finissait par l'afficher.
    Future<void> adm_add_task(dynamic caller, dynamic event) async {

                                final page = DvOrb.get_current_page()?.dvid ?? "";
                                if (page == "combat" || !page.endsWith("_tasks")) {
                                    deva_log("info", "[admin] tuile « + » hors sous-tiroir de tâches (page '$page') — ignorée");
                                    return;
                                }
                                final domain = page.substring(0, page.length - "_tasks".length);
                                if (domain.isEmpty) return;
                                _creatingNew    = true;
                                _createDomain   = domain;
                                _editTaskId     = "";               // vide = création (pas d'édition)
                                _editReturnPage = page;
                                DvOrb.navigate_new("rename_task");
    }

    // true si `iso` est une date valide vieille de moins de `n` jours (cooldown en cours).
    bool _withinDays(String iso, int n) {

                                final t = DateTime.tryParse(iso)?.toUtc();
                                return t != null && DateTime.now().toUtc().difference(t).inSeconds < n * 86400;
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
