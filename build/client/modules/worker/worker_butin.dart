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
// --- worker extension — Coffre du butin & cérémonie
// -----------------------------------------------------------------------------
extension Worker_butin on worker {

    void _register_butin() {

                                // Coffre du butin : dépôt d'un item, les trois options du coffre, et
                                // l'écran de contenu (liste du contenu).
                                ActionRegistry.register("worker.item_to_butin",             item_to_butin);

                                ActionRegistry.register("worker.butin_show",                butin_show);

                                ActionRegistry.register("worker.on_butin_page_appear",      on_butin_page_appear);

                                ActionRegistry.register("worker.on_butin_row_tap",          on_butin_row_tap);

                                ActionRegistry.register("worker.on_butin_ok",               on_butin_ok);

                                // Note du coffre : un chef y dépose un mot lu par tout le clan à la
                                // prochaine ouverture — secret jusque-là, y compris des autres chefs.
                                ActionRegistry.register("worker.item_note",                 item_note);

                                ActionRegistry.register("worker.on_butin_note_appear",      on_butin_note_appear);

                                ActionRegistry.register("worker.on_butin_note_ok",          on_butin_note_ok);

                                // Ouverture du butin. Cérémonie : le coffre doré de l'écran Clan (prise du
                                // verrou), l'écran de rituel partagé maître/joueurs, son bouton et le tap
                                // sur une ligne d'attente. Puis réception : révélation de l'écran de
                                // récompenses au bon acte de l'animation, et affichage de la part.
                                ActionRegistry.register("worker.on_butin_open_tap",         on_butin_open_tap);

                                ActionRegistry.register("worker.on_opening_appear",         on_opening_appear);

                                ActionRegistry.register("worker.on_opening_ready",          on_opening_ready);

                                ActionRegistry.register("worker.on_opening_row_tap",        on_opening_row_tap);

                                ActionRegistry.register("worker.butin_reveal",              butin_reveal);

                                ActionRegistry.register("worker.on_butin_rewards_appear",   on_butin_rewards_appear);

                                ActionRegistry.register("worker.on_butin_rewards_ok",       on_butin_rewards_ok);

                                // Notes des chefs, révélées après la part de chacun : lecture forcée
                                // (10 s) avant de laisser filer vers le conte.
                                ActionRegistry.register("worker.on_butin_notes_appear",     on_butin_notes_appear);

                                ActionRegistry.register("worker.on_butin_notes_ok",         on_butin_notes_ok);

                                ActionRegistry.register("worker.on_butin_tale_ok",          on_butin_tale_ok);

                                ActionRegistry.register("worker.on_butin_tale_share",       on_butin_tale_share);

    }

