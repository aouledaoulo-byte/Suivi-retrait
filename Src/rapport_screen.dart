import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'election_data.dart';
import 'db_helper.dart';

class RapportScreen extends StatefulWidget {
  const RapportScreen({super.key});
  @override
  State<RapportScreen> createState() => _RapportScreenState();
}

class _RapportScreenState extends State<RapportScreen> {
  List<SaisieEntry> _saisies = [];
  bool _loaded = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await DbHelper.all();
    setState(() { _saisies = s; _loaded = true; });
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+\$)'), (m) => '${m[1]} ');

  String _pctColor(double p) =>
      p >= 40 ? '#16a34a' : p >= 25 ? '#d97706' : '#dc2626';

  String _status(double p) =>
      p >= 40 ? 'OK' : p >= 25 ? 'ALERTE' : 'CRITIQUE';

  Future<void> _generateAndShare() async {
    setState(() => _generating = true);
    try {
      final centres = ElectionData.centresSuivi;
      final newByCode = <int, int>{};
      for (final s in _saisies) {
        newByCode[s.codeCentre] = (newByCode[s.codeCentre] ?? 0) + s.retraits;
      }
      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      int totalIns = 0;
      int totalRet = 0;
      for (final c in centres) {
        totalIns = totalIns + c.inscrits;
        totalRet = totalRet + c.cumulRetraits + (newByCode[c.codeCentre] ?? 0);
      }
      final pctNat = totalIns > 0 ? totalRet / totalIns * 100 : 0.0;

      final ranked = List<CentreSuivi>.from(centres)
        ..sort((a, b) {
          final pa = a.inscrits > 0
              ? (a.cumulRetraits + (newByCode[a.codeCentre] ?? 0)) / a.inscrits
              : 0.0;
          final pb = b.inscrits > 0
              ? (b.cumulRetraits + (newByCode[b.codeCentre] ?? 0)) / b.inscrits
              : 0.0;
          return pb.compareTo(pa);
        });

      final medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
      String top5 = '';
      for (int i = 0; i < 5 && i < ranked.length; i++) {
        final c = ranked[i];
        final tot = c.cumulRetraits + (newByCode[c.codeCentre] ?? 0);
        final p = c.inscrits > 0 ? tot / c.inscrits * 100 : 0.0;
        final flower = p >= 50 ? ' 🌸' : '';
        top5 += '<tr><td style="text-align:center;padding:6px">${medals[i]}</td>'
            '<td style="padding:6px;font-weight:700">${c.nomCentre}$flower</td>'
            '<td style="text-align:right;padding:6px;font-weight:800;color:#16a34a">${p.toStringAsFixed(1)}%</td></tr>';
      }

      String bottom5 = '';
      for (int i = ranked.length - 1; i >= ranked.length - 5 && i >= 0; i--) {
        final c = ranked[i];
        final tot = c.cumulRetraits + (newByCode[c.codeCentre] ?? 0);
        final p = c.inscrits > 0 ? tot / c.inscrits * 100 : 0.0;
        bottom5 = '<tr><td style="text-align:center;padding:6px">⚠️</td>'
            '<td style="padding:6px;font-weight:700">${c.nomCentre}</td>'
            '<td style="text-align:right;padding:6px;font-weight:800;color:#dc2626">${p.toStringAsFixed(1)}%</td></tr>'
            + bottom5;
      }

      final arrMap = <String, List<CentreSuivi>>{};
      for (final c in centres) {
        arrMap.putIfAbsent(c.arrondissement, () => []).add(c);
      }
      String arrSection = '';
      for (final entry in arrMap.entries) {
        int aIns = 0, aRet = 0;
        for (final c in entry.value) {
          aIns = aIns + c.inscrits;
          aRet = aRet + c.cumulRetraits + (newByCode[c.codeCentre] ?? 0);
        }
        final ap = aIns > 0 ? aRet / aIns * 100 : 0.0;
        final acol = _pctColor(ap);
        arrSection += '<tr style="background:#eff6ff"><td colspan="5" style="padding:7px;font-weight:700;color:#1d4ed8">'
            '🏙️ ${entry.key} — ${_fmt(aRet)}/${_fmt(aIns)} = <span style="color:$acol">${ap.toStringAsFixed(1)}%</span></td></tr>';
        final sorted = List<CentreSuivi>.from(entry.value)
          ..sort((a, b) => a.codeCentre.compareTo(b.codeCentre));
        for (final c in sorted) {
          final tot = c.cumulRetraits + (newByCode[c.codeCentre] ?? 0);
          final rest = c.inscrits - tot;
          final p = c.inscrits > 0 ? tot / c.inscrits * 100 : 0.0;
          final col = _pctColor(p); final st = _status(p);
          final flower = p >= 50 ? ' 🌸' : '';
          final bw = p.clamp(0, 100).toStringAsFixed(1);
          arrSection += '<tr><td style="text-align:center;padding:5px;font-weight:700;color:#1565C0">${c.codeCentre}</td>'
              '<td style="padding:5px">${c.nomCentre}$flower</td>'
              '<td style="text-align:right;padding:5px">${_fmt(c.inscrits)}</td>'
              '<td style="text-align:right;padding:5px;font-weight:700;color:$col">${_fmt(tot)}</td>'
              '<td style="padding:5px;min-width:100px"><div style="display:flex;align-items:center;gap:3px">'
              '<div style="flex:1;height:5px;background:#e5e7eb;border-radius:3px;overflow:hidden">'
              '<div style="height:100%;width:$bw%;background:$col"></div></div>'
              '<span style="color:$col;font-weight:700;font-size:10px">${p.toStringAsFixed(1)}% $st</span></div></td></tr>';
        }
      }

      final html = """<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rapport $dateStr</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:system-ui,sans-serif;font-size:11px;color:#111;padding:14px;max-width:900px;margin:0 auto}
.cover{text-align:center;padding:20px 0;border-bottom:3px solid #1565C0;margin-bottom:14px}
.kpi-row{display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap}
.kpi{flex:1;min-width:75px;border:1px solid #e5e7eb;border-radius:8px;padding:9px;border-top:4px solid;text-align:center}
.prog{background:#1565C0;border-radius:10px;padding:12px;color:white;text-align:center;margin-bottom:14px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:12px}
.box{border:1px solid #e5e7eb;border-radius:8px;overflow:hidden}
.bh-g{background:linear-gradient(135deg,#16a34a,#4ade80);padding:7px 10px;color:white;font-weight:800;font-size:11px}
.bh-r{background:linear-gradient(135deg,#dc2626,#f87171);padding:7px 10px;color:white;font-weight:800;font-size:11px}
.st{font-size:11px;font-weight:700;color:#1565C0;border-bottom:2px solid #1565C0;padding-bottom:3px;margin:12px 0 8px;text-transform:uppercase}
table{width:100%;border-collapse:collapse}th{background:#1565C0;color:#fff;font-size:9px;padding:5px 6px;text-align:left}
td{border-bottom:1px solid #f3f4f6;vertical-align:middle}
.ft{margin-top:16px;padding-top:8px;border-top:1px solid #e5e7eb;text-align:center;font-size:9px;color:#9ca3af}
@media print{@page{size:A4;margin:10mm}}</style></head><body>
<div class="cover"><div style="font-size:28px">🇩🇯</div>
<div style="font-size:16px;font-weight:800;color:#1565C0;margin-top:5px">ÉLECTIONS PRÉSIDENTIELLES 2026</div>
<div style="color:#374151;margin-top:3px">Rapport de suivi — Retrait des cartes électorales</div>
<div style="color:#6b7280;font-size:10px;margin-top:4px">Au $dateStr</div></div>
<div class="kpi-row">
<div class="kpi" style="border-top-color:#1565C0"><div style="font-size:8px;color:#6b7280">INSCRITS</div><div style="font-size:14px;font-weight:800;color:#1565C0">${_fmt(totalIns)}</div></div>
<div class="kpi" style="border-top-color:#16a34a"><div style="font-size:8px;color:#6b7280">RETIRÉES</div><div style="font-size:14px;font-weight:800;color:#16a34a">${_fmt(totalRet)}</div></div>
<div class="kpi" style="border-top-color:#d97706"><div style="font-size:8px;color:#6b7280">RESTANT</div><div style="font-size:14px;font-weight:800;color:#d97706">${_fmt(totalIns - totalRet)}</div></div>
<div class="kpi" style="border-top-color:#7c3aed"><div style="font-size:8px;color:#6b7280">TAUX</div><div style="font-size:14px;font-weight:800;color:#7c3aed">${pctNat.toStringAsFixed(2)}%</div></div>
</div>
<div class="prog"><div style="font-size:10px;opacity:0.8">Avancement retraits · Objectif 85%</div>
<div style="font-size:24px;font-weight:800;margin:3px 0">${pctNat.toStringAsFixed(2)}%</div>
<div style="height:7px;background:rgba(255,255,255,0.2);border-radius:4px;overflow:hidden">
<div style="height:100%;width:${pctNat.clamp(0,100).toStringAsFixed(1)}%;background:#4ade80;border-radius:4px"></div></div>
<div style="font-size:9px;opacity:0.7;margin-top:3px">${_fmt(totalRet)} / ${_fmt(totalIns)}</div></div>
<div class="grid">
<div class="box"><div class="bh-g">🏆 TOP 5 Meilleurs centres</div>
<table><thead><tr><th>#</th><th>Centre</th><th style="text-align:right">Taux</th></tr></thead><tbody>$top5</tbody></table></div>
<div class="box"><div class="bh-r">🚨 Centres en retard</div>
<table><thead><tr><th>#</th><th>Centre</th><th style="text-align:right">Taux</th></tr></thead><tbody>$bottom5</tbody></table></div>
</div>
<div class="st">Détail par arrondissement</div>
<table><thead><tr><th style="width:26px;text-align:center">#</th><th>Centre</th>
<th style="text-align:right">Inscrits</th><th style="text-align:right">Retirés</th>
<th style="width:130px">Taux</th></tr></thead><tbody>$arrSection</tbody></table>
<div class="ft">Élections 2026 — Djibouti | $dateStr | 162 833 inscrits · 413 bureaux · 39 centres</div>
</body></html>""";

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rapport_${dateStr.replaceAll('/', '-')}.html');
      await file.writeAsString(html);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/html')],
        subject: 'Rapport Retraits — $dateStr',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final centres = ElectionData.centresSuivi;
    final newByCode = <int, int>{};
    for (final s in _saisies) newByCode[s.codeCentre] = (newByCode[s.codeCentre] ?? 0) + s.retraits;
    int totalIns = 0, totalRet = 0;
    for (final c in centres) {
      totalIns = totalIns + c.inscrits;
      totalRet = totalRet + c.cumulRetraits + (newByCode[c.codeCentre] ?? 0);
    }
    final pct = totalIns > 0 ? totalRet / totalIns * 100 : 0.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('📊 Rapport retraits cartes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Column(children: [Text(_fmt(totalRet), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16a34a))), const Text('Retirées', style: TextStyle(fontSize: 11, color: Colors.grey))]),
            Column(children: [Text('${pct.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))), const Text('Taux', style: TextStyle(fontSize: 11, color: Colors.grey))]),
            Column(children: [Text(_fmt(totalIns - totalRet), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFd97706))), const Text('Restant', style: TextStyle(fontSize: 11, color: Colors.grey))]),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: pct / 100, backgroundColor: Colors.grey[200], color: const Color(0xFF1565C0), minHeight: 8),
          const SizedBox(height: 4),
          Text('Objectif 85% — Écart: ${_fmt((totalIns * 0.85 - totalRet).toInt())} cartes', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]))),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _generating ? null : _generateAndShare,
          icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.share),
          label: Text(_generating ? 'Génération...' : '📤 Générer et partager (HTML)'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
        const SizedBox(height: 8),
        const Text('Le rapport HTML se partage via email / WhatsApp', style: TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
      ])),
    );
  }
}