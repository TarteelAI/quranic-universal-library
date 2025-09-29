#!/usr/bin/env python3
import argparse
import json
from pydub import AudioSegment, silence

def detect_silences(audio_file, output_file, min_silence_len, silence_thresh, verbose=False):
    # Load audio
    sound = AudioSegment.from_file(audio_file)

    # If silence_thresh is relative (e.g., -16), shift it based on dBFS
    if silence_thresh is None:
        silence_thresh = sound.dBFS - 16

    # Detect silences
    silences = silence.detect_silence(
        sound,
        min_silence_len=min_silence_len,
        silence_thresh=silence_thresh
    )

    # Convert to JSON-friendly structure
    results = []
    for start, end in silences:
        results.append({
            "start_time": start,
            "end_time": end,
            "duration": end - start
        })
        if verbose:
            print(f"Silence from {start}ms to {end}ms (duration: {end - start}ms)")

    # Save JSON
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    if verbose:
        print(f"Saved {len(results)} silences to {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Detect silences in audio file")
    parser.add_argument("audio_file", help="Path to input audio file")
    parser.add_argument("-o", "--output", required=True, help="Path to output JSON file")
    parser.add_argument("-m", "--min_silence_len", type=int, default=500,
                        help="Minimum silence length in milliseconds (default: 500)")
    parser.add_argument("-t", "--silence_thresh", type=float, default=None,
                        help="Silence threshold in dBFS (default: audio.dBFS - 16)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output")

    args = parser.parse_args()
    detect_silences(
        args.audio_file,
        args.output,
        args.min_silence_len,
        args.silence_thresh,
        args.verbose
    )