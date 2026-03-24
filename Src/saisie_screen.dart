
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'election_data.dart';
import 'db_helper.dart';

class SaisieScreen extends StatefulWidget {
  const SaisieScreen({super.key});
  @override
  State<SaisieScreen> createState() => _SaisieScreenState();
}

class _SaisieScreenState extends State<SaisieScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(controller: _tc, labelColor: const Color(0xFF1565C0), unselectedLabelColor: Colors.grey, indicatorColor: const Color(0xFF1565C0),
        tabs: const [
          Tab(icon: Icon(Icons.edit_note), text: 'Saisie'),
          Tab(icon: Icon(Icons.upload_file), text: 'Import CSV'),
          Tab(icon: Icon(Icons.download), text: 'Export CSV'),
        ]),
      Expanded(child: TabBarView(controller: _tc, children: const [_FormulaireTab(), _ImportTab(), _ExportTab()])),
    ]);
  }
}

// ── Formulaire ──────────────────────────────
class _FormulaireTab extends StatefulWidget {
  const _FormulaireTab();
  @override State<_FormulaireTab> createState() => _FormulaireTabState();
}

class _FormulaireTabState extends State<_FormulaireTab> {
  CentreSuivi? _centre;
  final _dateCtrl = TextEditingController();
  final _cntCtrl = TextEditingController();
  List<SaisieEntry> _history = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _loadHistory(); }

  Future<void> _loadHistory() async {
    final all = await DbHelper.all();
    if (mounted) setState(() => _history = all.take(50).toList());
  }

  Future<void> _save() async {
    if (_centre == null || _dateCtrl.text.isEmpty || _cntCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remplir tous les champs')));
      return;
    }
    final n = int.tryParse(_cntCtrl.text);
    if (n == null || n < 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre invalide'))); return; }
    setState(() => _loading = true);
    await DbHelper.upsert(SaisieEntry(codeCentre: _centre!.codeCentre, nomCentre: _centre!.nomCentre, arrondissement: _centre!.arrondissement, date: _dateCtrl.text, retraits: n));
    _cntCtrl.clear();
    await _loadHistory();
    setState(() => _loading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistré ✓'), backgroundColor: Colors.green));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(2026, 3, 1), lastDate: DateTime(2026, 4, 30));
    if (d != null) setState(() => _dateCtrl.text = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          const Text('Saisir les retraits journaliers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          DropdownButtonFormField<CentreSuivi>(
            decoration: const InputDecoration(labelText: 'Centre de vote', border: OutlineInputBorder(), isDense: true),
            value: _centre, isExpanded: true,
            items: ElectionData.centresSuivi.map((c) => DropdownMenuItem(value: c, child: Text('${c.codeCentre}. ${c.nomCentre}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _centre = v),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _dateCtrl, decoration: const InputDecoration(labelText: 'Date (jj/mm/aaaa)', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 18)), readOnly: true, onTap: _pickDate)),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _cntCtrl, decoration: const InputDecoration(labelText: 'Nb retraits', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _loading ? null : _save,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
            label: const Text('Enregistrer'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
          )),
        ]))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_history.length} saisies enregistrées', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          TextButton.icon(onPressed: _loadHistory, icon: const Icon(Icons.refresh, size: 16), label: const Text('Actualiser', style: TextStyle(fontSize: 12))),
        ]),
        if (_history.isEmpty) const Text('Aucune saisie enregistrée', style: TextStyle(color: Colors.grey, fontSize: 12))
        else ..._history.map((e) => Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(dense: true,
            leading: CircleAvatar(radius: 16, backgroundColor: Colors.blue[50], child: Text('${e.codeCentre}', style: TextStyle(color: Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold))),
            title: Text(e.nomCentre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            subtitle: Text('${e.date} • ${e.arrondissement}', style: const TextStyle(fontSize: 10)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${e.retraits}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
              const SizedBox(width: 8),
              GestureDetector(onTap: () async { if (e.id != null) { await DbHelper.delete(e.id!); _loadHistory(); } }, child: const Icon(Icons.delete_outline, size: 18, color: Colors.red)),
            ]),
          ),
        )),
      ]),
    );
  }
}

