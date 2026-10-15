# FICHIER GÉNÉRÉ, Ne pas modifier, sera écrasé au prochain build
# Source: resources/base/dvutils/dvutils.py
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
# along with this program.  If not, see <https:#www.gnu.org/licenses/>.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# --- Dependencies
# -----------------------------------------------------------------------------

import base64
import hashlib
import os, time
import pathlib
import re
import shutil
import ssl
import subprocess
import sys
import tempfile
import threading
import zipfile

from modules.dvcore.deva import *
from modules.dvcore.dvidle import *

deva.load_py_module("urllib3")

sslunsecure = ssl._create_unverified_context()
import urllib

import urllib3

urllib3.disable_warnings()


try:
    import colorama

    colorama.init()
except:
    pass

# Au-dela, une valeur est consideree illisible et tronquee dans les diffs.
DIFF_MAX_LEN = 80

# Toolchain binaries/ : versions epinglees pour que deux postes installes a des
# dates differentes restent identiques. Alignees sur les postes de build existants.
JDK_VERSION = "21.0.8"
DART_VERSION = "3.12.2"
FLUTTER_VERSION = "3.44.8"  # embarque Dart 3.12.2
# 3.263.0 et 9.36.1 depuis le 2026-09-18 : l'arret intermittent
# « pulumi-resource-gcp.exe exited prematurely » est un faux positif connu
# (pulumi#18238), et les versions recentes durcissent la detection de plugin mort
# ainsi que le chargement d'un plugin demande par un autre (3.262).
PULUMI_VERSION = "3.263.0"
PULUMI_GCP_VERSION = "9.36.1"
ANDROID_CLI_BUILD = "15859902"  # cmdline-tools;latest
ANDROID_NDK = "28.2.13676358"  # r28c, le seul NDK reellement utilise
ANDROID_PLATFORM = "36"
ANDROID_BUILDTOOLS = "36.0.0"

JDK_URL = (
    "https://aka.ms/download-jdk/microsoft-jdk-" + JDK_VERSION + "-windows-x64.zip"
)
DART_URL = (
    "https://storage.googleapis.com/dart-archive/channels/stable/release/"
    + DART_VERSION
    + "/sdk/dartsdk-windows-x64-release.zip"
)
FLUTTER_URL = (
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/"
    "flutter_windows_" + FLUTTER_VERSION + "-stable.zip"
)
PULUMI_URL = (
    "https://get.pulumi.com/releases/sdk/pulumi-v" + PULUMI_VERSION + "-windows-x64.zip"
)
# requirements.txt genere dans chaque workspace Pulumi. Epingle au meme titre que
# la toolchain binaries/ : le state Pulumi memorise la version du provider qui l'a
# ecrit, et un provider plus recent rejoue un update a vide sur toute ressource dont
# le schema a gagne un champ depuis (ex: deletionPolicy sur gcp:projects/service:Service
# entre 9.15.0 et 9.32.1). Deux postes installes a des dates differentes produisaient
# alors deux previews differents sur le meme state.
# pyyaml et setuptools restent souples : ils n'influencent pas le state.
PULUMI_REQUIREMENTS = [
    "pulumi==" + PULUMI_VERSION,
    "pulumi-gcp==" + PULUMI_GCP_VERSION,
    "pyyaml>=6.0",
    "setuptools>=68.0",
]
# Version sans Python embarque : le framework impose deja CLOUDSDK_PYTHON.
GCLOUD_URL = "https://dl.google.com/dl/cloudsdk/channels/rapid/google-cloud-sdk.zip"
# Build "archive" (zip portable), et non l'installeur : rien a installer sur le
# poste, l'arborescence se deploie telle quelle dans binaries/vscode.
VSCODE_URL = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
ANDROID_CLI_URL = (
    "https://dl.google.com/android/repository/commandlinetools-win-"
    + ANDROID_CLI_BUILD
    + "_latest.zip"
)
# Node portable, pour EXECUTER EN LOCAL des Cloud Functions (simulateur de store,
# storemock) : meme version majeure que leur runtime `nodejs24`. Zip officiel,
# un seul dossier racine, node.exe et npm.cmd a sa racine. Rien de global : ni
# installeur, ni %APPDATA%, ni npm -g.
NODE_VERSION = "24.4.1"
NODE_URL = (
    "https://nodejs.org/dist/v" + NODE_VERSION + "/node-v" + NODE_VERSION + "-win-x64.zip"
)

# -----------------------------------------------------------------------------
# --- Globals shortcuts and miscellaneous
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# --- main class
# -----------------------------------------------------------------------------
# Sequences d'echappement ANSI : gardees pour la console, retirees du journal.
_ANSI = re.compile(chr(27) + r"\[[0-9;?]*[A-Za-z]")

# REGLAGES DE TERMINAL QUE LA PSEUDO-CONSOLE EMET POUR L'ENFANT, et qui n'ont rien a
# faire dans la notre : modes prives DEC (`ESC[?1004h` rapport de focus, `ESC[?9001h`
# mode d'entree win32, `ESC[?7l` retour a la ligne), operations de fenetre (`ESC[1t`)
# et interrogation d'attributs (`ESC[c`).
#
# ⚠ LES TRANSMETTRE N'EST PAS ANODIN : `ESC[?9001h` bascule la console parente en
#   mode d'entree win32. On ne relaie que ce qui PEINT, jamais ce qui REGLE.
_REGLAGES = re.compile(chr(27) + r"\[(\?[0-9;]*[hl]|[0-9;]*t|c)")
# -----------------------------------------------------------------------------


