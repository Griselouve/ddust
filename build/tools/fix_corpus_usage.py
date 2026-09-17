#!/usr/bin/env python3
"""L'essai de 14 jours disparaît du corpus légal adulte. Édition EN PLACE.

Contexte : décision du 2026-09-16. Le modèle ne demande plus sa première cotisation
au bout d'un compte à rebours mais à un USAGE — trois tâches menées à leur terme
depuis que le clan compte au moins deux membres, dix s'il est resté seul —, sur
l'écran de validation d'une tâche, avec trois reports annoncés. L'offre Play
`essai-14j` est retirée du catalogue (build.yml de la suite).

Les CGU annonçaient un « essai gratuit de 14 jours » à quatre endroits de leur
article 2, et les politiques de confidentialité rangeaient la « fin de l'essai »
parmi les causes de blocage d'un clan. Les deux deviennent faux le jour où l'offre
part : un document contractuel qui décrit un service qui n'existe plus ne protège
personne, et se retourne contre l'éditeur au premier litige.

⚠ PAS DE BUMP DE VERSION, contrairement à `gen_cgu_next.py`. Les documents restent
  en **v1**, réécrits sur place, seule la date d'entrée en vigueur avançant au
  16 septembre 2026. L'application n'est pas publiée : conserver l'ancienne v1
  « comme preuve de ce qui a été accepté » n'aurait rien prouvé, personne n'ayant
  encore rien accepté hors du cercle de test. Une v2 aurait en outre déclenché un
  ré-acquittement (dvdocuments) chez des familles qui n'ont pas commencé à jouer, et
  laissé douze jeux de fichiers morts à relire à chaque révision suivante.

  Le jour où l'app sera en production, cette décision s'inverse : toute révision de
  fond passera par un bump, et c'est `gen_cgu_next.py` qui en porte la mécanique.

CE QUI EST TOUCHÉ, ET CE QUI NE L'EST PAS :

    *-a-*-cgu-v1.html      96 fichiers — article 2 (chapeau, puce d'accès initial,
                                        offre fondateurs, absence d'abonnement)
    *-a-*-privacy-v1.html  96 fichiers — la seule puce qui nommait l'essai

    *-k-*  (documents enfants)          INCHANGÉS, et c'est voulu : ils disent « un
                                        adulte de ton clan paie un abonnement », ce
                                        qui reste vrai. Les enfants ne voient aucune
                                        surface commerciale, ils n'ont pas à lire un
                                        seuil de conversion.

`pudocuments` retient la version `max` par tuple (région, état, langue, type), et le
numéro ne bouge pas : ce sont donc les MÊMES documents qui repartent au bucket, avec
un contenu neuf. Les liens du site vitrine ne bronchent pas non plus, ils portent le
jeton `@@@legal_version:...@@@` et non un numéro.

Chaque substitution est vérifiée : une occurrence attendue, sinon le script échoue.
Un document légal réécrit à moitié est pire que pas de document du tout. Les fragments
réécrits sont IDENTIQUES d'un marché à l'autre pour une même langue (seule la puce de
rétractation varie par marché, et on n'y touche pas) : c'est ce qui permet de traiter
les douze corpus avec un seul jeu de textes.

⚠ SCRIPT DÉJÀ JOUÉ. Il ne retrouve plus ses motifs et échoue désormais — c'est ainsi
  qu'on le sait joué, comme ses voisins `fix_corpus_fr.py` et `set_publisher_*.py`.
  Il reste ici parce qu'il EST la trace de ce qui a changé, et dans quel ordre.

    python tools/fix_corpus_usage.py            # écrit
    python tools/fix_corpus_usage.py --check    # vérifie sans écrire
"""

import re
import sys
import time
from pathlib import Path

DOCS = Path(__file__).parent.parent / "legal" / "documents"

LANGS = ("fr", "en", "es", "de", "it", "pt", "br", "nl")

