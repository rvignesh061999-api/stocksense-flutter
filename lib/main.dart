import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/notification_service.dart';
import 'services/scan_service.dart';
import 'screens/home_screen.dart';
import 'constants.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor:Colors.transparent,statusBarIconBrightness:Brightness.light));
  await NotificationService().init();
  await ScanService().init();
  runApp(const StockSenseApp());
}
class StockSenseApp extends StatelessWidget {
  const StockSenseApp({super.key});
  @override Widget build(BuildContext ctx)=>MaterialApp(
    title:'StockSense',debugShowCheckedModeBanner:false,
    theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:const Color(COLOR_BG),
      colorScheme:const ColorScheme.dark(primary:Color(COLOR_GREEN),secondary:Color(COLOR_YELLOW),error:Color(COLOR_RED),surface:Color(COLOR_CARD)),
      fontFamily:'monospace',appBarTheme:const AppBarTheme(backgroundColor:Color(COLOR_BG),elevation:0,titleTextStyle:TextStyle(color:Color(COLOR_GREEN),fontSize:18,fontWeight:FontWeight.bold,fontFamily:'monospace',letterSpacing:2))),
    home:const HomeScreen());
}
