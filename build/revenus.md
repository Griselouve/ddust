# Revenus — Ddust (Donjons et Savons)

> Généré : 2026-07-07 · Révisé : 2026-08-24 (livraison confirmée au 3 sept 2026 ; trajectoire
> par livrable et taux d'érosion ajoutés).
> Révisé : 2026-08-20 (**grille à cinq paliers au nombre de joueurs** :
> les deux paliers « 5 enfants / 4 adultes » et « illimité » sont remplacés, le palier 1.99€
> est rétabli. Bornes calées sur la démographie des foyers, panier **3.05€**, plateau
> **1 495€**. Effet revenu **quasi nul (+3%)** — c'est une refonte de lisibilité, pas de
> tarif. Une première version de cette révision annonçait +10% sur une répartition estimée
> à la louche ; corrigé le jour même.)
> Révisé : 2026-08-11 (**lancement payant d'emblée** : la beta gratuite
> préalable est supprimée, une offre fondateurs la remplace ; périodes recalées sur la
> livraison KPI et effet fondateurs documenté).
> Révisé : 2026-07-07 (commission store réelle 15% → coefficient 0.70 ;
> essai gratuit ramené à 14 jours ; table recalculée — l'ancienne était restée sur un
> panier ~2€).
> Détail projet du modèle portefeuille `deva/revenus.md` (hypothèses fiscales SASU+IS,
> distribution et consolidation communes là-bas).

## Modèle économique retenu

- **Abonnement familial** avec essai gratuit **14 jours** (un mois complet laissait passer
  le pic d'enthousiasme avant le premier paiement), en **cinq paliers indexés sur le nombre
  de joueurs du clan** (membres actifs, admins compris, sans distinction enfant/adulte) :

  | Palier | Joueurs | Part des clans | Mensuel | Annuel | Remise annuelle |
  |---|---|---|---|---|---|
  | Essentiel | 1-2 | **40%** | 1.99€ | 19.99€ | -16% |
  | Clan | 3-4 | **30%** | 2.99€ | 24.99€ | -30% |
  | Tribu | 5-7 | **25%** | 4.99€ | 39.99€ | -33% |
  | Guilde | 8-12 | **4%** | 5.99€ | 49.99€ | -30% |
  | Royaume | 13+ | **1%** | 7.99€ | 64.99€ | -32% |

  Panier moyen retenu : **~3.05€/mois par famille** (calcul ci-dessous).
- **Extensions payantes** — **quinze produits de 1.99€ à 7.99€**, répartis sur les livrables
  `loots`, `classes`, `packs` et `themes` : l'**extension « Butin » à 7.99€** (or, boutique des
  héros, loot, équipement, faveurs, saisons), les **classes de personnage à 6.99€**, **trois
  thèmes** à 5.99€ pièce, **sept packs de contenu** à 3.99€ (Quêtes ×3, Potions ×3, Devoirs
  faits, plus les packs de tâches Bricolage et Routine) et les validations auto à 1.99€.
  Appliquées à un seul clan. Catalogue exact : `vision.md` § Extensions, qui fait foi.
  *(Corrigé le 2026-08-24 : `eco` a été renommé `loots` et éclaté ; « pack thèmes » au singulier
  laissait croire à un seul produit alors qu'il y en a trois.)*
- **Affiliation** (Awin/Amazon…) sur les butins : revenu additionnel par famille.
- Un abonnement par clan en multi-clan.
- **Coefficient net société : × 0.70** (store 15% — abonnements et développeur < 1M$/an —,
  IS ~18%) — usage IA très exceptionnel, aucun abattement d'inférence.

### Décision 2026-08-20 — grille au nombre de joueurs

La grille précédente portait **deux plafonds** (5 enfants, 4 adultes). Le motif du changement
n'est pas tarifaire mais de **lisibilité** : une famille ne pouvait pas prévoir son palier
sans répondre à des questions que le produit ne pose pas (l'admin joue-t-il ? l'ado de 17 ans
compte-t-il comme enfant ?). Un compteur unique s'explique en une phrase.

Elle **renverse la décision de juillet 2026** qui supprimait le palier 1.99€ pour ancrer
l'entrée à 2.99€. C'est assumé : l'ancrage suppose une offre unique qu'on veut faire paraître
chère ou bon marché, alors qu'une grille à cinq paliers se lit comme un barème — on y cherche
sa ligne, pas un point de comparaison. Et le palier d'entrée n'est pas une offre au rabais
consentie à une minorité : à **40% des clans**, c'est le palier le plus souscrit de la grille.

**Les bornes suivent la démographie réelle des foyers**, pas une progression régulière —
d'où Clan qui s'arrête à 4 joueurs et Tribu à 7. Un cran de décalage déplacerait des milliers
de foyers d'un palier à l'autre : ces bornes sont le paramètre le plus sensible de la grille,
bien avant les prix eux-mêmes.

### ⚠️ Effet sur le revenu : quasi nul, et c'est voulu

**+3% de panier moyen** à répartition identique (2.96€ → 3.05€), soit **moins que la précision
du modèle**. La refonte n'est **pas** une manœuvre de revenu : c'est un changement de
lisibilité, et il faut la juger comme telle.

Le détail des deux mouvements, qui se compensent presque exactement :

- **L'entrée à 1.99€ coûte**, et beaucoup : 40% des clans passent de 2.99€ à 1.99€, soit
  −0.40€ de panier à eux seuls.
- **Les paliers hauts rapportent** : les foyers de 5 joueurs et plus (30% des clans) passent
  de 2.99€ à 4.99€ ou davantage. Ils payaient auparavant le tarif d'un foyer de deux.

Une version antérieure de cette page annonçait +10%. Ce chiffre reposait sur une répartition
estimée à la louche (55% de clans de 3-5 joueurs) que les statistiques démographiques ne
soutiennent pas : les petits foyers dominent. Corrigé le 2026-08-20.

### Calcul du panier moyen

Répartition ci-dessus (40/30/25/4/1), fondée sur la démographie des foyers.

Mensuel pondéré : **3.26€**. En tenant compte de **~25% de souscriptions annuelles** à une
remise moyenne pondérée de **25.5%**, le panier retenu est **~3.05€/mois**.

Comparaison à grille égale — l'ancienne grille (2.99€ jusqu'à 5 enfants + 4 adultes, 4.99€
au-delà) sous **cette même répartition** donnait **2.96€**, et non les 3.00€ documentés en
juillet, qui supposaient des foyers plus grands. L'écart réel est donc de **+3.0%**, et le
facteur appliqué aux plateaux ci-dessous est **1.0175** par rapport à la base historique.

### Sensibilité — ce qui fait vraiment bouger le plateau

Le panier est **peu sensible aux prix** et **très sensible aux bornes**. Déplacer une borne
d'un cran fait basculer un palier entier de foyers.

Calcul sur une distribution par taille de foyer cohérente avec les parts ci-dessus
(1 j. 12%, 2 j. 28%, 3 j. 18%, 4 j. 12%, 5 j. 14%, 6 j. 8%, 7 j. 3%, 8-12 j. 4%, 13+ 1%) :

| Variante (plafonds des 4 premiers paliers) | Répartition obtenue | Panier | Plateau |
|---|---|---|---|
| **Grille retenue** — 2 / 4 / 7 / 12 | 40/30/25/4/1 | **3.05€** | **1 495€** |
| Tribu resserré à 5-6 — 2 / 4 / 6 / 12 | 40/30/22/7/1 | 3.08€ | 1 510€ |
| Clan réduit à 3 seul — 2 / 3 / 7 / 12 | 40/18/37/4/1 | 3.27€ | 1 605€ |
| Clan élargi à 3-5 — 2 / 5 / 8 / 12 | 40/44/13/2/1 | 2.77€ | 1 360€ |
| Essentiel élargi à 1-3 — 3 / 5 / 7 / 12 | 58/26/11/4/1 | 2.64€ | 1 295€ |

Lecture : **±1 sur la borne de Clan vaut ±10% de plateau**, soit cinq fois l'effet de toute la
refonte tarifaire. La grille retenue est volontairement au milieu de cette plage — élargir
Essentiel ou Clan « pour être sympa » coûterait 150 à 200€/mois au plateau.

Ces bornes ne doivent donc pas être retouchées à l'intuition : elles valent plus que le
barème. Et la donnée qui les arbitre — la taille réelle des clans — est **directement
observable dès les premières souscriptions** (`clans_store.tier`), sans instrumentation
supplémentaire.

## Hypothèses

- **Churn 8%/mois** (famille : usage récurrent, abandon si les enfants se désintéressent).
- **Acquisition organique : ~50–60 nouvelles familles/mois au pic** — les posts
  communautaires sont des one-shots, la niche est encombrée (Nipto, OurHome…).
  Équilibre : ~650–750 familles, retenu **~700**. La viralité intégrée (parrainage,
  bilan partageable) est l'upside, pas le cas de base.
- Les extensions (`loots`, `packs`, `themes`) et l'affiliation ne sont pas comptées dans le
  plateau d'abonnement : upside estimé +10–15% d'ARPU si le gate passe — à réviser sur données
  réelles au gate S+12.

## Estimation (livraison 3 septembre 2026 — voir kpi roadmap, ligne `ddust/beta`)

Les périodes se lisent en mois écoulés depuis la livraison, pas en dates figées : la date
de livraison est recalculée à chaque régénération du KPI. Les mois calendaires ci-dessous
ne sont qu'une commodité de lecture.

| Période | Familles en base | Net/mois |
|---|---|---|
| M1–M3 (sept–nov 2026) | ~70 | 155€ *(voir effet fondateurs)* |
| M4–M12 (déc 2026–août 2027) | ~180 | 385€ |
| An 2 (2027–2028) | ~350 | 745€ |
| An 3 | ~550 | 1 170€ |
| An 4–5 | ~700 | 1 495€ |
| An 6–7 | ~650 | 1 395€ |
| An 8–10 | ~570 | 1 220€ |

Plateau : ~700 familles × 3.05€ × 0.70 ≈ 1 495€ net/mois (An 4–5), hors upside extensions.

**Taux d'érosion sans nouveau contenu : ~3,8 %/an** — dérivé de l'écart An 4–5 → An 8–10
(−18 %, le plus faible du portefeuille hors TodoAist). `déclaré`. Justification : une famille
ne quitte pas Ddust parce qu'elle a « fini le contenu », elle le quitte parce que les enfants
grandissent ou se lassent du principe. Le contenu n'est pas ce qui la retient — c'est le
mécanisme d'habitude, et le churn de 8 % le capture déjà.

## Trajectoire par livrable

**Refaite le 2026-08-24** : la table ne connaissait que deux lots (`eco`, `themes`) alors que la
roadmap en compte six, dont deux gratuits.

| État | Livré | Familles | Churn | Panier | Plateau | Δ direct | Δ rétention | Perte évitée |
|---|---|---|---|---|---|---|---|---|
| `beta` + `mvp` | 2026-09 | 700 | 8 % | 3,05 € | **1 495 €** | — | — | — |
| `+ defis` *(gratuit)* | 2026-11 | 712 | 7,9 % | 3,05 € | **1 530 €** | +0 € | +35 € | **+45 €** |
| `+ loots` | 2026-12 | 735 | 7,7 % | 3,05 € | **1 665 €** | +95 € | +40 € | — |
| `+ minijeux` *(gratuit)* | 2027-02 | 743 | 7,6 % | 3,05 € | **1 690 €** | +0 € | +25 € | **+40 €** |
| `+ classes` | 2027-04 | 755 | 7,5 % | 3,05 € | **1 725 €** | +18 € | +17 € | — |
| `+ themes` | 2027-06 | 765 | 7,45 % | 3,05 € | **1 770 €** | +30 € | +15 € | — |
| `+ packs` | 2027-10 | 772 | 7,4 % | 3,05 € | **1 795 €** | +18 € | +7 € | — |
| *contrefactuel : rien après le MVP* | — | 672 | dérive à 8,3 % | 3,05 € | 1 495 → **1 435 €** | | | |

`déclaré` sur toute la ligne. Le taux d'attachement des packs sera `mesuré` dès leur sortie.

**`loots` porte à lui seul 135 €/mois, soit 45 % de tout ce que les extensions rapportent.** Il
vend l'extension « Butin » à 7.99 €, quatre packs à 3.99 € et les validations auto à 1.99 € — et
c'est aussi lui qui ouvre la boutique, donc qui rend les cinq lots suivants vendables. *(Ligne
révisée le 2026-08-24 : elle ne comptait que les packs, l'extension elle-même n'ayant pas de
prix jusque-là.)*

