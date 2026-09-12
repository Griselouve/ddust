#!/usr/bin/env python3
"""Désigne nommément le médiateur de la consommation, dans le corpus et sur le site.

Joué le 2026-09-09, le jour où l'adhésion a été souscrite. C'est le rendez-vous que
`fix_corpus_fr.py` s'était donné à lui-même le 2026-08-28, en purgeant la clause de
la plateforme européenne de règlement en ligne des litiges — fermée le 20/07/2025 —
et en écrivant dans sa propre docstring :

    « L'article L612-1 du code de la consommation impose de désigner NOMMÉMENT un
      médiateur de la consommation. Aucun n'est souscrit à ce jour, et un script
      n'a pas à en inventer un. La mention reste à ajouter le jour où l'adhésion
      est prise. »

⚠ POURQUOI C'EST DÛ. L'article L616-1 ne connaît AUCUN seuil d'effectif ni de
  chiffre d'affaires : dès lors qu'on agit « à des fins entrant dans le cadre de
  son activité commerciale » (art. liminaire), on doit adhérer à un médiateur et
  le nommer. Le défaut d'information est puni d'une amende administrative jusqu'à
  3 000 €. Le fait que Google Play soit le VENDEUR ne délègue rien : les CGU
  restent un contrat de SERVICE entre l'éditeur et le joueur — clan supprimé,
  données, service indisponible — et c'est à ce contrat-là que le médiateur
  s'attache. Le litige de PAIEMENT, lui, va bien chez Google, et le §2 le dit déjà.

  Médiateur retenu : CM2C, association loi 1901 référencée par la CECMC, adhésion
  souscrite au secteur B01 (vente en ligne, vente à distance), effectif 0.
  Le texte français ci-dessous est celui que CM2C fournit : il n'est PAS reformulé.

⚠ AUCUN BUMP DE VERSION, et ce n'est pas l'arbitrage des passages d'identité.
  Ceux-là ne bumpaient pas parce qu'ils ne changeaient pas le fond. Celui-ci ouvre
  un recours, donc touche au fond — et se pose quand même en `v1`, pour une raison
  qui lui est propre : L'APPLICATION N'A JAMAIS ÉTÉ PUBLIÉE. Personne n'a accepté
  ces documents. Bumper créerait un flux de ré-acceptation pour des utilisateurs
  qui n'existent pas, et invaliderait l'URL versionnée déjà déposée en Play
  Console. Le jour où un joueur réel aura accepté une version, la règle s'inverse :
  un ajout de cette nature passera par `gen_cgu_next.py`.

⚠ CE QUI N'EST PAS FAIT, ET POURQUOI :
    - LA SOUCHE `us` (us, ca, oceanie, bresil, hispam) — son §12 est un autre
      texte, en deux paragraphes, qui renvoie aux autorités locales (FTC et
      procureur général, CPVP et CAI, ANPD et Procon, PROFECO et SIC, OAIC).
      Ni L616-1 ni la directive 2013/11 ne l'atteignent. Offrir un médiateur
      français à un joueur brésilien n'est pas illégal : c'est trompeur sur la
      voie de recours réellement praticable ;
    - LES DOCUMENTS ENFANTS (`-k-`) — règle constante du corpus, et
      `check_corpus.py` exige zéro mention d'éditeur dans ceux-là. Le
      consommateur qui peut saisir le médiateur est le tuteur, qui lit le
      document adulte ;
    - LES POLITIQUES DE CONFIDENTIALITÉ — leur §11 « Réclamation » vise l'autorité
      de contrôle (CNIL et homologues). La médiation de la consommation relève du
      contrat, pas du traitement de données. Mélanger les deux recours est la
      faute que ce corpus évite depuis le début ;
    - LE SITE `grisloup.com` — il porte la même clause, mais son patron est
      l'inverse de celui-ci : sept pages vides remplies au chargement depuis un
      objet unique de `assets/site.js`. Il se traite là-bas, en un seul endroit,
      pas par substitution HTML.

⚠ OÙ ÇA S'INSÈRE. Le §12 « Droit applicable et réclamations » est un unique `<p>`,
  immédiatement suivi de `<h2>13. Modification…</h2>`. La clause devient un SECOND
  `<p>` entre les deux. Elle ne crée pas de section numérotée : les documents
  adultes portent des renvois internes (« article 8 », « article 12 ») que toute
  renumérotation casserait en silence.

  L'ancre est la dernière phrase du §12 — celle que `fix_corpus_fr.py` a posée en
  remplacement de l'ODR. Elle est IDENTIQUE dans les sept marchés de la souche
  pour une langue donnée : les blocs de marché (`eun` Lugano, `uk` Consumer Rights
  Act, `ch` droit suisse) réécrivent le MILIEU du paragraphe, jamais sa fin.
  Vérifié sur les 49 fichiers avant écriture. C'est aussi ce qui garantit qu'une
  future `derive_market_corpus.py` continuera de s'appliquer : ses ancres à elle
  sont intactes, et la clause voyagera avec la souche vers les marchés dérivés.

    python tools/set_consumer_mediation.py            # écrit
    python tools/set_consumer_mediation.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE, même contrat que ses aînés : une substitution qui ne
  trouve pas EXACTEMENT une occurrence est une erreur, jamais un silence. Rejouer
  doit échouer — c'est ainsi qu'on le sait joué.
"""

