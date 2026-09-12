#!/usr/bin/env python3
"""Dérive le corpus légal d'un marché à partir de celui d'un autre.

Contexte : décision du 2026-08-27. La « région » que choisit le joueur est
désormais un MARCHÉ (`fr`, `euo`, …) et non plus un datacenter. Chaque marché
porte donc ses propres documents, quitte à ce qu'ils soient d'abord une copie
conforme de ceux d'un marché voisin — la France et l'Allemagne partagent le
RGPD. Le coût de la copie est nul ; celui d'un niveau d'indirection de plus ne
l'était pas.

Ce script n'est PAS un bump de version (voir `gen_cgu_next.py`, qui archive un
bump daté). Il dérive un corpus complet vers un marché neuf, et le fait
repartir à **v1** : un nouveau marché n'hérite pas de l'historique d'un autre,
il commence le sien. Les documents du marché source ne sont jamais touchés —
ils restent la preuve de ce que les utilisateurs existants ont accepté.

Chaque substitution est vérifiée : une occurrence attendue, sinon le script
échoue. Un document légal généré à moitié est pire que pas de document du tout.

    python tools/derive_market_corpus.py            # écrit
    python tools/derive_market_corpus.py --check    # vérifie sans écrire
"""

import re
import sys
from pathlib import Path

DOCS = Path(__file__).parent.parent / "legal" / "documents"

# (marché source, marché cible). La source est lue à sa version la plus haute,
# la cible est toujours écrite en v1.
DERIVATIONS = [
    # ⚠ ("eu", "fr") RETIRÉ LE 2026-08-28, avec le corpus `eu` lui-même. Il était
    #   conservé « comme preuve », mais l'application n'a jamais été publiée : nul
    #   n'a accepté ces documents, il n'y avait donc rien à prouver. Le laisser
    #   n'aurait fait qu'un treizième jeu de douze fichiers à relire à chaque
    #   révision. `fr` est désormais la souche européenne, `us` la souche américaine.
    # ⚠ LA RÈGLE A CHANGÉ LE 2026-08-28, et il faut dire pourquoi. Elle disait
    #   « n'ajouter un marché ici qu'au moment de l'ouvrir », parce qu'un corpus
    #   dérivé était alors « identique à celui de `fr` au mot près » : douze
    #   fichiers à re-versionner à chaque révision, pour rien.
    #
    #   Ce n'est plus vrai. Depuis que `_market_blocks` porte les écarts de fond —
    #   autorité de contrôle, fourchette de l'article 8, et pour `eun` la Norvège
    #   qui n'est pas dans l'Union — un corpus dérivé DIT quelque chose que celui
    #   de `fr` ne dit pas. Le rédiger avant d'ouvrir a donc un sens : c'est la
    #   rédaction, et non la déclaration, qui est le long du chemin.
    #
    # ⚠ ÉCRIRE UN CORPUS N'OUVRE PAS UN MARCHÉ. L'ouverture reste le dernier
    #   geste, dans `build.yml → documents.regions`, et le build refuse l'ordre
    #   inverse. Ces quatre corpus existent ; aucun n'est servi.
    ("fr", "euo"),
    ("fr", "eus"),
    ("fr", "eun"),
    ("fr", "eux"),
    # Dérivé de `fr` et non de `us` : le UK GDPR est une reprise du RGPD, la
    # structure des documents européens lui va. C'est le profil de REVENUS que le
    # build.yml copie des États-Unis, pas le droit.
    ("fr", "uk"),
    ("fr", "ch"),
    # ⚠ SEULE DÉRIVATION QUI NE PART PAS DE `fr`, et le `cloud` l'impose : `ca` vit
    #   dans le datacenter `us`. Partir de `fr` ferait pointer les liens vers le
    #   bucket européen — `_retarget_links` ne réécrit jamais le bucket — et ferait
    #   annoncer un stockage dans l'Union qui serait faux.
    ("us", "ca"),
    ("us", "oceanie"),
    ("us", "bresil"),
    ("us", "hispam"),
]

# ⚠ SEPT LANGUES DEPUIS LE 2026-09-08. Les quatre dernieres — it, de, pt, nl —
#   etaient declarees dans `langues` du build.yml depuis le 2026-08-26 mais
#   n'existaient nulle part dans le corpus. L'ecart ne se voyait pas : le
#   controle de completude du build ne teste que `default_language`, et
#   dvdocuments.getDoc() renvoie null sans repli — un joueur italien aurait eu
#   un lien « lire les conditions » mort, sans erreur nulle part.
# ⚠ L'ORDRE EST CELUI DU BUILD.YML : priorite, pas alphabet.
LANGS = ("fr", "en", "es", "it", "de", "pt", "nl")
STATES = ("a", "k")
DOC_TYPES = ("cgu", "privacy")

# Libellé de région, par marché cible puis par langue du document.
# ⚠ Ce n'est PLUS le seul endroit où un marché se nomme en clair dans le corpus,
#   et l'avoir cru a coûté six mentions fautives. Le corpus `fr`, dérivé de `eu`,
#   a porté pendant tout son passage en piste fermée des phrases annonçant au
#   joueur français que « les présentes conditions sont celles de la région Union
#   Européenne » — parce que seul l'en-tête était réécrit. Le corps l'est
#   désormais aussi (voir BODY_REGION et `_set_region_body`).
#
# ⚠ Ouvrir un marché de plus, c'est ajouter une entrée ici — et vérifier que le
#   texte dit toujours vrai pour lui, ce qu'aucun script ne saura faire à ta
#   place. Les six écarts de fond à porter à la main (autorité de contrôle,
#   organe de médiation, fourchette de l'article 8 RGPD, loi applicable,
#   reconduction, langue du contrat) ne sont PAS produits par ce script.
#
# ⚠ L'ORGANE DE MÉDIATION A CHANGÉ DE STATUT LE 2026-09-09, et c'est le seul des
#   six à ne plus être un manque. `set_consumer_mediation.py` a posé la
#   désignation de CM2C (art. L616-1) au §12 des CGU ADULTES de la souche `fr`.
#   Elle est donc DANS la souche : un marché dérivé de `fr` l'hérite par simple
#   copie, sans rien faire — ce qui est juste pour un marché de l'Union.
#   ⚠ Mais elle s'hérite en silence, y compris là où elle serait fausse. Ouvrir
#     un marché hors du champ de la directive 2013/11 en le dérivant de `fr`
#     produirait un document qui offre un médiateur français à un consommateur
#     qui ne peut pas le saisir utilement. Deux issues, jamais l'oubli : dériver
#     de `us`, dont le §12 renvoie aux autorités locales, ou ajouter au marché un
#     bloc qui retire la clause. `check_corpus.MARCHES_MEDIATION` est la liste
#     qui fait foi, et il faut l'y déclarer dans les deux cas.
REGION_LABEL = {
    # `eu` n'est plus servi à personne, mais reste la SOURCE de la dérivation
    # historique : `_set_region_body` lit le libellé du marché source pour bâtir
    # ses motifs, et l'omettre ferait échouer la dérivation sur un KeyError.
    "eu":  {"fr": "Union Européenne",    "en": "European Union", "es": "Unión Europea",
            "it": "Unione Europea", "de": "Europäische Union", "pt": "União Europeia",
            "nl": "Europese Unie"},
    "fr":  {"fr": "France",             "en": "France",         "es": "Francia",
            "it": "Francia", "de": "Frankreich", "pt": "França", "nl": "Frankrijk"},
    "euo": {"fr": "Europe de l'Ouest",  "en": "Western Europe", "es": "Europa Occidental",
            "it": "Europa occidentale", "de": "Westeuropa", "pt": "Europa Ocidental",
            "nl": "West-Europa"},
    "eus": {"fr": "Europe du Sud",      "en": "Southern Europe", "es": "Europa Meridional",
            "it": "Europa meridionale", "de": "Südeuropa", "pt": "Europa do Sul",
            "nl": "Zuid-Europa"},
    "eun": {"fr": "Europe du Nord",     "en": "Northern Europe", "es": "Europa Septentrional",
            "it": "Europa settentrionale", "de": "Nordeuropa", "pt": "Europa do Norte",
            "nl": "Noord-Europa"},
    # ⚠ LIBELLÉ PROVISOIRE. `eux` regroupe GR SK SI EE LV LT CY HR — ni « centrale »,
    #   ni « orientale » ne les couvre (la Grèce et Chypre ne sont ni l'une ni
    #   l'autre), et le « reste de l'Europe » du build.yml est une commodité
    #   interne qu'on ne sert pas à un lecteur. À trancher avant toute ouverture.
    "eux": {"fr": "Union européenne — autres pays",
            "en": "European Union — other countries",
            "es": "Unión Europea — otros países",
            "it": "Unione europea — altri paesi",
            "de": "Europäische Union — weitere Länder",
            "pt": "União Europeia — outros países",
            "nl": "Europese Unie — overige landen"},
    "uk":  {"fr": "Royaume-Uni",         "en": "United Kingdom", "es": "Reino Unido",
            "it": "Regno Unito", "de": "Vereinigtes Königreich", "pt": "Reino Unido",
            "nl": "Verenigd Koninkrijk"},
    "ch":  {"fr": "Suisse",              "en": "Switzerland",    "es": "Suiza",
            "it": "Svizzera", "de": "Schweiz", "pt": "Suíça", "nl": "Zwitserland"},
    "us":  {"fr": "États-Unis",          "en": "United States",  "es": "Estados Unidos",
            "it": "Stati Uniti", "de": "Vereinigte Staaten", "pt": "Estados Unidos",
            "nl": "Verenigde Staten"},
    "ca":  {"fr": "Canada",              "en": "Canada",         "es": "Canadá",
            "it": "Canada", "de": "Kanada", "pt": "Canadá", "nl": "Canada"},
    "oceanie": {"fr": "Océanie",          "en": "Oceania",        "es": "Oceanía",
            "it": "Oceania", "de": "Ozeanien", "pt": "Oceania", "nl": "Oceanië"},
    "bresil":  {"fr": "Brésil",           "en": "Brazil",         "es": "Brasil",
            "it": "Brasile", "de": "Brasilien", "pt": "Brasil", "nl": "Brazilië"},
    # ⚠ NOM DE MARCHÉ, PAS ÉNUMÉRATION. Le marché ne porte que MX et CO, mais les
    #   nommer dans l'en-tête obligerait l'espagnol à accorder au pluriel dans les
    #   documents enfants (« Aquí son… »). Les deux pays sont nommés là où ça
    #   compte : dans les clauses de fond.
    "hispam":  {"fr": "Amérique hispanophone", "en": "Spanish-speaking America", "es": "Hispanoamérica",
            "it": "America ispanofona", "de": "Spanischsprachiges Amerika",
            "pt": "América hispanófona", "nl": "Spaanstalig Amerika"},
}

# Forme AVEC ARTICLE. Deux phrases du corpus font précéder le libellé d'un article,
# et il ne suit pas les mêmes règles d'une langue à l'autre.
#
# ⚠ LES TROIS LANGUES EN ONT BESOIN, contrairement à ce qui a d'abord été écrit ici.
#   Le français était le seul cas visible tant que les marchés s'appelaient « Europe
#   du Nord » — un nom que l'anglais et l'espagnol prennent sans article. Le
#   Royaume-Uni a révélé le défaut : la première dérivation produisait « for United
#   Kingdom » et « para Reino Unido », qui sont fautifs dans les deux langues.
#
# Un marché absent d'une langue reprend son libellé nu : c'est le cas de tous les
# noms de région en anglais et en espagnol, sauf le Royaume-Uni.
REGION_ARTICLE = {
    "fr": {
        "eu":  "l'Union Européenne",
        "fr":  "la France",
        "euo": "l'Europe de l'Ouest",
        "eus": "l'Europe du Sud",
        "eun": "l'Europe du Nord",
        "eux": "l'Union européenne — autres pays",
        "uk":  "le Royaume-Uni",
        "ch":  "la Suisse",
        "us":  "les États-Unis",
        "ca":  "le Canada",
        "oceanie": "l'Océanie",
        "bresil":  "le Brésil",
        "hispam":  "l'Amérique hispanophone",
    },
    "en": {"uk": "the United Kingdom", "us": "the United States", "ca": "Canada"},
    "es": {"uk": "el Reino Unido",     "us": "los Estados Unidos", "ca": "Canadá"},
    "it": {
        "eu":  "l'Unione Europea",
        "fr":  "la Francia",
        "euo": "l'Europa occidentale",
        "eus": "l'Europa meridionale",
        "eun": "l'Europa settentrionale",
        "eux": "l'Unione europea — altri paesi",
        "uk":  "il Regno Unito",
        "ch":  "la Svizzera",
        "us":  "gli Stati Uniti",
        "ca":  "il Canada",
        "oceanie": "l'Oceania",
        "bresil":  "il Brasile",
        "hispam":  "l'America ispanofona",
    },
    # ⚠ L'ALLEMAND N'EST PAS L'ITALIEN : la plupart des noms de pays y sont NEUTRES
    #   et sans article. N'en mettre que la ou la langue l'exige — sinon on produit
    #   « Hier ist es das Frankreich », qui n'est pas allemand.
    "de": {
        "eu":  "die Europäische Union",
        "eux": "die Europäische Union — weitere Länder",
        "uk":  "das Vereinigte Königreich",
        "ch":  "die Schweiz",
        "us":  "die Vereinigten Staaten",
        "hispam": "das spanischsprachige Amerika",
    },
    "pt": {
        "eu":  "a União Europeia",
        "fr":  "a França",
        "euo": "a Europa Ocidental",
        "eus": "a Europa do Sul",
        "eun": "a Europa do Norte",
        "eux": "a União Europeia — outros países",
        "uk":  "o Reino Unido",
        "ch":  "a Suíça",
        "us":  "os Estados Unidos",
        "ca":  "o Canadá",
        "oceanie": "a Oceania",
        "bresil":  "o Brasil",
        "hispam":  "a América hispanófona",
    },
    # Meme regle qu'en allemand : article seulement ou le neerlandais en met un.
    "nl": {
        "eu":  "de Europese Unie",
        "eux": "de Europese Unie — overige landen",
        "uk":  "het Verenigd Koninkrijk",
        "us":  "de Verenigde Staten",
    },
}


def _articled(market, lang):
    """Le libellé du marché avec son article, ou nu si la langue n'en met pas."""
    return REGION_ARTICLE.get(lang, {}).get(market, REGION_LABEL[market][lang])

# Mentions du marché DANS LE CORPS du texte, par (état légal, type de document)
# puis par langue. Chaque entrée est un couple (motif, remplacement) où `{src}` et
# `{dst}` reçoivent le libellé nu et `{src_a}` / `{dst_a}` la forme avec article.
# Le motif tolère les retours à la ligne du source HTML.
#
# ⚠ CHAQUE ENTRÉE EST VÉRIFIÉE À UNE OCCURRENCE, comme les substitutions
#   d'en-tête. Une phrase reformulée dans le corpus source fera donc échouer la
#   dérivation au lieu de produire un document à moitié régionalisé.
BODY_REGION = {
    ("a", "cgu"): {
        "fr": [(r"sont\s+celles\s+de\s+la\s+région\s+{src}", "sont celles de la région {dst}")],
        "en": [(r"are\s+those\s+of\s+the\s+{src}\s+region", "are those of the {dst} region")],
        "es": [(r"son\s+las\s+de\s+la\s+región\s+{src}",    "son las de la región {dst}")],
        "it": [(r"sono\s+quelle\s+della\s+regione\s+{src}", "sono quelle della regione {dst}")],
        "de": [(r"sind\s+die\s+der\s+Region\s+{src}",       "sind die der Region {dst}")],
        "pt": [(r"são\s+as\s+da\s+região\s+{src}",          "são as da região {dst}")],
        "nl": [(r"zijn\s+die\s+van\s+de\s+regio\s+{src}",  "zijn die van de regio {dst}")],
    },
    ("a", "privacy"): {
        "fr": [(r"\(aujourd'hui\s*:\s*{src}\)",                     "(aujourd'hui : {dst})"),
               (r"\(pour\s+{src_a}\s*:\s*des\s+centres",            "(pour {dst_a} : des centres"),
               (r"politique\s+est\s+celle\s+de\s+la\s+région\s+{src}",
                "politique est celle de la région {dst}")],
        "en": [(r"\(today:\s*{src}\)",                              "(today: {dst})"),
               (r"\(for\s+{src_a}:\s*data\s+centres",               "(for {dst_a}: data centres"),
               (r"policy\s+is\s+the\s+one\s+for\s+the\s+{src}\s+region",
                "policy is the one for the {dst} region")],
        "es": [(r"\(hoy:\s*{src}\)",                                "(hoy: {dst})"),
               (r"\(para\s+{src_a}:\s*centros",                     "(para {dst_a}: centros"),
               (r"política\s+es\s+la\s+de\s+la\s+región\s+{src}",
                "política es la de la región {dst}")],
        "it": [(r"\(oggi:\s*{src}\)",                               "(oggi: {dst})"),
               (r"\(per\s+{src_a}:\s*centri",                       "(per {dst_a}: centri"),
               (r"informativa\s+è\s+quella\s+della\s+regione\s+{src}",
                "informativa è quella della regione {dst}")],
        "de": [(r"\(heute:\s*{src}\)",                              "(heute: {dst})"),
               (r"\(für\s+{src_a}:\s*Rechenzentren",                "(für {dst_a}: Rechenzentren"),
               (r"Datenschutzerklärung\s+ist\s+die\s+der\s+Region\s+{src}",
                "Datenschutzerklärung ist die der Region {dst}")],
        "pt": [(r"\(hoje:\s*{src}\)",                               "(hoje: {dst})"),
               (r"\(para\s+{src_a}:\s*centros",                     "(para {dst_a}: centros"),
               (r"política\s+é\s+a\s+da\s+região\s+{src}",
                "política é a da região {dst}")],
        "nl": [(r"\(vandaag:\s*{src}\)",                            "(vandaag: {dst})"),
               (r"\(voor\s+{src_a}:\s*datacentra",                  "(voor {dst_a}: datacentra"),
               (r"privacybeleid\s+is\s+dat\s+van\s+de\s+regio\s+{src}",
                "privacybeleid is dat van de regio {dst}")],
    },
    ("k", "cgu"): {
        "fr": [(r"c'est\s+{src_a}",         "c'est {dst_a}")],
        "en": [(r"it\s+is\s+(?:the\s+)?{src}", "it is {dst_a}")],
        "es": [(r"es\s+(?:la\s+)?{src}",       "es {dst_a}")],
        "it": [(r"è\s+{src_a}",                 "è {dst_a}")],
        "de": [(r"ist\s+es\s+{src_a}",         "ist es {dst_a}")],
        "pt": [(r"é\s+{src_a}",                 "é {dst_a}")],
        "nl": [(r"is\s+dat\s+{src_a}",         "is dat {dst_a}")],
    },
    ("k", "privacy"): {
        "fr": [(r"c'est\s+{src_a}",         "c'est {dst_a}")],
        "en": [(r"it\s+is\s+(?:the\s+)?{src}", "it is {dst_a}")],
        "es": [(r"es\s+(?:la\s+)?{src}",       "es {dst_a}")],
        "it": [(r"è\s+{src_a}",                 "è {dst_a}")],
        "de": [(r"ist\s+es\s+{src_a}",         "ist es {dst_a}")],
        "pt": [(r"é\s+{src_a}",                 "é {dst_a}")],
        "nl": [(r"is\s+dat\s+{src_a}",         "is dat {dst_a}")],
    },
}

# Étiquettes localisées de l'en-tête. Le français met une espace avant le
# deux-points, pas les deux autres.
# ⚠ SEUL LE FRANCAIS MET UNE ESPACE AVANT LE DEUX-POINTS. Les six autres
#   langues collent, et l'oublier ferait echouer `_set_region` sur une table
#   entiere de documents — l'ancre est litterale.
REGION_TAG  = {"fr": "Région :",  "en": "Region:",  "es": "Región:",
               "it": "Regione:",  "de": "Region:",  "pt": "Região:",
               "nl": "Regio:"}
VERSION_TAG = {"fr": "Version :", "en": "Version:", "es": "Versión:",
               "it": "Versione:", "de": "Version:", "pt": "Versão:",
               "nl": "Versie:"}

# Un corpus neuf entre en vigueur à sa création, pas à celle de son modèle.
# ⚠ ALIGNÉES SUR LA DATE QUE PORTE LE CORPUS, pas sur celle de l'exécution passée :
#   la remise à plat du 2026-08-28 (`reset_corpus_v1.py`) a redaté tous les
#   documents. Dériver un marché en le datant du 27 lui donnerait une date
#   qu'aucun autre document ne porte.
DATE_ADULT = {
    "fr": "en vigueur au 28 août 2026",
    "en": "in force as of 28 August 2026",
    "es": "en vigor desde el 28 de agosto de 2026",
    "it": "in vigore dal 28 agosto 2026",
    "de": "in Kraft seit dem 28. August 2026",
    "pt": "em vigor desde 28 de agosto de 2026",
    "nl": "van kracht sinds 28 augustus 2026",
}
DATE_KID = {
    "fr": "28 août 2026",
    "en": "28 August 2026",
    "es": "28 de agosto de 2026",
    "it": "28 agosto 2026",
    "de": "28. August 2026",
    "pt": "28 de agosto de 2026",
    "nl": "28 augustus 2026",
}


def _latest_version(market, state, lang, doc):
    """Version la plus haute présente pour ce tuple, ou None."""
    versions = []
    for path in DOCS.glob(f"{market}-{state}-{lang}-{doc}-v*.html"):
        m = re.search(r"-v(\d+)\.html$", path.name)
        if m:
            versions.append(int(m.group(1)))
    return max(versions) if versions else None


def _set_region(text, lang, label, name):
    """Remplace le libellé de région de l'en-tête."""
    tag = REGION_TAG[lang]
    pattern = re.compile(re.escape(f"<strong>{tag}</strong>") + r"[^<\n]*")
    text, n = pattern.subn(f"<strong>{tag}</strong> {label}", text)
    if n != 1:
        raise SystemExit(f"[{name}] en-tête « {tag} » : {n} occurrence(s), 1 attendue.")
    return text


# =============================================================================
# LES ÉCARTS DE FOND, PAR MARCHÉ
# =============================================================================
# ⚠ CE QUI NE CHANGE PAS EST L'ESSENTIEL. Les quatre marchés sont UE/EEE, servis
#   par europe-west1, sous le même RGPD, le même DSA et les mêmes directives
#   2011/83 et 2019/770. Google est vendeur, donc la TVA — 20 % en `euo`, 21,7 %
#   en `eus`, 25 % en `eun`, 22,5 % en `eux` — ne produit aucune phrase
#   différente. Et surtout ddust exige le consentement du responsable légal
#   JUSQU'À 18 ANS PARTOUT, sans jamais user de la marge de l'article 8 RGPD :
#   c'est cette décision-là, et elle seule, qui rend le corpus recopiable.
#
# ⚠ LES DOCUMENTS `k` NE PORTENT RIEN DE RÉGIONAL — vérifié : ni autorité de
#   contrôle, ni article 8, ni droit applicable. Ils se dérivent par simple copie,
#   et cette table ne les cite donc jamais.
#
# Chaque entrée est (source littérale, remplacement). La source est compilée par
# `_as_pattern`, qui tolère les retours à la ligne du HTML, et DOIT se trouver à
# exactement une occurrence — sinon la dérivation échoue.
_EDPB = {
    "fr": '(coordonnées sur <a href="https://www.edpb.europa.eu/about-edpb/about-edpb/members_fr">edpb.europa.eu</a>)',
    "en": '(contact details at <a href="https://www.edpb.europa.eu/about-edpb/about-edpb/members_en">edpb.europa.eu</a>)',
    "es": '(datos de contacto en <a href="https://www.edpb.europa.eu/about-edpb/about-edpb/members_es">edpb.europa.eu</a>)',
    "it": '(recapiti su <a href="https://www.edpb.europa.eu/about-edpb/about-edpb/members_it">edpb.europa.eu</a>)',
    "de": '(Kontaktdaten unter <a href="https://www.edpb.europa.eu/about-edpb/about-edpb/members_de">edpb.europa.eu</a>)',
    "pt": '(contactos em <a href="https://www.edpb.europa.eu/about-edpb/about-edpb/members_pt">edpb.europa.eu</a>)',
    "nl": '(contactgegevens op <a href="https://www.edpb.europa.eu/about-edpb/about-edpb/members_nl">edpb.europa.eu</a>)',
}

# L'autorité nommée en exemple diffère DÉJÀ d'une langue à l'autre dans le corpus
# source : la version française cite la CNIL, l'espagnole l'AEPD. On remplace donc
# une source différente par langue.
_AUTORITE_SRC = {
    "fr": '— en France, la CNIL (<a href="https://www.cnil.fr">www.cnil.fr</a>)',
    "en": '— in France, the CNIL (<a href="https://www.cnil.fr">www.cnil.fr</a>)',
    "es": '— en España, la AEPD (<a href="https://www.aepd.es">www.aepd.es</a>)',
    "it": '— in Francia, la CNIL (<a href="https://www.cnil.fr">www.cnil.fr</a>)',
    "de": '— in Frankreich, die CNIL (<a href="https://www.cnil.fr">www.cnil.fr</a>)',
    "pt": '— em França, a CNIL (<a href="https://www.cnil.fr">www.cnil.fr</a>)',
    "nl": '— in Frankrijk, de CNIL (<a href="https://www.cnil.fr">www.cnil.fr</a>)',
}

_AUTORITES = {
    "euo": {
        "fr": "— en Allemagne le BfDI et les autorités de contrôle des Länder, en Autriche la Datenschutzbehörde, "
              "en Belgique l'Autorité de protection des données, en Irlande la Data Protection Commission, "
              "au Luxembourg la CNPD, à Malte l'IDPC et aux Pays-Bas l'Autoriteit Persoonsgegevens",
        "en": "— in Germany the BfDI and the Länder supervisory authorities, in Austria the Datenschutzbehörde, "
              "in Belgium the Data Protection Authority, in Ireland the Data Protection Commission, "
              "in Luxembourg the CNPD, in Malta the IDPC and in the Netherlands the Autoriteit Persoonsgegevens",
        "es": "— en Alemania el BfDI y las autoridades de los Länder, en Austria la Datenschutzbehörde, "
              "en Bélgica la Autoridad de Protección de Datos, en Irlanda la Data Protection Commission, "
              "en Luxemburgo la CNPD, en Malta el IDPC y en los Países Bajos la Autoriteit Persoonsgegevens",
        "it": "— in Germania il BfDI e le autorità di controllo dei Länder, in Austria la Datenschutzbehörde, "
              "in Belgio l'Autorità per la protezione dei dati, in Irlanda la Data Protection Commission, "
              "in Lussemburgo la CNPD, a Malta l'IDPC e nei Paesi Bassi l'Autoriteit Persoonsgegevens",
        "de": "— in Deutschland der BfDI und die Aufsichtsbehörden der Länder, in Österreich die "
              "Datenschutzbehörde, in Belgien die Datenschutzbehörde, in Irland die Data Protection "
              "Commission, in Luxemburg die CNPD, in Malta der IDPC und in den Niederlanden die Autoriteit "
              "Persoonsgegevens",
        "pt": "— na Alemanha o BfDI e as autoridades de controlo dos Länder, na Áustria a Datenschutzbehörde, "
              "na Bélgica a Autoridade de Proteção de Dados, na Irlanda a Data Protection Commission, "
              "no Luxemburgo a CNPD, em Malta o IDPC e nos Países Baixos a Autoriteit Persoonsgegevens",
        "nl": "— in Duitsland de BfDI en de toezichthoudende autoriteiten van de Länder, in Oostenrijk de "
              "Datenschutzbehörde, in België de Gegevensbeschermingsautoriteit, in Ierland de Data Protection "
              "Commission, in Luxemburg de CNPD, in Malta de IDPC en in Nederland de Autoriteit "
              "Persoonsgegevens",
    },
    "eus": {
        "fr": "— en Espagne l'AEPD, en Italie le Garante per la protezione dei dati personali "
              "et au Portugal la CNPD",
        "en": "— in Spain the AEPD, in Italy the Garante per la protezione dei dati personali "
              "and in Portugal the CNPD",
        "es": "— en España la AEPD, en Italia el Garante per la protezione dei dati personali "
              "y en Portugal la CNPD",
        "it": "— in Spagna l'AEPD, in Italia il Garante per la protezione dei dati personali "
              "e in Portogallo la CNPD",
        "de": "— in Spanien die AEPD, in Italien der Garante per la protezione dei dati personali "
              "und in Portugal die CNPD",
        "pt": "— em Espanha a AEPD, em Itália o Garante per la protezione dei dati personali "
              "e em Portugal a CNPD",
        "nl": "— in Spanje de AEPD, in Italië de Garante per la protezione dei dati personali "
              "en in Portugal de CNPD",
    },
    "eun": {
        "fr": "— au Danemark et en Norvège le Datatilsynet, en Finlande le Bureau du médiateur à la protection "
              "des données et en Suède l'IMY",
        "en": "— in Denmark and Norway the Datatilsynet, in Finland the Office of the Data Protection Ombudsman "
              "and in Sweden the IMY",
        "es": "— en Dinamarca y Noruega el Datatilsynet, en Finlandia la Oficina del Defensor de la Protección "
              "de Datos y en Suecia la IMY",
        "it": "— in Danimarca e Norvegia il Datatilsynet, in Finlandia l'Ufficio del Difensore civico per la "
              "protezione dei dati e in Svezia l'IMY",
        "de": "— in Dänemark und Norwegen das Datatilsynet, in Finnland das Büro des Datenschutzbeauftragten "
              "und in Schweden die IMY",
        "pt": "— na Dinamarca e na Noruega o Datatilsynet, na Finlândia o Gabinete do Provedor de Proteção de "
              "Dados e na Suécia a IMY",
        "nl": "— in Denemarken en Noorwegen het Datatilsynet, in Finland het Bureau van de Ombudsman voor "
              "gegevensbescherming en in Zweden de IMY",
    },
    "eux": {
        "fr": "— à Chypre le Commissaire à la protection des données à caractère personnel, en Croatie l'AZOP, "
              "en Estonie l'Andmekaitse Inspektsioon, en Grèce l'Autorité hellénique de protection des données, "
              "en Lettonie la Datu valsts inspekcija, en Lituanie la Valstybinė duomenų apsaugos inspekcija, "
              "en Slovaquie l'Úrad na ochranu osobných údajov et en Slovénie l'Informacijski pooblaščenec",
        "en": "— in Cyprus the Commissioner for Personal Data Protection, in Croatia the AZOP, "
              "in Estonia the Andmekaitse Inspektsioon, in Greece the Hellenic Data Protection Authority, "
              "in Latvia the Datu valsts inspekcija, in Lithuania the Valstybinė duomenų apsaugos inspekcija, "
              "in Slovakia the Úrad na ochranu osobných údajov and in Slovenia the Informacijski pooblaščenec",
        "es": "— en Chipre el Comisario para la Protección de Datos Personales, en Croacia la AZOP, "
              "en Estonia la Andmekaitse Inspektsioon, en Grecia la Autoridad Helénica de Protección de Datos, "
              "en Letonia la Datu valsts inspekcija, en Lituania la Valstybinė duomenų apsaugos inspekcija, "
              "en Eslovaquia la Úrad na ochranu osobných údajov y en Eslovenia el Informacijski pooblaščenec",
        "it": "— a Cipro il Commissario per la protezione dei dati personali, in Croazia l'AZOP, "
              "in Estonia l'Andmekaitse Inspektsioon, in Grecia l'Autorità ellenica per la protezione dei "
              "dati, in Lettonia la Datu valsts inspekcija, in Lituania la Valstybinė duomenų apsaugos "
              "inspekcija, in Slovacchia l'Úrad na ochranu osobných údajov e in Slovenia l'Informacijski "
              "pooblaščenec",
        "de": "— in Zypern der Beauftragte für den Schutz personenbezogener Daten, in Kroatien die AZOP, "
              "in Estland die Andmekaitse Inspektsioon, in Griechenland die Hellenische Datenschutzbehörde, "
              "in Lettland die Datu valsts inspekcija, in Litauen die Valstybinė duomenų apsaugos inspekcija, "
              "in der Slowakei das Úrad na ochranu osobných údajov und in Slowenien der Informacijski "
              "pooblaščenec",
        "pt": "— em Chipre o Comissário para a Proteção de Dados Pessoais, na Croácia a AZOP, "
              "na Estónia a Andmekaitse Inspektsioon, na Grécia a Autoridade Helénica de Proteção de Dados, "
              "na Letónia a Datu valsts inspekcija, na Lituânia a Valstybinė duomenų apsaugos inspekcija, "
              "na Eslováquia o Úrad na ochranu osobných údajov e na Eslovénia o Informacijski pooblaščenec",
        "nl": "— in Cyprus de Commissaris voor de bescherming van persoonsgegevens, in Kroatië de AZOP, "
              "in Estland de Andmekaitse Inspektsioon, in Griekenland de Helleense Autoriteit voor "
              "gegevensbescherming, in Letland de Datu valsts inspekcija, in Litouwen de Valstybinė duomenų "
              "apsaugos inspekcija, in Slowakije het Úrad na ochranu osobných údajov en in Slovenië de "
              "Informacijski pooblaščenec",
    },
}

