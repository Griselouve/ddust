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
// --- worker extension — L'accueil et la mise en scène du tunnel
// -----------------------------------------------------------------------------
//
// Ce que faisait l'application jusqu'au 2026-09-12 : télécharger 16 Mo de vidéo, puis
// enchaîner huit écrans de formulaire. Les testeurs l'ont dit dans les mêmes termes —
// « ça pose trente mille questions et on ne sait pas où on nous emmène ».
//
// Cinq écrans sur huit sont juridiques : ils ne se suppriment pas. Ce qui se corrige,
// c'est ce qui les entoure. D'où deux choses ici, et rien d'autre :
//
//   1. LE GRAND INTERLUDE D'ACCUEIL. Quatre tableaux (la maison devient donjon, les
//      corvées deviennent des monstres, la famille devient un clan, le coffre attend),
//      joués AVANT tout réseau sur des images, une musique et une voix EMBARQUÉES dans
//      le paquet. Personne ne demande rien à personne pendant ces trente secondes.
//   2. LA MISE EN SCÈNE DE CHAQUE ÉTAPE. Une courte scène d'arrivée, un bandeau qui
//      nomme le chapitre, et une réplique du conteur qui dit POURQUOI on demande ça.
//      Le formulaire ne change pas ; ce qui change, c'est qu'on sait où l'on va.
//
// ⚠ RIEN ICI N'ÉCRIT, NE LIT LE RÉSEAU, NI NE CONDITIONNE QUOI QUE CE SOIT. C'est du
//   décor, et il doit le rester : un asset manquant se tait, une scène absente ne
//   bloque pas une étape. L'onboarding doit marcher exactement pareil sans ce fichier.
//
// -----------------------------------------------------------------------------
extension Worker_onboarding on worker {

    void _register_onboarding() {

                                //-- Le seuil et l'accueil ----------------------------------------------
                                ActionRegistry.register("worker.on_awake_appear",      on_awake_appear);

                                ActionRegistry.register("worker.on_lang_chosen",       on_lang_chosen);

                                ActionRegistry.register("worker.on_start_adventure",   on_start_adventure);

                                ActionRegistry.register("worker.on_intro_beat",        on_intro_beat);
                                ActionRegistry.register("worker.on_screen_voice",      on_screen_voice);
                                ActionRegistry.register("worker.on_dashboard_welcome",  on_dashboard_welcome);
                                ActionRegistry.register("worker.on_pacte_beat",        on_pacte_beat);
                                ActionRegistry.register("worker.on_pacte_flammes",     on_pacte_flammes);
                                ActionRegistry.register("worker.on_pacte_finished",    on_pacte_finished);
                                ActionRegistry.register("worker.on_acceptance_appear",  on_acceptance_appear);
                                ActionRegistry.register("worker.on_ambiance_relais",    on_ambiance_relais);

                                ActionRegistry.register("worker.on_intro_reveal",      on_intro_reveal);

                                ActionRegistry.register("worker.on_intro_finished",    on_intro_finished);

                                //-- Mise en scène des étapes -------------------------------------------
                                ActionRegistry.register("worker.on_onboarding_appear", on_onboarding_appear);
    }

    // -----------------------------------------------------------------------
    // --- La voix du conteur
    // -----------------------------------------------------------------------

    // Les huit langues embarquées, et un repli sur le français pour toute autre.
    // `br` (portugais du Brésil) a sa propre réplique : même voix que `pt`, texte brésilien.
    //
    // ⚠ LUE À L'EXÉCUTION, jamais figée dans `sound.preload`. Le sélecteur de langue vit
    //   sur `home`, juste sous les deux portes : quelqu'un peut très bien passer l'app en
    //   espagnol PUIS lancer l'aventure. Or dvsound ne lit son `preload` qu'une fois, à
    //   son `appear` — un chemin résolu là-bas aurait gelé la langue du démarrage.
    //
    // ⚠ REPLI, ET PAS SILENCE. Une langue sans voix embarquée entend le conteur en
    //   français. Cette liste doit suivre les `langs:` des voix de build_assets.yml
    //   (étape `intro`) : une langue ajoutée là mais pas ici resterait en français.
    String get _voiceLang {

                                final l = TranslationRegistry.currentLang;
                                return const ["fr", "en", "es", "de", "it", "pt", "br", "nl"].contains(l) ? l : "fr";
    }

    // Charge une réplique sous un surnom dvsound. Rend false si l'asset n'existe pas :
    // l'appelant se tait alors, il n'échoue pas.
    Future<bool> _loadVoice(String nickname, String id) async {

                                final snd = ModuleRegistry.create("dvsound");
                                if (snd == null) return false;
                                try {
                                    final ok = await (snd as dynamic)
                                        .load(nickname, "intro/voices/${id}_$_voiceLang.mp3");
                                    return ok == true;
                                } catch (e) {
                                    deva_log("warning", "[intro] voix '$id' ($_voiceLang) : $e");
                                    return false;
                                }
    }

    // Traduction dans la langue courante, repli français. Même helper que la bienvenue
    // de clan (worker_celebrations) — il tient en trois lignes et n'a pas de maison.
    Future<String> _introTr(String key) async {

                                final lang = TranslationRegistry.currentLang;
                                for (final l in [lang, "fr", "en"]) {
                                    final v = (await deva_get(
                                        "lang.translations.$key.$l"))?.toString() ?? "";
                                    if (v.isNotEmpty) return v;
                                }
                                // Second chemin : la table peut arriver en bloc plutot qu'a plat.
                                final bloc = await deva_get("lang.translations.$key");
                                if (bloc is Dvidle) {
                                    for (final l in [lang, "fr", "en"]) {
                                        final v = bloc.get(l)?.toString() ?? "";
                                        if (v.isNotEmpty) return v;
                                    }
                                }
                                return "";
    }

    // -----------------------------------------------------------------------
    // --- Le seuil : la phrase qui défile
    // -----------------------------------------------------------------------

