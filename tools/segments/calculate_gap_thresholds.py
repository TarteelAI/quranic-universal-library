#!/usr/bin/env python3
"""
Calculate Per-Gap Relative Thresholds

Analyzes each gap between ayahs and calculates optimal threshold for each.
This allows detecting silences in gaps with varying volume levels.

Usage:
    python calculate_gap_thresholds.py audio.mp3 boundaries.json
    python calculate_gap_thresholds.py audio.mp3 boundaries.json --offset 5 -o thresholds.json
"""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Dict
import numpy as np

try:
    from pydub import AudioSegment
except ImportError:
    print("Error: pydub is required. Install with: pip install pydub")
    sys.exit(1)


class GapThresholdCalculator:
    """Calculates optimal threshold for each gap between ayahs."""
    
    def __init__(
        self,
        audio_path: str,
        boundaries: List[Dict],
        offset: float = 5.0,
        sample_interval: int = 50
    ):
        """
        Initialize the calculator.
        
        Args:
            audio_path: Path to audio file
            boundaries: List of ayah boundaries
            offset: dB offset below gap volume (default: 5.0)
            sample_interval: Interval for sampling gap volume in ms (default: 50)
        """
        self.audio_path = Path(audio_path)
        self.boundaries = sorted(boundaries, key=lambda x: x.get('start_time', 0))
        self.offset = offset
        self.sample_interval = sample_interval
        self.audio = None
        
        if not self.audio_path.exists():
            raise FileNotFoundError(f"Audio file not found: {audio_path}")
    
    def load_audio(self) -> None:
        """Load the audio file."""
        print(f"Loading audio: {self.audio_path}")
        try:
            self.audio = AudioSegment.from_file(str(self.audio_path))
            print(f"✓ Duration: {len(self.audio) / 1000:.2f}s")
        except Exception as e:
            raise RuntimeError(f"Failed to load audio: {e}")
    
    def analyze_gap_volume(self, start_ms: int, end_ms: int) -> Dict:
        """
        Analyze volume characteristics of a gap.
        
        Args:
            start_ms: Gap start time
            end_ms: Gap end time
            
        Returns:
            Dictionary with volume statistics
        """
        if self.audio is None:
            self.load_audio()
        
        gap_duration = end_ms - start_ms
        
        if gap_duration <= 0:
            return {
                'error': 'Invalid gap (no duration)',
                'mean': None,
                'min': None,
                'max': None,
                'percentile_10': None,
                'percentile_25': None
            }
        
        # Sample the gap at regular intervals
        volumes = []
        num_samples = max(1, gap_duration // self.sample_interval)
        
        for i in range(num_samples):
            sample_start = start_ms + (i * self.sample_interval)
            sample_end = min(sample_start + self.sample_interval, end_ms)
            
            if sample_end > sample_start:
                chunk = self.audio[sample_start:sample_end]
                db = chunk.dBFS
                if not np.isinf(db):
                    volumes.append(db)
        
        # Also get the entire gap volume
        gap_segment = self.audio[start_ms:end_ms]
        overall_volume = gap_segment.dBFS
        
        # Handle complete silence (-inf)
        if np.isinf(overall_volume):
            overall_volume = -80.0  # Treat as very quiet
        
        if not volumes:
            volumes = [overall_volume]
        
        volumes = np.array(volumes)
        # Filter out any -inf values that might have slipped through
        volumes = volumes[~np.isinf(volumes)]
        
        if len(volumes) == 0:
            # Gap is completely silent
            volumes = np.array([-80.0])
        
        return {
            'overall': float(overall_volume),
            'mean': float(np.mean(volumes)),
            'median': float(np.median(volumes)),
            'min': float(np.min(volumes)),
            'max': float(np.max(volumes)),
            'std_dev': float(np.std(volumes)),
            'percentile_10': float(np.percentile(volumes, 10)),
            'percentile_25': float(np.percentile(volumes, 25)),
            'percentile_50': float(np.percentile(volumes, 50)),
            'is_silent': bool(overall_volume <= -80.0 or np.isinf(gap_segment.dBFS))
        }
    
    def calculate_all_thresholds(self) -> List[Dict]:
        """
        Calculate optimal threshold for each gap.
        
        Returns:
            List of gap threshold configurations
        """
        print("\n" + "=" * 80)
        print("CALCULATING PER-GAP THRESHOLDS")
        print("=" * 80)
        print(f"Offset: -{self.offset} dB below gap volume\n")
        
        gap_configs = []
        
        for i in range(len(self.boundaries) - 1):
            current = self.boundaries[i]
            next_ayah = self.boundaries[i + 1]
            
            # Use corrected times if available, otherwise original
            current_end = current.get('corrected_end_time') or current.get('end_time')
            next_start = next_ayah.get('corrected_start_time') or next_ayah.get('start_time')
            
            current_ayah = current.get('ayah', i + 1)
            next_ayah_num = next_ayah.get('ayah', i + 2)
            
            gap_duration = next_start - current_end
            
            if gap_duration > 0:
                # Analyze gap volume
                vol_stats = self.analyze_gap_volume(current_end, next_start)
                
                # Calculate threshold based on different strategies
                # For truly silent gaps, use a conservative threshold
                if vol_stats.get('is_silent', False):
                    # Gap is completely silent, use conservative threshold
                    strategies = {
                        'overall': -60.0,
                        'mean': -60.0,
                        'median': -60.0,
                        'percentile_10': -60.0,
                        'percentile_25': -60.0
                    }
                    recommended_threshold = -60.0
                else:
                    strategies = {
                        'overall': vol_stats['overall'] - self.offset,
                        'mean': vol_stats['mean'] - self.offset,
                        'median': vol_stats['median'] - self.offset,
                        'percentile_10': vol_stats['percentile_10'] - self.offset,
                        'percentile_25': vol_stats['percentile_25'] - self.offset
                    }
                    
                    # Recommended: use the minimum (most sensitive)
                    recommended_threshold = max(strategies.values())
                
                gap_config = {
                    'gap_index': i + 1,
                    'from_ayah': current_ayah,
                    'to_ayah': next_ayah_num,
                    'gap_start': current_end,
                    'gap_end': next_start,
                    'gap_duration': gap_duration,
                    'volume_stats': vol_stats,
                    'threshold_strategies': strategies,
                    'recommended_threshold': recommended_threshold,
                    'threshold_method': 'min_of_strategies'
                }
                
                gap_configs.append(gap_config)
                
                print(f"Gap {i+1}: Ayah {current_ayah} → {next_ayah_num}")
                print(f"  Position: {current_end}ms - {next_start}ms ({gap_duration}ms)")
                
                # Check if gap is truly silent
                if vol_stats.get('is_silent', False) or vol_stats['overall'] <= -80:
                    print(f"  Volume: COMPLETE SILENCE (-inf or < -80 dBFS)")
                    print(f"  🎉 Perfect gap! Any threshold will detect this.")
                    print(f"  Recommended Threshold: -60.0 dBFS (conservative)")
                else:
                    print(f"  Volume: {vol_stats['overall']:.1f} dBFS (mean: {vol_stats['mean']:.1f})")
                    print(f"  Recommended Threshold: {recommended_threshold:.1f} dBFS")
                    print(f"  Strategies: overall={strategies['overall']:.1f}, " +
                          f"mean={strategies['mean']:.1f}, " +
                          f"p10={strategies['percentile_10']:.1f}")
            else:
                gap_config = {
                    'gap_index': i + 1,
                    'from_ayah': current_ayah,
                    'to_ayah': next_ayah_num,
                    'gap_start': current_end,
                    'gap_end': next_start,
                    'gap_duration': gap_duration,
                    'error': 'No gap or negative gap'
                }
                gap_configs.append(gap_config)
                print(f"Gap {i+1}: No gap (boundaries touching)")
        
        print(f"\n✓ Calculated thresholds for {len(gap_configs)} gaps")
        return gap_configs
    
    def print_summary(self, gap_configs: List[Dict]) -> None:
        """Print summary of calculated thresholds."""
        print("\n" + "=" * 80)
        print("THRESHOLD SUMMARY")
        print("=" * 80)
        
        valid_configs = [g for g in gap_configs if 'recommended_threshold' in g]
        
        if not valid_configs:
            print("No valid gaps found")
            return
        
        thresholds = [g['recommended_threshold'] for g in valid_configs]
        volumes = [g['volume_stats']['overall'] for g in valid_configs]
        
        print(f"\nGap Volume Range: {min(volumes):.1f} to {max(volumes):.1f} dBFS")
        print(f"Threshold Range: {min(thresholds):.1f} to {max(thresholds):.1f} dBFS")
        print(f"Average Threshold: {np.mean(thresholds):.1f} dBFS")
        print(f"Volume Variation: {np.std(volumes):.1f} dB std dev")
        
        print("\n💡 INSIGHTS:")
        
        volume_range = max(volumes) - min(volumes)
        if volume_range > 15:
            print(f"  • High volume variation ({volume_range:.1f} dB) across gaps")
            print("    → Per-gap thresholds are ESSENTIAL")
            print("    → A single threshold won't work well")
        elif volume_range > 8:
            print(f"  • Moderate volume variation ({volume_range:.1f} dB)")
            print("    → Per-gap thresholds recommended")
        else:
            print(f"  • Low volume variation ({volume_range:.1f} dB)")
            print("    → Single threshold might work")
            print(f"    → Try: --threshold {int(min(thresholds))}")
        
        # Check if gaps are actually silent
        loud_gaps = [g for g in valid_configs if g['volume_stats']['overall'] > -40]
        if loud_gaps:
            print(f"\n  ⚠️  {len(loud_gaps)} gap(s) have audible content (> -40 dBFS):")
            for g in loud_gaps[:3]:  # Show first 3
                print(f"    - Gap {g['gap_index']}: {g['volume_stats']['overall']:.1f} dBFS")
            if len(loud_gaps) > 3:
                print(f"    ... and {len(loud_gaps) - 3} more")
            print("    → These gaps contain reverb, breathing, or background noise")
            print("    → Current boundaries might already be optimal")


def load_boundaries(boundaries_path: str) -> List[Dict]:
    """Load boundaries from JSON file."""
    path = Path(boundaries_path)
    
    if not path.exists():
        raise FileNotFoundError(f"Boundaries file not found: {boundaries_path}")
    
    with open(path, 'r') as f:
        return json.load(f)


def main():
    parser = argparse.ArgumentParser(
        description='Calculate per-gap relative thresholds for silence detection',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic usage
  python calculate_gap_thresholds.py audio.mp3 boundaries.json
  
  # Custom offset
  python calculate_gap_thresholds.py audio.mp3 boundaries.json --offset 8
  
  # Save configuration
  python calculate_gap_thresholds.py audio.mp3 boundaries.json \
    --offset 5 \
    --output gap_thresholds.json
  
  # Then use with find_boundary_silences.py:
  python find_boundary_silences.py audio.mp3 boundaries.json \
    --gap-thresholds gap_thresholds.json
        """
    )
    
    parser.add_argument(
        'audio_file',
        help='Path to audio file'
    )
    
    parser.add_argument(
        'boundaries_file',
        help='Path to JSON file with ayah boundaries'
    )
    
    parser.add_argument(
        '--offset',
        type=float,
        default=5.0,
        help='dB offset below gap volume for threshold (default: 5.0)'
    )
    
    parser.add_argument(
        '--sample-interval',
        type=int,
        default=50,
        help='Sampling interval in ms for gap analysis (default: 50)'
    )
    
    parser.add_argument(
        '-o', '--output',
        help='Output JSON file for gap threshold configuration',
        default=None
    )
    
    args = parser.parse_args()
    
    try:
        # Load boundaries
        boundaries = load_boundaries(args.boundaries_file)
        
        print(f"✓ Loaded {len(boundaries)} boundaries")
        
        # Initialize calculator
        calculator = GapThresholdCalculator(
            audio_path=args.audio_file,
            boundaries=boundaries,
            offset=args.offset,
            sample_interval=args.sample_interval
        )
        
        # Calculate thresholds
        gap_configs = calculator.calculate_all_thresholds()
        
        # Print summary
        calculator.print_summary(gap_configs)
        
        # Save results
        if args.output:
            output_path = Path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            output_data = {
                'audio_file': str(calculator.audio_path),
                'boundaries_file': args.boundaries_file,
                'offset': args.offset,
                'gap_count': len(gap_configs),
                'gaps': gap_configs
            }
            
            with open(output_path, 'w') as f:
                json.dump(output_data, f, indent=2)

        print("\n✓ Analysis complete!")
        
    except Exception as e:
        print(f"\n✗ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

