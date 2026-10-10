---
# Généré par la console deva depuis Firestore : ne pas éditer, réécrit à chaque envoi.
id: "2a9d5fed2fe38f6b"
isp: 3
module: "ddust"
---

# basculer `publisher` sur la structure

`build.yml → publisher` porte encore l'identité de la **personne physique**, alors que les
documents publient désormais celle de la structure. Trois champs à reprendre, tous au moment de
la conversion du compte Play en organisation — c'est une procédure console, une étape à la fois :

- `address` : domicile de Courdimanche → domiciliation de Pontoise. Google avait vérifié le
  domicile pour le profil de paiement **personnel** ; l'organisation demandera l'adresse
  d'entreprise.
- `phone` : `+33783310851` (mobile personnel) → `+33744470944` (ligne de la structure). Le champ
  alimente la console, où le statut *trader* du DSA rend le numéro public.
- `registration_number` : `~` → le SIREN, dès attribution.

⚠ `trade_name` vaut `grisloup.com` quand `developer_name` vaut `Grisloup`. Les documents disent
**Grisloup**. Aligner, ou assumer l'écart en le documentant.
