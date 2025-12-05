"""
=================================================================================
                    خادم وسيط MetaTrader 5 (MT5 Middleware Server)
=================================================================================

الوصف:
    هذا التطبيق يعمل كجسر (Bridge) بين تطبيقات الويب الخارجية ومنصة MetaTrader 5.
    يوفر واجهة برمجة تطبيقات REST API للتحكم في MT5 وتشغيل اختبارات الاستراتيجيات.

المتطلبات:
    - Python 3.8+
    - MetaTrader 5 مثبت على Windows
    - المكتبات المطلوبة (انظر requirements.txt)

المطور: Senior Python Developer
التاريخ: 2024
=================================================================================
"""

import os
import sys
import time
import subprocess
import configparser
from datetime import datetime
from typing import Optional, List
from pathlib import Path
import logging

# إعداد FastAPI والمكتبات المساعدة
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

# ملاحظة: مكتبة MetaTrader5 تعمل فقط على Windows
# على Linux/Mac سنستخدم محاكاة للاختبار
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
except ImportError:
    MT5_AVAILABLE = False
    print("⚠️ تحذير: مكتبة MetaTrader5 غير متوفرة. سيتم تشغيل الخادم في وضع المحاكاة.")

# =================================================================================
#                              إعداد التسجيل (Logging)
# =================================================================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mt5_server.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# =================================================================================
#                              نماذج البيانات (Pydantic Models)
# =================================================================================

class ConnectionRequest(BaseModel):
    """
    نموذج طلب الاتصال بـ MT5
    
    المعاملات:
        terminal_path: المسار الكامل لملف terminal64.exe
        login: رقم حساب التداول (اختياري)
        password: كلمة المرور (اختياري)
        server: اسم خادم الوسيط (اختياري)
    """
    terminal_path: str = Field(
        ..., 
        description="المسار الكامل لملف terminal64.exe",
        example="C:/Program Files/MetaTrader 5/terminal64.exe"
    )
    login: Optional[int] = Field(None, description="رقم حساب التداول")
    password: Optional[str] = Field(None, description="كلمة مرور الحساب")
    server: Optional[str] = Field(None, description="اسم خادم الوسيط")


class BacktestRequest(BaseModel):
    """
    نموذج طلب تشغيل اختبار الاستراتيجية (Backtest)
    
    المعاملات:
        terminal_path: المسار الكامل لملف terminal64.exe
        expert_advisor: اسم المستشار الخبير (EA)
        symbol: رمز الزوج المراد اختباره (مثل EURUSD)
        period: الإطار الزمني (M1, M5, M15, M30, H1, H4, D1, W1, MN)
        from_date: تاريخ بداية الاختبار
        to_date: تاريخ نهاية الاختبار
        deposit: رأس المال الابتدائي
        leverage: الرافعة المالية
        model: نوع النمذجة (0=كل تيك, 1=نقاط التحكم, 2=أسعار الافتتاح)
        optimization: تفعيل التحسين
        visual: تفعيل الوضع المرئي
    """
    terminal_path: str = Field(
        ..., 
        description="المسار الكامل لملف terminal64.exe"
    )
    expert_advisor: str = Field(
        ..., 
        description="اسم المستشار الخبير (بدون .ex5)",
        example="ExpertMACD"
    )
    symbol: str = Field(
        ..., 
        description="رمز الزوج",
        example="EURUSD"
    )
    period: str = Field(
        default="H1",
        description="الإطار الزمني",
        example="H1"
    )
    from_date: str = Field(
        ..., 
        description="تاريخ البداية بصيغة YYYY.MM.DD",
        example="2024.01.01"
    )
    to_date: str = Field(
        ..., 
        description="تاريخ النهاية بصيغة YYYY.MM.DD",
        example="2024.06.30"
    )
    deposit: float = Field(
        default=10000.0,
        description="رأس المال الابتدائي"
    )
    leverage: int = Field(
        default=100,
        description="الرافعة المالية (1:100)"
    )
    model: int = Field(
        default=0,
        description="نوع النمذجة: 0=كل تيك, 1=نقاط التحكم, 2=أسعار الافتتاح"
    )
    optimization: int = Field(
        default=0,
        description="التحسين: 0=معطل, 1=بطيء, 2=خوارزمية جينية, 3=كل المعاملات"
    )
    visual: int = Field(
        default=0,
        description="الوضع المرئي: 0=معطل, 1=مفعل"
    )


