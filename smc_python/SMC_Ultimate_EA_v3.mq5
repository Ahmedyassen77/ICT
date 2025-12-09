//+------------------------------------------------------------------+
//|                                          SMC_Ultimate_EA_v3.mq5 |
//|          Full Control - Loads & Controls SMC Indicator Directly |
//|                            https://github.com/Ahmedyassen77/ICT |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen - SMC Ultimate EA v3"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "3.00"
#property description "Loads Smart Money Concepts indicator with FULL parameter control"
#property description "Changes to EA inputs will reload the indicator automatically!"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INDICATOR INPUTS - Exact copy of Smart Money Concepts 1.0        |
//+------------------------------------------------------------------+
input group "══════════════ SMART MONEY CONCEPTS SETTINGS ══════════════"
input int      Ind_Candles = 2000;                    // How many candles to calculate in history (0=All)
input string   Ind_Mode = "Historical";               // Mode
input string   Ind_Style = "Colored";                 // Style
input bool     Ind_ColorCandles = false;              // Color Candles

input group "══════════════ REAL TIME INTERNAL STRUCTURE ══════════════"
input bool     Ind_ShowInternalStructure = true;      // Show Internal Structure
input string   Ind_BullishStructure = "All";          // Bullish Structure
input color    Ind_BullishColor = C'8,153,129';       // Bullish Color
input string   Ind_BearishStructure = "All";          // Bearish Structure
input color    Ind_BearishColor = C'242,54,69';       // Bearish Color
input bool     Ind_ConfluenceFilter = false;          // Confluence Filter

input group "══════════════ REAL TIME SWING STRUCTURE ══════════════"
input bool     Ind_ShowSwingStructure = true;         // Show Swing Structure
input string   Ind_SwingBullishStructure = "All";     // Bullish Structure
input color    Ind_SwingBullishColor = C'8,153,129';  // Bullish Color
input string   Ind_SwingBearishStructure = "All";     // Bearish Structure
input color    Ind_SwingBearishColor = C'242,54,69';  // Bearish Color
input bool     Ind_ShowSwingsPoints = false;          // Show Swings Points
input int      Ind_Length = 50;                       // Length
input bool     Ind_ShowStrongWeakHL = true;           // Show Strong/Weak High/Low

input group "══════════════ ORDER BLOCKS ══════════════"
input bool     Ind_ShowInternalOB = true;             // Show Internal Order Blocks
input int      Ind_InternalOB_Count = 5;              // Internal Order Blocks
input bool     Ind_SwingOrderBlocks = false;          // Swing Order Blocks
input int      Ind_SwingOB_Count = 5;                 // Swing Order Blocks Count
input string   Ind_OB_Filter = "Atr";                 // Order Block Filter
input color    Ind_InternalBullishOB = C'91,156,246'; // Internal Bullish OB
input color    Ind_InternalBearishOB = C'247,124,128';// Internal Bearish OB
input color    Ind_BullishOB = C'24,72,204';          // Bullish OB
input color    Ind_BearishOB = C'178,40,51';          // Bearish OB

input group "══════════════ EQH/EQL ══════════════"
input bool     Ind_EqualHL = true;                    // Equal High/Low
input int      Ind_BarsConfirmation = 3;              // Bars Confirmation
input double   Ind_Threshold = 0.1;                   // Threshold

input group "══════════════ FAIR VALUE GAPS ══════════════"
input bool     Ind_FairValueGaps = false;             // Fair Value Gaps
input bool     Ind_AutoThreshold = true;              // Auto Threshold
input string   Ind_FVG_Timeframe = "current";         // Timeframe
input color    Ind_BullishFVG = C'0,255,104';         // Bullish FVG
input color    Ind_BearishFVG = C'255,0,8';           // Bearish FVG
input int      Ind_ExtendFVG = 1;                     // Extend FVG

