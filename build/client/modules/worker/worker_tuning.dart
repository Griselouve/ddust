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
// --- worker extension — Barèmes de jeu (XP, PV, butin)
// -----------------------------------------------------------------------------
extension Worker_tuning on worker {

    // XP rapportés par une tâche. Réutilisable dans tout le projet : prend la tâche
    // (couche tasks-base) et applique `(_xpPerEffort + respawn_h / _xpRespawnDiv) × effort`.
    // La part variable donne du poids aux corvées rares et lourdes : à effort égal, nettoyer
    // le four (720 h) vaut 7× mettre la table (6 h). Si la tâche porte un `dead` ET un `revive`
    // non nuls et que l'heure courante tombe entre les deux, l'XP est proportionnel :
    // 0 % à `dead`, 100 % à `revive`.
    int getTaskXPs(Dvidle? task) {

                            final effortRaw = task?.get("effort");
                            final effort    = effortRaw == null ? 0 : (int.tryParse(effortRaw.toString()) ?? 0);
                            // respawn_h absent (donnée partielle) → 0, on retombe sur l'ancien effort × _xpPerEffort.
                            final respawnH  = int.tryParse(task?.get("respawn_h")?.toString() ?? "") ?? 0;
                            final base      = _taskBaseXp(effort, respawnH);

                            final deadRaw   = task?.get("dead")?.toString()   ?? "";
                            final reviveRaw = task?.get("revive")?.toString() ?? "";
                            if (deadRaw.isEmpty || reviveRaw.isEmpty) return base;
                            try {
                                final dead   = DateTime.parse(deadRaw).toUtc();
                                final revive = DateTime.parse(reviveRaw).toUtc();
                                final now    = DateTime.now().toUtc();
                                final span   = revive.difference(dead).inMilliseconds;
                                if (span <= 0) return base;                     // bornes invalides → XP plein
                                if (!now.isAfter(dead))   return 0;             // now <= dead   → 0 %
                                if (!now.isBefore(revive)) return base;         // now >= revive → 100 %
                                final factor = now.difference(dead).inMilliseconds / span;  // dans ]0,1[
                                return (base * factor).round();
                            } catch (e) {
                                return base;                                    // dates non parsables → XP plein
                            }
    }

    // XP de base d'une tâche à pleine régénération, sans proratisation `dead`/`revive` :
    // `(_xpPerEffort + respawn_h / _xpRespawnDiv) × effort`. Un seul point de vérité pour
    // getTaskXPs (badge de combat, crédit au verdict) et _effortOptionLabel (picklist d'édition).
    int _taskBaseXp(int effort, int respawnH) {

                            final div = _xpRespawnDiv > 0 ? _xpRespawnDiv : 12;   // garde-fou : jamais de division par 0
                            return (effort * (_xpPerEffort + respawnH / div)).round();
    }

    // XP cumulé requis pour ATTEINDRE le niveau [n] (n <= 1 → 0 XP, on démarre niveau 1).
    int _xpForNiveau(int n) => n <= 1 ? 0 : _xpPerLevel * (n * (n + 1) ~/ 2 - 1);

    int get _xpPerLevelClan => _xpPerLevel * _clanXpFactor;

    // XP cumulé requis pour ATTEINDRE le niveau CLAN [n] (miroir de _xpForNiveau).
    int _xpForNiveauClan(int n) => n <= 1 ? 0 : _xpPerLevelClan * (n * (n + 1) ~/ 2 - 1);

    // --- Butin du clan : compteur cumulé + snapshot d'ouverture ------------------------------
    // `clans.butin_xp` est MONOTONE : il n'est jamais remis à 0, même quand le coffre est ouvert.
    // L'ouverture pose `clans.last_butin_xp = clans.butin_xp` ; le butin réellement en jeu est le
    // DELTA entre les deux. Tout ce qui affiche ou plafonne le butin doit donc passer par
    // _butinCourant() — jamais lire `butin_xp` brut, qui ne fait que grandir de partie en partie.
    // (Homonyme volontaire du champ `last_butin_xp` de clans_players, qui joue le même rôle de
    // snapshot mais sur l'XP DU JOUEUR : même sémantique « valeur au dernier reset », autre grandeur.)

    // Butin CUMULÉ depuis la création du clan (compteur monotone).
    int _butinCumul(Dvidle doc) => int.tryParse(doc.get("butin_xp")?.toString() ?? "0") ?? 0;

