import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'election_data.dart';
import 'db_helper.dart';

class RapportScreen extends StatefulWidget {
  const RapportScreen({super.key});
  @override State<RapportScreen> createState() => _RapportScreenState();
}

class _RapportScreenState extends State<RapportScreen> {
  List<SaisieEntry> _saisies = [];
  Map<int, int> _newByCode = {};
  bool _loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final all = await DbHelper.all();
    final Map<int, int> m = {};
    for (final s in all) m[s.codeCentre] = (m[s.codeCentre] ?? 0) + s.retraits;
    if (mounted) setState(() { _saisies = all; _newByCode = m; _loaded = true; });
  }

  int get _newTotal => _newByCode.values.fold(0, (s, v) => s + v);
  int get _totalRetires => ElectionData.totalRetires + _newTotal;
  int get _totalRestant => ElectionData.totalInscrits - _totalRetires;
  double get _pct => _totalRetires / ElectionData.totalInscrits;

  String _latestDate() {
    final dates = <String>[];
    for (final c in ElectionData.centresSuivi) dates.addAll(c.retraitsDailyData.keys);
    for (final s in _saisies) dates.add(s.date);
    if (dates.isEmpty) return ElectionData.dateMaj;
    dates.sort(); return dates.last;
  }

  String _fmt(int n) {
    final s = n.toString(); final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Color _pctColor(double p) {
    if (p >= 30) return const Color(0xFF16a34a);
    if (p >= 8.5) return const Color(0xFFd97706);
    return const Color(0xFFdc2626);
  }

  String _status(double p) => p >= 30 ? 'OK' : p >= 8.5 ? 'ALERTE' : 'CRITIQUE';

  // ── Build HTML string (save to file) ──────
  String _buildHtml() {
    final date = _latestDate();
    final pct  = _pct * 100;

    // Synthese
    final synth = StringBuffer();
    final sorted = [...ElectionData.syntheseArr]..sort((a,b) => b.pctRetrait.compareTo(a.pctRetrait));
    for (int i = 0; i < sorted.length; i++) {
      final a = sorted[i]; final p = a.pctRetrait * 100;
      final c = p>=30?'#16a34a':p>=8.5?'#d97706':'#dc2626';
      synth.write('<tr><td style="text-align:center;font-weight:700;color:#1565C0">${i+1}</td>'
        '<td>${a.arrondissement}</td>'
        '<td style="text-align:right">${_fmt(a.inscrits)}</td>'
        '<td style="text-align:right;color:$c;font-weight:700">${_fmt(a.retires)}</td>'
        '<td style="text-align:right;color:#6b7280">${_fmt(a.restant)}</td>'
        '<td style="text-align:right;color:$c;font-weight:700">${p.toStringAsFixed(2)}%</td></tr>');
    }
    synth.write('<tr style="background:#eff6ff"><td colspan="2" style="font-weight:700;color:#1d4ed8">TOTAL NATIONAL</td>'
      '<td style="text-align:right;font-weight:700">${_fmt(ElectionData.totalInscrits)}</td>'
      '<td style="text-align:right;font-weight:700;color:#16a34a">${_fmt(_totalRetires)}</td>'
      '<td style="text-align:right;font-weight:700">${_fmt(_totalRestant)}</td>'
      '<td style="text-align:right;font-weight:700;color:#1565C0">${pct.toStringAsFixed(2)}%</td></tr>');

    // Centres
    final centres = StringBuffer();
    final arrOrder = ElectionData.syntheseArr.map((a) => a.arrondissement).toList();
    for (final arrName in arrOrder) {
      final cs = ElectionData.centresSuivi.where((c) => c.arrondissement == arrName).toList()
        ..sort((a,b) => a.codeCentre.compareTo(b.codeCentre));
      if (cs.isEmpty) continue;
      final arrTotR = cs.fold(0, (s,c) => s + c.cumulRetraits + (_newByCode[c.codeCentre]??0));
      final arrTotI = cs.fold(0, (s,c) => s + c.inscrits);
      final arrPct  = arrTotI > 0 ? arrTotR/arrTotI*100 : 0.0;
      final ac = arrPct>=30?'#16a34a':arrPct>=8.5?'#d97706':'#dc2626';
      centres.write('<tr style="background:#eff6ff"><td colspan="7" style="font-weight:700;color:#1d4ed8;padding:8px">'
        '🏙️ $arrName <span style="font-size:10px;color:#6b7280;font-weight:400">'
        '${_fmt(arrTotI)} inscrits | ${_fmt(arrTotR)} retirés | ${arrPct.toStringAsFixed(1)}%</span></td></tr>');
      for (final c in cs) {
        final tot = c.cumulRetraits + (_newByCode[c.codeCentre]??0);
        final rest= c.inscrits - tot;
        final p   = c.inscrits>0 ? tot/c.inscrits*100 : 0.0;
        final cc  = p>=30?'#16a34a':p>=8.5?'#d97706':'#dc2626';
        final st  = p>=30?'OK':p>=8.5?'ALERTE':'CRITIQUE';
        final stbg= p>=30?'#dcfce7':p>=8.5?'#fef9c3':'#fee2e2';
        centres.write('<tr><td style="text-align:center;font-weight:700;color:#1565C0">${c.codeCentre}</td>'
          '<td>${c.nomCentre}<br><span style="font-size:9px;color:#9ca3af">${c.commune}</span></td>'
          '<td style="text-align:right">${_fmt(c.inscrits)}</td>'
          '<td style="text-align:right;color:$cc;font-weight:700">${_fmt(tot)}</td>'
          '<td style="text-align:right;color:#6b7280">${_fmt(rest)}</td>'
          '<td style="text-align:right;color:$cc;font-weight:700">${p.toStringAsFixed(1)}%</td>'
          '<td style="text-align:center"><span style="background:$stbg;color:$cc;padding:2px 6px;border-radius:10px;font-size:9px;font-weight:700">$st</span></td></tr>');
      }
      centres.write('<tr style="background:#f9fafb;border-top:2px solid #d1d5db">'
        '<td colspan="2" style="text-align:right;font-weight:700">Total</td>'
        '<td style="text-align:right;font-weight:700">${_fmt(arrTotI)}</td>'
        '<td style="text-align:right;font-weight:700;color:$ac">${_fmt(arrTotR)}</td>'
        '<td style="text-align:right;font-weight:700">${_fmt(arrTotI-arrTotR)}</td>'
        '<td style="text-align:right;font-weight:700;color:$ac">${arrPct.toStringAsFixed(2)}%</td><td></td></tr>'
        '<tr><td colspan="7" style="height:8px"></td></tr>');
    }

    return '''<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rapport $date</title>
<style>
body{font-family:Arial,sans-serif;font-size:11px;color:#111;padding:16px;max-width:900px;margin:0 auto}
.cover{text-align:center;padding:24px 0 18px;border-bottom:3px solid #1565C0;margin-bottom:18px}
.cover h1{font-size:18px;color:#1565C0;margin:8px 0 4px}
.cover p{font-size:12px;color:#555;margin:2px}
.info-row{display:flex;justify-content:center;gap:20px;margin-bottom:16px}
.info-box{text-align:center;background:#f0f9ff;border:1px solid #bfdbfe;border-radius:8px;padding:8px 18px}
.info-box.g{background:#f0fdf4;border-color:#bbf7d0}
.info-val{font-size:20px;font-weight:800;color:#1565C0}
.info-box.g .info-val{color:#16a34a}
.info-lbl{font-size:9px;color:#6b7280;text-transform:uppercase}
.kpis{display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap}
.kpi{flex:1;min-width:80px;border:1px solid #e5e7eb;border-radius:8px;padding:8px;border-top:3px solid}
.kpi.b{border-top-color:#1565C0}.kpi.g{border-top-color:#16a34a}.kpi.o{border-top-color:#d97706}.kpi.p{border-top-color:#7c3aed}
.kpi-l{font-size:9px;color:#6b7280;text-transform:uppercase;margin-bottom:2px}
.kpi-v{font-size:16px;font-weight:800}
.kpi.b .kpi-v{color:#1565C0}.kpi.g .kpi-v{color:#16a34a}.kpi.o .kpi-v{color:#d97706}.kpi.p .kpi-v{color:#7c3aed}
h2{font-size:11px;font-weight:700;color:#1565C0;border-bottom:2px solid #1565C0;padding-bottom:3px;margin:14px 0 10px;text-transform:uppercase;letter-spacing:.5px}
table{width:100%;border-collapse:collapse;margin-bottom:6px}
th{background:#1565C0;color:#fff;font-size:9px;font-weight:600;text-transform:uppercase;padding:6px 7px;text-align:left}
td{padding:5px 7px;border-bottom:1px solid #f3f4f6;vertical-align:middle}
tr:nth-child(even) td{background:#fafafa}
.footer{margin-top:20px;padding-top:8px;border-top:1px solid #e5e7eb;text-align:center;font-size:9px;color:#9ca3af}
@media print{@page{size:A4;margin:12mm}}
</style></head><body>
<div class="cover"><div style="font-size:32px">🇩🇯</div>
<h1>ÉLECTIONS PRÉSIDENTIELLES 2026</h1>
<p>Rapport de suivi — Retrait des cartes électorales</p>
<p style="color:#6b7280;font-size:10px">Données au <strong>$date</strong> &nbsp;|&nbsp; République de Djibouti</p></div>
<div class="info-row">
<div class="info-box"><div class="info-val">${ElectionData.totalBureaux}</div><div class="info-lbl">Bureaux de vote</div></div>
<div class="info-box g"><div class="info-val">${ElectionData.totalCentres}</div><div class="info-lbl">Centres de vote</div></div>
</div>
<div class="kpis">
<div class="kpi b"><div class="kpi-l">Inscrits</div><div class="kpi-v">${_fmt(ElectionData.totalInscrits)}</div></div>
<div class="kpi g"><div class="kpi-l">Retirées</div><div class="kpi-v">${_fmt(_totalRetires)}</div></div>
<div class="kpi o"><div class="kpi-l">Restant</div><div class="kpi-v">${_fmt(_totalRestant)}</div></div>
<div class="kpi p"><div class="kpi-l">Taux</div><div class="kpi-v">${pct.toStringAsFixed(2)}%</div></div>
</div>
<h2>1. Synthèse par arrondissement</h2>
<table><thead><tr><th style="width:36px;text-align:center">Rang</th><th>Arrondissement</th>
<th style="text-align:right">Inscrits</th><th style="text-align:right">Retirés</th>
<th style="text-align:right">Restant</th><th style="text-align:right">Taux</th></tr></thead>
<tbody>${synth.toString()}</tbody></table>
<h2>2. Détail par centre de vote</h2>
<table><thead><tr><th style="width:36px;text-align:center">#</th><th>Centre</th>
<th style="text-align:right">Inscrits</th><th style="text-align:right">Retirés</th>
<th style="text-align:right">Restant</th><th style="text-align:right">Taux</th>
<th style="width:60px;text-align:center">Statut</th></tr></thead>
<tbody>${centres.toString()}</tbody></table>
<div class="footer">Élections 2026 — Djibouti | $date | ${ElectionData.totalBureaux} bureaux · ${ElectionData.totalCentres} centres · 6 arrondissements</div>
</body></html>''';
  }

  // ── Generate & view ────────────────────────
  String? _savedPath;
  bool _generating = false;

  Future<void> _generate() async {
    setState(() { _generating = true; _savedPath = null; });
    final html = _buildHtml();
    try {
      final dir  = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/rapport_${_latestDate().replaceAll('/','_')}.html');
      await file.writeAsString(html);
      setState(() { _savedPath = file.path; _generating = false; });
    } catch (e) {
      setState(() => _generating = false);
    }
  }

  void _viewRapport() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _RapportPage(
        date: _latestDate(),
        totalInscrits: ElectionData.totalInscrits,
        totalRetires: _totalRetires,
        totalRestant: _totalRestant,
        pct: _pct,
        newByCode: _newByCode,
        fmt: _fmt,
        pctColor: _pctColor,
        status: _status,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final pct = _pct * 100;
    final date = _latestDate();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(color: const Color(0xFF1565C0), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [
            const Icon(Icons.description, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(child: Text('Rapport imprimable', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
            Text(date, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _IBox(_fmt(ElectionData.totalInscrits), 'Inscrits'),
            const SizedBox(width: 6),
            _IBox(_fmt(_totalRetires), 'Retirés'),
            const SizedBox(width: 6),
            _IBox('${pct.toStringAsFixed(2)}%', 'Taux'),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _IBox('${ElectionData.totalBureaux}', 'Bureaux'),
            const SizedBox(width: 6),
            _IBox('${ElectionData.totalCentres}', 'Centres'),
            const SizedBox(width: 6),
            _IBox(_fmt(_totalRestant), 'Restant'),
          ]),
        ]))),
        const SizedBox(height: 12),
        const Text('Contenu :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        for (final f in ['📊 Synthèse par arrondissement', '🏫 39 centres avec taux et statuts', '📍 413 bureaux · 39 centres', '🟢 Statuts OK / ALERTE / CRITIQUE', '➕ Saisies locales intégrées'])
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            Text(f.substring(0,2), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(f.substring(2), style: const TextStyle(fontSize: 12)),
          ])),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _viewRapport,
          icon: const Icon(Icons.visibility),
          label: const Text('Voir le rapport'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
        )),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _generating ? null : _generate,
          icon: _generating ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.save_alt),
          label: Text(_generating ? 'Génération...' : 'Sauvegarder HTML'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
        )),
        if (_savedPath != null) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('✅ Sauvegardé', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 2),
              Text(_savedPath!, style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace')),
            ])),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 10),
        const Text('Import CSV journalier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Format CSV :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: const Text('code_centre,nom_centre,date,retraits,arrondissement\n1,PREFECTURE,24/03/2026,20,Arr. du Plateau', style: TextStyle(fontFamily: 'monospace', fontSize: 9))),
            const SizedBox(height: 4),
            const Text('⚡ Format espace aussi accepté', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ])),
        const SizedBox(height: 8),
        _CsvWidget(onDone: _load),
      ]),
    );
  }
}

