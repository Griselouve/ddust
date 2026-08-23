<!-- ---------------------------------------------------------------
     GENERE par builder.py depuis le build.yml de la suite.
     Ne pas editer : toute modification est ecrasee au prochain build.
     Gabarit : ../stores/google/saisie_dpa.tpl.md
     Source  : build.yml -> dpa
     --------------------------------------------------------------- -->
# saisie dpa — donjons & savons

Conformité sous-traitance (art. 28 RGPD). **Aucun raisonnement ici** : que des valeurs à
recopier. Le pourquoi est dans `dpa.md`, à lire une fois, avant.

Des trois démarches, **une seule est encore manuelle**. Les deux autres sont posées par le
déploiement et par le build ; elles restent décrites pour que tu saches quoi vérifier, pas quoi
faire.

---

## 1 · Firebase — contact protection des données

**C'est la seule saisie de cette page.** Aucune API ne l'expose, elle se fait à la main.

*Console Firebase → projet `dvddust` → ⚙️ Paramètres du projet →
onglet **Confidentialité des données**.*

| Champ | À saisir |
|---|---|
| Responsable de la protection des données — nom | `Guillaume Marchal De Greef` |
| Responsable de la protection des données — e-mail | `donjons@grisloup.com` |
| Représentant UE (art. 27) | **laisser vide** |

- Le représentant UE ne se désigne que si l'éditeur est établi **hors** de l'Union. Il l'est en
  France : y mettre quoi que ce soit serait une déclaration fausse.
- Le DPO n'est pas obligatoire à cette échelle ; le champ sert ici de **contact données**, celui
  que la politique de confidentialité annonce déjà.
- ⚠️ L'emplacement exact de l'onglet bouge selon les versions de la console. S'il a disparu,
  chercher « Data privacy » dans les paramètres du projet.

---

## 2 · GCP — contacts essentiels : rien à saisir

Posé par `puproject` au déploiement (`backend/config.yml` → `conf.project.essential_contacts`).

**Vérification, une fois :** *Console GCP → IAM et administration → Contacts essentiels* doit
montrer une ligne `donjons@grisloup.com`, catégorie `Juridique`.

- Absente ? Le déploiement a échoué sur ce point — le plus probable est que le compte de service
  master n'a pas `essentialcontacts.admin`. Ne pas la créer à la main : elle ne survivrait pas à
  une recréation de projet, et son absence redeviendrait invisible.
- Ce canal apporte deux choses : les **changements de sous-traitants** et les **incidents**.

---

## 3 · archivage des deux textes : rien à saisir non plus

Le build télécharge, vérifie et date les deux textes dans `../../build/legal/`.

| Texte | Source |
|---|---|
| `Cloud Data Processing Addendum` | `https://cloud.google.com/terms/data-processing-addendum` |
| `Firebase Data Processing and Security Terms` | `https://firebase.google.com/terms/data-processing-terms` |

Ce qu'il faut savoir, et rien de plus :

- Les fichiers sont datés de la version **publiée par Google**, pas du jour du téléchargement.
- **Les anciennes versions ne sont jamais supprimées.** L'accountability est un historique, pas
  un état : c'est normal d'accumuler plusieurs `cdpa-*.pdf`.
- Un **avertissement jaune au build** signifie que la dernière tentative a échoué — page
  injoignable, date illisible ou rendu invalide. L'archive en place est conservée, mais elle
  peut être périmée. Deux builds de suite en jaune méritent un coup d'œil.
- ⚠️ **Aucune case « j'accepte » n'existe** dans les consoles récentes : ces textes sont
  incorporés d'office aux conditions d'utilisation. L'archive datée **plus** les contacts
  renseignés constituent la preuve d'adhésion (art. 5.2 RGPD). Il n'y a rien d'autre à signer.
- Veille humaine, second canal : la liste des sous-traitants Google se suit par abonnement à
  `https://cloud.google.com/terms/subprocessors`.

---

## contrôle

- [ ] Firebase : nom et e-mail renseignés, représentant UE **vide**
- [ ] GCP : un contact essentiel `donjons@grisloup.com` en catégorie `Juridique`
- [ ] `../../build/legal/` contient un `cdpa-*.pdf` et un `firebase-dpst-*.pdf`
- [ ] Aucun avertissement jaune `archive dpa/...` au dernier build

---

## 4 · identité du compte de facturation GCP — écart connu

C'est l'entité rattachée au compte de facturation GCP qui est **partie au CDPA**. Elle doit être
la même que celle déclarée à Play, aux CGU et aux pages légales du site.

*Console GCP → Facturation → compte de facturation → **Paramètres de paiement**.*

| Ce qu'on veut | `Guillaume Marchal De Greef`, personne physique |
|---|---|
| Ce qui est en place | un profil de paiement de type **Organisation**, nommé `Grisloup` |

⚠️ **Ce n'est pas une case à cocher, c'est un écart à traiter.** Le profil de paiement utilisé pour
Cloud n'est pas celui utilisé pour Play : Play est rattaché au profil *Particulier* au nom civil,
Cloud à un profil *Organisation* portant le nom commercial. Or aucune société n'existe derrière ce
nom — le responsable de traitement est une personne physique.

**Quoi faire :** rattacher le compte de facturation GCP au **même profil de paiement particulier**
que Play, ou à défaut corriger le nom du profil Organisation pour qu'il porte le nom civil.

**Quand :** avant la production, pas avant le test fermé. Le dossier RGPD doit être cohérent le jour
où de vrais clients paient, pas le jour où douze familles testent gratuitement. À reprendre avec la
question de statut (`publication.md` §6.2) — si une société est créée, c'est elle qui deviendra
partie au CDPA et les cinq points bougeront ensemble.

- [ ] Écart traité, ou explicitement reporté à la décision de statut
