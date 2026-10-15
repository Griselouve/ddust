# FICHIER GÉNÉRÉ, Ne pas modifier, sera écrasé au prochain build
# Source: resources/base/dvutils/dvhttp.py
# -----------------------------------------------------------------------------
# --- This file is part of the DEVA framework
# --- Copyright (C) 2026 Griselouve - deva@grisloup.com
#
# This file is part of DEVA.
#
# DEVA is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# DEVA is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# -----------------------------------------------------------------------------
"""dvhttp : les sessions HTTP des API Google, rendues robustes aux connexions perdues.

LE CONSTAT (2026-09-25). Depuis le poste de build, environ une connexion TCP neuve sur
vingt vers `firestore.googleapis.com` n'aboutit jamais : elle reste pendue au lieu
d'echouer. Une `AuthorizedSession` nue attend alors 120 s, puis leve, SANS JAMAIS
REESSAYER. Le builder ouvre des dizaines de connexions par run : l'echec tombait au
hasard, sur une lecture comme sur l'ecriture de l'etat de publication.

LE REMEDE, ET SES LIMITES VOULUES.
  - un delai de CONNEXION court (10 s), le delai de LECTURE inchange (120 s) ;
  - des tentatives repetees sur la CONNEXION SEULEMENT (4, avec attente croissante).

⚠ ON NE REESSAIE JAMAIS UNE LECTURE DE REPONSE, NI UN STATUT HTTP. Une connexion qui
  n'a pas abouti n'a rien envoye : la rejouer est sans risque, meme pour un PATCH ou
  un POST. Une requete partie dont la reponse tarde a peut-etre ete executee : la
  rejouer pourrait ecrire deux fois (un commit Play, une creation de catalogue).
"""

CONNECT_TIMEOUT = 10
READ_TIMEOUT    = 120
CONNECT_RETRIES = 4


def robuste(session):

    """Rend `session` (une requests.Session ou AuthorizedSession) robuste. La rend.

    ⚠ LE TIMEOUT DE L'APPELANT RESTE CELUI DE LA LECTURE. Un televersement d'AAB passe
      1800 s, un appel Play 120 s : ils les gardent pour attendre la reponse, mais la
      CONNEXION, elle, est bornee a 10 s. Sans cela, un nombre seul (120) valait aussi
      pour la connexion, et une connexion pendue coutait deux minutes par tentative.
      Un couple (connexion, lecture) explicite est respecte tel quel.
    """
    from requests.adapters import HTTPAdapter
    from urllib3.util.retry import Retry

    retry = Retry(
        total=None,
        connect=CONNECT_RETRIES,
        read=0,
        status=0,
        other=0,
        backoff_factor=1.0,
        allowed_methods=None,      # toutes : seule la CONNEXION est rejouee
        raise_on_status=False,
    )
    adaptateur = HTTPAdapter(max_retries=retry)
    session.mount("https://", adaptateur)
    session.mount("http://", adaptateur)

    origine = session.request

    def request(method, url, *args, **kwargs):

        delai = kwargs.get("timeout", None)
        if delai is None:
            kwargs["timeout"] = (CONNECT_TIMEOUT, READ_TIMEOUT)
        elif isinstance(delai, (int, float)):
            kwargs["timeout"] = (min(CONNECT_TIMEOUT, delai), delai)
        return origine(method, url, *args, **kwargs)

    session.request = request
    return session
