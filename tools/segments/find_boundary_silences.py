#!/usr/bin/env python3
"""
Boundary-Focused Silence Detection

Finds silences specifically around ayah boundaries.

Usage:
    python find_boundary_silences.py audio.mp3 boundaries.json
    python find_boundary_silences.py audio.mp3 boundaries.json --window 1000 --threshold -40
    python find_boundary_silences.py audio.mp3 boundaries.json --visualize --output result.json
"""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Dict, Tuple
import numpy as np

try:
    from pydub import AudioSegment
    from pydub.silence import detect_silence
except ImportError:
    print("Error: pydub is required. Install with: pip install pydub")
    sys.exit(1)

try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as patches
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False


class BoundarySilenceDetector:
    """Detects silences around ayah boundaries."""
    
    def __init__(
        self,
        audio_path: str,
        boundaries: List[Dict],
        threshold: float = -40,
        min_duration: int = 50,
        window_before: int = 500,
        window_after: int = 500,
        use_relative: bool = False,
        percentile: float = 10,
        offset: float = 5,
        gap_thresholds: Dict = None
    ):
        """
        Initialize the boundary silence detector.
        
        Args:
            audio_path: Path to audio file
            boundaries: List of ayah boundaries with start_time and end_time
            threshold: Silence threshold in dBFS (or base for relative)
            min_duration: Minimum silence duration in ms
            window_before: How many ms before boundary to search (default: 500)
            window_after: How many ms after boundary to search (default: 500)
            use_relative: Use relative threshold based on segment volume
            percentile: Percentile for relative threshold
            offset: Offset for relative threshold
            gap_thresholds: Optional dict with per-gap thresholds from calculate_gap_thresholds.py
        """
        self.audio_path = Path(audio_path)
        self.boundaries = sorted(boundaries, key=lambda x: x.get('start_time', 0))
        self.threshold = threshold
        self.min_duration = min_duration
        self.window_before = window_before
        self.window_after = window_after
        self.use_relative = use_relative
        self.percentile = percentile
        self.offset = offset
        self.gap_thresholds = gap_thresholds
        self.audio = None
        self.duration_ms = 0
        
        if not self.audio_path.exists():
            raise FileNotFoundError(f"Audio file not found: {audio_path}")
    
    def load_audio(self) -> None:
        """Load the audio file."""
        print(f"Loading audio: {self.audio_path}")
        try:
            self.audio = AudioSegment.from_file(str(self.audio_path))
            self.duration_ms = len(self.audio)
            print(f"✓ Duration: {self.duration_ms / 1000:.2f}s")
        except Exception as e:
            raise RuntimeError(f"Failed to load audio: {e}")
    
    def calculate_relative_threshold(self, segment: AudioSegment) -> float:
        """Calculate relative threshold for a segment."""
        window_size = 100  # ms
        segment_duration = len(segment)
        volumes = []
        
        num_samples = max(1, segment_duration // window_size)
        for i in range(num_samples):
            start = i * window_size
            end = min(start + window_size, segment_duration)
            if end > start:
                chunk = segment[start:end]
                db = chunk.dBFS
                if not np.isinf(db):
                    volumes.append(db)
        
        if volumes:
            threshold_base = np.percentile(volumes, self.percentile)
            return threshold_base - self.offset
        
        return self.threshold
    
    def get_gap_specific_threshold(self, ayah_index: int, is_before: bool = True) -> float:
        """
        Get threshold for a specific gap using gap_thresholds config.
        
        Args:
            ayah_index: Index of current ayah
            is_before: True if analyzing gap before this ayah, False for gap after
            
        Returns:
            Threshold to use for this gap
        """
        if not self.gap_thresholds or 'gaps' not in self.gap_thresholds:
            return self.threshold
        
        # Determine which gap we're analyzing
        if is_before:
            # Gap before this ayah is gap_index = ayah_index
            gap_index = ayah_index
        else:
            # Gap after this ayah is gap_index = ayah_index + 1
            gap_index = ayah_index + 1
        
        # Find the gap configuration
        gaps = self.gap_thresholds['gaps']
        for gap in gaps:
            if gap.get('gap_index') == gap_index:
                threshold = gap.get('recommended_threshold', self.threshold)
                return threshold
        
        return self.threshold
    
    def find_silences_around_boundary(
        self,
        ayah_index: int,
        boundary: Dict
    ) -> Dict:
        """
        Find silences around a single ayah boundary.
        
        Args:
            ayah_index: Index of the ayah
            boundary: Boundary dictionary with start_time and end_time
            
        Returns:
            Dictionary with boundary info and detected silences
        """
        if self.audio is None:
            self.load_audio()
        
        start_time = boundary.get('start_time', 0)
        end_time = boundary.get('end_time', 0)
        ayah_number = boundary.get('ayah', ayah_index + 1)
        
        # Determine search window
        # For first ayah, check before start
        # For others, check gap between previous end and current start
        
        if ayah_index == 0:
            # First ayah - check window before start
            search_start = max(0, start_time - self.window_before)
            search_end = start_time
        else:
            # Get previous ayah end time
            prev_boundary = self.boundaries[ayah_index - 1]
            prev_end = prev_boundary.get('end_time', 0)
            
            # Search from previous end to current start (the gap)
            # Plus some buffer
            search_start = max(0, prev_end - self.window_before)
            search_end = min(start_time + self.window_after, self.duration_ms)
        
        # Also check gap after this ayah if not last
        if ayah_index < len(self.boundaries) - 1:
            next_boundary = self.boundaries[ayah_index + 1]
            next_start = next_boundary.get('start_time', 0)
            
            # Extend search to include gap after
            after_search_start = max(0, end_time - self.window_before)
            after_search_end = min(next_start + self.window_after, self.duration_ms)
        else:
            # Last ayah - check after end
            after_search_start = end_time
            after_search_end = min(end_time + self.window_after, self.duration_ms)
        
        # Extract segments and detect silences
        silences_before = []
        silences_after = []
        
        # Detect in "before" region
        if search_end > search_start:
            segment_before = self.audio[search_start:search_end]
            
            # Calculate threshold - use gap-specific if available
            if self.gap_thresholds:
                actual_threshold = self.get_gap_specific_threshold(ayah_index, is_before=True)
            elif self.use_relative:
                actual_threshold = self.calculate_relative_threshold(segment_before)
            else:
                actual_threshold = self.threshold
            
            silence_ranges = detect_silence(
                segment_before,
                min_silence_len=self.min_duration,
                silence_thresh=actual_threshold,
                seek_step=1
            )
            
            for start_ms, end_ms in silence_ranges:
                # Convert to absolute time
                abs_start = search_start + start_ms
                abs_end = search_start + end_ms
                silences_before.append({
                    'start_time': abs_start,
                    'end_time': abs_end,
                    'duration': abs_end - abs_start
                })
        
        # Detect in "after" region
        if after_search_end > after_search_start:
            segment_after = self.audio[after_search_start:after_search_end]
            
            # Calculate threshold - use gap-specific if available
            if self.gap_thresholds:
                actual_threshold = self.get_gap_specific_threshold(ayah_index, is_before=False)
            elif self.use_relative:
                actual_threshold = self.calculate_relative_threshold(segment_after)
            else:
                actual_threshold = self.threshold
            
            silence_ranges = detect_silence(
                segment_after,
                min_silence_len=self.min_duration,
                silence_thresh=actual_threshold,
                seek_step=1
            )
            
            for start_ms, end_ms in silence_ranges:
                # Convert to absolute time
                abs_start = after_search_start + start_ms
                abs_end = after_search_start + end_ms
                
                # Avoid duplicates
                is_duplicate = False
                for sil in silences_before:
                    if abs(sil['start_time'] - abs_start) < 10:  # Within 10ms
                        is_duplicate = True
                        break
                
                if not is_duplicate:
                    silences_after.append({
                        'start_time': abs_start,
                        'end_time': abs_end,
                        'duration': abs_end - abs_start
                    })
        
        # Combine all silences
        all_silences = silences_before + silences_after
        all_silences.sort(key=lambda x: x['start_time'])
        
        # Classify silences relative to boundary
        classified_silences = []
        for silence in all_silences:
            sil_center = (silence['start_time'] + silence['end_time']) / 2
            
            if sil_center < start_time:
                position = 'before_start'
                distance = start_time - silence['end_time']
            elif sil_center > end_time:
                position = 'after_end'
                distance = silence['start_time'] - end_time
            else:
                position = 'overlapping'
                distance = 0
            
            classified_silences.append({
                **silence,
                'position': position,
                'distance_to_boundary': distance
            })
        
        return {
            'ayah': ayah_number,
            'start_time': start_time,
            'end_time': end_time,
            'silences': classified_silences,
            'silence_count': len(classified_silences),
            'search_window': {
                'before': {'start': search_start, 'end': search_end},
                'after': {'start': after_search_start, 'end': after_search_end}
            }
        }
    
    def detect_all_boundary_silences(self) -> List[Dict]:
        """
        Detect silences around all ayah boundaries.
        
        Returns:
            List of results for each boundary
        """
        print(f"\nDetecting silences around {len(self.boundaries)} boundaries...")
        
        if self.gap_thresholds:
            print(f"  Using per-gap thresholds (from gap threshold config)")
        else:
            print(f"  Threshold: {self.threshold} dBFS {'(relative)' if self.use_relative else '(absolute)'}")
        
        print(f"  Min Duration: {self.min_duration}ms")
        print(f"  Search Window: {self.window_before}ms before, {self.window_after}ms after")
        
        results = []
        
        for i, boundary in enumerate(self.boundaries):
            result = self.find_silences_around_boundary(i, boundary)
            results.append(result)
            
            ayah = result['ayah']
            count = result['silence_count']
            print(f"  Ayah {ayah}: {count} silence(s) found")
        
        total_silences = sum(r['silence_count'] for r in results)
        print(f"\n✓ Total: {total_silences} silences detected around boundaries")
        
        return results
    
    def visualize_results(
        self,
        results: List[Dict],
        output_path: str = None
    ) -> None:
        """
        Visualize boundaries and detected silences.
        
        Args:
            results: Detection results
            output_path: Optional path to save plot
        """
        if not HAS_MATPLOTLIB:
            print("⚠️  Visualization requires matplotlib")
            return
        
        print("\nGenerating visualization...")
        
        # Calculate figure size
        min_width = 16
        num_ayahs = len(results)
        duration_seconds = self.duration_ms / 1000
        ayah_scaling = max(0, (num_ayahs - 10) // 40) * 2
        duration_scaling = max(0, (duration_seconds - 60) // 60) * 1
        dynamic_width = min_width + ayah_scaling + duration_scaling
        dynamic_width = min(dynamic_width, 50)
        
        print(f"  Plot size: {dynamic_width:.0f} x 8 inches ({num_ayahs} ayahs, {duration_seconds:.0f}s)")
        
        # Sample volume
        sample_interval = 100  # ms
        times = []
        volumes = []
        num_samples = self.duration_ms // sample_interval
        
        for i in range(num_samples):
            start = i * sample_interval
            end = min(start + sample_interval, self.duration_ms)
            chunk = self.audio[start:end]
            db = chunk.dBFS
            times.append(start / 1000)
            volumes.append(db if not np.isinf(db) else -60)
        
        # Create plot (width calculated above)
        fig, ax = plt.subplots(figsize=(dynamic_width, 8))
        
        # Plot volume
        ax.plot(times, volumes, linewidth=0.8, alpha=0.6, color='#2196F3', label='Volume')
        
        # Plot ayah boundaries
        colors = [
          '#FF5722', # deep orange
          '#4CAF50', # green
          '#9C27B0', # purple
          '#FF9800', # orange
          '#00BCD4', # cyan
          '#E91E63', # bold pink/magenta
          '#2196F3', # vivid blue
          '#F44336', # bold red
          '#CDDC39', # lime/yellow-green
          '#3F51B5'  # indigo/deep blue
        ]

        for i, result in enumerate(results):
            ayah = result['ayah']
            start_sec = result['start_time'] / 1000
            end_sec = result['end_time'] / 1000
            color = colors[i % len(colors)]
            
            # Ayah region
            ax.axvspan(start_sec, end_sec, alpha=0.1, color=color,
                      label=f'Ayah {ayah}' if i < 7 else '')
            
            # Boundary lines
            ax.axvline(x=start_sec, color=color, linestyle='--', linewidth=1.5, alpha=0.7)
            ax.axvline(x=end_sec, color=color, linestyle='--', linewidth=1.5, alpha=0.7)
            
            # Plot detected silences
            for silence in result['silences']:
                sil_start = silence['start_time'] / 1000
                sil_end = silence['end_time'] / 1000
                ax.axvspan(sil_start, sil_end, alpha=0.4, color='#00FF00',
                          edgecolor='#FFFF00', linewidth=2,
                          label='Detected Silence' if i == 0 and silence == result['silences'][0] else '')
        
        # Formatting
        ax.set_xlabel('Time (seconds)', fontsize=12, fontweight='bold')
        ax.set_ylabel('Volume (dBFS)', fontsize=12, fontweight='bold')
        ax.set_title('Ayah Boundaries with Detected Silences', 
                    fontsize=14, fontweight='bold', pad=20)
        ax.grid(True, alpha=0.3, linestyle=':', linewidth=0.5)
        ax.legend(loc='upper right', framealpha=0.9, ncol=2)
        
        # Set y-axis limits
        valid_volumes = [v for v in volumes if v > -60]
        if valid_volumes:
            y_min = min(valid_volumes) - 5
            y_max = max(valid_volumes) + 5
            ax.set_ylim([y_min, y_max])
        
        plt.tight_layout()
        
        if output_path:
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            print(f"✓ Visualization saved: {output_path}")
        else:
            plt.show()
        
        plt.close()
    
    def diagnose_gaps(self, results: List[Dict]) -> None:
        """Diagnose why silences might not be detected in gaps."""
        print("\n" + "=" * 80)
        print("GAP DIAGNOSTICS")
        print("=" * 80)
        
        for i, result in enumerate(results[:-1]):
            next_result = results[i + 1]
            gap_start = result['end_time']
            gap_end = next_result['start_time']
            gap_duration = gap_end - gap_start
            
            if gap_duration > 0:
                # Analyze the gap segment
                gap_segment = self.audio[gap_start:gap_end]
                gap_volume = gap_segment.dBFS if not np.isinf(gap_segment.dBFS) else -60
                
                print(f"\nGap between Ayah {result['ayah']} and {next_result['ayah']}:")
                print(f"  Position: {gap_start}ms - {gap_end}ms")
                print(f"  Duration: {gap_duration}ms")
                print(f"  Volume: {gap_volume:.1f} dBFS")
                print(f"  Threshold: {self.threshold:.1f} dBFS")
                
                if gap_volume > self.threshold:
                    print(f"  ⚠️  Gap is ABOVE threshold by {gap_volume - self.threshold:.1f} dB")
                    print(f"      → Try lower threshold: --threshold {int(gap_volume - 5)}")
                else:
                    print(f"  ✓ Gap is below threshold")
                    if gap_duration < self.min_duration:
                        print(f"  ⚠️  But gap duration ({gap_duration}ms) < min_duration ({self.min_duration}ms)")
                        print(f"      → Try: --min-duration {max(20, gap_duration - 10)}")
    
    def print_summary(self, results: List[Dict]) -> None:
        """Print detailed summary of results."""
        print("\n" + "=" * 80)
        print("DETECTION SUMMARY")
        print("=" * 80)
        
        for result in results:
            ayah = result['ayah']
            silences = result['silences']
            
            print(f"\nAyah {ayah}:")
            print(f"  Boundary: {result['start_time']}ms - {result['end_time']}ms")
            print(f"  Silences found: {len(silences)}")
            
            if silences:
                # Group by position
                before = [s for s in silences if s['position'] == 'before_start']
                after = [s for s in silences if s['position'] == 'after_end']
                overlapping = [s for s in silences if s['position'] == 'overlapping']
                
                if before:
                    print(f"    Before start: {len(before)}")
                    for s in before:
                        print(f"      {s['start_time']:6d}ms - {s['end_time']:6d}ms "
                              f"(duration: {s['duration']:4d}ms, distance: {s['distance_to_boundary']:4.0f}ms)")
                
                if overlapping:
                    print(f"    Overlapping: {len(overlapping)}")
                    for s in overlapping:
                        print(f"      {s['start_time']:6d}ms - {s['end_time']:6d}ms "
                              f"(duration: {s['duration']:4d}ms)")
                
                if after:
                    print(f"    After end: {len(after)}")
                    for s in after:
                        print(f"      {s['start_time']:6d}ms - {s['end_time']:6d}ms "
                              f"(duration: {s['duration']:4d}ms, distance: {s['distance_to_boundary']:4.0f}ms)")
            else:
                print("    No silences detected in search window")


def load_boundaries(boundaries_path: str) -> List[Dict]:
    """
    Load ayah boundaries from JSON file.
    
    Args:
        boundaries_path: Path to JSON file

    Returns:
        List of boundary dictionaries
    """
    path = Path(boundaries_path)
    
    if not path.exists():
        raise FileNotFoundError(f"Boundaries file not found: {boundaries_path}")
    
    with open(path, 'r') as f:
        data = json.load(f)
    
    # Handle different formats
    if isinstance(data, list):
        boundaries = data
    elif isinstance(data, dict) and 'boundaries' in data:
        boundaries = data['boundaries']
    elif isinstance(data, dict) and 'ayahs' in data:
        boundaries = data['ayahs']
    else:
        raise ValueError("Unknown boundaries format. Expected list or dict with 'boundaries'/'ayahs' key")
    
    # Process boundaries - prefer corrected times if available and requested
    processed_boundaries = []
    has_corrected = False
    
    for i, b in enumerate(boundaries):
        # Check if boundary has corrected times
        has_corrected_start = 'corrected_start_time' in b and b['corrected_start_time'] is not None
        has_corrected_end = 'corrected_end_time' in b and b['corrected_end_time'] is not None
        
        if has_corrected_start or has_corrected_end:
            has_corrected = True
        
        # Create processed boundary
        boundary = {
            'ayah': b.get('ayah', i + 1),
            'original_start_time': b.get('start_time'),
            'original_end_time': b.get('end_time')
        }
        

        boundary['start_time'] = b.get('start_time')
        boundary['end_time'] = b.get('end_time')
        
        # Validate
        if boundary['start_time'] is None or boundary['end_time'] is None:
            raise ValueError(f"Boundary {i} missing start_time or end_time")
        
        processed_boundaries.append(boundary)

    return processed_boundaries


def main():
    parser = argparse.ArgumentParser(
        description='Find silences specifically around ayah boundaries',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        'audio_file',
        nargs='?',
        help='Path to audio file (optional if using --gap-thresholds)',
        default=None
    )
    
    parser.add_argument(
        'boundaries_file',
        nargs='?',
        help='Path to JSON file with ayah boundaries (optional if using --gap-thresholds)',
        default=None
    )
    
    parser.add_argument(
        '-t', '--threshold',
        type=float,
        default=-40,
        help='Silence threshold in dBFS (default: -40)'
    )
    
    parser.add_argument(
        '-d', '--min-duration',
        type=int,
        default=50,
        help='Minimum silence duration in ms (default: 50)'
    )
    
    parser.add_argument(
        '-w', '--window',
        type=int,
        default=500,
        help='Search window size in ms (default: 500)'
    )
    
    parser.add_argument(
        '--relative',
        action='store_true',
        help='Use relative threshold based on segment volume'
    )
    
    parser.add_argument(
        '--percentile',
        type=float,
        default=10,
        help='Percentile for relative threshold (default: 10)'
    )
    
    parser.add_argument(
        '--offset',
        type=float,
        default=5,
        help='Offset for relative threshold (default: 5)'
    )
    
    parser.add_argument(
        '-o', '--output',
        help='Output JSON file for results',
        default=None
    )
    
    parser.add_argument(
        '--visualize',
        action='store_true',
        help='Display visualization'
    )

    parser.add_argument(
        '--diagnose',
        action='store_true',
        help='Show diagnostic information about why silences might not be detected'
    )
    
    parser.add_argument(
        '--exclude-overlapping',
        action='store_true',
        help='Exclude overlapping silences from output (only keep before_start and after_end)'
    )
    
    parser.add_argument(
        '--gap-thresholds',
        help='JSON file with per-gap threshold configuration (from calculate_gap_thresholds.py)',
        default=None
    )
    
    args = parser.parse_args()
    
    try:
        # Load gap thresholds if provided
        gap_thresholds = None
        audio_file = args.audio_file
        boundaries_file = args.boundaries_file
        
        if args.gap_thresholds:
            gap_thresh_path = Path(args.gap_thresholds)
            if not gap_thresh_path.exists():
                print(f"✗ Gap thresholds file not found: {args.gap_thresholds}")
                sys.exit(1)
            
            with open(gap_thresh_path, 'r') as f:
                gap_thresholds = json.load(f)
            
            print(f"✓ Loaded gap threshold configuration")
            print(f"  Gaps: {len(gap_thresholds.get('gaps', []))}")
            
            # Extract audio and boundaries paths from config if not provided
            if not audio_file:
                audio_file = gap_thresholds.get('audio_file')
                if audio_file:
                    print(f"  Audio: {audio_file} (from config)")
                else:
                    print("✗ No audio file specified and none in config")
                    sys.exit(1)
            
            if not boundaries_file:
                boundaries_file = gap_thresholds.get('boundaries_file')
                if boundaries_file:
                    print(f"  Boundaries: {boundaries_file} (from config)")
                else:
                    print("✗ No boundaries file specified and none in config")
                    sys.exit(1)
        else:
            # No gap thresholds - require audio and boundaries files
            if not audio_file or not boundaries_file:
                print("✗ Error: audio_file and boundaries_file are required")
                print("  Either provide both files, or use --gap-thresholds with a config file")
                sys.exit(1)
        
        # Load boundaries
        boundaries = load_boundaries(boundaries_file)
        
        # Initialize detector
        detector = BoundarySilenceDetector(
            audio_path=audio_file,
            boundaries=boundaries,
            threshold=args.threshold,
            min_duration=args.min_duration,
            window_before=args.window,
            window_after=args.window,
            use_relative=args.relative,
            percentile=args.percentile,
            offset=args.offset,
            gap_thresholds=gap_thresholds
        )
        
        # Detect silences
        results = detector.detect_all_boundary_silences()
        
        # Filter overlapping silences if requested
        if args.exclude_overlapping:
            print("\nFiltering out overlapping silences...")
            original_total = sum(r['silence_count'] for r in results)
            
            for result in results:
                original_count = len(result['silences'])
                result['silences'] = [s for s in result['silences'] if s['position'] != 'overlapping']
                result['silence_count'] = len(result['silences'])
                
                if original_count > result['silence_count']:
                    filtered = original_count - result['silence_count']
                    print(f"  Ayah {result['ayah']}: Filtered {filtered} overlapping silence(s)")
            
            new_total = sum(r['silence_count'] for r in results)
            print(f"✓ Filtered {original_total - new_total} overlapping silences")
        
        # Print summary
        detector.print_summary(results)
        
        # Diagnose if no silences found or if requested
        total_silences = sum(r['silence_count'] for r in results)
        if args.diagnose or total_silences == 0:
            detector.diagnose_gaps(results)
        
        # Visualize if requested
        if args.visualize:
            if HAS_MATPLOTLIB:
                detector.visualize_results(results, output_path=args.save_plot)
            else:
                print("\n⚠️  Visualization requires matplotlib")
                print("Install with: pip install matplotlib")
        
        # Save results
        if args.output:
            output_path = Path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(output_path, 'w') as f:
                json.dump(results, f, indent=2)
            
            print(f"\n✓ Results saved: {args.output}")
        
        print("\n✓ Detection complete!")
        
    except Exception as e:
        print(f"\n✗ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

