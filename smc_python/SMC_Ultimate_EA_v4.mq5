//+------------------------------------------------------------------+
//|                                          SMC_Ultimate_EA_v4.mq5 |
//|          Full Control - Correct Parameter Order from Screenshots |
//|                            https://github.com/Ahmedyassen77/ICT |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen - SMC Ultimate EA v4"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "4.00"
#property description "Loads Smart Money Concepts indicator with EXACT parameter order"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INDICATOR INPUTS - EXACT ORDER FROM SCREENSHOTS                   |
//+------------------------------------------------------------------+

// ===== Smart Money Concepts (Header) =====
input group "═══════════ Smart Money Concepts ═══════════"
input int      Inp_Candles = 2000;                     // 01. How many candles to calculate in history (0=All)
// ab SmartMoney Concepts (separator - no input)
input string   Inp_Mode = "Historical";                // 02. Mode
input string   Inp_Style = "Colored";                  // 03. Style
input bool     Inp_ColorCandles = false;               // 04. Color Candles

// ===== Real Time Internal Structure (Header) =====
input group "═══════════ Real Time Internal Structure ═══════════"
// ab Real Time Internal Structure (separator - no input)
input bool     Inp_ShowInternalStructure = true;       // 05. Show Internal Structure
input string   Inp_IntBullishStructure = "All";        // 06. Bullish Structure
input color    Inp_IntBullishColor = C'8,153,129';     // 07. Bullish Color
input string   Inp_IntBearishStructure = "All";        // 08. Bearish Structure
input color    Inp_IntBearishColor = C'242,54,69';     // 09. Bearish Color
input bool     Inp_ConfluenceFilter = false;           // 10. Confluence Filter

// ===== Real Time Swing Structure (Header) =====
input group "═══════════ Real Time Swing Structure ═══════════"
// ab Real Time Swing Structure (separator - no input)
input bool     Inp_ShowSwingStructure = true;          // 11. Show Swing Structure
input string   Inp_SwingBullishStructure = "All";      // 12. Bullish Structure
input color    Inp_SwingBullishColor = C'8,153,129';   // 13. Bullish Color
input string   Inp_SwingBearishStructure = "All";      // 14. Bearish Structure
input color    Inp_SwingBearishColor = C'242,54,69';   // 15. Bearish Color
input bool     Inp_ShowSwingsPoints = false;           // 16. Show Swings Points
input int      Inp_Length = 50;                        // 17. Length
input bool     Inp_ShowStrongWeakHL = true;            // 18. Show Strong/Weak High/Low

// ===== Order Blocks (Header) =====
input group "═══════════ Order Blocks ═══════════"
// ab Order Blocks (separator - no input)
input bool     Inp_ShowInternalOB = true;              // 19. Show Internal Order Blocks
input int      Inp_InternalOBCount = 5;                // 20. Internal Order Blocks
input bool     Inp_SwingOrderBlocks = false;           // 21. Swing Order Blocks
input int      Inp_SwingOBCount = 5;                   // 22. Swing Order Blocks
input string   Inp_OBFilter = "Atr";                   // 23. Order Block Filter
input color    Inp_InternalBullishOB = C'91,156,246';  // 24. Internal Bullish OB
input color    Inp_InternalBearishOB = C'247,124,128'; // 25. Internal Bearish OB
input color    Inp_BullishOB = C'24,72,204';           // 26. Bullish OB
input color    Inp_BearishOB = C'178,40,51';           // 27. Bearish OB

// ===== EQH/EQL (Header) =====
input group "═══════════ EQH/EQL ═══════════"
// ab EQH/EQL (separator - no input)
input bool     Inp_EqualHL = true;                     // 28. Equal High/Low
input int      Inp_BarsConfirmation = 3;               // 29. Bars Confirmation
input double   Inp_Threshold = 0.1;                    // 30. Threshold

