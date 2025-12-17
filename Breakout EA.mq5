//+------------------------------------------------------------------+
//|                                            Breakout EA v1.0.mq5 |
//+------------------------------------------------------------------+
#property copyright "Copyright Jeppe Steenfatt"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Indicators/Trend.mqh>

#include <Trade/SymbolInfo.mqh>
CSymbolInfo       o_symbol;

CTrade        trade;
CPositionInfo posinfo;
COrderInfo    ordinfo; 

CiIchimoku    Ichimoku;
CiMA          MovAvgFast, MovAvgSlow;

// =========================== Debug ================================
// input group "=== Debug ==="
bool  DebugOn       = false;
bool  DebugPrices   = false;
bool  DebugFilters  = false;
bool  DebugNews     = false;
bool  LogPipMath    = false;   // show price + pips everywhere

void DPrint(const string s){ if(DebugOn) Print(s); }
void D2(const string fmt, double a, double b){ if(DebugOn) Print(StringFormat(fmt,a,b)); }
void D3(const string fmt, double a, double b, double c){ if(DebugOn) Print(StringFormat(fmt,a,b,c)); }
void Ds2(const string fmt, string a, string b){ if(DebugOn) Print(StringFormat(fmt,a,b)); }

// =========================== Enums ================================

enum SLTYPES{
   SL_PIPS = 0, // pips
   SL_CURRENCY = 1, // currency
};

enum LST      { Fixed=0, RiskPct=1 };
// allow midnight start/end safely
enum Hours    { H0=0, H1=1, H2, H3, H4, H5, H6, H7, H8, H9, H10, H11, H12, H13, H14, H15, H16, H17, H18, H19, H20, H21, H22, H23 };
enum Minutes  { M0=0, M5=5, M10=10, M15=15, M20=20, M25=25, M30=30, M35=35, M40=40, M45=45, M50=50, M55=55 };
enum TrSides  { Onesided=0, Bothside=1 };
//enum SLType   { Yes=0, No=1 };
enum TrType   { RangePct=0, HighLow=1, Fixedpips=2 };
enum TrStyle  { With_Break=0, Opposite_to_Break=1 };
enum IcTypes  { Price_above_Cloud=0, Price_above_Ten=1, Price_above_Kij=2, Price_above_SenA=3, Price_above_SenB=4,
                Ten_above_Kij=5, Ten_above_Kij_above_Cloud=6, Ten_above_Cloud=7, Kij_above_Cloud=8 };
enum sep_dropdown { comma=0, semicolon=1 };
enum TPSLMode { TPSL_RangePercent=0, TPSL_FixedPips=1 };


enum ZONES{
   z_Exchange  = 100, // Exchange
   zm12          = -12, // GMT-12
   zm11          = -11, // GMT-11
   zm10          = -10, // GMT-10
   zm9          = -9, // GMT-9
   zm8          = -8, // GMT-8
   zm7          = -7, // GMT-7
   zm6          = -6, // GMT-6
   zm5          = -5, // GMT-5
   zm4          = -4, // GMT-4
   zm3          = -3, // GMT-3
   zm2          = -2, // GMT-2
   zm1          = -1, // GMT-1
   z0          = 0, // GMT
   z1          = 1, // GMT+1
   z2          = 2, // GMT+2
   z3          = 3, // GMT+3
   z4          = 4, // GMT+4
   z5          = 5, // GMT+5
   z6          = 6, // GMT+6
   z7          = 7, // GMT+7
   z8          = 8, // GMT+8
   z9          = 9, // GMT+9
   z10          = 10, // GMT+10
   z11          = 11, // GMT+11
   z12          = 12 // GMT+12
};

input ZONES                TimeZone          = z0;    // Time Zone




// =========================== Inputs ===============================
input group "=== EA Specific Variables ==="
input string          TradeComment     = "Brotherrr Listennn";
input TrStyle         TradingStyle     = With_Break;
input TrSides         TradingSides     = Onesided;

input group "=== Daily Range ==="
input bool UseSession0                   = true; // Use Daily Range
input ulong           InpMagic0   = 23950; // Daily Magic Number
input Hours           TradeCloseHour0   = H22;
input Minutes         TradeCloseMin0    = M0;
color           rangecolor0       = clrBeige;
input double             MinRangeSize0     = 15;    // Min pips
input double             MaxRangeSize0     = 30000;  // Max pips
color           rangecolordisabled0 = clrRed;
bool            AllowRangeClampIfOutside0 = true; // clamp UsedRangeSize if out of bounds

input group "=== London Range ==="
input bool UseSession1                   = true; // Use London Session
input ulong           InpMagic1   = 23951; // London Magic Number
input Hours           RangeStartHour1   = H8;
input Minutes         RangeStartMin1    = M0;
input Hours           RangeEndHour1     = H12;
input Minutes         RangeEndMin1      = M0;
input Hours           TradeCloseHour1   = H22;
input Minutes         TradeCloseMin1    = M0;
input color           rangecolor1       = clrBeige;
input double             MinRangeSize1     = 15;    // Min pips
input double             MaxRangeSize1     = 30000;  // Max pips
input color           rangecolordisabled1 = clrRed;
bool            AllowRangeClampIfOutside1 = true; // clamp UsedRangeSize if out of bounds

input group "=== Asia Range ==="
input bool UseSession2                   = true; // Use Asia Session
input ulong           InpMagic2   = 23952; // London Magic Number
input Hours           RangeStartHour2   = H2;
input Minutes         RangeStartMin2    = M0;
input Hours           RangeEndHour2     = H6;
input Minutes         RangeEndMin2      = M0;
input Hours           TradeCloseHour2   = H22;
input Minutes         TradeCloseMin2    = M0;
input color           rangecolor2       = clrBeige;
input double             MinRangeSize2     = 15;    // Min pips
input double             MaxRangeSize2     = 30000;  // Max pips
input color           rangecolordisabled2 = clrRed;
bool            AllowRangeClampIfOutside2 = true; // clamp UsedRangeSize if out of bounds

bool            PlaceImmediatelyAtEnd    = true;
input bool      RequireInnerBandForPlacement = false;

input group "=== Trade Management ==="
input LST             LotSizeType      = RiskPct;
input double          FixedLotSize     = 0.01;
input double          RiskPercent      = 2.0;
input bool            UseEquityForRisk = true;        // Equity vs Balance for risk base
//input ENUM_TIMEFRAMES PERIOD_CURRENT     = PERIOD_M5;
int             OrdDistpct       = 10;          // inner band % of (Used) range
input int        EntryTolerancePoints = 10;      // Max points away from level to allow entry

input group "=== SL/TP Modes ==="
input SLTYPES SLType = SL_PIPS; // StopLoss type
TPSLMode        TPSL_Mode        = TPSL_FixedPips;
input double             StopLoss    = 500;   // Stop Loss
input double             TakeProfit    = 1500;  // Take Profit
 int             SLPercent        = 100;  // % of UsedRange when TPSL_RangePercent
 int             TPPercent        = 180;  // % of SL distance

/*
input group "=== StopLoss Management ==="
input SLType          SLT              = Yes;
TrType          TrailType        = Fixedpips;
input double             TrailFixedpips   = 30; // 
input int             TrailRangePct    = 80;
input ENUM_TIMEFRAMES HL_Timeframe     = PERIOD_M15;
int             BarsN            = 5;
int             HighLowBuffer    = 2;
*/

input group "=== Trailing Stop ==="
input bool UseTrailing              = true; //Use Trailing Stop
input double TrailingStart          = 100; // Trailing Trigger
input double TrailingStop           = 100; // Trailing Stop (pips)
double TrailingStep                 = 0; //Move Trailing every X Pips

input group "=== Spread Filter ==="
input double MaxSpreadPoints        = 30; // Maximum spread in points



//MqlDateTime starttime, endtime, closetime;
//datetime    timestart=0, timeend=0, timeclose=0;
//int         BarsRangeStart=0, BarstoCount=0, 
int BuyTotal=0, SellTotal=0;
//double      RangeHigh=0.0, RangeLow=0.0, RangeSize=0.0, UsedRangeSize=0.0;

input group "=== News Filter ==="
input bool            UseNewsFilter      = true; // Use News Filter
input int             NewsMinutesBefore  = 30; // Block minutes before news
input int             NewsMinutesAfter   = 30; // Block minutes after news
input bool            FilterHighImpact   = true; // Filter High Impact
input bool            FilterMediumImpact = false; // Filter Medium Impact
input bool            FilterLowImpact    = false; // Filter Low Impact
input string          NewsKeywordFilter  = ""; // Keyword filter (empty = no filter)


//input group "=== Moving Average Filter ==="
 bool               MAFilterOn     = false;
 ENUM_TIMEFRAMES    MATimeframe    = PERIOD_D1;
 int                Slow_MA_Period = 200;
 int                Fast_MA_Period = 50;
 ENUM_MA_METHOD     MA_Mode        = MODE_EMA;
 ENUM_APPLIED_PRICE MA_AppPrice    = PRICE_MEDIAN;

bool MA_BuyOn=true, MA_SellOn=true;
/*
input group "=== Ichimoku Filter ==="
input bool              IchimokuFilter  = false;
input IcTypes           IchiFilterType  = Price_above_Cloud;
input ENUM_TIMEFRAMES   IchiTimeframe   = PERIOD_D1;
input int               tenkan          = 9;
input int               kijun           = 26;
input int               senkou_b        = 52;
*/
bool Ichi_BuyOn=true, Ichi_SellOn=true;

bool   placedBuy=false, placedSell=false;
double lastBuyPrice=0.0, lastSellPrice=0.0;

double g_prevAsk = 0.0;
double g_prevBid = 0.0;
bool g_prevInit = false;

struct SessionLevels {
   double buyLevel;
   double sellLevel;
   double buySL;
   double buyTP;
   double sellSL;
   double sellTP;
   bool   active;
   ulong  magic;
   bool   buyFired;
   bool   sellFired;
   datetime dayStamp;
};

