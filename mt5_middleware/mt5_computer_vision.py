"""
================================================================================
         MT5 Computer Vision Control - رؤية حاسوبية لـ MT5
         AI Sees Your Screen Like a Human! 👁️
================================================================================

هذا السكريبت يعطي الـ AI القدرة على:
- 👁️ رؤية شاشة MT5 بشكل مستمر (كأنها فيديو)
- 🖱️ التحكم بالماوس
- ⌨️ التحكم بالكيبورد
- 🎯 التعرف على عناصر الواجهة
- 📊 تحليل الشارتات والبيانات

مستوحى من: Anthropic Computer Use
مُحسّن لـ: MetaTrader 5

================================================================================
"""

import os
import sys
import time
import json
import base64
import threading
from io import BytesIO
from datetime import datetime
from typing import Optional, Dict, List, Tuple, Any
from pathlib import Path

# محاولة استيراد المكتبات
try:
    from PIL import Image, ImageGrab, ImageDraw, ImageFont
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False
    print("⚠️ PIL غير متوفر: pip install Pillow")

try:
    import pyautogui
    pyautogui.FAILSAFE = False  # تعطيل الحماية
    PYAUTOGUI_AVAILABLE = True
except ImportError:
    PYAUTOGUI_AVAILABLE = False
    print("⚠️ PyAutoGUI غير متوفر: pip install pyautogui")

try:
    import pygetwindow as gw
    PYGETWINDOW_AVAILABLE = True
except ImportError:
    PYGETWINDOW_AVAILABLE = False
    print("⚠️ PyGetWindow غير متوفر: pip install pygetwindow")

try:
    from pywinauto import Application, Desktop
    from pywinauto.findwindows import ElementNotFoundError
    PYWINAUTO_AVAILABLE = True
except ImportError:
    PYWINAUTO_AVAILABLE = False
    print("⚠️ pywinauto غير متوفر: pip install pywinauto")


# ================================================================================
#                          الإعدادات
# ================================================================================

class Config:
    """إعدادات النظام"""
    
    # معدل التقاط الشاشة (FPS)
    CAPTURE_FPS = 2  # 2 frames per second
    
    # حجم الصورة المرسلة (للتقليل من حجم البيانات)
    MAX_IMAGE_WIDTH = 1280
    MAX_IMAGE_HEIGHT = 720
    
    # جودة JPEG
    JPEG_QUALITY = 80
    
    # مهلة العمليات
    OPERATION_TIMEOUT = 10  # ثواني
    
    # MT5 Window Title
    MT5_WINDOW_KEYWORDS = ['MetaTrader', 'MT5', 'terminal64']


# ================================================================================
#                          التقاط الشاشة
# ================================================================================

