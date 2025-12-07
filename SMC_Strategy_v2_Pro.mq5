//+------------------------------------------------------------------+
//|                                         SMC_Strategy_v2_Pro.mq5 |
//|                         Smart Money Concepts Trading Strategy    |
//|                                    Version 3.0 - Correct CHoCH   |
//+------------------------------------------------------------------+
#property copyright "SMC Strategy v3.0"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "3.00"
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
enum ENUM_TREND_STATE
{
   TREND_BULLISH,        // Bullish (HH + HL sequence)
   TREND_BEARISH,        // Bearish (LH + LL sequence)
   TREND_NEUTRAL         // Neutral (no clear structure)
};

enum ENUM_SWING_TYPE
{
   SWING_HH,             // Higher High (structural)
   SWING_HL,             // Higher Low (structural)
   SWING_LH,             // Lower High (structural)
   SWING_LL,             // Lower Low (structural)
   SWING_INTERNAL_HIGH,  // Internal High (not structural)
   SWING_INTERNAL_LOW,   // Internal Low (not structural)
   SWING_UNKNOWN         // Unknown
};

enum ENUM_BREAK_TYPE
{
   BREAK_NONE,           // No Break
   BREAK_BOS_BULL,       // BOS Bullish (continuation)
   BREAK_BOS_BEAR,       // BOS Bearish (continuation)
   BREAK_CHOCH_BULL,     // CHoCH Bullish (reversal from bearish)
   BREAK_CHOCH_BEAR      // CHoCH Bearish (reversal from bullish)
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
// Raw Swing Point (before classification)
struct RawSwing
{
   double         price;
   datetime       time;
   int            bar_index;
   bool           is_high;      // true = swing high, false = swing low
};

// Structural Swing Point (after classification)
struct StructuralSwing
{
   double         price;
   datetime       time;
   int            bar_index;
   bool           is_high;
   ENUM_SWING_TYPE swing_type;  // HH, HL, LH, LL or Internal
   bool           is_structural; // true = structural, false = internal
   string         label;
};

// Structure Break (BOS / CHoCH)
struct StructureBreak
{
   ENUM_BREAK_TYPE type;
   double         break_level;     // The level that was broken
   double         break_price;     // The close price that broke it
   datetime       break_time;
   int            break_bar;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "═══════════ General Settings ═══════════"
input int      Magic_Number = 12345;              // Magic Number
input string   EA_Comment = "SMC_v3";             // Trade Comment

input group "═══════════ Swing Detection ═══════════"
input int      Swing_Period = 5;                  // Swing Period (bars each side)
input int      Lookback_Bars = 200;               // Lookback Bars for Analysis

input group "═══════════ Visual Settings ═══════════"
input bool     Show_Info_Panel = true;            // Show Info Panel
input bool     Show_Structural_Swings = true;     // Show Structural HH/HL/LH/LL
input bool     Show_Internal_Swings = false;      // Show Internal Swings (non-structural)
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
input color    Color_Internal = clrGray;          // Internal Swing Color

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         trade;

// Current Trend State
ENUM_TREND_STATE g_trendState = TREND_NEUTRAL;

// Last Structural Points (KEY VARIABLES!)
double   g_lastStructuralHigh = 0;        // آخر قمة هيكلية حقيقية
datetime g_lastStructuralHighTime = 0;
int      g_lastStructuralHighBar = 0;

double   g_lastStructuralLow = 0;         // آخر قاع هيكلي حقيقي
datetime g_lastStructuralLowTime = 0;
int      g_lastStructuralLowBar = 0;

// For Bullish Trend
double   g_lastBullishStructuralHigh = 0; // آخر HH في الاتجاه الصاعد
datetime g_lastBullishStructuralHighTime = 0;
double   g_lastBullishStructuralLow = 0;  // آخر HL في الاتجاه الصاعد
datetime g_lastBullishStructuralLowTime = 0;

// For Bearish Trend
double   g_lastBearishStructuralHigh = 0; // آخر LH في الاتجاه الهابط
datetime g_lastBearishStructuralHighTime = 0;
double   g_lastBearishStructuralLow = 0;  // آخر LL في الاتجاه الهابط
datetime g_lastBearishStructuralLowTime = 0;

// Arrays
RawSwing g_rawSwings[];                   // All detected raw swings
StructuralSwing g_structuralSwings[];     // Classified structural swings
StructureBreak g_breaks[];                // All BOS/CHoCH breaks

// Last bar time
datetime g_last_bar_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("══════════════════════════════════════════════════════════");
   Print("   SMC Strategy v3.0 - CORRECT CHoCH LOGIC");
   Print("══════════════════════════════════════════════════════════");
   
