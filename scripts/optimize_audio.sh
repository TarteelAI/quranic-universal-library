#!/bin/bash

audio_folder="data/audio"

if [ ! -d "$audio_folder" ]; then
  echo "Error: '$audio_folder' folder not found!"
  exit 1
fi

for file in "$audio_folder"/*.mp3; do
  [ -e "$file" ] || continue

  temp_file="${file%.mp3}_optimized.mp3"
  opus_file="${file%.mp3}.opus"

  echo "Processing: $file"

  ffmpeg -i "$file" -map_metadata -1 -vn -c:a copy -metadata comment="qul.tarteel.ai" "$temp_file"

  new_name=$(basename "$temp_file" .mp3 | sed 's/^0\+//').mp3
  mv "$temp_file" "$audio_folder/$new_name"

  ffmpeg -i "$file" -c:a libopus -b:a 64k -metadata comment="qul.tarteel.ai" "$audio_folder/$(basename "$file" .mp3 | sed 's/^0\+//').opus"

  echo "Optimized MP3: $new_name"
  echo "Converted OPUS: $(basename "$file" .mp3 | sed 's/^0\+//').opus"
done

echo "All MP3 files optimized and converted to OPUS successfully."
