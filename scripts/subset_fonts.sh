#!/bin/bash

font_path="app-v1"

mkdir -p "../fonts/${font_path}/optimized/ttf"
mkdir -p "../fonts/${font_path}/optimized/woff"
mkdir -p "../fonts/${font_path}/optimized/woff2"
mkdir -p "../fonts/${font_path}/optimized/ttx"
mkdir -p "../fonts/${font_path}/optimized/optimized-ttx"
mkdir -p "../fonts/${font_path}/optimized/svg"

# Export flags
export_ttf=true
export_woff=false
export_woff2=false
export_ttx=true
export_optimized_ttf_ttx=false
export_svg=false

i=1
while IFS= read -r unicode_line || [ -n "$unicode_line" ]; do
  if [ "$i" -ne 175 ]; then
      i=$((i + 1))
      continue
  fi

  name=$(printf "QCF_P%03d.ttf" "$i")
  font="../fonts/${font_path}/$name"
  file=$(printf "QCF_P%03d" "$i")

  base_path="../fonts/${font_path}"

  if [[ -f "$font" ]]; then
    echo "Processing $font with unicodes: $unicode_line"

    # The rest can still use pyftsubset if needed

    # TTF
    if [ "$export_ttf" = true ]; then
     pyftsubset "$font" \
       --output-file="${base_path}/optimized/ttf/${file}.ttf" \
       --unicodes="$unicode_line" \
       --glyph-names \
       --retain-gids \
       --symbol-cmap \
       --legacy-cmap \
       --layout-features='*' \
       --notdef-glyph \
       --notdef-outline \
       --no-layout-closure \
       --recommended-glyphs \
       --name-languages=* \
       --name-IDs=* \
       --name-legacy \
       --hinting \
       --no-recalc-bounds \
       --verbose=true
    fi

    # WOFF
    if [ "$export_woff" = true ]; then
      pyftsubset "$font" --verbose=true \
        --output-file="${base_path}/optimized/woff/${file}.woff" \
        --flavor=woff \
        --unicodes="$unicode_line"
    fi

    # WOFF2
    if [ "$export_woff2" = true ]; then
      pyftsubset "$font" --verbose=true \
        --output-file="${base_path}/optimized/woff2/${file}.woff2" \
        --flavor=woff2 \
        --unicodes="$unicode_line"
    fi

    # TTX
    if [ "$export_ttx" = true ]; then
      ttx -o "${base_path}/optimized/ttx/${file}.ttx" "$font"
    fi

    if [ "$export_optimized_ttf_ttx" = true ]; then
      ttx -o "${base_path}/optimized/optimized-ttx/${file}.ttx" "${base_path}/optimized/ttf/${file}.ttf"
    fi

    # SVG (assuming ttf2svg is installed and in PATH)
    if [ "$export_svg" = true ]; then
      ttf2svg "$font" "${base_path}/optimized/svg/${file}.svg"
    fi

    echo "✅ Processed: $font"
  else
    echo "❌ Font file not found: $font"
  fi

  i=$((i + 1))
done < unicodes.txt
