class ApiLogEntry {
  final DateTime time;
  final String api; // 'replit', 'twelvedata', 'alphavantage', 'claude'
  final String method; // 'GET', 'POST'
  final String url;
  final int? statusCode;
  final int durationMs;
  final bool success;
  final String? error;

  ApiLogEntry({
    required this.time,
    required this.api,
    required this.method,
    required this.url,
    required this.statusCode,
    required this.durationMs,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'api': api,
    'method': method,
    'url': url,
    'statusCode': statusCode,
    'durationMs': durationMs,
    'success': success,
    'error': error,
  };

  factory ApiLogEntry.fromJson(Map<String, dynamic> j) => ApiLogEntry(
    time: DateTime.tryParse(j['time'] ?? '') ?? DateTime.now(),
    api: j['api'] ?? 'unknown',
    method: j['method'] ?? 'GET',
    url: j['url'] ?? '',
    statusCode: j['statusCode'] as int?,
    durationMs: j['durationMs'] ?? 0,
    success: j['success'] ?? false,
    error: j['error'] as String?,
  );
}
