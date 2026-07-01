import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';
import '../constants.dart';
import '../models/signal.dart';

bool _stop = false;
int _scanN = 0;

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StockSenseTaskHandler());
}

class StockSenseTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp) async {
    _stop = false;
    _scanN = 0;
    await NotificationService().init();
    await _runSession();
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

      final buyStr = buys.take(2).map((s) => '🟢 ' + s.symbol + ' ' + s.confidence.toString() + '%').join('  ');
      final shortStr = shorts.take(2).map((s) => '🔴 ' + s.symbol + ' ' + s.confidence.toString() + '%').join('  ');

      await notif.showScanComplete(
        scanNum: _scanN,
        buys: buys.length,
        shorts: shorts.length,
        topBuys: buys.take(3).map((s) => s.symbol + ' ' + s.confidence.toString() + '%').toList(),
        topShorts: shorts.take(3).map((s) => s.symbol + ' ' + s.confidence.toString() + '%').toList(),
      );

      FlutterForegroundTask.sendDataToMain({
        'event': 'scanComplete',
        'scanNum': _scanN,
        'buys': buys.length,
        'shorts': shorts.length,
        'signals': results.map((s) => {
          'symbol': s.symbol, 'signal': s.signal,
          'confidence': s.confidence, 'price': s.price,
          'rsi': s.rsi, 'volRatio': s.volRatio
        }).toList(),
      });

      if (_stop) break;
      await _rest(notif, rest, _scanN, [buyStr, shortStr]);
    }
    await notif.clearAll();
  }

  Future<List<StockSignal>> _scan(NotificationService notif, double capital, int scanN) async {
    final results = <StockSignal>[];
    int buys = 0, shorts = 0;
    for (int i = 0; i < ALL_STOCKS.length; i++) {
      if (_stop) break;
      final sig = await ApiService().scanStock(ALL_STOCKS[i], capital: capital);
      if (sig != null) {
        results.add(sig);
        if (sig.isBuy) buys++;
        if (sig.isShort) shorts++;
      }
      if (i == 0 || i % 5 == 0 || i == ALL_STOCKS.length - 1) {
        await notif.showScanProgress(
          scanned: i + 1, total: ALL_STOCKS.length,
          buys: buys, shorts: shorts, scanNum: scanN,
        );
        FlutterForegroundTask.sendDataToMain({
          'event': 'scanProgress',
          'scanned': i + 1, 'total': ALL_STOCKS.length,
          'buys': buys, 'shorts': shorts,
          'currentSymbol': ALL_STOCKS[i], 'scanNum': scanN,
        });
      }
    }
    return results;
  }

  Future<void> _rest(NotificationService notif, int total, int scanN, List<String> sigs) async {
    int left = total;
    while (left > 0 && !_stop) {
      await Future.delayed(const Duration(seconds: 1));
      left--;
      if (left % 10 == 0 || left <= 5) {
        await notif.showRestCountdown(secondsLeft: left, scanNum: scanN, topSignals: sigs);
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
        channelDescription: 'StockSense scanning service',
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
    _stop = false;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 888,
        notificationTitle: 'StockSense Scanning',
        notificationText: 'Scanning stocks...',
        callback: startCallback,
      );
    }
  }

  Future<void> stopScan() async {
    _stop = true;
    await FlutterForegroundTask.stopService();
  }

  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}
