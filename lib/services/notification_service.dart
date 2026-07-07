import 'package:flutter/material.dart';
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
    final ap = _p.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
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

  // Fix #6 \u2014 request at runtime on Android 13+
  // 2026-07-07: confirmed present \u2014 if your build says this method is
  // missing, your live repo has an older version of this file than this one.
  Future<void> requestPermission(BuildContext context) async {
    final ap = _p.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await ap?.requestNotificationsPermission();
    if (granted == false && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('\u26A0\uFE0F Enable notifications to receive scan alerts'),
        backgroundColor: Color(COLOR_YELLOW),
        duration: Duration(seconds: 4),
      ));
    }
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
      'StockSense \u2014 Scanning...',
      '$bar $scanned/$total  |  Scan #$scanNum  \u{1F7E2}$buys  \u{1F534}$shorts',
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
    required int secondsLeft, required int scanNum,
    required List<String> topSignals,
  }) async {
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    await _p.show(
      NOTIF_REST_TIMER,
      'Next scan in ${m}m ${s.toString().padLeft(2, "0")}s',
      'Scan #$scanNum  ${topSignals.take(3).join("  ")}',
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
    final buyStr = topBuys.take(2).map((s) => '\u{1F7E2} $s').join('  ');
    final shortStr = topShorts.take(2).map((s) => '\u{1F534} $s').join('  ');
    await _p.show(
      NOTIF_SCAN_COMPLETE,
      'Scan #$scanNum \u2014 ${buys + shorts} Signals!',
      '$buyStr  $shortStr',
      NotificationDetails(android: AndroidNotificationDetails(
        'stocksense_signal', 'Trade Signals',
        importance: Importance.high, priority: Priority.high,
      )),
    );
  }

  Future<void> clearAll() async => await _p.cancelAll();
}