import re
import sys
from pathlib import Path

BUILD = Path(__file__).parent.parent
DOCS = BUILD / "legal" / "documents"
SITE = BUILD / "hosting" / "web"

# Souche `fr` seulement. La souche `us` est hors champ, cf. docstring.
MARCHES = ("fr", "euo", "eus", "eun", "eux", "uk", "ch")

# ⚠ SEPT LANGUES DEPUIS LE 2026-09-08. Les `set_publisher_*.py` de septembre
#   portent encore ("fr","en","es") : les recopier raterait it/de/pt/nl, et en
#   silence pour celles-là.
LANGS = ("fr", "en", "es", "it", "de", "pt", "nl")

# ── Coordonnées : elles ne se traduisent PAS ─────────────────────────────────
# Une désignation de médiateur n'est pas de la prose. Le nom, l'adresse, l'URL et
# l'adresse électronique sont recopiés à l'identique dans les sept langues ; seuls
# les libellés qui les introduisent suivent la langue du document.
# Seule adaptation de fond : le téléphone passe en format international hors du
# document français — un lecteur néerlandais ne peut pas composer « 01 89 47 00 14 ».
CM2C_NOM = "CM2C"
CM2C_RUE = "49 rue de Ponthieu"
CM2C_VILLE = "75 008 PARIS"
CM2C_TEL_FR = "01 89 47 00 14"
CM2C_TEL_INTL = "+33 1 89 47 00 14"
CM2C_URL = "https://www.cm2c.net/declarer-un-litige.php"
CM2C_URL_TEXTE = "www.cm2c.net/declarer-un-litige.php"
CM2C_MAIL = "litiges@cm2c.net"

