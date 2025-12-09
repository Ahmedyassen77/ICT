//+------------------------------------------------------------------+
//|                                         SMC_ObjectReader_EA.mq5 |
//|                    EA to Read Objects from SMC Indicator (.ex5) |
//|                          https://github.com/Ahmedyassen77/ICT   |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen - SMC Object Reader"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "1.00"
#property description "Reads visual objects from Smart Money Concepts indicator"

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "=== Trade Settings ==="
input double LotSize = 0.1;              // Lot Size
input int    StopLoss = 500;             // Stop Loss (points)
input int    TakeProfit = 1000;          // Take Profit (points)
input int    MagicNumber = 123456;       // Magic Number

input group "=== Signal Settings ==="
input bool   TradeOnBOS = true;          // Trade on BOS
input bool   TradeOnCHoCH = true;        // Trade on CHoCH
input bool   RequireOB = false;          // Require Order Block confirmation
input int    MinBarsSinceSignal = 1;     // Min bars since signal to trade

input group "=== Object Detection ==="
input string PrefixFilter = "";          // Object name prefix filter (empty = all)
input bool   ShowDebugInfo = true;       // Show debug information

//--- Global Variables
CTrade trade;
datetime lastSignalTime = 0;
string lastProcessedBOS = "";
string lastProcessedCHoCH = "";
int totalObjectsLast = 0;

//--- Signal tracking
struct SignalInfo
{
   string name;
   datetime time;
   double price;
   bool is_bullish;
   string type; // "BOS" or "CHoCH"
};

SignalInfo pendingSignals[];

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   
   Print("==============================================");
   Print("SMC Object Reader EA Initialized");
   Print("==============================================");
   
   // Discover existing objects
   DiscoverIndicatorObjects();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("SMC Object Reader EA Stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Monitor for new objects
   MonitorNewObjects();
   
   // Scan for SMC signals
   ScanForSMCSignals();
   
   // Process pending signals
   ProcessPendingSignals();
}

//+------------------------------------------------------------------+
//| Discover all indicator objects on chart                           |
//+------------------------------------------------------------------+
void DiscoverIndicatorObjects()
{
   Print("--- Discovering Chart Objects ---");
   
   int total = ObjectsTotal(0, 0, -1);
   Print("Total objects on chart: ", total);
   
   int bos_count = 0;
   int choch_count = 0;
   int ob_count = 0;
   int other_count = 0;
   
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, 0, -1);
      ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
      
      // Check for BOS/CHoCH text objects
      if(type == OBJ_TEXT)
      {
         string text = ObjectGetString(0, name, OBJPROP_TEXT);
         
         if(StringFind(text, "BOS") >= 0 || StringFind(text, "bos") >= 0)
         {
            bos_count++;
            if(ShowDebugInfo)
               Print("Found BOS: ", name, " Text: ", text);
         }
         else if(StringFind(text, "CHoCH") >= 0 || StringFind(text, "CHOCH") >= 0 || StringFind(text, "choch") >= 0)
         {
            choch_count++;
            if(ShowDebugInfo)
               Print("Found CHoCH: ", name, " Text: ", text);
         }
         else if(StringFind(text, "OB") >= 0 || StringFind(text, "Order") >= 0)
         {
            ob_count++;
            if(ShowDebugInfo)
               Print("Found OB: ", name, " Text: ", text);
         }
      }
      // Check for trend lines (BOS/CHoCH lines)
      else if(type == OBJ_TREND || type == OBJ_HLINE)
      {
         color clr = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
         
         // Try to identify by color
         if(ShowDebugInfo)
            Print("Found Line: ", name, " Color: ", ColorToString(clr));
      }
      // Check for rectangles (Order Blocks)
      else if(type == OBJ_RECTANGLE)
      {
         ob_count++;
         if(ShowDebugInfo)
            Print("Found Rectangle (possible OB): ", name);
      }
   }
   
   Print("--- Summary ---");
   Print("BOS objects: ", bos_count);
   Print("CHoCH objects: ", choch_count);
   Print("Order Block objects: ", ob_count);
   Print("----------------");
   
   totalObjectsLast = total;
}

//+------------------------------------------------------------------+
//| Monitor for new objects                                           |
//+------------------------------------------------------------------+
void MonitorNewObjects()
{
   int currentTotal = ObjectsTotal(0, 0, -1);
   
   if(currentTotal > totalObjectsLast)
   {
      if(ShowDebugInfo)
         Print("New object detected! Previous: ", totalObjectsLast, " Current: ", currentTotal);
      
      // Find the new objects
      for(int i = totalObjectsLast; i < currentTotal; i++)
      {
         string name = ObjectName(0, i, 0, -1);
         AnalyzeNewObject(name);
      }
   }
   
   totalObjectsLast = currentTotal;
}