**`classes` est le meilleur rapport du tableau : 34sp pour 35 €/mois.** Le prix de 6.99 €
(décision 2026-08-24) en fait le deuxième produit du catalogue, et son taux d'attachement
devrait dépasser celui d'un pack de contenu — une classe change la façon de jouer, pas seulement
ce qu'il y a à jouer.

⚠ **C'est aussi ce qui rend son estimation suspecte.** 34sp est le chiffre d'origine, posé quand
les classes n'étaient qu'une ligne parmi d'autres du pack économie. Le même angle mort a été
trouvé sur les thèmes le même jour (34sp couvraient un thème sur trois). À revérifier avant
avril 2027.

**Ddust est le projet où les contenus additionnels rapportent le plus en direct** — quinze
produits de 1.99 à 7.99 € sur une base de 700 familles, sans abattement d'inférence
(coefficient 0,70 au lieu de 0,574). Et **le contrefactuel est clément** : ne rien livrer après
le MVP ne coûte que 60 €/mois.

C'est l'inverse exact de Prompt To Kill, dont les contenus ne rapportent presque rien en direct
mais dont l'absence coûte 240 €/mois. Deux projets, deux économies opposées — et c'est
exactement ce que la colonne « perte évitée » sert à rendre visible.

**Les deux lots gratuits ne sont pas des cadeaux, ce sont les plus rentables du tableau.** Ni
`defis` ni `minijeux` n'affichent un euro de Δ direct, et ensemble ils évitent 85 €/mois de
perte — davantage que ce que `themes` rapporte en vente. C'est l'alternance gratuit/payant qui
produit cet effet : la mise à jour offerte entretient l'abonnement et prépare la vente suivante.