SessionLevels session0Levels;
SessionLevels session1Levels;
SessionLevels session2Levels;

double point;

datetime lastCloseDateSession0 = 0;
datetime lastCloseDateSession1 = 0;
datetime lastCloseDateSession2 = 0;

int diffTime = 0;



// ====================== Helpers & Broker Info ======================
#define CALENDAR_IMPORTANCE_LOW    1
#define CALENDAR_IMPORTANCE_MEDIUM 2
#define CALENDAR_IMPORTANCE_HIGH   3

int    DigitsForSymbol(){ return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); }

double Pip(){
   int d = DigitsForSymbol();
   if(d<=2) return _Point;
   return 10.0*_Point;
}

double MinStopDistancePoints(){ return (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point; }
double FreezeLevelPoints(){     return (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point; }

// =========================== Lifecycle ============================
int OnInit(){

   if (!o_symbol.Name(Symbol())) return(INIT_FAILED);

   ChartSetInteger(0, CHART_SHOW_GRID, false);

   if (o_symbol.Digits() == 3 || o_symbol.Digits() == 5){
      point = o_symbol.Point() * 10;
   } else {
      point = o_symbol.Point();
   }  
   
   diffTime = (int)((TimeCurrent()-TimeGMT()) / 60 / 60);  
   
   if(!MovAvgFast.Create(_Symbol, MATimeframe, Fast_MA_Period, 0, MA_Mode, MA_AppPrice)){
      Print("Failed to create MovAvgFast");
      return(INIT_FAILED);
   }
   if(!MovAvgSlow.Create(_Symbol, MATimeframe, Slow_MA_Period, 0, MA_Mode, MA_AppPrice)){
      Print("Failed to create MovAvgSlow");
      return(INIT_FAILED);
   }
   
   datetime initDate = DateOnly(TimeCurrent());
   session0Levels.active = false;
   session0Levels.buyFired = false;
   session0Levels.sellFired = false;
   session0Levels.dayStamp = initDate;
   session1Levels.active = false;
   session1Levels.buyFired = false;
   session1Levels.sellFired = false;
   session1Levels.dayStamp = initDate;
   session2Levels.active = false;
   session2Levels.buyFired = false;
   session2Levels.sellFired = false;
   session2Levels.dayStamp = initDate;

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   DPrint(StringFormat("[DEINIT] reason=%d", reason));
}

// ============================ OnTick ===============================
void OnTick(){

   if (UseTrailing){
      Trailing(InpMagic0);
      Trailing(InpMagic1);
      Trailing(InpMagic2);
   }

   MonitorLevels();

   if(!IsNewBar()) return;

   datetime bt = iTime(_Symbol, PERIOD_CURRENT, 0);
   DPrint(StringFormat("[BAR] %s", TimeToString(bt, TIME_DATE|TIME_SECONDS)));

   bool now, prev;
   double ask, bid;
   ulong magic;

   double RangeHigh=0, RangeLow=0;

   double BuyPrice, SellPrice;
   double BuySL, SellSL;
   double BuyTP, SellTP;
   
   datetime timestart, timeend;
   
   double RangeSize;

   ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

      if (UseSession1){
      magic = InpMagic1;
      CheckforTradeSides(magic);
      CheckforOpenOrdersandPositions(magic);

//      if (BuyTotal+SellTotal > 0){

         datetime currentTime = TimeCurrent();
         datetime currentDate = DateOnly(currentTime);
         
         if(lastCloseDateSession1 > 0){
            datetime lastDate = DateOnly(lastCloseDateSession1);
            if(currentDate != lastDate){
               lastCloseDateSession1 = 0;
            }
         }

         if (isCloseTime(TradeCloseHour1, TradeCloseMin1, currentTime)){
            datetime lastDate = (lastCloseDateSession1 > 0) ? DateOnly(lastCloseDateSession1) : 0;
            if(lastDate != currentDate && (HasPositionOrOrder(magic) || session1Levels.active)){
               CloseandResetAll(magic);
               lastCloseDateSession1 = currentTime;
            }
         }
  //    }
      datetime barTime1 = iTime(_Symbol,PERIOD_CURRENT,0);
      now    = isInsideTime(RangeStartHour1, RangeStartMin1, RangeEndHour1, RangeEndMin1, barTime1);
      prev   = isInsideTime(RangeStartHour1, RangeStartMin1, RangeEndHour1, RangeEndMin1, iTime(_Symbol,PERIOD_CURRENT,1));
      
      datetime prevBarTime = iTime(_Symbol,PERIOD_CURRENT,1);
      MqlDateTime currentDT, prevDT;
      datetime checkTime1 = barTime1;
      TimeToStruct(checkTime1, currentDT);
      TimeToStruct(prevBarTime, prevDT);
      if (TimeZone != z_Exchange){
         checkTime1 = checkTime1 - (diffTime - TimeZone)*60*60;
         prevBarTime = prevBarTime - (diffTime - TimeZone)*60*60;
         TimeToStruct(checkTime1, currentDT);
         TimeToStruct(prevBarTime, prevDT);
      }
      
      bool shouldSetLevels = (prev && !now);
      if(!shouldSetLevels && !now && !session1Levels.active){
         int endMin = (int)RangeEndHour1 * 60 + (int)RangeEndMin1;
         int currentMin = currentDT.hour * 60 + currentDT.min;
         int minutesAfterEnd = (currentMin - endMin + 1440) % 1440;
         if(minutesAfterEnd >= 0 && minutesAfterEnd <= 120){
            shouldSetLevels = true;
         } else if(minutesAfterEnd > 0 && minutesAfterEnd < 1440){
            datetime barDate = DateOnly(barTime1);
            datetime checkTimeForDate = checkTime1;
            MqlDateTime sessionDT;
            TimeToStruct(checkTimeForDate, sessionDT);
            sessionDT.hour = (int)RangeEndHour1;
            sessionDT.min = (int)RangeEndMin1;
            sessionDT.sec = 0;
            datetime sessionEndTime = StructToTime(sessionDT);
            datetime sessionEndDate = DateOnly(sessionEndTime);
            if(barDate == sessionEndDate && minutesAfterEnd > 0){
               shouldSetLevels = true;
            }
         }
      }
      
      if (shouldSetLevels){
         GetRange(RangeHigh, RangeLow,timestart, timeend, RangeStartHour1, RangeStartMin1, RangeEndHour1, RangeEndMin1);

         if(RangeHigh <= 0 || RangeLow <= 0 || RangeHigh <= RangeLow){
            session1Levels.active = false;
            session1Levels.buyFired = false;
            session1Levels.sellFired = false;
         } else {
            ShowRange(RangeHigh, RangeLow, timestart, timeend,MinRangeSize1, MaxRangeSize1, rangecolor1, rangecolordisabled1);

            RangeSize = (RangeHigh - RangeLow)/point;
            if (RangeSize >= MinRangeSize1 && RangeSize <= MaxRangeSize1){
               double pip = Pip();
               if(TradingStyle==With_Break){
                  BuyPrice = RangeHigh;
                  SellPrice = RangeLow;
         
                  BuySL = BuyPrice - StopLoss * pip;
                  BuyTP = BuyPrice + TakeProfit * pip;
         
                  SellSL = SellPrice + StopLoss * pip;
                  SellTP = SellPrice - TakeProfit * pip;
               }else {
                  BuyPrice = RangeLow;
                  SellPrice = RangeHigh;
         
                  BuySL = BuyPrice - StopLoss * pip;
                  BuyTP = BuyPrice + TakeProfit * pip;
         
                  SellSL = SellPrice + StopLoss * pip;
                  SellTP = SellPrice - TakeProfit * pip;
               }
               
               session1Levels.buyLevel = BuyPrice;
               session1Levels.sellLevel = SellPrice;
               session1Levels.buySL = BuySL;
               session1Levels.buyTP = BuyTP;
               session1Levels.sellSL = SellSL;
               session1Levels.sellTP = SellTP;
               session1Levels.active = true;
               g_prevAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               g_prevBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               g_prevInit = true;
               session1Levels.magic = magic;
               session1Levels.buyFired = false;
               session1Levels.sellFired = false;
               session1Levels.dayStamp = currentDate;
            } else {
               session1Levels.active = false;
               session1Levels.buyFired = false;
               session1Levels.sellFired = false;
            }
         }
      }
   }

//////////////////////////
   if (UseSession2){
      magic = InpMagic2;
      CheckforTradeSides(magic);
      CheckforOpenOrdersandPositions(magic);

         datetime currentTime = TimeCurrent();
         datetime currentDate = DateOnly(currentTime);
         
         if(lastCloseDateSession2 > 0){
            datetime lastDate = DateOnly(lastCloseDateSession2);
            if(currentDate != lastDate){
               lastCloseDateSession2 = 0;
            }
         }

         if (isCloseTime(TradeCloseHour2, TradeCloseMin2, currentTime)){
            datetime lastDate = (lastCloseDateSession2 > 0) ? DateOnly(lastCloseDateSession2) : 0;
            if(lastDate != currentDate && (HasPositionOrOrder(magic) || session2Levels.active)){
               CloseandResetAll(magic);
               lastCloseDateSession2 = currentTime;
            }
         }
      datetime barTime2 = iTime(_Symbol,PERIOD_CURRENT,0);
      now    = isInsideTime(RangeStartHour2, RangeStartMin2, RangeEndHour2, RangeEndMin2, barTime2);
      prev   = isInsideTime(RangeStartHour2, RangeStartMin2, RangeEndHour2, RangeEndMin2, iTime(_Symbol,PERIOD_CURRENT,1));

      datetime prevBarTime2 = iTime(_Symbol,PERIOD_CURRENT,1);
      MqlDateTime currentDT2, prevDT2;
      datetime checkTime2 = barTime2;
      TimeToStruct(checkTime2, currentDT2);
      TimeToStruct(prevBarTime2, prevDT2);
      if (TimeZone != z_Exchange){
         checkTime2 = checkTime2 - (diffTime - TimeZone)*60*60;
         prevBarTime2 = prevBarTime2 - (diffTime - TimeZone)*60*60;
         TimeToStruct(checkTime2, currentDT2);
         TimeToStruct(prevBarTime2, prevDT2);
      }

      bool shouldSetLevels2 = (prev && !now);
      if(!shouldSetLevels2 && !now && !session2Levels.active){
         int endMin2 = (int)RangeEndHour2 * 60 + (int)RangeEndMin2;
         int currentMin2 = currentDT2.hour * 60 + currentDT2.min;
         int minutesAfterEnd2 = (currentMin2 - endMin2 + 1440) % 1440;
         if(minutesAfterEnd2 >= 0 && minutesAfterEnd2 <= 120){
            shouldSetLevels2 = true;
         } else if(minutesAfterEnd2 > 0 && minutesAfterEnd2 < 1440){
            datetime barDate2 = DateOnly(barTime2);
            datetime checkTimeForDate2 = checkTime2;
            MqlDateTime sessionDT2;
            TimeToStruct(checkTimeForDate2, sessionDT2);
            sessionDT2.hour = (int)RangeEndHour2;
            sessionDT2.min = (int)RangeEndMin2;
            sessionDT2.sec = 0;
            datetime sessionEndTime2 = StructToTime(sessionDT2);
            datetime sessionEndDate2 = DateOnly(sessionEndTime2);
            if(barDate2 == sessionEndDate2 && minutesAfterEnd2 > 0){
               shouldSetLevels2 = true;
            }
         }
      }

      if (shouldSetLevels2){
         GetRange(RangeHigh, RangeLow,timestart, timeend, RangeStartHour2, RangeStartMin2, RangeEndHour2, RangeEndMin2);
         
         if(RangeHigh <= 0 || RangeLow <= 0 || RangeHigh <= RangeLow){
            session2Levels.active = false;
            session2Levels.buyFired = false;
            session2Levels.sellFired = false;
         } else {
            ShowRange(RangeHigh, RangeLow, timestart, timeend,MinRangeSize2, MaxRangeSize2, rangecolor2, rangecolordisabled2);

            RangeSize = (RangeHigh - RangeLow)/point;
            if (RangeSize >= MinRangeSize2 && RangeSize <= MaxRangeSize2){
               double pip = Pip();
               if(TradingStyle==With_Break){
                  BuyPrice = RangeHigh;
                  SellPrice = RangeLow;
         
                  BuySL = BuyPrice - StopLoss * pip;
                  BuyTP = BuyPrice + TakeProfit * pip;
         
                  SellSL = SellPrice + StopLoss * pip;
                  SellTP = SellPrice - TakeProfit * pip;
               } else {
                  BuyPrice = RangeLow;
                  SellPrice = RangeHigh;
         
                  BuySL = BuyPrice - StopLoss * pip;
                  BuyTP = BuyPrice + TakeProfit * pip;
         
                  SellSL = SellPrice + StopLoss * pip;
                  SellTP = SellPrice - TakeProfit * pip;
               }
               
               session2Levels.buyLevel = BuyPrice;
               session2Levels.sellLevel = SellPrice;
               session2Levels.buySL = BuySL;
               session2Levels.buyTP = BuyTP;
               session2Levels.sellSL = SellSL;
               session2Levels.sellTP = SellTP;
               session2Levels.active = true;
               g_prevAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               g_prevBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               g_prevInit = true;
               session2Levels.magic = magic;
               session2Levels.buyFired = false;
               session2Levels.sellFired = false;
               session2Levels.dayStamp = currentDate;
            } else {
               session2Levels.active = false;
               session2Levels.buyFired = false;
               session2Levels.sellFired = false;
            }
         }

      }
   }

   if (UseSession0){
      magic = InpMagic0; 
      CheckforTradeSides(magic);
      CheckforOpenOrdersandPositions(magic);

//      if (BuyTotal+SellTotal > 0){

         datetime currentTime = TimeCurrent();
         datetime currentDate = DateOnly(currentTime);
         
         if(lastCloseDateSession0 > 0){
            datetime lastDate = DateOnly(lastCloseDateSession0);
            if(currentDate != lastDate){
               lastCloseDateSession0 = 0;
            }
         }

         if (isCloseTime(TradeCloseHour0, TradeCloseMin0, currentTime)){
            datetime lastDate = (lastCloseDateSession0 > 0) ? DateOnly(lastCloseDateSession0) : 0;
            if(lastDate != currentDate && (HasPositionOrOrder(magic) || session0Levels.active)){
               CloseandResetAll(magic);
               lastCloseDateSession0 = currentTime;
            }
         }
  //    }
      now    = iBarShift(_Symbol,PERIOD_D1, iTime(_Symbol,PERIOD_CURRENT,0));
      prev   = iBarShift(_Symbol,PERIOD_D1, iTime(_Symbol,PERIOD_CURRENT,1));
      
      if (prev != now){
         
         RangeHigh = iHigh(_Symbol,PERIOD_D1,1);
         RangeLow = iLow(_Symbol,PERIOD_D1,1);

         // Validate range values
         if(RangeHigh <= 0 || RangeLow <= 0 || RangeHigh <= RangeLow){
            session0Levels.active = false;
            session0Levels.buyFired = false;
            session0Levels.sellFired = false;
         } else {
         RangeSize = (RangeHigh - RangeLow)/point; 
         if (RangeSize >= MinRangeSize0 && RangeSize <= MaxRangeSize0){
            double pip = Pip();
            if(TradingStyle==With_Break){
               BuyPrice = RangeHigh;
               SellPrice = RangeLow;
      
               BuySL = BuyPrice - StopLoss * pip;
               BuyTP = BuyPrice + TakeProfit * pip;
      
               SellSL = SellPrice + StopLoss * pip;
               SellTP = SellPrice - TakeProfit * pip;
            } else {
               BuyPrice = RangeLow;
               SellPrice = RangeHigh;
      
               BuySL = BuyPrice - StopLoss * pip;
               BuyTP = BuyPrice + TakeProfit * pip;
      
               SellSL = SellPrice + StopLoss * pip;
               SellTP = SellPrice - TakeProfit * pip;
            }
               
               session0Levels.buyLevel = BuyPrice;
               session0Levels.sellLevel = SellPrice;
               session0Levels.buySL = BuySL;
               session0Levels.buyTP = BuyTP;
               session0Levels.sellSL = SellSL;
               session0Levels.sellTP = SellTP;
               session0Levels.active = true;
               g_prevAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               g_prevBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               g_prevInit = true;
               session0Levels.magic = magic;
               session0Levels.buyFired = false;
               session0Levels.sellFired = false;
               session0Levels.dayStamp = currentDate;
            } else {
               session0Levels.active = false;
               session0Levels.buyFired = false;
               session0Levels.sellFired = false;
            }
         }
      }
   }




//   CheckforOpenOrdersandPositions();
//   DPrint(StringFormat("[STATE] BuyTotal=%d SellTotal=%d", BuyTotal, SellTotal));

//   if(SLT==Yes && (BuyTotal>0 || SellTotal>0)) TrailSL();


/*
   ConvertTimes();

   if(IsInsideTime()){
      RangeHigh = GetHigh();
      RangeLow  = GetLow();
      RangeSize = RangeHigh - RangeLow;

      double pip = Pip();
      double rpips = (pip>0.0 ? RangeSize/pip : 0.0);

      if(LogPipMath)
         DPrint(StringFormat("[RANGE] High=%.10f Low=%.10f Size=%.10f (pips=%.2f) Limits=[%d..%d] pips",
                             RangeHigh, RangeLow, RangeSize, rpips, MinRangeSize, MaxRangeSize));
      else
         DPrint(StringFormat("[RANGE] High=%.10f Low=%.10f Size=%.10f", RangeHigh, RangeLow));

      // compute UsedRangeSize (clamp if enabled)
      UsedRangeSize = RangeSize;
      if(pip>0.0){
         if(rpips < MinRangeSize || rpips > MaxRangeSize){
            if(AllowRangeClampIfOutside){
               double used_pips = MathMin(MathMax(rpips, (double)MinRangeSize), (double)MaxRangeSize);
               UsedRangeSize = used_pips * pip;
               DPrint(StringFormat("[CLAMP] UsedRange=%.10f (%.2f pips)", UsedRangeSize, used_pips));
            }else{
               DPrint("[SKIP] Range outside bounds; clamping disabled.");
               ShowRange(RangeHigh, RangeLow);
               return;
            }
         }
      }
      ShowRange(RangeHigh, RangeLow);
   }else{
      DPrint("[INFO] Not yet inside range-building time.");
   }

   PrepareOrder();

   if(TimeCurrent() > timeclose){
      DPrint("[INFO] Close time reached -> closing & reset");
      CloseandResetAll();
   }
*/

}
/*
// ====================== Time & Range helpers ======================
void ConvertTimes(){
   TimeToStruct(TimeCurrent(), starttime); starttime.hour=(int)RangeStartHour; starttime.min=(int)RangeStartMin; starttime.sec=0; timestart=StructToTime(starttime);
   TimeToStruct(TimeCurrent(), endtime);   endtime.hour  =(int)RangeEndHour;   endtime.min  =(int)RangeEndMin;   endtime.sec=0;   timeend  =StructToTime(endtime);
   TimeToStruct(TimeCurrent(), closetime); closetime.hour=(int)TradeCloseHour; closetime.min=(int)TradeCloseMin; closetime.sec=0; timeclose=StructToTime(closetime);

   if(BarsRangeStart==0 && TimeCurrent()>=timestart){
      BarsRangeStart = iBars(_Symbol, PERIOD_CURRENT);
      // session reset
      placedBuy=false; placedSell=false;
      lastBuyPrice=0.0; lastSellPrice=0.0;
      DPrint(StringFormat("[TIME] BarsRangeStart=%d", BarsRangeStart));
   }
   DPrint(StringFormat("[TIME] start=%s end=%s close=%s",
      TimeToString(timestart, TIME_DATE|TIME_MINUTES),
      TimeToString(timeend,   TIME_DATE|TIME_MINUTES),
      TimeToString(timeclose, TIME_DATE|TIME_MINUTES)));
}*/
/*
double GetHigh(){
   if(TimeCurrent()>timestart && TimeCurrent()<timeend){
      BarstoCount = iBars(_Symbol, PERIOD_CURRENT) - BarsRangeStart + 1;
      int highestbar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, BarstoCount, 0);
      double high    = iHigh(_Symbol, PERIOD_CURRENT, highestbar);
      if(DebugOn) DPrint(StringFormat("[HIGH] bars=%d idx=%d val=%.10f", BarstoCount, highestbar, high));
      if(high != RangeHigh) return high;
   }
   return RangeHigh;
}

double GetLow(){
   if(TimeCurrent()>timestart && TimeCurrent()<timeend){
      BarstoCount = iBars(_Symbol, PERIOD_CURRENT) - BarsRangeStart + 1;
      int lowestbar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, BarstoCount, 0);
      double low    = iLow(_Symbol, PERIOD_CURRENT, lowestbar);
      if(DebugOn) DPrint(StringFormat("[LOW ] bars=%d idx=%d val=%.10f", BarstoCount, lowestbar, low));
      if(low != RangeLow) return low;
   }
   return RangeLow;
}
*/

void ShowRange(double high, double low, datetime timestart, datetime timeend,double MinRangeSize, double MaxRangeSize, color rangecolor, color rangecolordisabled){
   if(ObjectFind(0,"range")<0) ObjectCreate(0, "range", OBJ_RECTANGLE, 0, timestart, high, timeend, low);
   else { ObjectMove(0,"range",0,timestart,high); ObjectMove(0,"range",1,timeend,low); }

   double pip=Pip(), rpips = (pip>0.0? (high-low)/pip : 0.0);
   bool inside = (rpips>=MinRangeSize && rpips<=MaxRangeSize);

   ObjectSetInteger(0,"range", OBJPROP_COLOR, inside? rangecolor: rangecolordisabled);
   ObjectSetInteger(0,"range", OBJPROP_FILL,  true);

/*
   if(ObjectFind(0,"tradingtime")<0) ObjectCreate(0,"tradingtime", OBJ_RECTANGLE, 0, timeend, high, timeclose, low);
   else { ObjectMove(0,"tradingtime",0,timeend,high); ObjectMove(0,"tradingtime",1,timeclose,low); }
   ObjectSetInteger(0,"tradingtime", OBJPROP_COLOR, rangecolor);
   ObjectSetInteger(0,"tradingtime", OBJPROP_FILL,  false);


   if(ObjectFind(0,"endtime")<0) ObjectCreate(0,"endtime", OBJ_VLINE, 0, timeclose, 0.0);
   else ObjectMove(0,"endtime",0,timeclose,0.0);
   ObjectSetInteger(0,"endtime", OBJPROP_COLOR, rangecolor);
*/   
}

/*
bool IsInsideTime(){
   MqlDateTime start, now; TimeToStruct(TimeCurrent(), now); TimeToStruct(timestart, start);
   int nowmin = now.hour*60 + now.min; int startmin = start.hour*60 + start.min;
   return (nowmin >= startmin);
}*/

// ============================ Entries ==============================
// De-dup near a price (tol set inside)
/*
bool HasPendingNear(ENUM_ORDER_TYPE type, double price, double tol_points=0.0){
   if(tol_points<=0.0) tol_points = 2.0*_Point;
   for(int i=OrdersTotal()-1; i>=0; --i){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol()!=_Symbol || ordinfo.Magic()!=InpMagic) continue;
      if((ENUM_ORDER_TYPE)ordinfo.Type()!=type) continue;
      double p = ordinfo.PriceOpen();
      if(MathAbs(p - price) <= tol_points) return true;
   }
   return false;
}
*/
/*
// Compute raw SL/TP (before broker constraints)
void ComputeSLTP(ENUM_ORDER_TYPE type, double entry_raw, double &sl_raw, double &tp_raw){
   double pip = Pip();
   if(TPSL_Mode==TPSL_FixedPips){
      double sldist = MathMax(1, sl_fixed_pips) * pip;
      double tpdist = MathMax(1, tp_fixed_pips) * pip;
      if(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP){
         sl_raw = entry_raw - sldist;
         tp_raw = entry_raw + tpdist;
      }else{
         sl_raw = entry_raw + sldist;
         tp_raw = entry_raw - tpdist;
      }
   }else{ // TPSL_RangePercent
      double sldist = UsedRangeSize * (double)SLPercent/100.0;
      double tpdist = sldist * (double)TPPercent/100.0;
      if(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP){
         sl_raw = entry_raw - sldist;
         tp_raw = entry_raw + tpdist;
      }else{
         sl_raw = entry_raw + sldist;
         tp_raw = entry_raw - tpdist;
      }
   }
}

void PrepareOrder(){
   if(TimeCurrent()<=timeend || TimeCurrent()>=timeclose){
      DPrint("[SKIP] Not in placement window (need timeend < now < timeclose)");
      return;
   }

   // inner band using UsedRangeSize
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double innerTop     = RangeHigh - (UsedRangeSize*OrdDistpct/100.0);
   double innerBottom  = RangeLow  + (UsedRangeSize*OrdDistpct/100.0);

   if(DebugPrices)
      DPrint(StringFormat("[BAND] innerBottom=%.10f innerTop=%.10f UsedRange=%.10f", innerBottom, innerTop, UsedRangeSize));

   double mid = (bid+ask)/2.0;

   bool allowPlace = true;
   if(PlaceImmediatelyAtEnd){
      // allow right after end window opens, no band requirement
      allowPlace = true;
   }else if(!RequireInnerBandForPlacement){
      allowPlace = true;
   }else{
      if(!(mid < innerTop && mid > innerBottom)){
         DPrint(StringFormat("[SKIP] mid=%.10f not inside inner band", mid));
         allowPlace=false;
      } else if(DebugPrices) {
         DPrint(StringFormat("[OK  ] mid=%.10f inside inner band", mid));
      }
   }
   if(!allowPlace) return;

   if(TradingStyle==With_Break){
      if(BuyTotal<=0  && MA_BuyOn  && Ichi_BuyOn)  OpenTrade(ORDER_TYPE_BUY_STOP,  RangeHigh);
      if(SellTotal<=0 && MA_SellOn && Ichi_SellOn) OpenTrade(ORDER_TYPE_SELL_STOP, RangeLow);
   }else{ // Opposite_to_Break
      if(BuyTotal<=0  && MA_BuyOn  && Ichi_BuyOn)  OpenTrade(ORDER_TYPE_BUY_LIMIT,  RangeLow);
      if(SellTotal<=0 && MA_SellOn && Ichi_SellOn) OpenTrade(ORDER_TYPE_SELL_LIMIT, RangeHigh);
   }
}
*/
bool SendMarketOrder(bool isBuy, double lots, double sl, double tp, ulong Magic){
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPoints = (ask - bid) / _Point;
   
   if(spreadPoints > MaxSpreadPoints){
      DPrint(StringFormat("[SPREAD] Blocked: spread=%.1f points > max=%.1f", spreadPoints, MaxSpreadPoints));
      return false;
   }
   
   if(UseNewsFilter && IsNewsTime()){
      if(DebugNews) DPrint("[NEWS] Blocked by news filter");
      return false;
   }
   
   double entryPrice = isBuy ? ask : bid;
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   int digits = DigitsForSymbol();
   
   if(isBuy){
      if(sl > 0 && (entryPrice - sl) < minStop){
         sl = NormalizeDouble(entryPrice - minStop - _Point, digits);
         if(DebugOn) DPrint(StringFormat("[SL/TP] BUY SL adjusted to: %.5f", sl));
      }
      if(tp > 0 && (tp - entryPrice) < minStop){
         tp = NormalizeDouble(entryPrice + minStop + _Point, digits);
         if(DebugOn) DPrint(StringFormat("[SL/TP] BUY TP adjusted to: %.5f", tp));
      }
   } else {
      if(sl > 0 && (sl - entryPrice) < minStop){
         sl = NormalizeDouble(entryPrice + minStop + _Point, digits);
         if(DebugOn) DPrint(StringFormat("[SL/TP] SELL SL adjusted to: %.5f", sl));
      }
      if(tp > 0 && (entryPrice - tp) < minStop){
         tp = NormalizeDouble(entryPrice - minStop - _Point, digits);
         if(DebugOn) DPrint(StringFormat("[SL/TP] SELL TP adjusted to: %.5f", tp));
      }
   }
   
   if(sl > 0) sl = NormalizeDouble(sl, digits);
   if(tp > 0) tp = NormalizeDouble(tp, digits);
   
   trade.SetExpertMagicNumber(Magic);
   ResetLastError();
   
   bool ok = false;
   if(isBuy){
      ok = trade.Buy(lots, _Symbol, 0, sl, tp, TradeComment);
   } else {
      ok = trade.Sell(lots, _Symbol, 0, sl, tp, TradeComment);
   }
   
   uint   retcode = trade.ResultRetcode();
   string rdesc   = trade.ResultRetcodeDescription();
   ulong  order   = trade.ResultOrder();
   ulong  deal    = trade.ResultDeal();
   
   if(ok)  DPrint(StringFormat("[OK  ] Market %s lots=%.2f sl=%.10f tp=%.10f ret=%u '%s' order=%I64u deal=%I64u", 
                                isBuy?"BUY":"SELL", lots, sl, tp, retcode, rdesc, order, deal));
   else    DPrint(StringFormat("[FAIL] Market %s ret=%u '%s' lastError=%d", 
                                isBuy?"BUY":"SELL", retcode, rdesc, GetLastError()));
   
   return ok;
}

void MonitorLevels(){
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime currentDate = DateOnly(iTime(_Symbol, PERIOD_CURRENT, 0));
   datetime currentTime = TimeCurrent();

   if(!g_prevInit){
      g_prevAsk = ask;
      g_prevBid = bid;
      g_prevInit = true;
      return;
   }

   int symbolBuyTotal = GetSymbolSideTotal(true);
   int symbolSellTotal = GetSymbolSideTotal(false);
   
   if(UseSession0 && session0Levels.active){
      if(session0Levels.dayStamp != currentDate){
         session0Levels.buyFired = false;
         session0Levels.sellFired = false;
         session0Levels.active = false;
         session0Levels.dayStamp = currentDate;
      }
      int buyCount = GetBuyTotal(session0Levels.magic);
      int sellCount = GetSellTotal(session0Levels.magic);

      if(isCloseTime(TradeCloseHour0, TradeCloseMin0, currentTime)){
         session0Levels.active = false;
         session0Levels.buyFired = true;
         session0Levels.sellFired = true;
      }

      if(session0Levels.active){

      if(TradingStyle == With_Break){
         if(g_prevAsk < session0Levels.buyLevel && ask >= session0Levels.buyLevel && buyCount == 0 && symbolBuyTotal==0 && !session0Levels.buyFired && PriceWithinTolerance(ask, session0Levels.buyLevel)){
            int _points = (int)(MathAbs(session0Levels.buyLevel - session0Levels.buySL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(true, lots, session0Levels.buySL, session0Levels.buyTP, session0Levels.magic)){
               session0Levels.buyFired = true;
               session0Levels.sellFired = true;
               session0Levels.active = false;
            }
         }
         if(g_prevBid > session0Levels.sellLevel && bid <= session0Levels.sellLevel && sellCount == 0 && symbolSellTotal==0 && !session0Levels.sellFired && PriceWithinTolerance(bid, session0Levels.sellLevel)){
            int _points = (int)(MathAbs(session0Levels.sellLevel - session0Levels.sellSL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(false, lots, session0Levels.sellSL, session0Levels.sellTP, session0Levels.magic)){
               session0Levels.sellFired = true;
               session0Levels.buyFired = true;
               session0Levels.active = false;
            }
         }
      } else {
         if(g_prevBid > session0Levels.buyLevel && bid <= session0Levels.buyLevel && buyCount == 0 && symbolBuyTotal==0 && !session0Levels.buyFired && PriceWithinTolerance(bid, session0Levels.buyLevel)){
            int _points = (int)(MathAbs(session0Levels.buyLevel - session0Levels.buySL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(true, lots, session0Levels.buySL, session0Levels.buyTP, session0Levels.magic)){
               session0Levels.buyFired = true;
               session0Levels.sellFired = true;
               session0Levels.active = false;
            }
         }
         if(g_prevAsk < session0Levels.sellLevel && ask >= session0Levels.sellLevel && sellCount == 0 && symbolSellTotal==0 && !session0Levels.sellFired && PriceWithinTolerance(ask, session0Levels.sellLevel)){
            int _points = (int)(MathAbs(session0Levels.sellLevel - session0Levels.sellSL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(false, lots, session0Levels.sellSL, session0Levels.sellTP, session0Levels.magic)){
               session0Levels.sellFired = true;
               session0Levels.buyFired = true;
               session0Levels.active = false;
            }
         }
      }
      }
   }
   
   if(UseSession1 && session1Levels.active){
      if(session1Levels.dayStamp != currentDate){
         session1Levels.buyFired = false;
         session1Levels.sellFired = false;
         session1Levels.active = false;
         session1Levels.dayStamp = currentDate;
      }
      int buyCount = GetBuyTotal(session1Levels.magic);
      int sellCount = GetSellTotal(session1Levels.magic);

      if(isCloseTime(TradeCloseHour1, TradeCloseMin1, currentTime)){
         session1Levels.active = false;
         session1Levels.buyFired = true;
         session1Levels.sellFired = true;
      }

      if(session1Levels.active){

      if(TradingStyle == With_Break){
         if(g_prevAsk < session1Levels.buyLevel && ask >= session1Levels.buyLevel && buyCount == 0 && symbolBuyTotal==0 && !session1Levels.buyFired && PriceWithinTolerance(ask, session1Levels.buyLevel)){
            int _points = (int)(MathAbs(session1Levels.buyLevel - session1Levels.buySL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(true, lots, session1Levels.buySL, session1Levels.buyTP, session1Levels.magic)){
               session1Levels.buyFired = true;
               session1Levels.sellFired = true;
               session1Levels.active = false;
            }
         }
         if(g_prevBid > session1Levels.sellLevel && bid <= session1Levels.sellLevel && sellCount == 0 && symbolSellTotal==0 && !session1Levels.sellFired && PriceWithinTolerance(bid, session1Levels.sellLevel)){
            int _points = (int)(MathAbs(session1Levels.sellLevel - session1Levels.sellSL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(false, lots, session1Levels.sellSL, session1Levels.sellTP, session1Levels.magic)){
               session1Levels.sellFired = true;
               session1Levels.buyFired = true;
               session1Levels.active = false;
            }
         }
      } else {
         if(g_prevBid > session1Levels.buyLevel && bid <= session1Levels.buyLevel && buyCount == 0 && symbolBuyTotal==0 && !session1Levels.buyFired && PriceWithinTolerance(bid, session1Levels.buyLevel)){
            int _points = (int)(MathAbs(session1Levels.buyLevel - session1Levels.buySL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(true, lots, session1Levels.buySL, session1Levels.buyTP, session1Levels.magic)){
               session1Levels.buyFired = true;
               session1Levels.sellFired = true;
               session1Levels.active = false;
            }
         }
         if(g_prevAsk < session1Levels.sellLevel && ask >= session1Levels.sellLevel && sellCount == 0 && symbolSellTotal==0 && !session1Levels.sellFired && PriceWithinTolerance(ask, session1Levels.sellLevel)){
            int _points = (int)(MathAbs(session1Levels.sellLevel - session1Levels.sellSL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(false, lots, session1Levels.sellSL, session1Levels.sellTP, session1Levels.magic)){
               session1Levels.sellFired = true;
               session1Levels.buyFired = true;
               session1Levels.active = false;
            }
         }
      }
      }
   }
   
   if(UseSession2 && session2Levels.active){
      if(session2Levels.dayStamp != currentDate){
         session2Levels.buyFired = false;
         session2Levels.sellFired = false;
         session2Levels.active = false;
         session2Levels.dayStamp = currentDate;
      }
      int buyCount = GetBuyTotal(session2Levels.magic);
      int sellCount = GetSellTotal(session2Levels.magic);

      if(isCloseTime(TradeCloseHour2, TradeCloseMin2, currentTime)){
         session2Levels.active = false;
         session2Levels.buyFired = true;
         session2Levels.sellFired = true;
      }

      if(session2Levels.active){

      if(TradingStyle == With_Break){
         if(g_prevAsk < session2Levels.buyLevel && ask >= session2Levels.buyLevel && buyCount == 0 && symbolBuyTotal==0 && !session2Levels.buyFired && PriceWithinTolerance(ask, session2Levels.buyLevel)){
            int _points = (int)(MathAbs(session2Levels.buyLevel - session2Levels.buySL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(true, lots, session2Levels.buySL, session2Levels.buyTP, session2Levels.magic)){
               session2Levels.buyFired = true;
               session2Levels.sellFired = true;
               session2Levels.active = false;
            }
         }
         if(g_prevBid > session2Levels.sellLevel && bid <= session2Levels.sellLevel && sellCount == 0 && symbolSellTotal==0 && !session2Levels.sellFired && PriceWithinTolerance(bid, session2Levels.sellLevel)){
            int _points = (int)(MathAbs(session2Levels.sellLevel - session2Levels.sellSL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(false, lots, session2Levels.sellSL, session2Levels.sellTP, session2Levels.magic)){
               session2Levels.sellFired = true;
               session2Levels.buyFired = true;
               session2Levels.active = false;
            }
         }
      } else {
         if(g_prevBid > session2Levels.buyLevel && bid <= session2Levels.buyLevel && buyCount == 0 && symbolBuyTotal==0 && !session2Levels.buyFired && PriceWithinTolerance(bid, session2Levels.buyLevel)){
            int _points = (int)(MathAbs(session2Levels.buyLevel - session2Levels.buySL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(true, lots, session2Levels.buySL, session2Levels.buyTP, session2Levels.magic)){
               session2Levels.buyFired = true;
               session2Levels.sellFired = true;
               session2Levels.active = false;
            }
         }
         if(g_prevAsk < session2Levels.sellLevel && ask >= session2Levels.sellLevel && sellCount == 0 && symbolSellTotal==0 && !session2Levels.sellFired && PriceWithinTolerance(ask, session2Levels.sellLevel)){
            int _points = (int)(MathAbs(session2Levels.sellLevel - session2Levels.sellSL) / _Point);
            double lots = getLot(_points);
            if(SendMarketOrder(false, lots, session2Levels.sellSL, session2Levels.sellTP, session2Levels.magic)){
               session2Levels.sellFired = true;
               session2Levels.buyFired = true;
               session2Levels.active = false;
            }
         }
      }
      }
   }
   
   g_prevAsk = ask;
   g_prevBid = bid;
}
/*
void OpenTrade(ENUM_ORDER_TYPE type, double entry_anchor){
   LogSymbolSnapshot();

   // one-per-side per session guard
   if(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP){
      if(placedBuy){ DPrint("[SKIP] Buy side already placed this session"); return; }
   }else{
      if(placedSell){ DPrint("[SKIP] Sell side already placed this session"); return; }
   }

   // filters (final gate)
   if(MAFilterOn){
      string ma = PricevsMovAvg();
      if(DebugFilters) Ds2("[MA  ] relation=%s for %s", ma, (type==ORDER_TYPE_SELL_LIMIT||type==ORDER_TYPE_SELL_STOP)?"SELL":"BUY");
      if((type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP) && (ma=="below" || ma=="error")) { MA_BuyOn=false;  DPrint("[BLOCK] MA blocked BUY");  return; }
      if((type==ORDER_TYPE_SELL_LIMIT|| type==ORDER_TYPE_SELL_STOP) && (ma=="above" || ma=="error")) { MA_SellOn=false; DPrint("[BLOCK] MA blocked SELL"); return; }
   }
   if(IchimokuFilter){
      string ic = PricevsIchiCloud();
      if(DebugFilters) Ds2("[ICHI] relation=%s for %s", ic, (type==ORDER_TYPE_SELL_LIMIT||type==ORDER_TYPE_SELL_STOP)?"SELL":"BUY");
      if((type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP) && (ic=="below" || ic=="Incloud")) { Ichi_BuyOn=false;  DPrint("[BLOCK] Ichi blocked BUY");  return; }
      if((type==ORDER_TYPE_SELL_LIMIT|| type==ORDER_TYPE_SELL_STOP) && (ic=="above" || ic=="Incloud")) { Ichi_SellOn=false; DPrint("[BLOCK] Ichi blocked SELL"); return; }
   }

   // SL/TP from mode
   double sl_raw=0.0, tp_raw=0.0;
   ComputeSLTP(type, entry_anchor, sl_raw, tp_raw);

   // broker constraints
   double price = AdjustPriceForStops(type, entry_anchor);
   double sl    = AdjustSLForStops(type, price, sl_raw);
   double tp    = NormalizeDouble(tp_raw, DigitsForSymbol());

   // de-dup near identical pending price
   if(HasPendingNear(type, price)){
      DPrint("[SKIP] Duplicate pending exists near same price");
      return;
   }

   // risk-based lot size
   double base = UseEquityForRisk ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = base * (RiskPercent/100.0);
   double perLotLoss = OneLotLossAtSL(type, price, sl);

   double lots = FixedLotSize;
   if(LotSizeType==RiskPct){
      if(perLotLoss<=0.0){
         DPrint("[WARN] perLotLoss <= 0, fallback to min lot.");
         lots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      }else{
         lots = riskMoney / perLotLoss;
      }
      double minv  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double maxv  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      if(step>0.0) lots = MathFloor(lots/step)*step;
      if(maxv>0.0) lots = MathMin(lots, maxv);
      if(minv>0.0) lots = MathMax(lots, minv);
      lots = NormalizeDouble(lots, 2);
   }

   D3("[LOT ] riskMoney=%.2f perLotLoss=%.2f lots=%.2f", riskMoney, perLotLoss, lots);
   if(DebugPrices) D3("[PRC ] entry=%.10f SL=%.10f TP=%.10f", price, sl, tp);

   if(!SendPending(type, lots, price, sl, tp)){
      DPrint("[NOTE] Server rejected the order. See retcode above.");
      return;
   }
   if(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP){
      placedBuy=true;  lastBuyPrice=price;
   }else{
      placedSell=true; lastSellPrice=price;
   }
}*/

void ClosePending(ulong Magic){

      if ( OrdersTotal() > 0 )
      {
         for (int i = OrdersTotal() - 1 ; i >= 0 ; i--)
         {
            if (!ordinfo.SelectByIndex(i)) {break;}
            if (ordinfo.Magic() == Magic  && ordinfo.Symbol() == _Symbol)
            {
                trade.OrderDelete(ordinfo.Ticket());
            }
         }
     }


}

// ======================== Housekeeping =============================
void CloseandResetAll(ulong magic){

   ClosePending(magic);

   for(int i=PositionsTotal()-1; i>=0; i--){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()==_Symbol && posinfo.Magic()==magic){
         DPrint(StringFormat("[CLS ] closing pos %I64u", posinfo.Ticket()));
         trade.PositionClose(posinfo.Ticket());
      }
   }
   for(int i=OrdersTotal()-1; i>=0; i--){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol()==_Symbol && ordinfo.Magic()==magic){
         DPrint(StringFormat("[DEL ] deleting ord %I64u", ordinfo.Ticket()));
         trade.OrderDelete(ordinfo.Ticket());
      }
   }

   datetime currentDate = DateOnly(TimeCurrent());
   if(magic == InpMagic0){
      session0Levels.active = false;
      session0Levels.buyFired = false;
      session0Levels.sellFired = false;
      session0Levels.dayStamp = currentDate;
   }
   if(magic == InpMagic1){
      session1Levels.active = false;
      session1Levels.buyFired = false;
      session1Levels.sellFired = false;
      session1Levels.dayStamp = currentDate;
   }
   if(magic == InpMagic2){
      session2Levels.active = false;
      session2Levels.buyFired = false;
      session2Levels.sellFired = false;
      session2Levels.dayStamp = currentDate;
   }
   
   placedBuy=false; placedSell=false;
   lastBuyPrice=0.0; lastSellPrice=0.0;
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
}
/*
void TrailSL(){
   for(int i=PositionsTotal()-1; i>=0; --i){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()!=_Symbol || posinfo.Magic()!=InpMagic) continue;

      ulong ticket = posinfo.Ticket();
      ENUM_POSITION_TYPE postype = posinfo.PositionType();
      double price = (postype==POSITION_TYPE_BUY)? SymbolInfoDouble(_Symbol,SYMBOL_BID): SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl = posinfo.StopLoss();
      double tp = posinfo.TakeProfit();

      if(TrailType==RangePct){
         if(postype==POSITION_TYPE_BUY){
            if(price > posinfo.PriceOpen()){
               double nsl = NormalizeDouble(price - UsedRangeSize*TrailRangePct/100.0, DigitsForSymbol());
               if(nsl>sl){ D2("[TSL ] BUY Range%% -> %.10f -> %.10f", sl, nsl); trade.PositionModify(ticket, nsl, tp); }
            }
         }else{
            if(price < posinfo.PriceOpen()){
               double nsl = NormalizeDouble(price + UsedRangeSize*TrailRangePct/100.0, DigitsForSymbol());
               if(nsl<sl){ D2("[TSL ] SELL Range%% -> %.10f -> %.10f", sl, nsl); trade.PositionModify(ticket, nsl, tp); }
            }
         }
      }else if(TrailType==HighLow){
         double high = findHigh();
         double low  = findLow();
         if(postype==POSITION_TYPE_BUY && low>0){
            double nsl = NormalizeDouble(low - HighLowBuffer*Pip(), DigitsForSymbol());
            if(nsl>sl){ D2("[TSL ] BUY HL -> %.10f -> %.10f", sl, nsl); trade.PositionModify(ticket, nsl, tp); }
         }else if(postype==POSITION_TYPE_SELL && high>0){
            double nsl = NormalizeDouble(high + HighLowBuffer*Pip(), DigitsForSymbol());
            if(nsl<sl){ D2("[TSL ] SELL HL -> %.10f -> %.10f", sl, nsl); trade.PositionModify(ticket, nsl, tp); }
         }
      }else if(TrailType==Fixedpips){
         double dist = MathMax(1, TrailFixedpips)*Pip();
         if(postype==POSITION_TYPE_BUY){
            double nsl = NormalizeDouble(price - dist, DigitsForSymbol());
            if(nsl>sl){ D2("[TSL ] BUY FIX -> %.10f -> %.10f", sl, nsl); trade.PositionModify(ticket, nsl, tp); }
         }else{
            double nsl = NormalizeDouble(price + dist, DigitsForSymbol());
            if(nsl<sl){ D2("[TSL ] SELL FIX -> %.10f -> %.10f", sl, nsl); trade.PositionModify(ticket, nsl, tp); }
         }
      }
   }
}
*/

void Trailing(ulong magic){

   double sl = 0;

   if ( PositionsTotal() > 0 )
   {
      for (int i = PositionsTotal() - 1 ; i >= 0 ; i--)
         {
            if (!posinfo.SelectByIndex(i)) {break;}
            if (posinfo.Magic() == magic && posinfo.Symbol() == _Symbol)
            {
               if (posinfo.PositionType() == POSITION_TYPE_BUY){               
                  double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
                  if (price - posinfo.PriceOpen() <= 0) {continue;}
                     
                  double pip = Pip();
                 if(price-posinfo.PriceOpen()>=TrailingStart*pip)
                  {
                       double newSL = price - TrailingStop*pip;
                       double currentSL = posinfo.StopLoss();
                       
                       bool shouldModify = false;
                       if(currentSL == 0 || currentSL < posinfo.PriceOpen()){
                          shouldModify = true;
                       } else if(newSL > currentSL + TrailingStep*pip){
                          shouldModify = true;
                       }
                       
                       if(shouldModify){
                          trade.PositionModify(posinfo.Ticket(), newSL, posinfo.TakeProfit());
                       }
                  }
                     
               } else if (posinfo.PositionType() == POSITION_TYPE_SELL){
                  double price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                  if (price - posinfo.PriceOpen() >= 0) {continue;}
                     
                  double pip = Pip();
                 if((posinfo.PriceOpen()-price)>TrailingStart*pip)
                  {
                       double newSL = price + TrailingStop*pip;
                       double currentSL = posinfo.StopLoss();
                       
                       bool shouldModify = false;
                       if(currentSL == 0 || currentSL > posinfo.PriceOpen()){
                          shouldModify = true;
                       } else if(newSL < currentSL - TrailingStep*pip){
                          shouldModify = true;
                       }
                       
                       if(shouldModify){
                          trade.PositionModify(posinfo.Ticket(), newSL, posinfo.TakeProfit());
                       }
                     }
                     
                     
               }
            }
         }
     }

}  

void CheckforTradeSides(ulong magic=0){
   if(TradingSides==Bothside) return;

   int openPos=0;
   for(int i=PositionsTotal()-1; i>=0; --i){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()==_Symbol && posinfo.Magic()==magic) openPos++;
   }
   if(openPos>0){
      for(int i=OrdersTotal()-1; i>=0; --i){
         if(!ordinfo.SelectByIndex(i)) continue;
         if(ordinfo.Symbol()==_Symbol && ordinfo.Magic()==magic)
            trade.OrderDelete(ordinfo.Ticket());
      }
   }
}

// ============================= Utils ===============================
datetime DateOnly(datetime t){
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
}

bool IsNewBar(){
   static datetime previousTime=0;
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(previousTime!=currentTime){ previousTime=currentTime; return true; }
   return false;
}

double calcLots_fallback(double slPoints){
   double ticksize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(slPoints < 0) slPoints = -slPoints;
   if(ticksize<=0 || slPoints<ticksize)
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double base       = UseEquityForRisk ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
   double risk       = base * RiskPercent / 100.0;
   double tickvalue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotstep    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minvolume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxvolume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumelimit= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

   double moneyPerLotstep = (slPoints / ticksize) * tickvalue * lotstep;
   if(moneyPerLotstep <= 0.0) return minvolume;

   double lots = MathFloor(risk / moneyPerLotstep / lotstep) * lotstep;

   if(volumelimit>0) lots = MathMin(lots, volumelimit);
   if(maxvolume>0)   lots = MathMin(lots, maxvolume);
   if(minvolume>0)   lots = MathMax(lots, minvolume);
   return NormalizeDouble(lots, 2);
}

void CheckforOpenOrdersandPositions(ulong magic=0){
   BuyTotal=0; SellTotal=0;

   for(int i=OrdersTotal()-1; i>=0; --i){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol()!=_Symbol || ordinfo.Magic()!=magic) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)ordinfo.Type();
      if(t==ORDER_TYPE_BUY_STOP || t==ORDER_TYPE_BUY_LIMIT)   BuyTotal++;
      if(t==ORDER_TYPE_SELL_STOP|| t==ORDER_TYPE_SELL_LIMIT)  SellTotal++;
   }
   for(int i=PositionsTotal()-1; i>=0; --i){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()!=_Symbol || posinfo.Magic()!=magic) continue;
      ENUM_POSITION_TYPE pt = posinfo.PositionType();
      if(pt==POSITION_TYPE_BUY)  BuyTotal++;
      if(pt==POSITION_TYPE_SELL) SellTotal++;
   }
}

int GetBuyTotal(ulong magic){
   int count = 0;
   for(int i=OrdersTotal()-1; i>=0; --i){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol()!=_Symbol || ordinfo.Magic()!=magic) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)ordinfo.Type();
      if(t==ORDER_TYPE_BUY_STOP || t==ORDER_TYPE_BUY_LIMIT) count++;
   }
   for(int i=PositionsTotal()-1; i>=0; --i){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()!=_Symbol || posinfo.Magic()!=magic) continue;
      if(posinfo.PositionType()==POSITION_TYPE_BUY) count++;
   }
   return count;
}

int GetSellTotal(ulong magic){
   int count = 0;
   for(int i=OrdersTotal()-1; i>=0; --i){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol()!=_Symbol || ordinfo.Magic()!=magic) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)ordinfo.Type();
      if(t==ORDER_TYPE_SELL_STOP || t==ORDER_TYPE_SELL_LIMIT) count++;
   }
   for(int i=PositionsTotal()-1; i>=0; --i){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()!=_Symbol || posinfo.Magic()!=magic) continue;
      if(posinfo.PositionType()==POSITION_TYPE_SELL) count++;
   }
   return count;
}

#ifndef __GET_SYMBOL_SIDE_TOTAL_DEFINED__
#define __GET_SYMBOL_SIDE_TOTAL_DEFINED__
int GetSymbolSideTotal(bool isBuy){
   int count = 0;
   for(int i=OrdersTotal()-1; i>=0; --i){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol()!=_Symbol) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)ordinfo.Type();
      if(isBuy){
         if(t==ORDER_TYPE_BUY || t==ORDER_TYPE_BUY_LIMIT || t==ORDER_TYPE_BUY_STOP) count++;
      }else{
         if(t==ORDER_TYPE_SELL || t==ORDER_TYPE_SELL_LIMIT || t==ORDER_TYPE_SELL_STOP) count++;
      }
   }

   for(int i=PositionsTotal()-1; i>=0; --i){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()!=_Symbol) continue;
      if(isBuy && posinfo.PositionType()==POSITION_TYPE_BUY) count++;
      if(!isBuy && posinfo.PositionType()==POSITION_TYPE_SELL) count++;
   }
   return count;
}
#endif

