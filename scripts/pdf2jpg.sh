#!/bin/bash

# Convert pdf to jpg then use 2web script to convert these images to webp

# Check for input arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input_pdf> <start_page> <end_page>"
    exit 1
fi

input_pdf="$1"
start_page="$2"
end_page="$3"
output_dir="output_images"

# Create output directory
mkdir -p "$output_dir"

# Convert PDF to JPG for the specified page range
echo "Converting pages $start_page to $end_page from $input_pdf to JPG..."
pdftoppm -jpeg -f "$start_page" -l "$end_page" "$input_pdf" "$output_dir/page"

# Move to the output directory
cd "$output_dir" || exit

# Rename remaining files sequentially
echo "Renaming files..."
counter=1
for file in $(ls -v page-*.jpg); do
    new_name="${counter}.jpg"
    mv "$file" "$new_name"
    echo "Renamed $file → $new_name"
    ((counter++))
done

echo "Conversion and renaming complete! Files are in the '$output_dir' directory."