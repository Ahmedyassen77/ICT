//+------------------------------------------------------------------+
//|                                             SMC_Drawer_EA_1.mq5  |
//|              Monitors Smart Money Concepts indicator signals      |
//|                            https://github.com/Ahmedyassen77/ICT |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen - SMC Drawer EA 1"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "1.00"
#property description "Monitors SMC indicator objects and trades automatically"
#property description "Add 'Smart Money Concepts.ex5' indicator to chart manually first!"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| TRADING SETTINGS                                                  |
//+------------------------------------------------------------------+
input group "═══════════════ TRADE SETTINGS ═══════════════"
input double   LotSize = 0.1;                          // Lot Size
input int      StopLoss = 500;                         // Stop Loss (points)
input int      TakeProfit = 1000;                      // Take Profit (points)
input int      MagicNumber = 888999;                   // Magic Number
input int      MaxPositions = 1;                       // Max Positions

input group "═══════════════ SIGNAL SETTINGS ═══════════════"
input bool     TradeOnBOS = true;                      // Trade on BOS
input bool     TradeOnCHoCH = true;                    // Trade on CHoCH
input int      SignalExpiry = 3;                       // Signal Expiry (bars)

input group "═══════════════ DISPLAY ═══════════════"
input bool     ShowPanel = true;                       // Show Panel
input bool     DebugMode = false;                      // Debug Mode

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
string lastBOS = "", lastCHoCH = "";
datetime lastTradeTime = 0;
int objCount = 0, totalBOS = 0, totalCHoCH = 0, totalTrades = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════");
   Print("       SMC Drawer EA 1 - Object Monitor");
   Print("═══════════════════════════════════════════════════");
   Print("");
   Print("⚠️  IMPORTANT: Add 'Smart Money Concepts.ex5' indicator manually!");
   Print("📍 Steps:");
   Print("   1. Insert > Indicators > Custom");
   Print("   2. Select 'Smart Money Concepts'");
   Print("   3. Configure your preferred settings");
   Print("   4. Click OK");
   Print("");
   Print("✅ EA will automatically monitor indicator signals");
   Print("");
   
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Check if indicator exists
   bool found = false;
   for(int i = 0; i < ChartIndicatorsTotal(0, 0); i++)
   {
      string name = ChartIndicatorName(0, 0, i);
      if(StringFind(name, "Smart Money") >= 0)
      {
         found = true;
         Print("✓ Found indicator: ", name);
         break;
      }
   }
   
   if(!found)
   {
      Print("");
      Print("⚠️⚠️⚠️ INDICATOR NOT FOUND! ⚠️⚠️⚠️");
      Print("Please add 'Smart Money Concepts.ex5' manually to chart!");
      Print("");
   }
   
   ScanObjects();
   if(ShowPanel) CreatePanel();
   
   Print("═══════════════════════════════════════════════════");
   Print("EA Ready! Monitoring chart objects...");
   Print("═══════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinit                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SMCEA_");
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   MonitorObjects();
   if(ShowPanel) UpdatePanel();
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
   objCount = total;
   
   if(DebugMode)
      Print("📊 Total objects: ", total, " | BOS: ", totalBOS, " | CHoCH: ", totalCHoCH);
}

//+------------------------------------------------------------------+
//| Monitor objects                                                   |
//+------------------------------------------------------------------+
void MonitorObjects()
{
   static int lastCheck = 0;
   int current = ObjectsTotal(0, 0, -1);
   
   if(current != objCount)
   {
      if(DebugMode) Print("🔍 Objects changed: ", objCount, " -> ", current);
      
      for(int i = 0; i < current; i++)
      {
         string name = ObjectName(0, i, 0, -1);
         if(name != lastBOS && name != lastCHoCH)
            ProcessObject(name);
      }
      objCount = current;
   }
}

//+------------------------------------------------------------------+
//| Process object                                                    |
//+------------------------------------------------------------------+
void ProcessObject(string name)
{
   ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
   if(type != OBJ_TEXT && type != OBJ_LABEL) return;
   
   string text = ObjectGetString(0, name, OBJPROP_TEXT);
   StringToUpper(text);
   
   // Check if it's BOS or CHoCH
   bool isBOS = (StringFind(text, "BOS") >= 0);
   bool isCHoCH = (StringFind(text, "CHOCH") >= 0);
   
   if(!isBOS && !isCHoCH) return;
   
   datetime t = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
   color c = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
   
   // Check signal age
   int bars = iBarShift(_Symbol, PERIOD_CURRENT, t);
   if(bars > SignalExpiry)
   {
      if(DebugMode) Print("⏳ Signal expired: ", name, " (", bars, " bars old)");
      return;
   }
   
   // Determine direction
   bool bull = IsBull(c);
   
   if(isBOS && TradeOnBOS && name != lastBOS)
   {
      Print("🔵 BOS Signal: ", bull ? "BULLISH" : "BEARISH", " | ", name);
      if(CanTrade()) 
      {
         OpenTrade(bull ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, "BOS");
      }
      lastBOS = name;
      totalBOS++;
   }
   else if(isCHoCH && TradeOnCHoCH && name != lastCHoCH)
   {
      Print("🔴 CHoCH Signal: ", bull ? "BULLISH" : "BEARISH", " | ", name);
      if(CanTrade())
      {
         OpenTrade(bull ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, "CHoCH");
      }
      lastCHoCH = name;
      totalCHoCH++;
   }
}

