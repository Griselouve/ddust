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

LANGS = ("fr", "en", "es")
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
REGION_LABEL = {
    # `eu` n'est plus servi à personne, mais reste la SOURCE de la dérivation
    # historique : `_set_region_body` lit le libellé du marché source pour bâtir
    # ses motifs, et l'omettre ferait échouer la dérivation sur un KeyError.
    "eu":  {"fr": "Union Européenne",    "en": "European Union", "es": "Unión Europea"},
    "fr":  {"fr": "France",             "en": "France",         "es": "Francia"},
    "euo": {"fr": "Europe de l'Ouest",  "en": "Western Europe", "es": "Europa Occidental"},
    "eus": {"fr": "Europe du Sud",      "en": "Southern Europe", "es": "Europa Meridional"},
    "eun": {"fr": "Europe du Nord",     "en": "Northern Europe", "es": "Europa Septentrional"},
    # ⚠ LIBELLÉ PROVISOIRE. `eux` regroupe GR SK SI EE LV LT CY HR — ni « centrale »,
    #   ni « orientale » ne les couvre (la Grèce et Chypre ne sont ni l'une ni
    #   l'autre), et le « reste de l'Europe » du build.yml est une commodité
    #   interne qu'on ne sert pas à un lecteur. À trancher avant toute ouverture.
    "eux": {"fr": "Union européenne — autres pays",
            "en": "European Union — other countries",
            "es": "Unión Europea — otros países"},
    "uk":  {"fr": "Royaume-Uni",         "en": "United Kingdom", "es": "Reino Unido"},
    "ch":  {"fr": "Suisse",              "en": "Switzerland",    "es": "Suiza"},
    "us":  {"fr": "États-Unis",          "en": "United States",  "es": "Estados Unidos"},
    "ca":  {"fr": "Canada",              "en": "Canada",         "es": "Canadá"},
    "oceanie": {"fr": "Océanie",          "en": "Oceania",        "es": "Oceanía"},
    "bresil":  {"fr": "Brésil",           "en": "Brazil",         "es": "Brasil"},
    # ⚠ NOM DE MARCHÉ, PAS ÉNUMÉRATION. Le marché ne porte que MX et CO, mais les
    #   nommer dans l'en-tête obligerait l'espagnol à accorder au pluriel dans les
    #   documents enfants (« Aquí son… »). Les deux pays sont nommés là où ça
    #   compte : dans les clauses de fond.
    "hispam":  {"fr": "Amérique hispanophone", "en": "Spanish-speaking America", "es": "Hispanoamérica"},
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
    },
    ("k", "cgu"): {
        "fr": [(r"c'est\s+{src_a}",         "c'est {dst_a}")],
        "en": [(r"it\s+is\s+(?:the\s+)?{src}", "it is {dst_a}")],
        "es": [(r"es\s+(?:la\s+)?{src}",       "es {dst_a}")],
    },
    ("k", "privacy"): {
        "fr": [(r"c'est\s+{src_a}",         "c'est {dst_a}")],
        "en": [(r"it\s+is\s+(?:the\s+)?{src}", "it is {dst_a}")],
        "es": [(r"es\s+(?:la\s+)?{src}",       "es {dst_a}")],
    },
}

# Étiquettes localisées de l'en-tête. Le français met une espace avant le
# deux-points, pas les deux autres.
REGION_TAG  = {"fr": "Région :",  "en": "Region:",  "es": "Región:"}
VERSION_TAG = {"fr": "Version :", "en": "Version:", "es": "Versión:"}

# Un corpus neuf entre en vigueur à sa création, pas à celle de son modèle.
# ⚠ ALIGNÉES SUR LA DATE QUE PORTE LE CORPUS, pas sur celle de l'exécution passée :
#   la remise à plat du 2026-08-28 (`reset_corpus_v1.py`) a redaté tous les
#   documents. Dériver un marché en le datant du 27 lui donnerait une date
#   qu'aucun autre document ne porte.
DATE_ADULT = {
    "fr": "en vigueur au 28 août 2026",
    "en": "in force as of 28 August 2026",
    "es": "en vigor desde el 28 de agosto de 2026",
}
DATE_KID = {
    "fr": "28 août 2026",
    "en": "28 August 2026",
    "es": "28 de agosto de 2026",
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
}

# L'autorité nommée en exemple diffère DÉJÀ d'une langue à l'autre dans le corpus
# source : la version française cite la CNIL, l'espagnole l'AEPD. On remplace donc
# une source différente par langue.
_AUTORITE_SRC = {
    "fr": '— en France, la CNIL (<a href="https://www.cnil.fr">www.cnil.fr</a>)',
    "en": '— in France, the CNIL (<a href="https://www.cnil.fr">www.cnil.fr</a>)',
    "es": '— en España, la AEPD (<a href="https://www.aepd.es">www.aepd.es</a>)',
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
    },
    "eus": {
        "fr": "— en Espagne l'AEPD, en Italie le Garante per la protezione dei dati personali "
              "et au Portugal la CNPD",
        "en": "— in Spain the AEPD, in Italy the Garante per la protezione dei dati personali "
              "and in Portugal the CNPD",
        "es": "— en España la AEPD, en Italia el Garante per la protezione dei dati personali "
              "y en Portugal la CNPD",
    },
    "eun": {
        "fr": "— au Danemark et en Norvège le Datatilsynet, en Finlande le Bureau du médiateur à la protection "
              "des données et en Suède l'IMY",
        "en": "— in Denmark and Norway the Datatilsynet, in Finland the Office of the Data Protection Ombudsman "
              "and in Sweden the IMY",
        "es": "— en Dinamarca y Noruega el Datatilsynet, en Finlandia la Oficina del Defensor de la Protección "
              "de Datos y en Suecia la IMY",
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
}

# Fourchette réelle du marché. On donne l'ÉTENDUE et non un chiffre : `euo` porte
# à lui seul tout l'écart permis par l'article 8, de 13 à 16 ans.
_ART8_AGES = {
    "euo": {"fr": "13 ans en Belgique et à Malte, 14 ans en Autriche, 16 ans en Allemagne, en Irlande, au Luxembourg et aux Pays-Bas",
            "en": "13 in Belgium and Malta, 14 in Austria, 16 in Germany, Ireland, Luxembourg and the Netherlands",
            "es": "13 años en Bélgica y Malta, 14 en Austria, 16 en Alemania, Irlanda, Luxemburgo y los Países Bajos"},
    "eus": {"fr": "13 ans au Portugal, 14 ans en Espagne et en Italie",
            "en": "13 in Portugal, 14 in Spain and Italy",
            "es": "13 años en Portugal, 14 en España e Italia"},
    "eun": {"fr": "13 ans au Danemark, en Finlande, en Norvège et en Suède",
            "en": "13 in Denmark, Finland, Norway and Sweden",
            "es": "13 años en Dinamarca, Finlandia, Noruega y Suecia"},
    "eux": {"fr": "13 ans en Estonie et en Lettonie, 14 ans à Chypre et en Lituanie, 15 ans en Grèce et en Slovénie, 16 ans en Croatie et en Slovaquie",
            "en": "13 in Estonia and Latvia, 14 in Cyprus and Lithuania, 15 in Greece and Slovenia, 16 in Croatia and Slovakia",
            "es": "13 años en Estonia y Letonia, 14 en Chipre y Lituania, 15 en Grecia y Eslovenia, 16 en Croacia y Eslovaquia"},
}

