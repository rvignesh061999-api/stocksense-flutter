import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/notification_service.dart';
import 'services/scan_service.dart';
import 'screens/home_screen.dart';
import 'constants.dart';

void main() {
  // 2026-07-08: show the real error on-screen instead of a blank grey
  // screen — StockSense had zero crash visibility until now.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final errorText = 'STOCKSENSE CRASH:\n\n${details.exceptionAsString()}\n\n${details.stack}';
    debugPrint(errorText);
    return Material(
      color: const Color(COLOR_BG),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('COPY ERROR TO CLIPBOARD'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(COLOR_GREEN),
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Clipboard.setData(ClipboardData(text: errorText)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    errorText,
                    style: const TextStyle(color: Color(COLOR_RED), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FRAMEWORK ERROR: ${details.exceptionAsString()}\n${details.stack}');
    FlutterError.presentError(details);
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    try {
      await NotificationService().init();
    } catch (e, st) {
      debugPrint('NotificationService init failed: $e\n$st');
    }
    try {
      await ScanService().init();
    } catch (e, st) {
      debugPrint('ScanService init failed: $e\n$st');
    }
    runApp(const StockSenseApp());
  }, (error, stack) {
    debugPrint('UNCAUGHT ERROR: $error\n$stack');
  });
}

class StockSenseApp extends StatelessWidget {
  const StockSenseApp({super.key});
  @override
  Widget build(BuildContext ctx) => MaterialApp(
    title: 'StockSense',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(COLOR_BG),
      colorScheme: const ColorScheme.dark(
        primary: Color(COLOR_GREEN),
        secondary: Color(COLOR_YELLOW),
        error: Color(COLOR_RED),
        surface: Color(COLOR_CARD),
      ),
      fontFamily: 'monospace',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(COLOR_BG),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Color(COLOR_GREEN),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 2,
        ),
      ),
    ),
    home: WithForegroundTask(child: const HomeScreen()),
  );
}
