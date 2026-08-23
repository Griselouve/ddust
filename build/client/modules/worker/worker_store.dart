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
// --- worker extension — Boutique (dvstore)
//
// Tout ce qui est COMMERCIAL vit dans dvstore (catalogue, achat, entitlement) et
// se lit dans `store.*`. Ce fichier ne porte que le métier ddust :
//   - qui paie (le CLAN, pas le joueur) ;
//   - qui a le droit d'acheter (un adulte administrateur, derrière le contrôle
//     parental — l'app s'adresse à des enfants) ;
//   - ce que les droits achetés changent dans le jeu (plafonds de membres) ;
//   - à quoi ressemblent les écrans.
// -----------------------------------------------------------------------------
extension Worker_store on worker {

    void _register_store() {

                                // --- Contrats fournis à dvstore (déclarés dans conf.store) ---
                                ActionRegistry.register("worker.store_scope",              store_scope);

                                // --- Réactions aux changements d'état commercial ---
                                ActionRegistry.register("worker.on_entitlement_changed",   on_entitlement_changed);
                                ActionRegistry.register("worker.on_store_state_changed",   on_store_state_changed);

                                // --- Callbacks métier appelées par dvstore ---
                                ActionRegistry.register("worker.on_store_purchase",              on_store_purchase);
                                ActionRegistry.register("worker.on_store_purchase_failed",       on_store_purchase_failed);
                                ActionRegistry.register("worker.on_store_subscription",          on_store_subscription);
                                ActionRegistry.register("worker.on_store_subscription_renewed",  on_store_subscription_renewed);
                                ActionRegistry.register("worker.on_store_subscription_changed",  on_store_subscription_changed);
                                ActionRegistry.register("worker.on_store_subscription_ended",    on_store_subscription_ended);
                                ActionRegistry.register("worker.on_store_payment_default",       on_store_payment_default);
                                ActionRegistry.register("worker.on_store_payment_recovered",     on_store_payment_recovered);
                                ActionRegistry.register("worker.on_store_locked",                on_store_locked);

                                // --- Écrans ---
                                ActionRegistry.register("worker.on_shop_appear",           on_shop_appear);
                                ActionRegistry.register("worker.shop_settings_selector",   shop_settings_selector);
                                ActionRegistry.register("worker.store_open_subscription",  store_open_subscription);
                                ActionRegistry.register("worker.on_store_product_appear",  on_store_product_appear);
                                ActionRegistry.register("worker.store_buy_product",        store_buy_product);
                                ActionRegistry.register("worker.on_locked_appear",         on_locked_appear);
                                ActionRegistry.register("worker.store_revive_clan",        store_revive_clan);

                                // --- Page des paliers ---
                                ActionRegistry.register("worker.on_tiers_appear",          on_tiers_appear);
                                ActionRegistry.register("worker.tiers_pick",               tiers_pick);
                                ActionRegistry.register("worker.tiers_set_monthly",        tiers_set_monthly);
                                ActionRegistry.register("worker.tiers_set_yearly",         tiers_set_yearly);

                                // --- Codes cadeaux ---
                                ActionRegistry.register("worker.on_giftcode_appear",       on_giftcode_appear);
                                ActionRegistry.register("worker.on_giftcode_confirm",      on_giftcode_confirm);
                                ActionRegistry.register("worker.on_giftcode_close",        on_giftcode_close);

                                // --- Banc d'essai (mode test seulement) ---
                                ActionRegistry.register("worker.on_store_scenario_appear", on_store_scenario_appear);
                                ActionRegistry.register("worker.store_scenario_apply",     store_scenario_apply);
                                ActionRegistry.register("worker.on_giftcode_mint_appear",  on_giftcode_mint_appear);
                                ActionRegistry.register("worker.on_giftcode_mint",         on_giftcode_mint);
                                ActionRegistry.register("worker.on_giftcode_revoke",       on_giftcode_revoke);

                                // Rappel du contrôle parental : dvparentalgate ne rend pas un
                                // booléen, il rappelle cette action quand la porte est franchie.
                                ActionRegistry.register("worker.store_gate_passed",        store_gate_passed);
    }

    // -----------------------------------------------------------------------
    // --- Contrats fournis à dvstore
    // -----------------------------------------------------------------------

