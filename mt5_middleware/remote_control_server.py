"""
=================================================================================
          🌍 MT5 Remote Control Server
          خادم التحكم عن بعد في MT5
=================================================================================

هذا الخادم يسمح لـ Claude بالتحكم في MT5 من أي مكان في العالم!

الطريقة:
1. شغّل هذا الخادم على جهازك Windows
2. استخدم ngrok للحصول على رابط عام
3. أعطِ الرابط لـ Claude
4. Claude يرسل أوامر HTTP
5. الخادم ينفذها على MT5!

= تحكم من أي مكان بدون Dropbox! 🎉

=================================================================================
"""

import os
import sys
import json
import time
import subprocess
import threading
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, asdict
import hashlib
import secrets

# FastAPI
from fastapi import FastAPI, HTTPException, Depends, Header, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import APIKeyHeader
from pydantic import BaseModel, Field
import uvicorn

# استيراد نظام الأتمتة
try:
    from mt5_complete_automation import MT5CompleteAutomation, BacktestResult
    AUTOMATION_AVAILABLE = True
except ImportError:
    AUTOMATION_AVAILABLE = False
    print("⚠️ mt5_complete_automation.py غير موجود")


# =================================================================================
#                          الإعدادات
# =================================================================================

# مفتاح API للأمان (غيّره!)
API_KEY = os.environ.get("MT5_API_KEY", "your-secret-key-change-me")

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
#                          نماذج البيانات
# =================================================================================

class CreateEARequest(BaseModel):
    """طلب إنشاء EA"""
    name: str = Field(..., description="اسم الـ EA")
    strategy: str = Field(default="ma_crossover", description="الاستراتيجية")
    params: Dict = Field(default={}, description="معاملات إضافية")


class BacktestRequest(BaseModel):
    """طلب Backtest"""
    expert_name: str = Field(..., description="اسم الـ EA")
    symbol: str = Field(default="EURUSD", description="الزوج")
    timeframe: str = Field(default="H1", description="الإطار الزمني")
    from_date: str = Field(default="2024.01.01", description="من تاريخ")
    to_date: str = Field(default="2024.12.31", description="إلى تاريخ")
    visual: bool = Field(default=True, description="وضع مرئي")


class FullAutomationRequest(BaseModel):
    """طلب أتمتة كاملة"""
    name: str = Field(..., description="اسم الـ EA")
    strategy: str = Field(default="ma_crossover", description="الاستراتيجية")
    symbol: str = Field(default="EURUSD", description="الزوج")
    timeframe: str = Field(default="H1", description="الإطار الزمني")
    from_date: str = Field(default="2024.01.01", description="من تاريخ")
    to_date: str = Field(default="2024.12.31", description="إلى تاريخ")
    params: Dict = Field(default={}, description="معاملات الاستراتيجية")
    visual: bool = Field(default=True, description="وضع مرئي")


class CommandResponse(BaseModel):
    """استجابة الأمر"""
    success: bool
    message: str
    data: Optional[Dict] = None
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


# =================================================================================
#                          التطبيق
# =================================================================================