   trade.SetExpertMagicNumber(Magic_Number);
   
   // Initialize arrays
   ArrayResize(g_rawSwings, 0);
   ArrayResize(g_structuralSwings, 0);
   ArrayResize(g_breaks, 0);
   
   // Reset structural variables
   ResetStructuralVariables();
   
   // Delete old objects
   ObjectsDeleteAll(0, "SMC_");
   
   // Initial analysis
   FullMarketAnalysis();
   
   // Draw info panel
   if(Show_Info_Panel)
      DrawInfoPanel();
   
   Print("   Symbol: ", _Symbol);
   Print("   Timeframe: ", EnumToString((ENUM_TIMEFRAMES)Period()));
   Print("══════════════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Reset Structural Variables                                        |
//+------------------------------------------------------------------+
void ResetStructuralVariables()
{
   g_trendState = TREND_NEUTRAL;
   
   g_lastStructuralHigh = 0;
   g_lastStructuralHighTime = 0;
   g_lastStructuralHighBar = 0;
   
   g_lastStructuralLow = 0;
   g_lastStructuralLowTime = 0;
   g_lastStructuralLowBar = 0;
   
   g_lastBullishStructuralHigh = 0;
   g_lastBullishStructuralHighTime = 0;
   g_lastBullishStructuralLow = 0;
   g_lastBullishStructuralLowTime = 0;
   
   g_lastBearishStructuralHigh = 0;
   g_lastBearishStructuralHighTime = 0;
   g_lastBearishStructuralLow = 0;
   g_lastBearishStructuralLowTime = 0;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("Backtest ended - Objects KEPT on chart!");
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
   FindRawSwings();
   
   // Step 2: Classify swings and build structure (THE KEY FUNCTION!)
   ClassifyAndBuildStructure();
   
   // Step 3: Draw everything
   DrawAllVisuals();
}

//+------------------------------------------------------------------+
//| Step 1: Find Raw Swing Points                                     |
//+------------------------------------------------------------------+
void FindRawSwings()
{
   ArrayResize(g_rawSwings, 0);
   
   // We need Swing_Period bars on each side
   for(int i = Swing_Period; i < Lookback_Bars - Swing_Period; i++)
   {
      // Check for Swing High
      if(IsSwingHigh(i))
      {
         RawSwing sw;
         sw.price = iHigh(_Symbol, PERIOD_CURRENT, i);
         sw.time = iTime(_Symbol, PERIOD_CURRENT, i);
         sw.bar_index = i;
         sw.is_high = true;
         
         int size = ArraySize(g_rawSwings);
         ArrayResize(g_rawSwings, size + 1);
         g_rawSwings[size] = sw;
      }
      
      // Check for Swing Low
      if(IsSwingLow(i))
      {
         RawSwing sw;
         sw.price = iLow(_Symbol, PERIOD_CURRENT, i);
         sw.time = iTime(_Symbol, PERIOD_CURRENT, i);
         sw.bar_index = i;
         sw.is_high = false;
         
         int size = ArraySize(g_rawSwings);
         ArrayResize(g_rawSwings, size + 1);
         g_rawSwings[size] = sw;
      }
   }
   
   // Sort by bar_index descending (oldest first for processing)
   SortRawSwingsByBarDesc();
}

//+------------------------------------------------------------------+
//| Check if bar is Swing High                                        |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index)
{
   if(index < Swing_Period) return false;
   
   double high_value = iHigh(_Symbol, PERIOD_CURRENT, index);
   
   // Check left side (more recent bars - lower index)
   for(int i = 1; i <= Swing_Period; i++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, index - i) >= high_value)
         return false;
   }
   
