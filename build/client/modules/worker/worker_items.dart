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
// --- worker extension — Objets du clan
// -----------------------------------------------------------------------------
extension Worker_items on worker {

    void _register_items() {

                                // Écran Items : bascule admin/« bientôt disponible », lecture de
                                // clans_items, menu contextuel d'un item et dépôts.
                                ActionRegistry.register("worker.on_items_appear",           on_items_appear);

                                ActionRegistry.register("worker.items_selector",            items_selector);

                                ActionRegistry.register("worker.item_give",                 item_give);

                                // Fiche d'un objet (option « Voir », commune à tout le catalogue) :
                                // grande image, description, bouton Appliquer optionnel.
                                ActionRegistry.register("worker.item_view",                 item_view);

                                ActionRegistry.register("worker.on_item_view_appear",       on_item_view_appear);

                                ActionRegistry.register("worker.on_item_view_apply",        on_item_view_apply);

                                // Titres (première famille d'items) : porter le titre d'un personnage,
                                // celui du clan (chefs seulement), les retirer, et jeter un item
                                // (toutes familles).
                                ActionRegistry.register("worker.title_apply_player",        title_apply_player);

                                ActionRegistry.register("worker.title_unapply_player",      title_unapply_player);

                                ActionRegistry.register("worker.title_apply_clan",          title_apply_clan);

                                ActionRegistry.register("worker.title_unapply_clan",        title_unapply_clan);

                                ActionRegistry.register("worker.item_trash",                item_trash);

                                // Don d'un objet à un joueur du clan (option « Donner ») : écran de
                                // choix du destinataire, et tap sur une tuile joueur.
                                ActionRegistry.register("worker.on_give_appear",            on_give_appear);

                                ActionRegistry.register("worker.give_to_player",            give_to_player);

    }

    //-----------------------------------------------------------------------
    //-- Écran Items (clans_items) ------------------------------------------
    //-----------------------------------------------------------------------

    // Affichage de l'onglet Items. Ouvert à TOUS les joueurs : chacun y voit ses propres items et
    // sa bourse. Ce qui appartient au CLAN — le coffre et le portefeuille du coffre — reste réservé
    // aux admins, mais par le FILTRE de _pushClanItems (owner == clanId), pas par l'écran : c'est
    // une règle de contenu, pas d'accès.
    // _ensureIsAdmin est appelé AVANT le chargement, et pas seulement pour l'affichage : il pose
    // _isAdmin, que _pushClanItems et items_selector lisent ensuite. Sans lui, un chef verrait son
    // écran amputé du coffre le temps que la détection tombe.
    // _syncVisible sur la grille reste utile : un appareil qui a connu la version « réservée aux
    // chefs » porte un registry persisté à visible:false, et le widget renaîtrait caché.
    Future<void> on_items_appear(dynamic caller, dynamic event) async {

                                // wait_for_shape (et non get_shape_by_id) : à la première ouverture de
                                // l'onglet, les shapes de la page peuvent n'être pas encore construites —
                                // la bascule serait alors silencieusement perdue.
                                final grid = await DvOrb.wait_for_shape("items/explorer");

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        await _ensureIsAdmin(clanId, clanSecret, region);
                                        await _refreshTitleState(clanId, clanSecret, region);
                                    }

                                    await _syncVisible(grid, "items/explorer", true);

                                    await _loadClanItems(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[items] on_items_appear FAILED: $e");
                                }

