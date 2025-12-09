"""
Run SMC Analyzer V3 - Reference Indicator Style
"""
from smc_analyzer_v3 import SMCAnalyzerV3
import MetaTrader5 as mt5

if __name__ == "__main__":
    print("="*60)
    print("   SMC Analyzer V3 - Reference Style")
    print("="*60)
    
    analyzer = SMCAnalyzerV3(symbol="EURUSD", timeframe=mt5.TIMEFRAME_H1)
    result = analyzer.analyze(bars=500, swing_strength=5)
    
    if result:
        print("\n[SUCCESS] Analysis complete!")
        print("Now attach SMC_Drawer_V2.ex5 to your chart")
    else:
        print("\n[ERROR] Analysis failed")
