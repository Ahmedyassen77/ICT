"""
=============================================================================
    سكريبت تشغيل التحليل
    يحلل ويحفظ النتائج في مجلد MT5 Files
=============================================================================
"""

import os
import sys
import shutil

# إضافة المسار
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from smc_analyzer import SMCAnalyzer
import MetaTrader5 as mt5

def main():
    print("="*60)
    print("   🚀 SMC Python Analyzer")
    print("="*60)
    
    # الإعدادات
    SYMBOL = "EURUSD"
    TIMEFRAME = mt5.TIMEFRAME_H1
    BARS = 500
    SWING_STRENGTH = 3
    
    # تشغيل التحليل
    analyzer = SMCAnalyzer(symbol=SYMBOL, timeframe=TIMEFRAME)
    
    # تحليل
    local_file = analyzer.analyze(bars=BARS, swing_strength=SWING_STRENGTH)
    
    if local_file:
        # نسخ الملف إلى مجلد MT5 Files
        mt5_data_path = mt5.terminal_info().data_path
        mt5_files_path = os.path.join(mt5_data_path, "MQL5", "Files")
        
        dest_file = os.path.join(mt5_files_path, "smc_signals.json")
        shutil.copy(local_file, dest_file)
        
        print(f"\n✅ تم نسخ الملف إلى: {dest_file}")
        print("\n📌 الآن افتح MT5 وشغل SMC_Drawer_EA على الشارت!")
        print("="*60)
    
    # إغلاق الاتصال
    mt5.shutdown()

if __name__ == "__main__":
    main()
