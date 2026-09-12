"""Declenche le balayeur de relance depuis le poste, et rend son rapport.

Deux usages, et ce sont deux choses differentes :

    # LA PASSE COMPLETE, en simulation : elle enumere, choisit les motifs, dit
    # qui elle aurait joint et pourquoi elle a ecarte les autres. N'ENVOIE RIEN.
    python pulse_bench.py

    # LA PASSE COMPLETE, pour de vrai. Les cadences, le silence et les fenetres
    # d'envoi s'appliquent : a 15 h un mercredi, elle ne joindra personne.
    python pulse_bench.py --send

    # LE BANC : un motif force sur un clan, immediatement, par le chemin reel.
    # Ni cadence, ni silence, NI FENETRE D'ENVOI -- c'est tout l'interet.
    # Aucun etat n'est ecrit : le palier de relance n'est pas consomme.
    python pulse_bench.py --clan <clanId> --force validation --send

Motifs : onboarding_empty, onboarding_idle, onboarding_alone, validation,
         chest_full, chest_empty, boss, comeback.

⚠ `PULSE_DRY_RUN` NE TE CONCERNE PAS. Cette variable d'environnement ne muselle
  que le PLANIFICATEUR : Cloud Scheduler POSTe un corps vide, sans parametre
  d'URL, et retombe donc sur elle. Ce script, lui, passe `dry` explicitement a
  chaque appel, et le parametre d'URL PRIME (`config.yml`, `const dry = q.dry
  !== undefined ? ... : DRY_ENV`). `--send` envoie donc pour de vrai meme quand
  le balayeur automatique est encore en simulation -- c'est tout l'interet :
  eprouver avant d'ouvrir, sans qu'une passe parte dans le dos.

Trois choses a savoir avant de s'etonner d'un echec :

  1. `pulse_sweeper` est en `trigger: http`, donc PRIVEE. Il faut un jeton
     d'IDENTITE (pas un jeton d'acces) dont l'audience est l'URL exacte du
     service, et une identite portant `run.invoker`. Le compte maitre l'a, et
     `invoker:` dans backend/config.yml le nomme explicitement pour que ca reste
     vrai le jour ou les droits larges du projet seront resserres.
  2. L'URL n'est pas devinable : elle est rendue par Pulumi au deploiement et
     rangee dans l'etat. On la lit, on ne la fabrique pas.
  3. gRPC est bloque sur ce poste : REST partout, jamais google.cloud.firestore.

Usage :
    C:\\Asura\\Tools\\Python312\\python.exe E:\\Deva\\projects\\suites\\ddust\\build\\tools\\pulse_bench.py
"""

import argparse
import json
import sys

import yaml
from google.auth.transport.requests import AuthorizedSession, Request
from google.oauth2 import service_account

CLOUD_YML = r"E:\Deva\deva\deva-cloud.yml"

# Le document d'etat est nomme d'apres la SUITE, pas d'apres le projet GCP. Viser
# `dvddust` rend un 404 silencieux -- c'est le meme piege que pour la roadmap.
SUITE = "ddust"

MOTIFS = ("onboarding_empty", "onboarding_idle", "onboarding_alone", "validation",
          "chest_full", "chest_empty", "boss", "comeback")


def _master_sa():

            """La clef du compte de service maitre. L'ADC du poste est expire, et
            c'est de toute facon cette identite-la qui porte `run.invoker`."""

            with open(CLOUD_YML, encoding="utf-8") as fh:
                conf = yaml.safe_load(fh)
            return conf["cloud"]["master"]["service_account"]


