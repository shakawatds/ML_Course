//+------------------------------------------------------------------+
//|                     Ultimate Master EA                           |
//|                 Developed By: Scalp Master                       |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh> 


CTrade trade;

//------------------- Inputs -------------------------
enum TradingModeEnum {Normal, Aggressive};
input TradingModeEnum TradingMode = Aggressive;
input bool HedgingAllowed = true;
input long MagicNumber = 20250821;
input string OrderComment = "Ultimate Master";
input double BasketClosePercent = 2.0; // Balance-?? X% ? ?? trades close
input double TrailingStopPips = 20; // trailing stop distance
input bool UseATRFilter = false;
input int ATRPeriod = 14;
input double ATRMultiplier = 1.3;
input int CooldownSeconds = 60; // seconds between same-direction trades

input bool OnlyMicroWhenSoftHedge = true;   // Soft hedge active ??? ????? micro entries

// --- News Filter Inputs ---
input bool   UseNewsFilter        = false;               // news filter on/off
input string NewsTimes            = "";                  // "2025.08.23 12:30;2025.08.23 14:00"
input int    NewsBlockBeforeMin   = 15;                  // X min ??? ????
input int    NewsBlockAfterMin    = 15;                  // X min ??? ????
input bool   NewsBlocksMicroToo   = true;                // micro entries-? ???? ???? ????


// Recovery / Soft Hedge Inputs
input int RecoveryStep1_Pips = 50;
input int RecoveryStep2_Pips = 50;
input int RecoveryStep3Plus_Pips = 100;
input int SoftHedgeStep = 2; // Steps after which soft hedge triggers
input int MaxRecoveryLegs = 10;
input double FirstLot = 0.01;
input double LotMultiplier = 1.3;

// --- Soft Hedge re-entry settings ---
input int    SoftHedgeSRLookback   = 20;   // SR / swing lookback for re-entry detection
input int    SoftHedgeBreakPips    = 3;    // price must break SR/swing by X pips to trigger re-entry
input double SoftHedgeReentryLot   = 0.0;  // 0.0 -> use FirstLot, otherwise use this lot for re-entry


// Average TP
input double AverageTP_Pips = 10;

// Dashboard Inputs
input bool ShowDashboard = true;
input int DashX = 10;
input int DashY = 20;
input color DashBGColor = clrBlue;
input color DashFontColor = clrWhite;
input int DashFontSize = 12;
input bool ShowSRLines = true;   // Support/Resistance lines ??????? ???? hide/show toggle
input color SRLineColor = clrYellow; // SR line color


//------------------- Average TP Function ----------------
void CloseBasketByPercent()

{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double totalProfit = 0.0;

    for(int i=0; i<PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC)==MagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double volume = PositionGetDouble(POSITION_VOLUME);
                long type = PositionGetInteger(POSITION_TYPE);
                double price = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                double profit = PositionGetDouble(POSITION_PROFIT);totalProfit += profit;

            }
        }
    }

    if(totalProfit >= balance * BasketClosePercent/100.0)
    {
        for(int i=PositionsTotal()-1;i>=0;i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                if(PositionGetInteger(POSITION_MAGIC)==MagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol)
                    trade.PositionClose(ticket);
            }
        }
        Print("All positions closed at Basket % target!");
    }
}

void ApplyTrailingStop()
{
    double pip = PipPoint();
    for(int i=0; i<PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC)==MagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol)
            {
                long type = PositionGetInteger(POSITION_TYPE);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double price = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                double currentTP = PositionGetDouble(POSITION_TP);

                if(type==POSITION_TYPE_BUY)
                {
                    double newTP = price - TrailingStopPips*pip;
                    if(newTP > openPrice && newTP > currentTP) trade.PositionModify(ticket,0,newTP);
                }
                else
                {
                    double newTP = price + TrailingStopPips*pip;
                    if(newTP < openPrice && newTP < currentTP) trade.PositionModify(ticket,0,newTP);
                }
            }
        }
    }
}