//+------------------------------------------------------------------+
//| Is bullish color                                                  |
//+------------------------------------------------------------------+
bool IsBull(color c)
{
   // Get RGB components
   int r = c & 0xFF;
   int g = (c >> 8) & 0xFF;
   int b = (c >> 16) & 0xFF;
   
   // Bullish colors (greens, blues, lighter colors)
   if(g > r + 30 && g > b + 30) return true; // Green dominant
   if(b > r + 30 && b > g - 30) return true; // Blue dominant
   if(c == clrLime || c == clrGreen || c == clrSpringGreen || 
      c == clrAqua || c == clrDodgerBlue || c == clrCyan) return true;
   
   // Bearish colors (reds, magentas, darker colors)
   if(r > g + 30 && r > b + 30) return false; // Red dominant
   if(c == clrRed || c == clrCrimson || c == clrOrangeRed || 
      c == clrMagenta || c == clrPink) return false;
   
   // Default: check if it's a light color (bullish) or dark (bearish)
   int brightness = (r + g + b) / 3;
   return (brightness > 100);
}

//+------------------------------------------------------------------+
//| Can trade                                                         |
//+------------------------------------------------------------------+
bool CanTrade()
{
   int pos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         pos++;
   }
   
   if(pos >= MaxPositions)
   {
      if(DebugMode) Print("⛔ Max positions reached: ", pos);
      return false;
   }
   
   if(TimeCurrent() - lastTradeTime < 60)
   {
      if(DebugMode) Print("⏰ Wait for next trade: ", (60 - (TimeCurrent() - lastTradeTime)), "s");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Open trade                                                        |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, string cmt)
{
   double price, sl, tp, pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(type == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = StopLoss > 0 ? price - StopLoss * pt : 0;
      tp = TakeProfit > 0 ? price + TakeProfit * pt : 0;
      
      if(trade.Buy(LotSize, _Symbol, price, sl, tp, cmt))
      {
         Print("✅ BUY order opened: ", trade.ResultOrder());
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
      else
      {
         Print("❌ BUY failed: ", trade.ResultRetcodeDescription());
      }
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = StopLoss > 0 ? price + StopLoss * pt : 0;
      tp = TakeProfit > 0 ? price - TakeProfit * pt : 0;
      
      if(trade.Sell(LotSize, _Symbol, price, sl, tp, cmt))
      {
         Print("✅ SELL order opened: ", trade.ResultOrder());
         lastTradeTime = TimeCurrent();
         totalTrades++;
      }
      else
      {
         Print("❌ SELL failed: ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Panel                                                             |
//+------------------------------------------------------------------+
void CreatePanel()
{
   int x=10, y=30;
   ObjectCreate(0,"SMCEA_BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_XDISTANCE,x-5);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_YDISTANCE,y-5);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_XSIZE,220);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_YSIZE,140);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_BGCOLOR,C'20,25,35');
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_COLOR,clrDodgerBlue);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   
   CreateLbl("SMCEA_T","SMC Drawer EA 1",x,y,clrDodgerBlue,10);
   CreateLbl("SMCEA_I","Indicator: ...",x,y+20,clrWhite,9);
   CreateLbl("SMCEA_O","Objects: 0",x,y+40,clrGray,9);
   CreateLbl("SMCEA_B","BOS: 0",x,y+60,clrYellow,9);
   CreateLbl("SMCEA_C","CHoCH: 0",x,y+80,clrMagenta,9);
   CreateLbl("SMCEA_R","Trades: 0",x,y+100,clrLime,9);
   CreateLbl("SMCEA_P","Positions: 0",x,y+120,clrWhite,9);
}

void CreateLbl(string n,string t,int x,int y,color c,int s)
{
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,t);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,s);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
}

void UpdatePanel()
{
   static datetime last=0;
   if(TimeCurrent()-last<1) return;
   last=TimeCurrent();
   
   // Check for indicator
   bool found=false;
   string indName = "";
   for(int i=0;i<ChartIndicatorsTotal(0,0);i++)
   {
      string name = ChartIndicatorName(0,0,i);
      if(StringFind(name,"Smart Money")>=0)
      {
         found=true;
         indName = name;
         break;
      }
   }
   
   ObjectSetString(0,"SMCEA_I",OBJPROP_TEXT,"Indicator: "+(found?"✓ Active":"⚠ Not Found"));
   ObjectSetInteger(0,"SMCEA_I",OBJPROP_COLOR,found?clrLime:clrOrange);
   
   ObjectSetString(0,"SMCEA_O",OBJPROP_TEXT,"Objects: "+IntegerToString(objCount));
   ObjectSetString(0,"SMCEA_B",OBJPROP_TEXT,"BOS: "+IntegerToString(totalBOS));
   ObjectSetString(0,"SMCEA_C",OBJPROP_TEXT,"CHoCH: "+IntegerToString(totalCHoCH));
   ObjectSetString(0,"SMCEA_R",OBJPROP_TEXT,"Trades: "+IntegerToString(totalTrades));
   
   // Count open positions
   int pos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         pos++;
   ObjectSetString(0,"SMCEA_P",OBJPROP_TEXT,"Positions: "+IntegerToString(pos));
}

void OnChartEvent(const int id,const long&l,const double&d,const string&s)
{
   if(id==CHARTEVENT_OBJECT_CREATE)
   {
      if(DebugMode) Print("📌 New object created: ", s);
      ProcessObject(s);
   }
}
//+------------------------------------------------------------------+
