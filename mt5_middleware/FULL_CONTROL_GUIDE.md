# 🎮 دليل نظام التحكم الكامل في MT5

<div dir="rtl">

## 🆕 ما الجديد؟

### النظام القديم (main.py):
```
❌ تحكم محدود عبر Python API
❌ Backtest غير مرئي
❌ لا يستطيع اختيار الإعدادات
❌ لا يرى الشاشة
```

### النظام الجديد (mt5_full_control.py):
```
✅ تحكم كامل مثل الإنسان
✅ Backtest مرئي
✅ يختار الإعدادات بنفسه
✅ يرى الشاشة (screenshots)
✅ يكتب Expert Advisors
✅ يتحكم في الماوس ولوحة المفاتيح
```

---

## 🚀 التشغيل

### 1️⃣ تثبيت المتطلبات الإضافية

```bash
pip install pyautogui pygetwindow pillow pyperclip
pip install MetaTrader5  # Windows فقط
```

### 2️⃣ تشغيل النظام الجديد

```bash
python mt5_full_control.py
```

### 3️⃣ فتح التوثيق

```
http://localhost:8000/docs
```

---

## 📡 نقاط النهاية الجديدة

### 📸 الرؤية (Screenshots)

| Endpoint | الوصف |
|----------|-------|
| `GET /screenshot` | التقاط صورة للشاشة |
| `GET /screenshot?mt5_only=true` | التقاط نافذة MT5 فقط |
| `GET /screenshot/stream` | صورة PNG مباشرة |

**مثال:**
```python
response = requests.get("http://localhost:8000/screenshot?mt5_only=true")
data = response.json()
# data["image"] = صورة Base64
```

---

### 🖱️ التحكم في الماوس

| Endpoint | الوصف |
|----------|-------|
| `POST /mouse/click` | نقر في موقع محدد |
| `POST /mouse/move` | تحريك الماوس |
| `POST /mouse/drag` | سحب الماوس |
| `GET /mouse/position` | موقع الماوس الحالي |

**مثال - نقر:**
```python
requests.post("http://localhost:8000/mouse/click", json={
    "x": 500,
    "y": 300,
    "clicks": 1,
    "button": "left"
})
```

**مثال - نقر مزدوج:**
```python
requests.post("http://localhost:8000/mouse/click", json={
    "x": 500,
    "y": 300,
    "clicks": 2,
    "button": "left"
})
```

---

### ⌨️ التحكم في لوحة المفاتيح

| Endpoint | الوصف |
|----------|-------|
| `POST /keyboard/type` | كتابة نص (إنجليزي) |
| `POST /keyboard/write` | كتابة نص (يدعم العربية) |
| `POST /keyboard/press` | ضغط مفتاح |
| `POST /keyboard/hotkey` | اختصار لوحة المفاتيح |

**مثال - كتابة:**
```python
requests.post("http://localhost:8000/keyboard/type?text=EURUSD")
```

**مثال - اختصار:**
```python
# Ctrl+R لفتح Strategy Tester
requests.post("http://localhost:8000/keyboard/hotkey", json={
    "keys": ["ctrl", "r"]
})
```

**المفاتيح المتاحة:**
```
enter, tab, space, backspace, delete, escape
up, down, left, right, home, end
pageup, pagedown, f1-f12
ctrl, alt, shift, win
```

---

### 🪟 التحكم في النوافذ

| Endpoint | الوصف |
|----------|-------|
| `GET /windows` | قائمة النوافذ المفتوحة |
| `POST /windows/focus` | تفعيل نافذة |
| `POST /mt5/focus` | تفعيل نافذة MT5 |

---

### 📊 MT5 التحكم الكامل

| Endpoint | الوصف |
|----------|-------|
| `POST /mt5/launch` | تشغيل MT5 |
| `POST /mt5/focus` | تفعيل نافذة MT5 |
| `POST /mt5/open_strategy_tester` | فتح Strategy Tester |
| `POST /mt5/visual_backtest` | تشغيل Backtest مرئي |

**مثال - فتح Strategy Tester:**
```python
# يفعّل MT5 ويضغط Ctrl+R
requests.post("http://localhost:8000/mt5/open_strategy_tester")
```

---

### 🤖 Expert Advisors

| Endpoint | الوصف |
|----------|-------|
| `GET /experts` | قائمة EAs المتاحة |
| `POST /experts/create` | إنشاء EA جديد |
| `GET /experts/{name}/code` | قراءة كود EA |
| `PUT /experts/{name}/code` | تعديل كود EA |

**مثال - إنشاء EA:**
```python
code = '''
//+------------------------------------------------------------------+
//|                                                      SimpleEA.mq5|
//+------------------------------------------------------------------+
#property copyright "AI Generated"
#property version   "1.00"

input int MagicNumber = 12345;
input double LotSize = 0.01;

int OnInit() {
    Print("EA Started!");
    return(INIT_SUCCEEDED);
}

void OnTick() {
    // Trading logic here
}
'''

requests.post("http://localhost:8000/experts/create", json={
    "name": "MyAI_EA",
    "code": code,
    "compile": True
})
```