void CloseAllAtAverageTP()
{
    double pip = PipPoint();
    double totalProfit = 0.0;
    int posCount = 0;

    // ?? open position ????? current profit ??? ???
    for(int i=0; i<PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double volume = PositionGetDouble(POSITION_VOLUME);
                long type = PositionGetInteger(POSITION_TYPE);
                double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                                           : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                double profit = (type == POSITION_TYPE_BUY) ? (price - openPrice) * volume / pip
                                                           : (openPrice - price) * volume / pip;

                totalProfit += profit;
                posCount++;
            }
        }
    }

    // ??? totalProfit >= (AverageTP_Pips * posCount) ????? ?? close
    if(totalProfit >= AverageTP_Pips * posCount)
    {
        for(int i=PositionsTotal()-1; i>=0; i--) // reverse loop safer
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
                   PositionGetString(POSITION_SYMBOL) == _Symbol)
                {
                    trade.PositionClose(ticket);
                }
            }
        }
        Print("All positions closed at Average TP!");
    }
}


//------------------- Globals -----------------------


datetime lastBuyTime=0;
datetime lastSellTime=0;
bool softHedgeActive = false;
double softHedgeProfit = 0.0;

string dashboardName = "UltimateMasterDashboard";
// Dashboard object names (3 boxes + 3 labels)
string UM_Box_Bal      = "UM_Box_Bal";
string UM_Box_Bal_Txt  = "UM_Box_Bal_Txt";
string UM_Box_Pft      = "UM_Box_Pft";
string UM_Box_Pft_Txt  = "UM_Box_Pft_Txt";
string UM_Box_DD       = "UM_Box_DD";
string UM_Box_DD_Txt   = "UM_Box_DD_Txt";

// Track equity peak for Drawdown
double UM_EquityPeak = 0.0;

// --- News Filter globals ---
  datetime gNewsTimes[];         // parsed news datetimes
string   gNewsTimesCached = ""; // last parsed input cache


//------------------- Utility Functions -------------
double PipPoint() { double p=SymbolInfoDouble(_Symbol,SYMBOL_POINT); int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); return (d==3||d==5)? p*10.0 : p; }

bool PosMatches(long type)
{
   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetInteger(POSITION_TYPE) == type &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
      }
   }
   return false;
}
int CountOpenDir(long dirType)
{ 
   int c = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetInteger(POSITION_TYPE) == dirType &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
            c++;
      }
   }
   return c;
}

// ?? ?????? Step 1 function ????
bool IsNewsBlocked()
{
    if(!UseNewsFilter) return false;

    if(NewsTimes != gNewsTimesCached)
    {
        ArrayResize(gNewsTimes,0);
        gNewsTimesCached = NewsTimes;

        string arr[];
        int n = StringSplit(NewsTimes,';',arr);
        for(int i=0;i<n;i++)
        {
            datetime dt = StringToTime(arr[i]);
         
        }
    }

    datetime now = TimeCurrent();
    for(int i=0;i<ArraySize(gNewsTimes);i++)
    {
        datetime nt = gNewsTimes[i];
        if(now >= (nt - NewsBlockBeforeMin*60) && now <= (nt + NewsBlockAfterMin*60))
            return true;
    }

    return false;
}

// DrawSupportResistance() function ????? declare
//==================== Draw Support/Resistance ====================
//==================== Draw Support/Resistance ====================
void DrawSupportResistance()
{
    if(!ShowSRLines) return; // hide/show toggle

    int lookback = SoftHedgeSRLookback; // SR calculation lookback
    double highest = iHigh(_Symbol, PERIOD_CURRENT, 0); // current bar high
    double lowest  = iLow(_Symbol, PERIOD_CURRENT, 0);  // current bar low

    for(int i=1; i<lookback; i++)
    {
        double h = iHigh(_Symbol, PERIOD_CURRENT, i);
        double l = iLow(_Symbol, PERIOD_CURRENT, i);

        if(h > highest) highest = h;
        if(l < lowest)  lowest  = l;
    }

    string srHighName = "SR_High";
    string srLowName  = "SR_Low";

    // Draw High line
    if(ObjectFind(0,srHighName) < 0)
        ObjectCreate(0, srHighName, OBJ_HLINE, 0, 0, highest);
    else
        ObjectSetDouble(0, srHighName, OBJPROP_PRICE, highest);
    ObjectSetInteger(0, srHighName, OBJPROP_COLOR, SRLineColor);

    // Draw Low line
    if(ObjectFind(0,srLowName) < 0)
        ObjectCreate(0, srLowName, OBJ_HLINE, 0, 0, lowest);
    else
        ObjectSetDouble(0, srLowName, OBJPROP_PRICE, lowest);
    ObjectSetInteger(0, srLowName, OBJPROP_COLOR, SRLineColor);
}

