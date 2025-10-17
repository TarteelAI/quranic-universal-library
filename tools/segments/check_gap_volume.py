#!/usr/bin/env python3
"""
Quick utility to check the volume level in gaps between ayahs.
"""

import sys
import json
from pathlib import Path

try:
    from pydub import AudioSegment
except ImportError:
    print("Error: pydub required. Install with: pip install pydub")
    sys.exit(1)

if len(sys.argv) < 3:
    print("Usage: python check_gap_volume.py <audio_file> <boundaries_file>")
    print("\nExample:")
    print("  python check_gap_volume.py audio.mp3 boundaries.json")
    sys.exit(1)

audio_file = sys.argv[1]
boundaries_file = sys.argv[2]

audio = AudioSegment.from_file(audio_file)
with open(boundaries_file) as f:
    boundaries = json.load(f)

print("=" * 80)
print("GAP VOLUME ANALYSIS")
print("=" * 80)

for i in range(len(boundaries) - 1):
    current = boundaries[i]
    next_ayah = boundaries[i + 1]
    
    current_end = current.get('end_time')
    next_start = next_ayah.get('start_time')
    
    gap_duration = next_start - current_end
    
    if gap_duration > 0:
        # Extract gap segment
        gap_segment = audio[current_end:next_start]
        gap_volume = gap_segment.dBFS
        
        print(f"\nGap {i+1}: Between Ayah {current.get('ayah', i+1)} and {next_ayah.get('ayah', i+2)}")
        print(f"  Position: {current_end}ms - {next_start}ms")
        print(f"  Duration: {gap_duration}ms")
        
        # Handle -inf case (complete silence)
        if gap_volume == float('-inf') or gap_volume < -80:
            print(f"  Volume: -inf dBFS (COMPLETE SILENCE!)")
            print(f"  🎉 This gap is completely silent!")
            print(f"  💡 Use any reasonable threshold (e.g., -40 to -60 dBFS)")
            print(f"      All thresholds will detect this gap")
            continue
        
        print(f"  Volume: {gap_volume:.1f} dBFS")
        
        # Suggest threshold
        suggested_threshold = int(gap_volume - 5)
        print(f"  💡 Suggested threshold: {suggested_threshold} dBFS (gap volume - 5dB)")
        
        # Check against common thresholds
        common_thresholds = [-30, -35, -40, -45, -50, -60, -68]
        for thresh in common_thresholds:
            if gap_volume < thresh:
                status = "✓ DETECTABLE"
                color = "green"
            else:
                status = "✗ NOT DETECTABLE"
                color = "red"
            print(f"      Threshold {thresh:3d} dBFS: {status}")
    else:
        print(f"\nGap {i+1}: No gap (boundaries touching or overlapping)")

print("\n" + "=" * 80)
print("\n💡 RECOMMENDATIONS:")
print("  1. Use a threshold BELOW the gap volumes shown above")
print("  2. Try: --threshold <suggested_value>")
print("  3. Or use relative threshold: --relative --percentile 5 --offset 3")
print("  4. If gaps are very short, reduce: --min-duration 30")
print("")

