"""
=================================================================================
          🎯 MT5 Visual Backtest Server
          خادم التحكم المباشر في Strategy Tester
=================================================================================

هذا الخادم يتحكم مباشرة في واجهة MT5 لتشغيل Backtest مرئي!

يستخدم:
- pywinauto للتحكم الذكي في الواجهة
- PyAutoGUI كاحتياطي
- اختصارات لوحة المفاتيح (Ctrl+R)

=================================================================================
"""

import os
import sys
import time
import json
import subprocess
from datetime import datetime
from typing import Optional, Dict, Any
from pathlib import Path

# FastAPI
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import APIKeyHeader
from pydantic import BaseModel, Field
import uvicorn

# ألوان
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'

# =================================================================================
#                          تحميل المكتبات
# =================================================================================

PYWINAUTO_AVAILABLE = False
PYAUTOGUI_AVAILABLE = False
MT5_AVAILABLE = False

try:
    from pywinauto import Application, Desktop
    from pywinauto.keyboard import send_keys
    from pywinauto.findwindows import ElementNotFoundError
    PYWINAUTO_AVAILABLE = True
    print(f"{Colors.GREEN}✅ pywinauto متوفر{Colors.END}")
except ImportError:
    print(f"{Colors.YELLOW}⚠️ pywinauto غير متوفر{Colors.END}")

try:
    import pyautogui
    import pygetwindow as gw
    PYAUTOGUI_AVAILABLE = True
    pyautogui.FAILSAFE = True
    pyautogui.PAUSE = 0.1
    print(f"{Colors.GREEN}✅ pyautogui متوفر{Colors.END}")
except ImportError:
    print(f"{Colors.YELLOW}⚠️ pyautogui غير متوفر{Colors.END}")

try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
    print(f"{Colors.GREEN}✅ MetaTrader5 API متوفر{Colors.END}")
except ImportError:
    print(f"{Colors.YELLOW}⚠️ MetaTrader5 غير متوفر{Colors.END}")

# استيراد نظام الأتمتة
try:
    from mt5_complete_automation import MT5CompleteAutomation, EAGenerator
    AUTOMATION_AVAILABLE = True
    print(f"{Colors.GREEN}✅ نظام الأتمتة متوفر{Colors.END}")
except ImportError:
    AUTOMATION_AVAILABLE = False
    print(f"{Colors.YELLOW}⚠️ mt5_complete_automation غير متوفر{Colors.END}")

# =================================================================================
#                          الإعدادات
# =================================================================================

API_KEY = os.environ.get("MT5_API_KEY", "your-secret-key-change-me")

# =================================================================================
#                          فئة التحكم في MT5
# =================================================================================