# Incise EEE, `eun` seul : elle s'insère juste après « chaque État membre ».
_ART8_PAREN = {"fr": "15 ans en France", "en": "15 in France", "es": "15 años en Francia"}

_EEE_INCISE = {
    "fr": "chaque État membre — et, par l'accord sur l'Espace économique européen, la Norvège —",
    "en": "each Member State — and, through the European Economic Area Agreement, Norway —",
    "es": "cada Estado miembro — y, en virtud del Acuerdo sobre el Espacio Económico Europeo, Noruega —",
}
_EEE_SRC = {"fr": "chaque État membre", "en": "each Member State", "es": "cada Estado miembro"}

# `eun` SEUL : la Norvège n'est pas dans l'Union, la réserve des dispositions
# impératives doit donc viser l'EEE, faute de quoi elle ne joue pas pour elle.
# La compétence relève de Lugano 2007 et non de Bruxelles I bis.
_LOI_SRC = {
    "fr": "applicables dans votre pays de résidence au sein de l'Union Européenne.",
    "en": "applicable in your country of residence within the European Union.",
    "es": "aplicables en su país de residencia dentro de la Unión Europea.",
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
}
_EEE_STOCKAGE_SRC = {
    "fr": "des centres de données situés dans l'UE)",
    "en": "data centres located in the EU)",
    "es": "centros de datos situados en la UE)",
}
_EEE_STOCKAGE = {
    "fr": "des centres de données situés dans l'UE ; la Norvège appartenant à l'Espace économique européen, "
          "ce stockage n'emporte aucun transfert hors EEE)",
    "en": "data centres located in the EU; as Norway belongs to the European Economic Area, this storage "
          "involves no transfer outside the EEA)",
    "es": "centros de datos situados en la UE; al pertenecer Noruega al Espacio Económico Europeo, este "
          "almacenamiento no supone ninguna transferencia fuera del EEE)",
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
# ⚠ PREMIER MARCHÉ SANS MUR DE LA LANGUE. L'anglais y est natif : contrairement à
#   `eun` et `eux`, le corpus produit ici est lisible par son public, enfants
#   compris. C'est le seul des cinq nouveaux marchés qui soit réellement ouvrable.
_UK_ART8_SRC = {
    ("cgu", "fr"): "l'article 8 du RGPD, qui permet à chaque État membre de fixer entre 13 et 16 ans l'âge auquel un mineur peut consentir seul (15 ans en France) : nous n'utilisons jamais cette faculté et exigeons toujours le consentement du responsable légal.",
    ("cgu", "en"): "Article 8 of the GDPR, which lets each Member State set between 13 and 16 the age at which a minor may consent on their own (15 in France): we never rely on that option and always require the legal guardian's consent.",
    ("cgu", "es"): "el artículo 8 del RGPD, que permite a cada Estado miembro fijar entre los 13 y los 16 años la edad a la que un menor puede consentir por sí solo (15 años en Francia): nunca hacemos uso de esa facultad y siempre exigimos el consentimiento del responsable legal.",
    ("privacy", "fr"): "l'article 8 du RGPD, qui laisse chaque État membre fixer entre 13 et 16 ans l'âge du consentement numérique propre du mineur (15 ans en France) : nous n'utilisons jamais cette faculté.",
    ("privacy", "en"): "Article 8 of the GDPR, which lets each Member State set between 13 and 16 the age of a minor's own digital consent (15 in France): we never rely on that option.",
    ("privacy", "es"): "el artículo 8 del RGPD, que deja a cada Estado miembro fijar entre los 13 y los 16 años la edad del consentimiento digital propio del menor (15 años en Francia): nunca hacemos uso de esa facultad.",
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
}
# Le terme lui-meme, une fois les phrases traitees. L'anglais exige un motif brut :
# « UK GDPR » contient « GDPR ».
_UK_TERME = {
    "fr": ("RGPD", "UK GDPR", False),
    "en": (r"(?<!UK )GDPR", "UK GDPR", True),
    "es": ("RGPD", "UK GDPR", False),
}
_UK_HEBERGEMENT_SRC = {
    "fr": "avec stockage des données dans l'Union Européenne.",
    "en": "with data stored in the European Union.",
    "es": "con almacenamiento de los datos en la Unión Europea.",
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
}
# La réserve ne peut plus viser l'Union : elle vise le droit britannique.
_UK_LOI = {
    "fr": "applicables au Royaume-Uni, notamment le Consumer Rights Act 2015 et les Consumer Contracts "
          "(Information, Cancellation and Additional Charges) Regulations 2013.",
    "en": "applicable in the United Kingdom, in particular the Consumer Rights Act 2015 and the Consumer "
          "Contracts (Information, Cancellation and Additional Charges) Regulations 2013.",
    "es": "aplicables en el Reino Unido, en particular la Consumer Rights Act 2015 y las Consumer Contracts "
          "(Information, Cancellation and Additional Charges) Regulations 2013.",
}
_UK_ICO = {
    "fr": "— au Royaume-Uni, l'Information Commissioner's Office "
          '(<a href="https://ico.org.uk">ico.org.uk</a>)',
    "en": "— in the United Kingdom, the Information Commissioner's Office "
          '(<a href="https://ico.org.uk">ico.org.uk</a>)',
    "es": "— en el Reino Unido, la Information Commissioner's Office "
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
}
_PRESCRIPTION = {
    "uk": {
        "fr": "Cette durée est inférieure au délai de prescription du droit anglais (Limitation Act 1980, section 5 : six ans)",
        "en": "This period is shorter than the limitation period under English law (Limitation Act 1980, section 5: six years)",
        "es": "Este plazo es inferior al de prescripción del derecho inglés (Limitation Act 1980, sección 5: seis años)",
    },
    "ch": {
        "fr": "Cette durée est inférieure au délai de prescription de droit commun suisse (art. 127 du code des obligations : dix ans)",
        "en": "This period is shorter than the general Swiss limitation period (Article 127 of the Code of Obligations: ten years)",
        "es": "Este plazo es inferior al de prescripción de derecho común suizo (art. 127 del Código de las Obligaciones: diez años)",
    },
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
        out.append((_EEE_STOCKAGE_SRC[lang], {
            "fr": "des centres de données situés dans l'UE, donc hors du Royaume-Uni ; ce transfert "
                  "repose sur les règlements d'adéquation britanniques au bénéfice de l'EEE)",
            "en": "data centres located in the EU, therefore outside the United Kingdom; this transfer "
                  "relies on the United Kingdom's adequacy regulations for the EEA)",
            "es": "centros de datos situados en la UE, por tanto fuera del Reino Unido; esta transferencia "
                  "se ampara en los reglamentos de adecuación británicos respecto del EEE)",
        }[lang]))
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
}
_CH_RETRACTATION = {
    "fr": "<li><strong>Remboursement</strong> — tous les achats et abonnements sont traités par la plateforme de téléchargement. <strong>Le droit suisse ne prévoit pas de droit de rétractation légal</strong> pour un contrat conclu à distance de ce type : les art. 40a et suivants du code des obligations visent le démarchage, non le commerce en ligne. La politique de remboursement de la plateforme s'applique néanmoins, et toute demande se fait depuis les outils de gestion d'abonnement et d'historique d'achat de votre compte Google. Ces stipulations sont sans préjudice de vos droits légaux impératifs.</li>",
    "en": "<li><strong>Refunds</strong> — all purchases and subscriptions are processed by the download platform. <strong>Swiss law provides no statutory right of withdrawal</strong> for a distance contract of this kind: Articles 40a et seq. of the Code of Obligations cover doorstep selling, not online commerce. The platform's refund policy nonetheless applies, and any request is made through the subscription management and purchase history tools of your Google account. These provisions are without prejudice to your mandatory statutory rights.</li>",
    "es": "<li><strong>Reembolso</strong> — todas las compras y suscripciones las tramita la plataforma de descarga. <strong>El derecho suizo no prevé un derecho legal de desistimiento</strong> para un contrato a distancia de este tipo: los arts. 40a y siguientes del Código de las Obligaciones se refieren a la venta domiciliaria, no al comercio en línea. No obstante, se aplica la política de reembolso de la plataforma, y cualquier solicitud se realiza desde las herramientas de gestión de suscripciones y de historial de compras de su cuenta de Google. Estas estipulaciones se entienden sin perjuicio de sus derechos legales imperativos.</li>",
}
_CH_LOI_SRC = {
    "fr": "Les présentes conditions sont régies par le droit français, sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre pays de résidence au sein de l'Union Européenne.",
    "en": "These terms are governed by French law, without prejudice to the mandatory consumer-protection provisions applicable in your country of residence within the European Union.",
    "es": "Las presentes condiciones se rigen por el derecho francés, sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su país de residencia dentro de la Unión Europea.",
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
}
_CH_STOCKAGE = {
    "fr": "des centres de données situés dans l'UE, donc hors de Suisse ; l'EEE figure à l'annexe 1 de "
          "l'ordonnance sur la protection des données parmi les États à protection adéquate)",
    "en": "data centres located in the EU, therefore outside Switzerland; the EEA is listed in Annex 1 to the "
          "Data Protection Ordinance among the States affording adequate protection)",
    "es": "centros de datos situados en la UE, por tanto fuera de Suiza; el EEE figura en el anexo 1 de la "
          "Ordenanza sobre la protección de datos entre los Estados con protección adecuada)",
}
_CH_PFPDT = {
    "fr": "— en Suisse, le Préposé fédéral à la protection des données et à la transparence "
          '(<a href="https://www.edoeb.admin.ch">edoeb.admin.ch</a>)',
    "en": "— in Switzerland, the Federal Data Protection and Information Commissioner "
          '(<a href="https://www.edoeb.admin.ch">edoeb.admin.ch</a>)',
    "es": "— en Suiza, el Encargado Federal de Protección de Datos y Transparencia "
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
}


def _ch_blocks(lang, doc):

    """Les ecarts suisses d'UN document adulte, dans l'ordre d'application."""
    out = [(_UK_ART8_SRC[(doc, lang)], _CH_ART8[(doc, lang)])]
    if doc == "cgu":
        out.append((_UK_HEBERGEMENT_SRC[lang], _CH_HEBERGEMENT[lang]))
        out.append((_CH_RETRACTATION_SRC[lang], _CH_RETRACTATION[lang]))
        out.append((_CH_LOI_SRC[lang], _CH_LOI[lang]))
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
}
_US_SEUILS_SRC = {
    "fr": "(seuils applicables aux États-Unis : 13 ans, âge fixé par le Children's Online Privacy Protection Act, et 18 ans, âge de la majorité contractuelle)",
    "en": "(thresholds applicable in the United States: 13, the age set by the Children's Online Privacy Protection Act, and 18, the age of contractual majority)",
    "es": "(umbrales aplicables en los Estados Unidos: 13 años, edad fijada por la Children's Online Privacy Protection Act, y 18 años, edad de la mayoría contractual)",
}
_CA_SEUILS = {
    "fr": "(seuils applicables au Canada : 14 ans, âge en deçà duquel la Loi 25 exige au Québec le consentement du titulaire de l'autorité parentale, et 18 ans, seuil retenu par l'Application — la majorité est de 18 ou 19 ans selon la province)",
    "en": "(thresholds applicable in Canada: 14, the age below which Quebec's Law 25 requires the consent of the person having parental authority, and 18, the threshold used by the Application — the age of majority is 18 or 19 depending on the province)",
    "es": "(umbrales aplicables en Canadá: 14 años, edad por debajo de la cual la Ley 25 exige en Quebec el consentimiento del titular de la autoridad parental, y 18 años, umbral adoptado por la Aplicación — la mayoría de edad es de 18 o 19 años según la provincia)",
}
_US_H2_CGU_SRC = {
    "fr": "<h2>6. Enfants : consentement parental au titre de COPPA</h2>",
    "en": "<h2>6. Children: parental consent under COPPA</h2>",
    "es": "<h2>6. Niños: consentimiento parental conforme a COPPA</h2>",
}
_CA_H2_CGU = {
    "fr": "<h2>6. Mineurs : consentement parental (LPRPDE et Loi 25)</h2>",
    "en": "<h2>6. Minors: parental consent (PIPEDA and Law 25)</h2>",
    "es": "<h2>6. Menores: consentimiento parental (PIPEDA y Ley 25)</h2>",
}
_US_CADRE_SRC = {
    "fr": "La collecte d'informations personnelles auprès d'un enfant de moins de 13 ans est encadrée par le <strong>Children's Online Privacy Protection Act (COPPA)</strong> et par son règlement d'application.",
    "en": "The collection of personal information from a child under 13 is governed by the <strong>Children's Online Privacy Protection Act (COPPA)</strong> and by its implementing rule.",
    "es": "La recogida de información personal de un niño menor de 13 años está regulada por la <strong>Children's Online Privacy Protection Act (COPPA)</strong> y por su reglamento de aplicación.",
}
_CA_CADRE = {
    "fr": "La collecte de renseignements personnels auprès d'un mineur est encadrée par la <strong>Loi sur la protection des renseignements personnels et les documents électroniques (LPRPDE)</strong> et, au Québec, par la <strong>Loi 25</strong>, qui exige le consentement du titulaire de l'autorité parentale pour tout mineur de moins de 14 ans.",
    "en": "The collection of personal information from a minor is governed by the <strong>Personal Information Protection and Electronic Documents Act (PIPEDA)</strong> and, in Quebec, by <strong>Law 25</strong>, which requires the consent of the person having parental authority for any minor under 14.",
    "es": "La recogida de información personal de un menor está regulada por la <strong>Ley de protección de la información personal y los documentos electrónicos (PIPEDA)</strong> y, en Quebec, por la <strong>Ley 25</strong>, que exige el consentimiento del titular de la autoridad parental para todo menor de 14 años.",
}
_US_RESERVE_SRC = {
    "fr": "sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre État de résidence, que les présentes conditions n'excluent ni ne limitent.",
    "en": "without prejudice to the mandatory consumer-protection provisions applicable in your state of residence, which these terms neither exclude nor limit.",
    "es": "sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su estado de residencia, que las presentes condiciones no excluyen ni limitan.",
}
_CA_RESERVE = {
    "fr": "sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre <strong>province ou territoire de résidence</strong>, que les présentes conditions n'excluent ni ne limitent. Si vous résidez au Québec, l'article 3117 du Code civil du Québec vous garantit le bénéfice de ces dispositions et la compétence des tribunaux québécois.",
    "en": "without prejudice to the mandatory consumer-protection provisions applicable in your <strong>province or territory of residence</strong>, which these terms neither exclude nor limit. If you reside in Quebec, article 3117 of the Civil Code of Québec guarantees you the benefit of those provisions and the jurisdiction of Quebec courts.",
    "es": "sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su <strong>provincia o territorio de residencia</strong>, que las presentes condiciones no excluyen ni limitan. Si reside en Quebec, el artículo 3117 del Código Civil de Quebec le garantiza el beneficio de esas disposiciones y la competencia de los tribunales quebequenses.",
}
_US_FTC_CGU_SRC = {
    "fr": ', notamment la Federal Trade Commission (<a href="https://www.ftc.gov">www.ftc.gov</a>) pour les questions relatives à la vie privée des enfants, ainsi que le procureur général de votre État.',
    "en": ", in particular the Federal Trade Commission (<a href=\"https://www.ftc.gov\">www.ftc.gov</a>) for matters relating to children's privacy, and the attorney general of your state.",
    "es": ', en particular a la Federal Trade Commission (<a href="https://www.ftc.gov">www.ftc.gov</a>) para las cuestiones relativas a la privacidad de los niños, así como al fiscal general de su estado.',
}
_CA_FTC_CGU = {
    "fr": ', notamment le Commissariat à la protection de la vie privée du Canada (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) et, si vous résidez au Québec, la Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "en": ', in particular the Office of the Privacy Commissioner of Canada (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) and, if you reside in Quebec, the Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "es": ', en particular la Oficina del Comisionado de Privacidad de Canadá (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) y, si reside en Quebec, la Commission d\'accès à l\'information (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
}
_US_P1_SRC = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des informations de votre enfant au titre du Children's Online Privacy Protection Act (COPPA).",
    "en": "This is also the address to use to reach us about your child's information under the Children's Online Privacy Protection Act (COPPA).",
    "es": "Esta es también la dirección para contactarnos acerca de la información de su hijo conforme a la Children's Online Privacy Protection Act (COPPA).",
}
_CA_P1 = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des renseignements personnels de votre enfant au titre de la LPRPDE et, au Québec, de la Loi 25.",
    "en": "This is also the address to use to reach us about your child's personal information under PIPEDA and, in Quebec, Law 25.",
    "es": "Esta es también la dirección para contactarnos acerca de la información personal de su hijo conforme a PIPEDA y, en Quebec, a la Ley 25.",
}
_US_H2_P_SRC = {
    "fr": "<h2>4. Enfants de moins de 13 ans — COPPA</h2>",
    "en": "<h2>4. Children under 13 — COPPA</h2>",
    "es": "<h2>4. Niños menores de 13 años — COPPA</h2>",
}
_CA_H2_P = {
    "fr": "<h2>4. Mineurs — LPRPDE et Loi 25 (Québec)</h2>",
    "en": "<h2>4. Minors — PIPEDA and Law 25 (Quebec)</h2>",
    "es": "<h2>4. Menores — PIPEDA y Ley 25 (Quebec)</h2>",
}
_US_SEUILS_P_SRC = {
    "fr": "Les seuils d'âge applicables aux États-Unis sont 13 et 18 ans.",
    "en": "The age thresholds applicable in the United States are 13 and 18.",
    "es": "Los umbrales de edad aplicables en los Estados Unidos son 13 y 18 años.",
}
_CA_SEUILS_P = {
    "fr": "Le seuil retenu par l'application est 18 ans ; au Québec, la Loi 25 exige le consentement du titulaire de l'autorité parentale en deçà de 14 ans.",
    "en": "The threshold used by the application is 18; in Quebec, Law 25 requires the consent of the person having parental authority below the age of 14.",
    "es": "El umbral adoptado por la aplicación es 18 años; en Quebec, la Ley 25 exige el consentimiento del titular de la autoridad parental por debajo de los 14 años.",
}
_US_COPPA_P8_SRC = {"fr": "exigé par COPPA", "en": "required by COPPA", "es": "exigido por COPPA"}
_CA_COPPA_P8 = {
    "fr": "exigé par la Loi 25 au Québec",
    "en": "required by Law 25 in Quebec",
    "es": "exigido por la Ley 25 en Quebec",
}
_US_FTC_P_SRC = {
    "fr": 'Vous pouvez également saisir la <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>), chargée de faire appliquer COPPA, le procureur général de votre État, ou — si vous résidez en Californie — la <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
    "en": 'You may also contact the <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>), which enforces COPPA, the attorney general of your state, or — if you live in California — the <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
    "es": 'También puede dirigirse a la <strong>Federal Trade Commission</strong> (<a href="https://www.ftc.gov">www.ftc.gov</a>), encargada de hacer aplicar COPPA, al fiscal general de su estado o — si reside en California — a la <strong>California Privacy Protection Agency</strong> (<a href="https://cppa.ca.gov">cppa.ca.gov</a>).',
}
_CA_FTC_P = {
    "fr": 'Vous pouvez également saisir le <strong>Commissariat à la protection de la vie privée du Canada</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) ou, si vous résidez au Québec, la <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "en": 'You may also contact the <strong>Office of the Privacy Commissioner of Canada</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) or, if you reside in Quebec, the <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
    "es": 'También puede dirigirse a la <strong>Oficina del Comisionado de Privacidad de Canadá</strong> (<a href="https://www.priv.gc.ca">priv.gc.ca</a>) o, si reside en Quebec, a la <strong>Commission d\'accès à l\'information</strong> (<a href="https://www.cai.gouv.qc.ca">cai.gouv.qc.ca</a>).',
}
_US_CENTRES_SRC = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis)",
    "en": "(for this region: data centres located in the United States)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos)",
}
_CA_CENTRES = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis, donc hors du Canada)",
    "en": "(for this region: data centres located in the United States, therefore outside Canada)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos, por tanto fuera de Canadá)",
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
    },
    "privacy_a": {
        "fr": "Selon votre État de résidence, vous pouvez avoir le droit",
        "en": "Depending on your state of residence, you may have the right",
        "es": "Según su estado de residencia, puede tener derecho",
    },
    "privacy_b": {
        "fr": "quel que soit leur État de résidence",
        "en": "whichever state you live in",
        "es": "cualquiera que sea su estado de residencia",
    },
}

