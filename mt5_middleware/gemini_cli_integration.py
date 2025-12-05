"""
=================================================================================
          تكامل Gemini CLI مع MT5 Ultimate Control
          Gemini CLI Integration for MT5
=================================================================================

هذا السكريبت مصمم خصيصاً لـ Gemini CLI!

🚀 المميزات:
- يشتغل مباشرة من Terminal
- لا يحتاج ngrok أو خوادم خارجية
- تحكم كامل في MT5
- أوامر بسيطة وسهلة

📋 طريقة الاستخدام مع Gemini CLI:
1. افتح Terminal
2. قل لـ Gemini: "شغل python gemini_cli_integration.py"
3. اطلب أي شيء: "اعمل EA واختبره"

=================================================================================
"""

import os
import sys
import json
import time
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List, Any

# ألوان للطباعة
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'

def print_success(msg): print(f"{Colors.GREEN}✅ {msg}{Colors.END}")
def print_warning(msg): print(f"{Colors.YELLOW}⚠️ {msg}{Colors.END}")
def print_error(msg): print(f"{Colors.RED}❌ {msg}{Colors.END}")
def print_info(msg): print(f"{Colors.BLUE}ℹ️ {msg}{Colors.END}")
def print_header(msg): print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*60}\n{msg}\n{'='*60}{Colors.END}\n")


# =================================================================================
#                          تكوين MT5
# =================================================================================

# المسارات الشائعة لـ MT5
MT5_PATHS = [
    "C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe",
    "C:/Program Files/MetaTrader 5/terminal64.exe",
    "C:/Program Files (x86)/MetaTrader 5/terminal64.exe",
    "D:/MetaTrader 5/terminal64.exe",
]

def find_mt5_path() -> Optional[str]:
    """البحث عن مسار MT5"""
    for path in MT5_PATHS:
        if os.path.exists(path):
            return path
    return None

def find_mql5_data_path() -> Optional[str]:
    """البحث عن مجلد بيانات MQL5"""
    appdata = os.environ.get('APPDATA', '')
    if appdata:
        metaquotes = os.path.join(appdata, 'MetaQuotes', 'Terminal')
        if os.path.exists(metaquotes):
            for folder in os.listdir(metaquotes):
                path = os.path.join(metaquotes, folder)
                mql5_path = os.path.join(path, 'MQL5')
                if os.path.isdir(path) and os.path.exists(mql5_path):
                    return path
    return None


# =================================================================================
#                          فئة التحكم في MT5
# =================================================================================

