
import 'package:flutter/material.dart';
import 'election_data.dart';
import 'db_helper.dart';

// ══════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════
class GraphiquesScreen extends StatefulWidget {
  const GraphiquesScreen({super.key});
  @override
  State<GraphiquesScreen> createState() => _GraphiquesScreenState();
}

class _GraphiquesScreenState extends State<GraphiquesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  List<SaisieEntry> _saisies = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
    _loadSaisies();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload every time the tab becomes visible
    _loadSaisies();
  }

  Future<void> _loadSaisies() async {
    final data = await DbHelper.all();
    if (mounted) setState(() { _saisies = data; _loaded = true; });
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      // Refresh button
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('${_saisies.length} saisies locales', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loadSaisies,
            child: const Row(children: [Icon(Icons.refresh, size: 16, color: Color(0xFF1565C0)), SizedBox(width: 2), Text('Actualiser', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0)))]),
          ),
        ]),
      ),
      TabBar(
        controller: _tc, isScrollable: true,
        labelColor: const Color(0xFF1565C0), unselectedLabelColor: Colors.grey, indicatorColor: const Color(0xFF1565C0),
        tabs: const [Tab(text: 'Centres'), Tab(text: 'Arrond.'), Tab(text: 'Communes'), Tab(text: 'Bureaux')],
      ),
      Expanded(child: TabBarView(controller: _tc, children: [
        _CentreGraph(saisies: _saisies),
        _ArrGraph(saisies: _saisies),
        _CommuneGraph(saisies: _saisies),
        _BureauGraph(saisies: _saisies),
      ])),
    ]);
  }
}

// ══════════════════════════════════════════════
// CHART PRIMITIVES
// ══════════════════════════════════════════════
const List<Color> kPalette = [
  Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFE65100),
  Color(0xFF6A1B9A), Color(0xFF00695C), Color(0xFFC62828),
  Color(0xFF4527A0), Color(0xFF00838F), Color(0xFF558B2F),
];

// ── Scrollable horizontal bar chart ─────────────────────────────
class _HBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final String title;
  final String subtitle;
  final double barWidth;
  const _HBarChart({required this.values, required this.labels, required this.colors, required this.title, this.subtitle = '', this.barWidth = 48});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const Center(child: Text('Aucune donnée', style: TextStyle(color: Colors.grey)));
    final chartWidth = (barWidth + 8) * values.length + 60.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ])),
      Expanded(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth.clamp(MediaQuery.of(context).size.width - 16, double.infinity),
          child: CustomPaint(painter: _BarPainter(values: values, labels: labels, colors: colors, barWidth: barWidth)),
        ),
      )),
    ]);
  }
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final double barWidth;
  const _BarPainter({required this.values, required this.labels, required this.colors, this.barWidth = 48});

  @override
  void paint(Canvas canvas, Size size) {
    const ml = 40.0, mr = 8.0, mt = 8.0, mb = 52.0;
    final w = size.width - ml - mr;
    final h = size.height - mt - mb;
    if (w <= 0 || h <= 0) return;

    double maxVal = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;

    final axisPaint = Paint()..color = Colors.grey[300]!..strokeWidth = 0.8;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    // Y grid + labels
    for (int i = 0; i <= 4; i++) {
      final y = mt + h - (i / 4) * h;
      canvas.drawLine(Offset(ml, y), Offset(ml + w, y), axisPaint);
      tp.text = TextSpan(text: (maxVal * i / 4).toInt().toString(), style: const TextStyle(fontSize: 8, color: Colors.grey));
      tp.layout(); tp.paint(canvas, Offset(ml - tp.width - 2, y - tp.height / 2));
    }

    final slotW = w / values.length;
    final gap = (slotW - barWidth).clamp(4.0, 16.0);

    for (int i = 0; i < values.length; i++) {
      final x = ml + i * slotW + gap / 2;
      final bw = slotW - gap;
      final barH = (values[i] / maxVal) * h;
      final color = colors.isEmpty ? kPalette[i % kPalette.length] : colors[i % colors.length];

      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, mt + h - barH, bw, barH), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        Paint()..color = color,
      );

      // Value label on top of bar
      tp.text = TextSpan(text: values[i].toInt().toString(), style: const TextStyle(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.bold));
      tp.layout();
      if (barH > 12) canvas.drawRect(Rect.fromLTWH(x + bw / 2 - tp.width / 2 - 1, mt + h - barH - tp.height - 2, tp.width + 2, tp.height + 2), Paint()..color = Colors.white.withOpacity(0.7));
      tp.paint(canvas, Offset(x + bw / 2 - tp.width / 2, mt + h - barH - tp.height - 2));

      // X label — full label, rotated 35 degrees
      final lbl = labels[i];
      tp.text = TextSpan(text: lbl, style: const TextStyle(fontSize: 9, color: Colors.grey));
      tp.layout();
      canvas.save();
      canvas.translate(x + bw / 2, mt + h + 4);
      canvas.rotate(0.55); // ~32 degrees
      tp.paint(canvas, const Offset(0, 0));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => true;
}