    // Sept langues, l'une après l'autre, en fondu, tant que personne n'a touché l'écran.
    //
    // ⚠ ON NE TRADUIT PAS, ON DÉFILE. À l'instant où cet écran paraît, l'application ne
    //   sait pas à qui elle parle : ni royaume, ni compte, et la langue du système n'est
    //   qu'une présomption — sur une tablette familiale partagée, c'est souvent celle de
    //   quelqu'un d'autre. Plutôt que de parier, on montre la phrase dans chaque langue
    //   tour à tour, comme le font les téléphones au premier démarrage. Celui qui
    //   reconnaît la sienne sait qu'il est au bon endroit.
    //
    // ⚠ LA BOUCLE S'ARRÊTE D'ELLE-MÊME, et sur deux conditions plutôt qu'une : on a
    //   quitté l'écran, ou l'interlude a commencé. La seconde compte autant que la
    //   première — la scène se joue SUR cet écran, et une phrase qui continuerait de
    //   clignoter par-dessus les tableaux ruinerait exactement ce qu'ils installent.
    // ⚠ APPELEE PAR LE WORKER LUI-MEME (invoke), PAS PAR UN `appear` DE PAGE. Les
    //   actions d'une shape sont RESOLUES A SA CONSTRUCTION — DvShape garde la
    //   fonction, pas le nom. Or `awake` est la toute premiere page de l'orb : elle
    //   est bâtie avant que le worker n'ait fini de s'enregistrer, et son `appear`
    //   pointait donc sur une action qui n'existait pas encore. Rien ne levait, rien
    //   ne se journalisait, et l'écran restait noir. C'est exactement le piège que
    //   dvcloud documente pour ses actions d'authentification.
    //
    //   Le worker attend donc la shape lui-même, aussi longtemps qu'il le faut :
    //   quelqu'un peut rester devant ce seuil une minute avant de toucher l'écran.
    // ⚠ `dynamic caller` ET NON `DvShape?` : l'`appear` d'une PAGE passe la page
    //   elle-même, et une page est un DvView, pas un DvShape. Typer le paramètre
    //   `DvShape?` faisait lever un `type 'DvPage' is not a subtype of 'DvShape?'` que
    //   DvView attrape et journalise — l'écran naissait donc inerte, en silence.
    Future<void> on_awake_appear(dynamic caller, dynamic event) async {

                                if (_awakeCycling) return;   // un `appear` de retour, pas un premier
                                _awakeCycling = true;

                                final phrase = await DvOrb.wait_for_shape("awake/question",
                                                                          timeoutMs: 60000);
                                if (phrase == null) {
                                    // Lancé pour TOUT démarrage (worker.invoke), y compris celui d'un
                                    // joueur enrôlé que on_login emmène aussitôt ailleurs : ne pas
                                    // trouver la phrase n'est une anomalie que si l'on est resté au seuil.
                                    if (DvOrb.get_current_page()?.dvid == "awake") {
                                        deva_log("warning", "[seuil] awake/question jamais montée");
                                    }
                                    _awakeCycling = false;
                                    return;
                                }

                                // ⚠ UNE LISTE DE CONF N'ARRIVE PAS TOUJOURS COMME UNE `List` DART.
                                //   Selon le chemin de fusion elle peut rendre un Dvidle, une Map
                                //   indexee par rang, ou une chaine. Le seul test `is List` retombait
                                //   donc en silence sur le repli a deux langues — d'ou un ecran qui
                                //   alternait entre l'anglais et rien du tout.
                                // La musique, des la premiere seconde. Embarquee, donc disponible
                                // sans reseau ni royaume — c'est le seul son que le joueur entend
                                // avant d'avoir choisi quoi que ce soit.
                                unawaited(_musiqueDuSeuil());

                                final langues = _listeDeConf(await deva_get("awake.cycle"),
                                                             const ["en", "fr"]);
                                deva_log("info", "[seuil] cycle : ${langues.join(", ")}");

                                var i = 0;
                                while (!_introPlaying && DvOrb.get_current_page()?.dvid == "awake") {
                                    // ⚠ LA SHAPE SE RELIT A CHAQUE TOUR, et surtout pas une fois pour
                                    //   toutes. `awake` peut être reconstruite sous la boucle — un
                                    //   `navigate_reset` vers la page courante suffit — et l'ancienne
                                    //   shape est alors détruite sans que la boucle s'en aperçoive :
                                    //   elle continue d'écrire dans un objet que plus rien ne peint.
                                    //   C'est ce qui transformait le seuil en écran noir muet.
                                    final vivante = DvOrb.get_shape_by_id("awake/question") ?? phrase;
                                    final lang  = langues[i % langues.length];
                                    final texte = await _phraseDuSeuil(lang);
                                    if (texte.isNotEmpty) {
                                        await _fondu(vivante, texte);
                                    } else if (i < langues.length) {
                                        // Une fois par langue, au premier tour : une traduction
                                        // absente est une erreur de conf, pas un incident, et se
                                        // taire dessus revient a la cacher.
                                        deva_log("warning",
                                            "[seuil] aucune phrase pour '$lang' — langue sautee");
                                    }
                                    i++;
                                }
                                _awakeCycling = false;
    }

