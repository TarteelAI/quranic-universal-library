#!/usr/bin/env python3
# Usage:
#   python detect_silences.py path/to/audio.mp3
#   Options:
#     --threshold FLOAT       (default 3.0) - RMS threshold as percentage (0..100)
#     --min_silence INT       minimum silence duration in ms (default 150)
#     --merge_gap INT         merge gap in ms (default 50)
#     --no-refine             disable boundary refinement for faster processing
#     --stats-file PATH       save detailed statistics to a separate JSON file
#     --output PATH, -o PATH  output JSON path (default: <audio_basename>_silences.json)
#     --verbose, -v           verbose output

import argparse
import json
import numpy as np
import librosa
import soundfile as sf
import io
import tempfile
import os
import math
import traceback
from typing import Tuple, List, Dict

try:
    from pydub import AudioSegment
    HAS_PYDUB = True
except Exception:
    HAS_PYDUB = False

def _safe_unlink(path: str):
    try:
        if path and os.path.exists(path):
            os.unlink(path)
    except Exception:
        pass

def load_audio_file_from_bytes(file_bytes: io.BytesIO, filename_hint: str = None) -> Tuple[np.ndarray, int]:
    suffix = None
    if filename_hint and '.' in filename_hint:
        suffix = filename_hint[filename_hint.rfind('.'):]

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix or '.tmp')
    tmp_path = tmp.name
    try:
        try:
            file_bytes.seek(0)
            data_to_write = file_bytes.read()
        except Exception:
            data_to_write = bytes(file_bytes)

        tmp.write(data_to_write)
        tmp.flush()
        tmp.close()

        try:
            y, sr = librosa.load(tmp_path, sr=None, mono=False)
            if isinstance(y, np.ndarray) and y.ndim > 1:
                y = np.mean(y, axis=0)
            return y.astype(np.float32), int(sr)
        except Exception as e1:
            if HAS_PYDUB:
                wav_tmp = None
                try:
                    audio = AudioSegment.from_file(tmp_path)
                    wav_tmp = tempfile.NamedTemporaryFile(delete=False, suffix='.wav')
                    wav_tmp.close()
                    audio.export(wav_tmp.name, format='wav')
                    y, sr = librosa.load(wav_tmp.name, sr=None, mono=False)
                    if isinstance(y, np.ndarray) and y.ndim > 1:
                        y = np.mean(y, axis=0)
                    return y.astype(np.float32), int(sr)
                except Exception as e2:
                    try:
                        data, sr = sf.read(tmp_path, dtype='float32')
                        if data.ndim > 1:
                            data = np.mean(data, axis=1)
                        return data.astype(np.float32), int(sr)
                    except Exception as e3:
                        tb = traceback.format_exc()
                        raise RuntimeError(
                            f"All loaders failed. librosa error: {e1}; pydub error: {e2}; soundfile error: {e3}. Traceback: {tb}"
                        )
                finally:
                    if wav_tmp:
                        _safe_unlink(wav_tmp.name)
            else:
                try:
                    data, sr = sf.read(tmp_path, dtype='float32')
                    if data.ndim > 1:
                        data = np.mean(data, axis=1)
                    return data.astype(np.float32), int(sr)
                except Exception as e3:
                    tb = traceback.format_exc()
                    raise RuntimeError(f"librosa failed: {e1}; soundfile failed: {e3}. Consider installing pydub + ffmpeg. Traceback: {tb}")
    finally:
        _safe_unlink(tmp_path)

def refine_silence_boundaries(y: np.ndarray, sr: int, silences: List[Dict], threshold: float = 0.18) -> List[Dict]:
    """
    Refine silence boundaries to find exact transition points with sub-sample precision.
    This uses binary search to find the exact sample where the transition occurs.
    """
    refined_silences = []

    for silence in silences:
        start_sample = silence["start_sample"]
        end_sample = silence["end_sample"]

        # Refine start boundary (find exact transition from sound to silence)
        refined_start = find_exact_transition(y, sr, start_sample, -1, threshold, "start")

        # Refine end boundary (find exact transition from silence to sound)
        refined_end = find_exact_transition(y, sr, end_sample, 1, threshold, "end")

        # Create refined silence entry
        refined_silence = {
            "start_sample": refined_start,
            "end_sample": refined_end,
            "start_time": float(refined_start) / sr,
            "end_time": float(refined_end) / sr,
            "duration_samples": refined_end - refined_start
        }

        refined_silences.append(refined_silence)

    return refined_silences

