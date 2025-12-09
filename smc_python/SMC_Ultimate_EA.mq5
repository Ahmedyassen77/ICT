//+------------------------------------------------------------------+
//|                                              SMC_Ultimate_EA.mq5 |
//|                  Loads SMC Indicator with Full Control + Trading |
//|                            https://github.com/Ahmedyassen77/ICT |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen - SMC Ultimate EA"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "2.00"
#property description "Full control over Smart Money Concepts indicator + Auto Trading"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INDICATOR INPUTS - Same as Smart Money Concepts 1.0              |
//+------------------------------------------------------------------+
input group "═══════════ Smart Money Concepts Settings ═══════════"
input int      Ind_Candles = 2000;                    // How many candles to calculate in history (0=All)
input string   Ind_Mode = "Historical";               // Mode (Historical/Present)
input string   Ind_Style = "Colored";                 // Style (Colored/Monochrome)
input bool     Ind_ColorCandles = false;              // Color Candles

input group "═══════════ Real Time Internal Structure ═══════════"
input bool     Ind_ShowInternalStructure = true;      // Show Internal Structure
input string   Ind_BullishStructure = "All";          // Bullish Structure (All/BOS/CHoCH)
input color    Ind_BullishColor = C'8,153,129';       // Bullish Color
input string   Ind_BearishStructure = "All";          // Bearish Structure (All/BOS/CHoCH)
input color    Ind_BearishColor = C'242,54,69';       // Bearish Color
input bool     Ind_ConfluenceFilter = false;          // Confluence Filter

input group "═══════════ Real Time Swing Structure ═══════════"
input bool     Ind_ShowSwingStructure = true;         // Show Swing Structure
input string   Ind_SwingBullishStructure = "All";     // Bullish Structure (All/BOS/CHoCH)
input color    Ind_SwingBullishColor = C'8,153,129';  // Bullish Color
input string   Ind_SwingBearishStructure = "All";     // Bearish Structure (All/BOS/CHoCH)
input color    Ind_SwingBearishColor = C'242,54,69';  // Bearish Color
input bool     Ind_ShowSwingsPoints = false;          // Show Swings Points
input int      Ind_Length = 50;                       // Length
input bool     Ind_ShowStrongWeakHL = true;           // Show Strong/Weak High/Low

input group "═══════════ Order Blocks ═══════════"
input bool     Ind_ShowInternalOB = true;             // Show Internal Order Blocks
input int      Ind_InternalOB_Count = 5;              // Internal Order Blocks
input bool     Ind_SwingOrderBlocks = false;          // Swing Order Blocks
input int      Ind_SwingOB_Count = 5;                 // Swing Order Blocks Count
input string   Ind_OB_Filter = "Atr";                 // Order Block Filter (Atr/Avg/None)
input color    Ind_InternalBullishOB = C'91,156,246'; // Internal Bullish OB
input color    Ind_InternalBearishOB = C'247,124,128';// Internal Bearish OB
input color    Ind_BullishOB = C'24,72,204';          // Bullish OB
input color    Ind_BearishOB = C'178,40,51';          // Bearish OB

input group "═══════════ EQH/EQL ═══════════"
input bool     Ind_EqualHL = true;                    // Equal High/Low
input int      Ind_BarsConfirmation = 3;              // Bars Confirmation
input double   Ind_Threshold = 0.1;                   // Threshold

input group "═══════════ Fair Value Gaps ═══════════"
input bool     Ind_FairValueGaps = false;             // Fair Value Gaps
input bool     Ind_AutoThreshold = true;              // Auto Threshold
input string   Ind_FVG_Timeframe = "current";         // Timeframe (current/1H/4H/D1)
input color    Ind_BullishFVG = C'0,255,104';         // Bullish FVG
input color    Ind_BearishFVG = C'255,0,8';           // Bearish FVG
input int      Ind_ExtendFVG = 1;                     // Extend FVG