# Comment se nomme l'unite de residence, par marche puis par langue.
_UNITE = {
    "ca":      {"fr": ("province ou territoire", "leur province ou territoire de résidence"),
                "en": ("province or territory",  "whichever province or territory you live in"),
                "es": ("provincia o territorio", "cualquiera que sea su provincia o territorio")},
    "oceanie": {"fr": ("pays", "leur pays de résidence"),
                "en": ("country", "whichever of the two countries you live in"),
                "es": ("país", "cualquiera que sea su país de residencia")},
}


def _us_etat_blocks(market, lang, doc):

    """Les phrases du corpus americain qui disent « votre Etat », requalifiees."""
    unite, quelque = _UNITE[market][lang]
    if doc == "cgu":
        return [(_US_ETAT_SRC["cgu"][lang], {
            "fr": f"sans préjudice des droits que la loi de votre {unite} vous reconnaît.",
            "en": f"without prejudice to any rights you may have under the law of your {unite}.",
            "es": f"sin perjuicio de los derechos que le reconozca la ley de su {unite}.",
        }[lang])]
    return [
        (_US_ETAT_SRC["privacy_a"][lang], {
            "fr": f"Selon votre {unite} de résidence, vous pouvez avoir le droit",
            "en": f"Depending on your {unite} of residence, you may have the right",
            "es": f"Según su {unite} de residencia, puede tener derecho",
        }[lang]),
        (_US_ETAT_SRC["privacy_b"][lang], quelque),
    ]