class ExpertsListRequest(BaseModel):
    """
    نموذج طلب قائمة المستشارين الخبراء
    
    المعاملات:
        mql5_path: المسار لمجلد MQL5
    """
    mql5_path: str = Field(
        ..., 
        description="المسار لمجلد MQL5",
        example="C:/Users/Username/AppData/Roaming/MetaQuotes/Terminal/XXXXX/MQL5"
    )


# =================================================================================
#                              إنشاء تطبيق FastAPI
# =================================================================================

app = FastAPI(
    title="MT5 Middleware API",
    description="""
    ## خادم وسيط MetaTrader 5
    
    هذا الخادم يوفر واجهة برمجة تطبيقات للتفاعل مع منصة MetaTrader 5.
    
    ### الميزات الرئيسية:
    - 🔌 إدارة الاتصال بـ MT5
    - 📊 تشغيل اختبارات الاستراتيجيات (Backtest)
    - 📋 استعراض المستشارين الخبراء
    - 💰 معلومات الحساب
    
    ### ملاحظة مهمة:
    هذا الخادم يعمل فقط على نظام Windows مع تثبيت MetaTrader 5.
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# =================================================================================
#                              إعداد CORS
# =================================================================================
# السماح للتطبيقات الخارجية (مثل تطبيقات الويب) بالتواصل مع الخادم

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # في الإنتاج، حدد النطاقات المسموحة فقط
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =================================================================================
#                              متغيرات الحالة العامة
# =================================================================================

# حالة الاتصال الحالية
connection_state = {
    "connected": False,
    "terminal_path": None,
    "login": None,
    "server": None
}

# =================================================================================
#                              دوال مساعدة
# =================================================================================

def get_timeframe_constant(period: str) -> int:
    """
    تحويل اسم الإطار الزمني إلى الثابت المقابل
    
    المعاملات:
        period: اسم الإطار الزمني (M1, M5, etc.)
    
    المخرجات:
        الثابت الرقمي للإطار الزمني
    """
    timeframes = {
        "M1": 1,      # دقيقة واحدة
        "M5": 5,      # 5 دقائق
        "M15": 15,    # 15 دقيقة
        "M30": 30,    # 30 دقيقة
        "H1": 60,     # ساعة واحدة
        "H4": 240,    # 4 ساعات
        "D1": 1440,   # يوم واحد
        "W1": 10080,  # أسبوع واحد
        "MN": 43200   # شهر واحد
    }
    return timeframes.get(period.upper(), 60)


def generate_ini_config(request: BacktestRequest, config_path: str) -> str:
    """
    إنشاء ملف تكوين .ini لتشغيل Strategy Tester
    
    كيف يعمل Strategy Tester عبر ملف .ini:
    =========================================
    
    MT5 يدعم تشغيل اختبار الاستراتيجية من سطر الأوامر باستخدام ملف تكوين .ini
    يحتوي هذا الملف على جميع الإعدادات المطلوبة للاختبار:
    
    1. [Tester] - القسم الرئيسي لإعدادات الاختبار
       - Expert: اسم المستشار الخبير
       - Symbol: رمز الزوج
       - Period: الإطار الزمني
       - FromDate/ToDate: فترة الاختبار
       - Model: نوع النمذجة (الدقة)
       - Optimization: نوع التحسين
       
    2. طريقة التشغيل:
       terminal64.exe /config:path_to_config.ini
       
    3. المخرجات:
       - ملف التقرير (Report)
       - سجل العمليات (Journal)
    
    المعاملات:
        request: طلب الاختبار الخلفي
        config_path: مسار حفظ ملف التكوين
    
    المخرجات:
        المسار الكامل لملف التكوين المُنشأ
    """
    
    # إنشاء محتوى ملف التكوين
    config_content = f"""
; ============================================================
; ملف تكوين Strategy Tester - تم إنشاؤه تلقائياً
; التاريخ: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
; ============================================================

[Tester]
; === إعدادات المستشار الخبير ===
Expert={request.expert_advisor}
ExpertParameters=

; === إعدادات الرمز والإطار الزمني ===
Symbol={request.symbol}
Period={request.period}

; === فترة الاختبار ===
FromDate={request.from_date}
ToDate={request.to_date}

; === إعدادات النمذجة ===
; Model: 0 = كل تيك (أعلى دقة)
;        1 = نقاط التحكم (1 دقيقة OHLC)
;        2 = أسعار الافتتاح فقط (أسرع)
Model={request.model}

; === إعدادات التحسين ===
; Optimization: 0 = معطل
;               1 = بطيء (كامل)
;               2 = خوارزمية جينية
;               3 = كل المعاملات
Optimization={request.optimization}

; === إعدادات العرض ===
Visual={request.visual}

; === إعدادات رأس المال ===
Deposit={request.deposit}
Leverage={request.leverage}
Currency=USD

; === إعدادات التقرير ===
Report=backtest_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}
ReplaceReport=1
ShutdownTerminal=1