#ifndef __PRICE_WITHIN_TOLERANCE_DEFINED__
#define __PRICE_WITHIN_TOLERANCE_DEFINED__
bool PriceWithinTolerance(double price, double level){
   if(EntryTolerancePoints <= 0) return true;
   return MathAbs(price - level) <= EntryTolerancePoints * _Point;
}
#endif

datetime DayStartServer(){
   datetime now = TimeCurrent();
   MqlDateTime dt; TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

int CountEntriesToday(string symbol){
   datetime start = DayStartServer();
   if(!HistorySelect(start, TimeCurrent())) return 0;

   int count = 0;
   for(int i=HistoryDealsTotal()-1; i>=0; --i){
      ulong ticket = HistoryDealGetTicket(i);
      if(!HistoryDealSelect(ticket)) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      count++;
   }
   return count;
}

int CountEntriesTodayByMagic(string symbol, long magic){
   if(magic <= 0) return 0;
   datetime start = DayStartServer();
   if(!HistorySelect(start, TimeCurrent())) return 0;

   int count = 0;
   for(int i=HistoryDealsTotal()-1; i>=0; --i){
      ulong ticket = HistoryDealGetTicket(i);
      if(!HistoryDealSelect(ticket)) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;
      count++;
   }
   return count;
}

bool SessionTradedToday(string symbol, long magic){
   return CountEntriesTodayByMagic(symbol, magic) > 0;
}

int GetSymbolSideTotal(bool isBuy){
   int count = 0;
   for(int i=OrdersTotal()-1; i>=0; --i){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol()!=_Symbol) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)ordinfo.Type();
      if(isBuy){
         if(t==ORDER_TYPE_BUY || t==ORDER_TYPE_BUY_LIMIT || t==ORDER_TYPE_BUY_STOP) count++;
      }else{
         if(t==ORDER_TYPE_SELL || t==ORDER_TYPE_SELL_LIMIT || t==ORDER_TYPE_SELL_STOP) count++;
      }
   }

   for(int i=PositionsTotal()-1; i>=0; --i){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()!=_Symbol) continue;
      if(isBuy && posinfo.PositionType()==POSITION_TYPE_BUY) count++;
      if(!isBuy && posinfo.PositionType()==POSITION_TYPE_SELL) count++;
   }
   return count;
}

