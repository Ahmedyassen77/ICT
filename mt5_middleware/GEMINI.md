# 🤖 Gemini CLI - MT5 Control Guide

## أنت Gemini CLI وعندك تحكم كامل في MT5!

---

## 📂 الملفات المهمة:

```
mt5_middleware/
├── gemini_cli_integration.py   # للأوامر المباشرة
├── mt5_complete_automation.py  # للأتمتة الكاملة
├── mt5_visual_backtest_server.py # للسيرفر (اختياري)
└── GEMINI.md                   # هذا الملف!
```

---

## 🚀 الأوامر السريعة:

### 1️⃣ عرض الحالة:
```bash
python gemini_cli_integration.py status
```

### 2️⃣ إنشاء Expert Advisor:
```bash
python gemini_cli_integration.py create --name "MyStrategy"
```

### 3️⃣ تشغيل Backtest مرئي:
```bash
python gemini_cli_integration.py backtest --name "MyStrategy" --symbol EURUSD --visual
```

### 4️⃣ الوضع التفاعلي:
```bash
python gemini_cli_integration.py
```

---

## 🎯 أوامر Python مباشرة (للتحكم الكامل):

```python
# استيراد وتهيئة
import sys
sys.path.append('C:/Users/a/ICT/mt5_middleware')
from mt5_complete_automation import MT5Automation

# إنشاء المتحكم
mt5 = MT5Automation()

# === إنشاء EA ===
mt5.create_expert_advisor(
    name="RSI_Strategy",
    strategy_type="rsi",
    params={
        "RSI_Period": 14,
        "RSI_Overbought": 70,
        "RSI_Oversold": 30,
        "Risk_Percent": 2.0
    }
)

# === ترجمة EA ===
mt5.compile_expert("RSI_Strategy")

# === تشغيل Backtest مرئي ===
mt5.run_visual_backtest(
    expert_name="RSI_Strategy",
    symbol="EURUSD",
    timeframe="H1",
    from_date="2024.01.01",
    to_date="2024.06.30",
    visual=True,
    deposit=10000
)

# === قراءة النتائج ===
results = mt5.get_backtest_results("RSI_Strategy")
print(f"الربح: {results['profit']}")
print(f"الصفقات: {results['trades']}")
print(f"Drawdown: {results['drawdown']}")
```

---

## 📊 الاستراتيجيات المتاحة:

| الاستراتيجية | الوصف | المعاملات |
|-------------|-------|-----------|
| `ma_crossover` | تقاطع المتوسطات | MA_Fast_Period, MA_Slow_Period |
| `rsi` | مؤشر RSI | RSI_Period, RSI_Overbought, RSI_Oversold |
| `macd` | مؤشر MACD | MACD_Fast, MACD_Slow, MACD_Signal |
| `rsi_ma` | RSI + MA | RSI_Period, MA_Period |

---

## 🔧 أوامر النظام:

```python
import subprocess
import os

# فتح MT5
subprocess.Popen(r'"C:\Program Files\MetaTrader 5 IC Markets Global\terminal64.exe"')

# إغلاق MT5
os.system('taskkill /F /IM terminal64.exe')

# فتح MetaEditor
subprocess.Popen(r'"C:\Program Files\MetaTrader 5 IC Markets Global\metaeditor64.exe"')

# تشغيل Backtest مباشرة
ini_path = r"C:\Users\a\AppData\Roaming\MetaQuotes\Terminal\...\tester\config.ini"
subprocess.Popen(f'"{mt5_path}" /config:"{ini_path}"')
```

---

## 📸 أخذ Screenshot:

```python
import pyautogui

# كامل الشاشة
screenshot = pyautogui.screenshot()
screenshot.save("screen.png")

# نافذة MT5 فقط (مع pygetwindow)
import pygetwindow as gw
mt5_window = gw.getWindowsWithTitle('MetaTrader')[0]
mt5_window.activate()
region = (mt5_window.left, mt5_window.top, mt5_window.width, mt5_window.height)
screenshot = pyautogui.screenshot(region=region)
screenshot.save("mt5_screen.png")
```

---

## 📁 المسارات المهمة:

```python
# MT5 Terminal
MT5_PATH = r"C:\Program Files\MetaTrader 5 IC Markets Global\terminal64.exe"

# MetaEditor
METAEDITOR_PATH = r"C:\Program Files\MetaTrader 5 IC Markets Global\metaeditor64.exe"

# بيانات MT5
DATA_PATH = r"C:\Users\a\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E"

# مجلد Experts
EXPERTS_PATH = DATA_PATH + r"\MQL5\Experts"

# مجلد Tester
TESTER_PATH = DATA_PATH + r"\tester"
```

---

## 🎮 أمثلة كاملة:

### مثال 1: إنشاء EA واختباره:
```bash
cd C:\Users\a\ICT\mt5_middleware
python -c "
from mt5_complete_automation import MT5Automation
mt5 = MT5Automation()
mt5.create_expert_advisor('Test_EA', 'rsi')
mt5.compile_expert('Test_EA')
mt5.run_visual_backtest('Test_EA', 'EURUSD', 'H1', '2024.01.01', '2024.06.30', True)
"
```

### مثال 2: قائمة EAs:
```bash
python -c "
from gemini_cli_integration import MT5Controller
c = MT5Controller()
for ea in c.list_experts():
    print(ea['name'])
"
```

### مثال 3: أتمتة كاملة:
```bash
python -c "
from mt5_complete_automation import MT5Automation
mt5 = MT5Automation()
result = mt5.full_automation(
    ea_name='Auto_RSI',
    strategy='rsi',
    symbol='GBPUSD',
    timeframe='H4',
    visual=True
)
print(result)
"
```

---

## ⚡ نصائح مهمة:

1. **تأكد MT5 مغلق** قبل تشغيل Backtest جديد
2. **استخدم INI files** للـ Backtest (أسرع وأدق)
3. **pywinauto** للتحكم في UI
4. **Screenshots** للتحقق من النتائج

---

## 🔗 التكامل مع Claude (عبر الإنترنت):

إذا أردت التحكم عن بعد أيضاً:
```bash
# شغل السيرفر
python mt5_visual_backtest_server.py

# شغل ngrok
ngrok http 8000

# الآن Claude يقدر يتحكم عبر الإنترنت!
```

---

## ✅ أنت جاهز!

كـ Gemini CLI، يمكنك:
- ✅ إنشاء Expert Advisors
- ✅ ترجمة EAs
- ✅ تشغيل Backtests مرئية
- ✅ قراءة النتائج
- ✅ فتح/إغلاق MT5
- ✅ أخذ Screenshots
- ✅ تنفيذ أي أمر CMD

**فقط نفذ الأوامر أعلاه! 🚀**
