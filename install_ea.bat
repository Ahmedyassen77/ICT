@echo off
echo ========================================
echo   Installing SMC AutoTrader EA
echo ========================================
echo.

cd /d C:\Users\a\ICT

echo [1/3] Pulling latest code from GitHub...
git pull
if %errorlevel% neq 0 (
    echo ERROR: Git pull failed!
    pause
    exit /b 1
)

echo.
echo [2/3] Checking if EA file exists...
if not exist "smc_python\SMC_AutoTrader_EA.mq5" (
    echo ERROR: SMC_AutoTrader_EA.mq5 not found!
    echo Please check if git pull was successful.
    pause
    exit /b 1
)

echo.
echo [3/3] Copying EA to MT5 Experts folder...
copy /Y "smc_python\SMC_AutoTrader_EA.mq5" "C:\Users\a\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E\MQL5\Experts\"
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy EA!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   SUCCESS! EA installed successfully
echo ========================================
echo.
echo Next steps:
echo 1. Open MetaEditor (F4 in MT5)
echo 2. Compile SMC_AutoTrader_EA.mq5
echo 3. Add 'Smart Money Concepts' indicator to chart
echo 4. Drag SMC_AutoTrader EA to the chart
echo.
pause
