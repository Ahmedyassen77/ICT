"""
=================================================================================
          نظام التحكم النهائي الذكي في MetaTrader 5
          MT5 Ultimate Smart Control System
=================================================================================

🚀 هذا النظام يجمع أفضل 4 طرق للتحكم في MT5:

1️⃣ Python MT5 API (الرسمي) - للتداول وجلب البيانات
2️⃣ Windows UI Automation (pywinauto) - تحكم عميق في الواجهة بدون صور!
3️⃣ PyAutoGUI - للتحكم بالماوس ولوحة المفاتيح
4️⃣ MQL5 File Bridge - للتواصل مع Expert Advisors

=================================================================================
الميزة الجديدة: pywinauto يتحكم في MT5 مثل ما يتحكم Playwright في المتصفح!
- لا يحتاج صور شاشة
- يقرأ العناصر مباشرة من الواجهة
- أسرع وأدق بكثير
=================================================================================

المتطلبات:
    pip install fastapi uvicorn pydantic MetaTrader5
    pip install pywinauto pyautogui pygetwindow pillow comtypes

يعمل على Windows فقط (لأن MT5 يعمل على Windows فقط)

المطور: Senior Python Developer & Algo-trading Automation Engineer
التاريخ: 2024
=================================================================================
"""

import os
import sys
import time
import json
import base64
import subprocess
import threading
import configparser
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Tuple, Union
from pathlib import Path
from enum import Enum
import logging
from io import BytesIO
import asyncio
from contextlib import contextmanager

# FastAPI
from fastapi import FastAPI, HTTPException, status, BackgroundTasks, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field
import uvicorn

# =================================================================================
#                          تحميل المكتبات حسب النظام
# =================================================================================

# Windows UI Automation (pywinauto) - الطريقة الذكية الجديدة!
PYWINAUTO_AVAILABLE = False
try:
    from pywinauto import Application, Desktop
    from pywinauto.findwindows import ElementNotFoundError
    from pywinauto.controls.uia_controls import (
        ButtonWrapper, EditWrapper, ComboBoxWrapper,
        ListItemWrapper, MenuItemWrapper, TreeItemWrapper
    )
    from pywinauto.keyboard import send_keys
    from pywinauto.mouse import click, double_click, right_click, move
    from pywinauto.timings import wait_until
    import pywinauto.controls.win32_controls as win32_controls
    PYWINAUTO_AVAILABLE = True
    print("✅ pywinauto متوفر - تحكم ذكي في الواجهة!")
except ImportError as e:
    print(f"⚠️ pywinauto غير متوفر: {e}")
    print("ثبته بـ: pip install pywinauto comtypes")

# PyAutoGUI - للتحكم بالماوس والصور
PYAUTOGUI_AVAILABLE = False
try:
    import pyautogui
    import pygetwindow as gw
    from PIL import Image
    PYAUTOGUI_AVAILABLE = True
    pyautogui.FAILSAFE = True
    pyautogui.PAUSE = 0.1
except ImportError:
    print("⚠️ pyautogui غير متوفر")

# MetaTrader5 API
MT5_AVAILABLE = False
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
    print("✅ MetaTrader5 API متوفر!")
except ImportError:
    print("⚠️ MetaTrader5 غير متوفر (يعمل على Windows فقط)")

# إعداد التسجيل
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mt5_ultimate.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


# =================================================================================
#                              نماذج البيانات
# =================================================================================

class ControlMethod(str, Enum):
    """طرق التحكم المتاحة"""
    PYWINAUTO = "pywinauto"  # الأفضل - تحكم ذكي
    PYAUTOGUI = "pyautogui"  # احتياطي - تحكم بالصور
    MT5_API = "mt5_api"       # للتداول والبيانات
    MQL5_FILE = "mql5_file"   # للتواصل مع EA


class MT5Config(BaseModel):
    """تكوين MT5"""
    terminal_path: str = Field(
        default="C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe",
        description="مسار terminal64.exe"
    )
    data_path: Optional[str] = Field(default=None, description="مسار بيانات MT5")
    login: Optional[int] = Field(default=None, description="رقم الحساب")
    password: Optional[str] = Field(default=None, description="كلمة المرور")
    server: Optional[str] = Field(default=None, description="اسم السيرفر")


class BacktestRequest(BaseModel):
    """طلب Backtest"""
    expert_name: str = Field(..., description="اسم الـ EA (بدون امتداد)")
    symbol: str = Field(default="EURUSD", description="رمز الزوج")
    timeframe: str = Field(default="H1", description="الإطار الزمني")
    from_date: str = Field(default="2024.01.01", description="تاريخ البداية")
    to_date: str = Field(default="2024.12.31", description="تاريخ النهاية")
    model: int = Field(default=1, description="نوع النموذج (0=كل tick, 1=سعر افتتاح, 2=نقاط التحكم)")
    optimization: int = Field(default=0, description="نوع التحسين (0=بدون, 1=كامل, 2=جيني)")
    visual: bool = Field(default=True, description="الوضع المرئي")
    deposit: float = Field(default=10000, description="رأس المال")
    leverage: int = Field(default=100, description="الرافعة المالية")
    use_method: ControlMethod = Field(default=ControlMethod.PYWINAUTO, description="طريقة التحكم")


class TradeRequest(BaseModel):
    """طلب تداول"""
    symbol: str = Field(..., description="رمز الزوج")
    order_type: str = Field(..., description="نوع الأمر (buy/sell)")
    volume: float = Field(default=0.01, description="حجم الصفقة")
    price: Optional[float] = Field(None, description="السعر (للأوامر المعلقة)")
    sl: Optional[float] = Field(None, description="وقف الخسارة")
    tp: Optional[float] = Field(None, description="جني الأرباح")
    comment: str = Field(default="AI Trade", description="تعليق")


class UIElementRequest(BaseModel):
    """طلب عنصر واجهة"""
    element_path: str = Field(..., description="مسار العنصر (مثل 'Menu->View->Strategy Tester')")
    action: str = Field(default="click", description="الإجراء (click/double_click/right_click/select)")
    value: Optional[str] = Field(None, description="قيمة للإدخال")