---

## 🎯 سيناريوهات استخدام

### السيناريو 1: Manus يشغّل Backtest مرئي

```python
# 1. تفعيل MT5
requests.post("http://localhost:8000/mt5/focus")

# 2. فتح Strategy Tester
requests.post("http://localhost:8000/mt5/open_strategy_tester")

# 3. التقاط صورة لرؤية الحالة
response = requests.get("http://localhost:8000/screenshot?mt5_only=true")
# AI يحلل الصورة ويحدد مواقع الأزرار

# 4. النقر على dropdown لاختيار EA
requests.post("http://localhost:8000/mouse/click", json={"x": 200, "y": 100})

# 5. كتابة اسم EA
requests.post("http://localhost:8000/keyboard/type?text=ExpertMACD")
requests.post("http://localhost:8000/keyboard/press?key=enter")

# 6. تفعيل Visual Mode
requests.post("http://localhost:8000/mouse/click", json={"x": 150, "y": 400})

# 7. ضغط Start
requests.post("http://localhost:8000/mouse/click", json={"x": 300, "y": 500})
```

### السيناريو 2: AI يكتب EA ويختبره

```python
# 1. كتابة كود EA
ea_code = "..."  # AI يكتب الكود
requests.post("http://localhost:8000/experts/create", json={
    "name": "AI_Strategy_v1",
    "code": ea_code
})

# 2. فتح MetaEditor للترجمة (F4)
requests.post("http://localhost:8000/mt5/focus")
requests.post("http://localhost:8000/keyboard/press?key=f4")

# 3. انتظار وترجمة (F7)
time.sleep(2)
requests.post("http://localhost:8000/keyboard/press?key=f7")

# 4. العودة لـ MT5 وفتح Strategy Tester
requests.post("http://localhost:8000/keyboard/hotkey", json={"keys": ["alt", "tab"]})
requests.post("http://localhost:8000/keyboard/hotkey", json={"keys": ["ctrl", "r"]})
```

### السيناريو 3: مراقبة الشاشة

```python
# التقاط صورة كل 5 ثواني
while True:
    response = requests.get("http://localhost:8000/screenshot?mt5_only=true")
    image_base64 = response.json()["image"]
    
    # AI يحلل الصورة
    # يقرأ النتائج
    # يتخذ قرارات
    
    time.sleep(5)
```

---

## ⚠️ ملاحظات مهمة

### 1. الأمان
```
⚠️ pyautogui.FAILSAFE = True
حرك الماوس للزاوية العلوية اليسرى لإيقاف البرنامج طارئاً
```

### 2. التأخير
```python
# هناك تأخير 0.1 ثانية بين كل أمر
# يمكن تعديله في الكود
pyautogui.PAUSE = 0.1
```

### 3. إحداثيات الشاشة
```
• الإحداثيات تبدأ من (0,0) في الزاوية العلوية اليسرى
• استخدم /screenshot لمعرفة الإحداثيات
• استخدم /mouse/position للموقع الحالي
```

### 4. دقة الشاشة
```
• تأكد من دقة الشاشة ثابتة
• الإحداثيات تختلف حسب دقة الشاشة
• التقط صورة أولاً لتحديد المواقع
```

---

## 🔄 مقارنة بين النظامين

| الميزة | main.py | mt5_full_control.py |
|--------|---------|---------------------|
| الاتصال بـ MT5 | ✅ | ✅ |
| معلومات الحساب | ✅ | ✅ |
| قائمة الرموز | ✅ | ✅ |
| Backtest (غير مرئي) | ✅ | ✅ |
| **Backtest مرئي** | ❌ | ✅ |
| **التقاط الشاشة** | ❌ | ✅ |
| **التحكم بالماوس** | ❌ | ✅ |
| **التحكم بلوحة المفاتيح** | ❌ | ✅ |
| **كتابة Expert Advisors** | ❌ | ✅ |
| **رؤية النتائج** | ❌ | ✅ |

---

## 📊 التكامل مع AI

### Claude / Manus يستطيع الآن:

```
1. رؤية شاشة MT5 (screenshots)
2. تحليل الصور وفهم الواجهة
3. النقر على الأزرار والقوائم
4. كتابة في الحقول
5. اختيار Expert Advisors
6. تعديل الإعدادات
7. تشغيل Backtest مرئي
8. مراقبة النتائج
9. كتابة Expert Advisors جديدة
10. التحكم الكامل مثل الإنسان!
```

---

## 🎉 الخلاصة

```
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   🎮 نظام التحكم الكامل                                          ║
║                                                                   ║
║   الآن AI يستطيع:                                                ║
║   • رؤية MT5 (screenshots)                                       ║
║   • التحكم بالماوس                                               ║
║   • التحكم بلوحة المفاتيح                                        ║
║   • فتح Strategy Tester                                          ║
║   • تشغيل Backtest مرئي                                          ║
║   • كتابة Expert Advisors                                        ║
║   • قراءة النتائج                                                ║
║   • التحكم الكامل مثل إنسان! 🤖                                  ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
```

</div>
