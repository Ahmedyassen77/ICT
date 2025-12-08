//+------------------------------------------------------------------+
//|                                               SMC_Indicator.mq5 |
//|                         Smart Money Concepts - Visual Indicator  |
//|                                    Version 2.0 - Latest Only    |
//+------------------------------------------------------------------+
#property copyright "SMC Indicator v2.0"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "═══════════ Display Settings ═══════════"
input bool     Show_Only_Latest = true;      // Show Only Latest Concepts
input int      Latest_Count = 5;             // Number of Latest to Show

input group "═══════════ Swing Detection ═══════════"
input int      Swing_Strength = 3;           // Swing Strength
input int      Lookback = 200;               // Lookback Bars

input group "═══════════ Colors ═══════════"
input color    Color_HH = clrDodgerBlue;     // HH Color
input color    Color_HL = clrLime;           // HL Color
input color    Color_LH = clrOrange;         // LH Color
input color    Color_LL = clrRed;            // LL Color
input color    Color_BOS = clrYellow;        // BOS Color
input color    Color_CHoCH = clrMagenta;     // CHoCH Color

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct SwingInfo
{
   string   label;
   color    clr;
   double   price;
   datetime time;
   bool     is_high;
};

struct BreakInfo
{
   string   label;
   color    clr;
   double   level;
   datetime level_time;
   datetime break_time;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
datetime g_last_bar = 0;
int g_obj_count = 0;

SwingInfo g_allSwings[];
BreakInfo g_allBreaks[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════");
   Print("   SMC INDICATOR v2.0 - SHOW ONLY LATEST");
   Print("   Show_Only_Latest: ", Show_Only_Latest);
   Print("   Latest_Count: ", Latest_Count);
   Print("═══════════════════════════════════════════════════");
   
   ObjectsDeleteAll(0, "SMC_");
   AnalyzeAndDraw();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SMC_");
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
   datetime current_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(current_bar != g_last_bar)
   {
      g_last_bar = current_bar;
      AnalyzeAndDraw();
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Main Analysis Function                                            |
//+------------------------------------------------------------------+
void AnalyzeAndDraw()
{
   // Clear previous
   ObjectsDeleteAll(0, "SMC_");
   g_obj_count = 0;
   ArrayResize(g_allSwings, 0);
   ArrayResize(g_allBreaks, 0);
   
   double prevHigh = 0, prevLow = 0;
   datetime prevHighTime = 0, prevLowTime = 0;
   double lastLowBeforeHigh = 0, lastHighBeforeLow = 0;
   datetime lastLowBeforeHighTime = 0, lastHighBeforeLowTime = 0;
   
   bool isBullish = false, isBearish = false;
   double chochLevelBull = 0, chochLevelBear = 0;
   datetime chochLevelBullTime = 0, chochLevelBearTime = 0;
   
   // Find and process swings from oldest to newest
   for(int i = Lookback - Swing_Strength - 1; i >= Swing_Strength; i--)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      datetime time = iTime(_Symbol, PERIOD_CURRENT, i);
      
      // Check Swing High
      bool isSwingHigh = true;
      for(int j = 1; j <= Swing_Strength; j++)
      {
         if(iHigh(_Symbol, PERIOD_CURRENT, i-j) >= high || 
            iHigh(_Symbol, PERIOD_CURRENT, i+j) >= high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      // Check Swing Low
      bool isSwingLow = true;
      for(int j = 1; j <= Swing_Strength; j++)
      {
         if(iLow(_Symbol, PERIOD_CURRENT, i-j) <= low || 
            iLow(_Symbol, PERIOD_CURRENT, i+j) <= low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      // Process Swing High
      if(isSwingHigh)
      {
         string label = "";
         color clr = clrWhite;
         
         if(prevHigh > 0)
         {
            if(high > prevHigh)
            {
               // Higher High
               label = "HH";
               clr = Color_HH;
               
               // Check for BOS/CHoCH
               if(DidCloseBreak(i, prevHighTime, prevHigh, true))
               {
                  if(isBearish && chochLevelBear > 0)
                  {
                     // CHoCH Bullish!
                     AddBreak("CHoCH", Color_CHoCH, chochLevelBear, chochLevelBearTime, i);
                  }
                  else if(!isBullish)
                  {
                     // BOS Bullish
                     AddBreak("BOS", Color_BOS, prevHigh, prevHighTime, i);
                  }
                  
                  isBullish = true;
                  isBearish = false;
                  
                  // Save the HL that caused this BOS
                  if(lastLowBeforeHigh > 0)
                  {
                     chochLevelBull = lastLowBeforeHigh;
                     chochLevelBullTime = lastLowBeforeHighTime;
                  }
               }
            }
            else
            {
               // Lower High
               label = "LH";
               clr = Color_LH;
            }
         }
         else
         {
            label = "H";
            clr = clrGray;
         }
         
         // Store swing
         if(label != "")
            AddSwing(label, clr, high, time, true);
         
         prevHigh = high;
         prevHighTime = time;
         lastHighBeforeLow = high;
         lastHighBeforeLowTime = time;
      }
      
      // Process Swing Low
      if(isSwingLow)
      {
         string label = "";
         color clr = clrWhite;
         
         if(prevLow > 0)
         {
            if(low < prevLow)
            {
               // Lower Low
               label = "LL";
               clr = Color_LL;
               
               // Check for BOS/CHoCH
               if(DidCloseBreak(i, prevLowTime, prevLow, false))
               {
                  if(isBullish && chochLevelBull > 0)
                  {
                     // CHoCH Bearish!
                     AddBreak("CHoCH", Color_CHoCH, chochLevelBull, chochLevelBullTime, i);
                  }
                  else if(!isBearish)
                  {
                     // BOS Bearish
                     AddBreak("BOS", Color_BOS, prevLow, prevLowTime, i);
                  }
                  
                  isBearish = true;
                  isBullish = false;
                  
                  // Save the LH that caused this BOS
                  if(lastHighBeforeLow > 0)
                  {
                     chochLevelBear = lastHighBeforeLow;
                     chochLevelBearTime = lastHighBeforeLowTime;
                  }
               }
            }
            else
            {
               // Higher Low
               label = "HL";
               clr = Color_HL;
            }
         }
         else
         {
            label = "L";
            clr = clrGray;
         }
         
         // Store swing
         if(label != "")
            AddSwing(label, clr, low, time, false);
         
         prevLow = low;
         prevLowTime = time;
         lastLowBeforeHigh = low;
         lastLowBeforeHighTime = time;
      }
   }
   
   // NOW DRAW - Only Latest if enabled!
   DrawAllConcepts();
   
   ChartRedraw(0);
   Print("Total Swings: ", ArraySize(g_allSwings), " | Total Breaks: ", ArraySize(g_allBreaks), " | Objects Drawn: ", g_obj_count);
}

//+------------------------------------------------------------------+
//| Add swing to array                                                |
//+------------------------------------------------------------------+
void AddSwing(string label, color clr, double price, datetime time, bool is_high)
{
   int size = ArraySize(g_allSwings);
   ArrayResize(g_allSwings, size + 1);
   
   g_allSwings[size].label = label;
   g_allSwings[size].clr = clr;
   g_allSwings[size].price = price;
   g_allSwings[size].time = time;
   g_allSwings[size].is_high = is_high;
}

//+------------------------------------------------------------------+
//| Add break to array                                                |
//+------------------------------------------------------------------+
void AddBreak(string label, color clr, double level, datetime level_time, int break_bar)
{
   int size = ArraySize(g_allBreaks);
   ArrayResize(g_allBreaks, size + 1);
   
   g_allBreaks[size].label = label;
   g_allBreaks[size].clr = clr;
   g_allBreaks[size].level = level;
   g_allBreaks[size].level_time = level_time;
   g_allBreaks[size].break_time = iTime(_Symbol, PERIOD_CURRENT, break_bar);
}

//+------------------------------------------------------------------+
//| Draw All Concepts - Apply Show_Only_Latest filter                 |
//+------------------------------------------------------------------+
void DrawAllConcepts()
{
   int totalSwings = ArraySize(g_allSwings);
   int totalBreaks = ArraySize(g_allBreaks);
   
   // Determine how many to draw
   int swingsToShow = totalSwings;
   int breaksToShow = totalBreaks;
   
   if(Show_Only_Latest)
   {
      swingsToShow = MathMin(Latest_Count, totalSwings);
      breaksToShow = MathMin(Latest_Count, totalBreaks);
   }
   
   // Draw LATEST swings (from end of array = newest)
   int swingStart = totalSwings - swingsToShow;
   for(int i = swingStart; i < totalSwings; i++)
   {
      DrawSwing(g_allSwings[i].label, g_allSwings[i].clr, g_allSwings[i].price, 
                g_allSwings[i].time, g_allSwings[i].is_high);
   }
   
   // Draw LATEST breaks (from end of array = newest)
   int breakStart = totalBreaks - breaksToShow;
   for(int i = breakStart; i < totalBreaks; i++)
   {
      DrawBreak(g_allBreaks[i].label, g_allBreaks[i].clr, g_allBreaks[i].level,
                g_allBreaks[i].level_time, g_allBreaks[i].break_time);
   }
   
   Print("Showing: ", swingsToShow, " swings, ", breaksToShow, " breaks (Show_Only_Latest=", Show_Only_Latest, ")");
}

//+------------------------------------------------------------------+
//| Check if candle CLOSED beyond a level                             |
//+------------------------------------------------------------------+
bool DidCloseBreak(int current_bar, datetime level_time, double level_price, bool break_above)
{
   int level_bar = iBarShift(_Symbol, PERIOD_CURRENT, level_time);
   
   for(int bar = level_bar - 1; bar >= current_bar; bar--)
   {
      if(bar < 0) break;
      
      double close = iClose(_Symbol, PERIOD_CURRENT, bar);
      
      if(break_above && close > level_price)
         return true;
      
      if(!break_above && close < level_price)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Draw Swing Point                                                  |
//+------------------------------------------------------------------+
void DrawSwing(string label, color clr, double price, datetime time, bool is_high)
{
   g_obj_count++;
   
   int arrow = is_high ? 234 : 233;
   double offset = is_high ? 50 * _Point : -50 * _Point;
   
   // Arrow
   string arr_name = "SMC_A_" + IntegerToString(g_obj_count);
   if(ObjectCreate(0, arr_name, OBJ_ARROW, 0, time, price))
   {
      ObjectSetInteger(0, arr_name, OBJPROP_ARROWCODE, arrow);
      ObjectSetInteger(0, arr_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, arr_name, OBJPROP_WIDTH, 2);
   }
   
   // Label
   string lbl_name = "SMC_L_" + IntegerToString(g_obj_count);
   if(ObjectCreate(0, lbl_name, OBJ_TEXT, 0, time, price + offset))
   {
      ObjectSetString(0, lbl_name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, lbl_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lbl_name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, lbl_name, OBJPROP_FONT, "Arial Bold");
   }
   
   // Horizontal line
   string line_name = "SMC_H_" + IntegerToString(g_obj_count);
   datetime end_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(ObjectCreate(0, line_name, OBJ_TREND, 0, time, price, end_time, price))
   {
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Draw Break (BOS/CHoCH)                                            |
//+------------------------------------------------------------------+
void DrawBreak(string label, color clr, double level, datetime level_time, datetime break_time)
{
   g_obj_count++;
   
   // Line
   string line_name = "SMC_B_" + IntegerToString(g_obj_count);
   if(ObjectCreate(0, line_name, OBJ_TREND, 0, level_time, level, break_time, level))
   {
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
   }
   
   // Label
   string lbl_name = "SMC_BL_" + IntegerToString(g_obj_count);
   if(ObjectCreate(0, lbl_name, OBJ_TEXT, 0, break_time, level))
   {
      ObjectSetString(0, lbl_name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, lbl_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lbl_name, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, lbl_name, OBJPROP_FONT, "Arial Bold");
   }
}
//+------------------------------------------------------------------+