app = FastAPI(
    title="🌍 MT5 Remote Control",
    description="""
    # خادم التحكم عن بعد في MetaTrader 5
    
    هذا الخادم يسمح لـ Claude (أو أي AI) بالتحكم الكامل في MT5 من أي مكان!
    
    ## 🔐 الأمان
    كل الطلبات تحتاج API Key في الـ Header:
    ```
    X-API-Key: your-secret-key
    ```
    
    ## 🚀 الاستخدام
    1. شغّل الخادم على Windows
    2. استخدم ngrok: `ngrok http 8000`
    3. أعطِ الرابط لـ Claude
    4. Claude يتحكم في MT5!
    
    ## 📋 الأوامر
    - `POST /create-ea` - إنشاء Expert Advisor
    - `POST /compile-ea` - ترجمة EA
    - `POST /backtest` - تشغيل Backtest
    - `POST /full-automation` - كل شيء تلقائي! ⭐
    """,
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# نظام الأتمتة
automation: Optional[MT5CompleteAutomation] = None


# =================================================================================
#                          الأمان
# =================================================================================

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

async def verify_api_key(api_key: str = Depends(api_key_header)):
    """التحقق من مفتاح API"""
    if not api_key or api_key != API_KEY:
        raise HTTPException(
            status_code=401,
            detail="مفتاح API غير صحيح. أضف X-API-Key في الـ Header"
        )
    return api_key


# =================================================================================
#                          نقاط النهاية
# =================================================================================

@app.get("/", tags=["🏠 الرئيسية"])
async def root():
    """الصفحة الرئيسية"""
    return {
        "title": "🌍 MT5 Remote Control Server",
        "description": "تحكم في MT5 من أي مكان في العالم!",
        "version": "1.0.0",
        "automation_available": AUTOMATION_AVAILABLE,
        "endpoints": {
            "health": "GET /health",
            "create_ea": "POST /create-ea",
            "compile_ea": "POST /compile-ea/{name}",
            "backtest": "POST /backtest",
            "full_automation": "POST /full-automation ⭐",
            "strategies": "GET /strategies"
        },
        "security": "أضف X-API-Key في الـ Header",
        "docs": "/docs"
    }


@app.get("/health", tags=["🏠 الرئيسية"])
async def health():
    """فحص الحالة"""
    global automation
    
    if automation is None and AUTOMATION_AVAILABLE:
        automation = MT5CompleteAutomation()
    
    return {
        "status": "healthy",
        "automation_available": AUTOMATION_AVAILABLE,
        "mt5_terminal": automation.terminal_path if automation else None,
        "metaeditor": automation.metaeditor_path if automation else None,
        "timestamp": datetime.now().isoformat()
    }


@app.get("/strategies", tags=["📚 المعلومات"])
async def list_strategies():
    """قائمة الاستراتيجيات المتاحة"""
    return {
        "strategies": {
            "ma_crossover": {
                "name": "MA Crossover",
                "description": "تقاطع المتوسطات المتحركة",
                "params": ["MA_Fast_Period", "MA_Slow_Period"]
            },
            "rsi": {
                "name": "RSI",
                "description": "مؤشر القوة النسبية",
                "params": ["RSI_Period", "RSI_Overbought", "RSI_Oversold"]
            },
            "macd": {
                "name": "MACD",
                "description": "مؤشر MACD",
                "params": ["MACD_Fast", "MACD_Slow", "MACD_Signal"]
            },
            "rsi_ma": {
                "name": "RSI + MA",
                "description": "دمج RSI مع المتوسط المتحرك",
                "params": ["RSI_Period", "MA_Period", "RSI_Overbought", "RSI_Oversold"]
            }
        },
        "common_params": {
            "Risk_Percent": "نسبة المخاطرة لكل صفقة",
            "Stop_Loss_Pips": "وقف الخسارة بالنقاط",
            "Take_Profit_Pips": "جني الأرباح بالنقاط"
        }
    }


@app.post("/create-ea", tags=["🤖 Expert Advisor"], response_model=CommandResponse)
async def create_ea(request: CreateEARequest, api_key: str = Depends(verify_api_key)):
    """
    إنشاء Expert Advisor جديد
    
    الاستراتيجيات المتاحة:
    - ma_crossover: تقاطع المتوسطات
    - rsi: مؤشر RSI
    - macd: مؤشر MACD
    - rsi_ma: RSI + MA
    """
    global automation
    
    if automation is None:
        if not AUTOMATION_AVAILABLE:
            raise HTTPException(status_code=500, detail="نظام الأتمتة غير متوفر")
        automation = MT5CompleteAutomation()
    
    success, path = automation.create_expert(
        request.name,
        request.strategy,
        request.params
    )
    
    return CommandResponse(
        success=success,
        message=f"تم إنشاء {request.name}.mq5" if success else "فشل الإنشاء",
        data={"path": path, "strategy": request.strategy}
    )


@app.post("/compile-ea/{name}", tags=["🤖 Expert Advisor"], response_model=CommandResponse)
async def compile_ea(name: str, api_key: str = Depends(verify_api_key)):
    """ترجمة Expert Advisor"""
    global automation
    
    if automation is None:
        if not AUTOMATION_AVAILABLE:
            raise HTTPException(status_code=500, detail="نظام الأتمتة غير متوفر")
        automation = MT5CompleteAutomation()
    
    # البحث عن الملف
    if automation.data_path:
        ea_path = os.path.join(automation.data_path, 'MQL5', 'Experts', f"{name}.mq5")
    else:
        raise HTTPException(status_code=404, detail="مسار البيانات غير محدد")
    
    if not os.path.exists(ea_path):
        raise HTTPException(status_code=404, detail=f"الملف غير موجود: {ea_path}")
    
    success, ex5_path = automation.compile_expert(ea_path)
    
    return CommandResponse(
        success=success,
        message="تم الترجمة بنجاح!" if success else "فشل الترجمة - يرجى الترجمة يدوياً",
        data={"ex5_path": ex5_path} if success else {"mq5_path": ea_path}
    )


@app.post("/backtest", tags=["📊 Backtest"], response_model=CommandResponse)
async def run_backtest(request: BacktestRequest, api_key: str = Depends(verify_api_key)):
    """
    تشغيل Backtest
    
    - visual=true: تشاهد الاختبار على الشاشة
    - visual=false: أسرع لكن بدون عرض
    """
    global automation
    
    if automation is None:
        if not AUTOMATION_AVAILABLE:
            raise HTTPException(status_code=500, detail="نظام الأتمتة غير متوفر")
        automation = MT5CompleteAutomation()
    
    result = automation.run_backtest(
        expert_name=request.expert_name,
        symbol=request.symbol,
        timeframe=request.timeframe,
        from_date=request.from_date,
        to_date=request.to_date,
        visual=request.visual
    )
    
    return CommandResponse(
        success=result.success,
        message="تم بدء الاختبار! شاهده على الشاشة 👀" if result.success else result.error,
        data={
            "expert": request.expert_name,
            "symbol": request.symbol,
            "timeframe": request.timeframe,
            "visual": request.visual,
            "report_path": result.report_path
        }
    )


@app.post("/full-automation", tags=["🚀 الأتمتة الكاملة"], response_model=CommandResponse)
async def full_automation(request: FullAutomationRequest, api_key: str = Depends(verify_api_key)):
    """
    ⭐ الأتمتة الكاملة!
    
    يعمل كل شيء تلقائياً:
    1. إنشاء EA بالاستراتيجية المحددة
    2. ترجمة EA
    3. تشغيل Backtest مرئي
    
    أنت تشاهد النتيجة على الشاشة!
    """
    global automation
    
    if automation is None:
        if not AUTOMATION_AVAILABLE:
            raise HTTPException(status_code=500, detail="نظام الأتمتة غير متوفر")
        automation = MT5CompleteAutomation()
    
    result = automation.full_automation(
        name=request.name,
        strategy=request.strategy,
        symbol=request.symbol,
        timeframe=request.timeframe,
        from_date=request.from_date,
        to_date=request.to_date,
        params=request.params,
        visual=request.visual
    )
    
    return CommandResponse(
        success=result.get("success", False),
        message=result.get("message", ""),
        data=result
    )


@app.get("/results/{expert_name}", tags=["📊 Backtest"])
async def get_results(expert_name: str, api_key: str = Depends(verify_api_key)):
    """قراءة نتائج Backtest"""
    global automation
    
    if automation is None:
        if not AUTOMATION_AVAILABLE:
            raise HTTPException(status_code=500, detail="نظام الأتمتة غير متوفر")
        automation = MT5CompleteAutomation()
    
    result = automation.read_backtest_results(expert_name)
    
    return {
        "success": result.success,
        "expert": expert_name,
        "results": {
            "total_profit": result.total_profit,
            "total_trades": result.total_trades,
            "win_rate": result.win_rate,
            "max_drawdown": result.max_drawdown,
            "profit_factor": result.profit_factor,
            "sharpe_ratio": result.sharpe_ratio
        },
        "report_path": result.report_path,
        "error": result.error
    }


# =================================================================================
#                          نقاط للتكامل مع Claude
# =================================================================================

@app.post("/claude/command", tags=["🤖 Claude Integration"])
async def claude_command(
    command: str,
    params: Dict = {},
    api_key: str = Depends(verify_api_key)
):
    """
    نقطة نهاية خاصة لـ Claude
    
    الأوامر المتاحة:
    - create_ea: إنشاء EA
    - compile: ترجمة EA
    - backtest: تشغيل اختبار
    - full: أتمتة كاملة
    - status: حالة النظام
    - results: قراءة النتائج
    """
    global automation
    
    if automation is None and AUTOMATION_AVAILABLE:
        automation = MT5CompleteAutomation()
    
    if command == "status":
        return {
            "success": True,
            "status": "online",
            "mt5_path": automation.terminal_path if automation else None,
            "ready": automation is not None
        }
    
    elif command == "create_ea":
        name = params.get("name", "AI_EA")
        strategy = params.get("strategy", "ma_crossover")
        success, path = automation.create_expert(name, strategy, params)
        return {"success": success, "path": path}
    
    elif command == "compile":
        name = params.get("name")
        if not name:
            return {"success": False, "error": "اسم الـ EA مطلوب"}
        ea_path = os.path.join(automation.data_path, 'MQL5', 'Experts', f"{name}.mq5")
        success, ex5_path = automation.compile_expert(ea_path)
        return {"success": success, "path": ex5_path}
    
    elif command == "backtest":
        result = automation.run_backtest(
            expert_name=params.get("expert", params.get("name", "")),
            symbol=params.get("symbol", "EURUSD"),
            timeframe=params.get("timeframe", "H1"),
            from_date=params.get("from_date", "2024.01.01"),
            to_date=params.get("to_date", "2024.12.31"),
            visual=params.get("visual", True)
        )
        return {"success": result.success, "message": result.error or "تم بدء الاختبار"}
    
    elif command == "full":
        result = automation.full_automation(
            name=params.get("name", "AI_Strategy"),
            strategy=params.get("strategy", "ma_crossover"),
            symbol=params.get("symbol", "EURUSD"),
            timeframe=params.get("timeframe", "H1"),
            from_date=params.get("from_date", "2024.01.01"),
            to_date=params.get("to_date", "2024.12.31"),
            params=params.get("ea_params", {}),
            visual=params.get("visual", True)
        )
        return result
    
    elif command == "results":
        name = params.get("name")
        if not name:
            return {"success": False, "error": "اسم الـ EA مطلوب"}
        result = automation.read_backtest_results(name)
        return {
            "success": result.success,
            "profit": result.total_profit,
            "trades": result.total_trades,
            "drawdown": result.max_drawdown
        }
    
    else:
        return {"success": False, "error": f"أمر غير معروف: {command}"}


# =================================================================================
#                          التشغيل
# =================================================================================

def generate_api_key():
    """توليد مفتاح API عشوائي"""
    return secrets.token_urlsafe(32)


if __name__ == "__main__":
    # توليد مفتاح جديد إذا لم يكن موجوداً
    if API_KEY == "your-secret-key-change-me":
        new_key = generate_api_key()
        print(f"""
{Colors.BOLD}{Colors.YELLOW}
⚠️ مفتاح API الافتراضي!
─────────────────────────────────────────────────────────
يُنصح بتعيين مفتاح خاص:

Windows CMD:
  set MT5_API_KEY={new_key}

Windows PowerShell:
  $env:MT5_API_KEY="{new_key}"

Linux/Mac:
  export MT5_API_KEY="{new_key}"

أو غيّر المتغير API_KEY في الكود.
─────────────────────────────────────────────────────────
{Colors.END}
""")
    
    print(f"""
{Colors.BOLD}{Colors.CYAN}
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║               🌍 MT5 Remote Control Server                               ║
║               خادم التحكم عن بعد في MetaTrader 5                         ║
║                                                                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║   🚀 الخادم يعمل على: http://localhost:8000                             ║
║   📚 التوثيق: http://localhost:8000/docs                                 ║
║                                                                          ║
║   🔐 مفتاح API: {API_KEY[:20]}...                                        ║
║                                                                          ║
║   ═══════════════════════════════════════════════════════════════════   ║
║                                                                          ║
║   📱 للتحكم من الموبايل أو أي مكان:                                      ║
║   ──────────────────────────────────                                     ║
║   1. ثبّت ngrok: https://ngrok.com/download                             ║
║   2. شغّل: ngrok http 8000                                               ║
║   3. انسخ الرابط العام (مثل: https://abc123.ngrok.io)                   ║
║   4. أعطِ الرابط ومفتاح API لـ Claude                                   ║
║   5. Claude يتحكم في MT5 من أي مكان! 🎉                                 ║
║                                                                          ║
║   ═══════════════════════════════════════════════════════════════════   ║
║                                                                          ║
║   💬 مثال استخدام مع Claude:                                             ║
║   ─────────────────────────                                              ║
║   "يا Claude، الرابط هو https://abc123.ngrok.io                         ║
║    والمفتاح هو xxx...                                                   ║
║    اعمل EA باستراتيجية RSI واختبره على EURUSD"                          ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
{Colors.END}
""")
    
    uvicorn.run(
        "remote_control_server:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