# La NORVÈGE n'est pas un État membre : sa mention se glisse dans la phrase de
# l'article 8, sans quoi le corpus dirait « chaque État membre » puis citerait un
# pays qui n'en est pas un.
_ART8_SRC = {
    ("cgu", "fr"): "chaque État membre de fixer entre 13 et 16 ans l'âge auquel un mineur peut consentir seul (15 ans en France)",
    ("cgu", "en"): "each Member State set between 13 and 16 the age at which a minor may consent on their own (15 in France)",
    ("cgu", "es"): "cada Estado miembro fijar entre los 13 y los 16 años la edad a la que un menor puede consentir por sí solo (15 años en Francia)",
    ("privacy", "fr"): "chaque État membre fixer entre 13 et 16 ans l'âge du consentement numérique propre du mineur (15 ans en France)",
    ("privacy", "en"): "each Member State set between 13 and 16 the age of a minor's own digital consent (15 in France)",
    ("privacy", "es"): "cada Estado miembro fijar entre los 13 y los 16 años la edad del consentimiento digital propio del menor (15 años en Francia)",
    ("cgu", "it"): "a ciascuno Stato membro di fissare tra i 13 e i 16 anni l'età alla quale un minore può prestare il consenso da solo (15 anni in Francia)",
    ("cgu", "de"): "jedem Mitgliedstaat erlaubt, das Alter, ab dem eine minderjährige Person allein einwilligen kann, zwischen 13 und 16 Jahren festzulegen (15 Jahre in Frankreich)",
    ("cgu", "pt"): "a cada Estado-Membro fixar entre os 13 e os 16 anos a idade a partir da qual um menor pode consentir sozinho (15 anos em França)",
    ("cgu", "nl"): "elke lidstaat toestaat de leeftijd waarop een minderjarige zelfstandig toestemming kan geven tussen 13 en 16 jaar vast te stellen (15 jaar in Frankrijk)",
    ("privacy", "it"): "a ciascuno Stato membro fissare tra i 13 e i 16 anni l'età del consenso digitale proprio del minore (15 anni in Francia)",
    ("privacy", "de"): "jedem Mitgliedstaat überlässt, das Alter der eigenen digitalen Einwilligung des Minderjährigen zwischen 13 und 16 Jahren festzulegen (15 Jahre in Frankreich)",
    ("privacy", "pt"): "a cada Estado-Membro fixar entre os 13 e os 16 anos a idade do consentimento digital próprio do menor (15 anos em França)",
    ("privacy", "nl"): "elke lidstaat de leeftijd van de eigen digitale toestemming van de minderjarige tussen 13 en 16 jaar laat vaststellen (15 jaar in Frankrijk)",
}

# Fourchette réelle du marché. On donne l'ÉTENDUE et non un chiffre : `euo` porte
# à lui seul tout l'écart permis par l'article 8, de 13 à 16 ans.
_ART8_AGES = {
    "euo": {"fr": "13 ans en Belgique et à Malte, 14 ans en Autriche, 16 ans en Allemagne, en Irlande, au Luxembourg et aux Pays-Bas",
            "en": "13 in Belgium and Malta, 14 in Austria, 16 in Germany, Ireland, Luxembourg and the Netherlands",
            "es": "13 años en Bélgica y Malta, 14 en Austria, 16 en Alemania, Irlanda, Luxemburgo y los Países Bajos",
            "it": "13 anni in Belgio e a Malta, 14 anni in Austria, 16 anni in Germania, Irlanda, Lussemburgo e nei Paesi Bassi",
            "de": "13 Jahre in Belgien und Malta, 14 Jahre in Österreich, 16 Jahre in Deutschland, Irland, Luxemburg und den Niederlanden",
            "pt": "13 anos na Bélgica e em Malta, 14 anos na Áustria, 16 anos na Alemanha, na Irlanda, no Luxemburgo e nos Países Baixos",
            "nl": "13 jaar in België en Malta, 14 jaar in Oostenrijk, 16 jaar in Duitsland, Ierland, Luxemburg en Nederland"},
    "eus": {"fr": "13 ans au Portugal, 14 ans en Espagne et en Italie",
            "en": "13 in Portugal, 14 in Spain and Italy",
            "es": "13 años en Portugal, 14 en España e Italia",
            "it": "13 anni in Portogallo, 14 anni in Spagna e in Italia",
            "de": "13 Jahre in Portugal, 14 Jahre in Spanien und Italien",
            "pt": "13 anos em Portugal, 14 anos em Espanha e em Itália",
            "nl": "13 jaar in Portugal, 14 jaar in Spanje en Italië"},
    "eun": {"fr": "13 ans au Danemark, en Finlande, en Norvège et en Suède",
            "en": "13 in Denmark, Finland, Norway and Sweden",
            "es": "13 años en Dinamarca, Finlandia, Noruega y Suecia",
            "it": "13 anni in Danimarca, Finlandia, Norvegia e Svezia",
            "de": "13 Jahre in Dänemark, Finnland, Norwegen und Schweden",
            "pt": "13 anos na Dinamarca, na Finlândia, na Noruega e na Suécia",
            "nl": "13 jaar in Denemarken, Finland, Noorwegen en Zweden"},
    "eux": {"fr": "13 ans en Estonie et en Lettonie, 14 ans à Chypre et en Lituanie, 15 ans en Grèce et en Slovénie, 16 ans en Croatie et en Slovaquie",
            "en": "13 in Estonia and Latvia, 14 in Cyprus and Lithuania, 15 in Greece and Slovenia, 16 in Croatia and Slovakia",
            "es": "13 años en Estonia y Letonia, 14 en Chipre y Lituania, 15 en Grecia y Eslovenia, 16 en Croacia y Eslovaquia",
            "it": "13 anni in Estonia e Lettonia, 14 anni a Cipro e in Lituania, 15 anni in Grecia e Slovenia, 16 anni in Croazia e Slovacchia",
            "de": "13 Jahre in Estland und Lettland, 14 Jahre in Zypern und Litauen, 15 Jahre in Griechenland und Slowenien, 16 Jahre in Kroatien und der Slowakei",
            "pt": "13 anos na Estónia e na Letónia, 14 anos em Chipre e na Lituânia, 15 anos na Grécia e na Eslovénia, 16 anos na Croácia e na Eslováquia",
            "nl": "13 jaar in Estland en Letland, 14 jaar in Cyprus en Litouwen, 15 jaar in Griekenland en Slovenië, 16 jaar in Kroatië en Slowakije"},
}

# Incise EEE, `eun` seul : elle s'insère juste après « chaque État membre ».
_ART8_PAREN = {"fr": "15 ans en France", "en": "15 in France", "es": "15 años en Francia",
               "it": "15 anni in Francia", "de": "15 Jahre in Frankreich",
               "pt": "15 anos em França", "nl": "15 jaar in Frankrijk"}

_EEE_INCISE = {
    "fr": "chaque État membre — et, par l'accord sur l'Espace économique européen, la Norvège —",
    "en": "each Member State — and, through the European Economic Area Agreement, Norway —",
    "es": "cada Estado miembro — y, en virtud del Acuerdo sobre el Espacio Económico Europeo, Noruega —",
    "it": "ciascuno Stato membro — e, in virtù dell'accordo sullo Spazio economico europeo, la Norvegia —",
    "de": "jedem Mitgliedstaat — und, durch das Abkommen über den Europäischen Wirtschaftsraum, Norwegen —",
    "pt": "cada Estado-Membro — e, por força do Acordo sobre o Espaço Económico Europeu, a Noruega —",
    "nl": "elke lidstaat — en, krachtens de Overeenkomst betreffende de Europese Economische Ruimte, Noorwegen —",
}
_EEE_SRC = {"fr": "chaque État membre", "en": "each Member State", "es": "cada Estado miembro",
            "it": "ciascuno Stato membro", "de": "jedem Mitgliedstaat",
            "pt": "cada Estado-Membro", "nl": "elke lidstaat"}

# `eun` SEUL : la Norvège n'est pas dans l'Union, la réserve des dispositions
# impératives doit donc viser l'EEE, faute de quoi elle ne joue pas pour elle.
# La compétence relève de Lugano 2007 et non de Bruxelles I bis.
_LOI_SRC = {
    "fr": "applicables dans votre pays de résidence au sein de l'Union Européenne.",
    "en": "applicable in your country of residence within the European Union.",
    "es": "aplicables en su país de residencia dentro de la Unión Europea.",
    "it": "applicabili nel vostro paese di residenza all'interno dell'Unione Europea.",
    "de": "die in Ihrem Wohnsitzland innerhalb der Europäischen Union anwendbar sind.",
    "pt": "aplicáveis no seu país de residência dentro da União Europeia.",
    "nl": "die van toepassing zijn in uw land van verblijf binnen de Europese Unie.",
}
_LOI_EEE = {
    "fr": "applicables dans votre pays de résidence au sein de l'Union européenne ou de l'Espace économique "
          "européen. Si vous résidez en Norvège, la compétence juridictionnelle relève de la convention de "
          "Lugano du 30 octobre 2007, qui vous permet de saisir le tribunal de votre domicile.",
    "en": "applicable in your country of residence within the European Union or the European Economic Area. "
          "If you reside in Norway, jurisdiction is governed by the Lugano Convention of 30 October 2007, "
          "which allows you to bring proceedings before the court of your domicile.",
    "es": "aplicables en su país de residencia dentro de la Unión Europea o del Espacio Económico Europeo. "
          "Si reside en Noruega, la competencia jurisdiccional se rige por el Convenio de Lugano de 30 de "
          "octubre de 2007, que le permite acudir al tribunal de su domicilio.",
    "it": "applicabili nel vostro paese di residenza all'interno dell'Unione europea o dello Spazio economico "
          "europeo. Se risiedete in Norvegia, la competenza giurisdizionale è retta dalla Convenzione di Lugano "
          "del 30 ottobre 2007, che vi consente di adire il tribunale del vostro domicilio.",
    "de": "die in Ihrem Wohnsitzland innerhalb der Europäischen Union oder des Europäischen Wirtschaftsraums "
          "anwendbar sind. Wenn Sie in Norwegen wohnen, richtet sich die Zuständigkeit nach dem Übereinkommen "
          "von Lugano vom 30. Oktober 2007, das Ihnen erlaubt, das Gericht Ihres Wohnsitzes anzurufen.",
    "pt": "aplicáveis no seu país de residência dentro da União Europeia ou do Espaço Económico Europeu. Se "
          "residir na Noruega, a competência jurisdicional rege-se pela Convenção de Lugano de 30 de outubro "
          "de 2007, que lhe permite recorrer ao tribunal do seu domicílio.",
    "nl": "die van toepassing zijn in uw land van verblijf binnen de Europese Unie of de Europese Economische "
          "Ruimte. Als u in Noorwegen verblijft, wordt de rechterlijke bevoegdheid beheerst door het Verdrag "
          "van Lugano van 30 oktober 2007, dat u toelaat de rechtbank van uw woonplaats aan te spreken.",
}
_EEE_STOCKAGE_SRC = {
    "fr": "des centres de données situés dans l'UE)",
    "en": "data centres located in the EU)",
    "es": "centros de datos situados en la UE)",
    "it": "centri di dati situati nell'UE)",
    "de": "Rechenzentren in der EU)",
    "pt": "centros de dados situados na UE)",
    "nl": "datacentra gelegen in de EU)",
}
_EEE_STOCKAGE = {
    "fr": "des centres de données situés dans l'UE ; la Norvège appartenant à l'Espace économique européen, "
          "ce stockage n'emporte aucun transfert hors EEE)",
    "en": "data centres located in the EU; as Norway belongs to the European Economic Area, this storage "
          "involves no transfer outside the EEA)",
    "es": "centros de datos situados en la UE; al pertenecer Noruega al Espacio Económico Europeo, este "
          "almacenamiento no supone ninguna transferencia fuera del EEE)",
    "it": "centri di dati situati nell'UE; appartenendo la Norvegia allo Spazio economico europeo, questa "
          "archiviazione non comporta alcun trasferimento fuori dal SEE)",
    "de": "Rechenzentren in der EU; da Norwegen zum Europäischen Wirtschaftsraum gehört, bedeutet diese "
          "Speicherung keine Übermittlung außerhalb des EWR)",
    "pt": "centros de dados situados na UE; pertencendo a Noruega ao Espaço Económico Europeu, este "
          "armazenamento não implica qualquer transferência para fora do EEE)",
    "nl": "datacentra gelegen in de EU; aangezien Noorwegen tot de Europese Economische Ruimte behoort, houdt "
          "die opslag geen doorgifte buiten de EER in)",
}


# =============================================================================
# ROYAUME-UNI — le premier marché qui n'est pas une variante du droit de l'Union
# =============================================================================
# ⚠ `uk` NE SE DÉRIVE PAS COMME `euo` OU `eux`. Les quatre marchés européens
#   partagent le RGPD, le DSA et les directives consommateur : n'y changeaient que
#   des noms d'organismes. Le Royaume-Uni a son propre corpus de règles — UK GDPR,
#   Data Protection Act 2018, Consumer Rights Act 2015 — et l'Union n'y est plus
#   qu'un tiers. Chaque renvoi au droit de l'Union doit donc partir, pas être
#   renommé.
#
# ⚠ TROIS POINTS PROPRES À CE MARCHÉ, et aucun n'existait pour les quatre autres :
#     - l'âge du consentement numérique est FIXE à 13 ans (DPA 2018, art. 9), là où
#       l'article 8 du RGPD laissait chaque État choisir entre 13 et 16 ;
#     - les données sont stockées dans l'UE, donc HORS du Royaume-Uni. C'est un
#       transfert international, licite par les règlements d'adéquation britanniques
#       au bénéfice de l'EEE — mais il doit être dit ;
#     - l'Age Appropriate Design Code de l'ICO s'applique à un service susceptible
#       d'être utilisé par des enfants. C'est LE texte britannique qui vise ddust.
#
# ⚠ L'ANGLAIS Y EST NATIF, et c'est ce qui faisait du Royaume-Uni le seul des cinq
#   nouveaux marchés réellement ouvrable jusqu'au 2026-09-08. Ce n'est plus un
#   privilège : le corpus parle désormais sept langues, et `eun` comme `eux` sont
#   lisibles par la plus grande partie de leur public. Ce qui sépare encore les
#   marchés n'est plus la langue mais la RÉDACTION DES ÉCARTS DE FOND — autorité
#   de contrôle, fourchette de l'article 8, loi applicable —, qu'aucun script ne
#   produit à ta place.
_UK_ART8_SRC = {
    ("cgu", "fr"): "l'article 8 du RGPD, qui permet à chaque État membre de fixer entre 13 et 16 ans l'âge auquel un mineur peut consentir seul (15 ans en France) : nous n'utilisons jamais cette faculté et exigeons toujours le consentement du responsable légal.",
    ("cgu", "en"): "Article 8 of the GDPR, which lets each Member State set between 13 and 16 the age at which a minor may consent on their own (15 in France): we never rely on that option and always require the legal guardian's consent.",
    ("cgu", "es"): "el artículo 8 del RGPD, que permite a cada Estado miembro fijar entre los 13 y los 16 años la edad a la que un menor puede consentir por sí solo (15 años en Francia): nunca hacemos uso de esa facultad y siempre exigimos el consentimiento del responsable legal.",
    ("privacy", "fr"): "l'article 8 du RGPD, qui laisse chaque État membre fixer entre 13 et 16 ans l'âge du consentement numérique propre du mineur (15 ans en France) : nous n'utilisons jamais cette faculté.",
    ("privacy", "en"): "Article 8 of the GDPR, which lets each Member State set between 13 and 16 the age of a minor's own digital consent (15 in France): we never rely on that option.",
    ("privacy", "es"): "el artículo 8 del RGPD, que deja a cada Estado miembro fijar entre los 13 y los 16 años la edad del consentimiento digital propio del menor (15 años en Francia): nunca hacemos uso de esa facultad.",
    ("cgu", "it"): "l'articolo 8 del RGPD, che consente a ciascuno Stato membro di fissare tra i 13 e i 16 anni l'età alla quale un minore può prestare il consenso da solo (15 anni in Francia): non ci avvaliamo mai di questa facoltà ed esigiamo sempre il consenso del responsabile legale.",
    ("cgu", "de"): "Artikel 8 der DSGVO, der es jedem Mitgliedstaat erlaubt, das Alter, ab dem eine minderjährige Person allein einwilligen kann, zwischen 13 und 16 Jahren festzulegen (15 Jahre in Frankreich): wir machen von dieser Möglichkeit nie Gebrauch und verlangen stets die Einwilligung des gesetzlichen Vertreters.",
    ("cgu", "pt"): "o artigo 8.º do RGPD, que permite a cada Estado-Membro fixar entre os 13 e os 16 anos a idade a partir da qual um menor pode consentir sozinho (15 anos em França): nunca fazemos uso dessa faculdade e exigimos sempre o consentimento do responsável legal.",
    ("cgu", "nl"): "artikel 8 van de AVG, dat elke lidstaat toestaat de leeftijd waarop een minderjarige zelfstandig toestemming kan geven tussen 13 en 16 jaar vast te stellen (15 jaar in Frankrijk): wij maken nooit gebruik van die mogelijkheid en eisen steeds de toestemming van de wettelijke vertegenwoordiger.",
    ("privacy", "it"): "l'articolo 8 del RGPD, che lascia a ciascuno Stato membro fissare tra i 13 e i 16 anni l'età del consenso digitale proprio del minore (15 anni in Francia): non ci avvaliamo mai di questa facoltà.",
    ("privacy", "de"): "Artikel 8 der DSGVO, der jedem Mitgliedstaat überlässt, das Alter der eigenen digitalen Einwilligung des Minderjährigen zwischen 13 und 16 Jahren festzulegen (15 Jahre in Frankreich): wir machen von dieser Möglichkeit nie Gebrauch.",
    ("privacy", "pt"): "o artigo 8.º do RGPD, que deixa a cada Estado-Membro fixar entre os 13 e os 16 anos a idade do consentimento digital próprio do menor (15 anos em França): nunca fazemos uso dessa faculdade.",
    ("privacy", "nl"): "artikel 8 van de AVG, dat elke lidstaat de leeftijd van de eigen digitale toestemming van de minderjarige tussen 13 en 16 jaar laat vaststellen (15 jaar in Frankrijk): wij maken nooit gebruik van die mogelijkheid.",
}
_UK_ART8_DST = {
    ("cgu", "fr"): "l'article 8 du UK GDPR, qui fixe cet âge à 13 ans (Data Protection Act 2018, article 9) : nous n'utilisons jamais cette faculté et exigeons toujours le consentement du responsable légal.",
    ("cgu", "en"): "Article 8 of the UK GDPR, which sets that age at 13 (Data Protection Act 2018, section 9): we never rely on that option and always require the legal guardian's consent.",
    ("cgu", "es"): "el artículo 8 del UK GDPR, que fija esa edad en 13 años (Data Protection Act 2018, artículo 9): nunca hacemos uso de esa facultad y siempre exigimos el consentimiento del responsable legal.",
    # La politique porte en outre le code de l'ICO : c'est elle que lit un parent
    # britannique qui veut savoir ce que le service fait de l'enfant.
    ("privacy", "fr"): "l'article 8 du UK GDPR, qui fixe cet âge à 13 ans (Data Protection Act 2018, article 9) : nous n'utilisons jamais cette faculté. L'application est conçue selon l'Age Appropriate Design Code de l'Information Commissioner's Office : aucune publicité, aucun profilage, aucune donnée de localisation, et les réglages les plus protecteurs par défaut.",
    ("privacy", "en"): "Article 8 of the UK GDPR, which sets that age at 13 (Data Protection Act 2018, section 9): we never rely on that option. The application is designed in line with the Information Commissioner's Office Age Appropriate Design Code: no advertising, no profiling, no location data, and the most protective settings by default.",
    ("privacy", "es"): "el artículo 8 del UK GDPR, que fija esa edad en 13 años (Data Protection Act 2018, artículo 9): nunca hacemos uso de esa facultad. La aplicación está diseñada conforme al Age Appropriate Design Code de la Information Commissioner's Office: sin publicidad, sin elaboración de perfiles, sin datos de localización y con los ajustes más protectores por defecto.",
    ("cgu", "it"): "l'articolo 8 del UK GDPR, che fissa tale età a 13 anni (Data Protection Act 2018, articolo 9): non ci avvaliamo mai di questa facoltà ed esigiamo sempre il consenso del responsabile legale.",
    ("cgu", "de"): "Artikel 8 der UK GDPR, der dieses Alter auf 13 Jahre festsetzt (Data Protection Act 2018, Abschnitt 9): wir machen von dieser Möglichkeit nie Gebrauch und verlangen stets die Einwilligung des gesetzlichen Vertreters.",
    ("cgu", "pt"): "o artigo 8.º do UK GDPR, que fixa essa idade em 13 anos (Data Protection Act 2018, artigo 9): nunca fazemos uso dessa faculdade e exigimos sempre o consentimento do responsável legal.",
    ("cgu", "nl"): "artikel 8 van de UK GDPR, dat die leeftijd op 13 jaar vaststelt (Data Protection Act 2018, section 9): wij maken nooit gebruik van die mogelijkheid en eisen steeds de toestemming van de wettelijke vertegenwoordiger.",
    ("privacy", "it"): "l'articolo 8 del UK GDPR, che fissa tale età a 13 anni (Data Protection Act 2018, articolo 9): non ci avvaliamo mai di questa facoltà. L'applicazione è progettata secondo l'Age Appropriate Design Code dell'Information Commissioner's Office: nessuna pubblicità, nessuna profilazione, nessun dato di localizzazione, e le impostazioni più protettive per impostazione predefinita.",
    ("privacy", "de"): "Artikel 8 der UK GDPR, der dieses Alter auf 13 Jahre festsetzt (Data Protection Act 2018, Abschnitt 9): wir machen von dieser Möglichkeit nie Gebrauch. Die Anwendung ist nach dem Age Appropriate Design Code des Information Commissioner's Office gestaltet: keine Werbung, keine Profilbildung, keine Standortdaten und die schützendsten Einstellungen als Voreinstellung.",
    ("privacy", "pt"): "o artigo 8.º do UK GDPR, que fixa essa idade em 13 anos (Data Protection Act 2018, artigo 9): nunca fazemos uso dessa faculdade. A aplicação foi concebida segundo o Age Appropriate Design Code do Information Commissioner's Office: sem publicidade, sem definição de perfis, sem dados de localização, e com as definições mais protetoras por defeito.",
    ("privacy", "nl"): "artikel 8 van de UK GDPR, dat die leeftijd op 13 jaar vaststelt (Data Protection Act 2018, section 9): wij maken nooit gebruik van die mogelijkheid. De applicatie is ontworpen volgens de Age Appropriate Design Code van het Information Commissioner's Office: geen reclame, geen profilering, geen locatiegegevens, en de meest beschermende instellingen als standaard.",
}
# Le terme lui-meme, une fois les phrases traitees. L'anglais exige un motif brut :
# « UK GDPR » contient « GDPR ».
_UK_TERME = {
    "fr": ("RGPD", "UK GDPR", False),
    "en": (r"(?<!UK )GDPR", "UK GDPR", True),
    "es": ("RGPD", "UK GDPR", False),
    # ⚠ SEUL L'ANGLAIS A BESOIN DU MOTIF BRUT : « UK GDPR » contient « GDPR », donc
    #   un remplacement naif se mordrait la queue. Les six autres langues ont un
    #   acronyme propre — RGPD, DSGVO, AVG — qui ne se retrouve pas dans sa cible.
    "it": ("RGPD", "UK GDPR", False),
    "de": ("DSGVO", "UK GDPR", False),
    "pt": ("RGPD", "UK GDPR", False),
    "nl": ("AVG", "UK GDPR", False),
}
_UK_HEBERGEMENT_SRC = {
    "fr": "avec stockage des données dans l'Union Européenne.",
    "en": "with data stored in the European Union.",
    "es": "con almacenamiento de los datos en la Unión Europea.",
    "it": "con archiviazione dei dati nell'Unione Europea.",
    "de": "mit Speicherung der Daten in der Europäischen Union.",
    "pt": "com armazenamento dos dados na União Europeia.",
    "nl": "met opslag van de gegevens in de Europese Unie.",
}
_UK_HEBERGEMENT = {
    "fr": "avec stockage des données dans l'Union européenne. Vos données quittent donc le Royaume-Uni : "
          "ce transfert repose sur les règlements d'adéquation adoptés par le Royaume-Uni au bénéfice de "
          "l'Espace économique européen.",
    "en": "with data stored in the European Union. Your data therefore leaves the United Kingdom: this "
          "transfer relies on the adequacy regulations made by the United Kingdom in respect of the "
          "European Economic Area.",
    "es": "con almacenamiento de los datos en la Unión Europea. Sus datos salen por tanto del Reino Unido: "
          "esta transferencia se ampara en los reglamentos de adecuación adoptados por el Reino Unido "
          "respecto del Espacio Económico Europeo.",
    "it": "con archiviazione dei dati nell'Unione europea. I vostri dati lasciano quindi il Regno Unito: "
          "questo trasferimento si fonda sui regolamenti di adeguatezza adottati dal Regno Unito a favore "
          "dello Spazio economico europeo.",
    "de": "mit Speicherung der Daten in der Europäischen Union. Ihre Daten verlassen somit das Vereinigte "
          "Königreich: diese Übermittlung stützt sich auf die vom Vereinigten Königreich erlassenen "
          "Angemessenheitsverordnungen zugunsten des Europäischen Wirtschaftsraums.",
    "pt": "com armazenamento dos dados na União Europeia. Os seus dados saem, portanto, do Reino Unido: "
          "esta transferência assenta nos regulamentos de adequação adotados pelo Reino Unido em relação ao "
          "Espaço Económico Europeu.",
    "nl": "met opslag van de gegevens in de Europese Unie. Uw gegevens verlaten dus het Verenigd Koninkrijk: "
          "die doorgifte berust op de door het Verenigd Koninkrijk vastgestelde adequaatheidsbesluiten ten "
          "gunste van de Europese Economische Ruimte.",
}
# La réserve ne peut plus viser l'Union : elle vise le droit britannique.
_UK_LOI = {
    "fr": "applicables au Royaume-Uni, notamment le Consumer Rights Act 2015 et les Consumer Contracts "
          "(Information, Cancellation and Additional Charges) Regulations 2013.",
    "en": "applicable in the United Kingdom, in particular the Consumer Rights Act 2015 and the Consumer "
          "Contracts (Information, Cancellation and Additional Charges) Regulations 2013.",
    "es": "aplicables en el Reino Unido, en particular la Consumer Rights Act 2015 y las Consumer Contracts "
          "(Information, Cancellation and Additional Charges) Regulations 2013.",
    "it": "applicabili nel Regno Unito, in particolare il Consumer Rights Act 2015 e i Consumer Contracts "
          "(Information, Cancellation and Additional Charges) Regulations 2013.",
    "de": "die im Vereinigten Königreich anwendbar sind, insbesondere der Consumer Rights Act 2015 und die "
          "Consumer Contracts (Information, Cancellation and Additional Charges) Regulations 2013.",
    "pt": "aplicáveis no Reino Unido, em particular a Consumer Rights Act 2015 e os Consumer Contracts "
          "(Information, Cancellation and Additional Charges) Regulations 2013.",
    "nl": "die van toepassing zijn in het Verenigd Koninkrijk, in het bijzonder de Consumer Rights Act 2015 "
          "en de Consumer Contracts (Information, Cancellation and Additional Charges) Regulations 2013.",
}
_UK_ICO = {
    "fr": "— au Royaume-Uni, l'Information Commissioner's Office "
          '(<a href="https://ico.org.uk">ico.org.uk</a>)',
    "en": "— in the United Kingdom, the Information Commissioner's Office "
          '(<a href="https://ico.org.uk">ico.org.uk</a>)',
    "es": "— en el Reino Unido, la Information Commissioner's Office "
          '(<a href="https://ico.org.uk">ico.org.uk</a>)',
    "it": "— nel Regno Unito, l'Information Commissioner's Office "
          '(<a href="https://ico.org.uk">ico.org.uk</a>)',
    "de": "— im Vereinigten Königreich, das Information Commissioner's Office "
          '(<a href="https://ico.org.uk">ico.org.uk</a>)',
    "pt": "— no Reino Unido, o Information Commissioner's Office "
          '(<a href="https://ico.org.uk">ico.org.uk</a>)',
    "nl": "— in het Verenigd Koninkrijk, het Information Commissioner's Office "
          '(<a href="https://ico.org.uk">ico.org.uk</a>)',
}