    // La musique du seuil, en boucle. Elle tourne jusqu'à ce que la playlist du donjon
    // prenne le relais, à la sortie de l'écran de l'âge.
    //
    // ⚠ CHARGEE PAR SON CHEMIN, ET SURTOUT PAS PAR `sound.preload` DU THEME. C'est le
    //   seul son du jeu qui doive être jouable AVANT que le thème ne soit à jour, et le
    //   catalogue des surnoms vit justement DANS le thème. Or le thème du cache écrase
    //   celui du paquet dès qu'il existe, et il ne se rafraîchit qu'en cours de route :
    //   au premier lancement suivant un build, dvsound cherchait un surnom que son
    //   catalogue ne connaissait pas encore — « Son inconnu: seuil_music ». Deux
    //   lancements plus tard cela marchait, ce qui est la pire façon de marcher.
    //
    //   `load()` ne consulte aucun catalogue : il passe par dvassets, qui résout un
    //   chemin nu dans le PAQUET aussi bien que dans le cache. C'est exactement ce que
    //   font déjà les répliques du conteur, et pour la même raison.
    //
    // ⚠ RIEN N'EST TELECHARGE ICI, malgré les apparences. Le fichier est embarqué
    //   (`build_assets.yml`, étape `pacte`, `dir: resources`) : il est sur l'appareil
    //   avant même que l'application ne s'ouvre, et aucune vague d'assets n'a à
    //   intervenir.
    //
    // ⚠ NI GARDE NI ATTENTE : si le fichier manque, le seuil se joue en silence et rien
    //   d'autre ne change. Une musique d'ambiance ne doit jamais retarder un écran —
    //   surtout pas le premier, dont tout l'intérêt est de paraître à la première frame.
    Future<void> _musiqueDuSeuil() async {

                                if (_seuilMusique) return;
                                _seuilMusique = true;

                                // Une lecture qui traine encore (retour au seuil apres une
                                // deconnexion) est coupee avant d'en lancer une autre : deux
                                // boucles sur le meme surnom se superposeraient, decalees.
                                ActionRegistry.get("dvsound.stop.seuil_music")?.call(null, null);

                                final snd = ModuleRegistry.create("dvsound");
                                if (snd == null) {
                                    deva_log("warning", "[seuil] dvsound absent : pas de musique");
                                    return;
                                }
                                bool ok = false;
                                try {
                                    ok = await (snd as dynamic)
                                        .load("seuil_music", "intro/sounds/seuil.mp3") == true;
                                } catch (e) {
                                    deva_log("warning", "[seuil] musique illisible : $e");
                                    return;
                                }
                                if (!ok) {
                                    deva_log("warning",
                                        "[seuil] 'intro/sounds/seuil.mp3' introuvable — seuil silencieux");
                                    return;
                                }
                                // ⚠ A 45 %, ET LE NIVEAU SE POSE AVANT LA BOUCLE. A plein volume la
                                //   musique couvrait la narration : les répliques du conteur sont
                                //   rendues par ElevenLabs à un niveau de parole normal, quand une
                                //   nappe d'ambiance occupe tout le spectre en continu. Deux sources
                                //   à 1.0 ne se partagent pas l'écoute, la plus dense gagne.
                                //
                                //   On baisse la MUSIQUE plutôt que de monter les voix : celles-ci
                                //   sont déjà au maximum de ce qu'un mp3 rend sans saturer, et un
                                //   gain logiciel au-delà de 1.0 écrête. C'est aussi le seul son du
                                //   jeu concerné — le reste du contenu sonore garde son équilibre.
                                await ActionRegistry.get("dvsound.volume.seuil_music.30")
                                    ?.call(null, null);
                                await ActionRegistry.get("dvsound.loop.seuil_music")?.call(null, null);
                                deva_log("info", "[seuil] musique lancée (30 %)");
    }

    // Le relais : la playlist du donjon remplace la musique du seuil.
    //
    // Tire a la sortie de l'ecran de l'age (steps.age_screen.actions.routed), c'est-a-dire
    // au moment ou l'on entre dans la partie juridique du tunnel. La bascule se fait en
    // FONDU et non d'un coup : deux musiques qui se succedent sechement s'entendent comme
    // une erreur, alors que personne ne remarque un fondu d'une seconde.
    //
    // ⚠ LA PLAYLIST N'EST DISPONIBLE QU'ICI, et c'est ce qui commande le moment. Elle vit
    //   dans le bucket et descend avec la vague `critical` — donc apres le choix du
    //   royaume. La demander plus tot ne jouerait rien du tout.
    Future<void> on_ambiance_relais(dynamic caller, dynamic event) async {

                                // ⚠ ON LANCE LA SUITE AVANT DE COUPER, ET JAMAIS L'INVERSE. La
                                //   playlist du donjon vit dans le bucket : au premier parcours,
                                //   elle n'est pas toujours descendue quand on arrive ici. On
                                //   coupait alors la musique du seuil pour lancer une playlist qui
                                //   ne jouait rien, et le tunnel finissait en silence a partir des
                                //   conditions.
                                //
                                // ⚠ LE GARDE D'IDEMPOTENCE NE PORTE PAS SUR LE LANCEMENT, ET C'EST
                                //   TOUT L'ENJEU. Ce relais est tire par le pas de l'age ET par
                                //   celui de l'enigme : il ne doit pas rallumer deux fois la
                                //   musique du SEUIL. Le 2026-09-14, ce garde etait pose en tete
                                //   de methode sous la forme `if (!_seuilMusique) return;` : un
                                //   joueur qui n'etait pas passe par le seuil, donc sans musique a
                                //   couper, sortait AVANT d'avoir lance la playlist du donjon. La
                                //   musique ne demarrait plus jamais.
                                //
                                //   La playlist se lance donc toujours ; c'est l'extinction du
                                //   seuil, plus bas, qui est conditionnelle. Relancer une playlist
                                //   deja en cours est sans effet : `_playlistLoop` reprend l'etat
                                //   existant au lieu d'en creer un second.
                                final suite = ActionRegistry.get("dvsound.loop.ambiant");
                                if (suite == null) {
                                    deva_log("warning",
                                        "[ambiance] playlist du donjon indisponible — on garde le seuil");
                                    return;
                                }
                                await suite(null, null);

                                // ⚠ ON VERIFIE QUE LA SUITE JOUE VRAIMENT. `dvsound.loop.ambiant`
                                //   est une action a prefixe : elle existe toujours, et rendre la
                                //   main ne prouve rien. La playlist du donjon vit dans le bucket
                                //   et peut n'etre pas encore descendue — on coupait alors le
                                //   seuil pour du silence, a partir de l'ecran des conditions.
                                //
                                //   `sound.playing.<surnom>` est publie par dvsound : c'est le
                                //   seul temoin fiable. On laisse un instant a la lecture pour
                                //   s'etablir avant de regarder.
                                await Future.delayed(const Duration(milliseconds: 400));
                                if ((await deva_get("sound.playing.ambiant")) != true) {
                                    deva_log("warning",
                                        "[ambiance] la playlist ne joue pas — on garde le seuil");
                                    return;
                                }
                                // Rien a eteindre si le seuil n'a jamais chante : c'est le cas
                                // d'un joueur qui reprend sa session, et du second passage de ce
                                // relais.
                                if (!_seuilMusique) {
                                    deva_log("info", "[ambiance] playlist du donjon lancee");
                                    return;
                                }
                                _seuilMusique = false;

                                // Fondu plutot que coupure : deux musiques qui se succedent
                                // sechement s'entendent comme une erreur, un fondu d'une seconde
                                // ne se remarque pas.
                                final fondu = ActionRegistry.get("dvsound.fadeout.seuil_music");
                                if (fondu != null) {
                                    unawaited(fondu(null, null));
                                } else {
                                    ActionRegistry.get("dvsound.stop.seuil_music")?.call(null, null);
                                }
                                deva_log("info", "[ambiance] relais : seuil vers playlist du donjon");
    }