   // Check right side (older bars - higher index)
   for(int i = 1; i <= Swing_Period; i++)
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
bool IsSwingLow(int index)
{
   if(index < Swing_Period) return false;
   
   double low_value = iLow(_Symbol, PERIOD_CURRENT, index);
   
   // Check left side
   for(int i = 1; i <= Swing_Period; i++)
   {
      if(iLow(_Symbol, PERIOD_CURRENT, index - i) <= low_value)
         return false;
   }
   
   // Check right side
   for(int i = 1; i <= Swing_Period; i++)
   {
      if(index + i >= Bars(_Symbol, PERIOD_CURRENT))
         return false;
      if(iLow(_Symbol, PERIOD_CURRENT, index + i) <= low_value)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Sort Raw Swings by bar_index (descending = oldest first)          |
//+------------------------------------------------------------------+
void SortRawSwingsByBarDesc()
{
   int total = ArraySize(g_rawSwings);
   for(int i = 0; i < total - 1; i++)
   {
      for(int j = i + 1; j < total; j++)
      {
         // Larger bar_index = older bar, should come first
         if(g_rawSwings[j].bar_index > g_rawSwings[i].bar_index)
         {
            RawSwing temp = g_rawSwings[i];
            g_rawSwings[i] = g_rawSwings[j];
            g_rawSwings[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Step 2: CLASSIFY AND BUILD STRUCTURE (THE CORE LOGIC!)            |
//+------------------------------------------------------------------+
void ClassifyAndBuildStructure()
{
   ArrayResize(g_structuralSwings, 0);
   ArrayResize(g_breaks, 0);
   ResetStructuralVariables();
   
   int total_raw = ArraySize(g_rawSwings);
   if(total_raw < 4) return;
   
   // Process swings from OLDEST to NEWEST
   // g_rawSwings is sorted with oldest first (highest bar_index first)
   
   for(int i = 0; i < total_raw; i++)
   {
      RawSwing raw = g_rawSwings[i];
      
      // Create structural swing entry
      StructuralSwing ss;
      ss.price = raw.price;
      ss.time = raw.time;
      ss.bar_index = raw.bar_index;
      ss.is_high = raw.is_high;
      ss.is_structural = false;  // Default: not structural
      ss.swing_type = raw.is_high ? SWING_INTERNAL_HIGH : SWING_INTERNAL_LOW;
      ss.label = "";
      
      if(raw.is_high)
      {
         // ═══════════════════════════════════════════════════════════
         // PROCESSING A SWING HIGH
         // ═══════════════════════════════════════════════════════════
         
         // First check: Is this breaking a bearish structural high? (CHoCH Bull)
         if(g_trendState == TREND_BEARISH && g_lastBearishStructuralHigh > 0)
         {
            // Check if any bar between last structural point and this swing
            // closed ABOVE the last bearish structural high
            int check_bar = FindBreakBar(raw.bar_index, g_lastBearishStructuralHighTime, 
                                         g_lastBearishStructuralHigh, true);
            
            if(check_bar > 0)
            {
               // CHoCH BULLISH! Price closed above last LH
               StructureBreak brk;
               brk.type = BREAK_CHOCH_BULL;
               brk.break_level = g_lastBearishStructuralHigh;
               brk.break_price = iClose(_Symbol, PERIOD_CURRENT, check_bar);
               brk.break_time = iTime(_Symbol, PERIOD_CURRENT, check_bar);
               brk.break_bar = check_bar;
               
               int brk_size = ArraySize(g_breaks);
               ArrayResize(g_breaks, brk_size + 1);
               g_breaks[brk_size] = brk;
               
               // Change trend to BULLISH
               g_trendState = TREND_BULLISH;
               
               // This high becomes the first HH of new bullish trend
               ss.is_structural = true;
               ss.swing_type = SWING_HH;
               ss.label = "HH";
               
               g_lastBullishStructuralHigh = raw.price;
               g_lastBullishStructuralHighTime = raw.time;
               g_lastStructuralHigh = raw.price;
               g_lastStructuralHighTime = raw.time;
               g_lastStructuralHighBar = raw.bar_index;
            }
         }
         
         // If we're in BULLISH trend
         if(g_trendState == TREND_BULLISH && !ss.is_structural)
         {
            // Is this high HIGHER than last structural high? → HH (structural)
            if(raw.price > g_lastBullishStructuralHigh || g_lastBullishStructuralHigh == 0)
            {
               ss.is_structural = true;
               ss.swing_type = SWING_HH;
               ss.label = "HH";
               
               // Check for BOS (breaking previous HH)
               if(g_lastBullishStructuralHigh > 0)
               {
                  int check_bar = FindBreakBar(raw.bar_index, g_lastBullishStructuralHighTime,
                                               g_lastBullishStructuralHigh, true);
                  if(check_bar > 0)
                  {
                     StructureBreak brk;
                     brk.type = BREAK_BOS_BULL;
                     brk.break_level = g_lastBullishStructuralHigh;
                     brk.break_price = iClose(_Symbol, PERIOD_CURRENT, check_bar);
                     brk.break_time = iTime(_Symbol, PERIOD_CURRENT, check_bar);
                     brk.break_bar = check_bar;
                     
                     int brk_size = ArraySize(g_breaks);
                     ArrayResize(g_breaks, brk_size + 1);
                     g_breaks[brk_size] = brk;
                  }
               }
               
               // Update last structural high
               g_lastBullishStructuralHigh = raw.price;
               g_lastBullishStructuralHighTime = raw.time;
               g_lastStructuralHigh = raw.price;
               g_lastStructuralHighTime = raw.time;
               g_lastStructuralHighBar = raw.bar_index;
            }
            else
            {
               // This high is LOWER than last structural high → Internal (not structural)
               ss.is_structural = false;
               ss.swing_type = SWING_INTERNAL_HIGH;
               ss.label = "iH";
            }
         }
         
         // If we're in BEARISH trend
         if(g_trendState == TREND_BEARISH && !ss.is_structural)
         {
            // Is this high LOWER than last structural high? → LH (structural)
            if(raw.price < g_lastBearishStructuralHigh || g_lastBearishStructuralHigh == 0)
            {
               ss.is_structural = true;
               ss.swing_type = SWING_LH;
               ss.label = "LH";
               
               // Update
               g_lastBearishStructuralHigh = raw.price;
               g_lastBearishStructuralHighTime = raw.time;
               g_lastStructuralHigh = raw.price;
               g_lastStructuralHighTime = raw.time;
               g_lastStructuralHighBar = raw.bar_index;
            }
            else
            {
               // This high is HIGHER than last LH → Internal
               ss.is_structural = false;
               ss.swing_type = SWING_INTERNAL_HIGH;
               ss.label = "iH";
            }
         }
         
         // If NEUTRAL trend - initialize
         if(g_trendState == TREND_NEUTRAL && !ss.is_structural)
         {
            if(g_lastStructuralHigh == 0)
            {
               // First high we see
               ss.is_structural = true;
               ss.swing_type = SWING_HH;  // Will be reclassified later
               ss.label = "H";
               
               g_lastStructuralHigh = raw.price;
               g_lastStructuralHighTime = raw.time;
               g_lastStructuralHighBar = raw.bar_index;
            }
            else if(raw.price > g_lastStructuralHigh)
            {
               // Higher high - start bullish
               ss.is_structural = true;
               ss.swing_type = SWING_HH;
               ss.label = "HH";
               
               g_trendState = TREND_BULLISH;
               g_lastBullishStructuralHigh = raw.price;
               g_lastBullishStructuralHighTime = raw.time;
               g_lastStructuralHigh = raw.price;
               g_lastStructuralHighTime = raw.time;
               g_lastStructuralHighBar = raw.bar_index;
            }
            else if(raw.price < g_lastStructuralHigh)
            {
               // Lower high - start bearish
               ss.is_structural = true;
               ss.swing_type = SWING_LH;
               ss.label = "LH";
               
               g_trendState = TREND_BEARISH;
               g_lastBearishStructuralHigh = raw.price;
               g_lastBearishStructuralHighTime = raw.time;
               g_lastStructuralHigh = raw.price;
               g_lastStructuralHighTime = raw.time;
               g_lastStructuralHighBar = raw.bar_index;
            }
         }
      }
      else
      {
         // ═══════════════════════════════════════════════════════════
         // PROCESSING A SWING LOW
         // ═══════════════════════════════════════════════════════════
         
         // First check: Is this breaking a bullish structural low? (CHoCH Bear)
         if(g_trendState == TREND_BULLISH && g_lastBullishStructuralLow > 0)
         {
            // Check if any bar closed BELOW the last bullish structural low (HL)
            int check_bar = FindBreakBar(raw.bar_index, g_lastBullishStructuralLowTime,
                                         g_lastBullishStructuralLow, false);
            
            if(check_bar > 0)
            {
               // CHoCH BEARISH! Price closed below last HL
               StructureBreak brk;
               brk.type = BREAK_CHOCH_BEAR;
               brk.break_level = g_lastBullishStructuralLow;
               brk.break_price = iClose(_Symbol, PERIOD_CURRENT, check_bar);
               brk.break_time = iTime(_Symbol, PERIOD_CURRENT, check_bar);
               brk.break_bar = check_bar;
               
               int brk_size = ArraySize(g_breaks);
               ArrayResize(g_breaks, brk_size + 1);
               g_breaks[brk_size] = brk;
               
               // Change trend to BEARISH
               g_trendState = TREND_BEARISH;
               
               // This low becomes the first LL of new bearish trend
               ss.is_structural = true;
               ss.swing_type = SWING_LL;
               ss.label = "LL";
               
               g_lastBearishStructuralLow = raw.price;
               g_lastBearishStructuralLowTime = raw.time;
               g_lastStructuralLow = raw.price;
               g_lastStructuralLowTime = raw.time;
               g_lastStructuralLowBar = raw.bar_index;
            }
         }
         
         // If we're in BEARISH trend
         if(g_trendState == TREND_BEARISH && !ss.is_structural)
         {
            // Is this low LOWER than last structural low? → LL (structural)
            if(raw.price < g_lastBearishStructuralLow || g_lastBearishStructuralLow == 0)
            {
               ss.is_structural = true;
               ss.swing_type = SWING_LL;
               ss.label = "LL";
               
               // Check for BOS (breaking previous LL)
               if(g_lastBearishStructuralLow > 0)
               {
                  int check_bar = FindBreakBar(raw.bar_index, g_lastBearishStructuralLowTime,
                                               g_lastBearishStructuralLow, false);
                  if(check_bar > 0)
                  {
                     StructureBreak brk;
                     brk.type = BREAK_BOS_BEAR;
                     brk.break_level = g_lastBearishStructuralLow;
                     brk.break_price = iClose(_Symbol, PERIOD_CURRENT, check_bar);
                     brk.break_time = iTime(_Symbol, PERIOD_CURRENT, check_bar);
                     brk.break_bar = check_bar;
                     
                     int brk_size = ArraySize(g_breaks);
                     ArrayResize(g_breaks, brk_size + 1);
                     g_breaks[brk_size] = brk;
                  }
               }
               
               // Update
               g_lastBearishStructuralLow = raw.price;
               g_lastBearishStructuralLowTime = raw.time;
               g_lastStructuralLow = raw.price;
               g_lastStructuralLowTime = raw.time;
               g_lastStructuralLowBar = raw.bar_index;
            }
            else
            {
               // This low is HIGHER than last LL → Internal
               ss.is_structural = false;
               ss.swing_type = SWING_INTERNAL_LOW;
               ss.label = "iL";
            }
         }
         
         // If we're in BULLISH trend
         if(g_trendState == TREND_BULLISH && !ss.is_structural)
         {
            // Is this low HIGHER than last structural low? → HL (structural)
            if(raw.price > g_lastBullishStructuralLow || g_lastBullishStructuralLow == 0)
            {
               ss.is_structural = true;
               ss.swing_type = SWING_HL;
               ss.label = "HL";
               
               // Update
               g_lastBullishStructuralLow = raw.price;
               g_lastBullishStructuralLowTime = raw.time;
               g_lastStructuralLow = raw.price;
               g_lastStructuralLowTime = raw.time;
               g_lastStructuralLowBar = raw.bar_index;
            }
            else
            {
               // This low is LOWER than last HL → Internal
               ss.is_structural = false;
               ss.swing_type = SWING_INTERNAL_LOW;
               ss.label = "iL";
            }
         }
         
         // If NEUTRAL trend - initialize
         if(g_trendState == TREND_NEUTRAL && !ss.is_structural)
         {
            if(g_lastStructuralLow == 0)
            {
               // First low we see
               ss.is_structural = true;
               ss.swing_type = SWING_LL;
               ss.label = "L";
               
               g_lastStructuralLow = raw.price;
               g_lastStructuralLowTime = raw.time;
               g_lastStructuralLowBar = raw.bar_index;
            }
            else if(raw.price < g_lastStructuralLow)
            {
               // Lower low - confirm bearish
               ss.is_structural = true;
               ss.swing_type = SWING_LL;
               ss.label = "LL";
               
               if(g_trendState == TREND_NEUTRAL)
               {
                  g_trendState = TREND_BEARISH;
                  g_lastBearishStructuralLow = raw.price;
                  g_lastBearishStructuralLowTime = raw.time;
               }
               g_lastStructuralLow = raw.price;
               g_lastStructuralLowTime = raw.time;
               g_lastStructuralLowBar = raw.bar_index;
            }
            else if(raw.price > g_lastStructuralLow)
            {
               // Higher low - confirm bullish
               ss.is_structural = true;
               ss.swing_type = SWING_HL;
               ss.label = "HL";
               
               if(g_trendState == TREND_NEUTRAL)
               {
                  g_trendState = TREND_BULLISH;
                  g_lastBullishStructuralLow = raw.price;
                  g_lastBullishStructuralLowTime = raw.time;
               }
               g_lastStructuralLow = raw.price;
               g_lastStructuralLowTime = raw.time;
               g_lastStructuralLowBar = raw.bar_index;
            }
         }
      }
      
      // Add to structural swings array
      int ss_size = ArraySize(g_structuralSwings);
      ArrayResize(g_structuralSwings, ss_size + 1);
      g_structuralSwings[ss_size] = ss;
   }
   
   // Sort structural swings by bar_index ascending (most recent first)
   SortStructuralSwingsByBarAsc();
   
   // Sort breaks by bar_index ascending (most recent first)
   SortBreaksByBarAsc();
   
   Print("Trend: ", EnumToString(g_trendState), 
         " | Structural Swings: ", CountStructuralSwings(),
         " | Breaks: ", ArraySize(g_breaks));
}

//+------------------------------------------------------------------+
//| Find the bar where price CLOSED beyond a level                    |
//| Returns bar index if found, 0 if not found                        |
//+------------------------------------------------------------------+
int FindBreakBar(int swing_bar, datetime level_time, double level_price, bool break_above)
{
   // Search from the level time to the swing bar
   int level_bar = iBarShift(_Symbol, PERIOD_CURRENT, level_time);
   
   // Search from level_bar towards swing_bar (towards more recent)
   for(int bar = level_bar - 1; bar >= swing_bar; bar--)
   {
      if(bar < 0) break;
      
      double close_price = iClose(_Symbol, PERIOD_CURRENT, bar);
      
      if(break_above)
      {
         // Looking for close ABOVE level
         if(close_price > level_price)
            return bar;
      }
      else
      {
         // Looking for close BELOW level
         if(close_price < level_price)
            return bar;
      }
   }
   
   return 0;  // Not found
}

//+------------------------------------------------------------------+
//| Count Structural Swings                                           |
//+------------------------------------------------------------------+
int CountStructuralSwings()
{
   int count = 0;
   for(int i = 0; i < ArraySize(g_structuralSwings); i++)
   {
      if(g_structuralSwings[i].is_structural)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Sort Structural Swings by bar_index ascending                     |
//+------------------------------------------------------------------+
void SortStructuralSwingsByBarAsc()
{
   int total = ArraySize(g_structuralSwings);
   for(int i = 0; i < total - 1; i++)
   {
      for(int j = i + 1; j < total; j++)
      {
         if(g_structuralSwings[j].bar_index < g_structuralSwings[i].bar_index)
         {
            StructuralSwing temp = g_structuralSwings[i];
            g_structuralSwings[i] = g_structuralSwings[j];
            g_structuralSwings[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Sort Breaks by bar_index ascending                                |
//+------------------------------------------------------------------+
void SortBreaksByBarAsc()
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
   // Clear old objects if Show_Only_Latest
   if(Show_Only_Latest)
   {
      ObjectsDeleteAll(0, "SMC_SW_");
      ObjectsDeleteAll(0, "SMC_BRK_");
      ObjectsDeleteAll(0, "SMC_LINE_");
   }
   
   // Draw structural swings
   if(Show_Structural_Swings)
      DrawStructuralSwings();
   
   // Draw internal swings (optional)
   if(Show_Internal_Swings)
      DrawInternalSwings();
   
   // Draw structure lines
   if(Show_Structure_Lines)
      DrawStructureLines();
   
   // Draw breaks (BOS/CHoCH)
   if(Show_Break_Labels)
      DrawBreaks();
}

//+------------------------------------------------------------------+
//| Draw Structural Swings (HH, HL, LH, LL)                           |
//+------------------------------------------------------------------+
void DrawStructuralSwings()
{
   int drawn = 0;
   int max_draw = Show_Only_Latest ? Latest_Count : 100;
   
   for(int i = 0; i < ArraySize(g_structuralSwings) && drawn < max_draw; i++)
   {
      StructuralSwing ss = g_structuralSwings[i];
      
      if(!ss.is_structural) continue;
      
      color clr = Color_HH;
      int arrow_code = 234;  // Down arrow for highs
      ENUM_ANCHOR_POINT anchor = ANCHOR_BOTTOM;
      double label_offset = 50 * _Point;
      
      switch(ss.swing_type)
      {
         case SWING_HH:
            clr = Color_HH;
            arrow_code = 234;
            anchor = ANCHOR_BOTTOM;
            label_offset = 50 * _Point;
            break;
         case SWING_HL:
            clr = Color_HL;
            arrow_code = 233;
            anchor = ANCHOR_TOP;
            label_offset = -50 * _Point;
            break;
         case SWING_LH:
            clr = Color_LH;
            arrow_code = 234;
            anchor = ANCHOR_BOTTOM;
            label_offset = 50 * _Point;
            break;
         case SWING_LL:
            clr = Color_LL;
            arrow_code = 233;
            anchor = ANCHOR_TOP;
            label_offset = -50 * _Point;
            break;
         default:
            continue;
      }
      
      // Draw arrow
      string arrow_name = "SMC_SW_" + IntegerToString(drawn) + "_arr";
      ObjectDelete(0, arrow_name);
      ObjectCreate(0, arrow_name, OBJ_ARROW, 0, ss.time, ss.price);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, arrow_name, OBJPROP_ANCHOR, anchor);
      
      // Draw label
      string label_name = "SMC_SW_" + IntegerToString(drawn) + "_lbl";
      ObjectDelete(0, label_name);
      ObjectCreate(0, label_name, OBJ_TEXT, 0, ss.time, ss.price + label_offset);
      ObjectSetString(0, label_name, OBJPROP_TEXT, ss.label);
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, label_name, OBJPROP_FONT, "Arial Bold");
      
      // Draw horizontal line
      string hline_name = "SMC_SW_" + IntegerToString(drawn) + "_hline";
      datetime end_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      ObjectDelete(0, hline_name);
      ObjectCreate(0, hline_name, OBJ_TREND, 0, ss.time, ss.price, end_time, ss.price);
      ObjectSetInteger(0, hline_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, hline_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, hline_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, hline_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, hline_name, OBJPROP_BACK, true);
      
      drawn++;
   }
}

//+------------------------------------------------------------------+
//| Draw Internal Swings (optional)                                   |
//+------------------------------------------------------------------+
void DrawInternalSwings()
{
   int drawn = 0;
   int max_draw = Show_Only_Latest ? Latest_Count : 50;
   
   for(int i = 0; i < ArraySize(g_structuralSwings) && drawn < max_draw; i++)
   {
      StructuralSwing ss = g_structuralSwings[i];
      
      if(ss.is_structural) continue;  // Skip structural ones
      
      int arrow_code = ss.is_high ? 234 : 233;
      double label_offset = ss.is_high ? 30 * _Point : -30 * _Point;
      
      // Draw small arrow
      string arrow_name = "SMC_SW_INT_" + IntegerToString(drawn) + "_arr";
      ObjectDelete(0, arrow_name);
      ObjectCreate(0, arrow_name, OBJ_ARROW, 0, ss.time, ss.price);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, Color_Internal);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 1);
      
      // Draw small label
      string label_name = "SMC_SW_INT_" + IntegerToString(drawn) + "_lbl";
      ObjectDelete(0, label_name);
      ObjectCreate(0, label_name, OBJ_TEXT, 0, ss.time, ss.price + label_offset);
      ObjectSetString(0, label_name, OBJPROP_TEXT, ss.label);
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, Color_Internal);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
      
      drawn++;
   }
}

//+------------------------------------------------------------------+
//| Draw Structure Lines                                              |
//+------------------------------------------------------------------+
void DrawStructureLines()
{
   int line_count = 0;
   int max_lines = Show_Only_Latest ? Latest_Count * 2 : 50;
   
   StructuralSwing prev;
   bool have_prev = false;
   
   // Draw lines connecting structural swings only
   for(int i = ArraySize(g_structuralSwings) - 1; i >= 0 && line_count < max_lines; i--)
   {
      StructuralSwing ss = g_structuralSwings[i];
      
      if(!ss.is_structural) continue;
      
      if(have_prev && prev.is_high != ss.is_high)
      {
         // Connect high to low or low to high
         string line_name = "SMC_LINE_" + IntegerToString(line_count);
         
         color line_color = Color_HH;
         if(prev.is_high && !ss.is_high)
            line_color = Color_LH;  // High to Low = bearish move
         else
            line_color = Color_HL;  // Low to High = bullish move
         
         ObjectDelete(0, line_name);
         ObjectCreate(0, line_name, OBJ_TREND, 0, 
                      prev.time, prev.price,
                      ss.time, ss.price);
         ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
         ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
         
         line_count++;
      }
      
      prev = ss;
      have_prev = true;
   }
}

//+------------------------------------------------------------------+
//| Draw Breaks (BOS / CHoCH)                                         |
//+------------------------------------------------------------------+
void DrawBreaks()
{
   int drawn = 0;
   int max_draw = Show_Only_Latest ? Latest_Count : 50;
   
   for(int i = 0; i < ArraySize(g_breaks) && drawn < max_draw; i++)
   {
      StructureBreak brk = g_breaks[i];
      
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
      
      // Draw break level line
      string line_name = "SMC_BRK_" + IntegerToString(drawn) + "_line";
      datetime end_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      
      ObjectDelete(0, line_name);
      ObjectCreate(0, line_name, OBJ_TREND, 0, brk.break_time, brk.break_level, end_time, brk.break_level);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, label_color);
      ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
      
      // Draw label
      string text_name = "SMC_BRK_" + IntegerToString(drawn) + "_txt";
      ObjectDelete(0, text_name);
      ObjectCreate(0, text_name, OBJ_TEXT, 0, brk.break_time, brk.break_level);
      ObjectSetString(0, text_name, OBJPROP_TEXT, label_text);
      ObjectSetInteger(0, text_name, OBJPROP_COLOR, label_color);
      ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, text_name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      
      // Draw arrow at break point
      string arrow_name = "SMC_BRK_" + IntegerToString(drawn) + "_arr";
      int arrow_code = (brk.type == BREAK_BOS_BULL || brk.type == BREAK_CHOCH_BULL) ? 233 : 234;
      
      ObjectDelete(0, arrow_name);
      ObjectCreate(0, arrow_name, OBJ_ARROW, 0, brk.break_time, brk.break_price);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, label_color);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
      
      drawn++;
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
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_XSIZE, 300);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_YSIZE, 180);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_BGCOLOR, C'20,20,30');
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, panel_name + "_BG", OBJPROP_WIDTH, 2);
   
   // Title
   CreateLabel(panel_name + "_Title", "═══ SMC STRATEGY v3.0 ═══", 20, 30, clrGold, 11);
   
   // Trend State
   CreateLabel(panel_name + "_TrendLbl", "Trend State:", 20, 55, clrWhite, 10);
   CreateLabel(panel_name + "_TrendVal", "---", 140, 55, clrYellow, 10);
   
   // Last Structural High
   CreateLabel(panel_name + "_HighLbl", "Last Struct High:", 20, 80, clrWhite, 10);
   CreateLabel(panel_name + "_HighVal", "---", 140, 80, Color_HH, 10);
   
   // Last Structural Low
   CreateLabel(panel_name + "_LowLbl", "Last Struct Low:", 20, 105, clrWhite, 10);
   CreateLabel(panel_name + "_LowVal", "---", 140, 105, Color_HL, 10);
   
   // Last Break
   CreateLabel(panel_name + "_BreakLbl", "Last Break:", 20, 130, clrWhite, 10);
   CreateLabel(panel_name + "_BreakVal", "---", 140, 130, clrYellow, 10);
   
   // Counts
   CreateLabel(panel_name + "_CountLbl", "Struct/Breaks:", 20, 155, clrWhite, 10);
   CreateLabel(panel_name + "_CountVal", "---", 140, 155, clrCyan, 10);
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
   string panel_name = "SMC_Panel";
   
   // Update Trend State
   string trend_str = "NEUTRAL";
   color trend_color = clrYellow;
   
   if(g_trendState == TREND_BULLISH)
   {
      trend_str = "▲ BULLISH";
      trend_color = clrLime;
   }
   else if(g_trendState == TREND_BEARISH)
   {
      trend_str = "▼ BEARISH";
      trend_color = clrRed;
   }
   
   ObjectSetString(0, panel_name + "_TrendVal", OBJPROP_TEXT, trend_str);
   ObjectSetInteger(0, panel_name + "_TrendVal", OBJPROP_COLOR, trend_color);
   
   // Update Last Structural High
   if(g_lastStructuralHigh > 0)
   {
      string high_text = DoubleToString(g_lastStructuralHigh, _Digits);
      ObjectSetString(0, panel_name + "_HighVal", OBJPROP_TEXT, high_text);
   }
   
   // Update Last Structural Low
   if(g_lastStructuralLow > 0)
   {
      string low_text = DoubleToString(g_lastStructuralLow, _Digits);
      ObjectSetString(0, panel_name + "_LowVal", OBJPROP_TEXT, low_text);
   }
   
   // Update Last Break
   string break_str = "None";
   color break_color = clrGray;
   
   if(ArraySize(g_breaks) > 0)
   {
      StructureBreak last_brk = g_breaks[0];
      switch(last_brk.type)
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
   }
   
   ObjectSetString(0, panel_name + "_BreakVal", OBJPROP_TEXT, break_str);
   ObjectSetInteger(0, panel_name + "_BreakVal", OBJPROP_COLOR, break_color);
   
   // Update Counts
   string count_str = IntegerToString(CountStructuralSwings()) + " / " + 
                      IntegerToString(ArraySize(g_breaks));
   ObjectSetString(0, panel_name + "_CountVal", OBJPROP_TEXT, count_str);
}
//+------------------------------------------------------------------+
