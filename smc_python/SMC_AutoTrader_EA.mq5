//+------------------------------------------------------------------+
//|                                           SMC_AutoTrader_EA.mq5 |
//|                  Auto-loads SMC Indicator and Trades from Signals |
//|                            https://github.com/Ahmedyassen77/ICT |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen - SMC AutoTrader"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "1.00"
#property description "Loads Smart Money Concepts indicator and trades based on its signals"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Indicator Settings ==="
input string IndicatorName = "Smart Money Concepts";  // Indicator name (without .ex5)
input string IndicatorPath = "";                       // Full path (empty = default)

input group "=== Trade Settings ==="
input double LotSize = 0.1;              // Lot Size
input int    StopLoss = 500;             // Stop Loss (points)
input int    TakeProfit = 1000;          // Take Profit (points)
input int    MagicNumber = 777888;       // Magic Number
input int    MaxPositions = 1;           // Max open positions

input group "=== Signal Settings ==="
input bool   TradeOnBOS = true;          // Trade on BOS (Break of Structure)
input bool   TradeOnCHoCH = true;        // Trade on CHoCH (Change of Character)
input bool   OnlyNewSignals = true;      // Only trade new signals
input int    SignalExpiryBars = 3;       // Signal expires after X bars

input group "=== Risk Management ==="
input bool   UseTrailingStop = false;    // Use Trailing Stop
input int    TrailingStart = 300;        // Trailing Start (points)
input int    TrailingStep = 100;         // Trailing Step (points)

input group "=== Display ==="
input bool   ShowPanel = true;           // Show Info Panel
input bool   DebugMode = true;           // Debug Mode (print logs)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
int indicatorHandle = INVALID_HANDLE;
bool indicatorLoaded = false;

// Signal tracking
string lastBOSSignal = "";
string lastCHoCHSignal = "";
datetime lastTradeTime = 0;
int objectCountLast = 0;

// Statistics
int totalBOSFound = 0;
int totalCHoCHFound = 0;
int totalTrades = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("╔════════════════════════════════════════════╗");
   Print("║     SMC AutoTrader EA - Initializing       ║");
   Print("╚════════════════════════════════════════════╝");
   
   // Setup trade
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   // Try to load the indicator
   if(!LoadSMCIndicator())
   {
      Print("WARNING: Could not load indicator via iCustom.");
      Print("Please ensure the indicator is added to the chart manually.");
      Print("EA will still monitor objects drawn by any SMC indicator.");
   }
   
   // Initial object scan
   ScanExistingObjects();
   
   // Create info panel
   if(ShowPanel)
      CreateInfoPanel();
   
   Print("EA Ready! Monitoring for SMC signals...");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Load SMC Indicator                                                |
//+------------------------------------------------------------------+
bool LoadSMCIndicator()
{
   string fullPath = IndicatorPath;
   
   if(fullPath == "")
      fullPath = IndicatorName;
   
   // Try to create indicator handle
   // Note: iCustom works with compiled .ex5 indicators
   indicatorHandle = iCustom(_Symbol, PERIOD_CURRENT, fullPath);
   
   if(indicatorHandle == INVALID_HANDLE)
   {
      int error = GetLastError();
      Print("Failed to load indicator: ", fullPath, " Error: ", error);
      
      // Try alternative paths
      string altPaths[] = {
         "Smart Money Concepts",
         "Indicators\\Smart Money Concepts",
         "Market\\Smart Money Concepts",
         "Downloads\\Smart Money Concepts"
      };
      
      for(int i = 0; i < ArraySize(altPaths); i++)
      {
         indicatorHandle = iCustom(_Symbol, PERIOD_CURRENT, altPaths[i]);
         if(indicatorHandle != INVALID_HANDLE)
         {
            Print("Indicator loaded from: ", altPaths[i]);
            indicatorLoaded = true;
            return true;
         }
      }
      
      return false;
   }
   
   indicatorLoaded = true;
   Print("Indicator loaded successfully: ", fullPath);
   return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator
   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);
   
   // Delete panel
   ObjectsDeleteAll(0, "SMC_Panel_");
   
   Print("SMC AutoTrader EA Stopped. Total trades: ", totalTrades);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Monitor objects for new signals
   MonitorSMCObjects();
   
   // Apply trailing stop if enabled
   if(UseTrailingStop)
      ApplyTrailingStop();
   
   // Update panel
   if(ShowPanel)
      UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Scan existing objects on chart                                    |