// ===== Fair Value Gaps (Header) =====
input group "═══════════ Fair Value Gaps ═══════════"
// ab Fair Value Gaps (separator - no input)
input bool     Inp_FairValueGaps = false;              // 31. Fair Value Gaps
input bool     Inp_AutoThreshold = true;               // 32. Auto Threshold
input string   Inp_FVGTimeframe = "current";           // 33. Timeframe
input color    Inp_BullishFVG = C'0,255,104';          // 34. Bullish FVG
input color    Inp_BearishFVG = C'255,0,8';            // 35. Bearish FVG
input int      Inp_ExtendFVG = 1;                      // 36. Extend FVG

// ===== Highs & Lows MTF (Header) =====
input group "═══════════ Highs & Lows MTF ═══════════"
// ab Highs & Lows MTF (separator - no input)
input bool     Inp_ShowDaily = false;                  // 37. Show Daily
input string   Inp_StyleDaily = "Solid";               // 38. Style Daily
input color    Inp_ColorDaily = C'33,87,243';          // 39. Color Daily
input bool     Inp_ShowWeekly = false;                 // 40. Show Weekly
input string   Inp_StyleWeekly = "Solid";              // 41. Style Weekly
input color    Inp_ColorWeekly = C'33,87,243';         // 42. Color Weekly
input bool     Inp_ShowMonthly = false;                // 43. Show Monthly
input string   Inp_StyleMonthly = "Solid";             // 44. Style Monthly
input color    Inp_ColorMonthly = C'33,87,243';        // 45. Color Monthly

// ===== Premium & Discount Zones (Header) =====
input group "═══════════ Premium & Discount Zones ═══════════"
// ab Premium & Discount Zones (separator - no input)
input bool     Inp_PremiumDiscountZones = false;       // 46. Premium/Discount Zones
input color    Inp_PremiumZone = C'242,54,69';         // 47. Premium Zone
input color    Inp_EquilibriumZone = C'178,181,190';   // 48. Equilibrium Zone
input color    Inp_DiscountZone = C'8,153,129';        // 49. Discount Zone

//+------------------------------------------------------------------+
//| TRADING INPUTS                                                    |
//+------------------------------------------------------------------+
input group "═══════════ TRADE SETTINGS ═══════════"
input double   LotSize = 0.1;                          // Lot Size
input int      StopLoss = 500;                         // Stop Loss (points)
input int      TakeProfit = 1000;                      // Take Profit (points)
input int      MagicNumber = 999888;                   // Magic Number
input int      MaxPositions = 1;                       // Max Open Positions

input group "═══════════ SIGNAL SETTINGS ═══════════"
input bool     TradeOnBOS = true;                      // Trade on BOS
input bool     TradeOnCHoCH = true;                    // Trade on CHoCH
input bool     OnlyNewSignals = true;                  // Only New Signals
input int      SignalExpiryBars = 3;                   // Signal Expiry (bars)

input group "═══════════ RISK MANAGEMENT ═══════════"
input bool     UseTrailingStop = false;                // Use Trailing Stop
input int      TrailingStart = 300;                    // Trailing Start (points)
input int      TrailingStep = 100;                     // Trailing Step (points)

input group "═══════════ DISPLAY ═══════════"
input bool     ShowPanel = true;                       // Show Info Panel
input bool     DebugMode = true;                       // Debug Mode

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
int indicatorHandle = INVALID_HANDLE;
bool indicatorLoaded = false;

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
   Print("╔══════════════════════════════════════════════════════╗");
   Print("║         SMC Ultimate EA v4.0 - Initializing          ║");
   Print("║       Correct Parameter Order + Auto Trading         ║");
   Print("╚══════════════════════════════════════════════════════╝");
   
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   
   // Remove old indicator
   RemoveIndicator();
   Sleep(300);
   
   // Add indicator with correct parameter order
   AddIndicatorWithCorrectOrder();
   
   // Initial scan
   ScanObjects();
   
   // Create panel
   if(ShowPanel) CreatePanel();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Add indicator with EXACT parameter order from screenshots         |