class MT5Controller:
    """
    المتحكم الرئيسي في MT5 لـ Gemini CLI
    
    مصمم للعمل مباشرة من Terminal بدون خوادم!
    """
    
    def __init__(self):
        self.terminal_path = find_mt5_path()
        self.data_path = find_mql5_data_path()
        self.mt5 = None
        self.connected = False
        
        # محاولة استيراد MT5
        try:
            import MetaTrader5 as mt5
            self.mt5 = mt5
            print_success("مكتبة MetaTrader5 متوفرة!")
        except ImportError:
            print_warning("مكتبة MetaTrader5 غير متوفرة. ثبتها بـ: pip install MetaTrader5")
    
    def show_status(self):
        """عرض حالة النظام"""
        print_header("حالة النظام")
        
        print(f"📂 مسار MT5: {self.terminal_path or 'غير موجود'}")
        print(f"📁 مسار البيانات: {self.data_path or 'غير موجود'}")
        print(f"🔌 الاتصال: {'متصل ✅' if self.connected else 'غير متصل ❌'}")
        print(f"📚 مكتبة MT5: {'متوفرة ✅' if self.mt5 else 'غير متوفرة ❌'}")
        
        if self.data_path:
            experts_path = os.path.join(self.data_path, 'MQL5', 'Experts')
            if os.path.exists(experts_path):
                experts = [f for f in os.listdir(experts_path) if f.endswith(('.ex5', '.mq5'))]
                print(f"🤖 Expert Advisors: {len(experts)} ملف")
    
    def connect(self, path: str = None) -> bool:
        """الاتصال بـ MT5"""
        print_header("الاتصال بـ MetaTrader 5")
        
        if not self.mt5:
            print_error("مكتبة MT5 غير متوفرة!")
            return False
        
        terminal_path = path or self.terminal_path
        if not terminal_path:
            print_error("مسار MT5 غير محدد!")
            return False
        
        print_info(f"جاري الاتصال بـ: {terminal_path}")
        
        if self.mt5.initialize(terminal_path):
            self.connected = True
            print_success("تم الاتصال بنجاح!")
            
            # عرض معلومات الحساب
            account = self.mt5.account_info()
            if account:
                print(f"\n📊 معلومات الحساب:")
                print(f"   رقم الحساب: {account.login}")
                print(f"   السيرفر: {account.server}")
                print(f"   الرصيد: ${account.balance:,.2f}")
                print(f"   الرافعة: 1:{account.leverage}")
            
            return True
        else:
            print_error(f"فشل الاتصال: {self.mt5.last_error()}")
            return False
    
    def disconnect(self):
        """قطع الاتصال"""
        if self.mt5:
            self.mt5.shutdown()
            self.connected = False
            print_success("تم قطع الاتصال")
    
    def get_account_info(self) -> Dict:
        """معلومات الحساب"""
        if not self.connected:
            print_error("غير متصل!")
            return {}
        
        account = self.mt5.account_info()
        if account:
            return {
                "login": account.login,
                "server": account.server,
                "balance": account.balance,
                "equity": account.equity,
                "margin": account.margin,
                "free_margin": account.margin_free,
                "profit": account.profit,
                "leverage": account.leverage,
                "currency": account.currency
            }
        return {}
    
    def get_price(self, symbol: str) -> Dict:
        """السعر الحالي"""
        if not self.connected:
            print_error("غير متصل!")
            return {}
        
        tick = self.mt5.symbol_info_tick(symbol)
        if tick:
            return {
                "symbol": symbol,
                "bid": tick.bid,
                "ask": tick.ask,
                "spread": round((tick.ask - tick.bid) * 10000, 1)
            }
        return {}
    
    def list_experts(self) -> List[Dict]:
        """قائمة Expert Advisors"""
        experts = []
        
        if not self.data_path:
            print_warning("مسار البيانات غير محدد")
            return experts
        
        experts_path = os.path.join(self.data_path, 'MQL5', 'Experts')
        
        if os.path.exists(experts_path):
            for root, dirs, files in os.walk(experts_path):
                for file in files:
                    if file.endswith(('.ex5', '.mq5')):
                        full_path = os.path.join(root, file)
                        rel_path = os.path.relpath(full_path, experts_path)
                        experts.append({
                            "name": os.path.splitext(file)[0],
                            "filename": file,
                            "type": "compiled" if file.endswith('.ex5') else "source",
                            "path": rel_path
                        })
        
        return experts
    
    def create_expert(self, name: str, strategy_type: str = "MA Crossover", 
                     risk_percent: float = 2.0) -> bool:
        """إنشاء Expert Advisor جديد"""
        print_header(f"إنشاء Expert Advisor: {name}")
        
        if not self.data_path:
            print_error("مسار البيانات غير محدد!")
            return False
        
        experts_path = os.path.join(self.data_path, 'MQL5', 'Experts')
        os.makedirs(experts_path, exist_ok=True)
        
        # قالب EA
        code = f'''//+------------------------------------------------------------------+
//|                                           {name}.mq5             |
//|                                    Generated by Gemini CLI       |
//|                                    Strategy: {strategy_type}     |
//+------------------------------------------------------------------+
#property copyright "AI Generated via Gemini CLI"
#property version   "1.00"
#property description "Strategy: {strategy_type}"

// Input parameters
input double RiskPercent = {risk_percent};    // Risk per trade (%)
input int MA_Fast = 10;                        // Fast MA period
input int MA_Slow = 50;                        // Slow MA period

// Global variables
int handleFast, handleSlow;
double fastMA[], slowMA[];

//+------------------------------------------------------------------+
int OnInit()
{{
    handleFast = iMA(_Symbol, PERIOD_CURRENT, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    handleSlow = iMA(_Symbol, PERIOD_CURRENT, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    
    if(handleFast == INVALID_HANDLE || handleSlow == INVALID_HANDLE)
    {{
        Print("Error creating MA handles");
        return(INIT_FAILED);
    }}
    
    ArraySetAsSeries(fastMA, true);
    ArraySetAsSeries(slowMA, true);
    
    Print("EA Initialized: {name}");
    return(INIT_SUCCEEDED);
}}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{{
    IndicatorRelease(handleFast);
    IndicatorRelease(handleSlow);
    Print("EA Stopped: {name}");
}}

//+------------------------------------------------------------------+
void OnTick()
{{
    if(CopyBuffer(handleFast, 0, 0, 3, fastMA) < 3) return;
    if(CopyBuffer(handleSlow, 0, 0, 3, slowMA) < 3) return;
    
    bool buySignal = fastMA[1] <= slowMA[1] && fastMA[0] > slowMA[0];
    bool sellSignal = fastMA[1] >= slowMA[1] && fastMA[0] < slowMA[0];
    
    if(buySignal)
    {{
        ClosePositions(POSITION_TYPE_SELL);
        OpenTrade(ORDER_TYPE_BUY);
    }}
    else if(sellSignal)
    {{
        ClosePositions(POSITION_TYPE_BUY);
        OpenTrade(ORDER_TYPE_SELL);
    }}
}}

//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{{
    double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = 0.01;
    request.type = orderType;
    request.price = price;
    request.deviation = 20;
    request.magic = 123456;
    request.comment = "{name}";
    
    if(!OrderSend(request, result))
        Print("OrderSend error: ", GetLastError());
}}

//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE posType)
{{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {{
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {{
            if(PositionGetInteger(POSITION_TYPE) == posType && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {{
                MqlTradeRequest request;
                MqlTradeResult result;
                ZeroMemory(request);
                ZeroMemory(result);
                
                request.action = TRADE_ACTION_DEAL;
                request.symbol = _Symbol;
                request.volume = PositionGetDouble(POSITION_VOLUME);
                request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                request.price = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) 
                                                               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                request.position = PositionGetTicket(i);
                request.deviation = 20;
                
                OrderSend(request, result);
            }}
        }}
    }}
}}
//+------------------------------------------------------------------+
'''
        
        file_path = os.path.join(experts_path, f"{name}.mq5")
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(code)
            
            print_success(f"تم إنشاء: {file_path}")
            print_info("لترجمة الـ EA: افتح MetaEditor (F4) ثم اضغط F7")
            return True
        except Exception as e:
            print_error(f"فشل الإنشاء: {e}")
            return False
    
    def create_backtest_config(self, expert_name: str, symbol: str = "EURUSD",
                               timeframe: str = "H1", from_date: str = "2024.01.01",
                               to_date: str = "2024.12.31", visual: bool = True,
                               deposit: float = 10000, leverage: int = 100) -> str:
        """إنشاء ملف تكوين Backtest"""
        print_header(f"إنشاء تكوين Backtest لـ: {expert_name}")
        
        # تحويل الإطار الزمني
        timeframe_map = {
            "M1": "1", "M5": "5", "M15": "15", "M30": "30",
            "H1": "60", "H4": "240", "D1": "1440", "W1": "10080", "MN1": "43200"
        }
        period = timeframe_map.get(timeframe.upper(), "60")
        
        ini_content = f"""
; Strategy Tester Configuration
; Generated by Gemini CLI Integration
; Date: {datetime.now().isoformat()}

[Tester]
Expert={expert_name}
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
Report={expert_name}_report
ReplaceReport=1
ShutdownTerminal=0
"""
        
        # حفظ الملف
        if self.data_path:
            config_dir = os.path.join(self.data_path, 'tester')
        else:
            config_dir = os.path.dirname(self.terminal_path) if self.terminal_path else '.'
        
        os.makedirs(config_dir, exist_ok=True)
        config_path = os.path.join(config_dir, f"{expert_name}_config.ini")
        
        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(ini_content)
        
        print_success(f"تم إنشاء ملف التكوين: {config_path}")
        return config_path
    
    def run_backtest(self, expert_name: str, symbol: str = "EURUSD",
                     timeframe: str = "H1", from_date: str = "2024.01.01",
                     to_date: str = "2024.12.31", visual: bool = True) -> bool:
        """تشغيل Backtest"""
        print_header(f"تشغيل Backtest: {expert_name}")
        
        if not self.terminal_path:
            print_error("مسار MT5 غير محدد!")
            return False
        
        # إنشاء ملف التكوين
        config_path = self.create_backtest_config(
            expert_name, symbol, timeframe, from_date, to_date, visual
        )
        
        # تشغيل MT5 مع ملف التكوين
        cmd = f'"{self.terminal_path}" /config:"{config_path}"'
        
        print_info(f"تشغيل الأمر: {cmd}")
        
        try:
            process = subprocess.Popen(cmd, shell=True)
            print_success("تم بدء الاختبار!")
            print_info("MT5 سيفتح ويبدأ الاختبار المرئي تلقائياً")
            
            return True
        except Exception as e:
            print_error(f"فشل التشغيل: {e}")
            return False
    
    def trade(self, symbol: str, order_type: str, volume: float = 0.01,
              sl: float = None, tp: float = None) -> bool:
        """تنفيذ صفقة"""
        print_header(f"تنفيذ صفقة: {order_type.upper()} {symbol}")
        
        if not self.connected:
            print_error("غير متصل بـ MT5!")
            return False
        
        # جلب السعر
        tick = self.mt5.symbol_info_tick(symbol)
        if not tick:
            print_error(f"رمز '{symbol}' غير موجود")
            return False
        
        # تحديد نوع الأمر
        if order_type.lower() == "buy":
            trade_type = self.mt5.ORDER_TYPE_BUY
            price = tick.ask
        else:
            trade_type = self.mt5.ORDER_TYPE_SELL
            price = tick.bid
        
        # إنشاء الطلب
        request = {
            "action": self.mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": trade_type,
            "price": price,
            "deviation": 20,
            "magic": 234000,
            "comment": "Gemini CLI Trade",
            "type_time": self.mt5.ORDER_TIME_GTC,
            "type_filling": self.mt5.ORDER_FILLING_IOC,
        }
        
        if sl:
            request["sl"] = sl
        if tp:
            request["tp"] = tp
        
        # تنفيذ
        result = self.mt5.order_send(request)
        
        if result.retcode == self.mt5.TRADE_RETCODE_DONE:
            print_success(f"تم تنفيذ الصفقة! Ticket: {result.order}")
            print(f"   السعر: {result.price}")
            print(f"   الحجم: {result.volume}")
            return True
        else:
            print_error(f"فشل التنفيذ: {result.comment}")
            return False


