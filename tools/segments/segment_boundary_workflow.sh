#!/bin/bash

# Ayah boundaries adjustment workflow, this script:
# 1. Exports current ayah boundaries from database
# 2. Calculates optimal threshold we can use to detect silence for each gap between ayahs
# 3. Detects silences using optimal volume thresholds
# 4. Updates boundaries in the database using detected silences
# 5. Generates ayah segments and silence visualization(optional)

#
# Usage
# ./segment_boundary_workflow.sh RECITER SURAH AUDIO_FILE_PATH
# ./segment_boundary_workflow.sh 1 2 ./data/audio/1/wav/002.wav
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Ayah segment boundaries adjustment${NC}"
echo -e "${BLUE}Using gaps analysis around ayah start and end${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Parse arguments
RECITER=${1}
SURAH=${2}
AUDIO_FILE=${3}

if [ -z "$AUDIO_FILE" ]; then
    echo -e "${RED}Usage: $0 <reciter_id> <surah_number> <audio_file>${NC}"
    echo ""
    echo "Example:"
    echo "  $0 65 1 data/audio/65/wav/002.wav"
    echo ""
    echo "This workflow:"
    echo "  1. Exports current ayah boundaries from database"
    echo "  2. Calculates optimal threshold we can use to detect silence for each gap"
    echo "  3. Detects silences using optimal volume thresholds"
    echo "  4. Updates boundaries in the database using detected silences"
    echo "  5. Generates ayah segments and silence visualization(optional)"
    exit 1
fi

if [ ! -f "$AUDIO_FILE" ]; then
    echo -e "${RED}Error: Audio file not found: $AUDIO_FILE${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OUTPUT_DIR="$SCRIPT_DIR/data/result"
# current ayah boundaries
BOUNDARIES_DIR="$SCRIPT_DIR/data/result/boundaries/${RECITER}"
# Gaps thresholds results
GAPS_DIR="$SCRIPT_DIR/data/result/gaps/${RECITER}"
# Silences detected using per-gap thresholds
SILENCE_DIR="$SCRIPT_DIR/data/result/silences/${RECITER}"
# Visualization plot image and data
PLOT_DIR="$SCRIPT_DIR/data/result/plot_data/${RECITER}"

mkdir -p "$GAPS_DIR"
mkdir -p "$SILENCE_DIR"
mkdir -p "$PLOT_DIR"
mkdir -p "$BOUNDARIES_DIR"

BOUNDARIES_FILE="$BOUNDARIES_DIR/${SURAH}.json"
GAP_RESULT_FILE="$GAPS_DIR/${SURAH}.json"
SILENCES_FILE="$SILENCE_DIR/${SURAH}.json"
PLOT_FILE="$PLOT_DIR/${SURAH}.png"

echo -e "${GREEN}Configuration:${NC}"
echo "  Reciter: $RECITER"
echo "  Surah: $SURAH"
echo "  Audio: $AUDIO_FILE"
echo ""

# Step 1: Export boundaries
echo -e "${YELLOW}Step 1: Exporting boundaries from database...${NC}"
cd "$SCRIPT_DIR/../.." || exit 1

bundle exec rake segments:export_boundaries \
  RECITER="$RECITER" \
  SURAH="$SURAH" \
  OUTPUT_DIR="$BOUNDARIES_DIR"

if [ ! -f "$BOUNDARIES_FILE" ]; then
    echo -e "${RED}Error: Failed to export boundaries${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Boundaries exported${NC}"
echo ""

# Optional: run this quick diagnostic if gaps calculation is not accurate
#echo -e "${YELLOW}Checking gap volumes...${NC}"

cd "$SCRIPT_DIR" || exit 1

#echo ""
#python3 check_gap_volume.py "$AUDIO_FILE" "$BOUNDARIES_FILE"
#echo ""


# Step 2: Calculate per-gap thresholds
echo -e "${YELLOW}Step 2: Calculating optimal threshold for each gap...${NC}"
python3 calculate_gap_thresholds.py \
  "$AUDIO_FILE" \
  "$BOUNDARIES_FILE" \
  --offset 5 \
  --output "$GAP_RESULT_FILE"

echo ""
echo -e "${GREEN}✓ Gap thresholds calculated${NC}"
echo ""

# Step 3: Detect silences using per-gap thresholds
echo -e "${YELLOW}Step 3: Detecting silences with per-gap thresholds...${NC}"
python3 find_boundary_silences.py \
  --gap-thresholds "$GAP_RESULT_FILE" \
  --min-duration 30 \
  --window 200 \
  --exclude-overlapping \
  --output "$SILENCES_FILE"

echo ""
echo -e "${GREEN}✓ Detection complete${NC}"
echo ""

# Step 4: Refine boundaries using detected silences
echo -e "${YELLOW}Step 4: Refining boundaries in database...${NC}"
echo ""

if command -v jq &> /dev/null; then
    TOTAL_SILENCES=$(jq '[.[].silence_count] | add // 0' "$SILENCES_FILE")
    
    if [ "$TOTAL_SILENCES" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No silences detected - skipping refinement${NC}"
        echo "  • Gaps contain audio (reverb, breathing, room tone)"
        echo "  • Current boundaries are already optimal"
        echo ""
    else
        echo "Refining boundaries with detected silences..."
        cd "$SCRIPT_DIR/../.." || exit 1
        
        bundle exec rake segments:refine_with_silences \
          RECITER="$RECITER" \
          SURAH="$SURAH" \
          SILENCES_FILE="$SILENCES_FILE"
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✓ Boundaries refined and saved to database${NC}"
        else
            echo ""
            echo -e "${RED}✗ Refinement failed${NC}"
        fi
    fi
else
    # No jq, run refinement anyway
    echo "Running refinement..."
    cd "$SCRIPT_DIR/../.." || exit 1
    
    bundle exec rake segments:refine_with_silences \
      RECITER="$RECITER" \
      SURAH="$SURAH" \
      SILENCES_FILE="$SILENCES_FILE"
fi

echo ""

# Step 5: Summary
echo -e "${YELLOW}Step 5: Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Generated files:"
echo "  📄 Boundaries:    $BOUNDARIES_FILE"
echo "  ⚙️ Gap Results:    $GAP_RESULT_FILE"
echo "  🔍 Silences:      $SILENCES_FILE"
echo "  📊 Visualization: $PLOT_FILE"
echo "  📈 Plot Data:     ${PLOT_DIR}/${SURAH}.json"
echo ""

if command -v jq &> /dev/null; then
    TOTAL_SILENCES=$(jq '[.[].silence_count] | add // 0' "$SILENCES_FILE")
    AYAHS_WITH_SILENCES=$(jq '[.[] | select(.silence_count > 0)] | length' "$SILENCES_FILE")
    
    echo -e "${GREEN}Statistics:${NC}"
    echo "  Total Silences: $TOTAL_SILENCES"
    echo "  Ayahs with Silences: $AYAHS_WITH_SILENCES"
    echo ""
fi

echo -e "${GREEN}Next steps:${NC}"
echo "  1. Review Python visualization: open $PLOT_FILE"
echo "  2. View interactive plot with audio playback:"
echo "     http://localhost:3000/tools/plot_segments_timeline.html?reciter=$RECITER&surah=$SURAH"
echo "  3. Verify boundaries by playing ayahs in the browser"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Fully automated workflow complete!${NC}"
echo -e "${BLUE}Boundaries refined and ready to use${NC}"
echo -e "${BLUE}========================================${NC}"