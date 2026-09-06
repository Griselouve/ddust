<!-- généré : 20260819 -->
# publication — donjons & savons

Marche à suivre complète pour amener l'app sur Google Play, de zéro jusqu'au déploiement en
production. Première publication : rien n'est supposé acquis.

**Ce document dit dans quel ORDRE agir et pourquoi.** Ce qu'il faut *saisir* dans chaque formulaire
de la console vit dans `playstore.md` (fiche, Data Safety, IARC, identifiants produits) ; le registre
RGPD vit dans `legal/dpa.md` ; la doctrine produit dans `readme.md` §14 ; les arbitrages commerciaux
dans `strategie.md` et `revenus.md`. Les deux documents se lisent ensemble : celui-ci renvoie à
`playstore.md` à chaque fois qu'il faut remplir quelque chose.

---

## vocabulaire — quatre choses différentes

À lire une fois, elles sont **indépendantes** les unes des autres et leur confusion est la première
source d'erreur sur ce parcours.

| Notion | Ce que c'est | Où ça se règle |
|---|---|---|
| **Piste interne** | Canal de distribution, ≤ 100 testeurs. Sert à valider le build sur un vrai téléphone. | Play Console → Tests → Tests internes |
| **Piste fermée** | Canal de distribution pour les 12+ familles. C'est **elle seule** qui fait courir les 14 jours vers l'accès production. | Play Console → Tests → Tests fermés |
| **Testeurs sous licence** | Propriété de **comptes Google**, pas d'une piste. Leurs achats sont **réels côté Play mais gratuits**, avec des cartes de test. C'est ce qui permet d'éprouver la vraie facturation. | Play Console → Paramètres → Test de licence (le build t'y emmène) |
| **Banc d'essai (`test_mode`)** | Mécanisme **interne à ddust**. Fabrique des états d'abonnement en mémoire, **sans jamais parler à Play**. Ne teste pas la facturation, seulement l'affichage et les enchaînements. | Layer du bucket, `store-base-global.yml` |

⚠️ « Testeur sous licence » teste la **vraie** facturation sans payer. Le « banc d'essai » ne teste
**aucune** facturation. Les deux ne se remplacent pas.

Deux examens Google portent aussi le même nom :

| Examen | Quand | Ce qu'il regarde |
|---|---|---|
| **Première release** | ✅ passé le 2026-08-21 | Contrôle technique léger. Ni DPA, ni fiche complète, ni comptes de revue. |
| **Accès production** | Plus tard, **déclenché par toi** | Fiche complète, Data Safety, IARC, comptes de test, retours du test fermé. |

---

## les étapes qui restent

Liste **stable et ordonnée**. Les numéros de section plus bas (`0.x`, `2.x`, `5.x`…) restent la
référence de détail, mais c'est **cette liste** qui dit quoi faire et dans quel ordre.

| # | Étape | Qui | Détail |
|---|---|---|---|
| 1 | Finir la validation sur téléphone : onboarding, push, QR, privacy, suppression de compte | toi | §2.5 |
| 2 | Corriger les 5 points de code qui rendent la monétisation testable (audit n° 1 à 5) | dev | § audit |
| 3 | Passer `test_mode` à `false` dans `store-base-global.yml` | dev | §3.1 bis |
| 4 | Corriger les 18 liens légaux périmés du site (CGU EU v5→v6, US v3→v4) | dev | — |
| 5 | Reconstruire, uploader, republier bucket et hosting — **un seul build porte les étapes 2 à 4** | toi | §2.1 |
| 6 | Promouvoir en piste fermée, ouvrir les inscriptions — **le compteur des 14 jours démarre** | toi | §3.2 |
| 7 | Recruter jusqu'à 18-20 testeurs | toi | §3.1, §3.3 |
| 8 | Lier Play Console ↔ GCP et inviter `deva-store@dvddust` | toi | §0.5 |
| 9 | Créer les 5 abonnements, leurs 10 base plans et les 2 offres — **identifiants définitifs** | toi | §4.1 |
| 10 | Renseigner le sujet RTDN `projects/dvddust/topics/eu-play-rtdn` | toi | §4.2 |
| 11 | Renseigner `GRANT_ADMINS` (le cutoff fondateurs, lui, part avec le build) | toi | §0.7 |
| 12 | Déclarer `daddy.ddust` et `kiddy.ddust` comme testeurs sous licence — **le build te guide** | toi | §5.1 |
| 13 | Dérouler la recette de la monétisation | toi + dev | §5 |
| 14 | Corriger les points de code restants (audit n° 6, 7, 8, 11, 12, 13) | dev | § audit |
| 15 | Compléter la fiche Play : Data Safety, IARC, public cible, App access — **feuille : `saisie_playstore.md`**, assets rassemblés par le build dans `stores/google/assets/` | toi | §2.2 |
| 16 | Mener l'AIPD et faire relire CGU + politique de confidentialité | toi | §6.1 |
| 17 | À J+14 : demander l'accès à la production | toi | §3.4 |
| 18 | Déployer en production par paliers progressifs | toi | §6.3 |

**⚠️ Chaîne ajoutée le 2026-09-03 — l'immatriculation en a ouvert une seconde, parallèle.** Elle ne
s'intercale pas dans la liste ci-dessus : elle court **à côté**, et les étapes 17-18 ne peuvent pas
tomber avant qu'elle soit finie. Ses six maillons sont surtout des attentes, d'où l'urgence du
premier.

| # | Étape | Qui | Détail |
|---|---|---|---|
| A | **Demander le D-U-N-S** chez Altares — nom et adresse **exactement** ceux du RNE | toi | ⚠️ **aujourd'hui.** 5 à 30 jours ouvrés, chemin critique |
| B | Ouvrir le compte bancaire pro — titulaire **sans trait d'union** | toi | plan §2.3 |
| C | Demander le n° de TVA intracom au SIE, migrer la facturation Cloud | toi | plan §2.1-2.2 |
| D | Créer le profil de paiement **organisation**, le faire vérifier | toi | §0.2. Attend A et B |
| E | **Convertir le compte** en organisation, puis attendre **72 h** | toi | §0.2. Attend D |
| F | Fixer le nouveau package, **créer l'entrée d'app neuve**, refaire le SHA-1 | toi + dev | §0.1, §2.2. Attend E |

**Ce que F entraîne côté conf**, et qui n'est pas un détail de saisie : nouveau package dans
`backend/config.yml` et dans le `PACKAGE_NAME` des trois Cloud Functions du store, `unprotect` de
l'`AndroidApp` Firebase, nouveau SHA-1 mesuré sur le binaire installé, second client OAuth
redéployé, et **recréation des cinq abonnements avec leurs base plans et leurs offres** — les
produits sont attachés à l'entrée d'app, pas au compte.

**Groupements.** Les étapes 2 à 4 partent dans **un seul build** (étape 5). Les étapes 6 et 7 lancent
un compteur de 14 jours pendant lequel tout le reste avance — pousser une mise à jour sur la piste
fermée ne réinitialise rien. Les étapes 8 à 13 forment une chaîne, chacune conditionne la suivante.

**Hors liste, parce que hors chaîne.** Deux démarches de niveau **compte** ne figurent pas ci-dessus :
la **déclaration de statut de vendeur (DSA)** et l'inscription au **programme de frais de service
réduits**. Elles ne dépendent de rien et rien n'en dépend — deux minutes chacune, à n'importe quel
moment, sans attendre un build ni une fiche. Les numéroter laisserait croire qu'elles bloquent une
suite. Détail : `compte.md` ; enjeux : §0.2 ter et §0.3.

⚠️ **Pourquoi l'étape 3 impose un rebuild.** Le layer `store-base-global.yml` est publié au bucket
**et embarqué dans l'AAB** comme repli de premier lancement. Republier le bucket suffit aux appareils
déjà installés, mais une installation neuve afficherait brièvement le banc avant le téléchargement du
layer.

---

## chemin critique

> ⚠️ **LE CHEMIN CRITIQUE A CHANGÉ DE MAIN LE 2026-09-02.** Le poste qui commandait tout était le
> **profil de paiement Play** ; il est vérifié depuis le 2026-08-20 et le compte est activé. C'est
> désormais le **D-U-N-S** — 5 à 30 jours ouvrés chez Altares, un délai que personne ne maîtrise —
> parce que rien ne se publie sans compte organisation, et qu'aucun compte ne devient organisation
> sans lui. **À lancer aujourd'hui**, avant tout le reste : c'est la seule tâche dont le retard ne se
> rattrape par aucun effort.

Ce qu'il commande, en descendant : D-U-N-S → profil de paiement organisation → conversion du compte
(**+72 h**) → **entrée d'app neuve** → 12 testeurs × 14 jours → production. Six maillons, dont
quatre sont des attentes. Le seul geste qui les raccourcit est de commencer le premier tôt.

**Ce qui n'attend pas et doit avancer en parallèle** : build, fiche, correctifs de code, recette de
la monétisation, AIPD et relecture juridique — tout cela se fait sur l'**entrée existante**, qui
reste le bac à sable technique. Rien n'y est perdu : seuls le package et l'AAB changent à la fin.

⚠️ **Le piège d'ordonnancement est de créer l'entrée neuve trop tôt.** Créée avant que le compte
n'affiche « organisation », elle hérite des 12 × 14 et coûte deux semaines pour rien (§0.1).

Le second poste par la durée est le **test fermé** : 14 jours calendaires incompressibles. ⚠️ Il ne
comptera que s'il court sur l'**entrée neuve** : un test fermé mené sur l'entrée actuelle ne
s'y reporte pas. Il n'exige pas que la monétisation fonctionne — un build en piste fermée suffit.

```
S0   profil de paiement ─────────────────────────────────┐ (vérifications : plusieurs jours)
     OAuth prod, liaisons, compte de test                │
     redéploiement backend + hosting                     │
S1   AAB → fiche → piste interne → SHA-1 → redéploiement │
     phase 3 bis (correctifs)                            │
S2   piste fermée ── chrono 14 j ──────────────┐         │
     phase 3 bis (suite)                       │         │
S3   produits + RTDN en console ←──────────────┼─────────┘
     recette monétisation                      │
S4   correctifs de recette                     │
     AIPD + relecture juridique                │
     demande d'accès production ←──────────────┘
S5-6 déploiement progressif
```

⚠️ **La cible de « début octobre 2026 » qui figurait ici est retirée** : elle datait d'avant
l'immatriculation et ne tenait aucun des quatre délais ci-dessus. La date de publication se lit
du mécanisme de roadmap, pas de ce document — une échéance recopiée à la main dans un document
de procédure vieillit sans prévenir. La communication publique du site annonce « automne 2026 »,
formulation qui reste tenable.

---

## état au 2026-08-21

**Prêt** : version `1.0.0+1`, icône 512×512, feature graphic 1024×500, captures d'écran, descriptions
fr/en/es rédigées, corpus légal versionné (CGU EU v5 / US v3, privacy EU v3 / US v2 × adulte/mineur ×
3 langues), flux d'acceptation avec porte parentale, suppression de compte web et in-app, conformité
Families appliquée par le builder et vérifiée au manifeste, pipeline de signature release avec
keystore persisté en Firestore, site vitrine trilingue.

**Fait, et confirmé le 2026-08-21 :**

| Élément | État |
|---|---|
| Compte développeur | ✅ en place |
| §0.2 — profil de paiement | ✅ créé, compte bancaire validé, fiscal US + Taïwan renseignés, **compte activé** |
| §0.4 — écran de consentement OAuth → « En production » | ✅ fait |
| §0.6 — comptes de test | ✅ `daddy.ddust@gmail.com` et `kiddy.ddust@gmail.com` — un adulte et un mineur, la revue Play peut éprouver les deux rôles. À déclarer **aussi** comme testeurs sous licence (étape 12) |
| §2.2 — app créée en console | ✅ `com.grisloup.ddust_client`, sans frais, fr-FR. ⚠️ **Bac à sable désormais** : l'entrée de lancement sera neuve, sous un autre package (§0.1, §2.2) |
| §2.3 — AAB uploadé, examen de première release | ✅ passé, piste interne |
| §2.4 — SHA-1 de signature Play | ✅ `33:1E:56:BC:…`, **mesuré sur l'APK réel**, enregistré dans Firebase et dans `conf.oauth.android.play_sha1s.client` |
| **Connexion Google depuis le Store** | ✅ **fonctionne** |
| Étape 7 — recrutement des testeurs | 🔄 en cours |

