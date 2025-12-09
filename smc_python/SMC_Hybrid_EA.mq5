//+------------------------------------------------------------------+
//|                                            SMC_Hybrid_EA.mq5    |
//|              Simple Solution: Manual Indicator + EA Trading      |
//|                            https://github.com/Ahmedyassen77/ICT |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen - SMC Hybrid EA"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "6.00"
#property description "Add 'Smart Money Concepts' indicator manually once,"
#property description "then this EA will trade automatically based on its signals!"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT: TRADING SETTINGS                                           |
//+------------------------------------------------------------------+
input group "═══════════════ TRADE SETTINGS ═══════════════"
input double   LotSize = 0.1;                          // Lot Size
input int      StopLoss = 500;                         // Stop Loss (points)
input int      TakeProfit = 1000;                      // Take Profit (points)
input int      MagicNumber = 888999;                   // Magic Number
input int      MaxPositions = 1;                       // Max Open Positions

input group "═══════════════ SIGNAL SETTINGS ═══════════════"
input bool     TradeOnBOS = true;                      // Trade on BOS
input bool     TradeOnCHoCH = true;                    // Trade on CHoCH
input bool     TradeOnOBTouch = false;                 // Trade on Order Block Touch
input int      SignalExpiryBars = 3;                   // Signal Expiry (bars)
input bool     OnlyNewSignals = true;                  // Only Trade New Signals

input group "═══════════════ RISK MANAGEMENT ═══════════════"
input bool     UseTrailingStop = false;                // Use Trailing Stop
input int      TrailingStart = 300;                    // Trailing Start (points)
input int      TrailingStep = 100;                     // Trailing Step (points)
input double   MaxDailyLoss = 0;                       // Max Daily Loss $ (0=off)
input double   MaxDailyProfit = 0;                     // Max Daily Profit $ (0=off)

input group "═══════════════ COLOR DETECTION ═══════════════"
input color    BullishColor1 = C'8,153,129';           // Bullish Color 1
input color    BullishColor2 = clrLime;                // Bullish Color 2
input color    BullishColor3 = clrDodgerBlue;          // Bullish Color 3
input color    BearishColor1 = C'242,54,69';           // Bearish Color 1
input color    BearishColor2 = clrRed;                 // Bearish Color 2
input color    BearishColor3 = clrOrange;              // Bearish Color 3

input group "═══════════════ DISPLAY ═══════════════"
input bool     ShowPanel = true;                       // Show Info Panel
input bool     ShowInstructions = true;                // Show Instructions on Start
input bool     DebugMode = false;                      // Debug Mode (Expert Tab)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
string lastBOSSignal = "";
string lastCHoCHSignal = "";
string lastOBSignal = "";
datetime lastTradeTime = 0;
int objectCountLast = 0;

int totalBOS = 0;
int totalCHoCH = 0;
int totalTrades = 0;

