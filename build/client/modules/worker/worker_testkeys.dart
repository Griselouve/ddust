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

// RACCOURCIS CLAVIER DE TEST : Windows, build de test (snapshot) seulement.
//
// ⚠ LE CRITERE « BUILD DE TEST » EST `DV_STOREMOCK`, UNE CONSTANTE DE COMPILATION. Le builder ne
//   pose `--dart-define=DV_STOREMOCK=on` que sur un client SNAPSHOT (bld_storemock,
//   `_storemock_client` → `_essai_offert` : release_mode snapshot, jamais une release), y compris
//   pour `flutter build windows` (bld_windows) et `flutter run` (bld_lancement). C'est le verrou
//   le plus dur disponible : rien en conf ni sur disque ne peut le rallumer dans une app publiée,
//   et le compilateur y élague tout ce code mort. `autover.channel` ou
//   `documents.test_servers.enabled` disent la même chose, mais par la conf, donc plus
//   faiblement.
// ⚠ IL SUPPOSE QUE LA SUITE PORTE LE FAUX STORE (`pustoremock` dans le backend, cible `test`
//   déclarée) : c'est le cas de ddust. Sans lui, aucun snapshot n'aurait les raccourcis.
const bool _kTestKeysBuilt = String.fromEnvironment('DV_STOREMOCK') == 'on';

// Le handler n'est posé qu'une fois par processus, même si le worker est réinvoqué.
bool _tkInstalled = false;

// Rang du PROCHAIN interlude joué par « I » (en boucle sur la liste triée).
int _tkInterludeIdx = 0;

// « B » en cours (lecture, écriture, rafraîchissement) : un second appui ne fait rien.
bool _tkButinBusy = false;

// « M » en cours (lecture, écriture, évaluation de la mort) : un second appui ne fait rien.
bool _tkDeathBusy = false;

// Rang du PROCHAIN événement joué par « E » (en boucle : catalogue trié, puis la fée).
int _tkEventIdx = 0;

// « E » en cours : un second appui ne fait rien (l'attente d'une célébration peut durer).
bool _tkEventBusy = false;

// Nom réservé de la fée dans la liste de « E » : elle n'est pas au catalogue des événements.
const String _kTkFairy = "fée";

// Clefs qui ne sont PAS des interludes dans `interludes` : les drapeaux d'état que dvbeing pose
// sous le namespace du module (`invoked`, `appeared`) et celui du moteur (`playing`), plus la
// seule clef réservée de dvinterlude (`defaults`).
const Set<String> _kTkInterludeNotDefs = {"defaults", "invoked", "appeared", "playing"};

// Clefs de DÉFINITION réellement lues par DvInterludeMotor (play, finished, covered) : une vraie
// entrée d'interlude est une table qui en porte au moins une.
const Set<String> _kTkInterludeDefKeys = {
    "scene", "sound", "vibration", "splash", "lead", "guard", "freeze", "music",
    "on_covered", "on_finished",
};

// Seules actions de fin qu'un interlude rejoué à vide a le droit de tirer : la relâche des gardes
// de célébration, qui ne relâche que le garde de l'interlude NOMMÉ et ne trouve rien à relâcher
// ici. Tout autre `on_finished` (fin de l'accueil, du pacte, CGU adulte, bascule de clan) agit sur
// le parcours du joueur : l'interlude est alors sauté.
const Set<String> _kTkSafeFinished = {"worker.on_celebration_end"};

// -----------------------------------------------------------------------------
// --- worker extension — Raccourcis clavier de test
// -----------------------------------------------------------------------------
extension Worker_testkeys on worker {

