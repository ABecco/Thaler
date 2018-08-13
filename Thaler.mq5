//+------------------------------------------------------------------+
//|                                                       Thaler.mq5 |
//|                                               Diego Maicon Silva |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diego Maicon Silva"
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#import "shell32.dll"
int ShellExecuteW(int hwnd,string Operation,string File,string Parameters,string Directory,int ShowCmd);
#import

#include <Thaler\Tools.mqh>
Tools tools;

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

input int                horaInicio= 10;
input int                minInicio = 0;
input int                horaFim= 17;
input int                minFim = 0;
input int                Vol=5;                             // Volume de contratos negociados:    
input int                stopGain;                          // Stop Gain - Limite de Ganho:
input int                stopLoss;                          // Stop Loss - Limite de Perda:    
input string             dadosTreinamento="data.train";     // Nome Arquivo Treinamento SVM: 
input string             diretorioTreinamento="libsvm";     // Diretório do SVM:
input int                kernel_type = 1;                   // Define o tipo de função do kernel:
input int                periodoSMA = 21;                   // Periodo da medias Móveis {8, 9, 21}:
input int                periodoRSI = 14;                   // Periodo da medias Móveis {14}:
input int                periodoBB = 20;                    // Períodos da Banda de Bollinger {14,20,24}: 
input int                P_AD_OBV = 2;                      // Parâmetro A/D e OBV {1,2,3}: 
input int                P_VROC = 120;                      // Parâmetro do VROC {120,150}: 
input int                P_RSI_C = 30;                      // Parâmetro - Índice de Força Relativa - {10, 20, 30}:
input int                P_RSI_V = 70;                      // Parâmetro - Índice de Força Relativa - {70, 80, 90}:
input int                P_ST_C = 20;                       // Parâmetro - Estocástico - (10, 15, 20}:
input int                P_ST_V = 80;                       // Parâmetro - Estocástico - {80, 85, 90}:
input string             caminhoSVM= "C:\\libsvm\\";
input int                trainSize = 10000;                 // Temanho da amostra treinamento:
input int                qtdSinais = 6;                     // Quantidades de sinais atívos:
input bool               backtest;                          // Habilitra Testador de Estratégia:
input bool               estrategiaSVM;                     // Utilizando SVM.
input double              Number_DesviosBB=2;
#define NUMERO_MAGICO_EXPERT  988018119;

input int macd1=12;
input int macd2=26;
input int macd3=9;

input int stoch1=8;
input int stoch2=5;
input int stoch3=5;

input int TrailingStopDistance=1;
input int SL_moviment=6;
bool ja_moveu=false;


enum ENUM_TRADE {COMPRAR,VENDER};

datetime    New_Time;

int         sinal=1,contVenda=0,contCompra=0;
int         tempTrain=0;
bool        svmTreinada=false;
bool        Opn_Compra,Opn_Venda;
int         tickets[];
int         mesCorrente=0;
bool        posicaoAberta=false;
string      simboloTrain="";
string      simboloOperacao="";

