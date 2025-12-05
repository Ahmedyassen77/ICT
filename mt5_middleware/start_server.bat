@echo off
chcp 65001 >nul
title MT5 Middleware Server

echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                                                                  ║
echo ║              خادم MetaTrader 5 الوسيط                            ║
echo ║              MT5 Middleware Server                               ║
echo ║                                                                  ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.

:: التحقق من وجود Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python غير مثبت! قم بتثبيته أولاً
    echo Download from: https://www.python.org/downloads/
    pause
    exit /b 1
)

echo [OK] Python متوفر
echo.

:: التحقق من المكتبات
echo جاري التحقق من المكتبات...
pip show fastapi >nul 2>&1
if errorlevel 1 (
    echo [INFO] جاري تثبيت المكتبات المطلوبة...
    pip install fastapi uvicorn pydantic httpx MetaTrader5
)

echo [OK] المكتبات متوفرة
echo.

:: تشغيل الخادم
echo ════════════════════════════════════════════════════════════════════
echo   جاري تشغيل الخادم على http://localhost:8000
echo   التوثيق: http://localhost:8000/docs
echo   اضغط Ctrl+C لإيقاف الخادم
echo ════════════════════════════════════════════════════════════════════
echo.

python main.py

pause
