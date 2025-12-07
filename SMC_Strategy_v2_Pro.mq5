//+------------------------------------------------------------------+
//|                                         SMC_Strategy_v2_Pro.mq5 |
//|                         Smart Money Concepts Trading Strategy    |
//|                                    Version 2.1 - Visual Edition  |
//+------------------------------------------------------------------+
#property copyright "SMC Strategy v2.1"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "2.10"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+
enum ENUM_MARKET_BIAS
{
   BIAS_BULLISH,        // Bullish
   BIAS_BEARISH,        // Bearish
   BIAS_NEUTRAL         // Neutral
};

enum ENUM_SWING_TYPE
{
   SWING_HH,            // Higher High
   SWING_HL,            // Higher Low
   SWING_LH,            // Lower High
   SWING_LL,            // Lower Low
   SWING_UNKNOWN        // Unknown
};

enum ENUM_STRUCTURE_BREAK
{
   BREAK_NONE,          // No Break
   BREAK_BOS_BULL,      // BOS Bullish (trend continuation)
   BREAK_BOS_BEAR,      // BOS Bearish (trend continuation)
   BREAK_CHOCH_BULL,    // CHoCH Bullish (trend reversal)
   BREAK_CHOCH_BEAR     // CHoCH Bearish (trend reversal)
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double         price;           // Price level
   datetime       time;            // Time of formation
   int            bar_index;       // Bar index
   bool           is_high;         // true = swing high, false = swing low
   ENUM_SWING_TYPE swing_type;     // HH, HL, LH, LL
   bool           is_broken;       // Has it been broken?
   string         label;           // Label to display
};

struct StructureBreak
{
   ENUM_STRUCTURE_BREAK type;      // Type of break
   double         break_level;     // Level that was broken
   double         break_price;     // Price that broke the level
   datetime       break_time;      // Time of break
   int            break_bar;       // Bar index of break
   double         break_distance;  // Distance of break in points
};

struct MarketStructure
{
   ENUM_MARKET_BIAS current_bias;       // Current market bias
   SwingPoint       swing_points[];     // All swing points in order
   StructureBreak   last_break;         // Last structure break
   int              swing_count;        // Number of swing points
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - GENERAL                                        |
//+------------------------------------------------------------------+
input group "═══════════ General Settings ═══════════"
input int      Magic_Number = 12345;              // Magic Number
input string   EA_Comment = "SMC_v2_Pro";         // Trade Comment

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - SWING DETECTION                                |
//+------------------------------------------------------------------+
input group "═══════════ Swing Detection ═══════════"
input int      Swing_Period = 5;                  // Swing Period (bars each side)
input int      Lookback_Bars = 100;               // Lookback Bars for Analysis
input int      Max_Swing_Points = 20;             // Max Swing Points to Show

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - STRUCTURE BREAK                                |
//+------------------------------------------------------------------+
input group "═══════════ Structure Break Settings ═══════════"
input int      Min_Break_Points = 30;             // Min Break Distance (points)
input bool     Require_Close_Break = true;        // Require Candle Close Beyond Level

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - VISUAL SETTINGS                                |
//+------------------------------------------------------------------+
input group "═══════════ Visual Settings ═══════════"
input bool     Show_Info_Panel = true;            // Show Info Panel
input bool     Show_Swing_Points = true;          // Show Swing Points (HH,HL,LH,LL)
input bool     Show_Structure_Lines = true;       // Show Structure Lines
input bool     Show_Break_Labels = true;          // Show BOS/CHoCH Labels
input bool     Show_Only_Latest = true;           // Show Only Latest (clean chart)
input int      Latest_Swings_Count = 3;           // How many latest swings to show (each type)

input group "═══════════ Colors ═══════════"
input color    Color_HH = clrDodgerBlue;          // Higher High Color
input color    Color_HL = clrLime;                // Higher Low Color
input color    Color_LH = clrOrangeRed;           // Lower High Color
input color    Color_LL = clrRed;                 // Lower Low Color
input color    Color_BOS_Bull = clrDodgerBlue;    // BOS Bullish Color
input color    Color_BOS_Bear = clrOrangeRed;     // BOS Bearish Color
input color    Color_CHoCH_Bull = clrLime;        // CHoCH Bullish Color
input color    Color_CHoCH_Bear = clrRed;         // CHoCH Bearish Color
input color    Color_Structure_Bull = clrDodgerBlue;  // Bullish Structure Line
input color    Color_Structure_Bear = clrOrangeRed;   // Bearish Structure Line

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  position;

// Market Structure
MarketStructure g_market;

// Arrays for swing points (separated for easier processing)
SwingPoint g_swing_highs[];
SwingPoint g_swing_lows[];
SwingPoint g_all_swings[];  // Combined and sorted by time

// Array for all structure breaks (BOS/CHoCH)
StructureBreak g_all_breaks[];

// Last bar time for new bar detection
datetime g_last_bar_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("══════════════════════════════════════════════════════════");
   Print("   SMC Strategy v2.1 - VISUAL EDITION");
   Print("══════════════════════════════════════════════════════════");
   
