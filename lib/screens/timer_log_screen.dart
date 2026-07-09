import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../constants.dart';
import '../models/timer_log_entry.dart';
import '../services/timer_log_service.dart';

class TimerLogScreen extends StatefulWidget {
  const TimerLogScreen({super.key});
  @override
  State<TimerLogScreen> createState() => _TimerLogScreenState();
}

class _TimerLogScreenState extends State<TimerLogScreen> {
  List<TimerLogEntry> _entries = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await TimerLogService().loadAll();
    if (!mounted) return;
    setState(() {
      _entries = entries.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(COLOR_CARD),
        title: const Text('Clear All', style: TextStyle(color: Color(COLOR_TEXT))),
        content: const Text('Clear the entire timer scan log?', style: TextStyle(color: Color(COLOR_MUTED))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: Color(COLOR_RED)))),
        ],
      ),
    );
    if (confirm == true) {
      await TimerLogService().clear();
      await _load();
    }
  }

  String _asText() {
    if (_entries.isEmpty) return 'No timer scans logged yet.';
    return _entries.map((e) =>
      'Scan #${e.scanNum} \u2014 ${e.time.toString().substring(0, 19)}\n'
      'Scanned: ${e.scanned}/${e.total}  Buys: ${e.buys}  Shorts: ${e.shorts}  Failures: ${e.failures}\n'
      '${e.topBuys.isNotEmpty ? "Top Buys: ${e.topBuys.join(", ")}\n" : ""}'
      '${e.topShorts.isNotEmpty ? "Top Shorts: ${e.topShorts.join(", ")}\n" : ""}'
      '${e.lastError != null ? "Last error: ${e.lastError}\n" : ""}'
    ).join('\n${'=' * 30}\n\n');
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (context) => [
      pw.Text('StockSense \u2014 Timer Scan Log', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(DateTime.now().toIso8601String(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 16),
      pw.Text(_asText(), style: const pw.TextStyle(fontSize: 9)),
    ]));
    return doc.save();
  }

  Future<void> _exportTxt() async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/timer_log_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(_asText());
      await Share.shareXFiles([XFile(file.path)], text: 'StockSense Timer Scan Log');
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await FileSaver.instance.saveAs(
        name: 'timer_log_$stamp',
        bytes: await _buildPdfBytes(),
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(COLOR_BG),
      appBar: AppBar(
        backgroundColor: const Color(COLOR_BG),
        title: const Text('\u23F1\u{FE0F} TIMER SCAN LOG',
            style: TextStyle(fontSize: 13, letterSpacing: 1, color: Color(COLOR_TEXT))),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(COLOR_RED)),
              tooltip: 'Clear All', onPressed: _clear),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy || _entries.isEmpty ? null : _exportPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(COLOR_GREEN),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(COLOR_CARD),
                      ),
                      child: const Text('\u{1F4C4} EXPORT ALL TIMER LOGS AS PDF',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _busy || _entries.isEmpty ? null : _exportTxt,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(COLOR_MUTED),
                        side: BorderSide(color: const Color(COLOR_BORDER)),
                      ),
                      child: const Text('\u{1F4DD} EXPORT ALL TIMER LOGS AS TXT',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(
                          child: Text('No timer scans yet.', style: TextStyle(color: Color(COLOR_MUTED))),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _entries.length,
                          itemBuilder: (_, i) => _logItem(_entries[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _logItem(TimerLogEntry e) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(COLOR_CARD),
      border: Border.all(color: const Color(COLOR_BORDER)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Scan #${e.scanNum}',
                style: const TextStyle(color: Color(COLOR_BLUE), fontSize: 12, fontWeight: FontWeight.w800)),
            Text(e.time.toString().substring(0, 19),
                style: const TextStyle(color: Color(COLOR_MUTED), fontSize: 9)),
          ],
        ),
        const Divider(color: Color(COLOR_BORDER), height: 16),
        Row(
          children: [
            _pill('${e.scanned}/${e.total}', 'SCANNED', const Color(COLOR_TEXT)),
            _pill('${e.buys}', 'BUYS', const Color(COLOR_GREEN)),
            _pill('${e.shorts}', 'SHORTS', const Color(COLOR_RED)),
            if (e.failures > 0) _pill('${e.failures}', 'FAILED', const Color(COLOR_YELLOW)),
          ],
        ),
        if (e.topBuys.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('\u{1F7E2} ${e.topBuys.join("  ")}',
              style: const TextStyle(color: Color(COLOR_GREEN), fontSize: 10)),
        ],
        if (e.topShorts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('\u{1F534} ${e.topShorts.join("  ")}',
              style: const TextStyle(color: Color(COLOR_RED), fontSize: 10)),
        ],
        if (e.lastError != null) ...[
          const SizedBox(height: 8),
          Text('\u26A0\uFE0F ${e.lastError}',
              style: const TextStyle(color: Color(COLOR_YELLOW), fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ],
    ),
  );

  Widget _pill(String value, String label, Color color) => Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Color(COLOR_MUTED), fontSize: 7, letterSpacing: 1)),
      ],
    ),
  );
}