# La ligne d'en-tête, après puis avant. Le NUMÉRO NE BOUGE PAS (cf. l'avertissement
# du docstring) : seule la date d'entrée en vigueur avance. Le séparateur « — » est
# celui du corpus, on ne change pas la mise en forme d'un document pour son contenu.
VERSION_NEW = {
    "fr": "1 — en vigueur au 16 septembre 2026",
    "en": "1 — in force as of 16 September 2026",
    "es": "1 — en vigor desde el 16 de septiembre de 2026",
    "de": "1 — in Kraft seit dem 16. September 2026",
    "it": "1 — in vigore dal 16 settembre 2026",
    "pt": "1 — em vigor desde 16 de setembro de 2026",
    "br": "1 — em vigor desde 16 de setembro de 2026",
    "nl": "1 — van kracht sinds 16 september 2026",
}

VERSION_OLD = {
    "fr": "1 — en vigueur au 28 août 2026",
    "en": "1 — in force as of 28 August 2026",
    "es": "1 — en vigor desde el 28 de agosto de 2026",
    "de": "1 — in Kraft seit dem 28. August 2026",
    "it": "1 — in vigore dal 28 agosto 2026",
    "pt": "1 — em vigor desde 28 de agosto de 2026",
    "br": "1 — em vigor desde 28 de agosto de 2026",
    "nl": "1 — van kracht sinds 28 augustus 2026",
}

# --- Article 2 : le chapeau -------------------------------------------------------
HEAD = {
    "fr": "<p>L'accès à l'Application est <strong>libre au départ</strong>, sans abonnement et sans limite de "
          "durée. Au-delà d'un certain usage, il repose sur un <strong>abonnement</strong>. Une "
          "<strong>boutique</strong> propose en outre des contenus achetables à l'unité. L'Application ne "
          "comporte <strong>aucune publicité</strong>.</p>",
    "en": "<p>Access to the Application is <strong>free at the outset</strong>, with no subscription and no time "
          "limit. Beyond a certain amount of use, it is based on a <strong>subscription</strong>. A "
          "<strong>shop</strong> also offers content available for one-off purchase. The Application contains "
          "<strong>no advertising</strong>.</p>",
    "es": "<p>El acceso a la Aplicación es <strong>libre al principio</strong>, sin suscripción y sin límite de "
          "tiempo. Más allá de cierto uso, se basa en una <strong>suscripción</strong>. Además, una "
          "<strong>tienda</strong> ofrece contenidos que pueden adquirirse por unidad. La Aplicación no incluye "
          "<strong>ninguna publicidad</strong>.</p>",
    "de": "<p>Der Zugang zur Anwendung ist <strong>zu Beginn frei</strong>, ohne Abonnement und ohne zeitliche "
          "Begrenzung. Ab einer gewissen Nutzung beruht er auf einem <strong>Abonnement</strong>. Ein "
          "<strong>Laden</strong> bietet darüber hinaus einzeln erwerbbare Inhalte an. Die Anwendung enthält "
          "<strong>keinerlei Werbung</strong>.</p>",
    "it": "<p>L'accesso all'Applicazione è <strong>libero all'inizio</strong>, senza abbonamento e senza limiti "
          "di tempo. Oltre un certo utilizzo, si basa su un <strong>abbonamento</strong>. Una "
          "<strong>bottega</strong> propone inoltre contenuti acquistabili singolarmente. L'Applicazione non "
          "contiene <strong>alcuna pubblicità</strong>.</p>",
    "pt": "<p>O acesso à Aplicação é <strong>livre no início</strong>, sem subscrição e sem limite de tempo. A "
          "partir de certa utilização, assenta numa <strong>subscrição</strong>. Uma <strong>loja</strong> "
          "propõe ainda conteúdos adquiríveis à unidade. A Aplicação não contém <strong>qualquer "
          "publicidade</strong>.</p>",
    "br": "<p>O acesso ao Aplicativo é <strong>livre no início</strong>, sem assinatura e sem limite de tempo. A "
          "partir de certo uso, ele se baseia em uma <strong>assinatura</strong>. Uma <strong>loja</strong> "
          "oferece ainda conteúdos que podem ser comprados avulsos. O Aplicativo não contém <strong>nenhuma "
          "publicidade</strong>.</p>",
    "nl": "<p>De toegang tot de Applicatie is <strong>in het begin vrij</strong>, zonder abonnement en zonder "
          "tijdslimiet. Vanaf een bepaald gebruik berust zij op een <strong>abonnement</strong>. Een "
          "<strong>winkel</strong> biedt daarnaast per stuk te kopen inhoud aan. De Applicatie bevat <strong>geen "
          "enkele reclame</strong>.</p>",
}