//------------------- Dashboard ---------------------


double GetSwingHigh(int lookback=5)
{
   double highVal = iHigh(_Symbol, PERIOD_CURRENT, 0);
   for(int i=1; i<=lookback; i++)
   {
       double h = iHigh(_Symbol, PERIOD_CURRENT, i);
       if(h > highVal) highVal = h;
   }
   return highVal;
}


double GetSwingLow(int lookback=5)
{
    double lowVal = Low[0];
    for(int i=1; i<=lookback; i++)
        if(Low[i] < lowVal) lowVal = Low[i];
    return lowVal;
}

bool IsBullishEngulfing(int shift=1)
{
    double open1 = iOpen(_Symbol, PERIOD_CURRENT, shift+1);
    double close1 = iClose(_Symbol, PERIOD_CURRENT, shift+1);
    double open2 = iOpen(_Symbol, PERIOD_CURRENT, shift);
    double close2 = iClose(_Symbol, PERIOD_CURRENT, shift);
    return (close2 > open2 && close1 < open1 && open2 < close1 && close2 > open1);
}

bool IsBearishEngulfing(int shift=1)
{
    double open1 = Open[shift+1];
    double close1 = Close[shift+1];
    double open2 = Open[shift];
    double close2 = Close[shift];
    return (close2 < open2 && close1 > open1 && open2 > close1 && close2 < open1);
}

bool PipGapOK(double lastPrice, double currentPrice, int minPips)
{
    double pip = PipPoint();
    return MathAbs(currentPrice - lastPrice) >= minPips * pip;
}



//------------------- Trade Functions ----------------
void OpenTrade(string dir,double lot)
{
   trade.SetExpertMagicNumber(MagicNumber);
   double pip = PipPoint();
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tpPrice = 0.0;

   if(dir=="BUY")
   {
      tpPrice = ask + AverageTP_Pips * pip; // buy TP
      bool ok = trade.Buy(lot, _Symbol, 0, 0, tpPrice, OrderComment);
      if(!ok) Print("Error opening BUY: ", GetLastError());
   }
   else
   {
      tpPrice = bid - AverageTP_Pips * pip; // sell TP
      bool ok = trade.Sell(lot, _Symbol, 0, 0, tpPrice, OrderComment);
      if(!ok) Print("Error opening SELL: ", GetLastError());
   }
}

// Get last entry price for a specific direction
double GetLastEntryPriceDir(long dirType)
{
    datetime latest=0;
    double price=0;
    for(int i=PositionsTotal()-1; i>=0; i--)
    {
        ulong t=PositionGetTicket(i);
        if(!PositionSelectByTicket(t)) continue;
        if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber || 
           PositionGetInteger(POSITION_TYPE)!=dirType || 
           PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

        datetime tm=(datetime)PositionGetInteger(POSITION_TIME);
        if(tm>latest){ latest=tm; price=PositionGetDouble(POSITION_PRICE_OPEN); }
    }
    return price;
}

//------------------- Signal Functions (Engulfing + Major Candles) ----------------
bool ATRFilterOk()
{
    if(!UseATRFilter) return true;
    double atr = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, 0);
    double threshold = ATRMultiplier * atr;
    double priceRange = iHigh(_Symbol, PERIOD_CURRENT, 0) - iLow(_Symbol, PERIOD_CURRENT, 0);

    return priceRange <= threshold;
}

// Major Candle Patterns
bool IsPinBar(int shift=1)
{
    double body = MathAbs(Open[shift] - Close[shift]);
    double upperShadow = High[shift] - MathMax(Open[shift], Close[shift]);
    double lowerShadow = MathMin(Open[shift], Close[shift]) - Low[shift];
    return (body < (High[shift]-Low[shift])*0.3 && lowerShadow > body*2);
}

bool IsHammer(int shift=1)
{
    double body = MathAbs(Open[shift] - Close[shift]);
    double lowerShadow = MathMin(Open[shift], Close[shift]) - Low[shift];
    double upperShadow = High[shift] - MathMax(Open[shift], Close[shift]);
    return (body < (High[shift]-Low[shift])*0.3 && lowerShadow > body*2 && upperShadow < body);
}

