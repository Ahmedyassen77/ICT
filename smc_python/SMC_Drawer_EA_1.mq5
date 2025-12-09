//+------------------------------------------------------------------+
//|                                             SMC_Drawer_EA_1.mq5  |
//|              Automatically loads SMC indicator on chart           |
//|                            https://github.com/Ahmedyassen77/ICT |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen - SMC Drawer EA 1"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "1.00"
#property description "Automatically places and controls SMC Indicator"
#property description "Uses iCustom() to load indicator with full parameter control"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INDICATOR SETTINGS - Will be applied to indicator                |
//+------------------------------------------------------------------+
input group "═══════════════ INDICATOR: Smart Money Concepts ═══════════════"
input int      Ind_Candles = 2000;                     // How many candles (0=All)
input string   Ind_Mode = "Historical";                // Mode (Historical/Present)
input string   Ind_Style = "Colored";                  // Style (Colored/Monochrome)
input bool     Ind_ColorCandles = false;               // Color Candles

input group "═══════════════ INTERNAL STRUCTURE ═══════════════"
input bool     Ind_ShowInternal = true;                // Show Internal Structure
input string   Ind_IntBullStructure = "All";           // Bullish Structure (All/BOS/CHoCH)
input string   Ind_IntBullColor = "8,153,129";         // Bullish Color (R,G,B)
input string   Ind_IntBearStructure = "All";           // Bearish Structure (All/BOS/CHoCH)
input string   Ind_IntBearColor = "242,54,69";         // Bearish Color (R,G,B)
input bool     Ind_Confluence = false;                 // Confluence Filter

input group "═══════════════ SWING STRUCTURE ═══════════════"
input bool     Ind_ShowSwing = true;                   // Show Swing Structure
input string   Ind_SwingBullStructure = "All";         // Bullish Structure
input string   Ind_SwingBullColor = "8,153,129";       // Bullish Color (R,G,B)
input string   Ind_SwingBearStructure = "All";         // Bearish Structure
input string   Ind_SwingBearColor = "242,54,69";       // Bearish Color (R,G,B)
input bool     Ind_ShowSwingPoints = false;            // Show Swings Points
input int      Ind_Length = 50;                        // Length
input bool     Ind_StrongWeak = true;                  // Show Strong/Weak High/Low

input group "═══════════════ ORDER BLOCKS ═══════════════"
input bool     Ind_ShowInternalOB = true;              // Show Internal Order Blocks
input int      Ind_InternalOBCount = 5;                // Internal Order Blocks Count
input bool     Ind_ShowSwingOB = false;                // Swing Order Blocks
input int      Ind_SwingOBCount = 5;                   // Swing Order Blocks Count
input string   Ind_OBFilter = "Atr";                   // Order Block Filter (Atr/Avg)
input string   Ind_IntBullOB = "91,156,246";           // Internal Bullish OB (R,G,B)
input string   Ind_IntBearOB = "247,124,128";          // Internal Bearish OB (R,G,B)
input string   Ind_BullOB = "24,72,204";               // Bullish OB (R,G,B)
input string   Ind_BearOB = "178,40,51";               // Bearish OB (R,G,B)

input group "═══════════════ EQH/EQL ═══════════════"
input bool     Ind_EqualHL = true;                     // Equal High/Low
input int      Ind_BarsConfirm = 3;                    // Bars Confirmation
input double   Ind_Threshold = 0.1;                    // Threshold

input group "═══════════════ FAIR VALUE GAPS ═══════════════"
input bool     Ind_ShowFVG = false;                    // Fair Value Gaps
input bool     Ind_AutoThreshold = true;               // Auto Threshold
input string   Ind_FVGTimeframe = "current";           // Timeframe
input string   Ind_BullFVG = "0,255,104";              // Bullish FVG (R,G,B)
input string   Ind_BearFVG = "255,0,8";                // Bearish FVG (R,G,B)
input int      Ind_ExtendFVG = 1;                      // Extend FVG

input group "═══════════════ HIGHS & LOWS MTF ═══════════════"
input bool     Ind_ShowDaily = false;                  // Show Daily
input string   Ind_DailyStyle = "Solid";               // Style Daily
input string   Ind_DailyColor = "33,87,243";           // Color Daily (R,G,B)
input bool     Ind_ShowWeekly = false;                 // Show Weekly
input string   Ind_WeeklyStyle = "Solid";              // Style Weekly
input string   Ind_WeeklyColor = "33,87,243";          // Color Weekly (R,G,B)
input bool     Ind_ShowMonthly = false;                // Show Monthly
input string   Ind_MonthlyStyle = "Solid";             // Style Monthly
input string   Ind_MonthlyColor = "33,87,243";         // Color Monthly (R,G,B)

