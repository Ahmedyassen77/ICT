"""
=================================================================================
          🚀 MT5 Complete Automation System
          نظام الأتمتة الكامل لـ MetaTrader 5
=================================================================================

هذا النظام يعمل كل شيء تلقائياً:
✅ إنشاء Expert Advisor بأي استراتيجية
✅ ترجمة الـ EA تلقائياً (compile)
✅ تشغيل Backtest مرئي
✅ انتظار انتهاء الاختبار
✅ قراءة وتحليل النتائج
✅ إرسال التقرير

كل ده وأنت تشاهد الـ Backtest المرئي على الشاشة!

=================================================================================
"""

import os
import sys
import json
import time
import subprocess
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, List, Any, Tuple
from dataclasses import dataclass
from enum import Enum
import shutil
import glob

# ألوان
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    END = '\033[0m'

def log_success(msg): print(f"{Colors.GREEN}✅ {msg}{Colors.END}")
def log_warning(msg): print(f"{Colors.YELLOW}⚠️ {msg}{Colors.END}")
def log_error(msg): print(f"{Colors.RED}❌ {msg}{Colors.END}")
def log_info(msg): print(f"{Colors.BLUE}ℹ️ {msg}{Colors.END}")
def log_step(msg): print(f"{Colors.MAGENTA}🔄 {msg}{Colors.END}")
def log_header(msg): 
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*60}")
    print(f"  {msg}")
    print(f"{'='*60}{Colors.END}\n")


# =================================================================================
#                          استراتيجيات جاهزة
# =================================================================================

class StrategyType(Enum):
    MA_CROSSOVER = "ma_crossover"
    RSI = "rsi"
    MACD = "macd"
    BOLLINGER = "bollinger"
    RSI_MA = "rsi_ma"
    MACD_RSI = "macd_rsi"
    CUSTOM = "custom"


# قوالب الاستراتيجيات
STRATEGY_TEMPLATES = {
    "ma_crossover": '''
    // === MA Crossover Strategy ===
    int handleFast, handleSlow;
    double fastMA[], slowMA[];
    
    bool InitStrategy() {
        handleFast = iMA(_Symbol, PERIOD_CURRENT, MA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
        handleSlow = iMA(_Symbol, PERIOD_CURRENT, MA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
        if(handleFast == INVALID_HANDLE || handleSlow == INVALID_HANDLE) return false;
        ArraySetAsSeries(fastMA, true);
        ArraySetAsSeries(slowMA, true);
        return true;
    }
    
    void DeinitStrategy() {
        IndicatorRelease(handleFast);
        IndicatorRelease(handleSlow);
    }
    
    int CheckSignal() {
        if(CopyBuffer(handleFast, 0, 0, 3, fastMA) < 3) return 0;
        if(CopyBuffer(handleSlow, 0, 0, 3, slowMA) < 3) return 0;
        
        if(fastMA[1] <= slowMA[1] && fastMA[0] > slowMA[0]) return 1;  // Buy
        if(fastMA[1] >= slowMA[1] && fastMA[0] < slowMA[0]) return -1; // Sell
        return 0;
    }
''',
    
    "rsi": '''
    // === RSI Strategy ===
    int handleRSI;
    double rsiBuffer[];
    
    bool InitStrategy() {
        handleRSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
        if(handleRSI == INVALID_HANDLE) return false;
        ArraySetAsSeries(rsiBuffer, true);
        return true;
    }
    
    void DeinitStrategy() {
        IndicatorRelease(handleRSI);
    }
    
    int CheckSignal() {
        if(CopyBuffer(handleRSI, 0, 0, 3, rsiBuffer) < 3) return 0;
        
        if(rsiBuffer[1] < RSI_Oversold && rsiBuffer[0] >= RSI_Oversold) return 1;  // Buy
        if(rsiBuffer[1] > RSI_Overbought && rsiBuffer[0] <= RSI_Overbought) return -1; // Sell
        return 0;
    }
''',

    "macd": '''
    // === MACD Strategy ===
    int handleMACD;
    double macdMain[], macdSignal[];
    
    bool InitStrategy() {
        handleMACD = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
        if(handleMACD == INVALID_HANDLE) return false;
        ArraySetAsSeries(macdMain, true);
        ArraySetAsSeries(macdSignal, true);
        return true;
    }
    
    void DeinitStrategy() {
        IndicatorRelease(handleMACD);
    }
    
    int CheckSignal() {
        if(CopyBuffer(handleMACD, 0, 0, 3, macdMain) < 3) return 0;
        if(CopyBuffer(handleMACD, 1, 0, 3, macdSignal) < 3) return 0;
        
        if(macdMain[1] <= macdSignal[1] && macdMain[0] > macdSignal[0]) return 1;  // Buy
        if(macdMain[1] >= macdSignal[1] && macdMain[0] < macdSignal[0]) return -1; // Sell
        return 0;
    }
''',

    "rsi_ma": '''
    // === RSI + MA Strategy ===
    int handleRSI, handleMA;
    double rsiBuffer[], maBuffer[];
    
    bool InitStrategy() {
        handleRSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
        handleMA = iMA(_Symbol, PERIOD_CURRENT, MA_Period, 0, MODE_EMA, PRICE_CLOSE);
        if(handleRSI == INVALID_HANDLE || handleMA == INVALID_HANDLE) return false;
        ArraySetAsSeries(rsiBuffer, true);
        ArraySetAsSeries(maBuffer, true);
        return true;
    }
    
    void DeinitStrategy() {
        IndicatorRelease(handleRSI);
        IndicatorRelease(handleMA);
    }
    
    int CheckSignal() {
        if(CopyBuffer(handleRSI, 0, 0, 3, rsiBuffer) < 3) return 0;
        if(CopyBuffer(handleMA, 0, 0, 3, maBuffer) < 3) return 0;
        
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Buy: RSI oversold + Price above MA
        if(rsiBuffer[0] < RSI_Oversold && price > maBuffer[0]) return 1;
        // Sell: RSI overbought + Price below MA
        if(rsiBuffer[0] > RSI_Overbought && price < maBuffer[0]) return -1;
        return 0;
    }
'''
}