**Restent à confirmer** (invisibles depuis le dépôt) : fiche Play remplie · Play Console ↔ GCP liés
et compte de service invité · produits créés · déclaration vendeur DSA (`compte.md`) · programme de
frais réduits (`compte.md`) · `GRANT_ADMINS`.

**État vérifié de la configuration, 2026-08-21 :**

| Élément | Fait |
|---|---|
| Version | **1.0.2+3**, AAB livré le 2026-08-21 à 16:09 |
| Documents légaux servis | CGU EU adulte **v6**, US adulte **v4** — aucune version codée en dur, l'app suit l'index |
| ⚠️ Site vitrine | **en retard d'une version** : CGU EU v5 au lieu de v6, US v3 au lieu de v4 → **18 liens périmés** sur 3 pages (étape 4) |
| ⚠️ `test_mode` | **`true`**, embarqué tel quel dans l'AAB livré. Un seul fichier source, pas de variante prod/dev, pas de garde `kReleaseMode` : bascule **manuelle** (étape 3) |
| `simulate_state` | vide dans le binaire livré |
| Écrans de boutique | 5, tous routés : `shop`, `store_product_page`, `locked_page`, `store_scenario_page`, **`tiers_page`** (choix de palier, ouvert par le plafond atteint) |
| Catalogue | 5 abonnements, 10 base plans, 2 offres. **Aucun produit à l'unité** — volontairement absents au lancement |
| `GRANT_ADMINS` | **vide** → `store_grant` fermée à tous, aucun crédit accordable (étape 11) |
| Calendrier de défaut | `grace_days: 10`, `locked_day: 50`, **`purge_day: 730`**, phase `farewell` 700-730 |
| ⚠️ Git | 6 fichiers de conf **non commités** — l'AAB livré ne correspond à aucun commit |

**Monétisation** : écrite en entier, **jamais exercée contre le vrai Play Billing**. Audit du
2026-08-21 sur les 13 correctifs : **1 fait, 3 partiels, 9 non faits**.

