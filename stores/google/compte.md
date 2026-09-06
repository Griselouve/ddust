<!-- généré : 20260822 -->
# compte — donjons & savons

Les démarches qui se règlent au niveau du **compte développeur**, et non d'une application :
la **déclaration de statut de vendeur (DSA)** et le **programme de frais de service réduits**.
Elles ne concernent aucune app en particulier, ne demandent aucun binaire, et ne dépendent ni
de la fiche, ni des produits, ni de l'avancement du test fermé.

> ⚠️ **Ce document explique. Il ne se lit pas devant la console.**
> La feuille de saisie, avec les valeurs exactes déjà substituées, est **`saisie_compte.md`** —
> générée au build depuis `build/build.yml` (bloc `publisher:`) et son gabarit. C'est
> celle-là qu'on ouvre devant le formulaire. Celle-ci se lit **une fois**, avant, pour savoir ce
> qu'on fait.
>
> `publication.md` dit dans quel ORDRE agir (§0.2 ter et §0.3 renvoient ici) ; `playstore.md` dit
> quoi saisir au niveau de l'**app** ; `dpa.md` porte le registre RGPD.

---

## les deux démarches

| | Statut de vendeur (DSA) | Frais de service réduits |
|---|---|---|
| Ce que c'est | Une déclaration réglementaire : vends-tu en tant que professionnel ? | Une inscription commerciale : taux réduit sur le premier million de dollars annuels |
| Obligatoire ? | ✅ Oui, et sans arbitrage possible | Formellement non — **en pratique oui**, cf. plus bas |
| Durée | ~2 minutes | ~2 minutes |
| Dépend de quoi | Rien | Rien |
| Effet immédiat | Aucun affichage tant qu'aucune fiche n'est publique | Aucun, aucun produit à l'unité n'existe encore |

Elles sont **indépendantes l'une de l'autre** et du reste du parcours. On peut faire l'une sans
l'autre, dans n'importe quel ordre, et rien n'attend leur résultat.

---

## avant de commencer — deux réglages de contexte

⚠️ **Vérifier le bon compte Google.** Avec plusieurs comptes connectés, Play Console ouvre celui
d'indice 0 par défaut ; forcer le bon avec `https://play.google.com/console/u/1/` (ou l'indice qui
convient). Sinon l'écran paraît vide ou amputé, **sans aucun message d'erreur** — même piège qu'en
`publication.md` §0.2.

⚠️ **Se placer au niveau du COMPTE, pas de l'app.** Les deux réglages sont invisibles depuis la
vue d'une application. Passer par la vue « **Toutes les applis** », puis le menu de gauche. Chercher
ces écrans dans les paramètres de `Donjons & Savons` est une perte de temps garantie.

⚠️ **Les libellés bougent.** Google renomme et déplace régulièrement ces deux réglages. Les chemins
ci-dessous sont donnés avec leurs synonymes connus ; en cas de doute, la barre de recherche de la
console retrouve « statut de vendeur » et « frais de service » plus vite qu'une navigation.

---

## déclaration de statut de vendeur (DSA)

*Play Console → vue « Toutes les applis » → **Paramètres du compte développeur** → **Informations
sur le développeur** → section « **Statut de vendeur** ».*
Synonymes rencontrés : « Déclaration de statut de vendeur », « Trader status », « Vendeur au sens
du règlement européen sur les services numériques ». Une **tâche ou un bandeau** de la console peut
y mener directement.

### le verdict

| Option | Verdict |
|---|---|
| **Professionnel** (*trader*) | ✅ **C'est celle-ci.** Tu vends des abonnements dans l'Union |
| Non professionnel (*non-trader*) | ❌ Réservé à qui ne tire aucun revenu de son app. **Déclarer cela en vendant est une violation des règles, sanctionnée par le retrait de l'app** |

Il n'y a **aucun arbitrage** à faire ici. La grille à cinq paliers (1,99 € à 7,99 €/mois) est déjà
au catalogue, `pucatalog` la crée en console, et `revenus.md` en fait un plateau de revenu : le
statut professionnel est la seule réponse cohérente avec ce que fait l'app. Rien de nouveau à
décider, seulement à confirmer.

### ce qu'il faut saisir

Toutes les valeurs viennent de `build/build.yml`, bloc `publisher:` — ne rien réinventer au clavier.

| Champ (libellés variables) | Valeur | Source |
|---|---|---|
| Statut de vendeur | **Professionnel** | — |
| Nom / Nom légal | la **dénomination au RNE**, orthographe exacte de l'extrait d'immatriculation — **sans trait d'union**, et **sans « EI »** | `publisher.legal_name` |
| Adresse — rue | **adresse de domiciliation** | `publisher.address.street` |
| Adresse — code postal | | `publisher.address.postal_code` |
| Adresse — ville | | `publisher.address.city` |
| Adresse — pays | France | `publisher.address.country` |
| Téléphone | format international | `publisher.phone` |
| Adresse e-mail | `donjons@grisloup.com` | `publisher.email` |
| Site web (si demandé) | `https://donjons.grisloup.com` | `publisher.website` |
| Numéro d'immatriculation | le **SIREN**, neuf chiffres sans espaces | `publisher.registration_number` |
| Numéro de TVA | **laisser vide** — franchise en base, et le n° intracommunautaire n'est pas encore attribué (plan §2.1) | — |
| Case de consentement à l'affichage public | à cocher — c'est l'objet même de la déclaration | — |

