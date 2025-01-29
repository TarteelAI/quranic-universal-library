#!/bin/bash


# Check for input arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <target_directory>"
    exit 1
fi

SOURCE_DIR="$1"
TARGET_DIR="$2"

# Define source and target directories
# SOURCE_DIR="output_images"
# TARGET_DIR="output_images/webp"

# Create the target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Loop through each PNG file in the source directory
for file in "$SOURCE_DIR"/*.jpg; do
  # Get the base filename without extension
  filename=$(basename "$file" .jpg)

  # Convert PNG to WebP and save in target directory
  cwebp -q 80 "$file" -o "$TARGET_DIR/$filename.webp"

  echo "Converted $file to $TARGET_DIR/$filename.webp"
done

echo "All files have been converted to WebP format and saved in the $TARGET_DIR folder."
