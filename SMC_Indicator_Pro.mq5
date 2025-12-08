//+------------------------------------------------------------------+
//|                                            SMC_Indicator_Pro.mq5 |
//|                       Smart Money Concepts - Professional Edition |
//|                      BOS, CHoCH, Order Blocks, FVG, Swing Points  |
//+------------------------------------------------------------------+
#property copyright "SMC Indicator Pro"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "══════════ Swing Settings ══════════"
input int      InpSwingLength = 5;              // Swing Length (bars)
input int      InpLookback = 500;               // Lookback Bars

input group "══════════ Display Settings ══════════"
input bool     InpShowSwings = true;            // Show Swing Points
input bool     InpShowBOS = true;               // Show BOS (Break of Structure)
input bool     InpShowCHoCH = true;             // Show CHoCH (Change of Character)
input bool     InpShowOrderBlocks = true;       // Show Order Blocks
input bool     InpShowFVG = true;               // Show Fair Value Gaps
input bool     InpShowEQHL = true;              // Show Equal Highs/Lows

input group "══════════ Swing Colors ══════════"
input color    InpColorHH = clrDodgerBlue;      // Higher High Color
input color    InpColorHL = clrLime;            // Higher Low Color
input color    InpColorLH = clrOrange;          // Lower High Color
input color    InpColorLL = clrRed;             // Lower Low Color

input group "══════════ Structure Colors ══════════"
input color    InpColorBOSBull = clrAqua;       // BOS Bullish Color
input color    InpColorBOSBear = clrAqua;       // BOS Bearish Color
input color    InpColorCHoCHBull = clrLime;     // CHoCH Bullish Color
input color    InpColorCHoCHBear = clrRed;      // CHoCH Bearish Color

input group "══════════ Order Block Colors ══════════"
input color    InpColorOBBull = C'0,100,255';   // Bullish OB Color (Blue)
input color    InpColorOBBear = C'255,50,50';   // Bearish OB Color (Red)
input int      InpOBTransparency = 80;          // OB Transparency (0-100)

input group "══════════ FVG Colors ══════════"
input color    InpColorFVGBull = C'0,150,0';    // Bullish FVG Color
input color    InpColorFVGBear = C'150,0,0';    // Bearish FVG Color

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double   price;
   datetime time;
   int      bar;
   bool     isHigh;
   string   label;  // HH, HL, LH, LL
   bool     isBroken;
};

struct OrderBlock
{
   double   top;
   double   bottom;
   datetime startTime;
   datetime endTime;
   bool     isBullish;
   bool     isValid;
};

struct FairValueGap
{
   double   top;
   double   bottom;
   datetime time;
   bool     isBullish;
   bool     isFilled;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
SwingPoint g_swings[];
OrderBlock g_orderBlocks[];
FairValueGap g_fvgs[];

int g_objCount = 0;
datetime g_lastBar = 0;

// Trend tracking
bool g_isBullish = false;
bool g_isBearish = false;
double g_lastSwingHigh = 0;
double g_lastSwingLow = 0;
datetime g_lastSwingHighTime = 0;
datetime g_lastSwingLowTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════");
   Print("   🎯 SMC INDICATOR PRO - INITIALIZED");
   Print("═══════════════════════════════════════════");
   
