"""Maquette de la boutique générique deva (dvshop), pilotée par shop.yml.

Outil de la console deva (tools/shop/main.py) : bouton Tools du Builder ou d'une fiche.
Lancement à la main, depuis ce dossier : C:\\Asura\\Tools\\Python312\\python.exe main.py
Capture web : SHOP_WEB=8551 SHOP_TAGS=chef,guerrier SHOP_SIM=1 python main.py
Capture fenêtre : SHOP_SHOT=x.png [SHOP_TAGS=chef] [SHOP_THEME=theme-dino] [SHOP_PAGE=shop:themes]
               [SHOP_EMPTY=achats,objets] [SHOP_MARKET=US] [SHOP_SIM=1] python main.py
Aucune donnée en dur : tout sort de shop.yml (section `shop`) ; la section `simulation`
remplace ce que Play et la base fourniraient.
"""
import math
import os
import re
import threading
from datetime import datetime, timedelta
from pathlib import Path

import flet as ft
import yaml

CONF_PATH = Path(__file__).with_name("shop.yml")


# --------------------------------------------------------------------------- utilitaires
def parse_duration(s):
    """ISO 8601 réduit : P7D, P1M, P1W, PT24H, P1DT12H."""
    m = re.fullmatch(r"P(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?", s or "")
    if not m:
        raise ValueError(f"durée illisible : {s}")
    mo, w, d, h, mi = (int(x) if x else 0 for x in m.groups())
    return {"months": mo, "delta": timedelta(weeks=w, days=d, hours=h, minutes=mi)}


def period_key(dt, spec):
    dur = parse_duration(spec)
    if dur["months"]:
        return f"{dt.year}-{dt.month:02d}"
    days = dur["delta"].days
    if days == 7:
        y, wk, _ = dt.isocalendar()
        return f"{y}-W{wk:02d}"
    return dt.strftime("%Y-%m-%d")


def human_delta(td):
    secs = int(td.total_seconds())
    if secs <= 0:
        return "0 min"
    d, rem = divmod(secs, 86400)
    h, rem = divmod(rem, 3600)
    if d:
        return f"{d} j {h} h" if h else f"{d} j"
    if h:
        return f"{h} h"
    return f"{rem // 60} min"


# --------------------------------------------------------------------------- moteur
class ShopEngine:
    """Ce que serait dvshop côté client (et, pour les règles, pushop côté serveur)."""

    def __init__(self, conf):
        self.conf = conf
        self.shop = conf["shop"]
        self.sim = conf["simulation"]
        self.items = self.shop["items"]
        self.reset()

    # ---- état simulé
    def reset(self):
        self.now = datetime.fromisoformat(self.sim["now"])
        self.gold = int(self.sim["gold"])
        self.tags = set(self.sim.get("tags") or [])
        self.market = self.sim["market"]
        self.purchases = []          # la table `store` : une ligne par acquisition
        self.active = {}             # toggle_group -> item (document parent du groupe)
        for iid, it in self.items.items():
            if it.get("default"):
                self._record(iid, it, proof={"grant": "default"},
                             at=self.now - timedelta(days=30))
        for iid, it in self.items.items():
            if it.get("toggle_default"):
                self.active[it["toggle_group"]] = iid

    def _record(self, iid, it, proof, at=None):
        at = at or self.now
        exp = None
        if it.get("expiry"):
            exp = at + parse_duration(it["expiry"])["delta"]
        row = {
            "item": iid,
            "owner_id": self.sim["user"],
            "group_id": self.sim["group"] if it.get("scope", "group") == "group" else None,
            "qty": int(it.get("quantity", 1)),
            "acquired_at": at,
            "expires_at": exp,
            "proof": proof,
            "state": "active",
        }
        self.purchases.append(row)
        return row

    # ---- possessions et tags
    def rows(self, iid):
        return [r for r in self.purchases if r["item"] == iid and r["state"] == "active"]

    def live_rows(self, iid):
        return [r for r in self.rows(iid) if not r["expires_at"] or r["expires_at"] > self.now]

    def owns(self, iid):
        return bool(self.live_rows(iid))

    def viewer_tags(self):
        owned = {f"owns:{r['item']}" for r in self.purchases
                 if r["state"] == "active" and (not r["expires_at"] or r["expires_at"] > self.now)}
        return self.tags | owned

    def tags_ok(self, obj):
        vt = self.viewer_tags()
        if not set(obj.get("tags") or []) <= vt:
            return False
        anyof = obj.get("tags_any") or []
        if anyof and not (set(anyof) & vt):
            return False
        if set(obj.get("tags_none") or []) & vt:
            return False
        return True

    # ---- prix
    def market_conf(self):
        return self.sim["markets"][self.market]

    def play_price(self, product):
        """0 = produit que Play ne sert pas (absent de simulation.play_prices), comme un
        produit encore `enabled: false` dans l'app : la carte dit « Bientôt »."""
        cur = self.market_conf()["currency"]
        return float(((self.sim["play_prices"].get(product) or {}).get(cur)) or 0)

    def fmt_money(self, v):
        m = self.market_conf()
        s = f"{v:.2f}"
        if m["decimal"] == ",":
            s = s.replace(".", ",")
        if s.endswith(",00") or s.endswith(".00"):
            s = s[:-3]
        return m["fmt"].format(v=s)

    def amount(self, it):
        p = it["price"]
        if p["kind"] == "play":
            return self.play_price(p["product"])
        if p["kind"] == "gold":
            return float(p["amount"])
        return 0.0

    def price_label(self, it):
        p = it["price"]
        if p["kind"] == "free":
            return "Gratuit"
        if p["kind"] == "gold":
            return f"{p['amount']} {self.shop['currencies']['gold']['symbol']}"
        return self.fmt_money(self.play_price(p["product"]))

    def reference(self, it):
        ref = it["price"].get("compare_to")
        if ref is None:
            return None
        if isinstance(ref, dict):
            return float(ref["amount"])
        if isinstance(ref, str):
            ref = [ref]
        return sum(self.play_price(x) for x in ref)

    def discount(self, it):
        ref = self.reference(it)
        if not ref:
            return None
        d = 1 - self.amount(it) / ref
        return d if d >= self.shop["display"]["min_discount"] else None

    def advantage(self, it):
        qty = int(it.get("quantity", 1))
        unit_of = it.get("unit_of")
        if qty <= 1 or not unit_of:
            return None
        unit = self.items.get(unit_of)
        if not unit or int(unit.get("quantity", 1)) != 1 or unit["price"]["kind"] != it["price"]["kind"]:
            return None
        up = self.amount(unit)
        if not up:
            return None
        a = 1 - (self.amount(it) / qty) / up
        return a if a >= self.shop["display"]["min_advantage"] else None

    def ref_label(self, it):
        ref = self.reference(it)
        if not ref or not self.discount(it):
            return None
        if it["price"]["kind"] == "gold":
            return f"{int(ref)}"
        return self.fmt_money(ref)

    # ---- état d'un item pour le spectateur
    def item_state(self, iid):
        """None = invisible. Sinon dict {state, reason, timer}."""
        it = self.items[iid]
        if not self.tags_ok(it):
            if it.get("visibility") == "locked":
                return {"state": "locked", "reason": "Réservé"}
            return None
        live = self.live_rows(iid)
        allr = self.rows(iid)
        policy = str(it.get("policy", "once"))
        timer = None
        if live and live[-1]["expires_at"]:
            timer = live[-1]["expires_at"] - self.now

        if policy == "once" and live:
            if it.get("after_purchase") == "vanish":
                return None
            if it.get("toggle_group"):
                if self.active.get(it["toggle_group"]) == iid:
                    return {"state": "active", "reason": "Actif"}
                return {"state": "activate", "reason": "Activer"}
            return {"state": "owned", "reason": "Possédé"}

        missing = [r for r in (it.get("requires") or []) if not self.owns(r)]
        if missing:
            return {"state": "locked", "reason": it.get("requires_reason") or "Verrouillé"}

        if policy.startswith("cooldown:") and allr:
            wait = allr[-1]["acquired_at"] + parse_duration(policy.split(":", 1)[1])["delta"] - self.now
            if wait.total_seconds() > 0:
                return {"state": "cooldown", "reason": f"Dans {human_delta(wait)}", "timer": timer}
        if policy.startswith("period:"):
            spec = policy.split(":", 1)[1]
            key = period_key(self.now, spec)
            if any(period_key(r["acquired_at"], spec) == key for r in allr):
                unit = "ce mois-ci" if parse_duration(spec)["months"] else "pour cette période"
                return {"state": "period", "reason": f"Déjà pris {unit}", "timer": timer}
        # Annoncé, pas encore livré : se voit, ne s'obtient pas (le serveur refuse).
        if it.get("soon"):
            return {"state": "soon", "reason": "Bientôt"}
        if it["price"]["kind"] == "play" and self.amount(it) <= 0:
            if (self.shop.get("display") or {}).get("unpriced", "soon") == "hidden":
                return None
            return {"state": "soon", "reason": "Bientôt"}
        return {"state": "buyable", "reason": None, "timer": timer}

    # ---- actions
    def toggle(self, iid):
        it = self.items[iid]
        self.active[it["toggle_group"]] = iid

    def buy(self, iid):
        """Rend (ok, message)."""
        it = self.items[iid]
        st = self.item_state(iid)
        if not st or st["state"] != "buyable":
            return False, (st or {}).get("reason") or "Indisponible"
        p = it["price"]
        if p["kind"] == "gold":
            if self.gold < p["amount"]:
                return False, "Pas assez d'or"
            self.gold -= int(p["amount"])
            proof = {"debit_ref": f"req_{len(self.purchases)}"}
            msg = f"−{p['amount']} or"
        elif p["kind"] == "play":
            proof = {"order_id": f"GPA.SIM-{len(self.purchases):04d}"}
            msg = f"Google Play (simulé) : {self.price_label(it)} payé"
        else:
            proof = {"free": True}
            msg = "Ajouté !"
        self._record(iid, it, proof)
        for g in it.get("grants") or []:
            if not self.owns(g):
                self._record(g, self.items[g], {"bundle": iid})
        if it.get("toggle_group"):
            self.toggle(iid)
        return True, f"{it['label']} : {msg}"


