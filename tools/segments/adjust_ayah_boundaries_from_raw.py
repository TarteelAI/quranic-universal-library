#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np

try:
    from pydub import AudioSegment
except ImportError:
    print("Error: pydub is required. Install with: pip install pydub")
    sys.exit(1)


def load_raw_segments(path: Path) -> List[Dict]:
    with path.open("r") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("Raw segments JSON must be a list")
    normalized = []
    for row in data:
        segments = row.get("segments") or []
        if not segments:
            continue
        start_time = int(min(s[2] for s in segments))
        end_time = int(max(s[3] for s in segments))
        normalized.append(
            {
                "surah": int(row.get("surah")),
                "ayah": int(row.get("ayah")),
                "start_time": start_time,
                "end_time": end_time,
            }
        )
    normalized.sort(key=lambda x: x["ayah"])
    return normalized


def window_db_values(audio: AudioSegment, start_ms: int, end_ms: int, chunk_ms: int) -> np.ndarray:
    values = []
    t = start_ms
    while t < end_ms:
        nxt = min(t + chunk_ms, end_ms)
        chunk = audio[t:nxt]
        db = chunk.dBFS
        if np.isinf(db):
            db = -80.0
        values.append(float(db))
        t = nxt
    if not values:
        return np.array([-80.0], dtype=float)
    return np.array(values, dtype=float)


