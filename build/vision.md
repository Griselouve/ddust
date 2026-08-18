
# Donjons et Savons

--------------------------------------------------------------------------------------------------

## Concept

### MVP

Le foyer s'est transformé en un vaste donjon rempli de trésors et de monstres poussiereux.
Les valeureux parents ne s'en sortent pas, ils ont besoin d'aide !
Heureusement, AlChiffone de la guide "Corvée Nostra", envoie sa meilleur équipe d'aventuriers: les enfants.

Les taches ménagères, transformées en monstres, sont executées par les membres de la famille.
Chaque monstre vaincu rapporte des points d'experience au joueur qui l'a executé, mais aussi au clan tout entier.

Chaque fois que l'experience du clan atteint un certain palier, le clan passe au niveau supérieur et la famille peut décider d'ouvrir le butin du boss de niveau. 
Tous les joueurs se distribuent alors le butin de façon proportionnelle à leurs points d'experience et tous les points d'experiences sont dépensés.
La butin du boss de niveau est redéfini à chaque fois par les parents et peut contenir de l'argent de poche, une sortie en famille, etc...

Les parents peuvent décider d'un petit coup de pouce en XP supplémentaires pour compenser les déséquilibres et animer certains retardataires.
Ces XP ne sont pas donnés au clan, mais seulement au petit retardataire.
Cela se traduit par des évènements dans le jeu, par exemple "Un coup de main de la guilde".

Le joueur récoltant le moins d'XP n'est pas laissé à l'abandon. L'application précise dans le butin un prix spécial (qui n'a pas été injecté par les parents) pour celui qui traine, par exemple (si le pesudo du trainard est "Grog l'invincible") :
" et un bisou de chaque membre du clan pour Grog l'invincible pour l'encourager à aider un peu plus ! "

Les joueurs démarrent l'aventure avec 10 PVs.
On considère que chaque période de 3 jours sans executer de monstre et representée par une attaque de monstre, et le joueur perd 1 PV (sauf joueurs hors-ligne).
Chaque fois que le joueur monte un niveau, il récupère tous ses PVs
Chaque fois que le clan monte un niveau, tous les joueurs récupèrent leurs PVs.
Un joueur a 0 PV reçoit un gage (orienté comique et non punitif).

### Evolutions planifiées (à considérer dès le départ dans le design de la solution)

#### Or, loot et boutique

Les monstres donnent aussi de l'or.
En cours de jeu, cet or peut être dépensé à la boutique des heros pour obtenir des petites récompenses.
Cela peut être une récompense dans le jeu:
- une quête débloquée
- une potion
- un objet
Ou bien une récompense dans la vie réelle que l'on nommera "faveur" (un bonbon, droit de prendre un bain, 10 min d'écran additionel, etc...). 

Le loot est une chance mince mais non négligeable qu'une potion, un objet ou une faveur soit obtenu en plus de l'or, sans avoir à passer à la boutique

Dans le jeu on décrira les faveurs par exemple : "la bénédiction du pape" ou "une faveur de la reine" etc...

#### Les quêtes

Des quêtes permettent de booster les points d'experience. 
Par exemple, range ta chambre pendant 5 jours continus.
Il y a des quêtes individuelles qui ne rapportent des XP qu'au joueur, mais aussi des quêtes de clan qui rapporte des XP à tout le clan et aux joueurs.

#### Les potions

Une potion est un loot particulier qui modifie le jeu pour une durée limitée. Par exemple :
- Rajoute 10% d'XP pendant 3 jours
- Les taches partiellement terminées comptent pour complètes pendant 2 jours
- Les taches sont automatiquement validées sans validation d'un parent pendant 3 jours
(...)
Oui c'est un peu de la triche, mais cela est intéressant de donner aux enfant cette impression qu'ils peuvent dominer le jeu. 
L'essentiel est qu'ils participent ! Ceci s'adresse en particulier aux plus grands susceptibles de perdre un interêt dans le jeu.

#### Les objets

Armes, armure, bagues et talismans avec des effets divers.
Le joueur doit choisir le(s)quel(lles) équiper.

#### Les faveurs

Une faveur est une récompense dans la vraie vie. 
Le jeu propose des faveurs à titre d'exemple (un bonbon, droit de prendre un bain, 10 min d'écran additionel, etc...), 
mais les adultes peuvent en ajouter d'autres.

#### Les succès, partage

Le jeu est truffé de succès débloqués sous certains circonstances (par exemple laver la vaisselle 30 fois) qui accorde des titres au personnage et/ou au clan
Les niveaux des personnages et des clans également déclenchent des titres.
Chaque joueur peut choisir le titre débloqué de son choix pour afficher son profil, par exemple "Seigneur des Chaussettes"
La famille peut faire de même pour le clan.
Ces titres/succès sont partageables sur le reseau social de leur choix.
Toutefois, seuls les parents peuvent partager

#### Les classes

Chaque joueur peut choisir un stéréotype de personnage.
Le type de personnage implique des avantages et des inconvénients, donne accès à des taches spécifiques et titres spécifiques
Plus de détails sur ce concept dans "Focus Joueur" plus bas.

#### Les saisons

