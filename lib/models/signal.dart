class StockSignal {
final String symbol,signal,candle;
final int confidence;
final double price,rsi,volRatio;
final bool emaBullish,aboveVwap,macdBull,extended,sectorWeak;
final DateTime scannedAt;
StockSignal({required this.symbol,required this.signal,required this.confidence,
  required this.price,required this.rsi,required this.volRatio,
  required this.emaBullish,required this.aboveVwap,required this.candle,
  required this.macdBull,this.extended=false,this.sectorWeak=false,DateTime? scannedAt})
  :scannedAt=scannedAt??DateTime.now();
factory StockSignal.fromJson(Map<String,dynamic> j)=>StockSignal(
  symbol:j['symbol']??'',signal:j['signal']??'AVOID',
  confidence:(j['confidence']??0).toInt(),price:(j['price']??0.0).toDouble(),
  rsi:(j['rsi']??0.0).toDouble(),volRatio:(j['volRatio']??0.0).toDouble(),
  emaBullish:j['emaBullish']??false,aboveVwap:j['aboveVwap']??false,
  candle:j['candle']??'',macdBull:j['macdBull']??false,
  extended:j['extended']??false,sectorWeak:j['sectorWeak']??false);
bool get isBuy=>signal=='BUY';
bool get isShort=>signal=='SHORT';
bool get isAvoid=>signal=='AVOID';
String get signalEmoji=>isBuy?'📈':isShort?'📉':'⚪';
double get stopLoss=>isBuy?price*0.985:price*1.015;
double get target=>isBuy?price*1.03:price*0.97;
          }
