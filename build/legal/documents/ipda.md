# Donjons & Savons : analyse d'impact relative à la protection des données (AIPD)

**Document interne, non publié.** Tenu à la disposition de la CNIL et des autorités des autres
marchés sur demande. Rédigé en français, seule langue de référence ; une traduction sera faite si
une autorité étrangère le demande.

| | |
|---|---|
| Application | Donjons & Savons (Android, Google Play) |
| Responsable du traitement | Grisloup, nom commercial de MARCHAL DE GREEF Guillaume, entrepreneur individuel, 20 rue Lavoisier, 95300 Pontoise, France. SIREN 109354092, RCS Pontoise |
| Contact | donjons@grisloup.com |
| Délégué à la protection des données | Aucun, la désignation n'est pas obligatoire (registre des traitements, § 1) |
| Version | 0 (projet), 22 septembre 2026 |
| Statut | **Non close.** Deux garanties décrites ici ne sont pas encore livrées (section 7) ; l'avis des personnes concernées n'est pas encore recueilli (section 8) |
| Fondements | RGPD, article 35 ; lignes directrices du CEPD sur l'AIPD (WP248 rév. 01) ; méthode PIA de la CNIL |
| Documents sources | `docs/child_interest.md` (analyse de l'intérêt supérieur de l'enfant) ; registre des traitements (`grisloup/docs/registre_traitements.md`) ; politique de confidentialité `fr-a-fr-privacy` ; `build/readme.md` |

---

## 0. Objet et méthode

Ce document évalue les risques que le traitement des données de Donjons & Savons fait peser **sur
les personnes concernées**, et en premier lieu sur les enfants, puis met en face de chaque risque les
mesures qui le réduisent.

Il ne répète pas ce que décrivent déjà le registre des traitements et l'analyse de l'intérêt
supérieur de l'enfant : il y renvoie. Ce qui est propre à l'AIPD, c'est l'**analyse des risques**
(section 5) et le **bilan des mesures** (sections 6 et 7).

**Règle d'écriture.** Chaque mesure porte un statut : **livrée** (présente dans l'application
distribuée) ou **prévue** (décidée, pas encore livrée). Le risque résiduel n'est apprécié que sur
les mesures livrées. L'AIPD ne peut être close tant qu'une mesure dont dépend sa conclusion reste
prévue.

**Échelles** (méthode CNIL) :

| Niveau | Gravité (impact sur la personne) | Vraisemblance |
|---|---|---|
| 1. Négligeable | Aucun effet, ou un désagrément surmonté sans difficulté | Ne paraît pas pouvoir se produire |
| 2. Limitée | Désagréments significatifs, surmontés malgré quelques difficultés | Paraît difficile à réaliser |
| 3. Importante | Conséquences sérieuses, surmontées avec de réelles difficultés | Paraît possible |
| 4. Maximale | Conséquences graves, voire irrémédiables | Paraît facile à réaliser |

---

## 1. Pourquoi une AIPD est obligatoire

L'article 35 du RGPD impose une AIPD lorsqu'un traitement est susceptible d'engendrer un risque
élevé pour les droits et libertés des personnes. Les lignes directrices du CEPD, reprises par la
CNIL, retiennent neuf critères ; **un traitement qui en remplit deux doit en principe faire l'objet
d'une AIPD**. Donjons & Savons en remplit trois :

| Critère | Pourquoi il est rempli |
|---|---|
| **Personnes vulnérables** | Les enfants sont le public principal du jeu, y compris de jeunes enfants admis par un adulte |
| **Usage innovant d'une technologie** | Un modèle d'IA générative (Gemini, Vertex AI) produit, à la demande, des noms et un récit à partir de textes et du journal du clan |
| **Évaluation des personnes** | Le travail de l'enfant est jugé par un adulte (trois verdicts) ; ce jugement fait progresser un niveau, des points de vie et une part du coffre, et s'inscrit dans un journal lu par la famille |

Critères **non remplis** : aucune donnée sensible (article 9), aucune décision automatisée produisant
des effets juridiques, aucune surveillance systématique (ni localisation, ni image envoyée), aucun
croisement de fichiers, aucune exclusion du bénéfice d'un droit ou d'un contrat.

---

## 2. Description du traitement

### 2.1 Nature et finalité

Donjons & Savons transforme les tâches du foyer en jeu de rôle familial. La famille forme un clan
administré par des adultes (« chefs ») ; l'enfant choisit une tâche, la réalise dans la maison, la
soumet ; un adulte la juge ; le travail validé fait progresser le personnage et remplit un coffre
commun ouvert ensemble (`docs/child_interest.md`, section 3.1).

**Finalité unique** : permettre à un enfant de participer, sous la responsabilité de ses parents, à
un jeu familial dont l'objet est la contribution aux tâches du foyer (`child_interest.md`, 3.2).

Les données ne servent ni à la publicité, ni au profilage commercial, ni à la revente, ni à la mise
en relation.

### 2.2 Activités de traitement couvertes

Les activités sont décrites en détail dans le registre des traitements ; l'AIPD porte sur toutes
celles qui touchent des mineurs.

| Registre | Activité | Base légale | Mineurs |
|---|---|---|---|
| T1 | Comptes et connexion | Exécution du contrat (art. 6.1.b) | Oui |
| T2 | Déroulement du jeu | Contrat ; pour un mineur, consentement du tuteur (art. 8) | Oui |
| T3 | Consentement et preuves d'acceptation | Obligation légale et intérêt légitime (preuve) | Oui |
| T4 | Notifications | Exécution du contrat | Oui |
| T5 | Suggestions et récit par IA | Exécution du contrat, à la demande explicite | Oui |
| T6 | Abonnements, achats, codes cadeaux | Contrat ; intérêt légitime (litiges) | **Non** (adultes seuls) |
| T7 | Suppression et retrait du consentement | Obligation légale (art. 7.3 et 17) | Oui |
| T9 | Journaux techniques et sécurité | Intérêt légitime | Oui |