   // Clean up
   ObjectsDeleteAll(0, "SMC_");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SMC_");
   Print("SMC Indicator removed");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < InpLookback) return(0);
   
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBar != g_lastBar)
   {
      g_lastBar = currentBar;
      AnalyzeMarket();
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Main Analysis Function                                            |
//+------------------------------------------------------------------+
void AnalyzeMarket()
{
   // Clear old objects
   ObjectsDeleteAll(0, "SMC_");
   g_objCount = 0;
   
   // Reset arrays
   ArrayResize(g_swings, 0);
   ArrayResize(g_orderBlocks, 0);
   ArrayResize(g_fvgs, 0);
   
   // Reset tracking
   g_lastSwingHigh = 0;
   g_lastSwingLow = 0;
   g_isBullish = false;
   g_isBearish = false;
   
   // Step 1: Find Swing Points
   FindSwingPoints();
   
   // Step 2: Classify Swings (HH, HL, LH, LL) and detect BOS/CHoCH
   ClassifySwings();
   
   // Step 3: Find Order Blocks
   if(InpShowOrderBlocks)
      FindOrderBlocks();
   
   // Step 4: Find Fair Value Gaps
   if(InpShowFVG)
      FindFairValueGaps();
   
   // Step 5: Draw everything
   DrawAll();
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Find Swing Highs and Lows                                         |
//+------------------------------------------------------------------+
void FindSwingPoints()
{
   int limit = MathMin(InpLookback, iBars(_Symbol, PERIOD_CURRENT) - InpSwingLength - 1);
   
   for(int i = InpSwingLength; i < limit; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      datetime time = iTime(_Symbol, PERIOD_CURRENT, i);
      
      // Check Swing High
      bool isSwingHigh = true;
      for(int j = 1; j <= InpSwingLength; j++)
      {
         if(iHigh(_Symbol, PERIOD_CURRENT, i-j) >= high || 
            iHigh(_Symbol, PERIOD_CURRENT, i+j) >= high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh)
      {
         SwingPoint sp;
         sp.price = high;
         sp.time = time;
         sp.bar = i;
         sp.isHigh = true;
         sp.label = "SH";
         sp.isBroken = false;
         
         int size = ArraySize(g_swings);
         ArrayResize(g_swings, size + 1);
         g_swings[size] = sp;
      }
      
      // Check Swing Low
      bool isSwingLow = true;
      for(int j = 1; j <= InpSwingLength; j++)
      {
         if(iLow(_Symbol, PERIOD_CURRENT, i-j) <= low || 
            iLow(_Symbol, PERIOD_CURRENT, i+j) <= low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow)
      {
         SwingPoint sp;
         sp.price = low;
         sp.time = time;
         sp.bar = i;
         sp.isHigh = false;
         sp.label = "SL";
         sp.isBroken = false;
         
         int size = ArraySize(g_swings);
         ArrayResize(g_swings, size + 1);
         g_swings[size] = sp;
      }
   }
   
   // Sort by bar index descending (oldest first)
   SortSwings();
}

//+------------------------------------------------------------------+
//| Sort Swings (oldest first)                                        |
//+------------------------------------------------------------------+
void SortSwings()
{
   int total = ArraySize(g_swings);
   for(int i = 0; i < total - 1; i++)
   {
      for(int j = i + 1; j < total; j++)
      {
         if(g_swings[j].bar > g_swings[i].bar)
         {
            SwingPoint temp = g_swings[i];
            g_swings[i] = g_swings[j];
            g_swings[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Classify Swings and Detect BOS/CHoCH                              |
//+------------------------------------------------------------------+
void ClassifySwings()
{
   int total = ArraySize(g_swings);
   if(total < 2) return;
   
   double prevHigh = 0, prevLow = 0;
   datetime prevHighTime = 0, prevLowTime = 0;
   int prevHighBar = 0, prevLowBar = 0;
   
   // Track the swing that preceded the last BOS
   double swingBeforeBullBOS = 0;
   datetime swingBeforeBullBOSTime = 0;
   double swingBeforeBearBOS = 0;
   datetime swingBeforeBearBOSTime = 0;
   
   for(int i = 0; i < total; i++)
   {
      if(g_swings[i].isHigh)
      {
         // Processing a HIGH
         if(prevHigh > 0)
         {
            if(g_swings[i].price > prevHigh)
            {
               // Higher High
               g_swings[i].label = "HH";
               
               // Check for BOS (bullish)
               if(DidPriceBreak(prevHighBar, g_swings[i].bar, prevHigh, true))
               {
                  if(g_isBearish && InpShowCHoCH)
                  {
                     // CHoCH Bullish! (was bearish, now broke structure up)
                     DrawStructureBreak(swingBeforeBearBOSTime, swingBeforeBearBOS, 
                                        g_swings[i].bar, "CHoCH", true);
                  }
                  else if(InpShowBOS)
                  {
                     // BOS Bullish
                     DrawStructureBreak(prevHighTime, prevHigh, g_swings[i].bar, "BOS", true);
                  }
                  
                  g_isBullish = true;
                  g_isBearish = false;
                  
                  // Store the low before this high for CHoCH detection
                  swingBeforeBullBOS = g_lastSwingLow;
                  swingBeforeBullBOSTime = g_lastSwingLowTime;
               }
            }
            else
            {
               // Lower High
               g_swings[i].label = "LH";
            }
         }
         
         prevHigh = g_swings[i].price;
         prevHighTime = g_swings[i].time;
         prevHighBar = g_swings[i].bar;
         g_lastSwingHigh = g_swings[i].price;
         g_lastSwingHighTime = g_swings[i].time;
      }
      else
      {
         // Processing a LOW
         if(prevLow > 0)
         {
            if(g_swings[i].price < prevLow)
            {
               // Lower Low
               g_swings[i].label = "LL";
               
               // Check for BOS (bearish)
               if(DidPriceBreak(prevLowBar, g_swings[i].bar, prevLow, false))
               {
                  if(g_isBullish && InpShowCHoCH)
                  {
                     // CHoCH Bearish! (was bullish, now broke structure down)
                     DrawStructureBreak(swingBeforeBullBOSTime, swingBeforeBullBOS,
                                        g_swings[i].bar, "CHoCH", false);
                  }
                  else if(InpShowBOS)
                  {
                     // BOS Bearish
                     DrawStructureBreak(prevLowTime, prevLow, g_swings[i].bar, "BOS", false);
                  }
                  
                  g_isBearish = true;
                  g_isBullish = false;
                  
                  // Store the high before this low for CHoCH detection
                  swingBeforeBearBOS = g_lastSwingHigh;
                  swingBeforeBearBOSTime = g_lastSwingHighTime;
               }
            }
            else
            {
               // Higher Low
               g_swings[i].label = "HL";
            }
         }
         else
         {
            prevLow = g_swings[i].price;
         }
         
         prevLow = g_swings[i].price;
         prevLowTime = g_swings[i].time;
         prevLowBar = g_swings[i].bar;
         g_lastSwingLow = g_swings[i].price;
         g_lastSwingLowTime = g_swings[i].time;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if price broke a level                                      |
//+------------------------------------------------------------------+
bool DidPriceBreak(int fromBar, int toBar, double level, bool breakUp)
{
   for(int i = fromBar - 1; i >= toBar; i--)
   {
      if(i < 0) break;
      
      double close = iClose(_Symbol, PERIOD_CURRENT, i);
      
      if(breakUp && close > level)
         return true;
      if(!breakUp && close < level)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Find Order Blocks                                                 |
//+------------------------------------------------------------------+
void FindOrderBlocks()
{
   int limit = MathMin(InpLookback, iBars(_Symbol, PERIOD_CURRENT) - 5);
   
   for(int i = 3; i < limit; i++)
   {
      double open_i = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close_i = iClose(_Symbol, PERIOD_CURRENT, i);
      double high_i = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low_i = iLow(_Symbol, PERIOD_CURRENT, i);
      datetime time_i = iTime(_Symbol, PERIOD_CURRENT, i);
      
      // Bullish OB: Last bearish candle before a strong bullish move
      if(close_i < open_i)  // Bearish candle
      {
         // Check next candle for strong bullish move
         double nextClose = iClose(_Symbol, PERIOD_CURRENT, i-1);
         double nextHigh = iHigh(_Symbol, PERIOD_CURRENT, i-1);
         
         if(nextClose > high_i)  // Strong bullish engulfing
         {
            OrderBlock ob;
            ob.top = high_i;
            ob.bottom = low_i;
            ob.startTime = time_i;
            ob.endTime = iTime(_Symbol, PERIOD_CURRENT, MathMax(0, i - 20));
            ob.isBullish = true;
            ob.isValid = true;
            
            int size = ArraySize(g_orderBlocks);
            ArrayResize(g_orderBlocks, size + 1);
            g_orderBlocks[size] = ob;
         }
      }
      
      // Bearish OB: Last bullish candle before a strong bearish move
      if(close_i > open_i)  // Bullish candle
      {
         // Check next candle for strong bearish move
         double nextClose = iClose(_Symbol, PERIOD_CURRENT, i-1);
         double nextLow = iLow(_Symbol, PERIOD_CURRENT, i-1);
         
         if(nextClose < low_i)  // Strong bearish engulfing
         {
            OrderBlock ob;
            ob.top = high_i;
            ob.bottom = low_i;
            ob.startTime = time_i;
            ob.endTime = iTime(_Symbol, PERIOD_CURRENT, MathMax(0, i - 20));
            ob.isBullish = false;
            ob.isValid = true;
            
            int size = ArraySize(g_orderBlocks);
            ArrayResize(g_orderBlocks, size + 1);
            g_orderBlocks[size] = ob;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Find Fair Value Gaps                                              |
//+------------------------------------------------------------------+
void FindFairValueGaps()
{
   int limit = MathMin(InpLookback, iBars(_Symbol, PERIOD_CURRENT) - 3);
   
   for(int i = 2; i < limit; i++)
   {
      double high_prev = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
      double low_prev = iLow(_Symbol, PERIOD_CURRENT, i + 1);
      double high_curr = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low_curr = iLow(_Symbol, PERIOD_CURRENT, i);
      double high_next = iHigh(_Symbol, PERIOD_CURRENT, i - 1);
      double low_next = iLow(_Symbol, PERIOD_CURRENT, i - 1);
      datetime time_curr = iTime(_Symbol, PERIOD_CURRENT, i);
      
      // Bullish FVG: Gap between candle 1's high and candle 3's low
      if(low_next > high_prev)
      {
         FairValueGap fvg;
         fvg.top = low_next;
         fvg.bottom = high_prev;
         fvg.time = time_curr;
         fvg.isBullish = true;
         fvg.isFilled = false;
         
         int size = ArraySize(g_fvgs);
         ArrayResize(g_fvgs, size + 1);
         g_fvgs[size] = fvg;
      }
      
      // Bearish FVG: Gap between candle 1's low and candle 3's high
      if(high_next < low_prev)
      {
         FairValueGap fvg;
         fvg.top = low_prev;
         fvg.bottom = high_next;
         fvg.time = time_curr;
         fvg.isBullish = false;
         fvg.isFilled = false;
         
         int size = ArraySize(g_fvgs);
         ArrayResize(g_fvgs, size + 1);
         g_fvgs[size] = fvg;
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Everything                                                   |
//+------------------------------------------------------------------+
void DrawAll()
{
   // Draw Swing Points
   if(InpShowSwings)
      DrawSwingPoints();
   
   // Draw Order Blocks
   if(InpShowOrderBlocks)
      DrawOrderBlocks();
   
   // Draw FVGs
   if(InpShowFVG)
      DrawFVGs();
}

//+------------------------------------------------------------------+
//| Draw Swing Points with Labels                                     |
//+------------------------------------------------------------------+
void DrawSwingPoints()
{
   int total = ArraySize(g_swings);
   datetime now = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < total; i++)
   {
      SwingPoint sp = g_swings[i];
      color clr;
      
      // Set color based on label
      if(sp.label == "HH") clr = InpColorHH;
      else if(sp.label == "HL") clr = InpColorHL;
      else if(sp.label == "LH") clr = InpColorLH;
      else if(sp.label == "LL") clr = InpColorLL;
      else continue;  // Skip unclassified
      
      g_objCount++;
      string name = "SMC_SW_" + IntegerToString(g_objCount);
      
      // Draw label
      ObjectCreate(0, name, OBJ_TEXT, 0, sp.time, sp.price);
      ObjectSetString(0, name, OBJPROP_TEXT, sp.label);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, sp.isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
      
      // Draw horizontal dotted line
      g_objCount++;
      string lineName = "SMC_SWL_" + IntegerToString(g_objCount);
      ObjectCreate(0, lineName, OBJ_TREND, 0, sp.time, sp.price, now, sp.price);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Draw Structure Break (BOS/CHoCH)                                  |
//+------------------------------------------------------------------+
void DrawStructureBreak(datetime levelTime, double levelPrice, int breakBar, string type, bool isBullish)
{
   if(levelTime == 0 || levelPrice == 0) return;
   
   g_objCount++;
   datetime breakTime = iTime(_Symbol, PERIOD_CURRENT, breakBar);
   
   color clr;
   if(type == "BOS")
      clr = isBullish ? InpColorBOSBull : InpColorBOSBear;
   else
      clr = isBullish ? InpColorCHoCHBull : InpColorCHoCHBear;
   
   // Draw the structure line
   string lineName = "SMC_BRK_" + IntegerToString(g_objCount);
   ObjectCreate(0, lineName, OBJ_TREND, 0, levelTime, levelPrice, breakTime, levelPrice);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, type == "CHoCH" ? STYLE_DASH : STYLE_SOLID);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
   
   // Draw label
   g_objCount++;
   string labelName = "SMC_BRKL_" + IntegerToString(g_objCount);
   datetime midTime = levelTime + (breakTime - levelTime) / 2;
   ObjectCreate(0, labelName, OBJ_TEXT, 0, midTime, levelPrice);
   ObjectSetString(0, labelName, OBJPROP_TEXT, type);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, isBullish ? ANCHOR_UPPER : ANCHOR_LOWER);
}

//+------------------------------------------------------------------+
//| Draw Order Blocks                                                 |
//+------------------------------------------------------------------+
void DrawOrderBlocks()
{
   int total = ArraySize(g_orderBlocks);
   datetime now = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < total; i++)
   {
      if(!g_orderBlocks[i].isValid) continue;
      
      g_objCount++;
      string name = "SMC_OB_" + IntegerToString(g_objCount);
      
      color clr = g_orderBlocks[i].isBullish ? InpColorOBBull : InpColorOBBear;
      
      // Draw rectangle
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, 
                   g_orderBlocks[i].startTime, g_orderBlocks[i].top,
                   now, g_orderBlocks[i].bottom);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      
      // Label
      g_objCount++;
      string lblName = "SMC_OBL_" + IntegerToString(g_objCount);
      ObjectCreate(0, lblName, OBJ_TEXT, 0, 
                   g_orderBlocks[i].startTime, 
                   g_orderBlocks[i].isBullish ? g_orderBlocks[i].top : g_orderBlocks[i].bottom);
      ObjectSetString(0, lblName, OBJPROP_TEXT, g_orderBlocks[i].isBullish ? "OB+" : "OB-");
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
   }
}

//+------------------------------------------------------------------+
//| Draw Fair Value Gaps                                              |
//+------------------------------------------------------------------+
void DrawFVGs()
{
   int total = ArraySize(g_fvgs);
   datetime now = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < total; i++)
   {
      if(g_fvgs[i].isFilled) continue;
      
      g_objCount++;
      string name = "SMC_FVG_" + IntegerToString(g_objCount);
      
      color clr = g_fvgs[i].isBullish ? InpColorFVGBull : InpColorFVGBear;
      
      // Draw rectangle
      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                   g_fvgs[i].time, g_fvgs[i].top,
                   now, g_fvgs[i].bottom);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      
      // Label
      g_objCount++;
      string lblName = "SMC_FVGL_" + IntegerToString(g_objCount);
      ObjectCreate(0, lblName, OBJ_TEXT, 0, g_fvgs[i].time, (g_fvgs[i].top + g_fvgs[i].bottom) / 2);
      ObjectSetString(0, lblName, OBJPROP_TEXT, "FVG");
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 7);
   }
}
//+------------------------------------------------------------------+
