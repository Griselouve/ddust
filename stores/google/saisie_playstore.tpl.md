# saisie playstore — donjons & savons

Les cinq formulaires de l'étape 8. **Aucun raisonnement ici** : que des valeurs à recopier. Le
pourquoi de chaque réponse est dans `playstore.md`, à lire une fois, avant.

⚠️ **Tous sont obligatoires avant la PREMIÈRE release, test fermé compris.** Aucun ne peut être
remis à la production.

Les cinq assets sont rassemblés par le build dans `@@@C:listing.assets_dir@@@` — voir §5.

---

## 1 · Sécurité des données

*Play Console → Contenu de l'app → **Sécurité des données**.* Le plus long des cinq, et le seul
qui soit entièrement pré-rédigé.

**Questions générales :**

| Question | Réponse |
|---|---|
| L'app collecte-t-elle ou partage-t-elle des données utilisateur ? | **Oui** |
| Toutes les données sont-elles chiffrées en transit ? | **Oui** |
| Proposez-vous un moyen de demander la suppression des données ? | **Oui** — `@@@C:listing.delete_url@@@` |
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

1. **Abonner `@@@C:listing.app_access.adult_email@@@`.** C'est gratuit — le compte est testeur
   sous licence. Sans cet abonnement, le mur D2 se déclenche dès **deux validations** et le
   reviewer se retrouve devant un paywall sans échappatoire.
2. **Garnir le clan** : quelques joueurs, quelques tâches, un butin en cours. Un clan vide ne
   montre rien de ce que l'app fait.

### identifiants à fournir

| Compte | Rôle | Mot de passe |
|---|---|---|
| `@@@C:listing.app_access.adult_email@@@` | @@@C:listing.app_access.adult_role@@@ | `@@@C:listing.app_access.password@@@` |
| `@@@C:listing.app_access.kid_email@@@` | @@@C:listing.app_access.kid_role@@@ | `@@@C:listing.app_access.password@@@` |

### instructions à coller

```text
@@@C:listing.app_access.instructions@@@
```

---

## 5 · La fiche

*Play Console → Présence sur le Play Store → **Fiche principale**.*

### réglages

| Champ | Valeur |
|---|---|
| Nom de l'app (30 car. max) | `@@@C:listing.name@@@` |
| Type et catégorie | @@@C:listing.category@@@ |
| Tags | @@@C:listing.tags@@@ |
| E-mail de contact (public) | `@@@C:publisher.email@@@` |
| Site web | `@@@C:publisher.website@@@` |
| URL de politique de confidentialité | `@@@C:listing.privacy_url@@@` |
| Langues de la fiche | @@@C:listing.languages@@@ |
| Pays — test fermé | @@@C:listing.countries_closed@@@ |
| Pays — production | @@@C:listing.countries_prod@@@ |
| Publicités | **Non**, aucune |
| Achats dans l'application | **Oui** — Play calcule lui-même la fourchette affichée |

### descriptions courtes (80 car. max)

| Langue | Texte |
|---|---|
| fr-FR | `@@@C:listing.short_fr@@@` |
| en-US | `@@@C:listing.short_en@@@` |
| es-ES | `@@@C:listing.short_es@@@` |

### description longue — fr-FR

```text
@@@C:listing.long_fr@@@
```

### description longue — en-US

```text
@@@C:listing.long_en@@@
```

### description longue — es-ES

```text
@@@C:listing.long_es@@@
```

### assets graphiques

Rassemblés par le build dans **`@@@C:listing.assets_dir@@@`**, à téléverser **dans l'ordre de
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
- [ ] `@@@C:listing.app_access.adult_email@@@` **abonné** et son clan garni
- [ ] Accès à l'app : deux comptes et instructions fournis
- [ ] Fiche : réglages, 3 descriptions courtes, 3 longues
- [ ] 10 assets téléversés depuis `@@@C:listing.assets_dir@@@`
- [ ] Aucun avertissement jaune `asset listing/...` au dernier build