bool IsShootingStar(int shift=1)
{
    double body = MathAbs(Open[shift] - Close[shift]);
    double upperShadow = High[shift] - MathMax(Open[shift], Close[shift]);
    double lowerShadow = MathMin(Open[shift], Close[shift]) - Low[shift];
    return (body < (High[shift]-Low[shift])*0.3 && upperShadow > body*2 && lowerShadow < body);
}

bool IsDoji(int shift=1)
{
    double body = MathAbs(Open[shift] - Close[shift]);
    double candleRange = High[shift] - Low[shift];
    return (body <= candleRange*0.1);
}


bool CheckBuySignal()
{
    if(!ATRFilterOk()) { 
        Print("Buy Blocked: ATR filter failed");
        return false; 
    }

    double swingLow = GetSwingLow(5);
    double lastBuyPrice = GetLastEntryPriceDir(POSITION_TYPE_BUY);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Swing Low condition
    if(currentPrice <= swingLow) {
        Print("Buy Blocked: CurrentPrice=", currentPrice, " <= SwingLow=", swingLow);
        return false;
    }

    // Bullish Candle condition
    if(!(IsBullishEngulfing(1) || IsPinBar(1) || IsHammer(1) || IsDoji(1))) {
        Print("Buy Blocked: No bullish pattern detected at candle[1]");
        return false;
    }

    // Minimum pip gap condition
    if(!PipGapOK(lastBuyPrice, currentPrice, 50)) {
        Print("Buy Blocked: PipGap not satisfied. LastBuy=", lastBuyPrice, " Current=", currentPrice);
        return false;
    }

    Print("? Buy Signal Passed @Price=", currentPrice);
    return true;
}


bool CheckSellSignal()
{
    if(!ATRFilterOk()) { 
        Print("Sell Blocked: ATR filter failed");
        return false; 
    }

    double swingHigh = GetSwingHigh(5);
    double lastSellPrice = GetLastEntryPriceDir(POSITION_TYPE_SELL);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Swing High condition
    if(currentPrice >= swingHigh) {
        Print("Sell Blocked: CurrentPrice=", currentPrice, " >= SwingHigh=", swingHigh);
        return false;
    }

    // Bearish Candle condition
    if(!(IsBearishEngulfing(1) || IsPinBar(1) || IsShootingStar(1) || IsDoji(1))) {
        Print("Sell Blocked: No bearish pattern detected at candle[1]");
        return false;
    }

    // Minimum pip gap condition
    if(!PipGapOK(lastSellPrice, currentPrice, 50)) {
        Print("Sell Blocked: PipGap not satisfied. LastSell=", lastSellPrice, " Current=", currentPrice);
        return false;
    }

    Print("? Sell Signal Passed @Price=", currentPrice);
    return true;
}
// Lot Calculation Method
enum LotCalcMethodEnum {Multiplier, Fibonacci};
input LotCalcMethodEnum LotCalcMethod = Multiplier; // default previous behavior



