"""
=============================================================================
    SMC Analyzer V3 - Smart Money Concepts
    Matches the reference indicator style EXACTLY
    - Extended BOS/CHoCH lines
    - Clean Order Blocks
    - Minimal swing labels
=============================================================================
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
import json
from datetime import datetime
import os
import shutil

class SMCAnalyzerV3:
    """
    SMC Analyzer V3 - Cleaner output matching reference indicator
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
        Find swing points using fractal method
        Only keep significant structure points
        """
        self.swings = []
        
        highs = self.data['high'].values
        lows = self.data['low'].values
        times = self.data['time'].values
        
        swing_highs = []
        swing_lows = []
        
        # Find all swing highs and lows
        for i in range(strength, len(self.data) - strength):
            # Swing High
            is_high = all(highs[i] > highs[i-j] for j in range(1, strength+1)) and \
                      all(highs[i] > highs[i+j] for j in range(1, strength+1))
            
            if is_high:
                swing_highs.append({
                    'price': float(highs[i]),
                    'time': times[i],
                    'bar_index': i
                })
            
            # Swing Low  
            is_low = all(lows[i] < lows[i-j] for j in range(1, strength+1)) and \
                     all(lows[i] < lows[i+j] for j in range(1, strength+1))
            
            if is_low:
                swing_lows.append({
                    'price': float(lows[i]),
                    'time': times[i],
                    'bar_index': i
                })
        
        # Classify swing highs as HH or LH
        prev_high_price = None
        for sh in swing_highs:
            if prev_high_price is not None:
                label = 'HH' if sh['price'] > prev_high_price else 'LH'
                self.swings.append({
                    'type': 'high',
                    'label': label,
                    'price': sh['price'],
                    'time': str(sh['time']),
                    'bar_index': sh['bar_index']
                })
            prev_high_price = sh['price']
        
        # Classify swing lows as HL or LL
        prev_low_price = None
        for sl in swing_lows:
            if prev_low_price is not None:
                label = 'HL' if sl['price'] > prev_low_price else 'LL'
                self.swings.append({
                    'type': 'low',
                    'label': label,
                    'price': sl['price'],
                    'time': str(sl['time']),
                    'bar_index': sl['bar_index']
                })
            prev_low_price = sl['price']
        
        # Sort by bar index
        self.swings.sort(key=lambda x: x['bar_index'])
        
        print(f"[OK] Found {len(self.swings)} Swing Points")
        return self.swings
    
    def find_bos_choch(self):
        """
        Find BOS and CHoCH
        BOS = Break Of Structure (continuation)
        CHoCH = Change Of Character (reversal)
        
        Reference indicator style:
        - BOS: price breaks previous swing in trend direction
        - CHoCH: price breaks previous swing against trend (reversal)
        """
        self.bos_list = []
        self.choch_list = []
        
        closes = self.data['close'].values
        times = self.data['time'].values
        
        # Track current trend
        trend = None  # 'bull' or 'bear'
        
        # Track last significant levels
        last_hh = None
        last_ll = None
        last_hl = None
        last_lh = None
        
        for swing in self.swings:
            bar_idx = swing['bar_index']
            
            if swing['label'] == 'HH':
                # Check if this breaks previous resistance
                if last_lh is not None and swing['price'] > last_lh['price']:
                    # Breaking LH after downtrend = CHoCH
                    if trend == 'bear':
                        self.choch_list.append({
                            'type': 'BULL',
                            'level': last_lh['price'],
                            'start_time': last_lh['time'],
                            'start_bar': last_lh['bar_index'],
                            'break_time': str(times[bar_idx]),
                            'break_bar': bar_idx
                        })
                        trend = 'bull'
                    elif trend == 'bull':
                        # BOS in uptrend
                        self.bos_list.append({
                            'type': 'BULL',
                            'level': last_hh['price'] if last_hh else last_lh['price'],
                            'start_time': (last_hh or last_lh)['time'],
                            'start_bar': (last_hh or last_lh)['bar_index'],
                            'break_time': str(times[bar_idx]),
                            'break_bar': bar_idx
                        })
                    else:
                        trend = 'bull'
                
                last_hh = swing
                
            elif swing['label'] == 'LL':
                # Check if this breaks previous support
                if last_hl is not None and swing['price'] < last_hl['price']:
                    # Breaking HL after uptrend = CHoCH
                    if trend == 'bull':
                        self.choch_list.append({
                            'type': 'BEAR',
                            'level': last_hl['price'],
                            'start_time': last_hl['time'],
                            'start_bar': last_hl['bar_index'],
                            'break_time': str(times[bar_idx]),
                            'break_bar': bar_idx
                        })
                        trend = 'bear'
                    elif trend == 'bear':
                        # BOS in downtrend
                        self.bos_list.append({
                            'type': 'BEAR',
                            'level': last_ll['price'] if last_ll else last_hl['price'],
                            'start_time': (last_ll or last_hl)['time'],
                            'start_bar': (last_ll or last_hl)['bar_index'],
                            'break_time': str(times[bar_idx]),
                            'break_bar': bar_idx
                        })
                    else:
                        trend = 'bear'
                
                last_ll = swing
                
            elif swing['label'] == 'HL':
                last_hl = swing
                
            elif swing['label'] == 'LH':
                last_lh = swing
        
        print(f"[OK] Found {len(self.bos_list)} BOS, {len(self.choch_list)} CHoCH")
        return self.bos_list, self.choch_list
    
    def find_order_blocks(self, max_ob=20):
        """
        Find Order Blocks at BOS and CHoCH points
        Keep only recent and significant ones
        """
        self.order_blocks = []
        
        opens = self.data['open'].values
        closes = self.data['close'].values
        highs = self.data['high'].values
        lows = self.data['low'].values
        times = self.data['time'].values
        
        # Combine BOS and CHoCH for OB detection
        all_breaks = []
        for bos in self.bos_list:
            all_breaks.append(('BOS', bos))
        for choch in self.choch_list:
            all_breaks.append(('CHoCH', choch))
        
        for break_type, brk in all_breaks:
            break_bar = brk['break_bar']
            
            if 'BULL' in brk['type']:
                # Bullish OB: Last bearish candle before break
                for i in range(break_bar - 1, max(0, break_bar - 10), -1):
                    if closes[i] < opens[i]:  # Bearish candle
                        self.order_blocks.append({
                            'type': 'BULL',
                            'high': float(highs[i]),
                            'low': float(lows[i]),
                            'open': float(opens[i]),
                            'close': float(closes[i]),
                            'time': str(times[i]),
                            'bar_index': int(i),
                            'source': break_type
                        })
                        break
            else:
                # Bearish OB: Last bullish candle before break
                for i in range(break_bar - 1, max(0, break_bar - 10), -1):
                    if closes[i] > opens[i]:  # Bullish candle
                        self.order_blocks.append({
                            'type': 'BEAR',
                            'high': float(highs[i]),
                            'low': float(lows[i]),
                            'open': float(opens[i]),
                            'close': float(closes[i]),
                            'time': str(times[i]),
                            'bar_index': int(i),
                            'source': break_type
                        })
                        break
        
        # Keep only unique OBs (remove duplicates by bar_index)
        seen_bars = set()
        unique_obs = []
        for ob in self.order_blocks:
            if ob['bar_index'] not in seen_bars:
                seen_bars.add(ob['bar_index'])
                unique_obs.append(ob)
        
        # Keep only most recent
        unique_obs.sort(key=lambda x: x['bar_index'], reverse=True)
        self.order_blocks = unique_obs[:max_ob]
        
        print(f"[OK] Found {len(self.order_blocks)} Order Blocks")
        return self.order_blocks
    
    def export_to_json(self, filepath="smc_signals_v3.json"):
        """Export results to JSON for EA"""
        
        result = {
            'symbol': self.symbol,
            'timeframe': self._timeframe_to_string(),
            'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'swings': self.swings,
            'bos': self.bos_list,
            'choch': self.choch_list,
            'order_blocks': self.order_blocks,
            'config': {
                'bos_color': 'clrDodgerBlue',
                'choch_color': 'clrMagenta', 
                'ob_bull_color': 'clrDodgerBlue',
                'ob_bear_color': 'clrCrimson',
                'line_style': 'STYLE_SOLID',
                'extend_lines': True
            }
        }
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, default=str)
        
        print(f"[OK] Saved to: {filepath}")
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
        """Run complete analysis"""
        
        print("="*60)
        print(f"   SMC Analyzer V3: {self.symbol}")
        print("   Reference Indicator Style")
        print("="*60)
        
        if not self.connect():
            return None
        
        if not self.get_data(bars):
            return None
        
        print("\n[1] Finding Swing Points...")
        self.find_swing_points(swing_strength)
        
        print("\n[2] Finding BOS & CHoCH...")
        self.find_bos_choch()
        
        print("\n[3] Finding Order Blocks...")
        self.find_order_blocks()
        
        print("\n[4] Exporting results...")
        filepath = self.export_to_json()
        
        # Copy to MT5 Files folder
        mt5_files_path = r"C:\Users\a\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E\MQL5\Files"
        if os.path.exists(mt5_files_path):
            dest = os.path.join(mt5_files_path, "smc_signals_v3.json")
            shutil.copy(filepath, dest)
            print(f"[OK] Copied to: {dest}")
        
        # Summary
        print("\n" + "="*60)
        print("   Summary V3:")
        print(f"   - Swing Points: {len(self.swings)}")
        print(f"   - BOS: {len(self.bos_list)}")
        print(f"   - CHoCH: {len(self.choch_list)}")
        print(f"   - Order Blocks: {len(self.order_blocks)}")
        print("="*60)
        
        mt5.shutdown()
        return filepath


if __name__ == "__main__":
    analyzer = SMCAnalyzerV3(symbol="EURUSD", timeframe=mt5.TIMEFRAME_H1)
    analyzer.analyze(bars=500, swing_strength=5)