⚠️ **Effet en cascade à connaître** : le point 1 (publication de l'entitlement) neutralise le
point 10 (plafonds). `_publish()` est le seul écrivain de `store.grants.*` ; un clan sans document
`clans_store` n'a donc aucun plafond publié, `_storeMaxPlayers()` rend −1 = illimité, et le contrôle
sort immédiatement. **Les plafonds de joueurs ne s'appliquent aujourd'hui à personne.**

**Grille à cinq paliers** (livrée) : 1,99 € à 7,99 €, plafonds 2 / 4 / 7 / 12 / illimité, un seul
compteur `max_players`, et le choix du palier sorti de la boutique vers `tiers_page`, déclenché par
le plafond atteint. Les quatre chemins d'ajout de membre sont bien gardés ; l'absence de contrôle sur
le passage à l'âge adulte est délibérée et correcte, un compteur unique ne déplaçant plus de place.

**Décision de conception à acter** : `_checkStoreAccess` a été remplacé par `_storeLocked()`, et la
doctrine est désormais explicite dans `worker_screen_tiroir.dart:68-82` — **aucune porte fermée avant
le J50**. Ni la fin de l'essai ni un impayé en cours ne barrent quoi que ce soit : la boutique porte
l'offre, le bandeau prévient, et la seule porte qui se ferme le fait au terme de 50 jours de
relances, pour une raison de coût d'infrastructure et non de sanction. C'est cohérent avec
`strategie.md` et avec le refus des écrans bloquants. **Conséquence à assumer : entre le premier jour
et le J50, un clan qui ne paie pas joue normalement.**

---

## phase 0 — administratif

Rien ici ne dépend du code. Tout est à faire en console, et tout peut démarrer aujourd'hui.

### 0.1 — 12 testeurs × 14 jours : l'exemption suit l'ENTRÉE D'APP, pas le compte

**Corrigé le 2026-09-03, et c'est le fait qui commande toute la phase 4.** Une version antérieure de
cette section raisonnait sur l'**âge du compte** — « les comptes personnels créés après le
13 novembre 2023 » — et en déduisait qu'une conversion en compte organisation lèverait l'exigence.
Elle ne la lève pas.

> ## ➜ L'exigence est attachée à **l'entrée d'app**, pas au compte
>
> Une app **créée sous un compte personnel** conserve l'exigence **après** la conversion du compte
> en organisation. Une app **créée après** la conversion, sous un compte déjà organisation, en est
> exemptée.

**Conséquence directe : il faut une entrée d'app NEUVE**, donc un nouveau nom de package, créée
**après** la conversion. `com.grisloup.ddust_client` a déjà reçu un AAB et un examen de première
release : quoi qu'il advienne du compte, cette entrée-là garde les 12 × 14. Le geste et ses deux
obstacles techniques sont en §2.2 ; l'arbitrage, dans
`grisloup/docs/plan-creation-micro-entreprise.md` §0.3.

En une phrase : **on garde le compte, on repart de zéro sur l'app.**

**Confirmation définitive**, quel que soit le raisonnement : une fois l'app créée, le tableau de
bord de la Play Console affiche — ou n'affiche pas — l'exigence de test fermé. C'est la seule source
qui fasse foi, et c'est elle qu'on regarde juste après avoir créé l'entrée neuve.

⚠ **Ne pas supprimer l'app existante.** Elle reste le bac à sable technique — recrutement des
testeurs, SHA-1, banc d'essai — jusqu'à ce que la nouvelle entrée soit vivante. Les familles
testeuses **sont déjà prévenues** que le lancement se fera sur une entrée différente, avec
désinstallation et réinstallation : le coût social est réglé (2026-08-28).

Tant que l'entrée neuve n'existe pas, le présent document suppose que la règle s'applique — et elle
s'appliquera aussi à l'entrée neuve si la conversion n'est pas faite avant sa création. **L'ordre est
la substance de la phase 4 : convertir, PUIS créer.**

### 0.2 — profil de paiement Play ⚠️ LE POSTE BLOQUANT

> ## ⚠️ SECTION RETOURNÉE LE 2026-09-03 — ON PASSE EN **ORGANISATION**
>
> Tout ce qui suivait recommandait le profil **Particulier**, et le recommandait bien : c'était le
> choix réversible tant qu'aucune structure n'existait. **Une structure existe depuis le
> 2026-09-02** — entreprise individuelle, SIREN `109354092`, domiciliée 20 rue Lavoisier à Pontoise.
> L'arbitrage du §6.1 est donc tranché **dans l'autre sens**, et il l'est *avant* le passage en
> production, exactement là où cette section demandait qu'il le soit.
>
> Ce qui a changé n'est pas l'analyse mais le fait : le seul défaut du compte organisation était
> d'exiger une entité et un D-U-N-S. Son seul avantage — **publier une domiciliation au lieu d'un
> domicile** — est devenu le motif central de toute la démarche.

**Ce qui est déjà fait, et qu'on ne refait pas** : un profil **Particulier** existe, vérifié le
2026-08-20 (identité + compte bancaire), et le compte est **activé**. Il a rempli son office : il a
permis de créer l'app, d'uploader un AAB, de passer l'examen de première release et de valider la
connexion Google depuis le Store. Il n'est pas à défaire.

**Ce qui reste à faire, dans cet ordre — c'est la phase 4 du plan de création :**

| # | Geste | Attend |
|---|---|---|
| 1 | **D-U-N-S** chez Altares, gratuit | le SIREN ✅. **5 à 30 jours ouvrés — le chemin critique** |
| 2 | Compte bancaire professionnel, titulaire **sans trait d'union** | le SIREN ✅ |
| 3 | **Nouveau** profil de paiement, de type **Organisation** | 1 et 2 |
| 4 | Vérification identité + bancaire de ce nouveau profil | 3 |
| 5 | **Convertir le compte développeur** — *Compte développeur → À propos de vous → Modifier le type de compte* | 4, puis **72 h d'attente** |
| 6 | **Entrée d'app neuve** (§0.1, §2.2) | le compte affiché « organisation » |

⚠️ **Le compte se convertit, le profil de paiement NON.** C'est le point qui surprend : la
conversion préserve le compte, l'adresse Google, les 25 $, l'historique et les informations fiscales
déjà déposées — mais il faut créer un **second** profil de paiement, de type organisation, le faire
vérifier, puis le lier. Le profil Particulier ne se transforme pas.

⚠️ **La conversion est à sens unique.** Organisation → particulier est **impossible** et imposerait
d'ouvrir un compte développeur neuf, donc de tout republier. Une fois la phase engagée, on ne revient
pas en arrière. C'est acté.

**Temps 1 — créer le profil de paiement de type Organisation.**
*Play Console → Configuration → Informations de paiement → Créer un profil de paiement.*

⚠️ **Si la console propose de choisir parmi des profils existants** — elle le fait dès qu'un profil
de paiement Google existe déjà sur le compte — **créer un profil neuf, ne réutiliser ni le
Particulier de Play ni celui de Cloud.**

| Profil proposé | Verdict |
|---|---|
| **Créer un nouveau profil, type Organisation** | ✅ **celui-ci.** C'est le seul chemin vers un compte organisation, et le seul qui accepte une adresse de domiciliation |
| *Particulier*, au nom civil (« Profil Particulier pour Play ») | ❌ **plus celui-ci.** Il reste en place et continue de servir l'ancienne entrée d'app ; il ne peut pas devenir organisation |
| *Organisation*, « pour Cloud » | ❌ profil de **facturation**, pas de versement. La facturation Cloud se migre à part (plan §2.2) |

Avant de valider, les trois lignes qui font échouer une vérification organisation :

| Champ | Valeur | Le piège |
|---|---|---|
| Nom légal | `MARCHAL DE GREEF Guillaume` | ⚠ **Règle de nommage**, tenue sur tous les fronts : ordre du registre, **sans trait d'union** (forme du RNE, pas de la carte), **sans « EI »**, sans second prénom. Google confronte ce champ à l'extrait d'immatriculation |
| Adresse | `20 rue Lavoisier, 95300 Pontoise` | La **domiciliation**. Google la refusait sur un compte personnel ; sur une organisation, c'est la valeur attendue |
| Numéro d'immatriculation | SIREN `109354092` | Neuf chiffres, sans espaces. Le SIRET n'est pas demandé ici |
| D-U-N-S | *(en attente)* | Déclaré au **même nom et à la même adresse**, caractère pour caractère. C'est le recoupement que Google fait |

⚠️ **Le titulaire du compte bancaire est confronté au nom du profil.** Demander à la banque
d'enregistrer le titulaire **sans trait d'union**, à l'ouverture et pas après. Un compte ouvert à la
forme de la carte d'identité produirait un échec de vérification pour un caractère.

⚠️ **La pièce que Google réclamera est l'extrait d'immatriculation délivré par le greffe**, pas le
contrat de domiciliation. L'activité ayant été déclarée commerciale, cet extrait existe — c'est un
bénéfice direct du choix « commerciale » à l'immatriculation.

**Écran « Profil public de marchand » — le vocabulaire trompe.** Google parle d'« informations
publiques de l'**entreprise** » pour tous les vendeurs, y compris les personnes physiques : il n'y a
pas de variante « particulier ». Remplir ce formulaire ne crée aucune structure.

| Champ | Quoi mettre |
|---|---|
| Case « utiliser le nom, les coordonnées et l'adresse comme informations juridiques » | Cochée — ce qui est saisi ici fait office d'information **juridique** |
| **Nom de l'entreprise** | La **dénomination au RNE**, pas le nom commercial. Une entreprise individuelle n'est pas une personne morale séparée : son identité juridique reste celle de la personne physique. Y déclarer « Grisloup » crée un écart avec l'extrait d'immatriculation (cause classique de blocage) et avec `dpa.md` §3 |
| Site Web (facultatif) | `https://donjons.grisloup.com` — à renseigner, cela facilite la vérification |
| Produits ou services vendus | La catégorie *logiciels / applications* (ou divertissement selon la liste) — sert au profilage de risque, pas à la fiscalité |

⚠️ Le nom commercial n'est pas perdu : le **nom du développeur** affiché sur la fiche Play est un
champ distinct, réglé dans les paramètres du compte. C'est là que « Grisloup » a sa place. Cet
écran-ci relève du paiement et du juridique, pas de la vitrine.

À préparer **avant** de commencer la saisie. Toutes ces valeurs viennent de `build/build.yml`, bloc
`publisher:`, et sont restituées telles quelles dans **`saisie_compte.md`** — ne rien réinventer au
clavier :

| Élément | Valeur pour ce projet |
|---|---|
| Type de profil | **Organisation** — décidé le 2026-09-03, l'entreprise existant depuis la veille |
| Nom légal | `MARCHAL DE GREEF Guillaume` — ordre du registre, sans trait d'union, sans « EI » |
| Adresse légale | `20 rue Lavoisier, 95300 Pontoise, France` — la **domiciliation**, qui est l'adresse de l'entreprise au registre |
| Numéro d'immatriculation | SIREN `109354092` |
| D-U-N-S | *(en attente d'Altares — chemin critique)* |
| Téléphone | `+33 7 44 47 09 44` — celui de la **structure**, pas le mobile personnel |
| Contact | Nom du représentant + e-mail |
| E-mail d'assistance public | `donjons@grisloup.com` |
| Site web | `https://donjons.grisloup.com` |
| Catégorie de produits vendus | Applications / divertissement familial |
| Informations fiscales | Taïwan et États-Unis uniquement (§0.2 bis) — déjà déposées sur le compte, la conversion ne les redemande pas |

✅ **L'adresse publiée est désormais une domiciliation — le verrou est levé, pas reporté.**
Pour un compte **organisation**, nom, **adresse complète** et téléphone sont affichés sur la fiche
dans l'EEE, et ils le sont **même sans monétisation**. C'est sans conséquence : ce sont ceux de
l'entreprise. C'était le verrou de tout le dossier, et c'est ce qu'a acheté l'immatriculation.

Ce qu'il faut avoir compris pour ne pas défaire ce résultat :

- Google **refuse une domiciliation sur un compte PERSONNEL** — l'adresse doit y être la résidence
  réelle, justificatif à l'appui. Seul un compte organisation l'accepte. **Saisir la domiciliation
  avant la conversion fait échouer la vérification** ; saisir le domicile après la conversion
  republie ce qu'on venait d'écarter.
- Aucun réglage ne masque ces informations : ce n'est pas une option Play mais une obligation
  européenne répercutée. Il n'y a donc rien à négocier, seulement une bonne adresse à déclarer.
- Les contournements lus ailleurs — adresse d'un proche, résidence secondaire, coworking délivrant
  une attestation — restent à écarter : l'adresse doit être l'adresse **légale**, celle du registre.
  Une domiciliation agréée en est une ; les trois autres, non.

⚠️ **Avant la première publication : ouvrir la fiche publique et vérifier qu'aucune trace de
l'adresse personnelle n'y figure.** C'est la seule porte qu'on ne peut pas refermer.

**Temps 2 — ajouter le compte bancaire**, une fois le profil enregistré.
*<https://play.google.com/console> → Paramètres → rubrique **Monétisation** → Profil de paiement
(ancien libellé : « Paramètres de paiement ») → section « Mode de paiement » → Sélectionner un
mode de paiement → Ajouter un mode de paiement.*

⚠️ **Vérifier le bon compte Google.** Avec plusieurs comptes connectés, Play Console ouvre celui
d'indice 0 par défaut ; forcer le bon avec `https://play.google.com/console/u/1/` (ou l'indice qui
convient), sinon l'écran paraît vide ou amputé sans aucun message d'erreur.

Google redemande une **authentification** à l'ouverture de ce formulaire : c'est normal, ce
n'est pas un écran parasite. Champs attendus :

- **Titulaire** — écrit **exactement comme sur le relevé bancaire** (60 caractères max), et
  identique au nom légal du profil.
- **Type de compte** — courant / épargne / professionnel.
- **IBAN**, **BIC/SWIFT**, nom de la banque (70 caractères max).
- **Domiciliation** — le compte doit être dans le pays du profil de paiement ; pour l'EEE,
  n'importe quel compte **SEPA** de la zone convient.

⚠️ **Ce n'est ni sur `myaccount.google.com`, ni dans « Wallet et abonnements ».** Ces
écrans-là gèrent les moyens de paiement pour **acheter**, pas le compte sur lequel Google
**verse** les revenus. Le RIB de versement ne vit que dans les paramètres de paiement de la
Play Console. Le profil de paiement lui-même (identité, adresse, documents fiscaux) se gère
aussi depuis le centre marchand <https://pay.google.com/business/console>, à ne confondre ni
avec `myaccount.google.com` ni avec `pay.google.com`.

**Deux vérifications ensuite, indépendantes et parallèles :**

1. **Identité** — pièce d'identité en cours de validité, parfois complétée d'un justificatif de
   domicile. La lancer **immédiatement**, sans attendre la relance de Google.
2. **Compte bancaire** — après le temps 2, Google verse un **petit dépôt de contrôle** dont il faut
   reporter le montant dans la console. La notification arrive sous environ **72 h**, et il faut
   compter **jusqu'à 3 jours ouvrés** pour que la banque le passe. Si le dépôt ne
   peut pas être émis, la vérification bascule sur l'**envoi de documents bancaires officiels**,
   avec un délai d'environ **5 jours**.
   → Surveiller le relevé pendant cette fenêtre : le montant est de quelques centimes et passe
   facilement inaperçu.

⚠️ **Ce n'est pas une formalité.** Google indique que les développeurs dont le compte bancaire reste
non vérifié voient leur présence développeur **et leurs applications retirées** de Google Play.

⚠️ **Cohérence d'identité sur cinq points.** Le titulaire du profil de paiement doit coïncider avec
la facturation GCP, l'éditeur déclaré dans les CGU, la mention « éditeur » du site et le responsable
de traitement de `dpa.md` §3. Un écart bloque la validation ou fragilise le dossier RGPD. **Les cinq
bougent ensemble ou pas du tout** — c'est pour cela qu'ils sont listés ici plutôt que traités chacun
dans sa section.

État au **2026-09-03**, l'identité étant désormais connue :

| # | Point | État |
|---|---|---|
| 1 | **Profil de paiement Play** | ⏳ attend la conversion en organisation (§0.2). Le profil Particulier vérifié le 2026-08-20 reste en place jusque-là |
| 2 | **Facturation Google Cloud** | ⏳ nouveau compte de facturation au nom de l'entreprise, avec SIRET et n° de TVA intracom — plan §2.2. ⚠️ À caler au plus près du SIRET : avant, les dépenses d'inférence sont personnelles ; après, elles sont celles de l'activité |
| 3 | **Éditeur déclaré dans les CGU** | ✅ 72 documents adultes, 12 marchés × 3 langues — `tools/set_publisher_siren.py` |
| 4 | **Mention « éditeur » du site** | ✅ les 3 pages légales, avec directeur de publication |
| 5 | **Responsable de traitement, `dpa.md` §3** | ✅ qualification, SIREN, domiciliation |

**Source unique des cinq : `build/build.yml`, bloc `publisher:`.** Il porte la dénomination au RNE,
l'adresse de domiciliation, le SIREN et le téléphone de la structure ; `saisie_compte.md` en est
rendu au build. Corriger la console sans corriger `build.yml` fait revenir l'écart au build suivant.

⚠️ **Il ne manque plus qu'une chose : le n° de TVA intracommunautaire**, à demander au SIE, et il
n'est bloquant que pour la **facturation Google Cloud** — pas pour le corpus, qui n'a pas à porter un
numéro de TVA que l'entreprise ne facture pas. Suivi au §5.2 de
`grisloup/docs/plan-creation-micro-entreprise.md`.

Relevés le 2026-09-03 et désormais dans `build.yml` : **SIRET `10935409200016`**, **APE `58.29C`**
(`58.29Y` en NAF 2025). La mention **RCS Pontoise** est posée dans le corpus : c'est elle que
R123-237 exige d'un commerçant, le SIREN seul étant une mention incomplète.

**Et la SASU ?** Elle est **sortie du plan** (2026-08-28). Le portefeuille est publié sous une
**micro-entreprise**, sans bascule programmée : ~970 €/an de régime contre ~2 200 € en SASU
minimaliste, ni bilan ni liasse — et le seul avantage que la société conservait, publier une adresse
qui n'est pas le domicile, est atteint sans elle. Le dossier ne se rouvrirait que sur un signal
précis (plafond du régime approché, besoin d'accumuler plutôt que de distribuer, client exigeant une
entité) ; le premier atteint rouvre la question, il ne la tranche pas. Cf. `grisloup/docs/vision.md`.

Le **déclencheur** de la conversion du compte n'a jamais été « si les revenus le justifient » mais le
**passage en production** : c'est l'affichage public de l'adresse qui commande, pas le chiffre
d'affaires. Ce déclencheur est **atteint**, et le délai cumulé — D-U-N-S, profil organisation, 72 h —
court à partir d'aujourd'hui. Il est en amont de §6.3, pas au moment de cliquer.

### 0.2 bis — informations fiscales : Taïwan et États-Unis, pas la France

Une fois le compte bancaire validé, le centre de paiement réclame des **informations fiscales** pour
deux juridictions seulement, ce qui surprend. La règle : **Google ne demande des informations que là
où il a lui-même une obligation de retenue à la source** sur ce qu'il te verse.

| Juridiction | Pourquoi | Sans le formulaire |
|---|---|---|
| **États-Unis** | Google est une société américaine ; le fisc américain l'oblige à recueillir un certificat de statut étranger de tous ses partenaires non américains | Retenue par défaut sur la part de revenus de source américaine |
| **Taïwan** | La loi taïwanaise oblige Google à retenir sur les paiements liés aux ventes à des utilisateurs taïwanais | **3 % de retenue** sur les transactions taïwanaises, et **5 % de TVA sur la commission** faute de numéro de TVA taïwanais |
| **France** | Rien à collecter : sur les ventes UE, Google est le vendeur au sens fiscal et reverse lui-même la TVA. Cotisations et impôt se règlent directement avec l'URSSAF et l'administration fiscale | — |

⚠️ **Ce que la conversion en compte organisation change ici : rien.** Les informations fiscales sont
attachées au **compte**, pas au profil de paiement, et la conversion les préserve — c'est l'un des
arguments qui ont fait garder le compte plutôt qu'en ouvrir un second. Le formulaire reste un
**W-8BEN** et non un W-8BEN-E : une entreprise individuelle n'est pas une société, le bénéficiaire
effectif reste la personne physique. Il n'y a donc **rien à refaire** après la conversion.

**À remplir :**

- **États-Unis** → **W-8BEN** (personne physique ; le W-8BEN-E est réservé aux sociétés). Prévoir le
  **numéro fiscal français** (13 chiffres, sur l'avis d'imposition) pour le champ « TIN étranger »,
  déclarer la résidence fiscale française et demander le bénéfice de la **convention fiscale
  franco-américaine**. Le nom doit correspondre exactement au profil de paiement.
  - **Étape 3 du formulaire, « Convention fiscale » → répondre OUI.** L'article 12 de la convention
    franco-américaine prévoit que les redevances dont le bénéficiaire effectif réside en France ne
    sont imposables qu'en France : **0 % de retenue américaine**, exonération totale et non simple
    abattement. Répondre « Non » y renoncerait sans contrepartie.
  - L'outil **pré-remplit l'article et le taux** d'après le pays déclaré et refuse les combinaisons
    invalides : il n'y a pas de risque de se tromper d'article, on confirme ce qui est proposé. La
    ligne qui compte pour un développeur d'applications est celle des droits d'auteur / redevances.
  - **Le TIN étranger, c'est le numéro fiscal français** : 13 chiffres, commençant par 0, 1, 2 ou 3,
    en haut à gauche de l'avis d'impôt sur le revenu ou dans l'espace impots.gouv.fr. ⚠️ Ni le numéro
    de sécurité sociale, ni le « numéro d'accès en ligne » à 7 chiffres. Il se saisit à **l'étape 1**
    du formulaire ; tant qu'il manque, l'étape 3 reste bloquée avec un message qui n'indique pas
    clairement qu'il faut revenir en arrière.
  - **Étape « Conditions et tarifs spéciaux » — cocher deux cases sur trois :**

    | Case | Verdict |
    |---|---|
    | Autres royalties liées aux droits d'auteur (Play Pass…) | ✅ la catégorie la plus pertinente pour un développeur d'applications |
    | Revenus de services ou d'autres entreprises (AdSense…) | ✅ plus large que la publicité ; le formulaire invite explicitement à couvrir les revenus futurs |
    | Royalties liées au cinéma et à la télévision | ❌ sans objet, et seule catégorie au taux conventionnel historiquement différent |

    Cocher une case ne crée aucun revenu : on pré-autorise le taux conventionnel au cas où. Pour la
    France ces catégories sont à 0 %, donc couvrir large est sans inconvénient — alors que
    l'inverse en a un : un revenu dans une catégorie non cochée subirait le taux plein.

    > ### ⛔ NE JAMAIS LAISSER LIRE CETTE CASE COMME UNE CLASSIFICATION FISCALE FRANÇAISE
    >
    > La case cochée dit « royalties liées aux droits d'auteur », et l'activité est immatriculée en
    > **BIC prestations de services** — catégorie **commerciale**, APE `58.29C`, division 58
    > « Édition ». Ce n'est pas une contradiction, et c'est l'erreur la plus courante sur le sujet.
    >
    > Une **convention fiscale** répond à *« quel État peut taxer, et à quel taux »*. Le **CGI**
    > répond à *« dans quelle catégorie française »*. Un même flux peut parfaitement être une
    > redevance au sens conventionnel et un produit d'exploitation commerciale au sens interne.
    >
    > La ligne de partage du droit interne est ailleurs : **l'auteur qui *concède* ses droits à un
    > tiers qui les exploite relève du BNC ; l'entreprise qui *exploite elle-même*, de façon
    > répétée, vers un public indéterminé, relève du BIC.** Google distribue et encaisse pour le
    > compte de l'éditeur ; il n'exploite pas l'œuvre en reversant une part de *son* succès.
    >
    > En cas de contrôle, c'est le dossier d'exploitation commerciale qui parle — catalogue, grille
    > tarifaire, CGV, site, feuille de route — **pas la case de ce formulaire**. Raisonnement complet
    > et argument juridique : `grisloup/docs/plan-creation-micro-entreprise.md` §0.1 ; sécurisation
    > par **rescrit** fiscal et social : §2.4 du même plan.
  - **« … a-t-il effectué des services ou des activités pour Google aux États-Unis ? » → NON.** La
    question porte sur le lieu **physique** d'exercice, pas sur l'origine des clients : vendre à des
    utilisateurs américains depuis la France n'est pas y effectuer un service. Répondre « oui » à
    tort qualifierait une part des revenus de source américaine et déclencherait une retenue, voire
    des obligations déclaratives aux États-Unis. La région backend `us-central1` ne change rien —
    héberger chez Google Cloud, c'est consommer un service de Google, pas en rendre un.
- **Taïwan** → déclarer la non-résidence fiscale et l'absence d'établissement. Sans impact financier
  tant que la distribution reste en zone UE.

⚠️ **Remplir les deux, même celle qui semble sans objet** : des informations fiscales incomplètes
peuvent **retarder les versements**.

⚠️ Le W-8BEN ne deviendrait un **W-8BEN-E** que le jour où une **société** existerait. Ce n'est pas
le cas d'une entreprise individuelle, et la SASU est sortie du plan (cf. §6.2).

### 0.2 ter — programme de frais de service réduits

**Écran par écran : `saisie_compte.md`** (feuille générée), raisonnement dans `compte.md`. Ce qui suit
dit pourquoi la démarche compte, pas comment la remplir.

Un bandeau de la Play Console propose de s'inscrire au **palier de frais réduits sur le premier
million de dollars annuels**. **S'inscrire** : c'est gratuit, sans contrepartie, et l'inscription
n'est pas automatique — sans démarche, on reste au taux standard.

Trois gestes : créer un **groupe de comptes**, déclarer les **comptes développeur associés** (aucun
ici), accepter les conditions. Seul engagement dans la durée : déclarer honnêtement tout compte
ouvert plus tard, le plafond se partageant alors sur le groupe.

**Ce que ça protège concrètement.** Les abonnements bénéficient déjà du taux réduit indépendamment
du programme. Ce que l'inscription préserve, ce sont les **achats à l'unité** (packs de contenu et de
thèmes, 1.99–5.99 €), qui partiraient sinon au taux standard des transactions non récurrentes —
c'est la ligne « upside extensions » de `revenus.md`.

⚠️ **`revenus.md:23` suppose déjà l'inscription** : le coefficient net × 0.70 y est posé sur
« store 15 % — abonnements **et développeur < 1 M$/an** ». Ne pas s'inscrire invaliderait
silencieusement une hypothèse figée du modèle.

**Contexte tarifaire en mouvement.** Depuis le **30 juin 2026**, l'EEE est passé à une grille où la
commission se décompose en frais de service **+ 5 % de frais de facturation** avec le paiement Play ;
les transactions récurrentes y sont à 10 % de frais de service, et le palier du premier million
ramène l'ensemble à 10 %. L'ordre de grandeur reste cohérent avec le coefficient du modèle, mais
l'articulation exacte entre l'ancien palier « 15 % » et cette nouvelle grille est trop récente pour
être tenue pour acquise : **confirmer sur les premiers relevés de paiement**, pas avant.

### 0.3 — déclaration « vendeur » (DSA / UE)

Statut à déclarer : **professionnel**. Vendre des abonnements ne laisse aucun arbitrage — déclarer
le contraire en vendant est une violation des règles, sanctionnée par le retrait de l'app.

**Champ par champ, valeurs exactes : `saisie_compte.md`** — feuille générée au build depuis
`build/build.yml`, bloc `publisher:`. Le raisonnement est dans `compte.md`.

⚠️ La démarche **ne pré-empte pas §6.1** : l'affichage public des coordonnées ne commence qu'avec
une fiche publique (cf. 0.2). En piste fermée, rien n'est exposé.

### 0.4 — écran de consentement OAuth → « En production » ⚠️

*Console GCP → API et services → Écran de consentement OAuth.*

**À basculer AVANT d'ouvrir la piste fermée.** Ce sont deux listes de testeurs sans aucun rapport :
celle de la Play Console ouvre l'accès au *téléchargement*, celle de l'écran OAuth ouvre l'accès à la
*connexion Google*. Un testeur Play absent de la seconde se voit refuser le login. Et en statut
« Test », les **jetons de rafraîchissement expirent au bout de 7 jours** : les familles seraient
déconnectées au milieu des 14 jours, ce qui ruinerait le test.

⚠️ **« Production » ici ne publie rien.** Le dialogue annonce que « l'application sera disponible
pour tous les utilisateurs disposant d'un compte Google » : cela signifie seulement que n'importe
quel compte pourra *franchir l'écran de consentement*, au lieu des seuls comptes inscrits en liste
de test. Aucune fiche n'est créée, aucun binaire n'est distribué, rien n'est soumis à une revue. La
diffusion reste **intégralement** commandée par les pistes de la Play Console : le test reste fermé.

Publier est sans risque : le seul scope demandé est `email`, **non sensible**. Le passage en
production est immédiat et **ne déclenche aucun audit** — celui-ci ne concerne que les scopes
sensibles ou restreints. Et l'opération est **réversible** : on peut repasser en « Test ».

Une seconde limite du statut « Test », en plus des jetons à 7 jours : la liste est **plafonnée à
100 comptes**, à saisir un par un — chaque parent et chaque enfant du test fermé.

⚠️ **Le logo est le seul déclencheur de validation ici.** Un logo configuré sur l'écran de
consentement impose une **vérification de marque** (2-3 jours ouvrés) — pas la lourde vérification
OAuth, et non bloquante : la connexion continue de fonctionner, seuls le nom et le logo ne
s'affichent pas tant qu'elle court. La marque OAuth n'est **pas** gérée par le builder : c'est ce
qui a été saisi à la main dans la console. Vérifier de même que le nom de l'app et les domaines
autorisés sont propres, et **rester en « Externe »** — « Interne » réserverait la connexion aux
membres d'une organisation Google Workspace, qui n'existe pas ici.

### 0.5 — lier la Play Console au projet GCP

*Play Console → Configuration → Accès à l'API* → projet `dvddust`.

Puis inviter le compte de service créé par `pustore` (`deva-store@dvddust`) dans *Utilisateurs et
autorisations*, avec les droits :
- **Afficher les données financières**
- **Gérer les commandes et abonnements**

Sans cela, `store_verify` ne peut pas interroger `androidpublisher` et **aucun achat ne sera
vérifié** — donc aucun achat ne sera acquitté, et Play remboursera automatiquement.

Vérifier aussi que l'API `androidpublisher.googleapis.com` est activée côté GCP (elle est déclarée
dans `backend/config.yml`, donc posée par le déploiement).

