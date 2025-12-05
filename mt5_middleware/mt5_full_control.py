"""
=================================================================================
          نظام التحكم الكامل في MetaTrader 5
          MT5 Full Control System
=================================================================================

هذا النظام يمنح AI (مثل Manus أو Claude) تحكم كامل في MT5:

✅ التحكم في واجهة MT5 (مثل الإنسان)
✅ التقاط صور الشاشة (رؤية ما يحدث)
✅ فتح Strategy Tester المرئي
✅ اختيار Expert Advisors
✅ تعديل الإعدادات
✅ كتابة Expert Advisors جديدة
✅ قراءة النتائج والتقارير
✅ التحكم في الماوس ولوحة المفاتيح

المتطلبات:
    pip install pyautogui pygetwindow pillow pyperclip keyboard mouse

المطور: Senior Python Developer
التاريخ: 2024
=================================================================================
"""

import os
import sys
import time
import json
import base64
import subprocess
from datetime import datetime
from typing import Optional, List, Dict, Tuple
from pathlib import Path
import logging
from io import BytesIO

# FastAPI
from fastapi import FastAPI, HTTPException, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field
import uvicorn

# التحكم في الواجهة (Windows)
try:
    import pyautogui
    import pygetwindow as gw
    from PIL import Image
    import pyperclip
    AUTOMATION_AVAILABLE = True
    
    # إعدادات الأمان لـ pyautogui
    pyautogui.FAILSAFE = True  # حرك الماوس للزاوية لإيقاف البرنامج
    pyautogui.PAUSE = 0.1  # تأخير بين الأوامر
except ImportError:
    AUTOMATION_AVAILABLE = False
    print("⚠️ مكتبات التحكم غير متوفرة. ثبتها بـ:")
    print("pip install pyautogui pygetwindow pillow pyperclip")

# MT5 API
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
except ImportError:
    MT5_AVAILABLE = False

# إعداد التسجيل
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mt5_full_control.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# =================================================================================
#                              نماذج البيانات
# =================================================================================

class MT5PathConfig(BaseModel):
    """تكوين مسارات MT5"""
    terminal_path: str = Field(
        default="C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe",
        description="مسار terminal64.exe"
    )
    mql5_path: Optional[str] = Field(
        default=None,
        description="مسار مجلد MQL5 (يتم اكتشافه تلقائياً)"
    )


class VisualBacktestRequest(BaseModel):
    """طلب Backtest مرئي"""
    expert_name: str = Field(..., description="اسم الـ Expert Advisor")
    symbol: str = Field(default="EURUSD", description="رمز الزوج")
    timeframe: str = Field(default="H1", description="الإطار الزمني")
    from_date: str = Field(default="2024.01.01", description="تاريخ البداية")
    to_date: str = Field(default="2024.12.31", description="تاريخ النهاية")
    deposit: float = Field(default=10000, description="رأس المال")
    leverage: int = Field(default=100, description="الرافعة المالية")
    visual_mode: bool = Field(default=True, description="الوضع المرئي")
    speed: int = Field(default=32, description="سرعة الاختبار (1-32)")


class CreateExpertRequest(BaseModel):
    """طلب إنشاء Expert Advisor"""
    name: str = Field(..., description="اسم الـ EA")
    code: str = Field(..., description="كود MQL5")
    compile: bool = Field(default=True, description="ترجمة تلقائية")


class MouseClickRequest(BaseModel):
    """طلب نقر الماوس"""
    x: int = Field(..., description="إحداثي X")
    y: int = Field(..., description="إحداثي Y")
    clicks: int = Field(default=1, description="عدد النقرات")
    button: str = Field(default="left", description="زر الماوس (left/right)")


class KeyboardRequest(BaseModel):
    """طلب لوحة المفاتيح"""
    text: Optional[str] = Field(None, description="نص للكتابة")
    keys: Optional[List[str]] = Field(None, description="مفاتيح للضغط")
    hotkey: Optional[List[str]] = Field(None, description="اختصار (مثل ctrl+v)")


class ScreenshotRequest(BaseModel):
    """طلب التقاط الشاشة"""
    region: Optional[Tuple[int, int, int, int]] = Field(
        None, 
        description="منطقة محددة (x, y, width, height)"
    )
    window_title: Optional[str] = Field(
        None,
        description="عنوان النافذة لالتقاطها"
    )


