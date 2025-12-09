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
input bool   ShowSwingPoints = false;    // Show Swing Points (HH/HL/LH/LL)
input bool   ShowBOS = true;              // Show Break of Structure
input bool   ShowCHoCH = true;            // Show Change of Character
input bool   ShowOrderBlocks = false;     // Show Order Blocks
input int    ExtendLinesBars = 50;        // Extend Lines (bars)

input group "=== Colors ==="
input color  ColorHH = clrDodgerBlue;     // Higher High Color
input color  ColorHL = clrLime;           // Higher Low Color
input color  ColorLH = clrOrange;         // Lower High Color
input color  ColorLL = clrRed;            // Lower Low Color
input color  ColorBOS = clrWhite;         // BOS Line Color
input color  ColorCHoCH = clrRed;         // CHoCH Line Color
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
   
   if(g_swing_count < 3) return;
   
   // Track breaks directly from swing sequence
   for(int i = 0; i < g_swing_count - 1; i++)
   {
      SwingPoint current = g_swings[i];
      
      // Find next swing of same type
      SwingPoint next_same;
      bool found_next = false;
      
      for(int j = i + 1; j < g_swing_count; j++)
      {
         if(g_swings[j].is_high == current.is_high)
         {
            next_same = g_swings[j];
            found_next = true;
            break;
         }
      }
      
      if(!found_next) continue;
      
      // Find previous swing of opposite type between current and next
      SwingPoint between_opposite;
      bool found_between = false;
      
      for(int k = i + 1; k < g_swing_count; k++)
      {
         if(g_swings[k].is_high != current.is_high && 
            g_swings[k].bar_index > current.bar_index && 
            g_swings[k].bar_index < next_same.bar_index)
         {
            between_opposite = g_swings[k];
            found_between = true;
            break;
         }
      }
      
      if(!found_between) continue;
      
      // Detect BOS and CHoCH based on swing patterns
      if(current.is_high)
      {
         // Working with highs
         if(next_same.price > current.price)
         {
            // HH formed - BOS if we broke previous high
            if(g_break_count < 100)
            {
               g_breaks[g_break_count].time = next_same.time;
               g_breaks[g_break_count].price = current.price;
               g_breaks[g_break_count].bar_index = next_same.bar_index;
               g_breaks[g_break_count].is_bos = true;
               g_breaks[g_break_count].is_bullish = true;
               g_break_count++;
            }
         }
         else if(next_same.price < current.price)
         {
            // LH formed - CHoCH (potential reversal)
            if(g_break_count < 100)
            {
               g_breaks[g_break_count].time = between_opposite.time;
               g_breaks[g_break_count].price = between_opposite.price;
               g_breaks[g_break_count].bar_index = between_opposite.bar_index;
               g_breaks[g_break_count].is_bos = false;
               g_breaks[g_break_count].is_bullish = false;
               g_break_count++;
            }
         }
      }
      else
      {
         // Working with lows
         if(next_same.price < current.price)
         {
            // LL formed - BOS if we broke previous low
            if(g_break_count < 100)
            {
               g_breaks[g_break_count].time = next_same.time;
               g_breaks[g_break_count].price = current.price;
               g_breaks[g_break_count].bar_index = next_same.bar_index;
               g_breaks[g_break_count].is_bos = true;
               g_breaks[g_break_count].is_bullish = false;
               g_break_count++;
            }
         }
         else if(next_same.price > current.price)
         {
            // HL formed - CHoCH (potential reversal)
            if(g_break_count < 100)
            {
               g_breaks[g_break_count].time = between_opposite.time;
               g_breaks[g_break_count].price = between_opposite.price;
               g_breaks[g_break_count].bar_index = between_opposite.bar_index;
               g_breaks[g_break_count].is_bos = false;
               g_breaks[g_break_count].is_bullish = true;
               g_break_count++;
            }
         }
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
         datetime time_start = g_breaks[i].time - PeriodSeconds() * ExtendLinesBars;
         datetime time_end = g_breaks[i].time + PeriodSeconds() * ExtendLinesBars;
         
         ObjectCreate(0, obj_name, OBJ_TREND, 0, time_start, g_breaks[i].price, 
                      time_end, g_breaks[i].price);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DOT);
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
