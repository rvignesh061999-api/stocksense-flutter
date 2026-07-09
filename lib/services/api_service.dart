import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/signal.dart';
import '../models/api_log_entry.dart';
import 'api_monitor_service.dart';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  // Fix #8 — expose last error to UI
  String? lastError;

  Future<Map<String, dynamic>> getStatus() async {
    final sw = Stopwatch()..start();
    final url = '$SERVER_URL/status'; // Fix #1 — no backslash escaping
    try {
      lastError = null;
      final r = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      sw.stop();
      final ok = r.statusCode == 200;
      await ApiMonitorService().log(ApiLogEntry(
        time: DateTime.now(), api: 'replit', method: 'GET', url: url,
        statusCode: r.statusCode, durationMs: sw.elapsedMilliseconds, success: ok,
        error: ok ? null : 'Server returned ${r.statusCode}',
      ));
      if (ok) return {...json.decode(r.body), 'online': true};
      lastError = 'Server returned ${r.statusCode}';
      return {'online': false, 'error': lastError};
    } catch (e) {
      sw.stop();
      lastError = e.toString(); // Fix #17 — log error
      await ApiMonitorService().log(ApiLogEntry(
        time: DateTime.now(), api: 'replit', method: 'GET', url: url,
        statusCode: null, durationMs: sw.elapsedMilliseconds, success: false,
        error: lastError,
      ));
      return {'online': false, 'error': lastError};
    }
  }

  Future<StockSignal?> scanStock(String symbol, {double capital = 10000.0}) async {
    final sw = Stopwatch()..start();
    final url = '$SERVER_URL/scan?symbol=$symbol&capital=$capital'; // Fix #1
    try {
      lastError = null;
      final r = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      sw.stop();
      final ok = r.statusCode == 200;
      await ApiMonitorService().log(ApiLogEntry(
        time: DateTime.now(), api: 'replit', method: 'GET', url: url,
        statusCode: r.statusCode, durationMs: sw.elapsedMilliseconds, success: ok,
        error: ok ? null : 'Server returned ${r.statusCode} for $symbol',
      ));
      if (ok) return StockSignal.fromJson(json.decode(r.body));
      lastError = 'Server returned ${r.statusCode} for $symbol';
      return null;
    } catch (e) {
      sw.stop();
      lastError = e.toString(); // Fix #17
      await ApiMonitorService().log(ApiLogEntry(
        time: DateTime.now(), api: 'replit', method: 'GET', url: url,
        statusCode: null, durationMs: sw.elapsedMilliseconds, success: false,
        error: lastError,
      ));
      return null;
    }
  }
}
