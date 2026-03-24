
import 'package:flutter/material.dart';
import 'election_data.dart';
import 'saisie_screen.dart';
import 'graphiques_screen.dart';
import 'rapport_screen.dart';
import 'db_helper.dart';

void main() { runApp(const ElectionApp()); }

class ElectionApp extends StatelessWidget {
  const ElectionApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Élections 2026 Djibouti',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)), useMaterial3: true,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1565C0), foregroundColor: Colors.white, elevation: 2)),
      home: const LoginPage(), debugShowCheckedModeBanner: false);
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final _pin = TextEditingController(); String? _err;
  void _login() {
    final p = _pin.text.trim().toUpperCase();
    if (p == 'ADMIN26') { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage(role: 'superviseur'))); }
    else if (p.length >= 4) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage(role: 'agent'))); }
    else { setState(() => _err = 'PIN invalide. Superviseur: ADMIN26'); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF1565C0), body: Center(child: Card(
      margin: const EdgeInsets.all(32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.how_to_vote, size: 60, color: Color(0xFF1565C0)),
        const SizedBox(height: 12),
        const Text('Élections 2026', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
        const Text('République de Djibouti', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 24),
        TextField(controller: _pin, obscureText: true, decoration: InputDecoration(labelText: 'Code PIN', border: const OutlineInputBorder(), errorText: _err, prefixIcon: const Icon(Icons.lock)), onSubmitted: (_) => _login()),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _login, icon: const Icon(Icons.login), label: const Text('Connexion'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)))),
      ])),
    )));
  }
}

class HomePage extends StatelessWidget {
  final String role;
  const HomePage({super.key, required this.role});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 7, child: Scaffold(
      appBar: AppBar(title: const Text('Élections 2026 – Djibouti'),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Chip(label: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Colors.white24))],
        bottom: const TabBar(labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.white, isScrollable: true, tabs: [
          Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
          Tab(icon: Icon(Icons.credit_card), text: 'Retraits'),
          Tab(icon: Icon(Icons.location_city), text: 'Arrond.'),
          Tab(icon: Icon(Icons.list_alt), text: 'Bureaux'),
          Tab(icon: Icon(Icons.edit_note), text: 'Saisie'),
          Tab(icon: Icon(Icons.bar_chart), text: 'Graphiques'),
          Tab(icon: Icon(Icons.print), text: 'Rapport'),
        ])),
      body: const TabBarView(children: [DashboardTab(), RetraitsTab(), ArrondissementTab(), BureauxTab(), SaisieScreen(), GraphiquesScreen(), RapportScreen()]),
    ));
  }
}

// ══════════════════════════════════════════════
// DASHBOARD DYNAMIQUE
// ══════════════════════════════════════════════
class _LiveStats {
  final int totalInscrits;
  final int totalRetires;
  final int totalRestant;
  final double pctRetrait;
  final int nouveauxRetraits; // from SQLite
  final String dateMaj;
  final List<_CentreStats> centres;
  const _LiveStats({required this.totalInscrits, required this.totalRetires, required this.totalRestant, required this.pctRetrait, required this.nouveauxRetraits, required this.dateMaj, required this.centres});
}