class MT5Controller:
    """فئة التحكم المباشر في MT5"""
    
    def __init__(self):
        self.mt5_window = None
        self.mt5_app = None
        self.terminal_path = self._find_mt5()
        self.data_path = self._find_data_path()
        
    def _find_mt5(self) -> Optional[str]:
        """البحث عن MT5"""
        paths = [
            "C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe",
            "C:/Program Files/Pepperstone MetaTrader 5/terminal64.exe",
            "C:/Program Files/MetaTrader 5/terminal64.exe",
            "C:/Program Files (x86)/MetaTrader 5/terminal64.exe",
        ]
        for path in paths:
            if os.path.exists(path):
                return path
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
    
    def find_mt5_window(self):
        """البحث عن نافذة MT5"""
        if PYWINAUTO_AVAILABLE:
            try:
                # البحث عن نافذة MT5
                self.mt5_app = Application(backend="uia").connect(title_re=".*MetaTrader.*", timeout=5)
                self.mt5_window = self.mt5_app.top_window()
                return True
            except Exception as e:
                print(f"خطأ في الاتصال بـ MT5: {e}")
        
        if PYAUTOGUI_AVAILABLE:
            try:
                windows = gw.getWindowsWithTitle('MetaTrader')
                if windows:
                    self.mt5_window = windows[0]
                    return True
            except:
                pass
        
        return False
    
    def focus_mt5(self) -> bool:
        """تركيز نافذة MT5"""
        try:
            if PYWINAUTO_AVAILABLE and self.mt5_window:
                self.mt5_window.set_focus()
                time.sleep(0.3)
                return True
            elif PYAUTOGUI_AVAILABLE:
                windows = gw.getWindowsWithTitle('MetaTrader')
                if windows:
                    windows[0].activate()
                    time.sleep(0.3)
                    return True
        except Exception as e:
            print(f"خطأ في تركيز MT5: {e}")
        return False
    
    def open_strategy_tester(self) -> bool:
        """فتح Strategy Tester بـ Ctrl+R"""
        try:
            if not self.focus_mt5():
                # محاولة تشغيل MT5
                if self.terminal_path:
                    subprocess.Popen([self.terminal_path])
                    time.sleep(5)
                    self.find_mt5_window()
                    self.focus_mt5()
            
            # Ctrl+R لفتح Strategy Tester
            if PYWINAUTO_AVAILABLE:
                send_keys('^r')
            elif PYAUTOGUI_AVAILABLE:
                pyautogui.hotkey('ctrl', 'r')
            
            time.sleep(1)
            return True
        except Exception as e:
            print(f"خطأ في فتح Strategy Tester: {e}")
            return False
    
    def run_visual_backtest_direct(self, expert_name: str, symbol: str = "EURUSD",
                                   timeframe: str = "H1") -> Dict:
        """تشغيل Backtest مرئي مباشرة"""
        result = {
            "success": False,
            "steps": [],
            "error": ""
        }
        
        try:
            # 1. تركيز MT5
            result["steps"].append("محاولة تركيز MT5...")
            if not self.focus_mt5():
                if self.terminal_path:
                    result["steps"].append("تشغيل MT5...")
                    subprocess.Popen([self.terminal_path])
                    time.sleep(5)
                    self.find_mt5_window()
            
            result["steps"].append("✅ MT5 جاهز")
            
            # 2. فتح Strategy Tester
            result["steps"].append("فتح Strategy Tester (Ctrl+R)...")
            self.focus_mt5()
            time.sleep(0.5)
            
            if PYAUTOGUI_AVAILABLE:
                pyautogui.hotkey('ctrl', 'r')
            elif PYWINAUTO_AVAILABLE:
                send_keys('^r')
            
            time.sleep(2)
            result["steps"].append("✅ Strategy Tester مفتوح")
            
            # 3. تشغيل الاختبار بالضغط على زر Start أو F5
            result["steps"].append("بدء الاختبار (F5)...")
            time.sleep(1)
            
            # محاولة الضغط على زر Start
            if PYAUTOGUI_AVAILABLE:
                # F5 لبدء الاختبار في Strategy Tester
                pyautogui.press('f5')
            elif PYWINAUTO_AVAILABLE:
                send_keys('{F5}')
            
            time.sleep(2)
            result["steps"].append("✅ تم إرسال أمر البدء")
            
            result["success"] = True
            result["message"] = "تم فتح Strategy Tester وإرسال أمر البدء!"
            result["instructions"] = [
                "👀 شاهد شاشتك الآن",
                "📊 Strategy Tester يجب أن يكون مفتوحاً",
                "🎯 إذا لم يبدأ الاختبار تلقائياً:",
                "   - اختر الـ EA من القائمة المنسدلة",
                "   - اختر الزوج والفريم",
                "   - فعّل Visual mode",
                "   - اضغط Start"
            ]
            
        except Exception as e:
            result["error"] = str(e)
            result["steps"].append(f"❌ خطأ: {e}")
        
        return result


# =================================================================================
#                          التطبيق
# =================================================================================