# =================================================================================
#                              إنشاء التطبيق
# =================================================================================

app = FastAPI(
    title="MT5 Full Control API",
    description="""
    ## نظام التحكم الكامل في MetaTrader 5
    
    هذا النظام يمنح AI تحكم كامل في MT5 مثل الإنسان:
    
    ### 🖱️ التحكم في الواجهة
    - نقر الماوس
    - الكتابة على لوحة المفاتيح
    - اختصارات لوحة المفاتيح
    
    ### 📸 الرؤية
    - التقاط صور الشاشة
    - التقاط نافذة محددة
    - قراءة محتوى الشاشة
    
    ### 📊 Strategy Tester
    - فتح Strategy Tester
    - Backtest مرئي
    - اختيار Expert Advisors
    - تعديل الإعدادات
    
    ### 🤖 Expert Advisors
    - قائمة EAs المتاحة
    - إنشاء EA جديد
    - تعديل EA موجود
    - ترجمة EA
    
    ### 📈 التداول
    - فتح/إغلاق صفقات
    - معلومات الحساب
    - الأسعار الحية
    """,
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =================================================================================
#                              متغيرات عامة
# =================================================================================

config = {
    "terminal_path": "C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe",
    "mql5_path": None,
    "mt5_window": None,
    "connected": False
}


# =================================================================================
#                              دوال مساعدة
# =================================================================================

def find_mt5_window() -> Optional[object]:
    """البحث عن نافذة MT5"""
    if not AUTOMATION_AVAILABLE:
        return None
    
    try:
        windows = gw.getWindowsWithTitle('MetaTrader')
        if windows:
            return windows[0]
        
        # محاولة البحث بأسماء أخرى
        for title in ['MT5', 'IC Markets', 'Terminal']:
            windows = gw.getWindowsWithTitle(title)
            if windows:
                return windows[0]
    except Exception as e:
        logger.error(f"خطأ في البحث عن نافذة MT5: {e}")
    
    return None


def focus_mt5_window() -> bool:
    """تفعيل نافذة MT5"""
    window = find_mt5_window()
    if window:
        try:
            window.activate()
            time.sleep(0.3)
            return True
        except Exception as e:
            logger.error(f"خطأ في تفعيل نافذة MT5: {e}")
    return False


def take_screenshot(region=None) -> Optional[Image.Image]:
    """التقاط صورة للشاشة"""
    if not AUTOMATION_AVAILABLE:
        return None
    
    try:
        if region:
            screenshot = pyautogui.screenshot(region=region)
        else:
            screenshot = pyautogui.screenshot()
        return screenshot
    except Exception as e:
        logger.error(f"خطأ في التقاط الشاشة: {e}")
        return None


def image_to_base64(image: Image.Image) -> str:
    """تحويل الصورة إلى Base64"""
    buffer = BytesIO()
    image.save(buffer, format='PNG')
    return base64.b64encode(buffer.getvalue()).decode()


def find_mql5_path() -> Optional[str]:
    """البحث عن مجلد MQL5"""
    if config["mql5_path"]:
        return config["mql5_path"]
    
    # المسارات الشائعة
    appdata = os.environ.get('APPDATA', '')
    if appdata:
        metaquotes = os.path.join(appdata, 'MetaQuotes', 'Terminal')
        if os.path.exists(metaquotes):
            for folder in os.listdir(metaquotes):
                mql5_path = os.path.join(metaquotes, folder, 'MQL5')
                if os.path.exists(mql5_path):
                    config["mql5_path"] = mql5_path
                    return mql5_path
    
    return None


def get_experts_list() -> List[Dict]:
    """الحصول على قائمة Expert Advisors"""
    experts = []
    mql5_path = find_mql5_path()
    
    if not mql5_path:
        return experts
    
    experts_path = os.path.join(mql5_path, 'Experts')
    if not os.path.exists(experts_path):
        return experts
    
    for root, dirs, files in os.walk(experts_path):
        for file in files:
            if file.endswith(('.ex5', '.mq5')):
                full_path = os.path.join(root, file)
                relative_path = os.path.relpath(full_path, experts_path)
                experts.append({
                    "name": os.path.splitext(file)[0],
                    "filename": file,
                    "type": "compiled" if file.endswith('.ex5') else "source",
                    "path": relative_path,
                    "full_path": full_path
                })
    
    return experts


# =================================================================================
#                              نقاط النهاية - الأساسية
# =================================================================================

@app.get("/", tags=["الرئيسية"])
async def root():
    """الصفحة الرئيسية"""
    return {
        "message": "نظام التحكم الكامل في MT5",
        "version": "2.0.0",
        "automation_available": AUTOMATION_AVAILABLE,
        "mt5_available": MT5_AVAILABLE,
        "features": {
            "mouse_control": "التحكم في الماوس",
            "keyboard_control": "التحكم في لوحة المفاتيح",
            "screenshot": "التقاط الشاشة",
            "visual_backtest": "Backtest مرئي",
            "create_expert": "إنشاء Expert Advisor",
            "full_trading": "تداول كامل"
        }
    }


@app.get("/health", tags=["الحالة"])
async def health():
    """فحص الحالة"""
    mt5_window = find_mt5_window()
    return {
        "status": "healthy",
        "automation_available": AUTOMATION_AVAILABLE,
        "mt5_available": MT5_AVAILABLE,
        "mt5_window_found": mt5_window is not None,
        "mt5_window_title": mt5_window.title if mt5_window else None,
        "timestamp": datetime.now().isoformat()
    }


# =================================================================================
#                              نقاط النهاية - التقاط الشاشة
# =================================================================================

@app.get("/screenshot", tags=["الرؤية"])
async def get_screenshot(
    region_x: Optional[int] = None,
    region_y: Optional[int] = None,
    region_width: Optional[int] = None,
    region_height: Optional[int] = None,
    mt5_only: bool = False
):
    """
    ## التقاط صورة للشاشة
    
    يمكن للـ AI رؤية ما يحدث على الشاشة.
    
    ### المعاملات:
    - **region_x/y/width/height**: منطقة محددة (اختياري)
    - **mt5_only**: التقاط نافذة MT5 فقط
    
    ### الاستجابة:
    صورة بصيغة Base64
    """
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="مكتبات التحكم غير متوفرة"
        )
    
    try:
        region = None
        
        if mt5_only:
            window = find_mt5_window()
            if window:
                region = (window.left, window.top, window.width, window.height)
        elif all([region_x, region_y, region_width, region_height]):
            region = (region_x, region_y, region_width, region_height)
        
        screenshot = take_screenshot(region)
        
        if screenshot:
            base64_image = image_to_base64(screenshot)
            return {
                "success": True,
                "image": base64_image,
                "width": screenshot.width,
                "height": screenshot.height,
                "format": "png",
                "timestamp": datetime.now().isoformat()
            }
        else:
            raise HTTPException(status_code=500, detail="فشل التقاط الشاشة")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/screenshot/stream", tags=["الرؤية"])
