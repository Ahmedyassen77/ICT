//+------------------------------------------------------------------+
//|                                         SMC_Reader_EA.mq5        |
//|                  EA يقرأ قيم من المؤشر المغلق ويستخدمها           |
//+------------------------------------------------------------------+
#property copyright "SMC Reader"
#property version   "1.00"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string   Indicator_Name = "Smart Money Concepts";  // اسم المؤشر
input bool     Show_Arrows = true;                       // رسم أسهم على الإشارات
input color    Buy_Color = clrLime;                      // لون إشارة الشراء
input color    Sell_Color = clrRed;                      // لون إشارة البيع

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
int g_indicator_handle = INVALID_HANDLE;
datetime g_last_bar = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("===============================================");
   Print("   SMC Reader EA - Reading from .ex5 indicator");
   Print("===============================================");
   
   // محاولة تحميل المؤشر
   g_indicator_handle = iCustom(_Symbol, PERIOD_CURRENT, Indicator_Name);
   
   if(g_indicator_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to load indicator: ", Indicator_Name);
      Print("Make sure the indicator is in MQL5/Indicators folder");
      return INIT_FAILED;
   }
   
   Print("✓ Indicator loaded successfully");
   Print("Indicator Handle: ", g_indicator_handle);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_indicator_handle != INVALID_HANDLE)
      IndicatorRelease(g_indicator_handle);
   
   ObjectsDeleteAll(0, "SMC_");
   Print("SMC Reader EA stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Process only on new bar
   datetime current_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(current_bar == g_last_bar)
      return;
   
   g_last_bar = current_bar;
   
   // قراءة قيم المؤشر
   ReadIndicatorValues();
}

//+------------------------------------------------------------------+
//| قراءة قيم المؤشر                                                  |
//+------------------------------------------------------------------+
void ReadIndicatorValues()
{
   // المؤشرات عادة بترجع قيم في buffers
   // محتاجين نعرف كم buffer فيه
   
   // Try to read different buffers (0-7 usually)
   double buffer0[], buffer1[], buffer2[], buffer3[];
   
   ArraySetAsSeries(buffer0, true);
   ArraySetAsSeries(buffer1, true);
   ArraySetAsSeries(buffer2, true);
   ArraySetAsSeries(buffer3, true);
   
   // Copy data from indicator buffers
   int copied0 = CopyBuffer(g_indicator_handle, 0, 0, 10, buffer0);
   int copied1 = CopyBuffer(g_indicator_handle, 1, 0, 10, buffer1);
   int copied2 = CopyBuffer(g_indicator_handle, 2, 0, 10, buffer2);
   int copied3 = CopyBuffer(g_indicator_handle, 3, 0, 10, buffer3);
   
   // طباعة القيم للفهم
   if(copied0 > 0)
   {
      Print("=== Indicator Values ===");
      Print("Buffer 0: ", buffer0[0], " | ", buffer0[1]);
      
      if(copied1 > 0)
         Print("Buffer 1: ", buffer1[0], " | ", buffer1[1]);
      
      if(copied2 > 0)
         Print("Buffer 2: ", buffer2[0], " | ", buffer2[1]);
      
      if(copied3 > 0)
         Print("Buffer 3: ", buffer3[0], " | ", buffer3[1]);
      
      // Detect signals
      DetectSignals(buffer0, buffer1, buffer2, buffer3);
   }
}

//+------------------------------------------------------------------+
//| كشف الإشارات                                                      |
//+------------------------------------------------------------------+
void DetectSignals(const double &buf0[], const double &buf1[], 
                   const double &buf2[], const double &buf3[])
{
   // مثال: لو buffer0 فيه قيمة غير صفر = إشارة
   
   // Buy signal
   if(buf0[0] != 0 && buf0[0] != EMPTY_VALUE && buf0[1] == 0)
   {
      Print(">>> BUY SIGNAL DETECTED at ", TimeToString(TimeCurrent()));
      
      if(Show_Arrows)
         DrawArrow(TimeCurrent(), iLow(_Symbol, PERIOD_CURRENT, 0), Buy_Color, true);
   }
   
   // Sell signal
   if(buf1[0] != 0 && buf1[0] != EMPTY_VALUE && buf1[1] == 0)
   {
      Print(">>> SELL SIGNAL DETECTED at ", TimeToString(TimeCurrent()));
      
      if(Show_Arrows)
         DrawArrow(TimeCurrent(), iHigh(_Symbol, PERIOD_CURRENT, 0), Sell_Color, false);
   }
}

//+------------------------------------------------------------------+
//| رسم سهم                                                           |
//+------------------------------------------------------------------+
void DrawArrow(datetime time, double price, color clr, bool is_buy)
{
   static int arrow_count = 0;
   arrow_count++;
   
   string name = "SMC_Arrow_" + IntegerToString(arrow_count);
   int code = is_buy ? 233 : 234;  // Up : Down
   double offset = is_buy ? -20 * _Point : 20 * _Point;
   
   ObjectCreate(0, name, OBJ_ARROW, 0, time, price + offset);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
}

//+------------------------------------------------------------------+
//| Get indicator info                                                |
//+------------------------------------------------------------------+
void PrintIndicatorInfo()
{
   if(g_indicator_handle == INVALID_HANDLE)
      return;
   
   // Get number of buffers
   int buffers = 0;
   for(int i = 0; i < 512; i++)
   {
      double test[];
      if(CopyBuffer(g_indicator_handle, i, 0, 1, test) > 0)
         buffers++;
      else
         break;
   }
   
   Print("Indicator has ", buffers, " buffers");
}
//+------------------------------------------------------------------+