// ── Line chart ──────────────────────────────────────────────────
class _LineChart extends StatelessWidget {
  final List<List<double>> series;
  final List<String> labels;
  final List<String> seriesNames;
  final String title;
  const _LineChart({required this.series, required this.labels, required this.seriesNames, required this.title});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty || (series.isNotEmpty && series[0].isEmpty)) {
      return const Center(child: Text('Aucune donnée disponible', style: TextStyle(color: Colors.grey)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
      Expanded(child: CustomPaint(size: Size.infinite, painter: _LinePainter(series: series, labels: labels))),
      Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 4), child: Wrap(spacing: 8, runSpacing: 2,
        children: List.generate(seriesNames.length, (i) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 3, color: kPalette[i % kPalette.length]),
          const SizedBox(width: 3),
          Text(seriesNames[i], style: const TextStyle(fontSize: 9)),
        ])),
      )),
    ]);
  }
}

class _LinePainter extends CustomPainter {
  final List<List<double>> series;
  final List<String> labels;
  const _LinePainter({required this.series, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    const ml = 44.0, mr = 8.0, mt = 8.0, mb = 28.0;
    final w = size.width - ml - mr, h = size.height - mt - mb;
    if (w <= 0 || h <= 0 || series.isEmpty) return;

    double maxVal = 0;
    for (final s in series) for (final v in s) if (v > maxVal) maxVal = v;
    if (maxVal == 0) maxVal = 1;

    final axisPaint = Paint()..color = Colors.grey[300]!..strokeWidth = 0.8;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 4; i++) {
      final y = mt + h - (i / 4) * h;
      canvas.drawLine(Offset(ml, y), Offset(ml + w, y), axisPaint);
      tp.text = TextSpan(text: (maxVal * i / 4).toInt().toString(), style: const TextStyle(fontSize: 8, color: Colors.grey));
      tp.layout(); tp.paint(canvas, Offset(ml - tp.width - 2, y - tp.height / 2));
    }

    final n = series[0].length;
    final step = n <= 9 ? 1 : (n / 8).ceil();
    for (int i = 0; i < labels.length; i += step) {
      final x = ml + (n <= 1 ? 0 : i / (n - 1)) * w;
      final lbl = labels[i].length > 5 ? labels[i].substring(0, 5) : labels[i];
      tp.text = TextSpan(text: lbl, style: const TextStyle(fontSize: 7, color: Colors.grey));
      tp.layout(); tp.paint(canvas, Offset(x - tp.width / 2, mt + h + 2));
    }

    for (int si = 0; si < series.length; si++) {
      final s = series[si];
      if (s.isEmpty) continue;
      final color = kPalette[si % kPalette.length];
      final linePaint = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (int i = 0; i < s.length; i++) {
        final x = ml + (s.length <= 1 ? 0 : i / (s.length - 1)) * w;
        final y = mt + h - (s[i] / maxVal) * h;
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}

// ══════════════════════════════════════════════
// ONGLET CENTRES
// ══════════════════════════════════════════════
class _CentreGraph extends StatefulWidget {
  final List<SaisieEntry> saisies;
  const _CentreGraph({required this.saisies});
  @override State<_CentreGraph> createState() => _CentreGraphState();
}

class _CentreGraphState extends State<_CentreGraph> {
  CentreSuivi? _sel;
  bool _cumul = false;

  @override
  Widget build(BuildContext context) {
    Map<String, int> combined = {};
    if (_sel != null) {
      _sel!.retraitsDailyData.forEach((k, v) { combined[k] = v; });
      for (final e in widget.saisies.where((s) => s.codeCentre == _sel!.codeCentre)) {
        combined[e.date] = (combined[e.date] ?? 0) + e.retraits;
      }
    }
    final sortedKeys = combined.keys.toList()..sort();
    final dailyVals = sortedKeys.map((k) => combined[k]!.toDouble()).toList();
    double cum = 0;
    final cumulVals = dailyVals.map((v) { cum += v; return cum; }).toList();

    return Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: DropdownButtonFormField<CentreSuivi>(
        decoration: const InputDecoration(labelText: 'Sélectionner un centre', border: OutlineInputBorder(), isDense: true),
        value: _sel, isExpanded: true,
        items: ElectionData.centresSuivi.map((c) => DropdownMenuItem(value: c, child: Text('${c.codeCentre}. ${c.nomCentre}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _sel = v),
      )),
      if (_sel != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
        const Text('Journalier', style: TextStyle(fontSize: 12)),
        Switch(value: _cumul, onChanged: (v) => setState(() => _cumul = v)),
        const Text('Cumulatif', style: TextStyle(fontSize: 12)),
        const Spacer(),
        Text('${(_sel!.pctRetrait * 100).toStringAsFixed(1)}% base', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ])),
      if (_sel == null) const Expanded(child: Center(child: Text('Sélectionner un centre', style: TextStyle(color: Colors.grey))))
      else if (sortedKeys.isEmpty) const Expanded(child: Center(child: Text('Aucune donnée pour ce centre', style: TextStyle(color: Colors.grey))))
      else Expanded(child: _LineChart(
        series: [_cumul ? cumulVals : dailyVals],
        labels: sortedKeys,
        seriesNames: [_cumul ? 'Cumul' : 'Journalier'],
        title: '${_sel!.nomCentre} — ${_cumul ? "Cumulatif" : "Journalier"}',
      )),
    ]);
  }
}

// ══════════════════════════════════════════════
// ONGLET ARRONDISSEMENTS
// ══════════════════════════════════════════════
class _ArrGraph extends StatefulWidget {
  final List<SaisieEntry> saisies;
  const _ArrGraph({required this.saisies});
  @override State<_ArrGraph> createState() => _ArrGraphState();
}

class _ArrGraphState extends State<_ArrGraph> {
  bool _evol = false;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        const Text('Comparatif', style: TextStyle(fontSize: 12)),
        Switch(value: _evol, onChanged: (v) => setState(() => _evol = v)),
        const Text('Évolution', style: TextStyle(fontSize: 12)),
      ])),
      Expanded(child: _evol ? _buildEvol() : _buildBar()),
    ]);
  }

  String _latestDate() {
    // Find most recent date across base data + saisies
    final allDates = <String>[];
    for (final c in ElectionData.centresSuivi) {
      allDates.addAll(c.retraitsDailyData.keys);
    }
    for (final s in widget.saisies) allDates.add(s.date);
    if (allDates.isEmpty) return ElectionData.dateMaj;
    allDates.sort();
    return allDates.last;
  }

  Widget _buildBar() {
    final data = ElectionData.syntheseArr;
    // Add new saisies per arrondissement
    final Map<String, int> newByArr = {};
    for (final e in widget.saisies) {
      newByArr[e.arrondissement] = (newByArr[e.arrondissement] ?? 0) + e.retraits;
    }
    return DefaultTabController(length: 2, child: Column(children: [
      const TabBar(labelColor: Color(0xFF1565C0), unselectedLabelColor: Colors.grey, indicatorColor: Color(0xFF1565C0),
        tabs: [Tab(text: '% retrait'), Tab(text: 'Nb retirés')]),
      Expanded(child: TabBarView(children: [
        _HBarChart(
          values: data.map((e) => e.pctRetrait * 100).toList(),
          labels: data.map((e) => e.arrondissement.replaceAll('arrondissement','Arr').replaceAll('Arrondissement','Arr').replaceAll('du Plateau','Plateau')).toList(),
          colors: kPalette.toList(),
          title: 'Taux de retrait par arrondissement (%)',
          subtitle: 'Données au ${_latestDate()}',
        ),
        _HBarChart(
          values: data.map((e) => (e.retires + (newByArr[e.arrondissement] ?? 0)).toDouble()).toList(),
          labels: data.map((e) => e.arrondissement.replaceAll('arrondissement','Arr').replaceAll('Arrondissement','Arr').replaceAll('du Plateau','Plateau')).toList(),
          colors: kPalette.toList(),
          title: 'Cartes retirées par arrondissement',
          subtitle: 'Historique + saisies locales',
        ),
      ])),
    ]));
  }

  Widget _buildEvol() {
    final Map<String, Map<String, int>> arrData = {};
    for (final c in ElectionData.centresSuivi) {
      arrData.putIfAbsent(c.arrondissement, () => {});
      c.retraitsDailyData.forEach((date, v) {
        arrData[c.arrondissement]![date] = (arrData[c.arrondissement]![date] ?? 0) + v;
      });
    }
    for (final e in widget.saisies) {
      arrData.putIfAbsent(e.arrondissement, () => {});
      arrData[e.arrondissement]![e.date] = (arrData[e.arrondissement]![e.date] ?? 0) + e.retraits;
    }
    final allDates = arrData.values.expand((m) => m.keys).toSet().toList()..sort();
    final arrNames = arrData.keys.toList()..sort();
    final series = arrNames.map((arr) => allDates.map((d) => (arrData[arr]?[d] ?? 0).toDouble()).toList()).toList();
    final shortNames = arrNames.map((a) => a.replaceAll('arrondissement','Arr').replaceAll('Arrondissement','Arr').replaceAll('du Plateau','Plateau')).toList();
    return _LineChart(series: series, labels: allDates, seriesNames: shortNames, title: 'Évolution journalière par arrondissement');
  }
}

