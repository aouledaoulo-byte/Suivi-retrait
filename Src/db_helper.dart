
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class SaisieEntry {
  final int? id;
  final int codeCentre;
  final String nomCentre;
  final String arrondissement;
  final String date;
  final int retraits;
  SaisieEntry({this.id, required this.codeCentre, required this.nomCentre, required this.arrondissement, required this.date, required this.retraits});
  Map<String, dynamic> toMap() => {'id': id, 'codeCentre': codeCentre, 'nomCentre': nomCentre, 'arrondissement': arrondissement, 'date': date, 'retraits': retraits};
  factory SaisieEntry.fromMap(Map<String, dynamic> m) => SaisieEntry(id: m['id'], codeCentre: m['codeCentre'], nomCentre: m['nomCentre'], arrondissement: m['arrondissement'] ?? '', date: m['date'], retraits: m['retraits']);
}

class DbHelper {
  static Database? _db;
  static Future<Database> get db async { _db ??= await _init(); return _db!; }
  static Future<Database> _init() async {
    final path = p.join(await getDatabasesPath(), 'elections2026.db');
    return openDatabase(path, version: 1, onCreate: (db, v) {
      db.execute('''CREATE TABLE saisies (id INTEGER PRIMARY KEY AUTOINCREMENT, codeCentre INTEGER, nomCentre TEXT, arrondissement TEXT, date TEXT, retraits INTEGER)''');
    });
  }
  static Future<void> upsert(SaisieEntry e) async {
    final d = await db;
    final existing = await d.query('saisies', where: 'codeCentre=? AND date=?', whereArgs: [e.codeCentre, e.date]);
    if (existing.isEmpty) { await d.insert('saisies', e.toMap()); }
    else { await d.update('saisies', e.toMap(), where: 'codeCentre=? AND date=?', whereArgs: [e.codeCentre, e.date]); }
  }
  static Future<List<SaisieEntry>> all() async { final d = await db; return (await d.query('saisies', orderBy: 'date DESC, codeCentre ASC')).map(SaisieEntry.fromMap).toList(); }
  static Future<List<SaisieEntry>> byCentre(int code) async { final d = await db; return (await d.query('saisies', where: 'codeCentre=?', whereArgs: [code], orderBy: 'date ASC')).map(SaisieEntry.fromMap).toList(); }
  static Future<List<SaisieEntry>> byArr(String arr) async { final d = await db; return (await d.query('saisies', where: 'arrondissement=?', whereArgs: [arr], orderBy: 'date ASC')).map(SaisieEntry.fromMap).toList(); }
  static Future<void> delete(int id) async { final d = await db; await d.delete('saisies', where: 'id=?', whereArgs: [id]); }

  /// Parse a single line - handles BOTH comma-separated and space-separated formats.
  /// CSV format:  code,nom,date,retraits,arrondissement
  /// Space format: code NOM NOM 19/03/2026 retraits Arrondissement...
  static SaisieEntry? _parseLine(String line) {
    line = line.trim();
    if (line.isEmpty) return null;

    // ── Try comma-separated first ──────────────────────────────────────────
    if (line.contains(',')) {
      final parts = line.split(',');
      if (parts.length >= 4) {
        try {
          final code = int.parse(parts[0].trim());
          final nom  = parts[1].trim();
          final date = parts[2].trim();
          final ret  = int.parse(parts[3].trim());
          final arr  = parts.length > 4 ? parts.sublist(4).join(',').trim() : '';
          if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(date)) {
            return SaisieEntry(codeCentre: code, nomCentre: nom, arrondissement: arr, date: date, retraits: ret);
          }
        } catch (_) {}
      }
    }

    // ── Try space-separated: "CODE NOM... DD/MM/YYYY RETRAITS ARR..." ─────
    // Date is the anchor: find DD/MM/YYYY pattern
    final dateRe = RegExp(r'(\d{2}/\d{2}/\d{4})');
    final dateMatch = dateRe.firstMatch(line);
    if (dateMatch != null) {
      try {
        final before = line.substring(0, dateMatch.start).trim();
        final after  = line.substring(dateMatch.end).trim();
        final date   = dateMatch.group(1)!;

        // before = "CODE NOM NOM..."
        final beforeParts = before.split(RegExp(r'\s+'));
        if (beforeParts.isEmpty) return null;
        final code = int.parse(beforeParts[0]);
        final nom  = beforeParts.sublist(1).join(' ').trim();

        // after = "RETRAITS ARR ARR..."
        final afterParts = after.split(RegExp(r'\s+'));
        if (afterParts.isEmpty) return null;
        final ret = int.parse(afterParts[0]);
        final arr = afterParts.sublist(1).join(' ').trim();

        return SaisieEntry(codeCentre: code, nomCentre: nom, arrondissement: arr, date: date, retraits: ret);
      } catch (_) {}
    }

    return null;
  }

  static Future<int> importCsv(String text) async {
    int count = 0;
    final lines = text.trim().split('\n');
    for (final raw in lines) {
      final line = raw.trim();
      // Skip header line
      if (line.toLowerCase().startsWith('code_centre') || line.toLowerCase().startsWith('code centre')) continue;
      final entry = _parseLine(line);
      if (entry != null) {
        await upsert(entry);
        count++;
      }
    }
    return count;
  }
}
