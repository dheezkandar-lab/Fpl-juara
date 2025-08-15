// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'package:http/http.dart' as http;

const FPL_BOOTSTRAP = "https://fantasy.premierleague.com/api/bootstrap-static/";
const FPL_FIXTURES = "https://fantasy.premierleague.com/api/fixtures/?future=1";

const DIFF_MULTIPLIER = {
  1: 1.10,
  2: 1.05,
  3: 1.00,
  4: 0.95,
  5: 0.90,
};

Future<Map<String, dynamic>> fetchJson(String url) async {
  final r = await http.get(Uri.parse(url));
  if (r.statusCode != 200) {
    throw Exception("HTTP ${r.statusCode} for $url");
  }
  return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
}

Future<List<dynamic>> fetchJsonList(String url) async {
  final r = await http.get(Uri.parse(url));
  if (r.statusCode != 200) {
    throw Exception("HTTP ${r.statusCode} for $url");
  }
  final parsed = jsonDecode(utf8.decode(r.bodyBytes));
  if (parsed is List) return parsed;
  throw Exception("Expected list from $url");
}

double? toDouble(dynamic x) {
  if (x == null) return null;
  if (x is num) return x.toDouble();
  if (x is String) {
    return double.tryParse(x);
  }
  return null;
}

class PlayerScore {
  final int id;
  final String webName;
  final int teamId;
  final String teamName;
  final String position;
  final double cost;
  final double? epNext;
  final double form;
  final double ict;
  final double predicted;
  final String note;

  PlayerScore({
    required this.id,
    required this.webName,
    required this.teamId,
    required this.teamName,
    required this.position,
    required this.cost,
    required this.epNext,
    required this.form,
    required this.ict,
    required this.predicted,
    required this.note,
  });
}

Future<(int?, int?)> getCurrentAndNextGw(Map<String, dynamic> bootstrap) async {
  final events = (bootstrap["events"] as List<dynamic>? ?? []);
  int? current = events.cast<Map>().firstWhere(
    (e) => (e["is_current"] == true),
    orElse: () => {},
  )["id"] as int?;
  int? next = events.cast<Map>().firstWhere(
    (e) => (e["is_next"] == true),
    orElse: () => {},
  )["id"] as int?;
  return (current, next);
}

Map<int, String> buildTeamMap(Map<String, dynamic> bootstrap) {
  final teams = (bootstrap["teams"] as List<dynamic>? ?? []);
  return {
    for (final t in teams.cast<Map>())
      (t["id"] as int): (t["name"] as String),
  };
}

Map<int, int> fixtureDifficultyForNextGw(List<dynamic> fixtures, int? nextGw) {
  final Map<int, int> diffMap = {};
  if (nextGw == null) return diffMap;
  for (final f in fixtures.cast<Map>()) {
    if (f["event"] != nextGw) continue;
    final int h = f["team_h"];
    final int a = f["team_a"];
    final int hd = (f["team_h_difficulty"] ?? 3) as int;
    final int ad = (f["team_a_difficulty"] ?? 3) as int;
    diffMap[h] = diffMap.containsKey(h) ? (diffMap[h]!.clamp(1, 5)).clamp(1, hd) : hd;
    diffMap[a] = diffMap.containsKey(a) ? (diffMap[a]!.clamp(1, 5)).clamp(1, ad) : ad;
  }
  return diffMap;
}

Future<List<PlayerScore>> predictPlayersForNextGw({
  String? position, // GK/DEF/MID/FWD/ANY
  int limit = 10,
}) async {
  final bs = await fetchJson(FPL_BOOTSTRAP);
  final fixtures = await fetchJsonList(FPL_FIXTURES);
  final (_, nextGw) = await getCurrentAndNextGw(bs);
  final teamMap = buildTeamMap(bs);
  final diffMap = fixtureDifficultyForNextGw(fixtures, nextGw);

  final players = (bs["elements"] as List<dynamic>? ?? []).cast<Map>();
  final eltypes = (bs["element_types"] as List<dynamic>? ?? []).cast<Map>();
  final typeMap = {
    for (final t in eltypes) (t["id"] as int): (t["singular_name_short"] as String)
  };
  int? desired;
  if (position != null) {
    final p = position.trim().toUpperCase();
    if (p == "GK" || p == "GKP") desired = 1;
    else if (p == "DEF") desired = 2;
    else if (p == "MID" || p == "MIDF" || p == "MF") desired = 3;
    else if (p == "FWD" || p == "FW" || p == "ST") desired = 4;
    else if (p == "ANY" || p == "ALL") desired = null;
  }

  final List<PlayerScore> results = [];
  for (final pl in players) {
    final et = pl["element_type"] as int;
    if (desired != null && et != desired) continue;
    final webName = pl["web_name"] as String;
    final teamId = pl["team"] as int;
    final teamName = teamMap[teamId] ?? "Team $teamId";
    final pos = switch (et) { 1 => "GK", 2 => "DEF", 3 => "MID", 4 => "FWD", _ => (typeMap[et] ?? "$et") };
    final cost = ((pl["now_cost"] as int) / 10.0);
    final epNext = toDouble(pl["ep_next"]);
    final form = toDouble(pl["form"]) ?? 0.0;
    final ict = toDouble(pl["ict_index"]) ?? 0.0;

    double base;
    String note;
    if (epNext != null) {
      base = epNext;
      note = "ep_next";
    } else {
      base = 0.6 * form + 0.4 * (ict / 10.0);
      note = "heuristic(form+ict)";
    }

    final diff = diffMap[teamId] ?? 3;
    final mult = DIFF_MULTIPLIER[diff] ?? 1.0;
    final predicted = double.parse((base * mult).toStringAsFixed(2));

    results.add(PlayerScore(
      id: pl["id"] as int,
      webName: webName,
      teamId: teamId,
      teamName: teamName,
      position: pos,
      cost: cost,
      epNext: epNext,
      form: form,
      ict: ict,
      predicted: predicted,
      note: "$note, diff=$diff x$mult",
    ));
  }

  results.sort((a,b){
    final c = b.predicted.compareTo(a.predicted);
    if (c != 0) return c;
    return b.form.compareTo(a.form);
  });

  final n = limit < 1 ? 1 : limit;
  return results.take(n).toList();
}

Future<List<PlayerScore>> captainCandidates({int limit = 10}) async {
  final mids = await predictPlayersForNextGw(position: "MID", limit: 60);
  final fwds = await predictPlayersForNextGw(position: "FWD", limit: 60);
  final pool = [...mids, ...fwds];
  pool.sort((a,b){
    final c = b.predicted.compareTo(a.predicted);
    if (c != 0) return c;
    return b.form.compareTo(a.form);
  });
  final n = limit < 1 ? 1 : limit;
  return pool.take(n).toList();
}

Future<String> gwInfo() async {
  final bs = await fetchJson(FPL_BOOTSTRAP);
  final events = (bs["events"] as List<dynamic]? ?? []).cast<Map>();
  Map? current = events.firstWhere((e) => e["is_current"] == true, orElse: () => {});
  Map? nxt = events.firstWhere((e) => e["is_next"] == true, orElse: () => {});

  String fmt(Map? e) {
    if (e == null || e.isEmpty) return "—";
    final name = (e["name"] ?? "GW ${e["id"]}").toString();
    final deadline = (e["deadline_time"] ?? "unknown").toString();
    return "$name (deadline: $deadline)";
  }

  return "Current: ${fmt(current)}\nNext: ${fmt(nxt)}\n";
}