   // Set magic number
   trade.SetExpertMagicNumber(Magic_Number);
   
   // Initialize arrays
   ArrayResize(g_swing_highs, 0);
   ArrayResize(g_swing_lows, 0);
   ArrayResize(g_all_swings, 0);
   ArrayResize(g_all_breaks, 0);
   ArrayResize(g_market.swing_points, 0);
   
   // Initialize market structure
   g_market.current_bias = BIAS_NEUTRAL;
   g_market.swing_count = 0;
   g_market.last_break.type = BREAK_NONE;
   
   // Delete old objects
   ObjectsDeleteAll(0, "SMC_");
   
   // Initial full analysis
   FullMarketAnalysis();
   
   // Draw info panel
   if(Show_Info_Panel)
      DrawInfoPanel();
   
   Print("   Symbol: ", _Symbol);
   Print("   Timeframe: ", EnumToString((ENUM_TIMEFRAMES)Period()));
   Print("   Swing Period: ", Swing_Period);
   Print("══════════════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // In Strategy Tester - NEVER delete objects!
   // This keeps all drawings visible after backtest ends
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("Backtest ended - Objects KEPT on chart for analysis!");
      Print("Total objects: ", ObjectsTotal(0));
      return;  // EXIT - don't delete anything!
   }
   
   // Only delete when manually removed from live chart
   if(reason == REASON_REMOVE)
   {
      ObjectsDeleteAll(0, "SMC_");
      Comment("");
   }
   