    // Butin cumulé AU DERNIER COFFRE OUVERT. Champ absent (coffre jamais ouvert, ou clan antérieur
    // à l'introduction du champ) → 0, donc cumul et courant coïncident : rétrocompatible.
    int _butinBase(Dvidle doc) => int.tryParse(doc.get("last_butin_xp")?.toString() ?? "0") ?? 0;

    // Butin du CYCLE COURANT = ce que la jauge affiche et ce que le plafond borne. Borné des deux
    // côtés par prudence : une base incohérente (supérieure au cumul) ne doit pas rendre un négatif.
    int _butinCourant(Dvidle doc) =>
        (_butinCumul(doc) - _butinBase(doc)).clamp(0, _butinMaxXp);

    // XP à ajouter au butin pour `xpGagne` XP gagnées par le clan, au facteur `factor` du clan.
    // Point d'extension unique si la règle évolue (aujourd'hui : simple produit).
    int _butinGainFromXp(int xpGagne, int factor) => xpGagne * factor;

    // Plafond effectif = plafond de BASE porté par le doc (joueur ou clan) + `parNiveau` × niveau.
    // Point d'extension unique de la règle « le plafond croît avec le niveau », partagé par le
    // plafond joueur (_creditXp, _readPlayerMaxXp) et le plafond de gain du butin
    // (_creditClanButin). Base ≤ 0 → aucun plafond (0), garde-fou conservé des appelants existants :
    // un réglage aberrant ne doit pas annuler tous les gains du jeu.
    int _capForLevel(int base, int niveau, int parNiveau) =>
        base <= 0 ? 0 : base + parNiveau * niveau;

    // PV réellement affiché = pv stocké − dégradation temporelle − dégâts, borné à [0, pv].
    // Dégradation = entier((now − last_task) en JOURS FRACTIONNAIRES / decay). decay = jours (réels)
    // par PV perdu — supporte le sous-journalier (ex. 0.5 = 12 h). decay ≤ 0 = division par zéro =
    // perte INFINIE → mort instantanée (pvShown=0) dès qu'un temps s'est écoulé, quel que soit damage.
    // last_task vide/illisible → pas de perte temporelle.
    // `damage` retranche TOUJOURS par sa valeur absolue (le PV affiché ne peut jamais dépasser pv,
    // donc damage ne soigne pas : |damage| = nombre de PV retirés, peu importe le signe stocké).
    // Point d'extension unique de la règle PV.
    int _computeDisplayedPv(int pv, int damage, String lastTaskIso, double decay) {

                            var loss = 0;
                            if (lastTaskIso.isNotEmpty) {
                                final last = DateTime.tryParse(lastTaskIso)?.toUtc();
                                if (last != null) {
                                    final elapsedDays = DateTime.now().toUtc().difference(last).inSeconds / 86400.0;
                                    if (elapsedDays > 0) {
                                        if (decay <= 0) return 0;                     // decay=0 → perte infinie → mort
                                        loss = (elapsedDays / decay).floor();
                                    }
                                }
                            }
                            return (pv - loss - damage.abs()).clamp(0, pv);
    }

    // Lecture robuste du champ `decay` : accepte un double/entier natif, une chaîne numérique
    // ("1e-7"), OU l'ancienne structure imbriquée {doubleValue: "..."} laissée par les docs écrits
    // avant le fix double du backend REST dvcloud (dvcloud_rest_backend.dart). Repli sur
    // _playerDecay si null/illisible. → auto-répare les docs corrompus sans manip console.
    double _readDecay(dynamic raw) {

                            if (raw is num) return raw.toDouble();
                            if (raw is String) return double.tryParse(raw) ?? _playerDecay;
                            if (raw is Dvidle) {
                                final inner = raw.get("doubleValue");
                                if (inner != null) return double.tryParse(inner.toString()) ?? _playerDecay;
                            }
                            if (raw is Map && raw["doubleValue"] != null) {
                                return double.tryParse(raw["doubleValue"].toString()) ?? _playerDecay;
                            }
                            return _playerDecay;
    }

    // Lit un entier de la conf `worker.<key>` ; retombe sur `dflt` si absent/non parsable.
    Future<int> _confInt(String key, int dflt) async {

                            final raw = await deva_get("worker.$key");
                            return int.tryParse(raw?.toString() ?? "") ?? dflt;
    }

    // Miroir réel de _confInt : lit un double de la conf `worker.<key>` (repli `dflt`).
    Future<double> _confDouble(String key, double dflt) async {

                            final raw = await deva_get("worker.$key");
                            return double.tryParse(raw?.toString() ?? "") ?? dflt;
    }

