import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'fpl.dart';

const kPrimary = Color(0xFF00FF87);

void main() {
  runApp(const FPLJuaraApp());
}

class FPLJuaraApp extends StatelessWidget {
  const FPLJuaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPLjuara',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_)=> const HomeScreen())
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 140, height: 140),
            const SizedBox(height: 16),
            const Text("Menuju Juara FPL",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final pages = const [
    DashboardPage(),
    CaptainPage(),
    TopPlayersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FPLjuara")),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(()=>_index=i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.info_outline), label: "GW"),
          NavigationDestination(icon: Icon(Icons.star_outline), label: "Captain"),
          NavigationDestination(icon: Icon(Icons.leaderboard_outlined), label: "Top"),
        ],
      ),
    );
  }
}

Future<void> saveCache(String key, Map<String, dynamic> data) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(key, jsonEncode({
    "t": DateTime.now().toIso8601String(),
    "data": data,
  }));
}

Future<Map<String, dynamic>?> loadCache(String key, {Duration maxAge = const Duration(hours: 6)}) async {
  final sp = await SharedPreferences.getInstance();
  final s = sp.getString(key);
  if (s == null) return null;
  try {
    final m = jsonDecode(s) as Map<String, dynamic>;
    final t = DateTime.tryParse(m["t"] as String? ?? "");
    if (t != null && DateTime.now().difference(t) <= maxAge) {
      return m["data"] as Map<String, dynamic>;
    }
  } catch (_) {}
  return null;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? info;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(()=>{loading=true, error=null});
    try {
      // Try cache first
      final cached = await loadCache("gw_info");
      if (cached != null && cached["text"] is String) {
        setState(()=>info = cached["text"]);
      }
      final s = await gwInfo();
      await saveCache("gw_info", {"text": s});
      setState(()=>info=s);
    } catch (e) {
      setState(()=>error=e.toString());
    } finally {
      setState(()=>loading=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Gameweek Info", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (loading && info == null) const Center(child: CircularProgressIndicator()),
          if (info != null) SelectableText(info!),
          if (error != null) Text("Error: $error", style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text("Refresh")),
        ],
      ),
    );
  }
}

class CaptainPage extends StatefulWidget {
  const CaptainPage({super.key});

  @override
  State<CaptainPage> createState() => _CaptainPageState();
}

class _CaptainPageState extends State<CaptainPage> {
  List<PlayerScore>? players;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(()=>{loading=true, error=null});
    try {
      // No heavy caching here (since list can be big), but could be added similarly
      final p = await captainCandidates(limit: 10);
      setState(()=>players=p);
    } catch (e) {
      setState(()=>error=e.toString());
    } finally {
      setState(()=>loading=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Top 10 Captain Picks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (loading && players == null) const Center(child: CircularProgressIndicator()),
          if (error != null) Text("Error: $error", style: const TextStyle(color: Colors.red)),
          if (players != null) ...players!.asMap().entries.map((e) {
            final i = e.key + 1;
            final p = e.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: kPrimary.withOpacity(0.2), child: Text("$i")),
                title: Text("${p.webName} — ${p.teamName} (${p.position})"),
                subtitle: Text("£${p.cost.toStringAsFixed(1)}m • ${p.predicted} pts • ${p.note}"),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class TopPlayersPage extends StatefulWidget {
  const TopPlayersPage({super.key});

  @override
  State<TopPlayersPage> createState() => _TopPlayersPageState();
}

class _TopPlayersPageState extends State<TopPlayersPage> {
  String pos = "ANY";
  int n = 15;
  List<PlayerScore>? players;
  String? error;
  bool loading = true;
  final positions = const ["ANY","GK","DEF","MID","FWD"];
  final controller = TextEditingController(text: "15");

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(()=>{players=null,error=null,loading=true});
    try {
      final p = await predictPlayersForNextGw(position: pos, limit: n);
      setState(()=>players=p);
    } catch (e) {
      setState(()=>error=e.toString());
    } finally {
      setState(()=>loading=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200))
          ),
          child: Row(
            children: [
              DropdownButton<String>(
                value: pos,
                items: positions.map((e)=>DropdownMenuItem(value:e, child: Text(e))).toList(),
                onChanged: (v){ if (v!=null) setState(()=>pos=v); },
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Count"),
                  controller: controller,
                  onSubmitted: (v){
                    final val = int.tryParse(v) ?? 15;
                    setState(()=>n = val.clamp(1, 50));
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: const Text("Go"),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (loading && players == null) const Center(child: CircularProgressIndicator()),
                if (error != null) Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("Error: $error", style: const TextStyle(color: Colors.red)),
                ),
                if (players != null) ...players!.asMap().entries.map((e){
                  final i = e.key + 1;
                  final p = e.value;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: kPrimary.withOpacity(0.2), child: Text("$i")),
                      title: Text("${p.webName} — ${p.teamName} (${p.position})"),
                      subtitle: Text("£${p.cost.toStringAsFixed(1)}m • ${p.predicted} pts • ${p.note}"),
                    ),
                  );
                }),
              ],
            ),
          ),
        )
      ],
    );
  }
}
