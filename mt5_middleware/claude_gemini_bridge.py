"""
=================================================================================
          🌉 Claude-Gemini Bridge
          جسر التواصل بين Claude و Gemini CLI
=================================================================================

الفكرة:
- Claude يكتب أوامر في ملف
- Gemini CLI يراقب الملف وينفذ الأوامر
- النتائج ترجع لـ Claude

طريقة الاستخدام:
1. شغّل هذا السكريبت على Windows (مع Gemini CLI)
2. Claude يكتب أوامر في commands.json
3. السكريبت ينفذها ويحفظ النتائج في results.json

=================================================================================
"""

import os
import sys
import json
import time
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional
import threading
import hashlib

# ألوان
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    END = '\033[0m'

def log(msg, color=Colors.CYAN):
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"{color}[{timestamp}] {msg}{Colors.END}")

def log_success(msg): log(f"✅ {msg}", Colors.GREEN)
def log_warning(msg): log(f"⚠️ {msg}", Colors.YELLOW)
def log_error(msg): log(f"❌ {msg}", Colors.RED)
def log_info(msg): log(f"ℹ️ {msg}", Colors.BLUE)
def log_command(msg): log(f"🚀 {msg}", Colors.MAGENTA)


# =================================================================================
#                          المسارات
# =================================================================================

# مجلد التواصل (يجب أن يكون متاح لـ Claude و Gemini)
BRIDGE_DIR = Path.home() / "claude_gemini_bridge"
COMMANDS_FILE = BRIDGE_DIR / "commands.json"
RESULTS_FILE = BRIDGE_DIR / "results.json"
STATUS_FILE = BRIDGE_DIR / "status.json"
LOG_FILE = BRIDGE_DIR / "bridge.log"


# =================================================================================
#                          فئة الجسر
# =================================================================================