class CreateEARequest(BaseModel):
    """طلب إنشاء EA"""
    name: str = Field(..., description="اسم الـ EA")
    strategy_type: str = Field(default="trend_following", description="نوع الاستراتيجية")
    entry_logic: str = Field(default="MA crossover", description="منطق الدخول")
    exit_logic: str = Field(default="MA crossover reverse", description="منطق الخروج")
    risk_percent: float = Field(default=2.0, description="نسبة المخاطرة")
    custom_code: Optional[str] = Field(None, description="كود MQL5 مخصص")


# =================================================================================
#                              المتغيرات العامة
# =================================================================================

config = {
    "terminal_path": "C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe",
    "data_path": None,
    "mql5_path": None,
    "mt5_app": None,  # pywinauto Application object
    "mt5_window": None,  # pywinauto window object
    "connected": False,
    "last_screenshot": None
}


# =================================================================================
#                          فئة التحكم الذكي في MT5
# =================================================================================

class MT5SmartController:
    """
    المتحكم الذكي في MT5
    
    يستخدم pywinauto للتحكم المباشر في الواجهة:
    - لا يحتاج صور شاشة
    - يقرأ العناصر مباشرة
    - أسرع وأدق
    """
    
    def __init__(self, terminal_path: str):
        self.terminal_path = terminal_path
        self.app: Optional[Application] = None
        self.main_window = None
        self.connected = False
        
    def connect(self) -> bool:
        """الاتصال بـ MT5 باستخدام pywinauto"""
        if not PYWINAUTO_AVAILABLE:
            logger.warning("pywinauto غير متوفر")
            return False
        
        try:
            # محاولة الاتصال بـ MT5 إذا كان مفتوحاً
            try:
                self.app = Application(backend="uia").connect(
                    path=self.terminal_path,
                    timeout=5
                )
                logger.info("✅ تم الاتصال بـ MT5 (كان مفتوحاً)")
            except ElementNotFoundError:
                # إذا لم يكن مفتوحاً، شغله
                logger.info("🚀 تشغيل MT5...")
                self.app = Application(backend="uia").start(
                    self.terminal_path,
                    timeout=30
                )
                time.sleep(5)  # انتظار التحميل
            
            # البحث عن النافذة الرئيسية
            self.main_window = self.app.window(title_re=".*MetaTrader.*")
            self.main_window.wait('visible', timeout=30)
            self.connected = True
            logger.info("✅ تم الاتصال بنافذة MT5")
            return True
            
        except Exception as e:
            logger.error(f"❌ فشل الاتصال بـ MT5: {e}")
            return False
    
    def get_all_controls(self) -> List[Dict]:
        """الحصول على جميع عناصر الواجهة (مثل DOM في المتصفح!)"""
        if not self.main_window:
            return []
        
        controls = []
        try:
            for ctrl in self.main_window.descendants():
                try:
                    controls.append({
                        "control_type": ctrl.element_info.control_type,
                        "class_name": ctrl.element_info.class_name,
                        "name": ctrl.element_info.name,
                        "automation_id": ctrl.element_info.automation_id,
                        "rectangle": str(ctrl.element_info.rectangle) if hasattr(ctrl.element_info, 'rectangle') else None,
                        "is_enabled": ctrl.is_enabled() if hasattr(ctrl, 'is_enabled') else None,
                        "is_visible": ctrl.is_visible() if hasattr(ctrl, 'is_visible') else None
                    })
                except:
                    pass
        except Exception as e:
            logger.error(f"خطأ في قراءة العناصر: {e}")
        
        return controls
    
    def find_element(self, **kwargs) -> Optional[Any]:
        """البحث عن عنصر بمعايير محددة"""
        if not self.main_window:
            return None
        
        try:
            return self.main_window.child_window(**kwargs)
        except Exception as e:
            logger.error(f"لم يتم العثور على العنصر: {e}")
            return None
    
    def click_menu(self, menu_path: str) -> bool:
        """النقر على قائمة (مثل 'View->Strategy Tester')"""
        if not self.main_window:
            return False
        
        try:
            parts = menu_path.split('->')
            current = self.main_window
            
            for part in parts:
                menu_item = current.child_window(title=part.strip(), control_type="MenuItem")
                menu_item.click_input()
                time.sleep(0.3)
                current = self.main_window
            
            return True
        except Exception as e:
            logger.error(f"فشل النقر على القائمة: {e}")
            return False
    
    def open_strategy_tester(self) -> bool:
        """فتح Strategy Tester"""
        if not self.main_window:
            return False
        
        try:
            # الطريقة 1: اختصار لوحة المفاتيح
            self.main_window.set_focus()
            time.sleep(0.2)
            send_keys('^r')  # Ctrl+R
            time.sleep(1)
            logger.info("✅ تم فتح Strategy Tester")
            return True
        except Exception as e:
            logger.error(f"فشل فتح Strategy Tester: {e}")
            
            # الطريقة 2: عبر القائمة
            try:
                return self.click_menu("View->Strategy Tester")
            except:
                return False
    
    def get_window_text(self) -> str:
        """الحصول على نص النافذة"""
        if not self.main_window:
            return ""
        
        try:
            texts = []
            for ctrl in self.main_window.descendants():
                try:
                    text = ctrl.window_text()
                    if text:
                        texts.append(text)
                except:
                    pass
            return "\n".join(texts)
        except Exception as e:
            logger.error(f"خطأ في قراءة النص: {e}")
            return ""
    
    def type_text(self, text: str, element=None) -> bool:
        """كتابة نص"""
        try:
            if element:
                element.type_keys(text, with_spaces=True)
            else:
                send_keys(text, with_spaces=True)
            return True
        except Exception as e:
            logger.error(f"فشل الكتابة: {e}")
            return False
    
    def select_combobox(self, combobox_name: str, value: str) -> bool:
        """اختيار قيمة من ComboBox"""
        if not self.main_window:
            return False
        
        try:
            combo = self.main_window.child_window(title=combobox_name, control_type="ComboBox")
            combo.select(value)
            return True
        except Exception as e:
            logger.error(f"فشل اختيار القيمة: {e}")
            return False
    
    def click_button(self, button_name: str) -> bool:
        """النقر على زر"""
        if not self.main_window:
            return False
        
        try:
            button = self.main_window.child_window(title=button_name, control_type="Button")
            button.click_input()
            return True
        except Exception as e:
            logger.error(f"فشل النقر على الزر: {e}")
            return False
    
    def get_screenshot(self) -> Optional[Image.Image]:
        """التقاط صورة للنافذة"""
        if not self.main_window or not PYAUTOGUI_AVAILABLE:
            return None
        
        try:
            rect = self.main_window.rectangle()
            screenshot = pyautogui.screenshot(region=(
                rect.left, rect.top, rect.width(), rect.height()
            ))
            return screenshot
        except Exception as e:
            logger.error(f"فشل التقاط الصورة: {e}")
            return None