//------------------- Recovery Soft Hedge ----------------
void CheckRecovery(long dirType)
{
   int count = CountOpenDir(dirType);
   if(count >= MaxRecoveryLegs) return;

   double pip = PipPoint();
   double price = (dirType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double last = GetLastEntryPriceDir(dirType);
   int nextLeg = count + 1;
   double step = 0;

   if(nextLeg == 2) step = RecoveryStep1_Pips;
   else if(nextLeg == 3) step = RecoveryStep2_Pips;
   else step = RecoveryStep3Plus_Pips;

   // Soft Hedge Logic
   if(nextLeg >= SoftHedgeStep) {
       softHedgeActive = true;
       softHedgeProfit = AverageTP_Pips * pip * nextLeg; // optional calculation
   }

   // Check if price reached recovery step
   if( (dirType == POSITION_TYPE_BUY && price <= last - step * pip) ||
       (dirType == POSITION_TYPE_SELL && price >= last + step * pip) )
   {
       // Open new trade
       OpenTrade((dirType == POSITION_TYPE_BUY) ? "BUY" : "SELL", CalcLot(nextLeg));

       // Modify TP of opposite trades if soft hedge active
       if(softHedgeActive) {
           double profitTarget = softHedgeProfit;
           for(int i=0; i<PositionsTotal(); i++)
           {
               ulong t = PositionGetTicket(i);
               if(PositionSelectByTicket(t))
               {
                   if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
                   {
                       long type = PositionGetInteger(POSITION_TYPE);
                       if(type != dirType) // opposite position
                       {
                           double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                           double tp = (type == POSITION_TYPE_BUY) ? openPrice + profitTarget : openPrice - profitTarget;
                           trade.PositionModify(t, 0, tp);
                       }
                   }
               }
           }
       }
   }
} // <-- end of CheckRecovery

//------------------- Soft Hedge Re-entry ----------------
void CheckSoftHedgeReEntry()
{
   // Respect news filter
   if(IsNewsBlocked()) return;

   // ??? already active ???? ????? ??????? ?? ???? ???
   if(softHedgeActive) return;

   // ??? EA-? ???? ????? ?? ???? ????? ???? ?? ??
   int myPosCount = CountMyPositionsAll();
   if(myPosCount == 0) return;

   // Buy/Sell ?????? ??? ???
   int buyCount  = CountOpenDir(POSITION_TYPE_BUY);
   int sellCount = CountOpenDir(POSITION_TYPE_SELL);

   // ??? ???? ???????? ??? ??? ?? ????, ?????? ???? (optional net loss check)
   int netDir = 0; // 0=none, POSITION_TYPE_BUY or POSITION_TYPE_SELL
   if(buyCount > sellCount) netDir = POSITION_TYPE_BUY;
   else if(sellCount > buyCount) netDir = POSITION_TYPE_SELL;
   else
   {
      // ??? ?????? buy/sell ??? ?????/???? ???? ????????? ???
      double buyVol=0.0, sellVol=0.0;
      for(int i=0;i<PositionsTotal();i++){
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         int tp = (int)PositionGetInteger(POSITION_TYPE);
         double vol = PositionGetDouble(POSITION_VOLUME);
         if(tp==POSITION_TYPE_BUY) buyVol += vol;
         else if(tp==POSITION_TYPE_SELL) sellVol += vol;
      }
      if(buyVol > sellVol) netDir = POSITION_TYPE_BUY;
      else if(sellVol > buyVol) netDir = POSITION_TYPE_SELL;
      else return; // balanced - ??? ?????? re-entry condition ???
   }

   double pip = PipPoint();
   double price = (netDir==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   // swing/SR ????? (SoftHedgeSRLookback ??????? ???)
   double swingHigh = GetSwingHigh(SoftHedgeSRLookback);
   double swingLow  = GetSwingLow(SoftHedgeSRLookback);
   double breakDist = SoftHedgeBreakPips * pip;

   // Decide trigger ??? open hedge (opposite) + modify opposite TP
   if(netDir == POSITION_TYPE_BUY)
   {
      // net long exposure -> if price breaks below swingLow by breakDist -> open SELL hedge
      if(price <= (swingLow - breakDist))
      {
         double lot = (SoftHedgeReentryLot > 0.0) ? SoftHedgeReentryLot : FirstLot;
         OpenTrade("SELL", lot);

         // set soft hedge active and compute softHedgeProfit (scale by count)
         int scale = (buyCount>0) ? buyCount : 1;
         softHedgeProfit = AverageTP_Pips * pip * scale;
         softHedgeActive = true;

         // modify TP of existing BUYs so they close with softHedgeProfit
         for(int i=0;i<PositionsTotal();i++){
            ulong t = PositionGetTicket(i);
            if(!PositionSelectByTicket(t)) continue;
            if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
            int tp = (int)PositionGetInteger(POSITION_TYPE);
            if(tp==POSITION_TYPE_BUY){
               double openP = PositionGetDouble(POSITION_PRICE_OPEN);
               double newTP = openP + softHedgeProfit;
               trade.PositionModify(t, 0.0, newTP);
            }
         }
         Print("SoftHedge Re-entry triggered: SELL opened (swingLow break). softHedgeActive=true");
      }
   }
   else if(netDir == POSITION_TYPE_SELL)
   {
      // net short exposure -> if price breaks above swingHigh by breakDist -> open BUY hedge
      if(price >= (swingHigh + breakDist))
      {
         double lot = (SoftHedgeReentryLot > 0.0) ? SoftHedgeReentryLot : FirstLot;
         OpenTrade("BUY", lot);

         int scale = (sellCount>0) ? sellCount : 1;
         softHedgeProfit = AverageTP_Pips * pip * scale;
         softHedgeActive = true;

         // modify TP of existing SELLs so they close with softHedgeProfit
         for(int i=0;i<PositionsTotal();i++){
            ulong t = PositionGetTicket(i);
            if(!PositionSelectByTicket(t)) continue;
            if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
            int tp = (int)PositionGetInteger(POSITION_TYPE);
            if(tp==POSITION_TYPE_SELL){
               double openP = PositionGetDouble(POSITION_PRICE_OPEN);
               double newTP = openP - softHedgeProfit;
               trade.PositionModify(t, 0.0, newTP);
            }
         }
         Print("SoftHedge Re-entry triggered: BUY opened (swingHigh break). softHedgeActive=true");
      }
   }
}
//----------------- end Soft Hedge Re-entry ----------------

// ================= ???? ????????? ????? =================

// ?? ????? ??? ????? ?????? (?? EA-?)
int CountMyPositionsAll()
{
   int c=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==MagicNumber &&
         PositionGetString(POSITION_SYMBOL)==_Symbol) c++;
   }
   return c;
}