class _CentreStats {
  final int codeCentre;
  final String nomCentre;
  final String arrondissement;
  final int inscrits;
  final int retraitBase; // from Excel
  final int retraitNew;  // from SQLite
  int get totalRetraits => retraitBase + retraitNew;
  double get pct => inscrits > 0 ? totalRetraits / inscrits : 0;
  const _CentreStats({required this.codeCentre, required this.nomCentre, required this.arrondissement, required this.inscrits, required this.retraitBase, required this.retraitNew});
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with AutomaticKeepAliveClientMixin {
  _LiveStats? _stats;
  bool _loading = true;
  String? _lastRefresh;

  @override
  bool get wantKeepAlive => false; // always refresh when tab shown

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final saisies = await DbHelper.all();

    // Group new saisies by centre code
    final Map<int, int> newByCentre = {};
    for (final s in saisies) {
      newByCentre[s.codeCentre] = (newByCentre[s.codeCentre] ?? 0) + s.retraits;
    }

    // Build centre stats
    final centres = ElectionData.centresSuivi.map((c) {
      return _CentreStats(
        codeCentre: c.codeCentre, nomCentre: c.nomCentre,
        arrondissement: c.arrondissement, inscrits: c.inscrits,
        retraitBase: c.cumulRetraits, retraitNew: newByCentre[c.codeCentre] ?? 0,
      );
    }).toList();

    final baseRetires = ElectionData.totalRetires;
    final nouveaux = newByCentre.values.fold(0, (a, b) => a + b);
    final totalRetires = baseRetires + nouveaux;
    final totalInscrits = ElectionData.totalInscrits;
    final now = DateTime.now();
    final dateMaj = nouveaux > 0
        ? '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}'
        : ElectionData.dateMaj;

    setState(() {
      _stats = _LiveStats(
        totalInscrits: totalInscrits,
        totalRetires: totalRetires,
        totalRestant: totalInscrits - totalRetires,
        pctRetrait: totalRetires / totalInscrits,
        nouveauxRetraits: nouveaux,
        dateMaj: dateMaj,
        centres: centres,
      );
      _loading = false;
      _lastRefresh = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final s = _stats!;
    final pct = s.pctRetrait * 100;
    final colour = pct >= 50 ? Colors.green : pct >= 20 ? Colors.orange : Colors.red;

    // Top centres by new retraits
    final topCentres = [...s.centres]..sort((a, b) => a.codeCentre.compareTo(b.codeCentre));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header row
          Row(children: [
            const Icon(Icons.update, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(child: Text('MàJ: ${s.dateMaj}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
            GestureDetector(onTap: _refresh, child: const Icon(Icons.refresh, color: Color(0xFF1565C0), size: 22)),
            if (_lastRefresh != null) Padding(padding: const EdgeInsets.only(left: 4), child: Text(_lastRefresh!, style: const TextStyle(color: Colors.grey, fontSize: 10))),
          ]),
          const SizedBox(height: 12),

          // New retraits badge
          if (s.nouveauxRetraits > 0) Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.add_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('+${s.nouveauxRetraits} retraits saisis localement (non encore synchronisés avec la base centrale)', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),
          if (s.nouveauxRetraits > 0) const SizedBox(height: 10),

          // KPI Cards
          _KpiCard('Total inscrits', _fmt(s.totalInscrits), Icons.people, Colors.blue),
          _KpiCard('Cartes retirées', _fmt(s.totalRetires), Icons.credit_card, Colors.green,
              subtitle: s.nouveauxRetraits > 0 ? '${_fmt(ElectionData.totalRetires)} base + ${_fmt(s.nouveauxRetraits)} nouveaux' : null),
          _KpiCard('Restant à retirer', _fmt(s.totalRestant), Icons.pending_actions, Colors.orange),
          _KpiCard('Taux retrait national', '${pct.toStringAsFixed(2)}%', Icons.percent, colour),
          _KpiCard('Bureaux de vote', _fmt(ElectionData.totalBureaux), Icons.how_to_vote, Colors.indigo),
          _KpiCard('Centres de vote', _fmt(ElectionData.totalCentres), Icons.business, Colors.teal),

          const SizedBox(height: 16),

          // Progress card
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)]), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              const Text('Avancement retraits', style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${pct.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)), child: Text('/ 85% objectif', style: const TextStyle(color: Colors.white70, fontSize: 10))),
              ]),
              const SizedBox(height: 10),
              Stack(children: [
                Container(height: 14, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(7))),
                FractionallySizedBox(widthFactor: (0.85).clamp(0, 1), child: Container(height: 14, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(7)))),
                FractionallySizedBox(widthFactor: s.pctRetrait.clamp(0, 1), child: Container(height: 14, decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(7)))),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${_fmt(s.totalRetires)} retirés', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Objectif: ${_fmt((s.totalInscrits * 0.85).toInt())}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
              const SizedBox(height: 4),
              Text('Écart objectif: ${_fmt(((s.totalInscrits * 0.85) - s.totalRetires).toInt())} cartes', style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ]),
          ),

          const SizedBox(height: 16),

          // Centres avec nouvelles saisies
          if (s.nouveauxRetraits > 0) ...[
            Text('Tous les centres (${s.centres.where((c) => c.retraitNew > 0).length} avec saisies locales)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...topCentres.where((c) => c.retraitNew > 0).map((c) {
              final pctC = c.pct * 100;
              Color cc = pctC >= 30 ? Colors.green : pctC >= 8.5 ? Colors.orange : Colors.red;
              return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(dense: true,
                leading: CircleAvatar(radius: 16, backgroundColor: cc.withOpacity(0.15), child: Text('${c.codeCentre}', style: TextStyle(color: cc, fontSize: 10, fontWeight: FontWeight.bold))),
                title: Text(c.nomCentre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                subtitle: LinearProgressIndicator(value: c.pct.clamp(0, 1), backgroundColor: Colors.grey[200], color: cc, minHeight: 4),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('+${c.retraitNew}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${pctC.toStringAsFixed(1)}%', style: TextStyle(color: cc, fontSize: 10)),
                ]),
              ));
            }),
            const SizedBox(height: 8),
          ],

          // Mini synthèse arrondissements
          const Text('Synthèse arrondissements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          ...ElectionData.syntheseArr.map((a) {
            final pctA = a.pctRetrait * 100;
            Color ca = pctA >= 28 ? Colors.green : pctA >= 9 ? Colors.orange : Colors.red;
            return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
              Expanded(flex: 4, child: Text(a.arrondissement.replaceAll('arrondissement', 'Arr.').replaceAll('Arrondissement', 'Arr.'), style: const TextStyle(fontSize: 11))),
              Expanded(flex: 5, child: LinearProgressIndicator(value: a.pctRetrait.clamp(0, 1), backgroundColor: Colors.grey[200], color: ca, minHeight: 8)),
              const SizedBox(width: 6),
              SizedBox(width: 42, child: Text('${pctA.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: ca, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            ]));
          }),
        ]),
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color; final String? subtitle;
  const _KpiCard(this.label, this.value, this.icon, this.color, {this.subtitle});
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
    leading: CircleAvatar(backgroundColor: color.withOpacity(0.13), child: Icon(icon, color: color, size: 20)),
    title: Text(label, style: const TextStyle(fontSize: 12)),
    subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 10, color: Colors.grey)) : null,
    trailing: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color))));
}

