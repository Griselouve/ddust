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
// --- worker extension — Dépôts d'argent, tribut
// -----------------------------------------------------------------------------
extension Worker_chest on worker {

    void _register_chest() {

                                // Écran de saisie d'une somme (money_page), partagé par les deux
                                // sens de circulation de l'argent : la promesse versée au coffre et
                                // le retour d'argent de poche vers le coffre (option des chefs).
                                ActionRegistry.register("worker.item_to_chest",             item_to_chest);

                                ActionRegistry.register("worker.on_money_appear",           on_money_appear);

                                ActionRegistry.register("worker.on_money_digit",            on_money_digit);

                                ActionRegistry.register("worker.on_money_ok",               on_money_ok);

                                // « Payer son tribut » : versement réel de l'argent gagné en jeu
                                // (réutilise money_page, cf. _moneyPay).
                                ActionRegistry.register("worker.pay_tribute",               pay_tribute);

    }

    // Valeur de butin d'un item : le champ `cost` de SON document, seule source. La valeur d'un
    // objet est un fait de ce document précis (cet écu-là vaut tant), pas une propriété de son
    // type — pas de nominal au catalogue, qui ferait un second endroit à tenir d'accord.
    // Document inconnu ou champ absent (le coffre lui-même, un document ancien) → 0 : la
    // comparaison de _announceChestDeposit se tait alors d'elle-même.
    int _itemCostOf(Dvidle? doc) {

                                if (doc == null) return 0;
                                return int.tryParse(doc.get("cost")?.toString() ?? "") ?? 0;
    }

    // Moyenne du champ `field` (`amount` pour l'argent, `cost` pour les objets) sur les
    // _chestHistDepth derniers butins ouverts. 0 si la table est vide ou illisible : l'appelant
    // en déduit qu'il n'y a rien à comparer.
    // Le tri se fait ICI, sur le champ `date`, et pas sur le docId : l'ordre que rend
    // `dvcloud.list` est un détail des backends REST/SDK, pas un contrat, et le schéma de docId
    // appartiendra à la cérémonie d'ouverture. On divise par le nombre de lignes RÉELLEMENT
    // retenues, jamais par _chestHistDepth (sinon les premiers butins d'un clan comptent pour
    // rien et tout paraît dérisoire).
    Future<double> _chestHistoryAvg(String clanId, String region, String field) async {

                                if (clanId.isEmpty) return 0.0;
                                try {
                                    final rows = await _cloud?.list(
                                        "workers", "$_chestHistColl/$clanId/history", region: region) ?? [];
                                    if (rows.isEmpty) return 0.0;
                                    rows.sort((a, b) => (b.get("date")?.toString() ?? "")
                                        .compareTo(a.get("date")?.toString() ?? ""));
                                    final take = rows.length > _chestHistDepth ? _chestHistDepth : rows.length;
                                    var sum = 0, n = 0;
                                    for (var i = 0; i < take; i++) {
                                        final v = int.tryParse(rows[i].get(field)?.toString() ?? "");
                                        if (v == null) continue;      // champ absent : la ligne ne dit rien
                                        sum += v;
                                        n++;
                                    }
                                    return n == 0 ? 0.0 : sum / n;
                                } catch (e) {
                                    deva_log("error", "[chest] _chestHistoryAvg FAILED: $e");
                                    return 0.0;
                                }
    }

