import 'package:flutter/material.dart';
import '../models/signal.dart';
import '../constants.dart';
class SignalCard extends StatelessWidget {
  final StockSignal signal;
  const SignalCard({super.key,required this.signal});
  @override Widget build(BuildContext ctx){
    final c=signal.isBuy?const Color(COLOR_GREEN):signal.isShort?const Color(COLOR_RED):Colors.grey;
    return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:const Color(COLOR_CARD),borderRadius:BorderRadius.circular(8),border:Border.all(color:c.withOpacity(0.3))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Text(signal.signalEmoji,style:const TextStyle(fontSize:16)),const SizedBox(width:8),
          Text(signal.symbol,style:TextStyle(color:c,fontSize:16,fontWeight:FontWeight.bold)),const SizedBox(width:8),
          Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:2),decoration:BoxDecoration(color:c.withOpacity(0.15),borderRadius:BorderRadius.circular(4),border:Border.all(color:c.withOpacity(0.5))),
            child:Text('\\${signal.signal} \\${signal.confidence}%',style:TextStyle(color:c,fontSize:12,fontWeight:FontWeight.bold))),
          const Spacer(),Text('\\u20b9\\${signal.price.toStringAsFixed(2)}',style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.bold))]),
        const SizedBox(height:8),
        Wrap(spacing:8,runSpacing:4,children:[
          _i('RSI','\\${signal.rsi.toStringAsFixed(1)}',signal.rsi>50?const Color(COLOR_GREEN):const Color(COLOR_RED)),
          _i('VOL','\\${signal.volRatio.toStringAsFixed(2)}x',signal.volRatio>=0.9?const Color(COLOR_GREEN):const Color(COLOR_YELLOW)),
          _i('EMA',signal.emaBullish?'Bull':'Bear',signal.emaBullish?const Color(COLOR_GREEN):const Color(COLOR_RED)),
          _i('MACD',signal.macdBull?'Bull':'Bear',signal.macdBull?const Color(COLOR_GREEN):const Color(COLOR_RED)),
        ]),
        if(signal.extended||signal.sectorWeak)...[const SizedBox(height:6),Wrap(spacing:6,children:[if(signal.extended)_w('\\u26a0\\ufe0f EXTENDED'),if(signal.sectorWeak)_w('\\u26a0\\ufe0f SECTOR WEAK')])],
        const SizedBox(height:8),const Divider(color:Color(0xFF222222),height:1),const SizedBox(height:8),
        Row(children:[_l('ENTRY','\\u20b9\\${signal.price.toStringAsFixed(2)}',Colors.white),_l('SL','\\u20b9\\${signal.stopLoss.toStringAsFixed(2)}',const Color(COLOR_RED)),_l('TARGET','\\u20b9\\${signal.target.toStringAsFixed(2)}',const Color(COLOR_GREEN))]),
      ]));
  }
  Widget _i(String l,String v,Color c)=>Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:c.withOpacity(0.1),borderRadius:BorderRadius.circular(4)),child:Text('\\$l: \\$v',style:TextStyle(color:c,fontSize:10,fontWeight:FontWeight.bold)));
  Widget _w(String t)=>Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:const Color(COLOR_YELLOW).withOpacity(0.1),borderRadius:BorderRadius.circular(4),border:Border.all(color:const Color(COLOR_YELLOW).withOpacity(0.3))),child:Text(t,style:const TextStyle(color:Color(COLOR_YELLOW),fontSize:10)));
  Widget _l(String l,String v,Color c)=>Expanded(child:Column(children:[Text(l,style:const TextStyle(color:Colors.grey,fontSize:10,letterSpacing:1)),Text(v,style:TextStyle(color:c,fontSize:12,fontWeight:FontWeight.bold))]));
}