### 0.6 — compte Google de test pour la revue Play

L'app exige une connexion Google : la revue Play **doit** disposer d'un compte fonctionnel, sinon
l'app est rejetée pour « impossible d'accéder au contenu ».

Créer un compte Google dédié, y monter un clan pré-rempli (quelques joueurs, quelques tâches, un
butin en cours) et rédiger des instructions pas à pas. Cela alimente le champ **App access** de
`playstore.md`.

### 0.7 — un réglage à poser à la main

Ni Play ni Pulumi ne peuvent le créer (détail dans `playstore.md` § monétisation) :

- **`GRANT_ADMINS`** dans l'environnement de `store_grant` (`backend/config.yml`) : l'**UID Firebase**
  du compte d'exploitation. Vide = fonction fermée à tout le monde, ce qui est le bon défaut pour une
  fonction qui distribue des mois gratuits. À renseigner avant de compenser la première famille du
  test fermé.
  ⚠️ Bien l'**UID Firebase**, pas le `userId` métier : cette fonction-là compare à `request.auth.uid`.

Le **cutoff fondateurs** figurait ici jusqu'au 2026-08-22 ; il est désormais posé par le build.
`store.play.founder_cutoff` dans `build/build.yml` (**30 septembre 2026 23:59:59 Paris**), et
`pucatalog` écrit `store_config/founders` dans `eu-store` **et** `us-store` — une région sans ce
document ne rend jamais l'offre, et rien ne le signale à l'exécution. Décaler la date, c'est
changer cette ligne de conf et rejouer un build.

---

## phase 1 — redéploiement backend et hosting

Le redéploiement porte **trois** lots accumulés :
1. les documents légaux corrigés (CGU v5 / privacy v3 servis par `pudocuments`) ;
2. le site vitrine corrigé (liens de versions, « 14 jours », badges de sortie, press kit) ;
3. **l'infra de monétisation `pustore`** et les correctifs du 2026-08-19.

À lancer par toi (`builder.py`). Vérifier ensuite :

- [ ] Le site sert bien les CGU **v5** (EU) et **v3** (US), et le privacy **v3** / **v2**.
- [ ] Aucune page ne mentionne « 15 jours » d'essai.
- [ ] Dans l'app, l'option « Mes données » ouvre le privacy de la bonne région, langue et version.
- [ ] `https://donjons.grisloup.com/delete-account/` répond et le POST `/api/delete` aboutit.
- [ ] Les trois fonctions `store_*` sont déployées et le topic `eu-play-rtdn` existe.

---

## phase 2 — premier AAB, fiche Play, piste interne

### 2.1 — build release

Lancé par toi. Le builder gère seul : keystore récupéré depuis Firestore, `release.jks` +
`key.properties` écrits puis nettoyés après build, patch Gradle avec garde-fou anti-debug, AAB copié
dans `{suite}/builds/`.

