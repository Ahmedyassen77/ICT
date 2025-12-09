//+------------------------------------------------------------------+
//|                                      SMC_Ultimate_EA_Final.mq5  |
//|          Auto-loads & Controls Smart Money Concepts Indicator    |
//|                        https://github.com/Ahmedyassen77/ICT      |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "4.00"
#property description "★ Auto-loads Smart Money Concepts indicator"
#property description "★ Full parameter control from EA"
#property description "★ Change EA inputs = Indicator updates automatically"

#include <Trade\Trade.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//+------------------------------------------------------------------+
//| INDICATOR INPUTS - EXACT ORDER FROM SMART MONEY CONCEPTS 1.0     |
//+------------------------------------------------------------------+
input group "══════════ SMART MONEY CONCEPTS - MAIN ══════════"
input int      Candles = 2000;                        // How many candles (0=All)

input group "══════════ INTERNAL STRUCTURE (Real Time) ══════════"
input bool     ShowInternalStructure = true;          // Show Internal Structure
input string   InternalBullishMode = "All";           // Bullish Structure
input color    InternalBullishColor = C'8,153,129';   // Bullish Color
input string   InternalBearishMode = "All";           // Bearish Structure
input color    InternalBearishColor = C'242,54,69';   // Bearish Color
input bool     ConfluenceFilter = false;              // Confluence Filter

input group "══════════ SWING STRUCTURE (Real Time) ══════════"
input bool     ShowSwingStructure = true;             // Show Swing Structure
input string   SwingBullishMode = "All";              // Bullish Structure
input color    SwingBullishColor = C'8,153,129';      // Bullish Color
input string   SwingBearishMode = "All";              // Bearish Structure
input color    SwingBearishColor = C'242,54,69';      // Bearish Color
input bool     ShowSwingPoints = false;               // Show Swings Points
input int      SwingLength = 50;                      // Length
input bool     ShowStrongWeakHighLow = true;          // Show Strong/Weak High/Low

input group "══════════ ORDER BLOCKS ══════════"
input bool     ShowInternalOrderBlocks = true;        // Show Internal Order Blocks
input int      InternalOrderBlocksCount = 5;          // Internal Order Blocks Count
input bool     SwingOrderBlocks = false;              // Swing Order Blocks
input int      SwingOrderBlocksCount = 5;             // Swing Order Blocks Count
input string   OrderBlockFilter = "Atr";              // Order Block Filter
input color    InternalBullishOB = C'91,156,246';     // Internal Bullish OB
input color    InternalBearishOB = C'247,124,128';    // Internal Bearish OB
input color    BullishOB = C'24,72,204';              // Bullish OB
input color    BearishOB = C'178,40,51';              // Bearish OB

input group "══════════ EQUAL HIGH/LOW ══════════"
input bool     EqualHighLow = true;                   // Equal High/Low
input int      BarsConfirmation = 3;                  // Bars Confirmation
input double   Threshold = 0.1;                       // Threshold

input group "══════════ FAIR VALUE GAPS ══════════"
input bool     FairValueGaps = false;                 // Fair Value Gaps
input bool     AutoThreshold = true;                  // Auto Threshold
input string   FVGTimeframe = "current";              // Timeframe
input color    BullishFVG = C'0,255,104';             // Bullish FVG
input color    BearishFVG = C'255,0,8';               // Bearish FVG
input int      ExtendFVG = 1;                         // Extend FVG

input group "══════════ HIGHS & LOWS MTF ══════════"
input bool     ShowDaily = false;                     // Show Daily
input string   StyleDaily = "Solid";                  // Style Daily
input color    ColorDaily = C'33,87,243';             // Color Daily
input bool     ShowWeekly = false;                    // Show Weekly
input string   StyleWeekly = "Solid";                 // Style Weekly
input color    ColorWeekly = C'33,87,243';            // Color Weekly
input bool     ShowMonthly = false;                   // Show Monthly
input string   StyleMonthly = "Solid";                // Style Monthly
input color    ColorMonthly = C'33,87,243';           // Color Monthly

input group "══════════ PREMIUM & DISCOUNT ZONES ══════════"
input bool     PremiumDiscountZones = false;          // Premium/Discount Zones
input color    PremiumZone = C'242,54,69';            // Premium Zone
input color    EquilibriumZone = C'178,181,190';      // Equilibrium Zone
input color    DiscountZone = C'8,153,129';           // Discount Zone