    // Ce qui PAIE. Le clan, jamais l'utilisateur : c'est ce qu'annoncent les CGU
    // (« un seul abonnement et un seul payeur par clan ») et c'est ce qui permet
    // à un enfant de jouer sans compte marchand. dvstore n'en garde qu'une
    // empreinte — ni l'identifiant ni le secret du clan ne partent chez Play.
    Future<Dvidle?> store_scope(dynamic caller, dynamic event) async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return null;
                                return Dvidle({
                                    "scope_id": ctx.get("clanId").toString(),
                                    "secret":   ctx.get("clanSecret").toString(),
                                });
    }

    // L'éligibilité à l'offre fondateurs n'est PLUS décidée ici : elle l'est par la
    // cloud function `store_eligibility` (conf `store.eligibility_function`), qui
    // compare la date de création du clan à un cutoff vivant dans un document de
    // configuration serveur.
    //
    // L'ancienne version lisait `store.subscription.founder` pour décider de
    // demander l'offre fondateurs — or ce champ n'est écrit qu'APRÈS un achat portant
    // cette offre. La condition était donc sa propre conséquence : aucun clan ne
    // pouvait jamais devenir fondateur. Une éligibilité doit venir d'un fait
    // antérieur à l'achat, et d'une autorité que le client ne peut pas contrefaire.
    //
    // dvstore transmet l'offre de lui-même à `buy()` : les écrans n'ont plus rien à
    // en savoir.

    // -----------------------------------------------------------------------
    // --- Réactions aux changements d'état
    // -----------------------------------------------------------------------

    // Les droits achetés ne changent qu'une chose dans le jeu aujourd'hui : le
    // nombre de membres qu'un clan peut accueillir. Le reste (packs de contenu)
    // passe par les tags de layers, que dvstore active lui-même.
    Future<void> on_entitlement_changed(dynamic caller, dynamic event) async {

                                final state = (await deva_get("store.subscription.state"))?.toString() ?? "none";
                                deva_log("info", "[store] entitlement: state=$state "
                                    "joueurs=${await deva_get("store.grants.max_players")}");
                                await _evaluateDunning();
    }

    // Changement d'état commercial. Aucun état ne change l'écran affiché — le jeu
    // reste ouvert quoi qu'il arrive. Ce que l'état pilote, c'est ce que raconte la
    // boutique, et le rappel de cotisation.
    Future<void> on_store_state_changed(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                deva_log("info", "[store] état: ${m["from"]} → ${m["to"]}");

                                // Gel survenu EN COURS DE SESSION (le balayage serveur passe à 5 h, la
                                // vigilance temps réel le rapporte aussitôt). Sans ce cas, une famille
                                // déjà dans le jeu au moment du gel y resterait jusqu'à la prochaine
                                // ouverture — soit précisément la session la plus longue.
                                if ((await _storeLocked()) && !_storeOnLockedPage()) {
                                    deva_log("info", "[store] clan gelé en séance — donjon fermé");
                                    DvOrb.navigate_reset("locked_page");
                                    return;
                                }
                                await _evaluateDunning();
    }

    // L'ÉTAT COMMERCIAL DU CLAN, normalisé — et c'est le seul point d'où on le lit.
    //
    // `store.subscription.state` peut être TOTALEMENT ABSENT du dictionnaire, et pas
    // seulement vide : dvstore ne publie que depuis `_applyEntitlement(doc)`, qui sort
    // sans rien écrire quand le document n'existe pas. Or un clan qui n'a jamais
    // souscrit n'a justement pas de document `clans_store/<clanId>` — le cas le plus
    // fréquent n'est donc pas « la clef vaut none », c'est « la clef n'a jamais été
    // écrite ». Une lecture naïve rend `null` et casse toute comparaison.
    //
    // Il n'existe AUCUN état « je ne sais pas encore » dans l'énumération de dvstore
    // (none|trial|active|canceled|grace|hold|locked|expired). « Absent », « vide » et
    // « none » disent donc ici la même chose, et les distinguer reviendrait à inventer
    // une information que personne ne publie.
    Future<String> _storeState() async {

                                final s = (await deva_get("store.subscription.state"))?.toString() ?? "";
                                return s.isEmpty ? "none" : s;
    }

    // Le clan a-t-il une cotisation VIVANTE ?
    //
    // Miroir exact de `_subscribed` dans dvstore : c'est le module qui décide ce qu'est
    // un abonnement en cours, on recopie sa liste plutôt que d'en inventer une seconde
    // qui divergerait au premier état ajouté. `canceled` en fait partie — un abonnement
    // résilié court jusqu'à son échéance et le clan y a droit jusqu'au bout. `locked` et
    // `expired` en sont exclus : il n'y a plus rien à faire valoir.
    Future<bool> _storeSubscribed() async {

                                const alive = ["trial", "active", "canceled", "grace", "hold"];
                                return alive.contains(await _storeState());
    }

    // Le clan est-il gelé ? Un seul état ferme le jeu, et il n'est atteint qu'au
    // 50e jour d'un impayé jamais régularisé — après dix jours de grâce et quarante
    // jours de relances adressées aux seuls adultes.
    Future<bool> _storeLocked() async {

                                return (await _storeState()) == "locked";
    }

    // Déjà sur l'écran de gel : évite de rejouer un navigate_reset sur lui-même à
    // chaque republication d'état (idiome _storeOnBench).
    bool _storeOnLockedPage() {

                                try {
                                    for (final p in DvPage.actives) {
                                        if (p.get_shape_by_id("locked_page/revive") != null) return true;
                                    }
                                } catch (_) {}
                                return false;
    }

    // Vrai si la page des paliers est à l'écran, bloquante ou non — on repeint
    // alors son bandeau en place au lieu de renaviguer (cf. _storeShowPurchaseError).
    // Même idiome de détection que ci-dessus : on cherche une shape qui n'existe
    // que sur cette page. `tiers_page/notice` est le bandeau lui-même, donc
    // toujours présent dans la registry de la page, visible ou non.
    bool _storeOnTiersPage() {

                                try {
                                    for (final p in DvPage.actives) {
                                        if (p.get_shape_by_id("tiers_page/notice") != null) return true;
                                    }
                                } catch (_) {}
                                return false;
    }

    // -----------------------------------------------------------------------
    // --- Callbacks métier appelées par dvstore
    //
    // dvstore ne connaît que Play : il dit ce qui vient de se passer, pas ce que
    // cela signifie ici. C'est ce bloc qui traduit un événement commercial en
    // événement de jeu — journal de clan, retour d'écran, alerte aux adultes.
    // -----------------------------------------------------------------------

    // Achat à l'unité acquis (pack, option). Le contenu, lui, s'active tout seul :
    // dvstore pose le tag du layer correspondant.
    Future<void> on_store_purchase(dynamic caller, dynamic event) async {

                                final m       = (event is Map) ? event : const {};
                                final product = m["product"]?.toString() ?? "";
                                deva_log("info", "[store] achat acquis: $product");
                                await _logStoreEvent("StorePurchase", product);
                                await _storeLeaveAfterPurchase();
    }

    Future<void> on_store_purchase_failed(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                // Un abandon volontaire n'est pas un incident : on ne consigne au
                                // journal du clan que ce qui a réellement mal tourné.
                                final reason = m["reason"]?.toString() ?? "";
                                if (reason == "canceled") {
                                    deva_log("info", "[store] achat abandonné: ${m["product"]}");
                                    return;
                                }
                                deva_log("warning", "[store] achat non abouti: ${m["product"]} ($reason)");

                                // ... et surtout : LE DIRE. Sans ce bandeau, un achat qui échoue est
                                // indiscernable d'un bouton cassé — la feuille Play se referme, rien
                                // ne bouge, et la famille conclut que l'app ne marche pas. C'est la
                                // pire issue possible au moment précis où quelqu'un voulait payer.
                                //
                                // Un seul texte par famille de causes, jamais le code d'erreur : ce
                                // qui compte pour l'utilisateur est de savoir s'il doit réessayer,
                                // et qu'il n'a rien été prélevé.
                                await _storeShowPurchaseError(reason);
    }

    // Affiche l'échec sur le bandeau de la page des paliers.
    //
    // Deux situations, et une seule sortie : si l'on est déjà sur `tiers_page` —
    // le cas ordinaire, la feuille Play s'est refermée par-dessus — on repeint le
    // bandeau en place, sans renavigation qui ferait clignoter l'écran. Sinon
    // (achat lancé depuis la boutique ou la fiche produit) on ouvre la page, qui
    // est de toute façon l'endroit où réessayer.
    //
    // Jamais de popup : idiome des overlays du projet.
    Future<void> _storeShowPurchaseError(String reason) async {

                                // `unavailable` : la facturation n'existe pas sur cet appareil (Play
                                // Services absent, profil restreint). Réessayer n'y changera rien, le
                                // texte le dit. Tout le reste — refus de Play, vérification serveur
                                // en échec, périodicité absente — relève du « ça n'a pas abouti,
                                // vous n'avez pas été débité ».
                                final token = (reason == "unavailable")
                                    ? "@@@T:store_unavailable@@@"
                                    : "@@@T:store_error@@@";

                                if (_storeOnTiersPage()) {
                                    await deva_set("worker.store.notice", token);
                                    final banner = await DvOrb.wait_for_shape("tiers_page/notice");
                                    await _syncLabel(banner, "tiers_page/notice",
                                                     TranslationRegistry.processLabel(token));
                                    await _syncVisible(banner, "tiers_page/notice", true);
                                    return;
                                }

                                // `oneMore: false` : un échec d'achat n'est pas une demande de place
                                // supplémentaire — sans ce découplage la page flécherait le palier
                                // au-dessus (cf. le piège `one_more`).
                                await _storeGotoTiers(notice: token);
    }

    // Le clan entre en abonnement : le donjon s'ouvre pour tout le monde.
    Future<void> on_store_subscription(dynamic caller, dynamic event) async {

                                final m       = (event is Map) ? event : const {};
                                final product = m["product"]?.toString() ?? "";
                                deva_log("info", "[store] abonnement actif: $product (${m["state"]}) échéance=${m["expiry"]}");
                                await _logStoreEvent("StoreSubscription", product);
                                await _storeLeaveAfterPurchase();
    }

    // Reconduction encaissée. Silencieuse par choix : une famille n'a pas besoin
    // d'être félicitée tous les mois d'avoir payé. Seul le journal la retient.
    Future<void> on_store_subscription_renewed(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                deva_log("info", "[store] reconduction: ${m["product"]} → ${m["expiry"]}");
                                await _logStoreEvent("StoreRenewed", m["product"]?.toString() ?? "");
    }

    // Changement de palier : les plafonds de membres changent, c'est la seule
    // conséquence de jeu aujourd'hui. dvstore a déjà republié les droits.
    Future<void> on_store_subscription_changed(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                deva_log("info", "[store] palier: ${m["from_product"]} → ${m["product"]}");
                                await _logStoreEvent("StoreTierChanged", m["product"]?.toString() ?? "");
    }

    Future<void> on_store_subscription_ended(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                deva_log("info", "[store] abonnement terminé: ${m["product"]}");
                                await _logStoreEvent("StoreEnded", m["product"]?.toString() ?? "");
    }

    // Défaut de paiement. Rien ne se ferme, rien ne s'annonce aux enfants : c'est
    // une affaire d'adultes, et le jeu continue exactement comme avant. On pose
    // seulement un drapeau que l'écran d'abonnement sait lire. La campagne de
    // relance proprement dite est envoyée par le serveur (balayage quotidien) :
    // elle doit partir même quand personne n'ouvre l'app, ce qu'un client ne peut
    // pas garantir.
    Future<void> on_store_payment_default(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                deva_log("warning", "[store] défaut de paiement (${m["phase"]}) sur ${m["product"]}");
                                await deva_set("worker.store.payment_default", true);
                                await _logStoreEvent("StorePaymentDefault", m["product"]?.toString() ?? "");
    }

    Future<void> on_store_payment_recovered(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                deva_log("info", "[store] paiement régularisé: ${m["product"]}");
                                await deva_set("worker.store.payment_default", false);
                                await _logStoreEvent("StorePaymentRecovered", m["product"]?.toString() ?? "");
                                await _evaluateDunning();
    }

    // Fin du cycle de défaut de paiement, côté serveur. Aucune conséquence d'écran :
    // on ne ferme pas le donjon d'une famille, même là. Seul le journal le retient,
    // et c'est la page des paliers qui dira quoi faire à qui ira voir.
    Future<void> on_store_locked(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                deva_log("warning", "[store] clan gelé: ${m["product"]}");
                                await _logStoreEvent("StoreLocked", m["product"]?.toString() ?? "");
    }

    // Trace au journal du clan (clans_logs). À ne pas confondre avec le journal de
    // FACTURATION (clans_store/{clanId}/events), écrit par le serveur : celui-ci
    // raconte la vie du clan, pas la comptabilité, et il n'aurait de toute façon
    // aucune valeur probante puisque c'est un client qui l'alimente.
    //
    // ÉCRIT AUSSI AU BANC D'ESSAI, délibérément. Un scénario de test qui ne
    // laisserait pas de trace ne prouverait rien : c'est justement au journal qu'on
    // vient vérifier qu'un achat, un incident ou une reprise sont bien racontés à la
    // famille. Les lignes d'essai se lisent comme les vraies — et se purgent avec le
    // reste du clan de test.
    Future<void> _logStoreEvent(String event, String product) async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return;
                                await _writeClanLog(
                                    ctx.get("clanId").toString(),
                                    ctx.get("clanSecret").toString(),
                                    ctx.get("region").toString(),
                                    event,
                                    userId: _userId,
                                    slug:   product,
                                    data:   Dvidle({"product": product}),
                                );
    }

    // -----------------------------------------------------------------------
    // --- Rappel de cotisation impayée (bandeau overlay)
    // -----------------------------------------------------------------------

    // Le serveur publie la PHASE du cycle de relance (`store.subscription.dunning_phase`,
    // posée par le balayage de pustore) : "" pendant les 10 jours de grâce, puis soft,
    // firm, last. On ne la recalcule pas — le client ne connaît ni la date d'entrée en
    // défaut ni les seuils, et deux calendriers qui divergent valent moins qu'un seul.
    //
    // Pourquoi la phase et non le hook `on_payment_default` : le hook ne se déclenche que
    // sur une TRANSITION. Une session qui s'ouvre sur un clan déjà en défaut depuis trois
    // semaines n'en verrait jamais passer un seul.
    //
    // CHEFS DE CLAN UNIQUEMENT. « On n'inquiète surtout pas les enfants » (vision.md), et
    // ce sont de toute façon les seuls destinataires des relances push comme les seuls
    // capables de payer. Un adulte non-chef n'y peut rien non plus.
    Future<void> _evaluateDunning() async {

                                try {
                                    final phase = (await deva_get("store.subscription.dunning_phase"))?.toString() ?? "";
                                    if (phase.isEmpty) {
                                        await _applyDunning(false, "");
                                        return;
                                    }

                                    // Contexte de clan absent (onboarding, entre deux clans) : personne à
                                    // prévenir, et _ensureIsAdmin n'a rien à lire.
                                    final ctx = await _butinCtx();
                                    if (ctx == null) {
                                        await _applyDunning(false, "");
                                        return;
                                    }
                                    final isAdmin = await _ensureIsAdmin(
                                        ctx.get("clanId").toString(),
                                        ctx.get("clanSecret").toString(),
                                        ctx.get("region").toString());
                                    if (!isAdmin) {
                                        await _applyDunning(false, "");
                                        return;
                                    }

                                    deva_log("info", "[store] rappel de cotisation : phase=$phase");
                                    await _applyDunning(true, "@@@T:store_dunning_$phase@@@");
                                } catch (e) {
                                    // Un rappel qu'on n'arrive pas à évaluer ne doit rien casser : on le
                                    // laisse simplement de côté, le prochain passage au dashboard réessaiera.
                                    deva_log("error", "[store] _evaluateDunning FAILED: $e");
                                }
    }

    // Bandeau overlay du rappel de cotisation (idiome maison commons/death_* : widgets
    // layer:overlay révélés à la volée, jamais une popup modale). Copie de
    // _applyImpersonation, y compris sur le point le plus important : MÉMOIRE SEULE, aucun
    // store(). Un bandeau rouge persisté sur disque survivrait à la régularisation du
    // paiement et accuserait une famille à jour — bien pire que de le redessiner à chaque
    // session. Mute les templates de conf (→ les pages FUTURES naissent avec, sur les 25
    // écrans de jeu que page_taskbar couvre) ET applique aux pages déjà en pile.
    Future<void> _applyDunning(bool on, String label) async {

                                try {
                                    await deva_set("registry.commons/store_dunning.shape.visible", on);
                                    if (on) {
                                        await deva_set("registry.commons/store_dunning.shape.label", label);
                                    }
                                    for (final p in DvPage.actives) {
                                        final banner = p.get_shape_by_id("commons/store_dunning");
                                        if (on) {
                                            if (banner is DvLabel) banner.write(label);
                                            banner?.show();
                                        } else {
                                            banner?.hide();
                                        }
                                    }
                                } catch (e) {
                                    deva_log("error", "[store] _applyDunning FAILED: $e");
                                }
    }

    // Porte UNIQUE vers la PAGE DES PALIERS quand une raison commerciale y amène :
    // plafond atteint, bandeau d'impayé, notification de relance, « Se réabonner ».
    //
    // Elle a mené successivement à un écran d'abonnement dédié (supprimé), puis à la
    // boutique. Ni l'un ni l'autre ne convenait : le premier redisait un état de
    // compte, la seconde ne liste plus aucun abonnement depuis le retrait de
    // `shop/list` — un clan n'y avait tout simplement plus rien à souscrire. Le
    // choix de palier ne se fait donc plus dans l'échoppe du tout : celle-ci vend
    // des choses à l'unité, la cotisation a sa page.
    //
    // La RAISON de la venue est publiée dans le dictionnaire plutôt que perdue :
    // c'est une information réelle (« il n'y a plus de place »), et `tiers_page` la
    // peint en tête d'écran. Elle est REMISE À ZÉRO quand il n'y en a pas, sans quoi
    // une venue ordinaire hériterait du bandeau de la précédente.
    //
    // DEUX MODES, et le défaut reste le mode doux. `blocking: false` empile la page
    // par-dessus le jeu, qu'on quitte par la flèche arrière — c'est la forme de tous
    // les motifs qui répondent à une demande de la famille (plafond atteint, relance
    // d'impayé, réabonnement) : elle a voulu quelque chose, on lui dit le prix, elle
    // décide. Le jeu ne se ferme pour AUCUN état commercial, ni fin d'abonnement ni
    // clan gelé, et cela n'a pas changé.
    //
    // `blocking: true` pose au contraire la page en RACINE d'une pile réinitialisée,
    // sans appbar ni flèche : le seul geste possible est de souscrire. Réservé à la
    // première cotisation d'un clan qui a fait la preuve qu'il joue — c'est le mur, et
    // il ne s'adresse qu'aux chefs (cf. _storePitchDue). Un enfant n'y arrive jamais.
    //
    // `oneMore` dit s'il faut viser une place de PLUS que l'effectif ou l'effectif tel
    // quel. Publié, jamais déduit : cf. le commentaire de _tiersPushRows.
    Future<void> _storeGotoTiers({

        String notice   = "",
        bool   oneMore  = false,
        bool   blocking = false,
    }) async {

                                await deva_set("worker.store.notice",   notice);
                                await deva_set("worker.store.one_more", oneMore);

                                // Les deux drapeaux de conf de l'écran sont posés AVANT la navigation —
                                // idiome de _applyDunning : la page naît dans le bon mode, on ne la
                                // retouche pas après coup. La RESTAURATION à `true` n'est pas
                                // optionnelle : `tiers_page` est un singleton de conf, et une venue
                                // bloquante qui ne rendrait pas la flèche laisserait toutes les visites
                                // suivantes sans sortie — y compris celles d'un clan qui a payé.
                                await deva_set("registry.tiers_page.show_back",   !blocking);
                                await deva_set("registry.tiers_page.show_appbar", !blocking);

                                if (notice.isNotEmpty) deva_log("info", "[store] raison de la venue : $notice");
                                if (blocking) {
                                    deva_log("info", "[store] paliers en écran bloquant (racine de pile)");
                                    DvOrb.navigate_reset("tiers_page");
                                    return;
                                }
                                DvOrb.navigate_new("tiers_page");
    }

    // Sommes-nous sur la page des paliers en mode BLOQUANT ? Deux conditions, et les
    // deux comptent : l'écran est bien à l'affiche (même lecture de la pile que
    // _storeOnLockedPage — DvPage.actives est la seule vérité sur ce qui est montré),
    // ET il a été ouvert sans sortie. Le drapeau de conf seul ne suffirait pas : il
    // reste posé jusqu'à la prochaine venue non bloquante, donc il décrirait encore un
    // mur alors qu'on est reparti jouer depuis longtemps.
    Future<bool> _storeOnBlockingTiers() async {

                                var onPage = false;
                                try {
                                    for (final p in DvPage.actives) {
                                        if (p.get_shape_by_id("tiers_page/list") != null) { onPage = true; break; }
                                    }
                                } catch (_) {}
                                if (!onPage) return false;
                                return (await deva_get("registry.tiers_page.show_back")) == false;
    }

    // Entrée ordinaire : bandeau d'impayé, notification de relance, « Se réabonner ».
    // Enregistrée comme action pour que la conf n'ait pas à naviguer elle-même — un
    // `navigate_new.tiers_page` en dur laisserait la raison de la visite précédente
    // en place.
    Future<void> store_open_subscription(dynamic caller, dynamic event) async {

                                await _storeGotoTiers();
    }

    // Sortie après un achat abouti : on revient d'où l'on vient. Le bandeau de raison
    // n'a plus lieu d'être — la raison vient d'être satisfaite.
    //
    // Deux écrans font exception et se traitent avant : ceux qui sont la RACINE d'une
    // pile réinitialisée (clan gelé, mur de première cotisation). Il n'y a rien
    // derrière eux, un retour arrière ne mènerait nulle part — on rouvre le donjon.
    //
    // SAUF depuis le banc d'essai : basculer de scénario passe par _publish(), qui
    // voit une transition d'abonnement et appelle on_store_subscription — donc ici.
    // Sans cette garde, choisir « Abonné standard » éjecterait de l'écran de
    // scénarios à la seconde même où l'on veut en essayer un autre.
    Future<void> _storeLeaveAfterPurchase() async {

                                if (_storeOnBench()) {
                                    deva_log("info", "[store] banc d'essai : sortie d'écran ignorée");
                                    return;
                                }

                                // Sortie de GEL : l'écran de clan gelé est la RACINE d'une pile
                                // réinitialisée, il n'y a rien derrière lui — un retour arrière n'y
                                // mènerait nulle part. Le clan vient de reprendre sa cotisation : on
                                // rouvre le donjon, ce qui est très exactement ce qu'il a payé.
                                if (_storeOnLockedPage()) {
                                    deva_log("info", "[store] cotisation reprise — donjon rouvert");
                                    DvOrb.navigate_reset("dashboard");
                                    return;
                                }

                                // Sortie du MUR de première cotisation, pour la même raison exactement :
                                // la page bloquante est la RACINE d'une pile réinitialisée, un retour
                                // arrière n'y mènerait nulle part. Le clan vient de souscrire — on lui
                                // ouvre le donjon, ce qui est très précisément ce qu'il a payé.
                                if (await _storeOnBlockingTiers()) {
                                    deva_log("info", "[store] première cotisation prise — donjon ouvert");
                                    DvOrb.navigate_reset("dashboard");
                                    return;
                                }
                                DvOrb.navigate_back();
    }

    // Sommes-nous sur le banc d'essai ? Même façon de lire la pile que
    // _applyDunning : DvPage.actives est la seule vérité sur ce qui est affiché.
    bool _storeOnBench() {

                                try {
                                    for (final p in DvPage.actives) {
                                        if (p.get_shape_by_id("store_scenario_page/list") != null) return true;
                                    }
                                } catch (_) {}
                                return false;
    }

    // -----------------------------------------------------------------------
    // --- Plafonds de membres (grants du catalogue)
    // -----------------------------------------------------------------------

    // Le plafond du PALIER D'ENTRÉE — ce qu'on oppose à un clan sans droit acquis.
    // Lu au catalogue et jamais codé en dur : insérer un palier moins cher ou
    // renuméroter la grille ne doit pas demander de retoucher ce fichier.
    //
    // Rend -1 (= illimité) quand LE CATALOGUE N'EST PAS LÀ, et c'est le point
    // délicat. `store.catalog` vient d'un layer de bucket : tant qu'il n'est pas
    // descendu, on ne connaît ni les paliers ni leurs plafonds. Plafonner sur cette
    // ignorance refuserait des membres à une famille pour une raison qui n'existe
    // pas. Des deux erreurs possibles c'est de très loin la pire — elle est visible,
    // injuste et sans recours —, là où laisser passer un membre de trop coûte une
    // place, une fois, et se rattrape au contrôle suivant. Même arbitrage que
    // _storeCapNotice sur un effectif illisible et _storeTierForCount sur un effectif
    // inconnu : la doctrine du fichier est déjà celle-là, on ne fait que l'étendre.
    Future<int> _storeEntryCap() async {

                                final entry = await _storeEntryTier();
                                if (entry.isEmpty) {
                                    deva_log("warning", "[store] catalogue absent — plafond d'entrée inconnu");
                                    return -1;
                                }
                                return await _storeTierCapacity(entry);
    }

    // Plafond publié par le catalogue : UN SEUL compteur, toutes places confondues.
    //
    // Il y en a eu deux (`max_kids` / `max_adults`). Les fusionner n'est pas une
    // simplification de confort : deux compteurs obligeaient à connaître la NATURE
    // d'un membre pour savoir s'il restait de la place, si bien qu'un candidat dont
    // le `legal_state` n'était pas encore écrit n'était contrôlable qu'à moitié, et
    // que « Déclarer majeur » devait vérifier un plafond parce que la promotion
    // déplaçait une place d'un compteur à l'autre. Un membre est un membre.
    //
    // CONVENTION : -1 = illimité, jamais 0 — un plafond à zéro se lirait « aucun
    // joueur autorisé », l'exact contraire, et un `count >= max` écrit sans
    // précaution bloquerait tout le monde sur le palier le plus cher.
    //
    // CE QUE CETTE FONCTION REND N'EST PAS LE DROIT ACQUIS, c'est le plafond
    // OPPOSABLE. La nuance est tout le sujet : sans abonnement, elle rendait -1 —
    // illimité — au motif qu'« un clan sans abonnement relève de la paywall, pas d'un
    // plafond ». Le raisonnement se tenait tant qu'une paywall existait. Elle a été
    // supprimée (_checkStoreAccess), et plus rien n'a pris le relais : un clan qui ne
    // souscrivait pas n'était jamais plafonné, donc jamais amené à la page des
    // paliers, donc jamais sollicité — il jouait gratuitement, sans limite
    // d'effectif, indéfiniment. Une paywall n'existe que si quelque chose y mène.
    //
    // Deux valeurs disent « aucun droit », et elles sont INDISCERNABLES à dessein :
    //   - le booléen `false`, republié par dvstore quand le catalogue est là mais le
    //     droit absent (cf. _allGrantKeys — il n'omet pas la clef, il la remet à faux
    //     et, s'agissant d'un grant numérique, le repli est un `false` littéral) ;
    //   - la clef ABSENTE, quand dvstore n'a jamais rien publié du tout. C'est le cas
    //     d'un clan qui n'a jamais souscrit : sans document `clans_store/<clanId>`,
    //     `_applyEntitlement` sort avant la publication. Le cas le plus fréquent.
    // Les distinguer supposerait un état « je ne sais pas » que personne ne publie.
    //
    // Le repli est le plafond du PALIER D'ENTRÉE, et _storeEntryCap rend lui-même -1
    // si le catalogue n'est pas descendu : on ne plafonne jamais sur une ignorance.
    Future<int> _storeMaxPlayers() async {

                                final raw = await deva_get("store.grants.max_players");
                                if (raw is num) return raw.toInt();
                                final n = int.tryParse(raw?.toString() ?? "");
                                if (n != null) return n;
                                return await _storeEntryCap();
    }

    // Effectif du clan : toute ligne de clans_players qui n'est pas un tombstone.
    // Enfants, adultes, chefs, joueurs sans téléphone — tout le monde compte, une
    // fois. C'est exactement ce qu'annonce la grille (« joueurs actifs + admins »),
    // et c'est ce qui la rend explicable en une phrase à une famille.
    //
    // Rend -1 si l'effectif est ILLISIBLE, que l'appelant doit traiter comme « on
    // ne sait pas » et jamais comme zéro.
    Future<int> _storePlayerCount() async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return -1;
                                final clanId = ctx.get("clanId").toString();
                                final region = ctx.get("region").toString();
                                if (clanId.isEmpty) return -1;

                                try {
                                    final players = await _cloud?.list(
                                        "workers", "clans_players/$clanId/players", region: region) ?? [];
                                    int n = 0;
                                    for (final p in players) {
                                        // Tombstone : un membre révoqué ou parti ne consomme pas de
                                        // place (même filtre que le roster, cf. _refreshRoster).
                                        if (p.get("enabled") == false) continue;
                                        n++;
                                    }
                                    return n;
                                } catch (e) {
                                    deva_log("error", "[store] effectif illisible ($e)");
                                    return -1;
                                }
    }

    // Token du bandeau de refus, ou "" si une place est disponible.
    //
    // Plus aucun paramètre : le refus ne dépend plus de ce que sera le nouveau
    // membre, ce qui supprime du même coup les deux contournements connus (contrôle
    // effectué avant que le `legal_state` du candidat soit écrit, empilement d'états
    // « t » pour franchir le plafond adulte).
    Future<String> _storeCapNotice() async {

                                final max = await _storeMaxPlayers();
                                if (max < 0) return "";                 // palier sans plafond : rien à compter

                                final count = await _storePlayerCount();
                                // Effectif illisible : on laisse passer. Des deux erreurs possibles,
                                // refuser un membre sur une lecture ratée est de loin la pire — elle
                                // est visible, injuste, et sans recours pour la famille.
                                if (count < 0) {
                                    deva_log("error", "[store] effectif illisible — plafond non appliqué");
                                    return "";
                                }

                                deva_log("info", "[store] places : $count/$max joueur(s)");
                                if (count < max) return "";

                                // DEUX bandeaux, et le choix se fait sur l'HISTOIRE COMMERCIALE du clan,
                                // jamais sur le plafond. À un clan qui n'a jamais souscrit on annonce ce
                                // qui l'attend — cotisation, quatorze jours offerts, arrêt quand il veut ;
                                // « le clan est au complet » se lirait comme un refus alors que c'est une
                                // proposition. À tous les autres — abonné qui déborde, résilié, expiré,
                                // gelé — on ne promet PAS les quatorze jours : Play ne re-servira pas
                                // l'offre `essai-14j` à un compte qui l'a déjà eue, et une promesse que
                                // la feuille de paiement dément est pire que pas de promesse du tout.
                                return (await _storeState()) == "none"
                                    ? "@@@T:store_cap_start@@@"
                                    : "@@@T:store_cap_full@@@";
    }

    // Vrai si la place manque — et ouvre alors la page des paliers sur celui qui la
    // donne. Un refus de plafond n'est pas un cul-de-sac : c'est la seule occasion
    // de proposer la montée au moment exact où elle sert à quelque chose. Jamais de
    // popup (l'app n'en a aucune).
    //
    // Un plafond dépassé après une DESCENTE de palier n'évince personne : il ne
    // bloque que les entrées suivantes. Rétrograder un clan de six joueurs ne doit
    // pas en mettre un dehors.
    Future<bool> _storeRefuseMember() async {

                                final notice = await _storeCapNotice();
                                if (notice.isEmpty) return false;
                                deva_log("info", "[store] place refusée — plafond du palier atteint");
                                // `oneMore` EXPLICITE, et c'est le seul appelant qui le pose : la
                                // famille vient de se voir refuser un membre, elle veut une place DE
                                // PLUS. Cette intention était auparavant devinée par _tiersPushRows à
                                // la présence du bandeau ; elle se dit maintenant à l'endroit où on la
                                // connaît. L'oublier ici ne casserait rien de visible — la page
                                // s'ouvrirait, sans flécher aucun palier.
                                await _storeGotoTiers(notice: notice, oneMore: true);
                                return true;
    }

    // -----------------------------------------------------------------------
    // --- Relance de conversion : la première cotisation
    //
    // Le plafond ci-dessus attrape les clans qui GRANDISSENT. Il ne dit jamais rien à
    // un foyer d'un parent et un enfant, qui tient dans le palier d'entrée et n'en
    // sortira pas — soit environ quatre clans sur dix. Pour ceux-là, le seul moment
    // qui vaille est celui où le jeu a fait sa preuve : la DEUXIÈME tâche menée à son
    // terme. Pas la première, qu'une famille joue dans les dix minutes qui suivent
    // l'installation ; la deuxième, c'est-à-dire le moment où elle est revenue.
    // -----------------------------------------------------------------------

    // Compte une tâche validée AU CLAN. Le compteur ne peut pas vivre dans le
    // dictionnaire : c'est un fait du clan, pas de l'appareil. La 1re validation peut
    // être rendue par le chef A sur son téléphone et la 2e par le chef B sur le sien,
    // et un chef qui change d'appareil ne doit pas repartir de zéro.
    //
    // Il est FALSIFIABLE — la règle Firestore de `clans` autorise tout détenteur du
    // clanSecret à écrire n'importe quel champ. Sans gravité : le fausser ne peut
    // qu'AVANCER la demande de cotisation, jamais la retarder ni accorder un droit.
    //
    // Écriture en deep-merge CIBLÉ (un Dvidle neuf ne portant que le compteur), et
    // surtout pas le read-modify-write du document complet de _creditClanXp : on ne
    // réécrit pas l'XP, le butin et le titre d'un clan pour incrémenter un entier.
    Future<void> _storeCountValidation(String clanId, String clanSecret, String region) async {

                                if (clanId.isEmpty || clanSecret.isEmpty) return;
                                // Le clan cotise déjà : rien à compter, et surtout aucune lecture cloud
                                // à payer sur le chemin le plus chaud du jeu. Ce compteur n'a pas
                                // d'autre lecteur que la relance.
                                if (await _storeSubscribed()) return;

                                try {
                                    final doc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final n = int.tryParse(doc?.get("validations")?.toString() ?? "0") ?? 0;

                                    final out = Dvidle({});
                                    out.set("validations", n + 1);
                                    await _cloud?.write("workers", "clans", clanId, out,
                                        region: region, ownerId: clanSecret);
                                    deva_log("info", "[store] tâches validées par le clan : ${n + 1}");
                                } catch (e) {
                                    // Un compteur commercial ne doit JAMAIS faire échouer une validation :
                                    // la famille a fait son travail, elle est créditée et fêtée quoi qu'il
                                    // arrive ici. Au pire la relance part une tâche plus tard.
                                    deva_log("error", "[store] _storeCountValidation FAILED: $e");
                                }
    }

    // Le mur est-il dû ? État DÉRIVÉ, recalculé à chaque arrivée au dashboard depuis
    // des faits persistants — patron _evaluateDunning, et surtout pas un drapeau
    // one-shot. Conséquence directe : il survit au changement d'appareil comme à une
    // réinstallation, et il vaut pour les deux chefs d'un clan sans qu'il y ait rien à
    // synchroniser ni à purger. Un drapeau local n'aurait tenu que sur l'appareil qui
    // l'a armé.
    //
    // TROIS conditions, et la deuxième est celle qui protège les enfants.
    Future<bool> _storePitchDue() async {

                                try {
                                    if (await _storeSubscribed()) return false;

                                    // CHEFS SEULEMENT. Un enfant ne peut pas payer (l'achat est réservé
                                    // aux administrateurs, derrière le contrôle parental) : lui fermer le
                                    // jeu ne servirait à rien qu'à l'inquiéter. Couvre au passage la prise
                                    // de place (take_place), qui change l'identité agissante.
                                    if (!await _storeCanBuy()) return false;

                                    // CLAN ENCORE SEUL : on ne demande rien. Un fondateur teste volontiers
                                    // deux tâches en attendant que sa famille installe le jeu — et l'admin
                                    // solo auto-valide sans preuve, si bien que le compteur atteint le seuil
                                    // en quelques minutes. Le mur tomberait alors AVANT que le clan existe
                                    // vraiment : un écran de paiement sans issue en face d'un roster d'une
                                    // tuile, et l'essai de quatorze jours qui démarre pendant la phase de
                                    // constitution — celle qui a le plus de chances d'échouer.
                                    //
                                    // Lu sur le drapeau local (_setClanAlone) et pas par une requête : ABSENT
                                    // = on ne sait pas = comportement d'avant. Se tromper ici ne coûte au pire
                                    // qu'un mur retardé, jamais une famille enfermée — même arbitrage que le
                                    // catch plus bas.
                                    if ((await deva_get("worker.clan_alone"))?.toString() == "true") {
                                        deva_log("info", "[store] mur ajourné : le clan n'a encore qu'un membre");
                                        return false;
                                    }

                                    final ctx = await _butinCtx();
                                    if (ctx == null) return false;
                                    final clanId     = ctx.get("clanId").toString();
                                    final clanSecret = ctx.get("clanSecret").toString();
                                    final region     = ctx.get("region").toString();
                                    if (clanId.isEmpty || clanSecret.isEmpty) return false;

                                    final doc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final n = int.tryParse(doc?.get("validations")?.toString() ?? "0") ?? 0;

                                    // Seuil réglable depuis le BUCKET, comme le catalogue, les scénarios
                                    // du banc et la cadence de la fée : décaler le moment de la conversion
                                    // ne doit pas demander une version sur les stores.
                                    final raw   = await deva_get("store.pitch.min_validations");
                                    final min   = raw is num ? raw.toInt()
                                                             : int.tryParse(raw?.toString() ?? "") ?? 2;
                                    return n >= min;
                                } catch (e) {
                                    // Un mur qu'on n'arrive pas à évaluer ne ferme rien : le prochain
                                    // passage au dashboard réessaiera. Se tromper dans ce sens coûte une
                                    // session ; se tromper dans l'autre enferme une famille à jour.
                                    deva_log("error", "[store] _storePitchDue FAILED: $e");
                                    return false;
                                }
    }

    // -----------------------------------------------------------------------
    // --- Boutique (liste)
    // -----------------------------------------------------------------------

    // La boutique n'a plus de LISTE : le catalogue ne contient que des abonnements,
    // qui ne se présentent pas en lignes, et aucun produit à l'unité n'existe
    // encore. Restait un cadre vide affichant « l'étal est vide » — un aveu, pas une
    // boutique. La présentation commerciale se construira avec ses propres widgets ;
    // ce fichier garde la mécanique qu'elle appellera.
    //
    // Ne subsiste donc ici que le devoir hérité de l'ancien écran : quitter le combat
    // par la taskbar ne doit pas laisser tourner la boucle batte_swords.
    Future<void> on_shop_appear(dynamic caller, dynamic event) async {

                                _stopCombatSiege();
    }

    // Prix à afficher pour une entrée du catalogue.
    //
    // Pour un ABONNEMENT (`subscription: true`), celui de la périodicité courante :
    // `store.catalog.<id>.price` ne porte qu'un prix d'appel — toujours celui du
    // mensuel —, et l'annuel serait donc annoncé au tarif du mensuel. Pour un produit
    // à l'unité, son prix Play.
    //
    // `price_hint` du catalogue en dernier recours seulement : c'est un repli
    // d'affichage, jamais une source de vérité. Play fournit les prix localisés et
    // taxes incluses, et c'est une exigence de la politique du store.
    //
    // Conservé bien que la boutique ne liste plus les abonnements : c'est l'une des
    // deux prises que la présentation commerciale à venir appellera, avec
    // `_storeBuyGated(productId)`.
    Future<String> _storeRowPrice(String productId, bool subscription) async {

                                if (subscription) {
                                    final plan = await _storePlanId(productId);
                                    if (plan.isNotEmpty) {
                                        final p = (await deva_get("store.catalog.$productId.plans.$plan.price"))?.toString() ?? "";
                                        if (p.isNotEmpty) return p;
                                    }
                                }
                                final price = (await deva_get("store.catalog.$productId.price"))?.toString() ?? "";
                                if (price.isNotEmpty) return price;
                                return (await deva_get("store.catalog.$productId.price_hint"))?.toString() ?? "";
    }

    // Selector du kebab de la boutique. « Restaurer » est ouvert à tous : ce n'est
    // pas acheter, et l'appareil qu'on réinstalle peut très bien être celui d'un
    // enfant. « Gérer » n'a de sens que pour un chef qui a une cotisation en cours.
    // Le banc d'essai n'existe qu'en mode test, et qu'entre les mains d'un
    // administrateur.
    Future<List<String>> shop_settings_selector(dynamic caller, dynamic data) async {

                                final options = <String>["store_restore"];
                                try {
                                    final product = (await deva_get("store.subscription.product"))?.toString() ?? "";
                                    final canBuy  = await _storeCanBuy();
                                    if (product.isNotEmpty && canBuy) options.add("store_manage");
                                    // Saisir un code : sous la même garde que l'achat, et pour la même
                                    // raison — c'est le clan qu'on engage. Proposée abonné ou non : un
                                    // crédit réclamé pendant une cotisation payante n'est pas perdu,
                                    // il attend simplement son tour.
                                    if (canBuy) options.add("store_code");
                                    if (canBuy && await deva_get("store.debug.test_mode") == true) {
                                        options.add("store_scenario");
                                        // Fabriquer des codes : même garde que le banc d'essai, donc
                                        // absente du bucket de production. La vraie garde est serveur
                                        // (GRANT_ADMINS), celle-ci ne fait qu'éviter de montrer une
                                        // porte qui ne s'ouvrirait pas.
                                        options.add("store_mint");
                                        // « Faire venir la fée » : elle n'apparaît sinon qu'au terme d'un
                                        // tirage quotidien étalé sur trente jours, impossible à revoir à la
                                        // demande. Sous la MÊME garde que le banc d'essai — donc absente du
                                        // bucket de production, sans qu'il y ait rien à retirer plus tard.
                                        options.add("fairy_test");
                                    }
                                } catch (e) {
                                    // Lecture KO → repli sûr : seules les deux options inoffensives
                                    // restent. Un kebab amputé vaut mieux qu'un écran qui ne s'ouvre pas.
                                    deva_log("error", "[store] shop_settings_selector FAILED: $e");
                                }
                                return options;
    }

    // -----------------------------------------------------------------------
    // --- Fiche d'un produit à l'unité
    // -----------------------------------------------------------------------

    Future<void> on_store_product_appear(dynamic caller, dynamic event) async {

                                final id = _storeProductId;
                                if (id.isEmpty) return;

                                final image = await DvOrb.wait_for_shape("store_product_page/image");
                                final name  = await DvOrb.wait_for_shape("store_product_page/name");
                                final desc  = await DvOrb.wait_for_shape("store_product_page/desc");
                                final buy   = await DvOrb.wait_for_shape("store_product_page/buy");

                                final owned  = (await deva_get("store.purchases.$id"))?.toString() == "owned";
                                final title  = (await deva_get("store.catalog.$id.title"))?.toString() ?? id;
                                final price  = (await deva_get("store.catalog.$id.price"))?.toString() ?? "";
                                final canBuy = await _storeCanBuy();

                                await _syncLabel(name, "store_product_page/name", TranslationRegistry.processLabel(title));
                                await _syncLabel(desc, "store_product_page/desc",
                                    TranslationRegistry.processLabel((await deva_get("store.catalog.$id.description"))?.toString() ?? ""));

                                // L'illustration reste masquée tant que le catalogue n'en fournit
                                // pas : une image vide vaut mieux qu'un cadre vide.
                                await _syncVisible(image, "store_product_page/image", false);

                                // Bouton caché plutôt que grisé quand il n'y a rien à faire — c'est
                                // l'idiome de item_view_page/apply, et le framework n'a pas de
                                // notion d'inactivité sur un DvLabel.
                                await _syncLabel(buy, "store_product_page/buy",
                                    owned ? TranslationRegistry.processLabel("@@@T:store_owned@@@")
                                          : "${TranslationRegistry.processLabel("@@@T:store_buy@@@")}${price.isEmpty ? "" : "  $price"}");
                                await _syncVisible(buy, "store_product_page/buy", owned || canBuy);
    }

    Future<void> store_buy_product(dynamic caller, dynamic event) async {

                                if (_storeProductId.isEmpty) return;
                                await _storeBuyGated(_storeProductId);
    }

    // --- « Mes achats » : SUPPRIMÉ ------------------------------------------
    // L'écran de relevé (on_store_dashboard_appear + _storeBillingRows) est parti
    // avec sa conf : il redisait l'état que la boutique porte déjà, et son
    // historique se lit désormais au JOURNAL DU CLAN (worker_log._logLine, jetons
    // log_store_*), avec le reste de l'histoire de la famille.
    //
    // La sous-collection clans_store/{clanId}/events reste écrite par le serveur :
    // c'est la pièce d'audit en cas de litige, elle n'a simplement plus d'écran.

    // -----------------------------------------------------------------------
    // --- Clan gelé
    // -----------------------------------------------------------------------

    Future<void> on_locked_appear(dynamic caller, dynamic event) async {

                                final canBuy = await _storeCanBuy();
                                final revive = await DvOrb.wait_for_shape("locked_page/revive");

                                // Un enfant qui tombe sur cet écran ne se voit rien proposer : il
                                // lit la ligne qui dit que rien n'est perdu, et c'est tout. Payer
                                // est une affaire d'adultes, ici comme partout ailleurs.
                                await _syncVisible(revive, "locked_page/revive", canBuy);
    }

    // « Se réabonner » : reprend la cotisation SANS quitter l'écran de gel.
    //
    // TOUJOURS l'offre d'ENTRÉE du catalogue, jamais le palier que le clan tenait
    // avant : on ne profite pas d'un impayé pour vendre plus cher, et une famille
    // qui revient après des mois d'absence n'a pas besoin du palier illimité pour
    // rouvrir sa porte. Elle montera depuis la boutique si elle le veut.
    //
    // Et TARIF COURANT, sans aucune offre (`offer: ""`) : les 14 jours gratuits
    // s'adressent à qui découvre le jeu. Les laisser s'appliquer ici reviendrait à
    // offrir deux semaines à chaque défaut de paiement, ce qui récompenserait
    // exactement le comportement qu'on cherche à éviter.
    //
    // Aucune navigation : c'est ce qui fait de cet écran un cul-de-sac. La feuille
    // de paiement Play s'ouvre par-dessus, et _storeLeaveAfterPurchase rouvre le
    // donjon une fois l'achat confirmé.
    //
    // SANS contrôle parental, seul achat du jeu dans ce cas — décision produit,
    // demandée explicitement. Le raisonnement : cet écran n'est pas un étal qu'on
    // parcourt, c'est une porte fermée avec un seul geste possible, et ce geste n'est
    // proposé qu'aux administrateurs adultes du clan (le bouton est masqué à tous les
    // autres, cf. on_locked_appear). Faire résoudre une énigme arithmétique à un
    // parent qui vient rouvrir le jeu de ses enfants ajoutait un obstacle là où l'on
    // cherche précisément à en retirer.
    //
    // Le contrôle parental reste en place partout ailleurs (_storeBuyGated), où il a
    // son sens : sur un étal, l'enfant qui tient le téléphone déverrouillé peut
    // acheter par curiosité. Ici il n'a rien à toucher.
    Future<void> store_revive_clan(dynamic caller, dynamic event) async {

                                // Le palier qui couvre l'effectif RÉEL, pas le palier d'entrée. Avec
                                // cinq paliers, réabonner d'office au moins cher ferait renaître un
                                // clan de neuf joueurs sur une offre qui en accepte deux : il
                                // repartirait en dépassement à la seconde même où il vient de payer.
                                final tier = await _storeTierForCount(await _storePlayerCount());
                                if (tier.isEmpty) {
                                    deva_log("warning", "[store] se réabonner : aucun abonnement au catalogue");
                                    return;
                                }

                                // Le contrôle d'administrateur, lui, est conservé : il ne coûte rien à
                                // l'utilisateur et il évite qu'un bouton laissé visible par une
                                // synchronisation en retard ne déclenche un achat.
                                if (!await _storeCanBuy()) {
                                    deva_log("info", "[store] se réabonner : $_userId n'administre pas ce clan");
                                    return;
                                }

                                deva_log("info", "[store] se réabonner → $tier (tarif courant, sans offre)");
                                await _store?.buy(tier, period: _storePeriod, offer: "");
    }

    // L'offre d'entrée : le premier abonnement du catalogue par `order`, donc le
    // moins cher. Lu au catalogue et jamais codé en dur — renuméroter les paliers
    // ou en insérer un ne doit pas demander de retoucher ce fichier.
    Future<String> _storeEntryTier() async {

                                final catalog = await deva_get("store.catalog");
                                if (catalog is! Dvidle) return "";
                                String best = "";
                                int    rank = 1 << 30;
                                for (final id in catalog.keys) {
                                    if ((await deva_get("store.catalog.$id.type"))?.toString() != "subscription") continue;
                                    final order = ((await deva_get("store.catalog.$id.order")) as num?)?.toInt() ?? 0;
                                    if (best.isEmpty || order < rank) { rank = order; best = id; }
                                }
                                return best;
    }

    // Tous les abonnements du catalogue, triés par `order` croissant — donc du moins
    // cher au plus cher. C'est la liste que la page des paliers affiche et celle sur
    // laquelle raisonnent _storeTierForCount et _storeNextTier : personne ne code en
    // dur ni le nombre de paliers, ni leurs identifiants.
    Future<List<String>> _storeTiers() async {

                                final catalog = await deva_get("store.catalog");
                                if (catalog is! Dvidle) return const [];
                                final ids = <String>[];
                                for (final id in catalog.keys) {
                                    if ((await deva_get("store.catalog.$id.type"))?.toString() != "subscription") continue;
                                    ids.add(id);
                                }
                                final orders = <String, int>{};
                                for (final id in ids) {
                                    orders[id] = ((await deva_get("store.catalog.$id.order")) as num?)?.toInt() ?? 0;
                                }
                                ids.sort((a, b) => (orders[a] ?? 0).compareTo(orders[b] ?? 0));
                                return ids;
    }

    // Plafond de joueurs accordé par un palier du catalogue (-1 = illimité). À ne pas
    // confondre avec _storeMaxPlayers, qui lit le droit ACQUIS : celle-ci interroge
    // une offre qu'on n'a pas (encore) achetée.
    Future<int> _storeTierCapacity(String productId) async {

                                final raw = await deva_get("store.catalog.$productId.grants.max_players");
                                if (raw is num) return raw.toInt();
                                return int.tryParse(raw?.toString() ?? "") ?? -1;
    }

    // Le palier le MOINS CHER qui accueille `count` joueurs. Sert deux fois : au
    // réabonnement d'un clan gelé, et au fléchage du « palier suivant » sur la page.
    //
    // `count < 0` (effectif illisible) → palier d'entrée : on ne devine pas, et
    // proposer trop cher sur une lecture ratée serait la pire des deux erreurs.
    Future<String> _storeTierForCount(int count) async {

                                final tiers = await _storeTiers();
                                if (tiers.isEmpty) return "";
                                if (count < 0)     return tiers.first;

                                for (final id in tiers) {
                                    final cap = await _storeTierCapacity(id);
                                    if (cap < 0 || count <= cap) return id;
                                }
                                // Aucun palier plafonné ne suffit et il n'y en a pas d'illimité au
                                // catalogue : le plus large est encore la meilleure réponse.
                                return tiers.last;
    }

    // Le palier à FLÉCHER sur la page : celui qui résout le problème qui a amené la
    // famille ici. C'est le moins cher qui couvre l'effectif visé ET qui est
    // strictement au-dessus du palier courant — « suivant » au sens de `order + 1`
    // proposerait parfois une montée qui ne suffit toujours pas, ce qui est le pire
    // conseil qu'on puisse donner à quelqu'un qui vient de se voir refuser un membre.
    //
    // `oneMore` distingue les deux façons d'arriver ici, et il compte :
    //   true  — un refus de plafond. La famille veut une place DE PLUS, on vise donc
    //           l'effectif + 1.
    //   false — souscription ordinaire (fin d'essai, relance, réabonnement). On vise
    //           l'effectif tel quel. Viser +1 vendrait le palier du dessus à un clan
    //           de cinq qui tient très bien dans celui de cinq.
    //
    // "" si le clan est déjà au palier le plus large, ou s'il n'y a rien à proposer.
    Future<String> _storeNextTier({

        required String current,
        required int    count,
        required bool   oneMore,
    }) async {

                                final tiers = await _storeTiers();
                                if (tiers.isEmpty) return "";

                                final curIdx = tiers.indexOf(current);          // -1 si aucun abonnement
                                final target = count < 0 ? -1 : (oneMore ? count + 1 : count);
                                final fit    = await _storeTierForCount(target);
                                final fitIdx = tiers.indexOf(fit);

                                if (fitIdx > curIdx) return fit;                 // la montée qui suffit
                                // Le palier courant couvre déjà l'effectif visé : rien à conseiller
                                // pour une souscription ordinaire, et pour un refus de plafond cela
                                // ne peut arriver qu'au palier le plus large — donc rien non plus.
                                return "";
    }

    // -----------------------------------------------------------------------
    // --- Page des paliers
    //
    // Le seul écran d'où l'on souscrit ou change de cotisation. Il ne se parcourt
    // pas : une raison commerciale l'ouvre (plafond atteint, relance d'impayé,
    // réabonnement), et il répond à cette raison-là.
    //
    // Il n'invente RIEN. Les paliers, leurs plafonds et leur ordre viennent du
    // catalogue (layer cloud) ; les prix viennent de Play ; les noms viennent du
    // thème. Ce bloc ne fait que mettre les trois en regard de l'effectif du clan
    // et surligner deux lignes : celle où l'on est, celle qu'il faut prendre.
    // -----------------------------------------------------------------------

    Future<void> on_tiers_appear(dynamic caller, dynamic event) async {

                                // La RAISON de la venue, publiée par _storeGotoTiers. Vide pour une
                                // entrée ordinaire — on masque alors le bandeau plutôt que d'afficher
                                // un cadre creux.
                                final notice = (await deva_get("worker.store.notice"))?.toString() ?? "";
                                final banner = await DvOrb.wait_for_shape("tiers_page/notice");
                                if (notice.isNotEmpty) {
                                    // {n} = le plafond courant. Même idiome de substitution que
                                    // tiers_upto et tiers_headcount plus bas : le texte de traduction
                                    // ne chiffre jamais la grille, qui se règle depuis le bucket.
                                    // Garde `cap >= 0` : par construction un bandeau de plafond suppose
                                    // un plafond, mais on n'écrira pas « au-delà de -1 aventuriers » le
                                    // jour où un autre motif passera par ici.
                                    var text = TranslationRegistry.processLabel(notice);
                                    final cap = await _storeMaxPlayers();
                                    if (cap >= 0) text = text.replaceAll("{n}", "$cap");
                                    await _syncLabel(banner, "tiers_page/notice", text);
                                }
                                await _syncVisible(banner, "tiers_page/notice", notice.isNotEmpty);

                                await _tiersSyncPeriodButtons();
                                await _tiersPushRows();
    }

    // Les deux boutons de périodicité. Celui qui est ACTIF s'annonce par sa couleur
    // de texte, pas par un libellé qui changerait : « Par mois » doit rester « Par
    // mois » qu'on soit dessus ou non, sinon on ne sait plus ce qu'on tape.
    Future<void> _tiersSyncPeriodButtons() async {

                                final monthly = await DvOrb.wait_for_shape("tiers_page/monthly");
                                final yearly  = await DvOrb.wait_for_shape("tiers_page/yearly");
                                const on  = "amber_200";
                                const off = "#7A6A3A";
                                await _syncGeom(monthly, "tiers_page/monthly", "shape.font_color",
                                    _storePeriod == "monthly" ? on : off);
                                await _syncGeom(yearly,  "tiers_page/yearly",  "shape.font_color",
                                    _storePeriod == "yearly"  ? on : off);
    }

    Future<void> tiers_set_monthly(dynamic caller, dynamic event) async {

                                await _tiersSetPeriod("monthly");
    }

    Future<void> tiers_set_yearly(dynamic caller, dynamic event) async {

                                await _tiersSetPeriod("yearly");
    }

    Future<void> _tiersSetPeriod(String period) async {

                                if (_storePeriod == period) return;
                                _storePeriod = period;
                                deva_log("info", "[store] paliers : périodicité → $period");
                                await _tiersSyncPeriodButtons();
                                await _tiersPushRows();
    }

    // Construit et pousse les cinq lignes.
    //
    // Deux marqueurs, et deux seulement : le palier COURANT et le palier CONSEILLÉ.
    // On a résisté à l'envie d'en ajouter (« le plus populaire », « le meilleur
    // rapport ») — ils dilueraient les deux qui répondent réellement à la question
    // posée, et une famille venue parce qu'on lui a refusé un membre n'a qu'une
    // chose à trouver sur cet écran.
    Future<void> _tiersPushRows() async {

                                final tiers = await _storeTiers();
                                final rows  = <Map<String, dynamic>>[];

                                final current = (await deva_get("store.subscription.product"))?.toString() ?? "";
                                final count   = await _storePlayerCount();
                                // Viser une place de PLUS que l'effectif, ou l'effectif tel quel ?
                                // L'intention est PUBLIÉE par _storeGotoTiers, elle n'est plus déduite
                                // de la présence d'un bandeau. L'ancienne inférence (« il y a un motif,
                                // donc c'est un refus de plafond, donc il faut une place de plus ») ne
                                // tombait juste que par accident : le refus de plafond se trouvait être
                                // le seul appelant à passer un motif. Toute venue portant un motif SANS
                                // demander de place — première cotisation, relance — se serait vu
                                // flécher le palier du dessus, donc vendre Clan à un foyer de deux qui
                                // tient très bien dans Essentiel, et précisément au moment où l'on
                                // cherche à ne pas faire peur.
                                final oneMore = (await deva_get("worker.store.one_more")) == true;
                                final next    = await _storeNextTier(
                                    current: current, count: count, oneMore: oneMore);

                                for (final id in tiers) {
                                    final cap = await _storeTierCapacity(id);

                                    // Le nom du CATALOGUE, pas celui de Play : sur un comparatif,
                                    // le titre Play répéterait « (Donjons & Savons) » à chacune des
                                    // cinq lignes et noierait le seul mot qui les distingue. Le
                                    // titre Play garde son sens sur une fiche d'achat — pas ici.
                                    var name = (await deva_get("store.catalog.$id.label"))?.toString() ?? "";
                                    if (name.isEmpty) name = (await deva_get("store.catalog.$id.title"))?.toString() ?? "";
                                    final label = TranslationRegistry.processLabel(name.isNotEmpty ? name : id);

                                    // Effectif puis prix, sur la même ligne : c'est la mise en regard
                                    // des deux qui fait la décision. Le prix vient de Play via
                                    // _tiersPrice (localisé, taxes incluses) et retombe sur le repli
                                    // du catalogue — de la bonne périodicité — si le canal est fermé.
                                    final seats = cap < 0
                                        ? TranslationRegistry.processLabel("@@@T:tiers_unlimited@@@")
                                        : TranslationRegistry.processLabel("@@@T:tiers_upto@@@")
                                            .replaceAll("{n}", "$cap");
                                    final price = await _tiersPrice(id);
                                    final desc  = StringBuffer(seats);
                                    if (price.isNotEmpty) desc.write("   $price");

                                    // L'effectif réel du clan, rappelé UNE fois : c'est le chiffre qui
                                    // explique et le refus, et le fléchage. Sous le palier courant s'il
                                    // y en a un, sinon sous le palier conseillé — un clan qui n'a
                                    // jamais souscrit n'a pas de ligne « courante » où l'accrocher, et
                                    // c'est précisément celui à qui le chiffre manque le plus.
                                    final anchor = current.isNotEmpty ? current : next;
                                    if (id == anchor && anchor.isNotEmpty && count >= 0) {
                                        desc.write("\n");
                                        desc.write(TranslationRegistry.processLabel("@@@T:tiers_headcount@@@")
                                            .replaceAll("{n}", "$count"));
                                    }

                                    rows.add({
                                        "id":    id,
                                        "label": label,
                                        "desc":  desc.toString(),
                                        "icon":  id == current ? "check_circle"
                                               : id == next    ? "arrow_circle_up"
                                               : "circle",
                                        "badge": id == current
                                                    ? TranslationRegistry.processLabel("@@@T:tiers_current@@@")
                                               : id == next
                                                    ? TranslationRegistry.processLabel("@@@T:tiers_next@@@")
                                               : "",
                                        "selected": id == current,
                                        // On ne rachète pas le palier qu'on a déjà. Tous les autres
                                        // restent tapables, y compris les MOINS chers : une descente
                                        // de palier est un droit, et la refuser pousserait à résilier
                                        // tout court — ce qui coûte bien plus qu'un downgrade.
                                        "enabled": id != current,
                                    });
                                }

                                ActionRegistry.get("dvlist.set_rows")?.call(null, rows);
                                deva_log("info", "[store] paliers : ${rows.length} ligne(s), "
                                    "courant='$current' conseillé='$next' effectif=$count ($_storePeriod)");
    }

    // Prix d'un palier POUR LA PÉRIODICITÉ AFFICHÉE.
    //
    // Ne réutilise pas `_storeRowPrice` : ses deux derniers replis sont le prix
    // d'appel et `price_hint`, tous deux MENSUELS. Sur une fiche produit c'est
    // acceptable ; ici, sous l'onglet « Par an », cela afficherait un tarif mensuel
    // comme s'il était annuel — une page de tarifs qui ment est pire qu'une page de
    // tarifs vide, et elle mentirait précisément pendant toute la recette, où aucun
    // canal Play n'est ouvert.
    //
    // Ordre : le prix du base plan (Play s'il est là — localisé et taxes incluses,
    // seule vérité —, sinon le repli de la bonne périodicité, que dvstore choisit
    // désormais lui-même via `_hintForPlan`), puis le repli du catalogue lu en
    // direct, puis RIEN. Jamais le prix de l'autre périodicité.
    Future<String> _tiersPrice(String productId) async {

                                final plan = await _storePlanId(productId);
                                if (plan.isNotEmpty) {
                                    final live = (await deva_get("store.catalog.$productId.plans.$plan.price"))?.toString() ?? "";
                                    if (live.isNotEmpty) return live;
                                }
                                final key = _storePeriod == "yearly" ? "price_hint_yearly" : "price_hint";
                                return (await deva_get("store.catalog.$productId.$key"))?.toString() ?? "";
    }

    // Tap sur une ligne : achat du palier, derrière le contrôle parental.
    //
    // `offer: null` = celle que le serveur juge éligible (essai 14 j pour un nouveau
    // client, offre fondateurs pour un clan d'avant le cutoff). On ne force rien
    // ici : Play ne sert que les offres auxquelles le compte a droit, et c'est la
    // vérification serveur qui constate ensuite ce qui a été appliqué.
    Future<void> tiers_pick(dynamic caller, dynamic event) async {

                                final m  = (event is Map) ? event : const {};
                                final id = m["id"]?.toString() ?? "";
                                if (id.isEmpty) return;
                                deva_log("info", "[store] paliers : $id ($_storePeriod)");
                                await _storeBuyGated(id);
    }

    // -----------------------------------------------------------------------
    // --- Banc d'essai : changer de scénario sans rebuilder
    //
    // Simulation LOCALE (`store.debug.simulate_*`, relu par dvstore à chaque
    // `store.refresh`), plus l'envoi à la demande de la relance push correspondante.
    // Aucun serveur, aucune allowlist, aucun redéploiement — voir le commentaire de
    // store_scenario_apply pour ce qui a été essayé et pourquoi c'était trop cher.
    //
    // CE QUE LE BANC NE REPRODUIT PAS, et qu'il faut savoir en lisant ses résultats :
    //   - la projection clans_store n'est pas écrite : l'état ne se propage pas aux
    //     autres appareils du clan, et il disparaît au redémarrage ;
    //   - le balayage quotidien du serveur ne voit rien. Il tourne à 5 h du matin :
    //     on ne l'observait de toute façon pas dans une session de test.
    // Tout le reste — écrans, plafonds, bandeau, journal, notification — se comporte
    // exactement comme en production.
    //
    // Le CATALOGUE de scénarios vit dans le layer cloud (store-base-global.yml) : en
    // ajouter un se fait en republiant les assets, sans toucher au code.
    // -----------------------------------------------------------------------

    Future<void> on_store_scenario_appear(dynamic caller, dynamic event) async {

                                final summary = await DvOrb.wait_for_shape("store_scenario_page/summary");

                                // Ce que dvstore publie VRAIMENT après la bascule : c'est la
                                // confirmation que le scénario a pris, sans quoi on tapote et l'on
                                // croit sur parole.
                                //
                                // `source` reste affiché parce que c'est LA ligne qui dit ce qu'on
                                // est en train d'éprouver : "simulated" = cet appareil seulement,
                                // "server" = l'entitlement réel écrit par Play et la vérification
                                // serveur. Confondre les deux est exactement le malentendu qu'un
                                // banc d'essai doit rendre impossible.
                                final state   = (await deva_get("store.subscription.state"))?.toString()   ?? "none";
                                final product = (await deva_get("store.subscription.product"))?.toString() ?? "";
                                final phase   = (await deva_get("store.subscription.dunning_phase"))?.toString() ?? "";
                                final source  = (await deva_get("store.source"))?.toString()               ?? "cache";

                                final text = StringBuffer(await _storeStateLabel(state));
                                if (product.isNotEmpty) text.write("  $product");
                                if (phase.isNotEmpty)   text.write("  relance=$phase");
                                text.write("\n[$source]");
                                if (_storeBenchError.isNotEmpty) text.write("\n$_storeBenchError");

                                await _syncLabel(summary, "store_scenario_page/summary", text.toString());

                                final active    = (await deva_get("store.debug.scenario"))?.toString() ?? "";
                                final rows      = <Map<String, dynamic>>[];
                                final scenarios = await deva_get("store.debug.scenarios");
                                if (scenarios is Dvidle) {
                                    for (final key in scenarios.keys) {
                                        final label = (await deva_get("store.debug.scenarios.$key.label"))?.toString() ?? key;
                                        final desc  = (await deva_get("store.debug.scenarios.$key.desc"))?.toString()  ?? "";
                                        rows.add({
                                            "id":       key,
                                            "icon":     key == active ? "radio_button_checked" : "radio_button_unchecked",
                                            "label":    TranslationRegistry.processLabel(label),
                                            "desc":     TranslationRegistry.processLabel(desc),
                                            "selected": key == active,
                                        });
                                    }
                                }

                                ActionRegistry.get("dvlist.set_rows")?.call(null, rows);
                                deva_log("info", "[store] banc d'essai : ${rows.length} scénario(s), actif='$active'");
    }

    // Efface les réglages de simulation LOCALE que dvstore lit dans sa conf.
    //
    // Ces clefs sont PERSISTÉES avec le reste du dictionnaire (layer conf-global sur
    // disque) : elles survivent à la fermeture de l'app, et même au remplacement du
    // binaire. Un `simulate_state` posé un jour gardait donc dvstore en mode simulé
    // pour toujours — y compris après être « revenu au réel », et y compris dans une
    // version qui ne sait plus les écrire. D'où l'effacement au début de CHAQUE
    // bascule, celle vers le réel comprise.
    //
    // Vider avec le bon TYPE n'est pas un détail : dvstore lit `simulate_credits` par
    // un `as num?` qui lèverait sur une chaîne, et `simulate_products` par un `is List`.
    Future<void> _storeBenchClearLocal() async {

                                const rest = <String, dynamic>{
                                    "state": "", "product": "", "products": <String>[],
                                    "dunning_phase": "", "founder": false, "credits": 0, "offer": "",
                                };
                                for (final e in rest.entries) {
                                    await deva_set("store.debug.simulate_${e.key}", e.value);
                                }
    }

    // Applique le scénario tapé, en mémoire, puis fait relire dvstore.
    //
    // POURQUOI PAS D'ÉCRITURE SERVEUR. Une première version passait par une fonction
    // `store_simulate` qui écrivait la vraie projection clans_store. C'était payer très
    // cher trois avantages minces :
    //
    //   - la projection ne peut pas être écrite par un client (règle
    //     `allow create, update, delete: if false`), il fallait donc une fonction ;
    //   - cette fonction accorde un droit PAYANT, et la pile est unique — elle serait
    //     joignable en production. « Être administrateur du clan » ne la protège pas :
    //     n'importe qui crée un clan et en devient l'administrateur. Il fallait donc
    //     une allowlist de comptes, donc un identifiant à maintenir et un
    //     redéploiement pour chaque changement ;
    //   - et ce qu'elle apportait vraiment se réduisait à la propagation aux autres
    //     appareils du clan. Le balayage de relance, lui, tourne une fois par jour à
    //     5 h : on ne l'observe pas dans une session de test, quoi qu'on écrive.
    //
    // Ce qui manquait réellement — recevoir la notification — ne demandait aucun
    // serveur : le client sait déjà notifier les chefs d'un clan (il le fait pour la
    // validation des tâches), et _notifyDunning réutilise ce chemin avec le texte de
    // la vraie relance. On obtient donc l'essentiel sans ouvrir la moindre porte.
    Future<void> store_scenario_apply(dynamic caller, dynamic event) async {

                                final m   = (event is Map) ? event : const {};
                                final key = m["id"]?.toString() ?? "";
                                if (key.isEmpty) return;

                                _storeBenchError = "";

                                // TOUJOURS en premier, quel que soit le scénario visé : c'est la seule
                                // façon de garantir qu'aucun réglage d'un essai précédent ne survive.
                                await _storeBenchClearLocal();

                                final state = (await deva_get("store.debug.scenarios.$key.state"))?.toString() ?? "";
                                final phase = (await deva_get("store.debug.scenarios.$key.dunning_phase"))?.toString() ?? "";

                                // `reel` (aucun état déclaré) : les réglages viennent d'être effacés,
                                // dvstore repart donc sur son chemin réel et relit l'entitlement écrit
                                // par le serveur. C'est la sortie du banc.
                                if (state.isNotEmpty) {
                                    // Le catalogue parle en `tier`/`credits` (le vocabulaire de la
                                    // projection serveur), dvstore attend `simulate_product` /
                                    // `simulate_credits` : la traduction se fait ici, et nulle part
                                    // ailleurs.
                                    await deva_set("store.debug.simulate_state",   state);
                                    await deva_set("store.debug.simulate_product",
                                        (await deva_get("store.debug.scenarios.$key.tier"))?.toString() ?? "");
                                    await deva_set("store.debug.simulate_dunning_phase", phase);
                                    await deva_set("store.debug.simulate_founder",
                                        await deva_get("store.debug.scenarios.$key.founder") == true);
                                    await deva_set("store.debug.simulate_credits",
                                        ((await deva_get("store.debug.scenarios.$key.credits")) as num?)?.toInt() ?? 0);
                                }

                                await deva_set("store.debug.scenario", key);
                                deva_log("info", "[store] scénario appliqué : $key (${state.isEmpty ? "réel" : state})");

                                // Relecture, puis réévaluation du rappel de cotisation : sinon la
                                // bascule ne se verrait qu'au prochain passage par le dashboard.
                                await ActionRegistry.get("store.refresh")?.call(null, null);
                                await _evaluateDunning();

                                // La relance push, à la demande. C'est la seule chose que la
                                // simulation locale ne produirait pas d'elle-même, et c'était
                                // justement ce qui manquait pour éprouver un impayé de bout en bout.
                                if (phase.isNotEmpty) await _storeBenchNotify(phase);

                                await on_store_scenario_appear(caller, event);
    }

    // Envoi de la relance correspondant au scénario. Jamais fatal : un scénario reste
    // appliqué même si la notification ne part pas (appareil sans jeton, hors-ligne),
    // et c'est le bandeau qui le dira.
    Future<void> _storeBenchNotify(String phase) async {

                                final ctx = await _butinCtx();
                                if (ctx == null) {
                                    _storeBenchError = TranslationRegistry.processLabel("@@@T:scenario_no_clan@@@");
                                    return;
                                }
                                await _notifyDunning(
                                    ctx.get("clanId").toString(),
                                    ctx.get("clanSecret").toString(),
                                    ctx.get("region").toString(),
                                    phase);
    }

    // -----------------------------------------------------------------------
    // --- Helpers
    // -----------------------------------------------------------------------

    // Qui peut acheter : un administrateur du clan. Le contrôle parental s'ajoute
    // au moment de l'achat lui-même (_storeBuyGated) — être adulte administrateur
    // ne dispense pas de prouver qu'on l'est devant l'écran.
    Future<bool> _storeCanBuy() async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return false;
                                return _ensureIsAdmin(ctx.get("clanId").toString(),
                                                      ctx.get("clanSecret").toString(),
                                                      ctx.get("region").toString());
    }

    // Achat sous double condition : administrateur du clan, puis porte parentale.
    // L'app s'adresse à des enfants — c'est une exigence de la politique
    // « Familles » du store autant qu'une évidence de conception.
    //
    // dvparentalgate ne REND rien : il empile son écran et rappelle l'action
    // `on_success` une fois l'épreuve franchie. L'achat est donc différé, et le
    // produit visé mis de côté le temps du détour (même mécanique que
    // _giveItemId pour give_page). Un abandon ne rappelle personne : le produit
    // en attente est simplement oublié au prochain essai.
    // `offer` : null = l'offre que le serveur a jugée éligible (comportement par
    // défaut, remises comprises) ; "" = le tarif courant SANS aucune offre. Voir
    // dvstore.buy — la distinction porte une règle commerciale.
    Future<void> _storeBuyGated(String productId, {String? offer}) async {

                                if (productId.isEmpty) return;

                                if (!await _storeCanBuy()) {
                                    deva_log("info", "[store] achat non proposé : $_userId n'administre pas ce clan");
                                    return;
                                }

                                final gate = ActionRegistry.get("parentalgate.invoke_gate");
                                if (gate == null) {
                                    deva_log("error", "[store] contrôle parental indisponible — achat abandonné");
                                    return;
                                }

                                _storePendingBuy   = productId;
                                _storePendingOffer = offer;
                                await gate.call(null, {
                                    "mode":       "defi_calcul",
                                    "on_success": "worker.store_gate_passed",
                                });
    }

    // Porte franchie : l'achat mis de côté peut partir. `event` porte la preuve
    // produite par dvparentalgate (horodatée) — on ne la conserve pas : ce n'est
    // pas une autorisation durable, chaque achat repasse par la porte.
    Future<void> store_gate_passed(dynamic caller, dynamic event) async {

                                final productId    = _storePendingBuy;
                                final offer        = _storePendingOffer;
                                _storePendingBuy   = "";
                                _storePendingOffer = null;
                                if (productId.isEmpty) return;

                                deva_log("info", "[store] contrôle parental franchi → achat de $productId "
                                                 "($_storePeriod, offre=${offer == null ? "<éligible>" : offer.isEmpty ? "<aucune>" : offer})");
                                // `offer` null : dvstore applique celle que le serveur a jugée
                                // éligible (offre fondateurs le cas échéant). "" : tarif courant sec,
                                // ce que demande une reprise après gel.
                                await _store?.buy(productId, period: _storePeriod, offer: offer);
    }

    // Le clan est-il actif grâce à un MOIS OFFERT plutôt qu'à un prélèvement ?
    // (offre fondateurs, parrainage, compensation des familles du test fermé, dont
    // les achats sous licence sont gratuits). Lu sur `store.credits.until`, que le
    // serveur pose en consommant un crédit : le client ne le déduit pas, il le
    // constate — c'est le balayage quotidien qui décide, pas l'app.
    Future<bool> _storeOnCredit() async {

                                final raw = (await deva_get("store.credits.until"))?.toString() ?? "";
                                if (raw.isEmpty) return false;
                                final until = DateTime.tryParse(raw);
                                return until != null && until.isAfter(DateTime.now().toUtc());
    }

    // `expired` fait partie de la liste : sans lui, un abonnement arrivé à terme
    // retombait sur le libellé de `none` (« Aucune cotisation en cours »), ce qui
    // est faux — il y en a eu une, et c'est justement ce qu'on veut dire.
    Future<String> _storeStateLabel(String state) async {

                                const known = ["none", "trial", "active", "canceled",
                                               "grace", "hold", "locked", "expired"];
                                final key   = known.contains(state) ? state : "none";
                                return TranslationRegistry.processLabel("@@@T:store_state_$key@@@");
    }

    // Échéance lisible. Vide si aucune date n'est connue — mieux vaut ne rien
    // afficher qu'une date fantaisiste sur un écran de facturation.
    Future<String> _storeExpiryLabel() async {

                                final raw = (await deva_get("store.subscription.expiry"))?.toString() ?? "";
                                if (raw.isEmpty) return "";
                                final d = DateTime.tryParse(raw);
                                if (d == null) return "";
                                return "${TranslationRegistry.processLabel("@@@T:store_expires@@@")} : ${_storeShortDate(d)}";
    }

    // Date courte, dans le fuseau de l'appareil. Format numérique volontaire : un
    // relevé de facturation n'a pas à traduire des noms de mois, et la lecture est
    // la même dans les trois langues de l'app.
    String _storeShortDate(DateTime d) {

                                final local = d.toLocal();
                                return "${local.day.toString().padLeft(2, '0')}/"
                                       "${local.month.toString().padLeft(2, '0')}/${local.year}";
    }

    // Base plan correspondant à la périodicité affichée. On ne reconstruit PAS
    // l'identifiant (« ${productId}-$_storePeriod » serait faux : la convention est
    // `clan-monthly`, pas `ddust_clan-monthly`) : on lit les base plans que
    // dvstore a publiés depuis le catalogue et on retient celui dont le SUFFIXE
    // correspond. La table des périodicités reste ainsi au catalogue, jamais ici.
    Future<String> _storePlanId(String productId) async {

                                final plans = await deva_get("store.catalog.$productId.plans");
                                if (plans is! Dvidle || plans.keys.isEmpty) return "";
                                for (final id in plans.keys) {
                                    if (id.endsWith("-$_storePeriod")) return id;
                                }
                                // Périodicité non déclarée pour ce produit : le premier base plan,
                                // qui est aussi celui que Play sert par défaut (cf. basePlanFor).
                                return plans.keys.first;
    }

    // -----------------------------------------------------------------------
    // --- Codes cadeaux
    // -----------------------------------------------------------------------
    //
    // Ce que fait cet écran : présenter un code. Rien d'autre. Le droit s'acquiert
    // serveur (cloud function `store_claim`), qui vérifie l'appartenance au clan, le
    // droit de l'engager, le plafond d'essais, puis consomme le code dans une
    // transaction avant de créditer. Un client modifié ne gagnerait donc rien à mentir
    // ici — il n'a rien à mentir, il transmet une chaîne de caractères.
    //
    // Les mois obtenus rejoignent la MÊME réserve que les mois offerts à la main
    // (`credit_months`), consommée par le balayage quotidien. Réclamer pendant une
    // cotisation payante ne perd donc rien : la réserve attend que l'abonnement
    // retombe.

    Future<void> on_giftcode_appear(dynamic caller, dynamic event) async {

                                final code  = await DvOrb.wait_for_shape("giftcode_page/code");
                                code?..set("shape.value", "")..refreshUI();

                                _giftcodeError("");
                                _setGiftcodeOkVisible(false);
    }

    // Ligne d'erreur : un seul widget, dont on change le libellé avant de le révéler.
    // MÉMOIRE SEULE (aucun deva_set, aucun store) — même raison que le bandeau
    // d'impayé : un message d'échec persisté sur disque réapparaîtrait à la prochaine
    // ouverture de l'écran, alors que le code est passé depuis.
    void _giftcodeError(String token) {

                                final err = DvOrb.get_shape_by_id("giftcode_page/error");
                                if (err == null) return;
                                if (token.isEmpty) {
                                    err..set("shape.visible", false)..refreshUI();
                                    return;
                                }
                                err
                                    ..set("shape.label", TranslationRegistry.processLabel("@@@T:$token@@@"))
                                    ..set("shape.visible", true)
                                    ..refreshUI();
    }

    // Overlay de succès : widgets invisibles rendus visibles, jamais une popup modale
    // (idiome commons/death_* et clan_page/invite_*).
    void _setGiftcodeOkVisible(bool v) {

                                for (final id in const [
                                    "giftcode_page/ok_scrim",
                                    "giftcode_page/ok_panel",
                                    "giftcode_page/ok_close",
                                ]) {
                                    final s = DvOrb.get_shape_by_id(id);
                                    s?.set("shape.visible", v);
                                    s?.refreshUI();
                                }
    }

    Future<void> on_giftcode_confirm(dynamic caller, dynamic event) async {

                                _giftcodeError("");

                                final code = DvOrb.get_shape_by_id("giftcode_page/code")
                                    ?.get("shape.value")?.toString().trim() ?? "";
                                if (code.isEmpty) {
                                    _giftcodeError("giftcode_empty");
                                    return;
                                }

                                // Garde d'écran seulement : la vraie est serveur (SCOPE_ADMIN_FIELD).
                                // Elle évite d'envoyer une réclamation vouée au refus — et donc de
                                // brûler un essai — depuis un bouton laissé visible par une
                                // synchronisation en retard.
                                if (!await _storeCanBuy()) {
                                    _giftcodeError("giftcode_not_admin");
                                    return;
                                }

                                final ctx = await _butinCtx();
                                if (ctx == null) {
                                    _giftcodeError("giftcode_network");
                                    return;
                                }

                                String status = "";
                                int    months = 0;
                                try {
                                    final res = await _cloud?.call("store_claim", Dvidle({
                                        "code":        code,
                                        "scopeId":     ctx.get("clanId").toString(),
                                        "scopeSecret": ctx.get("clanSecret").toString(),
                                    }));
                                    status = res?.get("status")?.toString() ?? "";
                                    months = int.tryParse(res?.get("months")?.toString() ?? "0") ?? 0;
                                } catch (e) {
                                    // Hors-ligne, fonction pas encore déployée, panne : on ne sait
                                    // pas si le code est bon, on ne prétend donc rien. Réessayer
                                    // plus tard ne coûte rien — un code n'expire pas d'un aller-retour.
                                    deva_log("error", "[store] réclamation de code injoignable: $e");
                                    _giftcodeError("giftcode_network");
                                    return;
                                }

                                if (status != "ok") {
                                    // Un statut inconnu (fonction plus récente que l'app) retombe
                                    // sur le message générique plutôt que d'afficher un jeton brut.
                                    const known = ["invalid", "used", "exhausted", "expired",
                                                   "throttled", "not_admin"];
                                    final token = known.contains(status) ? status : "network";
                                    deva_log("info", "[store] code refusé : $status");
                                    _giftcodeError("giftcode_$token");
                                    return;
                                }

                                deva_log("info", "[store] code accepté : +$months mois offerts");

                                // La projection vient de changer côté serveur. On ne l'attend pas de
                                // la vigilance temps réel : le chef est devant son écran, il doit
                                // voir l'effet tout de suite.
                                await ActionRegistry.get("store.refresh")?.call(null, null);

                                // Le message dit ce qui a été reçu, pas quand ça s'ouvre : un mois
                                // offert commence au prochain balayage, et promettre une date que
                                // l'app ne décide pas serait un mensonge poli.
                                final panel = DvOrb.get_shape_by_id("giftcode_page/ok_panel");
                                if (panel is DvLabel) {
                                    panel.write(TranslationRegistry.processLabel(
                                        months > 1 ? "@@@T:giftcode_success@@@" : "@@@T:giftcode_success_one@@@")
                                        .replaceAll("@@@months@@@", "$months"));
                                }
                                _setGiftcodeOkVisible(true);
    }

    Future<void> on_giftcode_close(dynamic caller, dynamic event) async {

                                _setGiftcodeOkVisible(false);
                                DvOrb.navigate_back();
    }

    // --- Fabrique de codes (mode test) ---------------------------------------
    // N'existe que derrière store.debug.test_mode + administrateur, comme le banc
    // d'essai. La garde qui compte est serveur : `store_mint` refuse tout compte
    // absent de GRANT_ADMINS, et cet écran ne rend donc rien entre d'autres mains.

    Future<void> on_giftcode_mint_appear(dynamic caller, dynamic event) async {

                                final result = await DvOrb.wait_for_shape("giftcode_mint_page/result");
                                if (result is DvLabel) result.write("");

                                final share = DvOrb.get_shape_by_id("giftcode_mint_page/share");
                                share?..set("shape.visible", false)..refreshUI();

                                await deva_set("worker.mint.codes", "");
    }

    Future<void> on_giftcode_mint(dynamic caller, dynamic event) async {

                                final result = DvOrb.get_shape_by_id("giftcode_mint_page/result");
                                final share  = DvOrb.get_shape_by_id("giftcode_mint_page/share");

                                int intOf(String id, int fallback) {
                                    final raw = DvOrb.get_shape_by_id(id)?.get("shape.value")?.toString().trim() ?? "";
                                    return int.tryParse(raw) ?? fallback;
                                }

                                final count   = intOf("giftcode_mint_page/count",  0);
                                final months  = intOf("giftcode_mint_page/months", 0);
                                final maxUses = intOf("giftcode_mint_page/uses",   1);
                                // 0 = sans fin. La date est calculée au SERVEUR à partir de ce
                                // nombre de jours : l'horloge de l'appareil de l'éditeur n'a pas
                                // à décider quand un lot se ferme.
                                final days    = intOf("giftcode_mint_page/days",   0);
                                final label   = DvOrb.get_shape_by_id("giftcode_mint_page/label")
                                    ?.get("shape.value")?.toString().trim() ?? "";

                                share?..set("shape.visible", false)..refreshUI();

                                try {
                                    final res = await _cloud?.call("store_mint", Dvidle({
                                        "count":        count,
                                        "months":       months,
                                        "max_uses":     maxUses,
                                        "expires_days": days,
                                        "label":        label,
                                    }));
                                    if (res?.get("status")?.toString() != "ok") {
                                        if (result is DvLabel) result.write("mint: réponse inattendue");
                                        return;
                                    }

                                    final codes = List<dynamic>.from(res?.get("codes") as List? ?? [])
                                        .map((c) => c.toString()).toList();
                                    final batch = res?.get("batch")?.toString() ?? "";

                                    // Les codes ne repasseront JAMAIS : seule leur empreinte est
                                    // conservée serveur. Ils sont posés dans le dictionnaire pour
                                    // que `share.gift_codes` puisse les sortir de l'app, et c'est
                                    // le seul moyen de les garder.
                                    final validity = days > 0 ? "$days j" : "sans fin";
                                    final text = "$batch — $months mois × ${codes.length} "
                                                 "($maxUses usage(s), $validity)\n\n${codes.join("\n")}";
                                    await deva_set("worker.mint.codes", text);
                                    if (result is DvLabel) result.write(text);
                                    share?..set("shape.visible", codes.isNotEmpty)..refreshUI();

                                    deva_log("info", "[store] lot $batch : ${codes.length} codes de $months mois "
                                                     "($validity)");
                                } catch (e) {
                                    deva_log("error", "[store] fabrication de codes FAILED: $e");
                                    if (result is DvLabel) result.write("mint: $e");
                                }
    }

    // Couper un lot (son identifiant, rendu à la fabrication) ou un code isolé. Le
    // serveur distingue les deux à la longueur : un identifiant de lot fait 8 signes,
    // un code 12. On lui transmet donc le champ dans les deux cases et il tranche.
    Future<void> on_giftcode_revoke(dynamic caller, dynamic event) async {

                                final result = DvOrb.get_shape_by_id("giftcode_mint_page/result");
                                final field  = DvOrb.get_shape_by_id("giftcode_mint_page/revoke");
                                final raw    = field?.get("shape.value")?.toString().trim() ?? "";
                                if (raw.isEmpty) return;

                                // Normalisation locale, uniquement pour COMPTER les signes : le
                                // serveur refait la sienne, elle seule fait foi.
                                final bare = raw.toUpperCase().replaceAll(RegExp(r"[^0-9A-Z]"), "");
                                final asBatch = bare.length <= 8;

                                try {
                                    final res = await _cloud?.call("store_revoke", Dvidle({
                                        if (asBatch) "batch": bare else "code": raw,
                                    }));
                                    final status  = res?.get("status")?.toString() ?? "";
                                    final revoked = int.tryParse(res?.get("revoked")?.toString() ?? "0") ?? 0;

                                    final line = status == "ok"
                                        ? "$bare — $revoked code(s) coupé(s)"
                                        : "$bare — introuvable";
                                    if (result is DvLabel) result.write(line);
                                    field?..set("shape.value", "")..refreshUI();

                                    deva_log("info", "[store] coupure : $line");
                                } catch (e) {
                                    deva_log("error", "[store] coupure de codes FAILED: $e");
                                    if (result is DvLabel) result.write("revoke: $e");
                                }
    }

}

// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