; === إعدادات إضافية ===
UseLocal=1
UseRemote=0
UseCloud=0
"""
    
    # حفظ ملف التكوين
    full_path = os.path.abspath(config_path)
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(config_content)
    
    logger.info(f"تم إنشاء ملف التكوين: {full_path}")
    return full_path


def find_experts(mql5_path: str) -> List[dict]:
    """
    البحث عن المستشارين الخبراء في مجلد MQL5/Experts
    
    المعاملات:
        mql5_path: المسار لمجلد MQL5
    
    المخرجات:
        قائمة بالمستشارين الخبراء مع معلوماتهم
    """
    experts = []
    experts_path = os.path.join(mql5_path, "Experts")
    
    if not os.path.exists(experts_path):
        logger.warning(f"مجلد Experts غير موجود: {experts_path}")
        return experts
    
    # البحث عن ملفات .ex5 (المستشارين المترجمين) و .mq5 (الكود المصدري)
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
                    "full_path": full_path,
                    "size": os.path.getsize(full_path),
                    "modified": datetime.fromtimestamp(
                        os.path.getmtime(full_path)
                    ).isoformat()
                })
    
    return experts


# =================================================================================
#                              نقاط النهاية (API Endpoints)
# =================================================================================

@app.get("/", tags=["الرئيسية"])
async def root():
    """
    الصفحة الرئيسية - معلومات عامة عن الخادم
    """
    return {
        "message": "مرحباً بك في خادم MT5 الوسيط",
        "version": "1.0.0",
        "status": "running",
        "mt5_available": MT5_AVAILABLE,
        "endpoints": {
            "docs": "/docs",
            "redoc": "/redoc",
            "connect": "POST /connect",
            "disconnect": "POST /disconnect",
            "run_backtest": "POST /run_backtest",
            "list_experts": "GET /list_experts",
            "account_info": "GET /account_info"
        }
    }


@app.get("/health", tags=["الحالة"])
async def health_check():
    """
    فحص حالة الخادم والاتصال
    """
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "mt5_connected": connection_state["connected"],
        "mt5_available": MT5_AVAILABLE
    }


# =================================================================================
#                              إدارة الاتصال
# =================================================================================

@app.post("/connect", tags=["الاتصال"])
async def connect_mt5(request: ConnectionRequest):
    """
    ## الاتصال بـ MetaTrader 5
    
    يقوم بتهيئة الاتصال مع منصة MT5 باستخدام المسار المحدد.
    
    ### المعاملات:
    - **terminal_path**: المسار الكامل لملف terminal64.exe
    - **login**: رقم حساب التداول (اختياري)
    - **password**: كلمة المرور (اختياري)
    - **server**: اسم خادم الوسيط (اختياري)
    
    ### مثال على المسار:
    ```
    C:/Program Files/MetaTrader 5/terminal64.exe
    ```
    
    ### ملاحظة:
    تأكد من أن MT5 مثبت وأن المسار صحيح.
    """
    global connection_state
    
    # التحقق من وجود الملف
    if not os.path.exists(request.terminal_path):
        logger.error(f"ملف MT5 غير موجود: {request.terminal_path}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف terminal64.exe غير موجود في المسار: {request.terminal_path}"
        )
    
    if not MT5_AVAILABLE:
        # وضع المحاكاة للاختبار على Linux/Mac
        logger.warning("وضع المحاكاة: MT5 غير متوفر")
        connection_state = {
            "connected": True,
            "terminal_path": request.terminal_path,
            "login": request.login,
            "server": request.server,
            "mode": "simulation"
        }
        return {
            "success": True,
            "message": "تم الاتصال (وضع المحاكاة)",
            "mode": "simulation",
            "warning": "مكتبة MT5 غير متوفرة - هذا وضع محاكاة للاختبار"
        }
    
    try:
        # محاولة تهيئة MT5
        init_params = {"path": request.terminal_path}
        
        if request.login:
            init_params["login"] = request.login
        if request.password:
            init_params["password"] = request.password
        if request.server:
            init_params["server"] = request.server
        
        if not mt5.initialize(**init_params):
            error_code = mt5.last_error()
            logger.error(f"فشل تهيئة MT5: {error_code}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"فشل الاتصال بـ MT5. رمز الخطأ: {error_code}"
            )
        
        # تحديث حالة الاتصال
        terminal_info = mt5.terminal_info()
        account_info = mt5.account_info()
        
        connection_state = {
            "connected": True,
            "terminal_path": request.terminal_path,
            "login": account_info.login if account_info else None,
            "server": account_info.server if account_info else None,
            "mode": "live"
        }
        
        logger.info(f"تم الاتصال بـ MT5 بنجاح - الحساب: {connection_state['login']}")
        
        return {
            "success": True,
            "message": "تم الاتصال بـ MT5 بنجاح",
            "terminal_info": {
                "company": terminal_info.company if terminal_info else None,
                "name": terminal_info.name if terminal_info else None,
                "path": terminal_info.path if terminal_info else None,
                "build": terminal_info.build if terminal_info else None
            },
            "account_info": {
                "login": account_info.login if account_info else None,
                "server": account_info.server if account_info else None,
                "currency": account_info.currency if account_info else None
            }
        }
        
    except Exception as e:
        logger.error(f"خطأ في الاتصال: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"حدث خطأ أثناء الاتصال: {str(e)}"
        )


@app.post("/disconnect", tags=["الاتصال"])
async def disconnect_mt5():
    """
    ## قطع الاتصال بـ MetaTrader 5
    
    يقوم بإغلاق الاتصال مع منصة MT5 وتحرير الموارد.
    """
    global connection_state
    
    if not connection_state["connected"]:
        return {
            "success": True,
            "message": "لا يوجد اتصال نشط"
        }
    
    if MT5_AVAILABLE:
        mt5.shutdown()
    
    connection_state = {
        "connected": False,
        "terminal_path": None,
        "login": None,
        "server": None
    }
    
    logger.info("تم قطع الاتصال بـ MT5")
    
    return {
        "success": True,
        "message": "تم قطع الاتصال بنجاح"
    }


# =================================================================================
#                              اختبار الاستراتيجيات (Strategy Tester)
# =================================================================================

@app.post("/run_backtest", tags=["اختبار الاستراتيجيات"])
async def run_backtest(request: BacktestRequest):
    """
    ## تشغيل اختبار استراتيجية (Backtest)
    
    ### كيف يعمل:
    1. يتم إنشاء ملف تكوين .ini يحتوي على جميع إعدادات الاختبار
    2. يتم تشغيل MT5 من سطر الأوامر مع معامل /config
    3. MT5 يقرأ الإعدادات ويبدأ الاختبار تلقائياً
    4. بعد انتهاء الاختبار، يتم إغلاق MT5 (حسب الإعداد)
    
    ### أنواع النمذجة (Model):
    - **0 - كل تيك**: أعلى دقة، يستخدم كل حركة سعرية (بطيء)
    - **1 - نقاط التحكم**: دقة متوسطة، يستخدم بيانات 1 دقيقة
    - **2 - أسعار الافتتاح**: أسرع طريقة، يستخدم فقط سعر الافتتاح
    
    ### أنواع التحسين (Optimization):
    - **0**: معطل - اختبار عادي
    - **1**: بطيء - يختبر كل المجموعات
    - **2**: خوارزمية جينية - أسرع للمعاملات الكثيرة
    - **3**: كل المعاملات
    
    ### ملاحظة مهمة:
    تأكد من أن المستشار الخبير موجود في مجلد MQL5/Experts
    """
    
    # التحقق من وجود ملف MT5
    if not os.path.exists(request.terminal_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف terminal64.exe غير موجود: {request.terminal_path}"
        )
    
    try:
        # إنشاء مجلد للتكوينات إذا لم يكن موجوداً
        config_dir = os.path.join(os.path.dirname(__file__), "configs")
        os.makedirs(config_dir, exist_ok=True)
        
        # إنشاء اسم فريد لملف التكوين
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        config_filename = f"backtest_config_{timestamp}.ini"
        config_path = os.path.join(config_dir, config_filename)
        
        # إنشاء ملف التكوين
        full_config_path = generate_ini_config(request, config_path)
        
        logger.info(f"بدء اختبار الاستراتيجية: {request.expert_advisor}")
        logger.info(f"الرمز: {request.symbol}, الفترة: {request.period}")
        logger.info(f"من: {request.from_date} إلى: {request.to_date}")
        
        # تشغيل MT5 مع ملف التكوين
        # الأمر: terminal64.exe /config:path_to_config.ini
        command = [
            request.terminal_path,
            f"/config:{full_config_path}"
        ]
        
        logger.info(f"تنفيذ الأمر: {' '.join(command)}")
        
        # تشغيل العملية
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            creationflags=subprocess.CREATE_NEW_CONSOLE if sys.platform == 'win32' else 0
        )
        
        # انتظار انتهاء العملية (مع مهلة زمنية)
        # ملاحظة: في الإنتاج، قد تحتاج لتعديل هذا حسب طول الاختبار
        timeout_seconds = 3600  # ساعة واحدة كحد أقصى
        
        return {
            "success": True,
            "message": "تم بدء اختبار الاستراتيجية",
            "details": {
                "expert_advisor": request.expert_advisor,
                "symbol": request.symbol,
                "period": request.period,
                "from_date": request.from_date,
                "to_date": request.to_date,
                "model": request.model,
                "optimization": request.optimization,
                "deposit": request.deposit,
                "leverage": request.leverage
            },
            "config_file": full_config_path,
            "process_id": process.pid,
            "note": "الاختبار يعمل في الخلفية. راجع MT5 للنتائج."
        }
        
    except Exception as e:
        logger.error(f"خطأ في تشغيل الاختبار: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل تشغيل الاختبار: {str(e)}"
        )


@app.post("/run_backtest_sync", tags=["اختبار الاستراتيجيات"])
async def run_backtest_sync(request: BacktestRequest, timeout: int = 3600):
    """
    ## تشغيل اختبار استراتيجية (متزامن)
    
    نفس الوظيفة السابقة لكن ينتظر حتى انتهاء الاختبار.
    
    ### المعاملات الإضافية:
    - **timeout**: المهلة الزمنية بالثواني (افتراضي: 3600 = ساعة)
    
    ### تحذير:
    هذا الطلب قد يستغرق وقتاً طويلاً حسب إعدادات الاختبار.
    """
    
    if not os.path.exists(request.terminal_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف terminal64.exe غير موجود: {request.terminal_path}"
        )
    
    try:
        # إنشاء ملف التكوين
        config_dir = os.path.join(os.path.dirname(__file__), "configs")
        os.makedirs(config_dir, exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        config_path = os.path.join(config_dir, f"backtest_config_{timestamp}.ini")
        full_config_path = generate_ini_config(request, config_path)
        
        # تشغيل MT5
        command = [request.terminal_path, f"/config:{full_config_path}"]
        
        start_time = time.time()
        
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            creationflags=subprocess.CREATE_NEW_CONSOLE if sys.platform == 'win32' else 0
        )
        
        # انتظار انتهاء العملية
        try:
            stdout, stderr = process.communicate(timeout=timeout)
            end_time = time.time()
            
            return {
                "success": True,
                "message": "اكتمل اختبار الاستراتيجية",
                "duration_seconds": round(end_time - start_time, 2),
                "return_code": process.returncode,
                "config_file": full_config_path
            }
            
        except subprocess.TimeoutExpired:
            process.kill()
            raise HTTPException(
                status_code=status.HTTP_408_REQUEST_TIMEOUT,
                detail=f"انتهت المهلة الزمنية ({timeout} ثانية). تم إيقاف الاختبار."
            )
            
    except Exception as e:
        logger.error(f"خطأ في الاختبار المتزامن: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل الاختبار: {str(e)}"
        )


# =================================================================================
#                              المستشارين الخبراء (Expert Advisors)
# =================================================================================

@app.post("/list_experts", tags=["المستشارين الخبراء"])
async def list_experts(request: ExpertsListRequest):
    """
    ## قائمة المستشارين الخبراء
    
    يقوم بفحص مجلد MQL5/Experts وإرجاع قائمة بجميع المستشارين الخبراء.
    
    ### كيفية إيجاد مسار MQL5:
    1. افتح MT5
    2. اضغط على File > Open Data Folder
    3. ستجد مجلد MQL5 هناك
    
    ### المسار النموذجي:
    ```
    C:/Users/USERNAME/AppData/Roaming/MetaQuotes/Terminal/XXXX/MQL5
    ```
    
    ### أنواع الملفات:
    - **.ex5**: مستشار خبير مترجم (جاهز للاستخدام)
    - **.mq5**: كود مصدري (يحتاج ترجمة)
    """
    
    if not os.path.exists(request.mql5_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"مجلد MQL5 غير موجود: {request.mql5_path}"
        )
    
    experts = find_experts(request.mql5_path)
    
    # تصنيف المستشارين
    compiled = [e for e in experts if e["type"] == "compiled"]
    source = [e for e in experts if e["type"] == "source"]
    
    return {
        "success": True,
        "total_count": len(experts),
        "compiled_count": len(compiled),
        "source_count": len(source),
        "experts": {
            "compiled": compiled,
            "source": source
        },
        "mql5_path": request.mql5_path
    }


@app.get("/list_experts_default", tags=["المستشارين الخبراء"])
async def list_experts_default():
    """
    ## قائمة المستشارين الخبراء (المسار الافتراضي)
    
    يحاول إيجاد مجلد MQL5 تلقائياً في المسارات الشائعة.
    
    ### ملاحظة:
    قد لا يعمل إذا كان MT5 مثبتاً في مسار غير تقليدي.
    """
    
    # المسارات الشائعة لمجلد MQL5
    possible_paths = []
    
    if sys.platform == 'win32':
        # Windows
        appdata = os.environ.get('APPDATA', '')
        if appdata:
            metaquotes_path = os.path.join(appdata, 'MetaQuotes', 'Terminal')
            if os.path.exists(metaquotes_path):
                # البحث في جميع المجلدات الفرعية
                for folder in os.listdir(metaquotes_path):
                    mql5_path = os.path.join(metaquotes_path, folder, 'MQL5')
                    if os.path.exists(mql5_path):
                        possible_paths.append(mql5_path)
    
    if not possible_paths:
        return {
            "success": False,
            "message": "لم يتم العثور على مجلد MQL5 تلقائياً",
            "suggestion": "استخدم POST /list_experts مع تحديد المسار يدوياً"
        }
    
    # البحث في أول مسار موجود
    all_experts = []
    for path in possible_paths:
        experts = find_experts(path)
        for expert in experts:
            expert["mql5_path"] = path
        all_experts.extend(experts)
    
    return {
        "success": True,
        "total_count": len(all_experts),
        "found_paths": possible_paths,
        "experts": all_experts
    }


# =================================================================================
#                              معلومات الحساب
# =================================================================================

@app.get("/account_info", tags=["معلومات الحساب"])
async def get_account_info():
    """
    ## معلومات الحساب
    
    يرجع معلومات الحساب المتصل حالياً:
    - الرصيد (Balance)
    - الرصيد المتاح (Equity)
    - الهامش المستخدم (Margin)
    - الهامش الحر (Free Margin)
    - مستوى الهامش (Margin Level)
    - الربح/الخسارة (Profit)
    
    ### متطلبات:
    يجب أن يكون هناك اتصال نشط بـ MT5 (استخدم /connect أولاً)
    """
    
    if not connection_state["connected"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يوجد اتصال نشط بـ MT5. استخدم /connect أولاً."
        )
    
    if not MT5_AVAILABLE:
        # وضع المحاكاة
        return {
            "success": True,
            "mode": "simulation",
            "account": {
                "login": 12345678,
                "server": "Demo-Server",
                "currency": "USD",
                "balance": 10000.00,
                "equity": 10250.50,
                "margin": 500.00,
                "free_margin": 9750.50,
                "margin_level": 2050.10,
                "profit": 250.50,
                "leverage": 100
            },
            "warning": "هذه بيانات محاكاة - MT5 غير متوفر"
        }
    
    try:
        account = mt5.account_info()
        
        if account is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="فشل الحصول على معلومات الحساب"
            )
        
        return {
            "success": True,
            "mode": "live",
            "account": {
                "login": account.login,
                "server": account.server,
                "currency": account.currency,
                "balance": account.balance,
                "equity": account.equity,
                "margin": account.margin,
                "free_margin": account.margin_free,
                "margin_level": account.margin_level,
                "profit": account.profit,
                "leverage": account.leverage,
                "trade_mode": account.trade_mode,
                "limit_orders": account.limit_orders,
                "margin_so_mode": account.margin_so_mode,
                "trade_allowed": account.trade_allowed,
                "trade_expert": account.trade_expert
            }
        }
        
    except Exception as e:
        logger.error(f"خطأ في جلب معلومات الحساب: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"خطأ: {str(e)}"
        )


# =================================================================================
#                              بيانات السوق (اختياري)
# =================================================================================

@app.get("/symbols", tags=["بيانات السوق"])
async def get_symbols():
    """
    ## قائمة الرموز المتاحة
    
    يرجع قائمة بجميع رموز التداول المتاحة في المنصة.
    """
    
    if not connection_state["connected"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يوجد اتصال نشط بـ MT5"
        )
    
    if not MT5_AVAILABLE:
        # محاكاة
        return {
            "success": True,
            "mode": "simulation",
            "count": 5,
            "symbols": [
                {"name": "EURUSD", "description": "Euro vs US Dollar"},
                {"name": "GBPUSD", "description": "British Pound vs US Dollar"},
                {"name": "USDJPY", "description": "US Dollar vs Japanese Yen"},
                {"name": "XAUUSD", "description": "Gold vs US Dollar"},
                {"name": "BTCUSD", "description": "Bitcoin vs US Dollar"}
            ]
        }
    
    try:
        symbols = mt5.symbols_get()
        
        if symbols is None:
            return {"success": True, "count": 0, "symbols": []}
        
        symbols_list = [
            {
                "name": s.name,
                "description": s.description,
                "path": s.path,
                "visible": s.visible,
                "trade_mode": s.trade_mode
            }
            for s in symbols
        ]
        
        return {
            "success": True,
            "mode": "live",
            "count": len(symbols_list),
            "symbols": symbols_list
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"خطأ: {str(e)}"
        )


# =================================================================================
#                              نقطة التشغيل الرئيسية
# =================================================================================

if __name__ == "__main__":
    print("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║              خادم MetaTrader 5 الوسيط (Middleware)               ║
    ║                                                                  ║
    ║   الإصدار: 1.0.0                                                 ║
    ║   المنفذ: 8000                                                   ║
    ║   التوثيق: http://localhost:8000/docs                           ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
    """)
    
    # تشغيل الخادم
    uvicorn.run(
        "main:app",
        host="0.0.0.0",  # السماح بالاتصال من أي عنوان
        port=8000,
        reload=True,     # إعادة التحميل التلقائي عند تغيير الكود
        log_level="info"
    )