class dvutils:

    # VALEURS A NE JAMAIS AFFICHER. Registre de CLASSE, et c'est le point : chaque module
    # du builder cree sa propre instance de dvutils, et une valeur declaree par l'un doit
    # etre masquee dans les lignes de tous les autres.
    #
    # ⚠ LE MASQUAGE NE COUVRE QUE CE QUI PASSE PAR print() ET render_doc_diff(). La
    #   sortie d'un sous-processus (pulumi, gradle) va droit a la console : c'est pour
    #   cela qu'aucune valeur secrete ne doit jamais lui etre passee en argument.
    _masked = set()
    _MASK_MIN_LEN = 6

    # LE JOURNAL DU BUILDER : tout ce qui passe par print(), aussi dans un fichier.
    #
    # Un build qui echoue se diagnostique sur sa sortie, et cette sortie vivait dans une
    # console qu'on ferme. La relire supposait de la recopier a la main ; elle est
    # desormais aussi sur disque, a un chemin stable, lisible par un humain comme par une
    # IA qui cherche ce qui a casse.
    #
    # ⚠ REGISTRE DE CLASSE, pour la meme raison que `_masked` juste au-dessus : chaque
    #   module du builder cree sa propre instance de dvutils (dvcloud a la sienne), et
    #   tout doit atterrir dans le meme fichier.
    #
    # ⚠ CE QUI Y EST ECRIT EST DEJA MASQUE. Le journal est alimente APRES `mask()`, donc
    #   il ne peut pas contenir un secret declare. C'est la raison pour laquelle il se
    #   branche ici et nulle part ailleurs : teer la console entiere y ferait entrer la
    #   sortie BRUTE des sous-processus, que le masquage ne couvre pas (cf. l'encadre de
    #   `_masked`), et un fichier garde ce qu'une console oublie.
    #
    # ⚠ ET C'EST DONC UN JOURNAL INCOMPLET, VOLONTAIREMENT : la sortie de flutter, gradle
    #   et pulumi n'y est pas, seulement la ligne de commande que le builder a lancee.
    _journal = None
    _journal_path = ""

    @classmethod
    def journal_open(cls, path, garder=5):

            """Ouvre le journal a un chemin STABLE, en archivant le precedent.

            Meme convention que les logs de l'application (`DvLog.init`) : le dernier run
            est toujours au meme endroit, les precedents portent un horodatage, et on n'en
            garde que `garder`. Un chemin stable est ce qui permet d'aller lire le dernier
            build sans avoir a chercher lequel c'est.
            """
            if cls._journal is not None:
                return cls._journal_path
            try:
                dossier = os.path.dirname(path)
                os.makedirs(dossier, exist_ok=True)
                base, ext = os.path.splitext(os.path.basename(path))

                if os.path.exists(path):
                    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
                    try:
                        os.replace(path, os.path.join(dossier, base + "-" + stamp + ext))
                    except OSError:
                        pass
                    archives = sorted(
                        (os.path.join(dossier, n) for n in os.listdir(dossier)
                         if n.startswith(base + "-") and n.endswith(ext)),
                        key=lambda p: os.path.getmtime(p))
                    for vieux in archives[:-garder] if garder > 0 else archives:
                        try:
                            os.remove(vieux)
                        except OSError:
                            pass

                cls._journal = open(path, "a", encoding="utf-8")
                cls._journal_path = path
            except Exception:
                # Un journal qui ne s'ouvre pas ne doit jamais empecher un build : c'est
                # une commodite de diagnostic, pas une dependance.
                cls._journal = None
                cls._journal_path = ""
            return cls._journal_path

    @classmethod
    def journal(cls, texte, color=""):

            """Ajoute une ligne au journal. Sans journal ouvert, ne fait rien.

            ⚠ VIDE APRES CHAQUE LIGNE. Un build qui meurt sur une exception, un Ctrl-C ou
              un plantage de pulumi doit laisser derriere lui TOUT ce qui a precede : c'est
              precisement le moment ou l'on a besoin du journal. Un tampon non vide
              perdrait les dernieres lignes, les seules qui comptent.
            """
            if cls._journal is None:
                return
            try:
                horo = datetime.datetime.now().strftime("%H:%M:%S")
                marque = (" [" + color + "]") if color else ""
                cls._journal.write("[" + horo + "]" + marque + " " + str(texte) + "\n")
                cls._journal.flush()
            except Exception:
                pass

    @classmethod
    def journal_close(cls, texte=""):

            """Ferme le journal, apres une derniere ligne."""
            if cls._journal is None:
                return
            if texte:
                cls.journal(texte)
            try:
                cls._journal.close()
            except Exception:
                pass
            cls._journal = None

    @classmethod
    def mask_register(cls, value):

            """Declare une valeur secrete : elle sera remplacee par *** a l'affichage.

            Les valeurs trop courtes sont ignorees : masquer « true » ou « 1234 »
            ferait disparaitre la moitie des logs sans rien proteger.
            """
            if value is None:
                return
            text = str(value).strip()
            if len(text) >= cls._MASK_MIN_LEN:
                cls._masked.add(text)

    @classmethod
    def mask(cls, text):

            """Rend `text` avec chaque valeur declaree remplacee par ***."""
            if not cls._masked:
                return text
            out = str(text)
            # Les plus longues d'abord : une valeur contenue dans une autre ne doit pas
            # laisser apparaitre le reste de la premiere.
            for secret in sorted(cls._masked, key=len, reverse=True):
                if secret in out:
                    out = out.replace(secret, "***")
            return out

    def __init__(self):

            self.http = urllib3.PoolManager(cert_reqs="CERT_NONE")
            self._tls = threading.local()
            self._env_alias  = None    # canonical name (UPPER) -> alias name
            self._env_actual = None    # UPPER -> real os.environ key (Linux)
            self._env_logged = set()   # aliases already traced

    def print(self, color, *args):

            # When the calling thread has an active capture buffer (see
            # capture_begin), redirect the line there instead of stdout so that
            # parallel workers don't interleave their output.
            ligne = self.mask(" ".join(str(a) for a in args))
            # Le journal AVANT tout aiguillage : une ligne capturee dans un tampon de
            # thread qui ne serait jamais vide disparaitrait sinon du fichier, et c'est
            # sous parallelisme que l'on a le plus besoin de relire.
            self.journal(ligne, color)
            buffer = getattr(self._tls, "buffer", None)
            if buffer is not None:
                buffer.append((color, ligne))
                return
            if self._masked:
                print(getattr(colorama.Fore, color), ligne, colorama.Fore.RESET)
                return
            print(getattr(colorama.Fore, color), *args, colorama.Fore.RESET)

    # -----------------------------------------------------------------------
    # -- Per-thread output capture (readable logs under multithreading) -----
    # -----------------------------------------------------------------------

    def capture_begin(self):

            """Start capturing this thread's print() output into a buffer."""
            buffer = []
            self._tls.buffer = buffer
            return buffer

    def capture_end(self):

            """Stop capturing this thread's print() output."""
            self._tls.buffer = None

    def flush_captured(self, buffer):

            """Print a previously captured buffer to stdout, keeping colors."""
            for color, line in (buffer or []):
                print(getattr(colorama.Fore, color), self.mask(line), colorama.Fore.RESET)

    # -----------------------------------------------------------------------
    # -- Ouverture d'une page de console (etapes manuelles guidees) ---------
    # -----------------------------------------------------------------------

    def open_page(self, url):

            """Ouvre une page dans EDGE, profil normal, et reimprime l'URL.

            Point d'entree unique de toutes les etapes manuelles guidees des
            modules Pulumi (droit Play, RTDN, origines JS, clients OAuth...).
            Trois partis pris :

              - EDGE et pas le navigateur par defaut : les consignes qu'on
                dicte a cote (noms de menus, position des boutons) decrivent
                une console vue dans un seul navigateur. Suivre une consigne
                ecrite pour Edge dans un autre navigateur, c'est deja chercher.

              - PROFIL NORMAL, surtout pas --inprivate : ces pages exigent une
                session Play Console / GCP deja ouverte. L'InPrivate forcerait
                une reconnexion complete a chaque etape guidee. C'est la
                difference assumee avec _open_private_browser (dvcloud_base,
                builder/service), qui lui a besoin d'une session vierge.

              - on REIMPRIME toujours l'URL, meme quand l'ouverture reussit :
                la fenetre s'ouvre parfois derriere le terminal, et un lien
                affiche reste cliquable.

            Ne leve jamais : une etape guidee ne doit pas casser un deploiement
            parce qu'un navigateur manque."""

            candidates = []
            if sys.platform == "win32":
                for root in (
                    os.environ.get("ProgramFiles", "C:\\Program Files"),
                    os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"),
                    os.environ.get("LOCALAPPDATA", ""),
                ):
                    if root:
                        candidates.append(
                            [os.path.join(root, "Microsoft", "Edge", "Application",
                                          "msedge.exe"), url]
                        )
                found = shutil.which("msedge")
                if found:
                    candidates.append([found, url])
            elif sys.platform == "darwin":
                candidates.append(["open", "-a", "Microsoft Edge", url])
            else:
                for exe in ("microsoft-edge", "microsoft-edge-stable", "msedge"):
                    found = shutil.which(exe)
                    if found:
                        candidates.append([found, url])

            opened = False
            for cmd in candidates:
                # Popen leve FileNotFoundError sur un chemin absent : c'est ce
                # qui fait office de test d'existence, sans stat prealable.
                try:
                    subprocess.Popen(cmd)
                    opened = True
                    break
                except Exception:
                    continue

            if not opened:
                try:
                    import webbrowser

                    webbrowser.open(url)
                    self.print("YELLOW", "  (Edge introuvable - navigateur par defaut.)")
                except Exception:
                    self.print("YELLOW", "  (Aucun navigateur n'a pu etre ouvert.)")

            self.print("CYAN", "        " + url)

    # -----------------------------------------------------------------------
    # -- Environment variables (aliases + quote stripping) ------------------
    # -----------------------------------------------------------------------

    def env_clean(self, value):

            # A 'set VAR="value"' in a .bat stores the quotes INSIDE the value
            # (cmd only strips them when re-parsing a command line). CLI tools
            # run through shell=True are therefore fine, but HTTP calls made
            # from Python (Basic auth, Artifactory) send the secret quotes
            # included -> silent 401/403. Normalise here, once for everyone.
            if value is None:
                return None
            value = value.strip()
            for quote in ('"', "'"):
                if len(value) >= 2 and value.startswith(quote) and value.endswith(quote):
                    value = value[1:-1].strip()
                    break
            return value

    def env_index(self):

            """Reverse index of conf.env.alias: canonical name (UPPER) -> alias.

            The config declares one entry per variable that actually exists in
            the target environment (Jenkins), listing the canonical names -
            derived from the repo urls / registry hosts - it stands for."""
            if self._env_alias is not None:
                return self._env_alias

            index = {}
            table = deva.conf.get("env.alias")
            if table is None:
                # a top-level 'env:' in config.yml is dropped at build time
                # (only core/conf/runtime are ingested): name the mistake.
                if deva.conf.get("alias") is not None:
                    self.print("RED", "[env] 'env.alias' not found but a root 'alias' exists: "
                                      "the env block must be declared under 'conf:' in config.yml.")
            else:
                for alias in table.keys():
                    if "." in alias:
                        # dvidle.set() splits keys on '.' and would turn the key
                        # into a tree when layers are merged: refuse it loudly.
                        self.print("YELLOW", f"[env] alias '{alias}' ignored: a dot is not allowed "
                                             f"in an alias name (dots belong to the listed names).")
                        continue
                    names = getattr(table, alias, None)
                    if names is None:
                        continue
                    if not isinstance(names, list):
                        names = [names]
                    for name in names:
                        name = str(name or "").strip()
                        if not name:
                            continue
                        key = name.upper()
                        if key in index and index[key] != alias:
                            self.print("YELLOW", f"[env] '{name}' is claimed by two aliases "
                                                 f"({index[key]} and {alias}): {index[key]} wins.")
                            continue
                        index[key] = alias

            self._env_alias = index
            return index

    def _env_realkey(self, name):

            # os.environ is case-insensitive on Windows but case-SENSITIVE on
            # the Linux CI agents. Resolve the real key case-insensitively so
            # that a mixed-case name (externalID_PSW) works on both sides.
            if self._env_actual is None or len(self._env_actual) != len(os.environ):
                actual = {}
                for key in os.environ.keys():
                    actual.setdefault(key.upper(), key)
                self._env_actual = actual
            return self._env_actual.get(str(name).upper())

    def _env_raw(self, name):

            for key in (name, self._env_realkey(name)):
                if key is None:
                    continue
                value = os.environ.get(key)
                if value is not None:
                    return value
            return None

    def env(self, name, default=None, verbose=True):

            """Value of an environment variable, quotes stripped, resolved
            through conf.env.alias. The alias WINS over the canonical name:
            the target environment always drives."""
            if not name:
                return default

            alias = self.env_index().get(str(name).upper())
            if alias:
                value = self._env_raw(alias)
                if value is not None:
                    if verbose and (name, alias) not in self._env_logged:
                        self._env_logged.add((name, alias))
                        self.print("CYAN", f"[env] {name} resolved through the alias {alias}")
                    return self.env_clean(value)

            value = self._env_raw(name)
            if value is not None:
                return self.env_clean(value)
            return default

    def env_hint(self, *names):

            """Suffix for a 'set XXX_user / XXX_pwd' message, naming the aliases
            that would also do the job. Empty when no alias covers them."""
            index = self.env_index()
            aliases = []
            for name in names:
                alias = index.get(str(name).upper())
                if alias and alias not in aliases:
                    aliases.append(alias)
            if not aliases:
                return ""
            return " (or the alias " + " / ".join(aliases) + ")"

    def profile(self):

            """'jenkins' when running as a Jenkins pipeline step (JENKINS_URL
            and BUILD_NUMBER are always injected there), 'laptop' otherwise."""
            if os.environ.get("JENKINS_URL") or os.environ.get("BUILD_NUMBER"):
                return "jenkins"
            return "laptop"

    def profile_get(self, key, default=None):

            """conf.profiles.<profile>.<key>, profile resolved from the
            environment (see profile()). Lets a single conf.yml carry both a
            Jenkins-sized and a laptop-sized setting for the same key."""
            return deva.conf.get(f"profiles.{self.profile()}.{key}", default)

    # -----------------------------------------------------------------------
    # -- parsing parameters -------------------------------------------------
    # -----------------------------------------------------------------------

    def parse_params(self, file, argv=True):

            params = dvidle(words=[])
            params.set("env.root", pathlib.Path.cwd().as_posix())
            if os.path.exists(file):
                params.mask(dvidle().fromyamlfile(file))
            if argv is False:
                return params
            for arg in sys.argv:
                if "=" in arg:
                    params.set(arg.split("=")[0], "=".join(arg.split("=")[1:]))
                else:
                    params.words.append(arg)
            # ⚠ AUSSI SUR LA CLASSE, pour la meme raison que `_masked` : chaque module du
            #   builder cree sa propre instance de dvutils, et seule celle du builder passe
            #   ici. Sans cela, `utils.params` n'existait pas dans dvrelease, et toute
            #   publication mourait sur un AttributeError avant d'avoir rien decide.
            dvutils.params = params
            self.params = params
            return params

    def tob64(self, string):

            return base64.b64encode(string.encode("utf-8")).decode("utf-8")

    def fromb64(self, string):

            return base64.b64decode(string.encode("utf-8")).decode("utf-8")

    def rm(self, path):

            if os.path.isfile(path):
                self.rmfile(path)
            else:
                self.rmtree(path)

    def rmtree(self, path):

            shutil.rmtree(path, ignore_errors=True)

    def copytree(self, source, target, ignore=None):

            if ignore:
                shutil.copytree(
                    source,
                    target,
                    dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns(*ignore),
                )
            else:
                shutil.copytree(source, target, dirs_exist_ok=True)

    def copytreecontent(self, source, target, ignore=None):

            for item in os.listdir(source):
                if isinstance(ignore, list) and item in ignore:
                    pass
                elif os.path.isfile(source + "/" + item):
                    self.copyfile(source + "/" + item, target + "/" + item)
                else:
                    self.copytree(source + "/" + item, target + "/" + item, ignore)

    def makedirs(self, path):

            os.makedirs(path, exist_ok=True)

    def movefile(self, source, target):

            shutil.move(source, target)

    def copyfile(self, source, target):

            if os.path.isfile(source):
                # Repertoire parent par os.path.dirname, qui gere les deux separateurs.
                # L'ancien calcul retirait du target le dernier segment de la SOURCE decoupee
                # sur "/" : un source en antislashs (ou un renommage a la copie) ne trouvait
                # aucune correspondance, et makedirs creait alors un REPERTOIRE portant le nom
                # du fichier, shutil.copy deposait ensuite le fichier dedans.
                parent = os.path.dirname(target)
                if parent:
                    self.makedirs(parent)
                try:
                    shutil.copy(source, target)
                except:
                    with open(source, "rb") as fios:
                        with open(target, "wb") as fiow:
                            fiow.write(fios.read())

    def _text_comment(self, ext):

            if ext in (".py", ".yml", ".yaml", ".properties"):
                return ("#", None)
            if ext in (".dart", ".kt", ".java", ".gradle", ".kts"):
                return ("//", None)
            if ext in (".xml", ".html"):
                return ("<!--", "-->")
            return None

    def copyfile_annotated(self, source, target):

            self.copyfile(source, target)
            ext = os.path.splitext(target)[1].lower()
            tokens = self._text_comment(ext)
            if tokens is None:
                return
            open_tok, close_tok = tokens
            if close_tok:
                line1 = f"{open_tok} FICHIER GÉNÉRÉ, Ne pas modifier, sera écrasé au prochain build {close_tok}\n"
                line2 = f"{open_tok} Source: {source} {close_tok}\n"
            else:
                line1 = f"{open_tok} FICHIER GÉNÉRÉ, Ne pas modifier, sera écrasé au prochain build\n"
                line2 = f"{open_tok} Source: {source}\n"
            header = line1 + line2
            try:
                with open(target, "r", encoding="utf-8") as fio:
                    content = fio.read()
            except (UnicodeDecodeError, OSError):
                return
            if open_tok == "#" and content.startswith("#!"):
                newline_pos = content.find("\n")
                if newline_pos == -1:
                    annotated = content + "\n" + header
                else:
                    annotated = (
                        content[: newline_pos + 1] + header + content[newline_pos + 1 :]
                    )
            elif open_tok == "<!--" and content.lstrip("﻿").lower().startswith(("<?xml", "<!doctype")):
                # La declaration XML DOIT etre le tout premier octet du fichier : un
                # commentaire devant rend le document invalide. Le sitemap.xml des sites
                # vitrines etait ainsi refuse par les moteurs de recherche.
                end = content.find(">") + 1
                annotated = content[:end] + "\n" + header + content[end:].lstrip("\r\n")
            else:
                annotated = header + content
            with open(target, "w", encoding="utf-8") as fio:
                fio.write(annotated)

    def copytree_annotated(self, source, target, ignore=None):

            self.makedirs(target)
            self.copytreecontent_annotated(source, target, ignore)

    def copytreecontent_annotated(self, source, target, ignore=None):

            for item in os.listdir(source):
                if isinstance(ignore, list) and item in ignore:
                    pass
                elif os.path.isfile(source + "/" + item):
                    self.copyfile_annotated(source + "/" + item, target + "/" + item)
                else:
                    self.copytree_annotated(
                        source + "/" + item, target + "/" + item, ignore
                    )

    def rmfile(self, path):

            try:
                os.remove(path)
            except:
                pass

    def run(

            self,
            cmd,
            path=None,
            shell=True,
            system=False,
            output=False,
            verbose=True,
            indent="",
            pty=False,
            **kwargs,
    ):

        if output is True:
            system = False
        if verbose:
            if isinstance(cmd, list):
                self.print("GREEN", indent, " ".join(cmd))
            else:
                self.print("GREEN", indent, cmd)
        if not system:
            if shell:
                if isinstance(cmd, list):
                    cmd = " ".join(cmd)
            else:
                if isinstance(cmd, str):
                    cmd = cmd.split(" ")
            kwargs["shell"] = shell
            if path:
                kwargs["cwd"] = path
            if output:
                res = subprocess.check_output(cmd, **kwargs)
            else:
                res = subprocess.check_call(cmd, **kwargs)
            if verbose and output:
                print(res)
            if output:
                return res

        else:
            if isinstance(cmd, list):
                cmd = " ".join(cmd)
            here = os.getcwd()
            if path is None:
                path = os.getcwd()
            os.chdir(path)
            try:
                # AVEC journal : on relaie, pour que la sortie de l'enfant y entre. SANS
                # journal : `os.system` a l'identique, exactement comme avant. Le repli
                # garde le comportement historique partout ou le journal n'est pas ouvert
                # (pucore dans son propre processus, scripts qui importent dvutils).
                #
                # ⚠ UN LANCEMENT DETACHE (`start ...`, une app dans sa propre fenetre) NE
                #   PASSE JAMAIS PAR LE TUYAU. La fenetre ouverte heritait du tuyau, et la
                #   lecture de `_run_journalise` attendait sa fermeture : les apps d'une
                #   suite se lancaient l'une APRES l'autre, chacune attendant qu'on ferme
                #   la precedente. `start` rend la main aussitot et n'ecrit rien ici : seule
                #   la commande est journalisee.
                if cmd.lstrip().lower().startswith("start "):
                    if self._journal is not None:
                        self.journal(cmd, "DETACHE")
                    code = os.system(cmd)
                else:
                    code = (self._run_journalise(cmd, pty) if self._journal is not None
                            else os.system(cmd))
            finally:
                os.chdir(here)
            return code


    # LE RENDU D'UN TERMINAL, EN DIX LIGNES. Un programme qui anime une barre de
    # progression ou un sablier ne reecrit pas une ligne : il revient en arriere.
    # `flutter doctor` dessine son sablier en ecrivant `\`, un BACKSPACE, `|`, un
    # BACKSPACE, `/`... (mesure : 52 backspaces pour 11 retours chariot). Ecrire ce flux
    # tel quel dans un journal y laisse `\|/-\|/-\|/- [v] Windows Version`, illisible.
    #
    # On rejoue donc ce que fait un terminal : `\b` recule d'une colonne, `\r` revient au
    # debut de la ligne, et tout caractere ecrase ce qui est sous le curseur. Ce qui reste
    # a la fin de la ligne est ce que l'oeil aurait lu.
    def _rendu_ligne(self, tampon, col, texte):

            """Applique `texte` sur `tampon` a partir de `col`. Rend (tampon, col, lignes)."""
            finies = []
            for c in texte:
                if c == "\n":
                    finies.append("".join(tampon).rstrip())
                    tampon, col = [], 0
                elif c == "\r":
                    col = 0
                elif c == "\b":
                    col = max(0, col - 1)
                elif c == "\t":
                    saut = 8 - (col % 8)
                    for _ in range(saut):
                        if col < len(tampon):
                            tampon[col] = " "
                        else:
                            tampon.append(" ")
                        col += 1
                else:
                    if col < len(tampon):
                        tampon[col] = c
                    else:
                        tampon.append(c)
                    col += 1
            return tampon, col, finies

    def _run_pty(self, cmd):

            """Lance `cmd` derriere une PSEUDO-CONSOLE. Rend son code, ou None si refusee.

            ⚠ ELLE A ETE ESSAYEE, ECARTEE, PUIS REMISE SOUS GARDE. Il faut connaitre les
              trois etapes pour ne pas defaire la troisieme.

              1. Elle marche : derriere un ConPTY, flutter et pulumi voient un vrai terminal
                 et rendent leurs couleurs (mesure du 2026-09-20 : 20 sequences de couleur
                 sur `flutter doctor` contre 0 par un tuyau, et `--color` ne force ni chez
                 l'un ni chez l'autre).
              2. Elle a un defaut disqualifiant : `PtyProcess.spawn` refait son propre
                 decoupage et DETRUIT LA CITATION WINDOWS. Une commande contenant des
                 guillemets ne s'execute pas du tout et rend 0, donc « reussi ». Un
                 `flutter build` en echec passerait pour un succes.
              3. Mais ce defaut ne touche QUE les commandes citees, et les seules qui
                 justifient une pseudo-console n'en portent aucune : `flutter build ...`,
                 `pulumi up --stack X --yes --cwd D`. D'ou la garde ci-dessous, refus net
                 des qu'un guillemet apparait.

            ⚠ ET ELLE COUTE ~8 SECONDES FIXES PAR COMMANDE : ~3,2 s avant que le processus
              soit declare mort (meme un `exit 3` immediat), puis ~5 s pour l'EOF ; ni
              `iseof` ni `get_exitstatus` n'en sortent plus tot. C'est pourquoi l'appelant
              doit la DEMANDER (`pty=True`), et ne le fait que pour ce qui dure deja des
              minutes. L'y faire passer une quinzaine de commandes courtes ajouterait deux
              minutes a chaque build pour colorer trois lignes.

            ⚠ LA CONSOLE RECOIT LE FLUX BRUT, LE JOURNAL LE TEXTE RENDU. L'un veut la
              couleur et l'animation, l'autre une ligne stable qu'on puisse chercher.
            """
            if '"' in cmd:
                return None
            try:
                from winpty import PtyProcess
            except Exception:
                return None

            try:
                colonnes, hauteur = shutil.get_terminal_size((200, 50))
            except Exception:
                colonnes, hauteur = 200, 50
            try:
                proc = PtyProcess.spawn("cmd.exe /c " + cmd,
                                        dimensions=(max(hauteur, 25), max(colonnes, 80)))
            except Exception as err:
                self.print("YELLOW", "Pseudo-console indisponible (" + str(err) + "), repli tuyau.")
                return None

            tampon, col = [], 0
            while True:
                try:
                    bout = proc.read(4096)
                except EOFError:
                    break
                except Exception:
                    break
                if not bout:
                    if not proc.isalive():
                        break
                    continue
                bout = self.mask(bout)
                sys.stdout.write(_REGLAGES.sub("", bout))
                sys.stdout.flush()
                tampon, col, finies = self._rendu_ligne(tampon, col, _ANSI.sub("", bout))
                for finie in finies:
                    self.journal(finie, "OUT")
            if tampon:
                reste = "".join(tampon).rstrip()
                if reste:
                    self.journal(reste, "OUT")
            try:
                return proc.wait()
            except Exception:
                return 0

    def _run_journalise(self, cmd, pty=False):

            """Lance `cmd`, relaie sa sortie a la console ET au journal. Rend son code.

            ⚠ C'EST CE QUI MET LES ERREURS DE COMPILATION DANS LE JOURNAL, et sans elles il
              ne servait a rien : l'echec d'un build est dans la sortie de flutter, de
              gradle ou de pulumi, jamais dans les messages du builder, qui ne font
              qu'annoncer la commande.

            ⚠ SEULE LA SORTIE DE L'ENFANT EST DANS UN TUYAU, jamais celle du builder. Si on
              redirigeait la notre, colorama verrait autre chose qu'un terminal et
              retirerait toutes les couleurs de la console. L'enfant, lui, perd les
              siennes, ce qui est le prix a payer et n'enleve rien a la lisibilite de son
              texte.

            ⚠ STDIN N'EST PAS TOUCHE. Aucune commande lancee ainsi n'attend de saisie : les
              seules qui en attendent (l'app qui tourne, la boucle `play`) partent par
              `start cmd /k` ou un onglet de la console (`conpty_open`), dans un TERMINAL
              A PART, et leur sortie n'a jamais transite
              par cette console. Ne pas rediriger stdin laisse de toute facon une invite
              fonctionner si l'une venait a en poser une.

            ⚠ CHAQUE LIGNE EST MASQUEE AVANT D'ETRE ECRITE. La sortie d'un sous-processus
              echappait au masquage tant qu'elle n'allait qu'a la console (cf. l'encadre de
              `_masked`) ; la ranger dans un fichier durable exigeait de la couvrir aussi.
              Ce qui protege les valeurs DECLAREES, pas celles qu'un outil inventerait :
              la regle « aucun secret en argument d'un sous-processus » reste entiere.
            """
            # LA PSEUDO-CONSOLE QUAND L'APPELANT LA DEMANDE, LE TUYAU SINON. Voir
            # `_run_pty` : elle rend les couleurs que les outils coupent derriere un
            # tuyau, elle coute huit secondes, et elle se refuse elle-meme sur toute
            # commande citee. Le tuyau capture le meme texte dans tous les autres cas.
            if pty:
                code = self._run_pty(cmd)
                if code is not None:
                    return code
            try:
                proc = subprocess.Popen(
                    cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    text=True, encoding="utf-8", errors="replace", bufsize=1,
                )
            except Exception as err:
                self.print("RED", "Lancement impossible :", str(err))
                return 1
            for ligne in proc.stdout:
                ligne = self.mask(ligne.rstrip(chr(13) + chr(10)))
                # LA CONSOLE RECOIT LA LIGNE BRUTE, LE FICHIER LA RECOIT NETTOYEE.
                #
                # ⚠ LE TUYAU NE MANGE AUCUNE COULEUR, c'est mesure : un enfant qui ecrit
                #   une sequence ANSI la voit arriver intacte de l'autre cote. Rendre la
                #   ligne telle quelle a la console garde donc les couleurs de tout outil
                #   qui en emet malgre le tuyau. Ceux qui les coupent d'eux-memes en voyant
                #   `isatty=False` (flutter, et son `--color` n'y change rien, mesure le
                #   2026-09-20) n'en emettent pas : ce n'est pas le tuyau qui les perd.
                #
                # ⚠ ET LE FICHIER N'EN VEUT PAS : une sequence d'echappement dans un
                #   journal se lit `ESC[31m`, gene la recherche et n'apporte rien.
                print(ligne)
                self.journal(_ANSI.sub("", ligne), "OUT")
            proc.stdout.close()
            return proc.wait()

    def unzip(self, file, path):

            os.makedirs(path, exist_ok=True)
            with zipfile.ZipFile(file, "r") as zip_ref:
                zip_ref.extractall(path)

    def zip(self, path, file):

            output_dir = os.path.dirname(file)
            zip_filename_without_ext = os.path.splitext(os.path.basename(file))[0]
            os.makedirs(output_dir, exist_ok=True)
            # base_dir_name = os.path.basename(path)
            # root_dir_parent = os.path.dirname(path) or '.'
            # make_archive_base_name = os.path.join(output_dir, zip_filename_without_ext)
            return shutil.make_archive(
                base_name=os.path.join(output_dir, zip_filename_without_ext),
                format="zip",
                root_dir=path,
            )

    # -----------------------------------------------------------------------
    # -- dryrun / diff des ecritures ----------------------------------------
    # -----------------------------------------------------------------------

    def dryrun(self):

            """Vrai si le mot-cle dryrun a ete passe au builder.

            Passe par l'environnement et non par un attribut : dvcloud et pucore
            instancient chacun leur propre dvutils, et pucore tourne meme dans un
            process separe lance par pulumi.
            """

            return os.environ.get("DEVA_DRYRUN", "") == "1"

    def _diff_flatten(self, value, prefix, out):

            """Aplatit un dvidle/dict imbrique en {cle.pointee: scalaire}."""

            if (
                hasattr(value, "keys")
                and hasattr(value, "get")
                and not isinstance(value, (str, bytes))
            ):
                try:
                    keys = list(value.keys())
                except Exception:
                    keys = []
                if keys:
                    for key in keys:
                        try:
                            child = value.get(key)
                        except Exception:
                            child = None
                        self._diff_flatten(
                            child, prefix + "." + str(key) if prefix else str(key), out
                        )
                    return
                # ⚠ UN OBJET VIDE DEVIENT UN MEME {}. Garde tel quel, un dvidle vide
                #   etait compare a un dict vide (ou a un autre dvidle vide) par
                #   identite : trois « changements » fantomes a chaque build sur
                #   deva_builds, du genre « aimodel_regions : <dvidle>: {} -> {} ».
                out[prefix] = {}
                return
            out[prefix] = value

    def _diff_value(self, value):

            """Rend une valeur pour l'affichage.

            Lisible -> telle quelle. Illisible (state Pulumi base64, keystore,
            YAML multi-ligne...) -> tronquee avec sa taille, pour que le diff
            reste exploitable sans noyer l'ecran.
            """

            if value is None:
                return "(absent)"
            if isinstance(value, bool) or isinstance(value, int):
                return str(value)
            if isinstance(value, (list, tuple)):
                return "[" + str(len(value)) + " element(s)]"

            # ⚠ UNE VALEUR DECLAREE SECRETE NE S'AFFICHE PAS, meme courte : une clef
            #   d'API de 51 caracteres passait la limite de troncature et s'ecrivait en
            #   entier dans le diff d'une ecriture.
            if str(value).strip() in self._masked:
                return "*** (secret)"

            # Les retours ligne sont neutralises pour tenir sur une ligne, mais
            # ne declenchent pas la troncature : un YAML court (stack config)
            # reste parfaitement lisible, seule la taille decide.
            text = self.mask(str(value)).replace("\r", "").replace("\n", "\\n")
            if len(text) <= DIFF_MAX_LEN:
                return text

            size = len(text)
            if size >= 1048576:
                unit = "%.1f Mo" % (size / 1048576.0)
            elif size >= 1024:
                unit = "%.1f Ko" % (size / 1024.0)
            else:
                unit = str(size) + " o"
            return text[:40] + "... (" + unit + ", tronque)"

    def render_doc_diff(self, label, before, after):

            """Affiche le diff d'une ecriture de document. Vrai s'il change.

            Rend visible ce que le framework s'apprete a ecrire (passphrase,
            secrets, state Pulumi) au lieu d'un simple "sauvegarde".
            """

            old, new = {}, {}
            self._diff_flatten(before, "", old)
            self._diff_flatten(after, "", new)
            old.pop("", None)
            new.pop("", None)

            changes = []
            for key in sorted(set(old) | set(new)):
                was, now = old.get(key), new.get(key)
                if key not in old:
                    changes.append(("+", key, None, now))
                elif key not in new:
                    changes.append(("-", key, was, None))
                elif was != now:
                    changes.append(("~", key, was, now))

            if not changes:
                self.print("CYAN", "  " + label + " : aucun changement")
                return False

            self.print("CYAN", "  " + label + " : " + str(len(changes)) + " changement(s)")
            for sign, key, was, now in changes:
                if sign == "+":
                    self.print("GREEN", "    + " + key + " = " + self._diff_value(now))
                elif sign == "-":
                    self.print("RED", "    - " + key + " (" + self._diff_value(was) + ")")
                else:
                    self.print(
                        "YELLOW",
                        "    ~ " + key + " : "
                        + self._diff_value(was) + "  ->  " + self._diff_value(now),
                    )
            return True

    # -----------------------------------------------------------------------
    # -- toolchain provisioning ---------------------------------------------
    # -----------------------------------------------------------------------

    def env_root(self):

            """Racine du framework, equivalent de params.env.root.

            Recalcule depuis le cwd pour les instances dvutils qui n'ont jamais
            parse les parametres : dvcloud et pucore ont chacune la leur.
            """

            params = getattr(self, "params", None)
            if params is not None:
                return params.env.root
            return pathlib.Path.cwd().as_posix()

    def download(self, url, path, label):

            """Telecharge `url` vers `path` en flux, avec barre de progression.

            request() precharge tout le corps en memoire avant d'ecrire : tenable
            pour le JDK (191 Mo), pas pour l'archive Flutter (1,8 Go). On lit donc
            par blocs et on ecrit au fil de l'eau.
            """

            os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
            res = self.http.request("GET", url, preload_content=False)
            if not (200 <= res.status < 300):
                res.release_conn()
                raise RuntimeError("HTTP " + str(res.status) + " sur " + url)

            total = int(res.headers.get("Content-Length", 0) or 0)
            done = 0
            partial = path + ".part"
            try:
                with open(partial, "wb") as fio:
                    while True:
                        chunk = res.read(1024 * 1024)
                        if not chunk:
                            break
                        fio.write(chunk)
                        done += len(chunk)
                        self._render_download(label, done, total)
            finally:
                res.release_conn()
            print()  # cloture la ligne de la barre
            os.replace(partial, path)

    def _render_download(self, label, done, total):

            """Barre de progression reecrite en place (meme idiome qu'imgshaking).

            Ecrit directement avec end="\\r" : self.print ajoute toujours un
            retour de ligne.
            """

            mb = done / (1024.0 * 1024.0)
            if total > 0:
                width = 30
                filled = int(round(width * done / float(total)))
                bar = "#" * filled + "-" * (width - filled)
                text = "\t%s [%s] %d%% (%.0f Mo)" % (
                    label, bar, round(100.0 * done / total), mb,
                )
            else:
                text = "\t%s %.0f Mo" % (label, mb)
            print(colorama.Fore.CYAN, text, colorama.Fore.RESET, end="\r")

    def install_archive(self, url, dest, label):

            """Telecharge une archive zip et la deploie dans `dest`.

            Les archives de la toolchain contiennent toutes un unique repertoire
            racine (jdk-<ver>/, dart-sdk/, flutter/, pulumi/, google-cloud-sdk/,
            cmdline-tools/) : on l'aplatit pour que `dest` soit directement la
            racine de l'outil.
            """

            if sys.platform != "win32":
                self.print("RED", label, ": installation auto limitee a Windows.")
                self.print("RED", "Telecharger", url, "et le decompresser dans", dest)
                sys.exit(1)

            self.print("CYAN", label, "absent : installation ...")
            archive = os.path.join(
                tempfile.gettempdir(), "_deva_dl_" + label.replace(" ", "_") + ".zip"
            )
            staging = os.path.join(tempfile.gettempdir(), "_deva_stage_" + label.replace(" ", "_"))

            try:
                if not os.path.exists(archive):
                    self.download(url, archive, label)
                if os.path.exists(staging):
                    shutil.rmtree(staging)
                self.print("CYAN", "\tdecompression ...")
                self.unzip(archive, staging)

                entries = [
                    d for d in os.listdir(staging)
                    if os.path.isdir(os.path.join(staging, d))
                ]
                source = (
                    os.path.join(staging, entries[0]) if len(entries) == 1 else staging
                )

                os.makedirs(os.path.dirname(dest), exist_ok=True)
                if os.path.exists(dest):
                    shutil.rmtree(dest, ignore_errors=True)
                shutil.move(source, dest)
                shutil.rmtree(staging, ignore_errors=True)
                os.remove(archive)

            except Exception as e:
                # sys.exit plutot que remonter l'exception : plusieurs appelants
                # (do_prepare_android_keystores) attrapent Exception et
                # continueraient avec un etat incomplet, en silence.
                self.print("RED", "Echec de l'installation de", label, ":", e)
                self.print("RED", "Telecharger", url)
                self.print("RED", "puis le decompresser dans", dest)
                sys.exit(1)

            self.print("CYAN", label, "installe dans", dest)

    def ensure_tool(self, name, marker, url, label):

            """Garantit binaries/<name> et renvoie son chemin. Idempotent."""

            dest = self.env_root() + "/binaries/" + name
            if not os.path.exists(dest + "/" + marker):
                self.install_archive(url, dest, label)
            return dest

    def add_path(self, path):

            """Prepend au PATH du process s'il n'y est pas deja.

            Les commandes dart/flutter/pulumi sont lancees en nom nu, parfois via
            `start cmd /k` (console fille) : muter l'environnement est donc
            indispensable, un chemin absolu ne suffirait pas.
            """

            entry = path.replace("/", os.sep)
            current = os.environ.get("PATH", "")
            if entry.lower() not in current.lower():
                os.environ["PATH"] = entry + os.pathsep + current
            return entry

    def ensure_jdk(self):

            """Retourne JAVA_HOME, en installant binaries/jdk s'il est absent.

            Meme principe que les modules pip auto-installes en tete de builder :
            un poste neuf n'a pas de JDK, or keytool (keystores Android) et gradle
            en dependent.
            """

            java_home = os.environ.get("JAVA_HOME", "")
            if java_home and os.path.exists(java_home + "/bin"):
                return java_home

            jdk = self.ensure_tool("jdk", "bin", JDK_URL, "JDK " + JDK_VERSION)
            os.environ["JAVA_HOME"] = jdk
            return jdk

    def keytool(self):

            """Chemin absolu de keytool, JDK installe au besoin.

            Etait appele en bare "keytool" : sans JDK dans le PATH l'echec
            remontait en "[WinError 2] fichier introuvable", illisible.
            """

            return os.path.join(self.ensure_jdk(), "bin", "keytool").replace("/", os.sep)

    def ensure_dart(self):

            """Garantit binaries/dart et l'expose dans le PATH."""

            dart = self.ensure_tool(
                "dart", "bin", DART_URL, "Dart SDK " + DART_VERSION
            )
            self.add_path(dart + "/bin")
            return dart

    def ensure_flutter(self):

            """Garantit binaries/flutter et l'expose dans le PATH."""

            flutter = self.ensure_tool(
                "flutter", "bin", FLUTTER_URL, "Flutter " + FLUTTER_VERSION
            )
            self.add_path(flutter + "/bin")
            return flutter

    def ensure_pulumi(self):

            """Garantit binaries/pulumi et l'expose dans le PATH.

            `pulumi up` est lance en nom nu par do_deploy_pulumi_app : jusqu'ici
            ca ne marchait que si le poste avait binaries/pulumi/bin dans son PATH
            systeme, ajoute a la main.
            """

            pulumi = self.ensure_tool(
                "pulumi", "bin", PULUMI_URL, "Pulumi " + PULUMI_VERSION
            )
            self.add_path(pulumi + "/bin")

            # ⚠ `ensure_tool` NE REGARDE QUE LA PRESENCE DU DOSSIER, jamais la version
            #   installee : epingler une version plus recente ne suffisait donc pas, et le
            #   poste restait indefiniment sur l'ancienne. Constate le 2026-09-18 : version
            #   epinglee 3.256.0, CLI reellement installee 3.254.0. La version de la CLI
            #   decide du comportement du moteur (detection des plugins morts, entre autres) :
            #   une divergence silencieuse fausse tout diagnostic.
            try:
                import subprocess as _sp

                out = _sp.run([pulumi + "/bin/pulumi", "version"], capture_output=True,
                              text=True, encoding="utf-8", errors="replace", timeout=60)
                installee = (out.stdout or "").strip().lstrip("v")
                if installee and installee != PULUMI_VERSION:
                    self.print("CYAN", "Pulumi " + installee + " installe, " + PULUMI_VERSION
                                       + " attendu : remplacement ...")
                    import shutil as _sh

                    _sh.rmtree(pulumi, ignore_errors=True)
                    pulumi = self.ensure_tool("pulumi", "bin", PULUMI_URL, "Pulumi " + PULUMI_VERSION)
                    self.add_path(pulumi + "/bin")
            except Exception as exc:
                self.print("YELLOW", "Version de Pulumi non verifiee (" + str(exc)[:120] + ")")
            return pulumi

    def ensure_node(self):

            """Garantit binaries/node (Node portable) et l'expose dans le PATH.

            Sert uniquement a EXECUTER des Cloud Functions en local (simulateur de store,
            storemock). Le deploiement, lui, n'en a pas besoin : Cloud Build compile
            les fonctions, et l'hebergement passe par l'API REST.

            Meme garde de version qu'`ensure_pulumi` : un dossier present ne dit rien de
            la version installee.
            """

            node = self.ensure_tool("node", "node.exe", NODE_URL, "Node " + NODE_VERSION)
            self.add_path(node)
            try:
                import subprocess as _sp

                out = _sp.run([node + "/node.exe", "--version"], capture_output=True,
                              text=True, encoding="utf-8", errors="replace", timeout=60)
                installee = (out.stdout or "").strip().lstrip("v")
                if installee and installee != NODE_VERSION:
                    self.print("CYAN", "Node " + installee + " installe, " + NODE_VERSION
                                       + " attendu : remplacement ...")
                    import shutil as _sh

                    _sh.rmtree(node, ignore_errors=True)
                    node = self.ensure_tool("node", "node.exe", NODE_URL, "Node " + NODE_VERSION)
                    self.add_path(node)
            except Exception as exc:
                self.print("YELLOW", "Version de Node non verifiee (" + str(exc)[:120] + ")")
            return node

    def ensure_pulumi_sdk(self, requirements_path):

            """Installe les dependances Python du programme Pulumi.

            Pulumi.yaml ne declare pas de virtualenv : PULUMI_PYTHON_CMD pointe
            l'interpreteur courant, que pulumi execute directement sans jamais
            installer requirements.txt lui-meme. Sans ce pip install, "pulumi up"
            et "pulumi stack output" echouent avec
            "ModuleNotFoundError: No module named 'pulumi'".

            importlib.metadata (et non import pulumi) : le repo a un repertoire
            pulumi/ a sa racine, qui se resout en faux positif comme namespace
            package si on se contente d'un import.

            Les lignes epinglees (name==version) sont verifiees version par version,
            pas seulement en presence : sans ca un poste installe avant un pin reste
            indefiniment sur son ancienne version, et son provider Pulumi diverge de
            celui qui a ecrit le state (updates a vide au preview). Les lignes souples
            (>=) restent en simple test de presence, pour ne pas reinstaller pour rien.
            """

            if not os.path.exists(requirements_path):
                return

            import importlib.metadata as _im

            with open(requirements_path, "r", encoding="utf-8") as fio:
                lines = [l.strip() for l in fio]
            lines = [l for l in lines if l and not l.startswith("#")]

            stale = None
            for line in lines:
                if "==" in line:
                    name, _, wanted = line.partition("==")
                else:
                    name, wanted = line, None
                    for sep in ("<", ">", "!", "~", "="):
                        name = name.split(sep)[0]
                name = name.strip()
                try:
                    found = _im.version(name)
                except _im.PackageNotFoundError:
                    stale = name + " absent"
                    break
                if wanted and found != wanted.strip():
                    stale = name + " " + found + " au lieu de " + wanted.strip()
                    break

            if stale is None:
                return

            self.print("CYAN", "Dependances Pulumi a aligner (" + stale + ") ...")
            cmd = [sys.executable, "-m", "pip", "install", "--quiet", "-r", requirements_path]
            result = subprocess.run(cmd)
            if result.returncode != 0:
                self.print("RED", "Echec de pip install -r", requirements_path)
                sys.exit(1)

    def ensure_symlinks(self):

            """Verifie que le poste peut creer des liens symboliques.

            Flutter en cree un par plugin lors d'un build Windows. Sans le
            privilege, il echoue au milieu du build par une longue stack trace
            ("Building with plugins requires symlink support") : on prefere
            s'arreter avant, avec la marche a suivre.

            On teste la capacite reelle plutot que la cle de registre : une
            session elevee cree des liens sans que le mode developpeur soit actif.
            """

            if sys.platform != "win32":
                return True

            probe = tempfile.mkdtemp()
            target = os.path.join(probe, "cible")
            link = os.path.join(probe, "lien")
            try:
                os.makedirs(target, exist_ok=True)
                os.symlink(target, link, target_is_directory=True)
                return True
            except OSError:
                self.print("RED", "Liens symboliques impossibles sur ce poste.")
                self.print(
                    "RED",
                    "Flutter en a besoin pour les plugins : le build echouerait.",
                )
                self.print("CYAN", "")
                self.print("CYAN", "Activer le mode developpeur Windows, au choix :")
                self.print("CYAN", "  1. Interface :  start ms-settings:developers")
                self.print("CYAN", "  2. En ligne de commande, dans un terminal ADMINISTRATEUR :")
                self.print(
                    "CYAN",
                    '     reg add "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\AppModelUnlock"'
                    " /t REG_DWORD /f /v AllowDevelopmentWithoutDevLicense /d 1",
                )
                self.print("CYAN", "")
                self.print(
                    "CYAN",
                    "Aucune elevation possible depuis le builder : c'est un reglage machine.",
                )
                sys.exit(1)
            finally:
                shutil.rmtree(probe, ignore_errors=True)

    def ensure_vscode(self):

            """Garantit binaries/vscode et expose son CLI `code` dans le PATH.

            Sert uniquement a verdir la ligne "VS Code" de flutter doctor, qui
            n'est pas bloquante : sans lui le framework se contentait d'un
            avertissement. Rien a voir avec la ligne "Visual Studio", qui reclame
            le compilateur MSVC et n'est pas installable automatiquement.
            """

            vscode = self.ensure_tool("vscode", "bin", VSCODE_URL, "VS Code")
            self.add_path(vscode + "/bin")
            return vscode

    def ensure_gcloud(self):

            """Garantit binaries/google, ou build.yml attend bin/gcloud.cmd.

            L'archive ne livre que le SDK brut : les wrappers Windows (gcloud.cmd,
            gsutil.cmd, bq.cmd...) sont generes par bin/bootstrapping/install.py,
            qu'il faut donc lancer, sinon bin/ ne contient que les scripts bash
            et le chemin configure dans build.yml n'existe pas.
            """

            google = self.ensure_tool("google", "bin", GCLOUD_URL, "Google Cloud SDK")

            if not os.path.exists(google + "/bin/gcloud.cmd"):
                self.print("CYAN", "Google Cloud SDK : generation des wrappers ...")
                env = dict(os.environ)
                env["CLOUDSDK_PYTHON"] = sys.executable
                env["CLOUDSDK_CORE_DISABLE_PROMPTS"] = "1"
                env.pop("PYTHONHOME", None)
                proc = subprocess.run(
                    [
                        sys.executable,
                        (google + "/bin/bootstrapping/install.py").replace("/", os.sep),
                        "--quiet",
                        "--usage-reporting=false",
                        "--path-update=false",
                        "--command-completion=false",
                    ],
                    env=env,
                )
                if proc.returncode != 0 or not os.path.exists(google + "/bin/gcloud.cmd"):
                    self.print("RED", "Echec de l'initialisation du Google Cloud SDK.")
                    self.print("RED", "Lancer manuellement :", google + "/install.bat")
                    sys.exit(1)

            self.add_path(google + "/bin")
            return google

    def ensure_android(self):

            """Garantit binaries/android (SDK complet) et positionne ANDROID_HOME.

            Les cmdline-tools se deploient dans cmdline-tools/latest (layout exige
            par sdkmanager), qui installe ensuite les composants et accepte les
            licences, sans quoi Gradle refuse de telecharger quoi que ce soit.
            """

            self.ensure_jdk()  # sdkmanager est un programme Java

            sdk = self.env_root() + "/binaries/android"
            cli = sdk + "/cmdline-tools/latest"
            if not os.path.exists(cli + "/bin"):
                self.install_archive(
                    ANDROID_CLI_URL, cli, "Android cmdline-tools"
                )

            os.environ["ANDROID_HOME"] = sdk.replace("/", os.sep)
            os.environ["ANDROID_SDK_ROOT"] = os.environ["ANDROID_HOME"]

            components = [
                "platform-tools",
                "platforms;android-" + ANDROID_PLATFORM,
                "build-tools;" + ANDROID_BUILDTOOLS,
                "ndk;" + ANDROID_NDK,
            ]
            missing = not os.path.exists(sdk + "/platform-tools") or not os.path.exists(
                sdk + "/ndk/" + ANDROID_NDK
            )
            if missing:
                self.sdkmanager(cli, sdk, ["--licenses"])
                self.print("CYAN", "Android SDK : installation des composants ...")
                self.sdkmanager(cli, sdk, components)

            return sdk

    def sdkmanager(self, cli, sdk, args):

            """Lance sdkmanager en repondant "y" aux prompts de licence."""

            cmd = [
                (cli + "/bin/sdkmanager.bat").replace("/", os.sep),
                "--sdk_root=" + sdk.replace("/", os.sep),
            ] + args
            self.print("GREEN", "sdkmanager", *args)
            proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                env=os.environ,
            )
            proc.communicate("y\n" * 50)
            if proc.returncode != 0:
                self.print(
                    "RED", "sdkmanager a echoue (exit", proc.returncode, ") :", *args
                )
                sys.exit(1)

    def compute_file_hash(self, filepath, algo="sha256"):

            hash_func = hashlib.new(algo)
            with open(filepath, "rb") as f:
                while chunk := f.read(8192):
                    hash_func.update(chunk)
            return hash_func.hexdigest()

    def http_body_excerpt(self, data, limit=300):

            """Extrait lisible d'un corps de réponse, pour les messages d'erreur."""
            if data is None:
                return ""
            if isinstance(data, bytes):
                text = data.decode("utf-8", errors="replace")
            else:
                text = str(data)
            text = " ".join(text.split())
            return text[:limit] + ("..." if len(text) > limit else "")

    def request(self, protocol, url, headers, data=None, path=None, verbose=True):

            if data and isinstance(data, dvidle):
                data = self.convert_to_json(data)
            if data is None:
                res = self.http.request(protocol, url, headers=headers)
            elif isinstance(data, dict):
                res = self.http.request(
                    protocol, url, headers=headers, body=json.dumps(data)
                )
                # with open("C:/tmp/request.json","w") as fio: fio.write(json.dumps(data,indent=4))
            else:
                res = self.http.request(protocol, url, headers=headers, body=data)
            res = dvidle(
                data=res.data,
                headers=res.headers,
                status=res.status,
                version=res.version,
                reason=res.reason,
            )
            if res.status == 429:
                time.sleep(1)
                if data is None:
                    res = self.request(protocol, url, headers)
                else:
                    res = self.http.request(
                        protocol, url, headers=headers, body=json.dumps(data)
                    )
                res = dvidle(
                    data=res.data,
                    headers=res.headers,
                    status=res.status,
                    version=res.version,
                    reason=res.reason,
                )

            if verbose:
                self.print("GREEN", protocol, res.status, url)

            if path:
                # Ne jamais écrire le corps d'une réponse en erreur : une page 401/403
                # sauvegardée sous un nom de .tgz/.tar est indiscernable d'un artefact
                # valide et se retrouve livrée telle quelle.
                if not (200 <= res.status < 300):
                    raise RuntimeError(
                        f"HTTP {res.status} {res.reason} on {url} -> {self.http_body_excerpt(res.data)}"
                    )
                os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
                with open(path, "wb") as f:
                    f.write(res.data)
            else:
                try:
                    res.data = self.convert_from_json(res.data)
                except:
                    pass
            return res

    # -----------------------------------------------------------------------
    # -- process management (Windows) ---------------------------------------
    # -----------------------------------------------------------------------

    def conpty_open(self, title, command, cwd="", replace=True):

            """Ouvre `command` dans un onglet du panneau de terminaux de la console deva.

            Rend VRAI si l'onglet est ouvert. FAUX, l'appelant ouvre sa fenetre
            `start cmd /k` comme avant : le builder n'a pas ete lance depuis un onglet
            (pas de `DEVA_CONPTY_URL`), la console est fermee, ou elle a refuse.

            `command` est une ligne `cmd` ordinaire, jouee dans `cmd /k` depuis `cwd`.
            `replace` ferme d'abord l'onglet du meme titre : c'est le cas des apps, qu'on
            relance a la place de la precedente.

            ⚠ L'ENVIRONNEMENT DU BUILDER PART AVEC LA DEMANDE. Une fenetre `start` en
              heritait (variables exportees, identifiants poses en cours de build) ;
              l'onglet, ne de la console, n'aurait sinon que celui de la console. Il
              ne transite que par 127.0.0.1 et n'est jamais ecrit sur le disque.

            ⚠ SANS PROXY. Un `HTTP_PROXY` du poste enverrait la requete pour 127.0.0.1
              a un proxy, qui ne joindrait jamais la console.
            ⚠ DELAI LARGE (10 s) : ouvrir un onglet fige la console une seconde
              (cf. flutter/modules/dvconpty/readme.md).
            """
            return self._conpty_post("/open", {
                "title": title, "command": command, "cwd": cwd, "replace": bool(replace),
                "env": dict(os.environ),
            }) is not None

    def conpty_close(self, title):

            """Ferme les onglets de ce titre, processus compris. Sans console, ne fait rien."""
            self._conpty_post("/close", {"title": title})

    def _conpty_post(self, path, payload):

            import json
            import urllib.request
            url   = os.environ.get("DEVA_CONPTY_URL", "")
            token = os.environ.get("DEVA_CONPTY_TOKEN", "")
            if not url or not token:
                return None
            try:
                req = urllib.request.Request(
                    url + path,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json", "X-Deva-Token": token},
                    method="POST",
                )
                opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                with opener.open(req, timeout=10) as res:
                    body = json.loads(res.read().decode("utf-8") or "{}")
                if body.get("ok"):
                    return body
                self.print("YELLOW", "\t[conpty] refuse : " + str(body.get("error", "")))
            except Exception as e:
                self.print("YELLOW", "\t[conpty] console injoignable : " + str(e))
            return None

    def kill_app(self, exe_name):

            import time
            pids = self._find_pids_by_name(exe_name)
            for pid in pids:
                ancestor = self._find_ancestor_cmd(pid)
                target = ancestor if ancestor else pid
                subprocess.run(
                    ["taskkill", "/PID", str(target), "/F", "/T"],
                    capture_output=True,
                )
            if pids:
                time.sleep(0.5)

    def _find_pids_by_name(self, exe_name):

            try:
                out = subprocess.check_output(
                    [
                        "powershell", "-NoProfile", "-Command",
                        f'(Get-Process -Name "{exe_name}" -ErrorAction SilentlyContinue).Id',
                    ],
                    text=True,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                ).strip()
                return [int(x) for x in out.split() if x.strip().isdigit()]
            except Exception:
                return []

    def _get_parent_pid(self, pid):

            try:
                out = subprocess.check_output(
                    [
                        "powershell", "-NoProfile", "-Command",
                        f'(Get-CimInstance Win32_Process -Filter "ProcessId={pid}").ParentProcessId',
                    ],
                    text=True,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                ).strip()
                return int(out) if out.strip().isdigit() else None
            except Exception:
                return None

    def _get_process_name_by_pid(self, pid):

            try:
                out = subprocess.check_output(
                    [
                        "powershell", "-NoProfile", "-Command",
                        f'(Get-Process -Id {pid} -ErrorAction SilentlyContinue).Name',
                    ],
                    text=True,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                ).strip().lower()
                return out
            except Exception:
                return ""

    def _find_ancestor_cmd(self, pid):

            current = pid
            for _ in range(15):
                parent = self._get_parent_pid(current)
                if parent is None or parent == 0 or parent == current:
                    break
                if self._get_process_name_by_pid(parent) == "cmd":
                    return parent
                current = parent
            return None

    def ghostanim(self, condition, duration=60, signs=None, width=20):

            import threading
            ani = "\U0001F47B"
            if isinstance(signs, str):
                ani = signs
                signs = None
            if signs is None:
                signs = []
                for n in range(width+1): signs.append(" "*n+ani+" "*(10-n)+"     ")
                for n in range(width+1): signs.append(" "*(10-n)+ani+" "*n+"     ")

            def _run():

                now = time.time()
                sign = signs.pop(0)
                while not condition():
                    time.sleep(0.05)
                    sign = signs.pop(0)
                    print(colorama.Fore.BLUE, colorama.Style.BRIGHT, sign, colorama.Fore.RESET, colorama.Style.RESET_ALL, end="\r")
                    signs.append(sign)
                print(" ", sign, "Yiiipiii !!!")

            t = threading.Thread(target=_run, daemon=True)
            t.start()
            return t

# -----------------------------------------------------------------------------
# --- Let's go
# -----------------------------------------------------------------------------

if not "utils" in deva.keys():
    deva.set("utils", dvutils())

# -----------------------------------------------------------------------------
# --- To be continued...
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# --- That's all folks
# -----------------------------------------------------------------------------