Des évènements spéciaux avec des titres, taches, potions, quêtes temporaires.
Par exemple pour la saison halloween, la tache "citrouille de décoration" ou le titre "Sait utiliser un balai de sorcière"
Pour des raisons culturelles et religieuses, le choix d'activer une saison est laissée aux parents.

### Evolutions potentielles

- Défis entre familles ?
- Dans le cas d'un succès au delà des attentes, il faudra envisager plusieurs instances du jeux avec chacun son propre backend firestore. Ce sera vécu comme une experience multiserveur par les joueurs.
- Les clans pourront s'allier dans des guildes. Ceci donnera lieu à des évènements de défis de guilde par exemple.

--------------------------------------------------------------------------------------------------

## Architecture

Application flutter avec un backend firebase/firestore
utilisation de gemini flash, très exceptionnelle
Les joueurs sont authentifiés par google.
Toutes les briques sont déjà présentes dans le framework Deva à part :
- dvdecisiontree (voir plus bas).
- les notifications
- le partage vers les réseaux sociaux

--------------------------------------------------------------------------------------------------

## Focus Clan

### constitution du clan

Tout joueur se connecte une fois authentifié auprès de google (authent PKCE)

A la première connexion l'app demande l'année de naissance et la région du joueur. 
Si d'après la date de naissance il s'agit d'un adulte, on lui fait passer une énigme "parentalGate".
La date de naissance n'est conservée nulle part, toutefois on conserve l'information mineur/majeur.

Si le joueur est majeur, il doit cliquer "En continuant, vous acceptez nos [CGU] et avez pris connaissance de notre [Politique de Confidentialité]"
Sinon, il doit cliquer une version "enfant" des CGUs. (par construction, l'adulte responsable donnera son consentement pour son enfant pour qu'il puisse jouer).

Ensuite, le joueur est invité à :
- créer son propre donjon (necesite d'être majeur)
- rejoindre un donjon existant

Le premier joueur adulte crée le donjon. Il acquière automatiquement le role de parent.
Les autres joueurs rejoignent le donjon existant. Ils ont automatiquement le role d'enfant (indépendamment mineur/majeur)
Par la suite, un parent peut choisir un autre joueur majeur pour lui attribuer le role parent.

Un écran montre les membres de la famille et leurs points d'experience respectifs.

Un écran montre les demande d'adhésion à la famille. Cet écran n'est visible que par les parents.
Les parents peuvent accepter la demande (à la prochaine connexion le joueur entre dans le donjon)
Ils peuvent également rejeter la demande (rien ne se passe, la demande disparait de l'écran).

Au clan peut être ajouté :
- une petite icone pour rendre le jeu plus ludique.
- une description
- un nom de clan
- un titre obtenu difficilement en jouant

### nom interne vs nom externe

Pour éviter toute dérive et la diffusion d'éventuelle donnée sensible, chaque nom (joueur, clan) possède sa version interne (choisie par les utilisateurs) et sa version externe (générée par l'application).
Entre joueurs du même clan, l'affichage montre la version interne.
Par contre les joueurs exterieurs au clan voient des noms générés par l'application.

### experience de clan

Pour chaque tache effectuée par l'un des membres, le clan gagne également de l'experience.
L'experience gagnée est divisée par le nombre de joueurs dans le clan (une famille de 2 membres gagnera donc la même experience qu'une famille de 5 dont tous les membres travaillent autant).

### évolution du clan 

L'experience accumulée permet de monter de niveau.
Chaque niveau est materialisé par un monstre spécifique (le boss de niveau) que le clan doit vaincre.
Gagner un niveau permet d'obtenir un titre et des récompenses spéciales !
Parmi tous les titres obtenus, un adulte peut choisir à tout moment quel titre correspond au clan.

### Journal (IA)

Journal du Clan : Un log généré automatiquement à chaque niveau qui résume les exploits de la famille avec un ton épique ou humoristique.
Pour éviter tout envoi de données personnelles à l'IA, seuls les noms externes sont communiqués à l'IA. L'app se charge ensuite du remplacement par les noms internes avant affichage.

--------------------------------------------------------------------------------------------------

## Focus Joueur

### Profil utilisateur