// ══════════════════════════════════════════════
// ONGLET COMMUNES
// ══════════════════════════════════════════════
class _CommuneGraph extends StatelessWidget {
  final List<SaisieEntry> saisies;
  const _CommuneGraph({required this.saisies});

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, int>> data = {};
    for (final c in ElectionData.centresSuivi) {
      data.putIfAbsent(c.commune, () => {});
      c.retraitsDailyData.forEach((date, v) {
        data[c.commune]![date] = (data[c.commune]![date] ?? 0) + v;
      });
    }
    for (final e in saisies) {
      // find commune from centresSuivi
      final centre = ElectionData.centresSuivi.where((c) => c.codeCentre == e.codeCentre).firstOrNull;
      final commune = centre?.commune ?? 'Autre';
      data.putIfAbsent(commune, () => {});
      data[commune]![e.date] = (data[commune]![e.date] ?? 0) + e.retraits;
    }
    final allDates = data.values.expand((m) => m.keys).toSet().toList()..sort();
    final communes = data.keys.toList()..sort();
    final series = communes.map((c) => allDates.map((d) => (data[c]?[d] ?? 0).toDouble()).toList()).toList();
    final totals = communes.map((c) => data[c]!.values.fold(0, (a, b) => a + b).toDouble()).toList();

    return DefaultTabController(length: 2, child: Column(children: [
      const TabBar(labelColor: Color(0xFF1565C0), unselectedLabelColor: Colors.grey, indicatorColor: Color(0xFF1565C0),
        tabs: [Tab(text: 'Évolution'), Tab(text: 'Comparatif')]),
      Expanded(child: TabBarView(children: [
        _LineChart(series: series, labels: allDates, seriesNames: communes, title: 'Évolution journalière par commune'),
        _HBarChart(values: totals, labels: communes, colors: kPalette.toList(), title: 'Total retraits par commune'),
      ])),
    ]));
  }
}

