#!/bin/bash

# Usage:
#   ./run_segments_boundary_adjustment.sh                # runs for all reciters and all surahs (1..114)
#   ./run_segments_boundary_adjustment.sh 50 60          # runs for all reciters, surahs 50..60

# --- Configuration ---
RECITERS=(1 2 3 4 5 6 7 10 12 13 161)  # 👈 Add reciter IDs here
START_SURAH="${1:-1}"
END_SURAH="${2:-114}"

echo "Reciters: ${RECITERS[*]}"
echo "Surah range: $START_SURAH → $END_SURAH"
echo

for RECITER in "${RECITERS[@]}"; do
  echo "=============================="
  echo "🎧 Running for Reciter ID: $RECITER"
  echo "=============================="

  for ((SURAH=$START_SURAH; SURAH<=$END_SURAH; SURAH++)); do
    FILE="../../data/audio/$RECITER/wav/$(printf '%03d' $SURAH).wav"

    if [ ! -f "$FILE" ]; then
      echo "❌ File not found: $FILE"
      continue
    fi

    echo "▶️ Processing Surah $SURAH ..."
    ./segment_boundary_workflow.sh "$RECITER" "$SURAH" "$FILE"
  done

  echo "✅ Completed Reciter $RECITER"
  echo
done

echo "🎉 All done."
