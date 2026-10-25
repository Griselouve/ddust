"""Contrôles MÉTIER de la vitrine ddust (dvshowcase, `showcase.checks.scripts`).

La vitrine relève, à chaque capture, les textes affichés (un JSON par capture dans
`<rapport>/data/<cas>/<langue>/<capture>.json`) puis lance ce script en fin de boucle :

    main.py --data <dossier data>

Sans `--data` (lancé depuis la console), il relit le dernier rapport, dans le workspace
(2026-10-25, les prises n'écrivent plus dans le dépôt) : `deva/workspace/ddust/showcase/_report/data`.

Il écrit ses anomalies sur la sortie standard, une par ligne, en JSON, au format du
rapport de la vitrine : {"cat", "case", "langs", "capture", "text", "detail"}.

Contrôles :
  - le VOCABULAIRE INTERDIT par cas (vocabulaire.yml), par exemple les mots de donjon dans
    le thème dino ;
  - les TRADUCTIONS DES THÈMES : dans ddust, chaque texte vit dans chaque thème (jamais dans
    le commun). Toute clé de `lang.translations` du thème donjon doit exister dans chaque
    autre thème MAJEUR (catalogue `theme.themes`, mini-thèmes exclus), avec les mêmes
    langues. Lu dans les layers, pas dans les relevés : un texte que la vitrine n'affiche
    jamais (une demande en attente, une erreur) est contrôlé quand même ;
  - les LAYERS PÉRIMÉS : la vitrine sert les layers cloud depuis le cache local de la
    machine (le bucket), pas depuis `resources_cloud`. Un layer du cache qui diffère du
    source = un layer jamais publié : ses textes neufs s'affichent en clés brutes chez
    tous les joueurs. Pas de cache (machine neuve) : contrôle sauté.
"""
import argparse
import json
import os
import re
import sys

import yaml

ICI = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.normpath(os.path.join(ICI, "..", "..", "build"))
DEFAUT = os.path.normpath(os.path.join(BUILD, "..", "..", "..", "..", "deva", "workspace", "ddust",
                                       "showcase", "_report", "data"))
CLOUD = os.path.join(BUILD, "resources_cloud")
CATALOGUE = os.path.join(CLOUD, "general", "layers", "assets-global.yml")
REFERENCE = "theme-donjon"


