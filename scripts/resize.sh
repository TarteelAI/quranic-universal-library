#!/bin/bash

EXPORT_DIR="./exported_data/mushaf/6"
OUTPUT_DIR="./exported_data/mushaf/resized-6"

mkdir -p "$OUTPUT_DIR"

for file in "$EXPORT_DIR"/*.{png,jpg,jpeg}; do
  if [[ -f "$file" ]]; then
    filename=$(basename "$file")
    output_file="$OUTPUT_DIR/$filename"

    convert "$file" -resize 900x1437\! "$output_file"

    echo "Resized $filename to 900x1437 and saved to $output_file"
  fi
done