def find_exact_transition(y: np.ndarray, sr: int, initial_sample: int, direction: int, threshold: float, boundary_type: str) -> int:
    """
    Find the exact sample where the transition occurs using binary search.

    Args:
        y: Audio samples
        sr: Sample rate
        initial_sample: Initial estimate of transition point
        direction: -1 for searching backwards (start boundary), 1 for forwards (end boundary)
        threshold: RMS threshold for silence detection
        boundary_type: "start" or "end" for logging purposes

    Returns:
        Exact sample index where transition occurs
    """
    # Define search range
    if direction == -1:  # Searching backwards for start boundary
        search_start = max(0, initial_sample - sr)  # Search up to 1 second back
        search_end = min(len(y), initial_sample + sr)  # Search up to 1 second forward
    else:  # Searching forwards for end boundary
        search_start = max(0, initial_sample - sr)  # Search up to 1 second back
        search_end = min(len(y), initial_sample + sr)  # Search up to 1 second forward

    # Use a small window for RMS calculation
    window_size = max(1, int(sr * 0.001))  # 1ms window

    def get_rms_at_sample(sample_idx: int) -> float:
        """Calculate RMS value at a specific sample using a small window."""
        start_idx = max(0, sample_idx - window_size // 2)
        end_idx = min(len(y), sample_idx + window_size // 2)
        frame = y[start_idx:end_idx]
        if frame.size == 0:
            return 0.0
        return float(np.sqrt(np.mean(frame.astype(np.float64) * frame.astype(np.float64))))

    # Binary search to find exact transition
    left = search_start
    right = search_end

    while left < right:
        mid = (left + right) // 2
        rms_val = get_rms_at_sample(mid)

        if boundary_type == "start":
            # For start boundary: we want to find where rms goes from >= threshold to < threshold
            if rms_val < threshold:
                right = mid
            else:
                left = mid + 1
        else:  # end boundary
            # For end boundary: we want to find where rms goes from < threshold to >= threshold
            if rms_val >= threshold:
                right = mid
            else:
                left = mid + 1

    return left

def calculate_silence_statistics(silences: List[Dict], total_duration: float) -> Dict:
    """
    Calculate comprehensive statistics about detected silences.

    Args:
        silences: List of silence dictionaries
        total_duration: Total audio duration in seconds

    Returns:
        Dictionary containing various statistics
    """
    if not silences:
        return {
            "total_silences": 0,
            "total_silence_duration": 0.0,
            "silence_percentage": 0.0,
            "average_silence_duration": 0.0,
            "longest_silence": 0.0,
            "shortest_silence": 0.0
        }

    # Calculate basic statistics
    total_silence_duration = sum(s["end_time"] - s["start_time"] for s in silences)
    silence_percentage = (total_silence_duration / total_duration) * 100

    # Duration statistics
    durations = [s["end_time"] - s["start_time"] for s in silences]
    average_duration = sum(durations) / len(durations)
    longest_silence = max(durations)
    shortest_silence = min(durations)

    # Merge statistics
    merged_count = sum(1 for s in silences if "merged_count" in s and s["merged_count"] > 1)
    total_original_silences = sum(s.get("merged_count", 1) for s in silences)

    return {
        "total_silences": len(silences),
        "total_original_silences": total_original_silences,
        "merged_silences": merged_count,
        "total_silence_duration": total_silence_duration,
        "silence_percentage": silence_percentage,
        "average_silence_duration": average_duration,
        "longest_silence": longest_silence,
        "shortest_silence": shortest_silence,
        "total_audio_duration": total_duration
    }

def analyze_silence_detection(y: np.ndarray, sr: int, threshold: float, min_sil_ms: int) -> Dict:
    """
    Analyze the audio data to understand why certain silences are detected.
    This helps debug threshold and detection issues.
    """
    # Use the same parameters as the detection function
    window_samples = max(1, int(sr * 0.01))  # 10ms window
    hop_samples = max(1, int(sr * 0.001))    # 1ms hop

    rms_values = []
    sample_times = []

    # Calculate RMS for each small window
    for i in range(0, len(y) - window_samples, hop_samples):
        frame = y[i:i + window_samples]
        rms_val = float(np.sqrt(np.mean(frame.astype(np.float64) * frame.astype(np.float64))))
        rms_values.append(rms_val)
        sample_times.append(i)

    rms_array = np.array(rms_values)

    if rms_array.size > 0:
        max_rms = float(rms_array.max())
        min_rms = float(rms_array.min())
        rms_range = max_rms - min_rms

        if rms_range > 0:
            rms_norm = (rms_array - min_rms) / rms_range
            threshold_normalized = threshold / 100.0
        else:
            rms_norm = np.zeros_like(rms_array)
            threshold_normalized = threshold / 100.0
    else:
        rms_norm = np.array([])
        threshold_normalized = threshold / 100.0

    # Analyze the distribution
    below_threshold = np.sum(rms_norm < threshold_normalized)
    above_threshold = np.sum(rms_norm >= threshold_normalized)

    # Find some sample values around the threshold
    threshold_samples = []
    for i, rms_val in enumerate(rms_norm):
        if abs(rms_val - threshold_normalized) < 0.01:  # Within 1% of threshold
            time_sec = sample_times[i] / sr
            threshold_samples.append((time_sec, rms_val))
            if len(threshold_samples) >= 5:  # Limit to 5 samples
                break

    return {
        "total_samples": len(rms_norm),
        "rms_range": (min_rms, max_rms),
        "normalized_range": (rms_norm.min(), rms_norm.max()),
        "threshold_percentage": threshold,
        "threshold_normalized": threshold_normalized,
        "samples_below_threshold": below_threshold,
        "samples_above_threshold": above_threshold,
        "threshold_samples": threshold_samples,
        "silence_percentage_estimate": (below_threshold / len(rms_norm)) * 100 if rms_norm.size > 0 else 0
    }

def merge_close_silences(silences: List[Dict], merge_threshold_ms: int = 200) -> List[Dict]:
    """
    Merge silences that are close to each other, similar to the JavaScript implementation.

    Args:
        silences: List of silence dictionaries
        merge_threshold_ms: Maximum gap between silences to merge (in milliseconds)

    Returns:
        List of merged silences
    """
    if not silences:
        return []

    # Sort silences by start time
    sorted_silences = sorted(silences, key=lambda x: x["start_time"])

    merged = [sorted_silences[0].copy()]

    for next_silence in sorted_silences[1:]:
        current = merged[-1]

        # Calculate gap between current silence end and next silence start
        gap_ms = (next_silence["start_time"] - current["end_time"]) * 1000

        if gap_ms <= merge_threshold_ms:
            # Merge the silences
            merged[-1] = {
                "start_sample": current["start_sample"],
                "end_sample": next_silence["end_sample"],
                "start_time": current["start_time"],
                "end_time": next_silence["end_time"],
                "duration_samples": next_silence["end_sample"] - current["start_sample"]
            }

            if "merged_count" not in merged[-1]:
                merged[-1]["merged_count"] = 2
            else:
                merged[-1]["merged_count"] += 1
        else:
            # Add as new silence
            merged.append(next_silence.copy())

    return merged

def detect_silences_energy(y: np.ndarray, sr: int, threshold: float = 0.18, min_sil_ms: int = 400, merge_ms: int = 200, verbose: bool = False) -> List[Dict]:
    """
    Detect silences by finding exact transition points between sound and silence.
    This method matches the HTML implementation for consistent results.
    """
    if y is None or y.size == 0:
        return []

    # Convert thresholds to sample indices
    min_silence_samples = max(1, int(sr * min_sil_ms / 1000.0))
    merge_gap_samples = max(1, int(sr * merge_ms / 1000.0))

    # Use a small window for RMS calculation (similar to HTML version)
    window_samples = max(1, int(sr * 0.01))  # 10ms window
    hop_samples = max(1, int(sr * 0.001))    # 1ms hop for high precision

    rms_values = []
    sample_times = []

    # Calculate RMS for each small window
    for i in range(0, len(y) - window_samples, hop_samples):
        frame = y[i:i + window_samples]
        rms_val = float(np.sqrt(np.mean(frame.astype(np.float64) * frame.astype(np.float64))))
        rms_values.append(rms_val)
        sample_times.append(i)

    # Normalize RMS values to 0-1 range (this is the key fix!)
    rms_array = np.array(rms_values)
    if rms_array.size > 0:
        # Find the maximum RMS value for normalization
        max_rms = float(rms_array.max())
        min_rms = float(rms_array.min())
        rms_range = max_rms - min_rms

        if rms_range > 0:
            # Normalize to 0-1 range, then apply threshold as percentage
            rms_norm = (rms_array - min_rms) / rms_range
            # Convert threshold from percentage to normalized value
            threshold_normalized = threshold / 100.0  # threshold is now in percentage
        else:
            rms_norm = np.zeros_like(rms_array)
            threshold_normalized = threshold / 100.0
    else:
        rms_norm = np.array([])
        threshold_normalized = threshold / 100.0

    # Debug output for threshold calculation
    if verbose:
        print(f"RMS range: {min_rms:.6f} to {max_rms:.6f}")
        print(f"Threshold: {threshold}% = {threshold_normalized:.6f}")
        print(f"Sample RMS values: min={rms_norm.min():.6f}, max={rms_norm.max():.6f}")
        print(f"Silence detection threshold: {threshold_normalized:.6f}")

    # Find silence regions with exact boundaries
    silences = []
    in_silence = False
    silence_start_sample = None

    for i, (rms_val, sample_idx) in enumerate(zip(rms_norm, sample_times)):
        if rms_val < threshold_normalized:
            if not in_silence:
                in_silence = True
                silence_start_sample = sample_idx
        else:
            if in_silence:
                silence_end_sample = sample_idx
                silence_duration_samples = silence_end_sample - silence_start_sample

                if silence_duration_samples >= min_silence_samples:
                    # Convert sample indices to precise times
                    start_time = float(silence_start_sample) / sr
                    end_time = float(silence_end_sample) / sr

                    silences.append({
                        "start_sample": int(silence_start_sample),
                        "end_sample": int(silence_end_sample),
                        "start_time": start_time,
                        "end_time": end_time,
                        "duration_samples": int(silence_duration_samples)
                    })

                in_silence = False
                silence_start_sample = None

    # Handle case where audio ends in silence
    if in_silence and silence_start_sample is not None:
        silence_end_sample = len(y) - 1
        silence_duration_samples = silence_end_sample - silence_start_sample

        if silence_duration_samples >= min_silence_samples:
            start_time = float(silence_start_sample) / sr
            end_time = float(silence_end_sample) / sr

            silences.append({
                "start_sample": int(silence_start_sample),
                "end_sample": int(silence_end_sample),
                "start_time": start_time,
                "end_time": end_time,
                "duration_samples": int(silence_duration_samples)
            })

    if not silences:
        return []

    # Merge nearby silences
    merged = [silences[0]]
    for next_s in silences[1:]:
        cur = merged[-1]
        gap_samples = next_s["start_sample"] - cur["end_sample"]

        if gap_samples <= merge_gap_samples:
            # Merge the silences
            merged[-1] = {
                "start_sample": cur["start_sample"],
                "end_sample": next_s["end_sample"],
                "start_time": cur["start_time"],
                "end_time": next_s["end_time"],
                "duration_samples": next_s["end_sample"] - cur["start_sample"]
            }
        else:
            merged.append(next_s)

    return merged

def format_silences_for_output_ms(silences: List[Dict]) -> List[Dict]:
    formatted = []
    for i, s in enumerate(silences):
        start_ms = int(round(float(s["start_time"]) * 1000.0))
        end_ms = int(round(float(s["end_time"]) * 1000.0))
        duration_ms = int(round(end_ms - start_ms))

        silence_info = {
            "number": i + 1,
            "start_time_ms": start_ms,
            "end_time_ms": end_ms,
            "duration_ms": duration_ms
        }

        # Add merge information if available
        if "merged_count" in s:
            silence_info["merged_count"] = s["merged_count"]
            silence_info["note"] = f"Merged from {s['merged_count']} separate silences"

        formatted.append(silence_info)
    return formatted

def main():
    parser = argparse.ArgumentParser(description="Detect silences in an audio file and save JSON.")
    parser.add_argument("audio_file", help="Path to audio file (wav, mp3, m4a, etc.)")
    parser.add_argument("--threshold", type=float, default=3.0, help="RMS threshold as percentage (0..100). Default 3.0")
    parser.add_argument("--min_silence", type=int, default=150, help="Minimum silence duration in ms. Default 150")
    parser.add_argument("--merge_gap", type=int, default=50, help="Merge gap threshold in ms. Default 50")
    parser.add_argument("--no-refine", action="store_true", help="Disable boundary refinement for faster processing")
    parser.add_argument("--stats-file", help="Save detailed statistics to a separate JSON file")
    parser.add_argument("--output", "-o", help="Output JSON path. If not provided, use <audio_basename>_silences.json")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    args = parser.parse_args()

    if not os.path.exists(args.audio_file):
        print(f"Error: audio file not found: {args.audio_file}")
        return

    if args.output:
        output_file = args.output
    else:
        base, _ext = os.path.splitext(args.audio_file)
        output_file = base + "_silences.json"

    try:
        if args.verbose:
            print(f"Loading audio: {args.audio_file}")
        with open(args.audio_file, "rb") as f:
            audio_bytes = io.BytesIO(f.read())

        y, sr = load_audio_file_from_bytes(audio_bytes, filename_hint=args.audio_file)
        duration = float(librosa.get_duration(y=y, sr=sr))

        if args.verbose:
            print(f"Sample rate: {sr}, duration: {duration:.3f}s, samples: {len(y)}")

            # Analyze the audio data for debugging
            print("Analyzing audio characteristics...")
            analysis = analyze_silence_detection(y, sr, args.threshold, args.min_silence)
            print(f"RMS range: {analysis['rms_range'][0]:.6f} to {analysis['rms_range'][1]:.6f}")
            print(f"Normalized range: {analysis['normalized_range'][0]:.6f} to {analysis['normalized_range'][1]:.6f}")
            print(f"Threshold: {analysis['threshold_percentage']}% = {analysis['threshold_normalized']:.6f}")
            print(f"Estimated silence percentage: {analysis['silence_percentage_estimate']:.1f}%")
            print(f"Samples below threshold: {analysis['samples_below_threshold']} / {analysis['total_samples']}")

        if args.verbose:
            print("Detecting silences...")
        silences = detect_silences_energy(
            y=y,
            sr=sr,
            threshold=args.threshold,
            min_sil_ms=args.min_silence,
            merge_ms=args.merge_gap,
            verbose=args.verbose
        )

        if args.verbose:
            print(f"Found {len(silences)} initial silence regions")

        # Refine boundaries for more precise timing (unless disabled)
        if not args.no_refine:
            if args.verbose:
                print("Refining boundaries for precise timing...")
            refined_silences = refine_silence_boundaries(y, sr, silences, args.threshold)
        else:
            if args.verbose:
                print("Skipping boundary refinement (--no-refine flag used)")
            refined_silences = silences

        if args.verbose:
            print(f"Refined {len(refined_silences)} silence regions")

        # Merge close silences
        if args.verbose:
            print("Merging close silences...")
        merged_silences = merge_close_silences(refined_silences, args.merge_gap)

        if args.verbose:
            original_count = len(refined_silences)
            merged_count = len(merged_silences)
            if original_count != merged_count:
                print(f"Merged {original_count} silences into {merged_count} regions")
            else:
                print("No silences were merged")

        formatted_ms = format_silences_for_output_ms(merged_silences)

        # Calculate and display statistics
        stats = calculate_silence_statistics(merged_silences, duration)

        if args.verbose:
            print("\n" + "="*50)
            print("SILENCE DETECTION STATISTICS")
            print("="*50)
            print(f"Total audio duration: {stats['total_audio_duration']:.2f} seconds")
            print(f"Detected silences: {stats['total_silences']}")
            print(f"Original silences (before merging): {stats['total_original_silences']}")
            print(f"Merged silences: {stats['merged_silences']}")
            print(f"Total silence duration: {stats['total_silence_duration']:.2f} seconds")
            print(f"Silence percentage: {stats['silence_percentage']:.1f}%")
            print(f"Average silence duration: {stats['average_silence_duration']:.2f} seconds")
            print(f"Longest silence: {stats['longest_silence']:.2f} seconds")
            print(f"Shortest silence: {stats['shortest_silence']:.2f} seconds")
            print("="*50)

        # Save silence data
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(formatted_ms, f, indent=2, ensure_ascii=False)

        # Save statistics if requested
        if args.stats_file:
            with open(args.stats_file, "w", encoding="utf-8") as f:
                json.dump(stats, f, indent=2, ensure_ascii=False)
            print(f"Saved statistics to: {args.stats_file}")

        print(f"Detected {len(formatted_ms)} silences in '{args.audio_file}'.")
        print(f"Saved results to: {output_file}")

    except Exception as e:
        print("Error processing audio file:", str(e))
        traceback.print_exc()

if __name__ == "__main__":
    main()