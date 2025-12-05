# 🚀 دليل نظام التحكم النهائي الذكي في MetaTrader 5

## 📋 نظرة عامة

هذا النظام يجمع **أفضل 4 طرق** للتحكم الكامل في MT5:

| الطريقة | الوصف | الميزة |
|---------|-------|--------|
| **pywinauto** | تحكم ذكي في الواجهة | **لا يحتاج صور شاشة!** |
| **MT5 Python API** | تداول وبيانات | سريع ودقيق |
| **INI Files** | Backtest تلقائي | أسرع طريقة |
| **PyAutoGUI** | صور وماوس | احتياطي |

---

## 🔍 ما الجديد؟ pywinauto - التحكم الذكي!

### المشكلة السابقة:
كنا نستخدم **صور الشاشة** للتحكم في MT5، وهذا:
- بطيء ❌
- غير دقيق ❌
- يحتاج تحليل صور ❌

### الحل الجديد: pywinauto
مثل **Playwright للمتصفحات**، لكن للتطبيقات!

```
                      ┌─────────────────────────────────────┐
                      │                                     │
     AI Agent         │         pywinauto                   │         MT5
   (Manus/Claude)     │    (Windows UI Automation)          │     (MetaTrader)
                      │                                     │
         ┌────────────┴─────────────────────────────────────┴──────────┐
         │                                                              │
         │   HTTP Request                                              │
         │   ──────────►    API Server    ──────────►    UI Elements   │
         │                                                              │
         │   • /ui/controls = DOM elements                             │
         │   • /ui/click = Direct button click                         │
         │   • /ui/menu = Navigate menus                               │
         │   • /ui/type = Type in fields                               │
         │                                                              │
         └──────────────────────────────────────────────────────────────┘
```

### مقارنة الطرق:

| الميزة | PyAutoGUI (القديم) | pywinauto (الجديد) |
|--------|-------------------|-------------------|
| السرعة | بطيء | سريع جداً |
| الدقة | متوسطة (صور) | عالية جداً (مباشر) |
| يحتاج صور؟ | نعم | **لا!** |
| يقرأ العناصر؟ | لا | **نعم!** |
| مثل المتصفح؟ | لا | **نعم!** |

---

## 📦 التثبيت

### 1. المتطلبات الأساسية
```bash
pip install fastapi uvicorn pydantic httpx
```

### 2. المتطلبات للتحكم الذكي (مهم!)
```bash
pip install pywinauto comtypes
```

### 3. المتطلبات للتداول
```bash
pip install MetaTrader5
```

### 4. المتطلبات الاحتياطية (صور)
```bash
pip install pyautogui pygetwindow pillow
```

### أمر واحد للكل:
```bash
pip install fastapi uvicorn pydantic httpx pywinauto comtypes MetaTrader5 pyautogui pygetwindow pillow
```

---

## 🚀 تشغيل الخادم

### على Windows:
```bash
cd C:\MT5_Middleware
python mt5_ultimate_control.py
```

### الوصول:
- **التوثيق**: http://localhost:8000/docs
- **الصحة**: http://localhost:8000/health

### للوصول من الإنترنت (لـ AI):
```bash
ngrok http 8000
```

---

## 🔌 الاتصال بـ MT5

### الاتصال الكامل:
```python
import requests

# تغيير المسار حسب تثبيتك
response = requests.post("http://localhost:8000/connect", json={
    "terminal_path": "C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe",
    "login": 12345678,        # اختياري
    "password": "password",   # اختياري
    "server": "ICMarkets-Demo"  # اختياري
})

print(response.json())
```

### النتيجة:
```json
{
    "success": true,
    "connections": {
        "pywinauto": {
            "success": true,
            "message": "تم الاتصال بواجهة MT5"
        },
        "mt5_api": {
            "success": true,
            "message": "تم الاتصال بنجاح",
            "account": {
                "login": 12345678,
                "balance": 10000,
                "equity": 10000
            }
        }
    }
}
```

---

## 🖥️ التحكم الذكي في الواجهة (pywinauto)