    // Contexte clan de l'écran (région + identifiants) : les actions du coffre en ont toutes
    // besoin. Renvoie null si la session n'est pas exploitable (rien à faire, alors).
    Future<Dvidle?> _butinCtx() async {

                                final region     = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final session    = await _readSession(region);
                                final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) return null;
                                return Dvidle({"region": region, "clanId": clanId, "clanSecret": clanSecret});
    }

    // Crée le coffre et le portefeuille s'ils manquent, à partir de la liste DÉJÀ faite des
    // documents du clan (aucune lecture supplémentaire, et pas de `read` sur un document absent —
    // les règles Firestore refusent un `get` dont le document n'existe pas encore).
    // Renvoie la liste augmentée des documents créés, pour que l'appelant les affiche du même
    // coup. Appelée à l'ouverture de l'écran Items (rattrape les clans nés avant le coffre) ET
    // à la création d'un clan, avec une liste vide.
    Future<List<Dvidle>> _ensureButinDocs(String clanId, String clanSecret, String region,
                                          List<Dvidle> docs) async {

                            if (clanId.isEmpty || clanSecret.isEmpty) return docs;
                            final ids = docs
                                .map((d) => d.get("docId")?.toString() ?? "")
                                .where((id) => id.isNotEmpty)
                                .toSet();
                            final out = List<Dvidle>.from(docs);
                            try {
                                // Le coffre appartient au CLAN : la règle de visibilité existante le
                                // réserve donc aux admins, sans traitement particulier.
                                if (!ids.contains(_butinDocId)) {
                                    out.add(await _writeButinDoc(clanId, clanSecret, region,
                                        _butinDocId, "butin", clanId, null));
                                    deva_log("info", "[butin] coffre créé pour $clanId");
                                }
                                // Le portefeuille naît DANS le coffre, vide. Il n'est jamais supprimé,
                                // même à 0 : c'est un meuble du coffre, pas un objet qu'on y range.
                                if (!ids.contains(_walletDocId)) {
                                    out.add(await _writeButinDoc(clanId, clanSecret, region,
                                        _walletDocId, "argent_poche", _butinOwner, 0));
                                    deva_log("info", "[butin] portefeuille créé pour $clanId");
                                }
                            } catch (e) {
                                deva_log("error", "[butin] _ensureButinDocs FAILED: $e");
                            }
                            return out;
    }

    // Écrit un document d'item et le renvoie tel que le verrait `list` (docId compris). Créateur
    // « nu » unique de tout item du jeu (butin, portefeuilles, titres...) — pas seulement du
    // butin malgré son nom historique. `ownerId = clanSecret` est exigé par les règles de
    // clans_items. `titleIdx` : rang du titre porté par CET item (absent pour tout autre type).
    Future<Dvidle> _writeButinDoc(String clanId, String clanSecret, String region,
                                  String docId, String type, String owner, int? quantity,
                                  {int? titleIdx}) async {

                            final doc = Dvidle({});
                            doc.set("ownerId", clanSecret);
                            doc.set("type",    type);
                            doc.set("owner",   owner);
                            if (quantity != null)  doc.set("quantity",  quantity);
                            if (titleIdx != null)  doc.set("title_idx", titleIdx);
                            await _cloud?.write("workers", "clans_items/$clanId/items", docId, doc,
                                region: region, ownerId: clanSecret);
                            doc.set("docId", docId);
                            return doc;
    }

    // Dépôt d'un item sur le coffre (joker `drops` du type `butin`) : l'item passe dans le butin.
    Future<void> item_to_butin(dynamic caller, dynamic event) async {

                                final data   = (event is Map) ? event : const {};
                                final itemId = data["source_id"]?.toString() ?? "";
                                if (itemId.isEmpty) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                try {
                                    // Valeur de l'objet lue AVANT tout le reste : `event` ne porte que
                                    // source_id/source_type, le coût vit sur le document de l'item.
                                    final cost = _itemCostOf(_mirrorDoc(itemId));

                                    await _setItemOwner(ctx, itemId, _butinOwner);
                                    deva_log("info", "[butin] '$itemId' (${data["source_type"]}) déposé dans le coffre");
                                    // Miroir d'abord : la tuile disparaît à l'instant, sans le temps d'une
                                    // relecture de la collection. On ne relit que si le miroir ne connaît
                                    // pas l'item (grille jamais chargée) — mieux vaut lent que faux.
                                    if (_patchLocalItem(itemId, owner: _butinOwner)) {
                                        _pushClanItems();
                                    } else {
                                        await _loadClanItems(ctx.get("clanId").toString(),
                                            ctx.get("clanSecret").toString(), ctx.get("region").toString());
                                    }
                                    // La tuile a disparu : le clan peut être prévenu (le récit vient après
                                    // le geste, et n'a pas le droit de le faire échouer).
                                    await _announceChestDeposit(ctx, value: cost, field: "cost");
                                } catch (e) {
                                    deva_log("error", "[butin] item_to_butin FAILED: $e");
                                }
    }

    // Porte d'entrée du coffre : action de l'option `item_open` (menu du coffre) — rejouée
    // telle quelle par item_view_page quand « Voir » a été choisi avant « Appliquer ».
    Future<void> butin_show(dynamic caller, dynamic event) async {

                                DvOrb.navigate_new("butin_page");
    }

    // Apparition de l'écran : on repart d'un brouillon vierge et on relit le coffre.
    Future<void> on_butin_page_appear(dynamic caller, dynamic event) async {

                                _butinTaken.clear();
                                _butinMoneyAdd = 0;
                                try {
                                    // La liste est toujours visible : la version précédente de l'écran la
                                    // masquait dans un de ses modes, et cette bascule a pu être persistée
                                    // dans le registre d'un appareil. On la remet d'aplomb (diff : sans
                                    // effet quand elle l'est déjà).
                                    await _syncVisible(await DvOrb.wait_for_shape("butin_page/list"),
                                        "butin_page/list", true);
                                    await _loadButinRows();
                                } catch (e) {
                                    deva_log("error", "[butin] on_butin_page_appear FAILED: $e");
                                }
    }

    // Contenu du coffre → DvList. Une ligne par item, le portefeuille toujours en tête (il ne
    // bouge pas, on sait où le trouver). Nom et description viennent du CATALOGUE de types
    // (résolus dans la langue courante), le nom propre du document l'emporte s'il y en a un.
    Future<void> _loadButinRows() async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                try {
                                    final clanId = ctx.get("clanId").toString();
                                    final docs   = await _cloud?.list("workers", "clans_items/$clanId/items",
                                        region: ctx.get("region").toString()) ?? [];

                                    final rows = <Map<String, dynamic>>[];
                                    Map<String, dynamic>? wallet;
                                    // Mes propres notes, s'il y en a — un chef peut en déposer plusieurs.
                                    // Portées par le document `butin` lui-même (champ `notes`), pas par un
                                    // item du coffre — capturées à part, ce doc n'a ni owner==_butinOwner
                                    // ni id==_walletDocId.
                                    final myNotes = <Map<String, String>>[];

                                    for (final d in docs) {
                                        final id = d.get("docId")?.toString() ?? "";
                                        if (id.isEmpty) continue;
                                        if (id == _butinDocId) {
                                            final notes = d.get("notes");
                                            if (notes is List) {
                                                for (final n in notes) {
                                                    if (n is! Dvidle) continue;
                                                    if ((n.get("author")?.toString() ?? "") != _userId) continue;
                                                    final noteId = n.get("id")?.toString() ?? "";
                                                    if (noteId.isEmpty) continue;   // note malformée : ignorée à l'affichage
                                                    myNotes.add({
                                                        "id":   noteId,
                                                        "text": n.get("text")?.toString() ?? "",
                                                    });
                                                }
                                            }
                                            continue;
                                        }
                                        if ((d.get("owner")?.toString() ?? "") != _butinOwner) continue;

                                        final type     = d.get("type")?.toString() ?? "";
                                        final qty      = int.tryParse(d.get("quantity")?.toString() ?? "1") ?? 1;
                                        final name     = d.get("name")?.toString() ?? "";
                                        final isWallet = id == _walletDocId;

                                        final image = (await deva_get("items.$type.image"))?.toString() ?? "";
                                        final label = TranslationRegistry.processLabel(
                                            (await deva_get("items.$type.label"))?.toString() ?? "");
                                        final desc  = TranslationRegistry.processLabel(
                                            (await deva_get("items.$type.description"))?.toString() ?? "");

                                        final row = <String, dynamic>{
                                            "id":       id,
                                            "type":     type,
                                            "quantity": qty,
                                            "image":    image,
                                            "label":    name.isNotEmpty ? name : label,
                                            "desc":     desc,
                                            // Détermine l'icône d'action posée par _pushButinRows (kind
                                            // "wallet" → +, "item" → X/coche, "note"/"add_note" → +/X fixes).
                                            "kind":     isWallet ? "wallet" : "item",
                                        };
                                        if (isWallet) { wallet = row; } else { rows.add(row); }
                                    }

                                    // La bourse en tête : elle ne bouge jamais, on sait où la trouver. Puis
                                    // « Ajouter une note », TOUJOURS proposée (pas besoin d'en avoir déjà
                                    // une). Puis mes notes existantes, une ligne par note — visibles de moi
                                    // seul (le document ne liste QUE mon propre auteur, cf. la boucle
                                    // ci-dessus) — et enfin les objets.
                                    if (wallet != null) rows.insert(0, wallet);
                                    var insertAt = wallet != null ? 1 : 0;
                                    rows.insert(insertAt, <String, dynamic>{
                                        "id":       _addNoteRowId,
                                        "type":     "",
                                        "quantity": 0,
                                        "image":    "images/small/scroll_nobg.png",
                                        "label":    TranslationRegistry.processLabel("@@@T:butin_note_add_label@@@"),
                                        "desc":     "",
                                        "kind":     "add_note",
                                    });
                                    insertAt++;
                                    final noteLabel = TranslationRegistry.processLabel("@@@T:butin_note_row_label@@@");
                                    for (final n in myNotes) {
                                        rows.insert(insertAt++, <String, dynamic>{
                                            "id":       "$_noteRowPrefix${n["id"]}",
                                            "type":     "",
                                            "quantity": 0,
                                            "image":    "images/small/scroll_nobg.png",
                                            "label":    noteLabel,
                                            "desc":     n["text"],
                                            "kind":     "note",
                                        });
                                    }
                                    _butinRows = rows;
                                    _pushButinRows();
                                    deva_log("info", "[butin] ${rows.length} ligne(s) dans le coffre");
                                } catch (e) {
                                    deva_log("error", "[butin] _loadButinRows FAILED: $e");
                                }
    }

    // Affiche les lignes en leur appliquant le BROUILLON (bourse à la somme promise) et l'icône
    // d'action qui dit CE QUE fait le tap — sans elle, bourse/objet/note se ressemblaient tous,
    // et le geste de l'un (ajouter) était illisible face à celui d'un autre (retirer) :
    //   - bourse / « Ajouter une note »  → « + » (_addImage), le tap AJOUTE toujours quelque chose ;
    //   - note                            → « X » (_crossImage) FIXE, le tap la SUPPRIME d'un coup,
    //                                        pas de brouillon (cf. worker._deleteButinNote) ;
    //   - objet non marqué                → « X » (_crossImage), le tap le marque SORTANT ;
    //   - objet DÉJÀ marqué               → coche verte (même icône que la liste d'attente de la
    //                                        cérémonie), le tap ANNULE la sortie.
    // Ne lit ni n'écrit rien (hormis ce calcul d'icône) : c'est ce qui permet à un objet marqué de
    // rester à sa place, donc d'être retapé pour se raviser — une relecture le ferait disparaître.
    void _pushButinRows() {

                                final rows = <Map<String, dynamic>>[];
                                for (final r in _butinRows) {
                                    final id       = r["id"]?.toString() ?? "";
                                    final kind     = r["kind"]?.toString() ?? "item";
                                    final isWallet = kind == "wallet";
                                    final qty      = (int.tryParse(r["quantity"]?.toString() ?? "1") ?? 1)
                                        + (isWallet ? _butinMoneyAdd : 0);

                                    String trail;
                                    switch (kind) {
                                        case "wallet":
                                        case "add_note":
                                            trail = _addImage;
                                            break;
                                        case "note":
                                            trail = _crossImage;
                                            break;
                                        default: // "item"
                                            trail = _butinTaken.contains(id)
                                                ? "images/small/adm_enable.png"
                                                : _crossImage;
                                    }

                                    rows.add({
                                        ...r,
                                        "quantity": qty,
                                        // La bourse affiche toujours sa somme, même à 0 : c'est
                                        // l'information qu'on vient chercher. Les autres n'affichent leur
                                        // contenu que s'il dit quelque chose.
                                        "badge":       (isWallet || qty > 1) ? "($qty)" : "",
                                        "trail_image": trail,
                                    });
                                }
                                ActionRegistry.get("dvlist.set_rows")?.call(null, rows);
    }

    // Tap sur une ligne. Trois comportements bien distincts, désormais lisibles à l'icône
    // (cf. _pushButinRows) :
    //  - « Ajouter une note » : ouvre l'écran de saisie, toujours vierge.
    //  - une note existante : SUPPRIMÉE sur-le-champ, sans brouillon (comme « À la poubelle »).
    //  - la bourse / un objet : c'est le SEUL brouillon qui reste (cf. _butinTaken/_butinMoneyAdd),
    //    engagé au « Valider ».
    Future<void> on_butin_row_tap(dynamic caller, dynamic event) async {

                                final data = (event is Map) ? event : const {};
                                final id   = data["id"]?.toString() ?? "";
                                if (id.isEmpty) return;

                                if (id == _addNoteRowId) {
                                    await item_note(caller, event);
                                    return;
                                }

                                if (id.startsWith(_noteRowPrefix)) {
                                    // Suppression DIRECTE, pas de brouillon : une note se retire d'un tap,
                                    // comme « À la poubelle » pour un item (aucune popup dans ce jeu).
                                    await _deleteButinNote(id.substring(_noteRowPrefix.length));
                                    return;
                                }

                                if (id == _walletDocId) {
                                    // Promesse : aucun plafond (cf. _moneyCap). L'écran est empilé,
                                    // donc CET écran ne rejouera pas son `appear` au retour : le
                                    // brouillon en cours survit.
                                    _moneyMode = _moneyPromise;
                                    _moneyCap  = 0;
                                    DvOrb.navigate_new("money_page");
                                    return;
                                }

                                if (!_butinTaken.remove(id)) _butinTaken.add(id);
                                _pushButinRows();
    }

    // « Valider » : le SEUL endroit qui écrit. Tout le brouillon part dans un batchWrite unique —
    // les objets marqués passent dans l'inventaire de l'admin qui agit, la bourse encaisse l'argent
    // promis. batchWrite n'injecte pas ownerId : on le pose dans chaque document (cf.
    // _reconcileClanSchema). Brouillon vide → aucune écriture, on rentre simplement.
    // La grille de l'onglet Items est remise à jour ici même (cf. le miroir _clanItemDocs) : on ne
    // peut PAS compter sur son `appear`, qui ne rejoue pas au retour d'un écran empilé.
    Future<void> on_butin_ok(dynamic caller, dynamic event) async {

                                final ctx = await _butinCtx();
                                if (ctx == null) { DvOrb.navigate_back("testme"); return; }
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                final coll       = "clans_items/$clanId/items";
                                // Somme promise capturée AVANT toute écriture : le brouillon est remis à
                                // zéro en fin de méthode, et l'annonce au clan en a encore besoin.
                                final money      = _butinMoneyAdd;

                                try {
                                    final writes = <DvCloudWrite>[];

                                    // Écritures PARTIELLES : le deep-merge dvcloud préserve tout le reste
                                    // du document (type, quantité, nom…) — l'objet ne change que de mains.
                                    if (_userId.isNotEmpty) {
                                        for (final id in _butinTaken) {
                                            final doc = Dvidle({});
                                            doc.set("ownerId", clanSecret);
                                            doc.set("owner",   _userId);
                                            writes.add(DvCloudWrite.set(coll, id, doc));
                                        }
                                    }

                                    // La bourse est relue juste avant : elle a pu bouger sur un autre
                                    // appareil pendant qu'on remplissait le brouillon.
                                    int? walletTotal;
                                    if (_butinMoneyAdd > 0) {
                                        final cur = await _cloud?.read("workers", coll, _walletDocId,
                                            ownerId: clanSecret, region: region);
                                        final have = int.tryParse(cur?.get("quantity")?.toString() ?? "0") ?? 0;
                                        walletTotal = have + _butinMoneyAdd;
                                        final doc  = Dvidle({});
                                        doc.set("ownerId",  clanSecret);
                                        doc.set("quantity", walletTotal);
                                        writes.add(DvCloudWrite.set(coll, _walletDocId, doc));
                                    }

                                    if (writes.isNotEmpty) {
                                        await _cloud?.batchWrite("workers", writes, region: region);
                                        deva_log("info", "[butin] validé : ${_butinTaken.length} objet(s) sorti(s)"
                                            "${_butinMoneyAdd > 0 ? ", +$_butinMoneyAdd d'argent de poche" : ""}");

                                        // La grille de l'écran Items est remise à jour ICI, et pas à son
                                        // `appear` : revenir sur une page déjà empilée n'émet qu'un `show`
                                        // (cf. dvpage_motor.didPopNext), donc personne ne relirait la
                                        // collection — l'objet sorti resterait invisible alors qu'il est bien
                                        // en base, et on croirait le déplacement perdu. On applique les
                                        // changements au miroir : le retour se fait sur une grille déjà juste,
                                        // sans attendre un aller-retour réseau.
                                        bool missing = false;
                                        for (final id in _butinTaken) {
                                            if (!_patchLocalItem(id, owner: _userId)) missing = true;
                                        }
                                        // La bourse ne paraît jamais dans la grille, mais un miroir à moitié
                                        // vrai est un piège pour le prochain qui s'y fiera.
                                        if (walletTotal != null) _patchLocalItem(_walletDocId, quantity: walletTotal);
                                        if (missing) {
                                            await _loadClanItems(clanId, clanSecret, region);
                                        } else {
                                            _pushClanItems();
                                        }

                                        // De l'argent vient d'entrer dans le coffre : c'est un dépôt, il
                                        // s'annonce comme le dépôt d'un objet, mais comparé aux `amount`
                                        // de l'historique. Une sortie d'objet, elle, ne s'annonce pas :
                                        // le coffre ne s'est pas enrichi.
                                        if (money > 0) {
                                            await _announceChestDeposit(ctx, value: money, field: "amount");
                                        }
                                    }
                                } catch (e) {
                                    deva_log("error", "[butin] on_butin_ok FAILED: $e");
                                }

                                _butinTaken.clear();
                                _butinMoneyAdd = 0;
                                DvOrb.navigate_back("testme");
    }

    // --- Note du coffre (annonce d'un chef) --------------------------------------------------
    // Un chef peut déposer PLUSIEURS notes, chacune identifiée par son propre id (_generateUuid).
    // Portées par le document `butin` lui-même (champ `notes`, liste d'objets `{id, author,
    // author_name, text, date}`) — secrètes jusqu'à l'ouverture, y compris des autres chefs
    // (personne ne lit `notes` avant que la distribution la recopie dans `notes_shown`, cf.
    // _distributeButin). butin_note_page ne sert qu'À CRÉER : il n'existe plus d'écran d'édition,
    // une note déjà déposée se retire en un tap depuis le contenu du coffre (on_butin_row_tap →
    // _deleteButinNote), on n'en corrige pas le texte.

    // Porte d'entrée : ligne « Ajouter une note » du contenu du coffre. Toujours une note VIERGE —
    // même un chef qui en a déjà déposé plusieurs peut en ajouter une de plus.
    Future<void> item_note(dynamic caller, dynamic event) async {

                                DvOrb.navigate_new("butin_note_page");
    }

    // Apparition de l'écran : toujours vierge (create-only).
    Future<void> on_butin_note_appear(dynamic caller, dynamic event) async {

                                final entry = await DvOrb.wait_for_shape("butin_note_page/entry");
                                entry?.set("shape.value", "");
                                entry?.refreshUI();
    }

    // « Valider » : ajoute une note si le texte n'est pas vide (rien à faire sinon — un champ
    // vidé n'est pas une erreur, juste un renoncement). Le texte est relu DIRECTEMENT sur le
    // champ (`shape.value`), pas via un handler `changed` : DvEntry n'émet cet évènement que si
    // `shape.events.changed: true` est déclaré (cf. dventry_motor.dart), ce que
    // butin_note_page/entry ne fait pas — même idiome que money_page/amount et rename_task/desc
    // (relus au Valider, jamais suivis en direct). Relit le document du coffre pour préserver les
    // notes DÉJÀ présentes — une liste est une FEUILLE pour le deep-merge dvcloud (cf.
    // project_dvcloud_deepmerge) : écrire `notes` remplace le tableau entier, il faut donc le
    // reconstruire en entier ici.
    Future<void> on_butin_note_ok(dynamic caller, dynamic event) async {

                                final entry = DvOrb.get_shape_by_id("butin_note_page/entry");
                                final text  = entry?.get("shape.value")?.toString().trim() ?? "";

                                if (text.isNotEmpty) {
                                    final ctx = await _butinCtx();
                                    if (ctx != null) {
                                        final clanId     = ctx.get("clanId").toString();
                                        final clanSecret = ctx.get("clanSecret").toString();
                                        final region     = ctx.get("region").toString();
                                        try {
                                            final cur      = await _cloud?.read("workers", "clans_items/$clanId/items",
                                                _butinDocId, ownerId: clanSecret, region: region);
                                            final notes    = <Map<String, dynamic>>[];
                                            final existing = cur?.get("notes");
                                            if (existing is List) {
                                                for (final n in existing) {
                                                    if (n is! Dvidle) continue;
                                                    notes.add({
                                                        "id":          n.get("id")?.toString()          ?? "",
                                                        "author":      n.get("author")?.toString()      ?? "",
                                                        "author_name": n.get("author_name")?.toString() ?? "",
                                                        "text":        n.get("text")?.toString()         ?? "",
                                                        "date":        n.get("date")?.toString()         ?? "",
                                                    });
                                                }
                                            }
                                            final myName = (await Deva.instance.get("session.user.name"))?.toString() ?? "";
                                            notes.add({
                                                "id":          _generateUuid(),
                                                "author":      _userId,
                                                "author_name": myName,
                                                "text":        text,
                                                "date":        DateTime.now().toUtc().toIso8601String(),
                                            });

                                            final doc = Dvidle({});
                                            doc.set("ownerId", clanSecret);
                                            doc.set("notes",   notes);
                                            await _cloud?.write("workers", "clans_items/$clanId/items", _butinDocId, doc,
                                                region: region, ownerId: clanSecret);
                                            deva_log("info", "[butin] note déposée par $_userId");

                                            // La ligne doit paraître dans le coffre, où l'on retourne :
                                            // butin_page est EMPILÉE, son `appear` ne rejouera pas au
                                            // retour (cf. on_butin_row_tap, bourse) — sans cette relecture
                                            // la note déposée resterait invisible jusqu'à la prochaine
                                            // ouverture du coffre. Même geste qu'après un retrait
                                            // (_deleteButinNote). Avant la notification, qui n'a pas le
                                            // droit de faire échouer l'affichage. Le brouillon en cours
                                            // (objets marqués, argent promis) survit : _loadButinRows ne
                                            // touche pas _butinTaken/_butinMoneyAdd, et _pushButinRows les
                                            // réapplique.
                                            await _loadButinRows();

                                            // Le clan est prévenu qu'une surprise l'attend — sans rien en
                                            // dire, c'est justement le principe. Même canal que le dépôt
                                            // d'un objet/d'argent (_announceChestDeposit), mais sans
                                            // verdict (pas de suffixKey) : il n'y a rien à comparer à une
                                            // moyenne.
                                            await _notifyClanChest(clanId, region, "", baseKey: "chest_notif_note");
                                        } catch (e) {
                                            deva_log("error", "[butin] on_butin_note_ok FAILED: $e");
                                        }
                                    }
                                }

                                // Simple pop (pas de route ciblée) : contrairement à on_butin_ok, on ne
                                // referme pas le coffre ici, la note ne fait que s'y ajouter — l'admin
                                // doit rester sur butin_page pour continuer d'y déposer/annoncer.
                                DvOrb.navigate_back();
    }

    // Retrait direct d'une de mes notes (tap sur sa ligne dans le contenu du coffre) : pas de
    // brouillon, pas de confirmation — même immédiateté que item_trash. Relit le document pour
    // préserver les AUTRES notes (siennes et celles des autres auteurs) — une liste est une
    // FEUILLE pour le deep-merge dvcloud, écrire `notes` remplace le tableau entier.
    Future<void> _deleteButinNote(String noteId) async {

                                if (noteId.isEmpty) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                try {
                                    final cur      = await _cloud?.read("workers", "clans_items/$clanId/items",
                                        _butinDocId, ownerId: clanSecret, region: region);
                                    final notes    = <Map<String, dynamic>>[];
                                    final existing = cur?.get("notes");
                                    if (existing is List) {
                                        for (final n in existing) {
                                            if (n is! Dvidle) continue;
                                            if ((n.get("id")?.toString() ?? "") == noteId) continue; // celle-ci : retirée
                                            notes.add({
                                                "id":          n.get("id")?.toString()          ?? "",
                                                "author":      n.get("author")?.toString()      ?? "",
                                                "author_name": n.get("author_name")?.toString() ?? "",
                                                "text":        n.get("text")?.toString()         ?? "",
                                                "date":        n.get("date")?.toString()         ?? "",
                                            });
                                        }
                                    }
                                    final doc = Dvidle({});
                                    doc.set("ownerId", clanSecret);
                                    doc.set("notes",   notes);
                                    await _cloud?.write("workers", "clans_items/$clanId/items", _butinDocId, doc,
                                        region: region, ownerId: clanSecret);
                                    deva_log("info", "[butin] note retirée par $_userId");
                                    // La ligne a disparu : la liste doit le refléter sans attendre un
                                    // aller-retour réseau spontané.
                                    await _loadButinRows();
                                } catch (e) {
                                    deva_log("error", "[butin] _deleteButinNote FAILED: $e");
                                }
    }

    // --- OUVERTURE DU BUTIN ------------------------------------------------------------------
    // Trois temps, sur tous les appareils du clan à la fois.
    //
    // 0. CÉRÉMONIE (voir plus bas, on_butin_open_tap & co) : quand la jauge est pleine, un chef
    //    touche le coffre doré, prend le verrou dvlock (un seul meneur), lit le rituel et APPELLE
    //    le clan (`pending_opening` posé sur chaque joueur en ligne). Chacun répond depuis son
    //    appareil ; quand le dernier a répondu, l'appareil du meneur enchaîne sur 1.
    //
    // 1. DISTRIBUTION (app du meneur, _distributeButin) : le partage est calculé UNE fois et posé
    //    en base — chaque objet gagné reçoit son destinataire (`to_owner`) et quitte le coffre
    //    (`owner` = _openingOwner), l'argent est versé au portefeuille personnel de chaque gagnant,
    //    le portefeuille du coffre est vidé, et le doc clans_players de chaque gagnant reçoit
    //    `pending_butin: true`. C'est aussi là que le cycle se REFERME : les contributions sont
    //    recalées (clans.last_butin_xp / clans_players.last_butin_xp), la jauge repart de zéro et
    //    le coffre doré s'éteint jusqu'au prochain plafond.
    //
    // 2. RÉCEPTION (app de CHAQUE joueur, _checkPendingButin) : la vigilance temps réel voit le
    //    drapeau, l'app réclame la part (les objets passent à son nom, le drapeau retombe), PUIS
    //    l'animation se joue. Cet ordre n'est pas négociable : on ne montre jamais un butin qu'on
    //    n'a pas su encaisser. Personne ne voit la part des autres — la surprise est à chacun.

    // --- CÉRÉMONIE : le meneur --------------------------------------------------------------

    // Ressource du verrou dvlock de la cérémonie. Un seul meneur par clan : le premier chef qui
    // touche le coffre l'emporte, les autres n'obtiennent rien et ne voient rien.
    String _openingLockId(String clanId) => "butin_open_$clanId";

    // Coffre doré de l'écran Clan (chefs seulement, jauge au plafond) : ouvre la cérémonie.
    // Le verrou est pris AVANT d'empiler l'écran — celui qui ne l'a pas ne mène pas, et il n'a
    // rien à lire. On ne le relâche pas en cas d'échec plus loin : le TTL s'en charge (idiome
    // du verrou de combat, _takeCombatTask).
    Future<void> on_butin_open_tap(dynamic caller, dynamic event) async {

                                if (_openingRole.isNotEmpty || _butinChecking) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                // Double garde : la shape n'est révélée qu'aux admins, mais un registry
                                // persisté sur l'appareil d'un chef rétrogradé pourrait la laisser en place.
                                if (!await _ensureIsAdmin(clanId, clanSecret, region)) return;

                                final lock = Deva.instance.module("dvlock") as dvlock?;
                                final got  = await lock?.lock(
                                    _openingLockId(clanId), _userId, delaiMs: _openingLockMs) ?? false;
                                if (!got) {
                                    deva_log("info", "[opening] cérémonie déjà menée par un autre chef");
                                    return;
                                }

                                _openingRole = "master";
                                _openingRows.clear();
                                // L'aura n'a plus rien à annoncer : la cérémonie est lancée.
                                ActionRegistry.get("dvflame.stop.chestaura")?.call(null, null);
                                deva_log("info", "[opening] verrou pris : $_userId mène l'ouverture");
                                DvOrb.navigate_new("butin_open_page");
    }

    // --- CÉRÉMONIE : l'écran partagé ---------------------------------------------------------

    // Apparition de butin_open_page. Le MÊME écran sert au meneur et aux joueurs : seuls le texte
    // et le libellé du bouton changent. Un ré-affichage (rebuild) ne doit pas rendre son bouton au
    // meneur qui a déjà appelé le clan : _openingRows fait foi, on retrouve alors la liste d'attente.
    Future<void> on_opening_appear(dynamic caller, dynamic event) async {

                                final master = _openingRole == "master";
                                final called = master && _openingRows.isNotEmpty;   // le clan est déjà appelé

                                final text = await DvOrb.wait_for_shape("butin_open_page/text");
                                final ok   = await DvOrb.wait_for_shape("butin_open_page/ok");
                                final list = await DvOrb.wait_for_shape("butin_open_page/list");

                                await _syncLabel(text, "butin_open_page/text", TranslationRegistry.processLabel(
                                    master ? "@@@T:opening_master_text@@@" : "@@@T:opening_player_text@@@"));
                                await _syncLabel(ok, "butin_open_page/ok", TranslationRegistry.processLabel(
                                    master ? "@@@T:opening_master_btn@@@" : "@@@T:opening_player_btn@@@"));
                                await _syncVisible(ok,   "butin_open_page/ok",   !called);
                                await _syncVisible(list, "butin_open_page/list", called);
                                if (called) _pushOpeningRows();
    }

    // Le bouton de la cérémonie, partagé par les deux rôles.
    //
    //  - le MENEUR appelle le clan : `pending_opening` est posé sur chaque joueur EN LIGNE, sauf
    //    lui-même (il vient d'appuyer, il est prêt par construction — et s'exclure évite que sa
    //    propre vigilance le renvoie ici en tant que joueur). Son bouton laisse place à la liste
    //    d'attente, et une vigilance par joueur attendu se met à l'écoute.
    //  - un JOUEUR répond : son `pending_opening` est vidé et son bouton disparaît. Il reste sur
    //    l'écran ; c'est l'animation du butin qui viendra l'en sortir.
    Future<void> on_opening_ready(dynamic caller, dynamic event) async {

                                if (_openingRole.isEmpty) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                final pcoll      = "clans_players/$clanId/players";

                                if (_openingRole != "master") {
                                    try {
                                        // Chaîne VIDE et non champ omis : le deep-merge dvcloud préserverait
                                        // un champ absent, et le meneur attendrait ce joueur pour toujours.
                                        final doc = Dvidle({});
                                        doc.set("ownerId",         clanSecret);
                                        doc.set("pending_opening", "");
                                        await _cloud?.write("workers", pcoll, _userId, doc,
                                            region: region, ownerId: clanSecret);
                                        await _syncVisible(await DvOrb.wait_for_shape("butin_open_page/ok"),
                                            "butin_open_page/ok", false);
                                        deva_log("info", "[opening] réponse envoyée : $_userId est prêt");
                                    } catch (e) {
                                        deva_log("error", "[opening] réponse joueur FAILED: $e");
                                    }
                                    // Le meneur est devant sa liste d'attente : on le prévient directement
                                    // au lieu de le laisser découvrir la réponse par sa vigilance. Envoi
                                    // hors du try d'écriture — un échec de notification ne doit pas se lire
                                    // comme un échec de réponse (la vigilance rattrapera).
                                    await _notifyOpeningReady(clanId, clanSecret, region);
                                    return;
                                }

                                if (_openingRows.isNotEmpty || _openingCalling) return;   // clan déjà appelé
                                _openingCalling = true;
                                try {
                                    final players = await _cloud?.list("workers", pcoll, region: region) ?? [];
                                    final now     = DateTime.now().toUtc().toIso8601String();
                                    final writes  = <DvCloudWrite>[];
                                    final called  = <String>{};
                                    for (final p in players) {
                                        final pid = p.get("id")?.toString() ?? "";
                                        if (pid.isEmpty) continue;
                                        // Le révoqué n'est plus du clan ; le hors-device (declare_offline) n'a
                                        // pas d'appareil pour répondre — l'attendre gèlerait la cérémonie.
                                        if (p.get("enabled") == false)    continue;
                                        if (p.get("has_device") == false) continue;
                                        final avatar = p.get("avatar")?.toString() ?? "";
                                        _openingRows.add({
                                            "id":     pid,
                                            "name":   _memberLabel(p.get("name")?.toString() ?? ""),
                                            "avatar": avatar.isNotEmpty ? avatar : _nopeAvatar,
                                            "ready":  pid == _userId,
                                        });
                                        if (pid == _userId) continue;     // le meneur ne s'appelle pas lui-même
                                        final doc = Dvidle({});
                                        doc.set("ownerId",         clanSecret);
                                        doc.set("pending_opening", now);
                                        // Qui mène : c'est par ce champ que le joueur saura à qui envoyer sa
                                        // réponse. Écrit dans le même lot, il ne coûte rien de plus.
                                        doc.set("opening_master",  _userId);
                                        writes.add(DvCloudWrite.set(pcoll, pid, doc));
                                        called.add(pid);
                                    }
                                    if (writes.isNotEmpty) {
                                        await _cloud?.batchWrite("workers", writes, region: region);
                                    }
                                    deva_log("info", "[opening] clan appelé : ${writes.length} joueur(s) attendu(s)");
                                    // Le drapeau est posé ; reste à faire venir les joueurs. C'est le push
                                    // qui les amène — la vigilance n'est là que pour ceux qu'il n'atteint pas.
                                    await _notifyOpeningCall(players, called);
                                } catch (e) {
                                    // Rien n'est parti : on rend le bouton au meneur pour qu'il réessaie.
                                    deva_log("error", "[opening] appel du clan FAILED: $e");
                                    _openingRows.clear();
                                    _openingCalling = false;
                                    return;
                                }

                                // Le bouton a fait son office : place à l'attente.
                                await _syncVisible(await DvOrb.wait_for_shape("butin_open_page/ok"),
                                    "butin_open_page/ok", false);
                                await _syncVisible(await DvOrb.wait_for_shape("butin_open_page/list"),
                                    "butin_open_page/list", true);
                                _pushOpeningRows();
                                _startOpeningWatch(clanId, clanSecret, region);
                                await _maybeDistribute(clanId);   // meneur seul en ligne : rien à attendre
    }

    // Tap sur une ligne d'attente (meneur seulement) : force la réponse d'un joueur qui ne viendra
    // pas. Sans cette porte, un seul absent gèlerait l'ouverture pour toujours — le verrou finirait
    // par expirer, mais le coffre resterait fermé. Le tap sur une ligne déjà prête ne fait rien.
    Future<void> on_opening_row_tap(dynamic caller, dynamic event) async {

                                if (_openingRole != "master") return;
                                final data = (event is Map) ? event : const {};
                                final pid  = data["id"]?.toString() ?? "";
                                if (pid.isEmpty) return;
                                final row = _openingRows.firstWhere(
                                    (r) => r["id"] == pid, orElse: () => <String, dynamic>{});
                                if (row.isEmpty || row["ready"] == true) return;

                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                try {
                                    final doc = Dvidle({});
                                    doc.set("ownerId",         clanSecret);
                                    doc.set("pending_opening", "");
                                    await _cloud?.write("workers", "clans_players/$clanId/players", pid, doc,
                                        region: region, ownerId: clanSecret);
                                    deva_log("info", "[opening] absent forcé prêt par le meneur : $pid");
                                    // On n'attend pas le retour du watch : la ligne est vraie dès maintenant.
                                    await _markOpeningReady(pid, clanId);
                                } catch (e) {
                                    deva_log("error", "[opening] forçage FAILED: $e");
                                }
    }

    // --- CÉRÉMONIE : l'attente du meneur -----------------------------------------------------

    // Une vigilance PAR joueur attendu. dvcloud.watch écoute un DOCUMENT, pas une collection : il
    // n'y a pas d'autre façon de voir les réponses arriver en temps réel. Le clan est petit et
    // l'écoute ne dure que le temps du rituel — sur Android ce sont des snapshots natifs, sur
    // desktop un poll fibonacci plafonné.
    //
    // Ces vigilances ne sont PLUS le canal principal : les joueurs annoncent leur réponse par une
    // notification silencieuse (_notifyOpeningReady). Elles restent le filet de celui dont le push
    // n'est pas passé, et de celui qui a répondu pendant qu'on les armait.
    void _startOpeningWatch(String clanId, String clanSecret, String region) {

                                _stopOpeningWatch();
                                for (final row in _openingRows) {
                                    if (row["ready"] == true) continue;
                                    final pid = row["id"].toString();
                                    final v = _cloud?.watch("workers", "clans_players/$clanId/players", pid,
                                        (doc, reason) {
                                            if (reason != DvWatchReason.changed || doc == null) return;
                                            final pending = doc.get("pending_opening")?.toString() ?? "";
                                            if (pending.isEmpty) _markOpeningReady(pid, clanId);  // fire-and-forget
                                        },
                                        region: region, ownerId: clanSecret,
                                        strategy: DvWatchStrategy.fibonacci(baseMs: 2000, maxMs: 10000));
                                    if (v != null) _openingWatch.add(v);
                                }
                                deva_log("info", "[opening] ${_openingWatch.length} vigilance(s) d'attente armée(s)");
                                // Une vigilance ne notifie jamais son état initial. Entre l'appel du clan et
                                // cet armement, un joueur a pu répondre : sa réponse serait avalée par la
                                // baseline et sa ligne ne verdirait jamais. On relit donc une fois.
                                _catchUpOpeningRows(clanId, region);   // fire-and-forget : la liste se corrige seule
    }

    // Relecture unique de tous les joueurs attendus : coche ceux dont le drapeau est déjà retombé.
    Future<void> _catchUpOpeningRows(String clanId, String region) async {

                                try {
                                    final players = await _cloud?.list(
                                        "workers", "clans_players/$clanId/players", region: region) ?? [];
                                    for (final p in players) {
                                        final pid = p.get("id")?.toString() ?? "";
                                        if (pid.isEmpty || pid == _userId) continue;
                                        final pending = p.get("pending_opening")?.toString() ?? "";
                                        if (pending.isEmpty) await _markOpeningReady(pid, clanId);
                                    }
                                } catch (e) {
                                    deva_log("error", "[opening] _catchUpOpeningRows FAILED: $e");
                                }
    }

    void _stopOpeningWatch() {

                                for (final v in _openingWatch) { v.stop(); }
                                _openingWatch.clear();
    }

    // Fin de cérémonie pour CET appareil, quelle qu'en soit la raison (butin réclamé, déconnexion,
    // départ du clan, bascule d'identité) : plus de rôle, plus d'attente, plus d'écoutes.
    void _resetOpening() {

                                _stopOpeningWatch();
                                _openingRole    = "";
                                _openingCalling = false;
                                _openingMaster  = "";
                                _openingRows.clear();
    }

    // Coche verte sur la ligne d'un joueur, puis ouverture du coffre si plus personne ne manque.
    Future<void> _markOpeningReady(String pid, String clanId) async {

                                final row = _openingRows.firstWhere(
                                    (r) => r["id"] == pid, orElse: () => <String, dynamic>{});
                                if (row.isEmpty || row["ready"] == true) return;
                                row["ready"] = true;
                                _pushOpeningRows();
                                await _maybeDistribute(clanId);
    }

    // Re-pousse la liste ENTIÈRE : la DvList diffe seule, et une ligne ne se modifie pas en place.
    void _pushOpeningRows() {

                                final ready = TranslationRegistry.processLabel("@@@T:opening_ready_row@@@");
                                final wait  = TranslationRegistry.processLabel("@@@T:opening_wait_row@@@");
                                final rows  = _openingRows.map<Map<String, dynamic>>((r) => {
                                    "id":          r["id"],
                                    "label":       r["name"],
                                    "desc":        r["ready"] == true ? ready : wait,
                                    "image":       r["avatar"],
                                    // La coche verte : l'unique signal de l'écran d'attente.
                                    "trail_image": r["ready"] == true ? "images/small/adm_enable.png" : "",
                                }).toList();
                                ActionRegistry.get("dvlist.set_rows")?.call(null, rows);
    }

    // Tout le monde a répondu → le coffre s'ouvre, sans que personne n'ait à le redemander. Le
    // verrou est rendu AVANT la distribution : elle n'a plus rien à protéger (le drapeau
    // pending_butin, lui, est idempotent) et une panne au milieu ne doit pas laisser le clan
    // enfermé 30 minutes.
    Future<void> _maybeDistribute(String clanId) async {

                                if (_openingDistributing) return;
                                if (_openingRows.isEmpty) return;
                                if (_openingRows.any((r) => r["ready"] != true)) return;

                                _openingDistributing = true;
                                _stopOpeningWatch();
                                deva_log("info", "[opening] clan au complet : ouverture du coffre");
                                try {
                                    final lock = Deva.instance.module("dvlock") as dvlock?;
                                    await lock?.release(_openingLockId(clanId));
                                } catch (e) {
                                    deva_log("warning", "[opening] release du verrou : $e");
                                }
                                try {
                                    await _distributeButin();
                                } finally {
                                    _resetOpening();
                                    _openingDistributing = false;
                                }
    }

    // --- CÉRÉMONIE : le joueur appelé --------------------------------------------------------

    // Détection de l'appel du meneur : le doc joueur porte `pending_opening` (une date, posée à
    // l'appel ; vidée par la réponse). Appelée à chaque changement du doc ET une fois au démarrage
    // de la vigilance — un appel DÉJÀ lancé quand on s'abonne n'émet aucun changement.
    // Renvoie true si l'écran de cérémonie a été empilé : l'appelant s'abstient alors du reste.
    Future<bool> _checkPendingOpening() async {

                                if (_openingRole.isNotEmpty || _butinChecking || _userId.isEmpty) return false;
                                final ctx = await _butinCtx();
                                if (ctx == null) return false;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();

                                try {
                                    final me = await _cloud?.read("workers", "clans_players/$clanId/players",
                                        _userId, ownerId: clanSecret, region: region);
                                    final pending = me?.get("pending_opening")?.toString() ?? "";
                                    if (pending.isEmpty) return false;

                                    _openingRole   = "player";
                                    // Retenu ici et nulle part ailleurs : c'est la seule lecture du doc que
                                    // fait le joueur, et sa réponse ira droit au meneur sans relire le clan.
                                    _openingMaster = me?.get("opening_master")?.toString() ?? "";
                                    _openingRows.clear();
                                    deva_log("info", "[opening] appelé par le meneur : cérémonie ouverte");
                                    DvOrb.navigate_new("butin_open_page");
                                    return true;
                                } catch (e) {
                                    deva_log("error", "[opening] _checkPendingOpening FAILED: $e");
                                    return false;
                                }
    }

    // Distribution du contenu du coffre. Appelée par la cérémonie (dernier joueur prêt), jamais
    // directement par une action de conf : il n'y a plus de raccourci vers le butin.
    //
    // La garde _butinChecking est tenue pendant TOUTE la distribution, et pour deux raisons : elle
    // écarte le double appel, et elle empêche la vigilance de réclamer notre propre part au milieu
    // de l'écriture — le drapeau que l'on vient de poser sur son propre doc revient par le watch en
    // quelques dizaines de millisecondes. On réclame donc soi-même, à la fin, une fois la garde rendue.
    Future<void> _distributeButin() async {

                                if (_butinChecking) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                // Double garde : la shape n'est révélée qu'aux admins, mais un registry
                                // persisté sur l'appareil d'un chef rétrogradé pourrait la laisser en place.
                                final isAdmin = await _ensureIsAdmin(clanId, clanSecret, region);
                                if (!isAdmin) return;

                                _butinChecking = true;
                                try {
                                    final players = await _cloud?.list(
                                        "workers", "clans_players/$clanId/players", region: region) ?? [];
                                    final docs = await _cloud?.list(
                                        "workers", "clans_items/$clanId/items", region: region) ?? [];

                                    // Une seule lecture de la collection sert à tout : le contenu du
                                    // coffre, l'argent qu'il garde, et les portefeuilles déjà ouverts.
                                    // Les objets DÉJÀ en transit (owner = _openingOwner, part d'une
                                    // ouverture précédente que personne n'a réclamée) ne sont pas dans le
                                    // coffre : ils ne repartent pas au partage, ils attendent leur joueur.
                                    final loot    = <Dvidle>[];
                                    final wallets = <String, Dvidle>{};
                                    var   money   = 0;
                                    // Le document du coffre lui-même (docId `butin`) : owner == clanId, il
                                    // ne matche ni la bourse ni le butin ni un portefeuille — capturé à
                                    // part pour ses notes, révélées plus bas dans ce même batch.
                                    Dvidle? butinDoc;
                                    for (final d in docs) {
                                        final id = d.get("docId")?.toString() ?? "";
                                        if (id.isEmpty) continue;
                                        if (id == _butinDocId) {
                                            butinDoc = d;
                                            continue;
                                        }
                                        if (id == _walletDocId) {
                                            money = int.tryParse(d.get("quantity")?.toString() ?? "0") ?? 0;
                                            continue;
                                        }
                                        if ((d.get("owner")?.toString() ?? "") == _butinOwner) {
                                            loot.add(d);
                                            continue;
                                        }
                                        // Portefeuilles personnels déjà ouverts : leur solde sert de base
                                        // au versement (et leur `last_quantity` au repère du gain).
                                        if ((d.get("type")?.toString() ?? "") == "argent_poche") wallets[id] = d;
                                    }
                                    // Un coffre vide n'annule RIEN : l'ouverture est une cérémonie de
                                    // clan, elle a lieu même quand il n'y a rien dedans. Chacun aura
                                    // son animation, fût-elle celle d'un coffre décevant.
                                    if (money <= 0 && loot.isEmpty) {
                                        deva_log("info", "[butin] coffre vide : ouverture à blanc");
                                    }

                                    // Les chefs sont lus sur le doc clan, comme le roster.
                                    final clanDoc = await _cloud?.read(
                                        "workers", "clans", clanId, ownerId: clanSecret, region: region);
                                    final admins = List<dynamic>.from(clanDoc?.get("admins") as List? ?? []);

                                    // Membres du partage. Le révoqué (tombstone) en est exclu ; le mort et
                                    // le hors-device y restent — le second recevra sa part le jour où un
                                    // parent prendra sa place (la réclamation suit le joueur AGISSANT).
                                    final members = <_ButinShare>[];
                                    // XP de chaque membre au moment du partage : ce sera son nouveau repère de
                                    // contribution (last_butin_xp) une fois le coffre vidé. Lu du MÊME
                                    // instantané que les contributions, sinon on effacerait de l'XP gagnée
                                    // pendant la cérémonie.
                                    final xpOf = <String, int>{};
                                    for (final p in players) {
                                        final pid = p.get("id")?.toString() ?? "";
                                        if (pid.isEmpty || p.get("enabled") == false) continue;
                                        final pxp    = int.tryParse(p.get("xp")?.toString() ?? "0") ?? 0;
                                        final plastB = int.tryParse(p.get("last_butin_xp")?.toString() ?? "0") ?? 0;
                                        xpOf[pid] = pxp;
                                        members.add(_ButinShare(
                                            id:           pid,
                                            name:         _memberLabel(p.get("name")?.toString() ?? ""),
                                            admin:        admins.contains(pid),
                                            contribution: (pxp - plastB) > 0 ? pxp - plastB : 0,
                                            pending:      p.get("pending_butin") == true,
                                        ));
                                    }
                                    if (members.isEmpty) {
                                        deva_log("info", "[butin] aucun membre éligible : distribution annulée");
                                        return;
                                    }

                                    final rng    = Random();
                                    final shares = _computeButinShares(
                                        members: members, money: money, items: loot, rng: rng);

                                    // Le dernier contributeur, pour l'attaque de bisous de l'écran de
                                    // récompenses. Il se calcule ICI et nulle part ailleurs : le même lot
                                    // recale `last_butin_xp` sur l'xp courante (plus bas), après quoi toutes
                                    // les contributions du cycle valent zéro et plus personne ne peut le
                                    // retrouver. On le transporte donc sur le doc de CHAQUE joueur.
                                    final lowest = _lowestContributor(members, rng);

                                    final coll   = "clans_items/$clanId/items";
                                    final pcoll  = "clans_players/$clanId/players";
                                    final writes = <DvCloudWrite>[];

                                    for (final s in shares) {
                                        // Écritures PARTIELLES (deep-merge) : l'objet ne change que de
                                        // mains, tout le reste du document est préservé.
                                        for (final item in s.items) {
                                            final id = item.get("docId")?.toString() ?? "";
                                            if (id.isEmpty) continue;
                                            final doc = Dvidle({});
                                            doc.set("ownerId",  clanSecret);
                                            doc.set("owner",    _openingOwner);
                                            doc.set("to_owner", s.id);
                                            writes.add(DvCloudWrite.set(coll, id, doc));
                                        }

                                        // Solde de la bourse APRÈS distribution, null si elle n'a pas
                                        // bougé : sert à poser le miroir du doc joueur plus bas.
                                        int? newWallet;
                                        if (s.money > 0) {
                                            final wid  = _playerWalletId(s.id);
                                            final have = int.tryParse(
                                                wallets[wid]?.get("quantity")?.toString() ?? "0") ?? 0;
                                            newWallet = have + s.money;
                                            final doc = Dvidle({});
                                            doc.set("ownerId",  clanSecret);
                                            doc.set("type",     "argent_poche");
                                            doc.set("owner",    s.id);
                                            doc.set("quantity", newWallet);
                                            // `last_quantity` est le repère qui dira au joueur ce qu'il
                                            // vient de recevoir. On ne le rafraîchit QUE si sa part
                                            // précédente a été réclamée : sinon on effacerait un gain
                                            // qu'il n'a pas encore vu.
                                            if (!s.pending) doc.set("last_quantity", have);
                                            writes.add(DvCloudWrite.set(coll, wid, doc));
                                        }

                                        // Le drapeau est posé sur TOUT LE MONDE, y compris ceux qui
                                        // repartent les mains vides : l'ouverture du coffre est un
                                        // moment de clan, personne n'en est écarté. Celui qui n'a rien
                                        // gagné voit l'animation et un écran qui le lui dit.
                                        final flag = Dvidle({});
                                        flag.set("ownerId",       clanSecret);
                                        flag.set("pending_butin", true);
                                        // Le rituel est consommé : on éteint son drapeau ici, pour TOUT le
                                        // monde. Sans ça, l'absent qu'on a forcé prêt le garde et se ferait
                                        // téléporter dans une cérémonie fantôme au prochain lancement — sur
                                        // un écran sans flèche retour. Chaînes VIDES et non champs omis : le
                                        // deep-merge dvcloud préserverait un champ absent.
                                        flag.set("pending_opening", "");
                                        flag.set("opening_master",  "");
                                        // Miroir du solde de la bourse, dans LE MÊME batch que la bourse
                                        // elle-même : les deux valeurs ne peuvent pas diverger. Rien à
                                        // poser pour qui n'a pas reçu d'argent — son solde n'a pas bougé.
                                        if (newWallet != null) flag.set("wallet", newWallet);
                                        // RECALAGE de la contribution : ce que ce joueur a produit vient
                                        // d'être payé, son compteur repart d'ici. Dans le même lot que sa
                                        // part — on ne solde pas une dette qu'on n'aurait pas versée.
                                        flag.set("last_butin_xp", xpOf[s.id] ?? 0);
                                        // Le dernier contributeur, transporté à tout le monde (lui compris :
                                        // c'est son app qui décidera de ne rien lui montrer). Chaînes VIDES et
                                        // non champs omis quand il n'y en a pas — le deep-merge dvcloud
                                        // garderait sinon le dernier de l'ouverture PRÉCÉDENTE.
                                        flag.set("butin_low_id",   lowest?.id   ?? "");
                                        flag.set("butin_low_name", lowest?.name ?? "");
                                        writes.add(DvCloudWrite.set(pcoll, s.id, flag));
                                    }

                                    // Le coffre rend tout son argent d'un coup : il repart de zéro.
                                    if (money > 0) {
                                        final doc = Dvidle({});
                                        doc.set("ownerId",  clanSecret);
                                        doc.set("quantity", 0);
                                        writes.add(DvCloudWrite.set(coll, _walletDocId, doc));
                                    }

                                    // Les notes des chefs sont révélées à l'instant où le coffre s'ouvre,
                                    // et la file repart vide : une note ne se lit qu'une fois. Même lot que
                                    // la remise à zéro — on ne révèle pas un message dont le butin ne
                                    // serait pas parti. Inconditionnel (même un coffre vide peut porter une
                                    // note) : seule une file elle-même vide ne produit rien à écrire.
                                    final notesToShow = butinDoc?.get("notes");
                                    if (notesToShow is List && notesToShow.isNotEmpty) {
                                        final ndoc = Dvidle({});
                                        ndoc.set("ownerId",     clanSecret);
                                        ndoc.set("notes_shown", notesToShow);
                                        ndoc.set("notes",       []);
                                        writes.add(DvCloudWrite.set(coll, _butinDocId, ndoc));
                                    }

                                    // RECALAGE de la jauge : butin_xp est un compteur CUMULÉ qui ne
                                    // redescend jamais ; c'est last_butin_xp (sa base) qu'on avance jusqu'à
                                    // lui pour que _butinCourant retombe à zéro. Sans ce trait, la jauge
                                    // resterait pleine, le coffre doré ne s'éteindrait pas et la cérémonie
                                    // pourrait se rejouer en boucle sur un coffre vide.
                                    final cumul = int.tryParse(clanDoc?.get("butin_xp")?.toString() ?? "0") ?? 0;
                                    final reset = Dvidle({});
                                    reset.set("ownerId",       clanSecret);
                                    reset.set("last_butin_xp", cumul);
                                    writes.add(DvCloudWrite.set("clans", clanId, reset));

                                    await _cloud?.batchWrite("workers", writes, region: region);
                                    deva_log("info", "[butin] jauge recalée : last_butin_xp=$cumul (cycle refermé)");

                                    for (final s in shares) {
                                        deva_log("info", "[butin] distribution : ${s.name} contribution=${s.contribution}"
                                            " argent=${s.money} objets=${s.items.length}"
                                            " (cible=${s.target.toStringAsFixed(1)} reçu=${s.received.toStringAsFixed(1)})");
                                    }

                                    // Journal : l'ouverture du coffre, le sommet du cycle. C'est le seul
                                    // événement du jeu qui distribue de l'argent de poche — sans cette ligne,
                                    // le journal (et donc le conteur IA qui s'en nourrit) ne saurait rien du
                                    // butin. Événement de CLAN, sans acteur joueur : `adminId` seul, comme
                                    // ClanLeveledUp. Écrit APRÈS le batch : on ne raconte que ce qui est acquis.
                                    // Le détail par joueur voyage dans UNE chaîne plate ("nom=argent/objets")
                                    // plutôt qu'en liste de maps — la sérialisation dvcloud reste ainsi sur des
                                    // types scalaires, et la ligne se lit telle quelle.
                                    final breakdown = shares
                                        .map((s) => "${s.name}=${s.money}/${s.items.length}")
                                        .join(", ");
                                    await _writeClanLog(clanId, clanSecret, region, "ButinOpened",
                                        adminId: _userId, slug: clanId,
                                        data: Dvidle({"money":   money,
                                                      "items":   loot.length,
                                                      "players": shares.length,
                                                      "shares":  breakdown}));

                                    // Les parts sont posées : on va chercher les joueurs. Comme pour l'appel,
                                    // le push est le canal principal — il porte l'animation jusqu'à celui qui
                                    // a rangé son téléphone, ce qu'aucune vigilance ne sait faire.
                                    await _notifyButinReady(players, shares.map((s) => s.id).toSet());

                                    // Le miroir de la grille d'items est devenu faux (les objets ont quitté
                                    // le coffre) : on le relit plutôt que de le rafistoler pièce à pièce.
                                    await _loadClanItems(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[butin] _distributeButin FAILED: $e");
                                } finally {
                                    // Rendue AVANT la réclamation : c'est cette même garde qui protège la
                                    // célébration, et _checkPendingButin refuserait de partir sans elle.
                                    // Un `return` anticipé (coffre vide) passe aussi par ici, puis s'en va
                                    // sans rien réclamer — il n'y a rien à recevoir.
                                    _butinChecking = false;
                                }

                                // L'admin est un joueur comme un autre : il a sa part d'argent. Le watch
                                // de son propre doc a très probablement été ignoré pendant l'écriture
                                // (garde tenue), on réclame donc explicitement.
                                await _checkPendingButin();
    }

    // Le membre NON ADMIN qui a le moins contribué au cycle — celui à qui le clan doit une attaque
    // de bisous. Les chefs sont hors concours : ils organisent la maisonnée, on ne leur compte pas
    // leurs points. Null si le clan n'a que des chefs — il n'y a alors personne à encourager.
    // Ex æquo départagés par un TIRAGE explicite, comme le reste du partage : le tri de Dart n'est
    // pas stable, et sans tirage ce serait toujours le même enfant qui hériterait de la dernière
    // place (le plus souvent celui dont le document se lit en premier).
    _ButinShare? _lowestContributor(List<_ButinShare> members, Random rng) {

                                final field = members.where((m) => !m.admin).toList();
                                if (field.isEmpty) return null;
                                final luck = <_ButinShare, double>{
                                    for (final m in field) m: rng.nextDouble()
                                };
                                field.sort((a, b) {
                                    final c = a.contribution.compareTo(b.contribution);
                                    return c != 0 ? c : luck[a]!.compareTo(luck[b]!);
                                });
                                return field.first;
    }

    // Partage du contenu du coffre entre les membres. Fonction PURE : elle ne lit ni n'écrit rien,
    // et tout son hasard entre par `rng` — deux appels avec le même Random donnent le même partage.
    //
    //  - l'argent va à TOUT LE MONDE (chefs compris), proportionnellement aux XP contribués ;
    //  - les objets ne vont qu'aux joueurs NON ADMIN (le chef organise, il ne se sert pas) ;
    //  - un objet ne se coupe pas en deux : la proportionnalité est APPROCHÉE par tirage au sort.
    //    C'est le cœur de l'affaire — un partage déterministe donnerait toujours au même joueur.
    List<_ButinShare> _computeButinShares({

                required List<_ButinShare> members,
                required int money,
                required List<Dvidle> items,
                required Random rng,
    }) {

                                if (members.isEmpty) return members;

                                // Poids = contribution au cycle courant. Un clan qui n'a rien produit
                                // (tout le monde à 0) partage en parts ÉGALES : sans ça personne ne serait
                                // éligible et le coffre ne se viderait jamais.
                                final flat = members.every((m) => m.contribution <= 0);
                                double weightOf(_ButinShare m) => flat ? 1.0 : m.contribution.toDouble();

                                if (money > 0) _shareMoney(members, money, weightOf, rng);

                                // Repli sur tout le monde si le clan n'a que des chefs (clan de test à un
                                // membre) : mieux vaut un chef servi qu'un coffre qui ne se vide pas.
                                var takers = members.where((m) => !m.admin).toList();
                                if (takers.isEmpty) takers = List<_ButinShare>.from(members);

                                final valued = items.where((d) => _itemCostOf(d) > 0).toList()
                                    ..sort((a, b) => _itemCostOf(b).compareTo(_itemCostOf(a)));
                                final trinkets = items.where((d) => _itemCostOf(d) <= 0).toList();

                                _shareValuedItems(takers, valued, weightOf, rng);
                                _shareTrinkets(takers, trinkets, rng);

                                members.sort((a, b) => b.contribution.compareTo(a.contribution));
                                return members;
    }

    // L'argent au plus fort reste : chacun reçoit sa part entière, et les pièces qui restent (le
    // compte ne tombe jamais juste) vont aux plus grosses fractions. Les ex æquo sont départagés
    // par un tirage EXPLICITE : le tri de Dart n'est pas garanti stable, et un simple mélange
    // préalable ne suffirait donc pas à empêcher que ce soit toujours le même qui ramasse l'appoint.
    void _shareMoney(List<_ButinShare> all, int money,
                     double Function(_ButinShare) weightOf, Random rng) {

                            final total = all.fold<double>(0, (s, m) => s + weightOf(m));
                            if (total <= 0) return;

                            final frac = <_ButinShare, double>{};
                            final luck = <_ButinShare, double>{};
                            var   given = 0;
                            for (final m in all) {
                                final exact = money * weightOf(m) / total;
                                m.money  = exact.floor();
                                given   += m.money;
                                frac[m]  = exact - exact.floorToDouble();
                                luck[m]  = rng.nextDouble();
                            }

                            final order = List<_ButinShare>.from(all)
                                ..sort((a, b) {
                                    final c = frac[b]!.compareTo(frac[a]!);
                                    return c != 0 ? c : luck[a]!.compareTo(luck[b]!);
                                });
                            for (var i = 0; i < money - given && i < order.length; i++) {
                                order[i].money += 1;
                            }
    }

    // Les objets qui valent quelque chose, du plus cher au moins cher. À chaque tour le gagnant est
    // TIRÉ AU SORT, avec une chance proportionnelle à ce qui lui manque encore pour atteindre sa
    // part idéale : le partage colle donc à la proportionnalité sans jamais devenir prévisible.
    // L'ordre décroissant n'est pas cosmétique — un gros objet placé en dernier creuserait un écart
    // que plus rien ne pourrait rattraper, alors qu'au début tous les déficits sont assez larges
    // pour l'absorber.
    void _shareValuedItems(List<_ButinShare> takers, List<Dvidle> items,
                           double Function(_ButinShare) weightOf, Random rng) {

                            if (takers.isEmpty || items.isEmpty) return;
                            final total = takers.fold<double>(0, (s, m) => s + weightOf(m));
                            if (total <= 0) return;

                            final cost = items.fold<int>(0, (s, d) => s + _itemCostOf(d));
                            for (final m in takers) {
                                m.target = cost * weightOf(m) / total;
                            }

                            // Ce qui manque encore à un joueur pour atteindre sa part idéale : c'est
                            // CETTE quantité qui pondère le tirage, et elle fond à chaque objet reçu.
                            double deficitOf(_ButinShare m) {
                                final d = m.target - m.received;
                                return d > 0 ? d : 0.0;
                            }

                            for (final item in items) {
                                var pool = 0.0;
                                for (final m in takers) { pool += deficitOf(m); }

                                // Plus personne en déficit alors qu'il reste des objets (le coffre est
                                // plus riche que la somme des parts) : le tirage repart des poids, sinon
                                // il n'aurait plus de matière.
                                final draw = rng.nextDouble() * (pool > 0 ? pool : total);
                                var acc = 0.0;
                                var winner = takers.last;
                                for (final m in takers) {
                                    acc += pool > 0 ? deficitOf(m) : weightOf(m);
                                    if (draw < acc) { winner = m; break; }
                                }
                                winner.items.add(item);
                                winner.received += _itemCostOf(item);
                            }
    }

    // Les babioles (coût 0) ferment le partage. Elles ne pèsent rien dans la balance : elles servent
    // à CONSOLER ceux que le tirage des objets de valeur a lésés. On sert donc d'abord le plus lésé,
    // puis on tourne — deux babioles ne s'empilent pas sur la même tête.
    void _shareTrinkets(List<_ButinShare> takers, List<Dvidle> items, Random rng) {

                                if (takers.isEmpty || items.isEmpty) return;
                                final luck = <_ButinShare, double>{
                                    for (final m in takers) m: rng.nextDouble()
                                };
                                final order = List<_ButinShare>.from(takers)
                                    ..sort((a, b) {
                                        final c = (b.target - b.received).compareTo(a.target - a.received);
                                        return c != 0 ? c : luck[a]!.compareTo(luck[b]!);
                                    });
                                final pool = List<Dvidle>.from(items)..shuffle(rng);
                                for (var i = 0; i < pool.length; i++) {
                                    order[i % order.length].items.add(pool[i]);
                                }
    }

    // Détection de SA part : le doc joueur porte `pending_butin`. Appelée à chaque changement du doc
    // (vigilance temps réel) ET une fois au démarrage de celle-ci — un drapeau DÉJÀ posé au moment
    // où l'on s'abonne n'émet aucun changement, et c'est exactement le cas du joueur sans appareil
    // dont un parent vient de prendre la place.
    // Renvoie true si une célébration a été lancée : l'appelant s'abstient alors des autres.
    Future<bool> _checkPendingButin() async {

                                if (_butinChecking || _userId.isEmpty) return false;
                                final ctx = await _butinCtx();
                                if (ctx == null) return false;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();

                                try {
                                    final me = await _cloud?.read("workers", "clans_players/$clanId/players",
                                        _userId, ownerId: clanSecret, region: region);
                                    if (me == null || me.get("pending_butin") != true) return false;

                                    // Le dernier contributeur voyage sur le doc, posé par la distribution :
                                    // à cet instant sa contribution est déjà remise à zéro en base, il n'y a
                                    // plus que ces deux champs pour s'en souvenir.
                                    await _prepareButinKiss(
                                        me.get("butin_low_id")?.toString()   ?? "",
                                        me.get("butin_low_name")?.toString() ?? "");

                                    _butinChecking = true;                  // relâché par on_celebration_end
                                    final played = await _claimButin(clanId, clanSecret, region);
                                    if (!played) _butinChecking = false;    // personne ne viendrait le relâcher
                                    return played;
                                } catch (e) {
                                    deva_log("error", "[butin] _checkPendingButin FAILED: $e");
                                    _butinChecking = false;
                                    return false;
                                }
    }

    // Réclamation : les objets qui portent son nom passent dans son inventaire, le drapeau retombe,
    // et SEULEMENT ENSUITE l'animation part. Elle part TOUJOURS, même les mains vides. Ne renvoie
    // false que si l'écriture a échoué — l'appelant rend alors sa garde, que rien ne relâcherait.
    Future<bool> _claimButin(String clanId, String clanSecret, String region) async {

                                final coll  = "clans_items/$clanId/items";
                                final pcoll = "clans_players/$clanId/players";
                                final docs  = await _cloud?.list("workers", coll, region: region) ?? [];

                                // Ce qui m'attend : les objets marqués à mon nom, et l'écart entre ce que
                                // contient mon portefeuille et le repère posé par la distribution.
                                final wid   = _playerWalletId(_userId);
                                final mine  = <Dvidle>[];
                                var   gained    = 0;
                                var   walletQty = 0;
                                var   walletOld = 0;
                                var   hasWallet = false;
                                // Le document du coffre porte `notes_shown` : ce que CETTE ouverture vient
                                // de révéler (posé par _distributeButin, dans le même batch que la remise
                                // à zéro).
                                Dvidle? butinDoc;
                                for (final d in docs) {
                                    final id = d.get("docId")?.toString() ?? "";
                                    if (id.isEmpty) continue;
                                    if (id == _butinDocId) {
                                        butinDoc = d;
                                        continue;
                                    }
                                    if (id == wid) {
                                        walletQty = int.tryParse(d.get("quantity")?.toString() ?? "0") ?? 0;
                                        walletOld = int.tryParse(d.get("last_quantity")?.toString() ?? "0") ?? 0;
                                        hasWallet = true;
                                        gained    = (walletQty - walletOld) > 0 ? walletQty - walletOld : 0;
                                        continue;
                                    }
                                    if ((d.get("to_owner")?.toString() ?? "") == _userId) mine.add(d);
                                }

                                final writes = <DvCloudWrite>[];
                                for (final d in mine) {
                                    final doc = Dvidle({});
                                    doc.set("ownerId",  clanSecret);
                                    doc.set("owner",    _userId);
                                    // Chaîne VIDE et non champ omis : le deep-merge dvcloud préserverait un
                                    // champ absent, et l'objet resterait éternellement « en chemin ».
                                    doc.set("to_owner", "");
                                    writes.add(DvCloudWrite.set(coll, d.get("docId").toString(), doc));
                                }
                                // Le repère du portefeuille est recalé sur son solde : ce que le joueur
                                // vient de voir devient « déjà vu ». C'est ICI que ça se joue et nulle
                                // part ailleurs — la distribution ne rafraîchit ce repère que pour ceux
                                // à qui elle verse de l'argent, si bien qu'une ouverture sans argent
                                // rejouerait indéfiniment le gain de la précédente.
                                if (hasWallet && walletQty != walletOld) {
                                    final purse = Dvidle({});
                                    purse.set("ownerId",       clanSecret);
                                    purse.set("last_quantity", walletQty);
                                    writes.add(DvCloudWrite.set(coll, wid, purse));
                                }
                                // Le drapeau retombe dans le MÊME lot : rien ne se rejouera au prochain
                                // démarrage, et deux appareils du même joueur ne se disputent pas la part.
                                final flag = Dvidle({});
                                flag.set("ownerId",       clanSecret);
                                flag.set("pending_butin", false);
                                writes.add(DvCloudWrite.set(pcoll, _userId, flag));
                                await _cloud?.batchWrite("workers", writes, region: region);

                                // Une part vide se célèbre AUSSI : l'animation est le moment de clan, pas
                                // la récompense. Celui qui n'a rien gagné la voit comme les autres, et
                                // l'écran le lui dit franchement.
                                // La part est FIGÉE ici : l'écran de récompenses est empilé pendant
                                // l'animation, quand la base ne dit déjà plus ce qui vient d'être gagné.
                                _butinClaimRows = await _butinRewardRows(mine, gained);
                                // Les notes des chefs, figées pour la même raison : butin_notes_page
                                // n'est empilée qu'après l'animation, quand `notes_shown` a pu changer.
                                _butinNotesText = _buildButinNotesText(butinDoc);
                                deva_log("info", "[butin] part reçue : $gained pièce(s), ${mine.length} objet(s)");

                                // La cérémonie a produit ce qu'elle devait produire : elle est finie pour
                                // cet appareil, l'animation prend la suite et l'écran de rituel disparaîtra
                                // sous elle. Sans cette remise à zéro, l'écran ne pourrait plus être empilé
                                // à la prochaine ouverture (_openingRole sert aussi de garde).
                                _resetOpening();

                                // Le miroir de la grille d'items est faux (les objets viennent de changer de
                                // mains) : l'inventaire doit être juste quand le joueur y reviendra.
                                await _loadClanItems(clanId, clanSecret, region);
                                await _celebrateButin();
                                return true;
    }

    // Texte Markdown des notes révélées par CETTE ouverture (`notes_shown`, posé par
    // _distributeButin) : un bloc par note, en-tête centré (le prénom de son auteur) puis le
    // texte — même idiome que les en-têtes de date du journal (cf. worker._StoryBuffer). VIDE si
    // personne n'en a écrit, ce qui fait sauter butin_notes_page (worker.on_butin_rewards_ok).
    String _buildButinNotesText(Dvidle? doc) {

                                final notes = doc?.get("notes_shown");
                                if (notes is! List || notes.isEmpty) return "";
                                final blocks = <String>[];
                                for (final n in notes) {
                                    if (n is! Dvidle) continue;
                                    final text = n.get("text")?.toString() ?? "";
                                    if (text.isEmpty) continue;
                                    final name = n.get("author_name")?.toString() ?? "";
                                    blocks.add(name.isEmpty ? text : "<center>— $name —</center>\n\n$text");
                                }
                                return blocks.join("\n\n\n");
    }

    // Une ligne de liste par objet gagné : miniature du type, nom propre du document s'il en a un,
    // sinon le libellé du catalogue résolu dans la langue courante (idiome _loadButinRows).
    // L'argent de poche n'a pas de phrase à lui : il paraît comme les autres gains, en TÊTE de la
    // liste, sous la forme de son propre item — la bourse, avec le montant en pastille. C'est le
    // même objet que dans le coffre, il se lit donc sans qu'on ait à l'expliquer.
    Future<List<Map<String, dynamic>>> _butinRewardRows(List<Dvidle> items, int money) async {

                                final rows = <Map<String, dynamic>>[];
                                if (money > 0) {
                                    final image = (await deva_get("items.argent_poche.image"))?.toString() ?? "";
                                    final label = TranslationRegistry.processLabel(
                                        (await deva_get("items.argent_poche.label"))?.toString() ?? "");
                                    final desc  = TranslationRegistry.processLabel(
                                        (await deva_get("items.argent_poche.description"))?.toString() ?? "");
                                    rows.add({
                                        "id":    _playerWalletId(_userId),
                                        "image": image,
                                        "label": label,
                                        "desc":  desc,
                                        "badge": "($money)",
                                    });
                                }
                                for (final d in items) {
                                    final type  = d.get("type")?.toString() ?? "";
                                    final name  = d.get("name")?.toString() ?? "";
                                    final qty   = int.tryParse(d.get("quantity")?.toString() ?? "1") ?? 1;
                                    final image = (await deva_get("items.$type.image"))?.toString() ?? "";
                                    final label = TranslationRegistry.processLabel(
                                        (await deva_get("items.$type.label"))?.toString() ?? "");
                                    final desc  = TranslationRegistry.processLabel(
                                        (await deva_get("items.$type.description"))?.toString() ?? "");
                                    rows.add({
                                        "id":    d.get("docId")?.toString() ?? "",
                                        "image": image,
                                        "label": name.isNotEmpty ? name : label,
                                        "desc":  desc,
                                        "badge": qty > 1 ? "($qty)" : "",
                                    });
                                }
                                return rows;
    }

    // Prépare (ou efface) l'attaque de bisous, à partir du dernier contributeur posé sur le doc
    // joueur par la distribution. Rien à afficher si le clan n'a que des chefs (`lowId` vide) — et
    // rien non plus sur l'appareil du principal intéressé : le message parle de lui, pas à lui.
    // Texte résolu dans la langue COURANTE (repli fr), même idiome que _showClanWelcomeAnimation.
    Future<void> _prepareButinKiss(String lowId, String lowName) async {

                                _butinKissText = "";
                                if (lowId.isEmpty || lowName.isEmpty || lowId == _userId) return;

                                final lang = TranslationRegistry.currentLang;
                                var text = (await deva_get("lang.translations.butin_kiss.$lang"))?.toString() ?? "";
                                if (text.isEmpty) {
                                    text = (await deva_get("lang.translations.butin_kiss.fr"))?.toString() ?? "";
                                }
                                if (text.isEmpty) return;
                                _butinKissText = text.replaceAll("@@@name@@@", lowName);
    }

    // Célébration de l'ouverture (interlude "butin"). Texte pré-résolu dans la langue COURANTE ; le
    // mot encadré [[…]] ressort en braise (highlight_color de commons/butin_label).
    // L'écran de récompenses n'est PAS empilé ici : la scène le fait elle-même au bon acte
    // (worker.butin_reveal), quand la nappe d'or couvre tout — sinon la bascule se verrait.
    Future<void> _celebrateButin() async {

                                final lang = TranslationRegistry.currentLang;
                                var text = (await deva_get("lang.translations.butin_anim.$lang"))?.toString() ?? "";
                                if (text.isEmpty) text = (await deva_get("lang.translations.butin_anim.fr"))?.toString() ?? "";
                                ActionRegistry.get("dvinterlude.play.butin")?.call(null, {"text": text});
    }

    // Tirée par l'ACTE de la scène qui vient de couvrir l'écran d'or : on empile l'écran de
    // récompenses SOUS la nappe, que le dernier acte dissout. Gardée par le drapeau de la
    // célébration — sur le banc de test (burn_page), où l'on rejoue les interludes à vide, elle ne
    // doit emmener personne nulle part.
    Future<void> butin_reveal(dynamic caller, dynamic event) async {

                                if (!_butinChecking) return;
                                DvOrb.navigate_new("butin_rewards_page");
    }

    // Écran de récompenses : pur affichage de la part figée à la réclamation. Il ne lit RIEN — en
    // base, tout a déjà changé de mains.
    // Le message d'encouragement (l'attaque de bisous) suit la même règle : figé à la réclamation,
    // vide sur l'appareil de celui qu'il nomme, donc son parchemin reste caché chez lui.
    Future<void> on_butin_rewards_appear(dynamic caller, dynamic event) async {

                                try {
                                    ActionRegistry.get("dvlist.set_rows")?.call(null, _butinClaimRows);

                                    final kiss = await DvOrb.wait_for_shape("butin_rewards_page/kiss");
                                    await _syncLabel(kiss, "butin_rewards_page/kiss", _butinKissText);
                                    await _syncVisible(kiss, "butin_rewards_page/kiss", _butinKissText.isNotEmpty);
                                } catch (e) {
                                    deva_log("error", "[butin] on_butin_rewards_appear FAILED: $e");
                                }
    }

    // « ok » : on referme le butin. C'est ce tap qui RÉTABLIT la musique de fond — l'interlude du
    // butin est déclaré `music: hold`, il a fait taire l'ambiance sans jamais la rendre, exprès :
    // le morceau de victoire déborde le visuel de ~1,5 s et l'ambiance du donjon, en repartant à la
    // fin de la scène, lui passait dessus au moment précis où le joueur découvrait sa part.
    // navigate_reset (et non un retour) : la page a été empilée par l'animation par-dessus n'importe
    // quel écran.
    // On ne rend PAS la main au dashboard tout de suite : le clan vient de vivre son grand moment,
    // c'est là — et pas trois écrans plus loin — qu'on lui propose de le raconter.
    // S'il y a une note de chef à lire (_butinNotesText, figé par _claimButin), elle passe D'ABORD :
    // butin_notes_page mène ensuite elle-même au conte. Sans note, le parcours ne change pas.
    Future<void> on_butin_rewards_ok(dynamic caller, dynamic event) async {

                                ActionRegistry.get("dvsound.ambiance.resume")?.call(null, null);
                                DvOrb.navigate_reset(_butinNotesText.isEmpty ? "butin_tale_page" : "butin_notes_page");
    }

    // --- Notes des chefs, révélées ------------------------------------------------------------
    // Lecture forcée (2,5 s sans bouton) des notes déposées avant l'ouverture — le temps que tout
    // le monde ait VRAIMENT lu avant de pouvoir filer vers le conte.

    // Apparition : pose le texte (déjà figé par _claimButin), lance le halo, cache « ok » puis le
    // révèle après 2,5 s. Le jeton `_butinNotesTick` écarte un minuteur d'un affichage précédent qui
    // rendrait le bouton d'un écran qu'on a déjà quitté (retour rapide, double appel, etc.).
    Future<void> on_butin_notes_appear(dynamic caller, dynamic event) async {

                                try {
                                    final story = await DvOrb.wait_for_shape("butin_notes_page/story");
                                    if (story is DvLabel) { story.write(_butinNotesText); story.refreshUI(); }

                                    final ok = await DvOrb.wait_for_shape("butin_notes_page/ok");
                                    await _syncVisible(ok, "butin_notes_page/ok", false);

                                    ActionRegistry.get("dvflame.start.notehalo")?.call(null, null);

                                    final tick = ++_butinNotesTick;
                                    await Future.delayed(const Duration(milliseconds: 2500));
                                    if (tick != _butinNotesTick) return;   // écran quitté entre-temps
                                    await _syncVisible(ok, "butin_notes_page/ok", true);
                                } catch (e) {
                                    deva_log("error", "[butin] on_butin_notes_appear FAILED: $e");
                                }
    }

    // « ok » : referme les notes, place au conte comme si la lecture n'avait jamais eu lieu.
    Future<void> on_butin_notes_ok(dynamic caller, dynamic event) async {

                                ActionRegistry.get("dvflame.stop.notehalo")?.call(null, null);
                                DvOrb.navigate_reset("butin_tale_page");
    }

    // --- Le conte du butin -------------------------------------------------------------------
    // Dernière marche de la cérémonie. L'écran est le même pour tous, l'icône de partage comprise :
    // tout joueur qui a participé au butin peut raconter l'aventure, pas seulement les chefs — le
    // partage effectif reste de toute façon un geste conscient (share sheet Android). L'icône est
    // donc visible par défaut en conf, sans détour par un handler d'appear.

    // « ok » : on referme pour de bon. L'ambiance a déjà été rendue par on_butin_rewards_ok.
    Future<void> on_butin_tale_ok(dynamic caller, dynamic event) async {

                                DvOrb.navigate_reset("dashboard");
    }

    // Tap sur l'icône : on demande au journal de se raconter. Rien n'est généré ici — on arme le
    // mode conte et on ouvre log_page, qui possède déjà tout ce qu'il faut (le texte défilant ET
    // l'icône de partage). Le récit se fabrique dans on_log_appear, là où le journal est lu.
    Future<void> on_butin_tale_share(dynamic caller, dynamic event) async {

                                _logNarrative = true;
                                _logClanWide  = true;    // le conte est celui du CLAN, jamais d'un joueur
                                _logPlayerId  = "";
                                DvOrb.navigate_new("log_page");
    }

}

// Part d'un joueur dans l'ouverture du butin : ce qu'il a contribué, ce qu'il reçoit. Remplie par
// worker._computeButinShares, consommée par la distribution (écriture) et par le journal.
// `target` et `received` sont exprimés en COÛT d'objets : ils ne servent qu'au tirage et à la
// trace, jamais au joueur — lui ne voit que son argent et ses objets.
class _ButinShare {

    final String id;
    final String name;
    final bool   admin;
    // XP versés au butin depuis la dernière ouverture (xp - last_butin_xp, borné à 0). Ne sert que
    // de POIDS relatif : cette unité n'est pas celle de la jauge du coffre (cf. _refreshRoster).
    final int    contribution;
    // Drapeau pending_butin AVANT distribution : une part encore non réclamée interdit de
    // rafraîchir le repère `last_quantity` du portefeuille, sous peine d'effacer un gain jamais vu.
    final bool   pending;

    int money = 0;
    final List<Dvidle> items = [];
    double target   = 0;
    double received = 0;

    _ButinShare({

            required this.id,
            required this.name,
            required this.admin,
            required this.contribution,
            required this.pending,
    });
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