# --- Article 2, première puce : ce qui remplace « Essai gratuit » -----------------
# Les deux seuils y sont ÉCRITS. Un contrat qui dirait « après un certain usage »
# sans le chiffrer laisserait l'éditeur libre de déplacer la porte après coup, ce
# qui est exactement ce contre quoi un engagement contractuel existe. Les reports
# aussi : ils sont une promesse, pas une tolérance.
FIRST = {
    "fr": "<li><strong>Accès initial sans abonnement</strong> — le jeu s'utilise gratuitement, sans restriction "
          "de fonctionnalité et sans limite de durée, jusqu'à ce que le clan ait mené à leur terme un petit "
          "nombre de tâches : trois depuis qu'il compte au moins deux membres, ou dix s'il est resté à un seul "
          "membre. Aucune durée calendaire ne court : un clan qui ne joue pas ne consomme rien. Au-delà, "
          "l'abonnement est demandé à un adulte administrateur du clan au moment où il valide une tâche ; cette "
          "demande peut être reportée trois fois, et le nombre de reports restants est affiché.</li>",
    "en": "<li><strong>Initial access without a subscription</strong> — the game may be used free of charge, with "
          "no restriction on features and no time limit, until the clan has seen a small number of chores "
          "through to the end: three since it has had at least two members, or ten if it has remained a single "
          "member. No calendar period runs: a clan that does not play uses nothing up. Beyond that, the "
          "subscription is asked of an adult administrator of the clan at the moment they validate a chore; that "
          "request may be postponed three times, and the number of remaining postponements is displayed.</li>",
    "es": "<li><strong>Acceso inicial sin suscripción</strong> — el juego se usa gratuitamente, sin restricción "
          "de funcionalidades y sin límite de tiempo, hasta que el clan haya llevado a término un pequeño número "
          "de tareas: tres desde que cuenta con al menos dos miembros, o diez si ha permanecido con un solo "
          "miembro. No corre ningún plazo de calendario: un clan que no juega no consume nada. Más allá, la "
          "suscripción se pide a un adulto administrador del clan en el momento en que valida una tarea; esa "
          "petición puede aplazarse tres veces, y se muestra el número de aplazamientos restantes.</li>",
    "de": "<li><strong>Anfänglicher Zugang ohne Abonnement</strong> — das Spiel kann kostenlos genutzt werden, "
          "ohne Funktionseinschränkung und ohne zeitliche Begrenzung, bis der Clan eine kleine Zahl von Aufgaben "
          "zu Ende gebracht hat: drei, seit er mindestens zwei Mitglieder hat, oder zehn, wenn er ein einziges "
          "Mitglied geblieben ist. Es läuft keine Kalenderfrist: Ein Clan, der nicht spielt, verbraucht nichts. "
          "Darüber hinaus wird das Abonnement von einem erwachsenen Administrator des Clans in dem Moment "
          "verlangt, in dem er eine Aufgabe bestätigt; diese Aufforderung kann dreimal aufgeschoben werden, und "
          "die Zahl der verbleibenden Aufschübe wird angezeigt.</li>",
    "it": "<li><strong>Accesso iniziale senza abbonamento</strong> — il gioco si usa gratuitamente, senza "
          "limitazioni di funzionalità e senza limiti di tempo, finché il clan non ha portato a termine un "
          "piccolo numero di compiti: tre da quando conta almeno due membri, oppure dieci se è rimasto con un "
          "solo membro. Non decorre alcun termine di calendario: un clan che non gioca non consuma nulla. Oltre "
          "tale soglia, l'abbonamento è chiesto a un adulto amministratore del clan nel momento in cui convalida "
          "un compito; questa richiesta può essere rinviata tre volte, e il numero di rinvii restanti è "
          "visualizzato.</li>",
    "pt": "<li><strong>Acesso inicial sem subscrição</strong> — o jogo utiliza-se gratuitamente, sem restrição de "
          "funcionalidades e sem limite de tempo, até que o clã tenha levado a bom termo um pequeno número de "
          "tarefas: três desde que conta com pelo menos dois membros, ou dez se permaneceu com um só membro. Não "
          "corre nenhum prazo de calendário: um clã que não joga não consome nada. A partir daí, a subscrição é "
          "pedida a um adulto administrador do clã no momento em que valida uma tarefa; esse pedido pode ser "
          "adiado três vezes, e o número de adiamentos restantes é apresentado.</li>",
    "br": "<li><strong>Acesso inicial sem assinatura</strong>: o jogo é usado gratuitamente, sem restrição de "
          "funcionalidades e sem limite de tempo, até que o clã tenha levado até o fim um pequeno número de "
          "tarefas: três desde que tem pelo menos dois membros, ou dez se continuou com um só membro. Nenhum "
          "prazo de calendário corre: um clã que não joga não consome nada. A partir daí, a assinatura é pedida "
          "a um adulto administrador do clã no momento em que ele valida uma tarefa; esse pedido pode ser adiado "
          "três vezes, e o número de adiamentos restantes é exibido.</li>",
    "nl": "<li><strong>Aanvankelijke toegang zonder abonnement</strong> — het spel kan gratis worden gebruikt, "
          "zonder functionele beperking en zonder tijdslimiet, totdat de clan een klein aantal klussen tot een "
          "goed einde heeft gebracht: drie sinds hij ten minste twee leden telt, of tien als hij één lid is "
          "gebleven. Er loopt geen enkele kalendertermijn: een clan die niet speelt verbruikt niets. Daarna "
          "wordt het abonnement gevraagd aan een volwassen beheerder van de clan op het ogenblik waarop hij een "
          "klus goedkeurt; dat verzoek kan drie keer worden uitgesteld, en het aantal resterende uitstellen "
          "wordt getoond.</li>",
}