//+------------------------------------------------------------------+
void ScanExistingObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   
   if(DebugMode)
      Print("Scanning ", total, " objects on chart...");
   
   totalBOSFound = 0;
   totalCHoCHFound = 0;
   
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, 0, -1);
      ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
      
      if(type == OBJ_TEXT || type == OBJ_LABEL)
      {
         string text = ObjectGetString(0, name, OBJPROP_TEXT);
         
         if(StringFind(StringUpper(text), "BOS") >= 0)
            totalBOSFound++;
         else if(StringFind(StringUpper(text), "CHOCH") >= 0)
            totalCHoCHFound++;
      }
   }
   
   objectCountLast = total;
   
   if(DebugMode)
      Print("Found: ", totalBOSFound, " BOS, ", totalCHoCHFound, " CHoCH");
}

//+------------------------------------------------------------------+
//| Monitor SMC objects for trading signals                           |
//+------------------------------------------------------------------+
void MonitorSMCObjects()
{
   int currentCount = ObjectsTotal(0, 0, -1);
   
   // Check for new objects
   if(currentCount > objectCountLast)
   {
      // New objects added - scan them
      for(int i = 0; i < currentCount; i++)
      {
         string name = ObjectName(0, i, 0, -1);
         
         // Check if this is a new signal we haven't processed
         if(!IsProcessedSignal(name))
         {
            ProcessObject(name);
         }
      }
   }
   
   // Also scan recent objects periodically
   static datetime lastFullScan = 0;
   if(TimeCurrent() - lastFullScan > 60) // Every minute
   {
      ScanRecentSignals();
      lastFullScan = TimeCurrent();
   }
   
   objectCountLast = currentCount;
}

//+------------------------------------------------------------------+
//| Check if signal was already processed                             |
//+------------------------------------------------------------------+
bool IsProcessedSignal(string name)
{
   if(name == lastBOSSignal || name == lastCHoCHSignal)
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| Process an object for potential signal                            |
//+------------------------------------------------------------------+
void ProcessObject(string obj_name)
{
   ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, obj_name, OBJPROP_TYPE);
   
   // Only process text objects
   if(type != OBJ_TEXT && type != OBJ_LABEL)
      return;
   
   string text = ObjectGetString(0, obj_name, OBJPROP_TEXT);
   string textUpper = StringUpper(text);
   datetime obj_time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
   double obj_price = ObjectGetDouble(0, obj_name, OBJPROP_PRICE);
   color obj_color = (color)ObjectGetInteger(0, obj_name, OBJPROP_COLOR);
   
   // Check signal age
   int barsSince = iBarShift(_Symbol, PERIOD_CURRENT, obj_time);
   if(OnlyNewSignals && barsSince > SignalExpiryBars)
      return;
   
   // Detect BOS
   if(StringFind(textUpper, "BOS") >= 0 && TradeOnBOS)
   {
      bool isBullish = DetermineBullishByColorAndContext(obj_color, obj_name, text);
      
      if(DebugMode)
         Print("BOS Signal: ", obj_name, " Bullish: ", isBullish, " Price: ", obj_price);
      
      ProcessBOSSignal(obj_name, obj_time, obj_price, isBullish);
      lastBOSSignal = obj_name;
      totalBOSFound++;
   }
   // Detect CHoCH
   else if(StringFind(textUpper, "CHOCH") >= 0 && TradeOnCHoCH)
   {
      bool isBullish = DetermineBullishByColorAndContext(obj_color, obj_name, text);
      
      if(DebugMode)
         Print("CHoCH Signal: ", obj_name, " Bullish: ", isBullish, " Price: ", obj_price);
      
      ProcessCHoCHSignal(obj_name, obj_time, obj_price, isBullish);
      lastCHoCHSignal = obj_name;
      totalCHoCHFound++;
   }
}