    // Un dépôt vient d'être écrit : on situe sa valeur par rapport à l'habitude du clan et on
    // l'annonce. `field` dit à quelle colonne de l'historique `value` se compare — `amount` pour
    // l'argent du portefeuille, `cost` pour un objet : comparer de l'argent à des objets ne
    // voudrait rien dire.
    // Appelé APRÈS l'écriture métier et APRÈS la remise à jour de l'écran : le geste est déjà
    // visible, ce qui suit n'est que du récit. D'où le try/catch qui avale tout — il est
    // OBLIGATOIRE, et pas de la prudence décorative : DvExplorer appelle l'action de dépôt sans
    // l'attendre (dvexplorer.dart, `fn(this, {...})` hors await), donc son propre catch ne verra
    // jamais une erreur asynchrone d'ici.
    Future<void> _announceChestDeposit(Dvidle ctx, {required int value, required String field}) async {

                                try {
                                    final clanId = ctx.get("clanId").toString();
                                    final region = ctx.get("region").toString();
                                    final avg    = await _chestHistoryAvg(clanId, region, field);

                                    // Pas d'historique (ou historique muet sur ce champ) : aucun verdict.
                                    // C'est l'état normal jusqu'à la première ouverture de butin.
                                    var suffix = "";
                                    if (avg > 0) {
                                        if (value * 100.0 < avg * _chestLowPct)  suffix = "chest_notif_low";
                                        if (value * 100.0 > avg * _chestHighPct) suffix = "chest_notif_high";
                                    }
                                    deva_log("info", "[chest] dépôt $field=$value, moyenne="
                                        "${avg.toStringAsFixed(1)}"
                                        "${avg > 0 ? " (${(value * 100 / avg).round()}%)" : " (aucun historique)"}"
                                        "${suffix.isEmpty ? "" : " → $suffix"}");

                                    await _notifyClanChest(clanId, region, suffix);
                                } catch (e) {
                                    deva_log("error", "[chest] _announceChestDeposit FAILED: $e");
                                }
    }

    //-----------------------------------------------------------------------
    //-- Écran de saisie d'une somme (money_page) ---------------------------
    //-----------------------------------------------------------------------
    // Un écran, deux sens de circulation de l'argent, choisis par le mode posé AVANT navigate_new :
    //   - _moneyPromise : de la poche d'un parent vers le coffre. Rien n'est écrit ici — la somme
    //     rejoint le brouillon de butin_page, qui commet tout à son « Valider ». D'où l'avertissement
    //     « argent RÉEL » : c'est un engagement, et on ne le reprend pas.
    //   - _moneyDeposit : de la bourse d'un chef vers le coffre. Écrit sur-le-champ, plafonné au
    //     solde.
    //   - _moneyPay : de la bourse d'un joueur vers SA POCHE, dans la vraie vie. Le chef saisit ce
    //     qu'il lui remet en vrai (pas forcément tout), et la bourse baisse d'autant. Écrit
    //     sur-le-champ, plafonné au solde du joueur.
    // Les deux derniers sont les seuls chemins qui font DESCENDRE une bourse.
    // Le montant n'est pas mémorisé côté worker : il vit sur money_page/amount, que le pavé écrit et
    // que « Valider » relit. C'est ce qui rend la touche BACK — qui n'émet pas de `submit` — sans
    // conséquence, et ce qui évite un miroir de plus à tenir juste.

    // Apparition : saisie vierge, et textes accordés au mode. La remise à zéro n'est pas
    // décorative — _syncLabel persiste dans le registry (born-filled), donc sans elle l'écran
    // renaîtrait sur le montant de la fois précédente.
    Future<void> on_money_appear(dynamic caller, dynamic event) async {

                                _moneyBusy = false;
                                final deposit = _moneyMode == _moneyDeposit;
                                final pay     = _moneyMode == _moneyPay;
                                try {
                                    // clear_on_next : le PREMIER chiffre remplace la saisie au lieu de
                                    // s'y ajouter. Sans bouton OK, rien d'autre ne le remet à vrai.
                                    final pad = await DvOrb.wait_for_shape("money_page/numpad");
                                    pad?.set("shape.clear_on_next", true);
                                    // La touche MAX vit du plafond : posée à CHAQUE appear (0 en
                                    // mode promesse ⇒ pas de touche), persistée dans le registry
                                    // pour que le pavé renaisse avec la bonne grille au rebuild.
                                    await _syncGeom(pad, "money_page/numpad", "shape.max", "$_moneyCap");

                                    await _syncLabel(await DvOrb.wait_for_shape("money_page/amount"),
                                        "money_page/amount", "0");

                                    // Mode paiement : l'avertissement nomme le joueur. C'est LE point de
                                    // l'écran — le chef n'enregistre pas un chiffre, il constate un
                                    // versement qu'il doit faire de la main à la main.
                                    var warn = TranslationRegistry.processLabel(pay
                                        ? "@@@T:money_warn_pay@@@"
                                        : deposit
                                            ? "@@@T:money_warn_back@@@"
                                            : "@@@T:butin_money_warning@@@");
                                    if (pay) warn = warn.replaceAll("{name}", _moneyPayName);
                                    await _syncLabel(await DvOrb.wait_for_shape("money_page/warning"),
                                        "money_page/warning", warn);

                                    // « Somme à remettre dans le coffre — maximum : 37 ». Le plafond est
                                    // ÉNONCÉ quand il existe : c'est ce qui rend le rabotage d'on_money_digit
                                    // lisible plutôt que surprenant. Une promesse, elle, n'en a pas.
                                    var lbl = TranslationRegistry.processLabel(pay
                                        ? "@@@T:money_lbl_pay@@@"
                                        : deposit
                                            ? "@@@T:money_lbl_back@@@" : "@@@T:money_lbl_add@@@");
                                    if (_moneyCap > 0) {
                                        lbl += " — ${TranslationRegistry.processLabel("@@@T:money_lbl_max@@@")} "
                                            "$_moneyCap";
                                    }
                                    await _syncLabel(await DvOrb.wait_for_shape("money_page/label"),
                                        "money_page/label", lbl);
                                } catch (e) {
                                    deva_log("error", "[money] on_money_appear FAILED: $e");
                                }
    }

