import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/timer_log_entry.dart';

/// Persists a history entry every time a timer scan completes — matches
/// the web app's "TIMER SCAN LOG" (Timer Journal) page.
///
/// 2026-07-11: switched from SharedPreferences to plain file I/O.
/// SharedPreferences writes made from the background isolate (spawned by
/// flutter_foreground_task) were confirmed NOT visible to reads from the
/// main isolate — proven simultaneously across this service, the Admin/
/// Kibana API monitor, and the live scan progress marker, all showing zero
/// data despite notifications proving the underlying scans genuinely
/// completed. File I/O is OS-level and isn't tied to any plugin's
/// per-isolate channel/cache state, so it doesn't have this problem.
class TimerLogService {
  static final TimerLogService _i = TimerLogService._();
  factory TimerLogService() => _i;
  TimerLogService._();

  static const _maxEntries = 200;
  static const _fileName = 'timer_log_v1.json';
  static const _debugFileName = 'timer_log_debug_v1.txt';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<File> _debugFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_debugFileName');
  }

  Future<List<TimerLogEntry>> loadAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => TimerLogEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addEntry(TimerLogEntry entry) async {
    try {
      final entries = await loadAll();
      entries.add(entry);
      if (entries.length > _maxEntries) entries.removeAt(0);
      final f = await _file();
      await f.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
      final df = await _debugFile();
      await df.writeAsString(
          'OK: wrote entry #${entries.length} at ${DateTime.now().toIso8601String()}');
    } catch (e) {
      // 2026-07-08: previously silent — now visible via the debug line so
      // we can tell "never attempted" apart from "attempted but failed."
      try {
        final df = await _debugFile();
        await df.writeAsString('WRITE FAILED at ${DateTime.now().toIso8601String()}: $e');
      } catch (_) {}
    }
  }

  Future<String> debugStatus() async {
    try {
      final df = await _debugFile();
      if (!await df.exists()) return 'no write attempted yet';
      return await df.readAsString();
    } catch (e) {
      return 'debugStatus read failed: $e';
    }
  }

  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