input group "═══════════ Highs & Lows MTF ═══════════"
input bool     Ind_ShowDaily = false;                 // Show Daily
input string   Ind_StyleDaily = "Solid";              // Style Daily
input color    Ind_ColorDaily = C'33,87,243';         // Color Daily
input bool     Ind_ShowWeekly = false;                // Show Weekly
input string   Ind_StyleWeekly = "Solid";             // Style Weekly
input color    Ind_ColorWeekly = C'33,87,243';        // Color Weekly
input bool     Ind_ShowMonthly = false;               // Show Monthly
input string   Ind_StyleMonthly = "Solid";            // Style Monthly
input color    Ind_ColorMonthly = C'33,87,243';       // Color Monthly

input group "═══════════ Premium & Discount Zones ═══════════"
input bool     Ind_PremiumDiscountZones = false;      // Premium/Discount Zones
input color    Ind_PremiumZone = C'242,54,69';        // Premium Zone
input color    Ind_EquilibriumZone = C'178,181,190';  // Equilibrium Zone
input color    Ind_DiscountZone = C'8,153,129';       // Discount Zone

//+------------------------------------------------------------------+
//| TRADING INPUTS                                                    |
//+------------------------------------------------------------------+
input group "═══════════ Trade Settings ═══════════"
input double   LotSize = 0.1;                         // Lot Size
input int      StopLoss = 500;                        // Stop Loss (points)
input int      TakeProfit = 1000;                     // Take Profit (points)
input int      MagicNumber = 999888;                  // Magic Number
input int      MaxPositions = 1;                      // Max Open Positions

input group "═══════════ Signal Settings ═══════════"
input bool     TradeOnBOS = true;                     // Trade on BOS
input bool     TradeOnCHoCH = true;                   // Trade on CHoCH
input bool     TradeOnOB = false;                     // Trade on Order Block touch
input bool     OnlyNewSignals = true;                 // Only New Signals
input int      SignalExpiryBars = 3;                  // Signal Expiry (bars)

input group "═══════════ Risk Management ═══════════"
input bool     UseTrailingStop = false;               // Use Trailing Stop
input int      TrailingStart = 300;                   // Trailing Start (points)
input int      TrailingStep = 100;                    // Trailing Step (points)
input double   MaxDailyLoss = 0;                      // Max Daily Loss $ (0=disabled)
input double   MaxDailyProfit = 0;                    // Max Daily Profit $ (0=disabled)

input group "═══════════ Display ═══════════"
input bool     ShowPanel = true;                      // Show Info Panel
input bool     DebugMode = true;                      // Debug Mode

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
int indicatorHandle = INVALID_HANDLE;

string lastBOSSignal = "";
string lastCHoCHSignal = "";
datetime lastTradeTime = 0;
int objectCountLast = 0;

int totalBOS = 0;
int totalCHoCH = 0;
int totalTrades = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("╔══════════════════════════════════════════════════╗");
   Print("║       SMC Ultimate EA v2.0 - Initializing        ║");
   Print("╚══════════════════════════════════════════════════╝");
   
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   
   // Load indicator with all parameters
   LoadIndicator();
   
   // Initial scan
   ScanObjects();
   
   // Create panel
   if(ShowPanel) CreatePanel();
   
   Print("EA Ready! Monitoring SMC signals...");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Load SMC Indicator with parameters                                |