⚠️ **`versionCode` est à 1 et n'a jamais été uploadé.** Dès le premier envoi sur une piste, tout build
suivant devra porter un numéro **strictement supérieur** — donc `version=patch` sur les suivants. Un
`versionCode` déjà consommé est refusé par la console, y compris si l'upload précédent a été
supprimé.

### 2.2 — créer l'app et remplir la fiche

> ## ⚠️ L'ENTRÉE D'APP SERA **NEUVE**, ET SON PACKAGE N'EST PAS ENCORE CHOISI
>
> `com.grisloup.ddust_client` a reçu un AAB et passé un examen de première release : sur tout Google
> Play, il est **brûlé définitivement**, y compris si l'app est supprimée. Et comme l'exemption des
> 12 testeurs suit **l'entrée d'app** (§0.1), cette entrée-là gardera les 12 × 14 quoi qu'il arrive
> au compte.
>
> Ce qui suit décrit donc **le geste, pas la valeur** : l'app existante reste le bac à sable
> technique, et une seconde entrée sera créée **après** la conversion du compte en organisation. Le
> nom de package définitif — de la forme `com.grisloup.<app>` — est **à fixer avant la phase 4** :
> `grisloup/docs/plan-creation-micro-entreprise.md` §0.3.

**La création elle-même ne demande aucun binaire** et tient en une boîte de dialogue. Réponses :

| Champ | Valeur | Note |
|---|---|---|
| Nom de l'application | `Donjons & Savons` | modifiable ensuite |
| **Nom du package** | *à fixer — cf. l'encadré ci-dessus* | ⚠️ **irréversible et unique sur tout le Play Store.** Composé par le builder (`org` + projet + `_client`), donc **pas saisi à la main** : c'est la conf qui décide, et la console ne fait que le constater. Cliquer « Vérifier la disponibilité » avant de valider |
| Langue par défaut | **français (France) – fr-FR** | la console propose en-US par défaut : **à changer**. C'est la langue de la fiche principale (`playstore.md` § fiche), en-US et es-ES étant des traductions. Modifiable ensuite |
| Application ou jeu | **Appli** | catégorie *Parentalité* (cf. `playstore.md` § fiche) |
| Gratuite ou payante | **Sans frais** (libellé actuel de la console pour « gratuite ») | Modifiable via *Tarification de l'application* **tant que l'app n'est pas publiée**. À la première publication le choix se verrouille, et seulement dans ce sens : une appli sans frais ne peut plus devenir payante. Bon choix de toute façon — la monétisation passe par l'abonnement in-app |
| Déclarations | règles du programme + lois d'exportation US | à cocher |

**Trois choses que le renommage entraîne, et qu'il vaut mieux avoir vues d'avance :**

1. Le package est câblé dans `backend/config.yml → firebase.android_package` et dans le
   `PACKAGE_NAME` des **trois Cloud Functions** du store. ⚠️ Changer `org` renommerait les **douze**
   projets du portefeuille : le renommage doit être **ciblé sur ddust seul**.
2. `gcp.firebase.AndroidApp` est créée avec **`protect=True`**
   (`deva/pulumi/modules/pufirebase/brick.py:71-79`) : **Pulumi refusera de la remplacer**. Il faut
   une étape délibérée d'`unprotect`, ou accepter une seconde Android app dans le même projet
   Firebase. Sans utilisateurs réels, perdre l'ancienne est sans conséquence — l'obstacle est le
   garde-fou, pas la donnée.
3. Toute la danse **SHA-1** du §2.4 est à refaire : mesurer l'empreinte sur le binaire réellement
   installé, jamais la lire dans la console, puis renseigner `conf.oauth.android.play_sha1s.client`
   et l'empreinte côté Firebase, puis redéployer pour le second client OAuth.

**Juste après la création**, le tableau de bord indique — ou non — l'exigence de test fermé. C'est la
**confirmation définitive** du §0.1, celle qui fait foi. ⚠️ Si l'exigence apparaît sur l'entrée neuve,
c'est que la conversion du compte n'avait pas encore pris : la créer trop tôt coûte deux semaines.

Le remplissage de la fiche (textes, assets, Data Safety, IARC, public cible, App access) vient
ensuite, section par section, depuis `playstore.md`.

Tout le contenu à saisir est dans **`playstore.md`** : nom, descriptions courtes et longues fr/en/es,
catégorie, tags, assets graphiques, réglages, Data Safety, déclarations « Contenu de l'app ».

Points à ne pas expédier :

