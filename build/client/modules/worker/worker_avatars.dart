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
// --- worker extension — Édition avatar/nom
// -----------------------------------------------------------------------------
extension Worker_avatars on worker {

    void _register_avatars() {

                                // Édition du personnage (écran Personnage) : bascule du mode édition,
                                // saisie du nom, ouverture de l'explorateur d'avatars + sélection.
                                ActionRegistry.register("worker.toggle_personnage_edit",    toggle_personnage_edit);

                                ActionRegistry.register("worker.edit_player_name",          edit_player_name);

                                ActionRegistry.register("worker.open_avatar_explorer",      open_avatar_explorer);

                                ActionRegistry.register("worker.on_avatar_selected",        on_avatar_selected);

                                // Édition du clan (écran Clan) : miroir de l'édition du personnage.
                                ActionRegistry.register("worker.toggle_clan_edit",          toggle_clan_edit);

                                ActionRegistry.register("worker.edit_clan_name",            edit_clan_name);

                                ActionRegistry.register("worker.open_clan_avatar_explorer", open_clan_avatar_explorer);

                                ActionRegistry.register("worker.on_clan_avatar_selected",   on_clan_avatar_selected);

    }

    //-----------------------------------------------------------------------
    //-- Édition du personnage (avatar + nom) -------------------------------
    //-----------------------------------------------------------------------

    // Bascule le mode édition : révèle/masque les 2 grosses icônes « edit »
    // (par-dessus l'avatar et le nom). État éphémère, aucune persistance.
    Future<void> toggle_personnage_edit(DvShape? caller, dynamic event) async {

                                _personnageEditMode = !_personnageEditMode;
                                _applyPersonnageEdit(_personnageEditMode);
    }

    void _applyPersonnageEdit(bool editing) {

                                final av = DvOrb.get_shape_by_id("personnage/edit_avatar_big");
                                final nm = DvOrb.get_shape_by_id("personnage/edit_name_big");
                                if (editing) { av?.show(); nm?.show(); }
                                else         { av?.hide(); nm?.hide(); }
                                // Grise/assombrit les widgets édités (avatar + nom) tant que le mode est actif.
                                _setDesaturate("personnage/icon",  editing);
                                _setDesaturate("personnage/label", editing);
    }

    // Active/désactive l'effet "disabled" (grisé + assombri) sur une shape.
    void _setDesaturate(String id, bool on) {

                                final s = DvOrb.get_shape_by_id(id);
                                s?.set("shape.desaturate", on);
                                s?.refreshUI();
    }

    Future<void> _exitPersonnageEdit() async {

                                _personnageEditMode = false;
                                _applyPersonnageEdit(false);
    }

    // Ouvre l'écran plein de renommage (player_rename_screen, réutilise la belle UI du
    // formulaire de nom). Remplace l'ancienne popup native DvInput.
    Future<void> edit_player_name(DvShape? caller, dynamic event) async {

                                DvOrb.navigate_new("player_rename_screen");
    }

    // Ouvre l'écran explorateur d'avatars (grille DvExplorer filtrée sur icon_XX_P_XX.png).
    Future<void> open_avatar_explorer(DvShape? caller, dynamic event) async {

                                DvOrb.navigate_new("avatar_explorer");
    }

    // Sélection d'un avatar dans l'explorateur : data = {selected:[...], tap:<file>}.
    // Persiste l'image via le layer runtime (rechargée au boot), met à jour l'avatar en
    // direct, revient à l'écran Personnage et sort du mode édition.
    Future<void> on_avatar_selected(dynamic caller, dynamic data) async {

                                String file = "";
                                if (data is Map) {
                                    file = data["tap"]?.toString() ?? "";
                                    if (file.isEmpty) {
                                        final sel = data["selected"];
                                        if (sel is List && sel.isNotEmpty) file = sel.first.toString();
                                    }
                                }
                                if (file.isEmpty) return;
                                final path = "images/medium/$file";

                                // Persistance : mute le layer runtime (merge defaults→runtime au boot) + flush disque.
                                await deva_set("registry.personnage/icon.shape.image", path);
                                await Deva.instance.store();

                                // Persiste aussi dans clans_players.avatar : source lue par le roster
                                // (affichage de MON avatar chez les autres joueurs). Deep-merge dvcloud.
                                await _persistPlayerAvatar(path);

                                // Mise à jour immédiate de l'avatar affiché.
                                final icon = DvOrb.get_shape_by_id("personnage/icon");
                                icon?.set("shape.image", path);
                                try { await icon?.appear(); } catch (e) { deva_log("warning", "[avatar] icon appear: $e"); }
                                icon?.refreshUI();

                                DvOrb.navigate_back("personnage");
                                await _exitPersonnageEdit();
    }