input group "═══════════════ PREMIUM & DISCOUNT ═══════════════"
input bool     Ind_ShowPDZones = false;                // Premium/Discount Zones
input string   Ind_PremiumColor = "242,54,69";         // Premium Zone (R,G,B)
input string   Ind_EquilColor = "178,181,190";         // Equilibrium Zone (R,G,B)
input string   Ind_DiscountColor = "8,153,129";        // Discount Zone (R,G,B)

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
int indicatorHandle = INVALID_HANDLE;
bool indicatorLoaded = false;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════");
   Print("       SMC Drawer EA 1 - Direct Indicator Load");
   Print("═══════════════════════════════════════════════════");
   
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Remove old indicator if exists
   RemoveOldIndicator();
   
   // Load indicator with iCustom
   if(LoadIndicatorDirect())
   {
      Print("✓✓✓ Indicator loaded successfully! ✓✓✓");
      indicatorLoaded = true;
   }
   else
   {
      Print("⚠️ Could not load indicator automatically.");
      Print("ℹ️  Please add 'Smart Money Concepts.ex5' manually.");
      Print("ℹ️  EA will still monitor and trade from it!");
   }
   
   ScanObjects();
   if(ShowPanel) CreatePanel();
   
   Print("═══════════════════════════════════════════════════");
   Print("EA Ready! Monitoring chart objects...");
   Print("═══════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Remove old indicator from chart                                   |
//+------------------------------------------------------------------+
void RemoveOldIndicator()
{
   int total = ChartIndicatorsTotal(0, 0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ChartIndicatorName(0, 0, i);
      if(StringFind(name, "Smart Money") >= 0)
      {
         ChartIndicatorDelete(0, 0, name);
         Print("🗑️ Removed old indicator: ", name);
      }
   }
}

//+------------------------------------------------------------------+
//| Load indicator directly with iCustom                              |
//+------------------------------------------------------------------+
bool LoadIndicatorDirect()
{
   // Try to load indicator using iCustom
   MqlParam params[];
   ArrayResize(params, 35);
   
   int idx = 0;
   params[idx].type = TYPE_INT; params[idx++].integer_value = Ind_Candles;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_Mode;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_Style;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_ColorCandles;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_ShowInternal;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_IntBullStructure;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_IntBullColor;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_IntBearStructure;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_IntBearColor;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_Confluence;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_ShowSwing;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_SwingBullStructure;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_SwingBullColor;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_SwingBearStructure;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_SwingBearColor;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_ShowSwingPoints;
   params[idx].type = TYPE_INT; params[idx++].integer_value = Ind_Length;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_StrongWeak;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_ShowInternalOB;
   params[idx].type = TYPE_INT; params[idx++].integer_value = Ind_InternalOBCount;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_ShowSwingOB;
   params[idx].type = TYPE_INT; params[idx++].integer_value = Ind_SwingOBCount;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_OBFilter;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_IntBullOB;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_IntBearOB;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_BullOB;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_BearOB;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_EqualHL;
   params[idx].type = TYPE_INT; params[idx++].integer_value = Ind_BarsConfirm;
   params[idx].type = TYPE_DOUBLE; params[idx++].double_value = Ind_Threshold;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_ShowFVG;
   params[idx].type = TYPE_BOOL; params[idx++].integer_value = Ind_AutoThreshold;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_FVGTimeframe;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_BullFVG;
   params[idx].type = TYPE_STRING; params[idx++].string_value = Ind_BearFVG;
   params[idx].type = TYPE_INT; params[idx++].integer_value = Ind_ExtendFVG;
   
   indicatorHandle = iCustom(_Symbol, PERIOD_CURRENT, "Indicators\\Smart Money Concepts.ex5", params);
   
   if(indicatorHandle != INVALID_HANDLE)
   {
      Print("📊 Indicator handle created: ", indicatorHandle);
      ChartRedraw(0);
      return true;
   }
   else
   {
      int err = GetLastError();
      Print("❌ iCustom failed. Error: ", err);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Deinit                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SMCEA_");
   
   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);
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
}

//+------------------------------------------------------------------+
//| Monitor objects                                                   |
//+------------------------------------------------------------------+
void MonitorObjects()
{
   int current = ObjectsTotal(0, 0, -1);
   if(current != objCount)
   {
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
   
   datetime t = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
   color c = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
   
   int bars = iBarShift(_Symbol, PERIOD_CURRENT, t);
   if(bars > SignalExpiry) return;
   
   bool bull = IsBull(c);
   
   if(StringFind(text, "BOS") >= 0 && TradeOnBOS && name != lastBOS)
   {
      if(DebugMode) Print("BOS ", bull?"BULL":"BEAR");
      if(CanTrade()) OpenTrade(bull ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, "BOS");
      lastBOS = name;
      totalBOS++;
   }
   else if(StringFind(text, "CHOCH") >= 0 && TradeOnCHoCH && name != lastCHoCH)
   {
      if(DebugMode) Print("CHoCH ", bull?"BULL":"BEAR");
      if(CanTrade()) OpenTrade(bull ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, "CHoCH");
      lastCHoCH = name;
      totalCHoCH++;
   }
}

//+------------------------------------------------------------------+
//| Is bullish color                                                  |
//+------------------------------------------------------------------+
bool IsBull(color c)
{
   // Parse EA colors
   color bullInt = RGBStringToColor(Ind_IntBullColor);
   color bullSwing = RGBStringToColor(Ind_SwingBullColor);
   color bullOB = RGBStringToColor(Ind_BullOB);
   color bullFVG = RGBStringToColor(Ind_BullFVG);
   color discount = RGBStringToColor(Ind_DiscountColor);
   
   if(c == bullInt || c == bullSwing || c == bullOB || c == bullFVG || c == discount)
      return true;
   
   // Common green colors
   if(c == clrLime || c == clrGreen || c == clrSpringGreen || c == clrDodgerBlue)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Convert RGB string to color                                       |
//+------------------------------------------------------------------+
color RGBStringToColor(string rgb)
{
   string parts[];
   int count = StringSplit(rgb, ',', parts);
   if(count >= 3)
   {
      int r = (int)StringToInteger(parts[0]);
      int g = (int)StringToInteger(parts[1]);
      int b = (int)StringToInteger(parts[2]);
      return (color)((b << 16) | (g << 8) | r);
   }
   return clrWhite;
}

//+------------------------------------------------------------------+
//| Can trade                                                         |
//+------------------------------------------------------------------+
bool CanTrade()
{
   int pos = 0;
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         pos++;
   if(pos >= MaxPositions) return false;
   if(TimeCurrent() - lastTradeTime < 60) return false;
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
      { lastTradeTime = TimeCurrent(); totalTrades++; }
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = StopLoss > 0 ? price + StopLoss * pt : 0;
      tp = TakeProfit > 0 ? price - TakeProfit * pt : 0;
      if(trade.Sell(LotSize, _Symbol, price, sl, tp, cmt))
      { lastTradeTime = TimeCurrent(); totalTrades++; }
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
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_XSIZE,200);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_YSIZE,120);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_BGCOLOR,C'20,25,35');
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_COLOR,clrDodgerBlue);
   ObjectSetInteger(0,"SMCEA_BG",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   
   CreateLbl("SMCEA_T","SMC Drawer EA 1",x,y,clrDodgerBlue,10);
   CreateLbl("SMCEA_I","Indicator: ...",x,y+20,clrWhite,9);
   CreateLbl("SMCEA_B","BOS: 0",x,y+40,clrYellow,9);
   CreateLbl("SMCEA_C","CHoCH: 0",x,y+60,clrMagenta,9);
   CreateLbl("SMCEA_R","Trades: 0",x,y+80,clrLime,9);
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
   
   bool found=false;
   for(int i=0;i<ChartIndicatorsTotal(0,0);i++)
      if(StringFind(ChartIndicatorName(0,0,i),"Smart Money")>=0){found=true;break;}
   
   ObjectSetString(0,"SMCEA_I",OBJPROP_TEXT,"Indicator: "+(found?"Active":"Not Found"));
   ObjectSetInteger(0,"SMCEA_I",OBJPROP_COLOR,found?clrLime:clrOrange);
   ObjectSetString(0,"SMCEA_B",OBJPROP_TEXT,"BOS: "+IntegerToString(totalBOS));
   ObjectSetString(0,"SMCEA_C",OBJPROP_TEXT,"CHoCH: "+IntegerToString(totalCHoCH));
   ObjectSetString(0,"SMCEA_R",OBJPROP_TEXT,"Trades: "+IntegerToString(totalTrades));
}

void OnChartEvent(const int id,const long&l,const double&d,const string&s)
{if(id==CHARTEVENT_OBJECT_CREATE)ProcessObject(s);}
//+------------------------------------------------------------------+