⚠ Ces six livrables restent **conditionnels au gate Ddust ≥ maintenir** (fin novembre 2026).
Ils ne sont donc pas comptés dans les tableaux consolidés tant que le gate n'est pas tranché.
`defis` sort le 29 novembre, soit **au moment même du gate** — sa production commence donc avant
que la décision ne tombe.

### Effet de l'offre fondateurs (décision 2026-08-11)

Le passage au lancement payant d'emblée supprime la beta gratuite mais la remplace par une
offre fondateurs (essai allongé + première année remisée) sur les premiers clans. L'effet
est un **décalage, pas une perte** :

- **M1–M3 encaissent nettement moins que 155€/mois** — les fondateurs sont en essai allongé
  ou en tarif remisé, et les clans du test fermé ne paient rien du tout (achats gratuits sous
  licence). Ne pas lire un M1 faible comme un échec de conversion.
- **Le plateau est inchangé par l'offre** : elle ne porte que sur la première année des
  premiers clans, pas sur le prix courant. Les tarifs affichés restent ceux de la grille.
- **Le panier moyen ~3.05€ n'est atteint qu'à partir de M13**, quand les fondateurs
  basculent au tarif plein. Le churn au moment de cette bascule est le vrai risque à
  surveiller — c'est une donnée que le modèle n'a pas et que le gate ne verra pas non plus.