Le profil contient :
- une petite icone pour rendre le jeu plus ludique.
- un nom de personnage (
- un titre obtenu difficilement en jouant

La règle "nom interne vs nom externe" s'applique également pour le nom du personnage.

### Les enfants

Les enfants sont les principaux joueurs. Ils peuvent être légalement mineurs ou majeurs.

### Les adultes

Les adultes sont necessairement majeurs.
Les adultes ont les mêmes fonctionnalités que les enfants et peuvent jouer s'ils le désirent.

S'ils ne jouent pas, alors il n'y a aucune incidence sur le jeu, les enfants sont les seuls joueurs.

Si ils jouent et executent des taches, ils ont le choix entre : 
- gagner des XPs : ils jouent donc vraiment et sont en compétition/collaboration avec les enfants. Les taches effectuées visibles par les autres joueurs. Dans le cas où ils accumulent beaucoup d'XP en comparaison aux enfants, un petit message bienveillant leur rappellera que ceci peut démotiver les enfants, il ne faut surtout pas les écraser.
- ne pas gagner des XPs, mais jouer quand même : Dans ce cas seuls les adultes voient les taches réalisées par d'autres adultes. Les adultes ne comptent pas dans le calcul de l'experience du clan (diviser par le nombre de joueurs). Ce cas peut servir pour les parents qui ont un peu de mal à distribuer la charge entre eux, ils peuvent alors se rendre compte de qui fait le plus à la maison, sans impacter le jeu pour les enfants.

En plus des fonctionnalités "enfants", les adultes ont accès à 
- l'administration et aux paramètrages du jeu.
- l'audit de l'application
- une section "aide aux parents" qui donne quelques conseils

### passage à l'age adulte

Légalement, un joueur mineur est lié à l'adulte qui a approuvé l'adhésion à son tout premier clan (écran de consentement).
L'adulte majeur peut a tout moment sélectionner le joueur mineur et le déclarer adulte.
A la prochaine connexion, le joueur devenu adulte, devra cliquer "En continuant, vous acceptez nos [CGU] et avez pris connaissance de notre [Politique de Confidentialité]" pour continuer de jouer.

## Switch de profil

A la discretion des parents, l'age requis pour utiliser un téléphone est variable.
Pour les enfants jugés trop petits, les parents peuvent ajouter un profil "sans téléphone".

Egalement, on sait tous que parfois un enfant est privé de téléphone. Mais le jeu doit continuer !
Dans ce cas le parent peut selectionner le profil de l'enfant et le déclarer "hors ligne".

Pour que le butin puisse s'ouvrir :
Les profils "sans téléphone" et "hors ligne" ne sont pas comptés pour la demande d'ouverture du butin et l'ouverture effective.
Par contre, à moins que les parents soient radins, ils reçoivent bien leur part du butin

Pour que le jeu puisse continuer :
Avec le profil "parent", un parent peut switcher librement entre son profil et celui d'un enfant.
La première fois qu'il "switche", l'application lui demande de créer un code PIN, qu'il devra utiliser pour revenir sur son profil "adulte" (évitons ainsi que l'enfant accède à du contenu inapproprié).
Une fois avec le profil de l'enfant il peut selectionner les taches, les executer, utiliser des faveurs, objet, potion, aller à la boutique, etc... exactement comme le ferait l'enfant.

Au bout de trois tentative de code PIN incorrect, le "parentalGate" doit être résolue pour permettre de recréer un code PIN et revenir sur le compte adulte.

### Evolution du joueur

L'experience accumulée permet de monter de niveau.
Le niveau permet d'obtenir un titre.
Parmi tous les titres obtenus, le joueur peut choisir à tout moment quel titre lui correspond. 
Le niveau determine la puissance maximumdes artefacts que l'on peut acheter dans la boutique.

### Les classes

Chaque joueur peut choisir un stéréotype de personnage.
Le type de personnage implique des avantages et des inconvénients, donne accès à des taches spécifiques et titres spécifiques
Exemple : un voleur peut gagner de l'or supplémentaire sur des taches rapides. un barde peut donner un bonus de 5% d'experience à tout le clan si il execute une tache dans la même journée.
Certaines classes jouées ensemble peuvent offrir un petit bonus de synergie.

--------------------------------------------------------------------------------------------------

## Les taches

### gestion des taches

Le jeu dispose d'une liste de taches par défaut.
Lorsqu'un donjon est créé, des questions successives sont posées. 
Par exemple :
- Habitez vous en maison ou en appartement -> Toutes les taches ménagères relatives au jardin sont retirées si on choisi appartement
- Avez-vous une voiture ? -> Toutes les taches ménagères et d'entretien relatives à la voiture sont retirées s'il n'y a pas de voiture	
-> Le composant dvdecisiontree à développer :
Cette brique porte les éléménts de conf (data) et d'UI pour permettre de poser des questions à tiroir à l'utilisateur.
Les réponses à ces questions permettent de préselectionner les éléments d'une liste.

Les parents peuvent ajouter des nouvelles taches, selectionner/deselectionner, configurer des taches.

Les taches sont regroupées par lots logiques (chambres, salle de bain...)

A chaque tache pourrait être associée une petite icone pour rendre le jeu plus ludique.

### Selection d'une tache

Un écran montre toutes les taches disponibles, regroupées par lots logiques (chambres, salle de bain...)
Les taches désactivées par les parents n'apparaissent pas.
Les taches qui ne sont pas selectionnables en ce moment sont grisées.
Si une tache est déjà en cours, les autres taches ne sont pas selectionnables.

Pour chaque tache, l'écran montre le nombre d'XP qu'elle peut donner et une estimation du temps necessaire pour la faire.
Lorsqu'un utilisateur selectionne une tache, un écran de validation s'affiche et montre : 
- les XP à gagner
- les critères d'acceptance
- un bouton "Ok je vais le faire !"
Une fois validé, la tache passe au status "in progress" et n'est plus selectionnable par un autre joueur.

Le joueur s'il le désire peut relacher la tache qui redevient alors selectionnable par les autres joueurs. Aucun XP n'est gagné.

### Execution et Validation des taches

Lorsqu'un joueur termine une tache, le joueur peut prendre une photo (la photo est stockée sur le téléphone, pas dans le cloud pour éviter tout souci de PII), mais ce n'est pas obligatoire.
La tache passe au status "validating".
Dans ce status, personne ne peut selectionner la tache.

