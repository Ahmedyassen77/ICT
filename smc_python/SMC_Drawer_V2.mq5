//+------------------------------------------------------------------+
//|                                               SMC_Drawer_V2.mq5  |
//|                           Smart Money Concepts - Reference Style |
//|                          Clean visuals matching pro indicators   |
//+------------------------------------------------------------------+
#property copyright "SMC Drawer V2"
#property version   "2.0"
#property indicator_chart_window

#include <Trade\Trade.mqh>

//--- Input parameters
input string   InpJsonFile = "smc_signals_v3.json";  // JSON file name
input int      InpRefreshSec = 5;                     // Refresh interval (seconds)
input bool     InpShowSwings = false;                 // Show swing labels
input bool     InpShowBOS = true;                     // Show BOS
input bool     InpShowCHOCH = true;                   // Show CHoCH
input bool     InpShowOB = true;                      // Show Order Blocks
input color    InpBOSColor = clrDodgerBlue;          // BOS color
input color    InpCHOCHColor = clrMagenta;           // CHoCH color  
input color    InpOBBullColor = clrDodgerBlue;       // Bullish OB color
input color    InpOBBearColor = clrCrimson;          // Bearish OB color
input int      InpLineWidth = 2;                      // Line width
input int      InpOBExtendBars = 50;                  // OB extend bars

//--- Global variables
datetime g_lastUpdate = 0;
string g_prefix = "SMCV2_";
int g_objectCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("SMC Drawer V2 initialized - Reference Style");
   EventSetTimer(InpRefreshSec);
   LoadAndDraw();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Redraw periodically
   static datetime lastDraw = 0;
   if(TimeCurrent() - lastDraw > InpRefreshSec)
   {
      LoadAndDraw();
      lastDraw = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   LoadAndDraw();
}

//+------------------------------------------------------------------+
//| Delete all SMC objects                                             |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, g_prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Load JSON and draw objects                                         |
//+------------------------------------------------------------------+
void LoadAndDraw()
{
   // Read JSON file
   string filepath = InpJsonFile;
   
   int handle = FileOpen(filepath, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("Cannot open file: ", filepath);
      return;
   }
   
   string content = "";
   while(!FileIsEnding(handle))
      content += FileReadString(handle) + "\n";
   FileClose(handle);
   
   // Delete old objects
   DeleteAllObjects();
   g_objectCount = 0;
   
   // Parse and draw
   if(InpShowBOS)
      DrawBOS(content);
   
   if(InpShowCHOCH)
      DrawCHOCH(content);
   
   if(InpShowOB)
      DrawOrderBlocks(content);
   
   if(InpShowSwings)
      DrawSwings(content);
   
   // Update info
   UpdateInfoLabel();
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Draw BOS lines - Extended horizontal style                         |
//+------------------------------------------------------------------+
void DrawBOS(string &content)
{
   int start = 0;
   string section = ExtractSection(content, "\"bos\":", start);
   
   int idx = 0;
   while((start = StringFind(section, "\"type\":", start)) != -1)
   {
      // Extract type
      int typeStart = StringFind(section, "\"", start + 7) + 1;
      int typeEnd = StringFind(section, "\"", typeStart);
      string type = StringSubstr(section, typeStart, typeEnd - typeStart);
      
      // Extract level
      double level = ExtractDouble(section, "\"level\":", start);
      
      // Extract times
      string startTime = ExtractString(section, "\"start_time\":", start);
      string breakTime = ExtractString(section, "\"break_time\":", start);
      
      if(level > 0)
      {
         datetime t1 = StringToTime(startTime);
         datetime t2 = TimeCurrent() + PeriodSeconds() * InpOBExtendBars;
         
         string name = g_prefix + "BOS_" + IntegerToString(idx);
         
         // Create extended line
         ObjectCreate(0, name, OBJ_TREND, 0, t1, level, t2, level);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpBOSColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, InpLineWidth);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         
         // Add BOS label
         string labelName = g_prefix + "BOS_LBL_" + IntegerToString(idx);
         datetime labelTime = StringToTime(breakTime);
         ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, level);
         ObjectSetString(0, labelName, OBJPROP_TEXT, "BOS");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, InpBOSColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
         
         g_objectCount += 2;
         idx++;
      }
      
      start = typeEnd + 1;
   }
}

