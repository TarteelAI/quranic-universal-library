#!/usr/bin/env python3
"""

This script extracts ayah bounding rectangles.
It focuses ONLY on ayah positions, not individual word detection.

Approach:
1. Use pre-defined line boundaries (consistent rectangles)
2. Detect ayah markers (template matching)
3. Calculate ayah rectangles based on marker positions
4. For RTL text: ayah ENDS at marker position
"""

import cv2
import numpy as np
import json
import argparse
from pathlib import Path
from typing import List, Dict, Tuple, Optional


class AyahPositionExtractor:
    def __init__(self, 
                 marker_templates_dir: Optional[str] = None,
                 template_match_threshold: float = 0.6,
                 line_boundaries_file: Optional[str] = None):
        """
        Initialize the extractor.
        
        Args:
            marker_templates_dir: Directory containing marker template images
            template_match_threshold: Template matching confidence threshold
            line_boundaries_file: JSON file with pre-defined line boundaries
        """
        self.marker_templates_dir = marker_templates_dir
        self.template_match_threshold = template_match_threshold
        self.line_boundaries_file = line_boundaries_file
        self.line_boundaries = None
        self.marker_templates = []
        
        if marker_templates_dir:
            self._load_marker_templates()
        
        if line_boundaries_file:
            self._load_line_boundaries()
    
    def _load_marker_templates(self):
        """Load marker template images."""
        templates_path = Path(self.marker_templates_dir)
        if not templates_path.exists():
            print(f"Warning: Marker templates directory not found: {self.marker_templates_dir}")
            return
        
        for template_file in templates_path.glob('*.png'):
            template = cv2.imread(str(template_file), cv2.IMREAD_GRAYSCALE)
            if template is not None:
                self.marker_templates.append({
                    'image': template,
                    'name': template_file.name,
                    'size': template.shape
                })
        
        print(f"Loaded {len(self.marker_templates)} marker template(s)")
    
    def _load_line_boundaries(self):
        """Load pre-defined line boundaries from JSON."""
        with open(self.line_boundaries_file, 'r') as f:
            data = json.load(f)
            self.line_boundaries = data['lines']
        
        print(f"Loaded {len(self.line_boundaries)} line boundaries from {self.line_boundaries_file}")
    
    def preprocess_image(self, image: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """Preprocess image for marker detection."""
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Apply bilateral filter to reduce noise while preserving edges
        gray = cv2.bilateralFilter(gray, 9, 75, 75)
        
        # Adaptive thresholding
        binary = cv2.adaptiveThreshold(
            gray, 
            255, 
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
            cv2.THRESH_BINARY_INV, 
            21, 
            10
        )
        
        return gray, binary
    
    def detect_markers(self, gray: np.ndarray) -> List[Dict]:
        """
        Detect ayah markers using template matching.
        
        Returns:
            List of marker dictionaries with center and bbox
        """
        if not self.marker_templates:
            return []
        
        all_matches = []
        
        for template_info in self.marker_templates:
            template = template_info['image']
            th, tw = template.shape
            
            # Try multiple scales
            for scale in [0.8, 0.9, 1.0, 1.1, 1.2]:
                # Resize template
                new_w = int(tw * scale)
                new_h = int(th * scale)
                scaled_template = cv2.resize(template, (new_w, new_h))
                
                # Template matching
                result = cv2.matchTemplate(gray, scaled_template, cv2.TM_CCOEFF_NORMED)
                
                # Find matches above threshold
                locations = np.where(result >= self.template_match_threshold)
                
                for pt in zip(*locations[::-1]):
                    confidence = result[pt[1], pt[0]]
                    
                    # Calculate center and bbox
                    center_x = int(pt[0] + new_w / 2)
                    center_y = int(pt[1] + new_h / 2)
                    
                    all_matches.append({
                        'center': [center_x, center_y],
                        'bbox': [int(pt[0]), int(pt[1]), new_w, new_h],
                        'confidence': float(confidence),
                        'template': template_info['name'],
                        'scale': scale
                    })
        
        # Apply Non-Maximum Suppression
        markers = self._non_max_suppression(all_matches)
        
        # Sort by y-position (top to bottom)
        markers.sort(key=lambda m: m['center'][1])
        
        print(f"Detected {len(markers)} markers")
        return markers
    
    def _non_max_suppression(self, matches: List[Dict], overlap_thresh: float = 0.3) -> List[Dict]:
        """Remove overlapping marker detections."""
        if not matches:
            return []
        
        # Sort by confidence
        matches = sorted(matches, key=lambda m: m['confidence'], reverse=True)
        
        kept = []
        
        for match in matches:
            # Check if this match overlaps with any kept match
            overlap = False
            mx, my = match['center']
            
            for kept_match in kept:
                kx, ky = kept_match['center']
                distance = np.sqrt((mx - kx)**2 + (my - ky)**2)
                
                # If centers are very close, consider it a duplicate
                if distance < 50:  # 50 pixels threshold
                    overlap = True
                    break
            
            if not overlap:
                kept.append(match)
        
        return kept
    
    def calculate_ayah_rectangles(self, markers: List[Dict]) -> List[Dict]:
        """
        Calculate ayah rectangles based on line boundaries and markers.
        
        For RTL text:
        - Ayah ENDS at marker position (marker x = ayah end x)
        - If no marker on line, ayah continues to next line
        
        Args:
            markers: List of detected markers
            
        Returns:
            List of ayah dictionaries with rectangles
        """
        if not self.line_boundaries:
            raise ValueError("Line boundaries required for ayah calculation")
        
        ayahs = []
        current_ayah_lines = []
        ayah_number = 1
        marker_idx = 0
        
        for line in self.line_boundaries:
            line_bbox = line['bbox']
            line_x, line_y, line_w, line_h = line_bbox
            line_center_y = line_y + line_h // 2
            
            # Check if there's a marker on this line
            # Find the CLOSEST marker to this line's center
            marker_on_line = None
            if marker_idx < len(markers):
                marker = markers[marker_idx]
                marker_y = marker['center'][1]
                
                # Calculate distance from marker to this line's center
                distance = abs(marker_y - line_center_y)
                
                # Marker is on this line if it's the closest line
                # Use generous threshold (line_h * 1.5) to catch markers between lines
                if distance < line_h * 1.5:
                    # Check if this is closer than the next line (if exists)
                    is_closest = True
                    next_line_idx = self.line_boundaries.index(line) + 1
                    if next_line_idx < len(self.line_boundaries):
                        next_line = self.line_boundaries[next_line_idx]
                        next_line_center = next_line['bbox'][1] + next_line['bbox'][3] // 2
                        if abs(marker_y - next_line_center) < distance:
                            is_closest = False
                    
                    if is_closest:
                        marker_on_line = marker
            
            if marker_on_line:
                # Split line at marker's LEFT edge (include full marker in previous ayah)
                marker_bbox = marker_on_line.get('bbox', [marker_on_line['center'][0] - 30, 0, 60, 60])
                marker_left_x = marker_bbox[0]  # Left edge of marker
                
                # Calculate width of left part (space before marker)
                left_width = marker_left_x - line_x
                
                # If left part is tiny (< 30 pixels), it's just empty space
                # Include it in current ayah, next ayah starts on next line
                if left_width < 30:
                    # Current ayah gets the full line (including tiny space + marker)
                    right_rect = [line_x, line_y, line_w, line_h]
                    current_ayah_lines.append(right_rect)
                    
                    # Finalize current ayah
                    ayahs.append({
                        'number': ayah_number,
                        'line_rects': current_ayah_lines,
                        'bbox': self._calculate_bounding_box(current_ayah_lines),
                        'marker': marker_on_line
                    })
                    
                    ayah_number += 1
                    marker_idx += 1
                    
                    # Next ayah starts fresh on next line
                    current_ayah_lines = []
                else:
                    # Normal split: left part is significant
                    # Right part (higher x in RTL) = current ayah (includes marker)
                    right_rect = [marker_left_x, line_y, line_x + line_w - marker_left_x, line_h]
                    current_ayah_lines.append(right_rect)
                    
                    # Finalize current ayah
                    ayahs.append({
                        'number': ayah_number,
                        'line_rects': current_ayah_lines,
                        'bbox': self._calculate_bounding_box(current_ayah_lines),
                        'marker': marker_on_line
                    })
                    
                    ayah_number += 1
                    marker_idx += 1
                    
                    # Left part (lower x in RTL) = next ayah
                    left_rect = [line_x, line_y, left_width, line_h]
                    current_ayah_lines = [left_rect]
            else:
                # No marker, entire line belongs to current ayah
                current_ayah_lines.append([line_x, line_y, line_w, line_h])
        
        # Add remaining lines as final ayah
        if current_ayah_lines:
            ayahs.append({
                'number': ayah_number,
                'line_rects': current_ayah_lines,
                'bbox': self._calculate_bounding_box(current_ayah_lines),
                'marker': None
            })
        
        return ayahs
    
    def _calculate_bounding_box(self, rects: List[List[int]]) -> List[int]:
        """Calculate overall bounding box from multiple rectangles."""
        if not rects:
            return [0, 0, 0, 0]
        
        min_x = min(r[0] for r in rects)
        min_y = min(r[1] for r in rects)
        max_x = max(r[0] + r[2] for r in rects)
        max_y = max(r[1] + r[3] for r in rects)
        
        return [int(min_x), int(min_y), int(max_x - min_x), int(max_y - min_y)]
    
    def extract_page(self, image_path: str) -> Dict:
        """
        Extract ayah positions from a page image.
        
        Args:
            image_path: Path to the page image
            
        Returns:
            Dictionary with ayah positions
        """
        # Load image
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Could not load image: {image_path}")
        
        # Preprocess
        gray, binary = self.preprocess_image(image)
        
        # Detect markers
        markers = self.detect_markers(gray)
        
        # Calculate ayah rectangles
        ayahs = self.calculate_ayah_rectangles(markers)
        
        # Prepare result
        result = {
            'image_path': image_path,
            'image_size': {
                'width': image.shape[1],
                'height': image.shape[0]
            },
            'total_ayahs': len(ayahs),
            'total_markers': len(markers),
            'ayahs': ayahs,
            'markers_raw': markers
        }
        
        return result
    
    def visualize_results(self, image_path: str, result: Dict, output_path: str):
        """Draw ayah rectangles on image."""
        image = cv2.imread(image_path)
        vis_image = image.copy()
        
        # Define colors for ayahs
        colors = [
            (40, 167, 69),    # Green
            (0, 123, 255),    # Blue
            (253, 126, 20),   # Orange
            (111, 66, 193),   # Purple
            (232, 62, 140),   # Pink
            (32, 201, 151),   # Teal
            (23, 162, 184),   # Cyan
        ]
        
        # Draw ayah rectangles
        for i, ayah in enumerate(result['ayahs']):
            color = colors[i % len(colors)]
            
            # Draw each line rectangle
            for rect in ayah['line_rects']:
                x, y, w, h = rect
                cv2.rectangle(vis_image, (x, y), (x + w, y + h), color, 3)
            
            # Draw ayah number
            if ayah['line_rects']:
                first_rect = ayah['line_rects'][0]
                label_x = first_rect[0] + first_rect[2] - 40
                label_y = first_rect[1] + 30
                cv2.putText(vis_image, f"A{ayah['number']}", (label_x, label_y),
                           cv2.FONT_HERSHEY_SIMPLEX, 1, color, 3)
        
        # Draw markers
        for marker in result['markers_raw']:
            cx, cy = marker['center']
            cv2.circle(vis_image, (cx, cy), 25, (0, 0, 255), 3)
            cv2.circle(vis_image, (cx, cy), 5, (0, 0, 255), -1)
        
        # Save
        cv2.imwrite(output_path, vis_image)
        print(f"Visualization saved to: {output_path}")
    
    def save_json(self, result: Dict, output_path: str):
        """Save results to JSON file."""
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        
        print(f"JSON results saved to: {output_path}")


def main():
    """Main function for command-line usage."""
    parser = argparse.ArgumentParser(
        description='Extract ayah positions from Mushaf page image'
    )
    parser.add_argument(
        'image_path', 
        type=str, 
        help='Path to the Mushaf page image'
    )
    parser.add_argument(
        '--output-dir', 
        type=str, 
        default='output',
        help='Directory to save output files (default: output)'
    )
    parser.add_argument(
        '--marker-templates', 
        type=str,
        required=True,
        help='Path to directory containing marker template images'
    )
    parser.add_argument(
        '--template-threshold', 
        type=float, 
        default=0.6,
        help='Template matching threshold 0-1 (default: 0.6)'
    )
    parser.add_argument(
        '--line-boundaries',
        type=str,
        required=True,
        help='Path to JSON file with pre-defined line boundaries'
    )
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Initialize extractor
    extractor = AyahPositionExtractor(
        marker_templates_dir=args.marker_templates,
        template_match_threshold=args.template_threshold,
        line_boundaries_file=args.line_boundaries
    )
    
    # Extract
    print(f"Processing: {args.image_path}")
    result = extractor.extract_page(args.image_path)
    
    # Print summary
    print(f"\nExtraction Summary:")
    print(f"  Total Ayahs: {result['total_ayahs']}")
    print(f"  Total Markers: {result['total_markers']}")
    
    # Generate output filenames
    image_stem = Path(args.image_path).stem
    json_path = output_dir / f"{image_stem}_ayah_positions.json"
    vis_path = output_dir / f"{image_stem}_ayah_visualization.jpg"
    
    # Save results
    extractor.save_json(result, str(json_path))
    extractor.visualize_results(args.image_path, result, str(vis_path))
    
    print(f"\nProcessing complete!")


if __name__ == '__main__':
    main()