Les parents ont un écran dédié à la validation qui montre les taches en attente.
Pour chaque tache ils ont 3 choix :
- rejet : les XP ne sont pas gagnés et la tache redevient libre
- acceptance : les XP sont gagnés et la tache est executée
- partial : la tache est executée, mais le joueur ne gagne que la moitié des XPs. 

L'application affiche un petit texte pour récompenser la fin d'une tâche : 
"Tu as escorté le le Chariot Pestilentiel" (Sortir les poubelles), "Tu as vaincu l'Hydre de Céramique" (Nettoyer les WC).

### Taches mortelles

Une fois executée la tache est morte = non selectionnable.
Un délai indique le temps à partir duquel la tache est respawn.
Le gain en experience est constant.
Ce type de tache convient pour des taches qu'on ne peut pas faire deux fois de suite immédiatement, par exemple "mettre la table", ou bien des taches que les parents ne veulent pas voir repétées en permanence.

### Taches immortelles

La tache ne disparait pas, elle a juste "0 PV".
Un délai indique le temps que met la tache à regénérer completement.
Le gain en experience est proportionnel à la santé de la tache. Par exemple une tache à moitié régenérée ne fera gagner que la moitié des points.
Ce type de tache convient pour des taches que les enfants peuvent répéter sans cesse et sans risque.

## A anticiper dans le design : les taches

Pour chaque tache il faut donc :
- un nom
- une icone
- des critères d'acceptance
- un texte quand la tache est de nouveau dispo (notification)

--------------------------------------------------------------------------------------------------

## Focus faveurs

### Concept

Les faveurs sont des petites récompenses que le joueur peut obtenir en utilisant de l'or en via le loot.
Cela peut être par exemple : un petit temps d'écran supplémentaire, un bonbon, prendre un bain, etc.

### Mécanique

Le jeu dispose d'une liste de faveurs par défaut (pour donner quelques idées).
Les parents peuvent ajouter des nouvelles faveurs, selectionner/deselectionner...
A chaque faveurs pourrait être associée une petite icone pour rendre le jeu plus ludique.

Un écran dédié montre les faveurs gagnées par les joueurs, le cout en or et leur date d'expiration.
Une fois la date d'expiration dépassée, une faveur est désactivée et non selectionnable.

Lorsqu'un joueur veut utiliser une faveur qu'il a acquise, il en fait la demande à l'un des parents.
Les parents disposent d'un écran qui montre toutes les demandes d'utilisation de faveur.
Au moment où le parent valide la demande, la faveur passe au status "active" pendant une durée donnée.
A la fin de cette periode la faveur est désactivée et non selectionnable.

--------------------------------------------------------------------------------------------------

## Focus boutique

### Concept

La boutique propose d'échanger de l'or contre un nombre limité:
- d'objets
- de parchemins de quêtes (on ne sait pas quelle quête)
- de potions

L'offre est réinitialisée chaque samedi matin

Le niveau du joueur détermine le niveau des articles qu'il peut acheter.
Voir des articles incoyables, mais de haut niveau, motivera le joueur à monter de niveau.

--------------------------------------------------------------------------------------------------

## Les butins

### Concept

C'est la méta du jeu. La grosse récompense à partager entre tous les joueurs.
Il peut contenir plusieurs choses à la fois, par exemple : de l'argent de poche, une sortie en famille, etc.
Il s'ouvre lorsque le clan monte un niveau.

### gestion des butins

Une fois distribué, le butin est vidé et une nouvelle periode de jeu commence.
Les parents doivent alors penser à remplir le butin.
Pour cela ils ont un écran (invisible des autres joueurs) qui montre le contenu actuel du butin et un bouton "ajouter" pour ajouter un item supplémentaire.
L'ajout est un texte libre.
L'application propose des idées de butin (pour éviter les pannes d'inspi et les maux de tête des parents)

### ouverture du butin

Le butin apparait tous les 10000 XP
Lorsque le montant d'experience est atteint, alors le butin est sur le point de s'ouvrir.
Un écran permet à un adulte de choisir les membres du clan qui vont participer à l'ouverture du butin (un adulte peut être en voyage, un enfant puni de téléphone, etc...)
Un nouveau bouton "ouvrir" apparait pour tous les membres du clan qui sont sélectionnés pour participer.
Les membres du clan élus doivent cliquer sur ce bouton à peu près en même temps pour ouvrir le butin.
Un écran récompense avec des pieces d'or et des confetis dévoile alors le vrai contenu du butin.
Aux parents de tenir leurs promesses :)

### Affiliations

Stratégie à définir : local vs global.

Passer par des plateformes d'affiliation (comme Awin, Tradedoubler, ou CJ Affiliate). Ces plateformes listent des milliers de marques (parcs d'attractions, Lego, marques de jouets, cinémas) qui fournissent déjà des codes promos et des liens trackés de 5% à 15% de réduction.
Quand les parents configurent le "Butin du Boss", l'app leur propose une liste de récompenses pré-remplies. S'ils choisissent "Billet Futuroscope -10%", le jour de l'ouverture du butin, le parent clique sur le lien pour acheter la place.

