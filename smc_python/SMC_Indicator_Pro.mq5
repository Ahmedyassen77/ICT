//+------------------------------------------------------------------+
//|                                           SMC_Indicator_Pro.mq5 |
//|                                  Smart Money Concepts Indicator |
//|                                   https://github.com/Ahmedyassen77/ICT |
//+------------------------------------------------------------------+
#property copyright "SMC Pro - Ahmed Yassen"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input Parameters
input group "=== Swing Detection ==="
input int    SwingStrength = 5;           // Swing Strength (bars left/right)
input int    MaxSwings = 50;              // Maximum Swings to Track

input group "=== Display Settings ==="
input bool   ShowSwingPoints = true;     // Show Swing Points (HH/HL/LH/LL)
input bool   ShowBOS = true;              // Show Break of Structure
input bool   ShowCHoCH = true;            // Show Change of Character
input bool   ShowOrderBlocks = true;      // Show Order Blocks

input group "=== Colors ==="
input color  ColorHH = clrDodgerBlue;     // Higher High Color
input color  ColorHL = clrLime;           // Higher Low Color
input color  ColorLH = clrOrange;         // Lower High Color
input color  ColorLL = clrRed;            // Lower Low Color
input color  ColorBOS = clrYellow;        // BOS Line Color
input color  ColorCHoCH = clrMagenta;     // CHoCH Line Color
input color  ColorBullishOB = C'0,100,255'; // Bullish OB Color
input color  ColorBearishOB = C'255,0,100'; // Bearish OB Color

//--- Enums
enum ENUM_SWING_TYPE
{
   SWING_HH,  // Higher High
   SWING_HL,  // Higher Low
   SWING_LH,  // Lower High
   SWING_LL   // Lower Low
};

//--- Structures
struct SwingPoint
{
   datetime time;
   double   price;
   int      bar_index;
   ENUM_SWING_TYPE type;
   bool     is_high;
};

struct BreakLevel
{
   datetime time;
   double   price;
   int      bar_index;
   bool     is_bos;  // true = BOS, false = CHoCH
   bool     is_bullish;
};

struct OrderBlock
{
   datetime time_start;
   datetime time_end;
   double   price_high;
   double   price_low;
   bool     is_bullish;
};

//--- Global Arrays
SwingPoint  g_swings[];
BreakLevel  g_breaks[];
OrderBlock  g_orderblocks[];