T8 (liste d'attente des bêtas, site web, adultes seuls) est hors du périmètre de cette AIPD.

**Seuil d'âge** : tout joueur de moins de 18 ans relève du consentement de son tuteur, sans
exception. L'application n'utilise pas la faculté de l'article 8 qui permettrait à un mineur de 15
ans de consentir seul en France (politique `fr`, § 4).

### 2.3 Personnes concernées

- **Enfants et adolescents**, avec ou sans téléphone (un chef peut créer un profil sans compte pour
  un enfant sans appareil ; quand l'enfant reçoit un téléphone, l'adulte peut rattacher ce profil à son propre compte) ;
- **adultes** du clan, chefs ou simples membres ;
- **représentants légaux** d'un enfant : l'adulte qui a consenti à son entrée dans son clan
  d'origine, et les **co-représentants** reconnus ensuite par un échange avec lui (l'autre parent,
  par exemple), membres ou non du clan d'origine ;
- **membres des autres clans** d'un enfant qui joue dans plusieurs clans (8 au plus) : ils voient
  son nom, son avatar et le titre qu'il porte, rien d'autre ;
- **enfant qui a dit vouloir jouer** mais n'a pas encore été invité par un adulte : rien n'est
  enregistré à son sujet tant qu'il ne s'est pas connecté ; sa réponse, sans donnée personnelle,
  n'est enregistrée qu'avec la décision de l'adulte.

### 2.4 Données traitées

Tableau complet : `child_interest.md`, section 6.1, et registre, fiches T1 à T7. En résumé :

| Catégorie | Exemples | Remarque |
|---|---|---|
| Identification technique | Identifiant de compte, de joueur, d'appareil ; secret du clan | Jamais montrés |
| Statut légal | Enfant, transition, adulte | **La date de naissance est saisie puis oubliée** |
| Pays, région, langue, décalage horaire | | Le décalage horaire sert à n'écrire qu'à des heures convenables |
| Identité de jeu | Nom de personnage **libre**, description, avatar ; nom public de substitution | Le nom libre **peut contenir un prénom réel** |
| Profil partagé entre clans | Nom, avatar et titre porté, les mêmes dans chaque clan du joueur | Visibles des membres de chacun de ses clans ; le reste (niveau, journal, objets, tâches) reste propre à chaque clan |
| Dossier de représentation d'un enfant | Représentant et co-représentants ; clans de l'enfant (nom du clan, nom du chef, adulte qui l'y a fait entrer, date) ; autorisations données à d'autres clans ; historique des gestes des représentants | Visible de l'enfant et de ses représentants seuls ; c'est une preuve (5 ans) |
| Progression et vie du clan | Expérience, niveau, points de vie, objets, rôle, clan d'origine | |
| Journal du clan | Tâches jugées, niveaux, coffres, cadeaux, datés | Lisible par toute la famille |
| Preuves d'acceptation | Versions acceptées, dates, déclaration du chef, réponse de l'enfant (date, langue, région, version du texte montré, code de la demande tiré au hasard) ; autorisation d'un autre clan donnée par un représentant ; déclaration d'un co-représentant | Conservées 5 ans après clôture |
| Traces d'audit des actes qui engagent | Entrée dans un clan, départ (de soi-même ou retrait d'un enfant par un représentant), dissolution d'un clan par son fondateur, chaque geste d'un représentant, création de la représentation d'un enfant ; auteur, enfant ou clan concerné, date, contexte de la session (région, langue, état légal), rien d'autre | Sous le compte de l'auteur, au même endroit que les preuves d'acceptation ; closes à la suppression du compte, conservées 5 ans |
| Réglage de réception des notifications | Notifications coupées pour le clan courant ou pour tous les clans, rangé avec l'inscription de l'appareil | Aucune autre donnée ; le serveur n'envoie plus rien à ce téléphone |
| Notifications | Jeton d'envoi, texte (peut contenir un nom de personnage) | |
| Achats | Référence Play, produit, dates | **Adultes seuls** |

**Ne sont pas collectés** : nom et prénom réels demandés comme tels, date de naissance conservée,
adresse, contacts, localisation, photo de profil, nom et photo du compte Google, identifiant
publicitaire, mesure d'audience, rapport de plantage, son. **La preuve d'une tâche (photo ou courte
vidéo sans son) n'est jamais envoyée ni sauvegardée en ligne**, et l'application n'a pas la
permission micro (`child_interest.md`, 5.9 ; registre, annexe C).

### 2.5 Recours à l'IA générative

Quatre usages, **tous déclenchés par un bouton**, jamais automatiques ni en arrière-plan
(`child_interest.md`, 6.2 ; registre, T5) :

| Usage | Transmis au modèle |
|---|---|
| Proposer un nom et une description de personnage | Le texte que la personne vient de saisir |
| Proposer un nom et une description de clan | Idem |
| Proposer un nom et une description de tâche | Idem |
| Raconter les aventures du clan | Nom et description du clan, journal en texte, **noms de personnage internes** des membres, expérience totale ; événements d'abonnement retirés |

**Jamais transmis** : identifiant de compte, âge ou date de naissance, photo, vidéo, adresse,
localisation, argent de poche.

