//+------------------------------------------------------------------+
//|                                         SMC_Strategy_v2_Pro.mq5 |
//|                         Smart Money Concepts Trading Strategy    |
//|                                    Version 5.0 - Visual Test     |
//+------------------------------------------------------------------+
#property copyright "SMC Strategy v5.0"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "5.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+
enum ENUM_SWING_TYPE
{
   SWING_NONE,
   SWING_HH,    // Higher High
   SWING_HL,    // Higher Low  
   SWING_LH,    // Lower High
   SWING_LL,    // Lower Low
   SWING_HIGH,  // Unclassified High
   SWING_LOW    // Unclassified Low
};

enum ENUM_BREAK_TYPE
{
   BREAK_NONE,
   BREAK_BOS_BULL,    // BOS Bullish
   BREAK_BOS_BEAR,    // BOS Bearish
   BREAK_CHOCH_BULL,  // CHoCH Bullish
   BREAK_CHOCH_BEAR   // CHoCH Bearish
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
   ENUM_SWING_TYPE   type;
};

struct BreakPoint
{
   ENUM_BREAK_TYPE   type;
   double            level;
   datetime          time;
   int               bar_index;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "═══════════ Swing Detection ═══════════"
input int      Swing_Strength = 3;           // Swing Strength (bars each side)
input int      Lookback = 100;               // Lookback Bars

input group "═══════════ Colors ═══════════"
input color    Color_HH = clrDodgerBlue;     // HH Color
input color    Color_HL = clrLime;           // HL Color
input color    Color_LH = clrOrange;         // LH Color
input color    Color_LL = clrRed;            // LL Color
input color    Color_BOS = clrYellow;        // BOS Color
input color    Color_CHoCH = clrMagenta;     // CHoCH Color

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
SwingPoint g_swings[];
BreakPoint g_breaks[];
datetime g_last_bar = 0;
int g_obj_count = 0;

// Structure tracking
double g_lastStructuralHigh = 0;
double g_lastStructuralLow = 0;
datetime g_lastStructuralHighTime = 0;
datetime g_lastStructuralLowTime = 0;

// CHoCH tracking - the swing that caused the last BOS
double g_swingThatCausedLastBullishBOS = 0;  // The HL before HH
datetime g_swingThatCausedLastBullishBOSTime = 0;
double g_swingThatCausedLastBearishBOS = 0;  // The LH before LL
datetime g_swingThatCausedLastBearishBOSTime = 0;

bool g_isBullish = false;
bool g_isBearish = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════");
   Print("   SMC Strategy v5.0 - VISUAL TEST");
   Print("═══════════════════════════════════════════════════");
   
   ObjectsDeleteAll(0, "SMC_");
   
   AnalyzeAndDraw();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("Backtest complete - keeping objects on chart");
      return;
   }
   ObjectsDeleteAll(0, "SMC_");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime current_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(current_bar != g_last_bar)
   {
      g_last_bar = current_bar;
      AnalyzeAndDraw();
   }
}