//+------------------------------------------------------------------+
//| Determine if signal is bullish by color and context               |
//+------------------------------------------------------------------+
bool DetermineBullishByColorAndContext(color clr, string name, string text)
{
   // Method 1: Check by color
   // Green/Blue colors typically = Bullish
   // Red/Orange colors typically = Bearish
   
   if(clr == clrLime || clr == clrGreen || clr == clrSpringGreen || 
      clr == clrLimeGreen || clr == clrDodgerBlue || clr == clrDeepSkyBlue ||
      clr == clrAqua || clr == clrCyan)
      return true;
   
   if(clr == clrRed || clr == clrOrangeRed || clr == clrCrimson ||
      clr == clrDarkRed || clr == clrMaroon || clr == clrOrange)
      return false;
   
   // Method 2: Check text content
   string textLower = StringLower(text);
   if(StringFind(textLower, "bull") >= 0 || StringFind(textLower, "up") >= 0)
      return true;
   if(StringFind(textLower, "bear") >= 0 || StringFind(textLower, "down") >= 0)
      return false;
   
   // Method 3: Check object name
   string nameLower = StringLower(name);
   if(StringFind(nameLower, "bull") >= 0 || StringFind(nameLower, "up") >= 0)
      return true;
   if(StringFind(nameLower, "bear") >= 0 || StringFind(nameLower, "down") >= 0)
      return false;
   
   // Default: Check price action
   double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (close0 > close1);
}

//+------------------------------------------------------------------+
//| Scan recent signals (for signals we might have missed)            |
//+------------------------------------------------------------------+
void ScanRecentSignals()
{
   int total = ObjectsTotal(0, 0, -1);
   
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, 0, -1);
      ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
      
      if(type != OBJ_TEXT && type != OBJ_LABEL)
         continue;
      
      datetime obj_time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
      int barsSince = iBarShift(_Symbol, PERIOD_CURRENT, obj_time);
      
      // Only check recent objects
      if(barsSince <= SignalExpiryBars && !IsProcessedSignal(name))
      {
         ProcessObject(name);
      }
   }
}

//+------------------------------------------------------------------+
//| Process BOS signal                                                |
//+------------------------------------------------------------------+
void ProcessBOSSignal(string name, datetime signal_time, double signal_price, bool isBullish)
{
   // BOS = Trend continuation signal
   // Trade in the direction of the break
   
   if(!CanOpenNewTrade())
      return;
   
   if(isBullish)
   {
      if(DebugMode)
         Print(">>> BOS BUY Signal at ", signal_price);
      OpenTrade(ORDER_TYPE_BUY, "BOS_Bull");
   }
   else
   {
      if(DebugMode)
         Print(">>> BOS SELL Signal at ", signal_price);
      OpenTrade(ORDER_TYPE_SELL, "BOS_Bear");
   }
}

//+------------------------------------------------------------------+
//| Process CHoCH signal                                              |
//+------------------------------------------------------------------+
void ProcessCHoCHSignal(string name, datetime signal_time, double signal_price, bool isBullish)
{
   // CHoCH = Trend reversal signal
   // Trade in the new trend direction
   
   if(!CanOpenNewTrade())
      return;
   
   if(isBullish)
   {
      if(DebugMode)
         Print(">>> CHoCH BUY Signal (Reversal to Bullish) at ", signal_price);
      OpenTrade(ORDER_TYPE_BUY, "CHoCH_Bull");
   }
   else
   {
      if(DebugMode)
         Print(">>> CHoCH SELL Signal (Reversal to Bearish) at ", signal_price);
      OpenTrade(ORDER_TYPE_SELL, "CHoCH_Bear");
   }
}

