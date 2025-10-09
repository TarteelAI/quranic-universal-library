#!/bin/bash

ID=1       # recitation ID
FORMAT=wav  # audio format (wav | flac | mp3)

AUDIO_DIR="data/audio/$ID"
OUTPUT_DIR="data/audio/silences/$ID"

mkdir -p "$OUTPUT_DIR"

# --- Configuration Map ---
# Default values:
#   -m (window size, ms)
#   -t (audio threshold in dBFS, NEGATIVE values)
M_DEFAULT=200
T_DEFAULT=50   # this will be passed as -50

# Per-recitation overrides
declare -A M_MAP
declare -A T_MAP

M_MAP[65]=100   # window size reduced for recitation 65
T_MAP[65]=30    # threshold = -40 dBFS

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

M_VAL=$(get_m_value "$ID")
T_VAL=$(get_t_value "$ID")

for i in {1..114}
do
  printf -v num "%03d" "$i"
  audio_file="$AUDIO_DIR/$FORMAT/$num.$FORMAT"

  if [[ ! -f "$audio_file" ]]; then
    echo "Skipping Surah $i ($audio_file not found)."
    continue
  fi

  echo "Processing Surah $i ($audio_file) with window=$M_VAL ms, threshold=-$T_VAL dBFS..."

  python detect_silences.py \
    "$audio_file" \
    -o "$OUTPUT_DIR/${i}.json" \
    -m "$M_VAL" \
    -t "-$T_VAL" \
    -v
done

echo "All files processed."