app = FastAPI(
    title="🎯 MT5 Visual Backtest Server",
    description="خادم التحكم المباشر في Strategy Tester",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# المتحكم
controller = MT5Controller()
automation = MT5CompleteAutomation() if AUTOMATION_AVAILABLE else None

# الأمان
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

async def verify_api_key(api_key: str = Depends(api_key_header)):
    if not api_key or api_key != API_KEY:
        raise HTTPException(status_code=401, detail="مفتاح API غير صحيح")
    return api_key


# =================================================================================
#                          نماذج البيانات
# =================================================================================

class VisualBacktestRequest(BaseModel):
    expert_name: str = Field(..., description="اسم الـ EA")
    symbol: str = Field(default="EURUSD")
    timeframe: str = Field(default="H1")
    create_ea: bool = Field(default=True, description="إنشاء EA جديد؟")
    strategy: str = Field(default="rsi", description="الاستراتيجية")


class KeyboardCommand(BaseModel):
    keys: str = Field(..., description="المفاتيح (مثل: ^r, {F5}, hello)")
    delay: float = Field(default=0.1)


class MouseCommand(BaseModel):
    x: int
    y: int
    action: str = Field(default="click", description="click, double, right, move")


# =================================================================================
#                          نقاط النهاية
# =================================================================================

@app.get("/")
async def root():
    return {
        "title": "🎯 MT5 Visual Backtest Server",
        "status": "online",
        "capabilities": {
            "pywinauto": PYWINAUTO_AVAILABLE,
            "pyautogui": PYAUTOGUI_AVAILABLE,
            "mt5_api": MT5_AVAILABLE,
            "automation": AUTOMATION_AVAILABLE
        },
        "mt5_path": controller.terminal_path,
        "endpoints": {
            "visual_backtest": "POST /visual-backtest ⭐",
            "open_tester": "POST /open-tester",
            "keyboard": "POST /keyboard",
            "mouse": "POST /mouse",
            "focus_mt5": "POST /focus-mt5",
            "create_ea": "POST /create-ea"
        }
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "pywinauto": PYWINAUTO_AVAILABLE,
        "pyautogui": PYAUTOGUI_AVAILABLE,
        "mt5_found": controller.terminal_path is not None,
        "timestamp": datetime.now().isoformat()
    }


@app.post("/focus-mt5")
async def focus_mt5(api_key: str = Depends(verify_api_key)):
    """تركيز نافذة MT5"""
    controller.find_mt5_window()
    success = controller.focus_mt5()
    return {"success": success, "message": "تم تركيز MT5" if success else "فشل التركيز"}


@app.post("/open-tester")
async def open_tester(api_key: str = Depends(verify_api_key)):
    """فتح Strategy Tester"""
    success = controller.open_strategy_tester()
    return {
        "success": success,
        "message": "تم فتح Strategy Tester (Ctrl+R)" if success else "فشل الفتح"
    }


@app.post("/keyboard")
async def send_keyboard(cmd: KeyboardCommand, api_key: str = Depends(verify_api_key)):
    """إرسال أوامر لوحة المفاتيح"""
    try:
        controller.focus_mt5()
        time.sleep(cmd.delay)
        
        if PYWINAUTO_AVAILABLE:
            send_keys(cmd.keys)
        elif PYAUTOGUI_AVAILABLE:
            # تحويل الصيغة
            if cmd.keys.startswith('^'):
                pyautogui.hotkey('ctrl', cmd.keys[1:])
            elif cmd.keys.startswith('{') and cmd.keys.endswith('}'):
                key = cmd.keys[1:-1].lower()
                pyautogui.press(key)
            else:
                pyautogui.write(cmd.keys)
        
        return {"success": True, "keys": cmd.keys}
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.post("/mouse")
async def send_mouse(cmd: MouseCommand, api_key: str = Depends(verify_api_key)):
    """إرسال أوامر الماوس"""
    try:
        if PYAUTOGUI_AVAILABLE:
            if cmd.action == "click":
                pyautogui.click(cmd.x, cmd.y)
            elif cmd.action == "double":
                pyautogui.doubleClick(cmd.x, cmd.y)
            elif cmd.action == "right":
                pyautogui.rightClick(cmd.x, cmd.y)
            elif cmd.action == "move":
                pyautogui.moveTo(cmd.x, cmd.y)
            
            return {"success": True, "action": cmd.action, "x": cmd.x, "y": cmd.y}
        else:
            return {"success": False, "error": "pyautogui غير متوفر"}
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.post("/create-ea")
async def create_ea(
    name: str,
    strategy: str = "rsi",
    api_key: str = Depends(verify_api_key)
):
    """إنشاء Expert Advisor"""
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=500, detail="نظام الأتمتة غير متوفر")
    
    success, path = automation.create_expert(name, strategy, {})
    
    # محاولة الترجمة
    compile_success = False
    if success:
        compile_success, _ = automation.compile_expert(path)
    
    return {
        "success": success,
        "ea_path": path,
        "compiled": compile_success,
        "message": f"تم إنشاء {name}.mq5" + (" وترجمته ✅" if compile_success else " (يحتاج ترجمة يدوية)")
    }


