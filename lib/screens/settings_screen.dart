import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState()=>_S();
}
class _S extends State<SettingsScreen> {
  final _cap=TextEditingController(text:'10591');
  int _rest=300;String _mood='NEUTRAL';
  @override void initState(){super.initState();_load();}
  Future<void> _load() async{final p=await SharedPreferences.getInstance();setState((){_cap.text=(p.getDouble('capital')??10591.0).toStringAsFixed(0);_rest=p.getInt('rest_duration')??300;_mood=p.getString('market_mood')??'NEUTRAL';});}
  Future<void> _save() async{final p=await SharedPreferences.getInstance();await p.setDouble('capital',double.tryParse(_cap.text)??10591.0);await p.setInt('rest_duration',_rest);await p.setString('market_mood',_mood);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('\\u2705 Settings saved'),backgroundColor:Color(COLOR_GREEN),duration:Duration(seconds:2)));}
  @override void dispose(){_cap.dispose();super.dispose();}
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:const Color(COLOR_BG),
    appBar:AppBar(title:const Text('SETTINGS'),actions:[TextButton(onPressed:_save,child:const Text('SAVE',style:TextStyle(color:Color(COLOR_GREEN),fontWeight:FontWeight.bold)))]),
    body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('\\U0001f4b0 TRADING CAPITAL',style:TextStyle(color:Colors.grey,fontSize:11,letterSpacing:2)),const SizedBox(height:8),
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(COLOR_CARD),borderRadius:BorderRadius.circular(8)),child:Row(children:[const Text('\\u20b9 ',style:TextStyle(color:Color(COLOR_GREEN),fontSize:20)),Expanded(child:TextField(controller:_cap,keyboardType:TextInputType.number,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold),decoration:const InputDecoration(border:InputBorder.none)))])),
      const SizedBox(height:16),
      const Text('\\u2699\\ufe0f TIMER SETTINGS',style:TextStyle(color:Colors.grey,fontSize:11,letterSpacing:2)),const SizedBox(height:8),
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(COLOR_CARD),borderRadius:BorderRadius.circular(8)),
        child:Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Rest Duration',style:TextStyle(color:Colors.white,fontSize:14)),Text('Gap between scans',style:TextStyle(color:Colors.grey,fontSize:11))])),
          DropdownButton<int>(value:_rest,dropdownColor:const Color(COLOR_CARD),style:const TextStyle(color:Colors.white),underline:const SizedBox(),items:const[DropdownMenuItem(value:180,child:Text('3 min')),DropdownMenuItem(value:300,child:Text('5 min')),DropdownMenuItem(value:420,child:Text('7 min'))],onChanged:(v)=>setState(()=>_rest=v!))])),
      const SizedBox(height:16),
      const Text('\\U0001f4ca MARKET MOOD',style:TextStyle(color:Colors.grey,fontSize:11,letterSpacing:2)),const SizedBox(height:8),
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(COLOR_CARD),borderRadius:BorderRadius.circular(8)),
        child:Column(children:['BULLISH','NEUTRAL','BEARISH'].map((m){final s=_mood==m;final c=m=='BULLISH'?const Color(COLOR_GREEN):m=='BEARISH'?const Color(COLOR_RED):const Color(COLOR_YELLOW);return ListTile(contentPadding:EdgeInsets.zero,title:Text(m,style:TextStyle(color:s?c:Colors.grey,fontWeight:s?FontWeight.bold:FontWeight.normal)),trailing:s?Icon(Icons.check_circle,color:c):null,onTap:()=>setState(()=>_mood=m));}).toList())),
      const SizedBox(height:20),
      Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(COLOR_YELLOW).withOpacity(0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:const Color(COLOR_YELLOW).withOpacity(0.3))),child:const Text('\\u26a0\\ufe0f PERSONAL USE ONLY \u2014 Not SEBI registered advice. Always use stop-loss.',style:TextStyle(color:Color(COLOR_YELLOW),fontSize:11))),
    ])));
}
