import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timer_log_entry.dart';

/// Persists a history entry every time a timer scan completes — matches
/// the web app's "TIMER SCAN LOG" (Timer Journal) page.
class TimerLogService {
  static final TimerLogService _i = TimerLogService._();
  factory TimerLogService() => _i;
  TimerLogService._();

  static const _key = 'timer_log_v1';
  static const _maxEntries = 200;

  static const _debugKey = 'timer_log_debug_v1';

  Future<List<TimerLogEntry>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(_debugKey,
          'OK: wrote entry #${entries.length} at ${DateTime.now().toIso8601String()}');
    } catch (e, st) {
      // 2026-07-08: previously silent — now visible via the debug line so
      // we can tell "never attempted" apart from "attempted but failed."
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_debugKey,
            'WRITE FAILED at ${DateTime.now().toIso8601String()}: $e');
      } catch (_) {}
    }
  }

  Future<String> debugStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_debugKey) ?? 'no write attempted yet';
    } catch (e) {
      return 'debugStatus read failed: $e';
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
