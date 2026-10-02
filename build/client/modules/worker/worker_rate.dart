// -----------------------------------------------------------------------------
// --- This file is part of the DEVA framework
// --- Copyright (C) 2026 Griselouve - deva@grisloup.com
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
// --- Globals shortcuts and miscellaneous
// -----------------------------------------------------------------------------

// Les shapes du panneau « Noter et partager » (commons/rate_*, injectées par page_taskbar).
// Une seule liste pour ouvrir et refermer : un widget oublié à la fermeture resterait
// affiché par-dessus le jeu.
const List<String> _kRateShapes = <String>[
    "commons/rate_scrim",
    "commons/rate_panel",
    "commons/rate_phrase",
    "commons/rate_star1",
    "commons/rate_star2",
    "commons/rate_star3",
    "commons/rate_star4",
    "commons/rate_star5",
    "commons/rate_share",
];

// -----------------------------------------------------------------------------
// --- worker extension : Noter et partager l'application
// -----------------------------------------------------------------------------
extension Worker_rate on worker {

    void _register_rate() {

                                // Option « Noter et partager » des kebabs Clan et Personnage (adultes).
                                ActionRegistry.register("worker.open_rate_panel",           open_rate_panel);
                                ActionRegistry.register("worker.on_rate_close",             on_rate_close);
                                ActionRegistry.register("worker.on_rate_share",             on_rate_share);

                                // Une action par étoile : le tap d'un DvIcon ne porte pas son rang.
                                for (var n = 1; n <= 5; n++) {
                                    final rank = n;
                                    ActionRegistry.register("worker.on_rate_$rank",
                                        (dynamic c, dynamic e) async { await _onRateStar(rank); });
                                }
    }

    // Le contrôle d'âge, refait à chaque action du panneau : les selectors cachent l'option, mais
    // masquer n'est pas interdire (cf. on_log_share). Repli STRICT : une lecture en échec refuse.
    Future<bool> _rateAllowed(String what) async {

                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (await _ensureIsAdult(clanId, clanSecret, region)) return true;
                                    deva_log("info", "[rate] $what refusé : $_userId n'est pas légalement adulte");
                                } catch (e) {
                                    deva_log("error", "[rate] $what : contrôle d'âge FAILED ($e) → refusé");
                                }
                                return false;
    }

    // Vide tant que l'app est en test interne (pas de fiche publique) : cf. screens_meta.yml.
    Future<String> _rateStoreUrl() async {

                                return (await Deva.instance.get("app_share.store_url"))?.toString().trim() ?? "";
    }

    // Ouvre le panneau : étoiles vides, phrase d'accueil, puis tout est révélé d'un coup.
    Future<void> open_rate_panel(dynamic caller, dynamic event) async {

                                if (!await _rateAllowed("open_rate_panel")) return;
                                _rateFill(0);
                                await _setRatePhrase("rate_phrase");
                                for (final id in _kRateShapes) {
                                    DvOrb.get_shape_by_id(id)?.show();
                                }
    }

    Future<void> on_rate_close(dynamic caller, dynamic event) async {

                                for (final id in _kRateShapes) {
                                    DvOrb.get_shape_by_id(id)?.hide();
                                }
    }

    // Remplit les étoiles jusqu'à celle touchée, puis ouvre la fiche Play où la note se dépose
    // vraiment. En test interne, pas de fiche publique : un merci, et rien ne s'ouvre.
    Future<void> _onRateStar(int rank) async {

                                if (!await _rateAllowed("rate_$rank")) return;
                                _rateFill(rank);
                                final url = await _rateStoreUrl();
                                if (url.isEmpty) {
                                    await _setRatePhrase("rate_thanks_soon");
                                    return;
                                }
                                try {
                                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                } catch (e) {
                                    deva_log("warning", "[rate] fiche Store non ouverte : $e");
                                }
    }

    // Partage de l'app : le site tant que store_url est vide, la fiche Play ensuite.
    Future<void> on_rate_share(dynamic caller, dynamic event) async {

                                if (!await _rateAllowed("on_rate_share")) return;
                                final key = (await _rateStoreUrl()).isEmpty ? "share.app_site" : "share.app_store";
                                final r = ActionRegistry.get(key)?.call(caller, event);
                                if (r is Future) await r;
    }

    // Étoiles 1..rank pleines, les suivantes vides. DvIcon relit shape.icon à chaque rendu.
    void _rateFill(int rank) {

                                for (var n = 1; n <= 5; n++) {
                                    final s = DvOrb.get_shape_by_id("commons/rate_star$n");
                                    s?.set("shape.icon", n <= rank ? "star" : "star_border");
                                    s?.refreshUI();
                                }
    }

    // DvLabel ne peint que shape.display, recalculé par computeDisplay() : écrire shape.label
    // seul laisserait le texte figé sur celui du YAML (cf. _setConsentLabel).
    Future<void> _setRatePhrase(String key) async {

                                final s = DvOrb.get_shape_by_id("commons/rate_phrase");
                                if (s is! DvLabel) return;
                                s.set("shape.label", TranslationRegistry.translate(key));
                                await s.computeDisplay();
                                s.refreshUI();
    }
}

// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