    // Écrit MON avatar dans clans_players/{clanId}/players/{userId}.avatar (deep-merge).
    Future<void> _persistPlayerAvatar(String path) async {

                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (region.isEmpty || _userId.isEmpty) return;
                                final session    = await _readSession(region);
                                final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) return;
                                try {
                                    // Deep-merge dvcloud (comme _touchLastTask) : seul `avatar` est écrit,
                                    // xp/pv/name/… préservés. `id` garanti si le merge devait créer le doc.
                                    final doc = Dvidle({});
                                    doc.set("id",     _userId);
                                    doc.set("avatar", path);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", _userId,
                                        doc, region: region, ownerId: clanSecret);
                                    deva_log("info", "[avatar] clans_players.avatar → $path");
                                } catch (e) {
                                    deva_log("error", "[avatar] clans_players.avatar write FAILED: $e");
                                }
    }

    //-----------------------------------------------------------------------
    //-- Édition du clan (avatar + nom) — miroir du personnage --------------
    //-----------------------------------------------------------------------

    Future<void> toggle_clan_edit(DvShape? caller, dynamic event) async {

                                _clanEditMode = !_clanEditMode;
                                _applyClanEdit(_clanEditMode);
    }

    void _applyClanEdit(bool editing) {

                                final av = DvOrb.get_shape_by_id("clan_page/edit_avatar_big");
                                final nm = DvOrb.get_shape_by_id("clan_page/edit_name_big");
                                if (editing) { av?.show(); nm?.show(); }
                                else         { av?.hide(); nm?.hide(); }
                                // Grise/assombrit les widgets édités (avatar + nom) tant que le mode est actif.
                                _setDesaturate("clan_page/icon",  editing);
                                _setDesaturate("clan_page/label", editing);
    }

    Future<void> _exitClanEdit() async {

                                _clanEditMode = false;
                                _applyClanEdit(false);
    }

    // Saisie du nouveau nom de clan (popup native). 1re lettre en majuscule,
    // persistance Firestore (workers/clans, ownerId: clanSecret) + session.
    Future<void> edit_clan_name(DvShape? caller, dynamic event) async {

                                final current = (await Deva.instance.get("session.clan.name"))?.toString() ?? "";
                                final title   = TranslationRegistry.translate("edit_clan_name_title");
                                final raw     = await DvInput.ask(title, initialValue: current);
                                if (raw == null) return;                 // annulé
                                final trimmed = raw.trim();
                                if (trimmed.isEmpty) return;
                                final name = _capitalizeFirst(trimmed);

                                await _persistClanName(name);

                                // Recalcule le label (re-résout @@@session.clan.name@@@ depuis la session).
                                final lbl = DvOrb.get_shape_by_id("clan_page/label");
                                if (lbl is DvLabel) { await lbl.computeDisplay(); lbl.refreshUI(); }

                                await _exitClanEdit();
    }

    // Persiste le nom du clan : lecture/écriture du doc workers/clans (ownerId: clanSecret)
    // + session.clan.name. Rechargé au boot via dvsession (session.clanname ↔ clans.internal.name).
    Future<void> _persistClanName(String name) async {

                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (region.isNotEmpty) {
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        try {
                                            final clan = await _cloud?.read("workers", "clans", clanId,
                                                ownerId: clanSecret, region: region) ?? Dvidle({});
                                            clan.rem("docId");
                                            clan.set("internal.name", name);
                                            await _cloud?.write("workers", "clans", clanId, clan,
                                                region: region, ownerId: clanSecret);
                                            deva_log("info", "[worker] clan name saved → firestore OK ($name)");
                                        } catch (e) {
                                            deva_log("error", "[worker] clan name FAILED: $e");
                                        }
                                    }
                                }
                                await Deva.instance.set("session.clan.name", name);
    }

    Future<void> open_clan_avatar_explorer(DvShape? caller, dynamic event) async {

                                DvOrb.navigate_new("clan_avatar_explorer");
    }

    Future<void> on_clan_avatar_selected(dynamic caller, dynamic data) async {

                                String file = "";
                                if (data is Map) {
                                    file = data["tap"]?.toString() ?? "";
                                    if (file.isEmpty) {
                                        final sel = data["selected"];
                                        if (sel is List && sel.isNotEmpty) file = sel.first.toString();
                                    }
                                }
                                if (file.isEmpty) return;
                                final path = "images/medium/$file";

                                await deva_set("registry.clan_page/icon.shape.image", path);
                                await Deva.instance.store();

                                // Persiste dans clans.avatar : source lue à l'affichage de l'écran Clan
                                // (par tous les membres). Deep-merge dvcloud (préserve xp/butin/etc.).
                                await _persistClanAvatar(path);

                                final icon = DvOrb.get_shape_by_id("clan_page/icon");
                                icon?.set("shape.image", path);
                                try { await icon?.appear(); } catch (e) { deva_log("warning", "[clan avatar] icon appear: $e"); }
                                icon?.refreshUI();

                                DvOrb.navigate_back("clan_page");
                                await _exitClanEdit();
    }

    // Écrit l'avatar du clan dans clans/{clanId}.avatar (deep-merge, ownerId: clanSecret).
    Future<void> _persistClanAvatar(String path) async {

                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (region.isEmpty) return;
                                final session    = await _readSession(region);
                                final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) return;
                                try {
                                    // Lecture/écriture du doc complet (comme _persistClanName) : pattern éprouvé
                                    // pour la collection `clans` (règles + ownerId présent dans le doc).
                                    final clan = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    clan.rem("docId");
                                    clan.set("avatar", path);
                                    await _cloud?.write("workers", "clans", clanId, clan,
                                        region: region, ownerId: clanSecret);
                                    deva_log("info", "[clan avatar] clans.avatar → $path");
                                } catch (e) {
                                    deva_log("error", "[clan avatar] clans.avatar write FAILED: $e");
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
