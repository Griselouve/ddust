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
// --- worker extension — Notifications
// -----------------------------------------------------------------------------
extension Worker_notify on worker {

    void _register_notify() {

                                // Les trois messages de la cérémonie (canal principal, cf. _notifyOpeningCall) :
                                // l'appel du meneur, la réponse d'un joueur, l'ouverture du coffre.
                                ActionRegistry.register("worker.on_opening_called",         on_opening_called);

                                ActionRegistry.register("worker.on_opening_player_ready",   on_opening_player_ready);

                                ActionRegistry.register("worker.on_butin_ready",            on_butin_ready);

                                // Relance d'engagement (pulse_sweeper). Bascule du réglage « Rappels »,
                                // proposée par le kebab Personnage (sur soi) comme par le menu roster
                                // (un chef pour un enfant).
                                ActionRegistry.register("worker.nudges_off",                nudges_off);

                                ActionRegistry.register("worker.nudges_on",                 nudges_on);

                                // Tap sur le corps d'une relance serveur (convention tap-corps).
                                ActionRegistry.register("worker.on_pulse_open",             on_pulse_open);

    }

    // -----------------------------------------------------------------------
    // --- Relance d'engagement : le refus, et le retour
    // -----------------------------------------------------------------------

    // Écrit `nudges` sur un membre. `event` vient soit du menu roster (map du joueur
    // cliqué, clef "id"), soit du kebab Personnage (rien → soi-même).
    //
    // Écriture CIBLÉE (deep-merge) : le doc membre porte xp/pv/damage/last_task, un PATCH
    // complet les emporterait. Même précaution que le tombstone de revoke_player.
    Future<void> _setNudges(dynamic event, bool value) async {

                    final m  = (event is Map) ? event : const {};
                    final id = (m["id"]?.toString() ?? "").isNotEmpty ? m["id"].toString() : _userId;
                    if (id.isEmpty) return;
                    try {
                        final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                        final session    = await _readSession(region);
                        final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                        final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                        if (clanId.isEmpty || clanSecret.isEmpty) return;

                        final flag = Dvidle({});
                        flag.set("id",      id);
                        flag.set("ownerId", clanSecret);
                        flag.set("nudges",  value);
                        await _cloud?.write("workers", "clans_players/$clanId/players", id, flag,
                            region: region, ownerId: clanSecret);

                        deva_log("info", "[pulse] rappels ${value ? "rétablis" : "coupés"} pour $id");

                        // La tuile doit refléter le nouveau réglage tout de suite : le menu
                        // roster relit `nudges` sur les membres poussés, pas sur Firestore.
                        await _refreshRoster(clanId, clanSecret, region);
                    } catch (e) {
                        deva_log("error", "[pulse] _setNudges($value) FAILED: $e");
                    }
    }

    // « Couper les rappels ». Aucune confirmation : refuser d'être relancé ne se négocie
    // pas, et une modale pour retenir quelqu'un qui part serait exactement le procédé que
    // ce dispositif s'interdit.
    Future<void> nudges_off(dynamic caller, dynamic event) async {

                                await _setNudges(event, false);
    }

    Future<void> nudges_on(dynamic caller, dynamic event) async {

                                await _setNudges(event, true);
    }

    // Tap sur le corps d'une relance envoyée par le serveur. Le message porte son motif
    // dans `data.motive` ; on n'en fait qu'une CHOSE : amener le joueur là où l'action
    // attendue se trouve. Aucun état n'est écrit ici — c'est le balayage qui tient les
    // compteurs, et il les remettra à zéro tout seul à la prochaine connexion.
    //
    // Le motif `validation` ne passe JAMAIS par ici : il porte trois boutons et se
    // résout sans ouvrir l'app (worker.on_notif_validate_*).
    Future<void> on_pulse_open(DvShape? caller, dynamic event) async {

                                final dv = event is Dvidle
                                    ? event
                                    : Dvidle(event is Map ? Map<String, dynamic>.from(event) : {});
                                final motive = _msgData(dv)["motive"]?.toString() ?? "";
                                deva_log("info", "[pulse] relance ouverte (motif=$motive)");

                                // `navigate_reset` et non `navigate_new` : ce sont des écrans à
                                // taskbar (page_taskbar), pas des écrans empilés. Les empiler
                                // laisserait une flèche « retour » vers rien du tout — l'app
                                // vient d'être ouverte par une notification, il n'y a pas d'écran
                                // précédent où revenir.
                                switch (motive) {
                                    // Le coffre, plein ou vide : c'est le même écran qui répond aux
                                    // deux (`testme`, l'écran des items — le coffre et sa bourse y
                                    // sont filtrés aux seuls admins, ce qui tombe juste : ces deux
                                    // motifs ne partent qu'aux chefs).
                                    case "chest_full":
                                    case "chest_empty":
                                        DvOrb.navigate_reset("testme");
                                        return;
                                    // Boss, onboarding, retour du clan : le dashboard est le point de
                                    // départ du parcours dans les trois cas — c'est de là qu'on entre
                                    // dans les domaines, et donc qu'on tombe sur la tâche promue.
                                    default:
                                        DvOrb.navigate_reset("dashboard");
                                        return;
                                }
    }

    // -----------------------------------------------------------------------
    // --- Validation admin d'une tâche "validating"
    // -----------------------------------------------------------------------

