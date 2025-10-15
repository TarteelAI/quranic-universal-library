#!/bin/bash

# Usage:
#   ./run_segments_boundary_adjustment.sh                # runs for all reciters and all surahs (1..114)
#   ./run_segments_boundary_adjustment.sh 50 60          # runs for all reciters, surahs 50..60

RECITERS=(1)
START_SURAH="${1:-1}"
END_SURAH="${2:-114}"

echo "Reciters: ${RECITERS[*]}"
echo "Surah range: $START_SURAH → $END_SURAH"

for RECITER in "${RECITERS[@]}"; do
  echo "=============================="
  echo " Running for Reciter ID: $RECITER"
  echo "=============================="

  for ((SURAH=$START_SURAH; SURAH<=$END_SURAH; SURAH++)); do
    AUDIO_FILE="./data/audio/$RECITER/wav/$(printf '%03d' $SURAH).wav"

    if [ ! -f "$AUDIO_FILE" ]; then
      echo "❌ Audio File not found: $AUDIO_FILE"
      continue
    fi

    echo "▶️ Processing Surah $SURAH ..."
    ./segment_boundary_workflow.sh "$RECITER" "$SURAH" "$AUDIO_FILE"
  done

  echo "✅ Completed Reciter $RECITER"
  echo
done

echo "🎉 All done."
