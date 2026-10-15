# Boutique générique deva : dvshop (client) + pushop (serveur), premier client ddust

> Plan mis de côté le 2026-10-13, au profit d'une maquette Flet (voir shop.yml / main.py).

## Décisions utilisateur (2026-10-13)
- Module générique : drapeaux « populaire » et comptes à rebours autorisés (en conf).
- Loot (gains en jeu) ≠ boutique (achat en argent réel ou en or).
- Premier toucher = « confirmer » (retour au repos après 4 s), second toucher = achat. Pas de popup.
- Avantages et remises CALCULÉS, jamais déclarés.
- V1 = tout le vocabulaire + l'UI complète. Pas de panier. Abonnements hors boutique (tiers_page).
- Visibilité par tags : `tags` (tous requis), `tags_any` (au moins un), `tags_none` (aucun).
  - Les tags sont déclarés en conf comme règles sur des données que le serveur relit aussi.
  - Tags implicites `owns:<item>`.
  - Visibilité ≠ achat (`requires`), avec `hidden` | `locked` (+ raison).
- ddust : les objets en or sont visibles par tous, tout le reste par les chefs seulement.
- `clans_owned` et `clan_owned` sont supprimés, absorbés par la table générique.

## Constat sur l'existant
- **pucatalog** sait déjà créer les produits à l'unité (`type: product`). ddust en déclare 15 en `enabled: false`.
- **pustore `store_verify`** traite déjà `kind: product`, sans jamais consommer.
- **`store_rtdn`** retire déjà de la projection un produit remboursé.
- **dvstore** achète tout en `buyNonConsumable` (`dvstore_billing.dart` L190).
- **dvorb** a DvGallery et DvSegmented, mais aucun carrousel.
- ⚠ **L'or est modifiable par le client** (règle `clans_players`, `backend/config.yml` L414). Écart connu, à durcir
  avec loots.

## 1. Découpage
- `deva/flutter/modules/dvshop/` : moteur, tags, prix, effets.
- `dvorb/dvcarousel.dart` : PageView + points.
- `DvShop` : carrousel + DvSegmented + sections de cartes, aux styles surchargeables.
- `deva/pulumi/modules/pushop/` : callables `shop_sync`, `shop_buy`, `shop_toggle` ; HTTP `shop_fulfil` ;
  `shop_sweeper`.
  - `evalTags` est recopié à l'identique dans chaque fonction.
- **pustore** : quand `SHOP_FULFIL` est renseigné, `store_verify` et `store_rtdn` appellent `shop_fulfil` en OIDC,
  puis exécutent `consume` ou `ack` selon sa réponse, après l'octroi.

## 2. Conf : layer bucket `shop-global.yml`
- `shop.version` (sinon `stale_catalog`), `shop.group`, `shop.tags.<t> {doc, field, equals|in|contains}`,
  `shop.currencies`, `selectors`, `sections`, `highlights`.
- `items.<id>` :
  - placement et affichage : `section`, `rank`, `image`, `flags`, `quantity`, `unit_of` ;
  - prix : `price {kind: free|gold|play, amount|product, compare_to}` ;
  - règles d'achat : `policy` (`once` | `rebuy` | `cooldown:P7D` | `period:P1M`), `requires`, `expiry` ;
  - portée et bascule : `scope`, `toggle_group`, `toggle_default`, `default` ;
  - effets : `effects`, `server_effects` ;
  - après achat : `after_purchase` (`owned` | `vanish`) ;
  - visibilité : `tags*`, `visibility` ;
  - retrait : `retired`.

## 3. Firestore (base `<rp>store`)
- `shop_groups/{gk}`, avec `gk = sha256(scopeId:secret)`. Les règles ne savent pas consulter une autre base : le
  chemin sert de preuve d'appartenance.
  - Le document parent porte `active {theme, mascot}`, `changed_at/_by` et `rev`.
- `shop_items/{docId}` : `item_id`, `owner_id`, `group_id`, `qty`, `price_kind`, `paid`, `acquired_at`,
  `expires_at`, `state`, `proof`.
  - docId déterministe, qui sert de verrou : `once:`, `period:<clé>`, `cd:<n>`, `order:`, `default:`.
- `shop_orders/{orderId}` : `reserved → paid → granted | failed`.
- Règles : lecture pour tout utilisateur authentifié (par `gk`), collectionGroup filtré sur `owner_id`. Écriture
  serveur seulement.

## 4. Flux serveur
- **Vérifications communes**, à chaque appel : appartenance, version, tags, `requires`, policy (fuseau `SHOP_TZ`).
- **Gratuit** : `create()`. **Or** : transaction de débit + témoin `shop_debits/{requestId}`, rattrapé par le
  balayage.
- **Play** :
  1. réservation, puis achat avec `obfuscatedProfileId` ;
  2. `store_verify` ou le RTDN appelle `shop_fulfil`, qui répond `consume` (rachetable) ou `ack`.
- **Remboursement** : `state: revoked`, la bascule revient au défaut.
- **Item payé devenu invisible** : il reste possédé par le groupe.

## 5. Avantage et remise
- Avantage : `1 − (prix_pack/qty)/prix_unité` (même `unit_of`), affiché à partir de 5 %.
- Remise, selon la source disponible : offre Play `onetimeproducts`, sinon `compare_to: <productId>`, sinon
  `compare_to: {amount}` pour l'or. Historique Omnibus sur 30 jours.

## 6. API client
- Clés : `shop.items.<id>.{visible,state,reason,price,advantage,discount,…}`, `shop.active.<g>`, `shop.tags.<t>`.
- Actions : `shop.buy`, `shop.toggle`, `shop.refresh`.
- Événements : `on_purchase`, `on_toggle`, `on_expired`.
- Registre d'effets : `theme` et `mini` fournis, `shop.effects.<type>: worker.<action>` pour l'app.
- Surveillance de `shop_groups/{gk}`. dvstore : `consumable` + `profileId`.

## 7. Migration ddust
- `shop-global.yml`, avec une reprise unique depuis `clans_owned` (`MIGRATE_OWNED`).
- `worker_store`, `worker_watch`, `registry_store.yml` : `shop/dvshop`.
- Retrait de `clan_owned` (L1919-2082), de ses règles (L515-553), de `CLAN_COLLECTIONS` et du reset `build.yml`.

## 8. Étapes
1. DvCarousel.
2. pushop : base + `sync` / `toggle`.
3. dvshop : moteur.
4. Migration des thèmes.
5. Achat en or.
6. pustore `fulfil` + consume.
7. Réservation Play + remboursement.
8. UI complète.
9. pucatalog `onetimeproducts` + offres.
10. Activer les produits.

## Non vérifié
- `obfuscatedProfileId` et `oneTimePurchaseOfferDetails` dans `in_app_purchase_android`.
- L'abandon de `inappproducts` par Google.