# Phrase d'introduction. Le français est le texte fourni par CM2C, mot pour mot.
# Les six autres sont des traductions calées sur le registre du document existant
# (vouvoiement `Sie`/`U`/`Usted`, forme `voi` en italien, `você` implicite en
# portugais) et sur ses guillemets : « … » partout, «…» sans espaces en espagnol,
# aucun en anglais où la phrase se passe de citation.
INTRO = {
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

# Libellés des trois dernières lignes du bloc de coordonnées.
LIBELLES = {
    "fr": ("Tel :", "Site internet :", "Mail :"),
    "en": ("Tel:", "Website:", "Email:"),
    "es": ("Tel.:", "Sitio web:", "Correo electrónico:"),
    "it": ("Tel.:", "Sito web:", "E-mail:"),
    "de": ("Tel.:", "Website:", "E-Mail:"),
    "pt": ("Tel.:", "Sítio web:", "E-mail:"),
    "nl": ("Tel.:", "Website:", "E-mail:"),
}

# Titre de la section sur les pages du site. Les documents légaux, eux, n'en
# portent pas : la clause y reste dans le §12 existant.
TITRE_SITE = {
    "fr": "Médiation de la consommation",
    "en": "Consumer mediation",
    "es": "Mediación de consumo",
    "it": "Mediazione del consumo",
    "de": "Verbrauchermediation",
    "pt": "Mediação de consumo",
    "nl": "Consumentenbemiddeling",
}

# ── Ancres ───────────────────────────────────────────────────────────────────
# Dernière phrase du §12 des CGU, relevée sur disque et vérifiée à une occurrence
# dans chacun des 49 fichiers. Identique d'un marché à l'autre pour une langue.
ANCRE_CGU = {
    "fr": "Vous conservez en tout état de cause le droit de saisir la juridiction compétente de votre lieu de "
          "résidence.</p>",
    "en": "You retain in any event the right to bring proceedings before the competent court of your place of "
          "residence.</p>",
    "es": "Usted conserva en todo caso el derecho de acudir al órgano jurisdiccional competente de su lugar de "
          "residencia.</p>",
    "it": "Conservate in ogni caso il diritto di adire l'autorità giudiziaria competente del vostro luogo di "
          "residenza.</p>",
    "de": "Sie behalten in jedem Fall das Recht, das zuständige Gericht Ihres Wohnorts anzurufen.</p>",
    "pt": "Conserva em qualquer caso o direito de recorrer ao tribunal competente do seu local de "
          "residência.</p>",
    "nl": "U behoudt in elk geval het recht om de bevoegde rechtbank van uw woonplaats aan te spreken.</p>",
}

# Fin du bloc « Éditeur » des pages `legal/` du site ddust — dernier bloc avant
# `</main>`. La clause s'y ajoute en section à part entière : R616-1 veut une
# information « visible et lisible », ce qu'un titre sert mieux qu'un paragraphe
# noyé en fin de mentions légales.
ANCRE_SITE = {
    "fr": "(Google Ireland Ltd), seule région ouverte à ce jour.</p>",
    "en": "(Google Ireland Ltd), the only region open so far.</p>",
    "es": "(Google Ireland Ltd), única región abierta hasta la fecha.</p>",
    "it": "(Google Ireland Ltd), unica regione aperta a oggi.</p>",
    "de": "(Google Ireland Ltd), der einzigen bislang offenen Region.</p>",
    "pt": "(Google Ireland Ltd), única região aberta até à data.</p>",
    "nl": "(Google Ireland Ltd), de enige tot op heden open regio.</p>",
}


def _as_pattern(literal):
    """Libellé littéral -> motif tolérant le retour à la ligne du source HTML.

    Le corpus est enregistré en lignes courtes : « de votre lieu de / résidence »
    coupé en deux est le cas normal, pas l'exception.
    """
    return r"\s+".join(re.escape(w) for w in literal.split())


def _coordonnees(lang, indent):
    """Les six lignes de coordonnées, séparées par des `<br>`."""
    tel_label, site_label, mail_label = LIBELLES[lang]
    tel = CM2C_TEL_FR if lang == "fr" else CM2C_TEL_INTL
    lignes = [
        CM2C_NOM,
        CM2C_RUE,
        CM2C_VILLE,
        "%s %s" % (tel_label, tel),
        '%s <a href="%s">%s</a>' % (site_label, CM2C_URL, CM2C_URL_TEXTE),
        '%s <a href="mailto:%s">%s</a>' % (mail_label, CM2C_MAIL, CM2C_MAIL),
    ]
    return ("<br>\n" + indent).join(lignes)


def _clause_cgu(lang):
    return "\n<p>%s<br>\n%s</p>" % (INTRO[lang], _coordonnees(lang, ""))


def _bloc_site(lang):
    return ("\n\n    <h2>%s</h2>\n    <p>%s<br>\n    %s</p>"
            % (TITRE_SITE[lang], INTRO[lang], _coordonnees(lang, "    ")))


def _cibles():
    """(chemin, ancre, ajout) pour chaque fichier à traiter."""
    for marche in MARCHES:
        for lang in LANGS:
            yield (DOCS / ("%s-a-%s-cgu-v1.html" % (marche, lang)),
                   ANCRE_CGU[lang], _clause_cgu(lang))
    for lang in LANGS:
        yield (SITE / lang / "legal" / "index.html",
               ANCRE_SITE[lang], _bloc_site(lang))


def main():
    check = "--check" in sys.argv
    n_docs = n_site = 0

    for path, ancre, ajout in _cibles():
        if not path.exists():
            raise SystemExit("introuvable : %s" % path)
        text = path.read_text(encoding="utf-8")

        # ⚠ GARDE-FOU DU CARACTÈRE ONE-SHOT, ET IL NE VA PAS DE SOI ICI.
        #   Chez ses aînés, l'ancre était CONSOMMÉE par la substitution : rejouer
        #   ne la retrouvait pas et le script échouait tout seul. Ici l'ancre est
        #   conservée — on ajoute derrière elle — donc un second passage la
        #   retrouverait intacte et poserait la clause UNE SECONDE FOIS, sans
        #   rien signaler. Le nom du médiateur sert donc de témoin : présent, le
        #   travail est déjà fait, et c'est une erreur de le refaire.
        if CM2C_NOM in text:
            raise SystemExit(
                "[%s] « %s » est deja present : script deja joue." % (path.name, CM2C_NOM))

        # L'ancre est CONSERVÉE : on ajoute derrière, on ne remplace pas. Le droit
        # de saisir le juge reste dû, la médiation s'y ajoute — elle ne s'y
        # substitue pas, et une clause qui priverait du juge serait abusive.
        remplacement = (ancre + ajout).replace("\\", "\\\\")
        text, hits = re.subn(_as_pattern(ancre), remplacement, text)
        if hits != 1:
            raise SystemExit(
                "[%s] ancre : %d occurrence(s), 1 attendue." % (path.name, hits))

        if not check:
            path.write_text(text, encoding="utf-8")
        if path.parent == DOCS:
            n_docs += 1
        else:
            n_site += 1

    verb = "verifie(s)" if check else "ecrit(s)"
    print("%d fichier(s) %s - %d CGU adultes (%d marches x %d langues)"
          " + %d pages du site."
          % (n_docs + n_site, verb, n_docs, len(MARCHES), len(LANGS), n_site))
    print("  CM2C, 49 rue de Ponthieu, 75008 Paris - adhesion secteur B01.")
    print("  Souche us, documents enfants et politiques de confidentialite :"
          " hors champ, cf. docstring.")
    print("  Site grisloup.com : a traiter dans assets/site.js, patron different.")


if __name__ == "__main__":
    main()