// ── Retraits (LIVE — fusionne base + SQLite) ──
class RetraitsTab extends StatefulWidget {
  const RetraitsTab({super.key});
  @override State<RetraitsTab> createState() => _RetraitsTabState();
}

class _LiveCentre {
  final CentreSuivi base;
  final int newRetraits;
  final Map<String, int> newDaily;
  int get totalRetraits => base.cumulRetraits + newRetraits;
  int get restant => base.restant - newRetraits;
  double get pct => base.inscrits > 0 ? totalRetraits / base.inscrits : 0;
  // Convenience getters
  int get codeCentre => base.codeCentre;
  String get nomCentre => base.nomCentre;
  String get arrondissement => base.arrondissement;
  String get commune => base.commune;
  int get inscrits => base.inscrits;
  int get nombreBureaux => base.nombreBureaux;
  Map<String, int> get retraitsDailyData => base.retraitsDailyData;
  const _LiveCentre({required this.base, required this.newRetraits, required this.newDaily});
}

class _RetraitsTabState extends State<RetraitsTab> {
  String _filter = '';
  List<_LiveCentre> _centres = [];
  bool _loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final saisies = await DbHelper.all();
    final Map<int, int> newByCode = {};
    final Map<int, Map<String, int>> dailyByCode = {};
    for (final s in saisies) {
      newByCode[s.codeCentre] = (newByCode[s.codeCentre] ?? 0) + s.retraits;
      dailyByCode.putIfAbsent(s.codeCentre, () => {});
      dailyByCode[s.codeCentre]![s.date] = (dailyByCode[s.codeCentre]![s.date] ?? 0) + s.retraits;
    }
    final centres = ElectionData.centresSuivi.map((c) => _LiveCentre(
      base: c,
      newRetraits: newByCode[c.codeCentre] ?? 0,
      newDaily: dailyByCode[c.codeCentre] ?? {},
    )).toList();
    if (mounted) setState(() { _centres = centres; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final filtered = _centres.where((c) =>
      c.nomCentre.toLowerCase().contains(_filter.toLowerCase()) ||
      c.arrondissement.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: Row(children: [
        Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Rechercher centre / arrondissement', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() => _filter = v))),
        const SizedBox(width: 8),
        GestureDetector(onTap: _load, child: const Icon(Icons.refresh, color: Color(0xFF1565C0))),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Text('${filtered.length} centres', style: const TextStyle(color: Colors.grey, fontSize: 12))])),
      Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (ctx, i) {
        final lc = filtered[i];
        final c = lc.base;
        final pct = lc.pct * 100;
        Color sc = pct >= 30 ? Colors.green : pct >= 8.5 ? Colors.orange : Colors.red;
        String st = pct >= 30 ? 'OK' : pct >= 8.5 ? 'ALERTE' : 'CRITIQUE';

        // Merge daily: base + new
        final allDaily = Map<String, int>.from(c.retraitsDailyData);
        lc.newDaily.forEach((date, v) {
          allDaily[date] = (allDaily[date] ?? 0) + v;
        });
        final sortedDaily = allDaily.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

        return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ExpansionTile(
          leading: CircleAvatar(backgroundColor: sc.withOpacity(0.15), child: Text('${c.codeCentre}', style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.bold))),
          title: Text(c.nomCentre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('${c.arrondissement} • ${pct.toStringAsFixed(1)}% retiré${lc.newRetraits > 0 ? " (+${lc.newRetraits} local)" : ""}'),
          trailing: Chip(label: Text(st, style: const TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: sc, padding: EdgeInsets.zero),
          children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LinearProgressIndicator(value: lc.pct.clamp(0, 1), backgroundColor: Colors.grey[200], color: sc, minHeight: 6),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _IC('Inscrits', '${c.inscrits}', Colors.blue),
              _IC('Retirés', '${lc.totalRetraits}', Colors.green),
              _IC('Restant', '${lc.restant}', Colors.orange),
            ]),
            if (lc.newRetraits > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('+${lc.newRetraits} saisis localement', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500))),
            const SizedBox(height: 6),
            Text('Bureaux: ${c.nombreBureaux} | Commune: ${c.commune}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (sortedDaily.isNotEmpty) ...[const SizedBox(height: 6), const Text('Historique:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 4, children: sortedDaily.where((e) => e.value > 0).map((e) => Chip(label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 9)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList())],
          ]))],
        ));
      })),
    ]);
  }
}
class _IC extends StatelessWidget {
  final String l, v; final Color c;
  const _IC(this.l, this.v, this.c);
  @override Widget build(BuildContext ctx) => Column(children: [Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 14)), Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey))]);
}

