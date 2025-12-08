//+------------------------------------------------------------------+
//|                                         SMC_Strategy_v2_Pro.mq5 |
//|                         Smart Money Concepts Trading Strategy    |
//|                                    Version 4.0 - Correct CHoCH   |
//+------------------------------------------------------------------+
#property copyright "SMC Strategy v4.0"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "4.00"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+
enum ENUM_TREND_STATE
{
   TREND_BULLISH,        // Bullish (HH + HL sequence)
   TREND_BEARISH,        // Bearish (LH + LL sequence)
   TREND_NEUTRAL         // Neutral (no clear structure)
};

enum ENUM_SWING_TYPE
{
   SWING_HH,             // Higher High
   SWING_HL,             // Higher Low
   SWING_LH,             // Lower High
   SWING_LL,             // Lower Low
   SWING_HIGH,           // Unclassified High
   SWING_LOW             // Unclassified Low
};

enum ENUM_BREAK_TYPE
{
   BREAK_NONE,           // No Break
   BREAK_BOS_BULL,       // BOS Bullish (continuation - broke previous high)
   BREAK_BOS_BEAR,       // BOS Bearish (continuation - broke previous low)
   BREAK_CHOCH_BULL,     // CHoCH Bullish (reversal - broke the LH that created last LL)
   BREAK_CHOCH_BEAR      // CHoCH Bearish (reversal - broke the HL that created last HH)
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double            price;
   datetime          time;
   int               bar_index;
   bool              is_high;
   ENUM_SWING_TYPE   swing_type;
   bool              is_valid;        // Is this swing still valid (not broken)?
   bool              caused_bos;      // Did this swing cause a BOS?
};

struct StructureBreak
{
   ENUM_BREAK_TYPE   type;
   double            break_level;     // The level that was broken
   double            break_price;     // The close price that broke it
   datetime          break_time;
   int               break_bar;
   datetime          level_time;      // Time of the level that was broken
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "═══════════ General Settings ═══════════"
input int      Magic_Number = 12345;              // Magic Number

input group "═══════════ Swing Detection ═══════════"
input int      Swing_Period = 5;                  // Swing Period (bars each side)
input int      Lookback_Bars = 200;               // Lookback Bars for Analysis

input group "═══════════ Visual Settings ═══════════"
input bool     Show_Info_Panel = true;            // Show Info Panel
input bool     Show_Swing_Points = true;          // Show Swing Points (HH/HL/LH/LL)
input bool     Show_Structure_Lines = true;       // Show Structure Lines
input bool     Show_Break_Labels = true;          // Show BOS/CHoCH Labels
input bool     Show_Only_Latest = true;           // Show Only Latest (clean chart)
input int      Latest_Count = 5;                  // How many latest to show

input group "═══════════ Colors ═══════════"
input color    Color_HH = clrDodgerBlue;          // Higher High Color
input color    Color_HL = clrLime;                // Higher Low Color
input color    Color_LH = clrOrangeRed;           // Lower High Color
input color    Color_LL = clrRed;                 // Lower Low Color
input color    Color_BOS_Bull = clrDodgerBlue;    // BOS Bullish Color
input color    Color_BOS_Bear = clrOrangeRed;     // BOS Bearish Color
input color    Color_CHoCH_Bull = clrLime;        // CHoCH Bullish Color
input color    Color_CHoCH_Bear = clrRed;         // CHoCH Bearish Color

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade trade;

// Current Trend State
ENUM_TREND_STATE g_trendState = TREND_NEUTRAL;

// Arrays
SwingPoint g_swings[];              // All swing points (ordered oldest to newest during processing)
StructureBreak g_breaks[];          // All BOS/CHoCH breaks

// Key structural points for CHoCH detection
// In Bullish: The HL that pushed price to make the last HH
// In Bearish: The LH that pushed price to make the last LL
SwingPoint g_choch_level_bull;      // The HL to watch for bearish CHoCH
SwingPoint g_choch_level_bear;      // The LH to watch for bullish CHoCH

// Last structural points
double g_lastHH = 0;
datetime g_lastHH_time = 0;
double g_lastHL = 0;
datetime g_lastHL_time = 0;
double g_lastLH = 0;
datetime g_lastLH_time = 0;
double g_lastLL = 0;
datetime g_lastLL_time = 0;

// Last bar time
datetime g_last_bar_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("══════════════════════════════════════════════════════════");
   Print("   SMC Strategy v4.0 - CORRECT CHoCH LOGIC");
   Print("   CHoCH = Break of the swing that CAUSED the last BOS");
   Print("══════════════════════════════════════════════════════════");
   