// ?? ????? ????? ??? soft hedge reset
void ResetSoftHedgeIfFlat()
{
   if(CountMyPositionsAll()==0)
   {
      softHedgeActive=false;
      softHedgeProfit=0.0;
   }
}

// ??????? ???????-???? soft hedge active ???
void DoMicroEntries()
{
   if(!softHedgeActive) return;
   Print("Micro entries check running (soft hedge active).");
   if(CheckBuySignal())  OpenTrade("BUY",  FirstLot);
   if(CheckSellSignal()) OpenTrade("SELL", FirstLot);
}

double CalcLot(int leg)
{
    if(LotCalcMethod == Multiplier)
        return FirstLot * MathPow(LotMultiplier, leg-1);
    else if(LotCalcMethod == Fibonacci)
    {
        int fib0=1, fib1=1, fibNext;
        for(int i=1;i<leg;i++)
        {
            fibNext = fib0 + fib1;
            fib0 = fib1;
            fib1 = fibNext;
        }
        return FirstLot * fib1;
    }
    return FirstLot; // fallback
}

void UpdateDashboard(string signal)
{
   if(!ShowDashboard) return;

   // --- Compute Account Metrics ---
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double floating = AccountInfoDouble(ACCOUNT_PROFIT); // open P/L (all symbols)

   // Track equity peak for drawdown
   if(equity > UM_EquityPeak) UM_EquityPeak = equity;

   double dd_abs = (UM_EquityPeak > 0.0) ? (UM_EquityPeak - equity) : 0.0;
   if(dd_abs < 0) dd_abs = 0.0;
   double dd_pct = (UM_EquityPeak > 0.0) ? (dd_abs / UM_EquityPeak * 100.0) : 0.0;

   // --- Today Profit (keep your logic) ---
   double todayProfit=0;
   MqlDateTime now; TimeToStruct(TimeCurrent(), now);
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      datetime t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
      MqlDateTime md; TimeToStruct(t, md);
      if(md.day==now.day && md.mon==now.mon && md.year==now.year)
         todayProfit += HistoryDealGetDouble(d,DEAL_PROFIT);
   }

   // --- Geometry of boxes ---
   int boxW = 260;     // width
   int boxH = 34;      // height of each row box
   int gap  = 8;       // vertical gap between boxes
   int x    = DashX;   // left padding from corner
   int y1   = DashY;               // 1st row (Balance)
   int y2   = DashY + boxH + gap;  // 2nd row (Profit)
   int y3   = y2   + boxH + gap;   // 3rd row (DD)

   // ========== Helper lambdas (inline) ==========
   auto ensure_rect = [&](string name,int x,int y,int w,int h){
      if(ObjectFind(0,name) < 0)
         ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,     w);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,     h);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,   DashBGColor);  // blue background
      ObjectSetInteger(0,name,OBJPROP_COLOR,     DashBGColor);  // border same as bg
   };

   auto ensure_label = [&](string name,int x,int y,string txt){
      if(ObjectFind(0,name) < 0)
         ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE, x+10);   // left padding inside box
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE, y+8);    // top padding inside box
      ObjectSetInteger(0,name,OBJPROP_COLOR,     DashFontColor); // white font
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,  DashFontSize);
      ObjectSetString (0,name,OBJPROP_TEXT,      txt);
   };

   // ========== Row-1: Balance ==========
   ensure_rect(UM_Box_Bal,     x, y1, boxW, boxH);
   string balTxt = "Balance: " + DoubleToString(balance,2);
   ensure_label(UM_Box_Bal_Txt, x, y1, balTxt);

   // ========== Row-2: Floating P/L (+ today's profit + signal small) ==========
   ensure_rect(UM_Box_Pft,     x, y2, boxW, boxH);
   string pftTxt = "Floating P/L: " + DoubleToString(floating,2) + 
                   "   |  Today: " + DoubleToString(todayProfit,2) +
                   "   |  Signal: " + signal;
   ensure_label(UM_Box_Pft_Txt, x, y2, pftTxt);

   // ========== Row-3: Drawdown ==========
   ensure_rect(UM_Box_DD,      x, y3, boxW, boxH);
   string ddTxt  = "DD: " + DoubleToString(dd_abs,2) + 
                   " (" + DoubleToString(dd_pct,2) + "%)";
   ensure_label(UM_Box_DD_Txt,  x, y3, ddTxt);
}