⚠️ **Nom du registre, pas « Grisloup ».** Le champ attend l'identité **juridique**, qui reste
celle d'une personne physique : une entreprise individuelle n'est pas une société séparée de son
entrepreneur. Y déclarer le nom commercial crée un écart avec l'extrait d'immatriculation — cause
classique de blocage — et avec `dpa.md` §3.

⚠️ **RÉÉCRIT LE 2026-09-03, L'IMMATRICULATION ÉTANT OBTENUE** (SIREN `109354092`, RNE du
2026-09-02, APE `58.29C`). Ce tableau décrivait une personne physique sans structure. Deux
conséquences qui ne sont pas cosmétiques : l'adresse publiée devient la **domiciliation** au lieu du
domicile, et le numéro d'immatriculation cesse d'être vide. **Mais Google refuse une domiciliation
sur un compte PERSONNEL** : ces valeurs ne se saisissent qu'après la conversion en compte
organisation — D-U-N-S, second profil de paiement, 72 h, cf. `publication.md` §0.2. Saisir la
domiciliation trop tôt fait échouer la vérification ; saisir le domicile après la conversion
republie ce qu'on venait d'écarter.

### ⚠️ ne pas confondre trois « noms »

C'est le piège propre à ce dossier, et la console ne les distingue pas clairement :

| Nom | Valeur | Où il vit |
|---|---|---|
| Nom **légal** | `MARCHAL DE GREEF Guillaume` — règle de nommage du 2026-09-03, ordre du registre | déclaration DSA (ici) + profil de paiement |
| Nom **commercial** | `Grisloup` — déclaré au RNE, confirmé sur l'extrait. ⚠ Le domaine `grisloup.com` est déclaré à côté : c'est une adresse, pas un nom | CGU, politique de confidentialité, mention « éditeur » du site |
| Nom **du développeur** | `Grisloup` | fiche Play — **champ distinct**, paramètres du compte, réglé ailleurs |

Le nom commercial n'est pas perdu en déclarant le nom civil ici : ce sont trois champs séparés.

### ⚠️ ce que ça publie, et quand — le point qui débloque

Se déclarer professionnel fait afficher **nom, adresse complète et téléphone** sur la fiche Play
dans l'EEE. Aucun réglage ne permet de le masquer : ce n'est pas une option Play mais une
obligation répercutée.

**Mais l'exposition ne commence qu'avec une fiche publique.** Tant que la diffusion reste en piste
interne et fermée, devant des familles connues, il n'y a aucune fiche publique — donc rien
d'affiché. Faire la déclaration aujourd'hui **ne pré-empte pas** l'arbitrage de `publication.md`
§6.1 (rester particulier avec l'adresse du domicile publique, ou passer en compte organisation avec
une domiciliation). Cet arbitrage reste entier, à sa place, avant le passage en production.

C'est la raison pour laquelle cette démarche peut se faire maintenant sans rien engager.

### ⚠️ cohérence d'identité — un sixième point

`publication.md` §0.2 en liste cinq : profil de paiement Play, facturation GCP, éditeur déclaré aux
CGU, mention « éditeur » du site, responsable de traitement de `dpa.md` §3. **La déclaration DSA est
le sixième.** Un écart entre deux d'entre eux bloque une validation ou fragilise le dossier RGPD.

### ⚠️ deux écarts connus, à ne pas traiter ici

Les signaler pour qu'ils ne se perdent pas, sans les trancher maintenant :

1. **Nom civil absent du corpus légal.** Les 96 documents de `build/legal/documents/` et les pages
   légales du site déclarent l'éditeur `grisloup.com`. La déclaration DSA, elle, portera le nom
   civil — qui n'apparaît aujourd'hui dans aucun document publié. Un visiteur pourra donc lire deux
   identités différentes une fois la fiche publique. À arbitrer en même temps que §6.1.
2. **LCEN.** Se déclarer professionnel rend exigible la mention de l'adresse de l'éditeur sur le
   site, aujourd'hui volontairement absente (décision : « à réévaluer au lancement commercial »).
   L'échéance est la même que celle de §6.1 — pas aujourd'hui, mais pas oubliée.

### après la déclaration

Google peut demander une **pièce justificative** d'identité ou d'adresse, et vérifier les
coordonnées. La vérification d'identité du profil de paiement est déjà passée
(`publication.md` § état) : le dossier est donc cohérent, et il n'y a rien à préparer de plus.

---

## programme de frais de service réduits

*Play Console → vue « Toutes les applis » → **Paramètres du compte développeur** → **Groupes de
comptes**.*
Le plus simple reste le **bandeau** de la console qui propose l'inscription — c'est le point
d'entrée prévu, et il mène directement au parcours en trois écrans.

### pourquoi ce n'est pas optionnel dans les faits