# La durée de conservation des preuves d'acceptation est calée sur la PRESCRIPTION
# FRANÇAISE (art. 2224 du code civil, cinq ans). Hors de l'Union, cette référence
# ne dit plus rien au lecteur : le Royaume-Uni compte six ans (Limitation Act 1980)
# et la Suisse dix (art. 127 CO). On garde les cinq ans — conserver MOINS que la
# fenêtre de risque est un choix de proportionnalité, pas un manquement — mais on
# le dit avec le repère du lecteur.
#
# ⚠ CONSERVÉ TEL QUEL POUR LES MARCHÉS DE L'UNION. Le responsable de traitement est
#   français, et l'obligation de démontrer le consentement (art. 7(1) RGPD) est
#   commune : la prescription française reste sa propre fenêtre de risque.
_PRESCRIPTION_SRC = {
    "fr": "Cette durée correspond au délai de prescription de droit commun (article 2224 du code civil)",
    "en": "This period matches the general limitation period under French law (article 2224 of the Civil Code)",
    "es": "Este plazo corresponde al de prescripción de derecho común (artículo 2224 del código civil francés)",
    "it": "Questa durata corrisponde al termine di prescrizione di diritto comune (articolo 2224 del codice civile francese)",
    "de": "Diese Dauer entspricht der regelmäßigen Verjährungsfrist (Artikel 2224 des französischen Zivilgesetzbuchs)",
    "pt": "Este prazo corresponde ao prazo de prescrição ordinário (artigo 2224 do código civil francês)",
    "nl": "Die termijn stemt overeen met de gewone verjaringstermijn (artikel 2224 van het Franse burgerlijk wetboek)",
}
_PRESCRIPTION = {
    "uk": {
        "fr": "Cette durée est inférieure au délai de prescription du droit anglais (Limitation Act 1980, section 5 : six ans)",
        "en": "This period is shorter than the limitation period under English law (Limitation Act 1980, section 5: six years)",
        "es": "Este plazo es inferior al de prescripción del derecho inglés (Limitation Act 1980, sección 5: seis años)",
        "it": "Questa durata è inferiore al termine di prescrizione del diritto inglese (Limitation Act 1980, sezione 5: sei anni)",
        "de": "Diese Dauer ist kürzer als die Verjährungsfrist des englischen Rechts (Limitation Act 1980, Section 5: sechs Jahre)",
        "pt": "Este prazo é inferior ao prazo de prescrição do direito inglês (Limitation Act 1980, secção 5: seis anos)",
        "nl": "Die termijn is korter dan de verjaringstermijn naar Engels recht (Limitation Act 1980, section 5: zes jaar)",
    },
    "ch": {
        "fr": "Cette durée est inférieure au délai de prescription de droit commun suisse (art. 127 du code des obligations : dix ans)",
        "en": "This period is shorter than the general Swiss limitation period (Article 127 of the Code of Obligations: ten years)",
        "es": "Este plazo es inferior al de prescripción de derecho común suizo (art. 127 del Código de las Obligaciones: diez años)",
        "it": "Questa durata è inferiore al termine di prescrizione di diritto comune svizzero (art. 127 del Codice delle obbligazioni: dieci anni)",
        "de": "Diese Dauer ist kürzer als die allgemeine schweizerische Verjährungsfrist (Art. 127 des Obligationenrechts: zehn Jahre)",
        "pt": "Este prazo é inferior ao prazo de prescrição de direito comum suíço (art. 127 do Código das Obrigações: dez anos)",
        "nl": "Die termijn is korter dan de gewone Zwitserse verjaringstermijn (art. 127 van het Wetboek van verbintenissen: tien jaar)",
    },
}


# Le stockage hors du Royaume-Uni, dit une seconde fois dans la politique, la ou
# le lecteur le cherche : la section « Localisation, regions et securite ».
# ⚠ CETTE TABLE ETAIT UN LITTERAL ANONYME DANS `_uk_blocks` jusqu'au 2026-09-08.
#   Elle en sort parce qu'une table sans nom ne se trouve pas : l'ajout des quatre
#   langues l'avait oubliee, et c'est la derivation qui l'a signalee, par un
#   KeyError. Nommee, elle se cherche comme les autres.
_UK_STOCKAGE = {
    "fr": "des centres de données situés dans l'UE, donc hors du Royaume-Uni ; ce transfert "
          "repose sur les règlements d'adéquation britanniques au bénéfice de l'EEE)",
    "en": "data centres located in the EU, therefore outside the United Kingdom; this transfer "
          "relies on the United Kingdom's adequacy regulations for the EEA)",
    "es": "centros de datos situados en la UE, por tanto fuera del Reino Unido; esta transferencia "
          "se ampara en los reglamentos de adecuación británicos respecto del EEE)",
    "it": "centri di dati situati nell'UE, quindi fuori dal Regno Unito; questo trasferimento si fonda "
          "sui regolamenti di adeguatezza britannici a favore del SEE)",
    "de": "Rechenzentren in der EU, also außerhalb des Vereinigten Königreichs; diese Übermittlung stützt "
          "sich auf die Angemessenheitsverordnungen des Vereinigten Königreichs für den EWR)",
    "pt": "centros de dados situados na UE, portanto fora do Reino Unido; esta transferência assenta nos "
          "regulamentos de adequação britânicos em relação ao EEE)",
    "nl": "datacentra gelegen in de EU, dus buiten het Verenigd Koninkrijk; die doorgifte berust op de "
          "Britse adequaatheidsbesluiten voor de EER)",
}


def _uk_blocks(lang, doc):

    """Les ecarts britanniques d'UN document adulte, dans l'ordre d'application."""
    out = [
        # 1. Les PHRASES d'abord : elles contiennent le terme, et ne se
        #    reconnaitraient plus apres son remplacement.
        (_UK_ART8_SRC[(doc, lang)], _UK_ART8_DST[(doc, lang)]),
    ]
    if doc == "cgu":
        out.append((_UK_HEBERGEMENT_SRC[lang], _UK_HEBERGEMENT[lang]))
        out.append((_LOI_SRC[lang], _UK_LOI[lang]))
    else:
        out.append((_AUTORITE_SRC[lang], _UK_ICO[lang]))
        out.append((_PRESCRIPTION_SRC[lang], _PRESCRIPTION["uk"][lang]))
        # Le stockage hors du Royaume-Uni, redit la ou le lecteur cherche : la
        # section « Localisation, regions et securite ».
        out.append((_EEE_STOCKAGE_SRC[lang], _UK_STOCKAGE[lang]))
    # 2. Le TERME ensuite, sur ce qu'il en reste.
    src, dst, brut = _UK_TERME[lang]
    reste = 5 if doc == "privacy" else 0
    if reste:
        out.append((src, dst, reste, brut))
    return out


# =============================================================================
# SUISSE — le marché où la clause de loi applicable ne s'applique pas
# =============================================================================
# ⚠ `ch` VA PLUS LOIN QUE `uk`. Le Royaume-Uni avait repris le RGPD sous un autre
#   nom : il suffisait de requalifier le terme. La Suisse relève d'un droit
#   distinct — la LPD — et, surtout, d'un droit international privé qui PRIVE
#   D'EFFET le choix du droit français : l'art. 120 al. 2 LDIP exclut l'élection
#   de droit pour les contrats de consommation courante. La clause héritée de `fr`
#   y était doublement fausse — elle choisissait un droit qui ne s'appliquera pas,
#   et réservait les dispositions de l'Union, dont la Suisse ne fait pas partie.
#
# ⚠ AUCUNE SUBSTITUTION GLOBALE DU TERME ICI, contrairement à `uk`. Les numéros
#   d'articles ne se correspondent pas d'un texte à l'autre : « l'article 6.1.a du
#   LPD » n'existe pas. Les sept occurrences se traitent une par une.
#
# ⚠ `article 12` DU §2 DE LA POLITIQUE EST UN RENVOI INTERNE au §12 du même
#   document (liste d'attente des betas), pas un article du RGPD. Vérifié. Ne
#   jamais l'inclure dans une substitution de vocabulaire.
#
# ⚠ LE DROIT DE RÉTRACTATION N'EXISTE PAS EN DROIT SUISSE pour une vente à
#   distance : les art. 40a ss CO visent le démarchage, pas le commerce en ligne.
#   La clause héritée faisait « renoncer » l'acheteur à un droit qu'il n'a pas.
_CH_RETRACTATION_SRC = {
    "fr": "<li><strong>Rétractation et remboursement</strong> — tous les achats et abonnements sont traités par la plateforme de téléchargement. En achetant un contenu numérique dans l'Application, vous acceptez que sa fourniture commence immédiatement, ce qui entraîne <strong>la renonciation à votre droit de rétractation</strong> dans les conditions prévues par la plateforme. Pour toute demande de rétractation légale ou de remboursement dans les délais prévus par la loi, utilisez les outils de gestion d'abonnement et d'historique d'achat de votre compte Google. Ces stipulations sont sans préjudice de vos droits légaux impératifs.</li>",
    "en": "<li><strong>Withdrawal and refunds</strong> — all purchases and subscriptions are processed by the download platform. By purchasing digital content in the Application, you agree that its supply begins immediately, which entails <strong>the waiver of your right of withdrawal</strong> under the conditions set by the platform. For any statutory withdrawal or refund request within the time limits provided by law, use the subscription management and purchase history tools of your Google account. These provisions are without prejudice to your mandatory statutory rights.</li>",
    "es": "<li><strong>Desistimiento y reembolso</strong> — todas las compras y suscripciones las tramita la plataforma de descarga. Al comprar contenido digital en la Aplicación, usted acepta que su suministro comience de inmediato, lo que conlleva <strong>la renuncia a su derecho de desistimiento</strong> en las condiciones previstas por la plataforma. Para cualquier solicitud legal de desistimiento o de reembolso dentro de los plazos previstos por la ley, utilice las herramientas de gestión de suscripciones y de historial de compras de su cuenta de Google. Estas estipulaciones se entienden sin perjuicio de sus derechos legales imperativos.</li>",
    "it": "<li><strong>Recesso e rimborso</strong> — tutti gli acquisti e gli abbonamenti sono gestiti dalla piattaforma di download. Acquistando un contenuto digitale nell'Applicazione, accettate che la sua fornitura inizi immediatamente, il che comporta <strong>la rinuncia al vostro diritto di recesso</strong> alle condizioni previste dalla piattaforma. Per qualsiasi richiesta di recesso legale o di rimborso nei termini previsti dalla legge, utilizzate gli strumenti di gestione dell'abbonamento e di cronologia degli acquisti del vostro account Google. Queste disposizioni non pregiudicano i vostri diritti legali imperativi.</li>",
    "de": "<li><strong>Widerruf und Erstattung</strong> — alle Käufe und Abonnements werden von der Download-Plattform abgewickelt. Mit dem Kauf digitaler Inhalte in der Anwendung stimmen Sie zu, dass deren Bereitstellung sofort beginnt, was <strong>den Verzicht auf Ihr Widerrufsrecht</strong> zu den von der Plattform vorgesehenen Bedingungen zur Folge hat. Für jeden gesetzlichen Widerrufs- oder Erstattungsantrag innerhalb der gesetzlich vorgesehenen Fristen nutzen Sie die Werkzeuge zur Abonnementverwaltung und zum Kaufverlauf Ihres Google-Kontos. Diese Bestimmungen lassen Ihre zwingenden gesetzlichen Rechte unberührt.</li>",
    "pt": "<li><strong>Livre resolução e reembolso</strong> — todas as compras e subscrições são tratadas pela plataforma de descarregamento. Ao comprar um conteúdo digital na Aplicação, aceita que o seu fornecimento comece de imediato, o que implica <strong>a renúncia ao seu direito de livre resolução</strong> nas condições previstas pela plataforma. Para qualquer pedido legal de livre resolução ou de reembolso nos prazos previstos na lei, utilize as ferramentas de gestão de subscrições e de histórico de compras da sua conta Google. Estas estipulações não prejudicam os seus direitos legais imperativos.</li>",
    "nl": "<li><strong>Herroeping en terugbetaling</strong> — alle aankopen en abonnementen worden door het downloadplatform verwerkt. Door digitale inhoud in de Applicatie te kopen, aanvaardt u dat de levering ervan onmiddellijk begint, wat <strong>het afzien van uw herroepingsrecht</strong> met zich meebrengt onder de door het platform vastgestelde voorwaarden. Voor elk wettelijk herroepings- of terugbetalingsverzoek binnen de wettelijk voorziene termijnen gebruikt u de hulpmiddelen voor abonnementenbeheer en aankoopgeschiedenis van uw Google-account. Deze bepalingen doen geen afbreuk aan uw dwingende wettelijke rechten.</li>",
}
_CH_RETRACTATION = {
    "fr": "<li><strong>Remboursement</strong> — tous les achats et abonnements sont traités par la plateforme de téléchargement. <strong>Le droit suisse ne prévoit pas de droit de rétractation légal</strong> pour un contrat conclu à distance de ce type : les art. 40a et suivants du code des obligations visent le démarchage, non le commerce en ligne. La politique de remboursement de la plateforme s'applique néanmoins, et toute demande se fait depuis les outils de gestion d'abonnement et d'historique d'achat de votre compte Google. Ces stipulations sont sans préjudice de vos droits légaux impératifs.</li>",
    "en": "<li><strong>Refunds</strong> — all purchases and subscriptions are processed by the download platform. <strong>Swiss law provides no statutory right of withdrawal</strong> for a distance contract of this kind: Articles 40a et seq. of the Code of Obligations cover doorstep selling, not online commerce. The platform's refund policy nonetheless applies, and any request is made through the subscription management and purchase history tools of your Google account. These provisions are without prejudice to your mandatory statutory rights.</li>",
    "es": "<li><strong>Reembolso</strong> — todas las compras y suscripciones las tramita la plataforma de descarga. <strong>El derecho suizo no prevé un derecho legal de desistimiento</strong> para un contrato a distancia de este tipo: los arts. 40a y siguientes del Código de las Obligaciones se refieren a la venta domiciliaria, no al comercio en línea. No obstante, se aplica la política de reembolso de la plataforma, y cualquier solicitud se realiza desde las herramientas de gestión de suscripciones y de historial de compras de su cuenta de Google. Estas estipulaciones se entienden sin perjuicio de sus derechos legales imperativos.</li>",
    "it": "<li><strong>Rimborso</strong> — tutti gli acquisti e gli abbonamenti sono gestiti dalla piattaforma di download. <strong>Il diritto svizzero non prevede alcun diritto di recesso legale</strong> per un contratto concluso a distanza di questo tipo: gli art. 40a e seguenti del Codice delle obbligazioni riguardano la vendita a domicilio, non il commercio in linea. La politica di rimborso della piattaforma si applica comunque, e ogni richiesta si effettua dagli strumenti di gestione dell'abbonamento e di cronologia degli acquisti del vostro account Google. Queste disposizioni non pregiudicano i vostri diritti legali imperativi.</li>",
    "de": "<li><strong>Erstattung</strong> — alle Käufe und Abonnements werden von der Download-Plattform abgewickelt. <strong>Das schweizerische Recht sieht für einen Fernabsatzvertrag dieser Art kein gesetzliches Widerrufsrecht vor</strong>: die Art. 40a ff. des Obligationenrechts betreffen den Haustürverkauf, nicht den Online-Handel. Die Erstattungsrichtlinie der Plattform gilt gleichwohl, und jeder Antrag erfolgt über die Werkzeuge zur Abonnementverwaltung und zum Kaufverlauf Ihres Google-Kontos. Diese Bestimmungen lassen Ihre zwingenden gesetzlichen Rechte unberührt.</li>",
    "pt": "<li><strong>Reembolso</strong> — todas as compras e subscrições são tratadas pela plataforma de descarregamento. <strong>O direito suíço não prevê qualquer direito legal de livre resolução</strong> para um contrato à distância deste tipo: os arts. 40a e seguintes do Código das Obrigações visam a venda ao domicílio, não o comércio em linha. A política de reembolso da plataforma aplica-se ainda assim, e qualquer pedido é feito a partir das ferramentas de gestão de subscrições e de histórico de compras da sua conta Google. Estas estipulações não prejudicam os seus direitos legais imperativos.</li>",
    "nl": "<li><strong>Terugbetaling</strong> — alle aankopen en abonnementen worden door het downloadplatform verwerkt. <strong>Het Zwitserse recht voorziet niet in een wettelijk herroepingsrecht</strong> voor een overeenkomst op afstand van dit type: de art. 40a e.v. van het Wetboek van verbintenissen betreffen de huis-aan-huisverkoop, niet de onlinehandel. Het terugbetalingsbeleid van het platform is niettemin van toepassing, en elk verzoek verloopt via de hulpmiddelen voor abonnementenbeheer en aankoopgeschiedenis van uw Google-account. Deze bepalingen doen geen afbreuk aan uw dwingende wettelijke rechten.</li>",
}
_CH_LOI_SRC = {
    "fr": "Les présentes conditions sont régies par le droit français, sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre pays de résidence au sein de l'Union Européenne.",
    "en": "These terms are governed by French law, without prejudice to the mandatory consumer-protection provisions applicable in your country of residence within the European Union.",
    "es": "Las presentes condiciones se rigen por el derecho francés, sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su país de residencia dentro de la Unión Europea.",
    "it": "Le presenti condizioni sono disciplinate dal diritto francese, fatte salve le disposizioni imperative di protezione dei consumatori applicabili nel vostro paese di residenza all'interno dell'Unione Europea.",
    "de": "Die vorliegenden Bedingungen unterliegen französischem Recht, unbeschadet der zwingenden Verbraucherschutzbestimmungen, die in Ihrem Wohnsitzland innerhalb der Europäischen Union anwendbar sind.",
    "pt": "As presentes condições são regidas pelo direito francês, sem prejuízo das disposições imperativas de proteção dos consumidores aplicáveis no seu país de residência dentro da União Europeia.",
    "nl": "Deze voorwaarden worden beheerst door het Franse recht, onverminderd de dwingende bepalingen inzake consumentenbescherming die van toepassing zijn in uw land van verblijf binnen de Europese Unie.",
}
_CH_LOI = {
    "fr": "Si vous résidez en Suisse, les présentes conditions sont régies par le <strong>droit suisse</strong> : "
          "l'art. 120 al. 2 de la loi fédérale sur le droit international privé exclut l'élection d'un autre "
          "droit pour les contrats conclus avec un consommateur portant sur des prestations de consommation "
          "courante. La convention de Lugano du 30 octobre 2007 vous permet en outre de porter le litige devant "
          "le tribunal de votre domicile.",
    "en": "If you reside in Switzerland, these terms are governed by <strong>Swiss law</strong>: Article 120(2) "
          "of the Federal Act on Private International Law excludes any choice of another law for consumer "
          "contracts concerning goods or services of ordinary consumption. The Lugano Convention of 30 October "
          "2007 further allows you to bring the dispute before the court of your domicile.",
    "es": "Si usted reside en Suiza, las presentes condiciones se rigen por el <strong>derecho suizo</strong>: "
          "el art. 120.2 de la Ley federal de derecho internacional privado excluye la elección de otro derecho "
          "para los contratos celebrados con un consumidor sobre prestaciones de consumo corriente. El Convenio "
          "de Lugano de 30 de octubre de 2007 le permite además someter el litigio al tribunal de su domicilio.",
    "it": "Se risiedete in Svizzera, le presenti condizioni sono disciplinate dal <strong>diritto svizzero</strong>: "
          "l'art. 120 cpv. 2 della legge federale sul diritto internazionale privato esclude l'elezione di un "
          "altro diritto per i contratti conclusi con un consumatore aventi per oggetto prestazioni di consumo "
          "corrente. La Convenzione di Lugano del 30 ottobre 2007 vi consente inoltre di portare la controversia "
          "davanti al tribunale del vostro domicilio.",
    "de": "Wenn Sie in der Schweiz wohnen, unterliegen diese Bedingungen dem <strong>schweizerischen Recht</strong>: "
          "Art. 120 Abs. 2 des Bundesgesetzes über das Internationale Privatrecht schliesst die Wahl eines "
          "anderen Rechts für Verbraucherverträge über Leistungen des üblichen Verbrauchs aus. Das "
          "Übereinkommen von Lugano vom 30. Oktober 2007 erlaubt Ihnen zudem, den Streit vor das Gericht Ihres "
          "Wohnsitzes zu bringen.",
    "pt": "Se residir na Suíça, as presentes condições são regidas pelo <strong>direito suíço</strong>: o "
          "art. 120.º n.º 2 da Lei federal de direito internacional privado exclui a escolha de outro direito "
          "para os contratos celebrados com um consumidor que tenham por objeto prestações de consumo corrente. "
          "A Convenção de Lugano de 30 de outubro de 2007 permite-lhe além disso submeter o litígio ao tribunal "
          "do seu domicílio.",
    "nl": "Als u in Zwitserland verblijft, worden deze voorwaarden beheerst door het <strong>Zwitserse recht</strong>: "
          "art. 120 lid 2 van de federale wet op het internationaal privaatrecht sluit de keuze van een ander "
          "recht uit voor consumentenovereenkomsten betreffende prestaties van gewoon verbruik. Het Verdrag van "
          "Lugano van 30 oktober 2007 stelt u bovendien in staat het geschil voor de rechtbank van uw woonplaats "
          "te brengen.",
}