                                // Après le chargement (coffre/bourse poussés) : comme on_dashboard_appear,
                                // dvtuto.enter est appelé ici plutôt que via appear: (non attendue), pour ne
                                // pas spotlighter la grille avant que ses tuiles ne soient en place.
                                await deva_do("dvtuto.enter");
    }

    Future<void> _refreshTitleState(String clanId, String clanSecret, String region) async {

                                if (clanId.isEmpty || clanSecret.isEmpty) return;
                                try {
                                    final p = await _cloud?.read("workers",
                                        "clans_players/$clanId/players", _userId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    _playerTitleIdx = int.tryParse(p.get("title_idx")?.toString() ?? "-1") ?? -1;
                                    if (_isAdmin) {
                                        final c = await _cloud?.read("workers", "clans", clanId,
                                            ownerId: clanSecret, region: region) ?? Dvidle({});
                                        _clanTitleIdx = int.tryParse(c.get("title_idx")?.toString() ?? "-1") ?? -1;
                                    }
                                } catch (e) {
                                    deva_log("error", "[titres] _refreshTitleState FAILED: $e");
                                }
    }

    Future<void> _loadClanItems(String clanId, String clanSecret, String region) async {

                                if (clanId.isEmpty) return;
                                try {
                                    var docs = await _cloud?.list(
                                        "workers", "clans_items/$clanId/items", region: region) ?? [];
                                    // Coffre + portefeuille créés ici s'ils manquent (clan né avant eux) :
                                    // la liste qu'on vient de faire dit exactement ce qui existe déjà, pas
                                    // besoin d'une lecture par document. Réservé aux ADMINS : le mobilier
                                    // du clan n'est pas au joueur, et lui non plus ne le voit pas — le lui
                                    // faire créer serait une écriture aveugle sur un objet qui ne le
                                    // regarde pas.
                                    if (_isAdmin) {
                                        docs = await _ensureButinDocs(clanId, clanSecret, region, docs);
                                    }

                                    _clanItemDocs = docs;
                                    _clanItemsOf  = clanId;
                                    await _refreshSharedTypes(docs);
                                    _pushClanItems();
                                } catch (e) {
                                    deva_log("error", "[items] _loadClanItems FAILED: $e");
                                }
    }

    Future<void> _refreshSharedTypes(List<Dvidle> docs) async {

                                _sharedItemTypes.clear();
                                for (final t in docs.map((d) => d.get("type")?.toString() ?? "").toSet()) {
                                    if (t.isEmpty) continue;
                                    if ((await deva_get("items.$t.shared")) == true) _sharedItemTypes.add(t);
                                }
    }

    // Construit les tuiles depuis le miroir local et les pousse. Ne lit RIEN : c'est ce qui permet
    // de rendre un déplacement visible tout de suite après l'écriture, sans aller-retour réseau.
    void _pushClanItems() {

                                final clanId  = _clanItemsOf;
                                final docs    = _clanItemDocs;
                                final entries = <Map<String, dynamic>>[];
                                for (final d in docs) {
                                    final id = d.get("docId")?.toString() ?? "";
                                    if (id.isEmpty) continue;
                                    final owner = d.get("owner")?.toString() ?? "";
                                    final type  = d.get("type")?.toString() ?? "";
                                    final mine  = owner.isNotEmpty && owner == _userId;
                                    final clans = owner.isNotEmpty && owner == clanId;
                                    // Un item DU CLAN n'est vu que des chefs — sauf s'il est `shared`
                                    // (le titre de clan) : celui-là est la fierté de tout le monde, il
                                    // paraît chez tous. Le DROIT d'agir dessus, lui, reste au chef
                                    // (items_selector).
                                    final shared = _sharedItemTypes.contains(type);
                                    if (!mine && !(clans && (_isAdmin || shared))) continue;

                                    // Une bourse est un CONTENANT : `quantity` absente veut dire
                                    // vide (0), pas « un exemplaire ». La bourse d'un joueur naît
                                    // justement sans le champ (cf. _ensurePlayerWallet, qui ne le
                                    // pose jamais pour ne pas risquer d'écraser un solde) — avec le
                                    // défaut des objets elle s'afficherait à 1 alors qu'elle est vide.
                                    final purse = type == "argent_poche";
                                    final qty = int.tryParse(
                                        d.get("quantity")?.toString() ?? (purse ? "0" : "1")) ?? 0;
                                    // Titre : la tuile ne porte AUCUN libellé (DvExplorer en mode
                                    // `data` n'en affiche pas), et deux titres du même type ont la
                                    // même image. Le seul différenciateur possible est la pastille :
                                    // on y met le NIVEAU REQUIS (5, 10, 15…), court et parlant.
                                    final titleIdx = int.tryParse(d.get("title_idx")?.toString() ?? "-1") ?? -1;
                                    entries.add({
                                        "id":        id,
                                        "type":      type,
                                        "name":      d.get("name")?.toString() ?? "",
                                        "quantity":  qty,
                                        // Pastille : `quantity` est le CONTENU d'un contenant (doses
                                        // d'une fiole, argent d'une bourse), jamais un nombre
                                        // d'exemplaires — un item est toujours une seule chose. On ne
                                        // l'affiche donc que si elle dit quelque chose : un « 1 » sur
                                        // chaque tuile ne serait que du bruit. La bourse fait
                                        // exception et montre TOUJOURS sa somme, même à 0 : c'est
                                        // l'information qu'on vient chercher en la regardant.
                                        "badge": titleIdx >= 0
                                            ? "${(titleIdx + 1) * 5}"
                                            : (purse ? "$qty" : (qty > 1 ? "$qty" : "")),
                                        "cost":       int.tryParse(d.get("cost")?.toString() ?? "0") ?? 0,
                                        "owner":      owner,
                                        "last_used":  d.get("last_used")?.toString() ?? "",
                                        // Transmis à l'action de l'option (title_apply_*/item_trash) :
                                        // le handler sait quel rang appliquer sans relire le document.
                                        "title_idx":  titleIdx,
                                    });
                                }

                                ActionRegistry.get("dvexplorer.set_entries")?.call(null, entries);
                                deva_log("info", "[items] ${entries.length} item(s) poussé(s) "
                                    "(${docs.length} en miroir)");
    }

    // Document du miroir portant cet itemId, ou null s'il n'y est pas. Le miroir est la seule
    // source de ce que la grille montre : un item qu'on vient d'y voir y est forcément.
    Dvidle? _mirrorDoc(String itemId) {

                                for (final d in _clanItemDocs) {
                                    if ((d.get("docId")?.toString() ?? "") == itemId) return d;
                                }
                                return null;
    }

    // Applique au miroir un changement DÉJÀ écrit en base, sans pousser (l'appelant pousse une
    // fois, même s'il touche plusieurs items). Renvoie faux si l'item n'y est pas : le miroir est
    // alors incomplet et l'appelant doit relire la collection plutôt que d'afficher un mensonge.
    bool _patchLocalItem(String itemId, {String? owner, int? quantity}) {

                                for (final d in _clanItemDocs) {
                                    if ((d.get("docId")?.toString() ?? "") != itemId) continue;
                                    if (owner    != null) d.set("owner",    owner);
                                    if (quantity != null) d.set("quantity", quantity);
                                    return true;
                                }
                                return false;
    }

    // Retire un item SUPPRIMÉ (pas déplacé) du miroir local. Même contrat que _patchLocalItem :
    // faux si l'item n'y était pas, l'appelant doit alors relire la collection plutôt que
    // d'afficher une tuile qui n'existe plus.
    bool _removeLocalItem(String itemId) {

                                final before = _clanItemDocs.length;
                                _clanItemDocs.removeWhere((d) => (d.get("docId")?.toString() ?? "") == itemId);
                                return _clanItemDocs.length != before;
    }

    // Sélecteur du menu d'un item : reçoit la charge de l'item (dont `options`, les clefs que
    // son TYPE accepte, déclarées en conf) et décide ce qui est réellement proposé. La conf
    // propose, le worker arbitre : ici, on ne peut pas utiliser un item dont il ne reste rien.
    Future<Map<String, dynamic>> items_selector(dynamic caller, dynamic event) async {

                                final data = (event is Map) ? event : const {};

                                // Le coffre n'a plus d'« option seule » : depuis l'ajout de `item_view`
                                // (commune à tout le catalogue, cf. items-base-global.yml), il porte
                                // désormais `item_open` + `item_view` comme tout autre item — traités
                                // par la boucle ci-dessous, aucun cas particulier ici.

                                final raw  = data["options"];
                                final opts = (raw is List) ? raw.map((e) => e.toString()).toList() : <String>[];
                                final qty  = int.tryParse(data["quantity"]?.toString() ?? "0") ?? 0;

                                final id     = data["id"]?.toString() ?? "";
                                final owner  = data["owner"]?.toString() ?? "";
                                final tIdx   = int.tryParse(data["title_idx"]?.toString() ?? "-1") ?? -1;

                                // Un item qui n'est pas à moi n'est là que parce que le clan le partage
                                // (titre de clan, cf. `shared`) : je peux le VOIR (item_view, si le type
                                // la déclare — c'est le cas de tout le catalogue), je n'ai rien d'autre
                                // à en faire. Seul un chef décide de porter ou de jeter le titre du clan.
                                if (owner.isNotEmpty && owner != _userId && !_isAdmin) {
                                    return {
                                        "selectable": opts.contains("item_view") ? ["item_view"] : [],
                                        "disabled": [],
                                    };
                                }

                                final selectable = <String>[];
                                final disabled   = <String>[];
                                for (final o in opts) {
                                    // « Voir » et « Ouvrir le coffre » : jamais arbitrées, toujours
                                    // proposées si le type les déclare (item_open n'est déclarée que
                                    // par `butin`, déjà filtré aux admins par worker._pushClanItems).
                                    if (o == "item_view" || o == "item_open") { selectable.add(o); continue; }
                                    // Remettre de l'argent dans le coffre : réservé aux CHEFS, et à
                                    // leur PROPRE bourse — un chef voit aussi les items du clan, et
                                    // l'on ne vide pas la bourse d'un autre. Absente (et non grisée)
                                    // pour les autres : une option qu'on n'aura jamais le droit de
                                    // toucher n'a rien à faire dans le menu. Absente aussi sur une
                                    // bourse VIDE : il n'y a rien à déposer, et le chef — seul à qui
                                    // elle est proposée — sait déjà que l'option existe. La bourse
                                    // ne portant que celle-ci, le tap n'ouvre alors aucun menu.
                                    if (o == "item_to_chest") {
                                        if (!_isAdmin || id != _playerWalletId(_userId)) continue;
                                        if (qty <= 0) continue;
                                        selectable.add(o);
                                        continue;
                                    }
                                    // « Porter ce titre » / « Ne plus porter ce titre » : bascule,
                                    // jamais les deux à la fois. Sur le titre DÉJÀ PORTÉ, seule
                                    // l'option de retrait est proposée — c'est le SEUL retour visuel
                                    // dont on dispose pour dire quel titre est porté — les tuiles
                                    // n'ont pas de libellé, et le jeu s'interdit les popups de
                                    // confirmation.
                                    if (o == "title_apply_player") {
                                        if (tIdx >= 0 && tIdx == _playerTitleIdx) continue;
                                        selectable.add(o);
                                        continue;
                                    }
                                    if (o == "title_unapply_player") {
                                        if (!(tIdx >= 0 && tIdx == _playerTitleIdx)) continue;
                                        selectable.add(o);
                                        continue;
                                    }
                                    if (o == "title_apply_clan") {
                                        if (!_isAdmin) continue;   // ceinture : le filtre ci-dessus l'a déjà écarté
                                        if (tIdx >= 0 && tIdx == _clanTitleIdx) continue;
                                        selectable.add(o);
                                        continue;
                                    }
                                    if (o == "title_unapply_clan") {
                                        if (!_isAdmin) continue;
                                        if (!(tIdx >= 0 && tIdx == _clanTitleIdx)) continue;
                                        selectable.add(o);
                                        continue;
                                    }
                                    selectable.add(o);
                                }
                                return {"selectable": selectable, "disabled": disabled};
    }

    // Option « Voir » : mémorise la charge de l'item et empile la fiche. Comme item_give, rien
    // n'est écrit ici.
    Future<void> item_view(dynamic caller, dynamic event) async {

                                final data = (event is Map) ? event : const {};
                                if ((data["id"]?.toString() ?? "").isEmpty) return;
                                _viewedItem = Map<String, dynamic>.from(data);
                                DvOrb.navigate_new("item_view_page");
    }

    // Apparition de la fiche : image en grand, nom, description, bouton Appliquer. Aucune
    // lecture réseau — tout vient de `_viewedItem`, déjà en main.
    Future<void> on_item_view_appear(dynamic caller, dynamic event) async {

                                _viewedApplyKey = "";
                                final type = _viewedItem["type"]?.toString() ?? "";
                                if (type.isEmpty) return;

                                // Premier fetch en `wait_for_shape` (la page vient d'être empilée, cf.
                                // on_rename_task_appear), le reste en `get_shape_by_id` — patron partagé.
                                final imgShape  = await DvOrb.wait_for_shape("item_view_page/image");
                                final nameShape = DvOrb.get_shape_by_id("item_view_page/name");
                                final descShape = DvOrb.get_shape_by_id("item_view_page/desc");

                                // Image : gabarit big du type. Patron de rename_task (set + appear() +
                                // refreshUI) — le appear() est indispensable, sinon le ImageProvider mis
                                // en cache garde l'image de la fiche précédemment ouverte.
                                final img = (await deva_get("items.$type.image"))?.toString() ?? "";
                                if (img.isNotEmpty) {
                                    imgShape?.set("shape.image", img);
                                    try { await imgShape?.appear(); } catch (e) { deva_log("warning", "[items] item_view image appear: $e"); }
                                    imgShape?.refreshUI();
                                }

                                // Nom : pour un titre, le VRAI nom du rang porté par CET objet
                                // (player_title_N / clan_title_N, cf. _titleKeyOf) — pas le libellé du
                                // type, qui ne dit que « titre de personnage ». Sinon le nom propre de
                                // l'objet s'il en a un, à défaut le libellé du type.
                                String nameToken;
                                if (type == _playerTitleType || type == _clanTitleType) {
                                    final idx = int.tryParse(_viewedItem["title_idx"]?.toString() ?? "-1") ?? -1;
                                    nameToken = _titleKeyOf(type == _playerTitleType ? "player_title" : "clan_title", idx);
                                } else {
                                    final custom = _viewedItem["name"]?.toString() ?? "";
                                    nameToken = custom.isNotEmpty
                                        ? custom
                                        : (await deva_get("items.$type.label"))?.toString() ?? "";
                                }
                                await _syncLabel(nameShape, "item_view_page/name", nameToken);

                                // Description : texte long du catalogue, token @@@T:…@@@ résolu par le
                                // widget lui-même (comme partout ailleurs, cf. _titleKeyOf). Pour un
                                // titre, le libellé du type seul ne dit que « un titre gagné… » sans dire
                                // LEQUEL : on préfixe par le nom du rang, même idiome que le badge
                                // difficulté "@@@T:dt_effort_$effort@@@ - $shown XP" (cf. plus haut).
                                final descBase = (await deva_get("items.$type.description"))?.toString() ?? "";
                                final desc = (type == _playerTitleType || type == _clanTitleType)
                                    ? "$nameToken - $descBase"
                                    : descBase;
                                await _syncLabel(descShape, "item_view_page/desc", desc);

                                // Bouton Appliquer : relit items_selector avec la MÊME charge que le menu
                                // (elle porte déjà `options`) et retient la première option qui n'est ni
                                // « Voir » ni « Jeter » — porter/retirer un titre, remettre dans le coffre,
                                // ouvrir le coffre… Pour un titre, c'est items_selector qui bascule déjà
                                // entre l'option « porter » et « ne plus porter » (jamais les deux à la
                                // fois), le bouton affiche donc directement le bon libellé. `dis` reste
                                // géré pour une éventuelle option grisée (sans être cachée) d'un futur
                                // type — bouton visible mais inerte, même retour visuel que le menu.
                                final result = await items_selector(null, _viewedItem);
                                final sel = (result["selectable"] as List? ?? const [])
                                    .map((e) => e.toString()).toList();
                                final dis = (result["disabled"] as List? ?? const [])
                                    .map((e) => e.toString()).toList();
                                bool applyDisabled = false;
                                String applyKey = "";
                                for (final k in sel) {
                                    if (k == "item_view" || k == "item_trash") continue;
                                    applyKey = k;
                                    break;
                                }
                                if (applyKey.isEmpty) {
                                    for (final k in dis) {
                                        if (k == "item_view" || k == "item_trash") continue;
                                        applyKey = k;
                                        applyDisabled = true;
                                        break;
                                    }
                                }
                                _viewedApplyKey = applyDisabled ? "" : applyKey;   // grisé = pas d'action au tap

                                final applyShape = DvOrb.get_shape_by_id("item_view_page/apply");
                                if (applyKey.isEmpty) {
                                    await _syncVisible(applyShape, "item_view_page/apply", false);
                                } else {
                                    final label = (await deva_get("registry.items/menu.options.$applyKey.shape.label"))
                                        ?.toString() ?? "";
                                    await _syncLabel(applyShape, "item_view_page/apply", label);
                                    await _syncVisible(applyShape, "item_view_page/apply", true);
                                    // Grisage à l'idiome de rename_task/confirm : opacité + tap coupé.
                                    applyShape?.set("shape.opacity", applyDisabled ? 0.3 : 0.6);
                                    applyShape?.set("shape.events.tap", !applyDisabled);
                                    applyShape?.refreshUI();
                                }
    }

    // Bouton Appliquer : dépile D'ABORD (la fiche referme sur la grille, jamais sur un écran
    // ouvert par l'option elle-même — un item_to_chest empilerait sinon money_page PAR-DESSUS la
    // fiche), puis rejoue l'action de l'option retenue avec la charge de l'item. Clef vide (bouton
    // caché ou course improbable) → simple retour.
    Future<void> on_item_view_apply(dynamic caller, dynamic event) async {

                                final key = _viewedApplyKey;
                                final item = _viewedItem;
                                DvOrb.navigate_back("testme");
                                if (key.isEmpty) return;
                                final actionKey = (await deva_get("registry.items/menu.options.$key.actions.tap"))
                                    ?.toString() ?? "";
                                if (actionKey.isNotEmpty) ActionRegistry.get(actionKey)?.call(null, item);
    }

    // Option « Donner » : n'ouvre que l'écran de choix du destinataire. Reçoit la charge de l'item
    // (le menu la transmet à l'action de l'option), comme item_to_chest.
    Future<void> item_give(dynamic caller, dynamic event) async {

                                final data    = (event is Map) ? event : const {};
                                _giveItemId   = data["id"]?.toString()   ?? "";
                                _giveItemType = data["type"]?.toString() ?? "";
                                _giveItemName = data["name"]?.toString() ?? "";
                                if (_giveItemId.isEmpty) return;
                                DvOrb.navigate_new("give_page");
    }

    // Apparition de give_page : une ligne par membre du clan (avatar + nom), MOINS le donneur
    // (on ne se donne rien à soi-même) et moins les révoqués (tombstone `enabled: false`, ignorés
    // partout). Lecture directe de clans_players : la liste ne montre qu'un nom et une image, elle
    // n'a que faire des niveaux, PV et agrégats que calcule _refreshRoster.
    Future<void> on_give_appear(dynamic caller, dynamic event) async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final rows = <Map<String, dynamic>>[];
                                try {
                                    final players = await _cloud?.list("workers",
                                        "clans_players/${ctx.get("clanId")}/players",
                                        region: ctx.get("region").toString()) ?? [];
                                    for (final p in players) {
                                        final pid = p.get("id")?.toString() ?? "";
                                        if (pid.isEmpty || pid == _userId) continue;
                                        if (p.get("enabled") == false) continue;
                                        final avatar = p.get("avatar")?.toString() ?? "";
                                        rows.add({
                                            "id":    pid,
                                            "label": _memberLabel(p.get("name")?.toString() ?? ""),
                                            // Avatar absent → le « nope » du roster, déjà préchargé.
                                            "image": avatar.isNotEmpty ? avatar : "images/medium/nope.png",
                                        });
                                    }
                                    rows.sort((a, b) => a["label"].toString()
                                        .toLowerCase().compareTo(b["label"].toString().toLowerCase()));
                                } catch (e) {
                                    deva_log("error", "[items] on_give_appear FAILED: $e");
                                }
                                // Poussée même vide : c'est ce qui affiche `empty_label` (clan d'un seul membre).
                                ActionRegistry.get("dvlist.set_rows")?.call(null, rows);
                                deva_log("info", "[items] don: ${rows.length} destinataire(s) possible(s)");
    }

    // Tap sur une ligne : l'objet change de mains. `event` = la charge BRUTE de la ligne poussée
    // ci-dessus (DvList la retransmet telle quelle), dont `id` = le userId du destinataire.
    Future<void> give_to_player(dynamic caller, dynamic event) async {

                                final m        = (event is Map) ? event : const {};
                                final targetId = m["id"]?.toString()    ?? "";
                                final target   = m["label"]?.toString() ?? targetId;
                                final itemId   = _giveItemId;
                                // La liste écarte déjà le donneur (on_give_appear) : cette garde
                                // couvre le reste (charge incomplète, écran rouvert sans objet).
                                if (itemId.isEmpty || targetId.isEmpty || targetId == _userId) {
                                    DvOrb.navigate_back();
                                    return;
                                }
                                final ctx = await _butinCtx();
                                if (ctx == null) { DvOrb.navigate_back(); return; }
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                try {
                                    await _setItemOwner(ctx, itemId, targetId);
                                    deva_log("info", "[items] '$itemId' donné à $target ($targetId)");
                                    // Miroir d'abord : la tuile quitte la grille à l'instant, sans
                                    // attendre une relecture. On ne relit que si le miroir ne connaît
                                    // pas l'item — même prudence que item_to_butin.
                                    if (_patchLocalItem(itemId, owner: targetId)) {
                                        _pushClanItems();
                                    } else {
                                        await _loadClanItems(clanId, clanSecret, region);
                                    }
                                    // Journal du clan : un don est un fait PUBLIC (à la différence du
                                    // coffre, dont le contenu doit rester une surprise). L'acteur du log
                                    // est le DONNEUR — c'est son nom que le récit met en tête.
                                    final log = Dvidle({});
                                    log.set("item_type", _giveItemType);
                                    log.set("item_name", _giveItemName);
                                    log.set("to_id",     targetId);
                                    log.set("to_name",   target);
                                    await _writeClanLog(clanId, clanSecret, region, "ItemGiven",
                                        userId: _userId, slug: itemId, data: log);
                                    // Le récit et la notification viennent APRÈS le geste et n'ont pas
                                    // le droit de le faire échouer (ils sont dans le même try).
                                    await _notifyItemGift(ctx, targetId, _giveItemType, _giveItemName);
                                } catch (e) {
                                    deva_log("error", "[items] give_to_player FAILED: $e");
                                }
                                _giveItemId   = "";
                                _giveItemType = "";
                                _giveItemName = "";
                                DvOrb.navigate_back();
    }

    //-----------------------------------------------------------------------
    //-- Titres : porter, retirer, jeter --------------------------------------
    //-----------------------------------------------------------------------
    // Un titre porté est une donnée du PORTEUR, pas de l'objet : `title_idx` sur clans_players
    // (joueur) ou clans (clan). L'item, lui, ne bouge pas — on peut donc changer d'avis autant de
    // fois qu'on veut, et le titre précédent reste dans l'inventaire pour y revenir plus tard.
    // Le deep-merge dvcloud ne sait pas RETIRER un champ : « ne plus porter de titre » s'écrit -1,
    // jamais une suppression ; toute lecture traite < 0 comme « aucun ».

    // Option « Porter ce titre » sur un titre DE PERSONNAGE. Garde de propriété : on ne porte que
    // ses propres titres (items_selector l'interdit déjà côté menu, mais un item qui ne serait
    // pas à nous n'a aucune raison de nous renommer).
    Future<void> title_apply_player(dynamic caller, dynamic event) async {

                                final data = (event is Map) ? event : const {};
                                final idx  = int.tryParse(data["title_idx"]?.toString() ?? "-1") ?? -1;
                                if (idx < 0 || (data["owner"]?.toString() ?? "") != _userId) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                try {
                                    final doc = Dvidle({});
                                    doc.set("id",        _userId);   // garantit l'id si le merge crée le doc
                                    doc.set("title_idx", idx);
                                    await _cloud?.write("workers",
                                        "clans_players/${ctx.get("clanId")}/players", _userId, doc,
                                        region: ctx.get("region").toString(),
                                        ownerId: ctx.get("clanSecret").toString());
                                    _playerTitleIdx = idx;   // le selector proposera « Ne plus porter » sur CET item
                                    deva_log("info", "[titres] titre perso #$idx porté");
                                } catch (e) {
                                    deva_log("error", "[titres] title_apply_player FAILED: $e");
                                }
    }

    // Option « Ne plus porter ce titre » sur un titre DE PERSONNAGE : le selector ne la propose
    // que sur le titre actuellement porté, donc pas de condition d'index ici — juste la garde de
    // propriété. Même idiome que le retrait fait par item_trash (ligne plus bas) : -1, jamais une
    // suppression de champ.
    Future<void> title_unapply_player(dynamic caller, dynamic event) async {

                                final data = (event is Map) ? event : const {};
                                if ((data["owner"]?.toString() ?? "") != _userId) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                try {
                                    final doc = Dvidle({});
                                    doc.set("id",        _userId);
                                    doc.set("title_idx", -1);
                                    await _cloud?.write("workers",
                                        "clans_players/${ctx.get("clanId")}/players", _userId, doc,
                                        region: ctx.get("region").toString(),
                                        ownerId: ctx.get("clanSecret").toString());
                                    _playerTitleIdx = -1;
                                    deva_log("info", "[titres] titre perso retiré");
                                } catch (e) {
                                    deva_log("error", "[titres] title_unapply_player FAILED: $e");
                                }
    }

    // Option « Porter ce titre » sur un titre DE CLAN : réservée aux chefs (le selector l'a déjà
    // filtrée, cette garde est la ceinture). Read-modify-write du document complet — pattern de
    // cette collection (cf. _persistClanAvatar) : `clans` n'a pas d'écriture partielle établie
    // ailleurs pour un champ isolé, et le doc est petit.
    Future<void> title_apply_clan(dynamic caller, dynamic event) async {

                                if (!_isAdmin) return;
                                final data = (event is Map) ? event : const {};
                                final idx  = int.tryParse(data["title_idx"]?.toString() ?? "-1") ?? -1;
                                if (idx < 0) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                try {
                                    final clan = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    clan.rem("docId");
                                    clan.set("title_idx", idx);
                                    await _cloud?.write("workers", "clans", clanId, clan,
                                        region: region, ownerId: clanSecret);
                                    _clanTitleIdx = idx;
                                    deva_log("info", "[titres] titre clan #$idx porté");
                                } catch (e) {
                                    deva_log("error", "[titres] title_apply_clan FAILED: $e");
                                }
    }

    // Option « Ne plus porter ce titre » sur un titre DE CLAN : réservée aux chefs (le selector
    // l'a déjà filtrée, cette garde est la ceinture). Même read-modify-write que title_apply_clan.
    Future<void> title_unapply_clan(dynamic caller, dynamic event) async {

                                if (!_isAdmin) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                try {
                                    final clan = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region) ?? Dvidle({});
                                    clan.rem("docId");
                                    clan.set("title_idx", -1);
                                    await _cloud?.write("workers", "clans", clanId, clan,
                                        region: region, ownerId: clanSecret);
                                    _clanTitleIdx = -1;
                                    deva_log("info", "[titres] titre clan retiré");
                                } catch (e) {
                                    deva_log("error", "[titres] title_unapply_clan FAILED: $e");
                                }
    }

    // « À la poubelle » : générique, pas réservé aux titres. Aucune confirmation (le jeu s'interdit
    // les popups) et VRAIE suppression — pas de sentinelle « corbeille » : il n'y a pas de
    // rattrapage qui pourrait ressusciter un document conservé, donc rien à protéger. Un item jeté
    // est perdu pour de bon.
    Future<void> item_trash(dynamic caller, dynamic event) async {

                                final data   = (event is Map) ? event : const {};
                                final itemId = data["id"]?.toString()    ?? "";
                                final owner  = data["owner"]?.toString() ?? "";
                                if (itemId.isEmpty) return;
                                // Ce qui n'est pas à moi ne se jette que par un chef (ceinture : le
                                // selector n'a proposé l'option à personne d'autre).
                                if (owner != _userId && !_isAdmin) return;
                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                try {
                                    await _cloud?.delete("workers", "clans_items/$clanId/items", itemId,
                                        region: region, ownerId: clanSecret);

                                    // Jeter le titre QU'ON PORTE le retire aussi de sous le nom : sinon
                                    // le personnage/clan arborerait un titre dont l'objet n'existe plus,
                                    // sans aucun moyen de le lui reprendre.
                                    final type = data["type"]?.toString() ?? "";
                                    final tIdx = int.tryParse(data["title_idx"]?.toString() ?? "-1") ?? -1;
                                    if (tIdx >= 0 && type == _playerTitleType && tIdx == _playerTitleIdx) {
                                        final doc = Dvidle({});
                                        doc.set("id",        _userId);
                                        doc.set("title_idx", -1);
                                        await _cloud?.write("workers",
                                            "clans_players/$clanId/players", _userId, doc,
                                            region: region, ownerId: clanSecret);
                                        _playerTitleIdx = -1;
                                    } else if (tIdx >= 0 && type == _clanTitleType && tIdx == _clanTitleIdx && _isAdmin) {
                                        final clan = await _cloud?.read("workers", "clans", clanId,
                                            ownerId: clanSecret, region: region) ?? Dvidle({});
                                        clan.rem("docId");
                                        clan.set("title_idx", -1);
                                        await _cloud?.write("workers", "clans", clanId, clan,
                                            region: region, ownerId: clanSecret);
                                        _clanTitleIdx = -1;
                                    }

                                    // Miroir d'abord : la tuile disparaît à l'instant, sans le temps
                                    // d'une relecture de la collection. On ne relit que si le miroir ne
                                    // connaît pas l'item — même prudence que item_to_butin/give_to_player.
                                    if (_removeLocalItem(itemId)) {
                                        _pushClanItems();
                                    } else {
                                        await _loadClanItems(clanId, clanSecret, region);
                                    }
                                    deva_log("info", "[items] '$itemId' jeté");
                                } catch (e) {
                                    deva_log("error", "[items] item_trash FAILED: $e");
                                }
    }

    // Portefeuille PERSONNEL d'un joueur (type argent_poche, owner = son userId) : un document par
    // joueur, identifiant dérivé du sien. L'identifiant fixe `wallet` est déjà pris — c'est celui
    // du portefeuille DU COFFRE, qui n'appartient à personne.
    String _playerWalletId(String userId) => "wallet_$userId";

    String _playerTitleId(int idx, String userId) => "title_p_${idx}_$userId";

    String _clanTitleId(int idx)                  => "title_c_$idx";

    // Écriture partielle du MIROIR de solde sur le doc joueur (clans_players.wallet). Toujours
    // ajoutée au MÊME batchWrite que la bourse elle-même (clans_items), pour que les deux valeurs
    // ne puissent pas diverger : le roster lit le miroir, la grille Items lit la source.
    // `id` est posé pour le cas où le merge créerait le document.
    Dvidle _walletMirror(String userId, int quantity) {

                                final doc = Dvidle({});
                                doc.set("id",     userId);
                                doc.set("wallet", quantity);
                                return doc;
    }

    // Donne l'ITEM titre de rang <idx> à son propriétaire (joueur ou clan). Idempotent par
    // construction : le docId est dérivé du rang, réécrire le même document ne fait que le
    // réécrire — pas besoin de lire avant d'écrire, ce que les règles refusent sur un document
    // absent (cf. _ensureButinDocs). Sans rattrapage, un échec ici est un titre PERDU pour de bon
    // (tracé en erreur) : le prochain palier en donnera un autre, jamais celui-ci.
    Future<void> _grantTitleItem(String clanId, String clanSecret, String region,
                                 int idx, {required bool clan}) async {

                                if (clanId.isEmpty || clanSecret.isEmpty || idx < 0) return;
                                try {
                                    final docId = clan ? _clanTitleId(idx) : _playerTitleId(idx, _userId);
                                    final type  = clan ? _clanTitleType    : _playerTitleType;
                                    final owner = clan ? clanId            : _userId;
                                    await _writeButinDoc(clanId, clanSecret, region,
                                        docId, type, owner, null, titleIdx: idx);
                                    deva_log("info", "[titres] item '$docId' attribué (rang $idx)");
                                } catch (e) {
                                    deva_log("error", "[titres] _grantTitleItem FAILED: $e");
                                }
    }

    // Pose `owner` sur un item du clan. Écriture partielle : le deep-merge dvcloud préserve tout
    // le reste (type, quantité, nom…) — l'item n'est pas modifié, il change juste de mains.
    Future<void> _setItemOwner(Dvidle ctx, String itemId, String owner) async {

                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final doc = Dvidle({});
                                doc.set("ownerId", clanSecret);
                                doc.set("owner",   owner);
                                await _cloud?.write("workers", "clans_items/$clanId/items", itemId, doc,
                                    region: ctx.get("region").toString(), ownerId: clanSecret);
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