double dailyPL = 0;
datetime lastDailyCheck = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("╔══════════════════════════════════════════════════════════╗");
   Print("║            SMC Hybrid EA v6.0 - Starting                 ║");
   Print("╚══════════════════════════════════════════════════════════╝");
   
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   
   // Check if indicator is on chart
   bool indicatorFound = CheckIndicator();
   
   if(!indicatorFound && ShowInstructions)
   {
      ShowSetupInstructions();
   }
   
   // Initial scan
   ScanExistingObjects();
   
   // Create panel
   if(ShowPanel)
      CreateInfoPanel();
   
   Print("══════════════════════════════════════════════════════════");
   Print("✓ EA Ready! Monitoring for SMC signals...");
   Print("══════════════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Check if SMC indicator is on chart                                |
//+------------------------------------------------------------------+
bool CheckIndicator()
{
   for(int win = 0; win < ChartWindowsTotal(0); win++)
   {
      int total = ChartIndicatorsTotal(0, win);
      for(int i = 0; i < total; i++)
      {
         string name = ChartIndicatorName(0, win, i);
         if(StringFind(name, "Smart Money") >= 0 || 
            StringFind(name, "SMC") >= 0)
         {
            Print("✓ Found indicator: ", name);
            return true;
         }
      }
   }
   
   Print("⚠ SMC Indicator not found on chart!");
   return false;
}

//+------------------------------------------------------------------+
//| Show setup instructions                                           |
//+------------------------------------------------------------------+
void ShowSetupInstructions()
{
   Print("═══════════════════════════════════════════════════════════");
   Print("                   SETUP INSTRUCTIONS                       ");
   Print("═══════════════════════════════════════════════════════════");
   Print("");
   Print("  The 'Smart Money Concepts' indicator is NOT on the chart.");
   Print("");
   Print("  Please follow these steps:");
   Print("  1. Press Ctrl+I (or Insert → Indicators → Custom)");
   Print("  2. Select 'Smart Money Concepts'");
   Print("  3. Configure the indicator settings as you like");
   Print("  4. Click OK");
   Print("");
   Print("  The EA will then automatically:");
   Print("  ✓ Monitor BOS/CHoCH signals from the indicator");
   Print("  ✓ Open trades based on your EA settings");
   Print("  ✓ Manage positions with SL/TP");
   Print("");
   Print("  NOTE: You can change indicator settings anytime!");
   Print("        Just right-click chart → Indicators List → Properties");
   Print("");
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up panel
   ObjectsDeleteAll(0, "SMCEA_");
   
   Print("══════════════════════════════════════════════════════════");
   Print("SMC Hybrid EA Stopped.");
   Print("Total Trades: ", totalTrades);
   Print("══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check daily limits
   if(!CheckDailyLimits())
      return;
   
   // Monitor for new signals
   MonitorObjects();
   
   // Apply trailing stop
   if(UseTrailingStop)
      ApplyTrailingStop();
   
   // Update panel
   if(ShowPanel)
      UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Check daily profit/loss limits                                    |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
   if(MaxDailyLoss == 0 && MaxDailyProfit == 0)
      return true;
   
   // Reset daily counter at start of new day
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != lastDailyCheck)
   {
      dailyPL = 0;
      lastDailyCheck = today;
   }
   
   // Calculate today's P/L
   HistorySelect(today, TimeCurrent());
   dailyPL = 0;
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber)
      {
         dailyPL += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      }
   }
   
   // Check limits
   if(MaxDailyLoss > 0 && dailyPL <= -MaxDailyLoss)
   {
      if(DebugMode)
         Print("⚠ Daily loss limit reached: $", dailyPL);
      return false;
   }
   
   if(MaxDailyProfit > 0 && dailyPL >= MaxDailyProfit)
   {
      if(DebugMode)
         Print("✓ Daily profit target reached: $", dailyPL);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Scan existing objects                                             |
//+------------------------------------------------------------------+
void ScanExistingObjects()
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
         string textUpper = text;
         StringToUpper(textUpper);
         
         if(StringFind(textUpper, "BOS") >= 0)
            totalBOS++;
         else if(StringFind(textUpper, "CHOCH") >= 0)
            totalCHoCH++;
      }
   }
   
   objectCountLast = total;
   
   if(DebugMode)
      Print("Initial scan: ", totalBOS, " BOS, ", totalCHoCH, " CHoCH");
}

//+------------------------------------------------------------------+
//| Monitor objects for new signals                                   |
//+------------------------------------------------------------------+
void MonitorObjects()
{
   int currentCount = ObjectsTotal(0, 0, -1);
   
   // Check for new objects
   if(currentCount != objectCountLast)
   {
      if(DebugMode)
         Print("Object count changed: ", objectCountLast, " → ", currentCount);
      
      // Scan all objects to find new ones
      for(int i = 0; i < currentCount; i++)
      {
         string name = ObjectName(0, i, 0, -1);
         
         // Skip already processed signals
         if(name == lastBOSSignal || name == lastCHoCHSignal || name == lastOBSignal)
            continue;
         
         ProcessObject(name);
      }
      
      objectCountLast = currentCount;
   }
}

