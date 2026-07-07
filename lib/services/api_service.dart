import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/signal.dart';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  // Fix #8 — expose last error to UI
  // 2026-07-07: confirmed present — if your build says this getter is
  // missing, your live repo has an older version of this file than this one.
  String? lastError;

  Future<Map<String, dynamic>> getStatus() async {
    try {
      lastError = null;
      final url = '$SERVER_URL/status'; // Fix #1 — no backslash escaping
      final r = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        return {...json.decode(r.body), 'online': true};
      }
      lastError = 'Server returned ${r.statusCode}';
      return {'online': false, 'error': lastError};
    } catch (e) {
      lastError = e.toString(); // Fix #17 — log error
      return {'online': false, 'error': lastError};
    }
  }

  Future<StockSignal?> scanStock(String symbol, {double capital = 10000.0}) async {
    try {
      lastError = null;
      final url = '$SERVER_URL/scan?symbol=$symbol&capital=$capital'; // Fix #1
      final r = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        return StockSignal.fromJson(json.decode(r.body));
      }
      lastError = 'Server returned ${r.statusCode} for $symbol';
      return null;
    } catch (e) {
      lastError = e.toString(); // Fix #17
      return null;
    }
  }
}