    // Une frappe (show_ok: false ⇒ un `submit` par chiffre, cf. DvNumpad). On ne retient rien : on
    // NORMALISE l'affichage, sous les yeux de celui qui tape. Les zéros de tête tombent au passage.
    Future<void> on_money_digit(dynamic caller, dynamic event) async {

                                final raw = event?.toString() ?? "";
                                // Trop de chiffres : on sort de l'entier sûr et le nombre déborde de son
                                // cadre. On ignore la frappe en tronquant à ce qui tenait déjà.
                                final cut = raw.length > _moneyDigitsMax
                                    ? raw.substring(0, _moneyDigitsMax) : raw;
                                var n = int.tryParse(cut) ?? 0;
                                if (_moneyCap > 0 && n > _moneyCap) n = _moneyCap;
                                final txt = "$n";
                                if (txt == raw) return;                       // rien à corriger
                                await _syncLabel(await DvOrb.wait_for_shape("money_page/amount"),
                                    "money_page/amount", txt);
    }

    // « Valider » : le montant est relu sur l'affichage, jamais sur un miroir. Zéro = on rentre
    // sans rien faire (l'écran s'abandonne aussi par la flèche retour).
    Future<void> on_money_ok(dynamic caller, dynamic event) async {

                                if (_moneyBusy) return;
                                final disp = await DvOrb.wait_for_shape("money_page/amount");
                                var n = int.tryParse(disp?.get("shape.label")?.toString() ?? "") ?? 0;
                                if (_moneyCap > 0 && n > _moneyCap) n = _moneyCap;
                                if (n <= 0) { DvOrb.navigate_back(); return; }

                                if (_moneyMode == _moneyDeposit || _moneyMode == _moneyPay) {
                                    final pay  = _moneyMode == _moneyPay;
                                    _moneyBusy = true;
                                    try {
                                        if (pay) {
                                            await _payTribute(n);
                                        } else {
                                            await _depositMoneyToChest(n);
                                        }
                                    } finally {
                                        _moneyBusy = false;
                                    }
                                    DvOrb.navigate_back();
                                    return;
                                }

                                // Promesse : rien n'est écrit ici. La somme rejoint le BROUILLON, et la
                                // ligne de la bourse est redessinée AVANT le retour — butin_page ne rejoue
                                // pas son `appear` au pop, personne d'autre ne la rafraîchirait. Deux
                                // passages s'additionnent.
                                _butinMoneyAdd += n;
                                deva_log("info", "[butin] argent promis (en attente) : +$n → $_butinMoneyAdd");
                                _pushButinRows();
                                DvOrb.navigate_back();
    }

    // Option « remettre dans le coffre » : n'ouvre que l'écran de saisie, plafonné au solde de la
    // bourse. Reçoit la charge de l'item (le menu la transmet à l'action de l'option).
    Future<void> item_to_chest(dynamic caller, dynamic event) async {

                                final data = (event is Map) ? event : const {};
                                final qty  = int.tryParse(data["quantity"]?.toString() ?? "0") ?? 0;
                                if (qty <= 0) return;
                                _moneyMode = _moneyDeposit;
                                _moneyCap  = qty;
                                DvOrb.navigate_new("money_page");
    }

