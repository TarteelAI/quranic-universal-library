# Mushaf Page Ayah and Word boundaries detector

Detect ayah & words bounding rectangles from Mushaf page images.

## Overview

This tool detects ayah & words boundaries in Mushaf page images by:
1. Using pre-defined line boundaries (consistent rectangles)
2. Detecting ayah markers 
3. Calculating ayah rectangles for each page


## Quick Start

### 1. Place Source Images

```bash
mkdir -p mushaf-images
# Copy your Mushaf page images here (e.g., 1.jpg, 2.jpg, ...)
```

### 2. Extract Marker Templates (Once)

Extract sample markers from any page with clear markers:

```bash
python extract_marker_templates.py mushaf-images/5.jpg
```

**Controls:**
- Click and drag to select marker
- Resize: Drag corner/edge handles or use `HJKL` keys
- Move: Arrow keys or `WASD`
- Zoom: Mouse wheel or `+/-` keys
- Save: Press `S` (saves to `markers/` directory)
- Next: Press `N` to start selecting another marker
- Finish: Press `Q` when done

Extract 2-3 different marker samples for best results.

### 3. Extract Line Boundaries (Per Page)

For each page, define the text line boundaries:

```bash
python extract_line_boundaries.py mushaf-images/5.jpg
```

**Controls:**
- Same as marker extraction tool
- Press `N` to save current line and start next
- Press `F` to finish and save all lines

This creates `mushaf-images/line_boundaries/5_lines.json`

**Tip:** If all pages have identical line positions, extract once and reuse the JSON file.

### 4. Normalize Line Boundaries (Optional)

Make line dimensions consistent:

```bash
python normalize_line_boundaries.py mushaf-images/line_boundaries/5_lines.json
```

### 5. Extract Ayah Positions

Extract ayah rectangles for a page:

```bash
python extract_ayah_positions.py mushaf-images/5.jpg \
  --marker-templates mushaf-images/markers \
  --line-boundaries mushaf-images/line_boundaries/5_lines.json
```

**Output:**
- `output/5_ayah_positions.json` - Ayah rectangles data
- `output/5_ayah_visualization.jpg` - Visual verification

### 6. View Results

Open `viewer.html` in a browser:
1. Click "Choose JSON file" → load `output/5_ayah_positions.json`
2. Click "Choose Image file" → load `mushaf-images/5.jpg`
3. Explore ayahs, markers, and lines
4. Click on any element to scroll and highlight

## Output Format

```json
{
  "total_ayahs": 4,
  "total_markers": 3,
  "ayahs": [
    {
      "number": 1,
      "bbox": [x, y, width, height],
      "line_rects": [
        [x1, y1, w1, h1],
        [x2, y2, w2, h2]
      ],
      "marker": {
        "center": [x, y],
        "bbox": [x, y, w, h],
        "confidence": 0.997
      }
    }
  ]
}
```

## Processing Multiple Pages

Create a batch script to process all pages automatically:

```python
# process_all_pages.py
import subprocess
from pathlib import Path

for page_num in range(1, 605):  # 604 pages
    image_path = f'mushaf-images/{page_num}.jpg'
    
    # Skip if image doesn't exist
    if not Path(image_path).exists():
        continue
    
    subprocess.run([
        'python', 'extract_ayah_positions.py',
        image_path,
        '--marker-templates', 'mushaf-images/markers',
        '--line-boundaries', f'mushaf-images/line_boundaries/{page_num}_lines.json'
    ])
    
    print(f"Processed page {page_num}/604")
```

## Scripts

| Script | Purpose |
|--------|---------|
| `extract_marker_templates.py` | Interactive marker extraction |
| `extract_line_boundaries.py` | Interactive line boundary definition |
| `normalize_line_boundaries.py` | Make line dimensions consistent |
| `extract_ayah_positions.py` | Extract ayah rectangles (main script) |
| `viewer.html` | Interactive visualization and verification |

## Requirements

```bash
pip install opencv-python numpy
```

## Troubleshooting

**No markers detected:**
- Extract more marker samples with `extract_marker_templates.py`
- Try different pages with clear markers
- Adjust `--template-threshold` (default: 0.6)

**Wrong ayah boundaries:**
- Verify line boundaries in viewer
- Re-extract lines with `extract_line_boundaries.py`
- Normalize lines with `normalize_line_boundaries.py`

**Markers in wrong ayah:**
- Check marker position in visualization
- Verify marker templates are ayah-ending markers only
- Remove any non-ayah markers from `markers/` directory

## Support

Open `viewer.html` and click the **Help** button for interactive guide.