def detect_candidate_silence(
    audio: AudioSegment,
    boundary_ms: int,
    search_radius_ms: int,
    chunk_ms: int,
    threshold_offset_db: float,
    min_silence_ms: int,
) -> Dict:
    win_start = max(0, boundary_ms - search_radius_ms)
    win_end = min(len(audio), boundary_ms + search_radius_ms)
    if win_end <= win_start:
        return {"best_silence": None, "silences": [], "analysis": None}

    db_values = window_db_values(audio, win_start, win_end, chunk_ms)
    average_db = float(np.mean(db_values))
    median_db = float(np.median(db_values))
    threshold = average_db - threshold_offset_db

    chunks = []
    t = win_start
    while t < win_end:
        nxt = min(t + chunk_ms, win_end)
        chunk = audio[t:nxt]
        db = chunk.dBFS
        if np.isinf(db):
            db = -80.0
        chunks.append((t, nxt, float(db)))
        t = nxt

    spans = []
    run_start = None
    run_min_db = 0.0
    for c_start, c_end, c_db in chunks:
        if c_db <= threshold:
            if run_start is None:
                run_start = c_start
                run_min_db = c_db
            else:
                run_min_db = min(run_min_db, c_db)
        else:
            if run_start is not None:
                duration = c_start - run_start
                if duration >= min_silence_ms:
                    spans.append((run_start, c_start, duration, run_min_db))
                run_start = None
    if run_start is not None:
        duration = win_end - run_start
        if duration >= min_silence_ms:
            spans.append((run_start, win_end, duration, run_min_db))

    silences = []
    for s, e, duration, min_db in spans:
        silences.append(
            {
                "start_time": int(s),
                "end_time": int(e),
                "duration": int(duration),
                "center_time": int((s + e) // 2),
                "distance_to_boundary": int(((s + e) // 2) - boundary_ms),
                "min_db": round(float(min_db), 2),
            }
        )

    if not silences:
        return {
            "best_silence": None,
            "silences": [],
            "analysis": {
                "window_start": int(win_start),
                "window_end": int(win_end),
                "window_duration": int(win_end - win_start),
                "average_db": round(average_db, 2),
                "median_db": round(median_db, 2),
                "threshold_db": round(threshold, 2),
                "chunk_ms": int(chunk_ms),
                "min_silence_ms": int(min_silence_ms),
            },
        }

    def score(span: Tuple[int, int, int, float]) -> Tuple[int, int]:
        s, e, _, _ = span
        center = (s + e) // 2
        return (abs(center - boundary_ms), -1 * (e - s))

    best = sorted(silences, key=lambda span: score((span["start_time"], span["end_time"], span["duration"], span["min_db"])))[0]
    return {
        "best_silence": best,
        "silences": silences,
        "analysis": {
            "window_start": int(win_start),
            "window_end": int(win_end),
            "window_duration": int(win_end - win_start),
            "average_db": round(average_db, 2),
            "median_db": round(median_db, 2),
            "threshold_db": round(threshold, 2),
            "chunk_ms": int(chunk_ms),
            "min_silence_ms": int(min_silence_ms),
        },
    }


def adjust_boundaries(
    audio: AudioSegment,
    ayahs: List[Dict],
    search_radius_ms: int,
    chunk_ms: int,
    threshold_offset_db: float,
    min_silence_ms: int,
    min_gap_ms: int,
) -> Tuple[List[Dict], List[Dict]]:
    adjusted = []
    boundary_silences = []
    for idx, ayah in enumerate(ayahs):
        adjusted.append(
            {
                "surah": ayah["surah"],
                "ayah": ayah["ayah"],
                "start_time": ayah["start_time"],
                "end_time": ayah["end_time"],
                "silence_used": None,
                "corrected_start_time": ayah["start_time"],
                "corrected_end_time": ayah["end_time"],
                "adjustment_method": "",
                "gap_to_next": None,
                "metadata": {
                    "boundary_type": "initial",
                    "search_radius_ms": search_radius_ms,
                    "min_silence_ms": min_silence_ms,
                },
            }
        )

    if not adjusted:
        return adjusted

    adjusted[0]["corrected_start_time"] = 0
    adjusted[0]["adjustment_method"] = "First ayah: start set to 0"

    for i in range(len(adjusted) - 1):
        current = adjusted[i]
        nxt = adjusted[i + 1]
        boundary = int((current["end_time"] + nxt["start_time"]) / 2)

        detection = detect_candidate_silence(
            audio=audio,
            boundary_ms=boundary,
            search_radius_ms=search_radius_ms,
            chunk_ms=chunk_ms,
            threshold_offset_db=threshold_offset_db,
            min_silence_ms=min_silence_ms,
        )
        silence = detection["best_silence"]
        boundary_review = {
            "left_ayah": current["ayah"],
            "right_ayah": nxt["ayah"],
            "boundary_time": int(boundary),
            "analysis": detection["analysis"],
            "silences": detection["silences"],
            "silence_count": len(detection["silences"]),
            "selected_silence": silence,
        }
        boundary_silences.append(boundary_review)
        current["metadata"]["boundary_to_next"] = boundary_review

        if silence:
            left_end = silence["start_time"]
            right_start = silence["end_time"]
            if left_end > current["corrected_start_time"]:
                current["corrected_end_time"] = left_end
            if right_start < nxt["end_time"]:
                nxt["corrected_start_time"] = right_start
            current["silence_used"] = {
                "position": "after_end",
                "start_time": silence["start_time"],
                "end_time": silence["end_time"],
                "duration": silence["duration"],
                "distance_to_boundary": silence["distance_to_boundary"],
            }
            method = f"Boundary {current['ayah']}-{nxt['ayah']} adjusted using detected silence"
            current["adjustment_method"] = (
                current["adjustment_method"] + "; " + method if current["adjustment_method"] else method
            )
            nxt_method = f"Boundary {current['ayah']}-{nxt['ayah']} start aligned to detected silence"
            nxt["adjustment_method"] = (
                nxt["adjustment_method"] + "; " + nxt_method if nxt["adjustment_method"] else nxt_method
            )
            current["metadata"]["boundary_type"] = "silence_detected"
            current["metadata"]["threshold_db"] = detection["analysis"]["threshold_db"]
            current["metadata"]["average_db"] = detection["analysis"]["average_db"]
            current["metadata"]["window_start"] = detection["analysis"]["window_start"]
            current["metadata"]["window_end"] = detection["analysis"]["window_end"]
        else:
            fallback_end = max(current["corrected_start_time"], min(current["end_time"], nxt["start_time"] - min_gap_ms))
            fallback_start = min(nxt["end_time"], max(nxt["start_time"], current["end_time"] + min_gap_ms))
            current["corrected_end_time"] = fallback_end
            nxt["corrected_start_time"] = fallback_start
            method = "No silence near boundary, applied min gap fallback"
            current["adjustment_method"] = (
                current["adjustment_method"] + "; " + method if current["adjustment_method"] else method
            )
            nxt["adjustment_method"] = (
                nxt["adjustment_method"] + "; " + method if nxt["adjustment_method"] else method
            )
            current["metadata"]["boundary_type"] = "fallback_min_gap"

    if adjusted[-1]["corrected_end_time"] < adjusted[-1]["end_time"]:
        adjusted[-1]["corrected_end_time"] = adjusted[-1]["end_time"]

    for i in range(len(adjusted) - 1):
        gap = adjusted[i + 1]["corrected_start_time"] - adjusted[i]["corrected_end_time"]
        adjusted[i]["gap_to_next"] = int(gap)
    adjusted[-1]["gap_to_next"] = None
    adjusted[-1]["metadata"]["boundary_to_next"] = None

    for item in adjusted:
        if not item["adjustment_method"]:
            item["adjustment_method"] = "No boundary change"

    return adjusted, boundary_silences


def main() -> None:
    parser = argparse.ArgumentParser(description="Adjust ayah boundaries from raw segments and audio silence")
    parser.add_argument("raw_segments_file", help="Path to raw segments JSON")
    parser.add_argument("audio_file", help="Path to audio file")
    parser.add_argument("-o", "--output", required=True, help="Output JSON path")
    parser.add_argument("--search-radius", type=int, default=2000, help="Search radius around boundary in ms")
    parser.add_argument("--chunk-ms", type=int, default=10, help="Analysis chunk size in ms")
    parser.add_argument("--threshold-offset", type=float, default=6.0, help="Silence threshold offset in dB")
    parser.add_argument("--min-silence", type=int, default=35, help="Minimum silence duration in ms")
    parser.add_argument("--min-gap", type=int, default=80, help="Minimum gap fallback in ms")
    args = parser.parse_args()

    raw_path = Path(args.raw_segments_file)
    audio_path = Path(args.audio_file)
    output_path = Path(args.output)

    if not raw_path.exists():
        raise FileNotFoundError(f"Raw segments file not found: {raw_path}")
    if not audio_path.exists():
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    ayahs = load_raw_segments(raw_path)
    audio = AudioSegment.from_file(str(audio_path))
    adjusted, boundary_silences = adjust_boundaries(
        audio=audio,
        ayahs=ayahs,
        search_radius_ms=args.search_radius,
        chunk_ms=args.chunk_ms,
        threshold_offset_db=args.threshold_offset,
        min_silence_ms=args.min_silence,
        min_gap_ms=args.min_gap,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w") as f:
        workflow_metadata = {
            "source_raw_segments_file": str(raw_path),
            "source_audio_file": str(audio_path),
            "ayah_count": len(adjusted),
            "search_radius_ms": args.search_radius,
            "chunk_ms": args.chunk_ms,
            "threshold_offset_db": args.threshold_offset,
            "min_silence_ms": args.min_silence,
            "min_gap_ms": args.min_gap,
            "audio_duration_ms": len(audio),
        }
        for item in adjusted:
            item["metadata"]["workflow"] = workflow_metadata
        json.dump(adjusted, f, indent=2)

    print(f"Adjusted boundaries saved: {output_path}")
    print(f"Ayahs processed: {len(adjusted)}")


if __name__ == "__main__":
    main()