// ── Arrondissements ───────────────────────────
class ArrondissementTab extends StatelessWidget {
  const ArrondissementTab({super.key});
  @override
  Widget build(BuildContext context) {
    final sorted = [...ElectionData.syntheseArr]..sort((a, b) => b.pctRetrait.compareTo(a.pctRetrait));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(color: Colors.blue[50], child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [const Text('Synthèse par Arrondissement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text('Classement par taux de retrait', style: TextStyle(color: Colors.grey[600], fontSize: 12))]))),
      const SizedBox(height: 8),
      ...sorted.asMap().entries.map((entry) {
        final rank = entry.key + 1; final a = entry.value; final pct = a.pctRetrait * 100;
        Color color = pct >= 28 ? Colors.green : pct >= 9 ? Colors.orange : Colors.red;
        return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [CircleAvatar(radius: 14, backgroundColor: color, child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(width: 8), Expanded(child: Text(a.arrondissement, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Text('${pct.toStringAsFixed(2)}%', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16))]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: a.pctRetrait.clamp(0, 1), backgroundColor: Colors.grey[200], color: color, minHeight: 8),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_SS('Inscrits', '${a.inscrits}'), _SS('Retirés', '${a.retires}'), _SS('Restant', '${a.restant}')]),
        ])));
      }),
    ]);
  }
}
class _SS extends StatelessWidget {
  final String l, v; const _SS(this.l, this.v);
  @override Widget build(BuildContext ctx) => Column(children: [Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey))]);
}

// ── Bureaux ───────────────────────────────────
class BureauxTab extends StatefulWidget {
  const BureauxTab({super.key});
  @override State<BureauxTab> createState() => _BureauxTabState();
}
class _BureauxTabState extends State<BureauxTab> {
  String _filter = ''; String? _comm;
  @override
  Widget build(BuildContext context) {
    final communes = ElectionData.bureaux.map((b) => b.commune).toSet().toList()..sort();
    final filtered = ElectionData.bureaux.where((b) {
      final mn = b.nomBureau.toLowerCase().contains(_filter.toLowerCase()) || b.nomCentre.toLowerCase().contains(_filter.toLowerCase());
      return mn && (_comm == null || b.commune == _comm);
    }).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: TextField(decoration: const InputDecoration(labelText: 'Rechercher bureau / centre', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() => _filter = v))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Commune', border: OutlineInputBorder(), isDense: true), value: _comm,
        items: [const DropdownMenuItem<String>(value: null, child: Text('Toutes')), ...communes.map((c) => DropdownMenuItem(value: c, child: Text(c)))],
        onChanged: (v) => setState(() => _comm = v))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Row(children: [Text('${filtered.length} bureaux', style: const TextStyle(color: Colors.grey, fontSize: 12))])),
      Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (ctx, i) {
        final b = filtered[i];
        return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: ListTile(dense: true,
          leading: CircleAvatar(radius: 16, backgroundColor: Colors.blue[50], child: Text('${b.numeroCentre}', style: TextStyle(color: Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold))),
          title: Text(b.nomBureau, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          subtitle: Text('${b.nomCentre} • ${b.arrondissement}', style: const TextStyle(fontSize: 10)),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${b.votants}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1565C0))), const Text('votants', style: TextStyle(fontSize: 9, color: Colors.grey))])));
      })),
    ]);
  }
}