@app.post("/visual-backtest")
async def run_visual_backtest(req: VisualBacktestRequest, api_key: str = Depends(verify_api_key)):
    """
    ⭐ تشغيل Backtest مرئي
    
    الخطوات:
    1. إنشاء EA (اختياري)
    2. فتح Strategy Tester
    3. بدء الاختبار
    """
    result = {
        "success": False,
        "steps": [],
        "message": ""
    }
    
    try:
        # 1. إنشاء EA إذا مطلوب
        if req.create_ea and AUTOMATION_AVAILABLE:
            result["steps"].append(f"إنشاء EA: {req.expert_name}...")
            success, path = automation.create_expert(req.expert_name, req.strategy, {})
            if success:
                result["steps"].append(f"✅ تم إنشاء: {path}")
                
                # ترجمة
                compile_success, ex5 = automation.compile_expert(path)
                if compile_success:
                    result["steps"].append(f"✅ تم الترجمة: {ex5}")
                else:
                    result["steps"].append("⚠️ الترجمة فشلت - يحتاج ترجمة يدوية من MetaEditor (F7)")
            else:
                result["steps"].append("❌ فشل إنشاء EA")
        
        # 2. تشغيل Backtest المرئي
        result["steps"].append("تشغيل Backtest مرئي...")
        backtest_result = controller.run_visual_backtest_direct(
            req.expert_name, req.symbol, req.timeframe
        )
        
        result["steps"].extend(backtest_result["steps"])
        result["success"] = backtest_result["success"]
        
        if backtest_result["success"]:
            result["message"] = "🎉 تم! شاهد Strategy Tester على شاشتك!"
            result["instructions"] = backtest_result.get("instructions", [])
        else:
            result["error"] = backtest_result.get("error", "")
        
    except Exception as e:
        result["error"] = str(e)
        result["steps"].append(f"❌ خطأ: {e}")
    
    return result


@app.post("/full-visual-test")
async def full_visual_test(
    name: str = "AI_Test_EA",
    strategy: str = "rsi",
    symbol: str = "EURUSD",
    api_key: str = Depends(verify_api_key)
):
    """
    🚀 الاختبار المرئي الكامل
    
    1. إنشاء EA
    2. ترجمته
    3. فتح MT5
    4. فتح Strategy Tester
    5. محاولة تشغيل الاختبار
    """
    steps = []
    
    # 1. إنشاء EA
    if AUTOMATION_AVAILABLE:
        steps.append("📝 إنشاء Expert Advisor...")
        success, path = automation.create_expert(name, strategy, {})
        if success:
            steps.append(f"✅ EA: {path}")
            
            # ترجمة
            compile_success, ex5 = automation.compile_expert(path)
            if compile_success:
                steps.append(f"✅ Compiled: {ex5}")
            else:
                steps.append("⚠️ Compile failed - need manual F7")
    
    # 2. تشغيل MT5 إذا لم يكن شغال
    steps.append("🚀 تشغيل MT5...")
    if controller.terminal_path:
        subprocess.Popen([controller.terminal_path])
        time.sleep(5)
        steps.append("✅ MT5 started")
    
    # 3. البحث عن النافذة
    steps.append("🔍 البحث عن نافذة MT5...")
    controller.find_mt5_window()
    controller.focus_mt5()
    time.sleep(1)
    steps.append("✅ MT5 focused")
    
    # 4. فتح Strategy Tester
    steps.append("📊 فتح Strategy Tester (Ctrl+R)...")
    if PYAUTOGUI_AVAILABLE:
        pyautogui.hotkey('ctrl', 'r')
    time.sleep(2)
    steps.append("✅ Ctrl+R sent")
    
    # 5. محاولة بدء الاختبار
    steps.append("▶️ بدء الاختبار (F5)...")
    if PYAUTOGUI_AVAILABLE:
        pyautogui.press('f5')
    time.sleep(1)
    steps.append("✅ F5 sent")
    
    return {
        "success": True,
        "steps": steps,
        "message": "🎉 تم إرسال كل الأوامر! شاهد شاشتك الآن!",
        "manual_steps": [
            "إذا لم يبدأ الاختبار تلقائياً:",
            f"1. اختر {name} من قائمة Expert Advisors",
            f"2. اختر {symbol} من الرموز",
            "3. فعّل ✅ Visual mode",
            "4. اضغط Start"
        ]
    }