class ScreenCapture:
    """التقاط الشاشة بشكل مستمر"""
    
    def __init__(self):
        self.last_frame = None
        self.last_capture_time = 0
        self.is_running = False
        self.capture_thread = None
        self.mt5_window = None
        
    def find_mt5_window(self) -> Optional[Any]:
        """البحث عن نافذة MT5"""
        if PYGETWINDOW_AVAILABLE:
            for keyword in Config.MT5_WINDOW_KEYWORDS:
                windows = gw.getWindowsWithTitle(keyword)
                if windows:
                    return windows[0]
        return None
    
    def capture_full_screen(self) -> Optional[Image.Image]:
        """التقاط كامل الشاشة"""
        if not PIL_AVAILABLE:
            return None
        try:
            return ImageGrab.grab()
        except Exception as e:
            print(f"❌ خطأ في التقاط الشاشة: {e}")
            return None
    
    def capture_mt5_window(self) -> Optional[Image.Image]:
        """التقاط نافذة MT5 فقط"""
        if not PIL_AVAILABLE:
            return None
            
        window = self.find_mt5_window()
        if not window:
            return self.capture_full_screen()
        
        try:
            # تفعيل النافذة
            if hasattr(window, 'activate'):
                try:
                    window.activate()
                    time.sleep(0.1)
                except:
                    pass
            
            # التقاط المنطقة
            bbox = (window.left, window.top, window.right, window.bottom)
            return ImageGrab.grab(bbox=bbox)
        except Exception as e:
            print(f"❌ خطأ في التقاط نافذة MT5: {e}")
            return self.capture_full_screen()
    
    def capture_region(self, x: int, y: int, width: int, height: int) -> Optional[Image.Image]:
        """التقاط منطقة محددة"""
        if not PIL_AVAILABLE:
            return None
        try:
            bbox = (x, y, x + width, y + height)
            return ImageGrab.grab(bbox=bbox)
        except Exception as e:
            print(f"❌ خطأ في التقاط المنطقة: {e}")
            return None
    
    def resize_image(self, image: Image.Image) -> Image.Image:
        """تصغير الصورة للتقليل من حجم البيانات"""
        width, height = image.size
        
        if width > Config.MAX_IMAGE_WIDTH or height > Config.MAX_IMAGE_HEIGHT:
            ratio = min(Config.MAX_IMAGE_WIDTH / width, Config.MAX_IMAGE_HEIGHT / height)
            new_size = (int(width * ratio), int(height * ratio))
            return image.resize(new_size, Image.Resampling.LANCZOS)
        
        return image
    
    def image_to_base64(self, image: Image.Image, format: str = "JPEG") -> str:
        """تحويل الصورة إلى Base64"""
        buffer = BytesIO()
        
        if format.upper() == "JPEG":
            # تحويل RGBA إلى RGB للـ JPEG
            if image.mode == 'RGBA':
                image = image.convert('RGB')
            image.save(buffer, format="JPEG", quality=Config.JPEG_QUALITY)
        else:
            image.save(buffer, format=format)
        
        return base64.b64encode(buffer.getvalue()).decode('utf-8')
    
    def get_screen_state(self, mt5_only: bool = True) -> Dict:
        """الحصول على حالة الشاشة الحالية"""
        if mt5_only:
            image = self.capture_mt5_window()
        else:
            image = self.capture_full_screen()
        
        if not image:
            return {"error": "فشل التقاط الشاشة"}
        
        # تصغير الصورة
        image = self.resize_image(image)
        
        # تحويل إلى Base64
        base64_image = self.image_to_base64(image)
        
        return {
            "timestamp": datetime.now().isoformat(),
            "width": image.size[0],
            "height": image.size[1],
            "image_base64": base64_image,
            "format": "jpeg"
        }
    
    def save_screenshot(self, path: str, mt5_only: bool = True) -> bool:
        """حفظ لقطة شاشة"""
        if mt5_only:
            image = self.capture_mt5_window()
        else:
            image = self.capture_full_screen()
        
        if not image:
            return False
        
        try:
            image.save(path)
            return True
        except Exception as e:
            print(f"❌ خطأ في حفظ الصورة: {e}")
            return False


# ================================================================================
#                          التحكم بالماوس والكيبورد
# ================================================================================