    // Un chef rend `amount` de SA bourse au coffre. Les deux portefeuilles partent dans un
    // batchWrite unique : l'argent ne peut pas disparaître entre les deux écritures. batchWrite
    // n'injecte pas ownerId, chaque document le porte (règle de clans_items).
    Future<void> _depositMoneyToChest(int amount) async {

                                final ctx = await _butinCtx();
                                if (ctx == null || _userId.isEmpty) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                final coll       = "clans_items/$clanId/items";
                                final wid        = _playerWalletId(_userId);

                                try {
                                    // Relecture juste avant : la bourse a pu bouger sur un autre appareil
                                    // pendant la saisie (même prudence qu'on_butin_ok).
                                    final mineDoc = await _cloud?.read("workers", coll, wid,
                                        ownerId: clanSecret, region: region);
                                    final mineHave = int.tryParse(
                                        mineDoc?.get("quantity")?.toString() ?? "0") ?? 0;
                                    final mineLast = int.tryParse(
                                        mineDoc?.get("last_quantity")?.toString() ?? "0") ?? 0;
                                    // Le solde lu fait autorité sur celui affiché à l'ouverture.
                                    final n = amount > mineHave ? mineHave : amount;
                                    if (n <= 0) return;

                                    final chestDoc = await _cloud?.read("workers", coll, _walletDocId,
                                        ownerId: clanSecret, region: region);
                                    final chestHave = int.tryParse(
                                        chestDoc?.get("quantity")?.toString() ?? "0") ?? 0;

                                    final newMine  = mineHave - n;
                                    final newChest = chestHave + n;
                                    final writes   = <DvCloudWrite>[];

                                    final mine = Dvidle({});
                                    mine.set("ownerId",  clanSecret);
                                    mine.set("quantity", newMine);
                                    // RECALAGE du repère « déjà vu » : le gain montré à l'ouverture du butin
                                    // est quantity − last_quantity. Retirer de l'argent sans le recaler
                                    // laisserait un repère au-dessus du solde, donc un gain négatif. On ne
                                    // l'abaisse que s'il dépasse — jamais on ne re-montre un gain déjà vu.
                                    if (mineLast > newMine) mine.set("last_quantity", newMine);
                                    writes.add(DvCloudWrite.set(coll, wid, mine));

                                    // Miroir du solde sur le doc joueur, dans le MÊME batch que la
                                    // bourse : le roster lit l'argent là, il doit baisser d'autant.
                                    writes.add(DvCloudWrite.set(
                                        "clans_players/$clanId/players", _userId, _walletMirror(_userId, newMine)));

                                    final chest = Dvidle({});
                                    chest.set("ownerId",  clanSecret);
                                    chest.set("quantity", newChest);
                                    // Portefeuille du coffre absent (clan d'avant, jamais ouvert) : on le
                                    // recrée entier plutôt que d'écrire un document sans type ni owner.
                                    if (chestDoc == null) {
                                        chest.set("type",  "argent_poche");
                                        chest.set("owner", _butinOwner);
                                    }
                                    writes.add(DvCloudWrite.set(coll, _walletDocId, chest));

                                    await _cloud?.batchWrite("workers", writes, region: region);
                                    deva_log("info", "[butin] $n remis au coffre "
                                        "(bourse $mineHave→$newMine, coffre $chestHave→$newChest)");

                                    // La grille est remise à jour ICI : revenir sur l'onglet Items n'émet
                                    // qu'un `show`, son `appear` ne rejoue pas.
                                    final seen = _patchLocalItem(wid, quantity: newMine);
                                    _patchLocalItem(_walletDocId, quantity: newChest);
                                    if (seen) {
                                        _pushClanItems();
                                    } else {
                                        await _loadClanItems(clanId, clanSecret, region);
                                    }

                                    // De l'argent vient d'entrer dans le coffre : même annonce que le dépôt
                                    // d'une promesse, comparée aux `amount` de l'historique.
                                    await _announceChestDeposit(ctx, value: n, field: "amount");
                                } catch (e) {
                                    deva_log("error", "[butin] _depositMoneyToChest FAILED: $e");
                                }
    }

