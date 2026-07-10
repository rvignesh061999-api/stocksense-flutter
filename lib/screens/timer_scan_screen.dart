import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/scan_service.dart';
import '../services/notification_service.dart';
import '../models/signal.dart';
import '../widgets/signal_card.dart';
import '../constants.dart';

class TimerScanScreen extends StatefulWidget {
  const TimerScanScreen({super.key});
  @override State<TimerScanScreen> createState() => _S();
}

class _S extends State<TimerScanScreen> {
  final _svc = ScanService();
  bool _run = false, _rest = false;
  int _scanN = 0, _scanned = 0, _total = ALL_STOCKS.length, // Fix #7
      _buys = 0, _shorts = 0, _restSecs = 300, _failures = 0;
  String _cur = '', _status = 'IDLE \u2014 PRESS START TO BEGIN';
  String? _lastError;
  List<StockSignal> _sigs = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    // 2026-07-08: known flutter_foreground_task quirk — if the background
    // service survived an app restart, its receivePort may already have a
    // listener attached, throwing "Bad state: Stream has already been
    // listened to." Don't let this crash the whole screen — just skip
    // live background-event updates for this session; the scan/timer
    // service itself is unaffected. Same fix applied on ClaudeLink.
    try {
      FlutterForegroundTask.initCommunicationPort();
      _sub = FlutterForegroundTask.receivePort?.listen(_onData);
    } catch (e, st) {
      debugPrint('receivePort listen failed (non-fatal): $e\n$st');
    }
    // Fix #6 — request permission
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().requestPermission(context);
    });
  }

  // Fix — Build Failure 2: dynamic parameter type
  void _onData(dynamic data) {
    if (!mounted || data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final event = d['event'] as String?;
    if (event == 'scanProgress') {
      setState(() {
        _scanned = d['scanned'] ?? 0;
        _total = d['total'] ?? ALL_STOCKS.length;
        _buys = d['buys'] ?? 0;
        _shorts = d['shorts'] ?? 0;
        _cur = d['currentSymbol'] ?? '';
        _scanN = d['scanNum'] ?? _scanN;
        _failures = d['failures'] ?? 0; // Fix #8/#17 — surface API failures
        _lastError = d['lastError'];
        _rest = false;
        _status = 'SCAN #$_scanN IN PROGRESS...';
      });
    } else if (event == 'scanComplete') {
      final s = (d['signals'] as List? ?? [])
          .map((x) => StockSignal.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      setState(() {
        _sigs = s.where((x) => !x.isAvoid).toList();
        _failures = d['failures'] ?? 0; // Fix #8/#17
        _lastError = d['lastError'];
      });
    } else if (event == 'restTick') {
      setState(() {
        _restSecs = d['secsLeft'] ?? 0;
        _rest = true;
        _status = 'RESTING ${_restSecs}S BEFORE SCAN #${_scanN + 1}';
      });
    } else if (event == 'bgError') {
      // 2026-07-08: the background scan crashed — show it directly instead
      // of leaving the screen frozen at "Analysing: ..." with no explanation.
      setState(() {
        _status = 'BACKGROUND ERROR';
        _lastError = d['message'] ?? 'Unknown background error';
        _failures = -1; // sentinel: distinguishes a hard crash from normal API failures
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() { _run = true; _status = 'STARTING...'; });
    await _svc.startScan();
  }

  Future<void> _stop() async {
    await _svc.stopScan();
    setState(() {
      _run = false; _rest = false;
      _status = 'IDLE \u2014 PRESS START TO BEGIN';
    });
  }

  String get _timer {
    if (_rest) {
      final m = _restSecs ~/ 60;
      final s = _restSecs % 60;
      return '${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}';
    }
    return '05:00';
  }

  Color get _tc => _rest
      ? const Color(COLOR_YELLOW)
      : _run ? const Color(0xFF4499FF) : Colors.grey.withOpacity(0.3);

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: const Color(COLOR_BG),
    body: SingleChildScrollView(child: Column(children: [
      Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(color: const Color(COLOR_CARD),
            borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(_status, style: const TextStyle(color: Colors.grey,
              fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 16),
          Text(_timer, style: TextStyle(color: _tc, fontSize: 72,
              fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 4)),
          const SizedBox(height: 8),
          Text(_run
              ? 'Scan #$_scanN | $_scanned/${ALL_STOCKS.length} stocks analysed'
              : 'Scan #0 | 0 stocks analysed',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: _run ? null : _start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('START TIMER SCAN',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(COLOR_GREEN),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(
          onPressed: _run ? _stop : null,
          icon: const Icon(Icons.stop),
          label: const Text('STOP', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(COLOR_RED),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        )),
      ])),
      // Fix #8/#17 — distinguish "no signals found" from "server/network
      // issue" instead of silently showing zero results either way.
      // 2026-07-08: also handles _failures == -1, the sentinel for a hard
      // background-isolate crash (see bgError event above).
      if (_failures != 0)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(COLOR_RED).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(COLOR_RED).withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Color(COLOR_RED), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _failures == -1
                      ? 'Background scan crashed'
                      : '$_failures request(s) failed this scan',
                  style: const TextStyle(color: Color(COLOR_RED), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (_lastError != null)
                  Text(_lastError!,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      if (_run && !_rest)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(COLOR_CARD),
              borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SCANNING IN PROGRESS',
                style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _total > 0 ? _scanned / _total : 0,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(COLOR_GREEN)),
                  minHeight: 6,
                )),
            const SizedBox(height: 6),
            Text('$_scanned/$_total',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            Text('Analysing: $_cur...',
                style: const TextStyle(color: Color(COLOR_YELLOW), fontSize: 13)),
          ]),
        ),
      if (_sigs.isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(COLOR_CARD),
              borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SCAN #$_scanN SUMMARY',
                style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 10),
            Row(children: [
              _box('BUY', _sigs.where((s) => s.isBuy).length, const Color(COLOR_GREEN)),
              const SizedBox(width: 8),
              _box('SHORT', _sigs.where((s) => s.isShort).length, const Color(COLOR_RED)),
              const SizedBox(width: 8),
              _box('TOTAL', _sigs.length, Colors.white),
            ]),
            const SizedBox(height: 12),
            ..._sigs.take(5).map((s) => SignalCard(signal: s)),
          ]),
        ),
      const SizedBox(height: 20),
    ])),
  );

  Widget _box(String l, int n, Color c) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withOpacity(0.3)),
    ),
    child: Column(children: [
      Text(l, style: TextStyle(color: c, fontSize: 11, letterSpacing: 1)),
      Text('$n', style: TextStyle(color: c, fontSize: 28, fontWeight: FontWeight.bold)),
    ]),
  ));
}