    // Charge les valeurs de réglage du jeu depuis la conf (clef `worker.*`) dans les champs
    // d'instance. Appelé une fois au démarrage (invoke). Chaque champ garde sa valeur par
    // défaut historique si la clef de conf est absente. Les barèmes étant lus de façon
    // synchrone dans des helpers (getTaskXPs, getNiveauProgres…), on les met en cache ici
    // plutôt que de rendre ces helpers asynchrones.
    Future<void> _loadTuning() async {

                            _xpPerEffort   = await _confInt("xp_per_effort",   _xpPerEffort);
                            _xpRespawnDiv  = await _confInt("xp_respawn_div",  _xpRespawnDiv);
                            _xpPerLevel    = await _confInt("xp_per_level",    _xpPerLevel);
                            _clanXpFactor  = await _confInt("clan_xp_factor",  _clanXpFactor);
                            _playerPv      = await _confInt("player_pv",       _playerPv);
                            _playerDecay   = await _confDouble("player_decay", _playerDecay);
                            _healPv        = await _confInt("heal_pv",         _healPv);
                            _playerMaxXp   = await _confInt("player_max_xp",   _playerMaxXp);
                            _playerMaxXpPerLevel = await _confInt("player_max_xp_per_level", _playerMaxXpPerLevel);
                            _playerMaxXpLegacy   = await _confInt("player_max_xp_legacy",    _playerMaxXpLegacy);
                            _butinMaxXp    = await _confInt("butin_max_xp",    _butinMaxXp);
                            _butinXpFactor = await _confInt("butin_xp_factor", _butinXpFactor);
                            _butinGainMaxXp         = await _confInt("butin_gain_max_xp",           _butinGainMaxXp);
                            _butinGainMaxXpPerLevel = await _confInt("butin_gain_max_xp_per_level", _butinGainMaxXpPerLevel);
                            _chestLowPct   = await _confInt("chest_low_pct",   _chestLowPct);
                            _chestHighPct  = await _confInt("chest_high_pct",  _chestHighPct);
                            deva_log("info", "[worker] tuning: xp=(${_xpPerEffort}+respawn/$_xpRespawnDiv)×effort, niveau/$_xpPerLevel, "
                                "clan×$_clanXpFactor, pv=$_playerPv, decay=$_playerDecay, "
                                "xp/tâche≤$_playerMaxXp+$_playerMaxXpPerLevel/niveau, butin≤$_butinMaxXp "
                                "×$_butinXpFactor (amorçage — facteur réel = clans.butin_xp_factor), "
                                "gain butin≤$_butinGainMaxXp+$_butinGainMaxXpPerLevel/niveau clan (amorçage — plafond réel = clans.max_xp_butin), "
                                "coffre $_chestLowPct%/$_chestHighPct%");
    }

    // Crédite le butin du clan (champ `butin_xp`) au moment où le clan gagne des XP.
    // Calcule le gain via _butinGainFromXp au facteur PROPRE AU CLAN (`butin_xp_factor` du
    // même doc), l'écrête au plafond de gain (propre au clan lui aussi, +20×niveau CLAN — cf.
    // _capForLevel), puis l'ajoute au butin courant et plafonne le CYCLE à _butinMaxXp. Opère sur
    // le doc clan DÉJÀ lu par _creditClanXp (même lecture/écriture → pas de round-trip ni de
    // contention supplémentaires, et le facteur/plafond lus sont forcément frais).
    // `clanNiveau` = niveau du clan AVANT ce gain (passé par l'appelant, qui vient de lire/muter
    // `xp` sur le même doc — le relire ici donnerait le niveau D'APRÈS).
    void _creditClanButin(Dvidle doc, int xpGagne, int clanNiveau) {

                            if (_butinCourant(doc) >= _butinMaxXp) return;       // coffre du cycle déjà plein
                            // Facteur PORTÉ PAR LE CLAN, relu ici à chaque crédit (le doc vient d'être lu
                            // par _creditClanXp) → une modification en cours de partie prend effet sans
                            // relancer l'app. Champ absent (clan antérieur au champ) → repli sur la conf.
                            final factor = int.tryParse(doc.get("butin_xp_factor")?.toString() ?? "")
                                           ?? _butinXpFactor;
                            var gain = _butinGainFromXp(xpGagne, factor);
                            if (gain <= 0) return;
                            // Plafond de CE crédit, PORTÉ PAR LE CLAN (même idiome que le facteur ci-dessus),
                            // +20×niveau du clan : un jeune clan remplit son coffre corvée après corvée, un
                            // clan aguerri peut le faire bondir d'un seul coup.
                            final baseCap = int.tryParse(doc.get("max_xp_butin")?.toString() ?? "")
                                            ?? _butinGainMaxXp;
                            final capGain = _capForLevel(baseCap, clanNiveau, _butinGainMaxXpPerLevel);
                            if (capGain > 0 && gain > capGain) gain = capGain;
                            doc.set("butin_xp", _butinPlafonne(doc, gain));
    }