**Choix assumé.** Le récit reçoit les noms que la famille emploie, et non les noms publics de
substitution. Remplacer ces noms avant l'appel a été envisagé puis **écarté le 2026-09-10** : le
récit est écrit pour la famille, un récit où les parents ne reconnaissent personne n'a pas d'objet.
Le nom public de substitution n'est **pas** une mesure de pseudonymisation vis-à-vis du modèle
(`build/readme.md`, § 6).

Sans demande de proposition, le nom public d'un joueur est tiré d'une banque locale : le nom choisi
par l'enfant ne part pas au modèle.

### 2.6 Localisation et sous-traitants

| Service | Rôle | Localisation |
|---|---|---|
| Cloud Firestore, Cloud Functions | Données de jeu, fonctions serveur | Cloud `eu` : Paris. Cloud `us` : `us-central1` |
| Vertex AI (Gemini), appelé depuis l'application par Firebase AI Logic | Suggestions et récit | Cloud `eu` : UE. Cloud `us` : États-Unis |
| Firebase Authentication | Connexion | **États-Unis, quel que soit le marché** |
| Firebase Cloud Messaging | Acheminement des notifications | **Mondial** |
| Google Play | Distribution, paiement | Responsable de son propre traitement |

Détail par marché et garanties de transfert : registre, annexe B. Contrats : Cloud Data Processing
Addendum et Firebase Data Processing and Security Terms (`build/legal/vendors/`).

### 2.7 Durées de conservation

Détail : `child_interest.md`, 6.3 ; politique `fr`, § 8 ; registre, T1 à T9. Principe : suppression
**immédiate** du service, **30 jours** sous accès restreint, puis **effacement définitif, sans
anonymisation**. Exceptions : preuves d'acceptation et traces d'audit des actes qui engagent 5 ans ; dossier de représentation d'un enfant
5 ans après sa clôture (majorité ou suppression du compte) ; clan bloqué ou inactif 2 ans ;
historique d'achat 2 ans ; historique des connexions 90 jours.

---

## 3. Nécessité et proportionnalité

| Principe | Comment il est respecté | Référence |
|---|---|---|
| **Finalité déterminée** | Une finalité unique, sans publicité, profilage ni revente | `child_interest.md`, 2 et 3.2 |
| **Base légale** | Contrat pour l'adulte ; consentement du tuteur pour le mineur, donné **au moment de l'acte** (inviter, après avoir lu le souhait de jouer de l'enfant ; créer un profil) et scellé dans la preuve d'acceptation | `child_interest.md`, 5.8 ; politique `fr`, § 3 et 4 |
| **Minimisation** | Nom de personnage plutôt que prénom ; date de naissance oubliée ; aucune localisation ; aucune photo ni vidéo envoyée ; aucun son enregistré (pas de permission micro) ; nom et photo Google exclus ; statistiques et identifiant publicitaire désactivés | `child_interest.md`, 6.1 |
| **Exactitude** | Le statut d'enfant reste acquis, dans tous ses clans, jusqu'à ce qu'un de ses représentants légaux (et non un autre chef du clan d'origine) déclare l'enfant majeur, qui doit alors accepter les conditions adultes : l'erreur possible va dans le sens de la protection | `child_interest.md`, 6.1 |
| **Durées limitées** | Calendrier en trois temps ; durées longues pour les clans justifiées dans l'intérêt de l'enfant (son histoire ne se reconstitue pas) | `child_interest.md`, 6.3 |
| **Information** | Conditions et politique rédigées pour l'enfant ; politique adulte par marché ; guide parent intégré | `child_interest.md`, 5.8 |
| **Droits des personnes** | Suppression depuis l'application ou le site, **y compris par un mineur seul** ; retrait du consentement pour un seul enfant, dans tous ses clans ; retrait d'un enfant d'un seul clan par son représentant ; autres droits par courriel sous un mois | `child_interest.md`, 5.10 ; politique `fr`, § 9 |
| **Avis de l'enfant** | L'enfant dit s'il veut jouer **avant la décision de l'adulte**, et avant toute écriture, sur son téléphone comme en base ; sa réponse, sans donnée personnelle, est transmise à l'adulte (code QR ou lien) et enregistrée avec sa décision ; son code, tiré au hasard, lie l'invitation de l'adulte à cette réponse et à nulle autre | `child_interest.md`, 5.8 |
| **Sous-traitance** | Google, sous contrat de traitement ; engagement contractuel de non-entraînement des modèles | Registre, annexe A |
| **Transferts** | Garanties par marché | Registre, annexe B |

**Alternatives écartées, et pourquoi.**

- **Vérifier le lien de parenté** : il faudrait collecter un état civil ou une pièce d'identité,
  plus sensibles que toutes les données du jeu (`child_interest.md`, 5.8).
- **Envoyer la preuve (photo ou vidéo) à l'adulte** : constituerait une archive d'images de
  l'intérieur des foyers (`child_interest.md`, 5.9).
- **Enregistrer le son des vidéos de preuve** : capterait des tiers (frères et sœurs, conversations
  des parents) sans utilité pour juger une tâche, et exigerait la permission micro
  (`child_interest.md`, 5.9).
- **Remplacer les noms avant le récit** : rendrait le récit inutile pour la famille (section 2.5).
- **Tenir une liste des enfants écartés** : ce serait le seul fichier d'enfants que le produit n'a
  pas (`child_interest.md`, 6.3).
- **Offrir une recherche de clan par nom** : un annuaire serait un vecteur d'abus
  (`child_interest.md`, 5.7).

---

## 4. Sources de risque