//+------------------------------------------------------------------+
//| Main Analysis Function                                            |
//+------------------------------------------------------------------+
void AnalyzeAndDraw()
{
   // Clear previous
   ObjectsDeleteAll(0, "SMC_");
   ArrayResize(g_swings, 0);
   ArrayResize(g_breaks, 0);
   g_obj_count = 0;
   
   // Reset structure
   g_lastStructuralHigh = 0;
   g_lastStructuralLow = 0;
   g_isBullish = false;
   g_isBearish = false;
   g_swingThatCausedLastBullishBOS = 0;
   g_swingThatCausedLastBearishBOS = 0;
   
   // Step 1: Find ALL swing points
   FindAllSwings();
   
   // Step 2: Classify swings and detect breaks
   ClassifySwingsAndDetectBreaks();
   
   // Step 3: Draw everything
   DrawSwings();
   DrawBreaks();
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Find All Swing Highs and Lows                                     |
//+------------------------------------------------------------------+
void FindAllSwings()
{
   for(int i = Swing_Strength; i < Lookback - Swing_Strength; i++)
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
      
      if(isSwingHigh)
      {
         SwingPoint sp;
         sp.price = high;
         sp.time = time;
         sp.bar_index = i;
         sp.is_high = true;
         sp.type = SWING_HIGH;  // Will classify later
         
         int size = ArraySize(g_swings);
         ArrayResize(g_swings, size + 1);
         g_swings[size] = sp;
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
      
      if(isSwingLow)
      {
         SwingPoint sp;
         sp.price = low;
         sp.time = time;
         sp.bar_index = i;
         sp.is_high = false;
         sp.type = SWING_LOW;  // Will classify later
         
         int size = ArraySize(g_swings);
         ArrayResize(g_swings, size + 1);
         g_swings[size] = sp;
      }
   }
   
   // Sort oldest first (highest bar_index first)
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
   
   Print("Found ", total, " swing points");
}

//+------------------------------------------------------------------+
//| Classify Swings (HH/HL/LH/LL) and Detect BOS/CHoCH                |
//+------------------------------------------------------------------+
void ClassifySwingsAndDetectBreaks()
{
   int total = ArraySize(g_swings);
   if(total < 2) return;
   
   double prevHigh = 0, prevLow = 0;
   datetime prevHighTime = 0, prevLowTime = 0;
   
   // Track last low before a high (for CHoCH)
   double lastLowBeforeHigh = 0;
   datetime lastLowBeforeHighTime = 0;
   double lastHighBeforeLow = 0;
   datetime lastHighBeforeLowTime = 0;
   
   for(int i = 0; i < total; i++)
   {
      if(g_swings[i].is_high)
      {
         // === PROCESSING A HIGH ===
         
         if(prevHigh > 0)
         {
            // Compare with previous high
            if(g_swings[i].price > prevHigh)
            {
               // Higher High!
               g_swings[i].type = SWING_HH;
               
               // Check for BOS (close above previous high)
               if(DidCloseBreak(g_swings[i].bar_index, prevHighTime, prevHigh, true))
               {
                  // This is a BOS Bullish
                  if(g_isBearish)
                  {
                     // Was bearish -> CHoCH Bullish!
                     // CHoCH breaks the LH that caused the last LL
                     if(g_swingThatCausedLastBearishBOS > 0)
                     {
                        AddBreak(BREAK_CHOCH_BULL, g_swingThatCausedLastBearishBOS, 
                                 g_swingThatCausedLastBearishBOSTime, g_swings[i].bar_index);
                     }
                  }
                  else
                  {
                     // BOS Bullish
                     AddBreak(BREAK_BOS_BULL, prevHigh, prevHighTime, g_swings[i].bar_index);
                  }
                  
                  g_isBullish = true;
                  g_isBearish = false;
                  
                  // Save the LOW that caused this BOS (for future CHoCH detection)
                  if(lastLowBeforeHigh > 0)
                  {
                     g_swingThatCausedLastBullishBOS = lastLowBeforeHigh;
                     g_swingThatCausedLastBullishBOSTime = lastLowBeforeHighTime;
                     
                     // Mark that low as HL
                     for(int k = 0; k < total; k++)
                     {
                        if(!g_swings[k].is_high && g_swings[k].time == lastLowBeforeHighTime)
                        {
                           g_swings[k].type = SWING_HL;
                           break;
                        }
                     }
                  }
               }
               
               g_lastStructuralHigh = g_swings[i].price;
               g_lastStructuralHighTime = g_swings[i].time;
            }
            else
            {
               // Lower High
               g_swings[i].type = SWING_LH;
            }
         }
         
         prevHigh = g_swings[i].price;
         prevHighTime = g_swings[i].time;
         lastHighBeforeLow = g_swings[i].price;
         lastHighBeforeLowTime = g_swings[i].time;
      }
      else
      {
         // === PROCESSING A LOW ===
         
         if(prevLow > 0)
         {
            // Compare with previous low
            if(g_swings[i].price < prevLow)
            {
               // Lower Low!
               g_swings[i].type = SWING_LL;
               
               // Check for BOS (close below previous low)
               if(DidCloseBreak(g_swings[i].bar_index, prevLowTime, prevLow, false))
               {
                  // This is a BOS Bearish
                  if(g_isBullish)
                  {
                     // Was bullish -> CHoCH Bearish!
                     // CHoCH breaks the HL that caused the last HH
                     if(g_swingThatCausedLastBullishBOS > 0)
                     {
                        AddBreak(BREAK_CHOCH_BEAR, g_swingThatCausedLastBullishBOS,
                                 g_swingThatCausedLastBullishBOSTime, g_swings[i].bar_index);
                     }
                  }
                  else
                  {
                     // BOS Bearish
                     AddBreak(BREAK_BOS_BEAR, prevLow, prevLowTime, g_swings[i].bar_index);
                  }
                  
                  g_isBearish = true;
                  g_isBullish = false;
                  
                  // Save the HIGH that caused this BOS (for future CHoCH detection)
                  if(lastHighBeforeLow > 0)
                  {
                     g_swingThatCausedLastBearishBOS = lastHighBeforeLow;
                     g_swingThatCausedLastBearishBOSTime = lastHighBeforeLowTime;
                     
                     // Mark that high as LH
                     for(int k = 0; k < total; k++)
                     {
                        if(g_swings[k].is_high && g_swings[k].time == lastHighBeforeLowTime)
                        {
                           g_swings[k].type = SWING_LH;
                           break;
                        }
                     }
                  }
               }
               
               g_lastStructuralLow = g_swings[i].price;
               g_lastStructuralLowTime = g_swings[i].time;
            }
            else
            {
               // Higher Low
               g_swings[i].type = SWING_HL;
            }
         }
         
         prevLow = g_swings[i].price;
         prevLowTime = g_swings[i].time;
         lastLowBeforeHigh = g_swings[i].price;
         lastLowBeforeHighTime = g_swings[i].time;
      }
   }
   
   // Count classifications
   int hh=0, hl=0, lh=0, ll=0;
   for(int i = 0; i < total; i++)
   {
      switch(g_swings[i].type)
      {
         case SWING_HH: hh++; break;
         case SWING_HL: hl++; break;
         case SWING_LH: lh++; break;
         case SWING_LL: ll++; break;
      }
   }
   Print("Classified: HH=", hh, " HL=", hl, " LH=", lh, " LL=", ll, " | Breaks=", ArraySize(g_breaks));
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
//| Add a break to the array                                          |
//+------------------------------------------------------------------+
void AddBreak(ENUM_BREAK_TYPE type, double level, datetime level_time, int break_bar)
{
   BreakPoint bp;
   bp.type = type;
   bp.level = level;
   bp.time = level_time;
   bp.bar_index = break_bar;
   
   int size = ArraySize(g_breaks);
   ArrayResize(g_breaks, size + 1);
   g_breaks[size] = bp;
   
   string type_str = "";
   switch(type)
   {
      case BREAK_BOS_BULL: type_str = "BOS ▲"; break;
      case BREAK_BOS_BEAR: type_str = "BOS ▼"; break;
      case BREAK_CHOCH_BULL: type_str = "CHoCH ▲"; break;
      case BREAK_CHOCH_BEAR: type_str = "CHoCH ▼"; break;
   }
   Print("*** ", type_str, " @ ", level, " ***");
}

//+------------------------------------------------------------------+
//| Draw Swing Points                                                 |
//+------------------------------------------------------------------+
void DrawSwings()
{
   int total = ArraySize(g_swings);
   
   for(int i = 0; i < total; i++)
   {
      SwingPoint sp = g_swings[i];
      
      string label = "";
      color clr = clrWhite;
      int arrow = 0;
      double offset = 0;
      
      switch(sp.type)
      {
         case SWING_HH:
            label = "HH";
            clr = Color_HH;
            arrow = 234;  // Down arrow above
            offset = 30 * _Point;
            break;
         case SWING_HL:
            label = "HL";
            clr = Color_HL;
            arrow = 233;  // Up arrow below
            offset = -30 * _Point;
            break;
         case SWING_LH:
            label = "LH";
            clr = Color_LH;
            arrow = 234;
            offset = 30 * _Point;
            break;
         case SWING_LL:
            label = "LL";
            clr = Color_LL;
            arrow = 233;
            offset = -30 * _Point;
            break;
         default:
            continue;  // Skip unclassified
      }
      
      g_obj_count++;
      
      // Draw arrow
      string arr_name = "SMC_A_" + IntegerToString(g_obj_count);
      ObjectCreate(0, arr_name, OBJ_ARROW, 0, sp.time, sp.price);
      ObjectSetInteger(0, arr_name, OBJPROP_ARROWCODE, arrow);
      ObjectSetInteger(0, arr_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, arr_name, OBJPROP_WIDTH, 2);
      
      // Draw label
      string lbl_name = "SMC_L_" + IntegerToString(g_obj_count);
      ObjectCreate(0, lbl_name, OBJ_TEXT, 0, sp.time, sp.price + offset);
      ObjectSetString(0, lbl_name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, lbl_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lbl_name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, lbl_name, OBJPROP_FONT, "Arial Bold");
      
      // Draw horizontal line
      string line_name = "SMC_H_" + IntegerToString(g_obj_count);
      datetime end_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      ObjectCreate(0, line_name, OBJ_TREND, 0, sp.time, sp.price, end_time, sp.price);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
   }
   
   Print("Drew ", g_obj_count, " swing objects");
}

//+------------------------------------------------------------------+
//| Draw BOS and CHoCH                                                |
//+------------------------------------------------------------------+
void DrawBreaks()
{
   int total = ArraySize(g_breaks);
   
   for(int i = 0; i < total; i++)
   {
      BreakPoint bp = g_breaks[i];
      
      string label = "";
      color clr = clrWhite;
      
      switch(bp.type)
      {
         case BREAK_BOS_BULL:
            label = "BOS";
            clr = Color_BOS;
            break;
         case BREAK_BOS_BEAR:
            label = "BOS";
            clr = Color_BOS;
            break;
         case BREAK_CHOCH_BULL:
            label = "CHoCH";
            clr = Color_CHoCH;
            break;
         case BREAK_CHOCH_BEAR:
            label = "CHoCH";
            clr = Color_CHoCH;
            break;
         default:
            continue;
      }
      
      g_obj_count++;
      
      // Draw break line
      string line_name = "SMC_B_" + IntegerToString(g_obj_count);
      datetime break_time = iTime(_Symbol, PERIOD_CURRENT, bp.bar_index);
      ObjectCreate(0, line_name, OBJ_TREND, 0, bp.time, bp.level, break_time, bp.level);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      
      // Draw label
      string lbl_name = "SMC_BL_" + IntegerToString(g_obj_count);
      ObjectCreate(0, lbl_name, OBJ_TEXT, 0, break_time, bp.level);
      ObjectSetString(0, lbl_name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, lbl_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lbl_name, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, lbl_name, OBJPROP_FONT, "Arial Bold");
   }
   
   Print("Drew ", total, " break labels");
}
//+------------------------------------------------------------------+