// ══════════════════════════════════════════════
// ONGLET BUREAUX — scrollable, labels complets
// ══════════════════════════════════════════════
class _BureauGraph extends StatefulWidget {
  final List<SaisieEntry> saisies;
  const _BureauGraph({required this.saisies});
  @override State<_BureauGraph> createState() => _BureauGraphState();
}

class _BureauGraphState extends State<_BureauGraph> {
  String? _selCentre;

  @override
  Widget build(BuildContext context) {
    final centreNames = ElectionData.bureaux.map((b) => b.nomCentre).toSet().toList()..sort();
    final filtered = _selCentre == null ? <Bureau>[] : ElectionData.bureaux.where((b) => b.nomCentre == _selCentre).toList();

    // Build bureau labels: use the suffix after the last space (e.g. "-1", "-2") but prefix with bureau number for clarity
    List<String> labels = filtered.map((b) {
      // Extract bureau identifier: last token after space or dash
      final parts = b.nomBureau.split(RegExp(r'[\s\-]+'));
      final suffix = parts.last;
      // If suffix is just a number, show "B.N"
      final n = int.tryParse(suffix);
      return n != null ? 'B.$n' : suffix;
    }).toList();

    return Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Sélectionner un centre', border: OutlineInputBorder(), isDense: true),
        value: _selCentre, isExpanded: true,
        items: centreNames.map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _selCentre = v),
      )),
      if (_selCentre == null)
        const Expanded(child: Center(child: Text('Sélectionner un centre', style: TextStyle(color: Colors.grey))))
      else Expanded(child: DefaultTabController(length: 2, child: Column(children: [
        const TabBar(labelColor: Color(0xFF1565C0), unselectedLabelColor: Colors.grey, indicatorColor: Color(0xFF1565C0),
          tabs: [Tab(text: 'Votants / bureau'), Tab(text: 'Répartition')]),
        Expanded(child: TabBarView(children: [
          // Scrollable bar chart with proper labels
          _HBarChart(
            values: filtered.map((b) => b.votants.toDouble()).toList(),
            labels: labels,
            colors: kPalette.toList(),
            title: 'Votants par bureau — $_selCentre',
            subtitle: '${filtered.length} bureaux • ${filtered.fold(0, (s, b) => s + b.votants)} votants total',
            barWidth: 36,
          ),
          _PieWidget(
            values: filtered.map((b) => b.votants.toDouble()).toList(),
            labels: labels,
            title: 'Répartition — $_selCentre',
          ),
        ])),
      ]))),
    ]);
  }
}