    // Une liste declaree en conf, quelle que soit la forme sous laquelle elle arrive.
    //
    // ⚠ NE PAS SE FIER A `is List`. Une sequence YAML traverse la fusion de conf sous
    //   plusieurs formes selon d'ou elle vient — List, Dvidle indexe par rang, ou meme
    //   une chaine quand elle n'a qu'un element. N'en tester qu'une, c'est retomber sur
    //   le repli sans jamais savoir pourquoi.
    List<String> _listeDeConf(dynamic brut, List<String> repli) {

                                Iterable<dynamic>? valeurs;
                                if (brut is List) {
                                    valeurs = brut;
                                } else if (brut is Dvidle) {
                                    valeurs = brut.keys.map((k) => brut.get(k));
                                } else if (brut is Map) {
                                    valeurs = brut.values;
                                } else if (brut is String && brut.trim().isNotEmpty) {
                                    valeurs = [brut];
                                }
                                final out = (valeurs ?? const [])
                                    .map((v) => v.toString().trim())
                                    .where((v) => v.isNotEmpty)
                                    .toList();
                                return out.isEmpty ? repli : out;
    }

    // La phrase du seuil dans une langue donnee. Deux chemins de lecture, parce que la
    // table des traductions peut etre rangee a plat ou en bloc selon qu'elle vient de la
    // conf compilee ou d'un layer — et qu'on ne saura pas laquelle a gagne la fusion.
    Future<String> _phraseDuSeuil(String lang) async {

                                final v = (await deva_get(
                                    "lang.translations.awake_question.$lang"))?.toString() ?? "";
                                if (v.isNotEmpty) return v;
                                final bloc = await deva_get("lang.translations.awake_question");
                                if (bloc is Dvidle) return bloc.get(lang)?.toString() ?? "";
                                if (bloc is Map) return bloc[lang]?.toString() ?? "";
                                return "";
    }

    // Intervalle entre deux repeints d'un fondu : 25 ms, soit 40 images par seconde.
    // Assez pour que l'œil ne distingue plus les paliers, et bien assez peu pour qu'un
    // fondu d'une seconde ne coûte que quarante `refreshUI` — on ne cherche pas le
    // soixante par seconde d'une animation de jeu, seulement la continuité.
    static const int _pasFonduMs = 25;

    // Un texte qui paraît, tient, puis s'efface. Fondu refait à la main, sans widget
    // particulier : on repeint à CADENCE FIXE, et c'est le nombre de pas qui se déduit
    // de la durée — l'inverse de ce qu'on avait d'abord écrit.
    //
    // ⚠ SIX PAS QUELLE QUE SOIT LA DURÉE : C'ÉTAIT LA CAUSE DU SACCADÉ. Un fondu d'une
    //   seconde s'y jouait en six sauts d'opacité de 180 ms — à cette cadence, l'œil ne
    //   voit pas un fondu mais une suite de paliers, et rallonger la durée ne faisait
    //   qu'espacer les sauts, donc empirer les choses. Avec un pas de `_pasFonduMs`, une
    //   durée plus longue donne plus d'images, ce qui est le comportement attendu.
    //
    // ⚠ CHAQUE PAS VÉRIFIE QU'ON EST TOUJOURS LÀ. Sans cela, un tap au milieu d'un
    //   fondu laisserait la boucle finir sa phrase par-dessus l'interlude qui démarre.
    Future<void> _fondu(DvShape shape, String texte) async {

                                // Reglables depuis la shape : le rythme d'un ecran se decide en
                                // conf, pas dans le worker. `fadein`/`fadeout` donnent la duree
                                // TOTALE d'un fondu, decoupee en six pas.
                                int ms(String clef, int repli) =>
                                    int.tryParse(shape.get("shape.$clef")?.toString() ?? "") ?? repli;
                                final msEntree = ms("fadein", 650);
                                final msSortie = ms("fadeout", 650);
                                final tenue    = Duration(milliseconds: ms("duration", 1200));
                                // Au moins deux pas, pour qu'une durée très courte reste un
                                // fondu et non une apparition sèche.
                                // `.toInt()` : `clamp` est declare sur num et rend donc un num,
                                // ce qui ferait de la variable de boucle un num — legal, mais on
                                // compte des pas, pas des grandeurs.
                                final pasIn  = (msEntree ~/ _pasFonduMs).clamp(2, 200).toInt();
                                final pasOut = (msSortie ~/ _pasFonduMs).clamp(2, 200).toInt();
                                final entree = Duration(milliseconds: msEntree ~/ pasIn);
                                final sortie = Duration(milliseconds: msSortie ~/ pasOut);

                                // ⚠ `computeDisplay()` APRES avoir pose le label, et pas seulement
                                //   `refreshUI()` : `shape.display` n'est calcule qu'a l'invoke, et un
                                //   libelle change a l'execution resterait affiche avec l'ancienne
                                //   valeur. C'est exactement ce que fait DvSplash.splash().
                                //
                                // ⚠ APPEL DYNAMIQUE : la methode vit sur DvLabel, pas sur DvShape —
                                //   or `wait_for_shape` ne promet qu'une DvShape. Plutot que de
                                //   contraindre le type (et d'interdire au passage qu'on remplace un
                                //   jour cette shape par autre chose), on demande poliment : une
                                //   shape qui ne sait pas recalculer son affichage se contentera du
                                //   refreshUI ci-dessous.
                                shape.set("shape.label", texte);
                                try {
                                    await (shape as dynamic).computeDisplay();
                                } catch (_) {}
                                shape..set("shape.opacity", 0.0)..refreshUI();
                                for (var k = 1; k <= pasIn; k++) {
                                    if (!_toujoursAuSeuil()) return;
                                    shape..set("shape.opacity", k / pasIn)..refreshUI();
                                    await Future.delayed(entree);
                                }
                                await Future.delayed(tenue);
                                for (var k = pasOut - 1; k >= 0; k--) {
                                    if (!_toujoursAuSeuil()) return;
                                    shape..set("shape.opacity", k / pasOut)..refreshUI();
                                    await Future.delayed(sortie);
                                }
    }