bool PriceWithinTolerance(double price, double level){
   if(EntryTolerancePoints <= 0) return true;
   return MathAbs(price - level) <= EntryTolerancePoints * _Point;
}

datetime DayStartServer(){
   datetime now = TimeCurrent();
   MqlDateTime dt; TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

int CountEntriesToday(string symbol){
   datetime start = DayStartServer();
   if(!HistorySelect(start, TimeCurrent())) return 0;

   int count = 0;
   for(int i=HistoryDealsTotal()-1; i>=0; --i){
      ulong ticket = HistoryDealGetTicket(i);
      if(!HistoryDealSelect(ticket)) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      count++;
   }
   return count;
}

int CountEntriesTodayByMagic(string symbol, long magic){
   if(magic <= 0) return 0;
   datetime start = DayStartServer();
   if(!HistorySelect(start, TimeCurrent())) return 0;

   int count = 0;
   for(int i=HistoryDealsTotal()-1; i>=0; --i){
      ulong ticket = HistoryDealGetTicket(i);
      if(!HistoryDealSelect(ticket)) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic) continue;
      count++;
   }
   return count;
}

bool SessionTradedToday(string symbol, long magic){
   return CountEntriesTodayByMagic(symbol, magic) > 0;
}

int GetSymbolSideTotal(bool isBuy){
   int count = 0;
   for(int i=OrdersTotal()-1; i>=0; --i){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol()!=_Symbol) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)ordinfo.Type();
      if(isBuy){
         if(t==ORDER_TYPE_BUY || t==ORDER_TYPE_BUY_LIMIT || t==ORDER_TYPE_BUY_STOP) count++;
      }else{
         if(t==ORDER_TYPE_SELL || t==ORDER_TYPE_SELL_LIMIT || t==ORDER_TYPE_SELL_STOP) count++;
      }
   }

   for(int i=PositionsTotal()-1; i>=0; --i){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()!=_Symbol) continue;
      if(isBuy && posinfo.PositionType()==POSITION_TYPE_BUY) count++;
      if(!isBuy && posinfo.PositionType()==POSITION_TYPE_SELL) count++;
   }
   return count;
}