- **IARC** : déclarer **oui aux achats numériques**. Une déclaration fausse est un motif de retrait.
- **Public cible** : audience mixte (6-8 → 18+) → questionnaire Family Policy. Tout est déjà conforme
  côté technique (pas de pub, pas d'ID publicitaire, analytics désactivés, porte parentale).
- **URL de confidentialité** : `https://donjons.grisloup.com/fr/legal/`.
- **Suppression de compte** : `https://donjons.grisloup.com/delete-account/`.
- **App access** : le compte de test de 0.6 + ses instructions.

### 2.3 — upload en piste interne

S'y ajouter comme testeur, plus un ou deux proches.

⚠️ **La toute première release d'une app neuve EST examinée, même en piste interne.** Compter de
quelques heures à **sept jours** dans le pire cas. Pendant ce temps le bouton d'installation tourne
sans message d'erreur, et la console affiche un **nom temporaire** (le nom de package) avec la
mention `(unreviewed)` — c'est normal, ça dure au plus 48 h.

**Ce n'est PAS l'examen de production.** Cet examen-ci est technique et léger : il ne regarde ni le
DPA, ni la fiche complète, ni les comptes de test pour l'équipe de revue. Une app active en test
interne est même **dispensée de la section Sécurité des données**, et les tests internes ne sont pas
soumis aux examens standards de règles et de sécurité. C'est le bac à sable prévu pour travailler
avant d'avoir tout rempli.

Une fois cette première passée, **les mises à jour suivantes en piste interne sortent
immédiatement, sans examen**.

L'examen qui exige le DPA, la fiche complète, la Data Safety et les comptes de test est celui de la
**demande d'accès à la production** (§3.4) — bien plus tard, et **déclenché par toi**.

### 2.4 — boucler le SHA-1 de signature Play ⚠️ SOUVENT OUBLIÉ

**C'est le piège de la première publication.** Play **re-signe** l'AAB avec sa propre clé : l'app
installée depuis le Store ne porte donc pas l'empreinte de ta clé d'upload, mais celle de Google. Le
client OAuth Android créé au déploiement ne connaît que la première → **la connexion Google échoue
pour toute installation venant du Store**, alors qu'elle fonctionne parfaitement en local.

C'est une dépendance circulaire : l'empreinte n'existe qu'après le premier upload. Donc,
obligatoirement dans cet ordre :

1. Uploader l'AAB (2.3).
2. Installer l'app **depuis la piste**, puis **MESURER l'empreinte du binaire réellement distribué**
   (voir l'encadré ci-dessous — ne pas la lire dans la console).
3. La coller dans `backend/config.yml` → `conf.oauth.android.play_sha1s.client`.
4. Ajouter la **même** empreinte dans Firebase : *Paramètres du projet → Général → Vos applications
   → app Android → Empreintes de certificat SHA*. C'est **cette** liste que lit Firebase
   Authentication, et le builder ne la renseigne pas (`pufirebase` ne manipule aucun SHA-1).
5. Redéployer le backend → un **second client OAuth Android** est créé avec cette empreinte.

⚠️ **Mesurer l'empreinte, ne jamais la lire dans la console.** Vécu le 2026-08-21 : la valeur relevée
dans la Play Console ne correspondait à **aucune** installation. Tout était vert côté consoles —
client OAuth créé, empreinte déclarée dans Firebase, package correct — et l'authentification Google
échouait quand même depuis le Store, avec un message qui accuse le **compte** et non le certificat :

```
GoogleSignInException(code canceled, [16] Account reauth failed)
```

Ce libellé fait perdre des heures : avec les versions récentes de `google_sign_in` (Credential
Manager), une app non reconnue ne produit plus le `DEVELOPER_ERROR` explicite d'autrefois. **Le seul
discriminant fiable est le test APK local contre installation Store** : si l'APK signé localement
s'authentifie et que la version du Store échoue, c'est le certificat, quoi que dise le message.

La seule source de vérité est le binaire installé :

⚠️ **Le package ci-dessous est celui de l'entrée ACTUELLE.** Toute cette danse est à refaire à
l'identique sur l'entrée d'app neuve (§0.1, §2.2), avec son propre package : une empreinte de
signature Play est propre à une entrée d'app, elle ne se reporte pas.

```
adb shell pm path com.grisloup.ddust_client     → repérer le chemin de base.apk
adb pull <chemin>/base.apk store.apk
apksigner verify --print-certs store.apk        → « Signer #1 certificate SHA-1 digest »
```

Outils déjà présents : `deva/binaries/android/platform-tools/adb` et
`deva/binaries/android/build-tools/35.0.0/apksigner.bat`.

⚠️ Utiliser `apksigner`, **pas** `keytool -printcert -jarfile` : ce dernier ne lit que les signatures
v1, absentes des APK modernes, et renvoie une erreur trompeuse.

⚠️ Le **partage interne d'application** signe avec une clé **encore différente**. Un binaire installé
par ce canal ne prouve donc rien sur l'authentification, et exigerait sa propre empreinte.

### 2.5 — validation sur téléphone réel

Depuis la piste interne, pas depuis un build local — c'est tout l'intérêt.

- [ ] Onboarding complet : région → âge → vidéo → CGU → **liaison du compte Google** (c'est ici que
      le correctif SHA-1 se prouve) → nom → clan.
- [ ] Notification push reçue (validation de tâche).
- [ ] Scan du QR d'invitation de clan.
- [ ] Accès au privacy depuis l'app.
- [ ] Suppression de compte, jusqu'au bout.
- [ ] **La boutique affiche des prix venus de Play** et non les `price_hint` du catalogue — preuve
      que le moteur `dvstore` démarre bien (correctif du 2026-08-19).

---

## phase 3 — test fermé 12 × 14

### 3.1 — la règle, exactement

Pour un compte personnel créé après le 13 novembre 2023 : **au moins 12 testeurs inscrits (opt-in)
de façon continue pendant les 14 jours précédant la demande d'accès à la production**.

⚠️ **Il n'y a aucun compteur qui se déclenche et qu'il faudrait tenir.** Rien n'est évalué pendant la
période : la vérification a lieu **au moment où l'on demande l'accès à la production**, en regardant
les 14 jours écoulés. Conséquences rassurantes :

- **On peut recruter progressivement** — pas besoin de 12 personnes le premier jour. Chaque testeur
  fait courir ses propres 14 jours à partir de *sa* date d'inscription.
- La date au plus tôt de dépôt de la demande = **14 jours après l'inscription du douzième** testeur.
- Il n'y a donc aucun risque à ouvrir la piste avec trois inscrits : plus tôt le build est en ligne,
  plus tôt chacun accumule ses jours.

Ce qui compte vraiment :
- Les 14 jours sont **consécutifs par testeur**. Quelqu'un qui se désinscrit puis se réinscrit
  **remet son propre compteur à zéro** — c'est la seule chose qui fasse réellement perdre du temps.
- Le compteur ne doit **jamais** passer sous 12 pendant la fenêtre → viser **18-20 recrues** pour
  absorber les défections.
- Les testeurs doivent **réellement utiliser** l'app : la demande d'accès comporte des questions
  ouvertes sur les retours obtenus, et une réponse creuse fait rejeter la demande.
- Pousser des mises à jour sur la piste **ne réinitialise pas** le chrono. C'est ce qui permet de
  mener les phases 3 bis et 5 en parallèle.

### 3.1 bis — piste interne d'abord, piste fermée ensuite ⚠️

**Séquence retenue le 2026-08-21.** Les deux pistes ne portent pas la même configuration, et c'est
délibéré.

| | Piste **interne** | Piste **fermée** |
|---|---|---|
| Qui | toi seul (+ 1-2 proches) | les familles testeuses |
| Banc d'essai (`test_mode`) | **actif** — c'est là qu'on fait la recette des paiements | **coupé** |
| Ce qu'on y valide | SHA-1, onboarding, notifications, QR, suppression de compte, puis toute la phase 5 | l'usage réel, en famille |

**Pourquoi couper le banc avant la piste fermée.** Le banc de scénarios envoie de **vraies
notifications push d'impayé aux chefs de clan** et écrit dans le journal du clan : un parent testeur
qui tomberait dessus recevrait une relance pour une dette qui n'existe pas. L'accès dépend de
`test_mode`, servi par le **bucket** — donc réglable par piste sans reconstruire, mais aussi
susceptible de rester persisté sur un appareil (cf. défaut n°1 du banc).

C'est également ce qui protège du second défaut connu : un état simulé qui survivrait au redémarrage.

### 3.2 — mise en place

1. Créer la **piste fermée**, y promouvoir le build validé en interne. Première revue Google :
   de quelques heures à quelques jours.
2. Constituer la liste de testeurs. **Utiliser un groupe Google** plutôt qu'une liste d'e-mails :
   ajouter quelqu'un ne demande alors aucune re-soumission.
3. Diffuser le lien d'opt-in et **vérifier que chacun a bien installé** — un opt-in sans installation
   ne sert à rien pour la qualité des retours.

### 3.3 — guide à donner aux familles testeuses

À rédiger et envoyer avec le lien. Doit couvrir :

- **Comptes enfants (Family Link)** : un enfant avec un compte supervisé *peut* utiliser « Se
  connecter avec Google », mais la demande part au parent qui doit l'approuver depuis Family Link
  (ou activer en amont *Paramètres → Contrôles → Applis tierces*). Séquence à expliquer : le parent
  installe et approuve l'app côté enfant → l'enfant se connecte → le parent reçoit la demande → il
  approuve.
- Le fait que **leurs achats seront gratuits** (testeurs sous licence) et qu'ils ne seront donc pas
  débités — et, en contrepartie, comment leur compensation fonctionnera (crédits de mois, cf.
  `strategie.md`).
- Comment remonter un bug.

⚠️ Vérifier dans l'app qu'un **refus** de connexion côté parent affiche un message compréhensible
plutôt qu'un échec silencieux.

### 3.4 — à J+14

*Play Console → Tableau de bord → Demander l'accès à la production.* Répondre honnêtement et en
détail : qui a testé, ce qui a été remonté, ce qui a été corrigé.

---

## phase 3 bis — correctifs de la relecture de code

Une relecture critique de la monétisation (2026-08-19) a produit un inventaire de défauts. Deux ont
été corrigés le jour même ; le reste est ci-dessous, **par ordre de dépendance**.

> **État vérifié dans le code le 2026-08-20 : 2 points clos (9 livré, 10 sans objet), 2 partiels (6 et 12), 9 ouverts.**
> Le travail de la nuit a porté ailleurs — banc d'essai et bandeau de relance (§ plus bas), tous deux
> utiles — mais **les prérequis de la phase 5 ne sont pas remplis**.
>
> | # | Point | État |
> |---|---|---|
> | 1 | Publication inconditionnelle de l'entitlement | ❌ (portée revue à la baisse, voir ci-dessous) |
> | 2 | `store.refresh` à la création du clan | ❌ |
> | 3 | `basePlanFor` égalité stricte | ❌ |
> | 4 | `_selectDetails` échoue au lieu de substituer | ❌ |
> | 5 | Libellés d'échec affichés | ❌ |
> | 6 | Sécuriser `clan_purge` | ⚠️ 1/3 |
> | 7 | Cascade alignée sur `delete_user_data` | ❌ |
> | 8 | Callbacks limités à l'appareil acheteur | ❌ |
> | 9 | Sortie de `locked_page` | ✅ |
> | 10 | Plafonds de membres | ✅ sans objet (grille à un compteur, 2026-08-20) |
> | 11 | Cycle de vie du moteur | ❌ 0/4 |
> | 12 | Robustesse RTDN | ⚠️ 1/3 |
> | 13 | Durcissements | ❌ 0/3 |

### déjà corrigé le 2026-08-19

| Défaut | Correctif |
|---|---|
| `dvstore.invoke()` n'enregistrait que le hook `on_authenticated`, toujours dispatché **avant** que le module ne s'y inscrive (`depends.invoke.cloud` fait attendre le retour de `dvcloud.invoke()`, qui dispatche en son sein). Sur silent sign-in — le lancement ordinaire — le moteur ne démarrait **jamais** : ni prix Play, ni entitlement, ni vigilance, et tout achat sortait en `unavailable` | Appel direct à `_motor.start()` dans `invoke()`, sur le modèle de `dvmessaging` |
| `store_verify` comparait `request.auth.uid` (UID Firebase) à `clans.admins` (userId **métier**) : espaces disjoints, comparaison toujours fausse, **`permission-denied` sur chaque achat**, y compris pour le fondateur du clan. Même écart sur le ciblage des relances de défaut de paiement, qui ne partaient donc jamais | Indirection configurable `IDENTITY_COLLECTION` / `IDENTITY_FIELD` dans `pustore` + `identity_collection` dans le bloc `notify` de `STORE_LIFECYCLE` |

### à faire avant la recette (phase 5)

1. **Publier l'entitlement inconditionnellement.** `_applyEntitlement(null)` sort sans rien publier
   (`dvstore_motor.dart:576`), et `_startReal` ne publie pas non plus en fin de parcours : un clan
   neuf, ou une lecture d'entitlement en échec, laisse le dictionnaire vide.
   ⚠️ **Portée revue à la baisse depuis la suppression du gate** : le « jeu gratuit illimité » n'est
   plus un défaut, c'est le comportement voulu avant J50. Ce qui reste réellement cassé :
   - `_storeMaxPlayers` (`worker_store.dart`, ex-`_storeMaxMembers`) rend **-1 = illimité** quand
     `store.grants.max_players` n'est pas un nombre — l'état exact d'un clan jamais publié. **Les
     plafonds de joueurs ne s'appliquent donc pas**, y compris à un clan abonné, tant que rien n'a
     été publié. La refonte de la grille (2026-08-20) n'y change rien : elle porte le défaut à
     l'identique.
     ⚠️ **Conséquence directe sur la recette** : tant que ce point n'est pas corrigé, la page des
     paliers **ne se déclenchera jamais en conditions réelles**. Elle ne s'éprouve qu'au banc
     d'essai, dont les scénarios posent des grants explicites.
   - Le bandeau de relance ne s'affiche pas au démarrage hors-ligne, alors que la phase persistée
     dit `last` (cf. § bandeau de relance).
   Correctif : `_applyEntitlement(null)` doit poser `state = "none"`, `source = "server"` et publier ;
   `_startReal` doit publier en fin de parcours.
   → Vérifier au passage le **message de paywall d'un clan neuf** : il annonce aujourd'hui que « la
   guilde a mis les aventures en pause », ce qui est faux pour une famille qui n'a pas encore joué,
   et ne dit pas un mot de l'essai gratuit.
2. **Rafraîchir le scope à la création du clan.** Le scope n'existe pas encore quand la session
   démarre ; sans un `store.refresh` une fois `steps.clan.*` posé, le **premier achat de chaque
   nouveau client** échoue en `no_scope`.
3. **Corriger `basePlanFor`** : il ne matche que par suffixe (`endsWith("-$wanted")`), alors que les
   exemples du readme et de `config.yml` déclarent `base_plans: [monthly, yearly]` — avec ces
   valeurs, demander l'annuel souscrit le **mensuel**, sans un mot. Accepter l'égalité stricte et
   aligner les exemples.
4. **Échouer au lieu de substituer** un base plan dans `_selectDetails`. Deux replis achètent
   aujourd'hui un plan différent de celui demandé, dont un totalement muet. Substituer un plan à un
   autre n'est pas un repli acceptable quand il y a de l'argent en jeu : il faut un
   `on_purchase_failed` avec `reason: plan_unavailable`. (Le repli sur les **offres**, lui, est
   légitime : Play ne sert que celles auxquelles le compte est éligible.)
5. **Notifier les échecs d'achat à l'écran.** Les libellés `store_unavailable`, `store_error`,
   `store_pending` existent dans `dvstore/config.yml` et ne sont utilisés nulle part : un achat qui
   échoue est aujourd'hui indiscernable d'un bouton cassé.

### à faire avant la production

6. **Sécuriser `clan_purge`.** `store_verify` efface `default_since` et `locked_at` au retour à bon
   port mais **pas `purge_due`** ; et `clan_purge` sélectionne sur ce seul drapeau. Le balayage tourne
   à 5 h, la purge à 6 h : un clan qui se réabonne entre les deux est **dissous, irréversiblement**.
   Correctif : effacer `purge_due` dans `store_verify`, re-filtrer l'état dans `clan_purge`, et ne
   jamais dissoudre en cascade un clan dont l'abonnement est actif.
7. **Aligner la cascade de `clan_purge` sur `delete_user_data`.** Elle en diverge aujourd'hui
   (mineur multi-clans mal tombstoné, consentement non clos) alors que le commentaire du fichier
   exige une fidélité stricte. Deux implémentations divergentes d'une suppression irréversible sont
   un vrai danger.
8. **Callbacks multi-appareils.** `_storeLeaveAfterPurchase` et `_logStoreEvent` s'exécutent sur
   **tous** les appareils du clan, puisqu'ils sont déclenchés par la vigilance Firestore. Conséquences :
   la tablette d'un enfant en pleine tâche subit un `navigate_back()` quand un parent achète, et un
   achat unique écrit N lignes dans `clans_logs`. Un seul correctif règle les deux : n'agir que si
   *cet* appareil a initié l'achat.
9. **Sortie de `locked_page`.** Après un achat abouti depuis l'écran de clan gelé, la famille
   **retombe sur `locked_page`**, qui n'a ni barre d'appli, ni retour, ni taskbar : elle vient de
   payer et doit tuer l'app. Correctif : `blocking: true` depuis cet écran, ou réévaluation du gate
   dans `on_locked_appear`.
10. ~~**Plafonds de membres contournables.**~~ **SANS OBJET depuis le 2026-08-20** — résolu par
    conception, pas corrigé. Les deux contournements (contrôle effectué avant que le `legal_state`
    du candidat soit connu ; franchissement du plafond adulte par empilement d'états « t ») avaient
    la même cause unique : **deux plafonds distincts**, donc un refus qui dépendait de la nature du
    membre. La grille à cinq paliers ne compte plus qu'un seul chiffre — les membres actifs du clan,
    admins compris — et le contrôle est désormais exact à tous les points d'entrée, y compris quand
    on ignore encore qui frappe à la porte. `promote_adult` ne vérifie plus rien du tout : déclarer
    un mineur majeur ne déplace plus de place.
11. **Cycle de vie du moteur** : remise à zéro de l'état sur changement de scope (sinon les droits
    d'un clan payant fuient vers un clan gratuit), redémarrage de la vigilance après logout/login,
    prise en compte de `DvWatchReason.deleted`, timeout sur l'appel à `store_verify`.
12. **Robustesse backend** : dédupliquer les RTDN **en deux temps** (`processing` → `done`) — la
    déduplication est aujourd'hui posée avant le traitement, donc toute erreur transitoire jette
    l'événement définitivement et un `SUBSCRIPTION_CANCELED` perdu laisse le clan en `active` pour
    toujours ; lire `productType` pour qu'un remboursement de produit à l'unité ne coupe pas
    l'abonnement du clan ; poser `default_since` dans le balayage si l'état est `grace`/`hold` sans
    date, pour que le calendrier démarre même si une RTDN est perdue.
13. **Durcissements** : rendre la date de création du clan non modifiable par le client (le cutoff
    fondateurs est sinon falsifiable) ; refuser `debug.simulate_state` en release et purger un état
    persisté dont `store.source == "simulated"` ; durcir les règles `list` (valider le contenu de
    `userindexes`, ne pas exposer le secret dans l'`ownerId` des `events`).

⚠️ **Sur le point 13, dernier alinéa** : `userindexes` est réinscriptible par son propriétaire sans
validation de contenu, et la règle `list` de `clans_store/{clanId}/events` teste seulement
`clanSecret != null` — condition contrôlée par l'appelant — alors que les documents portent le vrai
secret dans `ownerId`. Le motif existe **7 fois** dans `backend/config.yml` : c'est une faiblesse
préexistante du modèle de sécurité, pas une régression de la monétisation, mais c'est le bon moment
pour la traiter.

---

## banc d'essai et bandeau de relance (ajouts du 2026-08-20)

Deux mécanismes ajoutés depuis la relecture. Tous deux utiles — le premier est même ce qui permet
d'éprouver la monétisation sans compte marchand — mais chacun a des défauts à corriger avant la
production.

### le banc d'essai de scénarios

**Douze** situations commerciales nommées — `reel` (sortie du banc), `jamais_abonne`, `essai`,
`abonne_essentiel`, `abonne_clan`, `abonne_royaume`, `fondateur`, `resilie`, `impaye_doux`,
`impaye_dur`, `clan_gele`, `expire` — déclarées dans
`resources_cloud/general/layers/store-base-global.yml:243-346`, chacune un paquet cohérent
`state` + `tier` + `dunning_phase` + `founder` + `credits`.

**Usage** : kebab de la boutique → « Changer de scénario », visible sous double condition
`store.debug.test_mode == true` **et** administrateur du clan. Le tap traduit le scénario en
`store.debug.simulate_*`, bascule dvstore sur `_startSimulated`, réévalue le bandeau, et peut
envoyer une **vraie** notification push de relance. Sortie du banc = scénario `reel`.

**À corriger :**

1. ⚠️ **Le banc persiste, contrairement à ce qu'annonce son propre commentaire**
   (`worker_store.dart:736` : « il disparaît au redémarrage » — c'est faux). Quitter l'app sur
   « impayé dur » la laisse en mode simulé au lancement suivant : `loadConfig` relit
   `simulate_state` et `start()` repart sur `_startSimulated`. **C'est le principal producteur du
   risque décrit au point 13** — un état fabriqué qui survit sur un build de production.
2. **Aucune garde de build.** La seule protection est `test_mode` servi par le bucket ; une valeur
   `true` déjà persistée sur un appareil rouvre le menu en release. Un `kReleaseMode` coûte une ligne.
3. **Le banc écrit dans les données réelles** : la relance push part à tous les chefs du clan, et
   `_logStoreEvent` alimente `clans_logs`. Sur un clan partagé, une session de test annonce une
   fausse dette à des adultes réels.
4. **L'offre fondateurs n'est pas éprouvable** : aucun scénario ne porte de champ `offer`, et
   `store_scenario_apply` n'écrit jamais `simulate_offer`. Le scénario `fondateur` ne pose que le
   drapeau — pas le chemin d'achat avec offre réservée, qui est pourtant le mécanisme le plus fragile.

### le bandeau de relance (dunning)

Phase calculée **côté serveur** (`pustore` écrit `dunning_phase`, l'efface au retour à bon port),
recopiée par dvstore, affichée en overlay **aux seuls chefs de clan** via `commons/store_dunning`.
Aucun écran bloquant : cohérent avec la doctrine « pas de porte fermée avant J50 ».

**À corriger :**

1. ⚠️ **Le « mémoire seule » n'est pas garanti.** `_applyDunning` écrit
   `registry.commons/store_dunning.shape.visible = true` par `deva_set` sans `store()` — mais la
   persistance deva est **globale** : n'importe quel `Deva.instance.store()` déclenché ailleurs
   (et `_publish` en appelle un à chaque publication) peut flusher cette clef. **Le bandeau rouge
   accusant une famille à jour reste donc possible** — exactement ce que le commentaire dit vouloir
   éviter. C'est le défaut le plus sérieux du lot.
2. Pas de bandeau au démarrage hors-ligne alors que la phase persistée dit `last` : `_restore()`
   recharge la phase mais ne publie pas, et `_evaluateDunning` n'est déclenché que par une
   publication. Même racine que le point 1 de la phase 3 bis.
3. `_applyDunning(false, …)` masque sans effacer le libellé : la valeur périmée reste en dictionnaire.
4. Coût réseau non borné : `_ensureIsAdmin` (lecture Firestore) à **chaque** publication d'entitlement,
   y compris quand la phase n'a pas bougé. Mémoriser la dernière phase évaluée.
5. `store_dunning_farewell` (`lang.yml:673`) n'est produit par aucune phase serveur — jeton orphelin,
   ou phase manquante côté balayage. À trancher.

---

## phase 4 — produits et RTDN en console

**Débloquée par 0.2 uniquement.** Rien de tout cela n'est saisissable tant que le profil de paiement
n'est pas vérifié.

### 4.1 — créer les produits

*Play Console → Monétisation → Produits → Abonnements.*

Les identifiants sont un **contrat à trois** entre le catalogue
(`resources_cloud/general/layers/store-base-global.yml`), la conf backend, et la console. Ils doivent
être saisis **au caractère près** :

| Abonnement | Base plans | Prix | Plafond |
|---|---|---|---|
| `ddust_essentiel` | `essentiel-monthly` · `essentiel-yearly` | 1,99 € · 19,99 € | 2 joueurs |
| `ddust_clan` | `clan-monthly` · `clan-yearly` | 2,99 € · 24,99 € | 4 joueurs |
| `ddust_tribu` | `tribu-monthly` · `tribu-yearly` | 4,99 € · 39,99 € | 7 joueurs |
| `ddust_guilde` | `guilde-monthly` · `guilde-yearly` | 5,99 € · 49,99 € | 12 joueurs |
| `ddust_royaume` | `royaume-monthly` · `royaume-yearly` | 7,99 € · 64,99 € | illimité |

Les **bornes** (2 / 4 / 7 / 12) sont calées sur la démographie des foyers, pas sur une
progression régulière. Elles pèsent cinq fois plus que le barème sur le revenu — ne pas les
retoucher sans relire `revenus.md` § Sensibilité.

⚠️ **`ddust_standard` et `ddust_unlimited` n'existent plus** (grille refondue le 2026-08-20).
Ce document supposait jusqu'ici qu'ils n'avaient jamais été saisis — la phase 4 est bloquée
par la vérification du profil de paiement (0.2) et sa checklist n'a jamais été cochée. **Si
l'un des deux a malgré tout été créé en console, il faut le DÉSACTIVER, pas le supprimer** :
un identifiant d'abonnement Play est définitif et ne se réemploie pas.

⚠️ **Le suffixe `-monthly` / `-yearly` est contractuel** : `dvstore.basePlanFor` choisit la
périodicité par `endsWith`. Un base plan nommé autrement rend l'annuel inachetable en
silence — l'app repart sur le mensuel sans un mot. C'est aussi la contrainte à respecter si
l'on traite un jour le point 3 de la phase 3 bis (« égalité stricte ») : la grille ci-dessus
doit continuer de fonctionner.

Offres attachées à chaque base plan :
- **`essai-14j`** — essai gratuit 14 jours, éligibilité « acquisition de nouveaux clients ».
- **`fondateur`** — éligibilité **déterminée par le développeur** : essai allongé + première année
  remisée.

⚠️ L'offre d'essai doit s'appeler **exactement `essai-14j`** : c'est ce que lit `TRIAL_OFFER_ID` pour
distinguer l'état « essai » de l'état « actif ». Une faute de frappe ne casse rien visiblement — elle
fait simplement apparaître tous les essais comme des abonnements payants.

Détail des bénéfices par palier et des produits à l'unité : `playstore.md` § monétisation.

### 4.2 — notifications temps réel (RTDN)

**Le build s'en charge — ou plutôt, de tout ce qui peut l'être.** L'API Play n'expose aucune
ressource RTDN : le nom du sujet et la case « Activer » n'existent que dans l'UI de la console.
`pucatalog` fait donc le reste : à la fin de la phase upload il ouvre la console, dicte la valeur
exacte à coller, et **vérifie pour de vrai** en écoutant le sujet avec un abonnement jetable. Il
suffit de suivre l'invite et de cliquer « Envoyer un message test ».

Une fois le message reçu, un marqueur est posé et la question ne se repose plus. Rien n'est
enregistré tant que le message n'est pas arrivé : une confirmation sur parole n'en est pas une.

Pour mémoire, la valeur en question — le build l'affiche lui-même :

```
projects/dvddust/topics/eu-play-rtdn
```

⚠️ Play n'accepte **qu'un seul sujet par application**, alors que l'infra en crée un par région
(`eu-play-rtdn`, `us-play-rtdn`). C'est voulu : ne renseigner **que celui d'Europe**. La fonction
européenne traite les deux régions de données (`STORE_REGIONS: "eu,us"`) ; celle des US reste muette.
Le build ne propose jamais le sujet américain.

### 4.3 — vérifier avant de passer à la recette

- [ ] Les 5 abonnements, 10 base plans et 2 offres existent avec les identifiants exacts.
- [ ] Le sujet RTDN est renseigné — le build a affiché « message de test reçu » puis « c'est
      enregistré », et ne repose plus la question au passage suivant.
- [ ] Le compte de service `deva-store@dvddust` figure dans *Utilisateurs et autorisations* (0.5).
- [ ] Le build a affiché `founders : eu-store …` **et** `founders : us-store …` — le document
      existe dans les deux régions, avec un `cutoff` de type *timestamp* (0.7).

---

## phase 5 — recette de la monétisation

C'est **la partie la moins rattrapable après coup** : un bug de facturation découvert en production
se paie en remboursements, en avis à une étoile et en confiance perdue.

### 5.1 — prérequis

- [ ] Phase 3 bis, points 1 à 5 livrés — **aucun ne l'est au 2026-08-20**. Sans eux : l'annuel n'est
      pas achetable (3-4), les plafonds ne s'appliquent pas (1), le premier achat d'un clan neuf
      échoue en `no_scope` (2), et un échec d'achat est indiscernable d'un bouton cassé (5).
- [ ] Profil de paiement **vérifié** (0.2) et produits créés (phase 4).
- [ ] Build contenant `dvstore` **publié sur une piste** (interne suffit). Compter quelques heures
      avant qu'il ne devienne installable.
- [ ] **Testeurs de licence** déclarés : *Play Console → Paramètres → Test de licence*. Ils doivent
      **aussi** avoir rejoint la piste via son lien d'opt-in. Leurs achats sont gratuits, sans débit.
      Les adresses vivent désormais dans `build.yml` sous `store.play.license_testers`, et **pucatalog
      pose l'étape à chaque déploiement** tant qu'elle n'est pas confirmée : il ouvre la page et
      affiche les adresses à coller. Aucune API Play n'expose ce réglage — le builder ne peut ni le
      poser ni le relire, il ne peut que guider, et il retient ta réponse sur parole.
- [ ] **Play Billing Lab** installé sur le téléphone de test (disponible sur le Play Store),
      connecté avec le **même compte** que le testeur de licence. C'est l'outil qui force les
      transitions d'état. ⚠️ Ses configurations **expirent au bout de 2 heures** — les reposer si la
      session s'éternise.

### 5.2 — durées de test accélérées

C'est ce qui rend exerçable en une après-midi un cycle qui dure normalement des mois.

| Ce qu'on teste | Durée réelle | Durée en test |
|---|---|---|
| Renouvellement hebdomadaire | 1 semaine | 5 min |
| Renouvellement **mensuel** | 1 mois | **5 min** |
| Renouvellement trimestriel | 3 mois | 10 min |
| Renouvellement semestriel | 6 mois | 15 min |
| Renouvellement **annuel** | 1 an | **30 min** |
| **Essai gratuit** | 14 jours | **3 min** |
| **Période de grâce** | paramétrée en console | **5 min** |
| **Suspension (account hold)** | jusqu'à 30 j | **10 min** |
| Fenêtre d'acquittement | 3 jours | **5 min** |
| Mise en pause | 1 / 2 / 3 mois | 5 / 10 / 15 min |

### 5.3 — moyens de paiement de test

Disponibles pour un testeur de licence, dans la feuille de paiement Play :

| Instrument | Usage |
|---|---|
| Test — approuve toujours | parcours nominal |
| **Test — refuse toujours** | **seul moyen de déclencher un vrai défaut de paiement** |
| Test — approuve lentement | achat différé (`PurchaseStatus.pending`) |
| Test — refuse lentement | échec différé |
| **Test — approuve puis rétrofacture** | **seul moyen d'exercer proprement le chemin de remboursement** |

Forcer une transition se fait soit par **Play Billing Lab** (*Subscription settings → Manage →
Subscription state* → Grace period / Account hold), soit à la main en changeant le moyen de paiement
de l'abonnement dans l'app Play Store.

### 5.4 — scénarios à dérouler

Vérifier à **chaque** étape la chaîne complète : *app → Play → RTDN → `clans_store` → retour app*.
La lecture de Firestore se fait en **REST + token ADC** (gRPC est bloqué sur ce poste).

| # | Scénario | Attendu |
|---|---|---|
| 1 | Achat `ddust_clan` mensuel **avec l'offre `essai-14j`** | état **`trial`**, pas `active` |
| 2 | Conversion de l'essai en payant, puis 2-3 renouvellements | `active`, `expiry` qui avance, un événement par renouvellement |
| 3 | **Achat annuel explicite** | le bon base plan part à Play (valide le point 3 de la phase 3 bis) |
| 4 | Défaut de paiement : Billing Lab → *Grace period* → *Account hold* | `grace` puis `hold` ; l'app verrouille au bon moment ; relances envoyées **aux admins seuls** |
| 5 | Récupération : retour à « approuve toujours » | l'accès revient **sans intervention** |
| 6 | Annulation depuis le Play Store, puis expiration | `canceled` puis `expired` en fin de période |
| 7 | Changement de palier `ddust_clan` ⇄ `ddust_tribu` (montée) **et** `ddust_tribu` → `ddust_essentiel` (descente) | ⚠️ la proration n'est **pas livrée** — constater ce que Play fait réellement et arbitrer. Avec cinq paliers, les sauts non adjacents (Essentiel → Guilde) sont à éprouver aussi |
| 8 | Plafonds : dépasser `max_players` par **chacun** des trois chemins gardés (création d'un joueur, invitation QR/PIN, acceptation d'une demande) | refus **et** ouverture de la **page des paliers**, bandeau de raison rempli, palier courant coché et palier conseillé fléché ; puis `ddust_royaume` lève le plafond ; une descente de palier **n'évince personne** |
| 8 bis | **Déclarer majeur** sur un clan au complet | **aucun refus** — la promotion ne déplace plus de place depuis la grille à un compteur |
| 8 ter | Page des paliers sous l'onglet **« Par an »**, canal Play fermé (banc d'essai) | les cinq lignes affichent les tarifs ANNUELS (`price_hint_yearly`), jamais les mensuels |
| 9 | Restauration sur un second appareil, et après réinstallation | droits retrouvés, pas de double crédit |
| 10 | Remboursement (carte « approuve puis rétrofacture », puis remboursement depuis la console) | droits retirés, événement d'audit écrit |
| 11 | **Suppression du clan pendant un abonnement actif** | la résiliation doit suivre — c'est le scénario qui produit des paiements fantômes |
| 12 | Un passage **sans** testeur de licence | aucune logique ne dépend du mode test |

### 5.5 — trois pièges du banc de test

- ⚠️ **Un achat de test non acquitté est remboursé automatiquement au bout de 3 minutes.** Si la
  chaîne d'acquittement n'est pas complète, les achats disparaissent tout seuls — symptôme qu'on
  prend facilement pour un bug d'affichage.
- ⚠️ **Maximum 6 renouvellements** par abonnement de test : au-delà, il expire de lui-même. Prévoir
  un compte de test neuf pour les longues séries.
- ⚠️ **Les achats de test ne calculent pas la TVA.** Ne rien conclure des montants affichés.

---

## phase 6 — verrous de production, puis lancement

### 6.1 — juridique

- ✅ **Structure ou adresse publique — RÉSOLU le 2026-09-02.** Cet arbitrage a commandé tout le
  dossier ; il est tranché, et dans le sens de la structure. **Entreprise individuelle, SIREN
  `109354092`, immatriculée au RNE le 2026-09-02, domiciliée `20 rue Lavoisier, 95300 Pontoise`.**
  L'adresse publiée sur la fiche sera celle de la domiciliation, jamais le domicile — ce qui était le
  motif central de toute la démarche.
  **Ce qui reste, ce n'est plus une décision mais un délai** : D-U-N-S (5 à 30 jours ouvrés, chemin
  critique), profil de paiement de type organisation, conversion du compte, 72 h d'attente, puis
  entrée d'app neuve. Détail et ordre : §0.2, et phase 4 de
  `grisloup/docs/plan-creation-micro-entreprise.md`.
  ⚠️ **Tant que la conversion n'a pas pris, ne rien publier.** Une fiche publique sous compte
  particulier afficherait le domicile, et c'est la seule porte qu'on ne peut pas refermer.
- **AIPD** (analyse d'impact relative à la protection des données, art. 35 RGPD) : **requise**, deux
  critères CNIL étant réunis — traitement de données de **mineurs** et recours à l'**IA générative**.
  Cf. `legal/dpa.md` §7. Non bloquante pour les tests, **bloquante pour la production**.
- **Relecture juridique** des CGU et de la politique de confidentialité, aujourd'hui qualifiées de
  « brouillons de test » dans `readme.md` §14.
- Archiver un PDF **daté** du Cloud Data Processing Addendum et des Firebase Data Processing Terms
  (cf. `playstore.md` § dpa).

### 6.2 — fiscal

✅ **RÉSOLU le 2026-09-02, en même temps que §6.1 — et c'est bien ainsi que les deux devaient se
prendre.** Le cadre est posé avant le premier encaissement, ce que cette section demandait :

| | Retenu |
|---|---|
| Forme | **Entreprise individuelle**, régime **micro** |
| Régime | **BIC prestations de services** — 21,2 % de cotisations, 50 % d'abattement, ~15 % d'IR en part du CA |
| Code APE | `58.29C` — édition de logiciels applicatifs, division 58 « Édition » |
| TVA | **Franchise en base** — pas de TVA facturée, pas de TVA récupérée |
| Déclaration de CA | **Trimestrielle**, à l'URSSAF, **même à zéro** (58 € par oubli) |
| SASU | **Hors plan.** ~970 €/an de régime contre ~2 200 €, sans bilan ni liasse |

**Ce qui n'est pas encore fait et qui touche l'encaissement :**

- [ ] **Numéro de TVA intracommunautaire** à faire attribuer par le SIE — **le dernier élément
      d'identité manquant**. ⚠️ **`FR43109354092`, affiché par Verif, societe.com et Pappers, N'EST
      PAS ATTRIBUÉ** : ces sites le *calculent* depuis le SIREN. Interrogé à VIES le 2026-09-06,
      il répond `isValid: false`. Le recopier dans la facturation Google Cloud ne déclencherait pas
      l'autoliquidation — il produirait une TVA irlandaise irrécupérable. ⚠️ Sous franchise en base, on ne
      facture pas de TVA — **mais recevoir des services de Google Ireland oblige à en disposer et à
      déclarer l'autoliquidation**. Avec des coûts d'inférence à ~15 % du brut, c'est exactement le
      profil concerné. Gratuit, mais à demander.
- [ ] **Rescrit fiscal (SIE) et rescrit social (URSSAF)** sur la position BIC. Gratuits, ~3 mois, et
      c'est ce qui transforme un pari annuel en position acquise opposable. Ne bloquent rien.
- [ ] **[PRO]** Le chiffre d'affaires déclaré est-il le **brut payé par l'utilisateur** ou le **net
      reversé par Google** ? La réponse commande la base des cotisations, la date d'atteinte du
      plafond du régime, et le sort de la commission Play au regard de l'autoliquidation.
- [ ] **Formulaire 1447-C avant le 31/12/2026** — il déclenche l'exonération de cotisation foncière
      de la première année.

⚠️ **La règle à tenir dans la durée.** Une seule facture de **développement sur commande** fragilise
la position BIC. Vendre un produit standard à un public indéterminé, c'est commercial ; vendre du
sur-mesure ou du conseil, c'est libéral — et pas seulement sur la ligne concernée. Le risque se
dégrade si le portefeuille dérive vers le sur-mesure, **pas s'il grossit**.

### 6.3 — lancement

1. Accès production accordé (fin de phase 3).
2. Promotion de la piste fermée vers la **production**, en **déploiement progressif** :
   10 % → 25 % → 50 % → 100 %, en laissant plusieurs jours entre les paliers.
3. Pays : **zone EU d'abord**, alignée sur les documents légaux et les langues fr/en/es. Les US
   suivront (le backend `us-*` existe déjà).
4. Grille tarifaire par pays à vérifier avant publication.

### 6.4 — surveillance des premières semaines

- Rapport de pré-lancement (crashs sur parc d'appareils réels).
- **Android Vitals** : taux de crash et d'ANR.
- Avis et notes — répondre vite aux premiers.
- **RTDN en conditions réelles** : vérifier que `clans_store` bouge à chaque événement Play.
- Connexion Google depuis une installation Store (validation continue du SHA-1).
- Premiers défauts de paiement : les relances partent-elles vraiment ?

---

## checklist finale avant production

- [ ] Profil de paiement **vérifié** (identité + compte bancaire)
- [ ] Écran de consentement OAuth **en production**
- [ ] `play_sha1s.client` renseigné et second client OAuth déployé
- [ ] Compte de test de revue fonctionnel, avec instructions
- [ ] IARC déclarant les achats numériques
- [ ] Data Safety cohérent avec `legal/dpa.md`
- [x] **Arbitrage §6.1 tranché** — structure + domiciliation, SIREN `109354092` du 2026-09-02
- [ ] **Compte développeur affiché « organisation »** : D-U-N-S obtenu, profil de paiement
      organisation vérifié, conversion faite, 72 h écoulées (§0.2)
- [ ] **Entrée d'app neuve créée APRÈS la conversion**, sous son package définitif — c'est ce qui
      achète l'exemption des 12 testeurs (§0.1, §2.2)
- [ ] **Fiche publique relue** : aucune trace de l'adresse personnelle
- [ ] **N° de TVA intracommunautaire** obtenu, puis reporté dans les mentions légales du site et sur
      la facturation Google Cloud (§6.2)
- [ ] **Statut de vendeur DSA déclaré « professionnel »**, coordonnées renseignées (affichage
      public assumé) — `compte.md`
- [ ] **Programme de frais de service réduits** : groupe de comptes créé, conditions acceptées —
      `compte.md`
- [ ] Corpus légal **v1** servi et cohérent avec le site (le corpus entier a été reposé en `v1` le
      2026-08-28 ; les mentions « CGU v5 / privacy v3 » qui traînent ailleurs sont périmées)
- [x] Identification de l'éditeur complète dans le corpus et sur le site — nom, qualité,
      domiciliation, **SIREN** (`tools/set_publisher_siren.py`, 2026-09-03)
- [ ] `store_config/founders` posé par le build dans les deux régions, `GRANT_ADMINS` renseigné
- [ ] Phase 3 bis : points 1 à 13 traités
- [ ] Recette de monétisation : les 12 scénarios verts
- [ ] AIPD menée, relecture juridique faite
- [x] Cadre fiscal confirmé — micro-entreprise, BIC prestations de services (§6.2)
- [ ] `debug.simulate_state` vide dans le build publié

---

## documents liés

| Document | Contenu |
|---|---|
| `playstore.md` | Ce qu'il faut **saisir** dans chaque formulaire de la console |
| `saisie_compte.md` | **Généré au build** — feuille de saisie des paramètres du compte, valeurs exactes |
| `saisie_playstore.md` | **Généré au build** — les cinq formulaires de l'étape 8 et la fiche |
| `compte.md` | Les démarches de niveau **compte** : statut de vendeur DSA, frais de service réduits |
| `legal/dpa.md` | Registre RGPD, Data Safety justifié, AIPD |
| `readme.md` §13-14 | Déploiement et doctrine légale |
| `strategie.md` | Lancement payant, offre fondateurs, gates de décision |
| `revenus.md` | Grille tarifaire et modèle de revenus |
| `progress.md` | État d'avancement fonctionnel |