### 1. رؤية جميع العناصر (مثل DOM!)
```python
# الحصول على جميع الأزرار والقوائم والحقول
response = requests.get("http://localhost:8000/ui/controls")
controls = response.json()["controls"]

# كل عنصر يحتوي على:
# - control_type: نوع (Button, Menu, Edit, ComboBox...)
# - name: الاسم
# - automation_id: المعرف
# - is_enabled: مفعّل؟
# - is_visible: مرئي؟
```

### 2. البحث عن عنصر
```python
# البحث عن زر "Start"
response = requests.get("http://localhost:8000/ui/search", params={
    "name": "Start",
    "control_type": "Button"
})
```

### 3. النقر على زر
```python
requests.post("http://localhost:8000/ui/click", params={"name": "Start"})
```

### 4. النقر على قائمة
```python
# فتح View -> Strategy Tester
requests.post("http://localhost:8000/ui/menu", params={
    "path": "View->Strategy Tester"
})
```

### 5. إرسال اختصار
```python
# Ctrl+R لفتح Strategy Tester
requests.post("http://localhost:8000/ui/hotkey", params={"keys": "^r"})

# F4 لفتح MetaEditor
requests.post("http://localhost:8000/ui/hotkey", params={"keys": "{F4}"})
```

---

## 📊 تشغيل Backtest

### الطريقة 1: INI File (الأسرع والأفضل!)
```python
response = requests.post("http://localhost:8000/backtest/ini", json={
    "expert_name": "ExpertMACD",
    "symbol": "EURUSD",
    "timeframe": "H1",
    "from_date": "2024.01.01",
    "to_date": "2024.12.31",
    "visual": True,
    "deposit": 10000,
    "leverage": 100
})
```

**كيف يعمل:**
1. ينشئ ملف INI بالإعدادات
2. يشغل MT5 مع `/config:file.ini`
3. MT5 يبدأ الاختبار **تلقائياً**!

### الطريقة 2: التحكم الذكي (لرؤية ما يحدث)
```python
response = requests.post("http://localhost:8000/backtest", json={
    "expert_name": "ExpertMACD",
    "symbol": "EURUSD",
    "timeframe": "H1",
    "visual": True,
    "use_method": "pywinauto"
})
```

---

## 💰 التداول

### فتح صفقة شراء
```python
response = requests.post("http://localhost:8000/trade", json={
    "symbol": "EURUSD",
    "order_type": "buy",
    "volume": 0.01,
    "sl": 1.0800,  # وقف الخسارة
    "tp": 1.0900,  # جني الأرباح
    "comment": "AI Trade"
})
```

### فتح صفقة بيع
```python
response = requests.post("http://localhost:8000/trade", json={
    "symbol": "EURUSD",
    "order_type": "sell",
    "volume": 0.01
})
```

### الصفقات المفتوحة
```python
response = requests.get("http://localhost:8000/positions")
positions = response.json()["positions"]
```

### إغلاق صفقة
```python
requests.post("http://localhost:8000/positions/123456/close")
```

### الأسعار الحالية
```python
response = requests.get("http://localhost:8000/prices/EURUSD")
print(f"Bid: {response.json()['bid']}, Ask: {response.json()['ask']}")
```

---

## 🤖 إنشاء Expert Advisor

### EA بسيط (MA Crossover)
```python
response = requests.post("http://localhost:8000/experts/create", json={
    "name": "AI_MA_Strategy",
    "strategy_type": "trend_following",
    "entry_logic": "MA crossover",
    "exit_logic": "MA crossover reverse",
    "risk_percent": 2.0
})
```

### EA بكود مخصص
```python
custom_code = '''
//+------------------------------------------------------------------+
//| Custom EA code here                                               |
//+------------------------------------------------------------------+
int OnInit() {
    Print("Custom EA Started!");
    return(INIT_SUCCEEDED);
}

void OnTick() {
    // Your trading logic
}
'''

response = requests.post("http://localhost:8000/experts/create", json={
    "name": "My_Custom_EA",
    "custom_code": custom_code
})
```

---

## 🔄 سيناريو كامل مع AI (مثل Manus)