//+------------------------------------------------------------------+
//| Process object for potential trading signal                       |
//+------------------------------------------------------------------+
void ProcessObject(string obj_name)
{
   ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, obj_name, OBJPROP_TYPE);
   
   // Only process text objects
   if(type != OBJ_TEXT && type != OBJ_LABEL)
      return;
   
   string text = ObjectGetString(0, obj_name, OBJPROP_TEXT);
   string textUpper = text;
   StringToUpper(textUpper);
   
   datetime obj_time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
   double obj_price = ObjectGetDouble(0, obj_name, OBJPROP_PRICE);
   color obj_color = (color)ObjectGetInteger(0, obj_name, OBJPROP_COLOR);
   
   // Check signal age
   int barsSince = iBarShift(_Symbol, PERIOD_CURRENT, obj_time);
   if(OnlyNewSignals && barsSince > SignalExpiryBars)
      return;
   
   // Determine direction by color
   bool isBullish = IsBullishColor(obj_color);
   
   // Detect BOS
   if(StringFind(textUpper, "BOS") >= 0 && TradeOnBOS)
   {
      if(obj_name != lastBOSSignal)
      {
         if(DebugMode)
            Print("► BOS Signal detected: ", obj_name, " | ", isBullish ? "BULLISH" : "BEARISH", " | Price: ", obj_price);
         
         if(CanTrade())
         {
            if(isBullish)
               OpenTrade(ORDER_TYPE_BUY, "BOS_Bullish");
            else
               OpenTrade(ORDER_TYPE_SELL, "BOS_Bearish");
         }
         
         lastBOSSignal = obj_name;
         totalBOS++;
      }
   }
   // Detect CHoCH
   else if(StringFind(textUpper, "CHOCH") >= 0 && TradeOnCHoCH)
   {
      if(obj_name != lastCHoCHSignal)
      {
         if(DebugMode)
            Print("► CHoCH Signal detected: ", obj_name, " | ", isBullish ? "BULLISH" : "BEARISH", " | Price: ", obj_price);
         
         if(CanTrade())
         {
            if(isBullish)
               OpenTrade(ORDER_TYPE_BUY, "CHoCH_Bullish");
            else
               OpenTrade(ORDER_TYPE_SELL, "CHoCH_Bearish");
         }
         
         lastCHoCHSignal = obj_name;
         totalCHoCH++;
      }
   }
   // Detect Order Block (if name contains "OB")
   else if((StringFind(textUpper, "OB") >= 0 || StringFind(textUpper, "ORDER") >= 0) && TradeOnOBTouch)
   {
      if(obj_name != lastOBSignal)
      {
         if(DebugMode)
            Print("► Order Block detected: ", obj_name);
         
         // Check if price is touching the OB
         double currentPrice = isBullish ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double distance = MathAbs(currentPrice - obj_price) / _Point;
         
         if(distance < 100 && CanTrade()) // Within 100 points
         {
            if(isBullish)
               OpenTrade(ORDER_TYPE_BUY, "OB_Bullish");
            else
               OpenTrade(ORDER_TYPE_SELL, "OB_Bearish");
         }
         
         lastOBSignal = obj_name;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if color indicates bullish                                  |
//+------------------------------------------------------------------+
bool IsBullishColor(color clr)
{
   // Check against EA configured bullish colors
   if(clr == BullishColor1 || clr == BullishColor2 || clr == BullishColor3)
      return true;
   
   // Check against EA configured bearish colors
   if(clr == BearishColor1 || clr == BearishColor2 || clr == BearishColor3)
      return false;
   
   // Default: Common green/blue = bullish
   if(clr == clrLime || clr == clrGreen || clr == clrSpringGreen ||
      clr == clrLimeGreen || clr == clrDodgerBlue || clr == clrDeepSkyBlue ||
      clr == clrAqua || clr == clrCyan)
      return true;
   
   // Common red/orange = bearish
   if(clr == clrRed || clr == clrOrangeRed || clr == clrCrimson ||
      clr == clrDarkRed || clr == clrMaroon || clr == clrOrange)
      return false;
   
   // Default to bullish if unknown
   return true;
}

//+------------------------------------------------------------------+
//| Check if can open new trade                                       |
//+------------------------------------------------------------------+
bool CanTrade()
{
   // Check max positions
   int openPositions = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         openPositions++;
      }
   }
   
   if(openPositions >= MaxPositions)
   {
      if(DebugMode)
         Print("Max positions reached: ", openPositions);
      return false;
   }
   
   // Check time since last trade (prevent spam)
   if(TimeCurrent() - lastTradeTime < 60)
   {
      if(DebugMode)
         Print("Trade cooldown active");
      return false;
   }
   
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
         Print("✓ BUY Order Opened: ", comment, " @ ", price);
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
      else
      {
         Print("✗ BUY Order Failed: ", GetLastError());
      }
   }
   else if(type == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = (StopLoss > 0) ? price + StopLoss * point : 0;
      tp = (TakeProfit > 0) ? price - TakeProfit * point : 0;
      
      if(trade.Sell(LotSize, _Symbol, price, sl, tp, comment))
      {
         Print("✓ SELL Order Opened: ", comment, " @ ", price);
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
      else
      {
         Print("✗ SELL Order Failed: ", GetLastError());
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
      if(PositionGetSymbol(i) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      
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
            {
               trade.PositionModify(ticket, newSL, currentTP);
            }
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit = (openPrice - ask) / point;
         
         if(profit >= TrailingStart)
         {
            double newSL = ask + TrailingStep * point;
            if(newSL < currentSL - point || currentSL == 0)
            {
               trade.PositionModify(ticket, newSL, currentTP);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create info panel                                                 |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
   int x = 10, y = 30;
   int width = 240;
   int height = 20;
   
   // Background
   ObjectCreate(0, "SMCEA_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_XDISTANCE, x - 5);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_YDISTANCE, y - 5);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_XSIZE, width + 10);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_YSIZE, 160);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_BGCOLOR, C'20,25,35');
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_COLOR, C'0,150,255');
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_WIDTH, 2);
   
   // Labels
   CreateLabel("SMCEA_Title", "◆ SMC Hybrid EA v6.0", x, y, C'0,200,255', 11);
   CreateLabel("SMCEA_Ind", "Indicator: ...", x, y + 25, clrWhite, 9);
   CreateLabel("SMCEA_BOS", "BOS Signals: 0", x, y + 47, clrYellow, 9);
   CreateLabel("SMCEA_CHoCH", "CHoCH Signals: 0", x, y + 69, clrMagenta, 9);
   CreateLabel("SMCEA_Trades", "Total Trades: 0", x, y + 91, clrLime, 9);
   CreateLabel("SMCEA_Pos", "Open Positions: 0", x, y + 113, clrAqua, 9);
   CreateLabel("SMCEA_PL", "Daily P/L: $0.00", x, y + 135, clrGold, 9);
}

void CreateLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Update info panel                                                 |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 1)
      return;
   lastUpdate = TimeCurrent();
   
   // Check if indicator is on chart
   bool indFound = CheckIndicator();
   
   ObjectSetString(0, "SMCEA_Ind", OBJPROP_TEXT, 
      "Indicator: " + (indFound ? "● Active" : "○ Not Found"));
   ObjectSetInteger(0, "SMCEA_Ind", OBJPROP_COLOR, 
      indFound ? clrLime : clrOrange);
   
   ObjectSetString(0, "SMCEA_BOS", OBJPROP_TEXT, 
      "BOS Signals: " + IntegerToString(totalBOS));
   ObjectSetString(0, "SMCEA_CHoCH", OBJPROP_TEXT, 
      "CHoCH Signals: " + IntegerToString(totalCHoCH));
   ObjectSetString(0, "SMCEA_Trades", OBJPROP_TEXT, 
      "Total Trades: " + IntegerToString(totalTrades));
   
   // Count open positions
   int openPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         openPos++;
   }
   ObjectSetString(0, "SMCEA_Pos", OBJPROP_TEXT, 
      "Open Positions: " + IntegerToString(openPos));
   
   // Show daily P/L
   color plColor = (dailyPL >= 0) ? clrLime : clrRed;
   ObjectSetString(0, "SMCEA_PL", OBJPROP_TEXT, 
      "Daily P/L: $" + DoubleToString(dailyPL, 2));
   ObjectSetInteger(0, "SMCEA_PL", OBJPROP_COLOR, plColor);
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CREATE)
   {
      if(DebugMode)
         Print("New object created: ", sparam);
      
      // Small delay to let the object fully initialize
      Sleep(50);
      ProcessObject(sparam);
   }
}
//+------------------------------------------------------------------+