   Print("SMC Strategy v2.1 - Stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Process on every new bar OR first tick
   static bool first_run = true;
   
   if(first_run || IsNewBar())
   {
      first_run = false;
      
      // Full market analysis
      FullMarketAnalysis();
      
      // Update info panel
      if(Show_Info_Panel)
         UpdateInfoPanel();
         
      // Force chart redraw
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| Full Market Analysis                                              |
//+------------------------------------------------------------------+
void FullMarketAnalysis()
{
   // Step 1: Find all swing points
   FindAllSwingPoints();
   
   // Step 2: Classify swing points (HH, HL, LH, LL)
   ClassifySwingPoints();
   
   // Step 3: Determine market bias
   DetermineMarketBias();
   
   // Step 4: Detect structure breaks (BOS / CHoCH)
   DetectStructureBreaks();
   
   // Step 5: Draw everything on chart
   DrawAllVisuals();
}

//+------------------------------------------------------------------+
//| Check for New Bar                                                 |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(current_bar_time != g_last_bar_time)
   {
      g_last_bar_time = current_bar_time;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if bar is Swing High                                        |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index, int period)
{
   if(index < period)
      return false;
   
   double high_value = iHigh(_Symbol, PERIOD_CURRENT, index);
   
   // Check left side (more recent bars)
   for(int i = 1; i <= period; i++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, index - i) >= high_value)
         return false;
   }
   
   // Check right side (older bars)
   for(int i = 1; i <= period; i++)
   {
      if(index + i >= Bars(_Symbol, PERIOD_CURRENT))
         return false;
      if(iHigh(_Symbol, PERIOD_CURRENT, index + i) >= high_value)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is Swing Low                                         |
//+------------------------------------------------------------------+
bool IsSwingLow(int index, int period)
{
   if(index < period)
      return false;
   
   double low_value = iLow(_Symbol, PERIOD_CURRENT, index);
   
   // Check left side (more recent bars)
   for(int i = 1; i <= period; i++)
   {
      if(iLow(_Symbol, PERIOD_CURRENT, index - i) <= low_value)
         return false;
   }
   
   // Check right side (older bars)
   for(int i = 1; i <= period; i++)
   {
      if(index + i >= Bars(_Symbol, PERIOD_CURRENT))
         return false;
      if(iLow(_Symbol, PERIOD_CURRENT, index + i) <= low_value)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Find All Swing Points                                             |
//+------------------------------------------------------------------+
void FindAllSwingPoints()
{
   // Clear arrays
   ArrayResize(g_swing_highs, 0);
   ArrayResize(g_swing_lows, 0);
   ArrayResize(g_all_swings, 0);
   
   int found_highs = 0;
   int found_lows = 0;
   
   // Find swing points
   for(int i = Swing_Period; i < Lookback_Bars - Swing_Period; i++)
   {
      // Check for swing high
      if(IsSwingHigh(i, Swing_Period))
      {
         SwingPoint sp;
         sp.price = iHigh(_Symbol, PERIOD_CURRENT, i);
         sp.time = iTime(_Symbol, PERIOD_CURRENT, i);
         sp.bar_index = i;
         sp.is_high = true;
         sp.swing_type = SWING_UNKNOWN;
         sp.is_broken = false;
         sp.label = "";
         
         int size = ArraySize(g_swing_highs);
         ArrayResize(g_swing_highs, size + 1);
         g_swing_highs[size] = sp;
         found_highs++;
      }
      
      // Check for swing low
      if(IsSwingLow(i, Swing_Period))
      {
         SwingPoint sp;
         sp.price = iLow(_Symbol, PERIOD_CURRENT, i);
         sp.time = iTime(_Symbol, PERIOD_CURRENT, i);
         sp.bar_index = i;
         sp.is_high = false;
         sp.swing_type = SWING_UNKNOWN;
         sp.is_broken = false;
         sp.label = "";
         
         int size = ArraySize(g_swing_lows);
         ArrayResize(g_swing_lows, size + 1);
         g_swing_lows[size] = sp;
         found_lows++;
      }
      
      // Limit swing points
      if(found_highs >= Max_Swing_Points && found_lows >= Max_Swing_Points)
         break;
   }
   
   // Combine all swings and sort by bar index (most recent first)
   CombineAndSortSwings();
   
   Print("Found ", found_highs, " Swing Highs, ", found_lows, " Swing Lows");
}

//+------------------------------------------------------------------+
//| Combine and Sort All Swings by Time                               |
//+------------------------------------------------------------------+
void CombineAndSortSwings()
{
   int total = ArraySize(g_swing_highs) + ArraySize(g_swing_lows);
   ArrayResize(g_all_swings, total);
   
   int idx = 0;
   
   // Add all highs
   for(int i = 0; i < ArraySize(g_swing_highs); i++)
   {
      g_all_swings[idx] = g_swing_highs[i];
      idx++;
   }
   
   // Add all lows
   for(int i = 0; i < ArraySize(g_swing_lows); i++)
   {
      g_all_swings[idx] = g_swing_lows[i];
      idx++;
   }
   
   // Sort by bar_index (ascending = most recent first since bar 0 is current)
   for(int i = 0; i < total - 1; i++)
   {
      for(int j = i + 1; j < total; j++)
      {
         if(g_all_swings[j].bar_index < g_all_swings[i].bar_index)
         {
            SwingPoint temp = g_all_swings[i];
            g_all_swings[i] = g_all_swings[j];
            g_all_swings[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Classify Swing Points (HH, HL, LH, LL)                            |
//+------------------------------------------------------------------+
void ClassifySwingPoints()
{
   // We need at least 2 highs and 2 lows for comparison
   int num_highs = ArraySize(g_swing_highs);
   int num_lows = ArraySize(g_swing_lows);
   
   // Classify Swing Highs
   // Array is sorted with most recent (lowest bar_index) first
   for(int i = 0; i < num_highs; i++)
   {
      if(i == num_highs - 1)
      {
         // Last (oldest) swing high - no comparison
         g_swing_highs[i].swing_type = SWING_UNKNOWN;
         g_swing_highs[i].label = "SH";
      }
      else
      {
         // Compare with previous (older) swing high
         double current_high = g_swing_highs[i].price;
         double previous_high = g_swing_highs[i + 1].price;
         
         if(current_high > previous_high)
         {
            g_swing_highs[i].swing_type = SWING_HH;
            g_swing_highs[i].label = "HH";
         }
         else
         {
            g_swing_highs[i].swing_type = SWING_LH;
            g_swing_highs[i].label = "LH";
         }
      }
   }
   
   // Classify Swing Lows
   for(int i = 0; i < num_lows; i++)
   {
      if(i == num_lows - 1)
      {
         // Last (oldest) swing low - no comparison
         g_swing_lows[i].swing_type = SWING_UNKNOWN;
         g_swing_lows[i].label = "SL";
      }
      else
      {
         // Compare with previous (older) swing low
         double current_low = g_swing_lows[i].price;
         double previous_low = g_swing_lows[i + 1].price;
         
         if(current_low > previous_low)
         {
            g_swing_lows[i].swing_type = SWING_HL;
            g_swing_lows[i].label = "HL";
         }
         else
         {
            g_swing_lows[i].swing_type = SWING_LL;
            g_swing_lows[i].label = "LL";
         }
      }
   }
   
   // Update combined array
   CombineAndSortSwings();
   
   // Copy classifications to combined array
   for(int i = 0; i < ArraySize(g_all_swings); i++)
   {
      if(g_all_swings[i].is_high)
      {
         // Find in highs array
         for(int j = 0; j < num_highs; j++)
         {
            if(g_all_swings[i].bar_index == g_swing_highs[j].bar_index)
            {
               g_all_swings[i].swing_type = g_swing_highs[j].swing_type;
               g_all_swings[i].label = g_swing_highs[j].label;
               break;
            }
         }
      }
      else
      {
         // Find in lows array
         for(int j = 0; j < num_lows; j++)
         {
            if(g_all_swings[i].bar_index == g_swing_lows[j].bar_index)
            {
               g_all_swings[i].swing_type = g_swing_lows[j].swing_type;
               g_all_swings[i].label = g_swing_lows[j].label;
               break;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Determine Market Bias                                             |
//+------------------------------------------------------------------+
void DetermineMarketBias()
{
   int num_highs = ArraySize(g_swing_highs);
   int num_lows = ArraySize(g_swing_lows);
   
   if(num_highs < 2 || num_lows < 2)
   {
      g_market.current_bias = BIAS_NEUTRAL;
      return;
   }
   
   // Get most recent swing high and low types
   ENUM_SWING_TYPE last_high_type = g_swing_highs[0].swing_type;
   ENUM_SWING_TYPE last_low_type = g_swing_lows[0].swing_type;
   
   // Bullish: HH + HL pattern
   // Bearish: LH + LL pattern
   
   if(last_high_type == SWING_HH && last_low_type == SWING_HL)
   {
      g_market.current_bias = BIAS_BULLISH;
   }
   else if(last_high_type == SWING_LH && last_low_type == SWING_LL)
   {
      g_market.current_bias = BIAS_BEARISH;
   }
   else
   {
      // Mixed signals - check previous bias or use majority
      int hh_count = 0, lh_count = 0;
      int hl_count = 0, ll_count = 0;
      
      for(int i = 0; i < MathMin(3, num_highs); i++)
      {
         if(g_swing_highs[i].swing_type == SWING_HH) hh_count++;
         else if(g_swing_highs[i].swing_type == SWING_LH) lh_count++;
      }
      
      for(int i = 0; i < MathMin(3, num_lows); i++)
      {
         if(g_swing_lows[i].swing_type == SWING_HL) hl_count++;
         else if(g_swing_lows[i].swing_type == SWING_LL) ll_count++;
      }
      
      if(hh_count + hl_count > lh_count + ll_count)
         g_market.current_bias = BIAS_BULLISH;
      else if(lh_count + ll_count > hh_count + hl_count)
         g_market.current_bias = BIAS_BEARISH;
      else
         g_market.current_bias = BIAS_NEUTRAL;
   }
   
   Print("Market Bias: ", EnumToString(g_market.current_bias));
}

//+------------------------------------------------------------------+
//| Detect Structure Breaks (BOS / CHoCH) - Historical Analysis       |
//+------------------------------------------------------------------+
void DetectStructureBreaks()
{
   g_market.last_break.type = BREAK_NONE;
   ArrayResize(g_all_breaks, 0);
   
   int num_swings = ArraySize(g_all_swings);
   if(num_swings < 4)
      return;
   
   // Track bias as we go through history (from oldest to newest)
   ENUM_MARKET_BIAS running_bias = BIAS_NEUTRAL;
   double last_significant_high = 0;
   double last_significant_low = 0;
   
   // Go through swings from oldest to newest (reverse order)
   for(int i = num_swings - 1; i >= 1; i--)
   {
      SwingPoint current = g_all_swings[i];
      
      // Update running highs/lows
      if(current.is_high)
         last_significant_high = current.price;
      else
         last_significant_low = current.price;
      
      // Look at next swing (more recent)
      SwingPoint next = g_all_swings[i - 1];
      
      // Check for break between these swings
      // We need to check if price between current and next swing broke any level
      
      // Find bars between current and next swing
      int start_bar = current.bar_index;
      int end_bar = next.bar_index;
      
      for(int bar = start_bar - 1; bar > end_bar; bar--)
      {
         double bar_high = iHigh(_Symbol, PERIOD_CURRENT, bar);
         double bar_low = iLow(_Symbol, PERIOD_CURRENT, bar);
         double bar_close = iClose(_Symbol, PERIOD_CURRENT, bar);
         datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, bar);
         
         // Check for bullish break (break above last significant high)
         if(last_significant_high > 0)
         {
            double break_price = Require_Close_Break ? bar_close : bar_high;
            if(break_price > last_significant_high)
            {
               double distance = (break_price - last_significant_high) / _Point;
               if(distance >= Min_Break_Points)
               {
                  // Check if this break already recorded
                  bool already_recorded = false;
                  for(int b = 0; b < ArraySize(g_all_breaks); b++)
                  {
                     if(MathAbs(g_all_breaks[b].break_level - last_significant_high) < _Point)
                     {
                        already_recorded = true;
                        break;
                     }
                  }
                  
                  if(!already_recorded)
                  {
                     StructureBreak brk;
                     brk.break_level = last_significant_high;
                     brk.break_price = break_price;
                     brk.break_time = bar_time;
                     brk.break_bar = bar;
                     brk.break_distance = distance;
                     
                     // Determine type based on running bias
                     if(running_bias == BIAS_BEARISH)
                     {
                        brk.type = BREAK_CHOCH_BULL;
                        running_bias = BIAS_BULLISH;  // Bias changes after CHoCH
                     }
                     else
                     {
                        brk.type = BREAK_BOS_BULL;
                     }
                     
                     // Add to array
                     int size = ArraySize(g_all_breaks);
                     ArrayResize(g_all_breaks, size + 1);
                     g_all_breaks[size] = brk;
                     
                     // Update last significant high
                     last_significant_high = break_price;
                  }
               }
            }
         }
         
         // Check for bearish break (break below last significant low)
         if(last_significant_low > 0)
         {
            double break_price = Require_Close_Break ? bar_close : bar_low;
            if(break_price < last_significant_low)
            {
               double distance = (last_significant_low - break_price) / _Point;
               if(distance >= Min_Break_Points)
               {
                  // Check if this break already recorded
                  bool already_recorded = false;
                  for(int b = 0; b < ArraySize(g_all_breaks); b++)
                  {
                     if(MathAbs(g_all_breaks[b].break_level - last_significant_low) < _Point)
                     {
                        already_recorded = true;
                        break;
                     }
                  }
                  
                  if(!already_recorded)
                  {
                     StructureBreak brk;
                     brk.break_level = last_significant_low;
                     brk.break_price = break_price;
                     brk.break_time = bar_time;
                     brk.break_bar = bar;
                     brk.break_distance = distance;
                     
                     // Determine type based on running bias
                     if(running_bias == BIAS_BULLISH)
                     {
                        brk.type = BREAK_CHOCH_BEAR;
                        running_bias = BIAS_BEARISH;  // Bias changes after CHoCH
                     }
                     else
                     {
                        brk.type = BREAK_BOS_BEAR;
                     }
                     
                     // Add to array
                     int size = ArraySize(g_all_breaks);
                     ArrayResize(g_all_breaks, size + 1);
                     g_all_breaks[size] = brk;
                     
                     // Update last significant low
                     last_significant_low = break_price;
                  }
               }
            }
         }
      }
      
      // Update running bias based on swing types
      if(current.swing_type == SWING_HH || current.swing_type == SWING_HL)
         running_bias = BIAS_BULLISH;
      else if(current.swing_type == SWING_LH || current.swing_type == SWING_LL)
         running_bias = BIAS_BEARISH;
   }
   
   // Sort breaks by bar_index (most recent first)
   int total_breaks = ArraySize(g_all_breaks);
   for(int i = 0; i < total_breaks - 1; i++)
   {
      for(int j = i + 1; j < total_breaks; j++)
      {
         if(g_all_breaks[j].break_bar < g_all_breaks[i].break_bar)
         {
            StructureBreak temp = g_all_breaks[i];
            g_all_breaks[i] = g_all_breaks[j];
            g_all_breaks[j] = temp;
         }
      }
   }
   
   // Set last break
   if(total_breaks > 0)
      g_market.last_break = g_all_breaks[0];
   
   Print("Found ", total_breaks, " Structure Breaks (BOS/CHoCH)");
}

//+------------------------------------------------------------------+
//| Draw All Visuals on Chart                                         |
//+------------------------------------------------------------------+
void DrawAllVisuals()
{
   // If Show_Only_Latest - delete old objects first for clean chart
   if(Show_Only_Latest)
   {
      ObjectsDeleteAll(0, "SMC_H_");
      ObjectsDeleteAll(0, "SMC_L_");
      ObjectsDeleteAll(0, "SMC_LINE_");
      ObjectsDeleteAll(0, "SMC_BRK_");
   }
   
   // Draw swing points with labels
   if(Show_Swing_Points)
      DrawSwingPointsWithLabels();
   
   // Draw structure lines connecting swings
   if(Show_Structure_Lines)
      DrawStructureLines();
   
   // Draw break labels (BOS/CHoCH) - draw all breaks
   if(Show_Break_Labels)
      DrawAllBreakLabels();
}

//+------------------------------------------------------------------+
//| Draw Swing Points with Labels (HH, HL, LH, LL)                    |
//+------------------------------------------------------------------+
void DrawSwingPointsWithLabels()
{
   // Determine how many swings to show
   int max_to_show = Show_Only_Latest ? Latest_Swings_Count : Max_Swing_Points;
   
   // Draw Swing Highs (only latest if Show_Only_Latest is true)
   int highs_to_draw = MathMin(ArraySize(g_swing_highs), max_to_show);
   for(int i = 0; i < highs_to_draw; i++)
   {
      SwingPoint sp = g_swing_highs[i];
      
      // Determine color based on type
      color point_color = Color_HH;
      if(sp.swing_type == SWING_LH)
         point_color = Color_LH;
      
      // Draw arrow
      string arrow_name = "SMC_H_" + IntegerToString(i) + "_arr";
      ObjectDelete(0, arrow_name);  // Delete old first
      ObjectCreate(0, arrow_name, OBJ_ARROW_DOWN, 0, sp.time, sp.price);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, point_color);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, arrow_name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, 234);
      ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, false);
      
      // Draw label
      string label_name = "SMC_H_" + IntegerToString(i) + "_lbl";
      double label_price = sp.price + 50 * _Point;
      
      ObjectDelete(0, label_name);
      ObjectCreate(0, label_name, OBJ_TEXT, 0, sp.time, label_price);
      ObjectSetString(0, label_name, OBJPROP_TEXT, sp.label);
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, point_color);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, label_name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
      
      // Draw horizontal line from swing point to current bar
      string hline_name = "SMC_H_" + IntegerToString(i) + "_line";
      datetime end_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      
      ObjectDelete(0, hline_name);
      ObjectCreate(0, hline_name, OBJ_TREND, 0, sp.time, sp.price, end_time, sp.price);
      ObjectSetInteger(0, hline_name, OBJPROP_COLOR, point_color);
      ObjectSetInteger(0, hline_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, hline_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, hline_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, hline_name, OBJPROP_BACK, true);
   }
   
   // Draw Swing Lows (only latest if Show_Only_Latest is true)
   int lows_to_draw = MathMin(ArraySize(g_swing_lows), max_to_show);
   for(int i = 0; i < lows_to_draw; i++)
   {
      SwingPoint sp = g_swing_lows[i];
      
      // Determine color based on type
      color point_color = Color_HL;
      if(sp.swing_type == SWING_LL)
         point_color = Color_LL;
      
      // Draw arrow
      string arrow_name = "SMC_L_" + IntegerToString(i) + "_arr";
      ObjectDelete(0, arrow_name);
      ObjectCreate(0, arrow_name, OBJ_ARROW_UP, 0, sp.time, sp.price);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, point_color);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, arrow_name, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, 233);
      ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, false);
      
      // Draw label
      string label_name = "SMC_L_" + IntegerToString(i) + "_lbl";
      double label_price = sp.price - 50 * _Point;
      
      ObjectDelete(0, label_name);
      ObjectCreate(0, label_name, OBJ_TEXT, 0, sp.time, label_price);
      ObjectSetString(0, label_name, OBJPROP_TEXT, sp.label);
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, point_color);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, label_name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_UPPER);
      ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
      
      // Draw horizontal line
      string hline_name = "SMC_L_" + IntegerToString(i) + "_line";
      datetime end_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      
      ObjectDelete(0, hline_name);
      ObjectCreate(0, hline_name, OBJ_TREND, 0, sp.time, sp.price, end_time, sp.price);
      ObjectSetInteger(0, hline_name, OBJPROP_COLOR, point_color);
      ObjectSetInteger(0, hline_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, hline_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, hline_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, hline_name, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Draw Structure Lines Connecting Swings                            |
//+------------------------------------------------------------------+
void DrawStructureLines()
{
   int num_swings = ArraySize(g_all_swings);
   if(num_swings < 2)
      return;
   
   // How many lines to draw
   int max_lines = Show_Only_Latest ? (Latest_Swings_Count * 2) : Max_Swing_Points;
   int lines_drawn = 0;
   
   // Connect alternating highs and lows to show structure
   for(int i = 0; i < num_swings - 1 && lines_drawn < max_lines; i++)
   {
      SwingPoint current = g_all_swings[i];
      SwingPoint next = g_all_swings[i + 1];
      
      // Only connect if they are different (high to low or low to high)
      if(current.is_high != next.is_high)
      {
         string line_name = "SMC_LINE_" + IntegerToString(lines_drawn);
         
         // Color based on direction
         color line_color = Color_Structure_Bull;
         if(current.is_high && !next.is_high)
         {
            // High to Low (downward move)
            line_color = Color_Structure_Bear;
         }
         else
         {
            // Low to High (upward move)
            line_color = Color_Structure_Bull;
         }
         
         ObjectDelete(0, line_name);
         ObjectCreate(0, line_name, OBJ_TREND, 0, 
                      next.time, next.price,    // Start from older point
                      current.time, current.price);  // To newer point
         ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
         ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
         
         lines_drawn++;
      }
   }
}

//+------------------------------------------------------------------+
//| Draw All Break Labels (BOS / CHoCH)                               |
//+------------------------------------------------------------------+
void DrawAllBreakLabels()
{
   int total_breaks = ArraySize(g_all_breaks);
   if(total_breaks == 0)
      return;
   
   // Determine how many breaks to show
   int max_to_show = Show_Only_Latest ? Latest_Swings_Count : total_breaks;
   int breaks_to_draw = MathMin(total_breaks, max_to_show);
   
   for(int i = 0; i < breaks_to_draw; i++)
   {
      StructureBreak brk = g_all_breaks[i];
      
      string label_text = "";
      color label_color = clrWhite;
      
      switch(brk.type)
      {
         case BREAK_BOS_BULL:
            label_text = "BOS ▲";
            label_color = Color_BOS_Bull;
            break;
         case BREAK_BOS_BEAR:
            label_text = "BOS ▼";
            label_color = Color_BOS_Bear;
            break;
         case BREAK_CHOCH_BULL:
            label_text = "★ CHoCH ▲";
            label_color = Color_CHoCH_Bull;
            break;
         case BREAK_CHOCH_BEAR:
            label_text = "★ CHoCH ▼";
            label_color = Color_CHoCH_Bear;
            break;
         default:
            continue;
      }
      
      // Draw break line
      string line_name = "SMC_BRK_LINE_" + IntegerToString(i);
      datetime end_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      
      ObjectDelete(0, line_name);
      ObjectCreate(0, line_name, OBJ_TREND, 0, brk.break_time, brk.break_level, end_time, brk.break_level);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, label_color);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
      
      // Draw label
      string text_name = "SMC_BRK_TXT_" + IntegerToString(i);
      double label_price = brk.break_level;
      
      ObjectDelete(0, text_name);
      ObjectCreate(0, text_name, OBJ_TEXT, 0, brk.break_time, label_price);
      ObjectSetString(0, text_name, OBJPROP_TEXT, label_text);
      ObjectSetInteger(0, text_name, OBJPROP_COLOR, label_color);
      ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, text_name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      
      // Draw arrow at break point
      string arrow_name = "SMC_BRK_ARW_" + IntegerToString(i);
      int arrow_code = (brk.type == BREAK_BOS_BULL || brk.type == BREAK_CHOCH_BULL) ? 233 : 234;
      
      ObjectDelete(0, arrow_name);
      ObjectCreate(0, arrow_name, OBJ_ARROW, 0, brk.break_time, brk.break_price);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, label_color);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
   }
}

//+------------------------------------------------------------------+
//| Draw Info Panel                                                   |
//+------------------------------------------------------------------+
void DrawInfoPanel()
{
   string panel_name = "SMC_Panel";
   
   // Background
   ObjectCreate(0, panel_name + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_YDISTANCE, 25);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_XSIZE, 280);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_YSIZE, 200);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_BGCOLOR, C'20,20,30');
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_WIDTH, 2);
   
   // Title
   CreatePanelLabel(panel_name + "_Title", "═══ SMC STRATEGY v2.1 ═══", 20, 30, clrGold, 11);
   
   // Market Bias
   CreatePanelLabel(panel_name + "_BiasLbl", "Market Bias:", 20, 55, clrWhite, 10);
   CreatePanelLabel(panel_name + "_BiasVal", "---", 140, 55, clrYellow, 10);
   
   // Last High
   CreatePanelLabel(panel_name + "_HighLbl", "Last Swing High:", 20, 80, clrWhite, 10);
   CreatePanelLabel(panel_name + "_HighVal", "---", 140, 80, Color_HH, 10);
   
   // Last Low
   CreatePanelLabel(panel_name + "_LowLbl", "Last Swing Low:", 20, 105, clrWhite, 10);
   CreatePanelLabel(panel_name + "_LowVal", "---", 140, 105, Color_HL, 10);
   
   // Structure Break
   CreatePanelLabel(panel_name + "_BreakLbl", "Last Break:", 20, 130, clrWhite, 10);
   CreatePanelLabel(panel_name + "_BreakVal", "---", 140, 130, clrYellow, 10);
   
   // Swing Counts
   CreatePanelLabel(panel_name + "_CountLbl", "Swings Found:", 20, 155, clrWhite, 10);
   CreatePanelLabel(panel_name + "_CountVal", "---", 140, 155, clrCyan, 10);
   
   // Legend
   CreatePanelLabel(panel_name + "_Legend", "HH=Blue HL=Green LH=Orange LL=Red", 20, 185, clrGray, 8);
}

//+------------------------------------------------------------------+
//| Create Panel Label Helper                                         |
//+------------------------------------------------------------------+
void CreatePanelLabel(string name, string text, int x, int y, color clr, int font_size)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Update Info Panel                                                 |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   string panel_name = "SMC_Panel";
   
   // Update Market Bias
   string bias_str = "NEUTRAL";
   color bias_color = clrYellow;
   
   if(g_market.current_bias == BIAS_BULLISH)
   {
      bias_str = "▲ BULLISH";
      bias_color = clrLime;
   }
   else if(g_market.current_bias == BIAS_BEARISH)
   {
      bias_str = "▼ BEARISH";
      bias_color = clrRed;
   }
   
   ObjectSetString(0, panel_name + "_BiasVal", OBJPROP_TEXT, bias_str);
   ObjectSetInteger(0, panel_name + "_BiasVal", OBJPROP_COLOR, bias_color);
   
   // Update Last Swing High
   if(ArraySize(g_swing_highs) > 0)
   {
      string high_text = g_swing_highs[0].label + " @ " + DoubleToString(g_swing_highs[0].price, _Digits);
      color high_color = (g_swing_highs[0].swing_type == SWING_HH) ? Color_HH : Color_LH;
      ObjectSetString(0, panel_name + "_HighVal", OBJPROP_TEXT, high_text);
      ObjectSetInteger(0, panel_name + "_HighVal", OBJPROP_COLOR, high_color);
   }
   
   // Update Last Swing Low
   if(ArraySize(g_swing_lows) > 0)
   {
      string low_text = g_swing_lows[0].label + " @ " + DoubleToString(g_swing_lows[0].price, _Digits);
      color low_color = (g_swing_lows[0].swing_type == SWING_HL) ? Color_HL : Color_LL;
      ObjectSetString(0, panel_name + "_LowVal", OBJPROP_TEXT, low_text);
      ObjectSetInteger(0, panel_name + "_LowVal", OBJPROP_COLOR, low_color);
   }
   
   // Update Structure Break
   string break_str = "None";
   color break_color = clrGray;
   
   switch(g_market.last_break.type)
   {
      case BREAK_BOS_BULL:
         break_str = "BOS ▲";
         break_color = Color_BOS_Bull;
         break;
      case BREAK_BOS_BEAR:
         break_str = "BOS ▼";
         break_color = Color_BOS_Bear;
         break;
      case BREAK_CHOCH_BULL:
         break_str = "★ CHoCH ▲";
         break_color = Color_CHoCH_Bull;
         break;
      case BREAK_CHOCH_BEAR:
         break_str = "★ CHoCH ▼";
         break_color = Color_CHoCH_Bear;
         break;
   }
   
   ObjectSetString(0, panel_name + "_BreakVal", OBJPROP_TEXT, break_str);
   ObjectSetInteger(0, panel_name + "_BreakVal", OBJPROP_COLOR, break_color);
   
   // Update Swing Count
   string count_str = IntegerToString(ArraySize(g_swing_highs)) + " H / " + 
                      IntegerToString(ArraySize(g_swing_lows)) + " L";
   ObjectSetString(0, panel_name + "_CountVal", OBJPROP_TEXT, count_str);
}
//+------------------------------------------------------------------+