| Source | Exemple |
|---|---|
| Adulte malveillant **hors** de la famille | Personne qui tente d'entrer dans un clan ou d'identifier un enfant |
| Adulte **dans** le clan qui ment ou abuse | Adulte qui se déclare responsable d'un enfant qui n'est pas le sien ; adulte qui se sert du jugement pour faire pression |
| Adulte d'un **autre** clan que celui de l'enfant | Chef qui voudrait accueillir dans son clan un enfant déjà membre d'un clan, sans l'accord de ses parents |
| Application modifiée sur un appareil | Client qui contourne les règles de l'application |
| Sous-traitant, ou autorité ayant accès à ses données | Google ; autorités américaines (FISA, CLOUD Act) |
| Le modèle d'IA lui-même | Texte inadapté à un enfant, invention d'une donnée personnelle |
| Erreur du responsable | Règle d'accès mal écrite, durée non appliquée, régression |
| Destinataire d'un partage | Proche qui reçoit le récit et le diffuse |

---

## 5. Analyse des risques

Chaque risque est coté **avant** mesures (brut) et **après** les seules mesures livrées (résiduel).
G = gravité, V = vraisemblance.

### 5.1 Accès illégitime aux données d'un enfant

**Ce qui est redouté** : un inconnu, ou un adulte qui n'est pas responsable de l'enfant, accède à
son identité de jeu, à son journal, à ses habitudes (heures de jeu, tâches du foyer).

**Impact** : l'enfant est identifiable par sa famille, pas par le monde ; mais le journal révèle la
vie domestique (qui fait quoi, quand).

| Mesure | Statut |
|---|---|
| Aucun annuaire, aucune recherche de clan ou de joueur, aucune messagerie, aucune interaction entre clans | Livrée |
| Entrée dans un clan uniquement par un chef (QR code, lien protégé par un code à six chiffres) ; invitation expirée à 72 heures, secret effacé à la première utilisation | Livrée |
| Invitation marquée « enfant » (avec le code de la demande de l'enfant) ou « adulte » : le téléphone d'un enfant refuse, avant toute connexion, une invitation d'adulte ou faite pour la demande d'un autre enfant, et revérifie le code scellé avec la déclaration à l'entrée ; celui d'un adulte refuse une invitation d'enfant. Le code ne vit qu'en mémoire : application fermée pendant l'attente = nouvelle demande | Livrée (code du 2026-09-22, à vérifier au build) |
| Cloisonnement par clan dans les règles d'accès (secret d'appartenance) ; collections sensibles en lecture seule pour les clients | Livrée |
| Hors du clan, seul un nom public de substitution existe, sauf dans les autres clans du joueur, qui voient son nom, son avatar et son titre ; aucun écran ne montre un autre clan, hormis le nom des clans d'un enfant et de leur chef, montrés à ses seuls représentants | Livrée (exceptions : code du 2026-09-27, à vérifier au build) |
| Aucune adresse, photo, vidéo, localisation ni contact n'est détenu : « il y a peu à obtenir » | Livrée |
| Preuve d'une tâche (photo ou courte vidéo de 15 s au plus) jamais envoyée ; **vidéo de preuve sans son : pas de permission micro**, retirée du manifeste au build, donc aucune piste sonore et aucune voix d'un tiers | Livrée (code du 2026-09-26, à vérifier au build) |
| Accès aux consoles Google Cloud et Firebase réservé au responsable ; échanges chiffrés | Livrée |
| Lien de responsabilité attaché au clan d'origine, non transférable : le représentant légal est l'adulte qui a consenti à l'entrée de l'enfant dans ce clan (sa déclaration est la preuve de référence) ; un co-représentant n'est reconnu que par un échange avec lui, où il déclare lui-même, sur son appareil, être représentant légal | Livrée (code du 2026-09-27, à vérifier au build) |
| **Entrée dans un autre clan sur autorisation préalable vérifiée** : un enfant déjà membre d'un clan n'entre dans un autre que si l'un de ses représentants a autorisé ce clan (QR code en présence, ou lien et code à six chiffres), pour 7 jours ; l'application de l'enfant vérifie l'autorisation avant toute admission. **Un adulte extérieur ne peut plus faire entrer seul un enfant dans son clan** : jusqu'ici, la déclaration du chef d'accueil (« j'agis avec l'accord de son responsable légal ») n'était vérifiée nulle part | Livrée (code du 2026-09-27, à vérifier au build) |
| **Le représentant garde la main** : il voit les clans de l'enfant (nom du clan et nom de son chef, rien d'autre), peut l'en retirer à tout moment sauf du clan d'origine (notifications de ce clan coupées dès la réception, fiche effacée comme celle de tout membre parti) ; retrait du consentement et déclaration de majorité réservés aux représentants ; chaque geste est tracé dans le dossier de représentation | Livrée (code du 2026-09-27, à vérifier au build) |
| Profil partagé limité au nom, à l'avatar et au titre porté ; rien d'autre ne passe d'un clan à l'autre (ni niveau, ni journal, ni objets, ni tâches) ; 8 clans au plus ; un enfant sans téléphone reste dans un seul clan | Livrée (code du 2026-09-27, à vérifier au build) |
| Dossier de représentation protégé comme un clan, par un secret que seuls l'enfant et ses représentants détiennent | Livrée (code du 2026-09-27, à vérifier au build) |

| | G | V |
|---|---|---|
| Brut | 3 | 3 |
| **Résiduel** | **2** | **2** |

**Résidu accepté** : l'application ne vérifie pas le lien de parenté. Un adulte qui ment verrait le
pseudonyme, l'avatar et le journal de jeu, rien d'autre. Choix justifié en section 3.

