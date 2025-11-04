#!/usr/bin/env python3
"""
Normalize line boundaries to have consistent heights and widths.
"""

import json
import numpy as np
from pathlib import Path
import argparse


def normalize_lines(input_file, output_file=None):
    """Normalize line boundaries."""
    with open(input_file, 'r') as f:
        data = json.load(f)
    
    lines = data.get('lines', [])
    if not lines:
        print("No lines found")
        return
    
    # Calculate statistics
    heights = [line['bbox'][3] for line in lines]
    widths = [line['bbox'][2] for line in lines]
    x_positions = [line['bbox'][0] for line in lines]
    
    # Use median for more robust normalization
    target_height = int(np.median(heights))
    target_width = int(np.median(widths))
    target_x = int(np.median(x_positions))
    
    print(f"Original heights: {heights}")
    print(f"Original widths: {widths}")
    print(f"Original x positions: {x_positions}")
    print(f"\nTarget height: {target_height}")
    print(f"Target width: {target_width}")
    print(f"Target x: {target_x}")
    
    # Normalize lines
    for line in lines:
        old_bbox = line['bbox'].copy()
        x, y, w, h = line['bbox']
        
        # Keep y position, normalize height
        new_h = target_height
        new_w = target_width
        new_x = target_x
        
        line['bbox'] = [new_x, y, new_w, new_h]
        line['y_center'] = y + new_h // 2
        line['height'] = new_h
        
        print(f"Line {line['line_number']}: {old_bbox} → {line['bbox']}")
    
    # Save
    if not output_file:
        output_file = input_file
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
    
    print(f"\n✓ Normalized and saved to: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description='Normalize line boundaries'
    )
    parser.add_argument('input_file', help='Input line boundaries JSON')
    parser.add_argument('--output', help='Output file (default: overwrite input)')
    
    args = parser.parse_args()
    normalize_lines(args.input_file, args.output)


if __name__ == '__main__':
    main()