//+------------------------------------------------------------------+
void LoadIndicator()
{
   // Try to load with parameters
   // Note: iCustom passes parameters in order they appear in indicator
   indicatorHandle = iCustom(_Symbol, PERIOD_CURRENT, "Smart Money Concepts",
      Ind_Candles,
      Ind_Mode,
      Ind_Style,
      Ind_ColorCandles,
      Ind_ShowInternalStructure,
      Ind_BullishStructure,
      Ind_BullishColor,
      Ind_BearishStructure,
      Ind_BearishColor,
      Ind_ConfluenceFilter,
      Ind_ShowSwingStructure,
      Ind_SwingBullishStructure,
      Ind_SwingBullishColor,
      Ind_SwingBearishStructure,
      Ind_SwingBearishColor,
      Ind_ShowSwingsPoints,
      Ind_Length,
      Ind_ShowStrongWeakHL,
      Ind_ShowInternalOB,
      Ind_InternalOB_Count,
      Ind_SwingOrderBlocks,
      Ind_SwingOB_Count,
      Ind_OB_Filter,
      Ind_InternalBullishOB,
      Ind_InternalBearishOB,
      Ind_BullishOB,
      Ind_BearishOB,
      Ind_EqualHL,
      Ind_BarsConfirmation,
      Ind_Threshold,
      Ind_FairValueGaps,
      Ind_AutoThreshold,
      Ind_FVG_Timeframe,
      Ind_BullishFVG,
      Ind_BearishFVG,
      Ind_ExtendFVG,
      Ind_ShowDaily,
      Ind_StyleDaily,
      Ind_ColorDaily,
      Ind_ShowWeekly,
      Ind_StyleWeekly,
      Ind_ColorWeekly,
      Ind_ShowMonthly,
      Ind_StyleMonthly,
      Ind_ColorMonthly,
      Ind_PremiumDiscountZones,
      Ind_PremiumZone,
      Ind_EquilibriumZone,
      Ind_DiscountZone
   );
   
   if(indicatorHandle == INVALID_HANDLE)
   {
      Print("Warning: Could not load indicator with parameters. Error: ", GetLastError());
      Print("Trying to load without parameters...");
      
      // Try without parameters
      indicatorHandle = iCustom(_Symbol, PERIOD_CURRENT, "Smart Money Concepts");
      
      if(indicatorHandle == INVALID_HANDLE)
      {
         Print("Please add the indicator manually to the chart.");
         Print("EA will still monitor objects drawn by any SMC indicator.");
      }
      else
      {
         Print("Indicator loaded (default parameters)");
      }
   }
   else
   {
      Print("Indicator loaded successfully with custom parameters!");
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);
   
   ObjectsDeleteAll(0, "SMCEA_");
   Print("SMC Ultimate EA Stopped. Total trades: ", totalTrades);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check daily limits
   if(!CheckDailyLimits()) return;
   
   // Monitor objects
   MonitorObjects();
   
   // Trailing stop
   if(UseTrailingStop) ApplyTrailingStop();
   
   // Update panel
   if(ShowPanel) UpdatePanel();
}

//+------------------------------------------------------------------+
//| Check daily profit/loss limits                                    |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
   if(MaxDailyLoss == 0 && MaxDailyProfit == 0) return true;
   
   double todayPL = 0;
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   
   HistorySelect(today, TimeCurrent());
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber)
      {
         todayPL += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      }
   }
   
   if(MaxDailyLoss > 0 && todayPL <= -MaxDailyLoss)
   {
      if(DebugMode) Print("Daily loss limit reached: ", todayPL);
      return false;
   }
   
   if(MaxDailyProfit > 0 && todayPL >= MaxDailyProfit)
   {
      if(DebugMode) Print("Daily profit target reached: ", todayPL);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Scan existing objects                                             |
//+------------------------------------------------------------------+
void ScanObjects()
{
   totalBOS = 0;
   totalCHoCH = 0;
   
   int total = ObjectsTotal(0, 0, -1);
   
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, 0, -1);
      ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
      
      if(type == OBJ_TEXT || type == OBJ_LABEL)
      {
         string text = ObjectGetString(0, name, OBJPROP_TEXT);
         StringToUpper(text);
         
         if(StringFind(text, "BOS") >= 0) totalBOS++;
         else if(StringFind(text, "CHOCH") >= 0) totalCHoCH++;
      }
   }
   
   objectCountLast = total;
   
   if(DebugMode)
      Print("Scan: ", totalBOS, " BOS, ", totalCHoCH, " CHoCH");
}

