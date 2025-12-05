#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=================================================================================
          🚀 MT5 Cloud Sync - سكربت الإعداد التلقائي
          Automatic Setup Script
=================================================================================

هذا السكربت يثبت كل شيء بضغطة واحدة!
This script installs everything with one click!

الاستخدام / Usage:
    python setup_cloud_sync.py

=================================================================================
"""

import os
import sys
import subprocess
import platform
import shutil
import secrets
import json
from pathlib import Path
import urllib.request
import zipfile
import tempfile

# ألوان للطباعة
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    END = '\033[0m'

def print_header(msg):
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*60}")
    print(f"  {msg}")
    print(f"{'='*60}{Colors.END}\n")

def print_success(msg):
    print(f"{Colors.GREEN}✅ {msg}{Colors.END}")

def print_warning(msg):
    print(f"{Colors.YELLOW}⚠️  {msg}{Colors.END}")

def print_error(msg):
    print(f"{Colors.RED}❌ {msg}{Colors.END}")

def print_info(msg):
    print(f"{Colors.BLUE}ℹ️  {msg}{Colors.END}")

def print_step(msg):
    print(f"{Colors.MAGENTA}🔄 {msg}{Colors.END}")

def print_banner():
    """طباعة شعار البرنامج"""
    banner = f"""
{Colors.BOLD}{Colors.CYAN}
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║   ███╗   ███╗████████╗███████╗     ██████╗██╗      ██████╗ ██╗   ██╗██████╗  ║
║   ████╗ ████║╚══██╔══╝██╔════╝    ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗ ║
║   ██╔████╔██║   ██║   ███████╗    ██║     ██║     ██║   ██║██║   ██║██║  ██║ ║
║   ██║╚██╔╝██║   ██║   ╚════██║    ██║     ██║     ██║   ██║██║   ██║██║  ██║ ║
║   ██║ ╚═╝ ██║   ██║   ███████║    ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝ ║
║   ╚═╝     ╚═╝   ╚═╝   ╚══════╝     ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝  ║
║                                                                          ║
║                   🌐 Cloud Sync Setup                                    ║
║                   سكربت الإعداد التلقائي                                  ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
{Colors.END}
"""
    print(banner)


class CloudSyncSetup:
    """فئة إعداد Cloud Sync"""
    
    def __init__(self):
        self.base_dir = Path(__file__).parent.absolute()
        self.config_file = self.base_dir / "cloud_sync_config.json"
        self.requirements_file = self.base_dir / "requirements.txt"
        self.is_windows = platform.system() == "Windows"
        
        # الإعدادات
        self.config = {
            "api_key": "",
            "server_port": 8000,
            "mt5_path": "",
            "ngrok_installed": False,
            "setup_complete": False
        }
    
    def check_python_version(self) -> bool:
        """التحقق من إصدار Python"""
        print_step("التحقق من إصدار Python...")
        
        version = sys.version_info
        if version.major >= 3 and version.minor >= 8:
            print_success(f"Python {version.major}.{version.minor}.{version.micro} ✓")
            return True
        else:
            print_error(f"Python {version.major}.{version.minor} - مطلوب 3.8+")
            print_info("حمّل Python من: https://python.org")
            return False
    
    def check_pip(self) -> bool:
        """التحقق من pip"""
        print_step("التحقق من pip...")
        
        try:
            subprocess.run([sys.executable, "-m", "pip", "--version"], 
                         capture_output=True, check=True)
            print_success("pip متوفر ✓")
            return True
        except:
            print_error("pip غير متوفر")
            return False
    
    def install_requirements(self) -> bool:
        """تثبيت المتطلبات"""
        print_header("تثبيت المتطلبات")
        
        # قائمة المتطلبات
        requirements = [
            "fastapi",
            "uvicorn[standard]",
            "pydantic",
            "httpx",
            "python-multipart",
        ]
        
        # متطلبات Windows فقط
        if self.is_windows:
            requirements.extend([
                "pywinauto",
                "comtypes",
                "MetaTrader5",
                "pyautogui",
                "pygetwindow",
                "pillow",
                "pyperclip",
            ])
        
        # تثبيت كل حزمة
        for package in requirements:
            print_step(f"تثبيت {package}...")
            try:
                result = subprocess.run(
                    [sys.executable, "-m", "pip", "install", package, "-q"],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    print_success(f"{package} ✓")
                else:
                    print_warning(f"{package} - قد يكون مثبتاً مسبقاً")
            except Exception as e:
                print_warning(f"تحذير في تثبيت {package}: {e}")
        
        print_success("تم تثبيت المتطلبات!")
        return True
    
    def create_requirements_file(self):
        """إنشاء ملف requirements.txt"""
        content = """# MT5 Cloud Sync Requirements