//+------------------------------------------------------------------+
//| Analyze a new object                                              |
//+------------------------------------------------------------------+
void AnalyzeNewObject(string obj_name)
{
   ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, obj_name, OBJPROP_TYPE);
   datetime obj_time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
   double obj_price = ObjectGetDouble(0, obj_name, OBJPROP_PRICE);
   
   if(ShowDebugInfo)
      Print("Analyzing new object: ", obj_name, " Type: ", EnumToString(type));
   
   if(type == OBJ_TEXT)
   {
      string text = ObjectGetString(0, obj_name, OBJPROP_TEXT);
      color clr = (color)ObjectGetInteger(0, obj_name, OBJPROP_COLOR);
      
      // Detect BOS
      if(StringFind(text, "BOS") >= 0)
      {
         bool is_bullish = (clr == clrLime || clr == clrGreen || clr == clrDodgerBlue);
         
         SignalInfo signal;
         signal.name = obj_name;
         signal.time = obj_time;
         signal.price = obj_price;
         signal.is_bullish = is_bullish;
         signal.type = "BOS";
         
         AddPendingSignal(signal);
         
         Print(">>> NEW BOS SIGNAL: ", is_bullish ? "BULLISH" : "BEARISH", 
               " at price ", obj_price, " time ", TimeToString(obj_time));
      }
      // Detect CHoCH
      else if(StringFind(text, "CHoCH") >= 0 || StringFind(text, "CHOCH") >= 0)
      {
         bool is_bullish = (clr == clrLime || clr == clrGreen || clr == clrDodgerBlue);
         
         SignalInfo signal;
         signal.name = obj_name;
         signal.time = obj_time;
         signal.price = obj_price;
         signal.is_bullish = is_bullish;
         signal.type = "CHoCH";
         
         AddPendingSignal(signal);
         
         Print(">>> NEW CHoCH SIGNAL: ", is_bullish ? "BULLISH" : "BEARISH", 
               " at price ", obj_price, " time ", TimeToString(obj_time));
      }
   }
}

//+------------------------------------------------------------------+
//| Add signal to pending list                                        |
//+------------------------------------------------------------------+
void AddPendingSignal(SignalInfo &signal)
{
   int size = ArraySize(pendingSignals);
   ArrayResize(pendingSignals, size + 1);
   pendingSignals[size] = signal;
}