# =================================================================================
#                          فئة أتمتة Strategy Tester
# =================================================================================

class StrategyTesterAutomation:
    """
    أتمتة Strategy Tester بعدة طرق:
    1. ملف INI (الأسرع - لا يحتاج واجهة)
    2. pywinauto (ذكي - تحكم مباشر)
    3. pyautogui (احتياطي - صور الشاشة)
    """
    
    def __init__(self, terminal_path: str):
        self.terminal_path = terminal_path
        self.data_path = self._find_data_path()
        self.smart_controller = MT5SmartController(terminal_path) if PYWINAUTO_AVAILABLE else None
    
    def _find_data_path(self) -> Optional[str]:
        """البحث عن مجلد بيانات MT5"""
        appdata = os.environ.get('APPDATA', '')
        if appdata:
            metaquotes = os.path.join(appdata, 'MetaQuotes', 'Terminal')
            if os.path.exists(metaquotes):
                for folder in os.listdir(metaquotes):
                    path = os.path.join(metaquotes, folder)
                    if os.path.isdir(path) and os.path.exists(os.path.join(path, 'MQL5')):
                        return path
        return None
    
    def create_ini_config(self, request: BacktestRequest) -> str:
        """
        إنشاء ملف INI للـ Backtest
        
        هذه الطريقة الأسرع والأكثر موثوقية!
        """
        # تحويل الإطار الزمني
        timeframe_map = {
            "M1": "1", "M5": "5", "M15": "15", "M30": "30",
            "H1": "60", "H4": "240", "D1": "1440", "W1": "10080", "MN1": "43200"
        }
        period = timeframe_map.get(request.timeframe.upper(), "60")
        
        # إنشاء محتوى INI
        ini_content = f"""
; Strategy Tester Configuration
; Generated by MT5 Ultimate Control System
; Date: {datetime.now().isoformat()}

[Tester]
; === Expert Advisor ===
Expert={request.expert_name}

; === Symbol and Period ===
Symbol={request.symbol}
Period={period}

; === Date Range ===
FromDate={request.from_date}
ToDate={request.to_date}

; === Model ===
; 0 = Every tick
; 1 = Open prices only
; 2 = Control points
Model={request.model}

; === Optimization ===
; 0 = Disabled
; 1 = Complete
; 2 = Genetic
Optimization={request.optimization}

; === Visual Mode ===
Visual={1 if request.visual else 0}

; === Account Settings ===
Deposit={request.deposit}
Leverage={request.leverage}
Currency=USD

; === Execution ===
UseLocal=1
UseRemote=0
UseCloud=0

; === Reports ===
Report={request.expert_name}_report
ReplaceReport=1
ShutdownTerminal=0

; === Logs ===
OptimizationLog=1
"""
        
        # حفظ الملف
        config_dir = os.path.join(self.data_path, 'tester') if self.data_path else os.path.dirname(self.terminal_path)
        os.makedirs(config_dir, exist_ok=True)
        
        config_path = os.path.join(config_dir, f"{request.expert_name}_config.ini")
        
        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(ini_content)
        
        logger.info(f"✅ تم إنشاء ملف INI: {config_path}")
        return config_path
    
    def run_backtest_ini(self, request: BacktestRequest) -> Dict:
        """
        تشغيل Backtest باستخدام ملف INI
        
        الطريقة الأسرع والأكثر موثوقية!
        """
        # إنشاء ملف التكوين
        config_path = self.create_ini_config(request)
        
        # تشغيل MT5 مع ملف التكوين
        cmd = f'"{self.terminal_path}" /config:"{config_path}"'
        
        logger.info(f"🚀 تشغيل الاختبار: {cmd}")
        
        try:
            process = subprocess.Popen(cmd, shell=True)
            
            return {
                "success": True,
                "method": "ini_file",
                "message": "تم بدء الاختبار",
                "config_path": config_path,
                "process_id": process.pid,
                "settings": {
                    "expert": request.expert_name,
                    "symbol": request.symbol,
                    "timeframe": request.timeframe,
                    "from_date": request.from_date,
                    "to_date": request.to_date,
                    "model": request.model,
                    "visual": request.visual
                },
                "note": "لمتابعة الاختبار، استخدم /screenshot أو /tester/status"
            }
        except Exception as e:
            return {
                "success": False,
                "method": "ini_file",
                "error": str(e)
            }
    
    def run_backtest_smart(self, request: BacktestRequest) -> Dict:
        """
        تشغيل Backtest باستخدام pywinauto (تحكم ذكي)
        
        هذه الطريقة تتيح رؤية ما يحدث!
        """
        if not self.smart_controller:
            return {"success": False, "error": "pywinauto غير متوفر"}
        
        try:
            # الاتصال بـ MT5
            if not self.smart_controller.connect():
                return {"success": False, "error": "فشل الاتصال بـ MT5"}
            
            # فتح Strategy Tester
            if not self.smart_controller.open_strategy_tester():
                return {"success": False, "error": "فشل فتح Strategy Tester"}
            
            time.sleep(1)
            
            # محاولة تكوين الإعدادات
            settings_applied = []
            
            # هنا يمكن إضافة المزيد من التحكم في الواجهة
            # لكن الأفضل هو دمج طريقة INI مع العرض المرئي
            
            return {
                "success": True,
                "method": "pywinauto",
                "message": "تم فتح Strategy Tester",
                "settings": {
                    "expert": request.expert_name,
                    "symbol": request.symbol,
                    "timeframe": request.timeframe,
                    "visual": request.visual
                },
                "next_steps": [
                    "Strategy Tester مفتوح الآن",
                    "اختر Expert Advisor من القائمة",
                    "أو استخدم /backtest/ini لتشغيل تلقائي كامل"
                ],
                "tip": "استخدم /ui/controls لرؤية جميع العناصر المتاحة"
            }
        except Exception as e:
            return {
                "success": False,
                "method": "pywinauto",
                "error": str(e)
            }


