<!-- revu: 20260526 -->
# dvutils (Python)

## concept

Boîte à outils Python du framework deva. Fournit des helpers de bas niveau pour les opérations fichiers, les requêtes HTTP et les paramètres de ligne de commande. Disponible globalement via `deva.utils`.

## API

- **Fichiers** : `copyfile`, `copytree`, `rm`, `rmtree`, `makedirs`, `movefile`, `unzip`, `zip`, `compute_file_hash`.
- **Copie annotée** : `copyfile_annotated`, `copytree_annotated`, `copytreecontent_annotated` — variantes qui prépendent un commentaire d'avertissement dans les fichiers texte copiés (`.py`, `.yml`, `.dart`, `.xml`, etc.), indiquant le chemin source d'origine et signalant que le fichier sera écrasé au prochain build.
- **Requêtes HTTP** : `request(protocol, url, headers, data?)`.
- **Paramètres** : `parse_params(file)` — charge un YAML + args CLI dans un `dvidle`. `tob64` / `fromb64`.
- **Sortie colorée** : `print(color, *args)` via colorama.
- **Shell** : `run(cmd, path?, shell?, output?, verbose?)`.
- **Sessions des API Google** (`dvhttp.py`) : `robuste(session)` borne la CONNEXION à 10 s et la rejoue jusqu'à 4 fois, sans jamais rejouer une requête partie. Toute `AuthorizedSession` du builder et des modules Pulumi passe par lui (2026-09-25 : une connexion neuve sur vingt vers Firestore restait pendue depuis le poste de build, et échouait au bout de 120 s sans reprise).
- **Process Windows** : `kill_app(exe_name)` — identifie les PIDs d'un exécutable par nom, remonte l'arbre de processus jusqu'au `cmd.exe` ancêtre, et le termine avec `/F /T` (cascade enfants). Fonctionne sans psutil.

## instanciation

S'auto-instancie à l'import sous `deva.utils` si absent. Les autres modules appellent `deva.utils.copyfile(...)` directement.

## hors scope

- Pas de gestion de retry sur les requêtes HTTP de `request` (sauf code 429) ; les sessions Google, elles, passent par `dvhttp.robuste` (connexion seule).
- Pas d'abstraction réseau avancée (pas de session, pas de cookies).