# تثبيت: pip install -r requirements.txt

# === Core ===
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
pydantic>=2.0.0
httpx>=0.25.0
python-multipart>=0.0.6

# === Windows Only (MT5 Control) ===
# حذف هذه إذا كنت على Linux/Mac
pywinauto>=0.6.8
comtypes>=1.2.0
MetaTrader5>=5.0.45
pyautogui>=0.9.54
pygetwindow>=0.0.9
pillow>=10.0.0
pyperclip>=1.8.2

# === Optional ===
# websockets>=12.0  # للتحديثات المباشرة
# aiofiles>=23.0.0  # للملفات async
"""
        
        with open(self.requirements_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print_success(f"تم إنشاء {self.requirements_file}")
    
    def find_mt5_path(self) -> str:
        """البحث عن مسار MT5"""
        print_step("البحث عن MetaTrader 5...")
        
        if not self.is_windows:
            print_warning("MT5 متوفر فقط على Windows")
            return ""
        
        # المسارات الشائعة
        common_paths = [
            "C:/Program Files/MetaTrader 5 IC Markets Global/terminal64.exe",
            "C:/Program Files/MetaTrader 5/terminal64.exe",
            "C:/Program Files (x86)/MetaTrader 5/terminal64.exe",
            "D:/MetaTrader 5/terminal64.exe",
            "D:/Program Files/MetaTrader 5/terminal64.exe",
        ]
        
        # البحث في Program Files
        program_files = [
            os.environ.get('PROGRAMFILES', 'C:/Program Files'),
            os.environ.get('PROGRAMFILES(X86)', 'C:/Program Files (x86)'),
            "D:/Program Files",
        ]
        
        for pf in program_files:
            if os.path.exists(pf):
                for folder in os.listdir(pf):
                    if 'metatrader' in folder.lower() or 'mt5' in folder.lower():
                        path = os.path.join(pf, folder, 'terminal64.exe')
                        if os.path.exists(path):
                            common_paths.insert(0, path)
        
        # التحقق من المسارات
        for path in common_paths:
            if os.path.exists(path):
                print_success(f"وُجد MT5: {path}")
                return path
        
        print_warning("لم يُعثر على MT5 - يرجى تحديد المسار يدوياً")
        return ""
    
    def generate_api_key(self) -> str:
        """توليد مفتاح API آمن"""
        return secrets.token_urlsafe(32)
    
    def check_ngrok(self) -> bool:
        """التحقق من ngrok"""
        print_step("التحقق من ngrok...")
        
        try:
            result = subprocess.run(["ngrok", "version"], 
                                   capture_output=True, text=True)
            if result.returncode == 0:
                print_success(f"ngrok متوفر: {result.stdout.strip()}")
                return True
        except FileNotFoundError:
            pass
        
        print_warning("ngrok غير مثبت")
        print_info("حمّل من: https://ngrok.com/download")
        return False
    
    def create_startup_scripts(self):
        """إنشاء سكربتات التشغيل"""
        print_header("إنشاء سكربتات التشغيل")
        
        # === Windows Batch Script ===
        if self.is_windows:
            bat_content = f'''@echo off
chcp 65001 >nul
title MT5 Cloud Sync Server

echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║           🌐 MT5 Cloud Sync Server                           ║
echo ║           خادم التحكم عن بعد                                  ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

:: تعيين مفتاح API
set MT5_API_KEY={self.config['api_key']}

:: الانتقال لمجلد المشروع
cd /d "{self.base_dir}"

:: تشغيل الخادم
echo 🚀 بدء تشغيل الخادم...
echo.
python remote_control_server.py

pause
'''
            
            bat_path = self.base_dir / "start_server.bat"
            with open(bat_path, 'w', encoding='utf-8') as f:
                f.write(bat_content)
            print_success(f"تم إنشاء: {bat_path}")
            
            # === ngrok Script ===
            ngrok_bat = f'''@echo off
chcp 65001 >nul
title ngrok Tunnel

echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║           🌐 ngrok Tunnel                                    ║
echo ║           الرابط العام للتحكم عن بعد                          ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo 📝 انسخ الرابط (Forwarding) وأعطه لـ Claude
echo.

ngrok http {self.config['server_port']}

pause
'''
            
            ngrok_path = self.base_dir / "start_ngrok.bat"
            with open(ngrok_path, 'w', encoding='utf-8') as f:
                f.write(ngrok_bat)
            print_success(f"تم إنشاء: {ngrok_path}")
            
            # === Combined Script ===
            combined_bat = f'''@echo off
chcp 65001 >nul
title MT5 Cloud Sync - Full Setup

echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║           🚀 MT5 Cloud Sync - التشغيل الكامل                 ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

:: تعيين مفتاح API
set MT5_API_KEY={self.config['api_key']}

cd /d "{self.base_dir}"

echo 🔄 بدء تشغيل الخادم و ngrok...
echo.

:: تشغيل الخادم في نافذة جديدة
start "MT5 Server" cmd /k "cd /d {self.base_dir} && set MT5_API_KEY={self.config['api_key']} && python remote_control_server.py"

:: انتظار بدء الخادم
timeout /t 3 /nobreak >nul

:: تشغيل ngrok في نافذة جديدة
start "ngrok" cmd /k "ngrok http {self.config['server_port']}"

echo.
echo ✅ تم!
echo.
echo 📝 الخطوات التالية:
echo    1. انتظر حتى يظهر رابط ngrok
echo    2. انسخ الرابط (مثل: https://abc123.ngrok.io)
echo    3. أعطِ الرابط ومفتاح API لـ Claude
echo.
echo 🔐 مفتاح API: {self.config['api_key'][:20]}...
echo.

pause
'''
            
            combined_path = self.base_dir / "start_cloud_sync.bat"
            with open(combined_path, 'w', encoding='utf-8') as f:
                f.write(combined_bat)
            print_success(f"تم إنشاء: {combined_path}")
        
        # === Python Script (Cross-platform) ===
        py_content = f'''#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
سكربت تشغيل سريع - Quick Start Script
"""