Comparé à la beta gratuite qu'elle remplace, l'offre est **strictement moins coûteuse** :
elle produit des conversions réelles (donc des données exploitables au gate) là où une beta
gratuite n'aurait produit aucun revenu ni aucun taux de conversion.

## Points de vigilance

- Le gate S+12 (~fin nov 2026, fin du rampup `ddust/beta`) recale acquisition et panier moyen
  sur données réelles — ne pas réviser les plateaux avant. L'essai à 14 jours fait passer les
  premières familles en payant avant le gate ; le seuil « geler » a été recalé à < 40 payantes
  (~40% sous le cas de base, voir strategie.md).
- **Le net encaissé au gate sera structurellement sous le modèle** à cause de l'offre
  fondateurs. Le gate se juge sur le **nombre de familles payantes et le taux de conversion**,
  pas sur le chiffre d'affaires des trois premiers mois — sinon l'offre déclenche mécaniquement
  un « geler » injustifié.
- Les revenus d'extensions ne démarrent qu'avec `ddust/loots` et restent conditionnels au gate.
- **Relever `clans_store.tier` en premier au gate S+12**, avant même la conversion. La
  répartition par palier (40/30/25/4/1) est adossée à la démographie des foyers, mais c'est
  une démographie générale, pas celle des familles qui installent une app de tâches
  ménagères — lesquelles ont probablement plus d'enfants que la moyenne. Le biais irait donc
  dans le bon sens, mais il n'est pas mesuré. La donnée est disponible sans instrumentation
  supplémentaire dès les premières souscriptions, et elle arbitre les BORNES, qui pèsent
  cinq fois plus que le barème (cf. « Sensibilité »).
- **Ne pas attendre de gain de revenu de cette refonte** : +3%, sous la précision du modèle.
  Si le plateau doit monter, cela viendra de l'acquisition ou des extensions, pas du barème.