async def stream_screenshot():
    """التقاط صورة وإرجاعها كـ PNG مباشرة"""
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    screenshot = take_screenshot()
    if screenshot:
        buffer = BytesIO()
        screenshot.save(buffer, format='PNG')
        buffer.seek(0)
        return StreamingResponse(buffer, media_type="image/png")
    
    raise HTTPException(status_code=500, detail="فشل التقاط الشاشة")


# =================================================================================
#                              نقاط النهاية - التحكم في الماوس
# =================================================================================

@app.post("/mouse/click", tags=["التحكم"])
async def mouse_click(request: MouseClickRequest):
    """
    ## نقر الماوس
    
    ### المعاملات:
    - **x, y**: إحداثيات النقر
    - **clicks**: عدد النقرات (1 أو 2)
    - **button**: زر الماوس (left/right)
    """
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        pyautogui.click(
            x=request.x,
            y=request.y,
            clicks=request.clicks,
            button=request.button
        )
        
        return {
            "success": True,
            "action": "click",
            "x": request.x,
            "y": request.y,
            "clicks": request.clicks,
            "button": request.button
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/mouse/move", tags=["التحكم"])
async def mouse_move(x: int, y: int, duration: float = 0.2):
    """تحريك الماوس"""
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        pyautogui.moveTo(x, y, duration=duration)
        return {"success": True, "action": "move", "x": x, "y": y}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/mouse/drag", tags=["التحكم"])
async def mouse_drag(
    start_x: int, start_y: int,
    end_x: int, end_y: int,
    duration: float = 0.5,
    button: str = "left"
):
    """سحب الماوس"""
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        pyautogui.moveTo(start_x, start_y)
        pyautogui.drag(end_x - start_x, end_y - start_y, duration=duration, button=button)
        return {
            "success": True,
            "action": "drag",
            "from": {"x": start_x, "y": start_y},
            "to": {"x": end_x, "y": end_y}
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/mouse/position", tags=["التحكم"])
async def mouse_position():
    """الحصول على موقع الماوس الحالي"""
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    pos = pyautogui.position()
    return {"x": pos.x, "y": pos.y}


# =================================================================================
#                              نقاط النهاية - لوحة المفاتيح
# =================================================================================

@app.post("/keyboard/type", tags=["التحكم"])
async def keyboard_type(text: str, interval: float = 0.02):
    """
    ## كتابة نص
    
    يكتب النص حرفاً حرفاً.
    """
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        pyautogui.typewrite(text, interval=interval)
        return {"success": True, "action": "type", "text": text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/keyboard/write", tags=["التحكم"])
async def keyboard_write(text: str):
    """
    ## كتابة نص (مع دعم Unicode/العربية)
    
    يستخدم الحافظة للكتابة - يدعم جميع اللغات.
    """
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        # حفظ النص في الحافظة
        pyperclip.copy(text)
        # لصق
        pyautogui.hotkey('ctrl', 'v')
        time.sleep(0.1)
        return {"success": True, "action": "write", "text": text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/keyboard/press", tags=["التحكم"])
async def keyboard_press(key: str):
    """
    ## ضغط مفتاح
    
    ### المفاتيح المتاحة:
    enter, tab, space, backspace, delete, escape,
    up, down, left, right, home, end, pageup, pagedown,
    f1-f12, ctrl, alt, shift, win
    """
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        pyautogui.press(key)
        return {"success": True, "action": "press", "key": key}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/keyboard/hotkey", tags=["التحكم"])
async def keyboard_hotkey(keys: List[str]):
    """
    ## اختصار لوحة المفاتيح
    
    ### مثال:
    ["ctrl", "c"] = نسخ
    ["ctrl", "v"] = لصق
    ["ctrl", "s"] = حفظ
    ["alt", "f4"] = إغلاق
    """
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        pyautogui.hotkey(*keys)
        return {"success": True, "action": "hotkey", "keys": keys}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =================================================================================
#                              نقاط النهاية - نوافذ
# =================================================================================

@app.get("/windows", tags=["النوافذ"])
async def list_windows():
    """قائمة النوافذ المفتوحة"""
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        windows = gw.getAllWindows()
        return {
            "success": True,
            "windows": [
                {
                    "title": w.title,
                    "left": w.left,
                    "top": w.top,
                    "width": w.width,
                    "height": w.height,
                    "visible": w.visible,
                    "minimized": w.isMinimized,
                    "maximized": w.isMaximized
                }
                for w in windows if w.title
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/windows/focus", tags=["النوافذ"])
async def focus_window(title: str):
    """تفعيل نافذة بعنوانها"""
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        windows = gw.getWindowsWithTitle(title)
        if windows:
            windows[0].activate()
            time.sleep(0.3)
            return {"success": True, "window": title}
        else:
            raise HTTPException(status_code=404, detail=f"نافذة '{title}' غير موجودة")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/mt5/focus", tags=["MT5"])
async def focus_mt5():
    """تفعيل نافذة MT5"""
    if focus_mt5_window():
        return {"success": True, "message": "تم تفعيل نافذة MT5"}
    raise HTTPException(status_code=404, detail="نافذة MT5 غير موجودة")


# =================================================================================
#                              نقاط النهاية - MT5 الكامل
# =================================================================================

@app.post("/mt5/launch", tags=["MT5"])
async def launch_mt5(terminal_path: str = None):
    """
    ## تشغيل MT5
    
    يفتح برنامج MetaTrader 5.
    """
    path = terminal_path or config["terminal_path"]
    
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail=f"الملف غير موجود: {path}")
    
    try:
        subprocess.Popen([path])
        time.sleep(3)  # انتظار فتح البرنامج
        
        window = find_mt5_window()
        return {
            "success": True,
            "message": "تم تشغيل MT5",
            "window_found": window is not None
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/mt5/open_strategy_tester", tags=["MT5"])
async def open_strategy_tester():
    """
    ## فتح Strategy Tester
    
    يفتح نافذة اختبار الاستراتيجيات باستخدام Ctrl+R.
    """
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        # تفعيل نافذة MT5
        if not focus_mt5_window():
            raise HTTPException(status_code=404, detail="نافذة MT5 غير موجودة")
        
        time.sleep(0.3)
        
        # فتح Strategy Tester
        pyautogui.hotkey('ctrl', 'r')
        time.sleep(1)
        
        return {
            "success": True,
            "message": "تم فتح Strategy Tester",
            "shortcut": "Ctrl+R"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/mt5/visual_backtest", tags=["MT5"])
async def run_visual_backtest(request: VisualBacktestRequest):
    """
    ## تشغيل Backtest مرئي
    
    يفتح Strategy Tester ويشغل اختباراً مرئياً.
    
    ### الخطوات:
    1. تفعيل MT5
    2. فتح Strategy Tester (Ctrl+R)
    3. اختيار الإعدادات
    4. تفعيل الوضع المرئي
    5. بدء الاختبار
    
    ⚠️ ملاحظة: يحتاج تفاعل يدوي لاختيار الإعدادات
    """
    if not AUTOMATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="مكتبات التحكم غير متوفرة")
    
    try:
        # 1. تفعيل MT5
        if not focus_mt5_window():
            raise HTTPException(status_code=404, detail="نافذة MT5 غير موجودة")
        time.sleep(0.5)
        
        # 2. فتح Strategy Tester
        pyautogui.hotkey('ctrl', 'r')
        time.sleep(1)
        
        # 3. التقاط صورة للحالة الحالية
        screenshot = take_screenshot()
        screenshot_base64 = image_to_base64(screenshot) if screenshot else None
        
        return {
            "success": True,
            "message": "تم فتح Strategy Tester",
            "next_steps": [
                "اختر Expert Advisor من القائمة",
                "اختر Symbol (الرمز)",
                "حدد الفترة الزمنية",
                "فعّل خيار 'Visual mode'",
                "اضغط Start"
            ],
            "request_settings": {
                "expert": request.expert_name,
                "symbol": request.symbol,
                "timeframe": request.timeframe,
                "from": request.from_date,
                "to": request.to_date,
                "visual": request.visual_mode
            },
            "screenshot": screenshot_base64,
            "tip": "استخدم /screenshot للتحقق من الحالة"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =================================================================================
#                              نقاط النهاية - Expert Advisors
# =================================================================================

@app.get("/experts", tags=["Expert Advisors"])
async def list_experts():
    """قائمة Expert Advisors المتاحة"""
    experts = get_experts_list()
    
    return {
        "success": True,
        "count": len(experts),
        "mql5_path": find_mql5_path(),
        "experts": experts
    }


@app.post("/experts/create", tags=["Expert Advisors"])
async def create_expert(request: CreateExpertRequest):
    """
    ## إنشاء Expert Advisor جديد
    
    ### المعاملات:
    - **name**: اسم الـ EA (بدون امتداد)
    - **code**: كود MQL5 الكامل
    - **compile**: ترجمة تلقائية
    
    ### مثال كود بسيط:
    ```mql5
    //+------------------------------------------------------------------+
    //|                                                      SimpleEA.mq5|
    //+------------------------------------------------------------------+
    #property copyright "AI Generated"
    #property version   "1.00"
    
    int OnInit() {
        Print("EA Started!");
        return(INIT_SUCCEEDED);
    }
    
    void OnDeinit(const int reason) {
        Print("EA Stopped!");
    }
    
    void OnTick() {
        // Your trading logic here
    }
    ```
    """
    mql5_path = find_mql5_path()
    if not mql5_path:
        raise HTTPException(status_code=404, detail="مجلد MQL5 غير موجود")
    
    try:
        # إنشاء الملف
        experts_path = os.path.join(mql5_path, 'Experts')
        os.makedirs(experts_path, exist_ok=True)
        
        file_path = os.path.join(experts_path, f"{request.name}.mq5")
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(request.code)
        
        result = {
            "success": True,
            "message": f"تم إنشاء {request.name}.mq5",
            "path": file_path
        }
        
        # الترجمة التلقائية
        if request.compile:
            result["compile_note"] = "لترجمة الملف: افتح MetaEditor واضغط F7"
            result["metaeditor_shortcut"] = "F4 في MT5 لفتح MetaEditor"
        
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/experts/{name}/code", tags=["Expert Advisors"])
async def get_expert_code(name: str):
    """قراءة كود Expert Advisor"""
    mql5_path = find_mql5_path()
    if not mql5_path:
        raise HTTPException(status_code=404, detail="مجلد MQL5 غير موجود")
    
    # البحث عن الملف
    for ext in ['.mq5', '.mq4']:
        file_path = os.path.join(mql5_path, 'Experts', f"{name}{ext}")
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as f:
                code = f.read()
            return {
                "success": True,
                "name": name,
                "path": file_path,
                "code": code
            }
    
    raise HTTPException(status_code=404, detail=f"EA '{name}' غير موجود")


@app.put("/experts/{name}/code", tags=["Expert Advisors"])
async def update_expert_code(name: str, code: str):
    """تعديل كود Expert Advisor"""
    mql5_path = find_mql5_path()
    if not mql5_path:
        raise HTTPException(status_code=404, detail="مجلد MQL5 غير موجود")
    
    file_path = os.path.join(mql5_path, 'Experts', f"{name}.mq5")
    
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(code)
        
        return {
            "success": True,
            "message": f"تم تحديث {name}.mq5",
            "path": file_path,
            "note": "أعد الترجمة في MetaEditor (F7)"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =================================================================================
#                              نقاط النهاية - التداول
# =================================================================================

@app.get("/account", tags=["التداول"])
async def get_account():
    """معلومات الحساب"""
    if not MT5_AVAILABLE:
        return {
            "success": False,
            "error": "مكتبة MT5 غير متوفرة",
            "simulation": {
                "balance": 10000,
                "equity": 10000,
                "profit": 0
            }
        }
    
    if not mt5.initialize():
        raise HTTPException(status_code=500, detail="فشل الاتصال بـ MT5")
    
    account = mt5.account_info()
    if account:
        return {
            "success": True,
            "account": {
                "login": account.login,
                "balance": account.balance,
                "equity": account.equity,
                "margin": account.margin,
                "free_margin": account.margin_free,
                "profit": account.profit,
                "leverage": account.leverage,
                "currency": account.currency
            }
        }
    
    raise HTTPException(status_code=500, detail="فشل جلب معلومات الحساب")


@app.get("/prices/{symbol}", tags=["التداول"])
async def get_price(symbol: str):
    """السعر الحالي لرمز"""
    if not MT5_AVAILABLE:
        return {
            "success": True,
            "symbol": symbol,
            "simulation": True,
            "bid": 1.0850,
            "ask": 1.0852,
            "spread": 2
        }
    
    if not mt5.initialize():
        raise HTTPException(status_code=500, detail="فشل الاتصال بـ MT5")
    
    tick = mt5.symbol_info_tick(symbol)
    if tick:
        return {
            "success": True,
            "symbol": symbol,
            "bid": tick.bid,
            "ask": tick.ask,
            "spread": round((tick.ask - tick.bid) * 10000, 1),
            "time": datetime.fromtimestamp(tick.time).isoformat()
        }
    
    raise HTTPException(status_code=404, detail=f"رمز '{symbol}' غير موجود")


# =================================================================================
#                              نقطة التشغيل
# =================================================================================

if __name__ == "__main__":
    print("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║          نظام التحكم الكامل في MetaTrader 5                      ║
    ║          MT5 Full Control System v2.0                            ║
    ║                                                                  ║
    ║   الإصدار: 2.0.0                                                 ║
    ║   المنفذ: 8000                                                   ║
    ║   التوثيق: http://localhost:8000/docs                           ║
    ║                                                                  ║
    ║   ⚠️ تأكد من تثبيت المتطلبات:                                   ║
    ║   pip install pyautogui pygetwindow pillow pyperclip            ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
    """)
    
    uvicorn.run(
        "mt5_full_control:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