_CA_LIMITATION = {
    "fr": "Certaines provinces n'autorisent pas l'exclusion ou la limitation de certains dommages ; dans ce cas, les limitations ci-dessus ne s'appliquent que dans la mesure permise par le droit de votre province, et rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable. Si vous résidez au Québec, la Loi sur la protection du consommateur s'applique et ne peut pas être écartée par contrat.",
    "en": "Some provinces do not allow the exclusion or limitation of certain damages; in that case the limitations above apply only to the extent permitted by the law of your province, and nothing in these terms excludes liability for gross negligence or personal injury attributable to the publisher. If you reside in Quebec, the Consumer Protection Act applies and cannot be contracted out of.",
    "es": "Algunas provincias no permiten la exclusión o limitación de determinados daños; en ese caso, las limitaciones anteriores solo se aplican en la medida permitida por el derecho de su provincia, y nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable. Si reside en Quebec, la Ley de protección del consumidor se aplica y no admite pacto en contrario.",
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
}
_US_LIMITATION_SRC = {
    "fr": "Certains États n'autorisent pas l'exclusion ou la limitation de certains dommages ; dans ce cas, les limitations ci-dessus ne s'appliquent que dans la mesure permise par le droit de votre État, et rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable.",
    "en": "Some states do not allow the exclusion or limitation of certain damages; in that case the limitations above apply only to the extent permitted by the law of your state, and nothing in these terms excludes liability for gross negligence or personal injury attributable to the publisher.",
    "es": "Algunos estados no permiten la exclusión o limitación de determinados daños; en ese caso, las limitaciones anteriores solo se aplican en la medida permitida por el derecho de su estado, y nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable.",
}
_OC_LIMITATION = {
    "fr": "<strong>Rien dans les présentes conditions n'exclut, ne restreint ni ne modifie les garanties du consommateur</strong> prévues par l'Australian Consumer Law ou par le Consumer Guarantees Act 1993 néo-zélandais, qui ne peuvent pas être écartées par contrat. Les limitations ci-dessus ne s'appliquent que dans la mesure permise par ces textes, et rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable.",
    "en": "<strong>Nothing in these terms excludes, restricts or modifies the consumer guarantees</strong> conferred by the Australian Consumer Law or by the New Zealand Consumer Guarantees Act 1993, which cannot be contracted out of. The limitations above apply only to the extent permitted by those Acts, and nothing excludes liability for gross negligence or personal injury attributable to the publisher.",
    "es": "<strong>Nada en las presentes condiciones excluye, restringe ni modifica las garantías del consumidor</strong> previstas por la Australian Consumer Law o por la Consumer Guarantees Act 1993 neozelandesa, que no pueden excluirse por contrato. Las limitaciones anteriores solo se aplican en la medida permitida por esos textos, y nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable.",
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
}
_OC_SEUILS = {
    "fr": "(ni le Privacy Act 1988 australien ni le Privacy Act 2020 néo-zélandais ne fixent d'âge de consentement : l'Application retient 18 ans et exige dans tous les cas le consentement d'un adulte responsable)",
    "en": "(neither the Australian Privacy Act 1988 nor the New Zealand Privacy Act 2020 sets a consent age: the Application uses 18 and always requires the consent of a responsible adult)",
    "es": "(ni la Privacy Act 1988 australiana ni la Privacy Act 2020 neozelandesa fijan una edad de consentimiento: la Aplicación adopta los 18 años y exige en todo caso el consentimiento de un adulto responsable)",
}
_OC_H2_CGU = {
    "fr": "<h2>6. Mineurs : consentement parental (Privacy Act 1988 et Privacy Act 2020)</h2>",
    "en": "<h2>6. Minors: parental consent (Privacy Act 1988 and Privacy Act 2020)</h2>",
    "es": "<h2>6. Menores: consentimiento parental (Privacy Act 1988 y Privacy Act 2020)</h2>",
}
_OC_CADRE = {
    "fr": "La collecte de renseignements personnels auprès d'un mineur est encadrée par le <strong>Privacy Act 1988</strong> et les Australian Privacy Principles en Australie, et par le <strong>Privacy Act 2020</strong> et ses Information Privacy Principles en Nouvelle-Zélande.",
    "en": "The collection of personal information from a minor is governed by the <strong>Privacy Act 1988</strong> and the Australian Privacy Principles in Australia, and by the <strong>Privacy Act 2020</strong> and its Information Privacy Principles in New Zealand.",
    "es": "La recogida de información personal de un menor está regulada por la <strong>Privacy Act 1988</strong> y los Australian Privacy Principles en Australia, y por la <strong>Privacy Act 2020</strong> y sus Information Privacy Principles en Nueva Zelanda.",
}
_OC_RESERVE = {
    "fr": "sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre <strong>pays de résidence</strong>, que les présentes conditions n'excluent ni ne limitent — en particulier l'Australian Consumer Law et le Consumer Guarantees Act 1993, auxquels il ne peut être dérogé par contrat.",
    "en": "without prejudice to the mandatory consumer-protection provisions applicable in your <strong>country of residence</strong>, which these terms neither exclude nor limit — in particular the Australian Consumer Law and the Consumer Guarantees Act 1993, which cannot be contracted out of.",
    "es": "sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su <strong>país de residencia</strong>, que las presentes condiciones no excluyen ni limitan — en particular la Australian Consumer Law y la Consumer Guarantees Act 1993, que no admiten pacto en contrario.",
}
_OC_AUTORITES_CGU = {
    "fr": ', notamment l\'Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) ou, en Nouvelle-Zélande, l\'Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "en": ', in particular the Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) or, in New Zealand, the Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "es": ', en particular la Office of the Australian Information Commissioner (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) o, en Nueva Zelanda, la Office of the Privacy Commissioner (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
}
_OC_P1 = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des renseignements personnels de votre enfant au titre du Privacy Act 1988 ou du Privacy Act 2020.",
    "en": "This is also the address to use to reach us about your child's personal information under the Privacy Act 1988 or the Privacy Act 2020.",
    "es": "Esta es también la dirección para contactarnos acerca de la información personal de su hijo conforme a la Privacy Act 1988 o a la Privacy Act 2020.",
}
_OC_H2_P = {
    "fr": "<h2>4. Mineurs — Privacy Act 1988 (Australie) et Privacy Act 2020 (Nouvelle-Zélande)</h2>",
    "en": "<h2>4. Minors — Privacy Act 1988 (Australia) and Privacy Act 2020 (New Zealand)</h2>",
    "es": "<h2>4. Menores — Privacy Act 1988 (Australia) y Privacy Act 2020 (Nueva Zelanda)</h2>",
}
_OC_SEUILS_P = {
    "fr": "Le seuil retenu par l'application est 18 ans ; ni le droit australien ni le droit néo-zélandais ne fixent d'âge de consentement propre au mineur.",
    "en": "The threshold used by the application is 18; neither Australian nor New Zealand law sets an age at which a minor may consent on their own.",
    "es": "El umbral adoptado por la aplicación es 18 años; ni el derecho australiano ni el neozelandés fijan una edad de consentimiento propia del menor.",
}
_OC_COPPA_P8 = {
    "fr": "exigé d'un adulte responsable",
    "en": "required from a responsible adult",
    "es": "exigido a un adulto responsable",
}
_OC_AUTORITES_P = {
    "fr": 'Vous pouvez également saisir l\'<strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) ou, si vous résidez en Nouvelle-Zélande, l\'<strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "en": 'You may also contact the <strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) or, if you live in New Zealand, the <strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
    "es": 'También puede dirigirse a la <strong>Office of the Australian Information Commissioner</strong> (<a href="https://www.oaic.gov.au">oaic.gov.au</a>) o, si reside en Nueva Zelanda, a la <strong>Office of the Privacy Commissioner</strong> (<a href="https://www.privacy.org.nz">privacy.org.nz</a>).',
}
_OC_CENTRES = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis, donc hors d'Australie et de Nouvelle-Zélande)",
    "en": "(for this region: data centres located in the United States, therefore outside Australia and New Zealand)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos, por tanto fuera de Australia y Nueva Zelanda)",
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
# ⚠ MUR DE LA LANGUE. Le portugais n'est pas au corpus. Le CDC et le décret 7.962/2013
#   imposent une information claire en portugais au consommateur brésilien : ce corpus
#   est écrit, il n'est pas ouvrable.
_BR_REMBOURSEMENT = {
    "fr": "<li><strong>Remboursement et rétractation</strong> — tous les achats et abonnements sont traités par la plateforme de téléchargement. <strong>L'article 49 du Code de défense du consommateur vous ouvre un droit de rétractation de sept jours</strong> à compter de l'achat, sans avoir à vous justifier ; ce délai s'applique quelle que soit la politique de la plateforme. Les demandes s'exercent au moyen des outils de gestion d'abonnement et d'historique d'achat de votre compte Google, ou en nous écrivant à donjons@grisloup.com.</li>",
    "en": "<li><strong>Refunds and withdrawal</strong> — all purchases and subscriptions are processed by the download platform. <strong>Article 49 of the Consumer Protection Code gives you a seven-day right of withdrawal</strong> from the purchase, without having to give reasons; that period applies whatever the platform's own policy provides. Requests are made through the subscription management and purchase history tools of your Google account, or by writing to donjons@grisloup.com.</li>",
    "es": "<li><strong>Reembolso y desistimiento</strong> — todas las compras y suscripciones las tramita la plataforma de descarga. <strong>El artículo 49 del Código de Defensa del Consumidor le reconoce un derecho de desistimiento de siete días</strong> desde la compra, sin necesidad de justificación; ese plazo se aplica cualquiera que sea la política de la plataforma. Las solicitudes se cursan mediante las herramientas de gestión de suscripciones y de historial de compras de su cuenta de Google, o escribiendo a donjons@grisloup.com.</li>",
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
}
_BR_SEUILS = {
    "fr": "(seuils applicables au Brésil : 12 ans, âge en deçà duquel l'article 14 de la LGPD qualifie le joueur d'« enfant » et exige le consentement spécifique et mis en évidence de l'un des parents, et 18 ans, âge de la majorité)",
    "en": "(thresholds applicable in Brazil: 12, below which Article 14 of the LGPD treats the player as a \"child\" and requires the specific, prominent consent of one parent, and 18, the age of majority)",
    "es": "(umbrales aplicables en Brasil: 12 años, por debajo de los cuales el artículo 14 de la LGPD califica al jugador de «niño» y exige el consentimiento específico y destacado de uno de los progenitores, y 18 años, edad de la mayoría)",
}
_BR_H2_CGU = {
    "fr": "<h2>6. Mineurs : consentement parental (article 14 de la LGPD)</h2>",
    "en": "<h2>6. Minors: parental consent (Article 14 of the LGPD)</h2>",
    "es": "<h2>6. Menores: consentimiento parental (artículo 14 de la LGPD)</h2>",
}
_BR_CADRE = {
    "fr": "La collecte de données personnelles auprès d'un mineur est encadrée par l'<strong>article 14 de la Loi générale de protection des données (LGPD, loi 13.709/2018)</strong>, qui impose que tout traitement se fasse dans son intérêt supérieur et exige, en deçà de 12 ans, le consentement spécifique et mis en évidence de l'un des parents ou du responsable légal.",
    "en": "The collection of personal data from a minor is governed by <strong>Article 14 of the General Data Protection Law (LGPD, Law 13.709/2018)</strong>, which requires all processing to serve the minor's best interest and, below the age of 12, the specific and prominent consent of one parent or legal guardian.",
    "es": "La recogida de datos personales de un menor está regulada por el <strong>artículo 14 de la Ley General de Protección de Datos (LGPD, ley 13.709/2018)</strong>, que exige que todo tratamiento se realice en su interés superior y requiere, por debajo de los 12 años, el consentimiento específico y destacado de uno de los progenitores o del responsable legal.",
}
_BR_LIMITATION = {
    "fr": "<strong>L'article 51 du Code de défense du consommateur frappe de nullité toute clause qui exonère ou limite la responsabilité du fournisseur envers un consommateur</strong> : les limitations ci-dessus ne lui sont pas opposables. Rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable.",
    "en": "<strong>Article 51 of the Consumer Protection Code renders void any clause that excludes or limits the supplier's liability towards a consumer</strong>: the limitations above cannot be relied on against them. Nothing excludes liability for gross negligence or personal injury attributable to the publisher.",
    "es": "<strong>El artículo 51 del Código de Defensa del Consumidor declara nula toda cláusula que exonere o limite la responsabilidad del proveedor frente a un consumidor</strong>: las limitaciones anteriores no le son oponibles. Nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable.",
}
_BR_RESERVE = {
    "fr": "sans préjudice du <strong>Code de défense du consommateur</strong>, qui est d'ordre public et dont aucune stipulation des présentes ne peut vous priver. Son article 101 vous permet de porter le litige devant le tribunal de votre domicile, et l'article 11 du Marco Civil da Internet soumet au droit brésilien toute collecte de données opérée au Brésil.",
    "en": "without prejudice to the <strong>Consumer Protection Code</strong>, which is a matter of public policy and of which nothing in these terms can deprive you. Its Article 101 lets you bring the dispute before the court of your own domicile, and Article 11 of the Marco Civil da Internet subjects any data collection carried out in Brazil to Brazilian law.",
    "es": "sin perjuicio del <strong>Código de Defensa del Consumidor</strong>, que es de orden público y del que ninguna estipulación de las presentes puede privarle. Su artículo 101 le permite someter el litigio al tribunal de su domicilio, y el artículo 11 del Marco Civil da Internet sujeta al derecho brasileño toda recogida de datos realizada en Brasil.",
}
_BR_ANPD_CGU = {
    "fr": ', notamment l\'Autorité nationale de protection des données (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) et les organismes de défense du consommateur (Procon).',
    "en": ', in particular the National Data Protection Authority (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) and the consumer protection bodies (Procon).',
    "es": ', en particular la Autoridad Nacional de Protección de Datos (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) y los organismos de defensa del consumidor (Procon).',
}
_BR_P1 = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des données personnelles de votre enfant au titre de l'article 14 de la LGPD ; elle tient lieu de canal de communication avec la personne concernée.",
    "en": "This is also the address to use to reach us about your child's personal data under Article 14 of the LGPD; it serves as the communication channel with the data subject.",
    "es": "Esta es también la dirección para contactarnos acerca de los datos personales de su hijo conforme al artículo 14 de la LGPD; sirve de canal de comunicación con el titular de los datos.",
}
_BR_H2_P = {
    "fr": "<h2>4. Mineurs — article 14 de la LGPD</h2>",
    "en": "<h2>4. Minors — Article 14 of the LGPD</h2>",
    "es": "<h2>4. Menores — artículo 14 de la LGPD</h2>",
}
_BR_SEUILS_P = {
    "fr": "Le seuil retenu par l'application est 18 ans ; l'article 14 de la LGPD exige en deçà de 12 ans le consentement spécifique et mis en évidence de l'un des parents.",
    "en": "The threshold used by the application is 18; below the age of 12, Article 14 of the LGPD requires the specific and prominent consent of one parent.",
    "es": "El umbral adoptado por la aplicación es 18 años; por debajo de los 12, el artículo 14 de la LGPD exige el consentimiento específico y destacado de uno de los progenitores.",
}
_BR_COPPA_P8 = {
    "fr": "exigé par l'article 14 de la LGPD",
    "en": "required by Article 14 of the LGPD",
    "es": "exigido por el artículo 14 de la LGPD",
}
_BR_ANPD_P = {
    "fr": 'Vous pouvez également saisir l\'<strong>Autorité nationale de protection des données</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) ou un organisme de défense du consommateur (Procon).',
    "en": 'You may also contact the <strong>National Data Protection Authority</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) or a consumer protection body (Procon).',
    "es": 'También puede dirigirse a la <strong>Autoridad Nacional de Protección de Datos</strong> (<a href="https://www.gov.br/anpd">gov.br/anpd</a>) o a un organismo de defensa del consumidor (Procon).',
}
_BR_CENTRES = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis, donc hors du Brésil — transfert international encadré par les articles 33 à 36 de la LGPD)",
    "en": "(for this region: data centres located in the United States, therefore outside Brazil — an international transfer governed by Articles 33 to 36 of the LGPD)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos, por tanto fuera de Brasil — transferencia internacional amparada en los artículos 33 a 36 de la LGPD)",
}
# ⚠ PAS DE `_us_etat_blocks` POUR LE BRÉSIL : la puce « Remboursement » est
#   entièrement réécrite (elle portait la mention « votre État »), et le §9 de la
#   politique se raccroche à la LGPD, qui est fédérale.
_BR_DROITS_SRC = {
    "fr": "Selon votre État de résidence, vous pouvez avoir le droit",
    "en": "Depending on your state of residence, you may have the right",
    "es": "Según su estado de residencia, puede tener derecho",
}
_BR_DROITS = {
    "fr": "En vertu de l'article 18 de la LGPD, vous avez le droit",
    "en": "Under Article 18 of the LGPD, you have the right",
    "es": "En virtud del artículo 18 de la LGPD, usted tiene derecho",
}
# ⚠ NE PAS RECOPIER LA SOURCE À L'IDENTIQUE. La première version rendait « quel que
#   soit leur État de résidence » inchangé en français : la substitution trouvait
#   bien son occurrence et ne changeait rien, donc le contrôle passait au vert pour
#   une phrase restée américaine. Un remplacement égal à sa source est un bug muet.
_BR_ETENDU = {
    "fr": "où qu'ils résident au Brésil",
    "en": "wherever in Brazil you live",
    "es": "dondequiera que residan en Brasil",
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
# ⚠ PAS DE MUR DE LA LANGUE : l'espagnol est au corpus. C'est ce qui sépare
#   `hispam` de `bresil`, dont le portugais manque.
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
}
_HI_SEUILS = {
    "fr": "(ni la LFPDPPP mexicaine ni la loi colombienne 1581 de 2012 ne fixent d'âge de consentement numérique : l'Application retient 18 ans et exige dans tous les cas l'autorisation du représentant légal du mineur)",
    "en": "(neither the Mexican LFPDPPP nor Colombian Law 1581 of 2012 sets a digital consent age: the Application uses 18 and always requires the authorisation of the minor's legal representative)",
    "es": "(ni la LFPDPPP mexicana ni la Ley 1581 de 2012 de Colombia fijan una edad de consentimiento digital: la Aplicación adopta los 18 años y exige en todo caso la autorización del representante legal del menor)",
}
_HI_H2_CGU = {
    "fr": "<h2>6. Mineurs : autorisation du représentant légal (LFPDPPP et loi 1581)</h2>",
    "en": "<h2>6. Minors: legal representative's authorisation (LFPDPPP and Law 1581)</h2>",
    "es": "<h2>6. Menores: autorización del representante legal (LFPDPPP y Ley 1581)</h2>",
}
_HI_CADRE = {
    "fr": "La collecte de données personnelles auprès d'un mineur est encadrée par la <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> au Mexique et par l'<strong>article 7 de la loi 1581 de 2012</strong> en Colombie, qui n'autorise le traitement des données d'un mineur que s'il respecte son intérêt supérieur et ses droits fondamentaux, sur autorisation de son représentant légal.",
    "en": "The collection of personal data from a minor is governed by the <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> in Mexico and by <strong>Article 7 of Law 1581 of 2012</strong> in Colombia, which permits processing a minor's data only where it respects their best interest and fundamental rights, and with their legal representative's authorisation.",
    "es": "La recogida de datos personales de un menor está regulada por la <strong>Ley Federal de Protección de Datos Personales en Posesión de los Particulares</strong> en México y por el <strong>artículo 7 de la Ley 1581 de 2012</strong> en Colombia, que solo permite el tratamiento de los datos de un menor cuando respeta su interés superior y sus derechos fundamentales, con autorización de su representante legal.",
}
_HI_REMBOURSEMENT = {
    "fr": "<li><strong>Remboursement et rétractation</strong> — tous les achats et abonnements sont traités par la plateforme de téléchargement. <strong>L'article 56 de la Ley Federal de Protección al Consumidor au Mexique et l'article 47 du Estatuto del Consumidor en Colombie ouvrent un droit de rétractation de cinq jours ouvrables</strong> ; en Colombie, ce droit ne joue pas lorsque la fourniture du service a commencé avec votre accord. Les demandes s'exercent au moyen des outils de gestion d'abonnement et d'historique d'achat de votre compte Google, ou en nous écrivant à donjons@grisloup.com.</li>",
    "en": "<li><strong>Refunds and withdrawal</strong> — all purchases and subscriptions are processed by the download platform. <strong>Article 56 of the Ley Federal de Protección al Consumidor in Mexico and Article 47 of the Estatuto del Consumidor in Colombia give you a five-business-day right of withdrawal</strong>; in Colombia that right does not apply once supply of the service has begun with your agreement. Requests are made through the subscription management and purchase history tools of your Google account, or by writing to donjons@grisloup.com.</li>",
    "es": "<li><strong>Reembolso y retracto</strong> — todas las compras y suscripciones las tramita la plataforma de descarga. <strong>El artículo 56 de la Ley Federal de Protección al Consumidor en México y el artículo 47 del Estatuto del Consumidor en Colombia le reconocen un derecho de retracto de cinco días hábiles</strong>; en Colombia ese derecho no procede cuando la prestación del servicio ha comenzado con su acuerdo. Las solicitudes se cursan mediante las herramientas de gestión de suscripciones y de historial de compras de su cuenta de Google, o escribiendo a donjons@grisloup.com.</li>",
}
_HI_LIMITATION = {
    "fr": "<strong>Les droits que la Ley Federal de Protección al Consumidor et le Estatuto del Consumidor reconnaissent au consommateur ne peuvent pas être écartés par contrat</strong> : les limitations ci-dessus ne s'appliquent que dans la mesure qu'ils permettent. Rien n'exclut la responsabilité de l'éditeur en cas de faute lourde ou de dommage corporel qui lui serait imputable.",
    "en": "<strong>The rights conferred on consumers by the Ley Federal de Protección al Consumidor and the Estatuto del Consumidor cannot be contracted out of</strong>: the limitations above apply only to the extent those Acts permit. Nothing excludes liability for gross negligence or personal injury attributable to the publisher.",
    "es": "<strong>Los derechos que la Ley Federal de Protección al Consumidor y el Estatuto del Consumidor reconocen al consumidor no pueden excluirse por contrato</strong>: las limitaciones anteriores solo se aplican en la medida en que dichas leyes lo permitan. Nada excluye la responsabilidad del editor en caso de culpa grave o de daño corporal que le sea imputable.",
}
_HI_RESERVE = {
    "fr": "sans préjudice des dispositions impératives de protection des consommateurs applicables dans votre <strong>pays de résidence</strong> — la Ley Federal de Protección al Consumidor au Mexique, le Estatuto del Consumidor (loi 1480 de 2011) en Colombie —, que les présentes conditions n'excluent ni ne limitent.",
    "en": "without prejudice to the mandatory consumer-protection provisions applicable in your <strong>country of residence</strong> — the Ley Federal de Protección al Consumidor in Mexico, the Estatuto del Consumidor (Law 1480 of 2011) in Colombia — which these terms neither exclude nor limit.",
    "es": "sin perjuicio de las disposiciones imperativas de protección de los consumidores aplicables en su <strong>país de residencia</strong> — la Ley Federal de Protección al Consumidor en México, el Estatuto del Consumidor (Ley 1480 de 2011) en Colombia —, que las presentes condiciones no excluyen ni limitan.",
}
_HI_AUTORITES_CGU = {
    "fr": ', notamment la Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) au Mexique et la Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) en Colombie.',
    "en": ', in particular the Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) in Mexico and the Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) in Colombia.',
    "es": ', en particular la Procuraduría Federal del Consumidor (<a href="https://www.profeco.gob.mx">profeco.gob.mx</a>) en México y la Superintendencia de Industria y Comercio (<a href="https://www.sic.gov.co">sic.gov.co</a>) en Colombia.',
}
_HI_P1 = {
    "fr": "C'est également l'adresse à utiliser pour nous joindre au sujet des données personnelles de votre enfant, pour exercer vos droits ARCO au Mexique ou vos droits au titre de la loi 1581 en Colombie. La présente politique vaut <strong>aviso de privacidad</strong> au sens de la LFPDPPP.",
    "en": "This is also the address to use to reach us about your child's personal data, and to exercise your ARCO rights in Mexico or your rights under Law 1581 in Colombia. This policy serves as the <strong>aviso de privacidad</strong> required by the LFPDPPP.",
    "es": "Esta es también la dirección para contactarnos acerca de los datos personales de su hijo, y para ejercer sus derechos ARCO en México o sus derechos conforme a la Ley 1581 en Colombia. La presente política constituye el <strong>aviso de privacidad</strong> exigido por la LFPDPPP.",
}
_HI_H2_P = {
    "fr": "<h2>4. Mineurs — LFPDPPP (Mexique) et loi 1581 de 2012 (Colombie)</h2>",
    "en": "<h2>4. Minors — LFPDPPP (Mexico) and Law 1581 of 2012 (Colombia)</h2>",
    "es": "<h2>4. Menores — LFPDPPP (México) y Ley 1581 de 2012 (Colombia)</h2>",
}
_HI_SEUILS_P = {
    "fr": "Le seuil retenu par l'application est 18 ans ; le traitement des données d'un mineur suppose l'autorisation de son représentant légal et, en Colombie, le respect démontré de son intérêt supérieur.",
    "en": "The threshold used by the application is 18; processing a minor's data requires their legal representative's authorisation and, in Colombia, a demonstrated respect for their best interest.",
    "es": "El umbral adoptado por la aplicación es 18 años; el tratamiento de los datos de un menor exige la autorización de su representante legal y, en Colombia, el respeto demostrado de su interés superior.",
}
_HI_COPPA_P8 = {
    "fr": "exigé du représentant légal",
    "en": "required from the legal representative",
    "es": "exigido al representante legal",
}
_HI_AUTORITES_P = {
    "fr": 'Vous pouvez également saisir l\'autorité mexicaine de protection des données personnelles — la <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, qui a succédé à l\'INAI — ou, en Colombie, la <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
    "en": 'You may also contact the Mexican personal data protection authority — the <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, which succeeded INAI — or, in Colombia, the <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
    "es": 'También puede dirigirse a la autoridad mexicana de protección de datos personales — la <strong>Secretaría Anticorrupción y Buen Gobierno</strong>, que sucedió al INAI — o, en Colombia, a la <strong>Superintendencia de Industria y Comercio</strong> (<a href="https://www.sic.gov.co">sic.gov.co</a>).',
}
_HI_CENTRES = {
    "fr": "(pour la présente région : des centres de données situés aux États-Unis, donc hors du Mexique et de la Colombie — transfert international soumis à votre autorisation préalable au sens de l'article 26 de la loi 1581)",
    "en": "(for this region: data centres located in the United States, therefore outside Mexico and Colombia — an international transfer subject to your prior authorisation under Article 26 of Law 1581)",
    "es": "(para la presente región: centros de datos situados en los Estados Unidos, por tanto fuera de México y Colombia — transferencia internacional sujeta a su autorización previa conforme al artículo 26 de la Ley 1581)",
}
_HI_DROITS = {
    "fr": "Au titre de vos droits ARCO au Mexique — accès, rectification, annulation, opposition — et de l'article 8 de la loi 1581 en Colombie, vous avez le droit",
    "en": "Under your ARCO rights in Mexico — access, rectification, cancellation, objection — and Article 8 of Law 1581 in Colombia, you have the right",
    "es": "En virtud de sus derechos ARCO en México — acceso, rectificación, cancelación, oposición — y del artículo 8 de la Ley 1581 en Colombia, usted tiene derecho",
}
_HI_ETENDU = {
    "fr": "qu'ils résident au Mexique ou en Colombie",
    "en": "whether you live in Mexico or Colombia",
    "es": "residan en México o en Colombia",
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
    },
    # ⚠ L'ESPAGNOL CHANGE DE VERBE : « Aquí son los Estados Unidos » devient « Aquí
    #   es Canadá ». Le remplacement porte donc la phrase entière, accord compris.
    ("k", "cgu"): {
        "fr": [(r"Ici,\s+c'est\s+{src_a}\.",  "Ici, c'est {dst_a}.")],
        "en": [(r"Here\s+it\s+is\s+{src_a}\.", "Here it is {dst_a}.")],
        "es": [(r"Aquí\s+son\s+{src_a}\.",    "Aquí es {dst_a}.")],
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
    pattern = re.compile(
        re.escape(src_market) + r"-([ak])-([a-z]{2,3})-([a-z0-9]+)-v\d+\.html"
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