   trade.SetExpertMagicNumber(Magic_Number);
   
   ArrayResize(g_swings, 0);
   ArrayResize(g_breaks, 0);
   
   ResetAll();
   
   ObjectsDeleteAll(0, "SMC_");
   
   FullMarketAnalysis();
   
   if(Show_Info_Panel)
      DrawInfoPanel();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Reset All Variables                                               |
//+------------------------------------------------------------------+
void ResetAll()
{
   g_trendState = TREND_NEUTRAL;
   
   g_lastHH = 0; g_lastHH_time = 0;
   g_lastHL = 0; g_lastHL_time = 0;
   g_lastLH = 0; g_lastLH_time = 0;
   g_lastLL = 0; g_lastLL_time = 0;
   
   // Reset CHoCH levels
   g_choch_level_bull.price = 0;
   g_choch_level_bull.time = 0;
   g_choch_level_bull.is_valid = false;
   
   g_choch_level_bear.price = 0;
   g_choch_level_bear.time = 0;
   g_choch_level_bear.is_valid = false;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("Backtest ended - Objects preserved!");
      return;
   }
   
   if(reason == REASON_REMOVE)
   {
      ObjectsDeleteAll(0, "SMC_");
      Comment("");
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static bool first_run = true;
   
   if(first_run || IsNewBar())
   {
      first_run = false;
      FullMarketAnalysis();
      
      if(Show_Info_Panel)
         UpdateInfoPanel();
      
      ChartRedraw(0);
   }
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
//| MAIN ANALYSIS FUNCTION                                            |
//+------------------------------------------------------------------+
void FullMarketAnalysis()
{
   // Step 1: Find all raw swing points
   FindSwingPoints();
   
   // Step 2: Build structure and detect breaks
   BuildStructure();
   
   // Step 3: Draw everything
   DrawAllVisuals();
}

//+------------------------------------------------------------------+
//| Find Swing Points                                                 |
//+------------------------------------------------------------------+
void FindSwingPoints()
{
   ArrayResize(g_swings, 0);
   
   for(int i = Swing_Period; i < Lookback_Bars - Swing_Period; i++)
   {
      // Check for Swing High
      if(IsSwingHigh(i))
      {
         SwingPoint sp;
         sp.price = iHigh(_Symbol, PERIOD_CURRENT, i);
         sp.time = iTime(_Symbol, PERIOD_CURRENT, i);
         sp.bar_index = i;
         sp.is_high = true;
         sp.swing_type = SWING_HIGH;
         sp.is_valid = true;
         sp.caused_bos = false;
         
         int size = ArraySize(g_swings);
         ArrayResize(g_swings, size + 1);
         g_swings[size] = sp;
      }
      
      // Check for Swing Low
      if(IsSwingLow(i))
      {
         SwingPoint sp;
         sp.price = iLow(_Symbol, PERIOD_CURRENT, i);
         sp.time = iTime(_Symbol, PERIOD_CURRENT, i);
         sp.bar_index = i;
         sp.is_high = false;
         sp.swing_type = SWING_LOW;
         sp.is_valid = true;
         sp.caused_bos = false;
         
         int size = ArraySize(g_swings);
         ArrayResize(g_swings, size + 1);
         g_swings[size] = sp;
      }
   }
   
   // Sort by bar_index descending (oldest first = highest bar_index first)
   SortSwingsOldestFirst();
}

//+------------------------------------------------------------------+
//| Check if bar is Swing High                                        |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index)
{
   if(index < Swing_Period) return false;
   
   double high = iHigh(_Symbol, PERIOD_CURRENT, index);
   
   for(int i = 1; i <= Swing_Period; i++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, index - i) >= high) return false;
      if(index + i >= Bars(_Symbol, PERIOD_CURRENT)) return false;
      if(iHigh(_Symbol, PERIOD_CURRENT, index + i) >= high) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is Swing Low                                         |
//+------------------------------------------------------------------+
bool IsSwingLow(int index)
{
   if(index < Swing_Period) return false;
   
   double low = iLow(_Symbol, PERIOD_CURRENT, index);
   
   for(int i = 1; i <= Swing_Period; i++)
   {
      if(iLow(_Symbol, PERIOD_CURRENT, index - i) <= low) return false;
      if(index + i >= Bars(_Symbol, PERIOD_CURRENT)) return false;
      if(iLow(_Symbol, PERIOD_CURRENT, index + i) <= low) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Sort swings oldest first (highest bar_index first)                |
//+------------------------------------------------------------------+
void SortSwingsOldestFirst()
{
   int total = ArraySize(g_swings);
   for(int i = 0; i < total - 1; i++)
   {
      for(int j = i + 1; j < total; j++)
      {
         if(g_swings[j].bar_index > g_swings[i].bar_index)
         {
            SwingPoint temp = g_swings[i];
            g_swings[i] = g_swings[j];
            g_swings[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BUILD STRUCTURE - THE CORE LOGIC                                  |
//| CHoCH = Breaking the swing that CAUSED the last BOS               |
//+------------------------------------------------------------------+
void BuildStructure()
{
   ArrayResize(g_breaks, 0);
   ResetAll();
   
   int total = ArraySize(g_swings);
   if(total < 3) return;
   
   // Track the swing that caused the last BOS
   SwingPoint swing_that_caused_last_bullish_bos;  // The HL before last HH
   SwingPoint swing_that_caused_last_bearish_bos;  // The LH before last LL
   swing_that_caused_last_bullish_bos.price = 0;
   swing_that_caused_last_bearish_bos.price = 0;
   
   // Previous swing for comparison
   SwingPoint prev_high;
   SwingPoint prev_low;
   prev_high.price = 0;
   prev_low.price = 0;
   
   // The swing immediately before current (to track what caused BOS)
   SwingPoint last_low_before_high;
   SwingPoint last_high_before_low;
   last_low_before_high.price = 0;
   last_high_before_low.price = 0;
   
   // Process swings from oldest to newest
   for(int i = 0; i < total; i++)
   {
      SwingPoint current = g_swings[i];
      
      if(current.is_high)
      {
         // ═══════════════════════════════════════════════════════════
         // PROCESSING A HIGH
         // ═══════════════════════════════════════════════════════════
         
         // First, check if this high breaks above previous high (potential BOS Bull)
         if(prev_high.price > 0)
         {
            // Check for close above previous high between prev_high and current
            int break_bar = FindBreakBarByClose(current.bar_index, prev_high.time, prev_high.price, true);
            
            if(break_bar > 0)
            {
               // ═══ BULLISH BOS ═══
               // Price closed above previous high = trend continuation
               
               if(g_trendState == TREND_BEARISH)
               {
                  // ═══ BULLISH CHoCH ═══
                  // We were bearish, now breaking the last LH = CHoCH!
                  // But CHoCH should break the LH that caused the last LL
                  
                  if(swing_that_caused_last_bearish_bos.price > 0)
                  {
                     // Check if we broke above that specific LH
                     int choch_bar = FindBreakBarByClose(current.bar_index, 
                                                          swing_that_caused_last_bearish_bos.time,
                                                          swing_that_caused_last_bearish_bos.price, true);
                     if(choch_bar > 0)
                     {
                        StructureBreak brk;
                        brk.type = BREAK_CHOCH_BULL;
                        brk.break_level = swing_that_caused_last_bearish_bos.price;
                        brk.break_price = iClose(_Symbol, PERIOD_CURRENT, choch_bar);
                        brk.break_time = iTime(_Symbol, PERIOD_CURRENT, choch_bar);
                        brk.break_bar = choch_bar;
                        brk.level_time = swing_that_caused_last_bearish_bos.time;
                        
                        int brk_size = ArraySize(g_breaks);
                        ArrayResize(g_breaks, brk_size + 1);
                        g_breaks[brk_size] = brk;
                        
                        Print("═══ CHoCH BULLISH @ ", brk.break_level, " ═══");
                     }
                  }
                  
                  g_trendState = TREND_BULLISH;
               }
               else
               {
                  // Already bullish or neutral - this is BOS
                  StructureBreak brk;
                  brk.type = BREAK_BOS_BULL;
                  brk.break_level = prev_high.price;
                  brk.break_price = iClose(_Symbol, PERIOD_CURRENT, break_bar);
                  brk.break_time = iTime(_Symbol, PERIOD_CURRENT, break_bar);
                  brk.break_bar = break_bar;
                  brk.level_time = prev_high.time;
                  
                  int brk_size = ArraySize(g_breaks);
                  ArrayResize(g_breaks, brk_size + 1);
                  g_breaks[brk_size] = brk;
                  
                  g_trendState = TREND_BULLISH;
               }
               
               // This is now HH
               g_swings[i].swing_type = SWING_HH;
               g_swings[i].caused_bos = true;
               
               g_lastHH = current.price;
               g_lastHH_time = current.time;
               
               // ★★★ KEY: Save the LOW that caused this HH for future CHoCH detection ★★★
               if(last_low_before_high.price > 0)
               {
                  swing_that_caused_last_bullish_bos = last_low_before_high;
                  swing_that_caused_last_bullish_bos.swing_type = SWING_HL;
                  
                  // Also update g_lastHL
                  g_lastHL = last_low_before_high.price;
                  g_lastHL_time = last_low_before_high.time;
                  
                  // Mark that low as HL
                  for(int k = 0; k < total; k++)
                  {
                     if(g_swings[k].time == last_low_before_high.time && !g_swings[k].is_high)
                     {
                        g_swings[k].swing_type = SWING_HL;
                        break;
                     }
                  }
               }
            }
            else
            {
               // No BOS - this is a Lower High (in bearish) or internal high
               if(current.price < prev_high.price)
               {
                  if(g_trendState == TREND_BEARISH || g_trendState == TREND_NEUTRAL)
                  {
                     g_swings[i].swing_type = SWING_LH;
                     g_lastLH = current.price;
                     g_lastLH_time = current.time;
                  }
               }
            }
         }
         else
         {
            // First high
            g_swings[i].swing_type = SWING_HIGH;
         }
         
         // Update tracking
         prev_high = g_swings[i];
         last_high_before_low = g_swings[i];
      }
      else
      {
         // ═══════════════════════════════════════════════════════════
         // PROCESSING A LOW
         // ═══════════════════════════════════════════════════════════
         
         // First, check if this low breaks below previous low (potential BOS Bear)
         if(prev_low.price > 0)
         {
            // Check for close below previous low
            int break_bar = FindBreakBarByClose(current.bar_index, prev_low.time, prev_low.price, false);
            
            if(break_bar > 0)
            {
               // ═══ BEARISH BOS ═══
               
               if(g_trendState == TREND_BULLISH)
               {
                  // ═══ BEARISH CHoCH ═══
                  // We were bullish, now breaking the last HL = CHoCH!
                  // CHoCH should break the HL that caused the last HH
                  
                  if(swing_that_caused_last_bullish_bos.price > 0)
                  {
                     // Check if we broke below that specific HL
                     int choch_bar = FindBreakBarByClose(current.bar_index,
                                                          swing_that_caused_last_bullish_bos.time,
                                                          swing_that_caused_last_bullish_bos.price, false);
                     if(choch_bar > 0)
                     {
                        StructureBreak brk;
                        brk.type = BREAK_CHOCH_BEAR;
                        brk.break_level = swing_that_caused_last_bullish_bos.price;
                        brk.break_price = iClose(_Symbol, PERIOD_CURRENT, choch_bar);
                        brk.break_time = iTime(_Symbol, PERIOD_CURRENT, choch_bar);
                        brk.break_bar = choch_bar;
                        brk.level_time = swing_that_caused_last_bullish_bos.time;
                        
                        int brk_size = ArraySize(g_breaks);
                        ArrayResize(g_breaks, brk_size + 1);
                        g_breaks[brk_size] = brk;
                        
                        Print("═══ CHoCH BEARISH @ ", brk.break_level, " ═══");
                     }
                  }
                  
                  g_trendState = TREND_BEARISH;
               }
               else
               {
                  // Already bearish or neutral - this is BOS
                  StructureBreak brk;
                  brk.type = BREAK_BOS_BEAR;
                  brk.break_level = prev_low.price;
                  brk.break_price = iClose(_Symbol, PERIOD_CURRENT, break_bar);
                  brk.break_time = iTime(_Symbol, PERIOD_CURRENT, break_bar);
                  brk.break_bar = break_bar;
                  brk.level_time = prev_low.time;
                  
                  int brk_size = ArraySize(g_breaks);
                  ArrayResize(g_breaks, brk_size + 1);
                  g_breaks[brk_size] = brk;
                  
                  g_trendState = TREND_BEARISH;
               }
               
               // This is now LL
               g_swings[i].swing_type = SWING_LL;
               g_swings[i].caused_bos = true;
               
               g_lastLL = current.price;
               g_lastLL_time = current.time;
               
               // ★★★ KEY: Save the HIGH that caused this LL for future CHoCH detection ★★★
               if(last_high_before_low.price > 0)
               {
                  swing_that_caused_last_bearish_bos = last_high_before_low;
                  swing_that_caused_last_bearish_bos.swing_type = SWING_LH;
                  
                  // Also update g_lastLH
                  g_lastLH = last_high_before_low.price;
                  g_lastLH_time = last_high_before_low.time;
                  
                  // Mark that high as LH
                  for(int k = 0; k < total; k++)
                  {
                     if(g_swings[k].time == last_high_before_low.time && g_swings[k].is_high)
                     {
                        g_swings[k].swing_type = SWING_LH;
                        break;
                     }
                  }
               }
            }
            else
            {
               // No BOS - this is a Higher Low (in bullish) or internal low
               if(current.price > prev_low.price)
               {
                  if(g_trendState == TREND_BULLISH || g_trendState == TREND_NEUTRAL)
                  {
                     g_swings[i].swing_type = SWING_HL;
                     g_lastHL = current.price;
                     g_lastHL_time = current.time;
                  }
               }
            }
         }
         else
         {
            // First low
            g_swings[i].swing_type = SWING_LOW;
         }
         
         // Update tracking
         prev_low = g_swings[i];
         last_low_before_high = g_swings[i];
      }
   }
   
   // Sort swings by bar_index ascending (most recent first) for drawing
   SortSwingsNewestFirst();
   
   // Sort breaks
   SortBreaksNewestFirst();
   
   Print("Trend: ", EnumToString(g_trendState), 
         " | Swings: ", ArraySize(g_swings),
         " | Breaks: ", ArraySize(g_breaks));
}

//+------------------------------------------------------------------+
//| Find bar where CLOSE price breaks a level                         |
//| Returns bar index if found, 0 if not                              |
//+------------------------------------------------------------------+
int FindBreakBarByClose(int swing_bar, datetime level_time, double level_price, bool break_above)
{
   int level_bar = iBarShift(_Symbol, PERIOD_CURRENT, level_time);
   
   // Search from level_bar towards swing_bar (more recent)
   for(int bar = level_bar - 1; bar >= swing_bar; bar--)
   {
      if(bar < 0) break;
      
      double close = iClose(_Symbol, PERIOD_CURRENT, bar);
      
      if(break_above && close > level_price)
         return bar;
      
      if(!break_above && close < level_price)
         return bar;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Sort swings newest first (lowest bar_index first)                 |
//+------------------------------------------------------------------+
void SortSwingsNewestFirst()
{
   int total = ArraySize(g_swings);
   for(int i = 0; i < total - 1; i++)
   {
      for(int j = i + 1; j < total; j++)
      {
         if(g_swings[j].bar_index < g_swings[i].bar_index)
         {
            SwingPoint temp = g_swings[i];
            g_swings[i] = g_swings[j];
            g_swings[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Sort breaks newest first                                          |
//+------------------------------------------------------------------+
void SortBreaksNewestFirst()
{
   int total = ArraySize(g_breaks);
   for(int i = 0; i < total - 1; i++)
   {
      for(int j = i + 1; j < total; j++)
      {
         if(g_breaks[j].break_bar < g_breaks[i].break_bar)
         {
            StructureBreak temp = g_breaks[i];
            g_breaks[i] = g_breaks[j];
            g_breaks[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DRAW ALL VISUALS                                                  |
//+------------------------------------------------------------------+
void DrawAllVisuals()
{
   // Clear old objects
   if(Show_Only_Latest)
   {
      ObjectsDeleteAll(0, "SMC_SW_");
      ObjectsDeleteAll(0, "SMC_BRK_");
      ObjectsDeleteAll(0, "SMC_LINE_");
   }
   
   if(Show_Swing_Points)
      DrawSwingPoints();
   
   if(Show_Structure_Lines)
      DrawStructureLines();
   
   if(Show_Break_Labels)
      DrawBreaks();
}

//+------------------------------------------------------------------+
//| Draw Swing Points                                                 |
//+------------------------------------------------------------------+
void DrawSwingPoints()
{
   int drawn = 0;
   int max_draw = Show_Only_Latest ? Latest_Count : 50;
   
   for(int i = 0; i < ArraySize(g_swings) && drawn < max_draw; i++)
   {
      SwingPoint sp = g_swings[i];
      
      // Only draw classified swings
      if(sp.swing_type == SWING_HIGH || sp.swing_type == SWING_LOW)
         continue;
      
      string label = "";
      color clr = clrWhite;
      int arrow_code = 234;
      double label_offset = 50 * _Point;
      
      switch(sp.swing_type)
      {
         case SWING_HH:
            label = "HH";
            clr = Color_HH;
            arrow_code = 234;
            label_offset = 50 * _Point;
            break;
         case SWING_HL:
            label = "HL";
            clr = Color_HL;
            arrow_code = 233;
            label_offset = -50 * _Point;
            break;
         case SWING_LH:
            label = "LH";
            clr = Color_LH;
            arrow_code = 234;
            label_offset = 50 * _Point;
            break;
         case SWING_LL:
            label = "LL";
            clr = Color_LL;
            arrow_code = 233;
            label_offset = -50 * _Point;
            break;
         default:
            continue;
      }
      
      // Draw arrow
      string arrow_name = "SMC_SW_" + IntegerToString(drawn) + "_arr";
      ObjectDelete(0, arrow_name);
      ObjectCreate(0, arrow_name, OBJ_ARROW, 0, sp.time, sp.price);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
      
      // Draw label
      string label_name = "SMC_SW_" + IntegerToString(drawn) + "_lbl";
      ObjectDelete(0, label_name);
      ObjectCreate(0, label_name, OBJ_TEXT, 0, sp.time, sp.price + label_offset);
      ObjectSetString(0, label_name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, label_name, OBJPROP_FONT, "Arial Bold");
      
      // Draw horizontal line
      string hline_name = "SMC_SW_" + IntegerToString(drawn) + "_hline";
      datetime end_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      ObjectDelete(0, hline_name);
      ObjectCreate(0, hline_name, OBJ_TREND, 0, sp.time, sp.price, end_time, sp.price);
      ObjectSetInteger(0, hline_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, hline_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, hline_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, hline_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, hline_name, OBJPROP_BACK, true);
      
      drawn++;
   }
}

//+------------------------------------------------------------------+
//| Draw Structure Lines                                              |
//+------------------------------------------------------------------+
void DrawStructureLines()
{
   int line_count = 0;
   int max_lines = Show_Only_Latest ? Latest_Count * 2 : 30;
   
   SwingPoint prev;
   bool have_prev = false;
   
   for(int i = ArraySize(g_swings) - 1; i >= 0 && line_count < max_lines; i--)
   {
      SwingPoint sp = g_swings[i];
      
      // Only connect classified swings
      if(sp.swing_type == SWING_HIGH || sp.swing_type == SWING_LOW)
         continue;
      
      if(have_prev && prev.is_high != sp.is_high)
      {
         string line_name = "SMC_LINE_" + IntegerToString(line_count);
         
         color line_color = Color_HH;
         if(prev.is_high && !sp.is_high)
            line_color = Color_LH;  // Down move
         else
            line_color = Color_HL;  // Up move
         
         ObjectDelete(0, line_name);
         ObjectCreate(0, line_name, OBJ_TREND, 0, prev.time, prev.price, sp.time, sp.price);
         ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
         ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
         
         line_count++;
      }
      
      prev = sp;
      have_prev = true;
   }
}

//+------------------------------------------------------------------+
//| Draw Breaks (BOS / CHoCH)                                         |
//+------------------------------------------------------------------+
void DrawBreaks()
{
   int drawn = 0;
   int max_draw = Show_Only_Latest ? Latest_Count : 30;
   
   for(int i = 0; i < ArraySize(g_breaks) && drawn < max_draw; i++)
   {
      StructureBreak brk = g_breaks[i];
      
      string label = "";
      color clr = clrWhite;
      
      switch(brk.type)
      {
         case BREAK_BOS_BULL:
            label = "BOS";
            clr = Color_BOS_Bull;
            break;
         case BREAK_BOS_BEAR:
            label = "BOS";
            clr = Color_BOS_Bear;
            break;
         case BREAK_CHOCH_BULL:
            label = "CHoCH";
            clr = Color_CHoCH_Bull;
            break;
         case BREAK_CHOCH_BEAR:
            label = "CHoCH";
            clr = Color_CHoCH_Bear;
            break;
         default:
            continue;
      }
      
      // Draw break line (from the level that was broken)
      string line_name = "SMC_BRK_" + IntegerToString(drawn) + "_line";
      datetime end_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      
      ObjectDelete(0, line_name);
      ObjectCreate(0, line_name, OBJ_TREND, 0, brk.level_time, brk.break_level, end_time, brk.break_level);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
      
      // Draw label at break point
      string text_name = "SMC_BRK_" + IntegerToString(drawn) + "_txt";
      ObjectDelete(0, text_name);
      ObjectCreate(0, text_name, OBJ_TEXT, 0, brk.break_time, brk.break_level);
      ObjectSetString(0, text_name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, text_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, text_name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      
      // Draw arrow at break point
      string arrow_name = "SMC_BRK_" + IntegerToString(drawn) + "_arr";
      int arrow_code = (brk.type == BREAK_BOS_BULL || brk.type == BREAK_CHOCH_BULL) ? 233 : 234;
      
      ObjectDelete(0, arrow_name);
      ObjectCreate(0, arrow_name, OBJ_ARROW, 0, brk.break_time, brk.break_price);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
      
      drawn++;
   }
}

//+------------------------------------------------------------------+
//| Draw Info Panel                                                   |
//+------------------------------------------------------------------+
void DrawInfoPanel()
{
   string p = "SMC_Panel";
   
   ObjectCreate(0, p + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, p + "_BG", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, p + "_BG", OBJPROP_YDISTANCE, 25);
   ObjectSetInteger(0, p + "_BG", OBJPROP_XSIZE, 280);
   ObjectSetInteger(0, p + "_BG", OBJPROP_YSIZE, 150);
   ObjectSetInteger(0, p + "_BG", OBJPROP_BGCOLOR, C'20,20,30');
   ObjectSetInteger(0, p + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, p + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, p + "_BG", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, p + "_BG", OBJPROP_WIDTH, 2);
   
   CreateLabel(p + "_Title", "═══ SMC v4.0 ═══", 20, 30, clrGold, 11);
   CreateLabel(p + "_TrendLbl", "Trend:", 20, 55, clrWhite, 10);
   CreateLabel(p + "_TrendVal", "---", 100, 55, clrYellow, 10);
   CreateLabel(p + "_HHLbl", "Last HH:", 20, 80, clrWhite, 9);
   CreateLabel(p + "_HHVal", "---", 100, 80, Color_HH, 9);
   CreateLabel(p + "_HLLbl", "Last HL:", 150, 80, clrWhite, 9);
   CreateLabel(p + "_HLVal", "---", 210, 80, Color_HL, 9);
   CreateLabel(p + "_LHLbl", "Last LH:", 20, 100, clrWhite, 9);
   CreateLabel(p + "_LHVal", "---", 100, 100, Color_LH, 9);
   CreateLabel(p + "_LLLbl", "Last LL:", 150, 100, clrWhite, 9);
   CreateLabel(p + "_LLVal", "---", 210, 100, Color_LL, 9);
   CreateLabel(p + "_BreakLbl", "Last Break:", 20, 125, clrWhite, 10);
   CreateLabel(p + "_BreakVal", "---", 120, 125, clrYellow, 10);
}

//+------------------------------------------------------------------+
//| Create Label                                                      |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int size)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Update Info Panel                                                 |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   string p = "SMC_Panel";
   
   // Trend
   string trend_str = "NEUTRAL";
   color trend_clr = clrYellow;
   if(g_trendState == TREND_BULLISH) { trend_str = "BULLISH"; trend_clr = clrLime; }
   else if(g_trendState == TREND_BEARISH) { trend_str = "BEARISH"; trend_clr = clrRed; }
   ObjectSetString(0, p + "_TrendVal", OBJPROP_TEXT, trend_str);
   ObjectSetInteger(0, p + "_TrendVal", OBJPROP_COLOR, trend_clr);
   
   // HH
   if(g_lastHH > 0)
      ObjectSetString(0, p + "_HHVal", OBJPROP_TEXT, DoubleToString(g_lastHH, _Digits));
   
   // HL
   if(g_lastHL > 0)
      ObjectSetString(0, p + "_HLVal", OBJPROP_TEXT, DoubleToString(g_lastHL, _Digits));
   
   // LH
   if(g_lastLH > 0)
      ObjectSetString(0, p + "_LHVal", OBJPROP_TEXT, DoubleToString(g_lastLH, _Digits));
   
   // LL
   if(g_lastLL > 0)
      ObjectSetString(0, p + "_LLVal", OBJPROP_TEXT, DoubleToString(g_lastLL, _Digits));
   
   // Last Break
   if(ArraySize(g_breaks) > 0)
   {
      StructureBreak brk = g_breaks[0];
      string brk_str = "";
      color brk_clr = clrWhite;
      
      switch(brk.type)
      {
         case BREAK_BOS_BULL: brk_str = "BOS Bull"; brk_clr = Color_BOS_Bull; break;
         case BREAK_BOS_BEAR: brk_str = "BOS Bear"; brk_clr = Color_BOS_Bear; break;
         case BREAK_CHOCH_BULL: brk_str = "CHoCH Bull"; brk_clr = Color_CHoCH_Bull; break;
         case BREAK_CHOCH_BEAR: brk_str = "CHoCH Bear"; brk_clr = Color_CHoCH_Bear; break;
      }
      
      ObjectSetString(0, p + "_BreakVal", OBJPROP_TEXT, brk_str);
      ObjectSetInteger(0, p + "_BreakVal", OBJPROP_COLOR, brk_clr);
   }
}
//+------------------------------------------------------------------+