// ══════════════════════════════════════════════
// PIE CHART
// ══════════════════════════════════════════════
class _PieWidget extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String title;
  const _PieWidget({required this.values, required this.labels, required this.title});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const Center(child: Text('Aucune donnée'));
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
      Expanded(child: Row(children: [
        Expanded(flex: 3, child: CustomPaint(size: Size.infinite, painter: _PiePainter(values: values))),
        Expanded(flex: 2, child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(values.length, (i) {
            final pct = (values[i] / values.fold(0.0, (a, b) => a + b) * 100).toStringAsFixed(1);
            return Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: kPalette[i % kPalette.length], shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Expanded(child: Text('${labels[i]}: $pct%', style: const TextStyle(fontSize: 9))),
            ]));
          }),
        )))),
      ])),
    ]);
  }
}

class _PiePainter extends CustomPainter {
  final List<double> values;
  const _PiePainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;
    final cx = size.width / 2, cy = size.height / 2;
    final r = ((cx < cy ? cx : cy) * 0.85).clamp(0.0, 120.0);
    double start = -3.14159265 / 2;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * 3.14159265;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start, sweep, true, Paint()..color = kPalette[i % kPalette.length]);
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start, sweep, true, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
      if (values[i] / total > 0.06) {
        final mid = start + sweep / 2;
        final lx = cx + r * 0.6 * _cos(mid), ly = cy + r * 0.6 * _sin(mid);
        tp.text = TextSpan(text: '${(values[i] / total * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold));
        tp.layout(); tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }
      start += sweep;
    }
  }

  double _cos(double a) {
    a = a % (2 * 3.14159265);
    if (a < 0) a += 2 * 3.14159265;
    // Taylor approximation good enough for a chart
    double s = 1, t = 1;
    for (int i = 1; i <= 8; i++) {
      t *= -a * a / (2 * i * (2 * i - 1));
      s += t;
    }
    return s;
  }

  double _sin(double a) => _cos(a - 3.14159265 / 2);

  @override
  bool shouldRepaint(_PiePainter old) => true;
}