**Résidu accepté (multiclan)** : les contrôles de l'autorisation et des représentants sont faits par
l'application, comme les autres gardes du jeu ; un enfant qui modifierait son application pourrait
techniquement les contourner. Ce contournement demande une compétence technique et ne donne accès
qu'au jeu d'un autre clan de la famille élargie. Les membres des autres clans de l'enfant voient son
nom, son avatar et son titre : perméabilité assumée, limitée à ces trois éléments et aux clans que
ses représentants ont autorisés ou fréquentent eux-mêmes.

### 5.2 Contenu inadapté produit par l'IA

**Ce qui est redouté** : le modèle écrit, pour un enfant, un texte violent, effrayant, sexuel,
moqueur, ou invente une information personnelle.

| Mesure | Statut |
|---|---|
| Appel uniquement sur action explicite ; repli sur un jeu statique traduit après 3 secondes | Livrée |
| Filtres de sécurité du modèle au niveau le plus strict (`BLOCK_LOW_AND_ABOVE`) sur les quatre catégories, posés par l'application dans chaque requête | Livrée |
| Consignes de ton dans chaque prompt : pas de violence, rien qui fasse peur, aucun thème d'adulte, aucun mot grossier, aucune donnée personnelle inventée, « dans le doute, la formulation la plus douce » | Livrée |
| Prompts dans un layer cloud : une consigne insuffisante se corrige sans nouvelle version de l'application | Livrée |
| Blocages non réglables de Google (notamment les contenus pédocriminels), appliqués quelle que soit la requête | Livrée (fournisseur) |
| **App Check exigé sur Android** (Play Integrity, jetons à usage limité) : seule l'application authentique installée depuis Play, donc avec ses filtres, peut interroger le modèle | **Prévue** (registre, écart E1) |

**Comment les filtres sont garantis.** Sur Android, l'application appelle le modèle directement et
les filtres partent avec la requête. Ils ne sont donc pas imposés par un serveur : ils sont
garantis par l'**authenticité de l'application**, qu'App Check vérifie. Une application modifiée,
ou un script, n'obtient pas de jeton ; un jeton extrait d'un appareil authentique ne sert qu'une
fois. Le proxy `ai_generate`, qui repose lui-même les filtres, est réservé à l'environnement de test
sous Windows et n'est pas ouvert au public.

| | G | V |
|---|---|---|
| Brut | 3 | 3 |
| **Résiduel** | **2** | **2** |