# --- Article 2, offre fondateurs : ce qui tient entre les parenthèses -------------
# Elle promettait un « essai allongé ». Il n'y a plus d'essai à allonger : ce que
# l'offre donne réellement est un mois offert, puis la remise sur la première année.
FOUNDER = {
    "fr": "un mois offert puis tarif réduit sur la première année",
    "en": "one free month and then a reduced price for the first year",
    "es": "un mes gratis y después precio reducido el primer año",
    "de": "ein Gratismonat und danach ein ermäßigter Tarif im ersten Jahr",
    "it": "un mese offerto e poi tariffa ridotta sul primo anno",
    "pt": "um mês oferecido e depois tarifa reduzida no primeiro ano",
    "br": "um mês de presente e depois preço reduzido no primeiro ano",
    "nl": "een gratis maand en daarna een verlaagd tarief in het eerste jaar",
}

# --- Article 2, absence d'abonnement actif ---------------------------------------
# La doctrine y est écrite noir sur blanc, parce qu'elle fait une différence de
# traitement entre deux familles : on fait crédit à qui a déjà payé (calendrier de
# défaut de paiement, cinquante jours), pas à qui n'a jamais payé (trois reports).
# Une différence de traitement qu'un contrat tait est une différence qu'on ne peut
# pas opposer.
#
# Ce qui N'EST PLUS PROMIS ici : la suppression automatique deux ans après le
# blocage pour un clan qui n'a jamais souscrit. Le balayage serveur compte à partir
# du premier impayé, et un clan sans achat n'a aucun document de facturation : la
# promesse n'aurait été tenue par personne. Elle reste, pour les clans qui ont
# souscrit, dans le calendrier de défaut de paiement juste en dessous.
NOSUB = {
    "fr": "<li><strong>Absence d'abonnement actif</strong> — au-delà de l'accès initial, après résiliation ou à "
          "la fin des mois offerts, le clan est bloqué : jouer demande alors un abonnement actif. Pour un clan "
          "qui n'a jamais souscrit, le blocage intervient une fois les trois reports épuisés. Pour un clan qui a "
          "souscrit, il suit le calendrier de défaut de paiement ci-dessous. Dans les deux cas, les données du "
          "clan et de ses membres restent intégralement conservées et redeviennent accessibles si vous "
          "souscrivez, et vous pouvez à tout moment demander la suppression de votre compte et de votre clan "
          "(article 11).</li>",
    "en": "<li><strong>No active subscription</strong> — beyond the initial access, after cancellation or when "
          "the free months run out, the clan is locked: playing then requires an active subscription. For a clan "
          "that has never subscribed, the lock comes once the three postponements are used up. For a clan that "
          "has subscribed, it follows the payment failure timetable below. In both cases the data of the clan "
          "and its members is kept in full and becomes accessible again if you subscribe, and you may ask for "
          "your account and your clan to be deleted at any time (section 11).</li>",
    "es": "<li><strong>Sin suscripción activa</strong> — más allá del acceso inicial, tras la cancelación o al "
          "agotarse los meses regalados, el clan queda bloqueado: para jugar se necesita entonces una "
          "suscripción activa. Para un clan que nunca se ha suscrito, el bloqueo llega una vez agotados los tres "
          "aplazamientos. Para un clan que sí se ha suscrito, sigue el calendario de impago que figura a "
          "continuación. En ambos casos los datos del clan y de sus miembros se conservan íntegramente y vuelven "
          "a ser accesibles si te suscribes, y puedes solicitar en cualquier momento la supresión de tu cuenta y "
          "de tu clan (artículo 11).</li>",
    "de": "<li><strong>Kein aktives Abonnement</strong> — über den anfänglichen Zugang hinaus, nach der "
          "Kündigung oder wenn die geschenkten Monate aufgebraucht sind, wird der Clan gesperrt: Zum Spielen ist "
          "dann ein aktives Abonnement erforderlich. Bei einem Clan, der nie abonniert hat, erfolgt die Sperrung, "
          "sobald die drei Aufschübe aufgebraucht sind. Bei einem Clan, der abonniert hat, folgt sie dem "
          "Zeitplan bei Zahlungsverzug weiter unten. In beiden Fällen bleiben die Daten des Clans und seiner "
          "Mitglieder vollständig erhalten und werden wieder zugänglich, wenn Sie ein Abonnement abschließen, "
          "und Sie können jederzeit die Löschung Ihres Kontos und Ihres Clans verlangen (Artikel 11).</li>",
    "it": "<li><strong>Assenza di abbonamento attivo</strong> — oltre l'accesso iniziale, dopo la disdetta o "
          "all'esaurimento dei mesi offerti, il clan è bloccato: per giocare serve allora un abbonamento attivo. "
          "Per un clan che non ha mai sottoscritto, il blocco interviene una volta esauriti i tre rinvii. Per un "
          "clan che ha sottoscritto, segue il calendario per mancato pagamento qui sotto. In entrambi i casi i "
          "dati del clan e dei suoi membri restano integralmente conservati e tornano accessibili se vi "
          "abbonate, e potete chiedere in qualsiasi momento la cancellazione del vostro account e del vostro "
          "clan (articolo 11).</li>",
    "pt": "<li><strong>Ausência de subscrição ativa</strong> — para além do acesso inicial, após cancelamento ou "
          "quando os meses oferecidos se esgotam, o clã fica bloqueado: para jogar é então necessária uma "
          "subscrição ativa. Para um clã que nunca subscreveu, o bloqueio ocorre depois de esgotados os três "
          "adiamentos. Para um clã que subscreveu, segue o calendário de incumprimento de pagamento abaixo. Em "
          "ambos os casos os dados do clã e dos seus membros são integralmente conservados e voltam a ficar "
          "acessíveis se subscrever, e pode a qualquer momento pedir a supressão da sua conta e do seu clã "
          "(artigo 11).</li>",
    "br": "<li><strong>Ausência de assinatura ativa</strong>: além do acesso inicial, após o cancelamento ou "
          "quando os meses oferecidos acabam, o clã fica bloqueado: para jogar é então necessária uma assinatura "
          "ativa. Para um clã que nunca assinou, o bloqueio ocorre depois de esgotados os três adiamentos. Para "
          "um clã que assinou, ele segue o calendário de inadimplência descrito abaixo. Nos dois casos os dados "
          "do clã e dos seus membros são integralmente conservados e voltam a ficar acessíveis se você assinar, "
          "e você pode a qualquer momento pedir a exclusão da sua conta e do seu clã (artigo 11).</li>",
    "nl": "<li><strong>Geen actief abonnement</strong> — na de aanvankelijke toegang, na opzegging of wanneer de "
          "geschonken maanden op zijn, wordt de clan geblokkeerd: om te spelen is dan een actief abonnement "
          "nodig. Voor een clan die zich nooit heeft geabonneerd, volgt de blokkering zodra de drie uitstellen "
          "op zijn. Voor een clan die zich wel heeft geabonneerd, volgt zij het hieronder beschreven schema bij "
          "wanbetaling. In beide gevallen blijven de gegevens van de clan en zijn leden volledig bewaard en "
          "worden zij opnieuw toegankelijk als u zich abonneert, en u kunt op elk moment vragen om uw account en "
          "uw clan te verwijderen (artikel 11).</li>",
}