import os
import sys
import subprocess
import threading
import time

# تعيين مفتاح API
os.environ['MT5_API_KEY'] = '{self.config['api_key']}'

# المسار
BASE_DIR = r"{self.base_dir}"
os.chdir(BASE_DIR)

def start_server():
    """تشغيل الخادم"""
    print("🚀 بدء الخادم...")
    subprocess.run([sys.executable, "remote_control_server.py"])

def start_ngrok():
    """تشغيل ngrok"""
    print("🌐 بدء ngrok...")
    time.sleep(2)  # انتظار الخادم
    subprocess.run(["ngrok", "http", "{self.config['server_port']}"])

if __name__ == "__main__":
    print("""
╔══════════════════════════════════════════════════════════════╗
║           🌐 MT5 Cloud Sync - Quick Start                    ║
╚══════════════════════════════════════════════════════════════╝
""")
    
    # اختيار الوضع
    print("اختر:")
    print("1. تشغيل الخادم فقط")
    print("2. تشغيل ngrok فقط")
    print("3. تشغيل الكل")
    
    choice = input("\\nاختيارك (1/2/3): ").strip()
    
    if choice == "1":
        start_server()
    elif choice == "2":
        start_ngrok()
    else:
        # تشغيل الكل في threads
        server_thread = threading.Thread(target=start_server)
        server_thread.start()
        
        time.sleep(3)
        print("\\n🔐 مفتاح API: {self.config['api_key'][:20]}...")
        print("📝 انسخ رابط ngrok عندما يظهر...")
        
        start_ngrok()
