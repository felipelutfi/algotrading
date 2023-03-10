//+------------------------------------------------------------------+
//|                                                   media_21_9.mq5 |
//|                                                     Felipe Lutfi |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Felipe Lutfi"
#include <Trade/SymbolInfo.mqh>

input ENUM_TIMEFRAMES TimeFrame = PERIOD_M15;
input double Volume = 1.0;
input string HoraInicial = "9:15";
input string HoraFechamento = "17:45";
input string HoraFinal = "17:30";
input double stop_loss_operacao = 250.0;
input double stop_gain_operacao = 50.0;
input int media_longa = 21;
input int media_curta = 9;

int handle_media_longa;
int handle_media_curta;
int magic_number = 1234;
int trades;

CSymbolInfo simbolo;

MqlTradeRequest request;
MqlTradeResult result;
MqlTradeCheckResult check_result;

MqlDateTime hora_inicial, hora_final, hora_fechamento;

static int bars;

enum ENUM_SINAL {COMPRA = 1, VENDA = -1, NULO = 0};

ENUM_SINAL ultimo_sinal;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   
   if(!simbolo.Name(_Symbol)){
         
         Print("Erro ao carregar o ativo");
         return INIT_FAILED;
     
   }

   handle_media_curta = iMA(_Symbol, TimeFrame, media_curta, 0, MODE_EMA, PRICE_CLOSE);
   handle_media_longa = iMA(_Symbol, TimeFrame, media_longa, 0, MODE_EMA, PRICE_CLOSE);
   
   TimeToStruct(StringToTime(HoraInicial), hora_inicial);
   TimeToStruct(StringToTime(HoraFinal), hora_final);
   TimeToStruct(StringToTime(HoraFechamento), hora_fechamento);
   
   ultimo_sinal = NULO;

   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
   printf("Reiniciando EA: %d", reason);
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
   if(!simbolo.RefreshRates()){
   
      return;
     
   }
   
   MqlDateTime hora_atual;
   TimeToStruct(TimeCurrent(), hora_atual);
   
   if (IsNovoDia()){
     
      ultimo_sinal = NULO;
      datetime last_time = TimeCurrent();
   
      MqlDateTime time;
      TimeToStruct(last_time, time);
     
      trades = 0;
     
      Print("Robô Ligado");      
           
   }
   
   if (ultimo_sinal == NULO)
      ultimo_sinal = CheckSinal();
   
   bool novo_candle = IsNovoCandle();
           
   if (novo_candle){
     
      ENUM_SINAL sinal = CheckSinal();
     
      CheckNovaEntrada(sinal);
     
      CheckHorarioFechamento();
     
   }
   
}

bool IsNovoDia(){

   static datetime OldDay = 0;
   
   MqlRates mrate[];    
   ArraySetAsSeries(mrate,true);      
   CopyRates(_Symbol,TimeFrame,0,2,mrate);
   
   datetime lastbar_time = mrate[0].time;
 
   
   MqlDateTime time;
   TimeToStruct(lastbar_time, time);
   
   if(OldDay < time.day_of_year)
   {
      OldDay = time.day_of_year;
      return true;
   }
   
   return false;

}

void CheckHorarioFechamento(){

   if(IsHorarioFechamento())
   {
      if(IsPosicionado()) {
         Print("Horário limite atingido. Encerrando posições abertas");
         FecharPosicao();
      }
   }
}

bool IsHorarioFechamento(){

   MqlDateTime hora_atual;
   TimeToStruct(TimeCurrent(), hora_atual);
   
   if (hora_atual.hour > hora_fechamento.hour)
      return true;
   
   if ((hora_atual.hour == hora_fechamento.hour) && (hora_atual.min >= hora_fechamento.min))
      return true;

   return false;

}

void CheckNovaEntrada(ENUM_SINAL sinal){

   if (IsHorarioPermitido() && !IsPosicionado())
    {
      if (sinal == COMPRA)
      {
         
         trades += 1;
         Print("Abrindo Compra");
         bool op = Comprar();
                 
         if (op)
            ultimo_sinal = COMPRA;
           
      }
      else if (sinal == VENDA)
      {

         trades += 1;
         Print("Abrindo Venda");
         bool op = Vender();
         
         if (op)
            ultimo_sinal = VENDA;
      }
   
    }
 
}

bool IsNovoCandle(){

   if(bars != Bars(_Symbol, _Period)){
     
      bars = Bars(_Symbol, _Period);
      return true;
   
   }
   
   return false;

}

