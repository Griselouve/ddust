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
                                ActionRegistry.register("worker.on_store_purchase_pending",      on_store_purchase_pending);
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
                                ActionRegistry.register("worker.on_locked_appear",         on_locked_appear);
                                ActionRegistry.register("worker.store_revive_clan",        store_revive_clan);

                                // --- Page des paliers ---
                                ActionRegistry.register("worker.on_tiers_appear",          on_tiers_appear);
                                ActionRegistry.register("worker.tiers_pick_yearly",        tiers_pick_yearly);
                                ActionRegistry.register("worker.tiers_pick_monthly",       tiers_pick_monthly);
                                ActionRegistry.register("worker.tiers_buy",                tiers_buy);
                                ActionRegistry.register("worker.tiers_open_pick",          tiers_open_pick);
                                ActionRegistry.register("worker.tiers_defer",              tiers_defer);
                                // --- Choix du palier (tiers_pick_page) ---
                                ActionRegistry.register("worker.on_tiers_pick_appear",     on_tiers_pick_appear);
                                ActionRegistry.register("worker.tiers_pick_1",             tiers_pick_1);
                                ActionRegistry.register("worker.tiers_pick_2",             tiers_pick_2);
                                ActionRegistry.register("worker.tiers_pick_3",             tiers_pick_3);
                                ActionRegistry.register("worker.tiers_pick_4",             tiers_pick_4);
                                ActionRegistry.register("worker.tiers_pick_5",             tiers_pick_5);
                                ActionRegistry.register("worker.tiers_pick_6",             tiers_pick_6);

                                // --- Codes cadeaux ---
                                ActionRegistry.register("worker.on_giftcode_appear",       on_giftcode_appear);
                                ActionRegistry.register("worker.on_giftcode_confirm",      on_giftcode_confirm);
                                ActionRegistry.register("worker.on_giftcode_close",        on_giftcode_close);

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
                                await _storeChangeLanded();
                                await _evaluateDunning();
    }

    // CHANGEMENT DE PALIER ABOUTI ? Un abonnement neuf se signale par
    // on_store_subscription, un changement non : le clan était déjà abonné, il le
    // reste. Une montée change le palier (ou la périodicité), une descente ne change
    // RIEN tout de suite, elle s'annonce seulement pour l'échéance. Sans ce contrôle, la
    // roue d'attente tournait jusqu'à son minuteur de secours. On compare donc la
    // projection publiée à la cible demandée : en cours, ou en attente, c'est acquis.
    Future<void> _storeChangeLanded() async {

                                if (_storeChangeTo.isEmpty || _storeBuyWaitPage == null) return;
                                final product = (await deva_get("store.subscription.product"))?.toString() ?? "";
                                final plan    = (await deva_get("store.subscription.base_plan"))?.toString() ?? "";
                                final pTier   = (await deva_get("store.subscription.pending_tier"))?.toString() ?? "";
                                final pPlan   = (await deva_get("store.subscription.pending_base_plan"))?.toString() ?? "";
                                if (_storeChangeTo != "$product|$plan" && _storeChangeTo != "$pTier|$pPlan") return;
                                deva_log("info", "[store] changement de palier acquis : $_storeChangeTo");
                                _storeChangeTo = "";
                                await _storeLeaveAfterPurchase();
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
    // `store.subscription.state` pouvait être TOTALEMENT ABSENT du dictionnaire : dvstore
    // ne publiait rien quand le document `clans_store/<clanId>` n'existait pas, soit pour
    // tout clan qui n'a jamais souscrit. Depuis le 2026-09-24, dvstore publie `none` dans
    // ce cas, et publie aussi en fin de démarrage quand la lecture échoue. La clef peut
    // encore manquer avant le tout premier démarrage de dvstore sur l'appareil : la
    // normalisation reste, par précaution. Une lecture naïve rendrait `null`.
    //
    // Il n'existe AUCUN état « je ne sais pas encore » dans l'énumération de dvstore
    // (none|trial|active|canceled|grace|hold|locked|expired). « Absent », « vide » et
    // « none » disent donc ici la même chose, et les distinguer reviendrait à inventer
    // une information que personne ne publie.
    Future<String> _storeState() async {

                                final s = (await deva_get("store.subscription.state"))?.toString() ?? "";
                                return s.isEmpty ? "none" : s;
    }

    // RÈGLE DU PAYEUR (2026-09-24) : un abonnement s'arrête dès que son payeur n'est plus
    // chef actif du clan, ou que le clan est dissous. Le client ne DÉCIDE rien : il demande
    // à `store_payer_check` (pustore) de relire le clan et de résilier si la règle, vérifiée
    // côté serveur, le dit. Appelé juste après ce qui peut la rendre vraie :
    //   - revoke_player / nomore_chief d'un CHEF (scopeId = le clan : le payeur peut être
    //     un autre que l'appelant) ;
    //   - la suppression de compte (scopeId vide : chaque clan dont l'appelant a payé).
    // Ne lève jamais, et ne remonte aucune erreur : le geste de l'utilisateur est déjà fait,
    // et le balayage quotidien de pustore applique la même règle en filet si cet appel se
    // perd. Les gestes du roster ne l'attendent pas (unawaited) ; la suppression de compte,
    // si, parce que la déconnexion qui suit retire le jeton d'authentification.
    Future<void> _storePayerCheck({String clanId = "", String region = ""}) async {

                                final payload = Dvidle({});
                                if (clanId.isNotEmpty) payload.set("scopeId", clanId);
                                try {
                                    final res = await _cloud?.call("store_payer_check", payload,
                                        region: region.isEmpty ? null : region,
                                        timeout: const Duration(seconds: 20));
                                    deva_log("info", "[store] règle du payeur : "
                                        "${res?.get("status")} résilié(s)=${res?.get("canceled")}");
                                } catch (e) {
                                    deva_log("warning", "[store] règle du payeur injoignable "
                                        "(le balayage quotidien repassera) : $e");
                                }
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
    // chaque republication d'état.
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

                                _storeBuyWaitStop();
                                _storeChangeTo = "";
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

    // Play a mis le paiement EN ATTENTE (espèces, virement, moyen de paiement à
    // valider). Ce n'est ni un succès ni un échec : l'issue viendra dans des heures,
    // par on_store_subscription ou on_store_purchase_failed. Sans ce retour, la roue
    // d'attente tournait trois minutes puis la page se dégelait sans un mot, et la
    // famille concluait à un achat qui n'avait rien fait, ou rachetait.
    //
    // ⚠ dvstore rappelle ce hook quand l'achat encore en attente revient dans une
    //   autre session (« Restaurer mes achats », redélivrance par Play). Hors d'un
    //   achat en cours (pas de roue d'attente), on ne dit rien : ouvrir la page des
    //   paliers à ce moment-là serait incompréhensible.
    Future<void> on_store_purchase_pending(dynamic caller, dynamic event) async {

                                final m = (event is Map) ? event : const {};
                                deva_log("info", "[store] paiement en attente: ${m["product"]}");
                                if (_storeBuyWaitPage == null) return;
                                _storeBuyWaitStop();
                                await _storeShowNotice("@@@T:store_pending@@@");
    }

    // Affiche l'échec sur le bandeau de la page des paliers.
    Future<void> _storeShowPurchaseError(String reason) async {

                                // `unavailable` : la facturation n'existe pas sur cet appareil (Play
                                // Services absent, profil restreint). Réessayer n'y changera rien, le
                                // texte le dit. Les trois refus de CHANGEMENT DE PALIER disent chacun
                                // quoi faire (cf. dvstore) : réessayer n'y changerait rien non plus.
                                // Tout le reste — refus de Play, vérification serveur en échec,
                                // périodicité absente — relève du « ça n'a pas abouti, vous n'avez
                                // pas été débité ».
                                await _storeShowNotice(switch (reason) {
                                    "unavailable"     => "@@@T:store_unavailable@@@",
                                    "not_payer"       => "@@@T:store_not_payer@@@",
                                    "payment_issue"   => "@@@T:store_payment_issue@@@",
                                    "already_pending" => "@@@T:store_already_pending@@@",
                                    _                 => "@@@T:store_error@@@",
                                });
    }

    // Affiche un avis d'achat (échec, paiement en attente) sur le bandeau de la page
    // des paliers.
    //
    // Deux situations, et une seule sortie : si l'on est déjà sur `tiers_page` —
    // le cas ordinaire, la feuille Play s'est refermée par-dessus — on repeint le
    // bandeau en place, sans renavigation qui ferait clignoter l'écran. Sinon
    // (achat lancé depuis la boutique ou la fiche produit) on ouvre la page, qui
    // est de toute façon l'endroit où réessayer.
    //
    // Jamais de popup : idiome des overlays du projet.
    Future<void> _storeShowNotice(String token) async {

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
    // ÉCRIT AUSSI AVEC LE SIMULATEUR DE STORE (storemock), délibérément. Un scénario de
    // test qui ne laisserait pas de trace ne prouverait rien : c'est justement au
    // journal qu'on vient vérifier qu'un achat, un incident ou une reprise sont bien
    // racontés à la famille. Les lignes d'essai se lisent comme les vraies, et se
    // purgent avec le reste du clan de test.
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
    // CHEFS DE CLAN ADULTES UNIQUEMENT. « On n'inquiète surtout pas les enfants », et ce sont
    // de toute façon les seuls destinataires des relances push comme les seuls capables de
    // payer. Un adulte non-chef n'y peut rien non plus.
    // La garde passe par _storeCanBuy et non par _ensureIsAdmin : ce bandeau est une relance
    // de paiement, donc une surface commerciale, et il doit tomber sous le MÊME prédicat que
    // la boutique. Le tester séparément est exactement ce qui avait laissé passer le cas du
    // mineur promu chef.
    Future<void> _evaluateDunning() async {

                                try {
                                    final phase = (await deva_get("store.subscription.dunning_phase"))?.toString() ?? "";
                                    if (phase.isEmpty) {
                                        await _applyDunning(false, "");
                                        return;
                                    }

                                    // Contexte de clan absent (onboarding, entre deux clans) → _storeCanBuy
                                    // rend false : personne à prévenir, et rien à lire.
                                    if (!await _storeCanBuy()) {
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
    // première cotisation d'un clan qui a fait la preuve qu'il joue ET qui a épuisé ses
    // reports — c'est le mur, et il ne s'adresse qu'aux chefs (cf. _storePitchDue). Un
    // enfant n'y arrive jamais.
    //
    // `pitch` dit que la venue est une DEMANDE DE PREMIÈRE COTISATION, seul motif qui
    // donne droit au bouton « Plus tard ». Publié comme le reste plutôt que déduit du
    // jeton de bandeau : un texte n'est pas un état, et le jour où le bandeau change de
    // formulation, une inférence sur son nom se tairait sans rien dire.
    //
    // `oneMore` dit s'il faut viser une place de PLUS que l'effectif ou l'effectif tel
    // quel. Publié, jamais déduit : cf. _tiersOfferTier.
    Future<void> _storeGotoTiers({

        String notice   = "",
        bool   oneMore  = false,
        bool   blocking = false,
        bool   pitch    = false,
    }) async {

                                await deva_set("worker.store.notice",   notice);
                                await deva_set("worker.store.one_more", oneMore);
                                await deva_set("worker.store.pitch",    pitch);

                                // Chaque venue repart du palier par défaut pour sa raison, et de
                                // l'ANNUEL présélectionné : c'est la carte qu'on met en avant.
                                _storeOfferTier = "";
                                _storePeriod    = "yearly";

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
                                        if (p.get_shape_by_id("tiers_page/cta") != null) { onPage = true; break; }
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
    Future<void> _storeLeaveAfterPurchase() async {

                                // L'attente de l'achat prend fin, quelle que soit la sortie : dégeler
                                // AVANT de naviguer, sinon la page gelée partirait gelée.
                                _storeBuyWaitStop();

                                // LA VALIDATION MISE DE CÔTÉ D'ABORD, avant toute navigation : le clan
                                // vient de payer, la tâche qu'il rendait au moment où on l'a arrêté lui
                                // est due. Le rejeu ramène au tiroir, sur la victoire — un `navigate_reset`
                                // vers le dashboard joué avant lui l'aurait écrasée.
                                //
                                // ⚠ UN REJEU PEUT NE RIEN NAVIGUER. `on_combat_ok` sort sans un mot s'il
                                //   ne retrouve plus la tâche en cours (tâche active effacée entre-temps,
                                //   app relancée) : le rejeu se disait pourtant maître de la navigation,
                                //   et l'écran des paliers restait affiché APRÈS un achat réussi (relevé
                                //   au simulateur de store, 2026-09-30). Toujours sur les paliers après
                                //   le rejeu = rien n'a navigué : on rouvre le donjon.
                                if (await _storeReplayPendingVerdict()) {
                                    if (DvOrb.get_current_page()?.dvid != "tiers_page") return;
                                    deva_log("info", "[store] rejeu sans navigation : donjon rouvert");
                                    DvOrb.navigate_reset("dashboard");
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
                                // qui l'attend — cotisation, arrêt quand il veut ; « le clan est au
                                // complet » se lirait comme un refus alors que c'est une proposition.
                                // À tous les autres — abonné qui déborde, résilié, expiré, gelé — on dit
                                // le plafond, parce qu'ils savent déjà ce qu'est la cotisation et qu'on
                                // ne leur présente pas le modèle une seconde fois.
                                //
                                // AUCUN des deux ne promet plus de jours offerts : il n'y a plus d'essai
                                // calendaire au catalogue (2026-09-16), l'accès libre du début a pris sa
                                // place et il est derrière eux — un clan qui bute sur le plafond a déjà
                                // joué. Promettre ici ce que la feuille de paiement dément serait pire
                                // que ne rien promettre du tout.
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
                                // PLUS. Cette intention était autrefois devinée par la page des paliers à
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
    // qui vaille est celui où le jeu a fait sa preuve : une tâche menée à son terme.
    //
    // IL N'Y A PLUS D'ESSAI CALENDAIRE (2026-09-16 : l'offre Play `essai-14j` est
    // retirée du catalogue). L'accès libre du début EST la générosité du modèle, et
    // il se mesure en USAGE : une famille qui installe l'app un samedi et n'y revient
    // que le week-end suivant n'a rien consommé, là où quatorze jours calendaires lui
    // auraient tout mangé sans qu'elle ait joué.
    //
    // DEUX SEUILS, parce qu'il y a deux populations (cf. store-base-global.yml) :
    //   - clan CONSTITUÉ  → `after_growth` validations à partir de l'ANCRE, c'est-à-dire
    //     de l'instant où le clan a cessé d'être seul. Trois validations vécues À
    //     PLUSIEURS, et pas trois validations tout court : un fondateur qui a préparé
    //     le terrain seul n'a encore rien vu du jeu qu'on lui vend ;
    //   - clan resté SEUL → `solo` validations, bien plus haut. Il n'est plus exempté
    //     comme avant : un clan d'un joueur qui joue six mois coûte de l'infrastructure
    //     sans jamais rencontrer une seule porte.
    //
    // ET UNE DOCTRINE, qui tient en une phrase : ON FAIT CRÉDIT À QUI A DÉJÀ PAYÉ,
    // ON NE FAIT PAS CRÉDIT À QUI N'A JAMAIS PAYÉ. Le calendrier de défaut de paiement
    // (grâce, relances, gel au 50e jour) reste réservé aux clans qui ont cotisé, où
    // l'échec est presque toujours technique — carte expirée, découvert passager — et
    // où la famille a un historique à perdre. Un clan qui n'a jamais souscrit a droit
    // à un nombre PETIT et ANNONCÉ de reports (`defers`), puis l'écran devient une
    // racine de pile. Le laisser refuser indéfiniment enseignerait que payer est
    // facultatif, puis fermerait le donjon deux mois plus tard sur une famille
    // installée : ni convertie, ni ménagée, et la pire des deux issues au moment où
    // la relation valait le plus.
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

    // Un réglage entier de la relance, lu au BUCKET comme le catalogue, les scénarios
    // du banc et la cadence de la fée : décaler le moment de la conversion ne doit pas
    // demander une version sur les stores. Le repli n'est pas décoratif — un layer qui
    // n'est pas descendu ne doit jamais rendre un seuil de 0, qui murerait le clan à la
    // première tâche.
    Future<int> _storePitchConf(String key, int fallback) async {

                                final raw = await deva_get("store.pitch.$key");
                                if (raw is num) return raw.toInt();
                                return int.tryParse(raw?.toString() ?? "") ?? fallback;
    }

    // Le mur est-il dû ? État DÉRIVÉ, recalculé depuis des faits persistants — patron
    // _evaluateDunning, et surtout pas un drapeau one-shot. Conséquence directe : il
    // survit au changement d'appareil comme à une réinstallation, et il vaut pour les
    // deux chefs d'un clan sans qu'il y ait rien à synchroniser ni à purger. Un drapeau
    // local n'aurait tenu que sur l'appareil qui l'a armé.
    //
    // `pending` dit qu'une validation est EN COURS et qu'elle compte. C'est tout l'écart
    // entre les deux appelants : la porte se ferme AVANT la validation qui atteint le
    // seuil (la famille ne reçoit pas le fruit de la tâche qu'elle vient de rendre, elle
    // le recevra dès qu'elle aura souscrit), tandis que le dashboard, lui, ne rouvre
    // rien tant que la porte n'a pas déjà été armée.
    //
    // QUATRE conditions, et la deuxième est celle qui protège les enfants.
    Future<bool> _storePitchDue({bool pending = false}) async {

                                try {
                                    if (await _storeSubscribed()) return false;

                                    // CHEFS SEULEMENT. Un enfant ne peut pas payer (l'achat est réservé
                                    // aux administrateurs, derrière le contrôle parental) : lui fermer le
                                    // jeu ne servirait à rien qu'à l'inquiéter. Couvre au passage la prise
                                    // de place (take_place), qui change l'identité agissante.
                                    if (!await _storeCanBuy()) return false;

                                    final ctx = await _butinCtx();
                                    if (ctx == null) return false;
                                    final clanId     = ctx.get("clanId").toString();
                                    final clanSecret = ctx.get("clanSecret").toString();
                                    final region     = ctx.get("region").toString();
                                    if (clanId.isEmpty || clanSecret.isEmpty) return false;

                                    final doc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final n       = int.tryParse(doc?.get("validations")?.toString() ?? "0") ?? 0;
                                    final defers  = int.tryParse(doc?.get("pitch_defers")?.toString() ?? "0") ?? 0;
                                    final armedAt = doc?.get("pitch_due_since")?.toString() ?? "";

                                    _pitchDefersLeft = (await _storePitchConf("defers", 3)) - defers;
                                    if (_pitchDefersLeft < 0) _pitchDefersLeft = 0;

                                    // DÉJÀ ARMÉ. La porte a été présentée une première fois : elle reste
                                    // due jusqu'à souscription, où qu'on la rencontre et quel que soit
                                    // l'appareil. C'est ce champ, et non un seuil recalculé, qui permet à
                                    // l'écran de se présenter « au premier chef qui se connecte » — le
                                    // second chef n'a rien validé, il n'en tomberait sur rien sans cela.
                                    if (armedAt.isNotEmpty) return true;

                                    // CLAN ENCORE SEUL : seuil bien plus haut, et non plus une exemption.
                                    // Un fondateur teste volontiers quelques tâches en attendant que sa
                                    // famille installe le jeu, et il s'auto-valide sans preuve : lui
                                    // présenter la note à trois validations la présenterait avant que le
                                    // clan existe vraiment, un écran de paiement en face d'un roster d'une
                                    // tuile. Mais l'exempter tout court, comme avant, laissait un clan d'un
                                    // seul joueur jouer indéfiniment sans jamais rencontrer de porte.
                                    //
                                    // Drapeau local (_setClanAlone) et pas une requête : ABSENT = on ne
                                    // sait pas = on prend le cas du clan constitué, qui est le cas normal.
                                    var alone = (await deva_get("worker.clan_alone"))?.toString() == "true";

                                    // L'ANCRE : le compteur tel qu'il était quand le clan a cessé d'être
                                    // seul. Sans elle, les validations de la phase de préparation
                                    // compteraient comme des validations de jeu en famille, et un fondateur
                                    // qui a déjà rendu neuf tâches verrait la note à la seconde même où sa
                                    // famille le rejoint — le plus mauvais moment du parcours.
                                    //
                                    // ABSENTE sur un clan constitué : on la pose MAINTENANT, à la valeur
                                    // courante. C'est le cas des clans nés avant ce champ, et l'arbitrage
                                    // est le même que partout ici — se tromper en repoussant coûte trois
                                    // validations, se tromper en avançant mure une famille pour un champ
                                    // manquant.
                                    final anchorRaw = doc?.get("validations_anchor")?.toString() ?? "";
                                    var   anchor    = int.tryParse(anchorRaw);

                                    // UN CLAN QUI A ÉTÉ CONSTITUÉ LE RESTE, pour cette demande. L'ancre
                                    // existe : le seuil est celui du clan constitué, même si le roster
                                    // est momentanément retombé à une tuile. Sans cela, retirer un
                                    // membre repousserait la demande de trois à dix validations, et le
                                    // seuil le plus généreux s'obtiendrait en défaisant son clan.
                                    if (anchor != null) alone = false;

                                    if (!alone && anchor == null) {
                                        anchor = n;
                                        await _storeWriteClanField(clanId, clanSecret, region,
                                                                   "validations_anchor", "$n");
                                        deva_log("info", "[store] ancre de conversion posée a posteriori : $n");
                                    }

                                    final counted = pending ? n + 1 : n;
                                    final due     = alone
                                        ? counted >= await _storePitchConf("solo", 10)
                                        : counted >= (anchor ?? 0) + await _storePitchConf("after_growth", 3);
                                    if (!due) return false;

                                    // ARMEMENT, à la première fois seulement : c'est la date qui fait foi
                                    // ensuite, pour les deux chefs et pour tous leurs appareils.
                                    await _storeWriteClanField(clanId, clanSecret, region,
                                        "pitch_due_since", DateTime.now().toUtc().toIso8601String());
                                    deva_log("info", "[store] première cotisation due (validations=$counted, "
                                                     "seul=$alone, ancre=${anchor ?? "-"})");
                                    return true;
                                } catch (e) {
                                    // Un mur qu'on n'arrive pas à évaluer ne ferme rien : le prochain
                                    // passage réessaiera. Se tromper dans ce sens coûte une session ;
                                    // se tromper dans l'autre enferme une famille à jour.
                                    deva_log("error", "[store] _storePitchDue FAILED: $e");
                                    return false;
                                }
    }

    // Écriture d'UN champ du doc de clan, en deep-merge ciblé (un Dvidle neuf ne
    // portant que lui). Surtout pas le read-modify-write du document complet : on ne
    // réécrit pas l'XP, le butin et le titre d'un clan pour poser un entier.
    //
    // Ces champs sont FALSIFIABLES — la règle Firestore de `clans` autorise tout
    // détenteur du clanSecret à écrire n'importe quoi. Sans gravité, et c'est
    // volontaire : les fausser ne peut qu'AVANCER la demande de cotisation (ancre plus
    // basse, reports déjà consommés), jamais la retarder ni accorder un droit. Le seul
    // qui pourrait l'être dans l'autre sens, `pitch_defers`, ne donne rien de plus que
    // trois écrans refusés de plus.
    Future<void> _storeWriteClanField(String clanId, String clanSecret, String region,
                                      String field, String value) async {

                                try {
                                    final out = Dvidle({});
                                    out.set(field, value);
                                    await _cloud?.write("workers", "clans", clanId, out,
                                        region: region, ownerId: clanSecret);
                                } catch (e) {
                                    deva_log("error", "[store] écriture clans.$field FAILED: $e");
                                }
    }

    // L'ANCRE DE CONVERSION, posée à l'instant où le clan cesse d'être seul — le seul
    // instant où l'on sait que les validations qui suivront seront vécues à plusieurs.
    //
    // Idempotente par le champ lui-même : un clan qui grandit, rétrécit et regrandit
    // garde sa PREMIÈRE ancre. Sinon un chef qui retire puis réadmet un membre
    // repousserait la demande de trois validations à chaque fois, et la porte
    // deviendrait une porte qu'on peut faire reculer indéfiniment.
    //
    // Appelée depuis _setClanAlone, qui est le seul endroit du worker à connaître la
    // transition. Silencieuse en cas d'échec : au pire l'ancre sera posée plus tard par
    // _storePitchDue, à une valeur plus haute — dans le sens généreux, comme le reste.
    Future<void> _storeAnchorGrowth() async {

                                try {
                                    if (await _storeSubscribed()) return;   // rien à relancer, rien à ancrer
                                    final ctx = await _butinCtx();
                                    if (ctx == null) return;
                                    final clanId     = ctx.get("clanId").toString();
                                    final clanSecret = ctx.get("clanSecret").toString();
                                    final region     = ctx.get("region").toString();
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    final doc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    if ((doc?.get("validations_anchor")?.toString() ?? "").isNotEmpty) return;

                                    final n = int.tryParse(doc?.get("validations")?.toString() ?? "0") ?? 0;
                                    await _storeWriteClanField(clanId, clanSecret, region,
                                                               "validations_anchor", "$n");
                                    deva_log("info", "[store] ancre de conversion : $n validation(s) avant la famille");
                                } catch (e) {
                                    deva_log("error", "[store] _storeAnchorGrowth FAILED: $e");
                                }
    }

    // UN REPORT SE CONSOMME À LA PRÉSENTATION, pas au geste de refus — et c'est le
    // point qui décide si le dispositif tient ou non.
    //
    // Compter le refus aurait paru plus juste, mais il y a deux façons de refuser :
    // le bouton « Plus tard » et la flèche arrière. Ne compter que la première, c'est
    // offrir des reports illimités à qui utilise la seconde ; compter les deux
    // suppose de savoir distinguer un départ d'un simple aller-retour, ce qu'aucune
    // pile de navigation ne dit proprement. La présentation, elle, est un fait unique
    // et observable.
    //
    // AU PLUS UN PAR SESSION (_pitchShown). Sans ce garde-fou, trois retours au
    // dashboard dans la même soirée useraient les trois reports en dix minutes, et
    // l'écran deviendrait un mur par accident plutôt que par décision. Une session,
    // un report : la famille est sollicitée une fois par ouverture du jeu, jamais
    // deux.
    //
    // Le compteur est persisté sur le CLAN : il ne se remet pas à zéro en changeant
    // d'appareil, en réinstallant, ni en passant à l'autre chef. Le garde-fou de
    // session vit dans worker.dart (_pitchShown).

    Future<void> _storePitchConsume() async {

                                if (_pitchShown) return;
                                _pitchShown = true;

                                try {
                                    final ctx = await _butinCtx();
                                    if (ctx == null) return;
                                    final clanId     = ctx.get("clanId").toString();
                                    final clanSecret = ctx.get("clanSecret").toString();
                                    final region     = ctx.get("region").toString();
                                    if (clanId.isEmpty || clanSecret.isEmpty) return;

                                    final doc = await _cloud?.read("workers", "clans", clanId,
                                        ownerId: clanSecret, region: region);
                                    final n = int.tryParse(doc?.get("pitch_defers")?.toString() ?? "0") ?? 0;
                                    await _storeWriteClanField(clanId, clanSecret, region,
                                                               "pitch_defers", "${n + 1}");
                                    _pitchDefersLeft = (await _storePitchConf("defers", 3)) - (n + 1);
                                    if (_pitchDefersLeft < 0) _pitchDefersLeft = 0;
                                    deva_log("info", "[store] cotisation présentée — "
                                                     "$_pitchDefersLeft report(s) restant(s)");
                                } catch (e) {
                                    // Un report qu'on n'arrive pas à compter est un report offert. Se
                                    // tromper dans ce sens coûte une présentation de plus ; dans l'autre,
                                    // on murerait une famille sur une écriture ratée.
                                    deva_log("error", "[store] _storePitchConsume FAILED: $e");
                                }
    }

    // « Plus tard ». Ne compte rien (c'est déjà fait, cf. ci-dessus) : il DIT que
    // partir est permis, et combien de fois encore. Un écran de paiement sans geste
    // de sortie visible se lit comme un mur, même quand il n'en est pas un.
    //
    // Le verdict mis de côté est oublié : la tâche reste en attente de validation, ce
    // qui est exactement la pression qu'on veut — elle s'exerce sur l'adulte qui peut
    // payer, et l'enfant ne voit aucun écran de paiement.
    Future<void> tiers_defer(dynamic caller, dynamic event) async {

                                _pendingVerdict = null;
                                deva_log("info", "[store] cotisation reportée par le chef");
                                DvOrb.navigate_reset("dashboard");
    }

    // La porte se ferme-t-elle SUR CETTE VALIDATION ? Appelée avant que quoi que ce
    // soit ne soit écrit — la famille ne reçoit pas le fruit de la tâche qu'elle vient
    // de rendre, elle le recevra intégralement dès qu'elle aura souscrit.
    //
    // Un verdict REFUSÉ ne passe jamais par ici : il ne compte pas au compteur, il ne
    // prouve pas que le jeu tourne, et demander sa cotisation à une famille au moment
    // précis où elle refuse un travail serait le pire enchaînement possible.
    //
    // `replay` porte de quoi rejouer l'acte après l'achat, et rien d'autre — les
    // identifiants du clan seront relus à ce moment-là, ils peuvent avoir changé.
    // Le rejeu est protégé par _pitchSuspended (worker.dart).

    Future<bool> _storePitchIntercept(Map<String, String> replay) async {

                                if (_pitchSuspended) return false;
                                if (!await _storePitchDue(pending: true)) return false;

                                final blocking = _pitchDefersLeft <= 0;

                                // DÉJÀ PRÉSENTÉE CETTE SESSION, et il reste des reports : on laisse
                                // passer. La famille a déjà vu l'écran il y a quelques minutes et a
                                // choisi de continuer à jouer ; le lui remettre à chaque tâche validée
                                // serait du harcèlement, et userait un dispositif qui ne vaut que par sa
                                // rareté. On la rappellera à la prochaine ouverture du jeu.
                                if (!blocking && _pitchShown) return false;

                                if (!blocking) await _storePitchConsume();

                                _pendingVerdict = replay;
                                deva_log("info", "[store] validation interceptée — première cotisation "
                                                 "(${blocking ? "sans report restant" : "$_pitchDefersLeft report(s) après celui-ci"})");
                                await _storeGotoTiers(notice: "@@@T:store_pitch_first@@@",
                                                      blocking: blocking, pitch: true);
                                return true;
    }

    // Rejoue l'acte mis de côté. Rend true s'il a pris la main sur la navigation : le
    // rejeu ramène lui-même au bon écran (le tiroir, où la tâche vient d'être vaincue),
    // ce qui vaut mieux que le dashboard — la famille a payé, elle doit voir sa
    // victoire, pas un écran d'accueil.
    Future<bool> _storeReplayPendingVerdict() async {

                                final replay = _pendingVerdict;
                                if (replay == null) return false;
                                _pendingVerdict = null;

                                _pitchSuspended = true;
                                try {
                                    deva_log("info", "[store] cotisation prise — validation rejouée (${replay["kind"]})");
                                    if (replay["kind"] == "combat_ok") {
                                        await on_combat_ok(null, null);
                                        return true;
                                    }
                                    await _handleVerdict(replay["verdict"] ?? "ok");
                                    return true;
                                } catch (e) {
                                    // Le rejeu a échoué : la tâche reste en attente de validation, et
                                    // l'admin la rendra d'un tap. On ne perd rien d'autre qu'un geste —
                                    // surtout pas l'achat, qui est acquis chez Play.
                                    deva_log("error", "[store] _storeReplayPendingVerdict FAILED: $e");
                                    return false;
                                } finally {
                                    _pitchSuspended = false;
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
    Future<List<String>> shop_settings_selector(dynamic caller, dynamic data) async {

                                // ⚠ LES TUTORIELS DANS TOUS LES KEBABS, celui-ci compris. C'est la
                                //   seule option qui reponde a « je ne sais pas quoi faire » : la
                                //   reserver a deux ecrans sur trois oblige a se souvenir DUQUEL,
                                //   ce que personne ne fait. Posee en tete, avant meme la
                                //   restauration des achats, parce qu'un joueur perdu dans la
                                //   boutique cherche a comprendre avant d'acheter.
                                final options = <String>["tutorials", "store_restore"];
                                try {
                                    // Une cotisation EN COURS, et pas seulement un nom de palier : la
                                    // projection le garde après l'expiration, « Gérer » y renverrait
                                    // vers un abonnement qui n'existe plus.
                                    final canBuy  = await _storeCanBuy();
                                    if (await _storeSubscribed() && canBuy) options.add("store_manage");
                                    // Saisir un code : sous la même garde que l'achat, et pour la même
                                    // raison — c'est le clan qu'on engage. Proposée abonné ou non : un
                                    // crédit réclamé pendant une cotisation payante n'est pas perdu,
                                    // il attend simplement son tour.
                                    if (canBuy) options.add("store_code");
                                } catch (e) {
                                    // Lecture KO → repli sûr : seules les deux options inoffensives
                                    // restent. Un kebab amputé vaut mieux qu'un écran qui ne s'ouvre pas.
                                    deva_log("error", "[store] shop_settings_selector FAILED: $e");
                                }
                                return options;
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
    // Et TARIF COURANT, sans aucune offre (`offer: ""`). Il n'y a plus d'essai au
    // catalogue depuis le 2026-09-16, mais l'offre FONDATEURS, elle, existe toujours :
    // la laisser s'appliquer ici offrirait un mois à chaque clan gelé qui revient, ce
    // qui récompenserait exactement le comportement qu'on cherche à éviter.
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

                                // MENSUEL, explicitement : la page des paliers présélectionne
                                // désormais l'annuel (_storeGotoTiers), et ce bouton sans écran de
                                // choix ne doit pas hériter d'une présélection qu'on ne voit pas ici.
                                deva_log("info", "[store] se réabonner → $tier (mensuel, tarif courant, sans offre)");
                                _storeBuyWaitStart();
                                await _store?.buy(tier, period: "monthly", offer: "");
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
    // --- Page des paliers (refonte 2026-09-30 : un choix, pas un tableau)
    //
    // Le seul écran d'où l'on souscrit ou change de cotisation. Il ne se parcourt
    // pas : une raison commerciale l'ouvre (plafond atteint, relance d'impayé,
    // réabonnement, première cotisation), et il y répond.
    //
    // L'app connaît l'effectif du clan, donc le palier qui lui convient : la page ne
    // fait plus comparer cinq lignes, elle présente CE palier et pose une seule
    // question, à l'année ou au mois. Le palier se change à part (tiers_pick_page).
    //
    // Il n'invente RIEN. Paliers, plafonds et ordre viennent du catalogue (layer
    // cloud) ; prix, économie et référence de Play (dvstore) ; textes du thème.
    // -----------------------------------------------------------------------

    Future<void> on_tiers_appear(dynamic caller, dynamic event) async {

                                // CHAQUE PARTIE À PART, et chacune journalise son échec : une lecture
                                // ratée sur les visages ne doit pas laisser les cartes sans prix.
                                Future<void> part(String what, Future<void> Function() paint) async {
                                    try {
                                        await paint();
                                    } catch (e, st) {
                                        deva_log("error", "[store] paliers : $what FAILED: $e\n$st");
                                    }
                                }

                                var tier = "";
                                await part("palier", () async { tier = await _tiersOfferTier(); });
                                deva_log("info", "[store] paliers : vitrine '$tier' ($_storePeriod)");
                                await part("visages", _tiersPaintFaces);
                                await part("raison",  _tiersPaintNotice);
                                await part("cartes",  () => _tiersPaintCards(tier));
                                await part("formule", () => _tiersPaintFormula(tier));
                                await part("report",  _tiersSyncDefer);
    }

    // LE PALIER PRÉSENTÉ. Celui choisi sur tiers_pick_page s'il y en a un ; sinon
    // celui qui résout la raison de la venue (_storeNextTier : une place de plus sur
    // un refus de plafond, l'effectif tel quel sinon) ; sinon le palier en cours ;
    // sinon le moins cher qui accueille tout le clan.
    Future<String> _tiersOfferTier() async {

                                final tiers = await _storeTiers();
                                if (_storeOfferTier.isNotEmpty && tiers.contains(_storeOfferTier)) return _storeOfferTier;
                                return await _tiersDefaultTier();
    }

    // LE PALIER PRÉSENTÉ PAR DÉFAUT : le plus juste pour la raison de la venue (une
    // place de plus sur un refus de plafond, l'effectif tel quel sinon). Ce n'est PAS
    // un conseil et rien ne l'affiche comme tel : on ne connaît ni la famille ni la
    // taille de clan qui lui convient (décision du 2026-10-01). C'est seulement le
    // point de départ de la vitrine, que la famille change d'un tap.
    Future<String> _tiersDefaultTier() async {

                                final current = await _storeSubscribed()
                                    ? ((await deva_get("store.subscription.product"))?.toString() ?? "")
                                    : "";
                                final count   = await _storePlayerCount();
                                final oneMore = (await deva_get("worker.store.one_more")) == true;
                                final next    = await _storeNextTier(current: current, count: count, oneMore: oneMore);
                                if (next.isNotEmpty) return next;
                                if (current.isNotEmpty) return current;
                                return await _storeTierForCount(count);
    }

    // LES VISAGES DU CLAN, et « Les Lapins Blancs · 5 aventuriers ». On paie pour
    // eux : c'est la première chose que la page montre. Six places au plus, qui se
    // chevauchent et se recentrent ; au-delà, le compte exact est dans la ligne.
    // Une lecture ratée masque la rangée plutôt que de montrer un clan faux.
    Future<void> _tiersPaintFaces() async {

                                final faces = <String>[];
                                var name = "";
                                var count = -1;
                                try {
                                    final ctx = await _butinCtx();
                                    if (ctx == null) deva_log("warning", "[store] paliers : aucun clan en contexte, visages masqués");
                                    if (ctx != null) {
                                        final clanId     = ctx.get("clanId").toString();
                                        final clanSecret = ctx.get("clanSecret").toString();
                                        final region     = ctx.get("region").toString();
                                        final clan = await _cloud?.read("workers", "clans", clanId,
                                            ownerId: clanSecret, region: region);
                                        // Le nom vit dans la SESSION (dvsession le pose au login) ;
                                        // le document du clan n'est qu'un repli.
                                        name = (await deva_get("session.clan.name"))?.toString() ?? "";
                                        if (name.isEmpty) name = clan?.get("name")?.toString() ?? "";
                                        final players = await _cloud?.list(
                                            "workers", "clans_players/$clanId/players", region: region) ?? [];
                                        count = 0;
                                        for (final p in players) {
                                            if (p.get("enabled") == false) continue;
                                            count++;
                                            final a = p.get("avatar")?.toString() ?? "";
                                            faces.add(a.isNotEmpty ? a : _defaultPlayerAvatar);
                                        }
                                    }
                                } catch (e) {
                                    deva_log("error", "[store] paliers : clan illisible ($e)");
                                }

                                const slots = 6;
                                const step  = 8.0;     // chevauchement : une moitié de visage
                                const width = 16.0;
                                final n     = faces.length < slots ? faces.length : slots;
                                final start = 50.0 - (width + step * (n - 1)) / 2;
                                for (var i = 0; i < slots; i++) {
                                    final id = "tiers_page/av${i + 1}";
                                    final av = await DvOrb.wait_for_shape(id);
                                    if (i < n) {
                                        await _syncGeom(av, id, "shape.x", "${(start + step * i).toStringAsFixed(2)}%");
                                        await _tiersSetImage(av, id, faces[i]);
                                    }
                                    await _syncVisible(av, id, i < n);
                                }

                                final line = await DvOrb.wait_for_shape("tiers_page/clan");
                                final who  = count < 0 ? "" : TranslationRegistry.processLabel(count == 1
                                                 ? "@@@T:tiers_adventurer@@@" : "@@@T:tiers_adventurers@@@")
                                                 .replaceAll("{n}", "$count");
                                await _syncLabel(line, "tiers_page/clan",
                                    [name, who].where((s) => s.isNotEmpty).join("  ·  "));
    }

    Future<void> _tiersSetImage(dynamic shape, String id, String path) async {

                                if (shape == null || shape.get("shape.image")?.toString() == path) return;
                                shape.set("shape.image", path);
                                await deva_set("registry.$id.shape.image", path);
                                try { await shape.appear(); } catch (e) { deva_log("warning", "[store] visage $id : $e"); }
                                shape.refreshUI();
    }

    // LA LIGNE SOUS LE TITRE : la RAISON de la venue s'il y en a une (plafond atteint,
    // relance…), sinon une descente en attente, sinon la phrase par défaut. Jamais
    // vide : un blanc sous un titre se lit comme un écran inachevé.
    Future<void> _tiersPaintNotice() async {

                                final notice = (await deva_get("worker.store.notice"))?.toString() ?? "";
                                final banner = await DvOrb.wait_for_shape("tiers_page/notice");
                                var text = "";
                                if (notice.isNotEmpty) {
                                    // {n} = le plafond courant : le texte ne chiffre jamais la grille.
                                    text = TranslationRegistry.processLabel(notice);
                                    final cap = await _storeMaxPlayers();
                                    if (cap >= 0) text = text.replaceAll("{n}", "$cap");
                                } else {
                                    text = await _tiersPendingText();
                                }
                                if (text.isEmpty) text = TranslationRegistry.processLabel("@@@T:tiers_subline@@@");
                                await _syncLabel(banner, "tiers_page/notice", text);
                                await _syncVisible(banner, "tiers_page/notice", true);
    }

    // LES DEUX CARTES ET LE BOUTON.
    //
    // L'annuelle garde son cadre doré (c'est le meilleur prix, choisie ou non) ; la
    // sélection se lit à la pastille et à l'épaisseur du trait. Le montant barré et
    // l'économie ne paraissent que si dvstore les a calculés depuis les prix Play :
    // on n'affiche jamais un chiffre de vente qu'on n'a pas.
    Future<void> _tiersPaintCards(String tier) async {

                                String t(String key) => TranslationRegistry.processLabel("@@@T:$key@@@");

                                final yearPlan  = await _tiersPlanFor(tier, "yearly");
                                final monthPlan = await _tiersPlanFor(tier, "monthly");
                                final yearPrice  = await _tiersPriceFor(tier, yearPlan, "yearly");
                                final monthPrice = await _tiersPriceFor(tier, monthPlan, "monthly");
                                deva_log("info", "[store] paliers : $tier an=$yearPlan '$yearPrice' "
                                    "mois=$monthPlan '$monthPrice' économie='${await deva_get("store.catalog.$tier.yearly_savings")}'");

                                // Un palier sans annuel (ou sans prix connu pour lui) : la carte
                                // dorée disparaît, et la mensuelle est d'office la bonne.
                                final hasYear = yearPrice.isNotEmpty;
                                if (!hasYear) _storePeriod = "monthly";
                                final yearOn  = _storePeriod == "yearly";

                                for (final id in const ["year_card", "year_ribbon", "year_name", "year_radio", "year_price"]) {
                                    final s = await DvOrb.wait_for_shape("tiers_page/$id");
                                    await _syncVisible(s, "tiers_page/$id", hasYear);
                                }

                                final yPrice = await DvOrb.wait_for_shape("tiers_page/year_price");
                                await _syncLabel(yPrice, "tiers_page/year_price", "$yearPrice ${t("tiers_per_year")}");

                                final savings   = (await deva_get("store.catalog.$tier.yearly_savings"))?.toString()   ?? "";
                                final reference = (await deva_get("store.catalog.$tier.yearly_reference"))?.toString() ?? "";
                                final showSave  = hasYear && savings.isNotEmpty && reference.isNotEmpty;
                                final old  = await DvOrb.wait_for_shape("tiers_page/year_old");
                                final save = await DvOrb.wait_for_shape("tiers_page/year_save");
                                if (showSave) {
                                    await _syncLabel(old,  "tiers_page/year_old",  reference);
                                    await _syncLabel(save, "tiers_page/year_save",
                                        t("tiers_saved").replaceAll("{amount}", savings));
                                }
                                await _syncVisible(old,  "tiers_page/year_old",  showSave);
                                await _syncVisible(save, "tiers_page/year_save", showSave);

                                final mPrice = await DvOrb.wait_for_shape("tiers_page/month_price");
                                await _syncLabel(mPrice, "tiers_page/month_price", "$monthPrice ${t("tiers_per_month")}");

                                // Sélection : pastille pleine et cochée, trait appuyé.
                                const gold  = "0xFFD6A84A";
                                const clear = "0x00000000";
                                final yRadio = await DvOrb.wait_for_shape("tiers_page/year_radio");
                                final mRadio = await DvOrb.wait_for_shape("tiers_page/month_radio");
                                await _syncLabel(yRadio, "tiers_page/year_radio",  yearOn ? "✓" : "");
                                await _syncLabel(mRadio, "tiers_page/month_radio", yearOn ? "" : "✓");
                                await _syncGeom(yRadio, "tiers_page/year_radio",  "shape.background_color", yearOn ? gold : clear);
                                await _syncGeom(mRadio, "tiers_page/month_radio", "shape.background_color", yearOn ? clear : gold);
                                await _syncGeom(mRadio, "tiers_page/month_radio", "shape.border_color", yearOn ? "0x59FFFFFF" : gold);

                                final yCard = await DvOrb.wait_for_shape("tiers_page/year_card");
                                final mCard = await DvOrb.wait_for_shape("tiers_page/month_card");
                                await _syncGeom(yCard, "tiers_page/year_card",  "shape.border_size",  yearOn ? "3.0" : "1.5");
                                await _syncGeom(mCard, "tiers_page/month_card", "shape.border_size",  yearOn ? "1.5" : "3.0");
                                await _syncGeom(mCard, "tiers_page/month_card", "shape.border_color", yearOn ? "0x33FFFFFF" : gold);

                                // LE BOUTON : « Continuer », sauf si la carte choisie est très
                                // exactement l'abonnement en cours, qu'on ne rachète pas.
                                final owned = await _tiersIsOwned(tier, yearOn ? yearPlan : monthPlan);
                                final cta   = await DvOrb.wait_for_shape("tiers_page/cta");
                                await _syncLabel(cta, "tiers_page/cta", t(owned ? "tiers_current_plan" : "tiers_continue"));
                                await _syncGeom(cta, "tiers_page/cta", "shape.opacity", owned ? "0.45" : "1.0");
    }

    // Vrai si (palier, base plan) est l'abonnement en cours, tel quel.
    Future<bool> _tiersIsOwned(String tier, String plan) async {

                                if (!await _storeSubscribed()) return false;
                                final product = (await deva_get("store.subscription.product"))?.toString() ?? "";
                                final current = (await deva_get("store.subscription.base_plan"))?.toString() ?? "";
                                return product == tier && (current.isEmpty || current == plan);
    }

    // « Formule Tribu · jusqu'à 7 joueurs · changer ». Le lien ouvre le choix du palier.
    Future<void> _tiersPaintFormula(String tier) async {

                                var name = (await deva_get("store.catalog.$tier.label"))?.toString() ?? "";
                                if (name.isEmpty) name = tier;
                                final cap   = await _storeTierCapacity(tier);
                                var seats = TranslationRegistry.processLabel(cap < 0
                                    ? "@@@T:tiers_unlimited@@@" : "@@@T:tiers_upto@@@").replaceAll("{n}", "$cap");
                                if (seats.isNotEmpty) seats = seats[0].toLowerCase() + seats.substring(1);
                                final head   = TranslationRegistry.processLabel("@@@T:tiers_formula@@@")
                                    .replaceAll("{tier}", "[[${TranslationRegistry.processLabel(name)}]]");
                                final change = TranslationRegistry.processLabel("@@@T:tiers_change@@@");
                                final line   = await DvOrb.wait_for_shape("tiers_page/formula");
                                await _syncLabel(line, "tiers_page/formula",
                                    "$head  ·  $seats  ·  (($change|worker.tiers_open_pick))");
    }

    // Base plan déclaré au catalogue pour une périodicité (le SUFFIXE est contractuel).
    Future<String> _tiersPlanFor(String productId, String period) async {

                                final plans = await deva_get("store.catalog.$productId.plans");
                                if (plans is! Dvidle) return "";
                                for (final id in plans.keys) {
                                    if (id.endsWith("-$period")) return id;
                                }
                                return "";
    }

    // Prix d'un palier POUR UNE PÉRIODICITÉ : celui du base plan (Play s'il est là,
    // sinon le repli de la bonne périodicité, que dvstore choisit), puis le repli du
    // catalogue lu en direct, puis RIEN. Jamais le prix de l'autre périodicité : une
    // page de tarifs qui ment est pire qu'une page de tarifs vide.
    Future<String> _tiersPriceFor(String productId, String plan, String period) async {

                                if (plan.isNotEmpty) {
                                    final live = (await deva_get("store.catalog.$productId.plans.$plan.price"))?.toString() ?? "";
                                    if (live.isNotEmpty) return live;
                                }
                                final key = period == "yearly" ? "price_hint_yearly" : "price_hint";
                                return (await deva_get("store.catalog.$productId.$key"))?.toString() ?? "";
    }

    // LE BOUTON « PLUS TARD », et le décompte qui va avec.
    //
    // Il n'apparaît que sur une venue de première cotisation (`worker.store.pitch`) et
    // tant qu'il reste des reports. Partout ailleurs, la page a déjà une sortie (sa
    // flèche), et un second bouton pour partir ne dirait rien de plus.
    //
    // LE DÉCOMPTE EST ÉCRIT SUR LE BOUTON : une famille qui lit « vous pourrez encore
    // reporter deux fois » sait ce qui vient. Rien n'est pire qu'un refus toujours
    // accepté puis une porte qui se ferme sans prévenir.
    Future<void> _tiersSyncDefer() async {

                                // Le mode BLOQUANT est la seule chose qui fait disparaître ce bouton :
                                // c'est l'état de la page qui décide, pas un compteur relu à part.
                                final pitch = (await deva_get("worker.store.pitch")) == true;
                                final show  = pitch && !(await _storeOnBlockingTiers());

                                final btn = await DvOrb.wait_for_shape("tiers_page/defer");
                                if (show) {
                                    // Le décompte est celui d'APRÈS la présentation en cours, qui vient
                                    // d'être comptée : « dernière fois » quand il ne reste plus rien.
                                    final token = _pitchDefersLeft > 0
                                        ? "@@@T:tiers_defer_n@@@"
                                        : "@@@T:tiers_defer_last@@@";
                                    await _syncLabel(btn, "tiers_page/defer",
                                        TranslationRegistry.processLabel(token)
                                            .replaceAll("{n}", "$_pitchDefersLeft"));
                                }
                                await _syncVisible(btn, "tiers_page/defer", show);
    }

    // Tap sur une carte : la périodicité change, rien ne s'achète.
    Future<void> tiers_pick_yearly(dynamic caller, dynamic event) async {

                                await _tiersSetPeriod("yearly");
    }

    Future<void> tiers_pick_monthly(dynamic caller, dynamic event) async {

                                await _tiersSetPeriod("monthly");
    }

    Future<void> _tiersSetPeriod(String period) async {

                                if (_storePeriod == period) return;
                                _storePeriod = period;
                                deva_log("info", "[store] paliers : périodicité → $period");
                                await _tiersPaintCards(await _tiersOfferTier());
    }

    // « Continuer » : achat du palier présenté, dans la périodicité choisie, derrière
    // le contrôle parental. Inerte quand c'est déjà l'abonnement en cours.
    //
    // `offer: null` = celle que le serveur juge éligible (aujourd'hui l'offre
    // fondateurs pour un clan d'avant le cutoff). Play ne sert que les offres
    // auxquelles le compte a droit, et la vérification serveur constate le reste.
    Future<void> tiers_buy(dynamic caller, dynamic event) async {

                                final tier = await _tiersOfferTier();
                                if (tier.isEmpty) return;
                                final plan = await _tiersPlanFor(tier, _storePeriod);
                                if (await _tiersIsOwned(tier, plan)) {
                                    deva_log("info", "[store] paliers : $tier/$plan est déjà l'abonnement en cours");
                                    return;
                                }
                                deva_log("info", "[store] paliers : achat $tier ($_storePeriod)");
                                await _storeBuyGated(tier);
    }

    Future<void> tiers_open_pick(dynamic caller, dynamic event) async {

                                DvOrb.navigate_new("tiers_pick_page");
    }

    // -----------------------------------------------------------------------
    // --- Choix du palier (« Combien d'aventuriers ? »)
    //
    // Mêmes cartes que la vitrine, une par abonnement du catalogue dans l'ordre
    // `order`, sur six emplacements fixes (registry_store_tiers.yml). Chaque carte
    // montre ses PLACES en points, son plafond, et ses DEUX prix. Un palier trop petit
    // est éteint et inerte. Un tap choisit le palier et ramène à la vitrine, sans rien
    // acheter.
    //
    // Le ruban « POPULAIRE » = `store.showcase.popular` (bucket) ; le cadre doré = le
    // palier choisi ; « VOTRE PALIER » = l'abonnement en cours. Aucun « conseillé » :
    // on ne connaît ni la famille ni la taille de clan qui lui convient.
    // -----------------------------------------------------------------------

    static const int _tiersSlots = 6;

    Future<void> on_tiers_pick_appear(dynamic caller, dynamic event) async {

                                try {
                                    await _tiersPaintPick();
                                } catch (e, st) {
                                    deva_log("error", "[store] choix du palier FAILED: $e\n$st");
                                }
    }

    Future<void> _tiersPaintPick() async {

                                String t(String key) => TranslationRegistry.processLabel("@@@T:$key@@@");

                                final tiers   = await _storeTiers();
                                final count   = await _storePlayerCount();
                                final chosen  = await _tiersOfferTier();
                                // Le palier « POPULAIRE », réglé au bucket (store-base-global.yml,
                                // `store.showcase.popular`), jamais déduit ici : c'est une allégation
                                // de fait, elle se corrige sans nouvelle version.
                                final popular = (await deva_get("store.showcase.popular"))?.toString() ?? "";
                                final current = await _storeSubscribed()
                                    ? ((await deva_get("store.subscription.product"))?.toString() ?? "")
                                    : "";

                                final sub = await DvOrb.wait_for_shape("tiers_pick_page/sub");
                                await _syncLabel(sub, "tiers_pick_page/sub",
                                    count < 0 ? "" : t("tiers_pick_sub").replaceAll("{n}", "$count"));

                                const gold = "0xFFD6A84A";
                                _tiersShownIds = [];
                                for (var i = 0; i < _tiersSlots; i++) {
                                    final k   = "tiers_pick_page/c${i + 1}";
                                    final has = i < tiers.length;
                                    final parts = <String, dynamic>{};
                                    for (final n in const ["frame", "badge", "name", "seats", "cap", "month", "year"]) {
                                        parts[n] = await DvOrb.wait_for_shape("${k}_$n");
                                    }
                                    if (!has) {
                                        for (final n in parts.keys) { await _syncVisible(parts[n], "${k}_$n", false); }
                                        continue;
                                    }

                                    final id = tiers[i];
                                    _tiersShownIds.add(id);
                                    final cap  = await _storeTierCapacity(id);
                                    // Effectif ILLISIBLE : on n'éteint rien (refuser sur une lecture
                                    // ratée est visible, injuste et sans recours).
                                    final fits = cap < 0 || count < 0 || cap >= count;

                                    var name = (await deva_get("store.catalog.$id.label"))?.toString() ?? "";
                                    if (name.isEmpty) name = id;
                                    final mPlan  = await _tiersPlanFor(id, "monthly");
                                    final yPlan  = await _tiersPlanFor(id, "yearly");
                                    final mPrice = await _tiersPriceFor(id, mPlan, "monthly");
                                    final yPrice = await _tiersPriceFor(id, yPlan, "yearly");

                                    final badge = id == current ? t("tiers_current").toUpperCase()
                                                : id == popular ? t("tiers_popular")
                                                : "";

                                    await _syncLabel(parts["name"],  "${k}_name",  TranslationRegistry.processLabel(name));
                                    await _syncLabel(parts["seats"], "${k}_seats", _tiersSeats(cap, count));
                                    await _syncLabel(parts["cap"],   "${k}_cap", fits
                                        ? TranslationRegistry.processLabel(cap < 0
                                            ? "@@@T:tiers_unlimited@@@" : "@@@T:tiers_upto@@@").replaceAll("{n}", "$cap")
                                        : t("tiers_too_small"));
                                    await _syncLabel(parts["month"], "${k}_month",
                                        mPrice.isEmpty ? "" : "$mPrice ${t("tiers_per_month")}");
                                    await _syncLabel(parts["year"],  "${k}_year",
                                        yPrice.isEmpty ? "" : "$yPrice ${t("tiers_per_year")}");
                                    await _syncLabel(parts["badge"], "${k}_badge", badge);

                                    // Le choisi : cadre doré appuyé, fond chaud. Les autres : sobres.
                                    final on = id == chosen;
                                    await _syncGeom(parts["frame"], "${k}_frame", "shape.border_color", on ? gold : "0x33FFFFFF");
                                    await _syncGeom(parts["frame"], "${k}_frame", "shape.border_size",  on ? "3.0" : "1.5");
                                    await _syncGeom(parts["frame"], "${k}_frame", "shape.background_color", on ? "0x2ED6A84A" : "0x0AFFFFFF");
                                    await _syncGeom(parts["cap"],   "${k}_cap",   "shape.font_color", fits ? "0xFFBFAE90" : "0xFFE39A7A");

                                    // Trop petit : tout s'éteint, et le tap ne part pas (tiers_pick_N).
                                    for (final n in parts.keys) {
                                        await _syncGeom(parts[n], "${k}_$n", "shape.opacity", fits ? "1.0" : "0.4");
                                        await _syncVisible(parts[n], "${k}_$n", n != "badge" || badge.isNotEmpty);
                                    }
                                }
                                deva_log("info", "[store] choix du palier : ${_tiersShownIds.length} palier(s), "
                                    "choisi='$chosen' populaire='$popular' courant='$current' effectif=$count");
    }

    // Les places d'un palier en points : ● pour chaque aventurier du clan, ○ pour
    // chaque place libre, ∞ pour un palier sans limite. Douze points au plus.
    String _tiersSeats(int cap, int count) {

                                final n      = count < 0 ? 0 : count;
                                const most   = 12;
                                if (cap < 0) {
                                    return "${"●" * (n < most ? n : most)} ∞";
                                }
                                final filled = n < cap ? n : cap;
                                final free   = cap - filled;
                                final shownF = filled < most ? filled : most;
                                final shownE = free < (most - shownF) ? free : (most - shownF);
                                return "${"●" * shownF}${"○" * shownE}";
    }

    // Tap sur une carte (tiers_pick_1 … tiers_pick_6) : ce palier devient celui de la
    // vitrine, qui se repeint au retour (action `show`). Rien ne s'achète ici, et un
    // palier trop petit ne se choisit pas.
    Future<void> _tiersPickSlot(int slot) async {

                                if (slot < 0 || slot >= _tiersShownIds.length) return;
                                final id    = _tiersShownIds[slot];
                                final cap   = await _storeTierCapacity(id);
                                final count = await _storePlayerCount();
                                if (!(cap < 0 || count < 0 || cap >= count)) {
                                    deva_log("info", "[store] choix du palier : $id trop petit, ignoré");
                                    return;
                                }
                                deva_log("info", "[store] choix du palier : $id");
                                _storeOfferTier = id;
                                DvOrb.navigate_back();
    }

    Future<void> tiers_pick_1(dynamic caller, dynamic event) => _tiersPickSlot(0);
    Future<void> tiers_pick_2(dynamic caller, dynamic event) => _tiersPickSlot(1);
    Future<void> tiers_pick_3(dynamic caller, dynamic event) => _tiersPickSlot(2);
    Future<void> tiers_pick_4(dynamic caller, dynamic event) => _tiersPickSlot(3);
    Future<void> tiers_pick_5(dynamic caller, dynamic event) => _tiersPickSlot(4);
    Future<void> tiers_pick_6(dynamic caller, dynamic event) => _tiersPickSlot(5);

    // Texte de la DESCENTE en attente (« Changement prévu le 12/11 : Clan, par mois »),
    // ou "" s'il n'y en a pas. Le palier suivant est publié par dvstore depuis la
    // projection : c'est le serveur qui l'a lu chez Play, l'app ne le devine pas.
    Future<String> _tiersPendingText() async {

                                if (!await _storeSubscribed()) return "";
                                final tier = (await deva_get("store.subscription.pending_tier"))?.toString() ?? "";
                                if (tier.isEmpty) return "";
                                final plan = (await deva_get("store.subscription.pending_base_plan"))?.toString() ?? "";
                                final at   = DateTime.tryParse(
                                    (await deva_get("store.subscription.pending_at"))?.toString() ?? "");

                                var name = (await deva_get("store.catalog.$tier.label"))?.toString() ?? "";
                                if (name.isEmpty) name = tier;
                                final period = plan.endsWith("yearly") ? "@@@T:tiers_yearly@@@" : "@@@T:tiers_monthly@@@";
                                final label  = "${TranslationRegistry.processLabel(name)}, "
                                               "${TranslationRegistry.processLabel(period).toLowerCase()}";
                                return TranslationRegistry.processLabel("@@@T:tiers_pending@@@")
                                    .replaceAll("{tier}", label)
                                    .replaceAll("{date}", at == null ? "" : _storeShortDate(at));
    }

    // -----------------------------------------------------------------------
    // --- Helpers
    // -----------------------------------------------------------------------

    // Qui voit et qui peut acheter : un administrateur du clan QUI EST AUSSI légalement
    // adulte. Les deux conditions, et pas une seule — « chef » est un rôle de jeu que le
    // fondateur peut donner à n'importe quel membre, y compris un enfant. Ce prédicat garde
    // TOUTES les surfaces commerciales, pas seulement l'achat : boutique, page des paliers,
    // mur de première cotisation, bandeau d'impayé, bouton « Se réabonner » du clan gelé.
    // C'est la première des deux gardes du § 5.3 du dossier « intérêt supérieur de l'enfant ».
    // La seconde — le contrôle parental de _storeBuyGated — ne porte que sur l'acte d'achat :
    // être adulte administrateur ne dispense pas de le prouver devant l'écran.
    //
    // L'ordre compte pour le coût, pas pour le résultat : _ensureIsAdmin est déjà chaud dans
    // la quasi-totalité des cas (le tiroir et l'écran Clan l'appellent avant), et il écarte
    // les non-chefs sans la lecture supplémentaire de _ensureIsAdult.
    Future<bool> _storeCanBuy() async {

                                final ctx = await _butinCtx();
                                if (ctx == null) return false;
                                final clanId     = ctx.get("clanId").toString();
                                final clanSecret = ctx.get("clanSecret").toString();
                                final region     = ctx.get("region").toString();
                                if (!await _ensureIsAdmin(clanId, clanSecret, region)) return false;
                                if (!await _ensureIsAdult(clanId, clanSecret, region)) {
                                    deva_log("info", "[store] surfaces commerciales masquées : "
                                        "$_userId est chef mais n'est pas légalement adulte");
                                    return false;
                                }
                                return true;
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
                                // éligible (aucune aujourd'hui). "" : tarif courant sec, ce que
                                // demande une reprise après gel.
                                //
                                // Clan déjà abonné : c'est un CHANGEMENT de palier (dvstore remplace
                                // l'abonnement), dont l'aboutissement se lit sur la projection.
                                _storeChangeTo = (await _storeSubscribed())
                                    ? "$productId|${await _storePlanId(productId)}" : "";
                                _storeBuyWaitStart();
                                await _store?.buy(productId, period: _storePeriod, offer: offer);
    }

    // L'ATTENTE D'UN ACHAT, VISIBLE. Entre le choix d'un palier et l'issue, il y a la
    // feuille de paiement du store PUIS la vérification serveur (lecture chez Google,
    // verrou du jeton, projection, relecture) : plusieurs secondes pendant lesquelles
    // l'écran restait figé sans rien dire, comme un bouton cassé. La page est gelée
    // (voile et roue d'attente, taps et retour bloqués) jusqu'à l'issue : succès
    // (_storeLeaveAfterPurchase), échec ou abandon (on_store_purchase_failed).
    //
    // Un paiement différé (Play le met « en attente », par exemple un paiement en
    // espèces) n'aboutit pas avant des heures : il dégèle la page tout de suite et le
    // dit (on_store_purchase_pending). L'achat, lui, reste suivi par dvstore.
    //
    // ⚠ UN MINUTEUR DE SECOURS, et il n'est pas décoratif : si Play ne rappelle
    //   personne du tout, passé ce délai, la page se dégèle quand même.
    void _storeBuyWaitStart() {

                                _storeBuyWaitStop();
                                final page = DvOrb.get_current_page();
                                if (page is! DvPage) return;
                                page.freeze();
                                _storeBuyWaitPage  = page;
                                _storeBuyWaitTimer = Timer(const Duration(seconds: 180), () {
                                    deva_log("warning", "[store] achat sans issue après 180 s : page dégelée");
                                    _storeBuyWaitStop();
                                });
    }

    void _storeBuyWaitStop() {

                                _storeBuyWaitTimer?.cancel();
                                _storeBuyWaitTimer = null;
                                _storeBuyWaitPage?.unfreeze();
                                _storeBuyWaitPage = null;
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

}

// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