class ClaudeGeminiBridge:
    """
    جسر التواصل بين Claude و Gemini CLI
    
    Claude يكتب أوامر ──► هذا السكريبت ينفذها ──► النتائج ترجع لـ Claude
    """
    
    def __init__(self):
        self.running = False
        self.last_command_hash = None
        self.command_history = []
        
        # إنشاء المجلد
        BRIDGE_DIR.mkdir(exist_ok=True)
        
        # تهيئة الملفات
        self._init_files()
        
        log_success(f"تم تهيئة الجسر في: {BRIDGE_DIR}")
    
    def _init_files(self):
        """تهيئة ملفات التواصل"""
        
        # ملف الأوامر
        if not COMMANDS_FILE.exists():
            self._write_json(COMMANDS_FILE, {
                "command": None,
                "params": {},
                "timestamp": None,
                "from": "claude"
            })
        
        # ملف النتائج
        if not RESULTS_FILE.exists():
            self._write_json(RESULTS_FILE, {
                "result": None,
                "success": False,
                "timestamp": None,
                "from": "gemini"
            })
        
        # ملف الحالة
        self._update_status("idle", "جاهز للأوامر")
    
    def _write_json(self, path: Path, data: Dict):
        """كتابة JSON"""
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    
    def _read_json(self, path: Path) -> Dict:
        """قراءة JSON"""
        try:
            with open(path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return {}
    
    def _update_status(self, state: str, message: str):
        """تحديث الحالة"""
        self._write_json(STATUS_FILE, {
            "state": state,
            "message": message,
            "timestamp": datetime.now().isoformat(),
            "bridge_active": self.running
        })
    
    def _get_command_hash(self, cmd_data: Dict) -> str:
        """حساب hash للأمر لتجنب التكرار"""
        content = json.dumps(cmd_data, sort_keys=True)
        return hashlib.md5(content.encode()).hexdigest()
    
    def _execute_command(self, command: str, params: Dict) -> Dict:
        """تنفيذ الأمر"""
        log_command(f"تنفيذ: {command}")
        log_info(f"المعاملات: {params}")
        
        result = {
            "success": False,
            "output": None,
            "error": None,
            "command": command,
            "timestamp": datetime.now().isoformat()
        }
        
        try:
            # ═══════════════════════════════════════════════════════
            #                    الأوامر المتاحة
            # ═══════════════════════════════════════════════════════
            
            if command == "ping":
                # اختبار الاتصال
                result["success"] = True
                result["output"] = "pong! الجسر يعمل بشكل صحيح 🎉"
            
            elif command == "shell":
                # تنفيذ أمر shell
                cmd = params.get("cmd", "")
                if cmd:
                    process = subprocess.run(
                        cmd, shell=True, capture_output=True, 
                        text=True, timeout=60
                    )
                    result["success"] = process.returncode == 0
                    result["output"] = process.stdout
                    result["error"] = process.stderr if process.stderr else None
            
            elif command == "python":
                # تنفيذ كود Python
                code = params.get("code", "")
                if code:
                    # حفظ الكود في ملف مؤقت
                    temp_file = BRIDGE_DIR / "temp_script.py"
                    with open(temp_file, 'w', encoding='utf-8') as f:
                        f.write(code)
                    
                    process = subprocess.run(
                        [sys.executable, str(temp_file)],
                        capture_output=True, text=True, timeout=120
                    )
                    result["success"] = process.returncode == 0
                    result["output"] = process.stdout
                    result["error"] = process.stderr if process.stderr else None
            
            elif command == "mt5_status":
                # حالة MT5
                from gemini_cli_integration import MT5Controller
                controller = MT5Controller()
                
                result["success"] = True
                result["output"] = {
                    "terminal_path": controller.terminal_path,
                    "data_path": controller.data_path,
                    "mt5_available": controller.mt5 is not None
                }
            
            elif command == "mt5_connect":
                # الاتصال بـ MT5
                from gemini_cli_integration import MT5Controller
                controller = MT5Controller()
                
                path = params.get("path")
                success = controller.connect(path)
                
                result["success"] = success
                result["output"] = controller.get_account_info() if success else "فشل الاتصال"
            
            elif command == "mt5_create_ea":
                # إنشاء EA
                from gemini_cli_integration import MT5Controller
                controller = MT5Controller()
                
                name = params.get("name", "AI_EA")
                strategy = params.get("strategy", "MA Crossover")
                risk = params.get("risk", 2.0)
                
                success = controller.create_expert(name, strategy, risk)
                
                result["success"] = success
                result["output"] = f"تم إنشاء {name}.mq5" if success else "فشل الإنشاء"
            
            elif command == "mt5_backtest":
                # تشغيل Backtest
                from gemini_cli_integration import MT5Controller
                controller = MT5Controller()
                
                success = controller.run_backtest(
                    expert_name=params.get("expert", ""),
                    symbol=params.get("symbol", "EURUSD"),
                    timeframe=params.get("timeframe", "H1"),
                    from_date=params.get("from_date", "2024.01.01"),
                    to_date=params.get("to_date", "2024.12.31"),
                    visual=params.get("visual", True)
                )
                
                result["success"] = success
                result["output"] = "تم بدء الاختبار المرئي!" if success else "فشل التشغيل"
            
            elif command == "mt5_trade":
                # تنفيذ صفقة
                from gemini_cli_integration import MT5Controller
                controller = MT5Controller()
                controller.connect()
                
                success = controller.trade(
                    symbol=params.get("symbol", "EURUSD"),
                    order_type=params.get("type", "buy"),
                    volume=params.get("volume", 0.01),
                    sl=params.get("sl"),
                    tp=params.get("tp")
                )
                
                result["success"] = success
                result["output"] = "تم تنفيذ الصفقة!" if success else "فشل التنفيذ"
            
            elif command == "mt5_account":
                # معلومات الحساب
                from gemini_cli_integration import MT5Controller
                controller = MT5Controller()
                controller.connect()
                
                info = controller.get_account_info()
                result["success"] = bool(info)
                result["output"] = info
            
            elif command == "mt5_experts":
                # قائمة EAs
                from gemini_cli_integration import MT5Controller
                controller = MT5Controller()
                
                experts = controller.list_experts()
                result["success"] = True
                result["output"] = experts
            
            elif command == "mt5_price":
                # السعر الحالي
                from gemini_cli_integration import MT5Controller
                controller = MT5Controller()
                controller.connect()
                
                symbol = params.get("symbol", "EURUSD")
                price = controller.get_price(symbol)
                
                result["success"] = bool(price)
                result["output"] = price
            
            elif command == "read_file":
                # قراءة ملف
                path = params.get("path", "")
                if path and os.path.exists(path):
                    with open(path, 'r', encoding='utf-8') as f:
                        result["success"] = True
                        result["output"] = f.read()
                else:
                    result["error"] = f"الملف غير موجود: {path}"
            
            elif command == "write_file":
                # كتابة ملف
                path = params.get("path", "")
                content = params.get("content", "")
                if path:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    result["success"] = True
                    result["output"] = f"تم كتابة الملف: {path}"
            
            elif command == "list_dir":
                # قائمة الملفات
                path = params.get("path", ".")
                if os.path.exists(path):
                    files = os.listdir(path)
                    result["success"] = True
                    result["output"] = files
                else:
                    result["error"] = f"المسار غير موجود: {path}"
            
            else:
                result["error"] = f"أمر غير معروف: {command}"
        
        except Exception as e:
            result["error"] = str(e)
            log_error(f"خطأ: {e}")
        
        return result
    
    def process_command(self):
        """معالجة الأمر الحالي"""
        cmd_data = self._read_json(COMMANDS_FILE)
        
        command = cmd_data.get("command")
        if not command:
            return
        
        # تجنب تنفيذ نفس الأمر مرتين
        cmd_hash = self._get_command_hash(cmd_data)
        if cmd_hash == self.last_command_hash:
            return
        
        self.last_command_hash = cmd_hash
        
        log_info(f"أمر جديد من Claude: {command}")
        self._update_status("executing", f"جاري تنفيذ: {command}")
        
        # تنفيذ الأمر
        params = cmd_data.get("params", {})
        result = self._execute_command(command, params)
        
        # حفظ النتيجة
        self._write_json(RESULTS_FILE, {
            "result": result["output"],
            "success": result["success"],
            "error": result["error"],
            "command": command,
            "timestamp": datetime.now().isoformat(),
            "from": "gemini"
        })
        
        # تحديث الحالة
        if result["success"]:
            log_success(f"تم تنفيذ: {command}")
            self._update_status("success", f"تم تنفيذ: {command}")
        else:
            log_error(f"فشل: {command}")
            self._update_status("error", f"فشل: {command} - {result['error']}")
        
        # إضافة للتاريخ
        self.command_history.append({
            "command": command,
            "params": params,
            "result": result,
            "timestamp": datetime.now().isoformat()
        })
    
    def start_watching(self, interval: float = 1.0):
        """بدء مراقبة الأوامر"""
        self.running = True
        self._update_status("watching", "جاري مراقبة الأوامر...")
        
        log_success("🌉 الجسر يعمل الآن!")
        log_info(f"مجلد التواصل: {BRIDGE_DIR}")
        log_info(f"ملف الأوامر: {COMMANDS_FILE}")
        log_info(f"ملف النتائج: {RESULTS_FILE}")
        print()
        log_info("في انتظار أوامر من Claude...")
        print()
        
        try:
            while self.running:
                self.process_command()
                time.sleep(interval)
        except KeyboardInterrupt:
            log_warning("تم إيقاف الجسر")
            self.running = False
            self._update_status("stopped", "تم إيقاف الجسر")
    
    def stop(self):
        """إيقاف المراقبة"""
        self.running = False


# =================================================================================
#                          أوامر Claude
# =================================================================================

class ClaudeCommands:
    """
    أوامر يستخدمها Claude لإرسال تعليمات لـ Gemini CLI
    
    هذه الفئة يستخدمها Claude (أو أي نظام) لكتابة الأوامر
    """
    
    @staticmethod
    def send_command(command: str, params: Dict = None) -> Dict:
        """إرسال أمر"""
        BRIDGE_DIR.mkdir(exist_ok=True)
        
        cmd_data = {
            "command": command,
            "params": params or {},
            "timestamp": datetime.now().isoformat(),
            "from": "claude"
        }
        
        with open(COMMANDS_FILE, 'w', encoding='utf-8') as f:
            json.dump(cmd_data, f, ensure_ascii=False, indent=2)
        
        return cmd_data
    
    @staticmethod
    def get_result(timeout: float = 30.0) -> Dict:
        """انتظار والحصول على النتيجة"""
        start_time = time.time()
        last_timestamp = None
        
        while time.time() - start_time < timeout:
            try:
                with open(RESULTS_FILE, 'r', encoding='utf-8') as f:
                    result = json.load(f)
                
                # تحقق من أن النتيجة جديدة
                if result.get("timestamp") != last_timestamp:
                    if result.get("timestamp"):
                        return result
                    last_timestamp = result.get("timestamp")
            except:
                pass
            
            time.sleep(0.5)
        
        return {"error": "انتهت مهلة الانتظار", "success": False}
    
    @staticmethod
    def get_status() -> Dict:
        """الحصول على حالة الجسر"""
        try:
            with open(STATUS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return {"state": "unknown", "message": "لا يمكن قراءة الحالة"}


# =================================================================================
#                          الأوامر المتاحة (للتوثيق)
# =================================================================================

AVAILABLE_COMMANDS = """
╔══════════════════════════════════════════════════════════════════════════╗
║                         الأوامر المتاحة                                   ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  🔧 أوامر النظام:                                                        ║
║  ─────────────────                                                       ║
║  ping              - اختبار الاتصال                                      ║
║  shell             - تنفيذ أمر shell     {cmd: "dir"}                   ║
║  python            - تنفيذ كود Python    {code: "print('hi')"}          ║
║  read_file         - قراءة ملف           {path: "C:/file.txt"}          ║
║  write_file        - كتابة ملف           {path: "...", content: "..."}  ║
║  list_dir          - قائمة الملفات       {path: "C:/"}                  ║
║                                                                          ║
║  📊 أوامر MT5:                                                           ║
║  ─────────────────                                                       ║
║  mt5_status        - حالة MT5                                           ║
║  mt5_connect       - الاتصال             {path: "C:/MT5/terminal.exe"}  ║
║  mt5_account       - معلومات الحساب                                     ║
║  mt5_price         - السعر الحالي        {symbol: "EURUSD"}             ║
║  mt5_experts       - قائمة EAs                                          ║
║  mt5_create_ea     - إنشاء EA            {name: "...", strategy: "..."}  ║
║  mt5_backtest      - تشغيل Backtest      {expert: "...", symbol: "..."}  ║
║  mt5_trade         - تنفيذ صفقة          {symbol: "...", type: "buy"}    ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"""


# =================================================================================
#                          نقطة الدخول
# =================================================================================

def main():
    print(f"""
{Colors.BOLD}{Colors.CYAN}
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                    🌉 Claude-Gemini Bridge                               ║
║                    جسر التواصل بين Claude و Gemini CLI                   ║
║                                                                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║   الطريقة:                                                               ║
║   ────────                                                               ║
║   1. شغّل هذا السكريبت (يبقى شغال في الخلفية)                           ║
║   2. Claude يكتب أوامر في: {str(COMMANDS_FILE)[:40]}...                  ║
║   3. الجسر ينفذها ويحفظ النتائج                                         ║
║   4. Claude يقرأ النتائج                                                 ║
║                                                                          ║
║   Claude ──► commands.json ──► Bridge ──► results.json ──► Claude        ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
{Colors.END}
""")
    
    print(AVAILABLE_COMMANDS)
    
    bridge = ClaudeGeminiBridge()
    bridge.start_watching()


if __name__ == "__main__":
    main()