# ── MÉDIATION : la Suisse n'en impose aucune, et c'est tout le problème ───────
# ⚠ LE SEUL BLOC SUISSE QUI NE CORRIGE PAS UNE ERREUR. Les autres redressent une
#   affirmation devenue fausse hors de l'Union. Celui-ci redresse un ENCHAÎNEMENT :
#   le §12 suisse dit que le droit SUISSE régit le contrat, et la phrase du corpus
#   `fr` enchaîne sur « Conformément aux dispositions du Code de la consommation ».
#   Le lecteur suisse lit alors qu'un code français lui ouvre un recours, ce qui
#   n'est pas ce qui se passe.
#
#   Vérifié : la Suisse n'a AUCUN équivalent de l'art. L616-1. Pas d'obligation
#   générale d'adhérer à un organisme de médiation, ni pour une entreprise suisse
#   ni pour une entreprise étrangère. Les ombudsmans y sont sectoriels — banques,
#   assurance, télécoms, voyages, poste, transports, textile — et aucun ne couvre
#   l'édition de jeux. Seul le domaine financier ancre la conciliation préalable
#   dans la loi (art. 74 LSFin).
#
#   ⚠ NE PAS CONFONDRE avec l'art. 14 al. 1 LPD, qui impose à un responsable de
#     traitement établi à l'étranger de désigner un REPRÉSENTANT EN SUISSE. C'est
#     l'équivalent de l'art. 27 RGPD — un point de contact pour la protection des
#     données, qui ne règle aucun litige contractuel — et ses trois conditions
#     sont cumulatives (grande ampleur, régulier, risque élevé). Rien à voir avec
#     la médiation de la consommation, et traité ailleurs.
#
#   D'où le choix retenu : on offre CM2C quand même, mais présenté pour ce qu'il
#   est en Suisse — un engagement volontaire de l'éditeur, et non l'effet d'un
#   code étranger. Les coordonnées qui suivent la phrase sont inchangées.
_MEDIATION_SRC = {
    "fr": "Conformément aux dispositions du Code de la consommation concernant « le processus de médiation des "
          "litiges de la consommation », après nous avoir sollicités et à défaut de réponse vous satisfaisant, "
          "vous avez la possibilité de recourir gratuitement à une procédure de médiation de la consommation "
          "auprès de :",
    "en": "In accordance with the provisions of the French Consumer Code on the mediation of consumer disputes, "
          "after contacting us and failing a reply that satisfies you, you may refer the matter free of charge "
          "to a consumer mediation procedure with:",
    "es": "De conformidad con las disposiciones del Código de Consumo francés relativas al «proceso de mediación "
          "de litigios de consumo», tras habernos contactado y a falta de una respuesta satisfactoria, usted "
          "puede recurrir gratuitamente a un procedimiento de mediación de consumo ante:",
    "it": "Conformemente alle disposizioni del Codice del consumo francese relative al « processo di mediazione "
          "delle controversie di consumo », dopo averci contattato e in mancanza di una risposta soddisfacente, "
          "avete la possibilità di ricorrere gratuitamente a una procedura di mediazione del consumo presso:",
    "de": "Gemäß den Bestimmungen des französischen Verbrauchergesetzbuchs über das « Verfahren zur Mediation "
          "von Verbraucherstreitigkeiten » haben Sie, nachdem Sie uns kontaktiert haben und mangels einer für "
          "Sie zufriedenstellenden Antwort, die Möglichkeit, kostenlos ein Verbrauchermediationsverfahren "
          "einzuleiten bei:",
    "pt": "Em conformidade com as disposições do Código do Consumo francês relativas ao « processo de mediação "
          "de litígios de consumo », depois de nos ter contactado e na falta de uma resposta satisfatória, tem "
          "a possibilidade de recorrer gratuitamente a um procedimento de mediação de consumo junto de:",
    "nl": "Overeenkomstig de bepalingen van het Franse consumentenwetboek betreffende de « bemiddelingsprocedure "
          "voor consumentengeschillen », kunt u, nadat u contact met ons hebt opgenomen en bij gebreke van een "
          "voor u bevredigend antwoord, kosteloos een consumentenbemiddelingsprocedure inleiden bij:",
}
_CH_MEDIATION = {
    "fr": "L'éditeur adhère à un dispositif de médiation de la consommation et vous en ouvre l'accès, sans y "
          "être tenu par le droit suisse. Après nous avoir sollicités et à défaut de réponse vous satisfaisant, "
          "vous avez la possibilité de recourir gratuitement à une procédure de médiation de la consommation "
          "auprès de :",
    "en": "The publisher belongs to a consumer mediation scheme and opens it to you, without being required to "
          "do so by Swiss law. After contacting us and failing a reply that satisfies you, you may refer the "
          "matter free of charge to a consumer mediation procedure with:",
    "es": "El editor está adherido a un dispositivo de mediación de consumo y le abre su acceso, sin estar "
          "obligado a ello por el derecho suizo. Tras habernos contactado y a falta de una respuesta "
          "satisfactoria, usted puede recurrir gratuitamente a un procedimiento de mediación de consumo ante:",
    "it": "L'editore aderisce a un dispositivo di mediazione del consumo e ve ne apre l'accesso, pur non "
          "essendovi tenuto dal diritto svizzero. Dopo averci contattato e in mancanza di una risposta "
          "soddisfacente, avete la possibilità di ricorrere gratuitamente a una procedura di mediazione del "
          "consumo presso:",
    "de": "Der Herausgeber gehört einer Verbrauchermediationsstelle an und eröffnet Ihnen deren Zugang, ohne "
          "dazu nach schweizerischem Recht verpflichtet zu sein. Nachdem Sie uns kontaktiert haben und mangels "
          "einer für Sie zufriedenstellenden Antwort haben Sie die Möglichkeit, kostenlos ein "
          "Verbrauchermediationsverfahren einzuleiten bei:",
    "pt": "O editor aderiu a um dispositivo de mediação de consumo e abre-lhe o respetivo acesso, sem a tal "
          "estar obrigado pelo direito suíço. Depois de nos ter contactado e na falta de uma resposta "
          "satisfatória, tem a possibilidade de recorrer gratuitamente a um procedimento de mediação de consumo "
          "junto de:",
    "nl": "De uitgever is aangesloten bij een consumentenbemiddelingsregeling en stelt die voor u open, zonder "
          "daartoe naar Zwitsers recht verplicht te zijn. Nadat u contact met ons hebt opgenomen en bij gebreke "
          "van een voor u bevredigend antwoord, kunt u kosteloos een consumentenbemiddelingsprocedure inleiden "
          "bij:",
}
_CH_HEBERGEMENT = {
    "fr": "avec stockage des données dans l'Union européenne. Ces données sont donc communiquées hors de Suisse "
          "(art. 16 et 17 LPD) : l'Espace économique européen figure à l'annexe 1 de l'ordonnance sur la "
          "protection des données, parmi les États assurant une protection adéquate.",
    "en": "with data stored in the European Union. Your data is therefore disclosed abroad from Switzerland "
          "(Articles 16 and 17 FADP): the European Economic Area is listed in Annex 1 to the Data Protection "
          "Ordinance, among the States affording adequate protection.",
    "es": "con almacenamiento de los datos en la Unión Europea. Sus datos se comunican por tanto fuera de Suiza "
          "(arts. 16 y 17 LPD): el Espacio Económico Europeo figura en el anexo 1 de la Ordenanza sobre la "
          "protección de datos, entre los Estados con protección adecuada.",
    "it": "con archiviazione dei dati nell'Unione europea. Tali dati sono quindi comunicati all'estero rispetto "
          "alla Svizzera (art. 16 e 17 LPD): lo Spazio economico europeo figura nell'allegato 1 dell'ordinanza "
          "sulla protezione dei dati, tra gli Stati che assicurano una protezione adeguata.",
    "de": "mit Speicherung der Daten in der Europäischen Union. Diese Daten werden somit von der Schweiz aus ins "
          "Ausland bekanntgegeben (Art. 16 und 17 DSG): der Europäische Wirtschaftsraum ist in Anhang 1 der "
          "Datenschutzverordnung aufgeführt, unter den Staaten mit angemessenem Schutz.",
    "pt": "com armazenamento dos dados na União Europeia. Esses dados são portanto comunicados para fora da "
          "Suíça (arts. 16.º e 17.º da LPD): o Espaço Económico Europeu consta do anexo 1 da Portaria sobre a "
          "proteção de dados, entre os Estados que asseguram uma proteção adequada.",
    "nl": "met opslag van de gegevens in de Europese Unie. Die gegevens worden dus buiten Zwitserland "
          "bekendgemaakt (art. 16 en 17 DSG): de Europese Economische Ruimte staat vermeld in bijlage 1 bij de "
          "verordening gegevensbescherming, bij de staten die een passende bescherming bieden.",
}
_CH_STOCKAGE = {
    "fr": "des centres de données situés dans l'UE, donc hors de Suisse ; l'EEE figure à l'annexe 1 de "
          "l'ordonnance sur la protection des données parmi les États à protection adéquate)",
    "en": "data centres located in the EU, therefore outside Switzerland; the EEA is listed in Annex 1 to the "
          "Data Protection Ordinance among the States affording adequate protection)",
    "es": "centros de datos situados en la UE, por tanto fuera de Suiza; el EEE figura en el anexo 1 de la "
          "Ordenanza sobre la protección de datos entre los Estados con protección adecuada)",
    "it": "centri di dati situati nell'UE, quindi fuori dalla Svizzera; il SEE figura nell'allegato 1 "
          "dell'ordinanza sulla protezione dei dati tra gli Stati a protezione adeguata)",
    "de": "Rechenzentren in der EU, also ausserhalb der Schweiz; der EWR ist in Anhang 1 der "
          "Datenschutzverordnung unter den Staaten mit angemessenem Schutz aufgeführt)",
    "pt": "centros de dados situados na UE, portanto fora da Suíça; o EEE consta do anexo 1 da Portaria sobre "
          "a proteção de dados entre os Estados com proteção adequada)",
    "nl": "datacentra gelegen in de EU, dus buiten Zwitserland; de EER staat vermeld in bijlage 1 bij de "
          "verordening gegevensbescherming bij de staten met een passende bescherming)",
}
_CH_PFPDT = {
    "fr": "— en Suisse, le Préposé fédéral à la protection des données et à la transparence "
          '(<a href="https://www.edoeb.admin.ch">edoeb.admin.ch</a>)',
    "en": "— in Switzerland, the Federal Data Protection and Information Commissioner "
          '(<a href="https://www.edoeb.admin.ch">edoeb.admin.ch</a>)',
    "es": "— en Suiza, el Encargado Federal de Protección de Datos y Transparencia "
          '(<a href="https://www.edoeb.admin.ch">edoeb.admin.ch</a>)',
    "it": "— in Svizzera, l'Incaricato federale della protezione dei dati e della trasparenza "
          '(<a href="https://www.edoeb.admin.ch">edoeb.admin.ch</a>)',
    "de": "— in der Schweiz, der Eidgenössische Datenschutz- und Öffentlichkeitsbeauftragte "
          '(<a href="https://www.edoeb.admin.ch">edoeb.admin.ch</a>)',
    "pt": "— na Suíça, o Encarregado Federal da Proteção de Dados e da Transparência "
          '(<a href="https://www.edoeb.admin.ch">edoeb.admin.ch</a>)',
    "nl": "— in Zwitserland, de Federale Commissaris voor gegevensbescherming en transparantie "
          '(<a href="https://www.edoeb.admin.ch">edoeb.admin.ch</a>)',
}
# La LPD ne fixe AUCUN âge : elle s'en remet à la capacité de discernement, qui
# s'apprécie cas par cas. Le seuil de 18 ans de ddust devient donc le seul repère.
_CH_ART8 = {
    ("cgu", "fr"): "le droit suisse, qui ne fixe aucun âge de consentement numérique et s'en remet à la capacité de discernement du mineur (art. 19 al. 1 du code civil) : nous ne recourons jamais à cette appréciation et exigeons toujours le consentement du représentant légal.",
    ("cgu", "en"): "Swiss law, which sets no digital consent age and relies instead on the minor's capacity of judgement (Article 19(1) of the Civil Code): we never rely on that assessment and always require the legal representative's consent.",
    ("cgu", "es"): "el derecho suizo, que no fija ninguna edad de consentimiento digital y se remite a la capacidad de discernimiento del menor (art. 19.1 del Código Civil): nunca recurrimos a esa apreciación y siempre exigimos el consentimiento del representante legal.",
    ("privacy", "fr"): "le droit suisse, qui ne fixe aucun âge de consentement numérique et s'en remet à la capacité de discernement du mineur (art. 19 al. 1 du code civil) : nous ne recourons jamais à cette appréciation.",
    ("privacy", "en"): "Swiss law, which sets no digital consent age and relies instead on the minor's capacity of judgement (Article 19(1) of the Civil Code): we never rely on that assessment.",
    ("privacy", "es"): "el derecho suizo, que no fija ninguna edad de consentimiento digital y se remite a la capacidad de discernimiento del menor (art. 19.1 del Código Civil): nunca recurrimos a esa apreciación.",
    ("cgu", "it"): "il diritto svizzero, che non fissa alcuna età di consenso digitale e si rimette alla capacità di discernimento del minore (art. 19 cpv. 1 del codice civile): non ricorriamo mai a tale valutazione ed esigiamo sempre il consenso del rappresentante legale.",
    ("cgu", "de"): "das schweizerische Recht, das kein Alter der digitalen Einwilligung festlegt und stattdessen auf die Urteilsfähigkeit der minderjährigen Person abstellt (Art. 19 Abs. 1 des Zivilgesetzbuchs): wir stützen uns nie auf diese Beurteilung und verlangen stets die Einwilligung des gesetzlichen Vertreters.",
    ("cgu", "pt"): "o direito suíço, que não fixa qualquer idade de consentimento digital e se remete à capacidade de discernimento do menor (art. 19.º n.º 1 do Código Civil): nunca recorremos a essa apreciação e exigimos sempre o consentimento do representante legal.",
    ("cgu", "nl"): "het Zwitserse recht, dat geen leeftijd voor digitale toestemming vaststelt en zich verlaat op het oordeelsvermogen van de minderjarige (art. 19 lid 1 van het Burgerlijk Wetboek): wij doen nooit een beroep op die beoordeling en eisen steeds de toestemming van de wettelijke vertegenwoordiger.",
    ("privacy", "it"): "il diritto svizzero, che non fissa alcuna età di consenso digitale e si rimette alla capacità di discernimento del minore (art. 19 cpv. 1 del codice civile): non ricorriamo mai a tale valutazione.",
    ("privacy", "de"): "das schweizerische Recht, das kein Alter der digitalen Einwilligung festlegt und stattdessen auf die Urteilsfähigkeit der minderjährigen Person abstellt (Art. 19 Abs. 1 des Zivilgesetzbuchs): wir stützen uns nie auf diese Beurteilung.",
    ("privacy", "pt"): "o direito suíço, que não fixa qualquer idade de consentimento digital e se remete à capacidade de discernimento do menor (art. 19.º n.º 1 do Código Civil): nunca recorremos a essa apreciação.",
    ("privacy", "nl"): "het Zwitserse recht, dat geen leeftijd voor digitale toestemming vaststelt en zich verlaat op het oordeelsvermogen van de minderjarige (art. 19 lid 1 van het Burgerlijk Wetboek): wij doen nooit een beroep op die beoordeling.",
}
# Les cinq autres renvois au RGPD de la politique, chacun vers SON équivalent.
_CH_RENVOIS = {
    "fr": [("Consentement de son tuteur légal (article 8 du RGPD)",
            "Consentement de son représentant légal (art. 6 al. 6 LPD)"),
           ("le consentement parental de l'article 8 du RGPD",
            "le consentement du représentant légal"),
           ("Conformément au RGPD", "Conformément à la LPD"),
           (": conformément à l'article 7(3) du RGPD,", " :"),
           ("votre consentement (article 6.1.a du RGPD)", "votre consentement (art. 6 al. 6 LPD)")],
    "en": [("Consent of their legal guardian (Article 8 GDPR)",
            "Consent of their legal representative (Article 6(6) FADP)"),
           ("the parental consent of Article 8 GDPR", "the legal representative's consent"),
           ("Under the GDPR", "Under the FADP"),
           (": in accordance with Article 7(3) GDPR,", ":"),
           ("your consent (Article 6(1)(a) GDPR)", "your consent (Article 6(6) FADP)")],
    "es": [("Consentimiento de su tutor legal (artículo 8 del RGPD)",
            "Consentimiento de su representante legal (art. 6.6 LPD)"),
           ("el consentimiento parental del artículo 8 del RGPD", "el consentimiento del representante legal"),
           ("Conforme al RGPD", "Conforme a la LPD"),
           (": conforme al artículo 7(3) del RGPD,", ":"),
           ("su consentimiento (artículo 6.1.a del RGPD)", "su consentimiento (art. 6.6 LPD)")],
    "it": [("Consenso del suo tutore legale (articolo 8 del RGPD)",
            "Consenso del suo rappresentante legale (art. 6 cpv. 6 LPD)"),
           ("il consenso parentale dell'articolo 8 del RGPD",
            "il consenso del rappresentante legale"),
           ("Conformemente al RGPD", "Conformemente alla LPD"),
           (": conformemente all'articolo 7(3) del RGPD,", ":"),
           ("il vostro consenso (articolo 6.1.a del RGPD)", "il vostro consenso (art. 6 cpv. 6 LPD)")],
    "de": [("Einwilligung seines gesetzlichen Vormunds (Artikel 8 der DSGVO)",
            "Einwilligung seines gesetzlichen Vertreters (Art. 6 Abs. 6 DSG)"),
           ("die elterliche Einwilligung nach Artikel 8 der DSGVO",
            "die Einwilligung des gesetzlichen Vertreters"),
           ("Gemäß der DSGVO", "Gemäß dem DSG"),
           (": gemäß Artikel 7(3) der DSGVO <strong>stellt er", ": <strong>er stellt"),
           ("Ihre Einwilligung (Artikel 6.1.a der DSGVO)", "Ihre Einwilligung (Art. 6 Abs. 6 DSG)")],
    "pt": [("Consentimento do seu tutor legal (artigo 8.º do RGPD)",
            "Consentimento do seu representante legal (art. 6.º n.º 6 da LPD)"),
           ("o consentimento parental do artigo 8.º do RGPD",
            "o consentimento do representante legal"),
           ("Em conformidade com o RGPD", "Em conformidade com a LPD"),
           (": em conformidade com o artigo 7(3) do RGPD,", ":"),
           ("o seu consentimento (artigo 6.1.a do RGPD)", "o seu consentimento (art. 6.º n.º 6 da LPD)")],
    "nl": [("Toestemming van zijn wettelijke voogd (artikel 8 van de AVG)",
            "Toestemming van zijn wettelijke vertegenwoordiger (art. 6 lid 6 DSG)"),
           ("de ouderlijke toestemming van artikel 8 van de AVG",
            "de toestemming van de wettelijke vertegenwoordiger"),
           ("Overeenkomstig de AVG", "Overeenkomstig het DSG"),
           (": overeenkomstig artikel 7(3) van de AVG <strong>doet zij", ": <strong>zij doet"),
           ("uw toestemming (artikel 6.1.a van de AVG)", "uw toestemming (art. 6 lid 6 DSG)")],
}


def _ch_blocks(lang, doc):

    """Les ecarts suisses d'UN document adulte, dans l'ordre d'application."""
    out = [(_UK_ART8_SRC[(doc, lang)], _CH_ART8[(doc, lang)])]
    if doc == "cgu":
        out.append((_UK_HEBERGEMENT_SRC[lang], _CH_HEBERGEMENT[lang]))
        out.append((_CH_RETRACTATION_SRC[lang], _CH_RETRACTATION[lang]))
        out.append((_CH_LOI_SRC[lang], _CH_LOI[lang]))
        out.append((_MEDIATION_SRC[lang], _CH_MEDIATION[lang]))
    else:
        out.append((_AUTORITE_SRC[lang], _CH_PFPDT[lang]))
        out.append((_EEE_STOCKAGE_SRC[lang], _CH_STOCKAGE[lang]))
        out.append((_PRESCRIPTION_SRC[lang], _PRESCRIPTION["ch"][lang]))
        out.extend(_CH_RENVOIS[lang])
    return out


# =============================================================================
# CANADA — le premier marché dérivé du corpus AMÉRICAIN, et pourquoi
# =============================================================================
# ⚠ `ca` NE SE DÉRIVE PAS DE `fr`, contrairement aux six marchés précédents, et
#   c'est le `cloud` qui l'impose : `ca` vit dans le datacenter `us`. En dérivant
#   de `fr`, deux choses casseraient d'un coup — `_retarget_links` ne réécrit
#   JAMAIS le bucket, donc les liens pointeraient vers `dvddust-eu-documents-
#   storage` ; et tout le corpus annoncerait un stockage dans l'Union, qui serait
#   faux. Le corpus `us` est déjà dans le bon bucket et dit déjà la bonne chose.
#
# ⚠ LE CORPUS `us` N'A PAS LA MÊME PHRASÉOLOGIE que l'européen : « (ici : … ) » et
#   non « (aujourd'hui : … ) », « Ici, c'est les États-Unis » et non « Pour
#   l'instant, c'est … », plus une mention de région au §1 de la politique qui
#   n'existe pas côté européen. D'où BODY_REGION_US.
#
# ⚠ COPPA N'A AUCUN ÉQUIVALENT FÉDÉRAL AU CANADA. La LPRPDE ne fixe pas d'âge ;
#   c'est la LOI 25 québécoise qui exige le consentement du titulaire de l'autorité
#   parentale en deçà de 14 ans. Et la majorité est de 18 ou 19 ans selon la
#   province, là où les États-Unis en donnaient une seule.
#
# ⚠ LE FRANÇAIS N'Y EST PAS UN CONFORT MAIS UNE OBLIGATION. La Charte de la langue
#   française impose le français aux contrats d'adhésion au Québec. Le corpus le
#   couvre déjà : `ca` est, avec `uk`, le seul marché sans mur de la langue.
_US_HEBERGEMENT_SRC = {
    "fr": "avec stockage des données aux États-Unis.",
    "en": "with data stored in the United States.",
    "es": "con almacenamiento de los datos en los Estados Unidos.",
    "it": "con archiviazione dei dati negli Stati Uniti.",
    "de": "mit Speicherung der Daten in den Vereinigten Staaten.",
    "pt": "com armazenamento dos dados nos Estados Unidos.",
    "nl": "met opslag van de gegevens in de Verenigde Staten.",
}
_CA_HEBERGEMENT = {
    "fr": "avec stockage des données aux États-Unis. Vos renseignements personnels sont donc traités "
          "<strong>hors du Canada</strong> et peuvent, à ce titre, être accessibles aux autorités "
          "américaines en vertu du droit qui leur est applicable.",
    "en": "with data stored in the United States. Your personal information is therefore processed "
          "<strong>outside Canada</strong> and may, on that basis, be accessible to United States "
          "authorities under the law applicable to them.",
    "es": "con almacenamiento de los datos en los Estados Unidos. Su información personal se trata por tanto "
          "<strong>fuera de Canadá</strong> y puede, por ello, ser accesible a las autoridades "
          "estadounidenses en virtud del derecho que les resulta aplicable.",
    "it": "con archiviazione dei dati negli Stati Uniti. Le vostre informazioni personali sono quindi trattate "
          "<strong>fuori dal Canada</strong> e possono, a tale titolo, essere accessibili alle autorità "
          "statunitensi in virtù del diritto loro applicabile.",
    "de": "mit Speicherung der Daten in den Vereinigten Staaten. Ihre personenbezogenen Informationen werden "
          "somit <strong>außerhalb Kanadas</strong> verarbeitet und können deshalb den US-Behörden nach dem "
          "für sie geltenden Recht zugänglich sein.",
    "pt": "com armazenamento dos dados nos Estados Unidos. As suas informações pessoais são portanto tratadas "
          "<strong>fora do Canadá</strong> e podem, a esse título, ser acessíveis às autoridades "
          "norte-americanas ao abrigo do direito que lhes é aplicável.",
    "nl": "met opslag van de gegevens in de Verenigde Staten. Uw persoonlijke informatie wordt dus "
          "<strong>buiten Canada</strong> verwerkt en kan uit dien hoofde toegankelijk zijn voor de "
          "Amerikaanse autoriteiten op grond van het recht dat op hen van toepassing is.",
}
_US_SEUILS_SRC = {
    "fr": "(seuils applicables aux États-Unis : 13 ans, âge fixé par le Children's Online Privacy Protection Act, et 18 ans, âge de la majorité contractuelle)",
    "en": "(thresholds applicable in the United States: 13, the age set by the Children's Online Privacy Protection Act, and 18, the age of contractual majority)",
    "es": "(umbrales aplicables en los Estados Unidos: 13 años, edad fijada por la Children's Online Privacy Protection Act, y 18 años, edad de la mayoría contractual)",
    "it": "(soglie applicabili negli Stati Uniti: 13 anni, età fissata dal Children's Online Privacy Protection Act, e 18 anni, età della maggiore età contrattuale)",
    "de": "(in den Vereinigten Staaten geltende Schwellen: 13, das durch den Children's Online Privacy Protection Act festgelegte Alter, und 18, das Alter der Vertragsmündigkeit)",
    "pt": "(limiares aplicáveis nos Estados Unidos: 13 anos, idade fixada pela Children's Online Privacy Protection Act, e 18 anos, idade da maioridade contratual)",
    "nl": "(in de Verenigde Staten geldende drempels: 13 jaar, de leeftijd vastgesteld door de Children's Online Privacy Protection Act, en 18 jaar, de leeftijd van de contractuele meerderjarigheid)",
}
_CA_SEUILS = {
    "fr": "(seuils applicables au Canada : 14 ans, âge en deçà duquel la Loi 25 exige au Québec le consentement du titulaire de l'autorité parentale, et 18 ans, seuil retenu par l'Application — la majorité est de 18 ou 19 ans selon la province)",
    "en": "(thresholds applicable in Canada: 14, the age below which Quebec's Law 25 requires the consent of the person having parental authority, and 18, the threshold used by the Application — the age of majority is 18 or 19 depending on the province)",
    "es": "(umbrales aplicables en Canadá: 14 años, edad por debajo de la cual la Ley 25 exige en Quebec el consentimiento del titular de la autoridad parental, y 18 años, umbral adoptado por la Aplicación — la mayoría de edad es de 18 o 19 años según la provincia)",
    "it": "(soglie applicabili in Canada: 14 anni, età al di sotto della quale la Legge 25 esige in Québec il consenso del titolare dell'autorità parentale, e 18 anni, soglia adottata dall'Applicazione — la maggiore età è di 18 o 19 anni secondo la provincia)",
    "de": "(in Kanada geltende Schwellen: 14, das Alter, unterhalb dessen das Gesetz 25 in Quebec die Einwilligung des Inhabers der elterlichen Sorge verlangt, und 18, die von der Anwendung verwendete Schwelle — die Volljährigkeit liegt je nach Provinz bei 18 oder 19 Jahren)",
    "pt": "(limiares aplicáveis no Canadá: 14 anos, idade abaixo da qual a Lei 25 exige no Quebeque o consentimento do titular da autoridade parental, e 18 anos, limiar adotado pela Aplicação — a maioridade é de 18 ou 19 anos consoante a província)",
    "nl": "(in Canada geldende drempels: 14 jaar, de leeftijd waaronder Wet 25 in Quebec de toestemming van de houder van het ouderlijk gezag vereist, en 18 jaar, de door de Applicatie gehanteerde drempel — de meerderjarigheid ligt naargelang de provincie op 18 of 19 jaar)",
}
_US_H2_CGU_SRC = {
    "fr": "<h2>6. Enfants : consentement parental au titre de COPPA</h2>",
    "en": "<h2>6. Children: parental consent under COPPA</h2>",
    "es": "<h2>6. Niños: consentimiento parental conforme a COPPA</h2>",
    "it": "<h2>6. Bambini: consenso parentale ai sensi del COPPA</h2>",
    "de": "<h2>6. Kinder: elterliche Einwilligung nach COPPA</h2>",
    "pt": "<h2>6. Crianças: consentimento parental ao abrigo da COPPA</h2>",
    "nl": "<h2>6. Kinderen: ouderlijke toestemming onder COPPA</h2>",
}
_CA_H2_CGU = {
    "fr": "<h2>6. Mineurs : consentement parental (LPRPDE et Loi 25)</h2>",
    "en": "<h2>6. Minors: parental consent (PIPEDA and Law 25)</h2>",
    "es": "<h2>6. Menores: consentimiento parental (PIPEDA y Ley 25)</h2>",
    "it": "<h2>6. Minori: consenso parentale (PIPEDA e Legge 25)</h2>",
    "de": "<h2>6. Minderjährige: elterliche Einwilligung (PIPEDA und Gesetz 25)</h2>",
    "pt": "<h2>6. Menores: consentimento parental (PIPEDA e Lei 25)</h2>",
    "nl": "<h2>6. Minderjarigen: ouderlijke toestemming (PIPEDA en Wet 25)</h2>",
}
_US_CADRE_SRC = {
    "fr": "La collecte d'informations personnelles auprès d'un enfant de moins de 13 ans est encadrée par le <strong>Children's Online Privacy Protection Act (COPPA)</strong> et par son règlement d'application.",
    "en": "The collection of personal information from a child under 13 is governed by the <strong>Children's Online Privacy Protection Act (COPPA)</strong> and by its implementing rule.",
    "es": "La recogida de información personal de un niño menor de 13 años está regulada por la <strong>Children's Online Privacy Protection Act (COPPA)</strong> y por su reglamento de aplicación.",
    "it": "La raccolta di informazioni personali presso un bambino di età inferiore a 13 anni è disciplinata dal <strong>Children's Online Privacy Protection Act (COPPA)</strong> e dal suo regolamento di attuazione.",
    "de": "Die Erhebung personenbezogener Informationen bei einem Kind unter 13 Jahren wird durch den <strong>Children's Online Privacy Protection Act (COPPA)</strong> und durch seine Durchführungsverordnung geregelt.",
    "pt": "A recolha de informações pessoais junto de uma criança com menos de 13 anos é regida pela <strong>Children's Online Privacy Protection Act (COPPA)</strong> e pelo seu regulamento de execução.",
    "nl": "Het verzamelen van persoonlijke informatie bij een kind jonger dan 13 jaar wordt beheerst door de <strong>Children's Online Privacy Protection Act (COPPA)</strong> en door de uitvoeringsregeling ervan.",
}
_CA_CADRE = {
    "fr": "La collecte de renseignements personnels auprès d'un mineur est encadrée par la <strong>Loi sur la protection des renseignements personnels et les documents électroniques (LPRPDE)</strong> et, au Québec, par la <strong>Loi 25</strong>, qui exige le consentement du titulaire de l'autorité parentale pour tout mineur de moins de 14 ans.",
    "en": "The collection of personal information from a minor is governed by the <strong>Personal Information Protection and Electronic Documents Act (PIPEDA)</strong> and, in Quebec, by <strong>Law 25</strong>, which requires the consent of the person having parental authority for any minor under 14.",
    "es": "La recogida de información personal de un menor está regulada por la <strong>Ley de protección de la información personal y los documentos electrónicos (PIPEDA)</strong> y, en Quebec, por la <strong>Ley 25</strong>, que exige el consentimiento del titular de la autoridad parental para todo menor de 14 años.",
    "it": "La raccolta di informazioni personali presso un minore è disciplinata dalla <strong>Legge sulla protezione delle informazioni personali e i documenti elettronici (PIPEDA)</strong> e, in Québec, dalla <strong>Legge 25</strong>, che esige il consenso del titolare dell'autorità parentale per ogni minore di età inferiore a 14 anni.",
    "de": "Die Erhebung personenbezogener Informationen bei einer minderjährigen Person wird durch den <strong>Personal Information Protection and Electronic Documents Act (PIPEDA)</strong> und, in Quebec, durch das <strong>Gesetz 25</strong> geregelt, das für jede minderjährige Person unter 14 Jahren die Einwilligung des Inhabers der elterlichen Sorge verlangt.",
    "pt": "A recolha de informações pessoais junto de um menor é regida pela <strong>Lei de proteção das informações pessoais e dos documentos eletrónicos (PIPEDA)</strong> e, no Quebeque, pela <strong>Lei 25</strong>, que exige o consentimento do titular da autoridade parental para qualquer menor de 14 anos.",
    "nl": "Het verzamelen van persoonlijke informatie bij een minderjarige wordt beheerst door de <strong>Personal Information Protection and Electronic Documents Act (PIPEDA)</strong> en, in Quebec, door <strong>Wet 25</strong>, die voor elke minderjarige onder de 14 jaar de toestemming van de houder van het ouderlijk gezag vereist.",
}
_US_RESERVE_SRC = {
    "fr": "sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre État de résidence, que les présentes conditions n'excluent ni ne limitent.",
    "en": "without prejudice to the mandatory consumer-protection provisions applicable in your state of residence, which these terms neither exclude nor limit.",
    "es": "sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su estado de residencia, que las presentes condiciones no excluyen ni limitan.",
    "it": "fatte salve le disposizioni imperative di protezione dei consumatori applicabili nel vostro Stato di residenza, che le presenti condizioni non escludono né limitano.",
    "de": "unbeschadet der zwingenden Verbraucherschutzbestimmungen, die in Ihrem Wohnsitzstaat anwendbar sind und die diese Bedingungen weder ausschließen noch beschränken.",
    "pt": "sem prejuízo das disposições imperativas de proteção dos consumidores aplicáveis no seu Estado de residência, que as presentes condições não excluem nem limitam.",
    "nl": "onverminderd de dwingende bepalingen inzake consumentenbescherming die van toepassing zijn in uw staat van verblijf, die deze voorwaarden noch uitsluiten noch beperken.",
}
_CA_RESERVE = {
    "fr": "sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre <strong>province ou territoire de résidence</strong>, que les présentes conditions n'excluent ni ne limitent. Si vous résidez au Québec, l'article 3117 du Code civil du Québec vous garantit le bénéfice de ces dispositions et la compétence des tribunaux québécois.",
    "en": "without prejudice to the mandatory consumer-protection provisions applicable in your <strong>province or territory of residence</strong>, which these terms neither exclude nor limit. If you reside in Quebec, article 3117 of the Civil Code of Québec guarantees you the benefit of those provisions and the jurisdiction of Quebec courts.",
    "es": "sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su <strong>provincia o territorio de residencia</strong>, que las presentes condiciones no excluyen ni limitan. Si reside en Quebec, el artículo 3117 del Código Civil de Quebec le garantiza el beneficio de esas disposiciones y la competencia de los tribunales quebequenses.",
    "it": "fatte salve le disposizioni imperative di protezione dei consumatori applicabili nella vostra <strong>provincia o territorio di residenza</strong>, che le presenti condizioni non escludono né limitano. Se risiedete in Québec, l'articolo 3117 del Codice civile del Québec vi garantisce il beneficio di tali disposizioni e la competenza dei tribunali quebecchesi.",
    "de": "unbeschadet der zwingenden Verbraucherschutzbestimmungen, die in Ihrer <strong>Wohnsitzprovinz oder Ihrem Wohnsitzterritorium</strong> anwendbar sind und die diese Bedingungen weder ausschließen noch beschränken. Wenn Sie in Quebec wohnen, garantiert Ihnen Artikel 3117 des Zivilgesetzbuchs von Quebec den Genuss dieser Bestimmungen und die Zuständigkeit der Gerichte Quebecs.",
    "pt": "sem prejuízo das disposições imperativas de proteção dos consumidores aplicáveis na sua <strong>província ou território de residência</strong>, que as presentes condições não excluem nem limitam. Se residir no Quebeque, o artigo 3117 do Código Civil do Quebeque garante-lhe o benefício dessas disposições e a competência dos tribunais quebequenses.",
    "nl": "onverminderd de dwingende bepalingen inzake consumentenbescherming die van toepassing zijn in uw <strong>provincie of territorium van verblijf</strong>, die deze voorwaarden noch uitsluiten noch beperken. Als u in Quebec verblijft, waarborgt artikel 3117 van het Burgerlijk Wetboek van Quebec u het genot van die bepalingen en de bevoegdheid van de Quebecse rechtbanken.",
}
_US_FTC_CGU_SRC = {
    "fr": ', notamment la Federal Trade Commission (<a href="https://www.ftc.gov">www.ftc.gov</a>) pour les questions relatives à la vie privée des enfants, ainsi que le procureur général de votre État.',
    "en": ", in particular the Federal Trade Commission (<a href=\"https://www.ftc.gov\">www.ftc.gov</a>) for matters relating to children's privacy, and the attorney general of your state.",
    "es": ', en particular a la Federal Trade Commission (<a href="https://www.ftc.gov">www.ftc.gov</a>) para las cuestiones relativas a la privacidad de los niños, así como al fiscal general de su estado.',
    "it": ', in particolare la Federal Trade Commission (<a href="https://www.ftc.gov">www.ftc.gov</a>) per le questioni relative alla privacy dei bambini, nonché il procuratore generale del vostro Stato.',
    "de": ', insbesondere der Federal Trade Commission (<a href="https://www.ftc.gov">www.ftc.gov</a>) für Fragen der Privatsphäre von Kindern, sowie dem Attorney General Ihres Bundesstaats.',
    "pt": ', em particular a Federal Trade Commission (<a href="https://www.ftc.gov">www.ftc.gov</a>) para as questões relativas à privacidade das crianças, e o procurador-geral do seu Estado.',
    "nl": ', in het bijzonder de Federal Trade Commission (<a href="https://www.ftc.gov">www.ftc.gov</a>) voor aangelegenheden betreffende de privacy van kinderen, en de attorney general van uw staat.',
}
_CA_FTC_CGU = {
    "fr": ', notamment le Commissariat à la protection de la vie privée du Canada (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) et, si vous résidez au Québec, la Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "en": ', in particular the Office of the Privacy Commissioner of Canada (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) and, if you reside in Quebec, the Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "es": ', en particular la Oficina del Comisionado de Privacidad de Canadá (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) y, si reside en Quebec, la Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "it": ', in particolare il Commissariato alla protezione della vita privata del Canada (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) e, se risiedete in Québec, la Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "de": ', insbesondere dem Office of the Privacy Commissioner of Canada (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) und, wenn Sie in Quebec wohnen, der Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "pt": ', em particular o Gabinete do Comissário para a Privacidade do Canadá (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) e, se residir no Quebeque, a Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "nl": ', in het bijzonder het Office of the Privacy Commissioner of Canada (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) en, als u in Quebec verblijft, de Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
}
_US_P1_SRC = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des informations de votre enfant au titre du Children's Online Privacy Protection Act (COPPA).",
    "en": "This is also the address to use to reach us about your child's information under the Children's Online Privacy Protection Act (COPPA).",
    "es": "Esta es también la dirección para contactarnos acerca de la información de su hijo conforme a la Children's Online Privacy Protection Act (COPPA).",
    "it": "Questo è anche l'indirizzo da utilizzare per contattarci in merito alle informazioni di vostro figlio ai sensi del Children's Online Privacy Protection Act (COPPA).",
    "de": "Dies ist auch die Adresse, die Sie verwenden, um uns wegen der Informationen Ihres Kindes nach dem Children's Online Privacy Protection Act (COPPA) zu erreichen.",
    "pt": "Este é também o endereço a utilizar para nos contactar acerca das informações do seu filho ao abrigo da Children's Online Privacy Protection Act (COPPA).",
    "nl": "Dit is ook het adres dat u gebruikt om ons te bereiken over de informatie van uw kind op grond van de Children's Online Privacy Protection Act (COPPA).",
}
_CA_P1 = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des renseignements personnels de votre enfant au titre de la LPRPDE et, au Québec, de la Loi 25.",
    "en": "This is also the address to use to reach us about your child's personal information under PIPEDA and, in Quebec, Law 25.",
    "es": "Esta es también la dirección para contactarnos acerca de la información personal de su hijo conforme a PIPEDA y, en Quebec, a la Ley 25.",
    "it": "Questo è anche l'indirizzo da utilizzare per contattarci in merito alle informazioni personali di vostro figlio ai sensi della PIPEDA e, in Québec, della Legge 25.",
    "de": "Dies ist auch die Adresse, die Sie verwenden, um uns wegen der personenbezogenen Informationen Ihres Kindes nach PIPEDA und, in Quebec, nach dem Gesetz 25 zu erreichen.",
    "pt": "Este é também o endereço a utilizar para nos contactar acerca das informações pessoais do seu filho ao abrigo da PIPEDA e, no Quebeque, da Lei 25.",
    "nl": "Dit is ook het adres dat u gebruikt om ons te bereiken over de persoonlijke informatie van uw kind op grond van PIPEDA en, in Quebec, Wet 25.",
}
_US_H2_P_SRC = {
    "fr": "<h2>4. Enfants de moins de 13 ans — COPPA</h2>",
    "en": "<h2>4. Children under 13 — COPPA</h2>",
    "es": "<h2>4. Niños menores de 13 años — COPPA</h2>",
    "it": "<h2>4. Bambini di età inferiore a 13 anni — COPPA</h2>",
    "de": "<h2>4. Kinder unter 13 Jahren — COPPA</h2>",
    "pt": "<h2>4. Crianças com menos de 13 anos — COPPA</h2>",
    "nl": "<h2>4. Kinderen onder de 13 jaar — COPPA</h2>",
}
_CA_H2_P = {
    "fr": "<h2>4. Mineurs — LPRPDE et Loi 25 (Québec)</h2>",
    "en": "<h2>4. Minors — PIPEDA and Law 25 (Quebec)</h2>",
    "es": "<h2>4. Menores — PIPEDA y Ley 25 (Quebec)</h2>",
    "it": "<h2>4. Minori — PIPEDA e Legge 25 (Québec)</h2>",
    "de": "<h2>4. Minderjährige — PIPEDA und Gesetz 25 (Quebec)</h2>",
    "pt": "<h2>4. Menores — PIPEDA e Lei 25 (Quebeque)</h2>",
    "nl": "<h2>4. Minderjarigen — PIPEDA en Wet 25 (Quebec)</h2>",
}
_US_SEUILS_P_SRC = {
    "fr": "Les seuils d'âge applicables aux États-Unis sont 13 et 18 ans.",
    "en": "The age thresholds applicable in the United States are 13 and 18.",
    "es": "Los umbrales de edad aplicables en los Estados Unidos son 13 y 18 años.",
    "it": "Le soglie di età applicabili negli Stati Uniti sono 13 e 18 anni.",
    "de": "Die in den Vereinigten Staaten geltenden Altersschwellen sind 13 und 18 Jahre.",
    "pt": "Os limiares de idade aplicáveis nos Estados Unidos são 13 e 18 anos.",
    "nl": "De in de Verenigde Staten geldende leeftijdsdrempels zijn 13 en 18 jaar.",
}
_CA_SEUILS_P = {
    "fr": "Le seuil retenu par l'application est 18 ans ; au Québec, la Loi 25 exige le consentement du titulaire de l'autorité parentale en deçà de 14 ans.",
    "en": "The threshold used by the application is 18; in Quebec, Law 25 requires the consent of the person having parental authority below the age of 14.",
    "es": "El umbral adoptado por la aplicación es 18 años; en Quebec, la Ley 25 exige el consentimiento del titular de la autoridad parental por debajo de los 14 años.",
    "it": "La soglia adottata dall'applicazione è 18 anni; in Québec, la Legge 25 esige il consenso del titolare dell'autorità parentale al di sotto dei 14 anni.",
    "de": "Die von der Anwendung verwendete Schwelle ist 18; in Quebec verlangt das Gesetz 25 unterhalb von 14 Jahren die Einwilligung des Inhabers der elterlichen Sorge.",
    "pt": "O limiar adotado pela aplicação é 18 anos; no Quebeque, a Lei 25 exige o consentimento do titular da autoridade parental abaixo dos 14 anos.",
    "nl": "De door de applicatie gehanteerde drempel is 18 jaar; in Quebec vereist Wet 25 onder de 14 jaar de toestemming van de houder van het ouderlijk gezag.",
}
_US_COPPA_P8_SRC = {"fr": "exigé par COPPA", "en": "required by COPPA", "es": "exigido por COPPA",
                    "it": "esigito da COPPA", "de": "von COPPA geforderte",
                    "pt": "exigido pela COPPA", "nl": "door COPPA vereiste"}
