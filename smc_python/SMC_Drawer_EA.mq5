//+------------------------------------------------------------------+
//|                                              SMC_Drawer_EA.mq5   |
//|                     EA بسيط يقرأ JSON من Python ويرسم على الشارت   |
//+------------------------------------------------------------------+
#property copyright "SMC Python Bridge"
#property link      "https://github.com/Ahmedyassen77/ICT"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string   JSON_File = "smc_signals.json";    // ملف JSON
input int      Refresh_Seconds = 5;                // تحديث كل X ثواني
input bool     Draw_Swings = true;                 // رسم Swing Points
input bool     Draw_BOS = true;                    // رسم BOS
input bool     Draw_CHoCH = true;                  // رسم CHoCH
input bool     Draw_OB = true;                     // رسم Order Blocks

input color    Color_HH = clrDodgerBlue;           // لون HH
input color    Color_HL = clrLime;                 // لون HL
input color    Color_LH = clrOrange;               // لون LH
input color    Color_LL = clrRed;                  // لون LL
input color    Color_BOS = clrYellow;              // لون BOS
input color    Color_CHoCH = clrMagenta;           // لون CHoCH
input color    Color_OB_Bull = clrBlue;            // لون OB Bullish
input color    Color_OB_Bear = clrRed;             // لون OB Bearish

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
datetime g_last_check = 0;
int g_obj_count = 0;
string g_json_path;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════");
   Print("   SMC Drawer EA - Reading from Python");
   Print("═══════════════════════════════════════════════════");
   
   // تحديد مسار الملف
   g_json_path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + JSON_File;
   Print("📁 JSON Path: ", g_json_path);
   
   // قراءة أولية
   ReadAndDraw();
   
   // إعداد Timer
   EventSetTimer(Refresh_Seconds);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, "SMC_");
   Print("SMC Drawer EA stopped");
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   ReadAndDraw();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // يمكن إضافة منطق هنا إذا لزم الأمر
}

//+------------------------------------------------------------------+
//| قراءة JSON ورسم العناصر                                           |
//+------------------------------------------------------------------+
void ReadAndDraw()
{
   // مسح الرسومات القديمة
   ObjectsDeleteAll(0, "SMC_");
   g_obj_count = 0;
   
   // قراءة الملف
   string content = ReadFile(JSON_File);
   if(content == "")
   {
      Comment("⏳ Waiting for smc_signals.json from Python...");
      return;
   }
   
   // تحليل JSON يدوياً (MQL5 لا يدعم JSON بشكل مباشر)
   
   // رسم Swing Points
   if(Draw_Swings)
      ParseAndDrawSwings(content);
   
   // رسم BOS
   if(Draw_BOS)
      ParseAndDrawBOS(content);
   
   // رسم CHoCH
   if(Draw_CHoCH)
      ParseAndDrawCHoCH(content);
   
   // رسم Order Blocks
   if(Draw_OB)
      ParseAndDrawOB(content);
   
   // تحديث الشارت
   ChartRedraw(0);
   
   Comment("✅ SMC Drawer: ", g_obj_count, " objects drawn\n",
           "Last update: ", TimeToString(TimeCurrent()));
}

//+------------------------------------------------------------------+
//| قراءة ملف نصي                                                     |
//+------------------------------------------------------------------+
string ReadFile(string filename)
{
   int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("⚠️ Cannot open file: ", filename);
      return "";
   }
   
   string content = "";
   while(!FileIsEnding(handle))
   {
      content += FileReadString(handle) + "\n";
   }
   
   FileClose(handle);
   return content;
}

//+------------------------------------------------------------------+
//| تحليل ورسم Swing Points                                           |
//+------------------------------------------------------------------+
void ParseAndDrawSwings(string &json)
{
   // البحث عن قسم swings
   int swings_start = StringFind(json, "\"swings\":");
   if(swings_start < 0) return;
   
   // البحث عن كل swing
   int pos = swings_start;
   
   while(true)
   {
      // البحث عن label
      int label_pos = StringFind(json, "\"label\":", pos);
      if(label_pos < 0 || label_pos > StringFind(json, "\"bos\":", swings_start)) break;
      
      // استخراج label
      string label = ExtractValue(json, "\"label\":", label_pos);
      
      // استخراج price
      int price_pos = StringFind(json, "\"price\":", pos);
      double price = StringToDouble(ExtractValue(json, "\"price\":", price_pos));
      
      // استخراج time
      int time_pos = StringFind(json, "\"time\":", pos);
      string time_str = ExtractValue(json, "\"time\":", time_pos);
      datetime time = ParseDateTime(time_str);
      
      if(price > 0 && time > 0)
      {
         DrawSwingPoint(label, price, time);
      }
      
      // الانتقال للـ swing التالي
      pos = label_pos + 10;
   }
}