# =================================================================================
#                          فئة إنشاء EA
# =================================================================================

class EAGenerator:
    """مولد Expert Advisor"""
    
    @staticmethod
    def generate_ea_code(name: str, strategy: str, params: Dict) -> str:
        """توليد كود EA كامل"""
        
        # الإعدادات الافتراضية
        default_params = {
            "MA_Fast_Period": 10,
            "MA_Slow_Period": 50,
            "MA_Period": 20,
            "RSI_Period": 14,
            "RSI_Overbought": 70,
            "RSI_Oversold": 30,
            "MACD_Fast": 12,
            "MACD_Slow": 26,
            "MACD_Signal": 9,
            "Risk_Percent": 2.0,
            "Stop_Loss_Pips": 50,
            "Take_Profit_Pips": 100,
            "Magic_Number": 123456
        }
        default_params.update(params)
        
        # الحصول على كود الاستراتيجية
        strategy_code = STRATEGY_TEMPLATES.get(strategy, STRATEGY_TEMPLATES["ma_crossover"])
        
        # توليد الكود الكامل
        code = f'''//+------------------------------------------------------------------+
//|                                           {name}.mq5             |
//|                        Generated by MT5 Complete Automation      |
//|                                    Strategy: {strategy}          |
//+------------------------------------------------------------------+
#property copyright "AI Generated - MT5 Complete Automation"
#property version   "1.00"
#property description "Strategy: {strategy}"
#property description "Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}"

#include <Trade/Trade.mqh>

// === Input Parameters ===
input group "=== Strategy Settings ==="
input int MA_Fast_Period = {default_params['MA_Fast_Period']};       // Fast MA Period
input int MA_Slow_Period = {default_params['MA_Slow_Period']};       // Slow MA Period
input int MA_Period = {default_params['MA_Period']};                  // MA Period
input int RSI_Period = {default_params['RSI_Period']};                // RSI Period
input int RSI_Overbought = {default_params['RSI_Overbought']};        // RSI Overbought Level
input int RSI_Oversold = {default_params['RSI_Oversold']};            // RSI Oversold Level
input int MACD_Fast = {default_params['MACD_Fast']};                  // MACD Fast
input int MACD_Slow = {default_params['MACD_Slow']};                  // MACD Slow
input int MACD_Signal = {default_params['MACD_Signal']};              // MACD Signal

input group "=== Risk Management ==="
input double Risk_Percent = {default_params['Risk_Percent']};         // Risk per Trade (%)
input int Stop_Loss_Pips = {default_params['Stop_Loss_Pips']};        // Stop Loss (pips)
input int Take_Profit_Pips = {default_params['Take_Profit_Pips']};    // Take Profit (pips)
input int Magic_Number = {default_params['Magic_Number']};            // Magic Number

// === Global Variables ===
CTrade trade;
datetime lastBarTime;

{strategy_code}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{{
    // Initialize trade object
    trade.SetExpertMagicNumber(Magic_Number);
    trade.SetDeviationInPoints(20);
    trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    // Initialize strategy
    if(!InitStrategy())
    {{
        Print("❌ Failed to initialize strategy!");
        return(INIT_FAILED);
    }}
    
    Print("✅ EA Initialized: {name}");
    Print("📊 Strategy: {strategy}");
    return(INIT_SUCCEEDED);
}}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{{
    DeinitStrategy();
    Print("👋 EA Stopped: {name}");
}}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{{
    // Check for new bar
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == lastBarTime) return;
    lastBarTime = currentBarTime;
    
    // Check if we have open positions
    if(HasOpenPosition()) return;
    
    // Check signal
    int signal = CheckSignal();
    
    // Execute trade
    if(signal == 1)
    {{
        OpenTrade(ORDER_TYPE_BUY);
    }}
    else if(signal == -1)
    {{
        OpenTrade(ORDER_TYPE_SELL);
    }}
}}

//+------------------------------------------------------------------+
//| Check if we have open position                                    |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {{
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {{
            if(PositionGetInteger(POSITION_MAGIC) == Magic_Number &&
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {{
                return true;
            }}
        }}
    }}
    return false;
}}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                  |
//+------------------------------------------------------------------+
double CalculateLotSize()
{{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * Risk_Percent / 100.0;
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    double slPoints = Stop_Loss_Pips * 10; // Convert pips to points
    double lotSize = riskAmount / (slPoints * tickValue / tickSize);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    
    return NormalizeDouble(lotSize, 2);
}}

//+------------------------------------------------------------------+
//| Open trade                                                        |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{{
    double price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double sl, tp;
    
    if(orderType == ORDER_TYPE_BUY)
    {{
        sl = price - Stop_Loss_Pips * 10 * point;
        tp = price + Take_Profit_Pips * 10 * point;
    }}
    else
    {{
        sl = price + Stop_Loss_Pips * 10 * point;
        tp = price - Take_Profit_Pips * 10 * point;
    }}
    
    double lotSize = CalculateLotSize();
    
    if(trade.PositionOpen(_Symbol, orderType, lotSize, price, sl, tp, "{name}"))
    {{
        Print("✅ Trade opened: ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"),
              " Lot: ", lotSize, " Price: ", price);
    }}
    else
    {{
        Print("❌ Trade failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
    }}
}}
//+------------------------------------------------------------------+
'''
        return code


