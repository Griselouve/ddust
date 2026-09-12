<!-- ---------------------------------------------------------------
     GENERE par builder.py depuis le build.yml de la suite.
     Ne pas editer : toute modification est ecrasee au prochain build.
     Gabarit : ../stores/google/saisie_playstore.tpl.md
     Source  : build.yml -> listing
     --------------------------------------------------------------- -->
# saisie playstore — donjons & savons

Les cinq formulaires de l'étape 8. **Aucun raisonnement ici** : que des valeurs à recopier. Le
pourquoi de chaque réponse est dans `playstore.md`, à lire une fois, avant.

⚠️ **Tous sont obligatoires avant la PREMIÈRE release, test fermé compris.** Aucun ne peut être
remis à la production.

Les cinq assets sont rassemblés par le build dans `../stores/google/assets/` — voir §5.

---

## 1 · Sécurité des données

*Play Console → Contenu de l'app → **Sécurité des données**.* Le plus long des cinq, et le seul
qui soit entièrement pré-rédigé.

**Questions générales :**

| Question | Réponse |
|---|---|
| L'app collecte-t-elle ou partage-t-elle des données utilisateur ? | **Oui** |
| Toutes les données sont-elles chiffrées en transit ? | **Oui** |
| Proposez-vous un moyen de demander la suppression des données ? | **Oui** — `https://donjons.grisloup.com/delete-account/` |
| L'app permet-elle de créer un compte ? | **Oui** (via Google) |

**Cinq types à déclarer.** Pour chacun, les mêmes quatre réponses : *collecté* **oui**,
*partagé* **non**, *traité de façon éphémère* **non**, *obligatoire* (pas facultatif).

| Catégorie → type | Finalités à cocher |
|---|---|
| Infos personnelles → **Nom** | Fonctionnement de l'appli |
| Infos personnelles → **Adresse e-mail** | Fonctionnement de l'appli, Gestion du compte |
| Infos personnelles → **ID utilisateur** | Fonctionnement de l'appli, Gestion du compte |
| Activité dans l'app → **Autres contenus générés par l'utilisateur** | Fonctionnement de l'appli |
| **Appareil ou autres ID** | Fonctionnement de l'appli |

**Ce qu'il ne faut surtout PAS déclarer** — c'est ici que le formulaire se rate :

- ❌ **Photos.** Les preuves restent sur l'appareil et ne sont jamais transmises : il n'y a pas
  de collecte au sens de Play. Les déclarer serait faux, et engagerait à tort.
- ❌ Localisation, contacts, ID publicitaire, analytics, historique web, santé, finances : rien.
- ❌ **Partage avec des tiers : non, partout.** Vertex AI est un sous-traitant agissant pour le
  compte de l'éditeur, pas un destinataire au sens du formulaire.

---

## 2 · Classification du contenu (IARC)

*Play Console → Contenu de l'app → **Classification du contenu**.* Questionnaire à remplir **en
tant qu'application**, pas en tant que jeu.

| Question | Réponse |
|---|---|
| Violence | **Fantastique et très légère** — monstres caricaturaux, « mort » du personnage |
| Interactions entre utilisateurs | **Oui, en cercle privé** (clan familial) — aucun échange avec des inconnus |
| Partage de localisation | **Non** |
| **Achats numériques** | ⚠️ **OUI** |

⚠️ **Le point à ne pas manquer, c'est le dernier.** Il avait été déclaré à l'envers du temps de
la beta gratuite, abandonnée depuis. **Une déclaration IARC fausse est un motif de retrait de
l'app** — ce n'est pas une case parmi d'autres.

Attendu : **PEGI 3 ou 7**, assorti de la mention « achats intégrés ».

---

## 3 · Public cible

*Play Console → Contenu de l'app → **Public cible et contenu**.*

Cocher **toutes** les tranches : `6-8`, `9-12`, `13-15`, `16-17` **et** `18+`. L'app est classée
en **audience mixte**, ce qui déclenche le questionnaire Family Policy.

Tu y es conforme **par construction**, rien à corriger avant de répondre :