    // Notifie le joueur (assignee) du verdict, dans SA langue (stockée dans son doc membre clans_players).
    // key = combat_validate_ok | combat_validate_ko. Le texte est lu directement depuis le
    // store fusionné (toutes langues chargées) → pas de @@@T:@@@ (qui résoudrait dans la
    // langue de l'admin). Repli sur "fr" si la langue cible est absente.
    Future<void> _notifyAssignee(String clanId, String clanSecret, String region,
                                 String assignee, String key, String taskId) async {

                if (assignee.isEmpty || clanSecret.isEmpty) return;
                final pdoc = await _cloud?.read(
                    "workers", "clans_players/$clanId/players", assignee,
                    ownerId: clanSecret, region: region);
                if (pdoc == null) return;
                final lang    = pdoc.get("lang")?.toString() ?? "fr";
                final devices = List<dynamic>.from(
                    pdoc.get("devices") as List? ?? []);
                if (devices.isEmpty) {
                    deva_log("warning", "[combat] notify: aucun device pour $assignee");
                    return;
                }
                // Verdict (« Défi relevé ! » / « Raté... essaie encore. ») dans la langue du destinataire.
                var text = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                if (text.isEmpty) text = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                if (text.isEmpty) { deva_log("warning", "[combat] notify: traduction absente ($key/$lang)"); return; }

                // Intitulé de la tâche, traduit lui aussi dans la langue du destinataire (feuille →
                // dt_t_<id>, domaine → task_<id>). Format final : « [<intitulé>] -> <verdict> ».
                final titleKey = _leafTaskRe.hasMatch(taskId) ? "dt_t_$taskId" : "task_$taskId";
                var title = (await deva_get("lang.translations.$titleKey.$lang"))?.toString() ?? "";
                if (title.isEmpty) title = (await deva_get("lang.translations.$titleKey.fr"))?.toString() ?? "";
                if (title.isNotEmpty) text = "[$title] -> $text";

                final recipes = devices.map((d) => d.toString()).toList();
                deva_log("info", "[combat] notify → assignee=$assignee lang=$lang recipes=$recipes");
                try {
                    final result = await _messaging?.send(dvmsg(
                        range:   'global',
                        label:   text,
                        recipes: recipes,
                        // Action unique SANS label → pas de bouton : le tap sur le corps de la
                        // notif déclenche on_validation_resolved (premier plan via FLN, arrière-plan
                        // via onMessageOpenedApp). wakeup:true → l'app reste ouverte (on va au dashboard).
                        actions: {
                            'resolved': {
                                'action': 'worker.on_validation_resolved',
                                'wakeup': true,
                            },
                        },
                    ));
                    // 'sent' = nb de devices réellement poussés (FCM ou desktop) ; 'dead' = tokens périmés.
                    // sent=0 ⇒ aucun recipe trouvé dans msgregistry (mobile pas enregistré / sans token).
                    deva_log("info", "[combat] notif verdict envoyée à $assignee ($lang): $text"
                        " — status=${result?.get('status')} sent=${result?.get('sent')} dead=${result?.get('dead')}");
                } catch (e) {
                    deva_log("error", "[combat] notify assignee échec: $e");
                }
    }