int hSma_T,hSma_O = INVALID_HANDLE;
int hEma_T,hEma_O = INVALID_HANDLE;
int hCo_T,hCo_O=INVALID_HANDLE;
int hVroc_T,hVroc_O=INVALID_HANDLE;
int hAO_T,hAO_O=INVALID_HANDLE;
int hWilliamsR_T,hWilliamsR_O=INVALID_HANDLE;
int hRsi_T,hRsi_O=INVALID_HANDLE;
int hStochastic_T,hStochastic_O=INVALID_HANDLE;
int hBB_T,hBB_O = INVALID_HANDLE;
int hAD_T,hAD_O = INVALID_HANDLE;
int hOBV_T,hOBV_O=INVALID_HANDLE;
int hMACD_T,hMACD_O = INVALID_HANDLE;
int hHILO_T,hHILO_O = INVALID_HANDLE;
MqlDateTime targetTime;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   New_Time=0;

   if(backtest)
     {
      simboloTrain="WDO$N";
      simboloOperacao="WDO$N";
        }else{
      simboloTrain="WDO$N";
      simboloOperacao=_Symbol;
     }

   indTrain();
   indOperando();

   TimeToStruct(TimeCurrent(),targetTime);
   mesCorrente=targetTime.mon;

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void indTrain()
  {

   hSma_T = iMA(simboloTrain, _Period, periodoSMA, 0,MODE_SMA,PRICE_CLOSE);
   hEma_T = iMA(simboloTrain, _Period, periodoSMA, 0,MODE_EMA,PRICE_CLOSE);
   hCo_T=iChaikin(simboloTrain,_Period,3,10,MODE_EMA,VOLUME_TICK);
   hVroc_T=iCustom(simboloTrain,_Period,"\\Examples\\VROC",14,VOLUME_TICK);
   hAO_T=iAO(simboloTrain,_Period);
   hMACD_T=iMACD(simboloTrain,_Period,macd1,macd2,macd3,PRICE_CLOSE);
   hWilliamsR_T=iWPR(simboloTrain,_Period,periodoSMA);

   hRsi_T=iRSI(simboloTrain,_Period,periodoRSI,PRICE_CLOSE);

   hStochastic_T=iStochastic(simboloTrain,_Period,stoch1,stoch2,macd3,MODE_EMA,STO_LOWHIGH);

   hBB_T=iBands(simboloTrain,_Period,periodoBB,0,Number_DesviosBB,PRICE_CLOSE);

   hAD_T = iCustom(simboloTrain, _Period,"\\Examples\\AD",VOLUME_TICK);
   hAD_T = iCustom(simboloTrain, _Period,"\\Examples\\OBV",VOLUME_TICK);
   /*
   hHILO_T=iCustom(simboloTrain,_Period,"hilo",periodoSMA,MODE_EMA);
  */
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void indOperando()
  {
   hSma_T=iMA(simboloTrain,_Period,periodoSMA,0,MODE_SMA,PRICE_CLOSE);
   hEma_T=iMA(simboloTrain,_Period,periodoSMA,0,MODE_EMA,PRICE_CLOSE);
   hCo_T=iChaikin(simboloTrain,_Period,3,10,MODE_EMA,VOLUME_TICK);
   hVroc_T=iCustom(simboloTrain,_Period,"\\Examples\\VROC",14,VOLUME_TICK);
   hAO_T=iAO(simboloTrain,_Period);
   hMACD_T=iMACD(simboloTrain,_Period,macd1,macd2,macd3,PRICE_CLOSE);
   hWilliamsR_T=iWPR(simboloTrain,_Period,periodoSMA);

   hRsi_T=iRSI(simboloTrain,_Period,periodoRSI,PRICE_CLOSE);

   hStochastic_T=iStochastic(simboloTrain,_Period,stoch1,stoch2,macd3,MODE_EMA,STO_LOWHIGH);

   hBB_T=iBands(simboloTrain,_Period,periodoBB,0,Number_DesviosBB,PRICE_CLOSE);

   hAD_T = iCustom(simboloTrain, _Period,"\\Examples\\AD",VOLUME_TICK);
   hAD_T = iCustom(simboloTrain, _Period,"\\Examples\\OBV",VOLUME_TICK);
   /*
   hHILO_T=iCustom(simboloTrain,_Period,"hilo",periodoSMA,MODE_EMA);
  */
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   if(estrategiaSVM)
     {
      if(backtest)
        {
         if(tempTrain==trainSize)
           {
            if(Train())
              {
               Print("MÁQUINA TREINADA !!");
               svmTreinada=true;
              }
            else
              {
               Print("ERRO TREINAMENTO !!");
               return;
              }
           }
         tempTrain++;

         TimeToStruct(TimeCurrent(),targetTime);

         if(tempTrain>trainSize)
           {
            if(targetTime.mon!=mesCorrente)
              {
               if(Train())
                 {
                  Print("MÁQUINA TREINADA !!");
                  svmTreinada = true;
                  mesCorrente = targetTime.mon;
                 }
               else
                 {
                  Print("ERRO TREINAMENTO !!");
                  return;
                 }
              }
           }
           }else{
         Train();
        }

      if(svmTreinada)
        {
         if(New_Time!=iTime(Symbol(),0,0))
           { // executa uma declaração se um novo candle  criada no período de gráfico atual
            New_Time=iTime(Symbol(),0,0);   // restaura a variável New_Time para o tempo da barra atual
            OnBarSVM();             // chama a função OnBar ()
           }
        }

        }else {
      if(New_Time!=iTime(Symbol(),0,0))
        { // executa uma declaração se um novo candle  criada no período de gráfico atual
         New_Time=iTime(Symbol(),0,0);   // restaura a variável New_Time para o tempo da barra atual
         OnBarNoSVM();             // chama a função OnBar ()
        }
     }
   if(PositionSelect(_Symbol)==true)
     {
    
      double TraderTick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

      //Trailing Stop
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         double PositionTP=PositionGetDouble(POSITION_TP);
         double PositionSL=PositionGetDouble(POSITION_SL);
         double PriceCurrent=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

         if((PriceCurrent-PositionSL)>=(stopLoss*TraderTick+TrailingStopDistance*TraderTick))
           {

            request.action=TRADE_ACTION_SLTP;
            request.position=PositionGetInteger(POSITION_TICKET);
            request.symbol=_Symbol;
            request.magic=NUMERO_MAGICO_EXPERT;
            request.sl=PositionSL + (TrailingStopDistance*TraderTick);
            request.tp=PositionGetDouble(POSITION_TP);
            OrderSend(request,result);

            if((result.retcode==TRADE_RETCODE_PLACED || result.retcode==TRADE_RETCODE_DONE))
              {

               Print("Execução realizada com sucesso");
              }
            else
              {
               Print("Error Trailing Stop de Compra",GetLastError());

              }

           }

        }
      else
        {
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
           {
            double PositionTP=PositionGetDouble(POSITION_TP);
            double PositionSL=PositionGetDouble(POSITION_SL);
            double PriceCurrent=SymbolInfoDouble(_Symbol,SYMBOL_BID);

            if((PositionSL-PriceCurrent)>=(stopLoss*TraderTick+TrailingStopDistance*TraderTick))
              {
              if(ja_moveu == false){
               request.action=TRADE_ACTION_SLTP;
               request.position=PositionGetInteger(POSITION_TICKET);
               request.symbol=_Symbol;
               request.magic=NUMERO_MAGICO_EXPERT;
               request.sl=PositionGetDouble(POSITION_SL)-(SL_moviment*TraderTick);
               request.tp=PositionGetDouble(POSITION_TP);
              

               OrderSend(request,result);

               if((result.retcode==TRADE_RETCODE_PLACED || result.retcode==TRADE_RETCODE_DONE))
                 {

                  Print("Execução realizada com sucesso");
                 }
               else
                 {
                  Print("Error Trailing Stop de Venda",GetLastError());

                 }
                 ja_moveu==true;
                }

              }

           }
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Esta função requer símbolo monetário, cronograma e índice como um
// | Entre e retorna o tempo para essa barra.
//+------------------------------------------------------------------+
datetime iTime(string symbol,ENUM_TIMEFRAMES timeframe,int index)
  {
   datetime Time[];
   ArraySetAsSeries(Time,true);
   int copied=CopyTime(symbol,timeframe,index,1,Time);
   return(Time[0]);
  }
//+------------------------------------------------------------------+
// | Essa função é chamada sempre que uma nova troca é executada. Esta função
// | é usado para determinar se uma ordem stopLoss / takeProfit foi
// | executado e, se tiver, exclua a ordem de stopLoss / takeProfit correspondente
//+------------------------------------------------------------------+
void OnTrade()
  {
   COrderInfo order;
   CTrade trade;
   int t;
   for(int i=0;i<OrdersTotal();i++)
     {
      order.SelectByIndex(i);
      t=(int)order.Ticket();
      if(!order.Select(tickets[t]))
        {
         trade.OrderDelete(t);
        }
     }
  }
//+------------------------------------------------------------------+
// | A função OnBarNoSVM
//+------------------------------------------------------------------+
void OnBarNoSVM()
  {

   candidatoNoSVM can;

   MqlRates srcArr[];
   double SMA[],EMA[],CO[],CO_1[],VROC[],AO[],WR[],RSI[],ST[],BBI[],BBS[],AD[],OBV[],MACD[],SINGmacd[],HILO[];
   if(backtest)
     {
      CopyBuffer(hHILO_T,0,0,1,HILO);
      CopyBuffer(hSma_T,0,0,4,SMA);
      CopyBuffer(hEma_T,0,0,4,EMA);
      CopyBuffer(hCo_T,0,0,3,CO);
      CopyBuffer(hVroc_T,0,0,1,VROC);
      CopyBuffer(hAO_T,0,0,2,AO);
      CopyBuffer(hWilliamsR_T,0,0,1,WR);
      CopyBuffer(hBB_T,1,0,2,BBI);
      CopyBuffer(hBB_T,2,0,2,BBS);
      CopyBuffer(hMACD_T,0,0,2,MACD);
      CopyBuffer(hMACD_T,1,0,2,SINGmacd);
      CopyBuffer(hAD_T,0,0,P_AD_OBV+1,AD);
      CopyBuffer(hOBV_T,0,0,P_AD_OBV+1,OBV);
      CopyRates(simboloTrain,_Period,0,5,srcArr);
      CopyBuffer(hRsi_T,0,0,1,RSI);
      CopyBuffer(hStochastic_T,0,0,1,ST);
        }else{
      CopyBuffer(hHILO_O,0,0,1,HILO);
      CopyBuffer(hSma_O,0,0,4,SMA);
      CopyBuffer(hEma_O,0,0,4,EMA);
      CopyBuffer(hCo_O,0,0,3,CO);
      CopyBuffer(hVroc_O,0,0,1,VROC);
      CopyBuffer(hAO_O,0,0,2,AO);
      CopyBuffer(hWilliamsR_O,0,0,1,WR);
      CopyBuffer(hBB_O,1,0,2,BBI);
      CopyBuffer(hBB_O,2,0,2,BBS);
      CopyBuffer(hMACD_O,0,0,2,MACD);
      CopyBuffer(hMACD_O,1,0,2,SINGmacd);
      CopyBuffer(hAD_O,0,0,P_AD_OBV+1,AD);
      CopyBuffer(hOBV_O,0,0,P_AD_OBV+1,OBV);
      CopyRates(simboloOperacao,_Period,0,5,srcArr);
      CopyBuffer(hRsi_O,0,0,1,RSI);
      CopyBuffer(hStochastic_O,0,0,1,ST);
     }
   ArraySetAsSeries(SMA,true);
   ArraySetAsSeries(EMA,true);
   ArraySetAsSeries(CO,true);
   ArraySetAsSeries(VROC,true);
   ArraySetAsSeries(AO,true);
   ArraySetAsSeries(ST,true);
   ArraySetAsSeries(RSI,true);
   ArraySetAsSeries(WR,true);
   ArraySetAsSeries(BBI,true);
   ArraySetAsSeries(BBS,true);
   ArraySetAsSeries(AD,true);
   ArraySetAsSeries(HILO,true);

   can=tools.verificaNewCandleNoSVM(SMA[0],SMA[3],EMA[0],EMA[3],CO[0],CO[1],VROC[0],P_VROC,
                                    AO[0],AO[1],WR[0],MACD[0],MACD[1],SINGmacd[0],SINGmacd[1],
                                    srcArr[0].close,srcArr[1].close,BBI[0],BBI[1],BBS[0],BBS[1],
                                    AD[0],AD[P_AD_OBV-1],srcArr[P_AD_OBV-1].close,OBV[0],OBV[P_AD_OBV-1],
                                    RSI[0],P_RSI_C,P_RSI_V,ST[0],P_ST_C,P_ST_V,HILO[0]);

   Print("Compra [ "+can.compra+" ] --Venda [ "+can.venda+" ]");
   Print("Oscilador -> "+can.oscilador+"  Tendência -> "+can.tendencia+"   Volume -> "+can.volume+"   "+SMA[0],SMA[3]);
   if(horarioTrade(horaInicio,minInicio,horaFim,minFim,TimeCurrent()))
     {
/* if (can.oscilador >= 1 && can.tendencia >= 1 && can.volume >= 1){
                  if (can.compra > can.venda){ 
                     Open_Order(COMPRAR);
                  }
                }
           */

      if(can.oscilador>=1 && can.tendencia>=1 && can.volume>=1)
        {
         if(can.venda>can.compra)
           {
            Open_Order(VENDER);
           }
        }

     }

  }
//+------------------------------------------------------------------+
// | A função OnBarSVM
//+------------------------------------------------------------------+
void OnBarSVM(void)
  {

   novoCandle candidato;
   long iSsinal=-100;

   if(PositionsTotal()==0)
     {

      MqlRates srcArr[];
      double SMA[],EMA[],CO[],CO_1[],VROC[],AO[],WR[],RSI[],ST[],BBI[],BBS[],AD[],OBV[],MACD[],SINGmacd[],HILO[];
      if(backtest)
        {
         CopyBuffer(hHILO_T,0,0,1,HILO);
         CopyBuffer(hSma_T,0,0,4,SMA);
         CopyBuffer(hEma_T,0,0,4,EMA);
         CopyBuffer(hCo_T,0,0,3,CO);
         CopyBuffer(hVroc_T,0,0,1,VROC);
         CopyBuffer(hAO_T,0,0,2,AO);
         CopyBuffer(hWilliamsR_T,0,0,1,WR);
         CopyBuffer(hBB_T,1,0,2,BBI);
         CopyBuffer(hBB_T,2,0,2,BBS);
         CopyBuffer(hMACD_T,0,0,2,MACD);
         CopyBuffer(hMACD_T,1,0,2,SINGmacd);
         CopyBuffer(hAD_T,0,0,P_AD_OBV+1,AD);
         CopyBuffer(hOBV_T,0,0,P_AD_OBV+1,OBV);
         CopyRates(simboloTrain,_Period,0,5,srcArr);
         CopyBuffer(hRsi_T,0,0,1,RSI);
         CopyBuffer(hStochastic_T,0,0,1,ST);
           }else{
         CopyBuffer(hHILO_O,0,0,1,HILO);
         CopyBuffer(hSma_O,0,0,4,SMA);
         CopyBuffer(hEma_O,0,0,4,EMA);
         CopyBuffer(hCo_O,0,0,3,CO);
         CopyBuffer(hVroc_O,0,0,1,VROC);
         CopyBuffer(hAO_O,0,0,2,AO);
         CopyBuffer(hWilliamsR_O,0,0,1,WR);
         CopyBuffer(hBB_O,1,0,2,BBI);
         CopyBuffer(hBB_O,2,0,2,BBS);
         CopyBuffer(hMACD_O,0,0,2,MACD);
         CopyBuffer(hMACD_O,1,0,2,SINGmacd);
         CopyBuffer(hAD_O,0,0,P_AD_OBV+1,AD);
         CopyBuffer(hOBV_O,0,0,P_AD_OBV+1,OBV);
         CopyRates(simboloOperacao,_Period,0,5,srcArr);
         CopyBuffer(hRsi_O,0,0,1,RSI);
         CopyBuffer(hStochastic_O,0,0,1,ST);
        }
      ArraySetAsSeries(SMA,true);
      ArraySetAsSeries(EMA,true);
      ArraySetAsSeries(CO,true);
      ArraySetAsSeries(VROC,true);
      ArraySetAsSeries(AO,true);
      ArraySetAsSeries(ST,true);
      ArraySetAsSeries(RSI,true);
      ArraySetAsSeries(WR,true);
      ArraySetAsSeries(BBI,true);
      ArraySetAsSeries(BBS,true);
      ArraySetAsSeries(AD,true);
      ArraySetAsSeries(HILO,true);

      candidato=svmTools.verificaNewCandle(SMA[0],SMA[3],EMA[0],EMA[3],CO[0],CO[1],VROC[0],P_VROC,
                                           AO[0],AO[1],WR[0],MACD[0],MACD[1],SINGmacd[0],SINGmacd[1],
                                           srcArr[0].close,srcArr[1].close,BBI[0],BBI[1],BBS[0],BBS[1],
                                           AD[0],AD[P_AD_OBV-1],srcArr[P_AD_OBV-1].close,OBV[0],OBV[P_AD_OBV-1],
                                           RSI[0],P_RSI_C,P_RSI_V,ST[0],P_ST_C,P_ST_V,HILO[0]);

      if(candidato.cont>=qtdSinais)
        {
         int file_sinal=FileOpen(diretorioTreinamento+"//"+"novoCandle.1.txt",FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
         FileWrite(file_sinal,"1"+candidato.candle);
         FileClose(file_sinal);
         Print(candidato.candle);

         int value=ShellExecuteW(0,"Open","C:\\libsvm\\svm-predict.exe ",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\libsvm\\novoCandle.1.txt "+
                                 TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\libsvm\\data.train.model "+
                                 TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\libsvm\\sinal.txt",caminhoSVM,0);
         if(value>32)
           {

            int arq_sinal=FileOpen(diretorioTreinamento+"//"+"sinal.txt",FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);

            if(arq_sinal!=INVALID_HANDLE)
              {
               //--- ler dados de um arquivo 
               iSsinal=StringToInteger(FileReadString(arq_sinal,1));
              }
            FileClose(arq_sinal);
            Print("Sinal -SVM- ",iSsinal);
           }
         if(horarioTrade(horaInicio,minInicio,horaFim,minFim,TimeCurrent()))
           {
/*if(iSsinal == 1){
                contCompra++;
                if (candidato.cont >= 3 && contCompra >= 3 ){
                   Open_Order(COMPRAR);
                }
            }
           */
            if(iSsinal==0)
              {
               contVenda++;
               if(candidato.cont>=3 && contVenda>=3)
                 {
                  Open_Order(VENDER);
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
// | Esta função é chamada para abrir um novo comércio e criar stopLoss e
// | takeProfit ordens.
//+------------------------------------------------------------------+
void Open_Order(int ordem)
  {
   MqlTradeRequest request={0};
   MqlTradeResult  result={0};

   bool orResult=false;

   double preco=0.0;
   if(ordem==COMPRAR)
     {
      request.action=TRADE_ACTION_DEAL;
      request.type=ORDER_TYPE_BUY;
      request.symbol=_Symbol;
      request.volume=Vol;
      request.magic=NUMERO_MAGICO_EXPERT;
      request.type_filling=ORDER_FILLING_FOK;

/*	Pergunte - melhor oferta de compra*/
      preco=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      request.price=preco;

      double TraderTick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

      request.sl=preco-(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*stopLoss);
      //  Print("Preço: "+ preco +" Perda: " + (SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*stopLoss));
      request.tp=preco+(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*stopGain);
      //  Print("Preço: "+preco+" Ganho: "+(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*stopGain));
      request.deviation=50;
      request.comment="Comprando.";

      orResult=OrderSend(request,result);
      //Verificando se a colocação da ordem foi bem sucedida
      if(orResult)
        {
         Print("Execução realizada com sucesso");
        }
      else
        {
         Print("Error Compra",GetLastError());

        }

     }

   if(ordem==VENDER)
     {
      //Parâmetros para abertura de uma venda 
      request.action=TRADE_ACTION_DEAL;
      request.type=ORDER_TYPE_SELL;
      request.symbol=_Symbol;
      request.volume=Vol;
      request.magic=NUMERO_MAGICO_EXPERT;
      request.type_filling=ORDER_FILLING_FOK;
      request.comment="Vendendo.";
/*Oferta de Venda*/
      preco=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      request.price=preco;

      double TraderTick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

      request.sl=preco+(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*stopLoss);
      request.tp=preco-(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*stopGain);

      request.deviation=50;


      orResult=OrderSend(request,result);
      //Verificando se a colocação da ordem foi bem sucedida
      if(orResult)
        {
         Print("Abertura de ordem de venda com  sucesso");

        }
      else
        {
         Print("Erro na abertura de uma venda",GetLastError());
        }
        ja_moveu=false;
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Train()
  {
//---
   MqlRates srcArr[];
   double StochKArr[],StochDArr[],WilliamsRArr[],SMA[],EMA[],CO[],VROC[],AO[],RSI[],BBI[],BBS[],AD[],OBV[],MACD[],SINGmacd[],HILO[];
//---
   if(backtest)
     {
      indTrain();
      int copied=CopyRates(simboloTrain,Period(),0,trainSize,srcArr);

      if(copied<0)
        {
         Print("Not enough data for "+simboloTrain);
         return false;

        }
      int trainSizeCopy=copied;
      CopyBuffer(hSma_T,0,0,trainSizeCopy,SMA);
      CopyBuffer(hEma_T,0,0,trainSizeCopy,EMA);
      CopyBuffer(hCo_T,0,0,trainSizeCopy+1,CO);
      CopyBuffer(hVroc_T,0,0,trainSizeCopy,VROC);
      CopyBuffer(hAO_T,0,0,trainSizeCopy,AO);
      CopyBuffer(hStochastic_T,0,0,trainSizeCopy,StochKArr);
      CopyBuffer(hRsi_T,0,0,trainSizeCopy,RSI);
      CopyBuffer(hWilliamsR_T,0,0,trainSizeCopy,WilliamsRArr);
      CopyBuffer(hMACD_T,0,0,trainSizeCopy,MACD);
      CopyBuffer(hMACD_T,1,0,trainSizeCopy,SINGmacd);
      CopyBuffer(hBB_T,1,0,trainSizeCopy,BBI);
      CopyBuffer(hBB_T,2,0,trainSizeCopy,BBS);
      CopyBuffer(hAD_T,0,0,trainSizeCopy,AD);
      CopyBuffer(hAD_T,0,0,trainSizeCopy,OBV);
      CopyBuffer(hHILO_T,0,0,trainSizeCopy,HILO);

      ArraySetAsSeries(srcArr,true);
      ArraySetAsSeries(SMA,true);
      ArraySetAsSeries(EMA,true);
      ArraySetAsSeries(CO,true);
      ArraySetAsSeries(VROC,true);
      ArraySetAsSeries(AO,true);
      ArraySetAsSeries(StochKArr,true);
      ArraySetAsSeries(RSI,true);
      ArraySetAsSeries(WilliamsRArr,true);
      ArraySetAsSeries(BBI,true);
      ArraySetAsSeries(BBS,true);
      ArraySetAsSeries(AD,true);
      ArraySetAsSeries(OBV,true);
      ArraySetAsSeries(HILO,true);
      int hFile=FileOpen("mt5export.csv",FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(hFile<0)
        {
         Print("Falha para abrir o arquivo pelo caminho absoluto ");
         Print("Cуdigo de erro ",GetLastError());
         return false;
        }
      else PrintFormat("Arquivo será aberto a partir %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH));

      FileWriteString(hFile,"DATE\tTIME\tCLOSE\tSMA\tSMA_3\tEMA\tEMA_3\tCO\tCO_1\tVROC\tAO\tWilliamsR\tRSI\tStochK\tBBS\tBBI\tAD\tOBV\tMACD\tSINGmacd\tHILO\n");

      int file_train=FileOpen(diretorioTreinamento+"//"+dadosTreinamento,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);

      string compra="1";
      int cont=0;
      for(int i=trainSizeCopy-5; i>0; i--)
        {
         string candleDate=TimeToString(srcArr[i].time,TIME_DATE);
         StringReplace(candleDate,".","");
         string candleTime=TimeToString(srcArr[i].time,TIME_MINUTES);
         StringReplace(candleTime,":","");

         FileWrite(hFile,candleDate,candleTime,DoubleToString(srcArr[i].close,4),
                   DoubleToString(SMA[i],4),
                   DoubleToString(SMA[i+3],4),
                   DoubleToString(EMA[i],4),
                   DoubleToString(EMA[i+3],4),
                   DoubleToString(CO[i],4),
                   DoubleToString(CO[i+1],4),
                   DoubleToString(VROC[i],4),
                   DoubleToString(AO[i],4),
                   DoubleToString(MACD[i],4),
                   DoubleToString(SINGmacd[i],4),
                   DoubleToString(WilliamsRArr[i],4),
                   DoubleToString(RSI[i],4),
                   DoubleToString(StochKArr[i],4),
                   DoubleToString(BBS[i],4),
                   DoubleToString(BBI[i],4),
                   DoubleToString(AD[i],4),
                   DoubleToString(OBV[i],4),
                   DoubleToString(HILO[i],4)
                   );

         if(svmTools.IsCompraSMA21(SMA[i],SMA[i+2]))
           {
            compra+=" 1:1";
            cont++;
           }
         if(svmTools.IsCompraEMA21(EMA[i],EMA[i+2]))
           {
            compra+=" 2:1";
            cont++;
           }
         if(svmTools.IsCompraCO(CO[i],CO[i+1]))
           {
            compra+=" 3:1";
            cont++;
           }
         if(svmTools.IsCompraVROC(VROC[i],P_VROC))
           {
            compra+=" 4:1";
            cont++;
           }
         if(svmTools.IsCompraAO(AO[i],AO[i+1]))
           {
            compra+=" 5:1";
            cont++;
           }
         if(svmTools.IsCompraWR(WilliamsRArr[i]))
           {
            compra+=" 6:1";
            cont++;
           }
         if(svmTools.IsCompraMACD(MACD[i],MACD[i+1],SINGmacd[i],SINGmacd[i+1]))
           {
            compra+=" 7:1";
            cont++;
           }
         if(svmTools.IsCompraBB(srcArr[i].close,srcArr[i+1].close,BBI[i],BBI[i+1]))
           {
            compra+=" 8:1";
            cont++;
           }

         if(svmTools.IsCompraAD(AD[i],AD[i+P_AD_OBV],srcArr[i].close,srcArr[i+1].close))
           {
            compra+=" 9:1";
            cont++;
           }

         if(svmTools.IsCompraOBV(OBV[i],OBV[i+P_AD_OBV],srcArr[i].close,srcArr[i+1].close))
           {
            compra+=" 10:1";
            cont++;
           }

         if(svmTools.IsCompraRSI(RSI[i],P_RSI_C))
           {
            compra+=" 11:1";
            cont++;
           }
         if(svmTools.IsCompraST(StochKArr[i],P_ST_C))
           {
            compra+=" 12:1";
            cont++;
           }

/*if (svmTools.IsCompraHILO(HILO[i],srcArr[i].close)){  
                         compra +=" 13:1";
                         cont++;
               } */
         if(StringLen(compra)>1 && cont>=4)
           {
            FileWrite(file_train,""+compra);
           }

         compra="1";
         cont=0;
        }

      string venda="0";
      cont=0;
      for(int i=trainSizeCopy-5; i>0; i--)
        {
         if(svmTools.IsVendaSMA21(SMA[i],SMA[i+2]))
           {
            venda+=" 14:1";
            cont++;
           }
         if(svmTools.IsVendaEMA21(EMA[i],EMA[i+2]))
           {
            venda+=" 15:1";
            cont++;
           }
         if(svmTools.IsVendaCO(CO[i],CO[i+1]))
           {
            venda+=" 16:1";
            cont++;
           }
         if(svmTools.IsVendaVROC(VROC[i],P_VROC))
           {
            venda+=" 17:1";
            cont++;
           }
         if(svmTools.IsVendaAO(AO[i],AO[i+1]))
           {
            venda+=" 18:1";
            cont++;
           }
         if(svmTools.IsVendaWR(WilliamsRArr[i]))
           {
            venda+=" 19:1";
            cont++;
           }
         if(svmTools.IsVendaMACD(MACD[i],MACD[i+1],SINGmacd[i],SINGmacd[i+1]))
           {
            venda+=" 20:1";
            cont++;
           }
         if(svmTools.IsVendaBB(srcArr[i].close,srcArr[i+1].close,BBS[i],BBS[i+1]))
           {
            venda+=" 21:1";
            cont++;
           }
         if(svmTools.IsVendaAD(AD[i],AD[i+P_AD_OBV],srcArr[i].close,srcArr[i+1].close))
           {
            venda+=" 22:1";
            cont++;
           }

         if(svmTools.IsVendaOBV(OBV[i],OBV[i+P_AD_OBV],srcArr[i].close,srcArr[i+1].close))
           {
            venda+=" 23:1";
            cont++;
           }
         if(svmTools.IsVendaRSI(RSI[i],P_RSI_V))
           {
            venda+=" 24:1";
            cont++;
           }
         if(svmTools.IsVendaST(StochKArr[i],P_ST_V))
           {
            venda+=" 25:1";
            cont++;
           }
/*
               if (svmTools.IsVendaHILO(HILO[i],srcArr[i].close)){  
                         venda +=" 26:1";
                         cont++;
               }   */
         if(StringLen(venda)>1 && cont>=4)
           {
            FileWrite(file_train,""+venda);
           }

         venda="0";
         cont=0;
        }

      FileClose(hFile);
      FileClose(file_train);
      Print("Dados Exportados com Sucesso !!.");

      int value=ShellExecuteW(0,"Open","C:\\libsvm\\svm-train.exe "," -t "+IntegerToString(kernel_type)+" -c 100 "+TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\libsvm\\"+dadosTreinamento,caminhoSVM,5);
      if(value>32)
         Print("Treinado com Sucesso !! Return -> ",value);
      return true;
     }
   else
      return false;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool horarioTrade(int aStartHour,int aStartMinute,int aStopHour,int aStopMinute,datetime aTimeCur)
  {
//--- hora de início da sessão
   int StartTime=3600*aStartHour+60*aStartMinute;
//--- tempo de término da sessão
   int StopTime=3600*aStopHour+60*aStopMinute;
//---hora atual em segundos desde o início do dia
   aTimeCur=aTimeCur%86400;
   if(StopTime<StartTime)
     {
      //--- passando a meia-noite
      if(aTimeCur>=StartTime || aTimeCur<StopTime)
        {
         return(true);
        }
     }
   else
     {
      //--- within one day
      if(aTimeCur>=StartTime && aTimeCur<StopTime)
        {
         return(true);
        }
     }
   return(false);
  }
//+------------------------------------------------------------------+
