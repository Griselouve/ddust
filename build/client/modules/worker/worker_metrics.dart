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
// --- Mesures d'usage (dvanalytics)
//
// UN SEUL POINT d'émission pour tout le worker. L'événement passe par l'action
// `dvanalytics.log` : aucun import du module, et rien du tout s'il est absent ou
// coupé (`analytics.enabled: false`, l'état de ddust aujourd'hui).
// ⚠ APP D'ENFANTS : un nom d'événement et des nombres. Jamais un nom, un pseudonyme,
//   un identifiant de joueur, de clan ou de tâche, jamais l'âge ni l'état légal. Le
//   module ajoute seul l'identifiant d'installation pseudonyme.
// ⚠ Chaque appel est placé APRÈS l'entrée dans un clan, donc après l'acceptation des
//   CGU (par le tuteur pour un mineur). Jamais en session anonyme ; avant la
//   connexion, le module jette (`analytics.before_login: drop`).
// ⚠ Jamais d'exception, jamais attendu : la mesure ne retarde ni ne casse le jeu.
// -----------------------------------------------------------------------------
extension Worker_metrics on worker {

    void _metric(String name, [Map<String, num> props = const {}]) {

                                try {
                                    if (_anon) return;
                                    ActionRegistry.get("dvanalytics.log")?.call(null, {"name": name, "props": props});
                                } catch (e) {
                                    deva_log("warning", "[metrics] $name : $e");
                                }
    }

    /// Une ligne du journal du clan (`clans_logs.event`) devient l'événement que lui
    /// associe `worker.metrics.clan_logs` (config.yml), sinon rien.
    Future<void> _metricClanLog(String logEvent) async {

                                try {
                                    final name = (await deva_get("worker.metrics.clan_logs.$logEvent"))?.toString() ?? "";
                                    if (name.isNotEmpty) _metric(name);
                                } catch (_) {}
    }
}
