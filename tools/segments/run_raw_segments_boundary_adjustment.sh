#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

read -r -p "Reciter ID: " RECITER
read -r -p "Starting Surah: " START_SURAH
read -r -p "Last Surah: " END_SURAH

if [ -z "$RECITER" ] || [ -z "$START_SURAH" ] || [ -z "$END_SURAH" ]; then
  echo "All values are required."
  exit 1
fi

if ! [[ "$RECITER" =~ ^[0-9]+$ && "$START_SURAH" =~ ^[0-9]+$ && "$END_SURAH" =~ ^[0-9]+$ ]]; then
  echo "Reciter ID and surah range must be numeric."
  exit 1
fi

if [ "$START_SURAH" -gt "$END_SURAH" ]; then
  echo "Starting Surah must be less than or equal to Last Surah."
  exit 1
fi

echo "Reciter: $RECITER"
echo "Surah range: $START_SURAH to $END_SURAH"

for ((SURAH=START_SURAH; SURAH<=END_SURAH; SURAH++)); do
  SURAH_PADDED=$(printf "%03d" "$SURAH")
  RAW_SURAH_PADDED=$(printf "%03d" "$SURAH")

  AUDIO_FILE="$REPO_ROOT/tools/segments/data/audio/$RECITER/wav/${SURAH_PADDED}.wav"
  RAW_SEGMENTS_FILE="$REPO_ROOT/data/segments-json/$RECITER/surah_${RAW_SURAH_PADDED}.json"
  OUTPUT_FILE="$REPO_ROOT/tools/segments/data/result/raw_adjusted/$RECITER/${SURAH}.json"

  if [ ! -f "$AUDIO_FILE" ]; then
    echo "Skipping Surah $SURAH: audio file not found ($AUDIO_FILE)"
    continue
  fi

  if [ ! -f "$RAW_SEGMENTS_FILE" ]; then
    echo "Skipping Surah $SURAH: raw segments file not found ($RAW_SEGMENTS_FILE)"
    continue
  fi

  echo "Processing Surah $SURAH"
  "$SCRIPT_DIR/raw_segment_boundary_workflow.sh" \
    "$RECITER" \
    "$SURAH" \
    "$AUDIO_FILE" \
    "$RAW_SEGMENTS_FILE" \
    "$OUTPUT_FILE"
done

echo "Batch run complete."
