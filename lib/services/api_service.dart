import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/signal.dart';
class ApiService {
  static final ApiService _i=ApiService._();
  factory ApiService()=>_i;
  ApiService._();
  Future<Map<String,dynamic>> getStatus() async {
    try {
      final r=await http.get(Uri.parse('\\$SERVER_URL/status')).timeout(const Duration(seconds:10));
      if(r.statusCode==200) return {...json.decode(r.body),'online':true};
      return {'online':false};
    } catch(e){return {'online':false};}
  }
  Future<StockSignal?> scanStock(String symbol,{double capital=10000.0}) async {
    try {
      final r=await http.get(Uri.parse('\\$SERVER_URL/scan?symbol=\\$symbol&capital=\\$capital')).timeout(const Duration(seconds:15));
      if(r.statusCode==200) return StockSignal.fromJson(json.decode(r.body));
      return null;
    } catch(e){return null;}
  }
}