```python
import requests

BASE_URL = "https://abc123.ngrok.io"  # رابط ngrok

# 1. الاتصال
print("🔌 الاتصال بـ MT5...")
requests.post(f"{BASE_URL}/connect", json={
    "terminal_path": "C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe"
})

# 2. فحص الحساب
print("💰 فحص الحساب...")
account = requests.get(f"{BASE_URL}/account").json()
print(f"   الرصيد: ${account['account']['balance']}")

# 3. إنشاء EA
print("🤖 إنشاء استراتيجية...")
requests.post(f"{BASE_URL}/experts/create", json={
    "name": "AI_Smart_Strategy",
    "strategy_type": "trend_following",
    "risk_percent": 1.5
})

# 4. تشغيل Backtest
print("📊 تشغيل الاختبار...")
result = requests.post(f"{BASE_URL}/backtest/ini", json={
    "expert_name": "AI_Smart_Strategy",
    "symbol": "EURUSD",
    "timeframe": "H1",
    "from_date": "2024.01.01",
    "to_date": "2024.06.30",
    "visual": True
}).json()

print(f"   ✅ تم بدء الاختبار!")
print(f"   📁 ملف التكوين: {result['config_path']}")

# 5. التقاط صورة للتحقق
print("📸 التقاط صورة...")
screenshot = requests.get(f"{BASE_URL}/screenshot", params={"mt5_only": True})

# 6. رؤية العناصر
print("🔍 فحص عناصر الواجهة...")
controls = requests.get(f"{BASE_URL}/ui/controls").json()
print(f"   عدد العناصر: {controls['count']}")

print("\n✅ اكتمل السيناريو!")
```

---

## ⚠️ ملاحظات مهمة

### 1. يعمل على Windows فقط
- MT5 يعمل على Windows فقط
- يجب تشغيل الخادم على نفس الجهاز

### 2. أغلق MT5 قبل الاتصال
- إذا كان MT5 مفتوحاً، سيتصل به
- إذا لم يكن مفتوحاً، سيفتحه

### 3. المسارات
- استخدم `/` بدلاً من `\` في المسارات
- مثال صحيح: `C:/Program Files/MetaTrader 5/terminal64.exe`

### 4. الأمان
- ngrok يعرض الخادم للإنترنت
- استخدم فقط مع AI موثوق
- أغلق ngrok بعد الانتهاء

---

## 🆚 مقارنة مع الحلول الأخرى

### مقارنة مع التحكم بالمتصفح:
| الميزة | Playwright (متصفح) | pywinauto (MT5) |
|--------|-------------------|-----------------|
| يقرأ DOM | ✅ | ✅ (UI elements) |
| يتحكم بالعناصر | ✅ | ✅ |
| بدون صور | ✅ | ✅ |
| API مفتوح | ✅ DevTools | ⚠️ محدود |
| Strategy Tester | - | ❌ (نستخدم INI) |

### الخلاصة:
**pywinauto** يوفر تحكم **ذكي ومباشر** في MT5، لكن:
- Strategy Tester **لا يمكن** التحكم به بالكامل
- الحل: **INI files** لتشغيل الاختبارات تلقائياً

---

## 📞 الدعم

### المشاكل الشائعة:

**pywinauto لا يجد MT5:**
- تأكد من تثبيت `pip install pywinauto comtypes`
- تأكد من أن MT5 مفتوح

**لا يمكن الاتصال:**
- تأكد من مسار `terminal64.exe`
- أغلق MT5 وأعد المحاولة

**الاختبار لا يبدأ:**
- تأكد من وجود الـ EA في مجلد `MQL5/Experts`
- تأكد من ترجمة الـ EA (ملف `.ex5`)

---

## 🎯 الخلاصة

هذا النظام يمنح الذكاء الاصطناعي **تحكم شبه كامل** في MT5:

| القدرة | الحالة |
|--------|--------|
| اتصال | ✅ كامل |
| تداول | ✅ كامل |
| معلومات الحساب | ✅ كامل |
| الأسعار | ✅ كامل |
| إنشاء EA | ✅ كامل |
| قراءة الواجهة | ✅ كامل (pywinauto) |
| التحكم بالقوائم | ✅ كامل |
| Strategy Tester | ✅ عبر INI |
| الاختبار المرئي | ✅ عبر INI |

**المتبقي فقط:** بعض عناصر Strategy Tester التي تحتاج تدخل يدوي.

---

💡 **نصيحة:** استخدم طريقة **INI** للاختبارات، وطريقة **pywinauto** لقراءة الواجهة!