_CA_COPPA_P8 = {
    "fr": "exigé par la Loi 25 au Québec",
    "en": "required by Law 25 in Quebec",
    "es": "exigido por la Ley 25 en Quebec",
    "it": "esigito dalla Legge 25 in Québec",
    "de": "vom Gesetz 25 in Quebec geforderte",
    "pt": "exigido pela Lei 25 no Quebeque",
    "nl": "door Wet 25 in Quebec vereiste",
}
_US_FTC_P_SRC = {
    "fr": 'Vous pouvez également saisir la <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>), chargée de faire appliquer COPPA, le procureur général de votre État, ou — si vous résidez en Californie — la <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
    "en": 'You may also contact the <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>), which enforces COPPA, the attorney general of your state, or — if you live in California — the <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
    "es": 'También puede dirigirse a la <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>), encargada de hacer aplicar COPPA, al fiscal general de su estado o — si reside en California — a la <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
    "it": 'Potete anche rivolgervi alla <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>), incaricata di far applicare COPPA, al procuratore generale del vostro Stato, oppure — se vivete in California — alla <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
    "de": 'Sie können sich auch an die <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>) wenden, die COPPA durchsetzt, an den Attorney General Ihres Bundesstaats oder — wenn Sie in Kalifornien leben — an die <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
    "pt": 'Pode também dirigir-se à <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>), que faz aplicar a COPPA, ao procurador-geral do seu Estado, ou — se viver na Califórnia — à <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
    "nl": 'U kunt ook contact opnemen met de <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>), die COPPA handhaaft, met de attorney general van uw staat, of — als u in Californië woont — met de <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
}
_CA_FTC_P = {
    "fr": 'Vous pouvez également saisir le <strong>Commissariat à la protection de la vie privée du Canada</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) ou, si vous résidez au Québec, la <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "en": 'You may also contact the <strong>Office of the Privacy Commissioner of Canada</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) or, if you reside in Quebec, the <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "es": 'También puede dirigirse a la <strong>Oficina del Comisionado de Privacidad de Canadá</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) o, si reside en Quebec, a la <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "it": 'Potete anche rivolgervi al <strong>Commissariato alla protezione della vita privata del Canada</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) oppure, se risiedete in Québec, alla <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "de": 'Sie können sich auch an das <strong>Office of the Privacy Commissioner of Canada</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) wenden oder, wenn Sie in Quebec wohnen, an die <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "pt": 'Pode também dirigir-se ao <strong>Gabinete do Comissário para a Privacidade do Canadá</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) ou, se residir no Quebeque, à <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "nl": 'U kunt ook contact opnemen met het <strong>Office of the Privacy Commissioner of Canada</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) of, als u in Quebec verblijft, met de <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
}
_US_CENTRES_SRC = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis)",
    "en": "(for this region: data centres located in the United States)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos)",
    "it": "(per la presente regione: centri di dati situati negli Stati Uniti)",
    "de": "(für die vorliegende Region: Rechenzentren in den Vereinigten Staaten)",
    "pt": "(para a presente região: centros de dados situados nos Estados Unidos)",
    "nl": "(voor deze regio: datacentra gelegen in de Verenigde Staten)",
}
_CA_CENTRES = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis, donc hors du Canada)",
    "en": "(for this region: data centres located in the United States, therefore outside Canada)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos, por tanto fuera de Canadá)",
    "it": "(per la presente regione: centri di dati situati negli Stati Uniti, quindi fuori dal Canada)",
    "de": "(für die vorliegende Region: Rechenzentren in den Vereinigten Staaten, also außerhalb Kanadas)",
    "pt": "(para a presente região: centros de dados situados nos Estados Unidos, portanto fora do Canadá)",
    "nl": "(voor deze regio: datacentra gelegen in de Verenigde Staten, dus buiten Canada)",
}


# ⚠ TROIS RÉSIDUS AMÉRICAINS QUI ONT FAILLI PASSER, et qu'aucun bloc propre à un
#   marché ne visait : ils ne parlent ni de COPPA ni de la FTC, seulement de
#   « votre État ». Le corpus `us` en est truffé parce que la protection du
#   consommateur et la vie privée y sont d'abord des matières d'État. Hors des
#   États-Unis, l'unité de résidence n'est plus l'État — c'est la province au
#   Canada, le pays en Océanie —, et ces phrases devenaient fausses en silence.
#   Trouvés par le contrôle de non-régression, pas par la rédaction.
_US_ETAT_SRC = {
    "cgu": {
        "fr": "sans préjudice des droits que la loi de votre État vous reconnaît.",
        "en": "without prejudice to any rights you may have under the law of your state.",
        "es": "sin perjuicio de los derechos que le reconozca la ley de su estado.",
        "it": "fatti salvi i diritti che la legge del vostro Stato vi riconosce.",
        "de": "unbeschadet der Rechte, die Ihnen nach dem Recht Ihres Bundesstaats zustehen.",
        "pt": "sem prejuízo dos direitos que a lei do seu Estado lhe reconheça.",
        "nl": "onverminderd de rechten die u eventueel hebt op grond van het recht van uw staat.",
    },
    "privacy_a": {
        "fr": "Selon votre État de résidence, vous pouvez avoir le droit",
        "en": "Depending on your state of residence, you may have the right",
        "es": "Según su estado de residencia, puede tener derecho",
        "it": "A seconda del vostro Stato di residenza, potete avere il diritto",
        "de": "Je nach Ihrem Wohnsitzstaat können Sie das Recht haben",
        "pt": "Consoante o seu Estado de residência, pode ter o direito",
        "nl": "Afhankelijk van uw staat van verblijf kunt u het recht hebben",
    },
    "privacy_b": {
        "fr": "quel que soit leur État de résidence",
        "en": "whichever state you live in",
        "es": "cualquiera que sea su estado de residencia",
        "it": "qualunque sia lo Stato in cui vivete",
        "de": "in welchem Bundesstaat Sie auch leben",
        "pt": "qualquer que seja o Estado em que viva",
        "nl": "in welke staat u ook woont",
    },
}

# Les TROIS PHRASES DE REMPLACEMENT, par marche puis par langue, dans l'ordre
# (cgu, privacy_a, privacy_b) — c'est-a-dire l'ordre des clefs de _US_ETAT_SRC.
#
# ⚠ PHRASES ENTIERES, PAS UN NOM A EPISSER. La premiere version ne stockait que
#   le nom de l'unite — « province ou territoire », « pays » — et le glissait dans
#   un gabarit par langue. Deux choses l'ont condamnee :
#     - le FRANCAIS y perdait sa locution. « quel que soit leur Etat de residence »
#       devenait « leur province ou territoire de residence » : le « quel que soit »
#       n'etait pas dans le gabarit, et la phrase cessait d'en etre une. Les corpus
#       `ca-a-fr-privacy` et `oceanie-a-fr-privacy` portent encore le defaut ; ils
#       se regenerent en les supprimant, puisque main() ne reecrit jamais un
#       fichier existant ;
#     - l'ALLEMAND ne l'aurait jamais accepte : un nom y change de forme selon le
#       cas, et le meme mot ne peut pas remplir un genitif et un datif.
#   Une table plus longue, mais qu'on relit sans la simuler dans sa tete.
_UNITE = {
    "ca": {
        "fr": ("sans préjudice des droits que la loi de votre province ou territoire vous reconnaît.",
               "Selon votre province ou territoire de résidence, vous pouvez avoir le droit",
               "quels que soient la province ou le territoire où ils résident"),
        "en": ("without prejudice to any rights you may have under the law of your province or territory.",
               "Depending on your province or territory of residence, you may have the right",
               "whichever province or territory you live in"),
        "es": ("sin perjuicio de los derechos que le reconozca la ley de su provincia o territorio.",
               "Según su provincia o territorio de residencia, puede tener derecho",
               "cualquiera que sea su provincia o territorio"),
        "it": ("fatti salvi i diritti che la legge della vostra provincia o del vostro territorio vi riconosce.",
               "A seconda della vostra provincia o del vostro territorio di residenza, potete avere il diritto",
               "qualunque sia la provincia o il territorio in cui vivete"),
        "de": ("unbeschadet der Rechte, die Ihnen nach dem Recht Ihrer Provinz oder Ihres Territoriums zustehen.",
               "Je nach Ihrer Wohnsitzprovinz oder Ihrem Wohnsitzterritorium können Sie das Recht haben",
               "in welcher Provinz oder welchem Territorium Sie auch leben"),
        "pt": ("sem prejuízo dos direitos que a lei da sua província ou território lhe reconheça.",
               "Consoante a sua província ou território de residência, pode ter o direito",
               "qualquer que seja a província ou o território em que viva"),
        "nl": ("onverminderd de rechten die u eventueel hebt op grond van het recht van uw provincie of territorium.",
               "Afhankelijk van uw provincie of territorium van verblijf kunt u het recht hebben",
               "in welke provincie of welk territorium u ook woont"),
    },
    "oceanie": {
        "fr": ("sans préjudice des droits que la loi de votre pays vous reconnaît.",
               "Selon votre pays de résidence, vous pouvez avoir le droit",
               "quel que soit leur pays de résidence"),
        "en": ("without prejudice to any rights you may have under the law of your country.",
               "Depending on your country of residence, you may have the right",
               "whichever of the two countries you live in"),
        "es": ("sin perjuicio de los derechos que le reconozca la ley de su país.",
               "Según su país de residencia, puede tener derecho",
               "cualquiera que sea su país de residencia"),
        "it": ("fatti salvi i diritti che la legge del vostro paese vi riconosce.",
               "A seconda del vostro paese di residenza, potete avere il diritto",
               "qualunque sia il paese in cui vivete"),
        "de": ("unbeschadet der Rechte, die Ihnen nach dem Recht Ihres Landes zustehen.",
               "Je nach Ihrem Wohnsitzland können Sie das Recht haben",
               "in welchem der beiden Länder Sie auch leben"),
        "pt": ("sem prejuízo dos direitos que a lei do seu país lhe reconheça.",
               "Consoante o seu país de residência, pode ter o direito",
               "qualquer que seja o país em que viva"),
        "nl": ("onverminderd de rechten die u eventueel hebt op grond van het recht van uw land.",
               "Afhankelijk van uw land van verblijf kunt u het recht hebben",
               "in welk van beide landen u ook woont"),
    },
}


def _us_etat_blocks(market, lang, doc):

    """Les phrases du corpus americain qui disent « votre Etat », requalifiees.

    Les remplacements sont lus tels quels dans `_UNITE`, dans l'ordre des clefs de
    `_US_ETAT_SRC` : (cgu, privacy_a, privacy_b). Voir l'encadre de `_UNITE` pour
    la raison pour laquelle ils n'y sont plus composes.
    """
    cgu, privacy_a, privacy_b = _UNITE[market][lang]
    if doc == "cgu":
        return [(_US_ETAT_SRC["cgu"][lang], cgu)]
    return [(_US_ETAT_SRC["privacy_a"][lang], privacy_a),
            (_US_ETAT_SRC["privacy_b"][lang], privacy_b)]


_CA_LIMITATION = {
    "fr": "Certaines provinces n'autorisent pas l'exclusion ou la limitation de certains dommages ; dans ce cas, les limitations ci-dessus ne s'appliquent que dans la mesure permise par le droit de votre province, et rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable. Si vous résidez au Québec, la Loi sur la protection du consommateur s'applique et ne peut pas être écartée par contrat.",
    "en": "Some provinces do not allow the exclusion or limitation of certain damages; in that case the limitations above apply only to the extent permitted by the law of your province, and nothing in these terms excludes liability for gross negligence or personal injury attributable to the publisher. If you reside in Quebec, the Consumer Protection Act applies and cannot be contracted out of.",
    "es": "Algunas provincias no permiten la exclusión o limitación de determinados daños; en ese caso, las limitaciones anteriores solo se aplican en la medida permitida por el derecho de su provincia, y nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable. Si reside en Quebec, la Ley de protección del consumidor se aplica y no admite pacto en contrario.",
    "it": "Alcune province non consentono l'esclusione o la limitazione di determinati danni; in tal caso, le limitazioni di cui sopra si applicano soltanto nella misura consentita dal diritto della vostra provincia, e nulla esclude la responsabilità dell'editore in caso di colpa grave o di danno alla persona a lui imputabile. Se risiedete in Québec, la Legge sulla protezione del consumatore si applica e non può essere esclusa per contratto.",
    "de": "Einige Provinzen lassen den Ausschluss oder die Beschränkung bestimmter Schäden nicht zu; in diesem Fall gelten die vorstehenden Beschränkungen nur, soweit das Recht Ihrer Provinz dies zulässt, und nichts schließt die Haftung des Herausgebers bei grober Fahrlässigkeit oder ihm zurechenbaren Personenschäden aus. Wenn Sie in Quebec wohnen, gilt das Verbraucherschutzgesetz und kann nicht vertraglich abbedungen werden.",
    "pt": "Algumas províncias não permitem a exclusão ou limitação de determinados danos; nesse caso, as limitações acima só se aplicam na medida permitida pelo direito da sua província, e nada exclui a responsabilidade do editor em caso de culpa grave ou de dano corporal que lhe seja imputável. Se residir no Quebeque, a Lei de proteção do consumidor aplica-se e não admite pacto em contrário.",
    "nl": "Sommige provincies staan de uitsluiting of beperking van bepaalde schade niet toe; in dat geval gelden de bovenstaande beperkingen alleen voor zover het recht van uw provincie dit toestaat, en niets sluit de aansprakelijkheid van de uitgever uit bij grove schuld of bij hem toerekenbare lichamelijke schade. Als u in Quebec verblijft, is de Wet op de consumentenbescherming van toepassing en kan daarvan niet contractueel worden afgeweken.",
}


def _ca_blocks(lang, doc):

    """Les ecarts canadiens d'UN document adulte, derives du corpus americain."""
    if doc == "cgu":
        return [(_US_HEBERGEMENT_SRC[lang], _CA_HEBERGEMENT[lang]),
                (_US_SEUILS_SRC[lang],      _CA_SEUILS[lang]),
                (_US_H2_CGU_SRC[lang],      _CA_H2_CGU[lang]),
                (_US_CADRE_SRC[lang],       _CA_CADRE[lang]),
                (_US_LIMITATION_SRC[lang],  _CA_LIMITATION[lang]),
                (_US_RESERVE_SRC[lang],     _CA_RESERVE[lang]),
                (_US_FTC_CGU_SRC[lang],     _CA_FTC_CGU[lang])] + _us_etat_blocks("ca", lang, doc)
    return [(_US_P1_SRC[lang],       _CA_P1[lang]),
            (_US_H2_P_SRC[lang],     _CA_H2_P[lang]),
            (_US_SEUILS_P_SRC[lang], _CA_SEUILS_P[lang]),
            (_US_COPPA_P8_SRC[lang], _CA_COPPA_P8[lang]),
            (_US_FTC_P_SRC[lang],    _CA_FTC_P[lang]),
            (_US_CENTRES_SRC[lang],  _CA_CENTRES[lang])] + _us_etat_blocks("ca", lang, doc)