bool PriceWithinTolerance(double price, double level){
   if(EntryTolerancePoints <= 0) return true;
   return MathAbs(price - level) <= EntryTolerancePoints * _Point;
}

bool HasPositionOrOrder(ulong magic){
   for(int i=OrdersTotal()-1; i>=0; --i){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol()==_Symbol && ordinfo.Magic()==magic) return true;
   }
   for(int i=PositionsTotal()-1; i>=0; --i){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol()==_Symbol && posinfo.Magic()==magic) return true;
   }
   return false;
}
/*
double findHigh(){
   int need = BarsN*2+1;
   int bars = iBars(_Symbol, HL_Timeframe);
   if(bars < need) return -1;
   for(int i=BarsN; i< MathMin(200, bars-BarsN); i++){
      if(iHighest(_Symbol, HL_Timeframe, MODE_HIGH, need, i-BarsN)==i)
         return iHigh(_Symbol, HL_Timeframe, i);
   }
   return -1;
}

double findLow(){
   int need = BarsN*2+1;
   int bars = iBars(_Symbol, HL_Timeframe);
   if(bars < need) return -1;
   for(int i=BarsN; i< MathMin(200, bars-BarsN); i++){
      if(iLowest(_Symbol, HL_Timeframe, MODE_LOW, need, i-BarsN)==i)
         return iLow(_Symbol, HL_Timeframe, i);
   }
   return -1;
}*/

