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
// --- worker extension — Écran Personnage
// -----------------------------------------------------------------------------
extension Worker_screen_personnage on worker {

    void _register_screen_personnage() {

                                ActionRegistry.register("worker.on_personnage_appear",      on_personnage_appear);

    }

    // caller peut être une DvPage (action appear de page) → typé dynamic, pas DvShape?.
    // Affichage de l'écran « Moi » (personnage) : lit l'xp du joueur courant et peint
    // l'indicateur niveau/progression/XP. Niveau et fraction de progression dérivés de
    // getNiveauProgres() ; rien n'est stocké, tout se recalcule à l'affichage.
    // La barre est composée de deux DvLabel (piste fixe + remplissage à largeur dynamique) ;
    // la flamme (DvImage) est centrée sur la pointe du remplissage. Les dimensions de cadrage
    // (trackX/trackW/flameW) sont LUES depuis les shapes (lvl_track, lvl_flame) → les réglages
    // de position/taille faits dans config.yml sont respectés sans toucher au code.
    // % d'une propriété de shape ("28%" → 28.0), avec repli si absente. Sync (lecture pure).
    // Partagé par _syncPersonnage / _syncClanHeader.
    double _pctOf(dynamic s, String key, double def) {

                                final v = s?.get(key)?.toString() ?? "";
                                return double.tryParse(v.replaceAll("%", "")) ?? def;
    }

    Future<void> on_personnage_appear(dynamic caller, dynamic event) async {

                                _stopCombatSiege();   // anti-fuite : coupe le son de combat si on quitte via la taskbar
                                // Shapes de la page ouverte. Elles naissent déjà remplies au rebuild (valeurs
                                // persistées en config registry par _sync* au dernier passage, comme l'avatar) ;
                                // ici on lit Firestore et on ne les met à jour QUE si une valeur a changé.
                                final track = await DvOrb.wait_for_shape("personnage/lvl_track");
                                final fill  = await DvOrb.wait_for_shape("personnage/lvl_fill");
                                final flame = await DvOrb.wait_for_shape("personnage/lvl_flame");
                                final lvl   = await DvOrb.wait_for_shape("personnage/lvl_label");
                                final xpLbl = await DvOrb.wait_for_shape("personnage/xp_label");
                                final title = await DvOrb.wait_for_shape("personnage/title_label");

                                // Barre de PV (miroir à droite). Icône = 2 images empilées (heart/Skull) dont
                                // on bascule la visibilité ; on ne swappe jamais shape.image à chaud.
                                final pvTrack = await DvOrb.wait_for_shape("personnage/pv_track");
                                final pvFill  = await DvOrb.wait_for_shape("personnage/pv_fill");
                                final pvHeart = await DvOrb.wait_for_shape("personnage/pv_heart");
                                final pvSkull = await DvOrb.wait_for_shape("personnage/pv_skull");
                                final pvLabel = await DvOrb.wait_for_shape("personnage/pv_label");

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";

                                    var xp = 0;
                                    var pv = _playerPv;   // repli : doc legacy sans champ pv → PV pleins
                                    var damage = 0;
                                    var decay = _playerDecay;
                                    var lastTask = "";
                                    // Titre PORTÉ (pas dérivé du niveau) : -1 = aucun, tant que le joueur
                                    // n'a pas appliqué l'item titre correspondant (cf. title_apply_player).
                                    var titleIdx = -1;
                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty && _userId.isNotEmpty) {
                                        final doc = await _cloud?.read(
                                            "workers", "clans_players/$clanId/players", _userId,
                                            ownerId: clanSecret, region: region) ?? Dvidle({});
                                        xp = int.tryParse(doc.get("xp")?.toString() ?? "0") ?? 0;
                                        pv = int.tryParse(doc.get("pv")?.toString() ?? "$_playerPv") ?? _playerPv;
                                        damage = int.tryParse(doc.get("damage")?.toString() ?? "0") ?? 0;
                                        decay = _readDecay(doc.get("decay"));
                                        lastTask = doc.get("last_task")?.toString() ?? "";
                                        titleIdx = int.tryParse(doc.get("title_idx")?.toString() ?? "-1") ?? -1;

                                        // Avatar du joueur : le layer runtime (rechargé au login) fournit déjà la
                                        // bonne image dès la première frame SUR CE DEVICE. Mais il est strictement
                                        // local (jamais poussé en Firestore) : sur un autre appareil, seul
                                        // clans_players.avatar (écrit par _persistPlayerAvatar) fait foi. On le relit
                                        // et on ne set/appear() QUE si la valeur diffère (changement fait depuis un
                                        // autre appareil) — sinon le set+appear() redondant re-décode l'image (flash).
                                        // Miroir exact de l'avatar de clan dans on_clan_appear.
                                        final playerAvatar = doc.get("avatar")?.toString() ?? "";
                                        final pIcon  = DvOrb.get_shape_by_id("personnage/icon");
                                        final wanted = playerAvatar.isNotEmpty ? playerAvatar : _defaultPlayerAvatar;
                                        final curImg = pIcon?.get("shape.image")?.toString() ?? "";
                                        if (wanted != curImg) {
                                            pIcon?.set("shape.image", wanted);
                                            try { await pIcon?.appear(); } catch (e) { deva_log("warning", "[personnage] icon appear: $e"); }
                                            pIcon?.refreshUI();
                                            // Resynchronise le runtime local pour connaître l'image dès le prochain boot.
                                            if (playerAvatar.isNotEmpty) {
                                                await deva_set("registry.personnage/icon.shape.image", playerAvatar);
                                                await Deva.instance.store();
                                            }
                                        }
                                    }