//+------------------------------------------------------------------+
//| TRADING INPUTS                                                    |
//+------------------------------------------------------------------+
input group "══════════ TRADING SETTINGS ══════════"
input double   LotSize = 0.1;                         // Lot Size
input int      StopLoss = 500;                        // Stop Loss (points)
input int      TakeProfit = 1000;                     // Take Profit (points)
input int      MagicNumber = 999999;                  // Magic Number
input int      MaxPositions = 1;                      // Max Positions

input group "══════════ SIGNAL SETTINGS ══════════"
input bool     TradeOnBOS = true;                     // Trade on BOS
input bool     TradeOnCHoCH = true;                   // Trade on CHoCH
input int      SignalExpiryBars = 3;                  // Signal Expiry (bars)

input group "══════════ DISPLAY ══════════"
input bool     ShowInfoPanel = true;                  // Show Info Panel
input bool     DebugMode = true;                      // Debug Mode

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
int indicatorHandle = INVALID_HANDLE;
bool indicatorLoadedOK = false;

// Signal tracking
string lastBOSProcessed = "";
string lastCHoCHProcessed = "";
int totalBOSFound = 0;
int totalCHoCHFound = 0;
int totalTrades = 0;
datetime lastTradeTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("╔═══════════════════════════════════════════════════════╗");
   Print("║    SMC Ultimate EA - Final Version - Starting         ║");
   Print("╚═══════════════════════════════════════════════════════╝");
   
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   
   // Load indicator with parameters
   if(!LoadIndicatorWithParameters())
   {
      Print("⚠ Warning: Indicator not loaded automatically");
      Print("⚠ Please add 'Smart Money Concepts' manually");
      Print("⚠ EA will still work by monitoring chart objects");
   }
   
   // Create info panel
   if(ShowInfoPanel)
      CreateInfoPanel();
   
   Print("✓ EA Ready - Monitoring SMC signals");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Load indicator with all parameters                                |
//+------------------------------------------------------------------+
bool LoadIndicatorWithParameters()
{
   Print("→ Loading Smart Money Concepts indicator...");
   
   // First, remove any existing SMC indicator
   RemoveExistingSMCIndicator();
   
   // Wait a bit
   Sleep(300);
   
   // Create indicator handle with parameters
   // IMPORTANT: Order must match exactly the indicator's input order!
   indicatorHandle = iCustom(
      _Symbol,
      PERIOD_CURRENT,
      "Smart Money Concepts",
      // Parameters in EXACT order as they appear in indicator
      Candles,
      ShowInternalStructure,
      InternalBullishMode,
      InternalBullishColor,
      InternalBearishMode,
      InternalBearishColor,
      ConfluenceFilter,
      ShowSwingStructure,
      SwingBullishMode,
      SwingBullishColor,
      SwingBearishMode,
      SwingBearishColor,
      ShowSwingPoints,
      SwingLength,
      ShowStrongWeakHighLow,
      ShowInternalOrderBlocks,
      InternalOrderBlocksCount,
      SwingOrderBlocks,
      SwingOrderBlocksCount,
      OrderBlockFilter,
      InternalBullishOB,
      InternalBearishOB,
      BullishOB,
      BearishOB,
      EqualHighLow,
      BarsConfirmation,
      Threshold,
      FairValueGaps,
      AutoThreshold,
      FVGTimeframe,
      BullishFVG,
      BearishFVG,
      ExtendFVG,
      ShowDaily,
      StyleDaily,
      ColorDaily,
      ShowWeekly,
      StyleWeekly,
      ColorWeekly,
      ShowMonthly,
      StyleMonthly,
      ColorMonthly,
      PremiumDiscountZones,
      PremiumZone,
      EquilibriumZone,
      DiscountZone
   );
   
   if(indicatorHandle == INVALID_HANDLE)
   {
      int error = GetLastError();
      Print("✗ Failed to create indicator handle. Error: ", error);
      return false;
   }
   
   Print("✓ Indicator handle created: ", indicatorHandle);
   
   // Add indicator to chart window 0
   if(!ChartIndicatorAdd(0, 0, indicatorHandle))
   {
      int error = GetLastError();
      Print("✗ Failed to add indicator to chart. Error: ", error);
      IndicatorRelease(indicatorHandle);
      indicatorHandle = INVALID_HANDLE;
      return false;
   }
   
   Print("✓ Indicator added to chart successfully!");
   Print("✓ All parameters from EA are now active!");
   
   indicatorLoadedOK = true;
   
   // Force chart redraw
   ChartRedraw(0);
   
   return true;
}