class _IBox extends StatelessWidget {
  final String v, l;
  const _IBox(this.v, this.l);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(7)),
    child: Column(children: [
      Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      Text(l, style: const TextStyle(color: Colors.white60, fontSize: 9)),
    ])));
}

// ── Pure Flutter Rapport Page ─────────────────
class _RapportPage extends StatelessWidget {
  final String date;
  final int totalInscrits, totalRetires, totalRestant;
  final double pct;
  final Map<int,int> newByCode;
  final String Function(int) fmt;
  final Color Function(double) pctColor;
  final String Function(double) status;
  const _RapportPage({required this.date, required this.totalInscrits, required this.totalRetires, required this.totalRestant, required this.pct, required this.newByCode, required this.fmt, required this.pctColor, required this.status});

  Future<void> _printRapport(BuildContext context) async {
    final pdf = pw.Document();
    final arrSorted = [...ElectionData.syntheseArr]..sort((a,b)=>b.pctRetrait.compareTo(a.pctRetrait));
    final arrOrder  = ElectionData.syntheseArr.map((a)=>a.arrondissement).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) {
        final rows = <pw.Widget>[];

        // Title
        rows.add(pw.Center(child: pw.Column(children: [
          pw.Text('ÉLECTIONS PRÉSIDENTIELLES 2026', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 4),
          pw.Text('Retrait des cartes électorales — Données au $date', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text('${ElectionData.totalBureaux} bureaux · ${ElectionData.totalCentres} centres · 6 arrondissements · 3 communes',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ])));
        rows.add(pw.Divider(color: PdfColors.blue800, thickness: 2));
        rows.add(pw.SizedBox(height: 8));

        // KPIs
        rows.add(pw.Row(children: [
          _pdfKpi(fmt(totalInscrits), 'Total inscrits', PdfColors.blue700),
          pw.SizedBox(width: 8),
          _pdfKpi(fmt(totalRetires), 'Cartes retirées', PdfColors.green700),
          pw.SizedBox(width: 8),
          _pdfKpi(fmt(totalRestant), 'Restant', PdfColors.orange700),
          pw.SizedBox(width: 8),
          _pdfKpi('${(pct*100).toStringAsFixed(2)}%', 'Taux national', PdfColors.purple700),
        ]));
        rows.add(pw.SizedBox(height: 12));

        // Synthese header
        rows.add(pw.Text('1. SYNTHÈSE PAR ARRONDISSEMENT',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)));
        rows.add(pw.SizedBox(height: 4));

        // Synthese table
        rows.add(pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.blue800), children: [
              _th('Rang'), _th('Arrondissement'), _th('Inscrits'), _th('Retirés'), _th('Restant'), _th('Taux'),
            ]),
            ...arrSorted.asMap().entries.map((e) {
              final i=e.key+1; final a=e.value; final p=a.pctRetrait*100;
              final c = p>=30?PdfColors.green700:p>=8.5?PdfColors.orange700:PdfColors.red700;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.grey50 : PdfColors.white),
                children: [
                  _td('$i', center: true, bold: true, color: PdfColors.blue800),
                  _td(a.arrondissement),
                  _td(fmt(a.inscrits), right: true),
                  _td(fmt(a.retires), right: true, color: c, bold: true),
                  _td(fmt(a.restant), right: true, color: PdfColors.grey600),
                  _td('${p.toStringAsFixed(2)}%', right: true, color: c, bold: true),
                ],
              );
            }),
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.blue50), children: [
              _td('', center: true),
              _td('TOTAL NATIONAL', bold: true, color: PdfColors.blue800),
              _td(fmt(totalInscrits), right: true, bold: true),
              _td(fmt(totalRetires), right: true, bold: true, color: PdfColors.green700),
              _td(fmt(totalRestant), right: true, bold: true),
              _td('${(pct*100).toStringAsFixed(2)}%', right: true, bold: true, color: PdfColors.blue700),
            ]),
          ],
        ));
        rows.add(pw.SizedBox(height: 14));

        // Centres header
        rows.add(pw.Text('2. DÉTAIL PAR CENTRE DE VOTE',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)));
        rows.add(pw.SizedBox(height: 4));

        // Centres table
        final centreHeader = pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.blue800), children: [
          _th('#'), _th('Centre de vote'), _th('Commune'), _th('Inscrits'), _th('Retirés'), _th('Restant'), _th('Taux'), _th('Statut'),
        ]);

        final centreRows2 = <pw.TableRow>[centreHeader];
        for (final arrName in arrOrder) {
          final cs = ElectionData.centresSuivi.where((c)=>c.arrondissement==arrName).toList()
            ..sort((a,b)=>a.codeCentre.compareTo(b.codeCentre));
          if (cs.isEmpty) continue;
          final arrTotI = cs.fold(0,(s,c)=>s+c.inscrits);
          final arrTotR = cs.fold(0,(s,c)=>s+c.cumulRetraits+(newByCode[c.codeCentre]??0));
          final arrPct  = arrTotI>0?arrTotR/arrTotI*100:0.0;
          // Arr header row
          centreRows2.add(pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.blue50), children: [
            pw.TableCell(columnSpan: 8, child: pw.Padding(padding: const pw.EdgeInsets.all(4),
              child: pw.Text('$arrName   |   ${fmt(arrTotI)} inscrits · ${fmt(arrTotR)} retirés · ${arrPct.toStringAsFixed(1)}%',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)))),
          ]));
          for (int i=0; i<cs.length; i++) {
            final c=cs[i];
            final tot = c.cumulRetraits+(newByCode[c.codeCentre]??0);
            final rest= c.inscrits-tot;
            final p   = c.inscrits>0?tot/c.inscrits*100:0.0;
            final col = p>=30?PdfColors.green700:p>=8.5?PdfColors.orange700:PdfColors.red700;
            final st  = p>=30?'OK':p>=8.5?'ALERTE':'CRITIQUE';
            centreRows2.add(pw.TableRow(
              decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.grey50 : PdfColors.white),
              children: [
                _td('${c.codeCentre}', center: true, bold: true, color: PdfColors.blue700),
                _td(c.nomCentre, small: true),
                _td(c.commune, small: true, color: PdfColors.grey600),
                _td(fmt(c.inscrits), right: true),
                _td(fmt(tot), right: true, color: col, bold: true),
                _td(fmt(rest), right: true, color: PdfColors.grey600),
                _td('${p.toStringAsFixed(1)}%', right: true, color: col, bold: true),
                _td(st, center: true, color: col, bold: true, small: true),
              ],
            ));
          }
        }
        rows.add(pw.Table(border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5), children: centreRows2));
        rows.add(pw.SizedBox(height: 10));
        rows.add(pw.Center(child: pw.Text('Élections Présidentielles 2026 — République de Djibouti | Rapport du $date',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500))));
        return rows;
      },
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  static pw.Widget _pdfKpi(String v, String l, PdfColor c) => pw.Expanded(child: pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: c, width: 3)),
      color: PdfColors.white, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Text(v, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: c)),
      pw.Text(l, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
    ])));

  static pw.Widget _th(String t) => pw.Padding(padding: const pw.EdgeInsets.all(4),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white)));

  static pw.Widget _td(String t, {bool right=false, bool center=false, bool bold=false, bool small=false, PdfColor? color}) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(t, textAlign: right ? pw.TextAlign.right : center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: small ? 7 : 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rapport $date', style: const TextStyle(fontSize: 14)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimer / PDF',
            onPressed: () => _printRapport(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Cover
          Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              const Text('🇩🇯', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              const Text('ÉLECTIONS PRÉSIDENTIELLES 2026', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const Text('Retrait des cartes électorales', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 4),
              Text('Données au $date', style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ])),
          const SizedBox(height: 10),
          // Info boxes
          Row(children: [
            _InfoCard('${ElectionData.totalBureaux}', 'Bureaux', Colors.blue),
            const SizedBox(width: 8),
            _InfoCard('${ElectionData.totalCentres}', 'Centres', Colors.green),
          ]),
          const SizedBox(height: 8),
          // KPIs
          Row(children: [
            _KpiMini(fmt(totalInscrits), 'Inscrits', Colors.blue),
            const SizedBox(width: 6),
            _KpiMini(fmt(totalRetires), 'Retirées', Colors.green),
            const SizedBox(width: 6),
            _KpiMini(fmt(totalRestant), 'Restant', Colors.orange),
            const SizedBox(width: 6),
            _KpiMini('${(pct*100).toStringAsFixed(2)}%', 'Taux', Colors.purple),
          ]),
          const SizedBox(height: 14),
          // Synthese
          const _SectionHeader('1. Synthèse par arrondissement'),
          const SizedBox(height: 6),
          ...() {
            final sorted = [...ElectionData.syntheseArr]..sort((a,b) => b.pctRetrait.compareTo(a.pctRetrait));
            return sorted.asMap().entries.map((e) {
              final i = e.key + 1; final a = e.value; final p = a.pctRetrait * 100;
              final col = pctColor(p);
              return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 12, backgroundColor: col, child: Text('$i', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.arrondissement, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    Text('${p.toStringAsFixed(2)}%', style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: (p/100).clamp(0,1), backgroundColor: Colors.grey[200], color: col, minHeight: 5),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${fmt(a.inscrits)} inscrits', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    Text('${fmt(a.retires)} retirés', style: TextStyle(fontSize: 9, color: col, fontWeight: FontWeight.w600)),
                    Text('${fmt(a.restant)} restant', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ]),
                ]));
            }).toList();
          }(),
          const SizedBox(height: 14),
          // Centres
          const _SectionHeader('2. Détail par centre de vote'),
          const SizedBox(height: 6),
          ...() {
            final widgets = <Widget>[];
            final arrOrder = ElectionData.syntheseArr.map((a) => a.arrondissement).toList();
            for (final arrName in arrOrder) {
              final cs = ElectionData.centresSuivi.where((c) => c.arrondissement == arrName).toList()
                ..sort((a,b) => a.codeCentre.compareTo(b.codeCentre));
              if (cs.isEmpty) continue;
              widgets.add(Container(margin: const EdgeInsets.only(bottom: 4, top: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFFeff6ff), borderRadius: BorderRadius.circular(6)),
                child: Text('🏙️ $arrName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1d4ed8)))));
              for (final c in cs) {
                final tot = c.cumulRetraits + (newByCode[c.codeCentre]??0);
                final p   = c.inscrits > 0 ? tot/c.inscrits*100 : 0.0;
                final col = pctColor(p);
                final st  = status(p);
                final stColor = p>=30 ? Colors.green : p>=8.5 ? Colors.orange : Colors.red;
                widgets.add(Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade100), borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    CircleAvatar(radius: 14, backgroundColor: col.withOpacity(0.15), child: Text('${c.codeCentre}', style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.nomCentre, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      LinearProgressIndicator(value: (p/100).clamp(0,1), backgroundColor: Colors.grey[200], color: col, minHeight: 4),
                      const SizedBox(height: 2),
                      Text('${fmt(c.inscrits)} inscrits · ${fmt(tot)} retirés · ${fmt(c.inscrits-tot)} restant', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ])),
                    const SizedBox(width: 6),
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${p.toStringAsFixed(1)}%', style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: stColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(st, style: TextStyle(color: stColor, fontSize: 8, fontWeight: FontWeight.bold))),
                    ]),
                  ])));
              }
            }
            return widgets;
          }(),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
            child: Text('Élections 2026 — Djibouti | $date | ${ElectionData.totalBureaux} bureaux · ${ElectionData.totalCentres} centres · 6 arrondissements · 3 communes',
              style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center)),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(bottom: 5),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1565C0), width: 2))),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1565C0), letterSpacing: 0.3)));
}