Ou alors Amazon Associates ou Rakuten.
L'app propose des idées de butins génériques mais excitantes :
"Une carte cadeau Roblox (10€)"
"Des V-Bucks pour Fortnite"
"Le dernier tome du manga One Piece (Livre physique)"
"Un mois d'abonnement Spotify Premium"
Quand le parent valide ce butin, le lien l'envoie sur Amazon (géo-localisé automatiquement dans son pays par le système d'affiliation Amazon) pour acheter le manga ou la carte cadeau numérique.

--------------------------------------------------------------------------------------------------

## Multitenancy

Tristement il existe des familles recomposées, décomposées, ou simplement certaines personnes auront besoin de jouer dans plusieurs clans à la fois, ou changer de clan pour les vacances

Un joueur qui joue pour la première fois, à le choix entre la création d'un clan ou demander l'adhésion à un clan existant.
Une fois le clan créé ou rejoint, l'UI ne montre rien de particulier.

### changement de clan

Un joueur peut passer d'un clan A à un clan B
Deux possibilités :

	Dans les paramètres, accessible par n'importe quel joueur, il y a une option "changer de clan".
	Si le joueur choisi "changer de clan" il tombe sur l'écran de demande d'adhesion au nouveau clan.
	Les clans dont le nombre de membre max est atteint (voir abonnements) sont grisés "full" et ne peuvent être selectionnés.
	Dans le champ "rechercher" il peut alors écrire le nom du clan B (interne non connu du public) et choisir ce clan.

	> ÉCARTÉ : la recherche/sélection d'un clan par son nom est abandonnée. Elle casse la confidentialité inter-clans (désormais verrouillée dans Firestore), le nom interne n'est pas unique, et un annuaire interrogeable serait un vecteur d'abus pour une app d'enfants. À distance, on rejoint désormais via un lien d'invitation chiffré par PIN (voir readme « inviter/rejoindre à distance »), pas par recherche.

Ou alors

	L'adulte du clan B lui montre un QR code.

Tout d'abord, si le joueur est mineur, la demande d'adhésion au clan B parvient aux parents du clan A (ceux qui ont donné le consentement légal). S'ils approuvent la demande, elle est alors transmise au clan B.
Si le joueur est majeur, il n'a pas besoin de l'aprobation des parents du clan A, la demande est transmise directement au clan B.

Si l'adulte du clan B approuve, alors le joueur rejoint le clan B :
- les parents du clan A sont notifiés
- le thème de l'application et les différentes options achetées par le clan B s'appliquent pour le joueur qui vient de rejoindre le clan B.
- les éventuels objets, taches etc... du clan A restent dans firestore, mais sont invisibles pour le joueur tant qu'il reste dans le clan B.

Si le joueur veut continuer de rejoindre d'autres clans, alors la demande est toujours validée en priorité par les parents du clan A (ceux qui ont donné le consentement légal) si le joueur est mineur. La suite de la procédure est identique.

Si le joueur décide de revenir sur un ancien clan, il est automatiquement accepté. Les parents du clan A sont notifiés (si le joueur est mineur), ainsi que ceux du clan que le joueur vient de quitter et ceux du clan que le joueur vient de rejoindre.
- le joueur retrouve ses anciens objets, le thème est les différentes options du clan qu'il rejoint.
- les objets, thèmes et achats du clan qu'il vient de quitter deviennent invisible.

Dans l'écran de gestion de clan, le profil de l'enfant reste visible même s'il a quitté le clan, mais grisé avec un texte indique (à rejoint le clan XXX)
Tristement, un bouton "révoquer" peut révoquer l'adhésion de l'enfant: 
- l'enfant devra faire une nouvelle demande d'adhésion si il veut revenir dans le clan
- il perd tous les objets qu'il possédait dans l'ancien clan.
Ce bouton toutefois n'est pas disponible pour le clan A (ceux qui ont donné le consentement légal) tant que le joueur est mineur.

Lorsqu'un joueur est présent dans plusieurs clans, alors l'UI ajoute une icone supplémentaire pour permettre au joueur de switcher rapidement entre les clans sans avoir à repasser par les paramètres. Le nom du clan actuel est toujours visible dans la page "principale".

Les titres ne sont pas affectés par le changement de clan, le joueur les conserve avec lui.

### création de clan multiple

Dans les paramètres, accessible par tous les joueurs, il y a une option "créer un clan supplémentaire".
Si le joueur choisi cette option:
- il est d'abord prévenu du modèle économique (voir plus bas) : il devra payer un abonnement supplémentaire.
- ensuite l'application "redémarre" avec le dvdecisiontree de création de clan.

A partir de ce moment, l'UI ajoute une icone supplémentaire pour permettre au joueur de switcher rapidement entre les clans sans avoir à repasser par les paramètres.

### fin d'un clan

Dans les paramètres, accessible seulement par les admins du clan, il y a une option "supprimer le clan", ça arrive.
Dans ce cas, toutes les informations relatives au clan sont supprimées de firestore, l'abonnement est révoqué.

--------------------------------------------------------------------------------------------------

## Les notifications

### Pour les parents

Les notifications suivantes doivent être validable en un tap depuis la notif pour fluidifier le role parent :

