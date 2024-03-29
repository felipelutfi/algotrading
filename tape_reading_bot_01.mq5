//+------------------------------------------------------------------+
//|                                          tape_reading_bot_01.mq5 |
//|                                                     Felipe Lutfi |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Felipe Lutfi"
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/SymbolInfo.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Trade\Trade.mqh>
CTrade ExtTrade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

input ENUM_TIMEFRAMES TimeFrame = PERIOD_M5;
input double Volume = 1.0;
input string HoraInicial = "9:15";
input string HoraFechamento = "18:00";
input string HoraFinal = "17:55";
input double stop_gain_operacao = 5.0;
input double stop_loss_operacao = 5.0;
input int stop_loss_diario = -100;
input int take_profit_diario = 50;

int trades;
int magic_number = 1234;
int buy_seguidos;
int sell_seguidos;
int direto_seguidos;
int buy_volume;
int sell_volume;
int counter;
int qtd_ticks;
double saldo_inicio_dia;
bool can_trade;
double preco_entrada;
bool modificado;

CArrayDouble volumes_compra;
CArrayDouble volumes_venda;
CArrayDouble precos_compra;
CArrayDouble precos_venda;

double volumes_compra_array[40];
double volumes_venda_array[40];
double volume_max_venda;
double volume_max_compra;


CSymbolInfo simbolo;

MqlTradeRequest request;
MqlTradeResult result;
MqlTradeCheckResult check_result;

MqlDateTime hora_inicial, hora_final, hora_fechamento;

static int bars;

enum ENUM_SINAL {COMPRA = 1, VENDA = -1, NULO = 0};

ENUM_SINAL ultimo_sinal;


int OnInit()
  {
   
    if(!simbolo.Name("WDOJ23")){
         
         Print("Erro ao carregar o ativo");
         return INIT_FAILED;
     
   }
   
   TimeToStruct(StringToTime(HoraInicial), hora_inicial);
   TimeToStruct(StringToTime(HoraFinal), hora_final);
   TimeToStruct(StringToTime(HoraFechamento), hora_fechamento);
   
   buy_seguidos = 0;
   sell_seguidos = 0;
   buy_volume = 0;
   sell_volume = 0;
   
   MarketBookAdd(_Symbol);
   
   EventSetTimer(1);

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
    
   TimesTrades();

   if(!simbolo.RefreshRates()){
   
      return;
     
   }
   
   if (IsNovoDia()){
   
      saldo_inicio_dia = AccountInfoDouble(ACCOUNT_BALANCE);
      
      trades = 0;
      counter = 0;
      
      can_trade = true;

      ultimo_sinal = NULO;

      Print("Novo Dia");      
           
   }
   
   if (ultimo_sinal == NULO)
     ultimo_sinal = CheckSinal();
   
   bool novo_candle = IsNovoCandle();
   
  }