# --- Politique de confidentialité : la puce du clan bloqué ------------------------
# Seule la parenthèse change : la cause « fin de l'essai » n'existe plus. On ne
# touche NI à la durée de deux ans, NI au point de départ (le blocage), qui restent
# ceux d'un clan ayant souscrit — les seuls que le balayage serveur sache traiter.
PRIVACY_OLD = {
    "fr": "(impayé, résiliation, fin de l'essai ou des mois offerts)",
    "en": "(payment failure, cancellation, end of the trial or of the free months)",
    "es": "(impago, cancelación, fin de la prueba o de los meses regalados)",
    "de": "(Zahlungsverzug, Kündigung, Ende der Testphase oder der geschenkten Monate)",
    "it": "(mancato pagamento, disdetta, fine della prova o dei mesi offerti)",
    "pt": "(incumprimento de pagamento, cancelamento, fim do período experimental ou dos meses oferecidos)",
    "br": "(inadimplência, cancelamento, fim do período de teste ou dos meses oferecidos)",
    "nl": "(wanbetaling, opzegging, einde van de proefperiode of van de geschonken maanden)",
}
PRIVACY_NEW = {
    "fr": "(impayé, résiliation ou fin des mois offerts)",
    "en": "(payment failure, cancellation or end of the free months)",
    "es": "(impago, cancelación o fin de los meses regalados)",
    "de": "(Zahlungsverzug, Kündigung oder Ende der geschenkten Monate)",
    "it": "(mancato pagamento, disdetta o fine dei mesi offerti)",
    "pt": "(incumprimento de pagamento, cancelamento ou fim dos meses oferecidos)",
    "br": "(inadimplência, cancelamento ou fim dos meses oferecidos)",
    "nl": "(wanbetaling, opzegging of einde van de geschonken maanden)",
}