//+------------------------------------------------------------------+
void AddIndicatorWithCorrectOrder()
{
   Print("Loading Smart Money Concepts indicator...");
   
   // Parameters in EXACT order from screenshots:
   // The order matches what we see in the indicator's Inputs tab
   
   indicatorHandle = iCustom(
      _Symbol, 
      PERIOD_CURRENT, 
      "Smart Money Concepts",
      
      // === Smart Money Concepts Section ===
      Inp_Candles,                 // How many candles to calculate in history (0=All)
      Inp_Mode,                    // Mode
      Inp_Style,                   // Style  
      Inp_ColorCandles,            // Color Candles
      
      // === Real Time Internal Structure Section ===
      Inp_ShowInternalStructure,   // Show Internal Structure
      Inp_IntBullishStructure,     // Bullish Structure
      Inp_IntBullishColor,         // Bullish Color
      Inp_IntBearishStructure,     // Bearish Structure
      Inp_IntBearishColor,         // Bearish Color
      Inp_ConfluenceFilter,        // Confluence Filter
      
      // === Real Time Swing Structure Section ===
      Inp_ShowSwingStructure,      // Show Swing Structure
      Inp_SwingBullishStructure,   // Bullish Structure
      Inp_SwingBullishColor,       // Bullish Color
      Inp_SwingBearishStructure,   // Bearish Structure
      Inp_SwingBearishColor,       // Bearish Color
      Inp_ShowSwingsPoints,        // Show Swings Points
      Inp_Length,                  // Length
      Inp_ShowStrongWeakHL,        // Show Strong/Weak High/Low
      
      // === Order Blocks Section ===
      Inp_ShowInternalOB,          // Show Internal Order Blocks
      Inp_InternalOBCount,         // Internal Order Blocks
      Inp_SwingOrderBlocks,        // Swing Order Blocks
      Inp_SwingOBCount,            // Swing Order Blocks
      Inp_OBFilter,                // Order Block Filter
      Inp_InternalBullishOB,       // Internal Bullish OB
      Inp_InternalBearishOB,       // Internal Bearish OB
      Inp_BullishOB,               // Bullish OB
      Inp_BearishOB,               // Bearish OB
      
      // === EQH/EQL Section ===
      Inp_EqualHL,                 // Equal High/Low
      Inp_BarsConfirmation,        // Bars Confirmation
      Inp_Threshold,               // Threshold
      
      // === Fair Value Gaps Section ===
      Inp_FairValueGaps,           // Fair Value Gaps
      Inp_AutoThreshold,           // Auto Threshold
      Inp_FVGTimeframe,            // Timeframe
      Inp_BullishFVG,              // Bullish FVG
      Inp_BearishFVG,              // Bearish FVG
      Inp_ExtendFVG,               // Extend FVG
      
      // === Highs & Lows MTF Section ===
      Inp_ShowDaily,               // Show Daily
      Inp_StyleDaily,              // Style Daily
      Inp_ColorDaily,              // Color Daily
      Inp_ShowWeekly,              // Show Weekly
      Inp_StyleWeekly,             // Style Weekly
      Inp_ColorWeekly,             // Color Weekly
      Inp_ShowMonthly,             // Show Monthly
      Inp_StyleMonthly,            // Style Monthly
      Inp_ColorMonthly,            // Color Monthly
      
      // === Premium & Discount Zones Section ===
      Inp_PremiumDiscountZones,    // Premium/Discount Zones
      Inp_PremiumZone,             // Premium Zone
      Inp_EquilibriumZone,         // Equilibrium Zone
      Inp_DiscountZone             // Discount Zone
   );
   
   if(indicatorHandle != INVALID_HANDLE)
   {
      // Try to add to chart
      if(ChartIndicatorAdd(0, 0, indicatorHandle))
      {
         indicatorLoaded = true;
         Print("✓ SUCCESS! Indicator loaded with your parameters!");
         Print("✓ All settings from EA are now active!");
      }
      else
      {
         int err = GetLastError();
         Print("✗ ChartIndicatorAdd failed. Error: ", err);
         indicatorLoaded = false;
      }
   }
   else
   {
      int err = GetLastError();
      Print("✗ iCustom failed. Error: ", err);
      
      // Show helpful message
      Print("════════════════════════════════════════════════════════");
      Print("NOTE: The indicator parameters might not match exactly.");
      Print("Please add 'Smart Money Concepts' indicator manually.");
      Print("The EA will still trade based on indicator signals!");
      Print("════════════════════════════════════════════════════════");
   }
}