'''
        
        py_path = self.base_dir / "quick_start.py"
        with open(py_path, 'w', encoding='utf-8') as f:
            f.write(py_content)
        print_success(f"تم إنشاء: {py_path}")
    
    def save_config(self):
        """حفظ الإعدادات"""
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(self.config, f, indent=2, ensure_ascii=False)
        print_success(f"تم حفظ الإعدادات في: {self.config_file}")
    
    def load_config(self):
        """تحميل الإعدادات"""
        if self.config_file.exists():
            with open(self.config_file, 'r', encoding='utf-8') as f:
                self.config.update(json.load(f))
    
    def run_setup(self):
        """تشغيل الإعداد الكامل"""
        print_banner()
        
        print_header("بدء الإعداد التلقائي")
        
        # 1. التحقق من Python
        if not self.check_python_version():
            return False
        
        # 2. التحقق من pip
        if not self.check_pip():
            return False
        
        # 3. تثبيت المتطلبات
        self.create_requirements_file()
        self.install_requirements()
        
        # 4. البحث عن MT5
        self.config['mt5_path'] = self.find_mt5_path()
        
        # 5. التحقق من ngrok
        self.config['ngrok_installed'] = self.check_ngrok()
        
        # 6. توليد مفتاح API
        print_header("إعداد الأمان")
        self.config['api_key'] = self.generate_api_key()
        print_success(f"مفتاح API: {self.config['api_key']}")
        print_warning("احفظ هذا المفتاح! ستحتاجه للاتصال.")
        
        # 7. إنشاء سكربتات التشغيل
        self.create_startup_scripts()
        
        # 8. حفظ الإعدادات
        self.config['setup_complete'] = True
        self.save_config()
        
        # 9. عرض الملخص
        self.print_summary()
        
        return True
    
    def print_summary(self):
        """طباعة ملخص الإعداد"""
        print(f"""
{Colors.BOLD}{Colors.GREEN}
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                    ✅ تم الإعداد بنجاح!                                  ║
║                    Setup Complete!                                       ║
║                                                                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║   📁 المجلد: {str(self.base_dir)[:50]}...
║                                                                          ║
║   🔐 مفتاح API: {self.config['api_key'][:30]}...
║                                                                          ║
║   📊 MT5: {'✅ موجود' if self.config['mt5_path'] else '❌ غير موجود'}
║   🌐 ngrok: {'✅ مثبت' if self.config['ngrok_installed'] else '❌ غير مثبت'}
║                                                                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║   🚀 للتشغيل السريع:                                                     ║
║   ─────────────────                                                      ║
║   • Windows: انقر مرتين على start_cloud_sync.bat                        ║
║   • أو شغّل: python quick_start.py                                       ║
║                                                                          ║
║   📝 الخطوات:                                                            ║
║   ─────────                                                              ║
║   1. شغّل start_cloud_sync.bat                                          ║
║   2. انسخ رابط ngrok (مثل: https://abc123.ngrok.io)                     ║
║   3. أعطِ الرابط ومفتاح API لـ Claude                                   ║
║   4. تكلم مع Claude واطلب منه التحكم في MT5!                            ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
{Colors.END}
""")
        
        if not self.config['ngrok_installed']:
            print(f"""
{Colors.YELLOW}
⚠️  ngrok غير مثبت!
─────────────────────────────────────────────────────
لتثبيت ngrok:
1. حمّل من: https://ngrok.com/download
2. فك الضغط وانقل ngrok.exe لمجلد في PATH
3. سجّل حساب مجاني على ngrok.com
4. شغّل: ngrok config add-authtoken YOUR_TOKEN
─────────────────────────────────────────────────────
{Colors.END}
""")


def main():
    """الدالة الرئيسية"""
    setup = CloudSyncSetup()
    
    # التحقق من وجود إعداد سابق
    setup.load_config()
    
    if setup.config.get('setup_complete'):
        print_info("تم العثور على إعداد سابق!")
        choice = input("\nهل تريد إعادة الإعداد؟ (y/n): ").strip().lower()
        if choice != 'y':
            print_info("استخدم start_cloud_sync.bat للتشغيل")
            return
    
    # تشغيل الإعداد
    success = setup.run_setup()
    
    if success:
        print_success("\n🎉 جاهز للاستخدام!")
    else:
        print_error("\n❌ فشل الإعداد - راجع الأخطاء أعلاه")


if __name__ == "__main__":
    main()