bool IsHorarioPermitido(){

   MqlDateTime hora_atual;
   TimeToStruct(TimeCurrent(), hora_atual);
     
   if (hora_atual.hour >= hora_inicial.hour && hora_atual.hour <= hora_final.hour)
   {
      if ((hora_inicial.hour == hora_final.hour)
            && (hora_atual.min >= hora_inicial.min) && (hora_atual.min <= hora_final.min))
         return true;
   
      if (hora_atual.hour == hora_inicial.hour)
      {
         if (hora_atual.min >= hora_inicial.min)
            return true;
         else
            return false;
      }
     
      if (hora_atual.hour == hora_final.hour)
      {
         if (hora_atual.min <= hora_final.min)
            return true;
         else
            return false;
      }
     
      return true;
   }
   
   return false;

}

bool Comprar(){
   
   ZerarRequest();
   
   double stop_loss = (simbolo.Ask() - stop_loss_operacao);
   double take_profit = (simbolo.Ask() + stop_gain_operacao);
   
   request.action = TRADE_ACTION_DEAL;
   request.magic = magic_number;
   request.symbol = _Symbol;
   request.volume = Volume;
   request.price = simbolo.Ask();
   request.sl = stop_loss;
   request.tp = take_profit;
   request.type = ORDER_TYPE_BUY;
   request.type_filling = ORDER_FILLING_RETURN;
   request.comment = "Compra";
   
   return EnviarRequisicao();

}

bool Vender(){

   ZerarRequest();
   
   double stop_loss = (simbolo.Bid() + stop_loss_operacao);
   double take_profit = (simbolo.Bid() - stop_gain_operacao);
   
   request.action = TRADE_ACTION_DEAL;
   request.magic = magic_number;
   request.symbol = _Symbol;
   request.volume = Volume;
   request.price = simbolo.Bid();
   request.sl = stop_loss;
   request.tp = take_profit;
   request.type = ORDER_TYPE_SELL;
   request.type_filling = ORDER_FILLING_RETURN;
   request.comment = "Venda";
   
   return EnviarRequisicao();

}

void ZerarRequest(){

   ZeroMemory(request);
   ZeroMemory(result);
   ZeroMemory(check_result);

}

bool EnviarRequisicao(){

   ResetLastError();
   
   PrintFormat("Request - %s, VOLUME: %.0f, PRICE: %.2f, SL: %.2f, TP: %.2f", request.comment, request.volume, request.price, request.sl, request.tp);
   
   if(!OrderCheck(request, check_result))
   {
      PrintFormat("Erro em OrderCheck: %d - Código: %d", GetLastError(), check_result.retcode);
      return false;
   }
   
   if(!OrderSend(request, result))
   {
      PrintFormat("Erro em OrderSend: %d - Código: %d", GetLastError(), result.retcode);
      return false;
   }
   
   return true;
   
}

ENUM_SINAL CheckSinal(){

   double media_curta_buffer[];
   CopyBuffer(handle_media_curta, 0, 0, 2, media_curta_buffer);
   ArraySetAsSeries(media_curta_buffer, true);
     
   double media_longa_buffer[];
   CopyBuffer(handle_media_longa, 0, 0, 2, media_longa_buffer);
   ArraySetAsSeries(media_longa_buffer, true);
     
   if((media_curta_buffer[0] > media_longa_buffer[0]) && (media_curta_buffer[1] < media_longa_buffer[1]) && (!IsComprado()))
      return COMPRA;
     
   if((media_curta_buffer[0] < media_longa_buffer[0]) && (media_curta_buffer[1] > media_longa_buffer[1]) && (!IsVendido()))
      return VENDA;
   
   
   return NULO;

}

void FecharPosicao(){
   
   if(!PositionSelect(_Symbol))
      return;
     
    ZerarRequest();
   
    double volume_fechamento = PositionGetDouble(POSITION_VOLUME);
 
    request.action = TRADE_ACTION_DEAL;
    request.magic = magic_number;
    request.symbol = _Symbol;
    request.volume = volume_fechamento;
    request.type_filling = ORDER_FILLING_RETURN;
    request.comment = "Fechando posição";
   
    long tipo = PositionGetInteger(POSITION_TYPE);
   
   if(tipo == POSITION_TYPE_BUY)
   {
      request.price = simbolo.Bid();
      request.type = ORDER_TYPE_SELL;
   }
   else
   {
      request.price = simbolo.Ask();
      request.type = ORDER_TYPE_BUY;
   }
   
   EnviarRequisicao();
   
}

bool IsPosicionado(){

   return PositionSelect(_Symbol);

}

bool IsComprado(){

   if(!PositionSelect(_Symbol))
      return false;
     
   return PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;

}

bool IsVendido(){

   if(!PositionSelect(_Symbol))
      return false;
   
   return PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL;

}