//+------------------------------------------------------------------+
//| Remove existing indicator                                         |
//+------------------------------------------------------------------+
void RemoveIndicator()
{
   for(int win = 0; win < ChartWindowsTotal(0); win++)
   {
      int total = ChartIndicatorsTotal(0, win);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ChartIndicatorName(0, win, i);
         if(StringFind(name, "Smart Money") >= 0 || StringFind(name, "SMC") >= 0)
         {
            if(ChartIndicatorDelete(0, win, name))
               Print("Removed: ", name);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);
   
   if(reason != REASON_PARAMETERS)
      RemoveIndicator();
   
   ObjectsDeleteAll(0, "SMCEA_");
   Print("EA Stopped. Trades: ", totalTrades);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   MonitorObjects();
   
   if(UseTrailingStop) 
      ApplyTrailingStop();
   
   if(ShowPanel) 
      UpdatePanel();
}

//+------------------------------------------------------------------+
//| Scan objects                                                      |
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
   if(DebugMode) Print("Found: ", totalBOS, " BOS, ", totalCHoCH, " CHoCH");
}

//+------------------------------------------------------------------+
//| Monitor objects                                                   |
//+------------------------------------------------------------------+
void MonitorObjects()
{
   int currentCount = ObjectsTotal(0, 0, -1);
   
   if(currentCount != objectCountLast)
   {
      for(int i = 0; i < currentCount; i++)
      {
         string name = ObjectName(0, i, 0, -1);
         if(name != lastBOSSignal && name != lastCHoCHSignal)
            ProcessObject(name);
      }
      objectCountLast = currentCount;
   }
}

//+------------------------------------------------------------------+
//| Process object                                                    |
//+------------------------------------------------------------------+
void ProcessObject(string obj_name)
{
   ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, obj_name, OBJPROP_TYPE);
   if(type != OBJ_TEXT && type != OBJ_LABEL) return;
   
   string text = ObjectGetString(0, obj_name, OBJPROP_TEXT);
   string textUpper = text;
   StringToUpper(textUpper);
   
   datetime obj_time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
   color obj_color = (color)ObjectGetInteger(0, obj_name, OBJPROP_COLOR);
   
   int barsSince = iBarShift(_Symbol, PERIOD_CURRENT, obj_time);
   if(OnlyNewSignals && barsSince > SignalExpiryBars) return;
   
   bool isBullish = IsBullishColor(obj_color);
   
   // BOS
   if(StringFind(textUpper, "BOS") >= 0 && TradeOnBOS)
   {
      if(obj_name != lastBOSSignal)
      {
         if(DebugMode) Print("► BOS: ", isBullish ? "BULL" : "BEAR");
         if(CanTrade()) OpenTrade(isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, "BOS");
         lastBOSSignal = obj_name;
         totalBOS++;
      }
   }
   // CHoCH
   else if(StringFind(textUpper, "CHOCH") >= 0 && TradeOnCHoCH)
   {
      if(obj_name != lastCHoCHSignal)
      {
         if(DebugMode) Print("► CHoCH: ", isBullish ? "BULL" : "BEAR");
         if(CanTrade()) OpenTrade(isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, "CHoCH");
         lastCHoCHSignal = obj_name;
         totalCHoCH++;
      }
   }
}