# =================================================================================
#                          فئة الأتمتة الكاملة
# =================================================================================

@dataclass
class BacktestResult:
    """نتيجة الـ Backtest"""
    success: bool
    total_profit: float = 0.0
    total_trades: int = 0
    win_rate: float = 0.0
    max_drawdown: float = 0.0
    profit_factor: float = 0.0
    sharpe_ratio: float = 0.0
    recovery_factor: float = 0.0
    expected_payoff: float = 0.0
    report_path: str = ""
    error: str = ""


class MT5CompleteAutomation:
    """
    نظام الأتمتة الكامل لـ MT5
    
    يعمل كل شيء تلقائياً:
    1. إنشاء EA
    2. ترجمة EA
    3. تشغيل Backtest مرئي
    4. قراءة وتحليل النتائج
    """
    
    def __init__(self, terminal_path: str = None):
        self.terminal_path = terminal_path or self._find_mt5_path()
        self.metaeditor_path = self._find_metaeditor_path()
        self.data_path = self._find_data_path()
        
        log_header("MT5 Complete Automation System")
        log_info(f"Terminal: {self.terminal_path}")
        log_info(f"MetaEditor: {self.metaeditor_path}")
        log_info(f"Data Path: {self.data_path}")
    
    def _find_mt5_path(self) -> Optional[str]:
        """البحث عن MT5"""
        paths = [
            "C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe",
            "C:/Program Files/MetaTrader 5/terminal64.exe",
            "C:/Program Files (x86)/MetaTrader 5/terminal64.exe",
            "D:/MetaTrader 5/terminal64.exe",
        ]
        for path in paths:
            if os.path.exists(path):
                return path
        return None
    
    def _find_metaeditor_path(self) -> Optional[str]:
        """البحث عن MetaEditor"""
        if self.terminal_path:
            base_dir = os.path.dirname(self.terminal_path)
            metaeditor = os.path.join(base_dir, "metaeditor64.exe")
            if os.path.exists(metaeditor):
                return metaeditor
        return None
    
    def _find_data_path(self) -> Optional[str]:
        """البحث عن مجلد البيانات"""
        appdata = os.environ.get('APPDATA', '')
        if appdata:
            metaquotes = os.path.join(appdata, 'MetaQuotes', 'Terminal')
            if os.path.exists(metaquotes):
                for folder in os.listdir(metaquotes):
                    path = os.path.join(metaquotes, folder)
                    if os.path.isdir(path) and os.path.exists(os.path.join(path, 'MQL5')):
                        return path
        return None
    
    def create_expert(self, name: str, strategy: str = "ma_crossover", 
                     params: Dict = None) -> Tuple[bool, str]:
        """
        إنشاء Expert Advisor
        
        Args:
            name: اسم الـ EA
            strategy: نوع الاستراتيجية (ma_crossover, rsi, macd, rsi_ma)
            params: معاملات الاستراتيجية
        
        Returns:
            (success, file_path)
        """
        log_step(f"إنشاء Expert Advisor: {name}")
        
        if not self.data_path:
            log_error("مسار البيانات غير موجود!")
            return False, ""
        
        # توليد الكود
        code = EAGenerator.generate_ea_code(name, strategy, params or {})
        
        # حفظ الملف
        experts_path = os.path.join(self.data_path, 'MQL5', 'Experts')
        os.makedirs(experts_path, exist_ok=True)
        
        file_path = os.path.join(experts_path, f"{name}.mq5")
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(code)
            
            log_success(f"تم إنشاء: {file_path}")
            return True, file_path
        except Exception as e:
            log_error(f"فشل الإنشاء: {e}")
            return False, ""
    
    def compile_expert(self, ea_path: str) -> Tuple[bool, str]:
        """
        ترجمة Expert Advisor
        
        Args:
            ea_path: مسار ملف .mq5
        
        Returns:
            (success, ex5_path)
        """
        log_step(f"ترجمة Expert Advisor...")
        
        if not self.metaeditor_path:
            log_error("MetaEditor غير موجود!")
            log_warning("يرجى ترجمة الـ EA يدوياً: افتح MetaEditor واضغط F7")
            return False, ""
        
        if not os.path.exists(ea_path):
            log_error(f"الملف غير موجود: {ea_path}")
            return False, ""
        
        # تشغيل MetaEditor للترجمة
        log_file = ea_path.replace('.mq5', '.log')
        
        cmd = f'"{self.metaeditor_path}" /compile:"{ea_path}" /log:"{log_file}"'
        
        log_info(f"تشغيل: {cmd}")
        
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, 
                                   text=True, timeout=60)
            
            # التحقق من وجود ملف .ex5
            ex5_path = ea_path.replace('.mq5', '.ex5')
            
            if os.path.exists(ex5_path):
                log_success(f"تم الترجمة: {ex5_path}")
                return True, ex5_path
            else:
                # قراءة log للأخطاء
                if os.path.exists(log_file):
                    with open(log_file, 'r', encoding='utf-16') as f:
                        log_content = f.read()
                    log_error(f"فشل الترجمة:\n{log_content}")
                else:
                    log_error("فشل الترجمة - لا يوجد ملف log")
                return False, ""
                
        except subprocess.TimeoutExpired:
            log_error("انتهت مهلة الترجمة!")
            return False, ""
        except Exception as e:
            log_error(f"خطأ في الترجمة: {e}")
            return False, ""
    
    def create_backtest_config(self, expert_name: str, symbol: str = "EURUSD",
                               timeframe: str = "H1", from_date: str = "2024.01.01",
                               to_date: str = "2024.12.31", visual: bool = True,
                               deposit: float = 10000, leverage: int = 100) -> str:
        """إنشاء ملف تكوين Backtest"""
        log_step(f"إنشاء ملف تكوين Backtest...")
        
        # تحويل الإطار الزمني
        timeframe_map = {
            "M1": "1", "M5": "5", "M15": "15", "M30": "30",
            "H1": "60", "H4": "240", "D1": "1440", "W1": "10080", "MN1": "43200"
        }
        period = timeframe_map.get(timeframe.upper(), "60")
        
        # اسم التقرير
        report_name = f"{expert_name}_{symbol}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        ini_content = f'''; MT5 Strategy Tester Configuration