    bool _toujoursAuSeuil() =>
        !_introPlaying && DvOrb.get_current_page()?.dvid == "awake";

    // -----------------------------------------------------------------------
    // --- Le choix de la langue
    // -----------------------------------------------------------------------

    // Une tuile a été touchée : on adopte la langue, puis l'accueil commence.
    //
    // ⚠ LE CHOIX PRÉCÈDE L'INTERLUDE, ET C'EST TOUT SON INTÉRÊT. Celui-ci parle —
    //   quatre répliques de conteur — et il faut bien savoir dans quelle langue les
    //   dire. Tant que la langue se choisissait plus loin, on jouait l'accueil en
    //   français à tout le monde : pour un accueil, c'est se tromper de personne dès
    //   la première seconde.
    //
    // ⚠ LA LANGUE EST POSÉE AVANT TOUT LE RESTE, et attendue : `on_start_adventure`
    //   charge les voix juste après, et `_voiceLang` lit la langue courante. Les deux
    //   dans le désordre, et le conteur parlerait celle d'avant.
    Future<void> on_lang_chosen(DvShape? caller, dynamic event) async {

                                final code = (event?.toString() ?? "").trim();
                                if (code.isEmpty) return;
                                await ActionRegistry.get("lang.set.$code")?.call(caller, null);
                                deva_log("info", "[seuil] langue choisie : $code");
                                await on_start_adventure(caller, null);
    }

    // -----------------------------------------------------------------------
    // --- Le grand interlude d'accueil
    // -----------------------------------------------------------------------

    // La langue est choisie : on lève le rideau, et RIEN D'AUTRE.
    //
    // ⚠ AUCUNE SESSION N'EST OUVERTE ICI, ni anonyme ni autre. C'est ce qui rendait
    //   l'accueil impossible hors ligne : `signInAnonymously` est un appel réseau, et
    //   quelqu'un dans un train voyait un message d'échec avant d'avoir vu le jeu. La
    //   session attend désormais la confirmation du royaume
    //   (worker.on_region_screen_done), premier instant où l'application a réellement
    //   quelque chose à demander au serveur. Seuil, interlude, deux portes et choix du
    //   royaume se jouent donc entièrement hors ligne.
    //
    // ⚠ ON NE SAIT RIEN DU JOUEUR À CET INSTANT, et c'est voulu : l'interlude est la
    //   même chose pour tout le monde. C'est APRÈS qu'on demande qui il est — un
    //   nouveau venu ou quelqu'un qui revient —, quand il sait enfin ce qu'on lui
    //   propose de rejoindre.
    Future<void> on_start_adventure(DvShape? caller, dynamic event) async {

                                if (_introPlaying) return;      // double tap sur un bouton qui ne gèle qu'un lead
                                _introPlaying = true;

                                // Rien à précharger : chaque tableau charge SA réplique à son beat,
                                // sous le même et unique surnom. Les fichiers sont dans le paquet,
                                // donc c'est instantané.

                                final play = ActionRegistry.get("dvinterlude.play.intro");
                                if (play == null) {
                                    // dvinterlude absent du build : on ne prive personne du jeu pour une
                                    // animation. On enchaîne comme si elle s'était jouée.
                                    deva_log("warning", "[intro] dvinterlude absent : accueil sauté");
                                    await on_intro_finished(null, null);
                                    return;
                                }
                                await play(null, null);
    }

    // Un tableau commence. Tiré par le `on_end` du `hold` de 0,05 s posé en parallèle de
    // chaque groupe d'entrée (cf. scène `intro` du thème) : dvflame passe l'identifiant de
    // l'effet en charge, et son préfixe nomme le tableau.
    //
    // ⚠ ANCRÉ SUR L'ACTE, PAS SUR UN MINUTEUR. Le texte et la voix sont posés par la scène
    //   elle-même, au moment exact où l'image paraît. Retoucher le rythme d'un tableau
    //   dans le thème ne demande donc pas de toucher ce fichier — et surtout, aucune
    //   dérive ne peut s'installer entre ce qu'on voit et ce qu'on entend.
    Future<void> on_intro_beat(dynamic caller, dynamic event) async {

                                final effect = (event is Map ? event["effect"] : null)?.toString() ?? "";
                                final m = RegExp(r'^b([1-4])_').firstMatch(effect);
                                if (m == null) return;
                                final t = m.group(1);

                                final text = await _introTr("intro_t$t");
                                if (text.isNotEmpty) {
                                    ActionRegistry.get("dvorb.splash.lang_choice/intro_label")
                                        ?.call(null, text);
                                } else {
                                    deva_log("warning",
                                        "[intro] aucun texte pour 'intro_t$t' — le tableau precedent "
                                        "reste affiche");
                                }

                                // ⚠ UN SEUL SURNOM POUR LES QUATRE RÉPLIQUES, et c'est ce qui rend la
                                //   superposition impossible plutôt que corrigée. Avec quatre surnoms,
                                //   il fallait éteindre les trois autres à chaque beat — et il a suffi
                                //   qu'un `stop` laisse un lecteur dans un état dont `play` ne le sort
                                //   pas pour que les tableaux 2 à 4 restent muets. Un seul canal : le
                                //   chargement suivant remplace le précédent, et rien ne se chevauche.
                                await ActionRegistry.get("dvsound.stop.intro_voice")?.call(null, null);
                                if (await _loadVoice("intro_voice", "t$t")) {
                                    await _porteLaVoix("intro_voice");
                                    ActionRegistry.get("dvsound.play.intro_voice")?.call(null, null);
                                }
    }