//+------------------------------------------------------------------+
//| رسم Swing Point                                                   |
//+------------------------------------------------------------------+
void DrawSwingPoint(string label, double price, datetime time)
{
   g_obj_count++;
   
   color clr = clrWhite;
   int arrow_code = 159;
   double offset = 0;
   
   if(label == "HH")
   {
      clr = Color_HH;
      arrow_code = 234;  // سهم لأسفل
      offset = 20 * _Point;
   }
   else if(label == "HL")
   {
      clr = Color_HL;
      arrow_code = 233;  // سهم لأعلى
      offset = -20 * _Point;
   }
   else if(label == "LH")
   {
      clr = Color_LH;
      arrow_code = 234;
      offset = 20 * _Point;
   }
   else if(label == "LL")
   {
      clr = Color_LL;
      arrow_code = 233;
      offset = -20 * _Point;
   }
   else if(label == "SH")
   {
      clr = clrGray;
      arrow_code = 234;
      offset = 20 * _Point;
   }
   else if(label == "SL")
   {
      clr = clrGray;
      arrow_code = 233;
      offset = -20 * _Point;
   }
   
   // رسم السهم
   string arr_name = "SMC_SW_" + IntegerToString(g_obj_count);
   ObjectCreate(0, arr_name, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, arr_name, OBJPROP_ARROWCODE, arrow_code);
   ObjectSetInteger(0, arr_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, arr_name, OBJPROP_WIDTH, 2);
   
   // رسم النص
   string txt_name = "SMC_SWT_" + IntegerToString(g_obj_count);
   ObjectCreate(0, txt_name, OBJ_TEXT, 0, time, price + offset);
   ObjectSetString(0, txt_name, OBJPROP_TEXT, label);
   ObjectSetInteger(0, txt_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, txt_name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, txt_name, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| تحليل ورسم BOS                                                    |
//+------------------------------------------------------------------+
void ParseAndDrawBOS(string &json)
{
   int bos_start = StringFind(json, "\"bos\":");
   if(bos_start < 0) return;
   
   int bos_end = StringFind(json, "\"choch\":", bos_start);
   if(bos_end < 0) bos_end = StringLen(json);
   
   int pos = bos_start;
   
   while(pos < bos_end)
   {
      int type_pos = StringFind(json, "\"type\":", pos);
      if(type_pos < 0 || type_pos > bos_end) break;
      
      string type = ExtractValue(json, "\"type\":", type_pos);
      
      int level_pos = StringFind(json, "\"level\":", pos);
      double level = StringToDouble(ExtractValue(json, "\"level\":", level_pos));
      
      int start_time_pos = StringFind(json, "\"start_time\":", pos);
      datetime start_time = ParseDateTime(ExtractValue(json, "\"start_time\":", start_time_pos));
      
      int break_time_pos = StringFind(json, "\"break_time\":", pos);
      datetime break_time = ParseDateTime(ExtractValue(json, "\"break_time\":", break_time_pos));
      
      if(level > 0 && start_time > 0 && break_time > 0)
      {
         DrawBOSLine(type, level, start_time, break_time);
      }
      
      pos = type_pos + 20;
   }
}

//+------------------------------------------------------------------+
//| رسم خط BOS                                                        |
//+------------------------------------------------------------------+
void DrawBOSLine(string type, double level, datetime start_time, datetime end_time)
{
   g_obj_count++;
   
   string line_name = "SMC_BOS_" + IntegerToString(g_obj_count);
   ObjectCreate(0, line_name, OBJ_TREND, 0, start_time, level, end_time, level);
   ObjectSetInteger(0, line_name, OBJPROP_COLOR, Color_BOS);
   ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
   
   // النص
   string txt_name = "SMC_BOST_" + IntegerToString(g_obj_count);
   ObjectCreate(0, txt_name, OBJ_TEXT, 0, end_time, level);
   ObjectSetString(0, txt_name, OBJPROP_TEXT, "BOS");
   ObjectSetInteger(0, txt_name, OBJPROP_COLOR, Color_BOS);
   ObjectSetInteger(0, txt_name, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, txt_name, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| تحليل ورسم CHoCH                                                  |
//+------------------------------------------------------------------+
void ParseAndDrawCHoCH(string &json)
{
   int choch_start = StringFind(json, "\"choch\":");
   if(choch_start < 0) return;
   
   int choch_end = StringFind(json, "\"order_blocks\":", choch_start);
   if(choch_end < 0) choch_end = StringLen(json);
   
   int pos = choch_start;
   
   while(pos < choch_end)
   {
      int type_pos = StringFind(json, "\"type\":", pos);
      if(type_pos < 0 || type_pos > choch_end) break;
      
      string type = ExtractValue(json, "\"type\":", type_pos);
      
      int level_pos = StringFind(json, "\"level\":", pos);
      double level = StringToDouble(ExtractValue(json, "\"level\":", level_pos));
      
      int start_time_pos = StringFind(json, "\"start_time\":", pos);
      datetime start_time = ParseDateTime(ExtractValue(json, "\"start_time\":", start_time_pos));
      
      int break_time_pos = StringFind(json, "\"break_time\":", pos);
      datetime break_time = ParseDateTime(ExtractValue(json, "\"break_time\":", break_time_pos));
      
      if(level > 0 && start_time > 0 && break_time > 0)
      {
         DrawCHoCHLine(type, level, start_time, break_time);
      }
      
      pos = type_pos + 20;
   }
}

//+------------------------------------------------------------------+
//| رسم خط CHoCH                                                      |
//+------------------------------------------------------------------+
void DrawCHoCHLine(string type, double level, datetime start_time, datetime end_time)
{
   g_obj_count++;
   
   string line_name = "SMC_CHOCH_" + IntegerToString(g_obj_count);
   ObjectCreate(0, line_name, OBJ_TREND, 0, start_time, level, end_time, level);
   ObjectSetInteger(0, line_name, OBJPROP_COLOR, Color_CHoCH);
   ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
   
   // النص
   string txt_name = "SMC_CHOCHT_" + IntegerToString(g_obj_count);
   ObjectCreate(0, txt_name, OBJ_TEXT, 0, end_time, level);
   ObjectSetString(0, txt_name, OBJPROP_TEXT, "CHoCH");
   ObjectSetInteger(0, txt_name, OBJPROP_COLOR, Color_CHoCH);
   ObjectSetInteger(0, txt_name, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, txt_name, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| تحليل ورسم Order Blocks                                           |
//+------------------------------------------------------------------+
void ParseAndDrawOB(string &json)
{
   int ob_start = StringFind(json, "\"order_blocks\":");
   if(ob_start < 0) return;
   
   int pos = ob_start;
   
   while(true)
   {
      int type_pos = StringFind(json, "\"type\":", pos);
      if(type_pos < 0) break;
      
      string type = ExtractValue(json, "\"type\":", type_pos);
      if(StringFind(type, "OB") < 0) break;
      
      int high_pos = StringFind(json, "\"high\":", pos);
      double high = StringToDouble(ExtractValue(json, "\"high\":", high_pos));
      
      int low_pos = StringFind(json, "\"low\":", pos);
      double low = StringToDouble(ExtractValue(json, "\"low\":", low_pos));
      
      int time_pos = StringFind(json, "\"time\":", pos);
      datetime time = ParseDateTime(ExtractValue(json, "\"time\":", time_pos));
      
      if(high > 0 && low > 0 && time > 0)
      {
         DrawOrderBlock(type, high, low, time);
      }
      
      pos = type_pos + 20;
   }
}

//+------------------------------------------------------------------+
//| رسم Order Block                                                   |
//+------------------------------------------------------------------+
void DrawOrderBlock(string type, double high, double low, datetime time)
{
   g_obj_count++;
   
   color clr = (StringFind(type, "BULL") >= 0) ? Color_OB_Bull : Color_OB_Bear;
   string label = (StringFind(type, "BULL") >= 0) ? "OB+" : "OB-";
   
   // رسم المستطيل
   string rect_name = "SMC_OB_" + IntegerToString(g_obj_count);
   datetime end_time = time + PeriodSeconds() * 20;  // امتداد 20 شمعة
   
   ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, time, high, end_time, low);
   ObjectSetInteger(0, rect_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
   ObjectSetInteger(0, rect_name, OBJPROP_BACK, true);
   
   // النص
   string txt_name = "SMC_OBT_" + IntegerToString(g_obj_count);
   ObjectCreate(0, txt_name, OBJ_TEXT, 0, time, (high + low) / 2);
   ObjectSetString(0, txt_name, OBJPROP_TEXT, label);
   ObjectSetInteger(0, txt_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, txt_name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, txt_name, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| استخراج قيمة من JSON                                              |
//+------------------------------------------------------------------+
string ExtractValue(string &json, string key, int start_pos)
{
   if(start_pos < 0) return "";
   
   int value_start = start_pos + StringLen(key);
   
   // تخطي المسافات
   while(value_start < StringLen(json) && 
         (StringGetCharacter(json, value_start) == ' ' || 
          StringGetCharacter(json, value_start) == '"'))
   {
      value_start++;
   }
   
   // إيجاد نهاية القيمة
   int value_end = value_start;
   while(value_end < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, value_end);
      if(ch == ',' || ch == '"' || ch == '}' || ch == ']' || ch == '\n')
         break;
      value_end++;
   }
   
   return StringSubstr(json, value_start, value_end - value_start);
}

//+------------------------------------------------------------------+
//| تحويل نص التاريخ إلى datetime                                     |
//+------------------------------------------------------------------+
datetime ParseDateTime(string dt_str)
{
   // التنسيق المتوقع: 2024-01-15 10:00:00
   // أو: 2024-01-15T10:00:00
   
   StringReplace(dt_str, "T", " ");
   StringReplace(dt_str, "-", ".");
   
   // حذف الميكروثواني إن وجدت
   int dot_pos = StringFind(dt_str, ".", 10);
   if(dot_pos > 0)
      dt_str = StringSubstr(dt_str, 0, dot_pos);
   
   return StringToTime(dt_str);
}
//+------------------------------------------------------------------+