# =================================================================================
#                          الواجهة التفاعلية
# =================================================================================

def interactive_menu():
    """القائمة التفاعلية"""
    controller = MT5Controller()
    
    while True:
        print_header("MT5 Control - Gemini CLI")
        print("""
الأوامر المتاحة:

  📊 الحالة:
     status    - عرض حالة النظام
     connect   - الاتصال بـ MT5
     disconnect- قطع الاتصال
     account   - معلومات الحساب
     price     - السعر الحالي

  🤖 Expert Advisors:
     experts   - قائمة EAs
     create    - إنشاء EA جديد
     
  📈 Backtest:
     backtest  - تشغيل اختبار

  💰 التداول:
     buy       - فتح صفقة شراء
     sell      - فتح صفقة بيع

  ❌ خروج:
     exit/quit - إنهاء البرنامج
""")
        
        try:
            cmd = input(f"{Colors.CYAN}>>> {Colors.END}").strip().lower()
        except KeyboardInterrupt:
            print("\n")
            break
        
        if cmd in ['exit', 'quit', 'q']:
            controller.disconnect()
            print_success("مع السلامة! 👋")
            break
        
        elif cmd == 'status':
            controller.show_status()
        
        elif cmd == 'connect':
            path = input("مسار MT5 (Enter للافتراضي): ").strip() or None
            controller.connect(path)
        
        elif cmd == 'disconnect':
            controller.disconnect()
        
        elif cmd == 'account':
            info = controller.get_account_info()
            if info:
                print(f"\n💰 الرصيد: ${info['balance']:,.2f}")
                print(f"📊 الإكويتي: ${info['equity']:,.2f}")
                print(f"📈 الربح: ${info['profit']:,.2f}")
        
        elif cmd == 'price':
            symbol = input("الرمز (مثل EURUSD): ").strip().upper() or "EURUSD"
            price = controller.get_price(symbol)
            if price:
                print(f"\n📊 {symbol}:")
                print(f"   Bid: {price['bid']}")
                print(f"   Ask: {price['ask']}")
                print(f"   Spread: {price['spread']} pips")
        
        elif cmd == 'experts':
            experts = controller.list_experts()
            print(f"\n🤖 Expert Advisors ({len(experts)}):")
            for ea in experts:
                print(f"   - {ea['name']} ({ea['type']})")
        
        elif cmd == 'create':
            name = input("اسم الـ EA: ").strip()
            if name:
                controller.create_expert(name)
        
        elif cmd == 'backtest':
            expert = input("اسم الـ EA: ").strip()
            symbol = input("الرمز (EURUSD): ").strip().upper() or "EURUSD"
            if expert:
                controller.run_backtest(expert, symbol)
        
        elif cmd == 'buy':
            symbol = input("الرمز (EURUSD): ").strip().upper() or "EURUSD"
            volume = float(input("الحجم (0.01): ").strip() or "0.01")
            controller.trade(symbol, "buy", volume)
        
        elif cmd == 'sell':
            symbol = input("الرمز (EURUSD): ").strip().upper() or "EURUSD"
            volume = float(input("الحجم (0.01): ").strip() or "0.01")
            controller.trade(symbol, "sell", volume)
        
        else:
            print_warning(f"أمر غير معروف: {cmd}")
        
        print()