bool IsNewsTime(){
   if(!UseNewsFilter) return false;
   
   string symbolName = _Symbol;
   string baseCurrency = "";
   string quoteCurrency = "";
   
   if(StringLen(symbolName) >= 6){
      baseCurrency = StringSubstr(symbolName, 0, 3);
      quoteCurrency = StringSubstr(symbolName, 3, 3);
   } else {
      if(StringFind(symbolName, "USD") >= 0) quoteCurrency = "USD";
      if(StringFind(symbolName, "EUR") >= 0) baseCurrency = "EUR";
      if(StringFind(symbolName, "GBP") >= 0) baseCurrency = "GBP";
      if(StringFind(symbolName, "JPY") >= 0) quoteCurrency = "JPY";
   }
   
   datetime now = TimeCurrent();
   datetime from = now - NewsMinutesBefore * 60;
   datetime to = now + NewsMinutesAfter * 60;
   
   MqlCalendarValue values[];
   int n = CalendarValueHistory(values, from, to, NULL, NULL);
   if(n <= 0){
      if(DebugNews) DPrint("[NEWS] Calendar unavailable, allowing trading");
      return false;
   }
   
   for(int i = 0; i < ArraySize(values); i++){
      MqlCalendarEvent event;
      MqlCalendarCountry country;
      
      if(!CalendarEventById(values[i].event_id, event)) continue;
      if(!CalendarCountryById(event.country_id, country)) continue;
      
      bool isRelevant = false;
      if(StringLen(country.currency) == 3){
         if(country.currency == baseCurrency || country.currency == quoteCurrency){
            isRelevant = true;
         }
      }
      
      if(!isRelevant) continue;
      
      bool impactMatch = false;
      if(FilterHighImpact && event.importance == CALENDAR_IMPORTANCE_HIGH){
         impactMatch = true;
      }
      if(FilterMediumImpact && event.importance == CALENDAR_IMPORTANCE_MEDIUM){
         impactMatch = true;
      }
      if(FilterLowImpact && event.importance == CALENDAR_IMPORTANCE_LOW){
         impactMatch = true;
      }
      
      if(!impactMatch) continue;
      
      if(StringLen(NewsKeywordFilter) > 0){
         if(StringFind(event.name, NewsKeywordFilter) < 0) continue;
      }
      
      datetime eventTime = values[i].time;
      long beforeSeconds = NewsMinutesBefore * 60;
      long afterSeconds = NewsMinutesAfter * 60;
      
      if(now >= eventTime - beforeSeconds && now <= eventTime + afterSeconds){
         if(DebugNews) DPrint(StringFormat("[NEWS] BLOCKED: %s %s (impact=%d, eventTime=%s, now=%s)", 
                                           country.currency, event.name, event.importance, 
                                           TimeToString(eventTime, TIME_DATE|TIME_MINUTES),
                                           TimeToString(now, TIME_DATE|TIME_MINUTES)));
         return true;
      }
   }
   
   return false;
}