def _function_url(sa, region, function):

            """L'URL du service, lue dans l'etat provisionne.

            Les clefs de `cloud_functions` sont PREFIXEES par region
            (`eu-pulse_sweeper`) : une fonction deployee dans deux regions donne
            deux services, et ils ne sont pas interchangeables -- chacun balaye les
            donnees de SA region."""

            creds = service_account.Credentials.from_service_account_info(
                sa, scopes=["https://www.googleapis.com/auth/cloud-platform"])
            session = AuthorizedSession(creds)
            url = ("https://firestore.googleapis.com/v1/projects/{}/databases/(default)"
                   "/documents/deva_builds/{}".format(sa["project_id"], SUITE))
            resp = session.get(url, timeout=30)
            if resp.status_code != 200:
                raise SystemExit(
                    "etat introuvable ({}) : {}\n"
                    "Le backend a-t-il deja ete deploye ?".format(resp.status_code, url))

            fields = resp.json().get("fields", {})
            fns = (fields.get("cloud_functions", {})
                         .get("mapValue", {}).get("fields", {}))
            key = "{}-{}".format(region, function)
            if key not in fns:
                raise SystemExit(
                    "'{}' absent de l'etat. Connues : {}".format(
                        key, ", ".join(sorted(fns)) or "aucune"))

            # Sans slash final : l'audience du jeton doit correspondre au CARACTERE
            # PRES a ce que Cloud Run attend, et un slash de trop rend un 403 sans
            # la moindre explication.
            return fns[key].get("stringValue", "").rstrip("/")


def _identity_session(sa, audience):

            """Une session portant un jeton d'IDENTITE pour cette audience.

            Un jeton d'acces (celui qu'on utilise pour Firestore) ne passe PAS :
            Cloud Run authentifie l'appelant sur un jeton d'identite, dont
            l'audience est l'URL du service."""

            creds = service_account.IDTokenCredentials.from_service_account_info(
                sa, target_audience=audience)
            creds.refresh(Request())
            return AuthorizedSession(creds)


def main():

            p = argparse.ArgumentParser(
                description="Declenche le balayeur de relance et rend son rapport.")
            p.add_argument("--clan", default="",
                           help="identifiant du clan (obligatoire avec --force)")
            p.add_argument("--force", default="", choices=("",) + MOTIFS,
                           help="motif a forcer : le banc, sans cadence ni fenetre")
            p.add_argument("--send", action="store_true",
                           help="envoyer POUR DE VRAI, meme si PULSE_DRY_RUN vaut "
                                "true (cette variable ne muselle que le "
                                "planificateur). Sans lui : simulation.")
            p.add_argument("--region", default="eu", help="region de donnees (defaut: eu)")
            args = p.parse_args()

            if args.force and not args.clan:
                raise SystemExit("--force exige --clan : le banc vise un clan precis.")
            if args.clan and not args.force:
                raise SystemExit("--clan exige --force : sans motif, rien a forcer.")

            sa  = _master_sa()
            url = _function_url(sa, args.region, "pulse_sweeper")

            params = {"dry": "0" if args.send else "1"}
            if args.force:
                params["force"] = args.force
                params["clan"] = args.clan

            quoi = ("banc : {} sur {}".format(args.force, args.clan) if args.force
                    else "passe complete")
            print("{}  [{}]  {}".format(
                quoi, args.region, "ENVOI REEL" if args.send else "simulation"))
            print(url)
            print()

            session = _identity_session(sa, url)
            # `timeout` de la fonction : 540 s. On laisse une marge plutot que de
            # couper une passe qui, elle, ira jusqu'au bout cote serveur.
            resp = session.get(url, params=params, timeout=600)

            if resp.status_code == 403:
                raise SystemExit(
                    "403 : cette identite n'a pas le droit d'appeler la fonction.\n"
                    "Verifier `invoker:` sur pulse_sweeper dans backend/config.yml,\n"
                    "et surtout que le backend a ete REDEPLOYE depuis.")
            if resp.status_code != 200:
                raise SystemExit("HTTP {} : {}".format(resp.status_code, resp.text[:800]))

            try:
                rapport = resp.json()
            except ValueError:
                raise SystemExit("reponse illisible : " + resp.text[:800])

            print(json.dumps(rapport, indent=2, ensure_ascii=False, sort_keys=True))

            # Le seul chiffre qui compte se lit mal au milieu du reste.
            if not args.force:
                print("\n{} notification(s) partie(s){}".format(
                    rapport.get("notified", 0),
                    "" if args.send else "  (simulation : rien n'a quitte le serveur)"))
            return 0


if __name__ == "__main__":
            sys.exit(main())
