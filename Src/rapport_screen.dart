import 'package:flutter/material.dart';
import 'election_data.dart';
import 'db_helper.dart';

class RapportScreen extends StatefulWidget {
  const RapportScreen({super.key});
  @override
  State<RapportScreen> createState() => _RapportScreenState();
}

class _RapportScreenState extends State<RapportScreen> {
  bool _loading = true;
  int _nouveaux = 0;
  Map<int, int> _newByCentre = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saisies = await DbHelper.all();
    final Map<int, int> map = {};
    for (final s in saisies) {
      map[s.codeCentre] = (map[s.codeCentre] ?? 0) + s.retraits;
    }
    if (mounted) setState(() {
      _newByCentre = map;
      _nouveaux = map.values.fold(0, (a, b) => a + b);
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final totalRetires = ElectionData.totalRetires + _nouveaux;
    final totalInscrits = ElectionData.totalInscrits;
    final pctNat = totalRetires / totalInscrits * 100;

    // SynthÃ¨se arrondissements live
    final Map<String, _ArrAcc> arrMap = {};
    for (final c in ElectionData.centresSuivi) {
      arrMap.putIfAbsent(c.arrondissement, () => _ArrAcc());
      arrMap[c.arrondissement]!.inscrits += c.inscrits;
      arrMap[c.arrondissement]!.retires  += c.cumulRetraits + (_newByCentre[c.codeCentre] ?? 0);
    }
    final arrs = arrMap.entries.map((e) => (
      nom: e.key,
      inscrits: e.value.inscrits,
      retires: e.value.retires,
      pct: e.value.inscrits > 0 ? e.value.retires / e.value.inscrits * 100 : 0.0,
    )).toList()..sort((a, b) => b.pct.compareTo(a.pct));

    // Centres triÃ©s par taux desc
    final centresSorted = ElectionData.centresSuivi.map((c) {
      final total = c.cumulRetraits + (_newByCentre[c.codeCentre] ?? 0);
      final pct = c.inscrits > 0 ? total / c.inscrits * 100 : 0.0;
      return (centre: c, total: total, pct: pct);
    }).toList()..sort((a, b) => b.pct.compareTo(a.pct));

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // En-tÃªte
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)]),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('ðŸ‡©ðŸ‡¯', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              const Text('RAPPORT DE SUIVI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const Text('Retrait des cartes Ã©lectorales', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 8),
              Text('MÃ J : ${ElectionData.dateMaj}${_nouveaux > 0 ? " + saisies locales" : ""}',
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ]),
          ),
          const SizedBox(height: 14),

          // KPIs nationaux
          _sectionTitle('ðŸ“Š Situation nationale'),
          const SizedBox(height: 8),
          Row(children: [
            _kpi('Inscrits',  _fmt(totalInscrits),          Colors.blue),
            const SizedBox(width: 8),
            _kpi('RetirÃ©es',  _fmt(totalRetires),            Colors.green),
            const SizedBox(width: 8),
            _kpi('Restant',   _fmt(totalInscrits - totalRetires), Colors.orange),
          ]),
          const SizedBox(height: 10),

          // Barre de progression
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Taux national', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${pctNat.toStringAsFixed(2)}%',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1565C0))),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: (pctNat / 100).clamp(0, 1),
                backgroundColor: Colors.grey[200],
                color: pctNat >= 40 ? Colors.green : Colors.orange,
                minHeight: 10,
              )),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${_fmt(totalRetires)} / ${_fmt(totalInscrits)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text('Objectif : 85%', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ]),
              if (_nouveaux > 0) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${_fmt(_nouveaux)} saisis localement inclus',
                    style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Arrondissements
          _sectionTitle('ðŸ™ï¸ SynthÃ¨se par arrondissement'),
          const SizedBox(height: 8),
          ...arrs.map((a) {
            Color col = a.pct >= 40 ? Colors.green : a.pct >= 25 ? Colors.orange : Colors.red;
            String badge = a.pct >= 40 ? 'OK' : a.pct >= 25 ? 'ALERTE' : 'CRITIQUE';
            Color badgeBg = a.pct >= 40 ? const Color(0xFFDCFCE7) : a.pct >= 25 ? const Color(0xFFFEF9C3) : const Color(0xFFFEE2E2);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(
                    a.nom.replaceAll('arrondissement', 'Arr.').replaceAll('Arrondissement', 'Arr.'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: col)),
                  ),
                  const SizedBox(width: 8),
                  Text('${a.pct.toStringAsFixed(2)}%',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: col)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                  value: (a.pct / 100).clamp(0, 1),
                  backgroundColor: Colors.grey[200], color: col, minHeight: 6,
                )),
                const SizedBox(height: 4),
                Text('${_fmt(a.retires)} retirÃ©s Â· ${_fmt(a.inscrits - a.retires)} restants',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
            );
          }),
          const SizedBox(height: 16),

          // Classement centres
          _sectionTitle('ðŸ† Classement des 39 centres'),
          const SizedBox(height: 8),
          ...centresSorted.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final item = entry.value;
            final c = item.centre;
            final pct = item.pct;
            Color col = pct >= 40 ? Colors.green : pct >= 25 ? Colors.orange : Colors.red;
            final isTop = rank <= 5;
            final isBottom = rank > 34;
            Color rowBg = isTop ? const Color(0xFFF0FDF4) : isBottom ? const Color(0xFFFFF1F2) : Colors.white;

            String rankStr;
            if (rank == 1) rankStr = 'ðŸ¥‡';
            else if (rank == 2) rankStr = 'ðŸ¥ˆ';
            else if (rank == 3) rankStr = 'ðŸ¥‰';
            else rankStr = '$rank';

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: rowBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(children: [
                SizedBox(width: 28, child: Text(rankStr,
                    style: TextStyle(fontSize: rank <= 3 ? 15 : 11, fontWeight: FontWeight.w700, color: const Color(0xFF1565C0)),
                    textAlign: TextAlign.center)),
                const SizedBox(width: 6),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.nomCentre, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(c.arrondissement.replaceAll('arrondissement', 'Arr.').replaceAll('Arrondissement', 'Arr.'),
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${pct.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: col)),
                  Text('${_fmt(item.total)} / ${_fmt(c.inscrits)}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 20),

          // Pied de page
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              'Ã‰lections PrÃ©sidentielles 2026 â€” RÃ©publique de Djibouti\n162 833 inscrits Â· 413 bureaux Â· 39 centres Â· 6 arrondissements',
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1565C0)),
  );

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ]),
    ),
  );
}

class _ArrAcc {
  int inscrits = 0;
  int retires  = 0;
}
