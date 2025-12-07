//+------------------------------------------------------------------+
//|                                         SMC_Strategy_v2_Pro.mq5 |
//|                         Smart Money Concepts Trading Strategy    |
//|                                    Version 2.0 - Step by Step    |
//+------------------------------------------------------------------+
#property copyright "SMC Strategy v2.0"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "2.00"
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

enum ENUM_CHOCH_TYPE
{
   CHOCH_NONE,          // No CHoCH
   CHOCH_BULLISH,       // Bullish CHoCH
   CHOCH_BEARISH        // Bearish CHoCH
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double   price;           // Price level
   datetime time;            // Time of formation
   int      bar_index;       // Bar index
   bool     is_high;         // true = swing high, false = swing low
   bool     is_broken;       // Has it been broken?
};

struct CHoCHInfo
{
   ENUM_CHOCH_TYPE type;     // Type of CHoCH
   double   break_level;     // Level that was broken
   double   break_price;     // Price that broke the level
   datetime break_time;      // Time of break
   int      break_bar;       // Bar index of break
   double   break_distance;  // Distance of break in points
};

struct MarketStructure
{
   ENUM_MARKET_BIAS current_bias;    // Current market bias
   SwingPoint last_swing_high;       // Last swing high
   SwingPoint last_swing_low;        // Last swing low
   SwingPoint last_internal_high;    // Last internal high (for CHoCH)
   SwingPoint last_internal_low;     // Last internal low (for CHoCH)
   CHoCHInfo  last_choch;            // Last CHoCH detected
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - GENERAL                                        |
//+------------------------------------------------------------------+
input group "=== General Settings ==="
input int      Magic_Number = 12345;              // Magic Number
input string   EA_Comment = "SMC_v2_Pro";         // Trade Comment
input bool     Show_Info_Panel = true;            // Show Info Panel
input bool     Show_Visual_Objects = true;        // Draw Visual Objects

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - SWING DETECTION                                |
//+------------------------------------------------------------------+
input group "=== Swing Detection Settings ==="
input int      Swing_Period = 5;                  // Swing Period (bars on each side)
input int      Lookback_Bars = 200;               // Lookback Bars for Analysis

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - CHoCH DETECTION                                |
//+------------------------------------------------------------------+
input group "=== CHoCH Detection Settings ==="
input int      Min_CHoCH_Break_Points = 50;       // Min CHoCH Break (points)
input bool     Require_Close_Break = true;        // Require Close Beyond Level
input color    CHoCH_Bullish_Color = clrLime;     // Bullish CHoCH Color
input color    CHoCH_Bearish_Color = clrRed;      // Bearish CHoCH Color

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - HTF BIAS                                       |
//+------------------------------------------------------------------+
input group "=== HTF Bias Settings ==="
input ENUM_TIMEFRAMES HTF_Timeframe_1 = PERIOD_H4;  // HTF Timeframe 1
input ENUM_TIMEFRAMES HTF_Timeframe_2 = PERIOD_H1;  // HTF Timeframe 2

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  position;

// Market Structure for different timeframes
MarketStructure g_structure_current;   // Current timeframe structure
MarketStructure g_structure_H1;        // H1 structure
MarketStructure g_structure_H4;        // H4 structure

// Arrays for swing points
SwingPoint g_swing_highs[];
SwingPoint g_swing_lows[];

// Last bar time for new bar detection
datetime g_last_bar_time = 0;

// Object counter for unique names
int g_object_counter = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("==============================================");
   Print("SMC Strategy v2.0 Pro - Initializing...");
   Print("==============================================");
   
   // Set magic number
   trade.SetExpertMagicNumber(Magic_Number);
   
   // Initialize arrays
   ArrayResize(g_swing_highs, 0);
   ArrayResize(g_swing_lows, 0);
   
   // Initialize structures
   InitializeMarketStructure(g_structure_current);
   InitializeMarketStructure(g_structure_H1);
   InitializeMarketStructure(g_structure_H4);
   
   // Initial analysis
   AnalyzeMarketStructure(PERIOD_CURRENT, g_structure_current);
   
   // Draw info panel
   if(Show_Info_Panel)
      DrawInfoPanel();
   
   Print("SMC Strategy v2.0 Pro - Ready!");
   Print("Current Symbol: ", _Symbol);
   Print("Current Timeframe: ", EnumToString((ENUM_TIMEFRAMES)Period()));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Delete all objects created by this EA
   ObjectsDeleteAll(0, "SMC_");
   