    // Nouvelle valeur du compteur CUMULÉ après un gain de `gain`, plafond appliqué au DELTA :
    // le cycle courant ne dépasse jamais _butinMaxXp, mais le cumul n'est pas écrêté dans l'absolu
    // (il stagne à `base + plafond` jusqu'à la prochaine ouverture, qui relève la base).
    // Écrêter le cumul lui-même détruirait l'information dont le delta a besoin au cycle suivant.
    int _butinPlafonne(Dvidle doc, int gain) {

                            final plein = _butinBase(doc) + _butinMaxXp;
                            final next  = _butinCumul(doc) + gain;
                            return next > plein ? plein : next;
    }

    // Niveau d'un joueur ET sa progression vers le niveau suivant, à partir de son XP total.
    // Retourne (niveau, progres) où `progres` ∈ [0, 1[ = fraction parcourue entre le seuil
    // du niveau courant et celui du suivant (à multiplier par 100 pour un %).
    // Réutilisable partout (badge joueur, profil, barre de progression, notif level-up).
    ({int niveau, double progres}) getNiveauProgres(int xp) {

                            if (xp <= 0) return (niveau: 1, progres: 0.0);

                            // Approximation par inversion de la formule, puis correction des erreurs
                            // d'arrondi flottant exactement aux seuils (cheap : 0–1 itération en pratique).
                            var niveau = (-1 + sqrt(9 + 8.0 * xp / _xpPerLevel)) ~/ 2;
                            if (niveau < 1) niveau = 1;
                            while (_xpForNiveau(niveau + 1) <= xp) niveau++;
                            while (_xpForNiveau(niveau) > xp)      niveau--;

                            final seuil   = _xpForNiveau(niveau);       // XP au début du niveau courant
                            final suivant = _xpForNiveau(niveau + 1);   // XP au début du niveau suivant
                            final span    = suivant - seuil;            // coût du niveau courant (> 0)
                            final progres = span <= 0 ? 0.0 : (xp - seuil) / span;
                            return (niveau: niveau, progres: progres.clamp(0.0, 1.0));
    }

    // Rang du titre correspondant à un NIVEAU : le 1er titre s'acquiert au niveau 5, puis un
    // nouveau tous les 5 niveaux (5→0, 10→1, …), borné au dernier titre existant. -1 = pas encore
    // de titre. Seul point de vérité de la formule : le level-up joueur, la détection de palier de
    // clan et l'attribution de l'item la partagent tous — elle n'a plus le droit d'être réécrite.
    int _titleIdxFor(int niveau, {int count = 20}) {

                            final idx = (niveau ~/ 5) - 1;
                            if (idx < 0) return -1;
                            return idx > count - 1 ? count - 1 : idx;
    }

    // Token du titre de rang <idx> (joueur ou clan), résolu par le moteur de thème
    // (player_title_N / clan_title_N, cf. _taskDifficulty pour le même idiome). idx < 0 → chaîne
    // vide : le label naît et reste vide, aucun titre ne s'affiche. C'est désormais l'état NORMAL
    // d'un joueur qui n'a pas encore appliqué de titre — le niveau ne donne plus le titre, il
    // donne l'OBJET titre (cf. _grantTitleItem) ; le porter est un choix distinct.
    String _titleKeyOf(String prefix, int idx, {int count = 20}) {

                            if (idx < 0) return "";
                            final capped = idx > count - 1 ? count - 1 : idx;
                            return "@@@T:${prefix}_$capped@@@";
    }

    // Niveau d'un CLAN ET sa progression vers le niveau suivant — copie de getNiveauProgres()
    // utilisant le barème clan (_xpPerLevelClan / _xpForNiveauClan, ×10). Rien n'est stocké :
    // tout se dérive de l'xp cumulé du clan à l'affichage.
    ({int niveau, double progres}) getClanNiveauProgres(int xp) {

                            if (xp <= 0) return (niveau: 1, progres: 0.0);

                            // Approximation par inversion de la formule, puis correction des erreurs
                            // d'arrondi flottant exactement aux seuils (cheap : 0–1 itération en pratique).
                            var niveau = (-1 + sqrt(9 + 8.0 * xp / _xpPerLevelClan)) ~/ 2;
                            if (niveau < 1) niveau = 1;
                            while (_xpForNiveauClan(niveau + 1) <= xp) niveau++;
                            while (_xpForNiveauClan(niveau) > xp)      niveau--;

                            final seuil   = _xpForNiveauClan(niveau);       // XP au début du niveau courant
                            final suivant = _xpForNiveauClan(niveau + 1);   // XP au début du niveau suivant
                            final span    = suivant - seuil;                // coût du niveau courant (> 0)
                            final progres = span <= 0 ? 0.0 : (xp - seuil) / span;
                            return (niveau: niveau, progres: progres.clamp(0.0, 1.0));
    }

