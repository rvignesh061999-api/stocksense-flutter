import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_log_entry.dart';

/// Tracks every API call made by the app (Replit server, Twelve Data,
/// Alpha Vantage, Claude AI) so the Admin/Kibana Monitor screen can show
/// a live request log, success/error counts, and response-time chart —
/// matching the web app's "KIBANA API MONITOR" page.
class ApiMonitorService {
  static final ApiMonitorService _i = ApiMonitorService._();
  factory ApiMonitorService() => _i;
  ApiMonitorService._();

  static const _key = 'api_monitor_log_v1';
  static const _maxEntries = 300; // matches "last 30 calls" chart + headroom

  final List<ApiLogEntry> _entries = [];
  List<ApiLogEntry> get entries => List.unmodifiable(_entries.reversed);

  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => ApiLogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _entries.addAll(list);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_entries.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> log(ApiLogEntry entry) async {
    await _ensureLoaded();
    _entries.add(entry);
    if (_entries.length > _maxEntries) _entries.removeAt(0);
    await _persist();
  }

  Future<void> clear() async {
    _entries.clear();
    await _persist();
  }

  Future<void> refresh() async {
    _loaded = false;
    _entries.clear();
    await _ensureLoaded();
  }

  // --- Stats for the live stats bar ---
  int get totalCalls => _entries.length;
  int get successCount => _entries.where((e) => e.success).length;
  int get errorCount => _entries.where((e) => !e.success).length;
  double get avgMs => _entries.isEmpty
      ? 0
      : _entries.map((e) => e.durationMs).reduce((a, b) => a + b) / _entries.length;

  // --- Last 30 calls for the response-time chart ---
  List<ApiLogEntry> get last30 =>
      _entries.length <= 30 ? _entries : _entries.sublist(_entries.length - 30);
}
