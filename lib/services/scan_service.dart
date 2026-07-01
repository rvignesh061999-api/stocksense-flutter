import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';
import '../constants.dart';
import '../models/signal.dart';
bool _stop=false;
int _scanN=0;
@pragma('vm:entry-point')
void backgroundMain(ServiceInstance svc){
  _stop=false;_scanN=0;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  svc.on('stopScan').listen((_){_stop=true;NotificationService().clearAll();});
  svc.on('startScan').listen((_) async{_stop=false;await _runSession(svc);});
}
Future<void> _runSession(ServiceInstance svc) async {
  _stop=false;_scanN=0;
  final notif=NotificationService();await notif.init();
  final prefs=await SharedPreferences.getInstance();
  final rest=prefs.getInt('rest_duration')??300;
  final capital=prefs.getDouble('capital')??10591.0;
  while(!_stop){
    _scanN++;
    final results=await _scan(svc,notif,capital,_scanN);
    if(_stop) break;
    final buys=results.where((s)=>s.isBuy).toList();
    final shorts=results.where((s)=>s.isShort).toList();
    await notif.showScanComplete(scanNum:_scanN,buys:buys.length,shorts:shorts.length,
      topBuys:buys.take(3).map((s)=>'\\${s.symbol} \\${s.confidence}%').toList(),
      topShorts:shorts.take(3).map((s)=>'\\${s.symbol} \\${s.confidence}%').toList());
    svc.invoke('scanComplete',{'scanNum':_scanN,'buys':buys.length,'shorts':shorts.length,
      'signals':results.map((s)=>{'symbol':s.symbol,'signal':s.signal,'confidence':s.confidence,'price':s.price,'rsi':s.rsi,'volRatio':s.volRatio}).toList()});
    if(_stop) break;
    await _rest(svc,notif,rest,_scanN,[...buys.take(2).map((s)=>'\\U0001f7e2 \\${s.symbol} \\${s.confidence}%'),...shorts.take(2).map((s)=>'\\U0001f534 \\${s.symbol} \\${s.confidence}%')]);
  }
  await notif.clearAll();
  svc.invoke('sessionStopped',{});
}
Future<List<StockSignal>> _scan(ServiceInstance svc,NotificationService notif,double capital,int scanN) async {
  final results=<StockSignal>[];int buys=0,shorts=0;
  for(int i=0;i<ALL_STOCKS.length;i++){
    if(_stop) break;
    final sig=await ApiService().scanStock(ALL_STOCKS[i],capital:capital);
    if(sig!=null){results.add(sig);if(sig.isBuy)buys++;if(sig.isShort)shorts++;}
    if(i==0||i%5==0||i==ALL_STOCKS.length-1){
      await notif.showScanProgress(scanned:i+1,total:ALL_STOCKS.length,buys:buys,shorts:shorts,scanNum:scanN);
      svc.invoke('scanProgress',{'scanned':i+1,'total':ALL_STOCKS.length,'buys':buys,'shorts':shorts,'currentSymbol':ALL_STOCKS[i],'scanNum':scanN});
    }
  }
  return results;
}
Future<void> _rest(ServiceInstance svc,NotificationService notif,int total,int scanN,List<String> sigs) async {
  int left=total;
  final c=Completer<void>();
  Timer.periodic(const Duration(seconds:1),(t) async {
    if(_stop){t.cancel();c.complete();return;}
    left--;
    if(left%10==0||left<=5){
      await notif.showRestCountdown(secondsLeft:left,scanNum:scanN,topSignals:sigs);
      svc.invoke('restTick',{'secsLeft':left,'scanNum':scanN});
    }
    if(left<=0){t.cancel();c.complete();}
  });
  await c.future;
}
class ScanService {
  static final ScanService _i=ScanService._();
  factory ScanService()=>_i;
  ScanService._();
  final _svc=FlutterBackgroundService();
  Future<void> init() async {
    await _svc.configure(
      androidConfiguration:AndroidConfiguration(onStart:backgroundMain,autoStart:false,isForegroundMode:true,
        notificationChannelId:'stocksense_scan',initialNotificationTitle:'StockSense',
        initialNotificationContent:'Ready to scan',foregroundServiceNotificationId:888),
      iosConfiguration:IosConfiguration(autoStart:false,onForeground:backgroundMain));
  }
  Future<void> startScan() async {if(!await _svc.isRunning()) await _svc.startService();_svc.invoke('startScan',{});}
  Future<void> stopScan() async=>_svc.invoke('stopScan',{});
  Stream<Map<String,dynamic>?> get onProgress=>_svc.on('scanProgress');
  Stream<Map<String,dynamic>?> get onScanComplete=>_svc.on('scanComplete');
  Stream<Map<String,dynamic>?> get onRestTick=>_svc.on('restTick');
  Stream<Map<String,dynamic>?> get onStopped=>_svc.on('sessionStopped');
  Future<bool> get isRunning=>_svc.isRunning();
}
