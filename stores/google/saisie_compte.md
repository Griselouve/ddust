<!-- ---------------------------------------------------------------
     GENERE par builder.py depuis le build.yml de la suite.
     Ne pas editer : toute modification est ecrasee au prochain build.
     Gabarit : ../stores/google/saisie_compte.tpl.md
     Source  : build.yml -> publisher
     --------------------------------------------------------------- -->
# saisie compte — donjons & savons

Feuille de saisie des **paramètres du compte développeur**. **Aucun raisonnement ici** : que des
valeurs à recopier.
Le pourquoi de chaque réponse est dans `compte.md`, à lire une fois, avant.

Ouvrir Play Console sur le **bon compte** : `https://play.google.com/console/u/1/`, puis la vue
**« Toutes les applis »** — les deux réglages sont invisibles depuis une application.

---

## 1 · statut de vendeur (DSA)

*Paramètres du compte développeur → Informations sur le développeur → **Statut de vendeur**.*

| Champ | À saisir |
|---|---|
| Statut de vendeur | **Professionnel** |
| Nom / Nom légal | `Guillaume Marchal De Greef` |
| Adresse | `16 Rue du Fief À Cavan` |
| Code postal | `95800` |
| Ville | `Courdimanche` |
| Pays | **France** (`FR`) |
| Téléphone | `+33783310851` |
| Adresse e-mail | `donjons@grisloup.com` |
| Site web | `https://donjons.grisloup.com` |
| Numéro d'immatriculation / TVA | *laisser vide* |
| Consentement à l'affichage public | **cocher** |

**Trois erreurs possibles, une ligne chacune :**

- « Nom » attend le nom civil. Ne **pas** y mettre `grisloup.com`.
- Le nom affiché sur la fiche est `Grisloup` : autre champ, autre écran, ne pas le saisir ici.
- « Non professionnel » n'est pas une option ouverte : vendre des abonnements en l'ayant déclaré = retrait de l'app.

---

## 2 · frais de service réduits

*Paramètres du compte développeur → **Groupes de comptes*** — ou le bandeau de la console, qui y mène directement.

| Écran | Réponse |
|---|---|
| Créer un groupe de comptes | **Oui** |
| Nom du groupe | `Grisloup` |
| Comptes développeur associés | **Aucun** |
| Conditions du programme | **Accepter** |

---

## 3 · nom du développeur affiché sur la fiche

*Paramètres du compte développeur → Informations sur le développeur → **Nom du développeur**.*

| Champ | À saisir |
|---|---|
| Nom du développeur | `Grisloup` |

C'est le **troisième** des trois noms de ce parcours, et le seul qui soit public au sens commercial.
Les trois vivent dans des écrans différents et la console ne les distingue pas clairement :

| Nom | Où | Valeur |
|---|---|---|
| Nom légal | profil de paiement, statut de vendeur (§1) | `Guillaume Marchal De Greef` |
| Nom commercial | CGU et pages légales du site | `grisloup.com` |
| **Nom du développeur** | **sous le titre de l'app, sur la fiche** | `Grisloup` |

C'est celui-ci que verront les familles, sous « Donjons & Savons ». Il n'a aucune contrainte
d'identité — c'est une marque, pas une déclaration — mais il doit rester stable : les avis et
l'historique de l'app y sont attachés.

---

## contrôle avant de fermer la console

- [ ] Statut affiché : **Professionnel**
- [ ] Nom légal identique, caractère pour caractère, au profil de paiement Play
- [ ] Adresse identique au justificatif de domicile — si elle diffère, **corriger `build.yml`** et relancer un build, jamais la console seule
- [ ] Numéro d'immatriculation resté vide
- [ ] Nom du développeur affiché : `Grisloup`
- [ ] Groupe de comptes créé, aucun compte associé déclaré, conditions acceptées
- [ ] Les deux lignes cochées dans la checklist de `publication.md`