**Écart à fermer** : App Check n'est pas encore embarqué ni exigé. Tant que E1 n'est pas livré, un
client authentifié mais modifié pourrait desserrer les filtres. La vraisemblance reste faible (il
faut modifier l'application, et le texte n'est lu que par la famille de celui qui l'a fait), mais
**la conclusion de cette AIPD dépend de E1**. La politique de confidentialité et les CGU disent
aujourd'hui « imposé par nos serveurs » : cette phrase décrit le proxy et doit être reformulée.

**Résidu accepté une fois E1 livré** : App Check n'est pas infaillible (appareil compromis avec
contournement de l'attestation). Celui qui y parviendrait n'exposerait que les textes de son propre
clan.

### 5.3 Données d'enfants transmises au modèle d'IA

**Ce qui est redouté** : des données d'enfants sortent vers un service d'IA, sont conservées,
réutilisées pour entraîner un modèle, ou révèlent une identité réelle.

**Point d'attention** : le nom de personnage est libre. Un enfant peut y écrire son vrai prénom,
voire son nom de famille, et l'envoyer en demandant une proposition ; le récit transmet les noms
internes de tous les membres actifs.

| Mesure | Statut |
|---|---|
| Rien n'est transmis sans demande ; sans demande, le nom public vient d'une banque locale | Livrée |
| Ni identifiant, ni âge, ni photo, ni vidéo, ni adresse, ni localisation, ni argent de poche transmis | Livrée |
| L'application demande un **nom de personnage** (« Comment te nommes-tu, aventurier ? »), jamais un prénom | Livrée |
| Traitement dans la zone du stockage (UE pour le cloud `eu`) | Livrée |
| Engagement contractuel de Google de ne pas entraîner ses modèles sur les données client (Service Specific Terms, « Training Restriction ») ; aucune autorisation donnée | Livrée (contractuelle, non vérifiable par l'éditeur) |
| Le modèle ne conserve pas les échanges ; le texte produit suit la durée du clan | Livrée |

| | G | V |
|---|---|---|
| Brut | 2 | 3 |
| **Résiduel** | **2** | **2** |

**Résidu accepté** : les noms de personnage internes partent au modèle pour le récit (choix de la
section 2.5), et un prénom réel peut s'y trouver.

### 5.4 Pression ou humiliation par le jeu lui-même

**Ce qui est redouté** : le traitement sert d'instrument de contrôle ou de comparaison contre
l'enfant : jugement arbitraire, classement dans la fratrie, sanction de l'inactivité, désignation
d'un « perdant ».

C'est le risque propre au critère « évaluation des personnes ». Il porte moins sur la
confidentialité que sur la dignité et le développement de l'enfant.

| Mesure | Statut |
|---|---|
| Critère d'acceptation connu **avant** le travail, identique pour tous | Livrée |
| Trois verdicts, **aucun n'est une sanction** ; un refus ne retire rien et est raconté comme une tentative | Livrée |
| Un travail soumis ne peut pas être retiré à l'enfant ; un adulte ne juge pas son propre travail dès deux chefs | Livrée |
| Points calculés par le jeu ; tout verdict est daté au journal, consultable par l'enfant | Livrée |
| Ni classement, ni tri par résultats ; liste alphabétique | Livrée |
| Mode « hors concours » pour les adultes, **jamais** posable sur un mineur | Livrée |
| Inactivité : alerte à la famille après dix jours, pas d'exclusion ; accès conservé aux fonctions essentielles | Livrée |
| « Attaque de bisous » : deux joueurs cités dans un ordre aléatoire, dont un tiré au sort, message absent de leurs appareils | Livrée |
| Aucun pouvoir ajouté à l'adulte par rapport à l'autorité parentale ordinaire | Livrée (`child_interest.md`, 5.1) |

| | G | V |
|---|---|---|
| Brut | 3 | 3 |
| **Résiduel** | **2** | **1** |

### 5.5 Captation et sollicitation commerciale de l'enfant

**Ce qui est redouté** : les données de jeu servent à retenir l'enfant devant l'écran ou à le pousser
à l'achat.

| Mesure | Statut |
|---|---|
| Aucun achat possible depuis un compte mineur ; aucune offre payante ni écran de paiement montré à un enfant | Livrée |
| Aucune publicité, aucun identifiant publicitaire, aucune mesure d'audience | Livrée |
| Aucune mécanique de captation : ni série de connexions, ni récompense de visite, ni énergie, ni gain qui expire | Livrée |
| Rappels limités : au plus un par passage, aucun au-delà de 30 jours, enfant joint le samedi de 9 h à 10 h seulement, texte qui ne nomme ni ne compte les autres membres, désactivables en un geste | Livrée |
| Défaut de paiement : seuls les chefs adultes sont prévenus ; l'enfant ne voit aucune offre | Livrée |

| | G | V |
|---|---|---|
| Brut | 2 | 3 |
| **Résiduel** | **1** | **1** |

### 5.6 Conservation au-delà des durées annoncées

**Ce qui est redouté** : des données d'enfants survivent à la suppression du compte, au retrait du
consentement ou à la dissolution du clan.

| Mesure | Statut |
|---|---|
| Suppression fonctionnelle immédiate ; retrait du consentement pour un seul enfant avec délai de réflexion de 3 jours | Livrée |
| Retrait du consentement étendu à tous les clans de l'enfant, exécuté par le serveur au terme du délai même si l'enfant ne rouvre jamais l'application | Livrée (code du 2026-09-27, à vérifier au build) |
| Cascade : dissolution du clan d'origine, suppression des mineurs sans responsable | Livrée |
| Le seul représentant d'un enfant ne peut pas supprimer son compte (il ajoute d'abord un co-représentant ou supprime le compte de l'enfant) ; un enfant qui garde un co-représentant n'est pas emporté par la cascade | Livrée (code du 2026-09-27, à vérifier au build) |
| Dossier de représentation clos à la majorité ou à la suppression du compte de l'enfant, avec sa date d'effacement à 5 ans | Livrée (code du 2026-09-27, à vérifier au build) ; l'effacement lui-même relève de E2 |
| Preuve (photo ou vidéo) effacée au verdict, au plus tard à l'ouverture suivante ; sauvegarde Android désactivée | Livrée |
| Invitations à 72 heures, jetons de notification, historique des connexions : effacement automatique | Livrée |
| **Effacement définitif à 30 jours** (comptes, fiches, clans dissous et journaux, compte d'authentification), jeton d'achat vidé en fin d'abonnement, preuves à 5 ans | **Prévue** (registre, écart E2) |
| Démarrage du calendrier de blocage après résiliation ou fin des mois offerts | **Prévue** (registre, écart E3) |

| | G | V |
|---|---|---|
| Brut | 2 | 4 |
| **Résiduel (mesures livrées)** | **2** | **4** |
| Résiduel attendu une fois E2 et E3 livrés | 2 | 1 |

**Écart à fermer** : aujourd'hui, les données supprimées sont marquées comme telles mais **restent en
base**. Les durées publiées ne sont pas tenues. C'est le risque résiduel le plus élevé de cette
analyse, et **la conclusion de l'AIPD dépend de E2**.

### 5.7 Transfert hors de l'Union et accès d'autorités étrangères

**Ce qui est redouté** : les données d'un joueur sont accessibles à une autorité étrangère sans voie
de recours.

| Mesure | Statut |
|---|---|
| Marché choisi à l'installation, définitif ; aucune circulation entre clouds | Livrée |
| Joueurs de l'UE : données de jeu et IA dans l'UE | Livrée |
| Authentification (États-Unis) et notifications (mondial) : clauses contractuelles types et Data Privacy Framework (Google LLC certifiée) | Livrée |
| Hors UE : évaluation marché par marché, autorisation distincte là où la loi l'exige | Livrée (registre, annexe B.3) |
| Données pauvres en information : pseudonymes, progression, sans date de naissance ni localisation | Livrée |

| | G | V |
|---|---|---|
| Brut | 2 | 2 |
| **Résiduel** | **2** | **1** |

**Résidu accepté** : pour les marchés du cloud `us`, l'accès des autorités américaines sans recours
effectif ; annoncé dans les politiques concernées (registre, B.3).

### 5.8 Diffusion hors de la famille

**Ce qui est redouté** : le journal ou le récit, qui nomment des enfants, circulent au-delà des
proches.

| Mesure | Statut |
|---|---|
| Partage réservé aux adultes du clan ; refusé à un mineur | Livrée |
| Hors du clan, seul le nom public de substitution existe dans l'application (hormis dans les autres clans du joueur, section 5.1) | Livrée |
| Le contenu du coffre n'est pas écrit au journal ; les événements d'abonnement sont retirés du récit | Livrée |
| La politique invite l'adulte à la prudence avant de partager un contenu mentionnant des enfants | Livrée |

| | G | V |
|---|---|---|
| Brut | 2 | 2 |
| **Résiduel** | **2** | **2** |

**Résidu accepté** : une fois partagé par un adulte, le texte échappe au responsable. C'est un geste
volontaire d'adulte, comparable à l'envoi de photos de famille.

### 5.9 Perte ou altération des données de jeu

**Ce qui est redouté** : l'histoire du clan (journal, niveaux, coffres) disparaît ou est altérée par
erreur ou par un client modifié.

| Mesure | Statut |
|---|---|
| Journal du clan en ajout seul ; journal de facturation écrit par le serveur seul | Livrée |
| 30 jours sous accès restreint pour réparer une erreur de manipulation | Livrée |
| Durées longues pour les clans bloqués ou inactifs, préavis avant dissolution, garde de réveil avant purge | Livrée |

| | G | V |
|---|---|---|
| Brut | 2 | 2 |
| **Résiduel** | **1** | **2** |

### 5.10 Cartographie

| Risque | Résiduel actuel (G × V) | Après E1, E2, E3 |
|---|---|---|
| 5.1 Accès illégitime | 2 × 2 | 2 × 2 |
| 5.2 Contenu IA inadapté | 2 × 2 | 2 × 1 |
| 5.3 Données transmises à l'IA | 2 × 2 | 2 × 2 |
| 5.4 Pression par le jeu | 2 × 1 | 2 × 1 |
| 5.5 Captation commerciale | 1 × 1 | 1 × 1 |
| **5.6 Conservation excessive** | **2 × 4** | 2 × 1 |
| 5.7 Transferts | 2 × 1 | 2 × 1 |
| 5.8 Diffusion hors famille | 2 × 2 | 2 × 2 |
| 5.9 Perte ou altération | 1 × 2 | 1 × 2 |

Aucun risque n'atteint une gravité importante ou maximale après mesures. Un seul atteint une
vraisemblance maximale : la conservation excessive, tant que E2 n'est pas livré.

---

## 6. Mesures transverses

Mesures qui servent plusieurs risques à la fois.

| Mesure | Statut |
|---|---|
| Aucune donnée de jeu avant l'avis de l'enfant et l'autorisation de l'adulte ; l'avis précède la décision et lui est transmis ; rien n'est enregistré avant la connexion de l'enfant, seule subsiste une entrée d'authentification anonyme vide, effacée par la plateforme à 30 jours | Livrée (code du 2026-09-22, à vérifier au build) |
| Onboarding en session anonyme tenue en mémoire : ni écriture en base ni fichier sur l'appareil avant la connexion à un compte, langue comprise ; la déconnexion vide la mémoire de tout ce qui appartient au compte | Livrée (code du 2026-09-22, à vérifier au build) |
| Comptes de service distincts par usage, aux droits limités | Livrée |
| Alertes de budget | Livrée |
| Registre des incidents ; notification à la CNIL sous 72 heures en cas de risque, aux personnes si le risque est élevé | Livrée (procédure, registre annexe D) |
| Isolation des bases vérifiée au build (`dvcloud` contre `pufirestore`) | Livrée |
| Revue de ce document à chaque changement listé en section 10 | Livrée (procédure) |

---

## 7. Plan d'action

| # | Mesure | Risques servis | Condition de clôture de l'AIPD |
|---|---|---|---|
| E1 | Exiger App Check sur les appels IA d'Android (Play Integrity, jetons à usage limité) ; proxy `ai_generate` réservé à Windows et fermé au public ; reformuler « imposé par nos serveurs » dans la politique et les CGU | 5.2, 5.3 | **Oui** : la garantie des filtres en dépend |
| E2 | Coder l'effacement définitif et les durées de la politique § 8 | 5.6 | **Oui** : durées publiées non tenues |
| E3 | Démarrer le calendrier de blocage après résiliation ou fin des mois offerts | 5.6 | Non (le clan inactif est déjà dissous à 2 ans) |
| A1 | Recueillir l'avis de parents de la bêta fermée (section 8) | Tous | **Oui** |

Les écarts E1 à E3 sont suivis dans le registre des traitements (annexe E) et dans la roadmap.

---

## 8. Avis des personnes concernées

L'article 35.9 du RGPD prévoit de demander, s'il y a lieu, l'avis des personnes concernées ou de
leurs représentants.

**À faire** pendant la bêta fermée : interroger quelques parents testeurs sur trois points au moins :

1. le récit transmis au modèle avec les noms de la famille : acceptable, à mieux signaler, à
   rendre optionnel ?
2. le nom de personnage libre, qui peut recevoir un vrai prénom : faut-il le déconseiller à l'écran ?
3. le jugement du travail et « l'attaque de bisous » : perçus comme bienveillants ou comme une
   pression ?

Consigner ici la date, le nombre de familles, les réponses et ce qui en a été tiré.

| Date | Familles interrogées | Synthèse | Suite donnée |
|---|---|---|---|
| | | | |

---

## 9. Conclusion

**Appréciation à ce jour (version 0).** Le traitement est limité, proportionné à sa finalité, et
chaque risque identifié est couvert par des mesures dont la plupart sont livrées. Aucun risque
n'atteint une gravité importante ou maximale.

**L'AIPD ne peut pas encore être close** :

- le risque de conservation excessive (5.6) reste à un niveau de vraisemblance maximal tant que
  l'effacement définitif (E2) n'est pas livré ;
- la protection contre un contenu IA inadapté (5.2) repose sur App Check, pas encore embarqué ni
  exigé (E1) ;
- l'avis des parents n'est pas recueilli (A1).

**Appréciation attendue une fois E1, E2 et A1 livrés** : risque résiduel acceptable, **sans
consultation préalable de la CNIL** (article 36), qui n'est requise que si un risque élevé subsiste
malgré les mesures.

| Rôle | Nom | Date | Décision |
|---|---|---|---|
| Responsable du traitement | MARCHAL DE GREEF Guillaume | | |

---

## 10. Révision

Réexaminer cette AIPD, et en changer la version, dès que :

- un nouvel usage de l'IA apparaît, ou qu'une nouvelle donnée est transmise au modèle ;
- un écran montre quoi que ce soit d'un clan à un autre clan (classement, comparaison, compétition) ;
- une donnée nouvelle est collectée sur un mineur, une photo ou une vidéo de preuve est envoyée hors
  de l'appareil, ou l'application obtient la permission micro ;
- un sous-traitant, une région ou un marché change ;
- une durée de conservation change ;
- un incident de confidentialité survient ;
- une mesure « prévue » est livrée (mettre à jour son statut et la cotation du risque).

| Version | Date | Changement |
|---|---|---|
| 0 | 16 septembre 2026 | Première rédaction, à partir de `docs/child_interest.md` et du registre des traitements |
| 0 | 22 septembre 2026 | Parcours du mineur réordonné : l'enfant dit d'abord s'il veut jouer, sa réponse (sans donnée personnelle) est transmise à l'adulte et enregistrée avec sa décision ; plus d'enregistrement avant la connexion, ni en base ni sur l'appareil ; mémoire vidée à la déconnexion (sections 2.3, 2.4, 3 et 6). Le même jour : la réponse porte un code tiré au hasard, et l'invitation est marquée « enfant » (avec ce code) ou « adulte » (sections 2.4, 3 et 5.1) |
| 0 | 27 septembre 2026 | Multiclan : un joueur peut appartenir à 8 clans ; nom, avatar et titre porté partagés entre ses clans. Un enfant n'entre dans un autre clan qu'avec l'autorisation préalable de son représentant, vérifiée par son application ; co-représentants ; retrait d'un clan ; retrait du consentement étendu à tous les clans et exécuté par le serveur ; dossier de représentation, preuve conservée 5 ans ; le seul représentant ne peut pas supprimer son compte (sections 2.3, 2.4, 2.7, 3, 4, 5.1 et 5.6). Le même jour : traces d'audit des actes qui engagent, rangées et conservées comme les preuves d'acceptation ; notifications coupées par clan ou pour tous (sections 2.4 et 2.7) |

---

## Annexes : obligations équivalentes hors de l'Union

Cette AIPD vaut pour tous les marchés : les garanties sont les mêmes partout. Les annexes disent,
marché par marché, ce que la loi locale exige de plus et où c'est traité.

### Annexe A. Royaume-Uni (`uk`)

Le **Children's Code** de l'ICO (Age Appropriate Design Code) impose une DPIA à tout service en
ligne susceptible d'être utilisé par des enfants (standard 2). Cette AIPD en tient lieu. Les autres
standards du code (intérêt de l'enfant, paramètres protecteurs par défaut, minimisation, absence de
géolocalisation, contrôle parental, pas de techniques de captation) sont couverts par les sections 3
et 5. **Obligation propre** : représentant au Royaume-Uni (UK GDPR, art. 27), registre annexe B.3.

### Annexe B. Suisse (`ch`)

La LPD (art. 22) exige une analyse d'impact en cas de risque élevé ; cette AIPD en tient lieu.
**Obligation propre** : représentant en Suisse (LPD, art. 14), à instruire, registre annexe B.3.

### Annexe C. Québec et Canada (`ca`)

L'**évaluation des facteurs relatifs à la vie privée** (Loi 25, art. 3.3 et 17) est rédigée dans le
registre des traitements, annexe B.3, section `ca`. Cette AIPD la complète pour l'analyse des risques
propres aux mineurs et à l'IA.

### Annexe D. Brésil (`bresil`)

La LGPD (art. 38) permet à l'ANPD d'exiger un **rapport d'impact** (*relatório de impacto à proteção
de dados pessoais*) : description des types de données, méthode de collecte, mesures de sécurité et
analyse des mesures. Les sections 2, 5 et 6 y répondent ; une traduction portugaise sera produite sur
demande. La protection des mineurs au titre de la Lei 15.211/2025 est traitée au registre, annexe B.3.

### Annexe E. Colombie (`hispam`)

La Ley 1581 de 2012 n'impose pas d'AIPD sous ce nom ; elle exige de démontrer que le traitement
répond à l'intérêt supérieur de l'enfant (art. 7). Cette démonstration est
`docs/child_interest.md` ; sa synthèse destinée à être remise est `build/legal/documents/child_interest.md`.

### Annexe F. Autres marchés

- **États-Unis (`us`)** : pas d'obligation fédérale d'AIPD. Les obligations propres aux enfants
  (COPPA) sont portées par la politique `us`.
- **Mexique (`hispam`)** : pas d'obligation d'analyse d'impact pour ce traitement ; contrat de
  sous-traitance, registre annexe B.3.
- **Australie et Nouvelle-Zélande (`oceanie`)** : pas d'obligation légale d'AIPD à ce jour ; le futur
  Children's Online Privacy Code australien est suivi au registre, annexe B.3.