//+------------------------------------------------------------------+
//| Check if can open new trade                                       |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
   // Check max positions
   int currentPositions = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            currentPositions++;
      }
   }
   
   if(currentPositions >= MaxPositions)
   {
      if(DebugMode)
         Print("Max positions reached: ", currentPositions);
      return false;
   }
   
   // Check time since last trade
   if(TimeCurrent() - lastTradeTime < 60) // At least 1 minute between trades
   {
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
         Print("BUY Order Opened: ", comment, " at ", price);
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
      else
      {
         Print("BUY Failed: ", GetLastError());
      }
   }
   else if(type == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = (StopLoss > 0) ? price + StopLoss * point : 0;
      tp = (TakeProfit > 0) ? price - TakeProfit * point : 0;
      
      if(trade.Sell(LotSize, _Symbol, price, sl, tp, comment))
      {
         Print("SELL Order Opened: ", comment, " at ", price);
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
      else
      {
         Print("SELL Failed: ", GetLastError());
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
   int width = 250;
   int height = 20;
   
   // Background
   ObjectCreate(0, "SMC_Panel_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_Panel_BG", OBJPROP_XDISTANCE, x - 5);
   ObjectSetInteger(0, "SMC_Panel_BG", OBJPROP_YDISTANCE, y - 5);
   ObjectSetInteger(0, "SMC_Panel_BG", OBJPROP_XSIZE, width + 10);
   ObjectSetInteger(0, "SMC_Panel_BG", OBJPROP_YSIZE, 150);
   ObjectSetInteger(0, "SMC_Panel_BG", OBJPROP_BGCOLOR, C'32,32,32');
   ObjectSetInteger(0, "SMC_Panel_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "SMC_Panel_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "SMC_Panel_BG", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "SMC_Panel_BG", OBJPROP_WIDTH, 2);
   
   // Title
   CreateLabel("SMC_Panel_Title", "SMC AutoTrader EA", x, y, clrDodgerBlue, 11);
   
   // Status labels
   CreateLabel("SMC_Panel_Ind", "Indicator: Loading...", x, y + 25, clrWhite, 9);
   CreateLabel("SMC_Panel_BOS", "BOS Found: 0", x, y + 45, clrYellow, 9);
   CreateLabel("SMC_Panel_CHoCH", "CHoCH Found: 0", x, y + 65, clrMagenta, 9);
   CreateLabel("SMC_Panel_Trades", "Total Trades: 0", x, y + 85, clrLime, 9);
   CreateLabel("SMC_Panel_Pos", "Open Positions: 0", x, y + 105, clrAqua, 9);
}

//+------------------------------------------------------------------+
//| Create label helper                                               |
//+------------------------------------------------------------------+
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
   if(TimeCurrent() - lastUpdate < 1) return;
   lastUpdate = TimeCurrent();
   
   // Update indicator status
   string indStatus = indicatorLoaded ? "Loaded" : "Manual/Not Found";
   ObjectSetString(0, "SMC_Panel_Ind", OBJPROP_TEXT, "Indicator: " + indStatus);
   ObjectSetInteger(0, "SMC_Panel_Ind", OBJPROP_COLOR, indicatorLoaded ? clrLime : clrOrange);
   
   // Update BOS count
   ObjectSetString(0, "SMC_Panel_BOS", OBJPROP_TEXT, "BOS Found: " + IntegerToString(totalBOSFound));
   
   // Update CHoCH count
   ObjectSetString(0, "SMC_Panel_CHoCH", OBJPROP_TEXT, "CHoCH Found: " + IntegerToString(totalCHoCHFound));
   
   // Update trades
   ObjectSetString(0, "SMC_Panel_Trades", OBJPROP_TEXT, "Total Trades: " + IntegerToString(totalTrades));
   
   // Update positions
   int openPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         openPos++;
   }
   ObjectSetString(0, "SMC_Panel_Pos", OBJPROP_TEXT, "Open Positions: " + IntegerToString(openPos));
}

//+------------------------------------------------------------------+
//| String to upper case                                              |
//+------------------------------------------------------------------+
string StringUpper(string str)
{
   string result = str;
   StringToUpper(result);
   return result;
}

//+------------------------------------------------------------------+
//| String to lower case                                              |
//+------------------------------------------------------------------+
string StringLower(string str)
{
   string result = str;
   StringToLower(result);
   return result;
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Detect new object creation
   if(id == CHARTEVENT_OBJECT_CREATE)
   {
      if(DebugMode)
         Print("New object created: ", sparam);
      
      // Small delay to let the object fully initialize
      Sleep(100);
      ProcessObject(sparam);
   }
}
//+------------------------------------------------------------------+