- les demandes d'entrée dans le donjon
- les demandes de validation de tache
- les demandes d'utilisation de loot
- les notifications de clans filleuls (voir plus bas)

La notification suivante peut envoyer le parent directement vers l'écran de butin :

- si le butin est vide, un petit rappel

### Pour les enfants

- lorsqu'un parent a validé l'entrée dans le donjon
- lorsqu'un parent a validé une tache
- lorsqu'un parent a validé le départ d'un loot
- lorsqu'un loot est parvenu à sa fin de vie
- lorsqu'une tache a été respawn ou arrive à 100% de ses points de vie

--------------------------------------------------------------------------------------------------

## Préférences

Selection du language (module existant dvlang)

--------------------------------------------------------------------------------------------------

## Monetisation (modèle retenu 2026-07-07)

### Jeu de Base

Gratuit les 14 premiers jours, quelque soit la taille du clan.
(Un mois complet laissait passer le pic d'enthousiasme avant le premier paiement.)
Abonnement de 2.99 euros par mois, 29.99 euros par an, pour max 5 enfants, max 4 adultes
Abonnement de 4.99 euros par mois, 49.99 euros par an, permet de passer en illimité
(Le palier 1.99 euros a été supprimé : entrée à 2.99 euros pour l'ancrage de prix.
Les plans annuels correspondent à ~2 mois offerts, -17%.)

Si un adulte crée plusieurs clan, il doit alors payer les abonnements pour chaque clan.

A tout moment, un chef de clan peut upgrader ou downgrader l'abonnement de son (ses) clan(s) :
CHARGE_PRORATED_PRICE pour upgrade
DEFERRED pour downgrade

### Extensions

Validations auto (configurable par enfant) : achat 1.99 euros
Packs contenu à 3.99 euros:
- Pack "Quêtes"  (3 packs au total)
- Pack "Potions" (3 packs au total)
- Pack "Devoirs faits" (1 pack)
(Exemple de contenu "Devoirs faits" : Quête "13 de moyenne générale", Tache additionnelle "Apprendre le cours de maths", Potion "+15% XP sur les exercices de SVT")

Pack "Themes" à 5.99 euros
("Station Spatiale", "Académie de Magie", "Far West", "Mafia")

Une extension s'applique à un seul clan : celui avec lequel l'adulte est connecté au moment de l'achat.
Si l'adulte possède plusieurs clan, au moment de l'achat, un écran de confirmation qu'il s'agit d'un "achat pour le clan XXX"

### Renommer

Renommer un clan ou un joueur est gratuit la première fois, puis coute 0.49 euros.
-> annulé, les noms ne seront plus affichés à l'exterieur.

### Parrainage

Le clan peut inviter un nouveau clan
Passé 1 mois, si le nouveau clan s'abonne, alors cela offre 1 mois gratuit au clan "parrain". Les mois gratuits sont cumulables.

### dashboard

Dans la section "profil" "mes achats" un dashboard présente les abonnements et achats réalisés pour chaque clan.

### Les défauts de paiement

C'est un jeu familial pour aider les parents, et le design le rend particulièrement rentable.
On montrera donc de la compréhension et on sera flexibles dans le cas de paiments non reçus.

#### Periode de grace

10 jours

#### Account Hold

Passé 10 jours de grace on rentre dans account hold.

Un timer est stocké dans firestore pour ce clan.
On n'inquiète surtout pas les enfants.
Par contre l'application envoie des notifications aux parents

Phase 1: les 10 premiers jours (jour 10 à jour 20 après le défaut de paiement) :
2 notifications parmi :

“Votre bourse semble un peu légère aujourd’hui. Pas d’inquiétude : l’aventure continue dans Donjon & Savons, et vous pourrez régulariser cela plus tard.”
“La cotisation de guilde n’a pas pu être récupérée cette fois. Nous laissons la porte du donjon ouverte, en attendant votre prochain passage à l’auberge.”
“Petit contretemps dans le coffre du royaume. Le jeu reste ouvert, et vous pourrez remettre quelques pièces dans la cassette quand le moment sera venu.”
“Le dragon de la banque sommeille mal aujourd’hui. Heureusement, l’aventure continue sans interruption ; pensez simplement à régulariser votre abonnement plus tard.”
“Votre compagnon de route est toujours le bienvenu. Donjon & Savons continue, même si la cotisation n’est pas encore arrivée.”

Phase 2: pendant les 20 jours suivants (jour 20 à 40) 
3 notifications parmi :

“Ne laissez pas un petit souci de bourse arrêter l’aventure : le donjon vous attend toujours.”
“N’abandonnez pas votre héros pour un simple contretemps de paiement.”
“Un petit défaut de paiement ne doit pas faire tomber votre quête dans l’oubli.”
“Le savon est prêt, le donjon aussi : ne laissez pas une bourse distraite freiner la quête.”
“L’aventure continue encore, mais mieux vaut reforger votre abonnement sans trop tarder.”
“Une petite pièce manque au trésor, mais il est encore temps de sauver la partie.”
“La quête n’est pas perdue : rallumez votre abonnement et poursuivez l’épopée.”
“Le donjon murmure encore votre nom ; ne laissez pas ce contretemps briser l’aventure.”
“Même les plus grands aventuriers trébuchent sur un coffre mal fermé : reprenez la quête.”
“Votre place autour de la table est gardée ; ne laissez pas ce petit incident vous éloigner du royaume.”
“Le dragon du paiement a soufflé sur votre cotisation, mais la quête peut encore être sauvée.”
“N’abandonnez pas le royaume pour quelques pièces égarées.” 

Phase 3: pour les 10 jours qui suivent (jour 40 à 50)
2 notifications parmi :

"Le grimoire va se refermer. On a adoré jouer avec vous ! La porte du donjon restera toujours ouverte pour votre retour."
"L'équipe va prend un repos long. Merci pour ces super moments, revenez lancer les dés quand vous voulez !"
"Fin de partie... pour l'instant ! L'aventure était belle, vous serez toujours les bienvenus à l'auberge."
"Toutes les quêtes font des pauses. C'était très chouette de jouer avec vous, à bientôt dans le donjon !"
"Votre place à la table de la guilde reste au chaud. Merci pour l'aventure, revenez quand vous voulez !"
"Les bulles éclatent, la partie s'arrête. On s'est bien amusés, le donjon vous accueillera toujours à bras ouverts."

#### Account locked

A partir du jour 50, le clan est freezé. Les joueurs qui tentent d'accéder au clan voient l'image d'un groupe tipique de JDR blessés, fatigués au repos et un texte : "Votre clan s'est bien battu. C'était très chouette de jouer avec vous, Revenez lancer les dés quand vous voulez"
Les chefs de clan ont les boutons supplémentaires :
- revivre le clan -> dirige vers le paiement
- supprimer mes données -> déclence la suppression immédiate du clan et toutes ses données (celles des joueurs) de firestore

#### Account deleted

A partir du jour 90, le clan est supprimé de firestore.

### page web

Il faut une page web qui permette à un utilisateur de s'authentifier et demander la suppression du clan

A priori : 
Flutter (ou HTML/JS brut) connectée au projet Firebase existant. 
C'est le portail "Gestion de compte" à greffer à l'app.
Le Front (Firebase Hosting) : Une page web avec le SDK Firebase Auth. L'utilisateur se connecte avec ses identifiants habituels (ce qui valide son identité de façon sécurisée, évitant que n'importe qui supprime le compte d'un autre).
L'Action : Un gros bouton rouge "Supprimer mon compte et mes données".
Le Backend (Cloud Function) : Le bouton déclenche une Firebase Cloud Function (en TypeScript).

Dans la Google Play Console (l'idéal serait d'automatiser, mais manuellement pour commencer c'est ok):
Menu de gauche : Contenu de l'application
Section Sécurité des données (Data Safety)
À la question sur la suppression du compte, cocher "Oui" et et coller l'URL google front.

--------------------------------------------------------------------------------------------------

## Pistes pour la promotion

### Flyers

Coup de pouce local :
Flyers très simples avec un QR Code géant et un slogan accrocheur : "Vos enfants ne rangent pas leur chambre ? Transformez votre maison en jeu de rôle."
Où : proximité des écoles, boulangeries, pharmacies

### Subreddits

Par exemple: r/Parenting, r/daddit, r/Mommit ou r/ADHD
Le post : "J'en avais marre de crier pour que mes enfants fassent la vaisselle, alors j'ai codé un RPG où les corvées sont des monstres et mon fils vient de me demander s'il pouvait passer la serpillière pour monter niveau 4. Des gens veulent tester ?"

### Réseaux sociaux

Avec des comptes dédiés.

### Partages de Profil utilisateur et profil de clan

Un profil contient une icone, un nom, un titre choisi, un niveau, une liste de succès
Depuis l'app, le parent peut partager. Le partage contient un lien pour télécharger l'app

### Partages du journal

Depuis l'app, le parent peut générer une image "Bilan de la semaine" partageable sur ses stories Instagram/WhatsApp : "Le clan [Nom] a vaincu 45 monstres de poussière cette semaine sur Donjons & Savons !" auquel s'ajoute le log du journal du clan
Ce résumé peut être partagé. Le partage contient un lien pour télécharger l'app et un petit descriptif de ce qu'est l'application

### Voter l'app dans le store

Après avoir vaincu le boss: "tu as aimé : va voter !" et on croise les doigts pour avoir un vote 5 étoiles.

--------------------------------------------------------------------------------------------------

## aspects légaux

### CGV, CGU, Confidentialité

#### Ou?

Un lien à ajouter :
- dans l'application
- dans la fiche play store
- Dans l'écran avant abonnement

#### Contenu CGV 

Au minimum : 
- qui est l'éditeur (toi, avec une adresse), 
- ce que couvre l'abonnement
- les conditions du "Account Hold/Locked"
- comment contacter le support.

+

Procédure de résiliation (Loi Chatel) : "Vous pouvez annuler le renouvellement de votre abonnement à tout moment. La résiliation s'effectue directement via les paramètres d'abonnement de votre compte Google Play. La suppression de l'application ou la suppression de votre compte 'Donjons et Savons' ne résilie pas automatiquement votre abonnement auprès du store.".

Gestion des comptes inactifs: "En cas de défaut de paiement, l'accès au clan est maintenu pendant 50 jours. Passé ce délai, le clan est bloqué ('Account Locked'). Au 90ème jour, les données du clan sont définitivement supprimées de nos serveurs."

Génération de Contenu par Intelligence Artificielle : L'application "Donjons et Savons" utilise l'API d'Intelligence Artificielle Google Gemini pour générer de manière procédurale et aléatoire certains contenus narratifs et ludiques (tels que les noms de monstres et les descriptions de quêtes). Ce contenu est généré à des fins purement récréatives. En utilisant l'application, vous acceptez que ces textes soient générés de manière automatisée. Conformément à notre politique de confidentialité, aucune donnée personnelle n'est envoyée à l'API d'IA pour générer ces textes.

A rédiger :
préciser que les parents sont responsables de la sécurité physique des enfants lors de l'exécution des tâches (ex: manipulation de produits ménagers ou objets lourds) pour dégager ta responsabilité en cas d'accident domestique
expliquer clairement quel usage est fait des données (quelles données sont collectées, pourquoi, combien de temps conservées, comment les supprimer) et confirmer que les photos ne quittent jamais le téléphone
En utilisant Google/Firebase et Gemini Flash, tu acceptes de fait leurs conditions de traitement des données, mais il faut le mentionner dans ta politique de confidentialité.
Signer le DPA Google (disponible dans la console Firebase) et le mentionner dans la politique de confidentialité. 
Idem pour les plateformes d'affiliation

#### CGU "mineurs"

Un lien supplémentaire: Une politique de confidentialité spécifique mineurs, rédigée dans un langage accessible.
(A définir)

#### Au moment de la suppression d'un clan

Afficher un avertissement en gras : "Attention : La suppression de votre clan n'annule pas automatiquement votre abonnement facturé par Google. Pensez à résilier votre abonnement dans les paramètres de votre Store pour éviter d'être facturé le mois prochain."

#### Au moment de l'achat

Interroger le store pour avoir le montant exact (priceString formatté local) et la période de facturation (storeProduct ou ProductDetails)

(Ajouter dans les CGU et afficher) :

Droit de rétractation et Remboursements :
Tous les achats et abonnements sont traités par la plateforme de téléchargement (Google Play Store). En achetant du contenu numérique dans l'application, vous acceptez que la fourniture de ce contenu commence immédiatement, ce qui entraîne la renonciation à votre droit de rétractation, conformément aux règles établies par ces plateformes. Pour toute demande de rétractation légale ou de remboursement dans les délais prévus par la loi, veuillez utiliser les outils de gestion d'abonnement et d'historique d'achat intégrés à votre compte Google.

(Ajouter dans les CGU et afficher si abonnement) :

Modalités d'abonnement et renouvellement : 
"Le paiement sera débité de votre compte Google Play lors de la confirmation de l'achat. L'abonnement se renouvelle automatiquement à moins que le renouvellement automatique ne soit désactivé au moins 24 heures avant la fin de la période en cours."

#### Au moment du butin (si afiliation)

Afficher : "Ce lien est affilié et soutient le développement du jeu"

### parentalGate

Une page affiche un calcul mathématique, un pavé numérique et un compte à rebours de 3 secondes.
A chaque fois que le compteur atteint 0, un nouveau calcul est affiché et le compte à rebours reprends à 3 secondes.
Si l'utilisateur parvient à trouver la réponse avant 0, alors on considère que c'est un adulte.

### consentement parental

Lorsqu'un parent accepte l'adhésion d'un mineur au clan, il doit cocher :
En générant ce code d'invitation pour un mineur, vous confirmez être son tuteur légal et consentez à ce que "Donjons et Savons" collecte ses données de jeu (pseudo, expérience, avatar) pour le fonctionnement de l'application.
[Bouton : J'accepte et je génère le code]

Ce consentement, accordé lors de l'adhésion au premier clan, est suffisant pour toute la durée du jeu.
Lorsque l'enfant voudra rejoindre d'autres clans (par exemple en vacance chez les grands parents) aucun autre consentement sera demandé.

### Boutique réservée aux adultes 

Seuls les admins (supposés être des adultes) ont accès à la boutique.
Les autres joueurs (supposés être des enfants) n'y ont pas accès.
Après le switch d'un compte adulte vers un compte enfant, l'enfant est bloqué par un code pin pour revenir vers le compte adulte.

### Regions !

Il faut insérer, avant le dvdecisiontree, un écran de selection de la region.

Côté backend, il n'y a qu'un seul projet firebase. Mais les tables sont clonées dans chaque région active et prefixées par le nom de la région.
De façon transparent pour le code de l'application, le composant dvcloud doit orienter les requêtes firestore vers la table de la bonne région.

### Family policy 

// Désactiver la collecte d'ID publicitaires pour être compliant "Family Policy"
await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false); 

// Configurer le backend Firebase pour ne PAS lier Analytics à Google Ads.

### PIIs

On ne stocke que :
- l'ownerId du compte google
- la région (EU, US...)
- la distinction mineur | majeur
Pas de souci PII, même concernant les mineurs.

### accessibilité

Mon status d'Indie-maker solitaire m'évite les contraintes de certification type WCAG 2.1 AA.
Toutefois, une simple passe avec "Google Accessibility Scanner" permet d'éviter certains défauts.