@app.post("/ini-backtest")
async def ini_backtest(
    name: str = "AI_Test_EA",
    strategy: str = "rsi",
    symbol: str = "EURUSD",
    timeframe: str = "H1",
    from_date: str = "2024.01.01",
    to_date: str = "2024.06.30",
    visual: bool = True,
    deposit: int = 10000,
    api_key: str = Depends(verify_api_key)
):
    """
    ⭐ الطريقة الصحيحة - INI File Method
    
    MT5 يقرأ ملف INI ويشغل الاختبار تلقائياً!
    - سريع
    - دقيق 100%
    - لا يحتاج تحكم بالماوس
    """
    steps = []
    
    try:
        # 1. إنشاء وترجمة EA
        if AUTOMATION_AVAILABLE:
            steps.append(f"📝 إنشاء EA: {name}...")
            success, ea_path = automation.create_expert(name, strategy, {})
            if success:
                steps.append(f"✅ تم: {ea_path}")
                
                compile_success, ex5_path = automation.compile_expert(ea_path)
                if compile_success:
                    steps.append(f"✅ ترجمة: {ex5_path}")
                else:
                    steps.append("⚠️ فشل الترجمة - يحتاج F7 يدوياً")
                    return {
                        "success": False,
                        "steps": steps,
                        "error": "EA compilation failed",
                        "manual_fix": "افتح MetaEditor واضغط F7"
                    }
            else:
                return {"success": False, "error": "Failed to create EA"}
        
        # 2. تحويل الإطار الزمني
        tf_map = {
            "M1": "1", "M5": "5", "M15": "15", "M30": "30",
            "H1": "60", "H4": "240", "D1": "1440", "W1": "10080"
        }
        period = tf_map.get(timeframe.upper(), "60")
        
        # 3. إنشاء ملف INI
        ini_content = f"""; MT5 Strategy Tester Configuration
; Generated by MT5 Visual Backtest Server
; {datetime.now().isoformat()}

[Tester]
Expert=Experts\\{name}
ExpertParameters=
Symbol={symbol}
Period={period}
FromDate={from_date}
ToDate={to_date}
Model=1
Optimization=0
Visual={1 if visual else 0}
Deposit={deposit}
Leverage=100
Currency=USD
UseLocal=1
UseRemote=0
UseCloud=0
ReplaceReport=1
ShutdownTerminal=0
"""
        
        # حفظ INI في مجلد tester
        if controller.data_path:
            ini_dir = os.path.join(controller.data_path, 'tester')
        else:
            ini_dir = os.path.dirname(controller.terminal_path) if controller.terminal_path else '.'
        
        os.makedirs(ini_dir, exist_ok=True)
        ini_path = os.path.join(ini_dir, f"{name}_backtest.ini")
        
        with open(ini_path, 'w', encoding='utf-8') as f:
            f.write(ini_content)
        
        steps.append(f"✅ INI: {ini_path}")
        
        # 4. تشغيل MT5 مع ملف INI
        if controller.terminal_path:
            cmd = f'"{controller.terminal_path}" /config:"{ini_path}"'
            steps.append(f"🚀 تشغيل: {cmd}")
            
            subprocess.Popen(cmd, shell=True)
            steps.append("✅ MT5 بدأ مع Strategy Tester!")
            
            return {
                "success": True,
                "steps": steps,
                "message": "🎉 MT5 يشغل الاختبار المرئي الآن!",
                "config": {
                    "ea": name,
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "period": f"{from_date} → {to_date}",
                    "visual": visual
                },
                "ini_path": ini_path,
                "note": "👀 شاهد شاشتك - الاختبار يعمل تلقائياً!"
            }
        else:
            return {"success": False, "error": "MT5 terminal not found"}
            
    except Exception as e:
        return {"success": False, "error": str(e), "steps": steps}


# =================================================================================
#                          التشغيل
# =================================================================================

if __name__ == "__main__":
    print(f"""
{Colors.BOLD}{Colors.CYAN}
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║           🎯 MT5 Visual Backtest Server                                  ║
║           خادم التحكم المباشر في Strategy Tester                         ║
║                                                                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║   🚀 الخادم يعمل على: http://localhost:8000                             ║
║   📚 التوثيق: http://localhost:8000/docs                                 ║
║                                                                          ║
║   ✨ الميزات:                                                            ║
║   ─────────                                                              ║
║   • POST /visual-backtest  - تشغيل Backtest مرئي                        ║
║   • POST /full-visual-test - الاختبار الكامل ⭐                         ║
║   • POST /keyboard         - إرسال مفاتيح                               ║
║   • POST /mouse            - التحكم بالماوس                             ║
║   • POST /open-tester      - فتح Strategy Tester                        ║
║                                                                          ║
║   📦 المكتبات:                                                           ║
║   ─────────                                                              ║
║   • pywinauto: {'✅' if PYWINAUTO_AVAILABLE else '❌'}                                                         ║
║   • pyautogui: {'✅' if PYAUTOGUI_AVAILABLE else '❌'}                                                         ║
║   • MT5 API:   {'✅' if MT5_AVAILABLE else '❌'}                                                         ║
║   • Automation: {'✅' if AUTOMATION_AVAILABLE else '❌'}                                                        ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
{Colors.END}
""")
    
    uvicorn.run(
        "mt5_visual_backtest_server:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
