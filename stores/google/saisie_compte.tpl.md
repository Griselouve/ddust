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
| Nom / Nom légal | `@@@C:publisher.legal_name@@@` |
| Adresse | `@@@C:publisher.address.street@@@` |
| Code postal | `@@@C:publisher.address.postal_code@@@` |
| Ville | `@@@C:publisher.address.city@@@` |
| Pays | **France** (`@@@C:publisher.address.country@@@`) |
| Téléphone | `@@@C:publisher.phone@@@` |
| Adresse e-mail | `@@@C:publisher.email@@@` |
| Site web | `@@@C:publisher.website@@@` |
| Numéro d'immatriculation / TVA | *laisser vide* |
| Consentement à l'affichage public | **cocher** |

**Trois erreurs possibles, une ligne chacune :**

- « Nom » attend le nom civil. Ne **pas** y mettre `@@@C:publisher.trade_name@@@`.
- Le nom affiché sur la fiche est `@@@C:publisher.developer_name@@@` : autre champ, autre écran, ne pas le saisir ici.
- « Non professionnel » n'est pas une option ouverte : vendre des abonnements en l'ayant déclaré = retrait de l'app.

---

## 2 · frais de service réduits

*Paramètres du compte développeur → **Groupes de comptes*** — ou le bandeau de la console, qui y mène directement.

| Écran | Réponse |
|---|---|
| Créer un groupe de comptes | **Oui** |
| Nom du groupe | `@@@C:publisher.developer_name@@@` |
| Comptes développeur associés | **Aucun** |
| Conditions du programme | **Accepter** |

---

## 3 · nom du développeur affiché sur la fiche

*Paramètres du compte développeur → Informations sur le développeur → **Nom du développeur**.*

| Champ | À saisir |
|---|---|
| Nom du développeur | `@@@C:publisher.developer_name@@@` |

C'est le **troisième** des trois noms de ce parcours, et le seul qui soit public au sens commercial.
Les trois vivent dans des écrans différents et la console ne les distingue pas clairement :

| Nom | Où | Valeur |
|---|---|---|
| Nom légal | profil de paiement, statut de vendeur (§1) | `@@@C:publisher.legal_name@@@` |
| Nom commercial | CGU et pages légales du site | `@@@C:publisher.trade_name@@@` |
| **Nom du développeur** | **sous le titre de l'app, sur la fiche** | `@@@C:publisher.developer_name@@@` |

C'est celui-ci que verront les familles, sous « Donjons & Savons ». Il n'a aucune contrainte
d'identité — c'est une marque, pas une déclaration — mais il doit rester stable : les avis et
l'historique de l'app y sont attachés.

---

## contrôle avant de fermer la console

- [ ] Statut affiché : **Professionnel**
- [ ] Nom légal identique, caractère pour caractère, au profil de paiement Play
- [ ] Adresse identique au justificatif de domicile — si elle diffère, **corriger `build.yml`** et relancer un build, jamais la console seule
- [ ] Numéro d'immatriculation resté vide
- [ ] Nom du développeur affiché : `@@@C:publisher.developer_name@@@`
- [ ] Groupe de comptes créé, aucun compte associé déclaré, conditions acceptées
- [ ] Les deux lignes cochées dans la checklist de `publication.md`
