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

// Clés SharedPreferences de l'emprunt de compte. Locales et privées à l'application :
// ddust relit un layer `runtime-<ownerId>` au login, et un code secret n'a rien à faire
// sur un chemin dont il faudrait démontrer qu'il ne monte jamais en ligne.
// Effacées ensemble par _impClear — un emprunt à moitié oublié serait pire qu'aucun.
const String _kImpActive     = "ddust_imp_active";
const String _kImpAuthId     = "ddust_imp_auth_id";
const String _kImpAuthName   = "ddust_imp_auth_name";
const String _kImpTargetId   = "ddust_imp_target_id";
const String _kImpTargetName = "ddust_imp_target_name";
const String _kImpPin        = "ddust_imp_pin";
const String _kImpLockUntil  = "ddust_imp_lock_until";

// Longueur du code. 4 chiffres : assez pour qu'un enfant ne tombe pas dessus, assez court
// pour qu'un adulte le retienne le temps d'une partie.
const int _kImpPinLength = 4;

// Délai de rétractation du retrait de consentement parental, en jours.
//
// ⚠ 3 ET NON 30. Les deux nombres cohabitent dans le corpus légal et ne mesurent pas la même
// chose (readme § 23, « les trois horloges ») : 3 jours pendant lesquels un chef du clan
// d'origine peut REVENIR sur sa décision, puis la suppression, puis 30 jours de conservation
// restreinte hors du service, SANS retour possible, avant l'effacement définitif. Le § 9 des
// 84 politiques de confidentialité adultes annonçait 30 jours de rétractation ; c'était une
// erreur, corrigée dans les 168 documents le 2026-09-10. Changer cette valeur oblige à
// reprendre le corpus.
const int _kConsentGraceDays = 3;

// Échecs tolérés avant de remplacer le pavé par la sortie. Le compteur ne punit pas, il
// RÉVÈLE : au 5e, soit on propose le verrou de l'appareil, soit on verrouille.
const int _kImpMaxTries = 5;

// Verrouillage quand l'appareil n'a PAS de verrou. Il n'y a alors aucune sortie à proposer,
// et laisser le pavé ouvert ne servirait à rien puisque le code est justement oublié :
// l'attente est la seule monnaie qui distingue encore l'adulte de l'enfant. À l'échéance,
// l'application rend la main au compte d'origine toute seule.
const int _kImpLockMinutes = 10;

// -----------------------------------------------------------------------------
// --- worker extension — Roster admin (autres joueurs)
// -----------------------------------------------------------------------------
extension Worker_members on worker {

    void _register_members() {

                                ActionRegistry.register("worker.revive_player",             revive_player);

                                ActionRegistry.register("worker.support_player",            support_player);

                                // Options roster (boutons/menu). promote_chief est implémenté ; declare_offline /
                                // promote_adult / revoke_player restent des stubs journalisés.
                                ActionRegistry.register("worker.declare_offline",           declare_offline);

                                ActionRegistry.register("worker.take_place",                take_place);

                                ActionRegistry.register("worker.restore_self",              restore_self);

                                ActionRegistry.register("worker.promote_chief",             promote_chief);

                                // « Plus chef » (rétrogradation) : opposé de promote_chief.
                                ActionRegistry.register("worker.nomore_chief",              nomore_chief);

                                ActionRegistry.register("worker.promote_adult",             promote_adult);

                                // Hors concours : paire exclusive, sur un joueur ADULTE (y compris soi-même).
                                ActionRegistry.register("worker.hors_concours_on",          hors_concours_on);
                                ActionRegistry.register("worker.hors_concours_off",         hors_concours_off);

                                ActionRegistry.register("worker.revoke_player",             revoke_player);

                                // --- Retrait du consentement parental (art. 7(3) RGPD) ------------
                                // Deux gestes symétriques et un overlay de confirmation partagé.
                                ActionRegistry.register("worker.withdraw_consent",          withdraw_consent);
                                ActionRegistry.register("worker.restore_consent",           restore_consent);
                                ActionRegistry.register("worker.on_consent_confirm",        on_consent_confirm);
                                ActionRegistry.register("worker.on_consent_cancel",         on_consent_cancel);

                                // --- Emprunt de compte : code temporaire ---------------------------
                                // Poser le code au moment de prêter, le redemander au moment de reprendre.
                                ActionRegistry.register("worker.on_imp_pin_set_appear",     on_imp_pin_set_appear);
                                ActionRegistry.register("worker.on_imp_pin_set",            on_imp_pin_set);
                                ActionRegistry.register("worker.on_imp_pin_set_cancel",     on_imp_pin_set_cancel);
                                ActionRegistry.register("worker.open_imp_pin_ask",          open_imp_pin_ask);
                                ActionRegistry.register("worker.on_imp_pin_ask_appear",     on_imp_pin_ask_appear);
                                ActionRegistry.register("worker.on_imp_pin_ask",            on_imp_pin_ask);
                                ActionRegistry.register("worker.on_imp_pin_cancel",         on_imp_pin_cancel);
                                ActionRegistry.register("worker.on_imp_device_unlock",      on_imp_device_unlock);

    }

    // =========================================================================================
    // --- EMPRUNT DE COMPTE : persistance et code temporaire
    // =========================================================================================
    //
    // Le geste encadré ici : un adulte prête son téléphone à son enfant en prenant la place de
    // celui-ci dans le jeu. Ce qu'il faut empêcher, c'est le retour au compte adulte d'un simple
    // toucher — l'enfant y trouverait les options d'administration, dont la validation de ses
    // PROPRES tâches. Ce n'est pas de l'argent (la boutique est fermée aux non-adultes, cf.
    // _storeCanBuy), c'est de la triche, et c'est ce qui est réellement en jeu.
    //
    // CE N'EST PAS UNE SERRURE, et le dossier ne doit rien promettre de tel : l'enfant tient un
    // téléphone déverrouillé, et effacer les données de l'application depuis les réglages Android
    // remet tout à zéro. Aucune vérification applicative ne franchit cette limite. C'est un cran
    // contre le retour accidentel ou opportuniste — et, accessoirement, c'est aussi la porte de
    // sortie de l'adulte qui aurait oublié son propre code.

    Future<void> _impPersist(String targetId, String targetName) async {

                                try {
                                    final p = await SharedPreferences.getInstance();
                                    await p.setBool(_kImpActive,       true);
                                    await p.setString(_kImpAuthId,     _authUserId);
                                    await p.setString(_kImpAuthName,   _realUserName);
                                    await p.setString(_kImpTargetId,   targetId);
                                    await p.setString(_kImpTargetName, targetName);
                                    await p.setString(_kImpPin,        _impPin);
                                    await p.setInt(_kImpLockUntil,     _impLockUntil);
                                } catch (e) {
                                    deva_log("error", "[roster] persistance de l'emprunt FAILED: $e");
                                }
    }

    Future<void> _impPersistLock() async {

                                try {
                                    final p = await SharedPreferences.getInstance();
                                    await p.setInt(_kImpLockUntil, _impLockUntil);
                                } catch (e) {
                                    deva_log("error", "[roster] persistance du verrouillage FAILED: $e");
                                }
    }

    Future<void> _impClear() async {

                                _impPin       = "";
                                _impPinTries  = 0;
                                _impLockUntil = 0;
                                try {
                                    final p = await SharedPreferences.getInstance();
                                    for (final k in [_kImpActive, _kImpAuthId, _kImpAuthName,
                                                     _kImpTargetId, _kImpTargetName, _kImpPin,
                                                     _kImpLockUntil]) {
                                        await p.remove(k);
                                    }
                                } catch (e) {
                                    deva_log("error", "[roster] effacement de l'emprunt FAILED: $e");
                                }
    }

