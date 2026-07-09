import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../constants.dart';
import '../models/api_log_entry.dart';
import '../services/api_monitor_service.dart';
import '../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<ApiLogEntry> _all = [];
  String _filter = 'all';
  String _search = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ApiMonitorService().refresh();
    if (!mounted) return;
    setState(() => _all = ApiMonitorService().entries);
  }

  List<ApiLogEntry> get _filtered {
    var list = _all;
    if (_filter == 'error') {
      list = list.where((e) => !e.success).toList();
    } else if (_filter == 'slow') {
      list = list.where((e) => e.durationMs > 2000).toList();
    } else if (_filter != 'all') {
      list = list.where((e) => e.api == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
          e.url.toLowerCase().contains(q) || (e.error ?? '').toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> _runAllTests() async {
    setState(() => _busy = true);
    await ApiService().getStatus();
    await ApiService().scanStock('RELIANCE');
    await _load();
    setState(() => _busy = false);
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(COLOR_CARD),
        title: const Text('Clear API Log', style: TextStyle(color: Color(COLOR_TEXT))),
        content: const Text('Clear all logged API calls?', style: TextStyle(color: Color(COLOR_MUTED))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: Color(COLOR_RED)))),
        ],
      ),
    );
    if (confirm == true) {
      await ApiMonitorService().clear();
      await _load();
    }
  }

  String _asText() {
    if (_all.isEmpty) return 'No API calls logged.';
    return _all.map((e) =>
      '[${e.time.toIso8601String()}] ${e.api.toUpperCase()} ${e.method} ${e.url}\n'
      '  status=${e.statusCode ?? "-"} ${e.success ? "OK" : "FAIL"} ${e.durationMs}ms'
      '${e.error != null ? "\n  error: ${e.error}" : ""}'
    ).join('\n\n');
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (context) => [
      pw.Text('StockSense \u2014 Kibana API Monitor', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(DateTime.now().toIso8601String(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 16),
      pw.Text(_asText(), style: const pw.TextStyle(fontSize: 8)),
    ]));
    return doc.save();
  }

  Future<void> _exportTxt() async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kibana_log_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(_asText());
      await Share.shareXFiles([XFile(file.path)], text: 'StockSense API Monitor log');
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await FileSaver.instance.saveAs(
        name: 'kibana_log_$stamp',
        bytes: await _buildPdfBytes(),
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Color _apiColor(String api) {
    switch (api) {
      case 'twelvedata': return const Color(COLOR_BLUE);
      case 'alphavantage': return const Color(COLOR_YELLOW);
      case 'claude': return const Color(0xFFB784FF);
      default: return const Color(COLOR_GREEN); // replit
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(COLOR_BG),
      appBar: AppBar(
        backgroundColor: const Color(COLOR_BG),
        title: const Text('\u{1F6E0}\u{FE0F} KIBANA API MONITOR',
            style: TextStyle(fontSize: 12, letterSpacing: 2, color: Color(COLOR_MUTED))),
        actions: [
          IconButton(icon: const Icon(Icons.description_outlined, size: 18, color: Color(COLOR_GREEN)),
              tooltip: 'Export TXT', onPressed: _busy ? null : _exportTxt),
          IconButton(icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(COLOR_BLUE)),
              tooltip: 'Export PDF', onPressed: _busy ? null : _exportPdf),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(COLOR_RED)),
              tooltip: 'Clear', onPressed: _clear),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _runAllTests,
                icon: _busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow, size: 16),
                label: const Text('TEST ALL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(COLOR_GREEN).withOpacity(0.1),
                  foregroundColor: const Color(COLOR_GREEN),
                  elevation: 0,
                  side: BorderSide(color: const Color(COLOR_GREEN).withOpacity(0.3)),
                ),
              ),
            ),
          ),

          // API status cards (2x2 grid, matches web app's adminStatusGrid)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                _apiCard('Replit Server', 'replit'),
                _apiCard('Twelve Data', 'twelvedata'),
                _apiCard('Alpha Vantage', 'alphavantage'),
                _apiCard('Claude AI', 'claude'),
              ],
            ),
          ),

          // Live stats bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _statBox('${ApiMonitorService().totalCalls}', 'TOTAL CALLS', const Color(COLOR_TEXT)),
                _statBox('${ApiMonitorService().successCount}', 'SUCCESS', const Color(COLOR_GREEN)),
                _statBox('${ApiMonitorService().errorCount}', 'ERRORS', const Color(COLOR_RED)),
                _statBox(
                  ApiMonitorService().avgMs == 0 ? '\u2014' : '${ApiMonitorService().avgMs.round()}',
                  'AVG MS', const Color(COLOR_YELLOW),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              style: const TextStyle(color: Color(COLOR_TEXT), fontSize: 12),
              decoration: InputDecoration(
                hintText: '\u{1F50D} Search URL, symbol, status...',
                hintStyle: const TextStyle(color: Color(COLOR_MUTED), fontSize: 12),
                filled: true,
                fillColor: const Color(COLOR_CARD),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color(COLOR_BORDER)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              children: [
                _filterChip('all', 'ALL'),
                _filterChip('replit', 'REPLIT'),
                _filterChip('twelvedata', '12DATA'),
                _filterChip('alphavantage', 'AV'),
                _filterChip('claude', 'CLAUDE'),
                _filterChip('error', '\u274C ERRORS'),
                _filterChip('slow', '\u{1F40C} SLOW'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Log list
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No requests yet.\nUse any feature in the app to see live API logs here.',
                        textAlign: TextAlign.center, style: TextStyle(color: Color(COLOR_MUTED), fontSize: 11)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _logRow(_filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _apiCard(String name, String key) {
    final last = _all.where((e) => e.api == key).toList();
    final ok = last.isNotEmpty ? last.last.success : null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(COLOR_CARD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(COLOR_BORDER)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ok == null ? const Color(COLOR_MUTED) : (ok ? const Color(COLOR_GREEN) : const Color(COLOR_RED)),
              ),
            ),
            const SizedBox(width: 6),
            Text(name, style: const TextStyle(color: Color(COLOR_TEXT), fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text(
            last.isEmpty ? '\u2014' : '${last.last.durationMs}ms',
            style: const TextStyle(color: Color(COLOR_MUTED), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String value, String label, Color color) => Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(COLOR_MUTED), fontSize: 8, letterSpacing: 1)),
      ],
    ),
  );

  Widget _filterChip(String key, String label) {
    final active = _filter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 9, color: active ? Colors.black : const Color(COLOR_MUTED))),
      selected: active,
      selectedColor: const Color(COLOR_GREEN),
      backgroundColor: const Color(COLOR_CARD),
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _logRow(ApiLogEntry e) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(COLOR_CARD),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: e.success ? const Color(COLOR_BORDER) : const Color(COLOR_RED).withOpacity(0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(e.time.toString().substring(5, 19),
              style: const TextStyle(color: Color(COLOR_MUTED), fontSize: 9, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: _apiColor(e.api).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(e.api.toUpperCase(), style: TextStyle(color: _apiColor(e.api), fontSize: 8, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          Text('${e.statusCode ?? "-"}',
              style: TextStyle(color: e.success ? const Color(COLOR_GREEN) : const Color(COLOR_RED), fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('${e.durationMs}ms', style: const TextStyle(color: Color(COLOR_MUTED), fontSize: 9)),
        ]),
        const SizedBox(height: 3),
        Text(e.url, style: const TextStyle(color: Color(COLOR_TEXT), fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (e.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(e.error!, style: const TextStyle(color: Color(COLOR_RED), fontSize: 8), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
      ],
    ),
  );
}