//------------------- OnTick ------------------------
//------------------- OnTick ------------------------
void OnTick()
{
    // --- Must be first line: check if trading is allowed
    if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
        return;

    // --- News filter
    if(IsNewsBlocked())
    {
        if(softHedgeActive && OnlyMicroWhenSoftHedge && !NewsBlocksMicroToo)
        {
            DoMicroEntries();
        }
        else
        {
            Print("? Trade blocked due to News Filter.");
            return;
        }
    }

    // --- Support & Resistance and Soft Hedge
    DrawSupportResistance();
    ResetSoftHedgeIfFlat();
    CheckSoftHedgeReEntry();

    // --- Signal determination
    string signal = "NONE";
    if(CheckBuySignal()) signal = "BUY";
    else if(CheckSellSignal()) signal = "SELL";

    // --- Recovery
    CheckRecovery(POSITION_TYPE_BUY);
    CheckRecovery(POSITION_TYPE_SELL);

    // --- Entry routing
    if(softHedgeActive && OnlyMicroWhenSoftHedge)
    {
        DoMicroEntries();
    }
    else
    {
        if(TradingMode == Aggressive && HedgingAllowed)
        {
            if(CountOpenDir(POSITION_TYPE_BUY) == 0 && CountOpenDir(POSITION_TYPE_SELL) == 0)
            {
                if(TimeCurrent() - lastBuyTime > 60 && TimeCurrent() - lastSellTime > 60)
                {
                    OpenTrade("BUY", FirstLot);
                    OpenTrade("SELL", FirstLot);
                    lastBuyTime  = TimeCurrent();
                    lastSellTime = TimeCurrent();
                    Print("Aggressive main entries opened (BUY & SELL).");
                }
            }
        }
        else if(TradingMode == Normal)
        {
            if(CheckBuySignal() && CountOpenDir(POSITION_TYPE_BUY) == 0 && TimeCurrent() - lastBuyTime > CooldownSeconds)
            {
                OpenTrade("BUY", FirstLot);
                lastBuyTime = TimeCurrent();
                Print("Normal main entry: BUY opened.");
            }

            if(CheckSellSignal() && CountOpenDir(POSITION_TYPE_SELL) == 0 && TimeCurrent() - lastSellTime > CooldownSeconds)
            {
                OpenTrade("SELL", FirstLot);
                lastSellTime = TimeCurrent();
                Print("Normal main entry: SELL opened.");
            }
        }
    }

    // --- Closing & trailing
    CloseAllAtAverageTP();
    CloseBasketByPercent();
    ApplyTrailingStop();

    // --- Dashboard update
    UpdateDashboard(signal);
}

//+------------------------------------------------------------------+
void OnInit(){
  Print("Ultimate Master EA started");
}
void OnDeinit(const int reason){
}