# Revenus — Ddust (Donjons et Savons)

> Généré : 2026-07-07 · Révisé : 2026-08-11 (**lancement payant d'emblée** : la beta gratuite
> préalable est supprimée, une offre fondateurs la remplace ; périodes recalées sur la
> livraison KPI et effet fondateurs documenté).
> Révisé : 2026-07-07 (commission store réelle 15% → coefficient 0.70 ;
> palier 1.99€ supprimé, entrée à 2.99€, essai gratuit ramené à 14 jours ; table recalculée —
> l'ancienne était restée sur un panier ~2€).
> Détail projet du modèle portefeuille `deva/revenus.md` (hypothèses fiscales SASU+IS,
> distribution et consolidation communes là-bas).

## Modèle économique retenu

- **Abonnement familial** avec essai gratuit **14 jours** (un mois complet laissait passer
  le pic d'enthousiasme avant le premier paiement) : paliers **2.99€/mois** (5 enfants,
  4 adultes) et **4.99€/mois** (illimité) — palier 1.99€ supprimé (ancrage sur 2.99€).
  Plans annuels à -17% : 29.99€/an et 49.99€/an. Panier moyen retenu :
  **~3.00€/mois par famille** (mix des deux paliers, remise annuelle incluse).
- **Extensions payantes** (livrables `eco` et `themes`) : validations auto 1.99€,
  packs contenu 3.99€, pack thèmes 5.99€ — appliquées à un seul clan.
- **Affiliation** (Awin/Amazon…) sur les butins : revenu additionnel par famille.
- Un abonnement par clan en multi-clan.
- **Coefficient net société : × 0.70** (store 15% — abonnements et développeur < 1M$/an —,
  IS ~18%) — usage IA très exceptionnel, aucun abattement d'inférence.

## Hypothèses

- **Churn 8%/mois** (famille : usage récurrent, abandon si les enfants se désintéressent).
- **Acquisition organique : ~50–60 nouvelles familles/mois au pic** — les posts
  communautaires sont des one-shots, la niche est encombrée (Nipto, OurHome…).
  Équilibre : ~650–750 familles, retenu **~700**. La viralité intégrée (parrainage,
  bilan partageable) est l'upside, pas le cas de base.
- Les extensions (eco/themes) et l'affiliation ne sont pas comptées dans le plateau
  d'abonnement : upside estimé +10–15% d'ARPU si le gate passe — à réviser sur données
  réelles au gate S+12.

## Estimation (livraison ~fin août 2026 — voir kpi roadmap, ligne `ddust/beta`)

Les périodes se lisent en mois écoulés depuis la livraison, pas en dates figées : la date
de livraison est recalculée à chaque régénération du KPI. Les mois calendaires ci-dessous
ne sont qu'une commodité de lecture.

| Période | Familles en base | Net/mois |
|---|---|---|
| M1–M3 (sept–nov 2026) | ~70 | 150€ *(voir effet fondateurs)* |
| M4–M12 (déc 2026–août 2027) | ~180 | 380€ |
| An 2 (2027–2028) | ~350 | 730€ |
| An 3 | ~550 | 1 150€ |
| An 4–5 | ~700 | 1 470€ |
| An 6–7 | ~650 | 1 370€ |
| An 8–10 | ~570 | 1 200€ |

Plateau : ~700 familles × 3.00€ × 0.70 ≈ 1 470€ net/mois (An 4–5), hors upside extensions.

### Effet de l'offre fondateurs (décision 2026-08-11)

Le passage au lancement payant d'emblée supprime la beta gratuite mais la remplace par une
offre fondateurs (essai allongé + première année remisée) sur les premiers clans. L'effet
est un **décalage, pas une perte** :

- **M1–M3 encaissent nettement moins que 150€/mois** — les fondateurs sont en essai allongé
  ou en tarif remisé, et les clans du test fermé ne paient rien du tout (achats gratuits sous
  licence). Ne pas lire un M1 faible comme un échec de conversion.
- **Le plateau est inchangé** : l'offre ne porte que sur la première année des premiers
  clans, pas sur le prix courant. L'ancrage à 2.99€ reste le prix affiché.
- **Le panier moyen ~3.00€ n'est atteint qu'à partir de M13**, quand les fondateurs
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
- Les revenus d'extensions ne démarrent qu'avec `ddust/eco` et restent conditionnels au gate.