def _fail(msg):
    print("ECHEC : " + msg)
    sys.exit(1)


def _sub_once(src, old, new, what, path):
    """Une substitution = une occurrence attendue. Sinon on s'arrête."""
    n = src.count(old)
    if n != 1:
        _fail(f"{path.name} : {what} — {n} occurrence(s) au lieu d'une.")
    return src.replace(old, new, 1)


def _article2(src, path):
    """Bornes de l'article 2 (du titre 2 au titre 3), où tout se joue."""
    i = src.find("<h2>2.")
    j = src.find("<h2>3.")
    if i < 0 or j <= i:
        _fail(f"{path.name} : article 2 introuvable.")
    return src[i:j]


def do_cgu(path, lang):
    src = path.read_text(encoding="utf-8")
    sec = _article2(src, path)

    ps = re.findall(r"<p>.*?</p>", sec, re.S)
    lis = re.findall(r"<li>.*?</li>", sec, re.S)
    if len(ps) < 2 or len(lis) < 9:
        _fail(f"{path.name} : article 2 inattendu ({len(ps)} <p>, {len(lis)} <li>).")

    head, first, founder, nosub = ps[1], lis[0], lis[3], lis[8]

    # Garde-fous : on vérifie qu'on a bien attrapé les bons fragments AVANT d'écrire.
    # Un corpus qui aurait bougé d'une puce se ferait sinon réécrire de travers.
    if "14" not in head or "14" not in first:
        _fail(f"{path.name} : le chapeau ou la première puce ne parlent pas de l'essai.")
    if "(" not in founder or ")" not in founder:
        _fail(f"{path.name} : l'offre fondateurs n'a pas sa parenthèse.")
    if "11" not in nosub:
        _fail(f"{path.name} : la puce d'absence d'abonnement ne renvoie pas à l'article 11.")

    src = _sub_once(src, head,  HEAD[lang],  "chapeau de l'article 2", path)
    src = _sub_once(src, first, FIRST[lang], "puce d'essai gratuit", path)
    src = _sub_once(src, founder,
                    re.sub(r"\([^)]*\)", "(" + FOUNDER[lang] + ")", founder, count=1),
                    "offre fondateurs", path)
    src = _sub_once(src, nosub, NOSUB[lang], "absence d'abonnement actif", path)
    src = _sub_once(src, VERSION_OLD[lang], VERSION_NEW[lang], "ligne de version", path)
    return src