//+------------------------------------------------------------------+
//| Draw CHoCH lines - Extended horizontal style (different color)     |
//+------------------------------------------------------------------+
void DrawCHOCH(string &content)
{
   int start = 0;
   string section = ExtractSection(content, "\"choch\":", start);
   
   int idx = 0;
   while((start = StringFind(section, "\"type\":", start)) != -1)
   {
      // Extract type
      int typeStart = StringFind(section, "\"", start + 7) + 1;
      int typeEnd = StringFind(section, "\"", typeStart);
      string type = StringSubstr(section, typeStart, typeEnd - typeStart);
      
      // Extract level
      double level = ExtractDouble(section, "\"level\":", start);
      
      // Extract times
      string startTime = ExtractString(section, "\"start_time\":", start);
      string breakTime = ExtractString(section, "\"break_time\":", start);
      
      if(level > 0)
      {
         datetime t1 = StringToTime(startTime);
         datetime t2 = TimeCurrent() + PeriodSeconds() * InpOBExtendBars;
         
         string name = g_prefix + "CHOCH_" + IntegerToString(idx);
         
         // Create extended line - thicker for CHoCH
         ObjectCreate(0, name, OBJ_TREND, 0, t1, level, t2, level);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpCHOCHColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, InpLineWidth + 1);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         
         // Add CHoCH label
         string labelName = g_prefix + "CHOCH_LBL_" + IntegerToString(idx);
         datetime labelTime = StringToTime(breakTime);
         ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, level);
         ObjectSetString(0, labelName, OBJPROP_TEXT, "CHoCH");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, InpCHOCHColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
         
         g_objectCount += 2;
         idx++;
      }
      
      start = typeEnd + 1;
   }
}

//+------------------------------------------------------------------+
//| Draw Order Blocks - Rectangle style                                |
//+------------------------------------------------------------------+
void DrawOrderBlocks(string &content)
{
   int start = 0;
   string section = ExtractSection(content, "\"order_blocks\":", start);
   
   int idx = 0;
   while((start = StringFind(section, "\"type\":", start)) != -1)
   {
      // Extract type
      int typeStart = StringFind(section, "\"", start + 7) + 1;
      int typeEnd = StringFind(section, "\"", typeStart);
      string type = StringSubstr(section, typeStart, typeEnd - typeStart);
      
      // Extract price levels
      double high = ExtractDouble(section, "\"high\":", start);
      double low = ExtractDouble(section, "\"low\":", start);
      
      // Extract time
      string timeStr = ExtractString(section, "\"time\":", start);
      
      if(high > 0 && low > 0)
      {
         datetime t1 = StringToTime(timeStr);
         datetime t2 = TimeCurrent() + PeriodSeconds() * InpOBExtendBars;
         
         string name = g_prefix + "OB_" + IntegerToString(idx);
         
         // Determine color based on type
         color obColor = (type == "BULL") ? InpOBBullColor : InpOBBearColor;
         
         // Create rectangle
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, high, t2, low);
         ObjectSetInteger(0, name, OBJPROP_COLOR, obColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         
         // Set transparency (alpha)
         long clrValue = obColor;
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrValue);
         
         g_objectCount++;
         idx++;
      }
      
      start = typeEnd + 1;
   }
}