//+------------------------------------------------------------------+
//| Check bullish color                                               |
//+------------------------------------------------------------------+
bool IsBullishColor(color clr)
{
   if(clr == Inp_IntBullishColor || clr == Inp_SwingBullishColor ||
      clr == Inp_InternalBullishOB || clr == Inp_BullishOB ||
      clr == Inp_BullishFVG || clr == Inp_DiscountZone)
      return true;
   
   if(clr == Inp_IntBearishColor || clr == Inp_SwingBearishColor ||
      clr == Inp_InternalBearishOB || clr == Inp_BearishOB ||
      clr == Inp_BearishFVG || clr == Inp_PremiumZone)
      return false;
   
   return (clr == clrLime || clr == clrGreen || clr == clrDodgerBlue);
}

//+------------------------------------------------------------------+
//| Can trade check                                                   |
//+------------------------------------------------------------------+
bool CanTrade()
{
   int openPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
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
         Print("✓ BUY @ ", price);
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
         Print("✓ SELL @ ", price);
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
   }
}

//+------------------------------------------------------------------+
//| Trailing stop                                                     |
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
         if((bid - openPrice) / point >= TrailingStart)
         {
            double newSL = bid - TrailingStep * point;
            if(newSL > currentSL + point)
               trade.PositionModify(ticket, newSL, currentTP);
         }
      }
      else
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if((openPrice - ask) / point >= TrailingStart)
         {
            double newSL = ask + TrailingStep * point;
            if(newSL < currentSL - point || currentSL == 0)
               trade.PositionModify(ticket, newSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create panel                                                      |
//+------------------------------------------------------------------+
void CreatePanel()
{
   int x = 10, y = 30;
   
   ObjectCreate(0, "SMCEA_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_XDISTANCE, x - 5);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_YDISTANCE, y - 5);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_XSIZE, 230);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_YSIZE, 140);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_BGCOLOR, C'20,20,30');
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_COLOR, C'0,150,255');
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   CreateLabel("SMCEA_Title", "SMC Ultimate EA v4", x, y, C'0,200,255', 11);
   CreateLabel("SMCEA_Ind", "Indicator: ...", x, y + 22, clrWhite, 9);
   CreateLabel("SMCEA_BOS", "BOS: 0", x, y + 44, clrYellow, 9);
   CreateLabel("SMCEA_CHoCH", "CHoCH: 0", x, y + 66, clrMagenta, 9);
   CreateLabel("SMCEA_Trades", "Trades: 0", x, y + 88, clrLime, 9);
   CreateLabel("SMCEA_Pos", "Positions: 0", x, y + 110, clrAqua, 9);
}

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
   
   // Check indicator
   bool indFound = false;
   for(int i = 0; i < ChartIndicatorsTotal(0, 0); i++)
   {
      string name = ChartIndicatorName(0, 0, i);
      if(StringFind(name, "Smart Money") >= 0) { indFound = true; break; }
   }
   
   ObjectSetString(0, "SMCEA_Ind", OBJPROP_TEXT, "Indicator: " + (indFound ? "Active" : "Manual"));
   ObjectSetInteger(0, "SMCEA_Ind", OBJPROP_COLOR, indFound ? clrLime : clrOrange);
   ObjectSetString(0, "SMCEA_BOS", OBJPROP_TEXT, "BOS: " + IntegerToString(totalBOS));
   ObjectSetString(0, "SMCEA_CHoCH", OBJPROP_TEXT, "CHoCH: " + IntegerToString(totalCHoCH));
   ObjectSetString(0, "SMCEA_Trades", OBJPROP_TEXT, "Trades: " + IntegerToString(totalTrades));
   
   int pos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) pos++;
   ObjectSetString(0, "SMCEA_Pos", OBJPROP_TEXT, "Positions: " + IntegerToString(pos));
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CREATE) ProcessObject(sparam);
}
//+------------------------------------------------------------------+