# =================================================================================
#                          أوامر مباشرة لـ Gemini CLI
# =================================================================================

def quick_command():
    """أوامر سريعة من command line"""
    import argparse
    
    parser = argparse.ArgumentParser(description='MT5 Control for Gemini CLI')
    parser.add_argument('command', nargs='?', default='interactive',
                       choices=['interactive', 'status', 'connect', 'experts', 
                               'create', 'backtest', 'buy', 'sell'])
    parser.add_argument('--name', help='EA name')
    parser.add_argument('--symbol', default='EURUSD', help='Trading symbol')
    parser.add_argument('--volume', type=float, default=0.01, help='Trade volume')
    parser.add_argument('--visual', action='store_true', help='Visual backtest')
    
    args = parser.parse_args()
    controller = MT5Controller()
    
    if args.command == 'interactive':
        interactive_menu()
    
    elif args.command == 'status':
        controller.show_status()
    
    elif args.command == 'connect':
        controller.connect()
    
    elif args.command == 'experts':
        experts = controller.list_experts()
        for ea in experts:
            print(f"{ea['name']} ({ea['type']})")
    
    elif args.command == 'create':
        if args.name:
            controller.create_expert(args.name)
        else:
            print_error("حدد اسم الـ EA بـ --name")
    
    elif args.command == 'backtest':
        if args.name:
            controller.run_backtest(args.name, args.symbol, visual=args.visual)
        else:
            print_error("حدد اسم الـ EA بـ --name")
    
    elif args.command == 'buy':
        controller.connect()
        controller.trade(args.symbol, 'buy', args.volume)
    
    elif args.command == 'sell':
        controller.connect()
        controller.trade(args.symbol, 'sell', args.volume)


# =================================================================================
#                          نقطة الدخول
# =================================================================================

if __name__ == "__main__":
    print(f"""
{Colors.BOLD}{Colors.CYAN}
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║          🚀 MT5 Control for Gemini CLI                          ║
║          تحكم كامل في MetaTrader 5 من Terminal                  ║
║                                                                  ║
║   الاستخدام:                                                     ║
║   python gemini_cli_integration.py              # تفاعلي        ║
║   python gemini_cli_integration.py status       # الحالة        ║
║   python gemini_cli_integration.py create --name MyEA           ║
║   python gemini_cli_integration.py backtest --name MyEA         ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
{Colors.END}
""")
    
    quick_command()