                                    // Sync UI ← Firestore : persiste les valeurs dans la config registry
                                    // (born-filled au prochain rebuild) et ne touche l'instance vive QUE si la
                                    // valeur a changé (diff) → pas de scintillement quand rien ne bouge.
                                    await _syncPersonnage(caller: caller, track: track, fill: fill, flame: flame,
                                        lvl: lvl, xpLbl: xpLbl, title: title, pvTrack: pvTrack, pvFill: pvFill,
                                        pvHeart: pvHeart, pvSkull: pvSkull, pvLabel: pvLabel,
                                        xp: xp, pv: pv, damage: damage, decay: decay, lastTask: lastTask,
                                        titleIdx: titleIdx);

                                    // Montée de niveau d'abord (prioritaire), puis évaluation de la mort : sur une
                                    // transition mort → vivant (soin pendant l'absence), _evaluateDeath déclenche
                                    // l'animation de soin AU MOMENT du retrait du crâne. celebrateHeal=false si une
                                    // montée a été célébrée (jamais deux animations à la fois). UNIQUEMENT sur le
                                    // flux frais — jamais sur la peinture cache (sinon double célébration).
                                    final leveled = await _checkPlayerLevelUp();
                                    await _evaluateDeath(celebrateHeal: !leveled, celebrateDeath: !leveled);
                                    // DIAG temporaire : expose last_task + jours écoulés pour comprendre pourquoi
                                    // la dégradation temporelle ne s'applique pas (loss=0).
                                    final np = getNiveauProgres(xp);
                                    final pvShownLog = _computeDisplayedPv(pv, damage, lastTask, decay);
                                    final diagLast = DateTime.tryParse(lastTask)?.toUtc();
                                    final diagDays = diagLast == null ? -1.0
                                        : DateTime.now().toUtc().difference(diagLast).inSeconds / 86400.0;
                                    deva_log("info", "[personnage] niveau=${np.niveau} progres=${(np.progres * 100).round()}% xp=$xp "
                                        "pv=$pvShownLog/${_playerPv} (stocké=$pv damage=$damage decay=$decay "
                                        "last_task='$lastTask' elapsedJ=${diagDays.toStringAsFixed(5)})${pvShownLog <= 0 ? " (MORT)" : ""}");
                                } catch (e) {
                                    deva_log("error", "[personnage] on_personnage_appear FAILED: $e");
                                }
    }

    // ---- Sync d'une prop de shape vers l'instance vive ET la config registry (born-filled) ----
    // Écrit une prop UNIQUEMENT si elle a changé (diff contre l'instance vive, elle-même née du
    // registry). `deva_set` met à jour _store (config fusionnée) → à la reconstruction de la page
    // la shape naît déjà remplie, comme l'avatar. Retourne true si modifié (le caller ne rafraîchit
    // la page globale que si au moins une prop a changé). store() disque non appelé ici (le logout
    // le fait déjà, cf. Deva.stop) : la mise à jour mémoire de _store suffit pour naviguer/revenir.
    Future<bool> _syncGeom(dynamic shape, String id, String prop, String val) async {

                                if (shape == null || shape.get(prop)?.toString() == val) return false;
                                shape.set(prop, val);                        // page ouverte (immédiat)
                                await deva_set("registry.$id.$prop", val);   // _store → born-filled au rebuild
                                shape.refresh();                             // recalcule les pixels depuis le "%"
                                return true;
    }

    Future<bool> _syncLabel(dynamic shape, String id, String text) async {

                                if (shape is! DvLabel || shape.get("shape.label")?.toString() == text) return false;
                                shape.set("shape.label", text);
                                await deva_set("registry.$id.shape.label", text);
                                await shape.computeDisplay();
                                shape.refreshUI();
                                return true;
    }

    Future<bool> _syncVisible(dynamic shape, String id, bool visible) async {

                                if (shape == null || (shape.get("shape.visible") == true) == visible) return false;
                                if (visible) { shape.show(); } else { shape.hide(); }   // instance vive + refreshUI
                                await deva_set("registry.$id.shape.visible", visible);  // born-filled
                                return true;
    }

    // Écran Personnage : calcule les valeurs cibles (niveau/prog, PV affichés) puis les synchronise
    // vers les shapes (config registry + instance vive) via _sync*. Aucune animation, aucune lecture.
    Future<void> _syncPersonnage({

                required dynamic caller,
                required dynamic track, required dynamic fill,  required dynamic flame,
                required dynamic lvl,   required dynamic xpLbl, required dynamic title,
                required dynamic pvTrack, required dynamic pvFill, required dynamic pvHeart,
                required dynamic pvSkull, required dynamic pvLabel,
                required int xp, required int pv, required int damage,
                required double decay, required String lastTask,
                required int titleIdx,
    }) async {

                                final trackX   = _pctOf(track,   "shape.x", 5.0);
                                final trackW   = _pctOf(track,   "shape.w", 28.0);
                                final flameW   = _pctOf(flame,   "shape.w", 10.0);
                                final pvTrackX = _pctOf(pvTrack, "shape.x", 66.0);
                                final pvTrackW = _pctOf(pvTrack, "shape.w", 29.0);
                                final pvHeartW = _pctOf(pvHeart, "shape.w", 10.0);

                                final np   = getNiveauProgres(xp);
                                final niv  = np.niveau;
                                final prog = np.progres;

                                var ch = false;
                                // Barre XP : remplissage (jamais 0 pour rester visible) + flamme sur la pointe.
                                final fillW  = (prog * trackW).clamp(0.5, trackW);
                                final flameX = (trackX + prog * trackW - flameW / 2).clamp(0.0, 100.0 - flameW);
                                ch = await _syncGeom(fill,  "personnage/lvl_fill",  "shape.w", "${fillW.toStringAsFixed(2)}%")  || ch;
                                ch = await _syncGeom(flame, "personnage/lvl_flame", "shape.x", "${flameX.toStringAsFixed(2)}%") || ch;
                                ch = await _syncLabel(lvl,   "personnage/lvl_label",   "$niv")                              || ch;
                                ch = await _syncLabel(xpLbl, "personnage/xp_label",    "$xp / ${_xpForNiveau(niv + 1)} XP") || ch;
                                // Titre PORTÉ, plus dérivé du niveau : cf. clans_players.title_idx,
                                // posé par l'option « Porter ce titre » de l'item titre.
                                ch = await _syncLabel(title, "personnage/title_label", _titleKeyOf("player_title", titleIdx)) || ch;

                                // Barre PV (ancrée à gauche, grandit vers la droite) : pvShown / _playerPv.
                                final pvShown = _computeDisplayedPv(pv, damage, lastTask, decay);
                                final pvMax   = _playerPv <= 0 ? 1 : _playerPv;
                                final pvProg  = (pvShown / pvMax).clamp(0.0, 1.0);
                                final dead    = pvShown <= 0;
                                final pvFillW = (pvProg * pvTrackW).clamp(0.5, pvTrackW);
                                final pvIconX = (pvTrackX + pvProg * pvTrackW - pvHeartW / 2).clamp(0.0, 100.0 - pvHeartW);
                                ch = await _syncGeom(pvFill,  "personnage/pv_fill",  "shape.x", "${pvTrackX.toStringAsFixed(2)}%") || ch;
                                ch = await _syncGeom(pvFill,  "personnage/pv_fill",  "shape.w", "${pvFillW.toStringAsFixed(2)}%")  || ch;
                                ch = await _syncGeom(pvHeart, "personnage/pv_heart", "shape.x", "${pvIconX.toStringAsFixed(2)}%")  || ch;
                                ch = await _syncGeom(pvSkull, "personnage/pv_skull", "shape.x", "${pvIconX.toStringAsFixed(2)}%")  || ch;
                                ch = await _syncLabel(pvLabel, "personnage/pv_label", "$pvShown / $_playerPv")                     || ch;
                                // Bascule icône : crâne à 0 PV, cœur sinon (visibilité persistée → correcte à la naissance).
                                ch = await _syncVisible(pvHeart, "personnage/pv_heart", !dead) || ch;
                                ch = await _syncVisible(pvSkull, "personnage/pv_skull", dead)  || ch;

                                if (ch) caller?.refreshUI();
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