    // Badge de difficulté : libellé d'effort traduit + XP (ex. "@@@T:dt_effort_5@@@ - 8 XP").
    // `cap` = plafond d'XP par tâche du joueur CONCERNÉ (0 = pas de plafond connu) : le badge ne
    // doit jamais promettre plus que ce qui sera versé.
    String _taskDifficulty(int effort, int xp, {int cap = 0}) {

                            final shown = (cap > 0 && xp > cap) ? cap : xp;
                            return "@@@T:dt_effort_$effort@@@ - $shown XP";
    }

    // Même badge, mais pour une tâche RECOMMANDÉE (boss) : annonce la FOURCHETTE réellement en jeu
    // (ex. "@@@T:dt_effort_5@@@ - 24-56 XP") au lieu de l'XP de base, qui sous-vendait la tâche —
    // c'est justement le gain exceptionnel qui doit donner envie de s'y mettre tout de suite.
    // Les bornes viennent de _bossXpRange, donc du même calcul que le crédit : ce qui est promis
    // ici est exactement ce qui peut tomber. `recommended` vide, ou fourchette réduite à un point
    // (recommandation trop ancienne, le coefficient est retombé à 1) → badge normal.
    // Les deux bornes sont ÉCRÊTÉES au plafond du joueur (`cap`) : c'est le bonus boss sur une
    // grosse corvée qui touche le plafond, et sans cet écrêtage le badge annoncerait une XP que
    // _creditXp ne versera pas. Si l'écrêtage referme la fourchette (les deux bornes au plafond),
    // on retombe sur le badge simple plutôt que d'afficher « 500-500 XP ».
    String _taskDifficultyRange(int effort, int xp, String recommended, {int cap = 0}) {

                            var (lo, hi) = _bossXpRange(xp, recommended);
                            if (cap > 0) {
                                if (lo > cap) lo = cap;
                                if (hi > cap) hi = cap;
                            }
                            if (lo == hi) return _taskDifficulty(effort, lo);
                            return "@@@T:dt_effort_$effort@@@ - $lo-$hi XP";
    }

    // Plafond d'XP par tâche du joueur [userId] (clans_players.max_xp + 20×niveau — cf.
    // _capForLevel), pour l'AFFICHAGE du badge. En revue admin c'est le plafond de l'ASSIGNEE qui
    // compte, jamais celui de l'admin qui juge : le badge doit montrer ce que le joueur avait
    // devant lui. Doc illisible ou champ absent (antérieur au champ) → repli sur la conf, et rien
    // n'est mis en cache si la lecture a échoué (la prochaine ouverture de l'écran réessaiera).
    // Le cache mémorise le plafond DÉJÀ additionné du bonus de niveau ; _checkPlayerLevelUp
    // l'invalide sur montée de niveau (même idiome que l'invalidation de _writeClanPlayer,
    // l. 3901) pour que le badge ne promette jamais l'ancien plafond après un level-up.
    Future<int> _readPlayerMaxXp(String userId) async {

                            if (userId.isEmpty) return _playerMaxXp;
                            // Cache testé AVANT la session : dans le cas courant (son propre badge, rouvert
                            // à chaque appear) il n'y a aucune lecture du tout.
                            final cached = _maxXpCache[userId];
                            if (cached != null) return cached;
                            try {
                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session    = await _readSession(region);
                                final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) return _playerMaxXp;
                                final doc     = await _cloud?.read(
                                    "workers", "clans_players/$clanId/players", userId,
                                    ownerId: clanSecret, region: region);
                                final baseCap = int.tryParse(doc?.get("max_xp")?.toString() ?? "") ?? _playerMaxXp;
                                final xp      = int.tryParse(doc?.get("xp")?.toString()     ?? "0") ?? 0;
                                final cap     = _capForLevel(baseCap, getNiveauProgres(xp).niveau, _playerMaxXpPerLevel);
                                _maxXpCache[userId] = cap;
                                return cap;
                            } catch (e) {
                                deva_log("warning", "[combat] _readPlayerMaxXp($userId) FAILED: $e");
                                return _playerMaxXp;
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