input group "══════════════ HIGHS & LOWS MTF ══════════════"
input bool     Ind_ShowDaily = false;                 // Show Daily
input string   Ind_StyleDaily = "Solid";              // Style Daily
input color    Ind_ColorDaily = C'33,87,243';         // Color Daily
input bool     Ind_ShowWeekly = false;                // Show Weekly
input string   Ind_StyleWeekly = "Solid";             // Style Weekly
input color    Ind_ColorWeekly = C'33,87,243';        // Color Weekly
input bool     Ind_ShowMonthly = false;               // Show Monthly
input string   Ind_StyleMonthly = "Solid";            // Style Monthly
input color    Ind_ColorMonthly = C'33,87,243';       // Color Monthly

input group "══════════════ PREMIUM & DISCOUNT ZONES ══════════════"
input bool     Ind_PremiumDiscountZones = false;      // Premium/Discount Zones
input color    Ind_PremiumZone = C'242,54,69';        // Premium Zone
input color    Ind_EquilibriumZone = C'178,181,190';  // Equilibrium Zone
input color    Ind_DiscountZone = C'8,153,129';       // Discount Zone

//+------------------------------------------------------------------+
//| TRADING INPUTS                                                    |
//+------------------------------------------------------------------+
input group "══════════════ TRADE SETTINGS ══════════════"
input double   LotSize = 0.1;                         // Lot Size
input int      StopLoss = 500;                        // Stop Loss (points)
input int      TakeProfit = 1000;                     // Take Profit (points)
input int      MagicNumber = 999888;                  // Magic Number
input int      MaxPositions = 1;                      // Max Open Positions

input group "══════════════ SIGNAL SETTINGS ══════════════"
input bool     TradeOnBOS = true;                     // Trade on BOS
input bool     TradeOnCHoCH = true;                   // Trade on CHoCH
input bool     OnlyNewSignals = true;                 // Only New Signals
input int      SignalExpiryBars = 3;                  // Signal Expiry (bars)

input group "══════════════ RISK MANAGEMENT ══════════════"
input bool     UseTrailingStop = false;               // Use Trailing Stop
input int      TrailingStart = 300;                   // Trailing Start (points)
input int      TrailingStep = 100;                    // Trailing Step (points)

input group "══════════════ DISPLAY ══════════════"
input bool     ShowPanel = true;                      // Show Info Panel
input bool     DebugMode = true;                      // Debug Mode

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
string indicatorShortName = "Smart Money Concepts";
string indicatorFullName = "";
int indicatorWindow = 0;
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
   Print("║         SMC Ultimate EA v3.0 - Initializing          ║");
   Print("║     Full Indicator Control + Auto Trading            ║");
   Print("╚══════════════════════════════════════════════════════╝");
   
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(30);
   
   // Remove existing indicator and add with new parameters
   RemoveIndicator();
   Sleep(500);
   AddIndicator();
   
   // Initial scan
   ScanObjects();
   
   // Create panel
   if(ShowPanel) CreatePanel();
   
   Print("✓ EA Ready! Monitoring SMC signals...");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Remove existing SMC indicator from chart                          |