bool IsNovoDia(){

   static datetime OldDay = 0;
   
   MqlRates mrate[];    
   ArraySetAsSeries(mrate,true);      
   CopyRates("WDOJ23",TimeFrame,0,2,mrate);
   
   datetime lastbar_time = mrate[0].time;
   
   MqlDateTime time;
   TimeToStruct(lastbar_time, time);
   
   if((OldDay < time.day_of_year))
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

   if(bars != Bars("WDOJ23", _Period)){
     
      bars = Bars("WDOJ23", _Period);
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
   
   modificado = false;
   
   preco_entrada = simbolo.Ask();

   request.action = TRADE_ACTION_DEAL;
   request.magic = magic_number;
   request.symbol = "WDOJ23";
   request.volume = Volume;
   request.price = simbolo.Ask();
   request.tp = take_profit;
   request.sl = stop_loss;
   request.type = ORDER_TYPE_BUY;
   request.type_filling = ORDER_FILLING_RETURN;
   request.comment = "Compra";
   
   return EnviarRequisicao();

}

bool Vender(){

   ZerarRequest();
   
   double stop_loss = (simbolo.Bid() + stop_loss_operacao);
   double take_profit = (simbolo.Bid() - stop_gain_operacao);
   
   modificado = false;
   
   preco_entrada = simbolo.Bid();

   request.action = TRADE_ACTION_DEAL;
   request.magic = magic_number;
   request.symbol = "WDOJ23";
   request.volume = Volume;
   request.price = simbolo.Bid();
   request.tp = take_profit;
   request.sl = stop_loss;
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



void FecharPosicao(){

   if(!PositionSelect("WDOJ23"))
      return;
     
    ZerarRequest();
   
    double volume_fechamento = PositionGetDouble(POSITION_VOLUME);
         
    request.action = TRADE_ACTION_DEAL;
    request.magic = magic_number;
    request.symbol = "WDOJ23";
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

   return PositionSelect("WDOJ23");

}

bool IsComprado(){

   if(!PositionSelect("WDOJ23"))
      return false;
     
   return PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;

}

bool IsVendido(){

   if(!PositionSelect("WDOJ23"))
      return false;
   
   return PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL;

}

ENUM_SINAL CheckSinal(){
 
   if((((buy_seguidos*100)/qtd_ticks) > ((sell_seguidos*100)/qtd_ticks)) && (qtd_ticks >= 200) && ((buy_volume - sell_volume) > 1000) && (trades == 0) && (can_trade == true) && (!IsComprado()))
      return COMPRA;
    
   if((((buy_seguidos*100)/qtd_ticks) < ((sell_seguidos*100)/qtd_ticks)) && (qtd_ticks >= 200) && ((buy_volume - sell_volume) < -1000) && (trades == 0) && (can_trade == true) && (!IsVendido()))
      return VENDA;
  
   return NULO;
 
}

void OnTimer(){
   
   GetBook();  
   
   if(((AccountInfoDouble(ACCOUNT_PROFIT)) >= 25) && (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) && (modificado == false)){
         
         Print("Modificando stop loss");
         modificado = true;
         ExtTrade.PositionModify(PositionGetTicket(0), preco_entrada, (preco_entrada + 5.0));
     
   }  
     
   if(((AccountInfoDouble(ACCOUNT_PROFIT)) >= 25) && (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) && (modificado == false)){
         
         Print("Modificando stop loss");
         modificado = true;
         ExtTrade.PositionModify(PositionGetTicket(0), preco_entrada, (preco_entrada - 5.0));

     
   } 
   
   if (qtd_ticks != 0){
   
      ENUM_SINAL sinal = CheckSinal();
   
      CheckNovaEntrada(sinal);
   
      CheckHorarioFechamento();
   
   }
   
   if((trades > 0) && (counter < 600)){
   
      counter += 1;
   
   }
   
   if((trades > 0) && (counter >= 600)){
   
      trades = 0;
      counter = 0;
   
   }
   
   if((IsPosicionado()) && ((AccountInfoDouble(ACCOUNT_BALANCE) - saldo_inicio_dia) + AccountInfoDouble(ACCOUNT_PROFIT) >= take_profit_diario)){
   
      FecharPosicao();
      can_trade = false; 
      Print("Limite de lucro diário atingido");
   
   }
   
   if((IsPosicionado()) && ((AccountInfoDouble(ACCOUNT_BALANCE) - saldo_inicio_dia) + AccountInfoDouble(ACCOUNT_PROFIT) <= stop_loss_diario)){
   
      FecharPosicao();
      can_trade = false; 
      Print("Limite de prejuízo diário atingido");
   
   }
   
   if ((!IsPosicionado()) && (AccountInfoDouble(ACCOUNT_BALANCE) - saldo_inicio_dia) >= (take_profit_diario - 5)){

      can_trade = false; 
      Print("Limite de lucro diário atingido");
   
   }
   
   if ((!IsPosicionado()) && (AccountInfoDouble(ACCOUNT_BALANCE) - saldo_inicio_dia) <= (stop_loss_diario - 5)){

      can_trade = false; 
      Print("Limite de prejuízo diário atingido");
   
   }

   Print("");
   
   if ((qtd_ticks != 0) && (can_trade == true)){
      
      Print("DOLAR");
      Print("Proporção compra: ", ((buy_seguidos*100)/qtd_ticks), "%");
      Print("Proporção venda: ", ((sell_seguidos*100)/qtd_ticks), "%");
      Print("Proporção diretos: ", ((direto_seguidos*100)/qtd_ticks), "%");
   
   }
   
   if(can_trade == true){

      Print("Posições compradas: ", buy_volume, " contratos");
      Print("Posições vendidas: ", sell_volume, " contratos");
      Print("Saldo das posições: ", buy_volume - sell_volume, " contratos" );
      Print("Possível Resistência: ", volume_max_venda, " a ", precos_venda.At(ArrayMaximum(volumes_venda_array, 0, 19)));
      Print("Possível Suporte: ", volume_max_compra, " a ", precos_compra.At(ArrayMaximum(volumes_compra_array, 0, 19)));
      Print("Contador: ", counter);
      Print("Trades: ", trades);
      Print("Can Trade: ", can_trade);
      
      Print(iTime(_Symbol, PERIOD_M1, 0));
      Print("Quantidade de operações nos últimos 10 minutos: ", qtd_ticks);
   
   }
   
   
}

void TimesTrades(){
   
   MqlTick ticks[];
   
   buy_seguidos = 0;
   sell_seguidos = 0;
   direto_seguidos = 0;
   buy_volume = 0;
   sell_volume = 0;
   qtd_ticks = 0;
   
   ulong stop = (ulong) TimeCurrent() * 1000;
   ulong start = (ulong) iTime(_Symbol, PERIOD_M1, 10) * 1000;
   
   int ok = CopyTicksRange(_Symbol, ticks, COPY_TICKS_TRADE, start, stop);
   //int ok = CopyTicks(_Symbol, ticks, COPY_TICKS_TRADE, 0, order_flow);
 
   if(ok != -1){
   
      for(int i=0;i<ArraySize(ticks);i++){
      
         string tipo;
         if(ticks[i].flags == 120){
         
            tipo = "DIRETO";
            direto_seguidos += 1;
            qtd_ticks += 1;
            
         }
         
         
         if(ticks[i].flags == 56){
         
            tipo = "COMPRA";
            buy_seguidos += 1;
            buy_volume += ticks[i].volume;
            qtd_ticks += 1;
            
         }
         
         if(ticks[i].flags == 88){
         
            tipo = "VENDA";
            sell_seguidos += 1;
            sell_volume += ticks[i].volume;
            qtd_ticks += 1;
         
         }
         
         
         //Print("Tick - Hora = ", ticks[i].time, " - Flag = ", ticks[i].flags, ", Ask = ", ticks[i].ask, ", Bid = ", ticks[i].bid, ", Last = ", ticks[i].last, ", Volume = ", ticks[i].volume, ", Tipo = ", tipo);
         
      }
   
 
   }else{
      
         Print("Não foi possível carregar o times and trades");
      
   }


   
 }
 
 void GetBook(){

   MqlBookInfo priceArray[];
   
   bool getBook=MarketBookGet(NULL,priceArray);

   
   if(getBook)
     {
      int size=ArraySize(priceArray);
      for(int i=0;i<size;i++)
        {
   
         string tipo;
         if(priceArray[i].type == 2){
         
            tipo = "COMPRA";
            volumes_compra.Add(priceArray[i].volume_real);
            precos_compra.Add(priceArray[i].price);
            volumes_compra_array[i-20] = priceArray[i].volume_real;
            
         }
         
         if(priceArray[i].type == 1){
         
            tipo = "VENDA";
            volumes_venda.Add(priceArray[i].volume_real);
            precos_venda.Add(priceArray[i].price);
            volumes_venda_array[i] = priceArray[i].volume_real;

            
         }

         //Print("Preço: ", priceArray[i].price
               //+"    Volume = "+priceArray[i].volume_real,
               //" tipo = ", tipo);
               

        }
        
        
     }
   else
     {
      Print("Could not get contents of the symbol DOM ",Symbol());
     }
     
   volume_max_venda = volumes_venda.At(volumes_venda.Maximum(0, WHOLE_ARRAY));
   volume_max_compra = volumes_compra.At(volumes_compra.Maximum(0, WHOLE_ARRAY));
  
}