    //-----------------------------------------------------------------------
    //-- Paiement du tribut (option roster, admins) -------------------------
    //-----------------------------------------------------------------------
    // « Payer son tribut » : le chef remet AU JOUEUR, dans la vraie vie, l'argent qu'il a gagné en
    // jeu. C'est donc le pendant de la promesse (butin_page) : là on prenait un engagement, ici on
    // le solde. Le jeu ne peut pas constater le versement — c'est le chef qui le déclare, et la
    // bourse du joueur baisse d'autant. Le montant est libre (on peut ne verser qu'une partie),
    // plafonné au solde : on ne paie pas ce qui n'a pas été gagné.
    //
    // Ouverture de l'écran de saisie seulement. Reçoit `data` = la charge du membre du roster.
    Future<void> pay_tribute(dynamic caller, dynamic event) async {

                                final data   = (event is Map) ? event : const {};
                                final target = data["id"]?.toString() ?? "";
                                final qty    = int.tryParse(data["wallet"]?.toString() ?? "0") ?? 0;
                                if (target.isEmpty || qty <= 0) return;
                                _moneyMode      = _moneyPay;
                                _moneyCap       = qty;
                                _moneyPayTarget = target;
                                _moneyPayName   = data["name"]?.toString() ?? "";
                                DvOrb.navigate_new("money_page");
    }

    // Écrit le versement : la bourse du joueur (source de vérité) et son miroir sur le doc membre
    // partent dans un batchWrite unique — l'argent ne peut pas s'évaporer entre deux écritures.
    // Calqué sur _depositMoneyToChest, à ceci près que l'argent ne va nulle part en jeu : il SORT,
    // puisqu'il a changé de monde.
    Future<void> _payTribute(int amount) async {

                                final ctx = await _butinCtx();
                                final target = _moneyPayTarget;
                                if (ctx == null || target.isEmpty) return;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                final coll       = "clans_items/$clanId/items";
                                final wid        = _playerWalletId(target);

                                try {
                                    // Relecture juste avant : le solde a pu bouger depuis l'ouverture de
                                    // l'écran (une distribution de butin, un autre chef). Le solde LU fait
                                    // autorité sur celui affiché — même prudence que _depositMoneyToChest.
                                    final mineDoc  = await _cloud?.read("workers", coll, wid,
                                        ownerId: clanSecret, region: region);
                                    final mineHave = int.tryParse(
                                        mineDoc?.get("quantity")?.toString() ?? "0") ?? 0;
                                    final mineLast = int.tryParse(
                                        mineDoc?.get("last_quantity")?.toString() ?? "0") ?? 0;
                                    final n = amount > mineHave ? mineHave : amount;
                                    if (n <= 0) return;

                                    final newQty = mineHave - n;
                                    final writes = <DvCloudWrite>[];

                                    final purse = Dvidle({});
                                    purse.set("ownerId",  clanSecret);
                                    purse.set("quantity", newQty);
                                    // RECALAGE du repère « déjà vu » (cf. _depositMoneyToChest) : sans lui,
                                    // le prochain butin afficherait un gain négatif au joueur payé.
                                    if (mineLast > newQty) purse.set("last_quantity", newQty);
                                    writes.add(DvCloudWrite.set(coll, wid, purse));
                                    writes.add(DvCloudWrite.set(
                                        "clans_players/$clanId/players", target, _walletMirror(target, newQty)));

                                    await _cloud?.batchWrite("workers", writes, region: region);
                                    deva_log("info", "[tribut] $n versé à $target (bourse $mineHave→$newQty)");

                                    // Journal du clan : le versement est un fait public et vérifiable —
                                    // c'est ce qui permet à l'enfant de retrouver ce qu'il a touché.
                                    final data = Dvidle({});
                                    data.set("playerId",   target);
                                    data.set("playerName", _moneyPayName);
                                    data.set("amount",     n);
                                    await _writeClanLog(clanId, clanSecret, region, "TributePaid",
                                        userId: target, adminId: _userId, slug: target, data: data);

                                    await _notifyTribute(clanId, clanSecret, region, target, n);

                                    // Le miroir local de la grille Items porte peut-être cette bourse (un
                                    // chef voit la sienne) : on la recale plutôt que de laisser un solde
                                    // périmé s'afficher au prochain passage sur l'onglet.
                                    if (_patchLocalItem(wid, quantity: newQty)) _pushClanItems();

                                    // L'écran Clan est SOUS money_page : au retour il n'émettra qu'un
                                    // `show`, son appear ne rejouera pas. On repousse donc le roster nous-
                                    // mêmes, sinon le badge bourse garderait l'ancienne somme.
                                    await _refreshRoster(clanId, clanSecret, region);
                                } catch (e) {
                                    deva_log("error", "[tribut] _payTribute FAILED: $e");
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
