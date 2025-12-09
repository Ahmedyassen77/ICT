"""
=============================================================================
    SMC Analyzer V2 - Smart Money Concepts
    Based on the reference indicator style
=============================================================================
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
import json
from datetime import datetime

class SMCAnalyzerV2:
    """
    SMC Analyzer - matches the reference indicator style
    Only draws SIGNIFICANT structure points
    """
    
    def __init__(self, symbol="EURUSD", timeframe=mt5.TIMEFRAME_H1):
        self.symbol = symbol
        self.timeframe = timeframe
        self.data = None
        self.swings = []
        self.structure_breaks = []  # BOS and CHoCH combined
        self.order_blocks = []
        
    def connect(self):
        if not mt5.initialize():
            print(f"[ERROR] Failed to connect to MT5: {mt5.last_error()}")
            return False
        print(f"[OK] Connected to MT5")
        return True
    
    def get_data(self, bars=500):
        rates = mt5.copy_rates_from_pos(self.symbol, self.timeframe, 0, bars)
        if rates is None:
            print(f"[ERROR] Failed to get data: {mt5.last_error()}")
            return False
            
        self.data = pd.DataFrame(rates)
        self.data['time'] = pd.to_datetime(self.data['time'], unit='s')
        print(f"[OK] Fetched {len(self.data)} bars")
        return True
    
    def find_swing_points(self, strength=5):
        """
        Find SIGNIFICANT swing points only
        Using higher strength for cleaner chart
        """
        self.swings = []
        
        highs = self.data['high'].values
        lows = self.data['low'].values
        times = self.data['time'].values
        
        for i in range(strength, len(self.data) - strength):
            # Swing High
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
                    'label': ''
                })
            
            # Swing Low
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
                    'label': ''
                })
        
        # Sort by time
        self.swings.sort(key=lambda x: x['bar_index'])
        
        # Classify swings
        self._classify_swings()
        
        # Filter - keep only labeled swings (HH, HL, LH, LL)
        self.swings = [s for s in self.swings if s['label'] in ['HH', 'HL', 'LH', 'LL']]
        
        print(f"[OK] Found {len(self.swings)} significant Swing Points")
        return self.swings
    
    def _classify_swings(self):
        """Classify swings as HH, HL, LH, LL"""
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
    
    def find_structure_breaks(self):
        """
        Find BOS and CHoCH
        - BOS: Break of Structure (continuation)
        - CHoCH: Change of Character (reversal)
        """
        self.structure_breaks = []
        
        closes = self.data['close'].values
        times = self.data['time'].values
        
        # Track trend
        trend = None  # 'bull' or 'bear'
        
        # Track important levels
        last_swing_high = None
        last_swing_low = None
        
        for i, swing in enumerate(self.swings):
            # BOS Bullish: HH breaks previous high in uptrend
            if swing['label'] == 'HH' and last_swing_high:
                level = last_swing_high['price']
                
                # Find break point
                for bar in range(last_swing_high['bar_index'] + 1, swing['bar_index'] + 1):
                    if bar < len(closes) and closes[bar] > level:
                        break_type = 'CHoCH' if trend == 'bear' else 'BOS'
                        
                        self.structure_breaks.append({
                            'type': f'{break_type}_BULL',
                            'level': float(level),
                            'start_time': last_swing_high['time'],
                            'break_time': str(times[bar]),
                            'break_bar': int(bar)
                        })
                        trend = 'bull'
                        break
            
            # BOS Bearish: LL breaks previous low in downtrend  
            if swing['label'] == 'LL' and last_swing_low:
                level = last_swing_low['price']
                
                for bar in range(last_swing_low['bar_index'] + 1, swing['bar_index'] + 1):
                    if bar < len(closes) and closes[bar] < level:
                        break_type = 'CHoCH' if trend == 'bull' else 'BOS'
                        
                        self.structure_breaks.append({
                            'type': f'{break_type}_BEAR',
                            'level': float(level),
                            'start_time': last_swing_low['time'],
                            'break_time': str(times[bar]),
                            'break_bar': int(bar)
                        })
                        trend = 'bear'
                        break
            
            # Update last swings
            if swing['type'] == 'high':
                last_swing_high = swing
            else:
                last_swing_low = swing
        
        # Remove duplicates
        seen = set()
        unique_breaks = []
        for brk in self.structure_breaks:
            key = (brk['type'], brk['level'])
            if key not in seen:
                seen.add(key)
                unique_breaks.append(brk)
        
        self.structure_breaks = unique_breaks
        
        bos_count = len([b for b in self.structure_breaks if 'BOS' in b['type']])
        choch_count = len([b for b in self.structure_breaks if 'CHoCH' in b['type']])
        
        print(f"[OK] Found {bos_count} BOS, {choch_count} CHoCH")
        return self.structure_breaks
    
    def find_order_blocks(self):
        """
        Find Order Blocks at structure breaks only
        - Bullish OB: Last bearish candle before bullish break
        - Bearish OB: Last bullish candle before bearish break
        """
        self.order_blocks = []
        
        opens = self.data['open'].values
        closes = self.data['close'].values
        highs = self.data['high'].values
        lows = self.data['low'].values
        times = self.data['time'].values
        
        for brk in self.structure_breaks:
            break_bar = brk['break_bar']
            
            # Bullish OB
            if 'BULL' in brk['type']:
                # Find last bearish candle before break
                for i in range(break_bar - 1, max(0, break_bar - 5), -1):
                    if closes[i] < opens[i]:  # Bearish candle
                        self.order_blocks.append({
                            'type': 'OB_BULL',
                            'high': float(highs[i]),
                            'low': float(lows[i]),
                            'time': str(times[i]),
                            'bar_index': int(i),
                            'mitigated': False
                        })
                        break
            
            # Bearish OB
            elif 'BEAR' in brk['type']:
                for i in range(break_bar - 1, max(0, break_bar - 5), -1):
                    if closes[i] > opens[i]:  # Bullish candle
                        self.order_blocks.append({
                            'type': 'OB_BEAR',
                            'high': float(highs[i]),
                            'low': float(lows[i]),
                            'time': str(times[i]),
                            'bar_index': int(i),
                            'mitigated': False
                        })
                        break
        
        print(f"[OK] Found {len(self.order_blocks)} Order Blocks")
        return self.order_blocks
    
    def export_to_json(self, filepath="smc_signals.json"):
        """Export results to JSON"""
        
        # Separate BOS and CHoCH for the EA
        bos_list = [b for b in self.structure_breaks if 'BOS' in b['type']]
        choch_list = [b for b in self.structure_breaks if 'CHoCH' in b['type']]
        
        result = {
            'symbol': self.symbol,
            'timeframe': self._timeframe_to_string(),
            'generated_at': datetime.now().isoformat(),
            'swings': self.swings,
            'bos': bos_list,
            'choch': choch_list,
            'order_blocks': self.order_blocks
        }
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, default=str)
        
        print(f"[OK] Results saved to: {filepath}")
        return filepath
    
    def _timeframe_to_string(self):
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
    
    def analyze(self, bars=500, swing_strength=5):
        """Run full analysis"""
        
        print("="*60)
        print(f"   SMC Analysis V2: {self.symbol}")
        print("="*60)
        
        if not self.connect():
            return None
        
        if not self.get_data(bars):
            return None
        
        print("\n[1] Finding Swing Points...")
        self.find_swing_points(swing_strength)
        
        print("\n[2] Finding BOS & CHoCH...")
        self.find_structure_breaks()
        
        print("\n[3] Finding Order Blocks...")
        self.find_order_blocks()
        
        print("\n[4] Exporting results...")
        filepath = self.export_to_json()
        
        # Summary
        print("\n" + "="*60)
        print("   Summary:")
        print(f"   - Swing Points: {len(self.swings)}")
        print(f"   - BOS: {len([b for b in self.structure_breaks if 'BOS' in b['type']])}")
        print(f"   - CHoCH: {len([b for b in self.structure_breaks if 'CHoCH' in b['type']])}")
        print(f"   - Order Blocks: {len(self.order_blocks)}")
        print("="*60)
        
        return filepath


if __name__ == "__main__":
    analyzer = SMCAnalyzerV2(symbol="EURUSD", timeframe=mt5.TIMEFRAME_H1)
    analyzer.analyze(bars=500, swing_strength=5)
