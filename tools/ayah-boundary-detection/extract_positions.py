"""
Quran Page Word & Ayah Position Extractor

This module extracts ayah and word bounding boxes from Mushaf page images.
Inspired by:
- https://github.com/quran/ayah-detection
- https://github.com/Fahad-alkamli/extract-ayah-using-opencv
"""

import cv2
import numpy as np
import json
from pathlib import Path
from typing import List, Dict, Tuple, Optional
import argparse


class MushafPageExtractor:
    """Extract ayah and word positions from a Mushaf page image."""
    
    def __init__(self, 
                 min_word_width: int = 20,
                 min_word_height: int = 20,
                 max_word_width: int = 500,
                 max_word_height: int = 200,
                 word_spacing_threshold: int = 15,
                 ayah_marker_min_area: int = 100,
                 ayah_marker_max_area: int = 2000,
                 marker_templates_dir: Optional[str] = None,
                 template_match_threshold: float = 0.6,
                 line_boundaries_file: Optional[str] = None,
                 debug: bool = False):
        """
        Initialize the extractor with configurable parameters.
        
        Args:
            min_word_width: Minimum width for word bounding boxes
            min_word_height: Minimum height for word bounding boxes
            max_word_width: Maximum width for word bounding boxes
            max_word_height: Maximum height for word bounding boxes
            word_spacing_threshold: Maximum horizontal gap between words (pixels)
            ayah_marker_min_area: Minimum area for ayah markers
            ayah_marker_max_area: Maximum area for ayah markers
            marker_templates_dir: Path to directory containing marker template images
            template_match_threshold: Threshold for template matching (0-1)
            line_boundaries_file: Path to JSON file with manually defined line boundaries
            debug: Enable debug visualizations
        """
        self.min_word_width = min_word_width
        self.min_word_height = min_word_height
        self.max_word_width = max_word_width
        self.max_word_height = max_word_height
        self.word_spacing_threshold = word_spacing_threshold
        self.ayah_marker_min_area = ayah_marker_min_area
        self.ayah_marker_max_area = ayah_marker_max_area
        self.marker_templates_dir = marker_templates_dir
        self.template_match_threshold = template_match_threshold
        self.line_boundaries_file = line_boundaries_file
        self.debug = debug
        self.marker_templates = []
        self.line_boundaries = None
        
        # Load marker templates if directory provided
        if marker_templates_dir:
            self._load_marker_templates()
        
        # Load line boundaries if file provided
        if line_boundaries_file:
            self._load_line_boundaries()
    
    def _load_marker_templates(self):
        """Load marker template images from the specified directory."""
        templates_path = Path(self.marker_templates_dir)
        
        if not templates_path.exists():
            print(f"Warning: Marker templates directory not found: {self.marker_templates_dir}")
            return
        
        # Supported image formats
        image_extensions = ['*.jpg', '*.jpeg', '*.png', '*.bmp', '*.tiff']
        
        for ext in image_extensions:
            for template_path in templates_path.glob(ext):
                try:
                    # Load template image
                    template = cv2.imread(str(template_path))
                    if template is not None:
                        # Convert to grayscale
                        template_gray = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)
                        
                        self.marker_templates.append({
                            'name': template_path.name,
                            'image': template_gray,
                            'height': template_gray.shape[0],
                            'width': template_gray.shape[1]
                        })
                        
                        if self.debug:
                            print(f"Loaded marker template: {template_path.name} "
                                  f"({template_gray.shape[1]}x{template_gray.shape[0]})")
                except Exception as e:
                    print(f"Error loading template {template_path}: {e}")
        
        if self.marker_templates:
            print(f"Loaded {len(self.marker_templates)} marker template(s)")
        else:
            print(f"Warning: No marker templates found in {self.marker_templates_dir}")
    
    def _load_line_boundaries(self):
        """Load manually defined line boundaries from JSON file."""
        try:
            with open(self.line_boundaries_file, 'r') as f:
                data = json.load(f)
                self.line_boundaries = data.get('lines', [])
                if self.line_boundaries:
                    print(f"Loaded {len(self.line_boundaries)} line boundaries from {self.line_boundaries_file}")
                else:
                    print(f"Warning: No line boundaries found in {self.line_boundaries_file}")
        except Exception as e:
            print(f"Error loading line boundaries: {e}")
            self.line_boundaries = None
    
    def detect_markers_with_templates(self, gray: np.ndarray) -> List[Dict]:
        """
        Detect ayah markers using template matching.
        
        Args:
            gray: Grayscale image
            
        Returns:
            List of marker dictionaries with bbox and center
        """
        if not self.marker_templates:
            return []
        
        markers = []
        height, width = gray.shape
        
        # For each template
        for template_info in self.marker_templates:
            template = template_info['image']
            t_h, t_w = template.shape
            
            # Try multiple scales (to handle size variations)
            scales = [0.7, 0.85, 1.0, 1.15, 1.3, 1.5]
            
            for scale in scales:
                # Resize template
                scaled_w = int(t_w * scale)
                scaled_h = int(t_h * scale)
                
                # Skip if scaled template is larger than image
                if scaled_w > width or scaled_h > height:
                    continue
                
                scaled_template = cv2.resize(template, (scaled_w, scaled_h))
                
                # Perform template matching
                result = cv2.matchTemplate(gray, scaled_template, cv2.TM_CCOEFF_NORMED)
                
                # Find matches above threshold
                locations = np.where(result >= self.template_match_threshold)
                
                for pt in zip(*locations[::-1]):  # Switch x and y
                    x, y = pt
                    w, h = scaled_w, scaled_h
                    
                    # Check if this marker overlaps with existing markers
                    overlap = False
                    for existing in markers:
                        ex, ey, ew, eh = existing['bbox']
                        # Simple overlap check
                        if (abs(x - ex) < ew and abs(y - ey) < eh):
                            overlap = True
                            break
                    
                    if not overlap:
                        center_x = x + w // 2
                        center_y = y + h // 2
                        
                        # Get match confidence
                        confidence = result[y, x]
                        
                        markers.append({
                            'bbox': [int(x), int(y), int(w), int(h)],
                            'center': [int(center_x), int(center_y)],
                            'confidence': float(confidence),
                            'template': template_info['name'],
                            'scale': scale
                        })
        
        # Remove duplicate detections (non-maximum suppression)
        markers = self._non_max_suppression(markers)
        
        # Sort markers by position (top to bottom, right to left for Arabic)
        markers.sort(key=lambda m: (m['center'][1], -m['center'][0]))
        
        if self.debug:
            print(f"Detected {len(markers)} markers using template matching")
        
        return markers
    
    def _non_max_suppression(self, markers: List[Dict], overlap_thresh: float = 0.3) -> List[Dict]:
        """
        Apply non-maximum suppression to remove duplicate detections.
        
        Args:
            markers: List of marker detections
            overlap_thresh: IoU threshold for considering detections as duplicates
            
        Returns:
            Filtered list of markers
        """
        if not markers:
            return []
        
        # Sort by confidence
        markers = sorted(markers, key=lambda m: m.get('confidence', 0), reverse=True)
        
        keep = []
        
        for marker in markers:
            x1, y1, w1, h1 = marker['bbox']
            
            # Check overlap with kept markers
            should_keep = True
            for kept in keep:
                x2, y2, w2, h2 = kept['bbox']
                
                # Calculate intersection over union (IoU)
                x_left = max(x1, x2)
                y_top = max(y1, y2)
                x_right = min(x1 + w1, x2 + w2)
                y_bottom = min(y1 + h1, y2 + h2)
                
                if x_right > x_left and y_bottom > y_top:
                    intersection = (x_right - x_left) * (y_bottom - y_top)
                    area1 = w1 * h1
                    area2 = w2 * h2
                    union = area1 + area2 - intersection
                    
                    iou = intersection / union if union > 0 else 0
                    
                    if iou > overlap_thresh:
                        should_keep = False
                        break
            
            if should_keep:
                keep.append(marker)
        
        return keep
        
    def preprocess_image(self, image: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Preprocess the image for better text and marker detection.
        
        Args:
            image: Input BGR image
            
        Returns:
            Tuple of (grayscale image, binary threshold image)
        """
        # Convert to grayscale
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Apply bilateral filter to reduce noise while preserving edges
        filtered = cv2.bilateralFilter(gray, 9, 75, 75)
        
        # Apply adaptive thresholding for better results with varying lighting
        binary = cv2.adaptiveThreshold(
            filtered, 
            255, 
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
            cv2.THRESH_BINARY_INV, 
            21, 
            10
        )
        
        if self.debug:
            print("Debug: Displaying preprocessed images (press any key to continue, or wait 3 seconds)...")
            cv2.imshow("Grayscale", gray)
            cv2.imshow("Binary", binary)
            cv2.waitKey(3000)  # Wait 3 seconds or until key press
            cv2.destroyAllWindows()  # Clean up windows
            
        return gray, binary
    
    def detect_ayah_markers(self, gray: np.ndarray, binary: np.ndarray) -> List[Dict]:
        """
        Detect ayah markers using template matching (if templates available) 
        or geometric detection as fallback.
        
        Args:
            gray: Grayscale image
            binary: Binary threshold image
            
        Returns:
            List of ayah marker dictionaries with bbox and center
        """
        # Try template matching first if templates are loaded
        if self.marker_templates:
            markers = self.detect_markers_with_templates(gray)
            if markers:
                if self.debug:
                    print(f"Using template matching: found {len(markers)} markers")
                return markers
            elif self.debug:
                print("Template matching found no markers, falling back to geometric detection")
        
        # Fallback to geometric detection
        markers = []
        
        # Find contours
        contours, _ = cv2.findContours(
            binary, 
            cv2.RETR_EXTERNAL, 
            cv2.CHAIN_APPROX_SIMPLE
        )
        
        for contour in contours:
            area = cv2.contourArea(contour)
            
            # Filter by area (ayah markers are typically circular/decorative)
            if self.ayah_marker_min_area < area < self.ayah_marker_max_area:
                x, y, w, h = cv2.boundingRect(contour)
                
                # Check aspect ratio (markers are usually roundish)
                aspect_ratio = w / float(h) if h > 0 else 0
                
                # Circular objects have aspect ratio close to 1
                if 0.7 < aspect_ratio < 1.3:
                    # Check circularity
                    perimeter = cv2.arcLength(contour, True)
                    if perimeter > 0:
                        circularity = 4 * np.pi * area / (perimeter * perimeter)
                        
                        # High circularity indicates a marker
                        if circularity > 0.5:
                            center_x = x + w // 2
                            center_y = y + h // 2
                            
                            markers.append({
                                'bbox': [int(x), int(y), int(w), int(h)],
                                'center': [int(center_x), int(center_y)],
                                'area': float(area),
                                'circularity': float(circularity)
                            })
        
        # Sort markers by y-coordinate (top to bottom), then x-coordinate (right to left for Arabic)
        markers.sort(key=lambda m: (m['center'][1], -m['center'][0]))
        
        if self.debug:
            print(f"Geometric detection found {len(markers)} markers")
        
        return markers
    
    def detect_text_lines(self, binary: np.ndarray) -> List[Tuple[int, int, int, int]]:
        """
        Detect text lines on the page.
        
        Args:
            binary: Binary threshold image
            
        Returns:
            List of line bounding boxes (x, y, w, h)
        """
        # Use horizontal morphological operations to connect words in lines
        kernel_length = binary.shape[1] // 30  # Adaptive kernel size
        horizontal_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kernel_length, 1))
        
        # Detect horizontal lines
        detect_horizontal = cv2.morphologyEx(binary, cv2.MORPH_OPEN, horizontal_kernel)
        
        # Find contours of lines
        contours, _ = cv2.findContours(
            detect_horizontal, 
            cv2.RETR_EXTERNAL, 
            cv2.CHAIN_APPROX_SIMPLE
        )
        
        lines = []
        for contour in contours:
            x, y, w, h = cv2.boundingRect(contour)
            
            # Filter out very small or very thin contours
            if w > 100 and h > 10:
                lines.append((x, y, w, h))
        
        # Sort lines from top to bottom
        lines.sort(key=lambda l: l[1])
        
        return lines
    
    def detect_words_in_line(self, 
                            binary: np.ndarray, 
                            line_bbox: Tuple[int, int, int, int]) -> List[Dict]:
        """
        Detect individual words within a text line.
        
        Args:
            binary: Binary threshold image
            line_bbox: Bounding box of the line (x, y, w, h)
            
        Returns:
            List of word dictionaries with bbox
        """
        x, y, w, h = line_bbox
        
        # Extract the line region
        line_roi = binary[y:y+h, x:x+w]
        
        # Apply morphological operations to separate words
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        morphed = cv2.morphologyEx(line_roi, cv2.MORPH_CLOSE, kernel)
        
        # Find contours (words)
        contours, _ = cv2.findContours(
            morphed, 
            cv2.RETR_EXTERNAL, 
            cv2.CHAIN_APPROX_SIMPLE
        )
        
        words = []
        for contour in contours:
            wx, wy, ww, wh = cv2.boundingRect(contour)
            
            # Filter by size
            if (self.min_word_width < ww < self.max_word_width and 
                self.min_word_height < wh < self.max_word_height):
                
                # Convert to absolute coordinates
                abs_x = x + wx
                abs_y = y + wy
                
                words.append({
                    'bbox': [int(abs_x), int(abs_y), int(ww), int(wh)],
                    'line_y': int(y)
                })
        
        # Sort words from right to left (Arabic reads right to left)
        words.sort(key=lambda w: -w['bbox'][0])
        
        return words
    
    def detect_words_direct(self, binary: np.ndarray) -> List[Dict]:
        """
        Detect words directly from binary image with improved segmentation.
        This uses vertical projection to separate connected words.
        
        Args:
            binary: Binary threshold image
            
        Returns:
            List of word dictionaries with bbox
        """
        # First try: use morphological opening to separate connected components
        # This is gentler than the previous approach
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        opened = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel, iterations=1)
        
        # Find all contours
        contours, _ = cv2.findContours(
            opened, 
            cv2.RETR_EXTERNAL, 
            cv2.CHAIN_APPROX_SIMPLE
        )
        
        words = []
        large_blobs = []
        
        for contour in contours:
            area = cv2.contourArea(contour)
            x, y, w, h = cv2.boundingRect(contour)
            
            # If this is a huge blob, it's likely multiple words connected
            if w > 300 or h > 200 or area > 50000:
                large_blobs.append((x, y, w, h))
                continue
            
            # Filter by size
            if (self.min_word_width < w < self.max_word_width and 
                self.min_word_height < h < self.max_word_height):
                
                # Additional filters to avoid markers and decorations
                aspect_ratio = w / float(h) if h > 0 else 0
                
                # Words are usually more horizontal than square
                # Markers are circular (aspect_ratio ~1)
                if aspect_ratio > 0.3:  # Not too vertical
                    words.append({
                        'bbox': [int(x), int(y), int(w), int(h)],
                        'area': float(area),
                        'aspect_ratio': float(aspect_ratio)
                    })
        
        # Try to segment large blobs using vertical projection
        for blob_x, blob_y, blob_w, blob_h in large_blobs:
            # Extract blob region
            blob_roi = opened[blob_y:blob_y+blob_h, blob_x:blob_x+blob_w]
            
            # Calculate vertical projection (sum of pixels in each column)
            vertical_projection = np.sum(blob_roi, axis=0)
            
            # Find gaps (columns with low pixel count)
            threshold = np.mean(vertical_projection) * 0.1  # 10% of mean
            gaps = vertical_projection < threshold
            
            # Find gap regions
            gap_starts = []
            gap_ends = []
            in_gap = False
            
            for i, is_gap in enumerate(gaps):
                if is_gap and not in_gap:
                    gap_starts.append(i)
                    in_gap = True
                elif not is_gap and in_gap:
                    gap_ends.append(i)
                    in_gap = False
            
            if in_gap:
                gap_ends.append(len(gaps))
            
            # Split blob at significant gaps
            if len(gap_starts) > 0:
                prev_end = 0
                for gap_start, gap_end in zip(gap_starts, gap_ends):
                    gap_width = gap_end - gap_start
                    
                    # Only split at significant gaps (at least 3 pixels wide)
                    if gap_width >= 3 and prev_end < gap_start:
                        word_w = gap_start - prev_end
                        if word_w > self.min_word_width:
                            words.append({
                                'bbox': [int(blob_x + prev_end), int(blob_y), int(word_w), int(blob_h)],
                                'area': float(word_w * blob_h),
                                'aspect_ratio': float(word_w / blob_h) if blob_h > 0 else 0
                            })
                        prev_end = gap_end
                
                # Add final segment
                if prev_end < blob_w:
                    word_w = blob_w - prev_end
                    if word_w > self.min_word_width:
                        words.append({
                            'bbox': [int(blob_x + prev_end), int(blob_y), int(word_w), int(blob_h)],
                            'area': float(word_w * blob_h),
                            'aspect_ratio': float(word_w / blob_h) if blob_h > 0 else 0
                        })
        
        if self.debug:
            print(f"Direct detection found {len(words)} word candidates (including {len(large_blobs)} segmented blobs)")
        
        # Filter out words outside line boundaries (page numbers, headers, etc.)
        if words and self.line_boundaries:
            words = self.filter_words_outside_boundaries(words)
            if self.debug:
                print(f"After filtering outside boundaries: {len(words)} words")
        
        # Merge words that are too close together (likely parts of same word)
        if words and self.word_spacing_threshold > 0:
            words = self.merge_close_words(words)
            if self.debug:
                print(f"After merging close words: {len(words)} words")
        
        # Correct word heights using line boundaries if available
        if words and self.line_boundaries:
            words = self.correct_word_heights_with_lines(words)
            if self.debug:
                print(f"Corrected word heights using line boundaries")
            
            # After height correction, words on same line might be close - merge again
            if self.word_spacing_threshold > 0:
                words = self.merge_close_words(words)
                if self.debug:
                    print(f"After merging post-correction: {len(words)} words")
        
        # Group words by approximate line (y-coordinate)
        # Skip this if we already have line_y from height correction
        if words:
            # Check if words already have line_y set (from height correction)
            has_line_y = all('line_y' in w for w in words)
            
            if has_line_y and self.line_boundaries:
                # Already have correct line_y from height correction, don't overwrite
                if self.debug:
                    print(f"Using line_y from height correction")
                return words
            
            # Otherwise, cluster words by y-coordinate
            words_with_line = []
            words.sort(key=lambda w: w['bbox'][1])  # Sort by y
            
            current_line_y = words[0]['bbox'][1]
            line_threshold = 30  # pixels
            
            for word in words:
                y = word['bbox'][1]
                # If word is roughly on the same line, use current line_y
                if abs(y - current_line_y) < line_threshold:
                    word['line_y'] = current_line_y
                else:
                    current_line_y = y
                    word['line_y'] = y
                words_with_line.append(word)
            
            return words_with_line
        
        return []
    
    def merge_close_words(self, words: List[Dict]) -> List[Dict]:
        """
        Merge words that are too close together (likely parts of same word).
        
        Args:
            words: List of word dictionaries
            
        Returns:
            List of merged words
        """
        if not words:
            return words
        
        # Sort by line, then by x position (right to left for Arabic)
        words_with_line = []
        for word in words:
            if 'line_y' not in word:
                word['line_y'] = word['bbox'][1]
            words_with_line.append(word)
        
        words_with_line.sort(key=lambda w: (w['line_y'], -w['bbox'][0]))
        
        merged = []
        current_word = None
        
        for word in words_with_line:
            if current_word is None:
                current_word = word.copy()
                continue
            
            # Check if on same line
            if abs(word['line_y'] - current_word['line_y']) < 20:
                # Calculate horizontal gap (for RTL Arabic)
                current_x = current_word['bbox'][0]
                current_right = current_x + current_word['bbox'][2]
                word_x = word['bbox'][0]
                word_right = word_x + word['bbox'][2]
                
                # Gap is the distance between the words
                gap = abs(current_x - word_right)
                
                # If gap is small, merge them
                if gap < self.word_spacing_threshold:
                    # Merge bounding boxes
                    new_x = min(current_x, word_x)
                    
                    # Preserve corrected line_y if available, otherwise use bbox
                    if 'corrected_height' in current_word and 'corrected_height' in word:
                        # Both have corrected heights, use line_y
                        new_y = current_word['line_y']
                        new_h = current_word['bbox'][3]  # Use corrected height
                    else:
                        # Use original bbox logic
                        new_y = min(current_word['bbox'][1], word['bbox'][1])
                        new_bottom = max(
                            current_word['bbox'][1] + current_word['bbox'][3],
                            word['bbox'][1] + word['bbox'][3]
                        )
                        new_h = new_bottom - new_y
                    
                    new_right = max(current_right, word_right)
                    new_w = new_right - new_x
                    
                    current_word['bbox'] = [new_x, new_y, new_w, new_h]
                    current_word['area'] = new_w * new_h
                    current_word['aspect_ratio'] = new_w / new_h if new_h > 0 else 0
                    # Preserve corrected_height flag if set
                    if 'corrected_height' in word:
                        current_word['corrected_height'] = True
                    continue
            
            # Different line or gap too large, save current and start new
            merged.append(current_word)
            current_word = word.copy()
        
        # Add last word
        if current_word:
            merged.append(current_word)
        
        return merged
    
    def filter_words_outside_boundaries(self, words: List[Dict]) -> List[Dict]:
        """
        Filter out words that fall outside the defined line boundaries.
        This removes page numbers, headers, and other decorative text.
        
        Args:
            words: List of word dictionaries
            
        Returns:
            Filtered list of words within boundaries
        """
        if not self.line_boundaries:
            return words
        
        # Calculate overall text area from line boundaries
        min_x = min(line['bbox'][0] for line in self.line_boundaries)
        max_x = max(line['bbox'][0] + line['bbox'][2] for line in self.line_boundaries)
        min_y = min(line['bbox'][1] for line in self.line_boundaries)
        max_y = max(line['bbox'][1] + line['bbox'][3] for line in self.line_boundaries)
        
        filtered_words = []
        
        for word in words:
            wx, wy, ww, wh = word['bbox']
            word_right = wx + ww
            word_bottom = wy + wh
            word_center_y = wy + wh // 2
            
            # Check if word is within boundaries
            # Use center for y-axis (more forgiving) and edges for x-axis
            if (wx >= min_x - 10 and word_right <= max_x + 10 and
                word_center_y >= min_y and word_center_y <= max_y):
                filtered_words.append(word)
            elif self.debug:
                print(f"Filtered out word at ({wx}, {wy}, {ww}, {wh}) - outside boundaries")
        
        return filtered_words
    
    def correct_word_heights_with_lines(self, words: List[Dict]) -> List[Dict]:
        """
        Correct word heights based on manually defined line boundaries.
        
        Args:
            words: List of word dictionaries
            
        Returns:
            Words with corrected heights
        """
        if not self.line_boundaries:
            return words
        
        corrected_words = []
        
        for word in words:
            wx, wy, ww, wh = word['bbox']
            word_center_y = wy + wh // 2
            
            # Find which line this word belongs to
            best_line = None
            min_distance = float('inf')
            
            for line in self.line_boundaries:
                line_y = line['bbox'][1]
                line_h = line['bbox'][3]
                line_center_y = line_y + line_h // 2
                
                distance = abs(word_center_y - line_center_y)
                if distance < min_distance:
                    min_distance = distance
                    best_line = line
            
            # If word is close to a line, use line's height
            # Use generous threshold since all words should belong to a line
            if best_line and min_distance < 100:
                line_y = best_line['bbox'][1]
                line_h = best_line['bbox'][3]
                
                # Adjust word height to match line
                word['bbox'] = [wx, line_y, ww, line_h]
                word['line_y'] = line_y
                word['corrected_height'] = True
            elif best_line:
                # Even if far, still assign to nearest line but keep warning
                if self.debug:
                    print(f"Warning: Word at ({wx}, {wy}) is {min_distance}px from nearest line")
                line_y = best_line['bbox'][1]
                line_h = best_line['bbox'][3]
                word['bbox'] = [wx, line_y, ww, line_h]
                word['line_y'] = line_y
                word['corrected_height'] = True
            
            corrected_words.append(word)
        
        return corrected_words
    
    def get_line_rectangles_for_ayah(self, words: List[Dict]) -> List[List[int]]:
        """
        Calculate per-line rectangles for an ayah (for non-overlapping visualization).
        If line boundaries are defined, use those; otherwise calculate from words.
        
        Args:
            words: List of words in the ayah
            
        Returns:
            List of bounding boxes, one per line
        """
        if not words:
            return []
        
        # If we have line boundaries, use those
        if self.line_boundaries:
            line_rects = []
            used_lines = set()
            
            for word in words:
                word_y = word['bbox'][1]
                word_h = word['bbox'][3]
                word_center_y = word_y + word_h // 2
                
                # Find which line boundary this word belongs to
                for line_def in self.line_boundaries:
                    line_num = line_def['line_number']
                    line_y = line_def['bbox'][1]
                    line_h = line_def['bbox'][3]
                    line_center_y = line_y + line_h // 2
                    
                    # Check if word is on this line
                    if abs(word_center_y - line_center_y) < line_h // 2 + 10:
                        if line_num not in used_lines:
                            # Use the predefined line boundary
                            line_rects.append(line_def['bbox'])
                            used_lines.add(line_num)
                        break
            
            # Sort by y position
            line_rects.sort(key=lambda r: r[1])
            return line_rects
        
        # Fallback: Group words by line_y
        lines = {}
        for word in words:
            line_y = word.get('line_y', word['bbox'][1])
            if line_y not in lines:
                lines[line_y] = []
            lines[line_y].append(word)
        
        # Create rectangle for each line
        line_rects = []
        for line_y, line_words in sorted(lines.items()):
            if line_words:
                # Calculate bounding box for this line
                xs = [w['bbox'][0] for w in line_words]
                ys = [w['bbox'][1] for w in line_words]
                rights = [w['bbox'][0] + w['bbox'][2] for w in line_words]
                bottoms = [w['bbox'][1] + w['bbox'][3] for w in line_words]
                
                x = min(xs)
                y = min(ys)
                w = max(rights) - x
                h = max(bottoms) - y
                
                line_rects.append([int(x), int(y), int(w), int(h)])
        
        return line_rects
    
    def group_words_by_ayah(self, 
                           words: List[Dict], 
                           markers: List[Dict]) -> List[Dict]:
        """
        Group detected words into ayahs based on marker positions.
        
        Args:
            words: List of word dictionaries
            markers: List of ayah marker dictionaries
            
        Returns:
            List of ayah dictionaries with grouped words
        """
        if not markers:
            # If no markers detected, treat all words as one ayah
            return [{
                'number': 1,
                'bbox': self._calculate_bounding_box([w['bbox'] for w in words]),
                'words': words,
                'marker': None
            }]
        
        ayahs = []
        current_words = []
        ayah_number = 1
        
        # Sort words by position (top to bottom, right to left)
        sorted_words = sorted(words, key=lambda w: (w['line_y'], -w['bbox'][0]))
        
        marker_idx = 0
        
        for word in sorted_words:
            word_center_x = word['bbox'][0] + word['bbox'][2] // 2
            word_center_y = word['bbox'][1] + word['bbox'][3] // 2
            word_left = word['bbox'][0]
            word_right = word['bbox'][0] + word['bbox'][2]
            
            # Check if we should finalize ayah BEFORE adding this word
            if marker_idx < len(markers):
                marker_x = markers[marker_idx]['center'][0]
                marker_y = markers[marker_idx]['center'][1]
                marker_bbox = markers[marker_idx].get('bbox', [marker_x - 30, marker_y - 30, 60, 60])
                marker_left = marker_bbox[0]
                marker_right = marker_bbox[0] + marker_bbox[2]
                marker_center_x = marker_x
                
                # Check if word is on marker line
                on_marker_line = abs(word_center_y - marker_y) < 40
                
                # Check if word is AFTER marker in reading order (RTL)
                # In RTL: words to the LEFT (smaller x) come AFTER marker
                word_after_marker = False
                
                if on_marker_line:
                    # Word is after marker if word's LEFT edge (where it ends in RTL) 
                    # is to the LEFT of marker's CENTER
                    # This handles words that overlap or span the marker position
                    if word_left < marker_center_x:
                        word_after_marker = True
                # Word on next line is definitely after marker
                elif word_center_y > marker_y + 40:
                    word_after_marker = True
                
                if word_after_marker:
                    # Finalize current ayah (does NOT include this word)
                    if current_words:
                        ayahs.append({
                            'number': ayah_number,
                            'bbox': self._calculate_bounding_box([w['bbox'] for w in current_words]),
                            'line_rects': self.get_line_rectangles_for_ayah(current_words),
                            'words': current_words,
                            'marker': markers[marker_idx]
                        })
                        ayah_number += 1
                        current_words = []
                    marker_idx += 1
            
            # Add word to current ayah
            current_words.append(word)
        
        # Add remaining words as the last ayah
        if current_words:
            ayahs.append({
                'number': ayah_number,
                'bbox': self._calculate_bounding_box([w['bbox'] for w in current_words]),
                'line_rects': self.get_line_rectangles_for_ayah(current_words),
                'words': current_words,
                'marker': markers[marker_idx] if marker_idx < len(markers) else None
            })
        
        # Add line_rects to all ayahs
        for ayah in ayahs:
            if 'line_rects' not in ayah:
                ayah['line_rects'] = self.get_line_rectangles_for_ayah(ayah.get('words', []))
        
        return ayahs
    
    def _calculate_bounding_box(self, boxes: List[List[int]]) -> List[int]:
        """
        Calculate the overall bounding box for a list of boxes.
        
        Args:
            boxes: List of bounding boxes [x, y, w, h]
            
        Returns:
            Overall bounding box [x, y, w, h]
        """
        if not boxes:
            return [0, 0, 0, 0]
        
        min_x = min(b[0] for b in boxes)
        min_y = min(b[1] for b in boxes)
        max_x = max(b[0] + b[2] for b in boxes)
        max_y = max(b[1] + b[3] for b in boxes)
        
        return [int(min_x), int(min_y), int(max_x - min_x), int(max_y - min_y)]
    
    def extract_page(self, image_path: str) -> Dict:
        """
        Extract all ayahs and words from a Mushaf page image.
        
        Args:
            image_path: Path to the page image
            
        Returns:
            Dictionary containing extraction results
        """
        # Load image
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Could not load image: {image_path}")
        
        # Preprocess
        gray, binary = self.preprocess_image(image)
        
        # Detect ayah markers (with template matching if available)
        markers = self.detect_ayah_markers(gray, binary)
        
        # Try direct word detection first (more robust for many Mushaf types)
        all_words = self.detect_words_direct(binary)
        
        # If direct detection didn't work well, try line-based detection
        if len(all_words) < 10:  # Very few words, try line-based approach
            if self.debug:
                print(f"Direct detection found only {len(all_words)} words, trying line-based detection")
            
            # Detect text lines
            lines = self.detect_text_lines(binary)
            
            # Detect words in each line
            all_words = []
            for line in lines:
                words = self.detect_words_in_line(binary, line)
                all_words.extend(words)
        
        if self.debug:
            print(f"Total words detected: {len(all_words)}")
        
        # Group words by ayah
        ayahs = self.group_words_by_ayah(all_words, markers)
        
        # Prepare result
        result = {
            'image_path': image_path,
            'image_size': {
                'width': image.shape[1],
                'height': image.shape[0]
            },
            'total_ayahs': len(ayahs),
            'total_words': len(all_words),
            'total_markers': len(markers),
            'ayahs': ayahs,
            'markers_raw': markers  # Include raw markers for visualization
        }
        
        return result
    
    def visualize_results(self, 
                         image_path: str, 
                         result: Dict, 
                         output_path: Optional[str] = None) -> np.ndarray:
        """
        Visualize extraction results by drawing bounding boxes on the image.
        
        Args:
            image_path: Path to the original image
            result: Extraction result dictionary
            output_path: Optional path to save the visualization
            
        Returns:
            Image with drawn bounding boxes
        """
        # Load original image
        image = cv2.imread(image_path)
        vis_image = image.copy()
        
        # If we have markers but no ayahs grouped, draw markers directly
        if result['total_markers'] > 0 and result['total_ayahs'] == 0:
            print("Note: Detected markers but no ayahs grouped (possibly no words detected)")
            # Draw markers from raw data
            if 'markers_raw' in result:
                for i, marker in enumerate(result['markers_raw']):
                    cx, cy = marker['center']
                    # Draw circle
                    cv2.circle(vis_image, (cx, cy), 15, (0, 0, 255), 3)
                    # Draw marker box
                    if 'bbox' in marker:
                        mx, my, mw, mh = marker['bbox']
                        cv2.rectangle(vis_image, (mx, my), (mx+mw, my+mh), (0, 0, 255), 2)
                    # Draw marker number
                    cv2.putText(vis_image, f"M{i+1}", (cx-10, cy-20), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
        
        # Draw text lines first (yellow/amber) - background layer
        all_line_rects = set()
        for ayah in result.get('ayahs', []):
            line_rects = ayah.get('line_rects', [])
            if line_rects:
                for (x, y, w, h) in line_rects:
                    line_key = (x, y, w, h)
                    if line_key not in all_line_rects and w > 0 and h > 0:
                        all_line_rects.add(line_key)
                        # Yellow for lines
                        cv2.rectangle(vis_image, (x, y), (x+w, y+h), (0, 193, 255), 1)  # BGR: yellow/amber
        
        # Draw ayah bounding boxes (green) - per line to avoid overlap
        for ayah in result.get('ayahs', []):
            # Use line_rects for non-overlapping visualization
            line_rects = ayah.get('line_rects', [])
            if line_rects:
                for i, (x, y, w, h) in enumerate(line_rects):
                    if w > 0 and h > 0:
                        # Draw rectangle for this line - Green for ayahs
                        cv2.rectangle(vis_image, (x, y), (x+w, y+h), (0, 180, 0), 2)
                        
                        # Draw ayah number only on first line
                        if i == 0:
                            cv2.putText(
                                vis_image, 
                                f"Ayah {ayah['number']}", 
                                (x, y-10), 
                                cv2.FONT_HERSHEY_SIMPLEX, 
                                0.5, 
                                (0, 255, 0), 
                                2
                            )
            elif ayah.get('bbox'):
                # Fallback to single bbox if line_rects not available
                x, y, w, h = ayah['bbox']
                if w > 0 and h > 0:
                    cv2.rectangle(vis_image, (x, y), (x+w, y+h), (0, 255, 0), 2)
                    cv2.putText(
                        vis_image, 
                        f"Ayah {ayah['number']}", 
                        (x, y-10), 
                        cv2.FONT_HERSHEY_SIMPLEX, 
                        0.5, 
                        (0, 255, 0), 
                        2
                    )
            
            # Draw word bounding boxes (blue) - brighter and thicker
            for word in ayah.get('words', []):
                wx, wy, ww, wh = word['bbox']
                cv2.rectangle(vis_image, (wx, wy), (wx+ww, wy+wh), (255, 100, 0), 2)  # BGR: brighter blue
            
            # Draw marker (red circle)
            if ayah.get('marker'):
                cx, cy = ayah['marker']['center']
                cv2.circle(vis_image, (cx, cy), 15, (0, 0, 255), 3)
                # Draw marker box
                if 'bbox' in ayah['marker']:
                    mx, my, mw, mh = ayah['marker']['bbox']
                    cv2.rectangle(vis_image, (mx, my), (mx+mw, my+mh), (0, 0, 255), 2)
        
        # Add summary text
        summary_y = 30
        cv2.putText(vis_image, f"Markers: {result['total_markers']}", (10, summary_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(vis_image, f"Markers: {result['total_markers']}", (10, summary_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 1)
        
        summary_y += 30
        cv2.putText(vis_image, f"Words: {result['total_words']}", (10, summary_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(vis_image, f"Words: {result['total_words']}", (10, summary_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 1)
        
        summary_y += 30
        cv2.putText(vis_image, f"Ayahs: {result['total_ayahs']}", (10, summary_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(vis_image, f"Ayahs: {result['total_ayahs']}", (10, summary_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 1)
        
        # Save if output path provided
        if output_path:
            cv2.imwrite(output_path, vis_image)
            print(f"Visualization saved to: {output_path}")
        
        return vis_image
    
    def save_json(self, result: Dict, output_path: str):
        """
        Save extraction results to JSON file.
        
        Args:
            result: Extraction result dictionary
            output_path: Path to save JSON file
        """
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        
        print(f"JSON results saved to: {output_path}")


def main():
    """Main function for command-line usage."""
    parser = argparse.ArgumentParser(
        description='Extract ayah and word positions from Mushaf page images'
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
        '--min-word-width', 
        type=int, 
        default=20,
        help='Minimum word width in pixels (default: 20)'
    )
    parser.add_argument(
        '--min-word-height', 
        type=int, 
        default=20,
        help='Minimum word height in pixels (default: 20)'
    )
    parser.add_argument(
        '--word-spacing', 
        type=int, 
        default=15,
        help='Max gap between word parts in pixels (default: 15, use 30-50 for large fonts)'
    )
    parser.add_argument(
        '--marker-templates', 
        type=str,
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
        help='Path to JSON file with manually defined line boundaries'
    )
    parser.add_argument(
        '--debug', 
        action='store_true',
        help='Enable debug visualizations'
    )
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Auto-detect marker templates directory if not specified
    marker_templates_dir = args.marker_templates
    if not marker_templates_dir:
        # Try to find markers directory relative to image
        image_dir = Path(args.image_path).parent
        potential_markers_dir = image_dir / 'markers'
        if potential_markers_dir.exists():
            marker_templates_dir = str(potential_markers_dir)
            print(f"Auto-detected marker templates directory: {marker_templates_dir}")
    
    # Auto-detect line boundaries file if not specified
    line_boundaries_file = args.line_boundaries
    if not line_boundaries_file:
        image_path_obj = Path(args.image_path)
        potential_lines_file = image_path_obj.parent / 'line_boundaries' / f"{image_path_obj.stem}_lines.json"
        if potential_lines_file.exists():
            line_boundaries_file = str(potential_lines_file)
            print(f"Auto-detected line boundaries file: {line_boundaries_file}")
    
    # Initialize extractor
    extractor = MushafPageExtractor(
        min_word_width=args.min_word_width,
        min_word_height=args.min_word_height,
        word_spacing_threshold=args.word_spacing,
        marker_templates_dir=marker_templates_dir,
        template_match_threshold=args.template_threshold,
        line_boundaries_file=line_boundaries_file,
        debug=args.debug
    )
    
    # Extract
    print(f"Processing: {args.image_path}")
    result = extractor.extract_page(args.image_path)
    
    # Print summary
    print(f"\nExtraction Summary:")
    print(f"  Total Ayahs: {result['total_ayahs']}")
    print(f"  Total Words: {result['total_words']}")
    print(f"  Total Markers: {result['total_markers']}")
    
    # Generate output filenames
    image_stem = Path(args.image_path).stem
    json_path = output_dir / f"{image_stem}_positions.json"
    vis_path = output_dir / f"{image_stem}_visualization.jpg"
    
    # Save results
    extractor.save_json(result, str(json_path))
    extractor.visualize_results(args.image_path, result, str(vis_path))
    
    print(f"\nProcessing complete!")


if __name__ == '__main__':
    main()


