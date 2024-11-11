#!/bin/bash

# Define source and target directories
SOURCE_DIR="exported_data/ayah/19/png"
TARGET_DIR="exported_data/mushaf/19/webp"

# Create the target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Loop through each PNG file in the source directory
for file in "$SOURCE_DIR"/*.png; do
  # Get the base filename without extension
  filename=$(basename "$file" .png)

  # Convert PNG to WebP and save in target directory
  cwebp -q 80 "$file" -o "$TARGET_DIR/$filename.webp"

  echo "Converted $file to $TARGET_DIR/$filename.webp"
done

echo "All files have been converted to WebP format and saved in the $TARGET_DIR folder."
