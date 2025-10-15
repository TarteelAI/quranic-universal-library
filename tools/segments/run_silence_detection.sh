#!/bin/bash

#RECITATION_IDS=(1 2 3 4 5 6 7 10 12 13 65 161)

RECITATION_IDS=(1)

 # audio format (wav | flac | mp3)
FORMAT=wav

M_DEFAULT=100
T_DEFAULT=30   # this will be passed as -30 dBFS

# Per-recitation overrides
declare -A M_MAP
declare -A T_MAP

M_MAP[65]=100   # window size reduced for recitation 65
T_MAP[65]=30    # threshold = -30 dBFS

get_m_value() {
  if [[ -n "${M_MAP[$1]}" ]]; then
    echo "${M_MAP[$1]}"
  else
    echo "$M_DEFAULT"
  fi
}

get_t_value() {
  if [[ -n "${T_MAP[$1]}" ]]; then
    echo "${T_MAP[$1]}"
  else
    echo "$T_DEFAULT"
  fi
}

# Loop through all recitation IDs
for ID in "${RECITATION_IDS[@]}"; do
  AUDIO_DIR="../../data/audio/$ID"
  OUTPUT_DIR="silences/$ID"

  mkdir -p "$OUTPUT_DIR"

  M_VAL=$(get_m_value "$ID")
  T_VAL=$(get_t_value "$ID")

  echo ""
  echo "=== Processing Recitation $ID (window=$M_VAL ms, threshold=-$T_VAL dBFS) ==="

  for i in {1..114}; do
    printf -v num "%03d" "$i"
    audio_file="$AUDIO_DIR/$FORMAT/$num.$FORMAT"

    if [[ ! -f "$audio_file" ]]; then
      echo "Skipping Surah $i ($audio_file not found)."
      continue
    fi

    echo "Processing Surah $i..."

    python  detect_silences2.py "$audio_file" -o "$OUTPUT_DIR/${i}.json" -v --stats-file "$OUTPUT_DIR/${i}_stats.json"
#    python detect_silences.py \
#      "$audio_file" \
#      -o "$OUTPUT_DIR/${i}.json" \
#      -m "$M_VAL" \
#      -t "-$T_VAL" \
#      -v
  done

  echo "Completed Recitation $ID."
done

echo ""
echo "✅ All recitations processed."