// ====================== Filters (MA / Ichimoku) ====================
string PricevsMovAvg(){
   double f = MovAvgFast.Main(0);
   double s = MovAvgSlow.Main(0);
   if(f>s) return "above";
   if(f<s) return "below";
   return "error";
}
/*
string PricevsIchiCloud(){
   double SenA = Ichimoku.SenkouSpanA(0);
   double SenB = Ichimoku.SenkouSpanB(0);
   double Ten  = Ichimoku.TenkanSen(0);
   double Kij  = Ichimoku.KijunSen(0);
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   switch(IchiFilterType){
      case Price_above_Cloud:               if(ask>SenA && ask>SenB) return "above"; if(ask<SenA && ask<SenB) return "below"; break;
      case Price_above_Ten:                 if(ask>Ten) return "above"; if(ask<Ten) return "below"; break;
      case Price_above_Kij:                 if(ask>Kij) return "above"; if(ask<Kij) return "below"; break;
      case Price_above_SenA:                if(ask>SenA) return "above"; if(ask<SenA) return "below"; break;
      case Price_above_SenB:                if(ask>SenB) return "above"; if(ask<SenB) return "below"; break;
      case Ten_above_Kij:                   if(Ten>Kij) return "above"; if(Ten<Kij) return "below"; break;
      case Ten_above_Kij_above_Cloud:       if(Ten>Kij && Kij>SenA && Kij>SenB) return "above"; if(Ten<Kij && Kij<SenA && Kij<SenB) return "below"; break;
      case Ten_above_Cloud:                 if(Ten>SenA && Ten>SenB) return "above"; if(Ten<SenA && Ten<SenB) return "below"; break;
      case Kij_above_Cloud:                 if(Kij>SenA && Kij>SenB) return "above"; if(Kij<SenA && Kij<SenB) return "below"; break;
   }
   return "Incloud";
}*/


