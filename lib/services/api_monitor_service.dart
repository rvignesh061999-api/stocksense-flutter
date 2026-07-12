import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/api_log_entry.dart';

/// Tracks every API call made by the app (Replit server, Twelve Data,
/// Alpha Vantage, Claude AI) so the Admin/Kibana Monitor screen can show
/// a live request log, success/error counts, and response-time chart —
/// matching the web app's "KIBANA API MONITOR" page.
///
/// 2026-07-11: switched from SharedPreferences (with an in-memory cache)
/// to plain file I/O with NO in-memory cache. This service is called from
/// both the background isolate (during automated scans) and the main
/// isolate (the "Test All" button) — an in-memory list is per-isolate and
/// would silently miss writes from the other isolate. Always reading
/// fresh from file avoids that entirely.
class ApiMonitorService {
  static final ApiMonitorService _i = ApiMonitorService._();
  factory ApiMonitorService() => _i;
  ApiMonitorService._();

  static const _maxEntries = 300; // matches "last 30 calls" chart + headroom
  static const _fileName = 'api_monitor_log_v1.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<ApiLogEntry>> loadAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final list = (jsonDecode(raw) as List)
          .map((e) => ApiLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      return list.reversed.toList(); // newest first
    } catch (_) {
      return [];
    }
  }

  Future<void> log(ApiLogEntry entry) async {
    try {
      // loadAll() returns newest-first; re-reverse to append correctly.
      final entries = (await loadAll()).reversed.toList();
      entries.add(entry);
      if (entries.length > _maxEntries) entries.removeAt(0);
      final f = await _file();
      await f.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
