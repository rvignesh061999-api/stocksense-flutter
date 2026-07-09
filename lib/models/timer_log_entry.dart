class TimerLogEntry {
  final DateTime time;
  final int scanNum;
  final int scanned;
  final int total;
  final int buys;
  final int shorts;
  final int failures;
  final String? lastError;
  final List<String> topBuys;
  final List<String> topShorts;

  TimerLogEntry({
    required this.time,
    required this.scanNum,
    required this.scanned,
    required this.total,
    required this.buys,
    required this.shorts,
    required this.failures,
    this.lastError,
    this.topBuys = const [],
    this.topShorts = const [],
  });

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'scanNum': scanNum,
    'scanned': scanned,
    'total': total,
    'buys': buys,
    'shorts': shorts,
    'failures': failures,
    'lastError': lastError,
    'topBuys': topBuys,
    'topShorts': topShorts,
  };

  factory TimerLogEntry.fromJson(Map<String, dynamic> j) => TimerLogEntry(
    time: DateTime.tryParse(j['time'] ?? '') ?? DateTime.now(),
    scanNum: j['scanNum'] ?? 0,
    scanned: j['scanned'] ?? 0,
    total: j['total'] ?? 0,
    buys: j['buys'] ?? 0,
    shorts: j['shorts'] ?? 0,
    failures: j['failures'] ?? 0,
    lastError: j['lastError'] as String?,
    topBuys: (j['topBuys'] as List?)?.map((e) => e.toString()).toList() ?? [],
    topShorts: (j['topShorts'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );
}