//+------------------------------------------------------------------+
void RemoveIndicator()
{
   int total = ChartIndicatorsTotal(0, 0);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ChartIndicatorName(0, 0, i);
      
      // Check if it's our indicator
      if(StringFind(name, "Smart Money") >= 0 || 
         StringFind(name, "SMC") >= 0)
      {
         if(ChartIndicatorDelete(0, 0, name))
         {
            Print("✓ Removed existing indicator: ", name);
         }
      }
   }
   
   // Also check subwindows
   for(int win = 1; win < ChartWindowsTotal(0); win++)
   {
      total = ChartIndicatorsTotal(0, win);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ChartIndicatorName(0, win, i);
         if(StringFind(name, "Smart Money") >= 0 || StringFind(name, "SMC") >= 0)
         {
            ChartIndicatorDelete(0, win, name);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Add SMC indicator with EA parameters                              |
//+------------------------------------------------------------------+
void AddIndicator()
{
   Print("Loading indicator with EA parameters...");
   
   // Create indicator handle with all parameters
   int handle = iCustom(_Symbol, PERIOD_CURRENT, indicatorShortName,
      // Smart Money Concepts Settings
      Ind_Candles,              // How many candles
      Ind_Mode,                 // Mode
      Ind_Style,                // Style
      Ind_ColorCandles,         // Color Candles
      // Real Time Internal Structure
      Ind_ShowInternalStructure,// Show Internal Structure
      Ind_BullishStructure,     // Bullish Structure
      Ind_BullishColor,         // Bullish Color
      Ind_BearishStructure,     // Bearish Structure
      Ind_BearishColor,         // Bearish Color
      Ind_ConfluenceFilter,     // Confluence Filter
      // Real Time Swing Structure
      Ind_ShowSwingStructure,   // Show Swing Structure
      Ind_SwingBullishStructure,// Bullish Structure
      Ind_SwingBullishColor,    // Bullish Color
      Ind_SwingBearishStructure,// Bearish Structure
      Ind_SwingBearishColor,    // Bearish Color
      Ind_ShowSwingsPoints,     // Show Swings Points
      Ind_Length,               // Length
      Ind_ShowStrongWeakHL,     // Show Strong/Weak High/Low
      // Order Blocks
      Ind_ShowInternalOB,       // Show Internal Order Blocks
      Ind_InternalOB_Count,     // Internal Order Blocks
      Ind_SwingOrderBlocks,     // Swing Order Blocks
      Ind_SwingOB_Count,        // Swing Order Blocks Count
      Ind_OB_Filter,            // Order Block Filter
      Ind_InternalBullishOB,    // Internal Bullish OB
      Ind_InternalBearishOB,    // Internal Bearish OB
      Ind_BullishOB,            // Bullish OB
      Ind_BearishOB,            // Bearish OB
      // EQH/EQL
      Ind_EqualHL,              // Equal High/Low
      Ind_BarsConfirmation,     // Bars Confirmation
      Ind_Threshold,            // Threshold
      // Fair Value Gaps
      Ind_FairValueGaps,        // Fair Value Gaps
      Ind_AutoThreshold,        // Auto Threshold
      Ind_FVG_Timeframe,        // Timeframe
      Ind_BullishFVG,           // Bullish FVG
      Ind_BearishFVG,           // Bearish FVG
      Ind_ExtendFVG,            // Extend FVG
      // Highs & Lows MTF
      Ind_ShowDaily,            // Show Daily
      Ind_StyleDaily,           // Style Daily
      Ind_ColorDaily,           // Color Daily
      Ind_ShowWeekly,           // Show Weekly
      Ind_StyleWeekly,          // Style Weekly
      Ind_ColorWeekly,          // Color Weekly
      Ind_ShowMonthly,          // Show Monthly
      Ind_StyleMonthly,         // Style Monthly
      Ind_ColorMonthly,         // Color Monthly
      // Premium & Discount Zones
      Ind_PremiumDiscountZones, // Premium/Discount Zones
      Ind_PremiumZone,          // Premium Zone
      Ind_EquilibriumZone,      // Equilibrium Zone
      Ind_DiscountZone          // Discount Zone
   );
   
   if(handle != INVALID_HANDLE)
   {
      // Add to chart
      if(ChartIndicatorAdd(0, 0, handle))
      {
         indicatorLoaded = true;
         Print("✓ Indicator loaded and added to chart successfully!");
         Print("✓ Parameters from EA are now active on the indicator!");
      }
      else
      {
         Print("✗ Failed to add indicator to chart. Error: ", GetLastError());
         // Try to add manually
         TryManualAdd();
      }
   }
   else
   {
      Print("✗ Failed to create indicator handle. Error: ", GetLastError());
      Print("Trying alternative method...");
      TryManualAdd();
   }
}

//+------------------------------------------------------------------+
//| Try manual add using template method                              |
//+------------------------------------------------------------------+
void TryManualAdd()
{
   Print("Attempting to apply indicator via template...");
   
   // Create a temporary template with indicator settings
   string templateContent = CreateIndicatorTemplate();
   
   if(templateContent != "")
   {
      // Save template
      string templatePath = "SMC_AutoLoad.tpl";
      int fileHandle = FileOpen(templatePath, FILE_WRITE|FILE_TXT|FILE_ANSI);
      
      if(fileHandle != INVALID_HANDLE)
      {
         FileWriteString(fileHandle, templateContent);
         FileClose(fileHandle);
         
         // Apply template
         if(ChartApplyTemplate(0, templatePath))
         {
            indicatorLoaded = true;
            Print("✓ Template applied successfully!");
         }
         else
         {
            Print("✗ Failed to apply template");
         }
      }
   }
   
   // Final fallback message
   if(!indicatorLoaded)
   {
      Print("═══════════════════════════════════════════════════════");
      Print("NOTICE: Please add 'Smart Money Concepts' indicator manually.");
      Print("The EA will still monitor and trade based on indicator signals.");
      Print("═══════════════════════════════════════════════════════");
   }
}

//+------------------------------------------------------------------+
//| Create template content with indicator                            |
//+------------------------------------------------------------------+
string CreateIndicatorTemplate()
{
   string tpl = "";
   
   tpl += "<chart>\n";
   tpl += "symbol=" + _Symbol + "\n";
   tpl += "period=" + IntegerToString(Period()) + "\n";
   tpl += "<window>\n";
   tpl += "height=100\n";
   tpl += "<indicator>\n";
   tpl += "name=Custom Indicator\n";
   tpl += "path=Smart Money Concepts.ex5\n";
   tpl += "<inputs>\n";
   tpl += "How many candles to calculate in history (0=All)=" + IntegerToString(Ind_Candles) + "\n";
   tpl += "Mode=" + Ind_Mode + "\n";
   tpl += "Style=" + Ind_Style + "\n";
   tpl += "Color Candles=" + (Ind_ColorCandles ? "true" : "false") + "\n";
   tpl += "Show Internal Structure=" + (Ind_ShowInternalStructure ? "true" : "false") + "\n";
   tpl += "Length=" + IntegerToString(Ind_Length) + "\n";
   tpl += "Show Swings Points=" + (Ind_ShowSwingsPoints ? "true" : "false") + "\n";
   tpl += "Show Internal Order Blocks=" + (Ind_ShowInternalOB ? "true" : "false") + "\n";
   tpl += "Fair Value Gaps=" + (Ind_FairValueGaps ? "true" : "false") + "\n";
   tpl += "</inputs>\n";
   tpl += "</indicator>\n";
   tpl += "</window>\n";
   tpl += "</chart>\n";
   
   return tpl;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Don't remove indicator if just changing parameters
   if(reason == REASON_PARAMETERS)
   {
      Print("Parameters changed - Indicator will be reloaded...");
   }
   else
   {
      // Remove indicator when EA is removed
      RemoveIndicator();
   }
   
   ObjectsDeleteAll(0, "SMCEA_");
   Print("SMC Ultimate EA Stopped. Total trades: ", totalTrades);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Monitor objects
   MonitorObjects();
   
   // Trailing stop
   if(UseTrailingStop) ApplyTrailingStop();
   
   // Update panel
   if(ShowPanel) UpdatePanel();
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
      Print("Scanned: ", totalBOS, " BOS, ", totalCHoCH, " CHoCH");
}

//+------------------------------------------------------------------+
//| Monitor objects for new signals                                   |
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
         {
            ProcessObject(name);
         }
      }
      objectCountLast = currentCount;
   }
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
   
   // Determine direction
   bool isBullish = IsBullishColor(obj_color);
   
   // BOS Signal
   if(StringFind(textUpper, "BOS") >= 0 && TradeOnBOS)
   {
      if(obj_name != lastBOSSignal)
      {
         if(DebugMode) Print("► BOS Signal: ", isBullish ? "BULLISH" : "BEARISH");
         
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
         if(DebugMode) Print("► CHoCH Signal: ", isBullish ? "BULLISH" : "BEARISH");
         
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
   // Check against EA bullish colors
   if(clr == Ind_BullishColor || clr == Ind_SwingBullishColor ||
      clr == Ind_InternalBullishOB || clr == Ind_BullishOB ||
      clr == Ind_BullishFVG || clr == Ind_DiscountZone)
      return true;
   
   // Check against EA bearish colors
   if(clr == Ind_BearishColor || clr == Ind_SwingBearishColor ||
      clr == Ind_InternalBearishOB || clr == Ind_BearishOB ||
      clr == Ind_BearishFVG || clr == Ind_PremiumZone)
      return false;
   
   // Default green = bullish
   if(clr == clrLime || clr == clrGreen || clr == clrSpringGreen ||
      clr == clrDodgerBlue || clr == clrAqua)
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
         Print("✓ BUY: ", comment, " @ ", price);
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
         Print("✓ SELL: ", comment, " @ ", price);
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
   
   ObjectCreate(0, "SMCEA_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_XDISTANCE, x - 5);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_YDISTANCE, y - 5);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_XSIZE, 250);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_YSIZE, 155);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_BGCOLOR, C'20,20,30');
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_COLOR, C'0,150,255');
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "SMCEA_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   CreateLabel("SMCEA_Title", "◆ SMC Ultimate EA v3.0", x, y, C'0,200,255', 11);
   CreateLabel("SMCEA_Ind", "Indicator: Checking...", x, y + 25, clrWhite, 9);
   CreateLabel("SMCEA_BOS", "BOS Signals: 0", x, y + 47, clrYellow, 9);
   CreateLabel("SMCEA_CHoCH", "CHoCH Signals: 0", x, y + 69, clrMagenta, 9);
   CreateLabel("SMCEA_Trades", "Total Trades: 0", x, y + 91, clrLime, 9);
   CreateLabel("SMCEA_Pos", "Open Positions: 0", x, y + 113, clrAqua, 9);
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
   
   // Check if indicator is on chart
   bool indOnChart = false;
   int total = ChartIndicatorsTotal(0, 0);
   for(int i = 0; i < total; i++)
   {
      string name = ChartIndicatorName(0, 0, i);
      if(StringFind(name, "Smart Money") >= 0 || StringFind(name, "SMC") >= 0)
      {
         indOnChart = true;
         break;
      }
   }
   
   ObjectSetString(0, "SMCEA_Ind", OBJPROP_TEXT, 
      "Indicator: " + (indOnChart ? "● Active" : "○ Not Found"));
   ObjectSetInteger(0, "SMCEA_Ind", OBJPROP_COLOR, 
      indOnChart ? clrLime : clrOrange);
   
   ObjectSetString(0, "SMCEA_BOS", OBJPROP_TEXT, "BOS Signals: " + IntegerToString(totalBOS));
   ObjectSetString(0, "SMCEA_CHoCH", OBJPROP_TEXT, "CHoCH Signals: " + IntegerToString(totalCHoCH));
   ObjectSetString(0, "SMCEA_Trades", OBJPROP_TEXT, "Total Trades: " + IntegerToString(totalTrades));
   
   int openPos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         openPos++;
   }
   ObjectSetString(0, "SMCEA_Pos", OBJPROP_TEXT, "Open Positions: " + IntegerToString(openPos));
}

//+------------------------------------------------------------------+
//| Chart event                                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CREATE)
   {
      if(DebugMode) Print("New object: ", sparam);
      ProcessObject(sparam);
   }
}
//+------------------------------------------------------------------+