//+------------------------------------------------------------------+
//| Draw Swing Points (optional - off by default)                      |
//+------------------------------------------------------------------+
void DrawSwings(string &content)
{
   int start = 0;
   string section = ExtractSection(content, "\"swings\":", start);
   
   int idx = 0;
   while((start = StringFind(section, "\"label\":", start)) != -1)
   {
      // Extract label
      int labelStart = StringFind(section, "\"", start + 8) + 1;
      int labelEnd = StringFind(section, "\"", labelStart);
      string label = StringSubstr(section, labelStart, labelEnd - labelStart);
      
      // Extract price
      double price = ExtractDouble(section, "\"price\":", start);
      
      // Extract time
      string timeStr = ExtractString(section, "\"time\":", start);
      
      if(price > 0 && StringLen(label) > 0)
      {
         datetime t = StringToTime(timeStr);
         
         string name = g_prefix + "SW_" + IntegerToString(idx);
         
         // Determine color and position
         color swColor;
         ENUM_ANCHOR_POINT anchor;
         
         if(label == "HH" || label == "LH")
         {
            swColor = (label == "HH") ? clrLime : clrOrange;
            anchor = ANCHOR_LOWER;
         }
         else
         {
            swColor = (label == "HL") ? clrLime : clrRed;
            anchor = ANCHOR_UPPER;
         }
         
         // Create small label
         ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
         ObjectSetString(0, name, OBJPROP_TEXT, label);
         ObjectSetInteger(0, name, OBJPROP_COLOR, swColor);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
         ObjectSetString(0, name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
         
         g_objectCount++;
         idx++;
      }
      
      start = labelEnd + 1;
   }
}

//+------------------------------------------------------------------+
//| Update info label                                                  |
//+------------------------------------------------------------------+
void UpdateInfoLabel()
{
   string name = g_prefix + "INFO";
   
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   
   string info = "SMC V2: " + IntegerToString(g_objectCount) + " objects";
   info += "\nLast: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
   
   ObjectSetString(0, name, OBJPROP_TEXT, info);
   g_objectCount++;
}

//+------------------------------------------------------------------+
//| Extract section from JSON                                          |
//+------------------------------------------------------------------+
string ExtractSection(string &content, string key, int &startPos)
{
   int keyPos = StringFind(content, key, startPos);
   if(keyPos == -1)
      return "";
   
   int bracketStart = StringFind(content, "[", keyPos);
   if(bracketStart == -1)
      return "";
   
   // Find matching bracket
   int depth = 1;
   int pos = bracketStart + 1;
   
   while(pos < StringLen(content) && depth > 0)
   {
      if(StringGetCharacter(content, pos) == '[')
         depth++;
      else if(StringGetCharacter(content, pos) == ']')
         depth--;
      pos++;
   }
   
   return StringSubstr(content, bracketStart, pos - bracketStart);
}

//+------------------------------------------------------------------+
//| Extract double value from JSON                                     |
//+------------------------------------------------------------------+
double ExtractDouble(string &content, string key, int searchStart)
{
   int keyPos = StringFind(content, key, searchStart);
   if(keyPos == -1 || keyPos > searchStart + 500)
      return 0;
   
   int valueStart = keyPos + StringLen(key);
   
   // Skip whitespace
   while(valueStart < StringLen(content) && 
         (StringGetCharacter(content, valueStart) == ' ' || 
          StringGetCharacter(content, valueStart) == ':'))
      valueStart++;
   
   int valueEnd = valueStart;
   while(valueEnd < StringLen(content))
   {
      ushort ch = StringGetCharacter(content, valueEnd);
      if(ch == ',' || ch == '}' || ch == '\n' || ch == '\r')
         break;
      valueEnd++;
   }
   
   string valueStr = StringSubstr(content, valueStart, valueEnd - valueStart);
   StringTrimLeft(valueStr);
   StringTrimRight(valueStr);
   
   return StringToDouble(valueStr);
}

//+------------------------------------------------------------------+
//| Extract string value from JSON                                     |
//+------------------------------------------------------------------+
string ExtractString(string &content, string key, int searchStart)
{
   int keyPos = StringFind(content, key, searchStart);
   if(keyPos == -1 || keyPos > searchStart + 500)
      return "";
   
   int quoteStart = StringFind(content, "\"", keyPos + StringLen(key));
   if(quoteStart == -1)
      return "";
   
   int quoteEnd = StringFind(content, "\"", quoteStart + 1);
   if(quoteEnd == -1)
      return "";
   
   return StringSubstr(content, quoteStart + 1, quoteEnd - quoteStart - 1);
}
//+------------------------------------------------------------------+