| Exigence | État |
|---|---|
| Aucune publicité | ✅ aucune régie, aucun SDK |
| Aucun identifiant publicitaire | ✅ le builder retire `AD_ID` du manifeste |
| Analytics désactivés | ✅ `setAnalyticsCollectionEnabled(false)` |
| Porte parentale | ✅ module `dvparentalgate` |

---

## 4 · Accès à l'app

*Play Console → Contenu de l'app → **Accès à l'app**.* **La seule des cinq qui demande de la
préparation.** L'app exige une connexion Google : sans compte fonctionnel, la revue rejette pour
« impossible d'accéder au contenu ».

### ⚠️ deux préparatifs, AVANT de remplir le formulaire

1. **Abonner `daddy.ddust@gmail.com`.** C'est gratuit — le compte est testeur
   sous licence. Sans cet abonnement, le mur D2 se déclenche dès **deux validations** et le
   reviewer se retrouve devant un paywall sans échappatoire.
2. **Garnir le clan** : quelques joueurs, quelques tâches, un butin en cours. Un clan vide ne
   montre rien de ce que l'app fait.

### identifiants à fournir

| Compte | Rôle | Mot de passe |
|---|---|---|
| `daddy.ddust@gmail.com` | chef de clan adulte | `Ddust!12345678` |
| `kiddy.ddust@gmail.com` | membre mineur | `Ddust!12345678` |

### instructions à coller

```text
Le compte fourni a déjà un clan pour accéder immédiatement au jeu, et une connexion avec un compte Google neuf déroule le parcours complet de consentement.
```

---

## 5 · La fiche

*Play Console → Présence sur le Play Store → **Fiche principale**.*

### réglages

| Champ | Valeur |
|---|---|
| Nom de l'app (30 car. max) | `Donjons & Savons` |
| Type et catégorie | Application → Parentalité |
| Tags | famille, corvées, tâches, enfants, motivation, RPG |
| E-mail de contact (public) | `donjons@grisloup.com` |
| Site web | `https://donjons.grisloup.com` |
| URL de politique de confidentialité | `https://donjons.grisloup.com/fr/legal/` |
| Langues de la fiche | fr-FR (par défaut), en-US, es-ES |
| Pays — test fermé | France |
| Pays — production | France au lancement, le reste de l'UE ensuite |
| Publicités | **Non**, aucune |
| Achats dans l'application | **Oui** — Play calcule lui-même la fourchette affichée |

### descriptions courtes (80 car. max)

| Langue | Texte |
|---|---|
| fr-FR | `Transformez les corvées en aventure familiale : tâches-monstres, XP et butins.` |
| en-US | `Turn chores into a family adventure: monster tasks, XP, levels and loot chests.` |
| es-ES | `Convierte las tareas en una aventura familiar: monstruos, XP, niveles y botín.` |

### description longue — fr-FR

```text
⚔️ Les corvées sont des monstres. Abattez-les en famille !

Donjons & Savons transforme la maison en donjon : la famille devient un clan, chaque tâche ménagère devient un monstre à vaincre, et chaque victoire rapporte de l'expérience au joueur comme au clan. Quand le coffre du clan est plein, la famille ouvre un butin — une vraie récompense, décidée à l'avance par les parents. Le jeu ne simule pas la récompense : il structure la promesse familiale.

🛡️ Comment ça marche
• Un parent fonde le clan et invite la famille (QR code ou lien sécurisé).
• Chacun choisit son avatar et son nom d'aventurier.
• Ranger sa chambre, sortir les poubelles, mettre la table : 19 domaines et plus de 150 tâches, ajustés à votre foyer — et vos propres tâches en plus.
• Les parents valident les exploits (preuve photo possible — elle reste sur le téléphone).
• XP, niveaux, titres, points de vie, journal du clan et cérémonies d'ouverture du butin.

👨‍👩‍👧‍👦 Pensé pour les familles
• Aucune publicité, aucun traceur, aucun achat surprise.
• Les mineurs ne rejoignent un clan qu'avec le consentement d'un adulte responsable.
• Les photos ne quittent jamais l'appareil ; les données restent hébergées en Europe.
• Suppression de compte autonome, dans l'app ou sur le site.

Le butin est la promesse tenue. À vos épées — et à vos éponges !

```