int g_swing_count = 0;
int g_break_count = 0;
int g_ob_count = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   ArrayResize(g_swings, MaxSwings);
   ArrayResize(g_breaks, 100);
   ArrayResize(g_orderblocks, 100);
   
   Print("SMC Indicator Pro Initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   // Clear old drawings on new bar
   static datetime last_time = 0;
   if(time[0] != last_time)
   {
      last_time = time[0];
      DeleteAllObjects();
      
      // Detect swings
      DetectSwings(time, high, low, rates_total);
      
      // Classify swings (HH/HL/LH/LL)
      ClassifySwings();
      
      // Detect BOS and CHoCH
      DetectBreaks(time, high, low, close, rates_total);
      
      // Detect Order Blocks
      DetectOrderBlocks(time, open, high, low, close);
      
      // Draw everything
      DrawAll();
      
      ChartRedraw(0);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Detect Swing Points                                              |
//+------------------------------------------------------------------+
void DetectSwings(const datetime &time[], const double &high[], const double &low[], int total)
{
   g_swing_count = 0;
   
   for(int i = SwingStrength; i < total - SwingStrength && g_swing_count < MaxSwings; i++)
   {
      // Check for Swing High
      bool is_swing_high = true;
      for(int j = 1; j <= SwingStrength; j++)
      {
         if(high[i] <= high[i-j] || high[i] <= high[i+j])
         {
            is_swing_high = false;
            break;
         }
      }
      
      if(is_swing_high)
      {
         g_swings[g_swing_count].time = time[i];
         g_swings[g_swing_count].price = high[i];
         g_swings[g_swing_count].bar_index = i;
         g_swings[g_swing_count].is_high = true;
         g_swing_count++;
         continue;
      }
      
      // Check for Swing Low
      bool is_swing_low = true;
      for(int j = 1; j <= SwingStrength; j++)
      {
         if(low[i] >= low[i-j] || low[i] >= low[i+j])
         {
            is_swing_low = false;
            break;
         }
      }
      
      if(is_swing_low)
      {
         g_swings[g_swing_count].time = time[i];
         g_swings[g_swing_count].price = low[i];
         g_swings[g_swing_count].bar_index = i;
         g_swings[g_swing_count].is_high = false;
         g_swing_count++;
      }
   }
}

//+------------------------------------------------------------------+
//| Classify Swings (HH/HL/LH/LL)                                    |
//+------------------------------------------------------------------+
void ClassifySwings()
{
   if(g_swing_count < 2) return;
   
   // First swing has no classification
   g_swings[0].type = g_swings[0].is_high ? SWING_HH : SWING_LL;
   
   for(int i = 1; i < g_swing_count; i++)
   {
      SwingPoint prev_same_type;
      bool found = false;
      
      // Find previous swing of same type (high/low)
      for(int j = i - 1; j >= 0; j--)
      {
         if(g_swings[j].is_high == g_swings[i].is_high)
         {
            prev_same_type = g_swings[j];
            found = true;
            break;
         }
      }
      
      if(!found)
      {
         g_swings[i].type = g_swings[i].is_high ? SWING_HH : SWING_LL;
         continue;
      }
      
      // Classify
      if(g_swings[i].is_high)
      {
         // This is a high
         if(g_swings[i].price > prev_same_type.price)
            g_swings[i].type = SWING_HH;  // Higher High
         else
            g_swings[i].type = SWING_LH;  // Lower High
      }
      else
      {
         // This is a low
         if(g_swings[i].price > prev_same_type.price)
            g_swings[i].type = SWING_HL;  // Higher Low
         else
            g_swings[i].type = SWING_LL;  // Lower Low
      }
   }
}

//+------------------------------------------------------------------+
//| Detect BOS and CHoCH                                             |
//+------------------------------------------------------------------+
void DetectBreaks(const datetime &time[], const double &high[], const double &low[], 
                  const double &close[], int total)
{
   g_break_count = 0;
   
   // Determine current trend based on recent swings
   bool is_uptrend = false;
   bool is_downtrend = false;
   
   // Look at last 5 classified swings
   int hh_count = 0, hl_count = 0, lh_count = 0, ll_count = 0;
   
   for(int i = 0; i < MathMin(5, g_swing_count); i++)
   {
      switch(g_swings[i].type)
      {
         case SWING_HH: hh_count++; break;
         case SWING_HL: hl_count++; break;
         case SWING_LH: lh_count++; break;
         case SWING_LL: ll_count++; break;
      }
   }
   
   if(hh_count + hl_count > lh_count + ll_count)
      is_uptrend = true;
   else if(lh_count + ll_count > hh_count + hl_count)
      is_downtrend = true;
   
   // Find last significant swing points
   double last_hh = 0, last_hl = 0, last_lh = 0, last_ll = 0;
   
   for(int i = 0; i < g_swing_count; i++)
   {
      if(g_swings[i].type == SWING_HH && last_hh == 0) last_hh = g_swings[i].price;
      if(g_swings[i].type == SWING_HL && last_hl == 0) last_hl = g_swings[i].price;
      if(g_swings[i].type == SWING_LH && last_lh == 0) last_lh = g_swings[i].price;
      if(g_swings[i].type == SWING_LL && last_ll == 0) last_ll = g_swings[i].price;
   }
   
   // Check recent price action for breaks
   for(int i = 1; i < MathMin(100, total); i++)
   {
      // BOS Bullish: In uptrend, break above last HH
      if(is_uptrend && last_hh > 0 && close[i] > last_hh && close[i+1] <= last_hh)
      {
         g_breaks[g_break_count].time = time[i];
         g_breaks[g_break_count].price = last_hh;
         g_breaks[g_break_count].bar_index = i;
         g_breaks[g_break_count].is_bos = true;
         g_breaks[g_break_count].is_bullish = true;
         g_break_count++;
      }
      
      // BOS Bearish: In downtrend, break below last LL
      if(is_downtrend && last_ll > 0 && close[i] < last_ll && close[i+1] >= last_ll)
      {
         g_breaks[g_break_count].time = time[i];
         g_breaks[g_break_count].price = last_ll;
         g_breaks[g_break_count].bar_index = i;
         g_breaks[g_break_count].is_bos = true;
         g_breaks[g_break_count].is_bullish = false;
         g_break_count++;
      }
      
      // CHoCH Bullish: In downtrend, break above last LH
      if(is_downtrend && last_lh > 0 && close[i] > last_lh && close[i+1] <= last_lh)
      {
         g_breaks[g_break_count].time = time[i];
         g_breaks[g_break_count].price = last_lh;
         g_breaks[g_break_count].bar_index = i;
         g_breaks[g_break_count].is_bos = false;
         g_breaks[g_break_count].is_bullish = true;
         g_break_count++;
      }
      
      // CHoCH Bearish: In uptrend, break below last HL
      if(is_uptrend && last_hl > 0 && close[i] < last_hl && close[i+1] >= last_hl)
      {
         g_breaks[g_break_count].time = time[i];
         g_breaks[g_break_count].price = last_hl;
         g_breaks[g_break_count].bar_index = i;
         g_breaks[g_break_count].is_bos = false;
         g_breaks[g_break_count].is_bullish = false;
         g_break_count++;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                              |
//+------------------------------------------------------------------+
void DetectOrderBlocks(const datetime &time[], const double &open[], const double &high[],
                       const double &low[], const double &close[])
{
   g_ob_count = 0;
   
   // Find Order Blocks around BOS/CHoCH levels
   for(int b = 0; b < g_break_count && g_ob_count < 100; b++)
   {
      int break_bar = g_breaks[b].bar_index;
      
      if(g_breaks[b].is_bullish)
      {
         // Bullish OB: Last bearish candle before the move
         for(int i = break_bar + 1; i < break_bar + 10; i++)
         {
            if(close[i] < open[i])  // Bearish candle
            {
               g_orderblocks[g_ob_count].time_start = time[i];
               g_orderblocks[g_ob_count].time_end = time[MathMax(0, i - 20)];
               g_orderblocks[g_ob_count].price_high = high[i];
               g_orderblocks[g_ob_count].price_low = low[i];
               g_orderblocks[g_ob_count].is_bullish = true;
               g_ob_count++;
               break;
            }
         }
      }
      else
      {
         // Bearish OB: Last bullish candle before the move
         for(int i = break_bar + 1; i < break_bar + 10; i++)
         {
            if(close[i] > open[i])  // Bullish candle
            {
               g_orderblocks[g_ob_count].time_start = time[i];
               g_orderblocks[g_ob_count].time_end = time[MathMax(0, i - 20)];
               g_orderblocks[g_ob_count].price_high = high[i];
               g_orderblocks[g_ob_count].price_low = low[i];
               g_orderblocks[g_ob_count].is_bullish = false;
               g_ob_count++;
               break;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw All Elements                                                 |
//+------------------------------------------------------------------+
void DrawAll()
{
   // Draw Swing Points
   if(ShowSwingPoints)
   {
      for(int i = 0; i < g_swing_count; i++)
      {
         string label = "";
         color clr = clrWhite;
         
         switch(g_swings[i].type)
         {
            case SWING_HH: label = "HH"; clr = ColorHH; break;
            case SWING_HL: label = "HL"; clr = ColorHL; break;
            case SWING_LH: label = "LH"; clr = ColorLH; break;
            case SWING_LL: label = "LL"; clr = ColorLL; break;
         }
         
         string obj_name = "Swing_" + IntegerToString(i);
         ObjectCreate(0, obj_name, OBJ_TEXT, 0, g_swings[i].time, g_swings[i].price);
         ObjectSetString(0, obj_name, OBJPROP_TEXT, label);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 10);
      }
   }
   
   // Draw BOS and CHoCH
   if(ShowBOS || ShowCHoCH)
   {
      for(int i = 0; i < g_break_count; i++)
      {
         if(g_breaks[i].is_bos && !ShowBOS) continue;
         if(!g_breaks[i].is_bos && !ShowCHoCH) continue;
         
         string label = g_breaks[i].is_bos ? "BOS" : "CHoCH";
         color clr = g_breaks[i].is_bos ? ColorBOS : ColorCHoCH;
         
         string obj_name = "Break_" + IntegerToString(i);
         datetime time2 = g_breaks[i].time - PeriodSeconds() * 10;
         
         ObjectCreate(0, obj_name, OBJ_TREND, 0, time2, g_breaks[i].price, 
                      g_breaks[i].time + PeriodSeconds() * 10, g_breaks[i].price);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, g_breaks[i].is_bos ? 1 : 2);
         ObjectSetInteger(0, obj_name, OBJPROP_STYLE, g_breaks[i].is_bos ? STYLE_DASH : STYLE_SOLID);
         ObjectSetInteger(0, obj_name, OBJPROP_RAY_RIGHT, false);
         
         // Add text label
         string txt_name = "BreakTxt_" + IntegerToString(i);
         ObjectCreate(0, txt_name, OBJ_TEXT, 0, g_breaks[i].time, g_breaks[i].price);
         ObjectSetString(0, txt_name, OBJPROP_TEXT, label);
         ObjectSetInteger(0, txt_name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, txt_name, OBJPROP_FONTSIZE, 8);
      }
   }
   
   // Draw Order Blocks
   if(ShowOrderBlocks)
   {
      for(int i = 0; i < g_ob_count; i++)
      {
         string obj_name = "OB_" + IntegerToString(i);
         color clr = g_orderblocks[i].is_bullish ? ColorBullishOB : ColorBearishOB;
         
         ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0,
                     g_orderblocks[i].time_start, g_orderblocks[i].price_high,
                     g_orderblocks[i].time_end, g_orderblocks[i].price_low);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Delete All Objects                                                |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "Swing_") == 0 || 
         StringFind(name, "Break_") == 0 ||
         StringFind(name, "BreakTxt_") == 0 ||
         StringFind(name, "OB_") == 0)
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Deinitialize                                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllObjects();
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
