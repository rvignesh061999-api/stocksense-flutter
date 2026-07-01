import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import 'timer_scan_screen.dart';
import 'settings_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState()=>_S();
}
class _S extends State<HomeScreen> {
  int _idx=0;Timer? _t;DateTime _now=DateTime.now();
  @override void initState(){super.initState();_t=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>_now=DateTime.now());});}
  @override void dispose(){_t?.cancel();super.dispose();}
  bool get _open{if(_now.weekday==DateTime.saturday||_now.weekday==DateTime.sunday)return false;final tot=_now.hour*60+_now.minute;return tot>=MARKET_OPEN_HOUR*60+MARKET_OPEN_MIN&&tot<MARKET_CLOSE_HOUR*60+MARKET_CLOSE_MIN;}
  bool get _best{final tot=_now.hour*60+_now.minute;return tot>=BEST_ENTRY_HOUR*60+BEST_ENTRY_MIN&&tot<EXIT_WARNING_HOUR*60+EXIT_WARNING_MIN;}
  String get _time=>'\\${_now.hour.toString().padLeft(2,"0")}:\\${_now.minute.toString().padLeft(2,"0")}:\\${_now.second.toString().padLeft(2,"0")}';
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:const Color(COLOR_BG),
    body:SafeArea(child:Column(children:[
      Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),child:Row(children:[
        RichText(text:const TextSpan(children:[TextSpan(text:'STOCK',style:TextStyle(color:Color(COLOR_GREEN),fontSize:20,fontWeight:FontWeight.bold,letterSpacing:2)),TextSpan(text:'SENSE',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold,letterSpacing:2)),TextSpan(text:'  V1.0',style:TextStyle(color:Colors.grey,fontSize:12))])),
        const Spacer(),
        Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:(_open?const Color(COLOR_GREEN):Colors.red).withOpacity(0.1),borderRadius:BorderRadius.circular(20),border:Border.all(color:(_open?const Color(COLOR_GREEN):Colors.red).withOpacity(0.5))),
          child:Row(mainAxisSize:MainAxisSize.min,children:[Container(width:7,height:7,decoration:BoxDecoration(color:_open?const Color(COLOR_GREEN):Colors.red,shape:BoxShape.circle)),const SizedBox(width:5),Text(_open?'MARKET OPEN':'MARKET CLOSED',style:TextStyle(color:_open?const Color(COLOR_GREEN):Colors.red,fontSize:10,fontWeight:FontWeight.bold))]))])),
      Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:6),color:const Color(COLOR_CARD),child:Row(children:[const Text('IST',style:TextStyle(color:Colors.grey,fontSize:10,letterSpacing:2)),const SizedBox(width:12),Text(_time,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.bold,fontFamily:'monospace')),const Spacer(),if(_open&&_best)const Text('\\u2705 BEST ENTRY WINDOW',style:TextStyle(color:Color(COLOR_GREEN),fontSize:10,fontWeight:FontWeight.bold))])),
      Container(height:2,decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(COLOR_GREEN),Color(0xFF004422)]))),
      Expanded(child:IndexedStack(index:_idx,children:const[TimerScanScreen(),SettingsScreen()])),
    ])),
    bottomNavigationBar:BottomNavigationBar(currentIndex:_idx,onTap:(i)=>setState(()=>_idx=i),backgroundColor:const Color(COLOR_CARD),selectedItemColor:const Color(COLOR_GREEN),unselectedItemColor:Colors.grey,
      items:const[BottomNavigationBarItem(icon:Icon(Icons.timer),label:'TIMER SCAN'),BottomNavigationBarItem(icon:Icon(Icons.settings),label:'SETTINGS')]));
}