def _yaml(chemin):
    with open(chemin, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def _traductions_du_theme(entree):
    """Les `lang.translations` fusionnées des layers d'un thème du catalogue. Un chemin
    `layers/x.yml` se cherche sous chacune de ses racines (`manifests`), de la plus
    spécifique à la plus générale ; un chemin `racine/layers/x.yml` est déjà complet."""
    trads = {}
    for rel in entree.get("layers") or []:
        candidats = [os.path.join(CLOUD, m, rel) for m in reversed(entree.get("manifests") or [])]
        candidats.append(os.path.join(CLOUD, rel))
        chemin = next((c for c in candidats if os.path.isfile(c)), None)
        if chemin is None:
            print(f"layer introuvable : {rel}", file=sys.stderr)
            continue
        donnees = _yaml(chemin)
        donnees = donnees.get("data", donnees)
        for cle, langues in ((donnees.get("lang") or {}).get("translations") or {}).items():
            trads.setdefault(cle, {}).update(langues if isinstance(langues, dict) else {})
    return trads


def controle_themes():
    """Chaque clé du thème de référence, dans chaque autre thème majeur, avec ses langues."""
    themes = ((_yaml(CATALOGUE).get("data") or {}).get("theme") or {}).get("themes") or {}
    if REFERENCE not in themes:
        print(f"thème de référence absent du catalogue : {REFERENCE}", file=sys.stderr)
        return 0
    ref = _traductions_du_theme(themes[REFERENCE])
    n = 0
    for nom, entree in themes.items():
        if nom == REFERENCE:
            continue
        autre = _traductions_du_theme(entree)
        cas = nom.removeprefix("theme-")
        for cle in sorted(ref):
            attendues = set(ref[cle])
            if cle not in autre:
                manque, detail = attendues, f"clé absente de {nom} (présente dans {REFERENCE})"
            else:
                manque = attendues - set(autre[cle])
                detail = f"langue(s) absente(s) de {nom} : " + ", ".join(sorted(manque))
            if not manque:
                continue
            print(json.dumps({
                "cat": "traduction_theme",
                "case": cas,
                "langs": sorted(manque),
                "capture": "",
                "page": "",
                "text": cle,
                "detail": detail,
            }, ensure_ascii=False))
            n += 1
    print(f"{n} anomalie(s) de traduction entre thèmes", file=sys.stderr)
    return n


CACHE = os.path.join(os.environ.get("LOCALAPPDATA", ""), "com.grisloup", "ddust_client", "dvassets")


def controle_layers():
    """Chaque layer de `resources_cloud/<racine>/layers` comparé à sa copie du cache cloud."""
    if not os.path.isdir(CACHE):
        print(f"cache cloud absent ({CACHE}) : layers non comparés", file=sys.stderr)
        return 0
    n = 0
    for racine in sorted(os.listdir(CLOUD)):
        dossier = os.path.join(CLOUD, racine, "layers")
        if not os.path.isdir(dossier):
            continue
        for nom in sorted(os.listdir(dossier)):
            if not nom.endswith(".yml"):
                continue
            servi = os.path.join(CACHE, racine, "layers", nom)
            if not os.path.isfile(servi):
                continue
            source, cache = _yaml(os.path.join(dossier, nom)), _yaml(servi)
            if source == cache:
                continue
            ts = set((((source.get("data") or {}).get("lang") or {}).get("translations") or {}))
            tc = set((((cache.get("data") or {}).get("lang") or {}).get("translations") or {}))
            manquent = sorted(ts - tc)
            detail = "le bucket sert une version différente du source"
            if manquent:
                detail += f" ; {len(manquent)} traduction(s) absente(s) du bucket : " + ", ".join(manquent[:12]) + (" …" if len(manquent) > 12 else "")
            print(json.dumps({
                "cat": "layer_perime",
                "case": "",
                "langs": [],
                "capture": "",
                "page": "",
                "text": f"{racine}/layers/{nom}",
                "detail": detail + " (à publier : push-assets)",
            }, ensure_ascii=False))
            n += 1
    print(f"{n} layer(s) périmé(s) dans le cache cloud", file=sys.stderr)
    return n


def main():
    # Les deux flux : la vitrine décode aussi stderr en UTF-8 (un « è » en cp1252 l'y fait échouer).
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    ap =argparse.ArgumentParser()
    ap.add_argument("--data", default=DEFAUT)
    args = ap.parse_args()

    controle_themes()
    controle_layers()

    with open(os.path.join(ICI, "vocabulaire.yml"), encoding="utf-8") as f:
        voc = yaml.safe_load(f) or {}
    allow = [re.compile(a, re.I) for a in voc.get("allow", [])]
    regles = {
        cas: {lang: [re.compile(x, re.I) for x in pats] for lang, pats in (langs or {}).items()}
        for cas, langs in (voc.get("cases") or {}).items()
    }

    if not os.path.isdir(args.data):
        print(f"dossier introuvable : {args.data}", file=sys.stderr)
        return 1

    n = 0
    for cas, par_langue in regles.items():
        base = os.path.join(args.data, cas)
        if not os.path.isdir(base):
            continue
        for lang, pats in par_langue.items():
            dossier = os.path.join(base, lang)
            if not os.path.isdir(dossier):
                continue
            for nom in sorted(os.listdir(dossier)):
                if not nom.endswith(".json"):
                    continue
                with open(os.path.join(dossier, nom), encoding="utf-8") as f:
                    rel = json.load(f)
                for t in rel.get("texts", []):
                    texte = t.get("text", "")
                    nettoye = texte
                    for a in allow:
                        nettoye = a.sub(" ", nettoye)
                    trouves = sorted({m.group(0) for p in pats for m in p.finditer(nettoye)})
                    if not trouves:
                        continue
                    print(json.dumps({
                        "cat": "vocabulaire",
                        "case": cas,
                        "langs": [lang],
                        "capture": rel.get("capture", nom[:-5]),
                        "page": rel.get("page", ""),
                        "i": t.get("i"),
                        "text": texte,
                        "detail": "mot(s) d'un autre thème : " + ", ".join(trouves),
                    }, ensure_ascii=False))
                    n += 1
    print(f"{n} anomalie(s) de vocabulaire", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