bool isInsideTime(Hours h1, Minutes m1, Hours h2, Minutes m2, datetime CheckTime)
{

   datetime d = CheckTime;

   if (TimeZone != z_Exchange){
      d = d - (diffTime - TimeZone)*60*60;
   }

   MqlDateTime dt;
   TimeToStruct(d,dt);

   int t = dt.hour*60 + dt.min;
   int t1_1,t1_2;

   t1_1 = h1*60+m1;
   t1_2 = h2*60+m2;
   
   bool result;
   if (t1_2 > t1_1){
      result = (t >= t1_1 && t < t1_2);
   } else {
      result = (t >= t1_1 || t < t1_2);
   }
   
   return result;
}
bool isCloseTime(Hours h1, Minutes m1, datetime CheckTime)
{
   datetime d = CheckTime;

   if (TimeZone != z_Exchange){
      d = d - (diffTime - TimeZone)*60*60;
   }



   MqlDateTime dt;
   TimeToStruct(d,dt);

   int t = dt.hour*60 + dt.min;
   int t1_1,t1_2;

   t1_1 = h1*60+m1;
   t1_2 = 24*60;
   
   if(t >= t1_1 && t < t1_2){return true;}else{return false;}
 
}

void GetRange(double &RangeHigh, double &RangeLow,datetime &timestart, datetime &timeend, Hours h1, Minutes m1, Hours h2, Minutes m2){

   RangeLow = 0;
   RangeHigh = 0;
   
   timestart = 0;
   timeend = 0;
   
   bool foundFirstBar = false;

   for (int i = 1; i<1000; i++){
      datetime barTime = iTime(_Symbol,PERIOD_CURRENT,i);
      
      // If this bar is inside the time range, process it
      if (isInsideTime(h1, m1, h2, m2, barTime)){
         if (!foundFirstBar){
            // First bar in the range
            RangeLow = iLow(_Symbol,PERIOD_CURRENT,i);
            RangeHigh = iHigh(_Symbol,PERIOD_CURRENT,i);
            timeend = barTime;
            timestart = barTime;
            foundFirstBar = true;
         } else {
            // Continue processing bars in the range
            RangeLow = MathMin(iLow(_Symbol,PERIOD_CURRENT,i), RangeLow);
            RangeHigh = MathMax(iHigh(_Symbol,PERIOD_CURRENT,i),RangeHigh);
            timestart = barTime;
         }
      } else {
         // Bar is outside the range - if we've found bars, we're done
         // If we haven't found any bars yet, continue searching
         if (foundFirstBar){
            break; // We've processed the range, exit
         }
         // Otherwise continue searching for the start of the range
      }
   }
   
   // If no bars were found in the range, return with zero values
   if (!foundFirstBar){
      RangeLow = 0;
      RangeHigh = 0;
      timestart = 0;
      timeend = 0;
   }
}


double getLot(int _points){


   string _symbol = _Symbol;
   double _risk_percent = RiskPercent;

   if (LotSizeType == Fixed){return FixedLotSize;}

   // Prevent division by zero
   if(_points <= 0){
      double minlot = SymbolInfoDouble(_symbol,SYMBOL_VOLUME_MIN);
      return minlot;
   }

   double base = UseEquityForRisk ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);


   double minlot = SymbolInfoDouble(_symbol,SYMBOL_VOLUME_MIN);
   double maxlot = SymbolInfoDouble(_symbol,SYMBOL_VOLUME_MAX);
   double steplot = SymbolInfoDouble(_symbol, SYMBOL_VOLUME_STEP);
   double money_risk = NormalizeDouble(base*_risk_percent/100,2);
   double calc_point_cost = NormalizeDouble(money_risk/_points,2);
   double lot_point_cost=SymbolInfoDouble(_symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   
   int retryCount = 0;
   while((!MathIsValidNumber(lot_point_cost) || lot_point_cost==0) && retryCount < 10){
      lot_point_cost=SymbolInfoDouble(_symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      retryCount++;
      Sleep(10);
   }
   if(lot_point_cost == 0 || !MathIsValidNumber(lot_point_cost)){
      return minlot;
   }
   
   double lot = calc_point_cost/lot_point_cost;
   if (lot<=minlot) {lot = minlot;}
   else if (lot>maxlot) {lot=maxlot;}
   else if (lot>minlot && lot<maxlot){
      int k = int ((lot-minlot)/steplot);
      lot = NormalizeDouble(minlot+k*steplot,2);
   }
   
   return (lot);

}