    // Pose le handler clavier, au démarrage du worker. Ne fait RIEN hors d'un build de test,
    // hors de Windows, ou une seconde fois.
    void _installTestKeys() {

                                if (!_kTestKeysBuilt || kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
                                if (_tkInstalled) return;
                                _tkInstalled = true;
                                HardwareKeyboard.instance.addHandler(_tkOnKey);
                                deva_log("info", "[testkeys] raccourcis de test actifs (I = interlude suivant, B = butin plein, "
                                    "M = mort du joueur, E = événement suivant)");
    }

    // Touche enfoncée (jamais la répétition ni le relâchement), sans modificateur, et jamais
    // pendant une saisie. Renvoie true seulement si la touche a été consommée.
    bool _tkOnKey(KeyEvent event) {

                                if (event is! KeyDownEvent) return false;
                                final kb = HardwareKeyboard.instance;
                                if (kb.isControlPressed || kb.isAltPressed || kb.isMetaPressed || kb.isShiftPressed) return false;
                                if (_tkSaisieActive()) return false;
                                if (event.logicalKey == LogicalKeyboardKey.keyI) {
                                    unawaited(_tkNextInterlude());
                                    return true;
                                }
                                if (event.logicalKey == LogicalKeyboardKey.keyB) {
                                    unawaited(_tkFillButin());
                                    return true;
                                }
                                if (event.logicalKey == LogicalKeyboardKey.keyM) {
                                    unawaited(_tkKillPlayer());
                                    return true;
                                }
                                if (event.logicalKey == LogicalKeyboardKey.keyE) {
                                    unawaited(_tkNextEvent());
                                    return true;
                                }
                                return false;
    }

    // Le focus est-il dans un champ de saisie ? Le FocusNode d'un TextField est porté par un Focus
    // construit SOUS son EditableText : on regarde le widget lui-même puis ses ancêtres. Un
    // contexte illisible (élément démonté) compte comme une saisie : dans le doute, on n'agit pas.
    bool _tkSaisieActive() {

                                final ctx = FocusManager.instance.primaryFocus?.context;
                                if (ctx == null) return false;
                                try {
                                    if (ctx.widget is EditableText) return true;
                                    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
                                } catch (_) {
                                    return true;
                                }
    }

    // Lit une clef d'un nœud de conf, Dvidle (imbriqué) ou Map.
    dynamic _tkGet(dynamic node, String key) {

                                if (node is Dvidle) return node.get(key);
                                if (node is Map) return node[key];
                                return null;
    }

    // Les clefs d'un nœud de conf, Dvidle ou Map.
    List<String> _tkKeys(dynamic node) {

                                if (node is Dvidle) return node.keys;
                                if (node is Map) return node.keys.map((k) => k.toString()).toList();
                                return const [];
    }

    // --- « I » : interlude suivant -------------------------------------------------------

    // Les interludes REJOUABLES À VIDE, triés par nom. Ne sont retenues que les vraies définitions
    // (une table portant au moins une clef de _kTkInterludeDefKeys). Sont écartés :
    //   - `defaults` et les drapeaux d'état (`invoked`, `appeared`, `playing`), cf. _kTkInterludeNotDefs ;
    //   - `theme_transition_*` : ils tiennent leur scène jusqu'à un `dvinterlude.release` que
    //     seul dvtheme envoie, et leur bascule appartient à dvtheme ;
    //   - tout interlude à `on_covered` : c'est une NAVIGATION (passages de l'onboarding, pacte,
    //     CGU adulte, changement de clan), jouée hors de son écran elle casserait le parcours ;
    //   - tout interlude dont le `on_finished` tire autre chose que _kTkSafeFinished ;
    //   - la liste facultative `worker.test_keys.interludes_skip` de la conf.
    // Les gestes que certaines scènes tirent en cours de route (worker.butin_reveal,
    // worker.show_gameover, worker.hide_skull) sont gardés par le drapeau de leur célébration :
    // rejoués à vide, ils ne font rien (même idiome que l'ancien banc burn_page).
    Future<(List<String>, List<String>)> _tkInterludes() async {

                                final conf = await deva_get("interludes");
                                final skipRaw = await deva_get("worker.test_keys.interludes_skip");
                                final skip = <String>{
                                    if (skipRaw is List) ...skipRaw.map((e) => e.toString()),
                                    if (skipRaw is Dvidle) ...skipRaw.keys,
                                };
                                final ok = <String>[], ecartes = <String>[];
                                for (final id in _tkKeys(conf)) {
                                    if (_kTkInterludeNotDefs.contains(id)) continue;
                                    final entry = _tkGet(conf, id);
                                    // Un drapeau (booléen, texte) ou une table sans clef de définition
                                    // n'est pas un interlude : on ne le montre même pas dans les écartés.
                                    if (entry is! Dvidle && entry is! Map) continue;
                                    if (!_tkKeys(entry).any(_kTkInterludeDefKeys.contains)) continue;
                                    var garde = !id.startsWith("theme_transition_")
                                        && !skip.contains(id)
                                        && _tkGet(entry, "on_covered") == null;
                                    if (garde) {
                                        final fin = _tkGet(entry, "on_finished");
                                        for (final k in _tkKeys(fin)) {
                                            final action = _tkGet(_tkGet(fin, k), "action")?.toString() ?? "";
                                            if (action.isNotEmpty && !_kTkSafeFinished.contains(action)) garde = false;
                                        }
                                    }
                                    (garde ? ok : ecartes).add(id);
                                }
                                ok.sort();
                                ecartes.sort();
                                return (ok, ecartes);
    }

    // Joue l'interlude suivant, par l'action du jeu réel (`dvinterlude.play.<id>`). Un interlude à
    // `splash` reçoit son propre nom en texte : le libellé de la célébration dit ce qui se joue.
    Future<void> _tkNextInterlude() async {

                                try {
                                    final (liste, ecartes) = await _tkInterludes();
                                    if (_tkInterludeIdx == 0 && ecartes.isNotEmpty) {
                                        deva_log("info", "[testkeys] interludes écartés (navigation, fin métier) : ${ecartes.join(', ')}");
                                    }
                                    if (liste.isEmpty) {
                                        deva_log("warning", "[testkeys] aucun interlude rejouable dans la conf");
                                        _tkToast("Aucun interlude rejouable");
                                        return;
                                    }
                                    final rang = _tkInterludeIdx % liste.length;
                                    _tkInterludeIdx = rang + 1;
                                    final id   = liste[rang];
                                    final conf = _tkGet(await deva_get("interludes"), id);
                                    final splash = _tkGet(conf, "splash")?.toString() ?? "";
                                    deva_log("info", "[testkeys] interlude '$id' (${rang + 1}/${liste.length})");
                                    _tkToast("Interlude $id (${rang + 1}/${liste.length})");
                                    unawaited(Future.sync(() => ActionRegistry.get("dvinterlude.play.$id")
                                        ?.call(null, splash.isNotEmpty ? {"text": id} : null)));
                                    // `music: hold` (le butin) ne rend pas l'ambiance : en jeu, c'est le bouton
                                    // de l'écran de récompenses qui le fait. Rejoué à vide, personne ne le
                                    // ferait : on la rend nous-mêmes quand plus rien ne joue.
                                    if (_tkGet(conf, "music")?.toString() == "hold") unawaited(_tkResumeAmbiance());
                                } catch (e) {
                                    deva_log("error", "[testkeys] interlude FAILED: $e");
                                }
    }

    // Rend la musique de fond une fois l'écran libre (plafond au-delà du garde-fou de dvinterlude).
    Future<void> _tkResumeAmbiance() async {

                                await Future.delayed(const Duration(milliseconds: 500));
                                for (var i = 0; i < 300; i++) {
                                    if (await deva_get("interludes.playing", false) != true) break;
                                    await Future.delayed(const Duration(milliseconds: 200));
                                }
                                ActionRegistry.get("dvsound.ambiance.resume")?.call(null, null);
    }

    // --- « B » : butin du clan plein ------------------------------------------------------

    // Remplit la jauge du CYCLE COURANT au plafond, dans le doc du clan (Firestore de la région
    // de la session, EUT dans un snapshot sur serveurs d'essai). Le strict nécessaire : seul
    // `clans.butin_xp` (compteur cumulé) est avancé jusqu'à `last_butin_xp + _butinMaxXp`, par
    // _butinPlafonne comme tout crédit du jeu ; le compteur journalier n'est pas touché. Le coffre
    // doré de l'écran Clan s'allume alors comme en jeu (chefs seulement), et la cérémonie
    // (on_butin_open_tap) suit le chemin réel. Les parts viennent des contributions des joueurs
    // (xp − last_butin_xp) : sans tâche faite depuis la dernière ouverture, le butin s'ouvre vide.
    Future<void> _tkFillButin() async {

                                if (_tkButinBusy) return;
                                _tkButinBusy = true;
                                try {
                                    final ctx = await _butinCtx();
                                    if (ctx == null) {
                                        deva_log("warning", "[testkeys] butin : pas de clan dans la session");
                                        _tkToast("Butin : pas de clan");
                                        return;
                                    }
                                    final clanId     = ctx.get("clanId").toString();
                                    final clanSecret = ctx.get("clanSecret").toString();
                                    final region     = ctx.get("region").toString();
                                    final doc = await _cloud?.read(
                                        "workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    if (doc == null) {
                                        deva_log("warning", "[testkeys] butin : doc du clan $clanId illisible");
                                        _tkToast("Butin : clan illisible");
                                        return;
                                    }
                                    final avant = _butinCourant(doc);
                                    if (avant < _butinMaxXp) {
                                        // Le gain qui amène le cumul pile à base + plafond, même si la base
                                        // dépasse le cumul (cf. _butinCourant, borné à 0).
                                        final next = _butinPlafonne(doc, _butinBase(doc) + _butinMaxXp - _butinCumul(doc));
                                        final out = Dvidle({});                 // deep-merge : ce seul champ
                                        out.set("butin_xp", next);
                                        await _cloud?.write("workers", "clans", clanId, out,
                                            region: region, ownerId: clanSecret);
                                    }
                                    final chef = await _ensureIsAdmin(clanId, clanSecret, region);
                                    deva_log("info", "[testkeys] butin du clan $clanId : $avant → $_butinMaxXp/$_butinMaxXp"
                                        "${chef ? "" : " (ouverture réservée aux chefs)"}");
                                    _tkToast(chef ? "Butin plein ($_butinMaxXp/$_butinMaxXp)"
                                                  : "Butin plein : seul un chef peut l'ouvrir");
                                    // L'écran Clan affiché relit le doc : barre pleine, coffre doré et aura.
                                    final page = DvOrb.get_current_page();
                                    if (page?.dvid == "clan_page") await on_clan_appear(page, null);
                                } catch (e) {
                                    deva_log("error", "[testkeys] butin FAILED: $e");
                                } finally {
                                    _tkButinBusy = false;
                                }
    }

    // --- « M » : mort du joueur courant ---------------------------------------------------

    // Fait tomber les PV AFFICHÉS du joueur à 0 par le levier du jeu réel : `damage` (celui d'un
    // piège) porté au maximum de PV dans clans_players, en deep-merge. Puis la détection ordinaire
    // (_evaluateDeath, la même que la vigilance et l'écran Personnage) voit la transition vivant →
    // mort : statut "dead" et gage tirés et persistés, interlude « gameover », crâne et gage posés
    // sous le noir, ambiance de mort. On l'appelle nous-mêmes : la vigilance (jusqu'à 60 s entre
    // deux lectures) passera ensuite sans rien rejouer (session.player_dead déjà vrai).
    // Le retour à la vie suit les chemins du jeu : soin d'un chef, résurrection de l'admin solo,
    // ou tâche validée (qui remet `damage` à 0).
    Future<void> _tkKillPlayer() async {

                                if (_tkDeathBusy) return;
                                _tkDeathBusy = true;
                                try {
                                    final ctx = await _butinCtx();
                                    if (ctx == null || _userId.isEmpty) {
                                        deva_log("warning", "[testkeys] mort : pas de clan dans la session");
                                        _tkToast("Mort : pas de clan");
                                        return;
                                    }
                                    final clanId     = ctx.get("clanId").toString();
                                    final clanSecret = ctx.get("clanSecret").toString();
                                    final region     = ctx.get("region").toString();
                                    final coll       = "clans_players/$clanId/players";
                                    final doc = await _cloud?.read("workers", coll, _userId,
                                        ownerId: clanSecret, region: region);
                                    if (doc == null) {
                                        _tkToast("Mort : joueur illisible");
                                        return;
                                    }
                                    // Mêmes exceptions que _evaluateDeath : ces joueurs-là ne meurent pas.
                                    if (doc.get("has_device") == false || doc.get("hors_concours") == true) {
                                        _tkToast("Mort impossible : joueur hors appareil ou hors concours");
                                        return;
                                    }
                                    final pv      = int.tryParse(doc.get("pv")?.toString() ?? "$_playerPv") ?? _playerPv;
                                    final damage  = int.tryParse(doc.get("damage")?.toString() ?? "0") ?? 0;
                                    final pvShown = _computeDisplayedPv(pv, damage,
                                        doc.get("last_task")?.toString() ?? "", _readDecay(doc.get("decay")));
                                    if (pvShown <= 0) {
                                        _tkToast("Le joueur est déjà mort");
                                        return;
                                    }
                                    // Aucun état encore observé dans cette session : _evaluateDeath amorcerait
                                    // sans animer. On l'amorce d'abord sur l'état vivant, comme un écran l'aurait fait.
                                    if (!_deathSeeded) await _evaluateDeath();
                                    final out = Dvidle({});                 // deep-merge : ce seul champ
                                    out.set("id",     _userId);
                                    out.set("damage", pv);
                                    await _cloud?.write("workers", coll, _userId, out,
                                        region: region, ownerId: clanSecret);
                                    deva_log("info", "[testkeys] mort du joueur $_userId : $pvShown → 0 PV (damage=$pv)");
                                    _tkToast("Mort du joueur ($pvShown → 0 PV)");
                                    await _evaluateDeath();
                                } catch (e) {
                                    deva_log("error", "[testkeys] mort FAILED: $e");
                                } finally {
                                    _tkDeathBusy = false;
                                }
    }

    // --- « E » : événement suivant --------------------------------------------------------

    // Les événements du catalogue (`events.catalog`, triés par nom), puis la fée en dernier.
    Future<List<String>> _tkEvents() async {

                                // Copie : on ne trie jamais la liste de clefs du Dvidle lui-même.
                                final ids = List<String>.of(_tkKeys(await _evtCatalog()))..sort();
                                return [...ids, _kTkFairy];
    }

    // Déclenche l'événement suivant, en boucle. Un événement passe par le moteur (_evtForce : le
    // chemin du tirage, sans dé ni compteurs) ; la fée par son apparition réelle (_spawnFairy : doc
    // partagé du clan, tuile dans un tiroir de domaine, vigilance), sans le dé quotidien.
    Future<void> _tkNextEvent() async {

                                if (_tkEventBusy) return;
                                _tkEventBusy = true;
                                try {
                                    final liste = await _tkEvents();
                                    final rang = _tkEventIdx % liste.length;
                                    _tkEventIdx = rang + 1;
                                    final id  = liste[rang];
                                    final pos = "${rang + 1}/${liste.length}";
                                    deva_log("info", "[testkeys] événement '$id' ($pos)");
                                    if (id == _kTkFairy) {
                                        _tkToast("Fée ($pos)...");
                                        final ctx = await _butinCtx();
                                        if (ctx == null) {
                                            _tkToast("Fée : pas de clan");
                                            return;
                                        }
                                        final ok = await _spawnFairy(ctx.get("clanId").toString(),
                                            ctx.get("clanSecret").toString(), ctx.get("region").toString(),
                                            reason: "test");
                                        _tkToast(ok ? "Fée ($pos) : tiroir $_fairyDomain"
                                                    : "Fée ($pos) : aucune monstre-tâche libre");
                                        return;
                                    }
                                    _tkToast("Événement $id ($pos)");
                                    final refus = await _evtForce(id);
                                    if (refus != null) {
                                        deva_log("info", "[testkeys] événement '$id' non joué : $refus");
                                        _tkToast("Événement $id ($pos) : $refus");
                                    }
                                } catch (e) {
                                    deva_log("error", "[testkeys] événement FAILED: $e");
                                } finally {
                                    _tkEventBusy = false;
                                }
    }

    // --- Retour visible -----------------------------------------------------------------

    // Message bref en bas de l'écran (2,5 s), préfixé « [test] » : l'utilitaire commun du
    // worker (_messageBref, worker.dart), qui sert aussi aux annonces du jeu.
    void _tkToast(String msg) => _messageBref("[test] $msg");
}

// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
