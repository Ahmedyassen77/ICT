//+------------------------------------------------------------------+
//|                                               SMC_Drawer_EA.mq5  |
//|        Uses ChartApplyTemplate to load indicator with settings   |
//|                            https://github.com/Ahmedyassen77/ICT |
//+------------------------------------------------------------------+
#property copyright "Ahmed Yassen - SMC Drawer EA"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "1.00"
#property description "Automatically places and controls SMC Indicator"
#property description "Change any parameter and click OK - indicator will reload!"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INDICATOR SETTINGS - Will be applied to indicator via Template   |
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
string templateFile = "SMC_EA_AutoLoad.tpl";

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════");
   Print("       SMC Drawer EA v1.0 - Auto Indicator Load");
   Print("═══════════════════════════════════════════════════");
   
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Create and apply template with indicator
   if(CreateAndApplyTemplate())
   {
      Print("✓ Indicator loaded successfully via Template!");
   }
   else
   {
      Print("✗ Template method failed. Add indicator manually.");
   }
   
   ScanObjects();
   if(ShowPanel) CreatePanel();
   
   Print("═══════════════════════════════════════════════════");
   Print("EA Ready! Change any setting and click OK to reload.");
   Print("═══════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Create template file with indicator and settings                  |
//+------------------------------------------------------------------+
bool CreateAndApplyTemplate()
{
   string terminalPath = TerminalInfoString(TERMINAL_DATA_PATH);
   string tplPath = terminalPath + "\\MQL5\\Files\\" + templateFile;
   
   // Build template content (EXACT MT5 format)
   string tpl = "";
   
   tpl += "<chart>\r\n";
   tpl += "id=133604233802703218\r\n";
   tpl += "symbol=" + _Symbol + "\r\n";
   tpl += "period_type=0\r\n";
   tpl += "period_size=" + IntegerToString(PeriodSeconds()/60) + "\r\n";
   tpl += "digits=" + IntegerToString(_Digits) + "\r\n";
   tpl += "tick_size=0.000000\r\n";
   tpl += "position_time=0\r\n";
   tpl += "scale_fix=0\r\n";
   tpl += "scale_fixed_min=0.000000\r\n";
   tpl += "scale_fixed_max=0.000000\r\n";
   tpl += "scale_fix11=0\r\n";
   tpl += "scale_bar=0\r\n";
   tpl += "scale_bar_val=1.000000\r\n";
   tpl += "scale=8\r\n";
   tpl += "mode=1\r\n";
   tpl += "fore=0\r\n";
   tpl += "grid=0\r\n";
   tpl += "volume=0\r\n";
   tpl += "scroll=1\r\n";
   tpl += "shift=1\r\n";
   tpl += "shift_size=20.856354\r\n";
   tpl += "fixed_pos=0.000000\r\n";
   tpl += "ticker=1\r\n";
   tpl += "ohlc=1\r\n";
   tpl += "ask_line=1\r\n";
   tpl += "days=0\r\n";
   tpl += "descriptions=0\r\n";
   tpl += "tradelines=1\r\n";
   tpl += "tradehistory=1\r\n";
   tpl += "window_left=0\r\n";
   tpl += "window_top=0\r\n";
   tpl += "window_right=0\r\n";
   tpl += "window_bottom=0\r\n";
   tpl += "window_type=3\r\n";
   tpl += "floating=0\r\n";
   tpl += "floating_left=0\r\n";
   tpl += "floating_top=0\r\n";
   tpl += "floating_right=0\r\n";
   tpl += "floating_bottom=0\r\n";
   tpl += "floating_type=1\r\n";
   tpl += "floating_toolbar=1\r\n";
   tpl += "floating_tbstate=\r\n";
   tpl += "background_color=0\r\n";
   tpl += "foreground_color=16777215\r\n";
   tpl += "barup_color=65280\r\n";
   tpl += "bardown_color=255\r\n";
   tpl += "bullcandle_color=0\r\n";
   tpl += "bearcandle_color=16777215\r\n";
   tpl += "chartline_color=65280\r\n";
   tpl += "volume_color=32768\r\n";
   tpl += "bid_color=0\r\n";
   tpl += "ask_color=255\r\n";
   tpl += "lastdeal_color=0\r\n";
   tpl += "stops_color=255\r\n";
   tpl += "windows_total=1\r\n";
   
   tpl += "\r\n";
   tpl += "<window>\r\n";
   tpl += "height=100.000000\r\n";
   tpl += "objects=0\r\n";
   
   tpl += "\r\n";
   tpl += "<indicator>\r\n";
   tpl += "name=Custom Indicator\r\n";
   tpl += "path=Indicators\\Smart Money Concepts.ex5\r\n";
   tpl += "apply=0\r\n";
   tpl += "show_data=1\r\n";
   tpl += "inputs=35\r\n";
   
   // ALL parameters in exact order with type specification
   tpl += "How many candles to calculate in history (0=All)=" + IntegerToString(Ind_Candles) + "\r\n";
   tpl += "Mode=" + Ind_Mode + "\r\n";
   tpl += "Style=" + Ind_Style + "\r\n";
   tpl += "Color Candles=" + (Ind_ColorCandles ? "1" : "0") + "\r\n";
   tpl += "Show Internal Structure=" + (Ind_ShowInternal ? "1" : "0") + "\r\n";
   tpl += "Bullish Structure=" + Ind_IntBullStructure + "\r\n";
   tpl += "Bullish Color=" + Ind_IntBullColor + "\r\n";
   tpl += "Bearish Structure=" + Ind_IntBearStructure + "\r\n";
   tpl += "Bearish Color=" + Ind_IntBearColor + "\r\n";
   tpl += "Confluence Filter=" + (Ind_Confluence ? "1" : "0") + "\r\n";
   tpl += "Show Swing Structure=" + (Ind_ShowSwing ? "1" : "0") + "\r\n";
   tpl += "Bullish Structure=" + Ind_SwingBullStructure + "\r\n";
   tpl += "Bullish Color=" + Ind_SwingBullColor + "\r\n";
   tpl += "Bearish Structure=" + Ind_SwingBearStructure + "\r\n";
   tpl += "Bearish Color=" + Ind_SwingBearColor + "\r\n";
   tpl += "Show Swings Points=" + (Ind_ShowSwingPoints ? "1" : "0") + "\r\n";
   tpl += "Length=" + IntegerToString(Ind_Length) + "\r\n";
   tpl += "Show Strong/Weak High/Low=" + (Ind_StrongWeak ? "1" : "0") + "\r\n";
   tpl += "Show Internal Order Blocks=" + (Ind_ShowInternalOB ? "1" : "0") + "\r\n";
   tpl += "Internal Order Blocks=" + IntegerToString(Ind_InternalOBCount) + "\r\n";
   tpl += "Swing Order Blocks=" + (Ind_ShowSwingOB ? "1" : "0") + "\r\n";
   tpl += "Swing Order Blocks=" + IntegerToString(Ind_SwingOBCount) + "\r\n";
   tpl += "Order Block Filter=" + Ind_OBFilter + "\r\n";
   tpl += "Internal Bullish OB=" + Ind_IntBullOB + "\r\n";
   tpl += "Internal Bearish OB=" + Ind_IntBearOB + "\r\n";
   tpl += "Bullish OB=" + Ind_BullOB + "\r\n";
   tpl += "Bearish OB=" + Ind_BearOB + "\r\n";
   tpl += "Equal High/Low=" + (Ind_EqualHL ? "1" : "0") + "\r\n";
   tpl += "Bars Confirmation=" + IntegerToString(Ind_BarsConfirm) + "\r\n";
   tpl += "Threshold=" + DoubleToString(Ind_Threshold, 1) + "\r\n";
   tpl += "Fair Value Gaps=" + (Ind_ShowFVG ? "1" : "0") + "\r\n";
   tpl += "Auto Threshold=" + (Ind_AutoThreshold ? "1" : "0") + "\r\n";
   tpl += "Timeframe=" + Ind_FVGTimeframe + "\r\n";
   tpl += "Bullish FVG=" + Ind_BullFVG + "\r\n";
   tpl += "Bearish FVG=" + Ind_BearFVG + "\r\n";
   tpl += "Extend FVG=" + IntegerToString(Ind_ExtendFVG) + "\r\n";
   tpl += "Show Daily=" + (Ind_ShowDaily ? "1" : "0") + "\r\n";
   tpl += "Style Daily=" + Ind_DailyStyle + "\r\n";
   tpl += "Color Daily=" + Ind_DailyColor + "\r\n";
   tpl += "Show Weekly=" + (Ind_ShowWeekly ? "1" : "0") + "\r\n";
   tpl += "Style Weekly=" + Ind_WeeklyStyle + "\r\n";
   tpl += "Color Weekly=" + Ind_WeeklyColor + "\r\n";
   tpl += "Show Monthly=" + (Ind_ShowMonthly ? "1" : "0") + "\r\n";
   tpl += "Style Monthly=" + Ind_MonthlyStyle + "\r\n";
   tpl += "Color Monthly=" + Ind_MonthlyColor + "\r\n";
   tpl += "Premium/Discount Zones=" + (Ind_ShowPDZones ? "1" : "0") + "\r\n";
   tpl += "Premium Zone=" + Ind_PremiumColor + "\r\n";
   tpl += "Equilibrium Zone=" + Ind_EquilColor + "\r\n";
   tpl += "Discount Zone=" + Ind_DiscountColor + "\r\n";
   
   tpl += "</indicator>\r\n";
   tpl += "</window>\r\n";
   tpl += "</chart>\r\n";
   
   // Save template as UTF-16 LE (MT5 native format)
   int h = FileOpen(templateFile, FILE_WRITE|FILE_TXT|FILE_UNICODE);
   if(h == INVALID_HANDLE)
   {
      Print("❌ Cannot create template. Error: ", GetLastError());
      return false;
   }
   
   FileWriteString(h, tpl);
   FileClose(h);
   
   Print("✓ Template saved: ", tplPath);
   Sleep(300);
   
   // Apply template
   if(ChartApplyTemplate(0, templateFile))
   {
      Print("✓✓✓ INDICATOR LOADED! ✓✓✓");
      ChartRedraw(0);
      return true;
   }
   else
   {
      int err = GetLastError();
      Print("❌ Template apply failed. Error: ", err);
      Print("ℹ️  Please apply template manually: Files/", templateFile);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Deinit                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SMCEA_");
   
   // Keep template for manual use
   // FileDelete(templateFile);
   Print("💾 Template saved for reuse: MQL5\\Files\\", templateFile);
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
   
   CreateLbl("SMCEA_T","SMC Drawer EA",x,y,clrDodgerBlue,10);
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
