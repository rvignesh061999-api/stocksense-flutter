import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _p = FlutterLocalNotificationsPlugin();
  bool _init = false;

  Future<void> init() async {
    if (_init) return;
    await _p.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    final ap = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await ap?.createNotificationChannel(const AndroidNotificationChannel(
      'stocksense_scan', 'Scan Progress',
      importance: Importance.low, playSound: false, enableVibration: false,
    ));
    await ap?.createNotificationChannel(const AndroidNotificationChannel(
      'stocksense_signal', 'Trade Signals',
      importance: Importance.high,
    ));
    _init = true;
  }

  Future<void> showScanProgress({
    required int scanned, required int total,
    required int buys, required int shorts, required int scanNum,
  }) async {
    final pct = total > 0 ? scanned / total : 0.0;
    final bar = String.fromCharCodes(List.filled((pct * 10).round(), 9608)) +
        String.fromCharCodes(List.filled(10 - (pct * 10).round(), 9617));
    await _p.show(
      NOTIF_SCAN_PROGRESS,
      'StockSense — Scanning...',
      '$bar $scanned/$total  |  Scan #$scanNum  |  BUY: $buys  SHORT: $shorts',
      NotificationDetails(android: AndroidNotificationDetails(
        'stocksense_scan', 'Scan Progress',
        importance: Importance.low, priority: Priority.low,
        ongoing: true, autoCancel: false,
        showProgress: true, maxProgress: total, progress: scanned,
        onlyAlertOnce: true,
      )),
    );
  }

  Future<void> showRestCountdown({
    required int secondsLeft, required int scanNum, required List<String> topSignals,
  }) async {
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    await _p.show(
      NOTIF_REST_TIMER,
      'Next scan in ${m}m ${s.toString().padLeft(2,"0")}s',
      '${topSignals.take(3).join("  ")}  |  Scan #$scanNum',
      NotificationDetails(android: AndroidNotificationDetails(
        'stocksense_scan', 'Scan Progress',
        importance: Importance.low, priority: Priority.low,
        ongoing: true, autoCancel: false, onlyAlertOnce: true,
      )),
    );
  }

  Future<void> showScanComplete({
    required int scanNum, required int buys, required int shorts,
    required List<String> topBuys, required List<String> topShorts,
  }) async {
    final buyStr = topBuys.take(2).map((s) => '🟢 ' + s).join('  ');
    final shortStr = topShorts.take(2).map((s) => '🔴 ' + s).join('  ');
    await _p.show(
      NOTIF_SCAN_COMPLETE,
      'Scan #$scanNum — ${buys + shorts} Signals!',
      '$buyStr  $shortStr',
      NotificationDetails(android: AndroidNotificationDetails(
        'stocksense_signal', 'Trade Signals',
        importance: Importance.high, priority: Priority.high,
      )),
    );
  }

  Future<void> clearAll() async => await _p.cancelAll();
}
