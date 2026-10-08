// -----------------------------------------------------------------------------
// --- This file is part of the DEVA framework
// --- Copyright (C) 2026 Griseloupe - deva@grisloup.com
//
// This file is part of DEVA.
//
// DEVA is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// DEVA is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Dependencies
// -----------------------------------------------------------------------------

part of 'worker.dart';

// -----------------------------------------------------------------------------
// --- worker extension : Parrainage de clans
// -----------------------------------------------------------------------------
// Conception : tmp/design_parrainage.md. Les règles vivent au serveur (pureferral), les
// appels et les valeurs `referral.*` dans le module dvreferral : ce fichier ne fait que
// garder les portes (chef adulte, porte parentale) et poser les libellés.
//
// ⚠ AUCUNE INFORMATION SUR UN FILLEUL n'est affichée, et le serveur n'en rend aucune.
extension Worker_referral on worker {

    void _register_referral() {

                                // Kebab de l'écran Clan (chefs adultes), et tap d'une notification
                                // de parrainage (« un nouveau clan est né grâce à vous », titre).
                                ActionRegistry.register("worker.open_referral",               open_referral);
                                ActionRegistry.register("worker.open_referral_declare",       open_referral_declare);
                                ActionRegistry.register("worker.referral_gate_passed",        referral_gate_passed);

                                ActionRegistry.register("worker.on_referral_appear",          on_referral_appear);
                                ActionRegistry.register("worker.on_referral_copy",            on_referral_copy);
                                ActionRegistry.register("worker.on_referral_share",           on_referral_share);
                                ActionRegistry.register("worker.on_referral_rotate",          on_referral_rotate);

                                ActionRegistry.register("worker.on_referral_declare_appear",  on_referral_declare_appear);
                                ActionRegistry.register("worker.on_referral_declare_confirm", on_referral_declare_confirm);
                                ActionRegistry.register("worker.on_referral_declare_close",   on_referral_declare_close);
    }

    String _rt(String key) => TranslationRegistry.processLabel("@@@T:$key@@@");

    // -----------------------------------------------------------------------
    // --- Portes
    // -----------------------------------------------------------------------

    // « J'ai un parrain » se propose-t-il encore ? Pas une fois un parrain déclaré (miroir
    // `referral.declared` du doc du clan, écrit par le serveur), ni une fois le clan abonné :
    // la déclaration se fait AVANT le premier abonnement payé. Le serveur refait le contrôle
    // (`already`, `paid`) : masquer n'est pas interdire. Lecture en échec : option masquée.
    Future<bool> _referralCanDeclare(String clanId, String clanSecret, String region) async {

                                try {
                                    if (await _storeSubscribed()) return false;
                                    final doc = await _cloud?.read("workers", "clans", clanId, ownerId: clanSecret, region: region);
                                    return doc != null && doc.get("referral.declared") != true;
                                } catch (e) {
                                    deva_log("warning", "[referral] état de déclaration illisible : $e");
                                    return false;
                                }
    }

    // Les deux écrans passent par la porte parentale (programme Familles : un partage et
    // une saisie liés à un échange hors de l'app), après la garde du chef adulte.
    // dvparentalgate ne rend rien à l'appelant : l'écran visé est mis de côté.
    Future<void> _referralGated(String page) async {

                                if (!await _storeCanBuy()) {
                                    deva_log("info", "[referral] $page refusé : $_userId n'est pas chef adulte du clan");
                                    return;
                                }
                                final gate = ActionRegistry.get("parentalgate.invoke_gate");
                                if (gate == null) {
                                    deva_log("error", "[referral] contrôle parental indisponible : $page abandonné");
                                    return;
                                }
                                _referralPendingPage = page;
                                await gate.call(null, {
                                    "mode":       "defi_calcul",
                                    "on_success": "worker.referral_gate_passed",
                                });
    }

    Future<void> open_referral(dynamic caller, dynamic event) async {

                                await _referralGated("referral_page");
    }

    Future<void> open_referral_declare(dynamic caller, dynamic event) async {

                                await _referralGated("referral_declare_page");
    }

    // Porte franchie. ⚠ LA PORTE NE SE REFERME PAS D'ELLE-MÊME (cf. store_gate_passed) :
    // on la quitte, on attend que la page d'en dessous redevienne courante, puis on ouvre.
    Future<void> referral_gate_passed(dynamic caller, dynamic event) async {

                                final page = _referralPendingPage;
                                _referralPendingPage = "";
                                if (page.isEmpty) return;
                                bool onGate() => DvOrb.get_current_page()?.dvid == "parentalgate_screen";
                                if (onGate()) {
                                    DvOrb.navigate_back();
                                    for (var i = 0; i < 20 && onGate(); i++) {
                                        await Future.delayed(const Duration(milliseconds: 50));
                                    }
                                }
                                DvOrb.navigate_new(page);
    }

    // -----------------------------------------------------------------------
    // --- Écran « Parrainage »
    // -----------------------------------------------------------------------

    void _referralLabel(String id, String text, {bool? visible}) {

                                final s = DvOrb.get_shape_by_id(id);
                                if (s == null) return;
                                s.set("shape.label", text);
                                if (visible != null) s.set("shape.visible", visible);
                                if (s is DvLabel) {
                                    s.write(text);
                                } else {
                                    s.refreshUI();
                                }
    }

    Future<void> _referralInfo(String key) async {

                                _referralLabel("referral_page/info", key.isEmpty ? "" : _rt(key), visible: key.isNotEmpty);
    }

