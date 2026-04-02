#!/bin/bash
set -e

RECITER=${1}
SURAH=${2}
AUDIO_FILE=${3}
RAW_SEGMENTS_FILE=${4}
OUTPUT_FILE=${5}

if [ -z "$OUTPUT_FILE" ]; then
  echo "Usage: $0 <reciter_id> <surah_number> <audio_file> <raw_segments_file> <output_file>"
  echo "Example:"
  echo "  $0 179 1 data/audio/179/wav/001.wav data/segments-json/179/surah_001.json tools/segments/data/result/raw_adjusted/179/1.json"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$AUDIO_FILE" ]; then
  echo "Audio file not found: $AUDIO_FILE"
  exit 1
fi

if [ ! -f "$RAW_SEGMENTS_FILE" ]; then
  echo "Raw segments file not found: $RAW_SEGMENTS_FILE"
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

python3 "$SCRIPT_DIR/adjust_ayah_boundaries_from_raw.py" \
  "$RAW_SEGMENTS_FILE" \
  "$AUDIO_FILE" \
  --search-radius 2000 \
  --output "$OUTPUT_FILE"

echo "Completed reciter=$RECITER surah=$SURAH"
echo "Output: $OUTPUT_FILE"