class InputController:
    """التحكم بالماوس والكيبورد"""
    
    def __init__(self):
        self.screen_capture = ScreenCapture()
    
    # -------------------- الماوس --------------------
    
    def move_mouse(self, x: int, y: int, duration: float = 0.2) -> bool:
        """تحريك الماوس"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            pyautogui.moveTo(x, y, duration=duration)
            return True
        except Exception as e:
            print(f"❌ خطأ في تحريك الماوس: {e}")
            return False
    
    def click(self, x: int = None, y: int = None, button: str = 'left', clicks: int = 1) -> bool:
        """النقر"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            if x is not None and y is not None:
                pyautogui.click(x, y, button=button, clicks=clicks)
            else:
                pyautogui.click(button=button, clicks=clicks)
            return True
        except Exception as e:
            print(f"❌ خطأ في النقر: {e}")
            return False
    
    def double_click(self, x: int = None, y: int = None) -> bool:
        """نقر مزدوج"""
        return self.click(x, y, clicks=2)
    
    def right_click(self, x: int = None, y: int = None) -> bool:
        """نقر يمين"""
        return self.click(x, y, button='right')
    
    def drag(self, start_x: int, start_y: int, end_x: int, end_y: int, duration: float = 0.5) -> bool:
        """السحب"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            pyautogui.moveTo(start_x, start_y)
            pyautogui.drag(end_x - start_x, end_y - start_y, duration=duration)
            return True
        except Exception as e:
            print(f"❌ خطأ في السحب: {e}")
            return False
    
    def scroll(self, clicks: int, x: int = None, y: int = None) -> bool:
        """التمرير"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            if x is not None and y is not None:
                pyautogui.scroll(clicks, x, y)
            else:
                pyautogui.scroll(clicks)
            return True
        except Exception as e:
            print(f"❌ خطأ في التمرير: {e}")
            return False
    
    # -------------------- الكيبورد --------------------
    
    def type_text(self, text: str, interval: float = 0.02) -> bool:
        """كتابة نص"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            pyautogui.typewrite(text, interval=interval)
            return True
        except Exception as e:
            print(f"❌ خطأ في الكتابة: {e}")
            return False
    
    def type_unicode(self, text: str) -> bool:
        """كتابة نص يونيكود (يدعم العربية)"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            import pyperclip
            pyperclip.copy(text)
            pyautogui.hotkey('ctrl', 'v')
            return True
        except Exception as e:
            # fallback
            try:
                for char in text:
                    pyautogui.press(char)
                return True
            except:
                print(f"❌ خطأ في كتابة اليونيكود: {e}")
                return False
    
    def press_key(self, key: str) -> bool:
        """ضغط مفتاح"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            pyautogui.press(key)
            return True
        except Exception as e:
            print(f"❌ خطأ في ضغط المفتاح: {e}")
            return False
    
    def hotkey(self, *keys) -> bool:
        """اختصار لوحة المفاتيح"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            pyautogui.hotkey(*keys)
            return True
        except Exception as e:
            print(f"❌ خطأ في الاختصار: {e}")
            return False
    
    def key_down(self, key: str) -> bool:
        """الضغط المستمر على مفتاح"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            pyautogui.keyDown(key)
            return True
        except Exception as e:
            print(f"❌ خطأ: {e}")
            return False
    
    def key_up(self, key: str) -> bool:
        """رفع مفتاح"""
        if not PYAUTOGUI_AVAILABLE:
            return False
        try:
            pyautogui.keyUp(key)
            return True
        except Exception as e:
            print(f"❌ خطأ: {e}")
            return False
    
    # -------------------- أوامر MT5 مخصصة --------------------
    
    def open_strategy_tester(self) -> bool:
        """فتح Strategy Tester (Ctrl+R)"""
        return self.hotkey('ctrl', 'r')
    
    def start_backtest(self) -> bool:
        """بدء الاختبار (F5)"""
        return self.press_key('f5')
    
    def stop_backtest(self) -> bool:
        """إيقاف الاختبار (F5 مرة أخرى أو Escape)"""
        return self.press_key('escape')
    
    def open_navigator(self) -> bool:
        """فتح Navigator (Ctrl+N)"""
        return self.hotkey('ctrl', 'n')
    
    def open_market_watch(self) -> bool:
        """فتح Market Watch (Ctrl+M)"""
        return self.hotkey('ctrl', 'm')
    
    def new_chart(self) -> bool:
        """فتح شارت جديد"""
        return self.hotkey('ctrl', 'n')
    
    def save_template(self) -> bool:
        """حفظ القالب"""
        return self.hotkey('ctrl', 't')
    
    def toggle_auto_trading(self) -> bool:
        """تفعيل/تعطيل التداول التلقائي (Ctrl+E)"""
        return self.hotkey('ctrl', 'e')


# ================================================================================
#                          التعرف على عناصر MT5
# ================================================================================

class MT5ElementRecognizer:
    """التعرف على عناصر واجهة MT5"""
    
    def __init__(self):
        self.app = None
        self.main_window = None
        
    def connect_to_mt5(self) -> bool:
        """الاتصال بنافذة MT5"""
        if not PYWINAUTO_AVAILABLE:
            return False
            
        try:
            # البحث عن MT5
            self.app = Application(backend='uia').connect(title_re='.*MetaTrader.*')
            self.main_window = self.app.window(title_re='.*MetaTrader.*')
            return True
        except Exception as e:
            print(f"❌ لم يتم العثور على MT5: {e}")
            return False
    
    def get_all_elements(self) -> List[Dict]:
        """الحصول على جميع العناصر المرئية"""
        if not self.main_window:
            if not self.connect_to_mt5():
                return []
        
        elements = []
        try:
            for element in self.main_window.descendants():
                try:
                    rect = element.rectangle()
                    elements.append({
                        "name": element.window_text() or "Unknown",
                        "type": element.element_info.control_type,
                        "x": rect.left,
                        "y": rect.top,
                        "width": rect.width(),
                        "height": rect.height(),
                        "enabled": element.is_enabled(),
                        "visible": element.is_visible()
                    })
                except:
                    continue
        except Exception as e:
            print(f"❌ خطأ في قراءة العناصر: {e}")
        
        return elements
    
    def find_element_by_name(self, name: str) -> Optional[Dict]:
        """البحث عن عنصر بالاسم"""
        elements = self.get_all_elements()
        for el in elements:
            if name.lower() in el['name'].lower():
                return el
        return None
    
    def find_button(self, text: str) -> Optional[Dict]:
        """البحث عن زر"""
        elements = self.get_all_elements()
        for el in elements:
            if el['type'] == 'Button' and text.lower() in el['name'].lower():
                return el
        return None
    
    def get_strategy_tester_elements(self) -> Dict:
        """الحصول على عناصر Strategy Tester"""
        result = {
            "expert_dropdown": None,
            "symbol_dropdown": None,
            "timeframe_dropdown": None,
            "start_button": None,
            "visual_checkbox": None
        }
        
        elements = self.get_all_elements()
        
        for el in elements:
            name_lower = el['name'].lower()
            
            if 'expert' in name_lower and el['type'] in ['ComboBox', 'Edit']:
                result['expert_dropdown'] = el
            elif 'symbol' in name_lower and el['type'] in ['ComboBox', 'Edit']:
                result['symbol_dropdown'] = el
            elif 'period' in name_lower or 'timeframe' in name_lower:
                result['timeframe_dropdown'] = el
            elif 'start' in name_lower and el['type'] == 'Button':
                result['start_button'] = el
            elif 'visual' in name_lower and el['type'] == 'CheckBox':
                result['visual_checkbox'] = el
        
        return result


# ================================================================================
#                          المتحكم الرئيسي
# ================================================================================

class MT5ComputerVision:
    """
    المتحكم الرئيسي - رؤية حاسوبية كاملة لـ MT5
    
    مثل Claude Computer Use لكن مُحسّن لـ MT5!
    """
    
    def __init__(self):
        self.screen = ScreenCapture()
        self.input = InputController()
        self.recognizer = MT5ElementRecognizer()
        
        print("=" * 60)
        print("  🖥️ MT5 Computer Vision Control")
        print("  AI يشوف شاشتك ويتحكم فيها!")
        print("=" * 60)
        print(f"  ✅ PIL: {PIL_AVAILABLE}")
        print(f"  ✅ PyAutoGUI: {PYAUTOGUI_AVAILABLE}")
        print(f"  ✅ PyGetWindow: {PYGETWINDOW_AVAILABLE}")
        print(f"  ✅ pywinauto: {PYWINAUTO_AVAILABLE}")
        print("=" * 60)
    
    # -------------------- الرؤية --------------------
    
    def see(self, mt5_only: bool = True) -> Dict:
        """
        👁️ أشوف الشاشة
        
        Returns:
            Dict مع الصورة بـ Base64 والمعلومات
        """
        return self.screen.get_screen_state(mt5_only)
    
    def see_and_save(self, path: str, mt5_only: bool = True) -> bool:
        """أشوف وأحفظ الصورة"""
        return self.screen.save_screenshot(path, mt5_only)
    
    def see_region(self, x: int, y: int, width: int, height: int) -> Optional[str]:
        """أشوف منطقة محددة"""
        image = self.screen.capture_region(x, y, width, height)
        if image:
            return self.screen.image_to_base64(image)
        return None
    
    # -------------------- التحكم --------------------
    
    def click_at(self, x: int, y: int) -> bool:
        """🖱️ أنقر في نقطة محددة"""
        return self.input.click(x, y)
    
    def double_click_at(self, x: int, y: int) -> bool:
        """🖱️ نقر مزدوج"""
        return self.input.double_click(x, y)
    
    def right_click_at(self, x: int, y: int) -> bool:
        """🖱️ نقر يمين"""
        return self.input.right_click(x, y)
    
    def type_text(self, text: str) -> bool:
        """⌨️ أكتب نص"""
        return self.input.type_text(text)
    
    def press(self, key: str) -> bool:
        """⌨️ أضغط مفتاح"""
        return self.input.press_key(key)
    
    def hotkey(self, *keys) -> bool:
        """⌨️ اختصار"""
        return self.input.hotkey(*keys)
    
    def scroll(self, amount: int) -> bool:
        """🖱️ تمرير"""
        return self.input.scroll(amount)
    
    # -------------------- أوامر MT5 --------------------
    
    def open_tester(self) -> bool:
        """فتح Strategy Tester"""
        return self.input.open_strategy_tester()
    
    def start_test(self) -> bool:
        """بدء الاختبار"""
        return self.input.start_backtest()
    
    def stop_test(self) -> bool:
        """إيقاف الاختبار"""
        return self.input.stop_backtest()
    
    # -------------------- التعرف على العناصر --------------------
    
    def find_element(self, name: str) -> Optional[Dict]:
        """البحث عن عنصر"""
        return self.recognizer.find_element_by_name(name)
    
    def find_and_click(self, name: str) -> bool:
        """البحث عن عنصر والنقر عليه"""
        element = self.find_element(name)
        if element:
            x = element['x'] + element['width'] // 2
            y = element['y'] + element['height'] // 2
            return self.click_at(x, y)
        return False
    
    def get_tester_controls(self) -> Dict:
        """الحصول على عناصر التحكم في Strategy Tester"""
        return self.recognizer.get_strategy_tester_elements()
    
    # -------------------- الأتمتة الكاملة --------------------
    
    def run_visual_backtest(self, expert_name: str, symbol: str = "EURUSD") -> Dict:
        """
        🚀 تشغيل Backtest مرئي كامل
        
        1. فتح Strategy Tester
        2. اختيار EA
        3. اختيار الزوج
        4. تفعيل Visual
        5. بدء الاختبار
        """
        results = {"steps": [], "success": False}
        
        # الخطوة 1: فتح Strategy Tester
        self.open_tester()
        time.sleep(1)
        results["steps"].append("✅ فتح Strategy Tester")
        
        # الخطوة 2: البحث عن عناصر التحكم
        controls = self.get_tester_controls()
        
        # الخطوة 3: اختيار EA
        if controls['expert_dropdown']:
            el = controls['expert_dropdown']
            self.click_at(el['x'] + el['width']//2, el['y'] + el['height']//2)
            time.sleep(0.3)
            self.type_text(expert_name)
            self.press('enter')
            results["steps"].append(f"✅ اختيار EA: {expert_name}")
        
        # الخطوة 4: اختيار الزوج
        if controls['symbol_dropdown']:
            el = controls['symbol_dropdown']
            self.click_at(el['x'] + el['width']//2, el['y'] + el['height']//2)
            time.sleep(0.3)
            self.type_text(symbol)
            self.press('enter')
            results["steps"].append(f"✅ اختيار الزوج: {symbol}")
        
        # الخطوة 5: تفعيل Visual
        if controls['visual_checkbox']:
            el = controls['visual_checkbox']
            self.click_at(el['x'] + el['width']//2, el['y'] + el['height']//2)
            results["steps"].append("✅ تفعيل Visual Mode")
        
        # الخطوة 6: بدء الاختبار
        if controls['start_button']:
            el = controls['start_button']
            self.click_at(el['x'] + el['width']//2, el['y'] + el['height']//2)
            results["steps"].append("✅ بدء الاختبار")
            results["success"] = True
        else:
            # استخدام F5
            self.press('f5')
            results["steps"].append("✅ بدء الاختبار (F5)")
            results["success"] = True
        
        return results


# ================================================================================
#                          FastAPI Server (اختياري)
# ================================================================================

def create_vision_server():
    """إنشاء سيرفر FastAPI للرؤية الحاسوبية"""
    try:
        from fastapi import FastAPI, HTTPException
        from fastapi.middleware.cors import CORSMiddleware
        from pydantic import BaseModel
    except ImportError:
        print("❌ FastAPI غير متوفر: pip install fastapi uvicorn")
        return None
    
    app = FastAPI(title="MT5 Computer Vision API")
    
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"]
    )
    
    vision = MT5ComputerVision()
    
    class ClickRequest(BaseModel):
        x: int
        y: int
    
    class TypeRequest(BaseModel):
        text: str
    
    class KeyRequest(BaseModel):
        key: str
    
    @app.get("/")
    async def root():
        return {
            "name": "MT5 Computer Vision API",
            "description": "AI يشوف شاشتك ويتحكم فيها!",
            "endpoints": ["/see", "/click", "/type", "/press", "/tester", "/backtest"]
        }
    
    @app.get("/see")
    async def see_screen(mt5_only: bool = True):
        """👁️ رؤية الشاشة"""
        return vision.see(mt5_only)
    
    @app.post("/click")
    async def click(request: ClickRequest):
        """🖱️ نقر"""
        success = vision.click_at(request.x, request.y)
        return {"success": success}
    
    @app.post("/type")
    async def type_text(request: TypeRequest):
        """⌨️ كتابة"""
        success = vision.type_text(request.text)
        return {"success": success}
    
    @app.post("/press")
    async def press_key(request: KeyRequest):
        """⌨️ ضغط مفتاح"""
        success = vision.press(request.key)
        return {"success": success}
    
    @app.post("/tester")
    async def open_tester():
        """فتح Strategy Tester"""
        success = vision.open_tester()
        return {"success": success}
    
    @app.post("/backtest")
    async def run_backtest(expert: str = "AI_RSI_Strategy", symbol: str = "EURUSD"):
        """🚀 تشغيل Backtest"""
        return vision.run_visual_backtest(expert, symbol)
    
    return app


# ================================================================================
#                          نقطة الدخول
# ================================================================================

if __name__ == "__main__":
    print("""
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║          🖥️ MT5 Computer Vision Control                         ║
║          AI يشوف شاشتك ويتحكم فيها مثل الإنسان!                 ║
║                                                                  ║
║   الاستخدام:                                                     ║
║   1. كمكتبة Python:                                              ║
║      from mt5_computer_vision import MT5ComputerVision           ║
║      ai = MT5ComputerVision()                                    ║
║      ai.see()           # رؤية الشاشة                           ║
║      ai.click_at(x, y)  # نقر                                    ║
║      ai.type_text("hi") # كتابة                                  ║
║                                                                  ║
║   2. كـ API Server:                                              ║
║      uvicorn mt5_computer_vision:create_vision_server --reload   ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""")
    
    # تشغيل السيرفر
    try:
        import uvicorn
        app = create_vision_server()
        if app:
            print("\n🚀 جاري تشغيل السيرفر على http://localhost:8001")
            uvicorn.run(app, host="0.0.0.0", port=8001)
    except ImportError:
        print("\n💡 لتشغيل السيرفر: pip install uvicorn")
        
        # وضع تفاعلي بديل
        print("\n🎮 الوضع التفاعلي:")
        vision = MT5ComputerVision()
        
        while True:
            cmd = input("\n>>> ").strip().lower()
            
            if cmd in ['exit', 'quit', 'q']:
                break
            elif cmd == 'see':
                state = vision.see()
                print(f"📸 Screen: {state['width']}x{state['height']}")
            elif cmd == 'tester':
                vision.open_tester()
                print("✅ فتح Strategy Tester")
            elif cmd == 'start':
                vision.start_test()
                print("✅ بدء الاختبار")
            elif cmd.startswith('click '):
                parts = cmd.split()
                if len(parts) == 3:
                    x, y = int(parts[1]), int(parts[2])
                    vision.click_at(x, y)
                    print(f"✅ نقر في ({x}, {y})")
            else:
                print("الأوامر: see, tester, start, click x y, exit")
