@echo off
chcp 65001 >nul
title تثبيت متطلبات خادم MT5

echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                                                                  ║
echo ║              تثبيت متطلبات خادم MT5                              ║
echo ║                                                                  ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.

:: التحقق من Python
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Python غير مثبت!
    echo.
    echo الرجاء تحميل وتثبيت Python من:
    echo https://www.python.org/downloads/
    echo.
    echo مهم: أثناء التثبيت، تأكد من اختيار:
    echo [x] Add Python to PATH
    echo.
    pause
    exit /b 1
)

echo [OK] Python متوفر
python --version
echo.

:: تحديث pip
echo [1/2] جاري تحديث pip...
python -m pip install --upgrade pip
echo.

:: تثبيت المكتبات
echo [2/2] جاري تثبيت المكتبات...
echo.

pip install fastapi
pip install "uvicorn[standard]"
pip install pydantic
pip install httpx
pip install MetaTrader5

echo.
echo ════════════════════════════════════════════════════════════════════
echo   تم تثبيت جميع المتطلبات بنجاح!
echo   
echo   لتشغيل الخادم، نفذ:
echo   python main.py
echo   
echo   أو انقر مرتين على: start_server.bat
echo ════════════════════════════════════════════════════════════════════
echo.

pause