def do_privacy(path, lang):
    src = path.read_text(encoding="utf-8")
    src = _sub_once(src, PRIVACY_OLD[lang], PRIVACY_NEW[lang], "causes de blocage", path)
    src = _sub_once(src, VERSION_OLD[lang], VERSION_NEW[lang], "ligne de version", path)
    return src


def main():
    check = "--check" in sys.argv
    ecrits = 0

    for path in sorted(DOCS.glob("*-a-*-v1.html")):
        parts = path.name.split("-")
        lang, kind = parts[2], parts[3]
        if lang not in LANGS or kind not in ("cgu", "privacy"):
            continue

        src = do_cgu(path, lang) if kind == "cgu" else do_privacy(path, lang)

        if check:
            print(f"  ok  {path.name}")
        else:
            # Écriture avec reprise : sur ce poste, un fichier fraîchement lu se voit
            # parfois refuser l'ouverture en écriture pendant quelques dixièmes de
            # seconde (indexation). Abandonner au 40e document sur 192 laisserait le
            # corpus à moitié réécrit, ce qui est exactement ce qu'on refuse.
            for _ in range(6):
                try:
                    path.write_text(src, encoding="utf-8", newline="")
                    break
                except OSError:
                    time.sleep(0.3)
            else:
                _fail(f"{path.name} : écriture impossible.")
            print(f"  reecrit  {path.name}")
        ecrits += 1

    print(f"\n{ecrits} document(s) {'verifie(s)' if check else 'reecrit(s)'} en place.")


if __name__ == "__main__":
    main()