//+------------------------------------------------------------------+
//| Remove existing SMC indicator from chart                          |
//+------------------------------------------------------------------+
void RemoveExistingSMCIndicator()
{
   int total = ChartIndicatorsTotal(0, 0);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ChartIndicatorName(0, 0, i);
      
      // Check if it's Smart Money Concepts
      if(StringFind(name, "Smart Money") >= 0 || 
         StringFind(name, "SMC") >= 0 ||
         StringFind(name, "smart money") >= 0)
      {
         if(ChartIndicatorDelete(0, 0, name))
         {
            Print("✓ Removed existing indicator: ", name);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // If just changing parameters, reload indicator
   if(reason == REASON_PARAMETERS)
   {
      Print("→ Parameters changed - Reloading indicator...");
      return;
   }
   
   // Clean up
   if(indicatorHandle != INVALID_HANDLE)
   {
      IndicatorRelease(indicatorHandle);
   }
   
   ObjectsDeleteAll(0, "SMC_EA_");
   
   Print("SMC Ultimate EA Stopped");
   Print("Total Trades: ", totalTrades);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Monitor for new signals
   MonitorChartObjects();
   
   // Update panel
   if(ShowInfoPanel)
      UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Monitor chart objects for BOS/CHoCH signals                       |
//+------------------------------------------------------------------+
void MonitorChartObjects()
{
   static int lastObjectCount = 0;
   int currentObjectCount = ObjectsTotal(0, 0, -1);
   
   // Check if new objects appeared
   if(currentObjectCount != lastObjectCount)
   {
      // Scan all text objects
      for(int i = 0; i < currentObjectCount; i++)
      {
         string objName = ObjectName(0, i, 0, -1);
         
         ENUM_OBJECT objType = (ENUM_OBJECT)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         
         if(objType == OBJ_TEXT || objType == OBJ_LABEL)
         {
            ProcessTextObject(objName);
         }
      }
      
      lastObjectCount = currentObjectCount;
   }
}

//+------------------------------------------------------------------+
//| Process text object for signal                                    |
//+------------------------------------------------------------------+
void ProcessTextObject(string objName)
{
   string text = ObjectGetString(0, objName, OBJPROP_TEXT);
   
   if(text == "") return;
   
   // Convert to upper case for comparison
   string textUpper = text;
   StringToUpper(textUpper);
   
   datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
   double objPrice = ObjectGetDouble(0, objName, OBJPROP_PRICE);
   color objColor = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
   
   // Check if signal is recent
   int barsSince = iBarShift(_Symbol, PERIOD_CURRENT, objTime);
   if(barsSince > SignalExpiryBars) return;
   
   // Determine if bullish or bearish by color
   bool isBullish = IsBullishByColor(objColor);
   
   // Check for BOS
   if(StringFind(textUpper, "BOS") >= 0 && TradeOnBOS)
   {
      if(objName != lastBOSProcessed)
      {
         totalBOSFound++;
         lastBOSProcessed = objName;
         
         if(DebugMode)
            Print("► BOS Signal: ", isBullish ? "BULLISH" : "BEARISH", " @ ", objPrice);
         
         if(CanTrade())
         {
            if(isBullish)
               OpenTrade(ORDER_TYPE_BUY, "BOS_Buy");
            else
               OpenTrade(ORDER_TYPE_SELL, "BOS_Sell");
         }
      }
   }
   // Check for CHoCH
   else if((StringFind(textUpper, "CHOCH") >= 0 || StringFind(textUpper, "CHoCH") >= 0) && TradeOnCHoCH)
   {
      if(objName != lastCHoCHProcessed)
      {
         totalCHoCHFound++;
         lastCHoCHProcessed = objName;
         
         if(DebugMode)
            Print("► CHoCH Signal: ", isBullish ? "BULLISH" : "BEARISH", " @ ", objPrice);
         
         if(CanTrade())
         {
            if(isBullish)
               OpenTrade(ORDER_TYPE_BUY, "CHoCH_Buy");
            else
               OpenTrade(ORDER_TYPE_SELL, "CHoCH_Sell");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Determine if color indicates bullish                              |
//+------------------------------------------------------------------+
bool IsBullishByColor(color clr)
{
   // Check against EA's bullish colors
   if(clr == InternalBullishColor || clr == SwingBullishColor ||
      clr == InternalBullishOB || clr == BullishOB ||
      clr == BullishFVG || clr == DiscountZone)
      return true;
   
   // Check against EA's bearish colors
   if(clr == InternalBearishColor || clr == SwingBearishColor ||
      clr == InternalBearishOB || clr == BearishOB ||
      clr == BearishFVG || clr == PremiumZone)
      return false;
   
   // Default: green = bullish, red = bearish
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
   // Check max positions
   int openPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         openPos++;
   }
   
   if(openPos >= MaxPositions)
      return false;
   
   // Check time between trades
   if(TimeCurrent() - lastTradeTime < 60)
      return false;
   
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
         Print("✓ BUY Opened: ", comment, " @ ", price);
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
      else
      {
         Print("✗ BUY Failed: ", GetLastError());
      }
   }
   else if(type == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = (StopLoss > 0) ? price + StopLoss * point : 0;
      tp = (TakeProfit > 0) ? price - TakeProfit * point : 0;
      
      if(trade.Sell(LotSize, _Symbol, price, sl, tp, comment))
      {
         Print("✓ SELL Opened: ", comment, " @ ", price);
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
      else
      {
         Print("✗ SELL Failed: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Create info panel                                                 |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
   int x = 15, y = 40;
   int width = 260;
   
   // Background
   ObjectCreate(0, "SMC_EA_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_EA_BG", OBJPROP_XDISTANCE, x - 8);
   ObjectSetInteger(0, "SMC_EA_BG", OBJPROP_YDISTANCE, y - 8);
   ObjectSetInteger(0, "SMC_EA_BG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, "SMC_EA_BG", OBJPROP_YSIZE, 170);
   ObjectSetInteger(0, "SMC_EA_BG", OBJPROP_BGCOLOR, C'15,15,25');
   ObjectSetInteger(0, "SMC_EA_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "SMC_EA_BG", OBJPROP_COLOR, C'50,150,255');
   ObjectSetInteger(0, "SMC_EA_BG", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "SMC_EA_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // Title
   CreateLabel("SMC_EA_Title", "★ SMC Ultimate EA v4.0", x, y, C'100,200,255', 12);
   
   // Status labels
   CreateLabel("SMC_EA_Ind", "Indicator: Checking...", x, y + 28, clrWhite, 9);
   CreateLabel("SMC_EA_BOS", "BOS Signals: 0", x, y + 52, clrYellow, 9);
   CreateLabel("SMC_EA_CHoCH", "CHoCH Signals: 0", x, y + 76, clrMagenta, 9);
   CreateLabel("SMC_EA_Trades", "Total Trades: 0", x, y + 100, clrLime, 9);
   CreateLabel("SMC_EA_Pos", "Open Positions: 0", x, y + 124, clrAqua, 9);
   CreateLabel("SMC_EA_Status", "Status: Active", x, y + 148, clrLime, 9);
}

//+------------------------------------------------------------------+
//| Create label helper                                               |
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
//| Update info panel                                                 |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 2) return;
   lastUpdate = TimeCurrent();
   
   // Update indicator status
   string indStatus = indicatorLoadedOK ? "● Loaded & Active" : "○ Add Manually";
   color indColor = indicatorLoadedOK ? clrLime : clrOrange;
   
   ObjectSetString(0, "SMC_EA_Ind", OBJPROP_TEXT, "Indicator: " + indStatus);
   ObjectSetInteger(0, "SMC_EA_Ind", OBJPROP_COLOR, indColor);
   
   // Update counts
   ObjectSetString(0, "SMC_EA_BOS", OBJPROP_TEXT, "BOS Signals: " + IntegerToString(totalBOSFound));
   ObjectSetString(0, "SMC_EA_CHoCH", OBJPROP_TEXT, "CHoCH Signals: " + IntegerToString(totalCHoCHFound));
   ObjectSetString(0, "SMC_EA_Trades", OBJPROP_TEXT, "Total Trades: " + IntegerToString(totalTrades));
   
   // Count open positions
   int openPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         openPos++;
   }
   ObjectSetString(0, "SMC_EA_Pos", OBJPROP_TEXT, "Open Positions: " + IntegerToString(openPos));
}

//+------------------------------------------------------------------+
//| Chart event                                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CREATE)
   {
      // New object created - might be a signal
      Sleep(50); // Let object fully initialize
      ProcessTextObject(sparam);
   }
}
//+------------------------------------------------------------------+