// ── Import CSV ───────────────────────────────
class _ImportTab extends StatefulWidget {
  const _ImportTab();
  @override State<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<_ImportTab> {
  final _ctrl = TextEditingController();
  String _msg = ''; bool _loading = false;

  Future<void> _import() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _msg = ''; });
    final n = await DbHelper.importCsv(_ctrl.text);
    setState(() { _loading = false; _msg = '$n lignes importées avec succès ✓'; _ctrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(color: Colors.blue[50], child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Format CSV attendu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
            child: const Text('code_centre,nom_centre,date,retraits,arrondissement\n1,PREFECTURE,19/03/2026,42,Arr. du Plateau\n2,ECOLE Z.P.S,19/03/2026,180,Arr. du Plateau', style: TextStyle(fontFamily: 'monospace', fontSize: 10))),
        ]))),
        const SizedBox(height: 10),
        TextField(controller: _ctrl, maxLines: 10, decoration: const InputDecoration(labelText: 'Coller les données CSV ici', border: OutlineInputBorder(), alignLabelWithHint: true)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _loading ? null : _import,
          icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload),
          label: const Text('Importer'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
        )),
        if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
      ]),
    );
  }
}

// ── Export CSV ───────────────────────────────
class _ExportTab extends StatefulWidget {
  const _ExportTab();
  @override State<_ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<_ExportTab> {
  List<SaisieEntry> _entries = [];
  bool _loading = false;
  String _status = '';
  String? _savedPath;
  bool _loaded = false;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() { _loading = true; _status = ''; });
    final data = await DbHelper.all();
    if (mounted) setState(() { _entries = data; _loading = false; _loaded = true; });
  }

  String _buildCsv() {
    final buf = StringBuffer();
    buf.writeln('code_centre,nom_centre,date,retraits,arrondissement');
    for (final e in _entries) {
      final nom = e.nomCentre.replaceAll(',', ' ');
      final arr = e.arrondissement.replaceAll(',', ' ');
      buf.writeln('${e.codeCentre},$nom,${e.date},${e.retraits},$arr');
    }
    return buf.toString();
  }

  Future<void> _export() async {
    if (_entries.isEmpty) {
      setState(() => _status = 'Aucune donnée à exporter.');
      return;
    }
    setState(() { _loading = true; _status = ''; _savedPath = null; });
    try {
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fname = 'elections2026_export_${now.day.toString().padLeft(2,'0')}${now.month.toString().padLeft(2,'0')}${now.year}_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}.csv';
      final file = File('${dir.path}/$fname');
      await file.writeAsString(_buildCsv());
      setState(() { _savedPath = file.path; _status = 'Fichier sauvegardé ✓'; });
    } catch (ex) {
      setState(() => _status = 'Erreur: $ex');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyToClipboard() async {
    if (_entries.isEmpty) return;
    // Show CSV text in dialog for easy copy
    final csv = _buildCsv();
    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Données CSV', style: TextStyle(fontSize: 16)),
      content: SizedBox(height: 300, child: SingleChildScrollView(child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    // Group by date for preview
    final Map<String, int> byDate = {};
    for (final e in _entries) {
      byDate[e.date] = (byDate[e.date] ?? 0) + e.retraits;
    }
    final sortedDates = byDate.keys.toList()..sort();
    final totalNew = _entries.fold(0, (s, e) => s + e.retraits);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Summary card
        Card(color: const Color(0xFF1565C0), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          const Icon(Icons.storage, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_entries.length} saisies locales', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('$totalNew retraits au total', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${sortedDates.length} jours distincts', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, color: Colors.white)),
        ]))),
        const SizedBox(height: 12),

        // Dates summary
        if (sortedDates.isNotEmpty) ...[
          const Text('Résumé par date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          ...sortedDates.map((d) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)), child: Text('${byDate[d]} retraits', style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.bold))),
          ]))),
          const SizedBox(height: 12),
        ],

        if (_entries.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Aucune saisie à exporter.\nUtilisez l\'onglet Saisie pour enregistrer des données.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))))
        else ...[
          // Export to file
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _loading ? null : _export,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt),
            label: const Text('Sauvegarder fichier CSV'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
          )),
          const SizedBox(height: 8),
          // View/copy CSV
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('Voir / Sélectionner CSV'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
          )),
        ],

        if (_status.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
            color: _status.contains('Erreur') ? Colors.red[50] : Colors.green[50],
            border: Border.all(color: _status.contains('Erreur') ? Colors.red : Colors.green),
            borderRadius: BorderRadius.circular(8),
          ), child: Row(children: [
            Icon(_status.contains('Erreur') ? Icons.error_outline : Icons.check_circle_outline, color: _status.contains('Erreur') ? Colors.red : Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(_status, style: TextStyle(color: _status.contains('Erreur') ? Colors.red : Colors.green, fontSize: 12))),
          ])),
        ],

        if (_savedPath != null) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Chemin du fichier:', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            SelectableText(_savedPath!, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87)),
          ])),
        ],

        const SizedBox(height: 16),
        Card(color: Colors.amber[50], child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Exportez vos données avant toute mise à jour ou réinstallation de l\'application pour ne pas perdre vos saisies.', style: TextStyle(fontSize: 11, color: Colors.brown))),
        ]))),
      ]),
    );
  }
}