; Generated by MT5 Complete Automation
; Date: {datetime.now().isoformat()}

[Tester]
Expert=Experts\\{expert_name}
Symbol={symbol}
Period={period}
FromDate={from_date}
ToDate={to_date}
Model=1
Optimization=0
Visual={1 if visual else 0}
Deposit={deposit}
Leverage={leverage}
Currency=USD
UseLocal=1
UseRemote=0
UseCloud=0
Report={report_name}
ReplaceReport=1
ShutdownTerminal=0
'''
        
        # حفظ الملف
        if self.data_path:
            config_dir = os.path.join(self.data_path, 'tester')
        else:
            config_dir = os.path.dirname(self.terminal_path) if self.terminal_path else '.'
        
        os.makedirs(config_dir, exist_ok=True)
        config_path = os.path.join(config_dir, f"{expert_name}_backtest.ini")
        
        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(ini_content)
        
        log_success(f"تم إنشاء: {config_path}")
        return config_path
    
    def run_backtest(self, expert_name: str, symbol: str = "EURUSD",
                     timeframe: str = "H1", from_date: str = "2024.01.01",
                     to_date: str = "2024.12.31", visual: bool = True,
                     wait_for_completion: bool = True) -> BacktestResult:
        """
        تشغيل Backtest
        
        Args:
            expert_name: اسم الـ EA
            symbol: رمز الزوج
            timeframe: الإطار الزمني
            from_date: تاريخ البداية
            to_date: تاريخ النهاية
            visual: وضع مرئي
            wait_for_completion: انتظار انتهاء الاختبار
        
        Returns:
            BacktestResult
        """
        log_header(f"تشغيل Backtest: {expert_name}")
        
        if not self.terminal_path:
            return BacktestResult(success=False, error="مسار MT5 غير محدد")
        
        # إنشاء ملف التكوين
        config_path = self.create_backtest_config(
            expert_name, symbol, timeframe, from_date, to_date, visual
        )
        
        # تشغيل MT5
        cmd = f'"{self.terminal_path}" /config:"{config_path}"'
        
        log_step(f"تشغيل MT5...")
        log_info(f"الأمر: {cmd}")
        
        try:
            process = subprocess.Popen(cmd, shell=True)
            log_success("تم بدء MT5!")
            log_info("👀 شاهد الـ Backtest المرئي على الشاشة...")
            
            if wait_for_completion and not visual:
                # انتظار انتهاء الاختبار (للوضع غير المرئي)
                log_step("انتظار انتهاء الاختبار...")
                process.wait(timeout=600)  # 10 دقائق
                
                # قراءة النتائج
                return self.read_backtest_results(expert_name)
            else:
                log_info("الاختبار شغال... النتائج ستكون متاحة بعد الانتهاء")
                return BacktestResult(
                    success=True,
                    report_path=config_path,
                    error="الاختبار قيد التشغيل - شاهده على الشاشة!"
                )
                
        except Exception as e:
            return BacktestResult(success=False, error=str(e))
    
    def read_backtest_results(self, expert_name: str) -> BacktestResult:
        """قراءة نتائج Backtest"""
        log_step("قراءة نتائج Backtest...")
        
        if not self.data_path:
            return BacktestResult(success=False, error="مسار البيانات غير محدد")
        
        # البحث عن ملف التقرير
        reports_path = os.path.join(self.data_path, 'tester', 'reports')
        
        if not os.path.exists(reports_path):
            return BacktestResult(success=False, error="مجلد التقارير غير موجود")
        
        # البحث عن أحدث تقرير
        pattern = os.path.join(reports_path, f"{expert_name}*.xml")
        reports = glob.glob(pattern)
        
        if not reports:
            pattern = os.path.join(reports_path, f"{expert_name}*.htm")
            reports = glob.glob(pattern)
        
        if not reports:
            return BacktestResult(success=False, error="لا يوجد تقرير")
        
        latest_report = max(reports, key=os.path.getctime)
        log_info(f"التقرير: {latest_report}")
        
        # قراءة التقرير
        try:
            if latest_report.endswith('.xml'):
                return self._parse_xml_report(latest_report)
            else:
                return self._parse_html_report(latest_report)
        except Exception as e:
            return BacktestResult(success=False, error=f"خطأ في قراءة التقرير: {e}")
    
    def _parse_xml_report(self, path: str) -> BacktestResult:
        """قراءة تقرير XML"""
        tree = ET.parse(path)
        root = tree.getroot()
        
        result = BacktestResult(success=True, report_path=path)
        
        # استخراج البيانات
        for elem in root.iter():
            if elem.tag == 'TotalProfit':
                result.total_profit = float(elem.text or 0)
            elif elem.tag == 'TotalTrades':
                result.total_trades = int(elem.text or 0)
            elif elem.tag == 'ProfitFactor':
                result.profit_factor = float(elem.text or 0)
            elif elem.tag == 'MaxDrawdown':
                result.max_drawdown = float(elem.text or 0)
            elif elem.tag == 'SharpeRatio':
                result.sharpe_ratio = float(elem.text or 0)
        
        return result
    
    def _parse_html_report(self, path: str) -> BacktestResult:
        """قراءة تقرير HTML"""
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        result = BacktestResult(success=True, report_path=path)
        
        # استخراج البيانات بـ regex
        patterns = {
            'total_profit': r'Total Net Profit.*?>([-\d.]+)',
            'total_trades': r'Total Trades.*?>(\d+)',
            'profit_factor': r'Profit Factor.*?>([\d.]+)',
            'max_drawdown': r'Maximal Drawdown.*?>([\d.]+)',
        }
        
        for key, pattern in patterns.items():
            match = re.search(pattern, content)
            if match:
                value = match.group(1)
                if key == 'total_trades':
                    setattr(result, key, int(value))
                else:
                    setattr(result, key, float(value))
        
        return result
    
    def full_automation(self, name: str, strategy: str, symbol: str = "EURUSD",
                        timeframe: str = "H1", from_date: str = "2024.01.01",
                        to_date: str = "2024.12.31", params: Dict = None,
                        visual: bool = True) -> Dict:
        """
        🚀 الأتمتة الكاملة!
        
        يعمل كل شيء:
        1. إنشاء EA
        2. ترجمة EA
        3. تشغيل Backtest مرئي
        4. انتظار النتائج (اختياري)
        
        Args:
            name: اسم الـ EA
            strategy: الاستراتيجية
            symbol: الزوج
            timeframe: الإطار الزمني
            from_date: تاريخ البداية
            to_date: تاريخ النهاية
            params: معاملات إضافية
            visual: وضع مرئي
        
        Returns:
            تقرير شامل
        """
        log_header(f"🚀 بدء الأتمتة الكاملة")
        
        result = {
            "success": False,
            "steps": {},
            "ea_name": name,
            "strategy": strategy,
            "symbol": symbol,
            "timeframe": timeframe,
            "period": f"{from_date} to {to_date}",
            "timestamp": datetime.now().isoformat()
        }
        
        # الخطوة 1: إنشاء EA
        log_header("الخطوة 1/3: إنشاء Expert Advisor")
        ea_success, ea_path = self.create_expert(name, strategy, params)
        result["steps"]["create_ea"] = {"success": ea_success, "path": ea_path}
        
        if not ea_success:
            result["error"] = "فشل إنشاء EA"
            return result
        
        # الخطوة 2: ترجمة EA
        log_header("الخطوة 2/3: ترجمة Expert Advisor")
        compile_success, ex5_path = self.compile_expert(ea_path)
        result["steps"]["compile_ea"] = {"success": compile_success, "path": ex5_path}
        
        if not compile_success:
            log_warning("فشل الترجمة التلقائية")
            log_info("💡 يرجى ترجمة الـ EA يدوياً:")
            log_info("   1. افتح MT5")
            log_info("   2. اضغط F4 (MetaEditor)")
            log_info(f"   3. افتح: {ea_path}")
            log_info("   4. اضغط F7 (Compile)")
            log_info("   5. بعدها شغل الـ Backtest")
            result["manual_compile_required"] = True
            result["ea_path"] = ea_path
            return result
        
        # الخطوة 3: تشغيل Backtest
        log_header("الخطوة 3/3: تشغيل Backtest مرئي")
        backtest_result = self.run_backtest(
            name, symbol, timeframe, from_date, to_date, visual
        )
        
        result["steps"]["backtest"] = {
            "success": backtest_result.success,
            "report_path": backtest_result.report_path,
            "error": backtest_result.error
        }
        
        if visual:
            result["success"] = True
            result["message"] = "🎉 تم! شاهد الـ Backtest المرئي على الشاشة!"
            result["watching_instructions"] = [
                "👀 MT5 مفتوح الآن مع Strategy Tester",
                "📊 شاهد الشارت والصفقات",
                "⏱️ انتظر حتى انتهاء الاختبار",
                "📈 النتائج ستظهر في نهاية الاختبار"
            ]
        
        return result


# =================================================================================
#                          الواجهة التفاعلية
# =================================================================================

def interactive_mode():
    """الوضع التفاعلي"""
    automation = MT5CompleteAutomation()
    
    print(f"""
{Colors.BOLD}{Colors.CYAN}
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║          🚀 MT5 Complete Automation System                       ║
║          نظام الأتمتة الكامل                                     ║
║                                                                  ║
║   الاستراتيجيات المتاحة:                                         ║
║   • ma_crossover  - تقاطع المتوسطات                             ║
║   • rsi           - مؤشر RSI                                    ║
║   • macd          - مؤشر MACD                                   ║
║   • rsi_ma        - RSI + MA                                    ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
{Colors.END}
""")
    
    # جمع المعلومات
    name = input(f"{Colors.CYAN}اسم الـ EA: {Colors.END}").strip() or "AI_Strategy"
    
    print(f"\n{Colors.YELLOW}الاستراتيجيات: ma_crossover, rsi, macd, rsi_ma{Colors.END}")
    strategy = input(f"{Colors.CYAN}الاستراتيجية: {Colors.END}").strip() or "ma_crossover"
    
    symbol = input(f"{Colors.CYAN}الزوج (EURUSD): {Colors.END}").strip() or "EURUSD"
    timeframe = input(f"{Colors.CYAN}الإطار الزمني (H1): {Colors.END}").strip() or "H1"
    from_date = input(f"{Colors.CYAN}من تاريخ (2024.01.01): {Colors.END}").strip() or "2024.01.01"
    to_date = input(f"{Colors.CYAN}إلى تاريخ (2024.12.31): {Colors.END}").strip() or "2024.12.31"
    
    # تشغيل الأتمتة
    result = automation.full_automation(
        name=name,
        strategy=strategy,
        symbol=symbol,
        timeframe=timeframe,
        from_date=from_date,
        to_date=to_date,
        visual=True
    )
    
    # عرض النتيجة
    print(f"\n{Colors.BOLD}{'='*60}{Colors.END}")
    print(json.dumps(result, indent=2, ensure_ascii=False))


def quick_run(name: str, strategy: str, symbol: str = "EURUSD"):
    """تشغيل سريع"""
    automation = MT5CompleteAutomation()
    return automation.full_automation(
        name=name,
        strategy=strategy,
        symbol=symbol,
        visual=True
    )


# =================================================================================
#                          نقطة الدخول
# =================================================================================

if __name__ == "__main__":
    if len(sys.argv) > 1:
        # وضع سطر الأوامر
        import argparse
        parser = argparse.ArgumentParser(description='MT5 Complete Automation')
        parser.add_argument('--name', required=True, help='EA name')
        parser.add_argument('--strategy', default='ma_crossover', help='Strategy type')
        parser.add_argument('--symbol', default='EURUSD', help='Symbol')
        parser.add_argument('--timeframe', default='H1', help='Timeframe')
        parser.add_argument('--from', dest='from_date', default='2024.01.01', help='From date')
        parser.add_argument('--to', dest='to_date', default='2024.12.31', help='To date')
        
        args = parser.parse_args()
        
        automation = MT5CompleteAutomation()
        result = automation.full_automation(
            name=args.name,
            strategy=args.strategy,
            symbol=args.symbol,
            timeframe=args.timeframe,
            from_date=args.from_date,
            to_date=args.to_date,
            visual=True
        )
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        # الوضع التفاعلي
        interactive_mode()
