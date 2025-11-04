#!/usr/bin/env python3
"""
Interactive Line Boundary Highlighter

This tool allows you to manually highlight text lines on a page.
The saved line boundaries will be used to:
1. Improve word detection (correct word heights)
2. Better line detection (ignore decorative borders)
3. More accurate ayah segmentation
"""

import cv2
import numpy as np
import json
from pathlib import Path
import argparse


class LineBoundaryExtractor:
    """Interactive tool to highlight and save text line boundaries."""
    
    def __init__(self, image_path: str, output_path: str):
        self.image_path = image_path
        self.output_path = output_path
        
        self.image = None
        self.clone = None
        self.display_image = None
        self.line_boundaries = []  # List of line rectangles
        self.current_line = None  # Current line being created [x, y, w, h]
        
        # Interaction state
        self.creating = False
        self.dragging = False
        self.resizing = False
        self.drag_start = None
        self.resize_handle = None
        self.initial_line = None
        
        # Zoom state
        self.zoom_level = 1.0
        self.pan_x = 0
        self.pan_y = 0
        self.panning = False
        self.pan_start = None
        
        # UI constants
        self.handle_size = 8
        self.edge_threshold = 10
        
    def extract_lines(self):
        """Main extraction workflow."""
        # Load image
        self.image = cv2.imread(self.image_path)
        if self.image is None:
            print(f"Error: Could not load image: {self.image_path}")
            return
        
        self.clone = self.image.copy()
        
        print("\n" + "="*70)
        print("LINE BOUNDARY HIGHLIGHTER")
        print("="*70)
        print("\nInstructions:")
        print("  • Click and drag to CREATE a line boundary")
        print("  • Drag inside to MOVE line")
        print("  • Drag edges/corners to RESIZE")
        print("  • Scroll wheel to ZOOM")
        print("  • Middle mouse to PAN")
        print("  • Arrow keys to adjust position")
        print("\nKeyboard:")
        print("  • 's' = SAVE current line")
        print("  • 'n' = NEW line (save current and start new)")
        print("  • 'd' = DELETE last saved line")
        print("  • 'r' = RESET current line")
        print("  • 'f' = FINISH and save all")
        print("  • 'q' = QUIT without saving")
        print("\nTip:")
        print("  - Draw rectangles around each text line")
        print("  - Include full line width (even if words extend)")
        print("  - Keep height tight to actual text")
        print("="*70 + "\n")
        
        window_name = "Line Boundary Highlighter - Draw lines from top to bottom"
        cv2.namedWindow(window_name)
        cv2.setMouseCallback(window_name, self.mouse_callback)
        
        while True:
            self.update_display()
            cv2.imshow(window_name, self.display_image)
            
            key_code = cv2.waitKey(10)
            if key_code == -1:
                continue
            
            key = key_code & 0xFF
            
            # Arrow keys for adjustment
            if key_code in [2424832, 2555904, 2490368, 2621440]:
                if key_code == 2424832:  # Left
                    self.move_line(-1, 0)
                elif key_code == 2555904:  # Right
                    self.move_line(1, 0)
                elif key_code == 2490368:  # Up
                    self.move_line(0, -1)
                elif key_code == 2621440:  # Down
                    self.move_line(0, 1)
                continue
            
            # Save current line
            if key == ord('s'):
                if self.current_line:
                    self.save_line()
                else:
                    print("No line to save. Create a line first.")
            
            # Save and create new
            elif key == ord('n'):
                if self.current_line:
                    self.save_line()
                print(f"Ready for next line (total: {len(self.line_boundaries)})")
            
            # Delete last saved
            elif key == ord('d'):
                if self.line_boundaries:
                    self.line_boundaries.pop()
                    print(f"Deleted last line (count: {len(self.line_boundaries)})")
                else:
                    print("No lines to delete")
            
            # Reset current
            elif key == ord('r'):
                self.current_line = None
                print("Current line reset")
            
            # Zoom
            elif key == ord('+') or key == ord('='):
                self.zoom_level = min(10.0, self.zoom_level * 1.2)
                print(f"Zoom: {self.zoom_level:.1f}x")
            elif key == ord('-'):
                self.zoom_level = max(0.1, self.zoom_level / 1.2)
                print(f"Zoom: {self.zoom_level:.1f}x")
            elif key == ord('f') and key_code != ord('f'):  # Not 'f' for finish
                self.zoom_level = 1.0
                self.pan_x = 0
                self.pan_y = 0
                print("Zoom reset")
            
            # Finish and save all
            elif key == ord('f'):
                if self.current_line:
                    self.save_line()
                self.save_all()
                break
            
            # Quit without saving
            elif key == ord('q'):
                print("Quitting without saving")
                break
        
        cv2.destroyAllWindows()
    
    def update_display(self):
        """Update display with all lines and current selection."""
        working_image = self.clone.copy()
        
        # Draw saved lines in green
        for i, line in enumerate(self.line_boundaries):
            x, y, w, h = line
            cv2.rectangle(working_image, (x, y), (x+w, y+h), (0, 255, 0), 2)
            cv2.putText(working_image, f"Line {i+1}", (x+5, y+20),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
        
        # Draw current line in blue
        if self.current_line:
            x, y, w, h = self.current_line
            cv2.rectangle(working_image, (x, y), (x+w, y+h), (255, 0, 0), 2)
            
            # Draw resize handles
            handles = self.get_resize_handles(self.current_line)
            for hx, hy in handles.values():
                cv2.circle(working_image, (hx, hy), 4, (0, 0, 255), -1)
            
            # Show dimensions
            cv2.putText(working_image, f"{w}x{h}px", (x, y+h+20),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 2)
        
        self.display_image = working_image
        
        # Add info overlay
        info_text = f"Lines: {len(self.line_boundaries)} | Zoom: {self.zoom_level:.1f}x | Press 'f' to finish"
        cv2.rectangle(self.display_image, (5, 5), (500, 35), (0, 0, 0), -1)
        cv2.putText(self.display_image, info_text, (10, 25),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    
    def get_resize_handles(self, line):
        """Get resize handle positions."""
        if not line:
            return {}
        x, y, w, h = line
        return {
            'nw': (x, y), 'ne': (x+w, y),
            'sw': (x, y+h), 'se': (x+w, y+h),
            'n': (x+w//2, y), 's': (x+w//2, y+h),
            'w': (x, y+h//2), 'e': (x+w, y+h//2)
        }
    
    def get_handle_at_position(self, x, y):
        """Check if position is on a resize handle."""
        if not self.current_line:
            return None
        handles = self.get_resize_handles(self.current_line)
        for name, (hx, hy) in handles.items():
            if abs(x - hx) <= self.handle_size and abs(y - hy) <= self.handle_size:
                return name
        return None
    
    def is_inside_line(self, x, y):
        """Check if position is inside current line."""
        if not self.current_line:
            return False
        lx, ly, lw, lh = self.current_line
        margin = self.edge_threshold
        return (lx + margin < x < lx + lw - margin and 
                ly + margin < y < ly + lh - margin)
    
    def move_line(self, dx, dy):
        """Move current line by delta."""
        if not self.current_line:
            return
        x, y, w, h = self.current_line
        new_x = max(0, min(x + dx, self.image.shape[1] - w))
        new_y = max(0, min(y + dy, self.image.shape[0] - h))
        self.current_line = [new_x, new_y, w, h]
    
    def mouse_callback(self, event, x, y, flags, param):
        """Handle mouse events."""
        # Zoom
        if event == cv2.EVENT_MOUSEWHEEL:
            if flags > 0:
                self.zoom_level = min(10.0, self.zoom_level * 1.1)
            else:
                self.zoom_level = max(0.1, self.zoom_level / 1.1)
            return
        
        # Pan
        if event == cv2.EVENT_MBUTTONDOWN:
            self.panning = True
            self.pan_start = (x, y)
            return
        if event == cv2.EVENT_MBUTTONUP:
            self.panning = False
            return
        if self.panning:
            return
        
        # Double-click reset
        if event == cv2.EVENT_LBUTTONDBLCLK:
            self.zoom_level = 1.0
            self.pan_x = 0
            self.pan_y = 0
            return
        
        # Selection
        if event == cv2.EVENT_LBUTTONDOWN:
            handle = self.get_handle_at_position(x, y)
            if handle:
                self.resizing = True
                self.resize_handle = handle
                self.drag_start = (x, y)
                self.initial_line = self.current_line.copy()
                return
            
            if self.is_inside_line(x, y):
                self.dragging = True
                self.drag_start = (x, y)
                self.initial_line = self.current_line.copy()
                return
            
            self.creating = True
            self.drag_start = (x, y)
            self.current_line = [x, y, 0, 0]
        
        elif event == cv2.EVENT_MOUSEMOVE:
            if self.creating and self.drag_start:
                x1, y1 = self.drag_start
                w = x - x1
                h = y - y1
                self.current_line = [min(x1, x), min(y1, y), abs(w), abs(h)]
            
            elif self.dragging and self.drag_start and self.initial_line:
                dx = x - self.drag_start[0]
                dy = y - self.drag_start[1]
                lx, ly, lw, lh = self.initial_line
                new_x = max(0, min(lx + dx, self.image.shape[1] - lw))
                new_y = max(0, min(ly + dy, self.image.shape[0] - lh))
                self.current_line = [new_x, new_y, lw, lh]
            
            elif self.resizing and self.drag_start and self.initial_line:
                dx = x - self.drag_start[0]
                dy = y - self.drag_start[1]
                lx, ly, lw, lh = self.initial_line
                new_line = [lx, ly, lw, lh]
                
                if 'n' in self.resize_handle:
                    new_line[1] = min(ly + dy, ly + lh - 10)
                    new_line[3] = max(10, lh - dy)
                if 's' in self.resize_handle:
                    new_line[3] = max(10, lh + dy)
                if 'w' in self.resize_handle:
                    new_line[0] = min(lx + dx, lx + lw - 10)
                    new_line[2] = max(10, lw - dx)
                if 'e' in self.resize_handle:
                    new_line[2] = max(10, lw + dx)
                
                new_line[0] = max(0, new_line[0])
                new_line[1] = max(0, new_line[1])
                new_line[2] = min(new_line[2], self.image.shape[1] - new_line[0])
                new_line[3] = min(new_line[3], self.image.shape[0] - new_line[1])
                
                self.current_line = new_line
        
        elif event == cv2.EVENT_LBUTTONUP:
            if self.creating and self.current_line and self.current_line[2] > 10:
                print(f"Created line: {self.current_line[2]}x{self.current_line[3]}px")
            self.creating = False
            self.dragging = False
            self.resizing = False
    
    def save_line(self):
        """Save current line to the list."""
        if not self.current_line:
            return
        
        x, y, w, h = self.current_line
        if w < 10 or h < 10:
            print("Line too small")
            return
        
        self.line_boundaries.append(self.current_line.copy())
        print(f"✓ Saved line {len(self.line_boundaries)}: {w}x{h}px at ({x}, {y})")
        self.current_line = None
    
    def save_all(self):
        """Save all line boundaries to JSON file."""
        if not self.line_boundaries:
            print("No lines to save")
            return
        
        # Sort lines top to bottom
        self.line_boundaries.sort(key=lambda l: l[1])
        
        # Prepare output
        output_data = {
            'image_path': self.image_path,
            'image_size': {
                'width': self.image.shape[1],
                'height': self.image.shape[0]
            },
            'total_lines': len(self.line_boundaries),
            'lines': [
                {
                    'line_number': i + 1,
                    'bbox': [int(x), int(y), int(w), int(h)],
                    'y_center': int(y + h // 2),
                    'height': int(h)
                }
                for i, (x, y, w, h) in enumerate(self.line_boundaries)
            ]
        }
        
        # Save JSON
        output_path = Path(self.output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2)
        
        print(f"\n{'='*70}")
        print(f"✓ Saved {len(self.line_boundaries)} line boundaries")
        print(f"✓ Saved to: {output_path}")
        print(f"\nYou can now use these line boundaries with:")
        print(f"  python extract_positions.py {self.image_path} \\")
        print(f"      --line-boundaries {output_path} \\")
        print(f"      --marker-templates <markers_dir>")
        print(f"{'='*70}")


def main():
    parser = argparse.ArgumentParser(
        description='Extract line boundaries from Mushaf page'
    )
    parser.add_argument('image_path', help='Path to Mushaf page image')
    parser.add_argument(
        '--output',
        type=str,
        help='Output JSON file path (default: <image>_lines.json)'
    )
    
    args = parser.parse_args()
    
    # Auto-generate output path if not provided
    if not args.output:
        image_path = Path(args.image_path)
        output_dir = image_path.parent / 'line_boundaries'
        output_dir.mkdir(exist_ok=True)
        args.output = str(output_dir / f"{image_path.stem}_lines.json")
    
    extractor = LineBoundaryExtractor(args.image_path, args.output)
    extractor.extract_lines()


if __name__ == '__main__':
    main()