### description longue — en-US

```text
⚔️ Chores are monsters. Defeat them as a family!

Donjons & Savons turns your home into a dungeon: the family becomes a clan, every household chore becomes a monster to defeat, and every victory earns experience for the player and for the clan. When the clan chest is full, the family opens a loot chest — a real reward, agreed in advance by the parents. The game doesn't simulate the reward: it gives the family promise a structure.

🛡️ How it works
• A parent founds the clan and invites the family (QR code or secure link).
• Everyone picks an avatar and an adventurer name.
• Tidying a bedroom, taking out the bins, setting the table: 19 areas and more than 150 tasks, tuned to your household — plus any you add yourself.
• Parents validate each feat (photo proof optional — it never leaves the phone).
• XP, levels, titles, hit points, clan log and loot-opening ceremonies.

👨‍👩‍👧‍👦 Built for families
• No ads, no trackers, no surprise purchases.
• Minors only join a clan with the consent of a responsible adult.
• Photos never leave the device; data stays hosted in Europe.
• Delete your account yourself, in the app or on the website.

The loot is the promise kept. Grab your swords — and your sponges!

```

### description longue — es-ES

```text
⚔️ Las tareas del hogar son monstruos. ¡Derrotadlas en familia!

Donjons & Savons convierte la casa en una mazmorra: la familia se convierte en un clan, cada tarea del hogar se convierte en un monstruo al que vencer, y cada victoria da experiencia al jugador y al clan. Cuando el cofre del clan está lleno, la familia abre un botín: una recompensa de verdad, acordada de antemano por los padres. El juego no simula la recompensa: da estructura a la promesa familiar.

🛡️ Cómo funciona
• Un adulto funda el clan e invita a la familia (código QR o enlace seguro).
• Cada cual elige su avatar y su nombre de aventurero.
• Ordenar la habitación, sacar la basura, poner la mesa: 19 ámbitos y más de 150 tareas, ajustadas a vuestro hogar, además de las que añadáis vosotros.
• Los padres validan las hazañas (con foto opcional, que nunca sale del teléfono).
• XP, niveles, títulos, puntos de vida, diario del clan y ceremonias de apertura del botín.

👨‍👩‍👧‍👦 Pensado para familias
• Sin publicidad, sin rastreadores, sin compras sorpresa.
• Los menores solo entran en un clan con el consentimiento de un adulto responsable.
• Las fotos nunca salen del dispositivo; los datos se alojan en Europa.
• Puedes eliminar tu cuenta tú mismo, en la app o en la web.

El botín es la promesa cumplida. ¡A por vuestras espadas... y vuestras esponjas!

```

### assets graphiques

Rassemblés par le build dans **`../stores/google/assets/`**, à téléverser **dans l'ordre de
leur numéro** :

| Fichier | Emplacement dans la console |
|---|---|
| `01-icone-512x512.png` | Icône de l'application |
| `02-feature-1024x500.png` | Image de présentation (feature graphic) |
| `03-capture-1.png` … `03-capture-8.png` | Captures d'écran — téléphone |

- Ne pas éditer ce dossier : il est réécrit à chaque build depuis `build.yml` → `listing.assets`.
  Pour changer une image ou son rang, c'est la conf qu'on modifie.
- Un **avertissement jaune au build** signale un asset hors des contraintes Play — mieux vaut le
  traiter avant l'upload que de se le faire refuser après.
- Captures tablette 7"/10" : facultatives, à ajouter le jour où la distribution tablette ouvre.

---

## contrôle

- [ ] Sécurité des données : 5 types déclarés, **photos non déclarées**, partage « non » partout
- [ ] IARC : **oui aux achats numériques**
- [ ] Public cible : les 5 tranches cochées, questionnaire Family Policy passé
- [ ] `daddy.ddust@gmail.com` **abonné** et son clan garni
- [ ] Accès à l'app : deux comptes et instructions fournis
- [ ] Fiche : réglages, 3 descriptions courtes, 3 longues
- [ ] 10 assets téléversés depuis `../stores/google/assets/`
- [ ] Aucun avertissement jaune `asset listing/...` au dernier build
