#!/usr/bin/env python3
"""
Helper tool to extract ayah marker templates from a Mushaf page image.
This allows you to manually select marker regions to create template images.
"""

import cv2
import numpy as np
from pathlib import Path
import argparse


class MarkerExtractor:
    """Interactive tool to extract marker templates with drag and resize support."""
    
    def __init__(self, image_path: str, output_dir: str):
        self.image_path = image_path
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.image = None
        self.clone = None
        self.display_image = None
        self.saved_rois = []  # List of saved ROIs
        self.current_roi = None  # Current ROI being edited [x, y, w, h]
        self.marker_count = 0
        
        # Interaction state
        self.dragging = False
        self.resizing = False
        self.creating = False
        self.panning = False
        self.drag_start = None
        self.resize_handle = None  # Which handle/edge is being resized
        self.initial_roi = None
        
        # Zoom and pan state
        self.zoom_level = 1.0
        self.min_zoom = 0.1
        self.max_zoom = 10.0
        self.zoom_step = 0.1
        self.pan_x = 0
        self.pan_y = 0
        self.pan_start = None
        
        # UI constants
        self.handle_size = 8
        self.edge_threshold = 10
        
    def extract_markers(self):
        """Main extraction workflow."""
        # Load image
        self.image = cv2.imread(self.image_path)
        if self.image is None:
            print(f"Error: Could not load image: {self.image_path}")
            return
        
        self.clone = self.image.copy()
        
        print("\n" + "="*70)
        print("MARKER TEMPLATE EXTRACTION TOOL - Enhanced Edition with Zoom!")
        print("="*70)
        print("\nSelection Controls:")
        print("  • Click and drag to CREATE a new selection")
        print("  • Click inside selection to MOVE it")
        print("  • Click on edges/corners to RESIZE")
        print("\nZoom & Pan Controls:")
        print("  • Mouse wheel or +/- keys to ZOOM in/out")
        print("  • Middle mouse button (or Space + drag) to PAN")
        print("  • Double-click to zoom to 100%")
        print("  • 'f' to FIT image to window")
        print("\nKeyboard Shortcuts:")
        print("  • 's' = SAVE current selection")
        print("  • 'r' = RESET current selection")
        print("  • 'd' = DELETE last saved marker")
        print("  • 'f' = FIT image to window")
        print("  • '+' / '=' = ZOOM in")
        print("  • '-' = ZOOM out")
        print("  • Arrow keys = MOVE selection 1px")
        print("  • Shift + Arrows = MOVE selection 10px")
        print("  • Ctrl/Cmd + Arrows = RESIZE selection")
        print("  • 'q' = QUIT and finish")
        print("\nVisual Guide:")
        print("  🟦 Blue = Current selection (being edited)")
        print("  🟩 Green = Saved selections")
        print("  🔴 Red dots = Resize handles")
        print("  📏 Top-left = Zoom level indicator")
        print("\nPro Tips:")
        print("  • Zoom in (scroll wheel) for precision")
        print("  • Use arrow keys for pixel-perfect adjustments")
        print("  • Hold Shift for faster movement (10px)")
        print("  • Hold Ctrl/Cmd to resize instead of move")
        print("="*70 + "\n")
        
        window_name = "Marker Extraction - Zoom with Mouse Wheel (press 'q' to finish)"
        cv2.namedWindow(window_name)
        cv2.setMouseCallback(window_name, self.mouse_callback)
        
        # Track if space is pressed for pan mode
        self.space_pressed = False
        
        while True:
            self.update_display()
            cv2.imshow(window_name, self.display_image)
            
            # Wait for key with longer delay to capture special keys
            key_code = cv2.waitKey(10)
            if key_code == -1:
                continue
            
            key = key_code & 0xFF
            
            # Check for special keys (arrow keys)
            if key_code in [2424832, 2555904, 2490368, 2621440]:  # Arrow keys on macOS/Linux
                if key_code == 2424832:  # Left
                    self.move_selection(-1, 0, False)
                elif key_code == 2555904:  # Right
                    self.move_selection(1, 0, False)
                elif key_code == 2490368:  # Up
                    self.move_selection(0, -1, False)
                elif key_code == 2621440:  # Down
                    self.move_selection(0, 1, False)
                continue
            
            # Check for Shift+Arrow keys
            if key_code in [2424833, 2555905, 2490369, 2621441]:  # Shift+Arrows
                if key_code == 2424833:  # Shift+Left
                    self.move_selection(-1, 0, True)
                elif key_code == 2555905:  # Shift+Right
                    self.move_selection(1, 0, True)
                elif key_code == 2490369:  # Shift+Up
                    self.move_selection(0, -1, True)
                elif key_code == 2621441:  # Shift+Down
                    self.move_selection(0, 1, True)
                continue
            
            # Reset current selection
            if key == ord("r"):
                self.current_roi = None
                self.dragging = False
                self.resizing = False
                self.creating = False
                print("Current selection reset")
            
            # Save current ROI
            elif key == ord("s"):
                if self.current_roi is not None:
                    self.save_marker()
                else:
                    print("No region selected. Create a selection first.")
            
            # Delete last saved ROI
            elif key == ord("d"):
                if self.saved_rois:
                    removed = self.saved_rois.pop()
                    self.marker_count -= 1
                    print(f"Deleted last saved marker (count now: {self.marker_count})")
                else:
                    print("No saved markers to delete")
            
            # Zoom in
            elif key == ord("+") or key == ord("="):
                self.zoom_in()
            
            # Zoom out
            elif key == ord("-"):
                self.zoom_out()
            
            # Fit to window
            elif key == ord("f"):
                self.fit_to_window()
            
            # Space key for pan mode
            elif key == ord(" "):
                self.space_pressed = not self.space_pressed
                if self.space_pressed:
                    print("Pan mode: Drag to pan the image")
                else:
                    print("Pan mode: Off")
            
            # Arrow key navigation
            elif key in [0, 1, 2, 3, 81, 82, 83, 84]:  # Arrow keys (different codes on different systems)
                # Detect modifiers from last event
                # Note: OpenCV waitKey doesn't reliably give us modifiers, so we track them
                shift_pressed = (key >= 81 and key <= 84)  # Shift+arrows on some systems
                
                # Determine direction
                if key == 81 or key == 2:  # Left arrow
                    self.move_selection(-1, 0, shift_pressed)
                elif key == 83 or key == 3:  # Right arrow
                    self.move_selection(1, 0, shift_pressed)
                elif key == 82 or key == 0:  # Up arrow
                    self.move_selection(0, -1, shift_pressed)
                elif key == 84 or key == 1:  # Down arrow
                    self.move_selection(0, 1, shift_pressed)
            
            # Additional navigation with WASD (alternative)
            elif key == ord('w'):
                self.move_selection(0, -1, False)
            elif key == ord('a'):
                self.move_selection(-1, 0, False)
            elif key == ord('s') and flags & cv2.EVENT_FLAG_CTRLKEY:
                # Ctrl+S should save (distinguish from move 's')
                if self.current_roi is not None:
                    self.save_marker()
            elif key == ord('d') and flags & cv2.EVENT_FLAG_CTRLKEY:
                # Ctrl+D handled separately from delete
                pass
            
            # Resize with Ctrl+Arrow (using letter keys as fallback)
            elif key == ord('h'):  # Ctrl+H = resize left
                self.resize_selection(-1, 0, False)
            elif key == ord('l'):  # Ctrl+L = resize right
                self.resize_selection(1, 0, False)
            elif key == ord('k'):  # Ctrl+K = resize up
                self.resize_selection(0, -1, False)
            elif key == ord('j'):  # Ctrl+J = resize down
                self.resize_selection(0, 1, False)
            
            # Quit
            elif key == ord("q"):
                break
        
        cv2.destroyAllWindows()
        
        print(f"\n{'='*70}")
        print(f"✓ Extracted {self.marker_count} marker template(s)")
        print(f"✓ Saved to: {self.output_dir}")
        if self.marker_count > 0:
            print(f"\n🎉 You can now use these templates with:")
            print(f"  python extract_positions.py your_image.jpg --marker-templates {self.output_dir}")
        print(f"{'='*70}")
    
    def screen_to_image(self, screen_x, screen_y):
        """Convert screen coordinates to image coordinates."""
        img_x = int((screen_x - self.pan_x) / self.zoom_level)
        img_y = int((screen_y - self.pan_y) / self.zoom_level)
        return img_x, img_y
    
    def image_to_screen(self, img_x, img_y):
        """Convert image coordinates to screen coordinates."""
        screen_x = int(img_x * self.zoom_level + self.pan_x)
        screen_y = int(img_y * self.zoom_level + self.pan_y)
        return screen_x, screen_y
    
    def zoom_in(self, center=None):
        """Zoom in the image."""
        old_zoom = self.zoom_level
        self.zoom_level = min(self.max_zoom, self.zoom_level + self.zoom_step)
        
        if center:
            # Adjust pan to zoom towards the center point
            cx, cy = center
            self.pan_x = cx - (cx - self.pan_x) * (self.zoom_level / old_zoom)
            self.pan_y = cy - (cy - self.pan_y) * (self.zoom_level / old_zoom)
        
        print(f"Zoom: {self.zoom_level:.1f}x")
    
    def zoom_out(self, center=None):
        """Zoom out the image."""
        old_zoom = self.zoom_level
        self.zoom_level = max(self.min_zoom, self.zoom_level - self.zoom_step)
        
        if center:
            # Adjust pan to zoom from the center point
            cx, cy = center
            self.pan_x = cx - (cx - self.pan_x) * (self.zoom_level / old_zoom)
            self.pan_y = cy - (cy - self.pan_y) * (self.zoom_level / old_zoom)
        
        print(f"Zoom: {self.zoom_level:.1f}x")
    
    def fit_to_window(self):
        """Reset zoom and pan to fit image in window."""
        self.zoom_level = 1.0
        self.pan_x = 0
        self.pan_y = 0
        print("Zoom reset to 100%")
    
    def move_selection(self, dx, dy, fast=False):
        """Move the current selection by the specified amount.
        
        Args:
            dx: Horizontal movement in pixels
            dy: Vertical movement in pixels
            fast: If True, multiply movement by 10
        """
        if self.current_roi is None:
            print("No selection to move. Create a selection first.")
            return
        
        # Apply fast movement multiplier
        if fast:
            dx *= 10
            dy *= 10
        
        x, y, w, h = self.current_roi
        
        # Calculate new position
        new_x = x + dx
        new_y = y + dy
        
        # Keep within image bounds
        new_x = max(0, min(new_x, self.image.shape[1] - w))
        new_y = max(0, min(new_y, self.image.shape[0] - h))
        
        self.current_roi = [new_x, new_y, w, h]
        
        # Print feedback for fast moves
        if fast:
            print(f"Moved selection by ({dx}, {dy})px → Position: ({new_x}, {new_y})")
    
    def resize_selection(self, dw, dh, fast=False):
        """Resize the current selection by the specified amount.
        
        Args:
            dw: Width change in pixels
            dh: Height change in pixels
            fast: If True, multiply change by 10
        """
        if self.current_roi is None:
            print("No selection to resize. Create a selection first.")
            return
        
        # Apply fast movement multiplier
        if fast:
            dw *= 10
            dh *= 10
        
        x, y, w, h = self.current_roi
        
        # Calculate new size
        new_w = max(10, w + dw)  # Minimum 10px width
        new_h = max(10, h + dh)  # Minimum 10px height
        
        # Keep within image bounds
        new_w = min(new_w, self.image.shape[1] - x)
        new_h = min(new_h, self.image.shape[0] - y)
        
        self.current_roi = [x, y, new_w, new_h]
        
        # Print feedback for resize
        if abs(dw) > 1 or abs(dh) > 1:
            print(f"Resized selection → Size: {new_w}x{new_h}px")
    
    def update_display(self):
        """Update the display image with all ROIs and handles, applying zoom and pan."""
        # Create a working copy
        working_image = self.clone.copy()
        
        # Draw saved ROIs in green (in image coordinates)
        for roi in self.saved_rois:
            x, y, w, h = roi
            cv2.rectangle(working_image, (x, y), (x+w, y+h), (0, 255, 0), 2)
            # Add label
            cv2.putText(working_image, "Saved", (x, y-5), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
        
        # Draw current ROI in blue with resize handles (in image coordinates)
        if self.current_roi is not None:
            x, y, w, h = self.current_roi
            
            # Rectangle
            cv2.rectangle(working_image, (x, y), (x+w, y+h), (255, 0, 0), 2)
            
            # Resize handles (red circles at corners and midpoints)
            handles = self.get_resize_handles(self.current_roi)
            handle_radius = max(3, int(self.handle_size // (2 * self.zoom_level)))
            for handle_name, (hx, hy) in handles.items():
                cv2.circle(working_image, (hx, hy), handle_radius, (0, 0, 255), -1)
            
            # Label
            label = "Creating..." if self.creating else "Selected"
            cv2.putText(working_image, label, (x, y-5), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 2)
            
            # Show dimensions
            dim_text = f"{w}x{h}px"
            cv2.putText(working_image, dim_text, (x, y+h+15), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 0, 0), 2)
        
        # Apply zoom and pan transformation
        h, w = working_image.shape[:2]
        
        # Calculate zoomed dimensions
        new_w = int(w * self.zoom_level)
        new_h = int(h * self.zoom_level)
        
        # Resize image according to zoom level
        if self.zoom_level != 1.0:
            working_image = cv2.resize(working_image, (new_w, new_h), 
                                      interpolation=cv2.INTER_LINEAR if self.zoom_level > 1 else cv2.INTER_AREA)
        
        # Create canvas for display (larger to accommodate pan)
        canvas_w = max(w, new_w + abs(self.pan_x) * 2)
        canvas_h = max(h, new_h + abs(self.pan_y) * 2)
        canvas = np.ones((canvas_h, canvas_w, 3), dtype=np.uint8) * 128  # Gray background
        
        # Calculate position on canvas
        start_x = max(0, int(self.pan_x))
        start_y = max(0, int(self.pan_y))
        end_x = min(canvas_w, start_x + new_w)
        end_y = min(canvas_h, start_y + new_h)
        
        # Calculate source region
        src_start_x = max(0, -int(self.pan_x))
        src_start_y = max(0, -int(self.pan_y))
        src_end_x = src_start_x + (end_x - start_x)
        src_end_y = src_start_y + (end_y - start_y)
        
        # Place image on canvas
        if src_end_x > src_start_x and src_end_y > src_start_y:
            canvas[start_y:end_y, start_x:end_x] = working_image[src_start_y:src_end_y, src_start_x:src_end_x]
        
        # Crop canvas to original image size for display
        self.display_image = canvas[:h, :w]
        
        # Add zoom level indicator
        zoom_text = f"Zoom: {self.zoom_level:.1f}x"
        cv2.rectangle(self.display_image, (5, 5), (150, 30), (0, 0, 0), -1)
        cv2.putText(self.display_image, zoom_text, (10, 23), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        
        # Add pan mode indicator if active
        if self.space_pressed or self.panning:
            pan_text = "PAN MODE"
            cv2.rectangle(self.display_image, (5, 35), (150, 60), (0, 100, 200), -1)
            cv2.putText(self.display_image, pan_text, (10, 53), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    
    def get_resize_handles(self, roi):
        """Get positions of resize handles for a ROI."""
        if roi is None:
            return {}
        
        x, y, w, h = roi
        
        return {
            'nw': (x, y),           # Northwest (top-left)
            'ne': (x+w, y),         # Northeast (top-right)
            'sw': (x, y+h),         # Southwest (bottom-left)
            'se': (x+w, y+h),       # Southeast (bottom-right)
            'n': (x+w//2, y),       # North (top-middle)
            's': (x+w//2, y+h),     # South (bottom-middle)
            'w': (x, y+h//2),       # West (left-middle)
            'e': (x+w, y+h//2),     # East (right-middle)
        }
    
    def get_handle_at_position(self, x, y):
        """Check if mouse is over a resize handle."""
        if self.current_roi is None:
            return None
        
        handles = self.get_resize_handles(self.current_roi)
        
        for handle_name, (hx, hy) in handles.items():
            if abs(x - hx) <= self.handle_size and abs(y - hy) <= self.handle_size:
                return handle_name
        
        return None
    
    def is_inside_roi(self, x, y):
        """Check if point is inside current ROI."""
        if self.current_roi is None:
            return False
        
        rx, ry, rw, rh = self.current_roi
        
        # Check if inside, but not too close to edges (those are for resizing)
        margin = self.edge_threshold
        return (rx + margin < x < rx + rw - margin and 
                ry + margin < y < ry + rh - margin)
    
    def mouse_callback(self, event, x, y, flags, param):
        """Enhanced mouse callback with drag, resize, zoom, and pan support."""
        
        # Convert screen coordinates to image coordinates
        img_x, img_y = self.screen_to_image(x, y)
        
        # Mouse wheel for zoom
        if event == cv2.EVENT_MOUSEWHEEL:
            if flags > 0:  # Scroll up - zoom in
                self.zoom_in(center=(x, y))
            else:  # Scroll down - zoom out
                self.zoom_out(center=(x, y))
            return
        
        # Middle mouse button for pan
        if event == cv2.EVENT_MBUTTONDOWN or (event == cv2.EVENT_LBUTTONDOWN and self.space_pressed):
            self.panning = True
            self.pan_start = (x, y)
            self.initial_pan = (self.pan_x, self.pan_y)
            return
        
        if event == cv2.EVENT_MBUTTONUP:
            self.panning = False
            self.pan_start = None
            return
        
        # Handle panning
        if self.panning and self.pan_start:
            dx = x - self.pan_start[0]
            dy = y - self.pan_start[1]
            self.pan_x = self.initial_pan[0] + dx
            self.pan_y = self.initial_pan[1] + dy
            return
        
        # Double click to reset zoom
        if event == cv2.EVENT_LBUTTONDBLCLK:
            self.fit_to_window()
            return
        
        # Don't process selection events if panning
        if self.panning or self.space_pressed:
            return
        
        # Mouse button down
        if event == cv2.EVENT_LBUTTONDOWN:
            # Check if clicking on a resize handle (use image coordinates)
            handle = self.get_handle_at_position(img_x, img_y)
            if handle:
                self.resizing = True
                self.resize_handle = handle
                self.drag_start = (img_x, img_y)
                self.initial_roi = self.current_roi.copy()
                return
            
            # Check if clicking inside existing ROI to drag it (use image coordinates)
            if self.is_inside_roi(img_x, img_y):
                self.dragging = True
                self.drag_start = (img_x, img_y)
                self.initial_roi = self.current_roi.copy()
                return
            
            # Otherwise, start creating new ROI (use image coordinates)
            self.creating = True
            self.drag_start = (img_x, img_y)
            self.current_roi = [img_x, img_y, 0, 0]
        
        # Mouse move
        elif event == cv2.EVENT_MOUSEMOVE:
            if self.creating and self.drag_start:
                # Update ROI size while creating (use image coordinates)
                x1, y1 = self.drag_start
                w = img_x - x1
                h = img_y - y1
                self.current_roi = [min(x1, img_x), min(y1, img_y), abs(w), abs(h)]
            
            elif self.dragging and self.drag_start and self.initial_roi:
                # Move the ROI (use image coordinates)
                dx = img_x - self.drag_start[0]
                dy = img_y - self.drag_start[1]
                rx, ry, rw, rh = self.initial_roi
                
                # Keep within image bounds
                new_x = max(0, min(rx + dx, self.image.shape[1] - rw))
                new_y = max(0, min(ry + dy, self.image.shape[0] - rh))
                
                self.current_roi = [new_x, new_y, rw, rh]
            
            elif self.resizing and self.drag_start and self.initial_roi:
                # Resize the ROI based on which handle is being dragged (use image coordinates)
                dx = img_x - self.drag_start[0]
                dy = img_y - self.drag_start[1]
                rx, ry, rw, rh = self.initial_roi
                
                new_roi = [rx, ry, rw, rh]
                
                # Adjust based on handle
                if 'n' in self.resize_handle:  # North handles
                    new_roi[1] = min(ry + dy, ry + rh - 10)
                    new_roi[3] = max(10, rh - dy)
                if 's' in self.resize_handle:  # South handles
                    new_roi[3] = max(10, rh + dy)
                if 'w' in self.resize_handle:  # West handles
                    new_roi[0] = min(rx + dx, rx + rw - 10)
                    new_roi[2] = max(10, rw - dx)
                if 'e' in self.resize_handle:  # East handles
                    new_roi[2] = max(10, rw + dx)
                
                # Keep within image bounds
                new_roi[0] = max(0, new_roi[0])
                new_roi[1] = max(0, new_roi[1])
                new_roi[2] = min(new_roi[2], self.image.shape[1] - new_roi[0])
                new_roi[3] = min(new_roi[3], self.image.shape[0] - new_roi[1])
                
                self.current_roi = new_roi
            
            # Update cursor based on position (use image coordinates)
            else:
                handle = self.get_handle_at_position(img_x, img_y)
                if handle:
                    # Over a resize handle - could set cursor here if needed
                    pass
                elif self.is_inside_roi(img_x, img_y):
                    # Inside ROI - drag cursor
                    pass
        
        # Mouse button up
        elif event == cv2.EVENT_LBUTTONUP:
            if self.creating:
                # Finished creating ROI
                if self.current_roi and self.current_roi[2] > 10 and self.current_roi[3] > 10:
                    self.creating = False
                    print(f"Created selection: {self.current_roi[2]}x{self.current_roi[3]} pixels")
                else:
                    self.current_roi = None
                    print("Selection too small, try again")
            
            self.creating = False
            self.dragging = False
            self.resizing = False
            self.drag_start = None
            self.resize_handle = None
            self.initial_roi = None
    
    def save_marker(self):
        """Save the current ROI as a marker template."""
        if self.current_roi is None:
            print("No selection to save")
            return
        
        x, y, w, h = self.current_roi
        
        # Check if selection is valid
        if w < 10 or h < 10:
            print("Selection too small. Please select a larger region.")
            return
        
        # Extract ROI
        roi = self.clone[y:y+h, x:x+w]
        
        # Save
        self.marker_count += 1
        output_path = self.output_dir / f"marker_{self.marker_count:02d}.png"
        cv2.imwrite(str(output_path), roi)
        
        print(f"✓ Saved marker template {self.marker_count}: {output_path.name} ({w}x{h} pixels)")
        
        # Add to saved list and reset current
        self.saved_rois.append(self.current_roi.copy())
        self.current_roi = None
        self.creating = False
        self.dragging = False
        self.resizing = False


def auto_extract_markers(image_path: str, output_dir: str, min_size: int = 30, max_size: int = 150):
    """
    Automatically extract potential marker regions using contour detection.
    This is a quick way to get started, but manual extraction is more accurate.
    """
    print("\nAttempting automatic marker extraction...")
    
    # Load image
    image = cv2.imread(image_path)
    if image is None:
        print(f"Error: Could not load image: {image_path}")
        return
    
    # Convert to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # Binary threshold
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    
    # Find contours
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Extract circular-ish contours
    marker_count = 0
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        
        # Filter by size
        if min_size < w < max_size and min_size < h < max_size:
            # Check aspect ratio (should be roughly square)
            aspect_ratio = w / float(h)
            if 0.7 < aspect_ratio < 1.3:
                # Check circularity
                area = cv2.contourArea(contour)
                perimeter = cv2.arcLength(contour, True)
                if perimeter > 0:
                    circularity = 4 * np.pi * area / (perimeter * perimeter)
                    
                    # High circularity suggests a marker
                    if circularity > 0.5:
                        # Extract with padding
                        padding = 5
                        x1 = max(0, x - padding)
                        y1 = max(0, y - padding)
                        x2 = min(image.shape[1], x + w + padding)
                        y2 = min(image.shape[0], y + h + padding)
                        
                        roi = image[y1:y2, x1:x2]
                        
                        marker_count += 1
                        output_file = output_path / f"marker_auto_{marker_count:02d}.png"
                        cv2.imwrite(str(output_file), roi)
    
    if marker_count > 0:
        print(f"✓ Automatically extracted {marker_count} potential marker(s)")
        print(f"✓ Saved to: {output_path}")
        print(f"\n⚠ Review the extracted markers and delete any false positives")
    else:
        print("✗ No markers found automatically. Try manual extraction instead.")


def main():
    parser = argparse.ArgumentParser(
        description='Extract ayah marker templates from Mushaf page images'
    )
    parser.add_argument('image_path', help='Path to Mushaf page image')
    parser.add_argument(
        '--output-dir',
        type=str,
        default='markers',
        help='Directory to save marker templates (default: markers)'
    )
    parser.add_argument(
        '--auto',
        action='store_true',
        help='Attempt automatic extraction (less accurate)'
    )
    parser.add_argument(
        '--min-size',
        type=int,
        default=30,
        help='Minimum marker size for auto extraction (default: 30)'
    )
    parser.add_argument(
        '--max-size',
        type=int,
        default=150,
        help='Maximum marker size for auto extraction (default: 150)'
    )
    
    args = parser.parse_args()
    
    if args.auto:
        auto_extract_markers(args.image_path, args.output_dir, args.min_size, args.max_size)
    else:
        extractor = MarkerExtractor(args.image_path, args.output_dir)
        extractor.extract_markers()


if __name__ == '__main__':
    main()