# =================================================================================
#                          فئة التداول
# =================================================================================

class TradingController:
    """
    التحكم في التداول عبر MT5 Python API
    """
    
    @staticmethod
    def connect(config: MT5Config) -> Dict:
        """الاتصال بـ MT5"""
        if not MT5_AVAILABLE:
            return {
                "success": False,
                "error": "MT5 Python library غير متوفرة",
                "note": "ثبتها بـ: pip install MetaTrader5"
            }
        
        try:
            # تهيئة MT5
            if not mt5.initialize(config.terminal_path):
                return {
                    "success": False,
                    "error": f"فشل التهيئة: {mt5.last_error()}"
                }
            
            # تسجيل الدخول إذا توفرت البيانات
            if config.login and config.password and config.server:
                if not mt5.login(config.login, config.password, config.server):
                    return {
                        "success": False,
                        "error": f"فشل تسجيل الدخول: {mt5.last_error()}"
                    }
            
            # معلومات الحساب
            account = mt5.account_info()
            
            return {
                "success": True,
                "message": "تم الاتصال بنجاح",
                "terminal_info": {
                    "path": mt5.terminal_info().path if mt5.terminal_info() else None,
                    "data_path": mt5.terminal_info().data_path if mt5.terminal_info() else None,
                    "connected": mt5.terminal_info().connected if mt5.terminal_info() else False
                },
                "account": {
                    "login": account.login if account else None,
                    "server": account.server if account else None,
                    "balance": account.balance if account else None,
                    "equity": account.equity if account else None,
                    "currency": account.currency if account else None
                } if account else None
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    @staticmethod
    def disconnect() -> Dict:
        """قطع الاتصال"""
        if MT5_AVAILABLE:
            mt5.shutdown()
        return {"success": True, "message": "تم قطع الاتصال"}
    
    @staticmethod
    def get_account_info() -> Dict:
        """معلومات الحساب"""
        if not MT5_AVAILABLE:
            return {"success": False, "error": "MT5 غير متوفر"}
        
        if not mt5.terminal_info():
            return {"success": False, "error": "غير متصل بـ MT5"}
        
        account = mt5.account_info()
        if account:
            return {
                "success": True,
                "account": {
                    "login": account.login,
                    "server": account.server,
                    "trade_mode": account.trade_mode,
                    "balance": account.balance,
                    "equity": account.equity,
                    "margin": account.margin,
                    "margin_free": account.margin_free,
                    "margin_level": account.margin_level,
                    "profit": account.profit,
                    "leverage": account.leverage,
                    "currency": account.currency,
                    "credit": account.credit
                }
            }
        return {"success": False, "error": "فشل جلب معلومات الحساب"}
    
    @staticmethod
    def execute_trade(request: TradeRequest) -> Dict:
        """تنفيذ صفقة"""
        if not MT5_AVAILABLE:
            return {"success": False, "error": "MT5 غير متوفر"}
        
        try:
            # جلب معلومات الرمز
            symbol_info = mt5.symbol_info(request.symbol)
            if not symbol_info:
                return {"success": False, "error": f"رمز '{request.symbol}' غير موجود"}
            
            if not symbol_info.visible:
                mt5.symbol_select(request.symbol, True)
            
            # جلب السعر
            tick = mt5.symbol_info_tick(request.symbol)
            if not tick:
                return {"success": False, "error": "فشل جلب السعر"}
            
            # تحديد نوع الأمر والسعر
            if request.order_type.lower() == "buy":
                order_type = mt5.ORDER_TYPE_BUY
                price = tick.ask
            else:
                order_type = mt5.ORDER_TYPE_SELL
                price = tick.bid
            
            # إنشاء الطلب
            trade_request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": request.symbol,
                "volume": request.volume,
                "type": order_type,
                "price": price,
                "deviation": 20,
                "magic": 234000,
                "comment": request.comment,
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            if request.sl:
                trade_request["sl"] = request.sl
            if request.tp:
                trade_request["tp"] = request.tp
            
            # تنفيذ الصفقة
            result = mt5.order_send(trade_request)
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                return {
                    "success": True,
                    "message": "تم تنفيذ الصفقة",
                    "order": {
                        "ticket": result.order,
                        "volume": result.volume,
                        "price": result.price,
                        "symbol": request.symbol,
                        "type": request.order_type
                    }
                }
            else:
                return {
                    "success": False,
                    "error": f"فشل التنفيذ: {result.comment}",
                    "retcode": result.retcode
                }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    @staticmethod
    def get_positions() -> Dict:
        """الصفقات المفتوحة"""
        if not MT5_AVAILABLE:
            return {"success": False, "error": "MT5 غير متوفر"}
        
        try:
            positions = mt5.positions_get()
            if positions:
                return {
                    "success": True,
                    "count": len(positions),
                    "positions": [
                        {
                            "ticket": p.ticket,
                            "symbol": p.symbol,
                            "type": "buy" if p.type == 0 else "sell",
                            "volume": p.volume,
                            "price_open": p.price_open,
                            "price_current": p.price_current,
                            "profit": p.profit,
                            "sl": p.sl,
                            "tp": p.tp,
                            "time": datetime.fromtimestamp(p.time).isoformat()
                        }
                        for p in positions
                    ]
                }
            return {"success": True, "count": 0, "positions": []}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    @staticmethod
    def close_position(ticket: int) -> Dict:
        """إغلاق صفقة"""
        if not MT5_AVAILABLE:
            return {"success": False, "error": "MT5 غير متوفر"}
        
        try:
            position = mt5.positions_get(ticket=ticket)
            if not position:
                return {"success": False, "error": f"الصفقة {ticket} غير موجودة"}
            
            position = position[0]
            tick = mt5.symbol_info_tick(position.symbol)
            
            # تحديد سعر الإغلاق
            if position.type == 0:  # Buy
                price = tick.bid
                order_type = mt5.ORDER_TYPE_SELL
            else:  # Sell
                price = tick.ask
                order_type = mt5.ORDER_TYPE_BUY
            
            # طلب الإغلاق
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": position.symbol,
                "volume": position.volume,
                "type": order_type,
                "position": ticket,
                "price": price,
                "deviation": 20,
                "magic": 234000,
                "comment": "Close by AI",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            result = mt5.order_send(request)
            
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                return {
                    "success": True,
                    "message": f"تم إغلاق الصفقة {ticket}",
                    "profit": position.profit
                }
            else:
                return {
                    "success": False,
                    "error": f"فشل الإغلاق: {result.comment}"
                }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    @staticmethod
    def get_prices(symbol: str) -> Dict:
        """الأسعار الحالية"""
        if not MT5_AVAILABLE:
            return {
                "success": True,
                "symbol": symbol,
                "simulation": True,
                "bid": 1.0850,
                "ask": 1.0852,
                "spread": 2
            }
        
        try:
            tick = mt5.symbol_info_tick(symbol)
            if tick:
                return {
                    "success": True,
                    "symbol": symbol,
                    "bid": tick.bid,
                    "ask": tick.ask,
                    "spread": round((tick.ask - tick.bid) * 10000, 1),
                    "last": tick.last,
                    "volume": tick.volume,
                    "time": datetime.fromtimestamp(tick.time).isoformat()
                }
            return {"success": False, "error": f"رمز '{symbol}' غير موجود"}
        except Exception as e:
            return {"success": False, "error": str(e)}


# =================================================================================
#                          إنشاء التطبيق
# =================================================================================

app = FastAPI(
    title="MT5 Ultimate Control System",
    description="""
    # 🚀 نظام التحكم النهائي الذكي في MetaTrader 5
    
    هذا النظام يجمع **4 طرق** للتحكم الكامل في MT5:
    
    ## 1️⃣ Python MT5 API (الرسمي)
    - تداول حقيقي (شراء/بيع)
    - معلومات الحساب
    - الأسعار الحية
    - الصفقات المفتوحة
    
    ## 2️⃣ Windows UI Automation (pywinauto)
    - **تحكم ذكي بدون صور شاشة!**
    - قراءة عناصر الواجهة مباشرة
    - النقر على الأزرار والقوائم
    - ملء الحقول تلقائياً
    
    ## 3️⃣ INI File Configuration
    - تشغيل Strategy Tester تلقائياً
    - أسرع طريقة للـ Backtest
    - لا يحتاج تفاعل يدوي
    
    ## 4️⃣ PyAutoGUI (احتياطي)
    - التقاط صور الشاشة
    - التحكم بالماوس والكيبورد
    - للحالات الخاصة
    
    ---
    
    ⚠️ **ملاحظة**: يعمل على Windows فقط (لأن MT5 يعمل على Windows فقط)
    
    📚 **للاستخدام من AI (مثل Manus)**:
    1. شغّل هذا الخادم على Windows
    2. استخدم ngrok للوصول من الإنترنت
    3. أرسل طلبات HTTP
    """,
    version="3.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# المتحكمات
strategy_tester = None
trading_controller = TradingController()


# =================================================================================
#                              نقاط النهاية - الرئيسية
# =================================================================================

@app.get("/", tags=["🏠 الرئيسية"])
async def root():
    """الصفحة الرئيسية"""
    return {
        "title": "MT5 Ultimate Control System",
        "version": "3.0.0",
        "description": "نظام التحكم النهائي الذكي في MetaTrader 5",
        "capabilities": {
            "pywinauto": PYWINAUTO_AVAILABLE,
            "pyautogui": PYAUTOGUI_AVAILABLE,
            "mt5_api": MT5_AVAILABLE
        },
        "methods": {
            "smart_ui": "تحكم ذكي في الواجهة (pywinauto)",
            "trading": "تداول حقيقي (MT5 API)",
            "backtest": "Backtest تلقائي (INI files)",
            "vision": "رؤية الشاشة (PyAutoGUI)"
        },
        "endpoints": {
            "docs": "/docs",
            "health": "/health",
            "connect": "POST /connect",
            "backtest": "POST /backtest",
            "trade": "POST /trade",
            "ui_controls": "GET /ui/controls"
        }
    }


@app.get("/health", tags=["🏠 الرئيسية"])
async def health():
    """فحص الحالة"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "capabilities": {
            "pywinauto": PYWINAUTO_AVAILABLE,
            "pyautogui": PYAUTOGUI_AVAILABLE,
            "mt5_api": MT5_AVAILABLE
        },
        "smart_controller_connected": strategy_tester.smart_controller.connected if strategy_tester and strategy_tester.smart_controller else False
    }


# =================================================================================
#                              نقاط النهاية - الاتصال
# =================================================================================

@app.post("/connect", tags=["🔌 الاتصال"])
async def connect(config: MT5Config):
    """
    ## الاتصال بـ MT5
    
    يتصل بـ MetaTrader 5 بعدة طرق:
    1. **pywinauto** - للتحكم في الواجهة
    2. **MT5 API** - للتداول والبيانات
    
    ### المعاملات:
    - **terminal_path**: مسار terminal64.exe (مثلاً: `C:/Program Files/MetaTrader 5/terminal64.exe`)
    - **login**: رقم الحساب (اختياري)
    - **password**: كلمة المرور (اختياري)
    - **server**: اسم السيرفر (اختياري)
    """
    global strategy_tester
    
    results = {}
    
    # 1. الاتصال بـ pywinauto
    if PYWINAUTO_AVAILABLE:
        strategy_tester = StrategyTesterAutomation(config.terminal_path)
        if strategy_tester.smart_controller:
            pywinauto_connected = strategy_tester.smart_controller.connect()
            results["pywinauto"] = {
                "success": pywinauto_connected,
                "message": "تم الاتصال بواجهة MT5" if pywinauto_connected else "فشل الاتصال"
            }
    
    # 2. الاتصال بـ MT5 API
    mt5_result = trading_controller.connect(config)
    results["mt5_api"] = mt5_result
    
    # تحديث التكوين
    config_dict = config.model_dump()
    for key, value in config_dict.items():
        if value:
            globals()["config"][key] = value
    
    return {
        "success": any(r.get("success") for r in results.values()),
        "connections": results,
        "config": {
            "terminal_path": config.terminal_path,
            "data_path": strategy_tester.data_path if strategy_tester else None
        }
    }


@app.post("/disconnect", tags=["🔌 الاتصال"])
async def disconnect():
    """قطع الاتصال"""
    result = trading_controller.disconnect()
    return result


# =================================================================================
#                              نقاط النهاية - Backtest
# =================================================================================

@app.post("/backtest", tags=["📊 Strategy Tester"])
async def run_backtest(request: BacktestRequest):
    """
    ## تشغيل Backtest
    
    يشغل اختبار الاستراتيجية بالطريقة المناسبة:
    
    ### طرق التحكم:
    - **pywinauto**: تحكم ذكي في الواجهة (يمكنك رؤية ما يحدث)
    - **ini_file**: أسرع طريقة (تشغيل مباشر)
    
    ### المعاملات:
    - **expert_name**: اسم الـ Expert Advisor
    - **symbol**: رمز الزوج (مثل EURUSD)
    - **timeframe**: الإطار الزمني (M1, M5, H1, D1...)
    - **from_date**: تاريخ البداية (YYYY.MM.DD)
    - **to_date**: تاريخ النهاية (YYYY.MM.DD)
    - **visual**: تفعيل الوضع المرئي
    - **use_method**: طريقة التحكم (pywinauto أو ini_file)
    """
    global strategy_tester
    
    terminal_path = config.get("terminal_path", request.model_dump().get("terminal_path"))
    
    if not strategy_tester:
        strategy_tester = StrategyTesterAutomation(terminal_path)
    
    if request.use_method == ControlMethod.PYWINAUTO:
        return strategy_tester.run_backtest_smart(request)
    else:
        return strategy_tester.run_backtest_ini(request)


@app.post("/backtest/ini", tags=["📊 Strategy Tester"])
async def run_backtest_ini(request: BacktestRequest):
    """
    ## تشغيل Backtest باستخدام ملف INI
    
    الطريقة الأسرع والأكثر موثوقية!
    
    ### كيف يعمل:
    1. ينشئ ملف INI بإعدادات الاختبار
    2. يشغل MT5 مع المعامل `/config:file.ini`
    3. MT5 يبدأ الاختبار تلقائياً
    """
    global strategy_tester
    
    terminal_path = config.get("terminal_path")
    
    if not strategy_tester:
        strategy_tester = StrategyTesterAutomation(terminal_path)
    
    return strategy_tester.run_backtest_ini(request)


@app.get("/backtest/config", tags=["📊 Strategy Tester"])
async def get_backtest_config():
    """الحصول على تكوين Backtest الحالي"""
    return {
        "terminal_path": config.get("terminal_path"),
        "data_path": strategy_tester.data_path if strategy_tester else None,
        "timeframes": ["M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"],
        "models": {
            0: "Every tick",
            1: "Open prices only",
            2: "Control points"
        },
        "optimization_types": {
            0: "Disabled",
            1: "Complete",
            2: "Genetic"
        }
    }


# =================================================================================
#                              نقاط النهاية - UI Control (pywinauto)
# =================================================================================

@app.get("/ui/controls", tags=["🖥️ واجهة المستخدم"])
async def get_ui_controls():
    """
    ## الحصول على جميع عناصر الواجهة
    
    مثل DOM في المتصفح! يعرض جميع الأزرار والقوائم والحقول.
    
    ⚠️ يتطلب اتصال pywinauto
    """
    if not PYWINAUTO_AVAILABLE:
        raise HTTPException(status_code=503, detail="pywinauto غير متوفر")
    
    if not strategy_tester or not strategy_tester.smart_controller or not strategy_tester.smart_controller.connected:
        raise HTTPException(status_code=400, detail="غير متصل بـ MT5. استخدم /connect أولاً")
    
    controls = strategy_tester.smart_controller.get_all_controls()
    
    return {
        "success": True,
        "count": len(controls),
        "controls": controls[:100],  # أول 100 عنصر فقط
        "note": "استخدم /ui/search للبحث عن عنصر محدد"
    }


@app.get("/ui/search", tags=["🖥️ واجهة المستخدم"])
async def search_ui_element(
    name: Optional[str] = None,
    control_type: Optional[str] = None,
    class_name: Optional[str] = None
):
    """
    ## البحث عن عنصر في الواجهة
    
    ### المعاملات:
    - **name**: اسم العنصر (مثل "Strategy Tester")
    - **control_type**: نوع العنصر (مثل "Button", "Menu", "Edit")
    - **class_name**: اسم الفئة
    """
    if not PYWINAUTO_AVAILABLE:
        raise HTTPException(status_code=503, detail="pywinauto غير متوفر")
    
    if not strategy_tester or not strategy_tester.smart_controller:
        raise HTTPException(status_code=400, detail="غير متصل")
    
    controls = strategy_tester.smart_controller.get_all_controls()
    
    # تصفية النتائج
    results = []
    for ctrl in controls:
        match = True
        if name and name.lower() not in (ctrl.get("name") or "").lower():
            match = False
        if control_type and control_type.lower() != (ctrl.get("control_type") or "").lower():
            match = False
        if class_name and class_name.lower() not in (ctrl.get("class_name") or "").lower():
            match = False
        
        if match:
            results.append(ctrl)
    
    return {
        "success": True,
        "count": len(results),
        "results": results
    }


@app.post("/ui/click", tags=["🖥️ واجهة المستخدم"])
async def click_ui_element(
    name: str = Query(..., description="اسم العنصر"),
    control_type: Optional[str] = Query(None, description="نوع العنصر")
):
    """
    ## النقر على عنصر
    
    ### مثال:
    - اسم: "Start" لبدء الاختبار
    - نوع: "Button"
    """
    if not PYWINAUTO_AVAILABLE:
        raise HTTPException(status_code=503, detail="pywinauto غير متوفر")
    
    if not strategy_tester or not strategy_tester.smart_controller:
        raise HTTPException(status_code=400, detail="غير متصل")
    
    success = strategy_tester.smart_controller.click_button(name)
    
    return {
        "success": success,
        "action": "click",
        "element": name
    }


@app.post("/ui/type", tags=["🖥️ واجهة المستخدم"])
async def type_text(text: str = Query(..., description="النص للكتابة")):
    """كتابة نص"""
    if not PYWINAUTO_AVAILABLE:
        raise HTTPException(status_code=503, detail="pywinauto غير متوفر")
    
    if not strategy_tester or not strategy_tester.smart_controller:
        raise HTTPException(status_code=400, detail="غير متصل")
    
    success = strategy_tester.smart_controller.type_text(text)
    
    return {
        "success": success,
        "action": "type",
        "text": text
    }


@app.post("/ui/menu", tags=["🖥️ واجهة المستخدم"])
async def click_menu(path: str = Query(..., description="مسار القائمة (مثل 'View->Strategy Tester')")):
    """
    ## النقر على قائمة
    
    ### أمثلة:
    - `View->Strategy Tester` - فتح نافذة الاختبار
    - `File->New Chart` - فتح شارت جديد
    - `Tools->Options` - فتح الإعدادات
    """
    if not PYWINAUTO_AVAILABLE:
        raise HTTPException(status_code=503, detail="pywinauto غير متوفر")
    
    if not strategy_tester or not strategy_tester.smart_controller:
        raise HTTPException(status_code=400, detail="غير متصل")
    
    success = strategy_tester.smart_controller.click_menu(path)
    
    return {
        "success": success,
        "action": "menu_click",
        "path": path
    }


@app.post("/ui/hotkey", tags=["🖥️ واجهة المستخدم"])
async def send_hotkey(keys: str = Query(..., description="الاختصار (مثل 'ctrl+r' أو 'f1')")):
    """
    ## إرسال اختصار لوحة المفاتيح
    
    ### أمثلة:
    - `^r` أو `ctrl+r` - فتح Strategy Tester
    - `{F4}` - فتح MetaEditor
    - `^s` - حفظ
    """
    if not PYWINAUTO_AVAILABLE:
        raise HTTPException(status_code=503, detail="pywinauto غير متوفر")
    
    try:
        send_keys(keys)
        return {"success": True, "action": "hotkey", "keys": keys}
    except Exception as e:
        return {"success": False, "error": str(e)}


# =================================================================================
#                              نقاط النهاية - التداول
# =================================================================================

@app.get("/account", tags=["💰 التداول"])
async def get_account():
    """معلومات الحساب"""
    return trading_controller.get_account_info()


@app.post("/trade", tags=["💰 التداول"])
async def execute_trade(request: TradeRequest):
    """
    ## تنفيذ صفقة
    
    ### المعاملات:
    - **symbol**: رمز الزوج (EURUSD, GBPUSD...)
    - **order_type**: buy أو sell
    - **volume**: حجم الصفقة (0.01, 0.1, 1.0...)
    - **sl**: وقف الخسارة (اختياري)
    - **tp**: جني الأرباح (اختياري)
    """
    return trading_controller.execute_trade(request)


@app.get("/positions", tags=["💰 التداول"])
async def get_positions():
    """الصفقات المفتوحة"""
    return trading_controller.get_positions()


@app.post("/positions/{ticket}/close", tags=["💰 التداول"])
async def close_position(ticket: int):
    """إغلاق صفقة"""
    return trading_controller.close_position(ticket)


@app.get("/prices/{symbol}", tags=["💰 التداول"])
async def get_prices(symbol: str):
    """الأسعار الحالية"""
    return trading_controller.get_prices(symbol)


@app.get("/symbols", tags=["💰 التداول"])
async def get_symbols():
    """قائمة الرموز المتاحة"""
    if not MT5_AVAILABLE:
        return {
            "success": True,
            "simulation": True,
            "symbols": ["EURUSD", "GBPUSD", "USDJPY", "XAUUSD"]
        }
    
    symbols = mt5.symbols_get()
    if symbols:
        return {
            "success": True,
            "count": len(symbols),
            "symbols": [s.name for s in symbols[:50]]  # أول 50 رمز
        }
    return {"success": False, "error": "فشل جلب الرموز"}


# =================================================================================
#                              نقاط النهاية - Expert Advisors
# =================================================================================

@app.get("/experts", tags=["🤖 Expert Advisors"])
async def list_experts():
    """قائمة Expert Advisors"""
    if not strategy_tester or not strategy_tester.data_path:
        return {"success": False, "error": "مسار البيانات غير محدد"}
    
    experts = []
    experts_path = os.path.join(strategy_tester.data_path, "MQL5", "Experts")
    
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
    
    return {
        "success": True,
        "path": experts_path,
        "count": len(experts),
        "experts": experts
    }


@app.post("/experts/create", tags=["🤖 Expert Advisors"])
async def create_expert(request: CreateEARequest):
    """
    ## إنشاء Expert Advisor جديد
    
    يمكن للـ AI كتابة استراتيجيات تداول كاملة!
    """
    if not strategy_tester or not strategy_tester.data_path:
        raise HTTPException(status_code=400, detail="مسار البيانات غير محدد")
    
    # قالب EA بسيط
    if request.custom_code:
        code = request.custom_code
    else:
        code = f'''//+------------------------------------------------------------------+
//|                                           {request.name}.mq5   |
//|                                    Generated by AI              |
//+------------------------------------------------------------------+
#property copyright "AI Generated"
#property version   "1.00"
#property description "Strategy: {request.strategy_type}"
#property description "Entry: {request.entry_logic}"
#property description "Exit: {request.exit_logic}"

// Input parameters
input double RiskPercent = {request.risk_percent};    // Risk per trade (%)
input int MA_Fast = 10;                                 // Fast MA period
input int MA_Slow = 50;                                 // Slow MA period

// Global variables
int handleFast, handleSlow;
double fastMA[], slowMA[];

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
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
    
    Print("EA Initialized: {request.name}");
    return(INIT_SUCCEEDED);
}}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{{
    IndicatorRelease(handleFast);
    IndicatorRelease(handleSlow);
    Print("EA Stopped: {request.name}");
}}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{{
    // Copy MA values
    if(CopyBuffer(handleFast, 0, 0, 3, fastMA) < 3) return;
    if(CopyBuffer(handleSlow, 0, 0, 3, slowMA) < 3) return;
    
    // Check for signals
    bool buySignal = fastMA[1] <= slowMA[1] && fastMA[0] > slowMA[0];
    bool sellSignal = fastMA[1] >= slowMA[1] && fastMA[0] < slowMA[0];
    
    // Execute trades
    if(buySignal)
    {{
        // Close sell positions and open buy
        CloseAllPositions(POSITION_TYPE_SELL);
        OpenTrade(ORDER_TYPE_BUY);
    }}
    else if(sellSignal)
    {{
        // Close buy positions and open sell
        CloseAllPositions(POSITION_TYPE_BUY);
        OpenTrade(ORDER_TYPE_SELL);
    }}
}}

//+------------------------------------------------------------------+
//| Open trade function                                               |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{{
    double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double lotSize = CalculateLotSize();
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = orderType;
    request.price = price;
    request.deviation = 20;
    request.magic = 123456;
    request.comment = "{request.name}";
    
    if(!OrderSend(request, result))
    {{
        Print("OrderSend error: ", GetLastError());
    }}
}}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                  |
//+------------------------------------------------------------------+
double CalculateLotSize()
{{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * RiskPercent / 100.0;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    
    double lotSize = NormalizeDouble(riskAmount / (tickValue * 100), 2);
    
    if(lotSize < minLot) lotSize = minLot;
    
    return lotSize;
}}

//+------------------------------------------------------------------+
//| Close all positions of a type                                     |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE posType)
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
    
    # حفظ الملف
    experts_path = os.path.join(strategy_tester.data_path, "MQL5", "Experts")
    os.makedirs(experts_path, exist_ok=True)
    
    file_path = os.path.join(experts_path, f"{request.name}.mq5")
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(code)
    
    return {
        "success": True,
        "message": f"تم إنشاء {request.name}.mq5",
        "path": file_path,
        "note": "لترجمة الـ EA: افتح MetaEditor (F4) ثم اضغط F7"
    }


# =================================================================================
#                              نقاط النهاية - الرؤية
# =================================================================================

@app.get("/screenshot", tags=["👁️ الرؤية"])
async def get_screenshot(mt5_only: bool = False):
    """
    ## التقاط صورة للشاشة
    
    ### المعاملات:
    - **mt5_only**: التقاط نافذة MT5 فقط
    
    ⚠️ استخدم هذا فقط إذا فشلت طرق pywinauto
    """
    if not PYAUTOGUI_AVAILABLE:
        raise HTTPException(status_code=503, detail="pyautogui غير متوفر")
    
    try:
        if mt5_only and strategy_tester and strategy_tester.smart_controller:
            screenshot = strategy_tester.smart_controller.get_screenshot()
        else:
            screenshot = pyautogui.screenshot()
        
        if screenshot:
            buffer = BytesIO()
            screenshot.save(buffer, format='PNG')
            img_base64 = base64.b64encode(buffer.getvalue()).decode()
            
            return {
                "success": True,
                "image": img_base64,
                "width": screenshot.width,
                "height": screenshot.height,
                "format": "png/base64"
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/screenshot/stream", tags=["👁️ الرؤية"])
async def stream_screenshot():
    """التقاط صورة وإرجاعها كـ PNG"""
    if not PYAUTOGUI_AVAILABLE:
        raise HTTPException(status_code=503, detail="pyautogui غير متوفر")
    
    screenshot = pyautogui.screenshot()
    buffer = BytesIO()
    screenshot.save(buffer, format='PNG')
    buffer.seek(0)
    return StreamingResponse(buffer, media_type="image/png")


# =================================================================================
#                              نقطة التشغيل
# =================================================================================

if __name__ == "__main__":
    print("""
    ╔══════════════════════════════════════════════════════════════════════════╗
    ║                                                                          ║
    ║          🚀 MT5 Ultimate Smart Control System v3.0                       ║
    ║          نظام التحكم النهائي الذكي في MetaTrader 5                        ║
    ║                                                                          ║
    ╠══════════════════════════════════════════════════════════════════════════╣
    ║                                                                          ║
    ║   المميزات:                                                              ║
    ║   ✅ تحكم ذكي في الواجهة (pywinauto) - بدون صور شاشة!                   ║
    ║   ✅ تداول حقيقي (MT5 API)                                              ║
    ║   ✅ Backtest تلقائي (INI files)                                        ║
    ║   ✅ رؤية الشاشة (احتياطي)                                              ║
    ║                                                                          ║
    ║   القدرات:                                                               ║
""")
    print(f"    ║   • pywinauto: {'✅ متوفر' if PYWINAUTO_AVAILABLE else '❌ غير متوفر'}".ljust(75) + "║")
    print(f"    ║   • pyautogui: {'✅ متوفر' if PYAUTOGUI_AVAILABLE else '❌ غير متوفر'}".ljust(75) + "║")
    print(f"    ║   • MT5 API: {'✅ متوفر' if MT5_AVAILABLE else '❌ غير متوفر'}".ljust(75) + "║")
    print("""    ║                                                                          ║
    ║   الخادم يعمل على:                                                       ║
    ║   📡 http://localhost:8000                                               ║
    ║   📚 http://localhost:8000/docs                                          ║
    ║                                                                          ║
    ║   للوصول من الإنترنت:                                                    ║
    ║   > ngrok http 8000                                                      ║
    ║                                                                          ║
    ╚══════════════════════════════════════════════════════════════════════════╝
    """)
    
    uvicorn.run(
        "mt5_ultimate_control:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
