# Stratégie — Ddust (Donjons et Savons)

> Généré : 2026-07-07 · Révisé : 2026-08-20 (**grille à cinq paliers au nombre de joueurs** :
> 1.99€ à 7.99€, bornes calées sur la démographie des foyers, palier 1.99€ rétabli, choix du
> palier sorti de la boutique. Effet revenu quasi nul : +3%, plateau 1 495€.)
> Révisé : 2026-08-11 (**lancement payant d'emblée** : la beta publique
> gratuite préalable est supprimée, la monétisation entre dans le périmètre de la première
> publication, compensée par une offre fondateurs).
> Révisé : 2026-07-07 (essai 14 jours ; seuil geler recalé de 60 à 40 familles payantes —
> ~40% sous le cas de base, même géométrie que TodoAist/Karma, pour ne pas geler sur du
> bruit statistique).
> Complément de `vision.md` (produit), `revenus.md` (chiffres) et `deva/roadmap.md` (exécution).

> ⚠️ **Noms de livrables.** `ddust/beta` désigne désormais **le lancement commercial** et
> `ddust/mvp` la consolidation qui le suit. Les clés sont conservées pour ne pas casser
> l'attribution des story points déjà réalisés dans `log.md` (voir l'intro de la table
> `## livrables` de `deva/roadmap.md`).

## Rôle dans le portefeuille

Premier lancement monétisé du portefeuille et **étalon de tous les gates** : ses métriques
réelles (funnel, churn, conversion essai→payant) calibreront les seuils des projets suivants.
Seule app du portefeuille avec un mécanisme de K-factor intégré (multi-utilisateurs par
construction, parrainage, partage du bilan hebdo).

## Découpage MVP / contenus additionnels

Objectif du découpage : lancer vite avec la boucle de jeu complète et les leviers viraux,
puis livrer du contenu payant régulier pour soutenir la rétention (churn famille 8%) et
monter l'ARPU. **Le développement habilitant des contenus additionnels est dans le lancement**
(item « socle extensions » : achat/activation de packs par clan, gating, restauration) —
seuls les contenus eux-mêmes sont livrés après.

**Décision 2026-08-11 — lancement payant d'emblée.** La beta publique gratuite préalable
est supprimée : la monétisation entre dans le périmètre de la première publication. Deux
raisons. D'une part elle raccourcit le délai jusqu'aux premières données payantes, seules
utiles au gate S+12 — une beta gratuite produit de la rétention, jamais de la conversion.
D'autre part elle évite de demander à des familles déjà installées de commencer à payer,
manœuvre qui coûte plus de churn qu'un prix affiché dès le premier écran.

La contrepartie est une **offre fondateurs** pour les premiers clans. Elle n'est pas
seulement commerciale : les **testeurs du test fermé Play achètent gratuitement sous
licence** et ne peuvent donc pas être récompensés par une offre Play. Le mécanisme de
compensation doit être souverain côté serveur (crédits de mois), pas délégué au store.

| Livrable | Contenu | Condition |
|---|---|---|
| `ddust/beta` *(le lancement commercial)* | Boucle de jeu complète (tâches, XP, PV, butin, boss), administration/profils, legal + abonnements (5 paliers 1.99→7.99€ au nombre de joueurs, essai 14 jours), **offre fondateurs**, cycle de défaut de paiement, dashboard achats, socle extensions, viralité de lancement (bilan hebdo partageable, parrainage v1, notation post-boss) | — |
| `ddust/mvp` *(consolidation post-lancement)* | Multitenancy et facturation multi-clan, **relances d'engagement** (balayage serveur `pulse_sweeper` : onboarding, validation en souffrance, coffre oublié ou vide côté adultes ; boss réellement convoqué et retour du clan côté enfants — cf. vision.md § « Les relances d'engagement »), invitations à distance, réserve refactor sur le feedback des premières familles payantes | — |
| `ddust/eco` | Pack économie : or, boutique des héros, loot, quêtes, potions, objets, classes, faveurs, succès/titres, saisons + packs de tâches (bricolage, routine) + affiliation butins. Commercialisé en extensions (packs 3.99€, cf. vision) | gate ≥ maintenir |
| `ddust/themes` | Packs de thèmes 5.99€ (« Station Spatiale », « Académie de Magie », « Far West », « Mafia ») : contenu YAML + assets | gate ≥ maintenir |

Rationnel de l'ordre : le pack économie arrive ~3 mois après le lancement, au
moment où la nouveauté s'essouffle pour les premières familles — il relance l'engagement
des enfants et ouvre la monétisation additionnelle. Les thèmes sont purement cosmétiques
et attendent la preuve que la base paye. La multitenancy suit le lancement plutôt que de
le précéder : l'entitlement est modélisé **par clan** dès le départ (aucune migration
ultérieure), mais l'UI reste mono-clan tant que le multi-clan n'est pas livré.

## Leviers acquisition & rétention

- **Bilan hebdo partageable** : canal d'acquisition n°1 — une pub gratuite dans les stories
  des parents. Il doit être beau, c'est un item de lancement à part entière.
- **Offre fondateurs** (décision 2026-08-11) : contrepartie du lancement payant d'emblée.
  Essai allongé + première année remisée pour les clans créés avant un cutoff, **lu côté
  serveur** pour rester ajustable sans republier. Doublée d'un moteur de crédits de mois,
  seul capable de récompenser les testeurs du test fermé (achats gratuits sous licence).
- **Parrainage** (1 mois offert, cumulable) : visible dans l'app dès le lancement. Même
  moteur de crédits que l'offre fondateurs — un seul mécanisme, deux usages.