# =============================================================================
# OCÉANIE — deux pays, deux lois, un seul corpus
# =============================================================================
# ⚠ PREMIER MARCHÉ QUI EN CONTIENT DEUX. `euo` et `eux` regroupaient des États
#   partageant le RGPD : une seule loi, plusieurs autorités. Ici, l'Australie et
#   la Nouvelle-Zélande ont chacune LA LEUR — Privacy Act 1988 et ses Australian
#   Privacy Principles d'un côté, Privacy Act 2020 et ses Information Privacy
#   Principles de l'autre. Chaque clause doit donc nommer les deux.
#
# ⚠ CE QUI EST NEUF ICI : LES GARANTIES LÉGALES DU CONSOMMATEUR. L'Australian
#   Consumer Law et le Consumer Guarantees Act 1993 néo-zélandais NE PEUVENT PAS
#   être écartés par contrat, et une clause de limitation qui ne les réserve pas
#   est réputée trompeuse. Aucun marché précédent ne l'exigeait — le §10 n'avait
#   jamais eu à bouger.
#
# ⚠ AUCUN ÂGE DE CONSENTEMENT dans ni l'un ni l'autre texte, comme en Suisse. Le
#   seuil de 18 ans de ddust redevient le seul repère.
#
# ⚠ PAS DE MUR DE LA LANGUE : deux pays anglophones natifs, et le corpus a `en`.
_US_REMBOURSEMENT_SRC = {
    "fr": "<li><strong>Remboursement</strong> — tous les achats et abonnements sont traités par la plateforme de téléchargement. La fourniture du contenu numérique commence immédiatement après la confirmation de l'achat. Les demandes de remboursement s'exercent auprès de la plateforme, au moyen des outils de gestion d'abonnement et d'historique d'achat de votre compte Google, selon ses conditions et sans préjudice des droits que la loi de votre État vous reconnaît.</li>",
    "en": "<li><strong>Refunds</strong> — all purchases and subscriptions are processed by the download platform. Supply of the digital content begins immediately upon confirmation of purchase. Refund requests are handled by the platform, through the subscription management and purchase history tools of your Google account, under its own conditions and without prejudice to any rights you may have under the law of your state.</li>",
    "es": "<li><strong>Reembolso</strong> — todas las compras y suscripciones las tramita la plataforma de descarga. El suministro del contenido digital comienza inmediatamente tras la confirmación de la compra. Las solicitudes de reembolso se tramitan ante la plataforma, mediante las herramientas de gestión de suscripciones y de historial de compras de su cuenta de Google, según sus condiciones y sin perjuicio de los derechos que le reconozca la ley de su estado.</li>",
    "it": "<li><strong>Rimborso</strong> — tutti gli acquisti e gli abbonamenti sono gestiti dalla piattaforma di download. La fornitura del contenuto digitale inizia immediatamente dopo la conferma dell'acquisto. Le richieste di rimborso si esercitano presso la piattaforma, mediante gli strumenti di gestione dell'abbonamento e di cronologia degli acquisti del vostro account Google, secondo le sue condizioni e fatti salvi i diritti che la legge del vostro Stato vi riconosce.</li>",
    "de": "<li><strong>Erstattungen</strong> — alle Käufe und Abonnements werden von der Download-Plattform abgewickelt. Die Bereitstellung der digitalen Inhalte beginnt unmittelbar nach der Kaufbestätigung. Erstattungsanträge werden von der Plattform bearbeitet, über die Werkzeuge zur Abonnementverwaltung und zum Kaufverlauf Ihres Google-Kontos, zu ihren eigenen Bedingungen und unbeschadet der Rechte, die Ihnen nach dem Recht Ihres Bundesstaats zustehen.</li>",
    "pt": "<li><strong>Reembolsos</strong> — todas as compras e subscrições são tratadas pela plataforma de descarregamento. O fornecimento do conteúdo digital começa imediatamente após a confirmação da compra. Os pedidos de reembolso são tratados pela plataforma, através das ferramentas de gestão de subscrições e de histórico de compras da sua conta Google, segundo as suas próprias condições e sem prejuízo dos direitos que a lei do seu Estado lhe reconheça.</li>",
    "nl": "<li><strong>Terugbetalingen</strong> — alle aankopen en abonnementen worden door het downloadplatform verwerkt. De levering van de digitale inhoud begint onmiddellijk na de bevestiging van de aankoop. Verzoeken tot terugbetaling worden door het platform behandeld, via de hulpmiddelen voor abonnementenbeheer en aankoopgeschiedenis van uw Google-account, onder zijn eigen voorwaarden en onverminderd de rechten die u eventueel hebt op grond van het recht van uw staat.</li>",
}
_US_LIMITATION_SRC = {
    "fr": "Certains États n'autorisent pas l'exclusion ou la limitation de certains dommages ; dans ce cas, les limitations ci-dessus ne s'appliquent que dans la mesure permise par le droit de votre État, et rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable.",
    "en": "Some states do not allow the exclusion or limitation of certain damages; in that case the limitations above apply only to the extent permitted by the law of your state, and nothing in these terms excludes liability for gross negligence or personal injury attributable to the publisher.",
    "es": "Algunos estados no permiten la exclusión o limitación de determinados daños; en ese caso, las limitaciones anteriores solo se aplican en la medida permitida por el derecho de su estado, y nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable.",
    "it": "Alcuni Stati non consentono l'esclusione o la limitazione di determinati danni; in tal caso, le limitazioni di cui sopra si applicano soltanto nella misura consentita dal diritto del vostro Stato, e nulla nelle presenti condizioni esclude la responsabilità per colpa grave o per danno alla persona imputabile all'editore.",
    "de": "Einige Bundesstaaten lassen den Ausschluss oder die Beschränkung bestimmter Schäden nicht zu; in diesem Fall gelten die vorstehenden Beschränkungen nur, soweit das Recht Ihres Bundesstaats dies zulässt, und nichts in diesen Bedingungen schließt die Haftung für grobe Fahrlässigkeit oder für dem Herausgeber zurechenbare Personenschäden aus.",
    "pt": "Alguns Estados não permitem a exclusão ou limitação de determinados danos; nesse caso, as limitações acima só se aplicam na medida permitida pela lei do seu Estado, e nada nas presentes condições exclui a responsabilidade por culpa grave ou por dano corporal imputável ao editor.",
    "nl": "Sommige staten staan de uitsluiting of beperking van bepaalde schade niet toe; in dat geval gelden de bovenstaande beperkingen alleen voor zover het recht van uw staat dit toestaat, en niets in deze voorwaarden sluit de aansprakelijkheid uit voor grove nalatigheid of voor aan de uitgever toerekenbare lichamelijke schade.",
}
_OC_LIMITATION = {
    "fr": "<strong>Rien dans les présentes conditions n'exclut, ne restreint ni ne modifie les garanties du consommateur</strong> prévues par l'Australian Consumer Law ou par le Consumer Guarantees Act 1993 néo-zélandais, qui ne peuvent pas être écartées par contrat. Les limitations ci-dessus ne s'appliquent que dans la mesure permise par ces textes, et rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable.",
    "en": "<strong>Nothing in these terms excludes, restricts or modifies the consumer guarantees</strong> conferred by the Australian Consumer Law or by the New Zealand Consumer Guarantees Act 1993, which cannot be contracted out of. The limitations above apply only to the extent permitted by those Acts, and nothing excludes liability for gross negligence or personal injury attributable to the publisher.",
    "es": "<strong>Nada en las presentes condiciones excluye, restringe ni modifica las garantías del consumidor</strong> previstas por la Australian Consumer Law o por la Consumer Guarantees Act 1993 neozelandesa, que no pueden excluirse por contrato. Las limitaciones anteriores solo se aplican en la medida permitida por esos textos, y nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable.",
    "it": "<strong>Nulla nelle presenti condizioni esclude, limita o modifica le garanzie del consumatore</strong> previste dall'Australian Consumer Law o dal Consumer Guarantees Act 1993 neozelandese, che non possono essere escluse per contratto. Le limitazioni di cui sopra si applicano soltanto nella misura consentita da tali testi, e nulla esclude la responsabilità dell'editore in caso di colpa grave o di danno alla persona a lui imputabile.",
    "de": "<strong>Nichts in diesen Bedingungen schließt die Verbrauchergarantien aus, schränkt sie ein oder ändert sie</strong>, die durch das Australian Consumer Law oder den neuseeländischen Consumer Guarantees Act 1993 gewährt werden und vertraglich nicht abbedungen werden können. Die vorstehenden Beschränkungen gelten nur, soweit diese Gesetze es zulassen, und nichts schließt die Haftung des Herausgebers bei grober Fahrlässigkeit oder ihm zurechenbaren Personenschäden aus.",
    "pt": "<strong>Nada nas presentes condições exclui, restringe ou modifica as garantias do consumidor</strong> previstas pela Australian Consumer Law ou pela Consumer Guarantees Act 1993 neozelandesa, que não podem ser afastadas por contrato. As limitações acima só se aplicam na medida permitida por esses diplomas, e nada exclui a responsabilidade do editor em caso de culpa grave ou de dano corporal que lhe seja imputável.",
    "nl": "<strong>Niets in deze voorwaarden sluit de consumentengaranties uit, beperkt of wijzigt ze</strong> die worden verleend door de Australian Consumer Law of de Nieuw-Zeelandse Consumer Guarantees Act 1993, waarvan niet contractueel kan worden afgeweken. De bovenstaande beperkingen gelden alleen voor zover die wetten dat toestaan, en niets sluit de aansprakelijkheid van de uitgever uit bij grove schuld of bij hem toerekenbare lichamelijke schade.",
}
_OC_HEBERGEMENT = {
    "fr": "avec stockage des données aux États-Unis. Vos renseignements personnels sont donc communiqués "
          "<strong>hors d'Australie et de Nouvelle-Zélande</strong> ; l'éditeur demeure responsable de leur "
          "traitement par son hébergeur, conformément au principe 8 des Australian Privacy Principles et au "
          "principe 12 du Privacy Act 2020 néo-zélandais.",
    "en": "with data stored in the United States. Your personal information is therefore disclosed "
          "<strong>outside Australia and New Zealand</strong>; the publisher remains accountable for its "
          "handling by its host, in accordance with Australian Privacy Principle 8 and Information Privacy "
          "Principle 12 of the New Zealand Privacy Act 2020.",
    "es": "con almacenamiento de los datos en los Estados Unidos. Su información personal se comunica por tanto "
          "<strong>fuera de Australia y Nueva Zelanda</strong>; el editor sigue siendo responsable de su "
          "tratamiento por su alojador, conforme al principio 8 de los Australian Privacy Principles y al "
          "principio 12 de la Privacy Act 2020 neozelandesa.",
    "it": "con archiviazione dei dati negli Stati Uniti. Le vostre informazioni personali sono quindi comunicate "
          "<strong>fuori dall'Australia e dalla Nuova Zelanda</strong>; l'editore resta responsabile del loro "
          "trattamento da parte del suo fornitore di hosting, conformemente al principio 8 degli Australian "
          "Privacy Principles e al principio 12 del Privacy Act 2020 neozelandese.",
    "de": "mit Speicherung der Daten in den Vereinigten Staaten. Ihre personenbezogenen Informationen werden "
          "somit <strong>außerhalb Australiens und Neuseelands</strong> offengelegt; der Herausgeber bleibt für "
          "ihre Behandlung durch seinen Hoster verantwortlich, gemäß Australian Privacy Principle 8 und "
          "Information Privacy Principle 12 des neuseeländischen Privacy Act 2020.",
    "pt": "com armazenamento dos dados nos Estados Unidos. As suas informações pessoais são portanto "
          "comunicadas <strong>fora da Austrália e da Nova Zelândia</strong>; o editor continua responsável "
          "pelo seu tratamento pelo seu alojador, em conformidade com o princípio 8 dos Australian Privacy "
          "Principles e com o princípio 12 da Privacy Act 2020 neozelandesa.",
    "nl": "met opslag van de gegevens in de Verenigde Staten. Uw persoonlijke informatie wordt dus "
          "<strong>buiten Australië en Nieuw-Zeeland</strong> bekendgemaakt; de uitgever blijft "
          "verantwoordelijk voor de behandeling ervan door zijn hoster, overeenkomstig Australian Privacy "
          "Principle 8 en Information Privacy Principle 12 van de Nieuw-Zeelandse Privacy Act 2020.",
}
_OC_SEUILS = {
    "fr": "(ni le Privacy Act 1988 australien ni le Privacy Act 2020 néo-zélandais ne fixent d'âge de consentement : l'Application retient 18 ans et exige dans tous les cas le consentement d'un adulte responsable)",
    "en": "(neither the Australian Privacy Act 1988 nor the New Zealand Privacy Act 2020 sets a consent age: the Application uses 18 and always requires the consent of a responsible adult)",
    "es": "(ni la Privacy Act 1988 australiana ni la Privacy Act 2020 neozelandesa fijan una edad de consentimiento: la Aplicación adopta los 18 años y exige en todo caso el consentimiento de un adulto responsable)",
    "it": "(né il Privacy Act 1988 australiano né il Privacy Act 2020 neozelandese fissano un'età di consenso: l'Applicazione adotta i 18 anni ed esige in ogni caso il consenso di un adulto responsabile)",
    "de": "(weder der australische Privacy Act 1988 noch der neuseeländische Privacy Act 2020 legt ein Einwilligungsalter fest: die Anwendung verwendet 18 und verlangt in jedem Fall die Einwilligung eines verantwortlichen Erwachsenen)",
    "pt": "(nem a Privacy Act 1988 australiana nem a Privacy Act 2020 neozelandesa fixam uma idade de consentimento: a Aplicação adota os 18 anos e exige em todo o caso o consentimento de um adulto responsável)",
    "nl": "(noch de Australische Privacy Act 1988 noch de Nieuw-Zeelandse Privacy Act 2020 stelt een toestemmingsleeftijd vast: de Applicatie hanteert 18 jaar en vereist in alle gevallen de toestemming van een verantwoordelijke volwassene)",
}
_OC_H2_CGU = {
    "fr": "<h2>6. Mineurs : consentement parental (Privacy Act 1988 et Privacy Act 2020)</h2>",
    "en": "<h2>6. Minors: parental consent (Privacy Act 1988 and Privacy Act 2020)</h2>",
    "es": "<h2>6. Menores: consentimiento parental (Privacy Act 1988 y Privacy Act 2020)</h2>",
    "it": "<h2>6. Minori: consenso parentale (Privacy Act 1988 e Privacy Act 2020)</h2>",
    "de": "<h2>6. Minderjährige: elterliche Einwilligung (Privacy Act 1988 und Privacy Act 2020)</h2>",
    "pt": "<h2>6. Menores: consentimento parental (Privacy Act 1988 e Privacy Act 2020)</h2>",
    "nl": "<h2>6. Minderjarigen: ouderlijke toestemming (Privacy Act 1988 en Privacy Act 2020)</h2>",
}
_OC_CADRE = {
    "fr": "La collecte de renseignements personnels auprès d'un mineur est encadrée par le <strong>Privacy Act 1988</strong> et les Australian Privacy Principles en Australie, et par le <strong>Privacy Act 2020</strong> et ses Information Privacy Principles en Nouvelle-Zélande.",
    "en": "The collection of personal information from a minor is governed by the <strong>Privacy Act 1988</strong> and the Australian Privacy Principles in Australia, and by the <strong>Privacy Act 2020</strong> and its Information Privacy Principles in New Zealand.",
    "es": "La recogida de información personal de un menor está regulada por la <strong>Privacy Act 1988</strong> y los Australian Privacy Principles en Australia, y por la <strong>Privacy Act 2020</strong> y sus Information Privacy Principles en Nueva Zelanda.",
    "it": "La raccolta di informazioni personali presso un minore è disciplinata dal <strong>Privacy Act 1988</strong> e dagli Australian Privacy Principles in Australia, e dal <strong>Privacy Act 2020</strong> e dai suoi Information Privacy Principles in Nuova Zelanda.",
    "de": "Die Erhebung personenbezogener Informationen bei einer minderjährigen Person wird durch den <strong>Privacy Act 1988</strong> und die Australian Privacy Principles in Australien sowie durch den <strong>Privacy Act 2020</strong> und seine Information Privacy Principles in Neuseeland geregelt.",
    "pt": "A recolha de informações pessoais junto de um menor é regida pela <strong>Privacy Act 1988</strong> e pelos Australian Privacy Principles na Austrália, e pela <strong>Privacy Act 2020</strong> e pelos seus Information Privacy Principles na Nova Zelândia.",
    "nl": "Het verzamelen van persoonlijke informatie bij een minderjarige wordt beheerst door de <strong>Privacy Act 1988</strong> en de Australian Privacy Principles in Australië, en door de <strong>Privacy Act 2020</strong> en zijn Information Privacy Principles in Nieuw-Zeeland.",
}
_OC_RESERVE = {
    "fr": "sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre <strong>pays de résidence</strong>, que les présentes conditions n'excluent ni ne limitent — en particulier l'Australian Consumer Law et le Consumer Guarantees Act 1993, auxquels il ne peut être dérogé par contrat.",
    "en": "without prejudice to the mandatory consumer-protection provisions applicable in your <strong>country of residence</strong>, which these terms neither exclude nor limit — in particular the Australian Consumer Law and the Consumer Guarantees Act 1993, which cannot be contracted out of.",
    "es": "sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su <strong>país de residencia</strong>, que las presentes condiciones no excluyen ni limitan — en particular la Australian Consumer Law y la Consumer Guarantees Act 1993, que no admiten pacto en contrario.",
    "it": "fatte salve le disposizioni imperative di protezione dei consumatori applicabili nel vostro <strong>paese di residenza</strong>, che le presenti condizioni non escludono né limitano — in particolare l'Australian Consumer Law e il Consumer Guarantees Act 1993, ai quali non si può derogare per contratto.",
    "de": "unbeschadet der zwingenden Verbraucherschutzbestimmungen, die in Ihrem <strong>Wohnsitzland</strong> anwendbar sind und die diese Bedingungen weder ausschließen noch beschränken — insbesondere das Australian Consumer Law und der Consumer Guarantees Act 1993, von denen vertraglich nicht abgewichen werden kann.",
    "pt": "sem prejuízo das disposições imperativas de proteção dos consumidores aplicáveis no seu <strong>país de residência</strong>, que as presentes condições não excluem nem limitam — em particular a Australian Consumer Law e a Consumer Guarantees Act 1993, das quais não é possível derrogar por contrato.",
    "nl": "onverminderd de dwingende bepalingen inzake consumentenbescherming die van toepassing zijn in uw <strong>land van verblijf</strong>, die deze voorwaarden noch uitsluiten noch beperken — in het bijzonder de Australian Consumer Law en de Consumer Guarantees Act 1993, waarvan niet contractueel kan worden afgeweken.",
}
_OC_AUTORITES_CGU = {
    "fr": ', notamment l\'Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) ou, en Nouvelle-Zélande, l\'Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "en": ', in particular the Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) or, in New Zealand, the Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "es": ', en particular la Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) o, en Nueva Zelanda, la Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "it": ', in particolare l\'Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) o, in Nuova Zelanda, l\'Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "de": ', insbesondere dem Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) oder, in Neuseeland, dem Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "pt": ', em particular o Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) ou, na Nova Zelândia, o Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "nl": ', in het bijzonder het Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) of, in Nieuw-Zeeland, het Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
}
_OC_P1 = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des renseignements personnels de votre enfant au titre du Privacy Act 1988 ou du Privacy Act 2020.",
    "en": "This is also the address to use to reach us about your child's personal information under the Privacy Act 1988 or the Privacy Act 2020.",
    "es": "Esta es también la dirección para contactarnos acerca de la información personal de su hijo conforme a la Privacy Act 1988 o a la Privacy Act 2020.",
    "it": "Questo è anche l'indirizzo da utilizzare per contattarci in merito alle informazioni personali di vostro figlio ai sensi del Privacy Act 1988 o del Privacy Act 2020.",
    "de": "Dies ist auch die Adresse, die Sie verwenden, um uns wegen der personenbezogenen Informationen Ihres Kindes nach dem Privacy Act 1988 oder dem Privacy Act 2020 zu erreichen.",
    "pt": "Este é também o endereço a utilizar para nos contactar acerca das informações pessoais do seu filho ao abrigo da Privacy Act 1988 ou da Privacy Act 2020.",
    "nl": "Dit is ook het adres dat u gebruikt om ons te bereiken over de persoonlijke informatie van uw kind op grond van de Privacy Act 1988 of de Privacy Act 2020.",
}
_OC_H2_P = {
    "fr": "<h2>4. Mineurs — Privacy Act 1988 (Australie) et Privacy Act 2020 (Nouvelle-Zélande)</h2>",
    "en": "<h2>4. Minors — Privacy Act 1988 (Australia) and Privacy Act 2020 (New Zealand)</h2>",
    "es": "<h2>4. Menores — Privacy Act 1988 (Australia) y Privacy Act 2020 (Nueva Zelanda)</h2>",
    "it": "<h2>4. Minori — Privacy Act 1988 (Australia) e Privacy Act 2020 (Nuova Zelanda)</h2>",
    "de": "<h2>4. Minderjährige — Privacy Act 1988 (Australien) und Privacy Act 2020 (Neuseeland)</h2>",
    "pt": "<h2>4. Menores — Privacy Act 1988 (Austrália) e Privacy Act 2020 (Nova Zelândia)</h2>",
    "nl": "<h2>4. Minderjarigen — Privacy Act 1988 (Australië) en Privacy Act 2020 (Nieuw-Zeeland)</h2>",
}
_OC_SEUILS_P = {
    "fr": "Le seuil retenu par l'application est 18 ans ; ni le droit australien ni le droit néo-zélandais ne fixent d'âge de consentement propre au mineur.",
    "en": "The threshold used by the application is 18; neither Australian nor New Zealand law sets an age at which a minor may consent on their own.",
    "es": "El umbral adoptado por la aplicación es 18 años; ni el derecho australiano ni el neozelandés fijan una edad de consentimiento propia del menor.",
    "it": "La soglia adottata dall'applicazione è 18 anni; né il diritto australiano né quello neozelandese fissano un'età alla quale un minore può prestare il consenso da solo.",
    "de": "Die von der Anwendung verwendete Schwelle ist 18; weder das australische noch das neuseeländische Recht legt ein Alter fest, ab dem eine minderjährige Person allein einwilligen kann.",
    "pt": "O limiar adotado pela aplicação é 18 anos; nem o direito australiano nem o neozelandês fixam uma idade a partir da qual um menor pode consentir sozinho.",
    "nl": "De door de applicatie gehanteerde drempel is 18 jaar; noch het Australische noch het Nieuw-Zeelandse recht stelt een leeftijd vast waarop een minderjarige zelfstandig toestemming kan geven.",
}
_OC_COPPA_P8 = {
    "fr": "exigé d'un adulte responsable",
    "en": "required from a responsible adult",
    "es": "exigido a un adulto responsable",
    "it": "esigito da un adulto responsabile",
    "de": "von einem verantwortlichen Erwachsenen geforderte",
    "pt": "exigido a um adulto responsável",
    "nl": "van een verantwoordelijke volwassene vereiste",
}
_OC_AUTORITES_P = {
    "fr": 'Vous pouvez également saisir l\'<strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) ou, si vous résidez en Nouvelle-Zélande, l\'<strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "en": 'You may also contact the <strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) or, if you live in New Zealand, the <strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "es": 'También puede dirigirse a la <strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) o, si reside en Nueva Zelanda, a la <strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "it": 'Potete anche rivolgervi all\'<strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) oppure, se risiedete in Nuova Zelanda, all\'<strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "de": 'Sie können sich auch an das <strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) wenden oder, wenn Sie in Neuseeland leben, an das <strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "pt": 'Pode também dirigir-se ao <strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) ou, se viver na Nova Zelândia, ao <strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "nl": 'U kunt ook contact opnemen met het <strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) of, als u in Nieuw-Zeeland woont, met het <strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
}
_OC_CENTRES = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis, donc hors d'Australie et de Nouvelle-Zélande)",
    "en": "(for this region: data centres located in the United States, therefore outside Australia and New Zealand)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos, por tanto fuera de Australia y Nueva Zelanda)",
    "it": "(per la presente regione: centri di dati situati negli Stati Uniti, quindi fuori dall'Australia e dalla Nuova Zelanda)",
    "de": "(für die vorliegende Region: Rechenzentren in den Vereinigten Staaten, also außerhalb Australiens und Neuseelands)",
    "pt": "(para a presente região: centros de dados situados nos Estados Unidos, portanto fora da Austrália e da Nova Zelândia)",
    "nl": "(voor deze regio: datacentra gelegen in de Verenigde Staten, dus buiten Australië en Nieuw-Zeeland)",
}


def _oc_blocks(lang, doc):

    """Les ecarts oceaniens d'UN document adulte, derives du corpus americain."""
    if doc == "cgu":
        return [(_US_HEBERGEMENT_SRC[lang], _OC_HEBERGEMENT[lang]),
                (_US_SEUILS_SRC[lang],      _OC_SEUILS[lang]),
                (_US_H2_CGU_SRC[lang],      _OC_H2_CGU[lang]),
                (_US_CADRE_SRC[lang],       _OC_CADRE[lang]),
                (_US_LIMITATION_SRC[lang],  _OC_LIMITATION[lang]),
                (_US_RESERVE_SRC[lang],     _OC_RESERVE[lang]),
                (_US_FTC_CGU_SRC[lang],     _OC_AUTORITES_CGU[lang])] + _us_etat_blocks("oceanie", lang, doc)
    return [(_US_P1_SRC[lang],       _OC_P1[lang]),
            (_US_H2_P_SRC[lang],     _OC_H2_P[lang]),
            (_US_SEUILS_P_SRC[lang], _OC_SEUILS_P[lang]),
            (_US_COPPA_P8_SRC[lang], _OC_COPPA_P8[lang]),
            (_US_FTC_P_SRC[lang],    _OC_AUTORITES_P[lang]),
            (_US_CENTRES_SRC[lang],  _OC_CENTRES[lang])] + _us_etat_blocks("oceanie", lang, doc)