# --------------------------------------------------------------------------- UI
def main(page: ft.Page):
    conf = yaml.safe_load(CONF_PATH.read_text(encoding="utf-8"))
    eng = ShopEngine(conf)
    shop = conf["shop"]
    looks = shop["looks"]
    disp = shop["display"]
    hub = shop["hub"]
    shops = shop["shops"]
    S = {}                         # habillage courant, recopié depuis shop.looks.<nom>
    H = {}                         # habillage de la page d'entrée (shop.looks.<nom>.hub)

    if os.environ.get("SHOP_TAGS") is not None:
        eng.tags = {t for t in os.environ["SHOP_TAGS"].split(",") if t}
    if os.environ.get("SHOP_MARKET"):
        eng.market = os.environ["SHOP_MARKET"]
    if os.environ.get("SHOP_THEME"):
        eng.toggle(os.environ["SHOP_THEME"])

    ui = {
        "page": tuple((os.environ.get("SHOP_PAGE") or "hub").split(":")),  # hub | shop:<id> | giftcode | subscription
        "selector": {},            # boutique -> sélecteur actif
        "hl": {},                  # boutique -> panneau du carrousel
        "confirm": None,           # (item_id, jeton)
        "flash": None,             # item_id en erreur
        "sim": os.environ.get("SHOP_SIM") == "1",
        # Boutiques VIDÉES par la simulation (outil de la maquette) : pour voir une tuile
        # « Bientôt » sans retoucher le catalogue.
        "emptied": {x for x in os.environ.get("SHOP_EMPTY", "").split(",") if x},
        "look": None,
        "scroll_to": os.environ.get("SHOP_SECTION"),
        "shown_page": None,
    }
    if os.environ.get("SHOP_HL"):
        ui["hl"][ui["page"][-1]] = int(os.environ["SHOP_HL"])

    page.title = "Boutique (maquette dvshop)"
    page.padding = 0
    page.window.width = 412
    page.window.height = 820
    page.fonts = shop.get("fonts") or {}

    root = ft.Container(expand=True)
    frame = ft.Column(spacing=0, expand=True)          # page courante + dvtaskbar
    page.add(root)
    shop_body = ft.Column(spacing=10, scroll=ft.ScrollMode.AUTO, expand=True)   # persistant : garde le défilement
    shop_wrap = ft.Container(shop_body, expand=True, padding=ft.padding.only(12, 4, 12, 12))

    # ---- habillage : suit le thème actif du clan
    def current_look():
        active = eng.active.get("theme")
        for name, lk in looks.items():
            if isinstance(lk, dict) and lk.get("item") == active:
                return name
        return looks["fallback"]

    def apply_look():
        name = current_look()
        if ui["look"] == name:
            return
        ui["look"] = name
        S.clear()
        S.update(looks[name])
        H.clear()
        H.update(looks[name]["hub"])
        page.bgcolor = S["background"]
        page.theme_mode = ft.ThemeMode.DARK if S.get("mode") == "dark" else ft.ThemeMode.LIGHT

    def txt(v, size=12, color=None, weight=None, **kw):
        return ft.Text(v, size=size, color=color or S["text"], weight=weight, **kw)

    def title(v, size, color=None, **kw):
        return ft.Text(v, size=size + (2 if S.get("title_font") else 0), color=color or S["text"],
                       weight=ft.FontWeight.BOLD, font_family=S.get("title_font"), **kw)

    def later(sec, fn):
        t = threading.Timer(sec, fn)
        t.daemon = True
        t.start()

    def toast(msg):
        page.open(ft.SnackBar(ft.Text(msg), duration=2500))

    # ---- navigation
    def go_page(*p):
        ui["page"] = p
        ui["confirm"] = None
        render()

    def open_shop(sid, section=None):
        """Lien direct : n'importe quel écran peut ouvrir une boutique, sur une section."""
        ui["selector"][sid] = "all"
        ui["scroll_to"] = section
        go_page("shop", sid)

    # ---- interaction
    def on_item(iid):
        st = eng.item_state(iid)
        if not st:
            return
        s = st["state"]
        if s in ("locked", "cooldown", "period", "soon"):
            flash(iid)
            toast(st["reason"])
        elif s == "activate":
            eng.toggle(iid)
            toast(f"{eng.items[iid]['label']} activé pour tout le clan")
        elif s == "active":
            toast("Déjà actif")
        elif s == "owned":
            toast("Déjà possédé")
        elif s == "buyable":
            c = ui["confirm"]
            if c and c[0] == iid:
                ui["confirm"] = None
                ok, msg = eng.buy(iid)
                if not ok:
                    flash(iid)
                toast(msg)
            else:
                token = object()
                ui["confirm"] = (iid, token)

                def expire():
                    if ui["confirm"] and ui["confirm"][1] is token:
                        ui["confirm"] = None
                        render()
                later(disp["confirm_seconds"], expire)
        render()

    def flash(iid):
        ui["flash"] = iid

        def clear():
            if ui["flash"] == iid:
                ui["flash"] = None
                render()
        later(0.9, clear)

    def confirming(iid):
        return bool(ui["confirm"] and ui["confirm"][0] == iid)

    # ---- briques visuelles
    def flag_chip(label, kind, size=9):
        return ft.Container(
            txt(label, size, "#ffffff", ft.FontWeight.BOLD),
            bgcolor=S["flag_colors"][kind], border_radius=6,
            padding=ft.padding.symmetric(2, 5))

    def pct(x):
        return math.floor(round(x * 100, 6))

    def flags_for(iid, st, size=9):
        it = eng.items[iid]
        out = []
        for f in it.get("flags") or []:
            out.append(flag_chip({"popular": "POPULAIRE", "new": "NOUVEAU"}.get(f, f.upper()), f, size))
        d = eng.discount(it)
        if d:
            out.append(flag_chip(f"-{pct(d)}%", "discount", size))
        a = eng.advantage(it)
        if a:
            out.append(flag_chip(f"-{pct(a)}% le lot", "advantage", size))
        if st and st.get("timer"):
            out.append(flag_chip(f"⏳ {human_delta(st['timer'])}", "timer", size))
        return out

    def action_bar(iid, st, size=11):
        it = eng.items[iid]
        s = st["state"]
        ref = eng.ref_label(it)
        if confirming(iid):
            label, bg, fg = f"Confirmer ? {eng.price_label(it)}", S["accent"], S["on_accent"]
        elif s == "buyable":
            label, bg, fg = eng.price_label(it), S["price_bg"], S["price_fg"]
        elif s == "activate":
            label, bg, fg = "Activer", S["activate_bg"], S["activate_fg"]
        elif s == "active":
            label, bg, fg = "✓ Actif", S["owned_bg"], S["owned_fg"]
        elif s == "owned":
            label, bg, fg = "✓ Possédé", S["owned_bg"], S["owned_fg"]
        else:
            label, bg, fg = st["reason"], S["disabled_bg"], S["text_dim"]
        content = [txt(label, size, fg, ft.FontWeight.BOLD, text_align=ft.TextAlign.CENTER,
                       max_lines=2, overflow=ft.TextOverflow.ELLIPSIS)]
        if ref and s == "buyable" and not confirming(iid):
            content.insert(0, ft.Text(ref, size=size - 2, color=S["text_dim"],
                                      style=ft.TextStyle(decoration=ft.TextDecoration.LINE_THROUGH)))
        return ft.Container(
            ft.Column(content, spacing=0, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
            bgcolor=bg, border_radius=min(8, S["card_radius"]), padding=ft.padding.symmetric(5, 6),
            alignment=ft.alignment.center)

    def picture(it, w, h, r, dim=False):
        """Image de boutique de l'item ; carré bleu tant qu'elle n'existe pas."""
        if it.get("image"):
            return ft.Container(width=w, height=h, border_radius=r, opacity=0.45 if dim else 1,
                                image=ft.DecorationImage(src=it["image"], fit=ft.ImageFit.COVER))
        return ft.Container(width=w, height=h, bgcolor=S["square"], border_radius=r,
                            opacity=0.45 if dim else 1)

    def tile(iid, st, w, h, caption=False):
        """Image de l'item de w×h, avec drapeaux ; `caption` = nom + prix incrustés."""
        it = eng.items[iid]
        s = st["state"]
        r = S["card_radius"] + 4 if caption else max(4, S["card_radius"] - 6)
        icon = {"locked": ft.Icons.LOCK, "owned": ft.Icons.CHECK_CIRCLE, "active": ft.Icons.CHECK_CIRCLE,
                "cooldown": ft.Icons.HOURGLASS_BOTTOM, "period": ft.Icons.HOURGLASS_BOTTOM}.get(s)
        big = min(w, h)
        layers = [picture(it, w, h, r, s == "locked")]
        if icon:
            layers.append(ft.Container(
                ft.Icon(icon, color=S["owned_fg"] if s in ("owned", "active") else S["overlay_icon"],
                        size=min(big * 0.3, 64)),
                width=w, height=h * (0.75 if caption else 1), alignment=ft.alignment.center))
        qty = int(it.get("quantity", 1))
        if qty > 1:
            layers.append(ft.Container(txt(f"×{qty}", 13 if not caption else 18, "#ffffff",
                                           ft.FontWeight.BOLD), right=8, top=6 if caption else None,
                                       bottom=None if caption else 4))
        fsize = 11 if caption and big > 150 else 9
        flags = flags_for(iid, st, fsize)
        if caption:     # drapeaux en ligne : la hauteur est réservée au nom et au prix
            layers.append(ft.Container(ft.Row(flags, spacing=3, wrap=True, run_spacing=3),
                                       left=6, top=6, right=40))
        else:
            layers.append(ft.Container(ft.Column(flags, spacing=3), left=6, top=6))
        if caption:
            narrow = w < 120
            small = h < 160
            name = txt(it["label"], 11 if (narrow or small) else 14, "#ffffff", ft.FontWeight.BOLD,
                       max_lines=2, overflow=ft.TextOverflow.ELLIPSIS)
            bar = action_bar(iid, st, 10 if (narrow or small) else 12)
            inner = (ft.Column([name, bar], spacing=4) if narrow else
                     ft.Row([ft.Container(name, expand=True), ft.Container(bar, width=min(150, w * 0.48))],
                            vertical_alignment=ft.CrossAxisAlignment.CENTER))
            layers.append(ft.Container(
                inner, left=0, right=0, bottom=0, padding=6 if small else 8, bgcolor=S["caption_bg"],
                border_radius=ft.border_radius.only(bottom_left=r, bottom_right=r)))
        border = None
        if ui["flash"] == iid:
            border = ft.border.all(3, S["error"])
        elif confirming(iid) and caption:
            border = ft.border.all(3, S["accent"])
        return ft.Container(ft.Stack(layers, width=w, height=h), width=w, height=h,
                            border=border, border_radius=r,
                            on_click=(lambda e, i=iid: on_item(i)) if caption else None)

    def card_border(iid):
        if ui["flash"] == iid:
            return ft.border.all(2, S["error"])
        if confirming(iid):
            return ft.border.all(2, S["accent"])
        return ft.border.all(1, S["card_border"])

    def card(iid, st, width):
        it = eng.items[iid]
        sq = width - 14
        return ft.Container(
            ft.Column([
                tile(iid, st, sq, sq),
                txt(it["label"], 11, weight=ft.FontWeight.W_600, max_lines=2,
                    overflow=ft.TextOverflow.ELLIPSIS),
                txt(it.get("subtitle", ""), 9, S["text_dim"], max_lines=1,
                    overflow=ft.TextOverflow.ELLIPSIS),
                action_bar(iid, st),
            ], spacing=4),
            width=width, padding=7, border_radius=S["card_radius"],
            bgcolor=S["card_locked"] if st["state"] == "locked" else S["card"],
            border=card_border(iid), on_click=lambda e, i=iid: on_item(i),
            animate=ft.Animation(200, ft.AnimationCurve.EASE_OUT))

    def showcase_card(iid, st, width):
        """Grande vitrine pleine largeur (mise en page `showcase`)."""
        it = eng.items[iid]
        iw = width - 16
        return ft.Container(
            ft.Column([
                tile(iid, st, iw, int(iw / 2)),
                ft.Row([
                    ft.Column([txt(it["label"], 15, weight=ft.FontWeight.BOLD),
                               txt(it.get("subtitle", ""), 11, S["text_dim"])], spacing=0, expand=True),
                    ft.Container(action_bar(iid, st, 12), width=150),
                ], vertical_alignment=ft.CrossAxisAlignment.CENTER),
            ], spacing=8),
            width=width, padding=8, border_radius=S["card_radius"],
            bgcolor=S["card_locked"] if st["state"] == "locked" else S["card"],
            border=card_border(iid), on_click=lambda e, i=iid: on_item(i),
            animate=ft.Animation(200, ft.AnimationCurve.EASE_OUT))

    # ---- ce que le spectateur voit
    def section_conf(sec_id):
        return next((s for s in shop["sections"] if s["id"] == sec_id), {})

    def visible_items(section_id):
        out = []
        for iid, it in sorted(eng.items.items(), key=lambda kv: kv[1].get("rank", 999)):
            if it.get("section") != section_id:
                continue
            st = eng.item_state(iid)
            if st:
                out.append((iid, st))
        return out

    def visible_sections(sid):
        if sid in ui["emptied"]:
            return []
        out = []
        wanted = shops[sid]["sections"]
        for sec in sorted(shop["sections"], key=lambda s: s.get("rank", 999)):
            if sec["id"] not in wanted or not eng.tags_ok(sec):
                continue
            items = visible_items(sec["id"])
            if items:
                out.append((sec, items))
        return out

    def visible_highlights(sid):
        out = []
        ids = shops[sid].get("highlights") or []
        for hl in sorted(shop.get("highlights") or [], key=lambda h: h.get("rank", 999)):
            if hl["id"] not in ids or not eng.tags_ok(hl):
                continue
            items = []
            for iid in hl["items"]:
                if not eng.tags_ok(section_conf(eng.items[iid].get("section"))):
                    continue
                st = eng.item_state(iid)
                if st:
                    items.append((iid, st))
            if items:
                out.append((hl, items))
        return out

    # ---- pastilles d'une tuile : calculées sur le contenu de la boutique
    def badges(sid):
        free = new = 0
        disc = adv = 0.0
        for sec, items in visible_sections(sid):
            for iid, st in items:
                it = eng.items[iid]
                if st["state"] == "buyable":
                    if it["price"]["kind"] == "free":
                        free += 1
                    disc = max(disc, eng.discount(it) or 0)
                    adv = max(adv, eng.advantage(it) or 0)
                if "new" in (it.get("flags") or []) and st["state"] in ("buyable", "locked"):
                    new += 1
        out = []
        for b in hub.get("badges") or []:
            if b == "free" and free:
                out.append(flag_chip(f"{free} cadeau{'x' if free > 1 else ''}", "new", 10))
            elif b == "new" and new:
                out.append(flag_chip("NOUVEAU", "popular", 10))
            elif b == "discount" and disc:
                out.append(flag_chip(f"-{pct(disc)}%", "discount", 10))
            elif b == "advantage" and adv:
                out.append(flag_chip(f"-{pct(adv)}% le lot", "advantage", 10))
        return out[:2]

    # ---- carrousel : les items remplissent tout le panneau
    def mosaic(items, W, Ht, g=8):
        n = len(items)
        t = lambda k, w, h: tile(items[k][0], items[k][1], int(w), int(h), caption=True)
        if n == 1:
            return t(0, W, Ht)
        if n == 2:
            return ft.Row([t(0, (W - g) / 2, Ht), t(1, (W - g) / 2, Ht)], spacing=g)
        if n == 3:                                     # un grand + deux petits (cf. 5.jpg)
            bw = (W - g) * 0.56
            return ft.Row([t(0, bw, Ht), ft.Column([t(1, W - g - bw, (Ht - g) / 2),
                                                    t(2, W - g - bw, (Ht - g) / 2)], spacing=g)], spacing=g)
        cols = 2 if n == 4 else 3
        rows = math.ceil(n / cols)
        w, h = (W - g * (cols - 1)) / cols, (Ht - g * (rows - 1)) / rows
        return ft.Column([ft.Row([t(k, w, h) for k in range(r * cols, min(n, (r + 1) * cols))], spacing=g)
                          for r in range(rows)], spacing=g)

    def carousel(sid, PW):
        hls = visible_highlights(sid)
        if not hls:
            return None
        idx = ui["hl"].get(sid, 0) % len(hls)
        ui["hl"][sid] = idx
        hl, items = hls[idx]

        def go(step):
            ui["hl"][sid] = (idx + step) % len(hls)
            render()

        pad, head_h, gap = 12, 62, 8
        Ht = disp["highlight_height"]
        head = [title(hl["title"], 20, S["panel_title"]),
                txt(hl.get("subtitle", ""), 12, S["panel_subtitle"])]
        right = None
        if hl.get("until"):
            left = datetime.fromisoformat(hl["until"]) - eng.now
            if left.total_seconds() > 0:
                right = flag_chip(f"⏳ Plus que {human_delta(left)}", "timer", 11)
        header = ft.Container(ft.Row([ft.Column(head, spacing=0, expand=True)] + ([right] if right else []),
                                     vertical_alignment=ft.CrossAxisAlignment.START), height=head_h)
        panel = ft.Container(
            ft.Column([header, mosaic(items, PW - 2 * pad, Ht - 2 * pad - head_h - gap)], spacing=gap),
            padding=pad, border_radius=S["card_radius"] + 8, height=Ht, width=PW,
            border=ft.border.all(1, S["panel_border"]),
            gradient=ft.LinearGradient(begin=ft.alignment.top_left, end=ft.alignment.bottom_right,
                                       colors=S["panel_gradient"]))

        def on_swipe(e: ft.DragEndEvent):
            v = e.velocity_x or 0
            if abs(v) > 50:
                go(1 if v < 0 else -1)

        layers = [panel]
        if len(hls) > 1:
            mid = (Ht - 44) / 2 + head_h / 2
            for icon, step, pos in ((ft.Icons.CHEVRON_LEFT, -1, {"left": 2}),
                                    (ft.Icons.CHEVRON_RIGHT, 1, {"right": 2})):
                layers.append(ft.Container(
                    ft.Icon(icon, color=S["arrows"], size=26), width=30, height=44, top=mid,
                    bgcolor="#40000000", border_radius=10, alignment=ft.alignment.center,
                    on_click=lambda e, st=step: go(st), **pos))
        out = [ft.GestureDetector(ft.Stack(layers, width=PW, height=Ht), on_horizontal_drag_end=on_swipe)]
        if len(hls) > 1:
            out.append(ft.Row([
                ft.Container(width=18 if i == idx else 8, height=8, border_radius=4,
                             bgcolor=S["accent"] if i == idx else S["dots_off"],
                             on_click=lambda e, i=i: (ui["hl"].__setitem__(sid, i), render()),
                             animate=ft.Animation(200))
                for i in range(len(hls))], alignment=ft.MainAxisAlignment.CENTER, spacing=6))
        return ft.Column(out, spacing=8)

    # ---- sélecteurs : passent à la ligne plutôt que de défiler (rien de caché)
    def selector_bar(sid, sections):
        present = {s["id"] for s, _ in sections}
        chips = []
        for sel in shops[sid].get("selectors") or []:
            secs = sel["sections"]
            if secs != "*" and not (set(secs) & present):
                continue
            on = ui["selector"].get(sid, "all") == sel["id"]
            chips.append(ft.Container(
                txt(sel["label"], 13, S["on_accent"] if on else S["text"], ft.FontWeight.W_600),
                bgcolor=S["accent"] if on else S["chip_bg"], border_radius=20,
                padding=ft.padding.symmetric(7, 14),
                on_click=lambda e, i=sel["id"]: (ui["selector"].__setitem__(sid, i), render())))
        return ft.Row(chips, wrap=True, spacing=8, run_spacing=8) if len(chips) > 1 else None

    # ---- panneau de simulation (outil de la maquette, pas du produit)
    def sim_panel():
        def tag_cb(t):
            def ch(e):
                (eng.tags.add if e.control.value else eng.tags.discard)(t)
                render()
            return ft.Checkbox(label=shop["tags"][t].get("label", t), value=t in eng.tags,
                               on_change=ch, label_style=ft.TextStyle(size=11, color=S["text"]))

        def chip(label, on, fn):
            return ft.Container(txt(label, 11, S["on_accent"] if on else S["text"]),
                                bgcolor=S["accent"] if on else S["chip_bg"], border_radius=10,
                                padding=ft.padding.symmetric(4, 8), on_click=lambda e: (fn(), render()))

        def add_days(n):
            eng.now += timedelta(days=n)

        def reset():
            eng.reset()
            ui["confirm"] = None

        themed = [(lk["item"], eng.items[lk["item"]]["label"]) for n, lk in looks.items()
                  if isinstance(lk, dict) and lk.get("item")]
        lines = []
        for r in eng.purchases[-5:][::-1]:
            exp = ""
            if r["expires_at"]:
                exp = " (expiré)" if r["expires_at"] <= eng.now else f" exp. {r['expires_at']:%d/%m %Hh}"
            lines.append(txt(f"{r['acquired_at']:%d/%m} {r['item']} · owner={r['owner_id']} "
                             f"group={r['group_id'] or '-'} · {list(r['proof'])[0]}{exp}",
                             9, S["text_dim"], font_family="Consolas"))
        return ft.Container(ft.Column([
            txt(f"SIMULATION · {eng.now:%d/%m/%Y %Hh}", 11, S["accent"], ft.FontWeight.BOLD),
            ft.Row([tag_cb(t) for t in shop["tags"]], wrap=True, spacing=0, run_spacing=0),
            ft.Row([txt("Marché", 11)] + [chip(m, eng.market == m, lambda m=m: setattr(eng, "market", m))
                                         for m in eng.sim["markets"]], spacing=6, wrap=True),
            ft.Row([txt("Thème du clan", 11)] + [chip(lbl, eng.active.get("theme") == iid,
                                                      lambda iid=iid: eng.toggle(iid))
                                                 for iid, lbl in themed], spacing=6, wrap=True),
            ft.Row([chip("+500 or", False, lambda: setattr(eng, "gold", eng.gold + 500)),
                    chip("+1 jour", False, lambda: add_days(1)),
                    chip("+7 jours", False, lambda: add_days(7)),
                    chip("Reset", False, reset)], wrap=True, spacing=6),
            ft.Row([txt("Vider", 11)] + [chip(sid, sid in ui["emptied"],
                                              lambda sid=sid: ui["emptied"].symmetric_difference_update({sid}))
                                         for sid in shops], spacing=6, wrap=True),
            ft.Row([txt("Lien direct", 11),
                    chip("Objets › Armurerie", False, lambda: open_shop("objets", "armurerie")),
                    chip("Thèmes › Mascottes", False, lambda: open_shop("themes", "mascottes"))],
                   wrap=True, spacing=6),
            txt("Table store (dernières lignes)", 10, S["text_dim"]),
            *lines,
        ], spacing=6), bgcolor=S["sim_bg"], border_radius=12, padding=10,
            border=ft.border.all(1, S["sim_border"]))

    def sim_button(color):
        return ft.IconButton(ft.Icons.SCIENCE_OUTLINED, icon_color=color, tooltip="Simulation (maquette)",
                             on_click=lambda e: (ui.__setitem__("sim", not ui["sim"]), render()))

    def gold_pill():
        gold = shop["currencies"]["gold"]
        return ft.Container(txt(f"{eng.gold} {gold['symbol']}", 14, S["price_fg"], ft.FontWeight.BOLD),
                            bgcolor=S["chip_bg"], border_radius=16, padding=ft.padding.symmetric(5, 12))

    # ---- page d'entrée : l'écran Boutique de ddust, dont le corps devient des tuiles
    def tile_art(t, w, h):
        kind = t.get("art")
        if kind == "vitrine":
            # La vitrine d'un AUTRE thème que celui qu'on habite : la tuile donne envie de
            # changer. Image ENTIÈRE à son format (`ratio`, 2:1), centrée, jamais recadrée.
            group = t.get("toggle_group", "theme")
            active = eng.active.get(group)
            ids = sorted((i for i, it in eng.items.items()
                          if it.get("toggle_group") == group and it.get("image") and not it.get("retired")),
                         key=lambda i: eng.items[i].get("rank", 999))
            pick = next((i for i in ids if i != active), active if not ids else ids[0])
            img = eng.items.get(pick, {}).get("image")
            if img:
                ratio = float(t.get("ratio", 2.0))
                iw, ih = w, w / ratio
                if ih > h:
                    ih, iw = h, h * ratio
                return ft.Container(ft.Container(width=iw, height=ih, border_radius=8,
                                                 image=ft.DecorationImage(src=img, fit=ft.ImageFit.COVER)),
                                    width=w, height=h, alignment=ft.alignment.center)
        if kind == "stack":
            sq = h - 16
            return ft.Container(ft.Stack([
                ft.Container(width=sq, height=sq, bgcolor=S["square"], border_radius=8, left=w / 2 - sq / 2 - 26,
                             top=10, rotate=ft.Rotate(-0.25), opacity=0.6),
                ft.Container(width=sq, height=sq, bgcolor=S["square"], border_radius=8, left=w / 2 - sq / 2 + 26,
                             top=10, rotate=ft.Rotate(0.25), opacity=0.8),
                ft.Container(width=sq, height=sq, bgcolor=S["square"], border_radius=8, left=w / 2 - sq / 2,
                             top=4),
            ]), width=w, height=h)
        if kind == "row":
            sq = h - 8
            n = max(1, int((w + 8) // (sq + 8)))
            return ft.Row([ft.Container(width=sq, height=sq, bgcolor=S["square"], border_radius=8)
                           for _ in range(n)], spacing=8, alignment=ft.MainAxisAlignment.CENTER, width=w)
        if kind == "giftwrap":
            c1, c2 = H["giftwrap"]
            return ft.Container(ft.Stack([
                ft.Container(width=14, bgcolor=H["ribbon"], left=w / 2 - 7, top=0, bottom=0),
                ft.Container(height=14, bgcolor=H["ribbon"], left=0, right=0, top=h / 2 - 7),
                ft.Container(ft.Text("🎀", size=38), left=w / 2 - 26, top=h / 2 - 32),
            ]), width=w, height=h, border_radius=8,
                gradient=ft.LinearGradient(colors=[c1, c2], begin=ft.alignment.top_left,
                                           end=ft.alignment.bottom_right))
        if kind == "crown":
            return ft.Container(ft.Icon(ft.Icons.WORKSPACE_PREMIUM, color=S["accent"], size=h * 0.7),
                                width=w, height=h, alignment=ft.alignment.center, border_radius=8,
                                bgcolor=S["chip_bg"])
        return ft.Container(width=w, height=h, bgcolor=S["square"], border_radius=8)

    def hub_tile(t, w, h):
        kind = t["kind"]
        # UNE BOUTIQUE VIDE GARDE SA PLACE (comme l'app) : aucun item visible pour ce
        # spectateur → la tuile reste, mais ne dit que « Bientôt » (c'est un secret : ni
        # titre ni sous-titre), sur ses petites cartes translucides gardées à leur taille.
        empty = kind == "shop" and not visible_sections(t["shop"])
        soon = hub.get("soon", "Bientôt")
        if empty:
            on_click = lambda e: toast(soon)
            pills = []
        elif kind == "shop":
            on_click = lambda e, sid=t["shop"]: open_shop(sid)
            pills = badges(t["shop"])
        else:
            on_click = lambda e, k=kind: go_page(k)
            pills = []
        art_h = h - 66
        if empty:
            body = ft.Container(ft.Container(tile_art(t, w - 20, art_h), opacity=0.35),
                                width=w - 20, height=h - 20, alignment=ft.alignment.center)
        else:
            body = ft.Column([
                tile_art(t, w - 20, art_h),
                ft.Text(t["label"], size=15, weight=ft.FontWeight.BOLD, color=H["tile_title"],
                        font_family=S.get("title_font"), max_lines=1, overflow=ft.TextOverflow.ELLIPSIS),
                ft.Text(t.get("subtitle", ""), size=11, color=H["tile_text"], max_lines=1,
                        overflow=ft.TextOverflow.ELLIPSIS),
            ], spacing=2)
        layers = [ft.Container(body, padding=10, width=w, height=h)]
        if empty:
            layers.append(ft.Container(
                ft.Container(ft.Text(soon, size=16, weight=ft.FontWeight.BOLD, color=H["tile_title"],
                                     font_family=S.get("title_font")),
                             bgcolor=S["chip_bg"], border=ft.border.all(1, H["tile_border"]),
                             border_radius=20, padding=ft.padding.symmetric(8, 16)),
                left=0, right=0, top=0, bottom=0, alignment=ft.alignment.center))
        if pills:
            layers.append(ft.Container(ft.Row(pills, spacing=4), right=6, top=6))
        return ft.Container(ft.Stack(layers, width=w, height=h), width=w, height=h,
                            bgcolor=H["tile_bg"], border=ft.border.all(1.5, H["tile_border"]),
                            border_radius=S["card_radius"] + 4, on_click=on_click)

    def taskbar():
        icons = [ft.Icons.STOREFRONT, ft.Icons.SHIELD_OUTLINED, None, ft.Icons.PERSON_OUTLINE,
                 ft.Icons.AUTO_AWESOME_OUTLINED]
        cells = []
        for i, label in enumerate(hub.get("taskbar") or []):
            if icons[i] is None:
                cells.append(ft.Container(
                    ft.Icon(ft.Icons.PETS if ui["look"] == "dino" else ft.Icons.SPORTS_MARTIAL_ARTS,
                            color=H["taskbar_fg"] if ui["look"] != "dino" else "#ffffff", size=30),
                    width=64, height=64, border_radius=32, bgcolor=H["taskbar_center"],
                    alignment=ft.alignment.center))
                continue
            sel = i == 0
            cells.append(ft.Container(ft.Column([
                ft.Icon(icons[i], color=H["taskbar_fg"], size=24),
                ft.Text(label, size=10, color=H["taskbar_fg"]),
                ft.Container(width=40, height=3, bgcolor=H["taskbar_fg"] if sel else None, border_radius=2),
            ], spacing=1, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                # l'onglet Boutique ramène à la page d'entrée, d'où que l'on soit
                on_click=(lambda e: go_page("hub")) if sel else None))
        return ft.Container(ft.Row(cells, alignment=ft.MainAxisAlignment.SPACE_AROUND,
                                   vertical_alignment=ft.CrossAxisAlignment.CENTER),
                            bgcolor=H["taskbar_bg"], height=72, padding=ft.padding.symmetric(0, 6))

    def hub_view():
        W = (page.width or 412) - 16 - 24
        appbar = ft.Container(ft.Row([
            ft.Text(hub["title"], size=24, color=H["appbar_fg"]),
            sim_button(H["appbar_fg"]),
        ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN), bgcolor=H["appbar_bg"],
            padding=ft.padding.only(16, 6, 6, 6))
        m = 128
        header = ft.Stack([
            ft.Container(width=m, height=m, border_radius=m / 2, left=(W + 24 - m) / 2, top=0,
                         border=ft.border.all(4, H["merchant_ring"]), bgcolor=S["card"],
                         image=ft.DecorationImage(src=H["merchant"], fit=ft.ImageFit.COVER)),
            ft.Container(ft.Text(hub["sign"], size=24, color=H["sign_fg"], font_family="MedievalSharp",
                                 text_align=ft.TextAlign.CENTER),
                         left=12, right=12, top=m - 26, height=62, alignment=ft.alignment.center,
                         bgcolor=H["sign_bg"], border=ft.border.all(1.5, H["sign_border"]),
                         border_radius=H["sign_radius"]),
        ], height=m + 40)

        tiles = [t for t in hub["tiles"] if eng.tags_ok(t)]
        rows, cur, used = [], [], 0
        for t in tiles:
            span = int(t.get("span", 1))
            if used + span > 2:
                rows.append(cur)
                cur, used = [], 0
            cur.append(t)
            used += span
        if cur:
            rows.append(cur)
        th = 172
        grid = [ft.Row([hub_tile(t, W if int(t.get("span", 1)) == 2 or len(r) == 1 else (W - 10) / 2, th)
                        for t in r], spacing=10) for r in rows]
        if not grid:
            grid = [ft.Container(ft.Text(hub.get("empty", "Bientôt"), size=18, weight=ft.FontWeight.BOLD,
                                         color=H["tile_title"], font_family=S.get("title_font"),
                                         text_align=ft.TextAlign.CENTER),
                                 width=W, padding=ft.padding.symmetric(40, 16), alignment=ft.alignment.center,
                                 bgcolor=H["tile_bg"], border=ft.border.all(1.5, H["tile_border"]),
                                 border_radius=S["card_radius"] + 4)]
        content = [header]
        if ui["sim"]:
            content.append(sim_panel())
        content += grid
        return ft.Container(ft.Column([
            appbar,
            ft.Container(ft.Column(content, spacing=12, scroll=ft.ScrollMode.AUTO),
                         expand=True, padding=ft.padding.symmetric(8, 12)),
        ], spacing=0, expand=True), expand=True,
            image=ft.DecorationImage(src=H["background"], fit=ft.ImageFit.COVER))

    # ---- une boutique dédiée
    def back_bar(label, extra=None):
        return ft.Row([
            ft.Row([ft.IconButton(ft.Icons.ARROW_BACK, icon_color=S["text"], on_click=lambda e: go_page("hub")),
                    title(label, 20)], spacing=0, expand=True),
            ft.Row(([extra] if extra else []) + [sim_button(S["text"])], spacing=0),
        ])

    def shop_view(sid):
        sh = shops[sid]
        sections = visible_sections(sid)
        sel_id = ui["selector"].get(sid, "all")
        sel = next((s for s in sh.get("selectors") or [] if s["id"] == sel_id), {"sections": "*"})
        shown = [(s, items) for s, items in sections
                 if sel["sections"] == "*" or s["id"] in sel["sections"]]
        avail = (page.width or 412) - 24 - 14          # marges + barre de défilement

        # La réserve de la monnaie que la boutique déclare (`currency`), et seulement elle.
        controls = [back_bar(sh["title"], gold_pill() if sh.get("currency") else None)]
        if ui["sim"]:
            controls.append(sim_panel())
        car = carousel(sid, avail)
        if car:
            controls.append(car)
        bar = selector_bar(sid, sections)
        if bar:
            controls.append(bar)
        cols = disp["columns"]
        width = int((avail - (cols - 1) * 8) / cols)
        for sec, items in shown:
            controls.append(title(sec["label"], 16, key=f"sec_{sec['id']}"))
            if sec.get("layout") == "showcase":
                controls.append(ft.Column([showcase_card(i, st, avail) for i, st in items], spacing=10))
            else:
                controls.append(ft.Row([card(i, st, width) for i, st in items],
                                       wrap=True, spacing=8, run_spacing=8,
                                       vertical_alignment=ft.CrossAxisAlignment.START))
        if not shown:
            controls.append(txt("Rien à voir ici pour l'instant.", 13, S["text_dim"]))
        shop_body.controls = controls
        return shop_wrap

    # ---- code cadeau et abonnement : leurs propres pages, plus de kebab
    def giftcode_view():
        W = (page.width or 412) - 24 - 14
        field = ft.TextField(label="Ton code (12 signes)", max_length=12, capitalization=ft.TextCapitalization.CHARACTERS,
                             border_color=S["card_border"], color=S["text"])
        return ft.Container(ft.Column([
            back_bar("Code cadeau"),
            tile_art({"art": "giftwrap"}, W, 170),
            txt("Quelqu'un t'a offert un code ? Saisis-le ici pour ouvrir ton cadeau.", 13),
            field,
            ft.Container(txt("Ouvrir le cadeau", 14, S["on_accent"], ft.FontWeight.BOLD),
                         bgcolor=S["accent"], border_radius=10, padding=12, alignment=ft.alignment.center,
                         on_click=lambda e: toast("Code inconnu (maquette : store_claim → status invalid)")),
        ], spacing=14), padding=ft.padding.only(12, 4, 12, 12), expand=True)

    def subscription_view():
        W = (page.width or 412) - 24 - 14
        return ft.Container(ft.Column([
            back_bar("Mon abonnement"),
            tile_art({"art": "crown"}, W, 150),
            ft.Container(ft.Column([
                title("Formule Clan", 18),
                txt("3 à 4 joueurs · 2,99 €/mois", 13, S["text_dim"]),
                txt("Prochain renouvellement le 13/11/2026", 12, S["text_dim"]),
            ], spacing=4), bgcolor=S["card"], border=ft.border.all(1, S["card_border"]),
                border_radius=S["card_radius"], padding=14, width=W),
            ft.Container(txt("Changer de formule", 14, S["on_accent"], ft.FontWeight.BOLD),
                         bgcolor=S["accent"], border_radius=10, padding=12, alignment=ft.alignment.center,
                         on_click=lambda e: toast("→ tiers_page (paliers)")),
            ft.Container(txt("Gérer dans Google Play", 13, S["text"]),
                         bgcolor=S["chip_bg"], border_radius=10, padding=12, alignment=ft.alignment.center,
                         on_click=lambda e: toast("→ store.manage")),
        ], spacing=14), padding=ft.padding.only(12, 4, 12, 12), expand=True)

    # ---- rendu complet
    def render():
        apply_look()
        p = ui["page"]
        if p[0] == "shop":
            view = shop_view(p[1])
        elif p[0] == "giftcode":
            view = giftcode_view()
        elif p[0] == "subscription":
            view = subscription_view()
        else:
            view = hub_view()
        # La dvtaskbar n'est jamais masquée : elle encadre toutes les pages de la boutique.
        frame.controls = [view, taskbar()]
        root.content = frame
        changed = ui["shown_page"] != p
        ui["shown_page"] = p
        page.update()
        if p[0] == "shop":
            if ui["scroll_to"]:
                key = f"sec_{ui['scroll_to']}"
                ui["scroll_to"] = None
                # après la mise en page : la section doit exister à l'écran pour qu'on y défile
                later(0.4, lambda: shop_body.scroll_to(key=key, duration=400))
            elif changed:
                shop_body.scroll_to(offset=0, duration=0)

    page.on_resized = lambda e: render()
    render()

    shot = os.environ.get("SHOP_SHOT")
    if shot:
        # Contrôle visuel : capture de la fenêtre puis fermeture.
        page.window.left, page.window.top = 20, 20
        page.window.always_on_top = True
        page.update()

        def grab():
            import ctypes
            import ctypes.wintypes
            from PIL import ImageGrab
            ctypes.windll.user32.SetProcessDPIAware()
            hwnd = ctypes.windll.user32.FindWindowW(None, page.title)
            r = ctypes.wintypes.RECT()
            ctypes.windll.user32.GetWindowRect(hwnd, ctypes.byref(r))
            ImageGrab.grab(bbox=(r.left, r.top, r.right, r.bottom), all_screens=True).save(shot)
            page.window.destroy()
        later(float(os.environ.get("SHOP_SHOT_DELAY", "4")), grab)


if __name__ == "__main__":
    assets = str(Path(__file__).with_name("assets"))
    port = os.environ.get("SHOP_WEB")
    if port:
        ft.app(target=main, view=None, port=int(port), assets_dir=assets)
    else:
        ft.app(target=main, assets_dir=assets)