    // ⚠ IL N'Y A PAS DE SAUT, et c'est délibéré. Un voile tapable a existé ici, puis on
    //   l'a retiré : ces trente secondes sont le seul moment où le jeu explique de quoi
    //   il parle avant de commencer à demander, et elles n'arrivent qu'une fois par
    //   installation. Laisser passer outre, c'est laisser arriver au premier formulaire
    //   quelqu'un qui ne sait toujours pas où il est — précisément ce qu'on corrige.
    //   L'interlude garde donc le gel `quiet` de dvinterlude (`freeze` au défaut).

    // Fin de l'accueil (normale, sautée, ou terminée par le garde-fou) : on range, et on
    // entre dans l'onboarding.
    //
    // ⚠ LE CALLER EST `null`, ET CE N'EST PAS UNE NÉGLIGENCE. dvinterlude tire ses
    //   `on_finished` avec SON propre DvBeing en appelant, et dvsteps demande à l'appelant
    //   `get_page()` — une méthode qui n'existe que sur les DvShape. L'exception serait
    //   avalée par dvinterlude et la navigation se perdrait sans un mot. Avec `null`,
    //   dvsteps retombe sur la page courante, qui est bien `home`.
    Future<void> on_intro_finished(dynamic caller, dynamic event) async {

                                _introPlaying = false;

                                ActionRegistry.get("dvsound.stop.intro_voice")?.call(null, null);
                                // ⚠ LA NAVIGATION A DÉJÀ EU LIEU, sous le rideau (worker.on_intro_reveal,
                                //   tiré par le dernier fondu de la scène). Il ne reste rien à faire ici :
                                //   naviguer maintenant rendrait l'écran des langues visible quelques
                                //   secondes, le temps que le rideau se lève — exactement ce qu'on évite.
                                //   Le filet ci-dessous ne sert qu'au cas où la scène n'aurait pas joué
                                //   son dernier acte (garde-fou, module absent).
                                if (DvOrb.get_current_page()?.dvid == "lang_choice") {
                                    await ActionRegistry.get("steps.navigate")?.call(null, null);
                                }
    }

    // L'écran est entièrement couvert par le rideau noir : c'est l'instant, et le seul,
    // où l'on peut changer de page sans que personne ne le voie. Le dernier acte de la
    // scène lève ensuite ce rideau — et découvre les deux portes, déjà en place.
    //
    // ⚠ MÊME MÉCANIQUE QUE L'OUVERTURE DU BUTIN, et pour la même raison : une bascule
    //   d'écran faite APRÈS la fin d'un interlude se voit toujours, parce qu'il reste
    //   une fraction de seconde pendant laquelle l'ancien écran est de nouveau visible.
    //   Ici c'était pire — l'écran des langues réapparaissait le temps du fondu final.
    //
    // ⚠ CE QUI REND LA CHOSE POSSIBLE : la scène `intro` est montée sur les DEUX pages
    //   (lang_choice/intro_view et home/intro_view). La vue de la page qui arrive
    //   s'attache à la scène EN COURS, celle de la page qui part se détache — la scène,
    //   elle, ne s'interrompt pas.
    Future<void> on_intro_reveal(dynamic caller, dynamic event) async {

                                if (DvOrb.get_current_page()?.dvid != "lang_choice") return;
                                await ActionRegistry.get("steps.navigate")?.call(null, null);
    }

    // -----------------------------------------------------------------------
    // --- Le pacte : les conditions viennent d'être acceptées
    // -----------------------------------------------------------------------

    // Les trois temps de la scène `pacte` : le premier choc, le second, puis la voix.
    // Tirés par les `hold` porteurs de hook du thème, comme les tableaux de l'accueil —
    // et pour la même raison : ce qu'on ENTEND est ancré sur ce qu'on VOIT, pas sur un
    // minuteur parallèle qui dériverait dès qu'une image met un peu plus longtemps.
    //
    // ⚠ LE MÊME SURNOM QUE LES RÉPLIQUES D'ÉCRAN (`onb_voice`), volontairement : c'est
    //   lui que la scène surveille via `wait_sound: onb_voice` pour tenir la pose
    //   jusqu'au bout de la phrase. Un surnom à part obligerait à le déclarer aussi au
    //   thème, en deux endroits qu'on penserait à désaccorder.
    Future<void> on_pacte_beat(dynamic caller, dynamic event) async {

                                final effect = (event is Map ? event["effect"] : null)?.toString() ?? "";

                                // Les deux lames : le même son, deux fois, à un quart de seconde
                                // d'intervalle. C'est ce décalage qui fait entendre DEUX épées.
                                if (effect.startsWith("q3_") || effect.startsWith("q4_")) {
                                    await _chocDesLames();
                                    return;
                                }

                                if (effect.startsWith("q5_")) {
                                    if (await _loadVoice("onb_voice", "pacte")) {
                                        await _porteLaVoix("onb_voice");
                                        ActionRegistry.get("dvsound.play.onb_voice")?.call(null, null);
                                    }
                                }
    }