    Future<void> on_referral_appear(dynamic caller, dynamic event) async {

                                await DvOrb.wait_for_shape("referral_page/stats");
                                await _referralInfo("");
                                _referralLabel("referral_page/code", "…");
                                final res = await ActionRegistry.get("referral.refresh")?.call(null, null);
                                final status = res is Dvidle ? (res.get("status")?.toString() ?? "network") : "network";
                                if (status != "ok") {
                                    _referralLabel("referral_page/code", "");
                                    await _referralInfo(status == "not_admin" ? "referral_err_not_admin" : "referral_err_network");
                                    return;
                                }
                                await _referralFill();
    }

    // Les libellés de l'écran, depuis les valeurs publiées par dvreferral.
    Future<void> _referralFill() async {

                                Future<String> v(String k) async => (await deva_get("referral.$k"))?.toString() ?? "";
                                Future<int> n(String k) async => int.tryParse(await v(k)) ?? 0;

                                _referralLabel("referral_page/code", await v("code"));

                                // Un titre : son nom (ou « aucun titre encore »), puis le palier suivant.
                                Future<String> titleLine(String series, String headKey) async {
                                    final name = await v("title_$series");
                                    final next = await n("next_$series");
                                    final nextName = await v("next_title_$series");
                                    var line = _rt(headKey) + "\n" + (name.isEmpty ? _rt("referral_no_title") : "« $name »");
                                    if (next > 0 && nextName.isNotEmpty) {
                                        line += "\n" + _rt(next > 1 ? "referral_next_many" : "referral_next_one")
                                            .replaceAll("{n}", "$next").replaceAll("{title}", nextName);
                                    }
                                    return line;
                                }
                                _referralLabel("referral_page/titles",
                                    "${await titleLine("lineage", "referral_series_lineage")}\n\n"
                                    "${await titleLine("active", "referral_series_active")}");

                                _referralLabel("referral_page/stats", _rt("referral_stats")
                                    .replaceAll("{lineage}",    "${await n("lineage")}")
                                    .replaceAll("{active}",     "${await n("active")}")
                                    .replaceAll("{active_max}", "${await n("active_max")}")
                                    .replaceAll("{months}",     "${await n("months_granted")}")
                                    .replaceAll("{stock}",      "${await n("stock")}")
                                    .replaceAll("{cap}",        "${await n("cap")}"));
    }

    Future<void> on_referral_copy(dynamic caller, dynamic event) async {

                                final res = await ActionRegistry.get("referral.copy")?.call(null, null);
                                await _referralInfo(res == true ? "referral_copied" : "referral_err_copy");
    }

    Future<void> on_referral_share(dynamic caller, dynamic event) async {

                                if (((await deva_get("referral.code"))?.toString() ?? "").isEmpty) return;
                                final fut = ActionRegistry.get("share.referral_code")?.call(caller, event);
                                if (fut is Future) await fut;
    }

    Future<void> on_referral_rotate(dynamic caller, dynamic event) async {

                                final res = await ActionRegistry.get("referral.rotate")?.call(null, null);
                                final ok = res is Dvidle && res.get("status")?.toString() == "ok";
                                if (ok) await _referralFill();
                                await _referralInfo(ok ? "referral_rotated" : "referral_err_network");
    }

    // -----------------------------------------------------------------------
    // --- Écran « J'ai un parrain »
    // -----------------------------------------------------------------------

    void _referralDeclareError(String key) {

                                _referralLabel("referral_declare_page/error", key.isEmpty ? "" : _rt(key), visible: key.isNotEmpty);
    }

    void _referralDeclareOk(bool v) {

                                for (final id in const ["referral_declare_page/ok_scrim",
                                                        "referral_declare_page/ok_panel",
                                                        "referral_declare_page/ok_close"]) {
                                    final s = DvOrb.get_shape_by_id(id);
                                    s?.set("shape.visible", v);
                                    s?.refreshUI();
                                }
    }

    Future<void> on_referral_declare_appear(dynamic caller, dynamic event) async {

                                final code = await DvOrb.wait_for_shape("referral_declare_page/code");
                                code?..set("shape.value", "")..refreshUI();
                                _referralDeclareError("");
                                _referralDeclareOk(false);
    }

    Future<void> on_referral_declare_confirm(dynamic caller, dynamic event) async {

                                final code = DvOrb.get_shape_by_id("referral_declare_page/code")
                                    ?.get("shape.value")?.toString().trim() ?? "";
                                if (code.isEmpty) { _referralDeclareError("referral_declare_empty"); return; }
                                // Double garde : le menu cache l'option, mais masquer n'est pas interdire.
                                if (!await _storeCanBuy()) { _referralDeclareError("referral_declare_not_admin"); return; }

                                final res = await ActionRegistry.get("referral.declare")?.call(null, {"code": code});
                                final status = res is Dvidle ? (res.get("status")?.toString() ?? "network") : "network";
                                if (status != "ok") {
                                    const known = ["invalid", "other_region", "inactive", "already", "paid",
                                                   "self", "loop", "throttled", "not_admin"];
                                    _referralDeclareError("referral_declare_${known.contains(status) ? status : "network"}");
                                    return;
                                }
                                _referralDeclareError("");
                                _referralDeclareOk(true);
    }

    Future<void> on_referral_declare_close(dynamic caller, dynamic event) async {

                                _referralDeclareOk(false);
                                DvOrb.navigate_back();
    }
}

// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