# =============================================================================
# BRÉSIL — un vrai droit de rétractation, et un droit de la consommation d'ordre public
# =============================================================================
# ⚠ LA SUISSE N'AVAIT PAS DE DROIT DE RÉTRACTATION ; LE BRÉSIL EN A UN, et il est
#   plus court que l'européen : SEPT JOURS (art. 49 du Code de défense du
#   consommateur), pour tout contrat conclu hors établissement — l'achat en ligne
#   en fait partie. La puce « Remboursement » du corpus américain, qui renvoie à la
#   seule politique de la plateforme, ne suffisait donc pas.
#
# ⚠ LE CDC EST D'ORDRE PUBLIC. Le choix du droit français ne prive un consommateur
#   brésilien d'aucune de ses protections, et l'art. 101 CDC lui ouvre le for de son
#   propre domicile. Le Marco Civil da Internet (art. 11) rattache par ailleurs au
#   droit brésilien toute collecte opérée au Brésil, quel que soit le siège de
#   l'opérateur.
#
# ⚠ LE BRÉSIL A DES ÉTATS, mais la consommation et la vie privée y sont FÉDÉRALES —
#   contrairement aux États-Unis. Les phrases en « votre État » du corpus source ne
#   se requalifient donc pas en « votre État brésilien » : elles se raccrochent au
#   CDC et à la LGPD.
#
# ⚠ LE MUR DE LA LANGUE EST TOMBÉ LE 2026-09-08. Ce bloc portait l'avertissement
#   inverse : « le portugais n'est pas au corpus (…) ce corpus est écrit, il n'est
#   pas ouvrable ». Le CDC et le décret 7.962/2013 imposent toujours une information
#   claire en portugais au consommateur brésilien — mais le portugais est désormais
#   une des sept langues du corpus. Ce marché est donc ouvrable côté LANGUE.
#   ⚠ Ouvrable ne veut pas dire ouvert : l'ouverture reste le dernier geste, dans
#     `build.yml → documents.regions`, et rien n'y figure d'autre que `fr`.
_BR_REMBOURSEMENT = {
    "fr": "<li><strong>Remboursement et rétractation</strong> — tous les achats et abonnements sont traités par la plateforme de téléchargement. <strong>L'article 49 du Code de défense du consommateur vous ouvre un droit de rétractation de sept jours</strong> à compter de l'achat, sans avoir à vous justifier ; ce délai s'applique quelle que soit la politique de la plateforme. Les demandes s'exercent au moyen des outils de gestion d'abonnement et d'historique d'achat de votre compte Google, ou en nous écrivant à donjons@grisloup.com.</li>",
    "en": "<li><strong>Refunds and withdrawal</strong> — all purchases and subscriptions are processed by the download platform. <strong>Article 49 of the Consumer Protection Code gives you a seven-day right of withdrawal</strong> from the purchase, without having to give reasons; that period applies whatever the platform's own policy provides. Requests are made through the subscription management and purchase history tools of your Google account, or by writing to donjons@grisloup.com.</li>",
    "es": "<li><strong>Reembolso y desistimiento</strong> — todas las compras y suscripciones las tramita la plataforma de descarga. <strong>El artículo 49 del Código de Defensa del Consumidor le reconoce un derecho de desistimiento de siete días</strong> desde la compra, sin necesidad de justificación; ese plazo se aplica cualquiera que sea la política de la plataforma. Las solicitudes se cursan mediante las herramientas de gestión de suscripciones y de historial de compras de su cuenta de Google, o escribiendo a donjons@grisloup.com.</li>",
    "it": "<li><strong>Rimborso e recesso</strong> — tutti gli acquisti e gli abbonamenti sono gestiti dalla piattaforma di download. <strong>L'articolo 49 del Codice di difesa del consumatore vi riconosce un diritto di recesso di sette giorni</strong> dall'acquisto, senza doverne indicare il motivo; tale termine si applica qualunque sia la politica della piattaforma. Le richieste si esercitano mediante gli strumenti di gestione dell'abbonamento e di cronologia degli acquisti del vostro account Google, oppure scrivendoci a donjons@grisloup.com.</li>",
    "de": "<li><strong>Erstattung und Widerruf</strong> — alle Käufe und Abonnements werden von der Download-Plattform abgewickelt. <strong>Artikel 49 des Verbraucherschutzgesetzbuchs gewährt Ihnen ein Widerrufsrecht von sieben Tagen</strong> ab dem Kauf, ohne Angabe von Gründen; diese Frist gilt unabhängig von der Politik der Plattform. Anträge erfolgen über die Werkzeuge zur Abonnementverwaltung und zum Kaufverlauf Ihres Google-Kontos oder durch eine Nachricht an donjons@grisloup.com.</li>",
    "pt": "<li><strong>Reembolso e direito de arrependimento</strong> — todas as compras e subscrições são tratadas pela plataforma de descarregamento. <strong>O artigo 49 do Código de Defesa do Consumidor reconhece-lhe um direito de arrependimento de sete dias</strong> a contar da compra, sem necessidade de justificação; esse prazo aplica-se qualquer que seja a política da plataforma. Os pedidos são feitos através das ferramentas de gestão de subscrições e de histórico de compras da sua conta Google, ou escrevendo-nos para donjons@grisloup.com.</li>",
    "nl": "<li><strong>Terugbetaling en herroeping</strong> — alle aankopen en abonnementen worden door het downloadplatform verwerkt. <strong>Artikel 49 van het Wetboek consumentenbescherming geeft u een herroepingsrecht van zeven dagen</strong> vanaf de aankoop, zonder opgave van redenen; die termijn geldt ongeacht het beleid van het platform. Verzoeken verlopen via de hulpmiddelen voor abonnementenbeheer en aankoopgeschiedenis van uw Google-account, of door ons te schrijven op donjons@grisloup.com.</li>",
}
_BR_HEBERGEMENT = {
    "fr": "avec stockage des données aux États-Unis. Vos données personnelles font donc l'objet d'un "
          "<strong>transfert international</strong> au sens des articles 33 à 36 de la LGPD, encadré par les "
          "clauses contractuelles types de l'ANPD.",
    "en": "with data stored in the United States. Your personal data is therefore subject to an "
          "<strong>international transfer</strong> within the meaning of Articles 33 to 36 of the LGPD, "
          "governed by the ANPD's standard contractual clauses.",
    "es": "con almacenamiento de los datos en los Estados Unidos. Sus datos personales son por tanto objeto de "
          "una <strong>transferencia internacional</strong> en el sentido de los artículos 33 a 36 de la LGPD, "
          "amparada en las cláusulas contractuales tipo de la ANPD.",
    "it": "con archiviazione dei dati negli Stati Uniti. I vostri dati personali sono quindi oggetto di un "
          "<strong>trasferimento internazionale</strong> ai sensi degli articoli da 33 a 36 della LGPD, "
          "disciplinato dalle clausole contrattuali tipo dell'ANPD.",
    "de": "mit Speicherung der Daten in den Vereinigten Staaten. Ihre personenbezogenen Daten sind somit "
          "Gegenstand einer <strong>internationalen Übermittlung</strong> im Sinne der Artikel 33 bis 36 der "
          "LGPD, geregelt durch die Standardvertragsklauseln der ANPD.",
    "pt": "com armazenamento dos dados nos Estados Unidos. Os seus dados pessoais são portanto objeto de uma "
          "<strong>transferência internacional</strong> na aceção dos artigos 33 a 36 da LGPD, enquadrada "
          "pelas cláusulas contratuais-padrão da ANPD.",
    "nl": "met opslag van de gegevens in de Verenigde Staten. Uw persoonsgegevens zijn dus voorwerp van een "
          "<strong>internationale doorgifte</strong> in de zin van de artikelen 33 tot en met 36 van de LGPD, "
          "beheerst door de modelcontractbepalingen van de ANPD.",
}
_BR_SEUILS = {
    "fr": "(seuils applicables au Brésil : 12 ans, âge en deçà duquel l'article 14 de la LGPD qualifie le joueur d'« enfant » et exige le consentement spécifique et mis en évidence de l'un des parents, et 18 ans, âge de la majorité)",
    "en": "(thresholds applicable in Brazil: 12, below which Article 14 of the LGPD treats the player as a \"child\" and requires the specific, prominent consent of one parent, and 18, the age of majority)",
    "es": "(umbrales aplicables en Brasil: 12 años, por debajo de los cuales el artículo 14 de la LGPD califica al jugador de «niño» y exige el consentimiento específico y destacado de uno de los progenitores, y 18 años, edad de la mayoría)",
    "it": "(soglie applicabili in Brasile: 12 anni, età al di sotto della quale l'articolo 14 della LGPD qualifica il giocatore come « bambino » ed esige il consenso specifico e messo in evidenza di uno dei genitori, e 18 anni, età della maggiore età)",
    "de": "(in Brasilien geltende Schwellen: 12, unterhalb derer Artikel 14 der LGPD den Spieler als „Kind“ behandelt und die spezifische, hervorgehobene Einwilligung eines Elternteils verlangt, und 18, das Alter der Volljährigkeit)",
    "pt": "(limiares aplicáveis no Brasil: 12 anos, abaixo dos quais o artigo 14 da LGPD qualifica o jogador de «criança» e exige o consentimento específico e destacado de um dos pais, e 18 anos, idade da maioridade)",
    "nl": "(in Brazilië geldende drempels: 12 jaar, waaronder artikel 14 van de LGPD de speler als « kind » aanmerkt en de specifieke, in het oog springende toestemming van één ouder vereist, en 18 jaar, de leeftijd van de meerderjarigheid)",
}
_BR_H2_CGU = {
    "fr": "<h2>6. Mineurs : consentement parental (article 14 de la LGPD)</h2>",
    "en": "<h2>6. Minors: parental consent (Article 14 of the LGPD)</h2>",
    "es": "<h2>6. Menores: consentimiento parental (artículo 14 de la LGPD)</h2>",
    "it": "<h2>6. Minori: consenso parentale (articolo 14 della LGPD)</h2>",
    "de": "<h2>6. Minderjährige: elterliche Einwilligung (Artikel 14 der LGPD)</h2>",
    "pt": "<h2>6. Menores: consentimento parental (artigo 14 da LGPD)</h2>",
    "nl": "<h2>6. Minderjarigen: ouderlijke toestemming (artikel 14 van de LGPD)</h2>",
}
_BR_CADRE = {
    "fr": "La collecte de données personnelles auprès d'un mineur est encadrée par l'<strong>article 14 de la Loi générale de protection des données (LGPD, loi 13.709/2018)</strong>, qui impose que tout traitement se fasse dans son intérêt supérieur et exige, en deçà de 12 ans, le consentement spécifique et mis en évidence de l'un des parents ou du responsable légal.",
    "en": "The collection of personal data from a minor is governed by <strong>Article 14 of the General Data Protection Law (LGPD, Law 13.709/2018)</strong>, which requires all processing to serve the minor's best interest and, below the age of 12, the specific and prominent consent of one parent or legal guardian.",
    "es": "La recogida de datos personales de un menor está regulada por el <strong>artículo 14 de la Ley General de Protección de Datos (LGPD, ley 13.709/2018)</strong>, que exige que todo tratamiento se realice en su interés superior y requiere, por debajo de los 12 años, el consentimiento específico y destacado de uno de los progenitores o del responsable legal.",
    "it": "La raccolta di dati personali presso un minore è disciplinata dall'<strong>articolo 14 della Legge generale di protezione dei dati (LGPD, legge 13.709/2018)</strong>, che impone che ogni trattamento avvenga nel suo interesse superiore ed esige, al di sotto dei 12 anni, il consenso specifico e messo in evidenza di uno dei genitori o del responsabile legale.",
    "de": "Die Erhebung personenbezogener Daten bei einer minderjährigen Person wird durch <strong>Artikel 14 des Allgemeinen Datenschutzgesetzes (LGPD, Gesetz 13.709/2018)</strong> geregelt, das verlangt, dass jede Verarbeitung dem Kindeswohl dient, und unterhalb von 12 Jahren die spezifische und hervorgehobene Einwilligung eines Elternteils oder gesetzlichen Vertreters fordert.",
    "pt": "A recolha de dados pessoais junto de um menor é regida pelo <strong>artigo 14 da Lei Geral de Proteção de Dados (LGPD, lei 13.709/2018)</strong>, que impõe que todo o tratamento se faça no seu melhor interesse e exige, abaixo dos 12 anos, o consentimento específico e destacado de um dos pais ou do responsável legal.",
    "nl": "Het verzamelen van persoonsgegevens bij een minderjarige wordt beheerst door <strong>artikel 14 van de Algemene wet gegevensbescherming (LGPD, wet 13.709/2018)</strong>, dat vereist dat elke verwerking het hoger belang van het kind dient en, onder de 12 jaar, de specifieke en in het oog springende toestemming van één van de ouders of de wettelijke vertegenwoordiger verlangt.",
}
_BR_LIMITATION = {
    "fr": "<strong>L'article 51 du Code de défense du consommateur frappe de nullité toute clause qui exonère ou limite la responsabilité du fournisseur envers un consommateur</strong> : les limitations ci-dessus ne lui sont pas opposables. Rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable.",
    "en": "<strong>Article 51 of the Consumer Protection Code renders void any clause that excludes or limits the supplier's liability towards a consumer</strong>: the limitations above cannot be relied on against them. Nothing excludes liability for gross negligence or personal injury attributable to the publisher.",
    "es": "<strong>El artículo 51 del Código de Defensa del Consumidor declara nula toda cláusula que exonere o limite la responsabilidad del proveedor frente a un consumidor</strong>: las limitaciones anteriores no le son oponibles. Nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable.",
    "it": "<strong>L'articolo 51 del Codice di difesa del consumatore dichiara nulla ogni clausola che esoneri o limiti la responsabilità del fornitore nei confronti di un consumatore</strong>: le limitazioni di cui sopra non gli sono opponibili. Nulla esclude la responsabilità dell'editore in caso di colpa grave o di danno alla persona a lui imputabile.",
    "de": "<strong>Artikel 51 des Verbraucherschutzgesetzbuchs erklärt jede Klausel für nichtig, die die Haftung des Anbieters gegenüber einem Verbraucher ausschließt oder beschränkt</strong>: die vorstehenden Beschränkungen können ihm nicht entgegengehalten werden. Nichts schließt die Haftung des Herausgebers bei grober Fahrlässigkeit oder ihm zurechenbaren Personenschäden aus.",
    "pt": "<strong>O artigo 51 do Código de Defesa do Consumidor declara nula toda a cláusula que exonere ou limite a responsabilidade do fornecedor perante um consumidor</strong>: as limitações acima não lhe são oponíveis. Nada exclui a responsabilidade do editor em caso de culpa grave ou de dano corporal que lhe seja imputável.",
    "nl": "<strong>Artikel 51 van het Wetboek consumentenbescherming verklaart elk beding nietig dat de aansprakelijkheid van de leverancier jegens een consument uitsluit of beperkt</strong>: de bovenstaande beperkingen kunnen hem niet worden tegengeworpen. Niets sluit de aansprakelijkheid van de uitgever uit bij grove schuld of bij hem toerekenbare lichamelijke schade.",
}
_BR_RESERVE = {
    "fr": "sans préjudice du <strong>Code de défense du consommateur</strong>, qui est d'ordre public et dont aucune stipulation des présentes ne peut vous priver. Son article 101 vous permet de porter le litige devant le tribunal de votre domicile, et l'article 11 du Marco Civil da Internet soumet au droit brésilien toute collecte de données opérée au Brésil.",
    "en": "without prejudice to the <strong>Consumer Protection Code</strong>, which is a matter of public policy and of which nothing in these terms can deprive you. Its Article 101 lets you bring the dispute before the court of your own domicile, and Article 11 of the Marco Civil da Internet subjects any data collection carried out in Brazil to Brazilian law.",
    "es": "sin perjuicio del <strong>Código de Defensa del Consumidor</strong>, que es de orden público y del que ninguna estipulación de las presentes puede privarle. Su artículo 101 le permite someter el litigio al tribunal de su domicilio, y el artículo 11 del Marco Civil da Internet sujeta al derecho brasileño toda recogida de datos realizada en Brasil.",
    "it": "fatto salvo il <strong>Codice di difesa del consumatore</strong>, che è di ordine pubblico e del quale nessuna stipulazione delle presenti può privarvi. Il suo articolo 101 vi consente di portare la controversia davanti al tribunale del vostro domicilio, e l'articolo 11 del Marco Civil da Internet sottopone al diritto brasiliano ogni raccolta di dati effettuata in Brasile.",
    "de": "unbeschadet des <strong>Verbraucherschutzgesetzbuchs</strong>, das zwingendes Recht ist und dessen Schutz Ihnen keine Bestimmung dieser Bedingungen entziehen kann. Sein Artikel 101 erlaubt Ihnen, den Streit vor das Gericht Ihres eigenen Wohnsitzes zu bringen, und Artikel 11 des Marco Civil da Internet unterstellt jede in Brasilien vorgenommene Datenerhebung dem brasilianischen Recht.",
    "pt": "sem prejuízo do <strong>Código de Defesa do Consumidor</strong>, que é de ordem pública e do qual nenhuma estipulação das presentes o pode privar. O seu artigo 101 permite-lhe submeter o litígio ao tribunal do seu domicílio, e o artigo 11 do Marco Civil da Internet sujeita ao direito brasileiro toda a recolha de dados realizada no Brasil.",
    "nl": "onverminderd het <strong>Wetboek consumentenbescherming</strong>, dat van openbare orde is en waarvan geen enkel beding uit deze voorwaarden u kan beroven. Artikel 101 ervan stelt u in staat het geschil voor de rechtbank van uw eigen woonplaats te brengen, en artikel 11 van de Marco Civil da Internet onderwerpt elke in Brazilië verrichte gegevensverzameling aan het Braziliaanse recht.",
}
_BR_ANPD_CGU = {
    "fr": ', notamment l\'Autorité nationale de protection des données (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) et les organismes de défense du consommateur (Procon).',
    "en": ', in particular the National Data Protection Authority (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) and the consumer protection bodies (Procon).',
    "es": ', en particular la Autoridad Nacional de Protección de Datos (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) y los organismos de defensa del consumidor (Procon).',
    "it": ', in particolare l\'Autorità nazionale di protezione dei dati (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) e gli organismi di difesa del consumatore (Procon).',
    "de": ', insbesondere der Nationalen Datenschutzbehörde (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) und den Verbraucherschutzstellen (Procon).',
    "pt": ', em particular a Autoridade Nacional de Proteção de Dados (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) e os organismos de defesa do consumidor (Procon).',
    "nl": ', in het bijzonder de Nationale Autoriteit Gegevensbescherming (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) en de consumentenbeschermingsinstanties (Procon).',
}
_BR_P1 = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des données personnelles de votre enfant au titre de l'article 14 de la LGPD ; elle tient lieu de canal de communication avec la personne concernée.",
    "en": "This is also the address to use to reach us about your child's personal data under Article 14 of the LGPD; it serves as the communication channel with the data subject.",
    "es": "Esta es también la dirección para contactarnos acerca de los datos personales de su hijo conforme al artículo 14 de la LGPD; sirve de canal de comunicación con el titular de los datos.",
    "it": "Questo è anche l'indirizzo da utilizzare per contattarci in merito ai dati personali di vostro figlio ai sensi dell'articolo 14 della LGPD; funge da canale di comunicazione con l'interessato.",
    "de": "Dies ist auch die Adresse, die Sie verwenden, um uns wegen der personenbezogenen Daten Ihres Kindes nach Artikel 14 der LGPD zu erreichen; sie dient als Kommunikationskanal mit der betroffenen Person.",
    "pt": "Este é também o endereço a utilizar para nos contactar acerca dos dados pessoais do seu filho ao abrigo do artigo 14 da LGPD; serve de canal de comunicação com o titular dos dados.",
    "nl": "Dit is ook het adres dat u gebruikt om ons te bereiken over de persoonsgegevens van uw kind op grond van artikel 14 van de LGPD; het dient als communicatiekanaal met de betrokkene.",
}
_BR_H2_P = {
    "fr": "<h2>4. Mineurs — article 14 de la LGPD</h2>",
    "en": "<h2>4. Minors — Article 14 of the LGPD</h2>",
    "es": "<h2>4. Menores — artículo 14 de la LGPD</h2>",
    "it": "<h2>4. Minori — articolo 14 della LGPD</h2>",
    "de": "<h2>4. Minderjährige — Artikel 14 der LGPD</h2>",
    "pt": "<h2>4. Menores — artigo 14 da LGPD</h2>",
    "nl": "<h2>4. Minderjarigen — artikel 14 van de LGPD</h2>",
}
_BR_SEUILS_P = {
    "fr": "Le seuil retenu par l'application est 18 ans ; l'article 14 de la LGPD exige en deçà de 12 ans le consentement spécifique et mis en évidence de l'un des parents.",
    "en": "The threshold used by the application is 18; below the age of 12, Article 14 of the LGPD requires the specific and prominent consent of one parent.",
    "es": "El umbral adoptado por la aplicación es 18 años; por debajo de los 12, el artículo 14 de la LGPD exige el consentimiento específico y destacado de uno de los progenitores.",
    "it": "La soglia adottata dall'applicazione è 18 anni; l'articolo 14 della LGPD esige al di sotto dei 12 anni il consenso specifico e messo in evidenza di uno dei genitori.",
    "de": "Die von der Anwendung verwendete Schwelle ist 18; unterhalb von 12 Jahren verlangt Artikel 14 der LGPD die spezifische und hervorgehobene Einwilligung eines Elternteils.",
    "pt": "O limiar adotado pela aplicação é 18 anos; abaixo dos 12, o artigo 14 da LGPD exige o consentimento específico e destacado de um dos pais.",
    "nl": "De door de applicatie gehanteerde drempel is 18 jaar; onder de 12 jaar vereist artikel 14 van de LGPD de specifieke en in het oog springende toestemming van één van de ouders.",
}
_BR_COPPA_P8 = {
    "fr": "exigé par l'article 14 de la LGPD",
    "en": "required by Article 14 of the LGPD",
    "es": "exigido por el artículo 14 de la LGPD",
    "it": "esigito dall'articolo 14 della LGPD",
    "de": "von Artikel 14 der LGPD geforderte",
    "pt": "exigido pelo artigo 14 da LGPD",
    "nl": "door artikel 14 van de LGPD vereiste",
}
_BR_ANPD_P = {
    "fr": 'Vous pouvez également saisir l\'<strong>Autorité nationale de protection des données</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) ou un organisme de défense du consommateur (Procon).',
    "en": 'You may also contact the <strong>National Data Protection Authority</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) or a consumer protection body (Procon).',
    "es": 'También puede dirigirse a la <strong>Autoridad Nacional de Protección de Datos</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) o a un organismo de defensa del consumidor (Procon).',
    "it": 'Potete anche rivolgervi all\'<strong>Autorità nazionale di protezione dei dati</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) o a un organismo di difesa del consumatore (Procon).',
    "de": 'Sie können sich auch an die <strong>Nationale Datenschutzbehörde</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) oder an eine Verbraucherschutzstelle (Procon) wenden.',
    "pt": 'Pode também dirigir-se à <strong>Autoridade Nacional de Proteção de Dados</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) ou a um organismo de defesa do consumidor (Procon).',
    "nl": 'U kunt ook contact opnemen met de <strong>Nationale Autoriteit Gegevensbescherming</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) of met een consumentenbeschermingsinstantie (Procon).',
}
_BR_CENTRES = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis, donc hors du Brésil — transfert international encadré par les articles 33 à 36 de la LGPD)",
    "en": "(for this region: data centres located in the United States, therefore outside Brazil — an international transfer governed by Articles 33 to 36 of the LGPD)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos, por tanto fuera de Brasil — transferencia internacional amparada en los artículos 33 a 36 de la LGPD)",
    "it": "(per la presente regione: centri di dati situati negli Stati Uniti, quindi fuori dal Brasile — trasferimento internazionale disciplinato dagli articoli da 33 a 36 della LGPD)",
    "de": "(für die vorliegende Region: Rechenzentren in den Vereinigten Staaten, also außerhalb Brasiliens — eine internationale Übermittlung nach den Artikeln 33 bis 36 der LGPD)",
    "pt": "(para a presente região: centros de dados situados nos Estados Unidos, portanto fora do Brasil — transferência internacional enquadrada pelos artigos 33 a 36 da LGPD)",
    "nl": "(voor deze regio: datacentra gelegen in de Verenigde Staten, dus buiten Brazilië — een internationale doorgifte beheerst door de artikelen 33 tot en met 36 van de LGPD)",
}
# ⚠ PAS DE `_us_etat_blocks` POUR LE BRÉSIL : la puce « Remboursement » est
#   entièrement réécrite (elle portait la mention « votre État »), et le §9 de la
#   politique se raccroche à la LGPD, qui est fédérale.
_BR_DROITS_SRC = {
    "fr": "Selon votre État de résidence, vous pouvez avoir le droit",
    "en": "Depending on your state of residence, you may have the right",
    "es": "Según su estado de residencia, puede tener derecho",
    "it": "A seconda del vostro Stato di residenza, potete avere il diritto",
    "de": "Je nach Ihrem Wohnsitzstaat können Sie das Recht haben",
    "pt": "Consoante o seu Estado de residência, pode ter o direito",
    "nl": "Afhankelijk van uw staat van verblijf kunt u het recht hebben",
}
_BR_DROITS = {
    "fr": "En vertu de l'article 18 de la LGPD, vous avez le droit",
    "en": "Under Article 18 of the LGPD, you have the right",
    "es": "En virtud del artículo 18 de la LGPD, usted tiene derecho",
    "it": "In virtù dell'articolo 18 della LGPD, avete il diritto",
    "de": "Nach Artikel 18 der LGPD haben Sie das Recht",
    "pt": "Nos termos do artigo 18 da LGPD, tem o direito",
    "nl": "Krachtens artikel 18 van de LGPD hebt u het recht",
}
# ⚠ NE PAS RECOPIER LA SOURCE À L'IDENTIQUE. La première version rendait « quel que
#   soit leur État de résidence » inchangé en français : la substitution trouvait
#   bien son occurrence et ne changeait rien, donc le contrôle passait au vert pour
#   une phrase restée américaine. Un remplacement égal à sa source est un bug muet.
_BR_ETENDU = {
    "fr": "où qu'ils résident au Brésil",
    "en": "wherever in Brazil you live",
    "es": "dondequiera que residan en Brasil",
    "it": "ovunque risiedano in Brasile",
    "de": "wo in Brasilien Sie auch leben",
    "pt": "onde quer que residam no Brasil",
    "nl": "waar in Brazilië u ook woont",
}


def _br_blocks(lang, doc):

    """Les ecarts bresiliens d'UN document adulte, derives du corpus americain."""
    if doc == "cgu":
        return [(_US_HEBERGEMENT_SRC[lang],   _BR_HEBERGEMENT[lang]),
                (_US_SEUILS_SRC[lang],        _BR_SEUILS[lang]),
                (_US_H2_CGU_SRC[lang],        _BR_H2_CGU[lang]),
                (_US_CADRE_SRC[lang],         _BR_CADRE[lang]),
                (_US_LIMITATION_SRC[lang],    _BR_LIMITATION[lang]),
                (_US_RESERVE_SRC[lang],       _BR_RESERVE[lang]),
                (_US_FTC_CGU_SRC[lang],       _BR_ANPD_CGU[lang]),
                (_US_REMBOURSEMENT_SRC[lang], _BR_REMBOURSEMENT[lang])]
    return [(_US_P1_SRC[lang],       _BR_P1[lang]),
            (_US_H2_P_SRC[lang],     _BR_H2_P[lang]),
            (_US_SEUILS_P_SRC[lang], _BR_SEUILS_P[lang]),
            (_US_COPPA_P8_SRC[lang], _BR_COPPA_P8[lang]),
            (_US_FTC_P_SRC[lang],    _BR_ANPD_P[lang]),
            (_US_CENTRES_SRC[lang],  _BR_CENTRES[lang]),
            (_BR_DROITS_SRC[lang],   _BR_DROITS[lang]),
            (_US_ETAT_SRC["privacy_b"][lang], _BR_ETENDU[lang])]


# =============================================================================
# AMÉRIQUE HISPANOPHONE — Mexique et Colombie, deux régimes, une seule langue
# =============================================================================
# ⚠ L'INAI N'EXISTE PLUS, et le build.yml dit encore de le nommer. La réforme
#   constitutionnelle mexicaine de décembre 2024 a supprimé l'Institut, et la
#   nouvelle LFPDPPP (DOF du 20 mars 2025) a transféré la protection des données
#   à la Secretaría Anticorrupción y Buen Gobierno. Nommer l'INAI dans une
#   politique de confidentialité enverrait le lecteur vers une autorité dissoute.
#   ⚠ CHANGEMENT INSTITUTIONNEL RÉCENT : à revérifier avant publication (item de
#     roadmap), c'est exactement le genre de fait qui bouge encore.
#
# ⚠ DEUX DROITS DE RÉTRACTATION, ET ILS NE SE RESSEMBLENT PAS. Le Mexique
#   (art. 56 LFPC) et la Colombie (art. 47 du Estatuto del Consumidor) ouvrent
#   tous deux CINQ JOURS OUVRABLES — mais la Colombie écarte le retracto lorsque
#   la fourniture du service a commencé avec l'accord du consommateur, ce que le
#   Mexique ne fait pas. La clause doit donc dire les deux.
#
# ⚠ LA COLOMBIE INTERDIT PAR PRINCIPE le traitement des données d'un mineur
#   (art. 7 de la loi 1581) et ne l'autorise que s'il respecte son intérêt
#   supérieur — qui doit être DÉMONTRÉ, note d'analyse à l'appui. Le build.yml le
#   signalait déjà ; c'est un livrable, pas une clause.
#
# ⚠ L'ESPAGNOL EST AU CORPUS DEPUIS TOUJOURS, et le portugais l'est depuis le
#   2026-09-08 : ce qui séparait `hispam` de `bresil` a disparu. Les deux marchés
#   sont désormais ouvrables côté langue, et ne se distinguent plus que par leur
#   droit.
_HI_HEBERGEMENT = {
    "fr": "avec stockage des données aux États-Unis. Vos données personnelles font donc l'objet d'un "
          "<strong>transfert international</strong> : il repose sur votre autorisation préalable, expresse et "
          "informée, exigée par l'article 26 de la loi colombienne 1581 de 2012, et sur le consentement "
          "recueilli au titre de la LFPDPPP mexicaine.",
    "en": "with data stored in the United States. Your personal data is therefore subject to an "
          "<strong>international transfer</strong>: it relies on your prior, express and informed "
          "authorisation, required by Article 26 of Colombian Law 1581 of 2012, and on the consent obtained "
          "under the Mexican LFPDPPP.",
    "es": "con almacenamiento de los datos en los Estados Unidos. Sus datos personales son por tanto objeto de "
          "una <strong>transferencia internacional</strong>: se ampara en su autorización previa, expresa e "
          "informada, exigida por el artículo 26 de la Ley 1581 de 2012 de Colombia, y en el consentimiento "
          "recabado conforme a la LFPDPPP mexicana.",
    "it": "con archiviazione dei dati negli Stati Uniti. I vostri dati personali sono quindi oggetto di un "
          "<strong>trasferimento internazionale</strong>: esso si fonda sulla vostra autorizzazione preventiva, "
          "espressa e informata, richiesta dall'articolo 26 della legge colombiana 1581 del 2012, e sul "
          "consenso raccolto ai sensi della LFPDPPP messicana.",
    "de": "mit Speicherung der Daten in den Vereinigten Staaten. Ihre personenbezogenen Daten sind somit "
          "Gegenstand einer <strong>internationalen Übermittlung</strong>: sie stützt sich auf Ihre vorherige, "
          "ausdrückliche und informierte Ermächtigung, die Artikel 26 des kolumbianischen Gesetzes 1581 von "
          "2012 verlangt, und auf die nach dem mexikanischen LFPDPPP eingeholte Einwilligung.",
    "pt": "com armazenamento dos dados nos Estados Unidos. Os seus dados pessoais são portanto objeto de uma "
          "<strong>transferência internacional</strong>: assenta na sua autorização prévia, expressa e "
          "informada, exigida pelo artigo 26 da Lei 1581 de 2012 da Colômbia, e no consentimento recolhido ao "
          "abrigo da LFPDPPP mexicana.",
    "nl": "met opslag van de gegevens in de Verenigde Staten. Uw persoonsgegevens zijn dus voorwerp van een "
          "<strong>internationale doorgifte</strong>: die berust op uw voorafgaande, uitdrukkelijke en "
          "geïnformeerde machtiging, vereist door artikel 26 van de Colombiaanse Wet 1581 van 2012, en op de "
          "krachtens de Mexicaanse LFPDPPP verkregen toestemming.",
}
_HI_SEUILS = {
    "fr": "(ni la LFPDPPP mexicaine ni la loi colombienne 1581 de 2012 ne fixent d'âge de consentement numérique : l'Application retient 18 ans et exige dans tous les cas l'autorisation du représentant légal du mineur)",
    "en": "(neither the Mexican LFPDPPP nor Colombian Law 1581 of 2012 sets a digital consent age: the Application uses 18 and always requires the authorisation of the minor's legal representative)",
    "es": "(ni la LFPDPPP mexicana ni la Ley 1581 de 2012 de Colombia fijan una edad de consentimiento digital: la Aplicación adopta los 18 años y exige en todo caso la autorización del representante legal del menor)",
    "it": "(né la LFPDPPP messicana né la legge colombiana 1581 del 2012 fissano un'età di consenso digitale: l'Applicazione adotta i 18 anni ed esige in ogni caso l'autorizzazione del rappresentante legale del minore)",
    "de": "(weder das mexikanische LFPDPPP noch das kolumbianische Gesetz 1581 von 2012 legt ein digitales Einwilligungsalter fest: die Anwendung verwendet 18 und verlangt in jedem Fall die Ermächtigung des gesetzlichen Vertreters der minderjährigen Person)",
    "pt": "(nem a LFPDPPP mexicana nem a Lei 1581 de 2012 da Colômbia fixam uma idade de consentimento digital: a Aplicação adota os 18 anos e exige em todo o caso a autorização do representante legal do menor)",
    "nl": "(noch de Mexicaanse LFPDPPP noch de Colombiaanse Wet 1581 van 2012 stelt een digitale toestemmingsleeftijd vast: de Applicatie hanteert 18 jaar en vereist in alle gevallen de machtiging van de wettelijke vertegenwoordiger van de minderjarige)",
}
_HI_H2_CGU = {
    "fr": "<h2>6. Mineurs : autorisation du représentant légal (LFPDPPP et loi 1581)</h2>",
    "en": "<h2>6. Minors: legal representative's authorisation (LFPDPPP and Law 1581)</h2>",
    "es": "<h2>6. Menores: autorización del representante legal (LFPDPPP y Ley 1581)</h2>",
    "it": "<h2>6. Minori: autorizzazione del rappresentante legale (LFPDPPP e legge 1581)</h2>",
    "de": "<h2>6. Minderjährige: Ermächtigung des gesetzlichen Vertreters (LFPDPPP und Gesetz 1581)</h2>",
    "pt": "<h2>6. Menores: autorização do representante legal (LFPDPPP e Lei 1581)</h2>",
    "nl": "<h2>6. Minderjarigen: machtiging van de wettelijke vertegenwoordiger (LFPDPPP en Wet 1581)</h2>",
}
_HI_CADRE = {
    "fr": "La collecte de données personnelles auprès d'un mineur est encadrée par la <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> au Mexique et par l'<strong>article 7 de la loi 1581 de 2012</strong> en Colombie, qui n'autorise le traitement des données d'un mineur que s'il respecte son intérêt supérieur et ses droits fondamentaux, sur autorisation de son représentant légal.",
    "en": "The collection of personal data from a minor is governed by the <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> in Mexico and by <strong>Article 7 of Law 1581 of 2012</strong> in Colombia, which permits processing a minor's data only where it respects their best interest and fundamental rights, and with their legal representative's authorisation.",
    "es": "La recogida de datos personales de un menor está regulada por la <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> en México y por el <strong>artículo 7 de la Ley 1581 de 2012</strong> en Colombia, que solo permite el tratamiento de los datos de un menor cuando respeta su interés superior y sus derechos fundamentales, con autorización de su representante legal.",
    "it": "La raccolta di dati personali presso un minore è disciplinata dalla <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> in Messico e dall'<strong>articolo 7 della legge 1581 del 2012</strong> in Colombia, che autorizza il trattamento dei dati di un minore solo se rispetta il suo interesse superiore e i suoi diritti fondamentali, su autorizzazione del suo rappresentante legale.",
    "de": "Die Erhebung personenbezogener Daten bei einer minderjährigen Person wird durch das <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> in Mexiko und durch <strong>Artikel 7 des Gesetzes 1581 von 2012</strong> in Kolumbien geregelt, der die Verarbeitung der Daten einer minderjährigen Person nur zulässt, wenn sie deren Kindeswohl und Grundrechte achtet, und mit Ermächtigung ihres gesetzlichen Vertreters.",
    "pt": "A recolha de dados pessoais junto de um menor é regida pela <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> no México e pelo <strong>artigo 7 da Lei 1581 de 2012</strong> na Colômbia, que só permite o tratamento dos dados de um menor quando respeita o seu melhor interesse e os seus direitos fundamentais, mediante autorização do seu representante legal.",
    "nl": "Het verzamelen van persoonsgegevens bij een minderjarige wordt beheerst door de <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> in Mexico en door <strong>artikel 7 van Wet 1581 van 2012</strong> in Colombia, dat de verwerking van de gegevens van een minderjarige alleen toestaat wanneer zij diens hoger belang en grondrechten eerbiedigt, en met machtiging van diens wettelijke vertegenwoordiger.",
}
_HI_REMBOURSEMENT = {
    "fr": "<li><strong>Remboursement et rétractation</strong> — tous les achats et abonnements sont traités par la plateforme de téléchargement. <strong>L'article 56 de la Ley Federal de Protección al Consumidor au Mexique et l'article 47 du Estatuto del Consumidor en Colombie ouvrent un droit de rétractation de cinq jours ouvrables</strong> ; en Colombie, ce droit ne joue pas lorsque la fourniture du service a commencé avec votre accord. Les demandes s'exercent au moyen des outils de gestion d'abonnement et d'historique d'achat de votre compte Google, ou en nous écrivant à donjons@grisloup.com.</li>",
    "en": "<li><strong>Refunds and withdrawal</strong> — all purchases and subscriptions are processed by the download platform. <strong>Article 56 of the Ley Federal de Protección al Consumidor in Mexico and Article 47 of the Estatuto del Consumidor in Colombia give you a five-business-day right of withdrawal</strong>; in Colombia that right does not apply once supply of the service has begun with your agreement. Requests are made through the subscription management and purchase history tools of your Google account, or by writing to donjons@grisloup.com.</li>",
    "es": "<li><strong>Reembolso y retracto</strong> — todas las compras y suscripciones las tramita la plataforma de descarga. <strong>El artículo 56 de la Ley Federal de Protección al Consumidor en México y el artículo 47 del Estatuto del Consumidor en Colombia le reconocen un derecho de retracto de cinco días hábiles</strong>; en Colombia ese derecho no procede cuando la prestación del servicio ha comenzado con su acuerdo. Las solicitudes se cursan mediante las herramientas de gestión de suscripciones y de historial de compras de su cuenta de Google, o escribiendo a donjons@grisloup.com.</li>",
    "it": "<li><strong>Rimborso e recesso</strong> — tutti gli acquisti e gli abbonamenti sono gestiti dalla piattaforma di download. <strong>L'articolo 56 della Ley Federal de Protección al Consumidor in Messico e l'articolo 47 del Estatuto del Consumidor in Colombia riconoscono un diritto di recesso di cinque giorni lavorativi</strong>; in Colombia, tale diritto non si applica quando la fornitura del servizio è iniziata con il vostro accordo. Le richieste si esercitano mediante gli strumenti di gestione dell'abbonamento e di cronologia degli acquisti del vostro account Google, oppure scrivendoci a donjons@grisloup.com.</li>",
    "de": "<li><strong>Erstattung und Widerruf</strong> — alle Käufe und Abonnements werden von der Download-Plattform abgewickelt. <strong>Artikel 56 des Ley Federal de Protección al Consumidor in Mexiko und Artikel 47 des Estatuto del Consumidor in Kolumbien gewähren ein Widerrufsrecht von fünf Werktagen</strong>; in Kolumbien gilt dieses Recht nicht, sobald die Erbringung der Leistung mit Ihrem Einverständnis begonnen hat. Anträge erfolgen über die Werkzeuge zur Abonnementverwaltung und zum Kaufverlauf Ihres Google-Kontos oder durch eine Nachricht an donjons@grisloup.com.</li>",
    "pt": "<li><strong>Reembolso e retratação</strong> — todas as compras e subscrições são tratadas pela plataforma de descarregamento. <strong>O artigo 56 da Ley Federal de Protección al Consumidor no México e o artigo 47 do Estatuto del Consumidor na Colômbia reconhecem um direito de retratação de cinco dias úteis</strong>; na Colômbia, esse direito não se aplica quando a prestação do serviço começou com o seu acordo. Os pedidos são feitos através das ferramentas de gestão de subscrições e de histórico de compras da sua conta Google, ou escrevendo-nos para donjons@grisloup.com.</li>",
    "nl": "<li><strong>Terugbetaling en herroeping</strong> — alle aankopen en abonnementen worden door het downloadplatform verwerkt. <strong>Artikel 56 van de Ley Federal de Protección al Consumidor in Mexico en artikel 47 van het Estatuto del Consumidor in Colombia kennen een herroepingsrecht van vijf werkdagen toe</strong>; in Colombia geldt dat recht niet zodra de dienstverlening met uw instemming is begonnen. Verzoeken verlopen via de hulpmiddelen voor abonnementenbeheer en aankoopgeschiedenis van uw Google-account, of door ons te schrijven op donjons@grisloup.com.</li>",
}
_HI_LIMITATION = {
    "fr": "<strong>Les droits que la Ley Federal de Protección al Consumidor et le Estatuto del Consumidor reconnaissent au consommateur ne peuvent pas être écartés par contrat</strong> : les limitations ci-dessus ne s'appliquent que dans la mesure qu'ils permettent. Rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable.",
    "en": "<strong>The rights conferred on consumers by the Ley Federal de Protección al Consumidor and the Estatuto del Consumidor cannot be contracted out of</strong>: the limitations above apply only to the extent those Acts permit. Nothing excludes liability for gross negligence or personal injury attributable to the publisher.",
    "es": "<strong>Los derechos que la Ley Federal de Protección al Consumidor y el Estatuto del Consumidor reconocen al consumidor no pueden excluirse por contrato</strong>: las limitaciones anteriores solo se aplican en la medida en que dichas leyes lo permitan. Nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable.",
    "it": "<strong>I diritti che la Ley Federal de Protección al Consumidor e il Estatuto del Consumidor riconoscono al consumatore non possono essere esclusi per contratto</strong>: le limitazioni di cui sopra si applicano soltanto nella misura in cui tali leggi lo consentono. Nulla esclude la responsabilità dell'editore in caso di colpa grave o di danno alla persona a lui imputabile.",
    "de": "<strong>Die Rechte, die das Ley Federal de Protección al Consumidor und das Estatuto del Consumidor dem Verbraucher gewähren, können vertraglich nicht abbedungen werden</strong>: die vorstehenden Beschränkungen gelten nur, soweit diese Gesetze es zulassen. Nichts schließt die Haftung des Herausgebers bei grober Fahrlässigkeit oder ihm zurechenbaren Personenschäden aus.",
    "pt": "<strong>Os direitos que a Ley Federal de Protección al Consumidor e o Estatuto del Consumidor reconhecem ao consumidor não podem ser afastados por contrato</strong>: as limitações acima só se aplicam na medida em que essas leis o permitam. Nada exclui a responsabilidade do editor em caso de culpa grave ou de dano corporal que lhe seja imputável.",
    "nl": "<strong>De rechten die de Ley Federal de Protección al Consumidor en het Estatuto del Consumidor aan de consument toekennen, kunnen niet contractueel worden uitgesloten</strong>: de bovenstaande beperkingen gelden alleen voor zover die wetten dat toestaan. Niets sluit de aansprakelijkheid van de uitgever uit bij grove schuld of bij hem toerekenbare lichamelijke schade.",
}
_HI_RESERVE = {
    "fr": "sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre <strong>pays de résidence</strong> — la Ley Federal de Protección al Consumidor au Mexique, le Estatuto del Consumidor (loi 1480 de 2011) en Colombie —, que les présentes conditions n'excluent ni ne limitent.",
    "en": "without prejudice to the mandatory consumer-protection provisions applicable in your <strong>country of residence</strong> — the Ley Federal de Protección al Consumidor in Mexico, the Estatuto del Consumidor (Law 1480 of 2011) in Colombia — which these terms neither exclude nor limit.",
    "es": "sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su <strong>país de residencia</strong> — la Ley Federal de Protección al Consumidor en México, el Estatuto del Consumidor (Ley 1480 de 2011) en Colombia —, que las presentes condiciones no excluyen ni limitan.",
    "it": "fatte salve le disposizioni imperative di protezione dei consumatori applicabili nel vostro <strong>paese di residenza</strong> — la Ley Federal de Protección al Consumidor in Messico, il Estatuto del Consumidor (legge 1480 del 2011) in Colombia —, che le presenti condizioni non escludono né limitano.",
    "de": "unbeschadet der zwingenden Verbraucherschutzbestimmungen, die in Ihrem <strong>Wohnsitzland</strong> anwendbar sind — das Ley Federal de Protección al Consumidor in Mexiko, das Estatuto del Consumidor (Gesetz 1480 von 2011) in Kolumbien —, und die diese Bedingungen weder ausschließen noch beschränken.",
    "pt": "sem prejuízo das disposições imperativas de proteção dos consumidores aplicáveis no seu <strong>país de residência</strong> — a Ley Federal de Protección al Consumidor no México, o Estatuto del Consumidor (Lei 1480 de 2011) na Colômbia —, que as presentes condições não excluem nem limitam.",
    "nl": "onverminderd de dwingende bepalingen inzake consumentenbescherming die van toepassing zijn in uw <strong>land van verblijf</strong> — de Ley Federal de Protección al Consumidor in Mexico, het Estatuto del Consumidor (Wet 1480 van 2011) in Colombia —, die deze voorwaarden noch uitsluiten noch beperken.",
}
_HI_AUTORITES_CGU = {
    "fr": ', notamment la Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) au Mexique et la Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) en Colombie.',
    "en": ', in particular the Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) in Mexico and the Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) in Colombia.',
    "es": ', en particular la Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) en México y la Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) en Colombia.',
    "it": ', in particolare la Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) in Messico e la Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) in Colombia.',
    "de": ', insbesondere der Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) in Mexiko und der Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) in Kolumbien.',
    "pt": ', em particular a Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) no México e a Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) na Colômbia.',
    "nl": ', in het bijzonder de Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) in Mexico en de Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) in Colombia.',
}
_HI_P1 = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des données personnelles de votre enfant, pour exercer vos droits ARCO au Mexique ou vos droits au titre de la loi 1581 en Colombie. La présente politique vaut <strong>aviso de privacidad</strong> au sens de la LFPDPPP.",
    "en": "This is also the address to use to reach us about your child's personal data, and to exercise your ARCO rights in Mexico or your rights under Law 1581 in Colombia. This policy serves as the <strong>aviso de privacidad</strong> required by the LFPDPPP.",
    "es": "Esta es también la dirección para contactarnos acerca de los datos personales de su hijo, y para ejercer sus derechos ARCO en México o sus derechos conforme a la Ley 1581 en Colombia. La presente política constituye el <strong>aviso de privacidad</strong> exigido por la LFPDPPP.",
    "it": "Questo è anche l'indirizzo da utilizzare per contattarci in merito ai dati personali di vostro figlio, per esercitare i vostri diritti ARCO in Messico o i vostri diritti ai sensi della legge 1581 in Colombia. La presente informativa vale <strong>aviso de privacidad</strong> ai sensi della LFPDPPP.",
    "de": "Dies ist auch die Adresse, die Sie verwenden, um uns wegen der personenbezogenen Daten Ihres Kindes zu erreichen und um Ihre ARCO-Rechte in Mexiko oder Ihre Rechte nach dem Gesetz 1581 in Kolumbien auszuüben. Diese Erklärung gilt als <strong>aviso de privacidad</strong> im Sinne des LFPDPPP.",
    "pt": "Este é também o endereço a utilizar para nos contactar acerca dos dados pessoais do seu filho, e para exercer os seus direitos ARCO no México ou os seus direitos ao abrigo da Lei 1581 na Colômbia. A presente política vale como <strong>aviso de privacidad</strong> exigido pela LFPDPPP.",
    "nl": "Dit is ook het adres dat u gebruikt om ons te bereiken over de persoonsgegevens van uw kind, en om uw ARCO-rechten in Mexico of uw rechten krachtens Wet 1581 in Colombia uit te oefenen. Dit beleid geldt als <strong>aviso de privacidad</strong> vereist door de LFPDPPP.",
}
_HI_H2_P = {
    "fr": "<h2>4. Mineurs — LFPDPPP (Mexique) et loi 1581 de 2012 (Colombie)</h2>",
    "en": "<h2>4. Minors — LFPDPPP (Mexico) and Law 1581 of 2012 (Colombia)</h2>",
    "es": "<h2>4. Menores — LFPDPPP (México) y Ley 1581 de 2012 (Colombia)</h2>",
    "it": "<h2>4. Minori — LFPDPPP (Messico) e legge 1581 del 2012 (Colombia)</h2>",
    "de": "<h2>4. Minderjährige — LFPDPPP (Mexiko) und Gesetz 1581 von 2012 (Kolumbien)</h2>",
    "pt": "<h2>4. Menores — LFPDPPP (México) e Lei 1581 de 2012 (Colômbia)</h2>",
    "nl": "<h2>4. Minderjarigen — LFPDPPP (Mexico) en Wet 1581 van 2012 (Colombia)</h2>",
}
_HI_SEUILS_P = {
    "fr": "Le seuil retenu par l'application est 18 ans ; le traitement des données d'un mineur suppose l'autorisation de son représentant légal et, en Colombie, le respect démontré de son intérêt supérieur.",
    "en": "The threshold used by the application is 18; processing a minor's data requires their legal representative's authorisation and, in Colombia, a demonstrated respect for their best interest.",
    "es": "El umbral adoptado por la aplicación es 18 años; el tratamiento de los datos de un menor exige la autorización de su representante legal y, en Colombia, el respeto demostrado de su interés superior.",
    "it": "La soglia adottata dall'applicazione è 18 anni; il trattamento dei dati di un minore presuppone l'autorizzazione del suo rappresentante legale e, in Colombia, il rispetto dimostrato del suo interesse superiore.",
    "de": "Die von der Anwendung verwendete Schwelle ist 18; die Verarbeitung der Daten einer minderjährigen Person setzt die Ermächtigung ihres gesetzlichen Vertreters voraus und, in Kolumbien, den nachgewiesenen Respekt ihres Kindeswohls.",
    "pt": "O limiar adotado pela aplicação é 18 anos; o tratamento dos dados de um menor pressupõe a autorização do seu representante legal e, na Colômbia, o respeito demonstrado do seu melhor interesse.",
    "nl": "De door de applicatie gehanteerde drempel is 18 jaar; de verwerking van de gegevens van een minderjarige veronderstelt de machtiging van diens wettelijke vertegenwoordiger en, in Colombia, het aangetoonde respect voor diens hoger belang.",
}
_HI_COPPA_P8 = {
    "fr": "exigé du représentant légal",
    "en": "required from the legal representative",
    "es": "exigido al representante legal",
    "it": "esigito al rappresentante legale",
    "de": "vom gesetzlichen Vertreter geforderte",
    "pt": "exigido ao representante legal",
    "nl": "van de wettelijke vertegenwoordiger vereiste",
}
_HI_AUTORITES_P = {
    "fr": 'Vous pouvez également saisir l\'autorité mexicaine de protection des données personnelles — la <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, qui a succédé à l\'INAI — ou, en Colombie, la <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
    "en": 'You may also contact the Mexican personal data protection authority — the <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, which succeeded INAI — or, in Colombia, the <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
    "es": 'También puede dirigirse a la autoridad mexicana de protección de datos personales — la <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, que sucedió al INAI — o, en Colombia, a la <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
    "it": 'Potete anche rivolgervi all\'autorità messicana di protezione dei dati personali — la <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, che è succeduta all\'INAI — oppure, in Colombia, alla <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
    "de": 'Sie können sich auch an die mexikanische Datenschutzbehörde wenden — die <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, die auf INAI folgte — oder, in Kolumbien, an die <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
    "pt": 'Pode também dirigir-se à autoridade mexicana de proteção de dados pessoais — a <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, que sucedeu ao INAI — ou, na Colômbia, à <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
    "nl": 'U kunt ook contact opnemen met de Mexicaanse autoriteit voor de bescherming van persoonsgegevens — de <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, die INAI heeft opgevolgd — of, in Colombia, met de <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
}
_HI_CENTRES = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis, donc hors du Mexique et de la Colombie — transfert international soumis à votre autorisation préalable au sens de l'article 26 de la loi 1581)",
    "en": "(for this region: data centres located in the United States, therefore outside Mexico and Colombia — an international transfer subject to your prior authorisation under Article 26 of Law 1581)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos, por tanto fuera de México y Colombia — transferencia internacional sujeta a su autorización previa conforme al artículo 26 de la Ley 1581)",
    "it": "(per la presente regione: centri di dati situati negli Stati Uniti, quindi fuori dal Messico e dalla Colombia — trasferimento internazionale soggetto alla vostra autorizzazione preventiva ai sensi dell'articolo 26 della legge 1581)",
    "de": "(für die vorliegende Region: Rechenzentren in den Vereinigten Staaten, also außerhalb Mexikos und Kolumbiens — eine internationale Übermittlung, die nach Artikel 26 des Gesetzes 1581 Ihrer vorherigen Ermächtigung bedarf)",
    "pt": "(para a presente região: centros de dados situados nos Estados Unidos, portanto fora do México e da Colômbia — transferência internacional sujeita à sua autorização prévia nos termos do artigo 26 da Lei 1581)",
    "nl": "(voor deze regio: datacentra gelegen in de Verenigde Staten, dus buiten Mexico en Colombia — een internationale doorgifte die krachtens artikel 26 van Wet 1581 uw voorafgaande machtiging vereist)",
}
_HI_DROITS = {
    "fr": "Au titre de vos droits ARCO au Mexique — accès, rectification, annulation, opposition — et de l'article 8 de la loi 1581 en Colombie, vous avez le droit",
    "en": "Under your ARCO rights in Mexico — access, rectification, cancellation, objection — and Article 8 of Law 1581 in Colombia, you have the right",
    "es": "En virtud de sus derechos ARCO en México — acceso, rectificación, cancelación, oposición — y del artículo 8 de la Ley 1581 en Colombia, usted tiene derecho",
    "it": "In virtù dei vostri diritti ARCO in Messico — accesso, rettifica, cancellazione, opposizione — e dell'articolo 8 della legge 1581 in Colombia, avete il diritto",
    "de": "Nach Ihren ARCO-Rechten in Mexiko — Zugang, Berichtigung, Löschung, Widerspruch — und Artikel 8 des Gesetzes 1581 in Kolumbien haben Sie das Recht",
    "pt": "Ao abrigo dos seus direitos ARCO no México — acesso, retificação, cancelamento, oposição — e do artigo 8 da Lei 1581 na Colômbia, tem o direito",
    "nl": "Krachtens uw ARCO-rechten in Mexico — inzage, rectificatie, verwijdering, bezwaar — en artikel 8 van Wet 1581 in Colombia hebt u het recht",
}
_HI_ETENDU = {
    "fr": "qu'ils résident au Mexique ou en Colombie",
    "en": "whether you live in Mexico or Colombia",
    "es": "residan en México o en Colombia",
    "it": "che risiedano in Messico o in Colombia",
    "de": "ob Sie in Mexiko oder in Kolumbien leben",
    "pt": "residam no México ou na Colômbia",
    "nl": "of u nu in Mexico of in Colombia woont",
}