   Print("SMC Strategy v2.0 Pro - Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only process on new bar
   if(!IsNewBar())
      return;
   
   // Analyze market structure
   AnalyzeMarketStructure(PERIOD_CURRENT, g_structure_current);
   
   // Check for CHoCH
   CHoCHInfo choch = DetectCHoCH(PERIOD_CURRENT, g_structure_current);
   
   if(choch.type != CHOCH_NONE)
   {
      // CHoCH detected!
      string choch_type_str = (choch.type == CHOCH_BULLISH) ? "BULLISH" : "BEARISH";
      
      Print("========================================");
      Print("CHoCH DETECTED: ", choch_type_str);
      Print("Break Level: ", DoubleToString(choch.break_level, _Digits));
      Print("Break Price: ", DoubleToString(choch.break_price, _Digits));
      Print("Break Distance: ", DoubleToString(choch.break_distance, 1), " points");
      Print("========================================");
      
      // Draw CHoCH on chart
      if(Show_Visual_Objects)
         DrawCHoCH(choch);
      
      // Update last CHoCH
      g_structure_current.last_choch = choch;
      
      // Update market bias based on CHoCH
      if(choch.type == CHOCH_BULLISH)
         g_structure_current.current_bias = BIAS_BULLISH;
      else if(choch.type == CHOCH_BEARISH)
         g_structure_current.current_bias = BIAS_BEARISH;
   }
   
   // Update info panel
   if(Show_Info_Panel)
      UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Initialize Market Structure                                       |
//+------------------------------------------------------------------+
void InitializeMarketStructure(MarketStructure &structure)
{
   structure.current_bias = BIAS_NEUTRAL;
   
   structure.last_swing_high.price = 0;
   structure.last_swing_high.time = 0;
   structure.last_swing_high.bar_index = -1;
   structure.last_swing_high.is_high = true;
   structure.last_swing_high.is_broken = false;
   
   structure.last_swing_low.price = 0;
   structure.last_swing_low.time = 0;
   structure.last_swing_low.bar_index = -1;
   structure.last_swing_low.is_high = false;
   structure.last_swing_low.is_broken = false;
   
   structure.last_internal_high = structure.last_swing_high;
   structure.last_internal_low = structure.last_swing_low;
   
   structure.last_choch.type = CHOCH_NONE;
   structure.last_choch.break_level = 0;
   structure.last_choch.break_price = 0;
   structure.last_choch.break_time = 0;
   structure.last_choch.break_bar = -1;
   structure.last_choch.break_distance = 0;
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
bool IsSwingHigh(int index, int period, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   // Need 'period' bars on each side
   if(index < period)
      return false;
   
   double high_value = iHigh(_Symbol, timeframe, index);
   
   // Check left side (more recent bars)
   for(int i = 1; i <= period; i++)
   {
      if(iHigh(_Symbol, timeframe, index - i) >= high_value)
         return false;
   }
   
   // Check right side (older bars)
   for(int i = 1; i <= period; i++)
   {
      if(iHigh(_Symbol, timeframe, index + i) >= high_value)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is Swing Low                                         |
//+------------------------------------------------------------------+
bool IsSwingLow(int index, int period, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   // Need 'period' bars on each side
   if(index < period)
      return false;
   
   double low_value = iLow(_Symbol, timeframe, index);
   
   // Check left side (more recent bars)
   for(int i = 1; i <= period; i++)
   {
      if(iLow(_Symbol, timeframe, index - i) <= low_value)
         return false;
   }
   
   // Check right side (older bars)
   for(int i = 1; i <= period; i++)
   {
      if(iLow(_Symbol, timeframe, index + i) <= low_value)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Find All Swing Points                                             |
//+------------------------------------------------------------------+
void FindSwingPoints(ENUM_TIMEFRAMES timeframe, int lookback)
{
   // Clear arrays
   ArrayResize(g_swing_highs, 0);
   ArrayResize(g_swing_lows, 0);
   
   // Find swing highs and lows
   for(int i = Swing_Period; i < lookback - Swing_Period; i++)
   {
      // Check for swing high
      if(IsSwingHigh(i, Swing_Period, timeframe))
      {
         SwingPoint sp;
         sp.price = iHigh(_Symbol, timeframe, i);
         sp.time = iTime(_Symbol, timeframe, i);
         sp.bar_index = i;
         sp.is_high = true;
         sp.is_broken = false;
         
         int size = ArraySize(g_swing_highs);
         ArrayResize(g_swing_highs, size + 1);
         g_swing_highs[size] = sp;
      }
      
      // Check for swing low
      if(IsSwingLow(i, Swing_Period, timeframe))
      {
         SwingPoint sp;
         sp.price = iLow(_Symbol, timeframe, i);
         sp.time = iTime(_Symbol, timeframe, i);
         sp.bar_index = i;
         sp.is_high = false;
         sp.is_broken = false;
         
         int size = ArraySize(g_swing_lows);
         ArrayResize(g_swing_lows, size + 1);
         g_swing_lows[size] = sp;
      }
   }
   
   // Sort arrays by bar index (most recent first)
   SortSwingPointsByIndex(g_swing_highs);
   SortSwingPointsByIndex(g_swing_lows);
}

//+------------------------------------------------------------------+
//| Sort Swing Points by Bar Index                                    |
//+------------------------------------------------------------------+
void SortSwingPointsByIndex(SwingPoint &arr[])
{
   int size = ArraySize(arr);
   
   for(int i = 0; i < size - 1; i++)
   {
      for(int j = i + 1; j < size; j++)
      {
         if(arr[j].bar_index < arr[i].bar_index)
         {
            SwingPoint temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Market Structure                                          |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure(ENUM_TIMEFRAMES timeframe, MarketStructure &structure)
{
   // Find all swing points
   FindSwingPoints(timeframe, Lookback_Bars);
   
   // Get last swing high and low
   if(ArraySize(g_swing_highs) > 0)
   {
      structure.last_swing_high = g_swing_highs[0];  // Most recent
      
      // Find internal high (second most recent or first that's lower than last)
      if(ArraySize(g_swing_highs) > 1)
      {
         structure.last_internal_high = g_swing_highs[1];
      }
   }
   
   if(ArraySize(g_swing_lows) > 0)
   {
      structure.last_swing_low = g_swing_lows[0];  // Most recent
      
      // Find internal low (second most recent or first that's higher than last)
      if(ArraySize(g_swing_lows) > 1)
      {
         structure.last_internal_low = g_swing_lows[1];
      }
   }
   
   // Determine initial bias based on swing points sequence
   DetermineMarketBias(timeframe, structure);
   
   // Draw swing points if visual objects enabled
   if(Show_Visual_Objects)
      DrawSwingPoints();
}

//+------------------------------------------------------------------+
//| Determine Market Bias                                             |
//+------------------------------------------------------------------+
void DetermineMarketBias(ENUM_TIMEFRAMES timeframe, MarketStructure &structure)
{
   // Simple bias determination:
   // If recent swing highs are making higher highs and lows making higher lows = Bullish
   // If recent swing highs are making lower highs and lows making lower lows = Bearish
   
   if(ArraySize(g_swing_highs) < 2 || ArraySize(g_swing_lows) < 2)
   {
      structure.current_bias = BIAS_NEUTRAL;
      return;
   }
   
   // Check last two swing highs
   bool higher_high = g_swing_highs[0].price > g_swing_highs[1].price;
   bool lower_high = g_swing_highs[0].price < g_swing_highs[1].price;
   
   // Check last two swing lows
   bool higher_low = g_swing_lows[0].price > g_swing_lows[1].price;
   bool lower_low = g_swing_lows[0].price < g_swing_lows[1].price;
   
   // Determine bias
   if(higher_high && higher_low)
   {
      structure.current_bias = BIAS_BULLISH;
   }
   else if(lower_high && lower_low)
   {
      structure.current_bias = BIAS_BEARISH;
   }
   else
   {
      structure.current_bias = BIAS_NEUTRAL;
   }
}

//+------------------------------------------------------------------+
//| Detect CHoCH (Change of Character)                                |
//+------------------------------------------------------------------+
CHoCHInfo DetectCHoCH(ENUM_TIMEFRAMES timeframe, MarketStructure &structure)
{
   CHoCHInfo choch;
   choch.type = CHOCH_NONE;
   choch.break_level = 0;
   choch.break_price = 0;
   choch.break_time = 0;
   choch.break_bar = -1;
   choch.break_distance = 0;
   
   // Get current candle data
   double close_current = iClose(_Symbol, timeframe, 0);
   double close_previous = iClose(_Symbol, timeframe, 1);
   double high_previous = iHigh(_Symbol, timeframe, 1);
   double low_previous = iLow(_Symbol, timeframe, 1);
   
   //+------------------------------------------------------------------+
   // BULLISH CHoCH: In bearish structure, price breaks above internal high
   //+------------------------------------------------------------------+
   if(structure.current_bias == BIAS_BEARISH || structure.current_bias == BIAS_NEUTRAL)
   {
      // Check if we have a valid internal high to break
      if(structure.last_internal_high.price > 0)
      {
         double level_to_break = structure.last_internal_high.price;
         
         // Check if previous candle broke above the level
         if(high_previous > level_to_break)
         {
            double break_distance = 0;
            
            if(Require_Close_Break)
            {
               // Need close above level
               if(close_previous > level_to_break)
               {
                  break_distance = (close_previous - level_to_break) / _Point;
               }
            }
            else
            {
               // Just need high above level
               break_distance = (high_previous - level_to_break) / _Point;
            }
            
            // Check minimum break distance
            if(break_distance >= Min_CHoCH_Break_Points)
            {
               choch.type = CHOCH_BULLISH;
               choch.break_level = level_to_break;
               choch.break_price = Require_Close_Break ? close_previous : high_previous;
               choch.break_time = iTime(_Symbol, timeframe, 1);
               choch.break_bar = 1;
               choch.break_distance = break_distance;
               
               return choch;
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   // BEARISH CHoCH: In bullish structure, price breaks below internal low
   //+------------------------------------------------------------------+
   if(structure.current_bias == BIAS_BULLISH || structure.current_bias == BIAS_NEUTRAL)
   {
      // Check if we have a valid internal low to break
      if(structure.last_internal_low.price > 0)
      {
         double level_to_break = structure.last_internal_low.price;
         
         // Check if previous candle broke below the level
         if(low_previous < level_to_break)
         {
            double break_distance = 0;
            
            if(Require_Close_Break)
            {
               // Need close below level
               if(close_previous < level_to_break)
               {
                  break_distance = (level_to_break - close_previous) / _Point;
               }
            }
            else
            {
               // Just need low below level
               break_distance = (level_to_break - low_previous) / _Point;
            }
            
            // Check minimum break distance
            if(break_distance >= Min_CHoCH_Break_Points)
            {
               choch.type = CHOCH_BEARISH;
               choch.break_level = level_to_break;
               choch.break_price = Require_Close_Break ? close_previous : low_previous;
               choch.break_time = iTime(_Symbol, timeframe, 1);
               choch.break_bar = 1;
               choch.break_distance = break_distance;
               
               return choch;
            }
         }
      }
   }
   
   return choch;
}

//+------------------------------------------------------------------+
//| Draw Swing Points on Chart                                        |
//+------------------------------------------------------------------+
void DrawSwingPoints()
{
   // Delete old swing point objects
   ObjectsDeleteAll(0, "SMC_SH_");
   ObjectsDeleteAll(0, "SMC_SL_");
   
   // Draw swing highs
   for(int i = 0; i < ArraySize(g_swing_highs) && i < 20; i++)
   {
      string name = "SMC_SH_" + IntegerToString(i);
      
      ObjectCreate(0, name, OBJ_ARROW_DOWN, 0, 
                   g_swing_highs[i].time, 
                   g_swing_highs[i].price + 10 * _Point);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   }
   
   // Draw swing lows
   for(int i = 0; i < ArraySize(g_swing_lows) && i < 20; i++)
   {
      string name = "SMC_SL_" + IntegerToString(i);
      
      ObjectCreate(0, name, OBJ_ARROW_UP, 0, 
                   g_swing_lows[i].time, 
                   g_swing_lows[i].price - 10 * _Point);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   }
}

//+------------------------------------------------------------------+
//| Draw CHoCH on Chart                                               |
//+------------------------------------------------------------------+
void DrawCHoCH(CHoCHInfo &choch)
{
   g_object_counter++;
   
   string name_line = "SMC_CHoCH_Line_" + IntegerToString(g_object_counter);
   string name_text = "SMC_CHoCH_Text_" + IntegerToString(g_object_counter);
   
   color choch_color = (choch.type == CHOCH_BULLISH) ? CHoCH_Bullish_Color : CHoCH_Bearish_Color;
   string choch_label = (choch.type == CHOCH_BULLISH) ? "CHoCH" : "CHoCH";
   
   // Draw horizontal line at break level
   ObjectCreate(0, name_line, OBJ_HLINE, 0, 0, choch.break_level);
   ObjectSetInteger(0, name_line, OBJPROP_COLOR, choch_color);
   ObjectSetInteger(0, name_line, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name_line, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name_line, OBJPROP_BACK, true);
   
   // Draw label
   ObjectCreate(0, name_text, OBJ_TEXT, 0, choch.break_time, choch.break_level);
   ObjectSetString(0, name_text, OBJPROP_TEXT, choch_label);
   ObjectSetInteger(0, name_text, OBJPROP_COLOR, choch_color);
   ObjectSetInteger(0, name_text, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name_text, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Draw Info Panel                                                   |
//+------------------------------------------------------------------+
void DrawInfoPanel()
{
   string panel_name = "SMC_InfoPanel";
   
   // Create background rectangle
   ObjectCreate(0, panel_name + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_XSIZE, 220);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_YSIZE, 150);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_BACK, false);
   
   // Title
   CreateLabel(panel_name + "_Title", "SMC Strategy v2.0", 20, 35, clrGold, 11);
   
   // Labels
   CreateLabel(panel_name + "_Bias_Label", "Market Bias:", 20, 60, clrWhite, 9);
   CreateLabel(panel_name + "_Bias_Value", "---", 120, 60, clrYellow, 9);
   
   CreateLabel(panel_name + "_SH_Label", "Last Swing High:", 20, 80, clrWhite, 9);
   CreateLabel(panel_name + "_SH_Value", "---", 120, 80, clrDodgerBlue, 9);
   
   CreateLabel(panel_name + "_SL_Label", "Last Swing Low:", 20, 100, clrWhite, 9);
   CreateLabel(panel_name + "_SL_Value", "---", 120, 100, clrOrange, 9);
   
   CreateLabel(panel_name + "_CHoCH_Label", "Last CHoCH:", 20, 120, clrWhite, 9);
   CreateLabel(panel_name + "_CHoCH_Value", "---", 120, 120, clrLime, 9);
   
   CreateLabel(panel_name + "_Status_Label", "Status:", 20, 145, clrWhite, 9);
   CreateLabel(panel_name + "_Status_Value", "Ready", 120, 145, clrLime, 9);
}

//+------------------------------------------------------------------+
//| Create Label Helper                                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int font_size)
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
   string panel_name = "SMC_InfoPanel";
   
   // Update Market Bias
   string bias_str = "NEUTRAL";
   color bias_color = clrYellow;
   
   if(g_structure_current.current_bias == BIAS_BULLISH)
   {
      bias_str = "BULLISH";
      bias_color = clrLime;
   }
   else if(g_structure_current.current_bias == BIAS_BEARISH)
   {
      bias_str = "BEARISH";
      bias_color = clrRed;
   }
   
   ObjectSetString(0, panel_name + "_Bias_Value", OBJPROP_TEXT, bias_str);
   ObjectSetInteger(0, panel_name + "_Bias_Value", OBJPROP_COLOR, bias_color);
   
   // Update Last Swing High
   if(g_structure_current.last_swing_high.price > 0)
   {
      ObjectSetString(0, panel_name + "_SH_Value", OBJPROP_TEXT, 
                      DoubleToString(g_structure_current.last_swing_high.price, _Digits));
   }
   
   // Update Last Swing Low
   if(g_structure_current.last_swing_low.price > 0)
   {
      ObjectSetString(0, panel_name + "_SL_Value", OBJPROP_TEXT, 
                      DoubleToString(g_structure_current.last_swing_low.price, _Digits));
   }
   
   // Update Last CHoCH
   if(g_structure_current.last_choch.type != CHOCH_NONE)
   {
      string choch_str = (g_structure_current.last_choch.type == CHOCH_BULLISH) ? "BULLISH" : "BEARISH";
      color choch_color = (g_structure_current.last_choch.type == CHOCH_BULLISH) ? clrLime : clrRed;
      
      ObjectSetString(0, panel_name + "_CHoCH_Value", OBJPROP_TEXT, choch_str);
      ObjectSetInteger(0, panel_name + "_CHoCH_Value", OBJPROP_COLOR, choch_color);
   }
}

//+------------------------------------------------------------------+
//| Get Bias String                                                   |
//+------------------------------------------------------------------+
string GetBiasString(ENUM_MARKET_BIAS bias)
{
   switch(bias)
   {
      case BIAS_BULLISH: return "BULLISH";
      case BIAS_BEARISH: return "BEARISH";
      default: return "NEUTRAL";
   }
}
//+------------------------------------------------------------------+