    // Annonce l'arrivée d'un nouveau membre à tous les autres membres du clan.
    // Un envoi par membre (langue propre), notif texte simple (pas de bouton).
    // On saute l'arrivant lui-même (il a déjà son animation de bienvenue clan sur dashboard).
    // `list` renvoie déjà lang/devices par doc → pas de read supplémentaire. Les admins
    // sont un sous-ensemble des membres (doc clans_players) → couverts sans lire `admins`.
    Future<void> _notifyClanNewMember(String clanId, String clanSecret, String region,
                                      String newMemberId, String newMemberName) async {
        if (clanId.isEmpty || clanSecret.isEmpty) return;
        final name = newMemberName.isNotEmpty ? newMemberName : "un nouvel aventurier";
        try {
            final players = await _cloud?.list(
                "workers", "clans_players/$clanId/players", region: region) ?? [];
            for (final p in players) {
                final pid = p.get("id")?.toString() ?? "";
                if (pid.isEmpty || pid == newMemberId) continue;   // pas l'arrivant
                if (p.get("enabled") == false) continue;           // membre révoqué : pas de notif
                final lang    = p.get("lang")?.toString() ?? "fr";
                final devices = List<dynamic>.from(p.get("devices") as List? ?? [])
                    .map((d) => d.toString()).toList();
                if (devices.isEmpty) continue;

                var text = (await deva_get("lang.translations.new_member_notif.$lang"))?.toString() ?? "";
                if (text.isEmpty) text = (await deva_get("lang.translations.new_member_notif.fr"))?.toString() ?? "";
                if (text.isEmpty) continue;
                text = text.replaceAll("{name}", name);

                try {
                    final r = await _messaging?.send(dvmsg(
                        range: 'global', label: text, recipes: devices));
                    deva_log("info", "[worker] notif nouveau membre → $pid ($lang)"
                        " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                } catch (e) {
                    deva_log("error", "[worker] notif nouveau membre → $pid échec: $e");
                }
            }
        } catch (e) {
            deva_log("error", "[worker] _notifyClanNewMember FAILED: $e");
        }
    }

    // Notification au DESTINATAIRE, dans SA langue (même schéma que _notifyAssignee) :
    // « Prend bien soin de <objet> (signé <donneur>) ». Le libellé de l'objet est résolu dans la
    // même langue — son nom propre s'il en a un, sinon le libellé de son type. Destinataire sans
    // appareil (enfant sans compte) : rien à envoyer, le don a bien eu lieu quand même.
    Future<void> _notifyItemGift(Dvidle ctx, String targetId, String type, String name) async {

                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                if (targetId.isEmpty || clanSecret.isEmpty) return;
                                try {
                                    final pdoc = await _cloud?.read(
                                        "workers", "clans_players/$clanId/players", targetId,
                                        ownerId: clanSecret, region: region);
                                    if (pdoc == null) return;
                                    final lang    = pdoc.get("lang")?.toString() ?? "fr";
                                    final devices = List<dynamic>.from(pdoc.get("devices") as List? ?? []);
                                    if (devices.isEmpty) {
                                        deva_log("info", "[items] don: aucun device pour $targetId (pas de notif)");
                                        return;
                                    }

                                    // Traduction dans la langue du destinataire, repli fr. Surtout pas de
                                    // @@@T:…@@@ ici : il se résoudrait dans la langue de l'expéditeur.
                                    Future<String> tr(String key) async {
                                        var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                                        if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                                        return v;
                                    }

                                    var text = await tr("it_give_notif");
                                    if (text.isEmpty) {
                                        deva_log("warning", "[items] don: traduction it_give_notif absente");
                                        return;
                                    }
                                    var item = name;
                                    if (item.isEmpty && type.isNotEmpty) item = await tr("it_t_$type");
                                    final giver = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                    text = text.replaceAll("{item}", item).replaceAll("{name}", giver);

                                    final result = await _messaging?.send(dvmsg(
                                        range:   'global',
                                        label:   text,
                                        recipes: devices.map((d) => d.toString()).toList(),
                                    ));
                                    deva_log("info", "[items] notif don → $targetId ($lang) "
                                        "status=${result?.get('status')} sent=${result?.get('sent')} "
                                        "dead=${result?.get('dead')}");
                                } catch (e) {
                                    deva_log("error", "[items] _notifyItemGift FAILED: $e");
                                }
    }

    // Annonce à TOUT le clan (les autres admins compris) qu'un dépôt vient d'être fait, chacun
    // dans SA langue (lang.translations.<clé>.<lang>, repli fr — pas de @@@T:@@@, qui résoudrait
    // dans la langue de l'émetteur). Modèle : _notifyClanBoss, à deux différences près :
    //  - les destinataires sont regroupés PAR LANGUE (un envoi par langue, pas un par membre) :
    //    une famille de cinq coûte deux appels au lieu de quatre ;
    //  - les membres déclarés hors-device sont sautés, comme dans tous les agrégats du jeu.
    // `suffixKey` vide = message nu (aucun historique, ou dépôt dans la norme). `baseKey` couvre
    // le même canal pour un événement de coffre qui n'est pas un dépôt chiffrable — une note de
    // chef (chest_notif_note) : pas de verdict à annoncer, donc appelé avec suffixKey vide.
    Future<void> _notifyClanChest(String clanId, String region, String suffixKey,
                                  {String baseKey = "chest_notif"}) async {

                    if (clanId.isEmpty) return;
                    try {
                        final players = await _cloud?.list(
                            "workers", "clans_players/$clanId/players", region: region) ?? [];

                        // deviceIds à prévenir, groupés par langue de destinataire.
                        final byLang = <String, List<String>>{};
                        for (final p in players) {
                            final pid = p.get("id")?.toString() ?? "";
                            if (pid.isEmpty || pid == _userId) continue;     // pas celui qui dépose
                            if (p.get("enabled")    == false) continue;      // membre révoqué
                            if (p.get("has_device") == false) continue;      // déclaré hors ligne
                            final devices = List<dynamic>.from(p.get("devices") as List? ?? [])
                                .map((d) => d.toString()).where((d) => d.isNotEmpty).toList();
                            if (devices.isEmpty) continue;
                            final lang = p.get("lang")?.toString() ?? "fr";
                            (byLang[lang] ??= <String>[]).addAll(devices);
                        }
                        if (byLang.isEmpty) { deva_log("info", "[chest] aucun destinataire"); return; }

                        for (final entry in byLang.entries) {
                            final lang = entry.key;

                            Future<String> tr(String key) async {
                                var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                                if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                                return v;
                            }

                            var text = await tr(baseKey);
                            if (text.isEmpty) continue;                      // clef absente : on se tait
                            if (suffixKey.isNotEmpty) {
                                final suffix = await tr(suffixKey);
                                if (suffix.isNotEmpty) text = "$text $suffix";
                            }

                            try {
                                final r = await _messaging?.send(dvmsg(
                                    range: 'global', label: text, recipes: entry.value));
                                deva_log("info", "[chest] notif → ${entry.value.length} appareil(s) ($lang)"
                                    " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                            } catch (e) {
                                deva_log("error", "[chest] notif ($lang) échec: $e");
                            }
                        }
                    } catch (e) {
                        deva_log("error", "[chest] _notifyClanChest FAILED: $e");
                    }
    }

    // -----------------------------------------------------------------------
    // --- La fée : « XXX a rencontré une fée ! »
    // -----------------------------------------------------------------------
    //
    // C'est la SEULE notification de toute la fonctionnalité, et elle part APRÈS coup. Tant que la
    // fée est là, personne n'est prévenu de rien : la trouver EST la récompense, un push la
    // désignerait du doigt. Ce message ne dit donc pas qu'une fée est apparue — il dit qu'elle est
    // repartie, et avec qui.
    //
    // Il ne nomme pas non plus le cadeau reçu : c'est le journal du clan qui le raconte, à qui va
    // le lire. Un push qui annoncerait « +250 XP pour Léa » transformerait une jolie surprise en
    // bulletin de score.
    //
    // Regroupement PAR LANGUE, comme _notifyClanChest (et non un envoi par membre comme
    // _notifyClanBoss) : une famille de cinq coûte deux appels au lieu de quatre.
    //
    // Jamais fatale : le cadeau est DÉJÀ crédité quand on arrive ici. Un push raté ne doit pas se
    // lire comme un cadeau raté (même précaution que _notifyOpeningCall).
    Future<void> _notifyClanFairy(String clanId, String region, String name) async {

                    if (clanId.isEmpty) return;
                    try {
                        final players = await _cloud?.list(
                            "workers", "clans_players/$clanId/players", region: region) ?? [];

                        final byLang = <String, List<String>>{};
                        for (final p in players) {
                            final pid = p.get("id")?.toString() ?? "";
                            if (pid.isEmpty || pid == _userId) continue;     // pas celui qui l'a touchée
                            if (p.get("enabled")    == false) continue;      // membre révoqué
                            if (p.get("has_device") == false) continue;      // déclaré hors ligne
                            final devices = List<dynamic>.from(p.get("devices") as List? ?? [])
                                .map((d) => d.toString()).where((d) => d.isNotEmpty).toList();
                            if (devices.isEmpty) continue;
                            final lang = p.get("lang")?.toString() ?? "fr";
                            (byLang[lang] ??= <String>[]).addAll(devices);
                        }
                        if (byLang.isEmpty) { deva_log("info", "[fairy] aucun destinataire"); return; }

                        for (final entry in byLang.entries) {
                            final lang = entry.key;
                            var text = (await deva_get("lang.translations.fairy_notif.$lang"))?.toString() ?? "";
                            if (text.isEmpty) {
                                text = (await deva_get("lang.translations.fairy_notif.fr"))?.toString() ?? "";
                            }
                            if (text.isEmpty) continue;                      // clef absente : on se tait
                            text = text.replaceAll("{name}", name);

                            try {
                                final r = await _messaging?.send(dvmsg(
                                    range: 'global', label: text, recipes: entry.value));
                                deva_log("info", "[fairy] notif → ${entry.value.length} appareil(s) ($lang)"
                                    " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                            } catch (e) {
                                deva_log("error", "[fairy] notif ($lang) échec: $e");
                            }
                        }
                    } catch (e) {
                        deva_log("error", "[fairy] _notifyClanFairy FAILED: $e");
                    }
    }

    // Prévient le joueur payé, dans SA langue (même schéma que _notifyItemGift) : il a de l'argent
    // à réclamer, et le jeu ne peut pas le lui donner tout seul. Sans appareil (enfant sans
    // compte) : rien à envoyer, le versement a bien eu lieu.
    Future<void> _notifyTribute(String clanId, String clanSecret, String region,
                                String target, int amount) async {

                                if (target.isEmpty || clanSecret.isEmpty) return;
                                try {
                                    final pdoc = await _cloud?.read(
                                        "workers", "clans_players/$clanId/players", target,
                                        ownerId: clanSecret, region: region);
                                    if (pdoc == null) return;
                                    final lang    = pdoc.get("lang")?.toString() ?? "fr";
                                    final devices = List<dynamic>.from(pdoc.get("devices") as List? ?? []);
                                    if (devices.isEmpty) return;

                                    var text = (await deva_get("lang.translations.tribute_notif.$lang"))?.toString() ?? "";
                                    if (text.isEmpty) {
                                        text = (await deva_get("lang.translations.tribute_notif.fr"))?.toString() ?? "";
                                    }
                                    if (text.isEmpty) return;
                                    text = text.replaceAll("{amount}", "$amount");

                                    final result = await _messaging?.send(dvmsg(
                                        range:   'global',
                                        label:   text,
                                        recipes: devices.map((d) => d.toString()).toList(),
                                    ));
                                    deva_log("info", "[tribut] notif → $target ($lang) "
                                        "status=${result?.get('status')} sent=${result?.get('sent')}");
                                } catch (e) {
                                    deva_log("error", "[tribut] _notifyTribute FAILED: $e");
                                }
    }

    // Annonce la montée de niveau à tous les AUTRES membres du clan (le joueur qui monte a l'animation,
    // pas la notif). Un envoi par membre, dans SA langue (lang.translations.<clé>.<lang>, repli fr) —
    // pas de @@@T:@@@ qui résoudrait dans la langue de l'émetteur (cf. _notifyAssignee). Modèle :
    // _notifyClanNewMember. `list` fournit déjà lang/devices par doc → pas de read supplémentaire.
    Future<void> _notifyClanLevelUp(String clanId, String clanSecret, String region,
                                    String levelerName, bool gotTitle, int titleIdx) async {

                if (clanId.isEmpty || clanSecret.isEmpty) return;
                final name = levelerName.isNotEmpty ? levelerName : "Un aventurier";
                try {
                    final players = await _cloud?.list(
                        "workers", "clans_players/$clanId/players", region: region) ?? [];
                    for (final p in players) {
                        final pid = p.get("id")?.toString() ?? "";
                        if (pid.isEmpty || pid == _userId) continue;   // pas le joueur qui monte
                        if (p.get("enabled") == false) continue;       // membre révoqué : pas de notif
                        final lang    = p.get("lang")?.toString() ?? "fr";
                        final devices = List<dynamic>.from(p.get("devices") as List? ?? [])
                            .map((d) => d.toString()).toList();
                        if (devices.isEmpty) continue;

                        Future<String> tr(String key) async {
                            var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                            if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                            return v;
                        }

                        var text = gotTitle ? await tr("levelup_notif_title") : await tr("levelup_notif");
                        if (text.isEmpty) continue;
                        text = text.replaceAll("{name}", name);
                        if (gotTitle) text = text.replaceAll("{title}", await tr("player_title_$titleIdx"));

                        try {
                            final r = await _messaging?.send(dvmsg(
                                range: 'global', label: text, recipes: devices));
                            deva_log("info", "[levelup] notif → $pid ($lang)"
                                " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                        } catch (e) {
                            deva_log("error", "[levelup] notif → $pid échec: $e");
                        }
                    }
                } catch (e) {
                    deva_log("error", "[levelup] _notifyClanLevelUp FAILED: $e");
                }
    }

    // Notifie les admins du clan qu'un joueur demande la validation d'une tâche.
    // Un envoi PAR admin (langue + devices propres au destinataire). Payload métier
    // (data) = clan + tâche + demandeur, lu par le handler.
    //
    // DEUX FORMES, selon que le clan cotise ou non.
    //
    // Clan ABONNÉ — 3 boutons (valider / à moitié / refuser) mappés sur
    // on_notif_validate_* et mode:'noorb' : app fermée, le tap relance l'app sans UI
    // (mode restreint), exécute le verdict, puis s'arrête (wakeup=false). C'est le
    // confort du produit : arbitrer sans ouvrir quoi que ce soit.
    //
    // Clan SANS COTISATION — une action unique et sans libellé, donc aucun bouton, et
    // le tap sur le corps ouvre l'app sur la tâche à valider. C'est délibéré et c'est
    // le seul levier du genre dans le jeu : les trois boutons résolvaient la
    // validation SANS jamais ouvrir l'app, donc sans jamais amener le chef devant
    // quoi que ce soit. Un chef qui n'ouvre pas l'app ne verra jamais ni la page des
    // paliers, ni le mur. Ils reviennent dès qu'une cotisation est active.
    Future<void> _notifyAdmins(String clanId, String clanSecret, String region,
                               String taskId, String requester, String requesterName) async {

                if (clanId.isEmpty || clanSecret.isEmpty || taskId.isEmpty) return;

                final clanDoc = await _cloud?.read("workers", "clans", clanId,
                    ownerId: clanSecret, region: region);
                final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? [])
                    .map((a) => a.toString()).where((a) => a.isNotEmpty).toList();
                if (admins.isEmpty) { deva_log("info", "[combat] notif admins: aucun admin"); return; }

                // Lu UNE fois, hors de la boucle : la cotisation est un fait du CLAN, pas
                // du destinataire. Et lu ici, sur l'appareil du JOUEUR qui vient de finir
                // sa tâche — souvent celui d'un enfant. Il le sait : la projection
                // `clans_store` a pour portée le clan, tout membre la lit (cf. store_scope).
                //
                // Défaut sûr si l'état n'est pas connu : PAS de boutons. _storeSubscribed
                // rend faux sur une clef absente, ce qui est exactement ce qu'on veut — se
                // tromper dans ce sens coûte un tap de plus, jamais un droit refusé.
                final subscribed = await _storeSubscribed();

                final titleKey = _leafTaskRe.hasMatch(taskId) ? "dt_t_$taskId" : "task_$taskId";
                final data     = {"clanId": clanId, "taskId": taskId, "assignee": requester};

                for (final adminId in admins) {
                    if (adminId == requester) continue;   // un admin ne se notifie pas lui-même
                    final pdoc = await _cloud?.read(
                        "workers", "clans_players/$clanId/players", adminId,
                        ownerId: clanSecret, region: region);
                    if (pdoc == null) continue;
                    final lang    = pdoc.get("lang")?.toString() ?? "fr";
                    final devices = List<dynamic>.from(pdoc.get("devices") as List? ?? [])
                        .map((d) => d.toString()).toList();
                    if (devices.isEmpty) continue;

                    // Traduction dans la langue de l'admin (repli fr, puis repli littéral).
                    Future<String> tr(String key) async {
                        var v = (await deva_get("lang.translations.$key.$lang"))?.toString() ?? "";
                        if (v.isEmpty) v = (await deva_get("lang.translations.$key.fr"))?.toString() ?? "";
                        return v;
                    }

                    final title = await tr(titleKey);
                    // La tête annonce ce qu'on peut FAIRE, et les deux formes ne proposent
                    // pas la même chose : avec boutons on arbitre sur place, sans boutons il
                    // faut toucher le bandeau. Le dire est indispensable — une notification
                    // muette et sans bouton a l'air cassée.
                    var head = await tr(subscribed ? "notif_validate_request"
                                                   : "notif_validate_request_open");
                    if (head.isEmpty) head = subscribed ? "demande la validation"
                                                        : "demande une validation — touchez pour l'ouvrir";

                    final label = title.isNotEmpty
                        ? "[$title] $requesterName $head"
                        : "$requesterName $head";

                    Map<String, dynamic> actions;
                    if (subscribed) {
                        var okL   = await tr("notif_validate_ok");      if (okL.isEmpty)   okL   = "Valider";
                        var halfL = await tr("notif_validate_partial"); if (halfL.isEmpty) halfL = "À moitié";
                        var koL   = await tr("notif_validate_ko");      if (koL.isEmpty)   koL   = "Refuser";
                        actions = {
                            "v_ok":      {"action": "worker.on_notif_validate_ok",      "label": okL,   "wakeup": false},
                            "v_partial": {"action": "worker.on_notif_validate_partial", "label": halfL, "wakeup": false},
                            "v_ko":      {"action": "worker.on_notif_validate_ko",      "label": koL,   "wakeup": false},
                        };
                    } else {
                        // UNE action, SANS libellé : c'est la seule forme où dvmessaging
                        // déclenche quelque chose au tap du CORPS de la notification. Un
                        // bouton n'est rendu que si l'action porte un `label`, et avec deux
                        // actions ou plus le tap corps est SANS EFFET — une action sans
                        // libellé y serait tout bonnement injoignable. Modèle : _notifyAssignee.
                        actions = {
                            "open": {"action": "worker.on_notif_open_task", "wakeup": true},
                        };
                    }

                    try {
                        final result = await _messaging?.send(dvmsg(
                            range:   'global',
                            label:   label,
                            recipes: devices,
                            // `noorb` déclare `orb.idle`, donc EMPÊCHE runApp() : l'app se
                            // relance sans interface. C'est ce qu'il faut pour rendre un
                            // verdict et s'éteindre ; c'est l'exact contraire de ce qu'il faut
                            // pour OUVRIR un écran. Il doit donc tomber avec les boutons.
                            // `dvmsg` déclare `String? mode` : null fait disparaître la clef.
                            mode:    subscribed ? 'noorb' : null,
                            data:    data,
                            actions: actions,
                        ));
                        deva_log("info", "[combat] notif admin → $adminId ($lang): $label"
                            " — sent=${result?.get('sent')} dead=${result?.get('dead')}");
                    } catch (e) {
                        deva_log("error", "[combat] notif admin $adminId échec: $e");
                    }
                }
    }

    // Relance de cotisation impayée, envoyée aux CHEFS du clan.
    //
    // En production c'est le balayage quotidien du serveur qui l'envoie, et ce doit
    // rester lui : un clan en défaut est justement un clan que plus personne n'ouvre,
    // aucun client ne peut donc garantir le départ de la relance. Cette version-ci ne
    // sert qu'au BANC D'ESSAI — elle rejoue l'envoi à la demande, avec le même texte
    // et par le même canal, pour qu'on puisse constater ce qu'une famille recevra
    // sans attendre le passage de 5 h du matin.
    //
    // Les textes viennent de lang.yml (embarqué) et non du thème : c'est ce qui rend
    // la relance lisible même quand le layer du bucket est en retard.
    //
    // Soi-même INCLUS, contrairement aux autres notifications du fichier : celui qui
    // actionne le banc est justement celui qui doit recevoir le message.
    Future<void> _notifyDunning(String clanId, String clanSecret, String region,
                                String phase) async {

                    if (clanId.isEmpty || clanSecret.isEmpty || phase.isEmpty) return;
                    try {
                        final clanDoc = await _cloud?.read("workers", "clans", clanId,
                            ownerId: clanSecret, region: region);
                        final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? [])
                            .map((a) => a.toString()).where((a) => a.isNotEmpty).toList();
                        if (admins.isEmpty) { deva_log("info", "[store] relance: aucun chef"); return; }

                        for (final adminId in admins) {
                            final pdoc = await _cloud?.read(
                                "workers", "clans_players/$clanId/players", adminId,
                                ownerId: clanSecret, region: region);
                            if (pdoc == null) continue;
                            final lang    = pdoc.get("lang")?.toString() ?? "fr";
                            final devices = List<dynamic>.from(pdoc.get("devices") as List? ?? [])
                                .map((d) => d.toString()).toList();
                            if (devices.isEmpty) continue;

                            var text = (await deva_get("lang.translations.store_dunning_$phase.$lang"))?.toString() ?? "";
                            if (text.isEmpty) {
                                text = (await deva_get("lang.translations.store_dunning_$phase.fr"))?.toString() ?? "";
                            }
                            if (text.isEmpty) continue;

                            try {
                                // Action sans libellé = convention tap-corps (cf. _notifyAssignee) :
                                // toucher le bandeau ouvre la boutique, exactement comme le fera la
                                // relance du serveur.
                                final r = await _messaging?.send(dvmsg(
                                    range:   'global',
                                    label:   text,
                                    recipes: devices,
                                    actions: {"open": {"action": "worker.store_open_subscription"}},
                                ));
                                deva_log("info", "[store] relance $phase → $adminId ($lang)"
                                    " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                            } catch (e) {
                                deva_log("error", "[store] relance → $adminId échec: $e");
                            }
                        }
                    } catch (e) {
                        deva_log("error", "[store] _notifyDunning FAILED: $e");
                    }
    }

    // Informe les AUTRES membres du clan qu'un joueur est devenu chef (« {name} a prouvé sa valeur… »).
    // Le promu, lui, n'est PAS notifié : il a l'animation "burn" jouée localement par sa propre
    // vigilance (_checkChiefPromotion), déclenchée par le miroir is_admin posé sur son doc. Un envoi
    // par membre dans sa langue (lang.translations.<clé>.<lang>, repli fr), en sautant promoteur et
    // promu. Modèle : _notifyClanNewMember / _notifyClanLevelUp.
    Future<void> _notifyChiefPromotion(String clanId, String clanSecret, String region,
                                       String promotedId, String promotedName) async {

                if (clanId.isEmpty || clanSecret.isEmpty || promotedId.isEmpty) return;
                final name = promotedName.isNotEmpty ? promotedName : "Un aventurier";

                try {
                    final players = await _cloud?.list(
                        "workers", "clans_players/$clanId/players", region: region) ?? [];
                    for (final p in players) {
                        final pid = p.get("id")?.toString() ?? "";
                        if (pid.isEmpty || pid == _userId || pid == promotedId) continue;
                        if (p.get("enabled") == false) continue;       // membre révoqué : pas de notif
                        final lang    = p.get("lang")?.toString() ?? "fr";
                        final devices = List<dynamic>.from(p.get("devices") as List? ?? [])
                            .map((d) => d.toString()).toList();
                        if (devices.isEmpty) continue;

                        var text = (await deva_get("lang.translations.promote_chief_clan.$lang"))?.toString() ?? "";
                        if (text.isEmpty) text = (await deva_get("lang.translations.promote_chief_clan.fr"))?.toString() ?? "";
                        if (text.isEmpty) continue;
                        text = text.replaceAll("{name}", name);

                        try {
                            final r = await _messaging?.send(dvmsg(
                                range: 'global', label: text, recipes: devices));
                            deva_log("info", "[roster] notif promo clan → $pid ($lang)"
                                " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                        } catch (e) {
                            deva_log("error", "[roster] notif promo clan → $pid échec: $e");
                        }
                    }
                } catch (e) {
                    deva_log("error", "[roster] notif promo (clan) FAILED: $e");
                }
    }

    // Prévient TOUT le clan (sauf l'admin qui recommande) qu'un « boss » vient d'apparaître. Un envoi
    // par membre dans sa langue (lang.translations.boss_notif.<lang>, repli fr), en sautant soi-même
    // et les membres révoqués. Modèle : _notifyChiefPromotion / _notifyClanNewMember.
    Future<void> _notifyClanBoss(String clanId, String clanSecret, String region) async {

                    if (clanId.isEmpty || clanSecret.isEmpty) return;
                    try {
                        final players = await _cloud?.list(
                            "workers", "clans_players/$clanId/players", region: region) ?? [];
                        for (final p in players) {
                            final pid = p.get("id")?.toString() ?? "";
                            if (pid.isEmpty || pid == _userId) continue;    // pas soi-même
                            if (p.get("enabled") == false) continue;        // membre révoqué : pas de notif
                            final lang    = p.get("lang")?.toString() ?? "fr";
                            final devices = List<dynamic>.from(p.get("devices") as List? ?? [])
                                .map((d) => d.toString()).toList();
                            if (devices.isEmpty) continue;

                            var text = (await deva_get("lang.translations.boss_notif.$lang"))?.toString() ?? "";
                            if (text.isEmpty) text = (await deva_get("lang.translations.boss_notif.fr"))?.toString() ?? "";
                            if (text.isEmpty) continue;

                            try {
                                final r = await _messaging?.send(dvmsg(
                                    range: 'global', label: text, recipes: devices));
                                deva_log("info", "[boss] notif → $pid ($lang)"
                                    " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                            } catch (e) {
                                deva_log("error", "[boss] notif → $pid échec: $e");
                            }
                        }
                    } catch (e) {
                        deva_log("error", "[boss] _notifyClanBoss FAILED: $e");
                    }
    }

    // -----------------------------------------------------------------------
    // --- Cérémonie du butin : le push, canal principal
    // -----------------------------------------------------------------------
    //
    // La cérémonie se joue à plusieurs appareils, et rien ne garantit qu'ils soient tous allumés,
    // ouverts sur l'app et regardés. Une vigilance dvcloud ne réveille QUE ce qui tourne déjà ;
    // c'est le push qui va chercher le téléphone posé sur la table. Il passe donc devant, et les
    // vigilances ne restent qu'en filet.
    //
    // Les messages d'appel et d'ouverture partagent la même forme : un `label` (le bandeau que
    // verra celui dont l'app est fermée), UNE action sans libellé (convention tap-corps, cf.
    // _notifyAssignee) et `foreground: 'silent'`. Un seul envoi couvre ainsi les trois états de
    // l'app — écran empilé tout seul si elle est ouverte, bandeau tapable sinon.

    // ① Le meneur appelle le clan. `players` est la liste DÉJÀ lue par on_opening_ready : aucune
    // relecture. `called` en désigne les seuls destinataires — le meneur ne s'appelle pas lui-même,
    // et on ne dérange pas ceux qu'on n'attend pas (révoqués, sans appareil).
    // Jamais fatale : l'appel est DÉJÀ écrit quand on arrive ici. Une notification qui échoue ne
    // doit pas se lire comme un appel raté — le meneur perdrait sa cérémonie pour un bandeau.
    Future<void> _notifyOpeningCall(List<Dvidle> players, Set<String> called) async {

                    if (called.isEmpty) return;
                    try {
                        for (final p in players) {
                            final pid = p.get("id")?.toString() ?? "";
                            if (!called.contains(pid)) continue;
                            final lang    = p.get("lang")?.toString() ?? "fr";
                            final devices = List<dynamic>.from(p.get("devices") as List? ?? [])
                                .map((d) => d.toString()).toList();
                            if (devices.isEmpty) continue;

                            var text = (await deva_get("lang.translations.opening_notif.$lang"))?.toString() ?? "";
                            if (text.isEmpty) text = (await deva_get("lang.translations.opening_notif.fr"))?.toString() ?? "";
                            if (text.isEmpty) continue;

                            try {
                                final r = await _messaging?.send(dvmsg(
                                    range:      'global',
                                    label:      text,
                                    recipes:    devices,
                                    foreground: 'silent',
                                    actions:    {
                                        'open': {'action': 'worker.on_opening_called', 'wakeup': true},
                                    },
                                ));
                                deva_log("info", "[opening] notif appel → $pid ($lang)"
                                    " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                            } catch (e) {
                                deva_log("error", "[opening] notif appel → $pid échec: $e");
                            }
                        }
                    } catch (e) {
                        deva_log("error", "[opening] _notifyOpeningCall FAILED: $e");
                    }
    }

    // ② Le joueur annonce sa réponse au meneur. Message VRAIMENT silencieux (pas de `label`) :
    // le meneur a les yeux sur sa liste d'attente, un bandeau serait du bruit. S'il a quitté
    // l'écran, le message ne fait rien — mais ses vigilances, elles, tournent toujours.
    // Sans `opening_master` (cérémonie d'avant cette version), on n'envoie rien : même filet.
    Future<void> _notifyOpeningReady(String clanId, String clanSecret, String region) async {

                    if (_openingMaster.isEmpty || _openingMaster == _userId) return;
                    try {
                        final m = await _cloud?.read("workers", "clans_players/$clanId/players",
                            _openingMaster, ownerId: clanSecret, region: region);
                        final devices = List<dynamic>.from(m?.get("devices") as List? ?? [])
                            .map((d) => d.toString()).toList();
                        if (devices.isEmpty) return;

                        final r = await _messaging?.send(dvmsg(
                            range:   'global',
                            recipes: devices,
                            data:    {"playerId": _userId},
                            actions: {
                                'ready': {'action': 'worker.on_opening_player_ready', 'wakeup': true},
                            },
                        ));
                        deva_log("info", "[opening] notif prêt → meneur $_openingMaster"
                            " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                    } catch (e) {
                        deva_log("error", "[opening] notif prêt → meneur échec: $e");
                    }
    }

    // ③ Le coffre est ouvert : chacun a une part qui l'attend. `served` sont les joueurs du partage
    // (le révoqué en est absent), meneur compris — sa part le concerne comme les autres, et son
    // app se l'annonce à elle-même sans que ça coûte quoi que ce soit.
    // Jamais fatale non plus : les parts sont écrites, le reste de la distribution (miroir des
    // items, réclamation du meneur) doit se dérouler même si aucun bandeau ne part.
    Future<void> _notifyButinReady(List<Dvidle> players, Set<String> served) async {

                    if (served.isEmpty) return;
                    try {
                        for (final p in players) {
                            final pid = p.get("id")?.toString() ?? "";
                            if (!served.contains(pid) || pid == _userId) continue;
                            final lang    = p.get("lang")?.toString() ?? "fr";
                            final devices = List<dynamic>.from(p.get("devices") as List? ?? [])
                                .map((d) => d.toString()).toList();
                            if (devices.isEmpty) continue;

                            var text = (await deva_get("lang.translations.butin_notif.$lang"))?.toString() ?? "";
                            if (text.isEmpty) text = (await deva_get("lang.translations.butin_notif.fr"))?.toString() ?? "";
                            if (text.isEmpty) continue;

                            try {
                                final r = await _messaging?.send(dvmsg(
                                    range:      'global',
                                    label:      text,
                                    recipes:    devices,
                                    foreground: 'silent',
                                    actions:    {
                                        'claim': {'action': 'worker.on_butin_ready', 'wakeup': true},
                                    },
                                ));
                                deva_log("info", "[butin] notif ouverture → $pid ($lang)"
                                    " — sent=${r?.get('sent')} dead=${r?.get('dead')}");
                            } catch (e) {
                                deva_log("error", "[butin] notif ouverture → $pid échec: $e");
                            }
                        }
                    } catch (e) {
                        deva_log("error", "[butin] _notifyButinReady FAILED: $e");
                    }
    }

    // Réception de l'appel du meneur (notif ①). Le message dit seulement qu'il s'est passé quelque
    // chose ; c'est la base qui dit quoi. On repasse donc par la relecture habituelle, avec ses
    // gardes — un joueur déjà dans la cérémonie ne s'y fait pas empiler deux fois.
    Future<void> on_opening_called(DvShape? caller, dynamic event) async {

                                deva_log("info", "[opening] notif d'appel reçue");
                                await _checkPendingOpening();
    }

    // Réception d'une réponse de joueur (notif ②) : la coche verte, sans attendre la vigilance.
    Future<void> on_opening_player_ready(DvShape? caller, dynamic event) async {

                                if (_openingRole != "master") return;
                                final dv = event is Dvidle
                                    ? event
                                    : Dvidle(event is Map ? Map<String, dynamic>.from(event) : {});
                                final pid = _msgData(dv)["playerId"]?.toString() ?? "";
                                if (pid.isEmpty) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                deva_log("info", "[opening] notif : $pid est prêt");
                                await _markOpeningReady(pid, ctx.get("clanId").toString());
    }

    // Réception de l'ouverture du coffre (notif ③) : la part est réclamée, puis l'animation part.
    Future<void> on_butin_ready(DvShape? caller, dynamic event) async {

                                deva_log("info", "[butin] notif d'ouverture reçue");
                                await _checkPendingButin();
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