    // Le choc des lames. CHARGE PAR SON CHEMIN, comme la musique du seuil et pour la
    // meme raison : `sound.preload` vit dans le THEME, et le theme du cache ecrase celui
    // du paquet sans etre forcement a jour. Un surnom qu'il ne connait pas encore ne joue
    // rien, et `dvsound` ne s'en plaint qu'une fois — la premiere.
    //
    // Le chargement n'a lieu qu'au premier choc : le second, un quart de seconde plus
    // tard, retrouve le lecteur deja pret.
    Future<void> _chocDesLames() async {

                                // Aucun chargement ici : tout est pret depuis l'ouverture de
                                // l'ecran des conditions (`_preparePacte`). Un `load` au moment
                                // du choc coutait une seconde — le son tombait bien apres que les
                                // lames se soient croisees.
                                if (!_lamesPretes) return;
                                ActionRegistry.get("dvsound.stop.pacte_clang")?.call(null, null);
                                ActionRegistry.get("dvsound.play.pacte_clang")?.call(null, null);
    }

    // Fin du pacte : on entre enfin dans le jeu.
    //
    // ⚠ CALLER `null`, comme pour l'accueil : dvinterlude tire ses `on_finished` avec son
    //   propre DvBeing, auquel dvsteps demanderait `get_page()` — une méthode qui n'existe
    //   que sur les DvShape. L'exception serait avalée et la navigation perdue sans un mot.
    Future<void> on_pacte_finished(dynamic caller, dynamic event) async {

                                // ⚠ PLUS DE NAVIGATION ICI : elle a déjà eu lieu, sous le noir
                                //   (`pacte.on_covered` au thème). La refaire empilerait un écran,
                                //   et la faire À LA PLACE laissait voir l'ancien réapparaître le
                                //   temps du dernier fondu.
                                ActionRegistry.get("dvsound.stop.onb_voice")?.call(null, null);
    }

    // -----------------------------------------------------------------------
    // --- La mise en scène des étapes
    // -----------------------------------------------------------------------

    // Arrivée sur un écran d'onboarding : la scène `arrive` (un voile qui se lève, une
    // volée d'étincelles — aucune image, elle marche donc sans réseau elle aussi) et la
    // réplique du conteur pour CET écran.
    //
    // ⚠ LE FICHIER DE VOIX PORTE LE dvid DE L'ÉCRAN (« intro/voices/<page>_<lang>.wav »).
    //   Pas de table de correspondance : renommer un écran sans renommer sa voix la fait
    //   taire, et c'est le seul couplage. Il est volontaire — une table aurait été un
    //   second endroit à tenir à jour, et c'est toujours celui-là qu'on oublie.
    //
    // ⚠ DÉCORATIF, DONC MUET EN CAS D'ABSENCE. Ni garde, ni verrou, ni attente : cet
    //   écran doit se comporter exactement pareil si la scène ou la voix manquent.
    // ⚠ `dynamic caller` ET NON `DvShape?` : l'`appear` d'une PAGE passe la page
    //   elle-même, et une page est un DvView, pas un DvShape. Typer le paramètre
    //   `DvShape?` faisait lever un `type 'DvPage' is not a subtype of 'DvShape?'` que
    //   DvView attrape et journalise — l'écran naissait donc inerte, en silence.
    Future<void> on_onboarding_appear(dynamic caller, dynamic event) async {

                                // Le caller d'un `appear` de page EST la page (DvShape._dispatchAction
                                // passe `this`), et `dvid` y est un String non nullable : seul le
                                // caller peut manquer.
                                final pageId = caller?.dvid ?? "";
                                if (pageId.isEmpty) {
                                    deva_log("warning", "[conteur] appear sans appelant — écran muet");
                                    return;
                                }
                                deva_log("info", "[conteur] arrivée sur '$pageId'");

                                // Le décor ne se lance plus d'ici : la scène `arrive` porte
                                // `autostart: true` et part quand sa vue s'attache. Le faire à la
                                // main depuis un `appear` la lançait AVANT que sa vue n'existe.
                                await _ditLaReplique(pageId);
    }

    // L'écran des conditions : le rideau se lève, puis la réplique.
    //
    // ⚠ IL LUI FAUT SON PROPRE HANDLER parce qu'il est le seul écran du tunnel à porter
    //   `masks: [page]` et non `page_onboarding` — un choix de sobriété assumé, cet
    //   écran n'ayant ni bandeau de chapitre ni étincelles. Mais `page_onboarding` est
    //   aussi ce qui injecte la scène `arrive` partout ailleurs : sans elle, l'écran
    //   paraîtrait d'un coup derrière le noir posé par l'âge.
    //
    //   D'où la vue `commons/arrive_view` déclarée à la main sur cet écran, et ce
    //   handler qui la joue. Le voile se lève ; les étincelles de `arrive`, elles,
    //   restent discrètes et ne détournent pas d'un texte qui engage.
    // ⚠ `dynamic caller` ET NON `DvShape?` : l'`appear` d'une PAGE passe la page
    //   elle-même, et une page est un DvView, pas un DvShape. Typer le paramètre
    //   `DvShape?` faisait lever un `type 'DvPage' is not a subtype of 'DvShape?'` que
    //   DvView attrape et journalise — l'écran naissait donc inerte, en silence.
    Future<void> on_acceptance_appear(dynamic caller, dynamic event) async {

                                // ⚠ LES SONS DU PACTE SE CHARGENT ICI, plusieurs secondes avant la
                                //   scene. Charges au moment du choc, ils arrivaient avec une
                                //   seconde de retard : `dvsound.load` lit le fichier, le decode
                                //   et construit un lecteur — un travail qu'on ne peut pas faire
                                //   tenir dans l'intervalle de deux lames qui se croisent.
                                //
                                //   Cet ecran precede TOUJOURS le pacte, et rien ne presse ici :
                                //   c'est le meilleur endroit pour payer ce cout.
                                unawaited(_preparePacte());
                                await _ditLaReplique("documents_acceptance_screen");
    }

