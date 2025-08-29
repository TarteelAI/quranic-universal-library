#!/usr/bin/env python3
# Usage:
#   python detect_silences.py path/to/audio.mp3
#   Options:
#     --threshold FLOAT       (default 0.18)
#     --min_silence INT       minimum silence duration in ms (default 400)
#     --merge_gap INT         merge gap in ms (default 140)
#     --window INT            RMS window size in ms (default 800)
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

def compute_rms(y: np.ndarray, sr: int, win_ms: int = 800) -> Tuple[np.ndarray, np.ndarray, int]:
    if y is None or y.size == 0:
        return np.array([], dtype=np.float32), np.array([], dtype=np.float32), 1

    hop = max(1, int(sr * (win_ms / 1000.0)))
    frame_len = hop
    rms = []
    for i in range(0, len(y), hop):
        frame = y[i:i+frame_len]
        if frame.size == 0:
            break
        rms_val = float(np.sqrt(np.mean(frame.astype(np.float64) * frame.astype(np.float64)))) if frame.size > 0 else 0.0
        rms.append(rms_val)
    rms = np.array(rms, dtype=np.float32)
    maxv = float(rms.max()) if rms.size and rms.max() > 0 else 1.0
    rms_norm = rms / maxv
    times = (np.arange(len(rms)) * hop) / float(sr)
    return rms_norm, times, hop

def detect_silences_energy(rms_norm: np.ndarray, times: np.ndarray, hop: int, sr: int,
                           threshold: float = 0.18, min_sil_ms: int = 400, merge_ms: int = 200) -> List[Dict]:
    if rms_norm.size == 0:
        return []

    frame_duration_ms = (hop / sr) * 1000.0
    min_sil_frames = max(1, int(math.ceil(min_sil_ms / frame_duration_ms)))
    merge_frames = max(1, int(math.ceil(merge_ms / frame_duration_ms)))

    silences = []
    in_silence = False
    silence_start = None

    for i, v in enumerate(rms_norm):
        if v < threshold:
            if not in_silence:
                in_silence = True
                silence_start = i
        else:
            if in_silence:
                silence_end = i - 1
                duration_frames = silence_end - silence_start + 1
                if duration_frames >= min_sil_frames:
                    start_time = float(silence_start * (hop / sr))
                    end_time = float((silence_end + 1) * (hop / sr))
                    silences.append({
                        "start_idx": int(silence_start),
                        "end_idx": int(silence_end),
                        "start_time": start_time,
                        "end_time": end_time
                    })
                in_silence = False
                silence_start = None

    if in_silence and silence_start is not None:
        silence_end = len(rms_norm) - 1
        duration_frames = silence_end - silence_start + 1
        if duration_frames >= min_sil_frames:
            start_time = float(silence_start * (hop / sr))
            end_time = float((silence_end + 1) * (hop / sr))
            silences.append({
                "start_idx": int(silence_start),
                "end_idx": int(silence_end),
                "start_time": start_time,
                "end_time": end_time
            })

    if not silences:
        return []

    merged = [silences[0]]
    for next_s in silences[1:]:
        cur = merged[-1]
        gap_frames = next_s["start_idx"] - cur["end_idx"] - 1
        if gap_frames <= merge_frames:
            merged[-1] = {
                "start_idx": cur["start_idx"],
                "end_idx": next_s["end_idx"],
                "start_time": cur["start_time"],
                "end_time": next_s["end_time"]
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
        formatted.append({
            "number": i + 1,
            "start_time_ms": start_ms,
            "end_time_ms": end_ms,
            "duration_ms": duration_ms
        })
    return formatted

def main():
    parser = argparse.ArgumentParser(description="Detect silences in an audio file and save JSON.")
    parser.add_argument("audio_file", help="Path to audio file (wav, mp3, m4a, etc.)")
    parser.add_argument("--threshold", type=float, default=0.18, help="RMS threshold (0..1). Default 0.18")
    parser.add_argument("--min_silence", type=int, default=400, help="Minimum silence duration in ms. Default 400")
    parser.add_argument("--merge_gap", type=int, default=140, help="Merge gap threshold in ms. Default 140")
    parser.add_argument("--window", type=int, default=800, help="Window size in ms for RMS frames. Default 800")
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

        if args.verbose:
            print("Computing RMS frames...")
        rms_norm, rms_times, hop = compute_rms(y, sr, win_ms=args.window)

        if rms_norm.size == 0:
            with open(output_file, "w", encoding="utf-8") as outf:
                json.dump([], outf, indent=2, ensure_ascii=False)
            print(f"Saved empty result to: {output_file}")
            return

        if args.verbose:
            print("Detecting silences...")
        silences = detect_silences_energy(
            rms_norm=rms_norm,
            times=rms_times,
            hop=hop,
            sr=sr,
            threshold=args.threshold,
            min_sil_ms=args.min_silence,
            merge_ms=args.merge_gap
        )

        formatted_ms = format_silences_for_output_ms(silences)

        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(formatted_ms, f, indent=2, ensure_ascii=False)

        print(f"Detected {len(formatted_ms)} silences in '{args.audio_file}'.")
        print(f"Saved results (array-only, times in ms) to: {output_file}")

    except Exception as e:
        print("Error processing audio file:", str(e))
        traceback.print_exc()

if __name__ == "__main__":
    main()