`revenus.md:23` pose le coefficient net **× 0.70** sur l'hypothèse « store 15 % — abonnements **et
développeur < 1 M$/an** ». Cette seconde condition est **exactement** ce que l'inscription garantit.
Ne pas s'inscrire invaliderait silencieusement une hypothèse figée en juillet 2026, sans qu'aucun
écran ne le signale jamais.

L'inscription est **gratuite, sans contrepartie, et n'est pas automatique** : sans démarche, on
reste au taux standard.

### les trois gestes

| # | Geste | Réponse |
|---|---|---|
| 1 | Créer un **groupe de comptes** | Le créer. Un groupe d'un seul compte est le cas normal d'un développeur indépendant |
| 2 | Déclarer les **comptes développeur associés** | **Aucun** — répondre non. Il n'existe qu'un compte Play ici |
| 3 | Accepter les **conditions** | Les accepter |

Seul engagement dans la durée : **déclarer honnêtement tout compte développeur ouvert plus tard**,
le plafond du premier million se partageant alors sur l'ensemble du groupe.

### ⚠️ ce que ça protège, et ce que ça ne protège pas

| | Taux réduit |
|---|---|
| **Abonnements** | Déjà acquis **indépendamment** du programme |
| **Achats à l'unité** (transactions non récurrentes) | ❌ **Seulement** avec l'inscription |

Ce que le programme préserve, ce sont donc les futurs **packs de contenu et de thèmes**
(1,99 € / 3,99 € / 5,99 €), pas les abonnements.

⚠️ **Et ces produits-là n'existent pas encore.** `build/build.yml` les laisse volontairement
commentés (`ddust_autovalidation`, `ddust_pack_quetes`), et `pucatalog` ne gère aujourd'hui **que**
les abonnements — ouvrir les produits à l'unité demandera d'étendre le module à l'endpoint
`inappproducts`. Le bénéfice réel de cette inscription est donc **entièrement différé** aux
livrables `eco` et `themes`.

On s'inscrit quand même aujourd'hui, pour une seule raison : c'est gratuit, et **ce n'est pas
rétroactif**. S'inscrire le jour où le premier pack se vend, c'est avoir vendu au taux plein
jusque-là.

### ⚠️ le taux lui-même est en mouvement

Depuis le **30 juin 2026**, l'EEE est passé à une grille où la commission se décompose en frais de
service **+ 5 % de frais de facturation** avec le paiement Play ; les transactions récurrentes y
sont à 10 % de frais de service, et le palier du premier million ramène l'ensemble à 10 %.

L'ordre de grandeur reste cohérent avec le coefficient × 0.70 du modèle, mais l'articulation exacte
entre l'ancien palier « 15 % » et cette grille est trop récente pour être tenue pour acquise :
**confirmer sur les premiers relevés de paiement**, pas avant. Ne pas réviser `revenus.md` sur une
lecture de documentation.

---

## ce que ces démarches ne font pas

Quatre confusions à écarter d'emblée — aucune de ces deux démarches ne fait quoi que ce soit de
ce qui suit :

| Ce qu'on pourrait croire | La réalité |
|---|---|
| « Se déclarer professionnel crée une structure » | ❌ Aucune. C'est une déclaration, pas une immatriculation. Le cadre fiscal se règle ailleurs (`publication.md` §6.2) |
| « Ça convertit le compte en organisation » | ❌ Le compte reste **particulier**. La conversion est une autre démarche (D-U-N-S, 72 h, **irréversible**) |
| « Ça publie mon adresse tout de suite » | ❌ Rien n'est affiché tant qu'aucune fiche n'est publique |
| « Ça tranche l'arbitrage §6.1 » | ❌ Il reste entier, avant le passage en production |

---

## checklist

- [ ] Bon compte Google (`/console/u/N/`), vue « Toutes les applis »
- [ ] `build/build.yml` → bloc `publisher:` complété (nom civil, adresse, téléphone)
- [ ] **Statut de vendeur déclaré : professionnel**, coordonnées saisies depuis `publisher:`
- [ ] Numéro d'immatriculation laissé vide (personne physique)
- [ ] Justificatif fourni si Google le demande
- [ ] **Groupe de comptes créé**
- [ ] Comptes développeur associés : aucun déclaré
- [ ] Conditions du programme de frais réduits acceptées
- [ ] `publication.md` : les deux lignes de « restent à confirmer » cochées

---

## documents liés

| Document | Contenu |
|---|---|
| **`saisie_compte.md`** | **La feuille à ouvrir devant la console** — valeurs exactes, générée au build |
| `saisie_compte.tpl.md` | Le gabarit dont elle est rendue — c'est lui qu'on édite, jamais la sortie |
| `publication.md` §0.2, §0.3, §0.2 ter | L'ordre des étapes, le profil de paiement, l'arbitrage §6.1 |
| `playstore.md` | Ce qu'il faut saisir au niveau de l'**app** (fiche, Data Safety, produits) |
| `dpa.md` §3 | Qualification des parties — même identité que `publisher.legal_name` |
| `build/build.yml` → `publisher:` | Les valeurs d'identité, source unique |
| `build/revenus.md` | Le coefficient × 0.70 que l'inscription au programme garantit |