    // Les deux sons du pacte, charges d'avance et une seule fois.
    Future<void> _preparePacte() async {

                                final snd = ModuleRegistry.create("dvsound");
                                if (snd == null) return;
                                for (final duo in const [
                                    ["pacte_clang", "intro/pacte/swords.mp3"],
                                    ["pacte_feu",   "sounds/anim_burn.mp3"],
                                ]) {
                                    try {
                                        final ok = await (snd as dynamic)
                                            .load(duo[0], duo[1]) == true;
                                        if (!ok) {
                                            deva_log("warning",
                                                "[pacte] '${duo[1]}' introuvable — ${duo[0]} muet");
                                        }
                                    } catch (e) {
                                        deva_log("warning", "[pacte] ${duo[0]} : $e");
                                    }
                                }
                                _lamesPretes = true;
    }

    // Le cercle de feu s'ouvre : le grondement part avec lui.
    Future<void> on_pacte_flammes(dynamic caller, dynamic event) async {

                                ActionRegistry.get("dvsound.play.pacte_feu")?.call(null, null);
    }

    // L'entrée dans le jeu : la bienvenue, UNE SEULE FOIS DANS LA VIE DU JOUEUR.
    //
    // ⚠ LE DASHBOARD N'EST PAS UN ÉCRAN DE TUNNEL. On y revient de partout, à chaque
    //   retour d'écran et à chaque lancement de l'application — plusieurs fois par jour.
    //   Une réplique jouée à chaque `appear` deviendrait insupportable en trois jours, et
    //   c'est le genre de détail qui fait désinstaller. Elle se dit à la PREMIÈRE arrivée
    //   et plus jamais.
    //
    // ⚠ LE DRAPEAU EST PERSISTÉ, pas gardé en mémoire : une réinstallation le remet à
    //   zéro — c'est bien un nouveau joueur — mais un simple redémarrage non.
    Future<void> on_dashboard_welcome(dynamic caller, dynamic event) async {

                                if ((await deva_get("worker.dashboard_greeted")) == true) return;
                                await Deva.instance.set("worker.dashboard_greeted", true);
                                await Deva.instance.store();
                                await _ditLaReplique("dashboard");
    }

    // La réplique du conteur, SANS le décor. Un écran l'emploie : celui de l'énigme.
    //
    // ⚠ CES DEUX-LÀ N'ONT PAS DE SCÈNE, ET C'EST VOULU. `parentalgate_screen` est un
    //   contrôle — un calcul, un compte à rebours —, et `documents_acceptance_screen`
    //   demande de LIRE un texte qui engage. Y faire voler des étincelles habillerait
    //   précisément les deux moments du parcours où l'on veut que le joueur regarde ce
    //   qui est écrit. La voix, elle, ne cache rien : elle dit quoi faire et se tait.
    // ⚠ `dynamic caller` ET NON `DvShape?` : l'`appear` d'une PAGE passe la page
    //   elle-même, et une page est un DvView, pas un DvShape. Typer le paramètre
    //   `DvShape?` faisait lever un `type 'DvPage' is not a subtype of 'DvShape?'` que
    //   DvView attrape et journalise — l'écran naissait donc inerte, en silence.
    Future<void> on_screen_voice(dynamic caller, dynamic event) async {

                                final pageId = caller?.dvid ?? "";
                                if (pageId.isEmpty) return;
                                await _ditLaReplique(pageId);
    }

    // Décorative de bout en bout : un fichier absent ne fait rien, ne bloque rien, et ne
    // change le comportement d'aucun écran.
    Future<void> _ditLaReplique(String pageId) async {

                                if (await _loadVoice("onb_voice", pageId)) {
                                    await _porteLaVoix("onb_voice");
                                    ActionRegistry.get("dvsound.play.onb_voice")?.call(null, null);
                                    return;
                                }
                                // Décoratif, donc non bloquant — mais PAS silencieux. Une réplique
                                // qui manque se voit au journal, sans quoi on ne distingue pas
                                // « le fichier n'est pas là » de « l'écran n'a jamais demandé ».
                                deva_log("warning",
                                    "[conteur] pas de réplique pour '$pageId' "
                                    "(intro/voices/${pageId}_$_voiceLang.mp3)");
    }

    // Le niveau des répliques du conteur : RIEN À FAIRE ICI, et c'est le propos.
    //
    // ⚠ L'AMPLIFICATION VIT DANS LE FICHIER, pas à la lecture. On a d'abord poussé
    //   `setVolume` à 150 % — sans effet audible : au-delà de 1.0, le réglage est borné
    //   en silence selon la plateforme, et l'on croit avoir monté le son alors qu'on n'a
    //   rien fait. Les dérivations audio portent donc `gain: 2.0` (+6 dB, limiteur
    //   compris, cf. `assetgen._convert_audio`) : le même résultat partout, une fois pour
    //   toutes, et rien à exécuter.
    //
    //   Cette méthode reste comme point d'accroche nommé : si un jour une voix doit être
    //   atténuée ponctuellement — une réplique par-dessus une scène bruyante —, c'est
    //   ici, et l'action `dvsound.volume.<nick>.<pct>` existe pour cela.
    // Le niveau des répliques du conteur : RIEN À FAIRE ICI, et c'est le propos.
    //
    // ⚠ UNE CORRECTION DE SONIE NE SE FAIT PAS À LA LECTURE. `setVolume` est borné à 1.0
    //   en silence selon la plateforme : monter un son à 140 % ne produit rien, et l'on
    //   croit avoir agi. Elle se fait dans le FICHIER, à la dérivation — et pas ici mais
    //   dans le framework, parce qu'elle qualifie la VOIX et non cette application :
    //   cf. `_GAIN_PAR_VOIX` dans `assetgen.py`.
    //
    //   Cette méthode reste comme point d'accroche nommé : si une réplique devait un jour
    //   être ATTÉNUÉE ponctuellement — par-dessus une scène bruyante —, c'est ici, et
    //   `dvsound.volume.<nick>.<pct>` existe pour cela (en dessous de 100, où elle agit).
    Future<void> _porteLaVoix(String nick) async {}
}