- **Affiliation Amazon/Awin sur les butins** : revenu additionnel par famille, zéro friction
  (livrable eco).
- **Featuring « famille » du Play Store** : conformité Family Policy déjà prévue — canal réel.
- **Boucle de notation post-boss** (« tu as aimé : va voter ») : dès le lancement.
- **Relances d'engagement** (livrable `mvp`) : le décrochage se joue PENDANT l'essai de
  14 jours, pas après. Coût d'infra négligeable (< 0,30 €/mois à 1 000 clans) ; le vrai
  coût est l'attention des familles, d'où le plafond d'une notification par personne et
  par passe et l'arrêt définitif après trois relances ignorées.
- **Seeding** : flyers écoles/commerces + subreddits parents FR+EN pendant la fenêtre
  d'exploitation (items roadmap).
- **Pricing (refondu 2026-08-20)** : cinq paliers indexés sur le **nombre de joueurs du clan**
  (membres actifs, admins compris, sans distinction enfant/adulte) — Essentiel 1-2 à 1.99€,
  Clan 3-4 à 2.99€, Tribu 5-7 à 4.99€, Guilde 8-12 à 5.99€, Royaume 13+ à 7.99€ ; plans
  annuels de 19.99€ à 64.99€. **Essai gratuit ramené de 1 mois à 14 jours** : un mois complet
  laissait passer le pic d'enthousiasme avant le premier paiement, et retardait d'autant les
  données payantes disponibles au gate.

  Remplace la grille à deux paliers (2.99€ « 5 enfants + 4 adultes » / 4.99€ illimité) et
  **renverse la suppression du palier 1.99€** décidée en juillet pour l'ancrage. Le motif est
  de **lisibilité, pas de revenu** : deux plafonds distincts obligeaient une famille à savoir
  de quelle nature était chacun de ses membres pour prévoir son palier, ce qu'aucune n'a envie
  de calculer.

  ⚠️ **Ne rien attendre de cette refonte côté revenu : +3% de panier**, sous la précision du
  modèle (panier 3.05€, plateau 1 495€). L'entrée à 1.99€ — souscrite par **40% des clans**,
  c'est le palier le plus fréquent — coûte à peu près ce que les paliers hauts rapportent. Une
  première évaluation annonçait +10% sur une répartition estimée à la louche, que la
  démographie ne soutient pas.

  Le vrai levier n'est pas le barème mais les **bornes** : ±1 sur celle de Clan vaut ±10% de
  plateau, cinq fois l'effet de toute la refonte. Elles se recalent sur `clans_store.tier`,
  observable dès les premières souscriptions — à relever au gate S+12 avant même la
  conversion (voir `revenus.md` § Sensibilité).

- **Montée de palier déclenchée, jamais démarchée** : le choix de palier sort de la boutique
  et vit sur un écran dédié qui ne s'ouvre qu'au moment où le clan bute sur sa capacité (ou
  sur relance d'impayé). Il surligne le palier courant et celui qui ouvre la place manquante.
  C'est un pari commercial explicite : on renonce à l'upsell permanent d'une grille affichée
  en boutique, contre une proposition faite à l'instant précis où elle répond à un besoin
  éprouvé. À surveiller au gate — si le taux de montée de palier est nul, c'est ce pari qui
  est faux, pas la grille.

## Gate S+12 (fin de fenêtre d'exploitation, ~novembre 2026)

| Décision | Critère |
|---|---|
| **Scale** (réinvestir : iOS, EN push, features) | ≥ 150 familles payantes, conversion essai→payant ≥ 25%, churn M2 ≤ 12% |
| **Geler** (maintenance seule) | < 40 familles payantes |

Les livrables `eco` et `themes` exigent au minimum **maintenir**. La décision est écrite
(1 page) pour éviter la renégociation émotionnelle. Ce gate est **le point de bascule du
portefeuille** : premier point de données réel, il étalonne tous les seuils suivants.

Les **seuils restent inchangés** malgré le passage au lancement payant : ils étaient déjà
exprimés en familles *payantes*, ce que la beta gratuite n'aurait de toute façon pas produit.
Deux précautions de lecture s'ajoutent. D'abord les **clans fondateurs comptent comme
payants** dès leur conversion, même pendant leur période remisée — sinon l'offre pénalise
le gate qu'elle sert. Ensuite les clans du **test fermé sont exclus du dénominateur** de la
conversion essai→payant : leurs achats sous licence sont gratuits et fausseraient le taux.

⚠️ La date se cale sur la fin de la fenêtre d'exploitation dans `deva/roadmap.md` (colonne
`rampup` de la ligne `ddust/beta`), recalculée à chaque régénération du KPI — ne pas figer
une date en dur ici.

## Principes portefeuille appliqués

- Fenêtre d'exploitation de 10 semaines après le lancement (rampup roadmap) : correctifs,
  itération onboarding, seeding — le build d'Engrams continue en fond mais ne prend pas le dessus.
- **Le chemin critique est administratif, pas technique** : compte marchand Google Payments,
  puis ≥ 12 testeurs opt-in pendant 14 jours continus avant l'accès production. Ces délais
  courent en parallèle du développement et doivent être engagés en premier — un lot de
  monétisation terminé n'avance à rien si le compte marchand n'est pas validé.
- FR + EN dès le jour 1 (fiche store, contenu).
- iOS seulement si gate = scale, jamais spéculativement.
- Usage IA « très exceptionnel » (vision) : pas d'enjeu de marge d'inférence sur ce projet.