    // Reprise au démarrage, appelée par on_login une fois l'identité authentifiée établie et le
    // contexte de clan connu. Rend true si un emprunt a été repris — l'appelant sait alors que
    // _userId n'est PAS l'utilisateur authentifié.
    //
    // Trois raisons de ne pas reprendre, et chacune rend la main à l'adulte plutôt que de laisser
    // un état bancal : l'échéance du verrouillage est passée (c'est le retour automatique promis),
    // l'identité authentifiée a changé (autre compte sur le même appareil), ou le joueur emprunté
    // n'est plus dans le clan (révoqué ou supprimé pendant que l'application était fermée).
    //
    // Repli en cas d'erreur : NE PAS reprendre. Rester sur son propre compte est le pire cas
    // acceptable ; croire emprunter sans savoir qui ne l'est pas.
    Future<bool> _impRestore(String clanId, String clanSecret, String region) async {

                                try {
                                    final p = await SharedPreferences.getInstance();
                                    if (p.getBool(_kImpActive) != true) return false;

                                    final authId     = p.getString(_kImpAuthId)     ?? "";
                                    final authName   = p.getString(_kImpAuthName)   ?? "";
                                    final targetId   = p.getString(_kImpTargetId)   ?? "";
                                    final targetName = p.getString(_kImpTargetName) ?? "";
                                    final pin        = p.getString(_kImpPin)        ?? "";
                                    final lockUntil  = p.getInt(_kImpLockUntil)     ?? 0;

                                    if (authId.isEmpty || targetId.isEmpty || authId != _authUserId) {
                                        deva_log("info", "[roster] emprunt persisté ignoré : autre compte authentifié");
                                        await _impClear();
                                        return false;
                                    }
                                    if (lockUntil > 0 && DateTime.now().millisecondsSinceEpoch >= lockUntil) {
                                        deva_log("info", "[roster] emprunt : verrouillage échu → retour au compte d'origine");
                                        await _impClear();
                                        return false;
                                    }
                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        final target = await _cloud?.read("workers", "clans_players/$clanId/players",
                                            targetId, ownerId: clanSecret, region: region);
                                        if (target == null || target.get("enabled") == false) {
                                            deva_log("info", "[roster] emprunt : joueur $targetId absent du clan → abandon");
                                            await _impClear();
                                            return false;
                                        }
                                    }

                                    _realUserName  = authName;
                                    _impPin        = pin;
                                    _impLockUntil  = lockUntil;
                                    _impPinTries   = 0;
                                    _impersonating = true;
                                    _userId        = targetId;
                                    await Deva.instance.set("session.user.id",   targetId);
                                    await Deva.instance.set("session.user.name", targetName);
                                    await deva_set("worker.impersonating", "true");
                                    await _applyImpersonation(true, targetName);
                                    deva_log("info", "[roster] emprunt repris au démarrage : $targetName ($targetId)");
                                    return true;
                                } catch (e) {
                                    deva_log("error", "[roster] reprise de l'emprunt FAILED: $e");
                                    return false;
                                }
    }



    // --- Écrans du code temporaire ------------------------------------------------------------
    //
    // Le pavé numérique (DvNumpad) lit et écrit sa valeur DANS SA CIBLE D'AFFICHAGE : c'est ce qui
    // permet de masquer la saisie sans le réécrire. La cible réelle (`.../buffer`) est invisible et
    // porte les chiffres ; un second label (`.../mask`) montre des points. Vider le buffer suffit
    // à repartir d'une saisie neuve.
    // `show_ok: false` fait auto-valider le pavé à CHAQUE chiffre : les gestionnaires ignorent
    // donc tout ce qui n'a pas la longueur attendue.

    void _impMask(String screen, String value) {

                                final buf = DvOrb.get_shape_by_id("$screen/buffer");
                                buf?.set("shape.label",   value);
                                buf?.set("shape.display", value);
                                final mask = DvOrb.get_shape_by_id("$screen/mask");
                                mask?.set("shape.label",   "•" * value.length);
                                mask?.set("shape.display", "•" * value.length);
                                mask?.refreshUI();
    }

    void _impResetEntry(String screen) {

                                _impMask(screen, "");
    }

    void _impSay(String id, String key, {Map<String, String> vars = const {}}) {

                                final shape = DvOrb.get_shape_by_id(id);
                                if (shape == null) return;
                                var txt = "@@@T:$key@@@";
                                vars.forEach((k, v) => txt = txt.replaceAll("{$k}", v));
                                shape.set("shape.label",   txt);
                                shape.set("shape.display", txt);
                                shape.refreshUI();
    }

    void _impShow(String id, bool visible) {

                                final shape = DvOrb.get_shape_by_id(id);
                                shape?.set("shape.visible", visible);
                                shape?.refreshUI();
    }

    // --- Écran « je choisis mon code » (avant de prêter) --------------------------------------

    Future<void> on_imp_pin_set_appear(dynamic caller, dynamic event) async {

                                _impResetEntry("imp_pin_set");
    }

    Future<void> on_imp_pin_set(dynamic caller, dynamic event) async {

                                final v = event?.toString() ?? "";
                                _impMask("imp_pin_set", v);
                                if (v.length < _kImpPinLength) return;

                                _impPin       = v;
                                _impLockUntil = 0;
                                _impPinTries  = 0;
                                _impResetEntry("imp_pin_set");

                                final id   = _impPendingId;
                                final name = _impPendingName;
                                _impPendingId   = "";
                                _impPendingName = "";
                                if (id.isEmpty) { DvOrb.navigate_reset("clan_page"); return; }
                                await _doTakePlace(id, name);
    }

    // Renoncer AVANT la bascule : il ne s'est rien passé, l'adulte est toujours chez lui.
    Future<void> on_imp_pin_set_cancel(dynamic caller, dynamic event) async {

                                _impPendingId   = "";
                                _impPendingName = "";
                                _impPin         = "";
                                _impResetEntry("imp_pin_set");
                                DvOrb.navigate_reset("clan_page");
    }

    // --- Écran « je reprends mon compte » (tap sur le bandeau) --------------------------------

    // Tap du bandeau « vous incarnez X ». Ne rend RIEN par lui-même : il ouvre l'écran de saisie.
    // Garde de cohérence — hors emprunt, le bandeau ne devrait pas être là ; s'il l'est, ne pas
    // ouvrir une demande de code qui n'aurait personne à qui rendre la main.
    Future<void> open_imp_pin_ask(dynamic caller, dynamic event) async {

                                if (!_impersonating) return;
                                DvOrb.navigate_new("imp_pin_ask");
    }

    Future<void> on_imp_pin_ask_appear(dynamic caller, dynamic event) async {

                                _impPinTries = 0;
                                _impResetEntry("imp_pin_ask");
                                _impSay("imp_pin_ask/message", "imp_pin_ask_intro");

                                // Verrouillage en cours (appareil sans verrou) : le pavé ne sert à rien,
                                // le code étant justement oublié. On affiche l'échéance et on garde le
                                // minuteur armé — la restitution est promise, elle ne dépend pas de l'écran.
                                final now = DateTime.now().millisecondsSinceEpoch;
                                if (_impLockUntil > now) {
                                    _impLocked((_impLockUntil - now));
                                    return;
                                }
                                if (_impLockUntil > 0) {
                                    // Échéance passée pendant que l'application tournait : on rend la main.
                                    await restore_self(null, null);
                                    return;
                                }
                                _impShow("imp_pin_ask/numpad", true);
                                _impShow("imp_pin_ask/mask",   true);
                                _impShow("imp_pin_ask/unlock", false);
    }

    Future<void> on_imp_pin_ask(dynamic caller, dynamic event) async {

                                if (!_impersonating) return;
                                final v = event?.toString() ?? "";
                                _impMask("imp_pin_ask", v);
                                if (v.length < _kImpPinLength) return;
                                _impResetEntry("imp_pin_ask");

                                if (_impPin.isNotEmpty && v == _impPin) {
                                    await restore_self(null, null);
                                    return;
                                }

                                _impPinTries++;
                                final restants = _kImpMaxTries - _impPinTries;
                                if (restants > 0) {
                                    _impSay("imp_pin_ask/message", "imp_pin_ask_left",
                                            vars: {"n": "$restants"});
                                    return;
                                }

                                // Cinquième échec : le pavé disparaît. Ce qui le remplace dépend de
                                // l'appareil, et c'est le seul endroit où cette distinction compte.
                                _impShow("imp_pin_ask/numpad", false);
                                _impShow("imp_pin_ask/mask",   false);

                                final verrouOk = await _devicelock?.available() ?? false;
                                if (verrouOk) {
                                    _impSay("imp_pin_ask/message", "imp_pin_ask_blocked");
                                    _impShow("imp_pin_ask/unlock", true);
                                    return;
                                }

                                // Pas de verrou d'appareil : il n'y a rien à proposer. On verrouille, et
                                // l'application rendra la main toute seule. Persisté, sinon « Annuler »
                                // suffirait à l'effacer ; et le minuteur est armé indépendamment de l'écran.
                                _impLockUntil = DateTime.now().millisecondsSinceEpoch
                                              + _kImpLockMinutes * 60 * 1000;
                                await _impPersistLock();
                                _impArmLockTimer(_kImpLockMinutes * 60 * 1000);
                                _impLocked(_kImpLockMinutes * 60 * 1000);
    }

    void _impLocked(int restantMs) {

                                final minutes = (restantMs / 60000).ceil();
                                _impShow("imp_pin_ask/numpad", false);
                                _impShow("imp_pin_ask/mask",   false);
                                _impShow("imp_pin_ask/unlock", false);
                                _impSay("imp_pin_ask/message", "imp_pin_ask_locked",
                                        vars: {"n": "$minutes"});
    }

    void _impArmLockTimer(int ms) {

                                _impLockTimer?.cancel();
                                _impLockTimer = Timer(Duration(milliseconds: ms), () async {
                                    _impLockTimer = null;
                                    if (!_impersonating) return;
                                    deva_log("info", "[roster] emprunt : échéance atteinte → restitution");
                                    await restore_self(null, null);
                                });
    }

    // Annuler : on RESTE sur le compte de l'enfant. C'est le comportement sûr — refermer une
    // demande de code ne doit jamais valoir réponse correcte.
    Future<void> on_imp_pin_cancel(dynamic caller, dynamic event) async {

                                _impResetEntry("imp_pin_ask");
                                DvOrb.navigate_reset("dashboard");
    }

    // Sortie de secours après cinq échecs, quand l'appareil sait vérifier son propriétaire.
    // Elle plafonne la garantie au verrou de l'appareil, et c'est assumé : un adulte qui a oublié
    // son code doit pouvoir rentrer chez lui sans support ni réinitialisation.
    Future<void> on_imp_device_unlock(dynamic caller, dynamic event) async {

                                if (!_impersonating) return;
                                final raison = await _resolveDesc("imp_pin_unlock_reason");
                                final ok = await _devicelock?.authenticate(
                                    raison.isNotEmpty ? raison : "Reprendre mon compte") ?? false;
                                if (!ok) return;
                                await restore_self(null, null);
    }

    // Date `last_task` qui produit exactement `lossTarget` points de dégradation temporelle.
    // Les PV ne sont JAMAIS stockés : ils se calculent depuis last_task (cf. _computeDisplayedPv,
    // loss = floor(joursÉcoulés / decay)). Soigner, c'est donc RECULER cette date, jamais écrire
    // un nombre de PV.
    // Le +0.5 vise le MILIEU du palier : à la charnière exacte, le floor bascule d'une unité au
    // gré de quelques microsecondes de latence, et le joueur verrait un PV de moins que promis.
    // Extrait de revive_player pour être partagé avec les cadeaux de soin de la fée
    // (_healPlayer) : chaque appelant calcule SON lossTarget, seule la conversion est commune.
    String _lastTaskForLoss(int lossTarget, double decay) {

                                final safe = lossTarget < 0 ? 0 : lossTarget;
                                final elapsedSeconds = (safe + 0.5) * decay * 86400.0;
                                return DateTime.now().toUtc()
                                    .subtract(Duration(microseconds: (elapsedSeconds * 1000000).round()))
                                    .toIso8601String();
    }

    // Soigne un joueur de `pv` points — un GAIN, et non une remise à un niveau fixe. C'est en
    // cela que ce helper diffère de revive_player, qui vise `_healPv` PV dans l'absolu : la fée
    // promet « la santé », pas une valeur.
    //
    // Deuxième différence, et elle compte : le `damage` est PRIS EN COMPTE dans le calcul de la
    // cible (loss = maxPv − damage − cible), pour que le gain annoncé soit le gain reçu. Le champ
    // `damage` lui-même n'est pas touché — la blessure reste, on ne fait que remonter le temps
    // assez loin pour la compenser. Si elle est trop profonde pour que la cible soit atteignable,
    // on remonte au maximum possible (loss = 0) plutôt que d'échouer en silence.
    Future<void> _healPlayer(String clanId, String clanSecret, String region,
                             String playerId, int pv) async {

                                if (clanId.isEmpty || clanSecret.isEmpty || playerId.isEmpty || pv <= 0) return;
                                try {
                                    final doc = await _cloud?.read("workers", "clans_players/$clanId/players",
                                        playerId, ownerId: clanSecret, region: region) ?? Dvidle({});
                                    final maxPv  = int.tryParse(doc.get("pv")?.toString() ?? "$_playerPv") ?? _playerPv;
                                    final damage = int.tryParse(doc.get("damage")?.toString() ?? "0") ?? 0;
                                    final decay  = _readDecay(doc.get("decay"));
                                    final last   = doc.get("last_task")?.toString() ?? "";

                                    final current = _computeDisplayedPv(maxPv, damage, last, decay);
                                    if (current >= maxPv) {
                                        deva_log("info", "[fairy] $playerId est déjà au maximum ($maxPv PV) — rien à soigner");
                                        return;
                                    }
                                    var target = current + pv;
                                    if (target > maxPv) target = maxPv;
                                    final newLastIso = _lastTaskForLoss(maxPv - damage.abs() - target, decay);
                                    final pvShown    = _computeDisplayedPv(maxPv, damage, newLastIso, decay);

                                    final out = Dvidle({});
                                    out.set("id", playerId);
                                    out.set("last_task", newLastIso);
                                    // Comme revive_player : on ne repasse "alive" que si le joueur est
                                    // RÉELLEMENT revenu à la vie. Un soin qui ne suffit pas laisse mort.
                                    if (pvShown > 0) out.set("status", "alive");
                                    await _cloud?.write("workers", "clans_players/$clanId/players", playerId, out,
                                        region: region, ownerId: clanSecret);

                                    deva_log("info", "[fairy] soin $playerId : $current → $pvShown PV "
                                        "(demandé +$pv, max=$maxPv, damage=$damage)");
                                } catch (e) {
                                    deva_log("error", "[fairy] _healPlayer($playerId) FAILED: $e");
                                }
    }

    // Action « Guérir le joueur » (admin, joueur mort). `event` = data du joueur cliqué.
    // Recale last_task pour que la dégradation temporelle ramène les PV à la MOITIÉ des PV
    // max (hors damage) : on impose loss = maxPv − maxPv÷2 en posant last_task à
    // now − (loss + 0.5)·decay jours (le +0.5 tombe au milieu du palier → floor stable).
    // Le champ `damage` reste hors scope : si damage ≥ moitié des PV, pvShown ≤ 0 et le
    // joueur reste mort. S'il est réellement ressuscité (pvShown > 0), on repasse status="alive".
    Future<void> revive_player(dynamic caller, dynamic event) async {

                                final m  = (event is Map) ? event : const {};
                                final id = m["id"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // PV max stocké + damage + decay du joueur (pas dans `data` : on lit le doc).
                                    final doc = await _cloud?.read("workers", "clans_players/$clanId/players", id,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    final maxPv  = int.tryParse(doc.get("pv")?.toString() ?? "$_playerPv") ?? _playerPv;
                                    final damage = int.tryParse(doc.get("damage")?.toString() ?? "0") ?? 0;
                                    final decay  = _readDecay(doc.get("decay"));
                                    final gage   = doc.get("gage")?.toString() ?? "";   // gage porté (pour le journal)

                                    final healTarget = (maxPv < _healPv) ? maxPv : _healPv;   // rendre _healPv PV (borné à maxPv)
                                    final lossTarget = maxPv - healTarget;                     // → pv − loss = healTarget
                                    final newLastIso = _lastTaskForLoss(lossTarget, decay);

                                    final pvShown = _computeDisplayedPv(maxPv, damage, newLastIso, decay);

                                    // Écriture (deep-merge → préserve pv/xp/damage/…) : last_task + status si vivant.
                                    final out = Dvidle({});
                                    out.set("id", id);
                                    out.set("last_task", newLastIso);
                                    if (pvShown > 0) out.set("status", "alive");
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, out,
                                        region: region, ownerId: clanSecret);

                                    deva_log("info", "[roster] revive_player ${m["name"]} ($id): visé=$healTarget PV "
                                        "→ pvShown=$pvShown (damage=$damage)${pvShown > 0 ? " alive" : " reste mort"}");

                                    // Journal : ne logger que si le joueur est réellement revenu à la vie.
                                    if (pvShown > 0) {
                                        final adminName  = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                        final playerName = m["name"]?.toString() ?? id;
                                        await _writeClanLog(clanId, clanSecret, region, "PlayerResurrected",
                                            userId: id, adminId: _userId, slug: gage,
                                            data: Dvidle({"playerId": id, "playerName": playerName,
                                                          "gage": gage, "adminId": _userId, "adminName": adminName}));
                                    }

                                    // Cooldown de cure de l'acteur : pose last_cure=now sur son doc
                                    // membre clans_players (deep-merge, ownerId = clanSecret) + cache.
                                    final now = DateTime.now().toUtc().toIso8601String();
                                    final u = Dvidle({});
                                    u.set("last_cure", now);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", _userId, u,
                                        region: region, ownerId: clanSecret);
                                    _myLastCure = now;

                                    // Rafraîchit les tuiles (re-lit clans_players et re-pousse au DvRoster).
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] revive_player FAILED: $e");
                                }
    }

    // Action « Coup de pouce » (admin, joueur le moins gradé). `event` = data du joueur.
    // +50 XP au joueur SEUL (via _creditXp) : ni clan (clans/{clanId}.xp) ni butin (butin_xp)
    // ne sont crédités (on n'appelle PAS _creditClanXp). Pose le cooldown boost de l'acteur.
    Future<void> support_player(dynamic caller, dynamic event) async {

                                final m  = (event is Map) ? event : const {};
                                final id = m["id"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // +50 XP joueur seul (deep-merge sur clans_players ; niveau dérivé de xp).
                                    await _creditXp(clanId, clanSecret, region, id, 50);

                                    // Cooldown de boost de l'acteur : last_boost=now sur son doc membre
                                    // clans_players (deep-merge, ownerId = clanSecret) + cache.
                                    final now = DateTime.now().toUtc().toIso8601String();
                                    final u = Dvidle({});
                                    u.set("last_boost", now);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", _userId, u,
                                        region: region, ownerId: clanSecret);
                                    _myLastBoost = now;

                                    deva_log("info", "[roster] support_player: +50 XP → ${m["name"]} ($id)");

                                    // Rafraîchit les tuiles (le niveau peut avoir monté).
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] support_player FAILED: $e");
                                }
    }

    // --- Actions roster encore en stub (journalisées) ------------------------
    // Chacune reçoit la charge utile du joueur ciblé (comme le menu). On journalise pour l'instant ;
    // les vraies implémentations viendront plus tard. (promote_chief / nomore_chief, plus bas, sont
    // implémentés.)
    // Action « Déclarer hors ligne » (admin) : pose has_device=false sur le doc clans_players du
    // joueur ciblé (deep-merge → préserve xp/pv/…). Dès lors le jeu l'ignore (exclu du partage
    // d'XP/butin, grisé sans crâne, ne peut pas mourir) et l'option disparaît de son menu ; il
    // repassera has_device=true tout seul à sa prochaine reconnexion (_writeClanPlayer). Sur son
    // propre appareil, sa vigilance verra le changement (pas de mort/burn, cf. _evaluateDeath).
    Future<void> declare_offline(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("has_device", false);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    deva_log("info", "[roster] declare_offline : $name ($id) déclaré hors ligne");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] declare_offline FAILED: $e");
                                }
    }

    // Action « Prendre la place d'un joueur » (admin) : le worker assume l'identité de JEU du membre
    // ciblé SANS se déconnecter (aucun impact sur le module cloud / l'auth). _userId bascule sur la
    // cible → toutes les lectures/écritures des collections de clan (roster, xp, pv, avatar, tâches,
    // tiroir, journal, vigilance) se routent sur elle, autorisées par le clanSecret partagé. Le doc
    // perso `users/` reste celui de l'admin (via _authUserId / _sessionDocId), jamais touché : on
    // reconstruit le contexte de clan depuis SA session (même clan, donc clanId/clanSecret connus).
    // PERSISTÉ (SharedPreferences, cf. les clés _kImp*) : un kill de l'application reprend
    // l'emprunt là où il était. C'était l'inverse jusqu'au 2026-09-09, et c'est le fond du
    // correctif — le mode « je te prête mon téléphone » s'évaporait à la première extinction,
    // rendant le compte de l'adulte sans rien demander. `event` = data du joueur cliqué.
    // Étape 1 sur 2 : les gardes, puis on demande à l'adulte de CHOISIR SON CODE. La bascule
    // d'identité n'a lieu qu'ensuite (_doTakePlace), pour une raison de fond — si l'adulte
    // renonce devant l'écran du code, il ne s'est rien passé. Prêter son compte et se donner le
    // moyen de le reprendre sont le même geste ; les séparer laisserait une fenêtre où le
    // téléphone est déjà passé en main d'enfant sans qu'aucun code n'existe.
    Future<void> take_place(dynamic caller, dynamic event) async {

                                final m        = (event is Map) ? event : const {};
                                final targetId = m["id"]?.toString()   ?? "";
                                final name     = m["name"]?.toString() ?? "";
                                // Gardes : cible valide, jamais soi-même, pas d'imbrication d'impersonation.
                                if (targetId.isEmpty || targetId == _userId || _impersonating) return;
                                try {
                                    final r0         = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final s0         = await _readSession(r0);
                                    final c0         = s0?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final k0         = s0?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (c0.isEmpty || k0.isEmpty) return;
                                    if (!await _ensureIsAdmin(c0, k0, r0)) return;
                                    _impPendingId   = targetId;
                                    _impPendingName = name;
                                    DvOrb.navigate_new("imp_pin_set");
                                } catch (e) {
                                    deva_log("error", "[roster] take_place (demande de code) FAILED: $e");
                                }
    }

    // Étape 2 sur 2 : la bascule elle-même, une fois le code posé. Corps d'origine de take_place,
    // inchangé — seule sa condition de déclenchement a bougé.
    Future<void> _doTakePlace(String targetId, String name) async {

                                if (targetId.isEmpty || _impersonating) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);   // doc de l'admin → contexte clan (même clan que la cible)
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;
                                    // Réservé aux admins (double garde : le clan_selector le filtre déjà).
                                    if (!await _ensureIsAdmin(clanId, clanSecret, region)) return;

                                    // Coupe les watchers de l'identité courante AVANT la bascule.
                                    _stopValidationPolling();
                                    _stopPlayerVigilance();
                                    _resetOpening();

                                    // Bascule d'identité de JEU (pas d'auth) : _authUserId (doc perso) reste
                                    // l'admin ; _userId devient la cible.
                                    _realUserName  = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    _impersonating = true;
                                    _userId = targetId;
                                    await Deva.instance.set("session.user.id",   targetId);
                                    await Deva.instance.set("session.user.name", name);   // @@@session.user.name@@@ → cible (journaux)
                                    await deva_set("worker.impersonating", "true");          // gate de la leçon dvtuto
                                    await deva_set("dvtuto.seen.impersonation_back", false); // rejoue la leçon à chaque prise de place

                                    // Purge des caches liés à l'identité (même repli que on_logout).
                                    _isAdmin = false; _adminCount = 0; _isAdminClanId = ""; _isAdminUserId = "";
                                    // Idem pour la majorité : _ensureIsAdult conserve sa valeur si la
                                    // relecture échoue. Sans remise à false, un admin adulte qui prend la
                                    // place d'un enfant laisserait _isAdult=true derrière lui, et une lecture
                                    // en échec ouvrirait la boutique sur le compte de l'enfant.
                                    _isAdult = false; _isAdultClanId = ""; _isAdultUserId = "";
                                    _adminMode = false;
                                    _gameDomains.clear();
                                    // État de jeu local (propre à la session/device) : repart neuf.
                                    await Deva.instance.set("session.active_task",  "");
                                    await Deva.instance.set("session.active_proof", "");
                                    await deva_set("worker.player_dead", false);

                                    // Amorce les lignes de base sur la CIBLE → pas de fausse animation au 1er tick.
                                    await _seedPlayerBaselines(clanId, clanSecret, region);

                                    // Recalcule le statut chef DE LA CIBLE + vocabulaire tiroir.
                                    await _ensureIsAdmin(clanId, clanSecret, region);
                                    _declareTiroirVocabulary();
                                    await _syncChiefUi();

                                    // Recharge les données de jeu du point de vue de la cible.
                                    await _setAmbiance(false);   // l'état de vie réel sera réévalué par la vigilance / on_dashboard_appear
                                    if (session != null) await _loadClanTasks(session, region);
                                    _startPlayerVigilance(clanId, clanSecret, region);   // garde keyée sur _userId → nouveau watch cible

                                    // Bandeau overlay « vous incarnez X » + bouton retour. On NE réenregistre
                                    // PAS le device (_writeClanPlayer) : cela volerait le token FCM / le nom /
                                    // l'avatar de la cible au profit de ce téléphone.
                                    await _applyImpersonation(true, name);

                                    // Persisté APRÈS que tout a réussi : un emprunt écrit sur disque alors
                                    // que la bascule a échoué en cours de route serait repris au démarrage
                                    // suivant sans que l'adulte l'ait jamais vu.
                                    await _impPersist(targetId, name);

                                    deva_log("info", "[roster] take_place → incarne $name ($targetId)");
                                    DvOrb.navigate_reset("dashboard");
                                } catch (e) {
                                    deva_log("error", "[roster] take_place FAILED: $e");
                                }
    }

    // Retour au compte d'origine depuis l'impersonation (bouton du bandeau overlay). Inverse de
    // take_place : _userId revient à _authUserId, on recharge l'UI du point de vue de l'admin.
    Future<void> restore_self(dynamic caller, dynamic event) async {

                                if (!_impersonating) return;
                                try {
                                    // L'emprunt est fini : plus rien à reprendre au démarrage, et le code
                                    // temporaire meurt avec lui — c'est ce qui dispense d'un parcours de
                                    // réinitialisation. Effacé AVANT la bascule : si la suite échoue, on
                                    // préfère un état propre sans emprunt qu'un code orphelin.
                                    await _impClear();
                                    _impLockTimer?.cancel();
                                    _impLockTimer = null;
                                    _stopValidationPolling();
                                    _stopPlayerVigilance();
                                    _resetOpening();

                                    _userId        = _authUserId;
                                    _impersonating = false;
                                    await Deva.instance.set("session.user.id",   _authUserId);
                                    await Deva.instance.set("session.user.name", _realUserName);
                                    await deva_set("worker.impersonating", "false");

                                    // Masque le bandeau AVANT de renaviguer → le dashboard neuf naît sans bandeau.
                                    await _applyImpersonation(false, "");

                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);   // à nouveau le doc de l'admin
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";

                                    _isAdmin = false; _adminCount = 0; _isAdminClanId = ""; _isAdminUserId = "";
                                    // Idem pour la majorité : _ensureIsAdult conserve sa valeur si la
                                    // relecture échoue. Sans remise à false, un admin adulte qui prend la
                                    // place d'un enfant laisserait _isAdult=true derrière lui, et une lecture
                                    // en échec ouvrirait la boutique sur le compte de l'enfant.
                                    _isAdult = false; _isAdultClanId = ""; _isAdultUserId = "";
                                    _adminMode = false;
                                    _gameDomains.clear();
                                    await Deva.instance.set("session.active_task",  "");
                                    await Deva.instance.set("session.active_proof", "");
                                    await deva_set("worker.player_dead", false);

                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        // Ré-amorce les lignes de base sur l'admin (elles portaient les valeurs
                                        // de la cible pendant l'impersonation) → pas de fausse animation au retour.
                                        await _seedPlayerBaselines(clanId, clanSecret, region);
                                        await _ensureIsAdmin(clanId, clanSecret, region);
                                        _declareTiroirVocabulary();
                                        await _syncChiefUi();
                                        await _setAmbiance(false);
                                        if (session != null) await _loadClanTasks(session, region);
                                        _startPlayerVigilance(clanId, clanSecret, region);
                                    }

                                    deva_log("info", "[roster] restore_self → retour au compte $_realUserName ($_authUserId)");
                                    DvOrb.navigate_reset("dashboard");
                                } catch (e) {
                                    deva_log("error", "[roster] restore_self FAILED: $e");
                                }
    }

    // Bandeau overlay d'impersonation (idiome maison commons/death_* : widgets layer:overlay révélés à
    // la volée, jamais une popup modale). Mute les templates de conf (→ les pages FUTURES, dont le
    // dashboard re-navigué, naissent avec/sans le bandeau) ET applique aux pages déjà en pile.
    // Cette fonction ne fait que l'AFFICHAGE : l'état de l'emprunt, lui, est persisté par
    // _impPersist et rejoué au démarrage par _impRestore, qui rappelle celle-ci. Ne pas rétablir
    // l'ancien « mémoire seule » ici — le bandeau doit être là au premier écran d'un démarrage
    // en emprunt, sinon l'enfant se retrouve sur le compte de l'adulte sans le savoir.
    Future<void> _applyImpersonation(bool on, String name) async {

                                try {
                                    // Widget UNIQUE : « Vous incarnez X — touchez pour revenir » (2 tokens traduits
                                    // + le nom injecté au milieu, comme death_gage compose plusieurs @@@T:@@@).
                                    final label = on
                                        ? "@@@T:impersonating_as@@@ $name — @@@T:impersonation_tap_return@@@"
                                        : "";
                                    await deva_set("registry.commons/impersonation_back.shape.visible", on);
                                    if (on) {
                                        await deva_set("registry.commons/impersonation_back.shape.label", label);
                                    }
                                    for (final p in DvPage.actives) {
                                        final backS = p.get_shape_by_id("commons/impersonation_back");
                                        if (on) {
                                            if (backS is DvLabel) backS.write(label);
                                            backS?.show();
                                        } else {
                                            backS?.hide();
                                        }
                                    }
                                } catch (e) {
                                    deva_log("error", "[impersonation] _applyImpersonation FAILED: $e");
                                }
    }

    // Pré-remplit les lignes de base de détection (xp/task/gold/is_admin) avec les valeurs ACTUELLES
    // du doc joueur courant (_userId), pour que le 1er _onPlayerDocChanged après une bascule d'identité
    // (impersonation ↔ retour) ne diffe pas contre l'identité précédente → aucune fausse animation
    // (level-up / cadeau XP / cadeau d'or / promotion chef). L'ownerId (firebaseUid) ne changeant PAS
    // en impersonation, ces clés per-owner resteraient sinon celles de l'admin. Amorçage explicite =
    // miroir de l'« amorçage silencieux » des checks (storedRaw==null).
    Future<void> _seedPlayerBaselines(String clanId, String clanSecret, String region) async {

                                try {
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return;
                                    final doc = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    final xp       = int.tryParse(doc.get("xp")?.toString()   ?? "0") ?? 0;
                                    final gold     = int.tryParse(doc.get("gold")?.toString() ?? "0") ?? 0;
                                    final lastTask = doc.get("last_task")?.toString() ?? "";
                                    final rawAdmin = doc.get("is_admin");
                                    final isAdmin  = rawAdmin == true || rawAdmin?.toString() == "true";
                                    await deva_set("worker.player_last_xp",       xp);
                                    await deva_set("worker.player_last_task",     lastTask);
                                    await deva_set("worker.player_last_gold",     gold);
                                    await deva_set("worker.player_last_is_admin", isAdmin ? "true" : "false");
                                    await Deva.instance.store();
                                } catch (e) {
                                    deva_log("error", "[impersonation] _seedPlayerBaselines FAILED: $e");
                                }
    }

    // Action « Promouvoir chef » (admin) : ajoute le joueur ciblé à la liste `admins` du doc clan
    // (deep-merge → on réécrit la liste augmentée) ET pose is_admin=true sur SON doc clans_players —
    // c'est cette dernière écriture qui réveille SA vigilance (animation "burn" + resync UI côté
    // promu, cf. _checkChiefPromotion). Journalise, invalide le cache admin du promoteur (le nombre
    // d'admins change → l'auto-validation solo bascule en validation croisée), informe le clan puis
    // rafraîchit le roster (le flag `admin` recalculé remplace l'option par « plus chef »). `event`
    // = data du joueur cliqué. Idempotent : re-promouvoir un chef ne fait rien.
    Future<void> promote_chief(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // GARDE D'ÂGE, avant toute écriture. Être chef ouvre les surfaces
                                    // commerciales (_storeCanBuy) : promouvoir un mineur "k", ou un
                                    // adolescent "t" dont la majorité est déclarée mais pas encore acquise,
                                    // lui montrerait la grille tarifaire, le mur de première cotisation et le
                                    // bandeau d'impayé. Le § 5.3 du dossier « intérêt supérieur de l'enfant »
                                    // et la politique Google Play Families l'interdisent l'un comme l'autre.
                                    // Le menu masque déjà l'option (worker_screen_clan) ; ici c'est la garde
                                    // qui compte — le menu est du confort, pas une autorisation.
                                    // Lecture sur clans_players, la même source que _ensureIsAdult, et repli
                                    // STRICT : legal_state absent ou illisible → refus. On n'inscrit personne
                                    // dans `admins` sans avoir lu "a".
                                    final target = await _cloud?.read("workers", "clans_players/$clanId/players",
                                        id, ownerId: clanSecret, region: region);
                                    final targetLegal = target?.get("legal_state")?.toString() ?? "";
                                    if (targetLegal != "a") {
                                        deva_log("warning", "[roster] promote_chief REFUSÉ : $name ($id) "
                                            "n'est pas légalement adulte (legal_state='$targetLegal')");
                                        return;
                                    }

                                    // Lecture de la liste des chefs actuels (source d'autorisation).
                                    final clanDoc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? [])
                                        .map((a) => a.toString()).where((a) => a.isNotEmpty).toList();
                                    if (admins.contains(id)) {
                                        deva_log("info", "[roster] promote_chief : $name ($id) est déjà chef");
                                        return;
                                    }

                                    // Écriture de la liste augmentée (deep-merge remplace la clé liste).
                                    final out = Dvidle({});
                                    out.set("admins", [...admins, id]);
                                    await _cloud?.write("workers", "clans", clanId, out,
                                        region: region, ownerId: clanSecret);

                                    // Miroir is_admin=true sur le doc du promu → réveille SA vigilance (animation
                                    // burn + resync). deep-merge : préserve xp/pv/… du joueur.
                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("is_admin", true);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    // Journal (schéma adminId déjà prévu) : userId = promu, adminId = promoteur.
                                    final adminName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "ChiefPromoted",
                                        userId: id, adminId: _userId,
                                        data: Dvidle({"playerId": id, "playerName": name,
                                                      "adminId": _userId, "adminName": adminName}));

                                    // Le nombre d'admins a changé → invalider le cache pour que _adminCount soit
                                    // relu (bascule solo→multi de l'auto-validation).
                                    _isAdminClanId = "";
                                    await _ensureIsAdmin(clanId, clanSecret, region);

                                    deva_log("info", "[roster] promote_chief : $name ($id) promu chef");

                                    // Informe les AUTRES membres du clan (le promu, lui, a l'animation burn).
                                    await _notifyChiefPromotion(clanId, clanSecret, region, id, name);

                                    // Rafraîchit les tuiles (recalcule le flag `admin` → « plus chef » sur ce joueur).
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] promote_chief FAILED: $e");
                                }
    }

    // Action « Plus chef » (admin) : retire le joueur ciblé de `admins` (source d'autorisation) ET
    // pose is_admin=false sur son doc clans_players (réveille SA vigilance → resync UI, pas d'anim).
    // Garde-fous : on ne peut PAS se rétrograder soi-même (déjà exclu côté menu, redoublé ici) ni
    // rétrograder le FONDATEUR (admin à vie). Journalise, invalide le cache admin, rafraîchit le
    // roster. Idempotent : rétrograder un non-chef ne fait rien.
    Future<void> nomore_chief(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty || id == _userId) return;       // jamais soi-même
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    final clanDoc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? [])
                                        .map((a) => a.toString()).where((a) => a.isNotEmpty).toList();
                                    // Fondateur = admin à vie (champ `founder`, repli legacy = admins[0]).
                                    final founder = clanDoc?.get("founder")?.toString().isNotEmpty == true
                                        ? clanDoc!.get("founder").toString()
                                        : (admins.isNotEmpty ? admins.first : "");
                                    if (id == founder) {
                                        deva_log("info", "[roster] nomore_chief refusé : $name ($id) est le fondateur");
                                        return;
                                    }
                                    if (!admins.contains(id)) {
                                        deva_log("info", "[roster] nomore_chief : $name ($id) n'est pas chef");
                                        return;
                                    }

                                    // Liste amputée + miroir is_admin=false sur le doc du rétrogradé.
                                    final out = Dvidle({});
                                    out.set("admins", admins.where((a) => a != id).toList());
                                    await _cloud?.write("workers", "clans", clanId, out,
                                        region: region, ownerId: clanSecret);

                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("is_admin", false);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    final adminName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "ChiefDemoted",
                                        userId: id, adminId: _userId,
                                        data: Dvidle({"playerId": id, "playerName": name,
                                                      "adminId": _userId, "adminName": adminName}));

                                    _isAdminClanId = "";
                                    await _ensureIsAdmin(clanId, clanSecret, region);

                                    deva_log("info", "[roster] nomore_chief : $name ($id) n'est plus chef");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] nomore_chief FAILED: $e");
                                }
    }

    // Action « Déclarer majeur » (admin tuteur). Réservée aux admins du CLAN D'ORIGINE du joueur
    // (clan_selector ne la propose que si clanId == original_clan de la cible). Pose legal_state="t"
    // (transition : ni enfant ni adulte) sur son doc clans_players. Le joueur ciblé, qui surveille son
    // propre doc (_playerVigilance), détecte le "t" et se voit imposer la CGU adulte ; à l'acceptation,
    // SON app bascule à "a" (users + clans_players). Tant qu'il est "t", il est traité comme "k".
    Future<void> promote_adult(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // AUCUN contrôle de plafond ici, et c'est le point de la grille à un
                                    // seul compteur. Déclarer majeur ne DÉPLACE plus de place : le
                                    // joueur en occupait une avant, il en occupe une après. La
                                    // promotion n'a donc plus rien à voir avec l'abonnement, et le
                                    // refus qui vivait ici — franchissable, au demeurant, en empilant
                                    // les états « t » — n'a plus d'objet.

                                    // Bascule en transition : deep-merge → préserve xp/pv/… du joueur.
                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("legal_state", "t");
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    deva_log("info", "[roster] promote_adult : $name ($id) passe en transition (legal_state=t)");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] promote_adult FAILED: $e");
                                }
    }

    // Bascule « hors concours » (admin), sur un joueur ADULTE — y compris soi-même, qui est le cas
    // nominal : c'est le parent qui abat le plus de travail qui choisit de ne plus peser.
    //
    // Ce que le drapeau fait, une fois posé : le joueur est retiré des AGRÉGATS du clan (maxCur des
    // barres de butin, _clanMinXp du coup de pouce), de l'AFFICHAGE comparatif de sa tuile (écu de
    // niveau, cœurs, barre, bourse — cf. `hide` dans _refreshRoster), de l'ÉCONOMIE du butin (ni
    // argent, ni objet, ni attaque de bisous, ni tribut) et de la MORT (_evaluateDeath).
    //
    // Ce qu'il ne fait PAS, et c'est délibéré : son XP continue d'être créditée normalement, donc le
    // clan et le coffre sont alimentés exactement comme avant — aucun découplage à écrire. Son écran
    // Personnage reste complet, ses montées de niveau se célèbrent, son travail reste au journal, il
    // est convoqué à la cérémonie d'ouverture comme tout le monde et son last_butin_xp s'y recale.
    // Il touche aussi les cadeaux de la fée : une surprise narrative n'est pas une récompense de
    // compétition. « Hors concours » ne veut pas dire « hors du clan ».
    //
    // GARDE D'ÂGE relue à frais avant d'écrire, repli STRICT (legal_state absent/illisible → refus),
    // sur le modèle de promote_chief : le drapeau retire quelqu'un du partage du butin, et un chef ne
    // doit pas pouvoir en priver un enfant. Le selector masque déjà l'option sur une tuile de mineur,
    // mais le menu est du confort, pas une autorisation.
    //
    // Réversible d'un tap, donc aucune confirmation — même doctrine que declare_offline et nudges_*.
    // Aucun _writeClanLog : un réglage n'est pas un événement de la mémoire familiale.
    Future<void> _setHorsConcours(dynamic event, bool value) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = (m["id"]?.toString() ?? "").isNotEmpty ? m["id"].toString() : _userId;
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    if (!await _ensureIsAdmin(clanId, clanSecret, region)) {
                                        deva_log("warning", "[roster] hors_concours REFUSÉ : non-chef");
                                        return;
                                    }

                                    final target = await _cloud?.read("workers", "clans_players/$clanId/players",
                                        id, ownerId: clanSecret, region: region);
                                    final targetLegal = target?.get("legal_state")?.toString() ?? "";
                                    if (targetLegal != "a") {
                                        deva_log("warning", "[roster] hors_concours REFUSÉ : $name ($id) "
                                            "n'est pas légalement adulte (legal_state='$targetLegal')");
                                        return;
                                    }

                                    final pflag = Dvidle({});
                                    pflag.set("id",            id);
                                    pflag.set("hors_concours", value);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    deva_log("info", "[roster] hors_concours=$value pour $name ($id)");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[roster] _setHorsConcours($value) FAILED: $e");
                                }
    }

    Future<void> hors_concours_on (dynamic caller, dynamic event) async { await _setHorsConcours(event, true);  }
    Future<void> hors_concours_off(dynamic caller, dynamic event) async { await _setHorsConcours(event, false); }

    // Action « A quitté le clan » (admin) : révocation d'un membre OU départ volontaire (cible = soi).
    // Pose enabled=false sur son doc clans_players (tombstone → ignoré partout : roster, XP/butin, coup
    // de pouce, notifs), le retire de `admins` s'il était chef (garde _adminCount juste), journalise.
    // Le FONDATEUR n'est jamais révocable (redoublé ici, admin à vie). Sur soi-même → éjection vers
    // l'écran de choix de clan ; sur autrui → refresh du roster (son appareil s'éjectera via sa vigilance).
    Future<void> revoke_player(dynamic caller, dynamic event) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // Chefs + fondateur (source d'autorisation). Le fondateur est admin à vie :
                                    // ni révocable ni « partant volontaire » (le menu le cache déjà).
                                    final clanDoc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? [])
                                        .map((a) => a.toString()).where((a) => a.isNotEmpty).toList();
                                    final founder = clanDoc?.get("founder")?.toString().isNotEmpty == true
                                        ? clanDoc!.get("founder").toString()
                                        : (admins.isNotEmpty ? admins.first : "");
                                    if (id == founder) {
                                        deva_log("info", "[roster] revoke_player refusé : $name ($id) est le fondateur");
                                        return;
                                    }

                                    // Tombstone : enabled=false en deep-merge → préserve xp/pv/… du joueur.
                                    final pflag = Dvidle({});
                                    pflag.set("id", id);
                                    pflag.set("enabled", false);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    // Chef révoqué : le retirer de `admins` pour que _adminCount (validation croisée)
                                    // reste juste, puis invalider le cache admin.
                                    if (admins.contains(id)) {
                                        final out = Dvidle({});
                                        out.set("admins", admins.where((a) => a != id).toList());
                                        await _cloud?.write("workers", "clans", clanId, out,
                                            region: region, ownerId: clanSecret);
                                        _isAdminClanId = "";
                                        await _ensureIsAdmin(clanId, clanSecret, region);
                                    }

                                    // Journal : userId = parti, adminId = acteur (= cible si départ volontaire).
                                    final adminName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "MemberRevoked",
                                        userId: id, adminId: _userId,
                                        data: Dvidle({"playerId": id, "playerName": name,
                                                      "adminId": _userId, "adminName": adminName}));

                                    deva_log("info", "[roster] revoke_player : $name ($id) a quitté le clan");

                                    if (id == _userId) {
                                        // Départ volontaire : retour immédiat à l'écran de choix de clan.
                                        await _leaveClanLocal(region);
                                    } else {
                                        // Révocation d'autrui : la tuile disparaît tout de suite (le membre
                                        // sera éjecté sur SON appareil par sa propre vigilance → _checkRevoked).
                                        await _refreshRoster(clanId, clanSecret, region);
                                    }
                                } catch (e) {
                                    deva_log("error", "[roster] revoke_player FAILED: $e");
                                }
    }

    // =========================================================================================
    // --- RETRAIT DU CONSENTEMENT PARENTAL (art. 7(3) RGPD)
    // =========================================================================================
    //
    // LE PROBLÈME QUE CECI RÉSOUT. Pour retirer son consentement concernant UN SEUL enfant, la
    // seule voie était de supprimer son propre compte — ce qui dissout le clan et détruit les
    // données de toute la famille. Donner le consentement est un geste ; le retirer en coûtait un
    // qui atteignait des tiers. L'article 7(3) du RGPD demande la symétrie.
    //
    // CE QUE LE RETRAIT SIGNIFIE. Cesser de traiter les données, PAS interdire à l'enfant
    // d'utiliser l'application. Le bloquer supposerait de conserver indéfiniment l'identifiant
    // d'un enfant dont on vient de demander l'effacement complet : la mesure censée le protéger
    // constituerait le seul fichier d'enfants que ce produit n'a pas. Elle serait de surcroît
    // inopérante, aucune identité n'étant vérifiée. La protection réelle est ailleurs, et elle
    // tient : un mineur ne peut ni créer de clan ni en chercher un, il n'entre que sur invitation
    // d'un adulte qui déclare en répondre. Un enfant seul ne revient pas.
    //
    // CHRONOLOGIE, telle que les 84 politiques de confidentialité adultes la publient au § 9 :
    //   immédiat      le joueur quitte le jeu, tuile grisée, porte close sur son appareil
    //   + 3 jours     un chef du clan d'origine peut revenir sur la décision (_kConsentGraceDays)
    //   à l'échéance  cascade de suppression sur cette seule cible + consentement clos et daté
    //   + 30 jours    conservation restreinte hors du service, puis effacement — PAS ENCORE LIVRÉ
    //                 (readme § 23 : « rien n'efface jamais rien », tâche « purges 30 j / 5 ans »)

    // Ouvre l'overlay de confirmation en mode RETRAIT. N'écrit rien : c'est on_consent_confirm
    // qui agit. Les gardes sont redoublées dans _openConsentOverlay — clan_selector n'est que du
    // confort d'affichage, et un geste de cette portée ne peut pas reposer sur un menu.
    Future<void> withdraw_consent(dynamic caller, dynamic event) async {

                                await _openConsentOverlay(event, "withdraw");
    }

    // Ouvre le même overlay en mode RÉTABLISSEMENT (retour arrière pendant le délai).
    Future<void> restore_consent(dynamic caller, dynamic event) async {

                                await _openConsentOverlay(event, "restore");
    }

    // Gardes communes aux deux gestes, puis ouverture de l'overlay. Le mode ne change ni les
    // droits ni les vérifications : celui qui peut retirer est exactement celui qui peut rétablir.
    Future<void> _openConsentOverlay(dynamic event, String mode) async {

                                final m    = (event is Map) ? event : const {};
                                final id   = m["id"]?.toString()   ?? "";
                                final name = m["name"]?.toString() ?? "";
                                if (id.isEmpty || id == _userId) return;
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    // Chef de CE clan. Même garde que promote_chief : le menu ne fait pas foi.
                                    if (!await _ensureIsAdmin(clanId, clanSecret, region)) {
                                        deva_log("info", "[consent] refusé : $_userId n'est pas chef de $clanId");
                                        return;
                                    }

                                    // Doc du joueur relu à frais : la charge utile de la tuile peut dater de
                                    // plusieurs minutes, et un état légal périmé ouvrirait le geste sur un
                                    // joueur devenu majeur entre-temps.
                                    final pdoc = await _cloud?.read("workers", "clans_players/$clanId/players", id,
                                        ownerId: clanSecret, region: region);
                                    if (pdoc == null) return;
                                    final plegal  = pdoc.get("legal_state")?.toString()   ?? "";
                                    final porigin = pdoc.get("original_clan")?.toString() ?? "";
                                    final pdue    = pdoc.get("consent_due")?.toString()   ?? "";

                                    // CLAN D'ORIGINE, et lui seul : c'est le seul clan dont le consentement est
                                    // en cause. Même règle que « déclarer majeur », et pour la même raison.
                                    if (porigin != clanId) {
                                        deva_log("info", "[consent] refusé : $clanId n'est pas le clan d'origine de $id ($porigin)");
                                        return;
                                    }
                                    // Un adulte donne son propre consentement : personne ne le retire pour lui.
                                    // "t" reste couvert — tant que la CGU adulte n'est pas acceptée, c'est encore
                                    // le consentement du tuteur qui porte le traitement.
                                    if (plegal == "a") {
                                        deva_log("info", "[consent] refusé : $id est majeur, il donne son propre consentement");
                                        return;
                                    }
                                    // Cohérence du geste avec l'état réel (deux chefs, deux appareils, une même
                                    // tuile ouverte des deux côtés). On ne discute pas : on rafraîchit.
                                    if (mode == "withdraw" && pdue.isNotEmpty) { await _refreshRoster(clanId, clanSecret, region); return; }
                                    if (mode == "restore"  && pdue.isEmpty)    { await _refreshRoster(clanId, clanSecret, region); return; }

                                    _consentTargetId   = id;
                                    _consentTargetName = name.isNotEmpty ? name : (pdoc.get("name")?.toString() ?? "");
                                    _consentMode       = mode;
                                    _setConsentVisible(true);
                                    await _applyConsentStep();
                                } catch (e) {
                                    deva_log("error", "[consent] ouverture overlay FAILED: $e");
                                }
    }

    // Bascule les 4 shapes de l'overlay (modèle _setDeleteVisible, personnage/delete_*).
    void _setConsentVisible(bool v) {

                                for (final id in const [
                                    "clan_page/consent_scrim",
                                    "clan_page/consent_panel",
                                    "clan_page/consent_yes",
                                    "clan_page/consent_no",
                                ]) {
                                    final s = DvOrb.get_shape_by_id(id);
                                    s?.set("shape.visible", v);
                                    s?.refreshUI();
                                }
    }

    // DvLabel ne peint que shape.display, recalculé par computeDisplay() : écrire shape.label
    // seul laisserait le texte figé sur celui du YAML (cf. _setDeleteLabel).
    Future<void> _setConsentLabel(String id, String key) async {

                                final s = DvOrb.get_shape_by_id(id);
                                if (s is! DvLabel) return;
                                s.set("shape.label",
                                    TranslationRegistry.translate(key).replaceAll("{name}", _consentTargetName));
                                await s.computeDisplay();
                                s.refreshUI();
    }

    // Écrit les trois libellés selon le mode. Un seul overlay, deux sens de lecture.
    Future<void> _applyConsentStep() async {

                                final withdraw = _consentMode == "withdraw";
                                await _setConsentLabel("clan_page/consent_panel",
                                    withdraw ? "consent_withdraw_warn"    : "consent_restore_warn");
                                await _setConsentLabel("clan_page/consent_yes",
                                    withdraw ? "consent_withdraw_confirm" : "consent_restore_confirm");
                                await _setConsentLabel("clan_page/consent_no",
                                    withdraw ? "consent_withdraw_cancel"  : "consent_restore_cancel");
                                for (final id in const ["clan_page/consent_yes", "clan_page/consent_no"]) {
                                    final s = DvOrb.get_shape_by_id(id);
                                    s?.set("shape.visible", true);
                                    s?.set("shape.events.tap", true);
                                    s?.refreshUI();
                                }
    }

    Future<void> on_consent_cancel(dynamic caller, dynamic event) async {

                                _consentTargetId   = "";
                                _consentTargetName = "";
                                _consentMode       = "";
                                _setConsentVisible(false);
    }

    Future<void> on_consent_confirm(dynamic caller, dynamic event) async {

                                final id   = _consentTargetId;
                                final name = _consentTargetName;
                                final mode = _consentMode;
                                if (id.isEmpty || mode.isEmpty) { await on_consent_cancel(null, null); return; }

                                // Anti double-tap : les deux boutons disparaissent, le panneau passe en attente.
                                for (final sid in const ["clan_page/consent_yes", "clan_page/consent_no"]) {
                                    final s = DvOrb.get_shape_by_id(sid);
                                    s?.set("shape.visible", false);
                                    s?.set("shape.events.tap", false);
                                    s?.refreshUI();
                                }
                                await _setConsentLabel("clan_page/consent_panel", "consent_working");

                                if (mode == "withdraw") {
                                    await _doWithdrawConsent(id, name);
                                } else {
                                    await _doRestoreConsent(id, name);
                                }
                                await on_consent_cancel(null, null);   // ferme et remet à zéro
    }

    // LE RETRAIT. Trois champs en deep-merge sur le doc membre, et rien d'autre : `enabled` reste
    // à true, délibérément. Le passer à false ici déclencherait _checkRevoked → _leaveClanLocal
    // sur l'appareil de l'enfant, qui efface son ancrage local au clan — le rétablissement
    // exigerait alors une ré-invitation par QR ou par PIN, et ce ne serait plus « revenir sur sa
    // décision ». La sortie du jeu est obtenue autrement, et complètement : tuile grisée et hors
    // de tous les agrégats (_refreshRoster), aucune option hormis « Rétablir » (clan_selector),
    // porte close sur l'appareil de l'enfant (_checkConsentClosed), et son propre client cesse
    // d'écrire sur le document (_writeClanPlayer).
    Future<void> _doWithdrawConsent(String id, String name) async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    final now = DateTime.now().toUtc();
                                    final due = now.add(const Duration(days: _kConsentGraceDays));

                                    final pflag = Dvidle({});
                                    pflag.set("id",          id);
                                    pflag.set("consent_at",  now.toIso8601String());
                                    pflag.set("consent_due", due.toIso8601String());
                                    pflag.set("consent_by",  _userId);
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    // Journal d'audit du clan. La preuve JURIDIQUE du retrait n'est pas ici :
                                    // c'est la clôture datée de la preuve d'acceptation, que la fonction cloud
                                    // posera à l'échéance (documents_acceptance.date_end).
                                    final adminName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "ConsentWithdrawn",
                                        userId: id, adminId: _userId,
                                        data: Dvidle({"playerId": id, "playerName": name,
                                                      "adminId": _userId, "adminName": adminName,
                                                      "due": due.toIso8601String()}));

                                    // Sans cette notification, la fenêtre de rétractation que la politique de
                                    // confidentialité promet aux AUTRES chefs serait purement théorique : ils ne
                                    // découvriraient le retrait qu'en ouvrant l'écran Clan, par hasard.
                                    await _notifyConsentWithdrawn(clanId, clanSecret, region, id, name);

                                    deva_log("info", "[consent] retrait posé sur $name ($id) — échéance ${due.toIso8601String()}");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[consent] _doWithdrawConsent FAILED: $e");
                                }
    }

    // LE RETOUR ARRIÈRE. Efface les trois champs — convention dvcloud : un champ s'efface en le
    // posant à "" (le write est un deep-merge par updateMask, une clef absente ne serait pas
    // touchée). L'enfant retrouve son personnage, ses niveaux et sa place, intacts : rien n'a été
    // supprimé, seulement suspendu. C'est ce qui rend la rétractation réelle plutôt qu'annoncée.
    Future<void> _doRestoreConsent(String id, String name) async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    final pflag = Dvidle({});
                                    pflag.set("id",          id);
                                    pflag.set("consent_at",  "");
                                    pflag.set("consent_due", "");
                                    pflag.set("consent_by",  "");
                                    await _cloud?.write("workers", "clans_players/$clanId/players", id, pflag,
                                        region: region, ownerId: clanSecret);

                                    final adminName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    await _writeClanLog(clanId, clanSecret, region, "ConsentRestored",
                                        userId: id, adminId: _userId,
                                        data: Dvidle({"playerId": id, "playerName": name,
                                                      "adminId": _userId, "adminName": adminName}));

                                    // Une cible balayée puis rétablie dans la même session doit pouvoir l'être
                                    // à nouveau : sans cet oubli, l'anti-rejeu la tiendrait pour déjà traitée.
                                    _consentSwept.remove(id);

                                    deva_log("info", "[consent] retrait annulé sur $name ($id)");
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[consent] _doRestoreConsent FAILED: $e");
                                }
    }

    // BALAYAGE DES ÉCHÉANCES, déclenché par le rafraîchissement du roster — donc par N'IMPORTE
    // QUEL membre du clan, chef ou non. Ce n'est pas un oubli de garde : la suppression est DUE,
    // et la faire dépendre du passage d'un chef la retarderait sans rien protéger.
    //
    // Le client ne supprime rien lui-même, et ne le pourrait pas : les règles Firestore réservent
    // l'écriture de `users` à son propriétaire (`request.auth.uid == resource.data.ownerId`) et
    // celle de `userindexes` au titulaire de l'index. Il RÉCLAME l'exécution à delete_user_data,
    // qui revérifie tout côté serveur — membre du clan, échéance réellement dépassée, clan
    // d'origine, minorité — puis déroule SA cascade, la même que pour une suppression de compte.
    // Aucune deuxième implémentation de la suppression n'existe donc côté client.
    //
    // ⚠ Contrepartie assumée du déclenchement client : si plus personne n'ouvre l'application, la
    // suppression attend. Le balayeur serveur de la tâche « purges 30 j / 5 ans » est l'endroit
    // naturel où reprendre ce filet.
    Future<void> _sweepExpiredConsent(String clanId, String clanSecret, String region,
                                      List<String> expired) async {

                                if (expired.isEmpty || clanId.isEmpty) return;
                                var claimed = false;
                                for (final id in expired) {
                                    if (_consentSwept.contains(id)) continue;
                                    _consentSwept.add(id);   // AVANT l'appel : un échec ne doit pas boucler
                                    claimed = true;
                                    try {
                                        final res = await _cloud?.call("delete_user_data",
                                            Dvidle({"consentTarget": id, "clanId": clanId}));
                                        deva_log("info", "[consent] échéance atteinte sur $id → suppression réclamée"
                                            " (ok=${res?.get('ok')} skipped=${res?.get('skipped')})");
                                    } catch (e) {
                                        deva_log("error", "[consent] suppression réclamée sur $id FAILED: $e");
                                    }
                                }
                                // La cascade a posé les pierres tombales : le roster doit les voir disparaître.
                                if (claimed && clanSecret.isNotEmpty) {
                                    await _refreshRoster(clanId, clanSecret, region);
                                }
    }

    // Détecte le retrait du consentement du joueur COURANT et ferme la porte. Pendant du couple
    // _checkRevoked / _checkAdultTransition, à une différence essentielle près : ON N'ÉJECTE PAS.
    // L'ancrage local au clan doit survivre intact pour que le retour arrière d'un chef soit
    // gratuit. Retourne true si la porte est close → l'appelant s'arrête là.
    //
    // Appelle _applyConsentClosed dans les DEUX sens : c'est aussi ce qui rouvre la porte, sans
    // que l'enfant ait le moindre geste à faire, quand un chef se ravise.
    // ensureScreen : appelé au DÉMARRAGE, où aucune page n'est encore montée. Les shapes de la
    // porte close vivent sur `page_taskbar` — les basculer sans amener l'enfant sur un écran qui
    // les porte le laisserait devant un écran vide. On navigue donc au dashboard, dont l'overlay
    // recouvre tout : la conf est mutée AVANT, si bien que la page naît déjà fermée.
    Future<bool> _checkConsentClosed({bool ensureScreen = false}) async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return false;
                                    final me = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region);
                                    final closed = (me?.get("consent_due")?.toString() ?? "").isNotEmpty;
                                    await _applyConsentClosed(closed);
                                    if (closed) {
                                        deva_log("info", "[consent] porte close pour $_userId (retrait en cours)");
                                        if (ensureScreen) DvOrb.navigate_reset("dashboard");
                                    }
                                    return closed;
                                } catch (e) {
                                    deva_log("warning", "[consent] _checkConsentClosed failed: $e");
                                }
                                return false;
    }

    // Bascule GLOBALE de la porte close (modèle _applyDeath) : mute les templates de conf → les
    // pages futures naissent fermées, persiste le layer runtime → la porte est close dès la
    // première frame au redémarrage, et applique aux pages DÉJÀ en pile (retours arrière).
    //
    // Bornée à h:100% et non 88% comme l'overlay de mort : c'est la seule surface du jeu qui
    // recouvre la taskbar, parce qu'elle est la seule à devoir tout fermer, navigation comprise.
    Future<void> _applyConsentClosed(bool closed) async {

                                try {
                                    final prev = (await deva_get("registry.commons/closed_scrim.shape.visible"))?.toString() == "true";
                                    // Cas de très loin le plus fréquent — porte déjà ouverte, et rien à fermer :
                                    // cette vérification passe à CHAQUE changement du doc joueur, pour tout le
                                    // monde. Sortir ici évite de parcourir la pile de pages pour rien.
                                    if (!closed && !prev) return;
                                    await deva_set("registry.commons/closed_scrim.shape.visible", closed);
                                    await deva_set("registry.commons/closed_msg.shape.visible",   closed);
                                    // Écriture disque sur CHANGEMENT seulement (cf. _applyDeath) : cette
                                    // vérification passe à chaque changement du doc joueur.
                                    if (prev != closed) await Deva.instance.store();

                                    for (final p in DvPage.actives) {
                                        final scrim = p.get_shape_by_id("commons/closed_scrim");
                                        final msg   = p.get_shape_by_id("commons/closed_msg");
                                        if (closed) { scrim?.show(); msg?.show(); }
                                        else        { scrim?.hide(); msg?.hide(); }
                                    }
                                } catch (e) {
                                    deva_log("error", "[consent] _applyConsentClosed FAILED: $e");
                                }
    }

    // Détecte la révocation du joueur COURANT : lit son doc membre et, si enabled=false, l'éjecte
    // (voir _leaveClanLocal). Retourne true si éjecté → l'appelant s'arrête là. Couvre la révocation
    // déclenchée depuis un AUTRE appareil (admin), remontée ici par la vigilance temps réel.
    Future<bool> _checkRevoked() async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return false;
                                    final me = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region);
                                    if (me?.get("enabled") == false) {
                                        deva_log("info", "[roster] joueur révoqué détecté → éjection vers decisiontree");
                                        await _leaveClanLocal(region);
                                        return true;
                                    }
                                } catch (e) {
                                    deva_log("warning", "[roster] _checkRevoked failed: $e");
                                }
                                return false;
    }

    // Détecte une bascule légale déclenchée par le tuteur : lit le doc membre du joueur COURANT ;
    // si legal_state == "t" (transition), impose la CGU ADULTE (bloquante) et retourne true → l'appelant
    // s'arrête là (ni dashboard ni autre animation). Le drapeau worker.pending_adult_transition permet à
    // on_acceptance_complete de committer "a" (users + clans_players) une fois la CGU acceptée. Idempotent
    // (navigate_reset) : sûr à rejouer à chaque tick de vigilance ou à chaque login tant qu'on est en "t".
    Future<bool> _checkAdultTransition() async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isEmpty || clanSecret.isEmpty || _userId.isEmpty) return false;
                                    final me = await _cloud?.read("workers", "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region);
                                    if ((me?.get("legal_state")?.toString() ?? "") != "t") return false;

                                    deva_log("info", "[legal] transition adulte détectée → CGU adulte imposée");
                                    await Deva.instance.set("worker.pending_adult_transition", "true");
                                    await Deva.instance.store();
                                    // Force la résolution + l'enregistrement de la CGU ADULTE (champ motor en mémoire),
                                    // SANS persister documents_sessions : un kill pendant la lecture repart proprement
                                    // (on re-détecte "t" au login et on ré-impose la CGU).
                                    await ActionRegistry.get("documents.set_session_legalstate")?.call(null, "a");
                                    await ActionRegistry.get("documents.show_acceptance")?.call(null, "cgu");
                                    return true;
                                } catch (e) {
                                    deva_log("warning", "[legal] _checkAdultTransition failed: $e");
                                }
                                return false;
    }

    // Retire localement le joueur COURANT de son clan : vide les pointeurs de clan sur son doc `users`
    // (deep-merge → champ vidé par "" ; le prédicat de login se base sur steps.clan.clanId non-vide),
    // coupe la vigilance et renvoie vers l'écran de choix de clan. Exécuté sur l'appareil du joueur
    // concerné : révocation à distance (_checkRevoked) OU départ volontaire (revoke_player sur soi).
    Future<void> _leaveClanLocal(String region) async {

                                try {
                                    final docId = _sessionDocId();
                                    if (region.isNotEmpty && docId.isNotEmpty) {
                                        final doc = Dvidle({});
                                        doc.set("steps.clan.clanId",     "");
                                        doc.set("steps.clan.clanSecret", "");
                                        doc.set("steps.clan.status",     "");
                                        doc.set("last_clan",             "");
                                        await _cloud?.write("workers", "users", docId, doc, region: region);
                                        _invalidateSessionCache();
                                    }
                                } catch (e) {
                                    deva_log("error", "[roster] _leaveClanLocal: users reset FAILED: $e");
                                }
                                _stopPlayerVigilance();
                                _resetOpening();
                                // Plus de clan → plus aucune tâche en validation, donc plus aucune preuve
                                // atteignable : on vide le répertoire au lieu d'effacer un uuid, parce que
                                // la révocation à distance peut avoir eu lieu app fermée et qu'on ne sait
                                // pas ce qui traîne. Vaut pour les deux appelants, _checkRevoked (éjection)
                                // et revoke_player sur soi (départ volontaire).
                                await _reconcileProofs("");
                                await Deva.instance.set("worker.session.clan_done", "");
                                DvOrb.navigate_reset("decisiontree");
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
