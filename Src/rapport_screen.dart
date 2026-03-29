import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'election_data.dart';
import 'db_helper.dart';

class RapportScreen extends StatefulWidget {
  const RapportScreen({super.key});
  @override State<RapportScreen> createState() => _RapportScreenState();
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
    final db = DbHelper();
    final s = await db.getSaisies();
    setState(() { _saisies = s; _loaded = true; });
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

  Future<void> _generateAndShare() async {
    setState(() => _generating = true);
    try {
      final centres = ElectionData.centresSuivi;
      final newByCode = <int, int>{};
      for (final s in _saisies) {
        newByCode[s.codeCentre] = (newByCode[s.codeCentre] ?? 0) + s.retraits;
      }

      final date = DateTime.now();
      final dateStr = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';

      int totalIns = 0, totalRet = 0;
      for (final c in centres) {
        totalIns = totalIns + c.inscrits;
        totalRet = totalRet + c.cumulRetraits + (newByCode[c.codeCentre] ?? 0);
      }
      final pctNat = totalIns > 0 ? totalRet / totalIns * 100 : 0.0;

      // Rank centres
      final ranked = List.from(centres)..sort((a, b) {
        final pa = a.inscrits > 0 ? (a.cumulRetraits + (newByCode[a.codeCentre]??0)) / a.inscrits : 0.0;
        final pb = b.inscrits > 0 ? (b.cumulRetraits + (newByCode[b.codeCentre]??0)) / b.inscrits : 0.0;
        return pb.compareTo(pa);
      });

      // Group by arrondissement
      final arrMap = <String, List<CentreSuivi>>{};
      for (final c in centres) {
        arrMap.putIfAbsent(c.arrondissement, () => []).add(c);
      }

      String pctColor(double p) => p >= 40 ? '#16a34a' : p >= 25 ? '#d97706' : '#dc2626';
      String status(double p) => p >= 40 ? 'OK' : p >= 25 ? 'ALERTE' : 'CRITIQUE';

      // TOP 5 / BOTTOM 5
      String top5 = '', bottom5 = '';
      final medals = ['馃','馃','馃','4锔忊儯','5锔忊儯'];
      for (int i = 0; i < 5 && i < ranked.length; i++) {
        final c = ranked[i];
        final int tot = (c.cumulRetraits + (newByCode[c.codeCentre] ?? 0)).toInt();
        final p = c.inscrits > 0 ? tot / c.inscrits * 100 : 0.0;
        final flower = p >= 50 ? ' 馃尭' : '';
        top5 += '<tr style="background:${p>=50?"#fdf4ff":"white"}"><td style="text-align:center">${medals[i]}</td>'
            '<td><strong>${c.nomCentre}$flower</strong></td>'
            '<td style="color:#6b7280;font-size:10px">${c.arrondissement.replaceAll("arrondissement","Arr.")}</td>'
            '<td style="text-align:right;font-weight:700;color:#16a34a">${p.toStringAsFixed(1)}%</td></tr>';
      }
      for (int i = ranked.length - 1; i >= ranked.length - 5 && i >= 0; i--) {
        final c = ranked[i];
        final int tot = (c.cumulRetraits + (newByCode[c.codeCentre] ?? 0)).toInt();
        final p = c.inscrits > 0 ? tot / c.inscrits * 100 : 0.0;
        bottom5 = '<tr><td style="text-align:center">鈿狅笍</td>'
            '<td><strong>${c.nomCentre}</strong></td>'
            '<td style="color:#6b7280;font-size:10px">${c.arrondissement.replaceAll("arrondissement","Arr.")}</td>'
            '<td style="text-align:right;font-weight:700;color:#dc2626">${p.toStringAsFixed(1)}%</td></tr>'
            + bottom5;
      }

      // Arrondissement section
      String arrSection = '';
      for (final entry in arrMap.entries) {
        final cs = entry.value;
        final arrIns = cs.fold(0, (s, c) => s + c.inscrits);
        final int arrRet = cs.fold<int>(0, (s, c) => s + (c.cumulRetraits + (newByCode[c.codeCentre] ?? 0)).toInt());
        final arrPct = arrIns > 0 ? arrRet / arrIns * 100 : 0.0;
        final col = pctColor(arrPct);
        arrSection += '''
        <tr style="background:#eff6ff">
          <td colspan="6" style="font-weight:700;color:#1d4ed8;padding:7px 8px">
            馃彊锔� ${entry.key} 鈥� ${_fmt(arrRet)} / ${_fmt(arrIns)} = <span style="color:$col">${arrPct.toStringAsFixed(1)}%</span>
          </td>
        </tr>''';
        for (final c in cs..sort((a,b)=>a.codeCentre.compareTo(b.codeCentre))) {
          final int tot = (c.cumulRetraits + (newByCode[c.codeCentre] ?? 0)).toInt();
          final rest = c.inscrits - tot;
          final p = c.inscrits > 0 ? tot / c.inscrits * 100 : 0.0;
          final col2 = pctColor(p);
          final st = status(p);
          final flower = p >= 50 ? ' 馃尭' : '';
          final barW = p.clamp(0, 100).toStringAsFixed(1);
          arrSection += '''<tr>
            <td style="text-align:center;font-weight:700;color:#1565C0">${c.codeCentre}</td>
            <td>${c.nomCentre}$flower</td>
            <td style="text-align:right">${_fmt(c.inscrits)}</td>
            <td style="text-align:right;font-weight:700;color:$col2">${_fmt(tot)}</td>
            <td style="text-align:right;color:#6b7280">${_fmt(rest)}</td>
            <td style="min-width:120px">
              <div style="display:flex;align-items:center;gap:4px">
                <div style="flex:1;height:6px;background:#e5e7eb;border-radius:3px;overflow:hidden">
                  <div style="height:100%;width:$barW%;background:$col2"></div>
                </div>
                <span style="font-weight:700;color:$col2;font-size:10px">${p.toStringAsFixed(1)}% <span style="color:#9ca3af;font-weight:400">$st</span></span>
              </div>
            </td>
          </tr>''';
        }
      }

      final html = '''<!DOCTYPE html>
<html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rapport Retraits 鈥� $dateStr</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap');
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Inter',sans-serif;font-size:11px;color:#111827;padding:16px;max-width:900px;margin:0 auto}
.cover{text-align:center;padding:28px 0;border-bottom:3px solid #1565C0;margin-bottom:18px}
.kpi-row{display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap}
.kpi{flex:1;min-width:80px;border:1px solid #e5e7eb;border-radius:8px;padding:10px;border-top:4px solid}
.section-title{font-size:12px;font-weight:700;color:#1565C0;border-bottom:2px solid #1565C0;padding-bottom:4px;margin:16px 0 10px;text-transform:uppercase}
table{width:100%;border-collapse:collapse;margin-bottom:12px}
th{background:#1565C0;color:#fff;font-size:9px;padding:6px 8px;text-align:left}
td{padding:5px 8px;border-bottom:1px solid #f3f4f6;vertical-align:middle}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:16px}
.box{border:1px solid #e5e7eb;border-radius:8px;overflow:hidden}
.box-head-green{background:linear-gradient(135deg,#16a34a,#4ade80);padding:8px 12px;color:white;font-weight:800;font-size:12px}
.box-head-red{background:linear-gradient(135deg,#dc2626,#f87171);padding:8px 12px;color:white;font-weight:800;font-size:12px}
@media print{body{padding:8px}@page{size:A4;margin:10mm}}
</style></head><body>
<div class="cover">
  <div style="font-size:32px">馃嚛馃嚡</div>
  <div style="font-size:18px;font-weight:800;color:#1565C0;margin-top:6px">脡LECTIONS PR脡SIDENTIELLES 2026</div>
  <div style="color:#374151;margin-top:4px">Rapport de suivi 鈥� Retrait des cartes 茅lectorales</div>
  <div style="color:#6b7280;font-size:10px;margin-top:6px">Donn茅es au <strong>$dateStr</strong></div>
</div>
<div class="kpi-row">
  <div class="kpi" style="border-top-color:#1565C0"><div style="font-size:8px;color:#6b7280;text-transform:uppercase">Inscrits</div><div style="font-size:16px;font-weight:800;color:#1565C0">${_fmt(totalIns)}</div></div>
  <div class="kpi" style="border-top-color:#16a34a"><div style="font-size:8px;color:#6b7280;text-transform:uppercase">Retir茅es</div><div style="font-size:16px;font-weight:800;color:#16a34a">${_fmt(totalRet)}</div></div>
  <div class="kpi" style="border-top-color:#d97706"><div style="font-size:8px;color:#6b7280;text-transform:uppercase">Restant</div><div style="font-size:16px;font-weight:800;color:#d97706">${_fmt(totalIns - totalRet)}</div></div>
  <div class="kpi" style="border-top-color:#7c3aed"><div style="font-size:8px;color:#6b7280;text-transform:uppercase">Taux</div><div style="font-size:16px;font-weight:800;color:#7c3aed">${pctNat.toStringAsFixed(2)}%</div></div>
</div>
<div style="background:#1565C0;border-radius:10px;padding:14px;color:white;margin-bottom:16px;text-align:center">
  <div style="font-size:11px;opacity:0.8;margin-bottom:4px">Avancement retraits</div>
  <div style="font-size:28px;font-weight:800">${pctNat.toStringAsFixed(2)}%</div>
  <div style="height:8px;background:rgba(255,255,255,0.2);border-radius:4px;margin-top:8px;overflow:hidden">
    <div style="height:100%;width:${pctNat.clamp(0,100).toStringAsFixed(1)}%;background:#4ade80;border-radius:4px"></div>
  </div>
</div>
<div class="grid">
  <div class="box">
    <div class="box-head-green">馃弳 TOP 5 鈥� Meilleurs centres</div>
    <table><thead><tr><th>#</th><th>Centre</th><th>Arr.</th><th style="text-align:right">Taux</th></tr></thead>
    <tbody>$top5</tbody></table>
  </div>
  <div class="box">
    <div class="box-head-red">馃毃 RETARDATAIRES</div>
    <table><thead><tr><th>#</th><th>Centre</th><th>Arr.</th><th style="text-align:right">Taux</th></tr></thead>
    <tbody>$bottom5</tbody></table>
  </div>
</div>
<div class="section-title">D茅tail par centre</div>
<table><thead><tr>
  <th style="width:30px;text-align:center">#</th><th>Centre</th>
  <th style="text-align:right">Inscrits</th><th style="text-align:right">Retir茅s</th>
  <th style="text-align:right">Restant</th><th style="width:160px">Taux</th>
</tr></thead><tbody>$arrSection</tbody></table>
<div style="text-align:center;font-size:9px;color:#9ca3af;margin-top:16px;padding-top:8px;border-top:1px solid #e5e7eb">
  脡lections 2026 鈥� Djibouti | $dateStr | 162 833 inscrits 路 413 bureaux 路 39 centres
</div>
</body></html>''';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rapport_$dateStr.html'.replaceAll('/', '-'));
      await file.writeAsString(html);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/html')],
        subject: 'Rapport Retraits 鈥� $dateStr',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final centres = ElectionData.centresSuivi;
    final newByCode = <int, int>{};
    for (final s in _saisies) {
      newByCode[s.codeCentre] = (newByCode[s.codeCentre] ?? 0) + s.retraits;
    }
    int totalRet = 0, totalIns = 0;
    for (final c in centres) {
      totalIns = totalIns + c.inscrits;
      totalRet = totalRet + c.cumulRetraits + (newByCode[c.codeCentre] ?? 0);
    }
    final pct = totalIns > 0 ? totalRet / totalIns * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Rapport'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            const Text('馃搳 Rapport de retrait des cartes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Column(children: [Text(_fmt(totalRet), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF16a34a))), const Text('Retir茅es', style: TextStyle(fontSize: 11, color: Colors.grey))]),
              Column(children: [Text('${pct.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))), const Text('Taux', style: TextStyle(fontSize: 11, color: Colors.grey))]),
              Column(children: [Text(_fmt(totalIns - totalRet), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFd97706))), const Text('Restant', style: TextStyle(fontSize: 11, color: Colors.grey))]),
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: pct / 100, backgroundColor: Colors.grey[200], color: const Color(0xFF1565C0), minHeight: 8),
          ]))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _generating ? null : _generateAndShare,
            icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.share),
            label: Text(_generating ? 'G茅n茅ration en cours...' : '馃摛 G茅n茅rer et partager le rapport HTML'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
          const SizedBox(height: 8),
          const Text('Le rapport s\'ouvre dans votre navigateur ou peut 锚tre partag茅 par email/WhatsApp', style: TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
