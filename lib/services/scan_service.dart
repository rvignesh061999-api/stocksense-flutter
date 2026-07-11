import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'timer_log_service.dart';
import '../constants.dart';
import '../models/signal.dart';
import '../models/timer_log_entry.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StockSenseTaskHandler());
}

// Fix #16 (corrected) — _stop/_scanN are instance fields of the TaskHandler,
// which lives entirely inside the background isolate spawned by
// flutter_foreground_task. They were previously top-level "globals," which
// looked shared with ScanService below but weren't: Dart isolates don't
// share memory, so ScanService's own assignments to a same-named global
// were actually silent no-ops on a completely separate copy. The real
// stop signal has always been FlutterForegroundTask.stopService()
// triggering onDestroy() here, inside this isolate — that part was
// already correct; only the misleading appearance of shared state is
// fixed by this encapsulation.
class StockSenseTaskHandler extends TaskHandler {
  bool _stop = false;
  int _scanN = 0;
  int _lastScanFailures = 0;
  String? _lastScanErrorSample;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _stop = false;
    _scanN = 0;
    try {
      await NotificationService().init();
      await _runSession();
    } catch (e, st) {
      await _reportBgCrash('onStart/_runSession failed', e, st);
    }
  }

  Future<void> _reportBgCrash(String context, Object e, StackTrace st) async {
    final msg = '$context: $e';
    try {
      // Persist so it survives even if the app was closed when this happened.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('stocksense_bg_crash',
          '${DateTime.now().toIso8601String()} | $msg\n$st');
    } catch (_) {}
    try {
      // Tell the UI right away if it's currently open.
      FlutterForegroundTask.sendDataToMain({'event': 'bgError', 'message': msg});
    } catch (_) {}
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _stop = true;
    await NotificationService().clearAll();
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'stop') {
      _stop = true;
      FlutterForegroundTask.stopService();
    }
  }

  Future<void> _runSession() async {
    final notif = NotificationService();
    final prefs = await SharedPreferences.getInstance();
    final rest = prefs.getInt('rest_duration') ?? 300;
    final capital = prefs.getDouble('capital') ?? 10591.0;

    while (!_stop) {
      _scanN++;
      final results = await _scan(notif, capital, _scanN);
      if (_stop) break;

      final buys = results.where((s) => s.isBuy).toList();
      final shorts = results.where((s) => s.isShort).toList();

      await TimerLogService().addEntry(TimerLogEntry(
        time: DateTime.now(),
        scanNum: _scanN,
        scanned: results.length,
        total: ALL_STOCKS.length,
        buys: buys.length,
        shorts: shorts.length,
        failures: _lastScanFailures,
        lastError: _lastScanErrorSample,
        topBuys: buys.take(3).map((s) => '${s.symbol} ${s.confidence}%').toList(),
        topShorts: shorts.take(3).map((s) => '${s.symbol} ${s.confidence}%').toList(),
      ));

      try {
        await notif.showScanComplete(
          scanNum: _scanN,
          buys: buys.length,
          shorts: shorts.length,
          topBuys: buys.take(3).map((s) => '${s.symbol} ${s.confidence}%').toList(),
          topShorts: shorts.take(3).map((s) => '${s.symbol} ${s.confidence}%').toList(),
        );
      } catch (_) {}

      FlutterForegroundTask.sendDataToMain({
        'event': 'scanComplete',
        'scanNum': _scanN,
        'buys': buys.length,
        'shorts': shorts.length,
        'failures': _lastScanFailures,
        'lastError': _lastScanErrorSample,
        // Fix #5 — ALL 12 fields forwarded
        'signals': results.map((s) => {
          'symbol': s.symbol,
          'signal': s.signal,
          'confidence': s.confidence,
          'price': s.price,
          'rsi': s.rsi,
          'volRatio': s.volRatio,
          'candle': s.candle,         // Fix #5
          'emaBullish': s.emaBullish, // Fix #5
          'aboveVwap': s.aboveVwap,   // Fix #5
          'macdBull': s.macdBull,     // Fix #5
          'extended': s.extended,     // Fix #5
          'sectorWeak': s.sectorWeak, // Fix #5
        }).toList(),
      });

      if (_stop) break;
      await _rest(notif, rest, _scanN);
    }
    try {
      await notif.clearAll();
    } catch (_) {}
  }

  Future<List<StockSignal>> _scan(
      NotificationService notif, double capital, int scanN) async {
    final results = <StockSignal>[];
    int buys = 0, shorts = 0, failures = 0;
    String? lastFailureSymbol;
    for (int i = 0; i < ALL_STOCKS.length; i++) {
      if (_stop) break;
      final sig = await ApiService().scanStock(ALL_STOCKS[i], capital: capital);
      if (sig != null) {
        results.add(sig);
        if (sig.isBuy) buys++;
        if (sig.isShort) shorts++;
      } else {
        failures++;
        lastFailureSymbol = ALL_STOCKS[i];
      }
      if (i == 0 || i % 5 == 0 || i == ALL_STOCKS.length - 1) {
        try {
          await notif.showScanProgress(
            scanned: i + 1,
            total: ALL_STOCKS.length, // Fix #7 — use actual list length
            buys: buys,
            shorts: shorts,
            scanNum: scanN,
          );
        } catch (_) {
          // Never let a notification failure kill the whole scan loop.
        }
        // 2026-07-11: persist a lightweight progress marker so the main
        // isolate's fallback poll can show live incremental progress
        // instead of only ever seeing "scan complete" at the very end.
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('scan_progress_marker', jsonEncode({
            'scanned': i + 1,
            'total': ALL_STOCKS.length,
            'buys': buys,
            'shorts': shorts,
            'currentSymbol': ALL_STOCKS[i],
            'scanNum': scanN,
            'failures': failures,
            'time': DateTime.now().toIso8601String(),
          }));
        } catch (_) {}
        FlutterForegroundTask.sendDataToMain({
          'event': 'scanProgress',
          'scanned': i + 1,
          'total': ALL_STOCKS.length, // Fix #7
          'buys': buys,
          'shorts': shorts,
          'currentSymbol': ALL_STOCKS[i],
          'scanNum': scanN,
          'failures': failures,
          'lastError': failures > 0 ? ApiService().lastError : null,
          'lastFailureSymbol': lastFailureSymbol,
        });
      }
    }
    _lastScanFailures = failures;
    _lastScanErrorSample = failures > 0 ? ApiService().lastError : null;
    return results;
  }

  Future<void> _rest(NotificationService notif, int total, int scanN) async {
    int left = total;
    while (left > 0 && !_stop) {
      await Future.delayed(const Duration(seconds: 1));
      left--;
      if (left % 10 == 0 || left <= 5) {
        try {
          await notif.showRestCountdown(
              secondsLeft: left, scanNum: scanN, topSignals: []);
        } catch (_) {}
        FlutterForegroundTask.sendDataToMain({
          'event': 'restTick', 'secsLeft': left, 'scanNum': scanN,
        });
      }
    }
  }
}

class ScanService {
  static final ScanService _i = ScanService._();
  factory ScanService() => _i;
  ScanService._();

  Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'stocksense_scan',
        channelName: 'StockSense Scan',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  Future<void> startScan() async {
    // _stop=false no longer needs setting here — onStart() in the
    // background isolate's TaskHandler resets its own instance field
    // every time the service (re)starts.
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 888,
        notificationTitle: 'StockSense Scanning',
        notificationText: 'Scanning ${ALL_STOCKS.length} stocks...',
        callback: startCallback,
      );
    }
  }

  Future<void> stopScan() async {
    // stopService() triggers onDestroy() inside the background isolate,
    // which sets that isolate's own _stop field to true — that's the
    // real stop signal; there's nothing else to do from this isolate.
    await FlutterForegroundTask.stopService();
  }

  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}