//+------------------------------------------------------------------+
//| Scan for SMC signals from existing objects                        |
//+------------------------------------------------------------------+
void ScanForSMCSignals()
{
   static datetime lastScan = 0;
   
   // Scan every new bar
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBar == lastScan) return;
   lastScan = currentBar;
   
   int total = ObjectsTotal(0, 0, OBJ_TEXT);
   
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, 0, OBJ_TEXT);
      string text = ObjectGetString(0, name, OBJPROP_TEXT);
      datetime obj_time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
      double obj_price = ObjectGetDouble(0, name, OBJPROP_PRICE);
      color clr = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
      
      // Skip old signals
      int barsSinceSignal = iBarShift(_Symbol, PERIOD_CURRENT, obj_time);
      if(barsSinceSignal > MinBarsSinceSignal) continue;
      
      // Check for BOS
      if(StringFind(text, "BOS") >= 0 && TradeOnBOS)
      {
         if(name != lastProcessedBOS)
         {
            bool is_bullish = IsBullishByColor(clr);
            ProcessBOSSignal(name, obj_time, obj_price, is_bullish);
            lastProcessedBOS = name;
         }
      }
      // Check for CHoCH
      else if((StringFind(text, "CHoCH") >= 0 || StringFind(text, "CHOCH") >= 0) && TradeOnCHoCH)
      {
         if(name != lastProcessedCHoCH)
         {
            bool is_bullish = IsBullishByColor(clr);
            ProcessCHoCHSignal(name, obj_time, obj_price, is_bullish);
            lastProcessedCHoCH = name;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if color indicates bullish                                  |
//+------------------------------------------------------------------+
bool IsBullishByColor(color clr)
{
   // Green colors = bullish
   if(clr == clrLime || clr == clrGreen || clr == clrSpringGreen || 
      clr == clrLimeGreen || clr == clrDodgerBlue || clr == clrBlue)
      return true;
   
   // Red colors = bearish
   return false;
}

//+------------------------------------------------------------------+
//| Check for Order Block confirmation                                |
//+------------------------------------------------------------------+
bool HasOrderBlockConfirmation(double price, bool is_bullish)
{
   if(!RequireOB) return true;
   
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      double ob_high = MathMax(ObjectGetDouble(0, name, OBJPROP_PRICE1),
                               ObjectGetDouble(0, name, OBJPROP_PRICE2));
      double ob_low = MathMin(ObjectGetDouble(0, name, OBJPROP_PRICE1),
                              ObjectGetDouble(0, name, OBJPROP_PRICE2));
      
      // Check if price is near OB
      if(price >= ob_low && price <= ob_high)
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Process BOS signal                                                |
//+------------------------------------------------------------------+
void ProcessBOSSignal(string name, datetime signal_time, double signal_price, bool is_bullish)
{
   Print("Processing BOS: ", name, " Bullish: ", is_bullish);
   
   // BOS = Trend continuation
   // Bullish BOS in uptrend = BUY opportunity
   // Bearish BOS in downtrend = SELL opportunity
   
   if(is_bullish)
   {
      if(HasOrderBlockConfirmation(signal_price, true))
      {
         OpenBuyTrade("BOS_Bullish");
      }
   }
   else
   {
      if(HasOrderBlockConfirmation(signal_price, false))
      {
         OpenSellTrade("BOS_Bearish");
      }
   }
}

//+------------------------------------------------------------------+
//| Process CHoCH signal                                              |
//+------------------------------------------------------------------+
void ProcessCHoCHSignal(string name, datetime signal_time, double signal_price, bool is_bullish)
{
   Print("Processing CHoCH: ", name, " Bullish: ", is_bullish);
   
   // CHoCH = Trend reversal
   // Bullish CHoCH = potential BUY (trend reversing to bullish)
   // Bearish CHoCH = potential SELL (trend reversing to bearish)
   
   if(is_bullish)
   {
      if(HasOrderBlockConfirmation(signal_price, true))
      {
         OpenBuyTrade("CHoCH_Bullish");
      }
   }
   else
   {
      if(HasOrderBlockConfirmation(signal_price, false))
      {
         OpenSellTrade("CHoCH_Bearish");
      }
   }
}

//+------------------------------------------------------------------+
//| Process pending signals                                           |
//+------------------------------------------------------------------+
void ProcessPendingSignals()
{
   if(ArraySize(pendingSignals) == 0) return;
   
   // Process first pending signal
   SignalInfo signal = pendingSignals[0];
   
   // Check if enough time has passed
   int barsSince = iBarShift(_Symbol, PERIOD_CURRENT, signal.time);
   if(barsSince < MinBarsSinceSignal) return;
   
   // Process signal
   if(signal.type == "BOS" && TradeOnBOS)
   {
      ProcessBOSSignal(signal.name, signal.time, signal.price, signal.is_bullish);
   }
   else if(signal.type == "CHoCH" && TradeOnCHoCH)
   {
      ProcessCHoCHSignal(signal.name, signal.time, signal.price, signal.is_bullish);
   }
   
   // Remove processed signal
   for(int i = 1; i < ArraySize(pendingSignals); i++)
   {
      pendingSignals[i-1] = pendingSignals[i];
   }
   ArrayResize(pendingSignals, ArraySize(pendingSignals) - 1);
}

//+------------------------------------------------------------------+
//| Open Buy Trade                                                    |
//+------------------------------------------------------------------+
void OpenBuyTrade(string comment)
{
   // Check if already have position
   if(PositionSelect(_Symbol))
   {
      Print("Already have position, skipping...");
      return;
   }
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double sl = (StopLoss > 0) ? ask - StopLoss * point : 0;
   double tp = (TakeProfit > 0) ? ask + TakeProfit * point : 0;
   
   if(trade.Buy(LotSize, _Symbol, ask, sl, tp, comment))
   {
      Print(">>> BUY ORDER OPENED: ", comment, " at ", ask);
   }
   else
   {
      Print("Failed to open BUY: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Open Sell Trade                                                   |
//+------------------------------------------------------------------+
void OpenSellTrade(string comment)
{
   // Check if already have position
   if(PositionSelect(_Symbol))
   {
      Print("Already have position, skipping...");
      return;
   }
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double sl = (StopLoss > 0) ? bid + StopLoss * point : 0;
   double tp = (TakeProfit > 0) ? bid - TakeProfit * point : 0;
   
   if(trade.Sell(LotSize, _Symbol, bid, sl, tp, comment))
   {
      Print(">>> SELL ORDER OPENED: ", comment, " at ", bid);
   }
   else
   {
      Print("Failed to open SELL: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| ChartEvent handler for object creation                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CREATE)
   {
      if(ShowDebugInfo)
         Print("Object created: ", sparam);
      
      AnalyzeNewObject(sparam);
   }
}
//+------------------------------------------------------------------+