def _hi_blocks(lang, doc):

    """Les ecarts hispano-americains d'UN document adulte, derives du corpus americain."""
    if doc == "cgu":
        return [(_US_HEBERGEMENT_SRC[lang],   _HI_HEBERGEMENT[lang]),
                (_US_SEUILS_SRC[lang],        _HI_SEUILS[lang]),
                (_US_H2_CGU_SRC[lang],        _HI_H2_CGU[lang]),
                (_US_CADRE_SRC[lang],         _HI_CADRE[lang]),
                (_US_LIMITATION_SRC[lang],    _HI_LIMITATION[lang]),
                (_US_RESERVE_SRC[lang],       _HI_RESERVE[lang]),
                (_US_FTC_CGU_SRC[lang],       _HI_AUTORITES_CGU[lang]),
                (_US_REMBOURSEMENT_SRC[lang], _HI_REMBOURSEMENT[lang])]
    return [(_US_P1_SRC[lang],       _HI_P1[lang]),
            (_US_H2_P_SRC[lang],     _HI_H2_P[lang]),
            (_US_SEUILS_P_SRC[lang], _HI_SEUILS_P[lang]),
            (_US_COPPA_P8_SRC[lang], _HI_COPPA_P8[lang]),
            (_US_FTC_P_SRC[lang],    _HI_AUTORITES_P[lang]),
            (_US_CENTRES_SRC[lang],  _HI_CENTRES[lang]),
            (_US_ETAT_SRC["privacy_a"][lang], _HI_DROITS[lang]),
            (_US_ETAT_SRC["privacy_b"][lang], _HI_ETENDU[lang])]


def _market_blocks(market, lang, state, doc):

    """Les couples (source, remplacement) propres a un marche, pour UN document."""
    if state != "a":
        return []                       # les documents enfants ne portent rien de regional
    if market == "uk":
        return _uk_blocks(lang, doc)    # droit propre, pas une variante du droit de l'Union
    if market == "ch":
        return _ch_blocks(lang, doc)    # droit distinct, et l'election de droit y est exclue
    if market == "ca":
        return _ca_blocks(lang, doc)    # derive du corpus americain : meme datacenter, meme bucket
    if market == "oceanie":
        return _oc_blocks(lang, doc)    # deux pays, deux lois, et des garanties inecartables
    if market == "bresil":
        return _br_blocks(lang, doc)    # CDC d'ordre public, et un vrai droit de retractation
    if market == "hispam":
        return _hi_blocks(lang, doc)    # MX + CO : deux droits, une langue
    out = []

    if doc == "privacy":
        out.append((_AUTORITE_SRC[lang],
                    f"{_AUTORITES[market][lang]} {_EDPB[lang]}"))

    # Article 8 : la parenthese devient la fourchette REELLE du marche. Pour `eun`
    # l'incise EEE est posee DANS LA MEME substitution, et non dans une seconde :
    # « chaque Etat membre » se retrouverait sinon a chercher une occurrence unique
    # dans un texte que la premiere substitution vient de reecrire, et la phrase
    # dirait « chaque Etat membre » avant de citer la Norvege, qui n'en est pas un.
    src = _ART8_SRC[(doc, lang)]
    dst = src.replace(_ART8_PAREN[lang], _ART8_AGES[market][lang])
    if dst == src:
        raise SystemExit(f"_ART8_PAREN[{lang}] introuvable dans _ART8_SRC[{doc},{lang}].")
    if market == "eun":
        dst = dst.replace(_EEE_SRC[lang], _EEE_INCISE[lang], 1)
    out.append((src, dst))

    # `eun` seul : la reserve doit viser l'EEE (CGU), et le stockage doit dire
    # qu'un Norvegien ne subit aucun transfert hors EEE (politique).
    if market == "eun":
        out.append((_LOI_SRC[lang], _LOI_EEE[lang]) if doc == "cgu"
                   else (_EEE_STOCKAGE_SRC[lang], _EEE_STOCKAGE[lang]))
    return out


def _set_market_blocks(text, market, lang, state, doc, name):

    """Applique les ecarts de fond du marche, dans l'ORDRE de la liste.

    Une entree vaut (source, remplacement), (source, remplacement, compte) ou
    (source, remplacement, compte, brut).

    ⚠ LE COMPTE EST PRESQUE TOUJOURS 1, et doit le rester. Il n'existe que pour le
      cas ou un TERME — et non une phrase — se remplace partout : `uk` reecrit six
      fois « RGPD » en « UK GDPR » dans sa politique. Poser le compte attendu garde
      la garantie : six occurrences ou echec, jamais « autant qu'il y en a ».

    ⚠ L'ORDRE COMPTE. Les phrases se substituent AVANT les termes, sinon la phrase
      ne se reconnait plus dans un texte que le terme vient de reecrire.

    `brut` dit que la source est deja une expression reguliere. Il ne sert qu'a
    l'anglais : « UK GDPR » contient « GDPR », donc un remplacement naif se
    mordrait la queue et produirait « UK UK GDPR ».
    """
    for entry in _market_blocks(market, lang, state, doc):
        source, replacement = entry[0], entry[1]
        expected = entry[2] if len(entry) > 2 else 1
        brut     = entry[3] if len(entry) > 3 else False
        pattern  = source if brut else _as_pattern(source)
        text, n = re.subn(pattern, replacement.replace("\\", "\\\\"), text)
        if n != expected:
            raise SystemExit(
                f"[{name}] bloc marche « {source[:55]}… » : "
                f"{n} occurrence(s), {expected} attendue(s)."
            )
    return text


# Le corpus AMÉRICAIN nomme sa région autrement que l'européen — « (ici : … ) »
# plutôt que « (aujourd'hui : … ) », « Ici, c'est … » plutôt que « Pour l'instant,
# c'est … », et il porte au §1 de la politique une mention que l'européen n'a pas.
# D'où une seconde table : `_set_region_body` choisit selon le marché SOURCE.
BODY_REGION_US = {
    ("a", "cgu"): {
        "fr": [(r"sont\s+celles\s+de\s+la\s+région\s+{src}", "sont celles de la région {dst}")],
        "en": [(r"are\s+those\s+of\s+the\s+{src}\s+region",  "are those of the {dst} region")],
        "es": [(r"son\s+las\s+de\s+la\s+región\s+{src}",     "son las de la región {dst}")],
        "it": [(r"sono\s+quelle\s+della\s+regione\s+{src}",  "sono quelle della regione {dst}")],
        "de": [(r"sind\s+die\s+der\s+Region\s+{src}",        "sind die der Region {dst}")],
        "pt": [(r"são\s+as\s+da\s+região\s+{src}",           "são as da região {dst}")],
        "nl": [(r"zijn\s+die\s+van\s+de\s+regio\s+{src}",   "zijn die van de regio {dst}")],
    },
    ("a", "privacy"): {
        "fr": [(r"<strong>région\s+{src}</strong>",          "<strong>région {dst}</strong>"),
               (r"\(ici\s*:\s*{src}\)",                      "(ici : {dst})"),
               (r"politique\s+est\s+celle\s+de\s+la\s+région\s+{src}",
                "politique est celle de la région {dst}")],
        "en": [(r"<strong>{src}\s+region</strong>",          "<strong>{dst} region</strong>"),
               (r"\(here:\s*{src}\)",                        "(here: {dst})"),
               (r"policy\s+is\s+the\s+one\s+for\s+the\s+{src}\s+region",
                "policy is the one for the {dst} region")],
        "es": [(r"<strong>región\s+{src}</strong>",          "<strong>región {dst}</strong>"),
               (r"\(aquí:\s*{src}\)",                        "(aquí: {dst})"),
               (r"política\s+es\s+la\s+de\s+la\s+región\s+{src}",
                "política es la de la región {dst}")],
        "it": [(r"<strong>regione\s+{src}</strong>",         "<strong>regione {dst}</strong>"),
               (r"\(qui:\s*{src}\)",                         "(qui: {dst})"),
               (r"informativa\s+è\s+quella\s+della\s+regione\s+{src}",
                "informativa è quella della regione {dst}")],
        "de": [(r"<strong>Region\s+{src}</strong>",          "<strong>Region {dst}</strong>"),
               (r"\(hier:\s*{src}\)",                        "(hier: {dst})"),
               (r"Erklärung\s+ist\s+die\s+für\s+die\s+Region\s+{src}",
                "Erklärung ist die für die Region {dst}")],
        "pt": [(r"<strong>região\s+{src}</strong>",          "<strong>região {dst}</strong>"),
               (r"\(aqui:\s*{src}\)",                        "(aqui: {dst})"),
               (r"política\s+é\s+a\s+da\s+região\s+{src}",
                "política é a da região {dst}")],
        "nl": [(r"<strong>regio\s+{src}</strong>",           "<strong>regio {dst}</strong>"),
               (r"\(hier:\s*{src}\)",                        "(hier: {dst})"),
               (r"privacybeleid\s+is\s+dat\s+van\s+de\s+regio\s+{src}",
                "privacybeleid is dat van de regio {dst}")],
    },
    # ⚠ L'ESPAGNOL CHANGE DE VERBE : « Aquí son los Estados Unidos » devient « Aquí
    #   es Canadá ». Le remplacement porte donc la phrase entière, accord compris.
    ("k", "cgu"): {
        "fr": [(r"Ici,\s+c'est\s+{src_a}\.",  "Ici, c'est {dst_a}.")],
        "en": [(r"Here\s+it\s+is\s+{src_a}\.", "Here it is {dst_a}.")],
        "es": [(r"Aquí\s+son\s+{src_a}\.",    "Aquí es {dst_a}.")],
        "it": [(r"Qui\s+sono\s+{src_a}\.",    "Qui è {dst_a}.")],
        "de": [(r"Hier\s+sind\s+es\s+{src_a}\.", "Hier ist es {dst_a}.")],
        "pt": [(r"Aqui\s+são\s+{src_a}\.",    "Aqui é {dst_a}.")],
        "nl": [(r"Hier\s+zijn\s+dat\s+{src_a}\.", "Hier is dat {dst_a}.")],
    },
}
BODY_REGION_US[("k", "privacy")] = BODY_REGION_US[("k", "cgu")]


def _as_pattern(label):
    """Libellé littéral -> motif tolérant le retour à la ligne du source HTML.

    Les documents sont enregistrés avec des lignes courtes : « la région\nFrance »
    est le cas normal, pas l'exception. Un motif qui exigerait l'espace simple
    échouerait sur un document mis en forme différemment — donc sur le prochain.
    """
    return r"\s+".join(re.escape(w) for w in label.split())


def _set_region_body(text, lang, state, doc, src_market, dst_market, name):
    """Réécrit les mentions du marché DANS LE CORPS du texte.

    ⚠ NE TOUCHE PAS AUX MENTIONS DU DATACENTER, et c'est toute la difficulté.
      « stockage des données dans l'Union Européenne » (CGU §1), « infrastructure
      située dans l'Union Européenne » (§7) et « votre pays de résidence au sein
      de l'Union Européenne » (§12) parlent d'hébergement ou de droit applicable :
      ils restent vrais quel que soit le marché, et les réécrire produirait un
      contresens. Seules les phrases listées dans BODY_REGION sont visées, une par
      une — jamais un remplacement global du libellé.
    """
    table = BODY_REGION_US if src_market == "us" else BODY_REGION
    entries = table.get((state, doc), {}).get(lang, [])
    subs = {
        "src":   _as_pattern(REGION_LABEL[src_market][lang]),
        "dst":   REGION_LABEL[dst_market][lang],
        "src_a": _as_pattern(_articled(src_market, lang)),
        "dst_a": _articled(dst_market, lang),
    }
    for raw_pattern, raw_replacement in entries:
        pattern = raw_pattern.format(**subs)
        replacement = raw_replacement.format(**subs)
        text, n = re.subn(pattern, replacement, text)
        if n != 1:
            raise SystemExit(
                f"[{name}] corps, motif « {pattern[:60]}… » : {n} occurrence(s), 1 attendue."
            )
    return text


def _set_version(text, lang, state, name):
    """Repose le numéro de version à 1 et la date d'entrée en vigueur."""
    tag = VERSION_TAG[lang]
    date = DATE_ADULT[lang] if state == "a" else DATE_KID[lang]
    pattern = re.compile(re.escape(f"<strong>{tag}</strong>") + r"[^<\n]*")
    text, n = pattern.subn(f"<strong>{tag}</strong> 1 — {date}", text)
    if n != 1:
        raise SystemExit(f"[{name}] en-tête « {tag} » : {n} occurrence(s), 1 attendue.")
    return text


def _retarget_links(text, src_market, dst_market, name):
    """Réécrit les URLs internes vers le corpus du marché cible, en v1.

    ⚠ TOUT LE CORPUS CIBLE ÉTANT EN v1, cette réécriture répare au passage les
      liens que le marché source pointait vers une version périmée — les CGU
      européennes renvoyaient encore à `privacy-v3` alors que la v4 existait.
      C'est un effet de bord, mais un effet de bord voulu : un document légal
      qui renvoie à une version qui n'est plus en vigueur induit en erreur.

    Le bucket n'est PAS réécrit : deux marchés servis par le même datacenter
    partagent leur bucket, et c'est le cas de `fr` et `euo`.
    """
    # ⚠ MEME CLASSE DE CARACTERES QUE `pucore/docnames` (framework), underscore
    #   compris dans le NOM DU DOCUMENT. Ce motif etait plus strict : un document
    #   appele `parental_consent` n'aurait pas ete reconnu comme un lien interne,
    #   donc pas reecrit — et le corpus derive aurait garde un lien vers le marche
    #   SOURCE, en silence. Le controle `leftover` ci-dessous ne l'aurait pas vu
    #   non plus, puisqu'il cherche avec le meme motif.
    pattern = re.compile(
        re.escape(src_market) + r"-([ak])-([a-z]{2,3})-([a-z0-9_]+)-v\d+\.html"
    )
    text, n = pattern.subn(
        lambda m: f"{dst_market}-{m.group(1)}-{m.group(2)}-{m.group(3)}-v1.html", text
    )
    # Contrôle restreint au MOTIF DE NOM DE DOCUMENT, pas à la simple présence de
    # la chaîne : le bucket s'appelle `dvddust-eu-documents-storage` et contient
    # donc « eu- » sans qu'aucun document n'y soit nommé.
    leftover = pattern.findall(text)
    if leftover:
        raise SystemExit(f"[{name}] référence au marché source subsistante : {leftover}")
    return text, n


def main():
    check = "--check" in sys.argv
    written, skipped = [], []

    for src_market, dst_market in DERIVATIONS:
        if dst_market not in REGION_LABEL:
            raise SystemExit(f"marché cible '{dst_market}' sans libellé : compléter REGION_LABEL.")

        for state in STATES:
            for lang in LANGS:
                for doc in DOC_TYPES:
                    src_v = _latest_version(src_market, state, lang, doc)
                    if src_v is None:
                        raise SystemExit(
                            f"source absente : {src_market}-{state}-{lang}-{doc}-v*.html"
                        )
                    src = DOCS / f"{src_market}-{state}-{lang}-{doc}-v{src_v}.html"
                    dst = DOCS / f"{dst_market}-{state}-{lang}-{doc}-v1.html"

                    # On n'écrase JAMAIS un document déjà dérivé : il a pu être
                    # relu et amendé depuis, et le remplacer par une copie fraîche
                    # de la source effacerait ce travail sans le dire.
                    if dst.exists():
                        skipped.append(dst.name)
                        continue

                    text = src.read_text(encoding="utf-8")
                    text = _set_region(text, lang, REGION_LABEL[dst_market][lang], src.name)
                    text = _set_region_body(text, lang, state, doc,
                                            src_market, dst_market, src.name)
                    text = _set_market_blocks(text, dst_market, lang, state, doc,
                                              src.name)
                    text = _set_version(text, lang, state, src.name)
                    text, links = _retarget_links(text, src_market, dst_market, src.name)

                    if not check:
                        dst.write_text(text, encoding="utf-8")
                    written.append(f"{dst.name}  (de {src.name}, {links} lien(s))")

    verb = "verifie" if check else "ecrit"
    print(f"{len(written)} document(s) {verb} :")
    for name in written:
        print(f"  {name}")
    if skipped:
        print(f"\n{len(skipped)} deja present(s), laisse(s) intact(s) :")
        for name in skipped:
            print(f"  {name}")


if __name__ == "__main__":
    main()
