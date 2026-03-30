import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final DbHelper _db = DbHelper();
  bool _loading = false;
  String _status = '';
  bool _statusOk = true;
  List<String> _dates = [];
  String? _selectedDate; // null = toutes les dates

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  Future<void> _loadDates() async {
    final dates = await _db.getDistinctDates();
    setState(() {
      _dates = dates;
      _selectedDate = dates.isNotEmpty ? dates.first : null;
    });
  }

  Future<void> _exportCsv({String? date}) async {
    setState(() { _loading = true; _status = ''; });
    try {
      final rows = await _db.getAllRetraits();
      final data = date != null
          ? rows.where((r) => r['date'] == date).toList()
          : rows;

      if (data.isEmpty) {
        setState(() {
          _status = 'Aucune donnée pour ${date ?? "toutes les dates"}';
          _statusOk = false;
        });
        return;
      }

      final sb = StringBuffer();
      sb.writeln('code_centre,nom_centre,date,retraits,arrondissement');
      for (final r in data) {
        final nom = (r['nom_centre'] as String).replaceAll(',', ' ');
        sb.writeln(
          '${r["code_centre"]},$nom,${r["date"]},${r["retraits"]},${r["arrondissement"]}',
        );
      }

      final dir = await getTemporaryDirectory();
      final label = date?.replaceAll('/', '_') ?? 'complet';
      final file = File('${dir.path}/retraits_$label.csv');
      await file.writeAsString(sb.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Retraits cartes électeurs — $label',
        text: 'Export CSV Elections 2026 Djibouti',
      );

      setState(() {
        _status =
            '✅ CSV partagé — ${data.length} lignes (${date ?? "toutes dates"})';
        _statusOk = true;
      });
    } catch (e) {
      setState(() { _status = '❌ Erreur : $e'; _statusOk = false; });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: const Column(
              children: [
                Icon(Icons.upload_file, color: Colors.white, size: 40),
                SizedBox(height: 10),
                Text(
                  'EXPORT CSV',
                  style: TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w900, letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Exporter les retraits · Partager via WhatsApp / Email / Drive',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sélection date
          const Text(
            'CHOISIR UNE DATE',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280), letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                RadioListTile<String?>(
                  value: null,
                  groupValue: _selectedDate,
                  onChanged: (v) => setState(() => _selectedDate = v),
                  title: const Text(
                    'Toutes les dates',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${_dates.length} jour(s) disponibles',
                    style: const TextStyle(fontSize: 11),
                  ),
                  activeColor: const Color(0xFF059669),
                  dense: true,
                ),
                ..._dates.expand((d) => [
                  const Divider(height: 1),
                  RadioListTile<String?>(
                    value: d,
                    groupValue: _selectedDate,
                    onChanged: (v) => setState(() => _selectedDate = v),
                    title: Text(
                      d,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Export du jour',
                      style: TextStyle(fontSize: 11),
                    ),
                    activeColor: const Color(0xFF059669),
                    dense: true,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bouton export
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _exportCsv(date: _selectedDate),
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.share, size: 20),
              label: Text(
                _loading
                    ? 'Génération...'
                    : _selectedDate != null
                        ? 'Exporter $_selectedDate'
                        : 'Exporter tout',
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor:
                    const Color(0xFF059669).withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Statut
          if (_status.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusOk
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _statusOk
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  fontSize: 12,
                  color: _statusOk
                      ? const Color(0xFF166534)
                      : const Color(0xFF991B1B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Aide
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 Comment ça marche',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF0C4A6E),
                  ),
                ),
                const SizedBox(height: 10),
                _step('1', 'Sélectionnez la date (ou toutes)'),
                _step('2', 'Appuyez sur "Exporter"'),
                _step('3', 'Choisissez WhatsApp, Email, Drive…'),
                _step('4', 'Intégrez le fichier CSV dans votre tableau de bord'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Format
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📄 Format du fichier',
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'code_centre,nom_centre,date,retraits,arrondissement\n'
                    '1,PREFECTURE,30/03/2026,32,Arrondissement du Plateau\n'
                    '2,ECOLE ZPS,30/03/2026,96,Arrondissement du Plateau\n'
                    '...',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      color: Color(0xFF86EFAC),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _step(String n, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20, height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFF0284C7),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            n,
            style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
          ),
        ),
      ],
    ),
  );
}
