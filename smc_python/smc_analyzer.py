"""
=============================================================================
    SMC Analyzer - Smart Money Concepts in Python
    يحلل البيانات ويكتب النتائج في JSON لـ MT5 EA
=============================================================================
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
import json
from datetime import datetime
from pathlib import Path

class SMCAnalyzer:
    """
    محلل Smart Money Concepts
    يكتشف: Swing Points, BOS, CHoCH, Order Blocks
    """
    
    def __init__(self, symbol="EURUSD", timeframe=mt5.TIMEFRAME_H1):
        self.symbol = symbol
        self.timeframe = timeframe
        self.data = None
        self.swings = []
        self.bos_list = []
        self.choch_list = []
        self.order_blocks = []
        
    def connect(self):
        """الاتصال بـ MT5"""
        if not mt5.initialize():
            print(f"❌ فشل الاتصال بـ MT5: {mt5.last_error()}")
            return False
        print(f"✅ متصل بـ MT5")
        return True
    
    def get_data(self, bars=500):
        """جلب البيانات من MT5"""
        rates = mt5.copy_rates_from_pos(self.symbol, self.timeframe, 0, bars)
        if rates is None:
            print(f"❌ فشل جلب البيانات: {mt5.last_error()}")
            return False
            
        self.data = pd.DataFrame(rates)
        self.data['time'] = pd.to_datetime(self.data['time'], unit='s')
        print(f"✅ تم جلب {len(self.data)} شمعة")
        return True
    
    # =========================================================================
    #                         1. SWING POINTS
    # =========================================================================
    
    def find_swing_points(self, strength=3):
        """
        إيجاد Swing Highs و Swing Lows
        
        Swing High: أعلى نقطة محاطة بـ 'strength' شموع أقل على كل جانب
        Swing Low: أدنى نقطة محاطة بـ 'strength' شموع أعلى على كل جانب
        """
        self.swings = []
        
        highs = self.data['high'].values
        lows = self.data['low'].values
        times = self.data['time'].values
        
        for i in range(strength, len(self.data) - strength):
            # Check Swing High
            is_swing_high = True
            for j in range(1, strength + 1):
                if highs[i] <= highs[i-j] or highs[i] <= highs[i+j]:
                    is_swing_high = False
                    break
            
            if is_swing_high:
                self.swings.append({
                    'type': 'high',
                    'price': float(highs[i]),
                    'time': str(times[i]),
                    'bar_index': i,
                    'label': 'SH'  # سيتم تحديثه لاحقاً (HH, LH)
                })
            
            # Check Swing Low
            is_swing_low = True
            for j in range(1, strength + 1):
                if lows[i] >= lows[i-j] or lows[i] >= lows[i+j]:
                    is_swing_low = False
                    break
            
            if is_swing_low:
                self.swings.append({
                    'type': 'low',
                    'price': float(lows[i]),
                    'time': str(times[i]),
                    'bar_index': i,
                    'label': 'SL'  # سيتم تحديثه لاحقاً (HL, LL)
                })
        
        # ترتيب حسب الوقت
        self.swings.sort(key=lambda x: x['bar_index'])
        
        # تصنيف الـ Swings (HH, HL, LH, LL)
        self._classify_swings()
        
        print(f"✅ تم إيجاد {len(self.swings)} Swing Points")
        return self.swings
    
    def _classify_swings(self):
        """
        تصنيف Swing Points:
        - HH (Higher High): قمة أعلى من القمة السابقة
        - LH (Lower High): قمة أدنى من القمة السابقة
        - HL (Higher Low): قاع أعلى من القاع السابق
        - LL (Lower Low): قاع أدنى من القاع السابق
        """
        prev_high = None
        prev_low = None
        
        for swing in self.swings:
            if swing['type'] == 'high':
                if prev_high is not None:
                    if swing['price'] > prev_high:
                        swing['label'] = 'HH'
                    else:
                        swing['label'] = 'LH'
                prev_high = swing['price']
                
            elif swing['type'] == 'low':
                if prev_low is not None:
                    if swing['price'] > prev_low:
                        swing['label'] = 'HL'
                    else:
                        swing['label'] = 'LL'
                prev_low = swing['price']
    
    # =========================================================================
    #                         2. BOS (Break of Structure)
    # =========================================================================
    
    def find_bos(self):
        """
        إيجاد Break of Structure (BOS)
        
        BOS Bullish: كسر آخر قمة (HH) = استمرار الترند الصاعد
        BOS Bearish: كسر آخر قاع (LL) = استمرار الترند الهابط
        """
        self.bos_list = []
        
        closes = self.data['close'].values
        
        # نحتاج على الأقل swing واحد
        highs = [s for s in self.swings if s['type'] == 'high']
        lows = [s for s in self.swings if s['type'] == 'low']
        
        # BOS Bullish: كسر القمة السابقة
        for i, swing in enumerate(highs[:-1]):
            level = swing['price']
            start_bar = swing['bar_index']
            
            # ابحث عن إغلاق فوق هذا المستوى
            for bar in range(start_bar + 1, len(closes)):
                if closes[bar] > level:
                    # تأكد أن هذا ليس تكرار
                    if not any(b['level'] == level and b['type'] == 'BOS_BULL' for b in self.bos_list):
                        self.bos_list.append({
                            'type': 'BOS_BULL',
                            'level': float(level),
                            'break_bar': int(bar),
                            'break_time': str(self.data['time'].iloc[bar]),
                            'start_time': swing['time']
                        })
                    break
        
        # BOS Bearish: كسر القاع السابق
        for i, swing in enumerate(lows[:-1]):
            level = swing['price']
            start_bar = swing['bar_index']
            
            # ابحث عن إغلاق تحت هذا المستوى
            for bar in range(start_bar + 1, len(closes)):
                if closes[bar] < level:
                    if not any(b['level'] == level and b['type'] == 'BOS_BEAR' for b in self.bos_list):
                        self.bos_list.append({
                            'type': 'BOS_BEAR',
                            'level': float(level),
                            'break_bar': int(bar),
                            'break_time': str(self.data['time'].iloc[bar]),
                            'start_time': swing['time']
                        })
                    break
        
        print(f"✅ تم إيجاد {len(self.bos_list)} BOS")
        return self.bos_list
    
    # =========================================================================
    #                         3. CHoCH (Change of Character)
    # =========================================================================
    
    def find_choch(self):
        """
        إيجاد Change of Character (CHoCH)
        
        CHoCH = أول كسر يغير اتجاه السوق
        - في ترند صاعد: كسر آخر HL = CHoCH Bearish
        - في ترند هابط: كسر آخر LH = CHoCH Bullish
        """
        self.choch_list = []
        
        closes = self.data['close'].values
        
        # تحديد الترند
        is_bullish = False
        is_bearish = False
        
        last_hl = None  # آخر Higher Low (مهم للـ CHoCH Bearish)
        last_lh = None  # آخر Lower High (مهم للـ CHoCH Bullish)
        
        for swing in self.swings:
            # تحديث الترند بناءً على HH/LL
            if swing['label'] == 'HH':
                is_bullish = True
                is_bearish = False
            elif swing['label'] == 'LL':
                is_bearish = True
                is_bullish = False
            
            # تتبع آخر HL و LH
            if swing['label'] == 'HL':
                last_hl = swing
            elif swing['label'] == 'LH':
                last_lh = swing
            
            # CHoCH Bearish: في ترند صاعد، كسر آخر HL
            if is_bullish and last_hl and swing['label'] == 'LL':
                level = last_hl['price']
                start_bar = last_hl['bar_index']
                
                for bar in range(start_bar + 1, len(closes)):
                    if closes[bar] < level:
                        self.choch_list.append({
                            'type': 'CHOCH_BEAR',
                            'level': float(level),
                            'break_bar': int(bar),
                            'break_time': str(self.data['time'].iloc[bar]),
                            'start_time': last_hl['time']
                        })
                        is_bullish = False
                        is_bearish = True
                        break
            
            # CHoCH Bullish: في ترند هابط، كسر آخر LH
            if is_bearish and last_lh and swing['label'] == 'HH':
                level = last_lh['price']
                start_bar = last_lh['bar_index']
                
                for bar in range(start_bar + 1, len(closes)):
                    if closes[bar] > level:
                        self.choch_list.append({
                            'type': 'CHOCH_BULL',
                            'level': float(level),
                            'break_bar': int(bar),
                            'break_time': str(self.data['time'].iloc[bar]),
                            'start_time': last_lh['time']
                        })
                        is_bearish = False
                        is_bullish = True
                        break
        
        print(f"✅ تم إيجاد {len(self.choch_list)} CHoCH")
        return self.choch_list
    
    # =========================================================================
    #                         4. ORDER BLOCKS
    # =========================================================================
    
    def find_order_blocks(self):
        """
        إيجاد Order Blocks
        
        Bullish OB: آخر شمعة هابطة قبل حركة صاعدة قوية
        Bearish OB: آخر شمعة صاعدة قبل حركة هابطة قوية
        """
        self.order_blocks = []
        
        opens = self.data['open'].values
        closes = self.data['close'].values
        highs = self.data['high'].values
        lows = self.data['low'].values
        times = self.data['time'].values
        
        # ابحث عن OBs عند كل BOS و CHoCH
        all_breaks = self.bos_list + self.choch_list
        
        for brk in all_breaks:
            break_bar = brk['break_bar']
            
            # Bullish OB: ابحث عن آخر شمعة هابطة قبل الكسر الصاعد
            if 'BULL' in brk['type']:
                for i in range(break_bar - 1, max(0, break_bar - 10), -1):
                    if closes[i] < opens[i]:  # شمعة هابطة
                        self.order_blocks.append({
                            'type': 'OB_BULL',
                            'high': float(highs[i]),
                            'low': float(lows[i]),
                            'time': str(times[i]),
                            'bar_index': int(i)
                        })
                        break
            
            # Bearish OB: ابحث عن آخر شمعة صاعدة قبل الكسر الهابط
            elif 'BEAR' in brk['type']:
                for i in range(break_bar - 1, max(0, break_bar - 10), -1):
                    if closes[i] > opens[i]:  # شمعة صاعدة
                        self.order_blocks.append({
                            'type': 'OB_BEAR',
                            'high': float(highs[i]),
                            'low': float(lows[i]),
                            'time': str(times[i]),
                            'bar_index': int(i)
                        })
                        break
        
        print(f"✅ تم إيجاد {len(self.order_blocks)} Order Blocks")
        return self.order_blocks
    
    # =========================================================================
    #                         تصدير النتائج
    # =========================================================================
    
    def export_to_json(self, filepath="smc_signals.json"):
        """تصدير كل النتائج إلى ملف JSON"""
        
        result = {
            'symbol': self.symbol,
            'timeframe': self._timeframe_to_string(),
            'generated_at': datetime.now().isoformat(),
            'swings': self.swings,
            'bos': self.bos_list,
            'choch': self.choch_list,
            'order_blocks': self.order_blocks
        }
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, default=str)
        
        print(f"✅ تم حفظ النتائج في: {filepath}")
        return filepath
    
    def _timeframe_to_string(self):
        """تحويل الـ timeframe لنص"""
        tf_map = {
            mt5.TIMEFRAME_M1: 'M1',
            mt5.TIMEFRAME_M5: 'M5',
            mt5.TIMEFRAME_M15: 'M15',
            mt5.TIMEFRAME_M30: 'M30',
            mt5.TIMEFRAME_H1: 'H1',
            mt5.TIMEFRAME_H4: 'H4',
            mt5.TIMEFRAME_D1: 'D1',
        }
        return tf_map.get(self.timeframe, 'H1')
    
    # =========================================================================
    #                         تشغيل التحليل الكامل
    # =========================================================================
    
    def analyze(self, bars=500, swing_strength=3):
        """تشغيل التحليل الكامل"""
        
        print("="*60)
        print(f"   SMC Analysis: {self.symbol}")
        print("="*60)
        
        if not self.connect():
            return None
        
        if not self.get_data(bars):
            return None
        
        # 1. Swing Points
        print("\n📍 Finding Swing Points...")
        self.find_swing_points(swing_strength)
        
        # 2. BOS
        print("\n📈 Finding BOS...")
        self.find_bos()
        
        # 3. CHoCH
        print("\n🔄 Finding CHoCH...")
        self.find_choch()
        
        # 4. Order Blocks
        print("\n📦 Finding Order Blocks...")
        self.find_order_blocks()
        
        # تصدير
        print("\n💾 Exporting results...")
        filepath = self.export_to_json()
        
        # ملخص
        print("\n" + "="*60)
        print("   📊 Summary:")
        print(f"   - Swing Points: {len(self.swings)}")
        print(f"   - BOS: {len(self.bos_list)}")
        print(f"   - CHoCH: {len(self.choch_list)}")
        print(f"   - Order Blocks: {len(self.order_blocks)}")
        print("="*60)
        
        return filepath


# =============================================================================
#                         تشغيل مباشر
# =============================================================================

if __name__ == "__main__":
    analyzer = SMCAnalyzer(symbol="EURUSD", timeframe=mt5.TIMEFRAME_H1)
    analyzer.analyze(bars=500, swing_strength=3)