class _InfoCard extends StatelessWidget {
  final String v, l; final Color c;
  const _InfoCard(this.v, this.l, this.c);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(0.08), border: Border.all(color: c.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)),
      Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ])));
}

class _KpiMini extends StatelessWidget {
  final String v, l; final Color c;
  const _KpiMini(this.v, this.l, this.c);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border(top: BorderSide(color: c, width: 3)), color: Colors.white, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
    child: Column(children: [
      Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
      Text(l, style: const TextStyle(fontSize: 9, color: Colors.grey)),
    ])));
}

class _CsvWidget extends StatefulWidget {
  final VoidCallback onDone;
  const _CsvWidget({required this.onDone});
  @override State<_CsvWidget> createState() => _CsvWidgetState();
}
class _CsvWidgetState extends State<_CsvWidget> {
  final _c = TextEditingController();
  String _msg = ''; bool _loading = false;
  Future<void> _import() async {
    if (_c.text.trim().isEmpty) return;
    setState(() { _loading = true; _msg = ''; });
    final n = await DbHelper.importCsv(_c.text);
    setState(() { _loading = false; _msg = '$n lignes importées ✓'; _c.clear(); });
    widget.onDone();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n retraits importés ✓'), backgroundColor: Colors.green));
  }
  @override Widget build(BuildContext context) => Column(children: [
    TextField(controller: _c, maxLines: 7, decoration: const InputDecoration(labelText: 'Coller le CSV ici', border: OutlineInputBorder(), alignLabelWithHint: true, isDense: true)),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: _loading ? null : _import,
      icon: _loading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.upload),
      label: const Text('Importer et mettre à jour'),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
    )),
    if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top:6), child: Text(_msg, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
  ]);
}