//+------------------------------------------------------------------+
//| Monitor objects for new signals                                   |
//+------------------------------------------------------------------+
void MonitorObjects()
{
   int currentCount = ObjectsTotal(0, 0, -1);
   
   if(currentCount > objectCountLast)
   {
      for(int i = 0; i < currentCount; i++)
      {
         string name = ObjectName(0, i, 0, -1);
         if(name != lastBOSSignal && name != lastCHoCHSignal)
         {
            ProcessObject(name);
         }
      }
   }
   
   objectCountLast = currentCount;
}

//+------------------------------------------------------------------+
//| Process object for trading signal                                 |
//+------------------------------------------------------------------+
void ProcessObject(string obj_name)
{
   ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, obj_name, OBJPROP_TYPE);
   
   if(type != OBJ_TEXT && type != OBJ_LABEL) return;
   
   string text = ObjectGetString(0, obj_name, OBJPROP_TEXT);
   string textUpper = text;
   StringToUpper(textUpper);
   
   datetime obj_time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
   double obj_price = ObjectGetDouble(0, obj_name, OBJPROP_PRICE);
   color obj_color = (color)ObjectGetInteger(0, obj_name, OBJPROP_COLOR);
   
   // Check signal age
   int barsSince = iBarShift(_Symbol, PERIOD_CURRENT, obj_time);
   if(OnlyNewSignals && barsSince > SignalExpiryBars) return;
   
   // Determine direction by color
   bool isBullish = IsBullishColor(obj_color);
   
   // BOS Signal
   if(StringFind(textUpper, "BOS") >= 0 && TradeOnBOS)
   {
      if(obj_name != lastBOSSignal)
      {
         if(DebugMode) Print("BOS: ", obj_name, " Bullish: ", isBullish);
         
         if(CanTrade())
         {
            if(isBullish)
               OpenTrade(ORDER_TYPE_BUY, "BOS_Buy");
            else
               OpenTrade(ORDER_TYPE_SELL, "BOS_Sell");
         }
         
         lastBOSSignal = obj_name;
         totalBOS++;
      }
   }
   // CHoCH Signal
   else if(StringFind(textUpper, "CHOCH") >= 0 && TradeOnCHoCH)
   {
      if(obj_name != lastCHoCHSignal)
      {
         if(DebugMode) Print("CHoCH: ", obj_name, " Bullish: ", isBullish);
         
         if(CanTrade())
         {
            if(isBullish)
               OpenTrade(ORDER_TYPE_BUY, "CHoCH_Buy");
            else
               OpenTrade(ORDER_TYPE_SELL, "CHoCH_Sell");
         }
         
         lastCHoCHSignal = obj_name;
         totalCHoCH++;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if color indicates bullish                                  |
//+------------------------------------------------------------------+
bool IsBullishColor(color clr)
{
   // Compare with indicator bullish colors
   if(clr == Ind_BullishColor || clr == Ind_SwingBullishColor ||
      clr == Ind_InternalBullishOB || clr == Ind_BullishOB ||
      clr == Ind_BullishFVG || clr == Ind_DiscountZone)
      return true;
   
   // Compare with indicator bearish colors
   if(clr == Ind_BearishColor || clr == Ind_SwingBearishColor ||
      clr == Ind_InternalBearishOB || clr == Ind_BearishOB ||
      clr == Ind_BearishFVG || clr == Ind_PremiumZone)
      return false;
   
   // Default check by common colors
   if(clr == clrLime || clr == clrGreen || clr == clrSpringGreen ||
      clr == clrDodgerBlue || clr == clrAqua || clr == clrCyan)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if can open new trade                                       |
//+------------------------------------------------------------------+
bool CanTrade()
{
   int openPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         openPos++;
   }
   
   if(openPos >= MaxPositions) return false;
   if(TimeCurrent() - lastTradeTime < 60) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Open trade                                                        |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, string comment)
{
   double price, sl, tp;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(type == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = (StopLoss > 0) ? price - StopLoss * point : 0;
      tp = (TakeProfit > 0) ? price + TakeProfit * point : 0;
      
      if(trade.Buy(LotSize, _Symbol, price, sl, tp, comment))
      {
         Print(">>> BUY: ", comment, " @ ", price);
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = (StopLoss > 0) ? price + StopLoss * point : 0;
      tp = (TakeProfit > 0) ? price - TakeProfit * point : 0;
      
      if(trade.Sell(LotSize, _Symbol, price, sl, tp, comment))
      {
         Print(">>> SELL: ", comment, " @ ", price);
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
   }
}

//+------------------------------------------------------------------+
//| Apply trailing stop                                               |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(posType == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profit = (bid - openPrice) / point;
         
         if(profit >= TrailingStart)
         {
            double newSL = bid - TrailingStep * point;
            if(newSL > currentSL + point)
               trade.PositionModify(ticket, newSL, currentTP);
         }
      }
      else
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit = (openPrice - ask) / point;
         
         if(profit >= TrailingStart)
         {
            double newSL = ask + TrailingStep * point;
            if(newSL < currentSL - point || currentSL == 0)
               trade.PositionModify(ticket, newSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create info panel                                                 |
//+------------------------------------------------------------------+
void CreatePanel()
{
   int x = 10, y = 30;
   
   // Background
   ObjectCreate(0, "SMCEA_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_XDISTANCE, x - 5);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_YDISTANCE, y - 5);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_XSIZE, 220);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_YSIZE, 130);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_BGCOLOR, C'25,25,35');
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   CreateLabel("SMCEA_Title", "SMC Ultimate EA v2.0", x, y, clrDodgerBlue, 10);
   CreateLabel("SMCEA_Ind", "Indicator: Loading...", x, y + 22, clrWhite, 9);
   CreateLabel("SMCEA_BOS", "BOS: 0", x, y + 42, clrYellow, 9);
   CreateLabel("SMCEA_CHoCH", "CHoCH: 0", x, y + 62, clrMagenta, 9);
   CreateLabel("SMCEA_Trades", "Trades: 0", x, y + 82, clrLime, 9);
   CreateLabel("SMCEA_Pos", "Positions: 0", x, y + 102, clrAqua, 9);
}

//+------------------------------------------------------------------+
//| Create label                                                      |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int size)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Update panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 1) return;
   lastUpdate = TimeCurrent();
   
   string indStatus = (indicatorHandle != INVALID_HANDLE) ? "Loaded" : "Manual";
   ObjectSetString(0, "SMCEA_Ind", OBJPROP_TEXT, "Indicator: " + indStatus);
   ObjectSetInteger(0, "SMCEA_Ind", OBJPROP_COLOR, 
      (indicatorHandle != INVALID_HANDLE) ? clrLime : clrOrange);
   
   ObjectSetString(0, "SMCEA_BOS", OBJPROP_TEXT, "BOS: " + IntegerToString(totalBOS));
   ObjectSetString(0, "SMCEA_CHoCH", OBJPROP_TEXT, "CHoCH: " + IntegerToString(totalCHoCH));
   ObjectSetString(0, "SMCEA_Trades", OBJPROP_TEXT, "Trades: " + IntegerToString(totalTrades));
   
   int openPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         openPos++;
   }
   ObjectSetString(0, "SMCEA_Pos", OBJPROP_TEXT, "Positions: " + IntegerToString(openPos));
}

//+------------------------------------------------------------------+
//| Chart event                                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CREATE)
   {
      if(DebugMode) Print("New object: ", sparam);
      Sleep(50);
      ProcessObject(sparam);
   }
}
//+------------------------------------------------------------------+
